#===============================================================================
# Adds battle animations used for deluxe battle speech.
#===============================================================================


#-------------------------------------------------------------------------------
# Animation used to toggle visibility of data boxes.
#-------------------------------------------------------------------------------
class Battle::Scene::Animation::ToggleDataBoxes < Battle::Scene::Animation
  def initialize(sprites, viewport, battlers, toggle)
    @battlers = battlers
    @toggle = toggle
    super(sprites, viewport)
  end

  def createProcesses
    delay = 0
    @battlers.each do |b|
      next if !b || b.fainted? && !@sprites["pokemon_#{b.index}"].visible
      if @sprites["dataBox_#{b.index}"]
        box = addSprite(@sprites["dataBox_#{b.index}"])
        case @toggle
        when false
          box.moveOpacity(delay, 3, 0)
          box.setVisible(delay + 3, false)
        when true
          box.setOpacity(delay, 0)
          box.moveOpacity(delay, 3, 255)
          box.setVisible(delay + 3, true)
        end
      end
    end
  end
end


#-------------------------------------------------------------------------------
# Animation used to toggle black bars during trainer speech.
#-------------------------------------------------------------------------------
class Battle::Scene::Animation::ToggleBlackBars < Battle::Scene::Animation
  def initialize(sprites, viewport, toggle)
    @toggle = toggle
    super(sprites, viewport)
  end

  def createProcesses
    delay = 5
    topBar = addSprite(@sprites["topBar"], PictureOrigin::TOP_LEFT)
    topBar.setZ(0, 200)
    bottomBar = addSprite(@sprites["bottomBar"], PictureOrigin::BOTTOM_RIGHT)
    bottomBar.setZ(0, 200)
    if @toggle
      toMoveBottom = [@sprites["bottomBar"].bitmap.width, Graphics.width].max
      toMoveTop = [@sprites["topBar"].bitmap.width, Graphics.width].max
      topBar.setOpacity(0, 255)
      bottomBar.setOpacity(0, 255)
      topBar.setXY(0, Graphics.width, 0)
      bottomBar.setXY(0, 0, Graphics.height)
      topBar.moveXY(delay, 5, (Graphics.width-toMoveTop), 0)
      bottomBar.moveXY(delay, 5, toMoveBottom, Graphics.height)
    else
      topBar.moveOpacity(delay, 4, 0)
      bottomBar.moveOpacity(delay, 4, 0)
      topBar.setXY(delay + 5, Graphics.width, 0)
      bottomBar.setXY(delay + 5, 0, Graphics.height)
    end
  end
end


#-------------------------------------------------------------------------------
# Animation used to slide a speaker on screen.
#-------------------------------------------------------------------------------
class Battle::Scene::Animation::SlideSpriteAppear < Battle::Scene::Animation
  def initialize(sprites, viewport, id, battle)
    @battle = battle
    case id
    when Integer
      @idxTrainer = id + 1
      trainer = @battle.opponent[id]
      @battle.scene.pbUpdateNameWindow(trainer, false)
    when Symbol, Array
      @battle.scene.pbUpdateGuestSprite(id) if !@battle.scene.guestSpeaker
      @guestSpeaker = true
    end
    super(sprites, viewport)
  end

  def createProcesses
    delay = 0	
    if @idxTrainer && !@sprites["trainer_#{@idxTrainer}"].visible
      slideSprite = addSprite(@sprites["trainer_#{@idxTrainer}"], PictureOrigin::BOTTOM)
      slideSprite.setVisible(delay, true)
      spriteX, spriteY = Battle::Scene.pbTrainerPosition(1)
      spriteX += 64 + (Graphics.width / 4)
    elsif @guestSpeaker && !@battle.scene.guestSpeaker
      slideSprite = addSprite(@sprites["midbattle_guest"], PictureOrigin::BOTTOM)
      slideSprite.setVisible(delay, true)
      spriteX, spriteY = @sprites["midbattle_guest"].x, @sprites["midbattle_guest"].y
      spriteX += @sprites["midbattle_guest"].width / 2 + (Graphics.width / 4)
      @battle.scene.guestSpeaker = true
    end
    if slideSprite
      if @battle.battlers[1] && @battle.battlers[1].dynamax?
        spriteY += 12
        slideSprite.setZ(delay, @sprites["pokemon_1"].z + 1)
      end
      slideSprite.setXY(delay, spriteX, spriteY)
      slideSprite.moveDelta(delay, 8, -Graphics.width / 4, 0)
    end
  end
end


