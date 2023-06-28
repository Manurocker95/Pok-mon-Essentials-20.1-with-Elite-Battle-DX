#===============================================================================
# Compile & save ZUD related data.
#===============================================================================
module Compiler
  module_function
  
  PLUGIN_FILES += ["ZUD"]
  
  def write_habitats(path = "PBS/Plugins/ZUD/pokemon.txt")
    write_pbs_file_message_start(path)
    File.open(path, "wb") { |f|
      idx = 0
      GameData::Species.each do |s|
        baseform = GameData::Species.get(s.species)
        next if s.form > 0 && s.habitat == baseform.habitat
        echo "." if idx % 50 == 0
        idx += 1
        Graphics.update if idx % 250 == 0
        f.write("\#-------------------------------\r\n")
        f.write(sprintf("[%s]\r\n", s.id))
        f.write(sprintf("Habitat = %s\r\n", s.habitat)) if s.habitat != :None
      end
    }
    process_pbs_file_message_end
  end
  
  #-----------------------------------------------------------------------------
  # Compiles Raid Ranks.
  #-----------------------------------------------------------------------------
  def compile_raid_ranks(path = "PBS/Plugins/ZUD/raid_ranks.txt")
    compile_pbs_file_message_start(path)
    rank_lists = [ 
      [], # Rank 1 (index 0) 
      [], # Rank 2 (index 1) 
      [], # Rank 3 (index 2) 
      [], # Rank 4 (index 3)
      [], # Rank 5 (index 4)
      [], # Rank 6 (index 5)
      [], # Total  (index 6)
      [], # Banned (index 7)
    ]
    banlist = raid_GenerateBanlist
	rank_lists[7] = banlist.clone
    pbCompilerEachCommentedLine(path) { |line, line_no|
      if line[/^\s*(\w+)\s*=\s*(.*)$/]
        species = $1.to_sym
        value = $2
        include = false
        if banlist.include?(species)
          raise _INTL("{1} is a banned raid species. Remove any raid rank entries for this species.\r\n", species, FileLineData.linereport)
        end
        line = pbGetCsvRecord(value, line_no, [0, "*u"])
        line.each do |rank|
          next if !(1..6).include?(rank)
          rank_lists[rank - 1].push(species)
          include = true
        end
        rank_lists[6].push(species) if include
      end
    }
    # Check for duplicate species in a Raid Rank.
    rank_lists.each_with_index do |list, index|
      if list.length < 5
        raise _INTL("Raid Rank {1} doesn't contain enough species. Each Raid Rank should contain at least five exclusive species.", index + 1)
      end
      unique_list = list.uniq
      next if list == unique_list
      list.each_with_index do |s, i|
        next if unique_list[i] == s
        raise _INTL("Raid Rank {1} has species {2} listed twice.\r\n{3}", index + 1, s, FileLineData.linereport)
      end
    end
    save_data(rank_lists, "Data/raid_ranks.dat")
    process_pbs_file_message_end
  end
  
  #-----------------------------------------------------------------------------
  # Writes the raid_ranks.txt file.
  #-----------------------------------------------------------------------------
  def write_raid_ranks(path = "PBS/Plugins/ZUD/raid_ranks.txt")
    data = pbGetRaidRank[:total]
    return if !data
    Console.echo_li "'ZUD Mechanics'"
    write_pbs_file_message_start(path)
    File.open(path, "wb") { |f|
      idx = 0
      f.write("\# This installation is part of the ZUD Plugin for Pokemon Essentials v20.1\r\n")
      f.write("\#-------------------------------\r\n")
      data.each do |species|
        echo "." if idx % 50 == 0
        idx += 1
        Graphics.update if idx % 250 == 0
        f.write(sprintf("#{species} = %s\r\n", raid_RanksAppearedIn(species).join(",")))
      end
    }
    process_pbs_file_message_end
  end
  
  #-----------------------------------------------------------------------------
  # Compile Max Lair maps.
  #-----------------------------------------------------------------------------
  def compile_lair_maps(path = "PBS/Plugins/ZUD/adventure_maps.txt")
    compile_pbs_file_message_start(path)
    currentmap = -1
    map_data   = []
    pbCompilerEachCommentedLine(path) { |line, line_no|
      if line[/^\s*\[\s*(\d+)\s*\]\s*$/]
        currentmap = $~[1].to_i
        map_data[currentmap] = {}
      else
        if currentmap < 0
          raise _INTL("Expected a section at the beginning of the file\r\n{1}", FileLineData.linereport)
        end
        if !line[/^\s*(\w+)\s*=\s*(.*)$/]
          raise _INTL("Bad line syntax (expected syntax like XXX=YYY)\r\n{1}", FileLineData.linereport)
        end
        settingname = $~[1]
        case settingname
        when "Name", "Start", "Player"
          record = pbGetCsvRecord($~[2], line_no, [0, "s"])
          map_data[currentmap][settingname] = record
          if ["Start", "Player"].include?(settingname)
            coordinate_check(record, map_data[currentmap]["Name"])
          end
        when "DarkMap"
          record = pbGetCsvRecord($~[2], line_no, [0, "b"])
          map_data[currentmap][settingname] = record
        else
          record = pbGetCsvRecord($~[2], line_no, [0, "*s"])
          map_data[currentmap][settingname] = record
          record.each do |coords|
            coordinate_check(coords, map_data[currentmap]["Name"])
          end
        end
      end
    }
    map_data.each_with_index do |map, i|
      if !map.has_key?("Name")
        raise _INTL("Lair map number {1} is missing a name entry.}", i)
      elsif !map.has_key?("Start")
        raise _INTL("'{1}' lair map is missing a 'Start' tile. This is a required tile for each lair map.", map["Name"])
      elsif !map.has_key?("Player")
        raise _INTL("'{1}' lair map is missing a 'Player' tile. This is a required tile for each lair map.", map["Name"])
      elsif !map.has_key?("Pokemon") || map["Pokemon"].length != 11
        raise _INTL("'{1}' lair map has an incorrect number of Pokemon coordinates. Each lair map requires eleven Pokemon coordinates.", map["Name"])
      end
      if !pbResolveBitmap("Graphics/Plugins/ZUD/Adventure/Maps/" + map["Name"])
        p _INTL("Missing graphic named '{1}' for lair map number {2}.", map["Name"], i)
      end
    end
    save_data(map_data, "Data/adventure_maps.dat")
    process_pbs_file_message_end
  end
  
  #-----------------------------------------------------------------------------
  # Writes the adventure_maps.txt file.
  #-----------------------------------------------------------------------------
  def write_lair_maps(path = "PBS/Plugins/ZUD/adventure_maps.txt")
    mapdata = pbLoadLairMapData
    return if !mapdata
    Console.echo_li "'ZUD Mechanics'"
    write_pbs_file_message_start(path)
    File.open(path, "wb") { |f|
      idx = 0
      f.write("\# This installation is part of the ZUD Plugin for Pokemon Essentials v20.1\r\n")
      mapdata.length.times do |i|
        echo "." if idx % 50 == 0
        idx += 1
        Graphics.update if idx % 250 == 0
        map = mapdata[i]
        next if !map
        f.write("\#-------------------------------\r\n")
        f.write(sprintf("[%d]\r\n", i))
        map.each do |key, value|
          if value.is_a?(Array)
            f.write(sprintf("%s = %s\r\n", key, value.join(",")))
          else
            f.write(sprintf("%s = %s\r\n", key, value))
          end
        end
      end
    }
    process_pbs_file_message_end
  end
  
  #-----------------------------------------------------------------------------
  # Adds Dynamax metric data to GameData::SpeciesMetrics.
  #-----------------------------------------------------------------------------
  def compile_dynamax_metrics(path = "PBS/Plugins/ZUD/dynamax_metrics.txt")
    # Creates new metrics entry if species doesn't already have one.
    path = "PBS/Plugins/ZUD/dynamax_metrics_ebdx.txt" if PluginManager.installed?("Generation 8 Pack Scripts")
    compile_pbs_file_message_start(path)
    idx = 0
    GameData::Species.each do |species|
      next if species.no_dynamax
      if !GameData::SpeciesMetrics.exists?(species.id)
        species_hash = {
          :id                    => species.id,
          :species               => species.species,
          :form                  => species.form,
          :back_sprite           => [0, 0],
          :front_sprite          => [0, 0],
          :front_sprite_altitude => 0,
          :shadow_x              => 0,
          :shadow_size           => 2,
          :dmax_back_sprite      => [0, 0],
          :dmax_front_sprite     => [0, 0],
          :dmax_altitude         => 0,
          :dmax_shadow_x         => 0,
          :dmax_shadow_size      => 3
        }
        GameData::SpeciesMetrics.register(species_hash)
        GameData::SpeciesMetrics.save
      end
    end
    pbAutoPositionDynamax if !safeExists?(path)
    schema = GameData::SpeciesMetrics::ZUD_SCHEMA
    File.open(path, "rb") { |f|
      FileLineData.file = path
      pbEachFileSection(f) { |contents, species_id|
        echo "." if idx % 50 == 0
        idx += 1
        Graphics.update if idx % 250 == 0
        FileLineData.setSection(species_id, "header", nil)
        metrics_data = GameData::SpeciesMetrics.try_get(species_id)
        next if !metrics_data
        schema.keys.each do |key|
          if nil_or_empty?(contents[key])
            contents[key] = nil
            next
          end
          FileLineData.setSection(species_id, key, contents[key])
          value = pbGetCsvRecord(contents[key], key, schema[key])
          value = nil if value.is_a?(Array) && value.length == 0
          contents[key] = value
          case key
          # Dynamax
          when "DmaxBackSprite";  metrics_data.dmax_back_sprite  = contents[key]
          when "DmaxFrontSprite"; metrics_data.dmax_front_sprite = contents[key]
          when "DmaxAltitude";    metrics_data.dmax_altitude     = contents[key]
          when "DmaxShadowX";     metrics_data.dmax_shadow_x     = contents[key]
          when "DmaxShadowSize";  metrics_data.dmax_shadow_size  = contents[key]
          # Gigantamax
          when "GmaxBackSprite";  metrics_data.gmax_back_sprite  = contents[key]
          when "GmaxFrontSprite"; metrics_data.gmax_front_sprite = contents[key]
          when "GmaxAltitude";    metrics_data.gmax_altitude     = contents[key]
          when "GmaxShadowX";     metrics_data.gmax_shadow_x     = contents[key]
          when "GmaxShadowSize";  metrics_data.gmax_shadow_size  = contents[key]
          end
        end
      }
    }
    GameData::SpeciesMetrics.save
    process_pbs_file_message_end
  end
  
  #-----------------------------------------------------------------------------
  # Writes dynamax_metrics.txt from SpeciesMetrics data.
  #-----------------------------------------------------------------------------
  def write_dynamax_metrics(path = "PBS/Plugins/ZUD/dynamax_metrics.txt")
    path = "PBS/Plugins/ZUD/dynamax_metrics_ebdx.txt" if PluginManager.installed?("Generation 8 Pack Scripts")
    Console.echo_li "'ZUD Mechanics'"
    write_pbs_file_message_start(path)
    idx = 0
    File.open(path, "wb") { |f|
      f.write("\# This installation is part of the ZUD Plugin for Pokemon Essentials v20.1\r\n")
      GameData::Species.each do |species|
	    next if species.no_dynamax
        echo "." if idx % 50 == 0
        idx += 1
        Graphics.update if idx % 250 == 0
        species_metrics = GameData::SpeciesMetrics.get(species.id)
        f.write("\#-------------------------------\r\n")
        f.write("[#{species.id}]\r\n")
        f.write(sprintf("DmaxBackSprite  = %s\r\n", species_metrics.dmax_back_sprite.join(",")))
        f.write(sprintf("DmaxFrontSprite = %s\r\n", species_metrics.dmax_front_sprite.join(",")))
        f.write(sprintf("DmaxAltitude    = %d\r\n", species_metrics.dmax_altitude)) if species_metrics.dmax_altitude != 0
        f.write(sprintf("DmaxShadowX     = %d\r\n", species_metrics.dmax_shadow_x))
        f.write(sprintf("DmaxShadowSize  = %d\r\n", species_metrics.dmax_shadow_size))
        next if !species.hasGmax?
        f.write(sprintf("GmaxBackSprite  = %s\r\n", species_metrics.gmax_back_sprite.join(",")))
        f.write(sprintf("GmaxFrontSprite = %s\r\n", species_metrics.gmax_front_sprite.join(",")))
        f.write(sprintf("GmaxAltitude    = %d\r\n", species_metrics.gmax_altitude)) if species_metrics.gmax_altitude != 0
        f.write(sprintf("GmaxShadowX     = %d\r\n", species_metrics.gmax_shadow_x))
        f.write(sprintf("GmaxShadowSize  = %d\r\n", species_metrics.gmax_shadow_size))
      end
    }
    process_pbs_file_message_end
  end
  
  #-----------------------------------------------------------------------------
  # Compiles GameData::PowerMove from power_moves.txt.
  #-----------------------------------------------------------------------------
  def compile_power_moves(path = "PBS/Plugins/ZUD/power_moves.txt")
    compile_pbs_file_message_start(path)
    GameData::PowerMove::DATA.clear
    schema = GameData::PowerMove::SCHEMA
    power_move_hash      = nil
    gmax_data            = {}
    gmax_form_names      = []
    gmax_pokedex_entries = []
    zmove_idx = ultra_idx = gmax_idx = 0
    pbCompilerEachPreppedLine(path) { |line, line_no|
      if line[/^\s*\[\s*(.+)\s*\]\s*$/]
        GameData::PowerMove.register(power_move_hash) if power_move_hash
        case $~[1]
        when "ZMOVE"
          zmove_idx += 1
          power_move_id = "ZMOVE_#{zmove_idx}".to_sym
        when "ULTRA"
          ultra_idx += 1
          power_move_id = "ULTRA_#{ultra_idx}".to_sym
        when "GMAX"
          gmax_idx  += 1
          power_move_id = "GMAX_#{gmax_idx}".to_sym
        when "ZSTATUS"
          power_move_id = $~[1].to_sym
        else
          if GameData::Type.exists?($~[1].to_sym)
            power_move_id = $~[1].to_sym
          else next
          end
        end
        if GameData::PowerMove.exists?(power_move_id)
          raise _INTL("Power Move ID '{1}' is used twice.\r\n{2}", power_move_id, FileLineData.linereport)
        end
        power_move_hash = {
          :id => power_move_id,
        }
      elsif line[/^\s*(\w+)\s*=\s*(.*)$/]
        if !power_move_hash
          raise _INTL("Expected a section at the beginning of the file.\r\n{1}", FileLineData.linereport)
        end
        property_name = $~[1]
        line_schema = schema[property_name]
        next if !line_schema
        property_value = pbGetCsvRecord($~[2], line_no, line_schema)
        id = power_move_hash[:id]
        gmax_data[id] = {} if id.to_s.include?("GMAX") && !gmax_data.has_key?(id)
        case property_name
        when "Name"
          gmax_form_names.push(property_value)
          gmax_data[id][property_name] = property_value
        when "Height"
          value = (property_value * 10).round
          if value <= 0
            raise _INTL("Value for 'Height' in G-Max data can't be less than or close to 0 (section {2})", path)
          end
          gmax_data[id][property_name] = value
        when "Pokedex"
          gmax_pokedex_entries.push(property_value)
          gmax_data[id][property_name] = property_value
        else
          power_move_hash[line_schema[0]] = property_value
        end
      end
    }
    GameData::PowerMove.register(power_move_hash) if power_move_hash
    #---------------------------------------------------------------------------
    # Adds all flagged forms to each relevant GameData::PowerMove.
    #---------------------------------------------------------------------------
    GameData::PowerMove.each do |entry|
      next if !entry.flag || !entry.species
      if entry.flag == "AllForms"
        GameData::Species.each do |sp|
          next if sp.species != entry.species.first
          entry.species.push(sp.id)
        end
      elsif entry.flag.include?("_")
        form = entry.flag.split("_").last.to_i
        GameData::Species.each do |sp|
          next if sp.species != entry.species.first
          next if entry.flag.include?("AllFormsAbove") && sp.form < form
          next if entry.flag.include?("AllFormsBelow") && sp.form >= form
          entry.species.push(sp.id)
        end
        entry.species.delete_at(0)
        entry.species.push(nil) if entry.species.length == 0
      end
      entry.species.uniq!
    end
    GameData::PowerMove.save
    #---------------------------------------------------------------------------
    # Adds G-Max data to each relevant GameData::Species.
    #---------------------------------------------------------------------------
    GameData::PowerMove.each do |entry|
      next if !entry.id.to_s.include?("GMAX") || !entry.species
      entry.species.each do |sp|
        species = GameData::Species::DATA[sp]
        species.real_gmax_name = gmax_data[entry.id]["Name"]
        species.gmax_height    = gmax_data[entry.id]["Height"]
        species.real_gmax_dex  = gmax_data[entry.id]["Pokedex"]
      end
    end
    GameData::Species.save
    MessageTypes.setMessagesAsHash(MessageTypes::GMaxNames, gmax_form_names)
    MessageTypes.setMessagesAsHash(MessageTypes::GMaxEntries, gmax_pokedex_entries)
    process_pbs_file_message_end
  end
  
  #-----------------------------------------------------------------------------
  # Writes the power_moves.txt file from GameData::PowerMove and Species data.
  #-----------------------------------------------------------------------------
  def write_power_moves(path = "PBS/Plugins/ZUD/power_moves.txt")
    write_pbs_file_message_start(path)
    File.open(path, "wb") { |f|
      f.write("# This installation is part of the ZUD Plugin for Pokemon Essentials v20.1\r\n")
      f.write("#########################################################################\r\n")
      f.write("# SECTION 1 : GENERIC POWER MOVES\r\n")
      f.write("# Power Moves linked to a particular Type.\r\n")
      f.write("#########################################################################\r\n")
      GameData::PowerMove.each do |pm|
        next if !pm.generic?
        f.write("[#{pm.id}]\r\n")
        f.write("MaxMove = #{pm.maxmove}\r\n")
        f.write("ZMove   = #{pm.zmove}\r\n")
        f.write("Item    = #{pm.item}\r\n")
        f.write("#-------------------------------\r\n")
      end
      f.write("#########################################################################\r\n")
      f.write("# SECTION 2 : EXCLUSIVE Z-MOVES\r\n")
      f.write("# Power Moves exclusive to a particular Item/Move/Species combo.\r\n")
      f.write("#########################################################################\r\n")
      GameData::PowerMove.each do |pm|
        next if !pm.z_move? || !pm.exclusive?
        species_ids = (pm.flag) ? [pm.species.first] : pm.species
        f.write("[ZMOVE]\r\n")
        f.write("ZMove   = #{pm.zmove}\r\n")
        f.write("Item    = #{pm.item}\r\n")
        f.write("Move    = #{pm.move}\r\n")
        f.write(sprintf("Species = %s\r\n", species_ids.join(",")))
        f.write("Flag    = #{pm.flag}\r\n") if pm.flag
        f.write("#-------------------------------\r\n")
      end
      f.write("#########################################################################\r\n")
      f.write("# SECTION 3 : ULTRA BURST\r\n")
      f.write("# Exclusive form changes for a particular Item/Species combo.\r\n")
      f.write("#########################################################################\r\n")
      GameData::PowerMove.each do |pm|
        next if !pm.ultra?
        f.write("[ULTRA]\r\n")
        f.write(sprintf("Species = %s\r\n", pm.species.join(",")))
        f.write("Item    = #{pm.item}\r\n")
        f.write("Ultra   = #{pm.ultra}\r\n")
        f.write("#-------------------------------\r\n")
      end
      f.write("#########################################################################\r\n")
      f.write("# SECTION 4 : EXCLUSIVE G-MAX FORMS\r\n")
      f.write("# Power Moves exclusive to a particular Type/Species combo.\r\n")
      f.write("#########################################################################\r\n")
      GameData::PowerMove.each do |pm|
        next if !pm.gmax?
        species = GameData::Species.get(pm.species.first)
        species_ids = (pm.flag) ? [pm.species.first] : pm.species
        f.write("[GMAX]\r\n")
        f.write("MaxMove = #{pm.maxmove}\r\n") if pm.maxmove
        f.write("Type    = #{pm.type}\r\n") if pm.type
        f.write(sprintf("Species = %s\r\n", species_ids.join(",")))
        f.write("Flag    = #{pm.flag}\r\n") if pm.flag
        f.write("Name    = #{species.gmax_form_name}\r\n")
        f.write(sprintf("Height  = %.1f\r\n", species.gmax_height / 10.0))
        f.write("Pokedex = #{species.gmax_dex_entry}\r\n")
        f.write("#-------------------------------\r\n")
      end
      f.write("#########################################################################\r\n")
      f.write("# SECTION 5 : STATUS Z-MOVES\r\n")
      f.write("# Additional effects granted to Z-Powered status moves.\r\n")
      f.write("#########################################################################\r\n")
      f.write("[ZSTATUS]\r\n")
      data = GameData::PowerMove.get(:ZSTATUS)
      GameData::PowerMove::SCHEMA.keys.each do |key|
        movelist = nil
        case key
        when "AtkBoost1";   movelist = data.status_atk[1]
        when "AtkBoost2";   movelist = data.status_atk[2]
        when "AtkBoost3";   movelist = data.status_atk[3]
        when "DefBoost1";   movelist = data.status_def[1]
        when "DefBoost2";   movelist = data.status_def[2]
        when "DefBoost3";   movelist = data.status_def[3]
        when "SpAtkBoost1"; movelist = data.status_spatk[1]
        when "SpAtkBoost2"; movelist = data.status_spatk[2]
        when "SpAtkBoost3"; movelist = data.status_spatk[3]
        when "SpDefBoost1"; movelist = data.status_spdef[1]
        when "SpDefBoost2"; movelist = data.status_spdef[2]
        when "SpDefBoost3"; movelist = data.status_spdef[3]
        when "SpeedBoost1"; movelist = data.status_speed[1]
        when "SpeedBoost2"; movelist = data.status_speed[2]
        when "SpeedBoost3"; movelist = data.status_speed[3]
        when "AccBoost1";   movelist = data.status_acc[1]
        when "AccBoost2";   movelist = data.status_acc[2]
        when "AccBoost3";   movelist = data.status_acc[3]
        when "EvaBoost1";   movelist = data.status_eva[1]
        when "EvaBoost2";   movelist = data.status_eva[2]
        when "EvaBoost3";   movelist = data.status_eva[3]
        when "OmniBoost1";  movelist = data.status_omni[1]
        when "OmniBoost2";  movelist = data.status_omni[2]
        when "OmniBoost3";  movelist = data.status_omni[3]
        when "CritBoost";   movelist = data.status_crit
        when "ResetStats";  movelist = data.status_reset
        when "HealUser";    movelist = data.status_heal[1]
        when "HealSwitch";  movelist = data.status_heal[2]
        when "FocusOnUser"; movelist = data.status_focus
        end
        next if !movelist || movelist.empty?
        f.write(sprintf("%s = %s\r\n", key, movelist.join(",")))
      end
    }
    process_pbs_file_message_end
  end
end