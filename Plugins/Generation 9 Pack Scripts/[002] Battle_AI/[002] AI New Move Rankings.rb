#===============================================================================
# Drowses the target.
#===============================================================================
Battle::AI::Handlers::MoveFailureAgainstTargetCheck.add("DrowseTarget",
  proc { |move, user, target, ai, battle|
    next move.statusMove? && !target.battler.pbCanDrowse?(user.battler, false, move.move)
  }
)
Battle::AI::Handlers::MoveEffectAgainstTargetScore.add("DrowseTarget",
  proc { |score, move, user, target, ai, battle|
    useless_score = (move.statusMove?) ? Battle::AI::MOVE_USELESS_SCORE : score
    next useless_score if target.effects[PBEffects::Yawn] > 0   # Target is going to fall asleep anyway
    # No score modifier if the sleep will be removed immediately
    next useless_score if target.has_active_item?([:CHESTOBERRY, :LUMBERRY])
    next useless_score if target.faster_than?(user) &&
                          target.has_active_ability?(:HYDRATION) &&
                          [:Rain, :HeavyRain].include?(target.battler.effectiveWeather)
    if target.battler.pbCanDrowse?(user.battler, false, move.move)
      add_effect = move.get_score_change_for_additional_effect(user, target)
      next useless_score if add_effect == -999   # Additional effect will be negated
      score += add_effect
      # Inherent preference
      score += 15
      # Prefer if the user or an ally has a move/ability that is better if the target is asleep
      ai.each_same_side_battler(user.side) do |b, i|
        score += 5 if b.has_move_with_function?("DoublePowerIfTargetAsleepCureTarget",
                                                "DoublePowerIfTargetStatusProblem",
                                                "HealUserByHalfOfDamageDoneIfTargetAsleep",
                                                "StartDamageTargetEachTurnIfTargetAsleep")
        score += 10 if b.has_active_ability?(:BADDREAMS)
      end
      # Don't prefer if target benefits from having the sleep status problem
      # NOTE: The target's Guts/Quick Feet will benefit from the target being
      #       asleep, but the target won't (usually) be able to make use of
      #       them, so they're not worth considering.
      score -= 10 if target.has_active_ability?(:EARLYBIRD)
      score -= 8 if target.has_active_ability?(:MARVELSCALE)
      # Don't prefer if target has a move it can use while asleep
      score -= 8 if target.check_for_move { |m| m.usableWhenAsleep? }
      # Don't prefer if the target can heal itself (or be healed by an ally)
      if target.has_active_ability?(:SHEDSKIN)
        score -= 8
      elsif target.has_active_ability?(:HYDRATION) &&
            [:Rain, :HeavyRain].include?(target.battler.effectiveWeather)
        score -= 15
      end
      ai.each_same_side_battler(target.side) do |b, i|
        score -= 8 if i != target.index && b.has_active_ability?(:HEALER)
      end
    end
    next score
  }
)

#===============================================================================
# Frostbites the target.
#===============================================================================
Battle::AI::Handlers::MoveFailureAgainstTargetCheck.add("FreezeTarget",
  proc { |move, user, target, ai, battle|
    next move.statusMove? && !target.battler.pbCanFrostbite?(user.battler, false, move.move)
  }
)
Battle::AI::Handlers::MoveEffectAgainstTargetScore.add("FreezeTarget",
  proc { |score, move, user, target, ai, battle|
    useless_score = (move.statusMove?) ? Battle::AI::MOVE_USELESS_SCORE : score
    # No score modifier if the freeze will be removed immediately
    next useless_score if target.has_active_item?([:ASPEARBERRY, :LUMBERRY])
    next useless_score if target.faster_than?(user) &&
                          target.has_active_ability?(:HYDRATION) &&
                          [:Rain, :HeavyRain].include?(target.battler.effectiveWeather)
    if target.battler.pbCanFrostbite?(user.battler, false, move.move)
      add_effect = move.get_score_change_for_additional_effect(user, target)
      next useless_score if add_effect == -999   # Additional effect will be negated
      score += add_effect
      # Inherent preference
      score += 15
      # Prefer if the user or an ally has a move/ability that is better if the target is frozen
      ai.each_same_side_battler(user.side) do |b, i|
        score += 5 if b.has_move_with_function?("DoublePowerIfTargetStatusProblem")
      end
      # Don't prefer if target benefits from having the frozen status problem
      # NOTE: The target's Guts/Quick Feet will benefit from the target being
      #       frozen, but the target won't be able to make use of them, so
      #       they're not worth considering.
      score -= 8 if target.has_active_ability?(:MARVELSCALE)
      # Don't prefer if the target knows a move that can thaw it
      score -= 15 if target.check_for_move { |m| m.thawsUser? }
      # Don't prefer if the target can heal itself (or be healed by an ally)
      if target.has_active_ability?(:SHEDSKIN)
        score -= 8
      elsif target.has_active_ability?(:HYDRATION) &&
            [:Rain, :HeavyRain].include?(target.battler.effectiveWeather)
        score -= 15
      end
      ai.each_same_side_battler(target.side) do |b, i|
        score -= 8 if i != target.index && b.has_active_ability?(:HEALER)
      end
    end
    next score
  }
)

################################################################################
# 
# New move effects (PLA).
# 
################################################################################

#===============================================================================
# Dire Claw
#===============================================================================
Battle::AI::Handlers::MoveEffectAgainstTargetScore.add("PoisonParalyzeOrSleepTarget",
  proc { |score, move, user, target, ai, battle|
    # No score modifier if the status problem will be removed immediately
    next score if target.has_active_item?(:LUMBERRY)
    next score if target.faster_than?(user) &&
                  target.has_active_ability?(:HYDRATION) &&
                  [:Rain, :HeavyRain].include?(target.battler.effectiveWeather)
    # Scores for the possible effects
    ["PoisonTarget", "ParalyzeTarget", "SleepTarget"].each do |function_code|
      effect_score = Battle::AI::Handlers.apply_move_effect_against_target_score(function_code,
         0, move, user, target, ai, battle)
      score += effect_score / 3 if effect_score != Battle::AI::MOVE_USELESS_SCORE
    end
    next score
  }
)

