#===============================================================================
# Species data.
#===============================================================================
module GameData
  class Species
    attr_reader   :no_dynamax
    attr_accessor :gmax_height
    attr_accessor :real_gmax_name
    attr_accessor :real_gmax_dex  
    
    alias zud_initialize initialize
    def initialize(hash)
      zud_initialize(hash)
      banned          = Settings::DYNAMAX_BANLIST
      banned         += [:KYOGRE_1, :GROUDON_1, :NECROZMA_3, :NECROZMA_4, 
                         :ZACIAN,   :ZACIAN_1,  :ZAMAZENTA,  :ZAMAZENTA_1]
      @no_dynamax     = (banned.include?(@id) || @mega_stone || @mega_move) ? true : false
      @gmax_height    = nil
      @real_gmax_name = nil
      @real_gmax_dex  = nil
    end

    #---------------------------------------------------------------------------
    # Gets G-Max messages.
    #---------------------------------------------------------------------------
    def gmax_form_name
      return pbGetMessageFromHash(MessageTypes::GMaxNames, @real_gmax_name)
    end

    def gmax_dex_entry
      return pbGetMessageFromHash(MessageTypes::GMaxEntries, @real_gmax_dex)
    end

    #---------------------------------------------------------------------------
    # Determines if a species is capable of Gigantamaxing.
    #---------------------------------------------------------------------------
    def hasGmax?
      return false if @no_dynamax
      species_list = GameData::PowerMove.species_list("G-Max")
      species_list.each { |sp| return true if sp == @id }
      return false
    end
	
    #---------------------------------------------------------------------------
    # Determines if a species is a regional form, and if it can be encountered.
    #---------------------------------------------------------------------------
    def regionalVariant?
      regional = false
      for i in Settings::REGIONAL_FORMS
        break if !@real_form_name
        break if @real_form_name.include?("Zen Mode")
        if @real_form_name.include?(i[0])
          regional = true
          break
        end
      end
      return regional
    end
    
    def encounterRegional?
      encounter = false
      for i in Settings::REGIONAL_FORMS
        if @real_form_name.include?(i[0]) && pbGetCurrentRegion == i[1]
          encounter = true
          break
        end
      end
      return encounter
    end
	
    #---------------------------------------------------------------------------
    # Gets all eligible forms of this species that may appear in raids.
    #---------------------------------------------------------------------------
    def get_raid_forms
      ret = []
      GameData::Species.each do |sp|
        next if sp.species != @species
        next if pbGetRaidRank[:banned].include?(sp.id)
        next if sp.generation > Settings::GENERATION_LIMIT
        ret.push(sp.id)
      end
      return ret
    end

    #---------------------------------------------------------------------------
    # Gets G-Max footprint graphic, if one is present.
    #---------------------------------------------------------------------------
    def self.footprint_filename(species, form = 0, gmax = false)
      species_data = self.get_species_form(species, form)
      return nil if species_data.nil?
      gmax_file = (gmax) ? "Gigantamax/" : ""
      path = "Graphics/Pokemon/Footprints/" + gmax_file
      ret  = pbResolveBitmap(path += "#{species_data.species}")
      if form > 0 
        path += "#{species_data.species}_#{form}" 
        new_ret = pbResolveBitmap(path)
        ret = new_ret if new_ret
      end
      return ret
    end
    
    #---------------------------------------------------------------------------
    # Gets special shadow graphic for Dynamaxed Pokemon, if one is present.
    #---------------------------------------------------------------------------
    def self.shadow_filename(species, form = 0, dynamax = false)
      species_data = self.get_species_form(species, form)
      return nil if species_data.nil?
      path = "Graphics/Pokemon/Shadow/#{species_data.species}"
      ret  = pbResolveBitmap(path)
      if form > 0
        path += "_#{form}"
        new_ret = pbResolveBitmap(path)
        ret = new_ret if new_ret
      end
      if dynamax
        path += "_dmax"
        new_ret = pbResolveBitmap(path)
        ret = new_ret if new_ret
        if !ret
          path = "Graphics/Pokemon/Shadow/dynamax"
          ret  = pbResolveBitmap(path)
        end
      end
      if !ret
        metrics_data = GameData::SpeciesMetrics.get_species_form(species_data.species, form)
        ret = pbResolveBitmap(sprintf("Graphics/Pokemon/Shadow/%d", metrics_data.shadow_size))
      end
      return ret
    end
    
    def self.shadow_bitmap(species, form = 0, dynamax = false)
      filename = self.shadow_filename(species, form, dynamax)
      return (filename) ? AnimatedBitmap.new(filename) : nil
    end

    def self.shadow_bitmap_from_pokemon(pkmn, dynamax = false)
      filename = self.shadow_filename(pkmn.species, pkmn.form, dynamax || pkmn.dynamax?)
      return (filename) ? AnimatedBitmap.new(filename) : nil
    end
  end
  
  
  #-----------------------------------------------------------------------------
  # Adds new data to GameData::SpeciesMetrics.
  #-----------------------------------------------------------------------------
  class SpeciesMetrics
    attr_accessor :dmax_back_sprite, :dmax_front_sprite, :dmax_altitude, :dmax_shadow_x, :dmax_shadow_size
    attr_accessor :gmax_back_sprite, :gmax_front_sprite, :gmax_altitude, :gmax_shadow_x, :gmax_shadow_size
    
    ZUD_SCHEMA = {
      "DmaxBackSprite"   => [0, "ii"],
      "DmaxFrontSprite"  => [0, "ii"],
      "DmaxAltitude"     => [0, "i"],
      "DmaxShadowX"      => [0, "i"],
      "DmaxShadowSize"   => [0, "u"],
      
      "GmaxBackSprite"   => [0, "ii"],
      "GmaxFrontSprite"  => [0, "ii"],
      "GmaxAltitude"     => [0, "i"],
      "GmaxShadowX"      => [0, "i"],
      "GmaxShadowSize"   => [0, "u"]
    }
    
    alias zud_initialize initialize
    def initialize(hash)
      zud_initialize(hash)
      @dmax_back_sprite    = @back_sprite           if !@dmax_back_sprite
      @dmax_front_sprite   = @front_sprite          if !@dmax_front_sprite
      @dmax_altitude       = @front_sprite_altitude if !@dmax_altitude
      @dmax_shadow_x       = @shadow_x              if !@dmax_shadow_x
      @dmax_shadow_size    = 3                      if !@dmax_shadow_size
      
      @gmax_back_sprite    = @dmax_back_sprite      if !@gmax_back_sprite
      @gmax_front_sprite   = @dmax_front_sprite     if !@gmax_front_sprite
      @gmax_altitude       = @dmax_altitude         if !@gmax_altitude
      @gmax_shadow_x       = @dmax_shadow_x         if !@gmax_shadow_x
      @gmax_shadow_size    = @dmax_shadow_size      if !@gmax_shadow_size
    end
  end
end