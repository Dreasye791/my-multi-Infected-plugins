#pragma tabsize 1
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define DEBUG		0
#define BENCHMARK	0
#if BENCHMARK
	#include <profiler>
	Profiler g_profiler;
#endif

#define SI_SMOKER		0
#define SI_BOOMER		1
#define SI_HUNTER		2
#define SI_SPITTER		3
#define SI_JOCKEY		4
#define SI_CHARGER		5

#define SPAWN_NO_PREFERENCE						-1
#define SPAWN_ANYWHERE							0
#define SPAWN_BEHIND_SURVIVORS					1
#define SPAWN_NEAR_IT_VICTIM					2
#define SPAWN_SPECIALS_IN_FRONT_OF_SURVIVORS	3
#define SPAWN_SPECIALS_ANYWHERE					4
#define SPAWN_FAR_AWAY_FROM_SURVIVORS			5
#define SPAWN_ABOVE_SURVIVORS					6
#define SPAWN_IN_FRONT_OF_SURVIVORS				7
#define SPAWN_VERSUS_FINALE_DISTANCE			8
#define SPAWN_LARGE_VOLUME						9
#define SPAWN_NEAR_POSITION						10

Handle
	g_hSpawnTimer,
	g_hRetryTimer,
	g_hUpdateTimer,
	g_hSuicideTimer;

ConVar
	g_cvSILimit,
	g_cvSpawnSize,
	g_cvSpawnLimits[6],
	g_cvSpawnWeights[6],
	g_cvScaleWeights,
	g_cvSpawnTimeMode,
	g_cvSpawnTimeMin,
	g_cvSpawnTimeMax,
	g_cvBaseLimit,
	g_cvExtraLimit,
	g_cvBaseSize,
	g_cvExtraSize,
	g_cvTankStatusAction,
	g_cvTankStatusLimits,
	g_cvTankStatusWeights,
	g_cvSuicideTime,
	g_cvRushDistance,
	g_cvSpawnRangeMin,
	g_cvSpawnRangeMax,
	g_cvFirstSpawnTime,
	g_cvSafeSpawnRange,
	g_cvSpawnRange,
	g_cvDiscardRange;

float
	g_fSpawnTimeMin,
	g_fSpawnTimeMax,
	g_fExtraLimit,
	g_fExtraSize,
	g_fSuicideTime,
	g_fRushDistance,
	g_fFirstSpawnTime,
	g_fSpawnTimes[MAXPLAYERS + 1],
	g_fActionTimes[MAXPLAYERS + 1];

static const char
	g_sZombieClass[6][] = {
		"smoker",
		"boomer",
		"hunter",
		"spitter",
		"jockey",
		"charger"
	};

int
	g_iSILimit,
	g_iSpawnSize,
	g_iDirection,
	g_iSpawnLimits[6],
	g_iSpawnWeights[6],
	g_iSpawnTimeMode,
	g_iTankStatusAction,
	g_iSILimitCache = -1,
	g_iSpawnLimitsCache[6] = {	
		-1,
		-1,
		-1,
		-1,
		-1,
		-1
	},
	g_iSpawnWeightsCache[6] = {
		-1,
		-1,
		-1,
		-1,
		-1,
		-1
	},
	g_iTankStatusLimits[6] = {	
		-1,
		-1,
		-1,
		-1,
		-1,
		-1
	},
	g_iTankStatusWeights[6] = {	
		-1,
		-1,
		-1,
		-1,
		-1,
		-1
	},
	g_iSpawnSizeCache = -1,
	g_iSpawnCounts[6],
	g_iBaseLimit,
	g_iBaseSize,
	g_iCurrentClass = -1;

bool
	g_bLateLoad,
	g_bInSpawnTime,
	g_bScaleWeights,
	g_bLeftSafeArea,
	g_bFinaleStarted;

