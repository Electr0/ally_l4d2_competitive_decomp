#include <sourcemod>
#include <sdktools>
#include <left4downtown>
#include <l4d2_direct>

#undef REQUIRE_PLUGIN
#include <readyup>
#define REQUIRE_PLUGIN

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

new bool:PlayerSpawned[MAXPLAYERS+1];
new storedClass[MAXPLAYERS+1];
new Float:fTankPls[MAXPLAYERS+1];
new bool:bKeepChecking[MAXPLAYERS+1];
new Handle:g_SpawnsArray;
new bool:readyUpIsAvailable;
new bool:bLive;
new Handle:g_hSetClass;
new Handle:g_hCreateAbility;
new g_oAbility;
new Handle:hDominators;
new Handle:hSpitterLimit;
new Handle:hMaxSI;
new dominators;
new spitterlimit;
new maxSI;

public Plugin:myinfo =
{
	name = "L4D2 Proper Sack Order",
	description = "Finally fix that pesky spawn rotation not being reliable",
	author = "Sir",
	version = "1.2",
	url = "nah"
};

public OnPluginStart()
{
	HookEvent("round_start", CleanUp, EventHookMode:1);
	HookEvent("round_end", CleanUp, EventHookMode:1);
	HookEvent("player_team", PlayerTeam, EventHookMode:1);
	HookEvent("player_spawn", PlayerSpawn, EventHookMode:1);
	HookEvent("player_death", PlayerDeath, EventHookMode:1);
	Sub_HookGameData();
	g_SpawnsArray = CreateArray(16, 0);
	hMaxSI = FindConVar("z_max_player_zombies");
	maxSI = GetConVarInt(hMaxSI);
	hSpitterLimit = FindConVar("z_versus_spitter_limit");
	spitterlimit = GetConVarInt(hSpitterLimit);
	HookConVarChange(hMaxSI, cvarChanged);
	HookConVarChange(hSpitterLimit, cvarChanged);
}

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

public OnConfigsExecuted()
{
	dominators = 53;
	hDominators = FindConVar("l4d2_dominators");
	if (hDominators != null)
	{
		dominators = GetConVarInt(hDominators);
	}
}

public CleanUp(Handle:event, String:name[], bool:dontBroadcast)
{
	CleanSlate();
}

public PlayerSpawn(Handle:event, String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (!IsValidClient(client) || IsFakeClient(client) || GetClientTeam(client) == 3 || !bLive || GetEntProp(client, Prop_Send, "m_zombieClass") == ZC_TANK)
	{
		return;
	}
	
	PlayerSpawned[client] = true;
}

public PlayerTeam(Handle:event, String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new oldteam = GetEventInt(event, "oldteam");
	
	if (!IsValidClient(client) || oldteam == 3 || !bLive || GetEntProp(client, Prop_Send, "m_isGhost") < 1 || GetEntProp(client, Prop_Send, "m_zombieClass") == ZC_TANK)
	{
		return;
	}
	
	PlayerSpawned[client] = false;
	storedClass[client] = 0;
	ShiftArrayUp(g_SpawnsArray, 0);
	SetArrayCell(g_SpawnsArray, 0, GetEntProp(client, Prop_Send, "m_zombieClass"));
}


public OnClientDisconnect(client)
{
	if (!IsValidClient(client) || IsFakeClient(client))
	{
		return;
	}
	PlayerSpawned[client] = false;
}

public PlayerDeath(Handle:event, String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsValidClient(client) || GetClientTeam(client) == 3 || !bLive)
	{
		return;
	}
	
	new SI = GetEntProp(client, Prop_Send, "m_zombieClass");
	if (SI != ZC_TANK && fTankPls[client] < GetGameTime())
	{
		if (!storedClass[client])
		{
			PushArrayCell(g_SpawnsArray, GetEntProp(client, Prop_Send, "m_zombieClass"));
		}
	}
	
	if (SI == ZC_TANK)
	{
		storedClass[client] = 0;
	}
	
	if (!IsFakeClient(client))
	{
		PlayerSpawned[client] = false;
	}
}

