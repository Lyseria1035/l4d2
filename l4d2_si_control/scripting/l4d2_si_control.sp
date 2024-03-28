#pragma tabsize 1
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define DEBUG		0
#define BENCHMARK	0
#if BENCHMARK
	#include <profiler>
	Profiler g_profiler;
#endif

#define SI_SMOKER		0
#define SI_BOOMER		1
#define SI_HUNTER		2
#define SI_SPITTER		3
#define SI_JOCKEY		4
#define SI_CHARGER		5
#define SI_MAX_SIZE		6

#define SPAWN_NO_PREFERENCE						-1
#define SPAWN_ANYWHERE							0
#define SPAWN_BEHIND_SURVIVORS					1
#define SPAWN_NEAR_IT_VICTIM					2
#define SPAWN_SPECIALS_IN_FRONT_OF_SURVIVORS	3
#define SPAWN_SPECIALS_ANYWHERE					4
#define SPAWN_FAR_AWAY_FROM_SURVIVORS			5
#define SPAWN_ABOVE_SURVIVORS					6
#define SPAWN_IN_FRONT_OF_SURVIVORS				7
#define SPAWN_VERSUS_FINALE_DISTANCE			8
#define SPAWN_LARGE_VOLUME						9
#define SPAWN_NEAR_POSITION						10

Handle
	g_hSpawnTimer,
	g_hRetryTimer,
	g_hUpdateTimer,
	g_hSuicideTimer;

ConVar
	g_cSILimit,
	g_cSpawnSize,
	g_cSpawnLimits[SI_MAX_SIZE],
	g_cSpawnWeights[SI_MAX_SIZE],
	g_cScaleWeights,
	g_cSpawnTimeMode,
	g_cSpawnTimeMin,
	g_cSpawnTimeMax,
	g_cBaseLimit,
	g_cExtraLimit,
	g_cBaseSize,
	g_cExtraSize,
	g_cTankStatusAction,
	g_cTankStatusLimits,
	g_cTankStatusWeights,
	g_cSuicideTime,
	g_cRushDistance,
	g_cSpawnRangeMin,
	g_cSpawnRangeMax,
	g_cFirstSpawnTime,
	g_cSpawnRange,
	g_cDiscardRange,
	g_cSafeSpawnRange;

float
	g_fSpawnTimeMin,
	g_fSpawnTimeMax,
	g_fExtraLimit,
	g_fExtraSize,
	g_fSuicideTime,
	g_fRushDistance,
	g_fFirstSpawnTime,
	g_fSpawnTimes[MAXPLAYERS + 1],
	g_fActionTimes[MAXPLAYERS + 1];

static const char
	g_sZombieClass[SI_MAX_SIZE][] = {
		"smoker",
		"boomer",
		"hunter",
		"spitter",
		"jockey",
		"charger"
	};

int
	g_iSILimit,
	g_iSpawnSize,
	g_iDirection,
	g_iSpawnLimits[SI_MAX_SIZE],
	g_iSpawnWeights[SI_MAX_SIZE],
	g_iSpawnTimeMode,
	g_iTankStatusAction,
	g_iSILimitCache = -1,
	g_iSpawnLimitsCache[SI_MAX_SIZE] = {	
		-1,
		-1,
		-1,
		-1,
		-1,
		-1
	},
	g_iSpawnWeightsCache[SI_MAX_SIZE] = {
		-1,
		-1,
		-1,
		-1,
		-1,
		-1
	},
	g_iTankStatusLimits[SI_MAX_SIZE] = {	
		-1,
		-1,
		-1,
		-1,
		-1,
		-1
	},
	g_iTankStatusWeights[SI_MAX_SIZE] = {	
		-1,
		-1,
		-1,
		-1,
		-1,
		-1
	},
	g_iSpawnSizeCache = -1,
	g_iSpawnCounts[SI_MAX_SIZE],
	g_iBaseLimit,
	g_iBaseSize,
	g_iCurrentClass = -1;

bool
	g_bLateLoad,
	g_bInSpawnTime,
	g_bScaleWeights,
	g_bLeftSafeArea,
	g_bFinaleStarted;

