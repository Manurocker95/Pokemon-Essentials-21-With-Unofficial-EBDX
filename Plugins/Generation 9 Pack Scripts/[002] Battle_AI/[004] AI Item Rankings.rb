#===============================================================================
# AI Item ranking handlers.
#===============================================================================

Battle::AI::Handlers::ItemRanking.add(:ADAMANTCRYSTAL,
  proc { |item, score, battler, ai|
    next score if battler.battler.isSpecies?(:DIALGA) &&
                  battler.has_damaging_move_of_type?(:DRAGON, :STEEL)
    next 0
  }
)

Battle::AI::Handlers::ItemRanking.add(:LUSTROUSGLOBE,
  proc { |item, score, battler, ai|
  next score if battler.battler.isSpecies?(:PALKIA) &&
                battler.has_damaging_move_of_type?(:DRAGON, :WATER)
    next 0
  }
)

Battle::AI::Handlers::ItemRanking.add(:GRISEOUSCORE,
  proc { |item, score, battler, ai|
    next score if battler.battler.isSpecies?(:GIRATINA) &&
                  battler.has_damaging_move_of_type?(:DRAGON, :GHOST)
    next 0
  }
)

Battle::AI::Handlers::ItemRanking.add(:LEGENDPLATE,
  proc { |item, score, battler, ai|
    next score if battler.battler.isSpecies?(:ARCEUS) &&
                  battler.target.has_move_with_function?("TypeDependsOnUserPlate")
    next 0
  }
)

Battle::AI::Handlers::ItemRanking.add(:BOOSTERENERGY,
  proc { |item, score, battler, ai|
    next score if [:PROTOSYNTHESIS, :QUARKDRIVE].include?(battler.ability_id)
    next 0
  }
)

Battle::AI::Handlers::ItemRanking.add(:BLANKPLATE,
  proc { |item, score, battler, ai|
    next score if battler.has_damaging_move_of_type?(:NORMAL)
    next 0
  }
)

Battle::AI::Handlers::ItemRanking.add(:PUNCHINGGLOVE,
  proc { |item, score, battler, ai|
    next score if battler.check_for_move { |m| m.punchingMove? }
    next 0
  }
)

Battle::AI::Handlers::ItemRanking.add(:LOADEDDICE,
  proc { |item, score, battler, ai|
    score = 0
    if ai.trainer.high_skill?
      score += 1 if battler.check_for_move { |m| m.multiHitMove? }
    end
    next score
  }
)

#===============================================================================
# Teal Mask DLC
#===============================================================================
Battle::AI::Handlers::ItemRanking.add(:FAIRYFEATHER,
  proc { |item, score, battler, ai|
    next score if battler.has_damaging_move_of_type?(:FAIRY)
    next 0
  }
)

Battle::AI::Handlers::ItemRanking.add(:WELLSPRINGMASK,
  proc { |item, score, battler, ai|
    next score if battler.battler.isSpecies?(:OGERPON) &&
                  battler.has_damaging_move_of_type?(battler.types[0], battler.types[1])
    next 0
  }
)

Battle::AI::Handlers::ItemRanking.copy(:WELLSPRINGMASK,:HEARTHFLAMEMASK, :CORNERSTONEMASK)