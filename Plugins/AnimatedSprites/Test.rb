

def pbTestAnimatedSprite
  animatedIcon = CustomAnimatedSprite.new("Graphics/EBDX/Battlers/Front/","001", 100, 100, 8, Viewport.new(0,0,Graphics.width,Graphics.height))
  loop do
       Graphics.update
       Input.update
       break if Input.trigger?(Input::B)
       animatedIcon.pbUpdate
  end
  animatedIcon.dispose
end