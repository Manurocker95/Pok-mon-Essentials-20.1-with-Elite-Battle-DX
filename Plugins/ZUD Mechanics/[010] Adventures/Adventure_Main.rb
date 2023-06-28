#===============================================================================
# Core class for handling a Dynamax Adventure.
#===============================================================================
class DynamaxAdventure
  attr_accessor :keycount
  attr_accessor :knockouts
  attr_accessor :loot
  attr_accessor :prizes
  attr_accessor :lair_floor
  attr_accessor :battle_count
  attr_accessor :abandoned
  attr_accessor :new_rental
  attr_accessor :boss_battled
  attr_accessor :boss_species
  attr_accessor :last_pokemon
  attr_reader   :lair_species
  attr_reader   :darkness_map
  attr_accessor :darkness_lvl
  
  # Window skin used for NPC encounter text (not dialogue).
  WINDOWSKIN = "Graphics/Windowskins/sign hgss loc"
  
  def clear
    #---------------------------------------------------------------------------
    # Tracks lair properties
    @map_name     = nil
    @map_index    = nil
    @keycount     = 0
    @knockouts    = 0
    #---------------------------------------------------------------------------
    # Tracks general adventure states
    @gender_text  = 0
    @abandoned    = false
    @in_progress  = false
    #---------------------------------------------------------------------------
    # Tracks the state of the Pokemon in the lair
    @lair_species = []
    @last_pokemon = nil
    @new_rental   = nil
    @boss_species = nil
    @boss_battled = false
    #---------------------------------------------------------------------------
    # Tracks Endless Mode properties
    @endless_mode = false
    @lair_floor   = 1
    @battle_count = 0
    @record_team  = []
    #---------------------------------------------------------------------------
    # Tracks Dark Lair properties
    @darkness_map = false
    @darkness_lvl = nil
    #---------------------------------------------------------------------------
    # Used to hold things for the player
    @loot         = {}
    @prizes       = []
    @party        = []
  end
  
  def initialize;                  clear;   end
  def darkLair?;    return @darkness_map;   end
  def endlessMode?; return @endless_mode;   end
  def inProgress?;  return @in_progress;    end
  def abandoned?;   return @abandoned;      end
  def completed?;   return @boss_battled;   end
  def defeated?;    return @knockouts <= 0; end
  def victory?;     return (completed? && !defeated?); end
  def ended?;       return (completed? || defeated? || abandoned?);  end
  
  #-----------------------------------------------------------------------------
  # Creates an encounter table of eleven species for this Dynamax Adventure.
  #-----------------------------------------------------------------------------
  def generate_species
    @lair_species.clear
    [2, 3, 4, 6].each do |rank|
      rank_list = raid_GenerateSpeciesList([], rank)
      case rank
      when 6
        @boss_species = rank_list.sample if !@boss_species
        @lair_species.push(@boss_species)
      else
        @lair_species.each { |sp| rank_list.delete(sp) if rank_list.include?(sp) }
        tier_size = (rank == 2) ? 2 : 4
        tier_size.times do |i|
          species = rank_list.sample
          @lair_species.push(species)
          rank_list.delete(species)
        end
      end
    end
  end
  
  #-------------------------------------------------------------------------------
  # Creates a rental Pokemon.
  #-------------------------------------------------------------------------------
  def generate_rental
    rank    = (@last_pokemon) ? 5 : 3
    species = raid_GenerateSpecies([], rank)
    scale   = ($player.badge_count <= 6) ? $player.badge_count : 6
    level   = [10, 15, 25, 35, 45, 55, 65][scale]
    owner   = Pokemon::Owner.new($player.make_foreign_ID, _INTL("RENTAL"), 2, $player.language)
    pokemon = Pokemon.new(species, level, owner)
    pokemon.dynamax_lvl = 5
    pokemon.gmax_factor = (pokemon.hasGmax? && rand(10) < 5)
    moves = raid_GenerateMovelists(pokemon.species_data.id, true)
    pokemon.learn_move(moves[0].sample) if moves[0].length > 0
    pokemon.learn_move(moves[1].sample) if moves[1].length > 0
    pokemon.learn_move(moves[2].sample) if moves[2].length > 0
    pokemon.learn_move(moves[3].sample) if moves[3].length > 0
    odds = rand(100)
    pokemon.item = (odds < 25) ? :SITRUSBERRY : (odds < 50) ? :ORANBERRY : nil
    pokemon.ability_index = rand(pokemon.getAbilityList.length)
    pokemon.obtain_text = _INTL("Adventure Rental.")
    pokemon.calc_lair_evs
    return pokemon
  end
  
  #-----------------------------------------------------------------------------
  # Handles prizes and loot in a Dynamax Adventure.
  #-----------------------------------------------------------------------------
  def swap_pokemon
    return if ended? || completed? || !inProgress?
    @new_rental = @last_pokemon
    pbMaxLairMenu(:exchange)
  end
  
  def add_prize(pkmn)
    @last_pokemon = pkmn
    if inProgress? && !ended?
      @last_pokemon.calc_lair_evs
    end
    @prizes.push(@last_pokemon)
    @prizes.delete(@prizes.first) if @prizes.length > 6
  end
  
  def add_loot(item, qty = 1)
    return if !GameData::Item.exists?(item)
    if @loot.has_key?(item)
      @loot[item] += qty
    else
      @loot[item] = qty
    end
  end
  
  def select_prize
    return if !inProgress?
    return if @prizes.length == 0
    shiny_charm = (GameData::Item.exists?(:SHINYCHARM) && $bag.has?(:SHINYCHARM))
    odds = (shiny_charm) ? rand(50) : rand(150)
    for poke in @prizes
      case odds
      when 0 then poke.shiny = true
      when 1 then poke.super_shiny = true
      end
      poke.item = nil
      poke.reset_moves
      GameData::Stat.each_main { |s| poke.ev[s.id] = 0 }
      poke.calc_stats
      poke.heal
    end
    pbMaxLairMenu(:prize)
  end
  
  #-----------------------------------------------------------------------------
  # Adventure start.
  #-----------------------------------------------------------------------------
  def start(map_index = nil, gender = nil)
    return if inProgress?
    initialize
    @gender_text = gender
    g = (@gender_text == 0) ? "\\b" : (@gender_text == 1) ? "\\r" : ""
    if pbConfirmMessage(_INTL("#{g}Would you like to embark on a Dynamax Adventure?"))
      #-------------------------------------------------------------------------
      # Select an adventure type.
      #-------------------------------------------------------------------------
      cmd = 0
      commands = []
      @map_index = map_index
      if !lair_SavedRoutes.empty?
        pbMessage(_INTL("#{g}According to my notes, it seems you might know how to find certain special Pokémon."))
        lair_SavedRoutes.each { |sp, _m| commands.push(_INTL("Find {1}!", GameData::Species.get(sp).name)) }
      end
      commands.push(_INTL("Normal Adventure"))
      commands.push(_INTL("Endless Adventure")) if lair_EndlessUnlocked?
      commands.push(_INTL("View Record")) if lair_EndlessRecord[:floor] > 1
      commands.push(_INTL("Nevermind"))
      loop do
        cmd = pbMessage(_INTL("#{g}Which type of adventure are you interested in today?"), commands, -1, nil, 0)
        if cmd == -1 || cmd == commands.length - 1
          pbMessage(_INTL("#{g}I hope we'll see you again soon!"))
          clear
          break
        else
          case commands[cmd]
          when _INTL("Normal Adventure")
            @in_progress  = true
            break
          when _INTL("Endless Adventure")
            @in_progress  = true
            @endless_mode = true
            break
          when _INTL("View Record")
            pbMaxLairMenu(:record)
          else
            @in_progress  = true
            array = lair_SavedRoutes.to_a
            @boss_species = array[cmd][0]
            @map_index = array[cmd][1]
            break
          end
        end
      end
      #-------------------------------------------------------------------------
      # Select a lair map.
      #-------------------------------------------------------------------------
      if inProgress?
        map_data = pbLoadLairMapData
        if !@map_index
          map_cmd = 0
          map_indexes = []
          map_commands = []
          map_path = "Graphics/Plugins/ZUD/Adventure/Maps/"
          map_data.each_with_index do |map, i|
            next if !pbResolveBitmap(map_path + map["Name"])
            next if map["DarkMap"] && lair_EndlessRecord[:floor] <= 1
            map_indexes.push(i)
            map_commands.push(_INTL("{1}", map["Name"]))
          end
          map_commands.push(_INTL("Nevermind"))
          loop do
            map_cmd = pbMessage(_INTL("#{g}Which lair would you like to explore?"), map_commands, -1, nil, 0)
            if map_cmd == -1 || map_cmd == map_commands.length - 1
              @in_progress = false
              pbMessage(_INTL("#{g}I hope we'll see you again soon!"))
              break
            else
              @map_index = map_indexes[map_cmd]
              break
            end
          end
        end
        if @map_index
          @map_name = map_data[@map_index]["Name"]
          @darkness_map = map_data[@map_index]["DarkMap"]
          process_adventure
        end
      end
    else
      pbMessage(_INTL("#{g}I hope we'll see you again soon!"))
      clear
    end
  end
  
  #-----------------------------------------------------------------------------
  # Enters and exits a Max Lair.
  #-----------------------------------------------------------------------------
  def process_adventure
    @party = $player.party
    pbMaxLairMenu(:rental)
    g = (@gender_text == 0) ? "\\b" : (@gender_text == 1) ? "\\r" : ""
    if $player.party == @party
      pbMessage(_INTL("#{g}I hope we'll see you again soon!"))
      clear
    else
      if !@darkness_map && Settings::DARK_LAIR_FREQUENCY > 0 
        @darkness_map = true if Settings::DARK_LAIR_FREQUENCY == 1 && rand(100) < 5
        @darkness_map = true if Settings::DARK_LAIR_FREQUENCY == 2 && rand(100) < 20
        @darkness_map = true if Settings::DARK_LAIR_FREQUENCY == 3
        @darkness_map = false if (!$DEBUG && lair_EndlessRecord[:floor] <= 1)
      end
      if @darkness_map
        $stats.dark_lairs_entered += 1
        pbMessage(_INTL("#{g}This route seems particularly treacherous - visibility will be limited!\nPlease be careful!"))
      end
      if @boss_species
        boss_name = GameData::Species.get(@boss_species).name
        pbMessage(_INTL("#{g}Good luck on your search for {1}!", boss_name)) 
      else
        pbMessage(_INTL("#{g}Good luck on your adventure!"))
      end
      $stats.max_lairs_entered += 1
      $stats.endless_lairs_entered += 1 if endlessMode?
      pbSEPlay("Door enter")
      @knockouts  = $player.party.length
      previousBGM = $game_system.getPlayingBGM
      pbFadeOutInWithMusic { 
        loop do
          generate_species
          pbMaxLairMap(@map_index)
          break if ended?
        end
        @record_team = $player.party
        @record_team.each { |p| p.heal }
        $player.party = @party
        select_prize
      }
      pbBGMPlay(previousBGM)
      lair_exit
    end
  end
  
  #-----------------------------------------------------------------------------
  # Adventure end.
  #-----------------------------------------------------------------------------
  def lair_exit
    return if !inProgress?
    g = (@gender_text == 0) ? "\\b" : (@gender_text == 1) ? "\\r" : ""
    if abandoned?
      pbMessage(_INTL("#{g}Huh, you're giving up?\nPlease come back any time for a new adventure!"))
    #---------------------------------------------------------------------------
    # Endless mode
    #---------------------------------------------------------------------------
    elsif endlessMode?
      if @lair_floor > lair_EndlessRecord[:floor]
        $stats.endless_lair_records += 1
        pbMessage(_INTL("#{g}Now THAT is what I call a fine performance! You set a new record! I keep track, you know."))
        $PokemonGlobal.dynamax_adventure_record = {
          :map     => @map_name,
          :floor   => @lair_floor,
          :battles => @battle_count,
          :party   => @record_team
        }
        pbMaxLairMenu(:record)
        if !@loot.empty?
          pbMessage(_INTL("#{g}I'll add any treasure you acquired during your adventure to your bag."))
          @loot.each { |item, qty| $bag.add(item, qty) }
        end
      else
        pbMessage(_INTL("#{g}Didn't make it quite far this time, eh?\nThat's ok, better luck next time!"))
        if !@loot.empty?
          loot_added = false
          @loot.each do |item, qty|
            next if rand(2) < 1
            $bag.add(item, qty)
            loot_added = true
          end
          if loot_added
            pbMessage(_INTL("#{g}I managed to salvage some of the treasure you acquired during your adventure..."))
            pbMessage(_INTL("#{g}I'll add what I was able to recover to your bag."))
          end
        end
      end
    #---------------------------------------------------------------------------
    # Defeat
    #---------------------------------------------------------------------------
    elsif defeated?
      bossname = GameData::Species.get(@boss_species).name
      pbMessage(_INTL("#{g}Well done facing such a tough opponent!\nVictory seemed so close - I could almost taste it!"))      
      if @boss_battled && !lair_SavedRoutes.has_key?(@boss_species)
        bossname = GameData::Species.get(@boss_species).name
        if pbConfirmMessage(_INTL("#{g}Would you like me to jot down where you found {1} this time so that you might find it again?", bossname))
          if lair_SavedRoutes.length >= 3
            pbMessage(_INTL("#{g}You already have the maximum number of routes saved..."))
            if pbConfirmMessage(_INTL("#{g}Would you like to replace an existing route?"))
              cmd = 0
              commands = []
              lair_SavedRoutes.each { |sp, _m| commands.push(GameData::Species.get(sp).name) }
              commands.push(_INTL("Nevermind"))
              loop do
                cmd = pbMessage(_INTL("#{g}Which route should be replaced?"), commands, -1, nil, 0)
                case cmd
                when -1, commands.length - 1
                  break
                else
                  array = $PokemonGlobal.dynamax_adventure_routes.to_a
                  array.delete_at(cmd)
                  array.push([@boss_species, @map_index])
                  $PokemonGlobal.dynamax_adventure_routes = array.to_h
                  pbMessage(_INTL("#{g}The route to {1} was saved for future reference.", bossname))
                  break
                end
              end
            end
          else 
            $PokemonGlobal.dynamax_adventure_routes[@boss_species] = @map_index
            pbMessage(_INTL("#{g}The route to {1} was saved for future reference.", bossname))
          end
        end     
      end
      if !@loot.empty?
        loot_added = false
        @loot.each do |item, qty|
          next if rand(2) < 1
          $bag.add(item, qty)
          loot_added = true
        end
        if loot_added
          pbMessage(_INTL("#{g}I managed to salvage some of the treasure you acquired during your adventure..."))
          pbMessage(_INTL("#{g}I'll add what I was able to recover to your bag."))
        end
      end
    #---------------------------------------------------------------------------
    # Victory
    #---------------------------------------------------------------------------
    elsif victory?
      $stats.max_lairs_cleared += 1
      if lair_SavedRoutes.has_key?(@boss_species)
        $PokemonGlobal.dynamax_adventure_routes.delete(@boss_species)
      end
      pbMessage(_INTL("#{g}Well done defeating that tough opponent!"))
      if !@loot.empty?
        pbMessage(_INTL("#{g}I'll add any treasure you acquired during your adventure to your bag."))
        @loot.each { |item, qty| $bag.add(item, qty) }
      end
      if !lair_EndlessUnlocked?
        pbMessage(_INTL("#{g}Hey, you seem good at this - maybe next time you'll want to try diving even deeper into the lair?"))
        pbMessage(_INTL("#{g}Try your luck at an Endless Adventure and see what you're really made of!"))
        $PokemonGlobal.dynamax_adventure_endless_unlocked = true
      end
    end
    pbMessage(_INTL("#{g}I hope we'll see you again soon!"))
    clear
  end
