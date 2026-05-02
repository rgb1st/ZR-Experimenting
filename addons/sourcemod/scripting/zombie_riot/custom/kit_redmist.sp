#pragma semicolon 1
#pragma newdecls required

static Handle h_RM_Timer[MAXPLAYERS]        = {null, ...};
static float  f_RM_HUDDelay[MAXPLAYERS];
static int    i_RM_WeaponLevel[MAXPLAYERS];
static int    ref_RM_Weapon[MAXPLAYERS];

static int    i_RM_KillStacks[MAXPLAYERS];
static bool   b_RM_EGOActive[MAXPLAYERS];
static float  f_RM_EGOEnd[MAXPLAYERS];
static float  f_RM_EGOCooldown[MAXPLAYERS];
static float  f_RM_LastDamageTime[MAXPLAYERS];
static float  f_RM_TotalDmgInWindow[MAXPLAYERS];
static bool   b_RM_RetaliateReady[MAXPLAYERS];
static float  f_RM_RetaliateWindow[MAXPLAYERS];
static int    i_RM_OnrushChains[MAXPLAYERS];

#define RM_MAX_STACKS           5
#define RM_EGO_DURATION         30.0
#define RM_EGO_COOLDOWN         45.0
#define RM_EGO_KILL_THRESHOLD   3
#define RM_PRESSURE_WINDOW      5.0
#define RM_PRESSURE_THRESHOLD   40.0
#define RM_PRESSURE_SELF_DMG    25.0
#define RM_RETALIATE_WINDOW     2.5
#define RM_ONRUSH_RANGE         320.0
#define RM_SPLIT_V_RANGE        260.0
#define RM_SPLIT_H_RADIUS       300.0

#define RM_SOUND_SWING_1        "weapons/sword_swing1.wav"
#define RM_SOUND_SWING_2        "weapons/sword_swing2.wav"
#define RM_SOUND_HIT            "weapons/bullet_impact_metal1.wav"
#define RM_SOUND_ONRUSH         "player/taunt_luxury_lounge_chair_creak.wav"
#define RM_SOUND_ONRUSH_HIT     "ambient/materials/cartrap_explode_impact1.wav"
#define RM_SOUND_RETALIATE      "ui/scored.wav"
#define RM_SOUND_EGO_START      "misc/halloween/spell_lightning_ball_cast.wav"
#define RM_SOUND_EGO_PULSE      "ambient/levels/citadel/weapon_disintegrate3.wav"
#define RM_SOUND_PRESSURE_FAIL  "items/medshotno1.wav"
#define RM_SOUND_SPLIT_H        "weapons/grappling_hook_shoot.wav"
#define RM_SOUND_KILL_STACK     "player/taunt_laugh_sniper.wav"
#define RM_BEAM_MATERIAL        "materials/sprites/laserbeam.vmt"

public void RedMist_OnMapStart()
{
	PrecacheSound(RM_SOUND_SWING_1);
	PrecacheSound(RM_SOUND_SWING_2);
	PrecacheSound(RM_SOUND_HIT);
	PrecacheSound(RM_SOUND_ONRUSH);
	PrecacheSound(RM_SOUND_ONRUSH_HIT);
	PrecacheSound(RM_SOUND_RETALIATE);
	PrecacheSound(RM_SOUND_EGO_START);
	PrecacheSound(RM_SOUND_EGO_PULSE);
	PrecacheSound(RM_SOUND_PRESSURE_FAIL);
	PrecacheSound(RM_SOUND_SPLIT_H);
	PrecacheSound(RM_SOUND_KILL_STACK);
	PrecacheModel(RM_BEAM_MATERIAL);

	Zero(f_RM_HUDDelay);
	Zero(i_RM_KillStacks);
	Zero(b_RM_EGOActive);
	Zero(f_RM_EGOEnd);
	Zero(f_RM_EGOCooldown);
	Zero(f_RM_LastDamageTime);
	Zero(f_RM_TotalDmgInWindow);
	Zero(b_RM_RetaliateReady);
	Zero(f_RM_RetaliateWindow);
	Zero(i_RM_OnrushChains);
}

