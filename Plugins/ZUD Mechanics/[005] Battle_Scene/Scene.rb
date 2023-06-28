#===============================================================================
# Battle scene Dynamax visuals.
#===============================================================================
class Battle::Scene
  #-----------------------------------------------------------------------------
  # Edited to allow for enlarged/colored Dynamax sprites.
  #-----------------------------------------------------------------------------
  def pbAnimationCore(animation, user, target, oppMove = false)
    return if !animation
    @briefMessage = false
    userSprite   = (user) ? @sprites["pokemon_#{user.index}"] : nil
    targetSprite = (target) ? @sprites["pokemon_#{target.index}"] : nil
    oldUserX = (userSprite) ? userSprite.x : 0
    oldUserY = (userSprite) ? userSprite.y : 0
    oldTargetX = (targetSprite) ? targetSprite.x : oldUserX
    oldTargetY = (targetSprite) ? targetSprite.y : oldUserY
    #---------------------------------------------------------------------------
    # Applies Dynamax effects to sprites.
    #---------------------------------------------------------------------------
    if Settings::SHOW_DYNAMAX_SIZE
      oldUserZoomX   = (userSprite)   ? userSprite.zoom_x   : 1
      oldUserZoomY   = (userSprite)   ? userSprite.zoom_y   : 1
      oldTargetZoomX = (targetSprite) ? targetSprite.zoom_x : 1
      oldTargetZoomY = (targetSprite) ? targetSprite.zoom_y : 1
    end
    #---------------------------------------------------------------------------
    animPlayer = PBAnimationPlayerX.new(animation,user,target,self,oppMove)
    userHeight = (userSprite && userSprite.bitmap && !userSprite.bitmap.disposed?) ? userSprite.bitmap.height : 128
    if targetSprite
      targetHeight = (targetSprite.bitmap && !targetSprite.bitmap.disposed?) ? targetSprite.bitmap.height : 128
    else
      targetHeight = userHeight
    end
    animPlayer.setLineTransform(
      FOCUSUSER_X, FOCUSUSER_Y, FOCUSTARGET_X, FOCUSTARGET_Y,
      oldUserX, oldUserY - (userHeight / 2), oldTargetX, oldTargetY - (targetHeight / 2)
    )
    animPlayer.start
    loop do
      animPlayer.update
      #-------------------------------------------------------------------------
      # Updates Dynamax effects on sprites.
      #-------------------------------------------------------------------------
      if Settings::SHOW_DYNAMAX_SIZE
        userSprite.zoom_x   = oldUserZoomX   if userSprite
        userSprite.zoom_y   = oldUserZoomY   if userSprite
        targetSprite.zoom_x = oldTargetZoomX if targetSprite
        targetSprite.zoom_y = oldTargetZoomY if targetSprite
      end
      #-------------------------------------------------------------------------
      pbUpdate
      break if animPlayer.animDone?
    end
    animPlayer.dispose
    if userSprite
      userSprite.x = oldUserX
      userSprite.y = oldUserY
      userSprite.pbSetOrigin
    end
    if targetSprite
      targetSprite.x = oldTargetX
      targetSprite.y = oldTargetY
      targetSprite.pbSetOrigin
    end
  end
  
  
#===============================================================================
# Fight Menu toggles.
#===============================================================================
  
  #-----------------------------------------------------------------------------
  # Toggles the use of Z-Moves in the Fight Menu.
  #-----------------------------------------------------------------------------
  def pbFightMenu_ZMove(battler, cw)
    battler.power_trigger = !battler.power_trigger
    if battler.power_trigger
      battler.display_power_moves("Z-Move")
      pbPlayBattleButton
    else
      battler.display_base_moves
      pbPlayCancelSE
    end
    pbUpdateMoveInfoWindow(battler, cw.index) if defined?(@moveUIToggle)
    return DXTriggers::MENU_TRIGGER_Z_MOVE, true
  end
  
  #-----------------------------------------------------------------------------
  # Toggles the use of Ultra Burst in the Fight Menu.
  #-----------------------------------------------------------------------------
  def pbFightMenu_UltraBurst(battler, cw)
    battler.power_trigger = !battler.power_trigger
    if battler.power_trigger
      pbPlayBattleButton
    else
      pbPlayCancelSE
    end
    return DXTriggers::MENU_TRIGGER_ULTRA_BURST, false
  end
  
  #-----------------------------------------------------------------------------
  # Toggles the use of Dynamax in the Fight Menu.
  #-----------------------------------------------------------------------------
  def pbFightMenu_Dynamax(battler, cw)
    battler.power_trigger = !battler.power_trigger
    if battler.power_trigger
      battler.display_power_moves("Max Move")
      pbPlayBattleButton
    else
      battler.display_base_moves
      pbPlayCancelSE
    end
    pbUpdateMoveInfoWindow(battler, cw.index) if defined?(@moveUIToggle)
    return DXTriggers::MENU_TRIGGER_DYNAMAX, true
  end
end