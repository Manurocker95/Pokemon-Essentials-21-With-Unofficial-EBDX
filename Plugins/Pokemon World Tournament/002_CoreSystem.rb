#===============================================================================
#  Pokemon World Tournament
#    by Luka S.J.
#    Updated by Vendily and DerxwnaKapsyla
# 
#  A new (and more advanced) of my previous Pokemon World Tournament script.
#  This system is a little more sophisticated, hence more complex to use and
#  implement. Comes with a whole load of goodies like a visual battle field,
#  customizable tournaments, and Trainer Lobby. Please make sure to carefully
#  read the instructions and information on my site before using/implementing
#  this new system.
#
#  Enjoy the script, and make sure to give credit!
#  (DO NOT ALTER THE NAMES OF THE INDIVIDUAL SCRIPT SECTIONS OR YOU WILL BREAK
#   YOUR SYSTEM!)
#===============================================================================                           
#New and Changed Features with the port:
#- Now tracks the stats of Losses and Win Streaks
#- Will award BP based on a Win Streak
#- Now plays unique music in Round 3 and tournament victory
#  music.
#- Overhauled the Tournament definition structure
#  * Also allows for setting unique BP, rules, unlock conditions,
#    and banlist messages on a tournament by tournament basis.
#- Includes a graphic (from default Essentials) to serve as a
#  "placeholder" battle background.
#
#Removed Features with the port:
#- World Leaders has been removed as an individual bracket.
#===============================================================================                           
#  Pokemon World Tournament (settings)
#===============================================================================                           
# Moved to its own dedicated script section.
#===============================================================================               
# Main PWT architecture
#-------------------------------------------------------------------------------
class AdvancedWorldTournament
  attr_reader :internal
  attr_reader :battle_type
  attr_accessor :outcome
  attr_accessor :beat
  attr_accessor :inbattle
  attr_reader :challenge_rules
  
