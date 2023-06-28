#===============================================================================
# Max Raid utilities for setting up and getting Raid Rank data.
#===============================================================================
# Handles the Raid Rank data.
#-------------------------------------------------------------------------------
class Game_Temp
  attr_accessor :lair_maps_data
  attr_accessor :raid_ranks_data
end

alias zud_pbClearData pbClearData
def pbClearData
  $game_temp.lair_maps_data = nil if $game_temp
  $game_temp.raid_ranks_data = nil if $game_temp
  zud_pbClearData
end

def pbLoadRaidRanks
  $game_temp = Game_Temp.new if !$game_temp
  if !$game_temp.raid_ranks_data
    $game_temp.raid_ranks_data = load_data("Data/raid_ranks.dat")
  end
  return $game_temp.raid_ranks_data
end


#-------------------------------------------------------------------------------
# Utilities for quickly obtaining information related to raid ranks.
#-------------------------------------------------------------------------------
def pbGetRaidRank
  ranks = pbLoadRaidRanks
  return {
    1 => ranks[0],
    2 => ranks[1],
    3 => ranks[2],
    4 => ranks[3],
    5 => ranks[4],
    6 => ranks[5],
    :total  => ranks[6],
    :banned => ranks[7]
  }
end

def raid_SpeciesFromRank(rank = nil)
  return (rank) ? pbGetRaidRank[rank] : pbGetRaidRank[:total]
end

def raid_RanksAppearedIn(species)
  ranks = []
  6.times { |i| ranks.push(i + 1) if pbLoadRaidRanks[i].include?(species) }
  return ranks
end

def raid_RankFromBadgeCount
  badges = $player.badge_count
  ranks  = []
  ranks.push(1) if badges < 6
  ranks.push(2) if badges < 8 && badges > 0
  ranks.push(3) if badges >= 3
  ranks.push(4) if badges >= 6
  ranks.push(5) if badges >= 8
  return ranks.sample
end

def raid_LevelFromRank(rank)
  case rank
  when 1 then return 15 + rand(6)
  when 2 then return 30 + rand(6)
  when 3 then return 40 + rand(6)
  when 4 then return 50 + rand(6)
  when 5 then return 60 + rand(6)
  when 6 then return 70
  end
end

def raid_RankFromLevel(level)
  return 1 if (1..20).include?(level)
  return 2 if (30..35).include?(level)
  return 3 if (40..45).include?(level)
  return 4 if (50..55).include?(level)
  return 5 if (60..65).include?(level)
  return 6 if level >= 70
end


#-------------------------------------------------------------------------------
# Generates the raid banlist containing all ineligible species.
#-------------------------------------------------------------------------------
def raid_GenerateBanlist
  #-----------------------------------------------------------------------------
  # Hard-coded banned species list. These species never appear as raid Pokemon
  # due to either being too gimmicky, being very exclusive forms that shouldn't
  # normally appear (despite other forms of that same species being eligible), or
  # base forms of Legendary species that are too weak to appear in Legendary tier.
  #-----------------------------------------------------------------------------
  raid_banlist = [:SMEARGLE, 
                  :SHEDINJA, 
                  :PHIONE, 
                  :FLOETTE_5, 
                  :ZYGARDE_2, 
                  :ZYGARDE_3,
                  :TYPENULL, 
                  :COSMOG, 
                  :COSMOEM, 
                  :POIPOLE, 
                  :MELTAN,
                  :KUBFU]
  #-----------------------------------------------------------------------------
  # Allowable multi-form species. These species have forms that should be allowed
  # to appear in raids. However, many of these species have forms that may only
  # appear under certain conditions, which is handled elsewhere.
  #-----------------------------------------------------------------------------
  allowed_forms = [:TAUROS,
                   :UNOWN, 
                   :DEOXYS, 
                   :BURMY, 
                   :WORMADAM, 
                   :SHELLOS, 
                   :GASTRODON, 
                   :ROTOM,
                   :SHAYMIN,
                   :DEERLING,
                   :SAWSBUCK,
                   :BASCULIN, 
                   :TORNADUS, 
                   :THUNDURUS, 
                   :LANDORUS, 
                   :VIVILLON,
                   :FURFROU, 
                   :FLABEBE, 
                   :FLOETTE, 
                   :FLORGES, 
                   :MEOWSTIC, 
                   :PUMPKABOO,
                   :GOURGEIST, 
                   :ZYGARDE, 
                   :HOOPA, 
                   :ORICORIO, 
                   :ROCKRUFF, 
                   :LYCANROC,
                   :SINISTEA, 
                   :POLTEAGEIST, 
                   :TOXTRICITY, 
                   :INDEEDEE, 
                   :URSHIFU,
                   :BASCULEGION,
                   :ENAMORUS,
                   :OINKOLOGNE,
                   :PALAFIN,
                   :DUDUNSPARCE,
                   :MAUSHOLD,
                   :TATSUGIRI,
                   :SQUAWKABILLY]
  #-----------------------------------------------------------------------------
  # All other forms not listed above are added to the raid banlist. Exceptions
  # are made for regional forms, as well as other specific cases, such as with 
  # Minior meteor forms.
  #-----------------------------------------------------------------------------
  GameData::Species.each do |sp|
    if sp.no_dynamax
      raid_banlist.push(sp.id)
    else
      #-------------------------------------------------------------------------
      # Species with allowable forms are not included in the banlist.
      #--------------------------------------------------------------------------
      next if sp.form == 0
      next if sp.regionalVariant?
      next if allowed_forms.include?(sp.species)
      next if sp.species == :MINIOR && sp.form < 7
      raid_banlist.push(sp.id)
    end
  end
  return raid_banlist
