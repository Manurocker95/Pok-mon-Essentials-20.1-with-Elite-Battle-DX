#===============================================================================
# Adds ZUD-related tools to debug options.
#===============================================================================

#-------------------------------------------------------------------------------
# General Debug options
#-------------------------------------------------------------------------------
MenuHandlers.add(:debug_menu, :zud_menu, {
  "name"        => _INTL("ZUD..."),
  "parent"      => :dx_menu,
  "description" => _INTL("Edit settings related to the ZUD Plugin.")
})


MenuHandlers.add(:debug_menu, :debug_zud_switches, {
  "name"        => _INTL("Toggle Switches..."),
  "parent"      => :zud_menu,
  "description" => _INTL("Toggles the availability of ZUD functionality."),
  "effect"      => proc {
    loop do
      commands = [
        _INTL("Z-Moves [{1}]",     ($game_switches[Settings::NO_Z_MOVE])      ? _INTL("NO") : _INTL("YES")),
        _INTL("Ultra Burst [{1}]", ($game_switches[Settings::NO_ULTRA_BURST]) ? _INTL("NO") : _INTL("YES")),
        _INTL("Dynamax [{1}]",     ($game_switches[Settings::NO_DYNAMAX])     ? _INTL("NO") : _INTL("YES"))
      ]
      command = pbShowCommands(nil, commands, -1, 0)
      break if command < 0
      case command
      when 0 then switch, text = Settings::NO_Z_MOVE,      "Z-Moves are "
      when 1 then switch, text = Settings::NO_ULTRA_BURST, "Ultra Burst is "
      when 2 then switch, text = Settings::NO_DYNAMAX,     "Dynamax is "  
      end
      $game_switches[switch] = !$game_switches[switch]
      text += ($game_switches[switch]) ? "disabled" : "enabled"
      pbMessage(_INTL("{1}.", text))
    end
  }
})


MenuHandlers.add(:debug_menu, :debug_dynamax, {
  "name"        => _INTL("Dynamax..."),
  "parent"      => :zud_menu,
  "description" => _INTL("Edit conditions related to Dynamax availability."),
  "effect"      => proc {
    loop do
      commands = [
        _INTL("Dynamax on All Maps [{1}]",     ($game_switches[Settings::DYNAMAX_ANY_MAP])  ? _INTL("YES") : _INTL("NO")),
        _INTL("Dynamax in Wild Battles [{1}]", ($game_switches[Settings::CAN_DYNAMAX_WILD]) ? _INTL("YES") : _INTL("NO"))
      ]
      command = pbShowCommands(nil, commands, -1, 0)
      break if command < 0
      case command
      when 0 then switch, text = Settings::DYNAMAX_ANY_MAP,  "Dynamax availability on all maps "
      when 1 then switch, text = Settings::CAN_DYNAMAX_WILD, "Dynamax availability in wild battles "  
      end
      $game_switches[switch] = !$game_switches[switch]
      text += ($game_switches[switch]) ? "enabled" : "disabled"
      pbMessage(_INTL("{1}.", text))
    end
  }
})


MenuHandlers.add(:debug_menu, :debug_raid_database, {
  "name"        => _INTL("Max Raid Database"),
  "parent"      => :zud_menu,
  "description" => _INTL("Toggle the player's ownership of the Max Raid Database."),
  "effect"      => proc {
    $player.has_raid_database = !$player.has_raid_database
    toggle = ($player.has_raid_database) ? "ON" : "OFF"
    pbMessage(_INTL("Ownership of the Max Raid Database is toggled {1}.", toggle))
  }
})


