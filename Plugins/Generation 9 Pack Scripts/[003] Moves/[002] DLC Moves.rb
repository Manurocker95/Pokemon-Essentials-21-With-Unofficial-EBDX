################################################################################
# 
# DLC move handlers.
# 
################################################################################

############################## Teal Mask DLC ###################################

#===============================================================================
# Matcha Gatcha
#===============================================================================
# User gains half the HP it inflicts as damage. It may also burn the target.
#-------------------------------------------------------------------------------
class Battle::Move::HealUserByHalfOfDamageDoneBurnTarget < Battle::Move::BurnTarget
  def healingMove?; return Settings::MECHANICS_GENERATION >= 6; end

  def pbEffectAgainstTarget(user, target)
    return if target.damageState.hpLost <= 0
    hpGain = (target.damageState.hpLost / 2.0).round
    user.pbRecoverHPFromDrain(hpGain, target)
    super
  end
end

#===============================================================================
# Syrup Bomb
#===============================================================================
# Lower Target Speed for 3 turns.
#-------------------------------------------------------------------------------
class Battle::Move::LowerTargetSpeedOverTime < Battle::Move
  def pbEffectAgainstTarget(user, target)
    return if target.fainted? || target.damageState.substitute
    return if target.effects[PBEffects::Syrupy] > 0
    target.effects[PBEffects::Syrupy] = 3
    target.effects[PBEffects::SyrupyUser] = user.index
    @battle.pbDisplay(_INTL("{1} got covered in sticky candy syrup!", target.pbThis))
  end

  def pbShowAnimation(id, user, targets, hitNum = 0, showAnimation = true)
    hitNum = (user.shiny?) ? 1 : 0
    super
  end
end

#===============================================================================
# Ivy Cudgel
#===============================================================================
# The type of the move changes to reflect Ogerpon's mask.
#-------------------------------------------------------------------------------
class Battle::Move::TypeIsUserSecondType < Battle::Move
  def pbBaseType(user)
    return @type if !user.isSpecies?(:OGERPON)
    userTypes = user.pokemon.types
    return userTypes[1] || userTypes[0] || @type
  end
  
  def pbShowAnimation(id, user, targets, hitNum = 0, showAnimation = true)
    case pbBaseType(user)
    when :WATER then hitNum = 1
    when :FIRE  then hitNum = 2
    when :ROCK  then hitNum = 3
    else             hitNum = 0
    end
    super
  end
end

############################## Indigo Disk DLC ###################################

#===============================================================================
# Electro Shot
#===============================================================================
# Two-turn attack. Raises Sp.Atk during the charging turn. Doesn't charge in rain.
#-------------------------------------------------------------------------------
class Battle::Move::TwoTurnAttackOneTurnInRainRaiseUserSpAtk1 < Battle::Move::TwoTurnMove
  attr_reader :statUp

  def initialize(battle, move)
    super
    @statUp = [:SPECIAL_ATTACK, 1]
  end

  def pbIsChargingTurn?(user)
    ret = super
    if !user.effects[PBEffects::TwoTurnAttack] &&
       [:Rain, :HeavyRain].include?(user.effectiveWeather)
      @powerHerb = false
      @chargingTurn = true
      @damagingTurn = true
      return false
    end
    return ret
  end
  
  def pbChargingTurnMessage(user, targets)
    @battle.pbDisplay(_INTL("{1} absorbed electricity!", user.pbThis))
  end

  def pbChargingTurnEffect(user, target)
    if user.pbCanRaiseStatStage?(@statUp[0], user, self)
      user.pbRaiseStatStage(@statUp[0], @statUp[1], user)
    end
  end
end

#===============================================================================
# Fickle Beam
#===============================================================================
# Has a 30% chance to deal double damage.
#-------------------------------------------------------------------------------
class Battle::Move::RandomlyDealsDoubleDamage < Battle::Move
  def pbOnStartUse(user, targets)
    @allOutAttack = (@battle.pbRandom(100) < 30)
    if @allOutAttack
      @battle.pbDisplay(_INTL("{1} is going all out for this attack!", user.pbThis))
    end
  end

  def pbBaseDamage(baseDmg, user, target)
    return (@allOutAttack) ? baseDmg * 2 : baseDmg
  end
  
  def pbShowAnimation(id, user, targets, hitNum = 0, showAnimation = true)
    hitNum = 1 if @allOutAttack
    super
  end