public Plugin myinfo =
{
	name = "L4D2 SI Control Spawn",
	author = "Lyseria",
	description = "",
	version = "1.4",
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	// Điều chỉnh số lượng special infected (hoạt động khi có 4 survivor khởi đầu)
	g_cBaseLimit =					CreateConVar("l4d2_si_start_limit",			"4",		"Với 4 Survivor thì SI sẽ đạt mốc sinh sản tối đa bao nhiêu.", _, true, 0.0, true, 32.0);
	g_cExtraLimit =					CreateConVar("l4d2_extra_si_limit",			"1",		"Với mỗi PLAYER thì SI sẽ được cộng thêm vào bao nhiêu (1 Players - 3 Bots = 4 si_start_limit + 1 players)", _, true, 0.0, true, 32.0);
	g_cBaseSize =					CreateConVar("l4d2_base_spawn",				"1",		"Khi đếm ngược hồi sinh kết thúc, có bao nhiêu SI sẽ xuất hiện cùng 1 lúc", _, true, 0.0, true, 32.0);
	g_cExtraSize =					CreateConVar("l4d2_extra_spawn",			"1",		"Với mỗi PLAYER khi đếm ngược hồi sinh kết thúc, số lượng SI sẽ được thêm vào xuất hiện cùng 1 lúc (1 Players - 3 Bots = 1 base_spawn + 1 extra_spawn)", _, true, 1.0, true, 32.0);

	// Điều chỉnh số lượng special infected (hoạt động khi có trên 5+ survivor)
	g_cSILimit	= 					CreateConVar("l4d2_si_spawn_limit",				"7",				"Khi đạt mốc số lượng tối đa sẽ không sinh sản thêm SI nữa.", _, true, 1.0, true, 32.0);
	g_cSpawnSize = 					CreateConVar("l4d2_spawn_number",				"3",				"Khi đếm ngược hồi sinh kết thúc, có bao nhiêu SI sẽ xuất hiện cùng 1 lúc.", _, true, 1.0, true, 32.0);
	g_cSpawnLimits[SI_SMOKER] = 	CreateConVar("l4d2_smoker_spawn_limit",			"2",				"Sinh sản tối đa Smorker cùng 1 lúc", _, true, 0.0, true, 32.0);
	g_cSpawnLimits[SI_BOOMER] = 	CreateConVar("l4d2_boomer_spawn_limit",			"2",				"Sinh sản tối đa Boomer cùng 1 lúc", _, true, 0.0, true, 32.0);
	g_cSpawnLimits[SI_HUNTER] = 	CreateConVar("l4d2_hunter_spawn_limit",			"4",				"Sinh sản tối đa Hunter cùng 1 lúc", _, true, 0.0, true, 32.0);
	g_cSpawnLimits[SI_SPITTER] = 	CreateConVar("l4d2_spitter_spawn_limit",		"2",				"Sinh sản tối đa Spitter cùng 1 lúc", _, true, 0.0, true, 32.0);
	g_cSpawnLimits[SI_JOCKEY] = 	CreateConVar("l4d2_jockey_spawn_limit",			"4",				"Sinh sản tối đa Jockey cùng 1 lúc", _, true, 0.0, true, 32.0);
	g_cSpawnLimits[SI_CHARGER] = 	CreateConVar("l4d2_charger_spawn_limit",		"4",				"Sinh sản tối đa Charger cùng 1 lúc", _, true, 0.0, true, 32.0);

	// Điều chỉnh tỉ lệ từng SI khi xuất hiện (Tỉ lệ càng cao ưu tiên xuất hiện hơn)
	// Khuyến cáo đặt nhỏ nhất là 100% vì engine game nó thế. Plugin không can thiệp thuật toán. 
	g_cSpawnWeights[SI_SMOKER] =	CreateConVar("l4d2_smoker_percent",			"100",					"Tỉ lệ Smorker sẽ xuất hiện.", _, true, 0.0);
	g_cSpawnWeights[SI_BOOMER] =	CreateConVar("l4d2_boomer_percent",			"200",					"Tỉ lệ Boomer sẽ xuất hiện.", _, true, 0.0);
	g_cSpawnWeights[SI_HUNTER] =	CreateConVar("l4d2_hunter_percent",			"100",					"Tỉ lệ Hunter sẽ xuất hiện.", _, true, 0.0);
	g_cSpawnWeights[SI_SPITTER] =	CreateConVar("l4d2_spitter_percent",		"200",					"Tỉ lệ Spitter sẽ xuất hiện.", _, true, 0.0);
	g_cSpawnWeights[SI_JOCKEY] =	CreateConVar("l4d2_jockey_percent",			"100",					"Tỉ lệ Jockey sẽ xuất hiện.", _, true, 0.0);
	g_cSpawnWeights[SI_CHARGER] =	CreateConVar("l4d2_charger_percent",		"100",					"Tỉ lệ Charger sẽ xuất hiện.", _, true, 0.0);
	
	// Điều chỉnh thời gian xuất hiện và thời gian tồn tại
	g_cScaleWeights =				CreateConVar("l4d2_dead_time_control",				"1",			"Điều chỉnh tỉ lệ tồn tại trên sân [0 = Tắt | 1 = Bật](Nếu được bật, tỉ lệ xuất hiện càng cao - thời gian tồn tại càng ngắn)", _, true, 0.0, true, 1.0);
	g_cSpawnTimeMin =				CreateConVar("l4d2_spawn_time_min",					"20.0",			"Sau khi chết, thời gian đợi hồi sinh ngắn nhất.", _, true, 0.1);
	g_cSpawnTimeMax =				CreateConVar("l4d2_spawn_time_max",					"30.0",			"Sau khi chết, thời gian đợi hồi sinh nhiều nhất.", _, true, 1.0);
	g_cSpawnTimeMode =				CreateConVar("l4d2_auto_time_refresh",				"1",			"Tự động tính toán thời gian và làm mới[0 = Ngẫu nhiên | 1 = Tăng (Giết nhanh - Hồi sinh NHANH) | 2 = Chậm (Sống lâu - Hồi sinh NHANH)]", _, true, 0.0, true, 2.0);

	// Điều chỉnh thông số sẽ thay đổi khi Tank xuất hiện - Sau khi Tank chết sẽ đặt về ban đầu
	g_cTankStatusAction =			CreateConVar("l4d2_tank_parameters",		"1",						"Khi Tank xuất hiện các thông số có thay đổi không? [0 = Không (Giữ nguyên thông số bên trên) | 1 = Có (Tùy chỉnh bên dưới)]", _, true, 0.0, true, 1.0);
	g_cTankStatusLimits =			CreateConVar("l4d2_tank_si_limits",			"2;1;4;1;4;4",				"Số lượng tối đa cùng 1 lúc của từng SI (thứ tự từ trên xuống)");
	g_cTankStatusWeights =			CreateConVar("l4d2_tank_si_percent",		"100;400;100;200;100;100",	"Tỉ lệ của từng SI sẽ xuất hiện (thứ tự từ trên xuống)");
	g_cSuicideTime =				CreateConVar("l4d2_tank_si_dead_time",		"25.0",						"SI sẽ tự động kết liễu sau bao nhiêu giây, khi có tank trên bản đồ.", _, true, 1.0);
	
	// Tính toán khoảng cách (khoảng cách của survivor dẫn đầu trừ đi khoảng cách của survivor cuối cùng, không tính survivor bị incap)
	g_cRushDistance =				CreateConVar("l4d2_rush_distance",			"1500.0",					"SI sẽ xuất hiện cách survivor bao xa (càng xa càng tốn tài nguyên, gần càng khó chơi).", _, true, 0.0);
	g_cSpawnRangeMin =				CreateConVar("l4d2_spawnrange_min",			"300.0",					"Khoảng cách gần nhất mà SI sẽ xuất hiện gần Survivor.", _, true, 0.0);
	g_cSpawnRangeMax =				CreateConVar("l4d2_spawnrange_max",			"1500.0",					"Khoảng cách xa nhất mà SI sẽ xuất hiện so với Survivor.", _, true, 0.0);

	// Đợt SI đầu tiên
	g_cFirstSpawnTime = 			CreateConVar("l4d2_first_time",			"15.0",						"Thời gian làm mới đợt đầu tiên khi tất cả ra khỏi saferoom.", _, true, 0.0);

	g_cSpawnRange =					FindConVar("z_spawn_range");
	g_cDiscardRange =				FindConVar("z_discard_range");
	g_cSafeSpawnRange =				FindConVar("z_safe_spawn_range");

	g_cSpawnSize.AddChangeHook(CvarChanged_Limits);
	for (int i; i < SI_MAX_SIZE; i++) {
		g_cSpawnLimits[i].AddChangeHook(CvarChanged_Limits);
		g_cSpawnWeights[i].AddChangeHook(CvarChanged_General);
	}

	g_cSILimit.AddChangeHook(CvarChanged_Times);
	g_cSpawnTimeMin.AddChangeHook(CvarChanged_Times);
	g_cSpawnTimeMax.AddChangeHook(CvarChanged_Times);
	g_cSpawnTimeMode.AddChangeHook(CvarChanged_Times);

	g_cScaleWeights.AddChangeHook(CvarChanged_General);
	g_cBaseLimit.AddChangeHook(CvarChanged_General);
	g_cExtraLimit.AddChangeHook(CvarChanged_General);
	g_cBaseSize.AddChangeHook(CvarChanged_General);
	g_cExtraSize.AddChangeHook(CvarChanged_General);
	g_cSuicideTime.AddChangeHook(CvarChanged_General);
	g_cRushDistance.AddChangeHook(CvarChanged_General);
	g_cFirstSpawnTime.AddChangeHook(CvarChanged_General);

	g_cTankStatusAction.AddChangeHook(CvarChanged_TankStatus);
	g_cTankStatusLimits.AddChangeHook(CvarChanged_TankCustom);
	g_cTankStatusWeights.AddChangeHook(CvarChanged_TankCustom);

	HookEvent("round_end",				Event_RoundEnd,		EventHookMode_PostNoCopy);
	HookEvent("finale_vehicle_leaving", Event_RoundEnd,		EventHookMode_PostNoCopy);
	HookEvent("round_start",			Event_RoundStart,	EventHookMode_PostNoCopy);
	HookEvent("player_hurt",			Event_PlayerHurt);
	HookEvent("player_team",			Event_PlayerTeam);
	HookEvent("player_spawn",			Event_PlayerSpawn);
	HookEvent("player_death",			Event_PlayerDeath,	EventHookMode_Pre);

	RegAdminCmd("sm_percent",		cmdSetWeight,	ADMFLAG_RCON);
	RegAdminCmd("sm_limit",			cmdSetLimit,	ADMFLAG_RCON);
	RegAdminCmd("sm_timer",			cmdSetTimer,	ADMFLAG_RCON);

	RegAdminCmd("sm_resetspawn",	cmdResetSpawn,	ADMFLAG_RCON);
	RegAdminCmd("sm_forcetimer",	cmdForceTimer,	ADMFLAG_RCON);
	RegAdminCmd("sm_type",			cmdType,		ADMFLAG_ROOT);

	HookEntityOutput("trigger_finale", "FinaleStart", OnFinaleStart);

	if (g_bLateLoad && L4D_HasAnySurvivorLeftSafeArea())
		L4D_OnFirstSurvivorLeftSafeArea_Post(0);
}

