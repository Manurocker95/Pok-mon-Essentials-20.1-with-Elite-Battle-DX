#===============================================================================
# Battle::Move additions
#===============================================================================
class Battle::Move
  attr_accessor :specialUseZMove, :zmove_flag, :old_move
  
  alias zud_initialize initialize
  def initialize(battle, move)
    zud_initialize(battle, move)
    @specialUseZMove = false
    @old_move        = move.old_move
    @zmove_flag      = (@old_move && statusMove? && !powerMove?)
    if @zmove_flag
      @name        = "Z-" + @name
      @short_name  = (Settings::SHORTEN_MOVES && @name.length > 16) ? @name[0..12] + "..." : @name
    end
  end
 
  def zMove?;     return GameData::Move.get(@id).zMove? || @zmove_flag; end
  def maxMove?;   return GameData::Move.get(@id).maxMove?; end
  def powerMove?; return GameData::Move.get(@id).powerMove?; end
  
  #-----------------------------------------------------------------------------
  # Aliased so damage from attacks consider Dynamax HP, and not base HP.
  #-----------------------------------------------------------------------------
  alias zud_pbInflictHPDamage pbInflictHPDamage
  def pbInflictHPDamage(target)
    target.ignore_dynamax = target.damageState.hpLost > 0 
    zud_pbInflictHPDamage(target)
  end
  
  #-----------------------------------------------------------------------------
  # Edited to prevent Parental Bond from triggering on Power Moves.
  #-----------------------------------------------------------------------------
  def pbNumHits(user, targets)
    if user.hasActiveAbility?(:PARENTALBOND) && pbDamagingMove? &&
       !chargingTurnMove? && !powerMove? && targets.length == 1
      user.effects[PBEffects::ParentalBond] = 3
      return 2
    end
    return 1
  end
  
  #-----------------------------------------------------------------------------
  # Edited to prevent Z-Moves from being affected by type-changing Abilities.
  #-----------------------------------------------------------------------------
  def pbBaseType(user)
    ret = @type
    return ret if user.selectedMoveIsZMove
    if ret && user.abilityActive?
      ret = Battle::AbilityEffects.triggerModifyMoveBaseType(user.ability, user, self, ret)
    end
    return ret
  end

  #-----------------------------------------------------------------------------
  # Displays animation and messages when using a Z-Move in battle.
  # No animation will play if Battle Animations were turned off in the Options.
  # Z-Moves that are used due to calling them with other moves, such as with
  # Sleep Talk, will not trigger the animation or special messages.
  #-----------------------------------------------------------------------------
  alias zud_pbDisplayUseMessage pbDisplayUseMessage
  def pbDisplayUseMessage(user)
    if zMove? && !@specialUseZMove
      $stats.zmove_count += 1 if user.pbOwnedByPlayer?
      triggers = ["zmove", "zmove" + user.species.to_s, "zmove" + @type.to_s]
      @battle.scene.pbDeluxeTriggers(user.index, nil, triggers)
      if Settings::SHOW_ZUD_ANIM && $PokemonSystem.battlescene == 0
        @battle.scene.pbShowZMove(user.index, @id)
      end
      if statusMove? && @zmove_flag
        status_zmove_effect(user)
      else
        @battle.pbDisplayBrief(_INTL("{1} surrounded itself with its Z-Power!", user.pbThis))
      end
      @battle.pbDisplayBrief(_INTL("{1} unleashed its full force Z-Move!", user.pbThis))
    end
    zud_pbDisplayUseMessage(user)
  end
  
  #-----------------------------------------------------------------------------
  # Gets the effects for a Z-Powered status move.
  #-----------------------------------------------------------------------------
  def status_zmove_effect(user)
    $stats.status_zmove_count += 1 if user.pbOwnedByPlayer?
    curse_effect = (@id != :CURSE) ? 0 : (user.pbHasType?(:GHOST)) ? 1 : 2
    #---------------------------------------------------------------------------
    # Status Z-Moves that boost the stats of the user.
    #---------------------------------------------------------------------------
    if GameData::PowerMove.stat_booster?(@id) || curse_effect == 2
      if curse_effect == 2
        stats, stage = [:ATTACK], 1
      else
        stats, stage = GameData::PowerMove.stat_with_stage(@id)
      end 
      statname = (stats.length > 1) ? "stats" : GameData::Stat.get(stats.first).name
      case stage
      when 3; boost = " drastically"
      when 2; boost = " sharply"
      else    boost = ""
      end
      showAnim = true
      stats.each do |stat|
        if user.pbCanRaiseStatStage?(stat, user)
          user.pbRaiseStatStageBasic(stat, stage)
          if showAnim
            @battle.pbCommonAnimation("StatUp", user)
            @battle.pbDisplay(_INTL("{1} boosted its {2}{3} using its Z-Power!", user.pbThis, statname, boost))
          end
          showAnim = false
        end
      end
    #---------------------------------------------------------------------------
    # Status Z-Moves that boosts the user's critical hit ratio.
    #---------------------------------------------------------------------------
    elsif GameData::PowerMove.boosts_crit?(@id)
      user.effects[PBEffects::CriticalBoost] += 2
      @battle.pbDisplay(_INTL("{1} boosted its critical hit ratio using its Z-Power!", user.pbThis))
    #---------------------------------------------------------------------------
    # Status Z-Moves that resets the user's lowered stats.
    #---------------------------------------------------------------------------
    elsif GameData::PowerMove.resets_stats?(@id) && user.hasLoweredStatStages?
      GameData::Stat.each_battle do |s|
        next if user.stages[s.id] >= 0
        user.stages[s.id] = 0
        user.statsRaisedThisRound = true
      end
      @battle.pbDisplay(_INTL("{1} returned its decreased stats to normal using its Z-Power!", user.pbThis))
    #---------------------------------------------------------------------------
    # Status Z-Moves that fully restores HP for the user.
    #---------------------------------------------------------------------------
    elsif GameData::PowerMove.heals_self?(@id) || curse_effect == 1
      if user.hp < user.totalhp
        user.pbRecoverHP(user.totalhp, false)
        @battle.pbDisplay(_INTL("{1} restored its HP using its Z-Power!", user.pbThis))
      end
    #---------------------------------------------------------------------------
    # Status Z-Moves that fully restores HP for an incoming Pokemon.
    #---------------------------------------------------------------------------
    elsif GameData::PowerMove.heals_switch?(@id)
      @battle.positions[user.index].effects[PBEffects::ZHeal] = true
    #---------------------------------------------------------------------------
    # Status Z-Moves that cause misdirection.
    #---------------------------------------------------------------------------
    elsif GameData::PowerMove.focus_user?(@id)
      @battle.pbDisplay(_INTL("{1} became the center of attention using its Z-Power!", user.pbThis))
      user.effects[PBEffects::FollowMe] = 1
      user.eachAlly do |b|
        next if b.effects[PBEffects::FollowMe] < user.effects[PBEffects::FollowMe]
        user.effects[PBEffects::FollowMe] = b.effects[PBEffects::FollowMe] + 1
      end
    end
  end
end