# List containing all possible tournament branches
# Format per tournament is as following:
#
# "name of tournaments","condition == true"
# trainer_entry[trainertype,trainername,endspeech_lose,endspeech_win,trainer variable,lobby text (optional), text before battle (optional), text after battle (optional)]
# 
# At least 8 entry arrays need to be defined per tournament name and condition
# to make the tournament valid. A tournament with less than 8 trainers to fight,
# will not show up on your tournament selection list.
  
  # Starts the PWT process
  def initialize(viewport)
    @viewport = viewport
    @outcome = 1
    @inbattle = false
    @beat = []
    @challenge_rules = nil
    # Turns on the PWT
    @internal = true
    # Configures the win entries of the PWT
    $stats.pwt_wins = {} if $stats.pwt_wins.nil? || $stats.pwt_wins.is_a?(Array)
    GameData::PWTTournament.each do |t|
      $stats.pwt_wins[t.id] = 0 if $stats.pwt_wins[t.id].nil?
	end
	# Configures the loss entries of the PWT
    $stats.pwt_loss = {} if $stats.pwt_loss.nil? || $stats.pwt_loss.is_a?(Array)
    GameData::PWTTournament.each do |t|
      $stats.pwt_loss[t.id] = 0 if $stats.pwt_loss[t.id].nil?
    end
	# Configures the win streak of the PWT
    $stats.pwt_win_streak = {} if $stats.pwt_win_streak.nil? || $stats.pwt_win_streak.is_a?(Array)
    GameData::PWTTournament.each do |t|
      $stats.pwt_win_streak[t.id] = 0 if $stats.pwt_win_streak[t.id].nil?
    end
    # Playes the introductory dialogue
    self.introduction
    pbMapInterpreter.command_end if pbMapInterpreterRunning?
    scene = PokemonSave_Scene.new
    screen = PokemonSaveScreen.new(scene)
    return self.cancelEntry if !screen.pbSaveScreen
    # Chooses tournament
    @tournament_id = self.chooseTournament
    return self.notAvailable if @tournament_id.nil?
    return self.cancelEntry if !@tournament_id
    # Chooses battle type
    @battle_type = self.chooseBattle
    return cancelEntry if !@battle_type
    @challenge_rules = GameData::PWTTournament.get(@tournament_id).call_rules([3,4,6,1][@battle_type])
    if @battle_type == 1 # doublebattle
      @challenge_rules.addBattleRule(DoubleBattle.new)
    else
      @challenge_rules.addBattleRule(SingleBattle.new)
    end
    # Chooses new party
    @modified_party = self.choosePokemon
    # Generates the scoreboard
    if @modified_party == "notEligible"
      pbMessage(_INTL("We're terribly sorry, but your Pokémon are not eligible for the Tournament.\\1"))
      GameData::PWTTournament.get(@tournament_id).call_ban_reason
      pbMessage(_INTL("Please come back once your Pokémon Party has been adjusted.\\1"))
    elsif !@modified_party
      cancelEntry
    else
      # Starts tournament branch
      self.transferPlayer(*PWTSettings::PWT_MAP_DATA)
    end
  end
  
  def streak_multiplier
	mult = 1
	if $stats.pwt_win_streak[@tournament_id] >= 50
	  mult = 10
	elsif $stats.pwt_win_streak[@tournament_id] >= 25
	  mult = 5
	elsif $stats.pwt_win_streak[@tournament_id] >= 10
	  mult = 3
	elsif $stats.pwt_win_streak[@tournament_id] >= 5
	  mult = 2
	else
	  mult = 1
	end
	return mult
  end
  
  def continue
    @oldParty = $player.party
    $player.party = @modified_party
    # Continues the tournament branch
    self.generateRounds(@tournament_id)
    ret = self.startTournament
    # Handles the tournament end and outcome
    self.endFanfare if ret == "win"
    @current_location.push(true)
    self.transferPlayer(*@current_location)
    case ret
    when "win"
	  total_points = GameData::PWTTournament.get(@tournament_id).points_won
	  pbMessage(_INTL("Congratulations on today's win.\\1"))
	  if PWTSettings::PWT_STREAK_MULT && $stats.pwt_win_streak[@tournament_id] >= 5
	    total_points = total_points * streak_multiplier
		pbMessage(_INTL("Accounting for your current win streak, you have earned {1} BP.\\1",total_points))
		pbMessage(_INTL("\\pn was awarded {1} Battle Points!\\me[BP Fanfare]\\wtnp[80]",total_points))
	  else
		pbMessage(_INTL("For your victory you have earned {1} BP.\\1",total_points))
		pbMessage(_INTL("\\pn was awarded {1} Battle Points!\\me[BP Fanfare]\\wtnp[80]",total_points))
	  end
      pbMessage(_INTL("We hope to see you again."))
      $stats.pwt_wins[@tournament_id] += 1
      $player.battle_points += total_points
	  $stats.pwt_win_streak[@tournament_id] += 1
      self.endTournament
    when "loss"
      pbMessage(_INTL("I'm sorry that you lost this tournament.\\1"))
      pbMessage(_INTL("Maybe you'll have better luck next time."))
	  $stats.pwt_loss[@tournament_id] += 1
	  $stats.pwt_win_streak[@tournament_id] = 0
      self.cancelEntry
    end
    $player.party = @oldParty
  end
  
  # Ends the whole PWT process
  def endTournament
    $player.party = @oldParty if @oldParty
    @challenge_rules = nil
    self.disposeScoreboard
    @internal = false
    $PWT = nil
  end
  
  # Generates a list of trainers for a selected tournament
  def generateFromList(selected)
    list = GameData::PWTTournament.get(selected).trainers.clone
    return list.length < 8 ? nil : list
  end
  
  # Generates a list of choices based on available tournaments
  def chooseTournament
    commands  = []
    tourn_ids = []
    GameData::PWTTournament.each do |t|
      next unless t.call_condition
      commands.push(t.name)
      tourn_ids.push(t.id)
    end
    return nil if commands.length < 1
    commands.push("Cancel")
    cmd = pbMessage(_INTL("Which Tournament would you like to participate in?"),commands,commands.length)
    return false if cmd == commands.length - 1
    return tourn_ids[cmd]
  end
    
  # Allows the player to choose which style of battle they would like to do
  def chooseBattle
    choices = [_INTL("Single"),_INTL("Double"),_INTL("Full"),_INTL("Sudden Death"),_INTL("Cancel")]
    cmd = pbMessage(_INTL("Which type of Battle would you like to participate in?"),choices,choices.length)
    return false if cmd == choices.length-1
    return cmd
  end
  
  # Creates a new trainer party based on the battle type, and the Pokemon chosen to enter
  def choosePokemon
    ret = false
    return "notEligible" if !@challenge_rules.ruleset.hasValidTeam?($player.party)
    pbMessage(_INTL("Please choose the Pokémon you would like to participate."))
    pbFadeOutIn(99999){
       scene = PokemonParty_Scene.new
       screen = PokemonPartyScreen.new(scene,$player.party)
       ret = screen.pbPokemonMultipleEntryScreenEx(@challenge_rules.ruleset)
    }
    return ret
  end
  
  # Cancels the entry into the Tournament
  def cancelEntry
    self.endTournament
    pbMessage(_INTL("We hope to see you again."))
    return false
  end
  
  # Method used to generate a full list of Trainers to battle
  def generateRounds(selected)
    @trainer_list = []
    full_list = generateFromList(selected)
    i = 0
    loop do
      n = rand(full_list.length)
      trainer = full_list[n]
      full_list.delete_at(n)
      @trainer_list.push([i,trainer])
      i+=1
      break if @trainer_list.length > 7
    end
    n = rand(8)
    @player_index = n
    @player_index_int = @player_index
    @trainer_list[n] = $player.party    
    @trainer_list_int = @trainer_list
  end
  
  # Methods used to generate the individual rounds
  def generateRound1
    trainer = @trainer_list[[1,0,3,2,5,4,7,6][@player_index]][1]
    trainer = Tournament_Trainer.new(*trainer)
    return trainer
  end
  
  def generateRound2
    list = ["","","",""]
    @player_index = @player_index/2
    for i in 0...4
      if i == @player_index
        list[i] = $player.party
      else
        list[i] = @trainer_list[(i*2)+rand(2)]
      end
    end
    @trainer_list = list
    trainer = @trainer_list[[1,0,3,2][@player_index]][1]
    trainer = Tournament_Trainer.new(*trainer)
    return trainer
  end
  
  def generateRound3
    list = ["","","",""]
    @player_index = @player_index/2
    for i in 0...2
      if i == @player_index
        list[i] = $player.party
      else
        list[i] = @trainer_list[(i*2)+rand(2)]
      end
    end
    @trainer_list = list
    trainer = @trainer_list[[1,0][@player_index]][1]
    trainer = Tournament_Trainer.new(*trainer)
    return trainer
  end
  
  def visualRound(trainer,back =false)
    event = $game_map.events[PWTSettings::PWT_OPP_EVENT]
    event.character_name = GameData::TrainerType.charset_filename_brief(trainer.id)
    event.refresh
    if back
      self.moveSwitch('D',event)
    else
      self.moveSwitch('B',event)
    end
    @miniboard.vsSequence(trainer) if !back
  end
  
  # Scoreboard visual effects
  def generateScoreboard
    @brdview = Viewport.new(0,-@viewport.rect.height,@viewport.rect.width,@viewport.rect.height*2)
    @brdview.z = 999999
    @board = Sprite.new(@brdview)
    @board.bitmap = Bitmap.new(@viewport.rect.width,@viewport.rect.height)
    pbSetSystemFont(@board.bitmap)
    @miniboard = MiniBoard.new(@viewport)
  end
  
  def displayScoreboard(trainer)
    @brdview.color = Color.new(0,0,0,0)
    nlist = []
    for i in 0...@trainer_list.length
      nlist.push(@trainer_list[i][0])
    end
    x = 0
    y = 0
    gwidth = @viewport.rect.width
    gheight = @viewport.rect.height
    @board.bitmap.clear
    @board.bitmap.fill_rect(0,0,gwidth,gheight,Color.new(0,0,0))
    @board.bitmap.blt(0,0,RPG::Cache.picture("PWT/scoreboard"),Rect.new(0,0,gwidth,gheight))

    for i in 0...@trainer_list_int.length
      opacity = 255
      if i == @player_index_int
        trname = $player.name
        meta = GameData::PlayerMetadata.get($player.character_ID)
        char = pbGetPlayerCharset(meta.walk_charset,nil,true)
        bitmap = RPG::Cache.load_bitmap("Graphics/Characters/",char)
      else
        opacity = 80 if !(nlist.include?(@trainer_list_int[i][0]))
        trainer = Tournament_Trainer.new(*@trainer_list_int[i][1])
        trname = trainer.name
        bitmap = RPG::Cache.load_bitmap("Graphics/Characters/",GameData::TrainerType.charset_filename_brief(trainer.id))
      end
      @board.bitmap.blt(24+(gwidth-44-(bitmap.width/4))*x,24+(gheight/6)*y,bitmap,Rect.new(0,0,bitmap.width/4,bitmap.height/4),opacity)
      text=[[trname,34+(bitmap.width/4)+(gwidth-64-(bitmap.width/2))*x,38+(gheight/6)*y,x*1,Color.new(255,255,255),Color.new(80,80,80)]]
      pbDrawTextPositions(@board.bitmap,text)
      y+=1
      x+=1 if y > 3
      y=0 if y > 3
    end
    for k in 0...2
      16.times do
        next if @brdview.nil?
        @brdview.color.alpha += 16*(k < 1 ? 1 : -1)
        self.wait(1)
      end
      if k == 0
        @brdview.rect.y += @viewport.rect.height
        @brdview.rect.y = - @viewport.rect.height if @brdview.rect.y > 0
      end
      8.times do; Graphics.update; end
    end
    loop do
      self.wait(1)
      if Input.trigger?(Input::C)
        pbSEPlay("Choose",80)
        break
      end
    end
    for k in 0...2
      16.times do
        next if @brdview.nil?
        @brdview.color.alpha += 16*(k < 1 ? 1 : -1)
        self.wait(1)
      end
      if k == 0
        @brdview.rect.y += @viewport.rect.height
        @brdview.rect.y = - @viewport.rect.height if @brdview.rect.y > 0
      end
      8.times do; Graphics.update; end
    end
  end
  
  def disposeScoreboard
    @board.dispose if @board && !@board.disposed?
    @miniboard.dispose if @miniboard && !@miniboard.disposed?
    @brdview.dispose if @brdview
  end
  
  def updateMiniboard
  return if @miniboard.nil? || !@miniboard.respond_to?(:disposed?) || !@miniboard.respond_to?(:update)
    return if !@miniboard && !@miniboard.disposed?
    if $game_map.map_id == PWTSettings::PWT_MAP_DATA[0]
      event = $game_map.events[PWTSettings::PWT_SCORE_BOARD_EVENT]
      return if event.nil?
      @miniboard.update(event.screen_x - 16, event.screen_y - 32)
    end
  end
    
  # Creates a small introductory conversation
  def introduction
    pbMessage(_INTL("Hello, and welcome to the Pokémon World Tournament!\\1"))
    pbMessage(_INTL("The place where the strongest gather to compete.\\1"))
    pbMessage(_INTL("Before we go any further, you will need to save your progress.\\1"))
  end
  
  # Creates a small conversation if no Tournaments are available
  def notAvailable
    pbMessage(_INTL("I'm terribly sorry, but it seems there are currently no competitions around for you to compete in.\\1"))
    pbMessage(_INTL("Please come back at a later time!"))
  end
  
  # Handles the tournament branch
  def startTournament
    @round = 0
    doublebattle = false
    doublebattle = true if @battle_type == 1

    pbMessage(_INTL("Announcer: Welcome to the {1} Tournament!\\1",GameData::PWTTournament.get(@tournament_id).name))
    pbMessage(_INTL("Announcer: Today we have 8 very eager contestants, waiting to compete for the title of \"Champion\".\\1"))
    pbMessage(_INTL("Announcer: Let us turn our attention to the scoreboard, to see who will be competing today.\\1"))
    trainer = self.generateRound1
    self.displayScoreboard(trainer)
    self.moveSwitch('A')
    pbMessage(_INTL("Announcer: Without further ado, let the first match begin.\\1"))
    pbMessage(_INTL("Announcer: This will be a battle between {1} and {2}.",$player.name,trainer.name))
    self.visualRound(trainer)
    pbMessage(trainer.beforebattle) if !trainer.beforebattle.nil?
	$PokemonGlobal.nextBattleVictoryBGM = "B2W2 213 Winning in the PWT!"
    if pbPWTBattle(trainer,@challenge_rules,@outcome)
      @round = 1
      pbMessage(trainer.afterbattle) if !trainer.afterbattle.nil?
      @beat.push(trainer)
      pbMessage(_INTL("Announcer: Wow! What an exciting first round!\\1"))
      pbMessage(_INTL("Announcer: The stadium is getting heated up, and the contestants are on fire!\\1"))
      self.visualRound(trainer,true)
      pbMessage(_INTL("Announcer: Let us turn our attention back to the scoreboard for the results.\\1"))
      trainer = self.generateRound2
      self.displayScoreboard(trainer)
      pbMessage(_INTL("Announcer: It looks like the next match will be between {1} and {2}.\\1",$player.name,trainer.name))
      self.visualRound(trainer)
      pbMessage(_INTL("Announcer: Let the battle begin!"))
      pbMessage(trainer.beforebattle) if !trainer.beforebattle.nil?
	  $PokemonGlobal.nextBattleVictoryBGM = "B2W2 213 Winning in the PWT!"
      if pbPWTBattle(trainer,@challenge_rules,@outcome)
        @round = 2
        pbMessage(trainer.afterbattle) if !trainer.afterbattle.nil?
        @beat.push(trainer)
        pbMessage(_INTL("Announcer: What spectacular matches!\\1"))
        pbMessage(_INTL("Announcer: These trainers are really giving it all.\\1"))
        self.visualRound(trainer,true)
        pbMessage(_INTL("Announcer: Let's direct our attention at the scoreboard one final time.\\1"))
        trainer = self.generateRound3
        self.displayScoreboard(trainer)
        pbMessage(_INTL("Announcer: Alright! It's all set!\\1"))
        pbMessage(_INTL("Announcer: The final match of this tournament will be between {1} and {2}.\\1",$player.name,trainer.name))
        self.visualRound(trainer)
        pbMessage(_INTL("Announcer: May the best trainer win!"))
        pbMessage(trainer.beforebattle) if !trainer.beforebattle.nil?
		$PokemonGlobal.nextBattleBGM = "B2W2 212 PWT Final Round!"
		$PokemonGlobal.nextBattleVictoryBGM = "B2W2 213 Winning in the PWT!"
        if pbPWTBattle(trainer,@challenge_rules,@outcome)
          pbBGMFade(0.1)
		  @round = 3
          pbMessage(trainer.afterbattle) if !trainer.afterbattle.nil?
          @beat.push(trainer)
		  pbBGMPlay("B2W2 214 PWT Victor!")
          pbMessage(_INTL("Announcer: What an amazing battle!\\1"))
          pbMessage(_INTL("Announcer: Both the trainers put up a great fight, but our very own {1} was the one to come out on top!\\1",$player.name))
          pbMessage(_INTL("Announcer: Congratulations {1}! You have certainly earned today's title of \"Champion\"!\\1",$player.name))
          pbMessage(_INTL("Announcer: That's all we have time for. I hope you enjoyed today's contest. And we hope to see you again soon."))
          return "win"
        end
      end
    end
    return "loss"
  end

  def transferPlayer(id,x,y,lobby = false)
    @viewport.color = Color.new(0,0,0,0)
    16.times do
      next if @viewport.nil?
      @viewport.color.alpha += 16
      self.wait(1)
    end
    @current_location = [$game_map.map_id,$game_player.x,$game_player.y]
    $game_temp.player_transferring   = true
    $game_temp.player_new_map_id    = id
    $game_temp.player_new_x         = x
    $game_temp.player_new_y         = y
    $game_temp.player_new_direction = 8
    $scene.transfer_player
    if lobby
      self.randLobbyGeneration
      @miniboard.dispose
    else
      self.generateScoreboard
      pbUpdateSceneMap
    end
    8.times do; Graphics.update; end
    16.times do
      next if @viewport.nil?
      @viewport.color.alpha -= 16
      self.wait(1)
    end
  end
  
  def moveSwitch(switch = 'A',event =nil)
    $game_self_switches[[PWTSettings::PWT_MAP_DATA[0],PWTSettings::PWT_MOVE_EVENT,switch]] = true
    $game_map.need_refresh = true
    loop do
      break if $game_self_switches[[PWTSettings::PWT_MAP_DATA[0],PWTSettings::PWT_MOVE_EVENT,switch]] == false
      self.wait(1)
    end
  end
  
  def randLobbyGeneration
    return if @beat.length < 1
    return if rand(100) < 25
    event = $game_map.events[PWTSettings::PWT_LOBBY_EVENT]
    trainer = @beat[rand(@beat.length)]
    return if trainer.lobbyspeech.nil?
    event.character_name = GameData::TrainerType.charset_filename_brief(trainer.id)
    $PokemonGlobal.lobby_trainer = trainer
  end
  
  def endFanfare
    $game_self_switches[[PWTSettings::PWT_MAP_DATA[0],PWTSettings::PWT_FANFARE_EVENT,'A']] = true
    $game_map.need_refresh = true
    loop do
      break if $game_self_switches[[PWTSettings::PWT_MAP_DATA[0],PWTSettings::PWT_FANFARE_EVENT,'A']] == false
      self.wait(1)
    end
  end

  def pbWaitWithFrames(frames = 1)
    frames.times do
      Graphics.update
      Input.update
      pbUpdateSceneMap
    end
  end
  
  # duration is in seconds
  def pbWaitWithDeltaTime(duration)
    timer_start = System.uptime
    until System.uptime - timer_start >= duration
      # do sth
      Graphics.update
      Input.update
      pbUpdateSceneMap
    end
  end

  def wait(frames = 1)
    mult = Graphics.frame_rate/PWTSettings::PWT_DEFAULT_FRAMERATE 
    frames = frames * mult

    if PWTSettings::PWT_USE_DELTA_TIME
      if frames <= 0
        self.update
        Graphics.update
        pbUpdateSceneMap
      else 
        pbWaitWithDeltaTime(pbGetFramesClampedDuration(frames))
      end
    else
      pbWaitWithFrames(frames)
    end
  end

  def pbGetFramesClampedDuration(frames = 1)
    duration = frames.to_f / Graphics.frame_rate
    duration = 0.01 if duration <= 0
    return duration
  end   
