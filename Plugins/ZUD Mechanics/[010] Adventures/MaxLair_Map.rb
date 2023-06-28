#===============================================================================
# Conversion hash for tile coordinates.
#===============================================================================
# The key used for converting the letter + number tile coordinates entered in 
# adventure_maps.txt into actual pixel coordinates to appear on screen. 
# The letter of a tile's coordinates corresponds to its X-axis coordinate, and
# the two digit number corresponds to its Y-axis coordinate. These numbers are
# then both multiplied by 32, to get the exact screen positioning for the tile
# on a 32x32 grid.
#===============================================================================
LAIR_COORDINATES = {
  # X-Axis coordinates
  "A" => 0,  "B" => 1,  "C" => 2,  "D" => 3,  "E" => 4,  "F" => 5,  "G" => 6,
  "H" => 7,  "I" => 8,  "J" => 9,  "K" => 10, "L" => 11, "M" => 12, "N" => 13,
  "O" => 14, "P" => 15, "Q" => 16, "R" => 17, "S" => 18, "T" => 19, "U" => 20,
  "V" => 21, "W" => 22, "X" => 23, "Y" => 24, "Z" => 25,
  # Y-Axis coordinates
  "01" => 11,  "02" => 10,  "03" => 9,   "04" => 8,   "05" => 7,   "06" => 6,   
  "07" => 5,   "08" => 4,   "09" => 3,   "10" => 2,   "11" => 1,   "12" => 0,
  "13" => -1,  "14" => -2,  "15" => -3,  "16" => -4,  "17" => -5,  "18" => -6,
  "19" => -7,  "20" => -8,  "21" => -9,  "22" => -10, "23" => -11, "24" => -12,
  "25" => -13, "26" => -14, "27" => -15, "28" => -16
}

#-------------------------------------------------------------------------------
# Returns the converted pixel coordinates of a letter-number string.
#-------------------------------------------------------------------------------
def coordinate_check(coords, map = nil)
  c = []
  coords.chars.each_with_index do |s, i|
    case i
    when 0, 1 then c.push(s)
    when 2    then c[1] += s
    end
  end
  if map
    if !LAIR_COORDINATES.has_key?(c[0])
    raise _INTL("{1} coordinate '{2}' in '{3}' doesn't exist. This coordinate must be a capital letter A-Z.", map, c[0], coords)
    elsif !LAIR_COORDINATES.has_key?(c[1])
    raise _INTL("{1} coordinate '{2}' in '{3}' doesn't exist. This coordinate must be a padded two-digit number 01-28.", map, c[1], coords)
    end
  else
    return [LAIR_COORDINATES[c[0]] * 32, LAIR_COORDINATES[c[1]] * 32]
  end
end


