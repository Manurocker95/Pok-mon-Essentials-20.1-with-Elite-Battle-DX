#===============================================================================
# Held Items
#===============================================================================
Battle::ItemEffects::DamageCalcFromUser.copy(:GRISEOUSORB, :GRISEOUSCORE)
Battle::ItemEffects::DamageCalcFromUser.copy(:ADAMANTORB, :ADAMANTCRYSTAL)
Battle::ItemEffects::DamageCalcFromUser.copy(:LUSTROUSORB, :LUSTROUSGLOBE)
Battle::ItemEffects::DamageCalcFromUser.copy(:SILKSCARF, :BLANKPLATE)
#===============================================================================
# UseOnPokemon Items
#===============================================================================
ItemHandlers::UseOnPokemon.add(:REVEALGLASS, proc { |item, qty, pkmn, scene|
  if !pkmn.isSpecies?(:TORNADUS) &&
     !pkmn.isSpecies?(:THUNDURUS) &&
     !pkmn.isSpecies?(:LANDORUS) &&
     !pkmn.isSpecies?(:ENAMORUS)
    scene.pbDisplay(_INTL("It had no effect."))
    next false
  elsif pkmn.fainted?
    scene.pbDisplay(_INTL("This can't be used on the fainted Pokémon."))
    next false
  end
  newForm = (pkmn.form == 0) ? 1 : 0
  pkmn.setForm(newForm) {
    scene.pbRefresh
    scene.pbDisplay(_INTL("{1} changed Forme!", pkmn.name))
  }
  next true
})
#===============================================================================
# Hopo Berry
#===============================================================================
Battle::ItemEffects::OnEndOfUsingMove.copy(:LEPPABERRY, :HOPOBERRY)
ItemHandlers::UseOnPokemon.copy(:ETHER, :HOPOBERRY)
ItemHandlers::CanUseInBattle.copy(:ETHER, :HOPOBERRY)
ItemHandlers::BattleUseOnPokemon.copy(:ETHER, :HOPOBERRY)
#===============================================================================
# Poke Ball Items
#===============================================================================
Battle::PokeBallEffects::ModifyCatchRate.add(:HISUIANPOKEBALL, proc { |ball, catchRate, battle, battler|
  next catchRate * 0.75
})

Battle::PokeBallEffects::ModifyCatchRate.add(:HISUIANGREATBALL, proc { |ball, catchRate, battle, battler|
  next catchRate * 1.5
})

Battle::PokeBallEffects::ModifyCatchRate.add(:HISUIANULTRABALL, proc { |ball, catchRate, battle, battler|
  next catchRate * 2.25
})

Battle::PokeBallEffects::ModifyCatchRate.add(:FEATHERBALL, proc { |ball, catchRate, battle, battler|
  # catchRate *= multiplier if battler.pbHasType?(:BUG) || battler.pbHasType?(:WATER)
  next catchRate
})

Battle::PokeBallEffects::ModifyCatchRate.add(:WINGBALL, proc { |ball, catchRate, battle, battler|
  next catchRate * 1.5
})

Battle::PokeBallEffects::ModifyCatchRate.add(:JETBALL, proc { |ball, catchRate, battle, battler|
  next catchRate * 2
})

Battle::PokeBallEffects::ModifyCatchRate.add(:HISUIANHEAVYBALL, proc { |ball, catchRate, battle, battler|
  next catchRate * 1
})

Battle::PokeBallEffects::ModifyCatchRate.add(:LEADENBALL, proc { |ball, catchRate, battle, battler|
  next catchRate * 1.75
})

Battle::PokeBallEffects::ModifyCatchRate.add(:GIGATONBALL, proc { |ball, catchRate, battle, battler|
  next catchRate * 2.5
})

Battle::PokeBallEffects::ModifyCatchRate.add(:STRANGEBALL, proc { |ball, catchRate, battle, battler|
  next catchRate * 0.75
})

Battle::PokeBallEffects::ModifyCatchRate.add(:ORIGINBALL, proc { |ball, catchRate, battle, battler|
  next catchRate * 0.75
})
#===============================================================================
# Multiple Form
#===============================================================================
MultipleForms.register(:GIRATINA, {
  "getForm" => proc { |pkmn|
    next 1 if pkmn.hasItem?(:GRISEOUSORB) || pkmn.hasItem?(:GRISEOUSCORE)
    if $game_map &&
       GameData::MapMetadata.get($game_map.map_id)&.has_flag?("DistortionWorld")
      next 1
    end
    next 0
  }
})
MultipleForms.register(:DIALGA, {
  "getForm" => proc { |pkmn|
    next 1 if pkmn.hasItem?(:ADAMANTCRYSTAL)
    next 0
  }
})
MultipleForms.register(:PALKIA, {
  "getForm" => proc { |pkmn|
    next 1 if pkmn.hasItem?(:LUSTROUSGLOBE)
    next 0
  }
})

#===============================================================================
# Evolution Items
#===============================================================================
GameData::Evolution.register({
  :id            => :TradeSpecies,
  :parameter     => :Species,
  :on_trade_proc => proc { |pkmn, parameter, other_pkmn|
    next false if other_pkmn.nil?
    next pkmn.species == parameter && !other_pkmn.hasItem?(:EVERSTONE)
  }
})

class Pokemon
  alias paldea_check_evolution_on_use_item check_evolution_on_use_item
  def check_evolution_on_use_item(item_used)
    return check_evolution_on_trade(nil) if item_used == :LINKINGCORD
    return paldea_check_evolution_on_use_item(item_used)
  end
end