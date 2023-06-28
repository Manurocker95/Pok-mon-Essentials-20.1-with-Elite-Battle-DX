#===============================================================================
# The general Battle::PowerMove class.
#===============================================================================
class Battle::PowerMove < Battle::Move
  def initialize(battle, move)
    validate move => Pokemon::Move
    super(battle, move)
    @category       = (GameData::Move.get(move.id).category == 2) ? 2 : @old_move.category
    if @baseDamage <= 10 && @category < 2
      @baseDamage   = calc_damage_zmove   if move.zMove?
      @baseDamage   = calc_damage_maxmove if move.maxMove?
    end
  end
  
  def self.from_pokemon_move(battle, move)
    validate move => Pokemon::Move
    code = move.function_code || "None"
    if code[/^\d/]
      class_name = sprintf("Battle::PowerMove::Effect%s", code)
    else
      class_name = sprintf("Battle::PowerMove::%s", code)
    end
    if Object.const_defined?(class_name)
      return Object.const_get(class_name).new(battle, move)
    end
    return Battle::PowerMove::Unimplemented.new(battle, move)
  end
  
  #-----------------------------------------------------------------------------
  # Abilities that change move type don't work on Power Moves. (unless Z-Powered status moves)
  #-----------------------------------------------------------------------------
  def pbBaseType(user)
    return super(user) if @zmove_flag
    return @type
  end
  
  #-----------------------------------------------------------------------------
  # Protection moves don't fully negate Power Moves.
  #-----------------------------------------------------------------------------
  def pbModifyDamage(damageMult, user, target)
    return damageMult if @function == "ZUDBypassProtect" # G-Max One Blow/Rapid Flow
    protected = false
    if target.effects[PBEffects::Protect]       || 
       target.effects[PBEffects::KingsShield]   ||
       target.effects[PBEffects::SpikyShield]   ||
       target.effects[PBEffects::BanefulBunker] ||
       target.effects[PBEffects::Obstruct]      ||
       target.pbOwnSide.effects[PBEffects::MatBlock]
      protected = true
    elsif defined?(PBEffects::SilkTrap) && target.effects[PBEffects::SilkTrap]
      protected = true
    elsif GameData::Target.get(@target).num_targets > 1 &&
          target.pbOwnSide.effects[PBEffects::WideGuard]
      protected = true
    end
    if protected
      @battle.pbDisplay(_INTL("{1} couldn't fully protect itself!", target.pbThis))
      return damageMult / 4
    end
    return damageMult
  end
  
  #-----------------------------------------------------------------------------
  # Calculates the base power of a Z-Move, based on the original move.
  #-----------------------------------------------------------------------------
  def calc_damage_zmove
    damage   = @old_move.baseDamage
    function = @old_move.function 
    return 0 if statusMove? || @zmove_flag
    case function
    when "OHKO",                      # Horn Drill, Guillotine, etc.
         "OHKOIce",                   # Sheer Cold
         "OHKOHitsUndergroundTarget"  # Fissure
      return 180
    end 
    case @old_move.id
    when :VCREATE;        return 220
    when :GEARGRIND;      return 180
    when :FLYINGPRESS;    return 170
    when :HEX;            return 160
    when :WEATHERBALL;    return 160
    when :COREENFORCER;   return 140
    when :MEGADRAIN;      return 120
    when :STRUGGLE;       return 1
    end
    if    damage >= 140;  return 200
    elsif damage >= 130;  return 195
    elsif damage >= 120;  return 190
    elsif damage >= 110;  return 185
    elsif damage >= 100;  return 180
    elsif damage >= 90;   return 175
    elsif damage >= 80;   return 160
    elsif damage >= 70;   return 140
    elsif damage >= 60;   return 120
    else                  return 100
    end
  end
  
  #-----------------------------------------------------------------------------
  # Calculates the base power of a Max Move, based on the original move.
  #-----------------------------------------------------------------------------
  def calc_damage_maxmove
    damage   = @old_move.baseDamage
    function = @old_move.function 
    return 0 if @old_move.statusMove?
    weaken = Settings::MOVE_TYPES_TO_WEAKEN.include?(@old_move.type)
    case function
    when "PowerHigherWithUserHP"                        # Eruption, Water Spout, etc.
      return (weaken) ? 100 : 150
    when "PowerHigherWithTargetHP"                      # Crush Grip
      return (weaken) ?  95 : 140
    when "HitTwoTimes",                                 # Bonemarang, Dual Wingbeat, etc.
         "HitTwoTimesTargetThenTargetAlly",             # Dragon Darts
         "HitTwoTimesFlinchTarget",                     # Double Iron Bash
         "HitThreeTimesPowersUpWithEachHit"             # Triple Kick
      dmg = (damage >= 60) ? 140 : (damage >= 40) ? 130 : 120
      return (weaken) ? dmg - 40 : dmg
    when "OHKO",                                        # Horn Drill, Guillotine, etc.
         "OHKOIce",                                     # Sheer Cold
         "OHKOHitsUndergroundTarget",                   # Fissure
         "PowerLowerWithUserHP",                        # Flail, Reversal, etc.
         "LowerTargetHPToUserHP",                       # Endeavor
         "PowerHigherWithUserFasterThanTarget",         # Electro Ball
         "PowerHigherWithTargetFasterThanUser",         # Gyro Ball
         "PowerHigherWithTargetWeight",                 # Grass Knot, Low Kick, etc.
         "PowerHigherWithUserHeavierThanTarget",        # Heavy Slam, Heat Crash, etc.
         "PowerHigherWithUserPositiveStatStages"        # Stored Power, Power Trip, etc.
      return (weaken) ?  100 : 130
    when "HitTwoToFiveTimes",                           # Bullet Seed, Pin Missile, etc.
         "HitTwoToFiveTimesRaiseUserSpd1LowerUserDef1", # Scale Shot
         "HitThreeTimesAlwaysCriticalHit"               # Surging Strikes
      dmg = (damage >= 25) ? 130 : 100
      return (weaken) ? dmg - 30 : dmg
    when "FixedDamageUserLevel",                        # Night Shade, Seismic Toss, etc.
         "FixedDamageUserLevelRandom",                  # Psywave
         "FixedDamageHalfTargetHP",                     # Super Fang
         "UserFaintsFixedDamageUserHP",                 # Final Gambit
         "CounterPhysicalDamage",                       # Counter
         "CounterSpecialDamage",                        # Mirror Coat
         "CounterDamagePlusHalf",                       # Metal Burst
         "HitOncePerUserTeamMember",                    # Beat Up
         "ThrowUserItemAtTarget",                       # Fling
         "RandomlyDamageOrHealTarget",                  # Present
         "PowerDependsOnUserStockpile"                  # Spit Up
      return (weaken) ?  75 : 100
    end
    if    damage >= 150;  return (weaken) ? 100 : 150
    elsif damage >= 110;  return (weaken) ?  95 : 140
    elsif damage >= 75;   return (weaken) ?  90 : 130
    elsif damage >= 65;   return (weaken) ?  85 : 120
    elsif damage >= 55;   return (weaken) ?  80 : 110
    elsif damage >= 45;   return (weaken) ?  75 : 100
    else                  return (weaken) ?  70 : 90
    end
  end
end