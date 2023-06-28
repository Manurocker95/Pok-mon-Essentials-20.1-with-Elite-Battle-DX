#===============================================================================
# Sprite Position editor for Dynamax sprites.
#===============================================================================
class SpritePositioner
  alias zud_pbOpen pbOpen
  def pbOpen
    @mode = 0
    @dynamax_mode = (Input.press?(Input::CTRL)) ? true : false
    if @dynamax_mode
      @mode = 1
      pbMessage(_INTL("Opening editor in Dynamax Mode..."))
    end
    @gmax    = false
    @metrics = {}
    zud_pbOpen
  end
  
  def pbSaveMetrics
    GameData::SpeciesMetrics.save
    if @dynamax_mode
      Compiler.write_dynamax_metrics
    else
      Compiler.write_pokemon_metrics
    end
  end
  
  def pbGetMetrics(data)
    if @metrics.empty?
      metrics = {
        :back        => [data.back_sprite,           data.dmax_back_sprite,   data.gmax_back_sprite],
        :front       => [data.front_sprite,          data.dmax_front_sprite,  data.gmax_front_sprite],
        :altitude    => [data.front_sprite_altitude, data.dmax_altitude,      data.gmax_altitude],
        :shadow_x    => [data.shadow_x,              data.dmax_shadow_x,      data.gmax_shadow_x],
        :shadow_size => [data.shadow_size,           data.dmax_shadow_size,   data.gmax_shadow_size]
      }
      @metrics = {
        :back        => metrics[:back][@mode],
        :front       => metrics[:front][@mode],
        :altitude    => metrics[:altitude][@mode],
        :shadow_x    => metrics[:shadow_x][@mode],
        :shadow_size => metrics[:shadow_size][@mode]
      }
    end
  end
  
  def pbApplyMetrics(data)
    pbGetMetrics(data)
    case @mode
    when 0
      data.back_sprite           = @metrics[:back]
      data.front_sprite          = @metrics[:front]
      data.front_sprite_altitude = @metrics[:altitude]
      data.shadow_x              = @metrics[:shadow_x]
      data.shadow_size           = @metrics[:shadow_size]
    when 1
      data.dmax_back_sprite      = @metrics[:back]
      data.dmax_front_sprite     = @metrics[:front]
      data.dmax_altitude         = @metrics[:altitude]
      data.dmax_shadow_x         = @metrics[:shadow_x]
      data.dmax_shadow_size      = @metrics[:shadow_size]
    when 2
      data.gmax_back_sprite      = @metrics[:back]
      data.gmax_front_sprite     = @metrics[:front]
      data.gmax_altitude         = @metrics[:altitude]
      data.gmax_shadow_x         = @metrics[:shadow_x]
      data.gmax_shadow_size      = @metrics[:shadow_size]
    end
  end
  
  def refresh
    if !@species
      @sprites["pokemon_0"].visible = false
      @sprites["pokemon_1"].visible = false
      @sprites["shadow_1"].visible = false
      return
    end
    metrics_data = GameData::SpeciesMetrics.get_species_form(@species, @form)
    pbApplyMetrics(metrics_data)
    2.times do |i|
      pos = Battle::Scene.pbBattlerPosition(i, 1)
      @sprites["pokemon_#{i}"].x = pos[0]
      @sprites["pokemon_#{i}"].y = pos[1]
      metrics_data.apply_metrics_to_sprite(@sprites["pokemon_#{i}"], i, false, @mode)
      @sprites["pokemon_#{i}"].visible = true
      next if i != 1
      @sprites["shadow_1"].x = pos[0]
      @sprites["shadow_1"].y = pos[1]
      if @sprites["shadow_1"].bitmap
        @sprites["shadow_1"].x -= @sprites["shadow_1"].bitmap.width / 2
        @sprites["shadow_1"].y -= @sprites["shadow_1"].bitmap.height / 2
      end
      metrics_data.apply_metrics_to_sprite(@sprites["shadow_1"], i, true, @mode)
      @sprites["shadow_1"].visible = true
    end
  end
  
  def pbAutoPosition
    metrics_data = GameData::SpeciesMetrics.get_species_form(@species, @form)
    old_back_y         = @metrics[:back][1]
    old_front_y        = @metrics[:front][1]
    old_front_altitude = @metrics[:altitude]
    bitmap1 = @sprites["pokemon_0"].bitmap
    bitmap2 = @sprites["pokemon_1"].bitmap
    new_back_y  = (bitmap1.height - (findBottom(bitmap1) + 1)) / 2
    new_front_y = (bitmap2.height - (findBottom(bitmap2) + 1)) / 2
    new_front_y += 4
    if new_back_y != old_back_y || new_front_y != old_front_y || old_front_altitude != 0
      @metrics[:back][1]  = new_back_y
      @metrics[:front][1] = new_front_y
      @metrics[:altitude] = 0
      @metricsChanged = true
      refresh
    end
  end
  
  def pbChangeSpecies(species, form, gmax)
    @species = species
    @form = form
    @gmax = gmax
    @mode = (@gmax) ? 2 : (@dynamax_mode) ? 1 : 0
    species_data = GameData::Species.get_species_form(@species, @form)
    return if !species_data
    metrics_data = GameData::SpeciesMetrics.get_species_form(@species, @form)
    pbGetMetrics(metrics_data)
    @sprites["pokemon_0"].setSpeciesBitmap(@species, 0, @form, false, false, true, false, @dynamax_mode, @gmax)
    @sprites["pokemon_1"].setSpeciesBitmap(@species, 0, @form, false, false, false, false, @dynamax_mode, @gmax)
    @sprites["shadow_1"].setBitmap(GameData::Species.shadow_filename(@species, @form, @dynamax_mode))
    if @dynamax_mode
      @sprites["pokemon_0"].applyDynamax(@species)
      @sprites["pokemon_1"].applyDynamax(@species)
    end
  end
  
  def pbShadowSize
    pbChangeSpecies(@species, @form, @gmax)
    refresh
    metrics_data = GameData::SpeciesMetrics.get_species_form(@species, @form)
    if @dynamax_mode
      pbMessage("Dynamax Pokémon have their own shadow sprite. The shadow size metric cannot be edited.")
      return false
    elsif pbResolveBitmap(sprintf("Graphics/Pokemon/Shadow/%s_%d", metrics_data.species, metrics_data.form)) ||
          pbResolveBitmap(sprintf("Graphics/Pokemon/Shadow/%s", metrics_data.species))
      pbMessage("This species has its own shadow sprite in Graphics/Pokemon/Shadow/. The shadow size metric cannot be edited.")
      return false
    end
    oldval = @metrics[:shadow_size]
    cmdvals = [0]
    commands = [_INTL("None")]
    defindex = 0
    i = 0
    loop do
      i += 1
      fn = sprintf("Graphics/Pokemon/Shadow/%d", i)
      break if !pbResolveBitmap(fn)
      cmdvals.push(i)
      commands.push(i.to_s)
      defindex = cmdvals.length - 1 if oldval == i
    end
    cw = Window_CommandPokemon.new(commands)
    cw.index    = defindex
    cw.viewport = @viewport
    ret = false
    oldindex = cw.index
    loop do
      Graphics.update
      Input.update
      cw.update
      self.update
      if cw.index != oldindex
        oldindex = cw.index
        @metrics[:shadow_size] = cmdvals[cw.index]
        pbApplyMetrics(metrics_data)
        pbChangeSpecies(@species, @form, @gmax)
        refresh
      end
      if Input.trigger?(Input::ACTION)
        pbPlayDecisionSE
        @metricsChanged = true if @metrics[:shadow_size] != oldval
        ret = true
        break
      elsif Input.trigger?(Input::BACK)
        @metrics[:shadow_size] = oldval
        pbApplyMetrics(metrics_data)
        pbPlayCancelSE
        break
      elsif Input.trigger?(Input::USE)
        pbPlayDecisionSE
        break
      end
    end
    cw.dispose
    return ret
  end
  
  def pbSetParameter(param)
    return if !@species
    return pbShadowSize if param == 2
    if param == 4
      pbAutoPosition
      return false
    end
    metrics_data = GameData::SpeciesMetrics.get_species_form(@species, @form)
    case param
    when 0
      sprite = @sprites["pokemon_0"]
      xpos = @metrics[:back][0]
      ypos = @metrics[:back][1]
    when 1
      sprite = @sprites["pokemon_1"]
      xpos = @metrics[:front][0]
      ypos = @metrics[:front][1]
    when 3
      sprite = @sprites["shadow_1"]
      xpos = @metrics[:shadow_x]
      ypos = 0
    end
    oldxpos = xpos
    oldypos = ypos
    @sprites["info"].visible = true
    ret = false
    loop do
      sprite.visible = (Graphics.frame_count % 16) < 12   # Flash the selected sprite
      Graphics.update
      Input.update
      self.update
      case param
      when 0 then @sprites["info"].setTextToFit("Ally Position = #{xpos},#{ypos}")
      when 1 then @sprites["info"].setTextToFit("Enemy Position = #{xpos},#{ypos}")
      when 3 then @sprites["info"].setTextToFit("Shadow Position = #{xpos}")
      end
      if (Input.repeat?(Input::UP) || Input.repeat?(Input::DOWN)) && param != 3
        ypos += (Input.repeat?(Input::DOWN)) ? 1 : -1
        case param
        when 0 then @metrics[:back][1]  = ypos
        when 1 then @metrics[:front][1] = ypos
        end
        refresh
      end
      if Input.repeat?(Input::LEFT) || Input.repeat?(Input::RIGHT)
        xpos += (Input.repeat?(Input::RIGHT)) ? 1 : -1
        case param
        when 0 then @metrics[:back][0]  = xpos
        when 1 then @metrics[:front][0] = xpos
        when 3 then @metrics[:shadow_x] = xpos
        end
        refresh
      end
      if Input.repeat?(Input::ACTION) && param != 3
        @metricsChanged = true if xpos != oldxpos || ypos != oldypos
        ret = true
        pbPlayDecisionSE
        break
      elsif Input.repeat?(Input::BACK)
        case param
        when 0
          @metrics[:back][0] = oldxpos
          @metrics[:back][1] = oldypos
        when 1
          @metrics[:front][0] = oldxpos
          @metrics[:front][1] = oldypos
        when 3
          @metrics[:shadow_x] = oldxpos
        end
        pbPlayCancelSE
        refresh
        break
      elsif Input.repeat?(Input::USE)
        @metricsChanged = true if xpos != oldxpos || (param != 3 && ypos != oldypos)
        pbPlayDecisionSE
        break
      end
    end
    @sprites["info"].visible = false
    sprite.visible = true
    return ret
  end
  
  def pbMenu(species, form, gmax)
    pbChangeSpecies(species, form, gmax)
    refresh
    cw = Window_CommandPokemon.new(
      [_INTL("Set Ally Position"),
       _INTL("Set Enemy Position"),
       _INTL("Set Shadow Size"),
       _INTL("Set Shadow Position"),
       _INTL("Auto-Position Sprites")]
    )
    cw.x        = Graphics.width - cw.width
    cw.y        = Graphics.height - cw.height
    cw.viewport = @viewport
    ret = -1
    loop do
      Graphics.update
      Input.update
      cw.update
      self.update
      if Input.trigger?(Input::USE)
        pbPlayDecisionSE
        ret = cw.index
        break
      elsif Input.trigger?(Input::BACK)
        pbPlayCancelSE
        break
      end
    end
    cw.dispose
    return ret
  end
  
  def pbChooseSpecies
    if @starting
      pbFadeInAndShow(@sprites) { update }
      @starting = false
    end
    cw = Window_CommandPokemonEx.newEmpty(0, 0, 260, 32 + (24 * 6), @viewport)
    cw.rowHeight = 24
    pbSetSmallFont(cw.contents)
    cw.x = Graphics.width - cw.width
    cw.y = Graphics.height - cw.height
    allspecies = []
    GameData::Species.each do |sp|
	  next if sp.no_dynamax && @dynamax_mode
      name = (sp.form == 0) ? sp.name : _INTL("{1} (form {2})", sp.real_name, sp.form)
      allspecies.push([sp.id, sp.species, sp.form, name, false]) if name && !name.empty?
      if @dynamax_mode && sp.hasGmax? && !(sp.species == :ALCREMIE && sp.form > 0)
        name = _INTL("{1} (G-Max)", sp.real_name)
        allspecies.push([sp.id, sp.species, sp.form, name, true]) if name && !name.empty?
      end
    end
    allspecies.sort! { |a, b| a[3] <=> b[3] }
    commands = []
    allspecies.each { |sp| commands.push(sp[3]) }
    cw.commands = commands
    cw.index    = @oldSpeciesIndex
    ret = false
    oldindex = -1
    loop do
      Graphics.update
      Input.update
      cw.update
      if cw.index != oldindex
        oldindex = cw.index
        @metrics.clear
        pbChangeSpecies(allspecies[cw.index][1], allspecies[cw.index][2], allspecies[cw.index][4])
        refresh
      end
      self.update
      if Input.trigger?(Input::BACK)
        @metrics.clear
        pbChangeSpecies(nil, nil, nil)
        refresh
        break
      elsif Input.trigger?(Input::USE)
        pbChangeSpecies(allspecies[cw.index][1], allspecies[cw.index][2], allspecies[cw.index][4])
        ret = [allspecies[cw.index][1], allspecies[cw.index][2], allspecies[cw.index][4]]
        break
      end
    end
    @oldSpeciesIndex = cw.index
    cw.dispose
    return ret
  end
