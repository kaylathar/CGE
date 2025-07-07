# frozen_string_literal: true

require 'cge/action'
require 'minisky'
require 'tempfile'

module CGE
  # Action that sends a post to ATProto (e.g., Bluesky) using the minisky gem
  class AtProtoAction < Action
    # The ATProto handle/identifier
    attr_input :handle, String, :required do |val|
      !val.empty? && val.match?(/\A[a-zA-Z0-9.-]+\z/)
    end

    # The ATProto app password
    attr_input :password, String, :required do |val|
      !val.empty?
    end

    # The text content to post
    attr_input :text, String, :required do |val|
      !val.empty? && val.length <= 300
    end

    # ATProto PDS host (default: bsky.social)
    attr_input :pds_host, String do |val|
      val.nil? || !val.empty?
    end

    def invoke
      host = pds_host.value || 'bsky.social'
      # Create temporary config file for minisky
      config_file = create_temp_config

      begin
        # Initialize minisky client
        bsky = Minisky.new(host, config_file.path)

        # Create the post
        create_post(bsky)
      ensure
        # Clean up temporary file
        config_file.close
        config_file.unlink
      end
    end

    private

    def create_temp_config
      config_file = Tempfile.new(['atproto_config', '.yml'])
      config_file.chmod(0o600) # Owner read/write only
      config_file.write("id: #{handle.value}\npass: #{password.value}\n")
      config_file.close
      config_file
    end

    def create_post(bsky)
      post_record = {
        text: text.value,
        createdAt: Time.now.utc.iso8601,
        langs: ['en']
      }

      data = {
        repo: bsky.user.did,
        collection: 'app.bsky.feed.post',
        record: post_record
      }
      bsky.post_request('com.atproto.repo.createRecord', data)
    end
  end
end

CGE::Command.register_command(CGE::AtProtoAction)
