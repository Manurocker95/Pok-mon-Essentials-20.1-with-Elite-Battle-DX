#===============================================================================
# Item handlers.
#===============================================================================

#-------------------------------------------------------------------------------
# Z-Crystal and Ultra Item properties
#-------------------------------------------------------------------------------
module GameData
  class Item
    def is_z_crystal?; return has_flag?("ZCrystal"); end
    def is_ultra_item?; return has_flag?("UltraItem"); end
      
    alias zud_is_important? is_important? 
    def is_important?
      return zud_is_important? || is_z_crystal?
    end
	
    alias zud_unlosable? unlosable?
    def unlosable?(*args)
      return true if is_z_crystal? || is_ultra_item?
      zud_unlosable?(*args)
    end
    
	Item.singleton_class.alias_method :zud_held_icon_filename, :held_icon_filename
    def self.held_icon_filename(item)
      item_data = self.try_get(item)
      return nil if !item_data
      name_base = "zcrystal" if item_data.is_z_crystal?
      ["Graphics/Plugins/ZUD/UI/icon_",
       "Graphics/Pictures/Party/icon_"].each do |p|
        ret = sprintf(p + "%s_%s", name_base, item_data.id)
        return ret if pbResolveBitmap(ret)
        ret = sprintf(p + "%s", name_base)
        return ret if pbResolveBitmap(ret)
      end
      return self.zud_held_icon_filename(item)
    end
	
    # Used for getting TR's based on the inputted types.
    def self.get_TR_from_type(types)
      trList = []
      self.each do |i|
        next if !i.is_TR?
        move_type = GameData::Move.get(i.move).type
        next if !types.include?(move_type)
        trList.push(i.id)
      end
      return trList.sample
    end
  end
end


#-------------------------------------------------------------------------------
# Adds Z-Crystal pocket to the bag.
#-------------------------------------------------------------------------------
module Settings
  Settings.singleton_class.alias_method :zud_bag_pocket_names, :bag_pocket_names
  def self.bag_pocket_names
    names = self.zud_bag_pocket_names
    names.push(_INTL("Z-Crystals"))
    return names
  end
   
  BAG_MAX_POCKET_SIZE.push(-1)
  BAG_POCKET_AUTO_SORT.push(true)
end


#-------------------------------------------------------------------------------
# Fix to prevent Z-Crystals from duplicating in the bag.
#-------------------------------------------------------------------------------
class PokemonBag
  alias zud_can_add? can_add?
  def can_add?(item, qty = 1)
    return true if GameData::Item.get(item).is_z_crystal?
    zud_can_add?(item, qty)
  end
  
  alias zud_add add
  def add(item, qty = 1)
    qty = 0 if has?(item, 1) && GameData::Item.get(item).is_z_crystal?
    zud_add(item, qty)
  end
end


#-------------------------------------------------------------------------------
# Z-Crystals
#-------------------------------------------------------------------------------
# Equips a holdable crystal upon use. Pokemon may still equip a Z-Crystal even if
# they are incompatible with it, but a message will display saying that it can't
# be used. This message will not play, however, if the Z-Crystal would also allow
# for the species to Ultra Burst, even if the Pokemon itself can't use the Z-Move
# in its current state.
#-------------------------------------------------------------------------------
ItemHandlers::UseOnPokemon.addIf(proc { |item| GameData::Item.get(item).is_z_crystal? },
  proc { |item, qty, pkmn, scene|
    crystal    = GameData::Item.get(item).portion_name
    compatible = pkmn.compat_zmove?(pkmn.moves, item) || pkmn.compat_ultra?(item)
    if pkmn.shadowPokemon? || pkmn.egg?
      scene.pbDisplay(_INTL("It won't have any effect."))
      next false
    elsif pkmn.item == item
      scene.pbDisplay(_INTL("{1} is already holding a {2}.", pkmn.name, crystal))
      next false
    elsif !compatible && !scene.pbConfirm(_INTL("This Pokémon currently can't use this crystal's Z-Power. Is that OK?"))
      next false
    end
    scene.pbDisplay(_INTL("The {1} will be given to the Pokémon so that the Pokémon can use its Z-Power!", crystal))
    if pkmn.item
      itemname = GameData::Item.get(pkmn.item).portion_name
      text = (itemname.starts_with_vowel?) ? "an" : "a"
      scene.pbDisplay(_INTL("{1} is already holding {2} {3}.\1", pkmn.name, text, itemname))
      if scene.pbConfirm(_INTL("Would you like to switch the two items?"))
        if !$bag.can_add?(pkmn.item)
          scene.pbDisplay(_INTL("The Bag is full. The Pokémon's item could not be removed."))
          next false
        else
          $bag.add(pkmn.item)
          scene.pbDisplay(_INTL("You took the Pokémon's {1} and gave it the {2}.", itemname, crystal))
        end
      else
        next false
      end
    end
    pkmn.item = item
    pbSEPlay("Pkmn move learnt")
    scene.pbDisplay(_INTL("Your Pokémon is now holding a {1}!", crystal))
    next true
  }
)


