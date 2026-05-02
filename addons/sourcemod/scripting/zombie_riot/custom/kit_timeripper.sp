#pragma semicolon 1
#pragma newdecls required

static Handle   h_TR_Timer[MAXPLAYERS]       = {null, ...};
static float    f_TR_HUDDelay[MAXPLAYERS];
static int      i_TR_WeaponLevel[MAXPLAYERS];
static int      ref_TR_MeleeWeapon[MAXPLAYERS];
static float    f_TR_StolenTime[MAXPLAYERS];
static float    f_TR_DecayDelay[MAXPLAYERS];
static float    f_TR_DespairEnd[MAXPLAYERS];

#define TR_DECAY_RATE           0.0007
#define TR_HIGH_THRESHOLD       0.60
#define TR_LOW_THRESHOLD        0.20
#define TR_RAZOR_RANGE          275.0
#define TR_EXTRACTION_RANGE     350.0
#define TR_PUNISHMENT_RADIUS    280.0

#define TR_SOUND_RAZOR_SWING    "weapons/sword_swing1.wav"
#define TR_SOUND_RAZOR_HIT      "ambient/materials/cartrap_explode_impact1.wav"
#define TR_SOUND_EXTRACTION     "weapons/grappling_hook_shoot.wav"
#define TR_SOUND_EXTRACTION_HIT "player/souls_receive1.wav"
#define TR_SOUND_PUNISHMENT     "misc/halloween/spell_lightning_ball_cast.wav"
#define TR_SOUND_LOW_TIME       "ui/scored.wav"
#define TR_SOUND_TIME_GAIN      "player/taunt_luxury_lounge_chair_creak.wav"
#define TR_BEAM_MATERIAL        "materials/sprites/laserbeam.vmt"

public void TimeRipper_OnMapStart()
{
	PrecacheSound(TR_SOUND_RAZOR_SWING);
	PrecacheSound(TR_SOUND_RAZOR_HIT);
	PrecacheSound(TR_SOUND_EXTRACTION);
	PrecacheSound(TR_SOUND_EXTRACTION_HIT);
	PrecacheSound(TR_SOUND_PUNISHMENT);
	PrecacheSound(TR_SOUND_LOW_TIME);
	PrecacheSound(TR_SOUND_TIME_GAIN);
	PrecacheModel(TR_BEAM_MATERIAL);

	Zero(f_TR_HUDDelay);
	Zero(f_TR_StolenTime);
	Zero(f_TR_DecayDelay);
	Zero(f_TR_DespairEnd);
}

public void Enable_TimeRipper(int client, int weapon)
{
	if (h_TR_Timer[client] != null)
	{
		if (IsValidHandle(h_TR_Timer[client]))
			delete h_TR_Timer[client];
		h_TR_Timer[client] = null;
	}

	i_TR_WeaponLevel[client]    = RoundFloat(Attributes_Get(weapon, 868, 0.0));
	ref_TR_MeleeWeapon[client]  = EntIndexToEntRef(weapon);
	f_TR_StolenTime[client]     = 0.0;

	DataPack pack = new DataPack();
	h_TR_Timer[client] = CreateDataTimer(0.1, Timer_TimeRipper, pack, TIMER_REPEAT);
	pack.WriteCell(client);
	pack.WriteCell(EntIndexToEntRef(weapon));
	pack.WriteCell(EntIndexToEntRef(client));
}

static Action Timer_TimeRipper(Handle timer, DataPack pack)
{
	pack.Reset();
	int clientindx = pack.ReadCell();
	int weapon     = EntRefToEntIndex(pack.ReadCell());
	int client     = EntRefToEntIndex(pack.ReadCell());

	if (!IsValidClient(client) || !IsClientInGame(client) || !IsPlayerAlive(client) || !IsValidEntity(weapon))
	{
		h_TR_Timer[clientindx] = null;
		return Plugin_Stop;
	}

	b_IsCannibal[client] = true;

	if (!Waves_InSetup() && f_TR_DecayDelay[client] < GetGameTime())
	{
		f_TR_StolenTime[client] -= TR_DECAY_RATE;
		if (f_TR_StolenTime[client] < 0.0)
			f_TR_StolenTime[client] = 0.0;
	}

	TR_ApplyPassiveBonuses(client, weapon);
	TR_ShowHUD(client);

	return Plugin_Continue;
}