public void OnPluginEnd() {
	TweakSettings(true);
}

void TweakSettings(bool restore) {
	if (!restore) {
		g_cSpawnRange.SetInt(g_cSpawnRangeMax.IntValue);
		g_cDiscardRange.SetInt(g_cSpawnRange.IntValue + 500);
		g_cSafeSpawnRange.SetInt(g_cSpawnRangeMin.IntValue);
	}
	else {
		g_cSpawnRange.RestoreDefault();
		g_cDiscardRange.RestoreDefault();
		g_cSafeSpawnRange.RestoreDefault();
	}
}

void OnFinaleStart(const char[] output, int caller, int activator, float delay) {
	g_bFinaleStarted = L4D_IsMissionFinalMap();
}

public Action L4D_OnGetScriptValueInt(const char[] key, int &retVal) {
	if (!g_bInSpawnTime) {
		if (!strcmp(key, "MaxSpecials", false) || !strcmp(key, "cm_MaxSpecials", false)) {
			retVal = 0;
			return Plugin_Handled;
		}
	}
	else if (!strcmp(key, "PreferredSpecialDirection", false)) {
		retVal = g_iDirection;
		return Plugin_Handled;
	}
	else if (!strcmp(key, "MaxSpecials", false) || !strcmp(key, "cm_MaxSpecials", false)) {
		retVal = g_iSILimit;
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public void L4D_OnFirstSurvivorLeftSafeArea_Post(int client) {
	if (g_bLeftSafeArea)
		return;

	g_bLeftSafeArea = true;

	if (g_iCurrentClass >= SI_MAX_SIZE) {
		PrintToChatAll("\x03当前轮换\x01: \n");
		PrintToChatAll("\x01[\x05%s\x01]\x04模式\x01", g_sZombieClass[g_iCurrentClass - SI_MAX_SIZE]);
	}
	else if (g_iCurrentClass > -1)
		PrintToChatAll("\x01[\x05%s\x01]\x04模式\x01", g_sZombieClass[g_iCurrentClass]);

	StartCustomSpawnTimer(g_fFirstSpawnTime);
	delete g_hSuicideTimer;
	g_hSuicideTimer = CreateTimer(2.5, tmrForceSuicide, _, TIMER_REPEAT);
}

Action tmrForceSuicide(Handle timer) {
	static int i;
	static int class;
	static int victim;
	static float time;

	time = GetEngineTime();
	for (i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || !IsFakeClient(i) || GetClientTeam(i) != 3 || !IsPlayerAlive(i))
			continue;

		class = GetEntProp(i, Prop_Send, "m_zombieClass");
		if (class < 1 || class > SI_MAX_SIZE)
			continue;

		if (GetEntProp(i, Prop_Send, "m_hasVisibleThreats")) {
			g_fActionTimes[i] = time;
			continue;
		}

		victim = GetSurVictim(i, class);
		if (victim > 0) {
			if (GetEntProp(victim, Prop_Send, "m_isIncapacitated"))
				KillInactiveSI(i, class);
			else
				g_fActionTimes[i] = time;
		}
		else if (time - g_fActionTimes[i] > g_fSuicideTime)
			KillInactiveSI(i, class);
	}

	return Plugin_Continue;
}

void KillInactiveSI(int client, int class) {
	#if DEBUG
	PrintToServer("[SS] Kill inactive SI -> %N", client);
	#endif
	ForcePlayerSuicide(client);

	if (!g_hRetryTimer)
		ExecuteSpawnQueue(GetTotalSI(), true, class - 1);
}

int GetSurVictim(int client, int class) {
	switch (class) {
		case 1:
			return GetEntPropEnt(client, Prop_Send, "m_tongueVictim");

		case 3:
			return GetEntPropEnt(client, Prop_Send, "m_pounceVictim");

		case 5:
			return GetEntPropEnt(client, Prop_Send, "m_jockeyVictim");

		case 6: {
			class = GetEntPropEnt(client, Prop_Send, "m_pummelVictim");
			if (class > 0)
				return class;

			class = GetEntPropEnt(client, Prop_Send, "m_carryVictim");
			if (class > 0)
				return class;
		}
	}

	return -1;
}

Action cmdSetLimit(int client, int args) {
	if (args == 1) {
		char arg[16];
		GetCmdArg(1, arg, sizeof arg);	
		if (strcmp(arg, "reset", false) == 0) {
			ResetLimits();
			ReplyToCommand(client, "[SS] Spawn Limits reset to default values");
		}
	}
	else if (args == 2) {
		int limit = GetCmdArgInt(2);	
		if (limit < 0)
			ReplyToCommand(client, "[SS] Limit value must be >= 0");
		else {
			char arg[16];
			GetCmdArg(1, arg, sizeof arg);
			if (strcmp(arg, "all", false) == 0) {
				for (int i; i < SI_MAX_SIZE; i++)
					g_cSpawnLimits[i].IntValue = limit;

				PrintToChatAll("\x01[SS] All SI limits have been set to \x05%d", limit);
			} 
			else if (strcmp(arg, "max", false) == 0) {
				g_cSILimit.IntValue = limit;
				PrintToChatAll("\x01[SS] -> \x04Max \x01SI limit set to \x05%i", limit);				   
			} 
			else if (strcmp(arg, "group", false) == 0 || strcmp(arg, "wave", false) == 0) {
				g_cSpawnSize.IntValue = limit;
				PrintToChatAll("\x01[SS] -> SI will spawn in \x04groups\x01 of \x05%i", limit);
			} 
			else  {
				for (int i; i < SI_MAX_SIZE; i++) {
					if (strcmp(g_sZombieClass[i], arg, false) == 0) {
						g_cSpawnLimits[i].IntValue = limit;
						PrintToChatAll("\x01[SS] \x04%s \x01limit set to \x05%i", arg, limit);
					}
				}
			}
		}	 
	} 
	else {
		ReplyToCommand(client, "\x04!limit/sm_limit \x05<class> <limit>");
		ReplyToCommand(client, "\x05<class> \x01[ all | max | group/wave | smoker | boomer | hunter | spitter | jockey | charger ]");
		ReplyToCommand(client, "\x05<limit> \x01[ >= 0 ]");
	}

	return Plugin_Handled;
}

Action cmdSetWeight(int client, int args) {
	if (args == 1) {
		char arg[16];
		GetCmdArg(1, arg, sizeof arg);	
		if (strcmp(arg, "reset", false) == 0) {
			ResetWeights();
			ReplyToCommand(client, "[SS] Spawn weights reset to default values");
		} 
	} 
	else if (args == 2) {
		if (GetCmdArgInt(2) < 0) {
			ReplyToCommand(client, "weight value >= 0");
			return Plugin_Handled;
		} 
		else  {
			char arg[16];
			GetCmdArg(1, arg, sizeof arg);
			int iWeight = GetCmdArgInt(2);
			if (strcmp(arg, "all", false) == 0) {
				for (int i; i < SI_MAX_SIZE; i++)
					g_cSpawnWeights[i].IntValue = iWeight;			

				ReplyToCommand(client, "\x01[SS] -> \x04All spawn weights \x01set to \x05%d", iWeight);	
			} 
			else  {
				for (int i; i < SI_MAX_SIZE; i++) {
					if (strcmp(arg, g_sZombieClass[i], false) == 0) {
						g_cSpawnWeights[i].IntValue = iWeight;
						ReplyToCommand(client, "\x01[SS] \x04%s \x01weight set to \x05%d", g_sZombieClass[i], iWeight);				
					}
				}	
			}
		}
	} 
	else 
	{
		ReplyToCommand(client, "\x04!weight/sm_weight \x05<class> <value>");
		ReplyToCommand(client, "\x05<class> \x01[ reset | all | smoker | boomer | hunter | spitter | jockey | charger ]");	
		ReplyToCommand(client, "\x05value \x01[ >= 0 ]");	
	}

	return Plugin_Handled;
}

Action cmdSetTimer(int client, int args) {
	if (args == 1) {
		float time = GetCmdArgFloat(1);
		if (time < 0.1)
			time = 0.1;

		g_cSpawnTimeMin.FloatValue = time;
		g_cSpawnTimeMax.FloatValue = time;
		ReplyToCommand(client, "\x01[SS] Spawn timer set to constant \x05%.1f \x01seconds", time);
	} 
	else if (args == 2) {
		float min = GetCmdArgFloat(1);
		float max = GetCmdArgFloat(2);
		if (min > 0.1 && max > 1.0 && max > min) {
			g_cSpawnTimeMin.FloatValue = min;
			g_cSpawnTimeMax.FloatValue = max;
			ReplyToCommand(client, "\x01[SS] Spawn timer will be between \x05%.1f \x01and \x05%.1f \x01seconds", min, max);
		} 
		else 
			ReplyToCommand(client, "[SS] Max(>= 1.0) spawn time must greater than min(>= 0.1) spawn time");
	} 
	else 
		ReplyToCommand(client, "[SS] timer <constant> || timer <min> <max>");

	return Plugin_Handled;
}

Action cmdResetSpawn(int client, int args) {	
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i) && GetEntProp(i, Prop_Send, "m_zombieClass") != 8)
			ForcePlayerSuicide(i);
	}

	StartCustomSpawnTimer(g_fSpawnTimes[0]);
	ReplyToCommand(client, "[SS] Slayed all special infected. Spawn timer restarted. Next potential spawn in %.1f seconds.", g_fSpawnTimeMin);
	return Plugin_Handled;
}

