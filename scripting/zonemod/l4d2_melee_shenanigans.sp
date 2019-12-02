#include <sourcemod>
#include <left4downtown>
#include <sdkhooks>
#include <sdktools>

new ConVar:hDropMethod;
new iDropMethod;

public Plugin:myinfo =
{
	name = "Shove Shenanigans - REVAMPED",
	description = "Stops Shoves slowing the Tank and Charger, gives control over what happens when a Survivor is punched while having a melee out.",
	author = "Sir",
	version = "1.2",
	url = ""
};

public OnPluginStart()
{
	HookEvent("player_hurt", PlayerHit, EventHookMode:1);
	hDropMethod = CreateConVar("l4d2_melee_drop_method", "2", "What to do when a Tank punches a Survivor that's holding out a melee weapon? 0: Nothing. 1: Drop Melee Weapon. 2: Force Switch to Primary Weapon.", 0, false, 0.0, false, 0.0);
	iDropMethod = GetConVarInt(hDropMethod);
	hDropMethod.AddChangeHook(ConVarChange);
}

public Action:PlayerHit(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new Player = GetClientOfUserId(GetEventInt(event, "userid"));
	new String:Weapon[256];
	GetEventString(event, "weapon", Weapon, sizeof(Weapon), "");

	if (IsSurvivor(Player) && StrEqual(Weapon, "tank_claw", true))
	{
		new activeweapon = GetEntPropEnt(Player, Prop_Send, "m_hActiveWeapon");
		if (IsValidEdict(activeweapon))
		{
			new String:weaponname[64];
			GetEdictClassname(activeweapon, weaponname, sizeof(weaponname));
			
			if (StrEqual(weaponname, "weapon_melee", false) && GetPlayerWeaponSlot(Player, 0) != -1)
			{
				switch (iDropMethod)
				{
					case 0:	return Plugin_Continue;
					case 1:	SDKHooks_DropWeapon(Player, activeweapon, NULL_VECTOR, NULL_VECTOR);
					case 2:
					{
						new PrimaryWeapon = GetPlayerWeaponSlot(Player, 0);
						SetEntPropEnt(Player, Prop_Send, "m_hActiveWeapon", PrimaryWeapon, 0);
					}
					default: { }
				}
			}
		}
	}
	return Plugin_Continue;
}

public Action:L4D_OnShovedBySurvivor(shover, shovee, const Float:vector[3])
{
    if (!IsSurvivor(shover) || !IsInfected(shovee)) return Plugin_Continue;
    if (IsTankOrCharger(shovee)) return Plugin_Handled;
    return Plugin_Continue;
}

public Action:L4D2_OnEntityShoved(shover, shovee_ent, weapon, Float:vector[3], bool:bIsHunterDeadstop)
{
    if (!IsSurvivor(shover) || !IsInfected(shovee_ent)) return Plugin_Continue;
    if (IsTankOrCharger(shovee_ent)) return Plugin_Handled;
    return Plugin_Continue;
}
 
stock bool:IsSurvivor(client)
{
    return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2;
}
 
stock bool:IsInfected(client)
{
    return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 3;
}
 
bool:IsTankOrCharger(client)  
{
    if (!IsPlayerAlive(client))
        return false;
 
    if (GetEntProp(client, Prop_Send, "m_zombieClass") == 8)
        return true;
 
    if (GetEntProp(client, Prop_Send, "m_zombieClass") == 6)
        return true;
 
    return false;
}

public ConVarChange(ConVar:convar, String:oldValue[], String:newValue[])
{
	iDropMethod = StringToInt(newValue);
}