# Change all @battle.moldBreaker condition for individual to affectedByMoldBreaker?
################################################################################
# Battler
################################################################################
class Battle::Battler
  def affectedByMoldBreaker?
    return @battle.moldBreaker && !hasActiveItem?(:ABILITYSHIELD)
  end
  def pbWeight
    ret = (@pokemon) ? @pokemon.weight : 500
    ret += @effects[PBEffects::WeightChange]
    ret = 1 if ret < 1
    if abilityActive? && !affectedByMoldBreaker?
      ret = Battle::AbilityEffects.triggerWeightCalc(self.ability, self, ret)
    end
    if itemActive?
      ret = Battle::ItemEffects.triggerWeightCalc(self.item, self, ret)
    end
    return [ret, 1].max
  end
  def airborne?
    return false if hasActiveItem?(:IRONBALL)
    return false if @effects[PBEffects::Ingrain]
    return false if @effects[PBEffects::SmackDown]
    return false if @battle.field.effects[PBEffects::Gravity] > 0
    return true if pbHasType?(:FLYING)
    return true if hasActiveAbility?(:LEVITATE) && !affectedByMoldBreaker?
    return true if hasActiveItem?(:AIRBALLOON)
    return true if @effects[PBEffects::MagnetRise] > 0
    return true if @effects[PBEffects::Telekinesis] > 0
    return false
  end
  def affectedByPowder?(showMsg = false)
    return false if fainted?
    if pbHasType?(:GRASS) && Settings::MORE_TYPE_EFFECTS
      @battle.pbDisplay(_INTL("{1} is unaffected!", pbThis)) if showMsg
      return false
    end
    if Settings::MECHANICS_GENERATION >= 6
      if hasActiveAbility?(:OVERCOAT) && !affectedByMoldBreaker?
        if showMsg
          @battle.pbShowAbilitySplash(self)
          if Battle::Scene::USE_ABILITY_SPLASH
            @battle.pbDisplay(_INTL("{1} is unaffected!", pbThis))
          else
            @battle.pbDisplay(_INTL("{1} is unaffected because of its {2}!", pbThis, abilityName))
          end
          @battle.pbHideAbilitySplash(self)
        end
        return false
      end
      if hasActiveItem?(:SAFETYGOGGLES)
        if showMsg
          @battle.pbDisplay(_INTL("{1} is unaffected because of its {2}!", pbThis, itemName))
        end
        return false
      end
    end
    return true
  end

  def pbCanInflictStatus?(newStatus, user, showMessages, move = nil, ignoreStatus = false)
    return false if fainted?
    self_inflicted = (user && user.index == @index)   # Rest and Flame Orb/Toxic Orb only
    # Already have that status problem
    if self.status == newStatus && !ignoreStatus
      if showMessages
        msg = ""
        case self.status
        when :SLEEP     then msg = _INTL("{1} is already asleep!", pbThis)
        when :POISON    then msg = _INTL("{1} is already poisoned!", pbThis)
        when :BURN      then msg = _INTL("{1} already has a burn!", pbThis)
        when :PARALYSIS then msg = _INTL("{1} is already paralyzed!", pbThis)
        when :FROZEN    then msg = _INTL("{1} is already frozen solid!", pbThis)
        end
        @battle.pbDisplay(msg)
      end
      return false
    end
    # Trying to replace a status problem with another one
    if self.status != :NONE && !ignoreStatus && !(self_inflicted && move)   # Rest can replace a status problem
      @battle.pbDisplay(_INTL("It doesn't affect {1}...", pbThis(true))) if showMessages
      return false
    end
    # Trying to inflict a status problem on a Pokémon behind a substitute
    if @effects[PBEffects::Substitute] > 0 && !(move && move.ignoresSubstitute?(user)) &&
       !self_inflicted
      @battle.pbDisplay(_INTL("It doesn't affect {1}...", pbThis(true))) if showMessages
      return false
    end
    # Weather immunity
    if newStatus == :FROZEN && [:Sun, :HarshSun].include?(effectiveWeather)
      @battle.pbDisplay(_INTL("It doesn't affect {1}...", pbThis(true))) if showMessages
      return false
    end
    # Terrains immunity
    if affectedByTerrain?
      case @battle.field.terrain
      when :Electric
        if newStatus == :SLEEP
          if showMessages
            @battle.pbDisplay(_INTL("{1} surrounds itself with electrified terrain!", pbThis(true)))
          end
          return false
        end
      when :Misty
        @battle.pbDisplay(_INTL("{1} surrounds itself with misty terrain!", pbThis(true))) if showMessages
        return false
      end
    end
    # Uproar immunity
    if newStatus == :SLEEP && !(hasActiveAbility?(:SOUNDPROOF) && !affectedByMoldBreaker?)
      @battle.allBattlers.each do |b|
        next if b.effects[PBEffects::Uproar] == 0
        @battle.pbDisplay(_INTL("But the uproar kept {1} awake!", pbThis(true))) if showMessages
        return false
      end
    end
    # Type immunities
    hasImmuneType = false
    case newStatus
    when :SLEEP
      # No type is immune to sleep
    when :POISON
      if !(user && user.hasActiveAbility?(:CORROSION))
        hasImmuneType |= pbHasType?(:POISON)
        hasImmuneType |= pbHasType?(:STEEL)
      end
    when :BURN
      hasImmuneType |= pbHasType?(:FIRE)
    when :PARALYSIS
      hasImmuneType |= pbHasType?(:ELECTRIC) && Settings::MORE_TYPE_EFFECTS
    when :FROZEN
      hasImmuneType |= pbHasType?(:ICE)
    end
    if hasImmuneType
      @battle.pbDisplay(_INTL("It doesn't affect {1}...", pbThis(true))) if showMessages
      return false
    end
    # Ability immunity
    immuneByAbility = false
    immAlly = nil
    if Battle::AbilityEffects.triggerStatusImmunityNonIgnorable(self.ability, self, newStatus)
      immuneByAbility = true
    elsif self_inflicted || !affectedByMoldBreaker?
      if abilityActive? && Battle::AbilityEffects.triggerStatusImmunity(self.ability, self, newStatus)
        immuneByAbility = true
      else
        allAllies.each do |b|
          next if !b.abilityActive?
          next if !Battle::AbilityEffects.triggerStatusImmunityFromAlly(b.ability, self, newStatus)
          immuneByAbility = true
          immAlly = b
          break
        end
      end
    end
    if immuneByAbility
      if showMessages
        @battle.pbShowAbilitySplash(immAlly || self)
        msg = ""
        if Battle::Scene::USE_ABILITY_SPLASH
          case newStatus
          when :SLEEP     then msg = _INTL("{1} stays awake!", pbThis)
          when :POISON    then msg = _INTL("{1} cannot be poisoned!", pbThis)
          when :BURN      then msg = _INTL("{1} cannot be burned!", pbThis)
          when :PARALYSIS then msg = _INTL("{1} cannot be paralyzed!", pbThis)
          when :FROZEN    then msg = _INTL("{1} cannot be frozen solid!", pbThis)
          end
        elsif immAlly
          case newStatus
          when :SLEEP
            msg = _INTL("{1} stays awake because of {2}'s {3}!",
                        pbThis, immAlly.pbThis(true), immAlly.abilityName)
          when :POISON
            msg = _INTL("{1} cannot be poisoned because of {2}'s {3}!",
                        pbThis, immAlly.pbThis(true), immAlly.abilityName)
          when :BURN
            msg = _INTL("{1} cannot be burned because of {2}'s {3}!",
                        pbThis, immAlly.pbThis(true), immAlly.abilityName)
          when :PARALYSIS
            msg = _INTL("{1} cannot be paralyzed because of {2}'s {3}!",
                        pbThis, immAlly.pbThis(true), immAlly.abilityName)
          when :FROZEN
            msg = _INTL("{1} cannot be frozen solid because of {2}'s {3}!",
                        pbThis, immAlly.pbThis(true), immAlly.abilityName)
          end
        else
          case newStatus
          when :SLEEP     then msg = _INTL("{1} stays awake because of its {2}!", pbThis, abilityName)
          when :POISON    then msg = _INTL("{1}'s {2} prevents poisoning!", pbThis, abilityName)
          when :BURN      then msg = _INTL("{1}'s {2} prevents burns!", pbThis, abilityName)
          when :PARALYSIS then msg = _INTL("{1}'s {2} prevents paralysis!", pbThis, abilityName)
          when :FROZEN    then msg = _INTL("{1}'s {2} prevents freezing!", pbThis, abilityName)
          end
        end
        @battle.pbDisplay(msg)
        @battle.pbHideAbilitySplash(immAlly || self)
      end
      return false
    end
    # Safeguard immunity
    if pbOwnSide.effects[PBEffects::Safeguard] > 0 && !self_inflicted && move &&
       !(user && user.hasActiveAbility?(:INFILTRATOR))
      @battle.pbDisplay(_INTL("{1}'s team is protected by Safeguard!", pbThis)) if showMessages
      return false
    end
    return true
  end
  #=============================================================================
  # Confusion
  #=============================================================================
  def pbCanConfuse?(user = nil, showMessages = true, move = nil, selfInflicted = false)
    return false if fainted?
    if @effects[PBEffects::Confusion] > 0
      @battle.pbDisplay(_INTL("{1} is already confused.", pbThis)) if showMessages
      return false
    end
    if @effects[PBEffects::Substitute] > 0 && !(move && move.ignoresSubstitute?(user)) &&
       !selfInflicted
      @battle.pbDisplay(_INTL("But it failed!")) if showMessages
      return false
    end
    # Terrains immunity
    if affectedByTerrain? && @battle.field.terrain == :Misty && Settings::MECHANICS_GENERATION >= 7
      @battle.pbDisplay(_INTL("{1} surrounds itself with misty terrain!", pbThis(true))) if showMessages
      return false
    end
    if (selfInflicted || !affectedByMoldBreaker?) && hasActiveAbility?(:OWNTEMPO)
      if showMessages
        @battle.pbShowAbilitySplash(self)
        if Battle::Scene::USE_ABILITY_SPLASH
          @battle.pbDisplay(_INTL("{1} doesn't become confused!", pbThis))
        else
          @battle.pbDisplay(_INTL("{1}'s {2} prevents confusion!", pbThis, abilityName))
        end
        @battle.pbHideAbilitySplash(self)
      end
      return false
    end
    if pbOwnSide.effects[PBEffects::Safeguard] > 0 && !selfInflicted &&
       !(user && user.hasActiveAbility?(:INFILTRATOR))
      @battle.pbDisplay(_INTL("{1}'s team is protected by Safeguard!", pbThis)) if showMessages
      return false
    end
    return true
  end
  #=============================================================================
  # Attraction
  #=============================================================================
  def pbCanAttract?(user, showMessages = true)
    return false if fainted?
    return false if !user || user.fainted?
    if @effects[PBEffects::Attract] >= 0
      @battle.pbDisplay(_INTL("{1} is unaffected!", pbThis)) if showMessages
      return false
    end
    agender = user.gender
    ogender = gender
    if agender == 2 || ogender == 2 || agender == ogender
      @battle.pbDisplay(_INTL("{1} is unaffected!", pbThis)) if showMessages
      return false
    end
    if !affectedByMoldBreaker?
      if hasActiveAbility?([:AROMAVEIL, :OBLIVIOUS])
        if showMessages
          @battle.pbShowAbilitySplash(self)
          if Battle::Scene::USE_ABILITY_SPLASH
            @battle.pbDisplay(_INTL("{1} is unaffected!", pbThis))
          else
            @battle.pbDisplay(_INTL("{1}'s {2} prevents romance!", pbThis, abilityName))
          end
          @battle.pbHideAbilitySplash(self)
        end
        return false
      else
        allAllies.each do |b|
          next if !b.hasActiveAbility?(:AROMAVEIL)
          if showMessages
            @battle.pbShowAbilitySplash(self)
            if Battle::Scene::USE_ABILITY_SPLASH
              @battle.pbDisplay(_INTL("{1} is unaffected!", pbThis))
            else
              @battle.pbDisplay(_INTL("{1}'s {2} prevents romance!", b.pbThis, b.abilityName))
            end
            @battle.pbHideAbilitySplash(self)
          end
          return true
        end
      end
    end
    return true
  end
  #=============================================================================
  # Flinching
  #=============================================================================
  def pbFlinch(_user = nil)
    return if hasActiveAbility?(:INNERFOCUS) && !affectedByMoldBreaker?
    @effects[PBEffects::Flinch] = true
  end

  #============================================================================
  # Stas
  #============================================================================
  def pbCanRaiseStatStage?(stat, user = nil, move = nil, showFailMsg = false, ignoreContrary = false)
    return false if fainted?
    # Contrary
    if hasActiveAbility?(:CONTRARY) && !ignoreContrary && !affectedByMoldBreaker?
      return pbCanLowerStatStage?(stat, user, move, showFailMsg, true)
    end
    # Check the stat stage
    if statStageAtMax?(stat)
      if showFailMsg
        @battle.pbDisplay(_INTL("{1}'s {2} won't go any higher!",
                                pbThis, GameData::Stat.get(stat).name))
      end
      return false
    end
    return true
  end
  def pbRaiseStatStageBasic(stat, increment, ignoreContrary = false)
    if !affectedByMoldBreaker?
      # Contrary
      if hasActiveAbility?(:CONTRARY) && !ignoreContrary
        return pbLowerStatStageBasic(stat, increment, true)
      end
      # Simple
      increment *= 2 if hasActiveAbility?(:SIMPLE)
    end
    # Change the stat stage
    increment = [increment, 6 - @stages[stat]].min
    if increment > 0
      stat_name = GameData::Stat.get(stat).name
      new = @stages[stat] + increment
      PBDebug.log("[Stat change] #{pbThis}'s #{stat_name}: #{@stages[stat]} -> #{new} (+#{increment})")
      @stages[stat] += increment
      @statsRaisedThisRound = true
    end
    return increment
  end
  def pbRaiseStatStageBasic(stat, increment, ignoreContrary = false)
    if !affectedByMoldBreaker?
      # Contrary
      if hasActiveAbility?(:CONTRARY) && !ignoreContrary
        return pbLowerStatStageBasic(stat, increment, true)
      end
      # Simple
      increment *= 2 if hasActiveAbility?(:SIMPLE)
    end
    # Change the stat stage
    increment = [increment, 6 - @stages[stat]].min
    if increment > 0
      stat_name = GameData::Stat.get(stat).name
      new = @stages[stat] + increment
      PBDebug.log("[Stat change] #{pbThis}'s #{stat_name}: #{@stages[stat]} -> #{new} (+#{increment})")
      @stages[stat] += increment
      @statsRaisedThisRound = true
    end
    return increment
  end
  def pbLowerStatStageBasic(stat, increment, ignoreContrary = false)
    if !affectedByMoldBreaker?
      # Contrary
      if hasActiveAbility?(:CONTRARY) && !ignoreContrary
        return pbRaiseStatStageBasic(stat, increment, true)
      end
      # Simple
      increment *= 2 if hasActiveAbility?(:SIMPLE)
    end
    # Change the stat stage
    increment = [increment, 6 + @stages[stat]].min
    if increment > 0
      stat_name = GameData::Stat.get(stat).name
      new = @stages[stat] - increment
      PBDebug.log("[Stat change] #{pbThis}'s #{stat_name}: #{@stages[stat]} -> #{new} (-#{increment})")
      @stages[stat] -= increment
      @statsLoweredThisRound = true
      @statsDropped = true
    end
    return increment
  end

  def pbLowerStatStage(stat, increment, user, showAnim = true, ignoreContrary = false,
                       mirrorArmorSplash = 0, ignoreMirrorArmor = false)
    if !affectedByMoldBreaker?
      # Contrary
      if hasActiveAbility?(:CONTRARY) && !ignoreContrary
        return pbRaiseStatStage(stat, increment, user, showAnim, true)
      end
      # Mirror Armor
      if hasActiveAbility?(:MIRRORARMOR) && !ignoreMirrorArmor &&
         user && user.index != @index && !statStageAtMin?(stat)
        if mirrorArmorSplash < 2
          @battle.pbShowAbilitySplash(self)
          if !Battle::Scene::USE_ABILITY_SPLASH
            @battle.pbDisplay(_INTL("{1}'s {2} activated!", pbThis, abilityName))
          end
        end
        ret = false
        if user.pbCanLowerStatStage?(stat, self, nil, true, ignoreContrary, true)
          ret = user.pbLowerStatStage(stat, increment, self, showAnim, ignoreContrary, mirrorArmorSplash, true)
        end
        @battle.pbHideAbilitySplash(self) if mirrorArmorSplash.even?   # i.e. not 1 or 3
        return ret
      end
    end
    # Perform the stat stage change
    increment = pbLowerStatStageBasic(stat, increment, ignoreContrary)
    return false if increment <= 0
    # Stat down animation and message
    @battle.pbCommonAnimation("StatDown", self) if showAnim
    arrStatTexts = [
      _INTL("{1}'s {2} fell!", pbThis, GameData::Stat.get(stat).name),
      _INTL("{1}'s {2} harshly fell!", pbThis, GameData::Stat.get(stat).name),
      _INTL("{1}'s {2} severely fell!", pbThis, GameData::Stat.get(stat).name)
    ]
    @battle.pbDisplay(arrStatTexts[[increment - 1, 2].min])
    # Trigger abilities upon stat loss
    if abilityActive?
      Battle::AbilityEffects.triggerOnStatLoss(self.ability, self, stat, user)
    end
    return true
  end

  def pbLowerStatStageByCause(stat, increment, user, cause, showAnim = true,
                              ignoreContrary = false, ignoreMirrorArmor = false)
    if !affectedByMoldBreaker?
      # Contrary
      if hasActiveAbility?(:CONTRARY) && !ignoreContrary
        return pbRaiseStatStageByCause(stat, increment, user, cause, showAnim, true)
      end
      # Mirror Armor
      if hasActiveAbility?(:MIRRORARMOR) && !ignoreMirrorArmor &&
         user && user.index != @index && !statStageAtMin?(stat)
        @battle.pbShowAbilitySplash(self)
        if !Battle::Scene::USE_ABILITY_SPLASH
          @battle.pbDisplay(_INTL("{1}'s {2} activated!", pbThis, abilityName))
        end
        ret = false
        if user.pbCanLowerStatStage?(stat, self, nil, true, ignoreContrary, true)
          ret = user.pbLowerStatStageByCause(stat, increment, self, abilityName, showAnim, ignoreContrary, true)
        end
        @battle.pbHideAbilitySplash(self)
        return ret
      end
    end
    # Perform the stat stage change
    increment = pbLowerStatStageBasic(stat, increment, ignoreContrary)
    return false if increment <= 0
    # Stat down animation and message
    @battle.pbCommonAnimation("StatDown", self) if showAnim
    if user.index == @index
      arrStatTexts = [
        _INTL("{1}'s {2} lowered its {3}!", pbThis, cause, GameData::Stat.get(stat).name),
        _INTL("{1}'s {2} harshly lowered its {3}!", pbThis, cause, GameData::Stat.get(stat).name),
        _INTL("{1}'s {2} severely lowered its {3}!", pbThis, cause, GameData::Stat.get(stat).name)
      ]
    else
      arrStatTexts = [
        _INTL("{1}'s {2} lowered {3}'s {4}!", user.pbThis, cause, pbThis(true), GameData::Stat.get(stat).name),
        _INTL("{1}'s {2} harshly lowered {3}'s {4}!", user.pbThis, cause, pbThis(true), GameData::Stat.get(stat).name),
        _INTL("{1}'s {2} severely lowered {3}'s {4}!", user.pbThis, cause, pbThis(true), GameData::Stat.get(stat).name)
      ]
    end
    @battle.pbDisplay(arrStatTexts[[increment - 1, 2].min])
    # Trigger abilities upon stat loss
    if abilityActive?
      Battle::AbilityEffects.triggerOnStatLoss(self.ability, self, stat, user)
    end
    return true
  end

  #=============================================================================
  # Master "use move" method
  #=============================================================================
  def pbUseMove(choice, specialUsage = false)
    # NOTE: This is intentionally determined before a multi-turn attack can
    #       set specialUsage to true.
    skipAccuracyCheck = (specialUsage && choice[2] != @battle.struggle)
    # Start using the move
    pbBeginTurn(choice)
    # Force the use of certain moves if they're already being used
    if usingMultiTurnAttack?
      choice[2] = Battle::Move.from_pokemon_move(@battle, Pokemon::Move.new(@currentMove))
      specialUsage = true
    elsif @effects[PBEffects::Encore] > 0 && choice[1] >= 0 &&
          @battle.pbCanShowCommands?(@index)
      idxEncoredMove = pbEncoredMoveIndex
      if idxEncoredMove >= 0 && choice[1] != idxEncoredMove &&
         @battle.pbCanChooseMove?(@index, idxEncoredMove, false)   # Change move if battler was Encored mid-round
        choice[1] = idxEncoredMove
        choice[2] = @moves[idxEncoredMove]
        choice[3] = -1   # No target chosen
      end
    end
    # Labels the move being used as "move"
    move = choice[2]
    return if !move   # if move was not chosen somehow
    # Try to use the move (inc. disobedience)
    @lastMoveFailed = false
    if !pbTryUseMove(choice, move, specialUsage, skipAccuracyCheck)
      @lastMoveUsed     = nil
      @lastMoveUsedType = nil
      if !specialUsage
        @lastRegularMoveUsed   = nil
        @lastRegularMoveTarget = -1
      end
      @battle.pbGainExp   # In case self is KO'd due to confusion
      pbCancelMoves
      pbEndTurn(choice)
      return
    end
    move = choice[2]   # In case disobedience changed the move to be used
    return if !move   # if move was not chosen somehow
    # Subtract PP
    if !specialUsage && !pbReducePP(move)
      @battle.pbDisplay(_INTL("{1} used {2}!", pbThis, move.name))
      @battle.pbDisplay(_INTL("But there was no PP left for the move!"))
      @lastMoveUsed          = nil
      @lastMoveUsedType      = nil
      @lastRegularMoveUsed   = nil
      @lastRegularMoveTarget = -1
      @lastMoveFailed        = true
      pbCancelMoves
      pbEndTurn(choice)
      return
    end
    # Stance Change
    if isSpecies?(:AEGISLASH) && self.ability == :STANCECHANGE
      if move.damagingMove?
        pbChangeForm(1, _INTL("{1} changed to Blade Forme!", pbThis))
      elsif move.id == :KINGSSHIELD
        pbChangeForm(0, _INTL("{1} changed to Shield Forme!", pbThis))
      end
    end
    # Calculate the move's type during this usage
    move.calcType = move.pbCalcType(self)
    # Start effect of Mold Breaker
    @battle.moldBreaker = hasMoldBreaker?
    # Remember that user chose a two-turn move
    if move.pbIsChargingTurn?(self)
      # Beginning the use of a two-turn attack
      @effects[PBEffects::TwoTurnAttack] = move.id
      @currentMove = move.id
    else
      @effects[PBEffects::TwoTurnAttack] = nil   # Cancel use of two-turn attack
    end
    # Add to counters for moves which increase them when used in succession
    move.pbChangeUsageCounters(self, specialUsage)
    # Charge up Metronome item
    if hasActiveItem?(:METRONOME) && !move.callsAnotherMove?
      if @lastMoveUsed && @lastMoveUsed == move.id && !@lastMoveFailed
        @effects[PBEffects::Metronome] += 1
      else
        @effects[PBEffects::Metronome] = 0
      end
    end
    # Record move as having been used
    @lastMoveUsed     = move.id
    @lastMoveUsedType = move.calcType   # For Conversion 2
    if !specialUsage
      @lastRegularMoveUsed   = move.id   # For Disable, Encore, Instruct, Mimic, Mirror Move, Sketch, Spite
      @lastRegularMoveTarget = choice[3]   # For Instruct (remembering original target is fine)
      @movesUsed.push(move.id) if !@movesUsed.include?(move.id)   # For Last Resort
    end
    @battle.lastMoveUsed = move.id   # For Copycat
    @battle.lastMoveUser = @index   # For "self KO" battle clause to avoid draws
    @battle.successStates[@index].useState = 1   # Battle Arena - assume failure
    # Find the default user (self or Snatcher) and target(s)
    user = pbFindUser(choice, move)
    user = pbChangeUser(choice, move, user)
    targets = pbFindTargets(choice, move, user)
    targets = pbChangeTargets(move, user, targets)
    # Pressure
    if !specialUsage
      targets.each do |b|
        next unless b.opposes?(user) && b.hasActiveAbility?(:PRESSURE)
        PBDebug.log("[Ability triggered] #{b.pbThis}'s #{b.abilityName}")
        user.pbReducePP(move)
      end
      if move.pbTarget(user).affects_foe_side
        @battle.allOtherSideBattlers(user).each do |b|
          next unless b.hasActiveAbility?(:PRESSURE)
          PBDebug.log("[Ability triggered] #{b.pbThis}'s #{b.abilityName}")
          user.pbReducePP(move)
        end
      end
    end
    # Dazzling/Queenly Majesty make the move fail here
    @battle.pbPriority(true).each do |b|
      next if !b || !b.abilityActive?
      if Battle::AbilityEffects.triggerMoveBlocking(b.ability, b, user, targets, move, @battle)
        @battle.pbDisplayBrief(_INTL("{1} used {2}!", user.pbThis, move.name))
        @battle.pbShowAbilitySplash(b)
        @battle.pbDisplay(_INTL("{1} cannot use {2}!", user.pbThis, move.name))
        @battle.pbHideAbilitySplash(b)
        user.lastMoveFailed = true
        pbCancelMoves
        pbEndTurn(choice)
        return
      end
    end
    # "X used Y!" message
    # Can be different for Bide, Fling, Focus Punch and Future Sight
    # NOTE: This intentionally passes self rather than user. The user is always
    #       self except if Snatched, but this message should state the original
    #       user (self) even if the move is Snatched.
    move.pbDisplayUseMessage(self)
    # Snatch's message (user is the new user, self is the original user)
    if move.snatched
      @lastMoveFailed = true   # Intentionally applies to self, not user
      @battle.pbDisplay(_INTL("{1} snatched {2}'s move!", user.pbThis, pbThis(true)))
    end
    # "But it failed!" checks
    if move.pbMoveFailed?(user, targets)
      PBDebug.log(sprintf("[Move failed] In function code %s's def pbMoveFailed?", move.function))
      user.lastMoveFailed = true
      pbCancelMoves
      pbEndTurn(choice)
      return
    end
    # Perform set-up actions and display messages
    # Messages include Magnitude's number and Pledge moves' "it's a combo!"
    move.pbOnStartUse(user, targets)
    # Self-thawing due to the move
    if user.status == :FROZEN && move.thawsUser?
      user.pbCureStatus(false)
      @battle.pbDisplay(_INTL("{1} melted the ice!", user.pbThis))
    end
    # Powder
    if user.effects[PBEffects::Powder] && move.calcType == :FIRE
      @battle.pbCommonAnimation("Powder", user)
      @battle.pbDisplay(_INTL("When the flame touched the powder on the Pokémon, it exploded!"))
      user.lastMoveFailed = true
      if ![:Rain, :HeavyRain].include?(user.effectiveWeather) && user.takesIndirectDamage?
        user.pbTakeEffectDamage((user.totalhp / 4.0).round, false) { |hp_lost|
          @battle.pbDisplay(_INTL("{1} is hurt by its {2}!", battler.pbThis, battler.itemName))
        }
        @battle.pbGainExp   # In case user is KO'd by this
      end
      pbCancelMoves
      pbEndTurn(choice)
      return
    end
    # Primordial Sea, Desolate Land
    if move.damagingMove?
      case @battle.pbWeather
      when :HeavyRain
        if move.calcType == :FIRE
          @battle.pbDisplay(_INTL("The Fire-type attack fizzled out in the heavy rain!"))
          user.lastMoveFailed = true
          pbCancelMoves
          pbEndTurn(choice)
          return
        end
      when :HarshSun
        if move.calcType == :WATER
          @battle.pbDisplay(_INTL("The Water-type attack evaporated in the harsh sunlight!"))
          user.lastMoveFailed = true
          pbCancelMoves
          pbEndTurn(choice)
          return
        end
      end
    end
    # Protean
    if user.hasActiveAbility?([:LIBERO, :PROTEAN]) &&
       !move.callsAnotherMove? && !move.snatched &&
       user.pbHasOtherType?(move.calcType) && !GameData::Type.get(move.calcType).pseudo_type && !user.effects[PBEffects::Protean]
      @battle.pbShowAbilitySplash(user)
      user.pbChangeTypes(move.calcType)
      typeName = GameData::Type.get(move.calcType).name
      @battle.pbDisplay(_INTL("{1}'s type changed to {2}!", user.pbThis, typeName))
      @battle.pbHideAbilitySplash(user)
      user.effects[PBEffects::Protean] = true
      # NOTE: The GF games say that if Curse is used by a non-Ghost-type
      #       Pokémon which becomes Ghost-type because of Protean, it should
      #       target and curse itself. I think this is silly, so I'm making it
      #       choose a random opponent to curse instead.
      if move.function == "CurseTargetOrLowerUserSpd1RaiseUserAtkDef1" && targets.length == 0
        choice[3] = -1
        targets = pbFindTargets(choice, move, user)
      end
    end
    #---------------------------------------------------------------------------
    magicCoater  = -1
    magicBouncer = -1
    if targets.length == 0 && move.pbTarget(user).num_targets > 0 && !move.worksWithNoTargets?
      # def pbFindTargets should have found a target(s), but it didn't because
      # they were all fainted
      # All target types except: None, User, UserSide, FoeSide, BothSides
      @battle.pbDisplay(_INTL("But there was no target..."))
      user.lastMoveFailed = true
    else   # We have targets, or move doesn't use targets
      # Reset whole damage state, perform various success checks (not accuracy)
      @battle.allBattlers.each do |b|
        b.droppedBelowHalfHP = false
        b.statsDropped = false
      end
      targets.each do |b|
        b.damageState.reset
        next if pbSuccessCheckAgainstTarget(move, user, b, targets)
        b.damageState.unaffected = true
      end
      # Magic Coat/Magic Bounce checks (for moves which don't target Pokémon)
      if targets.length == 0 && move.statusMove? && move.canMagicCoat?
        @battle.pbPriority(true).each do |b|
          next if b.fainted? || !b.opposes?(user)
          next if b.semiInvulnerable?
          if b.effects[PBEffects::MagicCoat]
            magicCoater = b.index
            b.effects[PBEffects::MagicCoat] = false
            break
          elsif b.hasActiveAbility?(:MAGICBOUNCE) && !b.affectedByMoldBreaker? &&
                !b.effects[PBEffects::MagicBounce]
            magicBouncer = b.index
            b.effects[PBEffects::MagicBounce] = true
            break
          end
        end
      end
      # Get the number of hits
      numHits = move.pbNumHits(user, targets)
      # Process each hit in turn
      realNumHits = 0
      numHits.times do |i|
        break if magicCoater >= 0 || magicBouncer >= 0
        success = pbProcessMoveHit(move, user, targets, i, skipAccuracyCheck)
        if !success
          if i == 0 && targets.length > 0
            hasFailed = false
            targets.each do |t|
              next if t.damageState.protected
              hasFailed = t.damageState.unaffected
              break if !t.damageState.unaffected
            end
            user.lastMoveFailed = hasFailed
          end
          break
        end
        realNumHits += 1
        break if user.fainted?
        break if [:SLEEP, :FROZEN].include?(user.status)
        # NOTE: If a multi-hit move becomes disabled partway through doing those
        #       hits (e.g. by Cursed Body), the rest of the hits continue as
        #       normal.
        break if targets.none? { |t| !t.fainted? }   # All targets are fainted
      end
      # Battle Arena only - attack is successful
      @battle.successStates[user.index].useState = 2
      if targets.length > 0
        @battle.successStates[user.index].typeMod = 0
        targets.each do |b|
          next if b.damageState.unaffected
          @battle.successStates[user.index].typeMod += b.damageState.typeMod
        end
      end
      # Effectiveness message for multi-hit moves
      # NOTE: No move is both multi-hit and multi-target, and the messages below
      #       aren't quite right for such a hypothetical move.
      if numHits > 1
        if move.damagingMove?
          targets.each do |b|
            next if b.damageState.unaffected || b.damageState.substitute
            move.pbEffectivenessMessage(user, b, targets.length)
          end
        end
        if realNumHits == 1
          @battle.pbDisplay(_INTL("Hit 1 time!"))
        elsif realNumHits > 1
          @battle.pbDisplay(_INTL("Hit {1} times!", realNumHits))
        end
      end
      # Magic Coat's bouncing back (move has targets)
      targets.each do |b|
        next if b.fainted?
        next if !b.damageState.magicCoat && !b.damageState.magicBounce
        @battle.pbShowAbilitySplash(b) if b.damageState.magicBounce
        @battle.pbDisplay(_INTL("{1} bounced the {2} back!", b.pbThis, move.name))
        @battle.pbHideAbilitySplash(b) if b.damageState.magicBounce
        newChoice = choice.clone
        newChoice[3] = user.index
        newTargets = pbFindTargets(newChoice, move, b)
        newTargets = pbChangeTargets(move, b, newTargets)
        success = false
        if !move.pbMoveFailed?(b, newTargets)
          newTargets.each_with_index do |newTarget, idx|
            if pbSuccessCheckAgainstTarget(move, b, newTarget, newTargets)
              success = true
              next
            end
            newTargets[idx] = nil
          end
          newTargets.compact!
        end
        pbProcessMoveHit(move, b, newTargets, 0, false) if success
        b.lastMoveFailed = true if !success
        targets.each { |otherB| otherB.pbFaint if otherB&.fainted? }
        user.pbFaint if user.fainted?
      end
      # Magic Coat's bouncing back (move has no targets)
      if magicCoater >= 0 || magicBouncer >= 0
        mc = @battle.battlers[(magicCoater >= 0) ? magicCoater : magicBouncer]
        if !mc.fainted?
          user.lastMoveFailed = true
          @battle.pbShowAbilitySplash(mc) if magicBouncer >= 0
          @battle.pbDisplay(_INTL("{1} bounced the {2} back!", mc.pbThis, move.name))
          @battle.pbHideAbilitySplash(mc) if magicBouncer >= 0
          success = false
          if !move.pbMoveFailed?(mc, [])
            success = pbProcessMoveHit(move, mc, [], 0, false)
          end
          mc.lastMoveFailed = true if !success
          targets.each { |b| b.pbFaint if b&.fainted? }
          user.pbFaint if user.fainted?
        end
      end
      # Move-specific effects after all hits
      targets.each { |b| move.pbEffectAfterAllHits(user, b) }
      # Faint if 0 HP
      targets.each { |b| b.pbFaint if b&.fainted? }
      user.pbFaint if user.fainted?
      # External/general effects after all hits. Eject Button, Shell Bell, etc.
      pbEffectsAfterMove(user, targets, move, realNumHits)
      @battle.allBattlers.each do |b|
        b.droppedBelowHalfHP = false
        b.statsDropped = false
      end
    end
    # End effect of Mold Breaker
    @battle.moldBreaker = false
    # Gain Exp
    @battle.pbGainExp
    # Battle Arena only - update skills
    @battle.allBattlers.each { |b| @battle.successStates[b.index].updateSkill }
    # Shadow Pokémon triggering Hyper Mode
    pbHyperMode if @battle.choices[@index][0] != :None   # Not if self is replaced
    # End of move usage
    pbEndTurn(choice)
    # Instruct
    @battle.allBattlers.each do |b|
      next if !b.effects[PBEffects::Instruct] || !b.lastMoveUsed
      b.effects[PBEffects::Instruct] = false
      idxMove = -1
      b.eachMoveWithIndex { |m, i| idxMove = i if m.id == b.lastMoveUsed }
      next if idxMove < 0
      oldLastRoundMoved = b.lastRoundMoved
      @battle.pbDisplay(_INTL("{1} used the move instructed by {2}!", b.pbThis, user.pbThis(true)))
      b.effects[PBEffects::Instructed] = true
      if b.pbCanChooseMove?(@moves[idxMove], false)
        PBDebug.logonerr {
          b.pbUseMoveSimple(b.lastMoveUsed, b.lastRegularMoveTarget, idxMove, false)
        }
        b.lastRoundMoved = oldLastRoundMoved
        @battle.pbJudge
        return if @battle.decision > 0
      end
      b.effects[PBEffects::Instructed] = false
    end
    # Dancer
    if !@effects[PBEffects::Dancer] && !user.lastMoveFailed && realNumHits > 0 &&
       !move.snatched && magicCoater < 0 && @battle.pbCheckGlobalAbility(:DANCER) &&
       move.danceMove?
      dancers = []
      @battle.pbPriority(true).each do |b|
        dancers.push(b) if b.index != user.index && b.hasActiveAbility?(:DANCER)
      end
      while dancers.length > 0
        nextUser = dancers.pop
        oldLastRoundMoved = nextUser.lastRoundMoved
        # NOTE: Petal Dance being used because of Dancer shouldn't lock the
        #       Dancer into using that move, and shouldn't contribute to its
        #       turn counter if it's already locked into Petal Dance.
        oldOutrage = nextUser.effects[PBEffects::Outrage]
        nextUser.effects[PBEffects::Outrage] += 1 if nextUser.effects[PBEffects::Outrage] > 0
        oldCurrentMove = nextUser.currentMove
        preTarget = choice[3]
        preTarget = user.index if nextUser.opposes?(user) || !nextUser.opposes?(preTarget)
        @battle.pbShowAbilitySplash(nextUser, true)
        @battle.pbHideAbilitySplash(nextUser)
        if !Battle::Scene::USE_ABILITY_SPLASH
          @battle.pbDisplay(_INTL("{1} kept the dance going with {2}!",
                                  nextUser.pbThis, nextUser.abilityName))
        end
        nextUser.effects[PBEffects::Dancer] = true
        if nextUser.pbCanChooseMove?(move, false)
          PBDebug.logonerr {
            nextUser.pbUseMoveSimple(move.id, preTarget)
          }
          nextUser.lastRoundMoved = oldLastRoundMoved
          nextUser.effects[PBEffects::Outrage] = oldOutrage
          nextUser.currentMove = oldCurrentMove
          @battle.pbJudge
          return if @battle.decision > 0
        end
        nextUser.effects[PBEffects::Dancer] = false
      end
    end
    # Add recoil damage and used move count for method for basculin, wyrdeer, and primeape
    if @lastMoveUsed && !self.lastMoveFailed
      self.pokemon.use_move(@lastMoveUsed)
      if move.recoilMove? && defined?(move.pbRecoilDamage) && !user.fainted?
        targets.each{|target|
          self.pokemon.add_recoil_dmg_taken(move.pbRecoilDamage(user,target))
        }
      end
    end
  end