end
#-------------------------------------------------------------------------------
# Trainer objects to be used in tournaments
#-------------------------------------------------------------------------------
class Tournament_Trainer
  attr_reader :id
  attr_reader :name
  attr_reader :endspeech
  attr_reader :winspeech
  attr_reader :variant
  attr_reader :lobbyspeech
  attr_reader :beforebattle
  attr_reader :afterbattle
  
  def initialize(*args)
    trainerid, name, endspeech, winspeech, variant, lobbyspeech, beforebattle, afterbattle = args
    tr_type_data = GameData::TrainerType.try_get(trainerid)
    raise "No valid Trainer ID has been specified" if !tr_type_data
    @id = tr_type_data.id
    @name = name
    @endspeech = endspeech
    @winspeech = winspeech
    @variant = variant
    @lobbyspeech = lobbyspeech
    @beforebattle = beforebattle
    @afterbattle = afterbattle
  end
  
end
#-------------------------------------------------------------------------------
# Mini scoreboard object
#-------------------------------------------------------------------------------
class MiniBoard
  attr_reader :inSequence
  
  def initialize(viewport)
    @viewport = Viewport.new(-6*32,-3*32,6*32,3*32)
    @viewport.z = viewport.z - 1
    @disposed = false
    @inSequence = false
    @index = 0
    
    @s = {}
    @s["bg"] = Sprite.new(@viewport)
    @s["bg"].bitmap = RPG::Cache.picture("PWT/pwtMiniBoard_bg")
    @s["bg"].opacity = 0
    
    @s["vs1"] = Sprite.new(@viewport)
    @s["vs1"].bitmap = Bitmap.new(6*32,3*32)
    pbSetSmallFont(@s["vs1"].bitmap)
    @s["vs1"].x = 6*32
    
    @s["vs2"] = Sprite.new(@viewport)
    @s["vs2"].bitmap = Bitmap.new(6*32,3*32)
    pbSetSmallFont(@s["vs2"].bitmap)
    @s["vs2"].x = -6*32
    
    @s["vs"] = Sprite.new(@viewport)
    @s["vs"].bitmap = RPG::Cache.picture("PWT/pwtMiniBoard_vs")
    @s["vs"].ox = @s["vs"].bitmap.width/2
    @s["vs"].oy = @s["vs"].bitmap.height/2
    @s["vs"].x = @s["vs"].ox
    @s["vs"].y = @s["vs"].oy
    @s["vs"].zoom_x = 2
    @s["vs"].zoom_y = 2
    @s["vs"].opacity = 0
    
    @s["over"] = Sprite.new(@viewport)
    @s["over"].bitmap = RPG::Cache.picture("PWT/pwtMiniBoard_ov")
    @s["over"].z = 50
  end
  
  def pbGetFramesClampedDuration(frames = 1)
    duration = frames.to_f/Graphics.frame_rate
    duration = 0.01 if duration <= 0
    return duration
  end   

  def update(x, y)
    @viewport.rect.x = x
    @viewport.rect.y = y
    @s["over"].y -= 1 if @index%4==0
    @s["over"].y = 0 if @s["over"].y <= -(32*3)
    @index += 1
    @index = 0 if @index > 64
    @s["bg"].opacity += 32 if @s["bg"].opacity < 255
    if !@inSequence
      @s["vs1"].x += 12 if @s["vs1"].x < 6*32
      @s["vs2"].x -= 12 if @s["vs2"].x > -6*32
      @s["vs"].zoom_x += 1/16.0 if @s["vs"].zoom_x < 2
      @s["vs"].zoom_y += 1/16.0 if @s["vs"].zoom_y < 2
      @s["vs"].opacity -= 16 if @s["vs"].opacity > 0
    end
  end
  
  def dispose
    pbDisposeSpriteHash(@s)
    @viewport.dispose
    @disposed = true
  end
  
  def disposed?
    return @disposed
  end
  
  def vsSequence(trainer)
    multFPS = pbGetFramesClampedDuration(1)
    @inSequence = true
    @s["vs1"].bitmap.clear
    @s["vs1"].bitmap.blt(0,0,RPG::Cache.picture("PWT/pwtMiniBoard_vs1"),Rect.new(0,0,6*32,3*32))
    bmp = self.fetchTrainerBmp($player.trainer_type)
    x = (bmp.width - 38)/2
    y = (bmp.height - 38)/6
    @s["vs1"].bitmap.blt(135,13,bmp,Rect.new(x,y,38,38))
    pbDrawOutlineText(@s["vs1"].bitmap,79,64,108,26,$player.name,Color.new(255,255,255),nil,1)
    
    @s["vs2"].bitmap.clear
    @s["vs2"].bitmap.blt(0,0,RPG::Cache.picture("PWT/pwtMiniBoard_vs2"),Rect.new(0,0,6*32,3*32))
    bmp = self.fetchTrainerBmp(trainer.id)
    x = (bmp.width - 38)/2
    y = (bmp.height - 38)/6
    @s["vs2"].bitmap.blt(19,44,bmp,Rect.new(x,y,38,38))
    pbDrawOutlineText(@s["vs2"].bitmap,5,15,108,26,trainer.name,Color.new(255,255,255),nil,1)
    16.times do
      @s["vs1"].x -= 12
      @s["vs2"].x += 12
      @s["vs"].zoom_x -= 1/16.0
      @s["vs"].zoom_y -= 1/16.0
      @s["vs"].opacity += 16
      pbWait(multFPS)
    end
    pbWait(multFPS * 64)
    @inSequence = false
  end
  
  def fetchTrainerBmp(trainerid)
    file = GameData::TrainerType.player_front_sprite_filename(trainerid)
	file.slice!("Graphics/Trainers/")
    bmp0 = RPG::Cache.load_bitmap("Graphics/Trainers/",file)
    if defined?(DynamicTrainerSprite) && defined?(TRAINERSPRITESCALE)
      bmp1 = Bitmap.new(bmp0.height*TRAINERSPRITESCALE,bmp0.height*TRAINERSPRITESCALE)
      bmp1.stretch_blt(Rect.new(0,0,bmp1.width,bmp1.height),bmp0,Rect.new(bmp0.width-bmp0.height,0,bmp0.height,bmp0.height))
    else
      bmp1 = bmp0.clone     
    end
    return bmp1
  end
