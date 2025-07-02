# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/cge/services/orchestration_service'
require_relative '../support/shared_examples/orchestration_service_shared_examples'

RSpec.describe CGE::OrchestrationService do
  let(:service) { CGE::OrchestrationService.new }

  before do
    service.start
  end

  after do
    service.stop
  end

  describe '#send_message and #block_for_message' do
    it 'delivers messages in FIFO order' do
      role = 'test_role'

      service.send_message(role, 'message1')
      service.send_message(role, 'message2')
      service.send_message(role, 'message3')

      expect(service.block_for_message(role)).to eq('message1')
      expect(service.block_for_message(role)).to eq('message2')
      expect(service.block_for_message(role)).to eq('message3')
    end

    it 'blocks until message is available' do
      role = 'blocking_role'
      received_message = nil
      start_time = Time.now

      thread = Thread.new do
        received_message = service.block_for_message(role)
      end

      sleep(0.1)
      expect(received_message).to be_nil

      service.send_message(role, 'delayed_message')
      thread.join

      expect(received_message).to eq('delayed_message')
      expect(Time.now - start_time).to be >= 0.1
    end
  end

  describe 'thread safety' do
    it 'handles concurrent senders and receivers safely' do
      role = 'concurrent_role'
      sent_messages = []
      received_messages = []
      num_messages = 10

      threads = create_concurrent_threads(role, num_messages, sent_messages, received_messages)
      threads.each(&:join)

      expect(received_messages.size).to eq(num_messages)
      expect(received_messages.sort).to eq(sent_messages.sort)
    end
  end

  def create_concurrent_threads(role, num_messages, sent_messages, received_messages)
    sender_threads = (1..num_messages).map do |i|
      Thread.new do
        message = "message_#{i}"
        sent_messages << message
        service.send_message(role, message)
      end
    end

    receiver_threads = (1..num_messages).map do
      Thread.new do
        received_messages << service.block_for_message(role)
      end
    end

    sender_threads + receiver_threads
  end

  it_behaves_like 'utility methods'
end