MenuHandlers.add(:debug_menu, :debug_raid_dens, {
  "name"        => _INTL("Max Raid Dens..."),
  "parent"      => :zud_menu,
  "description" => _INTL("Edit conditions related to Max Raid Dens."),
  "effect"      => proc {
    command  = 0
    commands = [
      _INTL("Test Raid Battle"),
      _INTL("Empty All Dens"),
      _INTL("Reset All Dens")
    ]
    loop do
      command = pbShowCommands(nil, commands, -1, command)
      break if command < 0
      case command
      when 0 # Test Raid Battle
        sp_cmds = []
        species_list = pbGetRaidRank[:total]
        species_list.each do |sp|
          next if !GameData::Species.exists?(sp)
          data = GameData::Species.get(sp)
          name = (data.form > 0) ? sprintf("%s_%d", data.real_name, data.form) : data.real_name
          sp_cmds.push([sp_cmds.length + 1, name, sp])
        end
        if species_list.empty?
          pbMessage(_INTL("No eligible raid species were found."))
        else
          pbMessage(_INTL("Choose a species to challenge in a raid battle."))
          species = pbChooseList(sp_cmds, nil, nil, -1)
          if species
            pbMessage(_INTL("Edit the conditions of this raid battle."))
            pbDebugMaxRaidBattle(species)
          end
        end
      when 1 # Empty All Dens
        pbClearAllDens(false)
        pbMessage(_INTL("Max Raid Dens on all maps were emptied of all Pokémon."))
      when 2 # Reset All Dens
        pbClearAllDens(true)
        pbMessage(_INTL("Max Raid Dens on all maps were reset with new Pokémon."))
      end
    end
  }
})


MenuHandlers.add(:debug_menu, :debug_dynamax_adventure, {
  "name"        => _INTL("Dynamax Adventures..."),
  "parent"      => :zud_menu,
  "description" => _INTL("Edit conditions related to Dynamax Adventures."),
  "effect"      => proc {
    command  = 0
    commands = [
      _INTL("Test Adventure"),
      _INTL("Edit Saved Routes"),
      _INTL("Edit Endless Adventure")
    ]
    loop do
      command = pbShowCommands(nil, commands, -1, command)
      break if command < 0
      case command
      when 0 # Start Adventure
        pbDynamaxAdventure.start
      when 1 # Edit Saved Routes
        routecmd = 0
        routecmds = [
          _INTL("Add New Route"),
          _INTL("Edit Existing Route"),
          _INTL("Clear All Routes")
        ]
        sp_cmds = []
        species_list = raid_GenerateSpeciesList([], 6)
        species_list.each do |sp|
          data = GameData::Species.get(sp)
          name = (data.form > 0) ? sprintf("%s_%d", data.real_name, data.form) : data.real_name
          sp_cmds.push([sp_cmds.length + 1, name, sp])
        end
        map_cmds = []
        map_data = pbLoadLairMapData
        map_data.each_with_index { |m, i| map_cmds.push([map_cmds.length + 1, m["Name"], i]) }
        loop do
          routecmd = pbShowCommands(nil, routecmds, -1, routecmd)
          break if routecmd < 0
          case routecmd
          when 0 # Add New Route
            if lair_SavedRoutes.length >= 3
              pbMessage(_INTL("You already have the maximum number of saved routes."))
            elsif species_list.length == 0
              pbMessage(_INTL("There aren't any eligible den species to add."))
            else
              pbMessage(_INTL("Choose a species for this route."))
              species = pbChooseList(sp_cmds, nil, nil, -1)
              if species
                sp_name = GameData::Species.get(species).name
                pbMessage(_INTL("Choose a map to encounter {1} on.", sp_name))
                map = pbChooseList(map_cmds, nil, nil, -1)
                if map
                  $PokemonGlobal.dynamax_adventure_routes[species] = map
                  pbMessage(_INTL("A route to {1} has been found within {2}.", sp_name, map_data[map]["Name"]))
                end
              end
            end
          when 1 # Edit Existing Route
            if lair_SavedRoutes.empty?
              pbMessage(_INTL("There are no saved routes to edit."))
            else
              pbMessage(_INTL("Select a saved route to edit."))
              array = $PokemonGlobal.dynamax_adventure_routes.to_a
              loop do
                savedcmd = 0
                savedcmds = []
                array.each do |a|
                  map = map_data[a[1]]["Name"]
                  species = GameData::Species.get(a[0]).name
                  savedcmds.push(_INTL("{1} in {2}", species, map))
                end
                savedcmd = pbShowCommands(nil, savedcmds, -1, savedcmd)
                break if savedcmd < 0
                pbMessage(_INTL("Edit the species of this route."))
                data = array[savedcmd]
                species = pbChooseList(sp_cmds, data[0], data[0], -1)
                pbMessage(_INTL("Edit the map for this route."))
                map = pbChooseList(map_cmds, data[1], data[1], -1)
                array[savedcmd] = [species, map]
                $PokemonGlobal.dynamax_adventure_routes = array.to_h
              end
            end
          when 2 # Clear All Routes
            lair_SavedRoutes.clear
            pbMessage(_INTL("All saved adventure routes have been cleared."))
          end
        end
      when 2 # Edit Endless Adventure
        endlesscmd = 0
        endlesscmds = [
          _INTL("Toggle Endless Mode"),
          _INTL("Reset Endless Record")
        ]
        loop do
          endlesscmd = pbShowCommands(nil, endlesscmds, -1, endlesscmd)
          break if endlesscmd < 0
          case endlesscmd
          when 0 # Toggle Endless Mode
            $PokemonGlobal.dynamax_adventure_endless_unlocked = !$PokemonGlobal.dynamax_adventure_endless_unlocked
            toggle = ($PokemonGlobal.dynamax_adventure_endless_unlocked) ? "unlocked" : "locked"
            pbMessage(_INTL("Endless Mode has been {1}.", toggle))
          when 1 # Reset Endless Record
            $PokemonGlobal.dynamax_adventure_record = { :map => "", :floor => 1, :battles => 0, :party => [] }
            pbMessage(_INTL("Your Endless Mode record has been reset."))
          end
        end
      end
    end
  }
})


