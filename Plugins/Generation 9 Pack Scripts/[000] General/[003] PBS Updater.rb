#===============================================================================
# PBS Updater
#===============================================================================
module Compiler
  module_function
  #-----------------------------------------------------------------------------
  # Applies PBS updates located in the Auto-Updates folder.
  #-----------------------------------------------------------------------------
  def update_gen9(*data_types)
    data_types = [:Ability, :Item, :Move, :Species] if data_types.length == 0
    data_types.each do |data_type|
      case data_type
      when :Ability then game_data = GameData::Ability
      when :Item    then game_data = GameData::Item
      when :Move    then game_data = GameData::Move
      when :Species then game_data = GameData::Species
      end
      base_filename = game_data::PBS_BASE_FILENAME
      base_filename = base_filename[0] if base_filename.is_a?(Array)
      path = "PBS/Gen 9 backup/Auto-Updates/#{base_filename}.txt"
      return if !FileTest.exist?(path)
      species_hash = {}
      schema = game_data.schema
      if data_type == :Species
        schema["Offspring"]  = [:offspring,  "*e",   :Species]
        schema["Evolutions"] = [:evolutions, "*ees", :Species, :Evolution, nil]
        game_data.each do |sp|
          next if !nil_or_empty?(sp.pbs_file_suffix)
          species_hash[sp.id] = game_data.initialize_from(sp.id)
        end
        species_hash.each do |id, hash|
          next if hash[:form] == 0
          [:moves, :tutor_moves, :egg_moves, :evolutions].each do |property|
            hash[property].clear if hash[property] == species_hash[hash[:species]][property]
          end
        end
      end
      compile_pbs_file_message_start(path)
      File.open(path, "rb") do |f|
        FileLineData.file = path
        pbEachFileSection(f, schema) do |contents, section_name|
          id = section_name.to_sym
          next if !game_data.try_get(id)
          if data_type == :Species
            data_hash = species_hash[id]
          else
            data_hash = game_data.initialize_from(id)
          end
          schema.each_key do |key|
            FileLineData.setSection(section_name, key, contents[key])
            next if contents[key].nil?
            if contents[key] == "nil"
              if data_hash[schema[key][0]].is_a?(Array)
                data_hash[schema[key][0]].clear
              else
                data_hash[schema[key][0]] = nil
              end
            elsif schema[key][1][0] == "^"
              contents[key].each do |val|
                value = get_csv_record(val, schema[key])
                value = nil if value.is_a?(Array) && value.empty?
                data_hash[schema[key][0]] ||= []
                data_hash[schema[key][0]].push(value)
              end
              data_hash[schema[key][0]].compact!
            else
              value = get_csv_record(contents[key], schema[key])
              value = nil if value.is_a?(Array) && value.empty?
              data_hash[schema[key][0]] = value
            end
          end
          if data_type != :Species
            case data_type
            when :Move
              validate_compiled_move(data_hash)
            when :Item
              if !data_hash.has_key?(:sell_price)
                data_hash[:sell_price] = data_hash[:price] / 2
              end
            end
            game_data::DATA[id] = game_data.new(data_hash)
          end
        end
      end
      if data_type == :Species
        game_data::DATA.clear
        finalize_all_recompiled_pokemon(species_hash)
        species_hash.each { |k, h| game_data.register(h) }
      end
      process_pbs_file_message_end
      game_data.save
      case data_type
      when :Ability then Compiler.write_abilities
      when :Item    then Compiler.write_items
      when :Move    then Compiler.write_moves
      when :Species then Compiler.write_pokemon; Compiler.write_pokemon_forms
      end
    end
    Compiler.compile_all(true)
  end
  
  #-----------------------------------------------------------------------------
  # The following methods are used only for validating :Species GameData.
  #-----------------------------------------------------------------------------
  def validate_recompiled_pokemon(hash)
    hash.each do |id, data|
      if data[:base_stats].is_a?(Array)
        new_stats = {}
        GameData::Stat.each_main do |s|
          new_stats[s.id] = (data[:base_stats][s.pbs_order] || 1) if s.pbs_order >= 0
        end
        data[:base_stats] = new_stats
      end
      if data[:evs].is_a?(Array)
        new_evs = {}
        data[:evs].each { |val| new_evs[val[0]] = val[1] }
        GameData::Stat.each_main { |s| new_evs[s.id] ||= 0 }
        data[:evs] = new_evs
      end
      if data[:types].is_a?(Array)
        data[:types].uniq!
        data[:types].compact!
      end
    end
  end
  
  def validate_recompiled_forms(hash)
    hash.each do |id, data|
      next if data[:form] == 0
      base_data = hash[data[:species]]
      [:real_name, :real_category, :real_pokedex_entry, :base_exp, :growth_rate,
       :gender_ratio, :catch_rate, :happiness, :hatch_steps, :incense, :height,
       :weight, :color, :shape, :habitat, :generation].each do |property|
        data[property] = base_data[property] if data[property].nil?
      end
      [:types, :base_stats, :evs, :abilities, :hidden_abilities, :egg_groups, 
       :offspring, :flags].each do |property|
        data[property] = base_data[property].clone if data[property].nil?
      end
      if data[:wild_item_common].nil? && data[:wild_item_uncommon].nil? && data[:wild_item_rare].nil?
        data[:wild_item_common] = base_data[:wild_item_common].clone
        data[:wild_item_uncommon] = base_data[:wild_item_uncommon].clone
        data[:wild_item_rare] = base_data[:wild_item_rare].clone
      end
    end
  end
  
  def validate_recompiled_evolutions(hash)
    hash.each do |id, data|
      FileLineData.setSection(id.to_s, "Evolutions", nil)
      data[:evolutions].each do |evo|
        param_type = GameData::Evolution.get(evo[1]).parameter
        if param_type.nil?
          evo[2] = nil
        elsif param_type == Integer
          evo[2] = cast_csv_value(evo[2], "u") if evo[2].is_a?(String)
        elsif param_type != String
          evo[2] = cast_csv_value(evo[2], "e", param_type) if evo[2].is_a?(String)
        end
      end
    end
    all_evos = {}
    hash.each do |id, data|
      data[:evolutions].each do |evo|
        next if evo[3]
        all_evos[evo[0]] = [data[:species], evo[1], evo[2], true] if !all_evos[evo[0]]
        if data[:form] > 0
          all_evos[[evo[0], data[:form]]] = [data[:species], evo[1], evo[2], true] if !all_evos[[evo[0], data[:form]]]
        end
      end
    end
    hash.each do |id, data|
      form = data[:form]
      data[:flags].each do |flag|
        form = $~[1].to_i if flag[/^DefaultForm_(\d+)$/i]
      end
      prevo_data = all_evos[[data[:species], form]] || all_evos[data[:species]]
      next if !prevo_data
      data[:evolutions].delete_if { |evo| evo[3] }
      data[:evolutions].push(prevo_data.clone)
      prevo = hash[prevo_data[0]]
      if prevo[:evolutions].none? { |evo| !evo[3] && evo[0] == data[:species] }
        prevo[:evolutions].push([data[:species], :None, nil])
      end
    end
  end
  
  def finalize_all_recompiled_pokemon(hash)    
    validate_recompiled_pokemon(hash)
    validate_recompiled_forms(hash)
    validate_recompiled_evolutions(hash)
    hash.each do |id, data|
      data[:moves] = data[:moves].sort_by(&:first)
      data[:moves].compact!
      data[:tutor_moves].sort!
      data[:tutor_moves].uniq!
      data[:tutor_moves].compact!
      data[:egg_moves].sort!
      data[:egg_moves].uniq!
      data[:egg_moves].compact!
    end
  end
