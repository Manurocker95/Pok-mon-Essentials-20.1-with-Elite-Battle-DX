#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#
#
#  Essentials Exporter by AceOfSpadesProduc100, built from Showdown Exporter v2 for Pokémon Essentials by Cilerba and Marin, rewritten by Nuri Yuri
#
#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#

ESSENTIALS_IV_TO_SHOWDOWN = { HP: 'HP', ATTACK: 'Atk', DEFENSE: 'Def', SPECIAL_ATTACK: 'SpA', SPECIAL_DEFENSE: 'SpD', SPEED: 'Spe' }

def pbShowdown
  party = $player.party.compact.map do |pokemon|
    next {
      name: pokemon.species.name.to_s.downcase,
      level: pokemon.level,
      item: pokemon.hasItem? ? pokemon.item.name : nil,
      ball: pokemon.poke_ball,
      moves: pokemon.moves.compact.reject { |move| move.id == 0 }.map { |move| move.name.to_s },
      form: pokemon.form,
      ability: pokemon.ability.name,
      ability_index: pokemon.ability_index,
      nature: pokemon.nature.id,
      ivs: pokemon.iv.select { |_, v| v < 31 }.transform_keys { |k| ESSENTIALS_IV_TO_SHOWDOWN[k] },
      evs: pokemon.ev.select { |_, v| v >= 0 }.transform_keys { |k| ESSENTIALS_IV_TO_SHOWDOWN[k] },
      happiness: pokemon.happiness,
      nickname: pokemon.name.to_s,
      language: pokemon.owner.language,
      timeReceived: pokemon.timeReceived.to_i,
      shiny: pokemon.shiny?,
      gender: pokemon.gender == 0 ? 'M' : 'F'
    }.compact
  end
  filename = @scene.pbEnterText(_INTL("Name for the team?"), 1, 12)
  Dir.mkdir("Saved teams/") if !Dir.exists?("Saved teams/")
	file = File.new("Saved teams/" + filename + ".json", "w+")
	file.write({ teams: [{ pokemon: party }] }.to_json)
end

