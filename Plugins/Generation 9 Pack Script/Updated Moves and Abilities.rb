#===============================================================================
# Updated Move
#===============================================================================
#===============================================================================
# In wild battles, makes target flee. Fails if target is a higher level than the
# user.
# In trainer battles, target switches out.
# For status moves. (Roar, Whirlwind)
# Add guard dog
#===============================================================================
class Battle::Move::SwitchOutTargetStatusMove < Battle::Move
  alias guarddog_pbFailsAgainstTarget? pbFailsAgainstTarget?
  def pbFailsAgainstTarget?(user, target, show_message)
    if target.hasActiveAbility?(:GUARDDOG) && !target.affectedByMoldBreaker?
      if show_message
        @battle.pbShowAbilitySplash(target)
        if Battle::Scene::USE_ABILITY_SPLASH
          @battle.pbDisplay(_INTL("{1} anchors itself!", target.pbThis))
        else
          @battle.pbDisplay(_INTL("{1} anchors itself with {2}!", target.pbThis, target.abilityName))
        end
        @battle.pbHideAbilitySplash(target)
      end
      return true
    end
    return guarddog_pbFailsAgainstTarget?(user, target, show_message)
  end

  def pbSwitchOutTargetEffect(user, targets, numHits, switched_battlers)
    return if @battle.wildBattle? || !switched_battlers.empty?
    return if user.fainted? || numHits == 0
    targets.each do |b|
      next if b.fainted? || b.damageState.unaffected
      next if b.effects[PBEffects::Ingrain]
      next if b.hasActiveAbility?([:SUCTIONCUPS,:GUARDDOG]) && !b.affectedByMoldBreaker?
      newPkmn = @battle.pbGetReplacementPokemonIndex(b.index, true)   # Random
      next if newPkmn < 0
      @battle.pbRecallAndReplace(b.index, newPkmn, true)
      @battle.pbDisplay(_INTL("{1} was dragged out!", b.pbThis))
      @battle.pbClearChoice(b.index)   # Replacement Pokémon does nothing this round
      @battle.pbOnBattlerEnteringBattle(b.index)
      switched_battlers.push(b.index)
      break
    end
  end
end

#===============================================================================
# In wild battles, makes target flee. Fails if target is a higher level than the
# user.
# In trainer battles, target switches out.
# For damaging moves. (Circle Throw, Dragon Tail)
# Add guard dog
#===============================================================================
class Battle::Move::SwitchOutTargetDamagingMove < Battle::Move
  def pbFailsAgainstTarget?(user, target, show_message)
    if target.hasActiveAbility?(:GUARDDOG) && !target.affectedByMoldBreaker?
      if show_message
        @battle.pbShowAbilitySplash(target)
        if Battle::Scene::USE_ABILITY_SPLASH
          @battle.pbDisplay(_INTL("{1} anchors itself!", target.pbThis))
        else
          @battle.pbDisplay(_INTL("{1} anchors itself with {2}!", target.pbThis, target.abilityName))
        end
        @battle.pbHideAbilitySplash(target)
      end
      return true
    end
  end

  def pbSwitchOutTargetEffect(user, targets, numHits, switched_battlers)
    return if @battle.wildBattle? || !switched_battlers.empty?
    return if user.fainted? || numHits == 0
    targets.each do |b|
      next if b.fainted? || b.damageState.unaffected || b.damageState.substitute
      next if b.effects[PBEffects::Ingrain]
      next if b.hasActiveAbility?([:SUCTIONCUPS,:GUARDDOG]) && !b.affectedByMoldBreaker?
      newPkmn = @battle.pbGetReplacementPokemonIndex(b.index, true)   # Random
      next if newPkmn < 0
      @battle.pbRecallAndReplace(b.index, newPkmn, true)
      @battle.pbDisplay(_INTL("{1} was dragged out!", b.pbThis))
      @battle.pbClearChoice(b.index)   # Replacement Pokémon does nothing this round
      @battle.pbOnBattlerEnteringBattle(b.index)
      switched_battlers.push(b.index)
      break
    end
  end
end