end
#-------------------------------------------------------------------------------
# Trainer party modifier
#-------------------------------------------------------------------------------
alias pbLoadTrainer_pwt pbLoadTrainer unless defined?(pbLoadTrainer_pwt)
def pbLoadTrainer(*args)
  trainer = pbLoadTrainer_pwt(*args)
  return nil if trainer.nil?
  return trainer if !(!$PWT.nil? && $PWT.internal)
  party = trainer.party
  length = [3,4,6,1][$PWT.battle_type]
  old_party = party.clone
  new_party = []
  count = 0
  loop do
    n = rand(old_party.length)
    new_party.push(old_party[n])
    old_party.delete_at(n)
    break if new_party.length >= length
  end
  trainer.party = new_party.clone 
  return trainer
end

module BattleCreationHelperMethods
  class << self
    alias pwt_prepare_battle prepare_battle
    def prepare_battle(battle)
      self.pwt_prepare_battle(battle)
      if !$PWT.nil? && $PWT.internal
        $PWT.inbattle = true
        battle.internalBattle = false
        if $PWT.challenge_rules
          $PWT.challenge_rules.battlerules.each do |p|
            p.setRule(battle)
          end
        end
      end
    end
  end
end

alias pbUpdateSceneMap_pwt pbUpdateSceneMap unless defined?(pbUpdateSceneMap_pwt)
def pbUpdateSceneMap(*args)
  pbUpdateSceneMap_pwt(*args)
  $PWT.updateMiniboard if !$PWT.nil? && $PWT.internal && !$PWT.inbattle