public void Enable_RedMist(int client, int weapon)
{
	if (h_RM_Timer[client] != null)
	{
		if (IsValidHandle(h_RM_Timer[client]))
			delete h_RM_Timer[client];
		h_RM_Timer[client] = null;
	}

	i_RM_WeaponLevel[client]   = RoundFloat(Attributes_Get(weapon, 868, 0.0));
	ref_RM_Weapon[client]      = EntIndexToEntRef(weapon);
	i_RM_KillStacks[client]    = 0;
	b_RM_EGOActive[client]     = false;
	f_RM_EGOCooldown[client]   = 0.0;
	b_RM_RetaliateReady[client] = false;
	f_RM_LastDamageTime[client] = GetGameTime();
	f_RM_TotalDmgInWindow[client] = 0.0;

	DataPack pack = new DataPack();
	h_RM_Timer[client] = CreateDataTimer(0.1, Timer_RedMist, pack, TIMER_REPEAT);
	pack.WriteCell(client);
	pack.WriteCell(EntIndexToEntRef(weapon));
	pack.WriteCell(EntIndexToEntRef(client));
}

static Action Timer_RedMist(Handle timer, DataPack pack)
{
	pack.Reset();
	int clientindx = pack.ReadCell();
	int weapon     = EntRefToEntIndex(pack.ReadCell());
	int client     = EntRefToEntIndex(pack.ReadCell());

	if (!IsValidClient(client) || !IsClientInGame(client) || !IsPlayerAlive(client) || !IsValidEntity(weapon))
	{
		h_RM_Timer[clientindx] = null;
		return Plugin_Stop;
	}

	b_IsCannibal[client] = true;

	float now = GetGameTime();

	if (i_RM_KillStacks[client] > 0)
	{
		float speedDuration = 0.3;
		TF2_AddCondition(client, TFCond_SpeedBuffAlly, speedDuration);
		if (i_RM_KillStacks[client] >= 4)
			TF2_AddCondition(client, TFCond_RuneHaste, speedDuration);
	}

	if (b_RM_EGOActive[client] && now >= f_RM_EGOEnd[client])
	{
		RM_DeactivateEGO(client);
	}

	if (b_RM_EGOActive[client] && i_RM_WeaponLevel[client] >= 5)
	{
		if (now - f_RM_LastDamageTime[client] >= RM_PRESSURE_WINDOW)
		{
			if (f_RM_TotalDmgInWindow[client] < RM_PRESSURE_THRESHOLD)
			{
				float selfDmg = RM_PRESSURE_SELF_DMG * (1.0 + float(i_RM_KillStacks[client]) * 0.1);
				float pos[3]; WorldSpaceCenter(client, pos);
				float force[3] = {0.0, 0.0, 0.1};
				SDKHooks_TakeDamage(client, client, client, selfDmg, DMG_GENERIC, -1, force, pos);
				EmitSoundToClient(client, RM_SOUND_PRESSURE_FAIL, _, _, 80, _, 1.0, 100);
				PrintHintText(client, "Mimicry hungers — deal damage!\nDamage dealt: %.0f / %.0f", f_RM_TotalDmgInWindow[client], RM_PRESSURE_THRESHOLD);
			}
			f_RM_LastDamageTime[client] = now;
			f_RM_TotalDmgInWindow[client] = 0.0;
		}
	}

	if (b_RM_EGOActive[client])
	{
		static int pulseCount[MAXPLAYERS];
		pulseCount[client]++;
		if (pulseCount[client] >= 20)
		{
			pulseCount[client] = 0;
			float pos[3]; WorldSpaceCenter(client, pos);
			TE_Particle("unusual_hot_sparks", pos, NULL_VECTOR, NULL_VECTOR, client, _, _, _, _, _, _, _, _, _, 0.0);
			EmitSoundToAll(RM_SOUND_EGO_PULSE, client, _, 50, _, 0.5, 90);
		}
	}

	if (b_RM_RetaliateReady[client] && now >= f_RM_RetaliateWindow[client])
	{
		b_RM_RetaliateReady[client] = false;
	}

	RM_ShowHUD(client);

	return Plugin_Continue;
}