end


#===============================================================================
# Initializes various GameData used by the PBS Updater.
#===============================================================================
module GameData
  class Ability
    def self.initialize_from(id)
      data = self.get(id)
      return {
        :id               => id,
        :real_name        => data.real_name,
        :real_description => data.real_description,
        :flags            => data.flags,
        :pbs_file_suffix  => data.pbs_file_suffix
      }
    end
  end
  
  class Item
    def self.initialize_from(id)
      data = self.get(id)
      return {
        :id                       => id,
        :real_name                => data.real_name,
        :real_name_plural         => data.real_name_plural,
        :real_portion_name        => data.real_portion_name,
        :real_portion_name_plural => data.real_portion_name_plural,
        :pocket                   => data.pocket,
        :price                    => data.price,
        :bp_price                 => data.bp_price,
        :field_use                => data.field_use,
        :battle_use               => data.battle_use,
        :flags                    => data.flags,
        :consumable               => data.consumable,
        :show_quantity            => data.show_quantity,
        :move                     => data.move,
        :real_description         => data.real_description,
        :pbs_file_suffix          => data.pbs_file_suffix
      }
    end
  end
  
  class Move
    def self.initialize_from(id)
      data = self.get(id)
      return {
        :id               => id,
        :real_name        => data.real_name,
        :type             => data.type,
        :category         => data.category,
        :power            => data.power,
        :accuracy         => data.accuracy,
        :total_pp         => data.total_pp,
        :target           => data.target,
        :priority         => data.priority,
        :function_code    => data.function_code,
        :flags            => data.flags,
        :effect_chance    => data.effect_chance,
        :real_description => data.real_description,
        :pbs_file_suffix  => data.pbs_file_suffix,
      }
    end
	
    def get_property_for_PBS(key)
      ret = __orig__get_property_for_PBS(key)
      ret = nil if ["Power", "Priority", "EffectChance"].include?(key) && ret == 0
      ret = ["Physical", "Special", "Status"][@category] if key == "Category"
      return ret
    end
  end
    
  class Species
    def self.initialize_from(id)
      data = self.get(id)
      return {
        :id                 => id,
        :species            => data.species,
        :form               => data.form,
        :pokedex_form       => data.pokedex_form,
        :real_name          => data.real_name,
        :real_form_name     => data.real_form_name,
        :real_category      => data.real_category,
        :real_pokedex_entry => data.real_pokedex_entry,
        :types              => data.types,
        :base_stats         => data.base_stats,
        :evs                => data.evs,
        :base_exp           => data.base_exp,
        :growth_rate        => data.growth_rate,
        :gender_ratio       => data.gender_ratio,
        :catch_rate         => data.catch_rate,
        :happiness          => data.happiness,
        :moves              => data.moves,
        :tutor_moves        => data.tutor_moves.sort,
        :egg_moves          => data.egg_moves.sort,
        :abilities          => data.abilities,
        :hidden_abilities   => data.hidden_abilities,
        :wild_item_common   => data.wild_item_common,
        :wild_item_uncommon => data.wild_item_uncommon,
        :wild_item_rare     => data.wild_item_rare,
        :egg_groups         => data.egg_groups,
        :hatch_steps        => data.hatch_steps,
        :incense            => data.incense,
        :offspring          => data.offspring,
        :evolutions         => data.evolutions,
        :height             => data.height,
        :weight             => data.weight,
        :color              => data.color,
        :shape              => data.shape,
        :habitat            => data.habitat,
        :generation         => data.generation,
        :mega_stone         => data.mega_stone,
        :mega_move          => data.mega_move,
        :unmega_form        => data.unmega_form,
        :mega_message       => data.mega_message,
        :flags              => data.flags,
        :pbs_file_suffix    => data.pbs_file_suffix
      }
    end
  end
end