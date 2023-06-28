#===============================================================================
# Berry Juice
#===============================================================================
# Healing isn't reduced while Dynamaxed.
#-------------------------------------------------------------------------------
Battle::ItemEffects::HPHeal.add(:BERRYJUICE,
  proc { |item, battler, battle, forced|
    next false if !battler.canHeal?
    next false if !forced && battler.hp > battler.totalhp / 2
    itemName = GameData::Item.get(item).name
    PBDebug.log("[Item triggered] Forced consuming of #{itemName}") if forced
    battle.pbCommonAnimation("UseItem", battler) if !forced
    battler.ignore_dynamax = true
    battler.pbRecoverHP(20)
    if forced
      battle.pbDisplay(_INTL("{1}'s HP was restored.", battler.pbThis))
    else
      battle.pbDisplay(_INTL("{1} restored its health using its {2}!", battler.pbThis, itemName))
    end
    next true
  }
)


#===============================================================================
# Oran Berry
#===============================================================================
# Healing isn't reduced while Dynamaxed.
#-------------------------------------------------------------------------------
Battle::ItemEffects::HPHeal.add(:ORANBERRY,
  proc { |item, battler, battle, forced|
    next false if !battler.canHeal?
    next false if !forced && !battler.canConsumePinchBerry?(false)
    amt = 10
    ripening = false
    if battler.hasActiveAbility?(:RIPEN)
      battle.pbShowAbilitySplash(battler, forced)
      amt *= 2
      ripening = true
    end
    battle.pbCommonAnimation("EatBerry", battler) if !forced
    battle.pbHideAbilitySplash(battler) if ripening
    battler.ignore_dynamax = true
    battler.pbRecoverHP(amt)
    itemName = GameData::Item.get(item).name
    if forced
      PBDebug.log("[Item triggered] Forced consuming of #{itemName}")
      battle.pbDisplay(_INTL("{1}'s HP was restored.", battler.pbThis))
    else
      battle.pbDisplay(_INTL("{1} restored a little HP using its {2}!", battler.pbThis, itemName))
    end
    next true
  }
)


#===============================================================================
# Shell Bell
#===============================================================================
# Healing isn't reduced while Dynamaxed.
#-------------------------------------------------------------------------------
Battle::ItemEffects::AfterMoveUseFromUser.add(:SHELLBELL,
  proc { |item, user, targets, move, numHits, battle|
    next if !user.canHeal?
    totalDamage = 0
    targets.each { |b| totalDamage += b.damageState.totalHPLost }
    next if totalDamage <= 0
    user.ignore_dynamax = true
    user.pbRecoverHP(totalDamage / 8)
    battle.pbDisplay(_INTL("{1} restored a little HP using its {2}!",
       user.pbThis, user.itemName))
  }
)


#===============================================================================
# Choice Items
#===============================================================================
# Stat bonuses are not applied to Z-Moves or while Dynamaxed.
#-------------------------------------------------------------------------------
Battle::ItemEffects::DamageCalcFromUser.add(:CHOICEBAND,
  proc { |item, user, target, move, mults, baseDmg, type|
    mults[:base_damage_multiplier] *= 1.5 if move.physicalMove? && !move.powerMove?
  }
)

Battle::ItemEffects::DamageCalcFromUser.add(:CHOICESPECS,
  proc { |item, user, target, move, mults, baseDmg, type|
    mults[:base_damage_multiplier] *= 1.5 if move.specialMove? && !move.powerMove?
  }
)

Battle::ItemEffects::SpeedCalc.add(:CHOICESCARF,
  proc { |item, battler, mult|
    next mult * 1.5 if !battler.dynamax?
  }
)


#===============================================================================
# Red Card
#===============================================================================
# Item triggers, but its effects fail to activate vs Dynamax targets.
#-------------------------------------------------------------------------------
Battle::ItemEffects::AfterMoveUseFromTarget.add(:REDCARD,
  proc { |item, battler, user, move, switched_battlers, battle|
    next if !switched_battlers.empty? || user.fainted?
    newPkmn = battle.pbGetReplacementPokemonIndex(user.index, true)   # Random
    next if newPkmn < 0
    battle.pbCommonAnimation("UseItem", battler)
    battle.pbDisplay(_INTL("{1} held up its {2} against {3}!",
       battler.pbThis, battler.itemName, user.pbThis(true)))
    battler.pbConsumeItem
    if user.dynamax?
      battle.pbDisplay(_INTL("But it failed!"))
      next
    end
    if user.hasActiveAbility?(:SUCTIONCUPS) && !battle.moldBreaker
      battle.pbShowAbilitySplash(user)
      if Battle::Scene::USE_ABILITY_SPLASH
        battle.pbDisplay(_INTL("{1} anchors itself!", user.pbThis))
      else
        battle.pbDisplay(_INTL("{1} anchors itself with {2}!", user.pbThis, user.abilityName))
      end
      battle.pbHideAbilitySplash(user)
      next
    end
    if user.effects[PBEffects::Ingrain]
      battle.pbDisplay(_INTL("{1} anchored itself with its roots!", user.pbThis))
      next
    end
    battle.pbRecallAndReplace(user.index, newPkmn, true)
    battle.pbDisplay(_INTL("{1} was dragged out!", user.pbThis))
    battle.pbClearChoice(user.index)   # Replacement Pokémon does nothing this round
    switched_battlers.push(user.index)
    battle.moldBreaker = false
    battle.pbOnBattlerEnteringBattle(user.index)
  }
)