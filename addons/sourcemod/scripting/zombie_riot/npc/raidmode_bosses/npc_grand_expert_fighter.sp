#pragma semicolon 1
#pragma newdecls required

static const char g_DeathSounds[][] = {
	"npc/combine_soldier/die1.wav",
	"npc/combine_soldier/die2.wav",
	"npc/combine_soldier/die3.wav",
};

static const char g_HurtSound[][] = {
	"npc/combine_soldier/pain1.wav",
	"npc/combine_soldier/pain2.wav",
	"npc/combine_soldier/pain3.wav",
};

static const char g_IdleSound[][] = {
	"npc/combine_soldier/vo/alert1.wav",
	"npc/combine_soldier/vo/bouncerbouncer.wav",
	"npc/combine_soldier/vo/boomer.wav",
	"npc/combine_soldier/vo/contactconfim.wav",
};

static const char g_IdleAlertedSounds[][] = {
	"npc/metropolice/vo/chuckle.wav",
};

static const char g_MeleeAttackSounds[][] = {
	"weapons/boxing_gloves_swing1.wav",
	"weapons/boxing_gloves_swing2.wav",
	"weapons/boxing_gloves_swap.wav",
};

static const char g_MeleeHitSounds[][] = {
	"weapons/boxing_gloves_hit1.wav",
	"weapons/boxing_gloves_hit2.wav",
	"weapons/boxing_gloves_hit3.wav",
	"weapons/boxing_gloves_hit4.wav",
};

static const char g_ChargeExplodeIn[][] = {
	"weapons/dragon_gun_motor_start.wav",
};

static const char g_DoExplodeSound[][] = {
	"weapons/cow_mangler_explosion_normal_01.wav",
	"weapons/cow_mangler_explosion_normal_02.wav",
	"weapons/cow_mangler_explosion_normal_03.wav",
};

// Zone ability — warning charge sound
static const char g_ZoneChargeSound[][] = {
	"weapons/physcannon/physcannon_charge.wav",
};

// Zone ability — detonation sound
static const char g_ZoneCastSound[][] = {
	"weapons/physcannon/energy_sing_explosion2.wav",
};

// Laser windup sound
static const char g_LaserWindupSound[][] = {
	"weapons/dragon_gun_motor_start.wav",
};

// Laser fire sound
static const char g_LaserFireSound[][] = {
	"weapons/physcannon/superphys_launch1.wav",
	"weapons/physcannon/superphys_launch2.wav",
	"weapons/physcannon/superphys_launch3.wav",
	"weapons/physcannon/superphys_launch4.wav",
};

static int   GEF_NPCId;                               // used to spawn clones of GEF
static float fl_GEF_CloneLifespan[MAXENTITIES];       // 0 = real boss, >0 = clone auto-despawn time

void RaidbossGrandExpertFighter_MapStart_NPC()
{
	for (int i = 0; i < (sizeof(g_DeathSounds)); i++) { PrecacheSound(g_DeathSounds[i]); }
	for (int i = 0; i < (sizeof(g_MeleeAttackSounds)); i++) { PrecacheSound(g_MeleeAttackSounds[i]); }
	for (int i = 0; i < (sizeof(g_MeleeHitSounds)); i++) { PrecacheSound(g_MeleeHitSounds[i]); }
	for (int i = 0; i < (sizeof(g_IdleSound)); i++) { PrecacheSound(g_IdleSound[i]); }
	for (int i = 0; i < (sizeof(g_HurtSound)); i++) { PrecacheSound(g_HurtSound[i]); }
	for (int i = 0; i < (sizeof(g_IdleAlertedSounds)); i++) { PrecacheSound(g_IdleAlertedSounds[i]); }
	for (int i = 0; i < (sizeof(g_ChargeExplodeIn)); i++) { PrecacheSound(g_ChargeExplodeIn[i]); }
	for (int i = 0; i < (sizeof(g_DoExplodeSound)); i++) { PrecacheSound(g_DoExplodeSound[i]); }
	for (int i = 0; i < (sizeof(g_ZoneChargeSound)); i++) { PrecacheSound(g_ZoneChargeSound[i]); }
	for (int i = 0; i < (sizeof(g_ZoneCastSound)); i++) { PrecacheSound(g_ZoneCastSound[i]); }
	for (int i = 0; i < (sizeof(g_LaserWindupSound)); i++) { PrecacheSound(g_LaserWindupSound[i]); }
	for (int i = 0; i < (sizeof(g_LaserFireSound)); i++) { PrecacheSound(g_LaserFireSound[i]); }

	PrecacheModel(COMBINE_CUSTOM_MODEL);
	PrecacheModel("models/workshop/player/items/soldier/hw2013_rocket_ranger/hw2013_rocket_ranger.mdl");
	PrecacheModel("models/workshop/player/items/spy/dec2014_stealthy_scarf/dec2014_stealthy_scarf.mdl");

	NPCData data;
	strcopy(data.Name, sizeof(data.Name), "Enhanced W.F. Elite Brawler");
	strcopy(data.Plugin, sizeof(data.Plugin), "npc_grand_expert_fighter");
	strcopy(data.Icon, sizeof(data.Icon), "");
	data.IconCustom = false;
	data.Flags = 0;
	data.Category = Type_Raid;
	data.Func = ClotSummon;
	GEF_NPCId = NPC_Add(data);
}

static any ClotSummon(int client, float vecPos[3], float vecAng[3], int team, const char[] data)
{
	return RaidbossGrandExpertFighter(vecPos, vecAng, team, data);
}

