#===============================================================================
# Max Raid Battle set up and associated utilities.
#===============================================================================
class MaxRaidBattle
  def self.start(species = [], rules = {}, pokemon = {})
    $game_temp.dx_clear
    default_rules = {
      :size      => Settings::MAXRAID_SIZE,
      :turns     => Settings::MAXRAID_TIMER,
      :kocount   => Settings::MAXRAID_KOS,
      :shield    => Settings::MAXRAID_SHIELD,
      :rank      => raid_RankFromBadgeCount,
      :environ   => :Cave,
      :hard      => false,
      :autoscale => true,
      :simple    => false
    }
    default_rules.keys.each { |key| rules[key] = default_rules[key].clone if !rules.has_key?(key) }
    foe, rank = MaxRaidBattle.generate_foe(species, rules[:rank], pokemon)
    rules[:rank]        = rank
    rules[:hard]        = true if rules[:rank] == 6 && !inMaxLair?
    rules[:outcome]     = 1 if !rules[:outcome]
    rules[:canlose]     = true
    rules[:noflee]      = true
    rules[:noexp]       = true
    rules[:nomoney]     = true
    rules[:nocapture]   = true
    rules[:nopartner]   = true
    rules[:setcapture]  = true if !rules[:hard]
    $game_temp.dx_rules = rules
    pbApplyBattleRules(1, true)
    if rules[:simple]
      outcome = MaxRaidBattle.start_core(foe)
      if inMaxLair? && [1, 4].include?(outcome)
        pbDynamaxAdventure.battle_count += 1
        qty = 1 + (rand(rules[:rank] * $game_temp.dx_pokemon[:level]) / 25).floor
        pbDynamaxAdventure.add_loot(:DYNITEORE, qty)
      end
    else
      outcome = raid_InitiateRaidDen(foe)
    end
    $game_temp.dx_clear
    return outcome != 2 && outcome != 5
  end

  #-----------------------------------------------------------------------------
  # Battle core.
  #-----------------------------------------------------------------------------
  def self.start_core(foe)
    rules = $game_temp.dx_rules
    EventHandlers.trigger(:on_start_battle)
    foe, _rank = MaxRaidBattle.generate_foe(foe, rules[:rank], pokemon) if !foe
    foe_party = [foe]
    if BattleCreationHelperMethods.skip_battle?
      return BattleCreationHelperMethods.skip_battle(rules[:outcome])
    end
    prefix = !(foe.gmax_factor?) ? "A Dynamaxed" : (foe.isSpecies?(:ETERNATUS)) ? "An Eternamax" : "A Gigantamax"
    location = (inMaxLair?) ? "lair" : "den"
    rules[:introtext] = "#{prefix} {1} emerged from within the #{location}!"
    rules[:raidcapture] = ["{1} disappeared somewhere into the #{location}...", "Battle Raid Capture"]
    rules[:raidcapture].push(20) if rules[:hard]
    player_trainers, ally_items, player_party, player_party_starts = BattleCreationHelperMethods.set_up_player_trainers(foe_party)
    scene = BattleCreationHelperMethods.create_battle_scene
    battle = RaidBattle.new(scene, player_party, foe_party, player_trainers, nil)
    battle.party1starts = player_party_starts
    battle.ally_items   = ally_items
    BattleCreationHelperMethods.prepare_battle(battle)
    $game_temp.clear_battle_rules
    outcome = 0
    naming_setting = $PokemonSystem.givenicknames
    $PokemonSystem.givenicknames = 1
    pbBattleAnimation(pbGetWildBattleBGM(foe_party), 0, foe_party) {
      pbSceneStandby {
        outcome = battle.pbStartBattle
      }
      BattleCreationHelperMethods.after_battle(outcome, rules[:canlose])
    }
    Input.update
    BattleCreationHelperMethods.set_outcome(outcome, rules[:outcome])
    $PokemonSystem.givenicknames = naming_setting
    $player.has_raid_database = true if Settings::UNLOCK_DATABASE_FROM_RAIDS
    return outcome
  end

  #-----------------------------------------------------------------------------
  # Creates a Max Raid Pokemon to generate for battle.
  #-----------------------------------------------------------------------------
  def self.generate_foe(species, rank, pokemon = {})
    default_pkmn = {
      :form       => 0,
      :obtaintext => _INTL("Max Raid Den."),
      :gmaxfactor => false
    }
    default_pkmn.keys.each { |key| pokemon[key] = default_pkmn[key].clone if !pokemon.has_key?(key) }
    case species
    #---------------------------------------------------------------------------
    # Sets appropriate data if species paramater is a Pokemon object.
    #---------------------------------------------------------------------------
    when Pokemon
      species_id           = species.species
      pokemon[:level]      = species.level
      pokemon[:form]       = species.form
      pokemon[:gender]     = species.gender
      pokemon[:size]       = species.scale
      pokemon[:item]       = species.item_id
      pokemon[:ability]    = species.ability_index
      pokemon[:moves]      = species.moves
      pokemon[:ribbons]    = species.ribbons
      pokemon[:ivs]        = species.iv.values
      pokemon[:dynamaxlvl] = species.dynamax_lvl
      pokemon[:shiny]      = species.shiny?
      pokemon[:supershiny] = species.super_shiny?
      pokemon[:gmaxfactor] = species.gmax_factor?
      rank = raid_RankFromLevel(pokemon[:level])
    #---------------------------------------------------------------------------
    # Sets a raid species if species parameter is a species symbol.
    #---------------------------------------------------------------------------
    else
      case species
      when Symbol
        species_id = raid_GetEligibleSpecies(species)
      else
        species_id = raid_GenerateSpecies(species, rank, pbGetEnvironment)
      end
      if pokemon[:form].is_a?(Symbol)
        total_forms = [0]
        GameData::Species.each { |s| total_forms.push(s.form) if s.species == species_id }
        pokemon[:form] = total_forms.sample
      end
      if pokemon[:form] > 0
        data = GameData::Species.get(species_id)
        species_id = GameData::Species.get_species_form(data.species, pokemon[:form]).id
      end
      eligible_ranks = raid_RanksAppearedIn(species_id)
      rank = eligible_ranks.sample if !eligible_ranks.include?(rank)
      pokemon[:level] = raid_LevelFromRank(rank)
      pokemon[:form] = GameData::Species.get(species_id).form
      species_data = GameData::Species.get(species_id)
      pokemon[:size] = 200 + rand(56)
      #-------------------------------------------------------------------------
      # Adjusts [:gender] in cases where gender alters appearance.
      #-------------------------------------------------------------------------
      if species_data.bitmap_exists?("Icons", true) && !pokemon[:gender]
        female_chance = GameData::GenderRatio.get(species_data.gender_ratio).female_chance
        pokemon[:gender] = (rand(255) < female_chance) ? 0 : 1
      else
        case species_data.gender_ratio
        when :AlwaysMale;   pokemon[:gender] = 0
        when :AlwaysFemale; pokemon[:gender] = 1
        when :Genderless;   pokemon[:gender] = nil
        end
      end
      #-------------------------------------------------------------------------
      # Sets [:ivs] based on the raid rank.
      #-------------------------------------------------------------------------
      i = 0
      stats = []
      GameData::Stat.each_main do |s|
        i += 1
        iv = (i <= rank) ? Pokemon::IV_STAT_LIMIT : rand(Pokemon::IV_STAT_LIMIT + 1)
        stats.push(iv)
      end
      pokemon[:ivs] = stats.shuffle
      #-------------------------------------------------------------------------
      # Sets Hidden Ability index for [:ability] based on the raid rank.
      #-------------------------------------------------------------------------
      if !pokemon[:ability]
        chance = rand(10)
        pokemon[:ability] = 2 if rank == 4  && chance < 2
        pokemon[:ability] = 2 if rank == 5  && chance < 5
        pokemon[:ability] = 2 if rank == 6  && chance < 8
      end
      #-------------------------------------------------------------------------
      # Sets the Mightiest Mark on raid Pokemon battled under Hard Mode.
      #-------------------------------------------------------------------------
      if !pokemon[:mark] && rank == 6
        pokemon[:mark] = :MIGHTIESTMARK
      end
      #-------------------------------------------------------------------------
      # Generates a raid moveset and sets the [:moves].
      #-------------------------------------------------------------------------
      if !pokemon[:moves]
        moves = []
        raid_moves = raid_GenerateMovelists(species_id)
        raid_moves.each { |m| moves.push(m.sample) }
        pokemon[:moves] = moves
      end
      #---------------------------------------------------------------------------
      # Sets [:dynamaxlvl] based on the raid [:rank].
      #-------------------------------------------------------------------------
      case rank
      when 1 then pokemon[:dynamaxlvl] = 5
      when 2 then pokemon[:dynamaxlvl] = 10
      when 3 then pokemon[:dynamaxlvl] = 20
      when 4 then pokemon[:dynamaxlvl] = 30
      when 5 then pokemon[:dynamaxlvl] = 40
      when 6 then pokemon[:dynamaxlvl] = 50
      end
      #-------------------------------------------------------------------------
      # Scales the likelihood of [:gmaxfactor] if the species can Gigantamax.
      #-------------------------------------------------------------------------
      if species_data.hasGmax?
        chance = rand(10)
        case rank
        when 3;   pokemon[:gmaxfactor] = true if chance < 1
        when 4;   pokemon[:gmaxfactor] = true if chance < 3
        when 5,6; pokemon[:gmaxfactor] = true if chance < 5
        end
      else
        pokemon[:gmaxfactor] = false
      end
    end
    #---------------------------------------------------------------------------
    # Dynamax Adventure settings for [:shiny] and [:obtaintext].
    #---------------------------------------------------------------------------
    if inMaxLair?
      pokemon[:shiny] = false
      pokemon[:supershiny] = false
    end
    pokemon[:dynamax] = true
    pokemon[:species] = species_id
    $game_temp.dx_pokemon = pokemon
    pkmn = Pokemon.new(pokemon[:species], pokemon[:level])
    pbApplyWildAttributes([pkmn])
    return pkmn, rank
  end
