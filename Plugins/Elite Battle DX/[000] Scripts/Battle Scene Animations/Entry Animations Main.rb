#===============================================================================
#  Main battle animation processing
#===============================================================================
def pbBattleAnimation(bgm = nil, battletype = 0, foe = nil)
  # gets trainer ID
  trainerid = (foe && foe[0].is_a?(Trainer) ? foe[0].trainer_type : nil) rescue nil
  # sets up starting variables
  handled = false
  playingBGS = nil
  playingBGM = nil
  # memorizes currently playing BGM and BGS
 if $game_system && $game_system.is_a?(Game_System)
    playingBGS = $game_system.getPlayingBGS
    playingBGM = $game_system.getPlayingBGM
    $game_system.bgm_pause
    $game_system.bgs_pause
    if $game_temp.memorized_bgm
      playingBGM = $game_temp.memorized_bgm
      $game_system.bgm_position = $game_temp.memorized_bgm_position
    end
  end
  # stops currently playing ME
  pbMEFade(0.25)
  pbWait(8)
  pbMEStop
  # checks if battle BGM is registered for species or trainer
  mapBGM = EliteBattle.get_map_data(:BGM)
  bgm = mapBGM if !mapBGM.nil?
  pkmnBGM = EliteBattle.next_bgm?(EliteBattle.get(:wildSpecies), EliteBattle.get(:wildForm), 0, :Species)
  bgm = pkmnBGM if !pkmnBGM.nil? && !trainerid
  trBGM = trainerid ? EliteBattle.next_bgm?(trainerid, foe[0].name, foe[0].partyID, :Trainer) : nil
  bgm = trBGM if !trBGM.nil?
  # plays battle BGM
  if bgm
    pbBGMPlay(bgm)
  else
    pbBGMPlay(pbGetWildBattleBGM(0))
  end
  # initialize viewport
  viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
  viewport.z = 99999
  # flashes viewport to gray a few times.
  viewport.color = Color.white
  2.times do
    viewport.color.alpha = 0
    for i in 0...16.delta_add
      viewport.color.alpha += (32 * (i < 8.delta_add ? 1 : -1)).delta_sub(false)
      pbWait(1)
    end
  end
  viewport.color.alpha = 0
  # checks if the Sun & Moon styled VS sequence is to be played
  EliteBattle.sun_moon_transition?(trainerid, false, (foe[0].name rescue 0), (foe[0].partyID rescue 0)) if trainerid && foe && foe.length < 2
  EliteBattle.sun_moon_transition?(EliteBattle.get(:wildSpecies), true, EliteBattle.get(:wildForm)) if !trainerid
  $timenow = Time.now
  # plays custom transition if applicable
  handled = EliteBattle.play_next_transition(viewport, trainerid)
  # plays basic trainer intro animation
  if !handled && trainerid
    handled = EliteBattle_BasicTrainerAnimations.new(viewport, battletype, foe)
  end
  if !handled
    handled = EliteBattle_BasicWildAnimations.new(viewport)
  end
  # battle processing
  yield if block_given?
  # resumes memorized BGM and BGS
  if $game_system && $game_system.is_a?(Game_System)
    $game_system.bgm_resume(playingBGM)
    $game_system.bgs_resume(playingBGS)
  end
  # resets cache variables
  $game_temp.memorized_bgm            = nil
  $game_temp.memorized_bgm_position   = 0
  $PokemonGlobal.nextBattleBGM       = nil
  $PokemonGlobal.nextBattleCaptureME = nil
  $PokemonGlobal.nextBattleBack      = nil
  $PokemonGlobal.nextBattleVictoryBGM      = nil
  $PokemonEncounters.reset_step_count
  # fades in viewport
  viewport.color = Color.new(0, 0, 0)
  for j in 0...16
    viewport.color.alpha -= 32.delta_sub(false)
    Graphics.update
    Input.update
    pbUpdateSceneMap
  end
  viewport.color.alpha = 0
  viewport.dispose
  $game_temp.in_battle = false
end

def pbTestBossBattle3
  EliteBattle.assign_bgm("Battle victory leader.ogg", :DIALGA)
  EliteBattle.bossBattle(:DIALGA, 15, 2, false, {
    :iv => { :HP => 31, :ATTACK => 31, :DEFENSE => 31, :SPECIAL_ATTACK => 31, :SPECIAL_DEFENSE =>31, :SPEED =>31 },
    :bossboost => { :HP => 2.00, :ATTACK => 1.25, :DEFENSE => 1.50, :SPECIAL_ATTACK => 1.50, :SPECIAL_DEFENSE => 2.00, :SPEED => 1.25 },
    :moves => [ :FLAMETHROWER, :ROAROFTIME, :SNARL, :TACKLE ]
  })
end