#===============================================================================
# Barb Barrage
#===============================================================================
Battle::AI::Handlers::MoveBasePower.add("DoublePowerIfTargetPoisonedPoisonTarget",
  proc { |power, move, user, target, ai, battle|
    next move.move.pbBaseDamage(power, user.battler, target.battler)
  }
)
Battle::AI::Handlers::MoveEffectAgainstTargetScore.add("DoublePowerIfTargetPoisonedPoisonTarget",
  proc { |score, move, user, target, ai, battle|
    poison_score = Battle::AI::Handlers.apply_move_effect_against_target_score("PoisonTarget",
      0, move, user, b, ai, battle)
    if poison_score != Battle::AI::MOVE_USELESS_SCORE
      score += poison_score if poison_score != Battle::AI::MOVE_USELESS_SCORE
    end
    next score
  }
)

#===============================================================================
# Infernal Parade
#===============================================================================
Battle::AI::Handlers::MoveBasePower.add("DoublePowerIfTargetStatusProblemBurnTarget",
  proc { |power, move, user, target, ai, battle|
    next move.move.pbBaseDamage(power, user.battler, target.battler)
  }
)
Battle::AI::Handlers::MoveEffectAgainstTargetScore.add("DoublePowerIfTargetStatusProblemBurnTarget",
  proc { |score, move, user, target, ai, battle|
    burn_score = Battle::AI::Handlers.apply_move_effect_against_target_score("BurnTarget",
      0, move, user, b, ai, battle)
    if burn_score != Battle::AI::MOVE_USELESS_SCORE
      score += burn_score if burn_score != Battle::AI::MOVE_USELESS_SCORE
    end
    next score
  }
)

#===============================================================================
# Ceaseless Edge
#===============================================================================
Battle::AI::Handlers::MoveFailureCheck.add("SplintersTargetGen8AddSpikesGen9",
  proc { |move, user, ai, battle|
    next user.pbOpposingSide.effects[PBEffects::Spikes] >= 3 && Settings::MECHANICS_GENERATION >= 9
  }
)
Battle::AI::Handlers::MoveFailureAgainstTargetCheck.add("SplintersTargetGen8AddStealthRocksGen9",
  proc { |move, user, target, ai, battle|
    next true if Settings::MECHANICS_GENERATION < 9 && target.effects[PBEffects::Splinters] > 0
    next false
  }
)
Battle::AI::Handlers::MoveEffectScore.add("SplintersTargetGen8AddSpikesGen9",
  proc { |score, move, user, ai, battle|
    score += 15
    if Settings::MECHANICS_GENERATION >= 9
      spike_score = Battle::AI::Handlers.apply_move_effect_against_target_score("AddSpikesToFoeSide",
        0, move, user, b, ai, battle)
      if spike_score != Battle::AI::MOVE_USELESS_SCORE
        score += spike_score if spike_score != Battle::AI::MOVE_USELESS_SCORE
      end
    else
      # Prefer early on
      score += 10 if user.turnCount < 2
      if ai.trainer.medium_skill?
        # Prefer if the user has no damaging moves
        score += 10 if !user.check_for_move { |m| m.damagingMove? }
        # Prefer if the target can't switch out to remove its seeding
        score += 8 if !battle.pbCanChooseNonActive?(target.index)
      end
      if ai.trainer.high_skill?
        # Prefer if user can stall while damage is dealt
        if user.check_for_move { |m| m.is_a?(Battle::Move::ProtectMove) }
          score += 10
        end
      end
    end
    next score
  }
)

#===============================================================================
# Stone Axe
#===============================================================================
Battle::AI::Handlers::MoveFailureCheck.add("SplintersTargetGen8AddStealthRocksGen9",
  proc { |move, user, ai, battle|
    next user.pbOpposingSide.effects[PBEffects::StealthRock] && Settings::MECHANICS_GENERATION >= 9
  }
)
Battle::AI::Handlers::MoveFailureAgainstTargetCheck.add("SplintersTargetGen8AddStealthRocksGen9",
  proc { |move, user, target, ai, battle|
    next true if Settings::MECHANICS_GENERATION < 9 && target.effects[PBEffects::Splinters] > 0
    next Battle::AI::Handlers.move_will_fail_against_target?("OHKO", move, user, target, ai, battle)
  }
)
Battle::AI::Handlers::MoveEffectScore.add("SplintersTargetGen8AddStealthRocksGen9",
  proc { |score, move, user, ai, battle|
    score += 15
    if Settings::MECHANICS_GENERATION >= 9
      stealth_rock_score = Battle::AI::Handlers.apply_move_effect_against_target_score("AddStealthRocksToFoeSide",
        0, move, user, b, ai, battle)
      if stealth_rock_score != Battle::AI::MOVE_USELESS_SCORE
        score += stealth_rock_score if stealth_rock_score != Battle::AI::MOVE_USELESS_SCORE
      end
    else
      # Prefer early on
      score += 10 if user.turnCount < 2
      if ai.trainer.medium_skill?
        # Prefer if the user has no damaging moves
        score += 10 if !user.check_for_move { |m| m.damagingMove? }
        # Prefer if the target can't switch out to remove its seeding
        score += 8 if !battle.pbCanChooseNonActive?(target.index)
      end
      if ai.trainer.high_skill?
        # Prefer if user can stall while damage is dealt
        if user.check_for_move { |m| m.is_a?(Battle::Move::ProtectMove) }
          score += 10
        end
      end
    end
    next score
  }
)

#===============================================================================
# Triple Arrows
#===============================================================================
Battle::AI::Handlers::MoveFailureAgainstTargetCheck.copy("LowerTargetDefense1",
                                                         "LowerTargetDefense1FlinchTarget")
