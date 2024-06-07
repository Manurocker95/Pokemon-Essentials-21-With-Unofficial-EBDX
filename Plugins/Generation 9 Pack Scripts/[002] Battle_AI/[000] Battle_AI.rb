################################################################################
# 
# Battle::AI class changes.
# 
################################################################################


class Battle::AI
  GEN_9_BASE_ABILITY_RATINGS = {
    9  => [:ORICHALCUMPULSE, :HADRONENGINE],
    8  => [:THERMALEXCHANGE],
    7  => [:EARTHEATER, :TOXICDEBRIS, :PROTOSYNTHESIS, :QUARKDRIVE, :SUPERSWEETSYRUP, :MINDSEYE],
    6  => [:SUPREMEOVERLORD, :SEEDSOWER, :OPPORTUNIST],
    5  => [:ARMORTAIL, :ROCKYPAYLOAD, :SHARPNESS, :LINGERINGAROMA, :CUDCHEW, 
           :TOXICCHAIN, :POISONPUPPETEER],
    4  => [:PURIFYINGSALT, :WELLBAKEDBODY, :ANGERSHELL, :ELECTROMORPHOSIS, :WINDPOWER],
    3  => [:WINDRIDER, :HOSPITALITY,
           :TABLETSOFRUIN, :SWORDOFRUIN, :VESSELOFRUIN, :BEADSOFRUIN
          ],
    1  => [:EMBODYASPECT, :EMBODYASPECT_1, :EMBODYASPECT_2, :EMBODYASPECT_3,
           :TERASHIFT, :TERASHELL, :TERAFORMZERO
          ]

  }

  GEN_9_BASE_ITEM_RATINGS = {
    6  => [ :LEGENDPLATE, :BOOSTERENERGY,
            # Legendary Orbs
            :ADAMANTCRYSTAL, :LUSTROUSGLOBE, :GRISEOUSCORE,
            # Ogerpon Masks
            :WELLSPRINGMASK, :HEARTHFLAMEMASK, :CORNERSTONEMASK
          ],
    5  => [:BLANKPLATE, :PUNCHINGGLOVE, :LOADEDDICE, :FAIRYFEATHER],
    3  => [:HOPOBERRY, :MIRRORHERB, :COVERTCLOAK],
    2  => [:CLEARAMULET],
  }



  #===============================================================================
  # Battle_AI
  #===============================================================================
  # Edited to add a variety of new effects that affect damage calculation.
  #  -Applies the effects of the various "of Ruin" abilities.
  #  -Negates the damage reduction the move Hydro Steam would have in the Sun.
  #  -Increases the Defense of Ice-types during Snow weather (Gen 9 version).
  #  -Halves the damage dealt by special attacks if the user has the Frostbite status.
  #  -Increases damage taken if the targer has the Drowsy status.
  #  -Doubles damage taken by a target still vulnerable due to Glaive Rush's effect.
  #-----------------------------------------------------------------------------
  # Full damage calculation.
  def rough_damage
    base_dmg = base_power
    return base_dmg if @move.is_a?(Battle::Move::FixedDamageMove)
    max_stage = Battle::Battler::STAT_STAGE_MAXIMUM
    stage_mul = Battle::Battler::STAT_STAGE_MULTIPLIERS
    stage_div = Battle::Battler::STAT_STAGE_DIVISORS
    # Get the user and target of this move
    user = @ai.user
    user_battler = user.battler
    target = @ai.target
    target_battler = target.battler
    # Get the move's type
    calc_type = rough_type
    # Decide whether the move has 50% chance of higher of being a critical hit
    crit_stage = rough_critical_hit_stage
    is_critical = crit_stage >= Battle::Move::CRITICAL_HIT_RATIOS.length ||
                  Battle::Move::CRITICAL_HIT_RATIOS[crit_stage] <= 2
    ##### Calculate user's attack stat #####
    if ["CategoryDependsOnHigherDamagePoisonTarget",
        "CategoryDependsOnHigherDamageIgnoreTargetAbility"].include?(function_code)
      @move.pbOnStartUse(user.battler, [target.battler])   # Calculate category
    end
    atk, atk_stage = @move.pbGetAttackStats(user.battler, target.battler)
    if !target.has_active_ability?(:UNAWARE) || @ai.battle.moldBreaker
      atk_stage = max_stage if is_critical && atk_stage < max_stage
      atk = (atk.to_f * stage_mul[atk_stage] / stage_div[atk_stage]).floor
    end
    ##### Calculate target's defense stat #####
    defense, def_stage = @move.pbGetDefenseStats(user.battler, target.battler)
    if !user.has_active_ability?(:UNAWARE) || @ai.battle.moldBreaker
      def_stage = max_stage if is_critical && def_stage > max_stage
      defense = (defense.to_f * stage_mul[def_stage] / stage_div[def_stage]).floor
    end
    ##### Calculate all multiplier effects #####
    multipliers = {
      :power_multiplier        => 1.0,
      :attack_multiplier       => 1.0,
      :defense_multiplier      => 1.0,
      :final_damage_multiplier => 1.0
    }
    # Global abilities
    if @ai.trainer.medium_skill? &&
       ((@ai.battle.pbCheckGlobalAbility(:DARKAURA) && calc_type == :DARK) ||
        (@ai.battle.pbCheckGlobalAbility(:FAIRYAURA) && calc_type == :FAIRY))
      if @ai.battle.pbCheckGlobalAbility(:AURABREAK)
        multipliers[:power_multiplier] *= 3 / 4.0
      else
        multipliers[:power_multiplier] *= 4 / 3.0
      end
    end
    if @ai.trainer.medium_skill?
      [:TABLETSOFRUIN, :SWORDOFRUIN, :VESSELOFRUIN, :BEADSOFRUIN].each_with_index do |ability, i|
        next if !@ai.battle.pbCheckGlobalAbility(ability)
        category = (i < 2) ? physicalMove?(calc_type) : specialMove?(calc_type)
        category = !category if i.odd? && @ai.battle.field.effects[PBEffects::WonderRoom] > 0
        if i.even? && !user.has_active_ability?(ability)
          multipliers[:attack_multiplier] *= 0.75 if category
        elsif i.odd? && !target.has_active_ability?(ability)
          multipliers[:defense_multiplier] *= 0.75 if category
        end
      end
    end
    # Ability effects that alter damage
    if user.ability_active?
      case user.ability_id
      when :AERILATE, :GALVANIZE, :PIXILATE, :REFRIGERATE
        multipliers[:power_multiplier] *= 1.2 if type == :NORMAL   # NOTE: Not calc_type.
      when :ANALYTIC
        if rough_priority(user) <= 0
          user_faster = false
          @ai.each_battler do |b, i|
            user_faster = (i != user.index && user.faster_than?(b))
            break if user_faster
          end
          multipliers[:power_multiplier] *= 1.3 if !user_faster
        end
      when :NEUROFORCE
        if Effectiveness.super_effective_type?(calc_type, *target.pbTypes(true))
          multipliers[:final_damage_multiplier] *= 1.25
        end
      when :NORMALIZE
        multipliers[:power_multiplier] *= 1.2 if Settings::MECHANICS_GENERATION >= 7
      when :SNIPER
        multipliers[:final_damage_multiplier] *= 1.5 if is_critical
      when :STAKEOUT
        # NOTE: Can't predict whether the target will switch out this round.
      when :TINTEDLENS
        if Effectiveness.resistant_type?(calc_type, *target.pbTypes(true))
          multipliers[:final_damage_multiplier] *= 2
        end
      else
        Battle::AbilityEffects.triggerDamageCalcFromUser(
          user.ability, user_battler, target_battler, @move, multipliers, base_dmg, calc_type
        )
      end
    end
    if !@ai.battle.moldBreaker
      user_battler.allAllies.each do |b|
        next if !b.abilityActive?
        Battle::AbilityEffects.triggerDamageCalcFromAlly(
          b.ability, user_battler, target_battler, @move, multipliers, base_dmg, calc_type
        )
      end
      if target.ability_active?
        case target.ability_id
        when :FILTER, :SOLIDROCK
          if Effectiveness.super_effective_type?(calc_type, *target.pbTypes(true))
            multipliers[:final_damage_multiplier] *= 0.75
          end
        else
          Battle::AbilityEffects.triggerDamageCalcFromTarget(
            target.ability, user_battler, target_battler, @move, multipliers, base_dmg, calc_type
          )
        end
      end
    end
    if target.ability_active?
      Battle::AbilityEffects.triggerDamageCalcFromTargetNonIgnorable(
        target.ability, user_battler, target_battler, @move, multipliers, base_dmg, calc_type
      )
    end
    if !@ai.battle.moldBreaker
      target_battler.allAllies.each do |b|
        next if !b.abilityActive?
        Battle::AbilityEffects.triggerDamageCalcFromTargetAlly(
          b.ability, user_battler, target_battler, @move, multipliers, base_dmg, calc_type
        )
      end
    end
    # Item effects that alter damage
    if user.item_active?
      case user.item_id
      when :EXPERTBELT
        if Effectiveness.super_effective_type?(calc_type, *target.pbTypes(true))
          multipliers[:final_damage_multiplier] *= 1.2
        end
      when :LIFEORB
        multipliers[:final_damage_multiplier] *= 1.3
      else
        Battle::ItemEffects.triggerDamageCalcFromUser(
          user.item, user_battler, target_battler, @move, multipliers, base_dmg, calc_type
        )
        user.effects[PBEffects::GemConsumed] = nil   # Untrigger consuming of Gems
      end
    end
    if target.item_active? && target.item && !target.item.is_berry?
      Battle::ItemEffects.triggerDamageCalcFromTarget(
        target.item, user_battler, target_battler, @move, multipliers, base_dmg, calc_type
      )
    end
    # Parental Bond
    if user.has_active_ability?(:PARENTALBOND)
      multipliers[:power_multiplier] *= (Settings::MECHANICS_GENERATION >= 7) ? 1.25 : 1.5
    end
    # Me First - n/a because can't predict the move Me First will use
    # Helping Hand - n/a
    # Charge
    if @ai.trainer.medium_skill? &&
       user.effects[PBEffects::Charge] > 0 && calc_type == :ELECTRIC
      multipliers[:power_multiplier] *= 2
    end
    # Mud Sport and Water Sport
    if @ai.trainer.medium_skill?
      if calc_type == :ELECTRIC
        if @ai.battle.allBattlers.any? { |b| b.effects[PBEffects::MudSport] }
          multipliers[:power_multiplier] /= 3
        end
        if @ai.battle.field.effects[PBEffects::MudSportField] > 0
          multipliers[:power_multiplier] /= 3
        end
      elsif calc_type == :FIRE
        if @ai.battle.allBattlers.any? { |b| b.effects[PBEffects::WaterSport] }
          multipliers[:power_multiplier] /= 3
        end
        if @ai.battle.field.effects[PBEffects::WaterSportField] > 0
          multipliers[:power_multiplier] /= 3
        end
      end
    end
    # Terrain moves
    if @ai.trainer.medium_skill?
      terrain_multiplier = (Settings::MECHANICS_GENERATION >= 8) ? 1.3 : 1.5
      case @ai.battle.field.terrain
      when :Electric
        multipliers[:power_multiplier] *= terrain_multiplier if calc_type == :ELECTRIC && user_battler.affectedByTerrain?
        multipliers[:power_multiplier] *= 1.5 if function_code == "IncreasePowerInElectricTerrain" && user_battler.affectedByTerrain?
      when :Grassy
        multipliers[:power_multiplier] *= terrain_multiplier if calc_type == :GRASS && user_battler.affectedByTerrain?
      when :Psychic
        multipliers[:power_multiplier] *= terrain_multiplier if calc_type == :PSYCHIC && user_battler.affectedByTerrain?
      when :Misty
        multipliers[:power_multiplier] /= 2 if calc_type == :DRAGON && target_battler.affectedByTerrain?
      end
    end
    # Badge multipliers
    if @ai.trainer.high_skill? && @ai.battle.internalBattle && target_battler.pbOwnedByPlayer?
      # Don't need to check the Atk/Sp Atk-boosting badges because the AI
      # won't control the player's Pokémon.
      if physicalMove?(calc_type) && @ai.battle.pbPlayer.badge_count >= Settings::NUM_BADGES_BOOST_DEFENSE
        multipliers[:defense_multiplier] *= 1.1
      elsif specialMove?(calc_type) && @ai.battle.pbPlayer.badge_count >= Settings::NUM_BADGES_BOOST_SPDEF
        multipliers[:defense_multiplier] *= 1.1
      end
    end
    # Multi-targeting attacks
    if @ai.trainer.high_skill? && targets_multiple_battlers?
      multipliers[:final_damage_multiplier] *= 0.75
    end
    # Weather
    if @ai.trainer.medium_skill?
      case user_battler.effectiveWeather
      when :Sun, :HarshSun
        case calc_type
        when :FIRE
          multipliers[:final_damage_multiplier] *= 1.5
        when :WATER
          if function_code == "IncreasePowerInSunWeather" # Added for Hydro Steam
            multipliers[:final_damage_multiplier] *= 1.5
          else
            multipliers[:final_damage_multiplier] /= 2
          end
        end
      when :Rain, :HeavyRain
        case calc_type
        when :FIRE
          multipliers[:final_damage_multiplier] /= 2
        when :WATER
          multipliers[:final_damage_multiplier] *= 1.5
        end
      when :Sandstorm
        if target.has_type?(:ROCK) && specialMove?(calc_type) &&
           function_code != "UseTargetDefenseInsteadOfTargetSpDef"   # Psyshock
          multipliers[:defense_multiplier] *= 1.5
        end
      #-------------------------------------------------------------------------
      # Added for Gen 9 Snow
      #-------------------------------------------------------------------------
      when :Hail
        if Settings::HAIL_WEATHER_TYPE > 0 && target.pbHasType?(:ICE) &&
            (physicalMove?(calc_type) || function_code == "UseTargetDefenseInsteadOfTargetSpDef")
          multipliers[:defense_multiplier] *= 1.5
        end
      #-------------------------------------------------------------------------
      end
    end
    # Critical hits
    if is_critical
      if Settings::NEW_CRITICAL_HIT_RATE_MECHANICS
        multipliers[:final_damage_multiplier] *= 1.5
      else
        multipliers[:final_damage_multiplier] *= 2
      end
    end
    # Random variance - n/a
    # STAB
    if calc_type && user.has_type?(calc_type)
      if user.has_active_ability?(:ADAPTABILITY)
        multipliers[:final_damage_multiplier] *= 2
      else
        multipliers[:final_damage_multiplier] *= 1.5
      end
    end
    # Type effectiveness
    typemod = target.effectiveness_of_type_against_battler(calc_type, user, @move)
    multipliers[:final_damage_multiplier] *= typemod
    # Burn
    if @ai.trainer.high_skill? && user.status == :BURN && physicalMove?(calc_type) &&
       @move.damageReducedByBurn? && !user.has_active_ability?(:GUTS)
      multipliers[:final_damage_multiplier] /= 2
    end
    #---------------------------------------------------------------------------
    # Added for Drowsy
    #---------------------------------------------------------------------------
    if @ai.trainer.high_skill? && target.status == :DROWSY
      multipliers[:final_damage_multiplier] *= 4 / 3.0
    end
    #---------------------------------------------------------------------------
    # Added for Frostbite
    #---------------------------------------------------------------------------
    if @ai.trainer.high_skill? && move.specialMove?(type) && user.status == :FROSTBITE
      multipliers[:final_damage_multiplier] /= 2
    end
    # Aurora Veil, Reflect, Light Screen
    if @ai.trainer.medium_skill? && !@move.ignoresReflect? && !is_critical &&
       !user.has_active_ability?(:INFILTRATOR)
      if target.pbOwnSide.effects[PBEffects::AuroraVeil] > 0
        if @ai.battle.pbSideBattlerCount(target_battler) > 1
          multipliers[:final_damage_multiplier] *= 2 / 3.0
        else
          multipliers[:final_damage_multiplier] /= 2
        end
      elsif target.pbOwnSide.effects[PBEffects::Reflect] > 0 && physicalMove?(calc_type)
        if @ai.battle.pbSideBattlerCount(target_battler) > 1
          multipliers[:final_damage_multiplier] *= 2 / 3.0
        else
          multipliers[:final_damage_multiplier] /= 2
        end
      elsif target.pbOwnSide.effects[PBEffects::LightScreen] > 0 && specialMove?(calc_type)
        if @ai.battle.pbSideBattlerCount(target_battler) > 1
          multipliers[:final_damage_multiplier] *= 2 / 3.0
        else
          multipliers[:final_damage_multiplier] /= 2
        end
      end
    end
    # Minimize
    if @ai.trainer.medium_skill? && target.effects[PBEffects::Minimize] && @move.tramplesMinimize?
      multipliers[:final_damage_multiplier] *= 2
    end
    #---------------------------------------------------------------------------
    # Added for Glaive Rush
    #---------------------------------------------------------------------------
    if @ai.trainer.high_skill? && target.effects[PBEffects::GlaiveRush] > 0
      multipliers[:final_damage_multiplier] *= 2
    end
    #---------------------------------------------------------------------------
    # NOTE: No need to check pbBaseDamageMultiplier, as it's already accounted
    #       for in an AI's MoveBasePower handler or can't be checked now anyway.
    # NOTE: No need to check pbModifyDamage, as it's already accounted for in an
    #       AI's MoveBasePower handler.
    ##### Main damage calculation #####
    base_dmg = [(base_dmg * multipliers[:power_multiplier]).round, 1].max
    atk      = [(atk      * multipliers[:attack_multiplier]).round, 1].max
    defense  = [(defense  * multipliers[:defense_multiplier]).round, 1].max
    damage   = ((((2.0 * user.level / 5) + 2).floor * base_dmg * atk / defense).floor / 50).floor + 2
    damage   = [(damage * multipliers[:final_damage_multiplier]).round, 1].max
    ret = damage.floor
    ret = target.hp - 1 if @move.nonLethal?(user_battler, target_battler) && ret >= target.hp
    return ret
  end
  
  #-----------------------------------------------------------------------------
  # Used to allow an AI trainer to select a Pokemon in the party to revive.
  #-----------------------------------------------------------------------------
  def choose_best_revive_pokemon(idxBattler, party)
    reserves = []
    idxPartyStart, idxPartyEnd = @battle.pbTeamIndexRangeFromBattlerIndex(idxBattler)
    party.each_with_index do |_p, i|
      reserves.push([i, 100]) if !_p.egg? && _p.fainted?
    end
    return -1 if reserves.length == 0
    # Rate each possible replacement Pokémon
    reserves.each_with_index do |reserve, i|
      reserves[i][1] = rate_replacement_pokemon(idxBattler, party[reserve[0]], reserve[1])
    end
    reserves.sort! { |a, b| b[1] <=> a[1] }   # Sort from highest to lowest rated
    # Return the party index of the best rated replacement Pokémon
    return reserves[0][0]
  end
  
  #===============================================================================
  # AI_Switch
  #===============================================================================
  # Handler to encourage AI trainers to switch out to trigger Zero to Hero.
  #-------------------------------------------------------------------------------
  Battle::AI::Handlers::ShouldSwitch.add(:zero_to_hero_ability,
    proc { |battler, reserves, ai, battle|
      next false if !battler.ability_active?
      next false if battler.ability != :ZEROTOHERO
      next false if battler.battler.form != 0
      # Don't try to transform if entry hazards will
      # KO the battler if it switches back in
      entry_hazard_damage = ai.calculate_entry_hazard_damage(battler.pokemon, battler.side)
      next false if entry_hazard_damage >= battler.hp
      # Check switching moves
      switchFunctions = [
          "SwitchOutUserStatusMove",           # Teleport
          "SwitchOutUserDamagingMove",         # U-Turn/Volt Switch
          "SwitchOutUserPassOnEffects",        # Baton Pass
          "LowerTargetAtkSpAtk1SwitchOutUser", # Parting Shot
          "StartHailWeatherSwitchOutUser",     # Chilly Reception
          "UserMakeSubstituteSwitchOut"        # Shed Tail
        ]
      hasSwitchMove = false
      battler.battler.eachMoveWithIndex do |m, i|
        next if !switchFunctions.include?(m.function_code) || !battle.pbCanChooseMove?(battler.index, i, false)
        hasSwitchMove = true
        break
      end
      next true if !hasSwitchMove && (ai.trainer.high_skill? || ai.pbAIRandom(100) < 70)
      next false
    }
  )
  
  #===============================================================================
  # AI_Utilities
  #===============================================================================
  # Aliased so AI trainers can recognize immunities from Gen 9 abilities.
  #-------------------------------------------------------------------------------
  alias paldea_pokemon_can_absorb_move? pokemon_can_absorb_move?
  def pokemon_can_absorb_move?(pkmn, move, move_type)
    return false if pkmn.is_a?(Battle::AI::AIBattler) && !pkmn.ability_active?
    # Check pkmn's ability
    # Anything with a Battle::AbilityEffects::MoveImmunity handler
    case pkmn.ability_id
    when :EARTHEATER
      return move_type == :GROUND
    when :WELLBAKEDBODY
      return move_type == :FIRE
    when :WINDRIDER
      move_data = GameData::Move.get(move.id)
      return move_data.has_flag?("Wind")
    end
    return paldea_pokemon_can_absorb_move?(pkmn, move, move_type)
  end

  #===============================================================================
  # AI_ChooseMove
  #===============================================================================
  # Returns whether the move will definitely fail against the target (assuming
  # no battle conditions change between now and using the move).
  #-------------------------------------------------------------------------------
  alias paldea_pbPredictMoveFailureAgainstTarget pbPredictMoveFailureAgainstTarget
  def pbPredictMoveFailureAgainstTarget
    ret = paldea_pbPredictMoveFailureAgainstTarget
    if !ret
      # Immunity because of Armor Tail
      if @move.rough_priority(@user) > 0 && @target.opposes?(@user)
        each_same_side_battler(@target.side) do |b, i|
          return true if b.has_active_ability?(:ARMORTAIL)
        end
      end
      # Immunity because of Commander
      return true if target.has_active_ability?(:COMMANDER) && target.battler.isCommander?
      # Good As Gold Pokémon immunity to status moves
      return true if @move.statusMove?  && @target.has_active_ability?(:GOODASGOLD) && 
                                          !(@user.has_active_ability?(:MYCELIUMMIGHT))
    end
    return ret
  end
  #===============================================================================
  # AI_ChooseMove_GenericEffects
  #===============================================================================
  # Aliased to adds score modifier for the Gen 9 abilities and moves.
  #-------------------------------------------------------------------------------
  alias paldea_get_score_for_weather get_score_for_weather
  def get_score_for_weather(weather, move_user, starting = false)
    return 0 if @battle.pbCheckGlobalAbility(:AIRLOCK) ||
                @battle.pbCheckGlobalAbility(:CLOUDNINE)
    ret = paldea_get_score_for_weather(weather, move_user, starting)
    each_battler do |b, i|
      # Check each battler's abilities/other moves affected by the new weather
      if @trainer.medium_skill? && !b.has_active_item?(:UTILITYUMBRELLA)
        # Abilities
        beneficial_abilities = {
          :Sun       => [:ORICHALCUMPULSE,:PROTOSYNTHESIS]
        }[weather]
        if beneficial_abilities && beneficial_abilities.length > 0 &&
           b.has_active_ability?(beneficial_abilities)
          ret += (b.opposes?(move_user)) ? -5 : 5
        end
        # Moves
        beneficial_moves = {
          :Sun       => ["IncreasePowerInSunWeather"],
          :Rain      => ["LowerTargetSpeed1AlwaysHitsInRain",
                         "ParalyzeTargetAlwaysHitsInRain",
                         "BurnTargetAlwaysHitsInRain"]
        }[weather]
        if beneficial_moves && beneficial_moves.length > 0 &&
           b.has_move_with_function?(*beneficial_moves)
          ret += (b.opposes?(move_user)) ? -5 : 5
        end
      end
    end
    return ret
  end

  #-------------------------------------------------------------------------------
  # Aliased to adds score modifier for the Gen 9 abilities and moves.
  #-------------------------------------------------------------------------------
  alias paldea_get_score_for_terrain get_score_for_terrain
  def get_score_for_terrain(terrain, move_user, starting = false)
    ret = paldea_get_score_for_terrain(terrain, move_user, starting)
    # Check for abilities/moves affected by the terrain
    if @trainer.medium_skill?
      abils = {
        :Electric => [:QUARKDRIVE,:HADRONENGINE]
      }[terrain]
      good_moves = {
        :Electric => ["IncreasePowerInElectricTerrain"],
      }[terrain]
      each_battler do |b, i|
        next if !b.battler.affectedByTerrain?
        # Abilities
        if abils && b.has_active_ability?(abils)
          ret += (b.opposes?(move_user)) ? -8 : 8
        end
        # Moves
        if good_moves && b.has_move_with_function?(*good_moves)
          ret += (b.opposes?(move_user)) ? -5 : 5
        end
      end
    end
    return ret
  end
