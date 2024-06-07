#===============================================================================
#
#===============================================================================
class PokemonPokedexInfo_Scene
  alias paldea_pbUpdateDummyPokemon pbUpdateDummyPokemon
  def pbUpdateDummyPokemon
    @sprites["formback"]&.zoom_x = 1.0
    @sprites["formback"]&.zoom_y = 1.0
    paldea_pbUpdateDummyPokemon
    if @sprites["formback"] && @sprites["formback"].bitmap.width > 200
      @sprites["formback"].zoom_x *= 2 / 3.0
      @sprites["formback"].zoom_y *= 2 / 3.0
      @sprites["formback"].y = 256
    end
  end
end