#===============================================================================
# The RaidBattle class, used for handling battle mechanics for raids.
#===============================================================================
class RaidBattle < Battle
  attr_reader :battlers
  attr_reader :hard_mode
  attr_reader :raid_battle
  
  def initialize(*arg)
    super(*arg)
    @raid_battle = true
    @hard_mode = $game_temp.dx_rules[:hard]
  end
  
  def pbRecordAndStoreCaughtPokemon
    @caughtPokemon.each do |pkmn|
      pbSetSeen(pkmn)
      pbStorePokemon(pkmn)
    end
    @caughtPokemon.clear
  end
  
  #-----------------------------------------------------------------------------
  # Raid Pokemon effects during the Attack Phase (before using a move).
  #-----------------------------------------------------------------------------
  def pbAttackPhaseRaidBoss
    pbPriority.each do |b|
      next unless b.effects[PBEffects::MaxRaidBoss]
      #-------------------------------------------------------------------------
      # Neutralizing Wave
      #-------------------------------------------------------------------------
      rand = pbRandom(10)
      if rand < 2 ||
         (b.status != :NONE && rand < 5) || 
         (b.effects[PBEffects::RaidShield] > 0 && rand < 4)
        neutralize = b.hp < b.totalhp - (b.totalhp / 5)
      else
        neutralize = false
      end
      if neutralize
        pbDisplay(_INTL("{1} released a neutralizing wave of Dynamax energy!", b.pbThis))
        @scene.pbWaveAttack(b.index)
        pbDisplay(_INTL("All stat increases and Abilities of your Pokémon were nullified!"))
        if b.status != :NONE
          b.pbCureStatus(false)
          pbDisplay(_INTL("{1}'s status returned to normal!", b.pbThis))
        end
        b.eachOpposing do |p|
          p.effects[PBEffects::GastroAcid] = true
          GameData::Stat.each_battle { |s| p.stages[s.id] = 0 if p.stages[s.id] > 0 }
        end
      end
      #-------------------------------------------------------------------------
      # Hard Mode Bonuses (Immobilizing Wave)
      #-------------------------------------------------------------------------
      if @hard_mode
        if b.effects[PBEffects::ShieldCounter] == -1 && b.effects[PBEffects::RaidShield] <= 0
          pbDisplay(_INTL("{1} released an immense wave of Dynamax energy!", b.pbThis))
          @scene.pbWaveAttack(b.index)
          b.eachOpposing do |p|  
            if p.effects[PBEffects::Dynamax] > 0
              pbDisplay(_INTL("{1} is unaffected!", p.pbThis))
            else
              pbDisplay(_INTL("The oppressive force immobilized {1}!", p.pbThis))
              p.effects[PBEffects::TwoTurnAttack] = nil
              pbClearChoice(p.index) if !p.movedThisRound?
            end
          end
          b.effects[PBEffects::ShieldCounter] -= 1
        end
      end
    end
  end
  
  #-----------------------------------------------------------------------------
  # Adds the Cheer command to the menu; replaces Run.
  #-----------------------------------------------------------------------------
  def pbCommandMenu(idxBattler, _firstAction)
    ret = @scene.pbCommandMenuEx(idxBattler,
                                [_INTL("What will\n{1} do?", @battlers[idxBattler].name),
                                 _INTL("Fight"),
                                 _INTL("Bag"),
                                 _INTL("Pokémon"),
                                 _INTL("Cheer")], 5)
    ret = 4 if ret == 3
    return ($DEBUG && Input.press?(Input::CTRL)) ? 3 : ret
  end
  
  #-----------------------------------------------------------------------------
  # Registers the Cheer command to be used during the Attack Phase.
  #-----------------------------------------------------------------------------
  def pbCallMenu(idxBattler)
    return pbRegisterCheer(idxBattler)
  end
  
  def pbRegisterCheer(idxBattler)
    @choices[idxBattler][0] = :Cheer
    @choices[idxBattler][1] = 0
    @choices[idxBattler][2] = nil
    return true
  end
  
  def pbAttackPhaseCheer
    pbPriority.each do |b|
      next unless @choices[b.index][0] == :Cheer && !b.fainted?
      b.lastMoveFailed = false # Counts as a successful move for Stomping Tantrum.
      pbCheer(b.index)
    end
  end

  #-----------------------------------------------------------------------------
  # Cheer command.
  #-----------------------------------------------------------------------------
  def pbCheer(idxBattler)
    rules       = $game_temp.dx_rules
    battler     = @battlers[idxBattler]
    boss        = battler.pbDirectOpposing(true)
    side        = battler.idxOwnSide
    owner       = pbGetOwnerIndexFromBattlerIndex(idxBattler)
    trainerName = pbGetOwnerName(idxBattler)
    dmaxInUse   = false
    eachSameSideBattler(battler) { |b| dmaxInUse = true if b.dynamax? }
    #---------------------------------------------------------------------------
    # Determines the possible Cheer effects.
    #---------------------------------------------------------------------------
    cheered = 0
    cheerEffects = {}
    player_losing = boss.effects[PBEffects::KnockOutCount] < 3 || boss.effects[PBEffects::Dynamax] < 5   
    #---------------------------------------------------------------------------
    # Counts the number of party members using Cheer this turn.
    #---------------------------------------------------------------------------
    eachSameSideBattler(battler) do |b|
      next if @choices[b.index][0] != :Cheer
      cheered += 1
    end
    case cheered
    when 0
      cheerEffects[:none] = true
    #---------------------------------------------------------------------------
    # Builds hash of possible Cheer effects for a single Cheer.
    #---------------------------------------------------------------------------
    # :reflect     => No Reflect and party size is 1 or Pokemon fainted.
    # :lightscreen => No Light Screen and party size is 1 or Pokemon fainted.
    # :shieldbreak => Raid Shield active and party size is 1 and turn count < 5.
    # :dynamax     => Dynamax used and party size is 1 and turn count < 5.
    # :heal        => Party Pokemon have low HP and party size is 1 and turn count < 5.
    # :none        => No above effects qualify and party size > 1.
    # :boost       => Always available.
    #---------------------------------------------------------------------------
    when 1
      if rules[:size] == 1 
        if boss.effects[PBEffects::Dynamax] < 10
          eachSameSideBattler(battler) do |b|
            cheerEffects[:heal] = true if b.hp <= b.totalhp / 2
            break if cheerEffects[:heal]
          end
        end
        if cheerEffects.empty? && boss.effects[PBEffects::Dynamax] < 5
          cheerEffects[:dynamax] = true if !dmaxInUse && @dynamax[side][owner] != -1
          cheerEffects[:shieldbreak] = true if boss.effects[PBEffects::RaidShield] > 1
        end
        if cheerEffects.empty?
          cheerEffects[:reflect] = true if battler.pbOwnSide.effects[PBEffects::Reflect] == 0
          cheerEffects[:lightscreen] = true if battler.pbOwnSide.effects[PBEffects::LightScreen] == 0
          cheerEffects[:boost] = true
        end
      else
        if !rules[:perfect_bonus]
          cheerEffects[:reflect] = true if battler.pbOwnSide.effects[PBEffects::Reflect] == 0
          cheerEffects[:lightscreen] = true if battler.pbOwnSide.effects[PBEffects::LightScreen] == 0
        end
        cheerEffects[:none] = true if cheerEffects.empty?
        cheerEffects[:boost] = true
      end
    #---------------------------------------------------------------------------
    # Builds hash of possible Cheer effects for a double Cheer.
    #---------------------------------------------------------------------------
    # :heal        => Party Pokemon have low HP and Pokemon fainted or turn count < 5.
    # :timer       => Party size > 2 and turn count is 1.
    # :shieldbreak => Raid Shield active and party size is 2 and Pokemon fainted or turn count < 5.
    # :dynamax     => Dynamax used and party size is 2 and Pokemon fainted or turn count < 5.
    # :boost       => No above effects qualify.
    #---------------------------------------------------------------------------
    when 2
      if !rules[:perfect_bonus] || boss.effects[PBEffects::Dynamax] < 5
        eachSameSideBattler(battler) do |b|
          cheerEffects[:heal] = true if b.hp <= b.totalhp / 2
          break if cheerEffects[:heal]
        end
      end
      if rules[:size] > 2 && boss.effects[PBEffects::Dynamax] == 1
        cheerEffects[:timer] = true
      end
      if rules[:size] == 2 && (!rules[:perfect_bonus] || boss.effects[PBEffects::Dynamax] < 5)
        cheerEffects[:shieldbreak] = true if boss.effects[PBEffects::RaidShield] > 0
        cheerEffects[:dynamax] = true if !dmaxInUse && @dynamax[side][owner] != -1
      end
      cheerEffects[:boost] = true if cheerEffects.empty?
    #---------------------------------------------------------------------------
    # Builds hash of possible Cheer effects for a triple+ Cheer.
    #---------------------------------------------------------------------------
    # :shieldbreak => Raid Shield active and Pokemon fainted.
    # :dynamax     => Dynamax used and Pokemon fainted.
    # :kocount     => KO count is 1.
    # :heal        => No above effects qualify and party Pokemon have low HP.
    # :boost       => No above effects qualify.
    #---------------------------------------------------------------------------
    else
      if !rules[:perfect_bonus] || boss.effects[PBEffects::Dynamax] < 5
	    cheerEffects[:shieldbreak] = true if boss.effects[PBEffects::RaidShield] > 0
        cheerEffects[:dynamax] = true if !dmaxInUse && @dynamax[side][owner] != -1
      end
      cheerEffects[:kocount] = true if boss.effects[PBEffects::KnockOutCount] == 1 && !inMaxLair?
      if cheerEffects.empty?
        eachSameSideBattler(battler) do |b|
          cheerEffects[:heal] = true if b.hp <= b.totalhp / 2
          break if cheerEffects[:heal]
        end
      end
      cheerEffects[:boost] = true if cheerEffects.empty?
    end
    #---------------------------------------------------------------------------
    # Chooses a random Cheer effect and displays Cheer messages.
    #---------------------------------------------------------------------------
    partyPriority = []
    pbPriority.each do |b|
      next if b.opposes?
      next if @choices[b.index][0] != :Cheer
      partyPriority.push(b)
    end
    randeffect = cheerEffects.keys.to_a.sample
    pbDisplay(_INTL("{1} cheered for {2}!", trainerName, battler.pbThis(true)))
    pbAnimation(:ENCORE, battler, battler)
    if ![:none, :dynamax].include?(randeffect)
      if battler == partyPriority.first
        pbDisplay(_INTL("{1}'s cheering was powered up by all the Dynamax Energy!", trainerName))
      else
        pbDisplay(_INTL("{1}'s continuous cheering grew in power!", trainerName))
      end
    end
    case randeffect
    #---------------------------------------------------------------------------
    # No effect.
    #---------------------------------------------------------------------------
    when :none
      pbDisplay(_INTL("The cheer echoed feebly around the area..."))
    #---------------------------------------------------------------------------
    # Applies Reflect on the user's side.
    #---------------------------------------------------------------------------
    when :reflect
      pbAnimation(:REFLECT, battler, battler)
      battler.pbOwnSide.effects[PBEffects::Reflect] = 5
      pbDisplay(_INTL("Reflect raised {1}'s Defense!", battler.pbTeam(true)))
    #---------------------------------------------------------------------------
    # Applies Light Screen to the user's side.
    #---------------------------------------------------------------------------
    when :lightscreen
      pbAnimation(:LIGHTSCREEN, battler, battler)
      battler.pbOwnSide.effects[PBEffects::LightScreen] = 5
      pbDisplay(_INTL("Light Screen raised {1}'s Special Defense!", battler.pbTeam(true)))
    #---------------------------------------------------------------------------
    # Restores the HP and status of each ally Pokemon.
    # Only eligible when at least one party member is at or below 50% HP.
    # Triggers after the final Cheer of this round.
    #---------------------------------------------------------------------------
    when :heal
      if battler == partyPriority.last
        eachSameSideBattler(battler) do |b|
          if b.hp < b.totalhp
            b.pbRecoverHP(b.totalhp)
            pbDisplay(_INTL("{1}'s HP was restored.", b.pbThis))
          end
          b.pbCureStatus
        end
      end
    #---------------------------------------------------------------------------
    # Raises a random stat for each ally Pokemon.
    # The number of stages raised is based on how many Cheers were used.
    # Triggers after the final Cheer of this round.
    #---------------------------------------------------------------------------
    when :boost
      if battler == partyPriority.last
        eachSameSideBattler(battler) do |b|
          stat = [:ATTACK, :DEFENSE, :SPEED, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :ACCURACY, :EVASION].sample
          if b.pbCanRaiseStatStage?(stat, b, nil, true)
            b.pbRaiseStatStage(stat, cheered, b, true, true)
          end
        end
      end
    #---------------------------------------------------------------------------
    # Increases the raid timer by 1 additional turn.
    # Triggers after the final Cheer of this round.
    #---------------------------------------------------------------------------
    when :timer
      if battler == partyPriority.last
        boss.effects[PBEffects::Dynamax] += 1
        pbDisplay(_INTL("{1} seemed distracted by all your cheering!", battler.pbThis(true)))
        @scene.pbRefresh
        pbSEPlay(sprintf("Anim/Lucky Chant"))
        pbDisplay(_INTL("You bought yourself an extra turn in the raid!"))
      end
    #---------------------------------------------------------------------------
    # Increases the raid KO counter by 1 additional KO.
    # Triggers after the final Cheer of this round.
    #---------------------------------------------------------------------------
    when :kocount
      if battler == partyPriority.last
        boss.effects[PBEffects::KnockOutCount] += 1
        pbDisplay(_INTL("{1} seemed distracted by all your cheering!", battler.pbThis(true)))
        @scene.pbRefresh
        pbSEPlay(sprintf("Anim/Lucky Chant"))
        pbDisplay(_INTL("The storm raging around {1} calmed down a bit!", battler.pbThis(true)))
      end
    #---------------------------------------------------------------------------
    # Removes the Raid Pokemon's shield.
    # Only eligible when the Max Raid Pokemon has active shields.
    # Triggers after the final Cheer of this round.
    #---------------------------------------------------------------------------
    when :shieldbreak
      if battler == partyPriority.last
        @scene.pbDamageAnimation(boss)
        boss.effects[PBEffects::RaidShield] = 0
        @scene.pbRefresh
        @scene.pbRaidShield(boss)
        pbDisplay(_INTL("The mysterious barrier disappeared!"))
        oldhp    = boss.hp
        boss.hp -= boss.totalhp / 8
        boss.hp  = 1 if boss.hp <= 1
        @scene.pbHPChanged(boss, oldhp)
        if boss.hp > 1
          [:DEFENSE, :SPECIAL_DEFENSE].each do |stat|
            if boss.pbCanLowerStatStage?(stat, boss, nil, true)
              boss.pbLowerStatStage(stat, 2, boss, true, false, 0, true)
            end
          end
        end
      end
    #---------------------------------------------------------------------------
    # Replenishes the player's ability to Dynamax.
    # Only eligible if Dynamax has already been used.
    # Triggers after the final Cheer of this round.
    #---------------------------------------------------------------------------
    when :dynamax
      item = pbGetDynamaxBandName(battler.index)
      case battler
      # Last Cheer user.
      when partyPriority.last
        pbSetBattleMechanicUsage(battler.index, "Dynamax", -1)
        pbSEPlay(sprintf("Anim/Lucky Chant"))
        pbDisplayPaused(_INTL("The absorbed Dynamax energy fully recharged {1}'s {2}!\n{1} can use Dynamax again!", trainerName, item))
      # First Cheer user.
      when partyPriority.first
        pbDisplay(_INTL("{1}'s {2} absorbed a little of the surrounding Dynamax Energy!", trainerName, item))
      # All other Cheer users.
      else
        pbDisplay(_INTL("{1}'s {2} absorbed even more of the surrounding Dynamax Energy!", trainerName, item))
      end
    end
  end