static void RM_ShowHUD(int client)
{
	if (f_RM_HUDDelay[client] >= GetGameTime())
		return;
	f_RM_HUDDelay[client] = GetGameTime() + 0.5;

	int level    = i_RM_WeaponLevel[client];
	int stacks   = i_RM_KillStacks[client];
	bool ego     = b_RM_EGOActive[client];
	bool counter = b_RM_RetaliateReady[client];

	char stackBar[12];
	for (int i = 0; i < RM_MAX_STACKS; i++)
		Format(stackBar, sizeof(stackBar), "%s%s", stackBar, (i < stacks) ? "▪" : "▫");

	if (level < 2)
		return;

	if (ego)
	{
		float remaining = f_RM_EGOEnd[client] - GetGameTime();
		if (remaining < 0.0) remaining = 0.0;

		if (level >= 5)
		{
			float pressure = f_RM_TotalDmgInWindow[client];
			float window   = RM_PRESSURE_WINDOW - (GetGameTime() - f_RM_LastDamageTime[client]);
			if (window < 0.0) window = 0.0;
			ShowSyncHudText(client, SyncHud_Notifaction, "【E.G.O MANIFESTED】 %.0fs\nRed Mist: %s  [+%i Power]\nDamage: %.0f / %.0f  (%.0fs)", remaining, stackBar, stacks, pressure, RM_PRESSURE_THRESHOLD, window);
		}
		else
		{
			ShowSyncHudText(client, SyncHud_Notifaction, "【E.G.O MANIFESTED】 %.0fs\nRed Mist: %s  [+%i Power]", remaining, stackBar, stacks);
		}
	}
	else
	{
		char egoStr[32];
		if (f_RM_EGOCooldown[client] > GetGameTime())
			Format(egoStr, sizeof(egoStr), "  (EGO: %.0fs)", f_RM_EGOCooldown[client] - GetGameTime());
		else if (stacks >= RM_EGO_KILL_THRESHOLD)
			Format(egoStr, sizeof(egoStr), "  (EGO: READY)");

		if (counter)
			ShowSyncHudText(client, SyncHud_Notifaction, "Red Mist: %s  [+%i Power]%s\n【RETALIATE PRIMED】", stackBar, stacks, egoStr);
		else
			ShowSyncHudText(client, SyncHud_Notifaction, "Red Mist: %s  [+%i Power]%s", stackBar, stacks, egoStr);
	}
}

public void RedMist_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage,
	int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int zr_custom_damage)
{
	if (CheckInHud())
		return;
	if (zr_custom_damage & ZR_DAMAGE_DO_NOT_APPLY_BURN_OR_BLEED)
		return;
	if (victim == attacker)
		return;

	int level  = i_RM_WeaponLevel[attacker];
	int stacks = i_RM_KillStacks[attacker];
	bool ego   = b_RM_EGOActive[attacker];

	if (stacks > 0)
		damage *= (1.0 + float(stacks) * 0.08);

	if (ego)
		damage *= 1.30;

	ApplyStatusEffect(attacker, victim, "Sinking", 8.0);
	StatusEffects_SinkingDebuffAdd(victim, (ego ? 3 : 1));

	if (ego && level >= 5)
		f_RM_TotalDmgInWindow[attacker] += damage;

	if (b_RM_RetaliateReady[attacker])
	{
		b_RM_RetaliateReady[attacker] = false;
		StatusEffects_SinkingDebuffAdd(victim, 4);
		damage *= 1.20;
		EmitSoundToAll(RM_SOUND_RETALIATE, attacker, _, 70, _, 1.0, 95);
	}

	if (HasSpecificBuff(weapon, "RM Onrush Chain"))
	{
		damage *= 1.15;
		EmitSoundToAll(RM_SOUND_ONRUSH_HIT, victim, _, 70, _, 1.0, 90);
	}
}

public void RedMist_OnTakeDamage_Take(int victim, int &attacker, int &inflictor, float &damage,
	int &damagetype, int &weapon, int equipped_weapon, float damagePosition[3], int zr_custom_damage)
{
	if (CheckInHud())
		return;
	if (zr_custom_damage & ZR_DAMAGE_DO_NOT_APPLY_BURN_OR_BLEED)
		return;
	if (attacker == victim)
		return;

	int level = i_RM_WeaponLevel[victim];
	if (level < 3)
		return;

	if (!b_RM_RetaliateReady[victim])
	{
		b_RM_RetaliateReady[victim]  = true;
		f_RM_RetaliateWindow[victim] = GetGameTime() + RM_RETALIATE_WINDOW;
		EmitSoundToClient(victim, RM_SOUND_RETALIATE, _, _, 70, _, 0.7, 110);
	}
}