Battle::AI::Handlers::MoveEffectAgainstTargetScore.add("LowerTargetDefense1FlinchTarget",
  proc { |score, move, user, target, ai, battle|
    flinch_score = Battle::AI::Handlers.apply_move_effect_against_target_score("FlinchTarget",
       0, move, user, target, ai, battle)
    score += flinch_score if flinch_score != Battle::AI::MOVE_USELESS_SCORE
    score = ai.get_score_for_target_stat_drop(score, target, move.move.statDown, false)
    next score
  }
)

#===============================================================================
# Victory Dance
#===============================================================================
Battle::AI::Handlers::MoveFailureCheck.add("RaiseUserAtkDefSpd1",
  proc { |move, user, ai, battle|
    next false if move.damagingMove?
    will_fail = true
    (move.move.statUp.length / 2).times do |i|
      next if !user.battler.pbCanRaiseStatStage?(move.move.statUp[i * 2], user.battler, move.move)
      will_fail = false
      break
    end
    next will_fail
  }
)
Battle::AI::Handlers::MoveEffectAgainstTargetScore.copy("RaiseUserAttack1",
                                                        "RaiseUserAtkDefSpd1")

#===============================================================================
# Take Heart
#===============================================================================
Battle::AI::Handlers::MoveFailureAgainstTargetCheck.add("RaiseUserSpAtkSpDef1CureStatus",
  proc { |move, user, target, ai, battle|
    will_fail = true
    (move.move.statUp.length / 2).times do |i|
      next if !user.battler.pbCanRaiseStatStage?(move.move.statUp[i * 2], user.battler, move.move)
      will_fail = false
      break
    end
    will_fail = false if target.status != :NONE
    next will_fail
  }
)
Battle::AI::Handlers::MoveEffectAgainstTargetScore.add("RaiseUserSpAtkSpDef1CureStatus",
  proc { |score, move, user, target, ai, battle|
    # Check whether an existing status problem will be removed
    if target.status != :NONE
      score += (target.wants_status_problem?(target.status)) ? -10 : 10
    end
    # Score for user's stat changes
    score = ai.get_score_for_target_stat_raise(score, user, [:SPECIAL_ATTACK, 1], false)
    score = ai.get_score_for_target_stat_drop(score, user, [:SPECIAL_DEFENSE, 1], false)
    next score
  }
)

################################################################################
# 
# New move effects (SV).
# 
################################################################################

#===============================================================================
# Raging Bull
#===============================================================================
Battle::AI::Handlers::MoveEffectScore.copy("RemoveScreens",
                                           "TypeIsUserSecondTypeRemoveScreens")

#===============================================================================
# Last Respects
#===============================================================================
Battle::AI::Handlers::MoveBasePower.add("IncreasePowerEachFaintedAlly",
  proc { |power, move, user, target, ai, battle|
    next move.move.pbBaseDamage(power, user.battler, target.battler)
  }
)

#===============================================================================
# Rage Fist
#===============================================================================
Battle::AI::Handlers::MoveBasePower.add("IncreasePowerEachTimeHit",
  proc { |power, move, user, target, ai, battle|
    next move.move.pbBaseDamage(power, user.battler, target.battler)
  }
)

#===============================================================================
# Collision Course, Electro Drift
#===============================================================================
Battle::AI::Handlers::MoveBasePower.add("IncreasePowerSuperEffective",
  proc { |power, move, user, target, ai, battle|
    next move.move.pbBaseDamage(power, user.battler, target.battler)
  }
)

#===============================================================================
# Triple Dive
#===============================================================================
Battle::AI::Handlers::MoveBasePower.copy("HitTwoTimes",
                                         "HitThreeTimes")    
Battle::AI::Handlers::MoveEffectAgainstTargetScore.copy("HitTwoTimes",
                                                        "HitThreeTimes")

#===============================================================================
# Population Bomb
#===============================================================================
Battle::AI::Handlers::MoveBasePower.add("HitTenTimes",
  proc { |power, move, user, target, ai, battle|
    next power * 7 if user.has_active_item?(:LOADEDDICE) # Average damage dealt
    next power * 10  # Average damage dealt
  }
)
Battle::AI::Handlers::MoveEffectAgainstTargetScore.add("HitTenTimes",
  proc { |score, move, user, target, ai, battle|
    # Prefer if the target has a Substitute and this move can break it before
    # the last hit
    if target.effects[PBEffects::Substitute] > 0 && !move.move.ignoresSubstitute?(user.battler)
      dmg = move.rough_damage
      score += 10 if target.effects[PBEffects::Substitute] < dmg / 2
    end
    next score
  }
)

#===============================================================================
# Axe Kick
#===============================================================================
Battle::AI::Handlers::MoveEffectAgainstTargetScore.add("CrashDamageIfFailsConfuseTarget",
  proc { |score, move, user, target, ai, battle|
    if user.battler.takesIndirectDamage?
      score -= (0.6 * (100 - move.rough_accuracy)).to_i   # -0 (100%) to -60 (1%) same as High Jump Kick and Jump Kick
    end
    next Battle::AI::Handlers.apply_move_effect_against_target_score("ConfuseTarget",
         score, move, user, target, ai, battle)
  }
)

#===============================================================================
# Glaive Rush
#===============================================================================
Battle::AI::Handlers::MoveEffectAgainstTargetScore.add("UserVulnerableUntilNextAction",
  proc { |score, move, user, target, ai, battle|
    if ai.trainer.high_skill?
      # Prefer if user can stall while damage is dealt
      if user.check_for_move { |m| m.is_a?(Battle::Move::ProtectMove) }
        score += 20
      end
    end
    next score
  }
)

