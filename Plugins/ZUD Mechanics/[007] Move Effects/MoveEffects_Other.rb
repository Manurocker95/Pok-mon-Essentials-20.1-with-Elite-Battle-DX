#===============================================================================
# Power Moves with very specific effects that the PowerMove::GeneralEffect 
# class cannot be used for efficiently.
#===============================================================================


#===============================================================================
# User is protected against all attacks, including Max Moves. (Max Guard)
# Specific exceptions dealt with elsewhere.
#===============================================================================
class Battle::PowerMove::ZUDProtectUser < Battle::Move::ProtectMove
  def initialize(battle, move)
    super
    @effect = PBEffects::MaxGuard
  end
end


#===============================================================================
# Ignores the target's Ability. (G-Max Drum Solo, G-Max Fireball, G-Max Hydrosnipe)
#===============================================================================
class Battle::PowerMove::ZUDIgnoreTargetAbility < Battle::Move::IgnoreTargetAbility
end


#===============================================================================
# Ignores the target's Ability. Damage category is chosen based on which would
# deal the most damage. (Light That Burns the Sky)
#===============================================================================
class Battle::PowerMove::ZUDPhotonGeyserEffect < Battle::Move::CategoryDependsOnHigherDamageIgnoreTargetAbility
end


#===============================================================================
# Inflicts 75% of the target's current HP. (Guardian of Alola)
#===============================================================================
class Battle::PowerMove::ZUDFixedDamage75PercentTargetHP < Battle::Move::FixedDamageMove
  def pbFixedDamage(user,target)
    return (target.real_hp * 0.75).round
  end
end


#===============================================================================
# The user and its allies gain 1/6th of their total HP. The amount healed doesn't
# scale down for Dynamax HP totals. (G-Max Finale)
#===============================================================================
class Battle::PowerMove::ZUDHealUserAndAlliesOneSixthOfTotalHP < Battle::PowerMove
  def pbEffectAfterAllHits(user, target)
    return if target.damageState.unaffected
    return if @battle.pbAllFainted?(target.idxOwnSide) || @battle.decision > 0
    @battle.eachSameSideBattler(user) do |b|
      next if b.hp == b.totalhp
      next if b.effects[PBEffects::HealBlock] > 0
      b.ignore_dynamax = true
      b.pbRecoverHP(b.totalhp / 6.0)
    end
  end
end


#===============================================================================
# The user and its allies may recover consumed berries. (G-Max Replenish)
#===============================================================================
class Battle::PowerMove::ZUDRestoreUserAndAlliesConsumedBerry < Battle::PowerMove
  def pbEffectAfterAllHits(user, target)
    return if target.damageState.unaffected
    return if @battle.pbAllFainted?(target.idxOwnSide) || @battle.decision > 0
    @battle.eachSameSideBattler(user) do |b|
      next if !b.recycleItem || !GameData::Item.get(b.recycleItem).is_berry?
      next if @battle.pbRandom(2) < 1
      b.item = b.recycleItem
      b.setRecycleItem(nil)
      b.setInitialItem(b.item) if !b.initialItem
      @battle.pbDisplay(_INTL("{1} found one {2}!", b.pbThis, b.itemName))	  
      b.pbHeldItemTriggerCheck
    end
  end
end


#===============================================================================
# Each opponent's last move used loses 2 PP. (G-Max Depletion)
#===============================================================================
class Battle::PowerMove::ZUDLowerPPOfAllFoesLastMoveBy2 < Battle::PowerMove
  def pbEffectAfterAllHits(user, target)
    return if target.damageState.unaffected
    return if @battle.pbAllFainted?(target.idxOwnSide) || @battle.decision > 0
    user.eachOpposing do |b|
      next if !b.lastRegularMoveUsed
      if GameData::Move.get(b.lastRegularMoveUsed).powerMove?
        last_move = b.moves[b.power_index]
      else
          last_move = b.pbGetMoveWithID(b.lastRegularMoveUsed)
      end
      reduction = [2, last_move.pp].min
      b.pbSetPP(last_move, last_move.pp - reduction)
      if GameData::Move.get(b.lastRegularMoveUsed).powerMove?
        last_move = b.base_moves[b.power_index]
        reduction = [2, last_move.pp].min
        b.pbSetPP(last_move, last_move.pp - reduction)
      end
      @battle.pbDisplay(_INTL("{1}'s PP was reduced!", b.pbThis))
    end
  end
end


#===============================================================================
# Opposing Pokemon can no longer switch or flee, as long as the user is active. 
# (G-Max Terror)
#===============================================================================
class Battle::PowerMove::ZUDTrapAllFoesInBattle < Battle::PowerMove
  def pbEffectAfterAllHits(user, target)
    return if target.damageState.unaffected
    return if @battle.pbAllFainted?(target.idxOwnSide) || @battle.decision > 0
    user.eachOpposing do |b|
      next if Settings::MORE_TYPE_EFFECTS && b.pbHasType?(:GHOST)
      next if b.effects[PBEffects::MeanLook] == user.index
      @battle.pbDisplay(_INTL("{1} can no longer escape!", b.pbThis))
      b.effects[PBEffects::MeanLook] = user.index
    end
  end
end


#===============================================================================
# Trapping move. Traps for 4 or 5 rounds. Trapped Pokémon lose 1/8 of max HP
# at end of each round. Trapping effect persists even upon the user switching out.
# (G-Max Centiferno, G-Max Sand Blast)
#===============================================================================
class Battle::PowerMove::ZUDBindAllFoesUserCanSwitch < Battle::PowerMove
  def pbEffectAfterAllHits(user, target)
    return if target.damageState.unaffected
    return if @battle.pbAllFainted?(target.idxOwnSide) || @battle.decision > 0
    case @type
    when :NORMAL; moveid = :BIND
    when :WATER;  moveid = :WHIRLPOOL
    when :FIRE;   moveid = :FIRESPIN
    when :BUG;    moveid = :INFESTATION
    when :GROUND; moveid = :SANDTOMB
    end
    user.eachOpposing do |b|
      next if b.effects[PBEffects::Trapping] > 0
      b.effects[PBEffects::Trapping] = 4 + @battle.pbRandom(2)
      b.effects[PBEffects::Trapping] = 7 if user.hasActiveItem?(:GRIPCLAW)
      b.effects[PBEffects::TrappingMove] = moveid
      b.effects[PBEffects::TrappingUser] = user.index
      b.effects[PBEffects::GMaxTrapping] = true
      msg = _INTL("{1} was trapped in the vortex!", b.pbThis)
      case moveid
      when :BIND
        msg = _INTL("{1} was squeezed by {2}!", b.pbThis, user.pbThis(true))
      when :FIRESPIN
        msg = _INTL("{1} was trapped in the fiery vortex!", b.pbThis)
      when :INFESTATION
        msg = _INTL("{1} has been afflicted with an infestation by {2}!", b.pbThis, user.pbThis(true))
      when :SANDTOMB
        msg = _INTL("{1} became trapped by Sand Tomb!", b.pbThis)
      when :WHIRLPOOL
        msg = _INTL("{1} became trapped in the watery vortex!", b.pbThis)
      end
      @battle.pbDisplay(msg)
    end
  end
end