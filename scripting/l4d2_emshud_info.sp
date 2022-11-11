#pragma semicolon 1
//強制1.7以後的新語法
#pragma newdecls required
#include <sourcemod>
#include <l4d2_ems_hud>

#define CVAR_FLAGS		FCVAR_NOTIFY
#define PLUGIN_VERSION	"1.9.10"

//设置数组数量(最大值:9).
#define SurvivorArray	9

bool  g_bMapRunTime, g_bShowHUD;
float g_fMapRunTime;

int    g_iPlayerNum, g_iChapterTotal[2], g_iCumulativeTotal[2], g_iKillSpecialNumber[MAXPLAYERS+1], g_iHeadSpecialNumber[MAXPLAYERS+1];

int    g_iSurvivorHealth, g_iMaxReviveCount, g_iFakeRanking, g_iTypeRanking, g_iInfoRanking;
ConVar g_hSurvivorHealth, g_hMaxReviveCount, g_hFakeRanking, g_hTypeRanking, g_hInfoRanking;

char sDate[][] = {"天", "时", "分", "秒"};
char g_sWeekName[][] = {"一", "二", "三", "四", "五", "六", "日"};

Handle g_hHostName, g_hTimerHUD;

public Plugin myinfo = 
{
	name 			= "l4d2_emshud_info",
	author 			= "豆瓣酱な | HUD提供者:Mr Cheng",
	description 	= "HUD显示各种信息.",
	version 		= PLUGIN_VERSION,
	url 			= "N/A"
}

public void OnPluginStart()
{
	HookEvent("player_death", Event_PlayerDeath);	//玩家死亡.
	HookEvent("round_start", Event_RoundStart);		//回合开始.
	HookEvent("round_end", Event_RoundEnd);			//回合结束.
	
	g_hHostName			= FindConVar("hostname");
	g_hSurvivorHealth	= FindConVar("survivor_limp_health");
	g_hMaxReviveCount	= FindConVar("survivor_max_incapacitated_count");

	g_hFakeRanking	= CreateConVar("l4d2_emshud_ranking_fake", "0", "排行榜显示电脑幸存者? 0=显示, 1=忽略.", CVAR_FLAGS);
	g_hTypeRanking	= CreateConVar("l4d2_emshud_ranking_type", "1", "排行榜第二组显示什么? 0=血量, 1=爆头.", CVAR_FLAGS);
	g_hInfoRanking	= CreateConVar("l4d2_emshud_ranking_info", "8", "击杀特感排名显示多少行(最大值:8). 0=禁用.", CVAR_FLAGS);

	g_hSurvivorHealth.AddChangeHook(ConVarChanged);
	g_hMaxReviveCount.AddChangeHook(ConVarChanged);
	g_hFakeRanking.AddChangeHook(ConVarChanged);
	g_hTypeRanking.AddChangeHook(ConVarChanged);
	g_hInfoRanking.AddChangeHook(ConVarChanged);
	AutoExecConfig(true, "l4d2_emshud_info");//生成指定文件名的CFG.
}

public void OnConfigsExecuted()
{
	if (g_bMapRunTime == false)
	{
		g_bMapRunTime = true;
		g_fMapRunTime = GetEngineTime();
	}
}

public void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_iSurvivorHealth	= g_hSurvivorHealth.IntValue;
	g_iMaxReviveCount	= g_hMaxReviveCount.IntValue;
	g_iFakeRanking		= g_hFakeRanking.IntValue;
	g_iTypeRanking		= g_hTypeRanking.IntValue;
	g_iInfoRanking		= g_hInfoRanking.IntValue;
	
	if( g_iInfoRanking > SurvivorArray - 1)
		g_iInfoRanking = SurvivorArray - 1;
}

//玩家死亡.
public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int iHeadshot = GetEventInt(event, "headshot");

	if(IsValidClient(attacker) && GetClientTeam(attacker) == 2)
	{
		char classname[32];
		int entity = GetEventInt(event, "entityid");
		GetEdictClassname(entity, classname, sizeof(classname));
		if (IsValidEdict(entity) && strcmp(classname, "infected") == 0)
		{
			g_iChapterTotal[0] += 1;
			g_iCumulativeTotal[0] += 1;
		}
		if(IsValidClient(client) && GetClientTeam(client) == 3)
		{
			g_iChapterTotal[1] += 1;
			g_iCumulativeTotal[1] += 1;
			int iBot = IsClientIdle(attacker);
	
			if(iHeadshot)
				g_iHeadSpecialNumber[iBot != 0 ? iBot : attacker] += 1;
			g_iKillSpecialNumber[iBot != 0 ? iBot : attacker] += 1;
		}
	}
}

