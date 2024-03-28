#include <sdkhooks>

int
	WeaponDrop;

public Plugin myinfo =
{
	name = "L4D2 Drop Secondary",
	author = "Lyseria",
	version	= "1.0",
	url = ""
};

public void OnPluginStart()
{
	WeaponDrop = FindSendPropInfo("CTerrorPlayer", "m_knockdownTimer") + 116;
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client) || GetClientTeam(client) != 2)
		return;

	int entity = GetEntDataEnt2(client, WeaponDrop);
	SetEntDataEnt2(client, WeaponDrop, -1, true);
	if (entity > MaxClients && IsValidEntity(entity) && GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity") == client)
	{
		float vecTarget[3];
		GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", vecTarget);
		SDKHooks_DropWeapon(client, entity, vecTarget, NULL_VECTOR, false);
	}
}
