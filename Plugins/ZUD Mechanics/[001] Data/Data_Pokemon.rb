#===============================================================================
# New Pokemon properties.
#===============================================================================
class Pokemon
  #-----------------------------------------------------------------------------
  # Dynamax Levels
  #-----------------------------------------------------------------------------
  def dynamax_lvl
    return @dynamax_lvl || 0
  end
  
  def dynamax_lvl=(value)
    @dynamax_lvl = (dynamax_able?) ? value : 0
    @dynamax_lvl = 10 if dynamax_lvl > 10
    @dynamax_lvl = 0  if dynamax_lvl < 0
  end
  
  def raid_dmax_lvl=(value)
    @dynamax_lvl = (dynamax_able?) ? value : 0
    @dynamax_lvl = 0 if dynamax_lvl < 0
  end
    
  #-----------------------------------------------------------------------------
  # G-Max Factor
  #-----------------------------------------------------------------------------  
  def gmax_factor?
    return @gmax_factor || false
  end
  
  def gmax_factor=(value)
    @gmax_factor = (dynamax_able?) ? value : false
  end
    
  #-----------------------------------------------------------------------------
  # Dynamax states
  #-----------------------------------------------------------------------------
  def dynamax?
    return @dynamax || false
  end
    
  def dynamax=(value)
    if tera?
      self.unmax
    else
      @gmax_factor = value if species_data.id == :ETERNATUS
      @dynamax  = (dynamax_able?) ? value  : false
      @reverted = (dynamax_able?) ? !value : false
      $player&.pokedex&.register(self)
    end
  end
  
  def reverted?
    return @reverted || false
  end

  def reversion=(value)
    @reverted = (dynamax_able?) ? value : false
  end
  
  def unmax
    if dynamax?
      @dynamax = false
      @reverted = true
    end
    calc_stats
    @reverted = false
  end
  
  def dynamax_able?
    return false if egg? || shadowPokemon? || tera? || celestial?
    return (!@dynamax_able.nil?) ? @dynamax_able : !species_data.no_dynamax
  end
  
  def dynamax_able=(value)
    if species_data.no_dynamax
      @dynamax_able = false
    else
      @dynamax_able = value
    end
  end
  
  def should_force_revert?
    return true if shadowPokemon? || celestial?
    return true if !@dynamax_able && !@dynamax_able.nil?
    in_battle_form = (mega? || primal? || ultra? || tera?)
    return true if (dynamax? || reverted?) && in_battle_form
    return true if species_data.no_dynamax && !in_battle_form
    return false
  end
  
  #-----------------------------------------------------------------------------
  # Dynamax forms
  #-----------------------------------------------------------------------------
  def hasGmax?
    return false if !dynamax_able?
    species_list = GameData::PowerMove.species_list("G-Max")
    species_list.each { |sp| return true if sp == species_data.id }
    return false
  end
  
  def canGmax?
    return (hasGmax? && gmax_factor?)
  end
  
  def gmax?
    if dynamax? && gmax_factor?
      return true if hasGmax? || species_data.id == :ETERNATUS
    end
    return false
  end
  
  def canEmax?
    return false if !dynamax_able?
    return (species_data.id == :ETERNATUS && gmax_factor?)
  end
  
  def play_cry(volume = 90, pitch = nil)
    if dynamax?
      volume = 100
      if gmax?
        try_form = "Cries/Gigantamax/#{species_data.id}"
        try_species = "Cries/Gigantamax/#{species_data.species}"
        if !pbResolveAudioSE(try_form) && !pbResolveAudioSE(try_species)
          pitch = 60
        end
      else
        try_form = "Cries/Dynamax/#{species_data.id}"
        try_species = "Cries/Dynamax/#{species_data.species}"
        if !pbResolveAudioSE(try_form) && !pbResolveAudioSE(try_species)
          pitch = 60
        end
      end
    end
    GameData::Species.play_cry_from_pokemon(self, volume, pitch)
  end
  
  #-----------------------------------------------------------------------------
  # Ultra Burst states
  #-----------------------------------------------------------------------------
  def getUltraForm
    return 0 if !compat_ultra?(self.item) 
    return GameData::PowerMove.ultra_from(self.item, species_data.id)
  end

  def getUnUltraForm
    ret = -1
    GameData::PowerMove.each do |data|
      next if !data.ultra?
      species = GameData::Species.get(data.species.first).species
      ultra_species = (species.to_s + "_" + data.ultra.to_s).to_sym
      next if species_data.id != ultra_species
      ret = GameData::Species.get(data.species.first).form
    end
    return ret
  end

  def hasUltraForm?
    ultraForm = self.getUltraForm
    return ultraForm > 0 && ultraForm != form_simple
  end

  def ultra?
    baseForm = self.getUnUltraForm
    return baseForm != -1
  end

  def makeUltra
    ultraForm = self.getUltraForm
    self.form = ultraForm if ultraForm > 0
  end

  def makeUnUltra
    unUltraForm = self.getUnUltraForm
    self.form = unUltraForm if unUltraForm >= 0
  end

  def ultraName
    formName = species_data.form_name
    return (formName && !formName.empty?) ? formName : _INTL("Ultra {1}", species_data.name)
  end
    
  #-----------------------------------------------------------------------------
  # Power Move compatibility checks.
  #-----------------------------------------------------------------------------  
  def compat_zmove?(param, equipping = nil, transform = nil)
    return false if egg? || shadowPokemon? || celestial?
    item    = (equipping) ? equipping : self.item
    species = (transform) ? transform : self.species_data.id
    return GameData::PowerMove.compat?("Z-Move", param, item, species)
  end
  
  def compat_ultra?(equipping = nil)
    return false if egg? || shadowPokemon? || celestial?
    item = (equipping) ? equipping : self.item
    return GameData::PowerMove.compat?("Ultra", item, self.species_data.id)
  end
  
  def compat_maxmove?(param, transform = nil)
    return false if egg? || shadowPokemon? || celestial?
    species = (transform) ? transform : self.species_data.id
    return GameData::PowerMove.compat?("Max Move", param, species)
  end
  
  #-----------------------------------------------------------------------------
  # Returns the ID of a Power Move compatible with the inputted parameters.
  #-----------------------------------------------------------------------------
  def get_zmove(param, item = nil, transform = nil)
    return nil if !compat_zmove?(param, nil, transform) && !item.nil?
    species = (transform) ? transform : self.species_data.id
    return GameData::PowerMove.zmove_from(param, item, species)
  end  
    
  def get_maxmove(param, category = nil, transform = nil)
    return nil if !compat_maxmove?(param, transform)
    return :MAXGUARD if category == 2
    species = (transform) ? transform : self.species_data.id
    gmax = GameData::Species.get(species).hasGmax? && self.gmax_factor?
    return GameData::PowerMove.maxmove_from(param, species, gmax)
  end
  
  #-----------------------------------------------------------------------------
  # Stat Calculations
  #-----------------------------------------------------------------------------
  def real_hp;         return @hp / dynamax_boost;                end
  def real_totalhp;    return @totalhp / dynamax_boost;           end
  def dynamax_calc;    return (1.5 + (dynamax_lvl.to_f * 0.05));  end
  def dynamax_boost;   return (dynamax?) ? dynamax_calc : 1;      end
  
  def calcHP(base, level, iv, ev)
    return 1 if base == 1
    return ((((base * 2 + iv + (ev / 4)) * level / 100).floor + level + 10) * dynamax_boost).ceil
  end
  
  def calc_stats
    # Forces an ineligible Pokemon to un-Dynamax.
    if should_force_revert?
      @reverted = true if dynamax?
      @dynamax = false
      @gmax_factor = false
    end
    base_stats = self.baseStats
    this_level = self.level
    this_IV    = self.calcIV
    nature_mod = {}
    GameData::Stat.each_main { |s| nature_mod[s.id] = 100 }
    this_nature = self.nature_for_stats
    if this_nature
      this_nature.stat_changes.each { |change| nature_mod[change[0]] += change[1] }
    end
    stats = {}
    GameData::Stat.each_main do |s|
      if s.id == :HP
        stats[s.id] = calcHP(base_stats[s.id], this_level, this_IV[s.id], @ev[s.id])
      else
        stats[s.id] = calcStat(base_stats[s.id], this_level, this_IV[s.id], @ev[s.id], nature_mod[s.id])
      end
    end
    # Dynamax HP calcs
    old_hp_diff = @totalhp - @hp # For Eternatus
    if dynamax? && !reverted?
      @totalhp = stats[:HP]
      self.hp  = (@hp * dynamax_calc).ceil
      self.hp  = [@totalhp - old_hp_diff, 1].max if canEmax?
    elsif reverted? && !dynamax?
      @totalhp = stats[:HP]
      self.hp  = (@hp / dynamax_calc).round
      self.hp  = [@totalhp - old_hp_diff, 1].max if canEmax?
    else
      hp_difference = stats[:HP] - @totalhp
      @totalhp = stats[:HP]
      self.hp = [@hp + hp_difference, 1].max if @hp > 0 || hp_difference > 0
    end
    @attack  = stats[:ATTACK]
    @defense = stats[:DEFENSE]
    @spatk   = stats[:SPECIAL_ATTACK]
    @spdef   = stats[:SPECIAL_DEFENSE]
    @speed   = stats[:SPEED]
    # Resets remaining Dynamax attributes for ineligible Pokemon.
    if should_force_revert?
      @dynamax_lvl = 0
      @reverted = false
      @dynamax_able = false
    end
  end
  
  def calc_lair_evs
    GameData::Stat.each_main { |s| @ev[s.id] = 0 }
    rand_ev = rand(6)
    case rand_ev
    when 0 then GameData::Stat.each_main { |s| @ev[s.id] = 50 }
    else
      GameData::Stat.each_main do |s|
        next if s.pbs_order != rand_ev
        @ev[s.id] = 252
        break
      end
    end
    @ev[:HP] = 252
    self.calc_stats
  end
  
  alias zud_initialize initialize  
  def initialize(*args)
    @dynamax_lvl  = 0
    @dynamax      = false
    @reverted     = false
    @gmax_factor  = false
    @dynamax_able = nil
    zud_initialize(*args)
  end
  
  
  #-----------------------------------------------------------------------------
  # Pokemon move attributes.
  #-----------------------------------------------------------------------------
  class Move
    attr_accessor :old_move
	
    alias zud_initialize initialize
    def initialize(move_id)
      zud_initialize(move_id)
      @old_move = nil
    end
  
    def zMove?;     return GameData::Move.get(@id).zMove?;     end
    def maxMove?;   return GameData::Move.get(@id).maxMove?;   end
    def powerMove?; return GameData::Move.get(@id).powerMove?; end
  end
end


#===============================================================================
# Form handler for Eternamax Eternatus.
#===============================================================================
MultipleForms.register(:ETERNATUS,{
  "baseStats" => proc { |pkmn|
    next if !pkmn.gmax?
    next {
      :HP              => 255,
      :ATTACK          => 115,
      :DEFENSE         => 250,
      :SPEED           => 130,
      :SPECIAL_ATTACK  => 125,
      :SPECIAL_DEFENSE => 250
    }
  }
})