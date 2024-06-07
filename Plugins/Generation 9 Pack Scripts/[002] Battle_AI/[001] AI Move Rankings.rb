#===============================================================================
# SleepTarget
#===============================================================================
# Add score modifier for Infernal Parade
Battle::AI::Handlers::MoveEffectAgainstTargetScore.add("SleepTarget",
  proc { |score, move, user, target, ai, battle|
    useless_score = (move.statusMove?) ? Battle::AI::MOVE_USELESS_SCORE : score
    next useless_score if target.effects[PBEffects::Yawn] > 0   # Target is going to fall asleep anyway
    # No score modifier if the sleep will be removed immediately
    next useless_score if target.has_active_item?([:CHESTOBERRY, :LUMBERRY])
    next useless_score if target.faster_than?(user) &&
                          target.has_active_ability?(:HYDRATION) &&
                          [:Rain, :HeavyRain].include?(target.battler.effectiveWeather)
    if target.battler.pbCanSleep?(user.battler, false, move.move)
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
# PoisonTarget
#===============================================================================
# Add score modifier for Barb Barrage and Infernal Parade
Battle::AI::Handlers::MoveEffectAgainstTargetScore.add("PoisonTarget",
  proc { |score, move, user, target, ai, battle|
    useless_score = (move.statusMove?) ? Battle::AI::MOVE_USELESS_SCORE : score
    next useless_score if target.has_active_ability?(:POISONHEAL)
    # No score modifier if the poisoning will be removed immediately
    next useless_score if target.has_active_item?([:PECHABERRY, :LUMBERRY])
    next useless_score if target.faster_than?(user) &&
                          target.has_active_ability?(:HYDRATION) &&
                          [:Rain, :HeavyRain].include?(target.battler.effectiveWeather)
    if target.battler.pbCanPoison?(user.battler, false, move.move)
      add_effect = move.get_score_change_for_additional_effect(user, target)
      next useless_score if add_effect == -999   # Additional effect will be negated
      score += add_effect
      # Inherent preference
      score += 15
      # Prefer if the target is at high HP
      if ai.trainer.has_skill_flag?("HPAware")
        score += 15 * target.hp / target.totalhp
      end
      # Prefer if the user or an ally has a move/ability that is better if the target is poisoned
      ai.each_same_side_battler(user.side) do |b, i|
        score += 5 if b.has_move_with_function?("DoublePowerIfTargetPoisoned",
                                                "DoublePowerIfTargetStatusProblem",
                                                "DoublePowerIfTargetPoisonedPoisonTarget",
                                                "DoublePowerIfTargetStatusProblemBurnTarget")
        score += 10 if b.has_active_ability?(:MERCILESS)
      end
      # Don't prefer if target benefits from having the poison status problem
      score -= 8 if target.has_active_ability?([:GUTS, :MARVELSCALE, :QUICKFEET, :TOXICBOOST])
      score -= 25 if target.has_active_ability?(:POISONHEAL)
      score -= 20 if target.has_active_ability?(:SYNCHRONIZE) &&
                     user.battler.pbCanPoisonSynchronize?(target.battler)
      score -= 5 if target.has_move_with_function?("DoublePowerIfUserPoisonedBurnedParalyzed",
                                                   "CureUserBurnPoisonParalysis")
      score -= 15 if target.check_for_move { |m|
        m.function_code == "GiveUserStatusToTarget" && user.battler.pbCanPoison?(target.battler, false, m)
      }
      # Don't prefer if the target won't take damage from the poison
      score -= 20 if !target.battler.takesIndirectDamage?
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
# ParalyzeTarget
#===============================================================================
# Add score modifier for Infernal Parade
Battle::AI::Handlers::MoveEffectAgainstTargetScore.add("ParalyzeTarget",
  proc { |score, move, user, target, ai, battle|
    useless_score = (move.statusMove?) ? Battle::AI::MOVE_USELESS_SCORE : score
    # No score modifier if the paralysis will be removed immediately
    next useless_score if target.has_active_item?([:CHERIBERRY, :LUMBERRY])
    next useless_score if target.faster_than?(user) &&
                          target.has_active_ability?(:HYDRATION) &&
                          [:Rain, :HeavyRain].include?(target.battler.effectiveWeather)
    if target.battler.pbCanParalyze?(user.battler, false, move.move)
      add_effect = move.get_score_change_for_additional_effect(user, target)
      next useless_score if add_effect == -999   # Additional effect will be negated
      score += add_effect
      # Inherent preference (because of the chance of full paralysis)
      score += 10
      # Prefer if the target is faster than the user but will become slower if
      # paralysed
      if target.faster_than?(user)
        user_speed = user.rough_stat(:SPEED)
        target_speed = target.rough_stat(:SPEED)
        score += 15 if target_speed < user_speed * ((Settings::MECHANICS_GENERATION >= 7) ? 2 : 4)
      end
      # Prefer if the target is confused or infatuated, to compound the turn skipping
      score += 7 if target.effects[PBEffects::Confusion] > 1
      score += 7 if target.effects[PBEffects::Attract] >= 0
      # Prefer if the user or an ally has a move/ability that is better if the target is paralysed
      ai.each_same_side_battler(user.side) do |b, i|
        score += 5 if b.has_move_with_function?("DoublePowerIfTargetParalyzedCureTarget",
                                                "DoublePowerIfTargetStatusProblem",
                                                "DoublePowerIfTargetStatusProblemBurnTarget")
      end
      # Don't prefer if target benefits from having the paralysis status problem
      score -= 8 if target.has_active_ability?([:GUTS, :MARVELSCALE, :QUICKFEET])
      score -= 20 if target.has_active_ability?(:SYNCHRONIZE) &&
                     user.battler.pbCanParalyzeSynchronize?(target.battler)
      score -= 5 if target.has_move_with_function?("DoublePowerIfUserPoisonedBurnedParalyzed",
                                                   "CureUserBurnPoisonParalysis")
      score -= 15 if target.check_for_move { |m|
        m.function_code == "GiveUserStatusToTarget" && user.battler.pbCanParalyze?(target.battler, false, m)
      }
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
# BurnTarget
#===============================================================================
# Add score modifier for Infernal Parade
Battle::AI::Handlers::MoveEffectAgainstTargetScore.add("BurnTarget",
  proc { |score, move, user, target, ai, battle|
    useless_score = (move.statusMove?) ? Battle::AI::MOVE_USELESS_SCORE : score
    # No score modifier if the burn will be removed immediately
    next useless_score if target.has_active_item?([:RAWSTBERRY, :LUMBERRY])
    next useless_score if target.faster_than?(user) &&
                          target.has_active_ability?(:HYDRATION) &&
                          [:Rain, :HeavyRain].include?(target.battler.effectiveWeather)
    if target.battler.pbCanBurn?(user.battler, false, move.move)
      add_effect = move.get_score_change_for_additional_effect(user, target)
      next useless_score if add_effect == -999   # Additional effect will be negated
      score += add_effect
      # Inherent preference
      score += 15
      # Prefer if the target knows any physical moves that will be weaked by a burn
      if !target.has_active_ability?(:GUTS) && target.check_for_move { |m| m.physicalMove? }
        score += 8
        score += 8 if !target.check_for_move { |m| m.specialMove? }
      end
      # Prefer if the user or an ally has a move/ability that is better if the target is burned
      ai.each_same_side_battler(user.side) do |b, i|
        score += 5 if b.has_move_with_function?("DoublePowerIfTargetStatusProblem",
                                                "DoublePowerIfTargetStatusProblemBurnTarget")
      end
      # Don't prefer if target benefits from having the burn status problem
      score -= 8 if target.has_active_ability?([:FLAREBOOST, :GUTS, :MARVELSCALE, :QUICKFEET])
      score -= 5 if target.has_active_ability?(:HEATPROOF)
      score -= 20 if target.has_active_ability?(:SYNCHRONIZE) &&
                     user.battler.pbCanBurnSynchronize?(target.battler)
      score -= 5 if target.has_move_with_function?("DoublePowerIfUserPoisonedBurnedParalyzed",
                                                   "CureUserBurnPoisonParalysis")
      score -= 15 if target.check_for_move { |m|
        m.function_code == "GiveUserStatusToTarget" && user.battler.pbCanBurn?(target.battler, false, m)
      }
      # Don't prefer if the target won't take damage from the burn
      score -= 20 if !target.battler.takesIndirectDamage?
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
# FreezeTarget
#===============================================================================
# Add score modifier for Infernal Parade
Battle::AI::Handlers::MoveEffectAgainstTargetScore.add("FreezeTarget",
  proc { |score, move, user, target, ai, battle|
    useless_score = (move.statusMove?) ? Battle::AI::MOVE_USELESS_SCORE : score
    # No score modifier if the freeze will be removed immediately
    next useless_score if target.has_active_item?([:ASPEARBERRY, :LUMBERRY])
    next useless_score if target.faster_than?(user) &&
                          target.has_active_ability?(:HYDRATION) &&
                          [:Rain, :HeavyRain].include?(target.battler.effectiveWeather)
    if target.battler.pbCanFreeze?(user.battler, false, move.move)
      add_effect = move.get_score_change_for_additional_effect(user, target)
      next useless_score if add_effect == -999   # Additional effect will be negated
      score += add_effect
      # Inherent preference
      score += 15
      # Prefer if the user or an ally has a move/ability that is better if the target is frozen
      ai.each_same_side_battler(user.side) do |b, i|
        score += 5 if b.has_move_with_function?("DoublePowerIfTargetStatusProblem",
                                                "DoublePowerIfTargetStatusProblemBurnTarget")
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

#===============================================================================
# Roar, Whirlwind
#===============================================================================
# Add score modifier for Zero to Hero
Battle::AI::Handlers::MoveEffectAgainstTargetScore.add("SwitchOutTargetStatusMove",
  proc { |score, move, user, target, ai, battle|
    # Ends the battle - generally don't prefer (don't want to end the battle too easily)
    next score - 10 if target.wild?
    # Switches the target out
    next Battle::AI::MOVE_USELESS_SCORE if target.effects[PBEffects::PerishSong] > 0
    # Don't prefer if target is at low HP and could be knocked out instead
    if ai.trainer.has_skill_flag?("HPAware")
      score -= 10 if target.hp <= target.totalhp / 3
    end
    # Consider the target's stat stages
    if target.stages.any? { |key, val| val >= 2 }
      score += 15
    elsif target.stages.any? { |key, val| val < 0 }
      score -= 15
    end
    # Consider the target's end of round damage/healing
    eor_damage = target.rough_end_of_round_damage
    score -= 15 if eor_damage > 0
    score += 15 if eor_damage < 0
    # Prefer if the target's side has entry hazards on it
    score += 10 if target.pbOwnSide.effects[PBEffects::Spikes] > 0
    score += 10 if target.pbOwnSide.effects[PBEffects::ToxicSpikes] > 0
    score += 10 if target.pbOwnSide.effects[PBEffects::StealthRock]
    # Don't prefer if the target switching out will change its form
    score -= 20 if target.has_active_ability?(:ZEROTOHERO) && target.battler.form == 0
    next score
  }
)

#===============================================================================
# Teleport (Gen 8+)
#===============================================================================
# Add score modifier for Zero to Hero
Battle::AI::Handlers::MoveEffectScore.add("SwitchOutUserStatusMove",
  proc { |score, move, user, ai, battle|
    # Wild Pokémon run from battle - generally don't prefer (don't want to end the battle too easily)
    next score - 20 if user.wild?
    # Trainer-owned Pokémon switch out
    if ai.trainer.has_skill_flag?("ReserveLastPokemon") && battle.pbTeamAbleNonActiveCount(user.index) == 1
      next Battle::AI::MOVE_USELESS_SCORE   # Don't switch in ace
    end
    # Prefer if the user switching out will lose a negative effect
    score += 20 if user.effects[PBEffects::PerishSong] > 0
    score += 10 if user.effects[PBEffects::Confusion] > 1
    score += 10 if user.effects[PBEffects::Attract] >= 0
    # Prefer if the user switching out will change its form
    score += 20 if user.has_active_ability?(:ZEROTOHERO) && user.battler.form == 0
    # Consider the user's stat stages
    if user.stages.any? { |key, val| val >= 2 }
      score -= 15
    elsif user.stages.any? { |key, val| val < 0 }
      score += 10
    end
    # Consider the user's end of round damage/healing
    eor_damage = user.rough_end_of_round_damage
    score += 15 if eor_damage > 0
    score -= 15 if eor_damage < 0
    # Prefer if the user doesn't have any damaging moves
    score += 10 if !user.check_for_move { |m| m.damagingMove? }
    # Don't prefer if the user's side has entry hazards on it
    score -= 10 if user.pbOwnSide.effects[PBEffects::Spikes] > 0
    score -= 10 if user.pbOwnSide.effects[PBEffects::ToxicSpikes] > 0
    score -= 10 if user.pbOwnSide.effects[PBEffects::StealthRock]
    next score
  }
)

#===============================================================================
# Flip Turn, U-turn, Volt Switch
#===============================================================================
# Add score modifier for Zero to Hero
Battle::AI::Handlers::MoveEffectScore.add("SwitchOutUserDamagingMove",
  proc { |score, move, user, ai, battle|
    next score if !battle.pbCanChooseNonActive?(user.index)
    # Don't want to switch in ace
    score -= 20 if ai.trainer.has_skill_flag?("ReserveLastPokemon") &&
                   battle.pbTeamAbleNonActiveCount(user.index) == 1
    # Prefer if the user switching out will lose a negative effect
    score += 20 if user.effects[PBEffects::PerishSong] > 0
    score += 10 if user.effects[PBEffects::Confusion] > 1
    score += 10 if user.effects[PBEffects::Attract] >= 0
    # Prefer if the user switching out will change its form
    score += 20 if user.has_active_ability?(:ZEROTOHERO) && user.battler.form == 0
    # Consider the user's stat stages
    if user.stages.any? { |key, val| val >= 2 }
      score -= 15
    elsif user.stages.any? { |key, val| val < 0 }
      score += 10
    end
    # Consider the user's end of round damage/healing
    eor_damage = user.rough_end_of_round_damage
    score += 15 if eor_damage > 0
    score -= 15 if eor_damage < 0
    # Don't prefer if the user's side has entry hazards on it
    score -= 10 if user.pbOwnSide.effects[PBEffects::Spikes] > 0
    score -= 10 if user.pbOwnSide.effects[PBEffects::ToxicSpikes] > 0
    score -= 10 if user.pbOwnSide.effects[PBEffects::StealthRock]
    next score
  }
)
#===============================================================================
# Parting Shot
#===============================================================================
# Add score modifier for Zero to Hero
Battle::AI::Handlers::MoveEffectScore.add("LowerTargetAtkSpAtk1SwitchOutUser",
  proc { |score, move, user, ai, battle|
    next score if !battle.pbCanChooseNonActive?(user.index)
    # Prefer if the user switching out will change its form
    score += 20 if user.has_active_ability?(:ZEROTOHERO) && user.battler.form == 0
    next score
  }
)
#===============================================================================
# Baton Pass
#===============================================================================
# Add score modifier for Zero to Hero
Battle::AI::Handlers::MoveEffectScore.add("SwitchOutUserPassOnEffects",
  proc { |score, move, user, ai, battle|
    # Don't want to switch in ace
    score -= 20 if ai.trainer.has_skill_flag?("ReserveLastPokemon") &&
                   battle.pbTeamAbleNonActiveCount(user.index) == 1
    # Don't prefer if the user will pass on a negative effect
    score -= 10 if user.effects[PBEffects::Confusion] > 1
    score -= 15 if user.effects[PBEffects::Curse]
    score -= 10 if user.effects[PBEffects::Embargo] > 1
    score -= 15 if user.effects[PBEffects::GastroAcid]
    score -= 10 if user.effects[PBEffects::HealBlock] > 1
    score -= 10 if user.effects[PBEffects::LeechSeed] >= 0
    score -= 20 if user.effects[PBEffects::PerishSong] > 0
    # Prefer if the user will pass on a positive effect
    score += 10 if user.effects[PBEffects::AquaRing]
    score += 10 if user.effects[PBEffects::FocusEnergy] > 0
    score += 10 if user.effects[PBEffects::Ingrain]
    score += 8 if user.effects[PBEffects::MagnetRise] > 1
    score += 10 if user.effects[PBEffects::Substitute] > 0
    # Consider the user's stat stages
    if user.stages.any? { |key, val| val >= 4 }
      score += 25
    elsif user.stages.any? { |key, val| val >= 2 }
      score += 15
    elsif user.stages.any? { |key, val| val < 0 }
      score -= 15
    end
    # Consider the user's end of round damage/healing
    eor_damage = user.rough_end_of_round_damage
    score += 15 if eor_damage > 0
    score -= 15 if eor_damage < 0
    # Prefer if the user doesn't have any damaging moves
    score += 15 if !user.check_for_move { |m| m.damagingMove? }
    # Don't prefer if the user's side has entry hazards on it
    score -= 10 if user.pbOwnSide.effects[PBEffects::Spikes] > 0
    score -= 10 if user.pbOwnSide.effects[PBEffects::ToxicSpikes] > 0
    score -= 10 if user.pbOwnSide.effects[PBEffects::StealthRock]
    # Prefer if the user switching out will change its form
    score += 20 if user.has_active_ability?(:ZEROTOHERO) && user.battler.form == 0
    next score
  }
)

#===============================================================================
# Circle Throw, Dragon Tail
#===============================================================================
# Add score modifier for Guard Dog and Zero to Hero
Battle::AI::Handlers::MoveEffectAgainstTargetScore.add("SwitchOutTargetDamagingMove",
  proc { |score, move, user, target, ai, battle|
    next score if target.wild?
    # No score modification if the target can't be made to switch out
    next score if !battle.moldBreaker && target.has_active_ability?([:SUCTIONCUPS,:GUARDDOG])
    next score if target.effects[PBEffects::Ingrain]
    # No score modification if the target can't be replaced
    can_switch = false
    battle.eachInTeamFromBattlerIndex(target.index) do |_pkmn, i|
      can_switch = battle.pbCanSwitchIn?(target.index, i)
      break if can_switch
    end
    next score if !can_switch
    # Not score modification if the target has a Substitute
    next score if target.effects[PBEffects::Substitute] > 0
    # Don't want to switch out the target if it will faint from Perish Song
    score -= 20 if target.effects[PBEffects::PerishSong] > 0
    # Consider the target's stat stages
    if target.stages.any? { |key, val| val >= 2 }
      score += 15
    elsif target.stages.any? { |key, val| val < 0 }
      score -= 15
    end
    # Consider the target's end of round damage/healing
    eor_damage = target.rough_end_of_round_damage
    score -= 15 if eor_damage > 0
    score += 15 if eor_damage < 0
    # Prefer if the target's side has entry hazards on it
    score += 10 if target.pbOwnSide.effects[PBEffects::Spikes] > 0
    score += 10 if target.pbOwnSide.effects[PBEffects::ToxicSpikes] > 0
    score += 10 if target.pbOwnSide.effects[PBEffects::StealthRock]
    # Don't prefer if the target switching out will change its form
    score -= 20 if target.has_active_ability?(:ZEROTOHERO) && target.battler.form == 0
    next score
  }
)

#===============================================================================
# Protect
#===============================================================================
# Add score modifier for Glaive Rush
Battle::AI::Handlers::MoveEffectScore.add("ProtectUser",
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
# Baneful Bunker
#===============================================================================
# Add score modifier for Glaive Rush
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
      # Prefer if the foe is likely to be poisoned by this move
      if b.check_for_move { |m| m.contactMove? }
        poison_score = Battle::AI::Handlers.apply_move_effect_against_target_score("PoisonTarget",
           0, move, user, b, ai, battle)
        if poison_score != Battle::AI::MOVE_USELESS_SCORE
          score += poison_score / 2   # Halved because we don't know what move b will use
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
    # Prefer if the user used Glaive Rush last turn
    score += 20 if user.effects[PBEffects::GlaiveRush] > 0
    next score
  }
)

#===============================================================================
# King Shield
#===============================================================================
# Add score modifier for Glaive Rush
Battle::AI::Handlers::MoveEffectScore.add("ProtectUserFromDamagingMovesKingsShield",
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
      # Prefer if the foe's Attack can be lowered by this move
      if b.battler.affectedByContactEffect? && b.check_for_move { |m| m.contactMove? }
        drop_score = ai.get_score_for_target_stat_drop(
           0, b, [:ATTACK, (Settings::MECHANICS_GENERATION >= 8) ? 1 : 2], false)
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
    # Aegislash
    score += 10 if user.battler.isSpecies?(:AEGISLASH) && user.battler.form == 1 &&
                   user.ability == :STANCECHANGE
    # Prefer if the user used Glaive Rush last turn
    score += 20 if user.effects[PBEffects::GlaiveRush] > 0
    next score
  }
)

#===============================================================================
# Obstruct
#===============================================================================
# Add score modifier for Glaive Rush
Battle::AI::Handlers::MoveEffectScore.add("ProtectUserFromDamagingMovesObstruct",
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
      # Prefer if the foe's Attack can be lowered by this move
      if b.battler.affectedByContactEffect? && b.check_for_move { |m| m.contactMove? }
        drop_score = ai.get_score_for_target_stat_drop(0, b, [:DEFENSE, 2], false)
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
# Spiky Shield
#===============================================================================
# Add score modifier for Glaive Rush
Battle::AI::Handlers::MoveEffectScore.add("ProtectUserFromTargetingMovesSpikyShield",
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
      # Prefer if this move will deal damage
      if b.battler.affectedByContactEffect? && b.check_for_move { |m| m.contactMove? }
        score += 5
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
# Quick Guard
#===============================================================================
# Add score modifier for Glaive Rush
Battle::AI::Handlers::MoveEffectScore.add("ProtectUserSideFromPriorityMoves",
  proc { |score, move, user, ai, battle|
    # Useless if the success chance is 25% or lower
    next Battle::AI::MOVE_USELESS_SCORE if user.effects[PBEffects::ProtectRate] >= 4
    # Score changes for each foe
    useless = true
    ai.each_foe_battler(user.side) do |b, i|
      next if !b.can_attack?
      next if !b.check_for_move { |m| m.pbPriority(b.battler) > 0 && m.canProtectAgainst? }
      useless = false
      # General preference
      score += 7
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
    score += 10 if user.effects[PBEffects::GlaiveRush] > 0
    next score
  }
)

#===============================================================================
# Wide Guard
#===============================================================================
# Add score modifier for Glaive Rush
Battle::AI::Handlers::MoveEffectScore.add("ProtectUserSideFromMultiTargetDamagingMoves",
  proc { |score, move, user, ai, battle|
    # Useless if the success chance is 25% or lower
    next Battle::AI::MOVE_USELESS_SCORE if user.effects[PBEffects::ProtectRate] >= 4
    # Score changes for each foe
    useless = true
    ai.each_battler do |b, i|
      next if b.index == user.index || !b.can_attack?
      next if !b.check_for_move { |m| (Settings::MECHANICS_GENERATION >= 7 || move.damagingMove?) &&
                                      m.pbTarget(b.battler).num_targets > 1 }
      useless = false
      # General preference
      score += 7
      # Prefer if foe takes EOR damage, don't prefer if they have EOR healing
      b_eor_damage = b.rough_end_of_round_damage
      if b_eor_damage > 0
        score += (b.opposes?(user)) ? 8 : -8
      elsif b_eor_damage < 0
        score -= (b.opposes?(user)) ? 8 : -8
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
# Wake-Up Slap
#===============================================================================
# Add Drowsy as a sleep
Battle::AI::Handlers::MoveEffectAgainstTargetScore.add("DoublePowerIfTargetAsleepCureTarget",
  proc { |score, move, user, target, ai, battle|
    if [:SLEEP, :DROWSY].include?(target.status) && target.statusCount > 1   # Will cure status
      if target.wants_status_problem?(target.status)
        score += 15
      else
        score -= 10
      end
    end
    next score
  }
)

#===============================================================================
# Rest
#===============================================================================
# Adds failure check with the Purifying Salt ability.
Battle::AI::Handlers::MoveFailureCheck.add("HealUserFullyAndFallAsleep",
  proc { |move, user, ai, battle|
    next true if user.battler.hasActiveAbility?(:PURIFYINGSALT)
    next true if !user.battler.canHeal?
    next true if user.battler.asleep?
    next true if !user.battler.pbCanSleep?(user.battler, false, move.move, true)
    next false
  }
)

#===============================================================================
# Ally Switch
#===============================================================================
# Allows Ally Switch to function like it does in Gen 9 if MECHANICS_GENERATION >= 9.
Battle::AI::Handlers::MoveFailureCheck.add("UserSwapsPositionsWithAlly",
  proc { |move, user, ai, battle|
    next true if Settings::MECHANICS_GENERATION >= 9 && user.effects[PBEffects::AllySwitch]
    next true if user.effects[PBEffects::Commander]
    num_targets = 0
    idxUserOwner = battle.pbGetOwnerIndexFromBattlerIndex(user.index)
    ai.each_ally(user.side) do |b, i|
      next if battle.pbGetOwnerIndexFromBattlerIndex(b.index) != idxUserOwner
      next if !b.battler.near?(user.battler)
      num_targets += 1
    end
    next num_targets != 1
  }
)

#===============================================================================
# Entrainment 
#===============================================================================
# Add target's Ability Shield check
Battle::AI::Handlers::MoveFailureAgainstTargetCheck.add("SetTargetAbilityToUserAbility",
  proc { |move, user, target, ai, battle|
    next true if target.battler.hasActiveItem?(:ABILITYSHIELD)
    next true if !user.ability || user.ability_id == target.ability_id
    next true if user.battler.ungainableAbility? ||
                 [:POWEROFALCHEMY, :RECEIVER, :TRACE].include?(user.ability_id)
    next move.move.pbFailsAgainstTarget?(user.battler, target.battler, false)
  }
)

#===============================================================================
# Skill Swap
#===============================================================================
# Adds Ability Shield immunity. Fails if user is holding an Ability Shield.
#-------------------------------------------------------------------------------
Battle::AI::Handlers::MoveFailureAgainstTargetCheck.add("UserTargetSwapAbilities",
  proc { |move, user, target, ai, battle|
    next true if user.battler.hasActiveItem?(:ABILITYSHIELD)
    next true if !user.ability || user.battler.unstoppableAbility? ||
                 user.battler.ungainableAbility? || user.ability_id == :WONDERGUARD
    next move.move.pbFailsAgainstTarget?(user.battler, target.battler, false)
  }
)

#===============================================================================
# OHKO moves
#===============================================================================
# Add Glaive Rush to score modifier
Battle::AI::Handlers::MoveEffectAgainstTargetScore.add("OHKO",
  proc { |score, move, user, target, ai, battle|
    # Don't prefer if the target has less HP and user has a non-OHKO damaging move
    if ai.trainer.has_skill_flag?("HPAware")
      if user.check_for_move { |m| m.damagingMove? && !m.is_a?(Battle::Move::OHKO) }
        score -= 12 if target.hp <= target.totalhp / 2
        score -= 8 if target.hp <= target.totalhp / 4
      end
    end
    score += 20 if target.effects[PBEffects::GlaiveRush] > 0
    next score
  }
)

Battle::AI::Handlers::MoveEffectAgainstTargetScore.copy("OHKO",
                                                        "OHKOIce")

Battle::AI::Handlers::MoveEffectAgainstTargetScore.copy("OHKO",
                                                        "OHKOHitsUndergroundTarget")

#===============================================================================
# Judgment
#===============================================================================
Battle::AI::Handlers::MoveEffectAgainstTargetScore.add("TypeDependsOnUserPlate",
proc { |score, move, user, target, ai, battle|
    # Prefer if the user has Legend Plate
    score += 20 if user.battler.hasLegendPlateJudgment?
    next score
  }
)