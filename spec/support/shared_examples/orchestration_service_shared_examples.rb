# frozen_string_literal: true

RSpec.shared_examples 'utility methods' do
  describe '#peek_message' do
    it 'returns next message without removing it' do
      role = 'peek_role'
      service.send_message(role, 'peek_test')

      expect(service.peek_message(role)).to eq('peek_test')
      expect(service.peek_message(role)).to eq('peek_test')
      expect(service.block_for_message(role)).to eq('peek_test')
      expect(service.peek_message(role)).to be_nil
    end
  end

  describe '#messages?' do
    it 'correctly reports message availability' do
      role = 'check_role'

      expect(service.messages?(role)).to be false
      service.send_message(role, 'test')
      expect(service.messages?(role)).to be true
      service.block_for_message(role)
      expect(service.messages?(role)).to be false
    end
  end

  describe '#clear_messages' do
    it 'removes all messages for a role' do
      role = 'clear_role'

      service.send_message(role, 'msg1')
      service.send_message(role, 'msg2')

      expect(service.clear_messages(role)).to eq(2)
      expect(service.messages?(role)).to be false
    end
  end

  describe '#get_queue_size' do
    it 'returns correct queue size' do
      role = 'size_role'

      expect(service.get_queue_size(role)).to eq(0)
      service.send_message(role, 'msg1')
      expect(service.get_queue_size(role)).to eq(1)
      service.send_message(role, 'msg2')
      expect(service.get_queue_size(role)).to eq(2)
      service.block_for_message(role)
      expect(service.get_queue_size(role)).to eq(1)
    end
  end

  describe '#list_roles' do
    it 'returns all roles with messages' do
      service.send_message('role1', 'msg')
      service.send_message('role2', 'msg')

      expect(service.list_roles).to contain_exactly('role1', 'role2')
    end
  end
end
