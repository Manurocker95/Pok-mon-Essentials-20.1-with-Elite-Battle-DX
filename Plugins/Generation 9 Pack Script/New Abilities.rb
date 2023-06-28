#===============================================================================
# Anger Shell
#===============================================================================
Battle::AbilityEffects::AfterMoveUseFromTarget.add(:ANGERSHELL,
  proc { |ability, target, user, move, switched_battlers, battle|
    next if !move.damagingMove?
    next if !target.droppedBelowHalfHP
    [:ATTACK,:SPECIAL_ATTACK,:SPEED].each{|stat|
      target.pbRaiseStatStageByAbility(stat, 1, target) if target.pbCanRaiseStatStage?(stat, target)
    }
    [:DEFENSE,:SPECIAL_DEFENSE].each{|stat|
      target.pbLowerStatStageByAbility(stat, 1, target) if target.pbCanLowerStatStage?(stat, target)
    }
  }
)
#===============================================================================
# Armor Tail
#===============================================================================
Battle::AbilityEffects::MoveBlocking.copy(:DAZZLING, :ARMORTAIL)
#===============================================================================
# Beads of Ruin
#===============================================================================
Battle::AbilityEffects::OnSwitchIn.add(:BEADSOFRUIN,
  proc { |ability, battler, battle, switch_in|
  battle.pbShowAbilitySplash(battler)
  battle.pbDisplay(_INTL("{1}'s Beads of Ruin weakened the Sp. Def of all surrounding Pokémon!", battler.pbThis))
  battle.pbHideAbilitySplash(battler)
  }
)
#===============================================================================
# Commander
#===============================================================================
Battle::AbilityEffects::OnSwitchIn.add(:COMMANDER,
  proc { |ability, battler, battle, switch_in|
    # dondozo = nil
    battler.allAllies.each{|b|
      next if b.species != :DONDOZO
      next if b.effects[PBEffects::CommanderDondozo] >= 0
      battle.pbShowAbilitySplash(battler)
      battle.pbDisplay(_INTL("{1} goes inside the mouth of {2}!", battler.pbThis, b.pbThis(true)))
      battle.pbHideAbilitySplash(battler)
      b.effects[PBEffects::CommanderDondozo] = battler.form
      b.effects[PBEffects::Commander_index] = battler.index
      battler.effects[PBEffects::CommanderTatsugiri] = true
      battler.effects[PBEffects::Commander_index] = b.index
      GameData::Stat.each_main_battle { |stat|
        b.pbRaiseStatStageByAbility(stat.id, 2, b, false) if b.pbCanRaiseStatStage?(stat.id, b)
      }
      break
    }
  }
)