methodmap RaidbossGrandExpertFighter < CClotBody
{
	public void PlayIdleSound()
	{
		if(this.m_flNextIdleSound > GetGameTime(this.index))
			return;
		
		int rand = GetRandomInt(0, sizeof(g_IdleSound) - 1);
		EmitSoundToAll(g_IdleSound[rand], this.index, SNDCHAN_VOICE, BOSS_ZOMBIE_SOUNDLEVEL, _, BOSS_ZOMBIE_VOLUME);
		this.m_flNextIdleSound = GetGameTime(this.index) + GetRandomFloat(24.0, 48.0);
	}
	
	public void PlayHurtSound()
	{
		EmitSoundToAll(g_HurtSound[GetRandomInt(0, sizeof(g_HurtSound) - 1)], this.index, SNDCHAN_VOICE, BOSS_ZOMBIE_SOUNDLEVEL, _, BOSS_ZOMBIE_VOLUME);
	}
	
	public void PlayDeathSound()
	{
		EmitSoundToAll(g_DeathSounds[GetRandomInt(0, sizeof(g_DeathSounds) - 1)], this.index, SNDCHAN_VOICE, BOSS_ZOMBIE_SOUNDLEVEL, _, BOSS_ZOMBIE_VOLUME);
	}
	
	public void PlayKilledEnemySound()
	{
		int rand = GetRandomInt(0, sizeof(g_IdleAlertedSounds) - 1);
		EmitSoundToAll(g_IdleAlertedSounds[rand], this.index, SNDCHAN_VOICE, BOSS_ZOMBIE_SOUNDLEVEL, _, BOSS_ZOMBIE_VOLUME);
		this.m_flNextIdleSound = GetGameTime(this.index) + GetRandomFloat(5.0, 10.0);
	}
	
	public void PlayMeleeSound()
	{
		EmitSoundToAll(g_MeleeAttackSounds[GetRandomInt(0, sizeof(g_MeleeAttackSounds) - 1)], this.index, SNDCHAN_AUTO, BOSS_ZOMBIE_SOUNDLEVEL, _, BOSS_ZOMBIE_VOLUME);
	}
	
	public void PlayMeleeHitSound()
	{
		EmitSoundToAll(g_MeleeHitSounds[GetRandomInt(0, sizeof(g_MeleeHitSounds) - 1)], this.index, SNDCHAN_AUTO, BOSS_ZOMBIE_SOUNDLEVEL, _, BOSS_ZOMBIE_VOLUME);
	}
	
	public void PlayChargeExplode()
	{
		EmitSoundToAll(g_ChargeExplodeIn[GetRandomInt(0, sizeof(g_ChargeExplodeIn) - 1)], this.index, SNDCHAN_AUTO, BOSS_ZOMBIE_SOUNDLEVEL, _, BOSS_ZOMBIE_VOLUME);
	}
	
	public void PlayExplodeSound()
	{
		EmitSoundToAll(g_DoExplodeSound[GetRandomInt(0, sizeof(g_DoExplodeSound) - 1)], this.index, SNDCHAN_AUTO, BOSS_ZOMBIE_SOUNDLEVEL, _, BOSS_ZOMBIE_VOLUME);
	}

	public void PlayZoneChargeSound()
	{
		EmitSoundToAll(g_ZoneChargeSound[GetRandomInt(0, sizeof(g_ZoneChargeSound) - 1)], this.index, SNDCHAN_STATIC, BOSS_ZOMBIE_SOUNDLEVEL, _, BOSS_ZOMBIE_VOLUME);
	}

	public void PlayZoneCastSound()
	{
		EmitSoundToAll(g_ZoneCastSound[GetRandomInt(0, sizeof(g_ZoneCastSound) - 1)], this.index, SNDCHAN_STATIC, BOSS_ZOMBIE_SOUNDLEVEL, _, BOSS_ZOMBIE_VOLUME);
	}

	public void PlayLaserWindupSound()
	{
		EmitSoundToAll(g_LaserWindupSound[GetRandomInt(0, sizeof(g_LaserWindupSound) - 1)], this.index, SNDCHAN_AUTO, BOSS_ZOMBIE_SOUNDLEVEL, _, BOSS_ZOMBIE_VOLUME);
	}

	public void PlayLaserFireSound()
	{
		EmitSoundToAll(g_LaserFireSound[GetRandomInt(0, sizeof(g_LaserFireSound) - 1)], this.index, SNDCHAN_WEAPON, BOSS_ZOMBIE_SOUNDLEVEL, _, BOSS_ZOMBIE_VOLUME, 120);
	}

	// [4] Zone ability cooldown
	property float m_flZoneAbilityCooldown
	{
		public get() { return fl_AbilityOrAttack[this.index][4]; }
		public set(float v) { fl_AbilityOrAttack[this.index][4] = v; }
	}

	// [5] Zone ability happening timer (> 0 = detonation pending)
	property float m_flZoneAbilityHappening
	{
		public get() { return fl_AbilityOrAttack[this.index][5]; }
		public set(float v) { fl_AbilityOrAttack[this.index][5] = v; }
	}

	// [6] Outlander laser cooldown (only used after half-HP)
	property float m_flOutlanderLaserCooldown
	{
		public get() { return fl_AbilityOrAttack[this.index][6]; }
		public set(float v) { fl_AbilityOrAttack[this.index][6] = v; }
	}

	// [7] Outlander laser happening timer (> 0 = windup/fire pending)
	property float m_flOutlanderLaserHappening
	{
		public get() { return fl_AbilityOrAttack[this.index][7]; }
		public set(float v) { fl_AbilityOrAttack[this.index][7] = v; }
	}

	// [8] Visual effect throttle shared by zone rings
	property float m_flGEFEffectThrottle
	{
		public get() { return fl_AbilityOrAttack[this.index][8]; }
		public set(float v) { fl_AbilityOrAttack[this.index][8] = v; }
	}

	// [9] Clone ability cooldown — available once anger triggers at 50 % HP
	property float m_flCloneAbilityCooldown
	{
		public get() { return fl_AbilityOrAttack[this.index][9]; }
		public set(float v) { fl_AbilityOrAttack[this.index][9] = v; }
	}

	property float m_flTimeTillSelfExplode
	{
		public get() { return fl_AbilityOrAttack[this.index][0]; }
		public set(float TempValueForProperty) { fl_AbilityOrAttack[this.index][0] = TempValueForProperty; }
	}
	
	property float m_flTimeTillSelfExplodeCD
	{
		public get() { return fl_AbilityOrAttack[this.index][1]; }
		public set(float TempValueForProperty) { fl_AbilityOrAttack[this.index][1] = TempValueForProperty; }
	}
	
	property float m_flTimeTillAllowAction
	{
		public get() { return fl_AbilityOrAttack[this.index][2]; }
		public set(float TempValueForProperty) { fl_AbilityOrAttack[this.index][2] = TempValueForProperty; }
	}
	
	property float m_flGrandExpertAngerResistance
	{
		public get() { return fl_AbilityOrAttack[this.index][3]; }
		public set(float TempValueForProperty) { fl_AbilityOrAttack[this.index][3] = TempValueForProperty; }
	}
	
	public RaidbossGrandExpertFighter(float vecPos[3], float vecAng[3], int ally, const char[] data)
	{
		RaidbossGrandExpertFighter npc = view_as<RaidbossGrandExpertFighter>(CClotBody(vecPos, vecAng, COMBINE_CUSTOM_MODEL, "1.35", "3000000", ally, false));
		
		SetVariantInt(1);
		AcceptEntityInput(npc.index, "SetBodyGroup");
		
		i_NpcWeight[npc.index] = 5;
		
		FormatEx(c_HeadPlaceAttachmentGibName[npc.index], sizeof(c_HeadPlaceAttachmentGibName[]), "head");
		KillFeed_SetKillIcon(npc.index, "fists");

		npc.SetActivity("ACT_IDLE");

		func_NPCDeath[npc.index] = RaidbossGrandExpertFighter_NPCDeath;
		func_NPCOnTakeDamage[npc.index] = RaidbossGrandExpertFighter_OnTakeDamage;
		func_NPCThink[npc.index] = RaidbossGrandExpertFighter_ClotThink;
		
		npc.m_iBleedType = BLEEDTYPE_NORMAL;
		npc.m_iStepNoiseType = STEPSOUND_NORMAL;
		npc.m_iNpcStepVariation = STEPTYPE_COMBINE;
		npc.m_bDissapearOnDeath = true;

		bool final = StrContains(data, "final_item") != -1;
		
		if(Rogue_HasNamedArtifact("Ascension Stack"))
			final = false;
		
		if(final)
		{
			i_RaidGrantExtra[npc.index] = 1;
		}
		
		RemoveAllDamageAddition();

		npc.m_bThisNpcIsABoss = true;
		npc.Anger = false;
		npc.m_flSpeed = 330.0;
		npc.m_iTarget = 0;
		npc.m_flGetClosestTargetTime = 0.0;
		b_thisNpcIsARaid[npc.index] = true;

		npc.m_flMeleeArmor = 0.65;
		npc.m_flGrandExpertAngerResistance = 0.0;

		// New abilities — zone starts available after 20s, laser unlocks at half HP
		npc.m_flZoneAbilityCooldown     = GetGameTime() + 20.0;
		npc.m_flZoneAbilityHappening    = 0.0;
		npc.m_flOutlanderLaserCooldown  = FAR_FUTURE; // locked until half HP
		npc.m_flOutlanderLaserHappening = 0.0;
		npc.m_flGEFEffectThrottle       = 0.0;
		npc.m_flCloneAbilityCooldown    = FAR_FUTURE; // locked until half HP
		
		Citizen_MiniBossSpawn();
		
		npc.m_iWearable1 = npc.EquipItem("weapon_bone", "models/workshop/player/items/soldier/hw2013_rocket_ranger/hw2013_rocket_ranger.mdl");
		SetVariantString("1.35");
		AcceptEntityInput(npc.m_iWearable1, "SetModelScale");

		npc.m_iWearable2 = npc.EquipItem("partyhat", "models/workshop/player/items/spy/dec2014_stealthy_scarf/dec2014_stealthy_scarf.mdl");
		SetVariantString("1.35");
		AcceptEntityInput(npc.m_iWearable2, "SetModelScale");
		
		SetEntityRenderColor(npc.m_iWearable1, 0, 0, 0, 255);
		SetEntityRenderColor(npc.m_iWearable2, 0, 0, 0, 255);

		// Chaos mage passive: tag this NPC as a chaos damage dealer
		Elemental_AddChaosDamage(npc.index, npc.index, 1, false);

		// Chaos mage unusuals — same particles, anchored to the head
		float flPos2[3], flAng2[3];
		npc.GetAttachment("head", flPos2, flAng2);
		npc.m_iWearable4 = ParticleEffectAt_Parent(flPos2, "unusual_smoking",                 npc.index, "head", {0.0, -5.0, -10.0});
		npc.m_iWearable5 = ParticleEffectAt_Parent(flPos2, "unusual_psychic_eye_white_glow",  npc.index, "head", {0.0,  5.0, -15.0});

		bool isClone = StrContains(data, "gef_clone") != -1;

		if(isClone)
		{
			// ── Clone appearance: same model, semi-transparent with a dark blue tint
			SetEntityRenderMode(npc.index,        RENDER_TRANSCOLOR);
			SetEntityRenderMode(npc.m_iWearable1, RENDER_TRANSCOLOR);
			SetEntityRenderMode(npc.m_iWearable2, RENDER_TRANSCOLOR);
			SetEntityRenderColor(npc.index,        0, 20, 80, 190);
			SetEntityRenderColor(npc.m_iWearable1, 0, 20, 80, 190);
			SetEntityRenderColor(npc.m_iWearable2, 0, 20, 80, 190);

			// Clones don't use any special abilities themselves — prevent all CDs
			npc.m_flGrandExpertAngerResistance = 1.0;     // skip the anger trigger
			npc.m_flTimeTillSelfExplodeCD      = FAR_FUTURE;
			npc.m_flZoneAbilityCooldown        = FAR_FUTURE;
			npc.m_flOutlanderLaserCooldown     = FAR_FUTURE;
			npc.m_flCloneAbilityCooldown       = FAR_FUTURE;

			// Clones don't pollute the kill feed
			b_NoKillFeed[npc.index] = true;

			// Auto-despawn tracked via lifespan timer — set in GEF_SpawnClones()
			fl_GEF_CloneLifespan[npc.index] = 0.0; // overwritten immediately after spawn
		}
		else
		{
			// Real boss — standard black colour already set above
			SetEntityRenderColor(npc.index,        0, 0, 0, 255);
			SetEntityRenderColor(npc.m_iWearable1, 0, 0, 0, 255);
			SetEntityRenderColor(npc.m_iWearable2, 0, 0, 0, 255);

			fl_GEF_CloneLifespan[npc.index] = 0.0; // not a clone

			EmitSoundToAll("npc/zombie_poison/pz_alert1.wav");
			EmitSoundToAll("npc/zombie_poison/pz_alert1.wav");

			for(int client_check=1; client_check<=MaxClients; client_check++)
			{
				if(IsClientInGame(client_check) && !IsFakeClient(client_check))
					LookAtTarget(client_check, npc.index);
			}

			RaidModeScaling = 0.0;
			RaidModeTime = GetGameTime() + ((360.0) * (1.0 + (MultiGlobalEnemy * 0.5)));
			Format(WhatDifficultySetting, sizeof(WhatDifficultySetting), "??????????????????????????????????");
			CPrintToChatAll("{blue}Experimented W.F. Elite{default}: You're not him.");
			RaidBossActive = EntIndexToEntRef(npc.index);
			RaidAllowsBuildings = true;
		}

		return npc;
	}
}

