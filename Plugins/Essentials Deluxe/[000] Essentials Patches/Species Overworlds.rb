#===============================================================================
# Handles the display of overworld Pokemon sprites.
#===============================================================================


#-------------------------------------------------------------------------------
# Overworld parameter hash
#-------------------------------------------------------------------------------
def species_overworld_params(*params)
  data = {
    :species   => params[0] || nil,
    :form      => params[1] || 0,
    :gender    => params[2] || 0,
    :shiny     => params[3] || false,
    :shadow    => params[4] || false,
    :celestial => params[5] || false
  }
  return data
end


#-------------------------------------------------------------------------------
# Species files
#-------------------------------------------------------------------------------
module GameData
  class Species
    def self.overworld_filename(*params)
      params = species_overworld_params(*params)
      return self.check_graphic_file("Graphics/Characters/", params, "Followers") || "Graphics/Characters/Followers/"
    end
	
    def self.overworld_filename_from_pokemon(pkmn)
      shiny = (pkmn.super_shiny?) ? :super_shiny : pkmn.shiny?
      return self.overworld_filename(pkmn.species, pkmn.form, pkmn.gender, shiny, pkmn.shadowPokemon?, pkmn.celestial?)
    end
	
    def self.overworld_bitmap(*params)
      filename = self.overworld_filename(*params)
      hue = (PluginManager.installed?("Pokémon Birthsigns")) ? pbCelestialHue(params[0], params[5]) : 0
      return (filename) ? AnimatedBitmap.new(filename, hue).deanimate : nil
    end
    
    def self.overworld_bitmap_from_pokemon(pkmn)
      shiny = (pkmn.super_shiny?) ? :super_shiny : pkmn.shiny?
      return self.overworld_bitmap(pkmn.species, pkmn.form, pkmn.gender, shiny, pkmn.shadowPokemon?, pkmn.celestial?)
    end
  end
end


#-------------------------------------------------------------------------------
# Compatibility with Visible Overworld Wild Encounters.
#-------------------------------------------------------------------------------
def ow_sprite_filename(*params)
  params = species_overworld_params(*params)
  return GameData::Species.check_graphic_file("Graphics/Characters/", params, "Followers")
end


#-------------------------------------------------------------------------------
# Compatibility with Following Pokemon EX.
#-------------------------------------------------------------------------------
module FollowingPkmn
  def self.change_sprite(pkmn)
    fname = GameData::Species.overworld_filename_from_pokemon(pkmn)
    fname.gsub!("Graphics/Characters/", "")
    FollowingPkmn.get_event&.character_name = fname
    FollowingPkmn.get_data&.character_name  = fname
    if FollowingPkmn.get_event&.move_route_forcing
      hue = 0
      hue = pkmn.superHue if pkmn.respond_to?(:superHue) && pkmn.superShiny?
      hue = pbCelestialHue(pkmn.species_data.id, true) if pkmn.celestial?
      FollowingPkmn.get_event&.character_hue = hue
      FollowingPkmn.get_data&.character_hue  = hue
    end
  end
end


#-------------------------------------------------------------------------------
# Pokémon overworld sprite (for defined Pokémon)
#-------------------------------------------------------------------------------
class PokemonOverworldSprite < Sprite
  attr_accessor :selected
  attr_accessor :active
  attr_reader   :pokemon

  def initialize(pokemon, viewport = nil)
    super(viewport)
    @selected     = false
    @active       = false
    @numFrames    = 0
    @currentFrame = 0
    @counter      = 0
    @direction    = 0
    self.pokemon  = pokemon
    @logical_x    = 0
    @logical_y    = 0
    @adjusted_x   = 0
    @adjusted_y   = 0
  end

  def dispose
    @animBitmap&.dispose
    super
  end

  def x; return @logical_x; end
  def y; return @logical_y; end

  def x=(value)
    @logical_x = value
    super(@logical_x + @adjusted_x)
  end

  def y=(value)
    @logical_y = value
    super(@logical_y + @adjusted_y)
  end
  
  def setPokemon(value, dir = 0)
    @direction = dir
    self.pokemon = value
  end

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
    @animBitmap = AnimatedBitmap.new(GameData::Species.overworld_filename_from_pokemon(value))
    self.bitmap = @animBitmap.bitmap
    self.src_rect.width  = @animBitmap.width / 4
    self.src_rect.height = @animBitmap.height / 4
    self.src_rect.y      = self.src_rect.height * @direction
    @numFrames    = 4
    @currentFrame = 0 if @currentFrame >= @numFrames
    changeOrigin
  end

  def setOffset(offset = PictureOrigin::CENTER)
    @offset = offset
    changeOrigin
  end

  def changeOrigin
    return if !self.bitmap
    @offset = PictureOrigin::TOP_LEFT if !@offset
    case @offset
    when PictureOrigin::TOP_LEFT, PictureOrigin::LEFT, PictureOrigin::BOTTOM_LEFT
      self.ox = 0
    when PictureOrigin::TOP, PictureOrigin::CENTER, PictureOrigin::BOTTOM
      self.ox = self.src_rect.width / 2
    when PictureOrigin::TOP_RIGHT, PictureOrigin::RIGHT, PictureOrigin::BOTTOM_RIGHT
      self.ox = self.src_rect.width
    end
    case @offset
    when PictureOrigin::TOP_LEFT, PictureOrigin::TOP, PictureOrigin::TOP_RIGHT
      self.oy = 0
    when PictureOrigin::LEFT, PictureOrigin::CENTER, PictureOrigin::RIGHT
      self.oy = self.src_rect.height / 2
    when PictureOrigin::BOTTOM_LEFT, PictureOrigin::BOTTOM, PictureOrigin::BOTTOM_RIGHT
      self.oy = self.src_rect.height
    end
  end

  def counterLimit
    return 0 if @pokemon.fainted?
    ret = Graphics.frame_rate / 2
    if @pokemon.hp <= @pokemon.totalhp / 4
      ret *= 4
    elsif @pokemon.hp <= @pokemon.totalhp / 2
      ret *= 2
    end
    ret /= @numFrames
    ret = 1 if ret < 1
    return ret
  end

  def update
    return if !@animBitmap
    super
    @animBitmap.update
    self.bitmap = @animBitmap.bitmap
    cl = self.counterLimit
    if cl == 0
      @currentFrame = 0
    else
      @counter += 1
      if @counter >= cl
        @currentFrame = (@currentFrame + 1) % @numFrames
        @counter = 0
      end
    end
    self.src_rect.x = self.src_rect.width * @currentFrame
    if @selected
      @adjusted_x = 4
      @adjusted_y = (@currentFrame >= @numFrames / 2) ? -2 : 6
    else
      @adjusted_x = 0
      @adjusted_y = 0
    end
    self.x = self.x
    self.y = self.y
  end
