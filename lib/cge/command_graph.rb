# frozen_string_literal: true

require 'securerandom'
Dir["#{File.dirname(__FILE__)}/monitors/*"].sort.each { |file| require file }
Dir["#{File.dirname(__FILE__)}/actions/*"].sort.each { |file| require file }
Dir["#{File.dirname(__FILE__)}/inputs/*"].sort.each { |file| require file }
Dir["#{File.dirname(__FILE__)}/conditionals/*"].sort.each { |file| require file }
Dir["#{File.dirname(__FILE__)}/services/*"].sort.each { |file| require file }

module CGE
  # Represents a graph of Monitor and Action objects
  # when requested, will begin watching the Monitor
  # and when it triggers will invoke the action by
  # default Command continues monitoring forever
  # though subclasses may override this behavior
  class CommandGraph
    attr_reader :name, :id, :initial_command, :constants, :owner_id

    @plugins_loaded = false

    # Load additional plugins from configured paths
    # @param global_configuration [GlobalConfiguration] Global configuration containing plugin paths
    def self.load_additional_plugins(global_configuration)
      return if @plugins_loaded
      return unless global_configuration&.additional_plugins

      global_configuration.additional_plugins.each do |plugin_path|
        load_plugins_from_path(plugin_path)
      end

      @plugins_loaded = true
    end

    # Load all Ruby files from a specific path
    # @param path [String] Path to directory containing plugin files
    def self.load_plugins_from_path(path)
      return unless File.directory?(path)

      Dir["#{path}/**/*.rb"].sort.each do |file|
        begin
          require file
        rescue LoadError => e
          warn "Failed to load plugin from #{file}: #{e.message}"
        end
      end
    end

    # Create a new command object from a data source
    # @param id [String] Optional unique identifier for this graph (auto-generated if not provided)
    # @param name [String] The user readable name for this graph
    # @param initial_command [Command] The first command of the command graph
    # @param global_configuration [GlobalConfiguration] Optional global configuration instance
    # @param constants [Hash] Optional hash of graph-level constants
    # @param owner_id [String] Optional ID of the user who owns this graph
    # @param repeat [Boolean] Whether the graph should repeat when it reaches the end (defaults to false)
    def initialize(id, name, initial_command, global_configuration = nil, constants = {}, owner_id = nil, repeat = false)
      @id = id || SecureRandom.uuid
      @name = name
      @initial_command = initial_command
      @current_command = initial_command
      @variables = {}
      @initial_variables = {}
      @constants = constants
      @owner_id = owner_id

      # Store constants under the 'graph' namespace
      constants.each do |key, value|
        @variables["graph.#{key}"] = value
      end

      global_configuration&.command_visible_configs&.each do |key, value|
        @variables["global.#{key}"] = value
      end

      @initial_variables = @variables.clone
      @repeat = repeat
    end

    # Begins executing the command by starting the monitor specified in
    # the data source - will return immediately
    def execute
      @cancelled = false
      @thread = Thread.new do
        if Thread.current != Thread.main
          loop do
            # If we are repeatable, then repeat if we are at the end
            if @current_command.nil? && @repeat
              @current_command = @initial_command
              @variables = @initial_variables.dup
            end

            break if @current_command.nil? || @cancelled

            next_command = @current_command.execute(substitute_variables(@current_command.inputs, @variables),
                                                    @current_command.next_command)
            @current_command.class.outputs.each_key do |output_name|
              output_value = @current_command.send(output_name)
              @variables["#{@current_command.id}.#{output_name}"] = output_value
            end
            @current_command = next_command
          end
        end
      end
    end

    # Apply in place subsitutions over a set of inputs using a set
    # of output variables and global configuration
    # @param inputs [Hash] The set of inputs that should have values substituted in
    # @param variables [Hash] The set of variables in key/value format that are used for subs
    def substitute_variables(inputs, variables)
      # Copy so we don't squash the original inputs
      processed_inputs = inputs.clone
      # Apply Command output substitutions
      variables.each do |variable_name, variable_value|
        processed_inputs.each do |input_key, input_value|
          if input_value.is_a?(String)
            processed_inputs[input_key] =
              input_value.gsub("{{#{variable_name}}}", variable_value.to_s)
          end
        end
      end
      processed_inputs
    end

    # Gracefully cancels command graph execution
    def cancel
      return unless @thread

      @cancelled = true
      # Give the thread a moment to finish gracefully
      @thread.join(1.0)
      # Force termination only if thread is still alive after timeout
      @thread.kill if @thread.alive?
    end

    # Resets the command graph to its initial state by cancelling
    # execution if it is going on and clearing all stored variables
    # in the graph
    def reset
      cancel
      @current_command = @initial_command
      @variables = @initial_variables.dup
    end

    protected :substitute_variables
  end

  # Exception generated during loading or execution of command
  class CommandGraphException < StandardError
  end
end
