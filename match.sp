#include <sourcemod>
#include <cstrike>
#include <sdkhooks>
#include <sdktools>
#include "include/restorecvars.inc"
#include "include/match.inc"
#include "include/fys.huds.inc"
#include "include/customvotes.inc"

#pragma semicolon 1
#pragma newdecls required

#define MAP_COUNTS 9
#define PICK_METHODS 2
#define MATCH_PLAYERS 10

GameState g_GameState = GameState_None;

ArrayList g_clients; // save players who join the match
ArrayList g_RequestRevote; // revote map

bool g_bIsReady[MAXPLAYERS + 1] = false;
bool g_bIsChangeMap = false;
bool g_bIsCountdown = false;
bool g_bEnableFriendlyfire = false;
bool g_bIsPaused = false;
bool g_bIsFreezeTime = false;

int g_iServerPlayers = 0;
int g_iCountdown = 30;
int g_iVoteMapCounts[MAP_COUNTS] = 0;
int g_iVotePickCounts[PICK_METHODS] = 0;
int g_iPickingCaptain = -1;
int g_iPickCount = 0;
int g_iSelectCT = 0;
int g_iSelectEnableFf = 0;

// Forward & Timer
Handle g_hOnMatchOver = INVALID_HANDLE;
Handle g_hOnReady = INVALID_HANDLE;
Handle g_hOnGameStateChanged = INVALID_HANDLE;
Handle g_hOnLive = INVALID_HANDLE;
Handle g_hPickingTimer = INVALID_HANDLE;

ConVar g_cPrefix;
ConVar g_cCaptainPick;
ConVar g_cRecord;
ConVar g_cDemoName;
ConVar g_cPauseCount;
ConVar g_cFriendlyfire;

char g_CaptainPick[16];

enum struct Team {
	int index; // 1 or 2, mean Team1 or Team2
	int team; // ct or t after game start
	int captain; // captain client index
	int players[5]; // players in team
	int pause; // pause count
	char name[32]; // default Team{index}_{captain_name}
}

char MapList[][] = { "de_mirage", "de_inferno", "de_dust2", "de_vertigo", "de_overpass", "de_ancient", "de_cache", "de_train", "de_nuke" };

Team g_tTeam[2];

#include "match/natives.sp"
#include "match/menus.sp"
#include "match/util.sp"

public Plugin myinfo = {
	name = "Match - Main",
	author = "Xc_ace",
	description = "Simple match mode",
	version = "1.0",
	url = "https://github.com/Cola-Ace/match"
}

public void OnPluginStart(){
	g_cPrefix = CreateConVar("sm_match_prefix", "[{green}Match{default}]", "message prefix");
	g_cCaptainPick = CreateConVar("sm_match_captain_pick", "0", "0 - ABABABABAB, 1 - ABBAABBAAB, 2 - ABAABBABAB", _, true, 0.0, true, 2.0);
	g_cRecord = CreateConVar("sm_match_record_enable", "0", "record demo (need tv_enable 1)", _, true, 0.0, true, 1.0);
	g_cDemoName = CreateConVar("sm_match_record_name", "Match#{map}#{start_time}", "Demo name (support {map} {start_time})");
	g_cPauseCount = CreateConVar("sm_match_pause_count", "2", "pause count in match. (every team)");
	g_cFriendlyfire = CreateConVar("sm_match_team_ff", "1", "enable team grenade damage", _, true, 0.0, true, 1.0);
	AutoExecConfig(true, "match");
	ExecuteAndSaveCvars("sourcemod/match.cfg");
	ExecuteAndSaveCvars("sourcemod/match/warmup.cfg");
	
	GetCaptainPickMethod(g_CaptainPick, sizeof(g_CaptainPick));
	// Forward
	g_hOnReady = CreateGlobalForward("Match_OnReady", ET_Ignore, Param_Cell);
	g_hOnGameStateChanged = CreateGlobalForward("Match_OnGameStateChanged", ET_Ignore, Param_Cell, Param_Cell);
	g_hOnMatchOver = CreateGlobalForward("Match_OnMatchOver", ET_Ignore);
	g_hOnLive = CreateGlobalForward("Match_OnLive", ET_Ignore);
	// Event
	HookEvent("player_spawn", Event_ClientSpawn);
	HookEvent("cs_win_panel_match", Event_MatchEnd);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_freeze_end", Event_FreezeEnd);
	AddCommandListener(OnClientDrop, "drop");
	// Command
	RegAdminCmd("sm_forcestart", Command_Forcestart, ADMFLAG_GENERIC);
	RegConsoleCmd("sm_ready", Command_Ready);
	RegConsoleCmd("sm_r", Command_Ready);
	RegConsoleCmd("sm_pause", Command_Pause);
	RegConsoleCmd("sm_unpause", Command_UnPause);
	RegAdminCmd("sm_test", Test, ADMFLAG_ROOT);
	
	g_clients = new ArrayList();
	g_RequestRevote = new ArrayList();
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast){
	g_bIsFreezeTime = true;
}