public void RaidbossGrandExpertFighter_ClotThink(int iNPC)
{
	RaidbossGrandExpertFighter npc = view_as<RaidbossGrandExpertFighter>(iNPC);
	
	float gameTime = GetGameTime(npc.index);

	if(npc.m_flNextThinkTime != FAR_FUTURE && RaidModeTime < GetGameTime())
	{
		if(IsValidEntity(RaidBossActive))
		{
			ForcePlayerLoss();
			RaidBossActive = INVALID_ENT_REFERENCE;
		}
		func_NPCThink[npc.index] = INVALID_FUNCTION;
		npc.StopPathing();
		npc.m_flNextThinkTime = FAR_FUTURE;
	}

	if(npc.m_flNextDelayTime > gameTime)
		return;

	npc.m_flNextDelayTime = gameTime + DEFAULT_UPDATE_DELAY_FLOAT;
	npc.Update();

	// ── Clone auto-despawn ─────────────────────────────────────────────────
	if(fl_GEF_CloneLifespan[npc.index] && fl_GEF_CloneLifespan[npc.index] < gameTime)
	{
		float pos[3]; GetEntPropVector(npc.index, Prop_Data, "m_vecAbsOrigin", pos);
		ParticleEffectAt(pos, "teleported_blue", 0.5);
		b_DissapearOnDeath[npc.index] = true;
		SmiteNpcToDeath(npc.index);
		return;
	}

	if(npc.m_flNextThinkTime > gameTime)
		return;

	if(npc.m_blPlayHurtAnimation)
	{
		npc.AddGesture("ACT_MP_GESTURE_FLINCH_CHEST", false);
		npc.PlayHurtSound();
		npc.m_blPlayHurtAnimation = false;
	}
	
	npc.m_flNextThinkTime = gameTime + 0.05;

	if(IsEntityAlive(EntRefToEntIndex(RaidBossActive)) && RaidBossActive != EntIndexToEntRef(npc.index))
	{
		for(int EnemyLoop; EnemyLoop <= MaxClients; EnemyLoop++)
		{
			if(IsValidClient(EnemyLoop))
			{
				Calculate_And_Display_hp(EnemyLoop, npc.index, 0.0, false);	
			}	
		}
	}
	else if(EntRefToEntIndex(RaidBossActive) != npc.index && !IsEntityAlive(EntRefToEntIndex(RaidBossActive)))
	{	
		RaidBossActive = EntIndexToEntRef(npc.index);
	}
	
	if(npc.m_flGetClosestTargetTime < gameTime || !IsValidEnemy(npc.index, npc.m_iTarget))
	{
		npc.m_iTarget = GetClosestTarget(npc.index);
		npc.m_flGetClosestTargetTime = gameTime + 1.0;
	}

	if(npc.m_flTimeTillSelfExplode)
	{
		float NpcLoc[3];
		GetEntPropVector(npc.index, Prop_Data, "m_vecAbsOrigin", NpcLoc);
		
		// MASSIVE range - 500 units
		spawnRing_Vectors(NpcLoc, 500.0 * 2.0, 0.0, 0.0, 5.0, "materials/sprites/laserbeam.vmt", 20, 50, 200, 200, 1, 0.3, 5.0, 8.0, 3);	
		spawnRing_Vectors(NpcLoc, 500.0 * 2.0, 0.0, 0.0, 25.0, "materials/sprites/laserbeam.vmt", 20, 50, 200, 200, 1, 0.3, 5.0, 8.0, 3);	
		
		if(npc.m_flTimeTillSelfExplode < gameTime)
		{
			npc.m_flTimeTillSelfExplode = 0.0;
			SpawnSmallExplosionNotRandom(NpcLoc);
			npc.PlayExplodeSound();
			
			float damageDealt = 1500.0;
			Explode_Logic_Custom(damageDealt, 0, npc.index, -1, _, 500.0, 1.0, _, true, 20);
			npc.m_flTimeTillAllowAction = gameTime + 1.2;
			
			if(npc.m_iChanged_WalkCycle != 9)
			{
				npc.m_bisWalking = false;
				npc.m_iChanged_WalkCycle = 9;
				npc.AddActivityViaSequence("Crouch_to_stand");
				npc.SetPlaybackRate(0.0);	
				npc.StopPathing();
			}
		}
		return;
	}
	
	if(npc.m_flTimeTillAllowAction)
	{
		if(npc.m_flTimeTillAllowAction < gameTime)
		{
			npc.m_flTimeTillAllowAction = 0.0;
		}
		return;
	}

	if(npc.m_flGrandExpertAngerResistance && GEF_CloneAbility(npc, gameTime))
		return;

	if(npc.m_flAttackHappens)
	{
		if(npc.m_flAttackHappens < gameTime)
		{
			npc.m_flAttackHappens = 0.0;
			
			if(IsValidEnemy(npc.index, npc.m_iTarget))
			{
				Handle swingTrace;
				float WorldSpaceCenterVec[3]; 
				WorldSpaceCenter(npc.m_iTarget, WorldSpaceCenterVec);
				npc.FaceTowards(WorldSpaceCenterVec, 20000.0);
				
				if(npc.DoSwingTrace(swingTrace, npc.m_iTarget))
				{
					int target = TR_GetEntityIndex(swingTrace);	
					
					float vecHit[3];
					TR_GetEndPosition(vecHit, swingTrace);
					float damage = 80000.0;
					
					if(target > 0) 
					{
						SDKHooks_TakeDamage(target, npc.index, npc.index, damage, DMG_CLUB);
						Elemental_AddChaosDamage(target, npc.index, 150, true, true);
						npc.PlayMeleeHitSound();
					}
				}
				delete swingTrace;
			}
		}
	}

	if(IsValidEnemy(npc.index, npc.m_iTarget))
	{
		float vecTarget[3];
		WorldSpaceCenter(npc.m_iTarget, vecTarget);
		float vecSelf[3];
		WorldSpaceCenter(npc.index, vecSelf);

		float flDistanceToTarget = GetVectorDistance(vecTarget, vecSelf, true);
			
		if(flDistanceToTarget < npc.GetLeadRadius()) 
		{
			float vPredictedPos[3]; 
			PredictSubjectPosition(npc, npc.m_iTarget, _, _, vPredictedPos);
			npc.SetGoalVector(vPredictedPos);
		}
		else
		{
			npc.SetGoalEntity(npc.m_iTarget);
		}

		if(npc.m_flDoingAnimation > gameTime)
		{
			npc.m_iState = -1;
		}
		else if(flDistanceToTarget < (NORMAL_ENEMY_MELEE_RANGE_FLOAT_SQUARED * 4.0))
		{
			if(npc.m_flTimeTillSelfExplodeCD < gameTime)
			{
				npc.PlayChargeExplode();
				npc.m_flTimeTillSelfExplode = gameTime + 1.5;
				npc.m_flTimeTillSelfExplodeCD = gameTime + 20.0;
				
				if(npc.m_iChanged_WalkCycle != 8)
				{
					npc.m_bisWalking = false;
					npc.m_iChanged_WalkCycle = 8;
					npc.AddActivityViaSequence("Stand_to_crouch");
					npc.SetPlaybackRate(0.0);	
					npc.StopPathing();
				}
				
				CPrintToChatAll("{blue}Experimented W.F. Elite{default}: Witness his failures come to life.");
				npc.m_iState = -1;
			}
			else if(flDistanceToTarget < NORMAL_ENEMY_MELEE_RANGE_FLOAT_SQUARED && npc.m_flNextMeleeAttack < gameTime)
			{
				npc.m_iState = 1;
			}
			else
			{
				npc.m_iState = 0;
			}
		}
		else 
		{
			npc.m_iState = 0;
		}
		
		switch(npc.m_iState)
		{
			case -1:
			{
				return;
			}
			case 0:
			{
				if(!npc.m_bPathing)
					npc.StartPathing();
					
				if(npc.m_iChanged_WalkCycle != 4) 	
				{
					npc.m_bisWalking = true;
					npc.m_iChanged_WalkCycle = 4;
					npc.SetActivity("ACT_BRAWLER_RUN");
				}
			}
			case 1:
			{			
				int Enemy_I_See = Can_I_See_Enemy(npc.index, npc.m_iTarget);
				
				if(IsValidEntity(Enemy_I_See) && IsValidEnemy(npc.index, Enemy_I_See))
				{
					npc.m_iTarget = Enemy_I_See;

					switch(GetRandomInt(0, 1))
					{
						case 0:
							npc.AddGesture("ACT_BRAWLER_ATTACK_LEFT");
						case 1:
							npc.AddGesture("ACT_BRAWLER_ATTACK_RIGHT");
					}

					npc.PlayMeleeSound();
					
					npc.m_flAttackHappens = gameTime + 0.2;
					npc.m_flDoingAnimation = gameTime + 0.2;
					npc.m_flNextMeleeAttack = gameTime + 0.45;
					npc.m_bisWalking = true;
				}
			}	
		}
	}
	else
	{
		npc.m_flGetClosestTargetTime = 0.0;
		npc.m_iTarget = GetClosestTarget(npc.index);
	}
	
	npc.PlayIdleSound();
}

