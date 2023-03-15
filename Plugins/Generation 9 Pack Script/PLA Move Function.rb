module PBEffects
  # Starts from 400 to avoid conflicts with other plugins.
  PowerShift          = 400
end

class Battle::Battler
  
  alias __pla__pbInitEffects pbInitEffects
  def pbInitEffects(batonPass)
    __pla__pbInitEffects(batonPass)
    if batonPass
      if @effects[PBEffects::PowerShift] 
        @attack,@defense = @defense,@attack
      end
    else
      @effects[PBEffects::PowerShift]        = false 
    end 
  end 
end 
###############################################################################
# 
# New moves from Pokémon Legends Arceus
# 
###############################################################################
#===============================================================================
# Paralyzes, poisons or forces the target to sleep. (Dire Claw)
#===============================================================================
class Battle::Move::PoisonParalyzeOrSleepTarget < Battle::Move
  def pbAdditionalEffect(user, target)
    return if target.damageState.substitute
    case @battle.pbRandom(3)
    when 0 then target.pbSleep if target.pbCanSleep?(user,false,self)
    when 1 then target.pbPoison(user) if target.pbCanPoison?(user,false,self)
    when 2 then target.pbParalyze(user) if target.pbCanParalyze?(user,false,self)
    end
  end
end
#===============================================================================
# Swaps the user's offensive and defensive stats. (Power Shift)
# Note: To me this means inverting both attack / special attack with 
# defense / special defense.
#===============================================================================
class Battle::Move::SwapsAttackDefenseTarget < Battle::Move
  def pbEffectGeneral(user)
    user.attack,user.defense = user.defense,user.attack
    user.effects[PBEffects::PowerShift] = !user.effects[PBEffects::PowerShift]
    @battle.pbDisplay(_INTL("{1} switched its attack and defense stats!",user.pbThis))
  end
end
#===============================================================================
# Recoil + boosts the user's speed. (Wave Crash)
#===============================================================================
class Battle::Move::RecoilAndRaiseUserSpeed < Battle::Move::StatUpMove
  def initialize(battle,move)
    super
    @statUp = [:SPEED,1]
  end
  
  def recoilMove?;                 return true; end
  
  def pbRecoilDamage(user,target)
    return (target.damageState.totalHPLost/3.0).round
  end

  def pbEffectAfterAllHits(user,target)
    return if target.damageState.unaffected
    return if !user.takesIndirectDamage?
    return if user.hasActiveAbility?(:ROCKHEAD)
    amt = pbRecoilDamage(user,target)
    amt = 1 if amt<1
    user.pbReduceHP(amt,false)
    @battle.pbDisplay(_INTL("{1} is damaged by recoil!",user.pbThis))
    user.pbItemHPHealCheck
  end
end

#===============================================================================
# Increases the user's Attack, Defense and Speed by 1 stage each. (Victory Dance)
#===============================================================================
class Battle::Move::RaiseUserAtkDefSpd1 < Battle::Move::MultiStatUpMove
  def initialize(battle, move)
    super
    @statUp = [:ATTACK, 1, :SPEED, 1,:DEFENSE,1]
  end
end

#===============================================================================
# Double Power if target has status and may Poison target. (Barb Barrage)
#===============================================================================
class Battle::Move::DoublePowerIfTargetPoisonedPoisonTarget < Battle::Move::PoisonTarget
  def canMagicCoat?; return false; end
  def pbBaseDamage(baseDmg, user, target)
    if target.poisoned? &&
       (target.effects[PBEffects::Substitute] == 0 || ignoresSubstitute?(user))
      baseDmg *= 2
    end
    return baseDmg
  end
end
#===============================================================================
# Double Power if target has status and may Burn target. (Infernal Parade)
#===============================================================================
class Battle::Move::DoublePowerIfTargetStatusProblemBurnTarget < Battle::Move::BurnTarget
  def canMagicCoat?; return false; end
  def pbBaseDamage(baseDmg, user, target)
    if target.pbHasAnyStatus? &&
       (target.effects[PBEffects::Substitute] == 0 || ignoresSubstitute?(user))
      baseDmg *= 2
    end
    return baseDmg
  end
end
#===============================================================================
# Raises critical hit ratio + decreases defense. (Triple Arrows)
#===============================================================================
class Battle::Move::LowerDefenseTarget1Flinch < Battle::Move::TargetStatDownMove
  def initialize(battle,move)
    super
    @statDown = [:DEFENSE, 1]
  end
  
  def flinchingMove?; return true; end

  def pbAdditionalEffect(user, target)
    super
    return if target.damageState.substitute
    target.pbFlinch(user) if @battle.pbRandom(100) < 30
  end
end
#===============================================================================
# Heals the user + cures its status. (Lunar Blessing)
#===============================================================================
class Battle::Move::HealAndCureStatusUser < Battle::Move::HealingMove
  def pbHealAmount(user)
    return (user.totalhp/4.0).round
  end
  def pbMoveFailed?(user,targets)
    return false if user.pbHasAnyStatus?
    return super 
  end 
  def pbEffectGeneral(user)
    user.pbCureStatus
    super 
  end 
end 

#===============================================================================
# Cures the user's status + raises its stats. (Take Heart)
#===============================================================================
class Battle::Move::RaiseStatsAndCureStatus < Battle::Move::MultiStatUpMove
  def initialize(battle,move)
    super
    @statUp = [:SPECIAL_ATTACK, 1, :SPECIAL_DEFENSE, 1]
  end
  
  def pbMoveFailed?(user,targets)
    return false if user.pbHasAnyStatus?
    return super 
  end 
  
  def pbEffectGeneral(user)
    user.pbCureStatus if user.pbHasAnyStatus?
    super 
  end 
end