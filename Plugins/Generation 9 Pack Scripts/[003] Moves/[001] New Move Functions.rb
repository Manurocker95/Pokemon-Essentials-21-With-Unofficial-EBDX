################################################################################
# 
# Drowse & Frostbite effects.
# 
################################################################################


#===============================================================================
# Drowses the target.
#===============================================================================
class Battle::Move::DrowseTarget < Battle::Move
  def canMagicCoat?; return true; end

  def pbFailsAgainstTarget?(user, target, show_message)
    return false if damagingMove?
    return !target.pbCanDrowse?(user, show_message, self)
  end

  def pbEffectAgainstTarget(user, target)
    return if damagingMove?
    target.pbDrowse
  end

  def pbAdditionalEffect(user, target)
    return if target.damageState.substitute
    target.pbDrowse if target.pbCanDrowse?(user, false, self)
  end
end

#===============================================================================
# Frostbites the target.
#===============================================================================
class Battle::Move::FrostbiteTarget < Battle::Move
  def canMagicCoat?; return true; end

  def pbFailsAgainstTarget?(user, target, show_message)
    return false if damagingMove?
    return !target.pbCanFrostbite?(user, show_message, self)
  end

  def pbEffectAgainstTarget(user, target)
    return if damagingMove?
    target.pbFrostbite(user)
  end

  def pbAdditionalEffect(user, target)
    return if target.damageState.substitute
    target.pbFrostbite(user) if target.pbCanFrostbite?(user, false, self)
  end
end


################################################################################
# 
# New move effects (PLA).
# 
################################################################################


#===============================================================================
# Dire Claw
#===============================================================================
# May paralyze, poison or put the target to sleep.
#-------------------------------------------------------------------------------
class Battle::Move::PoisonParalyzeOrSleepTarget < Battle::Move
  def pbAdditionalEffect(user, target)
    return if target.damageState.substitute
    case @battle.pbRandom(3)
    when 0 then target.pbSleep          if target.pbCanSleep?(user, false, self)
    when 1 then target.pbPoison(user)   if target.pbCanPoison?(user, false, self)
    when 2 then target.pbParalyze(user) if target.pbCanParalyze?(user, false, self)
    end
  end
end

#===============================================================================
# Barb Barrage
#===============================================================================
# Power is doubled if the target is poisoned. May poison the target.
#-------------------------------------------------------------------------------
class Battle::Move::DoublePowerIfTargetPoisonedPoisonTarget < Battle::Move::PoisonTarget
  def pbBaseDamage(baseDmg, user, target)
    if target.poisoned? &&
       (target.effects[PBEffects::Substitute] == 0 || ignoresSubstitute?(user))
      baseDmg *= 2
    end
    return baseDmg
  end
end

#===============================================================================
# Infernal Parade
#===============================================================================
# Power is doubled if the target has a status condition. May burn the target.
#-------------------------------------------------------------------------------
class Battle::Move::DoublePowerIfTargetStatusProblemBurnTarget < Battle::Move::BurnTarget
  def pbBaseDamage(baseDmg, user, target)
    if target.pbHasAnyStatus? &&
       (target.effects[PBEffects::Substitute] == 0 || ignoresSubstitute?(user))
      baseDmg *= 2
    end
    return baseDmg
  end
end

#===============================================================================
# Ceaseless Edge (Gen 9+)
#===============================================================================
# Lays spikes on the opposing side if damage was dealt (max. 3 layers).
#-------------------------------------------------------------------------------
class Battle::Move::DamageTargetAddSpikesToFoeSide < Battle::Move
  def pbEffectWhenDealingDamage(user, target)
    return if target.pbOwnSide.effects[PBEffects::Spikes] == 3
    target.pbOwnSide.effects[PBEffects::Spikes] += 1
    @battle.pbAnimation(:SPIKES, user, target)
    @battle.pbDisplay(_INTL("Spikes were scattered all around {1}'s feet!", user.pbOpposingTeam(true)))
  end
end

#===============================================================================
# Stone Axe (Gen 9+)
#===============================================================================
# Lays stealth rocks on the opposing side if damage was dealt.
#-------------------------------------------------------------------------------
class Battle::Move::DamageTargetAddStealthRocksToFoeSide < Battle::Move
  def pbEffectWhenDealingDamage(user, target)
    return if target.pbOwnSide.effects[PBEffects::StealthRock]
    target.pbOwnSide.effects[PBEffects::StealthRock] = true
    @battle.pbAnimation(:STEALTHROCK, user, target)
    @battle.pbDisplay(_INTL("Pointed stones float in the air around {1}!", user.pbOpposingTeam(true)))
  end
