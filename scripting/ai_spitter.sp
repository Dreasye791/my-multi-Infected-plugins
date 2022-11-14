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
	return vel > 0.0 && vel + 30.0 > GetEntPropFloat(client, Prop_Send, "m_flMaxspeed");
}
/*
Action BunnyHop(int client, int &buttons, const float vAng[3]) {
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
		if (WontFall(client, vVel)) {
			buttons |= IN_DUCK;
			buttons |= IN_JUMP;
			TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vVel);
			return Plugin_Changed;
		}
	}

	return Plugin_Continue;
}*/

Action BunnyHop(int client, int &buttons, const float vAng[3]) {
	float vVec[3];
	float vDir[3];
	float vVel[3];
	bool pressed;
	if (buttons & IN_FORWARD) {
		GetAngleVectors(vAng, vDir, NULL_VECTOR, NULL_VECTOR);
		NormalizeVector(vDir, vDir);
		ScaleVector(vDir, 180.0);
		pressed = true;
	}

	if (buttons & IN_BACK) {
		GetAngleVectors(vAng, vVec, NULL_VECTOR, NULL_VECTOR);
		NormalizeVector(vVec, vVec);
		ScaleVector(vVec, -90.0);
		if (!pressed)
			pressed = true;
		else
			AddVectors(vVec, vDir, vDir);
	}

	if (buttons & IN_MOVERIGHT) {
		GetAngleVectors(vAng, NULL_VECTOR, vVec, NULL_VECTOR);
		NormalizeVector(vVec, vVec);
		ScaleVector(vVec, 90.0);
		if (!pressed)
			pressed = true;
		else
			AddVectors(vVec, vDir, vDir);
	}

	if (buttons & IN_MOVELEFT) {
		GetAngleVectors(vAng, NULL_VECTOR, vVec, NULL_VECTOR);
		NormalizeVector(vVec, vVec);
		ScaleVector(vVec, -90.0);
		if (!pressed)
			pressed = true;
		else
			AddVectors(vVec, vDir, vDir);
	}

	if (pressed) {
		GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vVel);
		AddVectors(vVel, vDir, vVel);
		if (WontFall(client, vVel)) {
			buttons |= IN_DUCK;
			buttons |= IN_JUMP;
			TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vVel);
			return Plugin_Changed;
		}
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
	static Handle hndl;
	static float vVec[3];
	static float vNor[3];
	static float vPlane[3];

	didHit = false;
	vPos[2] += 10.0;
	vEnd[2] += 10.0;
	hndl = TR_TraceHullFilterEx(vPos, vEnd, vMins, vMaxs, MASK_PLAYERSOLID_BRUSHONLY, TraceEntityFilter);
	if (TR_DidHit(hndl)) {
		didHit = true;
		TR_GetEndPosition(vVec, hndl);
		NormalizeVector(vVel, vNor);
		TR_GetPlaneNormal(hndl, vPlane);
		if (RadToDeg(ArcCosine(GetVectorDotProduct(vNor, vPlane))) > 165.0) {
			delete hndl;
			return false;
		}
	}

	delete hndl;
	static float dist;
	if (!didHit)
		vVec = vEnd;
	else {
		MakeVectorFromPoints(vPos, vVec, vEnd);
		dist = GetVectorLength(vEnd) - 0.5 * (FloatAbs(vMaxs[0] - vMins[0])) - 3.0;
		NormalizeVector(vEnd, vEnd);
		ScaleVector(vEnd, dist);
		AddVectors(vPos, vEnd, vVec);
	}

	static float vDown[3];
	vDown[0] = vVec[0];
	vDown[1] = vVec[1];
	vDown[2] = vVec[2] - 100000.0;

	hndl = TR_TraceHullFilterEx(vVec, vDown, vMins, vMaxs, MASK_ALL, TraceSelfFilter, client);
	if (!TR_DidHit(hndl)) {
		delete hndl;
		return false;
	}

	TR_GetEndPosition(vEnd, hndl);
	if (vVec[2] - vEnd[2] > 104.0) {
		delete hndl;
		return false;
	}

	static int ent;
	ent = TR_GetEntityIndex(hndl);
	if (ent != -1) {
		static char cls[14];
		GetEntityClassname(ent, cls, sizeof cls);
		if (strcmp(cls, "trigger_hurt") == 0) {
			delete hndl;
			return false;
		}
	}

	delete hndl;
	return true;
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