end
################################################################################
# Battle::Move
################################################################################
class Battle::Move
  def pbImmunityByAbility(user, target, show_message)
    return false if target.affectedByMoldBreaker?
    ret = false
    if target.abilityActive?
      ret = Battle::AbilityEffects.triggerMoveImmunity(target.ability, user, target,
                                                       self, @calcType, @battle, show_message)
    end
    return ret
  end
  def pbMoveFailedAromaVeil?(user, target, showMessage = true)
    return false if target.affectedByMoldBreaker?
    if target.hasActiveAbility?(:AROMAVEIL)
      if showMessage
        @battle.pbShowAbilitySplash(target)
        if Battle::Scene::USE_ABILITY_SPLASH
          @battle.pbDisplay(_INTL("{1} is unaffected!", target.pbThis))
        else
          @battle.pbDisplay(_INTL("{1} is unaffected because of its {2}!",
                                  target.pbThis, target.abilityName))
        end
        @battle.pbHideAbilitySplash(target)
      end
      return true
    end
    target.allAllies.each do |b|
      next if !b.hasActiveAbility?(:AROMAVEIL)
      if showMessage
        @battle.pbShowAbilitySplash(target)
        if Battle::Scene::USE_ABILITY_SPLASH
          @battle.pbDisplay(_INTL("{1} is unaffected!", target.pbThis))
        else
          @battle.pbDisplay(_INTL("{1} is unaffected because of {2}'s {3}!",
                                  target.pbThis, b.pbThis(true), b.abilityName))
        end
        @battle.pbHideAbilitySplash(target)
      end
      return true
    end
    return false
  end
  def pbCheckDamageAbsorption(user, target)
    # Substitute will take the damage
    if target.effects[PBEffects::Substitute] > 0 && !ignoresSubstitute?(user) &&
       (!user || user.index != target.index)
      target.damageState.substitute = true
      return
    end
    # Ice Face will take the damage
    if !target.affectedByMoldBreaker? && target.isSpecies?(:EISCUE) &&
       target.form == 0 && target.ability == :ICEFACE && physicalMove?
      target.damageState.iceFace = true
      return
    end
    # Disguise will take the damage
    if !target.affectedByMoldBreaker? && target.isSpecies?(:MIMIKYU) &&
       target.form == 0 && target.ability == :DISGUISE
      target.damageState.disguise = true
      return
    end
  end

  def pbReduceDamage(user, target)
    damage = target.damageState.calcDamage
    # Substitute takes the damage
    if target.damageState.substitute
      damage = target.effects[PBEffects::Substitute] if damage > target.effects[PBEffects::Substitute]
      target.damageState.hpLost       = damage
      target.damageState.totalHPLost += damage
      return
    end
    # Disguise/Ice Face takes the damage
    return if target.damageState.disguise || target.damageState.iceFace
    # Target takes the damage
    if damage >= target.hp
      damage = target.hp
      # Survive a lethal hit with 1 HP effects
      if nonLethal?(user, target)
        damage -= 1
      elsif target.effects[PBEffects::Endure]
        target.damageState.endured = true
        damage -= 1
      elsif damage == target.totalhp
        if target.hasActiveAbility?(:STURDY) && !target.affectedByMoldBreaker?
          target.damageState.sturdy = true
          damage -= 1
        elsif target.hasActiveItem?(:FOCUSSASH) && target.hp == target.totalhp
          target.damageState.focusSash = true
          damage -= 1
        elsif target.hasActiveItem?(:FOCUSBAND) && @battle.pbRandom(100) < 10
          target.damageState.focusBand = true
          damage -= 1
        elsif Settings::AFFECTION_EFFECTS && @battle.internalBattle &&
              target.pbOwnedByPlayer? && !target.mega?
          chance = [0, 0, 0, 10, 15, 25][target.affection_level]
          if chance > 0 && @battle.pbRandom(100) < chance
            target.damageState.affection_endured = true
            damage -= 1
          end
        end
      end
    end
    damage = 0 if damage < 0
    target.damageState.hpLost       = damage
    target.damageState.totalHPLost += damage
  end
  #===============================================================================
  # Usage Calculation
  #===============================================================================
  def pbCalcAccuracyModifiers(user, target, modifiers)
    # Ability effects that alter accuracy calculation
    if user.abilityActive?
      Battle::AbilityEffects.triggerAccuracyCalcFromUser(
        user.ability, modifiers, user, target, self, @calcType
      )
    end
    user.allAllies.each do |b|
      next if !b.abilityActive?
      Battle::AbilityEffects.triggerAccuracyCalcFromAlly(
        b.ability, modifiers, user, target, self, @calcType
      )
    end
    if target.abilityActive? && !target.affectedByMoldBreaker?
      Battle::AbilityEffects.triggerAccuracyCalcFromTarget(
        target.ability, modifiers, user, target, self, @calcType
      )
    end
    # Item effects that alter accuracy calculation
    if user.itemActive?
      Battle::ItemEffects.triggerAccuracyCalcFromUser(
        user.item, modifiers, user, target, self, @calcType
      )
    end
    if target.itemActive?
      Battle::ItemEffects.triggerAccuracyCalcFromTarget(
        target.item, modifiers, user, target, self, @calcType
      )
    end
    # Other effects, inc. ones that set accuracy_multiplier or evasion_stage to
    # specific values
    if @battle.field.effects[PBEffects::Gravity] > 0
      modifiers[:accuracy_multiplier] *= 5 / 3.0
    end
    if user.effects[PBEffects::MicleBerry]
      user.effects[PBEffects::MicleBerry] = false
      modifiers[:accuracy_multiplier] *= 1.2
    end
    modifiers[:evasion_stage] = 0 if target.effects[PBEffects::Foresight] && modifiers[:evasion_stage] > 0
    modifiers[:evasion_stage] = 0 if target.effects[PBEffects::MiracleEye] && modifiers[:evasion_stage] > 0
  end
  # Returns whether the move will be a critical hit.
  def pbIsCritical?(user, target)
    return false if target.pbOwnSide.effects[PBEffects::LuckyChant] > 0
    # Set up the critical hit ratios
    ratios = (Settings::NEW_CRITICAL_HIT_RATE_MECHANICS) ? [24, 8, 2, 1] : [16, 8, 4, 3, 2]
    c = 0
    # Ability effects that alter critical hit rate
    if c >= 0 && user.abilityActive?
      c = Battle::AbilityEffects.triggerCriticalCalcFromUser(user.ability, user, target, c)
    end
    if c >= 0 && target.abilityActive? && !target.affectedByMoldBreaker?
      c = Battle::AbilityEffects.triggerCriticalCalcFromTarget(target.ability, user, target, c)
    end
    # Item effects that alter critical hit rate
    if c >= 0 && user.itemActive?
      c = Battle::ItemEffects.triggerCriticalCalcFromUser(user.item, user, target, c)
    end
    if c >= 0 && target.itemActive?
      c = Battle::ItemEffects.triggerCriticalCalcFromTarget(target.item, user, target, c)
    end
    return false if c < 0
    # Move-specific "always/never a critical hit" effects
    case pbCritialOverride(user, target)
    when 1  then return true
    when -1 then return false
    end
    # Other effects
    return true if c > 50   # Merciless
    return true if user.effects[PBEffects::LaserFocus] > 0
    c += 1 if highCriticalRate?
    c += user.effects[PBEffects::FocusEnergy]
    c += 1 if user.inHyperMode? && @type == :SHADOW
    c = ratios.length - 1 if c >= ratios.length
    # Calculation
    return true if ratios[c] == 1
    r = @battle.pbRandom(ratios[c])
    return true if r == 0
    if r == 1 && Settings::AFFECTION_EFFECTS && @battle.internalBattle &&
       user.pbOwnedByPlayer? && user.affection_level == 5 && !target.mega?
      target.damageState.affection_critical = true
      return true
    end
    return false
  end
  def pbCalcDamage(user, target, numTargets = 1)
    return if statusMove?
    if target.damageState.disguise || target.damageState.iceFace
      target.damageState.calcDamage = 1
      return
    end
    stageMul = [2, 2, 2, 2, 2, 2, 2, 3, 4, 5, 6, 7, 8]
    stageDiv = [8, 7, 6, 5, 4, 3, 2, 2, 2, 2, 2, 2, 2]
    # Get the move's type
    type = @calcType   # nil is treated as physical
    # Calculate whether this hit deals critical damage
    target.damageState.critical = pbIsCritical?(user, target)
    # Calcuate base power of move
    baseDmg = pbBaseDamage(@baseDamage, user, target)
    # Calculate user's attack stat
    atk, atkStage = pbGetAttackStats(user, target)
    if !target.hasActiveAbility?(:UNAWARE) || target.affectedByMoldBreaker?
      atkStage = 6 if target.damageState.critical && atkStage < 6
      atk = (atk.to_f * stageMul[atkStage] / stageDiv[atkStage]).floor
    end
    # Calculate target's defense stat
    defense, defStage = pbGetDefenseStats(user, target)
    if !user.hasActiveAbility?(:UNAWARE)
      defStage = 6 if target.damageState.critical && defStage > 6
      defense = (defense.to_f * stageMul[defStage] / stageDiv[defStage]).floor
    end
    # Calculate all multiplier effects
    multipliers = {
      :base_damage_multiplier  => 1.0,
      :attack_multiplier       => 1.0,
      :defense_multiplier      => 1.0,
      :final_damage_multiplier => 1.0
    }
    pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    # Main damage calculation
    baseDmg = [(baseDmg * multipliers[:base_damage_multiplier]).round, 1].max
    atk     = [(atk     * multipliers[:attack_multiplier]).round, 1].max
    defense = [(defense * multipliers[:defense_multiplier]).round, 1].max
    damage  = ((((2.0 * user.level / 5) + 2).floor * baseDmg * atk / defense).floor / 50).floor + 2
    damage  = [(damage * multipliers[:final_damage_multiplier]).round, 1].max
    target.damageState.calcDamage = damage
  end

  #=============================================================================
  # Additional effect chance
  #=============================================================================
  def pbAdditionalEffectChance(user, target, effectChance = 0)
    return 0 if target.hasActiveAbility?(:SHIELDDUST) && !target.affectedByMoldBreaker?
    ret = (effectChance > 0) ? effectChance : @addlEffect
    if (Settings::MECHANICS_GENERATION >= 6 || @function != "EffectDependsOnEnvironment") &&
       (user.hasActiveAbility?(:SERENEGRACE) || user.pbOwnSide.effects[PBEffects::Rainbow] > 0)
      ret *= 2
    end
    ret = 100 if $DEBUG && Input.press?(Input::CTRL)
    return ret
  end

  # NOTE: Flinching caused by a move's effect is applied in that move's code,
  #       not here.
  def pbFlinchChance(user, target)
    return 0 if flinchingMove?
    return 0 if target.hasActiveAbility?(:SHIELDDUST) && !target.affectedByMoldBreaker?
    ret = 0
    if user.hasActiveAbility?(:STENCH, true) ||
       user.hasActiveItem?([:KINGSROCK, :RAZORFANG], true)
      ret = 10
    end
    ret *= 2 if user.hasActiveAbility?(:SERENEGRACE) ||
                user.pbOwnSide.effects[PBEffects::Rainbow] > 0
    return ret
  end