end

#===============================================================================
# Ceaseless Edge, Stone Axe (PLA)
#===============================================================================
# Starts the splinters effect on the target.
#-------------------------------------------------------------------------------
class Battle::Move::StartSplintersTarget < Battle::Move
  def canMagicCoat?; return true; end

  def pbFailsAgainstTarget?(user, target, show_message)
    return false if damagingMove?
    if target.effects[PBEffects::Splinters] > 0
      @battle.pbDisplay(_INTL("But it failed!")) if show_message
      return true
    end
    return false
  end

  def pbEffectAgainstTarget(user, target)
    return if damagingMove?
    target.effects[PBEffects::Splinters] = 3
    target.effects[PBEffects::SplintersType] = @type
    @battle.pbDisplay(_INTL("Jagged splinters dug into {1}!", target.pbThis(true)))
  end

  def pbAdditionalEffect(user, target)
    return if target.damageState.substitute
    return if target.effects[PBEffects::Splinters] > 0
    target.effects[PBEffects::Splinters] = 3
    target.effects[PBEffects::SplintersType] = @type
    @battle.pbDisplay(_INTL("Jagged splinters dug into {1}!", target.pbThis(true)))
  end
end

#===============================================================================
# Ceaseless Edge, Stone Axe (Toggle)
#===============================================================================
# Toggles between the Gen 9 or PLA versions of these moves.
#-------------------------------------------------------------------------------
if Settings::MECHANICS_GENERATION >= 9
  class Battle::Move::SplintersTargetGen8AddSpikesGen9 < Battle::Move::DamageTargetAddSpikesToFoeSide
  end
  class Battle::Move::SplintersTargetGen8AddStealthRocksGen9 < Battle::Move::DamageTargetAddStealthRocksToFoeSide
  end
else
  class Battle::Move::SplintersTargetGen8AddSpikesGen9 < Battle::Move::StartSplintersTarget
  end
  class Battle::Move::SplintersTargetGen8AddStealthRocksGen9 < Battle::Move::StartSplintersTarget
  end
end

#===============================================================================
# Triple Arrows
#===============================================================================
# Lowers the target's Defense by 1 stage. May cause flinching.
#-------------------------------------------------------------------------------
class Battle::Move::LowerTargetDefense1FlinchTarget < Battle::Move
  def flinchingMove?; return true; end

  def pbAdditionalEffect(user, target)
    return if target.damageState.substitute
    chance = pbAdditionalEffectChance(user, target, 50)
    if @battle.pbRandom(100) < chance
      if target.pbCanLowerStatStage?(:DEFENSE, user, self) && 
        target.pbLowerStatStage(:DEFENSE, 1, user)
      end
    end
    chance = pbAdditionalEffectChance(user, target, 30)
    return if chance == 0
    target.pbFlinch(user) if @battle.pbRandom(100) < chance
  end
end

#===============================================================================
# Victory Dance
#===============================================================================
# Increases the user's Attack, Defense and Speed by 1 stage each.
#-------------------------------------------------------------------------------
class Battle::Move::RaiseUserAtkDefSpd1 < Battle::Move::MultiStatUpMove
  def initialize(battle, move)
    super
    @statUp = [:ATTACK, 1, :DEFENSE, 1, :SPEED, 1]
  end
end

#===============================================================================
# Take Heart
#===============================================================================
# Increases the user's Sp. Atk and Sp. Def by 1 stage each and cures its status.
#-------------------------------------------------------------------------------
class Battle::Move::RaiseUserSpAtkSpDef1CureStatus < Battle::Move::MultiStatUpMove
  def initialize(battle,move)
    super
    @statUp = [:SPECIAL_ATTACK, 1, :SPECIAL_DEFENSE, 1]
  end
  
  def pbEffectGeneral(user)
    super
    user.pbCureStatus if user.pbHasAnyStatus?
  end 
end

#===============================================================================
# User takes recoil damage equal to 1/2 of its total HP. (Chloroblast)
#===============================================================================
class Battle::Move::RecoilHalfOfTotalHP < Battle::Move::RecoilMove
  def pbRecoilDamage(user, target)
    return (user.totalhp / 2.0).ceil
  end
end

