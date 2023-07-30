#-------------------------------------------------------------------------------
#  STRINGSHOT
#-------------------------------------------------------------------------------
EliteBattle.defineMoveAnimation(:STRINGSHOT) do
  EliteBattle.playMoveAnimation(:SPIDERWEB, @scene, @userIndex, @targetIndex, @hitNum, @multiHit, nil, false)
end
#-------------------------------------------------------------------------------
#  SPIDERWEB
#-------------------------------------------------------------------------------
EliteBattle.defineMoveAnimation(:SPIDERWEB) do
  # set up animation
  fp = {}; rndx = []; rndy = []; dx = []; dy = []; px = []; py = []; rangl = []
  for i in 0...12
    fp["p#{i}"] = Sprite.new(@viewport)
    fp["p#{i}"].bitmap = Bitmap.new(16,16)
    fp["p#{i}"].bitmap.bmp_circle
    fp["p#{i}"].ox = 8
    fp["p#{i}"].oy = 8
    fp["p#{i}"].opacity = 0
    fp["p#{i}"].z = @targetSprite.z
    px.push(0)
    py.push(0)
  end	
  fp["bg"] = Sprite.new(@viewport)
  fp["bg"].bitmap = Bitmap.new(@viewport.width,@viewport.height)
  fp["bg"].bitmap.fill_rect(0,0,fp["bg"].bitmap.width,fp["bg"].bitmap.height,Color.new(229,255,204))
  fp["bg"].opacity = 0
  for k in 0...64
    i = 63-k
    fp["#{i}"] = Sprite.new(@viewport)
    bmp = pbBitmap("Graphics/EBDX/Animations/Moves/eb551_2")
    fp["#{i}"].bitmap = Bitmap.new(bmp.width,bmp.height)
    fp["#{i}"].bitmap.blt(0,0,bmp,Rect.new(0,0,bmp.width,bmp.height))
    fp["#{i}"].ox = fp["#{i}"].bitmap.width/2
    fp["#{i}"].oy = fp["#{i}"].bitmap.height/2
    fp["#{i}"].opacity = 0
    fp["#{i}"].z = 19
    #fp["#{i}"].color = Color.new(248,248,248,200)
    rndx.push(rand(16)); rndy.push(rand(16)); rangl.push(rand(2))
    dx.push(0); dy.push(0)
  end
  16.times do
    fp["bg"].opacity += 12
    @scene.wait(1,true)
  end
  for i in 0...64
    pbSEPlay("EBDX/Anim/water1",60) if i%4==0 && i < 48
    ax, ay = @userSprite.getAnchor
    cx, cy = @targetSprite.getCenter(true)
    for j in 0...64
      if fp["#{j}"].opacity == 0
        dx[j] = ax - 8*@userSprite.zoom_x*0.5 + rndx[j]*@userSprite.zoom_x*0.5
        dy[j] = ay - 8*@userSprite.zoom_y*0.5 + rndy[j]*@userSprite.zoom_y*0.5
        fp["#{j}"].x = dx[j]
        fp["#{j}"].y = dy[j]
        fp["#{j}"].zoom_x = 0.8#(!@targetIsPlayer ? 1.2 : 0.8)#@userSprite.zoom_x
        fp["#{j}"].zoom_y = 0.8#(!@targetIsPlayer ? 1.2 : 0.8)#@userSprite.zoom_y
        fp["#{j}"].opacity = 128 if !(j>i*2)
      end
      next if j>(i*2)
      x2 = cx - 8*@targetSprite.zoom_x*0.5 + rndx[j]*@targetSprite.zoom_x*0.5
      y2 = cy - 8*@targetSprite.zoom_y*0.5 + rndy[j]*@targetSprite.zoom_y*0.5
      x0 = dx[j]
      y0 = dy[j]
      fp["#{j}"].x += (x2 - x0)*0.1
      fp["#{j}"].y += (y2 - y0)*0.1
      fp["#{j}"].zoom_x += 0.04#(factor - fp["#{j}"].zoom_x)*0.2
      fp["#{j}"].zoom_y += 0.04#(factor - fp["#{j}"].zoom_y)*0.2
      fp["#{j}"].opacity += 32
      fp["#{j}"].angle += 8*(rangl[j]==0 ? -1 : 1)
      fp["#{j}"].angle = -Math.atan(1.0*(y2-y0)/(x2-x0))*180/Math::PI + (rand(4)==0 ? 180 : 0)
      fp["#{j}"].color.alpha -= 5 if fp["#{j}"].color.alpha > 0
      nextx = fp["#{j}"].x# + (x2 - x0)*0.1
      nexty = fp["#{j}"].y# + (y2 - y0)*0.1
      if !@targetIsPlayer
        fp["#{j}"].visible = false if nextx > cx && nexty < cy
      else
        fp["#{j}"].visible = false if nextx < cx && nexty > cy
      end
    end
    @targetSprite.still if i >= 64
    @vector.set(@scene.getRealVector(@targetIndex, @targetIsPlayer)) if i == 16
    @vector.inc = 0.1 if i == 64
    @scene.wait(1,true)
  end
    cxT, cyT = @targetSprite.getCenter(true)
    fp["net"] = Sprite.new(@viewport)
	fp["net"].bitmap = pbBitmap("Graphics/EBDX/Animations/Moves/eb621")
	fp["net"].center!
	fp["net"].x = cxT
	fp["net"].y = cyT
	fp["net"].zoom_x = 0
	fp["net"].zoom_y = 0
	fp["net"].angle = rand(360)
	fp["net"].z = @targetSprite.z + 30
	for i in 0...30
		pbSEPlay("Anim/Splat",90) if i == 5
		next if i < 1
		fp["net"].zoom_x += (1.6 - fp["net"].zoom_x)*0.1
		fp["net"].zoom_y += (1.6 - fp["net"].zoom_y)*0.1
		if fp["net"].zoom_x >= 1
		  fp["net"].opacity -= 16
		end
	    fp["net"].color.alpha -= 8
		@scene.wait(1,i < 1)
	end
  16.times do
    fp["bg"].opacity -= 20
    @scene.wait(1,true)
  end
  for j in 0...48; fp["#{j}"].visible = false; end
  @vector.reset if !@multiHit
  @vector.inc = 0.2
  pbDisposeSpriteHash(fp)
end
