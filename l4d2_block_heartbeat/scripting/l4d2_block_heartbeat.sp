#include <sdktools>

ConVar
    cvar_max_incappted_count;

int
    g_max_incappted_count;

#define HEART_BEAT "player/heartbeatloop.wav"

public Plugin myinfo =
{
	name = "L4D2 Block HeartBeat",
	author = "Lyseria",
	description = "Stop heart beat in death door",
	version = "1.0",
	url = "N/A"
}

public void OnMapStart()
{
    HookEvent("bot_player_replace",Event_PlayerReplaceBot);
    cvar_max_incappted_count = FindConVar("survivor_max_incapacitated_count");
    cvar_max_incappted_count.AddChangeHook(Cvar_HookCallBack);
    PrecacheSound("player/heartbeatloop.wav");
}

public void OnConfigsExecuted()
{
    g_max_incappted_count = cvar_max_incappted_count.IntValue;
}

void Cvar_HookCallBack(ConVar convar, const char[] oldValue, const char[] newValue)
{
    g_max_incappted_count = cvar_max_incappted_count.IntValue;
}

void Event_PlayerReplaceBot(Event event,const char[] name,bool dontbroadcast)
{
	int client = GetClientOfUserId( event.GetInt("player") );
	if( client < 1 || client > MaxClients || !IsClientInGame(client) )
		return;

	if( g_max_incappted_count != 0 )
		return;
        
	StopSound(client, SNDCHAN_STATIC, "player/heartbeatloop.wav");
	StopSound(client, SNDCHAN_STATIC, "player/heartbeatloop.wav");
	StopSound(client, SNDCHAN_STATIC, "player/heartbeatloop.wav");
	StopSound(client, SNDCHAN_STATIC, "player/heartbeatloop.wav");
}

