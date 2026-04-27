#pragma semicolon 1
#pragma newdecls required

// --- Vulnerability stacking per NPC ---
#define IRLN_VULN_PER_HIT		0.10	// 10% per hit
#define IRLN_VULN_MAX			1.20	// caps at 120%
#define IRLN_VULN_DECAY_RATE	0.10	// 10% decay per second
#define IRLN_VULN_HIT_COOLDOWN	0.25	// seconds between vulnerability ticks per entity

static float fl_IrlnVuln[MAXENTITIES];				// current vulnerability multiplier per NPC
static float fl_IrlnVulnDecayTime[MAXENTITIES];		// next time to apply decay
static float fl_IrlnVulnLastHit[MAXENTITIES];		// last hit time (to know when to start decaying)

// --- PAP1 Blazing Tempest ---
#define IRLN_TEMPEST_DURATION		5.0		// how long the rapid fire lasts
#define IRLN_TEMPEST_COOLDOWN		20.0	// cooldown after use
#define IRLN_TEMPEST_TICK_RATE		0.05	// how often bursts fire
#define IRLN_TEMPEST_BASE_DAMAGE	400.0	// damage per burst per target
#define IRLN_TEMPEST_FALLOFF		0.70	// damage falloff per penetrated enemy
#define IRLN_TEMPEST_MAX_TARGETS	10		// max enemies per burst
#define IRLN_TEMPEST_RANGE			1200.0	// burst range

#define IRLN_PARTICLE_PLAYER		"utaunt_burningdesire_orange_parent"
#define IRLN_PARTICLE_HIT			"heavy_ring_of_fire"
#define IRLN_SOUND_IGNITE			")ambient/fire/fire_med_burn1.wav"
#define IRLN_SOUND_BURST_1			")weapons/flame_thrower_fire_start.wav"
#define IRLN_SOUND_BURST_2			")weapons/flame_thrower_loop.wav"
#define IRLN_SOUND_BURST_END		")player/flame_out.wav"

static Handle h_IrlnTimer[MAXPLAYERS+1]		= {null, ...};
static float fl_IrlnTempestEnd[MAXPLAYERS+1]	= {0.0, ...};
static bool b_IrlnTempestActive[MAXPLAYERS+1]	= {false, ...};
static int i_IrlnPlayerParticle[MAXPLAYERS+1];	// the burning particle on the player

// For the weapon fire effect
static bool b_IrlnWeaponFire[MAXPLAYERS+1]		= {false, ...};

// Penetrating burst hit detection
static bool b_IrlnBurstHit[MAXENTITIES]		= {false, ...};

// --- Laser beam index for visual ---
static int IrlnBeamIndex;

void SwordIrln_MapStart()
{
	for (int i = 0; i < MAXENTITIES; i++)
	{
		fl_IrlnVuln[i]			= 0.0;
		fl_IrlnVulnDecayTime[i]	= 0.0;
		fl_IrlnVulnLastHit[i]	= 0.0;
		b_IrlnBurstHit[i]		= false;
	}
	for (int c = 0; c <= MaxClients; c++)
	{
		b_IrlnTempestActive[c]		= false;
		fl_IrlnTempestEnd[c]		= 0.0;
		b_IrlnWeaponFire[c]			= false;
		i_IrlnPlayerParticle[c]		= INVALID_ENT_REFERENCE;
		h_IrlnTimer[c]				= null;
	}
	IrlnBeamIndex = PrecacheModel("materials/sprites/laser.vmt", false);
	PrecacheSound(IRLN_SOUND_IGNITE);
	PrecacheSound(IRLN_SOUND_BURST_1);
	PrecacheSound(IRLN_SOUND_BURST_2);
	PrecacheSound(IRLN_SOUND_BURST_END);
}

// --- Vulnerability Decay Tick (called from a global game tick / PreThink hook if available) ---
// Called via the management timer
static void SwordIrln_VulnDecayTick()
{
	float gt = GetGameTime();
	for (int i = 1; i < MAXENTITIES; i++)
	{
		if (fl_IrlnVuln[i] <= 0.0)
			continue;
		if (!IsValidEntity(i))
		{
			fl_IrlnVuln[i] = 0.0;
			continue;
		}
		// Start decaying 3 seconds after the last hit
		if (gt - fl_IrlnVulnLastHit[i] > 3.0 && fl_IrlnVulnDecayTime[i] <= gt)
		{
			fl_IrlnVuln[i] -= IRLN_VULN_DECAY_RATE * 0.1; // 0.1 because timer runs at 0.1s
			fl_IrlnVulnDecayTime[i] = gt + 1.0;
			if (fl_IrlnVuln[i] < 0.0)
				fl_IrlnVuln[i] = 0.0;
		}
	}
}