Battle::AbilityEffects::CertainSwitching.add(:COMMANDER,
  proc { |ability, switcher, battle|
    switcher.allAllies.each{|b|
      next if b.species != :TATSUGIRI
      next if b.effects[PBEffects::CommanderTatsugiri]
      battle.pbShowAbilitySplash(b)
      battle.pbDisplay(_INTL("{1} goes inside the mouth of {2}!", b.pbThis, switcher.pbThis(true)))
      battle.pbHideAbilitySplash(b)
      switcher.effects[PBEffects::CommanderDondozo] = b.form
      switcher.effects[PBEffects::Commander_index] = b.index
      b.effects[PBEffects::CommanderTatsugiri] = true
      b.effects[PBEffects::Commander_index] = switcher.index
      GameData::Stat.each_main_battle { |stat|
        switcher.pbRaiseStatStageByAbility(stat.id, 2, switcher,false) if switcher.pbCanRaiseStatStage?(stat.id, switcher)
      }
      break
    }
  }
)
Battle::AbilityEffects::MoveImmunity.add(:COMMANDER,
  proc { |ability, user, target, move, type, battle, show_message|
    next false if !target.effects[PBEffects::CommanderTatsugiri]
    battle.pbDisplay(_INTL("{1} avoided the attack!", target.pbThis)) if show_message
    next true
  }
)
#===============================================================================
# Costar
#===============================================================================
Battle::AbilityEffects::OnSwitchIn.add(:COSTAR,
  proc { |ability, battler, battle, switch_in|
    battler.allAllies.each{|b|
      next if b.index == battler.index
      next if !b.hasAlteredStatStages?
      battle.pbShowAbilitySplash(battler)
      GameData::Stat.each_main_battle { |stat| 
        battler.stages[stat.id] = b.stages[stat.id]
      }
      battle.pbDisplay(_INTL("{1} copied {2}'s stat changes!", battler.pbThis, b.pbThis(true)))
      battle.pbHideAbilitySplash(battler)
      break
    }
  }
)
#===============================================================================
# Cud Chew
#===============================================================================
Battle::AbilityEffects::EndOfRoundEffect.add(:CUDCHEW,
  proc { |ability, battler, battle|
    next if battler.item
    next if !battler.recycleItem
    next if !GameData::Item.get(battler.recycleItem).is_berry?
    next if battler.effects[PBEffects::CudChew] > 0
    battle.pbShowAbilitySplash(battler)
    battler.item = battler.recycleItem
    battler.setRecycleItem(nil)
    battler.pbHeldItemTriggerCheck(battler.item)
    battler.item = nil if battler.item
    # battle.pbDisplay(_INTL("{1} harvested one {2}!", battler.pbThis, battler.itemName))
    battle.pbHideAbilitySplash(battler)
  }
)
#===============================================================================
# Earth Eater
#===============================================================================
Battle::AbilityEffects::MoveImmunity.add(:EARTHEATER,
  proc { |ability, user, target, move, type, battle, show_message|
    next target.pbMoveImmunityHealingAbility(user, move, type, :GROUND, show_message)
  }
)
#===============================================================================
# Electromorphosis
#===============================================================================
Battle::AbilityEffects::OnBeingHit.add(:ELECTROMORPHOSIS,
  proc { |ability, user, target, move, battle|
    next if target.fainted?
    next if target.effects[PBEffects::Charge] > 0
    battle.pbShowAbilitySplash(target)
    target.effects[PBEffects::Charge] = 2
    battle.pbDisplay(_INTL("Being hit by {1} charged {2} with power!", move.name, target.pbThis(true)))
    battle.pbHideAbilitySplash(target)
  }
)
#===============================================================================
# Good As Gold
#===============================================================================
Battle::AbilityEffects::MoveImmunity.add(:GOODASGOLD,
  proc { |ability, user, target, move, type, battle, show_message|
    next false if !move.statusMove?
    next false if target == user
    next false if target.affectedByMoldBreaker?
    if show_message
      battle.pbShowAbilitySplash(target)
      if Battle::Scene::USE_ABILITY_SPLASH
        battle.pbDisplay(_INTL("It doesn't affect {1}...", target.pbThis(true)))
      else
        battle.pbDisplay(_INTL("{1}'s {2} made {3} ineffective!",
           target.pbThis, target.abilityName, move.name))
      end
      battle.pbHideAbilitySplash(target)
    end
    next true
  }
)
#===============================================================================
# Guard Dog - Added on Battler.rb -
#===============================================================================
#===============================================================================
# Hadron Engine
#===============================================================================
Battle::AbilityEffects::OnSwitchIn.add(:HADRONENGINE,
  proc { |ability, battler, battle, switch_in|
    battle.pbShowAbilitySplash(battler)
    if battle.field.terrain == :Electric
      battle.pbDisplay(_INTL("{1} used the Electric Terrain to energize its futuristic engine!", battler.pbThis))
      battle.pbHideAbilitySplash(battler)
      next
    end
    battle.pbDisplay(_INTL("{1} turned the ground into Electric Terrain, energizing its futuristic engine!", battler.pbThis))
    battle.pbStartTerrain(battler, :Electric)
    # NOTE: The ability splash is hidden again in def pbStartTerrain.
  }
)
Battle::AbilityEffects::DamageCalcFromUser.add(:HADRONENGINE,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:attack_multiplier] *= 1.5 if move.specialMove? && user.battle.field.terrain == :Electric
  }
)
#===============================================================================
# Lingering Aroma
#===============================================================================
Battle::AbilityEffects::OnBeingHit.add(:LINGERINGAROMA,
  proc { |ability, user, target, move, battle|
    next if !move.pbContactMove?(user)
    next if user.fainted?
    next if user.unstoppableAbility? || user.ability == ability || user.ability == :MUMMY
    next if user.hasActiveItem?(:ABILITYSHIELD)
    oldAbil = nil
    battle.pbShowAbilitySplash(target) if user.opposes?(target)
    if user.affectedByContactEffect?(Battle::Scene::USE_ABILITY_SPLASH)
      oldAbil = user.ability
      battle.pbShowAbilitySplash(user, true, false) if user.opposes?(target)
      user.ability = ability
      battle.pbReplaceAbilitySplash(user) if user.opposes?(target)
      if Battle::Scene::USE_ABILITY_SPLASH
        battle.pbDisplay(_INTL("A lingering aroma clings to {1}!", user.pbThis(true)))
        # battle.pbDisplay(_INTL("{1}'s Ability became {2}!", user.pbThis, user.abilityName))
      else
        battle.pbDisplay(_INTL("{1}'s Ability became {2} because of {3}!",
           user.pbThis, user.abilityName, target.pbThis(true)))
      end
      battle.pbHideAbilitySplash(user) if user.opposes?(target)
    end
    battle.pbHideAbilitySplash(target) if user.opposes?(target)
    user.pbOnLosingAbility(oldAbil)
    user.pbTriggerAbilityOnGainingIt
  }
)
#===============================================================================
# Mycelium Might
#===============================================================================
Battle::AbilityEffects::PriorityChange.add(:MYCELIUMMIGHT,
  proc { |ability, battler, move, pri|
    if move.statusMove?
      next -1
    end
  }
)
class Battle::Move
  alias myceliummight_pbChangeUsageCounters pbChangeUsageCounters
  def pbChangeUsageCounters(user, specialUsage)
    myceliummight_pbChangeUsageCounters(user, specialUsage)
    @battle.moldBreaker = true if statusMove? && user.hasActiveAbility?(:MYCELIUMMIGHT)
  end
