################################################################################
# 
# Battle class additions.
# 
################################################################################


class Battle
  #-----------------------------------------------------------------------------
  # Type calculation
  #-----------------------------------------------------------------------------
  # Used when an Arceus holding a Legend Plate uses the move Judgment.
  # Calculates the ideal type to change to against the target of the move.
  # Randomizes type if there are multiple types with equivalent strength. 
  # Won't change type if check_type is already among the best types to use.
  # If the target has no type, (for example a pure Fire-type who used Burn Up)
  # and the target also has no abilities, item, or effects in play that would
  # affect the type chosen, then the Normal type will be chosen.
  #-----------------------------------------------------------------------------
  # The following factors are considered when calculating a type:
  #   -Type effectiveness.
  #   -The target's third type, if any. (Forest's Curse, Trick-or-Treat)
  #   -Type-based immunities, if any. (Considers Ring Target/Foresight/Miracle Eye)
  #   -Ability-based immunities related to typing. (Levitate, Water Absorb, etc.)
  #   -Ability-based power modifiers related to typing. (Heat Proof, Thick Fat, etc.)
  #   -Item-based immunities related to typing. (Air Balloon, Iron Ball, etc.)
  #   -User effect-based power modifiers related to typing. (Charge)
  #   -Target effect-based immunities related to typing. (Magnet Rise, Smack Down, etc.)
  #   -Field power modifiers related to typing. (Mud Sport, Water Sport)
  #   -Weather and Terrain power modifiers related to typing.
  #-----------------------------------------------------------------------------
  #   *Note: The opponent's type-weakening berries are not considered.
  #-----------------------------------------------------------------------------
  def pbGetBestTypeJudgment(user, target, move = nil, check_type = nil)
    return :NORMAL if !target
    all_types = []
    effective_types = Hash.new { |key, value| key[value] = [] }
    target_types = target.pbTypes(true)
    move = Move.from_pokemon_move(self, Pokemon::Move.new(:JUDGMENT)) if !move
    GameData::Type.each do |type_data|
      next if type_data.pseudo_type
      type = type_data.id
      all_types.push(type)
      next if pbTargetHasTypeImmunity?(user, target, move, type, target_types)
      multipliers = {
        :power_multiplier  => 1.0,
        :attack_multiplier       => 1.0,
        :defense_multiplier      => 1.0,
        :final_damage_multiplier => 1.0
      }
      pbCalcTypeMultsJudgment(user, target, move, type, target_types, multipliers)
      baseMult = [multipliers[:power_multiplier].round,        1].max
      atkMult  = [multipliers[:attack_multiplier].round,       1].max
      defMult  = [multipliers[:defense_multiplier].round,      1].max
      dmgMult  = [multipliers[:final_damage_multiplier].round, 1].max
      strength = ((baseMult * atkMult / defMult) * dmgMult).floor
      effective_types[strength] << type
    end
    best_types = (effective_types.empty?) ? all_types : effective_types.sort.last[1]
    bestType = pbCalcOptimalType(user, target, move, best_types, target_types, check_type)
    return bestType
  end
  
  #-----------------------------------------------------------------------------
  # Checks if the target is immune to a given type by its typing, ability, or effect.
  #-----------------------------------------------------------------------------
  def pbTargetHasTypeImmunity?(user, target, move, type, target_types)
    return true if type == :FIRE  && target.effectiveWeather == :HeavyRain
    return true if type == :WATER && target.effectiveWeather == :HarshSun
    return true if move.pbCalcTypeMod(type, user, target) == Effectiveness::INEFFECTIVE
    if target.abilityActive? && !@moldBreaker
      return true if Battle::AbilityEffects.triggerMoveImmunity(
        target.ability, user, target, move, type, self, false)
    end
    return false
  end
  
  #-----------------------------------------------------------------------------
  # Calculates the effectiveness of a given type used against the target.
  #-----------------------------------------------------------------------------
  def pbCalcTypeMultsJudgment(user, target, move, type, target_types, multipliers)
    if (pbCheckGlobalAbility(:DARKAURA)  && type == :DARK) ||
       (pbCheckGlobalAbility(:FAIRYAURA) && type == :FAIRY)
      if pbCheckGlobalAbility(:AURABREAK)
        multipliers[:power_multiplier] *= 2 / 3.0
      else
        multipliers[:power_multiplier] *= 4 / 3.0
      end
    end
    if target.abilityActive? && !@moldBreaker
      Battle::AbilityEffects.triggerDamageCalcFromTarget(
        target.ability, user, target, move, multipliers, move.baseDamage, type
      )
      Battle::AbilityEffects.triggerDamageCalcFromTargetNonIgnorable(
        target.ability, user, target, move, multipliers, move.baseDamage, type
      )
    end
    type_calc = move.pbCalcTypeMod(type, user, target)
    if type_calc > Effectiveness::INEFFECTIVE
      multipliers[:final_damage_multiplier] *= type_calc
    end
    case type
    when :FIRE
      multipliers[:power_multiplier] /= 3 if @field.effects[PBEffects::WaterSportField] > 0
    when :ELECTRIC
      multipliers[:power_multiplier] *= 2 if user.effects[PBEffects::Charge] > 0
      multipliers[:power_multiplier] /= 3 if @field.effects[PBEffects::MudSportField] > 0
    end
    if user.affectedByTerrain?
      case @field.terrain
      when :Electric then multipliers[:power_multiplier] *= 1.3 if type == :ELECTRIC
      when :Grassy   then multipliers[:power_multiplier] *= 1.3 if type == :GRASS
      when :Psychic  then multipliers[:power_multiplier] *= 1.3 if type == :PSYCHIC
      when :Misty    then multipliers[:power_multiplier] /= 2   if type == :DRAGON
      end
    end
    case user.effectiveWeather
    when :Sun, :HarshSun
      multipliers[:final_damage_multiplier] *= 1.5 if type == :FIRE
      multipliers[:final_damage_multiplier] /= 2   if type == :WATER
    when :Rain, :HeavyRain
      multipliers[:final_damage_multiplier] *= 1.5 if type == :WATER
      multipliers[:final_damage_multiplier] /= 2   if type == :FIRE
    end
  end
  
  #-----------------------------------------------------------------------------
  # Determines the optimal type to select out of the array of most effective types.
  #-----------------------------------------------------------------------------
  # -Returns most effective type if only one type would be most effective.
  # -If multiple effective types, returns the type that would be the best
  #  defensive type vs the target's primary type.
  # -If multiple effective types still exist, returns the type out of remaining
  #  types that would be the best defensive type vs the target's secondary type.
  # -If multiple effective types still exist, prefer selecting the last used
  #  type if that type is among the remaining types.
  # -Otherwise, select a random effective type.
  #-----------------------------------------------------------------------------
  def pbCalcOptimalType(user, target, move, effective_types, target_types, check_type)
    return effective_types[0] if effective_types.length == 1
    target_types.each do |target_type|
      effectiveness = Hash.new { |key, value| key[value] = [] }
      effective_types.each do |type|
        strength = move.pbCalcTypeModSingle(target_type, type, user, target)
        effectiveness[strength] << type
      end
      effective_types = effectiveness.sort.first[1].clone
      break if effective_types.length == 1
    end
    return check_type if effective_types.include?(check_type)
    return effective_types.sample
  end