#-------------------------------------------------------------------------------
# Animation used to slide a speaker off screen.
#-------------------------------------------------------------------------------
class Battle::Scene::Animation::SlideSpriteDisappear < Battle::Scene::Animation
  def initialize(sprites, viewport, battle)
    @battle = battle
    super(sprites, viewport)
  end

  def createProcesses
    delay = 0
    sprites_to_hide = 1
    sprites_to_hide += @battle.opponent.length if @battle.opponent
    sprites_to_hide.times do |i|
      if @sprites["trainer_#{i}"] && @sprites["trainer_#{i}"].visible
        slideSprite = addSprite(@sprites["trainer_#{i}"], PictureOrigin::BOTTOM)
      elsif @battle.scene.guestSpeaker
        slideSprite = addSprite(@sprites["midbattle_guest"], PictureOrigin::BOTTOM)
        @battle.scene.guestSpeaker = false
      end
      if slideSprite
        slideSprite.moveDelta(delay, 8, Graphics.width / 4, 0)
        slideSprite.setVisible(delay + 8, false)
        if @battle.battlers[1] && @battle.battlers[1].dynamax?
          slideSprite.setZ(delay + 8, @sprites["pokemon_1"].z - 1)
        end
      end
    end
  end
end


#-------------------------------------------------------------------------------
# Animation used for a fleeing battler.
#-------------------------------------------------------------------------------
class Battle::Scene::Animation::BattlerFlee < Battle::Scene::Animation
  def initialize(sprites, viewport, idxBattler, battle)
    @idxBattler = idxBattler
    @battle     = battle
    super(sprites, viewport)
  end

  def createProcesses
    delay = 0
    batSprite = @sprites["pokemon_#{@idxBattler}"]
    shaSprite = @sprites["shadow_#{@idxBattler}"]
    battler = addSprite(batSprite, PictureOrigin::BOTTOM)
    shadow  = addSprite(shaSprite, PictureOrigin::CENTER)
    direction = (@battle.battlers[@idxBattler].opposes?(0)) ? batSprite.x : -batSprite.x    
    shadow.setVisible(delay, false)
    battler.setSE(delay, "Battle flee")
    battler.moveOpacity(delay, 8, 0)
    battler.moveDelta(delay, 28, direction, 0)
    battler.setVisible(delay + 28, false)
  end
end


