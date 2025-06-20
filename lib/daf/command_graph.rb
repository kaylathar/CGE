require 'thread'
Dir["#{File.dirname(__FILE__)}/monitors/*"].sort.each { |file| require file }
Dir["#{File.dirname(__FILE__)}/actions/*"].sort.each { |file| require file }
Dir["#{File.dirname(__FILE__)}/inputs/*"].sort.each { |file| require file }

module DAF
  # Represents a graph of Monitor and Action objects
  # when requested, will begin watching the Monitor
  # and when it triggers will invoke the action by
  # default Command continues monitoring forever
  # though subclasses may override this behavior
  class CommandGraph
    # Create a new command object from a data source
    # @param graph_node [CommandGraphNode] The first node of the command graph
    # @param global_configuration [GlobalConfiguration] Optional global configuration instance
    # @param constants [Hash] Optional hash of graph-level constants
    def initialize(graph_node, global_configuration = nil, constants = {})
      @current_node = graph_node
      @global_configuration = global_configuration
      @outputs = {}

      # Store constants under the 'graph' namespace
      constants.each do |key, value|
        @outputs["graph.#{key}"] = value
      end

      return unless global_configuration

      global_configuration.outputs.each_key do |output_name|
        output_value = global_configuration.send(output_name)
        @outputs["global.#{output_name}"] = output_value unless output_value.nil?
      end
    end

    # Execute the provided monitor node
    def execute_monitor_node(_node)
      @current_node.underlying.on_trigger(apply_outputs(@current_node.options, @outputs)) do
        @current_node.underlying.class.outputs.each_key do |output_name|
          output_value = @current_node.underlying.send(output_name)
          @outputs["#{@current_node.name}.#{output_name}"] = output_value
        end
      end
    end

    # Execute the provided action node
    def execute_action_node(_node)
      @current_node.underlying.activate(apply_outputs(@current_node.options, @outputs))

      # Store action outputs with node name prefix
      @current_node.underlying.class.outputs.each_key do |output_name|
        output_value = @current_node.underlying.send(output_name)
        @outputs["#{@current_node.name}.#{output_name}"] = output_value
      end
    end

    # Execute the provided input node
    def execute_input_node(_node)
      @current_node.underlying.process(apply_outputs(@current_node.options, @outputs))
      @current_node.underlying.class.outputs.each_key do |output_name|
        output_value = @current_node.underlying.send(output_name)
        @outputs["#{@current_node.name}.#{output_name}"] = output_value
      end
    end

    # Begins executing the command by starting the monitor specified in
    # the data source - will return immediately
    def execute
      @thread = Thread.new do
        if Thread.current != Thread.main
          loop do
            break if @current_node.nil?

            case @current_node.type
            when :monitor
              execute_monitor_node(@current_node)
            when :action
              execute_action_node(@current_node)
            when :input
              execute_input_node(@current_node)
            end
            @current_node = @current_node.next
          end
        end
      end
    end

    # Apply in place subsitutions over a set of input options using a set
    # of output options and global configuration
    # @param input_options [Hash] The set of inputs that should have values substituted in
    # @param outputs [Hash] The set of outputs in key/value format that are used for subs
    def apply_outputs(input_options, outputs)
      options = input_options.clone
      # Apply node output substitutions
      outputs.each do |output_name, output_value|
        options.each do |option_key, option_value|
          if option_value.is_a?(String)
            options[option_key] =
              option_value.gsub("{{#{output_name}}}", output_value.to_s)
          end
        end
      end
      options
    end

    # Immediately cancels command graph execution
    def cancel
      @thread.kill
    end

    protected :apply_outputs, :execute_action_node, :execute_monitor_node, :execute_input_node
  end

  # Exception generated during loading or execution of command
  class CommandGraphException < StandardError
  end

  # Represents a node in the command graph
  class CommandGraphNode
    # Creates a new CommandGraphNode
    #
    # @param underlying [Configurable] The underlying object the node encapsulates
    # @param type [Symbol] Denotes the type of node - :monitor, :action, or :input
    # @param next_node [CommandGraphNode] May be nil - represents the next node to be processed, if any
    # @param options [Hash] Options to be populated to this node, or nil if none
    # @param name [String] Unique name for this node
    def initialize(underlying: nil, name: nil, type: nil, next_node: nil, options: nil)
      @type = type
      @next = next_node
      @underlying = underlying
      @options = options
      @name = name
    end
    attr_reader :type, :next, :underlying, :options, :name
  end
end
