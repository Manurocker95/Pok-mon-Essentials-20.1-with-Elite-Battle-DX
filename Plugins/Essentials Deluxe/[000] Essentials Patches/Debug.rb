#===============================================================================
# Adds debug options for Deluxe Plugins.
#===============================================================================

#-------------------------------------------------------------------------------
# General debug menus.
#-------------------------------------------------------------------------------
MenuHandlers.add(:debug_menu, :dx_menu, {
  "name"        => _INTL("Deluxe Plugins..."),
  "parent"      => :main,
  "description" => _INTL("Edit settings related to various plugins that utilize Essentials Deluxe."),
  "always_show" => false
})


MenuHandlers.add(:debug_menu, :deluxe_menu, {
  "name"        => _INTL("Essentials Deluxe..."),
  "parent"      => :dx_menu,
  "description" => _INTL("Edit settings related to the Essentials Deluxe plugin.")
})


MenuHandlers.add(:debug_menu, :debug_mega, {
  "name"        => _INTL("Toggle Switch"),
  "parent"      => :deluxe_menu,
  "description" => _INTL("Toggles the availability of Mega Evolution functionality."),
  "effect"      => proc {
    $game_switches[Settings::NO_MEGA_EVOLUTION] = !$game_switches[Settings::NO_MEGA_EVOLUTION]
    toggle = ($game_switches[Settings::NO_MEGA_EVOLUTION]) ? "disabled" : "enabled"
    pbMessage(_INTL("Mega Evolution {1}.", toggle))
  }
})


MenuHandlers.add(:debug_menu, :debug_birthday, {
  "name"        => _INTL("Set Player's Birthday"),
  "parent"      => :deluxe_menu,
  "description" => _INTL("Sets the month and day of the player's birthday."),
  "effect"      => proc {
    pbSetPlayerBirthday
    day = $player.birthdate.day
    month = pbGetMonthName($player.birthdate.mon)
    pbMessage(_INTL("The player's birthdate was set to {1} {2}.", month, day))
  }
})


#-------------------------------------------------------------------------------
# Pokemon debug menus.
#-------------------------------------------------------------------------------
MenuHandlers.add(:pokemon_debug_menu, :dx_pokemon_menu, {
  "name"   => _INTL("Deluxe Options..."),
  "parent" => :main
})


MenuHandlers.add(:pokemon_debug_menu, :set_ace, {
  "name"   => _INTL("Toggle Ace"),
  "parent" => :dx_pokemon_menu,
  "effect" => proc { |pkmn, pkmnid, heldpoke, settingUpBattle, screen|
    if pkmn.ace?
      pkmn.ace = false
      toggle = "unflagged"
    else
      pkmn.ace = true
      toggle = "flagged"
    end
    screen.pbDisplay(_INTL("{1} is {2} as an ace Pokémon.", pkmn.name, toggle))
    next false
  }
})


MenuHandlers.add(:pokemon_debug_menu, :set_scale, {
  "name"   => _INTL("Set Size"),
  "parent" => :dx_pokemon_menu,
  "effect" => proc { |pkmn, pkmnid, heldpoke, settingUpBattle, screen|
    params = ChooseNumberParams.new
    params.setRange(0, 255)
    params.setDefaultValue(pkmn.scale)
    newval = pbMessageChooseNumber(
      _INTL("Scale the Pokémon's size (max. 255)."), params
    ) { screen.pbUpdate }
    if newval != pkmn.scale
      pkmn.scale = newval
      screen.pbRefreshSingle(pkmnid)
      case pkmn.scale
      when 255      then size = "XXXL"
      when 242..254 then size = "XXL"
      when 196..241 then size = "XL"
      when 161..195 then size = "Large"
      when 100..160 then size = "Medium"
      when 61..99   then size = "Small"
      when 31..60   then size = "XS"
      when 1..30    then size = "XXS"
      when 0        then size = "XXXS"
      end
      screen.pbDisplay(_INTL("{1} is now considered {2} in size.", pkmn.name, size))
    end
    next false
  }
})


#-------------------------------------------------------------------------------
# Edits to existing menus.
#-------------------------------------------------------------------------------
MenuHandlers.add(:debug_menu, :fill_boxes, {
  "name"        => _INTL("Fill Storage Boxes"),
  "parent"      => :pokemon_menu,
  "description" => _INTL("Add one Pokémon of each species (at Level 50) to storage."),
  "effect"      => proc {
    added = 0
    box_qty = $PokemonStorage.maxPokemon(0)
    completed = true
    GameData::Species.each do |species_data|
      sp = species_data.species
      f = species_data.form
      if f == 0
        if species_data.single_gendered?
          g = (species_data.gender_ratio == :AlwaysFemale) ? 1 : 0
          for shiny in 0..2
            $player.pokedex.register(sp, g, f, shiny, false)
          end
        else
          2.times do |g|
            for shiny in 0..2
              $player.pokedex.register(sp, g, f, shiny, false)
            end
          end
        end
        $player.pokedex.set_owned(sp, false)
      elsif species_data.real_form_name && !species_data.real_form_name.empty?
        g = (species_data.gender_ratio == :AlwaysFemale) ? 1 : 0
        for shiny in 0..2
          $player.pokedex.register(sp, g, f, shiny, false)
        end
      end
      next if f != 0
      if added >= Settings::NUM_STORAGE_BOXES * box_qty
        completed = false
        next
      end
      added += 1
      $PokemonStorage[(added - 1) / box_qty, (added - 1) % box_qty] = Pokemon.new(sp, 50)
    end
    $player.pokedex.refresh_accessible_dexes
    pbMessage(_INTL("Storage boxes were filled with one Pokémon of each species."))
    if !completed
      pbMessage(_INTL("Note: The number of storage spaces ({1} boxes of {2}) is less than the number of species.",
                      Settings::NUM_STORAGE_BOXES, box_qty))
    end
  }
})