# update Tailwind
# add wind rider
class Battle::Move::StartUserSideDoubleSpeed < Battle::Move
  def pbEffectGeneral(user)
    user.pbOwnSide.effects[PBEffects::Tailwind] = 4
    @battle.pbDisplay(_INTL("The Tailwind blew from behind {1}!", user.pbTeam(true)))
    # windrider = @battle.pbCheckGlobalAbility(:WINDRIDER)
    @battle.allSameSideBattlers.each { |b| 
     next if !b.hasActiveAbility?(:WINDRIDER) 
     if b && b.pbCanRaiseStatStage?(:ATTACK, b, self)
       @battle.pbShowAbilitySplash(b, true)
       b.pbRaiseStatStage(:ATTACK, 1, b)
       @battle.pbHideAbilitySplash(b)
     end
    }
  end
end
#===============================================================================
# Ally Switch will fail when used successfully by another ally Pokémon on the same turn.
#===============================================================================
class Battle::Move::UserSwapsPositionsWithAlly < Battle::Move
  def pbMoveFailed?(user, targets)
    if user.pbOwnSide.effects[PBEffects::AllySwitch]
      @battle.pbDisplay(_INTL("But it failed!"))
      return true
    end
    numTargets = 0
    @idxAlly = -1
    idxUserOwner = @battle.pbGetOwnerIndexFromBattlerIndex(user.index)
    user.allAllies.each do |b|
      next if @battle.pbGetOwnerIndexFromBattlerIndex(b.index) != idxUserOwner
      next if !b.near?(user)
      numTargets += 1
      @idxAlly = b.index
    end
    if numTargets != 1
      @battle.pbDisplay(_INTL("But it failed!"))
      return true
    end
    return false
  end
  def pbEffectGeneral(user)
    idxA = user.index
    idxB = @idxAlly
    if @battle.pbSwapBattlers(idxA, idxB)
      @battle.pbDisplay(_INTL("{1} and {2} switched places!",
                              @battle.battlers[idxB].pbThis, @battle.battlers[idxA].pbThis(true)))
      [idxA, idxB].each { |idx| @battle.pbEffectsOnBattlerEnteringPosition(@battle.battlers[idx]) }
    end
    user.pbOwnSide.effects[PBEffects::AllySwitch] = true
  end
end

# Fling give a base power of TM based of TM Move power
class Battle::Move::ThrowUserItemAtTarget < Battle::Move
  def pbCheckFlingSuccess(user)
    @willFail = false
    @willFail = true if !user.item || !user.itemActive? || user.unlosableItem?(user.item)
    return if @willFail
    @willFail = true if user.item.is_berry? && !user.canConsumeBerry?
    return if @willFail
    @willFail = user.item.flags.none? { |f| f[/^Fling_/i] } && !user.item.is_TR?
  end

  def pbBaseDamage(baseDmg, user, target)
    return 0 if !user.item
    user.item.flags.each do |flag|
      return [$~[1].to_i, 10].max if flag[/^Fling_(\d+)$/i]
    end
    if pkmn.item.is_TR?
      ret = GameData::Move.get(pkmn.item.move).base_damage
      ret = 10 if ret < 10
      return ret
    end
    return 10
  end
end
# Update for Loaded Dice
#===============================================================================
# Triple Kick
#===============================================================================
class Battle::Move::HitThreeTimesPowersUpWithEachHit < Battle::Move
  def pbOnStartUse(user, targets)
    @calcBaseDmg = 0
    @accCheckPerHit = !user.hasActiveAbility?(:SKILLLINK) && !user.hasActiveItem?(:LOADEDDICE)
  end
end
#===============================================================================
# Hits 2-5 times.
#===============================================================================
class Battle::Move::HitTwoToFiveTimes < Battle::Move
  def pbNumHits(user, targets)
    hitChances = [
      2, 2, 2, 2, 2, 2, 2,
      3, 3, 3, 3, 3, 3, 3,
      4, 4, 4,
      5, 5, 5
    ]
    r = @battle.pbRandom(hitChances.length)
    r = hitChances.length - 1 if user.hasActiveAbility?(:SKILLLINK)
    chances = hitChances[r]
    chances = 5 - rand(2) if user.hasActiveItem?(:LOADEDDICE)
    return chances
  end
