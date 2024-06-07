################################################################################
# 
# New item losability.
# 
################################################################################


module GameData
  class Item
    alias paldea_unlosable? unlosable?
    def unlosable?(species, ability)
      combos = {
        :DIALGA   => [:ADAMANTCRYSTAL],
        :PALKIA   => [:LUSTROUSGLOBE],
        :GIRATINA => [:GRISEOUSCORE],
        :ARCEUS   => [:BLANKPLATE, :LEGENDPLATE],
		:OGERPON  => [:WELLSPRINGMASK, :HEARTHFLAMEMASK, :CORNERSTONEMASK]
      }
      return true if combos[species]&.include?(@id)
      return true if @id == :BOOSTERENERGY &&
                     [:PROTOSYNTHESIS, :QUARKDRIVE].include?(ability) &&
                     GameData::Species.get(species).has_flag?("Paradox")
      return paldea_unlosable?(species, ability)
    end
  end
end


################################################################################
# 
# New item handlers (from the bag).
# 
################################################################################


#===============================================================================
# Hopo Berry
#===============================================================================
ItemHandlers::UseOnPokemon.copy(:ETHER, :LEPPABERRY, :HOPOBERRY)
ItemHandlers::CanUseInBattle.copy(:ETHER, :LEPPABERRY, :HOPOBERRY)
ItemHandlers::BattleUseOnPokemon.copy(:ETHER, :LEPPABERRY, :HOPOBERRY)

#===============================================================================
# Scroll of Waters
#===============================================================================
ItemHandlers::UseOnPokemon.add(:SCROLLOFWATERS,
  proc { |item, qty, pkmn, scene|
    if pkmn.shadowPokemon?
      scene.pbDisplay(_INTL("It won't have any effect."))
      next false
    end
    newspecies = pkmn.check_evolution_on_use_item(item)
    if newspecies
      pkmn.form = 1 if pkmn.species == :KUBFU
      pbFadeOutInWithMusic {
        evo = PokemonEvolutionScene.new
        evo.pbStartScreen(pkmn, newspecies)
        evo.pbEvolution(false)
        evo.pbEndScreen
        if scene.is_a?(PokemonPartyScreen)
          scene.pbRefreshAnnotations(proc { |p| !p.check_evolution_on_use_item(item).nil? })
          scene.pbRefresh
        end
      }
      next true
    end
    scene.pbDisplay(_INTL("It won't have any effect."))
    next false
  }
)


################################################################################
# 
# New Poke Ball handlers.
# 
################################################################################
Battle::PokeBallEffects::ModifyCatchRate.add(:HISUIANPOKEBALL, proc { |ball, catchRate, battle, battler|
  next catchRate * 0.75
})

Battle::PokeBallEffects::ModifyCatchRate.add(:HISUIANGREATBALL, proc { |ball, catchRate, battle, battler|
  next catchRate * 1.5
})

Battle::PokeBallEffects::ModifyCatchRate.add(:HISUIANULTRABALL, proc { |ball, catchRate, battle, battler|
  next catchRate * 2.25
})

Battle::PokeBallEffects::ModifyCatchRate.add(:HISUIANHEAVYBALL, proc { |ball, catchRate, battle, battler|
  baseStats = battler.pokemon.baseStats
  baseSpeed = baseStats[:SPEED]
  catchRate *= 1.25 if baseSpeed <= 50
  next catchRate
})

Battle::PokeBallEffects::ModifyCatchRate.add(:LEADENBALL, proc { |ball, catchRate, battle, battler|
  baseStats = battler.pokemon.baseStats
  baseSpeed = baseStats[:SPEED]
  catchRate *= ((baseSpeed <= 50) ? 2 : 1.25)
  next catchRate
})

Battle::PokeBallEffects::ModifyCatchRate.add(:GIGATONBALL, proc { |ball, catchRate, battle, battler|
  baseStats = battler.pokemon.baseStats
  baseSpeed = baseStats[:SPEED]
  catchRate *= ((baseSpeed <= 50) ? 2.75 : 2)
  next catchRate
})

Battle::PokeBallEffects::ModifyCatchRate.add(:FEATHERBALL, proc { |ball, catchRate, battle, battler|
  baseStats = battler.pokemon.baseStats
  baseSpeed = baseStats[:SPEED]
  catchRate *= 1.25 if battler.airborne? || baseSpeed >= 100
  next catchRate
})

