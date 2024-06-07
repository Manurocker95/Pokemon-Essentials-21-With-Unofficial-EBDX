################################################################################
# 
# DLC ability handlers.
# 
################################################################################

############################## Teal Mask DLC ###################################

#===============================================================================
# Supersweet Syrup
#===============================================================================
Battle::AbilityEffects::OnSwitchIn.add(:SUPERSWEETSYRUP,
  proc { |ability, battler, battle, switch_in|
    next if battler.ability_triggered?
    battle.pbShowAbilitySplash(battler)
    battle.pbDisplay(_INTL("A supersweet aroma is wafting from the syrup covering {1}!", battler.pbThis))
    battle.allOtherSideBattlers(battler.index).each do |b|
      next if !b.near?(battler) || b.fainted?
      if b.itemActive? && !b.hasActiveAbility?(:CONTRARY) && b.effects[PBEffects::Substitute] == 0
        next if Battle::ItemEffects.triggerStatLossImmunity(b.item, b, :EVASION, battle, true)
      end
      b.pbLowerStatStageByAbility(:EVASION, 1, battler, false)
    end
    battle.pbHideAbilitySplash(battler)
    battle.pbSetAbilityTrigger(battler)
  }
)

#===============================================================================
# Hospitality
#===============================================================================
Battle::AbilityEffects::OnSwitchIn.add(:HOSPITALITY,
  proc { |ability, battler, battle, switch_in|
    next if battler.allAllies.none? { |b| b.canHeal? }
    battle.pbShowAbilitySplash(battler)
    battler.allAllies.each do |b|
      next if !b.canHeal?
      amt = (b.totalhp / 4).floor
      b.pbRecoverHP(amt)
      battle.pbDisplay(_INTL("{1} drank down all the matcha that {2} made!", b.pbThis, battler.pbThis(true)))
    end
    battle.pbHideAbilitySplash(battler)
  }
)

#===============================================================================
# Toxic Chain
#===============================================================================
Battle::AbilityEffects::OnDealingHit.add(:TOXICCHAIN,
  proc { |ability, user, target, move, battle|
    next if target.fainted?
    next if battle.pbRandom(100) >= 30
    next if target.hasActiveItem?(:COVERTCLOAK)
    battle.pbShowAbilitySplash(user)
    if target.hasActiveAbility?(:SHIELDDUST) && !battle.moldBreaker
      battle.pbShowAbilitySplash(target)
      if !Battle::Scene::USE_ABILITY_SPLASH
        battle.pbDisplay(_INTL("{1} is unaffected!", target.pbThis))
      end
      battle.pbHideAbilitySplash(target)
    elsif target.pbCanPoison?(user, Battle::Scene::USE_ABILITY_SPLASH)
      msg = nil
      if !Battle::Scene::USE_ABILITY_SPLASH
        msg = _INTL("{1} was badly poisoned!", target.pbThis)
      end
      target.pbPoison(user, msg, true)
    end
    battle.pbHideAbilitySplash(user)
  }
)

#===============================================================================
# Mind's Eye
#===============================================================================
Battle::AbilityEffects::StatLossImmunity.copy(:KEENEYE, :MINDSEYE)
Battle::AbilityEffects::AccuracyCalcFromUser.copy(:KEENEYE, :MINDSEYE)

#===============================================================================
# Embody Aspect
#===============================================================================
Battle::AbilityEffects::OnSwitchIn.add(:EMBODYASPECT,
  proc { |ability, battler, battle, switch_in|
    next if !battler.isSpecies?(:OGERPON)
    next if battler.effects[PBEffects::OneUseAbility] == ability
    mask = GameData::Species.get(:OGERPON).form_name
    battle.pbDisplay(_INTL("The {1} worn by {2} shone brilliantly!", mask, battler.pbThis(true)))
    battler.pbRaiseStatStageByAbility(:SPEED, 1, battler)
    battler.effects[PBEffects::OneUseAbility] = ability
  }
)

Battle::AbilityEffects::OnSwitchIn.add(:EMBODYASPECT_1,
  proc { |ability, battler, battle, switch_in|
    next if !battler.isSpecies?(:OGERPON)
    next if battler.effects[PBEffects::OneUseAbility] == ability
    mask = GameData::Species.get(:OGERPON_1).form_name
    battle.pbDisplay(_INTL("The {1} worn by {2} shone brilliantly!", mask, battler.pbThis(true)))
    battler.pbRaiseStatStageByAbility(:SPECIAL_DEFENSE, 1, battler)
    battler.effects[PBEffects::OneUseAbility] = ability
  }
)

Battle::AbilityEffects::OnSwitchIn.add(:EMBODYASPECT_2,
  proc { |ability, battler, battle, switch_in|
    next if !battler.isSpecies?(:OGERPON)
    next if battler.effects[PBEffects::OneUseAbility] == ability
    mask = GameData::Species.get(:OGERPON_2).form_name
    battle.pbDisplay(_INTL("The {1} worn by {2} shone brilliantly!", mask, battler.pbThis(true)))
    battler.pbRaiseStatStageByAbility(:ATTACK, 1, battler)
    battler.effects[PBEffects::OneUseAbility] = ability
  }
)

