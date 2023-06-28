#===============================================================================
# Formatting Move Effects that apply effects to one side of the field.
#===============================================================================
# To set up a custom move effect that applies effects to a team's side, all that 
# is required is initializing a @team_effects hash, where each key in the hash 
# can be one of the following symbols, set as an array:
#
#	:allies    => [Effects that apply to the user's side of the field]
#	:opponents => [Effects that apply to the opponent's side of the field]
#
# Each of these arrays may then contain their own arrays within them designating
# the effects to apply to the specified team. These arrays should contain the
# following three elements: [Effect, setting, message, focus]
#
# Effect  = The PBEffect that you wish to set on this side.
# Setting = What you want to set this PBEffect to (true/false, number, etc).
# Message = The message that should be displayed upon applying this effect.
#           This element may be omitted if you do not want a message displayed.
#           Messages may contain a single "{1}" to refer to the party the
#           designated effect is being applied to.
# Focus   = You can set this fourth element to "true" to make it so that the
#           "{1}" in the inputted message refers to the user of the move,
#           instead of the target party. You can ignore this setting otherwise.
#
# The following are all of the effects that may be set in these arrays:
#   AuroraVeil
#   Cannonade
#   CraftyShield
#   LightScreen
#   LuckyChant
#   Mist
#   Rainbow
#   Reflect
#   Safeguard
#   SeaOfFire
#   Spikes
#   StealthRock
#   Steelsurge
#   StickyWeb
#   Swamp
#   Tailwind
#   ToxicSpikes
#   VineLash
#   Volcalith
#   Wildfire
#
# For example, this will set a layer of Spikes and a Sticky Web on the opposing side, 
# while setting up Mat Block on yours.
#
# @side_effects = { 
#	:allies    => [ 
#	  [PBEffects::MatBlock, true, "{1} intends to flip up a mat and block incoming attacks!"] 
#	],
#	:opponents => [ 
#	  [PBEffects::Spikes, 1, "Spikes were scattered all around {1}'s feet!"],
#	  [PBEffects::StickyWeb, true, "A sticky web has been laid out beneath {1}'s feet!"]
#	]
# }
#
# Review how the following individual moves are set up below for guidance.
#-------------------------------------------------------------------------------


#===============================================================================
# Starts the Vine Lash effect on the opposing side for 4 turns. (G-Max Vine Lash)
#===============================================================================
class Battle::PowerMove::ZUDStartVineLashOnFoeSide < Battle::PowerMove::GeneralEffect
  def initialize(battle, move)
    super
    @team_effects = { 
      :opponents => [ [PBEffects::VineLash, 4, "{1} got trapped with vines!"] ]
    }
  end
end


#===============================================================================
# Starts the Wildfire effect on the opposing side for 4 turns. (G-Max Wildfire)
#===============================================================================
class Battle::PowerMove::ZUDStartWildfireOnFoeSide < Battle::PowerMove::GeneralEffect
  def initialize(battle, move)
    super
    @team_effects = { 
      :opponents => [ [PBEffects::Wildfire, 4, "{1} were surrounded by fire!"] ]
    }
  end
end


#===============================================================================
# Starts the Cannonade effect on the opposing side for 4 turns. (G-Max Cannonade)
#===============================================================================
class Battle::PowerMove::ZUDStartCannonadeOnFoeSide < Battle::PowerMove::GeneralEffect
  def initialize(battle, move)
    super
    @team_effects = { 
      :opponents => [ [PBEffects::Cannonade, 4, "{1} got caught in a vortex of water!"] ]
    }
  end
end


#===============================================================================
# Starts the Volcalith effect on the opposing side for 4 turns. (G-Max Volcalith)
#===============================================================================
class Battle::PowerMove::ZUDStartVolcalithOnFoeSide < Battle::PowerMove::GeneralEffect
  def initialize(battle, move)
    super
    @team_effects = { 
      :opponents => [ [PBEffects::Volcalith, 4, "{1} became surrounded by rocks!"] ]
    }
  end
end


#===============================================================================
# Entry hazard. Lays stealth rocks on the opposing side. (G-Max Stonesurge)
#===============================================================================
class Battle::PowerMove::ZUDAddStealthRocksToFoeSide < Battle::PowerMove::GeneralEffect
  def initialize(battle, move)
    super
    @team_effects = { 
      :opponents => [ [PBEffects::StealthRock, true, "Pointed stones float in the air around {1}!"] ]
    }
  end
end


#===============================================================================
# Entry hazard. Lays sharp steel on the opposing side. (G-Max Steelsurge)
#===============================================================================
class Battle::PowerMove::ZUDAddSteelsurgeToFoeSide < Battle::PowerMove::GeneralEffect
  def initialize(battle, move)
    super
    @team_effects = { 
      :opponents => [ [PBEffects::Steelsurge, true, "Sharp-pointed pieces of steel started floating around {1}!"] ]
    }
  end
end


#===============================================================================
# For 5 rounds, lowers power of attacks against the user's side. (G-Max Resonance)
#===============================================================================
class Battle::PowerMove::ZUDStartAuroraVeilOnUserSide < Battle::PowerMove::GeneralEffect
  def initialize(battle, move)
    super
    @team_effects = { 
      :allies => [ [PBEffects::AuroraVeil, 5, "{1} became stronger against physical and special moves!"] ]
    }
  end
end


#===============================================================================
# Ends terrain, all barriers and entry hazards for the target's side, and entry
# hazards for the user's side. (G-Max Wind Rage)
#===============================================================================
class Battle::PowerMove::ZUDRemoveTerrainAndSideEffects < Battle::PowerMove::GeneralEffect
  def initialize(battle, move)
    super
    @terrain = :None
    @team_effects = { 
      :allies => [
        [PBEffects::Spikes,      0,     "{1} blew away spikes!",            true],
        [PBEffects::ToxicSpikes, 0,     "{1} blew away poison spikes!",     true],
        [PBEffects::StealthRock, false, "{1} blew away stealth rocks!",     true],
        [PBEffects::Steelsurge,  false, "{1} blew away the pointed steel!", true],
        [PBEffects::StickyWeb,   false, "{1} blew away sticky webs!",       true]
      ],
      :opponents => [
        [PBEffects::AuroraVeil,  0,     "{1}'s Aurora Veil wore off!"],
        [PBEffects::LightScreen, 0,     "{1}'s Light Screen wore off!"],
        [PBEffects::Reflect,     0,     "{1}'s Reflect wore off!"],
        [PBEffects::Mist,        0,     "{1}'s Mist faded!"],
        [PBEffects::Safeguard,   0,     "{1} is no longer protected by Safeguard!"],
        [PBEffects::Spikes,      0,     "{1} blew away spikes!",            true],
        [PBEffects::ToxicSpikes, 0,     "{1} blew away poison spikes!",     true],
        [PBEffects::StealthRock, false, "{1} blew away stealth rocks!",     true],
        [PBEffects::Steelsurge,  false, "{1} blew away the pointed steel!", true],
        [PBEffects::StickyWeb,   false, "{1} blew away sticky webs!",       true]
      ]
    }
  end
end