end
#===============================================================================
# Opportunist
# for now its only raise 1 stage
#===============================================================================
Battle::AbilityEffects::CertainStatGain.add(:OPPORTUNIST,
  proc { |ability, battler, battle, stat, user,increment|
    next if !battler.opposes?(user)
    next if battler.statStageAtMax?(stat)
    battle.pbShowAbilitySplash(battler)
    increment.times.each do
      battler.stages[stat] += 1 if !battler.statStageAtMax?(stat)
    end
    battle.pbCommonAnimation("StatUp", battler)
    battle.pbDisplay(_INTL("{1} copied its {2}'s stat changes!", battler.pbThis, user.pbThis(true)))
    battle.pbHideAbilitySplash(battler)
  }
)
#===============================================================================
# Orichalcum Pulse
#===============================================================================
Battle::AbilityEffects::OnSwitchIn.add(:ORICHALCUMPULSE,
  proc { |ability, battler, battle, switch_in|
    battle.pbShowAbilitySplash(battler)
    if [:Sun, :HarshSun].include?(battler.effectiveWeather)
      battle.pbDisplay(_INTL("{1} basked in the sunlight, sending its ancient pulse into a frenzy!", battler.pbThis))
      battle.pbHideAbilitySplash(battler)
      next 
    end
    battle.pbStartWeatherAbility(:Sun, battler)
    battle.pbDisplay(_INTL("{1} turned the sunlight harsh, sending its ancient pulse into a frenzy!", battler.pbThis))
    battle.pbHideAbilitySplash(battler)
  }
)
Battle::AbilityEffects::DamageCalcFromUser.add(:ORICHALCUMPULSE,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:attack_multiplier] *= 1.5 if move.physicalMove? && [:Sun, :HarshSun].include?(user.effectiveWeather)
  }
)
#===============================================================================
# Protosynthesis
#===============================================================================
Battle::AbilityEffects::OnSwitchIn.add(:PROTOSYNTHESIS,
  proc { |ability, battler, battle, switch_in|
    next if ![:Sun, :HarshSun].include?(battler.effectiveWeather) && battler.item != :BOOSTERENERGY
    userStats = battler.plainStats
    highestStatValue = 0
    userStats.each_value { |value| highestStatValue = value if highestStatValue < value }
    # GameData::Stat.each_main_battle do |s|
    [:ATTACK,:DEFENSE,:SPECIAL_ATTACK,:SPECIAL_DEFENSE,:SPEED].each do |s|
      next if userStats[s] < highestStatValue
      battle.pbShowAbilitySplash(battler)
      if battler.item == :BOOSTERENERGY && ![:Sun, :HarshSun].include?(battler.effectiveWeather)
        battler.pbHeldItemTriggered(battler.item)
        battler.effects[PBEffects::BoosterEnergy] = true
        battle.pbDisplay(_INTL("{1} used its Booster Energy to activate Protosynthesis!", battler.pbThis))
      else
        battle.pbDisplay(_INTL("The harsh sunlight activated {1}'s Protosynthesis!", battler.pbThis(true)))
      end
      battler.effects[PBEffects::ParadoxStat] = s
      battle.pbDisplay(_INTL("{1}'s {2} was heightened!", battler.pbThis,GameData::Stat.get(s).name))
      battle.pbHideAbilitySplash(battler)
      break
    end
  }
)
Battle::AbilityEffects::OnSwitchOut.add(:PROTOSYNTHESIS,
  proc { |ability, battler, endOfBattle|
    battler.effects[PBEffects::BoosterEnergy] = false
    battler.effects[PBEffects::ParadoxStat] = nil
  }
)
Battle::AbilityEffects::DamageCalcFromUser.add(:PROTOSYNTHESIS,
  proc { |ability, user, target, move, mults, baseDmg, type|
    if user.effects[PBEffects::ParadoxStat]
      stat = user.effects[PBEffects::ParadoxStat]
      mults[:attack_multiplier] *= 1.3 if (stat == :ATTACK && move.physicalMove?) ||
                                          (stat == :SPECIAL_ATTACK && move.specialMove?)
    end
  }
)
Battle::AbilityEffects::DamageCalcFromTarget.add(:PROTOSYNTHESIS,
  proc { |ability, user, target, move, mults, baseDmg, type|
    if user.effects[PBEffects::ParadoxStat]
      stat = user.effects[PBEffects::ParadoxStat]
      mults[:defense_multiplier] *= 1.3 if (stat == :DEFENSE && move.physicalMove?) ||
                                          (stat == :SPECIAL_DEFENSE && move.specialMove?)
    end
  }
)
Battle::AbilityEffects::SpeedCalc.add(:PROTOSYNTHESIS,
  proc { |ability, battler, mult, ret|
    if battler.effects[PBEffects::ParadoxStat]
      stat = battler.effects[PBEffects::ParadoxStat]
      next stat == :SPEED ? 1.5 : 0
    end
  }
)
#===============================================================================
# Purifying Salt
#===============================================================================
Battle::AbilityEffects::StatusImmunity.add(:PURIFYINGSALT,
  proc { |ability, battler, status|
    next true
  }
)
Battle::AbilityEffects::DamageCalcFromTarget.add(:PURIFYINGSALT,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:final_damage_multiplier] /= 2 if move.calcType == :GHOST
  }
)
#===============================================================================
# Quark Drive
#===============================================================================
Battle::AbilityEffects::OnSwitchIn.add(:QUARKDRIVE,
  proc { |ability, battler, battle, switch_in|
    next if battle.field.terrain != :Electric && battler.item != :BOOSTERENERGY
    userStats = battler.plainStats
    highestStatValue = 0
    userStats.each_value { |value| highestStatValue = value if highestStatValue < value }
    # GameData::Stat.each_main_battle do |s|
    [:ATTACK,:DEFENSE,:SPECIAL_ATTACK,:SPECIAL_DEFENSE,:SPEED].each do |s|
      next if userStats[s] < highestStatValue
      battle.pbShowAbilitySplash(battler)
      if battler.item == :BOOSTERENERGY && !battle.field.terrain == :Electric
        battler.pbHeldItemTriggered(battler.item)
        battler.effects[PBEffects::BoosterEnergy] = true
        battle.pbDisplay(_INTL("{1} used its Booster Energy to activate its Quark Drive!", battler.pbThis))
      else
        battle.pbDisplay(_INTL("The Electric Terrain activated {1}'s Quark Drive!", battler.pbThis(true)))
      end
      battler.effects[PBEffects::ParadoxStat] = s
      battle.pbDisplay(_INTL("{1}'s {2} was heightened!", battler.pbThis,GameData::Stat.get(s).name))
      battle.pbHideAbilitySplash(battler)
      break
    end
  }
)
Battle::AbilityEffects::OnTerrainChange.add(:QUARKDRIVE,
proc { |ability, battler, battle, switch_in|
    next if battle.field.terrain == :Electric
    next if battler.effects[PBEffects::BoosterEnergy]
    if battler.item == :BOOSTERENERGY
      battler.pbHeldItemTriggered(battler.item)
      battle.pbDisplay(_INTL("{1} used its Booster Energy to activate its Quark Drive!", battler.pbThis))
      next
    end
    battle.pbDisplay(_INTL("The effects of {1}'s Quark Drive wore off!", battler.pbThis(true)))
    battler.effects[PBEffects::ParadoxStat] = nil
  }
)