end
#===============================================================================
# Hits 2-5 times in a row. If the move does not fail, increases the user's Speed
# by 1 stage and decreases the user's Defense by 1 stage. (Scale Shot)
#===============================================================================
class Battle::Move::HitTwoToFiveTimesRaiseUserSpd1LowerUserDef1 < Battle::Move
  def pbNumHits(user, targets)
    hitChances = [
      2, 2, 2, 2, 2, 2, 2,
      3, 3, 3, 3, 3, 3, 3,
      4, 4, 4,
      5, 5, 5
    ]
    r = @battle.pbRandom(hitChances.length)
    r = hitChances.length - 1 if user.hasActiveAbility?(:SKILLLINK)
    chances = hitChances[r]
    chances = 5 - rand(2) if user.hasActiveItem?(:LOADEDDICE)
    return chances
  end
end

# updated for ability shield
#-------------------------------------------------------------------------------
# Worry Seed
#-------------------------------------------------------------------------------
class Battle::Move::SetTargetAbilityToInsomnia < Battle::Move
  alias abilityshield_pbFailsAgainstTarget? pbFailsAgainstTarget?
  def pbFailsAgainstTarget?(user, target, show_message)
    ret = false
    if target.hasActiveItem?(:ABILITYSHIELD)
      itemname = GameData::Item.get(target.item).name
      @battle.pbDisplay(_INTL("{1}'s Ability is protected by the effects of its {2}!",target.pbThis,itemname)) if show_message
      return true
    end
    ret = abilityshield_pbFailsAgainstTarget?(user, target, show_message)
    return ret
  end
end
#-------------------------------------------------------------------------------
# Simple Beam
#-------------------------------------------------------------------------------
class Battle::Move::SetTargetAbilityToSimple < Battle::Move
  alias abilityshield_pbFailsAgainstTarget? pbFailsAgainstTarget?
  def pbFailsAgainstTarget?(user, target, show_message)
    ret = false
    if target.hasActiveItem?(:ABILITYSHIELD)
      itemname = GameData::Item.get(target.item).name
      @battle.pbDisplay(_INTL("{1}'s Ability is protected by the effects of its {2}!",target.pbThis,itemname)) if show_message
      return true
    end
    ret = abilityshield_pbFailsAgainstTarget?(user, target, show_message)
    return ret
  end
end
#-------------------------------------------------------------------------------
# Skill Swap
#-------------------------------------------------------------------------------
class Battle::Move::UserTargetSwapAbilities < Battle::Move
  alias abilityshield_pbFailsAgainstTarget? pbFailsAgainstTarget?
  def pbFailsAgainstTarget?(user, target, show_message)
    ret = false
    if target.hasActiveItem?(:ABILITYSHIELD)
      itemname = GameData::Item.get(target.item).name
      @battle.pbDisplay(_INTL("{1}'s Ability is protected by the effects of its {2}!",target.pbThis,itemname)) if show_message
      return true
    end
    ret = abilityshield_pbFailsAgainstTarget?(user, target, show_message)
    return ret
  end
end
#-------------------------------------------------------------------------------
# Gastro Acid
#-------------------------------------------------------------------------------
class Battle::Move::NegateTargetAbility < Battle::Move
  alias abilityshield_pbFailsAgainstTarget? pbFailsAgainstTarget?
  def pbFailsAgainstTarget?(user, target, show_message)
    ret = false
    if target.hasActiveItem?(:ABILITYSHIELD)
      itemname = GameData::Item.get(target.item).name
      @battle.pbDisplay(_INTL("{1}'s Ability is protected by the effects of its {2}!",target.pbThis,itemname)) if show_message
      return true
    end
    ret = abilityshield_pbFailsAgainstTarget?(user, target, show_message)
    return ret
  end
end
#-------------------------------------------------------------------------------
# Core Enforcer
#-------------------------------------------------------------------------------
class Battle::Move::NegateTargetAbilityIfTargetActed < Battle::Move
  def pbFailsAgainstTarget?(user, target, show_message)
    if target.hasActiveItem?(:ABILITYSHIELD)
      itemname = GameData::Item.get(target.item).name
      @battle.pbDisplay(_INTL("{1}'s Ability is protected by the effects of its {2}!",target.pbThis,itemname)) if show_message
      return true
    end
    return false
  end