end


#-------------------------------------------------------------------------------
# Generates all eligible movelists for a particular species.
#-------------------------------------------------------------------------------
def raid_GenerateMovelists(pkmn, rental = false)
  stab_moves     = []
  coverage_moves = []
  spread_moves   = []
  status_moves   = []
  #-----------------------------------------------------------------------------
  # Creates arrays of eligible moves for this species.
  #-----------------------------------------------------------------------------
  species_data = GameData::Species.get(pkmn)
  acrobatics = "DoublePowerIfUserHasNoItem"
  rotom_form = (species_data.species == :ROTOM && species_data.form > 0)
  family_moves = species_data.get_family_moves
  blacklist, whitelist = raid_GetEligibleMoves(rental)
  GameData::Move.each do |m|
    next if m.powerMove?
    next if !family_moves.include?(m.id)
    next if blacklist.include?(m.function_code)
    next if m.accuracy > 0 && m.accuracy < 70
    stab = species_data.types.include?(m.type)
    mult = (m.target == :AllNearFoes || m.target == :AllNearOthers)
    if whitelist.include?(m.function_code)
      status_moves.push(m.id)
    elsif m.base_damage >= 55 && mult && !rental
      spread_moves.push(m.id)
    elsif rotom_form && stab && !mult && (m.base_damage >= 75 || m.function_code == acrobatics)
      coverage_moves.push(m.id)
    elsif stab && !mult && (m.base_damage >= 70 || m.function_code == acrobatics)
      stab_moves.push(m.id)
    elsif m.type != :NORMAL && !mult && !stab && (m.base_damage >= 75 || m.function_code == acrobatics)
      coverage_moves.push(m.id)
    end 
    # Rental Pokemon in a Dynamax Adventure don't get spread moves.
    if rental && !mult
      spread_moves.push(m.id) if whitelist.include?(m.function_code) || m.base_damage >= 75
    end
  end
  #-----------------------------------------------------------------------------
  # Forces certain moves onto specific species's movelists.
  #-----------------------------------------------------------------------------
  case pkmn
  when :TAUROS_1   then stab_moves.push(:RAGINGBULL)
  when :TAUROS_2   then stab_moves.push(:RAGINGBULL)
  when :TAUROS_3   then stab_moves.push(:RAGINGBULL)
  when :SNORLAX    then status_moves.push(:REST)
  when :SHUCKLE    then status_moves.push(:POWERTRICK)
  when :SLAKING    then stab_moves.push(:GIGAIMPACT)
  when :CASTFORM   then stab_moves.push(:WEATHERBALL)
  when :ROTOM_1    then stab_moves.push(:OVERHEAT)
  when :ROTOM_2    then stab_moves.push(:HYDROPUMP)
  when :ROTOM_3    then stab_moves.push(:BLIZZARD)
  when :ROTOM_4    then stab_moves.push(:AIRSLASH)
  when :ROTOM_5    then stab_moves.push(:LEAFSTORM)
  when :DARKRAI    then status_moves.push(:DARKVOID)
  when :GENESECT   then coverage_moves.push(:TECHNOBLAST)  
  when :ORICORIO   then coverage_moves.push(:REVELATIONDANCE)
  when :ORICORIO_1 then coverage_moves.push(:REVELATIONDANCE)
  when :ORICORIO_2 then coverage_moves.push(:REVELATIONDANCE)
  when :ORICORIO_3 then coverage_moves.push(:REVELATIONDANCE)
  when :MELMETAL   then stab_moves.push(:DOUBLEIRONBASH)
  when :SIRFETCHD  then stab_moves.push(:METEORASSAULT)
  when :DRAGAPULT  then spread_moves.push(:DRAGONDARTS)
  when :URSHIFU_1  then stab_moves.push(:SURGINGSTRIKES)
  when :MAUSHOLD   then stab_moves.push(:POPULATIONBOMB)
  when :MAUSHOLD_1 then stab_moves.push(:POPULATIONBOMB)
  when :PALAFIN_1  then stab_moves.push(:JETPUNCH)
  when :ANNIHILAPE then stab_moves.push(:RAGEFIST)
  end
  return [stab_moves, coverage_moves, spread_moves, status_moves]
