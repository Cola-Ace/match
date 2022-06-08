static char _colorNames[][] = {"{default}", "{dark_red}", "{pink}", "{green}", "{yellow}", "{light_green}", "{light_red}", "{gray}", "{orange}", "{light_blue}", "{dark_blue}", "{purple}"};
static char _colorCodes[][] = {"\x01", "\x02", "\x03", "\x04", "\x05", "\x06", "\x07", "\x08", "\x09", "\x0B", "\x0C", "\x0E"};

/* warmup start */
stock void StartWarmup(){
	ExecuteAndSaveCvars("sourcemod/match/warmup.cfg");
	ServerCommand("mp_warmup_end");
	ServerCommand("mp_warmup_end");
	
	CreateTimer(0.8, Timer_ShowInfo, _, TIMER_REPEAT);
}

stock void StartCountdown(){
	g_bIsCountdown = true;
	CreateTimer(0.2, Timer_UpdateState, _, TIMER_REPEAT);
	CreateTimer(1.0, Timer_CutTime, _, TIMER_REPEAT);
}

public Action Timer_ShowInfo(Handle timer){
	if (!Match_IsWarmup()) return Plugin_Stop;
	if (g_bIsCountdown) return Plugin_Continue;
	if (GetRealClientCount() >= 10) StartCountdown();
	if (g_bIsChangeMap) Huds_ShowRealHudAll("已选图 | 购买诱饵弹重新选图");
	return Plugin_Continue;
}

public Action Timer_UpdateState(Handle timer){
	if (GetRealClientCount() != MATCH_PLAYERS) return Plugin_Stop;
	char output[64];
	if (g_iCountdown == 0){
		Format(output, sizeof(output), "已踢出未准备玩家");
		Huds_ShowRealHudAll(output, 3);
		KickNotReady();
		return Plugin_Stop;
	}
	if (Match_GetReadyPlayers() == MATCH_PLAYERS){
		NextStage();
		return Plugin_Stop;
	}
	Format(output, sizeof(output), "%s %d / 10 已准备 %d 秒", g_bIsChangeMap == true ? "已选图 |":"", Match_GetReadyPlayers(), g_iCountdown);
	Huds_ShowRealHudAll(output);
	for (int i = 0; i < MaxClients; i++){
		if (IsPlayer(i) && !Match_IsReady(i)) PrintCenterText(i, "按 G 准备");
	}
	return Plugin_Continue;
}

