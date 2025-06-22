require 'spec_helper'
require 'tempfile'

describe CGE::FileInput do
  let(:file_input) { CGE::FileInput.new('file_input_id', 'file_input', {}, nil) }
  let(:temp_file) { Tempfile.new('test_file') }
  let(:test_content) { 'Hello, World!' }
  let(:inputs) { { 'file_path' => temp_file.path } }

  before do
    temp_file.write(test_content)
    temp_file.close
  end

  after do
    temp_file.unlink
  end

  it 'should read file content correctly' do
    file_input.execute(inputs, nil)
    expect(file_input.content).to eq(test_content)
  end

  it 'should raise error when file_path is not provided' do
    expect { file_input.execute({}, nil) }
      .to raise_error(CGE::InputError)
  end

  it 'should raise error when file_path is empty' do
    expect { file_input.execute({ 'file_path' => '' }, nil) }
      .to raise_error(CGE::InputError)
  end

  it 'should raise error when file does not exist' do
    expect { file_input.execute({ 'file_path' => '/nonexistent/file.txt' }, nil) }
      .to raise_error(CGE::InputError)
  end

  it 'should raise error when path is a directory' do
    Dir.mktmpdir do |dir|
      expect { file_input.execute({ 'file_path' => dir }, nil) }
      .to raise_error(CGE::InputError)
    end
  end

  it 'should raise error when file is not readable' do
    File.chmod(0o000, temp_file.path)
    expect { file_input.execute(inputs, nil) }
      .to raise_error(CGE::InputError)
  ensure
    File.chmod(0o644, temp_file.path)
  end

  it 'should handle large files' do
    large_content = 'A' * 10000
    large_file = Tempfile.new('large_test_file')
    large_file.write(large_content)
    large_file.close

    file_input.execute({ 'file_path' => large_file.path }, nil)
    expect(file_input.content).to eq(large_content)

    large_file.unlink
  end

  it 'should handle binary files' do
    binary_content = "\x00\x01\x02\xFF"
    binary_file = Tempfile.new('binary_test_file', binmode: true)
    binary_file.write(binary_content)
    binary_file.close

    file_input.execute({ 'file_path' => binary_file.path }, nil)
    expect(file_input.content).to eq(binary_content)

    binary_file.unlink
  end

  it 'should handle empty files' do
    empty_file = Tempfile.new('empty_test_file')
    empty_file.close

    file_input.execute({ 'file_path' => empty_file.path }, nil)
    expect(file_input.content).to eq('')

    empty_file.unlink
  end
end