end


#-------------------------------------------------------------------------------
# Sets up arrays containing all moves a raid battler may or may not have.
#-------------------------------------------------------------------------------
def raid_GetEligibleMoves(rental = false)
  #-----------------------------------------------------------------------------
  # Moves that are ignored when compiling movelists.
  #-----------------------------------------------------------------------------
  blacklist  = [
    "FailsIfNotUserFirstTurn",                        # First Impression
    "FlinchTargetFailsIfNotUserFirstTurn",            # Fake Out
    "FailsIfUserDamagedThisTurn",                     # Focus Punch
    "FailsIfUserHasUnusedMove",                       # Last Resort
    "FailsIfTargetHasNoItem",                         # Poltergeist
    "RemoveTerrain",                                  # Steel Roller
    "UserLosesHalfOfTotalHP",                         # Steel Beam
    "HealUserByHalfOfDamageDoneIfTargetAsleep",       # Dream Eater
    "AttackAndSkipNextTurn",                          # Hyper Beam, Giga Impact, etc.
    "TwoTurnAttackInvulnerableInSkyTargetCannotAct",  # Sky Drop
    "UserFaintsExplosive",                            # Self-Destruct, Explosion, etc.
    "UserFaintsPowersUpInMistyTerrainExplosive",      # Misty Explosion
    "SwitchOutTargetDamagingMove",                    # Circle Throw, Dragon Tail, etc.
    "TypeDependsOnUserIVs",                           # Hidden Power
    "LowerUserSpAtk2",                                # Overheat, Draco Meteor, etc.
    "CategoryDependsOnHigherDamageTera"	              # Tera Blast
  ]
  blacklist += [
    "TwoTurnAttackInvulnerableInSky",                 # Fly
    "TwoTurnAttackInvulnerableUnderground",           # Dig
    "TwoTurnAttackInvulnerableUnderwater",            # Dive
    "FailsIfUserNotConsumedBerry",                    # Belch
    "DoubleDamageOnDynamaxTargets"                    # Behemoth Blade, Dynamax Cannon, etc.
  ] if rental
  #-----------------------------------------------------------------------------
  # Eligible support moves.
  #-----------------------------------------------------------------------------
  whitelist  = [
    "HealUserHalfOfTotalHP",                          # Recover
    "HealUserHalfOfTotalHPLoseFlyingTypeThisTurn",    # Roost
    "HealUserDependingOnWeather",                     # Moonlight, Morning Sun, etc.
    "HealUserDependingOnSandstorm",                   # Shore Up
    "HealUserAndAlliesQuarterOfTotalHP",              # Life Dew
    "HealUserAndAlliesQuarterOfTotalHPCureStatus",    # Jungle Healing
    "HealUserPositionNextTurn",                       # Wish
    "HealUserByTargetAttackLowerTargetAttack1",       # Strength Sap
    "StartHealUserEachTurn",                          # Aqua Ring
    "StartHealUserEachTurnTrapUserInBattle",          # Ingrain
    "StartLeechSeedTarget",                           # Leech Seed
    "StartUserSideImmunityToInflictedStatus",         # Safeguard
    "StartPreventCriticalHitsAgainstUserSide",        # Lucky Chant
    "StartWeakenPhysicalDamageAgainstUserSide",       # Reflect
    "StartWeakenSpecialDamageAgainstUserSide",        # Light Screen
    "CureUserPartyStatus",                            # Heal Bell, Aromatherapy, etc.
    "ProtectUserBanefulBunker",                       # Baneful Bunker
    "ProtectUserFromDamagingMovesObstruct",           # Obstruct
    "ProtectUserFromDamagingMovesKingsShield",        # King's Shield
    "ProtectUserFromTargetingMovesSpikyShield",       # Spiky Shield
    "ProtectUserSideFromMultiTargetDamagingMoves",    # Wide Guard
    "SetTargetTypesToWater",                          # Soak
    "SetTargetTypesToPsychic",                        # Magic Powder
    "TargetNextFireMoveDamagesTarget",                # Powder
    "LowerTargetSpeed1MakeTargetWeakerToFire",        # Tar Shot
    "DisableTargetStatusMoves",                       # Taunt
    "RaiseUserDefSpDef1",                             # Cosmic Power
    "RaiseUserDefense2",                              # Iron Defense
    "RaiseUserDefense3",                              # Cotton Guard
    "RaiseUserSpDef2",                                # Amnesia
    "RaiseUserEvasion2MinimizeUser",                  # Minimize
    "TwoTurnAttackRaiseUserSpAtkSpDefSpd2",           # Geomancy
    "LowerTargetEvasion1RemoveSideEffects",           # Defog
    "StartUserSideDoubleSpeed",                       # Tailwind
    "ResetAllBattlersStatStages",                     # Haze
    "InvertTargetStatStages",                         # Topsy-Turvy
    "TrapTargetInBattleLowerTargetDefSpDef1EachTurn", # Octolock
    "RaiseUserMainStats1TrapUserInBattle",            # No Retreat
    "RaiseUserAtkDefSpd1",                            # Victory Dance
    "SetUserAlliesAbilityToTargetAbility",            # Doodle
    "StartSaltCureTarget",                            # Salt Cure
    "ProtectUserFromDamagingSilkTrap",                # Silk Trap
    "RaiseAtkLowerDefTargetStat"                      # Spicy Extract
  ]
  whitelist += [
    "PowerUpAllyMove",                                # Helping Hand
    "SetTargetAbilityToInsomnia",                     # Worry Seed
    "SetUserAbilityToTargetAbility",                  # Role Play
    "NegateTargetAbility",                            # Gastro Acid
    "UseLastMoveUsed",                                # Copycat
    "TargetUsesItsLastUsedMoveAgain",                 # Instruct
    "HealTargetHalfOfTotalHP",                        # Heal Pulse
    "RedirectAllMovesToUser",                         # Follow Me, Rage Powder, etc.
    "RedirectAllMovesToTarget",                       # Spotlight
    "RaiseTargetAtkSpAtk2",                           # Decorate
    "RaiseUserAndAlliesAtkDef1",                      # Coaching
    "ProtectUser",                                    # Protect, Detect, etc.
    "ProtectUserSideFromDamagingMovesIfUserFirstTurn" # Mat Block
  ] if rental
  return blacklist, whitelist
