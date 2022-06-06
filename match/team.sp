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

stock void UpdateCoachTarget(int client, int csTeam) {
  SetEntProp(client, Prop_Send, "m_iCoachingTeam", csTeam);
}

stock bool IsClientCoaching(int client) {
  return GetClientTeam(client) == CS_TEAM_SPECTATOR &&
         GetEntProp(client, Prop_Send, "m_iCoachingTeam") != 0;
}

stock int GetCoachTeam(int client) {
  return GetEntProp(client, Prop_Send, "m_iCoachingTeam");
}