def importopponent
	filename = @scene.pbEnterText(_INTL("Name for the opponent team?"),1,12)
	begin
        file = File.read("Saved teams/" + filename + ".json")
		data_hash = JSON.parse(file)
        # Create trainer object
        tr_name = "CPU Player"
        trainer = NPCTrainer.new(tr_name, :CPUPLAYER)
        trainer.id        = $player.make_foreign_ID
        trainer.items     = nil
        trainer.lose_text = ""
        data_hash['teams'][0]['pokemon'].each do |pkmn_data|
            species = GameData::Species.get(pkmn_data['name'].upcase.gsub(/\W/,'')).species
            pkmn = Pokemon.new(species, pkmn_data['level'] ? pkmn_data['level'] : 50, trainer, false)
            plevel = pkmn_data['level'] ? pkmn_data['level'] : 50
            trainer.party.push(pkmn)
            # Set Pokémon's properties if defined
            if pkmn_data['form']
                pkmn.forced_form = pkmn_data['form'] if MultipleForms.hasFunction?(species, "getForm")
                pkmn.form_simple = pkmn_data['form']
            end
            pkmn.item = pkmn_data['item'].upcase.gsub(/\W/,'').to_sym if pkmn_data['item']
            if pkmn_data['moves'] && pkmn_data['moves'].length > 0
                pkmn_data['moves'].each { |move| pkmn.learn_move(move.upcase.gsub(/\W/,'').to_sym) }
            else
                pkmn.reset_moves
            end
            pkmn.ability_index = pkmn_data['ability_index'] if pkmn_data['ability_index']
            pkmn.ability = pkmn_data['ability'] if pkmn_data['ability']
            if pkmn_data['gender'] == "M"
                pkmn.gender = 0
            else
                pkmn.gender = 1
            end
            pkmn.shiny = (pkmn_data['shiny']) ? true : false
            if pkmn_data['nature']
                pkmn.nature = pkmn_data['nature']
            else
                nature = pkmn.species_data.id_number + GameData::TrainerType.get(trainer.trainer_type).id_number
                pkmn.nature = nature % (GameData::Nature::DATA.length / 2)
            end
                if pkmn_data['ivs']
                    pkmn.iv[:HP] = pkmn_data['ivs']['HP'] ? pkmn_data['ivs']['HP'] : pkmn.iv[:HP] = [plevel / 2, Pokemon::IV_STAT_LIMIT].min
                    pkmn.iv[:ATTACK] = pkmn_data['ivs']['Atk'] ? pkmn_data['ivs']['Atk'] : pkmn.iv[:ATTACK] = [plevel / 2, Pokemon::IV_STAT_LIMIT].min
                    pkmn.iv[:DEFENSE] = pkmn_data['ivs']['Def'] ? pkmn_data['ivs']['Def'] : pkmn.iv[:DEFENSE] = [plevel / 2, Pokemon::IV_STAT_LIMIT].min
                    pkmn.iv[:SPECIAL_ATTACK] = pkmn_data['ivs']['SpA'] ? pkmn_data['ivs']['SpA'] : pkmn.iv[:SPECIAL_ATTACK] = [plevel / 2, Pokemon::IV_STAT_LIMIT].min
                    pkmn.iv[:SPECIAL_DEFENSE] = pkmn_data['ivs']['SpD'] ? pkmn_data['ivs']['SpD'] : pkmn.iv[:SPECIAL_DEFENSE] = [plevel / 2, Pokemon::IV_STAT_LIMIT].min
                    pkmn.iv[:SPEED] = pkmn_data['ivs']['Spe'] ? pkmn_data['ivs']['Spe'] : pkmn.iv[:SPEED] = [plevel / 2, Pokemon::IV_STAT_LIMIT].min
                else
                    pkmn.iv[:HP] = [plevel / 2, Pokemon::IV_STAT_LIMIT].min
                    pkmn.iv[:ATTACK] = [plevel / 2, Pokemon::IV_STAT_LIMIT].min
                    pkmn.iv[:DEFENSE] = [plevel / 2, Pokemon::IV_STAT_LIMIT].min
                    pkmn.iv[:SPECIAL_ATTACK] = [plevel / 2, Pokemon::IV_STAT_LIMIT].min
                    pkmn.iv[:SPECIAL_DEFENSE] = [plevel / 2, Pokemon::IV_STAT_LIMIT].min
                    pkmn.iv[:SPEED] = [plevel / 2, Pokemon::IV_STAT_LIMIT].min
                end
                if pkmn_data['evs']
                    pkmn.ev[:HP] = pkmn_data['evs']['HP'] ? pkmn_data['evs']['HP'] : pkmn.ev[:HP] = [plevel * 3 / 2, Pokemon::EV_LIMIT / 6].min
                    pkmn.ev[:ATTACK] = pkmn_data['evs']['Atk'] ? pkmn_data['evs']['Atk'] : pkmn.ev[:ATTACK] = [plevel * 3 / 2, Pokemon::EV_LIMIT / 6].min
                    pkmn.ev[:DEFENSE] = pkmn_data['evs']['Def'] ? pkmn_data['evs']['Def'] : pkmn.ev[:DEFENSE] = [plevel * 3 / 2, Pokemon::EV_LIMIT / 6].min
                    pkmn.ev[:SPECIAL_ATTACK] = pkmn_data['evs']['SpA'] ? pkmn_data['evs']['SpA'] : pkmn.ev[:SPECIAL_ATTACK] = [plevel * 3 / 2, Pokemon::EV_LIMIT / 6].min
                    pkmn.ev[:SPECIAL_DEFENSE] = pkmn_data['evs']['SpD'] ? pkmn_data['evs']['SpD'] : pkmn.ev[:SPECIAL_DEFENSE] = [plevel * 3 / 2, Pokemon::EV_LIMIT / 6].min
                    pkmn.ev[:SPEED] = pkmn_data['evs']['Spe'] ? pkmn_data['evs']['Spe'] : pkmn.ev[:SPEED] = [plevel * 3 / 2, Pokemon::EV_LIMIT / 6].min
                else
                    pkmn.ev[:HP] = [plevel * 3 / 2, Pokemon::EV_LIMIT / 6].min
                    pkmn.ev[:ATTACK] = [plevel * 3 / 2, Pokemon::EV_LIMIT / 6].min
                    pkmn.ev[:DEFENSE] = [plevel * 3 / 2, Pokemon::EV_LIMIT / 6].min
                    pkmn.ev[:SPECIAL_ATTACK] = [plevel * 3 / 2, Pokemon::EV_LIMIT / 6].min
                    pkmn.ev[:SPECIAL_DEFENSE] = [plevel * 3 / 2, Pokemon::EV_LIMIT / 6].min
                    pkmn.ev[:SPEED] = [plevel * 3 / 2, Pokemon::EV_LIMIT / 6].min
                end
            pkmn.happiness = pkmn_data['happiness'] if pkmn_data['happiness']
            pkmn.name = pkmn_data['nickname'] if pkmn_data['nickname'] && !pkmn_data['nickname'].empty?
            pkmn.poke_ball = pkmn_data['ball'] if pkmn_data['ball']
            pkmn.calc_stats
        end
        return trainer
    rescue
		pbMessage(_INTL("An error occurred. Check for JSON-specific errors in a JSON validator, or refer to \"showdowntoessentialsguide.txt\" for team-specific errors."))
	end