#-------------------------------------------------------------------------------
# Pokemon Debug options.
#-------------------------------------------------------------------------------
MenuHandlers.add(:pokemon_debug_menu, :set_dynamax, {
  "name"   => _INTL("Dynamax..."),
  "parent" => :dx_pokemon_menu,
  "effect" => proc { |pkmn, pkmnid, heldpoke, settingUpBattle, screen|
    cmd = 0
    loop do
      able = (pkmn.dynamax_able?) ? "Yes" : "No"
      dlvl = pkmn.dynamax_lvl
      gmax = (pkmn.gmax_factor?)  ? "Yes" : "No" 
      dmax = (pkmn.dynamax?)      ? "Yes" : "No"
      cmd = screen.pbShowCommands(_INTL("Eligible: {1}\nDynamax Level: {2}\nG-Max Factor: {3}\nDynamaxed: {4}", able, dlvl, gmax, dmax),[
           _INTL("Set Eligibility"),
           _INTL("Set Dynamax Level"),
           _INTL("Set G-Max Factor"),
           _INTL("Set Dynamax"),
           _INTL("Reset All")], cmd)
      break if cmd < 0
      case cmd
      when 0   # Set Eligibility
        if pkmn.species_data.no_dynamax
          pkmn.unmax
          screen.pbDisplay(_INTL("{1} belongs to a species that cannot use Dynamax.\nEligibility cannot be changed.", pkmn.name))
        elsif pkmn.dynamax_able?
          pkmn.unmax
          pkmn.dynamax_lvl = 0
          pkmn.gmax_factor = false
          pkmn.dynamax_able = false
          screen.pbDisplay(_INTL("{1} is no longer able to use Dynamax.", pkmn.name))
        else
          pkmn.dynamax_able = true
          screen.pbDisplay(_INTL("{1} is now able to use Dynamax.", pkmn.name))
        end
        screen.pbRefreshSingle(pkmnid)
      when 1   # Set Dynamax Level
        if pkmn.dynamax_able?
          params = ChooseNumberParams.new
          params.setRange(0, 10)
          params.setDefaultValue(pkmn.dynamax_lvl)
          params.setCancelValue(pkmn.dynamax_lvl)
          f = pbMessageChooseNumber(
            _INTL("Set {1}'s Dynamax level (max. 10).", pkmn.name), params) { screen.pbUpdate }
          if f != pkmn.dynamax_lvl
            pkmn.dynamax_lvl = f
            pkmn.calc_stats
            screen.pbRefreshSingle(pkmnid)
          end
        else
          screen.pbDisplay(_INTL("Can't edit Dynamax values on that Pokémon."))
        end
      when 2   # Set G-Max Factor
        if pkmn.dynamax_able?
          if pkmn.gmax_factor?
            pkmn.unmax if pkmn.isSpecies?(:ETERNATUS)
            pkmn.gmax_factor = false
            screen.pbDisplay(_INTL("Gigantamax factor was removed from {1}.", pkmn.name))
          else
            if pkmn.hasGmax?
              pkmn.gmax_factor = true
              screen.pbDisplay(_INTL("Gigantamax factor was given to {1}.", pkmn.name))
            else
              if pbConfirmMessage(_INTL("{1} doesn't have a Gigantamax form.\nGive it Gigantamax factor anyway?", pkmn.name))
                pkmn.gmax_factor = true
                screen.pbDisplay(_INTL("Gigantamax factor was given to {1}.", pkmn.name))
              end
            end
          end
          screen.pbRefreshSingle(pkmnid)
        else
          screen.pbDisplay(_INTL("Can't edit Dynamax values on that Pokémon."))
        end
      when 3   # Set Dynamax
        if pkmn.dynamax_able?
          if pkmn.dynamax?
            pkmn.unmax
            screen.pbDisplay(_INTL("{1} is no longer Dynamaxed.", pkmn.name))
          else
            pkmn.dynamax = true
            pkmn.calc_stats
            pkmn.reversion = true
            screen.pbDisplay(_INTL("{1} is Dynamaxed.", pkmn.name))
            $player.pokedex.register(pkmn)
          end
          screen.pbRefreshSingle(pkmnid)
        else
          screen.pbDisplay(_INTL("Can't edit Dynamax values on that Pokémon."))
        end
      when 4   # Reset All
        pkmn.unmax
        pkmn.dynamax_lvl = 0
        pkmn.gmax_factor = false
        pkmn.dynamax_able = nil
        screen.pbDisplay(_INTL("All Dynamax settings restored to default."))
        screen.pbRefreshSingle(pkmnid)
      end
    end
    next false
  }
})


