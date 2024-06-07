################################################################################
# 
# Battle::Battler class changes.
# 
################################################################################


class Battle::Battler
  attr_accessor :proteanTrigger  # Used to flag when it's okay for Protean/Libero to trigger.
  attr_accessor :mirrorHerbUsed  # Used to stop Opportunist/Mirror Herb from triggering off other Mirror Herbs.
  attr_accessor :legendPlateType # Stores the default type to display for Judgment when used with a Legend Plate.

  alias paldea_pbInitEffects pbInitEffects
  def pbInitEffects(batonPass)
    paldea_pbInitEffects(batonPass)
    @effects[PBEffects::AllySwitch]      = false
    @effects[PBEffects::BoosterEnergy]   = false
    @effects[PBEffects::BurningBulwark]  = false
    @effects[PBEffects::Commander]       = nil
    @effects[PBEffects::CudChew]         = 0
    @effects[PBEffects::DoubleShock]     = false
    @effects[PBEffects::GlaiveRush]      = 0
    @effects[PBEffects::ParadoxStat]     = nil
    @effects[PBEffects::OneUseAbility]   = nil
    @effects[PBEffects::SaltCure]        = false
    @effects[PBEffects::Splinters]       = 0
    @effects[PBEffects::SplintersType]   = nil
    @effects[PBEffects::SilkTrap]        = false
    @effects[PBEffects::SuccessiveMove]  = nil
    @effects[PBEffects::SupremeOverlord] = 0
    @effects[PBEffects::Syrupy]          = 0
    @effects[PBEffects::SyrupyUser]      = -1
    @battle.allBattlers.each do |b|
      next if b.effects[PBEffects::SyrupyUser] != @index
      b.effects[PBEffects::Syrupy] = 0
      b.effects[PBEffects::SyrupyUser] = -1
    end
    @proteanTrigger  = false
    @mirrorHerbUsed  = false
    @legendPlateType = nil
  end
  
  def ability_triggered?
    return @battle.pbAbilityTriggered?(self)
  end
  
  def num_times_hit
    return @battle.pbRageHitCount(self)
  end
  
  def num_fainted_allies
    return @battle.pbFaintedAllyCount(self)
  end


  ##############################################################################
  # Related to battler typing.
  ##############################################################################


  #-----------------------------------------------------------------------------
  # Aliased for Double Shock effect.
  #-----------------------------------------------------------------------------
  alias paldea_pbTypes pbTypes
  def pbTypes(withType3 = false)
    ret = paldea_pbTypes(withType3)
    ret.delete(:ELECTRIC) if @effects[PBEffects::DoubleShock]
    return ret
  end
  
  alias paldea_pbChangeTypes pbChangeTypes
  def pbChangeTypes(newType)
    paldea_pbChangeTypes(newType)
    @effects[PBEffects::DoubleShock] = false
    if abilityActive? && @proteanTrigger # Protean/Libero
      Battle::AbilityEffects.triggerOnTypeChange(self.ability, self, newType)
    end 
  end

  alias paldea_pbResetTypes pbResetTypes
  def pbResetTypes
    paldea_pbResetTypes
    @effects[PBEffects::DoubleShock] = false
  end
  
  
  ##############################################################################
  # Related to changing stats.
  ##############################################################################
  

  #-----------------------------------------------------------------------------
  # Aliased for Clear Amulet checks.
  #-----------------------------------------------------------------------------
  alias paldea_pbCanLowerStatStage? pbCanLowerStatStage?
  def pbCanLowerStatStage?(*args)
    return false if fainted?
    if !args[1] || args[1].index != @index
      if itemActive?
        return false if Battle::ItemEffects.triggerStatLossImmunity(self.item, self, args[0], @battle, args[3])
      end
    end
    return paldea_pbCanLowerStatStage?(*args)
  end
  
  alias paldea_pbLowerAttackStatStageIntimidate pbLowerAttackStatStageIntimidate
  def pbLowerAttackStatStageIntimidate(user)
    return false if fainted?
    if !hasActiveAbility?(:CONTRARY) && @effects[PBEffects::Substitute] == 0
      if itemActive? && Battle::ItemEffects.triggerStatLossImmunity(self.item, self, :ATTACK, @battle, true)
        return false
      end
    end
    return paldea_pbLowerAttackStatStageIntimidate(user)
  end
  
  #-----------------------------------------------------------------------------
  # Aliased for Guard Dog.
  #-----------------------------------------------------------------------------
  alias paldea_pbLowerStatStageByAbility pbLowerStatStageByAbility
  def pbLowerStatStageByAbility(stat, increment, user, splashAnim = true, checkContact = false)
    if hasActiveAbility?(:GUARDDOG) && user.ability == :INTIMIDATE
      return pbRaiseStatStageByAbility(stat, increment, self, true)
    end
    return paldea_pbLowerStatStageByAbility(stat, increment, user, splashAnim)
  end
  
  #-----------------------------------------------------------------------------
  # Aliased for Opportunist and Mirror Herb checks.
  #-----------------------------------------------------------------------------
  alias paldea_pbRaiseStatStage pbRaiseStatStage
  def pbRaiseStatStage(*args)
    ret = paldea_pbRaiseStatStage(*args)
    if ret && !@mirrorHerbUsed && !(hasActiveAbility?(:CONTRARY) && !args[4] && !@battle.moldBreaker)
      addSideStatUps(args[0], args[1])
    end
    return ret
  end
  
  alias paldea_pbRaiseStatStageByCause pbRaiseStatStageByCause
  def pbRaiseStatStageByCause(*args)
    ret = paldea_pbRaiseStatStageByCause(*args)
    if ret && !@mirrorHerbUsed && !(hasActiveAbility?(:CONTRARY) && !args[5] && !@battle.moldBreaker)
      addSideStatUps(args[0], args[1]) 
    end
    return ret
  end
  
  alias paldea_pbRaiseStatStageByAbility pbRaiseStatStageByAbility
  def pbRaiseStatStageByAbility(*args)
    ret = paldea_pbRaiseStatStageByAbility(*args)
    pbMirrorStatUpsOpposing
    return ret
  end
  
  #-----------------------------------------------------------------------------
  # Used for triggering and consuming Mirror Herb.
  #-----------------------------------------------------------------------------
  def pbItemOpposingStatGainCheck(statUps, item_to_use = nil)
    return if fainted?
    return if !item_to_use && !itemActive?
    itm = item_to_use || self.item
    if Battle::ItemEffects.triggerOnOpposingStatGain(itm, self, @battle, statUps, !item_to_use)
      pbHeldItemTriggered(itm, item_to_use.nil?, false)
    end
  end
  
  #-----------------------------------------------------------------------------
  # General proc for Opportunist and Mirror Herb.
  #-----------------------------------------------------------------------------
  def pbMirrorStatUpsOpposing
    statUps = @battle.sideStatUps[self.idxOwnSide]
    return if fainted? || statUps.empty?
    @battle.allOtherSideBattlers(@index).each do |b|
      next if !b || b.fainted?
      if b.abilityActive?
        Battle::AbilityEffects.triggerOnOpposingStatGain(b.ability, b, @battle, statUps)
      end
      if b.itemActive?
        b.pbItemOpposingStatGainCheck(statUps)
      end
    end
    statUps.clear
  end
  
  #-----------------------------------------------------------------------------
  # Used to tally up the amount of stats raised on each side.
  #-----------------------------------------------------------------------------
  def addSideStatUps(stat, increment)
    statUps = @battle.sideStatUps[self.idxOwnSide]
    statUps[stat] = 0 if !statUps[stat]
    statUps[stat] += increment
  end
  

  ##############################################################################
  # Related to battler ability checks.
  ##############################################################################
  
  
  #-----------------------------------------------------------------------------
  # Aliased to add Gen 9 unstoppable abilities to blacklist.
  #-----------------------------------------------------------------------------
  alias paldea_unstoppableAbility? unstoppableAbility?
  def unstoppableAbility?(abil = nil)
    abil = @ability_id if !abil
    abil = GameData::Ability.try_get(abil)
    return false if !abil
    return true if paldea_unstoppableAbility?(abil)
    return [  
      :ZEROTOHERO,
      :TERASHIFT
    ].include?(abil.id)
  end
  
  #-----------------------------------------------------------------------------
  # Aliased to add Gen 9 ungainable abilities to blacklist.
  #-----------------------------------------------------------------------------
  alias paldea_ungainableAbility? ungainableAbility?
  def ungainableAbility?(abil = nil)
    abil = @ability_id if !abil
    abil = GameData::Ability.try_get(abil)
    return false if !abil
    return true if paldea_ungainableAbility?(abil)
    return [
      :WONDERGUARD,
      :HUNGERSWITCH,
      :COMMANDER,
      :PROTOSYNTHESIS,
      :QUARKDRIVE,	  
      :ZEROTOHERO,
      :EMBODYASPECT,
      :EMBODYASPECT_1,
      :EMBODYASPECT_2,
      :EMBODYASPECT_3,
      :TERASHIFT,
      :TERAFORMZERO,
      :POISONPUPPETEER
    ].include?(abil.id)
  end
  
  #-----------------------------------------------------------------------------
  # Returns true if ability cannot be copied.
  #-----------------------------------------------------------------------------
  def uncopyableAbility?(abil = nil)
    abil = @ability_id if !abil
    abil = GameData::Ability.try_get(abil)
    return false if !abil
    return true if ungainableAbility?(abil)
    return [
      :POWEROFALCHEMY,
      :RECEIVER,
      :TRACE
    ].include?(abil.id)
  end
  
  #-----------------------------------------------------------------------------
  # Specifically used to check for an Ability Shield for Neutralizing Gas.
  #-----------------------------------------------------------------------------
  def activeAbilityShield?(check_ability)
    return false if fainted?
    return false if self.item != :ABILITYSHIELD
    return false if @effects[PBEffects::Embargo] > 0
    return false if @battle.field.effects[PBEffects::MagicRoom] > 0
    return false if @battle.corrosiveGas[@index % 2][@pokemonIndex]
    return false if check_ability == :KLUTZ || self.ability == :KLUTZ
    return true
  end
  
  #-----------------------------------------------------------------------------
  # -Edited to ensure the trigger of Gen 9 versions of certain abilities.
  # -Allows the Ability Shield to ignore Neutralizing Gas.
  #-----------------------------------------------------------------------------
  def abilityActive?(ignore_fainted = false, check_ability = nil)
    return false if fainted? && !ignore_fainted
    if Settings::MECHANICS_GENERATION >= 9
      return true if !check_ability && self.ability == :BATTLEBOND
      if @proteanTrigger && self.ability == @effects[PBEffects::OneUseAbility]
        return false if !check_ability || check_ability == self.ability
        return false if check_ability.is_a?(Array) && check_ability.include?(@ability_id)
      end
    end
    return false if @effects[PBEffects::GastroAcid]
    return false if check_ability != :NEUTRALIZINGGAS && self.ability != :NEUTRALIZINGGAS &&
                    !activeAbilityShield?(check_ability) && @battle.pbCheckGlobalAbility(:NEUTRALIZINGGAS)
    return true
  end
  
  #-----------------------------------------------------------------------------
  # Aliased for new continuous ability checks.
  #-----------------------------------------------------------------------------
  alias paldea_pbContinualAbilityChecks pbContinualAbilityChecks
  def pbContinualAbilityChecks(onSwitchIn = false)
    @battle.pbEndPrimordialWeather
    if hasActiveAbility?(:COMMANDER)
      Battle::AbilityEffects.triggerOnSwitchIn(self.ability, self, @battle)
    end
    @proteanTrigger = false
    plateType = pbGetJudgmentType(@legendPlateType)
    @legendPlateType = plateType
    if hasActiveAbility?(:TRACE) && hasActiveItem?(:ABILITYSHIELD)
      @battle.pbShowAbilitySplash(self)
      @battle.pbDisplay(_INTL("{1}'s Ability is protected by the effects of its Ability Shield!", pbThis))
      @battle.pbHideAbilitySplash(self)
    else
      paldea_pbContinualAbilityChecks(onSwitchIn)
    end
    pbMirrorStatUpsOpposing
  end
  
  #-----------------------------------------------------------------------------
  # Aliased for Protosynthesis checks whenever weather is changed.
  #-----------------------------------------------------------------------------
  alias paldea_pbCheckFormOnWeatherChange pbCheckFormOnWeatherChange
  def pbCheckFormOnWeatherChange(ability_changed = false)
    if hasActiveAbility?(:PROTOSYNTHESIS)
      Battle::AbilityEffects.triggerOnSwitchIn(self.ability, self, @battle, false)
    end
    paldea_pbCheckFormOnWeatherChange(ability_changed)
  end
  
  #-----------------------------------------------------------------------------
  # Aliased to include Terapagos's Tera Shift form change.
  #-----------------------------------------------------------------------------
  alias paldea_pbCheckForm pbCheckForm
  def pbCheckForm(endOfRound = false)
    return if fainted? || @effects[PBEffects::Transform]
    if isSpecies?(:TERAPAGOS) && self.ability == :TERASHIFT
      if @form == 0
        @battle.pbShowAbilitySplash(self, true)
        @battle.pbHideAbilitySplash(self)
        pbChangeForm(1, _INTL("{1} transformed!", pbThis))
      end
    end
    paldea_pbCheckForm(endOfRound)
  end
  
  #-----------------------------------------------------------------------------
  # Commander utilities.
  #-----------------------------------------------------------------------------
  def isCommander?
    commander = @effects[PBEffects::Commander]
    return commander && commander.length == 1
  end
  
  def isCommanderHost?
    commander = @effects[PBEffects::Commander]
    return commander && commander.length == 2
  end  
  
  #-----------------------------------------------------------------------------
  # Aliased to prevent Pokemon under the effects of Commander from switching.
  #-----------------------------------------------------------------------------
  alias paldea_trappedInBattle? trappedInBattle?
  def trappedInBattle?
    return true if @effects[PBEffects::Commander]
    return paldea_trappedInBattle?
  end
  
  #-----------------------------------------------------------------------------
  # -Aliased to end the effects of Commander when one of the pair faints
  # -Adds to the number of fainted party members this battle.
  #-----------------------------------------------------------------------------
  alias paldea_pbFaint pbFaint
  def pbFaint(showMessage = true)
    commanderMsg = nil
    if @effects[PBEffects::Commander]
      pairedBattler = @battle.battlers[@effects[PBEffects::Commander][0]]
      if pairedBattler&.effects[PBEffects::Commander]
        if isCommander?
          order = [pbThis, pairedBattler.pbThis(true)]
        else
          order = [pairedBattler.pbThis, pbThis(true)]
          pairedBattler.effects[PBEffects::Commander] = nil
        end
        commanderMsg = _INTL("{1} comes out of {2}'s mouth!", *order)
        batSprite = @battle.scene.sprites["pokemon_#{pairedBattler.index}"]
      end
    end
    isFainted = @fainted
    paldea_pbFaint(showMessage)
    @battle.pbAddFaintedAlly(self) if !isFainted && @fainted
    if commanderMsg
      @battle.pbDisplay(commanderMsg)
      batSprite.visible = true
    end
  end
  
  #-----------------------------------------------------------------------------
  # Aliased to run initial checks for effects that would ignore abilities.
  #-----------------------------------------------------------------------------
  alias paldea_pbFindTargets pbFindTargets
  def pbFindTargets(choice, move, user)
    targets = paldea_pbFindTargets(choice, move, user)
    if !targets.empty?
      @battle.moldBreaker = user.hasMoldBreaker? || (move.statusMove? && user.hasActiveAbility?(:MYCELIUMMIGHT)) if !@battle.moldBreaker
      @battle.moldBreaker = false if targets[0].hasActiveItem?(:ABILITYSHIELD)
    end
    return targets
  end
  
  alias paldea_pbChangeTargets pbChangeTargets
  def pbChangeTargets(move, user, targets)
    targets = paldea_pbChangeTargets(move, user, targets)
    if !targets.empty?
      @battle.moldBreaker = user.hasMoldBreaker? || (move.statusMove? && user.hasActiveAbility?(:MYCELIUMMIGHT)) if !@battle.moldBreaker
      @battle.moldBreaker = false if targets[0].hasActiveItem?(:ABILITYSHIELD)
    end
    return targets
  end
  
  ##############################################################################
  # Related to battler item usage.
  ##############################################################################
  
  #-----------------------------------------------------------------------------
  # -Aliased so flung berry can triggered Cud Chew Ability.
  #-----------------------------------------------------------------------------
  alias paldea_pbHeldItemTriggered pbHeldItemTriggered
  def pbHeldItemTriggered(item_to_use, own_item = true, fling = false)
    paldea_pbHeldItemTriggered(item_to_use, own_item, fling)
    # Cud Chew
    if hasActiveAbility?(:CUDCHEW) && GameData::Item.get(item_to_use).is_berry? && 
       fling && !own_item
      setRecycleItem(item_to_use)
    end
  end

  ##############################################################################
  # Related to battler move usage.
  ##############################################################################
  
  
  #-----------------------------------------------------------------------------
  # -Aliased so the Charge effect ends only after using an Electric-type move.
  # -Moves that cause electrocution heals Drowsiness.
  # -Moves that cause thawing heals Frostbite.
  #-----------------------------------------------------------------------------
  alias paldea_pbEffectsAfterMove pbEffectsAfterMove
  def pbEffectsAfterMove(user, targets, move, numHits)
    if Settings::MECHANICS_GENERATION >= 9
      user.effects[PBEffects::Charge] = 0 if move.calcType == :ELECTRIC
    end
    if move.damagingMove?
      if user.status == :DROWSY && move.electrocuteUser?
        user.pbCureStatus(false)
        @battle.pbDisplay(_INTL("{1} was shocked wide awake!", user.pbThis))
      end
      if user.status == :FROSTBITE && move.thawsUser?
        user.pbCureStatus(false)
        @battle.pbDisplay(_INTL("{1} warmed up!", user.pbThis))
      end
      targets.each do |b|
        next if b.damageState.unaffected || b.damageState.substitute
        b.pbCureStatus if b.status == :DROWSY && move.electrocuteUser?
        b.pbCureStatus if b.status == :FROSTBITE && move.thawsUser?  
      end
    end
    paldea_pbEffectsAfterMove(user, targets, move, numHits)
  end
  
  #-----------------------------------------------------------------------------
  # -Aliased to power up Rage Fist when struck.
  # -Adds counter for Basculin -> Basculegion evolution method.
  #-----------------------------------------------------------------------------
  alias paldea_pbEffectsOnMakingHit pbEffectsOnMakingHit
  def pbEffectsOnMakingHit(move, user, target)
    paldea_pbEffectsOnMakingHit(move, user, target)
    if target.damageState.calcDamage > 0 && !target.damageState.substitute
      @battle.pbAddRageHit(target)
    end
    if user.pbOwnedByPlayer? && !user.fainted? && move.recoilMove?
      recoil = (defined?(move.pbRecoilDamage(user, target))) ? move.pbRecoilDamage(user, target) : 0
      user.pokemon.recoil_evolution(recoil)
    end
  end
  
  #-----------------------------------------------------------------------------
  # Aliased to copy the number of hits taken by the target when transforming.
  #-----------------------------------------------------------------------------
  alias paldea_pbTransform pbTransform
  def pbTransform(target)
    paldea_pbTransform(target)
    rage_counter = @battle.rage_hit_count[@index & 1][@pokemonIndex]
    rage_counter = @battle.pbRageHitCount(target)
  end
  
  #-----------------------------------------------------------------------------
  # Aliased so Gigaton Hammer/Blood Moon can't be selected consecutively.
  #-----------------------------------------------------------------------------
  alias paldea_pbCanChooseMove? pbCanChooseMove?
  def pbCanChooseMove?(move, commandPhase, showMessages = true, specialUsage = false)
    if !@effects[PBEffects::Instructed] && @lastMoveUsed == move.id &&
	    @effects[PBEffects::SuccessiveMove] == move.id
      if showMessages
        msg = _INTL("{1} can't be used twice in a row!", move.name)
        (commandPhase) ? @battle.pbDisplayPaused(msg) : @battle.pbDisplay(msg)
      end
      return false
    end
    return paldea_pbCanChooseMove?(move, commandPhase, showMessages, specialUsage)
  end
  
  #-----------------------------------------------------------------------------
  # -Aliased to add Silk Trap to move success check.
  # -Rechecks for effects that ignore abilities before running success check.
  #-----------------------------------------------------------------------------
  alias paldea_pbSuccessCheckAgainstTarget pbSuccessCheckAgainstTarget
  def pbSuccessCheckAgainstTarget(move, user, target, targets)
    @battle.moldBreaker = user.hasMoldBreaker? || (move.statusMove? && user.hasActiveAbility?(:MYCELIUMMIGHT)) if !@battle.moldBreaker
    @battle.moldBreaker = false if target.hasActiveItem?(:ABILITYSHIELD)
    if !(user.hasActiveAbility?(:UNSEENFIST) && move.contactMove?)
      if move.canProtectAgainst? && !user.effects[PBEffects::TwoTurnAttack]
        # Silk Trap
        if target.effects[PBEffects::SilkTrap] && move.damagingMove?
          if move.pbShowFailMessages?(targets)
            @battle.pbCommonAnimation("SilkTrap", target)
            @battle.pbDisplay(_INTL("{1} protected itself!", target.pbThis))
          end
          target.damageState.protected = true
          @battle.successStates[user.index].protected = true
          if move.pbContactMove?(user) && user.affectedByContactEffect? &&
             user.pbCanLowerStatStage?(:SPEED, target)
            user.pbLowerStatStage(:SPEED, 1, target)
          end
          return false
        end
        # Burning Bulwark
        if target.effects[PBEffects::BurningBulwark] && move.damagingMove?
          if move.pbShowFailMessages?(targets)
            @battle.pbCommonAnimation("BurningBulwark", target)
            @battle.pbDisplay(_INTL("{1} protected itself!", target.pbThis))
          end
          target.damageState.protected = true
          @battle.successStates[user.index].protected = true
          if move.pbContactMove?(user) && user.affectedByContactEffect? &&
             user.pbCanBurn?(target, false)
            user.pbBurn(target)
          end
          return false
        end
      end
    end
    ret = paldea_pbSuccessCheckAgainstTarget(move, user, target, targets)
    if ret
      Battle::AbilityEffects.triggerOnMoveSuccessCheck(
        target.ability, user, target, move, @battle)
    end
    return ret
  end
end


#===============================================================================
# Safari Zone compatibility.
#===============================================================================
class Battle::FakeBattler
  def isCommander?;     return false; end
  def isCommanderHost?; return false; end
end