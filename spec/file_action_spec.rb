require 'spec_helper'

describe DAF::FileAction do
  before(:each) do
    @options = { 'path' => '/tmp/test_file.txt',
                 'content' => 'Test content' }
    @action = DAF::FileAction.new
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

  context 'when activate is called' do
    it 'writes content to the specified file' do
      expect(File).to receive(:write).with('/tmp/test_file.txt', 'Test content')
      @action.activate(@options)
    end

    it 'creates directories when create_directories is true' do
      @options['create_directories'] = true
      @options['path'] = '/tmp/nested/dir/test_file.txt'

      expect(FileUtils).to receive(:mkdir_p).with('/tmp/nested/dir')
      expect(File).to receive(:write).with('/tmp/nested/dir/test_file.txt', 'Test content')

      @action.activate(@options)
    end

    it 'does not create directories when create_directories is false' do
      @options['create_directories'] = false

      expect(FileUtils).not_to receive(:mkdir_p)
      expect(File).to receive(:write).with('/tmp/test_file.txt', 'Test content')

      @action.activate(@options)
    end

    it 'handles file write errors gracefully' do
      allow(File).to receive(:write).and_raise(StandardError.new('Permission denied'))
      expect { @action.activate(@options) }.to raise_error(DAF::FileActionError)
    end
  end
end
