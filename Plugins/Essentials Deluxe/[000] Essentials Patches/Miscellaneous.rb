#===============================================================================
# Revamps miscellaneous bits of Essentials code to allow for plugin compatibility.
#===============================================================================


#-------------------------------------------------------------------------------
# Placeholder message types for plugin compatibility.
#-------------------------------------------------------------------------------
module MessageTypes
  ItemPortionNames       = 100
  ItemPortionNamePlurals = 101
  ItemHeldDescriptions   = 102
  MementoTitles          = 103
  GMaxNames              = 104
  GMaxEntries            = 105
  Birthsigns             = 106 
  ZodiacPowers           = 107
  Celestials             = 108
  BirthsignEffects       = 109
  ZodiacEffects          = 110
  BirthsignLore          = 111
end


#-------------------------------------------------------------------------------
# Placeholder game stat trackers for various plugin features.
#-------------------------------------------------------------------------------
class GameStats
  attr_accessor :primal_reversion_count
  # ZUD Plugin
  attr_accessor :zmove_count, :status_zmove_count, :ultra_burst_count
  attr_accessor :dynamax_count, :gigantamax_count
  attr_accessor :total_dynamax_lvls_gained, :total_gmax_factors_given
  attr_accessor :max_raid_dens_entered, :max_raid_dens_cleared
  attr_accessor :max_lairs_entered, :dark_lairs_entered, :endless_lairs_entered
  attr_accessor :max_lairs_cleared, :endless_lair_records
  # PLA Battle Styles
  attr_accessor :strong_style_count, :agile_style_count, :total_moves_mastered
  # Terastal Phenomenon
  attr_accessor :terastallize_count, :wild_tera_battles, :total_tera_types_changed
  # Focus Meter System
  attr_accessor :accuracy_focus_count, :evasion_focus_count, :critical_focus_count, 
                :potency_focus_count, :passive_focus_count, :enraged_focus_count, :total_focus_styles_changed
  # Pokemon Birthsigns
  attr_accessor :zodiac_power_count, :cooldown_command_count, :total_times_blessed
  # Legendary Breeding
  attr_accessor :legendary_eggs_hatched, :paradox_pokemon_engineered
  
  alias dx_initialize initialize
  def initialize
    dx_initialize
    @primal_reversion_count     = 0
    #------------------------------
    # ZUD Plugin
    @zmove_count                = 0
    @status_zmove_count         = 0
    @ultra_burst_count          = 0
    @dynamax_count              = 0
    @gigantamax_count           = 0
    @total_dynamax_lvls_gained  = 0
    @total_gmax_factors_given   = 0
    @max_raid_dens_entered      = 0
    @max_raid_dens_cleared      = 0
    @max_lairs_entered          = 0
    @dark_lairs_entered         = 0
    @endless_lairs_entered      = 0
    @max_lairs_cleared          = 0
    @endless_lair_records       = 0
    #------------------------------
    # PLA Battle Styles
    @strong_style_count         = 0
    @agile_style_count          = 0
    @total_moves_mastered       = 0
    #------------------------------
    # Terastal Phenomenon
    @terastallize_count         = 0
    @wild_tera_battles          = 0
    @total_tera_types_changed   = 0
    #------------------------------
    # Focus Meter System
    @accuracy_focus_count       = 0
    @evasion_focus_count        = 0
    @critical_focus_count       = 0
    @potency_focus_count        = 0
    @passive_focus_count        = 0
    @enraged_focus_count        = 0
    @total_focus_styles_changed = 0
    #------------------------------
    # Pokemon Birthsigns
    @zodiac_power_count         = 0
    @cooldown_command_count     = 0
    @total_times_blessed        = 0
    #------------------------------
    # Legendary Breeding
    @legendary_eggs_hatched     = 0
    @paradox_pokemon_engineered = 0
  end
end