public Action RaidbossGrandExpertFighter_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if(attacker < 1)
		return Plugin_Continue;

	RaidbossGrandExpertFighter npc = view_as<RaidbossGrandExpertFighter>(victim);

	float gameTime = GetGameTime(npc.index);
	if(npc.m_flHeadshotCooldown < gameTime)
	{
		npc.m_flHeadshotCooldown = gameTime + DEFAULT_HURTDELAY;
		npc.m_blPlayHurtAnimation = true;
	}
	
	if(!npc.m_flGrandExpertAngerResistance)
	{
		if((ReturnEntityMaxHealth(npc.index)/2) >= GetEntProp(npc.index, Prop_Data, "m_iHealth"))
		{
			npc.m_flGrandExpertAngerResistance = 1.0;
			ApplyStatusEffect(npc.index, npc.index, "Very Defensive Backup", 30.0);
			ApplyStatusEffect(npc.index, npc.index, "Expidonsan Anger", 5.0);
			CPrintToChatAll("{blue}Experimented W.F. Elite{default}: Enough!");
			npc.DispatchParticleEffect(npc.index, "hightower_explosion", NULL_VECTOR, NULL_VECTOR, NULL_VECTOR, npc.FindAttachment("eyes"), PATTACH_POINT_FOLLOW, true);
			
			npc.m_flSpeed = 380.0;

			// Unlock the Outlander laser ability — first use after 3 seconds
			npc.m_flOutlanderLaserCooldown = GetGameTime(npc.index) + 3.0;

			// Unlock the clone ability — first use after 8 seconds
			npc.m_flCloneAbilityCooldown = GetGameTime(npc.index) + 8.0;
		}
	}

	return Plugin_Changed;
}

