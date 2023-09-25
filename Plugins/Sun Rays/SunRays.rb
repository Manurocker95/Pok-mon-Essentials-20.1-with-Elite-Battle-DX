#===============================================================================
# SCRIPT DE RAYO DE SOL - CREADO POR POLECTRON
#===============================================================================
# * Settings
#===============================================================================
  BGPATH="Graphics/Pictures/Sun" #Ruta de la imagen de sol
#===============================================================================
# * Main
#===============================================================================
  UPDATESPERSECONDS=5
class Spriteset_Map
  
  alias :initializeSun :initialize
  alias :disposeOldSun :dispose
  alias :updateOldSun :update
  
  def initialize(map=nil)
    @sun = []
    initializeSun(map)
    $sun_need_refresh = true
    $sun_switch = true
  end
    
  def dispose
    disposeOldSun
    disposeSun
  end
  
  def update
    updateOldSun
    updateSun
  end

def pbGetMetadata(map_id)
  return GameData::MapMetadata.try_get(map_id)
end

#===============================================================================
# * HUD Data
#===============================================================================
  def createSun
    @hideSun = PBDayNight.isNight? || !$sun_switch || !pbGetMetadata($game_map.map_id).outdoor_map
    @correctWather = GameData::Weather.get($game_screen.weather_type).category == :None
    
    return if @hideSun || !@correctWather || $game_map.fog_name != ""
    yposition = 0
    @sun = []
#===============================================================================
# * Image
#===============================================================================
    if BGPATH != "" # Make sure that there is nothing between the two ".
      bgbar=IconSprite.new(0,yposition,@viewport1)
      bgbar.setBitmap(BGPATH)
      bgbar.z = 9999
      bgbar.blend_type = 1
      @sun.push(bgbar)  
    end
  end
#===============================================================================
  
  def updateSun
    for sprite in @sun
      sprite.update
    end
  end 
  
  def disposeSun
    for sprite in @sun
      sprite.dispose
    end
    @sun.clear
  end
end

#===============================================================================

class Scene_Map
  alias :updateOldSun :update
  alias :miniupdateOldSun :miniupdate
  alias :createSpritesetsOldSun :createSpritesets
  
  UPDATERATE = (UPDATESPERSECONDS>0) ? 
      (Graphics.frame_rate/UPDATESPERSECONDS).floor : 0x3FFF 
    
  def update
    updateOldSun
    checkAndUpdateSun
  end
  
  def miniupdate
    miniupdateOldSun
    checkAndUpdateSun
  end
  
  def createSpritesets
    createSpritesetsOldSun
    checkAndUpdateSun
  end  
  
  def checkAndUpdateSun
    $sun_need_refresh = (Graphics.frame_count%UPDATERATE==0 ||
      $sun_need_refresh)
    if $sun_need_refresh
      for s in @spritesets.values
        s.disposeSun
        s.createSun
      end
      $sun_need_refresh = false
    end
  end
end