#-------------------------------------------------------------------------------
# Placeholder item data for plugin compatibility.
#-------------------------------------------------------------------------------
module GameData
  class Item
    SCHEMA["HeldDescription"] = [:real_held_description, "q"]
	
    alias dx_initialize initialize
    def initialize(hash)
      dx_initialize(hash)
      @real_held_description = hash[:real_held_description]
    end
	
    def held_description
      return description if !@real_held_description
      return pbGetMessageFromHash(MessageTypes::ItemHeldDescriptions, @real_held_description)
    end
	
    def portion_name
      return name
    end

    def portion_name_plural
      return name_plural
    end
	
    # New item flags for certain groups of items.
    def is_repel?;        return has_flag?("Repel");           end
    def is_medicine?;     return has_flag?("Medicine");        end
    def is_remedy?;       return has_flag?("Remedy");          end
    def is_vitamin?;      return has_flag?("Vitamin");         end
    def is_exp_candy?;    return has_flag?("ExpCandy");        end
    def is_feather?;      return has_flag?("Feather");         end
    def is_mint?;         return has_flag?("Mint");            end
    def is_incense?;      return has_flag?("Incense");         end
    def is_contest_item?; return has_flag?("Contest");         end
    def is_ev_booster?;   return has_flag?("EVBooster");       end
    def is_flute?;        return has_flag?("Flute");           end
    def is_shard?;        return has_flag?("Shard");           end
    def is_nectar?;       return has_flag?("Nectar");          end
    def is_sweet?;        return has_flag?("Sweet");           end
    def is_plate?;        return has_flag?("Plate");           end
    def is_memory?;       return has_flag?("Memory");          end
    def is_drive?;        return has_flag?("Drive");           end
    def is_fossil_half?;  return has_flag?("FossilHalf");      end
    def is_enhancer?;     return has_flag?("BattleEnhancer");  end
    def is_heal_berry?;   return has_flag?("HealBerry");       end
    def is_status_berry?; return has_flag?("StatusBerry");     end
    def is_flavor_berry?; return has_flag?("FlavorBerry");     end
    def is_ev_berry?;     return has_flag?("EVReduceBerry");   end
    def is_type_berry?;   return has_flag?("TypeReduceBerry"); end
    def is_pinch_berry?;  return has_flag?("PinchBerry");      end
    def is_tera_shard?;   return !@flags.none? { |f| f[/^TeraShard_/i] }; end
  end
end


#-------------------------------------------------------------------------------
# Allows for different colored text in the party menu.
#-------------------------------------------------------------------------------
class Window_CommandPokemonColor < Window_CommandPokemon
  def drawItem(index, _count, rect)
    pbSetSystemFont(self.contents) if @starting
    rect = drawCursor(index, rect)
    base   = self.baseColor
    shadow = self.shadowColor
    #---------------------------------------------------------------------------
    # Blue text.
    #---------------------------------------------------------------------------
    if @colorKey[index] && @colorKey[index] == 1
      base   = Color.new(0, 80, 160)
      shadow = Color.new(128, 192, 240)
    end
    #---------------------------------------------------------------------------
    # Orange text.
    #---------------------------------------------------------------------------
    if @colorKey[index] && @colorKey[index] == 2
      base   = Color.new(236, 88, 0)
      shadow = Color.new(255, 170, 51)
    end
    #---------------------------------------------------------------------------
    # Purple text.
    #---------------------------------------------------------------------------
    if @colorKey[index] && @colorKey[index] == 3
      base   = Color.new(149, 33, 246)
      shadow = Color.new(255, 161, 326)
    end
    #---------------------------------------------------------------------------
    # Gray text.
    #---------------------------------------------------------------------------
    if @colorKey[index] && @colorKey[index] == 4
      base   = Color.new(184, 184, 184)
      shadow = Color.new(96, 96, 96)
    end
    pbDrawShadowText(self.contents, rect.x, rect.y + (self.contents.text_offset_y || 0),
                     rect.width, rect.height, @commands[index], base, shadow)
  end
end


