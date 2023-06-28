#===============================================================================
# Makes additions to various battle code to allow mid-battle settings to trigger.
#===============================================================================


class Battle::Scene
  #-----------------------------------------------------------------------------
  # Initializes various midbattle properties.
  #-----------------------------------------------------------------------------
  alias dx_initialize initialize
  def initialize
    dx_initialize
    @midbattle_var = 0
    @midbattle_choice = nil
    @midbattle_decision = 0
    @midbattle_delay = []
    @midbattle_ignore = []
    @guestSpeaker = false
    @namePanelName = nil
    @namePanelSkin = nil
  end

  #-----------------------------------------------------------------------------
  # Compiles a list of all viable triggers of each type to check for.
  #-----------------------------------------------------------------------------
  def pbDeluxeTriggers(idxBattler, idxTarget, triggers)
    return if !$game_temp.dx_midbattle?
    array = []
    idxBattler = idxBattler.index if idxBattler.respond_to?("index")
    if !idxBattler.nil?
      battler = @battle.battlers[idxBattler]
      triggers.each { |t| array.push((battler.pbOwnedByPlayer?) ? t : (battler.opposes?) ? t + "_foe" : t + "_ally") }
    else
      array = triggers.clone
    end
    oldvar = @midbattle_var
    dx_midbattle(idxBattler, idxTarget, *array) if !array.empty?
    if !@midbattle_choice.nil? && @midbattle_decision > 0
      loop do
        tag = (@midbattle_choice.is_a?(Array)) ? @midbattle_choice[0].to_s : @midbattle_choice.to_s
        triggers = ["choice_" + tag + "_" + @midbattle_decision.to_s]
        if @midbattle_choice.is_a?(Array)
          decision = (@midbattle_decision == @midbattle_choice[1]) ? "correct" : "incorrect"
          triggers.push("choice_" + tag + "_" + decision)
        end
        oldchoice = @midbattle_choice
        dx_midbattle(idxBattler, idxTarget, *triggers)
        break if @midbattle_choice == oldchoice
      end
      @midbattle_choice = nil
      @midbattle_decision = 0
    end
    if @midbattle_var != oldvar
      triggers = ["variable_" + @midbattle_var.to_s, "variable_under_" + (@midbattle_var + 1).to_s]
      @midbattle_var.times { |i| triggers.push("variable_over_" + i.to_s) }
      tag = (@midbattle_var > oldvar) ? "up" : "down"
      triggers.push("variable_" + tag)
      dx_midbattle(idxBattler, idxTarget, *triggers)
    end
  end
end


