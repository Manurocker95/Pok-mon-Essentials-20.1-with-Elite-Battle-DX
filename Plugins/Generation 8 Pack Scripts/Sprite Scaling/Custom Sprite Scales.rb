#-------------------------------------------------------------------------------
# Extensions to the species metrics to allow for custom sprite scaling
#-------------------------------------------------------------------------------
module GameData
  class SpeciesMetrics

    attr_accessor :front_sprite_scale
    attr_accessor :back_sprite_scale

    SCHEMA = {
      "BackSprite"          => [0, "ii"],
      "FrontSprite"         => [0, "ii"],
      "FrontSpriteAltitude" => [0, "i"],
      "ShadowX"             => [0, "i"],
      "ShadowSize"          => [0, "u"],
      "FrontSpriteScale"  => [0, "i"],
      "BackSpriteScale"   => [0, "i"],
    }

    def self.get_species_form(species, form)
      return nil if !species || !form
      validate species => [Symbol, String]
      validate form => Integer
      raise _INTL("Undefined species {1}.", species) if !GameData::Species.exists?(species)
      species = species.to_sym if species.is_a?(String)
      if form > 0
        trial = sprintf("%s_%d", species, form).to_sym
        if !DATA.has_key?(trial)
          self.register({ :id => species }) if !DATA[species]
          self.register({
            :id                    => trial,
            :species               => species,
            :form                  => form,
            :back_sprite           => DATA[species].back_sprite.clone,
            :front_sprite          => DATA[species].front_sprite.clone,
            :front_sprite_altitude => DATA[species].front_sprite_altitude,
            :shadow_x              => DATA[species].shadow_x,
            :shadow_size           => DATA[species].shadow_size,
            :front_sprite_scale    => DATA[species].front_sprite_scale,
            :back_sprite_scale     => DATA[species].back_sprite_scale
          })
        end
        return DATA[trial]
      end
      self.register({ :id => species }) if !DATA[species]
      return DATA[species]
    end

    alias __gen8__initialize initialize unless private_method_defined?(:__gen8__initialize)
    def initialize(hash)
      __gen8__initialize(hash)
      @front_sprite_scale = hash[:front_sprite_scale] || Settings::FRONT_BATTLER_SPRITE_SCALE
      @back_sprite_scale  = hash[:back_sprite_scale]  || Settings::BACK_BATTLER_SPRITE_SCALE
    end
  end
end

