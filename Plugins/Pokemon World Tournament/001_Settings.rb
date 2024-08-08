module PWTSettings
# Information pertining to the start position on the PWT stage
# Format is as following: [map_id, map_x, map_y]
PWT_MAP_DATA = [32,21,14]
# ID for the event used to move the player and opponents on the map
PWT_MOVE_EVENT = 37
# ID of the opponent event
PWT_OPP_EVENT = 35
# ID of the scoreboard event
PWT_SCORE_BOARD_EVENT = 34
# ID of the lobby trainer event
PWT_LOBBY_EVENT = 6
# ID of the event used to display an optional even if the player wins the PWT
PWT_FANFARE_EVENT = 38
# If marked as true, it will apply a multiplier based on the player's current win streak. Defeault to false.
PWT_STREAK_MULT = false
# If marked as true, it will use DeltaTime, otherwise, it will use the old frame system
PWT_USE_DELTA_TIME = false
# Target framerate. By default it's usually 60 fps with MKXP-Z.
PWT_DEFAULT_FRAMERATE = 60
end

module GameData
  class PWTTournament
    attr_reader :id
    attr_reader :real_name
    attr_reader :trainers
    attr_reader :condition_proc
	  attr_reader :points_won

    DATA = {}

    extend ClassMethodsSymbols
    include InstanceMethods

    def self.load; end
    def self.save; end

    def initialize(hash)
      @id             = hash[:id]
      @real_name      = hash[:name]          || "Unnamed"
      @trainers       = hash[:trainers]
      @condition_proc = hash[:condition_proc]
      @rules_proc     = hash[:rules_proc]
      @banned_proc    = hash[:banned_proc]
	  @points_won     = hash[:points_won]    || 3
    end

    # @return [String] the translated name of this nature
    def name
      return _INTL(@real_name)
    end
    
    def call_condition(*args)
      return (@condition_proc) ? @condition_proc.call(*args) : true
    end
    def call_rules(*args)
      return (@rules_proc) ? @rules_proc.call(*args) : PokemonChallengeRules.new
    end
    def call_ban_reason(*args)
      return (@banned_proc) ? @banned_proc.call(*args) : nil
    end
  end
end

##################################################################
# The format for defining individual Tournaments is as follows.
##################################################################
=begin
GameData::PWTTournament.register({
  :id => :Tutorial_Tournament,			# Internal name of the Tournament to be called
  :name => _INTL("Kanto Leaders"),		# Display name of the Tournament in the choice selection box
  :trainers => [						# Array that contains all of the posssible trainers in a Tournament. Must have at least 8.
                [:ID,"Trainer Name","Player Victory Dialogue.","Player Lose Dialogue.",Variant Number,"Lobby Dialogue.","Pre-Battle Dialogue.","Post-Battle Dialogue"], # Trainer 1
				[:ID,"Trainer Name","Player Victory Dialogue.","Player Lose Dialogue.",Variant Number,"Lobby Dialogue.","Pre-Battle Dialogue.","Post-Battle Dialogue"]  # Trainer 2, etc
			   ],
										# Trainers follow this exact format. 
										# ID and Trainer Name are mandatory.
										# Victory dialogue will default to "..." if not filled.
										# Lose dialogue will default to "..." is not filled in either here or trainers.txt. If Lose dialogue is filled here, it overrides the defined line from trainers.txt
										# Variant Number will default to 0 if not filled.
										# If there is no Lobby Dialogue they will not appear in the Lobby map
										# Pre- and Post-battle Dialogue is optional and will display nothing if not filled.
  :condition_proc => proc { 			# The conditions under which this Tournament shows up in the choice selection box. Optional.
	next $PokemonGlobal.hallOfFameLastNumber > 0 
  },					
  :rules_proc => proc {|length|			# This defines the rules for the rules for an individual tournament. More rules can be found in the Challenge Rules script sections
	rules = PokemonChallengeRules.new
    rules.addPokemonRule(BannedSpeciesRestriction.new(:MEWTWO,:MEW,:HOOH,:LUGIA,:CELEBI,:KYOGRE,:GROUDON,:RAYQUAZA,
                                                      :DEOXYS,:JIRACHI,:DIALGA,:PALKIA,:GIRATINA,:REGIGIGAS,:HEATRAN,:DARKRAI,
                                                      :SHAYMIN,:ARCEUS,:ZEKROM,:RESHIRAM,:KYUREM,:LANDORUS,:MELOETTA,
                                                      :KELDEO,:GENESECT))
    rules.addPokemonRule(NonEggRestriction.new)
    rules.addPokemonRule(AblePokemonRestriction.new)
    rules.setNumber(length)
    rules.setLevelAdjustment(FixedLevelAdjustment.new(50))
	next rules
  },
  :banned_proc => proc {				# Displays a message when a team is ineligable to be used in a tournament.
	pbMessage(_INTL("Certain exotic species, as well as eggs, are ineligible.\\1"))
  },
  :points_won => 2						# A configurable amount of Battle Points won after a tournament.
})
=end
##################################################################