Battle::AbilityEffects::OnSwitchOut.copy(:PROTOSYNTHESIS, :QUARKDRIVE)
Battle::AbilityEffects::DamageCalcFromUser.copy(:PROTOSYNTHESIS, :QUARKDRIVE)
Battle::AbilityEffects::DamageCalcFromTarget.copy(:PROTOSYNTHESIS, :QUARKDRIVE)
Battle::AbilityEffects::SpeedCalc.copy(:PROTOSYNTHESIS, :QUARKDRIVE)
#===============================================================================
# Rocky Payload
#===============================================================================
Battle::AbilityEffects::DamageCalcFromUser.add(:ROCKYPAYLOAD,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:attack_multiplier] *= 1.5 if type == :ROCK
  }
)
#===============================================================================
# Seed Sower
#===============================================================================
Battle::AbilityEffects::OnBeingHit.add(:SEEDSOWER,
  proc { |ability, user, target, move, battle|
    next if !move.damagingMove?
    next if battle.field.terrain == :Grassy
    battle.pbShowAbilitySplash(target)
    battle.pbDisplay(_INTL("Grass grew to cover the battlefield!"))
    battle.pbStartTerrain(target, :Grassy)
  }
)
#===============================================================================
# Sharpness
#===============================================================================
class Battle::Move
  def slicingMove?;      return @flags.any? { |f| f[/^Slicing$/i] }; end