#-------------------------------------------------------------------------------
# Dynamax Candy/XL
#-------------------------------------------------------------------------------
# Increases the Dynamax Level of a Pokemon by 1. The XL variety maxes out this 
# level instead. This won't have any effect on Pokemon that are incapable of
# Dynamaxing, including Eternatus.
#-------------------------------------------------------------------------------
ItemHandlers::UseOnPokemon.add(:DYNAMAXCANDY, proc { |item, qty, pkmn, scene|
  if pkmn.shadowPokemon? || pkmn.egg?
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  end
  if pkmn.dynamax_lvl < 10 && pkmn.dynamax_able? && !pkmn.isSpecies?(:ETERNATUS)
    pbSEPlay("Pkmn move learnt")
    if item == :DYNAMAXCANDYXL
      scene.pbDisplay(_INTL("{1}'s Dynamax level was increased to 10!", pkmn.name))
      $stats.total_dynamax_lvls_gained += (10 - pkmn.dynamax_lvl)
      pkmn.dynamax_lvl = 10
    else
      scene.pbDisplay(_INTL("{1}'s Dynamax level was increased by 1!", pkmn.name))
      $stats.total_dynamax_lvls_gained += 1
      pkmn.dynamax_lvl += 1
    end
    scene.pbHardRefresh
    next true
  else
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  end
})

ItemHandlers::UseOnPokemon.copy(:DYNAMAXCANDY, :DYNAMAXCANDYXL)


#-------------------------------------------------------------------------------
# Max Soup
#-------------------------------------------------------------------------------
# Toggles Gigantamax Factor if the species has a Gigantamax form. Cannot be used
# to give Eternatus G-Max Factor, however.
#-------------------------------------------------------------------------------
ItemHandlers::UseOnPokemon.add(:MAXSOUP, proc { |item, qty, pkmn, scene|
  if pkmn.shadowPokemon? || pkmn.egg?
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  end
  if pkmn.hasGmax? && !pkmn.isSpecies?(:ETERNATUS)
    if pkmn.gmax_factor?
      pkmn.gmax_factor = false
      scene.pbDisplay(_INTL("{1} lost its Gigantamax energy.", pkmn.name))
    else
      pbSEPlay("Pkmn move learnt")
      pkmn.gmax_factor = true
      $stats.total_gmax_factors_given += 1
      scene.pbDisplay(_INTL("{1} is now bursting with Gigantamax energy!", pkmn.name))
    end
    scene.pbHardRefresh
    next true
  else
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  end
})


#-------------------------------------------------------------------------------
# Max Scales
#-------------------------------------------------------------------------------
# Allows a Pokemon to recall a past move.
#-------------------------------------------------------------------------------
ItemHandlers::UseOnPokemon.add(:MAXSCALES, proc { |item, qty, pkmn, scene|
  if pkmn.shadowPokemon? || pkmn.egg?
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  end
  moves = []
  pkmn.first_moves.each do |m|
    next if pkmn.hasMove?(m)
    moves.push(m)
  end
  pkmn.getMoveList.each do |m|
    next if m[0] > pkmn.level || pkmn.hasMove?(m[1])
    moves.push(m[1])
  end
  if !moves.empty?
    scene.pbDisplay(_INTL("What move should {1} recall?", pkmn.name))
    oldmoves = []
    pkmn.moves.each { |m| oldmoves.push(m) }
    pbRelearnMoveScreen(pkmn)
    newmoves = pkmn.moves
    next newmoves != oldmoves
  else
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  end
})


#-------------------------------------------------------------------------------
# Max Plumage
#-------------------------------------------------------------------------------
# Increases each IV of a Pokemon by 1 point. Unlike Hyper Training, this will
# increase the Pokemon's raw IV's, instead of simply altering the Pokemon's 
# stats to be equivalent of higher IV's.
#-------------------------------------------------------------------------------
ItemHandlers::UseOnPokemon.add(:MAXPLUMAGE, proc { |item, qty, pkmn, scene|
  if pkmn.shadowPokemon? || pkmn.egg?
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  end
  used = false
  GameData::Stat.each_main do |s|
    next if pkmn.iv[s.id] == Pokemon::IV_STAT_LIMIT
    pkmn.iv[s.id] += 1
    used = true
  end
  if used
    pbSEPlay("Pkmn move learnt")
    scene.pbDisplay(_INTL("The quality of {1}'s base stats each increased by 1!", pkmn.name))
    pkmn.calc_stats
    scene.pbHardRefresh
    next true
  else
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  end
})


