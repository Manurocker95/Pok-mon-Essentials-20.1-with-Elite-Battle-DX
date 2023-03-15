# Universal Tutor Move
class Pokemon
  def compatible_with_move?(move_id)
    move_data = GameData::Move.try_get(move_id)
    universal_move = [:TERABLAST]
    return move_data && (species_data.tutor_moves.include?(move_data.id) || 
                        universal_move.include?(move_data.id))
  end
end

#===============================================================================
# If attack misses, user takes crash damage of 1/2 of max HP.
# 30% chances of confusing target
# And can take crash damage if target protected or immune
# (Axe Kick)
#===============================================================================
class Battle::Move::InflictConfuseCrashDamageIfFailsUnusableInGravity < Battle::Move::ConfuseTarget
  def recoilMove?;        return true; end
  def pbRecoilDamage(user, target); return (user.totalhp / 2);    end
  def pbCrashDamage(user)
    return if !user.takesIndirectDamage?
    @battle.pbDisplay(_INTL("{1} kept going and crashed!", user.pbThis))
    @battle.scene.pbDamageAnimation(user)
    dmg = pbRecoilDamage(user)
    user.pbReduceHP(dmg, false)
    user.pbItemHPHealCheck
    user.pbFaint if user.fainted?
  end
end
#===============================================================================
# Starts hail/snow weather, then user switches out. Ignores trapping moves.
# (Chilly Reception)
#===============================================================================
class Battle::Move::SwitchOutUserWeatherHailMove < Battle::Move::WeatherMove#Battle::Move
  def initialize(battle, move)
    super
    @weatherType = :Hail
  end
  def pbDisplayUseMessage(user)
    @battle.pbDisplayBrief(_INTL("{1} is preparing to tell a chillingly bad joke!", user.pbThis))
    super
  end
  def pbFailsAgainstTarget?(user, target, show_message)
    if !@battle.futureSight &&
       @battle.positions[target.index].effects[PBEffects::FutureSightCounter] > 0
      @battle.pbDisplay(_INTL("But it failed!")) if show_message
      return true
    end
    if user.effects[PBEffects::Taunt] > 0
      @battle.pbDisplay(_INTL("{1} can't use {2} after the taunt!",user.pbThis,@name))
      return true
    end
    return false
  end
  def pbEndOfMoveUsageEffect(user, targets, numHits, switchedBattlers)
    return if user.fainted?
    @weatherType = :Hail if @weatherType != :Hail
    @battle.pbDisplay(_INTL("{1} went back to {2}!", user.pbThis,
                            @battle.pbGetOwnerName(user.index)))
    @battle.pbPursuit(user.index)
    return if user.fainted?
    newPkmn = @battle.pbGetReplacementPokemonIndex(user.index)   # Owner chooses
    return if newPkmn < 0
    @battle.pbRecallAndReplace(user.index, newPkmn)
    @battle.pbClearChoice(user.index)   # Replacement Pokémon does nothing this round
    @battle.moldBreaker = false
    @battle.pbOnBattlerEnteringBattle(user.index)
    switchedBattlers.push(user.index)
  end
end
#===============================================================================
# Increase damage 30% if the move is super effective to target 
# (Collision Course,Electro Drift)
#===============================================================================
class Battle::Move::IncreaseDamageIfSuperEffective < Battle::Move
  def pbBaseDamage(baseDmg, user, target)
    baseDmg *= 1.3 if Effectiveness.super_effective?(target.damageState.typeMod)
    return baseDmg
  end
end
#===============================================================================
# User and allies ability becomes target ability. (Doodle)
#===============================================================================
# role play
class Battle::Move::SetUserAlliesAbilityToTargetAbility < Battle::Move
  # def ignoresSubstitute?(user); return true; end

  def pbMoveFailed?(user, targets)
    if user.unstoppableAbility?
      @battle.pbDisplay(_INTL("But it failed!"))
      return true
    end
    return false
  end

  def pbFailsAgainstTarget?(user, target, show_message)
    if !target.ability || user.ability == target.ability
      @battle.pbDisplay(_INTL("But it failed!")) if show_message
      return true
    end
    if target.ungainableAbility? ||
       [:POWEROFALCHEMY, :RECEIVER, :TRACE, :WONDERGUARD].include?(target.ability_id)
      @battle.pbDisplay(_INTL("But it failed!")) if show_message
      return true
    end
    return false
  end
  
  def pbEffectAgainstTarget(user, target)
    @battle.allSameSideBattlers(user).each do |b|
      @battle.pbShowAbilitySplash(b, true, false)
      oldAbil = b.ability
      b.ability = target.ability
      @battle.pbReplaceAbilitySplash(b)
      Graphics.frame_rate.times { @battle.scene.pbUpdate }
      @battle.pbHideAbilitySplash(b)
      b.pbOnLosingAbility(oldAbil)
      b.pbTriggerAbilityOnGainingIt
    end
    @battle.pbDisplay(_INTL("{1} copied {2}'s {3} Ability!",
    user.pbThis, target.pbThis(true), target.abilityName))
  end
