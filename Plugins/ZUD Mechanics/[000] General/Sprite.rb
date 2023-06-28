#===============================================================================
# SpriteWrapper additions for Dynamax sprites.
#===============================================================================
class Sprite
  def applyDynamax(pokemon = nil)
    self.unTera
    if Settings::SHOW_DYNAMAX_SIZE
      self.zoom_x = self.zoom_y = 1.5
    end
    if Settings::SHOW_DYNAMAX_COLOR
      calyrex = false
      if pokemon.is_a?(Battle::Battler)
        pokemon = pokemon.effects[PBEffects::TransformPokemon] || pokemon.displayPokemon
      end
      if pokemon.is_a?(Pokemon)
        calyrex = pokemon.isSpecies?(:CALYREX)
      elsif pokemon.is_a?(Symbol)
        calyrex = (pokemon == :CALYREX)
      end
      path = "Graphics/Plugins/ZUD/"
      path += (calyrex) ? "calyrex_pattern" : "dynamax_pattern"
      self.pattern = Bitmap.new(path)
      self.pattern_opacity = 150
    end
  end
  
  def unDynamax
    self.zoom_x = 1 if self.zoom_x > 1
    self.zoom_y = 1 if self.zoom_y > 1
    self.pattern = nil
  end
  
  def applyDynamaxIcon
    if self.pokemon&.dynamax?
      self.unTera
      if Settings::SHOW_DYNAMAX_SIZE && self.bitmap.height <= 64
        self.zoom_x = self.zoom_y = 1.5
      else
        self.zoom_x = self.zoom_y = 1
      end
      if Settings::SHOW_DYNAMAX_COLOR
        calyrex = self.pokemon.isSpecies?(:CALYREX)
        path = "Graphics/Plugins/ZUD/"
        path += (calyrex) ? "calyrex_pattern" : "dynamax_pattern"
        self.pattern = Bitmap.new(path)
        self.pattern_opacity = 150
      end
    else
      self.unDynamax
    end
  end
end