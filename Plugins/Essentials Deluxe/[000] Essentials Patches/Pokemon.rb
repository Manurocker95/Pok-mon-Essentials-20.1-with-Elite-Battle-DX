#===============================================================================
# Revamps miscellaneous bits of Essentials code related to Pokemon and species.
#===============================================================================


#-------------------------------------------------------------------------------
# Pokemon data.
#-------------------------------------------------------------------------------
class Pokemon
  def ace?; return @trainer_ace || false; end
  def ace=(value); @trainer_ace = value;  end
  
  def scale; return @scale || 100; end
  def scale=(value); @scale = value.clamp(0, 255); end
  
  def name_title; return self.name; end
  
  alias dx_baseStats baseStats
  def baseStats
    base_stats = dx_baseStats
    form_stats = MultipleForms.call("baseStats", self)
    form_stats = celestial_data["BaseStats"] if celestial?
    return form_stats || base_stats
  end
  
  alias dx_initialize initialize  
  def initialize(*args)
    dx_initialize(*args)
    @trainer_ace = false
    @scale = rand(256)
  end
  
  # Compatibility across multiple plugins.
  def dynamax?;   return false; end
  def gmax?;      return false; end
  def tera?;      return false; end
  def celestial?; return false; end
  
  # All-in-one attribute checker.
  def check_for_attribute(attribute, value)
    case attribute
    when :level     then return level == value
    when :form      then return form == value
    when :pokerus   then return pokerusStage == value
    when :ball      then return @poke_ball == value
    when :teratype  then return tera_type == value
    when :focus     then return focus_id == value
    when :shiny     then return (value) ? shiny? : !shiny?
    when :shadow    then return (value) ? shadowPokemon? : !shadowPokemon?
    when :hatched   then return (value) ? !timeEggHatched.nil? : !timeEggHatched
    when :foreign   then return (value) ? foreign? : !foreign?
    when :gmax      then return (value) ? gmax_factor? : !gmax_factor?
    when :blessed   then return (value) ? blessed? : !blessed?
    when :celestial then return (value) ? celestial? : !celestial?
    when :gender    then return (value == 1) ? female? : male?
    when :item      then return hasItem?(value)
    when :move      then return hasMove?(value)
    when :ribbon    then return hasRibbon?(value)
    when :nature    then return hasNature?(value)
    when :ability   then return hasAbility?(value)
    when :birthsign then return hasBirthsign?(value)
    else return true
    end
  end
end


#-------------------------------------------------------------------------------
# Returns the number of Pokemon owned that match the entered criteria.
#-------------------------------------------------------------------------------
def pbNumOwnedSpecies(species = nil, attribute = nil, value = nil)
  count = 0
  pbEachNonEggPokemon { |p|
    next unless species.nil? || p&.isSpecies?(species)
    next if !p.check_for_attribute(attribute, value)
    count += 1  
  }
  return count
end


#-------------------------------------------------------------------------------
# Gets all eligible moves that a species's entire evolutionary line can learn.
#-------------------------------------------------------------------------------
module GameData
  class Species
    def get_family_moves
      moves = []
      baby = GameData::Species.get_species_form(get_baby_species, @form)
      prev = GameData::Species.get_species_form(get_previous_species, @form)
      if baby.species != @species
        baby.moves.each { |m| moves.push(m[1]) }
      end
      if prev.species != @species && prev.species != baby.species
        prev.moves.each { |m| moves.push(m[1]) }
      end
      @moves.each { |m| moves.push(m[1]) }
      @tutor_moves.each { |m| moves.push(m) }
      get_egg_moves.each { |m| moves.push(m) }
      moves |= []
      return moves
    end
  end
end


#-------------------------------------------------------------------------------
# Adds Ultra Space habitat for Ultra Beasts.
#-------------------------------------------------------------------------------
GameData::Habitat.register({
  :id   => :UltraSpace,
  :name => _INTL("Ultra Space")
})