#-------------------------------------------------------------------------------
# Party Screen compatibility.
#-------------------------------------------------------------------------------
class PokemonPartyScreen
  def pbPokemonScreen
    ret = nil
    can_access_storage = false
    if ($player.has_box_link || $bag.has?(:POKEMONBOXLINK)) &&
       !$game_switches[Settings::DISABLE_BOX_LINK_SWITCH] &&
       !$game_map.metadata&.has_flag?("DisableBoxLink")
      can_access_storage = true
    end
    @scene.pbStartScene(@party,
                        (@party.length > 1) ? _INTL("Choose a Pokémon.") : _INTL("Choose Pokémon or cancel."),
                        nil, false, can_access_storage)
    loop do
      @scene.pbSetHelpText((@party.length > 1) ? _INTL("Choose a Pokémon.") : _INTL("Choose Pokémon or cancel."))
      party_idx = @scene.pbChoosePokemon(false, -1, 1)
      break if (party_idx.is_a?(Numeric) && party_idx < 0) || (party_idx.is_a?(Array) && party_idx[1] < 0)
      if party_idx.is_a?(Array) && party_idx[0] == 1
        @scene.pbSetHelpText(_INTL("Move to where?"))
        old_party_idx = party_idx[1]
        party_idx = @scene.pbChoosePokemon(true, -1, 2)
        pbSwitch(old_party_idx, party_idx) if party_idx >= 0 && party_idx != old_party_idx
        next
      end
      pkmn = @party[party_idx]
      command_list = []
      commands = []
      MenuHandlers.each_available(:party_menu, self, @party, party_idx) do |option, hash, name|
        if PluginManager.installed?("Improved Field Skills") && option == :field_skill
          command_list.push([name, 1])
        elsif PluginManager.installed?("Legendary Breeding") && option == :egg_skill
          command_list.push([name, 2])
        elsif PluginManager.installed?("Pokémon Birthsigns") && option.to_s.include?("birthsign_skill")
          if [:birthsign_skill_celestial, :birthsign_skill_creator].include?(option)
            color = BirthsignHandlers::triggerMenuCommandOption(:VOID, pkmn)
            option = :celestial_skill
          else
            color = BirthsignHandlers::triggerMenuCommandOption(pkmn.birthsign.id, pkmn)
            option = :birthsign_skill
          end
          command_list.push([name, color])
        else
          command_list.push(name)
        end
        commands.push([option, hash])
      end
      command_list.push(_INTL("Cancel"))
      if !PluginManager.installed?("Improved Field Skills") && !pkmn.egg?
        insert_index = ($DEBUG) ? 2 : 1
        pkmn.moves.each_with_index do |move, i|
          next if !HiddenMoveHandlers.hasHandler(move.id) &&
                  ![:MILKDRINK, :SOFTBOILED].include?(move.id)
          command_list.insert(insert_index, [move.name, 1])
          commands.insert(insert_index, i)
          insert_index += 1
        end
      end
      choice = @scene.pbShowCommands(_INTL("Do what with {1}?", pkmn.name), command_list)
      next if choice < 0 || choice >= commands.length
      case commands[choice]
      when Array
        if [:field_skill, :birthsign_skill].include?(commands[choice][0])
          ret = commands[choice][1]["effect"].call(self, @party, party_idx)
          break if !ret.nil?
        else
          commands[choice][1]["effect"].call(self, @party, party_idx)
        end
      when Integer
        move = pkmn.moves[commands[choice]]
        if [:MILKDRINK, :SOFTBOILED].include?(move.id)
          amt = [(pkmn.totalhp / 5).floor, 1].max
          if pkmn.hp <= amt
            pbDisplay(_INTL("Not enough HP..."))
            next
          end
          @scene.pbSetHelpText(_INTL("Use on which Pokémon?"))
          old_party_idx = party_idx
          loop do
            @scene.pbPreSelect(old_party_idx)
            party_idx = @scene.pbChoosePokemon(true, party_idx)
            break if party_idx < 0
            newpkmn = @party[party_idx]
            movename = move.name
            if party_idx == old_party_idx
              pbDisplay(_INTL("{1} can't use {2} on itself!", pkmn.name, movename))
            elsif newpkmn.egg?
              pbDisplay(_INTL("{1} can't be used on an Egg!", movename))
            elsif newpkmn.fainted? || newpkmn.hp == newpkmn.totalhp
              pbDisplay(_INTL("{1} can't be used on that Pokémon.", movename))
            else
              pkmn.hp -= amt
              hpgain = pbItemRestoreHP(newpkmn, amt)
              @scene.pbDisplay(_INTL("{1}'s HP was restored by {2} points.", newpkmn.name, hpgain))
              pbRefresh
            end
            break if pkmn.hp <= amt
          end
          @scene.pbSelect(old_party_idx)
          pbRefresh
        elsif pbCanUseHiddenMove?(pkmn, move.id)
          if pbConfirmUseHiddenMove(pkmn, move.id)
            @scene.pbEndScene
            if move.id == :FLY
              scene = PokemonRegionMap_Scene.new(-1, false)
              screen = PokemonRegionMapScreen.new(scene)
              ret = screen.pbStartFlyScreen
              if ret
                $game_temp.fly_destination = ret
                return [pkmn, move.id]
              end
              @scene.pbStartScene(
                @party, (@party.length > 1) ? _INTL("Choose a Pokémon.") : _INTL("Choose Pokémon or cancel.")
              )
              next
            end
            return [pkmn, move.id]
          end
        end
      end
    end
    @scene.pbEndScene
    return ret
  end
end


