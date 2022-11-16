#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

ConVar
	g_hTankBhop,
	g_hTankAttackRange,
	g_hTankThrowForce,
	g_hAimOffsetSensitivity;

bool
	g_bTankBhop;

float
	g_fTankAttackRange,
	g_fTankThrowForce,
	g_fAimOffsetSensitivity;

public Plugin myinfo = {
	name = "AI TANK",
	author = "Breezy",
	description = "Improves the AI behaviour of special infected",
	version = "1.0",
	url = "github.com/breezyplease"
};

public void OnPluginStart() {
	g_hTankBhop =				CreateConVar("ai_tank_bhop",					"1",	"Flag to enable bhop facsimile on AI tanks");
	g_hAimOffsetSensitivity =	CreateConVar("ai_aim_offset_sensitivity_tank",	"22.5",	"If the tank has a target, it will not straight throw if the target's aim on the horizontal axis is within this radius", _, true, 0.0, true, 180.0);
	g_hTankAttackRange =		FindConVar("tank_attack_range");
	g_hTankThrowForce =			FindConVar("z_tank_throw_force");

	g_hTankBhop.AddChangeHook(CvarChanged);
	g_hTankAttackRange.AddChangeHook(CvarChanged);
	g_hTankThrowForce.AddChangeHook(CvarChanged);
	g_hAimOffsetSensitivity.AddChangeHook(CvarChanged);
}

public void OnConfigsExecuted() {
	GetCvars();
}

void CvarChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	GetCvars();
}

void GetCvars() {
	g_bTankBhop =				g_hTankBhop.BoolValue;
	g_fTankAttackRange =		g_hTankAttackRange.FloatValue;
	g_fTankThrowForce =			g_hTankThrowForce.FloatValue;
	g_fAimOffsetSensitivity =	g_hAimOffsetSensitivity.FloatValue;
}

int g_iCurTarget[MAXPLAYERS + 1];
public Action L4D2_OnChooseVictim(int specialInfected, int &curTarget) {
	g_iCurTarget[specialInfected] = curTarget;
	return Plugin_Continue;
}

float g_fRunTopSpeed[MAXPLAYERS + 1];
public Action L4D_OnGetRunTopSpeed(int target, float &retVal) {
	g_fRunTopSpeed[target] = retVal;
	return Plugin_Continue;
}

