#===============================================================================
# Adds G-Max data to the Pokedex.
#===============================================================================
class PokemonPokedexInfo_Scene
  #-----------------------------------------------------------------------------
  # Adds G-Max forms to a species's form list.
  #-----------------------------------------------------------------------------
  def pbAddGmaxForms(species, form_array, checks = 1)
    if GameData::PowerMove.species_list("G-Max").include?(species.id)
      case species.species
      when :TOXTRICITY then gmax_form = 1
      when :ALCREMIE   then gmax_form = 62
      else                  gmax_form = species.form
      end
      return form_array if gmax_form > species.form
      gmax_name = (species.gmax_form_name) ? species.gmax_form_name : _INTL("Gigantamax #{species.name}")
      2.times do |real_gender|
        for i in 0..checks
          if $player.pokedex.seen_form?(@species, real_gender, species.form, i, 2) || Settings::DEX_SHOWS_ALL_FORMS
            data = [gmax_name, 3, gmax_form, i, 2]
            form_array.push(data) if !form_array.include?(data) && species.bitmap_exists?("Front", real_gender == 1, i, 2)
          end
        end
      end
    end
    return form_array
  end

  #-----------------------------------------------------------------------------
  # Draws G-Max info.
  #-----------------------------------------------------------------------------
  def drawPageInfo
    @sprites["background"].setBitmap("Graphics/Pictures/Pokedex/bg_info")
    overlay = @sprites["overlay"].bitmap
    base   = Color.new(88, 88, 80)
    shadow = Color.new(168, 184, 184)
    imagepos = []
    if @brief
      imagepos.push(["Graphics/Pictures/Pokedex/overlay_info", 0, 0])
    end
    species_data = GameData::Species.get_species_form(@species, @form)
    indexText = "???"
    if @dexlist[@index][4] > 0
      indexNumber = @dexlist[@index][4]
      indexNumber -= 1 if @dexlist[@index][5]
      indexText = sprintf("%03d", indexNumber)
    end
    textpos = [
      [_INTL("{1}{2} {3}", indexText, " ", species_data.name),
       246, 48, 0, Color.new(248, 248, 248), Color.new(0, 0, 0)]
    ]
    if @show_battled_count
      textpos.push([_INTL("Number Battled"), 314, 164, 0, base, shadow])
      textpos.push([$player.pokedex.battled_count(@species).to_s, 452, 196, 1, base, shadow])
    else
      textpos.push([_INTL("Height"), 314, 164, 0, base, shadow])
      textpos.push([_INTL("Weight"), 314, 196, 0, base, shadow])
    end
    if $player.owned?(@species)
      textpos.push([_INTL("{1} Pokémon", species_data.category), 246, 80, 0, base, shadow])
      if !@show_battled_count
        height = (@gmax) ? species_data.gmax_height : species_data.height
        weight = species_data.weight
        if System.user_language[3..4] == "US"
          inches = (height / 0.254).round
          pounds = (@gmax) ? _INTL("????.? lbs.") : _ISPRINTF("{1:4.1f} lbs.", (weight / 0.45359).round / 10.0)
          textpos.push([_ISPRINTF("{1:d}'{2:02d}\"", inches / 12, inches % 12), 460, 164, 1, base, shadow])
          textpos.push([pounds, 494, 196, 1, base, shadow])
        else
          kilograms = (@gmax) ? _INTL("????.? kg") : _ISPRINTF("{1:.1f} kg", weight / 10.0)
          textpos.push([_ISPRINTF("{1:.1f} m", height / 10.0), 470, 164, 1, base, shadow])
          textpos.push([kilograms, 482, 196, 1, base, shadow])
        end
      end
      dexentry = (@gmax) ? species_data.gmax_dex_entry : species_data.pokedex_entry
      drawTextEx(overlay, 40, 246, Graphics.width - (40 * 2), 4, dexentry, base, shadow)
      if PluginManager.installed?("Generation 8 Pack Scripts")
        if Settings::DEX_SHOWS_FOOTPRINTS
          footprintfile = GameData::Species.footprint_filename(@species, @form, @gmax)
        else
		  shiny = (@shiny == 2) ? :super_shiny : (@shiny == 1) ? true : false
          footprintfile = GameData::Species.icon_filename(@species, @form, @gender, shiny, @shadow, false, false, @gmax, @celestial)
        end
      else
        footprintfile = GameData::Species.footprint_filename(@species, @form, @gmax)
      end
      if footprintfile
        split = footprintfile.split("/")
        path  = split[0...split.length - 1].join("/"); name  = split[split.length - 1]
        footprint = RPG::Cache.load_bitmap(path + "/", name)
        if PluginManager.installed?("Generation 8 Pack Scripts")
          if Settings::DEX_SHOWS_FOOTPRINTS
            overlay.blt(226, 138, footprint, footprint.rect)
          else
            min_width  = (((footprint.width >= footprint.height * 2) ? footprint.height : footprint.width) - 64)/2
            min_height = [(footprint.height - 56)/2 , 0].max
            overlay.blt(210, 130, footprint, Rect.new(min_width, min_height, 64, 56))
          end
        else
          overlay.blt(226, 138, footprint, footprint.rect)
        end
        footprint.dispose
      end
      imagepos.push(["Graphics/Pictures/Pokedex/icon_own", 212, 44])
      species_data.types.each_with_index do |type, i|
        type_number = GameData::Type.get(type).icon_position
        type_rect = Rect.new(0, type_number * 32, 96, 32)
        overlay.blt(296 + (100 * i), 120, @typebitmap.bitmap, type_rect)
      end
    else
      textpos.push([_INTL("????? Pokémon"), 246, 80, 0, base, shadow])
      if !@show_battled_count
        if System.user_language[3..4] == "US"
          textpos.push([_INTL("???'??\""), 460, 164, 1, base, shadow])
          textpos.push([_INTL("????.? lbs."), 494, 196, 1, base, shadow])
        else
          textpos.push([_INTL("????.? m"), 470, 164, 1, base, shadow])
          textpos.push([_INTL("????.? kg"), 482, 196, 1, base, shadow])
        end
      end
    end
    pbDrawTextPositions(overlay, textpos)
    pbDrawImagePositions(overlay, imagepos)
  end
end