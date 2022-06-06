public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	CreateNative("Match_Message", Native_Message);
	CreateNative("Match_MessageToAll", Native_MessageToAll);
	CreateNative("Match_MessageToTeam", Native_MessageToTeam);
	CreateNative("Match_GetGameState", Native_GetGameState);
	CreateNative("Match_SetGameState", Native_SetGameState);
	CreateNative("Match_IsWarmup", Native_IsWarmup);
	CreateNative("Match_IsLive", Native_IsLive);
	CreateNative("Match_Ready", Native_Ready);
	CreateNative("Match_UnReady", Native_UnReady);
	CreateNative("Match_IsReady", Native_IsReady);
	CreateNative("Match_IsCaptain", Native_IsCaptain);
	CreateNative("Match_GetReadyPlayers", Native_GetReadyPlayers);
	CreateNative("Match_GetClientTeamtype", Native_GetClientTeamtype);
	CreateNative("Match_SetCaptain", Native_SetCaptain);
	CreateNative("Match_GetCaptain", Native_GetCaptain);
	return APLRes_Success;
}

public int Native_GetClientTeamtype(Handle plugin, int numParams){
	for (int i = 0; i < 2; i++){
		for (int j = 0; j < 5; j++){
			if (g_tTeam[i].players[j] == GetNativeCell(1)) return g_tTeam[i].index - 1;
		}
	}
	return -1;
}

public int Native_MessageToTeam(Handle plugin, int numParams){
	char buffer[2048];
	int bytesWritten = 0;

	FormatNativeString(0, 2, 3, sizeof(buffer), bytesWritten, buffer);
	
	for (int i = 0; i < MaxClients; i++){
		if (IsPlayer(i) && GetClientTeam(i) == GetNativeCell(1)) Match_Message(i, buffer);
	}
}

public int Native_GetCaptain(Handle plugin, int numParams){
	return g_tTeam[GetNativeCell(1)].captain;
}

public int Native_IsCaptain(Handle plugin, int numParams){
	int client = GetNativeCell(1);
	return client == Match_GetCaptain(TeamType_Team1) || client == Match_GetCaptain(TeamType_Team2);
}

public int Native_SetCaptain(Handle plugin, int numParams){
	g_tTeam[GetNativeCell(2)].captain = GetNativeCell(1);
}

public int Native_GetReadyPlayers(Handle plugin, int numParmas){
	int count = 0;
	for (int i = 0; i < MaxClients; i++){
		if (IsPlayer(i) && Match_IsReady(i)) count++;
	}
	return count;
}

public int Native_UnReady(Handle plugin, int numParams){
	g_bIsReady[GetNativeCell(1)] = false;
}

public int Native_Ready(Handle plugin, int numParams){
	int client = GetNativeCell(1);
	if (Match_IsReady(client)) return;
	g_bIsReady[client] = true;
	Call_StartForward(g_hOnReady);
	Call_PushCell(client);
	Call_Finish();
}

public int Native_IsReady(Handle plugin, int numParams){
	return g_bIsReady[GetNativeCell(1)];
}

public int Native_IsLive(Handle plugin, int numParams){
	return g_GameState == GameState_Live;
}

public int Native_IsWarmup(Handle plugin, int numParams){
	return g_GameState == GameState_Warmup;
}

public int Native_SetGameState(Handle plugin, int numParams){
	Call_StartForward(g_hOnGameStateChanged);
	Call_PushCell(g_GameState);
	g_GameState = view_as<GameState>(GetNativeCell(1));
	Call_PushCell(g_GameState);
	Call_Finish();
}

public int Native_GetGameState(Handle plugin, int numParams){
	return view_as<int>(g_GameState);
}

public int Native_Message(Handle plugin, int numParams){
	int client = GetNativeCell(1);
	
	char buffer[2048];
	int bytesWritten = 0;

	SetGlobalTransTarget(client);
	FormatNativeString(0, 2, 3, sizeof(buffer), bytesWritten, buffer);
	
	char finalMsg[1024];
	char prefix[128];
	g_cPrefix.GetString(prefix, sizeof(prefix));
	Format(finalMsg, sizeof(finalMsg), "%s %s", StrEqual(prefix, "") ? "":prefix, buffer);

	if (client == 0){
		Colorize(finalMsg, sizeof(finalMsg), false);
		PrintToConsole(client, finalMsg);
	} else if (IsClientInGame(client)) {
		Colorize(finalMsg, sizeof(finalMsg));
		PrintToChat(client, finalMsg);
	}
}

public int Native_MessageToAll(Handle plugin, int numParams){
  char buffer[1024];
  int bytesWritten = 0;
  
  FormatNativeString(0, 1, 2, sizeof(buffer), bytesWritten, buffer);
  
  for (int i = 0; i < MaxClients; i++){
  	if (IsPlayer(i)) Match_Message(i, buffer);
  }
}