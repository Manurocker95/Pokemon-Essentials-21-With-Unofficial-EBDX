#===============================================================================
# AI Ability ranking handlers.
#===============================================================================
Battle::AI::Handlers::AbilityRanking.add(:ROCKYPAYLOAD,
  proc { |ability, score, battler, ai|
    next score if battler.has_damaging_move_of_type?(:ROCK)
    next 0
  }
)

Battle::AI::Handlers::AbilityRanking.add(:SHARPNESS,
  proc { |ability, score, battler, ai|
    next score if battler.check_for_move { |m| m.slicingMove? }
    next 0
  }
)

Battle::AI::Handlers::AbilityRanking.add(:SUPREMEOVERLORD,
  proc { |ability, score, battler, ai|
    next battler.effects[PBEffects::SupremeOverlord]
  }
)

Battle::AI::Handlers::AbilityRanking.add(:ANGERSHELL,
  proc { |ability, score, battler, ai|
    next score if battler.hp > battler.totalhp/2
    next 0
  }
)

Battle::AI::Handlers::AbilityRanking.add(:CUDCHEW,
  proc { |ability, score, battler, ai|
    next score if battler.item && battler.item.is_berry?
    next 0
  }
)

Battle::AI::Handlers::AbilityRanking.add(:ORICHALCUMPULSE,
  proc { |ability, score, battler, ai|
    next score if battler.check_for_move { |m| m.physicalMove? && [:Sun, :HarshSun].include?(battler.battler.effectiveWeather) }
    next score - 1
  }
)

Battle::AI::Handlers::AbilityRanking.add(:HADRONENGINE,
  proc { |ability, score, battler, ai|
    next score if battler.check_for_move { |m| m.specialMove? && battler.battler.battle.field.terrain == :Electric }
    next score - 1
  }
)

Battle::AI::Handlers::AbilityRanking.add(:POISONPUPPETEER,
  proc { |ability, score, battler, ai|
    next score if battler.check_for_move do |m|
      m.is_a?(Battle::Move::PoisonTarget) ||
      m.is_a?(Battle::Move::BadPoisonTarget) ||
      m.is_a?(Battle::Move::PoisonTargetLowerTargetSpeed1) ||                # Toxic Thread
      m.is_a?(Battle::Move::CategoryDependsOnHigherDamagePoisonTarget) ||    # Shell Side Arm
      m.is_a?(Battle::Move::HitTwoTimesPoisonTarget) ||                      # Twin Needle
      m.is_a?(Battle::Move::DoublePowerIfTargetPoisonedPoisonTarget) ||      # Barb Barrage
      m.is_a?(Battle::Move::RemoveUserBindingAndEntryHazardsPoisonTarget) || # Mortal Spin
      m.is_a?(Battle::Move::StarmobilePoisonTarget) ||                       # Noxious Torque
      m.is_a?(Battle::Move::ProtectUserBanefulBunker) ||                     # Baneful Bunker
      m.is_a?(Battle::Move::PoisonParalyzeOrSleepTarget)                     # Dire Claw
    end
    next 0
  }
)
