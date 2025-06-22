require 'spec_helper'

describe CGE::EmailAction do
  before(:each) do
    @server = 'mail.example.com'
    @inputs = { 'from' => 'test@example.com',
                 'to' => 'test_to@example.com',
                 'subject' => 'Test Subject',
                 'body' => 'Test Body',
                 'server' => @server }
    @action = CGE::EmailAction.new("test_action", {})
  end

  it 'has five required inputs' do
    expect { @action.class.required_inputs }.not_to raise_error
    expect(@action.class.required_inputs.length).to eq(5)
  end

  it 'has six inputs' do
    expect { @action.class.inputs }.not_to raise_error
    expect(@action.class.inputs.length).to eq(6)
  end

  it 'has a port input of type Integer' do
    expect(@action.class.inputs['port']).to eq(Integer)
  end

  context 'when execute is called' do
    before(:each) do
      @smtp_obj = double(Net::SMTP.new('mail.example.com'))
      @smtp = class_double('Net::SMTP')
              .as_stubbed_const(transfer_nested_constants: true)
    end

    it 'sends with the server and port passed in' do
      @inputs['port'] = 333
      expect(@smtp).to receive(:start).with(@server, 333)
      @action.execute(@inputs, nil)
    end

    it 'should use a default port if none is specified' do
      expect(@smtp).to receive(:start).with(@server, 25)
      @action.execute(@inputs, nil)
    end

    it 'should send a message' do
      target_message = <<END
  From: test@example.com
  To: test_to@example.com
  Subject: Test Subject

  Test Body
END
      allow(@smtp).to receive(:start).and_yield(@smtp_obj)
      expect(@smtp_obj).to receive(:send_message).with(
        target_message, 'test@example.com', 'test_to@example.com'
      )
      @action.execute(@inputs, nil)
    end
  end
end
