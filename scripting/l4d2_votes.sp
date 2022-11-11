#pragma semicolon 1
//強制1.7以後的新語法
#pragma newdecls required
#include <sourcemod>

#define VOTE_NO "no"
#define VOTE_YES "yes"

#define SCORE_DELAY_EMPTY_SERVER	3.0

//int Votey = 0;
//int Voten = 0;

char VotensKicks_ED[32];
char Votensdifficulty_ED[32];
char Votensrestart_ED[32];

ConVar g_VotensED, g_difficulty, g_VotensKicks, g_VotensKickstime, g_Votensrestart, g_Cvar_Limits, g_VotensED_sb, g_VotensED_time;
int hVotensED, hdifficulty, hVotensKicks, hVotensrestart, hVotensED_sb, hotensKickstime;
float hCvar_Limits, hVotensED_time;
Menu g_hVoteMenu;

Handle Changeleveltimer = null;

bool l4d2_VotensKicks_D;
bool l4d2_Votensdifficulty_D;
bool l4d2_Votensrestart_D;

bool l4d2_VotensKicks_D_true = true;
bool l4d2_Votensdifficulty_D_true = true;
bool l4d2_Votensrestart_D_true = true;

char kickplayer[MAX_NAME_LENGTH];
char kickplayername[MAX_NAME_LENGTH];
char votesmaps[MAX_NAME_LENGTH];
char votesmapsname[MAX_NAME_LENGTH];
char votesdifficulty[MAX_NAME_LENGTH];
char votesdifficultyname[MAX_NAME_LENGTH];

enum voteType
{
	maps,
	kicks,
	difficultys,
	restart
}

voteType g_voteType = maps;

public void OnPluginStart()
{
	RegConsoleCmd("sm_v", Command_Votes, "玩家投票菜单.");
	RegConsoleCmd("sm_votes", Command_Votes, "玩家投票菜单.");
	
	g_VotensED		= CreateConVar("l4d2_votens", "1", "启用投票更换地图,踢出玩家,更改难度? 0=禁用(总开关,禁用所有投票指令), 1=启用.", FCVAR_NOTIFY);
	g_difficulty		= CreateConVar("l4d2_votens_a_difficulty", "2", "启用投票更改难度? 0=禁用, 1=默认关闭, 2=默认开启.", FCVAR_NOTIFY);
	g_VotensKicks		= CreateConVar("l4d2_votens_a_kicks", "2", "启用投票踢出玩家? 0=禁用, 1=默认关闭, 2=默认开启.", FCVAR_NOTIFY);
	g_VotensKickstime	= CreateConVar("l4d2_votens_a_kicks_time", "30", "封禁被投票踢出的玩家多长时间/分钟.", FCVAR_NOTIFY);
	g_Votensrestart	= CreateConVar("l4d2_votens_a_restart", "2", "启用投票重启章节? 0=禁用, 1=默认关闭, 2=默认开启.", FCVAR_NOTIFY);
	g_Cvar_Limits		= CreateConVar("l4d2_votens_b_percent", "0.60", "设置投票通过所需的百分比. (最小值0.05) (最大值1)", 0);
	g_VotensED_sb		= CreateConVar("l4d2_votens_b_sb", "1", "启用开局公告投票指令. 0=禁用, 启用.", FCVAR_NOTIFY);
	g_VotensED_time	= CreateConVar("l4d2_votens_b_time", "13", "设置开局延迟显示投票指令的显示时间(秒).", FCVAR_NOTIFY);
	
	g_VotensED.AddChangeHook(CVARVotensChanged);
	g_difficulty.AddChangeHook(CVARVotensChanged);
	g_VotensKicks.AddChangeHook(CVARVotensChanged);
	g_VotensKickstime.AddChangeHook(CVARVotensChanged);
	g_Votensrestart.AddChangeHook(CVARVotensChanged);
	g_Cvar_Limits.AddChangeHook(CVARVotensChanged);
	g_VotensED_sb.AddChangeHook(CVARVotensChanged);
	g_VotensED_time.AddChangeHook(CVARVotensChanged);
	
	AutoExecConfig(true, "l4d2_votes");
	
	HookEvent("round_end", Event_RoundEnd, EventHookMode_Pre);//回合结束.
}

