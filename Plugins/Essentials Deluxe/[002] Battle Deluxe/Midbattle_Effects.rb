#===============================================================================
# Allows for various PBEffects to be triggered through mid-battle settings.
#===============================================================================


#-------------------------------------------------------------------------------
# Hash of eligible effects that may be set with deluxe battle settings.
# Note: Other plugins may add additional effects to this hash.
#-------------------------------------------------------------------------------
$DELUXE_BATTLE_EFFECTS = {
  :battler_default_false => [
    PBEffects::AquaRing,
    PBEffects::Curse,
    PBEffects::GastroAcid,
    PBEffects::Ingrain,
    PBEffects::PowerTrick,
    PBEffects::BurnUp,
    PBEffects::DefenseCurl,
    PBEffects::Electrify,
    PBEffects::Endure,
    PBEffects::Foresight,
    PBEffects::Grudge,
    PBEffects::HelpingHand,
    PBEffects::Imprison,
    PBEffects::MagicCoat,
    PBEffects::Minimize,
    PBEffects::MiracleEye,
    PBEffects::MudSport,
  # PBEffects::Nightmare - Settable, but isn't listed here.
    PBEffects::NoRetreat,
    PBEffects::Powder,
    PBEffects::Rage,
    PBEffects::Roost,
    PBEffects::SmackDown,
    PBEffects::TarShot,
    PBEffects::Torment,
    PBEffects::WaterSport
  ],
  :battler_default_zero => [
    PBEffects::Charge,
  # PBEffects::CriticalBoost - Settable, but isn't listed here.
    PBEffects::Embargo,
    PBEffects::FocusEnergy,
    PBEffects::HealBlock,
    PBEffects::LaserFocus,
  # PBEffects::MagnetRise - Settable, but isn't listed here.
    PBEffects::Taunt,
  # PBEffects::Telekinesis - Settable, but isn't listed here.
    PBEffects::ThroatChop,
  # PBEffects::Type3 - Settable, but isn't listed here.
    PBEffects::WeightChange
  # PBEffects::Yawn - Settable, but isn't listed here.
  ],
  :team_default_false => [
    PBEffects::CraftyShield,
    PBEffects::StealthRock,
    PBEffects::StickyWeb
  ],
  :team_default_zero => [
  # PBEffects::Aurora Veil - Settable, but isn't listed here.
  # PBEffects::LightScreen - Settable, but isn't listed here.
    PBEffects::LuckyChant,
    PBEffects::Mist,
    PBEffects::Rainbow,
  # PBEffects::Reflect - Settable, but isn't listed here.
    PBEffects::Safeguard,
    PBEffects::SeaOfFire,
  # PBEffects::Spikes - Settable, but isn't listed here.
    PBEffects::Swamp,
    PBEffects::Tailwind,
  # PBEffects::ToxicSpikes - Settable, but isn't listed here.
  ],
  :field_default_false => [
    PBEffects::HappyHour,
    PBEffects::IonDeluge
  ],
  :field_default_zero => [
    PBEffects::FairyLock,
    PBEffects::Gravity,
    PBEffects::MagicRoom,
    PBEffects::MudSportField,
    PBEffects::TrickRoom,
    PBEffects::WaterSportField,
    PBEffects::WonderRoom
  ]
}


