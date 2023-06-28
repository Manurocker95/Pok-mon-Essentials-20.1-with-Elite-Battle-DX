#===============================================================================
# Two-Turn Attaks (Fly, Dig, Dive, etc.)
#===============================================================================
# Max Raid Pokemon skip charge turn of moves that make them semi-invulnerable.
#-------------------------------------------------------------------------------
class Battle::Move::TwoTurnMove < Battle::Move 
  def pbIsChargingTurn?(user)
    @powerHerb = false
    @chargingTurn = false
    @damagingTurn = true
    if !user.effects[PBEffects::TwoTurnAttack]
      @powerHerb = user.hasActiveItem?(:POWERHERB)
      @chargingTurn = true
      @damagingTurn = @powerHerb
      if user.effects[PBEffects::MaxRaidBoss] &&
         ["TwoTurnAttackInvulnerableInSky",
          "TwoTurnAttackInvulnerableUnderground",
          "TwoTurnAttackInvulnerableUnderwater",
          "TwoTurnAttackInvulnerableInSkyParalyzeTarget",
          "TwoTurnAttackInvulnerableRemoveProtections",
          "TwoTurnAttackInvulnerableInSkyTargetCannotAct",
          "TwoTurnAttackInvulnerableRemoveProtections"].include?(@function)
        @damagingTurn = true
      end
    end
    return !@damagingTurn
  end
end


#===============================================================================
# Nature's Madness, Super Fang
#===============================================================================
# Damage dealt is based on the target's non-Dynamax HP.
#-------------------------------------------------------------------------------
class Battle::Move::FixedDamageHalfTargetHP < Battle::Move::FixedDamageMove
  def pbFixedDamage(user, target)
    return (target.real_hp / 2.0).round
  end
end


#===============================================================================
# Endeavor
#===============================================================================
# Damage dealt is based on the user/target's non-Dynamax HP.
#-------------------------------------------------------------------------------
class Battle::Move::LowerTargetHPToUserHP < Battle::Move::FixedDamageMove
  def pbFixedDamage(user, target)
    return target.real_hp - user.real_hp
  end
end


#===============================================================================
# Pain Split
#===============================================================================
# Changes to HP is based on user/target's non-Dynamax HP.
#-------------------------------------------------------------------------------
class Battle::Move::UserTargetAverageHP < Battle::Move
  def pbEffectAgainstTarget(user,target)
    newHP = (user.real_hp + target.real_hp) / 2
    if user.real_hp > newHP
	  user.ignore_dynamax = true
	  user.pbReduceHP(user.real_hp - newHP, false, false)
    elsif user.real_hp < newHP
	  user.ignore_dynamax = true
	  user.pbRecoverHP(newHP - user.real_hp, false)
    end
    if target.real_hp > newHP
	  target.ignore_dynamax = true
	  target.pbReduceHP(target.real_hp - newHP, false, false)
    elsif target.real_hp < newHP
	  target.ignore_dynamax = true
	  target.pbRecoverHP(newHP - target.real_hp, false)
    end
    @battle.pbDisplay(_INTL("The battlers shared their pain!"))
    user.pbItemHPHealCheck
    target.pbItemHPHealCheck
  end
end


#===============================================================================
# Strength Sap
#===============================================================================
# Healing isn't reduced while Dynamaxed.
#-------------------------------------------------------------------------------
class Battle::Move::HealUserByTargetAttackLowerTargetAttack1 < Battle::Move
  alias zud_pbEffectAgainstTarget pbEffectAgainstTarget
  def pbEffectAgainstTarget(user, target)
    user.ignore_dynamax = true
    zud_pbEffectAgainstTarget(user, target)
    user.ignore_dynamax = false
  end
end


