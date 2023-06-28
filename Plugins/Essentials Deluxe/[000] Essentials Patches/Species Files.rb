#===============================================================================
# Revamps all base Essentials code related to obtaining Pokemon sprite or audio
# files, to allow for plugin compatibility.
#===============================================================================


#-------------------------------------------------------------------------------
# Species parameter hashes
#-------------------------------------------------------------------------------
def species_sprite_params(*params)
  data = {
    :species   => params[0] || nil,
    :form      => params[1] || 0,
    :gender    => params[2] || 0,
    :shiny     => params[3] || false,
    :shadow    => params[4] || false,
    :back      => params[5] || false,
    :egg       => params[6] || false,
    :dmax      => params[7] || false,
    :gmax      => params[8] || false,
    :celestial => params[9] || false
  }
  return data
end

def species_sprite_params2(*params)
  data = {
    :species   => params[0] || nil,
    :form      => params[2] || 0,
    :gender    => params[1] || 0,
    :shiny     => params[3] || false,
    :shadow    => params[4] || false,
    :back      => params[5] || false,
    :egg       => params[6] || false,
    :dmax      => params[7] || false,
    :gmax      => params[8] || false,
    :celestial => params[9] || false
  }
  return data
end

def species_icon_params(*params)
  data = {
    :species   => params[0] || nil,
    :form      => params[1] || 0,
    :gender    => params[2] || 0,
    :shiny     => params[3] || false,
    :shadow    => params[4] || false,
    :egg       => params[5] || false,
    :dmax      => params[6] || false,
    :gmax      => params[7] || false,
    :celestial => params[8] || false
  }
  return data
end

def species_cry_params(*params)
  data = {
    :species   => params[0] || nil,
    :form      => params[1] || 0,
    :suffix    => params[2] || "",
    :shiny     => params[3] || false,
    :shadow    => params[4] || false,
    :dmax      => params[5] || false,
    :gmax      => params[6] || false,
    :celestial => params[7] || false
  }
  return data
end