class Battle
  #-----------------------------------------------------------------------------
  # Mid-battle triggers for when items are used.
  #-----------------------------------------------------------------------------
  alias dx_pbUseItemOnPokemon pbUseItemOnPokemon
  def pbUseItemOnPokemon(item, idxParty, userBattler)
    triggers = ["item", "item" + item.to_s]
    @scene.pbDeluxeTriggers(userBattler, nil, triggers)
    dx_pbUseItemOnPokemon(item, idxParty, userBattler)
  end

  alias dx_pbUseItemOnBattler pbUseItemOnBattler
  def pbUseItemOnBattler(item, idxParty, userBattler)
    triggers = ["item", "item" + item.to_s]
    @scene.pbDeluxeTriggers(userBattler, nil, triggers)
    dx_pbUseItemOnBattler(item, idxParty, userBattler)
  end
  
  alias dx_pbUseItemInBattle pbUseItemInBattle
  def pbUseItemInBattle(item, idxBattler, userBattler)
    triggers = ["item", "item" + item.to_s]
    @scene.pbDeluxeTriggers(userBattler, idxBattler, triggers)
    dx_pbUseItemInBattle(item, idxBattler, userBattler)
  end
  
  #-----------------------------------------------------------------------------
  # Mid-battle triggers for when Pokemon are recalled and sent out.
  #-----------------------------------------------------------------------------
  alias dx_pbMessageOnRecall pbMessageOnRecall
  def pbMessageOnRecall(battler, withTriggers = true)
    if !battler.fainted? && withTriggers
      triggers = ["switchOut", "switchOut" + battler.species.to_s]
      battler.pokemon.types.each { |t| triggers.push("switchOut" + t.to_s) }
      @scene.pbDeluxeTriggers(battler, nil, triggers)
    end
    dx_pbMessageOnRecall(battler)
  end
  
  def pbMessagesOnReplace(idxBattler, idxParty, withTriggers = true)
    party = pbParty(idxBattler)
    if withTriggers
	  nextPoke = party[idxParty]
      triggers = ["switchIn", "switchIn" + nextPoke.species.to_s]
      nextPoke.types.each { |t| triggers.push("switchIn" + t.to_s) }
      triggers.push("switchInLast") if pbAbleNonActiveCount(idxBattler) == 1
      @scene.pbDeluxeTriggers(idxBattler, nil, triggers)
    end
    newPkmnName = party[idxParty].name_title
    if party[idxParty].ability == :ILLUSION && !pbCheckGlobalAbility(:NEUTRALIZINGGAS)
      new_index = pbLastInTeam(idxBattler)
      newPkmnName = party[new_index].name_title if new_index >= 0 && new_index != idxParty
    end
    if pbOwnedByPlayer?(idxBattler)
      opposing = @battlers[idxBattler].pbDirectOpposing
      if opposing.fainted? || opposing.hp == opposing.totalhp
        pbDisplayBrief(_INTL("You're in charge, {1}!", newPkmnName))
      elsif opposing.hp >= opposing.totalhp / 2
        pbDisplayBrief(_INTL("Go for it, {1}!", newPkmnName))
      elsif opposing.hp >= opposing.totalhp / 4
        pbDisplayBrief(_INTL("Just a little more! Hang in there, {1}!", newPkmnName))
      else
        pbDisplayBrief(_INTL("Your opponent's weak! Get 'em, {1}!", newPkmnName))
      end
    else
      owner = pbGetOwnerFromBattlerIndex(idxBattler)
      pbDisplayBrief(_INTL("{1} sent out {2}!", owner.full_name, newPkmnName))
    end
  end
  
  alias dx_pbReplace pbReplace
  def pbReplace(idxBattler, idxParty, batonPass = false, withTriggers = true)
    dx_pbReplace(idxBattler, idxParty, batonPass)
    if withTriggers
      battler = @battlers[idxBattler]
      triggers = ["switchSentOut", "switchSentOut" + battler.species.to_s]
      battler.pokemon.types.each { |t| triggers.push("switchSentOut" + t.to_s) }
      triggers.push("switchSentOutLast") if pbAbleNonActiveCount(idxBattler) == 0
      @scene.pbDeluxeTriggers(idxBattler, nil, triggers)
    end
  end
  
  def pbRecallAndReplace(idxBattler, idxParty, randomReplacement = false, batonPass = false, withTriggers = true)
    @scene.pbRecall(idxBattler) if !@battlers[idxBattler].fainted?
    @battlers[idxBattler].pbAbilitiesOnSwitchOut
    @scene.pbShowPartyLineup(idxBattler & 1) if pbSideSize(idxBattler) == 1
    pbMessagesOnReplace(idxBattler, idxParty, withTriggers) if !randomReplacement
    pbReplace(idxBattler, idxParty, batonPass, withTriggers)
  end
  
  #-----------------------------------------------------------------------------
  # Mid-battle triggers for various effects ending.
  #-----------------------------------------------------------------------------
  def pbEORCountDownBattlerEffect(priority, effect)
    priority.each do |battler|
      next if battler.fainted? || battler.effects[effect] == 0
      battler.effects[effect] -= 1
      yield battler if block_given? && battler.effects[effect] == 0
      sym = dxConvertToPBEffect(effect, :battler)
      @scene.pbDeluxeTriggers(battler, nil, ["endEffect", "endEffect" + sym.to_s.upcase]) if sym
    end
  end
  
  def pbEORCountDownSideEffect(side, effect, msg)
    return if @sides[side].effects[effect] <= 0
    @sides[side].effects[effect] -= 1
    if @sides[side].effects[effect] == 0
      pbDisplay(msg)
      sym = dxConvertToPBEffect(effect, :side)
      @scene.pbDeluxeTriggers(side, nil, ["endTeamEffect", "endTeamEffect" + sym.to_s.upcase]) if sym
    end
  end
  
  def pbEORCountDownFieldEffect(effect, msg)
    return if @field.effects[effect] <= 0
    @field.effects[effect] -= 1
    return if @field.effects[effect] > 0
    pbDisplay(msg)
    if effect == PBEffects::MagicRoom
      pbPriority(true).each { |battler| battler.pbItemTerrainStatBoostCheck }
    end
    sym = dxConvertToPBEffect(effect, :field)
    @scene.pbDeluxeTriggers(nil, nil, ["endFieldEffect", "endFieldEffect" + sym.to_s.upcase]) if sym
  end
  
  alias dx_pbEOREndWeather pbEOREndWeather
  def pbEOREndWeather(priority)
    oldWeather = @field.weather
    dx_pbEOREndWeather(priority)
    newWeather = @field.weather
    if newWeather == :None && oldWeather != :None
      @scene.pbDeluxeTriggers(nil, nil, ["endWeather", "endWeather" + oldWeather.to_s.upcase])
    end
  end
  
  alias dx_pbEOREndTerrain pbEOREndTerrain
  def pbEOREndTerrain
    oldTerrain = @field.terrain
    dx_pbEOREndTerrain
    newTerrain = @field.terrain
    if newTerrain == :None && oldTerrain != :None
      @scene.pbDeluxeTriggers(nil, nil, ["endTerrain", "endTerrain" + oldTerrain.to_s.upcase])
    end
  end
  
  #-----------------------------------------------------------------------------
  # Mid-battle triggers for the end of the round.
  #-----------------------------------------------------------------------------
  alias dx_pbEndOfRoundPhase pbEndOfRoundPhase
  def pbEndOfRoundPhase
    ret = dx_pbEndOfRoundPhase
    triggers = ["turnEnd", "turnEnd_" + (1 + @turnCount).to_s]
    @scene.pbDeluxeTriggers(nil, nil, triggers)
    return ret
  end
  
  #-----------------------------------------------------------------------------
  # Mid-battle triggers upon losing a battle.
  #-----------------------------------------------------------------------------
  alias dx_pbLoseMoney pbLoseMoney
  def pbLoseMoney
    @scene.pbDeluxeTriggers(nil, nil, ["loss"])
    dx_pbLoseMoney
  end
