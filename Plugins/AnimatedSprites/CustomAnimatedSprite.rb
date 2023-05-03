class CustomAnimatedSprite
  def initialize(_spritePath, _spriteName, _x, _y, _frames = 4, _viewport = nil, _width = -1, _height = -1, _multiplier = 10)
    @viewport = _viewport
    @sprite=Sprite.new(_viewport)
    @sprite.x = _x
    @sprite.y = _y
    @bitmapFile=RPG::Cache.load_bitmap(_spritePath, _spriteName)
    @bitmap=Bitmap.new(@bitmapFile.width,@bitmapFile.height)
    @bitmap.blt(0,0,@bitmapFile,Rect.new(0,0,@bitmapFile.width,@bitmapFile.height))

    @width=_width > 0 ? _width*2 : @bitmap.height*2
    @height=_height > 0 ? _height*2 : @bitmap.height*2

    @totalFrames=@bitmap.width/@bitmap.height
    @frames = _frames
    @setFrames = _frames
    @currentFrame = 0
    @animationframes = @totalFrames*@frames
    @currentIndex = 0
    @disposed = false

    @updateFrame = 0
    @updateFrameMultiplier = _multiplier
    @totalUpdateFrame = Graphics.frame_rate/@updateFrameMultiplier
    @loop_points=[0,@totalFrames]   
    @actualBitmap=Bitmap.new(@width,@height)
    @actualBitmap.clear
    @actualBitmap.stretch_blt(Rect.new(0,0,@width,@height),@bitmap,Rect.new(@currentIndex*(@width/2),0,@width/2,@height/2))
    pbUpdate
  end

  def dispose
    pbDispose
  end

  def pbDispose
    return if @disposed
    @actualBitmap.dispose if @actualBitmap && !@actualBitmap.disposed?
    @sprite.dispose if @sprite && !@sprite.disposed?
    @sprite=nil
    @disposed=true
  end

  def disposed?
    return pbIsDisposed?
  end

  def pbIsDisposed?
     return @disposed
  end

  def pbUpdate
      return if !@sprite || @sprite && @sprite.disposed?
      @updateFrame+=1

      return if @updateFrame < @totalUpdateFrame
      
      @updateFrame = 0
      @frames = @setFrames
      @currentFrame+=1
      if @currentFrame >= @frames
        @currentIndex+=1
        @currentIndex=@loop_points[0] if @currentIndex >= @loop_points[1]
        @currentIndex=@loop_points[1]-1 if @currentIndex < @loop_points[0]
        @frame=0
      end
      @actualBitmap.clear
      @actualBitmap.stretch_blt(Rect.new(0,0,@width,@height),@bitmap,Rect.new(@currentIndex*(@width/2),0,@width/2,@height/2))
      @sprite.bitmap=@actualBitmap
  end
end