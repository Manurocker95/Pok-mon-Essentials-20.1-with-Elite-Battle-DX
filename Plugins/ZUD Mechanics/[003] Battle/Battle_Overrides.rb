#===============================================================================
# All Battle code that has either been rewritten or aliased.
#===============================================================================
class Battle::ActiveSide
  alias zud_initialize initialize  
  def initialize
    zud_initialize
    @effects[PBEffects::Cannonade]  = 0
    @effects[PBEffects::Steelsurge] = false
    @effects[PBEffects::VineLash]   = 0
    @effects[PBEffects::Volcalith]  = 0
    @effects[PBEffects::Wildfire]   = 0
    @effects[PBEffects::ZHeal]      = false
  end
end

#-------------------------------------------------------------------------------
# Changes to the main Battle class.
#-------------------------------------------------------------------------------
class Battle
  attr_reader :peer     # Ensures correct capture sequence for Raid Pokemon.
  attr_reader :battleAI # Allows for Raid Pokemon to strike multiple times.

  #-----------------------------------------------------------------------------
  # Aliased for ZUD mechanics.
  #-----------------------------------------------------------------------------
  # Adds class variables for keeping track of Z-Move/Ultra Burst/Dynamax usage.
  #-----------------------------------------------------------------------------
  alias zud_initialize initialize
  def initialize(*args)
    zud_initialize(*args)
    @zMove = [
       [-1] * (@player ? @player.length : 1),
       [-1] * (@opponent ? @opponent.length : 1)
    ]
    @ultraBurst = [
       [-1] * (@player ? @player.length : 1),
       [-1] * (@opponent ? @opponent.length : 1)
    ]
    @dynamax = [
       [-1] * (@player ? @player.length : 1),
       [-1] * (@opponent ? @opponent.length : 1)
    ]
    @z_rings = []
    GameData::Item.each { |item| @z_rings.push(item.id) if item.has_flag?("ZRing") }
    @dynamax_bands = []
    GameData::Item.each { |item| @dynamax_bands.push(item.id) if item.has_flag?("DynamaxBand") }
  end
  
  #-----------------------------------------------------------------------------
  # Edited for Encore.
  #-----------------------------------------------------------------------------
  # Returns the user's Encore state after executing a Z-Move.
  # Allows for the selection of other moves during Encore if used as a Power Move.
  #-----------------------------------------------------------------------------
  alias zud_pbCanShowFightMenu? pbCanShowFightMenu?
  def pbCanShowFightMenu?(idxBattler)
    battler = @battlers[idxBattler]
    if !battler.effects[PBEffects::EncoreRestore].empty?
      battler.effects[PBEffects::Encore]        = battler.effects[PBEffects::EncoreRestore][0]
      battler.effects[PBEffects::EncoreMove]    = battler.effects[PBEffects::EncoreRestore][1]
      battler.effects[PBEffects::EncoreRestore].clear
    end
    return zud_pbCanShowFightMenu?(idxBattler)
  end
  
  def pbCanChooseMove?(idxBattler, idxMove, showMessages, sleepTalk = false)
    battler = @battlers[idxBattler]
    move = battler.moves[idxMove]
    return false unless move
    if move.pp == 0 && move.total_pp > 0 && !sleepTalk
      pbDisplayPaused(_INTL("There's no PP left for this move!")) if showMessages
      return false
    end
    if battler.effects[PBEffects::Encore] > 0
      idxEncoredMove = battler.pbEncoredMoveIndex
      if idxEncoredMove >= 0 && idxMove != idxEncoredMove && !move.powerMove?
        pbDisplayPaused(_INTL("Encore prevents using this move!")) if showMessages
        return false 
      end
    end
    return battler.pbCanChooseMove?(move, true, showMessages, sleepTalk)
  end
  
  #-----------------------------------------------------------------------------
  # Aliased for the switch-in effect of Z-Memento/Z-Parting Shot.
  #-----------------------------------------------------------------------------
  alias zud_pbEffectsOnBattlerEnteringPosition pbEffectsOnBattlerEnteringPosition
  def pbEffectsOnBattlerEnteringPosition(battler)
    position = @positions[battler.index]
    if position.effects[PBEffects::ZHeal]
      if battler.canHeal?
        pbCommonAnimation("HealingWish", battler)
        pbDisplay(_INTL("The Z-Power healed {1}!", battler.pbThis(true)))
        battler.pbRecoverHP(battler.totalhp)
        position.effects[PBEffects::ZHeal] = false
      elsif Settings::MECHANICS_GENERATION < 8
        position.effects[PBEffects::ZHeal] = false
      end
    end
    zud_pbEffectsOnBattlerEnteringPosition(battler)
  end
  
  #-----------------------------------------------------------------------------
  # Aliased for the hazard effect of G-Max Steelsurge.
  #-----------------------------------------------------------------------------
  alias zud_pbEntryHazards pbEntryHazards
  def pbEntryHazards(battler)
    battler_side = battler.pbOwnSide
    if battler_side.effects[PBEffects::Steelsurge] && battler.takesIndirectDamage? &&
       GameData::Type.exists?(:STEEL) && !battler.hasActiveItem?(:HEAVYDUTYBOOTS)
      bTypes = battler.pbTypes(true)
      eff = Effectiveness.calculate(:STEEL, bTypes[0], bTypes[1], bTypes[2])
      if !Effectiveness.ineffective?(eff)
        eff = eff.to_f / Effectiveness::NORMAL_EFFECTIVE
        battler.pbReduceHP(battler.totalhp * eff / 8, false)
        pbDisplay(_INTL("The sharp steel bit into {1}!", battler.pbThis(true)))
        battler.pbItemHPHealCheck
      end
    end
    zud_pbEntryHazards(battler)
  end
  
  #-----------------------------------------------------------------------------
  # Aliased for the end of round damage for G-Max Vine Lash/Wildfire/Cannonade/Volcalith.
  #-----------------------------------------------------------------------------
  alias zud_pbEORSeaOfFireDamage pbEORSeaOfFireDamage
  def pbEORSeaOfFireDamage(priority)
    zud_pbEORSeaOfFireDamage(priority)
    2.times do |side|
      # G-Max Vine Lash
      if @sides[side].effects[PBEffects::VineLash] > 0
        if @scene.pbCommonAnimationExists?("VineLash")
          pbCommonAnimation("VineLash") if side == 0
          pbCommonAnimation("VineLashOpp") if side == 1
        end
        priority.each do |battler|
          next if battler.opposes?(side)
          next if !battler.takesIndirectDamage? || battler.pbHasType?(:GRASS)
          @scene.pbDamageAnimation(battler)
          battler.pbTakeEffectDamage(battler.totalhp / 6, false) { |hp_lost|
            pbDisplay(_INTL("{1} is hurt by G-Max Vine Lash's ferocious beating!", battler.pbThis))
          }
        end
      end
      # G-Max Wildfire
      if @sides[side].effects[PBEffects::Wildfire] > 0
        if @scene.pbCommonAnimationExists?("Wildfire")
          pbCommonAnimation("Wildfire") if side == 0
          pbCommonAnimation("WildfireOpp") if side == 1
        end
        priority.each do |battler|
          next if battler.opposes?(side)
          next if !battler.takesIndirectDamage? || battler.pbHasType?(:FIRE)
          @scene.pbDamageAnimation(battler)
          battler.pbTakeEffectDamage(battler.totalhp / 6, false) { |hp_lost|
            pbDisplay(_INTL("{1} is burning up within G-Max Wildfire's flames!", battler.pbThis))
          }
        end
      end
      # G-Max Cannonade
      if @sides[side].effects[PBEffects::Cannonade] > 0
        if @scene.pbCommonAnimationExists?("Cannonade")
          pbCommonAnimation("Cannonade") if side == 0
          pbCommonAnimation("CannonadeOpp") if side == 1
        end
        priority.each do |battler|
          next if battler.opposes?(side)
          next if !battler.takesIndirectDamage? || battler.pbHasType?(:WATER)
          @scene.pbDamageAnimation(battler)
          battler.pbTakeEffectDamage(battler.totalhp / 6, false) { |hp_lost|
            pbDisplay(_INTL("{1} is hurt by G-Max Cannonade's vortex!", battler.pbThis))
          }
        end
      end
      # G-Max Volcalith
      if @sides[side].effects[PBEffects::Volcalith] > 0
        if @scene.pbCommonAnimationExists?("Volcalith")
          pbCommonAnimation("Volcalith") if side == 0
          pbCommonAnimation("VolcalithOpp") if side == 1
        end
        priority.each do |battler|
          next if battler.opposes?(side)
          next if !battler.takesIndirectDamage? || battler.pbHasType?(:ROCK)
          @scene.pbDamageAnimation(battler)
          battler.pbTakeEffectDamage(battler.totalhp / 6, false) { |hp_lost|
            pbDisplay(_INTL("{1} is hurt by the rocks thrown out by G-Max Volcalith!", battler.pbThis))
          }
        end
      end
    end
  end
  
  alias zud_pbEOREndSideEffects pbEOREndSideEffects
  def pbEOREndSideEffects(side, priority)
    zud_pbEOREndSideEffects(side, priority)
    # Vine Lash
    pbEORCountDownSideEffect(side, PBEffects::VineLash,
                             _INTL("{1} was released from G-Max Vine Lash's beating!", @battlers[side].pbTeam))
    # Wildfire
    pbEORCountDownSideEffect(side, PBEffects::Wildfire,
                             _INTL("{1} was released from G-Max Wildfire's flames!", @battlers[side].pbTeam))
    # Cannonade
    pbEORCountDownSideEffect(side, PBEffects::Cannonade,
                             _INTL("{1} was released from G-Max Cannonade's vortex!", @battlers[side].pbTeam))
    # Volcalith
    pbEORCountDownSideEffect(side, PBEffects::Volcalith,
                             _INTL("Rocks stopped being thrown out by G-Max Volcalith on {1}!", @battlers[side].pbTeam(true)))
  end
  
  #-----------------------------------------------------------------------------
  # Aliased for ending Z-Moves and Dynamax. (End of round)
  #-----------------------------------------------------------------------------
  # Resets to base moves if Z-Move was selected.
  # Counts down Dynamax turns and reverts each Pokemon who's Dynamax turns expired.
  #-----------------------------------------------------------------------------
  alias zud_pbEndOfRoundPhase pbEndOfRoundPhase
  def pbEndOfRoundPhase
    if @decision > 0
      allBattlers.each do |battler|
        next if battler.effects[PBEffects::MaxRaidBoss]
        battler.effects[PBEffects::Dynamax] -= 1
        battler.unmax if battler.effects[PBEffects::Dynamax] == 0
      end
      return
    end
    zud_pbEndOfRoundPhase
    allBattlers.each do |battler|
      battler.effects[PBEffects::MaxGuard] = false
      battler.power_index = -1
      if battler.selectedMoveIsZMove
        battler.display_base_moves
        battler.selectedMoveIsZMove = false
      end
      raid_EndOfRound(battler)
      next if battler.effects[PBEffects::Dynamax] <= 0
      # Converts any newly-learned moves into Max Moves while Dynamaxed.
      if !battler.effects[PBEffects::MaxRaidBoss]
        battler.moves.each_with_index do |move, i|
          next if move.maxMove?
          battler.base_moves[i] = move
          move = battler.convert_maxmove(move)
          move.pp = battler.base_moves[i].pp
          move.total_pp = battler.base_moves[i].total_pp
        end
      end
      battler.effects[PBEffects::Dynamax] -= 1
      if battler.effects[PBEffects::Dynamax] == 0
        battler.unmax if !battler.effects[PBEffects::MaxRaidBoss]
      end
      raid_EndOfRound2(battler)
    end
  end

  #-----------------------------------------------------------------------------
  # Aliased for ending Dynamax. (Switching)
  #-----------------------------------------------------------------------------
  # Reverts Dynamax prior to switching out.
  #-----------------------------------------------------------------------------
  alias zud_pbRecallAndReplace pbRecallAndReplace
  def pbRecallAndReplace(*args)
    idxBattler = args[0]
    @battlers[idxBattler].unmax if @battlers[idxBattler].dynamax?
    zud_pbRecallAndReplace(*args)
  end
  
  alias zud_pbSwitchInBetween pbSwitchInBetween
  def pbSwitchInBetween(*args)
    idxBattler = args[0]
    ret = zud_pbSwitchInBetween(*args)
    @battlers[idxBattler].unmax if @battlers[idxBattler].dynamax? && ret > -1
    return ret 
  end
  
  #-----------------------------------------------------------------------------
  # Aliased for ending Dynamax. (End of battle)
  #-----------------------------------------------------------------------------
  # Reverts Dynamax at the end of battle, regardless of remaning turn count.
  #-----------------------------------------------------------------------------
  alias zud_pbEndOfBattle pbEndOfBattle
  def pbEndOfBattle
    @battlers.each do |b|
      next if !b || !b.dynamax? || b.effects[PBEffects::MaxRaidBoss]
      b.unmax
    end
    zud_pbEndOfBattle
  end