end

################################################################################
# Moves
################################################################################
#===============================================================================
# Lower multiple of target's stats.
#===============================================================================
class Battle::Move::TargetMultiStatDownMove < Battle::Move
  def pbFailsAgainstTarget?(user, target, show_message)
    return false if damagingMove?
    failed = true
    (@statDown.length / 2).times do |i|
      next if !target.pbCanLowerStatStage?(@statDown[i * 2], user, self)
      failed = false
      break
    end
    if failed
      # NOTE: It's a bit of a faff to make sure the appropriate failure message
      #       is shown here, I know.
      canLower = false
      if target.hasActiveAbility?(:CONTRARY) && !target.affectedByMoldBreaker?
        (@statDown.length / 2).times do |i|
          next if target.statStageAtMax?(@statDown[i * 2])
          canLower = true
          break
        end
        @battle.pbDisplay(_INTL("{1}'s stats won't go any higher!", user.pbThis)) if !canLower && show_message
      else
        (@statDown.length / 2).times do |i|
          next if target.statStageAtMin?(@statDown[i * 2])
          canLower = true
          break
        end
        @battle.pbDisplay(_INTL("{1}'s stats won't go any lower!", user.pbThis)) if !canLower && show_message
      end
      if canLower
        target.pbCanLowerStatStage?(@statDown[0], user, self, show_message)
      end
      return true
    end
    return false
  end
