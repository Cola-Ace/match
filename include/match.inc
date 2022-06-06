#if defined _match_included
#endinput
#endif
#define _match_included

enum GameState {
  GameState_None,                          // no setup has taken place
  GameState_Warmup,                        // setup done, waiting for players to ready up
  GameState_VoteMap,											 // vote map
  GameState_VotePick,											 // vote pick style
  GameState_CaptainPick,                   // only used if TeamType_Captains is the teamtype
  GameState_KnifeRound,                    // in the knife round
  GameState_ChooseTeam,										 // choose team after knife round
  GameState_Live,                          // the match is live
};

enum TeamType {
	TeamType_Team1, // team1
	TeamType_Team2, // team2
}

// call it when game state had been changed.
forward void Match_OnGameStateChanged(GameState oldValue, GameState newValue);

// call it when player is ready.
forward void Match_OnReady(int client);

// call it when match over.
forward void Match_OnMatchOver();

// call it when live.
forward void Match_OnLive();

// print message to client (with color and prefix).
native void Match_Message(int client, const char[] format, any:...);

// print message to team (with color and prefix).
native void Match_MessageToTeam(int team, const char[] format, any:...);

// print message to all (with color and prefix).
native void Match_MessageToAll(const char[] format, any:...);

// set game state, and it will call Match_OnGameStateChanged.
native void Match_SetGameState(GameState state);

// set captain.
native void Match_SetCaptain(int client, TeamType type);

// set client ready.
native void Match_Ready(int client);

// set client unready.
native void Match_UnReady(int client);

// get captain client index.
native int Match_GetCaptain(TeamType type);

// get ready players count.
native int Match_GetReadyPlayers();

// return true if client is ready, always false if client is not valid.
native bool Match_IsReady(int client);

// return true if is warmup.
native bool Match_IsWarmup();

// return true if is live.
native bool Match_IsLive();

// return true if client is captain.
native bool Match_IsCaptain(int client);

// return teamtype where client in always -1 when client not in any team.
native TeamType Match_GetClientTeamtype(int client);

// return game state.
native GameState Match_GetGameState();

public SharedPlugin __pl_match = {
    name = "match", file = "match.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_match_SetNTVOptional() {
	MarkNativeAsOptional("Match_Message");
  MarkNativeAsOptional("Match_MessageToAll");
  MarkNativeAsOptional("Match_MessageToTeam");
  MarkNativeAsOptional("Match_GetGameState");
  MarkNativeAsOptional("Match_SetGameState");
  MarkNativeAsOptional("Match_IsWarmup");
  MarkNativeAsOptional("Match_IsLive");
  MarkNativeAsOptional("Match_SetCaptain");
  MarkNativeAsOptional("Match_GetCaptain");
  MarkNativeAsOptional("Match_Ready");
  MarkNativeAsOptional("Match_UnReady");
  MarkNativeAsOptional("Match_IsReady");
  MarkNativeAsOptional("Match_IsCaptain");
  MarkNativeAsOptional("Match_GetClientTeamtype");
  MarkNativeAsOptional("Match_GetReadyPlayers");
}
#endif