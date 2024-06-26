#===============================================================================
#  Loads an animated BitmapWrapper for Pokemon
#===============================================================================
def pbLoadPokemonBitmap(pokemon, back = false, scale = EliteBattle::FRONT_SPRITE_SCALE, speed = 2)
  return pbLoadPokemonBitmapSpecies(pokemon, pokemon.species, back, scale, speed)
end
#===============================================================================
#  Loads an animated BitmapWrapper for Pokemon species
#===============================================================================
def pbLoadPokemonBitmapSpecies(pokemon, species, back = false, scale = EliteBattle::FRONT_SPRITE_SCALE, speed = 2)
  ret = nil
  pokemon = pokemon.pokemon if pokemon.respond_to?(:pokemon)
  species = pokemon.species if species.nil? && pokemon.respond_to?(:species)
  # sauce
  species = :BIDOOF if GameData::Species.exists?(:BIDOOF) && defined?(firstApr?) && firstApr?
  # return question marks if no species provided
  return BitmapEBDX.new("Graphics/EBDX/Battlers/000", scale) if species.nil?
  # applies scale
  scale = back ? EliteBattle::BACK_SPRITE_SCALE : EliteBattle::FRONT_SPRITE_SCALE
  # gets additional scale (if applicable)
  s = EliteBattle.get_data(species, :Species, (back ? :BACKSCALE : :SCALE), (pokemon.form rescue 0))
  scale = s if !s.nil? && s.is_a?(Numeric)
  # get more metrics
  s = EliteBattle.get_data(species, :Species, :SPRITESPEED, (pokemon.form rescue 0))
  speed = s if !s.nil? && s.is_a?(Numeric)
  species_id = EliteBattle.GetSpeciesIndex(species)
  #echoln _INTL("Species ID: {1}",species_id)
  if pokemon.egg?
    eggPath = "Graphics/EBDX/Battlers/Eggs/"
    bitmapFileName = sprintf("#{eggPath}%s", species) rescue nil
    if !pbResolveBitmap(bitmapFileName)
      bitmapFileName = sprintf("#{eggPath}%03d", species_id)
      if !pbResolveBitmap(bitmapFileName)
        bitmapFileName = sprintf("#{eggPath}000")
      end
    end

    if !pbResolveBitmap(bitmapFileName)
      eggPath = "Graphics/Pokemon/Eggs/"
      bitmapFileName = sprintf("#{eggPath}%s", species) rescue nil
      if !pbResolveBitmap(bitmapFileName)
        bitmapFileName = sprintf("#{eggPath}%03d", species_id)
        if !pbResolveBitmap(bitmapFileName)
          bitmapFileName = sprintf("#{eggPath}000")
        end
      end
    end
    #bitmapFileName = pbResolveBitmap(bitmapFileName)
  else
    shiny = pokemon.shiny?
    shiny = pokemon.superVariant if (!pokemon.superVariant.nil? && pokemon.superShiny?)
    params = [species, back, pokemon.female?, shiny, (pokemon.form rescue 0), (pokemon.shadowPokemon? rescue false), (pokemon.dynamax rescue false), (pokemon.dynamax && pokemon.gfactor rescue false)]
    bitmapFileName = pbCheckPokemonBitmapFiles(params)
  end
  if bitmapFileName.nil?
    bitmapFileName = "Graphics/EBDX/Battlers/000"
    if !pbResolveBitmap(bitmapFileName)
      bitmapFileName = "Graphics/Pokemon/Front/000" 
    end  
    EliteBattle.log.warn(missingPokeSpriteError(pokemon, back)) 
  end
  animatedBitmap = BitmapEBDX.new(bitmapFileName, scale, speed) if bitmapFileName
  ret = animatedBitmap if bitmapFileName
  # Full compatibility with the alterBitmap methods is maintained
  # but unless the alterBitmap method gets rewritten and sprite animations get
  # hardcoded in the system, the bitmap alterations will not function properly
  # as they will not account for the sprite animation itself

  # alterBitmap methods for static sprites will work just fine
  alterBitmap = (MultipleForms.getFunction(species, "alterBitmap") rescue nil) if !pokemon.egg? && animatedBitmap && animatedBitmap.totalFrames == 1 # remove this totalFrames clause to allow for dynamic sprites too
  if bitmapFileName && alterBitmap
    animatedBitmap.prepare_strip
    for i in 0...animatedBitmap.totalFrames
      alterBitmap.call(pokemon, animatedBitmap.alter_bitmap(i))
    end
    animatedBitmap.compile_strip
    ret = animatedBitmap
  end
  # adjusts for custom animation loops
  data = EliteBattle.get_data(species, :Species, :FRAMEANIMATION, (pokemon.form rescue 0))
  unless data.nil?
    ret.compile_loop(data)
  end
  # applies super shiny hue
  ret.hue_change(pokemon.superHue) if pokemon.superHue && !ret.changedHue?
  # refreshes bitmap
  ret.deanimate if ret.respond_to?(:deanimate)
  return ret
