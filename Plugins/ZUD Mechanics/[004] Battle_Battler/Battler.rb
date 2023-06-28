#===============================================================================
# Core additions to the Battler class.
#===============================================================================
class Battle::Battler
  attr_accessor :power_index         # Saves the move index of a selected Power Move.
  attr_accessor :ignore_dynamax      # Flags whether HP changing effects should factor in the user's Dynamax HP or not.
  attr_accessor :selectedMoveIsZMove # Checks if the user's selected move is considered a Z-Move.
  attr_accessor :lastMoveUsedIsZMove # Checks if a Z-Move was the user's last selected move (even if it failed to trigger).
  
  #-----------------------------------------------------------------------------
  # Checks if the battler is in one of these modes.
  #-----------------------------------------------------------------------------
  def ultra?;        return @pokemon&.ultra?;        end
  def dynamax?;      return @pokemon&.dynamax?;      end
  def gmax?;         return @pokemon&.gmax?;         end
    
  #-----------------------------------------------------------------------------
  # Checks various Dynamax conditions.
  #-----------------------------------------------------------------------------
  def dynamax_able?; return @pokemon&.dynamax_able?; end
  def dynamax_boost; return @pokemon&.dynamax_boost; end
  def gmax_factor?;  return @pokemon&.gmax_factor?;  end
    
  #-----------------------------------------------------------------------------
  # Gets the non-Dynamax HP of a Pokemon.
  #-----------------------------------------------------------------------------
  def real_hp;       return @pokemon&.real_hp;       end
  def real_totalhp;  return @pokemon&.real_totalhp;  end
  
  #-----------------------------------------------------------------------------
  # Z-Moves
  #-----------------------------------------------------------------------------
  # Higher priority than:
  #   -Mega Evolution
  #   -Dynamax
  #   -Battle Styles
  #   -Terastallization
  #
  # Lower priority than:
  #   -Primal Reversion
  #   -Zodiac Powers
  #   -Ultra Burst
  #-----------------------------------------------------------------------------
  def hasZMove?
    return false if shadowPokemon?
    return false if mega? || primal? || dynamax? || inStyle? || tera? || celestial?
    return false if hasPrimal? || hasUltra? || hasZodiacPower?
    return hasCompatibleZMove?(@moves)
  end
  
  def hasCompatibleZMove?(move = nil)
    transform = @effects[PBEffects::Transform]
    newpoke   = @effects[PBEffects::TransformPokemon]
    species   = (transform) ? newpoke.species_data.id : nil
    return false if !self.item || !GameData::Item.get(self.item).is_z_crystal?
    return false if transform && GameData::Item.get(self.item).is_ultra_item?
    return @pokemon&.compat_zmove?(move, nil, species)
  end
  
  #-----------------------------------------------------------------------------
  # Ultra Burst
  #-----------------------------------------------------------------------------
  # Higher priority than:
  #   -Mega Evolution
  #   -Z-Moves
  #   -Dynamax
  #   -Battle Styles
  #   -Terastallization
  #
  # Lower priority than:
  #   -Primal Reversion
  #   -Zodiac Powers
  #-----------------------------------------------------------------------------
  def hasUltra?
    return false if shadowPokemon? || @effects[PBEffects::Transform]
    return false if mega? || primal? || ultra? || dynamax? || inStyle? || tera? || celestial?
    return false if hasPrimal? || hasZodiacPower?
    return @pokemon&.hasUltraForm?
  end
  
  #-----------------------------------------------------------------------------
  # Dynamax
  #-----------------------------------------------------------------------------
  # Higher priority than:
  #   -Battle Styles
  #   -Terastallization
  #
  # Lower priority than:
  #   -Primal Reversion
  #   -Zodiac Powers
  #   -Ultra Burst
  #   -Z-Moves
  #   -Mega Evolution
  #-----------------------------------------------------------------------------
  def hasDynamax?
    return false if shadowPokemon?
    return false if mega? || primal? || ultra? || dynamax? || inStyle? || tera? || celestial?
    return false if hasMega? || hasPrimal? || hasZMove? || hasUltra? || hasZodiacPower?
    return true if canEmax?
    pokemon = @effects[PBEffects::TransformPokemon] || self.displayPokemon
    return pokemon&.dynamax_able? && !pokemon.isSpecies?(:ETERNATUS)
  end
  
  def hasDynamaxAvail?
    return false if !hasDynamax?
    return false if !pbOwnedByPlayer? && !@battle.pbHasDynamaxBand?(@index)
    map_data = GameData::MapMetadata.try_get($game_map.map_id)
    return false if canEmax? && !($game_map && map_data&.has_flag?("EternaSpot"))
    return true if @battle.raid_battle && @battle.pbHasDynamaxBand?(@index)
    return false if @battle.wildBattle? && !$game_switches[Settings::CAN_DYNAMAX_WILD]
    return true if $game_switches[Settings::DYNAMAX_ANY_MAP] && @battle.pbHasDynamaxBand?(@index)
    return $game_map && map_data&.has_flag?("PowerSpot") && @battle.pbHasDynamaxBand?(@index)
  end
  
  def hasGmax?
    return false if !hasDynamax?
    return @pokemon&.hasGmax?
  end
  
  def canGmax?
    return hasGmax? && gmax_factor?
  end
  
  def canEmax?
    return false if @effects[PBEffects::Transform] || @effects[PBEffects::Illusion]
    return @pokemon&.canEmax?
  end
  
  #-----------------------------------------------------------------------------
  # Reverts the effects of Dynamax.
  #-----------------------------------------------------------------------------
  def unmax
    @pokemon.dynamax = false
    pbUpdate
    @pokemon.reversion = false
    if !@effects[PBEffects::MaxRaidBoss]
	  self.display_base_moves
	  @power_trigger = false
	  @effects[PBEffects::Dynamax] = 0
	  @battle.scene.pbRefreshOne(@index)
      @battle.scene.pbRevertDynamax(@index)
      @battle.scene.pbHPChanged(self, totalhp) if !fainted?
    end
  end
end