end


################################################################################
# 
# Battle::Battler class additions.
# 
################################################################################


class Battle::Battler
  #-----------------------------------------------------------------------------
  # Type setter.
  #-----------------------------------------------------------------------------
  # Saves an ideal type to the user's @legendPlateType attribute.
  # This attribute is continually reset throughout the battle to keep it updated
  # based on what's most optimal at each stage of the fight.
  #-----------------------------------------------------------------------------
  # *Note: Only the player's Pokemon has this attribute calculated continuously 
  # so that the type icon displayed in the fight window can be updated. Opponents
  # don't need this, so it'll only return :NORMAL until actually using the move.
  #-----------------------------------------------------------------------------
  def pbGetJudgmentType(check_type = nil)
    if pbOwnedByPlayer? && hasLegendPlateJudgment? 
      target = nil
      @battle.pbGetOpposingIndicesInOrder(@index).each do |i|
        battler = @battle.battlers[i]
        next if !battler || battler.fainted? || battler.isCommander?
        target = battler
        break
      end
      return @battle.pbGetBestTypeJudgment(self, target, nil, check_type) || :NORMAL
    end
    return :NORMAL
  end
  
  #-----------------------------------------------------------------------------
  # Used to simplify checking for a valid Pokemon using the Legend Plate.
  #-----------------------------------------------------------------------------
  def hasLegendPlateJudgment?
    return isSpecies?(:ARCEUS) && 
           hasActiveAbility?(:MULTITYPE) && 
           hasActiveItem?(:LEGENDPLATE) &&
           pbHasMove?(:JUDGMENT)
  end
end


################################################################################
# 
# Form change animation.
# 
################################################################################


#-------------------------------------------------------------------------------
# Calls the animation for Arceus's transformation while using a Legend Plate.
#-------------------------------------------------------------------------------
class Battle::Scene
  def pbArceusTransform(index, type = :NORMAL)
    @animations.push(Animation::ArceusTransform.new(@sprites, @viewport, index, type))
    while inPartyAnimation?
      pbUpdate
    end
  end
end