Action cmdForceTimer(int client, int args) {
	if (args < 1) {
		StartSpawnTimer();
		ReplyToCommand(client, "[SS] Spawn timer started manually.");
		return Plugin_Handled;
	}

	float time = GetCmdArgFloat(1);
	StartCustomSpawnTimer(time < 0.1 ? 0.1 : time);
	ReplyToCommand(client, "[SS] Spawn timer started manually. Next potential spawn in %.1f seconds.", time);
	return Plugin_Handled;
}

Action cmdType(int client, int args) {
	if (args != 1) {
		ReplyToCommand(client, "\x04!type/sm_type \x05<class>.");
		ReplyToCommand(client, "\x05<type> \x01[ off | random | smoker | boomer | hunter | spitter | jockey | charger ]");
		return Plugin_Handled;
	}

	char arg[16];
	GetCmdArg(1, arg, sizeof arg);
	if (strcmp(arg, "off", false) == 0) {
		g_iCurrentClass = -1;
		ReplyToCommand(client, "已关闭单一特感模式");
		ResetLimits();
	}
	else if (strcmp(arg, "random", false) == 0) {
		PrintToChatAll("\x03当前轮换\x01: \n");
		PrintToChatAll("\x01[\x05%s\x01]\x04模式\x01", g_sZombieClass[SetRandomType()]);
	}
	else {
		int class = GetZombieClass(arg);
		if (class == -1) {
			ReplyToCommand(client, "\x04!type/sm_type \x05<class>.");
			ReplyToCommand(client, "\x05<type> \x01[ off | random | smoker | boomer | hunter | spitter | jockey | charger ]");
		}
		else if (class == g_iCurrentClass)
			ReplyToCommand(client, "目标特感类型与当前特感类型相同");
		else {
			SetSiType(class);
			PrintToChatAll("\x01[\x05%s\x01]\x04模式\x01", g_sZombieClass[class]);
		}
	}

	return Plugin_Handled;
}