#-------------------------------------------------------------------------------
# Used to apply the above effects in battle.
#-------------------------------------------------------------------------------
class Battle::Battler
  #-----------------------------------------------------------------------------
  # Sets a battler effect to a specific setting, with a custom message.
  #-----------------------------------------------------------------------------
  def apply_battler_effects(effect, setting, msg = nil, lowercase = false)
    case effect
    when PBEffects::Type3
      if GameData::Type.exists?(setting) && !pbHasType?(setting)
        @effects[effect] = setting
        @battle.pbDisplay(_INTL(msg, pbThis(lowercase))) if msg
      end
    when PBEffects::Nightmare
      if !@effects[effect] && self.asleep? && setting
        @effects[effect] = setting
        @battle.pbDisplay(_INTL(msg, pbThis(lowercase))) if msg
      else
        @effects[effect] = false
      end
    when PBEffects::Yawn
      if self.status == :NONE
        if @effects[effect] > 0 && setting == 0 || (@effects[effect] == 0 && setting > 0)
          @effects[effect] = setting
          @battle.pbDisplay(_INTL(msg, pbThis(lowercase))) if msg
        end
      else
        @effects[effect] = 0
      end
    when PBEffects::MagnetRise, PBEffects::Telekinesis
      if @battle.field.effects[PBEffects::Gravity] == 0
        if @effects[effect] > 0 && setting == 0 || (@effects[effect] == 0 && setting > 0)
          @effects[effect] = setting
          @battle.pbDisplay(_INTL(msg, pbThis(lowercase))) if msg
        end
      else
        @effects[effect] = 0
      end
    when PBEffects::CriticalBoost
      if @effects[effect] > 0 && setting == 0
        @effects[effect] = setting
        @battle.pbDisplay(_INTL(msg, pbThis(lowercase))) if msg
      else
        @effects[effect] += setting
        @effects[effect] = 0 if @effects[effect] < 0
        @battle.pbDisplay(_INTL(msg, pbThis(lowercase))) if msg
      end
    else
      if PluginManager.installed?("Focus Meter System") && effect == PBEffects::FocusStyle
        if GameData::Focus.exists?(setting) && @effects[effect] != setting
          @effects[effect] = setting 
          @battle.pbDisplay(_INTL(msg, pbThis(lowercase))) if msg
        end
      elsif $DELUXE_BATTLE_EFFECTS[:battler_default_false].include?(effect)
        if @effects[effect] != setting
          @effects[effect] = setting 
          @battle.pbDisplay(_INTL(msg, pbThis(lowercase))) if msg
        end
      elsif $DELUXE_BATTLE_EFFECTS[:battler_default_zero].include?(effect)
        if (@effects[effect] > 0 && setting == 0) ||
           (@effects[effect] == 0 && setting > 0)
          @effects[effect] = setting
          @battle.pbDisplay(_INTL(msg, pbThis(lowercase))) if msg
        end
      end
    end
    pbAbilityStatusCureCheck
    pbItemStatusCureCheck
  end
  
  
  #-----------------------------------------------------------------------------
  # Sets a team effect to a specific setting, with a custom message.
  #-----------------------------------------------------------------------------
  def apply_team_effects(effect, setting, idxSide, skip_message = [], msg = nil, lowercase = false, user = false)
    repeat_message = nil
    case idxSide
    when 0
      side = pbOwnSide
      team = pbTeam(lowercase)
    when 1
      side = pbOpposingSide
      team = pbOpposingTeam(lowercase)
    end
    team = pbThis(lowercase) if user
    case effect
    when PBEffects::Spikes, PBEffects::ToxicSpikes
      max = (effect == PBEffects::Spikes) ? 3 : 2
      if side.effects[effect] > 0 && setting == 0
        side.effects[effect] = setting
        @battle.pbDisplay(_INTL(msg, team)) if msg && !skip_message.include?(effect)
        repeat_message = effect
      elsif side.effects[effect] < max && setting > 0
        side.effects[effect] += setting
        side.effects[effect] = max if side.effects[effect] > max
        side.effects[effect] = 0 if side.effects[effect] < 0
        @battle.pbDisplay(_INTL(msg, team)) if msg
      end
    when PBEffects::AuroraVeil, PBEffects::LightScreen, PBEffects::Reflect 
      if side.effects[effect] > 0 && setting == 0
        side.effects[effect] = setting
        @battle.pbDisplay(_INTL(msg, team)) if msg
      elsif side.effects[effect] == 0 && setting > 0
        side.effects[effect] = setting
        side.effects[effect] += 3 if self.hasActiveItem?(:LIGHTCLAY) && setting > 0
        side.effects[effect] = 0 if side.effects[effect] < 0
        @battle.pbDisplay(_INTL(msg, team)) if msg
      end
    else
      if $DELUXE_BATTLE_EFFECTS[:team_default_false].include?(effect)
        if side.effects[effect] != setting
          side.effects[effect] = setting 
          @battle.pbDisplay(_INTL(msg, team)) if msg && !skip_message.include?(effect)
          if [PBEffects::StealthRock, PBEffects::StickyWeb].include?(effect) ||
             PluginManager.installed?("ZUD Mechanics") && effect == PBEffects::Steelsurge
            repeat_message = effect if !setting
          end
        end
      elsif $DELUXE_BATTLE_EFFECTS[:team_default_zero].include?(effect)
        if (side.effects[effect] > 0 && setting == 0) ||
           (side.effects[effect] == 0 && setting > 0)
          side.effects[effect] = setting
          @battle.pbDisplay(_INTL(msg, team)) if msg
        end
      end
    end
    return repeat_message
  end
  
  
  #-----------------------------------------------------------------------------
  # Sets a field effect to a specific setting, with a custom message.
  #-----------------------------------------------------------------------------
  def apply_field_effects(effect, setting, msg = nil, lowercase = false)
    if $DELUXE_BATTLE_EFFECTS[:field_default_false].include?(effect)
      return if @battle.field.effects[effect] == setting
      @battle.field.effects[effect] = setting
      @battle.pbDisplay(_INTL(msg, pbThis(lowercase))) if msg
    elsif $DELUXE_BATTLE_EFFECTS[:field_default_zero].include?(effect)
      return if @battle.field.effects[effect] > 0 && setting > 0
      @battle.field.effects[effect] = setting
      @battle.pbDisplay(_INTL(msg, pbThis(lowercase))) if msg
      case effect
      when PBEffects::TrickRoom
        if @battle.field.effects[PBEffects::TrickRoom] > 0
          @battle.allBattlers.each do |b|
            next if !b.hasActiveItem?(:ROOMSERVICE)
            next if !b.pbCanLowerStatStage?(:SPEED)
            @battle.pbCommonAnimation("UseItem", b)
            b.pbLowerStatStage(:SPEED, 1, nil)
            b.pbConsumeItem
          end
        end
      when PBEffects::Gravity
        if @battle.field.effects[PBEffects::Gravity] > 0
          @battle.allBattlers.each do |b|
            showMessage = false
            if b.inTwoTurnAttack?("TwoTurnAttackInvulnerableInSky",
                                  "TwoTurnAttackInvulnerableInSkyParalyzeTarget",
                                  "TwoTurnAttackInvulnerableInSkyTargetCannotAct")
              b.effects[PBEffects::TwoTurnAttack] = nil
              @battle.pbClearChoice(b.index) if !b.movedThisRound?
              showMessage = true
            end
            if b.effects[PBEffects::MagnetRise]  >  0 ||
               b.effects[PBEffects::Telekinesis] >  0 ||
               b.effects[PBEffects::SkyDrop]     >= 0
              b.effects[PBEffects::MagnetRise]    = 0
              b.effects[PBEffects::Telekinesis]   = 0
              b.effects[PBEffects::SkyDrop]       = -1
              showMessage = true
            end
            @battle.pbDisplay(_INTL("{1} couldn't stay airborne because of gravity!", b.pbThis)) if showMessage
          end
        end
      end
    end
  end