#-------------------------------------------------------------------------------
# Species files
#-------------------------------------------------------------------------------
module GameData
  class Species
    def self.check_graphic_file(path, params, subfolder = "")
      species   = params[:species]
      form      = params[:form]
      gender    = params[:gender]
      shiny     = params[:shiny]
      shadow    = params[:shadow]
      dmax      = params[:dmax]
      gmax      = params[:gmax]
      celestial = params[:celestial]
      try_species = species
      try_form    = (form > 0)    ? sprintf("_%d", form) : ""
      try_gender  = (gender == 1) ? "_female"    : ""
      try_shadow  = (shadow)      ? "_shadow"    : ""
      try_dmax    = (dmax)        ? "_dmax"      : ""
      try_gmax    = (gmax)        ? "_gmax"      : ""
      try_celest  = (celestial)   ? "_celestial" : ""
      subfolder_tries = []
      if !nil_or_empty?(subfolder)
        if gmax
          subfolder_tries.push(" super shiny/Gigantamax/") if shiny == :super_shiny
          subfolder_tries.push(" shiny/Gigantamax/") if shiny
          subfolder_tries.push("/Gigantamax/")
        end
        if dmax
          subfolder_tries.push(" super shiny/Dynamax/") if shiny == :super_shiny
          subfolder_tries.push(" shiny/Dynamax/") if shiny
          subfolder_tries.push("/Dynamax/")
        end
        if shiny
          subfolder_tries.push(" super shiny/") if shiny == :super_shiny
          subfolder_tries.push(" shiny/")
        end
        subfolder_tries.push("/")
      end
      subfolder_tries.push("")
      factors = []
      factors.push([6, try_celest, ""]) if celestial
      factors.push([5, try_gmax,   ""]) if gmax
      factors.push([4, try_dmax,   ""]) if dmax
      factors.push([3, try_shadow, ""]) if shadow
      factors.push([2, try_gender, ""]) if gender == 1
      factors.push([1, try_form,   ""]) if form > 0
      factors.push([0, try_species, "000"])
      (2**factors.length).times do |i|
        factors.each_with_index do |factor, index|
          value = ((i / (2**index)).even?) ? factor[1] : factor[2]
          case factor[0]
          when 0 then try_species     = value
          when 1 then try_form        = value
          when 2 then try_gender      = value
          when 3 then try_shadow      = value
          when 4 then try_dmax        = value
          when 5 then try_gmax        = value
          when 6 then try_celest      = value
          end
        end
        try_species_text = try_species
        subfolder_tries.each do |try_folder|
          ret = pbResolveBitmap(sprintf("%s%s%s%s%s%s%s%s%s%s", path, subfolder, try_folder,
                                try_species_text, try_form, try_gender, try_shadow, try_dmax, try_gmax, try_celest))
          return ret if ret
        end
      end
      return nil
    end
	
    def bitmap_exists?(subfolder, female = false, shiny = 0, special = 0)
      path = (subfolder == "Followers") ? "Graphics/Characters/" : "Graphics/Pokemon/"
      path += subfolder
      path += (shiny == 2) ? " super shiny/" : (shiny == 1) ? " shiny/" : "/"
      path += "Gigantamax/" if special == 2
      path += @species.to_s
      path += "_" + @form.to_s if @form > 0
      path += "_female" if female
      path += "_shadow" if special == 1
      path += "_celestial" if special == 3
      return true if pbResolveBitmap(path)
    end
    
    def apply_metrics_to_sprite(sprite, index, shadow = false, set = 0)
      metrics_data = GameData::SpeciesMetrics.get_species_form(@species, @form)
      metrics_data.apply_metrics_to_sprite(sprite, index, shadow, set)
    end

    #---------------------------------------------------------------------------
    # Sprite file names
    #---------------------------------------------------------------------------
    def self.front_sprite_filename(*params)
      params = species_sprite_params(*params)
      return self.check_graphic_file("Graphics/Pokemon/", params, "Front")
    end

    def self.back_sprite_filename(*params)
      params = species_sprite_params(*params)
      return self.check_graphic_file("Graphics/Pokemon/", params, "Back")
    end

    def self.sprite_filename(*params)
      data = species_sprite_params(*params)
      return self.egg_sprite_filename(data[:species], data[:form]) if data[:egg]
      return self.back_sprite_filename(*params) if data[:back]
      return self.front_sprite_filename(*params)
    end

    #---------------------------------------------------------------------------
    # Sprite bitmaps
    #---------------------------------------------------------------------------
    def self.front_sprite_bitmap(*params)
      filename = self.front_sprite_filename(*params)
      hue = (PluginManager.installed?("Pokémon Birthsigns")) ? pbCelestialHue(params[0], params[9]) : 0
      if PluginManager.installed?("Generation 8 Pack Scripts")
        sp_data  = GameData::SpeciesMetrics.get_species_form(params[0], params[1])
        scale    = sp_data ? sp_data.front_sprite_scale : Settings::FRONT_BATTLER_SPRITE_SCALE
        bitmap   = (filename) ? EBDXBitmapWrapper.new(filename, scale) : nil
        bitmap.hue_change(hue) if bitmap && hue != 0
        return bitmap
      else
        return (filename) ? AnimatedBitmap.new(filename, hue) : nil
      end
    end

    def self.back_sprite_bitmap(*params)
      filename = self.back_sprite_filename(*params)
      hue = (PluginManager.installed?("Pokémon Birthsigns")) ? pbCelestialHue(params[0], params[9]) : 0
      if PluginManager.installed?("Generation 8 Pack Scripts")
        sp_data  = GameData::SpeciesMetrics.get_species_form(params[0], params[1])
        scale    = sp_data ? sp_data.back_sprite_scale : Settings::BACK_BATTLER_SPRITE_SCALE
        bitmap   = (filename) ? EBDXBitmapWrapper.new(filename, scale) : nil
        bitmap.hue_change(hue) if bitmap && hue != 0
        return bitmap
      else
        return (filename) ? AnimatedBitmap.new(filename, hue) : nil
      end
    end

    def self.sprite_bitmap(*params)
      data = species_sprite_params(*params)
      return self.egg_sprite_bitmap(data[:species], data[:form]) if data[:egg]
      return self.back_sprite_bitmap(*params) if data[:back]
      return self.front_sprite_bitmap(*params)
    end
    
    def self.sprite_bitmap_from_pokemon(*params)
      pkmn    = params[0]
      back    = params[1]
      species = params[2]
      setDmax = params[3]
      species = pkmn.species if !species
      species = GameData::Species.get(species).species
      return self.egg_sprite_bitmap(species, pkmn.form) if pkmn.egg?
      case setDmax
      when :none then dmax = gmax = false
      when :dmax then dmax = true; gmax = false
      when :gmax then dmax = true; gmax = true
      else dmax = pkmn.dynamax?; gmax = pkmn.gmax?
      end
      shiny = (pkmn.super_shiny?) ? :super_shiny : pkmn.shiny?
      sprite = [species, pkmn.form, pkmn.gender, shiny, pkmn.shadowPokemon?, back, pkmn.egg?, dmax, gmax, pkmn.celestial?]
      ret = (back) ? self.back_sprite_bitmap(*sprite) : self.front_sprite_bitmap(*sprite)
      if PluginManager.installed?("Generation 8 Pack Scripts")
        alter_bitmap_function = (ret && ret.total_frames == 1) ? MultipleForms.getFunction(species, "alterBitmap") : nil
        if ret && alter_bitmap_function
          ret.prepare_strip
          for i in 0...ret.total_frames
            alter_bitmap_function.call(pkmn, ret.alter_bitmap(i))
          end
          ret.compile_strip
        end
      else
        alter_bitmap_function = MultipleForms.getFunction(species, "alterBitmap")
        if ret && alter_bitmap_function
          new_ret = ret.copy
          ret.dispose
          new_ret.each { |bitmap| alter_bitmap_function.call(pkmn, bitmap) }
          ret = new_ret
        end
      end
      return ret
    end

    #---------------------------------------------------------------------------
    # Icons
    #---------------------------------------------------------------------------
    def self.icon_filename(*params)
      params = species_icon_params(*params)
      return self.egg_icon_filename(params[:species], params[:form]) if params[:egg]
      return self.check_graphic_file("Graphics/Pokemon/", params, "Icons")
    end
    
    def self.icon_filename_from_pokemon(pkmn)
      shiny = (pkmn.super_shiny?) ? :super_shiny : pkmn.shiny?
      return self.icon_filename(pkmn.species, pkmn.form, pkmn.gender, shiny, pkmn.shadowPokemon?, pkmn.egg?, 
                                pkmn.dynamax?, pkmn.gmax?, pkmn.celestial?)
    end
    
    def self.icon_bitmap(*params)
      filename = self.icon_filename(*params)
      hue = (PluginManager.installed?("Pokémon Birthsigns")) ? pbCelestialHue(params[0], params[8]) : 0
      return (filename) ? AnimatedBitmap.new(filename, hue).deanimate : nil
    end
    
    def self.icon_bitmap_from_pokemon(pkmn)
      shiny = (pkmn.super_shiny?) ? :super_shiny : pkmn.shiny?
      return self.icon_bitmap(pkmn.species, pkmn.form, pkmn.gender, shiny, pkmn.shadowPokemon?, pkmn.egg?, 
                              pkmn.dynamax?, pkmn.gmax?, pkmn.celestial?)
    end
  
    #---------------------------------------------------------------------------
    # Shadows
    #---------------------------------------------------------------------------
    def self.shadow_filename(*params)
      species = params[0]
      form = params[1]
      species_data = self.get_species_form(species, form)
      return nil if species_data.nil?
      if form > 0
        ret = pbResolveBitmap(sprintf("Graphics/Pokemon/Shadow/%s_%d", species_data.species, form))
        return ret if ret
      end
      ret = pbResolveBitmap(sprintf("Graphics/Pokemon/Shadow/%s", species_data.species))
      return ret if ret
      metrics_data = GameData::SpeciesMetrics.get_species_form(species_data.species, form)
      return pbResolveBitmap(sprintf("Graphics/Pokemon/Shadow/%d", metrics_data.shadow_size))
    end

    def self.shadow_bitmap(*params)
      species = params[0]
      form = params[1]
      filename = self.shadow_filename(species, form)
      return (filename) ? AnimatedBitmap.new(filename) : nil
    end

    def self.shadow_bitmap_from_pokemon(*params)
      pkmn = params[0]
      filename = self.shadow_filename(pkmn.species, pkmn.form)
      return (filename) ? AnimatedBitmap.new(filename) : nil
    end
  
    #---------------------------------------------------------------------------
    # Cries
    #---------------------------------------------------------------------------
    def self.check_cry_file(*params)
      params = species_cry_params(*params)
      species_data = self.get_species_form(params[:species], params[:form])
      return nil if species_data.nil?
      base_file = "#{species_data.species}" + params[:suffix]
      form_file = "#{species_data.species}" + "_#{params[:form]}" + params[:suffix]
      file = (params[:form] > 0) ? form_file : base_file
      base_folder = "Cries/"
      #-------------------------------------------------------------------------
      # Plays Gigantamax cry if one exists.
      #-------------------------------------------------------------------------
      if params[:gmax]
        folder = base_folder + "Gigantamax/"
        cry = folder + file
        backup = folder + base_file
        return cry if pbResolveAudioSE(cry)
        return backup if pbResolveAudioSE(backup)
      end
      #-------------------------------------------------------------------------
      # Plays Dynamax cry if one exists.
      #-------------------------------------------------------------------------
      if params[:dmax]
        folder = base_folder + "Dynamax/"
        cry = folder + file
        backup = folder + base_file
        return cry if pbResolveAudioSE(cry)
        return backup if pbResolveAudioSE(backup)
      end
      #-------------------------------------------------------------------------
      # Plays Celestial cry if one exists.
      #-------------------------------------------------------------------------
      if params[:celestial]
        folder = base_folder + "Celestial/"
        cry = folder + file
        backup = folder + base_file
        return cry if pbResolveAudioSE(cry)
        return backup if pbResolveAudioSE(backup)
      end
      #-------------------------------------------------------------------------
      # Plays Shadow cry if one exists.
      #-------------------------------------------------------------------------
      if params[:shadow]
        folder = base_folder + "Shadow/"
        cry = folder + file
        backup = folder + base_file
        return cry if pbResolveAudioSE(cry)
        return backup if pbResolveAudioSE(backup)
      end
      #-------------------------------------------------------------------------
      # Plays Shiny or Super Shiny cry if one exists.
      #-------------------------------------------------------------------------
      if params[:shiny]
        if params[:shiny] == :super_shiny
          folder = base_folder + "Super shiny/"
          cry = folder + file
          return cry if pbResolveAudioSE(cry)
        end
        folder = base_folder + "Shiny/"
        cry = folder + file
        backup = folder + base_file
        return cry if pbResolveAudioSE(cry)
        return backup if pbResolveAudioSE(backup)
      end
      #-------------------------------------------------------------------------
      # Plays base cry.
      #-------------------------------------------------------------------------
      cry = base_folder + file
      backup = base_folder + base_file
      return cry if pbResolveAudioSE(cry)
      return (pbResolveAudioSE(backup)) ? backup : nil
    end
  
    def self.cry_filename(*params)
      return self.check_cry_file(*params)
    end
  
    def self.cry_filename_from_pokemon(pkmn, suffix = "")
	  shiny = (pkmn.super_shiny?) ? :super_shiny : pkmn.shiny?
      params = [pkmn.species, pkmn.form, suffix, shiny, pkmn.shadowPokemon?, pkmn.dynamax?, pkmn.gmax?, pkmn.celestial?]
      return self.check_cry_file(*params)
    end
  end
  
  #-----------------------------------------------------------------------------
  # Metrics
  #-----------------------------------------------------------------------------
  class SpeciesMetrics
    def apply_metrics_to_sprite(sprite, index, shadow = false, set = 0)
      metrics = {
        :back     => [@back_sprite,           @dmax_back_sprite,   @gmax_back_sprite],
        :front    => [@front_sprite,          @dmax_front_sprite,  @gmax_front_sprite],
        :altitude => [@front_sprite_altitude, @dmax_altitude,      @gmax_altitude],
        :shadow   => [@shadow_x,              @dmax_shadow_x,      @gmax_shadow_x]
      }
      if shadow
        if (index & 1) == 1
          sprite.x += metrics[:shadow][set] * 2
        end
      elsif (index & 1) == 0
        sprite.x += metrics[:back][set][0] * 2
        sprite.y += metrics[:back][set][1] * 2
      else
        offset = metrics[:front][set][0] * 2
        sprite.x = (sprite.mirror) ? sprite.x -= offset : sprite.x += offset
        sprite.y += metrics[:front][set][1] * 2
        sprite.y -= metrics[:altitude][set] * 2
      end
    end
  end