#-------------------------------------------------------------------------------
# Battle Debug options.
#-------------------------------------------------------------------------------
MenuHandlers.add(:battle_debug_menu, :z_moves, {
  "name"        => _INTL("Z-Moves"),
  "parent"      => :trainers,
  "description" => _INTL("Whether each trainer is allowed to use Z-Moves."),
  "effect"      => proc { |battle|
    cmd = 0
    loop do
      commands = []
      cmds = []
      battle.zMove.each_with_index do |side_values, side|
        trainers = (side == 0) ? battle.player : battle.opponent
        next if !trainers
        side_values.each_with_index do |value, i|
          next if !trainers[i]
          text = (side == 0) ? "Your side:" : "Foe side:"
          text += sprintf(" %d: %s", i, trainers[i].name)
          text += sprintf(" [ABLE]") if value == -1
          text += sprintf(" [UNABLE]") if value == -2
          commands.push(text)
          cmds.push([side, i])
        end
      end
      cmd = pbMessage("\\ts[]" + _INTL("Choose trainer to toggle whether they can use Z-Moves."),
                      commands, -1, nil, cmd)
      break if cmd < 0
      real_cmd = cmds[cmd]
      if battle.zMove[real_cmd[0]][real_cmd[1]] == -1
        battle.zMove[real_cmd[0]][real_cmd[1]] = -2   # Make unable
      else
        battle.zMove[real_cmd[0]][real_cmd[1]] = -1   # Make able
      end
    end
  }
})


