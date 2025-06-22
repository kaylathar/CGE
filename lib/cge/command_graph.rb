require 'thread'
Dir["#{File.dirname(__FILE__)}/monitors/*"].sort.each { |file| require file }
Dir["#{File.dirname(__FILE__)}/actions/*"].sort.each { |file| require file }
Dir["#{File.dirname(__FILE__)}/inputs/*"].sort.each { |file| require file }
Dir["#{File.dirname(__FILE__)}/conditionals/*"].sort.each { |file| require file }

module CGE
  # Represents a graph of Monitor and Action objects
  # when requested, will begin watching the Monitor
  # and when it triggers will invoke the action by
  # default Command continues monitoring forever
  # though subclasses may override this behavior
  class CommandGraph
    attr_reader :name

    # Create a new command object from a data source
    # @param initial_command [Command] The first command of the command graph
    # @param global_configuration [GlobalConfiguration] Optional global configuration instance
    # @param constants [Hash] Optional hash of graph-level constants
    def initialize(name, initial_command, global_configuration = nil, constants = {})
      @name = name
      @current_command = initial_command
      @variables = {}

      # Store constants under the 'graph' namespace
      constants.each do |key, value|
        @variables["graph.#{key}"] = value
      end

      return unless global_configuration

      global_configuration.outputs.each_key do |output_name|
        output_value = global_configuration.send(output_name)
        @variables["global.#{output_name}"] = output_value unless output_value.nil?
      end
    end

    # Begins executing the command by starting the monitor specified in
    # the data source - will return immediately
    def execute
      @thread = Thread.new do
        if Thread.current != Thread.main
          loop do
            break if @current_command.nil?

            next_command = @current_command.execute(apply_variables(@current_command.options, @variables),
                                                    @current_command.next)
            @current_command.class.variables.each_key do |output_name|
              output_value = @current_command.send(output_name)
              @variables["#{@current_command.name}.#{output_name}"] = output_value
            end
            @current_command = next_command
          end
        end
      end
    end

    # Apply in place subsitutions over a set of input options using a set
    # of output options and global configuration
    # @param input_options [Hash] The set of inputs that should have values substituted in
    # @param variables [Hash] The set of variables in key/value format that are used for subs
    def substitute_variables(input_options, variables)
      # Copy so we don't squash the original options
      options = input_options.clone
      # Apply Command output substitutions
      variables.each do |variable_name, variable_value|
        options.each do |option_key, option_value|
          if option_value.is_a?(String)
            options[option_key] =
              option_value.gsub("{{#{variable_name}}}", variable_value.to_s)
          end
        end
      end
      options
    end

    # Immediately cancels command graph execution
    def cancel
      @thread.kill
    end

    protected :substitute_variables
  end

  # Exception generated during loading or execution of command
  class CommandGraphException < StandardError
  end
end