end
#===============================================================================
#  Pokemon icon aditions
#===============================================================================
def pbPokemonIconFile(pokemon)
  bitmapFileName = nil
  species = pokemon.species
  # sauce
  species = :BIDOOF if GameData::Species.exists?(:BIDOOF) && defined?(firstApr?) && firstApr?
  bitmapFileName = pbCheckPokemonIconFiles([species, (pokemon.female?),
     pokemon.shiny?,(pokemon.form rescue 0),(pokemon.shadowPokemon? rescue false)],
     pokemon.egg?)
  return bitmapFileName
end
#===============================================================================
#  Loads animated BitmapWrapper for species
#===============================================================================
def pbLoadSpeciesBitmap(species, female=false, form=0, shiny=false, shadow=false, back=false, egg=false, scale=EliteBattle::FRONT_SPRITE_SCALE)
  ret = nil
  species = :BIDOOF if GameData::Species.exists?(:BIDOOF) && defined?(firstApr?) && firstApr?
  # return question marks if no species provided
  return BitmapEBDX.new("Graphics/EBDX/Battlers/000", scale) if species.nil?
  # applies scale
  scale = back ? EliteBattle::BACK_SPRITE_SCALE : EliteBattle::FRONT_SPRITE_SCALE
  # gets additional scale (if applicable)
  s = EliteBattle.get_data(species, :Species, (back ? :BACKSCALE : :SCALE), (form rescue 0))
  scale = s if !s.nil? && s.is_a?(Numeric)
  species_id = EliteBattle.GetSpeciesIndex(species)
  # check sprite
  if egg
    eggPath = "Graphics/EBDX/Battlers/Eggs/"
    bitmapFileName = sprintf("#{eggPath}%s", species) rescue nil
    ret = pbResolveBitmap(bitmapFileName)
    if !ret
      bitmapFileName = sprintf("#{eggPath}%03d", species_id)
      ret = pbResolveBitmap(bitmapFileName)
      if !ret
        bitmapFileName = sprintf("#{eggPath}000")
      end
    end

    if !pbResolveBitmap(bitmapFileName)
      eggPath = "Graphics/Pokemon/Eggs/"
      bitmapFileName = sprintf("#{eggPath}%s", species) rescue nil
      ret = pbResolveBitmap(bitmapFileName)
      if !ret
        bitmapFileName = sprintf("#{eggPath}%03d", species_id)
        ret = pbResolveBitmap(bitmapFileName)
        if !ret
          bitmapFileName = sprintf("#{eggPath}000")
        end
      end
    end
    #bitmapFileName = pbResolveBitmap(bitmapFileName)
  else
    bitmapFileName = pbCheckPokemonBitmapFiles([species, back, female, shiny, form, shadow, false, false])
  end
  if bitmapFileName
    ret = BitmapEBDX.new(bitmapFileName, scale)
  end
  # adjusts for custom animation loops
  data = EliteBattle.get_data(species, :Species, :FRAMEANIMATION, form)
  unless data.nil?
    ret.compile_loop(data)
  end
  # refreshes bitmap
  ret.deanimate if ret.respond_to?(:deanimate)
  return ret
end
#===============================================================================
#  Returns error message upon missing sprites
#===============================================================================
def missingPokeSpriteError(pokemon, back)
  error_b = back ? "Back" : "Front"
  error_b += "Shiny" if pokemon.shiny?
  error_b += "/Female/" if pokemon.female?
  error_b += " shadow" if pokemon.shadowPokemon?
  error_b += " form #{pokemon.form} " if pokemon.form > 0
  return "Looks like you're missing the #{error_b} sprite for #{GameData::Species.get(pokemon.species).real_name}!"