//玩家连接
public void OnClientConnected(int client)
{   
	g_iKillSpecialNumber[client] = 0;
	g_iHeadSpecialNumber[client] = 0;

	if (!IsFakeClient(client))
		g_iPlayerNum += 1;
}

//玩家离开.
public void OnClientDisconnect(int client)
{   
	g_iKillSpecialNumber[client] = 0;
	g_iHeadSpecialNumber[client] = 0;

	if (!IsFakeClient(client))
		g_iPlayerNum -= 1;
}

//地图开始
public void OnMapStart()
{
	GetCvars();
	EnableHUD();
	g_iPlayerNum = 0;
}

//回合开始.
public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_bShowHUD = true;
	
	//创建计时器显示HUD.
	IsCreateTimerShowHUD();
	//重置章节击杀特感和丧尸数量.
	for (int i = 0; i < sizeof(g_iChapterTotal); i++)
		g_iChapterTotal[i] = 0;//重置章节击杀特感和丧尸数量.
	//重置玩家击杀特感和丧尸数量.
	for (int i = 1; i <= MaxClients; i++)
	{
		g_iKillSpecialNumber[i] = 0;
		g_iHeadSpecialNumber[i] = 0;
	}
}

//回合结束.
public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	g_bShowHUD = false;
	//清除击杀HUD.
	IsRemoveHUD();
}

//创建计时器.
void IsCreateTimerShowHUD()
{
	if(g_hTimerHUD == null)//不存在计时器才创建.
		g_hTimerHUD = CreateTimer(1.0, DisplayInfo, _, TIMER_REPEAT);
}

public Action DisplayInfo(Handle timer)
{
	//清除击杀HUD.
	IsRemoveHUD();
	//显示所有HUD.
	IsShowallHUD();
	return Plugin_Continue;
}

//清除指定HUD.
void IsRemoveHUD()
{
	if (g_bShowHUD)
		return;
	/*
	//删除人数运行HUD.
	if(HUDSlotIsUsed(HUD_SCORE_1))
		RemoveHUD(HUD_SCORE_1);
	
	//删除击杀数量HUD.
	if(HUDSlotIsUsed(HUD_MID_BOX))
		RemoveHUD(HUD_MID_BOX);

	//删除运行时间HUD.
	if(HUDSlotIsUsed(HUD_SCORE_TITLE))
		RemoveHUD(HUD_SCORE_TITLE);
	
	//删除当前时间HUD.
	if(HUDSlotIsUsed(HUD_MID_TOP))
		RemoveHUD(HUD_MID_TOP);

	//删除玩家数量HUD.
	if(HUDSlotIsUsed(HUD_SCORE_4))
		RemoveHUD(HUD_SCORE_4);

	//删除服名HUD.
	if(HUDSlotIsUsed(HUD_LEFT_TOP))
		RemoveHUD(HUD_LEFT_TOP);
	*/
	//删除玩家状态HUD.
	if(HUDSlotIsUsed(HUD_LEFT_BOT))
		RemoveHUD(HUD_LEFT_BOT);
	
	//删除击杀数量HUD.
	if(HUDSlotIsUsed(HUD_MID_BOT))
		RemoveHUD(HUD_MID_BOT);

	//删除爆头数量HUD.
	if(HUDSlotIsUsed(HUD_RIGHT_TOP))
		RemoveHUD(HUD_RIGHT_TOP);
	
	//删除玩家名字HUD.
	if(HUDSlotIsUsed(HUD_RIGHT_BOT))
		RemoveHUD(HUD_RIGHT_BOT);
}

//显示指定HUD.
void IsShowallHUD()
{
	//当前服务器时间.
	IsCurrentTime();
	//显示章节击杀数.
	IsChapterStatistics();
	//显示累计击杀数.
	IsCumulativeStatistics();
	//显示连接,闲置,旁观,特感和幸存者数量.
	IsPlayersNumber();
	//显示服务器名字.
	IsShowServerName();
	//显示服务器人数.
	IsShowServersNumber();
	//显示击杀特感排行榜.
	IsKillLeaderboards();
}