public void OnMapStart()
{
	GetVotensCvars();
}

public void CVARVotensChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetVotensCvars();
}

void GetVotensCvars()
{
	hVotensED = g_VotensED.IntValue;
	hdifficulty = g_difficulty.IntValue;
	hVotensKicks = g_VotensKicks.IntValue;
	hotensKickstime = g_VotensKickstime.IntValue;
	hVotensrestart = g_Votensrestart.IntValue;
	hCvar_Limits = g_Cvar_Limits.FloatValue;
	hVotensED_sb = g_VotensED_sb.IntValue;
	hVotensED_time = g_VotensED_time.FloatValue;
}


//回合结束.
public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	delete Changeleveltimer;
}

//地图结束.
public void OnMapEnd()
{
	delete Changeleveltimer;
}

//开局提示.
public void OnClientPutInServer(int client)
{
	if(IsFakeClient(client))
		return;

	if (hVotensED != 0  && hVotensED == 1)
	{
		CreateTimer(hVotensED_time, l4d2_Timer_Announce_VotensED, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action l4d2_Timer_Announce_VotensED(Handle timer, any client)
{
	if ((client = GetClientOfUserId(client)) && hVotensED_sb != 0)
	{
		if (client && IsClientInGame(client) && GetClientTeam(client) != 3)
		{
			PrintToChat(client, "\x04[提示]\x05聊天窗输入指令\x03!v\x05或\x03!votes\x05打开投票菜单.");//聊天窗提示.
		}
	}
	return Plugin_Continue;
}

public void OnConfigsExecuted()
{
	if(l4d2_VotensKicks_D_true)
	{
		if(hVotensKicks  == 1)
		{
			l4d2_VotensKicks_D = false;
		}
		else if(hVotensKicks  == 2)
		{
			l4d2_VotensKicks_D = true;
		}
	}
	if(l4d2_Votensdifficulty_D_true)
	{
		if(hdifficulty  == 1)
		{
			l4d2_Votensdifficulty_D = false;
		}
		else if(hdifficulty  == 2)
		{
			l4d2_Votensdifficulty_D = true;
		}
	}
	if(l4d2_Votensrestart_D_true)
	{
		if(hVotensrestart  == 1)
		{
			l4d2_Votensrestart_D = false;
		}
		else if(hVotensrestart  == 2)
		{
			l4d2_Votensrestart_D = true;
		}
	}
}

public Action Command_Votes(int client, int args)
{ 
	if(hVotensED == 1)
	{
		if(hVotensKicks != 0)
		{
			if(!l4d2_VotensKicks_D)
			{
				VotensKicks_ED = "开启";
			}
			else
			{
				VotensKicks_ED = "关闭";
			}
		}
		else
		{
			VotensKicks_ED = "已禁用";
		}
		
		if(hVotensrestart != 0)
		{
			if(!l4d2_Votensrestart_D)
			{
				Votensrestart_ED = "开启";
			}
			else
			{
				Votensrestart_ED = "关闭";
			}
		}
		else
		{
			Votensrestart_ED = "已禁用";
		}
		
		if(hdifficulty != 0)
		{
			if(!l4d2_Votensdifficulty_D)
			{
				Votensdifficulty_ED = "开启";
			}
			else
			{
				Votensdifficulty_ED = "关闭";
			}
		}
		else
		{
			Votensdifficulty_ED = "已禁用";
		}
		Handle menu = CreatePanel();
		char Value[64];
		SetPanelTitle(menu, "投票菜单");
		
		if(hVotensKicks != 0)
		{
			if(!l4d2_VotensKicks_D)
			{
				DrawPanelItem(menu, "投票踢出玩家已关闭");
			}
			else
			{
				DrawPanelItem(menu, "投票踢出玩家");
			}
		}
		else
		{
			DrawPanelItem(menu, "投票踢出玩家已禁用");
		}
		
		if(hVotensrestart != 0)
		{
			if(!l4d2_Votensrestart_D)
			{
				DrawPanelItem(menu, "投票重启章节已关闭");
			}
			else
			{
				DrawPanelItem(menu, "投票重启章节");
			}
		}
		else
		{
			DrawPanelItem(menu, "投票重启章节已禁用");
		}
		if(hdifficulty != 0)
		{
			if(!l4d2_Votensdifficulty_D)
			{
				DrawPanelItem(menu, "投票更改难度已关闭");
			}
			else
			{
				DrawPanelItem(menu, "投票更改难度");
			}
		}
		else
		{
			DrawPanelItem(menu, "投票更改难度已禁用");
		}
		if(bCheckClientAccess(client) && iGetClientImmunityLevel(client) >= 98)
		{
			DrawPanelText(menu, "管理员选项:");
			Format(Value, sizeof(Value), "%s 投票踢出玩家", VotensKicks_ED);
			DrawPanelItem(menu, Value);
			Format(Value, sizeof(Value), "%s 投票重启章节", Votensrestart_ED);
			DrawPanelItem(menu, Value);
			Format(Value, sizeof(Value), "%s 投票更改难度", Votensdifficulty_ED);
			DrawPanelItem(menu, Value);
		}
		DrawPanelText(menu, " \n");
		DrawPanelItem(menu, "关闭");
		//SetMenuExitButton(menu, true);
		SendPanelToClient(menu, client,Votes_Menu, 15);
	}
	else if(hVotensED == 0)
	{
		PrintToChat(client, "\x04[提示]\x05投票菜单也被腐竹禁用.");//聊天窗提示.
	}
	return Plugin_Handled;
}

public int Votes_Menu(Menu menu, MenuAction action, int client, int itemNum)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			switch (itemNum)
			{
				case 1: 
				{
					if(hVotensKicks != 0)
					{
						if(!l4d2_VotensKicks_D)
						{
							Command_Votes(client, false);
							PrintToChat(client, "\x04[提示]\x05管理员\x03已关闭\x05投票踢出玩家.");
						}
						else
						{
							Command_Voteskick(client, false);
						}
					}
					else
					{
						Command_Votes(client, false);
						PrintToChat(client, "\x04[提示]\x05服主\x03已禁用\x05投票踢出玩家.");
					}
				}
				case 2: 
				{
					if(hVotensrestart != 0)
					{
						if(!l4d2_Votensrestart_D)
						{
							Command_Votes(client, false);
							PrintToChat(client, "\x04[提示]\x05管理员\x03已关闭\x05投票重启章节.");
						}
						else
						{
							Command_votesrestartmenu(client, false);
						}
					}
					else
					{
						Command_Votes(client, false);
						PrintToChat(client, "\x04[提示]\x05服主\x03已禁用\x05投票重启章节.");
					}
				}
				case 3: 
				{
					if(hdifficulty != 0)
					{
						if(!l4d2_Votensdifficulty_D)
						{
							Command_Votes(client, false);
							PrintToChat(client, "\x04[提示]\x05管理员\x03已关闭\x05投票更换难度.");
						}
						else
						{
							Command_votesdifficultymenu(client, false);
						}
					}
					else
					{
						Command_Votes(client, false);
						PrintToChat(client, "\x04[提示]\x05服主\x03已禁用\x05投票更换难度.");
					}
				}
				case 4: 
				{
					if(bCheckClientAccess(client) && iGetClientImmunityLevel(client) >= 98)
					{
						if(hVotensKicks != 0)
						{
							if (!l4d2_VotensKicks_D)
							{
								l4d2_VotensKicks_D = true;
								l4d2_VotensKicks_D_true = false;
								PrintToChat(client, "\x04[提示]\x03已开启\x05投票踢出玩家.");
							}
							else
							{
								l4d2_VotensKicks_D = false;
								l4d2_VotensKicks_D_true = false;
								PrintToChat(client, "\x04[提示]\x03已关闭\x05投票踢出玩家.");
							}
						}
						else
						{
							l4d2_VotensKicks_D = false;
							PrintToChat(client, "\x04[提示]\x05投票踢出玩家\x03已禁用\x04,\x05开启失败.");
						}
						Command_Votes(client, false);
					}
				}
				case 5: 
				{
					if(bCheckClientAccess(client) && iGetClientImmunityLevel(client) >= 98)
					{
						if(hVotensrestart != 0)
						{
							if (!l4d2_Votensrestart_D)
							{
								l4d2_Votensrestart_D = true;
								l4d2_Votensrestart_D_true = false;
								PrintToChat(client, "\x04[提示]\x03已开启\x05投票重启章节.");
							}
							else
							{
								l4d2_Votensrestart_D = false;
								l4d2_Votensrestart_D_true = false;
								PrintToChat(client, "\x04[提示]\x03已关闭\x05投票重启章节.");
							}
						}
						else
						{
							l4d2_Votensrestart_D = false;
							PrintToChat(client, "\x04[提示]\x05投票重启章节\x03已禁用\x04,\x05开启失败.");
						}
						Command_Votes(client, false);
					}
				}
				case 6: 
				{
					if(bCheckClientAccess(client) && iGetClientImmunityLevel(client) >= 98)
					{
						if(hdifficulty != 0)
						{
							if (!l4d2_Votensdifficulty_D)
							{
								l4d2_Votensdifficulty_D = true;
								l4d2_Votensdifficulty_D_true = false;
								PrintToChat(client, "\x05[提示]\x03已开启\x05投票更改难度.");
							}
							else
							{
								l4d2_Votensdifficulty_D = false;
								l4d2_Votensdifficulty_D_true = false;
								PrintToChat(client, "\x04[提示]\x03已关闭\x05投票更改难度.");
							}
						}
						else
						{
							l4d2_Votensdifficulty_D = false;
							PrintToChat(client, "\x04[提示]\x05投票更改难度\x03已禁用\x04,\x05开启失败.");
						}
						Command_Votes(client, false);
					}
				}
			}
		}
		case MenuAction_End:
			delete menu;
	}
	return 0;
}