# Prefer using protect move after using Glaive Rush
Battle::AI::Handlers::GeneralMoveScore.add(:protect_after_glaive_rush,
  proc { |score, move, user, ai, battle|
    if ai.trainer.high_skill? && user.effects[PBEffects::GlaiveRush] > 0
      protect_moves = [
        "ProtectUser",
        "ProtectUserBanefulBunker",
        "ProtectUserFromDamagingMovesKingsShield",
        "ProtectUserFromDamagingMovesObstruct",
        "ProtectUserFromTargetingMovesSpikyShield",
        "ProtectUserSideFromDamagingMovesIfUserFirstTurn",
        "ProtectUserFromTargetingMovesSpikyShield",
        "ProtectUserBurningBulwark"
      ]
      half_protect_moves = [
        "ProtectUserSideFromPriorityMoves",
        "ProtectUserSideFromMultiTargetDamagingMoves"
      ]
      if protect_moves.include?(move.function_code)
        score += 20
      elsif half_protect_moves.include?(move.function_code)
        score += 15
      end
    end
    next score
  }
)

#===============================================================================
# Gigaton Hammer
#===============================================================================
Battle::AI::Handlers::MoveFailureCheck.add("CantSelectConsecutiveTurns",
  proc { |move, user, ai, battle|
    next true if user.effects[PBEffects::SuccessiveMove] == @id
    next false
  }
)
Battle::AI::Handlers::MoveEffectAgainstTargetScore.add("CantSelectConsecutiveTurns",
  proc { |score, move, user, target, ai, battle|
    if user.battler.hasActiveItem?([:CHOICEBAND, :CHOICESPECS, :CHOICESCARF]) ||
       user.battler.hasActiveAbility?(:GORILLATACTICS) || user.effects[PBEffects::Encore] > 0
     score -= 40
    end
    next score
  }
)

#===============================================================================
# Make it Rain
#===============================================================================
Battle::AI::Handlers::MoveEffectScore.copy("LowerUserSpAtk1",
                                           "AddMoneyGainedFromBattleLowerUserSpAtk1")

#===============================================================================
# Double Shock
#===============================================================================
Battle::AI::Handlers::MoveFailureCheck.add("UserLosesElectricType",
  proc { |move, user, ai, battle|
    next !user.has_type?(:ELECTRIC)
  }
)

#===============================================================================
# Salt Cure
#===============================================================================
Battle::AI::Handlers::MoveFailureCheck.add("StartSaltCureTarget",
  proc { |move, user, ai, battle|
    next false if move.damagingMove?
    next target.effects[PBEffects::SaltCure]
  }
)
Battle::AI::Handlers::MoveEffectAgainstTargetScore.add("StartSaltCureTarget",
  proc { |score, move, user, target, ai, battle|
    # Prefer early on
    score += 20 if target.turnCount < 2
    # Target will take damage at the end of each round from the salt cure
    score += 10 if target.battler.takesIndirectDamage?
    eor_damage = target.rough_end_of_round_damage
    if eor_damage > 0
      # Prefer if the target will take damage at the end of each round on top
      # of salt cure damage
      score += 10
    elsif eor_damage < 0
      # Don't prefer if the target will heal itself at the end of each round
      score -= 10
    end
    if ai.trainer.medium_skill?
      # Prefer if the user has no damaging moves
      score += 10 if !user.check_for_move { |m| m.damagingMove? }
      # Prefer if the target can't switch out to remove its salt cure
      score += 8 if !battle.pbCanChooseNonActive?(target.index)
    end
    if ai.trainer.high_skill?
      # Prefer if user can stall while damage is dealt
      if user.check_for_move { |m| m.is_a?(Battle::Move::ProtectMove) }
        score += 10
      end
    end
    next score
  }
)

#===============================================================================
# Silk Trap
#===============================================================================
Battle::AI::Handlers::MoveEffectScore.add("ProtectUserFromDamagingMovesSilkTrap",
  proc { |score, move, user, ai, battle|
    # Useless if the success chance is 25% or lower
    next Battle::AI::MOVE_USELESS_SCORE if user.effects[PBEffects::ProtectRate] >= 4
    # Score changes for each foe
    useless = true
    ai.each_foe_battler(user.side) do |b, i|
      next if !b.can_attack?
      next if !b.check_for_move { |m| m.damagingMove? && m.canProtectAgainst? }
      next if b.has_active_ability?(:UNSEENFIST) && b.check_for_move { |m| m.contactMove? }
      useless = false
      # General preference
      score += 7
      # Prefer if the foe's Speed can be lowered by this move
      if b.battler.affectedByContactEffect? && b.check_for_move { |m| m.contactMove? }
        drop_score = ai.get_score_for_target_stat_drop(0, b, [:SPEED, 1], false)
        score += drop_score / 2   # Halved because we don't know what move b will use
      end
      # Prefer if the foe is in the middle of using a two turn attack
      score += 15 if b.effects[PBEffects::TwoTurnAttack] &&
                     GameData::Move.get(b.effects[PBEffects::TwoTurnAttack]).flags.any? { |f| f[/^CanProtect$/i] }
      # Prefer if foe takes EOR damage, don't prefer if they have EOR healing
      b_eor_damage = b.rough_end_of_round_damage
      if b_eor_damage > 0
        score += 8
      elsif b_eor_damage < 0
        score -= 8
      end
    end
    next Battle::AI::MOVE_USELESS_SCORE if useless
    # Prefer if the user has EOR healing, don't prefer if they take EOR damage
    user_eor_damage = user.rough_end_of_round_damage
    if user_eor_damage >= user.hp
      next Battle::AI::MOVE_USELESS_SCORE
    elsif user_eor_damage > 0
      score -= 8
    elsif user_eor_damage < 0
      score += 8
    end
    # Don't prefer if the user used a protection move last turn, making this one
    # less likely to work
    score -= (user.effects[PBEffects::ProtectRate] - 1) * ((Settings::MECHANICS_GENERATION >= 6) ? 15 : 10)
    # Prefer if the user used Glaive Rush last turn
    score += 20 if user.effects[PBEffects::GlaiveRush] > 0
    next score
  }
)

