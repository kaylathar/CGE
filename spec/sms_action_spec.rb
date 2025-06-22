require 'spec_helper'

describe CGE::SMSAction do
  let(:valid_inputs) do
    {
      'to' => '+1234567890',
      'message' => 'Test SMS message',
      'from' => '+0987654321',
      'sid' => 'test_account_sid',
      'token' => 'test_auth_token'
    }
  end
  let(:action) { CGE::SMSAction.new('sms_action_id', 'sms_action', {}, nil) }
  let(:mock_messages) { double('Twilio::REST::Api::V2010::AccountContext::MessageList') }
  let(:mock_client) { double('Twilio::REST::Client') }

  context 'with mocked twilio operations' do
    before do
      @test_id = "1234"
      allow(Twilio::REST::Client).to receive(:new).and_return(mock_client)
      allow(mock_client).to receive(:messages).and_return(mock_messages)
      allow(mock_messages).to receive(:create).and_return(@test_id)
    end
  end

  context 'when new action is created' do
    it 'should require a to input' do
      expect(CGE::SMSAction.required_inputs).to include('to')
    end

    it 'should require a message input' do
      expect(CGE::SMSAction.required_inputs).to include('message')
    end

    it 'should require a from input' do
      expect(CGE::SMSAction.required_inputs).to include('from')
    end

    it 'should require a sid input' do
      expect(CGE::SMSAction.required_inputs).to include('sid')
    end

    it 'should require a token input' do
      expect(CGE::SMSAction.required_inputs).to include('token')
    end

    it 'should accept valid inputs' do
      mock_client = double('Twilio::REST::Client')
      mock_messages = double('Messages')
      allow(Twilio::REST::Client).to receive(:new).and_return(mock_client)
      allow(mock_client).to receive(:messages).and_return(mock_messages)
      allow(mock_messages).to receive(:create).and_return('SM123')
      
      expect { action.execute(valid_inputs, nil) }.not_to raise_error
    end

    it 'should raise error when to is missing' do
      invalid_inputs = valid_inputs.dup
      invalid_inputs.delete('to')
      expect { action.execute(invalid_inputs, nil) }.to raise_error
    end

    it 'should raise error when message is missing' do
      invalid_inputs = valid_inputs.dup
      invalid_inputs.delete('message')
      expect { action.execute(invalid_inputs, nil) }.to raise_error
    end

    it 'should raise error when from is missing' do
      invalid_inputs = valid_inputs.dup
      invalid_inputs.delete('from')
      expect { action.execute(invalid_inputs, nil) }.to raise_error
    end

    it 'should raise error when sid is missing' do
      invalid_inputs = valid_inputs.dup
      invalid_inputs.delete('sid')
      expect { action.execute(invalid_inputs, nil) }.to raise_error
    end

    it 'should raise error when token is missing' do
      invalid_inputs = valid_inputs.dup
      invalid_inputs.delete('token')
      expect { action.execute(invalid_inputs, nil) }.to raise_error
    end
  end

  context 'when activated is called' do
    let(:mock_client) { double('Twilio::REST::Client') }
    let(:mock_messages) { double('Messages') }
    let(:mock_message_id) { 'SM1234567890abcdef' }

    before do
      action.send(:process_inputs, valid_inputs)
      allow(Twilio::REST::Client).to receive(:new).and_return(mock_client)
      allow(mock_client).to receive(:messages).and_return(mock_messages)
      allow(mock_messages).to receive(:create).and_return(mock_message_id)
    end

    it 'should call create on client.messages' do
      expect(mock_messages).to receive(:create)
      action.execute(valid_inputs, nil)
    end

    it 'should pass correct parameters to messages.create' do
      expected_params = {
        body: 'Test SMS message',
        to: '+1234567890',
        from: '+0987654321'
      }

      expect(mock_messages).to receive(:create).with(expected_params)
      action.execute(valid_inputs, nil)
    end

    it 'should set message_id output attribute' do
      action.execute(valid_inputs, nil)
      expect(action.message_id).to eq(mock_message_id)
    end

    context 'when SMS send succeeds' do
      before do
        allow(mock_messages).to receive(:create).and_return('SM_success_id')
      end

      it 'should set the returned message ID' do
        action.execute(valid_inputs, nil)
        expect(action.message_id).to eq('SM_success_id')
      end

      it 'should complete without error' do
        expect { action.execute(valid_inputs, nil) }.not_to raise_error
      end
    end

    context 'when SMS send fails' do
      before do
        allow(mock_messages).to receive(:create).and_raise(StandardError, 'Twilio API Error')
      end

      it 'should propagate the error' do
        expect { action.execute(valid_inputs, nil) }.to raise_error(StandardError, 'Twilio API Error')
      end
    end
  end
end