bool bCheckClientAccess(int client)
{
	if(GetUserFlagBits(client) & ADMFLAG_ROOT)
		return true;
	return false;
}

int iGetClientImmunityLevel(int client)
{
	char sSteamID[32];
	GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID));
	AdminId admin = FindAdminByIdentity(AUTHMETHOD_STEAM, sSteamID);
	if(admin == INVALID_ADMIN_ID)
		return -999;

	return admin.ImmunityLevel;
}

public Action Command_Voteskick(int client, int args)
{
	if(client)
	{
		if (Getplayer(client) == 0)
		{
			PrintToChat(client, "\x04[提示]\x05当前有效玩家不足,投票踢出玩家功能暂时禁用.");
			Command_Votes(client, false);
		}
		else
			CreateVotekickMenu(client);
	}
	return Plugin_Handled;
}

int Getplayer(int client)
{
	int count;
	for(int i = 1;i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && client != i)
		{
			if (!CanUserTarget(client, i) && CanUserTarget(i, client))
			{
				continue;
			}
			count++;
		}
	}	
	return count;
}

void CreateVotekickMenu(int client)
{	
	if(hVotensED == 1 && l4d2_VotensKicks_D)
	{
		if (!TestVoteDelay(client)) return;
		{
			Handle menu = CreateMenu(Menu_Voteskick);		
			char name[MAX_NAME_LENGTH];
			char steamID[32];
			SetMenuTitle(menu, "踢出玩家?");
			for(int i = 1;i <= MaxClients; i++)
			{
				if(IsClientInGame(i) && !IsFakeClient(i) && client != i)
				{
					if (!CanUserTarget(client, i) && CanUserTarget(i, client)) continue;
					if(bCheckClientAccess(client) && iGetClientImmunityLevel(client) >= 98)
					GetClientAuthId(i, AuthId_Steam2, steamID, sizeof(steamID));
					if(GetClientName(i,name,sizeof(name)))
					{
						AddMenuItem(menu, steamID, name);						
					}
				}		
			}
			SetMenuExitButton(menu, true);
			DisplayMenu(menu, client, MENU_TIME_FOREVER);
		}
	}
	else
	{
		PrintToChat(client, "\x04[提示]\x05投票踢出玩家已被禁用.");
	}
}