end
#===============================================================================
#  New methods of handing Pokemon sprite name references
#===============================================================================
def pbCheckPokemonBitmapFiles(params)
  species = params[0]; back = params[1]; factors = []
  factors.push([5, params[5], false]) if params[5] && params[5] != false # shadow
  factors.push([2, params[2], false]) if params[2] && params[2] != false # gender
  factors.push([3, params[3], false]) if params[3] && params[3] != false # shiny
  factors.push([6, params[6], false]) if params[6] && params[6] != false # dynamaxed
  factors.push([7, params[7], false]) if params[7] && params[7] != false # gigantimaxed
  factors.push([4, params[4].to_s, ""]) if params[4] && params[4].to_s != "" && params[4].to_s != "0" # form
  tshadow = false; tgender = false; tshiny = false; tform = ""
  for i in 0...(2**factors.length)
    for j in 0...factors.length
      case factors[j][0]
      when 2   # gender
        tgender = ((i/(2**j))%2 == 0) ? factors[j][1] : factors[j][2]
      when 3   # shiny
        tshiny = ((i/(2**j))%2 == 0) ? factors[j][1] : factors[j][2]
      when 4   # form
        tform = ((i/(2**j))%2 == 0) ? factors[j][1] : factors[j][2]
      when 5   # shadow
        tshadow = ((i/(2**j))%2 == 0) ? factors[j][1] : factors[j][2]
      when 6   # dynamaxed
        tdyna = ((i/(2**j))%2 == 0) ? factors[j][1] : factors[j][2]
      when 7   # gigantimaxed
        tgigant = ((i/(2**j))%2 == 0) ? factors[j][1] : factors[j][2]
      end
    end
    subdir = "Front"
    if tshiny  && back
      subdir= "BackShiny"
    elsif tshiny 
      subdir = "FrontShiny"
    elsif back
      subdir = "Back"
    end
    folder = "Graphics/EBDX/Battlers/"+subdir
    folder2 = "Graphics/Pokemon/"+subdir

    dirs = []; dirs.push("/Gigantamax") if tgigant; dirs.push("/Dynamax") if tdyna && !tgigant; dirs.push("/Female") if tgender; dirs.push("")
    for dir in dirs
      species_id = EliteBattle.GetSpeciesIndex(species)
      species_ = EliteBattle.GetSpeciesID(species)
      if EliteBattle::PRIORITIZE_ANIMATED_SPRITES
        bitmapFileName = sprintf("#{folder}#{dir}/%03d%s%s", species_id, (tform != "" ? "_" + tform : ""), tshadow ? "_shadow" : "")
        ret = pbResolveBitmap(bitmapFileName)
        if !ret
          bitmapFileName = sprintf("#{folder}#{dir}/%s%s%s", species_, (tform != "" ? "_" + tform : ""), tshadow ? "_shadow" : "")
          ret = pbResolveBitmap(bitmapFileName)
          if !ret
            if EliteBattle::PRIORITIZE_REGULAR_SPRITES
              bitmapFileName = sprintf("#{folder}/%03d%s%s", species_id, (tform != "" ? "_" + tform : ""), tshadow ? "_shadow" : "")
              ret = pbResolveBitmap(bitmapFileName)
              if !ret
                bitmapFileName = sprintf("#{folder}/%s%s%s", species_, (tform != "" ? "_" + tform : ""), tshadow ? "_shadow" : "")
                ret = pbResolveBitmap(bitmapFileName)
                if !ret
                  bitmapFileName = sprintf("#{folder2}/%03d%s%s%s", species_id, (tform != "" ? "_" + tform : ""), tshadow ? "_shadow" : "","_#{dir}")
                  ret = pbResolveBitmap(bitmapFileName)
                  if !ret
                    bitmapFileName = sprintf("#{folder2}/%s%s%s%s", species_, (tform != "" ? "_" + tform : ""), tshadow ? "_shadow" : "","_#{dir}")
                    ret = pbResolveBitmap(bitmapFileName)
                    if !ret
                      bitmapFileName = sprintf("#{folder2}/%03d%s%s", species_id, (tform != "" ? "_" + tform : ""), tshadow ? "_shadow" : "")
                      ret = pbResolveBitmap(bitmapFileName)
                      if !ret
                        bitmapFileName = sprintf("#{folder2}/%s%s%s", species_, (tform != "" ? "_" + tform : ""), tshadow ? "_shadow" : "")
                        ret = pbResolveBitmap(bitmapFileName)
                      end 
                    end 
                  end 
                end  
              end
            else  
              if !ret
                bitmapFileName = sprintf("#{folder2}/%03d%s%s%s", species_id, (tform != "" ? "_" + tform : ""), tshadow ? "_shadow" : "","_#{dir}")
                ret = pbResolveBitmap(bitmapFileName)
                if !ret
                  bitmapFileName = sprintf("#{folder2}/%s%s%s%s", species_, (tform != "" ? "_" + tform : ""), tshadow ? "_shadow" : "","_#{dir}")
                  ret = pbResolveBitmap(bitmapFileName)
                  if !ret
                    bitmapFileName = sprintf("#{folder}/%03d%s%s", species_id, (tform != "" ? "_" + tform : ""), tshadow ? "_shadow" : "")
                    ret = pbResolveBitmap(bitmapFileName)
                    if !ret
                      bitmapFileName = sprintf("#{folder}/%s%s%s", species_, (tform != "" ? "_" + tform : ""), tshadow ? "_shadow" : "")
                      ret = pbResolveBitmap(bitmapFileName)
                      if !ret
                        bitmapFileName = sprintf("#{folder2}/%03d%s%s", species_id, (tform != "" ? "_" + tform : ""), tshadow ? "_shadow" : "")
                        ret = pbResolveBitmap(bitmapFileName)
                        if !ret
                          bitmapFileName = sprintf("#{folder2}/%s%s%s", species_, (tform != "" ? "_" + tform : ""), tshadow ? "_shadow" : "")
                          ret = pbResolveBitmap(bitmapFileName)
                        end 
                      end 
                    end  
                  end  
                end 
              end 
            end
          end
        end  
      else
        bitmapFileName = sprintf("#{folder2}/%03d%s%s%s", species_id, (tform != "" ? "_" + tform : ""), tshadow ? "_shadow" : "","_#{dir}")
        ret = pbResolveBitmap(bitmapFileName)
        if !ret
          bitmapFileName = sprintf("#{folder2}/%s%s%s%s", species_, (tform != "" ? "_" + tform : ""), tshadow ? "_shadow" : "","_#{dir}")
          ret = pbResolveBitmap(bitmapFileName)
          if !ret
            if EliteBattle::PRIORITIZE_REGULAR_SPRITES
              bitmapFileName = sprintf("#{folder2}/%03d%s%s", species_id, (tform != "" ? "_" + tform : ""), tshadow ? "_shadow" : "")
              ret = pbResolveBitmap(bitmapFileName)
              if !ret
                bitmapFileName = sprintf("#{folder2}/%s%s%s", species_, (tform != "" ? "_" + tform : ""), tshadow ? "_shadow" : "")
                ret = pbResolveBitmap(bitmapFileName)
                if !ret
                  bitmapFileName = sprintf("#{folder}#{dir}/%03d%s%s", species_id, (tform != "" ? "_" + tform : ""), tshadow ? "_shadow" : "")
                  ret = pbResolveBitmap(bitmapFileName)
                  if !ret
                    bitmapFileName = sprintf("#{folder}#{dir}/%s%s%s", species_, (tform != "" ? "_" + tform : ""), tshadow ? "_shadow" : "")
                    ret = pbResolveBitmap(bitmapFileName)
                    if !ret
                      bitmapFileName = sprintf("#{folder}/%03d%s%s", species_id, (tform != "" ? "_" + tform : ""), tshadow ? "_shadow" : "")
                      ret = pbResolveBitmap(bitmapFileName)
                      if !ret
                        bitmapFileName = sprintf("#{folder}/%s%s%s", species_, (tform != "" ? "_" + tform : ""), tshadow ? "_shadow" : "")
                        ret = pbResolveBitmap(bitmapFileName)
                      end 
                    end 
                  end 
                end  
              end
            else  
              if !ret
                bitmapFileName = sprintf("#{folder}#{dir}/%03d%s%s", species_id, (tform != "" ? "_" + tform : ""), tshadow ? "_shadow" : "")
                ret = pbResolveBitmap(bitmapFileName)
                if !ret
                  bitmapFileName = sprintf("#{folder}#{dir}/%s%s%s", species_, (tform != "" ? "_" + tform : ""), tshadow ? "_shadow" : "")
                  ret = pbResolveBitmap(bitmapFileName)
                  if !ret
                    bitmapFileName = sprintf("#{folder2}/%03d%s%s", species_id, (tform != "" ? "_" + tform : ""), tshadow ? "_shadow" : "")
                    ret = pbResolveBitmap(bitmapFileName)
                    if !ret
                      bitmapFileName = sprintf("#{folder2}/%s%s%s", species_, (tform != "" ? "_" + tform : ""), tshadow ? "_shadow" : "")
                      ret = pbResolveBitmap(bitmapFileName)
                      if !ret
                        bitmapFileName = sprintf("#{folder}/%03d%s%s", species_id, (tform != "" ? "_" + tform : ""), tshadow ? "_shadow" : "")
                        ret = pbResolveBitmap(bitmapFileName)
                        if !ret
                          bitmapFileName = sprintf("#{folder}/%s%s%s", species_, (tform != "" ? "_" + tform : ""), tshadow ? "_shadow" : "")
                          ret = pbResolveBitmap(bitmapFileName)
                        end 
                      end 
                    end  
                  end  
                end 
              end 
            end
          end
        end
      end  
      #echoln "#{bitmapFileName} - #{ret}"
      return bitmapFileName if ret
    end
  end
  return nil
