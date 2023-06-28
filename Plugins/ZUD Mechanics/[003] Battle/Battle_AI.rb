#===============================================================================
# Battler AI for ZUD mechanics.
#===============================================================================
class Battle::AI
  #-----------------------------------------------------------------------------
  # Ultra Burst
  #-----------------------------------------------------------------------------
  # The AI will immediately use Ultra Burst, if possible.
  #-----------------------------------------------------------------------------
  def pbEnemyShouldUltraBurst?(idxBattler)
    return false if @battle.pbScriptedMechanic?(idxBattler, :ultra)
    battler = @battle.battlers[idxBattler]
    elig = (battler.wild?) ? battler.ace? : true
    if @battle.pbCanUltraBurst?(idxBattler) && elig
      PBDebug.log("[AI] #{battler.pbThis} (#{idxBattler}) will Ultra Burst")
      return true
    end
    return false
  end
  
  #-----------------------------------------------------------------------------
  # Dynamax
  #-----------------------------------------------------------------------------
  # The AI will only Dynamax their last Pokemon that is entered in their lineup,
  # as listed in their PBS data. However, if an earlier Pokemon in their lineup
  # is flagged as an ace, they will Dynamax that one instead. The AI will
  # immediately Dynamax whichever Pokemon is on the field first.
  #-----------------------------------------------------------------------------
  def pbEnemyShouldDynamax?(idxBattler)
    return false if @battle.pbScriptedMechanic?(idxBattler, :dynamax)
    battler = @battle.battlers[idxBattler]
    ace = (battler.wild?) ? battler.ace? : (battler.ace? || @battle.pbAbleCount(idxBattler) == 1)
    if @battle.pbCanDynamax?(idxBattler) && ace
      battler.display_power_moves("Max Move") if !@battle.pbOwnedByPlayer?(idxBattler)
      PBDebug.log("[AI] #{battler.pbThis} (#{idxBattler}) will Dynamax")
      return true
    end
    return false
  end
  
  #-----------------------------------------------------------------------------
  # Z-Moves
  #-----------------------------------------------------------------------------
  # The AI will take all usable Z-Moves into account along with their normal 
  # moves if the option to Z-Move is available. If the AI determines that a
  # Z-Move is the best move to use, it will trigger the Z-Move mechanic and
  # use the selected Z-Move.  
  #-----------------------------------------------------------------------------
  alias zud_pbChooseMoves pbChooseMoves
  def pbChooseMoves(idxBattler)
    # Adds every eligible Z-Move to the user's movepool selection if the user has
    # the Z-Move option available to use.
    user = @battle.battlers[idxBattler]
    elig = (user.wild?) ? user.ace? : true 
    if @battle.pbCanZMove?(idxBattler) && elig && !@battle.pbScriptedMechanic?(idxBattler, :zmove)
      new_moves = []
      user.base_moves.clear
      species = (user.effects[PBEffects::Transform]) ? user.effects[PBEffects::TransformPokemon].species_data.id : nil
      user.eachMoveWithIndex do |m, i|
	    user.base_moves.push(m)
        if user.pokemon.compat_zmove?(m, nil, species)
          zmove = user.convert_zmove(m, user.item, species)
          zmove.pp = m.pp
        else
          zmove = nil
        end
        new_moves.push(zmove)
      end
      if !new_moves.empty?
        new_moves.each { |m| user.moves.push(m) if m }
      end
      zud_pbChooseMoves(idxBattler)
      # Registers the Z-Move mechanic if the AI determined a Z-Move is the best
      # move to use.
      if @battle.choices[idxBattler][2].zMove?
        @battle.pbRegisterZMove(idxBattler)
        user.power_trigger = true
        user.selectedMoveIsZMove = true
        new_moves.each_with_index do |m, i|
          next if m != @battle.choices[idxBattler][2]
          user.power_index = i
        end
      end
      if !user.base_moves.empty?
        user.moves.clear
        user.base_moves.each { |m| user.moves.push(m) }
      end
    else
      zud_pbChooseMoves(idxBattler)	
    end
  end
  
  #-----------------------------------------------------------------------------
  # Aliased for move scores.
  #-----------------------------------------------------------------------------
  # Adds AI move scores for each Power Move, allowing AI opponents to more
  # intelligently use Z-Moves and Max Moves.
  #-----------------------------------------------------------------------------
  alias aiEffectScorePart3_pbGetMoveScoreFunctionCode pbGetMoveScoreFunctionCode
  
  def pbGetMoveScoreFunctionCode(score, move, user, target, skill = 100)
    case move.function
    #---------------------------------------------------------------------------
    # Behemoth Blade, Behemoth Bash, Dynamax Cannon
    #---------------------------------------------------------------------------
    when "DoubleDamageOnDynamaxTargets"
      score += 60 if target.dynamax?
    #---------------------------------------------------------------------------
    # Max Guard
    #---------------------------------------------------------------------------
    when "ZUDProtectUser"
      if user.effects[PBEffects::ProtectRate] > 1 ||
         target.effects[PBEffects::HyperBeam] > 0
        score -= 90
      else
        if skill >= PBTrainerAI.mediumSkill
          score -= user.effects[PBEffects::ProtectRate] * 40
        end
        score += 50 if user.turnCount == 0
        score += 30 if target.effects[PBEffects::TwoTurnAttack]
      end
    #---------------------------------------------------------------------------
    # G-Max One Blow, G-Max Rapid Flow
    #---------------------------------------------------------------------------
    when "ZUDBypassProtect"
      score += 40 if target.pbHasMoveFunction?("ZUDProtectUser", "ProtectUser",
                                               "ProtectUserBanefulBunker",
                                               "ProtectUserFromDamagingMovesObstruct",
                                               "ProtectUserFromDamagingMovesKingsShield",
                                               "ProtectUserFromTargetingMovesSpikyShield")
    #---------------------------------------------------------------------------
    # Max Knuckle, Max Ooze
    #---------------------------------------------------------------------------
    when "ZUDRaiseUserAndAlliesAtk1", "ZUDRaiseUserAndAlliesSpAtk1"
      stat = (move.function == "ZUDRaiseUserAndAlliesAtk1") ? :ATTACK : :SPECIAL_ATTACK
      if move.statusMove?
        @battle.allSameSideBattlers(user.index).each do |b|
          if b.statStageAtMax?(stat)
            score -= 90
          else
            score -= b.stages[stat] * 20
            if skill >= PBTrainerAI.mediumSkill
              hasMoveCategory = false
              b.eachMove do |m|
                next if stat == :ATTACK && !m.physicalMove?(m.type)
                next if stat == :SPECIAL_ATTACK && !m.specialMove?(m.type)
                hasMoveCategory = true
                break
              end
              if hasMoveCategory
                score += 20
              elsif skill >= PBTrainerAI.highSkill
                score -= 90
              end
            end
          end
        end
      else
        @battle.allSameSideBattlers(user.index).each do |b|
          score += 20 if b.stages[stat] < 0
          if skill >= PBTrainerAI.mediumSkill
            hasMoveCategory = false
            b.eachMove do |m|
              next if stat == :ATTACK && !m.physicalMove?(m.type)
              next if stat == :SPECIAL_ATTACK && !m.specialMove?(m.type)
              hasMoveCategory = true
              break
            end
            score += 20 if hasMoveCategory
          end
        end
      end
    #---------------------------------------------------------------------------
    # Max Steelspike, Max Quake
    #---------------------------------------------------------------------------
    when "ZUDRaiseUserAndAlliesDef1", "ZUDRaiseUserAndAlliesSpDef1"
      stat = (move.function == "ZUDRaiseUserAndAlliesDef1") ? :DEFENSE : :SPECIAL_DEFENSE
      if move.statusMove?
        @battle.allSameSideBattlers(user.index).each do |b|
          if b.statStageAtMax?(stat)
            score -= 90
          else
            score += 40 if b.turnCount == 0
            score -= b.stages[stat] * 20
          end
        end
      else
        @battle.allSameSideBattlers(user.index).each do |b|
          score += 10 if b.turnCount == 0
          score += 20 if b.stages[stat] < 0
        end
      end
    #---------------------------------------------------------------------------
    # Max Airstream
    #---------------------------------------------------------------------------
    when "ZUDRaiseUserAndAlliesSpeed1"
      if move.statusMove?
        @battle.allSameSideBattlers(user.index).each do |b|
          if b.statStageAtMax?(:SPEED)
            score -= 90
          else
            score -= b.stages[:SPEED] * 10
            if skill >= PBTrainerAI.highSkill
              aspeed = pbRoughStat(b, :SPEED, skill)
              ospeed = pbRoughStat(target, :SPEED, skill)
              score += 30 if aspeed < ospeed && aspeed * 2 > ospeed
            end
          end
        end
      else
        @battle.allSameSideBattlers(user.index).each do |b|
          score += 20 if b.stages[:SPEED] < 0
        end
      end
    #---------------------------------------------------------------------------
    # Clangorous Soulblaze, Extreme Evoboost
    #---------------------------------------------------------------------------
    when "ZUDRaiseUserMainStats1", "ZUDRaiseUserMainStats2"
      GameData::Stat.each_main_battle { |s| score += 10 if user.stages[s.id] < 0 }
      score += 40 if user.pbHasMoveFunction?("SwitchOutUserPassOnEffects")
      if skill >= PBTrainerAI.mediumSkill
        hasDamagingAttack = false
        user.eachMove do |m|
          next if !m.damagingMove?
          hasDamagingAttack = true
          break
        end
        score += 20 if hasDamagingAttack
      end
    #---------------------------------------------------------------------------
    # G-Max Chi Strike
    #---------------------------------------------------------------------------
    when "ZUDRaiseUserAndAlliesCriticalHitRate1"
      if move.statusMove?
        @battle.allSameSideBattlers(user.index).each do |b|
          if b.effects[PBEffects::CriticalBoost] >= 4
            score -= 80
          else
            score += 30
          end
        end
      else
        @battle.allSameSideBattlers(user.index).each do |b|
          score += 30 if b.effects[PBEffects::CriticalBoost] < 2
        end
      end
    #---------------------------------------------------------------------------
    # Max Wyrmwind, Max Flutterby
    #---------------------------------------------------------------------------
    when "ZUDLowerAllFoesAtk1", "ZUDLowerAllFoesSpAtk1"
      stat = (move.function == "ZUDLowerAllFoesAtk1") ? :ATTACK : :SPECIAL_ATTACK
      if move.statusMove?
        @battle.allSameSideBattlers(target.index).each do |b|
          if b.pbCanLowerStatStage?(stat, user)
            score += b.stages[stat] * 20
            if skill >= PBTrainerAI.mediumSkill
              hasMoveCategory = false
              b.eachMove do |m|
                next if stat == :ATTACK && !m.physicalMove?(m.type)
                next if stat == :SPECIAL_ATTACK && !m.specialMove?(m.type)
                hasMoveCategory = true
                break
              end
              if hasMoveCategory
                score += 20
              elsif skill >= PBTrainerAI.highSkill
                score -= 90
              end
            end
          else
            score -= 90
          end
        end
      else
        @battle.allSameSideBattlers(target.index).each do |b|
          score += 20 if b.stages[:ATTACK] > 0
          if skill >= PBTrainerAI.mediumSkill
            hasMoveCategory = false
            b.eachMove do |m|
              next if stat == :ATTACK && !m.physicalMove?(m.type)
              next if stat == :SPECIAL_ATTACK && !m.specialMove?(m.type)
              hasMoveCategory = true
              break
            end
            score += 20 if hasMoveCategory
          end
        end
      end
    #---------------------------------------------------------------------------
    # Max Phantasm, Max Darkness
    #---------------------------------------------------------------------------
    when "ZUDLowerAllFoesDef1", "ZUDLowerAllFoesSpDef1"
      stat = (move.function == "ZUDLowerAllFoesDef1") ? :DEFENSE : :SPECIAL_DEFENSE
      if move.statusMove?
        @battle.allSameSideBattlers(target.index).each do |b|
          if b.pbCanLowerStatStage?(stat, user)
            score += b.stages[stat] * 20
          else
            score -= 90
          end
        end
      else
        @battle.allSameSideBattlers(target.index).each do |b|
          score += 20 if b.stages[stat] > 0
        end
      end
    #---------------------------------------------------------------------------
    # Max Strike, G-Max Foam Burst
    #--------------------------------------------------------------------------- 
    when "ZUDLowerAllFoesSpeed1", "ZUDLowerAllFoesSpeed2"
      if move.statusMove?
        @battle.allSameSideBattlers(target.index).each do |b|
          if b.pbCanLowerStatStage?(:SPEED, user)
            score += b.stages[:SPEED] * 10
            if skill >= PBTrainerAI.highSkill
              aspeed = pbRoughStat(user, :SPEED, skill)
              ospeed = pbRoughStat(b, :SPEED, skill)
              score += 30 if aspeed < ospeed && aspeed * 2 > ospeed
            end
          else
            score -= 90
          end
        end
      else
        @battle.allSameSideBattlers(target.index).each do |b|
          score += 20 if b.stages[:SPEED] > 0
        end
      end
    #---------------------------------------------------------------------------
    # G-Max Tartness
    #---------------------------------------------------------------------------
    when "ZUDLowerAllFoesEvasion1"
      if move.statusMove?
        @battle.allSameSideBattlers(target.index).each do |b|
          if b.pbCanLowerStatStage?(:EVASION, user)
            score += b.stages[:EVASION] * 10
          else
            score -= 90
          end
        end
      else 
        @battle.allSameSideBattlers(target.index).each do |b|
          score += 20 if b.stages[:EVASION] > 0
        end
      end
    #---------------------------------------------------------------------------
    # Max Flare, Max Geyser
    #---------------------------------------------------------------------------
    when "ZUDStartSunWeather", "ZUDStartRainWeather"
      case move.function
      when "ZUDStartSunWeather"
        move_weather = :Sun
        move_type = :FIRE
      when "ZUDStartRainWeather"
        move_weather = :Rain
        move_type = :WATER
      end
      if @battle.pbCheckGlobalAbility(:AIRLOCK) ||
         @battle.pbCheckGlobalAbility(:CLOUDNINE)
        score -= 90
      elsif @battle.field.weather == move_weather
        score -= 90
      else
        @battle.allSameSideBattlers(user.index).each do |b|
          b.eachMove do |m|
            next if !m.damagingMove? || m.type != move_type
            score += 20
          end
          case move_weather
          when :Sun
            score += 30 if b.hasActiveAbility?([:CHLOROPHYLL, :FLOWERGIFT, :LEAFGUARD, :SOLARPOWER])
          when :Rain
            score += 30 if b.hasActiveAbility?([:DRYSKIN, :HYDRATION, :RAINDISH, :SWIFTSWIM])
          end
        end
      end
    #---------------------------------------------------------------------------
    # Max Rockfall, Max Hailstorm
    #---------------------------------------------------------------------------
    when "ZUDStartSandstormWeather", "ZUDStartHailWeather"
      move_weather = (move.function == "ZUDStartSandstormWeather") ? :Sandstorm : :Hail
      if @battle.pbCheckGlobalAbility(:AIRLOCK) ||
         @battle.pbCheckGlobalAbility(:CLOUDNINE)
        score -= 90
      elsif @battle.field.weather == move_weather
        score -= 90
      else
        @battle.allSameSideBattlers(user.index).each do |b|
          case move_weather
          when :Sandstorm
            score += 30 if b.hasActiveAbility?([:SANDVEIL, :SANDRUSH, :SANDFORCE])
          when :Hail
            score += 30 if b.hasActiveAbility?([:ICEBODY, :SNOWCLOAK, :SLUSHRUSH, :ICEFACE])
          end
        end
      end
    #---------------------------------------------------------------------------
    # G-Max Gravitas
    #---------------------------------------------------------------------------
    when "ZUDStartGravity"
      if @battle.field.effects[PBEffects::Gravity] > 0
        score -= 90
      elsif skill >= PBTrainerAI.mediumSkill
        score -= 30
        score -= 20 if user.effects[PBEffects::SkyDrop] >= 0
        score -= 20 if user.effects[PBEffects::MagnetRise] > 0
        score -= 20 if user.effects[PBEffects::Telekinesis] > 0
        score -= 20 if user.pbHasType?(:FLYING)
        score -= 20 if user.hasActiveAbility?(:LEVITATE)
        score -= 20 if user.hasActiveItem?(:AIRBALLOON)
        score += 20 if target.effects[PBEffects::SkyDrop] >= 0
        score += 20 if target.effects[PBEffects::MagnetRise] > 0
        score += 20 if target.effects[PBEffects::Telekinesis] > 0
        score += 20 if target.inTwoTurnAttack?("TwoTurnAttackInvulnerableInSky",
                                               "TwoTurnAttackInvulnerableInSkyParalyzeTarget",
                                               "TwoTurnAttackInvulnerableInSkyTargetCannotAct")
        score += 20 if target.pbHasType?(:FLYING)
        score += 20 if target.hasActiveAbility?(:LEVITATE)
        score += 20 if target.hasActiveItem?(:AIRBALLOON)
      end
    #---------------------------------------------------------------------------
    # Genesis Supernova, Max Overgrowth, Max Lightning, Max Starfall, Max Mindstorm
    #---------------------------------------------------------------------------  
    when "ZUDStartGrassyTerrain", "ZUDStartElectricTerrain", 
         "ZUDStartMistyTerrain", "ZUDStartPsychicTerrain"
      case move.function
      when "ZUDStartGrassyTerrain";   terrain = :Grassy
      when "ZUDStartElectricTerrain"; terrain = :Electric
      when "ZUDStartMistyTerrain";    terrain = :Misty
      when "ZUDStartPsychicTerrain";  terrain = :Psychic
      end
      @battle.allSameSideBattlers(user.index).each do |b|
        score += 20 if b.affectedByTerrain?
        score += 20 if b.pbHasMove?(:TERRAINPULSE)
        case terrain
        when :Grassy
          score += 30 if b.pbHasMove?(:GRASSYGLIDE)
          score += 30 if b.hasActiveItem?(:GRASSYSEED)
          score += 30 if b.hasActiveAbility?(:GRASSPELT)
        when :Electric
          score += 30 if b.pbHasMove?(:RISINGVOLTAGE)
          score += 30 if b.hasActiveItem?(:ELECTRICSEED)
          score += 30 if b.hasActiveAbility?(:SURGESURFER)
          score += 40 if b.status == :SLEEP
        when :Misty
          score += 30 if b.pbHasMove?(:MISTYEXPLOSION)
          score += 30 if b.hasActiveItem?(:MISTYSEED)
        when :Psychic
          score += 30 if b.pbHasMove?(:EXPANDINGFORCE)
          score += 30 if b.hasActiveItem?(:PSYCHICSEED)
        end
      end
      @battle.allSameSideBattlers(target.index).each do |b|
        score -= 10 if b.affectedByTerrain?
        case terrain
        when :Grassy
          score += 30 if b.pbHasMove?(:EARTHQUAKE)
        when :Electric
          score -= 40 if b.status == :SLEEP
        when :Misty
          score += 30 if b.pbHasType?(:DRAGON)
        end
      end
    #---------------------------------------------------------------------------
    # Splintered Stormshards
    #---------------------------------------------------------------------------
    when "ZUDRemoveTerrain"
      if @battle.field.terrain == :None
        if move.statusMove?
          score -= 100
        else
          score -= 90
        end
      end
    #---------------------------------------------------------------------------
    # G-Max Stonesurge, G-Max Steelsurge
    #---------------------------------------------------------------------------
    when "ZUDAddStealthRocksToFoeSide", "ZUDAddSteelsurgeToFoeSide"
      effect = (move.function == "ZUDAddStealthRocksToFoeSide") ? PBEffects::StealthRock : PBEffects::Steelsurge
      if user.pbOpposingSide.effects[effect]
        score -= 90
      elsif user.allOpposing.none? { |b| @battle.pbCanChooseNonActive?(b.index) }
        score -= 90
      else
        score += 10 * @battle.pbAbleNonActiveCount(user.idxOpposingSide)
      end
    #---------------------------------------------------------------------------
    # G-Max Resonance
    #---------------------------------------------------------------------------
    when "ZUDStartAuroraVeilOnUserSide"
      if user.pbOwnSide.effects[PBEffects::AuroraVeil] > 0
        score -= 90
      else
        score += 40
      end
    #---------------------------------------------------------------------------
    # G-Max Wind Rage
    #---------------------------------------------------------------------------
    when "ZUDRemoveSideEffects"
      score += 30 if target.pbOwnSide.effects[PBEffects::AuroraVeil] > 0 ||
                     target.pbOwnSide.effects[PBEffects::Reflect] > 0 ||
                     target.pbOwnSide.effects[PBEffects::LightScreen] > 0 ||
                     target.pbOwnSide.effects[PBEffects::Mist] > 0 ||
                     target.pbOwnSide.effects[PBEffects::Safeguard] > 0
      score -= 30 if target.pbOwnSide.effects[PBEffects::Spikes] > 0 ||
                     target.pbOwnSide.effects[PBEffects::ToxicSpikes] > 0 ||
                     target.pbOwnSide.effects[PBEffects::StealthRock]
    #---------------------------------------------------------------------------
    # G-Max Vine Lash, G-Max Wildfire, G-Max Cannonade, G-Max Volcalith
    #---------------------------------------------------------------------------
    when "ZUDStartVineLashOnFoeSide", "ZUDStartWildfireOnFoeSide", 
         "ZUDStartCannonadeOnFoeSide", "ZUDStartVolcalithOnFoeSide"
      case move.function
      when "ZUDStartVineLashOnFoeSide";  effect = PBEffects::VineLash;  type = :GRASS
      when "ZUDStartWildfireOnFoeSide";  effect = PBEffects::Wildfire;  type = :FIRE
      when "ZUDStartCannonadeOnFoeSide"; effect = PBEffects::Cannonade; type = :WATER
      when "ZUDStartVolcalithOnFoeSide"; effect = PBEffects::Volcalith; type = :ROCK
      end
      if target.pbOwnSide.effects[effect] > 0
        score -= 90
      else
        @battle.allSameSideBattlers(target.index).each do |b|
          score -= 30 if b.pbHasType?(type)
        end
      end
    #---------------------------------------------------------------------------
    # Stoked Sparksurfer
    #---------------------------------------------------------------------------
    when "ZUDParalyzeTarget"
      if target.pbCanParalyze?(user, false)
        score += 30
        if skill >= PBTrainerAI.mediumSkill
          aspeed = pbRoughStat(user, :SPEED, skill)
          ospeed = pbRoughStat(target, :SPEED, skill)
          if aspeed < ospeed
            score += 30
          elsif aspeed > ospeed
            score -= 40
          end
        end
        if skill >= PBTrainerAI.highSkill
          score -= 40 if target.hasActiveAbility?([:GUTS, :MARVELSCALE, :QUICKFEET])
        end
      elsif skill >= PBTrainerAI.mediumSkill
        score -= 90 if move.statusMove?
      end
    #---------------------------------------------------------------------------
    # G-Max Volt Crash, G-Max Malodor, G-Max Stunshock, G-Max Befuddle
    #---------------------------------------------------------------------------
    when "ZUDParalyzeAllFoes", "ZUDPoisonAllFoes", 
         "ZUDPoisonOrParalyzeAllFoes", "ZUDPoisonParalyzeOrSleepAllFoes"
      case move.function
      when "ZUDPoisonAllFoes";                statuses = [:POISON]
      when "ZUDParalyzeAllFoes";              statuses = [:PARALYSIS]
      when "ZUDPoisonOrParalyzeAllFoes";      statuses = [:POISON, :PARALYSIS]
      when "ZUDPoisonParalyzeOrSleepAllFoes"; statuses = [:POISON, :PARALYSIS, :SLEEP]
      end
      @battle.allSameSideBattlers(target.index).each do |b|
        statuses.each do |status|
          case status
          when :POISON
            if b.pbCanPoison?(user, false)
              score += 30
              if skill >= PBTrainerAI.mediumSkill
                score += 30 if b.hp <= b.totalhp / 4
                score += 50 if b.hp <= b.totalhp / 8
                score -= 40 if b.effects[PBEffects::Yawn] > 0
              end
              if skill >= PBTrainerAI.highSkill
                score += 10 if pbRoughStat(b, :DEFENSE, skill) > 100
                score += 10 if pbRoughStat(b, :SPECIAL_DEFENSE, skill) > 100
                score -= 40 if b.hasActiveAbility?([:GUTS, :MARVELSCALE, :TOXICBOOST])
              end
            elsif skill >= PBTrainerAI.mediumSkill
              score -= 90 if move.statusMove?
            end
          when :PARALYSIS
            if b.pbCanParalyze?(user, false)
              score += 30
              if skill >= PBTrainerAI.mediumSkill
                aspeed = pbRoughStat(user, :SPEED, skill)
                ospeed = pbRoughStat(b, :SPEED, skill)
                if aspeed < ospeed
                  score += 30
                elsif aspeed > ospeed
                  score -= 40
                end
              end
              if skill >= PBTrainerAI.highSkill
                score -= 40 if b.hasActiveAbility?([:GUTS, :MARVELSCALE, :QUICKFEET])
              end
            elsif skill >= PBTrainerAI.mediumSkill
              score -= 90 if move.statusMove?
            end
          when :SLEEP
            if b.pbCanSleep?(user, false)
              score += 30
              if skill >= PBTrainerAI.mediumSkill
                score -= 30 if b.effects[PBEffects::Yawn] > 0
              end
              if skill >= PBTrainerAI.highSkill
                score -= 30 if b.hasActiveAbility?(:MARVELSCALE)
              end
              if skill >= PBTrainerAI.bestSkill
                if b.pbHasMoveFunction?("FlinchTargetFailsIfUserNotAsleep",
                                        "UseRandomUserMoveIfAsleep")
                  score -= 50
                end
              end
            elsif skill >= PBTrainerAI.mediumSkill
              score -= 90 if move.statusMove?
            end
          end
        end
      end
    #---------------------------------------------------------------------------
    # G-Max Snooze
    #---------------------------------------------------------------------------
    when "ZUDYawnTarget"
      if target.effects[PBEffects::Yawn] > 0 || !target.pbCanSleep?(user, false)
        score -= 90 if skill >= PBTrainerAI.mediumSkill
      else
        score += 30
        if skill >= PBTrainerAI.highSkill
          score -= 30 if target.hasActiveAbility?(:MARVELSCALE)
        end
        if skill >= PBTrainerAI.bestSkill
          if target.pbHasMoveFunction?("FlinchTargetFailsIfUserNotAsleep",
                                       "UseRandomUserMoveIfAsleep")
            score -= 50
          end
        end
      end
    #---------------------------------------------------------------------------
    # G-Max Smite, G-Max Goldrush
    #---------------------------------------------------------------------------
    when "ZUDConfuseAllFoes", "ZUDConfuseAllFoesAddMoney"
      @battle.allSameSideBattlers(target.index).each do |b|
        if b.pbCanConfuse?(user, false)
          score += 30
        elsif skill >= PBTrainerAI.mediumSkill
          score -= 90 if move.statusMove?
        end
      end
    #---------------------------------------------------------------------------
    # G-Max Cuddle
    #---------------------------------------------------------------------------
    when "ZUDInfatuateAllFoes"
      @battle.allSameSideBattlers(target.index).each do |b|
        canattract = true
        agender = user.gender
        ogender = b.gender
        if agender == 2 || ogender == 2 || agender == ogender
          score -= 90
          canattract = false
        elsif b.effects[PBEffects::Attract] >= 0
          score -= 80
          canattract = false
        elsif skill >= PBTrainerAI.bestSkill && b.hasActiveAbility?(:OBLIVIOUS)
          score -= 80
          canattract = false
        end
        if skill >= PBTrainerAI.highSkill
          if canattract && b.hasActiveItem?(:DESTINYKNOT) &&
             user.pbCanAttract?(b, false)
            score -= 30
          end
        end
      end
    #---------------------------------------------------------------------------
    # G-Max Meltdown
    #---------------------------------------------------------------------------
    when "ZUDTormentAllFoes"
      @battle.allSameSideBattlers(target.index).each do |b|
        score -= 90 if b.effects[PBEffects::Torment]
      end
    #---------------------------------------------------------------------------
    # G-Max Sweetness
    #---------------------------------------------------------------------------
    when "ZUDCureUserAndAlliesStatus"
      @battle.allSameSideBattlers(user.index).each do |b|
        case b.status
        when :POISON
          score += 40
          if skill >= PBTrainerAI.mediumSkill
            if b.hp < b.totalhp / 8
              score += 60
            elsif skill >= PBTrainerAI.highSkill &&
                  b.hp < (b.effects[PBEffects::Toxic] + 1) * b.totalhp / 16
              score += 60
            end
          end
        when :BURN, :PARALYSIS
          score += 40
        else
          score -= 90
        end
      end
    #---------------------------------------------------------------------------
    # G-Max Replenish
    #---------------------------------------------------------------------------
    when "ZUDRestoreUserAndAlliesConsumedBerry"
      @battle.allSameSideBattlers(user.index).each do |b|
        if b.recycleItem && GameData::Item.get(b.recycleItem).is_berry? && !b.item
          score += 60
        else
          score -= 80 if move.statusMove?
        end
      end
    #---------------------------------------------------------------------------
    # G-Max Finale
    #---------------------------------------------------------------------------
    when "ZUDHealUserAndAlliesOneSixthOfTotalHP"
      ally_amt = 30
      @battle.allSameSideBattlers(user.index).each do |b|
        if b.hp == b.totalhp || (skill >= PBTrainerAI.mediumSkill && !b.canHeal?)
          score -= ally_amt / 2
        elsif b.hp < b.totalhp * 3 / 4
          score += ally_amt
        end
      end
    #---------------------------------------------------------------------------
    # Guardian of Alola
    #---------------------------------------------------------------------------
    when "ZUDFixedDamage75PercentTargetHP"
      score -= 50
      score += target.hp * 100 / target.totalhp
    #---------------------------------------------------------------------------
    # G-Max Depletion
    #---------------------------------------------------------------------------
    when "ZUDLowerPPOfAllFoesLastMoveBy2"
      score -= 20
    #---------------------------------------------------------------------------
    # G-Max Terror
    #---------------------------------------------------------------------------
    when "ZUDTrapAllFoesInBattle"
      @battle.allSameSideBattlers(target.index).each do |b|
        score -= 90 if b.effects[PBEffects::MeanLook] >= 0
      end
    #---------------------------------------------------------------------------
    # G-Max Centiferno, G-Max Sandblast
    #---------------------------------------------------------------------------
    when "ZUDBindAllFoesUserCanSwitch"
      @battle.allSameSideBattlers(target.index).each do |b|
        score += 40 if b.effects[PBEffects::Trapping] == 0
      end
    #---------------------------------------------------------------------------
    # Searing Sunraze Smash, Menacing Moonraze Malestrom, Light That Burns the Sky,
    # G-Max Drum Solo, G-Max Fireball, G-Max Hydrosnipe
    #---------------------------------------------------------------------------
    when "ZUDIgnoreTargetAbility", "ZUDPhotonGeyser"
      score += 40 if target.hasActiveAbility?([:DISGUISE, :ICEFACE, :MULTISCALE, :STURDY, :WONDERGUARD])
    #---------------------------------------------------------------------------
    else
      return aiEffectScorePart3_pbGetMoveScoreFunctionCode(score, move, user, target, skill)
    end
    return score
  end
end