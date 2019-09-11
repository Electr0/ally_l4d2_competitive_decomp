#include <sourcemod>
#include <sdktools>

#undef REQUIRE_PLUGIN
#include <readyup>
#define REQUIRE_PLUGIN

enum L4D2Team
{
	L4D2Team_None = 0,
	L4D2Team_Spectator,
	L4D2Team_Survivor,
	L4D2Team_Infected
}

#if REG_CASTLERS_SYSTEM == 1
new bool:readyUpIsAvailable;
#endif

new Handle:sv_mincmdrate;
new Handle:sv_maxcmdrate;
new Handle:sv_minupdaterate;
new Handle:sv_maxupdaterate;
new Handle:sv_minrate;
new Handle:sv_maxrate;
new Handle:sv_client_min_interp_ratio;
new Handle:sv_client_max_interp_ratio;
new String:netvars[8][8];
new Float:fLastAdjusted[MAXPLAYERS+1];

public Plugin:myinfo =
{
	name = "Lightweight Spectating",
	description = "Forces low rates on spectators",
	author = "Visor",
	version = "1.2",
	url = "https://github.com/Attano/smplugins"
};

public OnPluginStart()
{
	sv_mincmdrate = FindConVar("sv_mincmdrate");
	sv_maxcmdrate = FindConVar("sv_maxcmdrate");
	sv_minupdaterate = FindConVar("sv_minupdaterate");
	sv_maxupdaterate = FindConVar("sv_maxupdaterate");
	sv_minrate = FindConVar("sv_minrate");
	sv_maxrate = FindConVar("sv_maxrate");
	sv_client_min_interp_ratio = FindConVar("sv_client_min_interp_ratio");
	sv_client_max_interp_ratio = FindConVar("sv_client_max_interp_ratio");
	HookEvent("player_team", OnTeamChange, EventHookMode_Post);
}

public OnPluginEnd()
{
	SetConVarString(sv_minupdaterate, netvars[2], false, false);
	SetConVarString(sv_mincmdrate, netvars[0], false, false);
}

#if REG_CASTLERS_SYSTEM == 1
public OnAllPluginsLoaded()
{
	readyUpIsAvailable = LibraryExists("readyup");
}
public OnLibraryRemoved(const String:name[])
{
	if (StrEqual(name, "readyup", true))
	{
		readyUpIsAvailable = false;
	}
}
public OnLibraryAdded(const String:name[])
{
	if (StrEqual(name, "readyup", true))
	{
		readyUpIsAvailable = true;
	}
}
#endif

public OnConfigsExecuted()
{
	GetConVarString(sv_mincmdrate, netvars[0], sizeof(netvars));
	GetConVarString(sv_maxcmdrate, netvars[1], sizeof(netvars));
	GetConVarString(sv_minupdaterate, netvars[2], sizeof(netvars));
	GetConVarString(sv_maxupdaterate, netvars[3], sizeof(netvars));
	GetConVarString(sv_minrate, netvars[4], sizeof(netvars));
	GetConVarString(sv_maxrate, netvars[5], sizeof(netvars));
	GetConVarString(sv_client_min_interp_ratio, netvars[6], sizeof(netvars));
	GetConVarString(sv_client_max_interp_ratio, netvars[7], sizeof(netvars));
	SetConVarInt(sv_minupdaterate, 30);
	SetConVarInt(sv_mincmdrate, 30);
}

public OnClientPutInServer(client)
{
	fLastAdjusted[client] = 0.0;
}

public OnTeamChange(Handle:event, String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	CreateTimer(10.0, TimerAdjustRates, client, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:TimerAdjustRates(Handle:timer, any:client)
{
	AdjustRates(client);
}

public OnClientSettingsChanged(client)
{
	AdjustRates(client);
}

AdjustRates(client)
{
	if (!IsValidClient(client))
	{
		return;
	}
	if (fLastAdjusted[client] < GetEngineTime() - 1.0)
	{
		fLastAdjusted[client] = GetEngineTime();
		new L4D2Team:team = view_as<L4D2Team>(GetClientTeam(client));
		if (team == L4D2Team_Survivor || team == L4D2Team_Infected || (GetFeatureStatus(FeatureType_Native, "IsClientCaster") == FeatureStatus_Available && IsClientCaster(client)))
		{
			ResetRates(client);
		}
		else
		{
			if (team == L4D2Team_Spectator)
			{
				SetSpectatorRates(client);
			}
		}
	}
}

SetSpectatorRates(client)
{
	SendConVarValue(client, sv_mincmdrate, "30");
	SendConVarValue(client, sv_maxcmdrate, "30");
	SendConVarValue(client, sv_minupdaterate, "30");
	SendConVarValue(client, sv_maxupdaterate, "30");
	SendConVarValue(client, sv_minrate, "10000");
	SendConVarValue(client, sv_maxrate, "10000");
	SetClientInfo(client, "cl_updaterate", "30");
	SetClientInfo(client, "cl_cmdrate", "30");
}

ResetRates(client)
{
	SendConVarValue(client, sv_mincmdrate, netvars[0]);
	SendConVarValue(client, sv_maxcmdrate, netvars[1]);
	SendConVarValue(client, sv_minupdaterate, netvars[2]);
	SendConVarValue(client, sv_maxupdaterate, netvars[3]);
	SendConVarValue(client, sv_minrate, netvars[4]);
	SendConVarValue(client, sv_maxrate, netvars[5]);
	SetClientInfo(client, "cl_updaterate", netvars[3]);
	SetClientInfo(client, "cl_cmdrate", netvars[1]);
}

bool:IsValidClient(client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client));
}