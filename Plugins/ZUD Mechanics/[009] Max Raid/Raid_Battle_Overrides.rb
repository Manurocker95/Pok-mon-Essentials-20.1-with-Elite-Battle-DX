#===============================================================================
# Changes to the Battle::Battler class specifically used for Max Raid battles.
#===============================================================================
class Battle::Battler
  #-----------------------------------------------------------------------------
  # Aliased to allow Max Raid Pokemon to use Belch without consuming a berry.
  #-----------------------------------------------------------------------------
  alias zud_belched? belched?
  def belched?
    return true if @effects[PBEffects::MaxRaidBoss]
    return zud_belched?
  end
  
  #-----------------------------------------------------------------------------
  # Aliased to allow Max Raid Pokemon to strike multiple times per turn.
  #-----------------------------------------------------------------------------
  alias zud_pbProcessTurn pbProcessTurn
  def pbProcessTurn(choice, tryFlee = true)
    ret = zud_pbProcessTurn(choice, tryFlee)
    raid_UseBaseMoves(choice) if ret && @battle.decision == 0
    return ret
  end
  
  #-----------------------------------------------------------------------------
  # Aliased to add special Max Raid effects that trigger after move usage.
  #-----------------------------------------------------------------------------
  alias zud_pbEffectsAfterMove pbEffectsAfterMove
  def pbEffectsAfterMove(user, targets, move, numHits)
    zud_pbEffectsAfterMove(user, targets, move, numHits)
    if @battle.raid_battle && move.damagingMove?
      #-------------------------------------------------------------------------
      # Hard Mode Bonuses (Malicious Wave)
      #-------------------------------------------------------------------------
      if @battle.hard_mode
        if user.effects[PBEffects::MaxRaidBoss] &&
           user.effects[PBEffects::RaidShield] <= 0 &&
           user.effects[PBEffects::KnockOutCount] > 0 &&
           !user.effects[PBEffects::TwoTurnAttack]
            showMsg = true
            @battle.eachOtherSideBattler(user) do |b|
            break if @battle.pbAllFainted?(b.index) || @battle.decision == 3
            damage = b.real_totalhp / 16 if user.effects[PBEffects::ShieldCounter] >= 1
            damage = b.real_totalhp / 8  if user.effects[PBEffects::ShieldCounter] <= 0
            oldhp  = b.hp
            if b.hp > 0 && !b.fainted?
              if showMsg
                @battle.pbDisplay(_INTL("A malicious wave of Dynamax energy rippled from {1}'s attack!", user.pbThis(true)))
                @battle.scene.pbWaveAttack(user.index)
              end
            end
            showMsg = false
            @battle.scene.pbDamageAnimation(b)
            b.hp -= damage
            b.hp = 0 if b.hp < 0
            @battle.scene.pbHPChanged(b, oldhp)
            b.pbFaint if b.fainted?
          end
        end
      end
      #-------------------------------------------------------------------------
      # Effects triggered after moves used on a Max Raid Pokemon.
      #-------------------------------------------------------------------------
      targets.each do |b|
        next unless b.effects[PBEffects::MaxRaidBoss] &&
                    b.effects[PBEffects::KnockOutCount] > 0
        next if b.damageState.calcDamage == 0 || b.damageState.unaffected
        #-----------------------------------------------------------------------
        # Initiates Max Raid capture sequence if brought down to 0 HP.
        #-----------------------------------------------------------------------
        if b.hp <= 0
          b.effects[PBEffects::RaidShield] = 0
          @battle.scene.pbRefresh
          b.pbFaint if b.fainted?
          return
        #-----------------------------------------------------------------------
        # Max Raid Pokemon loses shields.
        #-----------------------------------------------------------------------
        elsif b.effects[PBEffects::RaidShield] > 0
          shield_break = (move.powerMove?) ? 2 : 1
          if $DEBUG && Input.press?(Input::CTRL) # Instantly breaks shield.
            shield_break = b.effects[PBEffects::RaidShield]
          end
          b.effects[PBEffects::RaidShield] -= shield_break
          @battle.scene.pbRefresh
          if b.effects[PBEffects::RaidShield] <= 0
            b.effects[PBEffects::RaidShield] = 0
            @battle.scene.pbRaidShield(b)
            @battle.pbDisplay(_INTL("The mysterious barrier disappeared!"))
            oldhp = b.hp
            b.hp -= b.totalhp / 8
            b.hp  = 1 if b.hp <= 1
            @battle.scene.pbHPChanged(b, oldhp)
            if b.hp > 1
              [:DEFENSE, :SPECIAL_DEFENSE].each do |stat|
                if b.pbCanLowerStatStage?(stat, b, nil, true)
                  b.pbLowerStatStage(stat, 2, b, true, false, 0, true)
                end
              end
            end
          end
        #-----------------------------------------------------------------------
        # Max Raid Pokemon gains shields.
        #-----------------------------------------------------------------------
        elsif b.effects[PBEffects::RaidShield] <= 0 && b.hp > 1
          shields1   = (b.hp <= b.totalhp / 2)             # Activates at 1/2 HP
          shields2   = (b.hp <= b.totalhp - b.totalhp / 5) # Activates at 4/5ths HP
          if (b.effects[PBEffects::ShieldCounter] == 1 && shields1) ||
             (b.effects[PBEffects::ShieldCounter] == 2 && shields2)
            @battle.pbDisplay(_INTL("{1} is getting desperate!\nIts attacks are growing more aggressive!", b.pbThis))
            b.effects[PBEffects::RaidShield] = b.effects[PBEffects::MaxShieldHP]
            b.effects[PBEffects::ShieldCounter] -= 1
            @battle.pbAnimation(:REFLECT, b, b)
            @battle.scene.pbRaidShield(b)
            @battle.scene.pbRefresh
            @battle.pbDisplay(_INTL("A mysterious barrier appeared in front of {1}!", b.pbThis(true)))
          end
        end
        #-----------------------------------------------------------------------
        # Hard Mode Bonuses (Invigorating Wave)
        #-----------------------------------------------------------------------
        if @battle.hard_mode && b.effects[PBEffects::ShieldCounter] == 0
          stat_stages = 0
          GameData::Stat.each_main_battle do |s|
            if b.pbCanRaiseStatStage?(s.id, b, nil, true)
              b.pbRaiseStatStageBasic(s.id, 1, true) 
              stat_stages += 1
            end
          end
          if stat_stages > 0
            b.stages[:ACCURACY] = 0  if b.stages[:ACCURACY] < 0
            b.stages[:EVASION]  = 0  if b.stages[:EVASION] < 0
            @battle.pbDisplay(_INTL("{1} released an invigorating wave of Dynamax energy!", b.pbThis))
            @battle.scene.pbWaveAttack(b.index)
            @battle.pbCommonAnimation("StatUp", b)
            @battle.pbDisplay(_INTL("{1} got powered up!", b.pbThis))
          end
          b.effects[PBEffects::ShieldCounter] -= 1
        end
      end
    end
  end