#-------------------------------------------------------------------------------
# Orders Egg Groups numerically, including Legendary groups.
#-------------------------------------------------------------------------------
def egg_group_hash
  data ={
    :Monster      => 0,
    :Water1       => 1,
    :Bug          => 2,
    :Flying       => 3,
    :Field        => 4,
    :Fairy        => 5,
    :Grass        => 6,
    :Humanlike    => 7,
    :Water3       => 8,
    :Mineral      => 9,
    :Amorphous    => 10,
    :Water2       => 11,
    :Ditto        => 12,
    :Dragon       => 13,
    :Undiscovered => 14,
    :Skycrest     => 15,
    :Bestial      => 16,
    :Titan        => 17,
    :Overlord     => 18,
    :Nebulous     => 19,
    :Enchanted    => 20,
    :Ancestor     => 21,
    :Ultra        => 22,
    :Unused1      => 23,
    :Unused2      => 24,
    :Unknown      => 25
  }
  return data
end


#-------------------------------------------------------------------------------
# Rewrites Egg Generator to include plugin mechanics.
#-------------------------------------------------------------------------------
class DayCare
  module EggGenerator
    module_function
    
    def generate(mother, father)
      if mother.male? || father.female? || mother.genderless?
        mother, father = father, mother
      end
      mother_data = [mother, fluid_egg_group?(mother.species_data.egg_groups)]
      father_data = [father, fluid_egg_group?(father.species_data.egg_groups)]
      species_parent = (mother_data[1]) ? father : mother
      baby_species = determine_egg_species(species_parent.species, mother, father)
      mother_data.push(mother.species_data.breeding_can_produce?(baby_species))
      father_data.push(father.species_data.breeding_can_produce?(baby_species))
      egg = generate_basic_egg(baby_species)
      inherit_form(egg, species_parent, mother_data, father_data)
      inherit_nature(egg, mother, father)
      inherit_ability(egg, mother_data, father_data)
      inherit_moves(egg, mother_data, father_data)
      inherit_IVs(egg, mother, father)
      inherit_poke_ball(egg, mother_data, father_data)
      inherit_birthsign(egg, mother, father) if PluginManager.installed?("Pokémon Birthsigns")
      set_shininess(egg, mother, father)
      set_pokerus(egg)
      egg.calc_stats
      return egg
    end
  end
end

def fluid_egg_group?(groups)
  return groups.include?(:Ditto) || groups.include?(:Ancestor)
end

def legendary_egg_group?(groups)
  egg_groups = egg_group_hash
  return egg_groups[groups[0]] > 13 || (groups[1] && egg_groups[groups[1]] > 13)
end


#-------------------------------------------------------------------------------
# Fixes to allow certain forms to be generated for wild battles without being
# prompted to learn an exclusive move. (Moves are instead taught automatically)
#-------------------------------------------------------------------------------
# Rotom forms.
#-------------------------------------------------------------------------------
MultipleForms.register(:ROTOM, {
  "onSetForm" => proc { |pkmn, form, oldForm|
    form_moves = [
      :OVERHEAT,
      :HYDROPUMP,
      :BLIZZARD,
      :AIRSLASH,
      :LEAFSTORM
    ]
    old_move_index = -1
    pkmn.moves.each_with_index do |move, i|
      next if !form_moves.include?(move.id)
      old_move_index = i
      break
    end
    new_move_id = (form > 0) ? form_moves[form - 1] : nil
    new_move_id = nil if !GameData::Move.exists?(new_move_id)
    if $game_temp.dx_pokemon? || $game_temp.dx_midbattle?
	  next if form == 0 && old_move_index == -1
      new_move_id = :SHADOWBALL if !new_move_id
      old_move_index = pkmn.moves.length - 1 if old_move_index < 0
      pkmn.moves[old_move_index].id = new_move_id
      next
    end
    if new_move_id.nil? && old_move_index >= 0 && pkmn.numMoves == 1
      new_move_id = :THUNDERSHOCK
      new_move_id = nil if !GameData::Move.exists?(new_move_id)
      raise _INTL("Rotom is trying to forget its last move, but there isn't another move to replace it with.") if new_move_id.nil?
    end
    new_move_id = nil if pkmn.hasMove?(new_move_id)
    if old_move_index >= 0
      old_move_name = pkmn.moves[old_move_index].name
      if new_move_id.nil?
        pkmn.forget_move_at_index(old_move_index)
        pbMessage(_INTL("{1} forgot {2}...", pkmn.name, old_move_name))
      else
        pkmn.moves[old_move_index].id = new_move_id
        new_move_name = pkmn.moves[old_move_index].name
        pbMessage(_INTL("{1} forgot {2}...\1", pkmn.name, old_move_name))
        pbMessage(_INTL("\\se[]{1} learned {2}!\\se[Pkmn move learnt]\1", pkmn.name, new_move_name))
      end
    elsif !new_move_id.nil?
      pbLearnMove(pkmn, new_move_id, true)
    end
  }
})