#===============================================================================
# Lowers the target's Speed by 1 stage. Skips accuracy check in rain. 
# (Bleakwind Storm)
#===============================================================================
class Battle::Move::LowerTargetSpeed1AlwaysHitsInRain < Battle::Move::TargetStatDownMove
  def initialize(battle, move)
    super
    @statDown = [:SPEED, 1]
  end
  
  def pbBaseAccuracy(user, target)
    return 0 if [:Rain, :HeavyRain].include?(target.effectiveWeather)
    return super
  end
end

#===============================================================================
# May paralyze targets. Skips accuracy check in rain. (Wildbolt Storm)
#===============================================================================
class Battle::Move::ParalyzeTargetAlwaysHitsInRain < Battle::Move::ParalyzeTarget
  def pbBaseAccuracy(user, target)
    return 0 if [:Rain, :HeavyRain].include?(target.effectiveWeather)
    return super
  end
end

#===============================================================================
# May burn targets. Skips accuracy check in rain. (Sandsear Storm)
#===============================================================================
class Battle::Move::BurnTargetAlwaysHitsInRain < Battle::Move::BurnTarget
  def pbBaseAccuracy(user, target)
    return 0 if [:Rain, :HeavyRain].include?(target.effectiveWeather)
    return super
  end
end

################################################################################
# 
# New move effects (SV).
# 
################################################################################


#===============================================================================
# Raging Bull
#===============================================================================
# Ends Light Screen, Reflect and Aurora Veil on the target's side.
# If used by Tauros, the type of the move changes to reflect Tauros's type.
#-------------------------------------------------------------------------------
class Battle::Move::TypeIsUserSecondTypeRemoveScreens < Battle::Move::RemoveScreens
  def pbBaseType(user)
    return @type if !user.isSpecies?(:TAUROS)
    userTypes = user.pokemon.types
    return userTypes[1] || userTypes[0] || @type
  end
  
  def pbShowAnimation(id, user, targets, hitNum = 0, showAnimation = true)
	case pbBaseType(user)
	when :FIGHTING then hitNum = 1
	when :FIRE     then hitNum = 2
	when :WATER    then hitNum = 3
	else                hitNum = 0
	end
    super
  end
end

#===============================================================================
# Last Respects
#===============================================================================
# Power is increased by 50 for each time a teammate fainted this battle.
#-------------------------------------------------------------------------------
class Battle::Move::IncreasePowerEachFaintedAlly < Battle::Move
  def pbBaseDamage(baseDmg, user, target)
    numFainted = user.num_fainted_allies
    return baseDmg if numFainted <= 0
    baseDmg += 50 * numFainted
    return baseDmg
  end
end

#===============================================================================
# Rage Fist
#===============================================================================
# Power is increased by 50 for each time the user has been hit this battle.
#-------------------------------------------------------------------------------
class Battle::Move::IncreasePowerEachTimeHit < Battle::Move
  def pbBaseDamage(baseDmg, user, target)
    bonus = 50 * user.num_times_hit
    return [baseDmg + bonus, 350].min
  end
end

#===============================================================================
# Collision Course, Electro Drift
#===============================================================================
# Damage is increased if the move would deal super effective damage.
#-------------------------------------------------------------------------------
class Battle::Move::IncreasePowerSuperEffective < Battle::Move
  def pbBaseDamage(baseDmg, user, target)
    baseDmg *= 4 / 3.0 if Effectiveness.super_effective?(target.damageState.typeMod)
    return baseDmg
  end
end

#===============================================================================
# Triple Dive
#===============================================================================
# Hits the target 3 times.
#-------------------------------------------------------------------------------
class Battle::Move::HitThreeTimes < Battle::Move
  def multiHitMove?;            return true; end
  def pbNumHits(user, targets); return 3;    end
end

#===============================================================================
# Population Bomb
#===============================================================================
# Hits 10 times. An accuracy check is performed for each hit.
#-------------------------------------------------------------------------------
class Battle::Move::HitTenTimes < Battle::Move
  def multiHitMove?; return true; end

  def pbNumHits(user, targets)
    return 4 + rand(7) if user.hasActiveItem?(:LOADEDDICE)
    return 10
  end

  def successCheckPerHit?
    return @accCheckPerHit
  end

  def pbOnStartUse(user, targets)
    @accCheckPerHit = !user.hasActiveAbility?(:SKILLLINK) && !user.hasActiveItem?(:LOADEDDICE)
  end
end