public void RaidbossGrandExpertFighter_NPCDeath(int entity)
{
	Waves_ClearWave();

	RaidbossGrandExpertFighter npc = view_as<RaidbossGrandExpertFighter>(entity);
	
	float WorldSpaceVec[3]; 
	WorldSpaceCenter(npc.index, WorldSpaceVec);
		
	TE_Particle("pyro_blast", WorldSpaceVec, NULL_VECTOR, NULL_VECTOR, -1);
	TE_Particle("pyro_blast_lines", WorldSpaceVec, NULL_VECTOR, NULL_VECTOR, -1);
	TE_Particle("pyro_blast_warp", WorldSpaceVec, NULL_VECTOR, NULL_VECTOR, -1);
	TE_Particle("pyro_blast_flash", WorldSpaceVec, NULL_VECTOR, NULL_VECTOR, -1);
	EmitCustomToAll("zombiesurvival/internius/blinkarrival.wav", npc.index, SNDCHAN_STATIC, RAIDBOSS_ZOMBIE_SOUNDLEVEL, _, BOSS_ZOMBIE_VOLUME * 2.0);
	
	Format(WhatDifficultySetting, sizeof(WhatDifficultySetting), "%s", WhatDifficultySetting_Internal);
	WavesUpdateDifficultyName();
	
	if(i_RaidGrantExtra[npc.index] == 1 && GameRules_GetRoundState() == RoundState_ZombieRiot)
	{
		CPrintToChatAll("{blue}Experimented W.F. Elite{default}: ....Thank... You...");
		
		for(int client = 1; client <= MaxClients; client++)
		{
			if(IsValidClient(client) && GetClientTeam(client) == 2 && TeutonType[client] != TEUTON_WAITING && PlayerPoints[client] > 500)
			{
				Items_GiveNamedItem(client, "Tiny Flower..?");
				CPrintToChat(client, "{default}You've defeated the Grand Expert Fighter! He dropped a...{crimson}''Tiny Flower..?''{default}..");
			}
		}
		
		for(int i; i < i_MaxcountNpcTotal; i++)
		{
			int entitynpc = EntRefToEntIndexFast(i_ObjectsNpcsTotal[i]);
			if(IsValidEntity(entitynpc) && entitynpc != INVALID_ENT_REFERENCE && IsEntityAlive(entitynpc) && GetTeam(npc.index) == GetTeam(entitynpc))
			{
				SmiteNpcToDeath(entitynpc);
			}
		}
		Waves_ClearWaves();
	}
	
	if(!npc.m_bGib)
		npc.PlayDeathSound();

	if(IsValidEntity(npc.m_iWearable1))
		RemoveEntity(npc.m_iWearable1);
	
	if(IsValidEntity(npc.m_iWearable2))
		RemoveEntity(npc.m_iWearable2);

	if(IsValidEntity(npc.m_iWearable3))
		RemoveEntity(npc.m_iWearable3);

	if(IsValidEntity(npc.m_iWearable4))
		RemoveEntity(npc.m_iWearable4);

	if(IsValidEntity(npc.m_iWearable5))
		RemoveEntity(npc.m_iWearable5);

	RaidBossActive = INVALID_ENT_REFERENCE;
	fl_GEF_CloneLifespan[entity] = 0.0;
}



#define GEF_ZONE_RANGE         850.0
#define GEF_ZONE_DAMAGE        (120.0)   // flat — no RaidModeScaling here since GEF uses flat damage

static int GEF_ZoneInsideCheck[MAXENTITIES];

float GEF_ZoneCheck_Callback(int entity, int victim, float damage, int weapon)
{
	GEF_ZoneInsideCheck[victim] = true;
	return damage;
}

