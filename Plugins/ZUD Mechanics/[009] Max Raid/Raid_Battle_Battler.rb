#===============================================================================
# Additions to the Battle::Battler class specifically used for Max Raid battles.
#===============================================================================
class Battle::Battler
  #-----------------------------------------------------------------------------
  # Initializes a Max Raid battler.
  #-----------------------------------------------------------------------------
  def pbInitRaidBoss
    if @battle.raid_battle && opposes?
      rules = $game_temp.dx_rules
      @effects[PBEffects::MaxRaidBoss]   = true
      @effects[PBEffects::Dynamax]       = rules[:turns]
      @effects[PBEffects::RaidShield]    = 0
      @effects[PBEffects::MaxShieldHP]   = rules[:shield]
      @effects[PBEffects::KnockOutCount] = rules[:kocount]
      @effects[PBEffects::ShieldCounter] = (level > 35) ? 2 : 1
      if inMaxLair?
        @effects[PBEffects::ShieldCounter] = 1
        @effects[PBEffects::MaxShieldHP]   = 5
        @effects[PBEffects::KnockOutCount] = pbDynamaxAdventure.knockouts
      end
    end
  end
  
  #-----------------------------------------------------------------------------
  # Handles success checks for moves used in Max Raid battles.
  #-----------------------------------------------------------------------------
  def raid_SuccessCheck(move, user, target)
    ret = true
    if @battle.raid_battle
      #-------------------------------------------------------------------------
      # Max Raid Pokemon are immune to specified moves.
      #-------------------------------------------------------------------------
      if target.effects[PBEffects::MaxRaidBoss]
        functions = [
          "UserConsumeTargetBerry",  # Bug Bite/Pluck
          "DestroyTargetBerryOrGem", # Incinerate
          "RemoveTargetItem",        # Knock Off
          "FixedDamageHalfTargetHP"  # Super Fang
        ]
        if functions.include?(move.function) ||
           (user.pbHasType?(:GHOST) && 
           move.function == "CurseTargetOrLowerUserSpd1RaiseUserAtkDef1") # Curse
          @battle.pbDisplay(_INTL("But it failed!"))
          ret = false
        end
      end
      #-------------------------------------------------------------------------
      # Specified moves fail when used by Max Raid Pokemon.
      #-------------------------------------------------------------------------
      if user.effects[PBEffects::MaxRaidBoss]
        functions = [
          "UserFaintsFixedDamageUserHP",    # Final Gambit
          "UserFaintsLowerTargetAtkSpAtk2", # Memento
          "AttackerFaintsIfUserFaints",     # Destiny Bond
          "SwitchOutTargetStatusMove",      # Roar/Whirlwind
          "UserMakeSubstitute"              # Substitute
        ]
        if functions.include?(move.function) ||
           (user.pbHasType?(:GHOST) && 
           move.function == "CurseTargetOrLowerUserSpd1RaiseUserAtkDef1") # Curse
          @battle.pbDisplay(_INTL("But it failed!"))
          ret = false
        end
      end
      #-------------------------------------------------------------------------
      # Max Raid Shields block status moves.
      #-------------------------------------------------------------------------
      if target.effects[PBEffects::RaidShield] > 0 && move.statusMove?
        @battle.pbDisplay(_INTL("But it failed!"))
        ret = false
      end
    end
    return ret
  end
  
  #-----------------------------------------------------------------------------
  # Allows a Raid Pokemon to use its base moves in the same turn after Max Moves.
  #-----------------------------------------------------------------------------
  def raid_UseBaseMoves(choice)
    return if !@effects[PBEffects::MaxRaidBoss]
    return if @effects[PBEffects::ShieldCounter] > 0
    return if choice[0] != :UseMove
    return if choice[2].statusMove?
    return if @base_moves.empty?
    self.display_base_moves
    strikes = @battle.pbSideSize(0) - 1
    strikes.times do |i|
      break if @battle.pbAllFainted?
      break if @battle.decision > 0
      break if i + 1 >= @battle.pbAbleCount
      @battle.battleAI.pbChooseMoves(self.index)
      choice = @battle.choices[self.index]
      PBDebug.log("[Move usage] #{pbThis} started using #{choice[2].name}")
      PBDebug.logonerr{
        pbUseMove(choice, choice[2] == @battle.struggle)
      }
      @battle.pbJudge
    end
  end
  
  #-----------------------------------------------------------------------------
  # Deals damage to a Raid Pokemon's shields through Max Guard (only in 1v1 raids).
  #-----------------------------------------------------------------------------
  def raid_ShieldBreak(move, target)
    if @battle.pbSideSize(0) == 1 && 
       move.maxMove? && move.damagingMove? &&
       target.effects[PBEffects::MaxRaidBoss] && 
       target.effects[PBEffects::RaidShield] > 0
      @battle.pbDisplay(_INTL("{1}'s mysterious barrier took the hit!", target.pbThis))
      @battle.scene.pbDamageAnimation(target)
      target.effects[PBEffects::RaidShield] -= 1
      @battle.scene.pbRefresh
      if target.effects[PBEffects::RaidShield] <= 0
        target.effects[PBEffects::RaidShield] = 0 
        @battle.scene.pbRaidShield(target)
        @battle.pbDisplay(_INTL("The mysterious barrier disappeared!"))
        oldhp = target.hp
        target.hp -= target.totalhp / 8
        target.hp  = 1 if target.hp <= 1
        @battle.scene.pbHPChanged(target, oldhp)
        if target.hp > 1
          [:DEFENSE, :SPECIAL_DEFENSE].each do |stat|
            if target.pbCanLowerStatStage?(stat, target, nil, true)
              target.pbLowerStatStage(stat, 2, target, true, false, 0, true)
            end
          end
        end
      end
    end
  end
  
  #-----------------------------------------------------------------------------
  # Handles outcomes in Max Raid battles when party Pokemon are KO'd.
  #-----------------------------------------------------------------------------
  def raid_KOCounter(target)
    if target.effects[PBEffects::MaxRaidBoss]
	  return if !target || target.fainted?
      pbDynamaxAdventure.knockouts -= 1 if inMaxLair?
      target.effects[PBEffects::KnockOutCount] -= 1
      $game_temp.dx_rules[:perfect_bonus] = false
      @battle.scene.pbRefresh
      #-------------------------------------------------------------------------
      # Messages upon KO'ing a Pokemon.
      #-------------------------------------------------------------------------
      if target.effects[PBEffects::KnockOutCount] >= 2
        @battle.pbDisplay(_INTL("The storm raging around {1} is growing stronger!", target.pbThis(true)))
        koboost = true
      elsif target.effects[PBEffects::KnockOutCount] == 1
        @battle.pbDisplay(_INTL("The storm around {1} is growing too strong to withstand!", target.pbThis(true)))
        koboost = true
      else
        @battle.pbDisplay(_INTL("The storm around {1} grew out of control!", target.pbThis(true)))
        more_to_faint = false
        @battle.battlers.each do |b|
          next if !b || !b.opposes?(target) || b.hp > 0 || b.fainted
          more_to_faint = true
        end
        if !more_to_faint
          @battle.pbDisplay(_INTL("You were blown out of the den!"))
          pbSEPlay("Battle flee")
          @battle.decision = 3
          return
        end
      end
      #-------------------------------------------------------------------------
      # Hard Mode Bonuses (KO Boost).
      #-------------------------------------------------------------------------
      if koboost && @battle.hard_mode
        showAnim = true
        [:ATTACK, :SPECIAL_ATTACK].each do |stat|
          if target.pbCanRaiseStatStage?(stat, target)
            target.pbRaiseStatStage(stat, 1, target, showAnim)
            showAnim = false
          end
        end
      end
    end
  end
end