public int Menu_Voteskick(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char info[32] ,name[32];
			GetMenuItem(menu, param2, info, sizeof(info), _, name, sizeof(name));
			kickplayer = info;
			kickplayername = name;
			PrintToChatAll("\x04[提示]\x03%N\x05发起投票踢出\x04:\x03%s(%s)", param1, kickplayername, kickplayer);
			DisplayVoteKickMenu(param1);		
		}
		case MenuAction_End:
			delete menu;
	}
	return 0;
}

void DisplayVoteKickMenu(int client)
{
	if (IsVoteInProgress())
	{
		ReplyToCommand(client, "\x04[提示]\x05已有投票在进行中.");
		return;
	}
	
	if (!TestVoteDelay(client))
	{
		return;
	}
	g_voteType = kicks;
	
	g_hVoteMenu = CreateMenu(Handler_VoteCallback);
	SetMenuTitle(g_hVoteMenu, "踢出玩家: %s ?",kickplayername);
	AddMenuItem(g_hVoteMenu, VOTE_YES, "同意");
	AddMenuItem(g_hVoteMenu, VOTE_NO, "反对");
	SetMenuExitButton(g_hVoteMenu, false);
	VoteMenuToAll(g_hVoteMenu, 20);
}

public Action Command_votesrestartmenu(int client, int args)
{
	if(hVotensED == 1 && l4d2_Votensrestart_D)
	{
		PrintToChatAll("\x04[提示]\x03%N\x05发起投票重启当前章节.", client);
		DisplayVoterestartMenu(client);
	}

	return Plugin_Handled;
}