public void RedMist_OnKill(int client, int victim)
{
	int level = i_RM_WeaponLevel[client];

	if (i_RM_KillStacks[client] < RM_MAX_STACKS)
	{
		i_RM_KillStacks[client]++;
		EmitSoundToClient(client, RM_SOUND_KILL_STACK, _, _, 60, _, 0.8, 100 + i_RM_KillStacks[client] * 5);

		if (level >= 5
			&& i_RM_KillStacks[client] >= RM_EGO_KILL_THRESHOLD
			&& !b_RM_EGOActive[client]
			&& GetGameTime() >= f_RM_EGOCooldown[client])
		{
			RM_ActivateEGO(client);
		}
	}

	if (i_RM_OnrushChains[client] > 0 && level >= 1)
	{
		i_RM_OnrushChains[client]--;
		CreateTimer(0.15, Timer_OnrushChain, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	}
}

static void RM_ActivateEGO(int client)
{
	b_RM_EGOActive[client]            = true;
	f_RM_EGOEnd[client]               = GetGameTime() + RM_EGO_DURATION;
	f_RM_EGOCooldown[client]          = GetGameTime() + RM_EGO_DURATION + RM_EGO_COOLDOWN;
	f_RM_LastDamageTime[client]       = GetGameTime();
	f_RM_TotalDmgInWindow[client]     = RM_PRESSURE_THRESHOLD;

	EmitSoundToAll(RM_SOUND_EGO_START, client, _, 80, _, 1.0, 85);
	EmitSoundToAll(RM_SOUND_EGO_START, client, _, 80, _, 1.0, 85);

	float pos[3];
	WorldSpaceCenter(client, pos);
	spawnRing_Vectors(pos, 350.0, 0.0, 0.0, 0.0, RM_BEAM_MATERIAL, 180, 0, 0, 230, 1, 0.6, 5.0, 0.3, 1, 1.0);
	float pos2[3] = pos;
	pos2[2] += 60.0;
	spawnRing_Vectors(pos2, 220.0, 0.0, 0.0, 0.0, RM_BEAM_MATERIAL, 220, 10, 10, 180, 1, 0.5, 5.0, 0.25, 1, 1.0);

	TE_Particle("unusual_hot_sparks", pos, NULL_VECTOR, NULL_VECTOR, client, _, _, _, _, _, _, _, _, _, 0.0);
	TE_Particle("unusual_hot_sparks", pos, NULL_VECTOR, NULL_VECTOR, client, _, _, _, _, _, _, _, _, _, 0.0);

	GiveCompleteInvul(client, 1.5);

	SetGlobalTransTarget(client);
	PrintHintText(client, "E.G.O MANIFESTED\nMimicry thirsts for blood.\nDeal damage or suffer.");
}

static void RM_DeactivateEGO(int client)
{
	b_RM_EGOActive[client] = false;
	i_RM_KillStacks[client] = 0;
	f_RM_TotalDmgInWindow[client] = 0.0;

	float pos[3]; WorldSpaceCenter(client, pos);
	TE_Particle("unusual_hot_sparks", pos, NULL_VECTOR, NULL_VECTOR, client, _, _, _, _, _, _, _, _, _, 0.0);
	EmitSoundToClient(client, RM_SOUND_PRESSURE_FAIL, _, _, 60, _, 0.6, 80);
	PrintHintText(client, "E.G.O fades.\nRed Mist stacks reset.");
}

public void RedMist_Onrush(int client, int weapon, bool crit, int slot)
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
	DoSwingTrace_Custom(swingTrace, client, vecSwingForward, RM_ONRUSH_RANGE, false, 40.0, true);
	FinishLagCompensation_Base_boss();

	int target = TR_GetEntityIndex(swingTrace);
	delete swingTrace;

	if (!IsValidEnemy(client, target, true))
	{
		ClientCommand(client, "playgamesound items/medshotno1.wav");
		return;
	}

	int level = i_RM_WeaponLevel[client];
	bool ego  = b_RM_EGOActive[client];

	ApplyStatusEffect(weapon, weapon, "RM Onrush Chain", 1.5);
	i_RM_OnrushChains[client] = ego ? 2 : 1;

	Rogue_OnAbilityUse(client, weapon);

	float cd = 14.0 - float(level) * 0.7;
	if (ego) cd *= 0.65;
	if (cd < 6.0) cd = 6.0;
	Ability_Apply_Cooldown(client, slot, cd);

	EmitSoundToAll(RM_SOUND_ONRUSH, client, _, 70, _, 1.0, 90);

	int trail = Trail_Attach(client, ARROW_TRAIL_RED, 255, 0.40, 60.0, 3.0, 5);
	SDKCall_SetLocalOrigin(trail, {0.0, 0.0, 50.0});
	CreateTimer(0.40, Timer_RemoveEntityParent, EntIndexToEntRef(trail), TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(1.0,  Timer_RemoveEntity,       EntIndexToEntRef(trail), TIMER_FLAG_NO_MAPCHANGE);

	TF2_AddCondition(client, TFCond_LostFooting, 0.35);
	TF2_AddCondition(client, TFCond_AirCurrent,  0.35);

	float mePos[3]; WorldSpaceCenter(client, mePos);
	float tgPos[3]; WorldSpaceCenter(target, tgPos);
	float dir[3];
	MakeVectorFromPoints(mePos, tgPos, dir);
	GetVectorAngles(dir, dir);

	float vel[3];
	GetAngleVectors(dir, vel, NULL_VECTOR, NULL_VECTOR);
	float dashSpeed = 900.0 + float(level) * 25.0;
	if (ego) dashSpeed *= 1.2;
	ScaleVector(vel, dashSpeed);
	vel[2] += 90.0;
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vel);
}