end

#===============================================================================
#  Returns full path for sprite
#===============================================================================
def pbPokemonBitmapFile(species, shiny, back=false)
  subdir = "Front/"
    if shiny && back
      subdir= "BackShiny/"
    elsif shiny 
      subdir = "FrontShiny/"
    elsif back
      subdir = "Back/"
    end
    folder = "Graphics/EBDX/Battlers/"+subdir
    folder2 = "Graphics/Pokemon/"+subdir
  #GameData::Species.try_get(species)&.species
  if EliteBattle::PRIORITIZE_ANIMATED_SPRITES
    species_id = EliteBattle.GetSpeciesIndex(species) 
    name = sprintf("#{folder}%03d", species_id) #check %s 
    ret = pbResolveBitmap(name)
    return ret if ret
    name = sprintf("#{folder}%s", species) rescue nil
    ret = pbResolveBitmap(name)
    return ret if ret
    name = sprintf("#{folder2}%03d", species_id) #check %s 
    ret = pbResolveBitmap(name)
    return ret if ret
    name = sprintf("#{folder2}%s", species) rescue nil
    return pbResolveBitmap(name)
  else  
    name = sprintf("#{folder}%s", species) rescue nil
    ret = pbResolveBitmap(name)
    return ret if ret
    species_id = EliteBattle.GetSpeciesIndex(species) 
    name = sprintf("#{folder}%03d", species_id) #check %s 
    ret = pbResolveBitmap(name)
    return ret if ret
    name = sprintf("#{folder2}%s", species) rescue nil
    ret = pbResolveBitmap(name)
    return ret if ret
    name = sprintf("#{folder2}%03d", species_id) #check %s 
    return pbResolveBitmap(name)
  end
