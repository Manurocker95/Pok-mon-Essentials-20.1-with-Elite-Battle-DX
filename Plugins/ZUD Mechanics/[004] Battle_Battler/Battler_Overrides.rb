#===============================================================================
# All Battle::Battler code that has either been rewritten or aliased.
#===============================================================================
class Battle::Battler
  #-----------------------------------------------------------------------------
  # Aliased for initializing new effects and other properties.
  #-----------------------------------------------------------------------------
  alias zud_pbInitEffects pbInitEffects  
  def pbInitEffects(batonPass)
    @power_index                       = -1                       
    @ignore_dynamax                    = false 
    @selectedMoveIsZMove               = false
    @lastMoveUsedIsZMove               = false
    @effects[PBEffects::Dynamax]       = 0
    @effects[PBEffects::NonGMaxForm]   = nil
    if self.dynamax? && @effects[PBEffects::Dynamax] == 0
      @effects[PBEffects::Dynamax] = Settings::DYNAMAX_TURNS
    end
    @effects[PBEffects::MaxGuard]      = false
    @effects[PBEffects::MaxRaidBoss]   = false
    @effects[PBEffects::RaidShield]    = -1
    @effects[PBEffects::MaxShieldHP]   = -1
    @effects[PBEffects::ShieldCounter] = -1
    @effects[PBEffects::KnockOutCount] = -1
    #-----------------------------------------------------------------------------
    # Round about way of preventing trapping effects of certain G-Max moves from
    # ending prematurely if the user of the move leaves the field.
    #-----------------------------------------------------------------------------
    @effects[PBEffects::GMaxTrapping] = false if !batonPass
    trap_hash = {}
    @battle.allBattlers.each do |b|
      next if !b.effects[PBEffects::GMaxTrapping]
      trap_hash[b.index] = [b.effects[PBEffects::Trapping],
	                        b.effects[PBEffects::TrappingUser]]
    end
    zud_pbInitEffects(batonPass)
    if !trap_hash.empty?
      trap_hash.keys.each do |i|
        next if !@battle.battlers[i] || @battle.battlers[i].fainted?
        @battle.battlers[i].effects[PBEffects::Trapping] = trap_hash[i][0]
        @battle.battlers[i].effects[PBEffects::TrappingUser] = trap_hash[i][1]
      end
    end
    pbInitRaidBoss
  end
  
  #-----------------------------------------------------------------------------
  # Aliased to consider HP changes with Dynamax HP.
  #-----------------------------------------------------------------------------
  alias zud_pbReduceHP pbReduceHP
  def pbReduceHP(*args)
    # All effects that lower HP ignore any increased scaling for Dynamax Pokemon HP,
    # except for specific situations where it is otherwise flagged, such as with
    # direct attacks, or set damage as with the move Pain Split.
    args[0] = (args[0] / self.dynamax_boost) if self.dynamax? && !@ignore_dynamax
    ret = zud_pbReduceHP(*args)
    @ignore_dynamax = false
    return ret
  end
  
  alias zud_pbRecoverHP pbRecoverHP
  def pbRecoverHP(*args)
    # All effects that heal HP always scale down their healing for Dynamax Pokemon,
    # except for specific situations where it is otherwise flagged, such as items
    # that heal a set amount of HP, such as Oran Berry or Berry Juice.
    args[0] = (args[0] / self.dynamax_boost) if self.dynamax? && !@ignore_dynamax
    ret = zud_pbRecoverHP(*args)
    @ignore_dynamax = false
    return ret
  end
  
  alias zud_pbRecoverHPFromDrain pbRecoverHPFromDrain
  def pbRecoverHPFromDrain(*args)
    @ignore_dynamax = true
    zud_pbRecoverHPFromDrain(*args)
  end
  
  #-----------------------------------------------------------------------------
  # Aliased for Z-Move usage.
  #-----------------------------------------------------------------------------
  # Registers if selected move is a Z-Move, and triggers the use of that Z-Move.
  # Unregisters the Z-Move at the end of the turn, or if the move failed to execute.
  #-----------------------------------------------------------------------------
  alias zud_pbTryUseMove pbTryUseMove 
  def pbTryUseMove(*args)
    ret = zud_pbTryUseMove(*args)
    @lastMoveUsedIsZMove = ret if args[1].zMove?
    return ret 
  end
  
  alias zud_pbUseMove pbUseMove
  def pbUseMove(choice, specialUsage = false)
    @lastMoveUsedIsZMove = false
    if choice[2].powerMove?
      @power_index = choice[1] if @power_index == -1
      choice[2] = calc_power_move(choice[2])
      if @selectedMoveIsZMove 
        choice[2].specialUseZMove = specialUsage
      end
    end
    zud_pbUseMove(choice, specialUsage)
  end
  
  alias zud_pbEndTurn pbEndTurn
  def pbEndTurn(_choice)
    if _choice[0] == :UseMove && _choice[2].zMove?
      if @lastMoveUsedIsZMove
        @battle.pbSetBattleMechanicUsage(@index, "Z-Move")
      else 
        @battle.pbUnregisterZMove(@index)
      end
      @power_trigger = false
    end
    zud_pbEndTurn(_choice)
  end
  
  #-----------------------------------------------------------------------------
  # Edited for allowing Z-Moves when called by other moves.
  #-----------------------------------------------------------------------------
  # Allows Z-Powered version of moves selected via other moves, such as Sleep Talk.
  #-----------------------------------------------------------------------------  
  def pbUseMoveSimple(moveID, target = -1, idxMove = -1, specialUsage = true)
    choice = []
    choice[0] = :UseMove
    choice[1] = idxMove
    if idxMove >= 0
      choice[2] = @moves[idxMove]
    else
      choice[2] = Battle::Move.from_pokemon_move(@battle, Pokemon::Move.new(moveID))
      choice[2].pp = -1
    end
    choice[3] = target
    PBDebug.log("[Move usage] #{pbThis} started using the called/simple move #{choice[2].name}")
    side  = (@battle.opposes?(self.index)) ? 1 : 0
    owner = @battle.pbGetOwnerIndexFromBattlerIndex(self.index)
    if @battle.zMove[side][owner] == self.index
      z_move = convert_zmove(choice[2], nil, @effects[PBEffects::TransformSpecies])
      z_move.specialUseZMove = true
      choice[2] = z_move
      pbUseMove(choice, specialUsage)
    else
      pbUseMove(choice, specialUsage)
    end
  end
  
  #-----------------------------------------------------------------------------
  # Aliased for fainting.
  #-----------------------------------------------------------------------------
  # KO'd Pokemon properly un-Dynamax and un-Ultra Burst.
  #-----------------------------------------------------------------------------
  alias zud_pbFaint pbFaint
  def pbFaint(*args)
    return if @fainted || !fainted?
    self.unmax if dynamax?
    zud_pbFaint(*args)
    @pokemon.makeUnUltra if ultra?
    raid_KOCounter(self.pbDirectOpposing) if @battle.raid_battle
  end
  
  #-----------------------------------------------------------------------------
  # Aliased for Transform.
  #-----------------------------------------------------------------------------
  # Copies relevant Dynamax-related attributes.
  #-----------------------------------------------------------------------------
  alias zud_pbTransform pbTransform
  def pbTransform(target)
    zud_pbTransform(target)
    if target.dynamax? && !target.base_moves.empty?
      @moves.clear
      target.moves.each_with_index do |m, i|
        basemove  = target.base_moves[i].id
        @moves[i] = Battle::Move.from_pokemon_move(@battle, Pokemon::Move.new(basemove))
        @moves[i].pp       = 5
        @moves[i].total_pp = 5
      end
    end
    display_base_moves if dynamax?
    @battle.scene.pbRefreshOne(@index)
  end
  
  #-----------------------------------------------------------------------------
  # Aliased for Encore.
  #-----------------------------------------------------------------------------
  # Index of encored move is reset during the turn a Z-Move is used.
  #-----------------------------------------------------------------------------
  alias zud_pbEncoredMoveIndex pbEncoredMoveIndex
  def pbEncoredMoveIndex
    if @battle.choices[self.index][0] == :UseMove && @battle.choices[self.index][2].zMove?
      turns = @effects[PBEffects::Encore]
      move  = @effects[PBEffects::EncoreMove]
      @effects[PBEffects::EncoreRestore] = [turns, move]
      return -1
    end
    zud_pbEncoredMoveIndex
  end
  
  #-----------------------------------------------------------------------------
  # Aliased for Flinch.
  #-----------------------------------------------------------------------------
  # Dynamax Pokemon are immune to flinching effects.
  #-----------------------------------------------------------------------------
  alias zud_pbFlinch pbFlinch
  def pbFlinch(*args)
    return if @effects[PBEffects::Dynamax] > 0
    zud_pbFlinch(*args)
  end
  
  #-----------------------------------------------------------------------------
  # Edited for Imprison.
  #-----------------------------------------------------------------------------
  # Checks the user's base moves instead of its current moves while Dynamaxed.
  #-----------------------------------------------------------------------------
  def pbHasMove?(move_id)
    return false if !move_id
    if dynamax?
      @base_moves.each { |m| return true if m.id == move_id }
    else
      eachMove { |m| return true if m.id == move_id }
    end
    return false
  end
  
  #-----------------------------------------------------------------------------
  # Aliased for Grudge, Destiny Bond.
  #-----------------------------------------------------------------------------
  # Grudge: Lowers PP of base move if Max Move was used. Fails on Z-Moves.
  # Destiny Bond: Effect fails to apply on a Dynamax Pokemon.
  #-----------------------------------------------------------------------------
  alias zud_pbEffectsOnMakingHit pbEffectsOnMakingHit
  def pbEffectsOnMakingHit(move, user, target)
    if target.opposes?(user)
      if target.effects[PBEffects::Grudge] && target.fainted?
        target.effects[PBEffects::Grudge] = false if move.zMove?
        if move.maxMove? && user.dynamax?
          base_move = user.base_moves[@power_index]
          user.pbSetPP(move, 0)
          user.pbSetPP(base_move, 0)
          @battle.pbDisplay(_INTL("{1}'s {2} lost all of its PP due to the grudge!",
                                user.pbThis, base_move.name))
          target.effects[PBEffects::Grudge] = false
        end
      end
      if target.effects[PBEffects::DestinyBond] && user.dynamax?
        target.effects[PBEffects::DestinyBond] = false
      end
    end
    zud_pbEffectsOnMakingHit(move, user, target)
  end
  
  #-----------------------------------------------------------------------------
  # Aliased for move selection.
  #-----------------------------------------------------------------------------
  # Power Moves ignore effects that would prevent move selection.
  # However, Taunt still prevents the selection of Max Guard, and Gravity still
  # prevents the selection of moves affected by Gravity.
  #-----------------------------------------------------------------------------
  alias zud_pbCanChooseMove? pbCanChooseMove?
  def pbCanChooseMove?(move, commandPhase, showMessages = true, specialUsage = false)
    if move.powerMove?
      if @battle.field.effects[PBEffects::Gravity] > 0 && move.unusableInGravity?
        if showMessages
          msg = _INTL("{1} can't use {2} because of gravity!", pbThis, move.name)
          (commandPhase) ? @battle.pbDisplayPaused(msg) : @battle.pbDisplay(msg)
        end
        return false
      end
      if @effects[PBEffects::Taunt] > 0 && move.statusMove? && move.maxMove?
        if showMessages
          msg = _INTL("{1} can't use {2} after the taunt!", pbThis, move.name)
          (commandPhase) ? @battle.pbDisplayPaused(msg) : @battle.pbDisplay(msg)
        end
        return false
      end
      return false if !move.pbCanChooseMove?(self, commandPhase, showMessages)
      return true
    else
      return zud_pbCanChooseMove?(move, commandPhase, showMessages, specialUsage)
    end
  end
  
  #-----------------------------------------------------------------------------
  # Aliased for Dynamax immunities.
  #-----------------------------------------------------------------------------
  # Prevents Dynamax targets from being affected by various moves.
  # Also checks for moves that may bypass Max Guard.
  #-----------------------------------------------------------------------------
  alias zud_pbSuccessCheckAgainstTarget pbSuccessCheckAgainstTarget
  def pbSuccessCheckAgainstTarget(move, user, target, targets)
    if target.effects[PBEffects::Dynamax] > 0
      functions = [
        "OHKO",                                    # Horn Drill, Guillotine, etc.
        "OHKOIce",                                 # Sheer Cold
        "OHKOHitsUndergroundTarget",               # Fissure
        "SetTargetAbilityToUserAbility",           # Entrainment
        "UserTargetSwapAbilities",                 # Skill Swap
        "PowerHigherWithTargetWeight",             # Low Kick, Grass Knot, etc.
        "PowerHigherWithUserHeavierThanTarget",    # Heat Crash, Heavy Slam, etc.
        "DisableTargetUsingSameMoveConsecutively", # Torment
        "DisableTargetLastMoveUsed",               # Disable
        "DisableTargetUsingDifferentMove",         # Encore
        "AttackerFaintsIfUserFaints",              # Destiny Bond
        "SwitchOutTargetStatusMove",               # Roar, Whirlwind, etc.
        "TargetUsesItsLastUsedMoveAgain"           # Instruct
      ]
      if functions.include?(move.function)
        @battle.pbDisplay(_INTL("But it failed!"))
        return false
      end
    end
    return false if !raid_SuccessCheck(move, user, target)
    if target.effects[PBEffects::MaxGuard] && !user.effects[PBEffects::TwoTurnAttack]
      bypass = [:MEANLOOK, :ROLEPLAY, :PERISHSONG, :DECORATE, :FEINT]
      if !bypass.include?(move.id) && move.function != "ZUDBypassProtect"
        @battle.pbCommonAnimation("Protect", target)
        @battle.pbDisplay(_INTL("{1} protected itself!", target.pbThis))
        target.damageState.protected = true
        @battle.successStates[user.index].protected = true
        raid_ShieldBreak(move,target)
        return false
      end
    end
    return zud_pbSuccessCheckAgainstTarget(move, user, target, targets)
  end
end