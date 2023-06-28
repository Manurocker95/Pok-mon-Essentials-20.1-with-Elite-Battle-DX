#===============================================================================
# Revamps base Essentials code relatd to battle data boxes to allow for 
# plugin compatibility.
#===============================================================================


#-------------------------------------------------------------------------------
# Battler Databoxes
#-------------------------------------------------------------------------------
class Battle::Scene::PokemonDataBox < SpriteWrapper
  def initializeDataBoxGraphic(sideSize)
    onPlayerSide = @battler.index.even?
    @can_focus = PluginManager.installed?("Focus Meter System")
    @raid_boss = PluginManager.installed?("ZUD Mechanics") && @battler.effects[PBEffects::MaxRaidBoss]
    path = "Graphics/Pictures/Battle/"
    path = "Graphics/Plugins/Focus Meter/Databoxes/" if @can_focus
    player_normal = path + "databox_normal"
    player_thin   = path + "databox_thin"
    enemy_normal  = path + "databox_normal_foe"
    enemy_thin    = path + "databox_thin_foe"
    player_data   = (sideSize == 1) ? player_normal : player_thin
    enemy_data    = (sideSize == 1) ? enemy_normal  : enemy_thin
    enemy_data    = "Graphics/Plugins/ZUD/Battle/databox_raid" if @raid_boss
    bgFilename    = [player_data, enemy_data][@battler.index % 2]
    if @can_focus
      focus_InitializeDatabox(bgFilename, onPlayerSide)
      focus_MeterSetup(onPlayerSide)
    end
    @databoxBitmap&.dispose
    @databoxBitmap = AnimatedBitmap.new(bgFilename)
    if onPlayerSide
      @showHP  = true if sideSize == 1
      @showExp = true if sideSize == 1
      @spriteX = Graphics.width - 244
      @spriteY = Graphics.height - 192
      @spriteBaseX = 34
    elsif @raid_boss
      @spriteX = @spriteY = @spriteBaseX = 0
    else
      @spriteX = -16
      @spriteY = 36
      @spriteBaseX = 16
    end
    case sideSize
    when 2
      @spriteX += (PluginManager.installed?("Modular Battler Scene")) ? [0,0,0,0][@battler.index] : [-12,12,0,0][@battler.index]
      @spriteY += [-20, -34, 34, 20][@battler.index]
    when 3
      @spriteX += (PluginManager.installed?("Modular Battler Scene")) ? [0,0,0,0,0,0][@battler.index] : [-12,12,-6,6,0,0][@battler.index]
      @spriteY += [-42, -46,  4,  0, 50, 46][@battler.index]
    when 4
      @spriteX += [  0,  0,  0,  0,  0,   0,  0,  0][@battler.index]
      @spriteY += [-88,-46,-42,  0,  4,  46, 50, 92][@battler.index]
    when 5
      @spriteX += [   0,  0,  0,  0,  0,  0,  0,  0,  0,  0][@battler.index]
      @spriteY += [-134,-46,-88,  0,-42, 46,  4, 92, 50,138][@battler.index]
    end
  end
  
  alias :dx_x= :x=
  def x=(value)
    self.dx_x=(value)
    @hpBar.x = value + 20 if @raid_boss
    pbSetFocusBarX(value) if @can_focus
  end

  alias :dx_y= :y=
  def y=(value)
    self.dx_y=(value)
    @hpBar.y = value + 34 if @raid_boss
    pbSetFocusBarY(value) if @can_focus
  end
  
  alias dx_refresh refresh
  def refresh
    dx_refresh
    return if !@battler.pokemon
    if @raid_boss
      draw_raid_shield
      draw_raid_counters
    end
    refreshMeter if @can_focus
  end
end