//显示服务器名字.
void IsShowServerName()
{
	char g_sHostName[256];
	GetConVarString(g_hHostName, g_sHostName, sizeof(g_sHostName));
	
	HUDSetLayout(HUD_LEFT_TOP, HUD_FLAG_ALIGN_CENTER|HUD_FLAG_NOBG|HUD_FLAG_TEXT|HUD_FLAG_BLINK, g_sHostName);
	HUDPlace(HUD_LEFT_TOP, 0.00,0.03, 1.0,0.03);
}

//显示当前和总人数.
void IsShowServersNumber()
{
	char g_sTotal[256];
	FormatEx(g_sTotal, sizeof(g_sTotal), "(%d/%d)", g_iPlayerNum, IsMaxPlayers());
	HUDSetLayout(HUD_SCORE_1, HUD_FLAG_ALIGN_CENTER|HUD_FLAG_NOBG|HUD_FLAG_TEXT, g_sTotal);
	HUDPlace(HUD_SCORE_1,0.00,0.00,1.0,0.03);
}

//显示击杀特感排行榜.
void IsKillLeaderboards()
{
	if (GetPlayersMaxNumber(2, false) <= 0 || g_iInfoRanking <= 0 || !g_bShowHUD)//没有幸存者或禁用时直接返回，不执行后面的操作.
		return;

	int temp[2], iMax[2], ranking_count = 1;
	int assister_count;
	int[][] assisters = new int[MaxClients][3];//更改为动态大小的数组.
	
	char State[SurvivorArray][128], sKill[SurvivorArray][128], sType[SurvivorArray][128], sName[SurvivorArray][128], g_sInfo[4][256];
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2)
		{
			int iBot = IsClientIdle(i);

			if (g_iFakeRanking != 0 && IsFakeClient(!iBot ? i : iBot))//这里判断是否显示电脑幸存者.
				continue;

			assisters[assister_count][0] = !iBot ? i : iBot;
			assisters[assister_count][1] = g_iKillSpecialNumber[!iBot ? i : iBot];
			assisters[assister_count][2] = g_iTypeRanking != 0 ? g_iHeadSpecialNumber[!iBot ? i : iBot] : GetSurvivorHP(i);
			assister_count+=1;
		}
	}
	//以最大击杀数排序.
	SortCustom2D(assisters, assister_count, ClientValue2DSortDesc);
	
	strcopy(State[0], sizeof(State[]), "   状态");//这里的空格用于排版对齐.
	strcopy(sKill[0], sizeof(sKill[]), "击杀");
	strcopy(sType[0], sizeof(sType[]), g_iTypeRanking != 0 ? "爆头" : "血量");
	strcopy(sName[0], sizeof(sName[]), "名字");
	
	for (int x = 0; x < g_iInfoRanking; x++)
	{
		int j = x + 1;
		int client	= assisters[x][0];
		int iKill	= assisters[x][1];
		int iType	= assisters[x][2];
		
		if (IsValidClient(client))//因为要显示闲置玩家的数据,所以这里不要判断团队.
		{
			int Player = iGetBotOfIdlePlayer(client);
			FormatEx(State[j], sizeof(State[]), "%d:%s", j, GetSurvivorStatus(Player != 0 ? Player : client));
			IntToString(iKill, sKill[j], sizeof(sKill[]));
			IntToString(iType, sType[j], sizeof(sType[]));
			strcopy(sName[j], sizeof(sName[]), GetTrueName(Player != 0 ? Player : client));
			ranking_count+=1;
		}
	}
	temp[0] = strlen(sKill[1]);
	temp[1] = strlen(sType[1]);

	for (int x = 1; x < ranking_count; x++)
	{ 
		if(strlen(sKill[x]) > temp[0])
			temp[0] = strlen(sKill[x]);
		if(strlen(sType[x]) > temp[1])
			temp[1] = strlen(sType[x]);
	}
	//这里必须重新循环,不然数字不能对齐.
	for (int y = 1; y < ranking_count; y++)
	{
		iMax[0] = temp[0] - strlen(sKill[y]);
		iMax[1] = temp[1] - strlen(sType[y]);

		if(iMax[0] > 0)
			Format(sKill[y], sizeof(sKill[]), "%s%s", GetAddSpacesMax(iMax[0], " "),  sKill[y]);//这里不能使用FormatEx
	
		if(iMax[1] > 0)
			Format(sType[y], sizeof(sType[]), "%s%s", GetAddSpacesMax(iMax[1], " "),  sType[y]);//这里不能使用FormatEx
	}
	
	ImplodeStrings(State, sizeof(State), "\n", g_sInfo[0], sizeof(g_sInfo[]));//打包字符串.
	ImplodeStrings(sKill, sizeof(sKill), "\n", g_sInfo[1], sizeof(g_sInfo[]));//打包字符串.
	ImplodeStrings(sType, sizeof(sType), "\n", g_sInfo[2], sizeof(g_sInfo[]));//打包字符串.
	ImplodeStrings(sName, sizeof(sName), "\n", g_sInfo[3], sizeof(g_sInfo[]));//打包字符串.
	
	HUDSetLayout(HUD_LEFT_BOT,HUD_FLAG_ALIGN_LEFT|HUD_FLAG_NOBG|HUD_FLAG_TEAM_SURVIVORS|HUD_FLAG_TEXT, g_sInfo[0]);
	HUDPlace(HUD_LEFT_BOT, 0.00,0.03,1.0,0.35);
	HUDSetLayout(HUD_MID_BOT,HUD_FLAG_ALIGN_LEFT|HUD_FLAG_NOBG|HUD_FLAG_TEAM_SURVIVORS|HUD_FLAG_TEXT, g_sInfo[1]);
	HUDPlace(HUD_MID_BOT, 0.075,0.03,1.0,0.35);
	HUDSetLayout(HUD_RIGHT_TOP,HUD_FLAG_ALIGN_LEFT|HUD_FLAG_NOBG|HUD_FLAG_TEAM_SURVIVORS|HUD_FLAG_TEXT, g_sInfo[2]);
	HUDPlace(HUD_RIGHT_TOP, 0.130,0.03,1.0,0.35);
	HUDSetLayout(HUD_RIGHT_BOT,HUD_FLAG_ALIGN_LEFT|HUD_FLAG_NOBG|HUD_FLAG_TEAM_SURVIVORS|HUD_FLAG_TEXT, g_sInfo[3]);
	HUDPlace(HUD_RIGHT_BOT, 0.182,0.03,1.0,0.35);
	//PrintToChatAll("\x04[提示]\x03%d-%d-%d-%d.", strlen(g_sInfo[0]), strlen(g_sInfo[1]), strlen(g_sInfo[2]), strlen(g_sInfo[3]));//聊天窗提示.
}