public Plugin myinfo = {
	name = "Special Spawner",
	author = "Tordecybombo, breezy",
	description = "Provides customisable special infected spawing beyond vanilla coop limits",
	version = "1.3.6",
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart() {
	g_cvSILimit	= 					CreateConVar("ss_si_limit",				"12",						"同时存在的最大特感数量", _, true, 1.0, true, 32.0);
	g_cvSpawnSize = 				CreateConVar("ss_spawn_size",			"2",						"一次产生多少只特感", _, true, 1.0, true, 32.0);
	g_cvSpawnLimits[SI_SMOKER] = 	CreateConVar("ss_smoker_limit",			"5",						"同时存在的最大smoker数量", _, true, 0.0, true, 32.0);
	g_cvSpawnLimits[SI_BOOMER] = 	CreateConVar("ss_boomer_limit",			"5",						"同时存在的最大boomer数量", _, true, 0.0, true, 32.0);
	g_cvSpawnLimits[SI_HUNTER] = 	CreateConVar("ss_hunter_limit",			"5",						"同时存在的最大hunter数量", _, true, 0.0, true, 32.0);
	g_cvSpawnLimits[SI_SPITTER] = 	CreateConVar("ss_spitter_limit",		"5",						"同时存在的最大spitter数量", _, true, 0.0, true, 32.0);
	g_cvSpawnLimits[SI_JOCKEY] = 	CreateConVar("ss_jockey_limit",			"5",						"同时存在的最大jockey数量", _, true, 0.0, true, 32.0);
	g_cvSpawnLimits[SI_CHARGER] = 	CreateConVar("ss_charger_limit",		"5",						"同时存在的最大charger数量", _, true, 0.0, true, 32.0);

	g_cvSpawnWeights[SI_SMOKER] =	CreateConVar("ss_smoker_weight",		"100",						"smoker产生比重", _, true, 0.0);
	g_cvSpawnWeights[SI_BOOMER] =	CreateConVar("ss_boomer_weight",		"100",						"boomer产生比重", _, true, 0.0);
	g_cvSpawnWeights[SI_HUNTER] =	CreateConVar("ss_hunter_weight",		"100",						"hunter产生比重", _, true, 0.0);
	g_cvSpawnWeights[SI_SPITTER] =	CreateConVar("ss_spitter_weight",		"100",						"spitter产生比重", _, true, 0.0);
	g_cvSpawnWeights[SI_JOCKEY] =	CreateConVar("ss_jockey_weight",		"100",						"jockey产生比重", _, true, 0.0);
	g_cvSpawnWeights[SI_CHARGER] =	CreateConVar("ss_charger_weight",		"100",						"charger产生比重", _, true, 0.0);
	g_cvScaleWeights =				CreateConVar("ss_scale_weights",		"1",						"缩放相应特感的产生比重 [0 = 关闭 | 1 = 开启](开启后,总比重越大的越容易先刷出来, 动态控制特感刷出顺序)", _, true, 0.0, true, 1.0);
	g_cvSpawnTimeMin =				CreateConVar("ss_time_min",				"10.0",						"特感的最小产生时间", _, true, 0.1);
	g_cvSpawnTimeMax =				CreateConVar("ss_time_max",				"20.0",						"特感的最大产生时间", _, true, 1.0);
	g_cvSpawnTimeMode =				CreateConVar("ss_time_mode",			"1",						"特感的刷新时间模式[0 = 随机 | 1 = 递增(杀的越快刷的越快) | 2 = 递减(杀的越慢刷的越快)]", _, true, 0.0, true, 2.0);

	g_cvBaseLimit =					CreateConVar("ss_base_limit",			"4",						"生还者团队不超过4人时有多少个特感", _, true, 0.0, true, 32.0);
	g_cvExtraLimit =				CreateConVar("ss_extra_limit",			"1",						"生还者团队每增加一人可增加多少个特感", _, true, 0.0, true, 32.0);
	g_cvBaseSize =					CreateConVar("ss_base_size",			"4",						"生还者团队不超过4人时一次产生多少只特感", _, true, 0.0, true, 32.0);
	g_cvExtraSize =					CreateConVar("ss_extra_size",			"2",						"生还者团队每增加多少玩家人一次多产生一只特感", _, true, 1.0, true, 32.0);
	g_cvTankStatusAction =			CreateConVar("ss_tankstatus_action",	"1",						"坦克产生后是否对当前刷特参数进行修改, 坦克死完后恢复?[0 = 忽略(保持原有的刷特状态) | 1 = 自定义]", _, true, 0.0, true, 1.0);
	g_cvTankStatusLimits =			CreateConVar("ss_tankstatus_limits",	"5;5;5;5;5;5",				"坦克产生后每种特感数量的自定义参数");
	g_cvTankStatusWeights =			CreateConVar("ss_tankstatus_weights",	"100;200;100;200;100;100",	"坦克产生后每种特感比重的自定义参数");
	g_cvSuicideTime =				CreateConVar("ss_suicide_time",			"25.0",						"特感自动处死时间", _, true, 1.0);
	g_cvRushDistance =				CreateConVar("ss_rush_distance",		"1500.0",					"路程超过多少算跑图(最前面的玩家路程减去最后面的玩家路程, 忽略倒地玩家)", _, true, 0.0);

	g_cvSpawnRangeMin =				CreateConVar("ss_spawnrange_min",		"100.0",					"特感最小生成距离", _, true, 0.0);
	g_cvSpawnRangeMax =				CreateConVar("ss_spawnrange_max",		"1500.0",					"特感最大生成距离", _, true, 0.0);

	g_cvFirstSpawnTime = 			CreateConVar("ss_first_time",			"10.0",						"玩家离开安全区域后第一波特感的刷新时间", _, true, 0.0);

	g_cvSafeSpawnRange = FindConVar("z_safe_spawn_range");
	g_cvSpawnRange = FindConVar("z_spawn_range");
	
	g_cvSpawnRange.Flags &= ~FCVAR_NOTIFY;
	g_cvDiscardRange = FindConVar("z_discard_range");
	g_cvDiscardRange.Flags &= ~FCVAR_NOTIFY;

	g_cvSpawnSize.AddChangeHook(CvarChanged_Limits);
	for (int i; i < 6; i++) {
		g_cvSpawnLimits[i].AddChangeHook(CvarChanged_Limits);
		g_cvSpawnWeights[i].AddChangeHook(CvarChanged_General);
	}

	g_cvSILimit.AddChangeHook(CvarChanged_Times);
	g_cvSpawnTimeMin.AddChangeHook(CvarChanged_Times);
	g_cvSpawnTimeMax.AddChangeHook(CvarChanged_Times);
	g_cvSpawnTimeMode.AddChangeHook(CvarChanged_Times);

	g_cvScaleWeights.AddChangeHook(CvarChanged_General);
	g_cvBaseLimit.AddChangeHook(CvarChanged_General);
	g_cvExtraLimit.AddChangeHook(CvarChanged_General);
	g_cvBaseSize.AddChangeHook(CvarChanged_General);
	g_cvExtraSize.AddChangeHook(CvarChanged_General);
	g_cvSuicideTime.AddChangeHook(CvarChanged_General);
	g_cvRushDistance.AddChangeHook(CvarChanged_General);
	g_cvFirstSpawnTime.AddChangeHook(CvarChanged_General);

	g_cvTankStatusAction.AddChangeHook(CvarChanged_TankStatus);
	g_cvTankStatusLimits.AddChangeHook(CvarChanged_TankCustom);
	g_cvTankStatusWeights.AddChangeHook(CvarChanged_TankCustom);

	//AutoExecConfig(true);

	HookEvent("round_end",				Event_RoundEnd,		EventHookMode_PostNoCopy);
	HookEvent("finale_vehicle_leaving", Event_RoundEnd,		EventHookMode_PostNoCopy);
	HookEvent("round_start",			Event_RoundStart,	EventHookMode_PostNoCopy);
	HookEvent("player_hurt",			Event_PlayerHurt);
	HookEvent("player_team",			Event_PlayerTeam);
	HookEvent("player_spawn",			Event_PlayerSpawn);
	HookEvent("player_death",			Event_PlayerDeath,	EventHookMode_Pre);

	RegAdminCmd("sm_weight",		cmdSetWeight,	ADMFLAG_RCON, "设置特感生成比重");
	RegAdminCmd("sm_limit",			cmdSetLimit,	ADMFLAG_RCON, "设置特感生成数量");
	RegAdminCmd("sm_timer",			cmdSetTimer,	ADMFLAG_RCON, "设置特感生成时间");

	RegAdminCmd("sm_resetspawn",	cmdResetSpawn,	ADMFLAG_RCON, "处死所有特感并重新开始生成计时");
	RegAdminCmd("sm_forcetimer",	cmdForceTimer,	ADMFLAG_RCON, "开始生成计时");
	RegAdminCmd("sm_type",			cmdType,		ADMFLAG_ROOT, "随机轮换模式");

	HookEntityOutput("trigger_finale", "FinaleStart", OnFinaleStart);

	if (g_bLateLoad && L4D_HasAnySurvivorLeftSafeArea())
		L4D_OnFirstSurvivorLeftSafeArea_Post(0);
}

public void OnPluginEnd() {
	g_cvSpawnRange.RestoreDefault();
	g_cvDiscardRange.RestoreDefault();

	//FindConVar("director_no_specials").RestoreDefault();

	FindConVar("z_spawn_flow_limit").RestoreDefault();
	FindConVar("z_attack_flow_range").RestoreDefault();

	FindConVar("z_safe_spawn_range").RestoreDefault();
	FindConVar("z_spawn_safety_range").RestoreDefault();

	FindConVar("z_finale_spawn_safety_range").RestoreDefault();
	FindConVar("z_finale_spawn_tank_safety_range").RestoreDefault();
}

void OnFinaleStart(const char[] output, int caller, int activator, float delay) {
	g_bFinaleStarted = L4D_IsMissionFinalMap();
}

public Action L4D_OnGetScriptValueInt(const char[] key, int &retVal) {
	static int value;
	if (!g_bInSpawnTime) {
		if (strcmp(key, "MaxSpecials", false) == 0 || strcmp(key, "cm_MaxSpecials", false) == 0) {
			retVal = 0;
			return Plugin_Handled;
		}

		return Plugin_Continue;	
	}
	
	value = retVal;
	if (strcmp(key, "MaxSpecials", false) == 0 || strcmp(key, "cm_MaxSpecials", false) == 0)
		value = g_iSILimit;
	else if (strcmp(key, "PreferredSpecialDirection", false) == 0)
		value = g_iDirection;

	if (value != retVal) {
		retVal = value;
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public void L4D_OnFirstSurvivorLeftSafeArea_Post(int client) {
	if (g_bLeftSafeArea)
		return;

	g_bLeftSafeArea = true;

	if (g_iCurrentClass >= 6) {
		PrintToChatAll("\x03当前轮换\x01: \n");
		PrintToChatAll("\x01[\x05%s\x01]\x04模式\x01", g_sZombieClass[g_iCurrentClass - 6]);
	}
	else if (g_iCurrentClass > -1)
		PrintToChatAll("\x01[\x05%s\x01]\x04模式\x01", g_sZombieClass[g_iCurrentClass]);

	StartCustomSpawnTimer(g_fFirstSpawnTime);
	delete g_hSuicideTimer;
	g_hSuicideTimer = CreateTimer(2.0, tmrForceSuicide, _, TIMER_REPEAT);
}

Action tmrForceSuicide(Handle timer) {
	static int i;
	static int victim;
	static int zombieClass;
	static float engineTime;

	engineTime = GetEngineTime();
	for (i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || !IsFakeClient(i) || GetClientTeam(i) != 3 || !IsPlayerAlive(i))
			continue;

		zombieClass = GetEntProp(i, Prop_Send, "m_zombieClass");
		if (zombieClass < 1 || zombieClass > 6)
			continue;

		if (GetEntProp(i, Prop_Send, "m_hasVisibleThreats")) {
			g_fActionTimes[i] = engineTime;
			continue;
		}

		victim = GetSurVictim(i, zombieClass);
		if (victim > 0) {
			if (GetEntProp(victim, Prop_Send, "m_isIncapacitated"))
				KillInactiveSI(i);
			else
				g_fActionTimes[i] = engineTime;
		}
		else if (engineTime - g_fActionTimes[i] > g_fSuicideTime)
			KillInactiveSI(i);
	}

	return Plugin_Continue;
}

void KillInactiveSI(int client) {
	#if DEBUG
	PrintToServer("[SS] Kill inactive SI -> %N", client);
	#endif
	ForcePlayerSuicide(client);

	if (!g_hRetryTimer)
		CreateTimer(1.0, tmrRetrySpawn, true);
}

int GetSurVictim(int client, int zombieClass) {
	switch (zombieClass) {
		case 1:
			return GetEntPropEnt(client, Prop_Send, "m_tongueVictim");

		case 3:
			return GetEntPropEnt(client, Prop_Send, "m_pounceVictim");

		case 5:
			return GetEntPropEnt(client, Prop_Send, "m_jockeyVictim");

		case 6: {
			zombieClass = GetEntPropEnt(client, Prop_Send, "m_pummelVictim");
			if (zombieClass > 0)
				return zombieClass;

			zombieClass = GetEntPropEnt(client, Prop_Send, "m_carryVictim");
			if (zombieClass > 0)
				return zombieClass;
		}
	}

	return -1;
}

Action cmdSetLimit(int client, int args) {
	if (args == 1) {
		char arg[16];
		GetCmdArg(1, arg, sizeof arg);	
		if (strcmp(arg, "reset", false) == 0) {
			ResetLimits();
			ReplyToCommand(client, "[SS] Spawn Limits reset to default values");
		}
	}
	else if (args == 2) {
		int limit = GetCmdArgInt(2);	
		if (limit < 0)
			ReplyToCommand(client, "[SS] Limit value must be >= 0");
		else {
			char arg[16];
			GetCmdArg(1, arg, sizeof arg);
			if (strcmp(arg, "all", false) == 0) {
				for (int i; i < 6; i++)
					g_cvSpawnLimits[i].IntValue = limit;

				PrintToChatAll("\x01[SS] All SI limits have been set to \x05%d", limit);
			} 
			else if (strcmp(arg, "max", false) == 0) {
				g_cvSILimit.IntValue = limit;
				PrintToChatAll("\x01[SS] -> \x04Max \x01SI limit set to \x05%i", limit);				   
			} 
			else if (strcmp(arg, "group", false) == 0 || strcmp(arg, "wave", false) == 0) {
				g_cvSpawnSize.IntValue = limit;
				PrintToChatAll("\x01[SS] -> SI will spawn in \x04groups\x01 of \x05%i", limit);
			} 
			else  {
				for (int i; i < 6; i++) {
					if (strcmp(g_sZombieClass[i], arg, false) == 0) {
						g_cvSpawnLimits[i].IntValue = limit;
						PrintToChatAll("\x01[SS] \x04%s \x01limit set to \x05%i", arg, limit);
					}
				}
			}
		}	 
	} 
	else {
		ReplyToCommand(client, "\x04!limit/sm_limit \x05<class> <limit>");
		ReplyToCommand(client, "\x05<class> \x01[ all | max | group/wave | smoker | boomer | hunter | spitter | jockey | charger ]");
		ReplyToCommand(client, "\x05<limit> \x01[ >= 0 ]");
	}

	return Plugin_Handled;
}

Action cmdSetWeight(int client, int args) {
	if (args == 1) {
		char arg[16];
		GetCmdArg(1, arg, sizeof arg);	
		if (strcmp(arg, "reset", false) == 0) {
			ResetWeights();
			ReplyToCommand(client, "[SS] Spawn weights reset to default values");
		} 
	} 
	else if (args == 2) {
		if (GetCmdArgInt(2) < 0) {
			ReplyToCommand(client, "weight value >= 0");
			return Plugin_Handled;
		} 
		else  {
			char arg[16];
			GetCmdArg(1, arg, sizeof arg);
			int iWeight = GetCmdArgInt(2);
			if (strcmp(arg, "all", false) == 0) {
				for (int i; i < 6; i++)
					g_cvSpawnWeights[i].IntValue = iWeight;			

				ReplyToCommand(client, "\x01[SS] -> \x04All spawn weights \x01set to \x05%d", iWeight);	
			} 
			else  {
				for (int i; i < 6; i++) {
					if (strcmp(arg, g_sZombieClass[i], false) == 0) {
						g_cvSpawnWeights[i].IntValue = iWeight;
						ReplyToCommand(client, "\x01[SS] \x04%s \x01weight set to \x05%d", g_sZombieClass[i], iWeight);				
					}
				}	
			}
		}
	} 
	else 
	{
		ReplyToCommand(client, "\x04!weight/sm_weight \x05<class> <value>");
		ReplyToCommand(client, "\x05<class> \x01[ reset | all | smoker | boomer | hunter | spitter | jockey | charger ]");	
		ReplyToCommand(client, "\x05value \x01[ >= 0 ]");	
	}

	return Plugin_Handled;
}

Action cmdSetTimer(int client, int args) {
	if (args == 1) {
		float fTime = GetCmdArgFloat(1);
		if (fTime < 0.1)
			fTime = 0.1;

		g_cvSpawnTimeMin.FloatValue = fTime;
		g_cvSpawnTimeMax.FloatValue = fTime;
		ReplyToCommand(client, "\x01[SS] Spawn timer set to constant \x05%.1f \x01seconds", fTime);
	} 
	else if (args == 2) {
		float fMin = GetCmdArgFloat(1);
		float fMax = GetCmdArgFloat(2);
		if (fMin > 0.1 && fMax > 1.0 && fMax > fMin) {
			g_cvSpawnTimeMin.FloatValue = fMin;
			g_cvSpawnTimeMax.FloatValue = fMax;
			ReplyToCommand(client, "\x01[SS] Spawn timer will be between \x05%.1f \x01and \x05%.1f \x01seconds", fMin, fMax);
		} 
		else 
			ReplyToCommand(client, "[SS] Max(>= 1.0) spawn time must greater than min(>= 0.1) spawn time");
	} 
	else 
		ReplyToCommand(client, "[SS] timer <constant> || timer <min> <max>");

	return Plugin_Handled;
}

Action cmdResetSpawn(int client, int args) {	
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i) && GetEntProp(i, Prop_Send, "m_zombieClass") != 8)
			ForcePlayerSuicide(i);
	}

	StartCustomSpawnTimer(g_fSpawnTimes[0]);
	ReplyToCommand(client, "[SS] Slayed all special infected. Spawn timer restarted. Next potential spawn in %.1f seconds.", g_fSpawnTimeMin);
	return Plugin_Handled;
}