#-------------------------------------------------------------------------------
# Necrozma forms.
#-------------------------------------------------------------------------------
MultipleForms.register(:NECROZMA, {
  "getFormOnLeavingBattle" => proc { |pkmn, battle, usedInBattle, endBattle|
    next pkmn.form - 2 if pkmn.form >= 3 && (pkmn.fainted? || endBattle)
  },
  "onSetForm" => proc { |pkmn, form, oldForm|
    next if form > 2 || oldForm > 2
    form_moves = [
      :SUNSTEELSTRIKE,
      :MOONGEISTBEAM
    ]
    inBattle = $game_temp.dx_pokemon? || $game_temp.dx_midbattle?
    if form == 0
      form_moves.each do |move|
        next if !pkmn.hasMove?(move)
        pkmn.forget_move(move)
        pkmn.learn_move(:PSYCHIC) if inBattle
        pbMessage(_INTL("{1} forgot {2}...", pkmn.name, GameData::Move.get(move).name)) if !inBattle
      end
      pbLearnMove(pkmn, :CONFUSION) if pkmn.numMoves == 0 && !inBattle
    else
      new_move_id = form_moves[form - 1]
      if inBattle
        old_move_index = -1
        pkmn.moves.each_with_index do |move, i|
          next if !form_moves.include?(move.id)
          old_move_index = i
          break
        end
        old_move_index = pkmn.moves.length - 1 if old_move_index < 0
        pkmn.moves[old_move_index].id = new_move_id
      else
        pbLearnMove(pkmn, new_move_id, true)
      end
    end
  }
})

#-------------------------------------------------------------------------------
# Calyrex forms.
#-------------------------------------------------------------------------------
MultipleForms.register(:CALYREX, {
  "onSetForm" => proc { |pkmn, form, oldForm|
    form_moves = [
      :GLACIALLANCE,
      :ASTRALBARRAGE
    ]
    inBattle = $game_temp.dx_pokemon? || $game_temp.dx_midbattle?
    if form == 0
      form_moves.each do |move|
        next if !pkmn.hasMove?(move)
        pkmn.forget_move(move)
        pkmn.learn_move(:PSYCHIC) if inBattle
        pbMessage(_INTL("{1} forgot {2}...", pkmn.name, GameData::Move.get(move).name)) if !inBattle
      end
      sp_data = pkmn.species_data
      pkmn.moves.each_with_index do |move, i|
        next if sp_data.moves.any? { |learn_move| learn_move[1] == move.id }
        next if sp_data.tutor_moves.include?(move.id)
        next if sp_data.egg_moves.include?(move.id)
        pbMessage(_INTL("{1} forgot {2}...", pkmn.name, move.name)) if !inBattle
        pkmn.moves[i] = nil
      end
      pkmn.moves.compact!
      if pkmn.numMoves == 0
        (inBattle) ? pkmn.learn_move(:PSYCHIC) : pbLearnMove(pkmn, :CONFUSION)
      end
    else
      new_move_id = form_moves[form - 1]
      if inBattle
        old_move_index = -1
        pkmn.moves.each_with_index do |move, i|
          next if !form_moves.include?(move.id)
          old_move_index = i
          break
        end
        old_move_index = pkmn.moves.length - 1 if old_move_index < 0
        pkmn.moves[old_move_index].id = new_move_id
      else
        pbLearnMove(pkmn, new_move_id, true)
      end
    end
  }
})