end

# Update for Quark Drive
#===============================================================================
# Decreases the target's evasion by 1 stage. Ends all barriers and entry
# hazards for the target's side OR on both sides. (Defog)
#===============================================================================
class Battle::Move::LowerTargetEvasion1RemoveSideEffects < Battle::Move::TargetStatDownMove
  alias quarkdrive_pbEffectAgainstTarget pbEffectAgainstTarget
  def pbEffectAgainstTarget(user, target)
    quarkdrive_pbEffectAgainstTarget(user, target)
    @battle.allBattlers.each { |battler| battler.pbAbilityOnTerrainChange }
  end
end


#===============================================================================
# Updated Abilities
#===============================================================================
# add lingering aroma and ability shield
Battle::AbilityEffects::OnBeingHit.add(:MUMMY,
  proc { |ability, user, target, move, battle|
    next if !move.pbContactMove?(user)
    next if user.fainted?
    next if user.unstoppableAbility? || user.ability == ability || user.ability == :LINGERINGAROMA
    next if user.hasActiveItem?(:ABILITYSHIELD)
    oldAbil = nil
    battle.pbShowAbilitySplash(target) if user.opposes?(target)
    if user.affectedByContactEffect?(Battle::Scene::USE_ABILITY_SPLASH)
      oldAbil = user.ability
      battle.pbShowAbilitySplash(user, true, false) if user.opposes?(target)
      user.ability = ability
      battle.pbReplaceAbilitySplash(user) if user.opposes?(target)
      if Battle::Scene::USE_ABILITY_SPLASH
        battle.pbDisplay(_INTL("{1}'s Ability became {2}!", user.pbThis, user.abilityName))
      else
        battle.pbDisplay(_INTL("{1}'s Ability became {2} because of {3}!",
           user.pbThis, user.abilityName, target.pbThis(true)))
      end
      battle.pbHideAbilitySplash(user) if user.opposes?(target)
    end
    battle.pbHideAbilitySplash(target) if user.opposes?(target)
    user.pbOnLosingAbility(oldAbil)
    user.pbTriggerAbilityOnGainingIt
  }
)

Battle::AbilityEffects::OnBeingHit.add(:WANDERINGSPIRIT,
  proc { |ability, user, target, move, battle|
    next if !move.pbContactMove?(user)
    next if user.ungainableAbility? || [:RECEIVER, :WONDERGUARD].include?(user.ability_id)
    next if user.hasActiveItem?(:ABILITYSHIELD)
    oldUserAbil   = nil
    oldTargetAbil = nil
    battle.pbShowAbilitySplash(target) if user.opposes?(target)
    if user.affectedByContactEffect?(Battle::Scene::USE_ABILITY_SPLASH)
      battle.pbShowAbilitySplash(user, true, false) if user.opposes?(target)
      oldUserAbil   = user.ability
      oldTargetAbil = target.ability
      user.ability   = oldTargetAbil
      target.ability = oldUserAbil
      if user.opposes?(target)
        battle.pbReplaceAbilitySplash(user)
        battle.pbReplaceAbilitySplash(target)
      end
      if Battle::Scene::USE_ABILITY_SPLASH
        battle.pbDisplay(_INTL("{1} swapped Abilities with {2}!", target.pbThis, user.pbThis(true)))
      else
        battle.pbDisplay(_INTL("{1} swapped its {2} Ability with {3}'s {4} Ability!",
           target.pbThis, user.abilityName, user.pbThis(true), target.abilityName))
      end
      if user.opposes?(target)
        battle.pbHideAbilitySplash(user)
        battle.pbHideAbilitySplash(target)
      end
    end
    battle.pbHideAbilitySplash(target) if user.opposes?(target)
    user.pbOnLosingAbility(oldUserAbil)
    target.pbOnLosingAbility(oldTargetAbil)
    user.pbTriggerAbilityOnGainingIt
    target.pbTriggerAbilityOnGainingIt
  }
)

