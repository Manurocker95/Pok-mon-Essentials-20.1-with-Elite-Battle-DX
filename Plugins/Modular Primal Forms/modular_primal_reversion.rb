 module Compiler
 def compile_pokemon_forms(path = "PBS/pokemon_forms.txt")
    compile_pbs_file_message_start(path)
    species_names           = []
    species_form_names      = []
    species_categories      = []
    species_pokedex_entries = []
    used_forms = {}
    # Read from PBS file
    File.open(path, "rb") { |f|
      FileLineData.file = path   # For error reporting
      # Read a whole section's lines at once, then run through this code.
      # contents is a hash containing all the XXX=YYY lines in that section, where
      # the keys are the XXX and the values are the YYY (as unprocessed strings).
      schema = GameData::Species.schema(true)
      idx = 0
      pbEachFileSectionPokemonForms(f) { |contents, section_name|
        echo "." if idx % 50 == 0
        idx += 1
        Graphics.update if idx % 250 == 0
        FileLineData.setSection(section_name, "header", nil)   # For error reporting
        # Split section_name into a species number and form number
        split_section_name = section_name.split(/[-,\s]/)
        if split_section_name.length != 2
          raise _INTL("Section name {1} is invalid ({2}). Expected syntax like [XXX,Y] (XXX=species ID, Y=form number).", section_name, path)
        end
        species_symbol = csvEnumField!(split_section_name[0], :Species, nil, nil)
        form           = csvPosInt!(split_section_name[1])
        # Raise an error if a species is undefined, the form number is invalid or
        # a species/form combo is used twice
        if !GameData::Species.exists?(species_symbol)
          raise _INTL("Species ID '{1}' is not defined in {2}.\r\n{3}", species_symbol, path, FileLineData.linereport)
        elsif form == 0
          raise _INTL("A form cannot be defined with a form number of 0.\r\n{1}", FileLineData.linereport)
        elsif used_forms[species_symbol]&.include?(form)
          raise _INTL("Form {1} for species ID {2} is defined twice.\r\n{3}", form, species_symbol, FileLineData.linereport)
        end
        used_forms[species_symbol] = [] if !used_forms[species_symbol]
        used_forms[species_symbol].push(form)
        base_data = GameData::Species.get(species_symbol)
        # Go through schema hash of compilable data and compile this section
        schema.each_key do |key|
          # Skip empty properties (none are required)
          if nil_or_empty?(contents[key])
            contents[key] = nil
            next
          end
          FileLineData.setSection(section_name, key, contents[key])   # For error reporting
          # Compile value for key
          if ["EVs", "EffortPoints"].include?(key) && contents[key].split(",")[0].numeric?
            value = pbGetCsvRecord(contents[key], key, [0, "uuuuuu"])   # Old format
          else
            value = pbGetCsvRecord(contents[key], key, schema[key])
          end
          value = nil if value.is_a?(Array) && value.length == 0
          contents[key] = value
          # Sanitise data
          case key
          when "BaseStats"
            value_hash = {}
            GameData::Stat.each_main do |s|
              value_hash[s.id] = value[s.pbs_order] if s.pbs_order >= 0
            end
            contents[key] = value_hash
          when "EVs", "EffortPoints"
            if value[0].is_a?(Array)   # New format
              value_hash = {}
              value.each { |val| value_hash[val[0]] = val[1] }
              GameData::Stat.each_main { |s| value_hash[s.id] ||= 0 }
              contents[key] = value_hash
            else   # Old format
              value_hash = {}
              GameData::Stat.each_main do |s|
                value_hash[s.id] = value[s.pbs_order] if s.pbs_order >= 0
              end
              contents[key] = value_hash
            end
          when "Height", "Weight"
            # Convert height/weight to 1 decimal place and multiply by 10
            value = (value * 10).round
            if value <= 0
              raise _INTL("Value for '{1}' can't be less than or close to 0 (section {2}, {3})", key, section_name, path)
            end
            contents[key] = value
          when "Evolutions"
            contents[key].each do |evo|
              evo[3] = false
              param_type = GameData::Evolution.get(evo[1]).parameter
              if param_type.nil?
                evo[2] = nil
              elsif param_type == Integer
                evo[2] = csvPosInt!(evo[2])
              elsif param_type != String
                evo[2] = csvEnumField!(evo[2], param_type, "Evolutions", section_name)
              end
            end
          end
        end
        # Construct species hash
        form_symbol = sprintf("%s_%d", species_symbol.to_s, form).to_sym
        types = contents["Types"]
        types ||= [contents["Type1"], contents["Type2"]] if contents["Type1"]
        types ||= base_data.types.clone
        types = [types] if !types.is_a?(Array)
        types = types.uniq.compact
        moves = contents["Moves"]
        if !moves
          moves = []
          base_data.moves.each { |m| moves.push(m.clone) }
        end
        evolutions = contents["Evolutions"]
        if !evolutions
          evolutions = []
          base_data.evolutions.each { |e| evolutions.push(e.clone) }
        end
        species_hash = {
          :id                 => form_symbol,
          :species            => species_symbol,
          :form               => form,
          :name               => base_data.real_name,
          :form_name          => contents["FormName"],
          :category           => contents["Category"] || contents["Kind"] || base_data.real_category,
          :pokedex_entry      => contents["Pokedex"] || base_data.real_pokedex_entry,
          :pokedex_form       => contents["PokedexForm"],
          :types              => types,
          :base_stats         => contents["BaseStats"] || base_data.base_stats,
          :evs                => contents["EVs"] || contents["EffortPoints"] || base_data.evs,
          :base_exp           => contents["BaseExp"] || contents["BaseEXP"] || base_data.base_exp,
          :growth_rate        => base_data.growth_rate,
          :gender_ratio       => base_data.gender_ratio,
          :catch_rate         => contents["CatchRate"] || contents["Rareness"] || base_data.catch_rate,
          :happiness          => contents["Happiness"] || base_data.happiness,
          :moves              => moves,
          :tutor_moves        => contents["TutorMoves"] || base_data.tutor_moves.clone,
          :egg_moves          => contents["EggMoves"] || base_data.egg_moves.clone,
          :abilities          => contents["Abilities"] || base_data.abilities.clone,
          :hidden_abilities   => contents["HiddenAbilities"] || contents["HiddenAbility"] || base_data.hidden_abilities.clone,
          :wild_item_common   => contents["WildItemCommon"] || base_data.wild_item_common.clone,
          :wild_item_uncommon => contents["WildItemUncommon"] || base_data.wild_item_uncommon.clone,
          :wild_item_rare     => contents["WildItemRare"] || base_data.wild_item_rare.clone,
          :egg_groups         => contents["EggGroups"] || contents["Compatibility"] || base_data.egg_groups.clone,
          :hatch_steps        => contents["HatchSteps"] || contents["StepsToHatch"] || base_data.hatch_steps,
          :incense            => base_data.incense,
          :offspring          => contents["Offspring"] || base_data.offspring.clone,
          :evolutions         => evolutions,
          :height             => contents["Height"] || base_data.height,
          :weight             => contents["Weight"] || base_data.weight,
          :color              => contents["Color"] || base_data.color,
          :shape              => contents["Shape"] || base_data.shape,
          :habitat            => contents["Habitat"] || base_data.habitat,
          :generation         => contents["Generation"] || base_data.generation,
          :flags              => contents["Flags"] || base_data.flags.clone,
          :mega_stone         => contents["MegaStone"],
          :mega_move          => contents["MegaMove"],
          :unmega_form        => contents["UnmegaForm"],
          :mega_message       => contents["MegaMessage"],
          :primal_stone       => contents["PrimalStone"],
          :primal_move        => contents["PrimalMove"],
          :unprimal_form      => contents["UnprimalForm"],
          :primal_message     => contents["PrimalMessage"]
        }
        echoln "A"
        # If form has any wild items, ensure none are inherited from base species
        if (contents["WildItemCommon"] && !contents["WildItemCommon"].empty?) ||
           (contents["WildItemUncommon"] && !contents["WildItemUncommon"].empty?) ||
           (contents["WildItemRare"] && !contents["WildItemRare"].empty?)
          species_hash[:wild_item_common]   = contents["WildItemCommon"]
          species_hash[:wild_item_uncommon] = contents["WildItemUncommon"]
          species_hash[:wild_item_rare]     = contents["WildItemRare"]
        end
        # Add form's data to records
        GameData::Species.register(species_hash)
        species_names.push(species_hash[:name])
        species_form_names.push(species_hash[:form_name])
        species_categories.push(species_hash[:category])
        species_pokedex_entries.push(species_hash[:pokedex_entry])
        # Save metrics data if defined (backwards compatibility)
        if contents["BattlerPlayerX"] || contents["BattlerPlayerY"] ||
           contents["BattlerEnemyX"] || contents["BattlerEnemyY"] ||
           contents["BattlerAltitude"] || contents["BattlerShadowX"] ||
           contents["BattlerShadowSize"]
          base_metrics = GameData::SpeciesMetrics.get_species_form(species_symbol, 0)
          back_x      = contents["BattlerPlayerX"] || base_metrics.back_sprite[0]
          back_y      = contents["BattlerPlayerY"] || base_metrics.back_sprite[1]
          front_x     = contents["BattlerEnemyX"] || base_metrics.front_sprite[0]
          front_y     = contents["BattlerEnemyY"] || base_metrics.front_sprite[1]
          altitude    = contents["BattlerAltitude"] || base_metrics.front_sprite_altitude
          shadow_x    = contents["BattlerShadowX"] || base_metrics.shadow_x
          shadow_size = contents["BattlerShadowSize"] || base_metrics.shadow_size
          metrics_hash = {
            :id                    => form_symbol,
            :species               => species_symbol,
            :form                  => form,
            :back_sprite           => [back_x, back_y],
            :front_sprite          => [front_x, front_y],
            :front_sprite_altitude => altitude,
            :shadow_x              => shadow_x,
            :shadow_size           => shadow_size
          }
          GameData::SpeciesMetrics.register(metrics_hash)
        end
      }
    }
    # Add prevolution "evolution" entry for all evolved forms that define their
    # own evolution methods (and thus won't have a prevolution listed already)
    all_evos = {}
    GameData::Species.each do |species|   # Build a hash of prevolutions for each species
      species.evolutions.each do |evo|
        all_evos[evo[0]] = [species.species, evo[1], evo[2], true] if !evo[3] && !all_evos[evo[0]]
      end
    end
    GameData::Species.each do |species|   # Distribute prevolutions
      next if species.evolutions.any? { |evo| evo[3] }   # Already has prevo listed
      next if !all_evos[species.species]
      # Record what species evolves from
      species.evolutions.push(all_evos[species.species].clone)
      # Record that the prevolution can evolve into species
      prevo = GameData::Species.get(all_evos[species.species][0])
      if prevo.evolutions.none? { |evo| !evo[3] && evo[0] == species.species }
        prevo.evolutions.push([species.species, :None, nil])
      end
    end
    # Save all data
    GameData::Species.save
    GameData::SpeciesMetrics.save
    MessageTypes.addMessagesAsHash(MessageTypes::Species, species_names)
    MessageTypes.addMessagesAsHash(MessageTypes::FormNames, species_form_names)
    MessageTypes.addMessagesAsHash(MessageTypes::Kinds, species_categories)
    MessageTypes.addMessagesAsHash(MessageTypes::Entries, species_pokedex_entries)
    process_pbs_file_message_end
  end
  
  def write_pokemon_forms(path = "PBS/pokemon_forms.txt")
    write_pbs_file_message_start(path)
    File.open(path, "wb") { |f|
      idx = 0
      add_PBS_header_to_file(f)
      GameData::Species.each do |species|
        echo "." if idx % 50 == 0
        idx += 1
        Graphics.update if idx % 250 == 0
        next if species.form == 0
        base_species = GameData::Species.get(species.species)
        f.write("\#-------------------------------\r\n")
        f.write(sprintf("[%s,%d]\r\n", species.species, species.form))
        f.write(sprintf("FormName = %s\r\n", species.real_form_name)) if species.real_form_name && !species.real_form_name.empty?
        f.write(sprintf("PokedexForm = %d\r\n", species.pokedex_form)) if species.pokedex_form != species.form
        f.write(sprintf("MegaStone = %s\r\n", species.mega_stone)) if species.mega_stone
        f.write(sprintf("MegaMove = %s\r\n", species.mega_move)) if species.mega_move
        f.write(sprintf("UnmegaForm = %d\r\n", species.unmega_form)) if species.unmega_form != 0
        f.write(sprintf("MegaMessage = %d\r\n", species.mega_message)) if species.mega_message != 0
        f.write(sprintf("PrimalStone = %s\r\n", species.primal_stone)) if species.primal_stone
        f.write(sprintf("PrimalMove = %s\r\n", species.primal_move)) if species.primal_move
        f.write(sprintf("UnprimalForm = %d\r\n", species.unprimal_form)) if species.unprimal_form != 0
        f.write(sprintf("PrimalMessage = %d\r\n", species.primal_message)) if species.primal_message != 0
        if species.types.uniq.compact != base_species.types.uniq.compact
          f.write(sprintf("Types = %s\r\n", species.types.uniq.compact.join(",")))
        end
        stats_array = []
        evs_array = []
        GameData::Stat.each_main do |s|
          next if s.pbs_order < 0
          stats_array[s.pbs_order] = species.base_stats[s.id]
          evs_array.concat([s.id.to_s, species.evs[s.id]]) if species.evs[s.id] > 0
        end
        f.write(sprintf("BaseStats = %s\r\n", stats_array.join(","))) if species.base_stats != base_species.base_stats
        f.write(sprintf("BaseExp = %d\r\n", species.base_exp)) if species.base_exp != base_species.base_exp
        f.write(sprintf("EVs = %s\r\n", evs_array.join(","))) if species.evs != base_species.evs
        f.write(sprintf("CatchRate = %d\r\n", species.catch_rate)) if species.catch_rate != base_species.catch_rate
        f.write(sprintf("Happiness = %d\r\n", species.happiness)) if species.happiness != base_species.happiness
        if species.abilities.length > 0 && species.abilities != base_species.abilities
          f.write(sprintf("Abilities = %s\r\n", species.abilities.join(",")))
        end
        if species.hidden_abilities.length > 0 && species.hidden_abilities != base_species.hidden_abilities
          f.write(sprintf("HiddenAbilities = %s\r\n", species.hidden_abilities.join(",")))
        end
        if species.moves.length > 0 && species.moves != base_species.moves
          f.write(sprintf("Moves = %s\r\n", species.moves.join(",")))
        end
        if species.tutor_moves.length > 0 && species.tutor_moves != base_species.tutor_moves
          f.write(sprintf("TutorMoves = %s\r\n", species.tutor_moves.join(",")))
        end
        if species.egg_moves.length > 0 && species.egg_moves != base_species.egg_moves
          f.write(sprintf("EggMoves = %s\r\n", species.egg_moves.join(",")))
        end
        if species.egg_groups.length > 0 && species.egg_groups != base_species.egg_groups
          f.write(sprintf("EggGroups = %s\r\n", species.egg_groups.join(",")))
        end
        f.write(sprintf("HatchSteps = %d\r\n", species.hatch_steps)) if species.hatch_steps != base_species.hatch_steps
        if species.offspring.length > 0 && species.offspring != base_species.offspring
          f.write(sprintf("Offspring = %s\r\n", species.offspring.join(",")))
        end
        f.write(sprintf("Height = %.1f\r\n", species.height / 10.0)) if species.height != base_species.height
        f.write(sprintf("Weight = %.1f\r\n", species.weight / 10.0)) if species.weight != base_species.weight
        f.write(sprintf("Color = %s\r\n", species.color)) if species.color != base_species.color
        f.write(sprintf("Shape = %s\r\n", species.shape)) if species.shape != base_species.shape
        if species.habitat != :None && species.habitat != base_species.habitat
          f.write(sprintf("Habitat = %s\r\n", species.habitat))
        end
        f.write(sprintf("Category = %s\r\n", species.real_category)) if species.real_category != base_species.real_category
        f.write(sprintf("Pokedex = %s\r\n", species.real_pokedex_entry)) if species.real_pokedex_entry != base_species.real_pokedex_entry
        f.write(sprintf("Generation = %d\r\n", species.generation)) if species.generation != base_species.generation
        f.write(sprintf("Flags = %s\r\n", species.flags.join(","))) if species.flags.length > 0 && species.flags != base_species.flags
        if species.wild_item_common != base_species.wild_item_common ||
           species.wild_item_uncommon != base_species.wild_item_uncommon ||
           species.wild_item_rare != base_species.wild_item_rare
          f.write(sprintf("WildItemCommon = %s\r\n", species.wild_item_common.join(","))) if species.wild_item_common.length > 0
          f.write(sprintf("WildItemUncommon = %s\r\n", species.wild_item_uncommon.join(","))) if species.wild_item_uncommon.length > 0
          f.write(sprintf("WildItemRare = %s\r\n", species.wild_item_rare.join(","))) if species.wild_item_rare.length > 0
        end
        if species.evolutions != base_species.evolutions && species.evolutions.any? { |evo| !evo[3] }
          f.write("Evolutions = ")
          need_comma = false
          species.evolutions.each do |evo|
            next if evo[3]   # Skip prevolution entries
            f.write(",") if need_comma
            need_comma = true
            evo_type_data = GameData::Evolution.get(evo[1])
            param_type = evo_type_data.parameter
            f.write(sprintf("%s,%s,", evo[0], evo_type_data.id.to_s))
            if !param_type.nil?
              if param_type.is_a?(Symbol) && !GameData.const_defined?(param_type)
                f.write(getConstantName(param_type, evo[2]))
              else
                f.write(evo[2].to_s)
              end
            end
          end
          f.write("\r\n")
        end
      end
    }
    process_pbs_file_message_end
  end

  end

  module GameData
  class Species
    attr_reader :primal_stone
    attr_reader :primal_move
    attr_reader :unprimal_form
    attr_reader :primal_message

    alias old_initialize initialize
    def initialize(hash)
      old_initialize(hash)
      @primal_stone       = hash["PrimalStone"]
      @primal_move        = hash[:primal_move]
      @unprimal_form      = hash[:unprimal_form]        || 0
      @primal_message     = hash[:primal_message]       || 0
      echoln = @primal_stone if @primal_stone != nil
    end

    def pbGetPrimalStone; return @primal_stone; end

    #=========
    def self.schema(compiling_forms = false)
      ret = {
        "FormName"          => [0, "q"],
        "Category"          => [0, "s"],
        "Pokedex"           => [0, "q"],
        "Types"             => [0, "eE", :Type, :Type],
        "BaseStats"         => [0, "vvvvvv"],
        "EVs"               => [0, "*ev", :Stat],
        "BaseExp"           => [0, "v"],
        "CatchRate"         => [0, "u"],
        "Happiness"         => [0, "u"],
        "Moves"             => [0, "*ue", nil, :Move],
        "TutorMoves"        => [0, "*e", :Move],
        "EggMoves"          => [0, "*e", :Move],
        "Abilities"         => [0, "*e", :Ability],
        "HiddenAbilities"   => [0, "*e", :Ability],
        "WildItemCommon"    => [0, "*e", :Item],
        "WildItemUncommon"  => [0, "*e", :Item],
        "WildItemRare"      => [0, "*e", :Item],
        "EggGroups"         => [0, "*e", :EggGroup],
        "HatchSteps"        => [0, "v"],
        "Height"            => [0, "f"],
        "Weight"            => [0, "f"],
        "Color"             => [0, "e", :BodyColor],
        "Shape"             => [0, "e", :BodyShape],
        "Habitat"           => [0, "e", :Habitat],
        "Generation"        => [0, "i"],
        "Flags"             => [0, "*s"],
        "BattlerPlayerX"    => [0, "i"],
        "BattlerPlayerY"    => [0, "i"],
        "BattlerEnemyX"     => [0, "i"],
        "BattlerEnemyY"     => [0, "i"],
        "BattlerAltitude"   => [0, "i"],
        "BattlerShadowX"    => [0, "i"],
        "BattlerShadowSize" => [0, "u"],
        # All properties below here are old names for some properties above.
        # They will be removed in v21.
        "Type1"             => [0, "e", :Type],
        "Type2"             => [0, "e", :Type],
        "Rareness"          => [0, "u"],
        "Compatibility"     => [0, "*e", :EggGroup],
        "Kind"              => [0, "s"],
        "BaseEXP"           => [0, "v"],
        "EffortPoints"      => [0, "*ev", :Stat],
        "HiddenAbility"     => [0, "*e", :Ability],
        "StepsToHatch"      => [0, "v"]
      }
      if compiling_forms
        ret["PokedexForm"]  = [0, "u"]
        ret["Offspring"]    = [0, "*e", :Species]
        ret["Evolutions"]   = [0, "*ees", :Species, :Evolution, nil]
        ret["MegaStone"]    = [0, "e", :Item]
        ret["MegaMove"]     = [0, "e", :Move]
        ret["UnmegaForm"]   = [0, "u"]
        ret["MegaMessage"]  = [0, "u"]
        ret["PrimalStone"]  = [0, "e", :Item]
        ret["PrimalMove"]   = [0, "e", :Move]
        ret["UnprimalForm"] = [0, "u"]
        ret["PrimalMessage"]= [0, "u"]
        echoln "form"
      else
        ret["InternalName"] = [0, "n"]
        ret["Name"]         = [0, "s"]
        ret["GrowthRate"]   = [0, "e", :GrowthRate]
        ret["GenderRatio"]  = [0, "e", :GenderRatio]
        ret["Incense"]      = [0, "e", :Item]
        ret["Offspring"]    = [0, "*s"]
        ret["Evolutions"]   = [0, "*ses", nil, :Evolution, nil]
        # All properties below here are old names for some properties above.
        # They will be removed in v21.
        ret["GenderRate"]   = [0, "e", :GenderRatio]
      end
      return ret
    end

    #======
  end
  end

  class Pokemon

  alias old_hasPrimalForm? hasPrimalForm? 
  def hasPrimalForm?
    return true if old_hasPrimalForm?

    primalForm = self.getPrimalForm
    return primalForm > 0 && primalForm != form_simple
  end

  alias old_primal? primal? 
  def primal?
    return (species_data.pbGetPrimalStone || species_data.primal_move) ? true : false
  end

  alias old_makePrimal makePrimal 
  def makePrimal
    primalForm = self.getPrimalForm
    self.form = primalForm if primalForm > 0
  end

  alias old_makeUnprimal makeUnprimal 
  def makeUnprimal
    unprimalForm = self.getUnprimalForm
    if unprimalForm >= 0
      self.form = unprimalForm
    else
      self.form = 0
    end
  end

  def getPrimalForm
    ret = 0
    GameData::Species.each do |data|
      next if data.species != @species || data.unprimal_form != form_simple
      echoln _INTL("{1} {2} {3} {4}",data.species, data.pbGetPrimalStone != nil,hasItem?(data.pbGetPrimalStone), data.form)
      if data.pbGetPrimalStone && hasItem?(data.pbGetPrimalStone)
        ret = data.form
        break
      elsif data.pbGetPrimalStone && hasMove?(data.primal_move)
        ret = data.form
        break
      end
    end
    return ret   # form number, or 0 if no accessible Primal form
  end

  def primalName
    formName = species_data.form_name
    return (formName && !formName.empty?) ? formName : _INTL("Primal {1}", species_data.name)
  end

  def primalMessage   # 0=default message, 1=Custom message
    primalForm = self.getPrimalForm
    message_number = GameData::Species.get_species_form(@species, primalForm)&.primal_message
    return message_number || 0
  end

  end

  module GameData
  class Item
  def is_primal_stone?;      return has_flag?("Fling_60") || has_flag?("PrimalStone"); end
  end
  end

  class Battle
    alias old_pbPrimalReversion pbPrimalReversion
    def pbPrimalReversion(idxBattler)
      battler = @battlers[idxBattler]
      return if !battler || !battler.pokemon || battler.fainted?
      pbDisplay(_INTL("{1} has Primal {2} - {3}",battler.pbThis, battler.hasPrimal?, battler.primal?))
      return if !battler.hasPrimal? || battler.primal?
      if battler.isSpecies?(:KYOGRE)
        pbCommonAnimation("PrimalKyogre", battler)
      elsif battler.isSpecies?(:GROUDON)
        pbCommonAnimation("PrimalGroudon", battler)
      end
      battler.pokemon.makePrimal
      battler.form = battler.pokemon.form
      battler.pbUpdate(true)
      @scene.pbChangePokemon(battler, battler.pokemon)
      @scene.pbRefreshOne(idxBattler)
      if battler.isSpecies?(:KYOGRE)
        pbCommonAnimation("PrimalKyogre2", battler)
      elsif battler.isSpecies?(:GROUDON)
        pbCommonAnimation("PrimalGroudon2", battler)
      end
      pbDisplay(_INTL("{1}'s Primal Reversion to {2}!\nIt reverted to its primal form!", battler.pbThis, battler.pokemon.primalName))
    end
  end