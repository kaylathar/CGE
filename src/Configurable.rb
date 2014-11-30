
# Module used for configurable objects internally
# adds the has_option class method that creates an option
# for use on Monitor and Action subclasses - it exposes
# the options that are present, and required types, so that
# parsers and UI can view them if required
#
# Of particular note, it adds an accessor to instances 
# for each option, a process_options helper method to
# parse a hash set of parameters into options and validate
# each option, and a options class method that returns the options
# this class supports in the form of a hash
module Configurable
  def has_option(name,type,&verifier)
    name = name.to_s
    define_method("#{name}") do
      unless instance_variable_get("@"+name)
        instance_variable_set("@"+name,Option.new(name,type,verifier))   
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

  def has_output(name, type)
    define_method("@#{name}") do
      instance_variable_get("@#{name}")
    end

    begin
      class_variable_get("@@outputs")
    rescue
      class_variable_set("@@outputs",Hash.new)  
    end

    class_variable_get("@@outputs")[name]=type
  end

  def options
    class_variable_get("@@options")
  end

  def outputs
    class_variable_get("@@outputs")
  end

end

# Used to store options - includes the expected type
# the name, and the value.  Also includes validation logic
# - the absence of validation logic in the value= operator is
# intentional, as there may be cases where you can set an invalid
# option value
class Option
  attr_reader :name,:type
  attr_accessor :value

  def initialize(name,type,verifier = nil,&block_verifier)
    @type = type;
    @name = name;
    @verifier = if verifier
      verifier
    elsif block_verifier
      block_verifier
    else
      true
    end
  end

  def is_valid?
    @value != nil && @value.is_a?(@type) && (@verifier == true || @verifier.call(@value))
  end
end

class OptionException < Exception
end
