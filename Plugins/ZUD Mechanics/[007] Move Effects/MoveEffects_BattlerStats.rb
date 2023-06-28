#===============================================================================
# Formatting Move Effects that alter stat stages.
#===============================================================================
# To set up a custom move that alters stat stages, all that is required is 
# initializing a @stat_changes hash, where each key in the hash can be one of the 
# following symbols, set as an array:
#
#	:user      => [Stat changes that may apply to the user of the move.]
#	:target    => [Stat changes that may apply to the target of the move.]
#	:allies    => [Stat changes that may that apply to the user and all eligible ally Pokemon.]
#	:opponents => [Stat changes that may that apply to all eligible opposing Pokemon.]
#
# You may have as many of these keys set up as you wish in order to affect stats of
# multiple configurations of Pokemon.
#
# Each of the arrays these keys are set to may then contain the stats and stage changes 
# to apply to the specified Pokemon. These arrays should be set up in sequential order of
# a stat ID, followed by the number of stages, and so on. To make it so that the stat is 
# lowered instead of raised, you simply set the stages associated with a stat to a 
# negative number.
#
# For example, this will raise the Sp.Atk stat of all allies by 1 stage, and their 
# Accuracy by 2 stages.
#
# @stat_changes = { 
#   :allies => [:SPECIAL_ATTACK, 1, :ACCURACY, 2] 
# }
#
# Meanwhile, this will raise the user's Speed by 2 stages, and lower the target's 
# Attack stat by 1 stage.
#
# @stat_changes = {
#   :user   => [:SPEED, 2],
# 	:target => [:ATTACK, -1]
# }
#
# Review how the following individual moves are set up below for guidance.
#-------------------------------------------------------------------------------


#===============================================================================
# Raises all of the user's stats by 1 stage. (Clangorus Soulblaze)
#===============================================================================
class Battle::PowerMove::ZUDRaiseUserMainStats1 < Battle::PowerMove::GeneralEffect
  def initialize(battle, move)
    super
    @stat_changes = { 
      :user => [
        :ATTACK,          1,
        :DEFENSE,         1,
        :SPECIAL_ATTACK,  1,
        :SPECIAL_DEFENSE, 1,
        :SPEED,           1
      ]
    }
  end
end


#===============================================================================
# Raises all of the user's stats by 2 stages. (Extreme Evoboost)
#===============================================================================
class Battle::PowerMove::ZUDRaiseUserMainStats2 < Battle::PowerMove::GeneralEffect
  def initialize(battle, move)
    super
    @stat_changes = { 
      :user => [
        :ATTACK,          2,
        :DEFENSE,         2,
        :SPECIAL_ATTACK,  2,
        :SPECIAL_DEFENSE, 2,
        :SPEED,           2
      ]
    }
  end
end


#===============================================================================
# Raises the Attack of the user and its allies by 1 stage. (Max Knuckle)
#===============================================================================
class Battle::PowerMove::ZUDRaiseUserAndAlliesAtk1 < Battle::PowerMove::GeneralEffect
  def initialize(battle, move)
    super
    @stat_changes = { 
      :allies => [:ATTACK, 1]
    }
  end
end


#===============================================================================
# Raises the Defense of the user and its allies by 1 stage. (Max Steelspike)
#===============================================================================
class Battle::PowerMove::ZUDRaiseUserAndAlliesDef1 < Battle::PowerMove::GeneralEffect
  def initialize(battle, move)
    super
    @stat_changes = { 
      :allies => [:DEFENSE, 1]
    }
  end
end


#===============================================================================
# Raises the Sp.Atk of the user and its allies by 1 stage. (Max Ooze)
#===============================================================================
class Battle::PowerMove::ZUDRaiseUserAndAlliesSpAtk1 < Battle::PowerMove::GeneralEffect
  def initialize(battle, move)
    super
    @stat_changes = { 
      :allies => [:SPECIAL_ATTACK, 1]
    }
  end
end


#===============================================================================
# Raises the Sp.Def of the user and its allies by 1 stage. (Max Quake)
#===============================================================================
class Battle::PowerMove::ZUDRaiseUserAndAlliesSpDef1 < Battle::PowerMove::GeneralEffect
  def initialize(battle, power_move)
    super
    @stat_changes = { 
      :allies => [:SPECIAL_DEFENSE, 1]
    }
  end
end


#===============================================================================
# Raises the Speed of the user and its allies by 1 stage. (Max Airstream)
#===============================================================================
class Battle::PowerMove::ZUDRaiseUserAndAlliesSpeed1 < Battle::PowerMove::GeneralEffect
  def initialize(battle, move)
    super
    @stat_changes = { 
      :allies => [:SPEED, 1]
    }
  end
end


#===============================================================================
# Lowers the Attack of the target and its allies by 1 stage. (Max Wyrmwind)
#===============================================================================
class Battle::PowerMove::ZUDLowerAllFoesAtk1 < Battle::PowerMove::GeneralEffect
  def initialize(battle, move)
    super
    @stat_changes = { 
      :opponents => [:ATTACK, -1]
    }
  end
end


#===============================================================================
# Lowers the Defense of the target and its allies by 1 stage. (Max Phantasm)
#===============================================================================
class Battle::PowerMove::ZUDLowerAllFoesDef1 < Battle::PowerMove::GeneralEffect
  def initialize(battle, move)
    super
    @stat_changes = { 
      :opponents => [:DEFENSE, -1]
    }
  end
end


#===============================================================================
# Lowers the Sp.Atk of the target and its allies by 1 stage. (Max Flutterby)
#===============================================================================
class Battle::PowerMove::ZUDLowerAllFoesSpAtk1 < Battle::PowerMove::GeneralEffect
  def initialize(battle, move)
    super
    @stat_changes = { 
      :opponents => [:SPECIAL_ATTACK, -1]
    }
  end
end


#===============================================================================
# Lowers the Sp.Def of the target and its allies by 1 stage. (Max Darkness)
#===============================================================================
class Battle::PowerMove::ZUDLowerAllFoesSpDef1 < Battle::PowerMove::GeneralEffect
  def initialize(battle, move)
    super
    @stat_changes = { 
      :opponents => [:SPECIAL_DEFENSE, -1]
    }
  end
end


#===============================================================================
# Lowers the Speed of the target and its allies by 1 stage. (Max Strike)
#===============================================================================
class Battle::PowerMove::ZUDLowerAllFoesSpeed1 < Battle::PowerMove::GeneralEffect
  def initialize(battle, move)
    super
    @stat_changes = { 
      :opponents => [:SPEED, -1]
    }
  end
end


#===============================================================================
# Lowers the Speed of the target and its allies by 2 stages. (G-Max Foamburst)
#===============================================================================
class Battle::PowerMove::ZUDLowerAllFoesSpeed2 < Battle::PowerMove::GeneralEffect
  def initialize(battle, move)
    super
    @stat_changes = {
      :opponents => [:SPEED, -2]
    }
  end
end


#===============================================================================
# Lowers the Evasion of the target and its allies by 1 stage. (G-Max Tartness)
#===============================================================================
class Battle::PowerMove::ZUDLowerAllFoesEvasion1 < Battle::PowerMove::GeneralEffect
  def initialize(battle, move)
    super
    @stat_changes = { 
      :opponents => [:EVASION, -1]
    }
  end
end