Action cmdForceTimer(int client, int args) {
	if (args < 1) {
		StartSpawnTimer();
		ReplyToCommand(client, "[SS] Spawn timer started manually.");
		return Plugin_Handled;
	}

	float fTime = GetCmdArgFloat(1);
	StartCustomSpawnTimer(fTime < 0.1 ? 0.1 : fTime);
	ReplyToCommand(client, "[SS] Spawn timer started manually. Next potential spawn in %.1f seconds.", fTime);
	return Plugin_Handled;
}

Action cmdType(int client, int args) {
	if (args != 1) {
		ReplyToCommand(client, "\x04!type/sm_type \x05<class>.");
		ReplyToCommand(client, "\x05<type> \x01[ off | random | smoker | boomer | hunter | spitter | jockey | charger ]");
		return Plugin_Handled;
	}

	char arg[16];
	GetCmdArg(1, arg, sizeof arg);
	if (strcmp(arg, "off", false) == 0) {
		g_iCurrentClass = -1;
		ReplyToCommand(client, "已关闭单一特感模式");
		ResetLimits();
	}
	else if (strcmp(arg, "random", false) == 0) {
		PrintToChatAll("\x03当前轮换\x01: \n");
		PrintToChatAll("\x01[\x05%s\x01]\x04模式\x01", g_sZombieClass[SetRandomType()]);
	}
	else {
		int class = GetZombieClass(arg);
		if (class == -1) {
			ReplyToCommand(client, "\x04!type/sm_type \x05<class>.");
			ReplyToCommand(client, "\x05<type> \x01[ off | random | smoker | boomer | hunter | spitter | jockey | charger ]");
		}
		else if (class == g_iCurrentClass)
			ReplyToCommand(client, "目标特感类型与当前特感类型相同");
		else {
			SetSiType(class);
			PrintToChatAll("\x01[\x05%s\x01]\x04模式\x01", g_sZombieClass[class]);
		}
	}

	return Plugin_Handled;
}

