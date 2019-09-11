#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <left4downtown>

enum()
{
	ZC_SMOKER = 1,
	ZC_BOOMER,
	ZC_HUNTER,
	ZC_SPITTER,
	ZC_JOCKEY,
	ZC_CHARGER,
	ZC_TANK = 8
}

new bool:isJockey[MAXPLAYERS+1];

public Plugin:myinfo =
{
	name = "Musical Jockeys",
	description = "Prevents the Jockey from having silent spawns.",
	author = "Jacob",
	version = "1.2",
	url = "Earth"
};

public OnPluginStart()
{
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
}

public OnMapStart()
{
	PrecacheSound("music/bacteria/jockeybacterias.wav");
}

public L4D_OnEnterGhostState(client)
{
	Clear(client);
	new SI = GetEntProp(client, Prop_Send, "m_zombieClass");
	if (SI == ZC_JOCKEY)
	{
		isJockey[client] = true;
	}
}

public Action:Event_PlayerSpawn(Handle:event, String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (IsValidPlayer(client) && GetClientTeam(client) == 3)
	{
		if (GetEntProp(client, Prop_Send, "m_zombieClass") == ZC_TANK)
		{
			Clear(client);
		}
		if (isJockey[client])
		{
			PlaySound();
		}
	}
}

bool:IsValidPlayer(client)
{
	if (client <= 0 || client > MaxClients)
	{
		return false;
	}
	if (!IsClientInGame(client))
	{
		return false;
	}
	if (IsFakeClient(client))
	{
		return false;
	}
	return true;
}

Clear(client)
{
	isJockey[client] = false;
}

PlaySound()
{
	EmitSoundToAll("music/bacteria/jockeybacterias.wav");
}