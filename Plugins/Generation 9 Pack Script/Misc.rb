module Settings
  MECHANICS_GENERATION = 9
end
#===============================================================================
# PBEffects
#===============================================================================
module PBEffects
  # Starts from 401 to avoid conflicts with other plugins.
  # Abilities
  ParadoxStat         = 401
  BoosterEnergy       = 402
  CudChew             = 403
  SupremeOverlord     = 404
  Protean             = 415
  # Moves
  Comeuppance         = 405
  ComeuppanceTarget   = 406
  DoubleShock         = 407
  GlaiveRush          = 408
  CommanderTatsugiri  = 409
  CommanderDondozo    = 410
  SilkTrap            = 412
  SaltCure            = 413
  AllySwitch          = 414
end
#===============================================================================
# Ability Effects
#===============================================================================
module Battle::AbilityEffects
  CertainStatGain = AbilityHandlerHash.new

  def self.triggerCertainStatGain(ability, battler, battle, stat, user, increment)
    CertainStatGain.trigger(ability, battler, battle, stat, user,increment)
  end

  def self.triggerOnStatGain(ability, battler, stat, user, increment)
    OnStatGain.trigger(ability, battler, stat, user, increment)
  end
end
#===============================================================================
# Item Effects
#===============================================================================
module Battle::ItemEffects
  CertainStatGain = ItemHandlerHash.new
  StatLossImmunity = ItemHandlerHash.new
  def self.triggerCertainStatGain(item, battler, stat, user, increment, battle, forced)
    return trigger(CertainStatGain, item, battler, stat, user, increment, battle, forced)
  end

  def self.triggerStatLossImmunity(item, battler, stat, battle, show_message)
    return trigger(StatLossImmunity, item, battler, stat, battle, show_message)
  end