GameData::PWTTournament.register({
  :id => :Kanto_Leaders,
  :name => _INTL("Kanto Leaders"),
  :trainers => [
                [:LEADER_Brock,"Brock","Your Pokémon's powerful attacks overcame my rock-hard resistance...\nYou're stronger than I expected...","My barrier was tough to break. Maybe next time.",1,"You were pretty tough! I can't wait to face off against you again!","I'm Brock! I'm an expert on Rock-type Pokémon.","Brock: I really enjoyed the battle with you.\nStill, the world is huge! I can't believe you got past my rock-hard defense!"],
                [:LEADER_Misty,"Misty","You are a skilled Trainer, I have to admit that.","Looks like out of the two of us, I was the better Trainer.",1,"I'm going to train even harder, so that I can beat you next time!"],
                [:LEADER_Surge,"Lt.Surge","You shocked my very core, soldier!","At ease son, not everyone can beat me.",1,"Do you feel this electrifying atmosphere? I'm so pumped!"],
                [:LEADER_Erika,"Erika","Oh my! \nLooks like I've underestimated you.","Keep practicing hard, and one day you will be the victor.",1,"My Pokémon have bloomed ever since they've battled you."],
                [:LEADER_Sabrina,"Sabrina","Impossible! I did not predict this!","The outcome was just as I predicted.",1,"The future tells me of our rematch."],
                [:LEADER_Koga,"Koga","You've got a great battle technique!","My technique was the superior one!",1],
                [:LEADER_Blaine,"Blaine","Your flame burnt me up!","My flames are not something everyone can handle.",1,"You really burned me up back there!"],
                [:LEADER_Giovanni,"Giovanni","What? \nMe, lose?!","I could have never lost to a kid like you!",1]
               ],
  :rules_proc => proc {|length|
    rules = PokemonChallengeRules.new
    rules.addPokemonRule(BannedSpeciesRestriction.new(:MEWTWO,:MEW,:HOOH,:LUGIA,:CELEBI,:KYOGRE,:GROUDON,:RAYQUAZA,
                                                      :DEOXYS,:JIRACHI,:DIALGA,:PALKIA,:GIRATINA,:REGIGIGAS,:HEATRAN,:DARKRAI,
                                                      :SHAYMIN,:ARCEUS,:ZEKROM,:RESHIRAM,:KYUREM,:LANDORUS,:MELOETTA,
                                                      :KELDEO,:GENESECT))
    rules.addPokemonRule(NonEggRestriction.new)
    rules.addPokemonRule(AblePokemonRestriction.new)
    rules.setNumber(length)
    rules.setLevelAdjustment(FixedLevelAdjustment.new(50))
    next rules
  },
  :banned_proc => proc {
    pbMessage(_INTL("Certain exotic species, as well as eggs, are ineligible.\\1"))
  },
  :points_won => 2
})