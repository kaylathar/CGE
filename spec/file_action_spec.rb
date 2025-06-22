require 'spec_helper'

describe CGE::FileAction do
  before(:each) do
    @options = { 'path' => '/tmp/test_file.txt',
                 'content' => 'Test content' }
    @action = CGE::FileAction.new("test_action", {})
  end

  context 'options' do
    it 'has a path option of type String' do
      expect(@action.class.options['path']).to eq(String)
    end

    it 'has a content option of type String' do
      expect(@action.class.options['content']).to eq(String)
    end

    it 'has an optional create_directories option of type Object' do
      expect(@action.class.options['create_directories']).to eq(Object)
    end
  end

  context 'when execute is called' do
    it 'writes content to the specified file' do
      expect(File).to receive(:write).with('/tmp/test_file.txt', 'Test content')
      @action.execute(@options, nil)
    end

    it 'creates directories when create_directories is true' do
      @options['create_directories'] = true
      @options['path'] = '/tmp/nested/dir/test_file.txt'

      expect(FileUtils).to receive(:mkdir_p).with('/tmp/nested/dir')
      expect(File).to receive(:write).with('/tmp/nested/dir/test_file.txt', 'Test content')

      @action.execute(@options, nil)
    end

    it 'does not create directories when create_directories is false' do
      @options['create_directories'] = false

      expect(FileUtils).not_to receive(:mkdir_p)
      expect(File).to receive(:write).with('/tmp/test_file.txt', 'Test content')

      @action.execute(@options, nil)
    end

    it 'handles file write errors gracefully' do
      allow(File).to receive(:write).and_raise(StandardError.new('Permission denied'))
      expect { @action.execute(@options, nil) }.to raise_error(CGE::FileActionError)
    end
  end
end