#===============================================================================
# Order Up
#===============================================================================
Battle::AI::Handlers::MoveEffectAgainstTargetScore.add("RaiseUserStat1Commander",
  proc { |score, move, user, target, ai, battle|
    if user.battler.isCommanderHost?
      form = user.effects[PBEffects::Commander][1]
      stat = [:ATTACK, :DEFENSE, :SPEED][form]
      # Score for user's stat changes
      score = ai.get_score_for_target_stat_raise(score, user, [stat, 1], false)
    end
    next score
  }
)

#===============================================================================
# Spicy Extract
#===============================================================================
Battle::AI::Handlers::MoveFailureAgainstTargetCheck.add("RaiseTargetAtkLowerTargetDef2",
  proc { |move, user, target, ai, battle|
    will_fail = true
    (move.move.statUp.length / 2).times do |i|
      next if !target.battler.pbCanRaiseStatStage?(move.move.statUp[i * 2], target.battler, move.move)
      will_fail = false
      break
    end
    (move.move.statDown.length / 2).times do |i|
      next if !target.battler.pbCanLowerStatStage?(move.move.statDown[i * 2], target.battler, move.move)
      will_fail = false
      break
    end
    next will_fail
  }
)
Battle::AI::Handlers::MoveEffectAgainstTargetScore.add("RaiseTargetAtkLowerTargetDef2",
  proc { |score, move, user, target, ai, battle|
    # Score for target's stat changes
    score = ai.get_score_for_target_stat_raise(score, target, [:ATTACK, 2], false)
    score = ai.get_score_for_target_stat_drop(score, target, [:DEFENSE, 2], false)
    next score
  }
)

#===============================================================================
# Fillet Away
#===============================================================================
Battle::AI::Handlers::MoveFailureCheck.add("RaiseUserAtkSpAtkSpeed2LoseHalfOfTotalHP",
  proc { |move, user, ai, battle|
    next true if user.hp <= [user.totalhp / 2, 1].max
    failed = true
    [:ATTACK, :SPECIAL_ATTACK, :SPEED].each do |stat|
      next if !user.battler.pbCanRaiseStatStage?(stat, user.battler, move.move)
      failed = false
      break
    end
    next failed
  }
)
Battle::AI::Handlers::MoveEffectScore.add("RaiseUserAtkSpAtkSpeed2LoseHalfOfTotalHP",
  proc { |score, move, user, ai, battle|
    # Score for target's stat changes
    score = ai.get_score_for_target_stat_raise(score, user, [:ATTACK, 2, :SPECIAL_ATTACK, 2, :SPEED, 2])
    # Don't prefer the lower the user's HP is
    if ai.trainer.has_skill_flag?("HPAware")
      score -= 60 * (1 - (user.hp.to_f / user.totalhp))   # -0 to -30
    end
    next score
  }
)

#===============================================================================
# Tidy Up
#===============================================================================
Battle::AI::Handlers::MoveFailureAgainstTargetCheck.add("RaiseUserAtkSpd1RemoveHazardsSubstitutes",
  proc { |move, user, target, ai, battle|
    will_fail = true
    (move.move.statUp.length / 2).times do |i|
      next if !target.battler.pbCanRaiseStatStage?(move.move.statUp[i * 2], target.battler, move.move)
      will_fail = false
      break
    end
    2.times do |i|
      side = (i == 0) ? user.pbOwnSide : user.pbOpposingSide
      next unless side.effects[PBEffects::Spikes] > 0 ||
                  side.effects[PBEffects::ToxicSpikes] > 0 ||
                  side.effects[PBEffects::StealthRock] ||
                  side.effects[PBEffects::StickyWeb] ||
                  defined?(PBEffects::Steelsurge) && side.effects[PBEffects::Steelsurge]
      will_fail = false
      break
    end
    battle.allBattlers.each do |b|
      next if b.effects[PBEffects::Substitute] == 0
      will_fail = false
      break
    end
    next will_fail
  }
)
Battle::AI::Handlers::MoveEffectScore.add("RaiseUserAtkSpd1RemoveHazardsSubstitutes",
  proc { |score, move, user, ai, battle|
    # Score for raising user's Attack and Speed
    score = Battle::AI::Handlers.apply_move_effect_score("RaiseUserAtkSpd1",
       score, move, user, ai, battle)
    # Score for removing player side various hazards
    if battle.pbAbleNonActiveCount(user.idxOwnSide) > 0
      score += 15 if user.pbOwnSide.effects[PBEffects::Spikes] > 0
      score += 15 if user.pbOwnSide.effects[PBEffects::ToxicSpikes] > 0
      score += 20 if user.pbOwnSide.effects[PBEffects::StealthRock]
      score += 15 if user.pbOwnSide.effects[PBEffects::StickyWeb]
    end
    # Score for removing opponent side various hazards
    if battle.pbAbleNonActiveCount(user.idxOpposingSide) > 0
      score -= 15 if user.pbOpposingSide.effects[PBEffects::Spikes] > 0
      score -= 15 if user.pbOpposingSide.effects[PBEffects::ToxicSpikes] > 0
      score -= 20 if user.pbOpposingSide.effects[PBEffects::StealthRock]
      score -= 15 if user.pbOpposingSide.effects[PBEffects::StickyWeb]
    end
    # Prefer if foes have a substitute
    ai.each_foe_battler(user.side) do |b, i|
      next if b.effects[PBEffects::Substitute] == 0
      score += 10 if b.effects[PBEffects::Substitute] > 0
    end
    # Don't prefer if any allies have a substitute
    ai.each_same_side_battler(user.side) do |b, i|
      next if b.effects[PBEffects::Substitute] == 0
      score -= 10 if b.effects[PBEffects::Substitute] > 0
    end
    next score
  }
)

