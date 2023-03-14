class PokemonPokedexInfo_Scene
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
    # Write various bits of text
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
      # Write the category
      textpos.push([_INTL("{1} Pokémon", species_data.category), 246, 80, 0, base, shadow])
      # Write the height and weight
      if !@show_battled_count
        height = species_data.height
        weight = species_data.weight
        if System.user_language[3..4] == "US"   # If the user is in the United States
          inches = (height / 0.254).round
          pounds = (weight / 0.45359).round
          textpos.push([_ISPRINTF("{1:d}'{2:02d}\"", inches / 12, inches % 12), 460, 164, 1, base, shadow])
          textpos.push([_ISPRINTF("{1:4.1f} lbs.", pounds / 10.0), 494, 196, 1, base, shadow])
        else
          textpos.push([_ISPRINTF("{1:.1f} m", height / 10.0), 470, 164, 1, base, shadow])
          textpos.push([_ISPRINTF("{1:.1f} kg", weight / 10.0), 482, 196, 1, base, shadow])
        end
      end
      # Draw the Pokédex entry text
      drawTextEx(overlay, 40, 246, Graphics.width - (40 * 2), 4,   # overlay, x, y, width, num lines
                 species_data.pokedex_entry, base, shadow)
      # Draw the footprint
      if Settings::DEX_SHOWS_FOOTPRINTS
        footprintfile = GameData::Species.footprint_filename(@species, @form)
      else
        footprintfile = GameData::Species.icon_filename(@species, @form)
      end
      if footprintfile
        split = footprintfile.split("/")
        path  = split[0...split.length - 1].join("/"); name  = split[split.length - 1]
        footprint = RPG::Cache.load_bitmap(path + "/", name)
        if Settings::DEX_SHOWS_FOOTPRINTS
          overlay.blt(226, 138, footprint, footprint.rect)
        else
          min_width  = (((footprint.width >= footprint.height * 2) ? footprint.height : footprint.width) - 64)/2
          min_height = [(footprint.height - 56)/2 , 0].max
          overlay.blt(210, 130, footprint, Rect.new(min_width, min_height, 64, 56))
        end
      end
      # Show the owned icon
      imagepos.push(["Graphics/Pictures/Pokedex/icon_own", 212, 44])
      # Draw the type icon(s)
      species_data.types.each_with_index do |type, i|
        type_number = GameData::Type.get(type).icon_position
        type_rect = Rect.new(0, type_number * 32, 96, 32)
        overlay.blt(296 + (100 * i), 120, @typebitmap.bitmap, type_rect)
      end
    else
      # Write the category
      textpos.push([_INTL("????? Pokémon"), 246, 80, 0, base, shadow])
      # Write the height and weight
      if !@show_battled_count
        if System.user_language[3..4] == "US"   # If the user is in the United States
          textpos.push([_INTL("???'??\""), 460, 164, 1, base, shadow])
          textpos.push([_INTL("????.? lbs."), 494, 196, 1, base, shadow])
        else
          textpos.push([_INTL("????.? m"), 470, 164, 1, base, shadow])
          textpos.push([_INTL("????.? kg"), 482, 196, 1, base, shadow])
        end
      end
    end
    # Draw all text
    pbDrawTextPositions(overlay, textpos)
    # Draw all images
    pbDrawImagePositions(overlay, imagepos)
  end
end