public Action Timer_CutTime(Handle timer){
	if (GetRealClientCount() != 10){
		g_iCountdown = 30;
		return Plugin_Stop;
	}
	g_iCountdown--;
	if (g_iCountdown == -1){
		g_iCountdown = 30;
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

stock void KickNotReady(){
	for (int i = 0; i < MaxClients; i++){
		if (IsPlayer(i) && !Match_IsReady(i)) KickClient(i, "您因长时间未准备而被踢出服务器");
	}
}
/* warmup end */

stock void NextStage(){
	if (!g_bIsChangeMap) ChangeMap();
	else VotePick();
}

/* vote map start */
public Action Timer_VoteMap(Handle timer){
	int index = Max(g_iVoteMapCounts, sizeof(g_iVoteMapCounts));
	char output[512];
	Format(output, sizeof(output), "正在切换地图 <font color=\"#7FFF00;\">%s</font>", MapList[index]);
	Huds_ShowRealHudAll(output, 4);
	CreateTimer(3.0, Timer_ChangeMap, index);
}

public Action Timer_ChangeMap(Handle timer, int index){
	g_bIsChangeMap = true;
	ServerCommand("map %s", MapList[index]);
}

stock void ChangeMap(){
	Match_SetGameState(GameState_VoteMap);
	for (int i = 0; i < MaxClients; i++){
		if (IsPlayer(i)) ShowMapMenu(i);
	}
	CreateTimer(15.0, Timer_VoteMap);
}
/* vote map end */

/* captain pick start */
public Action Timer_VotePick(Handle timer){
	int index = Max(g_iVotePickCounts, sizeof(g_iVotePickCounts));
	Match_MessageToAll("本场比赛将使用【{green}%s{default}】分配方式", index == 0 ? "队长选人":"随机分配");
	switch (index){
		case 0:CaptainPick();
		case 1:RandomPick();
	}
}

stock void CaptainPick(){
	RandomCaptains();
	
	int captain1 = Match_GetCaptain(TeamType_Team1);
	int captain2 = Match_GetCaptain(TeamType_Team2);
	Match_MessageToAll("队长1 是 {purple}%N{default}", captain1);
	Match_MessageToAll("队长2 是 {purple}%N{default}", captain2);
	
	// switch players to spec unless captain
	for (int i = 0; i < MaxClients; i++){
		if (IsPlayer(i) && i != captain1 && i != captain2){
			g_clients.Push(i);
			SwitchClientTeam(i, CS_TEAM_SPECTATOR);
		}
	}
	
	// switch captain1 to ct and another to t
	SwitchClientTeam(captain1, CS_TEAM_CT);
	SwitchClientTeam(captain2, CS_TEAM_T);
	
	// set team
	g_tTeam[0].index = 1;
	g_tTeam[0].team = CS_TEAM_CT;
	g_tTeam[0].players[0] = captain1;
	Format(g_tTeam[0].name, 32, "Team1_%N", captain1);
	
	g_tTeam[1].index = 2;
	g_tTeam[1].team = CS_TEAM_T;
	g_tTeam[1].players[0] = captain2;
	Format(g_tTeam[1].name, 32, "Team2_%N", captain2);
	
	Match_SetGameState(GameState_CaptainPick);
	PickPlayer();
}

stock void PickPlayer(){
	if (GetRealClientCount() == 10){
		StartKnifeRound();
		CancelAllMenus();
		CloseHandle(g_hPickingTimer);
		g_hPickingTimer = INVALID_HANDLE;
		return;
	}
	
	switch (g_CaptainPick[g_iPickCount]){
		case 'A':g_iPickingCaptain = Match_GetCaptain(TeamType_Team1);
		case 'B':g_iPickingCaptain = Match_GetCaptain(TeamType_Team2);
	}
	g_iPickCount++;
	
	for (int i = 0; i < MaxClients; i++){
		if (IsPlayer(i)) ShowPickMenu(i);
	}
	
	g_hPickingTimer = CreateTimer(15.0, Timer_AutoPick);
}

public Action Timer_AutoPick(Handle timer){
	ArrayList clients = new ArrayList();
	for (int j = 0; j < g_clients.Length; j++){
		int i = g_clients.Get(j);
		if (GetClientTeam(i) == CS_TEAM_SPECTATOR) clients.Push(i);
	}
	
	int client = clients.Get(GetRandomInt(0, clients.Length - 1));
	SwitchClientTeam(client, GetClientTeam(g_iPickingCaptain));
	int team = view_as<int>(Match_GetClientTeamtype(g_iPickingCaptain)) - 1;
	g_tTeam[team].players[GetTeamClientCount(client) - 1] = client;
	PickPlayer();
}

stock void RandomCaptains(){
	ArrayList clients = new ArrayList();
	for (int i = 0; i < MaxClients; i++){
		if (IsPlayer(i)) clients.Push(i);
	}
	for (int i = 0; i < 2; i++){
		int index = GetRandomInt(0, clients.Length - 1);
		Match_SetCaptain(clients.Get(index), view_as<TeamType>(i));
		clients.Erase(index);
	}
}

stock void RandomPick(){
	ArrayList ct = new ArrayList();
	for (int i = 0; i < MaxClients; i++){
		if (IsPlayer(i)) ct.Push(i);
	}
	for (int i = 0; i < 5; i++){
		int index = GetRandomInt(0, ct.Length - 1);
		SwitchClientTeam(ct.Get(index), CS_TEAM_T);
		ct.Erase(index);
	}
	
	for (int i = 0; i < ct.Length; i++){
		SwitchClientTeam(ct.Get(i), CS_TEAM_CT);
	}
	
	StartKnifeRound();
}

stock void VotePick(){
	Match_SetGameState(GameState_VotePick);
	for (int i = 0; i < MaxClients; i++){
		if (IsPlayer(i)) ShowVotePickMenu(i);
	}
	CreateTimer(15.0, Timer_VotePick);
}

stock void GetCaptainPickMethod(char[] format, int maxsize){
	int method = g_cCaptainPick.IntValue;
	switch(method){
		case 0:Format(format, maxsize, "ABABABABAB");
		case 1:Format(format, maxsize, "ABBAABBAAB");
		case 2:Format(format, maxsize, "ABAABBABAB");
	}
}
/* captain pick end */

/* pick team start */
stock void PickTeam(int team){
	for (int i = 0; i < MaxClients; i++){
		if (!IsPlayer(i)) continue;
		if (GetClientTeam(i) == team) ShowPickTeamMenu(i);
	}
	CreateTimer(7.0, Timer_PickTeam, team);
}

public Action Timer_PickTeam(Handle timer, int team){
	if (g_iSelectCT >= 3 && team == CS_TEAM_T){
		SwapTeam();
	}
	
	// start vote friendlyfire
	StartVoteFf();
}
/* pick team end */

/* live start */
public Action Timer_Live(Handle timer){
	Live();
}

stock void Live(){
	g_bIsChangeMap = false;
	Match_SetGameState(GameState_Live);
	Call_StartForward(g_hOnLive);
	Call_Finish();
	Huds_ShowRealHudAll("<font color=\"#7FFF00;\">比赛开始</font>", 3);
}
/* live end */

/* overtime start */
stock void VoteOvertime(){
	for (int i = 0; i < MaxClients; i++){
		if (IsPlayer(i)) ShowVoteOvertimeMenu(i);
	}
}

stock void ShowVoteOvertimeMenu(int client){
	CustomVoteSetup setup;
	setup.team = CS_TEAM_NONE; // broad team
	setup.issue_id = VOTE_ISSUE_CONTINUE;
	setup.pass_percentage = 70.0;
	Format(setup.dispstr, sizeof(setup.dispstr), "是否加时？");
	Format(setup.disppass, sizeof(setup.disppass), "正在加时...");
	CustomVotes_Execute(setup, 10, OvertimeVotePassed, OvertimeVoteFailed);
}

public void OvertimeVotePassed(int results[MAXPLAYERS + 1]){
	Match_MessageToAll("投票结果为 {green}加时{default}");
}

public void OvertimeVoteFailed(int results[MAXPLAYERS + 1]){
	Match_MessageToAll("投票结果为 {dark_red}不加时{default}");
	EndMatch();
}
/* overtime end */

/* friendlyfire start */
stock void StartVoteFf(){
	CreateTimer(7.0, Timer_EndVoteFf);
	for (int i = 0; i < MaxClients; i++){
		if (IsPlayer(i)) ShowVoteFriendlyfireMenu(i);
	}
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3]){
	if ((!Match_IsLive() || g_bEnableFriendlyfire) // not in match or ff is enable
	|| (attacker < 1 || attacker > MaxClients || attacker == victim || weapon < 1) // self damage & greande
	|| (GetClientTeam(victim) == GetClientTeam(attacker) && weapon < 1 && g_cFriendlyfire.BoolValue) // same team & grenade & enable team grenade damage
	|| (GetClientTeam(victim) == GetClientTeam(attacker) && g_bEnableFriendlyfire) // same team & enable ff
	|| (GetClientTeam(victim) != GetClientTeam(attacker))) // different team
	return Plugin_Continue; 

	return Plugin_Handled;
}
/* friendlyfire end */

/* kniferound start */
stock void StartKnifeRound(){
	ExecuteAndSaveCvars("sourcemod/match/knife.cfg");
	ServerCommand("mp_restartgame 1");
	Match_SetGameState(GameState_KnifeRound);
	CreateTimer(1.5, Timer_StartKnifeRound);
}

public Action Timer_StartKnifeRound(Handle timer){
	if (g_cRecord.BoolValue) Record();
	Huds_ShowRealHudAll("<font color=\"#7FFF00;\">拼刀选边</font>");
}
/* kniferound end */

/* gotv record start */
stock bool IsTVEnabled(){
	Handle tvEnabledCvar = FindConVar("tv_enable");
	if (tvEnabledCvar == INVALID_HANDLE) {
		LogError("Failed to get tv_enable cvar");
		return false;
	}
	return GetConVarInt(tvEnabledCvar) != 0;
}

stock void Record(){
	if (!IsTVEnabled()){
		LogError("Autorecording will not work with current cvar \"tv_enable\"=0. Set \"tv_enable 1\" in server.cfg (or another config file) to fix this.");
		return;
	}
	
	char name[512], map[32], start_time[32];
	g_cDemoName.GetString(name, sizeof(name));
	GetCurrentMap(map, sizeof(map));
	FormatTime(start_time, sizeof(start_time), "%Y-%m-%d_%H:%M", GetTime());
	ReplaceString(name, sizeof(name), "{map}", map, false);
	ReplaceString(name, sizeof(name), "{start_time}", start_time, false);
	
	ServerCommand("tv_record \"%s\"", name);
	LogMessage("Record to %s.dem", name);
}

stock void StopRecord(){
	ServerCommand("tv_stoprecord");
}
/* gotv record end */

/* misc */
stock void CancelAllMenus(){
	for (int i = 0; i < MaxClients; i++){
		if (IsPlayer(i)) CancelClientMenu(i, true);
	}
}

stock void SwapTeam(){
	ArrayList ct = new ArrayList();
	for (int i = 0; i < MaxClients; i++){
		if (IsPlayer(i) && GetClientTeam(i) == CS_TEAM_CT) ct.Push(i);
	}
	
	for (int i = 0; i < MaxClients; i++){
		if (IsPlayer(i) && GetClientTeam(i) == CS_TEAM_T) SwitchClientTeam(i, CS_TEAM_CT);
	}
	
	for (int i = 0; i < ct.Length; i++){
		SwitchClientTeam(ct.Get(i), CS_TEAM_T);
	}
	
	delete ct;
}

stock void EndMatch(){
	StopRecord();
	Call_StartForward(g_hOnMatchOver);
	Call_Finish();
	Match_SetGameState(GameState_Warmup);
}

stock void SetMoney(int client, int money = 10000){
	SetEntProp(client, Prop_Send, "m_iAccount", money);
}

stock void RestoreVar(){
	g_iSelectCT = 0;
	for (int i = 0; i < sizeof(g_iVoteMapCounts); i++){
		g_iVoteMapCounts[i] = 0;
	}
	for (int i = 0; i < MAXPLAYERS + 1; i++){
		g_bIsReady[i] = false;
	}
	g_iPickingCaptain = -1;
	g_iPickCount = 0;
	g_iSelectEnableFf = 0;
	g_clients.Clear();
}

stock int GetMapIndexByName(const char[] map){
	for (int i = 0; i < sizeof(MapList); i++){
		if (StrEqual(MapList[i], map)) return i;
	}
	return -1;
}

stock int Max(int[] list, int size){
	int max = -1, index = 0;
	for (int i = 0; i < size; i++){
		if (list[i] > max){
			max = list[i];
			index = i;
		}
	}
	return index;
}

stock int GetRealClientCount(){
	int clients = 0;
	for (int i = 0; i < MaxClients; i++){
		if (IsPlayer(i) && (GetClientTeam(i) == CS_TEAM_CT || GetClientTeam(i) == CS_TEAM_T)) clients++;
	}
	return clients;
}

stock bool IsValidClient(int client){
	return (1 <= client <= MaxClients) && IsClientInGame(client) && IsClientConnected(client);
}

stock bool IsPlayer(int client){
	return IsValidClient(client) && !IsFakeClient(client);
}

stock void Colorize(char[] msg, int size, bool stripColor = false) {
  for (int i = 0; i < sizeof(_colorNames); i++) {
  	ReplaceString(msg, size, _colorNames[i], stripColor ? "\x01":_colorCodes[i]);
  }
}

stock void SwitchClientTeam(int client, int team) {
  if (GetClientTeam(client) == team)
    return;

  if (team > CS_TEAM_SPECTATOR) {
    CS_SwitchTeam(client, team);
    CS_UpdateClientModel(client);
    CS_RespawnPlayer(client);
  } else {
    ChangeClientTeam(client, team);
  }
}