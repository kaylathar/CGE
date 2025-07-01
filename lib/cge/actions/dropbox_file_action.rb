require 'cge/action'
require 'net/http'
require 'uri'
require 'json'

module CGE
  # An action that writes to a Dropbox file
  class DropboxFileAction < Action
    attr_input :access_token, String, :required
    attr_input :file_path, String, :required
    attr_input :content, String, :required
    attr_input :overwrite, Object

    def request_body(uri)
      request = Net::HTTP::Post.new(uri)
      request['Authorization'] = "Bearer #{@access_token.value}"
      request['Content-Type'] = 'application/octet-stream'
      request['Dropbox-API-Arg'] = {
        path: @file_path.value,
        mode: !@overwrite.nil? && @overwrite.value ? 'overwrite' : 'add',
        autorename: !@overwrite
      }.to_json
      request
    end

    def invoke
      uri = URI('https://content.dropboxapi.com/2/files/upload')

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = request_body(uri)
      request.body = @content.value
      response = http.request(request)

      raise DropboxFileActionError, "Failed to upload to Dropbox: #{response.code} - #{response.body}" unless response.code == '200'
    rescue StandardError => e
      raise DropboxFileActionError, "Failed to upload to Dropbox: #{e.message}"
    end

    private :request_body
  end

  class DropboxFileActionError < StandardError
  end
end

CGE::Command.register_command(CGE::DropboxFileAction)