#-------------------------------------------------------------------------------
# Extensions to the compiler species metrics to allow for custom sprite scales
#-------------------------------------------------------------------------------
module Compiler
  module_function
  #-----------------------------------------------------------------------------
  # Make sure the sprite scales are written in the PBS
  #-----------------------------------------------------------------------------
  def write_pokemon_metrics(path = "PBS/pokemon_metrics.txt")
    write_pbs_file_message_start(path)
    # Get in species order then in form order
    sort_array = []
    dex_numbers = {}
    i = 0
    GameData::SpeciesMetrics.each do |metrics|
      dex_numbers[metrics.species] = i if !dex_numbers[metrics.species]
      sort_array.push([dex_numbers[metrics.species], metrics.id, metrics.species, metrics.form])
      i += 1
    end
    sort_array.sort! { |a, b| (a[0] == b[0]) ? a[3] <=> b[3] : a[0] <=> b[0] }
    # Write file
    File.open(path, "wb") { |f|
      idx = 0
      add_PBS_header_to_file(f)
      sort_array.each do |val|
        echo "." if idx % 50 == 0
        idx += 1
        Graphics.update if idx % 250 == 0
        species = GameData::SpeciesMetrics.get(val[1])
        if species.form > 0
          base_species = GameData::SpeciesMetrics.get(val[2])
          next if species.back_sprite == base_species.back_sprite &&
                  species.front_sprite == base_species.front_sprite &&
                  species.front_sprite_altitude == base_species.front_sprite_altitude &&
                  species.shadow_x == base_species.shadow_x &&
                  species.shadow_size == base_species.shadow_size
        else
          next if species.back_sprite == [0, 0] && species.front_sprite == [0, 0] &&
                  species.front_sprite_altitude == 0 &&
                  species.shadow_x == 0 && species.shadow_size == 2
        end
        f.write("\#-------------------------------\r\n")
        if species.form > 0
          f.write(sprintf("[%s,%d]\r\n", species.species, species.form))
        else
          f.write(sprintf("[%s]\r\n", species.species))
        end
        f.write(sprintf("BackSprite = %s\r\n", species.back_sprite.join(",")))
        f.write(sprintf("FrontSprite = %s\r\n", species.front_sprite.join(",")))
        f.write(sprintf("FrontSpriteAltitude = %d\r\n", species.front_sprite_altitude)) if species.front_sprite_altitude != 0
        f.write(sprintf("ShadowX = %d\r\n", species.shadow_x))
        f.write(sprintf("ShadowSize = %d\r\n", species.shadow_size))
        f.write(sprintf("FrontSpriteScale = %d\r\n", species.front_sprite_scale)) if species.front_sprite_scale != Settings::FRONT_BATTLER_SPRITE_SCALE
        f.write(sprintf("BackSpriteScale = %d\r\n", species.back_sprite_scale)) if species.back_sprite_scale != Settings::BACK_BATTLER_SPRITE_SCALE
      end
    }
    process_pbs_file_message_end
  end
  #-----------------------------------------------------------------------------
  # Make sure the sprite scales are written in the PBS
  #-----------------------------------------------------------------------------
  def compile_pokemon_metrics(path = "PBS/pokemon_metrics.txt")
    return if !safeExists?(path)
    compile_pbs_file_message_start(path)
    schema = GameData::SpeciesMetrics::SCHEMA
    # Read from PBS file
    File.open(path, "rb") { |f|
      FileLineData.file = path   # For error reporting
      # Read a whole section's lines at once, then run through this code.
      # contents is a hash containing all the XXX=YYY lines in that section, where
      # the keys are the XXX and the values are the YYY (as unprocessed strings).
      idx = 0
      pbEachFileSection(f) { |contents, section_name|
        echo "." if idx % 50 == 0
        idx += 1
        Graphics.update if idx % 250 == 0
        FileLineData.setSection(section_name, "header", nil)   # For error reporting
        # Split section_name into a species number and form number
        split_section_name = section_name.split(/[-,\s]/)
        if split_section_name.length == 0 || split_section_name.length > 2
          raise _INTL("Section name {1} is invalid ({2}). Expected syntax like [XXX] or [XXX,Y] (XXX=species ID, Y=form number).", section_name, path)
        end
        species_symbol = csvEnumField!(split_section_name[0], :Species, nil, nil)
        form           = (split_section_name[1]) ? csvPosInt!(split_section_name[1]) : 0
        # Go through schema hash of compilable data and compile this section
        schema.keys.each do |key|
          # Skip empty properties (none are required)
          if nil_or_empty?(contents[key])
            contents[key] = nil
            next
          end
          FileLineData.setSection(section_name, key, contents[key])   # For error reporting
          # Compile value for key
          value = pbGetCsvRecord(contents[key], key, schema[key])
          value = nil if value.is_a?(Array) && value.length == 0
          contents[key] = value
        end
        # Construct species hash
        form_symbol = (form > 0) ? sprintf("%s_%d", species_symbol.to_s, form).to_sym : species_symbol
        species_hash = {
          :id                    => form_symbol,
          :species               => species_symbol,
          :form                  => form,
          :back_sprite           => contents["BackSprite"],
          :front_sprite          => contents["FrontSprite"],
          :front_sprite_altitude => contents["FrontSpriteAltitude"],
          :shadow_x              => contents["ShadowX"],
          :shadow_size           => contents["ShadowSize"],
          :front_sprite_scale    => contents["FrontSpriteScale"],
          :back_sprite_scale     => contents["BackSpriteScale"],
        }
        # Add form's data to records
        GameData::SpeciesMetrics.register(species_hash)
      }
    }
    # Save all data
    GameData::SpeciesMetrics.save
    process_pbs_file_message_end
  end
end

#-------------------------------------------------------------------------------
# Make sure the pokemon sprite scales are properly compiled
#-------------------------------------------------------------------------------
module GameData
  class << self
    alias __gen8__load_all load_all unless method_defined?(:__gen8__load_all)
  end

  def self.load_all(*args)
    __gen8__load_all(*args)
    return if !$DEBUG
    key = GameData::SpeciesMetrics::DATA.keys.first
    Compiler.compile_pokemon_metrics if GameData::SpeciesMetrics.get(key).front_sprite_scale.nil?
    SpeciesMetrics.load
  end
end
