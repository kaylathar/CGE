# frozen_string_literal: true

require 'cge/monitor'
require 'skyfall'
require 'tempfile'

module CGE
  # Monitor that listens for messages on the ATProto firehose stream using skyfall
  class AtProtoMonitor < Monitor
    # The ATProto handle/identifier (optional for firehose, required for timeline)
    attr_input :handle, String do |val|
      !val.empty? && val.match?(/\A[a-zA-Z0-9.-]+\z/)
    end

    # The ATProto app password (optional for firehose, required for timeline)
    attr_input :password, String do |val|
      !val.empty?
    end

    # The text to search for in posts
    attr_input :search_text, String, :required do |val|
      !val.empty?
    end

    # ATProto PDS host (default: bsky.social)
    attr_input :pds_host, String do |val|
      val.nil? || !val.empty?
    end

    attr_output :author, String
    attr_output :content, String
    attr_output :uri, String
    attr_output :created_at, String

    def block_until_triggered
      @triggered = false
      @trigger_mutex = Mutex.new
      @trigger_condition = ConditionVariable.new

      Thread.new do
        setup_firehose_connection
      end
      # Block until triggered
      @trigger_mutex.synchronize do
        @trigger_condition.wait(@trigger_mutex) until @triggered
      end
    end

    private

    def setup_firehose_connection
      relay = pds_host.value || 'bsky.network'
      sky = Skyfall::Firehose.new(relay, :subscribe_repos)

      sky.on_message { |msg| process_firehose_message(msg) }
      sky.connect
    end

    def process_firehose_message(msg)
      return unless msg.type == :commit

      msg.operations.each do |operation|
        next unless operation.action == :create &&
                    operation.type == :bsky_post &&
                    operation.raw_record['text']&.include?(search_text.value)

        handle_post_match(operation)
        break
      end
    end

    def handle_post_match(operation)
      @trigger_mutex.synchronize do
        return if @triggered

        @author = operation.repo
        @content = operation.raw_record['text']
        @uri = operation.uri
        @created_at = operation.raw_record['createdAt']

        @triggered = true
        @trigger_condition.signal
      end
    end
  end
end

CGE::Command.register_command(CGE::AtProtoMonitor)
