#include <sdktools>

static float
	Time = 1.5;

float
    PressTime[MAXPLAYERS + 1];

public Plugin myinfo =
{
    name = "L4D2 Night Vision",
    author = "Lyseria",
    description = "Sửa đổi nhỏ",
    version = "1.1",
    url = "https://forums.alliedmods.net/showthread.php?p=1576120"
};

public void OnPlayerRunCmdPost(int client, int buttons, int impulse)
{
	float time = GetEngineTime();
	if(impulse != 100) return;
	if(time - PressTime[client] < 0.3)
	{
		SwitchNightVision(client);
	}
	PressTime[client] = time;
}

void SwitchNightVision(int client)
{
	char Word[10];
	int entity = CreateEntityByName("env_instructor_hint");
	int d = GetEntProp(client, Prop_Send, "m_bNightVisionOn");
	if(d == 0)
	{
		SetEntProp(client, Prop_Send, "m_bNightVisionOn", 1); 
		FormatEx(Word, sizeof(Word), "Bật", client);
		DispatchKeyValue(client, "targetname", Word);
		DispatchKeyValue(entity, "hint_target", Word);
		DispatchKeyValue(entity, "hint_range", "0");
		DispatchKeyValue(entity, "hint_forcecaption", "1");
		DispatchKeyValue(entity, "hint_icon_onscreen", "icon_equip_flashlight_active");
		DispatchKeyValue(entity, "hint_caption", Word);
		FormatEx(Word, sizeof(Word), "%f", Time);
		DispatchKeyValue(entity, "hint_timeout", Word);
	
	    //FormatEx(Word, sizeof(Word), "%i %i %i", GetRandomInt(1, 255), GetRandomInt(100, 255), GetRandomInt(1, 255));
		//DispatchKeyValue(entity, "hint_color", Word);
		DispatchKeyValue(entity, "hint_color", "251 234 25");
		
		DispatchSpawn(entity);
		AcceptEntityInput(entity, "ShowHint", client);
		FormatEx(Word, sizeof(Word), "OnUser1 !self:Kill::%f:1", Time);
		SetVariantString(Word);
		AcceptEntityInput(entity, "AddOutput", -1, -1, 0);
		AcceptEntityInput(entity, "FireUser1", -1, -1, 0);	
	}

	else
	{
		SetEntProp(client, Prop_Send, "m_bNightVisionOn", 0); 
		FormatEx(Word, sizeof(Word), "Tắt", client);
		DispatchKeyValue(client, "targetname", Word);
		DispatchKeyValue(entity, "hint_target", Word);
		DispatchKeyValue(entity, "hint_range", "0");
		DispatchKeyValue(entity, "hint_forcecaption", "1");
		DispatchKeyValue(entity, "hint_icon_onscreen", "icon_equip_flashlight");
		DispatchKeyValue(entity, "hint_caption", Word);
	    //FormatEx(Word, sizeof(Word), "%i %i %i", GetRandomInt(1, 255), GetRandomInt(100, 255), GetRandomInt(1, 255));
		//DispatchKeyValue(entity, "hint_color", Word);
		DispatchKeyValue(entity, "hint_color", "25 70 251");

		FormatEx(Word, sizeof(Word), "%f", Time);
		DispatchKeyValue(entity, "hint_timeout", Word);
		DispatchSpawn(entity);
		AcceptEntityInput(entity, "ShowHint", client);
		FormatEx(Word, sizeof(Word), "OnUser1 !self:Kill::%f:1", Time);
		SetVariantString(Word);
		AcceptEntityInput(entity, "AddOutput", -1, -1, 0);
		AcceptEntityInput(entity, "FireUser1", -1, -1, 0);
	}
}
