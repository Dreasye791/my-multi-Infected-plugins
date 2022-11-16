#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

ConVar
	g_hSpitterBhop;

bool
	g_bSpitterBhop;

public Plugin myinfo = {
	name = "AI SPITTER",
	author = "Breezy",
	description = "Improves the AI behaviour of special infected",
	version = "1.0",
	url = "github.com/breezyplease"
};

public void OnPluginStart() {
	g_hSpitterBhop = CreateConVar("ai_spitter_bhop", "1", "Flag to enable bhop facsimile on AI spitters");
	g_hSpitterBhop.AddChangeHook(CvarChanged);
}

public void OnConfigsExecuted() {
	GetCvars();
}

void CvarChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	GetCvars();
}

void GetCvars() {
	g_bSpitterBhop = g_hSpitterBhop.BoolValue;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3]) {
	if (!g_bSpitterBhop)
		return Plugin_Continue;

	if (!IsClientInGame(client) || !IsFakeClient(client) || GetClientTeam(client) != 3 || !IsPlayerAlive(client) || GetEntProp(client, Prop_Send, "m_zombieClass") != 4 || GetEntProp(client, Prop_Send, "m_isGhost") == 1)
		return Plugin_Continue;

	if (L4D_IsPlayerStaggering(client))
		return Plugin_Continue;

	if (IsGrounded(client) && GetEntityMoveType(client) != MOVETYPE_LADDER && GetEntProp(client, Prop_Data, "m_nWaterLevel") < 2 && GetEntProp(client, Prop_Send, "m_hasVisibleThreats")) {
		static float vVel[3];
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVel);
		vVel[2] = 0.0;
		if (!CheckPlayerMove(client, GetVectorLength(vVel)))
			return Plugin_Continue;
	
		if (150.0 < NearestSurDistance(client) < 2000.0) {
			static float vAng[3];
			GetClientEyeAngles(client, vAng);
			return BunnyHop(client, buttons, vAng);
		}
	}

	return Plugin_Continue;
}

bool IsGrounded(int client) {
	int ent = GetEntPropEnt(client, Prop_Send, "m_hGroundEntity");
	return ent != -1 && IsValidEntity(ent);
}

bool CheckPlayerMove(int client, float vel) {
	return vel > 0.9 * GetEntPropFloat(client, Prop_Send, "m_flMaxspeed") > 0.0;
}

Action BunnyHop(int client, int &buttons, const float vAng[3]) {
	float fwd[3];
	float rig[3];
	float vDir[3];
	float vVel[3];
	bool pressed;
	if (buttons & IN_FORWARD && !(buttons & IN_BACK)) {
		GetAngleVectors(vAng, fwd, NULL_VECTOR, NULL_VECTOR);
		NormalizeVector(fwd, fwd);
		ScaleVector(fwd, 180.0);
		pressed = true;
	}
	else if (buttons & IN_BACK && !(buttons & IN_FORWARD)) {
		GetAngleVectors(vAng, fwd, NULL_VECTOR, NULL_VECTOR);
		NormalizeVector(fwd, fwd);
		ScaleVector(fwd, -90.0);
		pressed = true;
	}

	if (buttons & IN_MOVERIGHT && !(buttons & IN_MOVELEFT)) {
		GetAngleVectors(vAng, NULL_VECTOR, rig, NULL_VECTOR);
		NormalizeVector(rig, rig);
		ScaleVector(rig, 90.0);
		pressed = true;
	}
	else if (buttons & IN_MOVELEFT && !(buttons & IN_MOVERIGHT)) {
		GetAngleVectors(vAng, NULL_VECTOR, rig, NULL_VECTOR);
		NormalizeVector(rig, rig);
		ScaleVector(rig, -90.0);
		pressed = true;
	}

	if (pressed) {
		AddVectors(fwd, rig, vDir);
		GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vVel);
		AddVectors(vVel, vDir, vVel);
		if (CheckHopVel(client, vVel)) {
			buttons |= IN_DUCK;
			buttons |= IN_JUMP;
			TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vVel);
			return Plugin_Changed;
		}
	}

	return Plugin_Continue;
}

bool CheckHopVel(int client, const float vVel[3]) {
	static float vPos[3];
	static float vEnd[3];
	GetClientAbsOrigin(client, vPos);
	AddVectors(vPos, vVel, vEnd);

	static float vMins[3];
	static float vMaxs[3];
	GetClientMins(client, vMins);
	GetClientMaxs(client, vMaxs);

	static bool hit;
	static float val;
	static Handle hndl;
	static float vVec[3];
	static float vNor[3];
	static float vPlane[3];

	hit = false;
	vPos[2] += 10.0;
	vEnd[2] += 10.0;
	hndl = TR_TraceHullFilterEx(vPos, vEnd, vMins, vMaxs, MASK_PLAYERSOLID, TraceEntityFilter);
	if (TR_DidHit(hndl)) {
		hit = true;
		TR_GetEndPosition(vVec, hndl);
		NormalizeVector(vVel, vNor);
		TR_GetPlaneNormal(hndl, vPlane);
		val = RadToDeg(ArcCosine(GetVectorDotProduct(vNor, vPlane)));
		if (val <= 90.0 || val > 165.0) {
			delete hndl;
			return false;
		}
	}

	delete hndl;
	if (!hit)
		vVec = vEnd;
	else {
		MakeVectorFromPoints(vPos, vVec, vEnd);
		val = GetVectorLength(vEnd) - 0.5 * (FloatAbs(vMaxs[0] - vMins[0])) - 3.0;
		if (val < 0.0)
			return false;

		NormalizeVector(vEnd, vEnd);
		ScaleVector(vEnd, val);
		AddVectors(vPos, vEnd, vVec);
	}

	static float vDown[3];
	vDown[0] = vVec[0];
	vDown[1] = vVec[1];
	vDown[2] = vVec[2] - 100000.0;

	hndl = TR_TraceHullFilterEx(vVec, vDown, vMins, vMaxs, MASK_PLAYERSOLID, TraceSelfFilter, client);
	if (!TR_DidHit(hndl)) {
		delete hndl;
		return false;
	}

	TR_GetEndPosition(vEnd, hndl);
	delete hndl;
	return vVec[2] - vEnd[2] < 104.0;
}

bool TraceSelfFilter(int entity, int contentsMask, any data) {
	return entity != data;
}

bool TraceEntityFilter(int entity, int contentsMask) {
	if (!entity || entity > MaxClients) {
		static char cls[5];
		GetEdictClassname(entity, cls, sizeof cls);
		return cls[3] != 'e' && cls[3] != 'c';
	}

	return false;
}

float NearestSurDistance(int client) {
	static int i;
	static float vPos[3];
	static float vTar[3];
	static float dist;
	static float minDist;

	minDist = -1.0;
	GetClientAbsOrigin(client, vPos);
	for (i = 1; i <= MaxClients; i++) {
		if (i != client && IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i)) {
			GetClientAbsOrigin(i, vTar);
			dist = GetVectorDistance(vPos, vTar);
			if (minDist == -1.0 || dist < minDist)
				minDist = dist;
		}
	}

	return minDist;
}