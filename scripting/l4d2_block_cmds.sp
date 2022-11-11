#pragma semicolon 1
//強制1.7以後的新語法
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

ConVar g_hBlockCmds, g_hPunishType, g_hBanTime;
char g_sBlockCmds[64][32];
int g_iBlockCmdsCount;

public Plugin myinfo = 
{
	name = "block cmds",
	author = "sorallll",
	description = "",
	version = "1.0",
	url = ""
}

public void OnPluginStart()
{
	g_hBlockCmds	= CreateConVar("blockcmds_list", "sm_pw;sm_rpg;sm_boom;sm_explode;sm_vip;sm_help", "使用';'号分隔要禁用的命令.");
	g_hPunishType	= CreateConVar("l4d2_blockcmds_punish_Type", "0", "玩家输入了限制的指令后的惩罚方式. 0=仅提示, 1=处死, 2=踢出, 3=封禁.");
	g_hBanTime		= CreateConVar("l4d2_blockcmds_punish_time", "5", "设置被封禁的时间(分钟). 0=永久封禁.");

	AutoExecConfig(true,"l4d2_block_cmds");

	g_hBlockCmds.AddChangeHook(ConVarChanged);
}

public void OnConfigsExecuted()
{
	GetCmds();
}

public void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCmds();
}

void GetCmds()
{
	for(int i; i <= 63; i++)
	{
		if(g_sBlockCmds[i][0] != 0)
		{
			RemoveCommandListener(CmdIntercept, g_sBlockCmds[i]);
			g_sBlockCmds[i][0] = 0;
		}
	}

	char sCmds[2048];
	g_hBlockCmds.GetString(sCmds, sizeof(sCmds));
	g_iBlockCmdsCount = ReplaceString(sCmds, sizeof(sCmds), ";", ";", false);
	ExplodeString(sCmds, ";", g_sBlockCmds, g_iBlockCmdsCount + 1, 32);
	for(int i; i <= g_iBlockCmdsCount; i++)
	{
		AddCommandListener(CmdIntercept, g_sBlockCmds[i]);
	}
}

public Action CmdIntercept(int client, const char[] Command, int args)
{
	if(client && IsClientInGame(client))
	{
		//PrintHintText(client, "傻逼");
		//FakeClientCommandEx(client, "say 我是傻逼");
		PunishType(client);
	}

	return Plugin_Stop;
}

public Action OnClientSayCommand(int client, const char[] commnad, const char[] args)
{
	if(strlen(args) <= 1 || strncmp(commnad, "say", 3, false) != 0)
		return Plugin_Continue;

	if((args[0] == '!' || args[0] == '/') && IsAllowChatBlock(args))
	{
		if(client && IsClientInGame(client))
		{
			//PrintHintText(client, "傻逼");
			//FakeClientCommandEx(client, "say 我是傻逼");
			PunishType(client);
		}

		return Plugin_Handled;
	}

	return Plugin_Continue;
}

void PunishType(int client)
{
	switch(g_hPunishType.IntValue)
	{
		case 0:
			PrintToChat(client, "\x04[提示]\x03%N\x05,请勿使用奇怪的指令.", client);
		case 1:
		{
			CheckIdleBot(client);
			PrintToChat(client, "\x04[提示]\x03%N\x05,由于你使用了奇怪的指令,已被处死.", client);
		}
		case 2:
			KickClient(client, "[提示]由于你使用了奇怪的指令,已被踢出服务器.");
		case 3:
			BanClient(client, g_hBanTime.IntValue, BANFLAG_AUTO, "Banned", "[提示]由于你使用了奇怪的指令,已被封禁.");
	}
}

bool IsAllowChatBlock(const char[] Command)
{
	for(int i; i <= g_iBlockCmdsCount; i++)
	{
		if((strncmp(g_sBlockCmds[i], "sm_", 3, false) == 0 && strncmp(g_sBlockCmds[i][3], Command[1], strlen(g_sBlockCmds[i][3]), false) == 0) || strncmp(g_sBlockCmds[i], Command[1], strlen(g_sBlockCmds[i]), false) == 0)
			return true;
	}

	return false;
}

int GetBotOfIdle(int client)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(GetIdlePlayer(i) == client) 
			return i;
	}
	return 0;
}

int GetIdlePlayer(int client)
{
	if(IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client))
	{
		if(HasEntProp(client, Prop_Send, "m_humanSpectatorUserID"))
		{
			client = GetClientOfUserId(GetEntProp(client, Prop_Send, "m_humanSpectatorUserID"));			
			if(client > 0 && IsClientInGame(client) && GetClientTeam(client) == 1)
				return client;
		}
	}
	return 0;
}

void CheckIdleBot(int client)
{
	if(GetClientTeam(client) == 1)
	{
		int bot = GetBotOfIdle(client);
		if(bot)
			ForcePlayerSuicide(bot);
		else
			ForcePlayerSuicide(client);
	}
	else
		ForcePlayerSuicide(client);
}