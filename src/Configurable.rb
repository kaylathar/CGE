
module Configurable
  def has_option(name,type,optionType = Option)
    define_method("#{name}") do
      unless instance_variable_get("@"+name)
        instance_variable_set("@"+name,optionType.new(name,type))   
      end

      instance_variable_get("@"+name)
    end
     
    begin
      class_variable_get("@@options")
    rescue
      class_variable_set("@@options",Hash.new)
    end 

    class_variable_get("@@options")[name] = type

    unless respond_to?(:process_options)
      define_method("process_options") do |initOptions|
        initOptions.each do |key,value|
          key = key.to_s
          raise OptionException, "Invalid option #{key}" unless self.class.options[key]
          opt = send("#{key}")
          opt.value = value;
          raise OptionException, "Invalid option value for option #{key}" unless opt.is_valid?   
        end
      end
      protected :process_options 
    end
  end

  def options
    class_variable_get("@@options")
  end

end

class Option
  attr_reader :name,:type
  attr_accessor :value

  def initialize(name,type)
    @type = type;
    @name = name;
  end

  def is_valid?
    @value != nil && @value.is_a?(@type)
  end
end

class OptionException < Exception
end