end
#===============================================================================
# User loses their Electric type. Fails if user is not Electric-type. (Double Shock)
#===============================================================================
class Battle::Move::UserLosesElectricType < Battle::Move
  def pbMoveFailed?(user, targets)
    if !user.pbHasType?(:ELECTRIC)
      @battle.pbDisplay(_INTL("But it failed!"))
      return true
    end
    return false
  end

  def pbEffectAfterAllHits(user, target)
    if !user.effects[PBEffects::DoubleShock]
      user.effects[PBEffects::DoubleShock] = true
      @battle.pbDisplay(_INTL("{1} used up all its electricity!", user.pbThis))
    end
  end
end
#===============================================================================
# Reduces the user's HP by half of max, and raise Attack, Sp. Atk, and Speed 2 stages.
# (Fillet Away)
#===============================================================================
class Battle::Move::RaiseUserAtk2SpAtk2Speed2LoseHalfOfTotalHP < Battle::Move
  def canSnatch?; return true; end

  def pbMoveFailed?(user, targets)
    hpLoss = [user.totalhp / 2, 1].max
    if user.hp <= hpLoss
      @battle.pbDisplay(_INTL("But it failed!"))
      return true
    end
    return true if !(user.pbCanRaiseStatStage?(:ATTACK, user, self, true) &&
                     user.pbCanRaiseStatStage?(:SPECIAL_ATTACK, user, self, true) &&
                     user.pbCanRaiseStatStage?(:SPEED, user, self, true))
    return false
  end

  def pbEffectGeneral(user)
    hpLoss = [user.totalhp / 2, 1].max
    user.pbReduceHP(hpLoss, false, false)
    if user.hasActiveAbility?(:CONTRARY)
      [:ATTACK,:SPECIAL_ATTACK,:SPEED].each{|stat|
        2.times do
          user.stages[stat] -= 1 if !user.statStageAtMin?(stat)
        end
      }
      user.statsLoweredThisRound = true
      user.statsDropped = true
      @battle.pbCommonAnimation("StatDown", user)
      @battle.pbDisplay(_INTL("{1} cut its own HP and minimized its Attack, Sp. Atk, and Speed!", user.pbThis))
    else
      [:ATTACK,:SPECIAL_ATTACK,:SPEED].each{|stat|
        2.times do
          user.stages[stat] += 1 if !user.statStageAtMax?(stat)
        end
      }
      user.statsRaisedThisRound = true
      @battle.pbCommonAnimation("StatUp", user)
      @battle.pbDisplay(_INTL("{1} cut its own HP and maximized its Attack, Sp. Atk, and Speed!", user.pbThis))
    end
    user.pbItemHPHealCheck
  end
end
#===============================================================================
# makes any attacks directed to the user to always hit and 
# deal double the damage in the next turn.
# (Glaive Rush)
#===============================================================================
class Battle::Move::DoubleNextReceiveDamageAndNeverMiss < Battle::Move
  def pbEndOfMoveUsageEffect(user, targets, numHits, switchedBattlers)
    return if user.fainted?
    user.effects[PBEffects::GlaiveRush] = 2
  end
end
#===============================================================================
# Inflict damage and removes the current terrain.
# (Ice Spinner)
#===============================================================================
class Battle::Move::RemoveTerrainIceSpinner < Battle::Move
  def pbEffectGeneral(user)
    case @battle.field.terrain
    when :Electric
      @battle.pbDisplay(_INTL("The electricity disappeared from the battlefield."))
    when :Grassy
      @battle.pbDisplay(_INTL("The grass disappeared from the battlefield."))
    when :Misty
      @battle.pbDisplay(_INTL("The mist disappeared from the battlefield."))
    when :Psychic
      @battle.pbDisplay(_INTL("The weirdness disappeared from the battlefield."))
    end
    @battle.field.terrain = :None
    @battle.allBattlers.each { |battler| battler.pbAbilityOnTerrainChange }
  end