end
#===============================================================================
# Decreases the target's Special Attack by 2 stages. Only works on the opposite
# gender. (Captivate)
#===============================================================================
class Battle::Move::LowerTargetSpAtk2IfCanAttract < Battle::Move::TargetStatDownMove
  def initialize(battle, move)
    super
    @statDown = [:SPECIAL_ATTACK, 2]
  end

  def pbFailsAgainstTarget?(user, target, show_message)
    return true if super
    return false if damagingMove?
    if user.gender == 2 || target.gender == 2 || user.gender == target.gender
      @battle.pbDisplay(_INTL("{1} is unaffected!", target.pbThis)) if show_message
      return true
    end
    if target.hasActiveAbility?(:OBLIVIOUS) && !target.affectedByMoldBreaker?
      if show_message
        @battle.pbShowAbilitySplash(target)
        if Battle::Scene::USE_ABILITY_SPLASH
          @battle.pbDisplay(_INTL("{1} is unaffected!", target.pbThis))
        else
          @battle.pbDisplay(_INTL("{1}'s {2} prevents romance!", target.pbThis, target.abilityName))
        end
        @battle.pbHideAbilitySplash(target)
      end
      return true
    end
    return false
  end

  def pbAdditionalEffect(user, target)
    return if user.gender == 2 || target.gender == 2 || user.gender == target.gender
    return if target.hasActiveAbility?(:OBLIVIOUS) && !target.affectedByMoldBreaker?
    super
  end
