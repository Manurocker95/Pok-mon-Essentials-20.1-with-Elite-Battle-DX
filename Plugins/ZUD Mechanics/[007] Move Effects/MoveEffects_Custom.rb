################################################################################
################################################################################
# CUSTOM MOVES
################################################################################
################################################################################


#===============================================================================
# Starts sunny weather and grassy terrain. (G-Max Sun Bloom)
#===============================================================================
class Battle::PowerMove::ZUDStartSunWeatherGrassyTerrain < Battle::PowerMove::GeneralEffect
  def initialize(battle, move)
    super
    @weather = :Sun
    @terrain = :Grassy
  end
end


#===============================================================================
# Starts rain weather and electric terrain. (G-Max Thunderstorm)
#===============================================================================
class Battle::PowerMove::ZUDStartRainWeatherElectricTerrain < Battle::PowerMove::GeneralEffect
  def initialize(battle, move)
    super
    @weather = :Rain
    @terrain = :Electric
  end
end


#===============================================================================
# Starts Trick Room. (G-Max Inversion)
#===============================================================================
class Battle::PowerMove::ZUDStartTrickRoom < Battle::PowerMove::GeneralEffect
  def initialize(battle, move)
    super
    @field = [ [PBEffects::TrickRoom, 3, "{1} twisted the dimensions!"] ]
  end
end


#===============================================================================
# Starts Magic Room. No Pokemon can flee or switch out for 3 turns. (Magical Fairy Lock)
#===============================================================================
class Battle::PowerMove::ZUDStartMagicRoomFairyLock < Battle::PowerMove::GeneralEffect
  def initialize(battle, move)
    super
    @field = [
      [PBEffects::MagicRoom, 3, "A bizarre area was created in which Pokémon's held items lose their effects!"],
      [PBEffects::FairyLock, 3, "No one can escape for 3 turns!"]
    ]
  end
end


#===============================================================================
# For 3 rounds, applies the effects of all Pledge move combinations. (Trinity Pledge)
#===============================================================================
class Battle::PowerMove::ZUDStartPledgeEffects < Battle::PowerMove::GeneralEffect
  def initialize(battle, move)
    super
    @team_effects = { 
      :allies => [ 
        [PBEffects::Rainbow, 3, "A rainbow appeared in the sky on {1}'s side!", true] 
      ],
      :opposing => [
        [PBEffects::Swamp,     3, "A swamp enveloped {1}!"],
        [PBEffects::SeaOfFire, 3, "A sea of fire enveloped {1}!"]
      ]
    }
  end
end


