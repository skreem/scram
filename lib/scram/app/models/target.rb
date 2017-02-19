module Scram
  class Target
    include Mongoid::Document
    embedded_in :policy

    field :actions, type: Array, default: []
    field :conditions, type: Hash, default: {}
    
    field :priority, type: Integer, default: 0
    field :allow, type: Boolean, default: true

    def can? holder, action, obj
      return false unless actions.include? action

      if obj.is_a? String # ex: can? user, :view, "peek_bar"
        return obj == conditions[:equals][:@target_name]
        # ex: conditions: {equals: {@target_name: "peek_bar"}}
      else
        conditions.each do |comparator_name, fields_hash|
          comparator = Scram::DSL::Definitions::COMPARATORS[comparator_name]
          fields_hash.each do |field, model_value|
            # equals: {@involved: @holder}
            # equals: {age: 50}
            # @ symbol in field name => it is defined as a DSL condition, otherwise it is a model attribute
            # @ symbol in model_value => a special replace variable
            field = field.to_s
            attribute = if field.starts_with? "@"
              policy.model.scram_conditions[field.split("@")[1].to_sym].call(obj)
            else
              obj.send(field)
            end

            model_value.gsub! "@holder", holder.scram_compare_value if model_value.respond_to?(:gsub!)

            return comparator.call(attribute, model_value)
          end
        end
      end
    end
  end
end
