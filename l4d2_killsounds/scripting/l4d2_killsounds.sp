#include <sdktools>

public Plugin myinfo =
{
	name = "L4D2 Kill Sounds",
	author = "Lyseria",
	description = "Play a sound to survivor when they kill a special infected.",
	version = "1.0",
	url = "N/A"
}

public void OnPluginStart()
{
	PrecacheSound("buttons/bell1.wav");
//	PrecacheSound("ui/alert_clink.wav");
//	PrecacheSound("ui/buttonclickrelease.wav");
//	PrecacheSound("ui/critical_event_1.wav");
//	PrecacheSound("ui/menu_countdown.wav");

	HookEvent("player_death", Event_PlayerDeath);
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId( event.GetInt("userid") );
	if( client < 1 || client > MaxClients || !IsClientInGame(client) || GetClientTeam(client) != 3 )
		return;
	
	int attacker = GetClientOfUserId( event.GetInt("attacker") );
	if( attacker < 1 || attacker > MaxClients || !IsClientInGame(attacker) || IsFakeClient(attacker) || GetClientTeam(attacker) != 2)
		return;

	EmitSoundToClient(attacker, "buttons/bell1.wav");
//	EmitSoundToClient(attacker, "ui/alert_clink.wav");
//	EmitSoundToClient(attacker, "ui/buttonclickrelease.wav");
//	EmitSoundToClient(attacker, "ui/critical_event_1.wav");
//	EmitSoundToClient(attacker, "ui/menu_countdown.wav");
}