end
#===============================================================================
# OHKO. Accuracy increases by difference between levels of user and target.
#===============================================================================
class Battle::Move::OHKO < Battle::Move::FixedDamageMove
  def pbFailsAgainstTarget?(user, target, show_message)
    if target.level > user.level
      @battle.pbDisplay(_INTL("{1} is unaffected!", target.pbThis)) if show_message
      return true
    end
    if target.hasActiveAbility?(:STURDY) && !target.affectedMoldBreaker?
      if show_message
        @battle.pbShowAbilitySplash(target)
        if Battle::Scene::USE_ABILITY_SPLASH
          @battle.pbDisplay(_INTL("But it failed to affect {1}!", target.pbThis(true)))
        else
          @battle.pbDisplay(_INTL("But it failed to affect {1} because of its {2}!",
                                  target.pbThis(true), target.abilityName))
        end
        @battle.pbHideAbilitySplash(target)
      end
      return true
    end
    return false
  end
end
#===============================================================================
# Decreases the target's Attack by 1 stage. Heals user by an amount equal to the
# target's Attack stat (after applying stat stages, before this move decreases
# it). (Strength Sap)
#===============================================================================
class Battle::Move::HealUserByTargetAttackLowerTargetAttack1 < Battle::Move
  def pbFailsAgainstTarget?(user, target, show_message)
    # NOTE: The official games appear to just check whether the target's Attack
    #       stat stage is -6 and fail if so, but I've added the "fail if target
    #       has Contrary and is at +6" check too for symmetry. This move still
    #       works even if the stat stage cannot be changed due to an ability or
    #       other effect.
    if !target.affectedByMoldBreaker? && target.hasActiveAbility?(:CONTRARY) &&
       target.statStageAtMax?(:ATTACK)
      @battle.pbDisplay(_INTL("But it failed!")) if show_message
      return true
    elsif target.statStageAtMin?(:ATTACK)
      @battle.pbDisplay(_INTL("But it failed!")) if show_message
      return true
    end
    return false
  end