int ClientValue2DSortDesc(int[] elem1, int[] elem2, const int[][] array, Handle hndl)
{
	if (elem1[1] > elem2[1])
		return -1;
	else if (elem2[1] > elem1[1])
		return 1;
	return 0;
}

void IsPlayersNumber()
{
	char g_sLine[64];
	FormatEx(g_sLine, sizeof(g_sLine), "连接:%d 闲置:%d 旁观:%d 特感:%d/%d 幸存:%d/%d", 
	GetConnectionNumber(), GetPlayersStateNumber(1, true), GetPlayersStateNumber(1, false), GetPlayersMaxNumber(3, true), GetPlayersMaxNumber(3, false), GetPlayersMaxNumber(2, true), GetPlayersMaxNumber(2, false));
	HUDSetLayout(HUD_SCORE_4, HUD_FLAG_ALIGN_LEFT|HUD_FLAG_NOBG|HUD_FLAG_TEXT, g_sLine);
	HUDPlace(HUD_SCORE_4,0.00,0.00,1.0,0.03);
}

//显示服务器时间.
void IsCurrentTime()
{
	char g_sData[32], g_sTime[128];
	FormatTime(g_sData, sizeof(g_sData), "%Y-%m-%d %H:%M:%S");
	FormatEx(g_sTime, sizeof(g_sTime), "%s  星期%s", g_sData, IsWeekName());
	HUDSetLayout(HUD_MID_TOP, HUD_FLAG_ALIGN_RIGHT|HUD_FLAG_NOBG|HUD_FLAG_TEXT, g_sTime);
	HUDPlace(HUD_MID_TOP,0.00,0.00,1.0,0.03);
}

//显示运行时间.
void IsChapterStatistics()
{
	char g_sChapter[128];
	FormatEx(g_sChapter, sizeof(g_sChapter), "运行:%s", StandardizeTime(g_fMapRunTime));
	HUDSetLayout(HUD_SCORE_TITLE, HUD_FLAG_ALIGN_RIGHT|HUD_FLAG_NOBG|HUD_FLAG_TEXT, g_sChapter);
	HUDPlace(HUD_SCORE_TITLE,0.00,0.84,1.0,0.03);
}