#===============================================================================
# Mortal Spin
#===============================================================================
Battle::AI::Handlers::MoveEffectScore.add("RemoveUserBindingAndEntryHazardsPoisonTarget",
  proc { |score, move, user, ai, battle|
    # Score for removing various effects
    score += 10 if user.effects[PBEffects::Trapping] > 0
    score += 15 if user.effects[PBEffects::LeechSeed] >= 0
    if battle.pbAbleNonActiveCount(user.idxOwnSide) > 0
      score += 15 if user.pbOwnSide.effects[PBEffects::Spikes] > 0
      score += 15 if user.pbOwnSide.effects[PBEffects::ToxicSpikes] > 0
      score += 20 if user.pbOwnSide.effects[PBEffects::StealthRock]
      score += 15 if user.pbOwnSide.effects[PBEffects::StickyWeb]
    end
    ai.each_foe_battler(user.side) do |b, i|
      # Prefer if the foe is likely to be poisoned by this move
      poison_score = Battle::AI::Handlers.apply_move_effect_against_target_score("PoisonTarget",
        0, move, user, b, ai, battle)
      score += poison_score if poison_score != Battle::AI::MOVE_USELESS_SCORE
    end
    next score
  }
)

#===============================================================================
# Ice Spinner
#===============================================================================
Battle::AI::Handlers::MoveEffectScore.copy("RemoveTerrain",
                                          "RemoveTerrainIceSpinner")

#===============================================================================
# Chilly Reception
#===============================================================================
Battle::AI::Handlers::MoveFailureCheck.add("SwitchOutUserStartHailWeather",
  proc { |move, user, ai, battle|
    cannot_switch = true
    if user.wild?
      cannot_switch = !battle.pbCanRun?(user.index) || user.battler.allAllies.length > 0
    end
    cannot_switch = !battle.pbCanChooseNonActive?(user.index) if cannot_switch
    cannot_switch = [:HarshSun, :HeavyRain, :StrongWinds, move.move.weatherType].include?(battle.field.weather) if cannot_switch
    next cannot_switch
  }
)
Battle::AI::Handlers::MoveEffectScore.add("SwitchOutUserStartHailWeather",
  proc { |score, move, user, ai, battle|
    switchout_score = Battle::AI::Handlers.apply_move_effect_against_target_score("SwitchOutUserStatusMove",
        0, move, user, b, ai, battle)
    score += switchout_score if switchout_score != Battle::AI::MOVE_USELESS_SCORE
    next Battle::AI::MOVE_USELESS_SCORE if switchout_score == Battle::AI::MOVE_USELESS_SCORE && 
                                          (battle.pbCheckGlobalAbility(:AIRLOCK) ||
                                           battle.pbCheckGlobalAbility(:CLOUDNINE))
    # Not worth it at lower HP
    if ai.trainer.has_skill_flag?("HPAware")
      score -= 10 if user.hp < user.totalhp / 2
    end
    if ai.trainer.high_skill? && battle.field.weather != :None
      score -= ai.get_score_for_weather(battle.field.weather, user)
    end
    score += ai.get_score_for_weather(:Hail, user, true)
    next score
  }
)

#===============================================================================
# Shed Tail
#===============================================================================
Battle::AI::Handlers::MoveFailureCheck.add("UserMakeSubstituteSwitchOut",
  proc { |move, user, ai, battle|
    next true if user.effects[PBEffects::Substitute] > 0
    next user.hp <= [user.totalhp / 2, 1].max
  }
)
Battle::AI::Handlers::MoveEffectScore.add("UserMakeSubstituteSwitchOut",
  proc { |score, move, user, ai, battle|
    # Switch out score
    switchout_score = Battle::AI::Handlers.apply_move_effect_against_target_score("SwitchOutUserStatusMove",
        0, move, user, b, ai, battle)
    score += switchout_score if switchout_score != Battle::AI::MOVE_USELESS_SCORE
    # Substitute score
    substitute_score = Battle::AI::Handlers.apply_move_effect_against_target_score("UserMakeSubstitute",
        0, move, user, b, ai, battle)
    score += substitute_score if substitute_score != Battle::AI::MOVE_USELESS_SCORE
    next score
  }
)

#===============================================================================
# Doodle
#===============================================================================
Battle::AI::Handlers::MoveFailureAgainstTargetCheck.add("SetUserAlliesAbilityToTargetAbility",
  proc { |move, user, target, ai, battle|
    will_fail = true
    battle.allSameSideBattlers(user.index).each do |b|
      next if b.ability != target.ability && !b.unstoppableAbility? &&
              b.has_active_item?(:ABILITYSHIELD)
      will_fail = false
      break
    end
    next true if will_fail
    next move.move.pbFailsAgainstTarget?(user.battler, target.battler, false)
  }
)
Battle::AI::Handlers::MoveEffectAgainstTargetScore.add("SetUserAlliesAbilityToTargetAbility",
  proc { |score, move, user, target, ai, battle|
    ai.each_same_side_battler(user.side) do |b, i|
      next if !b.ability_active?
      old_ability_rating = b.wants_ability?(b.ability_id)
      new_ability_rating = b.wants_ability?(target.ability_id)
      if old_ability_rating > new_ability_rating
        score += 5 * [old_ability_rating - new_ability_rating, 3].max
      elsif old_ability_rating < new_ability_rating
        score -= 5 * [new_ability_rating - old_ability_rating, 3].max
      end
    end
    next score
  }
)

#===============================================================================
# Revival Blessing
#===============================================================================
Battle::AI::Handlers::MoveFailureCheck.add("RevivePokemonHalfHP",
  proc { |move, user, ai, battle|
    next battle.pbParty(user.index).none? { |pkmn| pkmn&.fainted? }
  }
)
Battle::AI::Handlers::MoveEffectScore.add("RevivePokemonHalfHP",
  proc { |score, move, user, ai, battle|
    score = Battle::AI::MOVE_BASE_SCORE   # Ignore the scores for each targeted battler calculated earlier
    battle.pbParty(user.index).each do |pkmn|
      next if !pkmn || !pkmn.fainted?
      score += 12
    end
    next score
  }
)