end
# Aerial Ace, Air Cutter, Air Slash, Aqua Cutter, Behemoth Blade, Ceaseless Edge,
# Cross Poison, Cut, Fury Cutter, Kowtow Cleave, Leaf Blade, Night Slash, Psycho Cut, 
# Razor Leaf, Razor Shell, Sacred Sword, Slash, Solar Blade, Stone Axe, X-Scissor
Battle::AbilityEffects::DamageCalcFromUser.add(:SHARPNESS,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:base_damage_multiplier] *= 1.5 if move.slicingMove?
  }
)

#===============================================================================
# Supreme Overlord
#===============================================================================
class Game_Temp
  attr_accessor :fainted_member
end

Battle::AbilityEffects::DamageCalcFromUser.add(:SUPREMEOVERLORD,
  proc { |ability, user, target, move, mults, baseDmg, type|
    next if user.effects[PBEffects::SupremeOverlord] <= 0
    mult = 1
    mult += 0.1 * user.effects[PBEffects::SupremeOverlord]
    mults[:base_damage_multiplier] *= mult
  }
)
Battle::AbilityEffects::OnSwitchIn.add(:SUPREMEOVERLORD,
  proc { |ability, battler, battle, switch_in|
  numFainted = battle.getFaintedCount(battler)
  numFainted = 5 if numFainted > 5
  next if numFainted <= 0
  battle.pbShowAbilitySplash(battler)
  battle.pbDisplay(_INTL("{1} gained strength from the fallen!", battler.pbThis))
  battler.effects[PBEffects::SupremeOverlord] = numFainted
  battle.pbHideAbilitySplash(battler)
  }
)
#===============================================================================
# Sword of Ruin
#===============================================================================
Battle::AbilityEffects::OnSwitchIn.add(:SWORDOFRUIN,
  proc { |ability, battler, battle, switch_in|
  battle.pbShowAbilitySplash(battler)
  battle.pbDisplay(_INTL("{1}'s Tablets of Ruin weakened the Defense of all surrounding Pokémon!", battler.pbThis))
  battle.pbHideAbilitySplash(battler)
  }
)
#===============================================================================
# Tablets of Ruin
#===============================================================================
Battle::AbilityEffects::OnSwitchIn.add(:TABLETSOFRUIN,
  proc { |ability, battler, battle, switch_in|
    battle.pbShowAbilitySplash(battler)
    battle.pbDisplay(_INTL("{1}'s Tablets of Ruin weakened the Attack of all surrounding Pokémon!", battler.pbThis))
    battle.pbHideAbilitySplash(battler)
  }
)
#===============================================================================
# Thermal Exchange
#===============================================================================
Battle::AbilityEffects::OnBeingHit.add(:THERMALEXCHANGE,
  proc { |ability, user, target, move, battle|
    next if move.calcType != :FIRE
    target.pbRaiseStatStageByAbility(:ATTACK, 1, target)
  }
)
Battle::AbilityEffects::StatusImmunity.add(:THERMALEXCHANGE,
  proc { |ability, battler, status|
    next true if status == :BURN
  }
)
#===============================================================================
# Toxic Debris
#===============================================================================
Battle::AbilityEffects::OnBeingHit.add(:TOXICDEBRIS,
  proc { |ability, user, target, move, battle|
    # next if !move.pbContactMove?(user)
    next if !move.physicalMove?
    next if user.pbOwnSide.effects[PBEffects::ToxicSpikes] >= 2
    battle.pbShowAbilitySplash(target)

    user.pbOwnSide.effects[PBEffects::ToxicSpikes] += 1
    # battle.pbAnimation("SPIKES", target, user)
    battle.pbDisplay(_INTL("Poison spikes were scattered on the ground all around {1}!",
                            target.pbOpposingTeam(true)))
    battle.pbHideAbilitySplash(target)
  }
)
#===============================================================================
# Vessel of Ruin
#===============================================================================
Battle::AbilityEffects::OnSwitchIn.add(:VESSELOFRUIN,
  proc { |ability, battler, battle, switch_in|
    battle.pbShowAbilitySplash(battler)
    battle.pbDisplay(_INTL("{1}'s Vessel of Ruin weakened the Sp. Atk of all surrounding Pokémon!", battler.pbThis))
    battle.pbHideAbilitySplash(battler)
  }
)
#===============================================================================
# Well-Baked Body
#===============================================================================
Battle::AbilityEffects::MoveImmunity.add(:WELLBAKEDBODY,
  proc { |ability, user, target, move, type, battle, show_message|
    next target.pbMoveImmunityStatRaisingAbility(user, move, type,
       :FIRE, :DEFENSE, 2, show_message)
  }
)
#===============================================================================
# Wind Power
#===============================================================================
class Battle::Move
  def windMove?;      return @flags.any? { |f| f[/^Wind$/i] }; end