Battle::AbilityEffects::OnSwitchIn.add(:NEUTRALIZINGGAS,
  proc { |ability, battler, battle, switch_in|
    battle.pbShowAbilitySplash(battler, true)
    battle.pbHideAbilitySplash(battler)
    battle.pbDisplay(_INTL("Neutralizing gas filled the area!"))
    battle.allBattlers.each do |b|
      if b.hasActiveItem?(:ABILITYSHIELD)
        itemname = GameData::Item.get(target.item).name
        @battle.pbDisplay(_INTL("{1}'s Ability is protected by the effects of its {2}!",b.pbThis,itemname))
        next
      end
      # Slow Start - end all turn counts
      b.effects[PBEffects::SlowStart] = 0
      # Truant - let b move on its first turn after Neutralizing Gas disappears
      b.effects[PBEffects::Truant] = false
      # Gorilla Tactics - end choice lock
      if !b.hasActiveItem?([:CHOICEBAND, :CHOICESPECS, :CHOICESCARF])
        b.effects[PBEffects::ChoiceBand] = nil
      end
      # Illusion - end illusions
      if b.effects[PBEffects::Illusion]
        b.effects[PBEffects::Illusion] = nil
        if !b.effects[PBEffects::Transform]
          battle.scene.pbChangePokemon(b, b.pokemon)
          battle.pbDisplay(_INTL("{1}'s {2} wore off!", b.pbThis, b.abilityName))
          battle.pbSetSeen(b)
        end
      end
    end
    # Trigger items upon Unnerve being negated
    battler.ability_id = nil   # Allows checking if Unnerve was active before
    had_unnerve = battle.pbCheckGlobalAbility(:UNNERVE)
    battler.ability_id = :NEUTRALIZINGGAS
    if had_unnerve && !battle.pbCheckGlobalAbility(:UNNERVE)
      battle.allBattlers.each { |b| b.pbItemsOnUnnerveEnding }
    end
  }
)
# updated ability in gen 9
Battle::AbilityEffects::OnSwitchIn.add(:DAUNTLESSSHIELD,
  proc { |ability, battler, battle, switch_in|
    next if battle.isBattlerActivedAbility?(battler)
    battler.pbRaiseStatStageByAbility(:DEFENSE, 1, battler)
    battle.setBattlerActivedAbility(battler)
  }
)
Battle::AbilityEffects::OnSwitchIn.add(:INTREPIDSWORD,
  proc { |ability, battler, battle, switch_in|
    next if battle.isBattlerActivedAbility?(battler)
    battler.pbRaiseStatStageByAbility(:ATTACK, 1, battler)
    battle.setBattlerActivedAbility(battler)
  }
)

#===============================================================================
# In Gen 9, Synchronize appears to have no effect on the Nature of wild Pokémon.
def pbGenerateWildPokemon(species, level, isRoamer = false)
  genwildpoke = Pokemon.new(species, level)
  # Give the wild Pokémon a held item
  items = genwildpoke.wildHoldItems
  first_pkmn = $player.first_pokemon
  chances = [50, 5, 1]
  if first_pkmn
    case first_pkmn.ability_id
    when :COMPOUNDEYES
      chances = [60, 20, 5]
    when :SUPERLUCK
      chances = [60, 20, 5] if Settings::MORE_ABILITIES_AFFECT_WILD_ENCOUNTERS
    end
  end
  itemrnd = rand(100)
  if (items[0] == items[1] && items[1] == items[2]) || itemrnd < chances[0]
    genwildpoke.item = items[0].sample
  elsif itemrnd < (chances[0] + chances[1])
    genwildpoke.item = items[1].sample
  elsif itemrnd < (chances[0] + chances[1] + chances[2])
    genwildpoke.item = items[2].sample
  end
  # Improve chances of shiny Pokémon with Shiny Charm and battling more of the
  # same species
  shiny_retries = 0
  shiny_retries += 2 if $bag.has?(:SHINYCHARM)
  if Settings::HIGHER_SHINY_CHANCES_WITH_NUMBER_BATTLED
    values = [0, 0]
    case $player.pokedex.battled_count(species)
    when 0...50    then values = [0, 0]
    when 50...100  then values = [1, 15]
    when 100...200 then values = [2, 20]
    when 200...300 then values = [3, 25]
    when 300...500 then values = [4, 30]
    else                values = [5, 30]
    end
    shiny_retries += values[0] if values[1] > 0 && rand(1000) < values[1]
  end
  if shiny_retries > 0
    shiny_retries.times do
      break if genwildpoke.shiny?
      genwildpoke.shiny = nil   # Make it recalculate shininess
      genwildpoke.personalID = rand(2**16) | (rand(2**16) << 16)
    end
  end
  # Give Pokérus
  genwildpoke.givePokerus if rand(65_536) < Settings::POKERUS_CHANCE
  # Change wild Pokémon's gender/nature depending on the lead party Pokémon's
  # ability
  if first_pkmn
    if first_pkmn.hasAbility?(:CUTECHARM) && !genwildpoke.singleGendered?
      if first_pkmn.male?
        (rand(3) < 2) ? genwildpoke.makeFemale : genwildpoke.makeMale
      elsif first_pkmn.female?
        (rand(3) < 2) ? genwildpoke.makeMale : genwildpoke.makeFemale
      end
    elsif first_pkmn.hasAbility?(:SYNCHRONIZE) && Settings::MECHANICS_GENERATION <= 8
      if !isRoamer && (Settings::MORE_ABILITIES_AFFECT_WILD_ENCOUNTERS || (rand(100) < 50))
        genwildpoke.nature = first_pkmn.nature
      end
    end
  end
  # Trigger events that may alter the generated Pokémon further
  EventHandlers.trigger(:on_wild_pokemon_created, genwildpoke)
  return genwildpoke