MenuHandlers.add(:battle_debug_menu, :ultra_burst, {
  "name"        => _INTL("Ultra Burst"),
  "parent"      => :trainers,
  "description" => _INTL("Whether each trainer is allowed to Ultra Burst."),
  "effect"      => proc { |battle|
    cmd = 0
    loop do
      commands = []
      cmds = []
      battle.ultraBurst.each_with_index do |side_values, side|
        trainers = (side == 0) ? battle.player : battle.opponent
        next if !trainers
        side_values.each_with_index do |value, i|
          next if !trainers[i]
          text = (side == 0) ? "Your side:" : "Foe side:"
          text += sprintf(" %d: %s", i, trainers[i].name)
          text += sprintf(" [ABLE]") if value == -1
          text += sprintf(" [UNABLE]") if value == -2
          commands.push(text)
          cmds.push([side, i])
        end
      end
      cmd = pbMessage("\\ts[]" + _INTL("Choose trainer to toggle whether they can Ultra Burst."),
                      commands, -1, nil, cmd)
      break if cmd < 0
      real_cmd = cmds[cmd]
      if battle.ultraBurst[real_cmd[0]][real_cmd[1]] == -1
        battle.ultraBurst[real_cmd[0]][real_cmd[1]] = -2   # Make unable
      else
        battle.ultraBurst[real_cmd[0]][real_cmd[1]] = -1   # Make able
      end
    end
  }
})


MenuHandlers.add(:battle_debug_menu, :dynamax, {
  "name"        => _INTL("Dynamax"),
  "parent"      => :trainers,
  "description" => _INTL("Whether each trainer is allowed to Dynamax."),
  "effect"      => proc { |battle|
    cmd = 0
    loop do
      commands = []
      cmds = []
      battle.dynamax.each_with_index do |side_values, side|
        trainers = (side == 0) ? battle.player : battle.opponent
        next if !trainers
        side_values.each_with_index do |value, i|
          next if !trainers[i]
          text = (side == 0) ? "Your side:" : "Foe side:"
          text += sprintf(" %d: %s", i, trainers[i].name)
          text += sprintf(" [ABLE]") if value == -1
          text += sprintf(" [UNABLE]") if value == -2
          commands.push(text)
          cmds.push([side, i])
        end
      end
      cmd = pbMessage("\\ts[]" + _INTL("Choose trainer to toggle whether they can Dynamax."),
                      commands, -1, nil, cmd)
      break if cmd < 0
      real_cmd = cmds[cmd]
      if battle.dynamax[real_cmd[0]][real_cmd[1]] == -1
        battle.dynamax[real_cmd[0]][real_cmd[1]] = -2   # Make unable
      else
        battle.dynamax[real_cmd[0]][real_cmd[1]] = -1   # Make able
      end
    end
  }
})


