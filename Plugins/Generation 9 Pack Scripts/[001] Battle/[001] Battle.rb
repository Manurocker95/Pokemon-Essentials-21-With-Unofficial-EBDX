################################################################################
# 
# Battle class changes.
# 
################################################################################


class Battle
  attr_accessor :abils_triggered # Used to track any once-per-battle ability triggers for each Pokemon.
  attr_accessor :rage_hit_count  # Used to track the number of hits that have been taken for Rage Fist.
  attr_accessor :fainted_count   # Used to track the number of fainted battlers for Last Respects/Supreme Overlord.
  attr_accessor :sideStatUps     # Used to tally up the number of stat boosts to mirror with Opportunist/Mirror Herb.

  #-----------------------------------------------------------------------------
  # Initializes new battle properties.
  #-----------------------------------------------------------------------------
  alias paldean_initialize initialize
  def initialize(scene, p1, p2, player, opponent)
    paldean_initialize(scene, p1, p2, player, opponent)
    @abils_triggered = [Array.new(@party1.length, false), Array.new(@party2.length, false)]
    @rage_hit_count  = [Array.new(@party1.length, 0), Array.new(@party2.length, 0)]
    @fainted_count   = [0, 0]
    @sideStatUps     = [{}, {}]
  end
  
  #-----------------------------------------------------------------------------
  # Various utilities.
  #-----------------------------------------------------------------------------
  def pbAbilityTriggered?(battler)
    return @abils_triggered[battler.index & 1][battler.pokemonIndex]
  end
  
  def pbSetAbilityTrigger(battler, value = true)
    @abils_triggered[battler.index & 1][battler.pokemonIndex] = value
  end
  
  def pbAddRageHit(battler, value = 1)
    @rage_hit_count[battler.index & 1][battler.pokemonIndex] += value
  end
  
  def pbRageHitCount(battler)
    return @rage_hit_count[battler.index & 1][battler.pokemonIndex]
  end
  
  def pbAddFaintedAlly(idxBattler)
    idxBattler = idxBattler.index if idxBattler.respond_to?("index")
    @fainted_count[idxBattler & 1] += 1 if @fainted_count[idxBattler & 1] < 100
  end
  
  def pbFaintedAllyCount(idxBattler)
    idxBattler = idxBattler.index if idxBattler.respond_to?("index")
    return @fainted_count[idxBattler & 1]
  end
  
  #-----------------------------------------------------------------------------
  # Aliased to skip Tatsugiri's commands while in Dondozo's mouth.
  #-----------------------------------------------------------------------------
  alias paldea_pbCanShowCommands? pbCanShowCommands?
  def pbCanShowCommands?(idxBattler)
    return false if @battlers[idxBattler].isCommander?
    return paldea_pbCanShowCommands?(idxBattler)
  end
  
  #-----------------------------------------------------------------------------
  # Aliased to ensure Pokemon affected by Commander cannot switch out for any reason.
  #-----------------------------------------------------------------------------
  alias paldea_pbCanSwitch? pbCanSwitch?
  def pbCanSwitch?(idxBattler, idxParty = -1, partyScene = nil)
    ret = paldea_pbCanSwitch?(idxBattler, idxParty, partyScene)
    if ret && @battlers[idxBattler].effects[PBEffects::Commander]
      partyScene&.pbDisplay(_INTL("{1} can't be switched out!", @battlers[idxBattler].pbThis))
      return false
    end
    return ret
  end

  #-----------------------------------------------------------------------------
  # Aliased to ensure Pokemon affected by Commander cannot shift positions.
  #-----------------------------------------------------------------------------
  alias paldea_pbCanShift? pbCanShift?
  def pbCanShift?(idxBattler)
    ret = paldea_pbCanShift?(idxBattler)
    if ret
      idxOther = -1
      case pbSideSize(idxBattler)
      when 2
        idxOther = (idxBattler + 2) % 4
      when 3
        idxOther = (idxBattler.even?) ? 2 : 3
      end
      return false if @battlers[idxBattler].effects[PBEffects::Commander] || 
                      @battlers[idxOther].effects[PBEffects::Commander]
    end
    return ret
  end

  #-----------------------------------------------------------------------------
  # Counts down the remaining turns of the Splinter effect until its reset.
  #-----------------------------------------------------------------------------
  alias paldea_pbEOREndBattlerEffects pbEOREndBattlerEffects
  def pbEOREndBattlerEffects(priority)
    paldea_pbEOREndBattlerEffects(priority)
    pbEORCountDownBattlerEffect(priority, PBEffects::Splinters) { |battler|
      pbDisplay(_INTL("{1} was freed from the jagged splinters!", battler.pbThis))
      battler.effects[PBEffects::SplintersType] = nil
    }
  end

  #-----------------------------------------------------------------------------
  # Aliased to add Syrupy effect.
  #-----------------------------------------------------------------------------
  alias paldea_pbEOREndBattlerSelfEffects pbEOREndBattlerSelfEffects
  def pbEOREndBattlerSelfEffects(battler)
    paldea_pbEOREndBattlerSelfEffects(battler)
    return if battler.fainted?
    if battler.effects[PBEffects::Syrupy] > 0
      pbCommonAnimation("Syrupy", battler)
      battler.effects[PBEffects::Syrupy] -= 1
      battler.pbLowerStatStage(:SPEED, 1, battler) if battler.pbCanLowerStatStage?(:SPEED)
      pbDisplay(_INTL("{1} was freed from the sticky candy syrup!", battler.pbThis)) if battler.effects[PBEffects::Syrupy] == 0
    end
  end
  
  #-----------------------------------------------------------------------------
  # Aliased to add splinters and Salt Cure effect damage.
  #-----------------------------------------------------------------------------
  alias paldea_pbEOREffectDamage pbEOREffectDamage
  def pbEOREffectDamage(priority)
    paldea_pbEOREffectDamage(priority)
    priority.each do |battler|
      next if battler.effects[PBEffects::Splinters] == 0 || !battler.takesIndirectDamage?
      pbCommonAnimation("Splinters", battler)
      battlerTypes = battler.pbTypes(true)
      splinterType = battler.effects[PBEffects::SplintersType] || :QMARKS
      effectiveness = [1, Effectiveness.calculate(splinterType, *battlerTypes)].max
      damage = ((((2.0 * battler.level / 5) + 2).floor * 25 * battler.attack / battler.defense).floor / 50).floor + 2
      damage *= effectiveness.to_f / Effectiveness::NORMAL_EFFECTIVE
      battler.pbTakeEffectDamage(damage) { |hp_lost|
        pbDisplay(_INTL("{1} is hurt by the jagged splinters!", battler.pbThis))
      }
    end
    priority.each do |battler|
      next if !battler.effects[PBEffects::SaltCure] || !battler.takesIndirectDamage?
      pbCommonAnimation("SaltCure", battler)
      fraction = (battler.pbHasType?(:STEEL) || battler.pbHasType?(:WATER)) ? 4 : 8
      battler.pbTakeEffectDamage(battler.totalhp / fraction) { |hp_lost|
        pbDisplay(_INTL("{1} is hurt by Salt Cure!", battler.pbThis))
      }
    end
  end
  
  #-----------------------------------------------------------------------------
  # Resets various effects at the end of round.
  #-----------------------------------------------------------------------------
  alias paldea_pbEndOfRoundPhase pbEndOfRoundPhase
  def pbEndOfRoundPhase
    paldea_pbEndOfRoundPhase
    allBattlers.each_with_index do |battler, i|
	  battler.effects[PBEffects::AllySwitch]     = false
	  battler.effects[PBEffects::BurningBulwark] = false
      if Settings::MECHANICS_GENERATION >= 9
        battler.effects[PBEffects::Charge]   += 1 if battler.effects[PBEffects::Charge]     > 0
      end
      battler.effects[PBEffects::GlaiveRush] -= 1 if battler.effects[PBEffects::GlaiveRush] > 0
    end
  end
  
  #-----------------------------------------------------------------------------
  # Adds counter for Bisharp -> Kingambit evolution method.
  #-----------------------------------------------------------------------------
  alias paldea_pbSetDefeated pbSetDefeated
  def pbSetDefeated(battler)
    paldea_pbSetDefeated(battler)
    return if !battler || !@internalBattle || battler.lastFoeAttacker.empty?
    attacker = @battlers[battler.lastFoeAttacker.last]
    return if !attacker.pbOwnedByPlayer?
    return if attacker.species != battler.species
    attacker.pokemon.leaders_crest_evolution(battler.item_id)
  end
  
  #-----------------------------------------------------------------------------
  # Used to revive a party Pokemon with Revival Blessing.
  #-----------------------------------------------------------------------------
  def pbReviveInParty(idxBattler, canCancel = false)
    party_index = -1
    if pbOwnedByPlayer?(idxBattler)
      @scene.pbPartyScreen(idxBattler, canCancel, 2) { |idxParty, partyScene|
        party_index = idxParty
        next true
      }
    else
      party_index = @battleAI.choose_best_revive_pokemon(idxBattler, pbParty(idxBattler))
    end
    return if party_index < 0
    party = pbParty(idxBattler)
    pkmn = party[party_index]
    pkmn.hp = [1, (pkmn.totalhp / 2).floor].max
    pkmn.heal_status
    displayname = (pbOwnedByPlayer?(idxBattler)) ? pkmn.name : _INTL("The opposing {1}", pkmn.name)
    pbDisplay(_INTL("{1} was revived and is ready to fight again!", displayname))
  end
