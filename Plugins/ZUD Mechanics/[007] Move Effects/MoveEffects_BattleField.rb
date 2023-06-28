#===============================================================================
# Formatting Move Effects that apply effects to the entire field.
#===============================================================================
# To set up a custom move effect that applies effects to the field, all that is 
# required is initializing a @field array, where each element in the array is 
# itself an array which designates the effects to apply to the field. These 
# arrays should contain the following three elements: [Effect, setting, message]
#
#	Effect  = The PBEffect that you wish to set for the field.
#	Setting = What you want to set this PBEffect to (true/false, number, etc).
#	Message = The message that should be displayed upon applying this effect.
#           This element may be omitted if you do not want a message displayed.
#           Messages may contain a single "{1}" to refer to the user of 
#           the move.
#
# The following are all of the field effects that may be set with the @field array:
#   FairyLock
#   Gravity
#   HappyHour
#   IonDeluge
#   MagicRoom
#   MudSportField
#   TrickRoom
#   WaterSportField
#   WonderRoom
#
# Weather and Terrain are not handled by the @field array however, and are
# instead simply set with thier own variables, @weather and @terrain. The
# @field array is not needed if creating a move that only sets these effects.
# Note that setting either of these to :None will end any active weather or terrain,
# respectively.
#
# For example, this will begin rain weather and apply the Ion Deluge effect:
#
# @weather = :Rain
# @field   = [ [PBEffects::IonDeluge, true, "A deluge of ions showers the battlefield!"] ]
#
# Meanwhile, this will apply both the Mud Sport and Water Sport effects to the field and
# also end any active terrains.
#
# @terrain = :None
# @field = [
#	  [PBEffects::WaterSportField, 5, "Fire's power was weakened!"],
#	  [PBEffects::MudSportField, 5, "Electricity's power was weakened!"]
# ]
#
# Review how the following individual moves are set up below for guidance.
#-------------------------------------------------------------------------------


#===============================================================================
# Starts sunny weather. (Max Flare)
#===============================================================================
class Battle::PowerMove::ZUDStartSunWeather < Battle::PowerMove::GeneralEffect
  def initialize(battle, move)
    super
    @weather = :Sun
  end
end


#===============================================================================
# Starts rainy weather. (Max Geyser)
#===============================================================================
class Battle::PowerMove::ZUDStartRainWeather < Battle::PowerMove::GeneralEffect
  def initialize(battle, move)
    super
    @weather = :Rain
  end
end


#===============================================================================
# Starts sandstorm weather. (Max Rockfall)
#===============================================================================
class Battle::PowerMove::ZUDStartSandstormWeather < Battle::PowerMove::GeneralEffect
  def initialize(battle, move)
    super
    @weather = :Sandstorm
  end
end


#===============================================================================
# Starts hail weather. (Max Hailstorm)
#===============================================================================
class Battle::PowerMove::ZUDStartHailWeather < Battle::PowerMove::GeneralEffect
  def initialize(battle, move)
    super
    @weather = :Hail
  end
end


#===============================================================================
# Starts grassy terrain. (Max Overgrowth)
#===============================================================================
class Battle::PowerMove::ZUDStartGrassyTerrain < Battle::PowerMove::GeneralEffect
  def initialize(battle, move)
    super
    @terrain = :Grassy
  end
end


#===============================================================================
# Starts electric terrain. (Max Lightning)
#===============================================================================
class Battle::PowerMove::ZUDStartElectricTerrain < Battle::PowerMove::GeneralEffect
  def initialize(battle, move)
    super
    @terrain = :Electric
  end
end


#===============================================================================
# Starts misty terrain. (Max Starfall)
#===============================================================================
class Battle::PowerMove::ZUDStartMistyTerrain < Battle::PowerMove::GeneralEffect
  def initialize(battle, move)
    super
    @terrain = :Misty
  end
end


#===============================================================================
# Starts psychic terrain. (Genesis Supernova, Max Mindstorm)
#===============================================================================
class Battle::PowerMove::ZUDStartPsychicTerrain < Battle::PowerMove::GeneralEffect
  def initialize(battle, move)
    super
    @terrain = :Psychic
  end
end


#===============================================================================
# Removes any active terrain. (Splintered Stormshards)
#===============================================================================
class Battle::PowerMove::ZUDRemoveTerrain < Battle::PowerMove::GeneralEffect
  def initialize(battle, move)
    super
    @terrain = :None
  end
end


#===============================================================================
# Starts gravity. (G-Max Gravitas)
#===============================================================================
class Battle::PowerMove::ZUDStartGravity < Battle::PowerMove::GeneralEffect
  def initialize(battle, move)
    super
    @field = [ [PBEffects::Gravity, 5, "Gravity intensified!"] ]
  end
end