Battle::PokeBallEffects::ModifyCatchRate.add(:WINGBALL, proc { |ball, catchRate, battle, battler|
  baseStats = battler.pokemon.baseStats
  baseSpeed = baseStats[:SPEED]
  catchRate *= ((battler.airborne? || baseSpeed >= 100) ? 2 : 1.25)
  next catchRate
})

Battle::PokeBallEffects::ModifyCatchRate.add(:JETBALL, proc { |ball, catchRate, battle, battler|
  baseStats = battler.pokemon.baseStats
  baseSpeed = baseStats[:SPEED]
  catchRate *= ((battler.airborne? || baseSpeed >= 100) ? 2.75 : 2)
  next catchRate
})

Battle::PokeBallEffects::ModifyCatchRate.add(:STRANGEBALL, proc { |ball, catchRate, battle, battler|
  next catchRate
})

Battle::PokeBallEffects::IsUnconditional.add(:ORIGINBALL, proc { |ball, battle, battler|
  next [:DIALGA, :PALKIA, :GIRATINA].include?(battler.species) && battler.form == 1
})


################################################################################
# 
# New battle item handlers (held items).
# 
################################################################################


#===============================================================================
# New item triggers.
#===============================================================================
module Battle::ItemEffects
  OnOpposingStatGain = ItemHandlerHash.new # Mirror Herb
  StatLossImmunity   = ItemHandlerHash.new # Clear Amulet
  
  def self.triggerOnOpposingStatGain(item, battler, battle, statUps, forced)
    return trigger(OnOpposingStatGain, item, battler, battle, statUps, forced)
  end

  def self.triggerStatLossImmunity(item, battler, stat, battle, show_message)
    return trigger(StatLossImmunity, item, battler, stat, battle, show_message)
  end
end

#===============================================================================
# Hopo Berry
#===============================================================================
Battle::ItemEffects::OnEndOfUsingMove.copy(:LEPPABERRY, :HOPOBERRY)

#===============================================================================
# PLA Damage boosters
#===============================================================================
Battle::ItemEffects::DamageCalcFromUser.copy(:GRISEOUSORB, :GRISEOUSCORE)
Battle::ItemEffects::DamageCalcFromUser.copy(:ADAMANTORB, :ADAMANTCRYSTAL)
Battle::ItemEffects::DamageCalcFromUser.copy(:LUSTROUSORB, :LUSTROUSGLOBE)
Battle::ItemEffects::DamageCalcFromUser.copy(:SILKSCARF, :BLANKPLATE)

#===============================================================================
# Punching Glove
#===============================================================================
Battle::ItemEffects::DamageCalcFromUser.add(:PUNCHINGGLOVE,
  proc { |item, user, target, move, mults, baseDmg, type|
    mults[:power_multiplier] *= 1.1 if move.punchingMove?
  }
)

#===============================================================================
# Clear Amulet
#===============================================================================
Battle::ItemEffects::StatLossImmunity.add(:CLEARAMULET,
  proc { |item, battler, stat, battle, showMessages|
    if showMessages
      battle.pbDisplay(_INTL("{1}'s {2} prevents stat loss!", battler.pbThis, battler.itemName))
    end
    next true
  }
)

#===============================================================================
# Mirror Herb
#===============================================================================
Battle::ItemEffects::OnOpposingStatGain.add(:MIRRORHERB,
  proc { |item, battler, battle, statUps, forced|
    showAnim = true
    battler.mirrorHerbUsed = true
    statUps.each do |stat, increment|
      next if !battler.pbCanRaiseStatStage?(stat, battler)
        if battler.pbRaiseStatStage(stat, increment, battler, showAnim)
        showAnim = false
      end
    end
    battler.mirrorHerbUsed = false
    next false if showAnim
    itemName = GameData::Item.get(item).name
    PBDebug.log("[Item triggered] #{battler.pbThis}'s #{itemName}") if forced
    battle.pbCommonAnimation("UseItem", battler) if !forced
    battle.pbDisplay(_INTL("{1} used its {2} to mirror its opponent's stat changes!", battler.pbThis, itemName))
    next true
  }
)