int GetZombieClass(const char[] sClass) {
	for (int i; i < 6; i++) {
		if (strcmp(sClass, g_sZombieClass[i], false) == 0)
			return i;
	}
	return -1;
}

int SetRandomType() {
	static int class;
	static int value;
	static int zombieClass[6] = {0, 1, 2, 3, 4, 5};
	if (class == 0)
		SortIntegers(zombieClass, 6, Sort_Random);

	SetSiType(zombieClass[class]);
	g_iCurrentClass += 6;
	value = class;

	class++;
	class -= RoundToFloor(class / 6.0) * 6;
	return zombieClass[(value - RoundToFloor(value / 6.0) * 6)];
}

void SetSiType(int class) {
	for (int i; i < 6; i++)		
		g_cvSpawnLimits[i].IntValue = i != class ? 0 : g_iSILimit;

	g_iCurrentClass = class;
}

public void OnConfigsExecuted() {
	GetCvars_Limits();
	GetCvars_Times();
	GetCvars_General();
	GetCvars_TankStatus();
	GetCvars_TankCustom();
	SetDirectorConvars();
}

void CvarChanged_Limits(ConVar convar, const char[] oldValue, const char[] newValue) {
	GetCvars_Limits();
}

void GetCvars_Limits() {
	g_iSpawnSize = g_cvSpawnSize.IntValue;
	for (int i; i < 6; i++)
		g_iSpawnLimits[i] = g_cvSpawnLimits[i].IntValue;
}

