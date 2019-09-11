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
new bool:readyUpIsAvailable;
new bool:bLive;
new Handle:g_hCvarHunterLimit;
new Handle:g_hCvarSmokerLimit;
new Handle:g_hCvarJockeyLimit;
new Handle:g_hCvarChargerLimit;
new Handle:g_hCvarBoomerLimit;
new Handle:g_hCvarSpitterLimit;
new Handle:g_hCvarTotalSI;
new maxSmokers;
new maxBoomers;
new maxHunters;
new maxSpitters;
new maxJockeys;
new maxChargers;
new maxSI;
new Handle:g_hSetClass;
new Handle:g_hCreateAbility;
new g_oAbility;

public Plugin:myinfo =
{
	name = "L4D2 Proper Sack Order",
	description = "Finally fix that pesky spawn rotation not being reliable",
	author = "Sir",
	version = "1.0",
	url = "nah"
};

public OnPluginStart()
{
	HookEvent("round_end", RoundEnd, EventHookMode_Pre);
	HookEvent("player_spawn", PlayerSpawn, EventHookMode_Post);
	HookEvent("player_death", PlayerDeath, EventHookMode_Post);
	Sub_HookGameData();
	g_hCvarHunterLimit = FindConVar("z_versus_hunter_limit");
	g_hCvarSmokerLimit = FindConVar("z_versus_smoker_limit");
	g_hCvarJockeyLimit = FindConVar("z_versus_jockey_limit");
	g_hCvarChargerLimit = FindConVar("z_versus_charger_limit");
	g_hCvarBoomerLimit = FindConVar("z_versus_boomer_limit");
	g_hCvarSpitterLimit = FindConVar("z_versus_spitter_limit");
	g_hCvarTotalSI = FindConVar("survivor_limit");
	maxSmokers = GetConVarInt(g_hCvarSmokerLimit);
	maxBoomers = GetConVarInt(g_hCvarBoomerLimit);
	maxHunters = GetConVarInt(g_hCvarHunterLimit);
	maxSpitters = GetConVarInt(g_hCvarSpitterLimit);
	maxJockeys = GetConVarInt(g_hCvarJockeyLimit);
	maxChargers = GetConVarInt(g_hCvarChargerLimit);
	maxSI = GetConVarInt(g_hCvarTotalSI);
	HookConVarChange(g_hCvarHunterLimit, cvarChanged);
	HookConVarChange(g_hCvarSmokerLimit, cvarChanged);
	HookConVarChange(g_hCvarJockeyLimit, cvarChanged);
	HookConVarChange(g_hCvarChargerLimit, cvarChanged);
	HookConVarChange(g_hCvarBoomerLimit, cvarChanged);
	HookConVarChange(g_hCvarSpitterLimit, cvarChanged);
	HookConVarChange(g_hCvarTotalSI, cvarChanged);
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

public RoundEnd(Handle:event, String:name[], bool:dontBroadcast)
{
	CleanSlate();
}
public PlayerSpawn(Handle:event, String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsValidClient(client) || IsFakeClient(client) || GetClientTeam(client) == 3 || !bLive)
	{
		return;
	}
	PlayerSpawned[client] = true;
}
public PlayerDeath(Handle:event, String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsValidClient(client) || IsFakeClient(client) || GetClientTeam(client) == 3 || !bLive)
	{
		return;
	}
	PlayerSpawned[client] = false;
}
public Action:L4D_OnFirstSurvivorLeftSafeArea(client)
{
	if (readyUpIsAvailable && IsInReady())
	{
		bLive = false;
	}
	else
	{
		bLive = true;
	}
}
public L4D_OnEnterGhostState(client)
{
	if (!bLive || !IsValidClient(client) || GetClientTeam(client) == 3 || PlayerSpawned[client])
	{
		return;
	}
	Sub_DetermineClass(client, ReturnNextSIInQueue(client));
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
	AcceptEntityInput(MakeCompatEntRef(GetEntProp(Client, PropType:0, "m_customAbility", 4, 0)), "Kill", -1, -1, 0);
	SetEntProp(Client, PropType:0, "m_customAbility", GetEntData(SDKCall(g_hCreateAbility, Client), g_oAbility, 4), 4, 0);
}
ReturnNextSIInQueue(client)
{
	new QueuedSI;
	new Float:QueuedSITime = 0.0;
	
	for (int i = ZC_SMOKER; i <= ZC_CHARGER; i++)
	{
		if (IsAbleToQueue(i, client))
		{
			if (ITimerLive(L4D2Direct_GetSIClassDeathTimer(i)))
			{
				new Float:ElapsedTimer = ITimer_GetElapsedTime(L4D2Direct_GetSIClassDeathTimer(i));
				if (ElapsedTimer > QueuedSITime)
				{
					QueuedSI = i;
					QueuedSITime = ElapsedTimer;
				}
			}
			QueuedSI = i;
			return QueuedSI;
		}
	}
	return QueuedSI;
}
bool:ITimerLive(IntervalTimer:timer)
{
	if (ITimer_HasStarted(timer))
	{
		return true;
	}
	return false;
}
bool:IsAbleToQueue(ZClass, client)
{
	new zAmount;
	
	for (int i = 1; i <= MAXPLAYERS; i++)
	{
		if (IsValidClient(i) && GetClientTeam(i) == 3 && i != client && GetEntProp(i, Prop_Send, "m_zombieClass") == ZClass)
		{
			zAmount++;
		}
	}
	
	switch (ZClass)
	{
		case ZC_SMOKER:
		{
			if (maxSmokers <= zAmount || maxSmokers)
			{
				return false;
			}
		}
		case ZC_BOOMER:
		{
			if (maxBoomers <= zAmount || maxBoomers)
			{
				return false;
			}
		}
		case ZC_HUNTER:
		{
			if (maxHunters <= zAmount || maxHunters)
			{
				return false;
			}
		}
		case ZC_SPITTER:
		{
			if (maxSpitters <= zAmount || maxSpitters)
			{
				return false;
			}
		}
		case ZC_JOCKEY:
		{
			if (maxJockeys <= zAmount || maxJockeys)
			{
				return false;
			}
		}
		case ZC_CHARGER:
		{
			if (maxChargers <= zAmount || maxChargers)
			{
				return false;
			}
		}
		default: { }
	}
	if (!IsTankInPlay())
	{
		if (!IsSupportSIAlive(client) && !IsSupportZClass(ZClass))
		{
			return false;
		}
	}
	return true;
}