end
#===============================================================================
# Damages user by 1/2 of its max HP, even if this move misses. (Mind Blown)
#===============================================================================
class Battle::Move::UserLosesHalfOfTotalHPExplosive < Battle::Move
  def pbMoveFailed?(user, targets)
    # if !@battle.moldBreaker
    bearer = @battle.pbCheckGlobalAbility(:DAMP)
    if bearer && !bearer.affectedByMoldBreaker?
      @battle.pbShowAbilitySplash(bearer)
      if Battle::Scene::USE_ABILITY_SPLASH
        @battle.pbDisplay(_INTL("{1} cannot use {2}!", user.pbThis, @name))
      else
        @battle.pbDisplay(_INTL("{1} cannot use {2} because of {3}'s {4}!",
                                user.pbThis, @name, bearer.pbThis(true), bearer.abilityName))
      end
      @battle.pbHideAbilitySplash(bearer)
      return true
    end
    # end
    return false
  end
end
#===============================================================================
# User faints, even if the move does nothing else. (Explosion, Self-Destruct)
#===============================================================================
class Battle::Move::UserFaintsExplosive < Battle::Move
  def pbMoveFailed?(user, targets)
    # if !@battle.moldBreaker
    bearer = @battle.pbCheckGlobalAbility(:DAMP)
    if bearer && !bearer.affectedByMoldBreaker?
      @battle.pbShowAbilitySplash(bearer)
      if Battle::Scene::USE_ABILITY_SPLASH
        @battle.pbDisplay(_INTL("{1} cannot use {2}!", user.pbThis, @name))
      else
        @battle.pbDisplay(_INTL("{1} cannot use {2} because of {3}'s {4}!",
                                user.pbThis, @name, bearer.pbThis(true), bearer.abilityName))
      end
      @battle.pbHideAbilitySplash(bearer)
      return true
    end
    # end
    return false
  end
