#===============================================================================
# Revamps base Essentials code related to the player's Pokedex to allow for 
# plugin compatibility.
#===============================================================================


#-------------------------------------------------------------------------------
# Pokedex sprites.
#-------------------------------------------------------------------------------
class PokemonPokedexInfo_Scene
  def pbUpdateDummyPokemon
    @species = @dexlist[@index][0]
    @gender, @form, @shiny, @special = $player.pokedex.last_form_seen(@species)
    @shiny = 0 if !Settings::POKEDEX_SHINY_FORMS
    @special = 0 if @special == 1 && !Settings::POKEDEX_SHADOW_FORMS
    @shadow = (@special == 1)
    @gmax = (@special == 2)
    @celestial = (@special == 3)
    shiny = (@shiny == 2) ? :super_shiny : (@shiny == 1) ? true : false
    metrics_data = GameData::SpeciesMetrics.get_species_form(@species, @form)
    @sprites["infosprite"].setSpeciesBitmap(@species, @gender, @form, shiny, @shadow, false, false, false, @gmax, @celestial)
    @sprites["formfront"]&.setSpeciesBitmap(@species, @gender, @form, shiny, @shadow, false, false, false, @gmax, @celestial)
    if @sprites["formback"]
      @sprites["formback"].setSpeciesBitmap(@species, @gender, @form, shiny, @shadow, true, false, false, @gmax, @celestial)
      @sprites["formback"].y = 256
      @sprites["formback"].y += metrics_data.back_sprite[1] * 2
    end
    @sprites["formicon"]&.pbSetParams(@species, @gender, @form, shiny, @shadow, false, @gmax, @celestial)
    if PluginManager.installed?("Generation 8 Pack Scripts")
      return if defined?(EliteBattle)
      sp_data = GameData::SpeciesMetrics.get_species_form(@species, @form)
      @sprites["infosprite"].constrict([208, 200])
      @sprites["formfront"].constrict([200, 196]) if @sprites["formfront"]
      return if !@sprites["formback"]
      @sprites["formback"].constrict([300, 294])
      return if sp_data.back_sprite_scale == sp_data.front_sprite_scale
      @sprites["formback"].setOffset(PictureOrigin::CENTER)
      @sprites["formback"].y = @sprites["formfront"].y if @sprites["formfront"]
      @sprites["formback"].zoom_x = (sp_data.front_sprite_scale.to_f / sp_data.back_sprite_scale)
      @sprites["formback"].zoom_y = (sp_data.front_sprite_scale.to_f / sp_data.back_sprite_scale)
    end
  end
  
  #-----------------------------------------------------------------------------
  # Gets all displayable species forms. Includes shiny and shadow forms.
  #-----------------------------------------------------------------------------
  def pbGetAvailableForms
    ret = []
    multiple_forms = false
    shiny_checks = (Settings::POKEDEX_SHINY_FORMS) ? 2 : 0
    special_checks = (Settings::POKEDEX_SHADOW_FORMS) ? 2 : 1
    GameData::Species.each do |sp|
      next if sp.species != @species
      next if sp.form != 0 && (!sp.real_form_name || sp.real_form_name.empty?)
      next if sp.pokedex_form != sp.form
      multiple_forms = true if sp.form > 0
      if sp.single_gendered?
        real_gender = (sp.gender_ratio == :AlwaysFemale) ? 1 : 0
        form_gender = (sp.gender_ratio == :Genderless)   ? 2 : real_gender + 3
        for i in 0...special_checks
          for j in 0..shiny_checks
            if $player.pokedex.seen_form?(@species, real_gender, sp.form, j, i)
              ret.push([sp.form_name, form_gender, sp.form, j, i]) if sp.bitmap_exists?("Front", false, j, i)
            end
          end
        end
      else
        2.times do |real_gender|
          show_all_forms = true
          for i in 0...special_checks
            form_gender = (sp.bitmap_exists?("Front", true, 0, i)) ? real_gender : real_gender + 3
            for j in 0..shiny_checks
              if $player.pokedex.seen_form?(@species, real_gender, sp.form, j, i) || (Settings::DEX_SHOWS_ALL_FORMS && show_all_forms)
                ret.push([sp.form_name, form_gender, sp.form, j, i]) if sp.bitmap_exists?("Front", real_gender == 1, j, i)
              end
              show_all_forms = false
            end
          end
        end
      end
      #-------------------------------------------------------------------------
      # Plugin-specific forms
      #-------------------------------------------------------------------------
      if PluginManager.installed?("ZUD Mechanics")
        ret = pbAddGmaxForms(sp, ret, shiny_checks)
      end
      if PluginManager.installed?("Pokémon Birthsigns")
        ret = pbAddCelestialForms(sp, ret, shiny_checks)
      end
    end
    ret.compact!
    ret.uniq!
    ret.each do |entry|
      form_name = ""
      case entry[3]
      when 1 then form_name += _INTL("Shiny")
      when 2 then form_name += _INTL("Super Shiny")
      end
      if nil_or_empty?(entry[0])
        case entry[4]
        when 1 then special_form = _INTL("Shadow")
        when 2 then special_form = _INTL("Gigantamax")
        when 3 then special_form = _INTL("Celestial")
        end
        if !nil_or_empty?(special_form)
          form_name += " " if !nil_or_empty?(form_name)
          form_name += special_form 
        end
      else
        form_name += " " if !nil_or_empty?(form_name)
        form_name += entry[0]
      end		
      case entry[1]
      when 0 then gender_form = _INTL("Male")
      when 1 then gender_form = _INTL("Female")
      when 2 then gender_form = _INTL("One Form") if nil_or_empty?(entry[0]) && multiple_forms
      end
      if !nil_or_empty?(gender_form)
        form_name += " " if !nil_or_empty?(form_name)
        form_name += gender_form
      end
      entry[0]  = _INTL("{1}", form_name)
      entry[1] -= 3 if entry[1] > 2
      entry[1]  = 0 if entry[1] >= 2
    end
    return ret
  end
  
  def pbChooseForm
    index = 0
    @available.length.times do |i|
      if @available[i][1] == @gender && 
         @available[i][2] == @form   &&
         @available[i][3] == @shiny  &&
         @available[i][4] == @special
        index = i
        break
      end
    end
    oldindex = -1
    loop do
      if oldindex != index
        $player.pokedex.set_last_form_seen(@species, 
          @available[index][1], # Gender
          @available[index][2], # Form
          @available[index][3], # Shiny
          @available[index][4]  # Special
        )
        pbUpdateDummyPokemon
        drawPage(@page)
        @sprites["uparrow"].visible   = (index > 0)
        @sprites["downarrow"].visible = (index < @available.length - 1)
        oldindex = index
      end
      Graphics.update
      Input.update
      pbUpdate
      if Input.trigger?(Input::UP)
        pbPlayCursorSE
        index = (index + @available.length - 1) % @available.length
      elsif Input.trigger?(Input::DOWN)
        pbPlayCursorSE
        index = (index + 1) % @available.length
      elsif Input.trigger?(Input::BACK)
        pbPlayCancelSE
        break
      elsif Input.trigger?(Input::USE)
        pbPlayDecisionSE
        break
      end
    end
    @sprites["uparrow"].visible   = false
    @sprites["downarrow"].visible = false
  end
  
  def drawPageForms
    @sprites["background"].setBitmap(_INTL("Graphics/Pictures/Pokedex/bg_forms"))
    overlay = @sprites["overlay"].bitmap
    base   = Color.new(88, 88, 80)
    shadow = Color.new(168, 184, 184)
    formname = ""
    @available.each do |i|
      if i[1] == @gender && 
         i[2] == @form   &&
         i[3] == @shiny  &&
         i[4] == @special
        formname = i[0]
        break
      end
    end
    textpos = [
      [GameData::Species.get(@species).name, Graphics.width / 2, Graphics.height - 82, 2, base, shadow],
      [formname, Graphics.width / 2, Graphics.height - 50, 2, base, shadow]
    ]
    pbDrawTextPositions(overlay, textpos)
  end