end


module Battle::CatchAndStoreMixin
  #-----------------------------------------------------------------------------
  # Mid-battle triggers during the capture process.
  #-----------------------------------------------------------------------------
  alias dx_pbThrowPokeBall pbThrowPokeBall
  def pbThrowPokeBall(*args)
    idxBattler = args[0]
    if opposes?(idxBattler)
      battler = @battlers[idxBattler]
    else
      battler = @battlers[idxBattler].pbDirectOpposing(true)
    end
    personalID = battler.pokemon.personalID
    triggers = ["captureAttempt", "captureAttempt" + battler.species.to_s]
    types = battler.pokemon.types
    types.each { |t| triggers.push("captureAttempt" + t.to_s) }
    @scene.pbDeluxeTriggers(nil, battler.index, triggers)
    dx_pbThrowPokeBall(*args)
    captured = false
    @caughtPokemon.each { |p| captured = true if p.personalID == personalID }
    if captured
      triggers = ["captureSuccess", "captureSuccess" + battler.species.to_s]
      types.each { |t| triggers.push("captureSuccess" + t.to_s) }
      @scene.pbDeluxeTriggers(nil, nil, triggers)
    else
      triggers = ["captureFailure", "captureFailure" + battler.species.to_s]
      types.each { |t| triggers.push("captureFailure" + t.to_s) }
      @scene.pbDeluxeTriggers(nil, nil, triggers)
    end
  end
end