end
#===============================================================================
# Increase 50 Damage for each time party members faint
# (Last Respect)
#===============================================================================
class Battle::Move::IncreaseDamageEachFaintedAllies < Battle::Move
  def pbBaseDamage(baseDmg, user, target)
    # user.battle.pbParty(user.idxOwnSide).each { |b| numFainted += 1 if b.fainted? }
    # numFainted -= $game_temp.fainted_member[user.idxOwnSide]
    numFainted = @battle.getFaintedCount(user)
    return baseDmg if numFainted <= 0
    baseDmg += baseDmg * numFainted
    return baseDmg
  end
end
#===============================================================================
# Scatters coins that the player picks up after winning the battle
# Lower user special attack 1 stage
# (Make It Rain)
#===============================================================================
class Battle::Move::AddMoneyGainedFromBattleLowerUserSpAtk1 < Battle::Move::LowerUserSpAtk1
  def pbEffectGeneral(user)
    if user.pbOwnedByPlayer?
      @battle.field.effects[PBEffects::PayDay] += 5 * user.level
    end
    @battle.pbDisplay(_INTL("Coins were scattered everywhere!"))
  end
end
#===============================================================================
# Removes trapping moves, entry hazards and Leech Seed on user/user's side.
# Poisons all opposing Pokémon. (Mortal Spin)
#===============================================================================
class Battle::Move::RemoveUserBindingAndEntryHazardsPoisonTarget < Battle::Move::PoisonTarget
  def pbEffectAfterAllHits(user, target)
    return if user.fainted? || target.damageState.unaffected
    if user.effects[PBEffects::Trapping] > 0
      trapMove = GameData::Move.get(user.effects[PBEffects::TrappingMove]).name
      trapUser = @battle.battlers[user.effects[PBEffects::TrappingUser]]
      @battle.pbDisplay(_INTL("{1} got free of {2}'s {3}!", user.pbThis, trapUser.pbThis(true), trapMove))
      user.effects[PBEffects::Trapping]     = 0
      user.effects[PBEffects::TrappingMove] = nil
      user.effects[PBEffects::TrappingUser] = -1
    end
    if user.effects[PBEffects::LeechSeed] >= 0
      user.effects[PBEffects::LeechSeed] = -1
      @battle.pbDisplay(_INTL("{1} shed Leech Seed!", user.pbThis))
    end
    if user.pbOwnSide.effects[PBEffects::StealthRock]
      user.pbOwnSide.effects[PBEffects::StealthRock] = false
      @battle.pbDisplay(_INTL("{1} blew away stealth rocks!", user.pbThis))
    end
    if user.pbOwnSide.effects[PBEffects::Spikes] > 0
      user.pbOwnSide.effects[PBEffects::Spikes] = 0
      @battle.pbDisplay(_INTL("{1} blew away spikes!", user.pbThis))
    end
    if user.pbOwnSide.effects[PBEffects::ToxicSpikes] > 0
      user.pbOwnSide.effects[PBEffects::ToxicSpikes] = 0
      @battle.pbDisplay(_INTL("{1} blew away poison spikes!", user.pbThis))
    end
    if user.pbOwnSide.effects[PBEffects::StickyWeb]
      user.pbOwnSide.effects[PBEffects::StickyWeb] = false
      @battle.pbDisplay(_INTL("{1} blew away sticky webs!", user.pbThis))
    end
  end
end
#===============================================================================
# Deal damage and increase the user's stat by 1 stage depends on Tatsugiri. 
# (Order Up)
#===============================================================================
class Battle::Move::RaiseUserStat1Tatsugiri < Battle::Move
  def pbEffectGeneral(user)
    if user.effects[PBEffects::CommanderDondozo] >= 0
      stat = [:ATTACK,:DEFENSE,:SPEED][user.effects[PBEffects::CommanderDondozo]]
      user.pbRaiseStatStage(stat, 1, user, true) if user.pbCanRaiseStatStage?(stat, user, self)
    end
  end
end
#===============================================================================
# Hits 10 times. (Population Bomb)
#===============================================================================
class Battle::Move::HitTenTimesPopulationBomb < Battle::Move
  def multiHitMove?;            return true; end
  def pbNumHits(user, targets)
    number = 10
    number = 10 - rand(7) if user.hasActiveItem?(:LOADEDDICE)
    return number
  end

  def successCheckPerHit?
    return @accCheckPerHit
  end

  def pbOnStartUse(user, targets)
    @accCheckPerHit = !user.hasActiveAbility?(:SKILLLINK) && !user.hasActiveItem?(:LOADEDDICE)
  end