Battle::AbilityEffects::OnSwitchIn.add(:EMBODYASPECT_3,
  proc { |ability, battler, battle, switch_in|
    next if !battler.isSpecies?(:OGERPON)
    next if battler.effects[PBEffects::OneUseAbility] == ability
    mask = GameData::Species.get(:OGERPON_3).form_name
    battle.pbDisplay(_INTL("The {1} worn by {2} shone brilliantly!", mask, battler.pbThis(true)))
    battler.pbRaiseStatStageByAbility(:DEFENSE, 1, battler)
    battler.effects[PBEffects::OneUseAbility] = ability
  }
)


############################# Indigo Disk DLC ##################################

#===============================================================================
# Tera Shell
#===============================================================================
Battle::AbilityEffects::ModifyTypeEffectiveness.add(:TERASHELL,
  proc { |ability, user, target, move, battle, effectiveness|
    next if !move.damagingMove?
    next if user.hasMoldBreaker?
    next if target.hp < target.totalhp
    next if effectiveness < Effectiveness::NORMAL_EFFECTIVE_MULTIPLIER
    target.damageState.terashell = true
    next Effectiveness::NOT_VERY_EFFECTIVE_MULTIPLIER
  }
)

Battle::AbilityEffects::OnMoveSuccessCheck.add(:TERASHELL,
  proc { |ability, user, target, move, battle|
    next if !target.damageState.terashell
    battle.pbShowAbilitySplash(target)
    battle.pbDisplay(_INTL("{1} made its shell gleam! It's distorting type matchups!", target.pbThis))
    battle.pbHideAbilitySplash(target)
  }
)

#===============================================================================
# Teraform Zero
#===============================================================================
Battle::AbilityEffects::OnSwitchIn.add(:TERAFORMZERO,
  proc { |ability, battler, battle, switch_in|
    next if battler.ability_triggered?
    battle.pbSetAbilityTrigger(battler)
    weather = battle.field.weather
    terrain = battle.field.terrain
    next if weather == :None && terrain == :None
    showSplash = false
    if weather != :None && battle.field.defaultWeather == :None
	  showSplash = true
      battle.pbShowAbilitySplash(battler)
      battle.field.weather = :None
      battle.field.weatherDuration = 0
      case weather
      when :Sun         then battle.pbDisplay(_INTL("The sunlight faded."))
      when :Rain        then battle.pbDisplay(_INTL("The rain stopped."))
      when :Sandstorm   then battle.pbDisplay(_INTL("The sandstorm subsided."))
      when :Hail
        case Settings::HAIL_WEATHER_TYPE
        when 0 then battle.pbDisplay(_INTL("The hail stopped."))
        when 1 then battle.pbDisplay(_INTL("The snow stopped."))
        when 2 then battle.pbDisplay(_INTL("The hailstorm ended."))
        end
      when :HarshSun    then battle.pbDisplay(_INTL("The harsh sunlight faded!"))
      when :HeavyRain   then battle.pbDisplay(_INTL("The heavy rain has lifted!"))
      when :StrongWinds then battle.pbDisplay(_INTL("The mysterious air current has dissipated!"))
      else
        battle.pbDisplay(_INTL("The weather returned to normal."))
      end
    end
    if terrain != :None && battle.field.defaultTerrain == :None
      battle.pbShowAbilitySplash(battler) if !showSplash
      battle.field.terrain = :None
      battle.field.terrainDuration = 0
      case terrain
      when :Electric then battle.pbDisplay(_INTL("The electric current disappeared from the battlefield!"))
      when :Grassy   then battle.pbDisplay(_INTL("The grass disappeared from the battlefield!"))
      when :Psychic  then battle.pbDisplay(_INTL("The mist disappeared from the battlefield!"))
      when :Misty    then battle.pbDisplay(_INTL("The weirdness disappeared from the battlefield!"))
      else
        battle.pbDisplay(_INTL("The battlefield returned to normal."))
      end
    end
    next if !showSplash
    battle.pbHideAbilitySplash(battler)
    battle.allBattlers.each { |b| b.pbCheckFormOnWeatherChange }
    battle.allBattlers.each { |b| b.pbAbilityOnTerrainChange }
    battle.allBattlers.each { |b| b.pbItemTerrainStatBoostCheck }
  }
)

#===============================================================================
# Poison Puppeteer
#===============================================================================
Battle::AbilityEffects::OnInflictingStatus.add(:POISONPUPPETEER,
  proc { |ability, user, battler, status|
    next if !user || user.index == battler.index
    next if status != :POISON
    next if battler.effects[PBEffects::Confusion] > 0
    user.battle.pbShowAbilitySplash(user)
    battler.pbConfuse if battler.pbCanConfuse?(user, false, nil)
    user.battle.pbHideAbilitySplash(user)
  }
)