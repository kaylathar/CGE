# frozen_string_literal: true

require 'cge/action'
require 'net/http'
require 'json'
require 'uri'

module CGE
  # Action that performs HTTP requests for RESTful API operations
  class HttpAction < Action
    REQUEST_STRING_MAP = {
      'GET' => Net::HTTP::Get,
      'POST' => Net::HTTP::Post,
      'PUT' => Net::HTTP::Put,
      'DELETE' => Net::HTTP::Delete,
      'PATCH' => Net::HTTP::Patch,
      'HEAD' => Net::HTTP::Head,
      'OPTIONS' => Net::HTTP::Options
    }.freeze
    # The URL to make the request to
    attr_input :url, String, :required do |val|
      !val.empty? && (val.start_with?('http://') || val.start_with?('https://'))
    end

    # HTTP method (GET, POST, PUT, DELETE, PATCH)
    attr_input :method, String do |val|
      val.nil? || %w[GET POST PUT DELETE PATCH HEAD OPTIONS].include?(val.upcase)
    end

    # Request headers
    attr_input :headers, Hash

    # Request body (for POST, PUT, PATCH)
    attr_input :body, String

    # Content type (default: application/json)
    attr_input :content_type, String

    # Timeout in seconds (default: 30)
    attr_input :timeout, Integer do |val|
      val.nil? || val.positive?
    end

    # Whether to follow redirects (default: true)
    attr_input :follow_redirects, Object

    # @return [Integer] HTTP response status code
    attr_output :status_code, Integer

    # @return [String] Response body
    attr_output :response_body, String

    # @return [String] Response headers as JSON
    attr_output :response_headers, String

    # @return [Boolean] Whether the request was successful (2xx status)
    attr_output :success, Object

    def invoke
      uri = URI(url.value)
      client = http_client(uri)
      request = request(uri)

      response = client.request(request)
      @status_code = response.code.to_i
      @response_body = response.body || ''
      @response_headers = response.to_hash.to_json
      @success = @status_code >= 200 && @status_code < 300
    end

    private

    def http_client(uri)
      client = Net::HTTP.new(uri.host, uri.port)
      client.use_ssl = uri.scheme == 'https'

      timeout_value = timeout.valid? || 30
      client.open_timeout = timeout_value
      client.read_timeout = timeout_value

      client
    end

    def request(uri)
      request_class = request_class_for_method(method.value)
      request = request_class.new(uri)
      request['Content-Type'] = content_type.value || 'application/json'
      headers.value&.each do |key, value|
        request[key] = value
      end
      request.body = body.value unless body.value.nil?
      request
    end

    def request_class_for_method(http_method)
      return Net::HTTP::Get unless http_method

      REQUEST_STRING_MAP[http_method.upcase]
    end
  end
end

CGE::Command.register_command(CGE::HttpAction)
