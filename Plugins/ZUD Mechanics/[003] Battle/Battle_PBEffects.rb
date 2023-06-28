#===============================================================================
# New PBEffects.
#===============================================================================
module PBEffects  
  #-----------------------------------------------------------------------------
  # Battler effects.
  #-----------------------------------------------------------------------------
  Dynamax          = 303  # The Dynamax state, and how many turns until it expires.
  NonGMaxForm      = 304  # Records a G-Max Pokemon's base form to revert to (used for Alcremie).
  GMaxTrapping     = 305  # Flags a battler as being trapped by a G-Max move, and persists even if the trap user switches out.
  MaxGuard         = 306  # The effect for the move Max Guard.
  
  #-----------------------------------------------------------------------------
  # Battler effects (Max Raid Battles).
  #-----------------------------------------------------------------------------
  MaxRaidBoss      = 307  # The effect that designates a Max Raid Pokemon.
  RaidShield       = 308  # The current HP for a Max Raid Pokemon's shields.
  MaxShieldHP      = 309  # The maximum total HP a Max Raid Pokemon's shields can have.
  ShieldCounter    = 310  # The counter for triggering Raid Shields and other effects.
  KnockOutCount    = 311  # The counter for KO's a Raid Pokemon needs to end the raid.
  
  #-----------------------------------------------------------------------------
  # Effects that apply to a side.
  #-----------------------------------------------------------------------------
  ZHeal            = 200  # The healing effect of Z-Parting Shot/Z-Memento.
  VineLash         = 201  # The lingering effect of G-Max Vine Lash.
  Wildfire         = 202  # The lingering effect of G-Max Wildfire.
  Cannonade        = 203  # The lingering effect of G-Max Cannonade.
  Volcalith        = 204  # The lingering effect of G-Max Volcalith.
  Steelsurge       = 205  # The hazard effect of G-Max Steelsurge.
end


#===============================================================================
# Allows the setting of newly-added effects in the battle Debug menu.
#===============================================================================
module Battle::DebugVariables
  BATTLER_EFFECTS[PBEffects::MaxGuard] = { name: "Max Guard applies this round",          default: false }
  POSITION_EFFECTS[PBEffects::ZHeal]   = { name: "Whether Z-Healing is waiting to apply", default: false }
  SIDE_EFFECTS[PBEffects::VineLash]    = { name: "G-Max Vine Lash duration",              default: 0     }
  SIDE_EFFECTS[PBEffects::Wildfire]    = { name: "G-Max Wildfire duration",               default: 0     }
  SIDE_EFFECTS[PBEffects::Cannonade]   = { name: "G-Max Cannonade duration",              default: 0     }
  SIDE_EFFECTS[PBEffects::Volcalith]   = { name: "G-Max Volcalith duration",              default: 0     }
  SIDE_EFFECTS[PBEffects::Steelsurge]  = { name: "G-Max Steelsurge exists",               default: false }
end


#===============================================================================
# Allows newly-added effects to be utilized in a Deluxe battle hash.
#===============================================================================
$DELUXE_BATTLE_EFFECTS[:team_default_false] += [PBEffects::Steelsurge]
$DELUXE_BATTLE_EFFECTS[:team_default_zero]  += [PBEffects::Cannonade, PBEffects::VineLash, PBEffects::Volcalith, PBEffects::Wildfire]