#===============================================================================
# Raid Shield animation.
#===============================================================================
class Battle::Scene::Animation::RaidShield < Battle::Scene::Animation
  def initialize(sprites, viewport, battler)
    @index = battler.index
    if battler.effects[PBEffects::MaxRaidBoss]
      @box = sprites["dataBox_#{@index}"]
      @shield_totalhp = battler.effects[PBEffects::MaxShieldHP]
      @shield_hp = battler.effects[PBEffects::RaidShield]
      @shield_bar_name = "Graphics/Plugins/ZUD/Battle/raid_bar"
      @shield_hp_name = "Graphics/Plugins/ZUD/Battle/raid_shield"
    end
    super(sprites, viewport)
  end

  def createProcesses
    return if !@box
    return if ![0, @shield_totalhp].include?(@shield_hp)
    delay = 0
    xpos = (137 - (2 + @shield_totalhp * 26 / 2))
    ypos = 46
    bar = addNewSprite(xpos, ypos, @shield_bar_name)
    bar.setSrcSize(delay, 2 + @shield_totalhp * 26, 12)
    bar.setZ(delay, 999)
    #---------------------------------------------------------------------------
    # Animation for creating shield.
    #---------------------------------------------------------------------------
    if @shield_hp == @shield_totalhp
      pictureHP = []
      for i in 1..@shield_totalhp
        hp = addNewSprite(xpos, ypos, @shield_hp_name)
        hp.setSrcSize(delay, 2 + i * 26, 12)
        hp.setVisible(delay, false)
        hp.setOpacity(delay, 0)
        hp.setZ(delay, 999)
        pictureHP.push(hp)
      end
      pictureHP.each do |p|
        delay += 2
        p.setSE(delay, "Vs sword")
        p.setVisible(delay, true)
        p.moveOpacity(delay, 4, 255)
      end
    #---------------------------------------------------------------------------
    # Animation for breaking shield.
    #---------------------------------------------------------------------------
    else
      t = 0.5
      16.times do |i|
        bar.moveXY(delay, t, xpos + 2, ypos)
        bar.moveXY(delay + t, t, xpos - 2, ypos)
        delay = bar.totalDuration
      end
      bar.moveColor(1, delay, Color.new(255, 255, 255, 150))
      bar.setXY(delay, xpos, ypos)
      bar.setSE(delay + 1, "Anim/Crash")
      bar.moveOpacity(delay, 4, 0)
    end
  end
end

class Battle::Scene
  def pbRaidShield(battler)
    shieldAnim = Animation::RaidShield.new(@sprites, @viewport, battler)
    loop do
      shieldAnim.update
      pbUpdate
      break if shieldAnim.animDone?
    end
    shieldAnim.dispose
  end
end


#===============================================================================
# Wave Attack animation.
#===============================================================================
class Battle::Scene::Animation::WaveAttack < Battle::Scene::Animation
  def initialize(sprites, viewport, idxBattler)
    @index = idxBattler
    super(sprites, viewport)
  end

  def createProcesses
    return if !@sprites["pokemon_#{@index}"]
    delay = 0
    xpos  = @sprites["pokemon_#{@index}"].x
    ypos  = @sprites["pokemon_#{@index}"].y
    zpos  = @sprites["pokemon_#{@index}"].z
    color = @sprites["pokemon_#{@index}"].color
    battler = addSprite(@sprites["pokemon_#{@index}"], PictureOrigin::BOTTOM)
    wave = addNewSprite(xpos, ypos - 60, "Graphics/Plugins/Essentials Deluxe/Animations/pulse", PictureOrigin::CENTER)
    wave.setColor(delay, color)
    wave.setZoom(delay, 0)
    wave.setZ(delay, zpos)
    t = 0.5
    8.times do |i|
      battler.moveXY(delay, t, xpos + 4, ypos)
      battler.moveXY(delay + t, t, xpos - 4, ypos)
      battler.setSE(delay + t, "Anim/fog2") if i == 0
      delay = battler.totalDuration
    end
    wave.moveZoom(delay, 5, 800)
    battler.moveColor(1, delay, Color.new(255, 255, 255, 248))
    battler.setXY(delay, xpos, ypos)
    battler.moveColor(delay, 4, color)
  end
end

class Battle::Scene
  def pbWaveAttack(idxBattler)
    waveAnim = Animation::WaveAttack.new(@sprites, @viewport, idxBattler)
    loop do
      waveAnim.update
      pbUpdate
      break if waveAnim.animDone?
    end
    waveAnim.dispose
  end
end