module CGE
  # Storage system for persisting graphs
  class CommandGraphManager
    def initialize(storage_backend)
      @storage_backend = storage_backend
      @graph_cache = {}
    end

    def store(graph)
      @graph_cache[graph.id] = graph
      @storage_backend.create_or_update_graph(graph)
    end

    def get(graph_id)
      return @graph_cache[graph_id] if @graph_cache.key?(graph_id)

      graph = @storage_backend.fetch_graph_with_id(graph_id)
      @graph_cache[graph.id] = graph
    end

    def delete(graph_id)
      @graph_cache.delete(graph_id)
      @storage_backend.delete_graph(graph_id)
    end
  end
end