end


#-------------------------------------------------------------------------------
# Pokemon bitmaps (Out of battle)
#-------------------------------------------------------------------------------
class PokemonSprite < SpriteWrapper
  def setPokemonBitmap(*params)
    pokemon = params[0]
    @_iconbitmap&.dispose
    @_iconbitmap = (pokemon) ? GameData::Species.sprite_bitmap_from_pokemon(*params) : nil
    self.bitmap = (@_iconbitmap) ? @_iconbitmap.bitmap : nil
    self.color = Color.new(0, 0, 0, 0)
    self.applyEffects(pokemon)
    changeOrigin
  end

  def setPokemonBitmapSpecies(pokemon, species, back = false)
    @_iconbitmap&.dispose
    @_iconbitmap = (pokemon) ? GameData::Species.sprite_bitmap_from_pokemon(pokemon, back, species) : nil
    self.bitmap = (@_iconbitmap) ? @_iconbitmap.bitmap : nil
    self.applyEffects(pokemon)
    changeOrigin
  end

  def setSpeciesBitmap(*params)
    data = species_sprite_params2(*params)
    @_iconbitmap&.dispose
    @_iconbitmap = GameData::Species.sprite_bitmap(*data.values)
    self.bitmap = (@_iconbitmap) ? @_iconbitmap.bitmap : nil
    changeOrigin
  end
