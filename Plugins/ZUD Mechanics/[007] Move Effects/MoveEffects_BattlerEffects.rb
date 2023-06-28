#===============================================================================
# Formatting Move Effects that apply specific effects on battlers.
#===============================================================================
# To set up a custom move effect that applies battler effects, all that is required
# is setting up a @battler_effects hash, where each key in the hash can be one of the 
# following symbols set as an array:
#
#	:user      => [Effects that apply to the user of the move.]
#	:target    => [Effects that apply to the target of this move.]
#	:allies    => [Effects that apply to the user and all eligible ally Pokemon.]
#	:opponents => [Effects that apply to all eligible opposing Pokemon.]
#
# Each of these arrays may then contain their own arrays within them designating
# the effects to apply to the specified Pokemon. These arrays should contain the
# following four elements: [Effect, setting, message, chance]
#
# Effect  = The PBEffect that you wish to set on this Pokemon.
# Setting = What you want to set this PBEffect to (true/false, number, etc).
# Message = The message that should be displayed upon applying this effect.
#           This element may be omitted if you do not want a message displayed.
#           Messages may contain a single "{1}" to refer to the battler the
#           designated effect is being applied to.
# Chance  = The numerical chance of this effect being applied, out of 100.
#           This element is ignored if the user's move already has an effect
#           chance set in its PBS data. This mainly exists just so Max Moves
#           may be set to have a chance to apply their effects without triggering 
#           Sheer Force or Serene Grace, since Max Move effects should not be 
#           considered "added effects" (as with the case of G-Max Snooze).
#           If you omit this element, it will just be assumed that the effect has
#           a 100% activation chance.
#
# The following are all of the effects that may be set in these arrays:
#   AquaRing
#   BurnUp
#   Charge
#   CriticalBoost
#   Curse
#   DefenseCurl
#   Electrify
#   Embargo
#   Endure
#   FocusEnergy
#   Foresight
#   GastroAcid
#   Grudge
#   HealBlock
#   HelpingHand
#   Imprison
#   Ingrain
#   LaserFocus
#   MagicCoat
#   MagnetRise
#   Minimize
#   MiracleEye
#   MudSport
#   Nightmare
#   NoRetreat
#   Powder
#   PowerTrick
#   Rage
#   Roost
#   SmackDown
#   TarShot
#   Taunt
#   Telekinesis
#   ThroatChop
#   Torment
#   Type3
#   WaterSport
#   WeightChange
#   Yawn
#
# For example, this will apply the Rage and No Retreat effects on the user,
# while applying the Embargo effect on all opponents, with a 50% chance to
# apply Taunt on each opponent as well.
#
# @battler_effects = { 
#	  :user => [
#	    [PBEffects::Rage, true],
#	    [PBEffects::NoRetreat, true, "{1} can no longer escape!"] 
#	  ],
#	  :opponents => [ 
#	    [PBEffects::Taunt, 4, "{1} fell for the taunt!", 50],
#	    [PBEffects::Embargo, 5, "{1} can't use items anymore!"]
#	  ]
# }
#
# Meanwhile, this will give the user the Grass type as a third type, while
# also applying the Ingrain effect. Additionally, all ally Pokemon will be
# given a Helping Hand boost if they have yet to move this turn.
#
# @battler_effects = { 
#	  :user => [
#	    [PBEffects::Type3, :GRASS],
#	    [PBEffects::Ingrain, true, "{1} planted its roots!"] 
#	  ],
#	  :allies => [ 
#	    [PBEffects::HelpingHand, true]
#	  ]
# }
#
# Review how the following individual moves are set up below for guidance.
#-------------------------------------------------------------------------------


#===============================================================================
# Increases the critical hit rate of the user and its allies. (G-Max Chi Strike)
#===============================================================================
class Battle::PowerMove::ZUDRaiseUserAndAlliesCriticalHitRate1 < Battle::PowerMove::GeneralEffect
  def initialize(battle, move)
    super
    @battler_effects = { 
      :allies => [ [PBEffects::CriticalBoost, 1, "{1} is getting pumped!"] ]
    }
  end
end


#===============================================================================
# May make the target drowsy; it falls asleep at the end of the next turn. (G-Max Snooze)
# Effect chance is set here to prevent Sheer Force and Serene Grace from triggering.
#===============================================================================
class Battle::PowerMove::ZUDYawnTarget < Battle::PowerMove::GeneralEffect
  def initialize(battle, move)
    super
    @battler_effects = { 
      :target => [ [PBEffects::Yawn, 2, "{1} became drowsy!", 50] ]
    }
  end
end


#===============================================================================
# Opposing Pokemon become subjected to the Torment effect. (G-Max Meltdown)
#===============================================================================
class Battle::PowerMove::ZUDTormentAllFoes < Battle::PowerMove::GeneralEffect
  def initialize(battle, move)
    super
    @battler_effects = { 
      :opponents => [ [PBEffects::Torment, true, "{1} was subjected to torment!"] ]
    }
  end
end