#===============================================================================
# Axe Kick
#===============================================================================
# If attack misses, user takes crash damage of 1/2 of max HP. May cause confusion.
#-------------------------------------------------------------------------------
class Battle::Move::CrashDamageIfFailsConfuseTarget < Battle::Move::ConfuseTarget
  def recoilMove?; return true; end
  
  def pbCrashDamage(user)
    return if !user.takesIndirectDamage?
    @battle.pbDisplay(_INTL("{1} kept going and crashed!", user.pbThis))
    @battle.scene.pbDamageAnimation(user)
    user.pbReduceHP((user.totalhp / 2), false)
    user.pbItemHPHealCheck
    user.pbFaint if user.fainted?
  end
end

#===============================================================================
# Glaive Rush
#===============================================================================
# The user becomes vulnerable to moves until it uses its next move.
#-------------------------------------------------------------------------------
class Battle::Move::UserVulnerableUntilNextAction < Battle::Move
  def pbEffectWhenDealingDamage(user, target)
    user.effects[PBEffects::GlaiveRush] = 2
  end
end

#===============================================================================
# Gigaton Hammer, Blood Moon
#===============================================================================
# This move becomes unselectable if you try to use it on consecutive turns.
#-------------------------------------------------------------------------------
class Battle::Move::CantSelectConsecutiveTurns < Battle::Move
  def pbEffectWhenDealingDamage(user, target)
    user.effects[PBEffects::SuccessiveMove] = @id
  end
end

#===============================================================================
# Make it Rain
#===============================================================================
# Lowers the user's Sp.Atk by 1 stage. Also scatters coins to be picked up.
#-------------------------------------------------------------------------------
class Battle::Move::AddMoneyGainedFromBattleLowerUserSpAtk1 < Battle::Move
  attr_reader :statDown
  def initialize(battle, move)
    super
    @statDown = [:SPECIAL_ATTACK, 1]
  end
  
  def pbEndOfMoveUsageEffect(user, targets, numHits, switchedBattlers)
    return if @battle.pbAllFainted?(user.idxOpposingSide)
    hit_target = false
    targets.each do |b|
      next if b.damageState.missed
      next if b.damageState.protected
      next if b.damageState.unaffected
      hit_target = true
      # Money modifier
      next if !user.pbOwnedByPlayer?
      @battle.field.effects[PBEffects::PayDay] += 5 * user.level
    end
    @battle.pbDisplay(_INTL("Coins were scattered everywhere!")) if hit_target
    # Stats modifier
    if user.pbCanLowerStatStage?(@statDown[0], user, self) && hit_target
      user.pbLowerStatStage(@statDown[0], @statDown[1], user)
    end
  end
end

#===============================================================================
# Double Shock
#===============================================================================
# User loses their Electric type. Fails if user is not Electric-type.
#-------------------------------------------------------------------------------
class Battle::Move::UserLosesElectricType < Battle::Move
  def pbMoveFailed?(user, targets)
    if !user.pbHasType?(:ELECTRIC)
      @battle.pbDisplay(_INTL("But it failed!"))
      return true
    end
    return false
  end

  def pbEffectAfterAllHits(user, target)
    if !user.effects[PBEffects::DoubleShock]
      user.effects[PBEffects::DoubleShock] = true
      @battle.pbDisplay(_INTL("{1} used up all its electricity!", user.pbThis))
    end
  end
end

#===============================================================================
# Salt Cure
#===============================================================================
# Target will lose 1/4 of max HP at end of each round, or 1/8th if Water or Steel.
#-------------------------------------------------------------------------------
class Battle::Move::StartSaltCureTarget < Battle::Move
  def canMagicCoat?; return true; end

  def pbFailsAgainstTarget?(user, target, show_message)
    return false if damagingMove?
    if target.effects[PBEffects::SaltCure]
      @battle.pbDisplay(_INTL("But it failed!")) if show_message
      return true
    end
    return false
  end

  def pbEffectAgainstTarget(user, target)
    return if damagingMove?
    target.effects[PBEffects::SaltCure] = true
    @battle.pbDisplay(_INTL("{1} is being salt cured!", target.pbThis))
  end

  def pbAdditionalEffect(user, target)
	return if target.damageState.substitute
	target.effects[PBEffects::SaltCure] = true
    @battle.pbDisplay(_INTL("{1} is being salt cured!", target.pbThis))
  end
end