class Battle::Battler
  #-----------------------------------------------------------------------------
  # Mid-battle triggers for when a move is used.
  #-----------------------------------------------------------------------------
  alias dx_pbTryUseMove pbTryUseMove
  def pbTryUseMove(*args)
    ret = dx_pbTryUseMove(*args)
    if ret
      type = args[1].type.to_s
      triggers = ["move", "move" + type, "move" + args[1].id.to_s, "move" + @species.to_s]
      if args[1].damagingMove?
        triggers.push("moveDamaging", "moveDamaging" + type, "moveDamaging" + @species.to_s)
        triggers.push("movePhysical", "movePhysical" + type, "movePhysical" + @species.to_s) if args[1].physicalMove?
        triggers.push("moveSpecial", "moveSpecial" + type, "moveSpecial" + @species.to_s) if args[1].specialMove?
      else
        triggers.push("moveStatus", "moveStatus" + type, "moveStatus" + @species.to_s)
      end
      @battle.scene.pbDeluxeTriggers(self, args[0][3], triggers)
    end
    return ret
  end
  
  #-----------------------------------------------------------------------------
  # Mid-battle triggers for when a used move fails.
  #-----------------------------------------------------------------------------
  alias dx_pbSuccessCheckAgainstTarget pbSuccessCheckAgainstTarget
  def pbSuccessCheckAgainstTarget(move, user, target, targets)
    ret = dx_pbSuccessCheckAgainstTarget(move, user, target, targets)
    if !ret
      user_triggers = ["attackerNegated", "attackerNegated" + move.id.to_s, "attackerNegated" + move.type.to_s, "attackerNegated" + user.species.to_s]
      targ_triggers = ["defenderNegated", "defenderNegated" + move.id.to_s, "defenderNegated" + move.type.to_s, "defenderNegated" + target.species.to_s]
      @battle.scene.pbDeluxeTriggers(user.index, target.index, user_triggers) if user_triggers.length > 0
      @battle.scene.pbDeluxeTriggers(target.index, user.index, targ_triggers) if targ_triggers.length > 0
    end	  
    return ret
  end
  
  #-----------------------------------------------------------------------------
  # Mid-battle triggers for when a used move misses.
  #-----------------------------------------------------------------------------
  alias dx_pbMissMessage pbMissMessage
  def pbMissMessage(move, user, target)
    dx_pbMissMessage(move, user, target)
    user_triggers = ["attackerDodged", "attackerDodged" + move.id.to_s, "attackerDodged" + move.type.to_s, "attackerDodged" + user.species.to_s]
    targ_triggers = ["defenderDodged", "defenderDodged" + move.id.to_s, "defenderDodged" + move.type.to_s, "defenderDodged" + target.species.to_s]
    @battle.scene.pbDeluxeTriggers(user.index, target.index, user_triggers) if user_triggers.length > 0
    @battle.scene.pbDeluxeTriggers(target.index, user.index, targ_triggers) if targ_triggers.length > 0
  end
  
  #-----------------------------------------------------------------------------
  # Mid-battle triggers for when a status condition is inflicted.
  #-----------------------------------------------------------------------------
  alias dx_pbInflictStatus pbInflictStatus 
  def pbInflictStatus(*args)
    oldStatus = self.status
    dx_pbInflictStatus(*args)
    if ![:NONE, oldStatus].include?(self.status)
      triggers = ["statusInflicted", "statusInflicted" + self.status.to_s, "statusInflicted" + @species.to_s]
      @battle.scene.pbDeluxeTriggers(self, nil, triggers)
    end
  end
  
  #-----------------------------------------------------------------------------
  # Mid-battle triggers for when a Pokemon faints.
  #-----------------------------------------------------------------------------
  alias dx_pbFaint pbFaint
  def pbFaint(showMessage = true, withTriggers = true)
    return if @fainted
    raidcapture = $game_temp.dx_rules? && $game_temp.dx_rules[:raidcapture]
    if !pbOwnedByPlayer? && raidcapture && @battle.wildBattle? && @battle.decision == 0
      self.hp += 1
      params = $game_temp.dx_rules[:raidcapture]
      pbRaidStyleCapture(self, (params[2] || 0), params[0], params[1])
    else
      dx_pbFaint(showMessage)
      if withTriggers && fainted?
        if @battle.pbAllFainted?(@index)
          triggers = ["faintedLast", "faintedLast" + @species.to_s]
          @pokemon.types.each { |t| triggers.push("faintedLast" + t.to_s) } 
        else
          triggers = ["fainted", "fainted" + @species.to_s]
          @pokemon.types.each { |t| triggers.push("fainted" + t.to_s) }
        end
        @battle.scene.pbDeluxeTriggers(self, nil, triggers)
      end
    end
  end
end


