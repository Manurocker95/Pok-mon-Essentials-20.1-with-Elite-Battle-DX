#===============================================================================
# Max Raid Den event utilities.
#===============================================================================

#===============================================================================
# Used for setting species for Max Raid Dens.
#===============================================================================
# The main Max Raid script to run in an event.
# The pkmn parameter can be a Pokemon object, species ID, or an array consisting
# of a GameData::Type, GameData::Habitat, and generation number.
# If set to nil, a randomly selected species found on the encounter table on the
# event's location will be selected instead.
#-------------------------------------------------------------------------------
def pbMaxRaidDen(pkmn = [], rules = {}, pokemon = {})
  interp = pbMapInterpreter
  this_event = interp.get_self
  return if !this_event
  raid_pkmn = interp.getVariable
  case raid_pkmn
  #-----------------------------------------------------------------------------
  # Attempts to reset an empty den.
  #-----------------------------------------------------------------------------
  when 0
    this_event.turn_down
    return pbRaidDenReset(interp, this_event)
  #-----------------------------------------------------------------------------
  # Accesses a Max Raid Den with an existing saved species.
  #-----------------------------------------------------------------------------
  when Pokemon
    if raid_pkmn.isSpecies?(:CALYREX)
      this_event.turn_right
    else
      this_event.turn_left
    end
    return MaxRaidBattle.start(raid_pkmn, rules, pokemon)
  #-----------------------------------------------------------------------------
  # Accesses a Max Raid Den with a newly generated species.
  #-----------------------------------------------------------------------------
  else
    this_event.turn_up
    return MaxRaidBattle.start(pkmn, rules, pokemon)
  end
end

#-------------------------------------------------------------------------------
# Selects a random species from an inputted array to spawn in a Max Raid Den.
# If two arrays are entered, the player can force a species from the second
# array to spawn instead if they throw a Dynamax Crystal into the den.
#-------------------------------------------------------------------------------
def pbSetRaidSpecies(table1 = [], table2 = [])
  interp = pbMapInterpreter
  this_event = interp.get_self
  raid_pkmn = interp.getVariable
  this_event.turn_down
  if raid_pkmn == 0 && table2.length > 0
    item = GameData::Item.get(:DYNAMAXCRYSTAL)
    if $bag.has?(item.id)
      pbMessage(_INTL("Oh? The Pokémon den seems to be reacting to your {1}!", item.portion_name))
      if pbConfirmMessage(_INTL("Want to throw in a {1} to lure a special Pokémon?", item.portion_name))
        $bag.remove(item.id)
        interp.setVariable(nil)
        this_event.turn_up
        return table2.sample
      end
    end
  end
  return table1.sample
end


#-------------------------------------------------------------------------------
# Automatically resets all Max Raid Den events after a day has passed.
#-------------------------------------------------------------------------------
EventHandlers.add(:on_frame_update, :raid_den_reset,
  proc {
    $PokemonGlobal.raid_timer = Time.now if !$PokemonGlobal.raid_timer
    next if Time.now.day == $PokemonGlobal.raid_timer.day
    $PokemonGlobal.eventvars = {} if !$PokemonGlobal.eventvars
    $PokemonGlobal.eventvars.keys.each do |key|
      map = load_data(sprintf("Data/Map%03d.rxdata", key[0]))
      event = map.events[key[1]]
      next if !event || !event.name[/raidden/i]
      $PokemonGlobal.eventvars[key] = nil
    end
    $PokemonGlobal.raid_timer = Time.now
    $game_map.update
  }
)

#-------------------------------------------------------------------------------
# Empties all Max Raid Dens on all maps. 
# Resets each den with new Pokemon instead if reset == true.
#-------------------------------------------------------------------------------
def pbClearAllDens(reset = false)
  set = (reset) ? nil : 0
  $PokemonGlobal.eventvars = {} if !$PokemonGlobal.eventvars
  GameData::MapMetadata.each do |map_data|
    map = load_data(sprintf("Data/Map%03d.rxdata", map_data.id))
    for event_id in 1..map.events.length
      event = map.events[event_id]
      next if !event || !event.name[/raidden/i]
      $PokemonGlobal.eventvars[[map_data.id, event_id]] = set
    end
  end  
  $PokemonGlobal.raid_timer = Time.now
  $game_map.update
end

#-------------------------------------------------------------------------------
# Resets an individual Max Raid Den by throwing in a Wishing Piece.
# This is automatically called by pbMaxRaidDen if the den is empty.
#-------------------------------------------------------------------------------
def pbRaidDenReset(interp, this_event)
  if $DEBUG && Input.press?(Input::CTRL)
    pbMessage(_INTL("A Pokémon was lured to the den!"))
    interp.setVariable(nil)
  else
    item = GameData::Item.get(:WISHINGPIECE)
    pbMessage(_INTL("There doesn't seem to be anything in the den..."))
    if pbConfirmMessage(_INTL("Want to throw in a {1} to lure a Pokémon?", item.portion_name))
      if $bag.has?(item.id)
        pbMessage(_INTL("You threw a {1} into the den!", item.portion_name))
        $bag.remove(item.id)
        interp.setVariable(nil)
        this_event.turn_up
      else
        pbMessage(_INTL("But you don't have any {1}...", item.portion_name_plural))
      end
    end
  end
  return false
end


#===============================================================================
# Handles the overworld sprites for Max Raid Den events.
#===============================================================================
class RaidDenSprite
  def initialize(event, map, _viewport)
    @event     = event
    @map       = map
    @disposed  = false
    raid_pkmn = event.variable
    @event.character_name = ""
    set_event_graphic(raid_pkmn)
  end

  def dispose
    @event    = nil
    @map      = nil
    @disposed = true
  end

  def disposed?
    @disposed
  end
 
  def update
    raid_pkmn = @event.variable
    set_event_graphic(raid_pkmn)
  end
  
  #-----------------------------------------------------------------------------
  # Sets the actual graphic for a Max Raid Den event.
  #-----------------------------------------------------------------------------
  def set_event_graphic(raid_pkmn)
    if pbResolveBitmap("Graphics/Characters/Object raid den")
      @event.character_name = "Object raid den"
      case raid_pkmn
      #-------------------------------------------------------------------------
      # Empty raid den graphic.
      #-------------------------------------------------------------------------
      when 0
        @event.turn_down
      #-------------------------------------------------------------------------
      # Shows blue beam if den species is Calyrex; red beam otherwise.
      #-------------------------------------------------------------------------
      when Pokemon
        if raid_pkmn.isSpecies?(:CALYREX)
          @event.turn_right
        else
          @event.turn_left
        end
      #-------------------------------------------------------------------------
      # Shows purple beam on newly reset dens.
      #-------------------------------------------------------------------------
      else @event.turn_up
      end
    end
  end
end

#-------------------------------------------------------------------------------
# Updates all Max Raid Den event sprites on a loaded map.
#-------------------------------------------------------------------------------
EventHandlers.add(:on_new_spriteset_map, :add_raid_den_graphics,
  proc { |spriteset, viewport|
    map = spriteset.map
    map.events.each do |event|
      next if !event[1].name[/raidden/i]
      spriteset.addUserSprite(RaidDenSprite.new(event[1], map, viewport))
    end
  }
)