void CvarChanged_Times(ConVar convar, const char[] oldValue, const char[] newValue) {
	GetCvars_Times();
}

void GetCvars_Times() {
	g_iSILimit =		g_cvSILimit.IntValue;
	g_fSpawnTimeMin =	g_cvSpawnTimeMin.FloatValue;
	g_fSpawnTimeMax =	g_cvSpawnTimeMax.FloatValue;
	g_iSpawnTimeMode =	g_cvSpawnTimeMode.IntValue;

	if (g_fSpawnTimeMin > g_fSpawnTimeMax)
		g_fSpawnTimeMin = g_fSpawnTimeMax;
		
	CalculateSpawnTimes();
}

void CalculateSpawnTimes() {
	if (g_iSILimit <= 1 || g_iSpawnTimeMode <= 0)
		g_fSpawnTimes[0] = g_fSpawnTimeMax;
	else {
		float unit = (g_fSpawnTimeMax - g_fSpawnTimeMin) / (g_iSILimit - 1);
		switch (g_iSpawnTimeMode) {
			case 1:  {
				g_fSpawnTimes[0] = g_fSpawnTimeMin;
				for (int i = 1; i <= MaxClients; i++)
					g_fSpawnTimes[i] = i < g_iSILimit ? (g_fSpawnTimes[i - 1] + unit) : g_fSpawnTimeMax;
			}

			case 2:  {	
				g_fSpawnTimes[0] = g_fSpawnTimeMax;
				for (int i = 1; i <= MaxClients; i++)
					g_fSpawnTimes[i] = i < g_iSILimit ? (g_fSpawnTimes[i - 1] - unit) : g_fSpawnTimeMax;
			}
		}	
	} 
}

void CvarChanged_General(ConVar convar, const char[] oldValue, const char[] newValue) {
	GetCvars_General();
}

