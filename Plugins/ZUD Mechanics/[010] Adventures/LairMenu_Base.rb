#===============================================================================
# Base setup for all Max Lair menus.
#===============================================================================
class MaxLairEventScene
  BASE   = Color.new(248, 248, 248)
  SHADOW = Color.new(0, 0, 0)
  
  #-----------------------------------------------------------------------------
  # Begins the screen.
  #-----------------------------------------------------------------------------
  def pbStartScene(show_party = true)
    @rentals     = []
    @rentalparty = []
    @textPos     = []
    @imagePos    = []
    @size        = 3
    @path        = "Graphics/Plugins/ZUD/Adventure/Menus/"
    @party_path  = "Graphics/Plugins/ZUD/Raid Den/raid_party_bg"
    @viewport    = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z  = 99999
    @sprites     = {}
    @sprites["background"] = IconSprite.new(0, 0, @viewport)
    @sprites["background"].setBitmap(@path + "menu_bg")
    @sprites["prizebg"]  = IconSprite.new(0, 0, @viewport)
    @sprites["prizebg"].setBitmap(@path + "menu")
    @sprites["prizebg"].src_rect.set(0, 0, 197, 384)
    @sprites["prizebg"].visible = false
    @sprites["menu"] = IconSprite.new(197, 0, @viewport)
    @sprites["menu"].setBitmap(@path + "menu")
    @sprites["menu"].src_rect.set(197, 0, 315, 384)
    @sprites["menu"].visible = false
    @xpos = Graphics.width - 330
    @ypos = 39
    3.times do |i|
      @sprites["pokeslot#{i}"] = IconSprite.new(@xpos, @ypos + (i * 114), @viewport)
      @sprites["pokeslot#{i}"].setBitmap(@path + "menu_slot")
      @sprites["pokeslot#{i}"].src_rect.set(0, 110, 330, 115)
      @sprites["pokeslot#{i}"].visible = false
    end
    @sprites["slotsel"] = IconSprite.new(@xpos, @ypos, @viewport)
    @sprites["slotsel"].setBitmap(@path + "menu_slot")
    @sprites["slotsel"].src_rect.set(0, 0, 166, 108)
    @sprites["slotsel"].visible = false
    @sprites["rightarrow"] = AnimatedSprite.new("Graphics/Pictures/rightarrow", 8, 40, 28, 2, @viewport)
    @sprites["rightarrow"].x = @xpos - 30
    @sprites["rightarrow"].play
    @sprites["rightarrow"].visible = false
    @sprites["leftarrow"] = AnimatedSprite.new("Graphics/Pictures/leftarrow", 8, 40, 28, 2, @viewport)
    @sprites["leftarrow"].x = @xpos - 42
    @sprites["leftarrow"].play
    @sprites["leftarrow"].visible = false
    @sprites["actionbutton"] = IconSprite.new(6, 350, @viewport)
    @sprites["actionbutton"].setBitmap("Graphics/Pictures/Controls help/help_actionkey")
    @sprites["actionbutton"].zoom_x = 0.5
    @sprites["actionbutton"].zoom_y = 0.5
    @sprites["actionbutton"].visible = false
    6.times do |i|
      @sprites["partybg#{i}"] = IconSprite.new(4, 90 + (i * 40), @viewport)
      @sprites["partybg#{i}"].setBitmap(@party_path)
      @sprites["partybg#{i}"].visible = show_party && i < @size
      @sprites["partyname#{i}"] = IconSprite.new(40, 99 + (i * 40), @viewport)
      @sprites["partyname#{i}"].setBitmap(@path + "menu_slot")
      @sprites["partyname#{i}"].src_rect.set(166, 20, 150, 20)
      @sprites["partyname#{i}"].visible = show_party && i < @size
    end
    @sprites["menudisplay"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    @sprites["menudisplay"].z += 1
    @menudisplay = @sprites["menudisplay"].bitmap
    @sprites["changesprites"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    @sprites["changesprites"].z += 1
    @changesprites = @sprites["changesprites"].bitmap
    @sprites["statictext"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    @sprites["statictext"].z += 1
    @statictext = @sprites["statictext"].bitmap
    pbSetSmallFont(@statictext)
    @sprites["changetext"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    @sprites["changetext"].z += 1
    @changetext = @sprites["changetext"].bitmap
    pbSetSmallFont(@changetext)
    drawTextEx(@statictext, 4, 6, 164, 0, _INTL("DYNAMAX ADVENTURE"), BASE, SHADOW)
    @typebitmap     = AnimatedBitmap.new("Graphics/Pictures/types")
    @categorybitmap = AnimatedBitmap.new("Graphics/Pictures/category")
    @statbitmap     = AnimatedBitmap.new(@path + "stat_icons")
    @sprites["messagebox"] = Window_AdvancedTextPokemon.new("")
    @sprites["messagebox"].viewport       = @viewport
    @sprites["messagebox"].visible        = false
    @sprites["messagebox"].letterbyletter = true
    pbBottomLeftLines(@sprites["messagebox"], 2)
    pbSEPlay("GUI trainer card open")
  end
  
  #-----------------------------------------------------------------------------
  # Draws the Summary screen for inputted Pokemon.
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
  # Draws the type icons for Pokemon and Moves.
  #-----------------------------------------------------------------------------
  def pbDrawTypeIcons(poke, sprite)
    ypos = sprite.y + 2
    poke.types.each_with_index do |type, i|
      type_number = GameData::Type.get(type).icon_position
      type_rect = Rect.new(0, type_number * 28, 64, 28)
      type_y = (i == 1) ? ypos + 32 : ypos
      @changesprites.blt(@xpos + 86, type_y, @typebitmap.bitmap, type_rect)
    end
  end
  
  #-----------------------------------------------------------------------------
  # Draws the icons used to display a Pokemon's stat training.
  #-----------------------------------------------------------------------------
  def pbDrawStatIcons(poke, sprite, rental = false)
    stat = 0
    xpos = (rental) ? Graphics.width - 34 : sprite.x + 55
    ypos = (rental) ? sprite.y - 2 : sprite.y + 5
    GameData::Stat.each_main do |s|
      next if s.id == :HP || poke.ev[s.id] < 252
      stat = s.pbs_order
      break
    end
    @changesprites.blt(xpos, ypos, @statbitmap.bitmap, Rect.new(stat * 32, 0, 32, 32))
  end
  
  #-----------------------------------------------------------------------------
  # Draws an array of Pokemon to display, usually the player's current party.
  #-----------------------------------------------------------------------------
  def pbDrawParty(party, showname = true)
    party.each_with_index do |pkmn, i|
      @sprites["partysprite#{i}"] = PokemonIconSprite.new(pkmn, @viewport)
      spritex = @sprites["partysprite#{i}"].x = @sprites["partybg#{i}"].x + 2
      spritey = @sprites["partysprite#{i}"].y = @sprites["partybg#{i}"].y - 2
      @sprites["partysprite#{i}"].zoom_x = 0.5
      @sprites["partysprite#{i}"].zoom_y = 0.5
      if showname
        @textPos.push([_INTL("{1}", pkmn.name), spritex + 40, spritey + 13, 0, BASE, SHADOW])
        pbDrawTextPositions(@changetext, @textPos)
      end
    end
  end
  
  #-----------------------------------------------------------------------------
  # Draws all core info for a Pokemon rental screen.
  #-----------------------------------------------------------------------------
  def pbDrawRentalScreen
    pbDrawParty(@rentalparty)
    remainder = @size - @rentalparty.length
    if remainder > 0
      @textPos.push([_INTL("Select {1} more rental Pokémon.", remainder), 230, 5, 0, BASE, SHADOW])
      @size.times do |i|
        @rentals.push(pbDynamaxAdventure.generate_rental)
        @sprites["pokeslot#{i}"].visible = true
        @sprites["gmaxsprite#{i}"] = IconSprite.new(0, 0, @viewport)
        @sprites["gmaxsprite#{i}"].setBitmap("Graphics/Plugins/ZUD/UI/gfactor")
        @sprites["pkmnsprite#{i}"] = PokemonIconSprite.new(@rentals[i], @viewport)
        spritex = @sprites["pkmnsprite#{i}"].x = @xpos + 12
        spritey = @sprites["pkmnsprite#{i}"].y = @ypos + (i * 114)
        @sprites["gmaxsprite#{i}"].x = spritex - 4
        @sprites["gmaxsprite#{i}"].y = spritey + 4
        @sprites["gmaxsprite#{i}"].visible = @rentals[i].gmax_factor?
        @sprites["helditem#{i}"] = HeldItemIconSprite.new(spritex - 8, spritey + 40, @rentals[i], @viewport)
        offset = (@rentals[i].genderless?) ? -4 : 12
        name   = @rentals[i].name
        abil   = GameData::Ability.get(@rentals[i].ability).name
        mark, base, shadow = "♂", Color.new(24, 112, 216), Color.new(136, 168, 208) if @rentals[i].male?
        mark, base, shadow = "♀", Color.new(248, 56, 32),  Color.new(224, 152, 144) if @rentals[i].female?
        @textPos.push([mark, spritex - 4, spritey + 67, 0, base, shadow]) if !@rentals[i].genderless?
        @textPos.push([_INTL("{1}", name), spritex + offset, spritey + 68, 0, BASE, SHADOW])
        @textPos.push([_INTL("{1}", abil), spritex - 4, spritey + 88, 0, BASE, SHADOW])
        @rentals[i].moves.each_with_index do |m, i|
          xpos = spritex + 160
          ypos = (spritey + 22) + (i * 22)
          move = GameData::Move.get(m.id).name
          @textPos.push([_INTL("{1}", move), xpos, ypos, 0, SHADOW, BASE])
        end
        pbDrawStatIcons(@rentals[i], @sprites["pokeslot#{i}"], true)
        pbDrawTypeIcons(@rentals[i], @sprites["pkmnsprite#{i}"])
      end
    end
    pbDrawTextPositions(@changetext, @textPos)
  end
  
  #-----------------------------------------------------------------------------
  # Draws all core info for a Pokemon exchange screen.
  #-----------------------------------------------------------------------------
  def pbDrawSwapScreen(pokemon = nil)
    pbDrawParty($player.party)
    if pokemon
      slot = 1
      @sprites["pokeslot#{slot}"].visible = true
      @sprites["gmaxsprite"] = IconSprite.new(0, 0, @viewport)
      @sprites["gmaxsprite"].setBitmap("Graphics/Plugins/ZUD/UI/gfactor")
      @sprites["pkmnsprite"] = PokemonIconSprite.new(pokemon, @viewport)
      spritex = @sprites["pkmnsprite"].x = @xpos + 12
      spritey = @sprites["pkmnsprite"].y = @ypos + (slot * 114)
      @sprites["slotsel"].y  = @sprites["pokeslot#{slot}"].y
      @sprites["gmaxsprite"].x = spritex - 4
      @sprites["gmaxsprite"].y = spritey + 4
      @sprites["gmaxsprite"].visible = pokemon.gmax_factor?
      @sprites["helditem"] = HeldItemIconSprite.new(spritex - 8, spritey + 40, pokemon, @viewport)
      newtag = [ [@path + "menu_slot", @xpos + 10, spritey - 15, 166, 0, 60, 20] ]
      pbDrawImagePositions(@changesprites, newtag)
      name   = pokemon.name
      abil   = GameData::Ability.get(pokemon.ability).name
      offset = (pokemon.genderless?) ? -4 : 12
      mark, base, shadow = "♂", Color.new(24, 112, 216), Color.new(136, 168, 208) if pokemon.male?
      mark, base, shadow = "♀", Color.new(248, 56, 32),  Color.new(224, 152, 144) if pokemon.female?
      @textPos.push([mark, spritex - 4, spritey + 67, 0, base, shadow]) if !pokemon.genderless?
      @textPos.push([_INTL("{1}", name), spritex + offset, spritey + 68, 0, BASE, SHADOW])
      @textPos.push([_INTL("{1}", abil), spritex - 4, spritey + 88, 0, BASE, SHADOW])
      pokemon.moves.each_with_index do |m, i|
        xpos = spritex + 160
        ypos = (spritey + 22) + (i * 22)
        move = GameData::Move.get(m.id).name
        @textPos.push([_INTL("{1}", move), xpos, ypos, 0, SHADOW, BASE])
      end
      pbDrawStatIcons(pokemon, @sprites["pokeslot#{slot}"], true)
      pbDrawTypeIcons(pokemon, @sprites["pkmnsprite"])
      @sprites["actionbutton"].visible = true
      @textPos.push([_INTL("Summary"), 62, 353, 0, BASE, SHADOW])
    end
    pbDrawTextPositions(@changetext, @textPos)
  end
  
  #-----------------------------------------------------------------------------
  # Draws all core info for a Pokemon held item equip screen.
  #-----------------------------------------------------------------------------
  def pbDrawItemScreen(items)
    items.length.times do |i|
      spritex = @xpos + 80
      spritey = 56 + (i * 40)
      @sprites["itembg#{i}"] = IconSprite.new(spritex, spritey, @viewport)
      @sprites["itembg#{i}"].setBitmap(@party_path)
      @sprites["itemname#{i}"] = IconSprite.new(spritex + 36, spritey + 9, @viewport)
      @sprites["itemname#{i}"].setBitmap(@path + "menu_slot")
      @sprites["itemname#{i}"].src_rect.set(166, 20, 150, 20)
      @sprites["itemsprite#{i}"] = ItemIconSprite.new(spritex + 19, spritey + 18, items[i], @viewport)
      @sprites["itemsprite#{i}"].zoom_x = 0.5
      @sprites["itemsprite#{i}"].zoom_y = 0.5
      @textPos.push([_INTL("{1}", GameData::Item.get(items[i]).name), spritex + 40, spritey + 11, 0, BASE, SHADOW])
    end
    pbDrawTextPositions(@changetext, @textPos)
  end
  
  #-----------------------------------------------------------------------------
  # Draws all core info for a Pokemon EV training screen.
  #-----------------------------------------------------------------------------
  def pbDrawStatScreen(stats)
    $player.party.each_with_index do |pkmn, i|
      pbDrawStatIcons(pkmn, @sprites["partysprite#{i}"])
    end
    stats.each_with_index do |stat, i|
      icon    = i - 1
      spritex = @xpos + 80
      spritey = 56 + (i * 40)
      @sprites["statbg#{i}"] = IconSprite.new(spritex, spritey, @viewport)
      @sprites["statbg#{i}"].setBitmap(@party_path)
      @sprites["statname#{i}"] = IconSprite.new(spritex + 36, spritey + 9, @viewport)
      @sprites["statname#{i}"].setBitmap(@path + "menu_slot")
      @sprites["statname#{i}"].src_rect.set(166, 20, 150, 20)
      @menudisplay.blt(spritex + 2, spritey + 3, @statbitmap.bitmap, Rect.new(stat[1] * 32, 0, 32, 32))
      @textPos.push([_INTL("{1} Training", stat[0]), spritex + 40, spritey + 11, 0, BASE, SHADOW])
    end
    pbDrawTextPositions(@changetext, @textPos)
  end
  
  #-----------------------------------------------------------------------------
  # Draws all core info for a Pokemon move tutor screen.
  #-----------------------------------------------------------------------------
  def pbDrawTutorScreen(moves_to_learn, pokemon, newmove)
    slot = 1
    textPos = []
    spritex = @xpos + 12
    spritey = @ypos + (slot * 114)
    @menudisplay.clear
    @changesprites.clear
    textPos.push([_INTL("Select {1} more move(s) to tutor.", moves_to_learn), 230, 5, 0, BASE, SHADOW])
    if newmove
      @sprites["slotsel"].y = @sprites["pokeslot#{slot}"].y
      @sprites["slotsel"].visible = true
      newtag = [ [@path + "menu_slot", @xpos + 10, spritey - 15, 166, 0, 60, 20] ]
      pbDrawImagePositions(@changesprites, newtag)
      m = GameData::Move.get(newmove)
      damage   = (m.base_damage > 0) ? m.base_damage : "---"
      accuracy = (m.accuracy > 0) ? m.accuracy : "---"
      typerect = Rect.new(0, GameData::Type.get(m.type).icon_position * 28, 64, 28)
      catrect  = Rect.new(0, m.category * 28, 64, 28)
      @changesprites.blt(spritex - 4, spritey + 42, @typebitmap.bitmap, typerect)
      @changesprites.blt(spritex - 4, spritey + 74, @categorybitmap.bitmap, catrect)
      textPos.push([_INTL("{1}", m.name), spritex - 4, spritey + 18, 0, BASE, SHADOW])
      textPos.push([_INTL("BP: {1}", damage), spritex + 72, spritey + 46, 0, BASE, SHADOW])
      textPos.push([_INTL("AC: {1}", accuracy), spritex + 72, spritey + 66, 0, BASE, SHADOW])
      textPos.push([_INTL("PP: {1}", m.total_pp), spritex + 72, spritey + 86, 0, BASE, SHADOW])
      pbDrawStatIcons(pokemon, @sprites["pokeslot#{slot}"], true)
      pokemon.moves.each_with_index do |m, i|
        xpos = spritex + 160
        ypos = (spritey + 22) + (i * 22)
        move = GameData::Move.get(m.id).name
        textPos.push([_INTL("{1}", move), xpos, ypos, 0, SHADOW, BASE])
      end
    else
      @sprites["slotsel"].visible = false
      textPos.push([_INTL("No moves to learn."), spritex + 80, spritey + 50, 0, SHADOW, BASE])
    end
    pbSetSmallFont(@menudisplay)
    pbDrawTextPositions(@menudisplay, textPos)
  end
  
  #-----------------------------------------------------------------------------
  # Used to generate an appropriate tutor move for a Pokemon.
  #-----------------------------------------------------------------------------
  def pbGenerateTutorMove(pkmn, oldmove = nil)
    pokemoves  = []
    tutormoves = []
    pkmn.moves.each { |move| pokemoves.push(move.id) }
    movelist = raid_GenerateMovelists(pkmn.species_data.id, true)
    movelist.flatten!.compact!
    movelist.each do |m|
      next if m == oldmove
      next if pokemoves.include?(m)
      case GameData::Move.get(m).category
      when 0 # Physical
        next if pkmn.ev[:SPECIAL_ATTACK] == 252
      when 1 # Special
        next if pkmn.ev[:ATTACK] == 252
      end
      tutormoves.push(m)
    end
    return (tutormoves.empty?) ? oldmove : tutormoves.sample
  end
  
  #-----------------------------------------------------------------------------
  # Scene utilities.
  #-----------------------------------------------------------------------------
  def pbShowCommands(commands, index = 0)
    ret = -1
    using(cmdwindow = Window_CommandPokemon.new(commands)) {
     cmdwindow.z = @viewport.z + 1
     cmdwindow.index = index
     pbBottomRight(cmdwindow)
     loop do
       Graphics.update
       Input.update
       cmdwindow.update
       pbUpdate
       if Input.trigger?(Input::BACK)
         pbPlayCancelSE
         ret = -1
         break
       elsif Input.trigger?(Input::USE)
         pbPlayDecisionSE
         ret = cmdwindow.index
         break
       end
     end
    }
    return ret
  end
  
  def pbClearAll
    @rentals.clear
    @textPos.clear
    @imagePos.clear
    @changetext.clear
    @changesprites.clear
  end
  
  def pbUpdate
    for i in @sprites
      sprite = i[1]
      if sprite
        sprite.update if !pbDisposed?(sprite)
      end
    end
  end
  
  def pbEndScene
    pbFadeOutAndHide(@sprites) { pbUpdate }
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
  end
end