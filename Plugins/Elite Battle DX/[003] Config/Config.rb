#===============================================================================
#  Elite Battle: DX
#    by Luka S.J.
# ----------------
#  System Settings
#===============================================================================
module EliteBattle

  # Waiting period (in seconds) before battle "camera" starts moving
  BATTLE_MOTION_TIMER = 90

  # used to scale the trainer bitmaps (front sprites) to 200%
  TRAINER_SPRITE_SCALE = 1

  # used to scale the Pokemon bitmaps (front sprites and UI) to 200%
  FRONT_SPRITE_SCALE = 2

  # used to scale the Pokemon bitmaps (back sprites) to 200%
  BACK_SPRITE_SCALE = 2

  # configures the scale of the room to account for the vector motion
  ROOM_SCALE = 2.25

  # set this to true to use the low HP bgm when player's Pokemon HP reaches 25%
  USE_LOW_HP_BGM = false

  # set this to true if you want to use your own common animations from the editor
  CUSTOM_COMMON_ANIM = false

  # set this to true to use animations from the Animation editor for missing move animations
  CUSTOM_MOVE_ANIM = false

  # disables "camera" zooming and movement throughout the entire scene
  DISABLE_SCENE_MOTION = false

  # Chance (%) (from 0 to 100, allows up to 2 decimal places) that Shiny Pokemon
  # will have a unique hue applied to them, altering their color further
  # this percentage is calculated AFTER the shiny generation chance
  SUPER_SHINY_RATE = 1

  # the minimum amount of (random) IV attributes to be set to 31 for shiny Pokemon
  PERFECT_IV_SHINY = 1

  # the minimum amount of (random) IV attributes to be set to 31 for super shiny Pokemon
  PERFECT_IV_SUPER = 3

  # Show player line up during wild battles
  SHOW_LINEUP_WILD = false

  # Adjust the player sendout animations based on whether or not the
  # Following Pokemon EX system is present
  USE_FOLLOWER_EXCEPTION = true

  # add EBDX debug menu
  SHOW_DEBUG_FEATURES = false

  #offset of the HP text (e.g: 10/10) so you can move it around
  HP_TEXT_Y_OFFSET = 10
  HP_TEXT_X_OFFSET = 0

  # The offset might require to set extra height to the bitmap where it is allocated
  HP_TEXT_Y_BITMAP = 20

  # Offset to adjust the "origin" of the player backsprite. Take into account, if you use Sprite Positioner this won't move the sprite.
  PLAYER_BACKSPRITE_X_OFFSET = 0
  PLAYER_BACKSPRITE_Y_OFFSET = -20

  # Offset to adjust the "origin" of the foe frontsprite. Take into account, if you use Sprite Positioner this won't move the sprite.
  ENEMY_FRONT_X_OFFSET = 0
  ENEMY_FRONT_Y_OFFSET = 0

  # if True, animated sprites (in Graphics/EDBX/Battlers) are checked first in battle. If false, static sprites are checked first.
  PRIORITIZE_ANIMATED_SPRITES = true
  #if True, when the female sprite is not found in Graphics/EBDX/Battlers/Front(Back or whatever)/Female, the regular sprite will be used instead. If using regular sprites _female is used instead
  PRIORITIZE_REGULAR_SPRITES = true

  # ZUD plugins clear cached data so EBDX gets stuck. Setting this to true skips the cache and directly loads the game.
  SKIP_CACHED_DATA = false

  #if set to false, pokemon_metrics.txt is checked first (default Essentials file). If not, that file is skipped.
  FORCE_EBDX_ALTITUDE = true

  #if set to false, the original "frame system" is used instead of the new deltaTime. The "original" has a hotfix as well based on waiting frames.
  USE_DELTA_TIME_HOTFIX = false

  #Target framerate to check the current Graphics.frame_rate. Duration for pbWait is calculated by frames / current fps and the multiplier by current fps / target rate. 60/60 = 1 so mult doesn't apply.
  DEFAULT_FRAMERATE = 60

  # Apply extra offsets based to pbShowOpponent and pbHideOpponent (still in test).
  USE_TRAINER_OUT_OF_PLACE_HOTFIX = true

  # If true, it always check the species count in GameData. If the full count is detected to be less than expected, it reinitilize the pokemon species list.
  TRY_TO_ALWAYS_INITIALIZE = true

  # As EBDX uses custom intros, setting this to false will use default Essentials intros
  USE_EBDX_BATTLE_INTROS = true
end
#-------------------------------------------------------------------------------
# Adds additional "camera" vectors for when the camera is idling
# vector parameters are: x, y, angle, scale, scene zoom
EliteBattle.add_vector(:CAMERA_MOTION,
  [132, 408, 24, 302, 1],
  [122, 294, 20, 322, 1],
  [238, 304, 26, 322, 1],
  [0, 384, 26, 322, 1],
  [198, 298, 18, 282, 1],
  [196, 306, 26, 242, 0.6],
  [156, 280, 18, 226, 0.6],
  [60, 280, 12, 388, 1],
  [160, 286, 16, 340, 1]
)
#-------------------------------------------------------------------------------
#  additional battle system configuration
#-------------------------------------------------------------------------------
# method of bulk assigning Transitions for Pokemon and Trainers
EliteBattle.assign_transition("rainbowIntro", :ALLOW_ALL)
