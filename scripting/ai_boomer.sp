#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

ConVar
	g_hBoomerBhop,
	g_hVomitRange;

bool
	g_bBoomerBhop;

float
	g_fVomitRange;

public Plugin myinfo = {
	name = "AI BOOMER",
	author = "Breezy",
	description = "Improves the AI behaviour of special infected",
	version = "1.0",
	url = "github.com/breezyplease"
};

public void OnPluginStart() {
	g_hBoomerBhop = CreateConVar("ai_boomer_bhop", "1", "Flag to enable bhop facsimile on AI boomers");
	g_hVomitRange = FindConVar("z_vomit_range");
	
	g_hBoomerBhop.AddChangeHook(CvarChanged);
	g_hVomitRange.AddChangeHook(CvarChanged);

	HookEvent("ability_use", Event_AbilityUse);
}

public void OnPluginEnd() {
	FindConVar("z_vomit_fatigue").RestoreDefault();
	FindConVar("z_boomer_near_dist").RestoreDefault();
}

public void OnConfigsExecuted() {
	GetCvars();
	TweakSettings();
}

void CvarChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	GetCvars();
}

void GetCvars() {
	g_bBoomerBhop = g_hBoomerBhop.BoolValue;
	g_fVomitRange = g_hVomitRange.FloatValue;
}

void TweakSettings() {
	FindConVar("z_vomit_fatigue").IntValue =	0;
	FindConVar("z_boomer_near_dist").IntValue =	1;
}

void Event_AbilityUse(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client) || !IsFakeClient(client))
		return;

	static char ability[16];
	event.GetString("ability", ability, sizeof ability);
	if (strcmp(ability, "ability_vomit") == 0) {
		int flags = GetEntityFlags(client) & ~FL_ONGROUND;
		SetEntityFlags(client, flags & ~FL_FROZEN);
		Boomer_OnVomit(client);
		SetEntityFlags(client, flags);
	}
}

int g_iCurTarget[MAXPLAYERS + 1];
public Action L4D2_OnChooseVictim(int specialInfected, int &curTarget) {
	g_iCurTarget[specialInfected] = curTarget;
	return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int &buttons) {
	if (!g_bBoomerBhop)
		return Plugin_Continue;

	if (!IsClientInGame(client) || !IsFakeClient(client) || GetClientTeam(client) != 3 || !IsPlayerAlive(client) || GetEntProp(client, Prop_Send, "m_zombieClass") != 2 || GetEntProp(client, Prop_Send, "m_isGhost") )
		return Plugin_Continue;

	if (L4D_IsPlayerStaggering(client))
		return Plugin_Continue;

	if (!IsGrounded(client) || GetEntityMoveType(client) == MOVETYPE_LADDER || GetEntProp(client, Prop_Data, "m_nWaterLevel") > 1 && (!GetEntProp(client, Prop_Send, "m_hasVisibleThreats") && !TargetSur(client)))
		return Plugin_Continue;

	static float vVel[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVel);
	if (SquareRoot(Pow(vVel[0], 2.0) + Pow(vVel[1], 2.0)) < GetEntPropFloat(client, Prop_Send, "m_flMaxspeed") - 10.0)
		return Plugin_Continue;

	static float curTargetDist;
	static float nearestSurDist;
	GetSurDistance(client, curTargetDist, nearestSurDist);
	if (curTargetDist > 0.50 * g_fVomitRange && -1.0 < nearestSurDist < 1000.0) {
		static float vAng[3];
		GetClientEyeAngles(client, vAng);
		return aBunnyHop(client, buttons, vAng);
	}

	return Plugin_Continue;
}

bool IsGrounded(int client) {
	int ent = GetEntPropEnt(client, Prop_Send, "m_hGroundEntity");
	return ent != -1 && IsValidEntity(ent);
}

bool TargetSur(int client) {
	return IsAliveSur(GetClientAimTarget(client, true));
}

Action aBunnyHop(int client, int &buttons, const float vAng[3]) {
	float vFwd[3];
	float vRig[3];
	float vDir[3];
	float vVel[3];
	bool pressed;
	if (buttons & IN_FORWARD || buttons & IN_BACK) {
		GetAngleVectors(vAng, vFwd, NULL_VECTOR, NULL_VECTOR);
		NormalizeVector(vFwd, vFwd);
		ScaleVector(vFwd, buttons & IN_FORWARD ? 180.0 : -90.0);
		pressed = true;
	}

	if (buttons & IN_MOVERIGHT || buttons & IN_MOVELEFT) {
		GetAngleVectors(vAng, NULL_VECTOR, vRig, NULL_VECTOR);
		NormalizeVector(vRig, vRig);
		ScaleVector(vRig, buttons & IN_MOVERIGHT ? 90.0 : -90.0);
		pressed = true;
	}

	if (pressed) {
		AddVectors(vFwd, vRig, vDir);
		GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vVel);
		AddVectors(vVel, vDir, vVel);
		if (!WontFall(client, vVel))
			return Plugin_Continue;

		buttons |= IN_DUCK;
		buttons |= IN_JUMP;
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vVel);
		return Plugin_Changed;
	}

	return Plugin_Continue;
}