#===============================================================================
# Spite
#===============================================================================
# Reduced PP of Max Moves is properly applied to the base move as well.
#-------------------------------------------------------------------------------
class Battle::Move::LowerPPOfTargetLastMoveBy4 < Battle::Move
  def pbEffectAgainstTarget(user, target)
    last_move = target.pbGetMoveWithID(target.lastRegularMoveUsed)
    reduction = [4, last_move.pp].min
    target.pbSetPP(last_move, last_move.pp - reduction)
    move_name = last_move.name
    if target.dynamax?
      base_move = target.base_moves[target.power_index]
      target.pbSetPP(base_move, base_move.pp - reduction)
      move_name = base_move.name
    end
    @battle.pbDisplay(_INTL("It reduced the PP of {1}'s {2} by {3}!",
                            target.pbThis(true), move_name, reduction))
  end
end


#===============================================================================
# Eerie Spell
#===============================================================================
# Reduced PP of Max Moves is properly applied to the base move as well.
#-------------------------------------------------------------------------------
class Battle::Move::LowerPPOfTargetLastMoveBy3 < Battle::Move
  def pbEffectAgainstTarget(user, target)
    return if target.fainted?
    last_move = target.pbGetMoveWithID(target.lastRegularMoveUsed)
    return if !last_move || last_move.pp == 0 || last_move.total_pp <= 0
    reduction = [3, last_move.pp].min
    target.pbSetPP(last_move, last_move.pp - reduction)
    move_name = last_move.name
    if target.dynamax?
      base_move = target.base_moves[target.power_index]
      target.pbSetPP(base_move, base_move.pp - reduction)
      move_name = base_move.name
    end
    @battle.pbDisplay(_INTL("It reduced the PP of {1}'s {2} by {3}!",
                            target.pbThis(true), move_name, reduction))
  end
end


#===============================================================================
# Rapid Spin
#===============================================================================
# Also clears away hazard applied with G-Max Steelsurge.
#-------------------------------------------------------------------------------
class Battle::Move::RemoveUserBindingAndEntryHazards < Battle::Move::StatUpMove
  alias zud_pbEffectAfterAllHits pbEffectAfterAllHits
  def pbEffectAfterAllHits(user, target)
    zud_pbEffectAfterAllHits(user,target)
    if user.pbOwnSide.effects[PBEffects::Steelsurge]
      user.pbOwnSide.effects[PBEffects::Steelsurge] = false
      @battle.pbDisplay(_INTL("{1} blew away the pointed steel!", user.pbThis))
    end
  end
end


#===============================================================================
# Defog
#===============================================================================
# Clears away hazard applied with G-Max Steelsurge.
#-------------------------------------------------------------------------------
class Battle::Move::LowerTargetEvasion1RemoveSideEffects < Battle::Move::TargetStatDownMove
  alias zud_pbFailsAgainstTarget? pbFailsAgainstTarget?
  def pbFailsAgainstTarget?(user, target, show_message)
    return false if Settings::MECHANICS_GENERATION >= 6 && target.pbOpposingSide.effects[PBEffects::Steelsurge]
    return zud_pbFailsAgainstTarget?(user, target, show_message)
  end
  
  alias zud_pbEffectAgainstTarget pbEffectAgainstTarget
  def pbEffectAgainstTarget(user, target)
    zud_pbEffectAgainstTarget(user, target)
    if target.pbOwnSide.effects[PBEffects::Steelsurge] ||
       (Settings::MECHANICS_GENERATION >= 6 && target.pbOpposingSide.effects[PBEffects::Steelsurge])
      target.pbOwnSide.effects[PBEffects::Steelsurge]      = false
      target.pbOpposingSide.effects[PBEffects::Steelsurge] = false if Settings::MECHANICS_GENERATION >= 6
      @battle.pbDisplay(_INTL("{1} blew away the pointed steel!", user.pbThis))
    end
  end
end