end

class SpritePositionerScreen
  def pbStart
    @scene.pbOpen
    loop do
      species = @scene.pbChooseSpecies
      break if !species
      loop do
        command = @scene.pbMenu(*species)
        break if command < 0
        loop do
          par = @scene.pbSetParameter(command)
          break if !par
          command = (command + 1) % 3
        end
      end
    end
    @scene.pbClose
  end
end

#-------------------------------------------------------------------------------
# Automatically positions Dynamax sprites.
#-------------------------------------------------------------------------------
def pbAutoPositionDynamax
  t = Time.now.to_i
  species_list = GameData::PowerMove.species_list("G-Max")
  # Gigantamax sprites
  for i in species_list
    next if !GameData::Species.try_get(i)
    if Time.now.to_i - t >= 5
      t = Time.now.to_i
      Graphics.update
    end
    sp = GameData::Species.get(i)
    metrics = GameData::SpeciesMetrics.get_species_form(sp.species, sp.form)
    bitmap1 = GameData::Species.sprite_bitmap(sp.species, sp.form, nil, nil, nil, true, false, false, true)
    bitmap2 = GameData::Species.sprite_bitmap(sp.species, sp.form, nil, nil, nil, false, false, false, true)
    if bitmap1&.bitmap
      metrics.gmax_back_sprite[0] = 0
      metrics.gmax_back_sprite[1] = ((bitmap1.height - (findBottom(bitmap1.bitmap) + 1)) / 2) + 45
    end
    if bitmap2&.bitmap
      metrics.gmax_front_sprite[0] = 0
      metrics.gmax_front_sprite[1] = ((bitmap2.height - (findBottom(bitmap2.bitmap) + 1)) / 2) + 4
    end
    metrics.gmax_altitude    = 0
    metrics.gmax_shadow_x    = 0
    metrics.gmax_shadow_size = 3
    bitmap1&.dispose
    bitmap2&.dispose
  end
  # All other Dynamax sprites
  GameData::Species.each do |sp|
    metrics = GameData::SpeciesMetrics.get_species_form(sp.species, sp.form)
    if Time.now.to_i - t >= 5
      t = Time.now.to_i
      Graphics.update
    end
    metrics.dmax_back_sprite[0]  = metrics.back_sprite[0]
    metrics.dmax_back_sprite[1]  = metrics.back_sprite[1]
    metrics.dmax_front_sprite[0] = metrics.front_sprite[0]
    metrics.dmax_front_sprite[1] = metrics.front_sprite[1] + 8
    metrics.dmax_altitude        = metrics.front_sprite_altitude
    metrics.dmax_shadow_x        = metrics.shadow_x
    metrics.dmax_shadow_size     = 3
  end
  GameData::SpeciesMetrics.save
  Compiler.write_dynamax_metrics
end

alias zud_pbAutoPositionAll pbAutoPositionAll
def pbAutoPositionAll
  if Input.press?(Input::CTRL)
    pbMessage(_INTL("Auto-positioning Dynamax sprites..."))
    pbAutoPositionDynamax
  else
    zud_pbAutoPositionAll
  end
end