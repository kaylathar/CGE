# frozen_string_literal: true

require 'cge/action'
require 'net/http'
require 'json'
require 'uri'
require 'base64'

module CGE
  # Action that posts to Reddit using the Reddit API
  class RedditPostAction < Action
    # Reddit client ID for OAuth
    attr_input :client_id, String, :required do |val|
      !val.empty?
    end

    # Reddit client secret for OAuth
    attr_input :client_secret, String, :required do |val|
      !val.empty?
    end

    # Reddit username
    attr_input :username, String, :required do |val|
      !val.empty?
    end

    # Reddit password
    attr_input :password, String, :required do |val|
      !val.empty?
    end

    # Subreddit to post to (without r/ prefix)
    attr_input :subreddit, String, :required do |val|
      !val.empty? && !val.start_with?('r/')
    end

    # Post title
    attr_input :title, String, :required do |val|
      !val.empty? && val.length <= 300
    end

    # Post text content
    attr_input :text, String, :required do |val|
      !val.empty?
    end

    def invoke
      access_token = authenticate
      create_post(access_token)
    end

    private

    def authenticate
      auth_string = Base64.strict_encode64("#{client_id.value}:#{client_secret.value}")

      uri = URI('https://www.reddit.com/api/v1/access_token')
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Post.new(uri)
      request['Authorization'] = "Basic #{auth_string}"
      request['User-Agent'] = 'CGE/1.0 (Command Graph Executor)'
      request.set_form_data({
                              'grant_type' => 'password',
                              'username' => username.value,
                              'password' => password.value
                            })

      response = http.request(request)
      raise "Reddit authentication failed: #{response.body}" unless response.code == '200'

      JSON.parse(response.body)['access_token']
    end

    def create_post(access_token)
      uri = URI('https://oauth.reddit.com/api/submit')
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Post.new(uri)
      request['Authorization'] = "Bearer #{access_token}"
      request['User-Agent'] = 'CGE/1.0 (Command Graph Executor)'

      post_data = {
        'api_type' => 'json',
        'kind' => 'self',
        'sr' => subreddit.value,
        'title' => title.value,
        'text' => text.value
      }

      request.set_form_data(post_data)

      response = http.request(request)
      raise RedditPostActionError, "Reddit post failed: #{response.body}" unless response.code == '200'

      result = JSON.parse(response.body)
      raise RedditPostActionError, "Reddit API error: #{result['json']['errors']}" if result['json']['errors']&.any?

      result
    end
  end

  class RedditPostActionError < StandardError
  end
end

CGE::Command.register_command(CGE::RedditPostAction)