bool g_bModify[MAXPLAYERS + 1];
public Action OnPlayerRunCmd(int client, int &buttons) {
	if (!g_bTankBhop)
		return Plugin_Continue;

	if (!IsClientInGame(client) || !IsFakeClient(client) || GetClientTeam(client) != 3 || !IsPlayerAlive(client) || GetEntProp(client, Prop_Send, "m_zombieClass") != 8 || GetEntProp(client, Prop_Send, "m_isGhost") == 1)
		return Plugin_Continue;

	if (L4D_IsPlayerStaggering(client))
		return Plugin_Continue;

	if (GetEntityMoveType(client) == MOVETYPE_LADDER || GetEntProp(client, Prop_Data, "m_nWaterLevel") > 1 || (!GetEntProp(client, Prop_Send, "m_hasVisibleThreats") && !TargetSur(client)))
		return Plugin_Continue;

	static float val;
	static float vVel[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVel);
	vVel[2] = 0.0;
	val = GetVectorLength(vVel);
	if (!CheckPlayerMove(client, val))
		return Plugin_Continue;

	static float vAng[3];
	if (IsGrounded(client)) {
		g_bModify[client] = false;

		static float curTargetDist;
		static float nearestSurDist;
		GetSurDistance(client, curTargetDist, nearestSurDist);
		if (curTargetDist > 0.5 * g_fTankAttackRange && -1.0 < nearestSurDist < 2000.0) {
			GetClientEyeAngles(client, vAng);
			return BunnyHop(client, buttons, vAng);
		}
	}
	else {
		if (g_bModify[client] || val < GetEntPropFloat(client, Prop_Send, "m_flMaxspeed") + 90.0)
			return Plugin_Continue;

		static int target;
		target = g_iCurTarget[client];//GetClientAimTarget(client, true);
		/*if (!IsAliveSur(target))
			target = g_iCurTarget[client];*/

		if (!IsAliveSur(target))
			return Plugin_Continue;

		static float vPos[3];
		static float vTar[3];
		static float vEye1[3];
		static float vEye2[3];
		GetClientAbsOrigin(client, vPos);
		GetClientAbsOrigin(target, vTar);
		val = GetVectorDistance(vPos, vTar);
		if (val < g_fTankAttackRange || val > 440.0)
			return Plugin_Continue;

		GetClientEyePosition(client, vEye1);
		if (vEye1[2] < vTar[2])
			return Plugin_Continue;

		GetClientEyePosition(target, vEye2);
		if (vPos[2] > vEye2[2])
			return Plugin_Continue;

		if (!IsVisibleTo(vEye2, vEye1))
			return Plugin_Continue;

		GetVectorAngles(vVel, vAng);
		vVel = vAng;
		vAng[0] = vAng[2] = 0.0;
		GetAngleVectors(vAng, vAng, NULL_VECTOR, NULL_VECTOR);
		NormalizeVector(vAng, vAng);

		static float vDir[2][3];
		vDir[0] = vPos;
		vDir[1] = vTar;
		vPos[2] = vTar[2] = 0.0;
		MakeVectorFromPoints(vPos, vEye2, vPos);
		NormalizeVector(vPos, vPos);
		if (RadToDeg(ArcCosine(GetVectorDotProduct(vAng, vPos))) < 90.0)
			return Plugin_Continue;

		MakeVectorFromPoints(vDir[0], vDir[1], vDir[0]);
		TeleportEntity(client, NULL_VECTOR, vVel, vDir[0]);
		g_bModify[client] = true;
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

public Action L4D2_OnSelectTankAttack(int client, int &sequence) {
	if (sequence != 50 || !IsFakeClient(client))
		return Plugin_Continue;

	sequence = Math_GetRandomInt(0, 1) ? 49 : 51;
	return Plugin_Handled;
}

#define PLAYER_HEIGHT 72.0
public Action L4D_TankRock_OnRelease(int tank, int rock, float vecPos[3], float vecAng[3], float vecVel[3], float vecRot[3]) {
	if (rock <= MaxClients || !IsValidEntity(rock))
		return Plugin_Continue;

	if (tank < 1 || tank > MaxClients || !IsClientInGame(tank)|| GetClientTeam(tank) != 3 || GetEntProp(tank, Prop_Send, "m_zombieClass") != 8)
		return Plugin_Continue;

	if (!IsFakeClient(tank) && (!CheckCommandAccess(tank, "", ADMFLAG_ROOT) || GetClientButtons(tank) & IN_SPEED == 0))
		return Plugin_Continue;

	static int target;
	target = GetClientAimTarget(tank, true);
	if (IsAliveSur(target) && !Incapacitated(target) && !IsPinned(target) && !HitWall(tank, rock, target) && !WithinViewAngle(tank, target, g_fAimOffsetSensitivity))
		return Plugin_Continue;
	
	target = GetClosestSur(tank, target, rock, 2.0 * g_fTankThrowForce);
	if (target == -1)
		return Plugin_Continue;

	static float vRock[3];
	static float vTar[3];
	static float vVectors[3];
	GetClientAbsOrigin(target, vTar);
	GetClientAbsOrigin(tank, vRock);
	float fDelta = GetVectorDistance(vRock, vTar) / g_fTankThrowForce * PLAYER_HEIGHT;

	vTar[2] += fDelta;
	while (fDelta < PLAYER_HEIGHT) {
		if (!HitWall(tank, rock, -1, vTar))
			break;

		fDelta += 10.0;
		vTar[2] += 10.0;
	}

	fDelta = vTar[2] - vRock[2];
	if (fDelta > PLAYER_HEIGHT)
		vTar[2] += fDelta / PLAYER_HEIGHT * 10.0;

	GetClientEyePosition(tank, vRock);
	MakeVectorFromPoints(vRock, vTar, vVectors);
	GetVectorAngles(vVectors, vTar);
	vecAng = vTar;

	static float vel;
	vel = GetVectorLength(vVectors);
	vel = vel > g_fTankThrowForce ? vel : g_fTankThrowForce;
	NormalizeVector(vVectors, vVectors);
	ScaleVector(vVectors, vel + g_fRunTopSpeed[target]);
	vecVel = vVectors;
	return Plugin_Changed;
}

bool IsAliveSur(int client) {
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client);
}

bool Incapacitated(int client) {
	return !!GetEntProp(client, Prop_Send, "m_isIncapacitated");
}

bool IsPinned(int client) {
	/*if (GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0)
		return true;*/
	if (GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0)
		return true;
	/*if (GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0)
		return true;*/
	if (GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0)
		return true;
	if (GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0)
		return true;
	return false;
}

bool HitWall(int tank, int ent, int target = -1, const float vEnd[3] = NULL_VECTOR) {
	static float vSrc[3];
	static float vTar[3];
	GetClientEyePosition(tank, vSrc);

	if (target == -1)
		vTar = vEnd;
	else
		GetClientEyePosition(target, vTar);

	static float vMins[3];
	static float vMaxs[3];
	GetEntPropVector(ent, Prop_Send, "m_vecMins", vMins);
	GetEntPropVector(ent, Prop_Send, "m_vecMaxs", vMaxs);

	static bool hit;
	static Handle hndl;
	hndl = TR_TraceHullFilterEx(vSrc, vTar, vMins, vMaxs, MASK_SOLID, TraceRockFilter, ent);
	hit = TR_DidHit(hndl);
	delete hndl;
	return hit;
}

bool TraceRockFilter(int entity, int contentsMask, any data) {
	if (entity == data)
		return false;

	if (entity > 0 && entity <= MaxClients)
		return false;

	static char cls[10];
	GetEntityClassname(entity, cls, sizeof cls);
	if ((cls[0] == 'i' && strcmp(cls[1], "nfected") == 0) || (cls[0] == 'w' && strcmp(cls[1], "itch") == 0))
		return false;

	return true;
}

int GetClosestSur(int client, int exclude = -1, int ent, float distance) {
	static int i;
	static int num;
	static int index;
	static float dist;
	static float vAng[3];
	static float vSrc[3];
	static float vTar[3];
	static int clients[MAXPLAYERS + 1];
	
	num = 0;
	GetClientEyePosition(client, vSrc);
	num = GetClientsInRange(vSrc, RangeType_Visibility, clients, MAXPLAYERS);

	if (!num)
		return -1;

	static ArrayList aClients;
	aClients = new ArrayList(3);
	float fFOV = GetFOVDotProduct(g_fAimOffsetSensitivity);
	for (i = 0; i < num; i++) {
		if (clients[i] && clients[i] != exclude && GetClientTeam(clients[i]) == 2 && IsPlayerAlive(clients[i]) && !Incapacitated(clients[i]) && !IsPinned(clients[i]) && !HitWall(client, ent, clients[i])) {
			GetClientEyePosition(clients[i], vTar);
			dist = GetVectorDistance(vSrc, vTar);
			if (dist < distance) {
				index = aClients.Push(dist);
				aClients.Set(index, clients[i], 1);

				GetClientEyeAngles(clients[i], vAng);
				aClients.Set(index, !PointWithinViewAngle(vTar, vSrc, vAng, fFOV) ? 0 : 1, 2);
			}
		}
	}

	if (!aClients.Length) {
		delete aClients;
		return -1;
	}

	aClients.Sort(Sort_Ascending, Sort_Float);
	index = aClients.FindValue(0, 2);
	i = aClients.Get(index != -1 && aClients.Get(index, 0) < g_fTankThrowForce ? index : Math_GetRandomInt(0, RoundToCeil((aClients.Length - 1) * 0.8)), 1);
	delete aClients;
	return i;
}

bool WithinViewAngle(int client, int viewer, float offsetThreshold) {
	static float vSrc[3];
	static float vTar[3];
	static float vAng[3];
	GetClientEyePosition(viewer, vSrc);
	GetClientEyePosition(client, vTar);
	if (IsVisibleTo(vSrc, vTar)) {
		GetClientEyeAngles(viewer, vAng);
		return PointWithinViewAngle(vSrc, vTar, vAng, GetFOVDotProduct(offsetThreshold));
	}

	return false;
}

// credits = "AtomicStryker"
bool IsVisibleTo(const float vPos[3], const float vTarget[3]) {
	static float vLookAt[3];
	MakeVectorFromPoints(vPos, vTarget, vLookAt);
	GetVectorAngles(vLookAt, vLookAt);

	static Handle hndl;
	hndl = TR_TraceRayFilterEx(vPos, vLookAt, MASK_VISIBLE, RayType_Infinite, TraceEntityFilter);

	static bool isVisible;
	isVisible = false;
	if (TR_DidHit(hndl)) {
		static float vStart[3];
		TR_GetEndPosition(vStart, hndl);

		if ((GetVectorDistance(vPos, vStart, false) + 25.0) >= GetVectorDistance(vPos, vTarget))
			isVisible = true;
	}

	delete hndl;
	return isVisible;
}

// https://github.com/nosoop/stocksoup

/**
 * Checks if a point is in the field of view of an object.  Supports up to 180 degree FOV.
 * I forgot how the dot product stuff works.
 * 
 * Direct port of the function of the same name from the Source SDK:
 * https://github.com/ValveSoftware/source-sdk-2013/blob/beaae8ac45a2f322a792404092d4482065bef7ef/sp/src/public/mathlib/vector.h#L461-L477
 * 
 * @param vecSrcPosition	Source position of the view.
 * @param vecTargetPosition	Point to check if within view angle.
 * @param vecLookDirection	The direction to look towards.  Note that this must be a forward
 * 							angle vector.
 * @param flCosHalfFOV		The width of the forward view cone as a dot product result. For
 * 							subclasses of CBaseCombatCharacter, you can use the
 * 							`m_flFieldOfView` data property.  To manually calculate for a
 * 							desired FOV, use `GetFOVDotProduct(angle)` from math.inc.
 * @return					True if the point is within view from the source position at the
 * 							specified FOV.
 */
bool PointWithinViewAngle(const float vecSrcPosition[3], const float vecTargetPosition[3], const float vecLookDirection[3], float flCosHalfFOV) {
	static float vecDelta[3];
	SubtractVectors(vecTargetPosition, vecSrcPosition, vecDelta);
	static float cosDiff;
	cosDiff = GetVectorDotProduct(vecLookDirection, vecDelta);
	if (cosDiff < 0.0)
		return false;

	// a/sqrt(b) > c  == a^2 > b * c ^2
	return cosDiff * cosDiff >= GetVectorLength(vecDelta, true) * flCosHalfFOV * flCosHalfFOV;
}

/**
 * Calculates the width of the forward view cone as a dot product result from the given angle.
 * This manually calculates the value of CBaseCombatCharacter's `m_flFieldOfView` data property.
 *
 * For reference: https://github.com/ValveSoftware/source-sdk-2013/blob/master/sp/src/game/server/hl2/npc_bullseye.cpp#L151
 *
 * @param angle     The FOV value in degree
 * @return          Width of the forward view cone as a dot product result
 */
float GetFOVDotProduct(float angle) {
	return Cosine(DegToRad(angle) / 2.0);
}

// https://github.com/bcserv/smlib/blob/transitional_syntax/scripting/include/smlib/math.inc
/**
 * Returns a random, uniform Integer number in the specified (inclusive) range.
 * This is safe to use multiple times in a function.
 * The seed is set automatically for each plugin.
 * Rewritten by MatthiasVance, thanks.
 *
 * @param min			Min value used as lower border
 * @param max			Max value used as upper border
 * @return				Random Integer number between min and max
 */
int Math_GetRandomInt(int min, int max)
{
	int random = GetURandomInt();

	if (random == 0) {
		random++;
	}

	return RoundToCeil(float(random) / (float(2147483647) / float(max - min + 1))) + min - 1;
}