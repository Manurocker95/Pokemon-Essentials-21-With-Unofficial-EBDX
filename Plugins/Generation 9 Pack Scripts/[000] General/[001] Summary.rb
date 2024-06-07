################################################################################
# 
# Pokemon Summary changes.
# 
################################################################################


class PokemonSummary_Scene
  #-----------------------------------------------------------------------------
  # Edits Summary controls to change Move page functionality.
  #-----------------------------------------------------------------------------
  def pbScene
    @pokemon.play_cry
    loop do
      Graphics.update
      Input.update
      pbUpdate
      dorefresh = false
      if Input.trigger?(Input::ACTION)
        pbSEStop
        @pokemon.play_cry
      elsif Input.trigger?(Input::BACK)
        pbPlayCloseMenuSE
        break
      elsif Input.trigger?(Input::USE)
        if @page == 5
          pbPlayDecisionSE
          pbRibbonSelection
          dorefresh = true
        elsif !@inbattle
          pbPlayDecisionSE
          dorefresh = pbOptions
        end
      elsif Input.trigger?(Input::UP) && @partyindex > 0
        oldindex = @partyindex
        pbGoToPrevious
        if @partyindex != oldindex
          pbChangePokemon
          @ribbonOffset = 0
          dorefresh = true
        end
      elsif Input.trigger?(Input::DOWN) && @partyindex < @party.length - 1
        oldindex = @partyindex
        pbGoToNext
        if @partyindex != oldindex
          pbChangePokemon
          @ribbonOffset = 0
          dorefresh = true
        end
      elsif Input.trigger?(Input::LEFT) && !@pokemon.egg?
        oldpage = @page
        @page -= 1
        @page = 1 if @page < 1
        @page = 5 if @page > 5
        if @page != oldpage
          pbSEPlay("GUI summary change page")
          @ribbonOffset = 0
          dorefresh = true
        end
      elsif Input.trigger?(Input::RIGHT) && !@pokemon.egg?
        oldpage = @page
        @page += 1
        @page = 1 if @page < 1
        @page = 5 if @page > 5
        if @page != oldpage
          pbSEPlay("GUI summary change page")
          @ribbonOffset = 0
          dorefresh = true
        end
      end
      if dorefresh
        drawPage(@page)
      end
    end
    return @partyindex
  end

  #-----------------------------------------------------------------------------
  # -Edited to add Nickname prompt in the Summary options.
  # -Edited to allow the use TM's, and to relearn/forget moves on the moves page. 
  #-----------------------------------------------------------------------------
  def pbOptions
    dorefresh = false
    commands = []
    cmdGiveItem   = -1
    cmdTakeItem   = -1
    cmdNickname   = -1
    cmdPokedex    = -1
    cmdMark       = -1
    cmdCheckMoves = -1
    cmdLearnMoves = -1
    cmdForgetMove = -1
    cmdTeachTMs   = -1
    case @page
    when 4
      commands[cmdCheckMoves = commands.length] = _INTL("Check Moves") if !@pokemon.moves.empty?
      commands[cmdLearnMoves = commands.length] = _INTL("Remember Moves") if @pokemon.can_relearn_move?
      commands[cmdForgetMove = commands.length] = _INTL("Forget Moves") if @pokemon.moves.length > 1
      commands[cmdTeachTMs   = commands.length] = _INTL("Use TM's")
    else
      if !@pokemon.egg?
        commands[cmdGiveItem = commands.length] = _INTL("Give item")
        commands[cmdTakeItem = commands.length] = _INTL("Take item") if @pokemon.hasItem?
        commands[cmdNickname = commands.length] = _INTL("Nickname") if !@pokemon.foreign?
        commands[cmdPokedex  = commands.length] = _INTL("View Pokédex") if $player.has_pokedex
      end
      commands[cmdMark = commands.length] = _INTL("Mark")
    end
    commands[commands.length] = _INTL("Cancel")
    command = pbShowCommands(commands)
    if cmdGiveItem >= 0 && command == cmdGiveItem
      item = nil
      pbFadeOutIn {
        scene = PokemonBag_Scene.new
        screen = PokemonBagScreen.new(scene, $bag)
        item = screen.pbChooseItemScreen(proc { |itm| GameData::Item.get(itm).can_hold? })
      }
      if item
        dorefresh = pbGiveItemToPokemon(item, @pokemon, self, @partyindex)
      end
    elsif cmdTakeItem >= 0 && command == cmdTakeItem
      dorefresh = pbTakeItemFromPokemon(@pokemon, self)
    elsif cmdNickname >= 0 && command == cmdNickname
      nickname = pbEnterPokemonName(_INTL("{1}'s nickname?", @pokemon.name), 0, Pokemon::MAX_NAME_SIZE, "", @pokemon, true)
      @pokemon.name = nickname
      dorefresh = true
    elsif cmdPokedex >= 0 && command == cmdPokedex
      $player.pokedex.register_last_seen(@pokemon)
      pbFadeOutIn {
        scene = PokemonPokedexInfo_Scene.new
        screen = PokemonPokedexInfoScreen.new(scene)
        screen.pbStartSceneSingle(@pokemon.species)
      }
      dorefresh = true
    elsif cmdMark >= 0 && command == cmdMark
      dorefresh = pbMarking(@pokemon)
    elsif cmdCheckMoves >= 0 && command == cmdCheckMoves
      pbPlayDecisionSE
      pbMoveSelection
      dorefresh = true
    elsif cmdLearnMoves >= 0 && command == cmdLearnMoves
      pbRelearnMoveScreen(@pokemon)
      dorefresh = true
    elsif cmdForgetMove >= 0 && command == cmdForgetMove
      move_index = pbForgetMove(@pokemon, nil)
      if move_index >= 0
        old_move_name = @pokemon.moves[move_index].name
        pbMessage(_INTL("{1} forgot how to use {2}.", @pokemon.name, old_move_name))
        @pokemon.forget_move_at_index(move_index)
        dorefresh = true
      end
    elsif cmdTeachTMs >= 0 && command == cmdTeachTMs
      item = nil
      pbFadeOutIn {
        scene  = PokemonBag_Scene.new
        screen = PokemonBagScreen.new(scene, $bag)
        item = screen.pbChooseItemScreen(Proc.new{ |itm|
          move = GameData::Item.get(itm).move  
          next false if !move || @pokemon.hasMove?(move) || !@pokemon.compatible_with_move?(move)
          next true
        })
      }
      if item
        pbUseItemOnPokemon(item, @pokemon, self)
        dorefresh = true
      end
    end
    return dorefresh
  end
end