################################################################################
# 
# Settings.
# 
################################################################################


module Settings
  #=============================================================================
  # Weather Settings (Hail/Snow)
  #=============================================================================
  # 0 : Hail     (Classic) Hail weather functions as it did in Gen 8 and older.
  # 1 : Snow      (Gen 9+) Snow weather replaces Hail. Boosts Defence of Ice-types.
  # 2 : Hailstorm (Custom) Hailstorm weather combines both versions.
  #-----------------------------------------------------------------------------
  # Note: In all versions of Snow/Hail, the odds of inflicting the Frostbite 
  # status is doubled if a move is capable of inflicting Frostbite. Pokemon with
  # the Drowsy status are also twice as likely to be unable to act each turn.
  #-----------------------------------------------------------------------------
  HAIL_WEATHER_TYPE = 1
  
  
  #=============================================================================
  # Status Settings (Drowsy/Frostbite)
  #=============================================================================
  # When true, effects that would normally check for or inflict Sleep/Freeze
  # will call the Drowsy/Frostbite statuses instead. If false, they will be
  # treated as separate status conditions.
  #-----------------------------------------------------------------------------
  SLEEP_EFFECTS_CAUSE_DROWSY     = false
  FREEZE_EFFECTS_CAUSE_FROSTBITE = false
  
  
  #=============================================================================
  # Mechanic Settings.
  #=============================================================================
  # Makes game mechanics function like their Gen 9 equivalents where appropriate. 
  # Don't change this setting if you want the full Gen 9 experience.
  #-----------------------------------------------------------------------------
  # Updated Effects:
  # -Battle Bond Ability now boosts stats instead of changing into Ash-Greninja.
  # -Protean/Libero Abilities now only trigger once per switch-in.
  # -Dauntless Shield/Intrepid Sword now only trigger once per battle.
  # -Ally Switch now fails with consecutive use.
  # -Charge effect now lasts until the next Electric-type move is used.
  # -Transistor ability grants a 30% power boost, down from 50%.
  # -Incense is no longer required to hatch baby species of certain Pokemon.
  #-----------------------------------------------------------------------------
  MECHANICS_GENERATION = 9
end