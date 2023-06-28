#===============================================================================
# Max Raid Den.
#===============================================================================
class MaxRaidScene
  BASE   = Color.new(248, 248, 248)
  SHADOW = Color.new(0, 0, 0)
  
  def pbUpdate
    pbUpdateSpriteHash(@sprites)
  end
   
  def pbEndScene
    pbUpdate
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
    $game_temp.dx_clear
  end
  
  #-----------------------------------------------------------------------------
  # Hash used for field conditions display.
  #-----------------------------------------------------------------------------
  def raid_FieldHash
    return {
      # Weather
      :Sun         => 1,
      :Rain        => 2,
      :Sandstorm   => 3,
      :Hail        => 4,
      :ShadowSky   => 5,
      :Fog         => 6, # Unimplemented
      :HarshSun    => 7, # Unused
      :HeavyRain   => 8, # Unused
      :StrongWinds => 9, # Unused
      
      # Terrain
      :Electric    => 1,
      :Grassy      => 2,
      :Misty       => 3,
      :Psychic     => 4,
      
      # Environment
      :None        => 1,  # Urban
      :Grass       => 2,  # Fields
      :TallGrass   => 2,  # Fields
      :MovingWater => 3,  # Aquatic
      :StillWater  => 3,  # Aquatic
      :Puddle      => 4,  # Wetlands
      :Underwater  => 5,  # Underwater
      :Cave        => 6,  # Cavern
      :Rock        => 7,  # Rocky
      :Sand        => 8,  # Sandy
      :Forest      => 9,  # Forest
      :ForestGrass => 9,  # Forest
      :Snow        => 10, # Frosty
      :Ice         => 10, # Frosty
      :Volcano     => 11, # Volcanic
      :Graveyard   => 12, # Spiritual
      :Sky         => 13, # Sky
      :Space       => 14, # Space
      :UltraSpace  => 15  # Ultra Space
    }
  end
  
  #-----------------------------------------------------------------------------
  # Saves the game and saves a new Max Raid Pokemon for this event.
  #-----------------------------------------------------------------------------
  def raid_SavingPrompt(pkmn)
    save_game = false
    @interp = pbMapInterpreter
    @this_event = @interp.get_self
    raid_pkmn = @interp.getVariable
    # Holding CTRL in Debug mode skips the saving prompt.
    if $DEBUG && Input.press?(Input::CTRL)
      @interp.setVariable(nil)
      pbMessage(_INTL("You peered into the raid den before you..."))
      return true
    end
    if !raid_pkmn
      if pbConfirmMessage(_INTL("You must save the game before entering a new raid den. Is this ok?"))
        save_game = true
        if SaveData.exists? && $game_temp.begun_new_game
          pbMessage(_INTL("WARNING!"))
          pbMessage(_INTL("There is a different game file that is already saved."))
          pbMessage(_INTL("If you save now, the other file's adventure, including items and Pokémon, will be entirely lost."))
          if !pbConfirmMessageSerious(_INTL("Are you sure you want to save now and overwrite the other save file?"))
            pbSEPlay("GUI save choice")
            save_game = false
          end
        end
      else
        pbSEPlay("GUI save choice")
      end
      if save_game
        $game_temp.begun_new_game = false
        pbSEPlay("GUI save choice")
        @interp.setVariable(pkmn)
        if Game.save
          pbMessage(_INTL("\\se[]{1} saved the game.\\me[GUI save game]\\wtnp[30]", $player.name))
        else
          pbMessage(_INTL("\\se[]Save failed.\\wtnp[30]"))
          @interp.setVariable(nil)
          save_game = false
        end
      end
      return save_game
    else
      pbMessage(_INTL("You peered into the raid den before you..."))
      return true
    end
  end
  
  #-----------------------------------------------------------------------------
  # Initializes the raid den.
  #-----------------------------------------------------------------------------
  def pbStartScene(pkmn)
    @sprites    = {}
    @viewport   = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    $PokemonGlobal.nextBattleBGM = nil
    return false if !raid_SavingPrompt(pkmn)
    @rules = $game_temp.dx_rules
    @pkmn  = (@interp.getVariable) ? @interp.getVariable : pkmn
    @path  = "Graphics/Plugins/ZUD/Raid Den/"
    @sprites["overlay"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    @overlay = @sprites["overlay"].bitmap
    pbSetSmallFont(@overlay)
    @sprites["raidentry"] = IconSprite.new(0, 0)
    @sprites["raidentry"].setBitmap(@path + "raid_bg_entry")
    @sprites["usebutton"] = IconSprite.new(346, 214)
    @sprites["usebutton"].setBitmap("Graphics/Pictures/Controls help/help_usekey")
    @sprites["usebutton"].zoom_x = 0.5
    @sprites["usebutton"].zoom_y = 0.5
    @sprites["backbutton"] = IconSprite.new(346, 151)
    @sprites["backbutton"].setBitmap("Graphics/Pictures/Controls help/help_backkey")
    @sprites["backbutton"].zoom_x = 0.5
    @sprites["backbutton"].zoom_y = 0.5
    @sprites["actionbutton"] = IconSprite.new(54, 292)
    @sprites["actionbutton"].setBitmap("Graphics/Pictures/Controls help/help_actionkey")
    @sprites["actionbutton"].zoom_x = 0.5
    @sprites["actionbutton"].zoom_y = 0.5
    #---------------------------------------------------------------------------
    # Rank stars
    #---------------------------------------------------------------------------
    star_x = 10
    for i in 1..@rules[:rank]
      @sprites["raidstar#{i}"] = IconSprite.new(star_x, 64)
      @sprites["raidstar#{i}"].setBitmap(@path + "raid_star")
      star_x += 40
      break if i == 5
    end
    #---------------------------------------------------------------------------
    # Raid Pokemon silhouette
    #---------------------------------------------------------------------------
    @sprites["pokeicon"] = PokemonIconSprite.new(@pkmn, @viewport)
    @sprites["pokeicon"].x = 95
    @sprites["pokeicon"].y = 140
    @sprites["pokeicon"].color.alpha = 255
    if @pkmn.gmax? && @sprites["pokeicon"].bitmap.height > 64
      @sprites["pokeicon"].x -= 12
      @sprites["pokeicon"].y -= 12
    else
      @sprites["pokeicon"].zoom_x = 1.5
      @sprites["pokeicon"].zoom_y = 1.5
    end
    #---------------------------------------------------------------------------
    # Raid Pokemon type display
    #---------------------------------------------------------------------------
    typebitmap = AnimatedBitmap.new(_INTL("Graphics/Pictures/Pokedex/icon_types"))
    @pkmn.types.each_with_index do |type, i|
      type_number = GameData::Type.get(type).icon_position
      type_rect = Rect.new(0, type_number * 32, 96, 32)
      type_x = (i == 0) ? 10 : 110
      @overlay.blt(type_x, 106, typebitmap.bitmap, type_rect)
    end
    #---------------------------------------------------------------------------
    # Party icons
    #---------------------------------------------------------------------------
    party_x = 127 - (19 * @rules[:size])
    for i in 0...@rules[:size]
      @sprites["partybg#{i}"] = IconSprite.new(party_x + (37 * i), 252)
      @sprites["partybg#{i}"].setBitmap(@path + "raid_party_bg")
    end
    $player.able_party.each_with_index do |pkmn, i|
      @sprites["partyicon#{i}"] = PokemonIconSprite.new(pkmn, @viewport)
      @sprites["partyicon#{i}"].x = @sprites["partybg#{i}"].x + 2
      @sprites["partyicon#{i}"].y = 251
      @sprites["partyicon#{i}"].zoom_x  = 0.5
      @sprites["partyicon#{i}"].zoom_y  = 0.5
      break if i == @rules[:size] - 1
    end
    #---------------------------------------------------------------------------
    # Battlefield display
    #---------------------------------------------------------------------------
    conds = []
    field = raid_FieldHash
    conds.push(field[@rules[:weather]])
    conds.push(field[@rules[:terrain]])
    # Environment isn't displayed if all field settings are default settings.
    if @rules[:environ] == :Cave
      conds.push(field[@rules[:environ]]) if conds.compact.length > 0
    else
      conds.push(field[@rules[:environ]])
    end
    if conds.compact.length > 0
      @sprites["fieldbg"] = IconSprite.new(295, 16)
      @sprites["fieldbg"].setBitmap(@path + "raid_bg_header")
      @sprites["fieldbg"].mirror = true
      fieldbitmap = AnimatedBitmap.new(_INTL(@path + "raid_field"))
      offset = 0
      conds.each_with_index do |cond, i|
        next if !cond
        @overlay.blt(444 - (offset * 58), 38, fieldbitmap.bitmap, Rect.new(cond * 58, i * 32, 58, 32))
        offset += 1
      end
    end
    #---------------------------------------------------------------------------
    # Extra raid conditions
    #---------------------------------------------------------------------------
    extras = []
    # G-Max symbol if this is a G-Max Raid.
    if @pkmn.gmax?
      @sprites["gmax"] = IconSprite.new(0, 94)
      @sprites["gmax"].setBitmap("Graphics/Plugins/ZUD/UI/gfactor")
      extras.push(@sprites["gmax"])
    end
    # Hard Mode symbol if this is a Hard Mode Raid.
    if @rules[:hard]
      @sprites["hard"] = IconSprite.new(0 ,80)
      @sprites["hard"].setBitmap(@path + "raid_hard")
      extras.push(@sprites["hard"])
    end
    # Bonus Item symbol if this raid has custom loot.
    if @rules[:loot]
      @sprites["loot"] = IconSprite.new(0, 80)
      @sprites["loot"].setBitmap(@path + "raid_loot")
      extras.push(@sprites["loot"])
    end
    for i in 0...extras.length; extras[i].x = 460 - (i * 54); end
    #---------------------------------------------------------------------------
    # Text displays
    #---------------------------------------------------------------------------
    textPos = [
      [_INTL("MAX RAID DEN"), 25,  32, 0, BASE, SHADOW],
      [_INTL("Leave Den"),   403, 154, 0, BASE, SHADOW],
      [_INTL("Enter Den"),   403, 217, 0, BASE, SHADOW],
      [_INTL("Set Party"),   111, 295, 0, BASE, SHADOW]
    ]
    textPos.push([_INTL("FIELD"), 450, 19, 0, BASE, SHADOW]) if conds.compact.length > 0
    pbDrawTextPositions(@overlay, textPos)
    ko_text = (@rules[:kocount] == 1) ? "knock out" : "knock outs"
    battletext = _INTL("Battle ends in {1} turns, or after {2} {3}.", @rules[:turns], @rules[:kocount], ko_text)
    drawTextEx(@overlay, 287, 276, 220, 2, battletext, BASE, SHADOW)
    pbSEPlay("GUI trainer card open")
    pbMaxRaidEntry
  end

  #-----------------------------------------------------------------------------
  # Command options while the den entry screen is displayed.
  #-----------------------------------------------------------------------------
  def pbMaxRaidEntry
    outcome = false
    full_party = $player.party
    loop do
      Graphics.update
      Input.update
      pbUpdate
      #-------------------------------------------------------------------------
      # Accesses Party screen and updates party display.
      #-------------------------------------------------------------------------
      if Input.trigger?(Input::ACTION)
        pbPlayDecisionSE
        pbPokemonScreen
        full_party = $player.party
        $player.able_party.each_with_index do |pkmn, i|
          @sprites["partyicon#{i}"].pokemon = pkmn
          break if i == @rules[:size] - 1
        end
      #-------------------------------------------------------------------------
      # Sets up and begins the Raid battle.
      #-------------------------------------------------------------------------
      elsif Input.trigger?(Input::USE)
        if pbConfirmMessage(_INTL("Enter the raid den with the displayed party?"))
          raid_party = []
          $player.able_party.each_with_index do |pkmn, i|
            raid_party.push(pkmn)
            break if i == @rules[:size] - 1
          end
          $player.party = raid_party
          pbFadeOutIn {
            $stats.max_raid_dens_entered += 1
            pbSEPlay("Door enter")
            pbDisposeSpriteHash(@sprites)
            @viewport.dispose
            pbMessage(_INTL("\\me[Max Raid Intro]You ventured forth into the den...\\wt[34] ...\\wt[34] ...\\wt[60]!\\wtnp[8]")) #if !$DEBUG
            @pkmn.heal
            $PokemonGlobal.nextBattleBGM = @rules[:bgm]
            outcome = MaxRaidBattle.start_core(@pkmn)
            pbWait(20)
            pbSEPlay("Door exit")
          }
          $player.party = full_party
          @result = $game_variables[@rules[:outcome]]
          if @result == 1 || @result == 4
            $stats.max_raid_dens_cleared += 1
            $player.party.each { |pkmn| pkmn.heal }
            @interp.setVariable(0)
          end
          pbRaidRewardsScreen
          break
        end
      #-------------------------------------------------------------------------
      # Exits the Raid event.
      #-------------------------------------------------------------------------
      elsif Input.trigger?(Input::BACK)
        if pbConfirmMessage(_INTL("Would you like to leave the raid den?"))
          pbSEPlay("GUI menu close")
          break
        end
      end
    end
    return outcome
  end
  
  #-----------------------------------------------------------------------------
  # Initializes the Raid Rewards screen.
  #-----------------------------------------------------------------------------
  def pbRaidRewardsScreen
    @sprites    = {}
    @viewport   = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @sprites["rewardscreen"] = IconSprite.new(0, 0)
    @sprites["rewardscreen"].setBitmap(@path + "raid_bg_rewards")
    @sprites["backbutton"] = IconSprite.new(335, 292)
    @sprites["backbutton"].setBitmap("Graphics/Pictures/Controls help/help_backkey")
    @sprites["backbutton"].zoom_x = 0.5
    @sprites["backbutton"].zoom_y = 0.5
    @sprites["overlay"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    @overlay = @sprites["overlay"].bitmap
    pbSetSmallFont(@overlay)
    textPos = []
    #---------------------------------------------------------------------------
    # Rank stars
    #---------------------------------------------------------------------------
    star_x = 385 - 20 * (@rules[:rank] == 6 ? 5 : @rules[:rank]) 
    for i in 1..@rules[:rank]
      @sprites["raidstar#{i}"] = IconSprite.new(star_x, 64)
      @sprites["raidstar#{i}"].setBitmap(@path + "raid_star")
      star_x += 40
      break if i == 5
    end
    #---------------------------------------------------------------------------
    # Raid Pokemon sprite
    #---------------------------------------------------------------------------
    @sprites["pokemon"] = PokemonSprite.new(@viewport)
    @sprites["pokemon"].setOffset(PictureOrigin::CENTER)
    @sprites["pokemon"].x = 104
    @sprites["pokemon"].y = 206
    @sprites["pokemon"].setPokemonBitmap(@pkmn)
    @sprites["pokemon"].unDynamax
    if @pkmn.gmax_factor?
      @sprites["gmax"] = IconSprite.new(140, 82)
      @sprites["gmax"].setBitmap("Graphics/Plugins/ZUD/UI/gfactor")
    end
    #---------------------------------------------------------------------------
    # Rewards display
    #---------------------------------------------------------------------------
    if @result == 1 || @result == 4
      @bonuses = []
      @bonuses.push(0) if @rules[:hard]
      @bonuses.push(1) if @rules[:perfect_bonus]
      @bonuses.push(2) if @rules[:timer_bonus] > (@rules[:turns] / 2).floor
      @bonuses.push(3) if @rules[:fairness_bonus]
      @bonuses.push(4) if @result == 4
      if !@bonuses.empty?
        @sprites["bonusbg"] = IconSprite.new(0,16)
        @sprites["bonusbg"].setBitmap(@path + "raid_bg_header")
        textPos.push([_INTL("BONUS"), 8, 19, 0, BASE, SHADOW])
        bonusbitmap = AnimatedBitmap.new(_INTL(@path + "raid_bonus"))
        for i in 0...@bonuses.length
          @overlay.blt(i * 41, 38, bonusbitmap.bitmap, Rect.new(@bonuses[i] * 41, 0, 41, 33))
        end
      end
      rewards = raid_Rewards(@pkmn.species_data.id, @rules[:rank], @bonuses.length)
      if rand(10) < 1
        case @rules[:weather]
        when :Sun         then rewards.push([:HEATROCK,      1])
        when :Rain        then rewards.push([:DAMPROCK,      1])
        when :Sandstorm   then rewards.push([:SMOOTHROCK,    1])
        when :Hail        then rewards.push([:ICYROCK,       1])
        when :ShadowSky   then rewards.push([:LIFEORB,       1])
        when :Fog         then rewards.push([:SMOKEBALL,     1])
        end
      end
      if rand(10) < 1
        case @rules[:terrain]              
        when :Electric    then rewards.push([:ELECTRICSEED,  1])
        when :Grassy      then rewards.push([:GRASSYSEED,    1])
        when :Misty       then rewards.push([:MISTYSEED,     1])
        when :Psychic     then rewards.push([:PSYCHICSEED,   1])
        end
      end
      if rand(10) < 1
        case @rules[:environment]
        when :None        then rewards.push([:CELLBATTERY,   1])    
        when :Grass       then rewards.push([:MIRACLESEED,   1])
        when :TallGrass   then rewards.push([:ABSORBBULB,    1])
        when :MovingWater then rewards.push([:MYSTICWATER,   1])
        when :StillWater  then rewards.push([:FRESHWATER,    1])
        when :Puddle      then rewards.push([:LIGHTCLAY,     1])
        when :Underwater  then rewards.push([:SHOALSHELL,    1])    
        when :Cave        then rewards.push([:LUMINOUSMOSS,  1])
        when :Rock        then rewards.push([:HARDSTONE,     1])
        when :Sand        then rewards.push([:SOFTSAND,      1])
        when :Forest      then rewards.push([:SHEDSHELL,     1])
        when :ForestGrass then rewards.push([:SILVERPOWDER,  1])
        when :Snow        then rewards.push([:SNOWBALL,      1])
        when :Ice         then rewards.push([:NEVERMELTICE,  1])
        when :Volcano     then rewards.push([:CHARCOAL,      1])
        when :Graveyard   then rewards.push([:RAREBONE,      1])
        when :Sky         then rewards.push([:PRETTYFEATHER, 1])
        when :Space       then rewards.push([:STARDUST,      1])
        when :UltraSpace  then rewards.push([:COMETSHARD,    1])
        end
      end
      if @rules[:loot]
        if @rules[:loot].is_a?(Array)
          rewards.push([@rules[:loot][0], @rules[:loot][1] || 1]) 
        else 
          rewards.push([@rules[:loot], 1])
        end
      end
      items = []
      for i in 0...rewards.length
        item, qty = rewards[i][0], rewards[i][1]
        next if !GameData::Item.exists?(item)
        item     = GameData::Item.get(item)
        itemname = (item.is_TR?) ? _INTL("{1} {2}", item.name, GameData::Move.get(item.move).name) : item.name
        items.push(_INTL("{1}  x{2}", itemname, qty))
        $bag.add(item.id, qty)
      end
      @sprites["itemwindow"] = Window_CommandPokemon.newWithSize(items, 260, 92, 258, 196, @viewport)
      @sprites["itemwindow"].index = 0
      @sprites["itemwindow"].baseColor   = BASE
      @sprites["itemwindow"].shadowColor = SHADOW
      @sprites["itemwindow"].windowskin  = nil
    end
    #---------------------------------------------------------------------------
    # Other text displays
    #---------------------------------------------------------------------------
    level   = "???"
    ability = "???"
    case @result
    when 1
      result = "defeated"
    when 4
      result  = "caught"
      level   = @pkmn.level
      ability = GameData::Ability.get(@pkmn.ability).name
      if @pkmn.male?
        gendermark = "♂"
        textPos.push( [gendermark, 20, 87, 0, Color.new(24, 112, 216), Color.new(136, 168, 208)] )
      elsif @pkmn.female?
        gendermark = "♀"
        textPos.push( [gendermark, 20, 87, 0, Color.new(248, 56, 32), Color.new(224, 152, 144)] )
      end
    else
      result = "lost to"
      textPos.push( [_INTL("No Rewards Earned."), 386, 179, 2, BASE, SHADOW] )
    end
    result = _INTL("You {1} {2}!", result, @pkmn.name)
    textPos.push(
      [result, 270, 32, 0, BASE, SHADOW],
      [_INTL("Exit"), 393, 295, 0, BASE, SHADOW],
      [_INTL("Lvl. {1}", level), 38, 88, 0, BASE, SHADOW],
      [_INTL("Ability: {1}", ability), 20, 295, 0, BASE, SHADOW]
    )
    pbDrawTextPositions(@overlay, textPos)
    #---------------------------------------------------------------------------
    # Exits the screen
    #---------------------------------------------------------------------------
    loop do
      Graphics.update
      Input.update
      pbUpdate
      if Input.trigger?(Input::BACK)
        pbSEPlay("GUI menu close")
        Input.update
        break
      end
    end
  end
end


#===============================================================================
# Used to call a Max Raid Den in an event script.
#===============================================================================
def raid_InitiateRaidDen(pkmn)
  scene  = MaxRaidScene.new
  screen = MaxRaidScreen.new(scene)
  screen.pbStartScreen(pkmn)
end

class MaxRaidScreen
  def initialize(scene)
    @scene = scene
  end
  def pbStartScreen(pkmn)
    @scene.pbStartScene(pkmn)
    @scene.pbEndScene
  end
end