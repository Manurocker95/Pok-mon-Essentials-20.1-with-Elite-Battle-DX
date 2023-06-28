#===============================================================================
# General Power Move class used to handle most effects.
#===============================================================================
class Battle::PowerMove::GeneralEffect < Battle::PowerMove
  def initialize(battle, move)
    super
    @stat_changes    = {} 
    @statuses        = {}
    @battler_effects = {}
    @team_effects    = {}
    @weather         = nil
    @terrain         = nil
    @field           = []
  end
  
  
  #-----------------------------------------------------------------------------
  # Target types that target other Pokemon on the field. Used for determining
  # how this move's effect should be processed.
  #-----------------------------------------------------------------------------
  SELECTABLE_TARGET_TYPES = [
    :NearAlly, 
    :UserOrNearAlly, 
    :AllAllies,   
    :UserAndAllies, 
    :NearFoe,  
    :RandomNearFoe,  
    :AllNearFoes, 
    :Foe, 
    :AllFoes, 
    :NearOther, 
    :AllNearOthers, 
    :Other
  ]
  
 
  #-----------------------------------------------------------------------------
  # Used to determine if this move should fail if the move is one that doesn't
  # target, or only targets the user. Returns true if this move is a status move
  # and cannot apply any of its effects.
  #-----------------------------------------------------------------------------
  def pbMoveFailed?(user, targets)
    return false if damagingMove?
    return false if SELECTABLE_TARGET_TYPES.include?(self.target)
    check1 = pbFailureCheckGeneral(user)
    check2 = pbFailureCheckTarget(user, nil, false)
    if check1 && check2
      @battle.pbDisplay(_INTL("But it failed!"))
      return true
    end
    return false  
  end
  
  
  #-----------------------------------------------------------------------------
  # Used when this Power Move is a status move that doesn't target, or only 
  # targets the user.
  #-----------------------------------------------------------------------------
  def pbEffectGeneral(user)
    return if damagingMove?
    return if SELECTABLE_TARGET_TYPES.include?(self.target)
    pbPowerMoveEffects(user)
  end
  
  
  #-----------------------------------------------------------------------------
  # Used to determine if this move should fail on the selected target. Returns 
  # true if this move is a status move and cannot apply any of its effects.
  #-----------------------------------------------------------------------------
  def pbFailsAgainstTarget?(user, target, show_message)
    return false if damagingMove?
    return false if !SELECTABLE_TARGET_TYPES.include?(self.target)
    return pbFailureCheckTarget(user, target)
  end


  #-----------------------------------------------------------------------------
  # Used when this Power Move is a status move that can target.
  #-----------------------------------------------------------------------------
  def pbEffectAgainstTarget(user, target)
    return if damagingMove?
    return if !SELECTABLE_TARGET_TYPES.include?(self.target)
    pbPowerMoveEffects(user, target)
  end
  
  
  #-----------------------------------------------------------------------------
  # Used when this Power Move is a damaging move with no added effect chance.
  # The effect of this move triggers only once, after all hits of the move.
  # Certain failure messages for effects won't bother to play for Max Moves.
  #-----------------------------------------------------------------------------
  def pbEffectAfterAllHits(user, target)
    return if !damagingMove? || @addlEffect > 0
    return if target.damageState.unaffected
    return if @battle.pbAllFainted?(target.idxOwnSide) || @battle.decision > 0
    showMsg = (maxMove?) ? false : true
    pbPowerMoveEffects(user, target, showMsg)
  end
  
  
  #-----------------------------------------------------------------------------
  # Used when this Power Move is a damaging move, but has an added effect chance.
  # This will work with Sheer Force/Serene Grace, so this should only be used for
  # Z-Moves, since Max Moves don't count as having added effects.
  #-----------------------------------------------------------------------------
  def pbAdditionalEffect(user, target)
    return if @addlEffect == 0
    return if @battle.pbAllFainted?(target.idxOwnSide)
    pbPowerMoveEffects(user, target, false)
  end
  
  
  #-----------------------------------------------------------------------------
  # Used to determine move failure specifically for status moves that target.
  #-----------------------------------------------------------------------------
  def pbFailureCheckTarget(user, target, showMsg = true)
    tries = 0
    fails = 0
    #---------------------------------------------------------------------------
    # Stat Changes
    #---------------------------------------------------------------------------
    if !@stat_changes.empty?
      @stat_changes.each do |recipients, stats|
        battlers = []
        case recipients
        when :user;      battlers.push(user)
        when :target;    battlers.push(target)
        when :allies;    battlers.push(user); user.eachAlly { |b| battlers.push(b) }
        when :opponents; user.eachOpposing { |b| battlers.push(b) }  
        end
        battlers.uniq!
        battlers.compact!
        show_each_msg = showMsg && (stats.length / 2) < 3
        battlers.each do |b|
          next if !b || b.fainted?
          b_tries = 0
          b_fails = 0
          for i in 0...stats.length / 2
            stat, stage = stats[i * 2], stats[i * 2 + 1]
            tries += 1
            b_tries += 1
            if stage > 0
              if !b.pbCanRaiseStatStage?(stat, b, self, show_each_msg)
                fails += 1
                b_fails += 1
              end				
            else
              if !b.pbCanLowerStatStage?(stat, b, self, show_each_msg)
                fails += 1
                b_fails += 1
              end
            end
          end
          if b_fails == b_tries && showMsg && (stats.length / 2) > 3
            @battle.pbDisplay(_INTL("{1}'s stats can't be changed any further!", b.pbThis))
          end
        end
      end
    end
    #---------------------------------------------------------------------------
    # Status Conditions
    #---------------------------------------------------------------------------
    if !@statuses.empty?
      @statuses.each do |recipients, statuses|
        battlers = []
        case recipients
        when :user;      battlers.push(user)
        when :target;    battlers.push(target)
        when :allies;    battlers.push(user); user.eachAlly { |b| battlers.push(b) }
        when :opponents; user.eachOpposing { |b| battlers.push(b) }  
        end
        battlers.uniq!
        battlers.compact!
        battlers.each do |b|
          next if !b || b.fainted?
          statuses.shuffle.each do |status|
            tries += 1
            case status
            when :NONE;      fails += 1 if b.status == :NONE
            when :TOXIC;     fails += 1 if !b.pbCanPoison?(user, showMsg)
            when :ATTRACT;   fails += 1 if !b.pbCanAttract?(user, showMsg)
            when :CONFUSION; fails += 1 if !b.pbCanConfuse?(user, showMsg)
            else             fails += 1 if !b.pbCanInflictStatus?(status, b, showMsg, self)
            end
            break
          end
        end
      end
    end
    #---------------------------------------------------------------------------
    # Battler Effects
    #---------------------------------------------------------------------------
    if !@battler_effects.empty?
      @battler_effects.each do |recipients, effects|
        battlers = []
        case recipients
        when :user;      battlers.push(user)
        when :target;    battlers.push(target)
        when :allies;    battlers.push(user); user.eachAlly { |b| battlers.push(b) }
        when :opponents; user.eachOpposing { |b| battlers.push(b) }  
        end
        battlers.uniq!
        battlers.compact!
        battlers.each do |b|
          next if !b || b.fainted?
          effects.each do |eff|
            effect, setting = eff[0], eff[1]
            tries += 1
            if $DELUXE_BATTLE_EFFECTS[:battler_default_false].include?(effect)
              if b.effects[effect] == setting
                fails += 1 
                @battle.pbDisplay(_INTL("It doesn't affect {1}...", b.pbThis(true))) if showMsg
              end
            elsif $DELUXE_BATTLE_EFFECTS[:battler_default_zero].include?(effect)
              if (b.effects[effect] > 0 && setting > 0) || (b.effects[effect] == 0 && setting == 0)
                fails += 1 
                @battle.pbDisplay(_INTL("It doesn't affect {1}...", b.pbThis(true))) if showMsg
              end
            end
          end
        end
      end
    end
    return fails >= tries
  end
  
  
  #-----------------------------------------------------------------------------
  # Used to determine move failure on status moves that don't target.
  #-----------------------------------------------------------------------------
  def pbFailureCheckGeneral(user)
    tries = 0
    fails = 0
    #---------------------------------------------------------------------------
    # Team Effects
    #---------------------------------------------------------------------------
    if !@team_effects.empty?
      @team_effects.each do |sides, effects|
        case sides
        when :allies;    side = user.pbOwnSide
        when :opponents; side = user.pbOpposingSide
        end
        effects.each do |eff|
          effect, setting = eff[0], eff[1]
          tries += 1
          case effect
          when PBEffects::Spikes, PBEffects::ToxicSpikes
            max = (effect == PBEffects::Spikes) ? 3 : 2
            fails += 1 if side.effects[effect] == max && setting > 0
            fails += 1 if side.effects[effect] == 0 && setting == 0
          when PBEffects::Reflect, PBEffects::LightScreen, PBEffects::AuroraVeil
            fails += 1 if side.effects[effect] > 0 && setting > 0
            fails += 1 if side.effects[effect] == 0 && setting == 0
          else
            if $DELUXE_BATTLE_EFFECTS[:team_default_false].include?(effect)
              fails += 1 if side.effects[effect] == setting
            elsif $DELUXE_BATTLE_EFFECTS[:team_default_zero].include?(effect)
              fails += 1 if side.effects[effect] > 0 && setting > 0
              fails += 1 if side.effects[effect] == 0 && setting == 0
            end
          end
        end
      end
    end
    #---------------------------------------------------------------------------
    # Field Effects
    #---------------------------------------------------------------------------
    if @weather
      tries += 1
      fails += 1 if [:HarshSun, :HeavyRain, :StrongWinds, @weather].include?(@battle.field.weather)
    end
    if @terrain
      tries += 1
      fails += 1 if @battle.field.terrain == @terrain
    end
    if !@field.empty?
      @field.each do |effects|
        effect, setting = effects[0], effects[1]
        tries += 1
        if $DELUXE_BATTLE_EFFECTS[:field_default_false].include?(effect)
          fails += 1 if field.effects[effect] == setting
        elsif $DELUXE_BATTLE_EFFECTS[:field_default_zero].include?(effect)
          fails += 1 if field.effects[effect] > 0 && setting > 0
          fails += 1 if field.effects[effect] == 0 && setting == 0
        end
      end
    end	
    return fails >= tries
  end
  
  
  #-----------------------------------------------------------------------------
  # Main method used to process all move effects.
  #-----------------------------------------------------------------------------
  def pbPowerMoveEffects(user, target = nil, showMsg = true)
    #---------------------------------------------------------------------------
    # Stat Changes
    #---------------------------------------------------------------------------
    if !@stat_changes.empty?
      @stat_changes.each do |recipients, stats|
        battlers = []
        case recipients
        when :user;      battlers.push(user)
        when :target;    battlers.push(target)
        when :allies;    battlers.push(user); user.eachAlly { |b| battlers.push(b) }
        when :opponents; user.eachOpposing { |b| battlers.push(b) }  
        end
        battlers.uniq!
        battlers.compact!
        battlers.each do |b|
          next if !b || b.fainted?
          showAnim = true
          last_change = 0
          for i in 0...stats.length / 2
            stat, stage = stats[i * 2], stats[i * 2 + 1]
            next if stage == 0
            if stage > 0
              next if !b.pbCanRaiseStatStage?(stat, b, self, showMsg)
              showAnim = true if !showAnim && last_change == -1
              if b.pbRaiseStatStage(stat, stage, b, showAnim)
                showAnim = false
                last_change = 1
              end
            else
              next if !b.pbCanLowerStatStage?(stat, b, self, showMsg)
              showAnim = true if !showAnim && last_change == 1
              if b.pbLowerStatStage(stat, stage.abs, b, showAnim)
                showAnim = false
                last_change = -1
              end
            end
          end
        end
      end
    end
    #---------------------------------------------------------------------------
    # Status Conditions
    #---------------------------------------------------------------------------
    if !@statuses.empty?
      @statuses.each do |recipients, statuses|
        battlers = []
        case recipients
        when :user;      battlers.push(user)
        when :target;    battlers.push(target)
        when :allies;    battlers.push(user); user.eachAlly { |b| battlers.push(b) }
        when :opponents; user.eachOpposing { |b| battlers.push(b) }  
        end
        battlers.uniq!
        battlers.compact!
        battlers.each do |b|
          next if !b || b.fainted?
          statuses.shuffle.each do |status|
            case status
            when :NONE;      b.pbCureStatus                  if b.status != :NONE
            when :TOXIC;     b.pbPoison(user, showMsg, true) if b.pbCanPoison?(user, showMsg)
            when :ATTRACT;   b.pbAttract(user)               if b.pbCanAttract?(user, showMsg)
            when :CONFUSION; b.pbConfuse                     if b.pbCanConfuse?(user, showMsg)
            else
              next if b.pbHasAnyStatus? || !b.pbCanInflictStatus?(status, b, showMsg)
              b.pbInflictStatus(status, 0, showMsg, user)
              b.statusCount = b.pbSleepDuration if status == :SLEEP
            end
            break
          end
          b.pbAbilityStatusCureCheck
          b.pbItemStatusCureCheck
        end
      end
    end
    #---------------------------------------------------------------------------
    # Battler Effects
    #---------------------------------------------------------------------------
    if !@battler_effects.empty?
      @battler_effects.each do |recipients, effects|
        battlers = []
        case recipients
        when :user;      battlers.push(user)
        when :target;    battlers.push(target)
        when :allies;    battlers.push(user); user.eachAlly { |b| battlers.push(b) }
        when :opponents; user.eachOpposing { |b| battlers.push(b) }  
        end
        battlers.uniq!
        battlers.compact!
        battlers.each do |b|
          next if !b || b.fainted?
          effects.each do |eff|
            effect, setting, msg, chance = eff[0], eff[1], eff[2], eff[3]
            chance = 100 if !chance
            lowercase = (msg && msg.first == "{") ? false : true
            if chance >= @battle.pbRandom(100)
              b.apply_battler_effects(effect, setting, msg, lowercase)
            end
          end
        end
      end
    end
    #---------------------------------------------------------------------------
    # Team Effects
    #---------------------------------------------------------------------------
    if !@team_effects.empty?
      skip_message = []
      @team_effects.each do |sides, effects|
        effects.each do |eff|
          effect, setting, msg, user_msg = eff[0], eff[1], eff[2], eff[3]
          lowercase = (msg && msg.first == "{") ? false : true
          case sides
          when :allies    then idxSide = 0
          when :opponents then idxSide = 1
          end
          ret = user.apply_team_effects(effect, setting, idxSide, skip_message, msg, lowercase, user_msg)
          skip_message.push(ret) if ret
        end
      end
    end
    #---------------------------------------------------------------------------
    # Field Effects
    #---------------------------------------------------------------------------
    if @weather
      if @weather == :Random
        weather = []
        GameData::BattleWeather::DATA.keys.each do |key|
          next if [:None, :HarshSun, :HeavyRain, :StrongWinds, @battle.field.weather].include?(key)
          weather.push(key)
        end
        @weather = weather.sample
      end
      if ![:HarshSun, :HeavyRain, :StrongWinds, @weather].include?(@battle.field.weather)
        if @weather == :None
          case @battle.field.weather
          when :Sun       then @battle.pbDisplay(_INTL("The sunlight faded."))
          when :Rain      then @battle.pbDisplay(_INTL("The rain stopped."))
          when :Sandstorm then @battle.pbDisplay(_INTL("The sandstorm subsided."))
          when :Hail      then @battle.pbDisplay(_INTL("The hail stopped."))
          when :ShadowSky then @battle.pbDisplay(_INTL("The shadow sky faded."))
          else                 @battle.pbDisplay(_INTL("The weather cleared."))
          end
        end
        @battle.pbStartWeather(user, @weather, true)
      end
    end
    if @terrain
      if @terrain == :Random
        terrain = []
        GameData::BattleTerrain::DATA.keys.each do |key|
          next if [:None, @battle.field.terrain].include?(key)
          terrain.push(key)
        end
        @terrain = terrain.sample
      end
      if @battle.field.terrain != @terrain
        if @terrain == :None
          case @battle.field.terrain
          when :Electric  then @battle.pbDisplay(_INTL("The electricity disappeared from the battlefield."))
          when :Grassy    then @battle.pbDisplay(_INTL("The grass disappeared from the battlefield."))
          when :Misty     then @battle.pbDisplay(_INTL("The mist disappeared from the battlefield."))
          when :Psychic   then @battle.pbDisplay(_INTL("The weirdness disappeared from the battlefield."))
          else                 @battle.pbDisplay(_INTL("The battlefield normalized."))
          end
        end
        @battle.pbStartTerrain(user, @terrain)
      end
    end
    if !@field.empty?
      @field.each do |effects|
        effect, setting, msg = effects[0], effects[1], effects[2]
        lowercase = (msg && msg.first == "{") ? false : true
        user.apply_field_effects(effect, setting, msg, lowercase)
      end
    end
  end
end


#===============================================================================
# For moves with no effects.
#===============================================================================
class Battle::PowerMove::None < Battle::PowerMove
end

class Battle::PowerMove::Unimplemented < Battle::PowerMove
  def pbMoveFailed?(user, targets)
    if statusMove?
      @battle.pbDisplay(_INTL("But it failed!"))
      return true
    end
    return false
  end
end