end


#-------------------------------------------------------------------------------
# Pokemon bitmaps (In battle)
#-------------------------------------------------------------------------------
class Battle::Scene::BattlerSprite < RPG::Sprite
  attr_accessor :dynamax

  def setPokemonBitmap(*params)
    @pkmn = params[0]
    case params[3]
    when :none then @dynamax = 0
    when :dmax then @dynamax = 1
    when :gmax then @dynamax = 2
    else @dynamax = (@pkmn.gmax?) ? 2 : (@pkmn.dynamax?) ? 1 : 0
    end
    @_iconBitmap&.dispose
    @_iconBitmap = GameData::Species.sprite_bitmap_from_pokemon(*params)
    self.bitmap = (@_iconBitmap) ? @_iconBitmap.bitmap : nil
    pbSetPosition
  end
  
  def pbSetPosition
    return if !@_iconBitmap
    pbSetOrigin
    if @index.even?
      self.z = 50 + (5 * @index / 2)
    else
      self.z = 50 - (5 * (@index + 1) / 2)
    end
    p = Battle::Scene.pbBattlerPosition(@index, @sideSize)
    @spriteX = p[0]
    @spriteY = p[1]
    @pkmn.species_data.apply_metrics_to_sprite(self, @index, false, @dynamax)
  end