int GetZombieClass(const char[] sClass) {
	for (int i; i < SI_MAX_SIZE; i++) {
		if (strcmp(sClass, g_sZombieClass[i], false) == 0)
			return i;
	}
	return -1;
}

int SetRandomType() {
	static int class;
	static int zombieClass[SI_MAX_SIZE] = {0, 1, 2, 3, 4, 5};

	class %= SI_MAX_SIZE;
	if (!class)
		SortIntegers(zombieClass, sizeof zombieClass, Sort_Random);

	SetSiType(zombieClass[class]);
	g_iCurrentClass += SI_MAX_SIZE;
	return zombieClass[class++];
}

void SetSiType(int class) {
	SaveConfiguration();
	for (int i; i < SI_MAX_SIZE; i++)		
		g_cSpawnLimits[i].IntValue = i != class ? 0 : g_iSILimit;

	g_iCurrentClass = class;
}

public void OnConfigsExecuted() {
	GetCvars_Limits();
	GetCvars_Times();
	GetCvars_General();
	GetCvars_TankStatus();
	GetCvars_TankCustom();
	TweakSettings(false);
}

void CvarChanged_Limits(ConVar convar, const char[] oldValue, const char[] newValue) {
	GetCvars_Limits();
}

void GetCvars_Limits() {
	g_iSpawnSize = g_cSpawnSize.IntValue;
	for (int i; i < SI_MAX_SIZE; i++)
		g_iSpawnLimits[i] = g_cSpawnLimits[i].IntValue;
}

void CvarChanged_Times(ConVar convar, const char[] oldValue, const char[] newValue) {
	GetCvars_Times();
}

void GetCvars_Times() {
	g_iSILimit =		g_cSILimit.IntValue;
	g_fSpawnTimeMin =	g_cSpawnTimeMin.FloatValue;
	g_fSpawnTimeMax =	g_cSpawnTimeMax.FloatValue;
	g_iSpawnTimeMode =	g_cSpawnTimeMode.IntValue;

	if (g_fSpawnTimeMin > g_fSpawnTimeMax)
		g_fSpawnTimeMin = g_fSpawnTimeMax;
		
	CalculateSpawnTimes();
}

