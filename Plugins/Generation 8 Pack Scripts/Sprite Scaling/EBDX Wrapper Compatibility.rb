#-------------------------------------------------------------------------------
#  aliasing the old Pokemon Sprite Functions and fixing UI overflow issues
#-------------------------------------------------------------------------------
if !defined?(EliteBattle)
  #-----------------------------------------------------------------------------
  #  All Pokemon Sprite files now return EBSBitmapWrapper
  #-----------------------------------------------------------------------------
  module GameData
    class Species
      def self.front_sprite_bitmap(species, form = 0, gender = 0, shiny = false, shadow = false)
        filename = self.front_sprite_filename(species, form, gender, shiny, shadow)
        sp_data  = GameData::SpeciesMetrics.get_species_form(species, form)
        scale    = sp_data ? sp_data.front_sprite_scale : Settings::FRONT_BATTLER_SPRITE_SCALE
        return (filename) ? EBDXBitmapWrapper.new(filename, scale) : nil
      end

      def self.back_sprite_bitmap(species, form = 0, gender = 0, shiny = false, shadow = false)
        filename = self.back_sprite_filename(species, form, gender, shiny, shadow)
        sp_data  = GameData::SpeciesMetrics.get_species_form(species, form)
        scale    = sp_data ? sp_data.back_sprite_scale : Settings::BACK_BATTLER_SPRITE_SCALE
        return (filename) ? EBDXBitmapWrapper.new(filename, scale) : nil
      end

      def self.egg_sprite_bitmap(species, form = 0)
        filename = self.egg_sprite_filename(species, form)
        sp_data  = GameData::SpeciesMetrics.get_species_form(species, form)
        scale    = sp_data ? sp_data.front_sprite_scale : Settings::FRONT_BATTLER_SPRITE_SCALE
        return (filename) ? EBDXBitmapWrapper.new(filename, scale) : nil
      end

      def self.sprite_bitmap_from_pokemon(pkmn, back = false, species = nil)
        species = pkmn.species if !species
        species = GameData::Species.get(species).species   # Just to be sure it's a symbol
        return self.egg_sprite_bitmap(species, pkmn.form) if pkmn.egg?
        if back
          ret = self.back_sprite_bitmap(species, pkmn.form, pkmn.gender, pkmn.shiny?, pkmn.shadowPokemon?)
        else
          ret = self.front_sprite_bitmap(species, pkmn.form, pkmn.gender, pkmn.shiny?, pkmn.shadowPokemon?)
        end
        alter_bitmap_function = nil
        alter_bitmap_function = MultipleForms.getFunction(species, "alterBitmap") if ret && ret.total_frames == 1
        return ret if !alter_bitmap_function
        ret.prepare_strip
        ret.total_frames.times { |i| alter_bitmap_function.call(pkmn, ret.alter_bitmap(i)) }
        ret.compile_strip
        return ret
      end
    end
  end

  #-----------------------------------------------------------------------------
  #  Adding Box constraints to the Pokemon Sprite Bitmap
  #-----------------------------------------------------------------------------
  class PokemonSprite
    def constrict(amt, deanimate = false)
      if amt.is_a?(Array)
        @_iconbitmap.constrict_x = amt[0] if @_iconbitmap.respond_to?(:constrict_x)
        @_iconbitmap.constrict_y = amt[1] if @_iconbitmap.respond_to?(:constrict_y)
        @_iconbitmap.constrict   = amt.max if @_iconbitmap.respond_to?(:constrict)
      else
        @_iconbitmap.constrict = amt if @_iconbitmap.respond_to?(:constrict)
      end
      @_iconbitmap.setSpeed(0) if @_iconbitmap.respond_to?(:setSpeed) && deanimate
      @_iconbitmap.deanimate if @_iconbitmap.respond_to?(:deanimate) && deanimate
      self.update
    end
  end

  #-----------------------------------------------------------------------------
  #  fix misalignment and add box constraints in Pokedex Info Screen
  #-----------------------------------------------------------------------------
  class PokemonPokedexInfo_Scene
    alias __gen8__pbUpdateDummyPokemon pbUpdateDummyPokemon unless method_defined?(:__gen8__pbUpdateDummyPokemon)
    def pbUpdateDummyPokemon
      __gen8__pbUpdateDummyPokemon
      return if defined?(EliteBattle)
      sp_data = GameData::SpeciesMetrics.get_species_form(@species, @form)
      @sprites["infosprite"].constrict([208, 200])
      @sprites["formfront"].constrict([200, 196]) if @sprites["formfront"]
      return if !@sprites["formback"]
      @sprites["formback"].constrict([300, 294])
      return if sp_data.back_sprite_scale == sp_data.front_sprite_scale
      @sprites["formback"].setOffset(PictureOrigin::CENTER)
      @sprites["formback"].y = @sprites["formfront"].y if @sprites["formfront"]
      @sprites["formback"].zoom_x = (sp_data.front_sprite_scale.to_f / sp_data.back_sprite_scale)
      @sprites["formback"].zoom_y = (sp_data.front_sprite_scale.to_f / sp_data.back_sprite_scale)
    end
  end

  #-----------------------------------------------------------------------------
  #  Adding Box constraints to the Pokemon Sprite Bitmap in Pokedex Menu
  #-----------------------------------------------------------------------------
  class PokemonPokedex_Scene
    alias __gen8__setIconBitmap setIconBitmap unless method_defined?(:__gen8__setIconBitmap)
    def setIconBitmap(*args)
      __gen8__setIconBitmap(*args)
      @sprites["icon"].constrict([224, 216]) if !defined?(EliteBattle)
    end
  end


  #-----------------------------------------------------------------------------
  #  Adding Box constraints to the Pokemon Sprite Bitmap in Storage Menu
  #-----------------------------------------------------------------------------
  class PokemonStorageScene
    alias __gen8__pbUpdateOverlay pbUpdateOverlay unless method_defined?(:__gen8__pbUpdateOverlay)
    def pbUpdateOverlay(*args)
      __gen8__pbUpdateOverlay(*args)
      @sprites["pokemon"].constrict(168, true) if !defined?(EliteBattle)
    end
  end

  #-----------------------------------------------------------------------------
  #  Adding Box constraints to the Pokemon Sprite Bitmap in Summary Screen
  #-----------------------------------------------------------------------------
  class PokemonSummary_Scene
    def pbFadeInAndShow(sprites, visiblesprites = nil)
      if visiblesprites
        visiblesprites.each do |i|
          if i[1] && sprites[i[0]] && !pbDisposed?(sprites[i[0]])
            sprites[i[0]].visible = true
          end
        end
      end
      @sprites["pokemon"].constrict([208, 164]) if @sprites["pokemon"] && !defined?(EliteBattle)
      numFrames = (Graphics.frame_rate * 0.4).floor
      alphaDiff = (255.0 / numFrames).ceil
      pbDeactivateWindows(sprites) {
        (0..numFrames).each do |j|
          pbSetSpritesToColor(sprites, Color.new(0, 0, 0, ((numFrames - j) * alphaDiff)))
          (block_given?) ? yield : pbUpdateSpriteHash(sprites)
        end
      }
    end

    alias __gen8__pbChangePokemon pbChangePokemon unless method_defined?(:__gen8__pbChangePokemon)
    def pbChangePokemon
      __gen8__pbChangePokemon
      @sprites["pokemon"].constrict([208, 164]) if !defined?(EliteBattle)
    end
  end
end

Graphics.frame_rate = 60 if Settings::SMOOTH_FRAMERATE