end


#-------------------------------------------------------------------------------
# Sets up potential base rewards for this raid battle.
#-------------------------------------------------------------------------------
def raid_Rewards(species, rank = 1, bonus = 1, loot = nil)
  rewards   = []
  qty       = [1, (rank * bonus * 1.1).round].max
  qty80     = [1, (qty / 1.25).round].max
  qty50     = [1, (qty / 2).round].max
  qty25     = [1, (qty / 4).round].max
  #---------------------------------------------------------------------------
  # Reward hash.
  #---------------------------------------------------------------------------
  reward = {
    "ExpCandy"  => [:EXPCANDYXS, :EXPCANDYS, :EXPCANDYM, :EXPCANDYL, :EXPCANDYXL],
    "Berries"   => [:POMEGBERRY, :KELPSYBERRY, :QUALOTBERRY, :HONDEWBERRY, :GREPABERRY, :TAMATOBERRY],
    "Vitamins"  => [:HPUP, :PROTEIN, :IRON, :CALCIUM, :ZINC, :CARBOS],
    "Training"  => [:PPUP, :PPMAX, :ABILITYCAPSULE, :ABILITYPATCH, :BOTTLECAP, :GOLDBOTTLECAP],
    "TreasureA" => [:BALMMUSHROOM, :PEARLSTRING, :RELICGOLD, :RELICSTATUE, :RELICCROWN],
    "TreasureB" => [:BIGMUSHROOM, :BIGNUGGET, :BIGPEARL, :RELICSILVER, :RELICBAND],
    "TreasureC" => [:TINYMUSHROOM, :NUGGET, :PEARL, :RELICCOPPER, :RELICVASE],
    "BonusItem" => [:DYNAMAXCANDYXL, :MAXSOUP]
  }
  #---------------------------------------------------------------------------
  # Adds Exp. Candy rewards.
  #---------------------------------------------------------------------------
  case rank
  when 1
    rewards.push( 
      [reward["ExpCandy"][0], qty   + rand(3)],
      [reward["ExpCandy"][1], qty25 + rand(3)]
    )
  when 2
    rewards.push(
      [reward["ExpCandy"][0], qty   + rand(3)],
      [reward["ExpCandy"][1], qty50 + rand(3)]
    )
  when 3
    rewards.push(
      [reward["ExpCandy"][0], qty80 + rand(3)],
      [reward["ExpCandy"][1], qty   + rand(3)],
      [reward["ExpCandy"][2], qty25 + rand(3)]
    )
  when 4
    rewards.push(
      [reward["ExpCandy"][0], qty80 + rand(3)],
      [reward["ExpCandy"][1], qty   + rand(3)],
      [reward["ExpCandy"][2], qty50 + rand(3)]
    )
    rewards.push([reward["ExpCandy"][3], qty25 + rand(3)]) if rand(10) < 2
  when 5
    rewards.push([reward["ExpCandy"][0], qty50 + rand(3)]) if rand(10) < 6
    rewards.push(
      [reward["ExpCandy"][1], qty80 + rand(3)],
      [reward["ExpCandy"][2], qty   + rand(3)],
      [reward["ExpCandy"][3], qty50 + rand(3)],
      [reward["ExpCandy"][4], qty25 + rand(3)]
    )
  when 6
    rewards.push([reward["ExpCandy"][0], qty25 + rand(2)]) if rand(10) < 2
    rewards.push([reward["ExpCandy"][1], qty50 + rand(3)]) if rand(10) < 6
    rewards.push(
      [reward["ExpCandy"][2], qty80 + rand(3)],
      [reward["ExpCandy"][3], qty   + rand(3)],
      [reward["ExpCandy"][4], qty50 + rand(3)]
    )
  end
  #---------------------------------------------------------------------------
  # Adds specific item rewards.
  #---------------------------------------------------------------------------
  if rank > 2
    rewards.push([:RARECANDY, qty25 + rand(3)], 
                 [:DYNAMAXCANDY, qty25 + rand(3)])
    rewards.push([reward["BonusItem"].sample, 1]) if bonus >= 5
    trItem = GameData::Item.get_TR_from_type(GameData::Species.get(species).types)
    rewards.push([trItem, 1]) if trItem
  end
  if bonus > 2
    case GameData::Species.get(species).species
    # Max Honey
    when :VESPIQUEN, :URSARING, :URSALUNA
      rewards.push([:MAXHONEY, 1])
    # Max Mushrooms
    when :PARASECT, :BRELOOM, :AMOONGUS, :SHIINOTIC, :TOEDSCRUEL
      rewards.push([:MAXMUSHROOMS, 1])
    # Max Eggs
    when :CHANSEY, :BLISSEY
      rewards.push([:MAXEGGS, 1])
    # Max Scales
    when :GYARADOS, :KINGDRA, :MILOTIC, :LUVDISC, :SALAMENCE, :GARCHOMP
      rewards.push([:MAXSCALES, 1])
    # Max Plumage
    when :PIDGEOT, :FEAROW, :DODRIO, :ARTICUNO, :NOCTOWL, :XATU, :HOOH, 
         :SWELLOW, :PELIPPER, :STARAPTOR, :HONCHKROW, :CHATOT, :UNFEZANT, 
         :SWANNA, :BRAVIARY, :MANDIBUZZ, :ARCHEOPS, :TALONFLAME, :HAWLUCHA, 
         :DECIDUEYE, :TOUCANNON, :ORICORIO, :CORVIKNIGHT, :CRAMORANT, 
         :KILOWATTREL, :BOMBIRDIER, :SQUAWKABILLY
      rewards.push([:MAXPLUMAGE, 1])
    # Wishing Star
    when :ETERNATUS
      rewards.push([:WISHINGSTAR, 1])
    end
  end
  rewards.push([:ARMORITEORE, qty25 + rand(3)])
  #---------------------------------------------------------------------------
  # Adds general rewards.
  #---------------------------------------------------------------------------
  rewards.push([reward["Berries"].sample, qty50 + rand(3)])
  case rank
  when 3
    rewards.push([reward["Vitamins"].sample, qty25 + rand(3)])
    rewards.push([reward["TreasureC"].sample, 1]) if rand(10) < 1
  when 4
    rewards.push([reward["Vitamins"].sample, qty25 + rand(3)])
    rewards.push([reward["TreasureB"].sample, 1]) if rand(10) < 1
  when 5, 6
    rewards.push([reward["Vitamins"].sample, qty50 + rand(3)])
    rewards.push([reward["Training"].sample,  1]) if rand(10) < 1
    rewards.push([reward["TreasureA"].sample, 1]) if rand(10) < 1
  end
  return rewards
end