end


#-------------------------------------------------------------------------------
# Pokémon overworld sprite (for species)
#-------------------------------------------------------------------------------
class PokemonSpeciesOverworldSprite < Sprite
  attr_reader :species
  attr_reader :gender
  attr_reader :form
  attr_reader :shiny
  attr_reader :shadow
  attr_reader :celestial

  def initialize(species, viewport = nil)
    super(viewport)
    @species      = species
    @gender       = 0
    @form         = 0
    @shiny        = false
    @shadow       = false
    @celestial    = false
    @numFrames    = 0
    @currentFrame = 0
    @counter      = 0
    @direction    = 0
    refresh
  end

  def dispose
    @animBitmap&.dispose
    super
  end

  def species=(value)
    @species = value
    refresh
  end

  def gender=(value)
    @gender = value
    refresh
  end

  def form=(value)
    @form = value
    refresh
  end

  def shiny=(value)
    @shiny = value
    refresh
  end
  
  def shadow=(value)
    @shadow = value
    refresh
  end
  
  def celestial=(value)
    @celestial = value
    refresh
  end
  
  def direction=(value)
    @direction = value
    refresh
  end

  def pbSetParams(*params)
    @species   = params[0]
    @gender    = params[1]
    @form      = params[2]
    @shiny     = params[3] || false
    @shadow    = params[4] || false
    @celestial = params[5] || false
    refresh
  end

  def setOffset(offset = PictureOrigin::CENTER)
    @offset = offset
    changeOrigin
  end

  def changeOrigin
    return if !self.bitmap
    @offset = PictureOrigin::TOP_LEFT if !@offset
    case @offset
    when PictureOrigin::TOP_LEFT, PictureOrigin::LEFT, PictureOrigin::BOTTOM_LEFT
      self.ox = 0
    when PictureOrigin::TOP, PictureOrigin::CENTER, PictureOrigin::BOTTOM
      self.ox = self.src_rect.width / 2
    when PictureOrigin::TOP_RIGHT, PictureOrigin::RIGHT, PictureOrigin::BOTTOM_RIGHT
      self.ox = self.src_rect.width
    end
    case @offset
    when PictureOrigin::TOP_LEFT, PictureOrigin::TOP, PictureOrigin::TOP_RIGHT
      self.oy = 0
    when PictureOrigin::LEFT, PictureOrigin::CENTER, PictureOrigin::RIGHT
      self.oy = self.src_rect.height / 2
    when PictureOrigin::BOTTOM_LEFT, PictureOrigin::BOTTOM, PictureOrigin::BOTTOM_RIGHT
      self.oy = self.src_rect.height
    end
  end

  def counterLimit
    ret = Graphics.frame_rate / 2
    ret /= @numFrames
    ret = 1 if ret < 1
    return ret
  end

  def refresh
    @animBitmap&.dispose
    @animBitmap = nil
    bitmapFileName = GameData::Species.overworld_filename(@species, @form, @gender, @shiny, @shadow, @celestial)
    return if !bitmapFileName
    @animBitmap = AnimatedBitmap.new(bitmapFileName)
    self.bitmap = @animBitmap.bitmap
    self.src_rect.width  = @animBitmap.width / 4
    self.src_rect.height = @animBitmap.height / 4
    self.src_rect.y      = self.src_rect.height * @direction
    @numFrames = 4
    @currentFrame = 0 if @currentFrame >= @numFrames
    changeOrigin
  end

  def update
    return if !@animBitmap
    super
    @animBitmap.update
    self.bitmap = @animBitmap.bitmap
    @counter += 1
    if @counter >= self.counterLimit
      @currentFrame = (@currentFrame + 1) % @numFrames
      @counter = 0
    end
    self.src_rect.x = self.src_rect.width * @currentFrame
  end
end