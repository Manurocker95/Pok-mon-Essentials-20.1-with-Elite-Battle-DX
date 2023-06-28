#===============================================================================
# Adds Dynamax displays to the Summary UI.
#===============================================================================
class PokemonSummary_Scene
  #-----------------------------------------------------------------------------
  # Displays G-Max Factor.
  #-----------------------------------------------------------------------------
  alias zud_drawPage drawPage
  def drawPage(page)
    @sprites["pokemon"].unDynamax if @pokemon.dynamax?
	if !@sprites["zud_overlay"]
      @sprites["zud_overlay"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    else
      @sprites["zud_overlay"].bitmap.clear
    end
	zud_drawPage(page)
	overlay = @sprites["overlay"].bitmap
    coords = (PluginManager.installed?("BW Summary Screen")) ? [454, 82] : [88, 95]
    pbDisplayGmaxFactor(@pokemon, overlay, coords[0], coords[1])
  end
  
  #-----------------------------------------------------------------------------
  # Displays Dynamax meter. Won't display on Pokemon that cannot use Dynamax.
  # Will not display if the NO_DYNAMAX switch is active.
  #-----------------------------------------------------------------------------
  alias zud_drawPageTwo drawPageTwo
  def drawPageTwo
    if PluginManager.installed?("BW Summary Screen")
      if @pokemon.dynamax_able? && !@pokemon.isSpecies?(:ETERNATUS) && !$game_switches[Settings::NO_DYNAMAX]
        path = "Graphics/Pictures/Summary/"
        meter = (SUMMARY_B2W2_STYLE) ? "overlay_dynamax_B2W2" : "overlay_dynamax"
        xpos = Graphics.width - 262
        imagepos = [[sprintf(path + meter), xpos, 322]]
        overlay = @sprites["zud_overlay"].bitmap
        pbSetSmallFont(overlay)
        pbDrawImagePositions(overlay, imagepos)
        dlevel = @pokemon.dynamax_lvl
        levels = AnimatedBitmap.new(_INTL(path + "dynamax_bar"))
        overlay.blt(xpos + 82, 352, levels.bitmap, Rect.new(0, 0, dlevel * 16, 14))
        pbDrawTextPositions(overlay, [ [_INTL("Dynamax Lv."), Graphics.width - 102, 324, 2, Color.new(255, 255, 255), Color.new(123, 123, 123)] ])
      end
    end
    zud_drawPageTwo
  end
  
  alias zud_drawPageThree drawPageThree
  def drawPageThree
    if !PluginManager.installed?("BW Summary Screen")
      if @pokemon.dynamax_able? && !@pokemon.isSpecies?(:ETERNATUS) && !$game_switches[Settings::NO_DYNAMAX]
        path = "Graphics/Plugins/ZUD/UI/"
        imagepos = [[sprintf(path + "dynamax_meter"), 56, 308]]
        overlay = @sprites["zud_overlay"].bitmap
        pbDrawImagePositions(overlay, imagepos)
        dlevel = @pokemon.dynamax_lvl
        levels = AnimatedBitmap.new(_INTL(path + "dynamax_levels"))
        overlay.blt(69, 325, levels.bitmap, Rect.new(0, 0, dlevel * 12, 21))
      end
    end
    zud_drawPageThree
  end
end


#===============================================================================
# Draws the icon for G-Max Factor on a UI overlay.
#===============================================================================
def pbDisplayGmaxFactor(pokemon, overlay, xpos, ypos)
  return if !pokemon.gmax_factor? || pokemon.isSpecies?(:ETERNATUS)
  path = (PluginManager.installed?("BW Party Screen")) ? "Graphics/Pictures/Summary/gfactor" : "Graphics/Plugins/ZUD/UI/gfactor"
  pbDrawImagePositions(overlay, [ [path, xpos, ypos] ])
end