#===============================================================================
# Max Lair map setup.
#===============================================================================
class LairMapScene
  #-----------------------------------------------------------------------------
  # Starts the Max Lair scene.
  #-----------------------------------------------------------------------------
  def pbStartScene(map)
    @map_data     = pbLoadLairMapData[map]
    @map_name     = _INTL("{1}", @map_data["Name"])
    @keycount     = pbDynamaxAdventure.keycount
    @max_hearts   = @knockouts = pbDynamaxAdventure.knockouts
    @endless_mode = pbDynamaxAdventure.endlessMode?
    @darkness_map = pbDynamaxAdventure.darkness_map
    @darkness_lvl = pbDynamaxAdventure.darkness_lvl
    @path = "Graphics/Plugins/ZUD/Adventure/"
    #---------------------------------------------------------------------------
    # Creates all Pokemon objects for the lair.
    #---------------------------------------------------------------------------
    @lair_pokemon = []
    pbDynamaxAdventure.lair_species.each_with_index do |species, i|
      case i
      when 0, 1       then rank = 2
      when 2, 3, 4, 5 then rank = 3
      when 6, 7, 8, 9 then rank = 4
      when 10         then rank = 6
      end
      pkmn, _rank = MaxRaidBattle.generate_foe(species, rank)
      pkmn.level = $player.party.first.level
      pkmn.level += 5 if rank == 6
      @lair_pokemon.push(pkmn)
    end
    #---------------------------------------------------------------------------
    # Draws the map.
    #---------------------------------------------------------------------------
    @sprites     = {}
    @map_sprites = []
    @viewport    = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z  = 99999
    @viewport2   = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport2.z = 99999
    @sprites["background"] = IconSprite.new(0, 0, @viewport)
    @sprites["background"].bitmap = Bitmap.new(@path + "Maps/#{@map_name}")
    bgheight = @sprites["background"].bitmap.height
    bgwidth  = @sprites["background"].bitmap.width
    @map_sprites.push(@sprites["background"])
    @upperBounds = -4
    @lowerBounds = (Graphics.height - bgheight) + 4
    @leftBounds  = -4
    @rightBounds = (Graphics.width - bgwidth) - 4
    @sprites["background"].y = Graphics.height - bgheight
    @darkness_bmp = LairDarknessSprite.new(@viewport) if @darkness_map
    @darkness_bmp.radius = @darkness_lvl if @darkness_lvl
    #---------------------------------------------------------------------------
    # Draws the map tiles.
    #---------------------------------------------------------------------------
    @map_data.keys.each do |key|
      next if !@map_data[key].is_a?(Array) || key == "Hidden"
      #-------------------------------------------------------------------------
      # Skips drawing Flare tiles if not a Dark Lair.
      #-------------------------------------------------------------------------
      next if key == "Flare" && !@darkness_map 
      #-------------------------------------------------------------------------
      @map_data[key].each_with_index do |coords, i|
        h = (@map_data.has_key?("Hidden") && @map_data["Hidden"].include?(coords)) ? "Hidden_" : ""
        case key
        #-----------------------------------------------------------------------
        # Sets the keys for each tile sprite. Sprites with the word "Hidden" in
        # their key name are invisible until a Switch tile is turned on.
        # Pokemon tiles cannot be made into Hidden tiles.
        #-----------------------------------------------------------------------
        when "Pokemon"   then name = "#{key}_#{i}"
        #-----------------------------------------------------------------------
        # Trap, Block and Chest tile keys are generated with a random number at 
        # the end of their key name to designate which variation of that tile 
        # they will trigger in the lair.
        # Trap tiles cannot be made into "Hidden" tiles, because they are already
        # visibly hidden by default, and aren't affected by Switch tiles.
        #-----------------------------------------------------------------------
        when "Trap"      then name = "#{key}_#{i}_"     + rand(6).to_s
        when "Block"     then name = "#{key}_#{h}#{i}_" + rand(12).to_s
        when "Chest"     then name = "#{key}_#{h}#{i}_" + rand(100).to_s
        #-----------------------------------------------------------------------
        # Warp tiles are given an additional index number at the end of their
        # key name that is +1 higher than their normal index. This designates 
        # the index of the next Warp tile that this tile will Warp the player to.
        #-----------------------------------------------------------------------
        when "Warp"      then name = "#{key}_#{h}#{i}_" + (i + 1).to_s
        #-----------------------------------------------------------------------
        else                  name = "#{key}_#{h}#{i}"
        end
        coords = coordinate_check(coords)
        tile = @sprites[name] = IconSprite.new(coords[0], coords[1], @viewport)
        tile.bitmap = Bitmap.new(@path + "tiles")
        tile.visible = !name.include?("Hidden")
        case key
        #-----------------------------------------------------------------------
        # Gets the appropriate sprite for each tile type.
        #-----------------------------------------------------------------------
        when "Pokemon"    then tile.src_rect.set(64,   0, 32, 32)
        when "TurnNorth"  then tile.src_rect.set(96,   0, 32, 32)
        when "TurnSouth"  then tile.src_rect.set(128,  0, 32, 32)
        when "TurnWest"   then tile.src_rect.set(160,  0, 32, 32)
        when "TurnEast"   then tile.src_rect.set(192,  0, 32, 32)
        when "TurnFlip"   then tile.src_rect.set(0,   32, 32, 32)
        when "TurnRandom" then tile.src_rect.set(32,  32, 32, 32)
        when "Warp"       then tile.src_rect.set(64,  32, 32, 32)
        when "Reset"      then tile.src_rect.set(96,  32, 32, 32)  
        when "Switch"     then tile.src_rect.set(128, 32, 32, 32)  
        when "Block"      then tile.src_rect.set(192, 32, 32, 32)  
        when "NPCSwap"    then tile.src_rect.set(0,   64, 32, 32)
        when "NPCEquip"   then tile.src_rect.set(32,  64, 32, 32)
        when "NPCTrain"   then tile.src_rect.set(64,  64, 32, 32)
        when "NPCTutor"   then tile.src_rect.set(96,  64, 32, 32)
        when "NPCWard"    then tile.src_rect.set(128, 64, 32, 32)
        when "NPCHeal"    then tile.src_rect.set(160, 64, 32, 32)
        when "NPCRandom"  then tile.src_rect.set(192, 64, 32, 32)
        when "Berry"      then tile.src_rect.set(0,   96, 32, 32)  
        when "Flare"      then tile.src_rect.set(32,  96, 32, 32)  
        when "Key"        then tile.src_rect.set(64,  96, 32, 32)
        when "Chest"      then tile.src_rect.set(96,  96, 32, 32)  
        when "Door"       then tile.src_rect.set(128, 96, 32, 32)
        #-----------------------------------------------------------------------
        # Trap tiles use no visible sprite so that they aren't visible, even if
        # their actual "visibility" isn't turned off.
        # Trap tiles will randomly have thier actual "visibility" turned on.
        # Traps with visibility turned on will trigger when stepped on.
        #-----------------------------------------------------------------------
        when "Trap"
          tile.src_rect.set(0, 0, 0, 0)
          tile.visible = rand(10) > 4
        #-----------------------------------------------------------------------
        # All Selection tiles use the same sprite, regardless of which variation
        # of Selection tile it is.
        #-----------------------------------------------------------------------
        else
          tile.src_rect.set(32, 0, 32, 32)
        #-----------------------------------------------------------------------
        end
        @map_sprites.push(tile)
      end
    end
    #---------------------------------------------------------------------------
    # Draws the start tile.
    #---------------------------------------------------------------------------
    coords = coordinate_check(@map_data["Start"])
    @start_tile = @sprites["Start"] = IconSprite.new(coords[0], coords[1], @viewport)
    @start_tile.bitmap = Bitmap.new(@path + "tiles")
    @start_tile.src_rect.set(0, 0, 32, 32)
    @map_sprites.push(@start_tile)
    #---------------------------------------------------------------------------
    # Draws all Pokemon and type icon sprites on the map.
    #---------------------------------------------------------------------------
    type = nil
    @lair_pokemon.each_with_index do |pkmn, i|
      pokemon = @sprites["Shadow_#{i}"] = PokemonSprite.new(@viewport)
      pokemon.setPokemonBitmap(pkmn)
      pokemon.unDynamax
      pokemon.setOffset(PictureOrigin::CENTER)
      pokemon.x = @sprites["Pokemon_#{i}"].x + 16
      pokemon.y = @sprites["Pokemon_#{i}"].y - 16
      pokemon.zoom_x = 0.5
      pokemon.zoom_y = 0.5
      pokemon.color.alpha = 255
      poketype = @sprites["Type_#{i}"] = IconSprite.new(pokemon.x - 32, pokemon.y + 20, @viewport2)
      poketype.bitmap = Bitmap.new("Graphics/Pictures/types")
      type = pkmn.types.sample
      poketype.src_rect.set(0, GameData::Type.get(type).icon_position * 28, 64, 28)
      @map_sprites.push(pokemon, poketype)
    end
    #---------------------------------------------------------------------------
    # Draws the player's icon.
    #---------------------------------------------------------------------------
    coords = coordinate_check(@map_data["Player"])
    @player = @sprites["Player"] = IconSprite.new(coords[0], coords[1], @viewport2)
    @player.setBitmap(GameData::TrainerType.player_map_icon_filename($player.trainer_type))
    @map_sprites.push(@player)
    #---------------------------------------------------------------------------
    # Centers all map sprites.
    #---------------------------------------------------------------------------
    @map_sprites.each do |sprite|
      sprite.y += 8
      sprite.x += 16
    end
    #---------------------------------------------------------------------------
    # Draws all UI sprites.
    #---------------------------------------------------------------------------
    4.times do |i|
      @sprites["arrow_ui_#{i}"] = IconSprite.new(0, 0, @viewport2)
      @sprites["arrow_ui_#{i}"].bitmap = Bitmap.new(@path + "arrows")
      @sprites["arrow_ui_#{i}"].src_rect.set(16 * i, 0, 16, 16)
      case i
      when 0
        @sprites["map_arrow_ui_#{i}"] = AnimatedSprite.new("Graphics/Pictures/uparrow", 8, 28, 40, 2, @viewport2)
        @sprites["map_arrow_ui_#{i}"].x = (Graphics.width / 2) - 14
        @sprites["map_arrow_ui_#{i}"].y = 0
      when 1
        @sprites["map_arrow_ui_#{i}"] = AnimatedSprite.new("Graphics/Pictures/downarrow", 8, 28, 40, 2, @viewport2)
        @sprites["map_arrow_ui_#{i}"].x = (Graphics.width / 2) - 14
        @sprites["map_arrow_ui_#{i}"].y = Graphics.height - 44
      when 2
        @sprites["map_arrow_ui_#{i}"] = AnimatedSprite.new("Graphics/Pictures/leftarrow", 8, 40, 28, 2, @viewport2)
        @sprites["map_arrow_ui_#{i}"].x = 0
        @sprites["map_arrow_ui_#{i}"].y = (Graphics.height / 2) - 14
      when 3
        @sprites["map_arrow_ui_#{i}"] = AnimatedSprite.new("Graphics/Pictures/rightarrow", 8, 40, 28, 2, @viewport2)
        @sprites["map_arrow_ui_#{i}"].x = Graphics.width - 44
        @sprites["map_arrow_ui_#{i}"].y = (Graphics.height / 2) - 14
      end
      @sprites["map_arrow_ui_#{i}"].play
    end
    @cursor = @sprites["cursor_ui"] = IconSprite.new(0, 0, @viewport2)
    @cursor.bitmap = Bitmap.new(@path + "cursor")
    @cursor.src_rect.set(0, 0, 64, 64)
    @sprites["return_ui"] = IconSprite.new(Graphics.width - 125, Graphics.height - 77, @viewport2)
    @sprites["return_ui"].bitmap = Bitmap.new(@path + "map_ui")
    @sprites["return_ui"].src_rect.set(135, 0, 125, 77)
    @sprites["options_ui"] = IconSprite.new(Graphics.width - 122, Graphics.height - 26, @viewport2)
    @sprites["options_ui"].bitmap = Bitmap.new(@path + "map_ui")
    @sprites["options_ui"].src_rect.set(0, 56, 135, 26)
    @sprites["speedup_ui"] = IconSprite.new(0, Graphics.height - 26, @viewport2)
    @sprites["speedup_ui"].bitmap = Bitmap.new(@path + "map_ui")
    @sprites["speedup_ui"].src_rect.set(0, 30, 135, 26)
    @sprites["speedup_ui"].visible = false
    @sprites["select_ui"] = IconSprite.new(126, Graphics.height - 38, @viewport2)
    @sprites["select_ui"].bitmap = Bitmap.new(@path + "map_ui")
    @sprites["select_ui"].src_rect.set(0, 82, 260, 38)
    @sprites["keycount"] = IconSprite.new(-2, 38, @viewport2)
    @sprites["keycount"].bitmap = Bitmap.new(@path + "map_ui")
    @sprites["keycount"].src_rect.set(0, 0, 135, 30)
    @sprites["keycount"].visible = false
    #---------------------------------------------------------------------------
    # Finalizes map.
    #---------------------------------------------------------------------------
    lair_UpdateDarkness
    lair_UpdateHP
    lair_UpdateKeys
    lair_UpdateFloor
    lair_HideUISprites
    lair_AutoMapPosition(@sprites["Pokemon_10"], 8, true)
    lair_AutoMapPosition(@player, 2, true)
    pbBGMPlay("Dynamax Adventure")
    lair_MapIntro(type)
    if    @start_tile.x > @player.x then direction = 3 
    elsif @start_tile.x < @player.x then direction = 2
    elsif @start_tile.y > @player.y then direction = 1
    else                                 direction = 0
    end
    lair_MovePlayerIcon(direction)
    lair_ChooseRoute
  end
  
  #-----------------------------------------------------------------------------
  # Plays the intro to a lair map. Skippable in Debug mode.
  #-----------------------------------------------------------------------------
  def lair_MapIntro(type)
    return if $DEBUG && Input.press?(Input::CTRL)
    title = @sprites["title"] = IconSprite.new(Graphics.width / 2, 24, @viewport2)
    title.bitmap = Bitmap.new(@path + "Menus/menu_header")
    title.x -= @sprites["title"].bitmap.width / 2
    pbSetSmallFont(title.bitmap)
    text = [ [@map_name, title.bitmap.width / 2, 23, 2, Color.new(248, 248, 248), Color.new(0, 0, 0)] ]
    pbDrawTextPositions(title.bitmap, text)
    pbWait(50)
    lair_AutoMapPosition(@sprites["Pokemon_10"], 2)
    pbWait(15)
    @lair_pokemon.last.play_cry
    pbWait(15)
    pbMessage(_INTL("There's a strong {1}-type reaction coming from within the den!", GameData::Type.get(type).name))
    title.visible = false
    lair_AutoMapPosition(@player, 4)
  end
  
  #-----------------------------------------------------------------------------
  # Updates the viewable space in a dark lair.
  #-----------------------------------------------------------------------------
  def lair_UpdateDarkness(radius = false)
    if @darkness_map
      @darkness_bmp.setRadius(14, @player.x, @player.y) if radius
      @darkness_bmp.refresh([@player.x, @player.y])
    end
  end
  
  #-----------------------------------------------------------------------------
  # Updates the player's total and remaining hearts.
  #-----------------------------------------------------------------------------
  def lair_UpdateHP
    @knockouts = pbDynamaxAdventure.knockouts
    @max_hearts.times do |i|
      @sprites["hearts#{i}"] = IconSprite.new(4 + (i * 34), 4, @viewport2)
      @sprites["hearts#{i}"].bitmap = Bitmap.new(@path + "hearts")
      if @knockouts > i then @sprites["hearts#{i}"].src_rect.set(0, 0, 34, 30)   
      else                   @sprites["hearts#{i}"].src_rect.set(34, 0, 68, 30)
      end
    end
    pbUpdate
  end
  
  #-----------------------------------------------------------------------------
  # Updates the number of Lair Keys in the player's posession.
  #-----------------------------------------------------------------------------
  def lair_UpdateKeys
    @keycount  = pbDynamaxAdventure.keycount
    if @keycount > 0
      @sprites["keycount"].bitmap.clear
      @sprites["keycount"].bitmap = Bitmap.new(@path + "map_ui")
      @sprites["keycount"].src_rect.set(0, 0, 135, 30)
      startX, startY = 52, 11
      n = (@keycount == -1) ? 10 : @keycount.to_i.digits.reverse
      keyCounter = AnimatedBitmap.new(_INTL("Graphics/Plugins/ZUD/Battle/raid_num"))
      charWidth  = keyCounter.width / 11
      charHeight = keyCounter.height / 4
      n.each do |i|
        numberRect = Rect.new(i * charWidth, 0, charWidth, charHeight)
        @sprites["keycount"].bitmap.blt(startX, startY, keyCounter.bitmap, numberRect)
        startX += charWidth
      end
      @sprites["keycount"].visible = true
    else
      @sprites["keycount"].visible = false
    end
    pbUpdate
  end
  
  #-----------------------------------------------------------------------------
  # Updates the floor number of the current lair in Endless Mode.
  #-----------------------------------------------------------------------------
  def lair_UpdateFloor
    if @endless_mode
      floor_num = pbDynamaxAdventure.lair_floor
      @sprites["floorwindow"] = Window_AdvancedTextPokemon.new(_INTL("B#{floor_num}F"))
      @sprites["floorwindow"].setSkin("Graphics/Windowskins/goldskin")
      @sprites["floorwindow"].resizeToFit(@sprites["floorwindow"].text, Graphics.width)
      @sprites["floorwindow"].x = Graphics.width - (@sprites["floorwindow"].width + 4)
      @sprites["floorwindow"].y = 4
      @sprites["floorwindow"].viewport = @viewport2
    end
  end
  
  #-----------------------------------------------------------------------------
  # Views the party Summary while on the lair map.
  #-----------------------------------------------------------------------------
  def pbSummary(pokemon, pkmnid, hidesprites)
    oldsprites = pbFadeOutAndHide(hidesprites) { pbUpdate }
    scene  = PokemonSummary_Scene.new
    screen = PokemonSummaryScreen.new(scene, true)
    screen.pbStartScreen(pokemon, pkmnid)
    yield if block_given?
    pbFadeInAndShow(hidesprites, oldsprites) { pbUpdate }
  end
  
  #-----------------------------------------------------------------------------
  # Initiates a raid battle with a lair Pokemon.
  #-----------------------------------------------------------------------------
  def lair_StartBattle(index)
    if @sprites["Shadow_#{index}"].visible
      if $DEBUG && Input.press?(Input::CTRL) && index < @lair_pokemon.length - 1
        @sprites["Shadow_#{index}"].color.alpha = 0
        @sprites["Shadow_#{index}"].visible = false
        @sprites["Type_#{index}"].visible = false
        return
      end
      pbFadeOutIn {
        pbMessage(_INTL("\\me[Max Raid Intro]You ventured deeper into the lair...\\wt[34] ...\\wt[34] ...\\wt[60]!\\wtnp[8]")) if !($DEBUG && Input.press?(Input::CTRL))
        @sprites["Shadow_#{index}"].color.alpha = 0
        @sprites["Shadow_#{index}"].visible = false
        @sprites["Type_#{index}"].visible = false
        pbDynamaxAdventure.boss_battled = (@lair_pokemon[index] == @lair_pokemon.last)
        MaxRaidBattle.start(@lair_pokemon[index], {
            :size          => $player.party.length,
            :turns         => 10,
            :kocount       => @knockouts,
            :shield        => 5,
            :autoscale     => false,
            :simple        => true,
            :perfect_bonus => @knockouts == @max_hearts,
            :bgm           => (pbDynamaxAdventure.boss_battled) ? "Battle! Legendary Raid" : "Battle! Max Raid"
          },
          { :obtaintext => @map_name + "."}
        )
        lair_UpdateHP
      }
      if !pbDynamaxAdventure.ended?
        lair_UpdateDarkness(true)
        lair_AutoMapPosition(@player, 2) 
      end
    end
  end
  
  #-----------------------------------------------------------------------------
  # Gets the description text for each individual tile type. 
  #-----------------------------------------------------------------------------
  def lair_GetTileInfo(coords)
    @sprites.keys.each do |key|
      next if !@sprites[key].visible
      next if !@map_sprites.include?(@sprites[key])
      next if key.include?("background") || key.include?("Shadow")|| key.include?("Type")
      next if coords != [@sprites[key].x, @sprites[key].y]
      case key.split("_").first
      #-------------------------------------------------------------------------
      when "Pokemon"
        pbMessage(_INTL("This is a Raid Tile.\nPassing over this tile will initiate a battle against a wild Dynamaxed Pokémon."))
        pbMessage(_INTL("Once captured or defeated, this tile is cleared and the Pokémon cannot be challenged again."))
      #-------------------------------------------------------------------------
      when "TurnRandom"
        pbMessage(_INTL("This is a Random Turn Tile.\nPassing over this tile may force you into changing course in a random direction."))
      #-------------------------------------------------------------------------
      when "TurnFlip"
        pbMessage(_INTL("This is a Flip Turn Tile.\nLanding on this tile will force you to reverse course and travel in the opposite direction."))
      #-------------------------------------------------------------------------
      when "NPCSwap"
        pbMessage(_INTL("There's a Scientist on this tile.\nScientists have additional rental Pokémon you may add to your party by swapping out an existing party member."))
        pbMessage(_INTL("After encountering a Scientist, they will leave the map and this tile will be cleared."))
      #-------------------------------------------------------------------------
      when "NPCEquip"
        pbMessage(_INTL("There's a Backpacker on this tile.\nBackpackers carry a random assortment of items that may be given to your party Pokémon to hold."))
      #-------------------------------------------------------------------------
      when "NPCTrain"
        pbMessage(_INTL("There's a Blackbelt on this tile.\nBlackbelts have secret training techniques that can power up particular stats of your party Pokémon."))
      #-------------------------------------------------------------------------
      when "NPCTutor"
        pbMessage(_INTL("There's an Ace Trainer on this tile.\nAce Trainers can tutor your party Pokémon and teach them new moves for a strategical advantage."))
      #-------------------------------------------------------------------------
      when "NPCWard"
        pbMessage(_INTL("There's a Channeler on this tile.\nChannelers will raise your spirit, increasing your heart counter by one."))
        pbMessage(_INTL("After encountering a Channeler, they will leave the map and this tile will be cleared."))
      #-------------------------------------------------------------------------
      when "NPCHeal"
        pbMessage(_INTL("There's a Nurse on this tile.\nNurses will heal your party Pokémon back to full health."))
        pbMessage(_INTL("After encountering a Nurse, they will leave the map and this tile will be cleared."))
      #-------------------------------------------------------------------------
      when "NPCRandom"
        pbMessage(_INTL("It's a mystery who's on this tile.\nYou'll never know who you'll run into!"))
        pbMessage(_INTL("After encountering this mystery person, they will leave the map and this tile will be cleared."))
      #-------------------------------------------------------------------------
      when "Berry"
        pbMessage(_INTL("There's a pile of Berries on this tile.\nIf you land on this tile, you may feed your party Pokémon these Berries to recover some HP."))
        pbMessage(_INTL("This tile will become cleared after consuming the Berries."))
      #-------------------------------------------------------------------------
      when "Flare"
        pbMessage(_INTL("There's a Flare on this tile.\nIf you land on this tile, you'll light the Flare to increase your visibility."))
        pbMessage(_INTL("This tile will become cleared after the Flare has been used."))
      #-------------------------------------------------------------------------
      when "Key"
        pbMessage(_INTL("There's a Lair Key on this tile.\nIf you land on this tile, you'll collect the key and increase your total number of Lair Keys by one."))
        pbMessage(_INTL("This tile will become cleared after collecting the Lair Key."))
      #-------------------------------------------------------------------------
      when "Chest"
        pbMessage(_INTL("There's a Treasure Chest on this tile.\nIf you land on this tile, you may open the chest and discover the contents within."))
        pbMessage(_INTL("However, some chests you encounter may be locked and require the use of a Lair Key to be opened."))
        pbMessage(_INTL("Unlike with Locked Doors, a Locked Chest does not consume the Lair Key upon use."))
        pbMessage(_INTL("This tile will become cleared after the Treasure Chest has been opened."))
      #-------------------------------------------------------------------------
      when "Door"
        pbMessage(_INTL("This is a Locked Door Tile.\nA locked door prevents movement on this path unless you have acquired a Lair Key to open it."))
        pbMessage(_INTL("Opening the door will clear the tile, and allow you to proceed. However, this will consume one of your Lair Keys."))
      #-------------------------------------------------------------------------
      when "Block"
        pbMessage(_INTL("This is a Roadblock Tile.\nAn obstacle prevents movement on this path unless you meet certain criteria."))
        pbMessage(_INTL("Once the obstacle's criteria has been met, this tile will become cleared and you will not be required to clear the obstacle again."))
      #-------------------------------------------------------------------------
      when "Warp"
        pbMessage(_INTL("This is a Warp Tile.\nLanding on this tile will teleport you to another Warp Tile on the map that is linked to this one."))
      #-------------------------------------------------------------------------
      when "Reset"
        pbMessage(_INTL("This is a Reset Tile.\nLanding on this tile will teleport you back to the Start Tile of this map."))
      #-------------------------------------------------------------------------
      when "Switch"
        pbMessage(_INTL("This is a Switch Tile.\nLanding on this tile will flip all switches to the ON position, revealing hidden tiles that are normally inactive."))
        pbMessage(_INTL("Landing on a Switch Tile that is already in the ON position will revert all switches to the OFF position, and any revealed tiles will return to their inactive state."))
      #-------------------------------------------------------------------------
      else
        #-----------------------------------------------------------------------
        # Start tile.
        #-----------------------------------------------------------------------
        if coords == [@start_tile.x, @start_tile.y]
          pbMessage(_INTL("This is the Start Tile.\nThis will always be the first tile you move towards."))
        #-----------------------------------------------------------------------
        # Directional tile.
        #-----------------------------------------------------------------------
        elsif lair_CanTurn?(nil, coords)
          pbMessage(_INTL("This is a Directional Tile.\nPassing over this tile will force you to move in the direction it's pointing."))
        #-----------------------------------------------------------------------
        # Selection tile.
        #-----------------------------------------------------------------------
        elsif lair_CanMove?(nil, coords)
          pbMessage(_INTL("This is a Selection Tile.\nLanding on this tile will allow you to choose a new path to travel in."))
          pbMessage(_INTL("The number of paths you can choose from varies with each individual Selection Tile."))
        end
      end
      break
    end
  end
  
  #-----------------------------------------------------------------------------
  # General map utilities.
  #-----------------------------------------------------------------------------
  def lair_HideUISprites
    @sprites.keys.each do |key|
      next if !key.include?("_ui")
      @sprites[key].visible = false
    end
  end
  
  def pbUpdate
    pbUpdateSpriteHash(@sprites)
  end
  
  def pbEndScene
    pbFadeOutAndHide(@sprites) { pbUpdate }
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
    @viewport2.dispose
    @darkness_bmp.dispose if @darkness_map
    pbBGMFade(1.0)
    pbSEPlay("Door exit")
    pbWait(25)
  end