#===============================================================================
# Mimic
#===============================================================================
# Move fails when attempting to Mimic a Z-Move/Max Move.
# Records mimicked move as a new base move to revert to after Z-Move/Dynamax.
#-------------------------------------------------------------------------------
class Battle::Move::ReplaceMoveThisBattleWithTargetLastMoveUsed < Battle::Move
  def pbFailsAgainstTarget?(user, target, show_message)
    lastMoveData = GameData::Move.try_get(target.lastRegularMoveUsed)
    if !lastMoveData ||
       user.pbHasMove?(target.lastRegularMoveUsed) ||
       @moveBlacklist.include?(lastMoveData.function_code) ||
       lastMoveData.type == :SHADOW || lastMoveData.powerMove?
      @battle.pbDisplay(_INTL("But it failed!")) if show_message
      return true
    end
    return false
  end
  
  def pbEffectAgainstTarget(user, target)
    user.eachMoveWithIndex do |m, i|
      next if m.id != @id
      newMove = Pokemon::Move.new(target.lastRegularMoveUsed)
      user.moves[i] = Battle::Move.from_pokemon_move(@battle, newMove)
      user.base_moves[i] = user.moves[i] if !user.base_moves.empty?
      @battle.pbDisplay(_INTL("{1} learned {2}!", user.pbThis, newMove.name))
      user.pbCheckFormOnMovesetChange
      break
    end
  end
end


#===============================================================================
# Sketch
#===============================================================================
# Move fails when attempting to Sketch a Z-Move/Max Move.
#-------------------------------------------------------------------------------
class Battle::Move::ReplaceMoveWithTargetLastMoveUsed < Battle::Move
  def pbFailsAgainstTarget?(user, target, show_message)
    lastMoveData = GameData::Move.try_get(target.lastRegularMoveUsed)
    if !lastMoveData ||
       user.pbHasMove?(target.lastRegularMoveUsed) ||
       @moveBlacklist.include?(lastMoveData.function_code) ||
       lastMoveData.type == :SHADOW || lastMoveData.powerMove?
      @battle.pbDisplay(_INTL("But it failed!")) if show_message
      return true
    end
    return false
  end
end


#===============================================================================
# Transform
#===============================================================================
# Move fails if the user is Dynamaxed and attempts to Transform into a species
# that is unable to have a Dynamax form.
#-------------------------------------------------------------------------------
class Battle::Move::TransformUserIntoTarget < Battle::Move
  alias zud_pbFailsAgainstTarget? pbFailsAgainstTarget?
  def pbFailsAgainstTarget?(user, target, show_message)
    if user.dynamax? && !target.dynamax_able?
      @battle.pbDisplay(_INTL("But it failed!"))
      return true
    end
    return zud_pbFailsAgainstTarget?(user, target, show_message)
  end
end


#===============================================================================
# Copycat
#===============================================================================
# Move fails when the last used move was a Z-Move.
# If last move used was a Max Move, copies the base move of that Max Move.
#-------------------------------------------------------------------------------
class Battle::Move::UseLastMoveUsed < Battle::Move
  def pbChangeUsageCounters(user, specialUsage)
    super
    @copied_move = @battle.lastMoveUsed
    @copy_target = @battle.lastMoveUser
  end

  def pbMoveFailed?(user, targets)
    if !@copied_move || GameData::Move.get(@copied_move).zMove? ||
       @moveBlacklist.include?(GameData::Move.get(@copied_move).function_code)
      @battle.pbDisplay(_INTL("But it failed!"))
      return true
    end
    return false
  end

  def pbEffectGeneral(user)
    if GameData::Move.get(@copied_move).maxMove?
      @battle.eachBattler do |b|
        next if b.index != @copy_target
        idxMove = @battle.choices[b.index][1]
        @copied_move = b.base_moves[idxMove].id
      end
    end
    user.pbUseMoveSimple(@copied_move)
  end
end