end


#-------------------------------------------------------------------------------
# Aliased for ending Dynamax. (Fainting)
#-------------------------------------------------------------------------------
# Reverts Dynamax upon fainting, regardless of the remaining turn count.
#-------------------------------------------------------------------------------
class Battle::Scene
  alias zud_pbFaintBattler pbFaintBattler
  def pbFaintBattler(battler)
    if @battle.battlers[battler.index].dynamax?
      @battle.battlers[battler.index].unmax
    end
    zud_pbFaintBattler(battler)
  end
end


#-------------------------------------------------------------------------------
# Edited for ending Ultra Burst.
#-------------------------------------------------------------------------------
# Ensures Ultra Burst forms revert after battle.
#-------------------------------------------------------------------------------
module BattleCreationHelperMethods
  module_function
  
  def after_battle(outcome, can_lose)
    $player.party.each do |pkmn|
      pkmn.statusCount = 0 if pkmn.status == :POISON
      pkmn.makeUnmega
      pkmn.makeUnUltra
      pkmn.makeUnprimal
    end
    if $PokemonGlobal.partner
      $player.heal_party
      $PokemonGlobal.partner[3].each do |pkmn|
        pkmn.heal
        pkmn.makeUnmega
        pkmn.makeUnUltra
        pkmn.makeUnprimal
      end
    end
    if [2, 5].include?(outcome) && can_lose
      $player.party.each { |pkmn| pkmn.heal }
      (Graphics.frame_rate / 4).times { Graphics.update }
    end
    EventHandlers.trigger(:on_end_battle, outcome, can_lose)
    $game_player.straighten
  end
end