end
#===============================================================================
# Its power increases by 50 each time the user was hit during a battle. (Rage Fist)
#===============================================================================
class Battle::Move::IncreaseDamage50EachGotHit < Battle::Move
  def pbBaseDamage(baseDmg, user, target)
    rage_hit = @battle.getBattlerHit(user)
    dmg = [baseDmg + 50  * rage_hit,350].min
    return dmg
  end
end
#===============================================================================
# Type depends on the user's form. (Raging Bull)
#===============================================================================
class Battle::Move::TypeDependsOnUserForm < Battle::Move::RemoveScreens
  def pbBaseType(user)
    ret = :NORMAL
    if user.species == :TAUROS
      case user.form
      when 1 then ret = :FIGHTING
      when 2 then ret = :FIRE
      when 3 then ret = :WATER
      end
    end
    return ret
  end
end
#===============================================================================
# Revive one fainted pokémon from party up to 1/2 HP total.
# (Revival Blessing)
#===============================================================================
class Battle::Move::RevivePokemonHalfHP < Battle::Move
  def healingMove?;            return true; end
  def pbMoveFailed?(user, targets)
    numFainted = 0
    user.battle.pbParty(user.idxOwnSide).each { |b| numFainted += 1 if b.fainted? }
    if numFainted == 0
      @battle.pbDisplay(_INTL("But it failed!"))
      return true
    end
    return false
  end
  def pbEndOfMoveUsageEffect(user, targets, numHits, switchedBattlers)
    return if user.fainted?
    numFainted = 0
    user.battle.pbParty(user.idxOwnSide).each { |b| numFainted += 1 if b.fainted? }
    return if numFainted == 0
    @battle.pbChooseFaintedPokemonParty(user.idxOwnSide)
  end
end

#===============================================================================
# Deal Damage and give damage 1/8 of max HP at the end of each round,
# damage become 1/4 if target type is steel or water.
# (Salt Cure)
#===============================================================================
class Battle::Move::StartSaltCureTarget < Battle::Move
  def pbFailsAgainstTarget?(user, target, show_message)
    if target.effects[PBEffects::SaltCure]
      @battle.pbDisplay(_INTL("{1} evaded the attack!", target.pbThis)) if show_message
      return true
    end
    return false
  end

  def pbMissMessage(user, target)
    @battle.pbDisplay(_INTL("{1} evaded the attack!", target.pbThis))
    return true
  end

  def pbEffectAgainstTarget(user, target)
    target.effects[PBEffects::SaltCure] = true
    @battle.pbDisplay(_INTL("{1} is being salt cured!", target.pbThis))
  end
end
#===============================================================================
# User turns 1/2 of max HP into a substitute and Switch Out. (Shed Tail)
#===============================================================================
class Battle::Move::UserMakeSubstituteSwitchOut < Battle::Move::UserMakeSubstitute
  def pbMoveFailed?(user, targets)
    if user.effects[PBEffects::Substitute] > 0
      @battle.pbDisplay(_INTL("{1} already has a substitute!", user.pbThis))
      return true
    end
    if !@battle.pbCanChooseNonActive?(user.index)
      @battle.pbDisplay(_INTL("But it failed!"))
      return true
    end
    @subLife = [user.totalhp / 2, 1].max
    if user.hp <= @subLife
      @battle.pbDisplay(_INTL("But it does not have enough HP left to make a substitute!"))
      return true
    end
    return false
  end

  def pbEffectGeneral(user)
    @battle.pbDisplay(_INTL("{1} shed its tail to create a decoy!", user.pbThis))
  end

  def pbEndOfMoveUsageEffect(user, targets, numHits, switchedBattlers)
    return if user.fainted? || numHits == 0
    return if !@battle.pbCanChooseNonActive?(user.index)
    @battle.pbDisplay(_INTL("{1} went back to {2}!", user.pbThis,
                            @battle.pbGetOwnerName(user.index)))
    @battle.pbPursuit(user.index)
    return if user.fainted?
    newPkmn = @battle.pbGetReplacementPokemonIndex(user.index)   # Owner chooses
    return if newPkmn < 0
    @battle.pbRecallAndReplace(user.index, newPkmn)
    @battle.pbClearChoice(user.index)   # Replacement Pokémon does nothing this round
    @battle.moldBreaker = false
    @battle.pbOnBattlerEnteringBattle(user.index)
    switchedBattlers.push(user.index)
    user.effects[PBEffects::Trapping]     = 0
    user.effects[PBEffects::TrappingMove] = nil
    user.effects[PBEffects::Substitute]   = @subLife
  end
