class Battle::AI
  #=============================================================================
  # Immunity to a move because of the target's ability, item or other effects
  #=============================================================================
  # Adding Wind Rider and Earth Eater
  def pbCheckMoveImmunity(score, move, user, target, skill)
    type = pbRoughType(move, user, skill)
    typeMod = pbCalcTypeMod(type, user, target)
    # Type effectiveness
    return true if (move.damagingMove? && Effectiveness.ineffective?(typeMod)) || score <= 0
    # Immunity due to ability/item/other effects
    if skill >= PBTrainerAI.mediumSkill
      case type
      when :GROUND
        return true if target.airborne? && !move.hitsFlyingTargets?
        return true if target.hasActiveAbility?(:EARTHEATER)
      when :FIRE
        return true if target.hasActiveAbility?([:FLASHFIRE,:WELLBAKEDBODY])
      when :WATER
        return true if target.hasActiveAbility?([:DRYSKIN, :STORMDRAIN, :WATERABSORB])
      when :GRASS
        return true if target.hasActiveAbility?(:SAPSIPPER)
      when :ELECTRIC
        return true if target.hasActiveAbility?([:LIGHTNINGROD, :MOTORDRIVE, :VOLTABSORB])
      end
      return true if move.damagingMove? && Effectiveness.not_very_effective?(typeMod) &&
                     target.hasActiveAbility?(:WONDERGUARD)
      return true if move.damagingMove? && user.index != target.index && !target.opposes?(user) &&
                     target.hasActiveAbility?(:TELEPATHY)
      return true if move.statusMove? && move.canMagicCoat? && target.hasActiveAbility?(:MAGICBOUNCE) &&
                     target.opposes?(user)
      return true if move.soundMove? && target.hasActiveAbility?(:SOUNDPROOF)
      return true if move.bombMove? && target.hasActiveAbility?(:BULLETPROOF)
      if move.powderMove?
        return true if target.pbHasType?(:GRASS)
        return true if target.hasActiveAbility?(:OVERCOAT)
        return true if target.hasActiveItem?(:SAFETYGOGGLES)
      end
      return true if move.statusMove? && target.effects[PBEffects::Substitute] > 0 &&
                     !move.ignoresSubstitute?(user) && user.index != target.index
      return true if move.statusMove? && Settings::MECHANICS_GENERATION >= 7 &&
                     user.hasActiveAbility?(:PRANKSTER) && target.pbHasType?(:DARK) &&
                     target.opposes?(user)
      return true if move.priority > 0 && @battle.field.terrain == :Psychic &&
                     target.affectedByTerrain? && target.opposes?(user)
      return true if move.windMove? && target.hasActiveAbility?(:WINDRIDER)
      return true if move.statusMove? && target.hasActiveAbility?(:GOODASGOLD) && !user.hasActiveAbility?(:MYCELIUMMIGHT)
      return true if target.effects[PBEffects::CommanderTatsugiri]
    end
    return false
  end
  #=============================================================================
  # Damage calculation
  #=============================================================================
  def pbRoughDamage(move, user, target, skill, baseDmg)
    # Fixed damage moves
    return baseDmg if move.is_a?(Battle::Move::FixedDamageMove)
    # Get the move's type
    type = pbRoughType(move, user, skill)
    ##### Calculate user's attack stat #####
    atk = pbRoughStat(user, :ATTACK, skill)
    if move.function == "UseTargetAttackInsteadOfUserAttack"   # Foul Play
      atk = pbRoughStat(target, :ATTACK, skill)
    elsif move.function == "UseUserBaseDefenseInsteadOfUserBaseAttack"   # Body Press
      atk = pbRoughStat(user, :DEFENSE, skill)
    elsif move.specialMove?(type)
      if move.function == "UseTargetAttackInsteadOfUserAttack"   # Foul Play
        atk = pbRoughStat(target, :SPECIAL_ATTACK, skill)
      else
        atk = pbRoughStat(user, :SPECIAL_ATTACK, skill)
      end
    end
    ##### Calculate target's defense stat #####
    defense = pbRoughStat(target, :DEFENSE, skill)
    if move.specialMove?(type) && move.function != "UseTargetDefenseInsteadOfTargetSpDef"   # Psyshock
      defense = pbRoughStat(target, :SPECIAL_DEFENSE, skill)
    end
    ##### Calculate all multiplier effects #####
    multipliers = {
      :base_damage_multiplier  => 1.0,
      :attack_multiplier       => 1.0,
      :defense_multiplier      => 1.0,
      :final_damage_multiplier => 1.0
    }
    # Ability effects that alter damage
    moldBreaker = false
    if skill >= PBTrainerAI.highSkill && target.hasMoldBreaker?
      moldBreaker = true
    end
    if skill >= PBTrainerAI.mediumSkill && user.abilityActive?
      # NOTE: These abilities aren't suitable for checking at the start of the
      #       round.
      abilityBlacklist = [:ANALYTIC, :SNIPER, :TINTEDLENS, :AERILATE, :PIXILATE, :REFRIGERATE]
      canCheck = true
      abilityBlacklist.each do |m|
        next if move.id != m
        canCheck = false
        break
      end
      if canCheck
        Battle::AbilityEffects.triggerDamageCalcFromUser(
          user.ability, user, target, move, multipliers, baseDmg, type
        )
      end
    end
    if skill >= PBTrainerAI.mediumSkill && !moldBreaker
      user.allAllies.each do |b|
        next if !b.abilityActive?
        Battle::AbilityEffects.triggerDamageCalcFromAlly(
          b.ability, user, target, move, multipliers, baseDmg, type
        )
      end
    end
    if skill >= PBTrainerAI.bestSkill && !moldBreaker && target.abilityActive?
      # NOTE: These abilities aren't suitable for checking at the start of the
      #       round.
      abilityBlacklist = [:FILTER, :SOLIDROCK]
      canCheck = true
      abilityBlacklist.each do |m|
        next if move.id != m
        canCheck = false
        break
      end
      if canCheck
        Battle::AbilityEffects.triggerDamageCalcFromTarget(
          target.ability, user, target, move, multipliers, baseDmg, type
        )
      end
    end
    if skill >= PBTrainerAI.bestSkill && !moldBreaker
      target.allAllies.each do |b|
        next if !b.abilityActive?
        Battle::AbilityEffects.triggerDamageCalcFromTargetAlly(
          b.ability, user, target, move, multipliers, baseDmg, type
        )
      end
    end
    # Item effects that alter damage
    # NOTE: Type-boosting gems aren't suitable for checking at the start of the
    #       round.
    if skill >= PBTrainerAI.mediumSkill && user.itemActive?
      # NOTE: These items aren't suitable for checking at the start of the
      #       round.
      itemBlacklist = [:EXPERTBELT, :LIFEORB]
      if !itemBlacklist.include?(user.item_id)
        Battle::ItemEffects.triggerDamageCalcFromUser(
          user.item, user, target, move, multipliers, baseDmg, type
        )
        user.effects[PBEffects::GemConsumed] = nil   # Untrigger consuming of Gems
      end
    end
    if skill >= PBTrainerAI.bestSkill &&
       target.itemActive? && target.item && !target.item.is_berry?
      Battle::ItemEffects.triggerDamageCalcFromTarget(
        target.item, user, target, move, multipliers, baseDmg, type
      )
    end
    # Global abilities
    if skill >= PBTrainerAI.mediumSkill &&
       ((@battle.pbCheckGlobalAbility(:DARKAURA) && type == :DARK) ||
        (@battle.pbCheckGlobalAbility(:FAIRYAURA) && type == :FAIRY))
      if @battle.pbCheckGlobalAbility(:AURABREAK)
        multipliers[:base_damage_multiplier] *= 2 / 3.0
      else
        multipliers[:base_damage_multiplier] *= 4 / 3.0
      end
    end
    # Of Ruin Abilities
    multipliers[:defense_multiplier] *= 0.75 if @battle.pbCheckGlobalAbility(:BEADSOFRUIN) && !user.hasActiveAbility?(:BEADSOFRUIN) && move.specialMove?
    multipliers[:defense_multiplier] *= 0.75 if @battle.pbCheckGlobalAbility(:SWORDOFRUIN) && !user.hasActiveAbility?(:SWORDOFRUIN) && move.physicalMove?
    multipliers[:attack_multiplier] *= 0.75 if @battle.pbCheckGlobalAbility(:TABLETSOFRUIN) && !user.hasActiveAbility?(:TABLETSOFRUIN) && move.physicalMove?
    multipliers[:attack_multiplier] *= 0.75 if @battle.pbCheckGlobalAbility(:VESSELOFRUIN) && !user.hasActiveAbility?(:VESSELOFRUIN) && move.specialMove?
    # Parental Bond
    if skill >= PBTrainerAI.mediumSkill && user.hasActiveAbility?(:PARENTALBOND)
      multipliers[:base_damage_multiplier] *= 1.25
    end
    # Me First
    # TODO
    # Helping Hand - n/a
    # Charge
    if skill >= PBTrainerAI.mediumSkill &&
       user.effects[PBEffects::Charge] > 0 && type == :ELECTRIC
      multipliers[:base_damage_multiplier] *= 2
    end
    # Mud Sport and Water Sport
    if skill >= PBTrainerAI.mediumSkill
      if type == :ELECTRIC
        if @battle.allBattlers.any? { |b| b.effects[PBEffects::MudSport] }
          multipliers[:base_damage_multiplier] /= 3
        end
        if @battle.field.effects[PBEffects::MudSportField] > 0
          multipliers[:base_damage_multiplier] /= 3
        end
      end
      if type == :FIRE
        if @battle.allBattlers.any? { |b| b.effects[PBEffects::WaterSport] }
          multipliers[:base_damage_multiplier] /= 3
        end
        if @battle.field.effects[PBEffects::WaterSportField] > 0
          multipliers[:base_damage_multiplier] /= 3
        end
      end
    end
    # Terrain moves
    if skill >= PBTrainerAI.mediumSkill
      case @battle.field.terrain
      when :Electric
        multipliers[:base_damage_multiplier] *= 1.5 if type == :ELECTRIC && user.affectedByTerrain?
      when :Grassy
        multipliers[:base_damage_multiplier] *= 1.5 if type == :GRASS && user.affectedByTerrain?
      when :Psychic
        multipliers[:base_damage_multiplier] *= 1.5 if type == :PSYCHIC && user.affectedByTerrain?
      when :Misty
        multipliers[:base_damage_multiplier] /= 2 if type == :DRAGON && target.affectedByTerrain?
      end
    end
    # Badge multipliers
    if skill >= PBTrainerAI.highSkill && @battle.internalBattle && target.pbOwnedByPlayer?
      if move.physicalMove?(type) && @battle.pbPlayer.badge_count >= Settings::NUM_BADGES_BOOST_DEFENSE
        multipliers[:defense_multiplier] *= 1.1
      elsif move.specialMove?(type) && @battle.pbPlayer.badge_count >= Settings::NUM_BADGES_BOOST_SPDEF
        multipliers[:defense_multiplier] *= 1.1
      end
    end
    # Multi-targeting attacks
    if skill >= PBTrainerAI.highSkill && pbTargetsMultiple?(move, user)
      multipliers[:final_damage_multiplier] *= 0.75
    end
    # Weather
    if skill >= PBTrainerAI.mediumSkill
      case user.effectiveWeather
      when :Sun, :HarshSun
        case type
        when :FIRE
          multipliers[:final_damage_multiplier] *= 1.5
        when :WATER
          multipliers[:final_damage_multiplier] /= 2
        end
      when :Rain, :HeavyRain
        case type
        when :FIRE
          multipliers[:final_damage_multiplier] /= 2
        when :WATER
          multipliers[:final_damage_multiplier] *= 1.5
        end
      when :Sandstorm
        if target.pbHasType?(:ROCK) && move.specialMove?(type) &&
           move.function != "UseTargetDefenseInsteadOfTargetSpDef"   # Psyshock
          multipliers[:defense_multiplier] *= 1.5
        end
      end
    end
    # Critical hits - n/a
    # Random variance - n/a
    # STAB
    if skill >= PBTrainerAI.mediumSkill && type && user.pbHasType?(type)
      if user.hasActiveAbility?(:ADAPTABILITY)
        multipliers[:final_damage_multiplier] *= 2
      else
        multipliers[:final_damage_multiplier] *= 1.5
      end
    end
    # Type effectiveness
    if skill >= PBTrainerAI.mediumSkill
      typemod = pbCalcTypeMod(type, user, target)
      multipliers[:final_damage_multiplier] *= typemod.to_f / Effectiveness::NORMAL_EFFECTIVE
    end
    # Burn
    if skill >= PBTrainerAI.highSkill && move.physicalMove?(type) &&
       user.status == :BURN && !user.hasActiveAbility?(:GUTS) &&
       !(Settings::MECHANICS_GENERATION >= 6 &&
         move.function == "DoublePowerIfUserPoisonedBurnedParalyzed")   # Facade
      multipliers[:final_damage_multiplier] /= 2
    end
    # Aurora Veil, Reflect, Light Screen
    if skill >= PBTrainerAI.highSkill && !move.ignoresReflect? && !user.hasActiveAbility?(:INFILTRATOR)
      if target.pbOwnSide.effects[PBEffects::AuroraVeil] > 0
        if @battle.pbSideBattlerCount(target) > 1
          multipliers[:final_damage_multiplier] *= 2 / 3.0
        else
          multipliers[:final_damage_multiplier] /= 2
        end
      elsif target.pbOwnSide.effects[PBEffects::Reflect] > 0 && move.physicalMove?(type)
        if @battle.pbSideBattlerCount(target) > 1
          multipliers[:final_damage_multiplier] *= 2 / 3.0
        else
          multipliers[:final_damage_multiplier] /= 2
        end
      elsif target.pbOwnSide.effects[PBEffects::LightScreen] > 0 && move.specialMove?(type)
        if @battle.pbSideBattlerCount(target) > 1
          multipliers[:final_damage_multiplier] *= 2 / 3.0
        else
          multipliers[:final_damage_multiplier] /= 2
        end
      end
    end
    # Minimize
    if skill >= PBTrainerAI.highSkill && target.effects[PBEffects::Minimize] && move.tramplesMinimize?
      multipliers[:final_damage_multiplier] *= 2
    end
    # Move-specific base damage modifiers
    # TODO
    # Move-specific final damage modifiers
    # TODO
    ##### Main damage calculation #####
    baseDmg = [(baseDmg * multipliers[:base_damage_multiplier]).round, 1].max
    atk     = [(atk     * multipliers[:attack_multiplier]).round, 1].max
    defense = [(defense * multipliers[:defense_multiplier]).round, 1].max
    damage  = ((((2.0 * user.level / 5) + 2).floor * baseDmg * atk / defense).floor / 50).floor + 2
    damage  = [(damage * multipliers[:final_damage_multiplier]).round, 1].max
    # "AI-specific calculations below"
    # Increased critical hit rates
    if skill >= PBTrainerAI.mediumSkill
      c = 0
      # Ability effects that alter critical hit rate
      if c >= 0 && user.abilityActive?
        c = Battle::AbilityEffects.triggerCriticalCalcFromUser(user.ability, user, target, c)
      end
      if skill >= PBTrainerAI.bestSkill && c >= 0 && !moldBreaker && target.abilityActive?
        c = Battle::AbilityEffects.triggerCriticalCalcFromTarget(target.ability, user, target, c)
      end
      # Item effects that alter critical hit rate
      if c >= 0 && user.itemActive?
        c = Battle::ItemEffects.triggerCriticalCalcFromUser(user.item, user, target, c)
      end
      if skill >= PBTrainerAI.bestSkill && c >= 0 && target.itemActive?
        c = Battle::ItemEffects.triggerCriticalCalcFromTarget(target.item, user, target, c)
      end
      # Other efffects
      c = -1 if target.pbOwnSide.effects[PBEffects::LuckyChant] > 0
      if c >= 0
        c += 1 if move.highCriticalRate?
        c += user.effects[PBEffects::FocusEnergy]
        c += 1 if user.inHyperMode? && move.type == :SHADOW
      end
      if c >= 0
        c = 4 if c > 4
        damage += damage * 0.1 * c
      end
    end
    return damage.floor
  end

  #=============================================================================
  # Get a score for the given move based on its effect
  #=============================================================================
  alias paldea_pbGetMoveScoreFunctionCode pbGetMoveScoreFunctionCode

  def pbGetMoveScoreFunctionCode(score, move, user, target, skill = 100)
    case move.function
    #---------------------------------------------------------------------------
    when "SetTargetAbilityToSimple"
      if target.effects[PBEffects::Substitute] > 0
        score -= 90
      elsif skill >= PBTrainerAI.mediumSkill
        if target.unstoppableAbility? || [:TRUANT, :SIMPLE].include?(target.ability) || target.hasActiveItem?(:ABILITYSHIELD)
          score -= 90
        end
      end
    #---------------------------------------------------------------------------
    when "SetTargetAbilityToInsomnia"
      if target.effects[PBEffects::Substitute] > 0
        score -= 90
      elsif skill >= PBTrainerAI.mediumSkill
        if target.unstoppableAbility? || [:TRUANT, :INSOMNIA].include?(target.ability_id) || target.hasActiveItem?(:ABILITYSHIELD)
          score -= 90
        end
      end
    #---------------------------------------------------------------------------
    when "SetUserAbilityToTargetAbility"
      score -= 40   # don't prefer this move
      if skill >= PBTrainerAI.mediumSkill
        if !target.ability || user.ability == target.ability ||
          [:MULTITYPE, :RKSSYSTEM].include?(user.ability_id) ||
          [:FLOWERGIFT, :FORECAST, :ILLUSION, :IMPOSTER, :MULTITYPE, :RKSSYSTEM,
            :TRACE, :WONDERGUARD, :ZENMODE].include?(target.ability_id) || user.hasActiveItem?(:ABILITYSHIELD)
          score -= 90
        end
      end
      if skill >= PBTrainerAI.highSkill
        if target.ability == :TRUANT && user.opposes?(target)
          score -= 90
        elsif target.ability == :SLOWSTART && user.opposes?(target)
          score -= 90
        end
      end
    #---------------------------------------------------------------------------
    when "SetTargetAbilityToUserAbility"
      score -= 40   # don't prefer this move
      if target.effects[PBEffects::Substitute] > 0
        score -= 90
      elsif skill >= PBTrainerAI.mediumSkill
        if !user.ability || user.ability == target.ability ||
          [:MULTITYPE, :RKSSYSTEM, :TRUANT].include?(target.ability_id) ||
          [:FLOWERGIFT, :FORECAST, :ILLUSION, :IMPOSTER, :MULTITYPE, :RKSSYSTEM,
            :TRACE, :ZENMODE].include?(user.ability_id)  || target.hasActiveItem?(:ABILITYSHIELD)
          score -= 90
        end
        if skill >= PBTrainerAI.highSkill
          if user.ability == :TRUANT && user.opposes?(target)
            score += 90
          elsif user.ability == :SLOWSTART && user.opposes?(target)
            score += 90
          end
        end
      end
    #---------------------------------------------------------------------------
    when "UserTargetSwapAbilities"
      score -= 40   # don't prefer this move
      if skill >= PBTrainerAI.mediumSkill
        if (!user.ability && !target.ability) ||
          user.ability == target.ability ||
          [:ILLUSION, :MULTITYPE, :RKSSYSTEM, :WONDERGUARD].include?(user.ability_id) ||
          [:ILLUSION, :MULTITYPE, :RKSSYSTEM, :WONDERGUARD].include?(target.ability_id) || 
          target.hasActiveItem?(:ABILITYSHIELD) || user.hasActiveItem?(:ABILITYSHIELD)
          score -= 90
        end
      end
      if skill >= PBTrainerAI.highSkill
        if target.ability == :TRUANT && user.opposes?(target)
          score -= 90
        elsif target.ability == :SLOWSTART && user.opposes?(target)
          score -= 90
        end
      end
    #---------------------------------------------------------------------------
    when "NegateTargetAbility"
      if target.effects[PBEffects::Substitute] > 0 ||
        target.effects[PBEffects::GastroAcid]
        score -= 90
      elsif skill >= PBTrainerAI.highSkill
        score -= 90 if [:MULTITYPE, :RKSSYSTEM, :SLOWSTART, :TRUANT].include?(target.ability_id) || target.hasActiveItem?(:ABILITYSHIELD)
      end
    #---------------------------------------------------------------------------
    when "UserSwapsPositionsWithAlly" # Ally Switch
      if skill >= PBTrainerAI.mediumSkill && user.pbOwnSide.effects[PBEffects::AllySwitch] == true
        score -= 100
      end
    # PLA
    #---------------------------------------------------------------------------
    when "PoisonParalyzeOrSleepTarget" # Dire Claw
      score -= 20 if target.pbHasAnyStatus?
      score -= 30 if target.effects[PBEffects::Yawn] > 0 && skill >= PBTrainerAI.mediumSkill
      if skill >= PBTrainerAI.bestSkill && 
         target.pbHasMoveFunction?("FlinchTargetFailsIfUserNotAsleep",
                                     "UseRandomUserMoveIfAsleep")   # Snore, Sleep Talk
        score -= 30
      end
      if skill >= PBTrainerAI.highSkill
        score -= 30 if target.hasActiveAbility?([:GUTS, :MARVELSCALE, :QUICKFEET, :TOXICBOOST])
      end
    #---------------------------------------------------------------------------
    when "SwapsAttackDefenseTarget"
      score += 40 if target.attack > target.defense
      score -= 60 if move.statusMove? && skill >= PBTrainerAI.mediumSkill
    #---------------------------------------------------------------------------
    when "RecoilAndRaiseUserSpeed"
      score -= 25 if skill < PBTrainerAI.mediumSkill || !user.hasActiveAbility?(:ROCKHEAD)
      score += 20 if !user.statStageAtMax?(:ATTACK)
    #---------------------------------------------------------------------------
    when "RaiseUserAtkDefSpd1"
      score -= 30 if user.statStageAtMax?(:ATTACK)
      score -= 30 if user.statStageAtMax?(:DEFENSE)
      score -= 30 if user.statStageAtMax?(:SPEED)
    #---------------------------------------------------------------------------
    when "DoublePowerIfTargetPoisonedPoisonTarget"
      if !target.pbHasAnyStatus?  # Because of possible poisoning
        score += 20
      elsif target.status == :POISON
        score += 40
      end
    #---------------------------------------------------------------------------
    when "DoublePowerIfTargetStatusProblemBurnTarget"
      if !target.pbHasAnyStatus?  # Because of possible burning
        score += 20
      else
        score += 40
      end
    #---------------------------------------------------------------------------
    when "LowerDefenseTarget1Flinch"
      if target.stages[:DEFENSE] > 0 && !target.statStageAtMax?(:DEFENSE)
        score += 20
      end
    #---------------------------------------------------------------------------
    when "HealAndCureStatusUser"
      score += 20 if user.hp <= user.totalhp / 2
      score += 20 if user.pbHasAnyStatus?
    #---------------------------------------------------------------------------
    when "RaiseStatsAndCureStatus"
      score += 40 if user.pbHasAnyStatus?
      score -= 20 if user.statStageAtMax?(:SPECIAL_ATTACK)
      score -= 20 if user.statStageAtMax?(:SPECIAL_DEFENSE)
    # Gen 9
    #---------------------------------------------------------------------------
    when "InflictConfuseCrashDamageIfFailsUnusableInGravity" # Axe Kick
      score += 10 * (user.stages[:ACCURACY] - target.stages[:EVASION])
    #---------------------------------------------------------------------------
    when "SwitchOutUserWeatherHailMove" # Chilly Reception
      if !@battle.pbCanChooseNonActive?(user.index) ||
         @battle.pbTeamAbleNonActiveCount(user.index) > 1   # Don't switch in ace
        score -= 100
      else
        score += 40 if user.effects[PBEffects::Confusion] > 0
        total = 0
        GameData::Stat.each_battle { |s| total += user.stages[s.id] }
        if total <= 0 || user.turnCount == 0
          score += 60
        else
          score -= total * 10
          # special case: user has no damaging moves
          hasDamagingMove = false
          user.eachMove do |m|
            next if !m.damagingMove?
            hasDamagingMove = true
            break
          end
          score += 75 if !hasDamagingMove
        end
      end
    #---------------------------------------------------------------------------
    when "IncreaseDamageIfSuperEffective"
      score += 60 if Effectiveness.super_effective?(pbCalcTypeMod(move.type, user, target)) && skill >= PBTrainerAI.mediumSkill
    #---------------------------------------------------------------------------
    when "SetUserAlliesAbilityToTargetAbility" # same as role play
      score -= 40   # don't prefer this move
      if skill >= PBTrainerAI.mediumSkill
        if !target.ability || user.ability == target.ability ||
           [:MULTITYPE, :RKSSYSTEM].include?(user.ability_id) ||
           [:FLOWERGIFT, :FORECAST, :ILLUSION, :IMPOSTER, :MULTITYPE, :RKSSYSTEM,
            :TRACE, :WONDERGUARD, :ZENMODE].include?(target.ability_id) ||
            (user.itemActive? && user.item_id == :ABILITYSHIELD)
          score -= 90
        end
      end
      if skill >= PBTrainerAI.highSkill
        if target.ability == :TRUANT && user.opposes?(target)
          score -= 90
        elsif target.ability == :SLOWSTART && user.opposes?(target)
          score -= 90
        end
      end
    #---------------------------------------------------------------------------
    when "UserLosesElectricType"
      score -= 90 if !user.pbHasType?(:ELECTRIC)
    #---------------------------------------------------------------------------
    when "RaiseUserAtk2SpAtk2Speed2LoseHalfOfTotalHP"
      if (user.statStageAtMax?(:ATTACK) && user.statStageAtMax?(:SPECIAL_ATTACK) && user.statStageAtMax?(:SPEED)) ||
         user.hp <= user.totalhp / 2
        score -= 100
      else
        score += (6 - user.stages[:ATTACK]) * 3
        score += (6 - user.stages[:SPECIAL_ATTACK]) * 3
        score += (6 - user.stages[:SPEED]) * 3
      end
    #---------------------------------------------------------------------------
    when "DoubleNextReceiveDamageAndNeverMiss"
    #---------------------------------------------------------------------------
    when "IncreaseDamageEachFaintedAllies" # Last Respect
      score += [@battle.getFaintedCount(user),10].min * 10
    #---------------------------------------------------------------------------
    when "AddMoneyGainedFromBattleLowerUserSpAtk1"
      score -= 40   # don't prefer this move
    #---------------------------------------------------------------------------
    when "RemoveUserBindingAndEntryHazardsPoisonTarget"
      score += 30 if user.effects[PBEffects::Trapping] > 0
      score += 30 if user.effects[PBEffects::LeechSeed] >= 0
      if @battle.pbAbleNonActiveCount(user.idxOwnSide) > 0
        score += 80 if user.pbOwnSide.effects[PBEffects::Spikes] > 0
        score += 80 if user.pbOwnSide.effects[PBEffects::ToxicSpikes] > 0
        score += 80 if user.pbOwnSide.effects[PBEffects::StealthRock]
      end
      if target.pbCanPoison?(user, false)
        score += 30
        if skill >= PBTrainerAI.mediumSkill
          score += 30 if target.hp <= target.totalhp / 4
          score += 50 if target.hp <= target.totalhp / 8
          score -= 40 if target.effects[PBEffects::Yawn] > 0
        end
        if skill >= PBTrainerAI.highSkill
          score += 10 if pbRoughStat(target, :DEFENSE, skill) > 100
          score += 10 if pbRoughStat(target, :SPECIAL_DEFENSE, skill) > 100
          score -= 40 if target.hasActiveAbility?([:GUTS, :MARVELSCALE, :TOXICBOOST])
        end
      end
    #---------------------------------------------------------------------------
    when "RaiseUserStat1Tatsugiri"
    #---------------------------------------------------------------------------
    when "HitTenTimesPopulationBomb"
    #---------------------------------------------------------------------------
    when "IncreaseDamage50EachGotHit" # Rage Fist
      score += [@battle.getBattlerHit(user),10].min * 10
    #---------------------------------------------------------------------------
    when "TypeDependsOnUserForm"
      score += 20 if user.pbOpposingSide.effects[PBEffects::AuroraVeil] > 0
      score += 20 if user.pbOpposingSide.effects[PBEffects::Reflect] > 0
      score += 20 if user.pbOpposingSide.effects[PBEffects::LightScreen] > 0
    #---------------------------------------------------------------------------
    when "RevivePokemonHalfHP"
      numFainted = 0
      @battle.pbParty(user.idxOwnSide).each { |b| numFainted += 1 if b.fainted? }
      score += (numFainted/@battle.pbParty(user.idxOwnSide).length) * 100 if numFainted > 0
    #---------------------------------------------------------------------------
    when "StartSaltCureTarget"
      if target.effects[PBEffects::SaltCure]
        score -= 40
      else
        score += 60 if user.turnCount == 0
        score += 80 if skill >= PBTrainerAI.mediumSkill && target.pbHasType?(:WATER) || target.pbHasType?(:STEEL)
      end
    #---------------------------------------------------------------------------
    when "UserMakeSubstituteSwitchOut"
      if user.effects[PBEffects::Substitute] > 0
        score -= 90
      elsif user.hp <= user.totalhp / 2
        score -= 90
      end
    #---------------------------------------------------------------------------
    when "ProtectUserFromDamagingSilkTrap"
      if user.effects[PBEffects::ProtectRate] > 1 ||
        target.effects[PBEffects::HyperBeam] > 0
       score -= 90
     else
       if skill >= PBTrainerAI.mediumSkill
         score -= user.effects[PBEffects::ProtectRate] * 40
       end
       score += 50 if user.turnCount == 0
       score += 30 if target.effects[PBEffects::TwoTurnAttack]
     end
    #---------------------------------------------------------------------------
    when "RaiseAtkLowerDefTargetStat"
      if target.pbCanLowerStatStage?(:DEFENSE, user)
        score -= target.stages[:ATTACK] * 20
        score += target.stages[:DEFENSE] * 20
        if skill >= PBTrainerAI.mediumSkill
          hasPhysicalAttack = false
          target.eachMove do |m|
            next if !m.physicalMove?(m.type)
            hasPhysicalAttack = true
            break
          end
          if hasPhysicalAttack
            score -= 20
          elsif skill >= PBTrainerAI.highSkill
            score += 60
          end
        end
      else
        score -= 60
      end
    #---------------------------------------------------------------------------
    when "CategoryDependsOnHigherDamageTera"
    #---------------------------------------------------------------------------
    when "RemoveBothEntryHazardsRaiseAtkSpeed"
      if @battle.pbAbleNonActiveCount(user.idxOwnSide) > 0
        score += 80 if user.pbOwnSide.effects[PBEffects::Spikes] > 0
        score += 80 if user.pbOwnSide.effects[PBEffects::ToxicSpikes] > 0
        score += 80 if user.pbOwnSide.effects[PBEffects::StealthRock]
      end
      score += 80 if user.effects[PBEffects::Substitute] > 0

      if @battle.pbAbleNonActiveCount(target.idxOwnSide) > 0
        score -= 80 if target.pbOwnSide.effects[PBEffects::Spikes] > 0
        score -= 80 if target.pbOwnSide.effects[PBEffects::ToxicSpikes] > 0
        score -= 80 if target.pbOwnSide.effects[PBEffects::StealthRock]
      end
      score -= 80 if target.effects[PBEffects::Substitute] > 0
    #---------------------------------------------------------------------------
    when "HitThreeTimes"
    #---------------------------------------------------------------------------
    else
      return paldea_pbGetMoveScoreFunctionCode(score, move, user, target, skill)
    end
    return score
  end

  #=============================================================================
  # Decide whether the opponent should use an item on the Pokémon
  #=============================================================================
  def pbEnemyShouldUseItem?(idxBattler)
    user = @battle.battlers[idxBattler]
    item, idxTarget = pbEnemyItemToUse(idxBattler)
    return false if !item
    # Determine target of item (always the Pokémon choosing the action)
    useType = GameData::Item.get(item).battle_use
    reviveItems = [
      :SACREDASH, :REVIVE, :MAXREVIVE, :REVIVALHERB
    ]
    if [1, 2, 3].include?(useType) && !reviveItems.include?(item)   # Use on Pokémon
      idxTarget = @battle.battlers[idxTarget].pokemonIndex   # Party Pokémon
    end
    # Register use of item
    @battle.pbRegisterItem(idxBattler, item, idxTarget)
    PBDebug.log("[AI] #{user.pbThis} (#{user.index}) will use item #{GameData::Item.get(item).name}")
    return true
  end
  
  # NOTE: The AI will only consider using an item on the Pokémon it's currently
  #       choosing an action for.
  alias paldea_pbEnemyItemToUse pbEnemyItemToUse
  def pbEnemyItemToUse(idxBattler)
    return nil if !@battle.internalBattle
    items = @battle.pbGetOwnerItems(idxBattler)
    return nil if !items || items.length == 0
    ret = paldea_pbEnemyItemToUse(idxBattler)
    return ret if ret
    # Determine target of item (always the Pokémon choosing the action)
    numFainted = 0
    partyCount = 0
    party = @battle.pbParty(idxBattler)
    party.each { |b| numFainted += 1 if b.fainted?; partyCount += 1 }
    return nil if numFainted == 0
    idxTarget = pbDefaultChooseReviveEnemy(idxBattler, party)
    echoln idxTarget
    return nil if idxTarget < 0
    battler = @battle.battlers[idxBattler]
    pkmn = party[idxTarget]#battler.pokemon
    fullreviveItems = [
      :SACREDASH
    ]
    reviveItems = [
      :REVIVE, :MAXREVIVE, :REVIVALHERB
    ]
    halfPartyFaint = ( numFainted >= (partyCount/2).to_i )
    # Find all usable items
    usableReviveItems = []
    items.each do |i|
      next if !i
      next if !@battle.pbCanUseItemOnPokemon?(i, pkmn, battler, @battle.scene, false)
      next if !ItemHandlers.triggerCanUseInBattle(i, pkmn, battler, nil,
                                                  false, self, @battle.scene, false)
      # Log revive items
      if reviveItems.include?(i)
        usableReviveItems.push([i, 5])
        next
      end
      # Log Sacred Ashes (Revive all fainted Pokemon)
      if fullreviveItems.include?(i)
        usableReviveItems.push([i, (halfPartyFaint) ? 3 : 7])
        next
      end
    end
    # Prioritise using a HP restoration item
    if usableReviveItems.length > 0 && (numFainted > 0 ||
       (halfPartyFaint && pbAIRandom(100) < 30))
      usableReviveItems.sort! { |a, b| (a[1] == b[1]) ? a[2] <=> b[2] : a[1] <=> b[1] }
      prevItem = nil
      usableReviveItems.each do |i|
        return i[0], idxTarget
        prevItem = i
      end
      return prevItem[0], idxTarget
    end
  end
  #=============================================================================
  # Choose a fainted Pokémon
  #=============================================================================
  def pbDefaultChooseReviveEnemy(idxBattler, party)
    enemies = []
    idxPartyStart, idxPartyEnd = @battle.pbTeamIndexRangeFromBattlerIndex(idxBattler)
    party.each_with_index do |_p, i|
      # next if i == idxPartyEnd - 1 && enemies.length > 0   # Ignore ace if possible
      enemies.push(i) if !_p.egg? && _p.fainted?
    end
    return -1 if enemies.length == 0
    return pbChooseBestNewEnemy(idxBattler, party, enemies)
  end

  #=============================================================================
  # Decide whether the opponent should switch Pokémon
  #=============================================================================
  def pbEnemyShouldWithdrawEx?(idxBattler, forceSwitch)
    return false if @battle.wildBattle?
    shouldSwitch = forceSwitch
    batonPass = -1
    moveType = nil
    skill = @battle.pbGetOwnerFromBattlerIndex(idxBattler).skill_level || 0
    battler = @battle.battlers[idxBattler]
    # If Pokémon is within 6 levels of the foe, and foe's last move was
    # super-effective and powerful
    if !shouldSwitch && battler.turnCount > 0 && skill >= PBTrainerAI.highSkill
      target = battler.pbDirectOpposing(true)
      if !target.fainted? && target.lastMoveUsed &&
         (target.level - battler.level).abs <= 6
        moveData = GameData::Move.get(target.lastMoveUsed)
        moveType = moveData.type
        typeMod = pbCalcTypeMod(moveType, target, battler)
        if Effectiveness.super_effective?(typeMod) && moveData.base_damage > 50
          switchChance = (moveData.base_damage > 70) ? 30 : 20
          shouldSwitch = (pbAIRandom(100) < switchChance)
        end
      end
    end
    # Pokémon can't do anything (must have been in battle for at least 5 rounds)
    if !@battle.pbCanChooseAnyMove?(idxBattler) &&
       battler.turnCount && battler.turnCount >= 5
      shouldSwitch = true
    end
    # Pokémon is Perish Songed and has Baton Pass
    if skill >= PBTrainerAI.highSkill && battler.effects[PBEffects::PerishSong] == 1
      battler.eachMoveWithIndex do |m, i|
        next if m.function != "SwitchOutUserPassOnEffects"   # Baton Pass
        next if !@battle.pbCanChooseMove?(idxBattler, i, false)
        batonPass = i
        shouldSwitch = true
        break
      end
    end
    # Pokémon will faint because of bad poisoning at the end of this round, but
    # would survive at least one more round if it were regular poisoning instead
    if battler.status == :POISON && battler.statusCount > 0 &&
       skill >= PBTrainerAI.highSkill
      toxicHP = battler.totalhp / 16
      nextToxicHP = toxicHP * (battler.effects[PBEffects::Toxic] + 1)
      if battler.hp <= nextToxicHP && battler.hp > toxicHP * 2 && pbAIRandom(100) < 80
        shouldSwitch = true
      end
    end
    # Pokémon is Encored into an unfavourable move
    if battler.effects[PBEffects::Encore] > 0 && skill >= PBTrainerAI.mediumSkill
      idxEncoredMove = battler.pbEncoredMoveIndex
      if idxEncoredMove >= 0
        scoreSum   = 0
        scoreCount = 0
        battler.allOpposing.each do |b|
          scoreSum += pbGetMoveScore(battler.moves[idxEncoredMove], battler, b, skill)
          scoreCount += 1
        end
        if scoreCount > 0 && scoreSum / scoreCount <= 20 && pbAIRandom(100) < 80
          shouldSwitch = true
        end
      end
    end
    # If there is a single foe and it is resting after Hyper Beam or is
    # Truanting (i.e. free turn)
    if @battle.pbSideSize(battler.index + 1) == 1 &&
       !battler.pbDirectOpposing.fainted? && skill >= PBTrainerAI.highSkill
      opp = battler.pbDirectOpposing
      if (opp.effects[PBEffects::HyperBeam] > 0 ||
         (opp.hasActiveAbility?(:TRUANT) && opp.effects[PBEffects::Truant])) && pbAIRandom(100) < 80
        shouldSwitch = false
      end
    end
    # Sudden Death rule - I'm not sure what this means
    if @battle.rules["suddendeath"] && battler.turnCount > 0
      if battler.hp <= battler.totalhp / 4 && pbAIRandom(100) < 30
        shouldSwitch = true
      elsif battler.hp <= battler.totalhp / 2 && pbAIRandom(100) < 80
        shouldSwitch = true
      end
    end
    # Pokémon is about to faint because of Perish Song
    if battler.effects[PBEffects::PerishSong] == 1
      shouldSwitch = true
    end
    # If its a Palafin that doesnt have a Switching Move
    if battler.isSpecies?(:PALAFIN) && battler.form == 0
      switchmove_func = ["SwitchOutUserStatusMove", "SwitchOutUserPassOnEffects","SwitchOutUserDamagingMove"]
      battler.eachMoveWithIndex do |m, i|
        next if !switchmove_func.include?(m.function)
        next if !@battle.pbCanChooseMove?(idxBattler, i, false)
        batonPass = i
        shouldSwitch = true
        break
      end
    end
    if shouldSwitch
      list = []
      idxPartyStart, idxPartyEnd = @battle.pbTeamIndexRangeFromBattlerIndex(idxBattler)
      @battle.pbParty(idxBattler).each_with_index do |pkmn, i|
        next if i == idxPartyEnd - 1   # Don't choose to switch in ace
        next if !@battle.pbCanSwitch?(idxBattler, i)
        # If perish count is 1, it may be worth it to switch
        # even with Spikes, since Perish Song's effect will end
        if battler.effects[PBEffects::PerishSong] != 1
          # Will contain effects that recommend against switching
          spikes = battler.pbOwnSide.effects[PBEffects::Spikes]
          # Don't switch to this if too little HP
          if spikes > 0
            spikesDmg = [8, 6, 4][spikes - 1]
            next if pkmn.hp <= pkmn.totalhp / spikesDmg &&
                    !pkmn.hasType?(:FLYING) && !pkmn.hasActiveAbility?(:LEVITATE)
          end
        end
        # moveType is the type of the target's last used move
        if moveType && Effectiveness.ineffective?(pbCalcTypeMod(moveType, battler, battler))
          weight = 65
          typeMod = pbCalcTypeModPokemon(pkmn, battler.pbDirectOpposing(true))
          if Effectiveness.super_effective?(typeMod)
            # Greater weight if new Pokemon's type is effective against target
            weight = 85
          end
          list.unshift(i) if pbAIRandom(100) < weight   # Put this Pokemon first
        elsif moveType && Effectiveness.resistant?(pbCalcTypeMod(moveType, battler, battler))
          weight = 40
          typeMod = pbCalcTypeModPokemon(pkmn, battler.pbDirectOpposing(true))
          if Effectiveness.super_effective?(typeMod)
            # Greater weight if new Pokemon's type is effective against target
            weight = 60
          end
          list.unshift(i) if pbAIRandom(100) < weight   # Put this Pokemon first
        else
          list.push(i)   # put this Pokemon last
        end
      end
      if list.length > 0
        if batonPass >= 0 && @battle.pbRegisterMove(idxBattler, batonPass, false)
          PBDebug.log("[AI] #{battler.pbThis} (#{idxBattler}) will use Baton Pass to avoid Perish Song")
          return true
        end
        if @battle.pbRegisterSwitch(idxBattler, list[0])
          PBDebug.log("[AI] #{battler.pbThis} (#{idxBattler}) will switch with " +
                      @battle.pbParty(idxBattler)[list[0]].name)
          return true
        end
      end
    end
    return false
  end
end