end

#===============================================================================
# AIBattler
#===============================================================================
# Add Salt Cure damage
#-------------------------------------------------------------------------------
class Battle::AI::AIBattler
  # Returns how much damage this battler will take at the end of this round.
  alias paldea_rough_end_of_round_damage rough_end_of_round_damage
  def rough_end_of_round_damage
    ret = paldea_rough_end_of_round_damage
    # Salt Cure
    if self.effects[PBEffects::SaltCure]
      if has_type?(:WATER) || has_type?(:STEEL)
        ret += [self.totalhp / 4, 1].max
      else
        ret += [self.totalhp / 8, 1].max
      end
    end
    return ret
  end

  # Added Drowsy and Frostbite
  alias paldea_wants_status_problem? wants_status_problem?
  def wants_status_problem?(new_status)
    return true if new_status == :NONE
    want_status = false
    if ability_active?
      case ability_id
      when :GUTS
        return true if ![:DROWSY, :FROSTBITE].include?(new_status) &&
                       @ai.stat_raise_worthwhile?(self, :ATTACK, true)
      when :QUICKFEET
        return true if ![:DROWSY, :FROSTBITE].include?(new_status) &&
                       @ai.stat_raise_worthwhile?(self, :SPEED, true)
      end
    end
    return true if new_status == :DROWSY && check_for_move { |m| m.usableWhenAsleep? }
    return paldea_wants_status_problem?(new_status) if !want_status
  end

  # Added Mind's Eye
  alias paldea_effectiveness_of_type_against_single_battler_type effectiveness_of_type_against_single_battler_type
  def effectiveness_of_type_against_single_battler_type(type, defend_type, user = nil)
    ret = paldea_effectiveness_of_type_against_single_battler_type(type, defend_type, user)
    if Effectiveness.ineffective_type?(type, defend_type)
      if user&.has_active_ability?(:MINDSEYE) && defend_type == :GHOST
        ret = Effectiveness::NORMAL_EFFECTIVE_MULTIPLIER
      end
    end
    return ret
  end

  # Added Gen 9 base item ratings
  alias paldea_wants_item? wants_item?
  def wants_item?(item)
    Battle::AI::GEN_9_BASE_ITEM_RATINGS.each_pair do |val, items|
      next if Battle::AI::BASE_ITEM_RATINGS[val] && Battle::AI::BASE_ITEM_RATINGS[val].include?(item)
      Battle::AI::BASE_ITEM_RATINGS[val] = [] if !Battle::AI::BASE_ITEM_RATINGS[val]
      items.each{|itm|
        Battle::AI::BASE_ITEM_RATINGS[val].push(itm)
      }
    end
    return paldea_wants_item?(item)
  end

  # Added Gen 9 base ability ratings
  alias paldea_wants_ability? wants_ability?
  def wants_ability?(ability = :NONE)
    Battle::AI::GEN_9_BASE_ABILITY_RATINGS.each_pair do |val, abilities|
      next if Battle::AI::BASE_ABILITY_RATINGS[val] && Battle::AI::BASE_ABILITY_RATINGS[val].include?(ability)
      Battle::AI::BASE_ABILITY_RATINGS[val] = [] if !Battle::AI::BASE_ABILITY_RATINGS[val]
      abilities.each{|ab|
        Battle::AI::BASE_ABILITY_RATINGS[val].push(ab)
      }
    end
    return paldea_wants_ability?(ability)
  end
end

#===============================================================================
# AIMove
#===============================================================================
# Add Glaive Rush to accuracy calculation
#-------------------------------------------------------------------------------
class Battle::AI::AIMove
  # Full accuracy calculation.
  alias paldea_rough_accuracy rough_accuracy
  def rough_accuracy
    if @ai.trainer.medium_skill?
      return 100 if @ai.target.effects[PBEffects::GlaiveRush] > 0
    end
    return paldea_rough_accuracy
  end
end