end

class PokemonPokedex_Scene
  def setIconBitmap(species)
    gender, form, shiny, special = $player.pokedex.last_form_seen(species)
    shiny = 0 if !Settings::POKEDEX_SHINY_FORMS
    special = 0 if special == 1 && !Settings::POKEDEX_SHADOW_FORMS
    shiny = (shiny == 2) ? :super_shiny : (shiny == 1) ? true : false
    shadow = (special == 1)
    gmax = (special == 2)
    celestial = (special == 3)
    poke_data = [species, gender, form, shiny, shadow, false, false, false, gmax, celestial]
    @sprites["icon"].setSpeciesBitmap(*poke_data)
    if PluginManager.installed?("Generation 8 Pack Scripts")
      @sprites["icon"].constrict([224, 216]) if !defined?(EliteBattle)
    end
  end
  
  def pbGetDexList
    region = pbGetPokedexRegion
    regionalSpecies = pbAllRegionalSpecies(region)
    if !regionalSpecies || regionalSpecies.length == 0
      regionalSpecies = []
      GameData::Species.each_species { |s| regionalSpecies.push(s.id) }
    end
    shift = Settings::DEXES_WITH_OFFSETS.include?(region)
    ret = []
    regionalSpecies.each_with_index do |species, i|
      next if !species
      next if !pbCanAddForModeList?($PokemonGlobal.pokedexMode, species)
      _gender, form, _shiny, _special = $player.pokedex.last_form_seen(species)
      species_data = GameData::Species.get_species_form(species, form)
      color  = species_data.color
      type1  = species_data.types[0]
      type2  = species_data.types[1] || type1
      shape  = species_data.shape
      height = species_data.height
      weight = species_data.weight
      ret.push([species, species_data.name, height, weight, i + 1, shift, type1, type2, color, shape])
    end
    return ret
  end