end

#===============================================================================
# Burning Bulwark
#===============================================================================
# The user protects itself. Foes who make contact will become burned.
#-------------------------------------------------------------------------------
class Battle::Move::ProtectUserBurningBulwark < Battle::Move::ProtectMove
  def initialize(battle, move)
    super
    @effect = PBEffects::BurningBulwark
  end
end

#===============================================================================
# Dragon Cheer
#===============================================================================
# Boosts the critical hit rate of allies. Dragon-types get boosted more.
#-------------------------------------------------------------------------------
class Battle::Move::RaiseAlliesCriticalHitRate1DragonTypes2 < Battle::Move
  def ignoresSubstitute?(user); return true; end
  def canSnatch?; return true; end

  def pbMoveFailed?(user, targets)
    @validTargets = []
    @battle.allSameSideBattlers(user).each do |b|
      next if b.index == user.index
      next if b.effects[PBEffects::FocusEnergy] > 0
      @validTargets.push(b)
    end
    if @validTargets.length == 0
      @battle.pbDisplay(_INTL("But it failed!"))
      return true
    end
    return false
  end

  def pbFailsAgainstTarget?(user, target, show_message)
    return false if @validTargets.any? { |b| b.index == target.index }
    @battle.pbDisplay(_INTL("{1} is already pumped!", target.pbThis)) if show_message
    return true
  end

  def pbEffectAgainstTarget(user, target)
    boost = (target.pbHasType?(:DRAGON)) ? 2 : 1
    target.effects[PBEffects::FocusEnergy] = boost
    @battle.pbCommonAnimation("StatUp", target)
    @battle.pbDisplay(_INTL("{1} is getting pumped!", target.pbThis))
  end
end

#===============================================================================
# Alluring Voice
#===============================================================================
# Confuse the target if the target's stats have been raised this turn.
#-------------------------------------------------------------------------------
class Battle::Move::ConfuseTargetIfTargetStatsRaisedThisTurn < Battle::Move::ConfuseTarget
  def pbAdditionalEffect(user, target)
    super if target.statsRaisedThisRound
  end
end

#===============================================================================
# Hard Press
#===============================================================================
# Deals damage based on the target's remaining HP.
#-------------------------------------------------------------------------------
class Battle::Move::PowerHigherWithTargetHP100PowerRange < Battle::Move
  def pbBaseDamage(baseDmg, user, target)
    return [100 * target.hp / target.totalhp, 1].max
  end
end

#===============================================================================
# Supercell Slam
#===============================================================================
# If attack misses, user takes crash damage of 1/2 of max HP.
# This move is NOT affected by Gravity.
#-------------------------------------------------------------------------------
class Battle::Move::CrashDamageIfFails < Battle::Move::CrashDamageIfFailsUnusableInGravity
  def unusableInGravity?; return false; end
end

#===============================================================================
# Psychic Noise
#===============================================================================
# Applies the Heal Block effect on the target for 2 turns.
#-------------------------------------------------------------------------------
class Battle::Move::DisableTargetHealingMoves2Turns < Battle::Move
  def pbAdditionalEffect(user, target)
    return if target.effects[PBEffects::HealBlock] > 0
    return if pbMoveFailedAromaVeil?(user, target, false)
    target.effects[PBEffects::HealBlock] = 2
    @battle.pbDisplay(_INTL("{1} was prevented from healing!", target.pbThis))
    target.pbItemStatusCureCheck
  end
end

#===============================================================================
# Upper Hand
#===============================================================================
# Fails if the target isn't using a priority move.
#-------------------------------------------------------------------------------
class Battle::Move::FlinchTargetFailsIfTargetNotUsingPriorityMove < Battle::Move::FlinchTarget
  def pbMoveFailed?(user, targets)
	hasPriority = false
    targets.each do |b|
      next if b.movedThisRound?
      choices = @battle.choices[b.index]
      next if !choices[2].damagingMove?
	  next if !choices[4] || choices[4] <= 0 || choices[4] > @priority
      hasPriority = true
    end
    if !hasPriority
      @battle.pbDisplay(_INTL("But it failed!"))
      return true
    end
    return false
  end
end