public Action Event_FreezeEnd(Event event, const char[] name, bool dontBroadcast){
	g_bIsFreezeTime = false;
}

public Action Test(int client, int args){
	NextStage();
}

public Action OnClientDrop(int client, const char[] command, int args){
	if (Match_IsWarmup()){
		Match_Ready(client);
	}
}

public Action Command_Forcestart(int client, int args){
	if (Match_IsWarmup()){
		for (int i = 0; i < MaxClients; i++){
			if (IsPlayer(i)) Match_Ready(i);
		}
	} else {
		Match_Message(client, "仅热身可使用");
	}
}

/* pause start */
public Action Command_Pause(int client, int args){
	if (!Match_IsLive()) return;
	int team = view_as<int>(Match_GetClientTeamtype(client)) - 1; // type conversion
	if (g_tTeam[team].pause < g_cPauseCount.IntValue){
		ServerCommand("mp_pause_match");
		Match_MessageToAll("{purple}%N{default} 发起了暂停", client);
		g_bIsPaused = true;
		g_tTeam[team].pause++;
		return;
	}
	Match_Message(client, "你所在的队伍投票次数已用完");
}

public Action Command_UnPause(int client, int args){
	if (g_bIsPaused && g_bIsFreezeTime){
		CustomVoteSetup setup;
		setup.team = CS_TEAM_NONE; // broad team
		setup.initiator = client; // who vote
		setup.issue_id = VOTE_ISSUE_ENDTIMEOUT;
		setup.pass_percentage = 100.0;
		Format(setup.dispstr, sizeof(setup.dispstr), "是否取消暂停？");
		Format(setup.disppass, sizeof(setup.disppass), "正在取消暂停...");
		CustomVotes_Execute(setup, 10, OnVotePassed, OnVoteFailed);
	} else {
		Match_Message(client, "当前不能发起取消暂停投票");
	}
}

public void OnVotePassed(int results[MAXPLAYERS + 1]){
	Match_MessageToAll("投票结果为 {green}取消暂停{default}");
	ServerCommand("mp_unpause_match");
}

public void OnVoteFailed(int results[MAXPLAYERS + 1]){
	Match_MessageToAll("投票结果为 {dark_red}不取消暂停{default}");
}
/* pause end */

public void OnClientPostAdminCheck(int client){
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	if (IsPlayer(client)) g_iServerPlayers++;
	if (Match_IsWarmup() && g_iServerPlayers == MATCH_PLAYERS){
		StartCountdown();
	}
}

public void OnClientDisconnect(int client){
	if (!IsPlayer(client)) return;
	g_iServerPlayers--;
	if (Match_IsWarmup() && GetRealClientCount() < 10) g_bIsCountdown = false;
	int index = g_RequestRevote.FindValue(client);
	if (index != -1) g_RequestRevote.Erase(index);
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast){
	switch (Match_GetGameState()){
		case GameState_KnifeRound:{
			Match_SetGameState(GameState_ChooseTeam);
			PickTeam(event.GetInt("winner"));
		}
		case GameState_Live:{
			if (GetTeamScore(CS_TEAM_CT) == 15 && GetTeamScore(CS_TEAM_T) == 15) VoteOvertime();
		}
	}
}

public Action Event_MatchEnd(Event event, const char[] name, bool dontBroadcast){
	if (Match_IsLive()){
		EndMatch();
	}
}

public Action Event_ClientSpawn(Event event, const char[] name, bool dontBroadcast){
	if (Match_IsWarmup()){ // set money after client respawn in warmup
		int client = GetClientOfUserId(event.GetInt("userid"));
		SetMoney(client);
	}
}

public Action Command_Ready(int client, int args){
	Match_Ready(client);
}

public void Match_OnReady(int client){
	Match_MessageToAll("{purple}%N{default} 已准备.", client);
}

public void Match_OnGameStateChanged(GameState oldValue, GameState newValue){
	switch (oldValue){
		case GameState_Warmup:{
			g_bIsCountdown = false;
			RestoreVar();
		}
	}
	switch (newValue){
		case GameState_Warmup:StartWarmup();
		case GameState_KnifeRound:{
			g_bIsChangeMap = false;
			g_RequestRevote.Clear();
		}
	}
}

public void OnMapStart(){
	RestoreVar();
	CreateTimer(3.0, Timer_LoadConfig);
}

public Action Timer_LoadConfig(Handle timer){
	Match_SetGameState(GameState_Warmup);
}

public Action CS_OnBuyCommand(int client, const char[] weapon){
	if (Match_IsWarmup() && g_bIsChangeMap && StrEqual(weapon, "decoy") && g_RequestRevote.FindValue(client) == -1){ // warmup & change map & buy decoy & not request
		if (g_RequestRevote.Length == 6){
			g_RequestRevote.Clear();
			Match_MessageToAll("已有7人请求重新选图, 所有玩家准备后将会重新选图");
			g_bIsChangeMap = false;
			return;
		}
		g_RequestRevote.Push(client);
		Match_MessageToAll("{purple}%N{default} 请求重新选图 {green}%d / 7", client, g_RequestRevote.Length);
	}
}