end
#===============================================================================
# User is protected against damaging moves this round. Decreases the Speed of
# the user of a stopped contact move by 1 stages. (Silk Trap)
#===============================================================================
class Battle::Move::ProtectUserFromDamagingSilkTrap < Battle::Move::ProtectMove
  def initialize(battle, move)
    super
    @effect = PBEffects::SilkTrap
  end
end
#===============================================================================
# Raise one of target's stats and lower another one of target's stat. 
# (Spicy Extract)
#===============================================================================
class Battle::Move::RaiseAtkLowerDefTargetStat < Battle::Move
  def canMagicCoat?; return true; end

  def initialize(battle, move)
    super
    @statDown = [:DEFENSE,1]
    @statUp = [:ATTACK,1]
  end

  def pbFailsAgainstTarget?(user, target, show_message)
    return false if damagingMove?
    return !target.pbCanLowerStatStage?(@statDown[0], user, self, show_message) && 
           !target.pbCanRaiseStatStage?(@statUp[0], user, self, show_message) 
  end

  def pbEffectAgainstTarget(user, target)
    return if damagingMove?
    target.pbLowerStatStage(@statDown[0], @statDown[1], user)
    target.pbRaiseStatStage(@statUp[0], @statUp[1], user)
  end

  def pbAdditionalEffect(user, target)
    return if target.damageState.substitute
    return if !target.pbCanLowerStatStage?(@statDown[0], user, self) && 
              !target.pbCanRaiseStatStage?(@statUp[0], user, self) 
    target.pbLowerStatStage(@statDown[0], @statDown[1], user)
    target.pbRaiseStatStage(@statUp[0], @statUp[1], user)
  end
end
#===============================================================================
# Change its type if teraslize and tera type. 
# This move becomes physical or special, whichever will deal
# more damage (only considers stats, stat stages and Wonder Room). Makes contact
# if it is a physical move. Has a different animation depending on the move's
# category. (Tera Blast)
#===============================================================================
class Battle::Move::CategoryDependsOnHigherDamageTera < Battle::Move
  def initialize(battle, move)
    super
    @calcCategory = 1
  end

  def physicalMove?(thisType = nil); return (@calcCategory == 0); end
  def specialMove?(thisType = nil);  return (@calcCategory == 1); end

  def pbOnStartUse(user, targets)
    target = targets[0]
    stageMul = [2, 2, 2, 2, 2, 2, 2, 3, 4, 5, 6, 7, 8]
    stageDiv = [8, 7, 6, 5, 4, 3, 2, 2, 2, 2, 2, 2, 2]
    # Calculate user's effective attacking values
    attack_stage         = user.stages[:ATTACK] + 6
    real_attack          = (user.attack.to_f * stageMul[attack_stage] / stageDiv[attack_stage]).floor
    special_attack_stage = user.stages[:SPECIAL_ATTACK] + 6
    real_special_attack  = (user.spatk.to_f * stageMul[special_attack_stage] / stageDiv[special_attack_stage]).floor
    # Calculate target's effective defending values
    defense_stage         = target.stages[:DEFENSE] + 6
    real_defense          = (target.defense.to_f * stageMul[defense_stage] / stageDiv[defense_stage]).floor
    special_defense_stage = target.stages[:SPECIAL_DEFENSE] + 6
    real_special_defense  = (target.spdef.to_f * stageMul[special_defense_stage] / stageDiv[special_defense_stage]).floor
    # Perform simple damage calculation
    physical_damage = real_attack.to_f / real_defense
    special_damage = real_special_attack.to_f / real_special_defense
    # Determine move's category
    if physical_damage == special_damage
      @calcCategry = @battle.pbRandom(2)
    else
      @calcCategory = (physical_damage > special_damage) ? 0 : 1
    end
  end

  def pbShowAnimation(id, user, targets, hitNum = 0, showAnimation = true)
    hitNum = 1 if physicalMove?
    super
  end
  def pbBaseType(user)
    ret = :NORMAL
    if PluginManager.installed?("ScarletVioletGimmick_TDW")
      ret = user.pokemon.tera_type[0] if user&.tera_active
    end
    return ret
  end