#===============================================================================
# Silk Trap
#===============================================================================
# User is protected against damaging moves this round. Decreases the Speed of
# the user of a stopped contact move by 1 stage.
#-------------------------------------------------------------------------------
class Battle::Move::ProtectUserFromDamagingMovesSilkTrap < Battle::Move::ProtectMove
  def initialize(battle, move)
    super
    @effect = PBEffects::SilkTrap
  end
end

#===============================================================================
# Order Up
#===============================================================================
# Increase the user's stat by 1 stage depending on the commanding Tatsugiri.
# This move can have different animations based on Tatsugiri's form.
#-------------------------------------------------------------------------------
class Battle::Move::RaiseUserStat1Commander < Battle::Move
  def pbEffectGeneral(user)
    if user.isCommanderHost?
      form = user.effects[PBEffects::Commander][1]
      stat = [:ATTACK, :DEFENSE, :SPEED][form]
      if user.pbCanRaiseStatStage?(stat, user, self)
        user.pbRaiseStatStage(stat, 1, user, true)
      end
    end
  end
  
  def pbShowAnimation(id, user, targets, hitNum = 0, showAnimation = true)
    hitNum = user.effects[PBEffects::Commander][1] + 1 if user.isCommanderHost? # Different animation based on Tatsugiri's form
    super
  end
end

#===============================================================================
# Spicy Extract
#===============================================================================
# Increases the target's Attack by 2 stages.
# Decreases the target's Defense by 2 stages.
#-------------------------------------------------------------------------------
class Battle::Move::RaiseTargetAtkLowerTargetDef2 < Battle::Move
  attr_reader :statUp, :statDown
  def canMagicCoat?; return true; end

  def initialize(battle, move)
    super
    @statUp   = [:ATTACK, 2]
    @statDown = [:DEFENSE, 2]
  end

  def pbFailsAgainstTarget?(user, target, show_message)
    return false if damagingMove?
    failed = !target.pbCanRaiseStatStage?(@statUp[0], user, self) && 
             !target.pbCanLowerStatStage?(@statDown[0], user, self)
    if failed
      @battle.pbDisplay(_INTL("{1}'s stats can't be changed further!", target.pbThis)) if show_message
      return true
    end
    return false
  end

  def pbEffectAgainstTarget(user, target)
    return if damagingMove?
    if target.pbCanRaiseStatStage?(@statUp[0], user, self)
      target.pbRaiseStatStage(@statUp[0], @statUp[1], user)
    end
    if target.pbCanLowerStatStage?(@statDown[0], user, self)
      target.pbLowerStatStage(@statDown[0], @statDown[1], user)
    end
  end
end

#===============================================================================
# Fillet Away
#===============================================================================
# Reduces the user's HP by half of max, and increases the user's Attack, Sp.Atk,
# and Speed by 2 stages.
#-------------------------------------------------------------------------------
class Battle::Move::RaiseUserAtkSpAtkSpeed2LoseHalfOfTotalHP < Battle::Move
  def canSnatch?; return true; end

  def pbMoveFailed?(user, targets)
    hpLoss = [user.totalhp / 2, 1].max
    if user.hp <= hpLoss
      @battle.pbDisplay(_INTL("But it failed!"))
      return true
    end
    failed = true
    [:ATTACK, :SPECIAL_ATTACK, :SPEED].each do |stat|
      next if !user.pbCanRaiseStatStage?(stat, user, self)
      failed = false
      break
    end
    if failed
      @battle.pbDisplay(_INTL("{1}'s stats won't go any higher!", user.pbThis))
      return true
    end
    return false
  end

  def pbEffectGeneral(user)
    hpLoss = [user.totalhp / 2, 1].max
    user.pbReduceHP(hpLoss, false, false)
    showAnim = true
    [:ATTACK, :SPECIAL_ATTACK, :SPEED].each do |stat|
      next if !user.pbCanRaiseStatStage?(stat, user, self)
      if user.pbRaiseStatStage(stat, 2, user, showAnim)
        showAnim = false
      end
    end
  end
end