#-------------------------------------------------------------------------------
# Arceus Plate Transform Animation
#-------------------------------------------------------------------------------
class Battle::Scene::Animation::ArceusTransform < Battle::Scene::Animation
  PLATE_BURST_VARIANCES = {
    :NORMAL   => [Tone.new(0, 0, 0),          Tone.new(0, 0, -192),       Tone.new(0, 0, -96),        Tone.new(0, -128, -248)], 
    :FIGHTING => [Tone.new(-12, -116, -192),  Tone.new(-12, -116, -192),  Tone.new(-10, -50, -96),    Tone.new(-30, -128, -248)],
    :FLYING   => [Tone.new(0, 0, 0),          Tone.new(-30, -22, 0),      Tone.new(-10, -10, 0),      Tone.new(-70, -70, 0)],
    :POISON   => [Tone.new(-60, -200, 0),     Tone.new(-30, -100, 0),     Tone.new(-20, -30, 0),      Tone.new(-60, -200, 0)],
    :GROUND   => [Tone.new(-10, -13, -36),    Tone.new(-10, -30, -70),    Tone.new(-10, -13, -36),    Tone.new(-15, -55, -120)],
    :ROCK     => [Tone.new(-25, -55, -120),   Tone.new(-20, -30, -70),    Tone.new(-20, -13, -36),    Tone.new(-25, -55, -120)],
    :BUG      => [Tone.new(-45, -26, -58),    Tone.new(-30, -8, -65),     Tone.new(-16, -8, -29),     Tone.new(-45, -26, -58)],
    :GHOST    => [Tone.new(-60, -200, 0),     Tone.new(-30, -100, 0),     Tone.new(-20, -30, 0),      Tone.new(-60, -200, 0)],
    :STEEL    => [Tone.new(0, 0, 0),          Tone.new(-40, -40, -40),    Tone.new(-10, -10, -10),    Tone.new(-128, -128, -128)], 
    :QMARKS   => [Tone.new(-60, -200, 0),     Tone.new(-30, -8, -65),     Tone.new(-16, -8, -29),     Tone.new(-45, -26, -58)],
    :FIRE     => [Tone.new(0, -128, -248),    Tone.new(0, -29, -80),      Tone.new(0, -30, -96),      Tone.new(0, -128, -248)],
    :WATER    => [Tone.new(-192, -96, 0),     Tone.new(-128, -64, 0),     Tone.new(-96, -48, 0),      Tone.new(-192, -96, 0)],
    :GRASS    => [Tone.new(-160, 0, -160),    Tone.new(-128, 0, -128),    Tone.new(-80, 0, -80),      Tone.new(-160, 0, -160)],
    :ELECTRIC => [Tone.new(0, 0, -192),       Tone.new(0, 0, -192),       Tone.new(0, -64, -144),     Tone.new(0, -128, -248)],
    :PSYCHIC  => [Tone.new(-6, -35, 0),       Tone.new(-6, -35, 0),       Tone.new(0, -20, 0),        Tone.new(-14, -100, 0)],
    :ICE      => [Tone.new(0, 0, 0),          Tone.new(-184, -40, 0),     Tone.new(-184, -40, 0),     Tone.new(-192, -128, -32)],
    :DRAGON   => [Tone.new(-26, -29, -24),    Tone.new(-30, -22, 0),      Tone.new(-26, -29, -24),    Tone.new(-50, -70, -40)],
    :DARK     => [Tone.new(-248, -248, -248), Tone.new(-248, -248, -248), Tone.new(-248, -248, -248), Tone.new(-248, -248, -248)],
    :FAIRY    => [Tone.new(0, -55, -32),      Tone.new(0, -25, 0),        Tone.new(0, -10, 0),        Tone.new(0, -55, -32)],
  }

  def initialize(sprites, viewport, index, type)
    @index = index
    @type  = type
    super(sprites, viewport)
  end

  def createProcesses
    batSprite = @sprites["pokemon_#{@index}"]
    ballPos = Battle::Scene.pbBattlerPosition(@index, batSprite.sideSize)
    delay = 0
    battlerX = batSprite.x
    battlerY = batSprite.y-100
    num_particles = 15
    num_rays = 10
    glare_fade_duration = 8   # Lifetimes/durations are in 20ths of a second
    particle_lifetime = 15
    particle_fade_duration = 8
    ray_lifetime = 13
    ray_fade_duration = 5
    ray_min_radius = 24   # How far out from the center a ray starts
    variances = PLATE_BURST_VARIANCES[@type] || PLATE_BURST_VARIANCES[:NORMAL]
    # Set up Plate
    plate = addNewSprite(battlerX, battlerY+40, "Graphics/Battle animations/Arceus_Plate", PictureOrigin::CENTER)
    plate.setZ(0, 105)
    plate.setZoom(0, 100)
    plate.setTone(0, variances[3])
    plate.setVisible(0, false)
    plate.setOpacity(0, 0)
    plate.setVisible(delay, true)
    plate.moveOpacity(delay, 10, 255)
    plate.moveXY(delay, 10, battlerX, battlerY)
    delay = delay + 10
    plate.moveTone(delay, glare_fade_duration / 2, variances[1])
    plate.moveOpacity(delay + glare_fade_duration + 3, glare_fade_duration, 0)
    plate.setVisible(delay + 19, false) 
    # Set up Battler
    battler = addSprite(batSprite, PictureOrigin::BOTTOM)
    battler.setXY(0, battlerX, batSprite.y)
    battler.setZoom(0, 100)
    col = variances[3]
    col.red += 255
    col.green += 255
    col.blue += 255
    battler.setTone(delay + 6, col)
    battler.moveTone(delay + glare_fade_duration + 3, glare_fade_duration, Tone.new(0,0,0,0))
    # Set up glare particles
    glare1 = addNewSprite(battlerX, battlerY, "Graphics/Battle animations/ballBurst_particle", PictureOrigin::CENTER)
    glare2 = addNewSprite(battlerX, battlerY, "Graphics/Battle animations/ballBurst_particle", PictureOrigin::CENTER)
    [glare1, glare2].each_with_index do |particle, num|
      particle.setZ(0, 105 + num)
      particle.setZoom(0, 0)
      particle.setTone(0, variances[2 - (2 * num)])
      particle.setVisible(0, false)
    end
    [glare1, glare2].each_with_index do |particle, num|
      particle.moveTone(delay + glare_fade_duration + 3, glare_fade_duration / 2, variances[1 - num])
    end
    # Animate glare particles
    [glare1, glare2].each { |p| p.setVisible(delay, true) }
    glare1.moveZoom(delay, glare_fade_duration, 250)
    glare1.moveOpacity(delay + glare_fade_duration + 3, glare_fade_duration, 0)
    glare2.moveZoom(delay, glare_fade_duration, 150)
    glare2.moveOpacity(delay + glare_fade_duration + 3, glare_fade_duration - 2, 0)
    [glare1, glare2].each { |p| p.setVisible(delay + 19, false) }
    # Rays
    num_rays.times do |i|
      # Set up ray
      angle = rand(360)
      radian = (angle + 90) * Math::PI / 180
      start_zoom = rand(50...100)
      ray = addNewSprite(battlerX + ray_min_radius * Math.cos(radian),
                         battlerY - ray_min_radius * Math.sin(radian),
                         "Graphics/Battle animations/ballBurst_ray", PictureOrigin::BOTTOM)
      ray.setZ(0, 100)
      ray.setZoomXY(0, 200, start_zoom)
      ray.setTone(0, variances[0])
      ray.setOpacity(0, 0)
      ray.setVisible(0, false)
      ray.setAngle(0, angle)
      # Animate ray
      start = delay + i / 2
      ray.setVisible(start, true)
      ray.moveZoomXY(start, ray_lifetime, 200, start_zoom * 6)
      ray.moveOpacity(start, 2, 255)   # Quickly fade in
      ray.moveOpacity(start + ray_lifetime - ray_fade_duration, ray_fade_duration, 0)   # Fade out
      ray.moveTone(start + ray_lifetime - ray_fade_duration, ray_fade_duration, variances[1])
      ray.setVisible(start + ray_lifetime, false)
    end
    # Particles
    num_particles.times do |i|
      # Set up particles
      particle1 = addNewSprite(battlerX, battlerY, "Graphics/Battle animations/ballBurst_particle", PictureOrigin::CENTER)
      particle2 = addNewSprite(battlerX, battlerY, "Graphics/Battle animations/ballBurst_particle", PictureOrigin::CENTER)
      [particle1, particle2].each_with_index do |particle, num|
        particle.setZ(0, 110 + num)
        particle.setZoom(0, (80 - (num * 20)))
        particle.setTone(0, variances[2 - (2 * num)])
        particle.setVisible(0, false)
      end
      # Animate particles
      start = delay + i / 4
      max_radius = rand(256...384)
      angle = rand(360)
      radian = angle * Math::PI / 180
      [particle1, particle2].each_with_index do |particle, num|
        particle.setVisible(start, true)
        particle.moveDelta(start, particle_lifetime, max_radius * Math.cos(radian), max_radius * Math.sin(radian))
        particle.moveZoom(start, particle_lifetime, 10)
        particle.moveTone(start + particle_lifetime - particle_fade_duration,
                           particle_fade_duration / 2, variances[3 - (3 * num)])
        particle.moveOpacity(start + particle_lifetime - particle_fade_duration,
                             particle_fade_duration,
                             0)   # Fade out at end
        particle.setVisible(start + particle_lifetime, false)
      end
    end
  end
end