end


#-------------------------------------------------------------------------------
# Shadow sprite for Pokémon (used in battle)
#-------------------------------------------------------------------------------
class Battle::Scene::BattlerShadowSprite < RPG::Sprite
  attr_accessor :dynamax
  
  def setPokemonBitmap(*params)
    @pkmn = params[0]
    case params[1]
    when :none then @dynamax = 0
    when :dmax then @dynamax = 1
    when :gmax then @dynamax = 2
    else @dynamax = (@pkmn.gmax?) ? 2 : (@pkmn.dynamax?) ? 1 : 0
    end
    @_iconBitmap&.dispose
    @_iconBitmap = GameData::Species.shadow_bitmap_from_pokemon(@pkmn, @dynamax > 0)
    self.bitmap = (@_iconBitmap) ? @_iconBitmap.bitmap : nil
    pbSetPosition
  end

  def pbSetPosition
    return if !@_iconBitmap
    pbSetOrigin
    self.z = 3
    p = Battle::Scene.pbBattlerPosition(@index, @sideSize)
    self.x = p[0]
    self.y = p[1]
    @pkmn.species_data.apply_metrics_to_sprite(self, @index, true, @dynamax)
  end
end


#-------------------------------------------------------------------------------
# Icon sprites (Defined Pokemon)
#-------------------------------------------------------------------------------
class PokemonIconSprite < SpriteWrapper
  def pokemon=(value)
    @pokemon = value
    @animBitmap&.dispose
    @animBitmap = nil
    if !@pokemon
      self.bitmap = nil
      @currentFrame = 0
      @counter = 0
      return
    end
    hue = (PluginManager.installed?("Pokémon Birthsigns")) ? pbCelestialHue(@pokemon.species, @pokemon.celestial?) : 0
    @animBitmap = AnimatedBitmap.new(GameData::Species.icon_filename_from_pokemon(value), hue)
    self.bitmap = @animBitmap.bitmap
    self.src_rect.width  = @animBitmap.height
    self.src_rect.height = @animBitmap.height
    self.applyIconEffects
    @numFrames    = @animBitmap.width / @animBitmap.height
    @currentFrame = 0 if @currentFrame >= @numFrames
    changeOrigin
  end