static void TR_ApplyPassiveBonuses(int client, int weapon)
{
	float st = f_TR_StolenTime[client];
	int level = i_TR_WeaponLevel[client];

	if (st >= TR_HIGH_THRESHOLD)
	{
		ApplyStatusEffect(client, client, "TR High Time", 0.25);
	}
	else if (st <= TR_LOW_THRESHOLD)
	{
		if (level >= 6)
		{
			ApplyStatusEffect(client, client, "TR Desperate", 0.25);
		}
	}
}

static void TR_ShowHUD(int client)
{
	if (f_TR_HUDDelay[client] >= GetGameTime())
		return;

	f_TR_HUDDelay[client] = GetGameTime() + 0.5;

	int displayVal  = RoundToFloor(f_TR_StolenTime[client] * 1000.0);
	int displayMax  = 1000;
	float st        = f_TR_StolenTime[client];
	int level       = i_TR_WeaponLevel[client];

	char timeBar[32];
	int barFill = RoundToFloor(st * 10.0);
	for (int i = 0; i < 10; i++)
		Format(timeBar, sizeof(timeBar), "%s%s", timeBar, (i < barFill) ? "■" : "□");

	if (level >= 5)
	{
		if (st >= TR_HIGH_THRESHOLD)
			PrintHintText(client, "Stolen Time [%i/%i]\n%s  ▲ Time Empowered", displayVal, displayMax, timeBar);
		else if (st <= TR_LOW_THRESHOLD && level >= 6)
			PrintHintText(client, "Stolen Time [%i/%i]\n%s  ▼ Running Out of Time", displayVal, displayMax, timeBar);
		else
			PrintHintText(client, "Stolen Time [%i/%i]\n%s", displayVal, displayMax, timeBar);
	}
}

public void TimeRipper_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage,
	int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int zr_custom_damage)
{
	if (CheckInHud())
		return;

	if (zr_custom_damage & ZR_DAMAGE_DO_NOT_APPLY_BURN_OR_BLEED)
		return;

	TR_GainStolenTime(attacker, damage);

	float st    = f_TR_StolenTime[attacker];
	int   level = i_TR_WeaponLevel[attacker];

	if (st >= TR_HIGH_THRESHOLD)
	{
		float bonus = (st - TR_HIGH_THRESHOLD) / (1.0 - TR_HIGH_THRESHOLD);
		damage *= (1.0 + bonus * 0.35);
	}
	else if (st <= TR_LOW_THRESHOLD && level < 6)
	{
		float penalty = 1.0 - st / TR_LOW_THRESHOLD;
		damage *= (1.0 - penalty * 0.25);
	}
	else if (st <= TR_LOW_THRESHOLD && level >= 6)
	{
		float penalty = 1.0 - st / TR_LOW_THRESHOLD;
		damage *= (1.0 + penalty * 0.20);
	}

	ApplyStatusEffect(attacker, victim, "Sinking", 8.0);
	StatusEffects_SinkingDebuffAdd(victim, 1);

	if (HasSpecificBuff(weapon, "TR Timekill"))
	{
		if (!StatusEffects_SinkingDebuffMaxStacks(victim))
		{
			Ability_Apply_Cooldown(attacker, 2, Ability_Check_Cooldown(attacker, 2, weapon) - 5.0, weapon, true);
		}
		EmitSoundToAll(TR_SOUND_RAZOR_HIT, attacker, _, 70, _, 1.0, 100);
		SensalCauseKnockback(attacker, victim, 0.4, false);
		RemoveSpecificBuff(weapon, "TR Timekill");
	}

	if (HasSpecificBuff(weapon, "TR Extraction"))
	{
		TR_ExtractionProc(attacker, victim, damage);
		RemoveSpecificBuff(weapon, "TR Extraction");
	}
}

