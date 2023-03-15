# Adding new trigger "CertainStatGain" in raiseStat function
# Adding new trigger "StatLossImmunity" in lowerStat function
# Replace @battle.moldBreaker to affectedByMoldBreaker

class Battle::Battler
  def pbItemCertainStatGainCheck(user, stat, increment = 1, item_to_use = nil)
    return if fainted?
    return if !item_to_use && !itemActive?
    itm = item_to_use || self.item
    if Battle::ItemEffects.triggerCertainStatGain(itm, self, stat, user, increment, @battle, !item_to_use)
      pbHeldItemTriggered(itm, item_to_use.nil?, false)
    end
  end
  #=============================================================================
  # Increase stat stages
  #=============================================================================
  def pbRaiseStatStage(stat, increment, user, showAnim = true, ignoreContrary = false)
    # Contrary
    if hasActiveAbility?(:CONTRARY) && !ignoreContrary && !affectedByMoldBreaker?
      return pbLowerStatStage(stat, increment, user, showAnim, true)
    end
    # Perform the stat stage change
    increment = pbRaiseStatStageBasic(stat, increment, ignoreContrary)
    return false if increment <= 0
    # Stat up animation and message
    @battle.pbCommonAnimation("StatUp", self) if showAnim
    arrStatTexts = [
      _INTL("{1}'s {2} rose!", pbThis, GameData::Stat.get(stat).name),
      _INTL("{1}'s {2} rose sharply!", pbThis, GameData::Stat.get(stat).name),
      _INTL("{1}'s {2} rose drastically!", pbThis, GameData::Stat.get(stat).name)
    ]
    @battle.pbDisplay(arrStatTexts[[increment - 1, 2].min])
    # Trigger abilities upon stat gain
    if abilityActive?
      Battle::AbilityEffects.triggerOnStatGain(self.ability, self, stat, user, increment)
    end
    # Trigger other's ability or item upon stat gain
    @battle.allOtherSideBattlers(user.index).each do |b|
      b.pbItemCertainStatGainCheck(user, stat, increment)
      Battle::AbilityEffects.triggerCertainStatGain(b.ability, b, @battle, stat, user, increment) if b.abilityActive?
    end
    return true
  end

  def pbRaiseStatStageByCause(stat, increment, user, cause, showAnim = true, ignoreContrary = false)
    # Contrary
    if hasActiveAbility?(:CONTRARY) && !ignoreContrary && !affectedByMoldBreaker?
      return pbLowerStatStageByCause(stat, increment, user, cause, showAnim, true)
    end
    # Perform the stat stage change
    increment = pbRaiseStatStageBasic(stat, increment, ignoreContrary)
    return false if increment <= 0
    # Stat up animation and message
    @battle.pbCommonAnimation("StatUp", self) if showAnim
    if user.index == @index
      arrStatTexts = [
        _INTL("{1}'s {2} raised its {3}!", pbThis, cause, GameData::Stat.get(stat).name),
        _INTL("{1}'s {2} sharply raised its {3}!", pbThis, cause, GameData::Stat.get(stat).name),
        _INTL("{1}'s {2} drastically raised its {3}!", pbThis, cause, GameData::Stat.get(stat).name)
      ]
    else
      arrStatTexts = [
        _INTL("{1}'s {2} raised {3}'s {4}!", user.pbThis, cause, pbThis(true), GameData::Stat.get(stat).name),
        _INTL("{1}'s {2} sharply raised {3}'s {4}!", user.pbThis, cause, pbThis(true), GameData::Stat.get(stat).name),
        _INTL("{1}'s {2} drastically raised {3}'s {4}!", user.pbThis, cause, pbThis(true), GameData::Stat.get(stat).name)
      ]
    end
    @battle.pbDisplay(arrStatTexts[[increment - 1, 2].min])
    # Trigger abilities upon stat gain
    if abilityActive?
      Battle::AbilityEffects.triggerOnStatGain(self.ability, self, stat, user,increment)
    end
    # Trigger other's ability or item upon stat gain
    @battle.allOtherSideBattlers(user.index).each do |b|
      b.pbItemCertainStatGainCheck(user, stat, increment)
      Battle::AbilityEffects.triggerCertainStatGain(b.ability, b, @battle, stat, user, increment) if b.abilityActive?
    end
    return true
  end

  #=============================================================================
  # Decrease stat stages
  #=============================================================================
  def statStageAtMin?(stat)
    return @stages[stat] <= -6
  end

  def pbCanLowerStatStage?(stat, user = nil, move = nil, showFailMsg = false,
                           ignoreContrary = false, ignoreMirrorArmor = false)
    return false if fainted?
    if !affectedByMoldBreaker?
      # Contrary
      if hasActiveAbility?(:CONTRARY) && !ignoreContrary
        return pbCanRaiseStatStage?(stat, user, move, showFailMsg, true)
      end
      # Mirror Armor
      if hasActiveAbility?(:MIRRORARMOR) && !ignoreMirrorArmor &&
         user && user.index != @index && !statStageAtMin?(stat)
        return true
      end
    end
    if !user || user.index != @index   # Not self-inflicted
      if @effects[PBEffects::Substitute] > 0 &&
         (ignoreMirrorArmor || !(move && move.ignoresSubstitute?(user)))
        @battle.pbDisplay(_INTL("{1} is protected by its substitute!", pbThis)) if showFailMsg
        return false
      end
      if pbOwnSide.effects[PBEffects::Mist] > 0 &&
         !(user && user.hasActiveAbility?(:INFILTRATOR))
        @battle.pbDisplay(_INTL("{1} is protected by Mist!", pbThis)) if showFailMsg
        return false
      end
      if abilityActive?
        return false if !affectedByMoldBreaker? && Battle::AbilityEffects.triggerStatLossImmunity(
          self.ability, self, stat, @battle, showFailMsg
        )
        return false if Battle::AbilityEffects.triggerStatLossImmunityNonIgnorable(
          self.ability, self, stat, @battle, showFailMsg
        )
      end
      if itemActive?
        return false if Battle::ItemEffects.triggerStatLossImmunity(
          self.item, self, stat, @battle, showFailMsg
        )
      end
      if !affectedByMoldBreaker?
        allAllies.each do |b|
          next if !b.abilityActive?
          return false if Battle::AbilityEffects.triggerStatLossImmunityFromAlly(
            b.ability, b, self, stat, @battle, showFailMsg
          )
        end
      end
    end
    # Check the stat stage
    if statStageAtMin?(stat)
      if showFailMsg
        @battle.pbDisplay(_INTL("{1}'s {2} won't go any lower!",
                                pbThis, GameData::Stat.get(stat).name))
      end
      return false
    end
    return true
  end

  def pbLowerAttackStatStageIntimidate(user)
    return false if fainted?
    # NOTE: Substitute intentionally blocks Intimidate even if self has Contrary.
    if @effects[PBEffects::Substitute] > 0
      if Battle::Scene::USE_ABILITY_SPLASH
        @battle.pbDisplay(_INTL("{1} is protected by its substitute!", pbThis))
      else
        @battle.pbDisplay(_INTL("{1}'s substitute protected it from {2}'s {3}!",
                                pbThis, user.pbThis(true), user.abilityName))
      end
      return false
    end
    if Settings::MECHANICS_GENERATION >= 8 && hasActiveAbility?([:OBLIVIOUS, :OWNTEMPO, :INNERFOCUS, :SCRAPPY])
      @battle.pbShowAbilitySplash(self)
      if Battle::Scene::USE_ABILITY_SPLASH
        @battle.pbDisplay(_INTL("{1}'s {2} cannot be lowered!", pbThis, GameData::Stat.get(:ATTACK).name))
      else
        @battle.pbDisplay(_INTL("{1}'s {2} prevents {3} loss!", pbThis, abilityName,
                                GameData::Stat.get(:ATTACK).name))
      end
      @battle.pbHideAbilitySplash(self)
      return false
    end
    # Guard Dog
    if hasActiveAbility?(:GUARDDOG)
      @battle.pbShowAbilitySplash(self)
      if Battle::Scene::USE_ABILITY_SPLASH
        pbRaiseStatStageByCause(:ATTACK, 1, self, abilityName)#pbRaiseStatStageByAbility(:ATTACK, 1, user, false)
      end
      @battle.pbHideAbilitySplash(self)
      return false
    end
    if Battle::Scene::USE_ABILITY_SPLASH
      return pbLowerStatStageByAbility(:ATTACK, 1, user, false)
    end
    # NOTE: These checks exist to ensure appropriate messages are shown if
    #       Intimidate is blocked somehow (i.e. the messages should mention the
    #       Intimidate ability by name).
    if !hasActiveAbility?(:CONTRARY)
      if pbOwnSide.effects[PBEffects::Mist] > 0
        @battle.pbDisplay(_INTL("{1} is protected from {2}'s {3} by Mist!",
                                pbThis, user.pbThis(true), user.abilityName))
        return false
      end
      if abilityActive? &&
         (Battle::AbilityEffects.triggerStatLossImmunity(self.ability, self, :ATTACK, @battle, false) ||
          Battle::AbilityEffects.triggerStatLossImmunityNonIgnorable(self.ability, self, :ATTACK, @battle, false))
        @battle.pbDisplay(_INTL("{1}'s {2} prevented {3}'s {4} from working!",
                                pbThis, abilityName, user.pbThis(true), user.abilityName))
        return false
      end
      if itemActive? && Battle::ItemEffects.triggerStatLossImmunity(self.item, self, stat, @battle, false)
        return false
      end
      allAllies.each do |b|
        next if !b.abilityActive?
        if Battle::AbilityEffects.triggerStatLossImmunityFromAlly(b.ability, b, self, :ATTACK, @battle, false)
          @battle.pbDisplay(_INTL("{1} is protected from {2}'s {3} by {4}'s {5}!",
                                  pbThis, user.pbThis(true), user.abilityName, b.pbThis(true), b.abilityName))
          return false
        end
      end
    end
    return false if !pbCanLowerStatStage?(:ATTACK, user)
    return pbLowerStatStageByCause(:ATTACK, 1, user, user.abilityName)
  end
end