public Action:L4D_OnFirstSurvivorLeftSafeArea(client)
{
	if (readyUpIsAvailable && IsInReady())
	{
		bLive = false;
	}
	else
	{
		ClearArray(g_SpawnsArray);
		FillArray(g_SpawnsArray);
		bLive = true;
	}
}

public L4D_OnEnterGhostState(client)
{
	if (!bLive || !IsValidClient(client) || GetClientTeam(client) == 3 || PlayerSpawned[client] || fTankPls[client] > GetGameTime())
	{
		return;
	}
	
	new SI = ReturnNextSIInQueue(client);
	
	if (SI > 0)
	{
		Sub_DetermineClass(client, SI);
	}
	
	if (bKeepChecking[client])
	{
		storedClass[client] = SI;
		bKeepChecking[client] = false;
	}
}

public Action:L4D_OnTryOfferingTankBot(tank_index, &bool:enterStasis)
{
	if (IsFakeClient(tank_index))
	{
		CreateTimer(0.01, CheckTankie);
	}
}

public L4D2_OnTankPassControl(oldTank, newTank, passCount)
{
	if (!IsFakeClient(newTank))
	{
		if (storedClass[newTank] > 0)
		{
			if (!PlayerSpawned[newTank])
			{
				PushArrayCell(g_SpawnsArray, storedClass[newTank]);
			}
		}
		bKeepChecking[newTank] = false;
	}
	else
	{
		fTankPls[oldTank] = GetGameTime() + 2.0;
		storedClass[oldTank] = 0;
	}
}

public Action:CheckTankie(Handle:timer)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && !IsFakeClient(i) && GetClientTeam(i) == 3)
		{
			if (L4D2Direct_GetTankTickets(i) == 20000)
			{
				if (GetEntProp(i, Prop_Send, "m_isGhost") > 0)
				{
					storedClass[i] = GetEntProp(i, Prop_Send, "m_zombieClass");
				}
				bKeepChecking[i] = true;
			}
		}
	}
}

public Sub_HookGameData()
{
	new Handle:g_hGameConf = LoadGameConfigFile("l4d2_zcs");

	if (g_hGameConf != INVALID_HANDLE)
	{
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(g_hGameConf, SDKConf_Signature, "SetClass");
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		g_hSetClass = EndPrepSDKCall();

		if (g_hSetClass == INVALID_HANDLE)
			SetFailState("Unable to find SetClass signature.");

		StartPrepSDKCall(SDKCall_Static);
		PrepSDKCall_SetFromConf(g_hGameConf, SDKConf_Signature, "CreateAbility");
		PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
		PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
		g_hCreateAbility = EndPrepSDKCall();

		if (g_hCreateAbility == INVALID_HANDLE)
			SetFailState("Unable to find CreateAbility signature.");

		g_oAbility = GameConfGetOffset(g_hGameConf, "oAbility");

		CloseHandle(g_hGameConf);
	}
	else
	{
		SetFailState("Unable to load l4d2_zcs.txt");
	}
}

public Sub_DetermineClass(any:Client, any:ZClass)
{
	new WeaponIndex;
	while ((WeaponIndex = GetPlayerWeaponSlot(Client, 0)) != -1)
	{
		RemovePlayerItem(Client, WeaponIndex);
		RemoveEdict(WeaponIndex);
	}
	SDKCall(g_hSetClass, Client, ZClass);
	AcceptEntityInput(MakeCompatEntRef(GetEntProp(Client, Prop_Send, "m_customAbility")), "Kill");
	SetEntProp(Client, Prop_Send, "m_customAbility", GetEntData(SDKCall(g_hCreateAbility, Client), g_oAbility));
}

public cvarChanged(Handle:cvar, String:oldValue[], String:newValue[])
{
	maxSI = GetConVarInt(hMaxSI);
	spitterlimit = GetConVarInt(hSpitterLimit);
}

