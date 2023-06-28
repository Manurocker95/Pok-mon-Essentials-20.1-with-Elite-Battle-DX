#===============================================================================
# Max Lair Event Tiles.
#===============================================================================
class DynamaxAdventure
  #-----------------------------------------------------------------------------
  # Scientist NPC
  # Allows the player to exchange a party member for a new rental Pokemon.
  #-----------------------------------------------------------------------------
  def lair_npc_swap
    return if ended?
    return if !inProgress?
    trainer = GameData::TrainerType.try_get(:SCIENTIST)
    gender = (trainer) ? trainer.gender : 2
    g = (gender == 0) ? "\\b" : (gender == 1) ? "\\r" : ""
    pbMessage(_INTL("You encountered a Scientist!"), nil, 0, WINDOWSKIN)
    pbMessage(_INTL("#{g}How have the results of your adventure been so far?"))
    pbMessage(_INTL("#{g}I have a rental Pokémon here that I could swap with you, if you'd like."))
    pbMaxLairMenu(:exchange)
    pbMessage(_INTL("#{g}I'll head back to study the new data I've gathered."))
    pbMessage(_INTL("#{g}Please report any new findings you may discover on your adventure!"))
    return true
  end
  
  #-----------------------------------------------------------------------------
  # Backpacker NPC
  # Allows the player to equip items to party members out of a randomized list.
  #-----------------------------------------------------------------------------
  def lair_npc_equip
    return if ended?
    return if !inProgress?
    trainer = GameData::TrainerType.try_get(:HIKER)
    gender = (trainer) ? trainer.gender : 2
    g = (gender == 0) ? "\\b" : (gender == 1) ? "\\r" : ""
    pbMessage(_INTL("You encountered a Backpacker!"), nil, 0, WINDOWSKIN)
    pbMessage(_INTL("#{g}I was worried I'd run into trouble in here, so I stocked up on more than I can carry..."))
    pbMessage(_INTL("#{g}I can share my supplies with you if you're in need. What items would you like?"))
    pbMaxLairMenu(:equip)
    pbMessage(_INTL("#{g}Remember, preparation is the key to victory!"))
  end
  
  #-----------------------------------------------------------------------------
  # Blackbelt NPC
  # Allows the player to reallocate EV points of party members.
  #-----------------------------------------------------------------------------
  def lair_npc_train
    return if ended?
    return if !inProgress?
    trainer = GameData::TrainerType.try_get(:BLACKBELT)
    gender = (trainer) ? trainer.gender : 2
    g = (gender == 0) ? "\\b" : (gender == 1) ? "\\r" : ""
    pbMessage(_INTL("You encountered a Blackbelt!"), nil, 0, WINDOWSKIN)
    pbMessage(_INTL("#{g}I've been training deep in this lair so that I can grow strong like a Dynamax Pokémon!"))
    pbMessage(_INTL("#{g}Do you want to become strong, too? Let me share my secret training techniques with you!"))
    pbMaxLairMenu(:train)
    pbMessage(_INTL("#{g}Keep pushing yourself until you've reached your limits!"))
  end
  
  #-----------------------------------------------------------------------------
  # Ace Trainer NPC
  # Allows the player to tutor their party Pokemon to teach them up to three 
  # new randomly generated moves in total.
  #-----------------------------------------------------------------------------
  def lair_npc_tutor
    return if ended?
    return if !inProgress?
    trainer = GameData::TrainerType.try_get(:COOLTRAINER_F)
    gender = (trainer) ? trainer.gender : 2
    g = (gender == 0) ? "\\b" : (gender == 1) ? "\\r" : ""
    pbMessage(_INTL("You encountered an Ace Trainer!"), nil, 0, WINDOWSKIN)
    pbMessage(_INTL("#{g}I've been studying the most effective tactics to use in Dynamax battles."))
    pbMessage(_INTL("#{g}If you'd like, I can teach one of your Pokémon a new move to help it excel in battle!"))
    pbMaxLairMenu(:tutor)
    pbMessage(_INTL("#{g}A good strategy will help you overcome any obstacle!"))
  end
  
  #-----------------------------------------------------------------------------
  # Channeller NPC
  # Increases the player's current and total heart counter by 1.
  # The heart counter caps at six, and will not increase beyond that.
  #-----------------------------------------------------------------------------
  def lair_npc_ward_intro
    return if ended?
    return if !inProgress?
    trainer = GameData::TrainerType.try_get(:CHANNELER)
    gender = (trainer) ? trainer.gender : 2
    g = (gender == 0) ? "\\b" : (gender == 1) ? "\\r" : ""
    pbMessage(_INTL("You encountered a Channeler!"), nil, 0, WINDOWSKIN)
    pbMessage(_INTL("#{g}Ahh! Your spirit beckons me to cleanse it of its weariness!"))
    pbMessage(_INTL("#{g}Let me exorcise the demons that plague your body and soul!"))
    pbMessage(_INTL("#{g}...\\wt[10] ...\\wt[10] ...\\wt[20]Begone!"))
    @knockouts += 1
    @knockouts = 6 if @knockouts > 6
  end
  
  def lair_npc_ward_outro
    return if ended?
    return if !inProgress?
    trainer = GameData::TrainerType.try_get(:CHANNELER)
    gender = (trainer) ? trainer.gender : 2
    g = (gender == 0) ? "\\b" : (gender == 1) ? "\\r" : ""
    pbSEPlay(sprintf("Anim/Natural Gift"))
    pbMessage(_INTL("Your total number of hearts increased!\\wt[34]"), nil, 0, WINDOWSKIN)
    pbMessage(_INTL("#{g}What am I even doing here, you ask?\nHaha! Foolish child."))
    randtext = rand(5)
    case randtext
    when 0
      pbMessage(_INTL("#{g}I was once an adventurer like you who got lost in this lair.\nMany...\\wt[10]many years ago.\\wt[10]"))
      pbMessage(_INTL("Huh? The Channeler suddenly vanished!"), nil, 0, WINDOWSKIN)
    when 1
      pbMessage(_INTL("#{g}I go where the spirits say I'm needed! Nothing more!"))
      pbMessage(_INTL("#{g}I must go now, young one. There are many other souls that need saving!"))
    when 2
      pbMessage(_INTL("#{g}What makes you think I was ever really here at all?\nOooooo....\\wt[10]"))
      pbWait(20)
      pbMessage(_INTL("The Channeler tripped over a rock during their dramatic exit."), nil, 0, WINDOWSKIN)
    when 3
      pbMessage(_INTL("#{g}I was summoned here by the wailing of souls crying out from this lair!"))
      pbMessage(_INTL("#{g}..but now that I'm here, I think it was just the wind."))
      pbMessage(_INTL("#{g}Perhaps it was fate that drew me here to meet you?\nAlas, it is now time for us to part ways."))
      pbMessage(_INTL("#{g}Farewell, child. Good luck on your journeys."))
    when 4
      pbMessage(_INTL("#{g}If you must know, I...\\wt[10]just got lost."))
      pbMessage(_INTL("#{g}The exit is back there, you say?\nThank you, child."))
      pbMessage(_INTL("#{g}May the spirits guide you better than they have me!"))
    end
    return true
  end
  
  #-----------------------------------------------------------------------------
  # Nurse NPC
  # Fully restores the player's party.
  #-----------------------------------------------------------------------------
  def lair_npc_heal
    return if ended?
    return if !inProgress?
    trainer = GameData::TrainerType.try_get(:LASS)
    gender = (trainer) ? trainer.gender : 2
    g = (gender == 0) ? "\\b" : (gender == 1) ? "\\r" : ""
    pbMessage(_INTL("You encountered a Nurse!"), nil, 0, WINDOWSKIN)
    pbMessage(_INTL("#{g}Are your Pokémon feeling a bit worn out from your adventure?"))
    pbMessage(_INTL("\\me[Pkmn healing]#{g}Please, let me heal them back to full health.\\wtnp[30]"))
    $player.party.each { |p| p.heal }
    pbMessage(_INTL("#{g}I'll be going now.\nGood luck with the rest of your adventure!"))
    return true
  end
  
  #-----------------------------------------------------------------------------
  # Random NPC
  # The effect of a random NPC Tile is applied.
  #-----------------------------------------------------------------------------
  def lair_npc_random
    return if ended?
    return if !inProgress?
    case rand(5)
    when 0 then lair_npc_swap
    when 1 then lair_npc_equip
    when 2 then lair_npc_train
    when 3 then lair_npc_tutor
    when 4 then lair_npc_heal
    end
    return true
  end
  
  #-----------------------------------------------------------------------------
  # Berries
  # Heals up to 50% of each party member's max HP if any party Pokemon are
  # damaged. Leaves the berries behind if already at full health.
  #-----------------------------------------------------------------------------
  def lair_tile_berry
    return if ended?
    return if !inProgress?
    pbMessage(_INTL("You found some Berries lying on the ground!"))
    needs_healing = false
    $player.party.each { |p| needs_healing = true if p.hp < p.totalhp }
    if needs_healing
      pbSEPlay(sprintf("Anim/Recovery"))
      pbMessage(_INTL("Your Pokémon ate the Berries and some of their HP was restored!"))
      for i in $player.party
        i.hp += i.totalhp / 2
        i.hp = i.totalhp if i.hp > i.totalhp
      end
      return true
    else
      pbMessage(_INTL("But your Pokémon are already at full health..."))
      pbMessage(_INTL("You decided to leave the Berries behind and press on!"))
      return false
    end
  end
  
  #-----------------------------------------------------------------------------
  # Treasure Chest
  # Collects random rewards. The quality of the rewards scales with the difficulty
  # of the last Pokemon that was encountered in the lair. Some chests are locked,
  # and require a Lair Key to open. Some chests are also traps, and may warp the
  # player back to the start of the lair.
  #-----------------------------------------------------------------------------
  def lair_tile_chest(value)
    return if ended?
    return if !inProgress?
    pbMessage(_INTL("You found a Treasure Chest!"))
    trap_chest = value.digits.first == 0
    if value < 15
      pbMessage(_INTL("But the chest appears to be locked..."))
      if @keycount > 0
        pbMessage(_INTL("You used a Lair Key to unlock the Treasure Chest!"))
        pbSEPlay("Battle catch click")
        pbMaxLairMenu(:treasure) if !trap_chest
        if trap_chest
          pbWait(8)
          pbSEPlay("Exclaim")
          pbMessage(_INTL("Huh?"))
          pbMessage(_INTL("A pair of glowing red eyes peeked at you from within the chest..."))
          pbMessage(_INTL("A mysterious Pokémon growled from within and shrouded you in darkness!"))
        end
        return true
      else
        pbMessage(_INTL("With a heavy sigh, you decided to press on and leave the chest behind..."))
        return false
      end
    else
      pbSEPlay("Battle catch click")
      pbMaxLairMenu(:treasure) if !trap_chest
      if trap_chest
        pbWait(8)
        pbSEPlay("Exclaim")
        pbMessage(_INTL("Huh?"))
        pbMessage(_INTL("A pair of glowing red eyes peeked at you from within the chest..."))
        pbMessage(_INTL("A mysterious Pokémon growled from within and shrouded you in darkness!"))
      end
      return true
    end
  end
  
  #-----------------------------------------------------------------------------
  # Lair Keys
  # Collects a key that may be used to unlock doors and chests.
  #-----------------------------------------------------------------------------
  def lair_tile_key
    return if ended?
    return if !inProgress?
    @keycount += 1
    pbMessage(_INTL("\\me[Bug catching 3rd]You found a Lair Key!\\wtnp[30]"))
    return true
  end
  
  #-----------------------------------------------------------------------------
  # Locked Door
  # Prevents passage unless a key is used to unlock it.
  #-----------------------------------------------------------------------------
  def lair_tile_door
    return if ended?
    return if !inProgress?
    return true if $DEBUG && Input.press?(Input::CTRL)
    pbMessage(_INTL("A massive locked door blocks your path."))
    if @keycount > 0
      @keycount -= 1
      pbMessage(_INTL("You used a Lair Key to open the door!"))
      pbSEPlay("Battle catch click")
      pbWait(2)
      pbSEPlay("Door open")
      return true
    else
      pbMessage(_INTL("Unable to proceed, you turned back the way you came."))
      return false
    end
  end
  
  #-----------------------------------------------------------------------------
  # Flare
  # Lights a found flare to illuminate a dark lair and increase visibility.
  #-----------------------------------------------------------------------------
  def lair_tile_flare
    return if ended?
    return if !inProgress?
    pbMessage(_INTL("\\me[Bug catching 3rd]You found a Flare!\\wtnp[30]"))
    if @darkness_map
      pbMessage(_INTL("You lit the flare and increased your visibility!"))
      return true
    else
      pbMessage(_INTL("But this is of no use to you in this lair..."))
      return false
    end
  end
  
  #-----------------------------------------------------------------------------
  # Roadblocks
  # Prevents movement unless a party member meets certain criteria.
  #-----------------------------------------------------------------------------
  def lair_tile_block(value)
    return if ended?
    return if !inProgress?
    return true if $DEBUG && Input.press?(Input::CTRL)
    pokemon = nil
    case value
    #---------------------------------------------------------------------------
    when 0 # Flying-type (Chasm)
      pbMessage(_INTL("A deep chasm blocks your path."))
      pbMessage(_INTL("A Flying-type Pokémon may be able to lift you safely across."))
      text = "{1} happily carried you across the chasm."
      $player.pokemon_party.each { |p| pokemon = p if p.hasType?(:FLYING) }
    #---------------------------------------------------------------------------
    when 1 # Water-type (Ferry)
      pbMessage(_INTL("A large pool of murky water blocks your path."))
      pbMessage(_INTL("A Water-type Pokémon may be able to ferry you safely across."))
      text = "{1} happily carried you across the water."
      $player.pokemon_party.each { |p| pokemon = p if p.hasType?(:WATER) }
    #---------------------------------------------------------------------------
    when 2 # Fighting-type (Wall)
      pbMessage(_INTL("You reached what appears to be a dead end, but the wall here seems thin."))
      pbMessage(_INTL("A Fighting-type Pokémon may be able to punch through the wall and forge a path forward."))
      text = "{1} bashed through the wall with a mighty blow!"
      $player.pokemon_party.each { |p| pokemon = p if p.hasType?(:FIGHTING) }
    #---------------------------------------------------------------------------
    when 3 # Psychic-type (Pitfall)
      pbMessage(_INTL("The floor here seems unstable in certain spots, and you may fall through if you proceed."))
      pbMessage(_INTL("A Psychic-type Pokémon may be able to foresee the safest route forward and avoid any pitfalls."))
      text = "{1} foresaw the dangers ahead and navigated you safely across."
      $player.pokemon_party.each { |p| pokemon = p if p.hasType?(:PSYCHIC) }
    #---------------------------------------------------------------------------
    when 4 # Rock/Ground/Steel-type (Sandstorm)
      pbMessage(_INTL("Strong winds funneled through the passage have whipped up a storm of dust that blocks your path."))
      pbMessage(_INTL("A Rock, Ground, or Steel-type Pokémon may be able to safely guide you through the storm."))
      text = "{1} bravely traversed the storm and led you across."
      $player.pokemon_party.each do |p|
        break if pokemon
        pokemon = p if p.hasType?(:ROCK) || p.hasType?(:GROUND) || p.hasType?(:STEEL)
      end
    #---------------------------------------------------------------------------
    when 5 # Bug/Dark/Ghost (Spooky)
      pbMessage(_INTL("An eerie wail howling from the depths of the lair stops you cold in your tracks."))
      pbMessage(_INTL("A Bug, Dark, or Ghost-type Pokémon may be able to scout the path ahead without fear."))
      text = "{1} investigated the eerie wail and discovered it was just the wind!"
      $player.pokemon_party.each do |p|
        break if pokemon
        pokemon = p if p.hasType?(:BUG) || p.hasType?(:DARK) || p.hasType?(:GHOST)
      end
    #---------------------------------------------------------------------------
    when 6 # Attack EV's (Boulder)
      pbMessage(_INTL("A massive boulder blocks your path."))
      pbMessage(_INTL("A Pokémon sufficienty trained in Attack may be physically capable of moving it."))
      text = "{1} flexed its muscles and tossed the boulder aside with ease!"
      $player.pokemon_party.each { |p| pokemon = p if p.ev[:ATTACK] == 252 }
    #---------------------------------------------------------------------------
    when 7 # Defense EV's (Rockslide)
      pbMessage(_INTL("Falling rocks makes it too dangerous to press on."))
      pbMessage(_INTL("A Pokémon sufficienty trained in Defense may be tough enough to shield you from harm."))
      text = "{1} unflinchingly shrugged off the falling rocks as you moved on ahead!"
      $player.pokemon_party.each { |p| pokemon = p if p.ev[:DEFENSE] == 252 }
    #---------------------------------------------------------------------------
    when 8 # Speed EV's (Incline)
      pbMessage(_INTL("A steep incline makes it too difficult to climb any further."))
      pbMessage(_INTL("A Pokémon sufficienty trained in Speed may be quick enough to carry you up with ease."))
      text = "{1} bolted you up the incline without breaking a sweat!"
      $player.pokemon_party.each { |p| pokemon = p if p.ev[:SPEED] == 252 }
    #---------------------------------------------------------------------------
    when 9 # Sp.Atk EV's (Barrier) 
      pbMessage(_INTL("An impenetrable barrier of Dynamax energy blocks your path."))
      pbMessage(_INTL("A Pokémon sufficienty trained in Special Attack may be powerful enough to blast through it."))
      text = "{1} let out a yawn and effortlessly shattered the barrier!"
      $player.pokemon_party.each { |p| pokemon = p if p.ev[:SPECIAL_ATTACK] == 252 }
    #---------------------------------------------------------------------------
    when 10 # Sp.Def EV's (Energy waves)
      pbMessage(_INTL("A powerful wave of Dynamax energy prevents you from continuing on this path."))
      pbMessage(_INTL("A Pokémon sufficienty trained in Special Defense may have enough fortitude to carry you through it."))
      text = "{1} swatted away the waves of energy and carried you through unscathed!"
      $player.pokemon_party.each { |p| pokemon = p if p.ev[:SPECIAL_DEFENSE] == 252 }
    #---------------------------------------------------------------------------
    when 11 # Balanced EV's (Gauntlet)
      pbMessage(_INTL("An intimidating gauntlet of various challenges prevents you from pressing onwards."))
      pbMessage(_INTL("A Pokémon with balanced training may be capable of overcoming the numerous obstacles."))
      text = "{1} impressively traversed the gauntlet with near-perfect form!"
      $player.pokemon_party.each { |p| pokemon = p if p.ev[:ATTACK] == 50 }
    #---------------------------------------------------------------------------
    end
    if pokemon
      pbHiddenMoveAnimation(pokemon)
      pbMessage(_INTL(text, pokemon.name))
      return true
    else
      pbMessage(_INTL("Unable to proceed, you turned back the way you came."))
      return false
    end
  end
  
  #-----------------------------------------------------------------------------
  # Hidden Traps
  # May inflict negative effects on a random party member when triggered.
  #-----------------------------------------------------------------------------
  def lair_tile_trap(value)
    return if ended?
    return if !inProgress?
    pbSEPlay("Exclaim")
    pokemon = $player.party.sample
    case value
    #---------------------------------------------------------------------------
    when 0 # Damage (Falling)
      pbMessage(_INTL("You suddenly lost your footing and fell down a deep shaft!"))
      text1 = "{1} came to your rescue and cushioned your fall!"
      text2 = "Luckily, {1} managed to avoid harm!"
      text3 = "However, {1} was injured in the process..."
      failure = rand(10) < 2
    #---------------------------------------------------------------------------
    when 1 # Sleep (Mushroom spores)
      pbMessage(_INTL("A nearby overgrown mushroom suddenly burst and released a cloud of spores!"))
      text1 = "{1} pushed you aside and was hit by the cloud of spores instead!"
      text2 = "Luckily, the spores had no effect on {1}!"
      text3 = "{1} became drowsy due to the spores!"
      failure = pokemon.hasType?(:GRASS)
      status = :SLEEP
    #---------------------------------------------------------------------------
    when 2 # Poison (Mysterious ooze)
      pbMessage(_INTL("A mysterious ooze leaked from the cieling and fell towards you!"))
      text1 = "{1} pushed you aside and was hit by the mysterious ooze instead!"
      text2 = "Luckily, the mysterious ooze had no effect on {1}!"
      text3 = "{1} became poisoned due to the mysterious ooze!"
      failure = pokemon.hasType?(:POISON)
      status = :POISON
    #---------------------------------------------------------------------------
    when 3 # Burn (Hot steam)
      pbMessage(_INTL("A geyser of hot steam suddenly erupted beneath your feet!"))
      text1 = "{1} pushed you aside and was hit by the hot steam instead!"
      text2 = "Luckily, the hot steam had no effect on {1}!"
      text3 = "{1} became burned due to the hot steam!"
      failure = pokemon.hasType?(:FIRE)
      status = :BURN
    #---------------------------------------------------------------------------
    when 4 # Paralysis (Electrical pulse)
      pbMessage(_INTL("An electrical pulse was suddenly released by charged iron deposits nearby!"))
      text1 = "{1} pushed you aside and was hit by the electrical pulse instead!"
      text2 = "Luckily, the electrical pulse had no effect on {1}!"
      text3 = "{1} became paralyzed due to the electrical pulse!"
      failure = pokemon.hasType?(:ELECTRIC)
      status = :PARALYSIS
    #---------------------------------------------------------------------------
    when 5 # Frozen (Frigid water)
      pbMessage(_INTL("You walked over a sheet of ice and it began to crack beneath your feet!"))
      text1 = "{1} pushed you aside and plunged into the frigid water instead!"
      text2 = "Luckily, the frigid water had no effect on {1}!"
      text3 = "{1} was frozen solid due to the frigid water!"
      failure = pokemon.hasType?(:ICE)
      status = :FROZEN
    #---------------------------------------------------------------------------
    end
    pbHiddenMoveAnimation(pokemon)
    pbMessage(_INTL(text1, pokemon.name))
    if failure
      pbSEPlay("Mining found all")
      pbMessage(_INTL(text2, pokemon.name))
    else
      case value
      when 0
        pokemon.hp -= pokemon.totalhp / 4
        pokemon.hp = 1 if pokemon.hp <= 0
      else
        pokemon.status = status
        pokemon.statusCount = 4 if value == 1
      end
      pbSEPlay("Battle damage normal")
      pbMessage(_INTL(text3, pokemon.name))
    end
    return true
  end
end