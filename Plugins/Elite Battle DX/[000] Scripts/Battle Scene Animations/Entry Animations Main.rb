#===============================================================================
#  Main battle animation processing
#===============================================================================
alias pbBattleAnimation_ebdx pbBattleAnimation unless defined?(pbBattleAnimation_ebdx)
def pbBattleAnimation(bgm = nil, battletype = 0, foe = nil)
  $game_temp.in_battle = true
  viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
  viewport.z = 99999
   
  multFPS = 1/Graphics.frame_rate
  multFPS = 0.01 if multFPS <= 0
  # flashes viewport to gray a few times.
   viewport.color = Color.white
   2.times do
     viewport.color.alpha = 0
     for i in 0...16.delta_add
       viewport.color.alpha += (32 * (i < 8.delta_add ? 1 : -1)).delta_sub(false)
       pbWait(multFPS)
     end
   end
   viewport.color.alpha = 0

  # Set up audio
  playingBGS = nil
  playingBGM = nil
  if $game_system.is_a?(Game_System)
    playingBGS = $game_system.getPlayingBGS
    playingBGM = $game_system.getPlayingBGM
    $game_system.bgm_pause
    $game_system.bgs_pause
    if $game_temp.memorized_bgm
      playingBGM = $game_temp.memorized_bgm
      $game_system.bgm_position = $game_temp.memorized_bgm_position
    end
  end
  # Play battle music
  # checks if battle BGM is registered for species or trainer
  mapBGM = EliteBattle.get_map_data(:BGM)
  bgm = mapBGM if !mapBGM.nil?
  pkmnBGM = EliteBattle.next_bgm?(EliteBattle.get(:wildSpecies), EliteBattle.get(:wildForm), 0, :Species)
  bgm = pkmnBGM if !pkmnBGM.nil?
  # gets trainer ID
  trainerid = (foe && foe[0].is_a?(Trainer) ? foe[0].trainer_type : nil) rescue nil
  trBGM = trainerid ? EliteBattle.next_bgm?(trainerid, foe[0].name, foe[0].partyID, :Trainer) : nil
  bgm = trBGM if !trBGM.nil?
  bgm = pbGetWildBattleBGM([]) if !bgm
  pbBGMPlay(bgm)
  # Determine location of battle
  location = 0   # 0=outside, 1=inside, 2=cave, 3=water
  if $PokemonGlobal.surfing || $PokemonGlobal.diving
    location = 3
  elsif $game_temp.encounter_type &&
        GameData::EncounterType.get($game_temp.encounter_type).type == :fishing
    location = 3
  elsif $PokemonEncounters.has_cave_encounters?
    location = 2
  elsif !$game_map.metadata&.outdoor_map
    location = 1
  end
  # Check for custom battle intro animations
  handled = false
  SpecialBattleIntroAnimations.each do |name, priority, condition, animation|
    next if !condition.call(battletype, foe, location)
    animation.call(viewport, battletype, foe, location)
    handled = true
    break
  end
  
if EliteBattle::USE_EBDX_BATTLE_INTROS
  # checks if the Sun & Moon styled VS sequence is to be played
  EliteBattle.sun_moon_transition?(trainerid, false, (foe[0].name rescue 0), (foe[0].partyID rescue 0)) if trainerid && foe && foe.length < 2
  EliteBattle.sun_moon_transition?(EliteBattle.get(:wildSpecies), true, EliteBattle.get(:wildForm)) if !trainerid

  if !handled
    # plays custom transition if applicable
    handled = EliteBattle.play_next_transition(viewport, trainerid) 
    
    # plays basic trainer intro animation
    if !handled && trainerid
      handled = EliteBattle_BasicTrainerAnimations.new(viewport, battletype, foe)
    end

    # plays custom transition
    if !handled
      handled = EliteBattle_BasicWildAnimations.new(viewport)
    end
  end  
end

  # Default battle intro animation
  if !handled
    # Determine which animation is played
    anim = ""
    if PBDayNight.isDay?
      case battletype
      when 0, 2   # Wild, double wild
        anim = ["SnakeSquares", "DiagonalBubbleTL", "DiagonalBubbleBR", "RisingSplash"][location]
      when 1      # Trainer
        anim = ["TwoBallPass", "ThreeBallDown", "BallDown", "WavyThreeBallUp"][location]
      when 3      # Double trainer
        anim = "FourBallBurst"
      end
    else
      case battletype
      when 0, 2   # Wild, double wild
        anim = ["SnakeSquares", "DiagonalBubbleBR", "DiagonalBubbleBR", "RisingSplash"][location]
      when 1      # Trainer
        anim = ["SpinBallSplit", "BallDown", "BallDown", "WavySpinBall"][location]
      when 3      # Double trainer
        anim = "FourBallBurst"
      end
    end
    pbBattleAnimationCore(anim, viewport, location)
  end
  pbPushFade
  # Yield to the battle scene
  yield if block_given?
  # After the battle
  pbPopFade
  if $game_system.is_a?(Game_System)
    $game_system.bgm_resume(playingBGM)
    $game_system.bgs_resume(playingBGS)
  end
  $game_temp.memorized_bgm            = nil
  $game_temp.memorized_bgm_position   = 0
  $PokemonGlobal.nextBattleBGM        = nil
  $PokemonGlobal.nextBattleVictoryBGM = nil
  $PokemonGlobal.nextBattleCaptureME  = nil
  $PokemonGlobal.nextBattleBack       = nil
  $PokemonEncounters.reset_step_count
  # Fade back to the overworld in 0.4 seconds
  viewport.color = Color.black
  timer_start = System.uptime
  loop do
    Graphics.update
    Input.update
    pbUpdateSceneMap
    viewport.color.alpha = 255 * (1 - ((System.uptime - timer_start) / 0.4))
    break if viewport.color.alpha <= 0
  end
  viewport.dispose
  $game_temp.in_battle = false
end

def pbBattleAnimationOriginal(bgm = nil, battletype = 0, foe = nil)
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
  end
  # stops currently playing ME
  pbMEFade(0.25)
  multFPS2 = 8/Graphics.frame_rate
  multFPS2 = 0.01 if multFPS2 <= 0
  pbWait(multFPS2)
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
  multFPS =1/Graphics.frame_rate
  multFPS = 0.01 if multFPS <= 0
  2.times do
    viewport.color.alpha = 0
    for i in 0...16.delta_add
      viewport.color.alpha += (32 * (i < 8.delta_add ? 1 : -1)).delta_sub(false)
      pbWait(multFPS)
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
