#===============================================================================
# Additions to Battle::Scene::PokemonDataBox.
#===============================================================================
class Battle::Scene::PokemonDataBox < SpriteWrapper
  #-----------------------------------------------------------------------------
  # Aliased for including bitmaps for raid graphics.
  #-----------------------------------------------------------------------------
  alias zud_initializeOtherGraphics initializeOtherGraphics
  def initializeOtherGraphics(viewport)
    path = "Graphics/Plugins/ZUD/Battle/"
    @raidNumbersBitmap = AnimatedBitmap.new(path + "raid_num")
    @raidBarBitmap     = AnimatedBitmap.new(path + "raid_bar")
    @shieldHPBitmap    = AnimatedBitmap.new(path + "raid_shield")
    zud_initializeOtherGraphics(viewport)
    if @battler.effects[PBEffects::MaxRaidBoss] 
      @hpBarBitmap = AnimatedBitmap.new(path + "overlay_hp")
      @hpBar = Sprite.new(viewport)
      @hpBar.bitmap = @hpBarBitmap.bitmap
      @hpBar.src_rect.height = @hpBarBitmap.height / 3
      @sprites["hpBar"] = @hpBar
      @sprites["hpBar"].z = @sprites["hpNumbers"].z + 1
      @sprites["hpBar"].visible = false
    end
  end
  
  alias zud_dispose dispose
  def dispose
    @raidBarBitmap.dispose
    @shieldHPBitmap.dispose
    @raidNumbersBitmap.dispose
    zud_dispose
  end
  
  #-----------------------------------------------------------------------------
  # Aliased so level and gender do not display on Max Raid Pokemon (as in SwSh).
  #-----------------------------------------------------------------------------
  alias zud_draw_level draw_level
  def draw_level
    return if @battler.effects[PBEffects::MaxRaidBoss]
    zud_draw_level
  end
  
  alias zud_draw_gender draw_gender
  def draw_gender
    return if @battler.effects[PBEffects::MaxRaidBoss]
    zud_draw_gender
  end
  
  #-----------------------------------------------------------------------------
  # Aliased so Max Raid Pokemon names are outlined in red (blue for Calyrex).
  #-----------------------------------------------------------------------------
  alias zud_draw_name draw_name
  def draw_name
    if @battler.effects[PBEffects::MaxRaidBoss]
      name_base   = Color.new(248, 248, 248)
      name_shadow = (@battler.isSpecies?(:CALYREX)) ? Color.new(48, 206, 216) : Color.new(248, 32, 32)
      pbDrawTextPositions(self.bitmap, [[@battler.name, 26, 6, false, name_base, name_shadow]])
    else
      zud_draw_name
    end
  end
  
  #-----------------------------------------------------------------------------
  # Aliased for status icon coordinates on Max Raid Pokemon databoxes.
  #-----------------------------------------------------------------------------
  alias zud_draw_status draw_status
  def draw_status
    if @battler.effects[PBEffects::MaxRaidBoss]
      return if @battler.status == :NONE
      if @battler.status == :POISON && @battler.statusCount > 0
        s = GameData::Status.count - 1
      else
        s = GameData::Status.get(@battler.status).icon_position
      end
      return if s < 0
      pbDrawImagePositions(self.bitmap, [["Graphics/Pictures/Battle/icon_statuses", 155, 12,
                                        0, s * STATUS_ICON_HEIGHT, -1, STATUS_ICON_HEIGHT]])
    else
      zud_draw_status
    end
  end
  
  #-----------------------------------------------------------------------------
  # Aliased to use better shiny and owned icons for Max Raid Pokemon.
  #-----------------------------------------------------------------------------
  alias zud_draw_shiny_icon draw_shiny_icon
  def draw_shiny_icon
    if @battler.effects[PBEffects::MaxRaidBoss]
      return if !@battler.shiny?
      pbDrawImagePositions(self.bitmap, [["Graphics/Plugins/ZUD/Battle/shiny", 0, 30]])
    else
      zud_draw_shiny_icon
    end
  end
  
  alias zud_draw_owned_icon draw_owned_icon
  def draw_owned_icon
    if @battler.effects[PBEffects::MaxRaidBoss]
      return if !@battler.owned? || !@battler.opposes?(0)
      pbDrawImagePositions(self.bitmap, [["Graphics/Plugins/ZUD/Battle/icon_own", 8, 12]])
    else
      zud_draw_owned_icon
    end
  end
  
  #-----------------------------------------------------------------------------
  # Aliased to allow Ultra Burst and Dynamax icons to display.
  #-----------------------------------------------------------------------------
  alias zud_draw_special_form_icon draw_special_form_icon
  def draw_special_form_icon
    return if @battler.effects[PBEffects::MaxRaidBoss]
    specialX = (@battler.opposes?(0)) ? 208 : -28
    if @battler.ultra?
      pbDrawImagePositions(self.bitmap, [["Graphics/Plugins/ZUD/Battle/icon_ultra", @spriteBaseX + specialX, 4]])
    elsif @battler.dynamax?
      pbDrawImagePositions(self.bitmap, [["Graphics/Plugins/ZUD/Battle/icon_dynamax", @spriteBaseX + specialX, 4]])
    else
      zud_draw_special_form_icon
    end
  end
  
  #-----------------------------------------------------------------------------
  # Draws the turn count and KO count numbers on a raid databox.
  #-----------------------------------------------------------------------------
  def raid_DrawNumbers(counter, number, btmp, startX, startY)
    color = 0
    case counter
    when 0
      color = 1 if number <= Settings::MAXRAID_TIMER / 2
      color = 2 if number <= Settings::MAXRAID_TIMER / 4
      color = 3 if number <= Settings::MAXRAID_TIMER / 8
    when 1
      color = 1 if number <= Settings::MAXRAID_KOS / 2
      color = 2 if number <= Settings::MAXRAID_KOS / 4
      color = 3 if number <= 1
    end
    n = (number == -1) ? 10 : number.to_i.digits.reverse
    charWidth  = @raidNumbersBitmap.width / 11
    charHeight = @raidNumbersBitmap.height / 4
    startX -= charWidth * n.length
    n.each do |i|
      numberRect = Rect.new(i * charWidth, color * 14, charWidth, charHeight)
      btmp.blt(startX, startY, @raidNumbersBitmap.bitmap, numberRect)
      startX += charWidth
    end
  end
  
  #-----------------------------------------------------------------------------
  # Draws the Timer and KO counters on a Max Raid databox.
  #-----------------------------------------------------------------------------
  def draw_raid_counters
    turncount = @battler.effects[PBEffects::Dynamax]
    kocount   = @battler.effects[PBEffects::KnockOutCount]
    kocount   = 0 if kocount < 0
    raid_DrawNumbers(0, turncount, self.bitmap, 231, 14)
    raid_DrawNumbers(1, kocount, self.bitmap, 260, 14)
  end
  
  #-----------------------------------------------------------------------------
  # Draws raid shields on a Max Raid databox.
  #-----------------------------------------------------------------------------
  def draw_raid_shield
    shieldHP = @battler.effects[PBEffects::RaidShield]
    if shieldHP > 0
	  shieldLvl = @battler.effects[PBEffects::MaxShieldHP]
	  offset = (137 - (2 + shieldLvl * 26 / 2))
      self.bitmap.blt(offset, 46, @raidBarBitmap.bitmap, Rect.new(0, 0, 2 + shieldLvl * 26, 12))
	  self.bitmap.blt(offset, 46, @shieldHPBitmap.bitmap, Rect.new(0, 0, 2 + shieldHP * 26, 12))
    end
  end
end