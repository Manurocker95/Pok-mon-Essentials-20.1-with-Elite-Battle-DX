#===============================================================================
# The "Power Move" class, which handles all Z-Move & Max Move compatibily data.
#===============================================================================
module GameData
  class PowerMove
    attr_reader :id
    # [ZMOVE], [ULTRA], [GMAX]
    attr_reader :zmove, :ultra, :maxmove
    attr_reader :type, :item, :move, :species, :flag
    # [ZSTATUS]
    attr_reader :status_atk,   :atk_1,   :atk_2,   :atk_3
    attr_reader :status_def,   :def_1,   :def_2,   :def_3
    attr_reader :status_spatk, :spatk_1, :spatk_2, :spatk_3
    attr_reader :status_spdef, :spdef_1, :spdef_2, :spdef_3 
    attr_reader :status_speed, :speed_1, :speed_2, :speed_3
    attr_reader :status_acc,   :acc_1,   :acc_2,   :acc_3
    attr_reader :status_eva,   :eva_1,   :eva_2,   :eva_3 
    attr_reader :status_omni,  :omni_1,  :omni_2,  :omni_3
    attr_reader :status_heal,  :heal_1,  :heal_2
    attr_reader :status_crit,  :crit
    attr_reader :status_reset, :reset
    attr_reader :status_focus, :focus
    
    DATA = {}
    DATA_FILENAME = "power_moves.dat"

    SCHEMA = {
      #-------------------------------------------------------------------------
      # Power Move categories
      #-------------------------------------------------------------------------
      "ZMove"           => [:zmove,   "e",   :Move],
      "MaxMove"         => [:maxmove, "e",   :Move],
      #-------------------------------------------------------------------------
      # Power Move data
      #-------------------------------------------------------------------------
      "Type"            => [:type,    "e",   :Type],
      "Item"            => [:item,    "e",   :Item],
      "Move"            => [:move,    "e",   :Move],
      "Species"         => [:species, "*e",  :Species],
      "Flag"            => [:flag,    "s"],
      #-------------------------------------------------------------------------
      # Ultra Burst form
      #-------------------------------------------------------------------------
      "Ultra"           => [:ultra, "u"],
      #-------------------------------------------------------------------------
      # Species data
      #-------------------------------------------------------------------------
      "Name"            => [0, "q"],
      "Height"          => [0, "f"],
      "Pokedex"         => [0, "q"],
      #-------------------------------------------------------------------------
      # Status Z-Move effects
      #-------------------------------------------------------------------------
      "AtkBoost1"       => [:atk_1,    "*e",  :Move],
      "AtkBoost2"       => [:atk_2,    "*e",  :Move],
      "AtkBoost3"       => [:atk_3,    "*e",  :Move],
      
      "DefBoost1"       => [:def_1,    "*e",  :Move],
      "DefBoost2"       => [:def_2,    "*e",  :Move], # Not used by any existing moves.
      "DefBoost3"       => [:def_3,    "*e",  :Move], # Not used by any existing moves.
      
      "SpAtkBoost1"     => [:spatk_1,  "*e",  :Move],
      "SpAtkBoost2"     => [:spatk_2,  "*e",  :Move],
      "SpAtkBoost3"     => [:spatk_3,  "*e",  :Move], # Not used by any existing moves.
      
      "SpDefBoost1"     => [:spdef_1,  "*e",  :Move],
      "SpDefBoost2"     => [:spdef_2,  "*e",  :Move],
      "SpDefBoost3"     => [:spdef_3,  "*e",  :Move], # Not used by any existing moves.
      
      "SpeedBoost1"     => [:speed_1,  "*e",  :Move],
      "SpeedBoost2"     => [:speed_2,  "*e",  :Move],
      "SpeedBoost3"     => [:speed_3,  "*e",  :Move], # Not used by any existing moves.
      
      "AccBoost1"       => [:acc_1,    "*e",  :Move],
      "AccBoost2"       => [:acc_2,    "*e",  :Move], # Not used by any existing moves.
      "AccBoost3"       => [:acc_3,    "*e",  :Move], # Not used by any existing moves.
      
      "EvaBoost1"       => [:eva_1,    "*e",  :Move],
      "EvaBoost2"       => [:eva_2,    "*e",  :Move], # Not used by any existing moves.
      "EvaBoost3"       => [:eva_3,    "*e",  :Move], # Not used by any existing moves.
      
      "OmniBoost1"      => [:omni_1,   "*e",  :Move],
      "OmniBoost2"      => [:omni_2,   "*e",  :Move], # Not used by any existing moves.
      "OmniBoost3"      => [:omni_3,   "*e",  :Move], # Not used by any existing moves.
      
      "HealUser"        => [:heal_1,   "*e",  :Move],
      "HealSwitch"      => [:heal_2,   "*e",  :Move],
      
      "CritBoost"       => [:crit,     "*e",  :Move],
      "ResetStats"      => [:reset,    "*e",  :Move],
      "FocusOnUser"     => [:focus,    "*e",  :Move]
    }

    extend ClassMethodsSymbols
    include InstanceMethods

    def initialize(hash)
      @id      = hash[:id]
      # [ZMOVE], [ULTRA], [GMAX]
      @zmove   = hash[:zmove]
      @ultra   = hash[:ultra]
      @maxmove = hash[:maxmove]
      @type    = GameData::Type.exists?(@id) ? @id : hash[:type]
      @item    = hash[:item]
      @move    = hash[:move]
      @gmax    = @id.to_s.include?("GMAX")
      @species = hash[:species] || []
      @flag    = hash[:flag]
      # [ZSTATUS]
      if @id == :ZSTATUS
        @status_atk   = { 1 => hash[:atk_1]   || [],
                          2 => hash[:atk_2]   || [],   
                          3 => hash[:atk_3]   || []
                        }
        @status_def   = { 1 => hash[:def_1]   || [],
                          2 => hash[:def_2]   || [],   
                          3 => hash[:def_3]   || []
                        }
        @status_spatk = { 1 => hash[:spatk_1] || [], 
                          2 => hash[:spatk_2] || [], 
                          3 => hash[:spatk_3] || []
                        }
        @status_spdef = { 1 => hash[:spdef_1] || [],
                          2 => hash[:spdef_2] || [],
                          3 => hash[:spdef_3] || []
                        }
        @status_speed = { 1 => hash[:speed_1] || [],
                          2 => hash[:speed_2] || [],
                          3 => hash[:speed_3] || []
                        }
        @status_acc   = { 1 => hash[:acc_1]   || [],
                          2 => hash[:acc_2]   || [],
                          3 => hash[:acc_3]   || []
                        }
        @status_eva   = { 1 => hash[:eva_1]   || [],
                          2 => hash[:eva_2]   || [],
                          3 => hash[:eva_3]   || []
                        }
        @status_omni  = { 1 => hash[:omni_1]  || [],
                          2 => hash[:omni_2]  || [],
                          3 => hash[:omni_3]  || []
                        }
        @status_heal  = { 1 => hash[:heal_1]  || [],
                          2 => hash[:heal_2]  || []
                        }
        @status_crit  = hash[:crit]  || []
        @status_reset = hash[:reset] || []
        @status_focus = hash[:focus] || []
      end
    end
    
    #---------------------------------------------------------------------------
    # Utilities for checking Power Move data.
    #---------------------------------------------------------------------------
    def z_move?;    return !@zmove.nil?;   end
    def ultra?;     return !@ultra.nil?;   end
    def max_move?;  return !@maxmove.nil?; end
      
    def generic?;   return GameData::Type.exists?(@id); end
    def exclusive?; return @species.length > 0; end
    def gmax?;      return @gmax; end
    
    #---------------------------------------------------------------------------
    # Returns total number of Power Moves, or number of specific Power Moves.
    #---------------------------------------------------------------------------
    def self.get_count(mode = 0)
      num = 0
      self.each do |pm|
	    case mode
        when 1, "Z-Move";   num += 1 if pm.z_move?
        when 2, "Max Move"; num += 1 if pm.max_move?
        else; num += 1
        end
      end
      return num
    end
    
    #---------------------------------------------------------------------------
    # Returns a list of all species with an exclusive Z-Move, Ultra form, or G-Max form.
    #---------------------------------------------------------------------------
    def self.species_list(mode = 0)
      species_list = []
      self.each do |pm|
        next if !pm.exclusive?
        case mode
        when 1, "Z-Move"; next if !pm.z_move?
        when 2, "Ultra";  next if !pm.ultra?
        when 3, "G-Max";  next if !pm.gmax?
        end
        for species in pm.species
          species_list.push(species)
        end
      end
      return species_list
    end
    
    #---------------------------------------------------------------------------
    # Returns a required Z-Crystal based on the inputted Type.
    #---------------------------------------------------------------------------
    def self.item_from(type)
      self.each do |pm|
        next if !pm.generic?
        return @item if type == pm.type
      end
    end
    
    #---------------------------------------------------------------------------
    # Returns true when all inputted parameters are compatible.
    #---------------------------------------------------------------------------
    def self.compat?(mode, *params)
      case mode
      when 0, "Z-Move";   return !zmove_from(*params).nil?
      when 1, "Ultra";    return !ultra_from(*params).nil?
      when 2, "Max Move"; return !maxmove_from(*params).nil?
      end
    end
    
    #---------------------------------------------------------------------------
    # Returns a Z-Move based on the inputted parameters.
    # Parameters can be any of the following (or an array containing the following):
    # Battle::Move, Battle::PowerMove, Pokemon::Move, GameData::Move, GameData::Type
    #---------------------------------------------------------------------------
    def self.zmove_from(param, item, species)
      ret = nil
      self.each do |pm|
        next if !pm.z_move?
        next if pm.exclusive? && !pm.species.include?(species)
        if item == pm.item || item.nil?
          case param
          # When param is a list of moves
          when Array
            param.each do |move|
              if move.id == pm.move || move.type == pm.type
                ret = pm.zmove
              end
            end
          # When param is a Z-Move
          when Battle::PowerMove
            ret = pm.zmove if param.id == pm.zmove			
          # When param is a move
          when Battle::Move, Pokemon::Move
            if param.id == pm.move || param.id == pm.zmove || param.type == pm.type
              ret = pm.zmove
            end
          else
            # When param is a Move ID
            if GameData::Move.exists?(param)
              ret = pm.zmove if param == pm.move || param == pm.zmove
              ret = pm.zmove if GameData::Move.get(param).type == pm.type
            # When param is a Type ID
            elsif GameData::Type.exists?(param)
              ret = pm.zmove if param == pm.type
            end
          end
        end
      end
      return ret
    end
	
    #---------------------------------------------------------------------------
    # Returns an Ultra Form based on the inputted item and species.
    #---------------------------------------------------------------------------
    def self.ultra_from(item, species)
      ret = nil
      self.each do |pm|
        next if !pm.ultra?
        next if !pm.species.include?(species)
        if item == pm.item
          ret = pm.ultra
        end
      end
      return ret
    end
    
    #---------------------------------------------------------------------------
    # Returns a Max Move based on the inputted parameters.
    # Parameters can be any of the following (or an array containing the following):
    # Battle::Move, Battle::PowerMove, Pokemon::Move, GameData::Move, GameData::Type
    #---------------------------------------------------------------------------
    def self.maxmove_from(param, species, gmax = false)
      ret = nil
      self.each do |pm|
        next if !pm.max_move?
        next if pm.exclusive? && (!pm.species.include?(species) || !gmax)
        case param
        # When param is a list of moves
        when Array
          param.each { |move| ret = pm.maxmove if move.type == pm.type }
        # When param is a Max Move
        when Battle::PowerMove
          ret = pm.maxmove if param.id == pm.maxmove
        # When param is a move
        when Battle::Move, Pokemon::Move
          ret = pm.maxmove if param.type == pm.type
        else
          # When param is a Move ID
          if GameData::Move.exists?(param)
            ret = pm.maxmove if GameData::Move.get(param).type == pm.type
          # When param is a Type ID
          elsif GameData::Type.exists?(param)
            ret = pm.maxmove if param == pm.type
          end
        end
      end
      return ret
    end
    
    #---------------------------------------------------------------------------
    # Functions for Z-Powered status moves
    #---------------------------------------------------------------------------
    def self.stat_booster?(move)
      data = self.get(:ZSTATUS)
      data.status_atk.keys.each   { |key| return true if data.status_atk[key].include?(move) }
      data.status_def.keys.each   { |key| return true if data.status_def[key].include?(move) }
      data.status_spatk.keys.each { |key| return true if data.status_spatk[key].include?(move) }
      data.status_spdef.keys.each { |key| return true if data.status_spdef[key].include?(move) }
      data.status_speed.keys.each { |key| return true if data.status_speed[key].include?(move) }
      data.status_acc.keys.each   { |key| return true if data.status_acc[key].include?(move) }
      data.status_eva.keys.each   { |key| return true if data.status_eva[key].include?(move) }
      data.status_omni.keys.each  { |key| return true if data.status_omni[key].include?(move) }
      return false
    end
    
    def self.stat_with_stage(move)
      return if !self.stat_booster?(move)
      data = self.get(:ZSTATUS)
      for stage in 1..3
        if data.status_atk[stage].include?(move);      stats = [:ATTACK] 
        elsif data.status_def[stage].include?(move);   stats = [:DEFENSE]
        elsif data.status_spatk[stage].include?(move); stats = [:SPECIAL_ATTACK]
        elsif data.status_spdef[stage].include?(move); stats = [:SPECIAL_DEFENSE]
        elsif data.status_speed[stage].include?(move); stats = [:SPEED]
        elsif data.status_acc[stage].include?(move);   stats = [:ACCURACY]
        elsif data.status_eva[stage].include?(move);   stats = [:EVASION]
        elsif data.status_omni[stage].include?(move)
          stats = [:ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED]
        end
        if stats
          return stats, stage
        end
      end
    end
    
    def self.heals_self?(move)
      return self.get(:ZSTATUS).status_heal[1].include?(move)
    end
    
    def self.heals_switch?(move)
      return self.get(:ZSTATUS).status_heal[2].include?(move)
    end    

    def self.boosts_crit?(move)
      return self.get(:ZSTATUS).status_crit.include?(move)
    end
    
    def self.resets_stats?(move)
      return self.get(:ZSTATUS).status_reset.include?(move)
    end

    def self.focus_user?(move)
      return self.get(:ZSTATUS).status_focus.include?(move)
    end
  end
  
  
  #-----------------------------------------------------------------------------
  # Move flags
  #-----------------------------------------------------------------------------
  class Move
    def zMove?;     return self.flags.any? { |f| f[/^ZMove$/i] };   end
    def maxMove?;   return self.flags.any? { |f| f[/^MaxMove$/i] }; end
    def powerMove?; return zMove? || maxMove?; end
	
    def name
      ret = pbGetMessageFromHash(MessageTypes::Moves, @real_name)
      ret.gsub!("_", ",")
      return ret
    end
  end
  
  
  #-----------------------------------------------------------------------------
  # Loads Power Move data
  #-----------------------------------------------------------------------------
  GameData.singleton_class.alias_method :zud_load_all, :load_all
  def self.load_all
    self.zud_load_all
    PowerMove.load
  end
end