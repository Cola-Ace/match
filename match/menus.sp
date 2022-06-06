// vote friendlyfire

public Action Timer_EndVoteFf(Handle timer){
	if (g_iSelectEnableFf == 6) g_bEnableFriendlyfire = true;
	Match_MessageToAll("本场比赛将 %s", g_bEnableFriendlyfire ? "{dark_red}开启友伤{default}":"{green}关闭友伤{default}, 但道具仍能队友造成 {dark_red}100%的伤害{default}");
	
	ExecuteAndSaveCvars("sourcemod/match/live.cfg");
	ServerCommand("mp_restartgame 1");
	CreateTimer(1.5, Timer_Live);
}

public int Handler_VoteFriendlyfire(Menu menu, MenuAction action, int client, int select){
	if (action == MenuAction_Select){
		char info[4];
		menu.GetItem(select, info, sizeof(info));
		if (StrEqual(info, "1")) g_iSelectEnableFf++;
		Match_MessageToAll("{purple}%N{default} 选择了 %s友伤{default} %s", client, StrEqual(info, "1") ? "{red}开启":"{green}不开启", StrEqual(info, "1") ? "[{green}%d{default}/{green}6{default}]":"", g_iSelectEnableFf);
	}
}

stock void ShowVoteFriendlyfireMenu(int client){
	Menu menu = new Menu(Handler_VoteFriendlyfire);
	menu.SetTitle("开启友伤?");
	menu.AddItem("1", "开启");
	menu.AddItem("0", "不开启");
	menu.ExitButton = false;
	menu.ExitBackButton = false;
	menu.Display(client, 7);
}

// pick team

public int Handler_PickTeam(Menu menu, MenuAction action, int client, int select){
	if (action == MenuAction_Select){
		char info[4];
		menu.GetItem(select, info, sizeof(info));
		if (StrEqual(info, "CT")) g_iSelectCT++;
		Match_MessageToTeam(GetClientTeam(client), "{purple}%N{default} 选择了 {green}%s{default}", client, info);
	}
}

stock void ShowPickTeamMenu(int client){
	Menu menu = new Menu(Handler_PickTeam);
	menu.SetTitle("请选择队伍");
	menu.AddItem("T", "T");
	menu.AddItem("CT", "CT");
	menu.ExitButton = false;
	menu.ExitBackButton = false;
	menu.Display(client, 7);
}

// vote pick

public Action Timer_ShowVotePickMenu(Handle timer, int client){
	ShowVotePickMenu(client);
}

public int Handler_VotePickMenu(Menu menu, MenuAction action, int client, int select){
	if (select == MenuCancel_Interrupted){
		CreateTimer(0.2, Timer_ShowVotePickMenu, client);
	} else if (action == MenuAction_Select){
		g_iVotePickCounts[select]++;
		Match_MessageToAll("{purple}%N{default} 选择了 {green}%s{default} [{light_green}%i{default}]", client, select == 0 ? "队长选人":"随机分配", g_iVotePickCounts[select]);
	}
}

stock void ShowVotePickMenu(int client){
	Menu menu = new Menu(Handler_VotePickMenu);
	menu.SetTitle("投票选择选人方式");
	
	menu.AddItem("captain", "队长选人");
	menu.AddItem("random", "随机分配");
	
	menu.ExitBackButton = false;
	menu.ExitButton = false;
	
	menu.Display(client, 15);
}

// pick player

public Action Timer_ShowPickMenu(Handle timer, int client){
	ShowPickMenu(client);
}

public int Handler_PickPlayer(Menu menu, MenuAction action, int client, int select){ // client is picking captain
	if (select == MenuCancel_Interrupted && Match_GetGameState() == GameState_CaptainPick){
		CreateTimer(0.2, Timer_ShowPickMenu, client);
	} else if (action == MenuAction_Select){
		char index[4];
		menu.GetItem(select, index, sizeof(index));
		int pick = StringToInt(index);
		SwitchClientTeam(pick, GetClientTeam(client));
		int team = 0;
		if (g_tTeam[1].captain == client) team = 1;
		g_tTeam[team].players[GetTeamClientCount(GetClientTeam(client)) - 1] = pick;
		PickPlayer();
	}
}

stock void ShowPickMenu(int client){
	Menu menu = new Menu(Handler_PickPlayer);
	SetMenuPagination(menu, MENU_NO_PAGINATION);
	
	int captain1 = Match_GetCaptain(TeamType_Team1);
	int captain2 = Match_GetCaptain(TeamType_Team2);
	for (int i = 0; i < MaxClients; i++){
		char info[4], display[32];
		if (!IsPlayer(i) || i == captain1 || i == captain2) continue;
		IntToString(i, info, sizeof(info));
		Format(display, sizeof(display), "[%s] %N", GetClientTeam(i) == CS_TEAM_SPECTATOR ? "  ":"√", i);
		menu.AddItem(info, display, g_iPickingCaptain == client ? ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED);
	}
	
	menu.ExitButton = false;
	menu.ExitBackButton = false;
	
	menu.Display(client, 15);
}

// vote map

public Action Timer_ShowMapMenu(Handle timer, int client){
	ShowMapMenu(client);
}

public int Handler_ChangeMap(Menu menu, MenuAction action, int client, int select){
	if (select == MenuCancel_Interrupted){
		CreateTimer(0.2, Timer_ShowMapMenu, client);
	} else if (action == MenuAction_Select){
		char map[32];
		menu.GetItem(select, map, sizeof(map));
		int index = StrEqual(map, "random") ? GetRandomInt(0, sizeof(MapList) - 1):GetMapIndexByName(map);

		g_iVoteMapCounts[index]++;
		Match_MessageToAll("{purple}%N{default} %s选择了 {green}%s{default} [{light_green}%i{default}]", client, StrEqual(map, "random") ? "随机":"", MapList[index], g_iVoteMapCounts[index]);
	}
}

stock void ShowMapMenu(int client){
	Menu menu = new Menu(Handler_ChangeMap);
	menu.SetTitle("投票选图");
	
	menu.AddItem("random", "随机");
	for (int i = 0; i < sizeof(MapList); i++){
		menu.AddItem(MapList[i], MapList[i]);
	}
	menu.ExitBackButton = false;
	menu.ExitButton = false;
	
	menu.Display(client, 15);
}