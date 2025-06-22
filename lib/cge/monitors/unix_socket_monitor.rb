require 'cge/monitor'
require 'socket'

module CGE
  # Monitor that watches a Unix domain socket for incoming connections/data
  class UnixSocketMonitor < Monitor
    attr_option :socket_path, String, :required do |val|
      !val.empty?
    end

    # @return [String] The data received from the socket
    attr_output :data, String

    def block_until_triggered
      server = UNIXServer.new(@socket_path.value)

      begin
        # Wait for a connection
        client = server.accept

        # Read data from the client
        @data = client.read

        client.close
      ensure
        server.close
        # Clean up the socket file
        File.unlink(@socket_path.value)
      end
    end
  end
end