end
# Air Cutter, Bleakwind Storm, Blizzard, Fairy Wind, Gust, Heat Wave, Hurricane, 
# Icy Wind, Petal Blizzard, Sandsear Storm, Sandstorm, Springtide Storm, Tailwind, 
# Twister, Whirlwind, Wildbolt Storm
Battle::AbilityEffects::OnBeingHit.add(:WINDPOWER,
  proc { |ability, user, target, move, battle|
    next if target.fainted?   
    next if !move.windMove?
    next if target.effects[PBEffects::Charge] > 0
    battle.pbShowAbilitySplash(target)
    target.effects[PBEffects::Charge] = 2
    battle.pbDisplay(_INTL("Being hit by {1} charged {2} with power!", move.name, target.pbThis(true)))
    battle.pbHideAbilitySplash(target)
  }
)
#===============================================================================
# Wind Rider
#===============================================================================
Battle::AbilityEffects::MoveImmunity.add(:WINDRIDER,
  proc { |ability, user, target, move, type, battle, show_message|
    next false if !move.windMove?
    if show_message
      battle.pbShowAbilitySplash(target)
      if Battle::Scene::USE_ABILITY_SPLASH
        battle.pbDisplay(_INTL("It doesn't affect {1}...", target.pbThis(true)))
      else
        battle.pbDisplay(_INTL("{1}'s {2} made {3} ineffective!",
           target.pbThis, target.abilityName, move.name))
      end
      if target.pbCanRaiseStatStage?(:ATTACK, target)
        target.pbRaiseStatStageByAbility(:ATTACK, 1, target, false)
      end
      battle.pbHideAbilitySplash(target)
    end
    next true
  }
)
Battle::AbilityEffects::OnSwitchIn.add(:WINDRIDER,
  proc { |ability, battler, battle, switch_in|
    next if battler.pbOwnSide.effects[PBEffects::Tailwind] <= 0
    next if !battler.pbCanRaiseStatStage?(:ATTACK, battler, self)
    battle.pbShowAbilitySplash(battler, true)
    battler.pbRaiseStatStage(:ATTACK, 1, battler)
    battle.pbHideAbilitySplash(battler)
  }
)
#===============================================================================
# Zero To Hero (Palafin)
#===============================================================================
MultipleForms.register(:PALAFIN, {
  "getFormOnLeavingBattle" => proc { |pkmn, battle, usedInBattle, endBattle|
    next if !endBattle || !usedInBattle || !pkmn.fainted?
    next 0 
  }
})
Battle::AbilityEffects::OnSwitchOut.add(:ZEROTOHERO,
  proc { |ability, battler, endOfBattle|
    next if battler.form == 1
    PBDebug.log("[Ability triggered] #{battler.pbThis}'s #{battler.abilityName}")
    battler.pbChangeForm(1,"")
  }
)
Battle::AbilityEffects::OnSwitchIn.add(:ZEROTOHERO,
  proc { |ability, battler, battle, switch_in|
    next if battler.form == 0
    next if battle.isBattlerActivedAbility?(battler)
    battle.pbShowAbilitySplash(battler)
    battle.pbDisplay(_INTL("{1} underwent a heroic transformation!", battler.pbThis))
    battle.pbHideAbilitySplash(battler)
    battle.setBattlerActivedAbility(battler)
  }
)