#-------------------------------------------------------------------------------
# Rewrites Pokemon Storage to show displays added by plugins.
#-------------------------------------------------------------------------------
class PokemonStorageScene
  def pbUpdateOverlay(selection, party = nil)
    overlay = @sprites["overlay"].bitmap
    overlay.clear
    if !@sprites["plugin_overlay"]
      @sprites["plugin_overlay"] = BitmapSprite.new(Graphics.width, Graphics.height, @boxsidesviewport)
      pbSetSystemFont(@sprites["plugin_overlay"].bitmap)
    end
    plugin_overlay = @sprites["plugin_overlay"].bitmap
    plugin_overlay.clear
    buttonbase = Color.new(248, 248, 248)
    buttonshadow = Color.new(80, 80, 80)
    pbDrawTextPositions(
      overlay,
      [[_INTL("Party: {1}", (@storage.party.length rescue 0)), 270, 334, 2, buttonbase, buttonshadow, 1],
       [_INTL("Exit"), 446, 334, 2, buttonbase, buttonshadow, 1]]
    )
    pokemon = nil
    if @screen.pbHeldPokemon
      pokemon = @screen.pbHeldPokemon
    elsif selection >= 0
      pokemon = (party) ? party[selection] : @storage[@storage.currentBox, selection]
    end
    if !pokemon
      @sprites["pokemon"].visible = false
      return
    end
    @sprites["pokemon"].visible = true
    base   = Color.new(88, 88, 80)
    shadow = Color.new(168, 184, 184)
    nonbase   = Color.new(208, 208, 208)
    nonshadow = Color.new(224, 224, 224)
    pokename = pokemon.name
    textstrings = [
      [pokename, 10, 14, false, base, shadow]
    ]
    if !pokemon.egg?
      imagepos = []
      if pokemon.male?
        textstrings.push([_INTL("♂"), 148, 14, false, Color.new(24, 112, 216), Color.new(136, 168, 208)])
      elsif pokemon.female?
        textstrings.push([_INTL("♀"), 148, 14, false, Color.new(248, 56, 32), Color.new(224, 152, 144)])
      end
      imagepos.push(["Graphics/Pictures/Storage/overlay_lv", 6, 246])
      textstrings.push([pokemon.level.to_s, 28, 240, false, base, shadow])
      if pokemon.ability
        textstrings.push([pokemon.ability.name, 86, 312, 2, base, shadow])
      else
        textstrings.push([_INTL("No ability"), 86, 312, 2, nonbase, nonshadow])
      end
      if pokemon.item
        textstrings.push([pokemon.item.name, 86, 348, 2, base, shadow])
      else
        textstrings.push([_INTL("No item"), 86, 348, 2, nonbase, nonshadow])
      end
      if pokemon.shiny?
        pbDrawImagePositions(plugin_overlay, [["Graphics/Pictures/shiny", 134, 16]])
      end
      if PluginManager.installed?("ZUD Mechanics")
        pbDisplayGmaxFactor(pokemon, plugin_overlay, 8, 52)
      end
      if PluginManager.installed?("Terastal Phenomenon") && Settings::STORAGE_TERA_TYPES
        pbDisplayTeraType(pokemon, plugin_overlay, 8, 164)
      end
      if PluginManager.installed?("Pokémon Birthsigns")
        pbDisplayToken(pokemon, plugin_overlay, 149, 167, true)
      end
      if PluginManager.installed?("Enhanced UI")
        pbDisplayShinyLeaf(pokemon, plugin_overlay, 158, 50)      if Settings::STORAGE_SHINY_LEAF
        pbDisplayIVRatings(pokemon, plugin_overlay, 8, 198, true) if Settings::STORAGE_IV_RATINGS
      end
      typebitmap = AnimatedBitmap.new(_INTL("Graphics/Pictures/types"))
      pokemon.types.each_with_index do |type, i|
        type_number = GameData::Type.get(type).icon_position
        type_rect = Rect.new(0, type_number * 28, 64, 28)
        type_x = (pokemon.types.length == 1) ? 52 : 18 + (70 * i)
        overlay.blt(type_x, 272, typebitmap.bitmap, type_rect)
      end
      drawMarkings(overlay, 70, 240, 128, 20, pokemon.markings)
      pbDrawImagePositions(overlay, imagepos)
    end
    pbDrawTextPositions(overlay, textstrings)
    @sprites["pokemon"].setPokemonBitmap(pokemon)
  end
end


#-------------------------------------------------------------------------------
# Placeholder for save file compatibility if ZUD Plugin removed.
#-------------------------------------------------------------------------------
class DynamaxAdventure; end