end


#===============================================================================
# Sets up the darkness sprite used in Dark Lairs.
#===============================================================================
class LairDarknessSprite < SpriteWrapper
  attr_reader :radius

  def initialize(viewport = nil)
    super(viewport)
    @darkness = BitmapWrapper.new(Graphics.width, Graphics.height)
    @radius = radiusMin
    self.bitmap = @darkness
    self.z      = 99999
    refresh([0, 0])
  end

  def dispose
    @darkness.dispose
    super
  end

  def radiusMin; return 64;      end
  def radiusMax; return 176;     end
  def radiusCur; return @radius; end
  
  def radius=(value)
    @radius = value
  end
  
  def setRadius(*args)
    if radiusCur < radiusMax
      @radius = radiusCur + args[0]
      @radius = radiusMax if @radius > radiusMax
    end
    pbSEPlay("Vs flash")
    refresh([args[1], args[2]])
    pbWait(30)
  end

  def refresh(coords)
    @darkness.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(0, 0, 0, 255))
    cx = coords[0] + 16
    cy = coords[1] + 16
    cradius = @radius
    numfades = 5
    for i in 1..numfades
      for j in cx - cradius..cx + cradius
        diff2 = (cradius * cradius) - ((j - cx) * (j - cx))
        diff = Math.sqrt(diff2)
        @darkness.fill_rect(j, cy - diff, 1, diff * 2, Color.new(0, 0, 0, 255.0 * (numfades - i) / numfades))
      end
      cradius = (cradius * 0.9).floor
    end
  end
end


#===============================================================================
# Used for calling the Max Lair Map screen.
#===============================================================================
class LairMapScreen
  def initialize(scene)
    @scene = scene
  end

  def pbStartScreen(map)
    @scene.pbStartScene(map)
    @scene.pbEndScene
  end
end

def pbMaxLairMap(map)
  scene  = LairMapScene.new
  screen = LairMapScreen.new(scene)
  screen.pbStartScreen(map)
end