require 'daf/input'
require 'net/http'
require 'uri'
require 'nokogiri'

module DAF
  # An input node that gets text from a webpage
  class WebInput < Input
    attr_option 'uri', String, :required do |val|
      parsed_uri = URI.parse(val)
      parsed_uri && %w[http https].include?(parsed_uri.scheme)
    end
    attr_option 'timeout', Integer do |val|
      val > 0
    end
    attr_option 'user_agent', String

    attr_output 'content', String

    MAX_RESPONSE_SIZE = 10 * 1024 * 1024 # 10MB
    MAX_REDIRECTS = 5

    protected

    def invoke
      parsed_uri = URI.parse(uri.value)
      @content = fetch_webpage_contents(parsed_uri)
    end

    private

    def validate_response_and_check_redirect(request_uri, response)
      if response.is_a?(Net::HTTPRedirection)
        location = response['location']
        raise WebInputError, 'Redirect without location' unless location

        return URI.join(request_uri, location)
      end

      raise WebInputError, "HTTP #{response.code}: #{response.message}" unless response.is_a?(Net::HTTPSuccess)

      content_length = response['content-length']
      raise WebInputError, 'Response too large' if content_length && content_length.to_i > MAX_RESPONSE_SIZE

      nil
    end

    def fetch_webpage_contents(request_uri)
      request_timeout = timeout.value || 30
      request_user_agent = user_agent.value || 'DAF WebInput/1.0'
      retry_count = 0
      response = nil
      loop do
        response = perform_http_request(request_uri, request_timeout, request_user_agent)
        request_uri = validate_response_and_check_redirect(request_uri, response)
        break if request_uri.nil?

        retry_count += 1
        raise WebInputError, 'Maximum redirects exceeded' unless retry_count <= MAX_REDIRECTS
      end
      extract_text_content(response.body)
    end

    def perform_http_request(request_uri, request_timeout, request_user_agent)
      Net::HTTP.start(request_uri.host, request_uri.port,
                      use_ssl: request_uri.scheme == 'https',
                      read_timeout: request_timeout,
                      open_timeout: request_timeout) do |http|
        request = Net::HTTP::Get.new(request_uri)
        request['User-Agent'] = request_user_agent
        http.request(request)
      end
    end

    def extract_text_content(html)
      doc = Nokogiri::HTML(html)
      doc.search('script, style').remove
      doc.text.gsub(/\s+/, ' ').strip
    end
  end

  class WebInputError < StandardError
  end
end
