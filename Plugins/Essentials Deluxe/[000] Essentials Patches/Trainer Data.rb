#===============================================================================
# Revamps base Essentials code related to trainers to allow for plugin 
# compatibility.
#===============================================================================


#-------------------------------------------------------------------------------
# Player's birthday data.
#-------------------------------------------------------------------------------
class Player < Trainer
  def birthdate
    return @birthdate || $PokemonGlobal.startTime
  end
  
  def setBirthdate(day, month, year = nil)
    year = Time.now.year - 1 if !year
    @birthdate = Time.new(year, month, day)
  end
  
  def is_anniversary?(date = nil)
    time = pbGetTimeNow
    date = $player.birthdate if !date
    return time.day == date.day && time.mon == date.mon && time.year > date.year
  end
end

def pbSetPlayerBirthday
  months = []
  mon = day = 1
  12.times { |i| months.push(_INTL("{1}", pbGetMonthName(i + 1))) }
  loop do
    mon = pbMessage(_INTL("Which month is your birthday in?"), months) + 1
    maxval = ([4, 6, 9, 11].include?(mon)) ? 30 : (mon == 2) ? 28 : 31
    params = ChooseNumberParams.new
    params.setRange(1, maxval)
    params.setInitialValue(1)
    params.setCancelValue(1)
    day = pbMessageChooseNumber(_INTL("Which day in {1} is your birthday?", pbGetMonthName(mon)), params)
    case day.to_s.last
    when "1" then suffix = (day != 11) ? "st" : "th"
    when "2" then suffix = (day != 12) ? "nd" : "th"
    when "3" then suffix = (day != 13) ? "rd" : "th"
    else          suffix = "th"
    end
    break if pbConfirmMessage(_INTL("So, your birthday is {1} {2}{3}, correct?", pbGetMonthName(mon), day, suffix))
  end
  $player.setBirthdate(day, mon)
end


#-------------------------------------------------------------------------------
# Rewrites Trainer data to consider plugin properties.
#-------------------------------------------------------------------------------
module GameData
  class Trainer
    SCHEMA["Size"]       = [:size,        "u"]
    SCHEMA["Ace"]        = [:trainer_ace, "b"]
    SCHEMA["Memento"]    = [:memento,     "u"] # Placeholder
    SCHEMA["Focus"]      = [:focus,       "u"] # Placeholder
    SCHEMA["Birthsign"]  = [:birthsign,   "u"] # Placeholder
    SCHEMA["DynamaxLvl"] = [:dynamax_lvl, "u"]
    SCHEMA["Gigantamax"] = [:gmaxfactor,  "b"]
    SCHEMA["NoDynamax"]  = [:nodynamax,   "b"]
    SCHEMA["Mastery"]    = [:mastery,     "b"]
    SCHEMA["TeraType"]   = [:teratype,    "u"] # Placeholder
	
    alias dx_to_trainer to_trainer
    def to_trainer
      plugins = [
        "ZUD Mechanics", 
        "PLA Battle Styles", 
        "Terastal Phenomenon", 
        "Focus Meter System", 
        "Pokémon Birthsigns",
        "Improved Mementos"
      ]
      trainer = dx_to_trainer
      trainer.party.each_with_index do |pkmn, i|
        pkmn_data = @pokemon[i]
        pkmn.scale = pkmn_data[:size] if pkmn_data[:size]
        pkmn.ace = (pkmn_data[:trainer_ace]) ? true : false
        plugins.each do |plugin|
          if PluginManager.installed?(plugin)
            case plugin
            when "ZUD Mechanics"
              if pkmn.shadowPokemon? || pkmn_data[:nodynamax]
                pkmn.dynamax_able = false
                pkmn.dynamax_lvl = 0
                pkmn.gmax_factor = false
              else
                pkmn.dynamax_lvl = pkmn_data[:dynamax_lvl]
                pkmn.gmax_factor = (pkmn_data[:gmaxfactor]) ? true : false
              end
            when "PLA Battle Styles"
              if pkmn.shadowPokemon?
                pkmn.moves.each { |m| m.mastered = false }
              else
                pkmn.master_moveset if pkmn_data[:mastery]
              end
            when "Terastal Phenomenon"
              pkmn.tera_type = (pkmn.shadowPokemon?) ? nil : pkmn_data[:teratype]
            when "Focus Meter System"
              pkmn.focus_style = (pkmn.shadowPokemon?) ? :None : (pkmn_data[:focus] || Settings::FOCUS_STYLE_DEFAULT)
            when "Pokémon Birthsigns"
              pkmn.birthsign = (pkmn.shadowPokemon?) ? :VOID : (pkmn_data[:birthsign] || :VOID)
            when "Improved Mementos"
              pkmn.memento = (pkmn.shadowPokemon?) ? nil : pkmn_data[:memento]
            end
          end
        end
        pkmn.calc_stats
      end
      return trainer
    end
  end