#===============================================================================
# Me First
#===============================================================================
# Move fails when attempting to copy a target's Z-Move/Max Move.
#-------------------------------------------------------------------------------
class Battle::Move::UseMoveTargetIsAboutToUse < Battle::Move
  def pbFailsAgainstTarget?(user, target, show_message)
    return true if pbMoveFailedTargetAlreadyMoved?(target, show_message)
    oppMove = @battle.choices[target.index][2]
    if !oppMove || oppMove.statusMove? || @moveBlacklist.include?(oppMove.function) || oppMove.powerMove?
      @battle.pbDisplay(_INTL("But it failed!")) if show_message
      return true
    end
    return false
  end
end


#===============================================================================
# Sleep Talk
#===============================================================================
# Z-Sleep Talk will use the Z-Powered version of the random move selected.
#-------------------------------------------------------------------------------
class Battle::Move::UseRandomUserMoveIfAsleep < Battle::Move
  def pbEffectGeneral(user)
    choice = @sleepTalkMoves[@battle.pbRandom(@sleepTalkMoves.length)]
    user.pbUseMoveSimple(user.moves[choice].id, user.pbDirectOpposing.index, choice)
  end
end


#===============================================================================
# Assist
#===============================================================================
# Ignores Z-Moves/Max Moves when calling a move in the party.
#-------------------------------------------------------------------------------
class Battle::Move::UseRandomMoveFromUserParty < Battle::Move
  def pbMoveFailed?(user, targets)
    @assistMoves = []
    @battle.pbParty(user.index).each_with_index do |pkmn, i|
      next if !pkmn || i == user.pokemonIndex
      next if Settings::MECHANICS_GENERATION >= 6 && pkmn.egg?
      pkmn.moves.each do |move|
	    next if move.powerMove?
        next if @moveBlacklist.include?(move.function_code)
        next if move.type == :SHADOW
        @assistMoves.push(move.id)
      end
    end
    if @assistMoves.length == 0
      @battle.pbDisplay(_INTL("But it failed!"))
      return true
    end
    return false
  end
end


#===============================================================================
# Metronome
#===============================================================================
# Ignores Z-Moves/Max Moves when calling a random move.
#-------------------------------------------------------------------------------
class Battle::Move::UseRandomMove < Battle::Move
  def pbMoveFailed?(user, targets)
    @metronomeMove = nil
    move_keys = GameData::Move.keys
    1000.times do
      move_id = move_keys[@battle.pbRandom(move_keys.length)]
      move_data = GameData::Move.get(move_id)
      next if @moveBlacklist.include?(move_data.function_code)
      next if move_data.has_flag?("CannotMetronome")
      next if move_data.type == :SHADOW
      next if move_data.powerMove?
      @metronomeMove = move_data.id
      break
    end
    if !@metronomeMove
      @battle.pbDisplay(_INTL("But it failed!"))
      return true
    end
    return false
  end
end


#===============================================================================
# Encore
#===============================================================================
# Move fails if the target's last used move was a Z-Move.
# No effect on Max Moves because Dynamax Pokemon are already immune to Encore.
#-------------------------------------------------------------------------------
class Battle::Move::DisableTargetUsingDifferentMove < Battle::Move
  alias zud_pbFailsAgainstTarget? pbFailsAgainstTarget?
  def pbFailsAgainstTarget?(user, target, show_message)
    if target.lastMoveUsedIsZMove
      @battle.pbDisplay(_INTL("But it failed!"))
      return true
    end
    return zud_pbFailsAgainstTarget?(user, target, show_message)
  end
end


#===============================================================================
# Self-Destruct, Explosion, Misty Explosion
#===============================================================================
# Move fails when used by a Max Raid Pokemon.
#-------------------------------------------------------------------------------
class Battle::Move::UserFaintsExplosive < Battle::Move
  alias zud_pbMoveFailed? pbMoveFailed?
  def pbMoveFailed?(user, targets)
    if user.effects[PBEffects::MaxRaidBoss]
      @battle.pbDisplay(_INTL("But it failed!"))
      return true
    end
    return zud_pbMoveFailed?(user,targets)
  end
end


