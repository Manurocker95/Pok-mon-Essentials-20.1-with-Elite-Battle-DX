#===============================================================================
# New Evolution methods
#===============================================================================
GameData::Evolution.register({
  :id            => :LevelUseMoveCount,
  :parameter     => :Move,
  :minimum_level        => 1,   # Needs any level up
  :level_up_proc        => proc { |pkmn, parameter|
    next pkmn.get_move_count(parameter) >= 20
  },
})
GameData::Evolution.register({
  :id            => :LevelWithPartner,
  :parameter     => Integer,
  :level_up_proc        => proc { |pkmn, parameter|
    next pkmn.level >= parameter && $PokemonGlobal.partner
  },
})
GameData::Evolution.register({
  :id            => :Walk,
  :parameter     => Integer,
  :minimum_level        => 1,   # Needs any level up
  :level_up_proc        => proc { |pkmn, parameter|
    next pkmn.step_count && pkmn.step_count >= parameter
  },
})
GameData::Evolution.register({
  :id            => :CollectItems,
  :parameter     => :Item,
  :minimum_level => 1,   # Needs any level up
  :level_up_proc => proc { |pkmn, parameter|
    next $bag.quantity(parameter) >= 999
  }
})
GameData::Evolution.register({
  :id            => :LevelDefeatItsKindWithItem,
  :parameter     => :Item,
  :minimum_level        => 1,   # Needs any level up
  :level_up_proc        => proc { |pkmn, parameter|
    next pkmn.defeated_species && pkmn.defeated_species(pkmn.species) >= 3
  },
})
GameData::Evolution.register({
  :id            => :LevelRecoilDamage,
  :parameter     => Integer,
  :minimum_level        => 1,   # Needs any level up
  :level_up_proc        => proc { |pkmn, parameter|
    next pkmn.recoil_dmg_taken && pkmn.recoil_dmg_taken >= parameter
  },
})
#===============================================================================
# Multiple forms and Regional forms Handler
#===============================================================================
MultipleForms.register(:TAUROS, {
  "getFormOnEggCreation" => proc { |pkmn|
    if $game_map
      map_pos = $game_map.metadata&.town_map_position
      if map_pos && map_pos[0] == 1
        # for now tauros rare breed only able to encountered 10%
        if rand(100) < 10
          next rand(2)+2
        else
          next 1
        end
      end
    end
    next 0
  }
})

MultipleForms.copy(:RATTATA,:WOOPER,:QUILAVA,:DEWOTT,:PETILIL,:RUFFLET,:GOOMY,:BERGMITE,:DARTRIX)

MultipleForms.register(:LECHONK, {
  "getFormOnCreation" => proc { |pkmn|
    next pkmn.gender
  }
})

MultipleForms.copy(:LECHONK,:OINKOLOGNE)

MultipleForms.register(:BASCULEGION, {
  "getForm" => proc { |pkmn|
    next pkmn.gender
  },

  "getFormOnCreation" => proc { |pkmn|
    next pkmn.gender
  }
})

MultipleForms.register(:TANDEMAUS, {
  "getFormOnCreation" => proc { |pkmn|
    next (pkmn.personalID % 100 == 0) ? 1 : 0
  }
})
MultipleForms.copy(:TANDEMAUS,:MAUSHOLD,:DUNSPARCE,:DUDUNSPARCE)

MultipleForms.register(:SQWARKABILLY, {
  "getFormOnCreation" => proc { |pkmn|
    next rand(4)
  }
})
#===============================================================================
# Pokemon Attribute
#===============================================================================
class Pokemon
  attr_reader :used_move_count, :step_count, :defeated_species, :recoil_dmg_taken, :size
  def use_move(move,qty=1)
    @used_move_count = {} if !@used_move_count
    @used_move_count[move] = 0 if !@used_move_count[move]
    @used_move_count[move] += qty
  end
  def get_move_count(move)
    @used_move_count = {} if !@used_move_count
    @used_move_count[move] = 0 if !@used_move_count[move]
    return @used_move_count[move]
  end
  def add_step(i=1)
    @step_count = 0 if !@step_count
    @step_count += i
  end
  def add_defeated_species(species,qty=1)
    @defeated_species = {} if !@defeated_species
    @defeated_species[species] = 0 if !@defeated_species[species]
    @defeated_species[species] += qty
  end
  def defeated_species(species)
    @defeated_species = {} if !@defeated_species
    @defeated_species[species] = 0 if !@defeated_species[species]
    return @defeated_species[species]
  end
  def add_recoil_dmg_taken(qty=1)
    @recoil_dmg_taken = 0 if !@recoil_dmg_taken
    @recoil_dmg_taken += qty
  end
end