public Action Timer_OnrushChain(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (!IsValidClient(client) || !IsPlayerAlive(client))
		return Plugin_Stop;

	int weapon = EntRefToEntIndex(ref_RM_Weapon[client]);
	if (!IsValidEntity(weapon))
		return Plugin_Stop;

	float clientPos[3]; WorldSpaceCenter(client, clientPos);
	int   bestTarget  = -1;
	float bestDist    = 600.0;

	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "base_boss")) != -1)
	{
		if (!IsValidEnemy(client, entity, true)) continue;
		float pos[3]; WorldSpaceCenter(entity, pos);
		float dist = GetVectorDistance(clientPos, pos);
		if (dist < bestDist)
		{
			bestDist   = dist;
			bestTarget = entity;
		}
	}

	if (bestTarget == -1)
		return Plugin_Stop;

	ApplyStatusEffect(weapon, weapon, "RM Onrush Chain", 1.5);

	int trail = Trail_Attach(client, ARROW_TRAIL_RED, 200, 0.30, 60.0, 2.0, 5);
	SDKCall_SetLocalOrigin(trail, {0.0, 0.0, 50.0});
	CreateTimer(0.30, Timer_RemoveEntityParent, EntIndexToEntRef(trail), TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(0.8,  Timer_RemoveEntity,       EntIndexToEntRef(trail), TIMER_FLAG_NO_MAPCHANGE);

	TF2_AddCondition(client, TFCond_LostFooting, 0.3);
	TF2_AddCondition(client, TFCond_AirCurrent,  0.3);

	float mePos[3]; WorldSpaceCenter(client, mePos);
	float tgPos[3]; WorldSpaceCenter(bestTarget, tgPos);
	float dir[3];
	MakeVectorFromPoints(mePos, tgPos, dir);
	GetVectorAngles(dir, dir);

	float vel[3];
	GetAngleVectors(dir, vel, NULL_VECTOR, NULL_VECTOR);
	ScaleVector(vel, 850.0);
	vel[2] += 80.0;
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vel);

	EmitSoundToAll(RM_SOUND_ONRUSH, client, _, 55, _, 1.0, 100);

	return Plugin_Stop;
}

public void RedMist_GreatSplitVertical(int client, int weapon, bool crit, int slot)
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
	DoSwingTrace_Custom(swingTrace, client, vecSwingForward, RM_SPLIT_V_RANGE, false, 45.0, true);
	FinishLagCompensation_Base_boss();

	int target = TR_GetEntityIndex(swingTrace);
	delete swingTrace;

	if (!IsValidEnemy(client, target, true))
	{
		ClientCommand(client, "playgamesound items/medshotno1.wav");
		return;
	}

	int   level = i_RM_WeaponLevel[client];
	bool  ego   = b_RM_EGOActive[client];

	Rogue_OnAbilityUse(client, weapon);

	float cd = 20.0 - float(level) * 0.6;
	if (ego) cd *= 0.70;
	if (cd < 10.0) cd = 10.0;
	Ability_Apply_Cooldown(client, slot, cd, weapon);

	EmitSoundToAll(RM_SOUND_SWING_1, client, _, 75, _, 1.0, 80);
	EmitSoundToAll(RM_SOUND_SWING_2, client, _, 75, _, 1.0, 80);

	int trail = Trail_Attach(client, ARROW_TRAIL_RED, 255, 0.5, 60.0, 5.0, 5);
	SDKCall_SetLocalOrigin(trail, {0.0, 0.0, 60.0});
	CreateTimer(0.5,  Timer_RemoveEntityParent, EntIndexToEntRef(trail), TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(1.2,  Timer_RemoveEntity,       EntIndexToEntRef(trail), TIMER_FLAG_NO_MAPCHANGE);

	ApplyStatusEffect(client, target, "Memorial Debuff", 5.0);
	StatusEffects_SinkingDebuffAdd(target, 5);

	SensalCauseKnockback(client, target, 0.7, false);

	float damage = 120.0 * WeaponDamageAttributeMultipliers(weapon, _, client);
	if (ego) damage *= 1.30;
	damage *= (1.0 + float(i_RM_KillStacks[client]) * 0.08);

	float tgPos[3]; WorldSpaceCenter(target, tgPos);
	float force[3] = {0.0, 0.0, 0.1};
	SDKHooks_TakeDamage(target, weapon, client, damage, DMG_SLASH, -1, force, tgPos);

	EmitSoundToAll(RM_SOUND_HIT, target, _, 70, _, 1.0, 85);
}

