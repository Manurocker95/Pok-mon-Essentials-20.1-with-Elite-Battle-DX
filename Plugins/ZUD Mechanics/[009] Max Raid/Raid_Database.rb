#===============================================================================
# Draws an entire page of species sprites to appear in the Database.
#===============================================================================
class PokemonDatabaseSprite < Sprite
  def initialize(list, page, viewport = nil)
    super(viewport)
    @pokemonsprites = []
    xpos = 0
    ypos = 42
    offset = 1
    RaidDataScene::PAGE_SIZE.times do |i|
      index = RaidDataScene::PAGE_SIZE * page + i
      break if index > list.length - 1
      @pokemonsprites[i] = nil
      pokemon = list[index]
      case pokemon
      when :WISHIWASHI then pokemon = :WISHIWASHI_1
      when :PALAFIN    then pokemon = :PALAFIN_1
      end
      offset += 1 if i >= RaidDataScene::ROW_SIZE * offset
      @pokemonsprites[i] = PokemonSpeciesIconSprite.new(pokemon, viewport)
      @pokemonsprites[i].viewport = self.viewport
      @pokemonsprites[i].zoom_x = 0.5
      @pokemonsprites[i].zoom_y = 0.5
      xpos = 0 if xpos >= RaidDataScene::ROW_SIZE * RaidDataScene::ICON_GAP
      xpos += RaidDataScene::ICON_GAP
      @pokemonsprites[i].x = xpos
      @pokemonsprites[i].y = ypos + RaidDataScene::ICON_GAP * offset
    end
    @contents = BitmapWrapper.new(324, 296)
    self.bitmap = @contents
    self.x = 0
    self.y = 0
  end
  
  def dispose
    if !disposed?
      RaidDataScene::PAGE_SIZE.times do |i|
        @pokemonsprites[i]&.dispose
        @pokemonsprites[i] = nil
      end
      @contents.dispose
      super
    end
  end
  
  def visible=(value)
    super
    RaidDataScene::PAGE_SIZE.times do |i|
      if @pokemonsprites[i] && !@pokemonsprites[i].disposed?
        @pokemonsprites[i].visible = value
      end
    end
  end
  
  def getPokemon(index)
    return @pokemonsprites[index]
  end
  
  def update
    @pokemonsprites.each { |s| s.update }
  end
end