end


################################################################################
# 
# Battle::Move class changes.
# 
################################################################################


class Battle::Move
  #-----------------------------------------------------------------------------
  # New move flags.
  #-----------------------------------------------------------------------------
  def windMove?;        return @flags.any? { |f| f[/^Wind$/i] };            end
  def slicingMove?;     return @flags.any? { |f| f[/^Slicing$/i] };         end
  def electrocuteUser?; return @flags.any? { |f| f[/^ElectrocuteUser$/i] }; end

  #-----------------------------------------------------------------------------
  # Aliased to add Mind's Eye effect.
  #-----------------------------------------------------------------------------  
  alias paldea_pbCalcTypeModSingle pbCalcTypeModSingle
  def pbCalcTypeModSingle(moveType, defType, user, target)
    ret = paldea_pbCalcTypeModSingle(moveType, defType, user, target)
    if Effectiveness.ineffective_type?(moveType, defType)
      if user.hasActiveAbility?(:MINDSEYE) && defType == :GHOST
        ret = Effectiveness::NORMAL_EFFECTIVE_MULTIPLIER
      end
    end
    return ret
  end

  #-----------------------------------------------------------------------------
  # Aliased to add Tera Shell effect.
  #-----------------------------------------------------------------------------  
  alias paldea_pbCalcTypeMod pbCalcTypeMod
  def pbCalcTypeMod(moveType, user, target)
    ret = Effectiveness::NORMAL_EFFECTIVE_MULTIPLIER
    return ret if !moveType
    ret = paldea_pbCalcTypeMod(moveType, user, target)
    if target.abilityActive?
      ret = Battle::AbilityEffects.triggerModifyTypeEffectiveness(
	    target.ability, user, target, self, @battle, ret)
    end
    return ret
  end

  #-----------------------------------------------------------------------------
  # Aliased to add type displays for certain moves that change type.
  #-----------------------------------------------------------------------------  
  alias paldea_display_type display_type
  def display_type(battler)
    case @function_code
    when "TypeDependsOnUserPlate",            # Judgement
         "TypeIsUserSecondType",              # Ivy Cudgel
         "TypeIsUserSecondTypeRemoveScreens"  # Raging Bull
      return pbBaseType(battler)
    else
      return paldea_display_type(battler)
    end
  end
  
  #-----------------------------------------------------------------------------
  # -Aliased to reset various checks upon using a move.
  # -Adds counter for Primeape -> Annihilape evolution method (and others).
  #-----------------------------------------------------------------------------
  alias paldea_pbChangeUsageCounters pbChangeUsageCounters
  def pbChangeUsageCounters(user, specialUsage)
    paldea_pbChangeUsageCounters(user, specialUsage)
    user.proteanTrigger = true
    user.effects[PBEffects::GlaiveRush] = 0
    user.effects[PBEffects::SuccessiveMove] = nil if user.effects[PBEffects::SuccessiveMove] != @id
    user.pokemon.move_count_evolution(@id) if user.pbOwnedByPlayer?
  end
  
  #-----------------------------------------------------------------------------
  # Adds Punching Glove effect to prevent contact for punching moves.
  #-----------------------------------------------------------------------------
  alias paldea_pbContactMove? pbContactMove?
  def pbContactMove?(user)
    return false if user.hasActiveItem?(:PUNCHINGGLOVE) && punchingMove?
    return paldea_pbContactMove?(user)
  end
 
  #-----------------------------------------------------------------------------
  # -Aliased to add Covert Cloak effect to block additional effects.
  # -Moves that may cause Frostbite have an increased chance to do so in Hail/Snow.
  #-----------------------------------------------------------------------------
  alias paldea_pbAdditionalEffectChance pbAdditionalEffectChance
  def pbAdditionalEffectChance(user, target, effectChance = 0)
    return 0 if target.hasActiveItem?(:COVERTCLOAK)
    ret = paldea_pbAdditionalEffectChance(user, target, effectChance)
    return ret if [0, 100].include?(ret)
    if @battle.pbWeather == :Hail &&
       (@function_code.include?("FrostbiteTarget") ||
       (Settings::FREEZE_EFFECTS_CAUSE_FROSTBITE && @function_code.include?("FreezeTarget")))
      ret *= 2
    end
    return [ret, 100].min
  end

  alias paldea_pbFlinchChance pbFlinchChance
  def pbFlinchChance(user, target)
    return 0 if target.hasActiveItem?(:COVERTCLOAK)
    return paldea_pbFlinchChance(user, target)
  end
  
  #-----------------------------------------------------------------------------
  # Aliased for accuracy checks on targets with certain effects.
  # -Moves on Pokemon who's Commander ability is currently active always miss.
  # -Moves on Pokemon who are under the negative effects of Glaive Rush always hit.
  #-----------------------------------------------------------------------------
  alias paldea_pbAccuracyCheck pbAccuracyCheck
  def pbAccuracyCheck(user, target)
    return false if target.isCommander?
    return true if target.effects[PBEffects::GlaiveRush] > 0
    return paldea_pbAccuracyCheck(user, target)
  end
  
  #-----------------------------------------------------------------------------
  # Aliased to add a variety of new effects that affect damage calculation.
  #  -Applies the effects of the various "of Ruin" abilities.
  #  -Calculates the power of Psyblade in Electric Terrain.
  #  -Calculates the power of Hydro Steam in Sun.
  #  -Increases the Defense of Ice-types during Snow weather (Gen 9 version).
  #  -Halves the damage dealt by special attacks if the user has the Frostbite status.
  #  -Increases damage taken if the targer has the Drowsy status.
  #  -Doubles damage taken by a target still vulnerable due to Glaive Rush's effect.
  #-----------------------------------------------------------------------------
  alias paldea_pbCalcDamageMultipliers pbCalcDamageMultipliers
  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    # "of Ruin" abilities
    [:TABLETSOFRUIN, :SWORDOFRUIN, :VESSELOFRUIN, :BEADSOFRUIN].each_with_index do |ability, i|
      next if !@battle.pbCheckGlobalAbility(ability)
      category = (i < 2) ? physicalMove? : specialMove?
      category = !category if i.odd? && @battle.field.effects[PBEffects::WonderRoom] > 0
      if i.even? && !user.hasActiveAbility?(ability)
        multipliers[:attack_multiplier] *= 0.75 if category
      elsif i.odd? && !target.hasActiveAbility?(ability)
        multipliers[:defense_multiplier] *= 0.75 if category
      end
    end
    if @battle.field.terrain == :Electric && user.affectedByTerrain? &&
       @function_code == "IncreasePowerInElectricTerrain"
      multipliers[:power_multiplier] *= 1.5 if type != :ELECTRIC
    end
    case user.effectiveWeather
    when :Sun, :HarshSun
      if @function_code == "IncreasePowerInSunWeather"
        multipliers[:final_damage_multiplier] *= (type == :FIRE) ? 1 : (type == :WATER) ? 3 : 1.5
      end
    when :Hail
      if Settings::HAIL_WEATHER_TYPE > 0 && target.pbHasType?(:ICE) && 
         (physicalMove? || @function_code == "UseTargetDefenseInsteadOfTargetSpDef")
        multipliers[:defense_multiplier] *= 1.5
      end
    end
    # Frostbite
    if user.status == :FROSTBITE && specialMove?
      multipliers[:final_damage_multiplier] /= 2
    end
    # Drowsy
    if target.status == :DROWSY
      multipliers[:final_damage_multiplier] *= 4 / 3.0
    end
    # Glaive Rush
    multipliers[:final_damage_multiplier] *= 2 if target.effects[PBEffects::GlaiveRush] > 0
    paldea_pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
  end