#===============================================================================
# Tidy Up
#===============================================================================
# Increases the user's Attack and Speed by 1 stage each.
# Clears all entry hazards and substitutes on both sides.
#-------------------------------------------------------------------------------
class Battle::Move::RaiseUserAtkSpd1RemoveHazardsSubstitutes < Battle::Move::MultiStatUpMove
  def initialize(battle, move)
    super
    @statUp = [:ATTACK, 1, :SPEED, 1]
  end
  
  def pbMoveFailed?(user, targets)
    failed = true
    2.times do |i|
      side = (i == 0) ? user.pbOwnSide : user.pbOpposingSide
      next unless side.effects[PBEffects::Spikes] > 0 ||
                  side.effects[PBEffects::ToxicSpikes] > 0 ||
                  side.effects[PBEffects::StealthRock] ||
                  side.effects[PBEffects::StickyWeb] ||
                  defined?(PBEffects::Steelsurge) && side.effects[PBEffects::Steelsurge]
      failed = false
      break
    end
    @battle.allBattlers.each do |b|
      next if b.effects[PBEffects::Substitute] == 0
        failed = false
      break
    end
    failed2 = true
    (@statUp.length / 2).times do |i|
      next if !user.pbCanRaiseStatStage?(@statUp[i * 2], user, self)
      failed2 = false
      break
    end
    if failed && failed2
      @battle.pbDisplay(_INTL("But it failed!", user.pbThis))
      return true
    end
    return false
  end

  def pbEffectGeneral(user)
    showMsg = false
    2.times do |i|
      side = (i == 0) ? user.pbOwnSide : user.pbOpposingSide
      team = (i == 0) ? user.pbTeam(true) : user.pbOpposingTeam(true)
      if side.effects[PBEffects::StealthRock]
        side.effects[PBEffects::StealthRock] = false
        @battle.pbDisplay(_INTL("The pointed stones disappeared from around {1}!", team))
        showMsg = true
      end
      if defined?(PBEffects::Steelsurge) && side.effects[PBEffects::Steelsurge]
        side.effects[PBEffects::Steelsurge] = false
        @battle.pbDisplay(_INTL("The pointed steel disappeared from around {1}!", team))
        showMsg = true
      end
      if side.effects[PBEffects::Spikes] > 0
        side.effects[PBEffects::Spikes] = 0
        @battle.pbDisplay(_INTL("The spikes disappeared from the ground around {1}!", team))
        showMsg = true
      end
      if side.effects[PBEffects::ToxicSpikes] > 0
        side.effects[PBEffects::ToxicSpikes] = 0
        @battle.pbDisplay(_INTL("The poison spikes disappeared from the ground around {1}!", team))
        showMsg = true
      end
      if side.effects[PBEffects::StickyWeb]
        side.effects[PBEffects::StickyWeb] = false
        @battle.pbDisplay(_INTL("The sticky web has disappeared from the ground around {1}!", team))
        showMsg = true
      end
    end
    @battle.allBattlers.each do |b|
      next if b.effects[PBEffects::Substitute] == 0
      b.effects[PBEffects::Substitute] = 0
      showMsg = true
    end
    @battle.pbDisplay(_INTL("Tidying up complete!")) if showMsg
    super
  end
end

#===============================================================================
# Mortal Spin
#===============================================================================
# Removes trapping moves, entry hazards and Leech Seed on user/user's side.
# Poisons the target.
#-------------------------------------------------------------------------------
class Battle::Move::RemoveUserBindingAndEntryHazardsPoisonTarget < Battle::Move::PoisonTarget
  def pbEffectAfterAllHits(user, target)
    return if user.fainted? || target.damageState.unaffected
    if user.effects[PBEffects::Trapping] > 0
      trapMove = GameData::Move.get(user.effects[PBEffects::TrappingMove]).name
      trapUser = @battle.battlers[user.effects[PBEffects::TrappingUser]]
      @battle.pbDisplay(_INTL("{1} got free of {2}'s {3}!", user.pbThis, trapUser.pbThis(true), trapMove))
      user.effects[PBEffects::Trapping]     = 0
      user.effects[PBEffects::TrappingMove] = nil
      user.effects[PBEffects::TrappingUser] = -1
    end
    if user.effects[PBEffects::LeechSeed] >= 0
      user.effects[PBEffects::LeechSeed] = -1
      @battle.pbDisplay(_INTL("{1} shed Leech Seed!", user.pbThis))
    end
    if user.pbOwnSide.effects[PBEffects::StealthRock]
      user.pbOwnSide.effects[PBEffects::StealthRock] = false
      @battle.pbDisplay(_INTL("{1} blew away stealth rocks!", user.pbThis))
    end
    if defined?(PBEffects::Steelsurge) && user.pbOwnSide.effects[PBEffects::Steelsurge]
      user.pbOwnSide.effects[PBEffects::Steelsurge] = false
      @battle.pbDisplay(_INTL("{1} blew away the pointed steel!", user.pbThis))
    end
    if user.pbOwnSide.effects[PBEffects::Spikes] > 0
      user.pbOwnSide.effects[PBEffects::Spikes] = 0
      @battle.pbDisplay(_INTL("{1} blew away spikes!", user.pbThis))
    end
    if user.pbOwnSide.effects[PBEffects::ToxicSpikes] > 0
      user.pbOwnSide.effects[PBEffects::ToxicSpikes] = 0
      @battle.pbDisplay(_INTL("{1} blew away poison spikes!", user.pbThis))
    end
    if user.pbOwnSide.effects[PBEffects::StickyWeb]
      user.pbOwnSide.effects[PBEffects::StickyWeb] = false
      @battle.pbDisplay(_INTL("{1} blew away sticky webs!", user.pbThis))
    end
  end
