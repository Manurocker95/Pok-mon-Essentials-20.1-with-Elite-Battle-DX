#===============================================================================
# Additions to the Battler class specific to converting the user's moves.
#===============================================================================
class Battle::Battler
  #-----------------------------------------------------------------------------
  # Converts base moves into Power Moves.
  #-----------------------------------------------------------------------------
  def display_power_moves(mode = 0)
    # Set "mode" to 1 to convert to Z-Moves.
    # Set "mode" to 2 to convert to Max Moves.
    transform = @effects[PBEffects::TransformSpecies]
    for i in 0...@moves.length
      @base_moves.push(@moves[i])
      # Z-Moves
      case mode
      when 1, "Z-Move"
        next if !@pokemon.compat_zmove?(@moves[i], nil, transform)
        @moves[i]          = convert_zmove(@moves[i], @pokemon.item, transform)
        @moves[i].pp       = [1, @base_moves[i].pp].min
        @moves[i].total_pp = 1
      # Max Moves
      when 2, "Max Move"
        @moves[i]          = convert_maxmove(@moves[i], transform)
        @moves[i].pp       = @base_moves[i].pp   
        @moves[i].total_pp = @base_moves[i].total_pp
      end
    end
  end
  
  #-----------------------------------------------------------------------------
  # Gets a battler's Z-Move based on the inputted base move.
  #-----------------------------------------------------------------------------
  def convert_zmove(move, item = nil, transform = nil)
    if move.statusMove?
      poke_move = Pokemon::Move.new(move.id)
    else
      id = @pokemon.get_zmove(move, item, transform)
      poke_move = Pokemon::Move.new(id)
    end
    poke_move.old_move = move
    return Battle::PowerMove.from_pokemon_move(@battle, poke_move)
  end
  
  #-----------------------------------------------------------------------------
  # Gets a battler's Max Move based on the inputted base move.
  #-----------------------------------------------------------------------------
  def convert_maxmove(move, transform = nil)
    id = @pokemon.get_maxmove(move, move.category, transform)
    poke_move = Pokemon::Move.new(id)
    poke_move.old_move = move
    return Battle::PowerMove.from_pokemon_move(@battle, poke_move)
  end
  
  #-----------------------------------------------------------------------------
  # Effects that may change a Power Move into one of a different type.
  #-----------------------------------------------------------------------------
  def calc_power_move(move)
    if move.powerMove?
      base_move = @base_moves[@power_index]
      return move if move.function == "ZUDProtectUser"
      return move if ["TypeDependsOnUserIVs", 
                      "TypeAndPowerDependOnUserBerry"].include?(base_move.function)
      newtype = base_move.pbCalcType(self)
      if GameData::Type.exists?(newtype) && newtype != move.type
        transform = @effects[PBEffects::TransformSpecies]
        if move.zMove?
          z_move    = @pokemon.get_zmove(newtype, nil, transform)
          poke_move = Pokemon::Move.new(z_move)
          poke_move.old_move = base_move
          return Battle::PowerMove.from_pokemon_move(@battle, poke_move)
        elsif move.maxMove?
          max_move  = @pokemon.get_maxmove(newtype, nil, transform)
          poke_move = Pokemon::Move.new(max_move)
          poke_move.old_move = base_move
          return Battle::PowerMove.from_pokemon_move(@battle, poke_move)
        end
      end
    end
    return move
  end
end