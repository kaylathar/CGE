require 'daf/configurable'

module DAF
  # Stores information from an input source into the command graph
  class Input
    include Configurable

    # Asks this node to process its input and insert it into the graph data
    #
    # @param options [Hash] A hash of options with name/value pairs, must
    # match types expected for each option or will raise an exception
    def process(options)
      process_options(options)
      invoke
    end
  end
end
