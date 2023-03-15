#===============================================================================
# PBEffects each round
#===============================================================================
class Battle
  attr_reader   :activedAbility # Check if a Pokémon already actived its ability in a battle (Used for Dauntless Shield, etc)
  attr_reader   :rage_hit # Hit counter for rage hit

  alias paldean_initialize initialize
  def initialize(scene, p1, p2, player, opponent)
    paldean_initialize(scene, p1, p2, player, opponent)
    @activedAbility  = [Array.new(@party1.length, false), Array.new(@party2.length, false)]
    @rage_hit        = [Array.new(@party1.length, 0), Array.new(@party2.length, 0)]
    @fainted_count   = [0,0]
  end

  def isBattlerActivedAbility?(user) ; return @activedAbility[user.index & 1][user.pokemonIndex] ; end
  def setBattlerActivedAbility(user,value=true) ; @activedAbility[user.index & 1][user.pokemonIndex] = value ; end
  def getBattlerHit(user) ; return @rage_hit[user.index & 1][user.pokemonIndex] ; end
  def addBattlerHit(user,qty=1) ; @rage_hit[user.index & 1][user.pokemonIndex] += qty ; end
  # added for Supreme Overlord and Last Respect
  def addFaintedCount(user) ; @fainted_count[user.index & 1] += 1 if @fainted_count[user.index & 1] < 100 ; end
  def getFaintedCount(user) ; return @fainted_count[user.index & 1] ; end

  alias paldea_pbEndOfRoundPhase pbEndOfRoundPhase
  def pbEndOfRoundPhase
    paldea_pbEndOfRoundPhase
    allBattlers.each do |battler|
      battler.effects[PBEffects::CudChew]             -= 1 if battler.effects[PBEffects::CudChew] > 0
      battler.effects[PBEffects::Comeuppance]          = -1
      battler.effects[PBEffects::ComeuppanceTarget]    = -1
      battler.effects[PBEffects::GlaiveRush]          -= 1 if battler.effects[PBEffects::GlaiveRush] > 0
    end
    2.times do |side|
      @sides[side].effects[PBEffects::AllySwitch] = false
    end
  end
  
  # add false for ability comando
  def pbCanShowCommands?(idxBattler)
    battler = @battlers[idxBattler]
    return false if !battler || battler.fainted?
    return false if battler.usingMultiTurnAttack?
    return false if battler.effects[PBEffects::CommanderTatsugiri]
    return true
  end

  def pbChooseFaintedPokemonParty(idxBattler)
    party    = pbParty(idxBattler)
    pkmn = nil
    oppname = ""
    battler = @battlers[idxBattler]
    if battler.idxOwnSide == 0 # player
      partyPos = pbPartyOrder(idxBattler)
      partyStart, _partyEnd = pbTeamIndexRangeFromBattlerIndex(idxBattler)
      modParty = pbPlayerDisplayParty(idxBattler)
      # Start party screen
      pkmnScene = PokemonParty_Scene.new
      pkmnScreen = PokemonPartyScreen.new(pkmnScene, modParty)
      pkmnScreen.pbStartScene(_INTL("Use on which Pokémon?"), pbNumPositions(0, 0))
      idxParty = -1
      # Loop while in party screen
      loop do
        # Select a Pokémon
        pkmnScene.pbSetHelpText(_INTL("Use on which Pokémon?"))
        idxParty = pkmnScene.pbChooseFaintedPokemon
        idxPartyRet = -1
        partyPos.each_with_index do |pos, i|
          next if pos != idxParty + partyStart
          idxPartyRet = i
          break
        end
        next if idxPartyRet < 0
        pkmn = party[idxPartyRet]
        if !pkmn || pkmn.egg? || !pkmn.fainted?
          pkmnScene.pbDisplay(_INTL("It won't have any effect."))
          next
        end
        break
      end
      pkmnScene.pbEndScene
    else
      pkmn = party[@battleAI.pbDefaultChooseReviveEnemy(idxBattler, party)]
      oppname = "The opposing "
    end
    pkmn.hp = (pkmn.totalhp / 2).floor
    pkmn.hp = 1 if pkmn.hp <= 0
    pkmn.heal_status
    pbDisplay(_INTL("{1}{2} was revived and is ready to fight again!",oppname,pkmn.name))
  end

  # Called when the Pokémon is Encored, or if it can't use any of its moves.
  # Makes the Pokémon use the Encored move (if Encored), or Struggle.
  def pbAutoChooseMove(idxBattler, showMessages = true)
    battler = @battlers[idxBattler]
    if battler.fainted?
      pbClearChoice(idxBattler)
      return true
    end
    # Encore
    idxEncoredMove = battler.pbEncoredMoveIndex
    if idxEncoredMove >= 0 && pbCanChooseMove?(idxBattler, idxEncoredMove, false)
      encoreMove = battler.moves[idxEncoredMove]
      # If this is the second time using Gigaton Hammer, change it to struggle
      echoln "use encored move"
      if encoreMove.id == :GIGATONHAMMER && battler.lastMoveUsed == encoreMove.id
        idxEncoredMove = -1
        encoreMove = @struggle
      end
      @choices[idxBattler][0] = :UseMove         # "Use move"
      @choices[idxBattler][1] = idxEncoredMove   # Index of move to be used
      @choices[idxBattler][2] = encoreMove       # Battle::Move object
      @choices[idxBattler][3] = -1               # No target chosen yet
      return true if singleBattle?
      if pbOwnedByPlayer?(idxBattler)
        if showMessages
          pbDisplayPaused(_INTL("{1} has to use {2}!", battler.name, encoreMove.name))
        end
        return pbChooseTarget(battler, encoreMove)
      end
      return true
    end
    # Struggle
    if pbOwnedByPlayer?(idxBattler) && showMessages
      pbDisplayPaused(_INTL("{1} has no moves left!", battler.name))
    end
    @choices[idxBattler][0] = :UseMove    # "Use move"
    @choices[idxBattler][1] = -1          # Index of move to be used
    @choices[idxBattler][2] = @struggle   # Struggle Battle::Move object
    @choices[idxBattler][3] = -1          # No target chosen yet
    return true
  end

  # add damage from salt Cure
  alias paldea_pbEORStatusProblemDamage pbEORStatusProblemDamage
  def pbEORStatusProblemDamage(priority)
    paldea_pbEORStatusProblemDamage(priority)
    # Damage from salt cure
    priority.each do |battler|
      next if !battler.effects[PBEffects::SaltCure] || !battler.takesIndirectDamage?
      battler.droppedBelowHalfHP = false
      dmg = battler.totalhp / 8
      dmg = (dmg * 2).round if battler.pbHasType?(:STEEL) || battler.pbHasType?(:WATER)
      pbCommonAnimation("SaltCure", battler)
      battler.pbReduceHP(dmg, false)
      pbDisplay(_INTL("{1} is hurt by Salt Cure!", battler.pbThis))
      battler.pbItemHPHealCheck
      battler.pbAbilitiesOnDamageTaken
      battler.pbFaint if battler.fainted?
      battler.droppedBelowHalfHP = false
    end
  end
end