CleanSlate()
{
	bLive = false;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			PlayerSpawned[i] = false;
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
bool:IsSupportSIAlive(client)
{
	new iNonSupport;
	new iSupport;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i) && i != client)
		{
			if (IsSupport(i))
			{
				iSupport++;
			}
			else
			{
				iNonSupport++;
			}
		}
	}
	
	if (iSupport > 0 || iNonSupport < maxSI || (maxBoomers && maxSpitters))
	{
		return true;
	}
	return false;
}
bool:IsSupport(client)
{
	new ZClass = GetEntProp(client, Prop_Send, "m_zombieClass");
	return IsSupportZClass(ZClass);
}
bool:IsSupportZClass(ZClass)
{
	return ZClass == 2 || ZClass == 4;
}
bool:IsTank(client)
{
	return GetEntProp(client, Prop_Send, "m_zombieClass") == 8;
}
bool:IsValidClient(client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client));
}
public cvarChanged(Handle:cvar, String:oldValue[], String:newValue[])
{
	maxSmokers = GetConVarInt(g_hCvarSmokerLimit);
	maxBoomers = GetConVarInt(g_hCvarBoomerLimit);
	maxHunters = GetConVarInt(g_hCvarHunterLimit);
	maxSpitters = GetConVarInt(g_hCvarSpitterLimit);
	maxJockeys = GetConVarInt(g_hCvarJockeyLimit);
	maxChargers = GetConVarInt(g_hCvarChargerLimit);
	maxSI = GetConVarInt(g_hCvarTotalSI);
}