void CalculateSpawnTimes() {
	if (g_iSILimit <= 1 || g_iSpawnTimeMode <= 0)
		g_fSpawnTimes[0] = g_fSpawnTimeMax;
	else {
		float unit = (g_fSpawnTimeMax - g_fSpawnTimeMin) / (g_iSILimit - 1);
		switch (g_iSpawnTimeMode) {
			case 1:  {
				g_fSpawnTimes[0] = g_fSpawnTimeMin;
				for (int i = 1; i <= MaxClients; i++)
					g_fSpawnTimes[i] = i < g_iSILimit ? (g_fSpawnTimes[i - 1] + unit) : g_fSpawnTimeMax;
			}

			case 2:  {	
				g_fSpawnTimes[0] = g_fSpawnTimeMax;
				for (int i = 1; i <= MaxClients; i++)
					g_fSpawnTimes[i] = i < g_iSILimit ? (g_fSpawnTimes[i - 1] - unit) : g_fSpawnTimeMax;
			}
		}	
	} 
}

void CvarChanged_General(ConVar convar, const char[] oldValue, const char[] newValue) {
	GetCvars_General();
}

void GetCvars_General() {
	g_bScaleWeights =	g_cScaleWeights.BoolValue;

	for (int i; i < SI_MAX_SIZE; i++)
		g_iSpawnWeights[i] = g_cSpawnWeights[i].IntValue;

	g_iBaseLimit =		g_cBaseLimit.IntValue;
	g_fExtraLimit =		g_cExtraLimit.FloatValue;
	g_iBaseSize =		g_cBaseSize.IntValue;
	g_fExtraSize =		g_cExtraSize.FloatValue;
	g_fSuicideTime =	g_cSuicideTime.FloatValue;
	g_fRushDistance =	g_cRushDistance.FloatValue;
	g_fFirstSpawnTime =	g_cFirstSpawnTime.FloatValue;
}

void CvarChanged_TankStatus(ConVar convar, const char[] oldValue, const char[] newValue) {
	int last = g_iTankStatusAction;

	GetCvars_TankStatus();
	if (last != g_iTankStatusAction)
		TankStatusActoin(FindTank(-1));
}

void GetCvars_TankStatus() {
	g_iTankStatusAction = g_cTankStatusAction.IntValue;
}

void CvarChanged_TankCustom(ConVar convar, const char[] oldValue, const char[] newValue) {
	GetCvars_TankCustom();
}

void GetCvars_TankCustom() {
	char temp[64];
	g_cTankStatusLimits.GetString(temp, sizeof temp);

	char buffers[SI_MAX_SIZE][8];
	ExplodeString(temp, ";", buffers, sizeof buffers, sizeof buffers[]);

	int i;
	int val;
	for (; i < SI_MAX_SIZE; i++) {
		if (buffers[i][0] == '\0') {
			g_iTankStatusLimits[i] = -1;
			continue;
		}

		if ((val = StringToInt(buffers[i])) < -1 || val > g_iSILimit) {
			g_iTankStatusLimits[i] = -1;
			buffers[i][0] = '\0';
			continue;
		}

		g_iTankStatusLimits[i] = val;
		buffers[i][0] = '\0';
	}

	g_cTankStatusWeights.GetString(temp, sizeof temp);
	ExplodeString(temp, ";", buffers, sizeof buffers, sizeof buffers[]);

	for (i = 0; i < SI_MAX_SIZE; i++) {
		if (buffers[i][0] == '\0' || (val = StringToInt(buffers[i])) < 0) {
			g_iTankStatusWeights[i] = -1;
			continue;
		}

		g_iTankStatusWeights[i] = val;
	}
}

public void OnClientDisconnect(int client) {
	if (!client || !IsClientInGame(client) || GetClientTeam(client) != 3 || GetEntProp(client, Prop_Send, "m_zombieClass") != 8)
		return;

	CreateTimer(0.1, tmrTankDisconnect, _, TIMER_FLAG_NO_MAPCHANGE);
}

public void OnMapEnd() {
	g_bLeftSafeArea = false;
	g_bFinaleStarted = false;

	EndSpawnTimer();
	delete g_hSuicideTimer;
	TankStatusActoin(false);

	if (g_iCurrentClass >= SI_MAX_SIZE)
		SetRandomType();
	else if (g_iCurrentClass > -1)
		SetSiType(g_iCurrentClass);
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
	OnMapEnd();
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
	EndSpawnTimer();
}

void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast) {
	if (!g_bLeftSafeArea)
		return;

	g_fActionTimes[GetClientOfUserId(event.GetInt("userid"))] = GetEngineTime();
	g_fActionTimes[GetClientOfUserId(event.GetInt("attacker"))] = GetEngineTime();
}

void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client))
		return;

	if (event.GetInt("team") == 2 || event.GetInt("oldteam") == 2) {
		delete g_hUpdateTimer;
		g_hUpdateTimer = CreateTimer(2.0, tmrUpdate);
	}
}

Action tmrUpdate(Handle timer) {
	g_hUpdateTimer = null;
	SetSpawnCount();
	return Plugin_Continue;
}

void SetSpawnCount() {
	int count;
	int limit;
	int spawnSize;
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && GetClientTeam(i) == 2)
			count++;
	}

	count -= 4;
	if (count < 1) {
		limit = g_iBaseLimit;
		spawnSize = g_iBaseSize;
	}
	else {
		limit = g_iBaseLimit + RoundToNearest(g_fExtraLimit * count);
		spawnSize = g_iBaseSize + RoundToNearest(count / g_fExtraSize);
	}

	if (limit == g_iSILimit && spawnSize == g_iSpawnSize)
		return;

	g_cSILimit.IntValue = limit;
	g_cSpawnSize.IntValue = spawnSize;
	PrintToChatAll("\x01[\x05%d特\x01/\x05次\x01] \x05%d特 \x01[\x03%.1f\x01~\x03%.1f\x01]\x04秒", spawnSize <= limit ? spawnSize : limit, limit, g_fSpawnTimeMin, g_fSpawnTimeMax);
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client) || GetClientTeam(client) != 3)
		return;

	if (GetEntProp(client, Prop_Send, "m_zombieClass") != 8)
		g_fActionTimes[client] = GetEngineTime();
	else
		CreateTimer(0.1, tmrTankSpawn, event.GetInt("userid"), TIMER_FLAG_NO_MAPCHANGE);
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client) || GetClientTeam(client) != 3)
		return;

	static int class;
	class = GetEntProp(client, Prop_Send, "m_zombieClass");
	if (class == 8 && !FindTank(client))
		TankStatusActoin(false);

	if (class != 4 && IsFakeClient(client))
		RequestFrame(NextFrame_KickBot, event.GetInt("userid"));
}