end
#===============================================================================
# Removes Substitutes, Spikes, Toxic Spikes, Stealth Rock, and Sticky Web 
# on both side. Raises user's Attack and Speed by 1 stage. (Tidy Up)
#===============================================================================
class Battle::Move::RemoveBothEntryHazardsRaiseAtkSpeed < Battle::Move
  def initialize(battle, move)
    super
    @statUp = [:ATTACK, 1, :SPEED, 1]
  end

  def pbEffectAfterAllHits(user, target)
    return if user.fainted? || target.damageState.unaffected
    tidy = false
    # user side
    if user.pbOwnSide.effects[PBEffects::StealthRock]
      user.pbOwnSide.effects[PBEffects::StealthRock] = false
      @battle.pbDisplay(_INTL("The pointed stones disappeared from around your team!"))
      tidy = true if !tidy
    end
    if user.pbOwnSide.effects[PBEffects::Spikes] > 0
      user.pbOwnSide.effects[PBEffects::Spikes] = 0
      @battle.pbDisplay(_INTL("The spikes disappeared from the ground around your team!"))
      tidy = true if !tidy
    end
    if user.pbOwnSide.effects[PBEffects::ToxicSpikes] > 0
      user.pbOwnSide.effects[PBEffects::ToxicSpikes] = 0
      @battle.pbDisplay(_INTL("The poison spikes disappeared from the ground around your team!"))
      tidy = true if !tidy
    end
    if user.pbOwnSide.effects[PBEffects::StickyWeb]
      user.pbOwnSide.effects[PBEffects::StickyWeb] = false
      @battle.pbDisplay(_INTL("The sticky web has disappeared from the ground around you!"))
      tidy = true if !tidy
    end
    @battle.allSameSideBattlers(user).each do |b|
      b.effects[PBEffects::Substitute] = 0
      tidy = true if !tidy
    end
    # opp side
    if user.pbOpposingSide.effects[PBEffects::StealthRock]
      user.pbOpposingSide.effects[PBEffects::StealthRock] = false
      @battle.pbDisplay(_INTL("The pointed stones disappeared from around the opposing team!"))
      tidy = true if !tidy
    end
    if user.pbOpposingSide.effects[PBEffects::Spikes] > 0
      user.pbOpposingSide.effects[PBEffects::Spikes] = 0
      @battle.pbDisplay(_INTL("The spikes disappeared from the ground around the opposing team!"))
      tidy = true if !tidy
    end
    if user.pbOpposingSide.effects[PBEffects::ToxicSpikes] > 0
      user.pbOpposingSide.effects[PBEffects::ToxicSpikes] = 0
      @battle.pbDisplay(_INTL("The poison spikes disappeared from the ground around the opposing team!"))
      tidy = true if !tidy
    end
    if user.pbOpposingSide.effects[PBEffects::StickyWeb]
      user.pbOpposingSide.effects[PBEffects::StickyWeb] = false
      @battle.pbDisplay(_INTL("The sticky web has disappeared from the ground around the opposing team!"))
    end
    @battle.allOtherSideBattlers(user).each do |b|
      b.effects[PBEffects::Substitute] = 0
      tidy = true if !tidy
    end
    @battle.pbDisplay(_INTL("Tidying up complete!")) if tidy
    showAnim = true
    (@statUp.length / 2).times do |i|
      if user.pbCanRaiseStatStage?(@statUp[i * 2], user, self)
        showAnim = false if user.pbRaiseStatStage(@statUp[i * 2], @statUp[(i * 2) + 1], user, showAnim)
      else
        @battle.pbDisplay(_INTL("{1}'s stats won't go any higher!", user.pbThis))
      end
    end
  end
end
#===============================================================================
# Hits the target three times.
#===============================================================================
class Battle::Move::HitThreeTimes < Battle::Move
  def multiHitMove?;            return true; end
  def pbNumHits(user, targets); return 3;    end
end
#===============================================================================
# Increase Base Power while Sunny (Hydro Steam)
#===============================================================================
class Battle::Move::BPRaiseWhileSunny < Battle::Move
  def pbBaseDamage(baseDmg, user, target)
    baseDmg *= 1.5 if [:Sun, :HarshSun].include?(user.effectiveWeather)
    return baseDmg
  end
end

#===============================================================================
# Increase Base Power while Electric Terrain (Psyblade)
#===============================================================================
class Battle::Move::BPRaiseWhileElectricTerrain < Battle::Move
  def pbBaseDamage(baseDmg, user, target)
    baseDmg *= 1.5 if @battle.field.terrain == :Electric
    return baseDmg
  end
end