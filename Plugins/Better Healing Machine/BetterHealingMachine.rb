class MakeHealingBallGraphics
#------------------Settings

CENTRE = false #change to false if Pokéball tray is between two tiles
                            # if above is false, you need two events on the left and right side of the Pokéball tray
                            # if above is true, place a single event in the middle of your Pokéball tray

#------------------
  def initialize
    balls=[]
    for poke in $player.party
      balls.push(poke.poke_ball) if !poke.egg?
    end
    return false if balls.length==0
    @sprites={}
    @viewport=Viewport.new(0,0,Graphics.width,Graphics.height)
    @viewport.z=999999
    for i in 0...balls.length
      @sprites["ball#{i}"]=Sprite.new(@viewport)
      if pbResolveBitmap("Graphics/Pictures/Balls/ball_#{balls[i]}.png")
        @sprites["ball#{i}"].bitmap=Bitmap.new("Graphics/Pictures/Balls/ball_#{balls[i]}.png")
      else
        @sprites["ball#{i}"].bitmap=Bitmap.new("Graphics/Pictures/Balls/ball_POKEBALL.png")
      end
      @sprites["ball#{i}"].visible=false
    end

    if CENTRE
    bitmap1=Bitmap.new(128,192) #testing
    bitmap2=Bitmap.new(128,192) #testing
    rect1=Rect.new(0,0,128,192/4) #testing was 128
    rect2=Rect.new(0,0,128,192/4) #testing was 128, need to chnage ball grpahics!!!!!
    for i in 0...balls.length
      case i
      when 0
        bitmap1.blt(0,50,@sprites["ball#{i}"].bitmap,rect1) #test
        bitmap1.blt(0,98,@sprites["ball#{i}"].bitmap,rect1)
        bitmap1.blt(0,146,@sprites["ball#{i}"].bitmap,rect1)

        bitmap2.blt(0,50,@sprites["ball#{i}"].bitmap,rect2) #test
        bitmap2.blt(0,98,@sprites["ball#{i}"].bitmap,rect2)
        bitmap2.blt(0,146,@sprites["ball#{i}"].bitmap,rect2)
      when 1
        bitmap1.blt(0,106,@sprites["ball#{i}"].bitmap,rect1)
        bitmap1.blt(0,154,@sprites["ball#{i}"].bitmap,rect1)
        
        bitmap2.blt(0,58,@sprites["ball#{i}"].bitmap,rect2)
        bitmap2.blt(0,106,@sprites["ball#{i}"].bitmap,rect2)
        bitmap2.blt(0,154,@sprites["ball#{i}"].bitmap,rect2)
      when 2
        bitmap1.blt(15,146,@sprites["ball#{i}"].bitmap,rect1)

        bitmap2.blt(15,50,@sprites["ball#{i}"].bitmap,rect1)
        bitmap2.blt(15,98,@sprites["ball#{i}"].bitmap,rect1)
        bitmap2.blt(15,146,@sprites["ball#{i}"].bitmap,rect2)
      when 3
        bitmap2.blt(15,58,@sprites["ball#{i}"].bitmap,rect2)
        bitmap2.blt(15,106,@sprites["ball#{i}"].bitmap,rect2)
        bitmap2.blt(15,154,@sprites["ball#{i}"].bitmap,rect2)
      when 4
        bitmap2.blt(0,114,@sprites["ball#{i}"].bitmap,rect2)
        bitmap2.blt(0,162,@sprites["ball#{i}"].bitmap,rect2)
      when 5
        bitmap2.blt(15,162,@sprites["ball#{i}"].bitmap,rect2)
      end
      Graphics.update
    end
    if RTP.exists?("Graphics/Characters/Healing balls 1.png")
      File.delete("Graphics/Characters/Healing balls 1.png")
    end
    if RTP.exists?("Graphics/Characters/Healing balls 2.png")
      File.delete("Graphics/Characters/Healing balls 2.png")
    end
    bitmap1.to_file("Graphics/Characters/Healing balls 1.png")
    bitmap2.to_file("Graphics/Characters/Healing balls 2.png")
    
    else #if CENTRE != true

    bitmap1=Bitmap.new(128,192)
    bitmap2=Bitmap.new(128,192)
    rect1=Rect.new(0,0,128,192/4)
    rect2=Rect.new(0,0,128,192/4)
    for i in 0...balls.length
      case i
      when 0
        bitmap1.blt(20,50,@sprites["ball#{i}"].bitmap,rect1)
        bitmap1.blt(20,98,@sprites["ball#{i}"].bitmap,rect1)
        bitmap1.blt(20,146,@sprites["ball#{i}"].bitmap,rect1)
      when 1
        bitmap2.blt(0,50,@sprites["ball#{i}"].bitmap,rect2)
        bitmap2.blt(0,98,@sprites["ball#{i}"].bitmap,rect2)
        bitmap2.blt(0,146,@sprites["ball#{i}"].bitmap,rect2)
      when 2
        bitmap1.blt(20,106,@sprites["ball#{i}"].bitmap,rect1)
        bitmap1.blt(20,154,@sprites["ball#{i}"].bitmap,rect1)
      when 3
        bitmap2.blt(0,106,@sprites["ball#{i}"].bitmap,rect2)
        bitmap2.blt(0,154,@sprites["ball#{i}"].bitmap,rect2)
      when 4
        bitmap1.blt(20,162,@sprites["ball#{i}"].bitmap,rect1)
      when 5
        bitmap2.blt(0,162,@sprites["ball#{i}"].bitmap,rect2)
      end
      Graphics.update
    end
    if RTP.exists?("Graphics/Characters/Healing balls left.png")
      File.delete("Graphics/Characters/Healing balls left.png")
    end
    if RTP.exists?("Graphics/Characters/Healing balls right.png")
      File.delete("Graphics/Characters/Healing balls right.png")
    end
    bitmap1.to_file("Graphics/Characters/Healing balls left.png")
    bitmap2.to_file("Graphics/Characters/Healing balls right.png")
    
end #CENTRE check end
    
    
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
    bitmap1.dispose
    bitmap2.dispose
  end
end