public void TimeRipper_OnTakeDamage_Take(int victim, int &attacker, int &inflictor, float &damage,
	int &damagetype, int &weapon, int equipped_weapon, float damagePosition[3], int zr_custom_damage)
{
	if (CheckInHud())
		return;
	if (zr_custom_damage & ZR_DAMAGE_DO_NOT_APPLY_BURN_OR_BLEED)
		return;

	float st    = f_TR_StolenTime[victim];
	int   level = i_TR_WeaponLevel[victim];

	if (st >= TR_HIGH_THRESHOLD && level >= 2)
	{
		float reduction = (st - TR_HIGH_THRESHOLD) / (1.0 - TR_HIGH_THRESHOLD);
		damage *= (1.0 - reduction * 0.20);
	}

	if (st <= TR_LOW_THRESHOLD && level < 6)
	{
		float penalty = 1.0 - st / TR_LOW_THRESHOLD;
		damage *= (1.0 + penalty * 0.15);
	}
}

public void TimeRipper_TimeRazor(int client, int weapon, bool crit, int slot)
{
	if (Ability_Check_Cooldown(client, slot) > 0.0)
	{
		float cd = Ability_Check_Cooldown(client, slot);
		if (cd < 0.0) cd = 0.0;
		ClientCommand(client, "playgamesound items/medshotno1.wav");
		SetDefaultHudPosition(client);
		SetGlobalTransTarget(client);
		ShowSyncHudText(client, SyncHud_Notifaction, "%t", "Ability has cooldown", cd);
		return;
	}

	Handle swingTrace;
	b_LagCompNPC_No_Layers = true;
	float vecSwingForward[3];
	StartLagCompensation_Base_Boss(client);
	DoSwingTrace_Custom(swingTrace, client, vecSwingForward, TR_RAZOR_RANGE, false, 35.0, true);
	FinishLagCompensation_Base_boss();

	int target = TR_GetEntityIndex(swingTrace);
	delete swingTrace;

	if (!IsValidEnemy(client, target, true))
	{
		ClientCommand(client, "playgamesound items/medshotno1.wav");
		return;
	}

	ApplyStatusEffect(weapon, weapon, "TR Timekill", 1.5);
	Rogue_OnAbilityUse(client, weapon);

	int level = i_TR_WeaponLevel[client];
	float cd  = 14.0 - (float(level) * 0.8);
	if (cd < 7.0) cd = 7.0;
	Ability_Apply_Cooldown(client, slot, cd);

	EmitSoundToAll(TR_SOUND_RAZOR_SWING, client, _, 70, _, 1.0, 85);
	EmitSoundToAll(TR_SOUND_RAZOR_SWING, client, _, 70, _, 1.0, 85);

	TF2_AddCondition(client, TFCond_LostFooting, 0.3);
	TF2_AddCondition(client, TFCond_AirCurrent, 0.3);

	int trail = Trail_Attach(client, ARROW_TRAIL_RED, 255, 0.40, 60.0, 3.0, 5);
	SetEntityRenderColor(trail, 0, 200, 255, 255);
	SDKCall_SetLocalOrigin(trail, {0.0, 0.0, 50.0});
	CreateTimer(0.40, Timer_RemoveEntityParent, EntIndexToEntRef(trail), TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(1.0,  Timer_RemoveEntity,       EntIndexToEntRef(trail), TIMER_FLAG_NO_MAPCHANGE);

	float mePos[3];    WorldSpaceCenter(client, mePos);
	float targPos[3];  WorldSpaceCenter(target, targPos);
	float dir[3];
	MakeVectorFromPoints(mePos, targPos, dir);
	GetVectorAngles(dir, dir);

	float velocity[3];
	GetAngleVectors(dir, velocity, NULL_VECTOR, NULL_VECTOR);
	float dashSpeed = 850.0 + (float(level) * 30.0);
	ScaleVector(velocity, dashSpeed);
	velocity[2] += 120.0;
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, velocity);

	f_TR_StolenTime[client] += 0.04;
	if (f_TR_StolenTime[client] > 1.0) f_TR_StolenTime[client] = 1.0;
}