#===============================================================================
# Max Raid Database
#===============================================================================
class RaidDataScene
  PAGE_SIZE = 98
  ROW_SIZE  = 14
  ICON_GAP  = 32
  BASE      = Color.new(248, 248, 248)
  SHADOW    = Color.new(104, 104, 104)
  
  def pbUpdate
    pbUpdateSpriteHash(@sprites)
  end
  
  def pbEndScene
    pbPlayCloseMenuSE
    pbFadeOutAndHide(@sprites) { pbUpdate }
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
  end
  
  #-----------------------------------------------------------------------------
  # Gets the appropriate form name to display.
  #-----------------------------------------------------------------------------
  def pbRaidFormName(species, dataPage = false)
    poke = GameData::Species.get(species)
    form_name = poke.form_name || ""
    if dataPage
      hide_base_name = [:CASTFORM, :ROTOM, :GIRATINA, :ARCEUS, :KYUREM, :KELDEO, :MELOETTA, 
                        :GENESECT, :FURFROU, :AEGISLASH, :XERNEAS, :ZYGARDE, :WISHIWASHI, 
                        :SILVALLY, :MIMIKYU, :CRAMORANT, :EISCUE, :MORPEKO, :GIMMIGHOUL]
      form_name = "" if hide_base_name.include?(poke.id)
      form_name = "Own Tempo" if poke.species == :ROCKRUFF && poke.form != 0
      form_name = form_name[0..12] + "..." if form_name.length > 15
      return _INTL("{1}", form_name)
    else
      show_base_name = [:BURMY, :WORMADAM, :BASCULIN, :DEERLING, :SAWSBUCK, :MEOWSTIC, 
                        :ORICORIO, :LYCANROC, :INDEEDEE, :TOXTRICITY, :URSHIFU, :BASCULEGION]
      if show_base_name.include?(poke.id) || poke.form > 0
        form_name = form_name[0..10] + "..." if form_name.length > 13
        return _INTL("{1} ({2})", poke.name, form_name) if form_name
      else
        return _INTL("{1}", poke.name)
      end
    end
  end
  
  #-----------------------------------------------------------------------------
  # Initializes scene.
  #-----------------------------------------------------------------------------
  def pbStartScene
    @sprites     = {}
    @viewport    = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z  = 99999
    @path = "Graphics/Plugins/ZUD/Raid Database/"
    @sprites["screen"]  = IconSprite.new(0, 0, @viewport)
    @sprites["screen"].setBitmap(@path + "data_menu")
    @sprites["search"]  = IconSprite.new(0, 0, @viewport)
    @sprites["search"].setBitmap(@path + "data_search")
    @sprites["search"].visible = false
    @sprites["results"] = IconSprite.new(0, 0, @viewport)
    @sprites["results"].setBitmap(@path + "data_results")
    @sprites["results"].visible = false
    searchcmds = [
      _INTL("Show Pokémon"),
      _INTL("Filter: Raid"),
      _INTL("Filter: Type"),
      _INTL("Filter: Habitat"),
      _INTL("Filter: Region"),
      _INTL("Exit")
    ]
    @sprites["settings"] = Window_CommandPokemon.newWithSize(searchcmds, 65, 95, 500, 250, @viewport)
    @sprites["settings"].index = 0
    @sprites["settings"].baseColor   = BASE
    @sprites["settings"].shadowColor = SHADOW
    @sprites["settings"].windowskin  = nil
    @sprites["settings"].visible     = false
    @sprites["filter"] = Window_CommandPokemon.newWithSize("", 160, 95, 300, 220, @viewport)
    @sprites["filter"].index = 0
    @sprites["filter"].baseColor     = BASE
    @sprites["filter"].shadowColor   = SHADOW
    @sprites["filter"].windowskin    = nil
    @sprites["filter"].visible       = false
    @sprites["pagetext"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    @pagetext = @sprites["pagetext"].bitmap
    pbSetSmallFont(@pagetext)
    @sprites["overlay"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    @overlay = @sprites["overlay"].bitmap
    @raidlist = []
    @pagehead = []
    @nationalDexList = [:NONE]
    GameData::Species.each_species { |s| @nationalDexList.push(s.species) }
  end
  
  #-----------------------------------------------------------------------------
  # Search mode.
  #-----------------------------------------------------------------------------
  def pbRaidData
    textPos = []
    command = 0
    type    = nil
    habitat = nil
    gen     = nil
    raid    = 1
    raid    = 2 if $player.badge_count > 0
    raid    = 3 if $player.badge_count >= 3
    raid    = 4 if $player.badge_count >= 6
    raid    = 5 if $player.badge_count >= 8
    @raidlvl = "Raid: Lv. #{raid}"
    region_names = ["Kanto", "Johto", "Hoenn", "Sinnoh", "Unova", "Kalos", "Alola", "Galar/Hisui", "Paldea"]
    regions = region_names.slice(0, Settings::GENERATION_LIMIT)
    if Settings::HIDE_UNSEEN_SPECIES
      pkmnCount = raid_GetSeenSpecies([], raid, nil, true).length
    else
      pkmnCount = raid_GenerateSpeciesList([], raid, nil, true).length
    end
    textPos.push(
      [_INTL("[#{@raidlvl}]"), 270, 149, 0, BASE, SHADOW],
      [_INTL("[Any]"), 270, 181, 0, BASE, SHADOW],
      [_INTL("[Any]"), 270, 213, 0, BASE, SHADOW],
      [_INTL("[Any]"), 270, 245, 0, BASE, SHADOW],
      [_INTL("Available Pokémon: {1}", pkmnCount), 256, 346, 2, BASE, SHADOW]
    )
    pbSetSystemFont(@overlay)
    pbDrawTextPositions(@overlay, textPos)
    pbSEPlay("PC access")
    loop do
      Graphics.update
      Input.update
      pbUpdate
      ids  = []
      cmds = []
      @sprites["filter"].index = 0
      @sprites["filter"].visible   = false
      command = @sprites["settings"].index
      @sprites["settings"].visible = true
      @sprites["search"].visible   = true
      if Input.trigger?(Input::USE)
        case command
        when -1, 5
          break
        #-----------------------------------------------------------------------
        # Enters selection mode.
        #-----------------------------------------------------------------------
        when 0
        if pkmnCount > 0
          pbPlayDecisionSE
          pbFadeOutIn {
            @raidlist.clear
            if Settings::HIDE_UNSEEN_SPECIES
              @raidlist = raid_GetSeenSpecies([type, habitat, gen], raid, nil, true)
            else
              @raidlist = raid_GenerateSpeciesList([type, habitat, gen], raid, nil, true)
            end
            @sprites["settings"].visible = false
            @sprites["search"].visible   = false
            @sprites["results"].visible  = true
            @overlay.clear
          }
          pbDeactivateWindows(@sprites) { pbSpeciesSelect }
        else
          pbPlayBuzzerSE
        end
        #-----------------------------------------------------------------------
        # Filter: Raid Level
        #-----------------------------------------------------------------------
        when 1
          cmds.push(_INTL("Raid Level 1"))
          cmds.push(_INTL("Raid Level 2"))      if $player.badge_count > 0
          cmds.push(_INTL("Raid Level 3"))      if $player.badge_count >= 3
          cmds.push(_INTL("Raid Level 4"))      if $player.badge_count >= 6
          cmds.push(_INTL("Raid Level 5"))      if $player.badge_count >= 8
          cmds.push(_INTL("Legendary Raid"))    if $player.badge_count >= 8
          cmds.push(_INTL("Remove Raid Level")) if $player.badge_count >= 8
          @sprites["filter"].commands  = cmds
          @sprites["settings"].visible = false
          @sprites["filter"].visible   = true
          @overlay.clear
          textPos.clear
          loop do
            Graphics.update
            Input.update
            pbUpdate
            break if Input.trigger?(Input::BACK)
            if Input.trigger?(Input::USE)
              pbPlayDecisionSE
              raid = @sprites["filter"].index + 1
              raid = nil if cmds.length == 7 && raid >= cmds.length
              break
            end
          end
        #-----------------------------------------------------------------------
        # Filter: Type
        #-----------------------------------------------------------------------
        when 2
          GameData::Type.each do |t|
            next if t.id == :QMARKS
            ids.push(t.id)
            cmds.push(t.name)
          end
          cmds.push(_INTL("Remove Type"))  
          @sprites["filter"].commands  = cmds
          @sprites["settings"].visible = false
          @sprites["filter"].visible   = true
          @overlay.clear
          textPos.clear
          loop do
            Graphics.update
            Input.update
            pbUpdate
            break if Input.trigger?(Input::BACK)
            if Input.trigger?(Input::USE)
              pbPlayDecisionSE
              type = ids[@sprites["filter"].index]
              type = nil if @sprites["filter"].index >= cmds.length
              break
            end
          end
        #-----------------------------------------------------------------------
        # Filter: Habitat
        #-----------------------------------------------------------------------
        when 3
          GameData::Habitat.each do |h|
            ids.push(h.id)
            cmds.push(h.name)
          end
          cmds.push(_INTL("Remove Habitat"))
          @sprites["filter"].commands  = cmds
          @sprites["settings"].visible = false
          @sprites["filter"].visible   = true
          @overlay.clear
          textPos.clear
          loop do
            Graphics.update
            Input.update
            pbUpdate
            break if Input.trigger?(Input::BACK)
            if Input.trigger?(Input::USE)
              pbPlayDecisionSE
              habitat = ids[@sprites["filter"].index]
              habitat = nil if @sprites["filter"].index >= cmds.length
              break
            end
          end
        #-----------------------------------------------------------------------
        # Filter: Generation
        #-----------------------------------------------------------------------
        when 4
          cmds += regions
          cmds.push(_INTL("Remove Region"))
          @sprites["filter"].commands  = cmds
          @sprites["settings"].visible = false
          @sprites["filter"].visible   = true
          @overlay.clear
          textPos.clear
          loop do
            Graphics.update
            Input.update
            pbUpdate
            break if Input.trigger?(Input::BACK)
            if Input.trigger?(Input::USE)
              pbPlayDecisionSE()
              gen = @sprites["filter"].index + 1
              gen = nil if gen >= cmds.length
              break
            end
          end
        end
        #-----------------------------------------------------------------------
        @overlay.clear
        textPos.clear
        @sprites["settings"].index = 0
        text1     = (raid)    ? _INTL("Raid Lvl. {1}", raid)        : "Any"
        text2     = (type)    ? GameData::Type.get(type).name       : "Any"
        text3     = (habitat) ? GameData::Habitat.get(habitat).name : "Any"
        text4     = (gen)     ? regions[gen - 1]                    : "Any"
        text1     = "Legendary" if raid == 6
        if Settings::HIDE_UNSEEN_SPECIES
          pkmnCount = raid_GetSeenSpecies([type, habitat, gen], raid, nil, true).length
        else
          pkmnCount = raid_GenerateSpeciesList([type, habitat, gen], raid, nil, true).length
        end
        textPos.push(
          [_INTL("[{1}]", text1), 270, 149, 0, BASE, SHADOW],
          [_INTL("[{1}]", text2), 270, 181, 0, BASE, SHADOW],
          [_INTL("[{1}]", text3), 270, 213, 0, BASE, SHADOW],
          [_INTL("[{1}]", text4), 270, 245, 0, BASE, SHADOW],
          [_INTL("Available Pokémon: {1}", pkmnCount), 256, 346, 2, BASE, SHADOW]
        )
        @raidlvl = (text1 == "Any") ? "Raid: Any Lv." : "Raid: Lv. #{raid}"
        @raidlvl = "Raid: Legend" if raid == 6
        pbDrawTextPositions(@overlay, textPos)
      elsif Input.trigger?(Input::BACK)
        pbPlayCancelSE
        break
      end
    end
  end
  
  #-----------------------------------------------------------------------------
  # Selection mode.
  #-----------------------------------------------------------------------------
  def pbSpeciesSelect
    textPos    = []
    index      = 0
    offset     = 0
    page       = 1
    maxpage    = 0
    spritelist = -1
    select     = index + offset
    pkmnTotal  = @raidlist.length
    poke_name  = pbRaidFormName(@raidlist[select])
    for i in 0...pkmnTotal
      maxpage += 1 if i >= PAGE_SIZE * maxpage
    end
    textPos.push([_INTL("{1}", poke_name), 256, 352, 2, BASE, SHADOW])
    drawTextEx(@pagetext, 35, 55, 150, 2, _INTL("{1}", @raidlvl), BASE, SHADOW)
    drawTextEx(@pagetext, 376, 308, 150, 2, _INTL("Page: {1}/{2}", page, maxpage), BASE, SHADOW)
    @sprites["uparrow"] = AnimatedSprite.new("Graphics/Pictures/uparrow", 8, 28, 40, 2, @viewport)
    @sprites["uparrow"].x = 242
    @sprites["uparrow"].y = 44
    @sprites["uparrow"].play
    @sprites["uparrow"].visible = false
    @sprites["downarrow"] = AnimatedSprite.new("Graphics/Pictures/downarrow", 8, 28, 40, 2, @viewport)
    @sprites["downarrow"].x = 242
    @sprites["downarrow"].y = 298
    @sprites["downarrow"].play
    @sprites["downarrow"].visible = false
    @sprites["pokelist"] = PokemonDatabaseSprite.new(@raidlist, 0, @viewport)
    @sprites["cursor"] = IconSprite.new(0, 0, @viewport)
    @sprites["cursor"].setBitmap("Graphics/Pictures/Storage/cursor_point_1")
    @sprites["cursor"].zoom_x = 0.5
    @sprites["cursor"].zoom_y = 0.5
    @sprites["cursor"].x = @sprites["pokelist"].getPokemon(index).x + 10
    @sprites["cursor"].y = @sprites["pokelist"].getPokemon(index).y - 10
    @sprites["cursor"].z = 1
    @sprites["overlay"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    @overlay = @sprites["overlay"].bitmap
    pbSetSystemFont(@overlay)
    pbDrawTextPositions(@overlay, textPos)
    pbSEPlay("GUI storage show party panel")
    loop do
      Graphics.update
      Input.update
      pbUpdate
      if pkmnTotal > PAGE_SIZE
        @sprites["uparrow"].visible   = true
        @sprites["downarrow"].visible = true
        @sprites["uparrow"].visible   = false if offset <= 0
        @sprites["downarrow"].visible = false if offset >= pkmnTotal - PAGE_SIZE
      end
      #-------------------------------------------------------------------------
      # Scrolling upwards
      #-------------------------------------------------------------------------
      if Input.repeat?(Input::UP)
        Input.update
        index -= ROW_SIZE
        # Previous page of species
        if pkmnTotal > PAGE_SIZE && offset > 0 && index < 0
          for i in offset - PAGE_SIZE...@raidlist.length
            spritelist += 1
            break if spritelist >= PAGE_SIZE
          end
          page   -= 1
          offset -= spritelist
          spritelist = -1
          index      =  0
          @sprites["pokelist"].dispose
          @sprites["pokelist"] = PokemonDatabaseSprite.new(@raidlist, page - 1, @viewport)
          pbSEPlay("GUI summary change page")
        else
          pbPlayCursorSE
        end
        # Returns to last index
        if index < 0
          endsprite = 0
          for i in 0...PAGE_SIZE
            next if !@sprites["pokelist"].getPokemon(endsprite)
            break if endsprite > PAGE_SIZE
            endsprite += 1 
          end
          index = endsprite - 1
        end
        @sprites["cursor"].x = @sprites["pokelist"].getPokemon(index).x + 10
        @sprites["cursor"].y = @sprites["pokelist"].getPokemon(index).y - 10
        @overlay.clear
        @pagetext.clear
        textPos.clear
        select = index + offset
        poke_name = pbRaidFormName(@raidlist[select])
        drawTextEx(@pagetext, 35, 55, 150, 2, _INTL("{1}", @raidlvl), BASE, SHADOW)
        drawTextEx(@pagetext, 376, 308, 150, 2, _INTL("Page: {1}/{2}", page, maxpage), BASE, SHADOW)
        textPos.push([_INTL("{1}", poke_name), 256, 352, 2, BASE, SHADOW])
        pbDrawTextPositions(@overlay, textPos)
      #-------------------------------------------------------------------------
      # Scrolling downwards
      #-------------------------------------------------------------------------
      elsif Input.repeat?(Input::DOWN)
        Input.update
        index += ROW_SIZE
        # Next page of species
        if pkmnTotal > PAGE_SIZE + offset && index > PAGE_SIZE - 1
          for i in PAGE_SIZE + offset...@raidlist.length
            spritelist += 1
            break if spritelist >= PAGE_SIZE
          end
          page   += 1
          offset += spritelist
          offset += PAGE_SIZE - spritelist if spritelist < PAGE_SIZE
          spritelist = -1
          index      =  0
          @sprites["pokelist"].dispose
          @sprites["pokelist"] = PokemonDatabaseSprite.new(@raidlist, page - 1, @viewport)
          pbSEPlay("GUI summary change page")
        else
          pbPlayCursorSE
        end
        # Returns to first index
        index  = 0 if index > PAGE_SIZE - 1
        index  = 0 if !@sprites["pokelist"].getPokemon(index)
        if index < PAGE_SIZE
          @sprites["cursor"].x = @sprites["pokelist"].getPokemon(index).x + 10
          @sprites["cursor"].y = @sprites["pokelist"].getPokemon(index).y - 10
        end
        @overlay.clear
        @pagetext.clear
        textPos.clear
        select = index + offset
        poke_name = pbRaidFormName(@raidlist[select])
        drawTextEx(@pagetext, 35, 55, 150, 2, _INTL("{1}", @raidlvl), BASE, SHADOW)
        drawTextEx(@pagetext, 376, 308, 150, 2, _INTL("Page: {1}/{2}", page, maxpage), BASE, SHADOW)
        textPos.push([_INTL("{1}", poke_name), 256, 352, 2, BASE, SHADOW])
        pbDrawTextPositions(@overlay, textPos)
      #-------------------------------------------------------------------------
      # Scrolling left
      #-------------------------------------------------------------------------
      elsif Input.repeat?(Input::LEFT)
        pbPlayCursorSE
        Input.update
        index -= 1
        # Returns to last index
        if index < 0
          endsprite = 0
          for i in 0...PAGE_SIZE
            next if !@sprites["pokelist"].getPokemon(endsprite)
            break if endsprite > PAGE_SIZE
            endsprite += 1 
          end
          index = endsprite - 1
        end
        @sprites["cursor"].x = @sprites["pokelist"].getPokemon(index).x + 10
        @sprites["cursor"].y = @sprites["pokelist"].getPokemon(index).y - 10
        @overlay.clear
        textPos.clear
        select = index + offset
        poke_name = pbRaidFormName(@raidlist[select])
        textPos.push([_INTL("{1}", poke_name), 256, 352, 2, BASE, SHADOW])
        pbDrawTextPositions(@overlay, textPos)
      #-------------------------------------------------------------------------
      # Scrolling right
      #-------------------------------------------------------------------------
      elsif Input.repeat?(Input::RIGHT)
        if index < PAGE_SIZE
          pbPlayCursorSE
          Input.update
          index += 1
          # Returns to first index
          index  = 0 if index > PAGE_SIZE - 1
          index  = 0 if !@sprites["pokelist"].getPokemon(index)
          @sprites["cursor"].x = @sprites["pokelist"].getPokemon(index).x + 10
          @sprites["cursor"].y = @sprites["pokelist"].getPokemon(index).y - 10
          @overlay.clear
          textPos.clear
          select = index + offset
          poke_name = pbRaidFormName(@raidlist[select])
          textPos.push([_INTL("{1}", poke_name), 256, 352, 2, BASE, SHADOW])
          pbDrawTextPositions(@overlay, textPos)
        end
      #-------------------------------------------------------------------------
      # Scrolls up through entire pages at a time.
      #-------------------------------------------------------------------------    
      elsif Input.trigger?(Input::JUMPUP)
        Input.update
        if pkmnTotal > PAGE_SIZE && page > 1
          for i in offset - PAGE_SIZE...@raidlist.length
            spritelist += 1
            break if spritelist >= PAGE_SIZE
          end
          page   -= 1
          offset -= spritelist
          spritelist = -1
          index      =  0
          @sprites["pokelist"].dispose
          @sprites["pokelist"] = PokemonDatabaseSprite.new(@raidlist, page - 1, @viewport)
          @sprites["cursor"].x = @sprites["pokelist"].getPokemon(index).x + 10
          @sprites["cursor"].y = @sprites["pokelist"].getPokemon(index).y - 10
          pbSEPlay("GUI summary change page")
          @overlay.clear
          @pagetext.clear
          textPos.clear
          select = index + offset
          poke_name = pbRaidFormName(@raidlist[select])
          drawTextEx(@pagetext, 35, 55, 150, 2, _INTL("{1}", @raidlvl), BASE, SHADOW)
          drawTextEx(@pagetext, 376, 308, 150, 2, _INTL("Page: {1}/{2}", page, maxpage), BASE, SHADOW)
          textPos.push([_INTL("{1}", poke_name), 256, 352, 2, BASE, SHADOW])
          pbDrawTextPositions(@overlay, textPos)
        end
      #-------------------------------------------------------------------------
      # Scrolls down through entire pages at a time.
      #-------------------------------------------------------------------------    
      elsif Input.trigger?(Input::JUMPDOWN)
        Input.update
        if pkmnTotal > PAGE_SIZE + offset && page < maxpage
          for i in PAGE_SIZE + offset...@raidlist.length
            spritelist += 1
            break if spritelist >= PAGE_SIZE
          end
          page   += 1
          offset += spritelist
          offset += PAGE_SIZE - spritelist if spritelist < PAGE_SIZE
          spritelist = -1
          index      =  0
          @sprites["pokelist"].dispose
          @sprites["pokelist"] = PokemonDatabaseSprite.new(@raidlist, page - 1, @viewport)
          @sprites["cursor"].x = @sprites["pokelist"].getPokemon(index).x + 10
          @sprites["cursor"].y = @sprites["pokelist"].getPokemon(index).y - 10
          pbSEPlay("GUI summary change page")
          @overlay.clear
          @pagetext.clear
          textPos.clear
          select = index + offset
          poke_name = pbRaidFormName(@raidlist[select])
          drawTextEx(@pagetext, 35, 55, 150, 2, _INTL("{1}", @raidlvl), BASE, SHADOW)
          drawTextEx(@pagetext, 376, 308, 150, 2, _INTL("Page: {1}/{2}", page, maxpage), BASE, SHADOW)
          textPos.push([_INTL("{1}", poke_name), 256, 352, 2, BASE, SHADOW])
          pbDrawTextPositions(@overlay, textPos)
        end
      #-------------------------------------------------------------------------
      # Opens species' raid data page.
      #-------------------------------------------------------------------------
      elsif Input.trigger?(Input::USE)
        pbPlayDecisionSE
        pbFadeOutIn {
          select = index + offset
          for i in 0...@raidlist.length
            pkmn = @raidlist[i] if select == i
          end
          pbRaidDataPage(pkmn)
        }
      #-------------------------------------------------------------------------
      # Returns to search mode.
      #-------------------------------------------------------------------------
      elsif Input.trigger?(Input::BACK)
        pbSEPlay("GUI storage hide party panel")
        pbFadeOutIn {
          @sprites["pokelist"].dispose
          @sprites["cursor"].dispose
          @sprites["uparrow"].dispose
          @sprites["downarrow"].dispose
          @sprites["results"].visible = false
          @pagetext.clear
          @overlay.clear
        }
        break
      end
    end
  end
  
  #-----------------------------------------------------------------------------
  # Species data to display.
  #-----------------------------------------------------------------------------
  def pbSetSpeciesData(pkmn)
    display     = 8    # Number of moves displayed (counts 0)
    ydiff       = 17   # Difference in y positioning between moves. 
    xposL       = 92   # X position of left move column.
    xposR       = 270  # X position of right move column.
    yposT       = 36   # Y position of top move row.
    yposB       = 224  # Y position of bottom move row.
    pkmn        = GameData::Species.get(pkmn)
    case pkmn.species
    when :MINIOR     then form = 0
    when :WISHIWASHI then form = 1
    else form = pkmn.form
    end
    habitat     = GameData::Habitat.get(pkmn.habitat).name
    ranks       = raid_RanksAppearedIn(pkmn.id)
    moves       = raid_GenerateMovelists(pkmn.id)
    @datamoves1 = moves[0]
    @datamoves2 = moves[1]
    @datamoves3 = moves[2]
    @datamoves4 = moves[3]
    @datasprites["pokemon"].setSpeciesBitmap(pkmn.species, nil, form)
    @datasprites["pokemon"].zoom_x = 0.5
    @datasprites["pokemon"].zoom_y = 0.5
    @datasprites["gmax"].visible = (pkmn.hasGmax?) ? true : false
    pkmn.types.each_with_index do |type, i|
      type_number = GameData::Type.get(type).icon_position
      type_rect = Rect.new(0, type_number * 28, 64, 28)
      type_x = (pkmn.types.length == 1) ? 400 : 367 + (68 * i)
      @dataoverlay.blt(type_x, 194, @typebitmap.bitmap, type_rect)
    end
    @dataoverlay.blt(0,   0,   @movebitmap.bitmap, Rect.new(0,   0,   181, 194)) if @datamoves1.length > 0
    @dataoverlay.blt(181, 0,   @movebitmap.bitmap, Rect.new(181, 0,   181, 194)) if @datamoves2.length > 0
    @dataoverlay.blt(0,   193, @movebitmap.bitmap, Rect.new(0,   194, 181, 388)) if @datamoves3.length > 0
    @dataoverlay.blt(181, 193, @movebitmap.bitmap, Rect.new(181, 194, 362, 388)) if @datamoves4.length > 0
    textPos = []
    textPos.push(
      [pkmn.name, 434, 22, 2, BASE, SHADOW],
      [_INTL("Habitat:"), 434, 332, 2, BASE, SHADOW],
      [_INTL("{1}", habitat), 434, 356, 2, BASE, SHADOW],
      [_INTL("Appears In:"), 383, 229, 0, BASE, SHADOW]
    )
    dexnum = 0
    dexnumshift = false
    if $player.pokedex.unlocked?(-1)
      dexnum = @nationalDexList.index(pkmn.species) || 0
      dexnumshift = true if Settings::DEXES_WITH_OFFSETS.include?(-1)
    else
      ($player.pokedex.dexes_count - 1).times do |i|
        next if !$player.pokedex.unlocked?(i)
        num = pbGetRegionalNumber(i, pkmn.species)
        next if num <= 0
        dexnum = num
        dexnumshift = true if Settings::DEXES_WITH_OFFSETS.include?(i)
        break
      end
    end
    if dexnum > 0
      dexnum -= 1 if dexnumshift
      textPos.push(["#" + dexnum.to_s.rjust(3, "0"), 477, 58, 2, BASE, SHADOW])
    end
    if pbRaidFormName(pkmn, true) != pkmn.name
      textPos.push([pbRaidFormName(pkmn, true), 434, 151, 2, BASE, SHADOW])
    end
    if ranks.length > 0
      if ranks.include?(6)
        textPos.push([_INTL("Legendary Raid"), 368, 261, 0, BASE, SHADOW])
      else
        for i in 0...ranks.length
          textPos.push([_INTL("Raid Lv. {1}", ranks[i]), 389, 257 + (20 * i), 0, BASE, SHADOW])
        end
      end
    else
      textPos.push([_INTL("None"), 413, 261, 0, BASE, SHADOW])
    end
    #---------------------------------------------------------------------------
    # Primary movelist
    #---------------------------------------------------------------------------
    if @datamoves1.length > 0
      for i in 0...@datamoves1.length
        @movePos.push([GameData::Move.get(@datamoves1[i]).name, xposL, yposT + (i * ydiff), 2, BASE, SHADOW])
        break if i >= display
      end
    else
      textPos.push([_INTL("None Found"), xposL, 97, 2, BASE, SHADOW])
    end
    #---------------------------------------------------------------------------
    # Secondary movelist
    #---------------------------------------------------------------------------
    if @datamoves2.length > 0
      for i in 0...@datamoves2.length
        @movePos.push([GameData::Move.get(@datamoves2[i]).name, xposR, yposT + (i * ydiff), 2, BASE, SHADOW])
        break if i >= display
      end
    else
      textPos.push([_INTL("None Found"), xposR, 97, 2, BASE, SHADOW])
    end
    #---------------------------------------------------------------------------
    # Spread moves movelist
    #---------------------------------------------------------------------------
    if @datamoves3.length > 0
      for i in 0...@datamoves3.length
        @movePos.push([GameData::Move.get(@datamoves3[i]).name, xposL, yposB + (i * ydiff), 2, BASE, SHADOW])
        break if i >= display
      end
    else
      textPos.push([_INTL("None Found"), xposL, 290, 2, BASE, SHADOW])
    end
    #---------------------------------------------------------------------------
    # Support moves movelist
    #---------------------------------------------------------------------------
    if @datamoves4.length > 0
      for i in 0...@datamoves4.length
        @movePos.push([GameData::Move.get(@datamoves4[i]).name, xposR, yposB + (i * ydiff), 2, BASE, SHADOW])
        break if i >= display
      end
    else
      textPos.push([_INTL("None Found"), xposR, 290, 2, BASE, SHADOW])
    end
    pbSetSmallFont(@dataoverlay)
    pbSetSmallFont(@dataoverlay2)
    pbDrawTextPositions(@dataoverlay, textPos)
    pbDrawTextPositions(@dataoverlay2, @movePos)
  end   
    
  #-----------------------------------------------------------------------------
  # Raid Data page
  #-----------------------------------------------------------------------------
  def pbRaidDataPage(pkmn)
    page     = 0
    display  = 8
    ydiff    = 17
    xposL    = 92 
    xposR    = 270
    yposT    = 36
    yposB    = 224
    @movePos = []
    @datasprites = {}
    @dataviewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @dataviewport.z = 99999
    @datasprites["screen"] = IconSprite.new(0, 0, @dataviewport)
    @datasprites["screen"].setBitmap(@path + "data_bg")
    @datasprites["overlay"] = BitmapSprite.new(Graphics.width, Graphics.height, @dataviewport)
    @dataoverlay = @datasprites["overlay"].bitmap
    @datasprites["overlay2"] = BitmapSprite.new(Graphics.width, Graphics.height, @dataviewport)
    @dataoverlay2 = @datasprites["overlay2"].bitmap
    @datasprites["pokemon"] = PokemonSprite.new(@dataviewport)
    @datasprites["pokemon"].setOffset(PictureOrigin::CENTER)
    @datasprites["pokemon"].x = 432
    @datasprites["pokemon"].y = 110
    @datasprites["gmax"] = IconSprite.new(472, 124, @dataviewport)
    @datasprites["gmax"].setBitmap("Graphics/Plugins/ZUD/UI/gfactor")
    @datasprites["uparrow"] = AnimatedSprite.new("Graphics/Pictures/uparrow", 8, 28, 40, 2, @dataviewport)
    @datasprites["uparrow"].x = 167
    @datasprites["uparrow"].y = 4
    @datasprites["uparrow"].play
    @datasprites["uparrow"].visible = false
    @datasprites["downarrow"] = AnimatedSprite.new("Graphics/Pictures/downarrow", 8, 28, 40, 2, @dataviewport)
    @datasprites["downarrow"].x = 167
    @datasprites["downarrow"].y = 345
    @datasprites["downarrow"].play
    @datasprites["downarrow"].visible = false
    @datasprites["leftarrow"] = AnimatedSprite.new("Graphics/Pictures/leftarrow", 8, 40, 28, 2, @dataviewport)
    @datasprites["leftarrow"].x = 352
    @datasprites["leftarrow"].y = 92
    @datasprites["leftarrow"].play
    @datasprites["leftarrow"].visible = false
    @datasprites["rightarrow"] = AnimatedSprite.new("Graphics/Pictures/rightarrow", 8, 40, 28, 2, @dataviewport)
    @datasprites["rightarrow"].x = 472
    @datasprites["rightarrow"].y = 92
    @datasprites["rightarrow"].play
    @datasprites["rightarrow"].visible = false
    @typebitmap = AnimatedBitmap.new(_INTL("Graphics/Pictures/types"))
    @movebitmap = AnimatedBitmap.new(_INTL(@path + "data_moves"))
    pbSetSpeciesData(pkmn)
    pkmndata = GameData::Species.get(pkmn)
    form = ([:WISHIWASHI, :PALAFIN].include?(pkmndata.species)) ? 1 : pkmndata.form
    GameData::Species.play_cry_from_species(pkmndata.species, form)
    raidforms = pkmndata.get_raid_forms
    loop do
      Graphics.update
      Input.update
      pbUpdateSpriteHash(@datasprites)
      offset1 = offset2 = offset3 = offset4 = -1
      topReached  = (page > 0) ? false : true
      endReached1 = (@datamoves1.length <= display + 1) ? true : false
      endReached2 = (@datamoves2.length <= display + 1) ? true : false
      endReached3 = (@datamoves3.length <= display + 1) ? true : false
      endReached4 = (@datamoves4.length <= display + 1) ? true : false
      endReached  = (endReached1 && endReached2 && endReached3 && endReached4) ? true : false
      @datasprites["uparrow"].visible    = (topReached) ? false : true
      @datasprites["downarrow"].visible  = (endReached) ? false : true
      @datasprites["leftarrow"].visible  = (raidforms.length > 1 && pkmn != raidforms.first) ? true : false
      @datasprites["rightarrow"].visible = (raidforms.length > 1 && pkmn != raidforms.last)  ? true : false
      #-------------------------------------------------------------------------
      # Scrolling movelists upwards.
      #-------------------------------------------------------------------------
      if Input.repeat?(Input::UP)
        if !topReached
          page    -= 9
          page     = 0 if page < 0
          display -= 9
          display  = 8 if page == 0
          pbSEPlay("GUI summary change page")
          Input.update
          @movePos.clear
          @dataoverlay2.clear
          offset1 = offset2 = offset3 = offset4 = -1
          for i in page...@datamoves1.length
            offset1 += 1 if i < @datamoves1.length
            @movePos.push([GameData::Move.get(@datamoves1[i]).name, xposL, yposT + (offset1 * ydiff), 2, BASE, SHADOW])
            break if i >= display
          end
          for i in page...@datamoves2.length
            offset2 += 1 if i < @datamoves2.length
            @movePos.push([GameData::Move.get(@datamoves2[i]).name, xposR, yposT + (offset2 * ydiff), 2, BASE, SHADOW])
            break if i >= display
          end
          for i in page...@datamoves3.length
            offset3 += 1 if i < @datamoves3.length
            @movePos.push([GameData::Move.get(@datamoves3[i]).name, xposL, yposB + (offset3 * ydiff), 2, BASE, SHADOW])
            break if i >= display
          end
          for i in page...@datamoves4.length
            offset4 += 1 if i < @datamoves4.length
            @movePos.push([GameData::Move.get(@datamoves4[i]).name, xposR, yposB + (offset4 * ydiff), 2, BASE, SHADOW])
            break if i >= display
          end
          topReached = true if page == 0
          pbDrawTextPositions(@dataoverlay2, @movePos)
        end
      #-------------------------------------------------------------------------
      # Scrolling movelists downwards.
      #-------------------------------------------------------------------------
      elsif Input.repeat?(Input::DOWN)
        if !endReached
          page    += 9
          display += 9
          pbSEPlay("GUI summary change page")
          Input.update
          @movePos.clear
          @dataoverlay2.clear
          offset1 = offset2 = offset3 = offset4 = -1
          for i in page...@datamoves1.length
            offset1 += 1 if i > 0
            @movePos.push([GameData::Move.get(@datamoves1[i]).name, xposL, yposT + (offset1 * ydiff), 2, BASE, SHADOW])
            break if i >= display
          end
          endReached1 = true if display > @datamoves1.length
          for i in page...@datamoves2.length
            offset2 += 1 if i > 0
            @movePos.push([GameData::Move.get(@datamoves2[i]).name, xposR, yposT + (offset2 * ydiff), 2, BASE, SHADOW])
            break if i >= display
          end
          endReached2 = true if display > @datamoves2.length
          for i in page...@datamoves3.length
            offset3 += 1 if i > 0
            @movePos.push([GameData::Move.get(@datamoves3[i]).name, xposL, yposB + (offset3 * ydiff), 2, BASE, SHADOW])
            break if i >= display
          end
          endReached3 = true if display > @datamoves3.length
          for i in page...@datamoves4.length
            offset4 += 1 if i > 0
            @movePos.push([GameData::Move.get(@datamoves4[i]).name, xposR, yposB + (offset4 * ydiff), 2, BASE, SHADOW])
            break if i >= display
          end
          endReached4 = true if display > @datamoves4.length
          pbDrawTextPositions(@dataoverlay2, @movePos)
        end
      #-------------------------------------------------------------------------
      # Scrolling left through forms.
      #-------------------------------------------------------------------------
      elsif Input.repeat?(Input::LEFT)
        if raidforms.length > 1 && pkmn != raidforms.first
          prev_form = pkmn
          raidforms.each do |f|
            break if f == pkmn
            prev_form = f
          end
          pkmn = prev_form
          page    = 0
          display = 8
          @movePos.clear
          @dataoverlay.clear
          @dataoverlay2.clear
          pbSetSpeciesData(prev_form)
          pbSEPlay("GUI party switch")
        end
      #-------------------------------------------------------------------------
      # Scrolling right through forms.
      #-------------------------------------------------------------------------    
      elsif Input.repeat?(Input::RIGHT)
        if raidforms.length > 1 && pkmn != raidforms.last
          next_form = pkmn
          raidforms.reverse.each do |f|
            break if f == pkmn
            next_form = f
          end
          pkmn = next_form
          page    = 0
          display = 8
          @movePos.clear
          @dataoverlay.clear
          @dataoverlay2.clear
          pbSetSpeciesData(next_form)
          pbSEPlay("GUI party switch")
        end
      #-------------------------------------------------------------------------
      # Scrolling up through species list.
      #-------------------------------------------------------------------------    
      elsif Input.trigger?(Input::JUMPUP)
        if @raidlist.length > 1 && pkmn != @raidlist.first
          prev_species = pkmn
          @raidlist.each do |species|
            break if species == pkmn
            prev_species = species
          end
          pkmn = prev_species
          page    = 0
          display = 8
          @movePos.clear
          @dataoverlay.clear
          @dataoverlay2.clear
          pbSetSpeciesData(prev_species)
          pkmndata = GameData::Species.get(pkmn)
          GameData::Species.play_cry_from_species(pkmndata.species, pkmndata.form)
          raidforms = pkmndata.get_raid_forms
        end
      #-------------------------------------------------------------------------
      # Scrolling down through species list.
      #-------------------------------------------------------------------------    
      elsif Input.trigger?(Input::JUMPDOWN)
        if @raidlist.length > 1 && pkmn != @raidlist.last
          next_species = pkmn
          @raidlist.reverse.each do |species| 
            break if species == pkmn
            next_species = species
          end
          pkmn = next_species
          page    = 0
          display = 8
          @movePos.clear
          @dataoverlay.clear
          @dataoverlay2.clear
          pbSetSpeciesData(next_species)
          pkmndata = GameData::Species.get(pkmn)
          GameData::Species.play_cry_from_species(pkmndata.species, pkmndata.form)
          raidforms = pkmndata.get_raid_forms
        end
      #-------------------------------------------------------------------------
      # Test battle (Debug Mode only)
      #-------------------------------------------------------------------------
      elsif Input.trigger?(Input::USE) && $DEBUG
        Input.update
        if pbConfirmMessage(_INTL("Test battle this Max Raid species?"))
          pbMessage(_INTL("Choose any desired raid criteria for this battle."))
          pbDebugMaxRaidBattle(pkmn)
        end
      #-------------------------------------------------------------------------
      # Plays the species cry.
      #-------------------------------------------------------------------------
      elsif Input.trigger?(Input::ACTION)
        Input.update
        pkmndata = GameData::Species.get(pkmn)
        GameData::Species.play_cry_from_species(pkmndata.species, form)
      #-------------------------------------------------------------------------
      # Returns to selection mode.
      #-------------------------------------------------------------------------
      elsif Input.trigger?(Input::BACK)
        pbPlayCloseMenuSE
        Input.update
        break
      end
    end
    pbDisposeSpriteHash(@datasprites)
    @dataviewport.dispose
  end
end


#===============================================================================
# Calls the Max Raid Database.
#===============================================================================
class RaidDataScreen
  def initialize(scene)
    @scene = scene
  end

  def pbStartScreen
    @scene.pbStartScene
    @scene.pbRaidData
    @scene.pbEndScene
  end
end

def pbOpenRaidData
  pbFadeOutIn {
    scene = RaidDataScene.new
    screen = RaidDataScreen.new(scene)
    screen.pbStartScreen
  }
end


#===============================================================================
# Player's ownership of the Max Raid Database.
#===============================================================================
class Player < Trainer
  attr_accessor :has_raid_database
  alias zud_initialize initialize
  def initialize(*args)
    zud_initialize(*args)
    @has_raid_database = false
  end
end

#-------------------------------------------------------------------------------
# Adds the Raid Database to the Pokegear if unlocked.
#-------------------------------------------------------------------------------
MenuHandlers.add(:pokegear_menu, :raid_database, {
  "name"      => _INTL("Raid Database"),
  "icon_name" => "raid",
  "order"     => 40,
  "condition" => proc { next $player.has_raid_database },
  "effect"    => proc { |menu|
    pbFadeOutIn { pbOpenRaidData }
    next false
  }
})