end


#-------------------------------------------------------------------------------
# Gets the specific species or array of species to utilize in a raid event.
#-------------------------------------------------------------------------------
def raid_GenerateSpeciesList(params, rank, env = nil, database_filter = false)
  case params
  #-----------------------------------------------------------------------------
  # Filters by inputted array [GameData::Type, GameData::Habitat, generation]
  #-----------------------------------------------------------------------------
  when Array
    type_filter    = true if params[0]
    habitat_filter = true if params[1]
    gen_filter     = true if params[2]
  #-----------------------------------------------------------------------------
  # Filters by inputted GameData::Species id.
  #-----------------------------------------------------------------------------
  when Symbol
    params = raid_GetEligibleSpecies(params)
    rank   = raid_RanksAppearedIn(params).sample if !rank
    case GameData::Species.get(params).form
    when 0; species_filter = true
    else    pokemon_filter = true
    end
  #-----------------------------------------------------------------------------
  # Otherwise, filters by random species found on the current map.
  #-----------------------------------------------------------------------------
  else
    species_filter = true
    enctype = $PokemonEncounters.encounter_type
    if enctype && $PokemonEncounters.encounter_possible_here?
      encounter = $PokemonEncounters.choose_wild_pokemon(enctype)
      params = encounter[0]
    end
    params = raid_GetEligibleSpecies(params)
  end
  #-----------------------------------------------------------------------------
  # Builds an array of eligible species based on applied filters.
  #-----------------------------------------------------------------------------
  raid_species = []
  if pokemon_filter
    raid_species.push(params)
  else
    environ  = [:BURMY, :WORMADAM]
    seasonal = [:DEERLING, :SAWSBUCK]
    timeday  = [:SHAYMIN, :ROCKRUFF, :LYCANROC]
    dataform = [:PIKACHU, :UNOWN, :SHELLOS, :GASTRODON, :FLABEBE, :FLOETTE, :FLORGES, :FURFROU, :PUMPKABOO, :GOURGEIST,
            	:ROCKRUFF, :MINIOR, :SINISTEA, :POLTEAGEIST, :PALAFIN, :DUDUNSPARCE, :MAUSHOLD, :TATSUGIRI, :SQUAWKABILLY]
    enviform = (env == :Cave || env == :Rock || env == :Sand) ? 1 : (env == :None) ? 2 : 0
    timeform = (PBDayNight.isNight?) ? 1 : (PBDayNight.isEvening?) ? 2 : 0
    banlist  = pbGetRaidRank[:banned]
    for i in raid_SpeciesFromRank(rank)
	  next if banlist.include?(i) || !GameData::Species.exists?(i)
      sp = GameData::Species.get(i)
      #-------------------------------------------------------------------------
      # General filters.
      #-------------------------------------------------------------------------
      next if sp.generation > Settings::GENERATION_LIMIT
      next if type_filter    && !sp.types.include?(params[0])
      next if habitat_filter && sp.habitat != params[1]
      next if gen_filter     && sp.generation != params[2]
      next if seasonal.include?(sp.species) && sp.form != pbGetSeason
      next if sp.species == :VIVILLON && sp.form != $player.secret_ID % 18
      #-------------------------------------------------------------------------
      # Filters out species that shouldn't naturally appear unless specified.
      #-------------------------------------------------------------------------
      if database_filter 
        next if dataform.include?(sp.species) && sp.form > 0
      else
        next if species_filter && sp.species != params
        next if sp.regionalVariant? && !sp.encounterRegional?
        next if environ.include?(sp.species) && sp.form != enviform
        next if timeday.include?(sp.species) && sp.form != timeform
        next if params.is_a?(Array) && sp.species == :UNOWN
        next if params.is_a?(Array) && sp.species == :ETERNATUS
        next if sp.species == :FURFROU && sp.form > 0
        next if sp.id == :ZYGARDE_1
      end
      raid_species.push(i)
    end
  end
  return raid_species
end

#-------------------------------------------------------------------------------
# Selects a random species out of the generated species list above.
# Returns Ditto if no species was found for some reason.
#-------------------------------------------------------------------------------
def raid_GenerateSpecies(*args)
  species = raid_GenerateSpeciesList(*args)
  return (!species.empty?) ? species.sample : :DITTO
end

#-------------------------------------------------------------------------------
# Returns a list only of raid species that the player has already seen.
#-------------------------------------------------------------------------------
def raid_GetSeenSpecies(*args)
  total = []
  raid_GenerateSpeciesList(*args).each { |sp| total.push(sp) if $player.seen?(sp) }
  return total  
end

#-------------------------------------------------------------------------------
# Checks if the inputted species appears on the raid banlist. If so, selects the
# base form of that species instead. If the base form also appears on the banlist,
# then Ditto is selected instead as a last resort.
#-------------------------------------------------------------------------------
def raid_GetEligibleSpecies(pokemon)
  pokemon = :DITTO if pokemon.nil? || !GameData::Species.exists?(pokemon)
  data    = GameData::Species.get(pokemon)
  banlist = pbGetRaidRank[:banned]
  pokemon = data.species if banlist.include?(data.id)
  pokemon = :DITTO       if banlist.include?(data.species)
  return pokemon
end