end
#===============================================================================
# Battle Move
#===============================================================================
class Battle::Move
  def pbContactMove?(user)
    return false if user.hasActiveAbility?(:LONGREACH)
    return false if user.hasActiveItem?(:PUNCHINGGLOVE) && punchingMove?
    return contactMove?
  end
  # Used by Counter/Mirror Coat/Metal Burst/Revenge/Focus Punch/Bide/Assurance.
  # add Comeuppance
  def pbRecordDamageLost(user, target)
    damage = target.damageState.hpLost
    # NOTE: In Gen 3 where a move's category depends on its type, Hidden Power
    #       is for some reason countered by Counter rather than Mirror Coat,
    #       regardless of its calculated type. Hence the following two lines of
    #       code.
    moveType = nil
    moveType = :NORMAL if @function == "TypeDependsOnUserIVs"   # Hidden Power
    if physicalMove?(moveType)
      target.effects[PBEffects::Counter]       = damage
      target.effects[PBEffects::CounterTarget] = user.index
    elsif specialMove?(moveType)
      target.effects[PBEffects::MirrorCoat]       = damage
      target.effects[PBEffects::MirrorCoatTarget] = user.index
    end
    target.effects[PBEffects::Comeuppance]       = damage
    target.effects[PBEffects::ComeuppanceTarget] = user.index
    if target.effects[PBEffects::Bide] > 0
      target.effects[PBEffects::BideDamage] += damage
      target.effects[PBEffects::BideTarget] = user.index
    end
    target.damageState.fainted = true if target.fainted?
    target.lastHPLost = damage                        # For Focus Punch
    target.tookDamageThisRound = true if damage > 0   # For Assurance
    target.lastAttacker.push(user.index)              # For Revenge
    if target.opposes?(user)
      target.lastHPLostFromFoe = damage               # For Metal Burst
      target.lastFoeAttacker.push(user.index)         # For Metal Burst
    end
    if $game_temp.party_direct_damage_taken &&
       $game_temp.party_direct_damage_taken[target.pokemonIndex] &&
       target.pbOwnedByPlayer?
      $game_temp.party_direct_damage_taken[target.pokemonIndex] += damage
    end
  end

  # Add Effect of Glaive Rush, snow & Frostbite
  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    # Global abilities
    if (@battle.pbCheckGlobalAbility(:DARKAURA) && type == :DARK) ||
       (@battle.pbCheckGlobalAbility(:FAIRYAURA) && type == :FAIRY)
      if @battle.pbCheckGlobalAbility(:AURABREAK)
        multipliers[:base_damage_multiplier] *= 2 / 3.0
      else
        multipliers[:base_damage_multiplier] *= 4 / 3.0
      end
    end
    # Of Ruin Abilities
    multipliers[:defense_multiplier] *= 0.75 if @battle.pbCheckGlobalAbility(:BEADSOFRUIN) && !user.hasActiveAbility?(:BEADSOFRUIN) && specialMove?
    multipliers[:defense_multiplier] *= 0.75 if @battle.pbCheckGlobalAbility(:SWORDOFRUIN) && !user.hasActiveAbility?(:SWORDOFRUIN) && physicalMove?
    multipliers[:attack_multiplier] *= 0.75 if @battle.pbCheckGlobalAbility(:TABLETSOFRUIN) && !user.hasActiveAbility?(:TABLETSOFRUIN) && physicalMove?
    multipliers[:attack_multiplier] *= 0.75 if @battle.pbCheckGlobalAbility(:VESSELOFRUIN) && !user.hasActiveAbility?(:VESSELOFRUIN) && specialMove?
    # Ability effects that alter damage
    if user.abilityActive?
      Battle::AbilityEffects.triggerDamageCalcFromUser(
        user.ability, user, target, self, multipliers, baseDmg, type
      )
    end
    if !target.affectedByMoldBreaker?
      # NOTE: It's odd that the user's Mold Breaker prevents its partner's
      #       beneficial abilities (i.e. Flower Gift boosting Atk), but that's
      #       how it works.
      user.allAllies.each do |b|
        next if !b.abilityActive?
        Battle::AbilityEffects.triggerDamageCalcFromAlly(
          b.ability, user, target, self, multipliers, baseDmg, type
        )
      end
      if target.abilityActive?
        Battle::AbilityEffects.triggerDamageCalcFromTarget(
          target.ability, user, target, self, multipliers, baseDmg, type
        )
        Battle::AbilityEffects.triggerDamageCalcFromTargetNonIgnorable(
          target.ability, user, target, self, multipliers, baseDmg, type
        )
      end
      target.allAllies.each do |b|
        next if !b.abilityActive?
        Battle::AbilityEffects.triggerDamageCalcFromTargetAlly(
          b.ability, user, target, self, multipliers, baseDmg, type
        )
      end
    end
    # Item effects that alter damage
    if user.itemActive?
      Battle::ItemEffects.triggerDamageCalcFromUser(
        user.item, user, target, self, multipliers, baseDmg, type
      )
    end
    if target.itemActive?
      Battle::ItemEffects.triggerDamageCalcFromTarget(
        target.item, user, target, self, multipliers, baseDmg, type
      )
    end
    # Parental Bond's second attack
    if user.effects[PBEffects::ParentalBond] == 1
      multipliers[:base_damage_multiplier] /= (Settings::MECHANICS_GENERATION >= 7) ? 4 : 2
    end
    # Other
    if user.effects[PBEffects::MeFirst]
      multipliers[:base_damage_multiplier] *= 1.5
    end
    if user.effects[PBEffects::HelpingHand] && !self.is_a?(Battle::Move::Confusion)
      multipliers[:base_damage_multiplier] *= 1.5
    end
    if user.effects[PBEffects::Charge] > 0 && type == :ELECTRIC
      multipliers[:base_damage_multiplier] *= 2
    end
    # Mud Sport
    if type == :ELECTRIC
      if @battle.allBattlers.any? { |b| b.effects[PBEffects::MudSport] }
        multipliers[:base_damage_multiplier] /= 3
      end
      if @battle.field.effects[PBEffects::MudSportField] > 0
        multipliers[:base_damage_multiplier] /= 3
      end
    end
    # Water Sport
    if type == :FIRE
      if @battle.allBattlers.any? { |b| b.effects[PBEffects::WaterSport] }
        multipliers[:base_damage_multiplier] /= 3
      end
      if @battle.field.effects[PBEffects::WaterSportField] > 0
        multipliers[:base_damage_multiplier] /= 3
      end
    end
    # Terrain moves
    terrain_multiplier = (Settings::MECHANICS_GENERATION >= 8) ? 1.3 : 1.5
    case @battle.field.terrain
    when :Electric
      multipliers[:base_damage_multiplier] *= terrain_multiplier if type == :ELECTRIC && user.affectedByTerrain?
    when :Grassy
      multipliers[:base_damage_multiplier] *= terrain_multiplier if type == :GRASS && user.affectedByTerrain?
    when :Psychic
      multipliers[:base_damage_multiplier] *= terrain_multiplier if type == :PSYCHIC && user.affectedByTerrain?
    when :Misty
      multipliers[:base_damage_multiplier] /= 2 if type == :DRAGON && target.affectedByTerrain?
    end
    # Badge multipliers
    if @battle.internalBattle
      if user.pbOwnedByPlayer?
        if physicalMove? && @battle.pbPlayer.badge_count >= Settings::NUM_BADGES_BOOST_ATTACK
          multipliers[:attack_multiplier] *= 1.1
        elsif specialMove? && @battle.pbPlayer.badge_count >= Settings::NUM_BADGES_BOOST_SPATK
          multipliers[:attack_multiplier] *= 1.1
        end
      end
      if target.pbOwnedByPlayer?
        if physicalMove? && @battle.pbPlayer.badge_count >= Settings::NUM_BADGES_BOOST_DEFENSE
          multipliers[:defense_multiplier] *= 1.1
        elsif specialMove? && @battle.pbPlayer.badge_count >= Settings::NUM_BADGES_BOOST_SPDEF
          multipliers[:defense_multiplier] *= 1.1
        end
      end
    end
    # Multi-targeting attacks
    if numTargets > 1
      multipliers[:final_damage_multiplier] *= 0.75
    end
    # Weather
    case user.effectiveWeather
    when :Sun, :HarshSun
      case type
      when :FIRE
        multipliers[:final_damage_multiplier] *= 1.5
      when :WATER
        multipliers[:final_damage_multiplier] /= 2 if @function != "BPRaiseWhileSunny"
      end
    when :Rain, :HeavyRain
      case type
      when :FIRE
        multipliers[:final_damage_multiplier] /= 2
      when :WATER
        multipliers[:final_damage_multiplier] *= 1.5
      end
    when :Sandstorm
      if target.pbHasType?(:ROCK) && specialMove? && @function != "UseTargetDefenseInsteadOfTargetSpDef"
        multipliers[:defense_multiplier] *= 1.5
      end
    when :Hail
      if target.pbHasType?(:ICE) && physicalMove? && Settings::HAIL_MODE != 1
        multipliers[:defense_multiplier] *= 1.5
      end
    end
    # Critical hits
    if target.damageState.critical
      if Settings::NEW_CRITICAL_HIT_RATE_MECHANICS
        multipliers[:final_damage_multiplier] *= 1.5
      else
        multipliers[:final_damage_multiplier] *= 2
      end
    end
    # Random variance
    if !self.is_a?(Battle::Move::Confusion)
      random = 85 + @battle.pbRandom(16)
      multipliers[:final_damage_multiplier] *= random / 100.0
    end
    # STAB
    if type && user.pbHasType?(type)
      if user.hasActiveAbility?(:ADAPTABILITY)
        multipliers[:final_damage_multiplier] *= 2
      else
        multipliers[:final_damage_multiplier] *= 1.5
      end
    end
    # Type effectiveness
    multipliers[:final_damage_multiplier] *= target.damageState.typeMod.to_f / Effectiveness::NORMAL_EFFECTIVE
    # Burn
    if user.status == :BURN && physicalMove? && damageReducedByBurn? &&
       !user.hasActiveAbility?(:GUTS)
      multipliers[:final_damage_multiplier] /= 2
    end
    # Frostbite
    if user.status == :FROSTBITE && specialMove? && damageReducedByFrostbite?
      multipliers[:final_damage_multiplier] /= 2
    end
    # Aurora Veil, Reflect, Light Screen
    if !ignoresReflect? && !target.damageState.critical &&
       !user.hasActiveAbility?(:INFILTRATOR)
      if target.pbOwnSide.effects[PBEffects::AuroraVeil] > 0
        if @battle.pbSideBattlerCount(target) > 1
          multipliers[:final_damage_multiplier] *= 2 / 3.0
        else
          multipliers[:final_damage_multiplier] /= 2
        end
      elsif target.pbOwnSide.effects[PBEffects::Reflect] > 0 && physicalMove?
        if @battle.pbSideBattlerCount(target) > 1
          multipliers[:final_damage_multiplier] *= 2 / 3.0
        else
          multipliers[:final_damage_multiplier] /= 2
        end
      elsif target.pbOwnSide.effects[PBEffects::LightScreen] > 0 && specialMove?
        if @battle.pbSideBattlerCount(target) > 1
          multipliers[:final_damage_multiplier] *= 2 / 3.0
        else
          multipliers[:final_damage_multiplier] /= 2
        end
      end
    end
    # Minimize
    if target.effects[PBEffects::Minimize] && tramplesMinimize?
      multipliers[:final_damage_multiplier] *= 2
    end
    # Glaive Rush
    multipliers[:final_damage_multiplier] *= 2 if target.effects[PBEffects::GlaiveRush] > 0
    # Move-specific base damage modifiers
    multipliers[:base_damage_multiplier] = pbBaseDamageMultiplier(multipliers[:base_damage_multiplier], user, target)
    # Move-specific final damage modifiers
    multipliers[:final_damage_multiplier] = pbModifyDamage(multipliers[:final_damage_multiplier], user, target)
  end