Action tmrTankSpawn(Handle timer, int client) {
	if (!(client = GetClientOfUserId(client)) || !IsClientInGame(client) || GetClientTeam(client) != 3 || !IsPlayerAlive(client) || GetEntProp(client, Prop_Send, "m_zombieClass") != 8 || FindTank(client))
		return Plugin_Stop;

	int totalLimit;
	int totalWeight;
	for (int i; i < SI_MAX_SIZE; i++) {
		totalLimit += g_iSpawnLimits[i];
		totalWeight += g_iSpawnWeights[i];
	}

	if (totalLimit && totalWeight)
		TankStatusActoin(true);

	return Plugin_Continue;
}

void SaveConfiguration() {
	for (int i; i < SI_MAX_SIZE; i++) {
		g_iSpawnLimitsCache[i] = g_iSpawnLimits[i];
		g_iSpawnWeightsCache[i] = g_iSpawnWeights[i];
	}
}

void NextFrame_KickBot(any client) {
	if ((client = GetClientOfUserId(client)) && IsClientInGame(client) && !IsClientInKickQueue(client) && IsFakeClient(client))
		KickClient(client);
}

bool FindTank(int client) {
	for (int i = 1; i <= MaxClients; i++) {
		if (i != client && IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i) && GetEntProp(i, Prop_Send, "m_zombieClass") == 8)
			return true;
	}
	return false;
}

Action tmrTankDisconnect(Handle timer) {
	if (FindTank(-1))
		return Plugin_Stop;

	TankStatusActoin(false);
	return Plugin_Continue;
}

void TankStatusActoin(bool isTankAlive) {
	static bool loaded;
	if (!isTankAlive) {
		if (loaded) {
			loaded = false;
			LoadCacheSpawnLimits();
			LoadCacheSpawnWeights();
		}
	}
	else {
		if (!loaded && g_iTankStatusAction) {
			loaded = true;
			for (int i; i < SI_MAX_SIZE; i++) {
				g_iSpawnLimitsCache[i] = g_iSpawnLimits[i];
				g_iSpawnWeightsCache[i] = g_iSpawnWeights[i];
			}
			LoadCacheTankCustom();
		}
	}
}

void LoadCacheSpawnLimits() {
	if (g_iSILimitCache != -1) {
		g_cSILimit.IntValue = g_iSILimitCache;
		g_iSILimitCache = -1;
	}

	if (g_iSpawnSizeCache != -1) {
		g_cSpawnSize.IntValue = g_iSpawnSizeCache;
		g_iSpawnSizeCache = -1;
	}

	for (int i; i < SI_MAX_SIZE; i++) {		
		if (g_iSpawnLimitsCache[i] != -1) {
			g_cSpawnLimits[i].IntValue = g_iSpawnLimitsCache[i];
			g_iSpawnLimitsCache[i] = -1;
		}
	}
}

void LoadCacheSpawnWeights() {
	for (int i; i < SI_MAX_SIZE; i++) {		
		if (g_iSpawnWeightsCache[i] != -1) {
			g_cSpawnWeights[i].IntValue = g_iSpawnWeightsCache[i];
			g_iSpawnWeightsCache[i] = -1;
		}
	}
}

void LoadCacheTankCustom() {
	for (int i; i < SI_MAX_SIZE; i++) {
		if (g_iTankStatusLimits[i] != -1)
			g_cSpawnLimits[i].IntValue = g_iTankStatusLimits[i];
			
		if (g_iTankStatusWeights[i] != -1)
			g_cSpawnWeights[i].IntValue = g_iTankStatusWeights[i];
	}
}

void ResetLimits() {
	for (int i; i < SI_MAX_SIZE; i++)
		g_cSpawnLimits[i].RestoreDefault();
}

void ResetWeights() {
	for (int i; i < SI_MAX_SIZE; i++)
		g_cSpawnWeights[i].RestoreDefault();
}

void StartCustomSpawnTimer(float time) {
	EndSpawnTimer();
	g_hSpawnTimer = CreateTimer(time, tmrSpawnSpecial);
}

void StartSpawnTimer() {
	EndSpawnTimer();
	g_hSpawnTimer = CreateTimer(g_iSpawnTimeMode > 0 ? g_fSpawnTimes[GetTotalSI()] : Math_GetRandomFloat(g_fSpawnTimeMin, g_fSpawnTimeMax), tmrSpawnSpecial);
}

void EndSpawnTimer() {
	delete g_hSpawnTimer;
	delete g_hRetryTimer;
}

Action tmrSpawnSpecial(Handle timer) { 
	g_hSpawnTimer = null;
	delete g_hRetryTimer;

	int totalSI = GetTotalSI();
	ExecuteSpawnQueue(totalSI, true);

	g_hSpawnTimer = CreateTimer(g_iSpawnTimeMode > 0 ? g_fSpawnTimes[totalSI] : Math_GetRandomFloat(g_fSpawnTimeMin, g_fSpawnTimeMax), tmrSpawnSpecial);
	return Plugin_Continue;
}

