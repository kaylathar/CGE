require 'spec_helper'

describe CGE::FileAction do
  before(:each) do
    @inputs = { 'path' => '/tmp/test_file.txt',
                 'content' => 'Test content' }
    @action = CGE::FileAction.new('file_action_id', "test_action", {}, nil)
  end

  context 'inputs' do
    it 'has a path input of type String' do
      expect(@action.class.inputs['path']).to eq(String)
    end

    it 'has a content input of type String' do
      expect(@action.class.inputs['content']).to eq(String)
    end

    it 'has an optional create_directories input of type Object' do
      expect(@action.class.inputs['create_directories']).to eq(Object)
    end
  end

  context 'when execute is called' do
    it 'writes content to the specified file' do
      expect(File).to receive(:write).with('/tmp/test_file.txt', 'Test content')
      @action.execute(@inputs, nil)
    end

    it 'creates directories when create_directories is true' do
      @inputs['create_directories'] = true
      @inputs['path'] = '/tmp/nested/dir/test_file.txt'

      expect(FileUtils).to receive(:mkdir_p).with('/tmp/nested/dir')
      expect(File).to receive(:write).with('/tmp/nested/dir/test_file.txt', 'Test content')

      @action.execute(@inputs, nil)
    end

    it 'does not create directories when create_directories is false' do
      @inputs['create_directories'] = false

      expect(FileUtils).not_to receive(:mkdir_p)
      expect(File).to receive(:write).with('/tmp/test_file.txt', 'Test content')

      @action.execute(@inputs, nil)
    end

    it 'handles file write errors gracefully' do
      allow(File).to receive(:write).and_raise(StandardError.new('Permission denied'))
      expect { @action.execute(@inputs, nil) }.to raise_error(CGE::FileActionError)
    end
  end
end