end


#-------------------------------------------------------------------------------
# Rewrites in-game Trainer editor to consider plugin properties.
#-------------------------------------------------------------------------------
module TrainerPokemonProperty
  def self.set(settingname, initsetting)
    initsetting = { :species => nil, :level => 10 } if !initsetting
    oldsetting = [
      initsetting[:species],
      initsetting[:level],
      initsetting[:name],
      initsetting[:form],
      initsetting[:gender],
      initsetting[:shininess],
      initsetting[:super_shininess],
      initsetting[:shadowness]
    ]
    Pokemon::MAX_MOVES.times do |i|
      oldsetting.push((initsetting[:moves]) ? initsetting[:moves][i] : nil)
    end
    oldsetting.concat([
      initsetting[:ability],
      initsetting[:ability_index],
      initsetting[:item],
      initsetting[:nature],
      initsetting[:iv],
      initsetting[:ev],
      initsetting[:happiness],
      initsetting[:poke_ball],
      initsetting[:size],
      initsetting[:trainer_ace],
      initsetting[:memento],
      initsetting[:focus],
      initsetting[:birthsign],
      initsetting[:dynamax_lvl], 
      initsetting[:gmaxfactor],
      initsetting[:nodynamax],
      initsetting[:mastery],
      initsetting[:teratype]
    ])
    max_level = GameData::GrowthRate.max_level
    pkmn_properties = [
      [_INTL("Species"),       SpeciesProperty,                         _INTL("Species of the Pokémon.")],
      [_INTL("Level"),         NonzeroLimitProperty.new(max_level),     _INTL("Level of the Pokémon (1-{1}).", max_level)],
      [_INTL("Name"),          StringProperty,                          _INTL("Name of the Pokémon.")],
      [_INTL("Form"),          LimitProperty2.new(999),                 _INTL("Form of the Pokémon.")],
      [_INTL("Gender"),        GenderProperty,                          _INTL("Gender of the Pokémon.")],
      [_INTL("Shiny"),         BooleanProperty2,                        _INTL("If set to true, the Pokémon is a different-colored Pokémon.")],
      [_INTL("SuperShiny"),    BooleanProperty2,                        _INTL("Whether the Pokémon is super shiny (shiny with a special shininess animation).")],
      [_INTL("Shadow"),        BooleanProperty2,                        _INTL("If set to true, the Pokémon is a Shadow Pokémon.")]
    ]
    Pokemon::MAX_MOVES.times do |i|
      pkmn_properties.push([_INTL("Move {1}", i + 1),
                            MovePropertyForSpecies.new(oldsetting), _INTL("A move known by the Pokémon. Leave all moves blank (use Z key to delete) for a wild moveset.")])
    end
    pkmn_properties.concat(
      [[_INTL("Ability"),       AbilityProperty,                         _INTL("Ability of the Pokémon. Overrides the ability index.")],
       [_INTL("Ability index"), LimitProperty2.new(99),                  _INTL("Ability index. 0=first ability, 1=second ability, 2+=hidden ability.")],
       [_INTL("Held item"),     ItemProperty,                            _INTL("Item held by the Pokémon.")],
       [_INTL("Nature"),        GameDataProperty.new(:Nature),           _INTL("Nature of the Pokémon.")],
       [_INTL("IVs"),           IVsProperty.new(Pokemon::IV_STAT_LIMIT), _INTL("Individual values for each of the Pokémon's stats.")],
       [_INTL("EVs"),           EVsProperty.new(Pokemon::EV_STAT_LIMIT), _INTL("Effort values for each of the Pokémon's stats.")],
       [_INTL("Happiness"),     LimitProperty2.new(255),                 _INTL("Happiness of the Pokémon (0-255).")],
       [_INTL("Poké Ball"),     BallProperty.new(oldsetting),            _INTL("The kind of Poké Ball the Pokémon is kept in.")],
       [_INTL("Size"),          LimitProperty2.new(255),                 _INTL("Size variance of the Pokémon (0-255).")],
       [_INTL("Ace"),           BooleanProperty2,                        _INTL("Flags this Pokémon as this trainer's ace. Used by certain plugins below.")]
    ])
    ["Improved Mementos",
     "Focus Meter System",
     "Pokémon Birthsigns",
     "ZUD Mechanics", 
     "PLA Battle Styles", 
     "Terastal Phenomenon"
    ].each do |plugin|
      if PluginManager.installed?(plugin)
        case plugin
        when "Improved Mementos"   then pkmn_properties.push(
          [_INTL("Memento"), GameDataProperty.new(:Ribbon), _INTL("The memento adorned on the Pokémon. This determines its title.")])
        when "Focus Meter System"  then pkmn_properties.push(
          [_INTL("Focus"), GameDataProperty.new(:Focus), _INTL("Focus style of the Pokémon.")])
        when "Pokémon Birthsigns"  then pkmn_properties.push(
          [_INTL("Birthsign"), GameDataProperty.new(:Birthsign), _INTL("Birthsign of the Pokémon.")])
        when "ZUD Mechanics"       then pkmn_properties.push(
          [_INTL("Dynamax Lvl"), LimitProperty2.new(10), _INTL("Dynamax level of the Pokémon (0-10).")],
          [_INTL("G-Max Factor"), BooleanProperty2, _INTL("If set to true, the Pokémon will have G-Max Factor.")],
          [_INTL("No Dynamax"), BooleanProperty2, _INTL("If set to true, the Pokémon will be unable to Dynamax. This allows for other mechanics such as Battle Styles or Terastallization.")])
        when "PLA Battle Styles"   then pkmn_properties.push(
          [_INTL("Mastery"), BooleanProperty2, _INTL("If set to true, the Pokémon's eligible moves will be mastered.")])
        when "Terastal Phenomenon" then pkmn_properties.push(
          [_INTL("Tera Type"), GameDataProperty.new(:Type), _INTL("Tera Type of the Pokémon.")])
        end
      else
        repeat = (plugin == "ZUD Mechanics") ? 3 : 1
        placeholder = [_INTL("Plugin Property"), ReadOnlyProperty, _INTL("This property requires a certain plugin to be installed./n[#{plugin}]")]
        repeat.times { |i| pkmn_properties.push(placeholder) }
      end
    end
    pbPropertyList(settingname, oldsetting, pkmn_properties, false)
    return nil if !oldsetting[0]
    ret = {
      :species         => oldsetting[0],
      :level           => oldsetting[1],
      :name            => oldsetting[2],
      :form            => oldsetting[3],
      :gender          => oldsetting[4],
      :shininess       => oldsetting[5],
      :super_shininess => oldsetting[6],
      :shadowness      => oldsetting[7],
      :ability         => oldsetting[8 + Pokemon::MAX_MOVES],
      :ability_index   => oldsetting[9 + Pokemon::MAX_MOVES],
      :item            => oldsetting[10 + Pokemon::MAX_MOVES],
      :nature          => oldsetting[11 + Pokemon::MAX_MOVES],
      :iv              => oldsetting[12 + Pokemon::MAX_MOVES],
      :ev              => oldsetting[13 + Pokemon::MAX_MOVES],
      :happiness       => oldsetting[14 + Pokemon::MAX_MOVES],
      :poke_ball       => oldsetting[15 + Pokemon::MAX_MOVES],
      :size            => oldsetting[16 + Pokemon::MAX_MOVES],
      :trainer_ace     => oldsetting[17 + Pokemon::MAX_MOVES],
      :memento         => oldsetting[18 + Pokemon::MAX_MOVES],
      :focus           => oldsetting[19 + Pokemon::MAX_MOVES],
      :birthsign       => oldsetting[20 + Pokemon::MAX_MOVES],
      :dynamax_lvl     => oldsetting[21 + Pokemon::MAX_MOVES],
      :gmaxfactor      => oldsetting[22 + Pokemon::MAX_MOVES],
      :nodynamax       => oldsetting[23 + Pokemon::MAX_MOVES],
      :mastery         => oldsetting[24 + Pokemon::MAX_MOVES],
      :teratype        => oldsetting[25 + Pokemon::MAX_MOVES]
    }
    moves = []
    Pokemon::MAX_MOVES.times do |i|
      moves.push(oldsetting[7 + i])
    end
    moves.uniq!
    moves.compact!
    ret[:moves] = moves
    return ret
  end
end