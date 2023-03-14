# Clear Amulet
Battle::ItemEffects::StatLossImmunity.add(:CLEARAMULET,
  proc { |item, battler, stat, battle, showMessages|
    if showMessages
      itemName = GameData::Item.get(item).name
      battle.pbDisplay(_INTL("{1}'s {2} prevents stat loss!", battler.pbThis, itemName))
    end
    next true
  }
)

# Mirror Herb
Battle::ItemEffects::CertainStatGain.add(:MIRRORHERB,
  proc { |item, battler, stat, user, increment, battle, forced|
    next false if !battler.opposes?(user)
    next false if battler.statStageAtMax?(stat)
    increment.times.each do
      battler.stages[stat] += 1 if !battler.statStageAtMax?(stat)
    end
    itemName = GameData::Item.get(item).name
    PBDebug.log("[Item triggered] #{battler.pbThis}'s #{itemName}") if forced
    battle.pbCommonAnimation("UseItem", battler)# if !forced
    battle.pbCommonAnimation("StatUp", battler)
    battle.pbDisplay(_INTL("{1} copied {2}'s stat changes using its {3}!", battler.pbThis,user.pbThis(true),itemName))
    next true
  }
)

# Punching Glove
Battle::ItemEffects::DamageCalcFromUser.add(:PUNCHINGGLOVE,
  proc { |item, user, target, move, mults, baseDmg, type|
    next if user.hasActiveAbility?(:IRONFIST)
    mults[:base_damage_multiplier] *= 1.1 if move.punchingMove?
  }
)

# Scroll of Waters
ItemHandlers::UseOnPokemon.add(:SCROLLOFWATERS,
  proc { |item, qty, pkmn, scene|
    if pkmn.shadowPokemon?
      scene.pbDisplay(_INTL("It won't have any effect."))
      next false
    end
    newspecies = pkmn.check_evolution_on_use_item(item)
    if newspecies
      pkmn.form = 1 if pkmn.species == :KUBFU
      pbFadeOutInWithMusic {
        evo = PokemonEvolutionScene.new
        evo.pbStartScreen(pkmn, newspecies)
        evo.pbEvolution(false)
        evo.pbEndScreen
        if scene.is_a?(PokemonPartyScreen)
          scene.pbRefreshAnnotations(proc { |p| !p.check_evolution_on_use_item(item).nil? })
          scene.pbRefresh
        end
      }
      next true
    end
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  }
)