public Action Command_votesdifficultymenu(int client, int args)
{
	if(hVotensED == 1 && l4d2_Votensdifficulty_D)
	{
		if (!TestVoteDelay(client))
		{
			return Plugin_Handled;
		}
		char difficulty[32];
		GetConVarString(FindConVar("z_difficulty"), difficulty, sizeof(difficulty));
		
		if (StrEqual(difficulty, "Easy", false))
		{
			Handle menu = CreateMenu(difficultyMenuHandler);
			SetMenuTitle(menu, "请选择难度:");
			AddMenuItem(menu, "Normal", "普通");
			AddMenuItem(menu, "Hard", "高级");
			AddMenuItem(menu, "Impossible", "专家");
			SetMenuExitButton(menu, true);
			DisplayMenu(menu, client, MENU_TIME_FOREVER);
		
			return Plugin_Handled;
		}
		else if (StrEqual(difficulty, "Normal", false))
		{
			Handle menu = CreateMenu(difficultyMenuHandler);
			SetMenuTitle(menu, "请选择难度:");
			AddMenuItem(menu, "Easy", "简单");
			AddMenuItem(menu, "Hard", "高级");
			AddMenuItem(menu, "Impossible", "专家");
			SetMenuExitButton(menu, true);
			DisplayMenu(menu, client, MENU_TIME_FOREVER);
		
			return Plugin_Handled;
		}
		else if (StrEqual(difficulty, "Hard", false))
		{
			Handle menu = CreateMenu(difficultyMenuHandler);
			SetMenuTitle(menu, "请选择难度:");
			AddMenuItem(menu, "Easy", "简单");
			AddMenuItem(menu, "Normal", "普通");
			AddMenuItem(menu, "Impossible", "专家");
			SetMenuExitButton(menu, true);
			DisplayMenu(menu, client, MENU_TIME_FOREVER);
		
			return Plugin_Handled;
		}
		else if (StrEqual(difficulty, "Impossible", false))
		{
			Handle menu = CreateMenu(difficultyMenuHandler);
			SetMenuTitle(menu, "请选择难度:");
			AddMenuItem(menu, "Easy", "简单");
			AddMenuItem(menu, "Normal", "普通");
			AddMenuItem(menu, "Hard", "高级");
			SetMenuExitButton(menu, true);
			DisplayMenu(menu, client, MENU_TIME_FOREVER);
		
			return Plugin_Handled;
		}
	}
	else
	{
		PrintToChat(client, "\x04[提示]\x05投票更换难度已被禁用.");
	}
	return Plugin_Handled;
}