end

#===============================================================================
# Various utilities used for Dynamax Adventure functions.
#===============================================================================
class PokemonGlobalMetadata
  attr_accessor :raid_timer
  attr_accessor :dynamax_adventure_state
  attr_accessor :dynamax_adventure_routes
  attr_accessor :dynamax_adventure_record
  attr_accessor :dynamax_adventure_endless_unlocked
  
  alias zud_initialize initialize
  def initialize
    @raid_timer = Time.now
    @dynamax_adventure_state  = nil
    @dynamax_adventure_routes = {}
    @dynamax_adventure_record = { :map => "", :floor => 1, :battles => 0, :party => [] }
    @dynamax_adventure_endless_unlocked = false
    zud_initialize
  end
end

def lair_SavedRoutes
  if !$PokemonGlobal.dynamax_adventure_routes
    $PokemonGlobal.dynamax_adventure_routes = {}
  end
  return $PokemonGlobal.dynamax_adventure_routes
end

def lair_EndlessRecord
  if !$PokemonGlobal.dynamax_adventure_record
    $PokemonGlobal.dynamax_adventure_record = { :map => "", :floor => 1, :battles => 0, :party => [] }
  end
  return $PokemonGlobal.dynamax_adventure_record
end

def lair_EndlessUnlocked?
  return $PokemonGlobal.dynamax_adventure_endless_unlocked
end

def pbDynamaxAdventure
  return if !defined?(DynamaxAdventure)
  if !$PokemonGlobal.dynamax_adventure_state
    $PokemonGlobal.dynamax_adventure_state = DynamaxAdventure.new
  end
  return $PokemonGlobal.dynamax_adventure_state
end

def inMaxLair?
  return false if !defined?(DynamaxAdventure)
  return pbDynamaxAdventure.inProgress?
end

def pbLoadLairMapData
  $game_temp = Game_Temp.new if !$game_temp
  if !$game_temp.lair_maps_data
    $game_temp.lair_maps_data = load_data("Data/adventure_maps.dat")
  end
  return $game_temp.lair_maps_data
end