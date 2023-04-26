class Footprint
    def initialize(event,position)
      return if !$scene || !$scene.is_a?(Scene_Map) ||
      event!=$game_player && (event.character_name=="" || (event.name.include?(FootprintSettings::EVENT_NAME_SKIP_FOOTPRINT) or pbEventCommentInput(event,0,FootprintSettings::EVENT_NAME_SKIP_FOOTPRINT)))
      character_sprites=$scene.spriteset.character_sprites
      viewport=$scene.spriteset.pbViewport1
      footsprites=$scene.spriteset.footsprites
      nid=getNewId
      fev=$game_map.events[nid]
      rpgEvent=RPG::Event.new(position[0],position[1])
      rpgEvent.id=nid       
      fev=Game_Event.new($game_map.map_id,rpgEvent,$game_map)
      eventsprite=Sprite_Character.new(viewport,fev)
      character_sprites.push(eventsprite)
      footsprites.push(Footsprite.new(eventsprite,fev,viewport,
      $game_map,position[2],nid,character_sprites,(event==$game_player)))
    end
  end
  
  def getNewId
    newId = 1
    while $game_map.events[newId] != nil do 
      break if $game_map.events[newId].erased
      newId += 1
    end
    return newId
  end
    
  class Game_Event < Game_Character
    attr_reader :erased
  end
  
  class Sprite_Character
    alias old_initialize_foot initialize
    def initialize(viewport, character = nil)
      old_initialize_foot(viewport, character)
      @disposed=false
    end
    
    alias old_update_foot update
    def update
      return if @disposed
      old_update_foot
    end
  
    alias old_dispose_foot dispose
    def dispose
      old_dispose_foot
      @disposed=true
    end
  end
  
  class Spriteset_Map
    attr_accessor :character_sprites
    attr_accessor :footsprites
      
    alias old_initialize initialize
    def initialize(map=nil)
      old_initialize(map)
      @footsprites=[]
    end

    def pbViewport1
        return @@viewport1
    end    
    
    def putFootprint(event,pos)
      foot=Footprint.new(event,pos) 
    end
    
    alias old_dispose dispose
    def dispose
      old_dispose
      if @footsprites!=nil
        for sprite in @footsprites
          sprite.dispose
        end
      end
      @footsprites.clear
    end
    
    alias old_update update
    def update
      old_update
      if @footsprites!=nil
        for sprite in @footsprites
          sprite.update 
        end
      end
    end
  end
  
  class Scene_Map
    def spriteset?
      return true if @spritesets!=nil
      return false
    end
  end
  
  class Game_Character
    alias old_increase_foot increase_steps
    
    def get_last_pos
      case direction
      when 2 # Move down
        return [@x,@y-1,direction]
      when 4 # Move left
        return [@x+1,@y,direction]
      when 6 # Move right
        return [@x-1,@y,direction]
      when 8 # Move up
        return [@x,@y+1,direction]
      end
      return false
    end
    
    def terrain_tag_pos(x=@x,y=@y)
      return $game_map.terrain_tag(x, y)
    end
    
    def increase_steps
      if terrain_tag_pos(get_last_pos[0],get_last_pos[1])==FootprintSettings::TERRAIN_FOOT
        $scene.spriteset.putFootprint(self,get_last_pos) if $scene.is_a?(Scene_Map) &&
        $scene.spriteset?
       end  
      old_increase_foot
    end
  end
  
  class Footsprite
    def initialize(sprite,event,viewport,map,direction,nid,chardata,player)
      @rsprite=sprite
      @sprite=Sprite.new(viewport)
      if player && $PokemonGlobal.bicycle
        @sprite.bitmap=RPG::Cache.load_bitmap(FootprintSettings::FOOTPRINT_IMAGE_DIRECTORY, FootprintSettings::FOOTPRINT_BIKE_IMAGE)
        else
        @sprite.bitmap=RPG::Cache.load_bitmap(FootprintSettings::FOOTPRINT_IMAGE_DIRECTORY, FootprintSettings::FOOTPRINT_REGULAR_IMAGE)
      end
      @realwidth=@sprite.bitmap.width/4
      @sprite.src_rect.width=@realwidth
      @opacity=FootprintSettings::INITIAL_FOOT_OPACITY
      setFootset(direction)
      @event=event
      @disposed=false
      @map=map
      @eventid=nid
      @viewport=viewport
      @chardata=chardata
      update
    end
    
    def setFootset(direction)
      case direction
      when 2 # Move down
        @sprite.src_rect.x=0
      when 4 # Move left
        @sprite.src_rect.x=@realwidth*3
      when 6 # Move right
        @sprite.src_rect.x=@realwidth*2
      when 8 # Move up
        @sprite.src_rect.x=@realwidth
      end
      @sprite.opacity=@opacity
    end
  
    def dispose
      if !@disposed
       @disposed=true
       @event.erase
       for i in 0...@chardata.length
         @chardata.delete_at(i) if @chardata[i]==@rsprite
       end
       @rsprite.dispose
       @sprite.dispose 
       @sprite=nil
      end
    end
   
    def update 
      return if @disposed 
      x=@rsprite.x-@rsprite.ox
      y=@rsprite.y-@rsprite.oy
      width=@rsprite.src_rect.width
      height=@rsprite.src_rect.height
      @sprite.x=x+width/2
      @sprite.y=y+height
      @sprite.ox=@realwidth/2
      @sprite.oy=@sprite.bitmap.height
      @sprite.z=@rsprite.z-2
      @opacity-=FootprintSettings::FOOT_DELAY_VELOCITY
      @sprite.opacity=@opacity
      if @sprite.opacity<=0
        dispose
      end
    end
  end