bool WontFall(int client, const float vVel[3]) {
	static float vPos[3];
	static float vEnd[3];
	GetClientAbsOrigin(client, vPos);
	AddVectors(vPos, vVel, vEnd);

	static float vMins[3];
	static float vMaxs[3];
	GetClientMins(client, vMins);
	GetClientMaxs(client, vMaxs);

	static bool didHit;
	static Handle hTrace;
	static float vVec[3];
	static float vNor[3];
	static float vPlane[3];

	didHit = false;
	vPos[2] += 10.0;
	vEnd[2] += 10.0;
	hTrace = TR_TraceHullFilterEx(vPos, vEnd, vMins, vMaxs, MASK_PLAYERSOLID_BRUSHONLY, TraceEntityFilter);
	if (TR_DidHit(hTrace)) {
		didHit = true;
		TR_GetEndPosition(vVec, hTrace);
		NormalizeVector(vVel, vNor);
		TR_GetPlaneNormal(hTrace, vPlane);
		if (RadToDeg(ArcCosine(GetVectorDotProduct(vNor, vPlane))) > 135.0) {
			delete hTrace;
			return false;
		}
	}

	delete hTrace;
	if (!didHit)
		vVec = vEnd;

	static float vDown[3];
	vDown[0] = vVec[0];
	vDown[1] = vVec[1];
	vDown[2] = vVec[2] - 100000.0;

	hTrace = TR_TraceHullFilterEx(vVec, vDown, vMins, vMaxs, MASK_PLAYERSOLID_BRUSHONLY, TraceEntityFilter);
	if (TR_DidHit(hTrace)) {
		TR_GetEndPosition(vEnd, hTrace);
		if (vVec[2] - vEnd[2] > 104.0) {
			delete hTrace;
			return false;
		}

		static int ent;
		if ((ent = TR_GetEntityIndex(hTrace)) > MaxClients) {
			static char cls[13];
			GetEdictClassname(ent, cls, sizeof cls);
			if (strcmp(cls, "trigger_hurt") == 0) {
				delete hTrace;
				return false;
			}
		}
		delete hTrace;
		return true;
	}

	delete hTrace;
	return false;
}

bool TraceEntityFilter(int entity, int contentsMask) {
	if (entity <= MaxClients)
		return false;

	static char cls[9];
	GetEntityClassname(entity, cls, sizeof cls);
	if ((cls[0] == 'i' && strcmp(cls[1], "nfected") == 0) || (cls[0] == 'w' && strcmp(cls[1], "itch") == 0))
		return false;

	return true;
}

void GetSurDistance(int client, float &curTargetDist, float &nearestSurDist) {
	static float vPos[3];
	static float vTar[3];

	GetClientAbsOrigin(client, vPos);
	if (!IsAliveSur(g_iCurTarget[client]))
		curTargetDist = -1.0;
	else {
		GetClientAbsOrigin(g_iCurTarget[client], vTar);
		curTargetDist = GetVectorDistance(vPos, vTar);
	}

	static int i;
	static float dist;

	nearestSurDist = -1.0;
	GetClientAbsOrigin(client, vPos);
	for (i = 1; i <= MaxClients; i++) {
		if (i != client && IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i)) {
			GetClientAbsOrigin(i, vTar);
			dist = GetVectorDistance(vPos, vTar);
			if (nearestSurDist == -1.0 || dist < nearestSurDist)
				nearestSurDist = dist;
		}
	}
}

#define PLAYER_HEIGHT 72.0
void Boomer_OnVomit(int client) {
	static int target;
	target = g_iCurTarget[client];//GetClientAimTarget(client, true);
	if (!IsAliveSur(target))
		target = GetClosestSur(client, target, g_fVomitRange);

	if (target == -1)
		return;

	static float vPos[3];
	static float vTar[3];
	static float vVelocity[3];
	GetClientAbsOrigin(client, vPos);
	GetClientEyePosition(target, vTar);
	MakeVectorFromPoints(vPos, vTar, vVelocity);

	static float length;
	length = GetVectorLength(vVelocity);
	if (length < g_fVomitRange)
		length = 0.5 * g_fVomitRange;
	else {
		float height = vTar[2] - vPos[2];
		if (height > PLAYER_HEIGHT)
			length += GetVectorDistance(vPos, vTar) / length * PLAYER_HEIGHT;
	}

	static float vAngles[3];
	GetVectorAngles(vVelocity, vAngles);
	NormalizeVector(vVelocity, vVelocity);
	ScaleVector(vVelocity, length);
	TeleportEntity(client, NULL_VECTOR, vAngles, vVelocity);
}

bool IsAliveSur(int client) {
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client);
}

int GetClosestSur(int client, int iExclude = -1, float fDistance) {
	static int i;
	static int count;
	static float fDist;
	static float vPos[3];
	static float vTar[3];
	static int iTargets[MAXPLAYERS + 1];
	
	count = 0;
	GetClientEyePosition(client, vPos);
	count = GetClientsInRange(vPos, RangeType_Visibility, iTargets, MAXPLAYERS);
	
	if (!count)
		return -1;
			
	static int target;
	static ArrayList aTargets;
	aTargets = new ArrayList(2);
	for (i = 0; i < count; i++) {
		target = iTargets[i];
		if (target && target != iExclude && GetClientTeam(target) == 2 && IsPlayerAlive(target) && !GetEntProp(target, Prop_Send, "m_isIncapacitated")) {
			GetClientAbsOrigin(target, vTar);
			fDist = GetVectorDistance(vPos, vTar);
			if (fDist < fDistance)
				aTargets.Set(aTargets.Push(fDist), target, 1);
		}
	}

	if (!aTargets.Length) {
		delete aTargets;
		return -1;
	}

	aTargets.Sort(Sort_Ascending, Sort_Float);
	target = aTargets.Get(0, 1);
	delete aTargets;
	return target;
}