end
#===============================================================================
# Decreases the target's Attack by 1 stage. Heals user by an amount equal to the
# target's Attack stat (after applying stat stages, before this move decreases
# it). (Strength Sap)
#===============================================================================
class Battle::Move::HealUserByTargetAttackLowerTargetAttack1 < Battle::Move
  def pbFailsAgainstTarget?(user, target, show_message)
    # NOTE: The official games appear to just check whether the target's Attack
    #       stat stage is -6 and fail if so, but I've added the "fail if target
    #       has Contrary and is at +6" check too for symmetry. This move still
    #       works even if the stat stage cannot be changed due to an ability or
    #       other effect.
    if !target.affectedByMoldBreaker? && target.hasActiveAbility?(:CONTRARY) &&
       target.statStageAtMax?(:ATTACK)
      @battle.pbDisplay(_INTL("But it failed!")) if show_message
      return true
    elsif target.statStageAtMin?(:ATTACK)
      @battle.pbDisplay(_INTL("But it failed!")) if show_message
      return true
    end
    return false
  end
end
#===============================================================================
# User steals the target's item, if the user has none itself. (Covet, Thief)
# Items stolen from wild Pokémon are kept after the battle.
#===============================================================================
class Battle::Move::UserTakesTargetItem < Battle::Move
  def pbEffectAfterAllHits(user, target)
    return if user.wild?   # Wild Pokémon can't thieve
    return if user.fainted?
    return if target.damageState.unaffected || target.damageState.substitute
    return if !target.item || user.item
    return if target.unlosableItem?(target.item)
    return if user.unlosableItem?(target.item)
    return if target.hasActiveAbility?(:STICKYHOLD) && !target.affectedByMoldBreaker?
    itemName = target.itemName
    user.item = target.item
    # Permanently steal the item from wild Pokémon
    if target.wild? && !user.initialItem && target.item == target.initialItem
      user.setInitialItem(target.item)
      target.pbRemoveItem
    else
      target.pbRemoveItem(false)
    end
    @battle.pbDisplay(_INTL("{1} stole {2}'s {3}!", user.pbThis, target.pbThis(true), itemName))
    user.pbHeldItemTriggerCheck
  end
end
#===============================================================================
# User and target swap items. They remain swapped after wild battles.
# (Switcheroo, Trick)
#===============================================================================
class Battle::Move::UserTargetSwapItems < Battle::Move
  def pbFailsAgainstTarget?(user, target, show_message)
    if !user.item && !target.item
      @battle.pbDisplay(_INTL("But it failed!")) if show_message
      return true
    end
    if target.unlosableItem?(target.item) ||
       target.unlosableItem?(user.item) ||
       user.unlosableItem?(user.item) ||
       user.unlosableItem?(target.item)
      @battle.pbDisplay(_INTL("But it failed!")) if show_message
      return true
    end
    if target.hasActiveAbility?(:STICKYHOLD) && !target.affectedByMoldBreaker?
      if show_message
        @battle.pbShowAbilitySplash(target)
        if Battle::Scene::USE_ABILITY_SPLASH
          @battle.pbDisplay(_INTL("But it failed to affect {1}!", target.pbThis(true)))
        else
          @battle.pbDisplay(_INTL("But it failed to affect {1} because of its {2}!",
                                  target.pbThis(true), target.abilityName))
        end
        @battle.pbHideAbilitySplash(target)
      end
      return true
    end
    return false
  end
end
#===============================================================================
# Target drops its item. It regains the item at the end of the battle. (Knock Off)
# If target has a losable item, damage is multiplied by 1.5.
#===============================================================================
class Battle::Move::RemoveTargetItem < Battle::Move
  def pbEffectAfterAllHits(user, target)
    return if user.wild?   # Wild Pokémon can't knock off
    return if user.fainted?
    return if target.damageState.unaffected || target.damageState.substitute
    return if !target.item || target.unlosableItem?(target.item)
    return if target.hasActiveAbility?(:STICKYHOLD) && !target.affectedByMoldBreaker?
    itemName = target.itemName
    target.pbRemoveItem(false)
    @battle.pbDisplay(_INTL("{1} dropped its {2}!", target.pbThis, itemName))
  end