void ExecuteSpawnQueue(int totalSI, bool retry, int index = -1) {
	if (totalSI >= g_iSILimit)
		return;

	#if BENCHMARK
	g_profiler = new Profiler();
	g_profiler.Start();
	#endif

	int i;
	int spawnSize;
	ArrayList aQueue = new ArrayList();
	if (index != -1) {
		aQueue.Push(index);
		g_iSpawnCounts[index]++;
	}
	else {
		int allowedSI = g_iSILimit - totalSI;
		spawnSize = g_iSpawnSize > allowedSI ? allowedSI : g_iSpawnSize;
		GetSITypeCount();
		for (; i < spawnSize; i++) {
			index = GenerateIndex();
			if (index == -1)
				break;

			aQueue.Push(index);
			g_iSpawnCounts[index]++;
		}
	}

	spawnSize = aQueue.Length;
	if (!spawnSize) {
		delete aQueue;
		return;
	}

	float flow;
	ArrayList aList = new ArrayList(2);
	for (i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && !GetEntProp(i, Prop_Send, "m_isIncapacitated")) {
			flow = L4D2Direct_GetFlowDistance(i);
			if (flow && flow != -9999.0)
				aList.Set(aList.Push(flow), i, 1);
		}
	}

	int count = aList.Length;
	if (!count) {
		delete aList;
		delete aQueue;
		return;
	}

	aList.Sort(Sort_Descending, Sort_Float);

	bool find;
	int client = aList.Get(0, 1);
	flow = aList.Get(0, 0);
	float lastFlow = aList.Get(count - 1, 0);
	if (count == 1 || flow - lastFlow > g_fRushDistance) {
		#if DEBUG
		PrintToServer("[SS] Rusher -> %N", client);
		#endif

		find = true;
	}

	delete aList;
	g_bInSpawnTime = true;
	//g_cSpawnRange.IntValue = retry ? 1000 : 1500;
	g_iDirection = g_bFinaleStarted ? SPAWN_NEAR_IT_VICTIM : (!retry ? SPAWN_NO_PREFERENCE : (!find ? SPAWN_LARGE_VOLUME/*SPAWN_SPECIALS_ANYWHERE*/ : SPAWN_IN_FRONT_OF_SURVIVORS));

	count = 0;
	find = false;
	int zombie;
	float vPos[3];
	for (i = 0; i < spawnSize; i++) {
		index = aQueue.Get(i) + 1;
		if (L4D_GetRandomPZSpawnPosition(client, index, 10, vPos))
			find = true;

		vPos[2] += 5.0;
		if (find && (zombie = L4D2_SpawnSpecial(index, vPos, NULL_VECTOR)) > 0) {
			SetEntProp(zombie, Prop_Send, "m_bDucked", 1);
			SetEntityFlags(zombie, GetEntityFlags(client)|FL_DUCKING);
			count++;
		}

		vPos[2] -= 5.0;
	}

	g_bInSpawnTime = false;

	#if BENCHMARK
	g_profiler.Stop();
	PrintToServer("[SS] ProfilerTime: %f", g_profiler.Time);
	#endif

	if (retry) {
		if (!count) {
			#if DEBUG
			PrintToServer("[SS] Retry spawn SI! spawned:%d failed:%d", count, aQueue.Length - count);
			#endif
			g_hRetryTimer = CreateTimer(1.0, tmrRetrySpawn, false);
		}
	}
	#if DEBUG
	else {
		if (!count)
			PrintToServer("[SS] Spawn SI failed! spawned:%d failed:%d", count, aQueue.Length - count);
	}
	#endif

	delete aQueue;
}

Action tmrRetrySpawn(Handle timer, bool retry) {
	g_hRetryTimer = null;
	ExecuteSpawnQueue(GetTotalSI(), retry);
	return Plugin_Continue;
}

int GetTotalSI() {
	int count;
	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || IsClientInKickQueue(i) || GetClientTeam(i) != 3)
			continue;
	
		if (IsPlayerAlive(i)) {
			if (1 <= GetEntProp(i, Prop_Send, "m_zombieClass") <= 6)
				count++;
		}
		else if (IsFakeClient(i) && GetEntProp(i, Prop_Send, "m_zombieClass") != 4)
			KickClient(i);
	}
	return count;
}

void GetSITypeCount() {
	int i;
	for (; i < SI_MAX_SIZE; i++)
		g_iSpawnCounts[i] = 0;

	for (i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || IsClientInKickQueue(i)|| GetClientTeam(i) != 3 || !IsPlayerAlive(i))
			continue;

		switch (GetEntProp(i, Prop_Send, "m_zombieClass")) {
			case 1:
				g_iSpawnCounts[SI_SMOKER]++;

			case 2:
				g_iSpawnCounts[SI_BOOMER]++;

			case 3:
				g_iSpawnCounts[SI_HUNTER]++;

			case 4:
				g_iSpawnCounts[SI_SPITTER]++;

			case 5:
				g_iSpawnCounts[SI_JOCKEY]++;
		
			case 6:
				g_iSpawnCounts[SI_CHARGER]++;
		}
	}
}

int GenerateIndex() {	
	static int i;
	static int totalWeight;
	static int standardizedWeight;
	static int tempWeights[SI_MAX_SIZE];
	static float unit;
	static float random;
	static float intervalEnds[SI_MAX_SIZE];

	totalWeight = 0;
	standardizedWeight = 0;

	for (i = 0; i < SI_MAX_SIZE; i++) {
		tempWeights[i] = g_iSpawnCounts[i] < g_iSpawnLimits[i] ? (g_bScaleWeights ? ((g_iSpawnLimits[i] - g_iSpawnCounts[i]) * g_iSpawnWeights[i]) : g_iSpawnWeights[i]) : 0;
		totalWeight += tempWeights[i];
	}

	unit = 1.0 / totalWeight;
	for (i = 0; i < SI_MAX_SIZE; i++) {
		if (tempWeights[i] >= 0) {
			standardizedWeight += tempWeights[i];
			intervalEnds[i] = standardizedWeight * unit;
		}
	}

	random = Math_GetRandomFloat(0.0, 1.0);
	for (i = 0; i < SI_MAX_SIZE; i++) {
		if (tempWeights[i] > 0 && intervalEnds[i] >= random)
			return i;
	}

	return -1;
}

// https://github.com/bcserv/smlib/blob/transitional_syntax/scripting/include/smlib/math.inc
float Math_GetRandomFloat(float min, float max) {
	return (GetURandomFloat() * (max  - min)) + min;
}