bool GEF_RockZoneAbility(RaidbossGrandExpertFighter npc, float gameTime)
{
	// ---- Phase 2: detonation fires ----
	if(npc.m_flZoneAbilityHappening)
	{
		float pos[3];
		GetEntPropVector(npc.index, Prop_Data, "m_vecAbsOrigin", pos);

		// Throttled ring visuals while waiting for detonation
		if(npc.m_flGEFEffectThrottle < gameTime)
		{
			spawnRing_Vectors(pos, GEF_ZONE_RANGE * 2.0, 0.0, 0.0, 5.0,  "materials/sprites/laserbeam.vmt", 20, 50, 200, 220, 1, 0.3, 5.0, 8.0, 3);
			spawnRing_Vectors(pos, GEF_ZONE_RANGE * 2.0, 0.0, 0.0, 25.0, "materials/sprites/laserbeam.vmt", 20, 50, 200, 220, 1, 0.3, 5.0, 8.0, 3);
			spawnRing_Vectors(pos, GEF_ZONE_RANGE * 10.0, 0.0, 0.0, 5.0,  "materials/sprites/laserbeam.vmt", 20, 50, 200, 180, 1, 0.3, 5.0, 8.0, 3, GEF_ZONE_RANGE * 2.0);
			spawnRing_Vectors(pos, GEF_ZONE_RANGE * 10.0, 0.0, 0.0, 25.0, "materials/sprites/laserbeam.vmt", 20, 50, 200, 180, 1, 0.3, 5.0, 8.0, 3, GEF_ZONE_RANGE * 2.0);
			npc.m_flGEFEffectThrottle = gameTime + 0.25;
		}

		if(npc.m_flZoneAbilityHappening < gameTime)
		{
			// Detonation: detect who's in range
			Zero(GEF_ZoneInsideCheck);
			float detPos[3];
			GetEntPropVector(npc.index, Prop_Data, "m_vecAbsOrigin", detPos);
			detPos[2] += 60.0;
			Explode_Logic_Custom(1.0, 0, npc.index, -1, detPos, GEF_ZONE_RANGE, 1.0, _, false, 99, _, _, _, GEF_ZoneCheck_Callback);

			npc.PlayZoneCastSound();

			static float victimPos[3];
			static float bossPos[3];
			GetEntPropVector(npc.index, Prop_Send, "m_vecOrigin", bossPos);

			for(int victim = 1; victim < MAXENTITIES; victim++)
			{
				if(!IsValidEnemy(npc.index, victim, true))
					continue;

				GetEntPropVector(victim, Prop_Send, "m_vecOrigin", victimPos);

				if(!GEF_ZoneInsideCheck[victim])
				{
					// OUTSIDE the zone — slam upward + heavy damage
					if(b_ThisWasAnNpc[victim])
						PluginBot_Jump(victim, {0.0, 0.0, 1200.0});
					else
						TeleportEntity(victim, NULL_VECTOR, NULL_VECTOR, {0.0, 0.0, 1200.0});

					SDKHooks_TakeDamage(victim, npc.index, npc.index, GEF_ZONE_DAMAGE * 1.8, DMG_PLASMA, -1, NULL_VECTOR, victimPos);
					Elemental_AddChaosDamage(victim, npc.index, 120, true, true);
				}
				else
				{
					// INSIDE the zone — pulled toward the boss + Teslar + heavy knockback inward
					ApplyStatusEffect(npc.index, victim, "Teslar Shock", 5.0);
					Elemental_AddChaosDamage(victim, npc.index, 80, true, true);

					if(!b_ThisWasAnNpc[victim])
					{
						static float angles[3];
						GetVectorAnglesTwoPoints(victimPos, bossPos, angles);
						if(GetEntityFlags(victim) & FL_ONGROUND)
							angles[0] = 0.0;

						static float velocity[3];
						GetAngleVectors(angles, velocity, NULL_VECTOR, NULL_VECTOR);
						float pullStrength = 1800.0;
						ScaleVector(velocity, pullStrength);
						velocity[0] *= -1.0;
						velocity[1] *= -1.0;
						velocity[2] = (GetEntityFlags(victim) & FL_ONGROUND) ? 400.0 : 250.0;

						TeleportEntity(victim, NULL_VECTOR, NULL_VECTOR, velocity);
					}
				}
			}

			TE_Particle("hammer_bell_ring_shockwave2", detPos, NULL_VECTOR, NULL_VECTOR, _, _, _, _, _, _, _, _, _, _, 0.0);
			CreateEarthquake(detPos, 1.0, 1500.0, 14.0, 120.0);
			npc.m_flZoneAbilityHappening = 0.0;

			// Resume movement
			npc.m_bisWalking = true;
			npc.StartPathing();
			npc.m_iChanged_WalkCycle = -1;
			npc.m_flSpeed = npc.m_flGrandExpertAngerResistance ? 380.0 : 330.0;

			float cd = npc.m_flGrandExpertAngerResistance ? 28.0 : 45.0;
			npc.m_flZoneAbilityCooldown = gameTime + cd;
		}
		return true;
	}

	if(npc.m_flZoneAbilityCooldown > gameTime)
		return false;

	npc.m_bisWalking = false;
	npc.m_iChanged_WalkCycle = 8;
	npc.AddActivityViaSequence("Stand_to_crouch");
	npc.SetPlaybackRate(0.5);
	npc.StopPathing();
	npc.m_flSpeed = 0.0;

	// Annotation warning visible in world
	float pos[3];
	GetEntPropVector(npc.index, Prop_Data, "m_vecAbsOrigin", pos);
	Event event = CreateEvent("show_annotation");
	if(event)
	{
		event.SetFloat("worldPosX", pos[0]);
		event.SetFloat("worldPosY", pos[1]);
		event.SetFloat("worldPosZ", pos[2]);
		event.SetFloat("lifetime", 4.5);
		event.SetString("text", "STAY IN ZONE!!");
		event.SetString("play_sound", "vo/null.mp3");
		event.SetInt("id", 999978);
		event.Fire();
	}

	pos[2] += 5.0;
	float ang_Look[3];
	float DelayPillars     = 3.8;   // slightly faster "incoming" than Vhxis (4.5)
	float DelayBetween     = 0.15;  // denser than Vhxis (0.25)
	int   MaxRocks         = 8;     // more rocks per rotation than Vhxis (6)

	ResetTEStatusSilvester();
	SetSilvesterPillarColour({20, 50, 200, 220}); // dark blue
	for(int Repeat = 0; Repeat <= 20; Repeat++)
	{
		Silvester_Damaging_Pillars_Ability(
			npc.index,
			30.0,          // damage per pillar — tuned for GEF
			MaxRocks,
			DelayPillars,
			DelayBetween,
			ang_Look,
			pos,
			0.25,
			1.25);
		ang_Look[1] += 18.0; // tighter rotation step than Vhxis (22.5)
	}

	npc.PlayZoneChargeSound();

	float flPos[3], flAng[3];
	npc.GetAttachment("weapon_bone", flPos, flAng);
	if(IsValidEntity(npc.m_iWearable3))
		RemoveEntity(npc.m_iWearable3);
	npc.m_iWearable3 = ParticleEffectAt_Parent(flPos, "flaregun_energyfield_blue", npc.index, "weapon_bone", {0.0, 0.0, 0.0});

	npc.m_flZoneAbilityHappening = gameTime + 3.5;
	npc.m_flDoingAnimation       = gameTime + 5.0;
	npc.m_flGEFEffectThrottle    = 0.0;
	npc.m_flZoneAbilityCooldown  = FAR_FUTURE; // reset after detonation

	switch(GetRandomInt(0, 2))
	{
		case 0: CPrintToChatAll("{blue}Experimented W.F. Elite{default}: Let's see handle this!");
		case 1: CPrintToChatAll("{blue}Experimented W.F. Elite{default}: WHERE DO YOU THINK YOU'RE GOING?!");
		case 2: CPrintToChatAll("{blue}Experimented W.F. Elite{default}: Not on my watch.");
	}

	return true;
}




