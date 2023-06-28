#===============================================================================
# Max Lair Menus.
#===============================================================================
class MaxLairEventScene
  
  #=============================================================================
  # Rental screen.
  #=============================================================================
  def pbRentalSelect
    pbDrawRentalScreen
    index    = -1
    maxindex = @rentals.length - 1
    drawTextEx(@statictext, 4, 52, 164, 0, _INTL("Rental Party:"), BASE, SHADOW)
    loop do
      Graphics.update
      Input.update
      pbUpdate
      if @rentalparty.length > 0
        @sprites["actionbutton"].visible = true
        drawTextEx(@statictext, 62, 353, 120, 0, _INTL("Summary"), BASE, SHADOW)
      end
      #-------------------------------------------------------------------------
      # Scrolls up/down through rental options.
      #-------------------------------------------------------------------------
      if Input.trigger?(Input::DOWN)
        pbPlayCursorSE
        index += 1
        index  = 0 if index > maxindex
        @sprites["slotsel"].y  = @sprites["pokeslot#{index}"].y
        @sprites["rightarrow"].y = 80 + (index * 114)
        @sprites["slotsel"].visible = true
        @sprites["rightarrow"].visible = true
      elsif Input.trigger?(Input::UP)
        pbPlayCursorSE
        index -= 1
        index  = maxindex if index < 0
        @sprites["slotsel"].y  = @sprites["pokeslot#{index}"].y
        @sprites["rightarrow"].y = 80 + (index * 114)
        @sprites["slotsel"].visible = true
        @sprites["rightarrow"].visible = true
      #-------------------------------------------------------------------------
      # View the Summary of the current rental party.
      #-------------------------------------------------------------------------
      elsif Input.trigger?(Input::ACTION) && @rentalparty.length > 0
        pbPlayDecisionSE
        pbSummary(@rentalparty, 0, @sprites)
      #-------------------------------------------------------------------------
      # Select a rental Pokemon.
      #-------------------------------------------------------------------------
      elsif Input.trigger?(Input::USE) && index > -1
        pbPlayDecisionSE
        cmd = pbShowCommands([_INTL("Select"), 
                              _INTL("Summary"), 
                              _INTL("Back")], 0)
        case cmd
        #-----------------------------------------------------------------------
        # Adds the selected rental Pokemon to your rental team.
        #-----------------------------------------------------------------------
        when 0
          poke = @rentals[index]
          if pbConfirmMessage(_INTL("Add {1} to your rental team?", poke.name))
            poke.play_cry
            @rentalparty.push(poke)
            pbWait(25)
            index = -1
            for i in 0...@rentals.length
              @sprites["pkmnsprite#{i}"].dispose
              @sprites["gmaxsprite#{i}"].dispose
              @sprites["helditem#{i}"].dispose
            end
            pbClearAll
            @sprites["slotsel"].visible    = false
            @sprites["rightarrow"].visible = false
            pbDrawRentalScreen
            if @rentalparty.length >= @size
              pbWait(20)
              $player.party = @rentalparty
              break
            end
          end
        #-----------------------------------------------------------------------
        # View the Summary of the selected rental Pokemon.
        #-----------------------------------------------------------------------
        when 1
          pbSummary(@rentals, index, @sprites)
        end
      #-------------------------------------------------------------------------
      # Ends the Adventure.
      #-------------------------------------------------------------------------
      elsif Input.trigger?(Input::BACK)
        if pbConfirmMessage(_INTL("End the Dynamax Adventure?"))
          break
        end
      end
    end
    pbPlayCloseMenuSE
    pbEndScene
  end
  
  
  #=============================================================================
  # Exchange screen.
  #=============================================================================
  def pbSwapSelect
    pokemon = pbDynamaxAdventure.new_rental || pbDynamaxAdventure.generate_rental
    pbDrawSwapScreen(pokemon)
    @sprites["slotsel"].visible = true
    drawTextEx(@statictext, 4, 52, 164, 0, _INTL("Current Party:"), BASE, SHADOW)
    drawTextEx(@statictext, 220, 6, 400, 0, _INTL("Select a party member to swap."), BASE, SHADOW)
    if pbConfirmMessage(_INTL("Would you like to swap Pokémon?"))
      pbMessage(_INTL("Select a party member to exchange."))
      index    = 0
      maxindex = $player.party.length - 1
      @sprites["leftarrow"].y = 95
      @sprites["leftarrow"].visible = true
      loop do
        Graphics.update
        Input.update
        pbUpdate
        #-----------------------------------------------------------------------
        # Scrolls up/down through your rental party.
        #-----------------------------------------------------------------------
        if Input.trigger?(Input::DOWN)
          pbPlayCursorSE
          index += 1
          index  = 0 if index > maxindex
          @sprites["leftarrow"].y = 95 + (index * 40)
        elsif Input.trigger?(Input::UP)
          pbPlayCursorSE
          index -= 1
          index  = maxindex if index < 0
          @sprites["leftarrow"].y = 95 + (index * 40)
        #-----------------------------------------------------------------------
        # View the Summary of the rental Pokemon.
        #-----------------------------------------------------------------------
        elsif Input.trigger?(Input::ACTION)
          pbPlayDecisionSE
          pbSummary([pokemon], 0, @sprites)
        #-----------------------------------------------------------------------
        # Select a party member.
        #-----------------------------------------------------------------------
        elsif Input.trigger?(Input::USE)
          pbPlayDecisionSE
          cmd = pbShowCommands([_INTL("Select"), 
                                _INTL("Summary"), 
                                _INTL("Back")], 0)
          #---------------------------------------------------------------------
          # Exchanges the selected party member for the caught Pokemon.
          #---------------------------------------------------------------------
          case cmd
          when 0
            oldpoke = $player.party[index]
            olditem = $player.party[index].item
            if pbConfirmMessage(_INTL("Exchange {1} for the new Pokémon?", oldpoke.name))
              pokemon.play_cry
              pbWait(25)
              @sprites["partysprite#{index}"].dispose
              @sprites["pkmnsprite"].dispose
              @sprites["gmaxsprite"].dispose
              @sprites["helditem"].dispose
              @sprites["slotsel"].visible = false
              @sprites["leftarrow"].visible = false
              $player.party[index] = pokemon
              $player.party[index].item = olditem
              pbClearAll
              pbDrawSwapScreen
              pbMessage(_INTL("\\se[]{1} was added to the party!\\se[Pkmn move learnt]", pokemon.name))
              pbMessage(_INTL("{1}'s {2} was given to {3}.", oldpoke.name, GameData::Item.get(olditem).portion_name, pokemon.name)) if !olditem.nil?
              break
            end
          #---------------------------------------------------------------------
          # View the Summary of the selected party member.
          #---------------------------------------------------------------------
          when 1
            pbSummary($player.party, index, @sprites)
          end
        #-----------------------------------------------------------------------
        # Exits without swapping.
        #-----------------------------------------------------------------------
        elsif Input.trigger?(Input::BACK)
          if pbConfirmMessage(_INTL("Move on without swapping?"))
            break
          end
        end
      end
    end
    pbDynamaxAdventure.new_rental = nil
    pbPlayCloseMenuSE
    pbEndScene
  end
  
  
  #=============================================================================
  # Equip screen.
  #=============================================================================
  def pbItemSelect
    items    = []
    #---------------------------------------------------------------------------
    # General item pool.
    #---------------------------------------------------------------------------
    itempool = [:ABILITYSHIELD,   :AIRBALLOON,     :ASSAULTVEST, :BRIGHTPOWDER,
                :CHOICESCARF,     :CLEARAMULET,    :COVERTCLOAK, :EXPERTBELT,  
                :FOCUSBAND,       :FOCUSSASH,      :LEFTOVERS,   :LIFEORB,     
                :LIGHTCLAY,       :MIRRORHERB,     :POWERHERB,   :PROTECTIVEPADS,
                :PUNCHINGGLOVE,   :QUICKCLAW,      :RAZORCLAW,   :ROCKYHELMET,
                :SAFETYGOGGLES,   :SCOPELENS,      :SHELLBELL,   :STICKYBARB,
                :UTILITYUMBRELLA, :WEAKNESSPOLICY, :WHITEHERB,   :WIDELENS,
                :ZOOMLENS,        :SITRUSBERRY,    :LUMBERRY,    :LEPPABERRY,     
                :ELECTRICSEED,    :GRASSYSEED,     :MISTYSEED,   :PSYCHICSEED]
    #---------------------------------------------------------------------------
    # Adds type-specific items to item pool based on the party's types.
    #---------------------------------------------------------------------------
    GameData::Type.each do |type|
      next if !$player.has_pokemon_of_type?(type.id)
      case type.id
      when :NORMAL   then itempool.push(:NORMALGEM, :SILKSCARF)
      when :FIGHTING then itempool.push(:BLACKBELT)
      when :FLYING   then itempool.push(:SHARPBEAK)
      when :POISON   then itempool.push(:POISONBARB, :BLACKSLUDGE)
      when :BUG      then itempool.push(:SILVERPOWDER)
      when :GROUND   then itempool.push(:SOFTSAND)
      when :ROCK     then itempool.push(:HARDROCK)
      when :GHOST    then itempool.push(:SPELLTAG)
      when :STEEL    then itempool.push(:METALCOAT)
      when :FIRE     then itempool.push(:CHARCOAL)
      when :WATER    then itempool.push(:MYSTICWATER)
      when :GRASS    then itempool.push(:MIRACLESEED)
      when :ELECTRIC then itempool.push(:MAGNET)
      when :PSYCHIC  then itempool.push(:TWISTEDSPOON)
      when :ICE      then itempool.push(:NEVERMELTICE)
      when :DRAGON   then itempool.push(:DRAGONFANG)
      when :DARK     then itempool.push(:BLACKGLASSES)
      when :FAIRY    then itempool.push(:PIXIEPLATE)
      end
    end
    #---------------------------------------------------------------------------
    # Allows for certain items to appear depending on the party.
    #---------------------------------------------------------------------------
    items.push(:LIGHTBALL) if $player.has_species?(:PIKACHU) && GameData::Item.exists?(:LIGHTBALL)
    items.push(:THICKCLUB) if $player.has_species?(:MAROWAK) && GameData::Item.exists?(:THICKCLUB)
    items.push(:LEEK)      if ($player.has_species?(:FARFETCHD) || $player.has_species?(:SIRFETCHD)) && GameData::Item.exists?(:LEEK)
    items.push(:EVIOLITE)  if $player.party.any? { |p| p&.species_data.get_evolutions(true).length > 0 }
    itempool.push(:CHOICEBAND, :MUSCLEBAND)   if $player.party.any? { |p| p&.ev[:ATTACK] > 0 }
    itempool.push(:CHOICESPECS, :WISEGLASSES) if $player.party.any? { |p| p&.ev[:SPECIAL_ATTACK] > 0 }
    #---------------------------------------------------------------------------
    loop do
      break if itempool.empty?
      randitem = itempool.sample
      itempool.delete(randitem)
      next if !GameData::Item.exists?(randitem) || items.include?(randitem)
      items.push(randitem)
      break if items.length >= 6
    end
    items.shuffle!
    pbDrawItemScreen(items)
    ended = false
    @sprites["menu"].visible = true
    @sprites["actionbutton"].visible = true
    drawTextEx(@statictext, 4, 52, 164, 0, _INTL("Current Party:"), BASE, SHADOW)
    drawTextEx(@statictext, 62, 353, 120, 0, _INTL("Summary"), BASE, SHADOW)
    pbDrawParty($player.party, false)
    $player.party.each_with_index do |pkmn, i|
      spritex = @sprites["partysprite#{i}"].x
      spritey = @sprites["partysprite#{i}"].y
      @sprites["partyitem#{i}"] = ItemIconSprite.new(spritex + 73, spritey + 20, pkmn.item, @viewport)
      @sprites["partyitem#{i}"].zoom_x  = 0.5
      @sprites["partyitem#{i}"].zoom_y  = 0.5
      @sprites["partyitem#{i}"].visible = false if !pkmn.item
    end
    if pbConfirmMessage(_INTL("Would you like to give items to your Pokémon?"))
      $player.party.each_with_index do |pkmn, i|
        index    = 0
        maxindex = items.length - 1
        pbMessage(_INTL("Select an item to give to {1}.", pkmn.name))
        if pkmn.item
          olditem = GameData::Item.get(pkmn.item).portion_name
          text = (olditem.starts_with_vowel?) ? "an" : "a"
          text = _INTL("{1} is already holding {2} {3}.", pkmn.name, text, olditem)
          next if !pbConfirmMessage(_INTL("{1}\nReplace this item?", text))
        end
        @textPos.push([_INTL("Select {1}'s item.", pkmn.name), 250, 5, 0, BASE, SHADOW])
        @textPos.push([_INTL("{1}", pkmn.name), 46, (95 + (i * 40)) + 5, 0, BASE, SHADOW])
        pbDrawTextPositions(@changetext, @textPos)
        @sprites["rightarrow"].x = @xpos + 44
        @sprites["rightarrow"].y = @sprites["itembg#{index}"].y + 5
        @sprites["rightarrow"].visible    = true
        @sprites["partyitem#{i}"].visible = false
        loop do
          Graphics.update
          Input.update
          pbUpdate
          #---------------------------------------------------------------------
          # Scrolls up/down through the item options.
          #---------------------------------------------------------------------
          if Input.trigger?(Input::DOWN)
            pbPlayCursorSE
            index += 1
            index  = 0 if index > maxindex
            @sprites["rightarrow"].y = @sprites["itembg#{index}"].y + 5
          elsif Input.trigger?(Input::UP)
            pbPlayCursorSE
            index -= 1
            index  = maxindex if index < 0
            @sprites["rightarrow"].y = @sprites["itembg#{index}"].y + 5
          #---------------------------------------------------------------------
          # View the Summary of the party.
          #---------------------------------------------------------------------
          elsif Input.trigger?(Input::ACTION)
            pbPlayDecisionSE
            pbSummary($player.party, i, @sprites)
          #---------------------------------------------------------------------
          # Select an item.
          #---------------------------------------------------------------------
          elsif Input.trigger?(Input::USE)
            pbPlayDecisionSE
            cmd = pbShowCommands([_INTL("Give"), 
                                  _INTL("Details"), 
                                  _INTL("Next"), 
                                  _INTL("Exit")], 0)
            itemname = GameData::Item.get(items[index]).name
            itemportion = GameData::Item.get(items[index]).portion_name
            case cmd
            #-------------------------------------------------------------------
            # Equips the selected hold item.
            #-------------------------------------------------------------------
            when 0
              if pkmn.hasItem?(items[index])
                pbMessage(_INTL("{1}", text))
              else
                if pbConfirmMessage(_INTL("Give the {1} to {2}?", itemportion, pkmn.name))
                  pkmn.play_cry
                  pbWait(25)
                  pbMessage(_INTL("{1} was given the {2}.", pkmn.name, itemportion))
                  @sprites["partyitem#{i}"].item    = items[index]
                  @sprites["partyitem#{i}"].visible = true
                  @sprites["rightarrow"].visible    = false
                  pkmn.item = items[index]
                  items.length.times do |item|
                    @sprites["itembg#{item}"].dispose
                    @sprites["itemname#{item}"].dispose
                    @sprites["itemsprite#{item}"].dispose
                  end
                  items.delete_at(index)
                  pbClearAll
                  pbDrawItemScreen(items)
                  break
                end
              end
            #-------------------------------------------------------------------
            # Checks the decription of the selected item.
            #-------------------------------------------------------------------
            when 1
              pbMessage(_INTL("{1}:\n{2}", itemname, GameData::Item.get(items[index]).held_description))
            #-------------------------------------------------------------------
            # Skips to the next Pokemon.
            #-------------------------------------------------------------------
            when 2
              if pbConfirmMessage(_INTL("Skip {1} without giving it an item?", pkmn.name))
                @sprites["partyitem#{i}"].visible = true if pkmn.item
                @sprites["rightarrow"].visible = false
                items.length.times do |item|
                  @sprites["itembg#{item}"].dispose
                  @sprites["itemname#{item}"].dispose
                  @sprites["itemsprite#{item}"].dispose
                end
                pbClearAll
                pbDrawItemScreen(items)
                break
              end
            #-------------------------------------------------------------------
            # Exits item selection.
            #-------------------------------------------------------------------
            when 3
              if pbConfirmMessage(_INTL("Move on without equipping any more items?"))
                ended = true
                break
              end
            end
          #---------------------------------------------------------------------
          # Exits item selection.
          #---------------------------------------------------------------------
          elsif Input.trigger?(Input::BACK)
            if pbConfirmMessage(_INTL("Move on without equipping any more items?"))
              ended = true
              break
            end
          end
        end
        break if ended
      end
    end
    pbPlayCloseMenuSE
    pbEndScene
  end

  
  #=============================================================================
  # Training screen.
  #=============================================================================
  def pbTrainingSelect
    stats = [
      [_INTL("Attack"),   GameData::Stat.get(:ATTACK).pbs_order],
      [_INTL("Defense"),  GameData::Stat.get(:DEFENSE).pbs_order],
      [_INTL("Sp. Atk"),  GameData::Stat.get(:SPECIAL_ATTACK).pbs_order],
      [_INTL("Sp. Def"),  GameData::Stat.get(:SPECIAL_DEFENSE).pbs_order],
      [_INTL("Speed"),    GameData::Stat.get(:SPEED).pbs_order],
      [_INTL("Balanced"), 0]
    ]
    ended = false
    @sprites["menu"].visible = true
    @sprites["actionbutton"].visible = true
    drawTextEx(@statictext, 4, 52, 164, 0, _INTL("Current Party:"), BASE, SHADOW)
    drawTextEx(@statictext, 62, 353, 120, 0, _INTL("Summary"), BASE, SHADOW)
    pbDrawParty($player.party, false)
    pbDrawStatScreen(stats)
    if pbConfirmMessage(_INTL("Would you like to train your Pokémon?\nDoing so may undo thier current training."))
      $player.party.each_with_index do |pkmn, i|
        oldstat  = 0
        index    = 0
        maxindex = stats.length - 1
        GameData::Stat.each_main do |s|
          next if s.id==:HP || pkmn.ev[s.id] != 252
          oldstat = s.pbs_order
        end
        pbMessage(_INTL("Select the type of training {1} should undergo.", pkmn.name))
        @changesprites.clear
        $player.party.each_with_index do |_pkmn, _i|
          next if pkmn == _pkmn
          pbDrawStatIcons(_pkmn, @sprites["partysprite#{_i}"])
        end
        @textPos.push([_INTL("Select {1}'s training.", pkmn.name), 230, 5, 0, BASE, SHADOW])
        @textPos.push([_INTL("{1}", pkmn.name), 46, (96 + (i * 40)) + 5, 0, BASE, SHADOW])
        pbDrawTextPositions(@changetext, @textPos)
        @sprites["rightarrow"].x = @xpos + 44
        @sprites["rightarrow"].y = @sprites["statbg#{index}"].y + 5
        @sprites["rightarrow"].visible = true
        loop do
          Graphics.update
          Input.update
          pbUpdate
          #---------------------------------------------------------------------
          # Scrolls up/down through the stat options.
          #---------------------------------------------------------------------
          if Input.trigger?(Input::DOWN)
            pbPlayCursorSE
            index += 1
            index  = 0 if index > maxindex
            @sprites["rightarrow"].y = @sprites["statbg#{index}"].y + 5
          elsif Input.trigger?(Input::UP)
            pbPlayCursorSE
            index -= 1
            index  = maxindex if index < 0
            @sprites["rightarrow"].y = @sprites["statbg#{index}"].y + 5
          #---------------------------------------------------------------------
          # View the Summary of the party.
          #---------------------------------------------------------------------
          elsif Input.trigger?(Input::ACTION)
            pbPlayDecisionSE
            pbSummary($player.party, i, @sprites)
          #---------------------------------------------------------------------
          # Select a training course.
          #---------------------------------------------------------------------
          elsif Input.trigger?(Input::USE)
            pbPlayDecisionSE
            cmd = pbShowCommands([_INTL("Train"),
                                  _INTL("Details"), 
                                  _INTL("Next"), 
                                  _INTL("Exit")], 0)
            name = stats[index][0]
            newstat = stats[index][1]
            case cmd
            #-------------------------------------------------------------------
            # Trains up the selected stat for the Pokemon.
            #-------------------------------------------------------------------
            when 0
              old_totals = []
              new_totals = []
              if newstat == oldstat
                pbMessage(_INTL("{1} already has {2} training.", pkmn.name, name))
              else
                if pbConfirmMessage(_INTL("Give {1} some {2} training?", pkmn.name, name))
                  pkmn.play_cry
                  #-------------------------------------------------------------
                  # Gets old stat totals
                  #-------------------------------------------------------------
                  GameData::Stat.each_main do |s|
                    case s.id
                    when :ATTACK          then poke_stat = pkmn.attack
                    when :DEFENSE         then poke_stat = pkmn.defense
                    when :SPECIAL_ATTACK  then poke_stat = pkmn.spatk
                    when :SPECIAL_DEFENSE then poke_stat = pkmn.spdef
                    when :SPEED           then poke_stat = pkmn.speed
                    else next
                    end
                    old_totals[s.pbs_order] = poke_stat
                  end
                  #-------------------------------------------------------------
                  # Applies new EV's
                  #-------------------------------------------------------------
                  case newstat
                  when 0
                    GameData::Stat.each_main do |s|
                      next if s.id == :HP
                      pkmn.ev[s.id] = 50
                    end
                  else
                    GameData::Stat.each_main do |s|
                      next if s.id == :HP
                      pkmn.ev[s.id] = (s.pbs_order == newstat) ? 252 : 0
                    end
                  end
                  pkmn.calc_stats
                  #-------------------------------------------------------------
                  # Gets new stat totals
                  #-------------------------------------------------------------
                  GameData::Stat.each_main do |s|
                    case s.id
                    when :ATTACK          then poke_stat = pkmn.attack
                    when :DEFENSE         then poke_stat = pkmn.defense
                    when :SPECIAL_ATTACK  then poke_stat = pkmn.spatk
                    when :SPECIAL_DEFENSE then poke_stat = pkmn.spdef
                    when :SPEED           then poke_stat = pkmn.speed
                    else next
                    end
                    new_totals[s.pbs_order] = poke_stat
                  end
                  #-------------------------------------------------------------
                  pbWait(25)
                  pbMessage(_INTL("{1} unlearned its previous training.\\nAnd...\1", pkmn.name))
                  pbSEPlay("Pkmn move learnt")
                  case newstat
                  when 0
                    GameData::Stat.each_main do |s|
                      next if [0, oldstat].include?(s.pbs_order)
                      diff = new_totals[s.pbs_order] - old_totals[s.pbs_order]
                      pbMessage(_INTL("{1}'s training increased its {2} by {3} point(s)!", pkmn.name, s.name, diff))
                    end
                  else
                    diff = new_totals[newstat] - old_totals[newstat]
                    pbMessage(_INTL("{1}'s training increased its {2} by {3} point(s)!", pkmn.name, name, diff))
                  end
                  @sprites["rightarrow"].visible = false
                  stats.length.times do |i|
                    @sprites["statbg#{i}"].dispose
                    @sprites["statname#{i}"].dispose
                  end
                  stats.delete_at(index)
                  pbClearAll
                  @menudisplay.clear
                  pbDrawStatScreen(stats)
                  break
                end
              end
            #-------------------------------------------------------------------
            # Checks current training.
            #-------------------------------------------------------------------
            when 1
              case newstat
              when 0
                pbMessage(_INTL("{1} training will slightly improve {2}'s performance in all stat categories, but no stat will be maximized.", name, pkmn.name))
              when 1, 4
                category = (newstat == 1) ? _INTL("physical") : _INTL("special")
                pbMessage(_INTL("{1} training will maximize {2}'s offense with {3} moves, at the expense of its other stats.", name, pkmn.name, category))
              when 2, 5
                category = (newstat == 2) ? _INTL("physical") : _INTL("special")
                pbMessage(_INTL("{1} training will maximize {2}'s resistance to {3} moves, at the expense of its other stats.", name, pkmn.name, category))
              when 3
                pbMessage(_INTL("{1} training will maximize {2}'s capacity to act sooner than other Pokémon, at the expense of its other stats.", name, pkmn.name))
              end
              stats.each do |s|
                next if s[1] != oldstat
                pbMessage(_INTL("{1} currently has {2} training.", pkmn.name, s[0]))
                break
              end
            #-------------------------------------------------------------------
            # Skips to the next Pokemon.
            #-------------------------------------------------------------------
            when 2
              if pbConfirmMessage(_INTL("Skip {1} without giving it any training?", pkmn.name))
                @sprites["rightarrow"].visible = false
                stats.length.times do |i|
                  @sprites["statbg#{i}"].dispose
                  @sprites["statname#{i}"].dispose
                end
                pbClearAll
                @menudisplay.clear
                pbDrawStatScreen(stats)
                break
              end
            #-------------------------------------------------------------------
            # Exits training selection.
            #-------------------------------------------------------------------
            when 3
              if pbConfirmMessage(_INTL("Move on without any further training?"))
                ended = true
                break
              end
            end
          #---------------------------------------------------------------------
          # Exits training selection.
          #---------------------------------------------------------------------
          elsif Input.trigger?(Input::BACK)
            if pbConfirmMessage(_INTL("Move on without any further training?"))
              ended = true
              break
            end
          end
        end
        break if ended
      end
    end
    pbPlayCloseMenuSE
    pbEndScene
  end
  
  
  #=============================================================================
  # Tutor screen.
  #=============================================================================
  def pbTutorSelect
    moves_to_learn = $player.party.length
    @sprites["pokeslot#{1}"].visible = true
    @sprites["actionbutton"].visible = true
    drawTextEx(@statictext, 4, 52, 164, 0, _INTL("Current Party:"), BASE, SHADOW)
    drawTextEx(@statictext, 62, 353, 120, 0, _INTL("Summary"), BASE, SHADOW)
    pbDrawParty($player.party)
    if pbConfirmMessage(_INTL("Would you like to tutor your Pokémon?"))
      pbMessage(_INTL("Which Pokémon requires tutoring?"))
      index    = 0
      maxindex = $player.party.length - 1
      move_swap = false
      newmoves = []
      $player.party.each { |pkmn| newmoves.push(pbGenerateTutorMove(pkmn)) }
      @sprites["leftarrow"].y = 95
      @sprites["leftarrow"].visible = true
      pbDrawTutorScreen(moves_to_learn, $player.party[index], newmoves[index])
      loop do
        Graphics.update
        Input.update
        pbUpdate
        #-----------------------------------------------------------------------
        # Scrolls up/down through your rental party.
        #-----------------------------------------------------------------------
        if Input.trigger?(Input::DOWN)
          pbPlayCursorSE
          index += 1
          index  = 0 if index > maxindex
          @sprites["leftarrow"].y = 95 + (index * 40)
          pbDrawTutorScreen(moves_to_learn, $player.party[index], newmoves[index])
        elsif Input.trigger?(Input::UP)
          pbPlayCursorSE
          index -= 1
          index  = maxindex if index < 0
          @sprites["leftarrow"].y = 95 + (index * 40)
          pbDrawTutorScreen(moves_to_learn, $player.party[index], newmoves[index])
        #-----------------------------------------------------------------------
        # View the Summary of the current rental party.
        #-----------------------------------------------------------------------
        elsif Input.trigger?(Input::ACTION)
          pbPlayDecisionSE
          pbSummary($player.party, index, @sprites)
        #-----------------------------------------------------------------------
        # Select a party member.
        #-----------------------------------------------------------------------
        elsif Input.trigger?(Input::USE)
          pbPlayDecisionSE
          pkmn = $player.party[index]
          movename = GameData::Move.get(newmoves[index]).name
          if newmoves[index]
            commands = [_INTL("Teach"), 
                        _INTL("Details")]
            commands.push(_INTL("New Move")) if !move_swap
            commands.push(_INTL("Back"))
            cmd = pbShowCommands(commands, 0)
            case cmd
            #-------------------------------------------------------------------
            # Select a move to replace.
            #-------------------------------------------------------------------
            when 0
              if pbConfirmMessage(_INTL("Teach {1} the move {2}?", pkmn.name, movename))
                pkmn.play_cry
                pbWait(25)
                if pkmn.numMoves < 4
                  pbMessage(_INTL("\\se[]{1} learned {2}!\\se[Pkmn move learnt]", pkmn.name, movename))
                  pkmn.learn_move(newmoves[index])
                  moves_to_learn -= 1
                  newmoves[index] = pbGenerateTutorMove(pkmn)
                  pbDrawTutorScreen(moves_to_learn, pkmn, newmoves[index])
                else
                  forgetMove = @scene.pbForgetMove(pkmn, newmoves[index])
                  if forgetMove >= 0
                    oldMoveName = GameData::Move.get(pkmn.moves[forgetMove].id).name
                    pbMessage(_INTL("1,\\wt[16] 2, and\\wt[16]...\\wt[16] ...\\wt[16] ... Ta-da!\\se[Battle ball drop]\1"))
                    pbMessage(_INTL("{1} forgot how to use {2}.\\nAnd...\1", pkmn.name, oldMoveName))
                    pbMessage(_INTL("\\se[]{1} learned {2}!\\se[Pkmn move learnt]", pkmn.name, movename))
                    pkmn.moves[forgetMove] = Pokemon::Move.new(newmoves[index])
                    moves_to_learn -= 1
                    newmoves[index] = pbGenerateTutorMove(pkmn)
                    pbDrawTutorScreen(moves_to_learn, pkmn, newmoves[index])
                  end
                end
                break if moves_to_learn <= 0
              end
            #-------------------------------------------------------------------
            # Display the description of the new move.
            #-------------------------------------------------------------------
            when 1
              pbMessage(_INTL("{1}:\n{2}", movename, GameData::Move.get(newmoves[index]).description))
            #-------------------------------------------------------------------
            # Swap out the current move.
            #-------------------------------------------------------------------
            else
              if ![-1, (commands.length - 1)].include?(cmd)
                if pbConfirmMessage(_INTL("Would you like to swap out {1} for a different move?\nThis may only be done once.", movename))
                  newmove = pbGenerateTutorMove(pkmn, newmoves[index])
                  if newmove && newmove != newmoves[index]
                    pbMessage(_INTL("\\se[]The move {1} may now be taught to {2}!\\se[Pkmn move learnt]", GameData::Move.get(newmove).name, pkmn.name))
                    newmoves[index] = newmove
                    pbDrawTutorScreen(moves_to_learn, pkmn, newmoves[index])
                    move_swap = true
                  else
                    pbMessage(_INTL("{1} has no other moves to learn.", pkmn.name))
                  end
                end
              end
            end
          else
            pbMessage(_INTL("{1} has no other moves to learn.", pkmn.name))
          end
        elsif Input.trigger?(Input::BACK)
          if pbConfirmMessage(_INTL("Move on without any additional tutoring?"))
            break 
          end
        end
      end
    end
    pbPlayCloseMenuSE
    pbEndScene
  end
  
  
  #=============================================================================
  # Prize screen.
  #=============================================================================
  def pbPrizeSelect
    @sprites["menu"].visible = true
    #---------------------------------------------------------------------------
    # Draws prizes.
    #---------------------------------------------------------------------------
    prizes = pbDynamaxAdventure.prizes
    6.times do |i|
      @sprites["partybg#{i}"].x   = @xpos + 100
      @sprites["partybg#{i}"].y  -= 30
      @sprites["partybg#{i}"].visible = i < prizes.length
      @sprites["partyname#{i}"].x = @sprites["partybg#{i}"].x + 37
      @sprites["partyname#{i}"].y = @sprites["partybg#{i}"].y + 9
      @sprites["partyname#{i}"].visible = i < prizes.length
    end
    pbDrawParty(prizes)
    #---------------------------------------------------------------------------
    # Draws loot.
    #---------------------------------------------------------------------------
    loot = pbDynamaxAdventure.loot
    itemname = GameData::Item.get(:DYNITEORE).name
    if loot.has_key?(:DYNITEORE)
      spritex = 4
      spritey = 30
      @sprites["itembg"] = IconSprite.new(spritex, spritey, @viewport)
      @sprites["itembg"].setBitmap(@party_path)
      @sprites["itemname"] = IconSprite.new(spritex + 36, spritey + 9, @viewport)
      @sprites["itemname"].setBitmap(@path + "menu_slot")
      @sprites["itemname"].src_rect.set(166, 20, 150, 20)
      @sprites["itemsprite"] = ItemIconSprite.new(spritex + 19, spritey + 18, :DYNITEORE, @viewport)
      @sprites["itemsprite"].zoom_x = 0.5
      @sprites["itemsprite"].zoom_y = 0.5
      @textPos.push([_INTL("x{1} {2}",loot[:DYNITEORE], itemname), spritex + 40, spritey + 11, 0, BASE, SHADOW])
      pbDrawTextPositions(@changetext, @textPos)
    end
    #---------------------------------------------------------------------------
    pbMessage(_INTL("You may select one of the captured Pokémon to keep."))
    index    = 0
    maxindex = prizes.length - 1
    @sprites["pokemon"] = PokemonSprite.new(@viewport)
    @sprites["pokemon"].setOffset(PictureOrigin::CENTER)
    @sprites["pokemon"].x = 104
    @sprites["pokemon"].y = 190
    @sprites["pokemon"].setPokemonBitmap(prizes[index])
    @sprites["rightarrow"].x = @xpos + 60
    @sprites["rightarrow"].y = @sprites["partysprite#{index}"].y + 5
    @sprites["rightarrow"].visible   = true
    @sprites["prizebg"].visible      = true
    @sprites["actionbutton"].visible = true
    drawTextEx(@statictext, 250, 6, 400, 0, _INTL("Select one Pokémon to keep."), BASE, SHADOW)
    drawTextEx(@statictext, 62, 353, 120, 0, _INTL("Summary"), BASE, SHADOW) if index > -1
    loop do
      Graphics.update
      Input.update
      pbUpdate
      #-------------------------------------------------------------------------
      # Scrolls up/down through the prize options.
      #-------------------------------------------------------------------------
      if Input.trigger?(Input::DOWN)
        pbPlayCursorSE
        index += 1
        index  = 0 if index > maxindex
        @sprites["pokemon"].setPokemonBitmap(prizes[index])
        @sprites["rightarrow"].y = @sprites["partysprite#{index}"].y + 5
      elsif Input.trigger?(Input::UP)
        pbPlayCursorSE
        index -= 1
        index  = maxindex if index < 0
        @sprites["pokemon"].setPokemonBitmap(prizes[index])
        @sprites["rightarrow"].y = @sprites["partysprite#{index}"].y + 5
      #-------------------------------------------------------------------------
      # View the Summary of a prize Pokemon.
      #-------------------------------------------------------------------------
      elsif Input.trigger?(Input::ACTION) && index > -1
        pbPlayDecisionSE
        pbSummary(prizes, index, @sprites)
      end
      #-------------------------------------------------------------------------
      # Select a prize Pokemon.
      #-------------------------------------------------------------------------
      if Input.trigger?(Input::USE)
        pbPlayDecisionSE
        cmd = pbShowCommands([_INTL("Select"),
                              _INTL("Summary"),
                              _INTL("Back")], 0)
        case cmd
        #-----------------------------------------------------------------------
        # Acquires the selected prize Pokemon.
        #-----------------------------------------------------------------------
        when 0
          pkmn = prizes[index]
          if pbConfirmMessage(_INTL("So, you'd like to take {1} with you?", pkmn.name))
            was_owned = $player.owned?(pkmn.species)
            $player.pokedex.set_seen(pkmn.species)
            $player.pokedex.set_owned(pkmn.species)
            $player.pokedex.register(pkmn)
            if Settings::SHOW_NEW_SPECIES_POKEDEX_ENTRY_MORE_OFTEN && !was_owned && $player.has_pokedex
              pbMessage(_INTL("{1}'s data was added to the Pokédex.", pkmn.speciesName))
              $player.pokedex.register_last_seen(pkmn)
              pbFadeOutIn {
                scene = PokemonPokedexInfo_Scene.new
                screen = PokemonPokedexInfoScreen.new(scene)
                screen.pbDexEntry(pkmn.species)
              }
            else
              pkmn.play_cry
              pbWait(25)
            end
            pbNicknameAndStore(pkmn)
            pbMessage(_INTL("You returned any remaining captured Pokémon and your rental party."))
            break
          end
        #-----------------------------------------------------------------------
        # View the Summary of the selected Pokemon.
        #-----------------------------------------------------------------------
        when 1
          pbSummary(prizes, index, @sprites)
        end
      elsif Input.trigger?(Input::BACK)
        break if pbConfirmMessage(_INTL("Leave without taking any captured Pokémon with you?"))
      end
    end
    if loot.has_key?(:DYNITEORE)
      item = GameData::Item.get(:DYNITEORE)
      case loot[:DYNITEORE]
      when 1 then itemname = item.portion_name
      else        itemname = item.portion_name_plural
      end
      pbMessage(_INTL("You found {1} {2} during your adventure!", loot[:DYNITEORE], itemname))
      pbMessage(_INTL("You put the {1} in\\nyour Bag's <icon=bagPocket{2}>\\c[1]{3}\\c[0] pocket.",
                      itemname, item.pocket, PokemonBag.pocket_names[item.pocket - 1]))
      $bag.add(:DYNITEORE, loot[:DYNITEORE])
      pbDynamaxAdventure.loot.delete(:DYNITEORE)
    end
    pbPlayCloseMenuSE
    pbEndScene
  end
  
  
  #=============================================================================
  # Treasure screen.
  #=============================================================================
  def pbTreasureScreen
    @statictext.clear
    xpos, ypos = Graphics.width / 2, Graphics.height / 2
    @sprites["header"] = IconSprite.new(xpos - 100, ypos - 144, @viewport)
    @sprites["header"].bitmap = Bitmap.new(@path + "menu_header")
    @sprites["background"].visible = false
    @sprites["menu"].visible = true
    @sprites["menu"].x = xpos - 150
    textPos = [ [_INTL("Treasure Chest"), xpos, ypos - 122, 2, BASE, SHADOW] ]
    rank = bonus = 1
    lair_pkmn = pbDynamaxAdventure.lair_species
    last_pkmn = pbDynamaxAdventure.last_pokemon
    species = (last_pkmn) ? last_pkmn.species : lair_pkmn.first
    lair_pkmn.each_with_index do |pkmn, i|
      if species == pkmn
        case i
        when 0, 1, 2 then rank, bonus = 2, 3
        when 3, 4, 5 then rank, bonus = 3, 4
        when 6, 7, 8 then rank, bonus = 4, 5
        when 9, 10   then rank, bonus = 5, 5
        end
        break
      end
    end
    loot = []
    GameData::Item.each { |i| loot.push(i.id) if i.is_evolution_stone? }
    rewards = raid_Rewards(species, rank, bonus, loot.sample)
    rewards.shuffle.each_with_index do |item, i|
      break if i >= rank
      item, qty = item[0], item[1]
      next if !GameData::Item.exists?(item)
      spritex = xpos - 90
      spritey = (ypos - 75) + (i * 40)
      @sprites["itembg#{i}"] = IconSprite.new(spritex, spritey, @viewport)
      @sprites["itembg#{i}"].setBitmap(@party_path)
      @sprites["itemname#{i}"] = IconSprite.new(spritex + 36, spritey + 9, @viewport)
      @sprites["itemname#{i}"].setBitmap(@path + "menu_slot")
      @sprites["itemname#{i}"].src_rect.set(166, 20, 150, 20)
      @sprites["itemsprite#{i}"] = ItemIconSprite.new(spritex + 19, spritey + 18, item, @viewport)
      @sprites["itemsprite#{i}"].zoom_x = 0.5
      @sprites["itemsprite#{i}"].zoom_y = 0.5
      item_data = GameData::Item.get(item)
      itemname = (item_data.is_TR?) ? _INTL("{1} {2}", item_data.name, GameData::Move.get(item_data.move).name) : item_data.name
      textPos.push([_INTL("x{1} {2}", qty, itemname), spritex + 40, spritey + 11, 0, BASE, SHADOW])
      pbDynamaxAdventure.add_loot(item, qty)
    end
    pbDrawTextPositions(@changetext, textPos)
    pbWait(30)
    loop do
      Graphics.update
      Input.update
      pbUpdate
      if Input.trigger?(Input::BACK) || Input.trigger?(Input::USE)
        pbPlayCloseMenuSE
        break 
      end
    end
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
  end
  
  
  #=============================================================================
  # Record screen.
  #=============================================================================
  def pbEndlessRecordScreen
    @statictext.clear
    xpos, ypos = Graphics.width / 2, Graphics.height / 2
    @sprites["header"] = IconSprite.new(xpos - 100, ypos - 144, @viewport)
    @sprites["header"].bitmap = Bitmap.new(@path + "menu_header")
    record = lair_EndlessRecord
    @sprites["background"].visible = false
    @sprites["menu"].visible = true
    @sprites["menu"].x = xpos - 150
    @sprites["menu"].tone = Tone.new(-48, -48, -48)
    textPos = [
      [_INTL("Adventure Record"), xpos, ypos - 122, 2, BASE, SHADOW],
      [_INTL("#{record[:map]}"), xpos, ypos - 75, 2, BASE, SHADOW],
      [_INTL("Floor Reached: B#{record[:floor]}F"), xpos, ypos + 76, 2, BASE, SHADOW],
      [_INTL("Pokémon Battled: #{record[:battles]}"), xpos, ypos + 105, 2, BASE, SHADOW]
    ]
    record[:party].length.times do |i|
      @sprites["partybg#{i}"].x = xpos - 80
      @sprites["partybg#{i}"].y = (ypos - 47) + (i * 40)
      @sprites["partybg#{i}"].visible = true
      @sprites["partyname#{i}"].x = @sprites["partybg#{i}"].x + 36
      @sprites["partyname#{i}"].y = @sprites["partybg#{i}"].y + 9
      @sprites["partyname#{i}"].visible = true
    end
    pbDrawParty(record[:party])
    pbDrawTextPositions(@changetext, textPos)
    loop do
      Graphics.update
      Input.update
      pbUpdate
      if Input.trigger?(Input::BACK) || Input.trigger?(Input::USE)
        pbPlayCloseMenuSE
        break 
      end
    end
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
  end
end


#===============================================================================
# Used for accessing various Max Lair menu screens.
#===============================================================================
def pbMaxLairMenu(menu_type)
  scene  = MaxLairEventScene.new
  screen = MaxLairScreen.new(scene)
  screen.pbStartSetScreen(menu_type)
end

class MaxLairScreen
  def initialize(scene)
    @scene = scene
  end

  def pbStartSetScreen(menu_type)
    case menu_type
    when :treasure
      @scene.pbStartScene(false)
      @scene.pbTreasureScreen
    when :record
      @scene.pbStartScene(false)
      @scene.pbEndlessRecordScreen
    else
      pbFadeOutIn {
        @scene.pbStartScene
        case menu_type
        when :rental   then @scene.pbRentalSelect
        when :exchange then @scene.pbSwapSelect
        when :equip    then @scene.pbItemSelect
        when :train    then @scene.pbTrainingSelect
        when :tutor    then @scene.pbTutorSelect
        when :prize    then @scene.pbPrizeSelect
        end
      }
    end
  end
end