end


################################################################################
# 
# Battle::Scene class changes.
# 
################################################################################


class Battle::Scene
  #-----------------------------------------------------------------------------
  # Overwritten to allow for selection of a target for Revival Blessing.
  #-----------------------------------------------------------------------------
  def pbPartyScreen(idxBattler, canCancel = false, mode = 0)
    visibleSprites = pbFadeOutAndHide(@sprites)
    partyPos = @battle.pbPartyOrder(idxBattler)
    partyStart, _partyEnd = @battle.pbTeamIndexRangeFromBattlerIndex(idxBattler)
    modParty = @battle.pbPlayerDisplayParty(idxBattler)
    scene = PokemonParty_Scene.new
    switchScreen = PokemonPartyScreen.new(scene, modParty)
    msg = _INTL("Choose a Pokémon.")
    msg = _INTL("Send which Pokémon to Boxes?") if mode == 1
    switchScreen.pbStartScene(msg, @battle.pbNumPositions(0, 0))
    loop do
      scene.pbSetHelpText(msg)
      idxParty = switchScreen.pbChoosePokemon
      if idxParty < 0
        next if !canCancel
        break
      end
      cmdSwitch  = -1
      cmdBoxes   = -1
      cmdSelect  = -1
      cmdSummary = -1
      commands = []
      commands[cmdSwitch  = commands.length] = _INTL("Switch In") if mode == 0 && modParty[idxParty].able?
      commands[cmdBoxes   = commands.length] = _INTL("Send to Boxes") if mode == 1
      commands[cmdSelect  = commands.length] = _INTL("Select") if mode == 2 && modParty[idxParty].fainted?
      commands[cmdSummary = commands.length] = _INTL("Summary")
      commands[commands.length]              = _INTL("Cancel")
      command = scene.pbShowCommands(_INTL("Do what with {1}?", modParty[idxParty].name), commands)
      if (cmdSwitch >= 0 && command == cmdSwitch) ||   # Switch In
         (cmdBoxes >= 0 && command == cmdBoxes)   ||   # Send to Boxes
         (cmdSelect >= 0 && command == cmdSelect)      # Select for Revival Blessing
        idxPartyRet = -1
        partyPos.each_with_index do |pos, i|
          next if pos != idxParty + partyStart
          idxPartyRet = i
          break
        end
        break if yield idxPartyRet, switchScreen
      elsif cmdSummary >= 0 && command == cmdSummary
        scene.pbSummary(idxParty, true)
      end
    end
    switchScreen.pbEndScene
    pbFadeInAndShow(@sprites, visibleSprites)
  end
  
  #-----------------------------------------------------------------------------
  # Aliased to keep Tatsugiri's sprite hidden during Commander.
  #-----------------------------------------------------------------------------
  alias paldea_pbCommonAnimation pbCommonAnimation
  def pbCommonAnimation(animName, user = nil, target = nil)
    return if user && user.isCommander?
    target = target[0] if target.is_a?(Array)
    return if target && target.isCommander?
    paldea_pbCommonAnimation(animName, user, target)  
  end
end

################################################################################
# 
# Battle::DamageState class changes.
# 
################################################################################
class Battle::DamageState
  attr_accessor :terashell # Tera Shell ability used

  alias paldea_reset reset
  def reset
    @terashell = false
    paldea_reset
  end
end