void GetCvars_General() {
	g_bScaleWeights =	g_cvScaleWeights.BoolValue;

	for (int i; i < 6; i++)
		g_iSpawnWeights[i] = g_cvSpawnWeights[i].IntValue;

	g_iBaseLimit =		g_cvBaseLimit.IntValue;
	g_fExtraLimit =		g_cvExtraLimit.FloatValue;
	g_iBaseSize =		g_cvBaseSize.IntValue;
	g_fExtraSize =		g_cvExtraSize.FloatValue;
	g_fSuicideTime =	g_cvSuicideTime.FloatValue;
	g_fRushDistance =	g_cvRushDistance.FloatValue;
	g_fFirstSpawnTime =	g_cvFirstSpawnTime.FloatValue;
}

void CvarChanged_TankStatus(ConVar convar, const char[] oldValue, const char[] newValue) {
	int lastValue = g_iTankStatusAction;

	GetCvars_TankStatus();
	if (lastValue != g_iTankStatusAction)
		TankStatusActoin(FindTank(-1));
}

void GetCvars_TankStatus() {
	g_iTankStatusAction = g_cvTankStatusAction.IntValue;
}

void CvarChanged_TankCustom(ConVar convar, const char[] oldValue, const char[] newValue) {
	GetCvars_TankCustom();
}

void GetCvars_TankCustom() {
	char temp[64];
	g_cvTankStatusLimits.GetString(temp, sizeof temp);

	char buffers[6][8];
	ExplodeString(temp, ";", buffers, sizeof buffers, sizeof buffers[]);
	
	int i;
	int value;
	for (; i < 6; i++) {
		if (buffers[i][0] == '\0') {
			g_iTankStatusLimits[i] = -1;
			continue;
		}
		
		if ((value = StringToInt(buffers[i])) < -1 || value > g_iSILimit) {
			g_iTankStatusLimits[i] = -1;
			buffers[i][0] = '\0';
			continue;
		}
	
		g_iTankStatusLimits[i] = value;
		buffers[i][0] = '\0';
	}
	
	g_cvTankStatusWeights.GetString(temp, sizeof temp);
	ExplodeString(temp, ";", buffers, sizeof buffers, sizeof buffers[]);
	
	for (i = 0; i < 6; i++) {
		if (buffers[i][0] == '\0' || (value = StringToInt(buffers[i])) < 0) {
			g_iTankStatusWeights[i] = -1;
			continue;
		}

		g_iTankStatusWeights[i] = value;
	}
}

void SetDirectorConvars() {
	g_cvSafeSpawnRange.IntValue = g_cvSpawnRangeMin.IntValue;
	g_cvSpawnRange.IntValue = g_cvSpawnRangeMax.IntValue;
	g_cvDiscardRange.IntValue = g_cvSpawnRange.IntValue + 500;

	//FindConVar("director_no_specials").IntValue = 1;

	FindConVar("z_spawn_flow_limit").IntValue = 999999;
	FindConVar("z_attack_flow_range").IntValue = 999999;

	FindConVar("z_spawn_safety_range").IntValue = 1;
	FindConVar("z_finale_spawn_safety_range").IntValue = 1;
	FindConVar("z_finale_spawn_tank_safety_range").IntValue = 1;
}

public void OnClientDisconnect(int client) {
	if (!client || !IsClientInGame(client) || GetClientTeam(client) != 3 || GetEntProp(client, Prop_Send, "m_zombieClass") != 8)
		return;
		
	CreateTimer(0.1, tmrTankDisconnect, _, TIMER_FLAG_NO_MAPCHANGE);
}

public void OnMapEnd() {
	g_bLeftSafeArea = false;
	g_bFinaleStarted = false;

	EndSpawnTimer();
	delete g_hSuicideTimer;
	TankStatusActoin(false);

	if (g_iCurrentClass >= 6)
		SetRandomType();
	else if (g_iCurrentClass > -1)
		SetSiType(g_iCurrentClass);
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
	OnMapEnd();
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
	EndSpawnTimer();
}

void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast) {
	if (!g_bLeftSafeArea)
		return;

	g_fActionTimes[GetClientOfUserId(event.GetInt("userid"))] = GetEngineTime();
	g_fActionTimes[GetClientOfUserId(event.GetInt("attacker"))] = GetEngineTime();
}

void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client))
		return;

	if (event.GetInt("team") == 2 || event.GetInt("oldteam") == 2) {
		delete g_hUpdateTimer;
		g_hUpdateTimer = CreateTimer(2.0, tmrUpdate);
	}
}

Action tmrUpdate(Handle timer) {
	g_hUpdateTimer = null;
	SetSpawnCount();
	return Plugin_Continue;
}

void SetSpawnCount() {
	int count;
	int limit;
	int spawnSize;
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && GetClientTeam(i) == 2)
			count++;
	}

	count -= 4;
	if (count < 1) {
		limit = g_iBaseLimit;
		spawnSize = g_iBaseSize;
	}
	else {
		limit = g_iBaseLimit + RoundToNearest(g_fExtraLimit * count);
		spawnSize = g_iBaseSize + RoundToNearest(count / g_fExtraSize);
	}

	if (limit == g_iSILimit && spawnSize == g_iSpawnSize)
		return;

	g_cvSILimit.IntValue = limit;
	g_cvSpawnSize.IntValue = spawnSize;
	PrintToChatAll("\x01[\x05%d特\x01/\x05次\x01] \x05%d特 \x01[\x03%.1f\x01~\x03%.1f\x01]\x04秒", spawnSize <= limit ? spawnSize : limit, limit, g_fSpawnTimeMin, g_fSpawnTimeMax);
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client) || GetClientTeam(client) != 3)
		return;

	if (GetEntProp(client, Prop_Send, "m_zombieClass") != 8)
		g_fActionTimes[client] = GetEngineTime();
	else
		CreateTimer(0.1, tmrTankSpawn, event.GetInt("userid"), TIMER_FLAG_NO_MAPCHANGE);
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client) || GetClientTeam(client) != 3)
		return;

	static int class;
	class = GetEntProp(client, Prop_Send, "m_zombieClass");
	if (class == 8 && !FindTank(client))
		TankStatusActoin(false);

	if (class != 4 && IsFakeClient(client))
		RequestFrame(NextFrame_KickBot, event.GetInt("userid"));
}