ReturnNextSIInQueue(client)
{
	new QueuedSI;
	new QueuedIndex;
	if (GetArraySize(g_SpawnsArray) > 0)
	{
		if (dominators && !IsTankInPlay() && !IsSupportSIAlive(client) && IsInfectedTeamFull())
		{
			QueuedSI = ZC_BOOMER;
			QueuedIndex = FindValueInArray(g_SpawnsArray, ZC_BOOMER);
			new iTempIndex = FindValueInArray(g_SpawnsArray, ZC_SPITTER);
			if (QueuedIndex > iTempIndex || QueuedIndex == -1)
			{
				QueuedSI = ZC_SPITTER;
				QueuedIndex = iTempIndex;
			}
		}
		else
		{
			QueuedSI = GetArrayCell(g_SpawnsArray, 0);
			if (QueuedSI == ZC_SPITTER && spitterlimit)
			{
				QueuedSI = GetArrayCell(g_SpawnsArray, ZC_SMOKER);
				QueuedIndex = ZC_SMOKER;
			}
		}
		RemoveFromArray(g_SpawnsArray, QueuedIndex);
	}
	return QueuedSI;
}

CleanSlate()
{
	bLive = false;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			PlayerSpawned[i] = false;
			fTankPls[i] = 0.0;
			storedClass[i] = 0;
			bKeepChecking[i] = false;
		}
	}
}

bool:IsTankInPlay()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i) && IsTank(i))
		{
			return true;
		}
	}
	return false;
}

bool:IsInfectedTeamFull()
{
	new SI;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && !IsFakeClient(i) && GetClientTeam(i) == 3)
		{
			SI++;
		}
	}
	
	if (SI >= maxSI)
	{
		return true;
	}
	return false;
}

bool:IsSupportSIAlive(client)
{
	new iSupport;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i) && i != client)
		{
			if (IsSupport(i))
			{
				iSupport++;
			}
		}
	}
	return false;
}

bool:IsSupport(client)
{
	new ZClass = GetEntProp(client, Prop_Send, "m_zombieClass");
	return ZClass == ZC_BOOMER || ZClass == ZC_SPITTER;
}

FillArray(Handle:array)
{
	new smokers = GetConVarInt(FindConVar("z_versus_smoker_limit"));
	new boomers = GetConVarInt(FindConVar("z_versus_boomer_limit"));
	new hunters = GetConVarInt(FindConVar("z_versus_hunter_limit"));
	new spitters = GetConVarInt(FindConVar("z_versus_spitter_limit"));
	new jockeys = GetConVarInt(FindConVar("z_versus_jockey_limit"));
	new chargers = GetConVarInt(FindConVar("z_versus_charger_limit"));
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && !IsFakeClient(i) && GetClientTeam(i) == 3)
		{
			new SI = GetEntProp(i, Prop_Send, "m_zombieClass");
			switch (SI)
			{
				case ZC_SMOKER:
				{
					smokers--;
				}
				case ZC_BOOMER:
				{
					boomers--;
				}
				case ZC_HUNTER:
				{
					hunters--;
				}
				case ZC_SPITTER:
				{
					spitters--;
				}
				case ZC_JOCKEY:
				{
					jockeys--;
				}
				case ZC_CHARGER:
				{
					chargers--;
				}
				default: { }
			}
		}
	}	
	
	while (smokers > 0)
	{
		smokers--;
		PushArrayCell(array, ZC_SMOKER);
	}
	while (boomers > 0)
	{
		boomers--;
		PushArrayCell(array, ZC_BOOMER);
	}
	while (hunters > 0)
	{
		hunters--;
		PushArrayCell(array, ZC_HUNTER);
	}
	while (spitters > 0)
	{
		spitters--;
		PushArrayCell(array, ZC_SPITTER);
	}
	while (jockeys > 0)
	{
		jockeys--;
		PushArrayCell(array, ZC_JOCKEY);
	}
	while (chargers > 0)
	{
		chargers--;
		PushArrayCell(array, ZC_CHARGER);
	}
}

bool:IsTank(client)
{
	return GetEntProp(client, Prop_Send, "m_zombieClass") == ZC_TANK;
}

bool:IsValidClient(client)
{
	if (client <= 0 || client > MaxClients || !IsClientConnected(client))
	{
		return false;
	}
	return IsClientInGame(client);
}