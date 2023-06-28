#===============================================================================
# Sprite Outliner.
#===============================================================================


#-------------------------------------------------------------------------------
# Creates new sprites that act as an outline for an existing sprite.
#-------------------------------------------------------------------------------
def pbAddSpriteOutline(param = [], color = Color.white, border = 2, opacity = 255)
  key, viewport, object, offset = param[0], param[1], param[2], param[3]
  return if !@sprites || !@sprites.has_key?(key) || param.empty?
  for i in 0..7
    outline = key + "_outline#{i}"
    case @sprites[key]
    when PokemonSprite
      @sprites[outline] = PokemonSprite.new(viewport)
      @sprites[outline].setOffset(offset)
      case object
      when Pokemon
        @sprites[outline].setPokemonBitmap(object)
        object.species_data.apply_metrics_to_sprite(@sprites[outline], 1, nil, object.gmax_factor? ? 2 : 1)
      when Symbol
        @sprites[outline].setSpeciesBitmap(*object)
      end
    when PokemonIconSprite
      @sprites[outline] = PokemonIconSprite.new(object, viewport)
      @sprites[outline].setOffset(offset)
    when PokemonSpeciesIconSprite
      @sprites[outline] = PokemonSpeciesIconSprite.new(object, viewport)
    when ItemIconSprite
      @sprites[outline] = ItemIconSprite.new(0, 0, object, viewport)
    when HeldItemIconSprite
      @sprites[outline] = HeldItemIconSprite.new(0, 0, object, viewport)
    else
      @sprites[outline] = IconSprite.new(0, 0, viewport)
      @sprites[outline].bitmap = @sprites[key].bitmap
    end
    @sprites[outline].visible = @sprites[key].visible
    @sprites[outline].mirror = @sprites[key].mirror
    @sprites[outline].color = color
    @sprites[outline].opacity = opacity
    @sprites[outline].x = @sprites[key].x
    @sprites[outline].y = @sprites[key].y
    @sprites[outline].z = @sprites[key].z
    case i
    when 0; @sprites[outline].x += border
    when 1; @sprites[outline].x -= border
    when 2; @sprites[outline].y += border
    when 3; @sprites[outline].y -= border
    when 4
      @sprites[outline].x -= border
      @sprites[outline].y -= border
    when 5
      @sprites[outline].x += border
      @sprites[outline].y -= border
    when 6
      @sprites[outline].x -= border
      @sprites[outline].y += border
    when 7
      @sprites[outline].x += border
      @sprites[outline].y += border
    end
  end
  @sprites[key].z = @sprites[key + "_outline7"].z + 1
end


#-------------------------------------------------------------------------------
# Adjusts outline coordinates.
#-------------------------------------------------------------------------------
def pbSetWithOutline(sprite, coords = [], color = Color.white, border = 2)
  return if !@sprites || !@sprites.has_key?(sprite)
  @sprites[sprite].x = coords[0] if coords[0]
  @sprites[sprite].y = coords[1] if coords[1]
  @sprites[sprite].z = coords[2] + 1 if coords[2]
  for i in 0..7
    key = sprite + "_outline#{i}"
    next if !@sprites[key]
    @sprites[key].x = coords[0] if coords[0]
    @sprites[key].y = coords[1] if coords[1]
    @sprites[key].z = coords[2] if coords[2]
    case i
    when 0; @sprites[key].x += border
    when 1; @sprites[key].x -= border
    when 2; @sprites[key].y += border
    when 3; @sprites[key].y -= border
    when 4
      @sprites[key].x -= border
      @sprites[key].y -= border
    when 5
      @sprites[key].x += border
      @sprites[key].y -= border
    when 6
      @sprites[key].x -= border
      @sprites[key].y += border
    when 7
      @sprites[key].x += border
      @sprites[key].y += border
    end
  end
end

def pbMoveWithOutline(sprite, x = 0, y = 0, z = 0)
  return if !@sprites || !@sprites.has_key?(sprite)
  @sprites[sprite].x += x
  @sprites[sprite].y += y
  @sprites[sprite].z += z
  for i in 0..7
    key = sprite + "_outline#{i}"
    next if !@sprites[key]
    @sprites[key].x += x
    @sprites[key].y += y
    @sprites[key].z += z
  end
end


#-------------------------------------------------------------------------------
# Adjusts outline visibility.
#-------------------------------------------------------------------------------
def pbShowOutline(sprite, visibility = true)
  return if !@sprites || !@sprites.has_key?(sprite)
  case visibility
  when Numeric
    if visibility == 0
      for i in 0..7
        key = sprite + "_outline#{i}"
        next if !@sprites[key]
        @sprites[key].opacity = visibility
      end
    else
      for i in 0..7
        key = sprite + "_outline#{i}"
        next if !@sprites[key]
        @sprites[key].opacity += visibility
      end
    end
  else
    for i in 0..7
      key = sprite + "_outline#{i}"
      next if !@sprites[key]
      @sprites[key].visible = visibility
    end
  end  
end


#-------------------------------------------------------------------------------
# Adjusts outline color.
#-------------------------------------------------------------------------------
def pbColorOutline(sprite, color)
  return if !@sprites || !@sprites.has_key?(sprite)
  color = Color.white if color.nil?
  for i in 0..7
    key = sprite + "_outline#{i}"
    next if !@sprites[key]
    @sprites[key].color = color
  end  
end


#-------------------------------------------------------------------------------
# Updates outlines for Pokemon sprites.
#-------------------------------------------------------------------------------
def pbUpdateOutline(sprite, pokemon)
  return if !@sprites || !@sprites.has_key?(sprite)
  for i in 0..7
    key = sprite + "_outline#{i}"
    next if !@sprites[key]
    next if !(@sprites[key].is_a?(PokemonSprite) || @sprites[key].is_a?(PokemonIconSprite))
    if pokemon.is_a?(Pokemon)
      case @sprites[key]
      when PokemonSprite
        @sprites[key].setPokemonBitmap(pokemon)
        pokemon.species_data.apply_metrics_to_sprite(@sprites[key], 1, nil, pokemon.gmax_factor? ? 2 : 1)
        @sprites[key].applyEffects(pokemon)
      when PokemonIconSprite
        @sprites[key].pokemon = pokemon
        @sprites[key].applyIconEffects
      end
    else
      @sprites[key].setSpeciesBitmap(*pokemon)
    end
  end
end