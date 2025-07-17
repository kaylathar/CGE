# frozen_string_literal: true

require 'securerandom'
Dir["#{File.dirname(__FILE__)}/monitors/*"].sort.each { |file| require file }
Dir["#{File.dirname(__FILE__)}/actions/*"].sort.each { |file| require file }
Dir["#{File.dirname(__FILE__)}/inputs/*"].sort.each { |file| require file }
Dir["#{File.dirname(__FILE__)}/conditionals/*"].sort.each { |file| require file }
Dir["#{File.dirname(__FILE__)}/services/*"].sort.each { |file| require file }

require 'cge/logging'

module CGE
  # Represents a graph of Monitor and Action objects
  # when requested, will begin watching the Monitor
  # and when it triggers will invoke the action by
  # default Command continues monitoring forever
  # though subclasses may override this behavior
  class CommandGraph
    include Logging
    attr_reader :name, :id, :initial_command, :constants, :owner_id, :subgraphs, :initial_subgraph_id, :graph_executor

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

    # Create a new command object from subgraph data
    # @param id [String] Optional unique identifier for this graph (auto-generated if not provided)
    # @param name [String] The user readable name for this graph
    # @param subgraphs [Hash] Hash of subgraph_id => first_command_of_subgraph (required)
    # @param initial_subgraph_id [String] ID of the subgraph to start execution with (required)
    # @param global_configuration [GlobalConfiguration] Optional global configuration instance
    # @param constants [Hash] Optional hash of graph-level constants
    # @param owner_id [String] Optional ID of the user who owns this graph
    # @param repeat [Boolean] Whether the graph should repeat when it reaches the end (defaults to false)
    # rubocop:disable Metrics/ParameterLists, Metrics/CyclomaticComplexity
    def initialize(id, name, subgraphs, initial_subgraph_id, global_configuration = nil,
                   constants = {}, owner_id = nil, repeat = false)
      # rubocop:enable Metrics/ParameterLists, Metrics/CyclomaticComplexity

      @id = id || SecureRandom.uuid
      @name = name
      @owner_id = owner_id
      @repeat = repeat

      @subgraphs = subgraphs
      @initial_subgraph_id = initial_subgraph_id
      @initial_command = @subgraphs[@initial_subgraph_id]
      @current_command = @initial_command

      @node_lookup = {}
      @subgraphs.each_value do |first_command|
        current = first_command
        while current
          @node_lookup[current.id] = current
          current = current.next_command
        end
      end

      @variables = {}
      @initial_variables = {}
      @constants = constants

      # Store constants under the 'graph' namespace
      constants.each do |key, value|
        @variables["graph.#{key}"] = value
        @initial_variables["graph.#{key}"] = value
      end

      # Store global configuration values in 'global' namespace
      global_configuration&.command_visible_configs&.each do |key, value|
        @variables["global.#{key}"] = value
        @initial_variables["global.#{key}"] = value
      end
    end

    # Look up a node by ID, if subgraph ID is used instead will return first node in graph
    # @param node_id [String] The ID of the node or subgraph to find
    # @return [Command] The command node, or first node of subgraph if node_id is a subgraph ID
    def find_node_by_id(node_id)
      return @node_lookup[node_id] if @node_lookup.key?(node_id)
      return @subgraphs[node_id] if @subgraphs.key?(node_id)

      # Not found
      nil
    end

    # Begins executing the command by starting the monitor specified in
    # the data source - will return immediately
    def execute(graph_executor)
      @graph_executor = graph_executor
      @cancelled = false
      @thread = Thread.new do
        if Thread.current != Thread.main
          log_info("Beginning thread for graph #{id} - will be repeated: #{@repeat}")
          loop do
            # If we are repeatable, then repeat if we are at the end
            if @current_command.nil? && @repeat
              log_info("Repeating command graph #{name} with id #{id}")
              @current_command = @initial_command
              @variables = @initial_variables.dup
            end

            break if @current_command.nil? || @cancelled

            log_info("Executing command: #{@current_command.id}")
            log_debug("Current Variables: #{@variables}")
            next_command = @current_command.execute(substitute_variables(@current_command.inputs, @variables), @current_command.next_command, self)
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

    def add_variables(additional_initial_variables = {}, additional_variables = {})
      @initial_variables.merge!(additional_initial_variables)
      @variables.merge!(additional_variables)
    end

    # Creates a forked copy of this command graph with inherited state
    # @param fork_variables [Hash] Optional variables to set in the forked graph
    # @param start_subgraph_id [String] Optional subgraph to start execution with (defaults to initial_subgraph_id)
    # @return [CommandGraph] A new command graph instance with inherited state
    def fork(fork_variables = {}, start_subgraph_id = nil)
      # Create a new graph with the same structure but fresh state
      forked_graph = self.class.new(
        SecureRandom.uuid, # New unique ID for the fork
        "#{@name} (fork)",
        @subgraphs,
        start_subgraph_id || @initial_subgraph_id,
        nil, # global_configuration will be inherited through variables
        @constants,
        @owner_id,
        @repeat
      )

      forked_graph.add_variables(@initial_variables, @variables)
      forked_graph.add_variables(fork_variables, fork_variables)
      forked_graph
    end

    # Forks this graph and executes it in current executor
    # @param fork_variables [Hash] Optional variables to set in the forked graph's scope
    # @param start_subgraph_id [String] Optional subgraph to start execution with
    # @return [Thread] The thread executing the forked graph
    def fork_and_execute(fork_variables = {}, start_subgraph_id = nil)
      forked_graph = fork(fork_variables, start_subgraph_id)
      @graph_executor.add_command_graph(forked_graph)
    end

    protected :substitute_variables, :add_variables
  end

  # Exception generated during loading or execution of command
  class CommandGraphException < StandardError
  end
end