end

#===============================================================================
# Pokémon party visuals
#===============================================================================
class PokemonParty_Scene
  def pbChooseFaintedPokemon(switching = true, initialsel = -1, canswitch = 0)
    @activecmd = initialsel if initialsel >= 0
    pbRefresh
    loop do
      Graphics.update
      Input.update
      self.update
      oldsel = @activecmd
      key = -1
      key = Input::DOWN if Input.repeat?(Input::DOWN)
      key = Input::RIGHT if Input.repeat?(Input::RIGHT)
      key = Input::LEFT if Input.repeat?(Input::LEFT)
      key = Input::UP if Input.repeat?(Input::UP)
      if key >= 0
        @activecmd = pbChangeSelection(key, @activecmd)
      end
      if @activecmd != oldsel   # Changing selection
        pbPlayCursorSE
        numsprites = Settings::MAX_PARTY_SIZE + ((@multiselect) ? 2 : 1)
        numsprites.times do |i|
          @sprites["pokemon#{i}"].selected = (i == @activecmd)
        end
      end
      cancelsprite = Settings::MAX_PARTY_SIZE + ((@multiselect) ? 1 : 0)
      if Input.trigger?(Input::SPECIAL) && @can_access_storage && canswitch != 2
        pbPlayDecisionSE
        pbFadeOutIn {
          scene = PokemonStorageScene.new
          screen = PokemonStorageScreen.new(scene, $PokemonStorage)
          screen.pbStartScreen(0)
          pbHardRefresh
        }
      elsif Input.trigger?(Input::ACTION) && canswitch == 1 && @activecmd != cancelsprite
        pbPlayDecisionSE
        return [1, @activecmd]
      elsif Input.trigger?(Input::ACTION) && canswitch == 2
        return -1
      elsif Input.trigger?(Input::BACK)
        pbPlayCloseMenuSE if !switching
        return -1
      elsif Input.trigger?(Input::USE)
        if @activecmd == cancelsprite
          (switching) ? pbPlayDecisionSE : pbPlayCloseMenuSE
          return -1
        else
          pbPlayDecisionSE
          ret = -1
          commands = [_INTL("Select"),_INTL("Summary"),_INTL("Cancel")]
          loop do 
            ret = pbShowCommands(_INTL("{1} is selected.", @party[@activecmd].name), commands)
            if ret == 1
              pbSummary(@activecmd,true) 
            else
              break
            end
          end
          next if ret == 2 || ret == -1
          return @activecmd
        end
      end
    end
  end
end
