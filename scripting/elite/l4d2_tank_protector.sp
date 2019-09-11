#include <sourcemod>
#include <sdktools>

new Float:c2m2SafePlace[3] = { -453.0, -5243.0, 32.0 };
new Float:c5m2SafePlace[3] = { -9100.0, -7345.0, 10.0 };
new Float:c5m2SafePlace2[3] = { -9730.0, -6110.0, 162.0 };
new Float:c5m3SafePlace[3] = { 5104.0, 5004.0, 10.0 };
new Float:c2m2Angles[3] = { 0.0, 175.0, 0.0 };

public Plugin:myinfo =
{
	name = "Tank Protector",
	description = "Teleports tanks from unsafe spawns to safer locations.",
	author = "Jacob",
	version = "0.4",
	url = "github.com/jacob404/myplugins"
};

public OnPluginStart()
{
	HookEvent("tank_spawn", TankSpawn_Event, EventHookMode:1);
}

public TankSpawn_Event(Handle:event, String:name[], bool:dontBroadcast)
{
	new tank = GetClientOfUserId(GetEventInt(event, "userid"));
	new Float:position[3] = 0.0;
	GetClientAbsOrigin(tank, position);
	new pos1 = RoundFloat(position[0]);
	new pos2 = RoundFloat(position[1]);
	decl String:mapname[64];
	GetCurrentMap(mapname, 64);
	if (StrEqual(mapname, "c2m2_fairgrounds", true))
	{
		if (pos1 >= -2750 && pos1 <= -1450 && pos2 >= -5450 && pos2 <= -4925)
		{
			TeleportEntity(tank, c2m2SafePlace, c2m2Angles, NULL_VECTOR);
		}
	}
	else if (StrEqual(mapname, "c5m2_park", true))
	{
		if (pos1 >= -7635 && pos1 <= -6700 && pos2 >= -7540 && pos2 <= -6750)
		{
			TeleportEntity(tank, c5m2SafePlace, NULL_VECTOR, NULL_VECTOR);
		}
		else
		{
			if (pos1 >= -9910 && pos1 <= -9365 && pos2 >= -6210 && pos2 <= -5000)
			{
				TeleportEntity(tank, c5m2SafePlace2, NULL_VECTOR, NULL_VECTOR);
			}
		}
	}
	else if (StrEqual(mapname, "c5m3_cemetery", true))
	{
		if (pos1 >= 4020 && pos1 <= 4060 && pos2 >= 5030 && pos2 <= 5300)
		{
			TeleportEntity(tank, c5m3SafePlace, NULL_VECTOR, NULL_VECTOR);
		}
	}
}
