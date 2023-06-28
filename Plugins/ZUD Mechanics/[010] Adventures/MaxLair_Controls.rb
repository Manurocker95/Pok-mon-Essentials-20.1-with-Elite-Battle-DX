#===============================================================================
# Max Lair - Map movement related functions.
#===============================================================================
class LairMapScene
  #-----------------------------------------------------------------------------
  # Returns whether there is a cardinal directional tile at the given coordinates.
  # Uses the player's coordinates if none are given.
  # Direction may be set to check for a specific cardinal direction.
  #-----------------------------------------------------------------------------
  def lair_CanTurn?(direction = nil, coords = nil)
    direction = "Turn" if !["North", "South", "West", "East"].include?(direction)
    return lair_TileType(direction, coords).is_a?(Numeric)
  end
  
  #-----------------------------------------------------------------------------
  # Returns whether there is a Selection tile at the given coordinates.
  # Uses the player's coordinates if none are given.
  # Direction may be set to check if the chosen Selection tile allows for
  # movement in that cardinal direction.
  #-----------------------------------------------------------------------------
  def lair_CanMove?(direction = nil, coords = nil)
    ret = lair_TileType("Select", coords)
    return ret.is_a?(Array) if !direction
    case direction
    when "North" then return ret.include?(0)
    when "South" then return ret.include?(1)
    when "West"  then return ret.include?(2)
    when "East"  then return ret.include?(3)
    end
  end
  
  #-----------------------------------------------------------------------------
  # Returns whether there is a specified type of tile at the given coordinates.
  # Uses the player's coordinates if none are given.
  # Tile must be set to a string that appears in a specific tile's sprite key.
  # For example, set tile to "Warp" to check if the tile is a Warp tile.
  #-----------------------------------------------------------------------------
  def lair_OnTile?(tile = "", coords = nil)
    coords = [@player.x, @player.y] if !coords
    @sprites.keys.each do |key|
      next if !key.include?(tile)
      next if !@sprites[key].visible
      tile_pos = [@sprites[key].x, @sprites[key].y]
      return true if coords == tile_pos
    end
    return false
  end
  
  #-----------------------------------------------------------------------------
  # Returns values related to the specified tile type at the given coordinates.
  # Uses the player's coordinates if none are given.
  # Tile must be set to a string that appears in a specific tile's sprite key.
  # For example, set tile to "NPC" to get the value of the specific type of
  # NPC event used for this tile, if any.
  #-----------------------------------------------------------------------------
  def lair_TileType(tile = "", coords = nil)
    return if !lair_OnTile?(tile, coords)
    coords = [@player.x, @player.y] if !coords
    @sprites.keys.each do |key|
      next if !key.include?(tile)
      next if !@sprites[key].visible
      next if coords != [@sprites[key].x, @sprites[key].y]
      case key.split("_").first
      #-------------------------------------------------------------------------
      # Directional values.
      #-------------------------------------------------------------------------
      when "TurnNorth"   then return 0
      when "TurnSouth"   then return 1
      when "TurnWest"    then return 2
      when "TurnEast"    then return 3
      when "TurnRandom"  then return 4
      when "TurnFlip"    then return 5
      #-------------------------------------------------------------------------
      # Event values.
      #-------------------------------------------------------------------------
      when "NPCSwap"   then return 0
      when "NPCEquip"  then return 1
      when "NPCTrain"  then return 2
      when "NPCTutor"  then return 3
      when "NPCWard"   then return 4
      when "NPCHeal"   then return 5
      when "NPCRandom" then return 6
      #-------------------------------------------------------------------------
      # Selection values.
      #-------------------------------------------------------------------------
      when "SelectNS"    then return [0, 1]
      when "SelectNW"    then return [0, 2]
      when "SelectNE"    then return [0, 3]
      when "SelectSW"    then return [1, 2]
      when "SelectSE"    then return [1, 3]
      when "SelectWE"    then return [2, 3]
      when "SelectNSW"   then return [0, 1, 2]
      when "SelectNSE"   then return [0, 1, 3]
      when "SelectNWE"   then return [0, 2, 3]
      when "SelectSWE"   then return [1, 2, 3]
      when "SelectNSWE"  then return [0, 1, 2, 3]
      #-------------------------------------------------------------------------
      # All other values are derived from the tile's index, or whatever value
      # appears last in the sprite's key.
      #-------------------------------------------------------------------------
      else return key.split("_").last.to_i
      end
    end
  end
  
  #-----------------------------------------------------------------------------
  # Triggers the event related to the specific tile the player is on.
  # Index refers to the player's current directional movement, from 0-3.
  # If a triggered tile would alter the player's movement, then this returns the
  # new index associated with the new direction the player should move in.
  #-----------------------------------------------------------------------------
  def lair_TriggerTile(index)
    clear = reset = false
    coords = [@player.x, @player.y]
    #---------------------------------------------------------------------------
    # The order in which tiles are triggered. Specifically done so in case there
    # are multiple events stacked on a single tile for whatever reason.
    #---------------------------------------------------------------------------
    tiles = ["Trap", "Block", "Door", "Pokemon", "NPC", "Chest", "Berry", "Key", 
             "Flare", "Switch", "Warp", "Reset", "Turn", "Select", "Start"]
    tiles.each do |type|
      next if !lair_OnTile?(type)
      value = lair_TileType(type)
      case type
      #-------------------------------------------------------------------------
      # Tile effects.
      #-------------------------------------------------------------------------
      when "Trap"
        clear = pbDynamaxAdventure.lair_tile_trap(value)
      #-------------------------------------------------------------------------
      when "Block"
        clear = pbDynamaxAdventure.lair_tile_block(value)
        index = lair_RedirectMovement(index) if !clear
      #-------------------------------------------------------------------------
      when "Door"
        clear = pbDynamaxAdventure.lair_tile_door
        index = lair_RedirectMovement(index) if !clear
        lair_UpdateKeys
      #-------------------------------------------------------------------------
      when "Pokemon" then lair_StartBattle(value)
      #-------------------------------------------------------------------------
      when "NPC"
        case value
        when 0 # Scientist
          clear = pbDynamaxAdventure.lair_npc_swap
        when 1 # Backpacker
          pbDynamaxAdventure.lair_npc_equip
        when 2 # Blackbelt
          pbDynamaxAdventure.lair_npc_train
        when 3 # Ace Trainer
          pbDynamaxAdventure.lair_npc_tutor
        when 4 # Channeler
          pbDynamaxAdventure.lair_npc_ward_intro
          @knockouts = pbDynamaxAdventure.knockouts
          @max_hearts += 1 if @max_hearts < 6
          lair_UpdateHP
          clear = pbDynamaxAdventure.lair_npc_ward_outro
        when 5 # Nurse
          clear = pbDynamaxAdventure.lair_npc_heal
        when 6 # Random
          clear = pbDynamaxAdventure.lair_npc_random
        end
      #-------------------------------------------------------------------------
      when "Chest"
        clear = pbDynamaxAdventure.lair_tile_chest(value)
        reset = value.digits.first == 0
      #-------------------------------------------------------------------------
      when "Berry"
        clear = pbDynamaxAdventure.lair_tile_berry
      #-------------------------------------------------------------------------
      when "Key"
        clear = pbDynamaxAdventure.lair_tile_key
        lair_UpdateKeys
      #-------------------------------------------------------------------------
      when "Flare"
        clear = pbDynamaxAdventure.lair_tile_flare
        lair_UpdateDarkness(true)
      #-------------------------------------------------------------------------
      when "Switch"
        lair_SwitchToggle
      #-------------------------------------------------------------------------
      when "Warp"
        lair_WarpPlayer(value)
      #-------------------------------------------------------------------------
      when "Reset"
        reset = true
      #-------------------------------------------------------------------------
      when "Turn"
        case value
        when 4 then index = lair_RedirectMovement(index, true)
        when 5 then index = lair_RedirectMovement(index)
        else        index = value
        end
      #-------------------------------------------------------------------------
      when "Start", "Select" then index = -1
      #-------------------------------------------------------------------------
      end
      break
    end
    lair_ClearTile if clear
    index = lair_RestartPosition(true) if reset
    return index
  end
  
  #-----------------------------------------------------------------------------
  # Used for reversing the player's movement path, where index refers to the
  # player's current directional movement, from 0-3.
  # Returns a random new direction instead if random = true. Cannot randomize
  # the player back in the opposite direction they were just moving in.
  #-----------------------------------------------------------------------------
  def lair_RedirectMovement(index, random = false)
    case index
    when 0 then new_index = 1
    when 1 then new_index = 0
    when 2 then new_index = 3
    when 3 then new_index = 2
    end
    if random
      directions = [0, 1, 2, 3]
      directions.delete(new_index)
      return directions.sample
    end
    return new_index
  end
  
  #-----------------------------------------------------------------------------
  # Warps the player to the next available Warp tile.
  # Warp tiles are linked in sequential order, in the order they are listed in 
  # the adventure_maps.txt PBS file. The final warp tile listed links back to 
  # the first. If the next available Warp tile is not visible for some reason, 
  # skips to the next available Warp tile in the list.
  #-----------------------------------------------------------------------------
  def lair_WarpPlayer(value)
    first_warp = next_warp = nil
    @sprites.keys.each do |key|
      next if !key.include?("Warp")
      next if !@sprites[key].visible
      first_warp = @sprites[key] if !first_warp
      num = key.split("_").last.to_i
      next_warp = @sprites[key] if num > value
      break if next_warp
    end
    next_warp = first_warp if !next_warp
    pbWait(20)
    pbSEPlay("Player jump")
    @player.visible = false
    @player.x = next_warp.x
    @player.y = next_warp.y
    lair_AutoMapPosition(@player, 8)
    pbSEPlay("Player jump")
    @player.visible = true
    pbWait(20)
  end
  
  #-----------------------------------------------------------------------------
  # Transports the player back to the start tile of the lair.
  #-----------------------------------------------------------------------------
  def lair_RestartPosition(msg = false)
    pbFadeOutIn {
      @player.x = @start_tile.x
      @player.y = @start_tile.y
      lair_AutoMapPosition(@player, 2, true)
      pbSEPlay(sprintf("Anim/Teleport"))
    }
    pbMessage(_INTL("You were suddenly transported back to the entrance of the lair!")) if msg
    return -1
  end
  
  #-----------------------------------------------------------------------------
  # Toggles the visibility of all Hidden tiles on the map, as well as toggling 
  # all Switch tiles between the ON and OFF positions.
  #-----------------------------------------------------------------------------
  def lair_SwitchToggle
    pbWait(10)
    pbSEPlay("Voltorb flip tile")
    @sprites.keys.each do |key|
      if key.include?("Hidden")
        @sprites[key].visible = !@sprites[key].visible
      elsif key.include?("Switch")
        icon = @sprites[key].src_rect.x
        pos = (icon == 128) ? 160 : 128
        @sprites[key].src_rect.set(pos, 32, 32, 32)
      end
    end
  end
  
  #-----------------------------------------------------------------------------
  # Switches off the visibility of whatever tile the player is currently on,
  # preventing that tile's effects from being triggerable again.
  #-----------------------------------------------------------------------------
  def lair_ClearTile
    coords = [@player.x, @player.y]
    for sprite in @map_sprites
      next if [@player, @start_tile, @sprites["background"]].include?(sprite)
      sprite.visible = false if coords == [sprite.x, sprite.y]
    end
  end
  
  #-----------------------------------------------------------------------------
  # Toggles the opacity for Pokemon shadow sprites. Used during movement for
  # better map visibility.
  #-----------------------------------------------------------------------------
  def lair_ChangePokeOpacity(fade = true)
    @sprites.keys.each do |key|
      next if !@map_sprites.include?(@sprites[key])
      next if !key.include?("Shadow")
      if fade then @sprites[key].opacity = 100
      else         @sprites[key].opacity = 255
      end
    end
  end
  
  #-----------------------------------------------------------------------------
  # Moves the player's icon around the map. Index refers to the player's current
  # directional movement, from 0-3. Speed refers to how many pixels the player's
  # icon will move per frame. 
  # Movement is instantaneous if the ACTION button is held.
  #-----------------------------------------------------------------------------
  def lair_MovePlayerIcon(index = 0, speed = 2)
    lair_ChangePokeOpacity
    loop do
      boundsReached = (@player.x < 32 || 
                       @player.y < 32 || 
                       @player.x > Graphics.width - 32 || 
                       @player.y > Graphics.height - 32)
      instant = (Input.press?(Input::ACTION)) ? true : false
      pbWait(1) if !instant
      case index
      when 0 then @player.y -= speed
      when 1 then @player.y += speed
      when 2 then @player.x -= speed
      when 3 then @player.x += speed
      else break
      end
      index = lair_TriggerTile(index)
      lair_UpdateDarkness
      lair_AutoMapPosition(@player,speed) if boundsReached
      break if pbDynamaxAdventure.ended?
    end
  end
  
  #-----------------------------------------------------------------------------
  # Automatically scrolls the map to the correct position when needed.
  # Sprite refers to the specific sprite the camera should center on when
  # positioning itself, usually the player's icon.
  # Speed refers to how many pixels the map should scroll per frame to reach its
  # destination.
  # Scrolling is instantaneous when instant = true.
  #-----------------------------------------------------------------------------
  def lair_AutoMapPosition(sprite, speed, instant = false)
    xBoundsReached = false
    yBoundsReached = false
    center = [(Graphics.width / 2) - 16, (Graphics.height / 2) - 16]
    loop do
      coords = [sprite.x, sprite.y]
      xBoundsReached = true if coords[0] == center[0]
      yBoundsReached = true if coords[1] == center[1]
      lair_UpdateDarkness
      #-------------------------------------------------------------------------
      # X-axis movement.
      #-------------------------------------------------------------------------
      if !xBoundsReached
        # Target sprite is left of center.
        if coords[0] < center[0]
          if @sprites["background"].x + 2 * speed >= @leftBounds + 2
            xBoundsReached = true
          else
            if (center[0] - coords[0]) % (2 * speed) == 0
              pbWait(1) if !instant
              @map_sprites.each { |sp| sp.x += 2 * speed }
            else
              @map_sprites.each { |sp| sp.x += 1 }
            end
          end
        end
        # Target sprite is right of center.
        if coords[0] > center[0]
          if @sprites["background"].x - 2 * speed <= @rightBounds + 2
            xBoundsReached = true
          else
            if (coords[0] - center[0]) % (2 * speed) == 0
              pbWait(1) if !instant
              @map_sprites.each { |sp| sp.x -= 2 * speed }
            else
              @map_sprites.each { |sp| sp.x -= 1 }
            end
          end
        end
      #-------------------------------------------------------------------------
      # Y-axis movement.
      #-------------------------------------------------------------------------
      elsif !yBoundsReached
        # Target sprite is above center.
        if coords[1] < center[1]
          if @sprites["background"].y + 2 * speed >= @upperBounds + 2
            yBoundsReached = true
          else
            if (center[1] - coords[1]) % (2 * speed) == 0
              pbWait(1) if !instant
              @map_sprites.each { |sp| sp.y += 2 * speed }
            else
              @map_sprites.each { |sp| sp.y += 1 }
            end
          end
        end
        # Target sprite is below center.
        if coords[1] > center[1]
          if @sprites["background"].y - 2 * speed <= @lowerBounds + 2
            yBoundsReached = true
          else
            if (coords[1] - center[1]) % (2 * speed) == 0
              pbWait(1) if !instant
              @map_sprites.each { |sp| sp.y -= 2 * speed }
            else
              @map_sprites.each { |sp| sp.y -= 1 }
            end
          end
        end
      end
      break if xBoundsReached && yBoundsReached
    end
  end
  
  #-----------------------------------------------------------------------------
  # Allows for player-controlled map scrolling while viewing the Max Lair map.
  #-----------------------------------------------------------------------------
  def lair_MapScroll
    move = 8
    lair_HideUISprites
    @cursor.x = @player.x - 16
    @cursor.y = @player.y - 16
    @cursor.visible = true
    @sprites["return_ui"].visible = true
    @sprites.keys.each do |key|
      next if !key.include?("Pokemon")
      @sprites[key].visible = true
    end
    loop do
      Graphics.update
      Input.update
      pbUpdate
      4.times { |i| @sprites["map_arrow_ui_#{i}"].visible = true }
      #-------------------------------------------------------------------------
      # Scroll map and cursor upwards.
      #-------------------------------------------------------------------------
      if Input.press?(Input::UP)
        @cursor.y -= move if @cursor.y > 0
        if @sprites["background"].y <= @upperBounds - move
          @map_sprites.each { |sp| sp.y += move }
          lair_UpdateDarkness
        else
          @sprites["map_arrow_ui_0"].visible = false
        end
      end
      #-------------------------------------------------------------------------
      # Scroll map and cursor downwards.
      #-------------------------------------------------------------------------
      if Input.press?(Input::DOWN)
        @cursor.y += move if @cursor.y <= Graphics.height - 72
        if @sprites["background"].y >= @lowerBounds + move
          @map_sprites.each { |sp| sp.y -= move }
          lair_UpdateDarkness
        else
          @sprites["map_arrow_ui_1"].visible = false
        end
      end
      #-------------------------------------------------------------------------
      # Scroll map and cursor to the left.
      #-------------------------------------------------------------------------
      if Input.press?(Input::LEFT)
        @cursor.x -= move if @cursor.x > 0
        if @sprites["background"].x <= @leftBounds - move
          @map_sprites.each { |sp| sp.x += move }
          lair_UpdateDarkness
        else
          @sprites["map_arrow_ui_2"].visible = false
        end
      end
      #-------------------------------------------------------------------------
      # Scroll map and cursor to the right.
      #-------------------------------------------------------------------------
      if Input.press?(Input::RIGHT)
        @cursor.x += move if @cursor.x <= Graphics.width - 72
        if @sprites["background"].x >= @rightBounds + move
          @map_sprites.each { |sp| sp.x -= move }
          lair_UpdateDarkness
        else
          @sprites["map_arrow_ui_3"].visible = false
        end
      end
      #-------------------------------------------------------------------------
      # Toggle Pokemon and type icon sprite visibility.
      #-------------------------------------------------------------------------
      if Input.trigger?(Input::ACTION)
        pbSEPlay("GUI party switch")
        @sprites.keys.each do |key|
          if key.include?("Shadow") || key.include?("Type")
            @sprites[key].visible = !@sprites[key].visible
          end
        end
      end
      #-------------------------------------------------------------------------
      # Gets tile information.
      #-------------------------------------------------------------------------
      if lair_CursorReact.is_a?(Array) && !@darkness_map
        @cursor.src_rect.set(64, 0, 64, 64)
        if Input.trigger?(Input::USE)
          @cursor.x = lair_CursorReact[0] - 16 
          @cursor.y = lair_CursorReact[1] - 16
          @cursor.src_rect.set(64, 0, 64, 64)
          newcoords = [@cursor.x + 16, @cursor.y + 16]
          lair_GetTileInfo(newcoords)
        end
      end
      #-------------------------------------------------------------------------
      # Cycles through raid species from first to last.
      #-------------------------------------------------------------------------
      if Input.trigger?(Input::JUMPUP)
        coords = [@cursor.x + 16, @cursor.y + 16]
        index = lair_TileType("Pokemon", coords) || 0
        case index
        when @lair_pokemon.length - 1
          sprite = @sprites["Pokemon_0"]
        else
          index += 1
          sprite = @sprites["Pokemon_#{index}"]
        end
        pbSEPlay("GUI party switch")
        lair_AutoMapPosition(sprite, move, true)
        @cursor.x = sprite.x - 16
        @cursor.y = sprite.y - 16
      #-------------------------------------------------------------------------
      # Cycles through raid species from last to first.
      #-------------------------------------------------------------------------
      elsif Input.trigger?(Input::JUMPDOWN)
        coords = [@cursor.x + 16, @cursor.y + 16]
        index = lair_TileType("Pokemon", coords) || 0
        case index
        when 0
          index = @lair_pokemon.length - 1
          sprite = @sprites["Pokemon_#{index}"]
        else
          index -= 1
          sprite = @sprites["Pokemon_#{index}"]
        end
        pbSEPlay("GUI party switch")
        lair_AutoMapPosition(sprite, move, true)
        @cursor.x = sprite.x - 16
        @cursor.y = sprite.y - 16
      end
      #-------------------------------------------------------------------------
      # Returns to route selection.
      #-------------------------------------------------------------------------
      if Input.trigger?(Input::BACK)
        pbPlayCancelSE
        lair_HideUISprites
        @lair_pokemon.length.times do |i|
          if @sprites["Shadow_#{i}"].color.alpha == 255
            @sprites["Shadow_#{i}"].visible = true
            @sprites["Type_#{i}"].visible = true
          else
            @sprites["Shadow_#{i}"].visible = false
            @sprites["Type_#{i}"].visible = false
          end
        end
        lair_AutoMapPosition(@player, move)
        @sprites["select_ui"].visible = true
        @sprites["options_ui"].visible = true
        break
      end
    end
  end
  
  #-----------------------------------------------------------------------------
  # Changes the map view cursor while hovering over a selectable tile.
  #-----------------------------------------------------------------------------
  def lair_CursorReact
    select = nil
    @cursor.src_rect.set(0, 0, 64, 64)
    @sprites.keys.each do |key|
      next if !@map_sprites.include?(@sprites[key])
      next if key.include?("background") || key.include?("Shadow")|| key.include?("Type")
      next if !@sprites[key].visible || key.include?("Trap")
      withinXRange = ((@sprites[key].x - 20)..(@sprites[key].x + 20)).include?(@cursor.x + 16)
      withinYRange = ((@sprites[key].y - 20)..(@sprites[key].y + 20)).include?(@cursor.y + 16)
      select = [@sprites[key].x, @sprites[key].y] if withinXRange && withinYRange
    end
    return select
  end
  
  #-----------------------------------------------------------------------------
  # Allows the player to select a route to take while on a Selection tile.
  #-----------------------------------------------------------------------------
  def lair_ChooseRoute
    endgame = false
    loop do
      break if pbDynamaxAdventure.ended?
      lair_AutoMapPosition(@player, 2)
      lair_ChangePokeOpacity(false)
      @sprites["speedup_ui"].visible = false
      pbMessage(_INTL("Which path would you like to take?"))
      coords = [@player.x, @player.y]
      index = 3 if lair_CanMove?("East")
      index = 2 if lair_CanMove?("West")
      index = 1 if lair_CanMove?("South")
      index = 0 if lair_CanMove?("North")
      @sprites["arrow_ui_#{index}"].color = Color.new(255, 0, 0, 200)
      loop do
        Graphics.update
        Input.update
        pbUpdate
        @sprites["arrow_ui_0"].y = @player.y - 16
        @sprites["arrow_ui_1"].y = @player.y + 32
        @sprites["arrow_ui_0"].x = @sprites["arrow_ui_1"].x = @player.x + 8
        @sprites["arrow_ui_2"].x = @player.x - 16
        @sprites["arrow_ui_3"].x = @player.x + 32
        @sprites["arrow_ui_2"].y = @sprites["arrow_ui_3"].y = @player.y + 10
        indexes = lair_TileType("Select")
        indexes.each { |i| @sprites["arrow_ui_#{i}"].visible = true }
        @sprites["select_ui"].visible  = true
        @sprites["options_ui"].visible = true
        #-----------------------------------------------------------------------
        # Selects between available routes to take.
        #-----------------------------------------------------------------------
        if Input.trigger?(Input::UP) && lair_CanMove?("North")
          pbPlayDecisionSE
          index = 0
        elsif Input.trigger?(Input::DOWN) && lair_CanMove?("South")
          pbPlayDecisionSE
          index = 1
        elsif Input.trigger?(Input::LEFT) && lair_CanMove?("West")
          pbPlayDecisionSE
          index = 2
        elsif Input.trigger?(Input::RIGHT) && lair_CanMove?("East")
          pbPlayDecisionSE
          index = 3
        end
        4.times do |i|
          if i == index
            @sprites["arrow_ui_#{i}"].color = Color.new(255, 0, 0, 200)
          else
            @sprites["arrow_ui_#{i}"].color = Color.new(0, 0, 0, 0)
          end
        end
        #-----------------------------------------------------------------------
        # Confirms a selected route.
        #-----------------------------------------------------------------------
        if Input.trigger?(Input::USE)
          if pbConfirmMessage(_INTL("Are you sure you want to take this path?"))
            lair_HideUISprites
            @sprites["speedup_ui"].visible = true
            lair_MovePlayerIcon(index)
            break
          end
        #-----------------------------------------------------------------------
        # Options menu.
        #-----------------------------------------------------------------------
        elsif Input.trigger?(Input::ACTION)
          cmd = 0
          commands = [_INTL("View Map"), _INTL("View Party")]
          commands.push(_INTL("View Record")) if @endless_mode && lair_EndlessRecord[:floor] > 1
          commands.push(_INTL("Leave Lair"))
          loop do
            cmd = pbMessage(_INTL("What would you like to do?"), commands, -1, nil, 0)
            case cmd
            when -1 then break
            when 0 then lair_MapScroll; break
            when 1 then pbSummary($player.party, 0, @sprites); break
            when commands.length - 1
              if pbConfirmMessage(_INTL("End your Dynamax Adventure?\nAny captured Pokémon and acquired treasure will be lost."))
                endgame = true
                break
              end
            else pbMaxLairMenu(:record)
            end
          end
          break if endgame
        end
      end
      break if endgame  
    end
    #---------------------------------------------------------------------------
    # Resets the entire lair from the start if playing in Endless Mode.
    #---------------------------------------------------------------------------
    if @endless_mode && pbDynamaxAdventure.victory?
      pbMessage(_INTL("The storm seems to have died down a bit..."))
      pbDynamaxAdventure.boss_species = nil
      pbDynamaxAdventure.boss_battled = false
      pbDynamaxAdventure.lair_floor += 1
      pbDynamaxAdventure.darkness_lvl = @darkness_bmp.radiusCur if @darkness_map
    else
      pbMessage(_INTL("Your Dynamax Adventure is over!"))
      pbDynamaxAdventure.abandoned = endgame
    end
  end
end