end


#-------------------------------------------------------------------------------
# Allows for special forms to be recorded in the Pokedex.
#-------------------------------------------------------------------------------
class Player < Trainer
  class Pokedex
    def seen_form?(species, gender, form, shiny = nil, special = nil)
      species_id = GameData::Species.try_get(species)&.species
      return false if species_id.nil?
      @seen_forms[species_id] ||= [# [   Regular    ]  [    Shiny     ]  [  Super Shiny ]
                                   [ [[], [], [], []], [[], [], [], []], [[], [], [], []] ], # Male
                                   [ [[], [], [], []], [[], [], [], []], [[], [], [], []] ]  # Female
                                  ]
      if shiny.nil? && special.nil?
        shiny = special = 0
        ret = nil
        9.times do |i|
          ret = @seen_forms[species_id][gender][shiny][special][form]
          break if !ret.nil?
          special += 1
          special = 0 if special > 2
          shiny += 1 if ((i + 1) % 3) == 0
        end
        return ret == true
      end
      shiny = 0 if shiny.nil? || !Settings::POKEDEX_SHINY_FORMS
      special = 0 if special.nil? || special == 1 && !Settings::POKEDEX_SHADOW_FORMS
      return @seen_forms[species_id][gender][shiny][special][form] == true
    end
    
    def seen_forms_count(species)
      species_id = GameData::Species.try_get(species)&.species
      return 0 if species_id.nil?
      ret = 0
      @seen_forms[species_id] ||= [# [   Regular    ]  [    Shiny     ]  [  Super Shiny ]
                                   [ [[], [], [], []], [[], [], [], []], [[], [], [], []] ], # Male
                                   [ [[], [], [], []], [[], [], [], []], [[], [], [], []] ]  # Female
                                  ]
      array = @seen_forms[species_id]
      [array[0].length, array[1].length].max.times do |i|
        ret += 1 if array[0][0][0][i] ||  # male, regular, base
                    array[0][1][0][i] ||  # male, shiny, base
                    array[0][2][0][i] ||  # male, super shiny, base
                    array[1][0][0][i] ||  # female, regular, base
                    array[1][1][0][i] ||  # female, shiny, base
                    array[1][2][0][i] ||  # female, super shiny, base
                    # Shadow Sprites
                    array[0][0][1][i] ||  # male, regular, shadow
                    array[0][1][1][i] ||  # male, shiny, shadow
                    array[0][2][1][i] ||  # male, super shiny, shadow
                    array[1][0][1][i] ||  # female, regular, shadow
                    array[1][1][1][i] ||  # female, shiny, shadow
                    array[1][2][1][i] ||  # female, super shiny, shadow
                    # Gigantamax Sprites
                    array[0][0][2][i] ||  # male, regular, gmax
                    array[0][1][2][i] ||  # male, shiny, gmax
                    array[0][2][2][i] ||  # male, super shiny, gmax
                    array[1][0][2][i] ||  # female, regular, gmax
                    array[1][1][2][i] ||  # female, shiny, gmax
                    array[1][2][2][i] ||  # female, super shiny, gmax
                    # Celestial Sprites
                    array[0][0][3][i] ||  # male, regular, celestial
                    array[0][1][3][i] ||  # male, shiny, celestial
                    array[0][2][3][i] ||  # male, super shiny, celestial
                    array[1][0][3][i] ||  # female, regular, celestial
                    array[1][1][3][i] ||  # female, shiny, celestial
                    array[1][2][3][i]     # female, super shiny, celestial
      end
      return ret
    end
    
    def last_form_seen(species)
      @last_seen_forms[species] ||= []
      return @last_seen_forms[species][0] || 0, 
             @last_seen_forms[species][1] || 0, 
             @last_seen_forms[species][2] || 0, 
             @last_seen_forms[species][3] || 0
    end
    
    def set_last_form_seen(species, gender = 0, form = 0, shiny = 0, special = 0)
      shiny = 0 if !Settings::POKEDEX_SHINY_FORMS
      special = 0 if special == 1 && !Settings::POKEDEX_SHADOW_FORMS
      @last_seen_forms[species] = [gender, form, shiny, special]
    end
    
    def register(species, gender = 0, form = 0, shiny = 0, should_refresh_dexes = true, special = 0)
      if species.is_a?(Pokemon)
        species_data = species.species_data
        gender = species.gender
        shiny = (!Settings::POKEDEX_SHINY_FORMS) ? 0 : (species.super_shiny?) ? 2 : (species.shiny?) ? 1 : 0
        special = (species.shadowPokemon? && Settings::POKEDEX_SHADOW_FORMS) ? 1 : (species.gmax?) ? 2 : (species.celestial?) ? 3 : 0
      else
        species_data = GameData::Species.get_species_form(species, form)
      end
      species = species_data.species
      gender = 0 if gender >= 2
      form = species_data.form
      shiny = 1 if shiny == true
      special = 1 if special == true
      if form != species_data.pokedex_form
        species_data = GameData::Species.get_species_form(species, species_data.pokedex_form)
        form = species_data.form
      end
      form = 0 if species_data.form_name.nil? || species_data.form_name.empty?
      @seen[species] = true
      @seen_forms[species] ||= [# [   Regular    ]  [    Shiny     ]  [  Super Shiny ]
                                [ [[], [], [], []], [[], [], [], []], [[], [], [], []] ], # Male
                                [ [[], [], [], []], [[], [], [], []], [[], [], [], []] ]  # Female
                               ]
      @seen_forms[species][gender][shiny][special][form] = true
      @last_seen_forms[species] ||= []
      @last_seen_forms[species] = [gender, form, shiny, special] if @last_seen_forms[species] == []
      self.refresh_accessible_dexes if should_refresh_dexes
    end
    
    def register_last_seen(pkmn)
      validate pkmn => Pokemon
      species_data = pkmn.species_data
      form = species_data.pokedex_form
      form = 0 if species_data.form_name.nil? || species_data.form_name.empty?
      shiny = (!Settings::POKEDEX_SHINY_FORMS) ? 0 : (pkmn.super_shiny?) ? 2 : (pkmn.shiny?) ? 1 : 0
      special = (pkmn.shadowPokemon? && Settings::POKEDEX_SHADOW_FORMS) ? 1 : (pkmn.gmax?) ? 2 : (pkmn.celestial?) ? 3 : 0
      @last_seen_forms[pkmn.species] = [pkmn.gender, form, shiny, special]
    end
	
    def set_shadow_pokemon_owned(species)
      species_id = GameData::Species.try_get(species)&.species
      return if species_id.nil?
      @owned_shadow[species_id] = true
      @owned_shadow[species] = true if species != species_id 
      self.refresh_accessible_dexes
    end
	
    def owned_shadow_pokemon?(species)
      species_id = GameData::Species.try_get(species)&.species
      return false if species_id.nil?
      return @owned_shadow[species] || @owned_shadow[species_id]
    end
	
    def owned_shadow_species?(species)
      species_id = GameData::Species.try_get(species)&.id
      return false if species_id.nil?
      return @owned_shadow[species] == true
    end
  end
end