public void TimeRipper_Extraction(int client, int weapon, bool crit, int slot)
{
	if (Ability_Check_Cooldown(client, slot) > 0.0)
	{
		float cd = Ability_Check_Cooldown(client, slot);
		if (cd < 0.0) cd = 0.0;
		ClientCommand(client, "playgamesound items/medshotno1.wav");
		SetDefaultHudPosition(client);
		SetGlobalTransTarget(client);
		ShowSyncHudText(client, SyncHud_Notifaction, "%t", "Ability has cooldown", cd);
		return;
	}

	int MeleeWeapon = EntRefToEntIndex(ref_TR_MeleeWeapon[client]);
	if (!IsValidEntity(MeleeWeapon))
		return;

	Handle swingTrace;
	b_LagCompNPC_No_Layers = true;
	float vecSwingForward[3];
	StartLagCompensation_Base_Boss(client);
	DoSwingTrace_Custom(swingTrace, client, vecSwingForward, TR_EXTRACTION_RANGE, false, 40.0, true);
	FinishLagCompensation_Base_boss();

	int target = TR_GetEntityIndex(swingTrace);
	delete swingTrace;

	if (!IsValidEnemy(client, target, true))
	{
		ClientCommand(client, "playgamesound items/medshotno1.wav");
		return;
	}

	ApplyStatusEffect(weapon, weapon, "TR Extraction", 1.5);
	Rogue_OnAbilityUse(client, MeleeWeapon);

	int level = i_TR_WeaponLevel[client];
	float cd  = 22.0 - (float(level) * 0.5);
	if (cd < 14.0) cd = 14.0;
	Ability_Apply_Cooldown(client, slot, cd, weapon);

	EmitSoundToAll(TR_SOUND_EXTRACTION, client, _, 70, _, 0.9, 90);

	FreezeNpcInTime(target, 2.5, true);

	float targPos[3]; WorldSpaceCenter(target, targPos);
	float mePos[3];   WorldSpaceCenter(client, mePos);

	int SPRITE = PrecacheModel(TR_BEAM_MATERIAL, false);
	TE_SetupBeamPoints(mePos, targPos, SPRITE, 0, 0, 0, 0.6, 6.0, 6.0, 1, 0.0, {0, 200, 255, 220}, 0);
	TE_SendToAll();

	TE_Particle("halloween_boss_death_cloud", targPos, NULL_VECTOR, NULL_VECTOR, target, _, _, _, _, _, _, _, _, _, 0.0);

	f_TR_StolenTime[client] += 0.18;
	if (f_TR_StolenTime[client] > 1.0) f_TR_StolenTime[client] = 1.0;
}

public void TimeRipper_Punishment(int client, int weapon, bool crit, int slot)
{
	if (Ability_Check_Cooldown(client, slot) > 0.0)
	{
		float cd = Ability_Check_Cooldown(client, slot);
		if (cd < 0.0) cd = 0.0;
		ClientCommand(client, "playgamesound items/medshotno1.wav");
		SetDefaultHudPosition(client);
		SetGlobalTransTarget(client);
		ShowSyncHudText(client, SyncHud_Notifaction, "%t", "Ability has cooldown", cd);
		return;
	}

	int MeleeWeapon = EntRefToEntIndex(ref_TR_MeleeWeapon[client]);
	if (!IsValidEntity(MeleeWeapon))
		return;

	Rogue_OnAbilityUse(client, MeleeWeapon);

	int level = i_TR_WeaponLevel[client];
	float cd  = 28.0 - (float(level) * 0.5);
	if (cd < 20.0) cd = 20.0;
	Ability_Apply_Cooldown(client, slot, cd, weapon);

	EmitSoundToAll(TR_SOUND_PUNISHMENT, client, _, 75, _, 1.0, 95);
	EmitSoundToAll(TR_SOUND_PUNISHMENT, client, _, 75, _, 1.0, 95);

	float spawnLoc[3];
	WorldSpaceCenter(client, spawnLoc);

	spawnRing_Vectors(spawnLoc, TR_PUNISHMENT_RADIUS * 2.0, 0.0, 0.0, 0.0,
		TR_BEAM_MATERIAL, 0, 200, 255, 200, 1, 0.5, 4.0, 0.3, 1, 1.0);

	float spawnHigh[3];
	spawnHigh = spawnLoc;
	spawnHigh[2] += 80.0;
	spawnRing_Vectors(spawnHigh, TR_PUNISHMENT_RADIUS * 1.4, 0.0, 0.0, 0.0,
		TR_BEAM_MATERIAL, 0, 200, 255, 150, 1, 0.5, 4.0, 0.3, 1, 1.0);

	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(client));
	pack.WriteCell(EntIndexToEntRef(MeleeWeapon));
	pack.WriteFloat(spawnLoc[0]);
	pack.WriteFloat(spawnLoc[1]);
	pack.WriteFloat(spawnLoc[2]);
	CreateDataTimer(0.15, TimeRipper_Punishment_Delayed, pack, TIMER_FLAG_NO_MAPCHANGE);

	f_TR_StolenTime[client] += 0.06;
	if (f_TR_StolenTime[client] > 1.0) f_TR_StolenTime[client] = 1.0;
}