end
def pbCPUTrainerBattle(doubleBattle=false, canLose=false, outcomeVar=1)
    begin
        setBattleRule("outcomeVar",outcomeVar) if outcomeVar!=1
        setBattleRule("canLose") if canLose
        setBattleRule("double") if doubleBattle
        $PokemonGlobal.nextBattleBGM = pbListScreen("Battle theme", MusicFileLister.new(true,nil))
        ret = pbOrganizedBattleEx(importopponent,nil,
        "",
        "")
        return ret
    rescue
        pbMessage(_INTL("The battle didn't start, because of an error."))
    end
  end
  
  #=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=
#
#  Showdown JSON Importer for Pokémon Essentials by AceOfSpadesProduc100
#
#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=#=
# Get the JSON library from the folder of the below name
$:.push File.join(Dir.pwd, "Plugins/Ruby Library 3.1.0")
# Import the library
require 'json'
def importteam
	filename = @scene.pbEnterText(_INTL("Name? (Case insensitive)"),1,12)
	begin
		file = File.read("Saved teams/" + filename + ".json")
		data_hash = JSON.parse(file)
		data_hash['teams'][0]['pokemon'].each do |i|
			#.upcase.gsub(/\W/,'').to_sym means to convert into uppercase, include only letters and no spaces, and convert into a Ruby symbol, a variable with a : at the beginning
			p = Pokemon.new(i['name'].upcase.gsub(/\W/,'').to_sym,i['level'] ? i['level'] : 50)
			plevel = i['level'] ? i['level'] : 50
			p.item = i['item'].upcase.gsub(/\W/,'').to_sym if i['item']
			p.poke_ball = i['ball'].upcase.gsub(/\W/,'').to_sym if i['ball']
			if i['moves'] && i['moves'].length > 0
				i['moves'].each do |j|
					p.learn_move(j.upcase.gsub(/\W/,'').to_sym)
				end
			else
				p.reset_moves
			end
			p.form = i['form'] if i['form']
			if i['gender'] == 'M'
				p.makeMale
			else
				p.makeFemale
			end
			p.ability= i['ability'] if i['ability']
			p.ability_index = i['ability_index'] if i['ability_index']
			p.shiny = i['shiny'] if i['shiny']
			p.nature = i['nature'].upcase.gsub(/\W/,'').to_sym if i['nature']
			if i['ivs']
				p.iv[:HP] = i['ivs']['HP'] ? i['ivs']['HP'] : p.iv[:HP] = [plevel / 2, Pokemon::IV_STAT_LIMIT].min
				p.iv[:ATTACK] = i['ivs']['Atk'] ? i['ivs']['Atk'] : p.iv[:ATTACK] = [plevel / 2, Pokemon::IV_STAT_LIMIT].min
				p.iv[:DEFENSE] = i['ivs']['Def'] ? i['ivs']['Def'] : p.iv[:DEFENSE] = [plevel / 2, Pokemon::IV_STAT_LIMIT].min
				p.iv[:SPECIAL_ATTACK] = i['ivs']['SpA'] ? i['ivs']['SpA'] : p.iv[:SPECIAL_ATTACK] = [plevel / 2, Pokemon::IV_STAT_LIMIT].min
				p.iv[:SPECIAL_DEFENSE] = i['ivs']['SpD'] ? i['ivs']['SpD'] : p.iv[:SPECIAL_DEFENSE] = [plevel / 2, Pokemon::IV_STAT_LIMIT].min
				p.iv[:SPEED] = i['ivs']['Spe'] ? i['ivs']['Spe'] : p.iv[:SPEED] = [plevel / 2, Pokemon::IV_STAT_LIMIT].min
			else
				p.iv[:HP] = [plevel / 2, Pokemon::IV_STAT_LIMIT].min
				p.iv[:ATTACK] = [plevel / 2, Pokemon::IV_STAT_LIMIT].min
				p.iv[:DEFENSE] = [plevel / 2, Pokemon::IV_STAT_LIMIT].min
				p.iv[:SPECIAL_ATTACK] = [plevel / 2, Pokemon::IV_STAT_LIMIT].min
				p.iv[:SPECIAL_DEFENSE] = [plevel / 2, Pokemon::IV_STAT_LIMIT].min
				p.iv[:SPEED] = [plevel / 2, Pokemon::IV_STAT_LIMIT].min
			end
			if i['evs']
				p.ev[:HP] = i['evs']['HP'] ? i['evs']['HP'] : p.ev[:HP] = [plevel * 3 / 2, Pokemon::EV_LIMIT / 6].min
				p.ev[:ATTACK] = i['evs']['Atk'] ? i['evs']['Atk'] : p.ev[:ATTACK] = [plevel * 3 / 2, Pokemon::EV_LIMIT / 6].min
				p.ev[:DEFENSE] = i['evs']['Def'] ? i['evs']['Def'] : p.ev[:DEFENSE] = [plevel * 3 / 2, Pokemon::EV_LIMIT / 6].min
				p.ev[:SPECIAL_ATTACK] = i['evs']['SpA'] ? i['evs']['SpA'] : p.ev[:SPECIAL_ATTACK] = [plevel * 3 / 2, Pokemon::EV_LIMIT / 6].min
				p.ev[:SPECIAL_DEFENSE] = i['evs']['SpD'] ? i['evs']['SpD'] : p.ev[:SPECIAL_DEFENSE] = [plevel * 3 / 2, Pokemon::EV_LIMIT / 6].min
				p.ev[:SPEED] = i['evs']['Spe'] ? i['evs']['Spe'] : p.ev[:SPEED] = [plevel * 3 / 2, Pokemon::EV_LIMIT / 6].min
			else
				p.ev[:HP] = [plevel * 3 / 2, Pokemon::EV_LIMIT / 6].min
				p.ev[:ATTACK] = [plevel * 3 / 2, Pokemon::EV_LIMIT / 6].min
				p.ev[:DEFENSE] = [plevel * 3 / 2, Pokemon::EV_LIMIT / 6].min
				p.ev[:SPECIAL_ATTACK] = [plevel * 3 / 2, Pokemon::EV_LIMIT / 6].min
				p.ev[:SPECIAL_DEFENSE] = [plevel * 3 / 2, Pokemon::EV_LIMIT / 6].min
				p.ev[:SPEED] = [plevel * 3 / 2, Pokemon::EV_LIMIT / 6].min
			end
			p.happiness = i['happiness'] if i['happiness']
			p.name = i['nickname'] if i['nickname']
			p.owner.language = i['language'] if i['language']
			p.timeReceived = Time.at(i['timeReceived']) if i['timeReceived']
			p.calc_stats
			(0) rescue nil; pbAddPokemonSilent(p)
		end
		pbMessage(_INTL($player.name + "\\se[] obtained some Pokémon!\\me[Pkmn get]\\wtnp[30]"))
	rescue
		pbMessage(_INTL("An error occurred. Check for JSON-specific errors in a JSON validator, or refer to \"showdowntoessentialsguide.txt\" for team-specific errors.")) 
	end
end

def pbSaveJSON(save_data)
    pbShowdown
    Dir.mkdir("Saves/") if !Dir.exists?("Saves/")
    fileJson = File.new("Saves/save.json", "w+")
    fileJson.write(save_data.to_json)
end  
  