#include <sourcemod>
#define PLUGIN_VERSION "6.11.2"
#pragma semicolon 1
new Handle:g_sedirector;
new Handle:shutdownTimer;
new shutdownTime;
new String:g_latestMap[128];
new String:g_currentMap[128];
new g_latestPlayerCount;
new g_currentPlayerCount;

///////////////////////////////////////////////////////////////////////////
// Plugin Info
///////////////////////////////////////////////////////////////////////////
	public Plugin:myinfo =
	{
		name = "seDirector",
		author = "seDirector",
		description = "seDirector's SourceMod plugin to assist in updating/restarting servers automatically, reporting player count, and reporting current map.",
		version = PLUGIN_VERSION,
		url = "https://sedirector.net"
	};


	public OnPluginStart()
	{
		ServerCommand("sm_cvar sv_hibernate_when_empty 0");
		ServerCommand("sm_cvar tf_allow_server_hibernation 0");
		CreateConVar("sedirector_version", PLUGIN_VERSION, "seDirector version",FCVAR_NOTIFY);
		g_sedirector = CreateConVar("sedirector", "1", "0 = Disabled \n1 = Enabled");
	}

	public OnMapStart()
	{
		UpdateMap();
		CreateTimer(30.0, UpdatePlayerCount, _, TIMER_REPEAT);
		CreateTimer(30.0, CheckForUpdate, _, TIMER_REPEAT);
		CreateTimer(30.0, CheckForRestart, _, TIMER_REPEAT);
	}

///////////////////////////////////////////////////////////////////////////
// Current Map
///////////////////////////////////////////////////////////////////////////
	public UpdateMap() {
		GetCurrentMap(g_currentMap, sizeof(g_currentMap));
		if (!StrEqual(g_latestMap,g_currentMap)) {
			g_latestMap = g_currentMap;
			new Handle:sed_MapFile = OpenFile("seDirector.map","w");
			WriteFileLine(sed_MapFile, g_currentMap);
			if(sed_MapFile != INVALID_HANDLE) 
			{
				CloseHandle(sed_MapFile);
			}
		}
	}

///////////////////////////////////////////////////////////////////////////
// Player Count
///////////////////////////////////////////////////////////////////////////
	public Action:UpdatePlayerCount(Handle:timer) {
		new value = GetConVarInt(g_sedirector);
		if (value == 0) {
			return Plugin_Continue;
		} else {		
			g_currentPlayerCount = GetClientCount();
			if (g_latestPlayerCount != g_currentPlayerCount) {
				g_latestPlayerCount = g_currentPlayerCount;
				new Handle:sed_PlayersFile = OpenFile("seDirector.players","w");
				WriteFileLine(sed_PlayersFile, "%d", g_currentPlayerCount);
				if(sed_PlayersFile != INVALID_HANDLE)
				{
					CloseHandle(sed_PlayersFile);
				}
			}
		
		}
		return Plugin_Continue;
	}

///////////////////////////////////////////////////////////////////////////
// Update Request
///////////////////////////////////////////////////////////////////////////
	public Action:CheckForUpdate(Handle:timer) {
		new value = GetConVarInt(g_sedirector);
		if (value == 0) {
			return Plugin_Continue;
		} else {		
			if(FileExists("seDirector.update") == true) {		
				LogMessage("Update request detected.");
				shutdownTime = 60;
				shutdownTimer = CreateTimer(1.0, ShutItDownUpdate, _, TIMER_REPEAT);
				return Plugin_Stop;
			}
		}
		return Plugin_Continue;
	}

	public ShutDownPrintUpdate() {
		PrintHintTextToAll("Shutting down in %i seconds",shutdownTime);
	}

	public ShutDownFullPrintUpdate() {
		PrintToChatAll("Server shutting down for maintenance in %i seconds, please rejoin in 10 minutes.",shutdownTime);
		PrintCenterTextAll("Server shutting down for maintenance in %i seconds, please rejoin in 10 minutes.",shutdownTime);	
		LogMessage("%i second shutdown reminder",shutdownTime);
		
	}

	public Action:ShutItDownUpdate(Handle:timer) {
		if(shutdownTime == 60) {
			ShutDownFullPrintUpdate();
			ShutDownPrintUpdate();
		} else if (shutdownTime == 50) {
			ShutDownPrintUpdate();
		} else if (shutdownTime == 40) {
			ShutDownPrintUpdate();
		} else if (shutdownTime == 30) {
			ShutDownFullPrintUpdate();
			ShutDownPrintUpdate();
		} else if (shutdownTime == 20) {
			ShutDownPrintUpdate();
		} else if (shutdownTime <= 10) {
			if(shutdownTime == 10) {
				ShutDownFullPrintUpdate();
			}
			ShutDownPrintUpdate();
		}	
		shutdownTime--;
		if(shutdownTime <= -1) 
		{
			if (shutdownTimer != INVALID_HANDLE)
			{
				KillTimer(shutdownTimer);
				shutdownTimer = INVALID_HANDLE;
			}
			DeleteFile("seDirector.update");
			LogMessage("Server shutdown.");
			ServerCommand("quit");
			return Plugin_Handled;
		}
		return Plugin_Continue;
	}

///////////////////////////////////////////////////////////////////////////
// Restart Request
///////////////////////////////////////////////////////////////////////////
	public Action:CheckForRestart(Handle:timer) {
		new value = GetConVarInt(g_sedirector);
		if (value == 0) {
			return Plugin_Continue;
		} else {		
			if(FileExists("seDirector.restart") == true) {		
				LogMessage("Restart request detected.");
				shutdownTime = 60;
				shutdownTimer = CreateTimer(1.0, ShutItDownRestart, _, TIMER_REPEAT);
				return Plugin_Stop;
			}
		}
		return Plugin_Continue;
	}
	
	public ShutDownPrintRestart() {
		PrintHintTextToAll("Restarting in %i seconds",shutdownTime);
	}
	
	public ShutDownFullPrintRestart() {
		PrintToChatAll("Server restarting in %i seconds, please rejoin in 10 minutes.",shutdownTime);
		PrintCenterTextAll("Server restarting in %i seconds, please rejoin 10 minutes.",shutdownTime);	
		LogMessage("%i second restart reminder",shutdownTime);
	}
	
	public Action:ShutItDownRestart(Handle:timer) {
		if(shutdownTime == 60) {
			ShutDownFullPrintRestart();
			ShutDownPrintRestart();
		} else if (shutdownTime == 50) {
			ShutDownPrintRestart();
		} else if (shutdownTime == 40) {
			ShutDownPrintRestart();
		} else if (shutdownTime == 30) {
			ShutDownFullPrintRestart();
			ShutDownPrintRestart();
		} else if (shutdownTime == 20) {
			ShutDownPrintRestart();
		} else if (shutdownTime <= 10) {
			if(shutdownTime == 10) {
				ShutDownFullPrintRestart();
			}
			ShutDownPrintRestart();
		}	
		shutdownTime--;
		if(shutdownTime <= -1) 
		{
			if (shutdownTimer != INVALID_HANDLE)
			{
				KillTimer(shutdownTimer);
				shutdownTimer = INVALID_HANDLE;
			}
			DeleteFile("seDirector.restart");
			LogMessage("Server shutdown.");
			ServerCommand("quit");
			return Plugin_Handled;
		}
		return Plugin_Continue;
	}