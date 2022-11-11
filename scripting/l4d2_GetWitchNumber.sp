#pragma semicolon 1
//強制1.7以後的新語法
#pragma newdecls required
#include <sourcemod>
#define PLUGIN_VERSION	"1.0.0"
#define WITCH_LEN		32
int witchCUR;
int witchID[WITCH_LEN];

public Plugin myinfo = 
{
	name 			= "l4d2_given_witch_number",
	author 			= "豆瓣酱な",
	description 	= "给女巫添加编号.",
	version 		= PLUGIN_VERSION,
	url 			= "N/A"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("l4d2_GetWitchNumber");
	CreateNative("GetWitchNumber", GetWitchNumberNative);
	return APLRes_Success;
}

public void OnPluginStart()
{
	HookEvent("round_start",  Event_RoundStart, EventHookMode_Pre);
	HookEvent("witch_spawn",  Event_WitchSpawn, EventHookMode_Pre);
	HookEvent("witch_killed", Event_Witchkilled, EventHookMode_Pre);//女巫死亡.
}

public void Event_RoundStart(Event event, const char[] sName, bool bDontBroadcast)
{
	witchCUR = 0;
	for(int i = 0; i < WITCH_LEN; i ++)
		witchID[i] = -1;
}

public void Event_WitchSpawn(Event event, const char[] sName, bool bDontBroadcast)
{
	int iWitchid = event.GetInt( "witchid");
	witchID[witchCUR] = iWitchid;
	witchCUR = (witchCUR + 1) % WITCH_LEN;
}

public void Event_Witchkilled(Event event, const char[] name, bool dontBroadcast)
{
	int iWitchid = event.GetInt("witchid" );
	
	for(int i = 0; i < WITCH_LEN; i ++)
	{
		if(witchID[i] == iWitchid)
		{
			witchID[i] = -1;
			break;
		}
	}
}

int GetWitchNumberNative(Handle plugin, int numParams)
{
	int iWitchid = GetNativeCell(1);
	return GetWitchID(iWitchid);
}

int GetWitchID(int entity)
{
	for(int i = 0; i < sizeof(witchID); i ++)
	{
		if(witchID[i] == entity)
			return i;
	}
	return 0;
}