Action tmrTankSpawn(Handle timer, int client) {
	if (!(client = GetClientOfUserId(client)) || !IsClientInGame(client) || GetClientTeam(client) != 3 || !IsPlayerAlive(client) || GetEntProp(client, Prop_Send, "m_zombieClass") != 8 || FindTank(client))
		return Plugin_Stop;

	int totalLimit;
	int totalWeight;
	for (int i; i < 6; i++) {
		totalLimit += g_iSpawnLimits[i];
		totalWeight += g_iSpawnWeights[i];
	}

	if (totalLimit && totalWeight)
		TankStatusActoin(true);

	return Plugin_Continue;
}

void NextFrame_KickBot(any client) {
	if ((client = GetClientOfUserId(client)) && IsClientInGame(client) && !IsClientInKickQueue(client) && IsFakeClient(client))
		KickClient(client);
}

bool FindTank(int client) {
	for (int i = 1; i <= MaxClients; i++) {
		if (i != client && IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i) && GetEntProp(i, Prop_Send, "m_zombieClass") == 8)
			return true;
	}
	return false;
}

Action tmrTankDisconnect(Handle timer) {
	if (FindTank(-1))
		return Plugin_Stop;

	TankStatusActoin(false);
	return Plugin_Continue;
}

void TankStatusActoin(bool isTankAlive) {
	static bool loaded;
	if (!isTankAlive) {
		if (loaded) {
			loaded = false;
			LoadCacheSpawnLimits();
			LoadCacheSpawnWeights();
		}
	}
	else {
		if (!loaded && g_iTankStatusAction) {
			loaded = true;
			for (int i; i < 6; i++) {
				g_iSpawnLimitsCache[i] = g_iSpawnLimits[i];
				g_iSpawnWeightsCache[i] = g_iSpawnWeights[i];
			}
			LoadCacheTankCustom();
		}
	}
}

void LoadCacheSpawnLimits() {
	if (g_iSILimitCache != -1) {
		g_cvSILimit.IntValue = g_iSILimitCache;
		g_iSILimitCache = -1;
	}

	if (g_iSpawnSizeCache != -1) {
		g_cvSpawnSize.IntValue = g_iSpawnSizeCache;
		g_iSpawnSizeCache = -1;
	}

	for (int i; i < 6; i++) {		
		if (g_iSpawnLimitsCache[i] != -1) {
			g_cvSpawnLimits[i].IntValue = g_iSpawnLimitsCache[i];
			g_iSpawnLimitsCache[i] = -1;
		}
	}
}

void LoadCacheSpawnWeights() {
	for (int i; i < 6; i++) {		
		if (g_iSpawnWeightsCache[i] != -1) {
			g_cvSpawnWeights[i].IntValue = g_iSpawnWeightsCache[i];
			g_iSpawnWeightsCache[i] = -1;
		}
	}
}

void LoadCacheTankCustom() {
	for (int i; i < 6; i++) {
		if (g_iTankStatusLimits[i] != -1)
			g_cvSpawnLimits[i].IntValue = g_iTankStatusLimits[i];
			
		if (g_iTankStatusWeights[i] != -1)
			g_cvSpawnWeights[i].IntValue = g_iTankStatusWeights[i];
	}
}

void ResetLimits() {
	for (int i; i < 6; i++)
		g_cvSpawnLimits[i].RestoreDefault();
}

void ResetWeights() {
	for (int i; i < 6; i++)
		g_cvSpawnWeights[i].RestoreDefault();
}

void StartCustomSpawnTimer(float fTime) {
	EndSpawnTimer();
	g_hSpawnTimer = CreateTimer(fTime, tmrSpawnSpecial);
}

void StartSpawnTimer() {
	EndSpawnTimer();
	g_hSpawnTimer = CreateTimer(g_iSpawnTimeMode > 0 ? g_fSpawnTimes[GetTotalSI()] : Math_GetRandomFloat(g_fSpawnTimeMin, g_fSpawnTimeMax), tmrSpawnSpecial);
}

void EndSpawnTimer() {
	delete g_hSpawnTimer;
	delete g_hRetryTimer;
}

Action tmrSpawnSpecial(Handle timer) { 
	g_hSpawnTimer = null;
	delete g_hRetryTimer;

	int totalSI = GetTotalSI();
	ExecuteSpawnQueue(totalSI, true);

	g_hSpawnTimer = CreateTimer(g_iSpawnTimeMode > 0 ? g_fSpawnTimes[totalSI] : Math_GetRandomFloat(g_fSpawnTimeMin, g_fSpawnTimeMax), tmrSpawnSpecial);
	return Plugin_Continue;
}

