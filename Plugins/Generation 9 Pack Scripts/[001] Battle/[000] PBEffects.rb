################################################################################
# 
# New PBEffects.
# 
################################################################################


module PBEffects
  AllySwitch      = 400 # Used to determine if Ally Switch should fail.
  BoosterEnergy   = 401 # Used to flag whether or not ParadoxStat should persist due to Booster Energy.
  Commander       = 402 # Used for storing data related to Commander.
  CudChew         = 403 # Used to count the remaining rounds until Cud Chew triggers.
  DoubleShock     = 404 # Used for removing the user's Electric typing after using Double Shock.
  GlaiveRush      = 405 # Used to count the remaining rounds until vulnerability from Glaive Rush wares off.
  ParadoxStat     = 406 # Used to reference which stat is being boosted by Protosynthesis/Quark Drive.
  OneUseAbility   = 407 # Used to flag a battler's ability to only trigger once per switch-in.
  SaltCure        = 408 # Used to flag a battler as under the effects of Salt Cure.
  SilkTrap        = 409 # Used to flag a battler as under the protection effects of Silk Trap.
  Splinters       = 410 # Used to flag a battler as under the splinters effect.
  SplintersType   = 411 # Used to determine the type effectiveness of splinters damage.
  SuccessiveMove  = 412 # Used to flag a move as unselectable by a battler on consecutive turns.
  SupremeOverlord = 413 # Used to trigger the effects of the Supreme Overlord ability.
  Syrupy          = 414 # Used to track the remaining number of turns until Syrup Bomb's effect wares off.
  SyrupyUser      = 415 # Used to track the Syrup Bomb user so the effect ends if they leave the field.
  BurningBulwark  = 416 # Used for the effect of Burning Bulwark.
end

#-------------------------------------------------------------------------------
# New effects and values to be added to the debug menu.
#-------------------------------------------------------------------------------
module Battle::DebugVariables
  BATTLER_EFFECTS[PBEffects::AllySwitch]      = { name: "Ally Switch applies this round",                default: false }
  BATTLER_EFFECTS[PBEffects::CudChew]         = { name: "Cud Chew number of rounds until active",        default: 0 }
  BATTLER_EFFECTS[PBEffects::DoubleShock]     = { name: "Double Shock has removed self's Electric type", default: false }
  BATTLER_EFFECTS[PBEffects::GlaiveRush]      = { name: "Glaive Rush vulnerability rounds remaining",    default: 0 }
  BATTLER_EFFECTS[PBEffects::ParadoxStat]     = { name: "Protosynthesis/Quark Drive stat boosted",       default: nil, type: :stat }
  BATTLER_EFFECTS[PBEffects::BoosterEnergy]   = { name: "Booster Energy applies",                        default: false }
  BATTLER_EFFECTS[PBEffects::SaltCure]        = { name: "Salt Cure applies",                             default: false }
  BATTLER_EFFECTS[PBEffects::SilkTrap]        = { name: "Silk Trap applies this round",                  default: false }
  BATTLER_EFFECTS[PBEffects::Splinters]       = { name: "Splinters number of rounds remaining",          default: 0 }
  BATTLER_EFFECTS[PBEffects::SplintersType]   = { name: "Splinters damage typing",                       default: nil, type: :type }
  BATTLER_EFFECTS[PBEffects::SupremeOverlord] = { name: "Supreme Overlord multiplier 1 + 0.1*x (0-5)",   default: 0, max: 5 }
  BATTLER_EFFECTS[PBEffects::Syrupy]          = { name: "Syrupy turns remaining",                        default: 0 }
  BATTLER_EFFECTS[PBEffects::SyrupyUser]      = { name: "Battler syruped self",                          default: -1 }
  BATTLER_EFFECTS[PBEffects::BurningBulwark]  = { name: "Burning Bulwark applies this round",            default: false }
end