#===============================================================================
# Blazing Torque
#===============================================================================
Battle::AI::Handlers::MoveFailureAgainstTargetCheck.copy("BurnTarget","StarmobileBurnTarget")
Battle::AI::Handlers::MoveEffectAgainstTargetScore.copy("BurnTarget","StarmobileBurnTarget")

#===============================================================================
# Combat Torque
#===============================================================================
Battle::AI::Handlers::MoveFailureAgainstTargetCheck.copy("ParalyzeTarget","StarmobileParalyzeTarget")
Battle::AI::Handlers::MoveEffectAgainstTargetScore.copy("ParalyzeTarget","StarmobileParalyzeTarget")

#===============================================================================
# Magical Torque
#===============================================================================
Battle::AI::Handlers::MoveFailureAgainstTargetCheck.copy("ConfuseTarget","StarmobileConfuseTarget")
Battle::AI::Handlers::MoveEffectAgainstTargetScore.copy("ConfuseTarget","StarmobileConfuseTarget")

#===============================================================================
# Noxious Torque
#===============================================================================
Battle::AI::Handlers::MoveFailureAgainstTargetCheck.copy("PoisonTarget","StarmobilePoisonTarget")
Battle::AI::Handlers::MoveEffectAgainstTargetScore.copy("PoisonTarget","StarmobilePoisonTarget")

#===============================================================================
# Wicked Torque
#===============================================================================
Battle::AI::Handlers::MoveFailureAgainstTargetCheck.copy("SleepTarget","StarmobileSleepTarget")
Battle::AI::Handlers::MoveEffectAgainstTargetScore.copy("SleepTarget","StarmobileSleepTarget")

#===============================================================================
# Hydro Steam
#===============================================================================
Battle::AI::Handlers::MoveEffectAgainstTargetScore.add("IncreasePowerInSunWeather",
proc { |score, move, user, target, ai, battle|
  score += 20 if [:Sun, :HarshSun].include?(user.battler.effectiveWeather)
  next score
}
)

#===============================================================================
# Psyblade
#===============================================================================
Battle::AI::Handlers::MoveEffectAgainstTargetScore.add("IncreasePowerInElectricTerrain",
  proc { |score, move, user, target, ai, battle|
    score += 20 if battle.field.terrain != :Electric
    next score
  }
)

#===============================================================================
# Matcha Gatcha
#===============================================================================
Battle::AI::Handlers::MoveEffectAgainstTargetScore.add("HealUserByHalfOfDamageDoneBurnTarget",
  proc { |score, move, user, target, ai, battle|
    rough_dmg = move.rough_damage
    if target.has_active_ability?(:LIQUIDOOZE)
      score -= 20 if rough_dmg < target.hp
    elsif user.battler.canHeal?
      score += 5 if user.has_active_item?(:BIGROOT)
      if ai.trainer.has_skill_flag?("HPAware")
        # Consider how much HP will be restored
        heal_amt = rough_dmg / 2
        heal_amt *= 1.3 if user.has_active_item?(:BIGROOT)
        heal_amt = [heal_amt, user.totalhp - user.hp].min
        if heal_amt > user.totalhp * 0.3   # Only modify the score if it'll heal a decent amount
          if user.hp < user.totalhp * 0.5
            score += 20 * (user.totalhp - user.hp) / user.totalhp   # +10 to +20
          end
          score += 20 * heal_amt / user.totalhp   # +6 to +20
        end
      end
    end
    # burn score
    burn_score = Battle::AI::Handlers.apply_move_effect_against_target_score("BurnTarget",
      0, move, user, b, ai, battle)
    if burn_score != Battle::AI::MOVE_USELESS_SCORE
      score += burn_score if burn_score != Battle::AI::MOVE_USELESS_SCORE
    end

    next score
  }
)

#===============================================================================
# Syrup Bomb
#===============================================================================
Battle::AI::Handlers::MoveEffectAgainstTargetScore.add("HealUserByHalfOfDamageDoneBurnTarget",
  proc { |score, move, user, target, ai, battle|
    stage_amt = Battle::Battler::STAT_STAGE_MAXIMUM - [target.effects[PBEffects::Syrupy],3].max
    score += 5 * stage_amt
    next score
  }
)

#===============================================================================
# Electro Shot
#===============================================================================
Battle::AI::Handlers::MoveEffectAgainstTargetScore.add("TwoTurnAttackOneTurnInRainRaiseUserSpAtk1",
  proc { |score, move, user, target, ai, battle|
    # In sunny weather this a 1 turn move, the same as a move with no effect
    next score if [:Rain, :HeavyRain].include?(user.battler.effectiveWeather)
    # Score for being a two turn attack
    next Battle::AI::Handlers.apply_move_effect_against_target_score("TwoTurnAttack",
       score, move, user, target, ai, battle)
  }
)