public int difficultyMenuHandler(Handle menu, MenuAction action, int client, int itemNum)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char info[32] , name[32];
			GetMenuItem(menu, itemNum, info, sizeof(info), _, name, sizeof(name));
			votesdifficulty = info;
			votesdifficultyname = name;
			
			char difficulty[32];
			GetConVarString(FindConVar("z_difficulty"), difficulty, sizeof(difficulty));
			
			if (StrEqual(difficulty, votesdifficulty, false))
			{
				PrintToChat(client, "\x04[提示]\x05选择的难度与当前难度相同.");
			}
			else
			{
				PrintToChatAll("\x04[提示]\x03%N\x05发起投票更换难度为\x04:\x03%s", client, votesdifficultyname);
				DisplayVotedifficultyMenu(client);
			}
		}
		case MenuAction_End:
			delete menu;
	}
	return 0;
}

void DisplayVoterestartMenu(int client)
{
	if (IsVoteInProgress())
	{
		ReplyToCommand(client, "\x04[提示]\x05已有投票在进行中.");
		return;
	}
	if (!TestVoteDelay(client))
	{
		return;
	}
	g_voteType = restart;
	
	g_hVoteMenu = CreateMenu(Handler_VoteCallback, MENU_ACTIONS_ALL);
	SetMenuTitle(g_hVoteMenu, "投票重启当前章节?");
	AddMenuItem(g_hVoteMenu, VOTE_YES, "同意");
	AddMenuItem(g_hVoteMenu, VOTE_NO, "反对");
	SetMenuExitButton(g_hVoteMenu, false);
	VoteMenuToAll(g_hVoteMenu, 20);
}

void DisplayVotedifficultyMenu(int client)
{
	if (IsVoteInProgress())
	{
		ReplyToCommand(client, "\x04[提示]\x05已有投票在进行中.");
		return;
	}
	if (!TestVoteDelay(client))
	{
		return;
	}
	g_voteType = difficultys;
	
	g_hVoteMenu = CreateMenu(Handler_VoteCallback, MENU_ACTIONS_ALL);
	SetMenuTitle(g_hVoteMenu, "投票更换难度为: %s ?", votesdifficultyname, votesmaps);
	AddMenuItem(g_hVoteMenu, VOTE_YES, "同意");
	AddMenuItem(g_hVoteMenu, VOTE_NO, "反对");
	SetMenuExitButton(g_hVoteMenu, false);
	VoteMenuToAll(g_hVoteMenu, 20);
}