#-------------------------------------------------------------------------------
# Debug tool for setting up a Max Raid Battle.
#-------------------------------------------------------------------------------
def pbDebugMaxRaidBattle(pkmn)
  rules = {}
  pokemon = {}
  ranks = raid_RanksAppearedIn(pkmn)
  rules[:rank] = ranks[0]
  rules[:hard] = (rules[:rank] == 6) ? true : false
  rules[:size] = Settings::MAXRAID_SIZE
  rules[:weather] = :None
  rules[:terrain] = :None
  rules[:environ] = :Cave
  rules[:simple] = true
  pokemon[:form] = GameData::Species.get(pkmn).form
  pokemon[:gmaxfactor] = (GameData::Species.get(pkmn).hasGmax?) ? true : false
  raidmsg = (rules[:rank] == 6) ? "Legendary" : rules[:rank]
  hardmsg =  rules[:hard] ? "Hard" : "Normal"
  sizemsg = ["1v1", "2v1", "3v1"]
  gmaxmsg   = (pokemon[:gmaxfactor]) ? "Yes" : "No"
  eternamax = (pkmn == :ETERNATUS) ? true : false
  maxtype   = (eternamax) ? "Eternamax" : "Gigantamax"
  cmd = 0
  criteria = [
    _INTL("Start Battle"),
    _INTL("Set Party"),
    _INTL("Raid Level [{1}]", raidmsg),
    _INTL("Raid Size [{1}]", sizemsg[rules[:size] - 1]),
    _INTL("Difficulty [{1}]", hardmsg),
    _INTL("{1} [{2}]", maxtype, gmaxmsg),
    _INTL("Weather [{1}]", GameData::BattleWeather.get(rules[:weather]).name),
    _INTL("Terrain [{1}]", GameData::BattleTerrain.get(rules[:terrain]).name),
    _INTL("Environment [{1}]", GameData::Environment.get(rules[:environ]).name),
    _INTL("Back")
  ]
  loop do
    Input.update
    cmd = pbShowCommands(nil, criteria, -1, cmd)
    #-------------------------------------------------------------------------
    # Cancel & Reset
    #-------------------------------------------------------------------------
    if cmd == 9 || cmd < 0
      pbPlayCancelSE
      pbMessage(_INTL("Battle cancelled."))
      break
    end
    #-------------------------------------------------------------------------
    # Start Battle
    #-------------------------------------------------------------------------
    if cmd == 0
      pbFadeOutIn {
        pbSEPlay("Door enter")
        Input.update
        MaxRaidBattle.start(pkmn, rules, pokemon)
        pbWait(20)
        pbSEPlay("Door exit")
      }
      for i in $player.party; i.heal; end
      break
    #-------------------------------------------------------------------------
    # View party screen
    #-------------------------------------------------------------------------
    elsif cmd == 1
      Input.update
      pbPlayDecisionSE
      pbPokemonScreen
    #-------------------------------------------------------------------------
    # Set Raid Level
    #-------------------------------------------------------------------------
    elsif cmd == 2
      choice = 0
      stars = []
      ranks.each { |r| stars.push(r.to_s) }
      if rules[:rank] < 6
        loop do
          Input.update
          choice = pbShowCommands(nil, stars, -1, choice)
          pbPlayDecisionSE if choice == -1
          if choice > -1
            rules[:rank] = ranks[choice]
            pbMessage(_INTL("Raid level set to {1}.", rules[:rank]))
          end
          break
        end
      else
        pbMessage(_INTL("This species may only appear in Legendary raids."))
      end
    #-------------------------------------------------------------------------
    # Set Raid Size
    #-------------------------------------------------------------------------
    elsif cmd == 3
      choice = 0
      loop do
        Input.update
        choice = pbShowCommands(nil, sizemsg, -1, choice)
        pbPlayDecisionSE if choice == -1
        if choice > -1
          rules[:size] = choice + 1
          pbMessage(_INTL("Raid size is set to {1}.", sizemsg[choice]))
        end
        break
      end
    #-------------------------------------------------------------------------
    # Set Difficulty mode
    #-------------------------------------------------------------------------    
    elsif cmd == 4
      if rules[:rank] < 6
        loop do
          Input.update
          pbPlayDecisionSE
          if !rules[:hard]
            rules[:hard] = true
            pbMessage(_INTL("Hard Mode enabled."))
          else
            rules[:hard] = false
            pbMessage(_INTL("Hard Mode disabled."))
          end
          break
        end
      else
        pbMessage(_INTL("Difficulty for Legendary raids cannot be changed."))
      end
    #-------------------------------------------------------------------------
    # Set Gigantamax
    #-------------------------------------------------------------------------
    elsif cmd == 5
      if GameData::Species.get(pkmn).hasGmax?
        if !eternamax
          loop do
            Input.update
            pbPlayDecisionSE
            if !pokemon[:gmaxfactor]
              pokemon[:gmaxfactor] = true
              pbMessage(_INTL("Gigantamax Factor applied."))
            else
              pokemon[:gmaxfactor] = false
              pbMessage(_INTL("Gigantamax Factor removed."))
            end
            break
          end
        else
          pbMessage(_INTL("This species can only appear in its Eternamax Form."))
        end
      else
        pbMessage(_INTL("This species is unable to Gigantamax."))
      end
    #-------------------------------------------------------------------------
    # Set Weather
    #-------------------------------------------------------------------------
    elsif cmd == 6
      weather    = []
      weather_id = []
      GameData::BattleWeather.each do |w|
        next if w.id == :HarshSun
        next if w.id == :HeavyRain
        next if w.id == :StrongWinds
        weather.push(w.name)
        weather_id.push(w.id)
      end
      choice = 0
      loop do
        Input.update
        choice = pbShowCommands(nil, weather, -1, choice)
        pbPlayDecisionSE if choice == -1
        if choice > -1
          rules[:weather] = weather_id[choice]
          pbMessage(_INTL("Weather is set to {1}.", weather[choice]))
        end
        break
      end
    #-------------------------------------------------------------------------
    # Set Terrain
    #-------------------------------------------------------------------------
    elsif cmd == 7
      terrain    = []
      terrain_id = []
      GameData::BattleTerrain.each do |t|
        name = t.name
        full_name = (t.id == :None) ? name : name += " Terrain"
        terrain.push(full_name)
        terrain_id.push(t.id)
      end
      choice = 0
      loop do
        Input.update
        choice = pbShowCommands(nil, terrain, -1, choice)
        pbPlayDecisionSE if choice == -1
        if choice > -1
          rules[:terrain] = terrain_id[choice]
          pbMessage(_INTL("Terrain is set to {1}.", terrain[choice]))
        end
        break
      end
    #-------------------------------------------------------------------------
    # Set Environment
    #-------------------------------------------------------------------------
    elsif cmd == 8
      environ    = []
      environ_id = []
      GameData::Environment.each do |e|
        environ.push(e.name)
        environ_id.push(e.id)
      end
      choice = 0
      loop do
        Input.update
        choice = pbShowCommands(nil, environ, -1, choice)
        pbPlayDecisionSE if choice == -1
        if choice > -1
          rules[:environ] = environ_id[choice]
          pbMessage(_INTL("Environment is set to {1}.", environ[choice]))
        end
        break
      end
    end
    #-------------------------------------------------------------------------
    # Sets newly selected criteria
    #-------------------------------------------------------------------------
    criteria.clear
    raidmsg  = (rules[:rank] == 6) ? "Legendary" : rules[:rank]
    hardmsg  = (rules[:hard]) ? "Hard" : "Normal"
    maxtype  = (eternamax) ? "Eternamax" : "Gigantamax"
    gmaxmsg  = (pokemon[:gmaxfactor]) ? "Yes" : "No"
    criteria = [
      _INTL("Start Battle"),
      _INTL("Set Party"),
      _INTL("Raid Level [{1}]", raidmsg),
      _INTL("Raid Size [{1}]", sizemsg[rules[:size] - 1]),
      _INTL("Difficulty [{1}]", hardmsg),
      _INTL("{1} [{2}]", maxtype, gmaxmsg),
      _INTL("Weather [{1}]", GameData::BattleWeather.get(rules[:weather]).name),
      _INTL("Terrain [{1}]", GameData::BattleTerrain.get(rules[:terrain]).name),
      _INTL("Environment [{1}]", GameData::Environment.get(rules[:environ]).name),
      _INTL("Back")
    ]
  end
end