end

# Add guard dog
#===============================================================================
# Updated Items
#===============================================================================
# Red Card
Battle::ItemEffects::AfterMoveUseFromTarget.add(:REDCARD,
  proc { |item, battler, user, move, switched_battlers, battle|
    next if !switched_battlers.empty? || user.fainted?
    newPkmn = battle.pbGetReplacementPokemonIndex(user.index, true)   # Random
    next if newPkmn < 0
    battle.pbCommonAnimation("UseItem", battler)
    battle.pbDisplay(_INTL("{1} held up its {2} against {3}!",
       battler.pbThis, battler.itemName, user.pbThis(true)))
    battler.pbConsumeItem
    if user.hasActiveAbility?([:SUCTIONCUPS,:GUARDDOG]) && !user.affectedByMoldBreaker?
      battle.pbShowAbilitySplash(user)
      if Battle::Scene::USE_ABILITY_SPLASH
        battle.pbDisplay(_INTL("{1} anchors itself!", user.pbThis))
      else
        battle.pbDisplay(_INTL("{1} anchors itself with {2}!", user.pbThis, user.abilityName))
      end
      battle.pbHideAbilitySplash(user)
      next
    end
    if user.effects[PBEffects::Ingrain]
      battle.pbDisplay(_INTL("{1} anchored itself with its roots!", user.pbThis))
      next
    end
    battle.pbRecallAndReplace(user.index, newPkmn, true)
    battle.pbDisplay(_INTL("{1} was dragged out!", user.pbThis))
    battle.pbClearChoice(user.index)   # Replacement Pokémon does nothing this round
    switched_battlers.push(user.index)
    battle.moldBreaker = false
    battle.pbOnBattlerEnteringBattle(user.index)
  }
)

ItemHandlers::UseOnPokemon.add(:ABILITYPATCH, proc { |item, qty, pkmn, scene|
  if scene.pbConfirm(_INTL("Do you want to change {1}'s Ability?", pkmn.name))
    current_abi = pkmn.ability_index
    abils = pkmn.getAbilityList
    new_ability_id = nil
    abils.each { |a| new_ability_id = a[0] if (current_abi < 2 && a[1] == 2) || (current_abi == 2 && a[1] == 0) }
    if !new_ability_id || pkmn.isSpecies?(:ZYGARDE)
      scene.pbDisplay(_INTL("It won't have any effect."))
      next false
    end
    new_ability_name = GameData::Ability.get(new_ability_id).name
    pkmn.ability_index = current_abi < 2 ? 2 : 0
    pkmn.ability = nil
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1}'s Ability changed! Its Ability is now {2}!",
       pkmn.name, new_ability_name))
    next true
  end
  next false
})