void ExecuteSpawnQueue(int totalSI, bool retry) {
	if (totalSI >= g_iSILimit)
		return;

	#if BENCHMARK
	g_profiler = new Profiler();
	g_profiler.Start();
	#endif

	int allowedSI = g_iSILimit - totalSI;
	int spawnSize = g_iSpawnSize > allowedSI ? allowedSI : g_iSpawnSize;

	GetSITypeCount();

	int i;
	int index;
	ArrayList aQueue = new ArrayList();
	for (; i < spawnSize; i++) {
		index = GenerateIndex();
		if (index == -1)
			break;

		aQueue.Push(index);
		g_iSpawnCounts[index]++;
	}

	spawnSize = aQueue.Length;
	if (!spawnSize) {
		delete aQueue;
		return;
	}

	float flow;
	ArrayList aList = new ArrayList(2);
	for (i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && !GetEntProp(i, Prop_Send, "m_isIncapacitated")) {
			flow = L4D2Direct_GetFlowDistance(i);
			if (flow && flow != -9999.0)
				aList.Set(aList.Push(flow), i, 1);
		}
	}

	int count = aList.Length;
	if (!count) {
		delete aList;
		delete aQueue;
		return;
	}

	aList.Sort(Sort_Descending, Sort_Float);

	bool find;
	int client = aList.Get(0, 1);
	flow = aList.Get(0, 0);
	float lastFlow = aList.Get(count - 1, 0);
	if (flow - lastFlow > g_fRushDistance) {
		#if DEBUG
		PrintToServer("[SS] Rusher -> %N", client);
		#endif

		find = true;
	}

	delete aList;
	g_bInSpawnTime = true;
	//g_cvSpawnRange.IntValue = retry ? 1000 : 1500;
	g_iDirection = g_bFinaleStarted ? SPAWN_NEAR_IT_VICTIM : (!retry ? SPAWN_NO_PREFERENCE : (!find ? SPAWN_LARGE_VOLUME/*SPAWN_SPECIALS_ANYWHERE*/ : SPAWN_IN_FRONT_OF_SURVIVORS));

	count = 0;
	find = false;
	float vPos[3];
	for (i = 0; i < spawnSize; i++) {
		index = aQueue.Get(i) + 1;
		if (L4D_GetRandomPZSpawnPosition(client, index, 10, vPos))
			find = true;

		vPos[2] += 20.0;
		if (find && L4D2_SpawnSpecial(index, vPos, NULL_VECTOR) > 0)
			count++;

		vPos[2] -= 20.0;
	}

	g_bInSpawnTime = false;

	#if BENCHMARK
	g_profiler.Stop();
	PrintToServer("[SS] ProfilerTime: %f", g_profiler.Time);
	#endif

	if (retry) {
		if (!count) {
			#if DEBUG
			PrintToServer("[SS] Retry spawn SI! spawned:%d failed:%d", count, aQueue.Length - count);
			#endif
			g_hRetryTimer = CreateTimer(1.0, tmrRetrySpawn, false);
		}
	}
	#if DEBUG
	else {
		if (!count)
			PrintToServer("[SS] Spawn SI failed! spawned:%d failed:%d", count, aQueue.Length - count);
	}
	#endif

	delete aQueue;
}

Action tmrRetrySpawn(Handle timer, bool retry) {
	g_hRetryTimer = null;
	ExecuteSpawnQueue(GetTotalSI(), retry);
	return Plugin_Continue;
}

int GetTotalSI() {
	int count;
	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || IsClientInKickQueue(i) || GetClientTeam(i) != 3)
			continue;
	
		if (IsPlayerAlive(i)) {
			if (1 <= GetEntProp(i, Prop_Send, "m_zombieClass") <= 6)
				count++;
		}
		else if (IsFakeClient(i))
			KickClient(i);
	}
	return count;
}

void GetSITypeCount() {
	int i;
	for (; i < 6; i++)
		g_iSpawnCounts[i] = 0;

	for (i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || IsClientInKickQueue(i)|| GetClientTeam(i) != 3 || !IsPlayerAlive(i))
			continue;

		switch (GetEntProp(i, Prop_Send, "m_zombieClass")) {
			case 1:
				g_iSpawnCounts[SI_SMOKER]++;

			case 2:
				g_iSpawnCounts[SI_BOOMER]++;

			case 3:
				g_iSpawnCounts[SI_HUNTER]++;

			case 4:
				g_iSpawnCounts[SI_SPITTER]++;

			case 5:
				g_iSpawnCounts[SI_JOCKEY]++;
		
			case 6:
				g_iSpawnCounts[SI_CHARGER]++;
		}
	}
}

int GenerateIndex() {	
	static int i;
	static int totalWeight;
	static int standardizedWeight;
	static int tempWeights[6];
	static float unit;
	static float random;
	static float intervalEnds[6];

	totalWeight = 0;
	standardizedWeight = 0;

	for (i = 0; i < 6; i++) {
		tempWeights[i] = g_iSpawnCounts[i] < g_iSpawnLimits[i] ? (g_bScaleWeights ? ((g_iSpawnLimits[i] - g_iSpawnCounts[i]) * g_iSpawnWeights[i]) : g_iSpawnWeights[i]) : 0;
		totalWeight += tempWeights[i];
	}

	unit = 1.0 / totalWeight;
	for (i = 0; i < 6; i++) {
		if (tempWeights[i] >= 0) {
			standardizedWeight += tempWeights[i];
			intervalEnds[i] = standardizedWeight * unit;
		}
	}

	random = Math_GetRandomFloat(0.0, 1.0);
	for (i = 0; i < 6; i++) {
		if (tempWeights[i] > 0 && intervalEnds[i] >= random)
			return i;
	}

	return -1;
}

// https://github.com/bcserv/smlib/blob/transitional_syntax/scripting/include/smlib/math.inc
/**
 * Returns a random, uniform Float number in the specified (inclusive) range.
 * This is safe to use multiple times in a function.
 * The seed is set automatically for each plugin.
 *
 * @param min			Min value used as lower border
 * @param max			Max value used as upper border
 * @return				Random Float number between min and max
 */
float Math_GetRandomFloat(float min, float max)
{
	return (GetURandomFloat() * (max  - min)) + min;
}