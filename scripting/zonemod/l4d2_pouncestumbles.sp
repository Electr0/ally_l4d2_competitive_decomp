#include <sourcemod>
#include <left4downtown>
#include <sdkhooks>

#pragma newdecls required

int iStumbledBy[MAXPLAYERS+1];
ConVar hStumbleFlags;

public Plugin myinfo =
{
	name = "Increase Stumble Duration for Hunters",
	description = "See title.",
	author = "Sir",
	version = "1.0",
	url = "None."
};

public void OnPluginStart()
{
	hStumbleFlags = CreateConVar("pouncestumbles_flags", "1", "Which classes have an increased stumble duration? - 1: Hunter, 2: Jockey, 3: Both.");
}

public Action L4D2_OnPounceOrLeapStumble(int victim, int attacker)
{
	if (!IsValidClient(victim) || !IsValidClient(attacker))
	{
		return Plugin_Continue;
	}
	
	switch (hStumbleFlags.IntValue)
	{
		case 1:
		{
			if (!IsHunter(attacker))
			{
				return Plugin_Continue;
			}
		}
		case 2:
		{
			if (!IsJockey(attacker))
			{
				return Plugin_Continue;
			}
		}
		default:
		{
			if (!IsHunter(attacker) && !IsJockey(attacker))
			{
				return Plugin_Continue;
			}
		}
	}
	
	iStumbledBy[victim] = attacker;
	SDKHook(victim, SDKHook_PostThink, PostThink);
	
	return Plugin_Continue;
}
public void PostThink(int victim)
{
	if (!IsValidClient(victim) || GetClientTeam(victim) == 2)
	{
		return;
	}
	
	SetEntPropFloat(victim, Prop_Send, "m_flCycle", 1000.0);
	L4D_StaggerPlayer(victim, iStumbledBy[victim], NULL_VECTOR);
	
	SDKUnhook(victim, SDKHook_PostThink, PostThink);
}
bool IsValidClient(int client)
{
	if (client <= 0 || client > MaxClients || !IsClientConnected(client))
	{
		return false;
	}
	
	if (!IsClientInGame(client))
	{
		return false;
	}
	
	return true;
}

bool IsJockey(int client)
{
	return GetEntProp(client, Prop_Send, "m_zombieClass") == 5;
}

bool IsHunter(int client)
{
	return GetEntProp(client, Prop_Send, "m_zombieClass") == 3;
}