#===============================================================================
# Burning Bulwark
#===============================================================================
Battle::AI::Handlers::MoveEffectScore.add("ProtectUserBanefulBunker",
  proc { |score, move, user, ai, battle|
    # Useless if the success chance is 25% or lower
    next Battle::AI::MOVE_USELESS_SCORE if user.effects[PBEffects::ProtectRate] >= 4
    # Score changes for each foe
    useless = true
    ai.each_foe_battler(user.side) do |b, i|
      next if !b.can_attack?
      next if !b.check_for_move { |m| m.canProtectAgainst? }
      next if b.has_active_ability?(:UNSEENFIST) && b.check_for_move { |m| m.contactMove? }
      useless = false
      # General preference
      score += 7
      # Prefer if the foe is likely to be burned by this move
      if b.check_for_move { |m| m.contactMove? }
        burn_score = Battle::AI::Handlers.apply_move_effect_against_target_score("BurnTarget",
           0, move, user, b, ai, battle)
        if burn_score != Battle::AI::MOVE_USELESS_SCORE
          score += burn_score / 2   # Halved because we don't know what move b will use
        end
      end
      # Prefer if the foe is in the middle of using a two turn attack
      score += 15 if b.effects[PBEffects::TwoTurnAttack] &&
                     GameData::Move.get(b.effects[PBEffects::TwoTurnAttack]).flags.any? { |f| f[/^CanProtect$/i] }
      # Prefer if foe takes EOR damage, don't prefer if they have EOR healing
      b_eor_damage = b.rough_end_of_round_damage
      if b_eor_damage > 0
        score += 8
      elsif b_eor_damage < 0
        score -= 8
      end
    end
    next Battle::AI::MOVE_USELESS_SCORE if useless
    # Prefer if the user has EOR healing, don't prefer if they take EOR damage
    user_eor_damage = user.rough_end_of_round_damage
    if user_eor_damage >= user.hp
      next Battle::AI::MOVE_USELESS_SCORE
    elsif user_eor_damage > 0
      score -= 8
    elsif user_eor_damage < 0
      score += 8
    end
    # Don't prefer if the user used a protection move last turn, making this one
    # less likely to work
    score -= (user.effects[PBEffects::ProtectRate] - 1) * ((Settings::MECHANICS_GENERATION >= 6) ? 15 : 10)
    next score
  }
)

#===============================================================================
# Dragon Cheer
#===============================================================================
Battle::AI::Handlers::MoveFailureAgainstTargetCheck.add("RaiseAlliesCriticalHitRate1DragonTypes2",
  proc { |move, user, target, ai, battle|
    noTargets = true
    battle.allSameSideBattlers(user).each do |b|
      next if b.index == user.index
      next if b.effects[PBEffects::FocusEnergy] > 0
      noTargets = false
      break
    end
    next noTargets
  }
)

Battle::AI::Handlers::MoveEffectScore.add("RaiseAlliesCriticalHitRate1DragonTypes2",
  proc { |score, move, user, ai, battle|
    battle.allSameSideBattlers(user).each do |b|
      next if b.index == user.index
      next if b.effects[PBEffects::FocusEnergy] > 0
      score += 10
      if ai.trainer.medium_skill?
        # If allies are a dragon type
        score += 10 if b.has_type?(:DRAGON)
        # Other effects that raise the critical hit rate
        if b.item_active?
          if [:RAZORCLAW, :SCOPELENS].include?(b.item_id) ||
             (b.item_id == :LUCKYPUNCH && b.battler.isSpecies?(:CHANSEY)) ||
             ([:LEEK, :STICK].include?(b.item_id) &&
             (b.battler.isSpecies?(:FARFETCHD) || b.battler.isSpecies?(:SIRFETCHD)))
            score += 5
          end
        end
        # Critical hits do more damage
        score += 5 if b.has_active_ability?(:SNIPER)
      end
    end
    next score
  }
)

#===============================================================================
# Alluring Voice
#===============================================================================
Battle::AI::Handlers::MoveEffectAgainstTargetScore.add("ConfuseTargetIfTargetStatsRaisedThisTurn",
  proc { |score, move, user, target, ai, battle|
    # Return score if target stats haven't raised this turn or target cannot become confused
    next score if !target.battler.statsRaisedThisRound || !target.battler.pbCanConfuse?(user.battler, false, move.move)
    # Score for confusing the target
    score += Battle::AI::Handlers.apply_move_effect_against_target_score(
             "ConfuseTarget", score, move, user, target, ai, battle)
    next score
  }
)

#===============================================================================
# Hard Press
#===============================================================================
Battle::AI::Handlers::MoveBasePower.copy("PowerHigherWithUserHP",
                                         "PowerHigherWithTargetHP100PowerRange")

#===============================================================================
# Supercell Slam
#===============================================================================
Battle::AI::Handlers::MoveEffectAgainstTargetScore.add("CrashDamageIfFails",
  proc { |score, move, user, target, ai, battle|
    next Battle::AI::Handlers.apply_move_effect_against_target_score(
         "CrashDamageIfFailsUnusableInGravity", score, move, user, target, ai, battle)
  }
)

#===============================================================================
# Psychic Noise
#===============================================================================
Battle::AI::Handlers::MoveFailureAgainstTargetCheck.add("DisableTargetHealingMoves2Turns",
  proc { |move, user, target, ai, battle|
    next true if target.effects[PBEffects::HealBlock] > 0
    next true if move.move.pbMoveFailedAromaVeil?(user.battler, target.battler, false)
    next false
  }
)

Battle::AI::Handlers::MoveEffectAgainstTargetScore.add("DisableTargetHealingMoves2Turns",
  proc { |score, move, user, target, ai, battle|
    # If the foe can heal themselves with a move or some held items
    if target.check_for_move { |m| m.healingMove? } || target.has_active_item?(:LEFTOVERS) ||
       (target.has_active_item?(:BLACKSLUDGE) && target.has_type?(:POISON))
      score += 10
    end
    next score
  }
)


#===============================================================================
# Upper Hand
#===============================================================================
Battle::AI::Handlers::MoveEffectAgainstTargetScore.add("FlinchTargetFailsIfTargetNotUsingPriorityMove",
  proc { |score, move, user, target, ai, battle|
    # Check whether user is faster than the target and could use this move
    next Battle::AI::MOVE_USELESS_SCORE if target.faster_than?(user)
    # Check whether the target has any damaging moves it could use
    next Battle::AI::MOVE_USELESS_SCORE if !target.check_for_move { |m| m.damagingMove? && m.priority > 0 }
    # Don't risk using this move if target is weak
    if ai.trainer.has_skill_flag?("HPAware")
      score -= 10 if target.hp <= target.totalhp / 2
      score -= 10 if target.hp <= target.totalhp / 4
    end
    next score
  }
)