end

class Battle::Scene
  alias pbEndBattle_pwt pbEndBattle unless self.method_defined?(:pbEndBattle_pwt)
  def pbEndBattle(*args)
    pbEndBattle_pwt(*args)
    $PWT.inbattle = false if !$PWT.nil? && $PWT.internal && $PWT.inbattle
  end
end
#-------------------------------------------------------------------------------
# Extra functionality added to the PokemonGlobalMetadata and GameStats
#-------------------------------------------------------------------------------
class Game_Event
  attr_accessor :interpreter
  attr_accessor :page
end

class PokemonGlobalMetadata
  attr_accessor :lobby_trainer
end

class GameStats
  attr_accessor :pwt_wins
  attr_accessor :pwt_loss
  attr_accessor :pwt_win_streak
end

class PokemonChallengeRules
  attr_reader :battlerules
end

# Method used to start the PWT
def startPWT
  height = defined?(SCREENDUALHEIGHT) ? SCREENDUALHEIGHT : Graphics.height
  viewport = Viewport.new(0,0,Graphics.width,height)
  viewport.z = 100
  $PWT = AdvancedWorldTournament.new(viewport)
end

def continuePWT(id =0)
  $PWT.continue
end

def pwtLobbyTalk
  event = $game_map.events[PWTSettings::PWT_LOBBY_EVENT]
  if event.character_name != "" && !$PokemonGlobal.lobby_trainer.nil?
    pbMessage(_INTL($PokemonGlobal.lobby_trainer.lobbyspeech))
  end
