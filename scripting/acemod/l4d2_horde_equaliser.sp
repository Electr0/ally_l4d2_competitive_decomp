#pragma semicolon 1

#include <sourcemod>
#include <left4downtown>
#include <l4d2_direct>
#include <l4d2lib>
#include <colors>

#define HORDE_MIN_SIZE_AUDIAL_FEEDBACK	120
#define MAX_CHECKPOINTS					4

#define HORDE_SOUND	"/npc/mega_mob/mega_mob_incoming.wav"

new Handle:hCvarAllowHordeDuringTanks;
new Handle:hCvarHordeCheckpointAnnounce;

new Address:pZombieManager = Address_Null;

new commonLimit;
new commonTotal;
new lastCheckpoint;

new bool:announcedInChat;
new bool:checkpointAnnounced[MAX_CHECKPOINTS];

public Plugin:myinfo = 
{
	name = "L4D2 Horde Equaliser",
	author = "Visor (original idea by Sir)",
	description = "Make certain event hordes finite",
	version = "4.4.1",
	url = "https://github.com/Attano/L4D2-Competitive-Framework"
};

public OnPluginStart()
{
	new Handle:gamedata = LoadGameConfigFile("left4downtown.l4d2");
	if (!gamedata)
	{
		SetFailState("Left4Downtown2 gamedata missing or corrupt");
	}

	pZombieManager = GameConfGetAddress(gamedata, "ZombieManager");
	if (!pZombieManager)
	{
		SetFailState("Couldn't find the 'ZombieManager' address");
	}

	hCvarAllowHordeDuringTanks = CreateConVar("l4d2_heq_allow_horde_during_tank", "0", "Keep spawning commons during events even when the Tank is up");
	hCvarHordeCheckpointAnnounce = CreateConVar("l4d2_heq_checkpoint_sound", "1", "Play the incoming mob sound at checkpoints (each 1/4 of total commons killed off) to simulate L4D1 behaviour");

	HookEvent("round_start", EventHook:OnRoundStart, EventHookMode_PostNoCopy);
	HookEvent("infected_death", OnInfectedDeath, EventHookMode_Post);
}

public Action:L4D_OnGetScriptValueInt(const String:key[], &retVal)
{
	// "Pause" the infinite horde during the Tank fight
	if(GetConVarBool(hCvarAllowHordeDuringTanks) && StrEqual(key, "ShouldAllowMobsWithTank", true))
	{
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public OnMapStart()
{
	commonLimit = L4D2_GetMapValueInt("horde_limit", -1);
	PrecacheSound(HORDE_SOUND);
}

public OnRoundStart()
{
	commonTotal = 0;
	lastCheckpoint = 0;
	announcedInChat = false;
	for (new i = 0; i < MAX_CHECKPOINTS; i++)
	{
		checkpointAnnounced[i] = false;
	}
}

public OnInfectedDeath(Handle:event, String:name[], bool:dontBroadcast)
{
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	if (IsSurvivor(attacker) && IsInfiniteHordeActive())
	{
		commonTotal++;
		
		// Horde too small for audial feedback
		if (commonLimit < HORDE_MIN_SIZE_AUDIAL_FEEDBACK)
		{
			return;
		}
		
		// Our job here is done
		if (commonTotal >= commonLimit)
		{
			return;
		}

		if (GetConVarBool(hCvarHordeCheckpointAnnounce) && commonTotal >= RoundFloat(float(commonLimit / MAX_CHECKPOINTS)) * (lastCheckpoint + 1))
		{
			CreateTimer(GetRandomFloat(0.5, 5.0), AnnounceHordeViaAudio, TIMER_FLAG_NO_MAPCHANGE);
			checkpointAnnounced[lastCheckpoint] = true;
			lastCheckpoint++;
			new commonsLeft = commonLimit - commonTotal;
			if (commonsLeft > 10)
			{
				CPrintToChatAll("<{olive}HordeManager{default}> {red}%i{default} commons left to go!", commonsLeft);
			}
		}
	}
}

public Action:AnnounceHordeViaAudio(Handle:timer)
{
	EmitSoundToAll(HORDE_SOUND);
}

public Action:L4D_OnSpawnMob(&amount)
{
	/////////////////////////////////////
	// - Called on Event Hordes.
	// - Called on Panic Event Hordes.
	// - Called on Natural Hordes.
	// - Called on Onslaught (Mini-finale or finale Scripts)

	// - Not Called on Boomer Hordes.
	// - Not Called on z_spawn mob.
	////////////////////////////////////
	
	// Excluded map -- don't block any infinite hordes on this one
	if (commonLimit < 0)
	{
		return Plugin_Continue;
	}
	
	// If it's a "finite" infinite horde...
	if (IsInfiniteHordeActive())
	{
		if (!announcedInChat)
		{
			CPrintToChatAll("<{olive}HordeManager{default}> A {blue}finite event{default} of {olive}%i{default} common infected has started!", commonLimit);
			announcedInChat = true;
		}
		
		// ...and it's overlimit...
		if (commonTotal >= commonLimit)
		{
			SetPendingMobCount(0);
			amount = 0;
			return Plugin_Handled;
		}
	}
	
	// ...or not.
	return Plugin_Continue;
}

bool:IsSurvivor(client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2);
}

bool:IsInfiniteHordeActive()
{
	new countdown = GetHordeCountdown();
	return (/*GetPendingMobCount() > 0 &&*/ countdown > -1 && countdown <= 10);
}

// GetPendingMobCount()
// {
	// return LoadFromAddress(pZombieManager + Address:528, NumberType_Int32);
// }

SetPendingMobCount(count)
{
	return StoreToAddress(pZombieManager + Address:528, count, NumberType_Int32);
}

GetHordeCountdown()
{
	return CTimer_HasStarted(L4D2Direct_GetMobSpawnTimer()) ? RoundFloat(CTimer_GetRemainingTime(L4D2Direct_GetMobSpawnTimer())) : -1;
}