end
#===============================================================================
# Negates the effect and usability of the target's held item for the rest of the
# battle (even if it is switched out). Fails if the target doesn't have a held
# item, the item is unlosable, the target has Sticky Hold, or the target is
# behind a substitute. (Corrosive Gas)
#===============================================================================
class Battle::Move::CorrodeTargetItem < Battle::Move
  def pbFailsAgainstTarget?(user, target, show_message)
    if !target.item || target.unlosableItem?(target.item) ||
       target.effects[PBEffects::Substitute] > 0
      @battle.pbDisplay(_INTL("{1} is unaffected!", target.pbThis)) if show_message
      return true
    end
    if target.hasActiveAbility?(:STICKYHOLD) && !target.affectedByMoldBreaker?
      if show_message
        @battle.pbShowAbilitySplash(target)
        if Battle::Scene::USE_ABILITY_SPLASH
          @battle.pbDisplay(_INTL("{1} is unaffected!", target.pbThis))
        else
          @battle.pbDisplay(_INTL("{1} is unaffected because of its {2}!",
                                  target.pbThis(true), target.abilityName))
        end
        @battle.pbHideAbilitySplash(target)
      end
      return true
    end
    if @battle.corrosiveGas[target.index % 2][target.pokemonIndex]
      @battle.pbDisplay(_INTL("{1} is unaffected!", target.pbThis)) if show_message
      return true
    end
    return false
  end
end
#===============================================================================
# User consumes target's berry and gains its effect. (Bug Bite, Pluck)
#===============================================================================
class Battle::Move::UserConsumeTargetBerry < Battle::Move
  def pbEffectAfterAllHits(user, target)
    return if user.fainted? || target.fainted?
    return if target.damageState.unaffected || target.damageState.substitute
    return if !target.item || !target.item.is_berry?
    return if target.hasActiveAbility?(:STICKYHOLD) && !@battle.moldBreaker
    item = target.item
    itemName = target.itemName
    target.pbRemoveItem
    @battle.pbDisplay(_INTL("{1} stole and ate its target's {2}!", user.pbThis, itemName))
    user.pbHeldItemTriggerCheck(item, false)
  end
end
#===============================================================================
# User flings its item at the target. Power/effect depend on the item. (Fling)
#===============================================================================
class Battle::Move::ThrowUserItemAtTarget < Battle::Move
  def pbEffectAgainstTarget(user, target)
    return if target.damageState.substitute
    return if target.hasActiveAbility?(:SHIELDDUST) && !target.affectedByMoldBreaker?
    case user.item_id
    when :POISONBARB
      target.pbPoison(user) if target.pbCanPoison?(user, false, self)
    when :TOXICORB
      target.pbPoison(user, nil, true) if target.pbCanPoison?(user, false, self)
    when :FLAMEORB
      target.pbBurn(user) if target.pbCanBurn?(user, false, self)
    when :LIGHTBALL
      target.pbParalyze(user) if target.pbCanParalyze?(user, false, self)
    when :KINGSROCK, :RAZORFANG
      target.pbFlinch(user)
    else
      target.pbHeldItemTriggerCheck(user.item, true)
    end
  end
end
#===============================================================================
# In wild battles, makes target flee. Fails if target is a higher level than the
# user.
# In trainer battles, target switches out.
# For status moves. (Roar, Whirlwind)
#===============================================================================
class Battle::Move::SwitchOutTargetStatusMove < Battle::Move
  def pbFailsAgainstTarget?(user, target, show_message)
    if target.hasActiveAbility?(:SUCTIONCUPS) && !target.affectedByMoldBreaker?
      if show_message
        @battle.pbShowAbilitySplash(target)
        if Battle::Scene::USE_ABILITY_SPLASH
          @battle.pbDisplay(_INTL("{1} anchors itself!", target.pbThis))
        else
          @battle.pbDisplay(_INTL("{1} anchors itself with {2}!", target.pbThis, target.abilityName))
        end
        @battle.pbHideAbilitySplash(target)
      end
      return true
    end
    if target.effects[PBEffects::Ingrain]
      @battle.pbDisplay(_INTL("{1} anchored itself with its roots!", target.pbThis)) if show_message
      return true
    end
    if !@battle.canRun
      @battle.pbDisplay(_INTL("But it failed!")) if show_message
      return true
    end
    if @battle.wildBattle? && target.level > user.level
      @battle.pbDisplay(_INTL("But it failed!")) if show_message
      return true
    end
    if @battle.trainerBattle?
      canSwitch = false
      @battle.eachInTeamFromBattlerIndex(target.index) do |_pkmn, i|
        next if !@battle.pbCanSwitchLax?(target.index, i)
        canSwitch = true
        break
      end
      if !canSwitch
        @battle.pbDisplay(_INTL("But it failed!")) if show_message
        return true
      end
    end
    return false
  end
  def pbSwitchOutTargetEffect(user, targets, numHits, switched_battlers)
    return if @battle.wildBattle? || !switched_battlers.empty?
    return if user.fainted? || numHits == 0
    targets.each do |b|
      next if b.fainted? || b.damageState.unaffected
      next if b.effects[PBEffects::Ingrain]
      next if b.hasActiveAbility?(:SUCTIONCUPS) && !b.affectedByMoldBreaker?
      newPkmn = @battle.pbGetReplacementPokemonIndex(b.index, true)   # Random
      next if newPkmn < 0
      @battle.pbRecallAndReplace(b.index, newPkmn, true)
      @battle.pbDisplay(_INTL("{1} was dragged out!", b.pbThis))
      @battle.pbClearChoice(b.index)   # Replacement Pokémon does nothing this round
      @battle.pbOnBattlerEnteringBattle(b.index)
      switched_battlers.push(b.index)
      break
    end
  end
end
#===============================================================================
# For 4 rounds, disables the target's non-damaging moves. (Taunt)
#===============================================================================
class Battle::Move::DisableTargetStatusMoves < Battle::Move
  def pbFailsAgainstTarget?(user, target, show_message)
    if target.effects[PBEffects::Taunt] > 0
      @battle.pbDisplay(_INTL("But it failed!")) if show_message
      return true
    end
    return true if pbMoveFailedAromaVeil?(user, target, show_message)
    if Settings::MECHANICS_GENERATION >= 6 && target.hasActiveAbility?(:OBLIVIOUS) &&
       !target.affectedByMoldBreaker?
      if show_message
        @battle.pbShowAbilitySplash(target)
        if Battle::Scene::USE_ABILITY_SPLASH
          @battle.pbDisplay(_INTL("But it failed!"))
        else
          @battle.pbDisplay(_INTL("But it failed because of {1}'s {2}!",
                                  target.pbThis(true), target.abilityName))
        end
        @battle.pbHideAbilitySplash(target)
      end
      return true
    end
    return false
  end
end



################################################################################
# Ability
################################################################################
Battle::AbilityEffects::OnBeingHit.add(:AFTERMATH,
  proc { |ability, user, target, move, battle|
    next if !target.fainted?
    next if !move.pbContactMove?(user)
    battle.pbShowAbilitySplash(target)
    # if !battle.moldBreaker
    dampBattler = battle.pbCheckGlobalAbility(:DAMP)
    if dampBattler && !dampBattler.affectedMoldBreaker?
      battle.pbShowAbilitySplash(dampBattler)
      if Battle::Scene::USE_ABILITY_SPLASH
        battle.pbDisplay(_INTL("{1} cannot use {2}!", target.pbThis, target.abilityName))
      else
        battle.pbDisplay(_INTL("{1} cannot use {2} because of {3}'s {4}!",
            target.pbThis, target.abilityName, dampBattler.pbThis(true), dampBattler.abilityName))
      end
      battle.pbHideAbilitySplash(dampBattler)
      battle.pbHideAbilitySplash(target)
      next
    end
    # end
    if user.takesIndirectDamage?(Battle::Scene::USE_ABILITY_SPLASH) &&
       user.affectedByContactEffect?(Battle::Scene::USE_ABILITY_SPLASH)
      battle.scene.pbDamageAnimation(user)
      user.pbReduceHP(user.totalhp / 4, false)
      battle.pbDisplay(_INTL("{1} was caught in the aftermath!", user.pbThis))
    end
    battle.pbHideAbilitySplash(target)
  }
)

Battle::AbilityEffects::OnDealingHit.add(:POISONTOUCH,
  proc { |ability, user, target, move, battle|
    next if !move.contactMove?
    next if battle.pbRandom(100) >= 30
    battle.pbShowAbilitySplash(user)
    if target.hasActiveAbility?(:SHIELDDUST) && !target.affectedByMoldBreaker?
      battle.pbShowAbilitySplash(target)
      if !Battle::Scene::USE_ABILITY_SPLASH
        battle.pbDisplay(_INTL("{1} is unaffected!", target.pbThis))
      end
      battle.pbHideAbilitySplash(target)
    elsif target.pbCanPoison?(user, Battle::Scene::USE_ABILITY_SPLASH)
      msg = nil
      if !Battle::Scene::USE_ABILITY_SPLASH
        msg = _INTL("{1}'s {2} poisoned {3}!", user.pbThis, user.abilityName, target.pbThis(true))
      end
      target.pbPoison(user, msg)
    end
    battle.pbHideAbilitySplash(user)
  }
)