class Battle::Move
  #-----------------------------------------------------------------------------
  # Mid-battle triggers for type effectiveness of a used move.
  #-----------------------------------------------------------------------------
  alias dx_pbEffectivenessMessage pbEffectivenessMessage
  def pbEffectivenessMessage(user, target, numTargets = 1)
    dx_pbEffectivenessMessage(user, target, numTargets)
    return if target.damageState.disguise || target.damageState.iceFace
    if Effectiveness.super_effective?(target.damageState.typeMod)
      user_triggers = ["attackerSEdmg", "attackerSEdmg" + @id.to_s, "attackerSEdmg" + @type.to_s, "attackerSEdmg" + user.species.to_s]
      targ_triggers = ["defenderSEdmg", "defenderSEdmg" + @id.to_s, "defenderSEdmg" + @type.to_s, "defenderSEdmg" + target.species.to_s]
    elsif Effectiveness.not_very_effective?(target.damageState.typeMod)
      user_triggers = ["attackerNVEdmg", "attackerNVEdmg" + @id.to_s, "attackerNVEdmg" + @type.to_s, "attackerNVEdmg" + user.species.to_s]
      targ_triggers = ["defenderNVEdmg", "defenderNVEdmg" + @id.to_s, "defenderNVEdmg" + @type.to_s, "defenderNVEdmg" + target.species.to_s]
    else return
    end
    return [user_triggers, targ_triggers]
  end

  #-----------------------------------------------------------------------------
  # Mid-battle triggers for when a used move deals damage.
  #-----------------------------------------------------------------------------
  def pbHitEffectivenessMessages(user, target, numTargets = 1)
    return if target.damageState.disguise || target.damageState.iceFace
    effectiveness = nil
    user_triggers = []
    targ_triggers = []
    if target.damageState.substitute
      @battle.pbDisplay(_INTL("The substitute took damage for {1}!", target.pbThis(true)))
      if target.effects[PBEffects::Substitute] > 0
        user_triggers.push("attackerSubDamaged", "attackerSubDamaged" + user.species.to_s)
        targ_triggers.push("defenderSubDamaged", "defenderSubDamaged" + target.species.to_s)
      end
    end
    if target.damageState.critical
      if $game_temp.party_critical_hits_dealt &&
         $game_temp.party_critical_hits_dealt[user.pokemonIndex] &&
         user.pbOwnedByPlayer?
        $game_temp.party_critical_hits_dealt[user.pokemonIndex] += 1
      end
      if target.damageState.affection_critical
        if numTargets > 1
          @battle.pbDisplay(_INTL("{1} landed a critical hit on {2}, wishing to be praised!",
                                  user.pbThis, target.pbThis(true)))
        else
          @battle.pbDisplay(_INTL("{1} landed a critical hit, wishing to be praised!", user.pbThis))
        end
      elsif numTargets > 1
        @battle.pbDisplay(_INTL("A critical hit on {1}!", target.pbThis(true)))
      else
        @battle.pbDisplay(_INTL("A critical hit!"))
      end
      user_triggers.push("attackerCrit", "attackerCrit" + @id.to_s, "attackerCrit" + @type.to_s, "attackerCrit" + user.species.to_s)
      if !target.damageState.substitute
        targ_triggers.push("defenderCrit", "defenderCrit" + @id.to_s, "defenderCrit" + @type.to_s, "defenderCrit" + target.species.to_s)
      end
    end
    if !multiHitMove? && user.effects[PBEffects::ParentalBond] == 0
      effectiveness = pbEffectivenessMessage(user, target, numTargets)
      user_triggers += effectiveness[0] if effectiveness.is_a?(Array)
    end
    if target.damageState.substitute && target.effects[PBEffects::Substitute] == 0
      target.effects[PBEffects::Substitute] = 0
      @battle.pbDisplay(_INTL("{1}'s substitute faded!", target.pbThis))
      user_triggers.push("attackerSubBroken", "attackerSubBroken" + user.species.to_s)
      targ_triggers.push("defenderSubBroken", "defenderSubBroken" + target.species.to_s)
    end
    if !target.damageState.substitute
      user_triggers.push("attackerDamaged", "attackerDamaged" + @id.to_s, "attackerDamaged" + @type.to_s, "attackerDamaged" + user.species.to_s)
      if user.opposes?(target.index)
        targ_triggers.push("defenderDamaged", "defenderDamaged" + @id.to_s, "defenderDamaged" + @type.to_s, "defenderDamaged" + target.species.to_s)
      end
      targ_triggers += effectiveness[1] if effectiveness.is_a?(Array)
      if !user.fainted?
        if user.hp <= user.totalhp / 2
          lowHP = user.hp <= user.totalhp / 4
          if @battle.pbParty(user.index).length > @battle.pbSideSize(user.index)
            if @battle.pbAbleNonActiveCount(user.index) == 0
              user_triggers.push("attackerHPHalfLast", "attackerHPHalfLast" + user.species.to_s)
              user_triggers.push("attackerHPLowLast", "attackerHPLowLast" + user.species.to_s) if lowHP
              user.pokemon.types.each do |t| 
                user_triggers.push("attackerHPHalfLast" + t.to_s, "attackerHPHalfLast" + t.to_s)
                user_triggers.push("attackerHPLowLast" + t.to_s, "attackerHPLowLast" + t.to_s) if lowHP
              end
            else
              user_triggers.push("attackerHPHalf", "attackerHPHalf" + user.species.to_s)
              user_triggers.push("attackerHPLow", "attackerHPLow" + user.species.to_s) if lowHP
              user.pokemon.types.each do |t| 
                user_triggers.push("attackerHPHalf" + t.to_s, "attackerHPHalf" + t.to_s)
                user_triggers.push("attackerHPLow" + t.to_s, "attackerHPLow" + t.to_s) if lowHP
              end
            end
          else
            user_triggers.push("attackerHPHalfLast", "attackerHPHalfLast" + user.species.to_s, 
                               "attackerHPHalf", "attackerHPHalf" + user.species.to_s)
            user_triggers.push("attackerHPLowLast", "attackerHPLowLast" + user.species.to_s,
                               "attackerHPLow", "attackerHPLow" + user.species.to_s) if lowHP
            user.pokemon.types.each do |t| 
              user_triggers.push("attackerHPHalfLast" + t.to_s, "attackerHPHalfLast" + t.to_s,
                                 "attackerHPHalf" + t.to_s, "attackerHPHalf" + t.to_s,)
              user_triggers.push("attackerHPLowLast" + t.to_s, "attackerHPLowLast" + t.to_s,
                                 "attackerHPLow" + t.to_s, "attackerHPLow" + t.to_s) if lowHP
            end
          end
        end
      end
      if !target.fainted? && user.opposes?(target.index)
        if target.hp <= target.totalhp / 2
          lowHP = target.hp <= target.totalhp / 4
          if @battle.pbParty(target.index).length > @battle.pbSideSize(target.index)
            if @battle.pbAbleNonActiveCount(target.index) == 0
              targ_triggers.push("defenderHPHalfLast", "defenderHPHalfLast" + target.species.to_s)
              targ_triggers.push("defenderHPLowLast", "defenderHPLowLast" + target.species.to_s) if lowHP
              target.pokemon.types.each do |t| 
                targ_triggers.push("defenderHPHalfLast" + t.to_s, "defenderHPHalfLast" + t.to_s)
                targ_triggers.push("defenderHPLowLast" + t.to_s, "defenderHPLowLast" + t.to_s) if lowHP
              end
            else
              targ_triggers.push("defenderHPHalf", "defenderHPHalf" + target.species.to_s)
              targ_triggers.push("defenderHPLow", "defenderHPLow" + target.species.to_s) if lowHP
              target.pokemon.types.each do |t| 
                targ_triggers.push("defenderHPHalf" + t.to_s, "defenderHPHalf" + t.to_s)
                targ_triggers.push("defenderHPLow" + t.to_s, "defenderHPLow" + t.to_s) if lowHP
              end
            end
          else
            targ_triggers.push("defenderHPHalfLast", "defenderHPHalfLast" + target.species.to_s, 
                               "defenderHPHalf", "defenderHPHalf" + target.species.to_s)
            targ_triggers.push("defenderHPLowLast", "defenderHPLowLast" + target.species.to_s, 
                               "defenderHPLow", "defenderHPLow" + target.species.to_s) if lowHP
            target.pokemon.types.each do |t| 
              targ_triggers.push("defenderHPHalfLast" + t.to_s, "defenderHPHalfLast" + t.to_s,
                                 "defenderHPHalf" + t.to_s, "defenderHPHalf" + t.to_s,)
              targ_triggers.push("defenderHPLowLast" + t.to_s, "defenderHPLowLast" + t.to_s,
                                 "defenderHPLow" + t.to_s, "defenderHPLow" + t.to_s) if lowHP
            end
          end
        end
      end
    end
    @battle.scene.pbDeluxeTriggers(user.index, target.index, user_triggers) if user_triggers.length > 0
    @battle.scene.pbDeluxeTriggers(target.index, user.index, targ_triggers) if targ_triggers.length > 0
  end
end