end

def pbPWTBattle(pwt_trainer,challenge_rules,outcomeVar=1)
  $player.heal_party
  # Create the trainer
  npc_trainer = pbLoadTrainer(pwt_trainer.id,pwt_trainer.name,pwt_trainer.variant)
  npc_trainer.lose_text = pwt_trainer.endspeech if pwt_trainer.endspeech
  npc_trainer.win_text = pwt_trainer.winspeech if pwt_trainer.winspeech
  # Set battle rules
  setBattleRule("outcomeVar",outcomeVar) if outcomeVar != 1
  setBattleRule("canLose")
  setBattleRule("noMoney")
  setBattleRule("noExp")
  setBattleRule("backdrop", "PWT") if pbResolveBitmap(sprintf("Graphics/Battlebacks/PWT_bg"))
  # set up challenge rules
  challenge_rules = PokemonChallengeRules.new if !challenge_rules
  oldlevels = challenge_rules.adjustLevels($player.party, npc_trainer.party)
  olditems  = $player.party.transform { |p| p.item_id }
  # Perform the battle
  decision = TrainerBattle.start_core(npc_trainer)
  challenge_rules.unadjustLevels($player.party, npc_trainer.party, oldlevels)
  # Return true if the player won the battle, and false if any other result
  $player.party.each_with_index do |pkmn, i|
    pkmn.heal
    pkmn.item = olditems[i]
  end
  return (decision==1)
end