//显示击杀数量.
void IsCumulativeStatistics()
{
	int temp[2];
	char g_sStatistics[128];
	for (int i = 0; i < sizeof(temp); i++)
		temp[i] = GetCharacterSize(g_iCumulativeTotal[i]) - GetCharacterSize(g_iChapterTotal[i]);
	FormatEx(g_sStatistics, sizeof(g_sStatistics), "累计:特感:%d 丧尸:%d\n章节:特感:%s%d 丧尸:%s%d", 
	g_iCumulativeTotal[1], g_iCumulativeTotal[0], GetAddSpacesMax(temp[1], "0"), g_iChapterTotal[1], GetAddSpacesMax(temp[0], "0"), g_iChapterTotal[0]);
	HUDSetLayout(HUD_MID_BOX, HUD_FLAG_ALIGN_RIGHT|HUD_FLAG_NOBG|HUD_FLAG_TEXT, g_sStatistics);
	HUDPlace(HUD_MID_BOX,0.00,0.03,1.0,0.07);
}

//填入对应数量的内容.
char[] GetAddSpacesMax(int Value, char[] sContent)
{
	char g_sBlank[64], g_sFill[10][64];
	for (int i = 0; i < Value; i++)
		strcopy(g_sFill[i], sizeof(g_sFill[]), sContent);
	ImplodeStrings(g_sFill, sizeof(g_sFill), "", g_sBlank, sizeof(g_sBlank));//打包字符串.
	return g_sBlank;
}

//返回对应的内容.
char[] GetTrueName(int client)
{
	char g_sName[14];//因为字符限制,显示8行只能限制到14个字符.
	int Bot = IsClientIdle(client);
	
	if(Bot != 0)
		FormatEx(g_sName, sizeof(g_sName), "闲置:%N", Bot);
	else
		GetClientName(client, g_sName, sizeof(g_sName));
	return g_sName;
}

//https://forums.alliedmods.net/showthread.php?t=288686
char[] StandardizeTime(float g_fRunTime)
{
	int iTime[4];
	char sName[128], sTime[4][32];
	float remainder = GetEngineTime() - g_fRunTime;
	
	iTime[0] = RoundToFloor(remainder / 86400.0);
	remainder = remainder - float(iTime[0] * 86400);
	iTime[1] = RoundToFloor(remainder / 3600.0);
	remainder = remainder - float(iTime[1] * 3600);
	iTime[2] = RoundToFloor(remainder / 60.0);
	remainder = remainder - float(iTime[2] * 60);
	iTime[3] = RoundToFloor(remainder);

	for (int i = 0; i < sizeof(sTime); i++)
		if(iTime[i] > 0)
			FormatEx(sTime[i], sizeof(sTime[]), "%d%s", iTime[i], sDate[i]);
	ImplodeStrings(sTime, sizeof(sTime), "", sName, sizeof(sName));//打包字符串.
	return sName;
}

//返回当前星期几.
char[] IsWeekName()
{
	char g_sWeek[8];
	FormatTime(g_sWeek, sizeof(g_sWeek), "%u");
	return g_sWeekName[StringToInt(g_sWeek) - 1];
}

//返回玩家状态.
char[] GetSurvivorStatus(int client)
{
	char g_sStatus[8];
	if (g_iMaxReviveCount <= 0)//玩家倒地次数设置0时把玩家状态显示为正常.
	{
		if (!IsPlayerAlive(client))
			strcopy(g_sStatus, sizeof(g_sStatus), "死亡");
		else if (IsPlayerFallen(client))
			strcopy(g_sStatus, sizeof(g_sStatus), "倒地");
		else if (IsPlayerFalling(client))
			strcopy(g_sStatus, sizeof(g_sStatus), "挂边");
		else
			strcopy(g_sStatus, sizeof(g_sStatus), GetSurvivorHP(client) < g_iSurvivorHealth ? "濒死" : "正常");
	}
	else
	{
		if(GetEntProp(client, Prop_Send, "m_currentReviveCount") == g_iMaxReviveCount)//判断是否黑白.
		{
			if (!IsPlayerAlive(client))
				strcopy(g_sStatus, sizeof(g_sStatus), "死亡");
			else
				strcopy(g_sStatus, sizeof(g_sStatus), GetSurvivorHP(client) < g_iSurvivorHealth ? "濒死" : "黑白");
		}
		else
			if (!IsPlayerAlive(client))
				strcopy(g_sStatus, sizeof(g_sStatus), "死亡");
			else if (IsPlayerFallen(client))
				strcopy(g_sStatus, sizeof(g_sStatus), "倒地");
			else if (IsPlayerFalling(client))
				strcopy(g_sStatus, sizeof(g_sStatus), "挂边");
			else
				strcopy(g_sStatus, sizeof(g_sStatus), GetSurvivorHP(client) < g_iSurvivorHealth ? "瘸腿" : "正常");
	}
	return g_sStatus;
}

