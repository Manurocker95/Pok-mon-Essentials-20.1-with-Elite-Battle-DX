#===============================================================================
# Battler
#===============================================================================
class Battle::Battler
  # Returns the active types of this Pokémon. The array should not include the
  # same type more than once, and should not include any invalid types.
  alias paldea_pbTypes pbTypes
  def pbTypes(withType3 = false)
    ret = paldea_pbTypes
    # Double Shock erases the Electric-type.
    ret.delete(:ELECTRIC) if @effects[PBEffects::DoubleShock]
    return ret
  end
  #=============================================================================
  # Change type
  #=============================================================================
  alias paldea_pbChangeTypes pbChangeTypes
  def pbChangeTypes(newType)
    paldea_pbChangeTypes(newType)
    @effects[PBEffects::DoubleShock]  = false
  end

  alias paldea_pbResetTypes pbResetTypes
  def pbResetTypes
    paldea_pbResetTypes
    @effects[PBEffects::DoubleShock]  = false
  end

  # Add tatsugiri and dondozo
  def trappedInBattle?
    return true if @effects[PBEffects::Trapping] > 0
    return true if @effects[PBEffects::MeanLook] >= 0
    return true if @effects[PBEffects::JawLock] >= 0
    return true if @battle.allBattlers.any? { |b| b.effects[PBEffects::JawLock] == @index }
    return true if @effects[PBEffects::Octolock] >= 0
    return true if @effects[PBEffects::Ingrain]
    return true if @effects[PBEffects::NoRetreat]
    return true if @battle.field.effects[PBEffects::FairyLock] > 0
    return true if @effects[PBEffects::CommanderDondozo] >= 0
    return true if @effects[PBEffects::CommanderTatsugiri]
    return false
  end

  # Applies to both losing self's ability (i.e. being replaced by another) and
  # having self's ability be negated.
  def unstoppableAbility?(abil = nil)
    abil = @ability_id if !abil
    abil = GameData::Ability.try_get(abil)
    return false if !abil
    ability_blacklist = [
      # Form-changing abilities
      :BATTLEBOND,
      :DISGUISE,
#      :FLOWERGIFT,                                        # This can be stopped
#      :FORECAST,                                          # This can be stopped
      :GULPMISSILE,
      :ICEFACE,
      :MULTITYPE,
      :POWERCONSTRUCT,
      :SCHOOLING,
      :SHIELDSDOWN,
      :STANCECHANGE,
      :ZENMODE,
      # Abilities intended to be inherent properties of a certain species
      :ASONECHILLINGNEIGH,
      :ASONEGRIMNEIGH,
      :COMATOSE,
      :RKSSYSTEM,
      :COMMANDER,
      :ZEROTOHERO
    ]
    return ability_blacklist.include?(abil.id)
  end

  # Add a function for using Booster energy
  alias proto_pbCheckFormOnWeatherChange pbCheckFormOnWeatherChange
  def pbCheckFormOnWeatherChange(ability_changed = false)
    ret = proto_pbCheckFormOnWeatherChange(ability_changed)
    return ret if ret == false
    if hasActiveAbility?(:PROTOSYNTHESIS) && !@effects[PBEffects::BoosterEnergy] && @effects[PBEffects::ParadoxStat]
      if @item == :BOOSTERENERGY
        pbHeldItemTriggered(@item)
        @effects[PBEffects::BoosterEnergy] = true
        @battle.pbDisplay(_INTL("{1} used its Booster Energy to activate Protosynthesis!", pbThis))
      else
        @battle.pbDisplay(_INTL("The effects of {1}'s Protosynthesis wore off!", pbThis(true)))
        @effects[PBEffects::ParadoxStat] = nil
      end
    end
  end
  
  alias paldea_pbInitEffects pbInitEffects
  def pbInitEffects(batonPass)
    paldea_pbInitEffects(batonPass)
    @effects[PBEffects::CudChew]              = 0
    @effects[PBEffects::Comeuppance]          = -1
    @effects[PBEffects::ComeuppanceTarget]    = -1
    @effects[PBEffects::ParadoxStat]          = nil
    @effects[PBEffects::BoosterEnergy]        = false
    @effects[PBEffects::DoubleShock]          = false
    @effects[PBEffects::GlaiveRush]           = 0
    @effects[PBEffects::CommanderTatsugiri]   = false
    @effects[PBEffects::CommanderDondozo]     = -1
    @effects[PBEffects::Commander_index]      = -1
    @effects[PBEffects::SaltCure]             = false
    @effects[PBEffects::SupremeOverlord]      = 0
  end

  # When transform copy target rage fist counter
  alias ragefist_pbTransform pbTransform
  def pbTransform(target)
    ragefist_pbTransform(target)
    @battle.addBattlerHit(self,@battle.getBattlerHit(target))
  end

  alias paldea_pbFaint pbFaint
  def pbFaint(showMessage = true)
    if !fainted?
      PBDebug.log("!!!***Can't faint with HP greater than 0")
      return
    end
    return if @fainted   # Has already fainted properly
    # Commander Effect
    dondozo = []
    if self.species == :DONDOZO && @effects[PBEffects::CommanderDondozo] >= 0 # Dondozo faint
      dondozo = [self.index,@effects[PBEffects::Commander_index],true]
    elsif self.species == :TATSUGIRI && @effects[PBEffects::CommanderTatsugiri] # Tatsugiri faint
      dondozo = [@effects[PBEffects::Commander_index],self.index,false]
    end
    #
    paldea_pbFaint(showMessage)
    @battle.addFaintedCount(self)
    if !dondozo.empty?
      if dondozo[2] # Dondozo faint
        @battle.battlers[dondozo[1]].effects[PBEffects::CommanderTatsugiri] = false
        @battle.battlers[dondozo[1]].effects[PBEffects::Commander_index] = -1
      else # Tatsugiri faint
        @battle.battlers[dondozo[0]].effects[PBEffects::CommanderDondozo] = -1
        @battle.battlers[dondozo[0]].effects[PBEffects::Commander_index] = -1
      end
      @battle.pbDisplay(_INTL("{1} comes out of {2}'s mouth!", @battle.battlers[dondozo[1]].pbThis, @battle.battlers[dondozo[0]].pbThis(true))) if showMessage
    end
  end

  # Add Cud Chew counter
  def pbConsumeItem(recoverable = true, symbiosis = true, belch = true)
    PBDebug.log("[Item consumed] #{pbThis} consumed its held #{itemName}")
    if recoverable
      setRecycleItem(@item_id)
      @effects[PBEffects::CudChew] = 1
      @effects[PBEffects::PickupItem] = @item_id
      @effects[PBEffects::PickupUse]  = @battle.nextPickupUse
    end
    setBelched if belch && self.item.is_berry?
    pbRemoveItem
    pbSymbiosis if symbiosis
  end

  # add glaiverush and silk trap effect
  def pbSuccessCheckAgainstTarget(move, user, target, targets)
    show_message = move.pbShowFailMessages?(targets)
    typeMod = move.pbCalcTypeMod(move.calcType, user, target)
    target.damageState.typeMod = typeMod
    # Two-turn attacks can't fail here in the charging turn
    return true if user.effects[PBEffects::TwoTurnAttack]
    # Can't fail after target use Glaive Rush
    return true if user.effects[PBEffects::GlaiveRush] > 0
    # Move-specific failures
    return false if move.pbFailsAgainstTarget?(user, target, show_message)
    # Immunity to priority moves because of Psychic Terrain
    if @battle.field.terrain == :Psychic && target.affectedByTerrain? && target.opposes?(user) &&
       @battle.choices[user.index][4] > 0   # Move priority saved from pbCalculatePriority
      @battle.pbDisplay(_INTL("{1} surrounds itself with psychic terrain!", target.pbThis)) if show_message
      return false
    end
    # Crafty Shield
    if target.pbOwnSide.effects[PBEffects::CraftyShield] && user.index != target.index &&
       move.statusMove? && !move.pbTarget(user).targets_all
      if show_message
        @battle.pbCommonAnimation("CraftyShield", target)
        @battle.pbDisplay(_INTL("Crafty Shield protected {1}!", target.pbThis(true)))
      end
      target.damageState.protected = true
      @battle.successStates[user.index].protected = true
      return false
    end
    if !(user.hasActiveAbility?(:UNSEENFIST) && move.contactMove?)
      # Wide Guard
      if target.pbOwnSide.effects[PBEffects::WideGuard] && user.index != target.index &&
         move.pbTarget(user).num_targets > 1 &&
         (Settings::MECHANICS_GENERATION >= 7 || move.damagingMove?)
        if show_message
          @battle.pbCommonAnimation("WideGuard", target)
          @battle.pbDisplay(_INTL("Wide Guard protected {1}!", target.pbThis(true)))
        end
        target.damageState.protected = true
        @battle.successStates[user.index].protected = true
        return false
      end
      if move.canProtectAgainst?
        # Quick Guard
        if target.pbOwnSide.effects[PBEffects::QuickGuard] &&
           @battle.choices[user.index][4] > 0   # Move priority saved from pbCalculatePriority
          if show_message
            @battle.pbCommonAnimation("QuickGuard", target)
            @battle.pbDisplay(_INTL("Quick Guard protected {1}!", target.pbThis(true)))
          end
          target.damageState.protected = true
          @battle.successStates[user.index].protected = true
          return false
        end
        # Protect
        if target.effects[PBEffects::Protect]
          if show_message
            @battle.pbCommonAnimation("Protect", target)
            @battle.pbDisplay(_INTL("{1} protected itself!", target.pbThis))
          end
          target.damageState.protected = true
          @battle.successStates[user.index].protected = true
          return false
        end
        # King's Shield
        if target.effects[PBEffects::KingsShield] && move.damagingMove?
          if show_message
            @battle.pbCommonAnimation("KingsShield", target)
            @battle.pbDisplay(_INTL("{1} protected itself!", target.pbThis))
          end
          target.damageState.protected = true
          @battle.successStates[user.index].protected = true
          if move.pbContactMove?(user) && user.affectedByContactEffect? &&
             user.pbCanLowerStatStage?(:ATTACK, target)
            user.pbLowerStatStage(:ATTACK, (Settings::MECHANICS_GENERATION >= 8) ? 1 : 2, target)
          end
          return false
        end
        # Spiky Shield
        if target.effects[PBEffects::SpikyShield]
          if show_message
            @battle.pbCommonAnimation("SpikyShield", target)
            @battle.pbDisplay(_INTL("{1} protected itself!", target.pbThis))
          end
          target.damageState.protected = true
          @battle.successStates[user.index].protected = true
          if move.pbContactMove?(user) && user.affectedByContactEffect?
            @battle.scene.pbDamageAnimation(user)
            user.pbReduceHP(user.totalhp / 8, false)
            @battle.pbDisplay(_INTL("{1} was hurt!", user.pbThis))
            user.pbItemHPHealCheck
          end
          return false
        end
        # Silk Trap
        if target.effects[PBEffects::SilkTrap] && move.damagingMove?
          if show_message
            @battle.pbCommonAnimation("SilkTrap", target)
            @battle.pbDisplay(_INTL("{1} protected itself!", target.pbThis))
          end
          target.damageState.protected = true
          @battle.successStates[user.index].protected = true
          if move.pbContactMove?(user) && user.affectedByContactEffect? &&
            user.pbCanLowerStatStage?(:SPEED, target)
             user.pbLowerStatStage(:SPEED, 1, target)
          end
          return false
        end
        # Baneful Bunker
        if target.effects[PBEffects::BanefulBunker]
          if show_message
            @battle.pbCommonAnimation("BanefulBunker", target)
            @battle.pbDisplay(_INTL("{1} protected itself!", target.pbThis))
          end
          target.damageState.protected = true
          @battle.successStates[user.index].protected = true
          if move.pbContactMove?(user) && user.affectedByContactEffect? &&
             user.pbCanPoison?(target, false)
            user.pbPoison(target)
          end
          return false
        end
        # Obstruct
        if target.effects[PBEffects::Obstruct] && move.damagingMove?
          if show_message
            @battle.pbCommonAnimation("Obstruct", target)
            @battle.pbDisplay(_INTL("{1} protected itself!", target.pbThis))
          end
          target.damageState.protected = true
          @battle.successStates[user.index].protected = true
          if move.pbContactMove?(user) && user.affectedByContactEffect? &&
             user.pbCanLowerStatStage?(:DEFENSE, target)
            user.pbLowerStatStage(:DEFENSE, 2, target)
          end
          return false
        end
        # Mat Block
        if target.pbOwnSide.effects[PBEffects::MatBlock] && move.damagingMove?
          # NOTE: Confirmed no common animation for this effect.
          @battle.pbDisplay(_INTL("{1} was blocked by the kicked-up mat!", move.name)) if show_message
          target.damageState.protected = true
          @battle.successStates[user.index].protected = true
          return false
        end
      end
    end
    # Magic Coat/Magic Bounce
    if move.statusMove? && move.canMagicCoat? && !target.semiInvulnerable? && target.opposes?(user)
      if target.effects[PBEffects::MagicCoat]
        target.damageState.magicCoat = true
        target.effects[PBEffects::MagicCoat] = false
        return false
      end
      if target.hasActiveAbility?(:MAGICBOUNCE) && !target.affectedByMoldBreaker? &&
         !target.effects[PBEffects::MagicBounce]
        target.damageState.magicBounce = true
        target.effects[PBEffects::MagicBounce] = true
        return false
      end
    end
    # Immunity because of ability (intentionally before type immunity check)
    return false if move.pbImmunityByAbility(user, target, show_message)
    # Type immunity
    if move.pbDamagingMove? && Effectiveness.ineffective?(typeMod)
      PBDebug.log("[Target immune] #{target.pbThis}'s type immunity")
      @battle.pbDisplay(_INTL("It doesn't affect {1}...", target.pbThis(true))) if show_message
      return false
    end
    # Dark-type immunity to moves made faster by Prankster
    if Settings::MECHANICS_GENERATION >= 7 && user.effects[PBEffects::Prankster] &&
       target.pbHasType?(:DARK) && target.opposes?(user)
      PBDebug.log("[Target immune] #{target.pbThis} is Dark-type and immune to Prankster-boosted moves")
      @battle.pbDisplay(_INTL("It doesn't affect {1}...", target.pbThis(true))) if show_message
      return false
    end
    # Airborne-based immunity to Ground moves
    if move.damagingMove? && move.calcType == :GROUND &&
       target.airborne? && !move.hitsFlyingTargets?
      if target.hasActiveAbility?(:LEVITATE) && !target.affectedByMoldBreaker?
        if show_message
          @battle.pbShowAbilitySplash(target)
          if Battle::Scene::USE_ABILITY_SPLASH
            @battle.pbDisplay(_INTL("{1} avoided the attack!", target.pbThis))
          else
            @battle.pbDisplay(_INTL("{1} avoided the attack with {2}!", target.pbThis, target.abilityName))
          end
          @battle.pbHideAbilitySplash(target)
        end
        return false
      end
      if target.hasActiveItem?(:AIRBALLOON)
        @battle.pbDisplay(_INTL("{1}'s {2} makes Ground moves miss!", target.pbThis, target.itemName)) if show_message
        return false
      end
      if target.effects[PBEffects::MagnetRise] > 0
        @battle.pbDisplay(_INTL("{1} makes Ground moves miss with Magnet Rise!", target.pbThis)) if show_message
        return false
      end
      if target.effects[PBEffects::Telekinesis] > 0
        @battle.pbDisplay(_INTL("{1} makes Ground moves miss with Telekinesis!", target.pbThis)) if show_message
        return false
      end
    end
    # Immunity to powder-based moves
    if move.powderMove?
      if target.pbHasType?(:GRASS) && Settings::MORE_TYPE_EFFECTS
        PBDebug.log("[Target immune] #{target.pbThis} is Grass-type and immune to powder-based moves")
        @battle.pbDisplay(_INTL("It doesn't affect {1}...", target.pbThis(true))) if show_message
        return false
      end
      if Settings::MECHANICS_GENERATION >= 6
        if target.hasActiveAbility?(:OVERCOAT) && !target.affectedByMoldBreaker?
          if show_message
            @battle.pbShowAbilitySplash(target)
            if Battle::Scene::USE_ABILITY_SPLASH
              @battle.pbDisplay(_INTL("It doesn't affect {1}...", target.pbThis(true)))
            else
              @battle.pbDisplay(_INTL("It doesn't affect {1} because of its {2}.", target.pbThis(true), target.abilityName))
            end
            @battle.pbHideAbilitySplash(target)
          end
          return false
        end
        if target.hasActiveItem?(:SAFETYGOGGLES)
          PBDebug.log("[Item triggered] #{target.pbThis} has Safety Goggles and is immune to powder-based moves")
          @battle.pbDisplay(_INTL("It doesn't affect {1}...", target.pbThis(true))) if show_message
          return false
        end
      end
    end
    #===============================================================================
    # Substitute
    if target.effects[PBEffects::Substitute] > 0 && move.statusMove? &&
       !move.ignoresSubstitute?(user) && user.index != target.index
      PBDebug.log("[Target immune] #{target.pbThis} is protected by its Substitute")
      @battle.pbDisplay(_INTL("{1} avoided the attack!", target.pbThis(true))) if show_message
      return false
    end
    return true
  end

  # add Covert Cloak effect
  #=============================================================================
  # Attack a single target
  #=============================================================================
  def pbProcessMoveHit(move, user, targets, hitNum, skipAccuracyCheck)
    return false if user.fainted?
    # For two-turn attacks being used in a single turn
    move.pbInitialEffect(user, targets, hitNum)
    numTargets = 0   # Number of targets that are affected by this hit
    # Count a hit for Parental Bond (if it applies)
    user.effects[PBEffects::ParentalBond] -= 1 if user.effects[PBEffects::ParentalBond] > 0
    # Accuracy check (accuracy/evasion calc)
    if hitNum == 0 || move.successCheckPerHit?
      targets.each do |b|
        b.damageState.missed = false
        next if b.damageState.unaffected
        if pbSuccessCheckPerHit(move, user, b, skipAccuracyCheck)
          numTargets += 1
        else
          b.damageState.missed     = true
          b.damageState.unaffected = true
        end
      end
      # If failed against all targets
      if targets.length > 0 && numTargets == 0 && !move.worksWithNoTargets?
        targets.each do |b|
          next if !b.damageState.missed || b.damageState.magicCoat
          pbMissMessage(move, user, b)
          if user.itemActive?
            Battle::ItemEffects.triggerOnMissingTarget(user.item, user, b, move, hitNum, @battle)
          end
          break if move.pbRepeatHit?   # Dragon Darts only shows one failure message
        end
        move.pbCrashDamage(user)
        user.pbItemHPHealCheck
        pbCancelMoves
        return false
      end
    end
    # If we get here, this hit will happen and do something
    all_targets = targets
    targets = move.pbDesignateTargetsForHit(targets, hitNum)   # For Dragon Darts
    targets.each { |b| b.damageState.resetPerHit }
    #---------------------------------------------------------------------------
    # Calculate damage to deal
    if move.pbDamagingMove?
      targets.each do |b|
        next if b.damageState.unaffected
        # Check whether Substitute/Disguise will absorb the damage
        move.pbCheckDamageAbsorption(user, b)
        # Calculate the damage against b
        # pbCalcDamage shows the "eat berry" animation for SE-weakening
        # berries, although the message about it comes after the additional
        # effect below
        move.pbCalcDamage(user, b, targets.length)   # Stored in damageState.calcDamage
        # Lessen damage dealt because of False Swipe/Endure/etc.
        move.pbReduceDamage(user, b)   # Stored in damageState.hpLost
      end
    end
    # Show move animation (for this hit)
    move.pbShowAnimation(move.id, user, targets, hitNum)
    # Type-boosting Gem consume animation/message
    if user.effects[PBEffects::GemConsumed] && hitNum == 0
      # NOTE: The consume animation and message for Gems are shown now, but the
      #       actual removal of the item happens in def pbEffectsAfterMove.
      @battle.pbCommonAnimation("UseItem", user)
      @battle.pbDisplay(_INTL("The {1} strengthened {2}'s power!",
                              GameData::Item.get(user.effects[PBEffects::GemConsumed]).name, move.name))
    end
    # Messages about missed target(s) (relevant for multi-target moves only)
    if !move.pbRepeatHit?
      targets.each do |b|
        next if !b.damageState.missed
        pbMissMessage(move, user, b)
        if user.itemActive?
          Battle::ItemEffects.triggerOnMissingTarget(user.item, user, b, move, hitNum, @battle)
        end
      end
    end
    # Deal the damage (to all allies first simultaneously, then all foes
    # simultaneously)
    if move.pbDamagingMove?
      # This just changes the HP amounts and does nothing else
      targets.each { |b| move.pbInflictHPDamage(b) if !b.damageState.unaffected }
      # Animate the hit flashing and HP bar changes
      move.pbAnimateHitAndHPLost(user, targets)
    end
    # Self-Destruct/Explosion's damaging and fainting of user
    move.pbSelfKO(user) if hitNum == 0
    user.pbFaint if user.fainted?
    if move.pbDamagingMove?
      targets.each do |b|
        next if b.damageState.unaffected
        # NOTE: This method is also used for the OHKO special message.
        move.pbHitEffectivenessMessages(user, b, targets.length)
        # Record data about the hit for various effects' purposes
        move.pbRecordDamageLost(user, b)
      end
      # Close Combat/Superpower's stat-lowering, Flame Burst's splash damage,
      # and Incinerate's berry destruction
      targets.each do |b|
        next if b.damageState.unaffected
        move.pbEffectWhenDealingDamage(user, b)
      end
      # Ability/item effects such as Static/Rocky Helmet, and Grudge, etc.
      targets.each do |b|
        next if b.damageState.unaffected
        pbEffectsOnMakingHit(move, user, b)
      end
      # Disguise/Endure/Sturdy/Focus Sash/Focus Band messages
      targets.each do |b|
        next if b.damageState.unaffected
        move.pbEndureKOMessage(b)
      end
      # HP-healing held items (checks all battlers rather than just targets
      # because Flame Burst's splash damage affects non-targets)
      @battle.pbPriority(true).each { |b| b.pbItemHPHealCheck }
      # Animate battlers fainting (checks all battlers rather than just targets
      # because Flame Burst's splash damage affects non-targets)
      @battle.pbPriority(true).each { |b| b.pbFaint if b&.fainted? }
    end
    @battle.pbJudgeCheckpoint(user, move)
    # Main effect (recoil/drain, etc.)
    targets.each do |b|
      next if b.damageState.unaffected
      move.pbEffectAgainstTarget(user, b)
    end
    move.pbEffectGeneral(user)
    targets.each { |b| b.pbFaint if b&.fainted? }
    user.pbFaint if user.fainted?
    # Additional effect
    if !user.hasActiveAbility?(:SHEERFORCE)
      targets.each do |b|
        next if b.damageState.calcDamage == 0
        next if b.hasActiveItem?(:COVERTCLOAK)
        chance = move.pbAdditionalEffectChance(user, b)
        next if chance <= 0
        if @battle.pbRandom(100) < chance
          move.pbAdditionalEffect(user, b)
        end
      end
    end
    # Make the target flinch (because of an item/ability)
    targets.each do |b|
      next if b.fainted?
      next if b.damageState.calcDamage == 0 || b.damageState.substitute
      chance = move.pbFlinchChance(user, b)
      next if chance <= 0
      if @battle.pbRandom(100) < chance
        PBDebug.log("[Item/ability triggered] #{user.pbThis}'s King's Rock/Razor Fang or Stench")
        b.pbFlinch(user)
      end
    end
    # Message for and consuming of type-weakening berries
    # NOTE: The "consume held item" animation for type-weakening berries occurs
    #       during pbCalcDamage above (before the move's animation), but the
    #       message about it only shows here.
    targets.each do |b|
      next if b.damageState.unaffected
      next if !b.damageState.berryWeakened
      @battle.pbDisplay(_INTL("The {1} weakened the damage to {2}!", b.itemName, b.pbThis(true)))
      b.pbConsumeItem
    end
    # Steam Engine (goes here because it should be after stat changes caused by
    # the move)
    if [:FIRE, :WATER].include?(move.calcType)
      targets.each do |b|
        next if b.damageState.unaffected
        next if b.damageState.calcDamage == 0 || b.damageState.substitute
        next if !b.hasActiveAbility?(:STEAMENGINE)
        b.pbRaiseStatStageByAbility(:SPEED, 6, b) if b.pbCanRaiseStatStage?(:SPEED, b)
      end
    end
    # Fainting
    targets.each { |b| b.pbFaint if b&.fainted? }
    user.pbFaint if user.fainted?
    # Dragon Darts' second half of attack
    if move.pbRepeatHit? && hitNum == 0 &&
       targets.any? { |b| !b.fainted? && !b.damageState.unaffected }
      pbProcessMoveHit(move, user, all_targets, 1, skipAccuracyCheck)
    end
    return true
  end
  #=============================================================================
  # Effect per hit
  #=============================================================================
  alias ragefist_pbEffectsOnMakingHit pbEffectsOnMakingHit
  def pbEffectsOnMakingHit(move, user, target)
    ragefist_pbEffectsOnMakingHit(move, user, target)
    if target.damageState.calcDamage > 0 && !target.damageState.substitute
        # target.pokemon.rage_hit += 1
        @battle.addBattlerHit(target)
    end
  end

  #=============================================================================
  # Decide whether the trainer is allowed to tell the Pokémon to use the given
  # move. Called when choosing a command for the round.
  # Also called when processing the Pokémon's action, because these effects also
  # prevent Pokémon action. Relevant because these effects can become active
  # earlier in the same round (after choosing the command but before using the
  # move) or an unusable move may be called by another move such as Metronome.
  #=============================================================================
  def pbCanChooseMove?(move, commandPhase, showMessages = true, specialUsage = false)
    # Disable
    if @effects[PBEffects::DisableMove] == move.id && !specialUsage
      if showMessages
        msg = _INTL("{1}'s {2} is disabled!", pbThis, move.name)
        (commandPhase) ? @battle.pbDisplayPaused(msg) : @battle.pbDisplay(msg)
      end
      return false
    end
    # Heal Block
    if @effects[PBEffects::HealBlock] > 0 && move.healingMove?
      if showMessages
        msg = _INTL("{1} can't use {2} because of Heal Block!", pbThis, move.name)
        (commandPhase) ? @battle.pbDisplayPaused(msg) : @battle.pbDisplay(msg)
      end
      return false
    end
    # Gravity
    if @battle.field.effects[PBEffects::Gravity] > 0 && move.unusableInGravity?
      if showMessages
        msg = _INTL("{1} can't use {2} because of gravity!", pbThis, move.name)
        (commandPhase) ? @battle.pbDisplayPaused(msg) : @battle.pbDisplay(msg)
      end
      return false
    end
    # Throat Chop
    if @effects[PBEffects::ThroatChop] > 0 && move.soundMove?
      if showMessages
        msg = _INTL("{1} can't use {2} because of Throat Chop!", pbThis, move.name)
        (commandPhase) ? @battle.pbDisplayPaused(msg) : @battle.pbDisplay(msg)
      end
      return false
    end
    # Choice Band/Gorilla Tactics
    @effects[PBEffects::ChoiceBand] = nil if !pbHasMove?(@effects[PBEffects::ChoiceBand])
    if @effects[PBEffects::ChoiceBand] && move.id != @effects[PBEffects::ChoiceBand]
      choiced_move_name = GameData::Move.get(@effects[PBEffects::ChoiceBand]).name
      if hasActiveItem?([:CHOICEBAND, :CHOICESPECS, :CHOICESCARF])
        if showMessages
          msg = _INTL("The {1} only allows the use of {2}!", itemName, choiced_move_name)
          (commandPhase) ? @battle.pbDisplayPaused(msg) : @battle.pbDisplay(msg)
        end
        return false
      elsif hasActiveAbility?(:GORILLATACTICS)
        if showMessages
          msg = _INTL("{1} can only use {2}!", pbThis, choiced_move_name)
          (commandPhase) ? @battle.pbDisplayPaused(msg) : @battle.pbDisplay(msg)
        end
        return false
      end
    end
    # Taunt
    if @effects[PBEffects::Taunt] > 0 && move.statusMove?
      if showMessages
        msg = _INTL("{1} can't use {2} after the taunt!", pbThis, move.name)
        (commandPhase) ? @battle.pbDisplayPaused(msg) : @battle.pbDisplay(msg)
      end
      return false
    end
    # Torment
    if @effects[PBEffects::Torment] && !@effects[PBEffects::Instructed] &&
       @lastMoveUsed && move.id == @lastMoveUsed && move.id != @battle.struggle.id
      if showMessages
        msg = _INTL("{1} can't use the same move twice in a row due to the torment!", pbThis)
        (commandPhase) ? @battle.pbDisplayPaused(msg) : @battle.pbDisplay(msg)
      end
      return false
    end
    # Imprison
    if @battle.allOtherSideBattlers(@index).any? { |b| b.effects[PBEffects::Imprison] && b.pbHasMove?(move.id) }
      if showMessages
        msg = _INTL("{1} can't use its sealed {2}!", pbThis, move.name)
        (commandPhase) ? @battle.pbDisplayPaused(msg) : @battle.pbDisplay(msg)
      end
      return false
    end
    # Gigaton Hammer
    if !@effects[PBEffects::Instructed] && @lastMoveUsed && move.id == @lastMoveUsed && move.id == :GIGATONHAMMER && 
       @effects[PBEffects::Encore] == 0
     if showMessages
       msg = _INTL("{1} can't use this move twice in a row!", pbThis)
       (commandPhase) ? @battle.pbDisplayPaused(msg) : @battle.pbDisplay(msg)
     end
     return false
   end
    # Assault Vest (prevents choosing status moves but doesn't prevent
    # executing them)
    if hasActiveItem?(:ASSAULTVEST) && move.statusMove? && move.id != :MEFIRST && commandPhase
      if showMessages
        msg = _INTL("The effects of the {1} prevent status moves from being used!", itemName)
        (commandPhase) ? @battle.pbDisplayPaused(msg) : @battle.pbDisplay(msg)
      end
      return false
    end
    # Belch
    return false if !move.pbCanChooseMove?(self, commandPhase, showMessages)
    return true
  end
  #=============================================================================
  # Effects after all hits (i.e. at end of move usage)
  #=============================================================================
  # Battle bond changes
  def pbEffectsAfterMove(user, targets, move, numHits)
    # Defrost
    if move.damagingMove?
      targets.each do |b|
        next if b.damageState.unaffected || b.damageState.substitute
        next if b.status != :FROZEN
        # NOTE: Non-Fire-type moves that thaw the user will also thaw the
        #       target (in Gen 6+).
        if move.calcType == :FIRE || (Settings::MECHANICS_GENERATION >= 6 && move.thawsUser?)
          b.pbCureStatus
        end
      end
    end
    # Destiny Bond
    # NOTE: Although Destiny Bond is similar to Grudge, they don't apply at
    #       the same time (however, Destiny Bond does check whether it's going
    #       to trigger at the same time as Grudge).
    if user.effects[PBEffects::DestinyBondTarget] >= 0 && !user.fainted?
      dbName = @battle.battlers[user.effects[PBEffects::DestinyBondTarget]].pbThis
      @battle.pbDisplay(_INTL("{1} took its attacker down with it!", dbName))
      user.pbReduceHP(user.hp, false)
      user.pbItemHPHealCheck
      user.pbFaint
      @battle.pbJudgeCheckpoint(user)
    end
    # User's ability
    if user.abilityActive?
      Battle::AbilityEffects.triggerOnEndOfUsingMove(user.ability, user, targets, move, @battle)
    end
    if !user.fainted? && !user.effects[PBEffects::Transform] &&
       !@battle.pbAllFainted?(user.idxOpposingSide)
      # Greninja - Battle Bond
      if user.isSpecies?(:GRENINJA) && user.ability == :BATTLEBOND &&
         !@battle.battleBond[user.index & 1][user.pokemonIndex]
        numFainted = 0
        targets.each { |b| numFainted += 1 if b.damageState.fainted }
        if numFainted > 0 && user.form == 1
          if Settings::MECHANICS_GENERATION >= 9
            if user.pbCanRaiseStatStage?(:ATTACK, user) || user.pbCanRaiseStatStage?(:SPECIAL_ATTACK, user) ||
               user.pbCanRaiseStatStage?(:SPEED, user)
               @battle.battleBond[user.index & 1][user.pokemonIndex] = true
               @battle.pbDisplay(_INTL("{1} became fully charged due to its bond with its Trainer!", user.pbThis))
               @battle.pbShowAbilitySplash(user, true)
               @battle.pbHideAbilitySplash(user)
               [:ATTACK,:SPECIAL_ATTACK,:SPEED].each{|s|
                user.pbRaiseStatStageByAbility(s, 1, user,false)
               }
            end
          else
            @battle.battleBond[user.index & 1][user.pokemonIndex] = true
            @battle.pbDisplay(_INTL("{1} became fully charged due to its bond with its Trainer!", user.pbThis))
            @battle.pbShowAbilitySplash(user, true)
            @battle.pbHideAbilitySplash(user)
            user.pbChangeForm(2, _INTL("{1} became Ash-Greninja!", user.pbThis))
          end
        end
      end
      # Cramorant = Gulp Missile
      if user.isSpecies?(:CRAMORANT) && user.ability == :GULPMISSILE && user.form == 0 &&
         ((move.id == :SURF && numHits > 0) || (move.id == :DIVE && move.chargingTurn))
        # NOTE: Intentionally no ability splash or message here.
        user.pbChangeForm((user.hp > user.totalhp / 2) ? 1 : 2, nil)
      end
    end
    # Room Service
    if move.function == "StartSlowerBattlersActFirst" && @battle.field.effects[PBEffects::TrickRoom] > 0
      @battle.allBattlers.each do |b|
        next if !b.hasActiveItem?(:ROOMSERVICE)
        next if !b.pbCanLowerStatStage?(:SPEED)
        @battle.pbCommonAnimation("UseItem", b)
        b.pbLowerStatStage(:SPEED, 1, nil)
        b.pbConsumeItem
      end
    end
    # Consume user's Gem
    if user.effects[PBEffects::GemConsumed]
      # NOTE: The consume animation and message for Gems are shown immediately
      #       after the move's animation, but the item is only consumed now.
      user.pbConsumeItem
    end
    switched_battlers = []   # Indices of battlers that were switched out somehow
    # Target switching caused by Roar, Whirlwind, Circle Throw, Dragon Tail
    move.pbSwitchOutTargetEffect(user, targets, numHits, switched_battlers)
    # Target's item, user's item, target's ability (all negated by Sheer Force)
    if !(user.hasActiveAbility?(:SHEERFORCE) && move.addlEffect > 0)
      pbEffectsAfterMove2(user, targets, move, numHits, switched_battlers)
    end
    # Some move effects that need to happen here, i.e. user switching caused by
    # U-turn/Volt Switch/Baton Pass/Parting Shot, Relic Song's form changing,
    # Fling/Natural Gift consuming item.
    if !switched_battlers.include?(user.index)
      move.pbEndOfMoveUsageEffect(user, targets, numHits, switched_battlers)
    end
    # User's ability/item that switches the user out (all negated by Sheer Force)
    if !(user.hasActiveAbility?(:SHEERFORCE) && move.addlEffect > 0)
      pbEffectsAfterMove3(user, targets, move, numHits, switched_battlers)
    end
    if numHits > 0
      @battle.allBattlers.each { |b| b.pbItemEndOfMoveCheck }
    end
  end
  
  # Called when a Pokémon (self) enters battle, at the end of each move used,
  # and at the end of each round.
  def pbContinualAbilityChecks(onSwitchIn = false)
    # Check for end of primordial weather
    @battle.pbEndPrimordialWeather
    # Trace
    if hasActiveAbility?(:TRACE) && !hasActiveItem?(:ABILITYSHIELD)
      # NOTE: In Gen 5 only, Trace only triggers upon the Trace bearer switching
      #       in and not at any later times, even if a traceable ability turns
      #       up later. Essentials ignores this, and allows Trace to trigger
      #       whenever it can even in Gen 5 battle mechanics.
      choices = @battle.allOtherSideBattlers(@index).select { |b|
        next !b.ungainableAbility? &&
             ![:POWEROFALCHEMY, :RECEIVER, :TRACE].include?(b.ability_id)
      }
      if choices.length > 0
        choice = choices[@battle.pbRandom(choices.length)]
        @battle.pbShowAbilitySplash(self)
        self.ability = choice.ability
        @battle.pbDisplay(_INTL("{1} traced {2}'s {3}!", pbThis, choice.pbThis(true), choice.abilityName))
        @battle.pbHideAbilitySplash(self)
        if !onSwitchIn && (unstoppableAbility? || abilityActive?)
          Battle::AbilityEffects.triggerOnSwitchIn(self.ability, self, @battle)
        end
      end
    end
  end
end