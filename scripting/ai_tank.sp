#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define SPEEDBOOST	90.0

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

	static float vVel[3];
	static float fSpeed;
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVel);
	fSpeed = SquareRoot(Pow(vVel[0], 2.0) + Pow(vVel[1], 2.0));
	if (fSpeed < GetEntPropFloat(client, Prop_Send, "m_flMaxspeed") - 10.0)
		return Plugin_Continue;

	static float vAng[3];
	if (IsGrounded(client)) {
		g_bModify[client] = false;

		static float curTargetDist;
		static float nearestSurDist;
		GetSurDistance(client, curTargetDist, nearestSurDist);
		if (curTargetDist > 0.5 * g_fTankAttackRange && -1.0 < nearestSurDist < 1000.0) {
			GetClientEyeAngles(client, vAng);
			return aBunnyHop(client, buttons, vAng);
		}
	}
	else {
		if (g_bModify[client] || fSpeed < GetEntPropFloat(client, Prop_Send, "m_flMaxspeed") + SPEEDBOOST)
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
		fSpeed = GetVectorDistance(vPos, vTar);
		if (fSpeed < g_fTankAttackRange || fSpeed > 440.0)
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

	static float length;
	length = GetVectorLength(vVectors);
	length = length > g_fTankThrowForce ? length : g_fTankThrowForce;
	NormalizeVector(vVectors, vVectors);
	ScaleVector(vVectors, length + g_fRunTopSpeed[target]);
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

bool HitWall(int iTank, int ent, int target = -1, const float vEnd[3] = NULL_VECTOR) {
	static float vSrc[3];
	static float vTar[3];
	GetClientEyePosition(iTank, vSrc);

	if (target == -1)
		vTar = vEnd;
	else
		GetClientEyePosition(target, vTar);

	static float vMins[3];
	static float vMaxs[3];
	GetEntPropVector(ent, Prop_Send, "m_vecMins", vMins);
	GetEntPropVector(ent, Prop_Send, "m_vecMaxs", vMaxs);

	static bool didHit;
	static Handle hTrace;
	hTrace = TR_TraceHullFilterEx(vSrc, vTar, vMins, vMaxs, MASK_SOLID, TraceEntityFilter, ent);
	didHit = TR_DidHit(hTrace);
	delete hTrace;
	return didHit;
}

int GetClosestSur(int client, int iExclude = -1, int ent, float fDistance) {
	static int i;
	static int count;
	static int index;
	static float fDist;
	static float vAng[3];
	static float vSrc[3];
	static float vTar[3];
	static int iTargets[MAXPLAYERS + 1];
	
	count = 0;
	GetClientEyePosition(client, vSrc);
	count = GetClientsInRange(vSrc, RangeType_Visibility, iTargets, MAXPLAYERS);

	if (!count)
		return -1;

	static ArrayList aClients;
	aClients = new ArrayList(3);
	float fFOV = GetFOVDotProduct(g_fAimOffsetSensitivity);
	for (i = 0; i < count; i++) {
		if (iTargets[i] && iTargets[i] != iExclude && GetClientTeam(iTargets[i]) == 2 && IsPlayerAlive(iTargets[i]) && !Incapacitated(iTargets[i]) && !IsPinned(iTargets[i]) && !HitWall(client, ent, iTargets[i])) {
			GetClientEyePosition(iTargets[i], vTar);
			fDist = GetVectorDistance(vSrc, vTar);
			if (fDist < fDistance) {
				index = aClients.Push(fDist);
				aClients.Set(index, iTargets[i], 1);

				GetClientEyeAngles(iTargets[i], vAng);
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
	static float vAngles[3], vLookAt[3];
	MakeVectorFromPoints(vPos, vTarget, vLookAt); // compute vector from start to target
	GetVectorAngles(vLookAt, vAngles); // get angles from vector for trace

	// execute Trace
	static Handle hTrace;
	static bool isVisible;

	isVisible = false;
	hTrace = TR_TraceRayFilterEx(vPos, vAngles, MASK_ALL, RayType_Infinite, TraceEntityFilter);
	if (TR_DidHit(hTrace)) {
		static float vStart[3];
		TR_GetEndPosition(vStart, hTrace); // retrieve our trace endpoint

		if ((GetVectorDistance(vPos, vStart, false) + 25.0) >= GetVectorDistance(vPos, vTarget))
			isVisible = true; // if trace ray length plus tolerance equal or bigger absolute distance, you hit the target
	}

	delete hTrace;
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