public void RedMist_GreatSplitHorizontal(int client, int weapon, bool crit, int slot)
{
	if (!b_RM_EGOActive[client])
	{
		RedMist_Onrush(client, weapon, crit, slot);
		return;
	}

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

	int level = i_RM_WeaponLevel[client];

	Rogue_OnAbilityUse(client, weapon);

	float cd = 22.0 - float(level) * 0.5;
	if (cd < 14.0) cd = 14.0;
	Ability_Apply_Cooldown(client, slot, cd, weapon);

	EmitSoundToAll(RM_SOUND_SPLIT_H, client, _, 80, _, 1.0, 82);
	EmitSoundToAll(RM_SOUND_SPLIT_H, client, _, 80, _, 1.0, 82);
	EmitSoundToAll(RM_SOUND_SWING_1, client, _, 75, _, 1.0, 75);

	float origin[3]; WorldSpaceCenter(client, origin);

	spawnRing_Vectors(origin, RM_SPLIT_H_RADIUS * 2.0, 0.0, 0.0, 0.0,
		RM_BEAM_MATERIAL, 200, 0, 0, 220, 1, 0.6, 6.0, 0.35, 1, 1.0);

	float origin2[3] = origin;
	origin2[2] += 80.0;
	spawnRing_Vectors(origin2, RM_SPLIT_H_RADIUS * 1.6, 0.0, 0.0, 0.0,
		RM_BEAM_MATERIAL, 230, 20, 0, 170, 1, 0.5, 5.0, 0.3, 1, 1.0);

	TE_Particle("unusual_hot_sparks", origin, NULL_VECTOR, NULL_VECTOR, client, _, _, _, _, _, _, _, _, _, 0.0);
	TE_Particle("unusual_hot_sparks", origin, NULL_VECTOR, NULL_VECTOR, client, _, _, _, _, _, _, _, _, _, 0.0);

	int trail = Trail_Attach(client, ARROW_TRAIL_RED, 255, 0.55, 60.0, 6.0, 5);
	SDKCall_SetLocalOrigin(trail, {0.0, 0.0, 40.0});
	CreateTimer(0.55, Timer_RemoveEntityParent, EntIndexToEntRef(trail), TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(1.4,  Timer_RemoveEntity,       EntIndexToEntRef(trail), TIMER_FLAG_NO_MAPCHANGE);

	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(client));
	pack.WriteCell(EntIndexToEntRef(weapon));
	pack.WriteFloat(origin[0]);
	pack.WriteFloat(origin[1]);
	pack.WriteFloat(origin[2]);
	CreateDataTimer(0.2, Timer_GreatSplitH_Damage, pack, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_GreatSplitH_Damage(Handle timer, DataPack pack)
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

	float damage = 100.0 * WeaponDamageAttributeMultipliers(weapon, _, client);
	damage *= (1.0 + float(i_RM_KillStacks[client]) * 0.08);
	damage *= 1.30;

	Explode_Logic_Custom(damage, client, client, weapon, loc, RM_SPLIT_H_RADIUS, _, _, false, 12);

	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "base_boss")) != -1)
	{
		if (!IsValidEnemy(client, entity, true)) continue;
		float ePos[3]; WorldSpaceCenter(entity, ePos);
		if (GetVectorDistance(loc, ePos) <= RM_SPLIT_H_RADIUS)
		{
			ApplyStatusEffect(client, entity, "Sinking", 10.0);
			StatusEffects_SinkingDebuffAdd(entity, 5);
			SensalCauseKnockback(client, entity, 0.5, false);
		}
	}

	f_RM_TotalDmgInWindow[client] += damage * 0.5;

	return Plugin_Stop;
}