public Action TimeRipper_Punishment_Delayed(Handle timer, DataPack pack)
{
	pack.Reset();
	int client = GetClientOfUserId(pack.ReadCell());
	int weapon = EntRefToEntIndex(pack.ReadCell());
	float loc[3];
	loc[0] = pack.ReadFloat();
	loc[1] = pack.ReadFloat();
	loc[2] = pack.ReadFloat();

	if (!IsValidClient(client) || !IsValidEntity(weapon))
		return Plugin_Stop;

	float damage = 80.0;
	damage *= WeaponDamageAttributeMultipliers(weapon, _, client);

	Explode_Logic_Custom(damage, client, client, weapon, loc, TR_PUNISHMENT_RADIUS, _, _, false, 12);

	int MaxEnemies = 16;
	int enemies[16];
	int found = GetEnemiesInRange(client, loc, TR_PUNISHMENT_RADIUS, enemies, MaxEnemies);
	for (int i = 0; i < found; i++)
	{
		if (!IsValidEnemy(client, enemies[i], true))
			continue;
		FreezeNpcInTime(enemies[i], 1.5, false);
		ApplyStatusEffect(client, enemies[i], "Sinking", 10.0);
		StatusEffects_SinkingDebuffAdd(enemies[i], 2);
	}

	return Plugin_Stop;
}

stock void TR_GainStolenTime(int client, float damage)
{
	int scale = CurrentCash;
	if (scale < 1000)  scale = 1000;
	if (scale > 200000) scale = 200000;

	float damageForFull = Pow(2.0 * float(scale), 1.1) + float(scale) * 2.5;

	f_TR_StolenTime[client] += damage / damageForFull;
	if (f_TR_StolenTime[client] > 1.0)
		f_TR_StolenTime[client] = 1.0;
}

static void TR_ExtractionProc(int attacker, int victim, float damage)
{
	float extraDmg = damage * 0.6;
	if (extraDmg > 0.0)
	{
		float pos[3]; WorldSpaceCenter(victim, pos);
		float force[3] = {0.0, 0.0, 0.1};
		int MeleeWeapon = EntRefToEntIndex(ref_TR_MeleeWeapon[attacker]);
		if (IsValidEntity(MeleeWeapon))
			SDKHooks_TakeDamage(victim, MeleeWeapon, attacker, extraDmg, DMG_CLUB, -1, force, pos);
	}

	float targPos[3]; WorldSpaceCenter(victim, targPos);
	TE_Particle("halloween_boss_death_cloud", targPos, NULL_VECTOR, NULL_VECTOR, victim, _, _, _, _, _, _, _, _, _, 0.0);
	EmitSoundToAll(TR_SOUND_EXTRACTION_HIT, victim, SNDCHAN_AUTO, 80, _, 0.85, 90);
}

static int GetEnemiesInRange(int client, float origin[3], float radius, int[] out, int maxOut)
{
	int count = 0;
	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "base_boss")) != -1 && count < maxOut)
	{
		if (!IsValidEnemy(client, entity, true)) continue;
		float pos[3]; WorldSpaceCenter(entity, pos);
		if (GetVectorDistance(origin, pos) <= radius)
			out[count++] = entity;
	}
	entity = -1;
	while ((entity = FindEntityByClassname(entity, "obj_*")) != -1 && count < maxOut)
	{
		if (!IsValidEnemy(client, entity, true)) continue;
		float pos[3]; WorldSpaceCenter(entity, pos);
		if (GetVectorDistance(origin, pos) <= radius)
			out[count++] = entity;
	}
	return count;
}