end


#===============================================================================
# Changes to the Battle::Move class specifically used for Max Raid battles.
#===============================================================================
class Battle::Move
  #-----------------------------------------------------------------------------
  # Aliased to set damage thresholds for triggering Max Raid shields.
  #-----------------------------------------------------------------------------
  alias zud_pbCalcDamage pbCalcDamage
  def pbCalcDamage(user, target, numTargets = 1)
    zud_pbCalcDamage(user, target, numTargets)
    if @battle.raid_battle && 
       target.effects[PBEffects::MaxRaidBoss] && 
       target.effects[PBEffects::ShieldCounter] > 0 &&
       target.damageState.calcDamage > 0
      case target.effects[PBEffects::ShieldCounter]
      when 1 then thresh = (target.totalhp / 2).floor
      when 2 then thresh = (target.totalhp / 5).floor
      end
      hpstop = target.totalhp - thresh
      damage = target.damageState.calcDamage
      if (target.hp > hpstop) && (damage > target.hp - hpstop)
        damage = target.hp - hpstop + 1
      elsif target.hp <= hpstop
        damage = 1
      end
      target.damageState.calcDamage = damage
    end
  end
  
  #-----------------------------------------------------------------------------
  # Aliased so Max Raid Pokemon take greatly reduced damage while shields are up.
  #-----------------------------------------------------------------------------
  alias zud_pbCalcDamageMultipliers pbCalcDamageMultipliers
  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    zud_pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    if target.effects[PBEffects::RaidShield] > 0
      multipliers[:final_damage_multiplier] /= 24
    end
  end
  
  #-----------------------------------------------------------------------------
  # Aliased for effect immunity for Max Raid Pokemon while shields are up.
  #-----------------------------------------------------------------------------
  alias zud_pbAdditionalEffectChance pbAdditionalEffectChance
  def pbAdditionalEffectChance(user, target, effectChance = 0)
    return 0 if target.effects[PBEffects::MaxRaidBoss] && target.effects[PBEffects::RaidShield] > 0
    return zud_pbAdditionalEffectChance(user, target, effectChance)
  end
end