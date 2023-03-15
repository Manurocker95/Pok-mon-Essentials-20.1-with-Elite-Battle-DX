#-------------------------------------------------------------------------------
#  New bitmap wrapper by Luka S.J. EBDX sprites
#  Creates an animated bitmap (different from regular bitmaps)
#-------------------------------------------------------------------------------
class EBDXBitmapWrapper
  attr_reader :width, :height, :total_frames, :frame_idx
  attr_accessor :constrict, :scale, :frame_skip, :constrict_x, :constrict_y
  #-----------------------------------------------------------------------------
  #  class constructor
  #-----------------------------------------------------------------------------
  def initialize(file, scale = Settings::FRONT_BATTLER_SPRITE_SCALE, skip = 1)
    # failsafe checks
    raise "EBDXBitmapWrapper filename is nil." if file.nil?
    #---------------------------------------------------------------------------
    @scale        = scale
    @constrict    = nil
    @width        = 0
    @height       = 0
    @frame        = 0
    @frames       = 2
    @frame_skip   = skip
    @direction    = 1
    @total_frames = 0
    @frame_idx    = 0
    @changed_hue  = false
    @speed        = 1
    # 0 - not moving at all
    # 1 - normal speed
    # 2 - medium speed
    # 3 - slow speed
    @bmp_file = file
    # initializes full Pokemon bitmap
    @bitmaps = []
    #---------------------------------------------------------------------------
    self.refresh
    #---------------------------------------------------------------------------
  end
  #-----------------------------------------------------------------------------
  #  check if already a bitmap
  #-----------------------------------------------------------------------------
  def is_bitmap?
    return @bmp_file.is_a?(BitmapWrapper) || @bmp_file.is_a?(Bitmap)
  end
  #-----------------------------------------------------------------------------
  #  returns proper object values when requested
  #-----------------------------------------------------------------------------
  def delta; return Graphics.frame_rate / 40.0; end
  #-----------------------------------------------------------------------------
  def length; return @total_frames; end
  #-----------------------------------------------------------------------------
  # Dispose related methods
  #-----------------------------------------------------------------------------
  def disposed?; return @bitmaps.empty?; end
  #-----------------------------------------------------------------------------
  def dispose
    @bitmaps.each { |bmp| bmp.dispose }
    @bitmaps.clear
    @temp_bmp.dispose if @temp_bmp && !@temp_bmp.disposed?
  end
  #-----------------------------------------------------------------------------
  # Bitmap getting and setting methods
  #-----------------------------------------------------------------------------
  def bitmap
    return @bmp_file if self.is_bitmap? && !@bmp_file.disposed?
    return nil if self.disposed?
    # applies constraint if applicable
    x, y, w, h = self.box
    @temp_bmp.clear
    @temp_bmp.blt(x, y, @bitmaps[@frame_idx], Rect.new(x, y, w, h))
    return @temp_bmp
  end
  #-----------------------------------------------------------------------------
  def bitmap=(value)
    return if !value.is_a?(String)
    @bmp_file = value
    self.refresh
  end
  #-----------------------------------------------------------------------------
  def copy; return @bitmaps[@frame_idx].clone; end
  #-----------------------------------------------------------------------------
  #  preparation and compiling of spritesheet for sprite alterations
  #-----------------------------------------------------------------------------
  def prepare_strip
    @strip = []
    bmp = Bitmap.new(@bmp_file)
    @total_frames.times do |i|
      bitmap = Bitmap.new(@width, @height)
      bitmap.stretch_blt(Rect.new(0, 0, @width, @height), bmp, Rect.new((@width / @scale) * i, 0, @width / @scale, @height / @scale))
      @strip.push(bitmap)
    end
  end
  #-----------------------------------------------------------------------------
  def alter_bitmap(index); return @strip[index]; end
  #-----------------------------------------------------------------------------
  def compile_strip
    self.refresh(@strip)
  end
  #-----------------------------------------------------------------------------
  def each; end
  #-----------------------------------------------------------------------------
  #  refreshes the metric parameters
  #-----------------------------------------------------------------------------
  def refresh(bitmaps = nil)
    # dispose existing
    self.dispose
    # temporarily load the full file
    if bitmaps.nil? && @bmp_file.is_a?(String)
      # calculate initial metrics
      f_bmp = Bitmap.new(@bmp_file)
      # construct frames
      if f_bmp.animated?
        @width = f_bmp.width * @scale
        @height = f_bmp.height * @scale
        f_bmp.frame_count.times do |i|
          f_bmp.goto_and_stop(i)
          bitmap = Bitmap.new(@width, @height)
          bitmap.stretch_blt(Rect.new(0, 0, @width, @height), f_bmp, Rect.new(0, 0, f_bmp.width, f_bmp.height))
          @bitmaps.push(bitmap)
        end
      elsif f_bmp.width > (f_bmp.height * 2)
        @width = f_bmp.height * @scale
        @height = f_bmp.height * @scale
        (f_bmp.width.to_f / f_bmp.height).ceil.times do |i|
          x = i * f_bmp.height
          bitmap = Bitmap.new(@width, @height)
          bitmap.stretch_blt(Rect.new(0, 0, @width, @height), f_bmp, Rect.new(x, 0, f_bmp.height, f_bmp.height))
          @bitmaps.push(bitmap)
        end
      else
        @width = f_bmp.width * @scale
        @height = f_bmp.height * @scale
        bitmap = Bitmap.new(@width, @height)
        bitmap.stretch_blt(Rect.new(0, 0, @width, @height), f_bmp, Rect.new(0, 0, f_bmp.width, f_bmp.height))
        @bitmaps.push(bitmap)
      end
      f_bmp.dispose
    else
      @bitmaps = bitmaps
    end
    if @bitmaps.length < 1 && !self.is_bitmap?
      raise "Unable to construct proper bitmap sheet from `#{@bmp_file}`"
    end
    # calculates the total number of frames
    if !self.is_bitmap?
      @total_frames = @bitmaps.length
      @temp_bmp = Bitmap.new(@bitmaps[0].width, @bitmaps[0].width)
    end
  end
  #-----------------------------------------------------------------------------
  #  sets speed of animation
  #-----------------------------------------------------------------------------
  def setSpeed(value); @speed = value; end
  #-----------------------------------------------------------------------------
  #  reverses the animation
  #-----------------------------------------------------------------------------
  def reverse; @direction = @direction > 0 ? -1 : 1; end
  #-----------------------------------------------------------------------------
  #  jumps animation to specific frame
  #-----------------------------------------------------------------------------
  def to_frame(frame)
    # checks if specified string parameter
    frame = frame == "last" ? @total_frames - 1 : 0 if frame.is_a?(String)
    # sets frame
    frame = @total_frames - 1 if frame >= @total_frames
    frame = 0 if frame < 0
    @frame_idx = frame
  end
  #-----------------------------------------------------------------------------
  #  changes the hue of the bitmap
  #-----------------------------------------------------------------------------
  def hue_change(value)
    @bitmaps.each { |bmp| bmp.hue_change(value) }
    @changed_hue = true
  end
  #-----------------------------------------------------------------------------
  def changedHue?; return @changed_hue; end
  #-----------------------------------------------------------------------------
  #  performs animation loop once
  #-----------------------------------------------------------------------------
  def play
    return if self.finished?
    self.update
  end
  #-----------------------------------------------------------------------------
  #  returns bitmap to original state
  #-----------------------------------------------------------------------------
  def deanimate
    @frame = 0
    @frame_idx = 0
  end
  #-----------------------------------------------------------------------------
  #  checks if animation is finished
  #-----------------------------------------------------------------------------
  def finished?; return (@frame_idx >= @total_frames - 1); end
  #-----------------------------------------------------------------------------
  #  fetches the constraints for the sprite
  #-----------------------------------------------------------------------------
  def box
    c_x = @constrict_x || @constrict || @width
    x = (c_x < @width ? ((@width - c_x) / 2.0).ceil : 0)
    w = (c_x < @width ? c_x : @width)
    c_y = @constrict_y || @constrict || @height
    y = (c_y < @height ? ((@height - c_y) / 2.0).ceil : 0)
    h = (c_y < @height ? c_y : @height)
    return x, y, w, h
  end
  #-----------------------------------------------------------------------------
  #  performs sprite animation
  #-----------------------------------------------------------------------------
  def update
    return false if self.disposed?
    return false if @speed < 1
    # frame skip
    @frames = case @speed
              when 2 then 4
              when 3 then 5
              else        2
              end
    @frame += 1
    return if @frame < @frames * @frame_skip * self.delta
    # processes animation speed
    @frame_idx += @direction
    @frame_idx = 0 if @frame_idx >= @total_frames
    @frame_idx = @total_frames - 1 if @frame_idx < 0
    @frame = 0
  end
  #-----------------------------------------------------------------------------
end
