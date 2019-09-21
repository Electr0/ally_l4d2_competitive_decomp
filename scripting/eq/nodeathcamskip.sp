#pragma semicolon 1

#include <sourcemod>
#include <colors>

new bool:Blocked[MAXPLAYERS+1];
new bool:bSkipPrint[MAXPLAYERS+1];
new Float:fSavedTime[MAXPLAYERS+1];

public Plugin:myinfo = 
{
	name = "Death Cam Skip Fix",
	author = "Jacob, Sir",
	description = "Blocks players skipping their death cam by going spec, also puts players in a spec mode on death so they don't get bored.",
	version = "1.4",
	url = "..."
}

public OnPluginStart()
{
	HookEvent("player_death", Event_PlayerDeath);
	AddCommandListener(Listener_Join, "jointeam");
	
	for(new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			Blocked[i] = false;
			bSkipPrint[i] = false;
			fSavedTime[i] = 0.0;
		}
	}
}

public Action:Listener_Join(client, String:command[], argc)
{
	if (client && argc)
	{
		new String:sJoin[32];
		GetCmdArg(1, sJoin, sizeof(sJoin));

		if (StrEqual(sJoin, "Infected", false) || StringToInt(sJoin) == 3)
		{
			if (GetInfectedPlayers() == GetConVarInt(FindConVar("z_max_player_zombies")))
			{
				return Plugin_Handled;
			}
			if (Blocked[client])
			{
				if (!bSkipPrint[client])
				{
					CPrintToChatAll("{red}[{default}Exploit{red}] {olive}%N {default}tried skipping the Death Timer.", client);
					bSkipPrint[client] = true;
				}
				CPrintToChat(client, "{red}[{default}Exploit{red}] {default}You will be unable to join the Team for {red}%.1f {default}Seconds.", fSavedTime[client]+6.0 - GetGameTime());
				CPrintToChat(client, "{red}[{default}Exploit{red}] {default}You will be moved automatically.");
				return Plugin_Handled;
			}
			if (GetInfectedPlayers() + GetBlockedPlayers() == GetConVarInt(FindConVar("z_max_player_zombies")))
			{
				CPrintToChat(client, "{red}[{default}!{red}] {default}This team currently has slots {olive}reserved{default}.");
				return Plugin_Handled;
			}
		}
	}
	return Plugin_Continue;
}

GetInfectedPlayers()
{
	new count;
	
	for(new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 3 && !IsFakeClient(i))
		{
			count++;
		}
	}
	
	return count;
}

GetBlockedPlayers()
{
	new count;
	
	for(new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && bSkipPrint[i] && !IsFakeClient(i))
		{
			count++;
		}
	}
	
	return count;
}

public OnClientPutInServer(client)
{
	bSkipPrint[client] = false;
	Blocked[client] = false;
	fSavedTime[client] = 0.0;
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if (IsValidInfected(client) && Blocked[client])
	{
		if (IsPlayerAlive(client))
		{
			Blocked[client] = false;
			fSavedTime[client] = 0.0;
			bSkipPrint[client] = false;
			return Plugin_Continue;
		}
	}
	return Plugin_Continue;
}

public Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event,"userid"));
	if (IsValidInfected(client) && 0.0 == fSavedTime[client])
	{
		Blocked[client] = true;
		fSavedTime[client] = GetGameTime();
		CreateTimer(0.1, UnblockTimer, client, 3);
	}
}

public Action:UnblockTimer(Handle:timer, any:client)
{
	if (IsValidClient(client))
	{
		new Float:Time = GetGameTime();
		if (Time >= fSavedTime[client]+6.0)
		{
			Blocked[client] = false;
			fSavedTime[client] = 0.0;

			if (bSkipPrint[client] && GetClientTeam(client) == 1)
			{
				ChangeClientTeam(client, 3);
			}
			bSkipPrint[client] = false;
			return Plugin_Stop;
		}
		return Plugin_Continue;
	}
	return Plugin_Stop;
}
bool:IsValidClient(client)
{
	if (client <= 0 || client > MaxClients || !IsClientConnected(client))
	{
		return false;
	}
	
	return IsClientInGame(client) && !IsFakeClient(client);
}
bool:IsValidInfected(client)
{
	if (client <= 0 || client > MaxClients || !IsClientConnected(client))
	{
		return false;
	}

	return IsClientInGame(client) && GetClientTeam(client) == 3 && !IsFakeClient(client);
}