public int Handler_VoteCallback(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		switch(param2)
		{
			case 0: 
			{
				//Votey += 1;
				PrintToChatAll("\x04[提示]\x03%N\x05已投票.", param1);
			}
			case 1: 
			{
				//Voten += 1;
				PrintToChatAll("\x04[提示]\x03%N\x05已投票.", param1);
			}
		}
	}
	char item[32], display[32];
	float percent;
	int votes, totalVotes;
	GetMenuVoteInfo(param2, votes, totalVotes);
	GetMenuItem(menu, param1, item, sizeof(item), _, display, sizeof(display));
	
	if (strcmp(item, VOTE_NO) == 0 && param1 == 1)
	{
		votes = totalVotes - votes;
	}
	percent = GetVotePercent(votes, totalVotes);
	
	if (action == MenuAction_End)
	{
		VoteMenuClose();
	}
	else if (action == MenuAction_VoteCancel && param1 == VoteCancel_NoVotes)
	{
		PrintToChatAll("\x04[提示]\x05本次投票没有玩家投票.");
	}
	else if (action == MenuAction_VoteEnd)
	{
		if ((strcmp(item, VOTE_YES) == 0 && FloatCompare(percent,hCvar_Limits) < 0 && param1 == 0) || (strcmp(item, VOTE_NO) == 0 && param1 == 1))
		{
			PrintToChatAll("\x04[提示]\x05投票失败\x04.\x05至少需要\x03%d%%\x05支持\x04(\x05同意\x03%d%%\x05总共\x03%i\x05票\x04)\x05.", RoundToNearest(100.0*hCvar_Limits), RoundToNearest(100.0*percent), totalVotes);
			CreateTimer(2.0, VoteEndDelay);
		}
		else
		{
			CreateTimer(2.0, VoteEndDelay);
			switch (g_voteType)
			{
				case (maps):
				{
					Changeleveltimer = CreateTimer(8.0, Changelevel_Map);
					PrintHintTextToAll("[提示] 投票通过,服务器将在 8秒 后更换地图为: %s", votesmapsname);
					PrintToChatAll("\x04[提示]\x05投票通过\x04.\x038秒\x05后更换地图为\x04:\x03%s\x04(\x05同意\x03%d%%\x05总共\x03%i\x05票\x04)\x05.", votesmapsname, RoundToNearest(100.0*percent), totalVotes);
					
				}
				case (kicks):
				{
					if(IsAuthIdSteam2() != 0)
					{
						BanClient(client, hotensKickstime, BANFLAG_AUTO, "", "你被投票踢出(临时封禁)");
						PrintToChatAll("\x04[提示]\x05投票通过\x04.\x05玩家\x03%s\x05已被踢出.\x04(\x05同意\x03%d%%\x05总共\x03%i\x05票\x04)\x05.", kickplayername, RoundToNearest(100.0*percent), totalVotes);
					}
					else
						PrintToChatAll("\x04[提示]\x05投票通过\x04.\x05踢出玩家\x03%s\x05失败.\x04(\x05同意\x03%d%%\x05总共\x03%i\x05票\x04)\x05.", kickplayername, RoundToNearest(100.0*percent), totalVotes);
				}
				case (difficultys):
				{
					Changelevel_difficulty();
					PrintHintTextToAll("[提示] 投票通过,难度已更换为: %s .", votesdifficultyname);
					PrintToChatAll("\x04[提示]\x05投票通过\x04.\x05难度已更换为\x04:\x03%s\x04(\x05同意\x03%d%%\x05总共\x03%i\x05票\x04)\x05.", votesdifficultyname, RoundToNearest(100.0*percent), totalVotes);
				}
				case (restart):
				{
					Changeleveltimer = CreateTimer(8.0, Changelevel_restart);
					PrintHintTextToAll("[提示] 投票通过,将在 8秒 后重启当前章节.");
					PrintToChatAll("\x04[提示]\x05投票通过\x04.\x038\x05秒后重启当前章节\x04(\x05同意\x03%d%%\x05总共\x03%i\x05票\x04)\x05.", RoundToNearest(100.0*percent), totalVotes);
				}
			}
		}
	}
	return 0;
}

int IsAuthIdSteam2()
{
	char steamId[32];
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
		{
			GetClientAuthId(i, AuthId_Steam2, steamId, sizeof(steamId));
			if (StrEqual(steamId, kickplayer, false))
				return i;
		}
	}
	return 0;
}

public Action VoteEndDelay(Handle timer)
{
	//Votey = 0;
	//Voten = 0;
	return Plugin_Continue;
}

public Action Changelevel_Map(Handle timer)
{
	ServerCommand("changelevel %s", votesmaps);
	Changeleveltimer = null;
	return Plugin_Stop;
}

void Changelevel_difficulty()
{
	ServerCommand("z_difficulty %s", votesdifficulty);
}

public Action Changelevel_restart(Handle timer)
{
	char strCurrentMap[32];
	GetCurrentMap(strCurrentMap,32);
	
	ServerCommand("changelevel %s", strCurrentMap);
	Changeleveltimer = null;
	return Plugin_Stop;
}

void VoteMenuClose()
{
	//Votey = 0;
	//Voten = 0;
	delete g_hVoteMenu;
}

float GetVotePercent(int votes, int totalVotes)
{
	return float(votes) / float(totalVotes);
}

bool TestVoteDelay(int client)
{
 	int delay = CheckVoteDelay();
 	
 	if (delay > 0)
	{
 		if (delay > 60)
		{
 			PrintToChat(client, "\x04[提示]\x05您必须再等待\x03%i\x05分钟才能发起新的投票.", delay % 60);
 		}
		else
		{
 			PrintToChat(client, "\x04[提示]\x05您必须再等待\x03%i\x05秒钟才能发起新的投票.", delay);
 		}
 		return false;
 	}
	return true;
}