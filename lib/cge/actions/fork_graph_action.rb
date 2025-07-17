# frozen_string_literal: true

require 'cge/action'
require 'cge/logging'

module CGE
  # An action that forks the current command graph
  class ForkGraphAction < Action
    include Logging

    attr_input :subgraph_id, String, :optional do |val|
      !val.empty?
    end
    attr_input :variables, Hash, :optional

    def invoke
      command_graph.fork_and_execute(
        variables&.value || {},
        subgraph_id&.value
      )
      log_info('Forked graph')
    end
  end
end

CGE::Command.register_command(CGE::ForkGraphAction)
