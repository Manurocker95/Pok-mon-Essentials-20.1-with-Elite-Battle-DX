#===============================================================================
# Formatting Move Effects that apply status effects.
#===============================================================================
# To set up a custom move effect that applies statuses, all that is required is 
# initializing a @statuses hash, where each key in the hash can be one of the 
# following symbols, set as an array:
#
#	:user      => [Statuses that may apply to the user of the move.]
#	:target    => [Statuses that may apply to the target of the move.]
#	:allies    => [Statuses that may that apply to the user and all eligible ally Pokemon.]
#	:opponents => [Statuses that may that apply to all eligible opposing Pokemon.]
#
# Each of these arrays may then contain the statuses to apply to the specified Pokemon.
# These arrays should contain at least one status effect ID. If multiple statuses are 
# inputted, then a random one out of the array is chosen to be inflicted on each of the 
# specified targets.
#
# In addition to the traditional status symbols (:SLEEP, :POISON, etc), the
# following symbols are also accepted:
#
# :TOXIC     = Badly poisons the designated targets instead of regular Poison.
# :CONFUSION = Confuses the designated targets, if possible.
# :ATTRACT   = Infatuates the designated targets with the user, if possible.
# :NONE      = Acts as a "cure status" trigger. Setting this will heal any status
#              conditions on the designated targets. Does not heal confusion/infatuation.
#
# For example, this will inflict the burn status on the target.
#
# @statuses = {
#   :target => [:BURN]
# }
#
# Meanwhile, this may randomly inflict either Poison, Toxic Poison, or Confusion on 
# each opponent, while curing all allies of any primary status conditions.
#
# @statuses = {
#   :allies    => [:NONE],
#   :opponents => [:POISON, :TOXIC, :CONFUSION]
# }
#
# Review how the following individual moves are set up below for guidance.
#-------------------------------------------------------------------------------


#===============================================================================
# Paralyzes the target. (Stoked Sparksurfer)
#===============================================================================
class Battle::PowerMove::ZUDParalyzeTarget < Battle::PowerMove::GeneralEffect
  def initialize(battle, move)
    super
    @statuses = {
      :target => [:PARALYSIS]
    }
  end
end


#===============================================================================
# Cures the user and its allies of status conditions. (G-Max Sweetness)
#===============================================================================
class Battle::PowerMove::ZUDCureUserAndAlliesStatus < Battle::PowerMove::GeneralEffect
  def initialize(battle, move)
    super
    @statuses = {
      :allies => [:NONE]
    }
  end
end


#===============================================================================
# Paralyzes the target and its allies. (G-Max Volt Crash)
#===============================================================================
class Battle::PowerMove::ZUDParalyzeAllFoes < Battle::PowerMove::GeneralEffect
  def initialize(battle, move)
    super
    @statuses = {
      :opponents => [:PARALYSIS]
    }
  end
end


#===============================================================================
# Poisons the target and its allies. (G-Max Malador)
#===============================================================================
class Battle::PowerMove::ZUDPoisonAllFoes < Battle::PowerMove::GeneralEffect
  def initialize(battle, move)
    super
    @statuses = {
      :opponents => [:POISON]
    }
  end
end


#===============================================================================
# Randomly poisons or paralyzes the target and its allies. (G-Max Stun Shock)
#===============================================================================
class Battle::PowerMove::ZUDPoisonOrParalyzeAllFoes < Battle::PowerMove::GeneralEffect
  def initialize(battle, move)
    super
    @statuses = {
      :opponents => [:POISON, :PARALYSIS]
    }
  end
end


#===============================================================================
# Randomly poisons, paralyzes or sleeps the target and its allies. (G-Max Befuddle)
#===============================================================================
class Battle::PowerMove::ZUDPoisonParalyzeOrSleepAllFoes < Battle::PowerMove::GeneralEffect
  def initialize(battle, move)
    super
    @statuses = {
      :opponents => [:POISON, :PARALYSIS, :SLEEP]
    }
  end
end


#===============================================================================
# Infatuates the target and its allies. (G-Max Cuddle)
#===============================================================================
class Battle::PowerMove::ZUDInfatuateAllFoes < Battle::PowerMove::GeneralEffect
  def initialize(battle, move)
    super
    @statuses = {
      :opponents => [:ATTRACT]
    }
  end
end


#===============================================================================
# Confuses the target and its allies. (G-Max Smite)
#===============================================================================
class Battle::PowerMove::ZUDConfuseAllFoes < Battle::PowerMove::GeneralEffect
  def initialize(battle, move)
    super
    @statuses = {
      :opponents => [:CONFUSION]
    }
  end
end


#===============================================================================
# Confuses the target and its allies. Gains money at the end of battle. (G-Max Goldrush)
#===============================================================================
class Battle::PowerMove::ZUDConfuseAllFoesAddMoney < Battle::PowerMove::GeneralEffect
  def initialize(battle, move)
    super
    @statuses = {
      :opponents => [:CONFUSION]
    }
  end
  
  def pbEffectAfterAllHits(user, target)
    super
    @battle.field.effects[PBEffects::PayDay] += 100 * user.level
    @battle.pbDisplay(_INTL("Coins were scattered everywhere!"))
  end
end