bool GEF_OutlanderLaserAbility(RaidbossGrandExpertFighter npc, float gameTime)
{
	if(npc.m_flOutlanderLaserHappening)
	{
		if(npc.m_flOutlanderLaserHappening < gameTime)
		{
			npc.m_flOutlanderLaserHappening = 0.0;

			if(IsValidEnemy(npc.index, npc.m_iTarget))
			{
				float handPos[3], handAng[3];
				npc.GetAttachment("weapon_bone", handPos, handAng);

				float vecEnemy[3];
				WorldSpaceCenter(npc.m_iTarget, vecEnemy);
				npc.FaceTowards(vecEnemy, 20000.0);

				// Two beams: one at enemy, one slightly offset for visual flair
				GEF_FireLaser(npc.index, vecEnemy, handPos);
				vecEnemy[0] += GetRandomFloat(-80.0, 80.0);
				vecEnemy[1] += GetRandomFloat(-80.0, 80.0);
				GEF_FireLaser(npc.index, vecEnemy, handPos);

				npc.PlayLaserFireSound();
				npc.AddGesture("ACT_BRAWLER_ATTACK_RIGHT");
			}

			// Resume
			npc.m_bisWalking = true;
			npc.m_iChanged_WalkCycle = -1;
			npc.m_flSpeed = 380.0;
			npc.StartPathing();
			npc.m_flOutlanderLaserCooldown = gameTime + 18.0;
		}
		return true;
	}

	if(npc.m_flOutlanderLaserCooldown > gameTime)
		return false;

	if(!IsValidEnemy(npc.index, npc.m_iTarget))
		return false;

	// Wind up
	npc.m_flOutlanderLaserHappening = gameTime + 1.2;
	npc.m_flOutlanderLaserCooldown  = FAR_FUTURE;
	npc.m_flDoingAnimation          = gameTime + 1.5;

	npc.m_bisWalking       = false;
	npc.m_iChanged_WalkCycle = 8;
	npc.AddActivityViaSequence("Stand_to_crouch");
	npc.SetPlaybackRate(0.75);
	npc.StopPathing();
	npc.m_flSpeed = 0.0;

	npc.PlayLaserWindupSound();

	switch(GetRandomInt(0, 2))
	{
		case 0: CPrintToChatAll("{blue}Experimented W.F. Elite{default}: EAT THIS!");
		case 1: CPrintToChatAll("{blue}Experimented W.F. Elite{default}: Let me show you what REAL power looks like!");
		case 2: CPrintToChatAll("{blue}Experimented W.F. Elite{default}: Tch! Time to end this.");
	}

	return true;
}



static bool GEF_Laser_TraceWallsOnly(int entity, int contentsMask)
{
	return !entity;
}

static bool GEF_Laser_TraceUsers(int entity, int contentsMask, int client)
{
	if(IsEntityAlive(entity))
		LaserVarious_HitDetection[entity] = true;
	return false;
}

void GEF_FireLaser_DamagePart(DataPack pack)
{
	for(int i = 1; i < MAXENTITIES; i++)
		LaserVarious_HitDetection[i] = false;

	pack.Reset();
	int entity = EntRefToEntIndex(pack.ReadCell());
	if(!IsValidEntity(entity)) entity = 0;

	float VectorTarget[3], VectorStart[3];
	VectorTarget[0] = pack.ReadFloat();
	VectorTarget[1] = pack.ReadFloat();
	VectorTarget[2] = pack.ReadFloat();
	VectorStart[0]  = pack.ReadFloat();
	VectorStart[1]  = pack.ReadFloat();
	VectorStart[2]  = pack.ReadFloat();

	int colorLayer4[4];
	float diameter = 30.0;
	SetColorRGBA(colorLayer4, 20, 50, 200, 100);
	int colorLayer1[4];
	SetColorRGBA(colorLayer1, colorLayer4[0] * 5 + 765 / 8, colorLayer4[1] * 5 + 765 / 8, colorLayer4[2] * 5 + 765 / 8, 100);
	TE_SetupBeamPoints(VectorStart, VectorTarget, Shared_BEAM_Laser, 0, 0, 0, 0.11, ClampBeamWidth(diameter * 0.2), ClampBeamWidth(diameter * 0.35), 0, 5.0, colorLayer1, 3);
	TE_SendToAll(0.0);
	TE_SetupBeamPoints(VectorStart, VectorTarget, Shared_BEAM_Laser, 0, 0, 0, 0.11, ClampBeamWidth(diameter * 0.2), ClampBeamWidth(diameter * 0.25), 0, 5.0, colorLayer1, 3);
	TE_SendToAll(0.0);

	float hullMin[3] = {-10.0, -10.0, -10.0};
	float hullMax[3] = { 10.0,  10.0,  10.0};

	Handle trace = TR_TraceHullFilterEx(VectorStart, VectorTarget, hullMin, hullMax, 1073741824, GEF_Laser_TraceUsers, entity);
	delete trace;

	// Reduced damage: 250 flat (vs Outlander's 800-850)
	float CloseDamage = 250.0;
	float FarDamage   = 275.0;
	float MaxDistance = 1000.0;
	float playerPos[3];
	for(int victim = 1; victim < MAXENTITIES; victim++)
	{
		if(LaserVarious_HitDetection[victim] && GetTeam(entity) != GetTeam(victim))
		{
			GetEntPropVector(victim, Prop_Send, "m_vecOrigin", playerPos, 0);
			float distance = GetVectorDistance(VectorStart, playerPos, false);
			float damage   = CloseDamage + (FarDamage - CloseDamage) * (distance / MaxDistance);
			if(damage < 0.0) damage *= -1.0;
			SDKHooks_TakeDamage(victim, entity, entity, damage, DMG_PLASMA, -1, NULL_VECTOR, playerPos);
			Elemental_AddChaosDamage(victim, entity, 100, true, true);
		}
	}
	delete pack;
}