end


#===============================================================================
# Adds a command menu configuration to display the "Cheer" command.
#===============================================================================
class Battle::Scene::CommandMenu < Battle::Scene::MenuBase
  MODES += [[0, 2, 1, 10]] # Fight, Bag, Pokemon, Cheer
end

class Battle::Scene::TargetMenu < Battle::Scene::MenuBase
  MODES += [[0, 2, 1, 10]] # Fight, Bag, Pokemon, Cheer
end


#===============================================================================
# End of Round additions.
#===============================================================================
class Battle
  #-----------------------------------------------------------------------------
  # End of round checks for raid Pokemon.
  #-----------------------------------------------------------------------------
  def raid_EndOfRound(battler)
    if battler.effects[PBEffects::MaxRaidBoss] && battler.effects[PBEffects::KnockOutCount] > 0
      #-------------------------------------------------------------------------
      # Tracks Raid Reward bonuses.
      #-------------------------------------------------------------------------
      $game_temp.dx_rules[:timer_bonus] = battler.effects[PBEffects::Dynamax]
      battler.eachOpposing do |opp|
        $game_temp.dx_rules[:fairness_bonus] = false if opp.level >= battler.level + 5
      end
      #-------------------------------------------------------------------------
      # The Raid Pokemon starts using Max Moves once final round of shields trigger.
      #-------------------------------------------------------------------------
      if battler.base_moves.empty? && battler.effects[PBEffects::ShieldCounter] <= 0
        battler.display_power_moves("Max Move") 
      end
      #-------------------------------------------------------------------------
      # Raid Shield thresholds for effect damage.
      #-------------------------------------------------------------------------
      if battler.effects[PBEffects::RaidShield] <= 0 && battler.hp > 1
        shields1 = battler.hp <= battler.totalhp / 2                    # Activates at 1/2 HP
        shields2 = battler.hp <= battler.totalhp - battler.totalhp / 5  # Activates at 4/5ths HP
        if (battler.effects[PBEffects::ShieldCounter] == 1 && shields1) ||
           (battler.effects[PBEffects::ShieldCounter] == 2 && shields2)
          pbDisplay(_INTL("{1} is getting desperate!\nIts attacks are growing more aggressive!", battler.pbThis))
          battler.effects[PBEffects::RaidShield] = battler.effects[PBEffects::MaxShieldHP]
          battler.effects[PBEffects::ShieldCounter] -= 1
          pbAnimation(:REFLECT, battler, battler)
          @scene.pbRaidShield(battler)
          @scene.pbRefresh
          pbDisplay(_INTL("A mysterious barrier appeared in front of {1}!", battler.pbThis(true)))
        end
      end
      #-------------------------------------------------------------------------
      # Hard Mode Bonuses (HP Regeneration).
      #-------------------------------------------------------------------------
      if @hard_mode
        if battler.effects[PBEffects::RaidShield] > 0 && 
           battler.effects[PBEffects::HealBlock] == 0 && 
           battler.hp < battler.totalhp && battler.hp > 1
          battler.ignore_dynamax = true
          battler.pbRecoverHP((battler.totalhp / 16).floor)
          pbDisplay(_INTL("{1} regenerated a little HP behind the mysterious barrier!", battler.pbThis))
        end
      end
    end
  end
  
  #-----------------------------------------------------------------------------
  # End of round checks for raid battles.
  #-----------------------------------------------------------------------------
  def raid_EndOfRound2(battler)
    if battler.effects[PBEffects::MaxRaidBoss] && battler.effects[PBEffects::KnockOutCount] > 0
      #-------------------------------------------------------------------------
      # Ends raid if timer expires.
      #-------------------------------------------------------------------------
      if battler.effects[PBEffects::Dynamax] <= 0
        @scene.pbRefresh
        pbDisplayPaused(_INTL("The storm around {1} grew out of control!", battler.pbThis(true)))
        pbDisplay(_INTL("You were blown out of the den!"))
        pbSEPlay("Battle flee")
        @decision = 3
        pbDynamaxAdventure.knockouts = 0 if inMaxLair?
      else
        #-----------------------------------------------------------------------
        # Revives any fainted Pokemon in the party at the end of each turn.
        #-----------------------------------------------------------------------
        for i in pbParty(0)
          if i.fainted?
            i.heal
            pbSEPlay(sprintf("Anim/Lucky Chant"))
            pbDisplayPaused(_INTL("{1} recovered from fainting!\nIt can be sent back out next turn!", i.name))
          end
        end
        @scene.pbRefresh
      end
    end
  end
  
  def raid_ResetPokemon(pkmn)
    pkmn.dynamax = false
    pkmn.calc_stats
    pkmn.reversion = false
    if pkmn.dynamax_lvl > 10
      pkmn.dynamax_lvl /= 10
      pkmn.dynamax_lvl += rand(5)
      pkmn.dynamax_lvl = 10 if pkmn.dynamax_lvl > 10
    end
  end
end


#===============================================================================
# Upon capturing a Dynamaxed Pokemon.
#===============================================================================
module Battle::CatchAndStoreMixin
  alias zud_pbStorePokemon pbStorePokemon
  def pbStorePokemon(pkmn)
    if pkmn.isSpecies?(:ETERNATUS) || !pkmn.dynamax_able?
      pkmn.gmax_factor = false
      pkmn.dynamax_lvl = 0
    end
    if inMaxLair?
	  raid_ResetPokemon(pkmn)
      pkmn.heal
      pbDynamaxAdventure.add_prize(pkmn)
      pbDisplay(_INTL("Caught {1}!", pkmn.name))
      pbDynamaxAdventure.swap_pokemon
    elsif @raid_battle
	  raid_ResetPokemon(pkmn)
      pkmn.heal
      pkmn.reset_moves
      stored_box = $PokemonStorage.pbStoreCaught(pkmn)
      box_name = @peer.pbBoxName(stored_box)
      pbDisplayPaused(_INTL("{1} has been sent to Box \"{2}\"!", pkmn.name, box_name))
    else
      zud_pbStorePokemon(pkmn)
    end
  end
end