//返回字符串实际大小.
int GetCharacterSize(int g_iSize)
{
	char sChapter[64];
	IntToString(g_iSize, sChapter, sizeof(sChapter));//格式化int类型为char类型.
	return strlen(sChapter);
}

//幸存者总血量.
int GetSurvivorHP(int client)
{
	int HP = GetClientHealth(client) + GetPlayerTempHealth(client);
	return IsPlayerAlive(client) ? HP > 999 ? 999 : HP : 0;//如果幸存者血量大于999就显示为999
}

//幸存者虚血量.
int GetPlayerTempHealth(int client)
{
    static Handle painPillsDecayCvar = null;
    if (painPillsDecayCvar == null)
    {
        painPillsDecayCvar = FindConVar("pain_pills_decay_rate");
        if (painPillsDecayCvar == null)
            return -1;
    }

    int tempHealth = RoundToCeil(GetEntPropFloat(client, Prop_Send, "m_healthBuffer") - ((GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * GetConVarFloat(painPillsDecayCvar))) - 1;
    return tempHealth < 0 ? 0 : tempHealth;
}

//获取正在连接的玩家数量.
int GetConnectionNumber()
{
	int count = 0;
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientConnected(i) && !IsClientInGame(i) && !IsFakeClient(i))
			count += 1;
	
	return count;
}

//获取闲置或旁观者数量.
int GetPlayersStateNumber(int iTeam, bool bClientTeam)
{
	int count = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == iTeam)
		{
			if (bClientTeam)
			{
				if (iGetBotOfIdlePlayer(i))
					count += 1;
			}
			else
			{
				if (!iGetBotOfIdlePlayer(i))
					count += 1;
			}
		}
	}
	return count;
}

//获取特感或幸存者数量.
int GetPlayersMaxNumber(int iTeam, bool bSurvive)
{
	int count = 0;
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && GetClientTeam(i) == iTeam)
			if (bSurvive)
			{
				if(IsPlayerAlive(i))
					count += 1;
			}
			else
				count += 1;
	
	return count;
}

//返回最大人数.
int IsMaxPlayers()
{
	int g_iMaxcl;
	Handle invalid = null;
	Handle downtownrun = FindConVar("l4d_maxplayers");
	Handle toolzrun = FindConVar("sv_maxplayers");
	if (downtownrun != (invalid))
	{
		int downtown = (GetConVarInt(FindConVar("l4d_maxplayers")));
		
		if (downtown >= 1)
			g_iMaxcl = (GetConVarInt(FindConVar("l4d_maxplayers")));
	}
	if (toolzrun != (invalid))
	{
		int toolz = (GetConVarInt(FindConVar("sv_maxplayers")));
		if (toolz >= 1)
			g_iMaxcl = (GetConVarInt(FindConVar("sv_maxplayers")));
	}
	if (downtownrun == (invalid) && toolzrun == (invalid))
		g_iMaxcl = (MaxClients);
	return g_iMaxcl;
}

//返回闲置玩家对应的电脑.
int iGetBotOfIdlePlayer(int client)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == 2 && IsClientIdle(i) == client)
			return i;
	}
	return 0;
}

//返回电脑幸存者对应的玩家.
int IsClientIdle(int client)
{
	if (!HasEntProp(client, Prop_Send, "m_humanSpectatorUserID"))
		return 0;

	return GetClientOfUserId(GetEntProp(client, Prop_Send, "m_humanSpectatorUserID"));
}

//挂边的
bool IsPlayerFalling(int client)
{
	return GetEntProp(client, Prop_Send, "m_isIncapacitated") && GetEntProp(client, Prop_Send, "m_isHangingFromLedge");
}

//倒地的.
bool IsPlayerFallen(int client)
{
	return GetEntProp(client, Prop_Send, "m_isIncapacitated") && !GetEntProp(client, Prop_Send, "m_isHangingFromLedge");
}

//判断玩家有效.
bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}