end


#-------------------------------------------------------------------------------
# Used for getting the name of various effects that count down each turn.
#-------------------------------------------------------------------------------
def dxConvertToPBEffect(effect, type)
  case type
  when :battler
  case effect
	when 19  then return :Disable
	when 22  then return :Embargo
	when 37  then return :HealBlock
	when 53  then return :MagnetRise
	when 99  then return :Taunt
	when 100 then return :Telekinesis
	when 116 then return :Yawn
	when 313 then return :FocusLock
	end
  when :side
  case effect
	when 0   then return :AuroraVeil
	when 5   then return :LightScreen
	when 6   then return :LuckyChant
	when 8   then return :Mist
	when 10  then return :Rainbow
	when 11  then return :Reflect
	when 13  then return :Safeguard
	when 14  then return :SeaOfFire
	when 18  then return :Swamp
	when 19  then return :Tailwind
	when 201 then return :VineLash
	when 202 then return :Wildfire
	when 203 then return :Cannonade
	when 204 then return :Volcalith
	when 206 then return :FocusedGuard
	end
  when :field
  case effect
	when 4  then return :Gravity
	when 7  then return :MagicRoom
	when 8  then return :MudSportField
	when 10 then return :TrickRoom
	when 11 then return :WaterSportField
	when 12 then return :WonderRoom
	end
  end
  return nil
end