void GEF_FireLaser(int entity, float VectorTarget[3], float VectorStart[3])
{
	float vecForward[3], Angles[3];
	MakeVectorFromPoints(VectorStart, VectorTarget, vecForward);
	GetVectorAngles(vecForward, Angles);

	Handle trace = TR_TraceRayFilterEx(VectorStart, Angles, 11, RayType_Infinite, GEF_Laser_TraceWallsOnly);
	if(TR_DidHit(trace))
	{
		TR_GetEndPosition(VectorTarget, trace);
		float lineReduce = 10.0 * 2.0 / 3.0;
		float curDist    = GetVectorDistance(VectorStart, VectorTarget, false);
		if(curDist > lineReduce)
			ConformLineDistance(VectorTarget, VectorStart, VectorTarget, curDist - lineReduce);
	}
	delete trace;

	// Previsualization beam
	int colorLayer4[4];
	float diameter = float(10 * 4);
	SetColorRGBA(colorLayer4, 20, 50, 200, 150);
	int colorLayer1[4];
	SetColorRGBA(colorLayer1, colorLayer4[0] * 5 + 765 / 8, colorLayer4[1] * 5 + 765 / 8, colorLayer4[2] * 5 + 765 / 8, 100);
	TE_SetupBeamPoints(VectorStart, VectorTarget, Shared_BEAM_Laser, 0, 0, 0, 0.6, ClampBeamWidth(diameter * 0.1), ClampBeamWidth(diameter * 0.3), 0, 5.0, colorLayer1, 3);
	TE_SendToAll(0.0);
	int glowColor[4];
	SetColorRGBA(glowColor, 20, 50, 200, 100);
	TE_SetupBeamPoints(VectorStart, VectorTarget, Shared_BEAM_Glow, 0, 0, 0, 0.7, ClampBeamWidth(diameter * 0.1), ClampBeamWidth(diameter * 0.1), 0, 0.5, glowColor, 0);
	TE_SendToAll(0.0);

	DataPack pack = new DataPack();
	pack.WriteCell(EntIndexToEntRef(entity));
	pack.WriteFloat(VectorTarget[0]);
	pack.WriteFloat(VectorTarget[1]);
	pack.WriteFloat(VectorTarget[2]);
	pack.WriteFloat(VectorStart[0]);
	pack.WriteFloat(VectorStart[1]);
	pack.WriteFloat(VectorStart[2]);
	RequestFrames(GEF_FireLaser_DamagePart, 40, pack);
}


bool GEF_CloneAbility(RaidbossGrandExpertFighter npc, float gameTime)
{
	if(npc.m_flCloneAbilityCooldown > gameTime)
		return false;

	if(!IsValidEnemy(npc.index, npc.m_iTarget))
		return false;

	npc.m_bisWalking       = false;
	npc.m_iChanged_WalkCycle = 8;
	npc.AddActivityViaSequence("Stand_to_crouch");
	npc.SetPlaybackRate(0.5);
	npc.StopPathing();
	npc.m_flSpeed = 0.0;
	npc.m_flDoingAnimation = gameTime + 0.9;

	// Visual flash at GEF's position
	float pos[3]; GetEntPropVector(npc.index, Prop_Data, "m_vecAbsOrigin", pos);
	ParticleEffectAt(pos, "teleported_blue", 0.6);
	EmitSoundToAll(g_ZoneChargeSound[GetRandomInt(0, sizeof(g_ZoneChargeSound)-1)],
		npc.index, SNDCHAN_STATIC, BOSS_ZOMBIE_SOUNDLEVEL, _, BOSS_ZOMBIE_VOLUME);

	GEF_SpawnClones(npc);

	// Set next CD — shorter on repeat uses
	npc.m_flCloneAbilityCooldown = gameTime + 35.0;

	// Resume movement after the brief pause
	DataPack pk = new DataPack();
	pk.WriteCell(EntIndexToEntRef(npc.index));
	CreateDataTimer(0.9, GEF_Clone_ResumeMovement, pk, TIMER_FLAG_NO_MAPCHANGE);

	switch(GetRandomInt(0, 2))
	{
		case 0: CPrintToChatAll("{blue}Experimented W.F. Elite{default}: Can you even tell which one is real?");
		case 1: CPrintToChatAll("{blue}Experimented W.F. Elite{default}: ALL of them are me!");
		case 2: CPrintToChatAll("{blue}Experimented W.F. Elite{default}: Deal with ALL of us.");
	}

	return true;
}

public Action GEF_Clone_ResumeMovement(Handle timer, DataPack pack)
{
	pack.Reset();
	int entity = EntRefToEntIndex(pack.ReadCell());
	delete pack;
	if(!IsValidEntity(entity)) return Plugin_Stop;

	RaidbossGrandExpertFighter npc = view_as<RaidbossGrandExpertFighter>(entity);
	npc.m_bisWalking       = true;
	npc.m_iChanged_WalkCycle = -1;
	npc.m_flSpeed = 380.0;
	npc.StartPathing();
	return Plugin_Stop;
}

void GEF_SpawnClones(RaidbossGrandExpertFighter npc)
{
	float bossPos[3]; GetEntPropVector(npc.index, Prop_Data, "m_vecAbsOrigin", bossPos);
	float bossAng[3]; GetEntPropVector(npc.index, Prop_Data, "m_angRotation",  bossAng);

	static float hullMaxs[3]; hullMaxs = view_as<float>({24.0, 24.0, 82.0});
	static float hullMins[3]; hullMins = view_as<float>({-24.0,-24.0,  0.0});

	int clonesSpawned = 0;
	int attempts      = 0;

	while(clonesSpawned < 2 && attempts < 8)
	{
		attempts++;

		// Pick a random scatter position ±250–350 HU away from GEF
		float scatterPos[3];
		float angle = GetRandomFloat(0.0, 360.0);
		float dist  = GetRandomFloat(250.0, 350.0);
		scatterPos[0] = bossPos[0] + Cosine(DegToRad(angle)) * dist;
		scatterPos[1] = bossPos[1] + Sine  (DegToRad(angle)) * dist;
		scatterPos[2] = bossPos[2];

		// Only spawn if the location is reachable (no wall in the way)
		if(!Npc_Teleport_Safe(-1, scatterPos, hullMins, hullMaxs, false, false))
			continue;

		int clone = NPC_CreateById(GEF_NPCId, -1, scatterPos, bossAng, GetTeam(npc.index), "gef_clone");
		if(!IsValidEntity(clone))
			continue;

		// Set clone HP to 1/3 of the real boss's current max HP
		int cloneHP = ReturnEntityMaxHealth(npc.index) / 3;
		SetEntProp(clone, Prop_Data, "m_iHealth",    cloneHP);
		SetEntProp(clone, Prop_Data, "m_iMaxHealth", cloneHP);

		// Inherit scaling so the clone's melee/explosion damage matches the fight
		NpcStats_CopyStats(npc.index, clone);
		NpcAddedToZombiesLeftCurrently(clone, false); // don't count toward wave clear

		// Set the 14-second lifespan
		fl_GEF_CloneLifespan[clone] = GetGameTime() + 14.0;

		ParticleEffectAt(scatterPos, "teleported_blue", 0.5);
		clonesSpawned++;
	}
}