// --- Called when player equips the weapon ---
public void Enable_SwordIrln(int client, int weapon)
{
	if (i_CustomWeaponEquipLogic[weapon] != WEAPON_SWORD_IRLN)
		return;

	if (h_IrlnTimer[client] != null)
	{
		delete h_IrlnTimer[client];
		h_IrlnTimer[client] = null;
	}

	DataPack pack;
	h_IrlnTimer[client] = CreateDataTimer(0.1, Timer_IrlnManagement, pack, TIMER_REPEAT);
	pack.WriteCell(client);
	pack.WriteCell(EntIndexToEntRef(weapon));
}

public Action Timer_IrlnManagement(Handle timer, DataPack pack)
{
	pack.Reset();
	int client = pack.ReadCell();
	int weapon = EntRefToEntIndex(pack.ReadCell());

	if (!IsValidClient(client) || !IsClientInGame(client) || !IsPlayerAlive(client) || !IsValidEntity(weapon))
	{
		SwordIrln_Cleanup(client);
		h_IrlnTimer[client] = null;
		return Plugin_Stop;
	}

	SwordIrln_VulnDecayTick();

	int weapon_holding = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (weapon_holding == weapon)
	{
		// Ensure the weapon is always on fire visually
		SwordIrln_ApplyWeaponFire(client);

		// HUD
		float gt = GetGameTime();
		SwordIrln_ShowHUD(client, gt);

		// If tempest is active, fire rapid bursts
		if (b_IrlnTempestActive[client])
		{
			if (gt >= fl_IrlnTempestEnd[client])
			{
				SwordIrln_EndTempest(client);
			}
			else
			{
				SwordIrln_FireBurst(client, weapon);
			}
		}
	}
	else
	{
		// Weapon put away — extinguish weapon fire, keep tempest tracking
		SwordIrln_RemoveWeaponFire(client);
	}

	return Plugin_Continue;
}

// --- Weapon fire effect (always on) ---
static void SwordIrln_ApplyWeaponFire(int client)
{
	if (b_IrlnWeaponFire[client])
		return;

	int worldModel = EntRefToEntIndex(i_Worldmodel_WeaponModel[client]);
	if (IsValidEntity(worldModel))
	{
		if (Timer_Ingition_Settings[worldModel] == null)
		{
			IgniteTargetEffect(worldModel, FIRSTPERSON, client);
		}
	}

	int viewModel = EntRefToEntIndex(WeaponRef_viewmodel[client]);
	if (IsValidEntity(viewModel))
	{
		if (Timer_Ingition_Settings[viewModel] == null)
		{
			IgniteTargetEffect(viewModel, THIRDPERSON, client);
		}
	}

	b_IrlnWeaponFire[client] = true;
}

static void SwordIrln_RemoveWeaponFire(int client)
{
	if (!b_IrlnWeaponFire[client])
		return;

	int worldModel = EntRefToEntIndex(i_Worldmodel_WeaponModel[client]);
	if (IsValidEntity(worldModel) && Timer_Ingition_Settings[worldModel] != null)
		ExtinguishTarget(worldModel);

	int viewModel = EntRefToEntIndex(WeaponRef_viewmodel[client]);
	if (IsValidEntity(viewModel) && Timer_Ingition_Settings[viewModel] != null)
		ExtinguishTarget(viewModel);

	b_IrlnWeaponFire[client] = false;
}

