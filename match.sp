#include <sourcemod>
#include <cstrike>
#include <sdktools>
#include "include/restorecvars.inc"
#include "include/match.inc"
#include "include/fys.huds.inc"

#pragma semicolon 1
#pragma newdecls required

#define MAP_COUNTS 9
#define PICK_METHODS 2
#define MATCH_PLAYERS 10

GameState g_GameState = GameState_None;

bool g_bIsReady[MAXPLAYERS + 1] = false;
bool g_bIsChangeMap = false;
bool g_bIsCountdown = false;
bool g_bEnableFriendlyfire = false;

int g_iServerPlayers = 0;
int g_iCountdown = 30;
int g_iVoteMapCounts[MAP_COUNTS] = 0;
int g_iVotePickCounts[PICK_METHODS] = 0;
int g_iPickingCaptain = -1;
int g_iPickCount = 0;
int g_iSelectCT = 0;
int g_iSelectEnableFf = 0;

// Handle
Handle g_hOnMatchOver = INVALID_HANDLE;
Handle g_hOnReady = INVALID_HANDLE;
Handle g_hOnGameStateChanged = INVALID_HANDLE;
Handle g_hOnLive = INVALID_HANDLE;
Handle g_hPickingTimer = INVALID_HANDLE;

// ConVar
ConVar g_cPrefix;
ConVar g_cCaptainPick;
ConVar g_cRecord;
ConVar g_cDemoName;

// Char
char g_CaptainPick[16];

// Team
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
#include "match/team.sp"
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
	RegPluginLibrary("match");
	
	g_cPrefix = CreateConVar("sm_match_prefix", "[{green}Match{default}]", "message prefix");
	g_cCaptainPick = CreateConVar("sm_match_captain_pick", "0", "0 - ABABABABAB, 1 - ABBAABBAAB, 2 - ABAABBABAB", _, true, 0.0, true, 2.0);
	g_cRecord = CreateConVar("sm_match_record_enable", "0", "0 - disable, 1 - enable (need tv_enable 1)", _, true, 0.0, true, 1.0);
	g_cDemoName = CreateConVar("sm_match_record_name", "Match#{map}#{start_time}", "Demo name (support {map} {start_time})");
	AutoExecConfig(true, "match");
	ExecuteAndSaveCvars("sourcemod/match.cfg");
	
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
	AddCommandListener(OnClientDrop, "drop");
	// Command
	RegAdminCmd("sm_forcestart", Command_Forcestart, ADMFLAG_GENERIC);
	RegConsoleCmd("sm_ready", Command_Ready);
	RegConsoleCmd("sm_r", Command_Ready);
	RegConsoleCmd("sm_pause", Command_Pause);
	RegConsoleCmd("sm_unpause", Command_UnPause);
	RegAdminCmd("sm_test", Test, ADMFLAG_ROOT);
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

public Action Command_Pause(int client, int args){
	int team = view_as<int>(Match_GetClientTeamtype(client)) - 1;
	if (g_tTeam[team].pause < 2){
		ServerCommand("mp_pause_match");
		Match_MessageToAll("{purple}%N{default} 发起了暂停", client);
		g_tTeam[team].pause++;
		return;
	}
	Match_Message(client, "你所在的队伍投票次数已用完");
}

public Action Command_UnPause(int client, int args){
	
}

public void OnClientPostAdminCheck(int client){
	if (IsPlayer(client)) g_iServerPlayers++;
	if (Match_IsWarmup() && g_iServerPlayers == MATCH_PLAYERS){
		StartCountdown();
	}
}

public void OnClientDisconnect(int client){
	if (IsPlayer(client)) g_iServerPlayers--;
	if (IsPlayer(client) && Match_IsWarmup() && GetRealClientCount() < 10) g_bIsCountdown = false;
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast){
	if (Match_GetGameState() == GameState_KnifeRound){
		Match_SetGameState(GameState_ChooseTeam);
		PickTeam(event.GetInt("winner"));
	}
}

public Action Event_MatchEnd(Event event, const char[] name, bool dontBroadcast){
	if (Match_IsLive()){
		EndMatch();
	}
}

public Action Event_ClientSpawn(Event event, const char[] name, bool dontBroadcast){
	if (Match_IsWarmup()){
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
	}
}

public void OnMapStart(){
	RestoreVar();
	CreateTimer(3.0, Timer_LoadConfig);
}

public Action Timer_LoadConfig(Handle timer){
	Match_SetGameState(GameState_Warmup);
}