#===============================================================================
# Applies every possible effect. Please don't actually use this monstrosity, it's 
# here to serve as an extreme example. (G-Max Kitchen Sink)
#===============================================================================
class Battle::PowerMove::ZUDKitchenSink < Battle::PowerMove::GeneralEffect
  def initialize(battle, move)
    super
    #---------------------------------------------------------------------------
    # Stat changes.
    #---------------------------------------------------------------------------
    @stat_changes = {
      :user      => [:ATTACK, 2, :DEFENSE, 2, :SPEED, -1],
      :target    => [:SPECIAL_ATTACK, -2, :SPECIAL_DEFENSE, - 2, :SPEED, 1],
      :allies    => [:ACCURACY, 6],
      :opponents => [:EVASION, -6]
    }
    #---------------------------------------------------------------------------
    # Statuses.
    #---------------------------------------------------------------------------
    @statuses = {
      :user      => [:CONFUSION],
      :allies    => [:NONE],
      :target    => [:ATTRACT],
      :opponents => [:SLEEP, :FROZEN, :PARALYSIS, :BURN, :POISON, :TOXIC, :CONFUSION, :ATTRACT]
    }
    #---------------------------------------------------------------------------
    # Battler effects.
    #---------------------------------------------------------------------------
    @battler_effects = { 
      :user      => [
        [PBEffects::BurnUp,      true],
        [PBEffects::DefenseCurl, true],
        [PBEffects::Minimize,    true],
        [PBEffects::Rage,        true],
        [PBEffects::AquaRing,    true, "{1} surrounded itself with a veil of water!"],
        [PBEffects::Ingrain,     true, "{1} planted its roots!"],
        [PBEffects::Endure,      true, "{1} braced itself!"],
        [PBEffects::HelpingHand, true, "{1} is ready to help its allies!"],
        [PBEffects::Imprison,    true, "{1} sealed any moves its target shares with it!"],
        [PBEffects::MagicCoat,   true, "{1} shrouded itself with Magic Coat!"],
        [PBEffects::NoRetreat,   true, "{1} can no longer escape!"],
        [PBEffects::PowerTrick,  true, "{1} switched its Attack and Defense!"],
        [PBEffects::Grudge,      true, "{1} wants its target to bear a grudge!"],
        [PBEffects::Charge,         2, "{1} began charging power!"],
        [PBEffects::LaserFocus,     2, "{1} concentrated intensely!"]
      ],
      :allies    => [
        [PBEffects::HelpingHand, true],
        [PBEffects::Electrify,   true, "{1}'s moves have been electrified!"],
        [PBEffects::MagnetRise,     5, "{1} levitated with electromagnetism!"],
        [PBEffects::FocusEnergy,    3, "{1} is getting pumped!"],
        [PBEffects::Type3,     :GHOST, "{1} transformed into the Ghost type!"]
      ],
      :target    => [
        [PBEffects::MiracleEye,  true],
        [PBEffects::Curse,       true, "{1} was afflicted with a curse!"],
        [PBEffects::Foresight,   true, "{1} was identified!"],
        [PBEffects::Torment,     true, "{1} was subjected to torment!"],
        [PBEffects::Taunt,          4, "{1} fell for the taunt!"],
        [PBEffects::Telekinesis,    3, "{1} was hurled into the air!"],
        [PBEffects::ThroatChop,     3, "{1} is prevented from using sound-based moves!"],
        [PBEffects::Yawn,           2, "{1} became drowsy!"]
      ],
      :opponents => [
        [PBEffects::SmackDown,   true],
        [PBEffects::GastroAcid,  true, "{1}'s Ability was suppressed!"],
        [PBEffects::Nightmare,   true, "{1} began having a nightmare!"],
        [PBEffects::Powder,      true, "{1} is covered in powder!"],
        [PBEffects::TarShot,     true, "{1} became weaker to fire!"],
        [PBEffects::Embargo,        5, "{1} can't use items anymore!"],
        [PBEffects::HealBlock,      5, "{1} was prevented from healing!"],
        [PBEffects::Type3,    :NORMAL, "{1} transformed into the Normal type!"]
      ]
    }
    #---------------------------------------------------------------------------
    # Team effects.
    #---------------------------------------------------------------------------
    @team_effects = {
      :allies    => [
        # Effects to apply to ally party.
        [PBEffects::CraftyShield, true,  "Crafty Shield protected {1}!"],
        [PBEffects::AuroraVeil,  5,      "{1} became stronger against physical and special moves!"],
        [PBEffects::LightScreen, 5,      "{1} became stronger against special moves!"],
        [PBEffects::Reflect,     5,      "{1} became stronger against physical moves!"],
        [PBEffects::Mist,        5,      "{1} became shrouded in mist!"],
        [PBEffects::Safeguard,   5,      "{1} became cloaked in a mystical veil!"],
        [PBEffects::LuckyChant,  5,      "The Lucky Chant shielded {1} from critical hits!"],
        [PBEffects::Tailwind,    4,      "The Tailwind blew from behind {1}!"],
        [PBEffects::Rainbow,     4,      "A rainbow appeared in the sky on {1}'s side!"],
        # Effects to remove from ally party.
        [PBEffects::StealthRock, false,  "{1} blew away stealth rocks!",     true],
        [PBEffects::Steelsurge,  false,  "{1} blew away the pointed steel!", true],
        [PBEffects::StickyWeb,   false,  "{1} blew away sticky webs!",       true],
        [PBEffects::Spikes,      0,      "{1} blew away spikes!",            true],
        [PBEffects::ToxicSpikes, 0,      "{1} blew away poison spikes!",     true],
        [PBEffects::Swamp,       0,      "The swamp around {1} disappeared!"],
        [PBEffects::SeaOfFire,   0,      "The sea of fire around {1} disappeared!"],
        [PBEffects::VineLash,    0,      "{1} was released from G-Max Vine Lash's beating!"],
        [PBEffects::Wildfire,    0,      "{1} was released from G-Max Wildfire's flames!"],
        [PBEffects::Cannonade,   0,      "{1} was released from G-Max Cannonade's vortex!"],
        [PBEffects::Volcalith,   0,      "Rocks stopped being thrown out by G-Max Volcalith on {1}!"]
      ],
      :opponents => [
        # Effects to apply to foe party.
        [PBEffects::StealthRock, true,   "Pointed stones float in the air around {1}!"],
        [PBEffects::Steelsurge,  true,   "Sharp-pointed pieces of steel started floating around {1}!"],
        [PBEffects::StickyWeb,   true,   "A sticky web has been laid out beneath {1}'s feet!"],
        [PBEffects::Spikes,      1,      "Spikes were scattered all around {1}'s feet!"],
        [PBEffects::ToxicSpikes, 1,      "Poison spikes were scattered all around {1}'s feet!"],
        [PBEffects::Swamp,       3,      "A swamp enveloped {1}!"],
        [PBEffects::SeaOfFire,   3,      "A sea of fire enveloped {1}!"],
        [PBEffects::VineLash,    4,      "{1} got trapped with vines!"],
        [PBEffects::Wildfire,    4,      "{1} were surrounded by fire!"],
        [PBEffects::Cannonade,   4,      "{1} got caught in a vortex of water!"],
        [PBEffects::Volcalith,   4,      "{1} became surrounded by rocks!"],
        # Effects to remove from foe party.
        [PBEffects::CraftyShield, false, "{1} is no longer protected by Crafty Shield!"],
        [PBEffects::AuroraVeil,  0,      "{1}'s Aurora Veil wore off!"],
        [PBEffects::LightScreen, 0,      "{1}'s Light Screen wore off!"],
        [PBEffects::Reflect,     0,      "{1}'s Reflect wore off!"],
        [PBEffects::Mist,        0,      "{1}'s Mist faded!"],
        [PBEffects::Safeguard,   0,      "{1} is no longer protected by Safeguard!"],
        [PBEffects::LuckyChant,  0,      "{1}'s Lucky Chant ended!"],
        [PBEffects::Tailwind,    0,      "{1}'s Tailwind petered out!"],
        [PBEffects::Rainbow,     0,      "{1}'s Rainbow faded!"]
      ]
    }
    #---------------------------------------------------------------------------
    # Weather & Terrain.
    #---------------------------------------------------------------------------
    @weather = :Random
    @terrain = :Random
    #---------------------------------------------------------------------------
    # Field effects.
    #---------------------------------------------------------------------------
    @field = [
      [PBEffects::HappyHour,       true, "Everyone is caught up in the happy atmosphere!"],
      [PBEffects::IonDeluge,       true, "A deluge of ions showers the battlefield!"],
      [PBEffects::Gravity,         5,    "Gravity intensified!"],
      [PBEffects::WaterSportField, 5,    "Fire's power was weakened!"],
      [PBEffects::MudSportField,   5,    "Electricity's power was weakened!"],
      [PBEffects::TrickRoom,       3,    "{1} twisted the dimensions!"],
      [PBEffects::MagicRoom,       3,    "A bizarre area was created in which Pokémon's held items lose their effects!"],
      [PBEffects::WonderRoom,      3,    "A bizarre area was created in which the Defense and Sp. Def stats are swapped!"],
      [PBEffects::FairyLock,       3,    "No one can escape for 3 turns!"]
    ]
  end
end