#===============================================================================
# "v21 Hotfixes" plugin
# This file contains fixes for bugs in Essentials v21.
# These bug fixes are also in the master branch of the GitHub version of
# Essentials:
# https://github.com/Maruno17/pokemon-essentials
#===============================================================================

Essentials::ERROR_TEXT += "[v21 Hotfixes 1.0.1]\r\n"

#===============================================================================
# Fixed incorrect positioning of text in some menus in the Battle Factory.
#===============================================================================
class Window_AdvancedCommandPokemon < Window_DrawableCommand
  def drawItem(index, _count, rect)
    pbSetSystemFont(self.contents)
    rect = drawCursor(index, rect)
    if toUnformattedText(@commands[index]).gsub(/\n/, "") == @commands[index]
      # Use faster alternative for unformatted text without line breaks
      pbDrawShadowText(self.contents, rect.x, rect.y + (self.contents.text_offset_y || 0),
                       rect.width, rect.height, @commands[index], self.baseColor, self.shadowColor)
    else
      chars = getFormattedText(self.contents, rect.x, rect.y + (self.contents.text_offset_y || 0),
                               rect.width, rect.height, @commands[index], rect.height, true, true)
      drawFormattedChars(self.contents, chars)
    end
  end
end

#===============================================================================
# Fixed crash when entering a map with no defined map metadata.
#===============================================================================
def pbGetMapNameFromId(id)
  name = GameData::MapMetadata.try_get(id)&.name
  if nil_or_empty?(name)
    name = pbGetBasicMapNameFromId(id)
    name.gsub!(/\\PN/, $player.name) if $player
  end
  return name
end

class Sprite_Reflection
  def update
    return if disposed?
    shouldShow = @parent_sprite.visible
    if !shouldShow
      # Just-in-time disposal of sprite
      if @sprite
        @sprite.dispose
        @sprite = nil
      end
      return
    end
    # Just-in-time creation of sprite
    @sprite = Sprite.new(@viewport) if !@sprite
    if @sprite
      x = @parent_sprite.x - (@parent_sprite.ox * TilemapRenderer::ZOOM_X)
      y = @parent_sprite.y - (@parent_sprite.oy * TilemapRenderer::ZOOM_Y)
      y -= Game_Map::TILE_HEIGHT * TilemapRenderer::ZOOM_Y if event.character_name[/offset/i]
      @height = $PokemonGlobal.bridge if !@fixedheight
      y += @height * TilemapRenderer::ZOOM_Y * Game_Map::TILE_HEIGHT / 2
      width  = @parent_sprite.src_rect.width
      height = @parent_sprite.src_rect.height
      @sprite.x        = x + ((width / 2) * TilemapRenderer::ZOOM_X)
      @sprite.y        = y + ((height + (height / 2)) * TilemapRenderer::ZOOM_Y)
      @sprite.ox       = width / 2
      @sprite.oy       = (height / 2) - 2   # Hard-coded 2 pixel shift up
      @sprite.oy       -= event.bob_height * 2
      @sprite.z        = -50   # Still water is -100, map is 0 and above
      @sprite.z        += 1 if event == $game_player
      @sprite.zoom_x   = @parent_sprite.zoom_x
      if Settings::ANIMATE_REFLECTIONS && !GameData::MapMetadata.try_get(event.map_id)&.still_reflections
        @sprite.zoom_x   += 0.05 * @sprite.zoom_x * Math.sin(2 * Math::PI * System.uptime)
      end
      @sprite.zoom_y   = @parent_sprite.zoom_y
      @sprite.angle    = 180.0
      @sprite.mirror   = true
      @sprite.bitmap   = @parent_sprite.bitmap
      @sprite.tone     = @parent_sprite.tone
      if @height > 0
        @sprite.color   = Color.new(48, 96, 160, 255)   # Dark still water
        @sprite.opacity = @parent_sprite.opacity
        @sprite.visible = !Settings::TIME_SHADING   # Can't time-tone a colored sprite
      else
        @sprite.color   = Color.new(224, 224, 224, 96)
        @sprite.opacity = @parent_sprite.opacity * 3 / 4
        @sprite.visible = true
      end
      @sprite.src_rect = @parent_sprite.src_rect
    end
  end
end

#===============================================================================
# Fixed Sky Drop failing in the second round causing the target to remain in the
# air forever.
#===============================================================================
class Battle::Move::TwoTurnAttackInvulnerableInSkyTargetCannotAct < Battle::Move::TwoTurnMove
  def pbEffectAfterAllHits(user, target)
    target.effects[PBEffects::SkyDrop] = -1 if @damagingTurn
  end
end

#===============================================================================
# Fixed the first frame of RMXP Database animations not showing.
#===============================================================================
class SpriteAnimation
  def animation(animation, hit, height = 3)
    dispose_animation
    @_animation = animation
    return if @_animation.nil?
    @_animation_hit      = hit
    @_animation_height   = height
    @_animation_duration = @_animation.frame_max
    @_animation_index    = -1
    fr = 20
    if @_animation.name[/\[\s*(\d+?)\s*\]\s*$/]
      fr = $~[1].to_i
    end
    @_animation_time_per_frame = 1.0 / fr
    @_animation_timer_start = System.uptime
    animation_name = @_animation.animation_name
    animation_hue  = @_animation.animation_hue
    bitmap = pbGetAnimation(animation_name, animation_hue)
    if @@_reference_count.include?(bitmap)
      @@_reference_count[bitmap] += 1
    else
      @@_reference_count[bitmap] = 1
    end
    @_animation_sprites = []
    if @_animation.position != 3 || !@@_animations.include?(animation)
      16.times do
        sprite = ::Sprite.new(self.viewport)
        sprite.bitmap = bitmap
        sprite.visible = false
        @_animation_sprites.push(sprite)
      end
      @@_animations.push(animation) unless @@_animations.include?(animation)
    end
    update_animation
  end

  def loop_animation(animation)
    return if animation == @_loop_animation
    dispose_loop_animation
    @_loop_animation = animation
    return if @_loop_animation.nil?
    @_loop_animation_duration = @_animation.frame_max
    @_loop_animation_index = -1
    fr = 20
    if @_animation.name[/\[\s*(\d+?)\s*\]\s*$/]
      fr = $~[1].to_i
    end
    @_loop_animation_time_per_frame = 1.0 / fr
    @_loop_animation_timer_start = System.uptime
    animation_name = @_loop_animation.animation_name
    animation_hue  = @_loop_animation.animation_hue
    bitmap = pbGetAnimation(animation_name, animation_hue)
    if @@_reference_count.include?(bitmap)
      @@_reference_count[bitmap] += 1
    else
      @@_reference_count[bitmap] = 1
    end
    @_loop_animation_sprites = []
    16.times do
      sprite = ::Sprite.new(self.viewport)
      sprite.bitmap = bitmap
      sprite.visible = false
      @_loop_animation_sprites.push(sprite)
    end
    update_loop_animation
  end
end