#-------------------------------------------------------------------------------
# Battle scene additions for midbattle speech.
#-------------------------------------------------------------------------------
class Battle::Scene
  attr_accessor :guestSpeaker
  
  def pbMidbattleInit
    nameWindow = Window_AdvancedTextPokemon.new
    nameWindow.baseColor      = MESSAGE_BASE_COLOR
    nameWindow.shadowColor    = MESSAGE_SHADOW_COLOR
    nameWindow.viewport       = @viewport
    nameWindow.letterbyletter = false
    nameWindow.visible        = false
    nameWindow.x              = 16
    nameWindow.y              = Graphics.height - 158
    nameWindow.z              = 200
    @sprites["nameWindow"]    = nameWindow
    defaultFile = GameData::TrainerType.front_sprite_filename($player.trainer_type)
    spriteX, spriteY = Battle::Scene.pbTrainerPosition(1)
    sprite = pbAddSprite("midbattle_guest", spriteX, spriteY, defaultFile, @viewport)
    return if !sprite.bitmap
    sprite.z = 7
    sprite.ox = sprite.src_rect.width / 2
    sprite.oy = sprite.bitmap.height
    sprite.visible = false
  end
  
  def pbUpdateGuestSprite(id)
    sym  = (id.is_a?(Array)) ? id[0] : id
    spriteX, spriteY = Battle::Scene.pbTrainerPosition(1)
    if GameData::Species.exists?(sym)
      speaker = Pokemon.new(sym, 1)
      if id.is_a?(Array)
        speaker.gender      = id[1] || 0
        speaker.form        = id[2] || 0
        speaker.shiny       = id[3] || false
        speaker.makeShadow if id[4]
      elsif !speaker.singleGendered?
        speaker.gender = 0
      end
      @sprites["midbattle_guest"] = PokemonSprite.new(viewport)
      sprite = @sprites["midbattle_guest"]
      sprite.setPokemonBitmap(speaker)
      sprite.setOffset(PictureOrigin::BOTTOM)
      sprite.x = spriteX
      sprite.y = spriteY
      sprite.ox = sprite.src_rect.width / 2
      sprite.oy = sprite.bitmap.height
      speaker.species_data.apply_metrics_to_sprite(sprite, 1)
    elsif GameData::TrainerType.exists?(sym)
      speaker = GameData::TrainerType.get(sym)
      @sprites["midbattle_guest"] = IconSprite.new(spriteX, spriteY, viewport)
      sprite = @sprites["midbattle_guest"]
      sprite.setBitmap("Graphics/Trainers/" + sym.to_s)
      sprite.ox = sprite.src_rect.width / 2
      sprite.oy = sprite.bitmap.height
    end
    sprite.z = 7
    sprite.visible = false
    @namePanelName = speaker.name if !@namePanelName
    @namePanelSkin = speaker.gender if !@namePanelSkin
    pbUpdateNameWindow(speaker, false)
  end
  
  def pbUpdateNameWindow(speaker = "", visible = true, reset = false)
    if reset
      @namePanelName = nil
      @namePanelSkin = nil
    end
    case speaker
    when String, nil
      newName = @namePanelName || ""
      newSkin = @namePanelSkin
    else
      newName = @namePanelName || speaker.name
      newSkin = @namePanelSkin || speaker.gender
    end
    if !newSkin.is_a?(String) || nil_or_empty?(newSkin)
      case newSkin
      when 0 then newSkin = Settings::MENU_WINDOWSKINS[4]
      when 1 then newSkin = Settings::MENU_WINDOWSKINS[2]
      else        newSkin = Settings::MENU_WINDOWSKINS[0]
      end
    end
    @sprites["nameWindow"].text = newName
    @sprites["nameWindow"].resizeToFit(newName)
    @sprites["nameWindow"].setSkin("Graphics/Windowskins/" + newSkin)
    @sprites["nameWindow"].visible = (nil_or_empty?(newName) || !visible) ? false : true
  end

  def pbShowSlideSprite(id)
    appearAnim = Animation::SlideSpriteAppear.new(@sprites, @viewport, id, @battle)
    @animations.push(appearAnim)
    while inPartyAnimation?
      pbUpdate
    end
  end

  def pbHideSlideSprite
    hideAnim = Animation::SlideSpriteDisappear.new(@sprites, @viewport, @battle)
    @animations.push(hideAnim)
    while inPartyAnimation?
      pbUpdate
    end
  end
  
  def pbToggleDataboxes(toggle = false)
    dataBoxAnim = Animation::ToggleDataBoxes.new(@sprites, @viewport, @battle.battlers, toggle)
    loop do
      dataBoxAnim.update
      pbUpdate
      break if dataBoxAnim.animDone?
    end
    dataBoxAnim.dispose
  end
  
  def pbToggleBlackBars(toggle = false)
    pbAddSprite("topBar", Graphics.width, 0, "Graphics/Plugins/Essentials Deluxe/Animations/blackbar_top", @viewport) if !@sprites["topBar"]
    pbAddSprite("bottomBar", 0, Graphics.height, "Graphics/Plugins/Essentials Deluxe/Animations/blackbar_bottom", @viewport) if !@sprites["bottomBar"]
    blackBarAnim = Animation::ToggleBlackBars.new(@sprites, @viewport, toggle)
    loop do
      blackBarAnim.update
      pbUpdate
      break if blackBarAnim.animDone?
    end
    blackBarAnim.dispose
    @sprites["messageWindow"].text = ""
    if toggle
      @sprites["messageWindow"].baseColor = MessageConfig::LIGHT_TEXT_MAIN_COLOR
      @sprites["messageWindow"].shadowColor = MessageConfig::LIGHT_TEXT_SHADOW_COLOR
      @sprites["messageWindow"].z += 1
    else
      colors = getDefaultTextColors(@sprites["messageWindow"].windowskin)
      @sprites["messageWindow"].baseColor = colors[0]
      @sprites["messageWindow"].shadowColor = colors[1]
      @sprites["messageWindow"].z -= 1
    end
  end
  
  def pbBattlerFlee(battler, msg = nil)
    @briefMessage = false
    fleeAnim = Animation::BattlerFlee.new(@sprites, @viewport, battler.index, @battle)
    dataBoxAnim = Animation::DataBoxDisappear.new(@sprites, @viewport, battler.index)
    loop do
      fleeAnim.update
      dataBoxAnim.update
      pbUpdate
      break if fleeAnim.animDone? && dataBoxAnim.animDone?
    end
    fleeAnim.dispose
    dataBoxAnim.dispose
    if msg.is_a?(String)
      @battle.pbDisplayPaused(_INTL("#{msg}", battler.pbThis))
    else
      @battle.pbDisplayPaused(_INTL("{1} fled!", battler.pbThis))
    end
  end
  
  def pbFlashRefresh
    tone = 0
    toneDiff = 20 * 20 / Graphics.frame_rate
    loop do
      Graphics.update
      pbUpdate
      tone += toneDiff
      @viewport.tone.set(tone, tone, tone, 0)
      break if tone >= 255
    end
    pbRefreshEverything
    (Graphics.frame_rate / 4).times do
      Graphics.update
      pbUpdate
    end
    tone = 255
    toneDiff = 40 * 20 / Graphics.frame_rate
    loop do
      Graphics.update
      pbUpdate
      tone -= toneDiff
      @viewport.tone.set(tone, tone, tone, 0)
      break if tone <= 0
    end
  end
end