// --- HUD ---
static void SwordIrln_ShowHUD(int client, float gt)
{
	int pap = RoundFloat(Attributes_Get(GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon"), 122, 0.0));
	if (pap < 1)
		return;

	if (b_IrlnTempestActive[client])
	{
		float remaining = fl_IrlnTempestEnd[client] - gt;
		PrintHintText(client, "⚔ BLAZING TEMPEST: ACTIVE [%.1fs remaining]", remaining);
	}
	else
	{
		float cd = Ability_Check_Cooldown(client, 2);
		if (cd > 0.0)
			PrintHintText(client, "⚔ Blazing Tempest [%.1fs] (M2)", cd);
		else
			PrintHintText(client, "⚔ Blazing Tempest [READY] (M2)");
	}
}

// --- M2 Callback (dispatched via weapons.cfg func_attack2) ---
public void SwordIrln_M2(int client, int weapon, bool crit, int slot)
{
	int pap = RoundFloat(Attributes_Get(weapon, 122, 0.0));
	if (pap < 1)
		return;

	if (b_IrlnTempestActive[client])
		return; // Already active

	float cd = Ability_Check_Cooldown(client, 2);
	if (cd > 0.0)
	{
		ClientCommand(client, "playgamesound items/medshotno1.wav");
		SetDefaultHudPosition(client);
		SetGlobalTransTarget(client);
		ShowSyncHudText(client, SyncHud_Notifaction, "Blazing Tempest on cooldown: %.1fs", cd);
		return;
	}

	SwordIrln_ActivateTempest(client);
}

static void SwordIrln_ActivateTempest(int client)
{
	b_IrlnTempestActive[client] = true;
	fl_IrlnTempestEnd[client] = GetGameTime() + IRLN_TEMPEST_DURATION;

	// Attach the burning unusual particle to the player
	SwordIrln_AttachPlayerParticle(client);

	// Sound
	EmitSoundToAll(IRLN_SOUND_IGNITE, client, SNDCHAN_STATIC, 80, _, 0.8);
	EmitSoundToAll(IRLN_SOUND_BURST_1, client, SNDCHAN_AUTO, 75, _, 0.9);
	EmitSoundToAll(IRLN_SOUND_BURST_2, client, SNDCHAN_STATIC, 70, _, 0.7, 80);

	Client_Shake(client, _, 10.0, 80.0, 0.5);
}

static void SwordIrln_AttachPlayerParticle(int client)
{
	SwordIrln_RemovePlayerParticle(client);

	float flPos[3];
	GetClientAbsOrigin(client, flPos);
	int particle = ParticleEffectAt(flPos, IRLN_PARTICLE_PLAYER, 0.0);
	AddEntityToThirdPersonTransitMode(client, particle);
	SetParent(client, particle);
	i_IrlnPlayerParticle[client] = EntIndexToEntRef(particle);

	// Also set the player on fire visually via TFCond
	TF2_AddCondition(client, TFCond_OnFire, IRLN_TEMPEST_DURATION + 1.0, client);
}

static void SwordIrln_RemovePlayerParticle(int client)
{
	int particle = EntRefToEntIndex(i_IrlnPlayerParticle[client]);
	if (IsValidEntity(particle))
		RemoveEntity(particle);
	i_IrlnPlayerParticle[client] = INVALID_ENT_REFERENCE;
}

static void SwordIrln_EndTempest(int client)
{
	b_IrlnTempestActive[client] = false;

	SwordIrln_RemovePlayerParticle(client);
	TF2_RemoveCondition(client, TFCond_OnFire);

	EmitSoundToAll(IRLN_SOUND_BURST_END, client, SNDCHAN_AUTO);
	StopSound(client, SNDCHAN_STATIC, IRLN_SOUND_BURST_2);

	Ability_Apply_Cooldown(client, 2, IRLN_TEMPEST_COOLDOWN);

	Client_Shake(client, _, 5.0, 60.0, 0.3);
}

// --- Penetrating burst fire during Blazing Tempest ---
static float fl_IrlnNextBurst[MAXPLAYERS+1] = {0.0, ...};

static void SwordIrln_FireBurst(int client, int weapon)
{
	float gt = GetGameTime();
	if (fl_IrlnNextBurst[client] > gt)
		return;

	fl_IrlnNextBurst[client] = gt + IRLN_TEMPEST_TICK_RATE;

	float eyePos[3], eyeAng[3], direction[3], endPos[3];
	GetClientEyePosition(client, eyePos);
	GetClientEyeAngles(client, eyeAng);
	GetAngleVectors(eyeAng, direction, NULL_VECTOR, NULL_VECTOR);
	ScaleVector(direction, IRLN_TEMPEST_RANGE);
	AddVectors(eyePos, direction, endPos);

	// Hull trace for penetrating hit detection
	static float hullMin[3] = {-8.0, -8.0, -8.0};
	static float hullMax[3] = {8.0, 8.0, 8.0};

	for (int i = 1; i < MAXENTITIES; i++)
		b_IrlnBurstHit[i] = false;

	b_LagCompNPC_No_Layers = true;
	StartLagCompensation_Base_Boss(client);
	Handle trace = TR_TraceHullFilterEx(eyePos, endPos, hullMin, hullMax, MASK_ALL, IrlnBurst_TraceFilter, client);
	delete trace;
	FinishLagCompensation_Base_boss();

	float baseDMG = IRLN_TEMPEST_BASE_DAMAGE;
	baseDMG *= Attributes_Get(weapon, 2, 1.0);

	int hits = 0;
	for (int victim = 1; victim < MAXENTITIES; victim++)
	{
		if (!b_IrlnBurstHit[victim])
			continue;
		if (!IsValidEnemy(client, victim))
			continue;
		if (hits >= IRLN_TEMPEST_MAX_TARGETS)
			break;

		float victimPos[3];
		WorldSpaceCenter(victim, victimPos);

		float forceDir[3];
		forceDir = direction;
		CalculateDamageForce(forceDir, 5000.0, forceDir);

		// Penetrating melee-type damage
		SDKHooks_TakeDamage(victim, client, client, baseDMG, DMG_CLUB, weapon, forceDir, victimPos, false);

		baseDMG *= IRLN_TEMPEST_FALLOFF;
		hits++;
	}

	// Visual: golden-orange beam along the shot path
	if (hits > 0)
	{
		int colour[4] = {255, 160, 30, 220};
		TE_SetupBeamPoints(eyePos, endPos, IrlnBeamIndex, 0, 0, 0, IRLN_TEMPEST_TICK_RATE + 0.02, 4.0, 4.0, 0, 0.5, colour, 3);
		TE_SendToAll(0.0);

		float hitPos[3];
		WorldSpaceCenter(client, hitPos);
		hitPos[0] += direction[0] * 200.0;
		hitPos[1] += direction[1] * 200.0;
		hitPos[2] += direction[2] * 200.0;
		ParticleEffectAt(hitPos, IRLN_PARTICLE_HIT, 0.3);
	}
}

static bool IrlnBurst_TraceFilter(int entity, int contentsMask, int client)
{
	if (IsEntityAlive(entity) && IsValidEnemy(client, entity, true))
	{
		b_IrlnBurstHit[entity] = true;
	}
	return false; // don't stop — keep penetrating
}

// --- On Melee Hit: Apply Vulnerability ---
// This is called from the ZR damage callback (NPC_OnTakeDamage hook)
public void SwordIrln_OnNPCHit(int client, int victim, int damagetype, int weapon)
{
	if (i_CustomWeaponEquipLogic[weapon] != WEAPON_SWORD_IRLN)
		return;
	if (!(damagetype & DMG_CLUB))
		return; // Only from actual melee swings

	float gt = GetGameTime();
	fl_IrlnVulnLastHit[victim] = gt;

	// Stack vulnerability
	fl_IrlnVuln[victim] += IRLN_VULN_PER_HIT;
	if (fl_IrlnVuln[victim] > IRLN_VULN_MAX)
		fl_IrlnVuln[victim] = IRLN_VULN_MAX;
}

// --- Apply vulnerability multiplier to all incoming damage on NPCs ---
// Call this from the ZR global NPC OnTakeDamage hook
public float SwordIrln_ApplyVuln(int victim, float damage)
{
	if (victim < 1 || victim >= MAXENTITIES)
		return damage;
	if (fl_IrlnVuln[victim] <= 0.0)
		return damage;

	damage *= (1.0 + fl_IrlnVuln[victim]);
	return damage;
}

// --- Cleanup on player death / disconnect ---
static void SwordIrln_Cleanup(int client)
{
	if (b_IrlnTempestActive[client])
	{
		b_IrlnTempestActive[client] = false;
		TF2_RemoveCondition(client, TFCond_OnFire);
		StopSound(client, SNDCHAN_STATIC, IRLN_SOUND_BURST_2);
	}
	SwordIrln_RemovePlayerParticle(client);
	SwordIrln_RemoveWeaponFire(client);
}