#===============================================================================
# Perish Song
#===============================================================================
# Move fails when used by any Pokemon in a Max Raid battle.
#-------------------------------------------------------------------------------
class Battle::Move::StartPerishCountsForAllBattlers < Battle::Move
  alias zud_pbMoveFailed? pbMoveFailed?
  def pbMoveFailed?(user, targets)
	return true if @battle.raid_battle
    return zud_pbMoveFailed?(user, targets)
  end
end


#===============================================================================
# Destiny Bond
#===============================================================================
# Move fails when used by a Max Raid Pokemon.
#-------------------------------------------------------------------------------
class Battle::Move::AttackerFaintsIfUserFaints < Battle::Move
  alias zud_pbMoveFailed? pbMoveFailed?
  def pbMoveFailed?(user, targets)
    if user.effects[PBEffects::MaxRaidBoss]
      @battle.pbDisplay(_INTL("But it failed!"))
      return true
    end
    return zud_pbMoveFailed?(user, targets)
  end
end


#===============================================================================
# Teleport (Gen 7-)
#===============================================================================
# Move fails when used by any Pokemon in a Max Raid battle.
#-------------------------------------------------------------------------------
class Battle::Move::FleeFromBattle < Battle::Move
  def pbMoveFailed?(user,targets)
    if !@battle.pbCanRun?(user.index) || @battle.raid_battle
      @battle.pbDisplay(_INTL("But it failed!"))
      return true
    end
    return false
  end
end


#===============================================================================
# Teleport (Gen 8+)
#===============================================================================
# Move fails when used by a Max Raid Pokemon.
#-------------------------------------------------------------------------------
class Battle::Move::SwitchOutUserStatusMove < Battle::Move
  alias zud_pbMoveFailed? pbMoveFailed?
  def pbMoveFailed?(user, targets)
    if user.effects[PBEffects::MaxRaidBoss]
      @battle.pbDisplay(_INTL("But it failed!"))
      return true
    end
    return zud_pbMoveFailed?(user, targets)
  end
end


#===============================================================================
# Dragon Tail, Circle Throw
#===============================================================================
# Forced switch fails to trigger if target is Dynamaxed, or user is Raid Boss.
#-------------------------------------------------------------------------------
class Battle::Move::SwitchOutTargetDamagingMove < Battle::Move
  def pbEffectAgainstTarget(user, target)
    if @battle.wildBattle? && target.level <= user.level && @battle.canRun && !@battle.raid_battle &&
       (target.effects[PBEffects::Substitute] == 0 || ignoresSubstitute?(user))
      @battle.decision = 3
    end
  end
  
  def pbSwitchOutTargetEffect(user, targets, numHits, switched_battlers)
    return if @battle.wildBattle? || !switched_battlers.empty?
    return if user.fainted? || numHits == 0
    targets.each do |b|
      next if b.fainted? || b.damageState.unaffected || b.damageState.substitute || b.dynamax?
      next if b.effects[PBEffects::Ingrain]
      next if b.hasActiveAbility?(:SUCTIONCUPS) && !@battle.moldBreaker
      newPkmn = @battle.pbGetReplacementPokemonIndex(b.index, true)
      next if newPkmn < 0
      @battle.pbRecallAndReplace(b.index, newPkmn, true)
      @battle.pbDisplay(_INTL("{1} was dragged out!", b.pbThis))
      @battle.pbClearChoice(b.index)
      @battle.pbOnBattlerEnteringBattle(b.index)
      switched_battlers.push(b.index)
      break
    end
  end
end


#===============================================================================
# Behemoth Blade, Behemoth Bash, Dynamax Cannon
#===============================================================================
# Deals double damage vs Dynamax targets, except for Eternamax Eternatus.
#-------------------------------------------------------------------------------
class Battle::Move::DoubleDamageOnDynamaxTargets < Battle::Move
  def pbBaseDamage(baseDmg, user, target)
    if target.dynamax? && !target.isSpecies?(:ETERNATUS)
      baseDmg *= 2
    end
    return baseDmg
  end
end