end

#===============================================================================
# Ice Spinner
#===============================================================================
# Removes the current terrain.
#-------------------------------------------------------------------------------
class Battle::Move::RemoveTerrainIceSpinner < Battle::Move
  def pbEffectGeneral(user)
    return if user.fainted?
    return if @battle.field.terrain == :None
    case @battle.field.terrain
    when :Electric
      @battle.pbDisplay(_INTL("The electricity disappeared from the battlefield."))
    when :Grassy
      @battle.pbDisplay(_INTL("The grass disappeared from the battlefield."))
    when :Misty
      @battle.pbDisplay(_INTL("The mist disappeared from the battlefield."))
    when :Psychic
      @battle.pbDisplay(_INTL("The weirdness disappeared from the battlefield."))
    end
    @battle.field.terrain = :None
    @battle.allBattlers.each { |battler| battler.pbAbilityOnTerrainChange }
  end
end

#===============================================================================
# Chilly Reception
#===============================================================================
# Starts hail weather, then switches out.
#-------------------------------------------------------------------------------
class Battle::Move::SwitchOutUserStartHailWeather < Battle::Move::StartHailWeather  
  def pbDisplayUseMessage(user)
    @battle.pbDisplayBrief(_INTL("{1} is preparing to tell a chillingly bad joke!", user.pbThis))
    super
  end
  
  def pbEndOfMoveUsageEffect(user, targets, numHits, switchedBattlers)
    return if user.fainted? || numHits == 0
    return if !@battle.pbCanChooseNonActive?(user.index)
    @battle.pbDisplay(_INTL("{1} went back to {2}!", user.pbThis, @battle.pbGetOwnerName(user.index)))
    @battle.pbPursuit(user.index)
    return if user.fainted? 
    newPkmn = @battle.pbGetReplacementPokemonIndex(user.index)
    return if newPkmn < 0
    @battle.pbRecallAndReplace(user.index, newPkmn)
    @battle.pbClearChoice(user.index)
    @battle.moldBreaker = false
    @battle.pbOnBattlerEnteringBattle(user.index)
    switchedBattlers.push(user.index)
  end
end

#===============================================================================
# Shed Tail
#===============================================================================
# User turns 1/4 of max HP into a substitute. Then, the user switches out. The
# switched-in Pokemon retains the user's substitute.
#-------------------------------------------------------------------------------
class Battle::Move::UserMakeSubstituteSwitchOut < Battle::Move
  def pbMoveFailed?(user, targets)
    if user.effects[PBEffects::Substitute] > 0
      @battle.pbDisplay(_INTL("{1} already has a substitute!", user.pbThis))
      return true
    end
    @lifeCost = [(user.totalhp / 2).ceil, 1].max
    @subLife = [(@lifeCost / 4).ceil, 1].max
    if user.hp <= @lifeCost
      @battle.pbDisplay(_INTL("But it does not have enough HP left to make a substitute!"))
      return true
    end
    return false
  end
  
  def pbOnStartUse(user, targets)
    user.pbReduceHP(@lifeCost, false, false)
    user.pbItemHPHealCheck
  end

  def pbEffectGeneral(user)
    user.effects[PBEffects::Trapping]     = 0
    user.effects[PBEffects::TrappingMove] = nil
    user.effects[PBEffects::Substitute]   = @subLife
    @battle.pbDisplay(_INTL("{1} shed its tail to create a decoy!", user.pbThis))
  end

  def pbEndOfMoveUsageEffect(user, targets, numHits, switchedBattlers)
    return if user.fainted? || numHits == 0
    return if !@battle.pbCanChooseNonActive?(user.index)
    @battle.pbDisplay(_INTL("{1} went back to {2}!", user.pbThis, @battle.pbGetOwnerName(user.index)))
    @battle.pbPursuit(user.index)
    oldSub = user.effects[PBEffects::Substitute]
    return if user.fainted?
    newPkmn = @battle.pbGetReplacementPokemonIndex(user.index)
    return if newPkmn < 0
    @battle.pbRecallAndReplace(user.index, newPkmn)
    @battle.pbClearChoice(user.index)
    @battle.moldBreaker = false
    @battle.pbOnBattlerEnteringBattle(user.index)
    switchedBattlers.push(user.index)
    user.effects[PBEffects::Substitute] = oldSub
  end