#-------------------------------------------------------------------------------
# Max Eggs
#-------------------------------------------------------------------------------
# Increases the party's Exp. by a large amount relative to badge count.
#-------------------------------------------------------------------------------
ItemHandlers::UseInField.add(:MAXEGGS, proc { |item|
  if $player.pokemon_count == 0
    pbMessage(_INTL("There are no Pokémon."))
    next false
  end
  cangain = false
  $player.pokemon_party.each do |i|
    next if i.level >= GameData::GrowthRate.max_level || i.shadowPokemon? || i.egg?
    cangain = true
    break
  end
  if !cangain
    pbMessage(_INTL("It won't have any effect."))
    next false
  end
  gainers     = 0
  experience  = 2500
  experience *= ($player.badge_count > 1) ? $player.badge_count : 1
  experience  = 20000 if experience > 20000
  pbFadeOutIn {
    scene  = PokemonParty_Scene.new
    screen = PokemonPartyScreen.new(scene, $player.party)
    screen.pbStartScene(_INTL("Using item..."), false)
    $player.party.each_with_index do |pkmn, i|
      next if pkmn.shadowPokemon? || pkmn.egg?
      next if pkmn.level >= GameData::GrowthRate.max_level
      gainers   += 1
      maxexp     = pkmn.growth_rate.maximum_exp
      newexp     = pkmn.growth_rate.add_exp(pkmn.exp, experience)
      newlevel   = pkmn.growth_rate.level_from_exp(newexp)
      experience = (maxexp - pkmn.exp) if maxexp < (pkmn.exp + experience)
      screen.pbDisplay(_INTL("{1} gained {2} Exp. Points!", pkmn.name, experience.to_s_formatted))
      pbSEPlay("Pkmn move learnt")
      pbChangeLevel(pkmn, newlevel, screen)
      pkmn.exp = newexp
      screen.pbRefreshSingle(i)
    end
    if gainers == 0
      screen.pbDisplay(_INTL("It won't have any effect."))
    end
    screen.pbEndScene
  }
  next (gainers > 0)
})


#-------------------------------------------------------------------------------
# Z-Booster
#-------------------------------------------------------------------------------
# Restores your ability to use Z-Moves if one was already used in battle. Using
# this item will take up your entire turn, and cannot be used if orders have
# already been given to a Pokemon.
#-------------------------------------------------------------------------------
ItemHandlers::CanUseInBattle.add(:ZBOOSTER, proc { |item, pokemon, battler, move, firstAction, battle, scene, showMessages|
  side  = battler.idxOwnSide
  owner = battle.pbGetOwnerIndexFromBattlerIndex(battler.index)
  ring  = battle.pbGetZRingName(battler.index)      
  dmax  = false
  battle.eachSameSideBattler(battler) { |b| dmax = true if b.dynamax? }
  if !battle.pbHasZRing?(battler.index)
    scene.pbDisplay(_INTL("You don't have a {1} to charge!", ring))
    next false
  elsif !firstAction
    scene.pbDisplay(_INTL("You can't use this item while issuing orders at the same time!"))
    next false
  elsif battle.zMove[side][owner] == -1
    if showMessages
      scene.pbDisplay(_INTL("You don't need to recharge your {1} yet!", ring))
    end
    next false
  end
  next true
})

ItemHandlers::UseInBattle.add(:ZBOOSTER, proc { |item, battler, battle|
  ring    = battle.pbGetZRingName(battler.index)
  trainer = battle.pbGetOwnerName(battler.index)
  item    = GameData::Item.get(item).portion_name
  battle.pbSetBattleMechanicUsage(battler.index, "Z-Move", -1)
  pbSEPlay(sprintf("Anim/Lucky Chant"))
  battle.pbDisplayPaused(_INTL("The {1} fully recharged {2}'s {3}!\n{2} can use Z-Moves again!", item, trainer, ring))
})


#-------------------------------------------------------------------------------
# Wishing Star
#-------------------------------------------------------------------------------
# Restores your ability to use Dynamax if it was already used in battle. Using
# this item will take up your entire turn, and cannot be used if orders have
# already been given to a Pokemon. This item also can't be used if you still
# currently have a Dynamaxed Pokemon on the field.
#-------------------------------------------------------------------------------
ItemHandlers::CanUseInBattle.add(:WISHINGSTAR, proc { |item, pokemon, battler, move, firstAction, battle, scene, showMessages|
  side  = battler.idxOwnSide
  owner = battle.pbGetOwnerIndexFromBattlerIndex(battler.index)
  band  = battle.pbGetDynamaxBandName(battler.index)      
  dmax  = false
  battle.eachSameSideBattler(battler) { |b| dmax = true if b.dynamax? }
  if !battle.pbHasDynamaxBand?(battler.index)
    scene.pbDisplay(_INTL("You don't have a {1} to charge!", band))
    next false
  elsif !firstAction
    scene.pbDisplay(_INTL("You can't use this item while issuing orders at the same time!"))
    next false
  elsif dmax || battle.dynamax[side][owner] == -1
    if showMessages
      scene.pbDisplay(_INTL("You don't need to recharge your {1} yet!", band))
    end
    next false
  end
  next true
})

ItemHandlers::UseInBattle.add(:WISHINGSTAR, proc { |item, battler, battle|
  band    = battle.pbGetDynamaxBandName(battler.index)
  trainer = battle.pbGetOwnerName(battler.index)
  item    = GameData::Item.get(item).portion_name
  battle.pbSetBattleMechanicUsage(battler.index, "Dynamax", -1)
  pbSEPlay(sprintf("Anim/Lucky Chant"))
  battle.pbDisplayPaused(_INTL("The {1} fully recharged {2}'s {3}!\n{2} can use Dynamax again!", item, trainer, band))
})