end


#-------------------------------------------------------------------------------
# Icon sprites (for species)
#-------------------------------------------------------------------------------
class PokemonSpeciesIconSprite < SpriteWrapper
  attr_reader :shadow
  attr_reader :dmax
  attr_reader :gmax
  attr_reader :celestial
  
  def initialize(species, viewport = nil)
    super(viewport)
    @species      = species
    @gender       = 0
    @form         = 0
    @shiny        = false
    @shadow       = false
    @dmax         = false
    @gmax         = false
    @celestial    = false
    @numFrames    = 0
    @currentFrame = 0
    @counter      = 0
    refresh
  end
  
  def shadow=(value)
    @shadow = value
    refresh
  end
  
  def dmax=(value)
    @dmax = value
    refresh
  end
  
  def gmax=(value)
    @gmax = value
    refresh
  end
  
  def celestial=(value)
    @celestial = value
    refresh
  end

  def pbSetParams(*params)
    @species   = params[0]
    @gender    = params[1]
    @form      = params[2]
    @shiny     = params[3] || false
    @shadow    = params[4] || false
    @dmax      = params[5] || false
    @gmax      = params[6] || false
    @celestial = params[7] || false
    refresh
  end
  
  def refresh
    @animBitmap&.dispose
    @animBitmap = nil
    bitmapFileName = GameData::Species.icon_filename(@species, @form, @gender, @shiny, @shadow, false, @dmax, @gmax, @celestial)
    return if !bitmapFileName
    hue = (PluginManager.installed?("Pokémon Birthsigns")) ? pbCelestialHue(@species, @celestial) : 0
    @animBitmap = AnimatedBitmap.new(bitmapFileName, hue)
    self.bitmap = @animBitmap.bitmap
    self.src_rect.width  = @animBitmap.height
    self.src_rect.height = @animBitmap.height
    @numFrames = @animBitmap.width / @animBitmap.height
    @currentFrame = 0 if @currentFrame >= @numFrames
    changeOrigin
  end
end


#-------------------------------------------------------------------------------
# Icon sprites (Storage)
#-------------------------------------------------------------------------------
class PokemonBoxIcon < IconSprite
  def refresh
    return if !@pokemon
    hue = (PluginManager.installed?("Pokémon Birthsigns")) ? pbCelestialHue(@pokemon.species, @pokemon.celestial?) : 0
    self.setBitmap(GameData::Species.icon_filename_from_pokemon(@pokemon), hue)
    self.src_rect = Rect.new(0, 0, self.bitmap.height, self.bitmap.height)
  end
end