end

#===============================================================================
# Doodle
#===============================================================================
# User and all allies copy the target's ability.
#-------------------------------------------------------------------------------
class Battle::Move::SetUserAlliesAbilityToTargetAbility < Battle::Move
  def ignoresSubstitute?(user); return true; end
  
  def pbMoveFailed?(user, targets)
    @battle.allSameSideBattlers(user.index).each do |b|
      next if !b.unstoppableAbility?
      @battle.pbDisplay(_INTL("But it failed!"))
      return true
    end
    if user.hasActiveItem?(:ABILITYSHIELD)
      @battle.pbDisplay(_INTL("{1}'s Ability is protected by the effects of its Ability Shield!",user.pbThis))
      return true
    end
    return false
  end

  def pbFailsAgainstTarget?(user, target, show_message)
    if !target.ability || user.ability == target.ability
      @battle.pbDisplay(_INTL("But it failed!")) if show_message
      return true
    end
    if target.uncopyableAbility?
      @battle.pbDisplay(_INTL("But it failed!")) if show_message
      return true
    end
    return false
  end
  
  def pbEffectAgainstTarget(user, target)
    @battle.allSameSideBattlers(user).each do |b|
	  next if b.ability == target.ability
      if b.hasActiveItem?(:ABILITYSHIELD)
        @battle.pbDisplay(_INTL("{1}'s Ability is protected by the effects of its Ability Shield!", b.pbThis))
      else
        @battle.pbShowAbilitySplash(b, true, false)
        oldAbil = b.ability
        b.ability = target.ability
        @battle.pbReplaceAbilitySplash(b)
        @battle.pbDisplay(_INTL("{1} copied {2}'s {3}!",
                            user.pbThis, target.pbThis(true), target.abilityName))
        @battle.pbHideAbilitySplash(b)
        b.pbOnLosingAbility(oldAbil)
        b.pbTriggerAbilityOnGainingIt
      end
    end
  end
end

#===============================================================================
# Revival Blessing
#===============================================================================
# Revive one fainted Pokemon from party with up to 1/2 its total HP.
#-------------------------------------------------------------------------------
class Battle::Move::RevivePokemonHalfHP < Battle::Move
  def healingMove?; return true; end
  
  def pbMoveFailed?(user, targets)
    @numFainted = 0
    user.battle.pbParty(user.idxOwnSide).each { |b| @numFainted += 1 if b.fainted? }
    if @numFainted == 0
      @battle.pbDisplay(_INTL("But it failed!"))
      return true
    end
    return false
  end
  
  def pbEndOfMoveUsageEffect(user, targets, numHits, switchedBattlers)
    return if user.fainted? || @numFainted == 0
    @battle.pbReviveInParty(user.index)
  end
end

#===============================================================================
# Blazing Torque
#===============================================================================
# Burns the target.
#-------------------------------------------------------------------------------
class Battle::Move::StarmobileBurnTarget < Battle::Move::BurnTarget
end

#===============================================================================
# Noxious Torque
#===============================================================================
# Poisons the target.
#-------------------------------------------------------------------------------
class Battle::Move::StarmobilePoisonTarget < Battle::Move::PoisonTarget
end

#===============================================================================
# Combat Torque
#===============================================================================
# Paralyzes the target.
#-------------------------------------------------------------------------------
class Battle::Move::StarmobileParalyzeTarget < Battle::Move::ParalyzeTarget
end

#===============================================================================
# Wicked Torque
#===============================================================================
# Puts the target to sleep.
#-------------------------------------------------------------------------------
class Battle::Move::StarmobileSleepTarget < Battle::Move::SleepTarget
end

#===============================================================================
# Magical Torque
#===============================================================================
# Confuses the target.
#-------------------------------------------------------------------------------
class Battle::Move::StarmobileConfuseTarget < Battle::Move::ConfuseTarget
end