# Defeated species method for bisharp
class Battle
  alias bisharp_pbSetDefeated pbSetDefeated
  def pbSetDefeated(battler)
    return if !battler || !@internalBattle
    # echoln [@lastMoveUser,battler.lastAttacker,battler.lastFoeAttacker,battler.lastHPLostFromFoe]
    return if battler.lastAttacker.empty?
    attacker = @battlers[battler.lastAttacker[0]]
    evo = GameData::Species.get_species_form(attacker.species,attacker.form).get_evolutions
    evo.each{|e|
      case e[1]
      when :LevelDefeatItsKindWithItem
        next if battler.item != e[2]
        next if battler.species != attacker.species
        attacker.pokemon.add_defeated_species(battler.species)
      end
    }
    bisharp_pbSetDefeated(battler)
  end
end

# Walk method for pawmo, rellor, and bramblin
EventHandlers.add(:on_player_step_taken, :gain_steps,
  proc {
    $player.able_party.each_with_index do |pkmn,i|
      pkmn.add_step
      break
    end
  }
)

#===============================================================================
# Tandemaus skipping evolution scene
#===============================================================================
# Add a skiping animation for tandemaus if it level up but not participate in a battle
GameData::Evolution.register({
  :id                => :BattleLevelSkipEvoScene,
  :parameter         => Integer,
  :after_battle_proc => proc { |pkmn, party_index, parameter|
    next pkmn.level >= parameter
  }
})

class Pokemon
  def get_evolution_method(new_species)
    species_data.get_evolutions(true).each do |evo|   # [new_species, method, parameter, boolean]
      next if evo[3]   # Prevolution
      # ret = yield self, evo[0], evo[1], evo[2]   # pkmn, new_species, method, parameter
      return evo[1] if new_species == evo[0]
    end
  end
end

def pbEvolutionCheck
  $player.party.each_with_index do |pkmn, i|
    next if !pkmn || pkmn.egg?
    next if pkmn.fainted? && !Settings::CHECK_EVOLUTION_FOR_FAINTED_POKEMON
    # Find an evolution
    new_species = nil
    if new_species.nil? && $game_temp.party_levels_before_battle &&
       $game_temp.party_levels_before_battle[i] &&
       $game_temp.party_levels_before_battle[i] < pkmn.level
      new_species = pkmn.check_evolution_on_level_up
    end
    new_species = pkmn.check_evolution_after_battle(i) if new_species.nil?
    next if new_species.nil?
    # Evolve Pokémon if possible
    if pkmn.get_evolution_method(new_species) == :BattleLevelSkipEvoScene && !$game_temp.party_levelUpAndPartic[i]
      # Check for consumed item and check if Pokémon should be duplicated
      pkmn.action_after_evolution(new_species)
      # Modify Pokémon to make it evolved
      pkmn.species = new_species
      pkmn.calc_stats
      pkmn.ready_to_evolve = false
      # See and own evolved species
      was_owned = $player.owned?(new_species)
      $player.pokedex.register(pkmn)
      $player.pokedex.set_owned(new_species)
      moves_to_learn = []
      movelist = pkmn.getMoveList
      movelist.each do |i|
        next if i[0] != 0 && i[0] != pkmn.level   # 0 is "learn upon evolution"
        moves_to_learn.push(i[1])
      end
      # Learn moves upon evolution for evolved species
      moves_to_learn.each do |move|
        pbLearnMove(@pokemon, move, true) { pbUpdate }
      end
    else
      evo = PokemonEvolutionScene.new
      evo.pbStartScreen(pkmn, new_species)
      evo.pbEvolution
      evo.pbEndScreen
    end
  end
end

class Battle
  alias tandemaus_pbGainExpOne pbGainExpOne
  def pbGainExpOne(idxParty, defeatedBattler, numPartic, expShare, expAll, showMessages = true)
    pkmn = pbParty(0)[idxParty]   # The Pokémon gaining Exp from defeatedBattler
    isPartic = defeatedBattler.participants.include?(idxParty)
    oldlevel = pkmn.level
    tandemaus_pbGainExpOne(idxParty, defeatedBattler, numPartic, expShare, expAll, showMessages)
    if pkmn.level > oldlevel && isPartic
      $game_temp.party_levelUpAndPartic[idxParty] = true
    end
  end
end
#-------------------------------------------------------------------------------
# New Temp Parameter
#-------------------------------------------------------------------------------
class Game_Temp
  attr_accessor :party_levelUpAndPartic
end

EventHandlers.add(:on_start_battle, :record_party_levelUpAndPartic,
  proc {
    $game_temp.party_levelUpAndPartic = []
    $player.party.each_with_index do |pkmn, i|
      $game_temp.party_levelUpAndPartic[i] = false
    end
  }
)
# Clear the hit count after the battle end
EventHandlers.add(:on_end_battle, :rage_hit_clear,
  proc { |decision, canLose| 
    $game_temp.party_levelUpAndPartic = []
  }
)