end
#===============================================================================
#  Game data overrides
#===============================================================================
module GameData
  #-----------------------------------------------------------------------------
  #  Species class (bitmaps)
  #-----------------------------------------------------------------------------
  class Species
    #---------------------------------------------------------------------------
    #  get bitmap from species
    #---------------------------------------------------------------------------
    def self.sprite_bitmap(species, form = 0, gender = 0, shiny = false, shadow = false, back = false, egg = false)
      return pbLoadSpeciesBitmap(species, (gender == 1), form, shiny, shadow, back, egg)
    end
    #---------------------------------------------------------------------------
    #  get bitmap from Pokemon
    #---------------------------------------------------------------------------
    def self.sprite_bitmap_from_pokemon(pokemon, back = false, species = nil)
      return pbLoadPokemonBitmapSpecies(pokemon, species, back)
    end
    #---------------------------------------------------------------------------
    #  get icon from species
    #---------------------------------------------------------------------------
    def self.icon_bitmap(species, form = 0, gender = 0, shiny = false, shadow = false)
      species = :BIDOOF if GameData::Species.exists?(:BIDOOF) && defined?(firstApr?) && firstApr?
      filename = self.icon_filename(species, form, gender, shiny, shadow)
      return (filename) ? AnimatedBitmap.new(filename).deanimate : nil
    end
    #---------------------------------------------------------------------------
    #  get icon from Pokemon
    #---------------------------------------------------------------------------
    def self.icon_bitmap_from_pokemon(pkmn)
      species = (GameData::Species.exists?(:BIDOOF) && defined?(firstApr?) && firstApr?) ? :BIDOOF : pkmn.species
      return self.icon_bitmap(species, pkmn.form, pkmn.gender, pkmn.shiny?, pkmn.shadowPokemon?, pkmn.egg?)
    end
    #---------------------------------------------------------------------------
  end
  #-----------------------------------------------------------------------------
end
