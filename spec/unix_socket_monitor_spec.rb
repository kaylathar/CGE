require 'spec_helper'
require 'socket'
require 'tempfile'

describe DAF::UnixSocketMonitor do
  let(:temp_socket_path) { "/tmp/test_socket_#{SecureRandom.hex(8)}" }
  let(:options) { { 'socket_path' => temp_socket_path } }
  let(:monitor) { DAF::UnixSocketMonitor.new }

  after do
    File.unlink(temp_socket_path) if File.exist?(temp_socket_path)
  end

  context 'monitor options' do
    it 'should require a socket_path option' do
      expect(DAF::UnixSocketMonitor.required_options).to include('socket_path')
    end

    it 'should validate socket_path is not empty' do
      invalid_options = { 'socket_path' => '' }
      expect { monitor.on_trigger(invalid_options) }.to raise_error(DAF::OptionError)
    end
  end

  context 'when on_trigger is called' do
    let(:mock_server) { double('UNIXServer') }
    let(:mock_client) { double('UNIXSocket') }
    let(:test_data) { 'test message from client' }

    context 'with mocked socket operations' do
      before do
        allow(UNIXServer).to receive(:new).with(temp_socket_path).and_return(mock_server)
        allow(mock_server).to receive(:accept).and_return(mock_client)
        allow(mock_server).to receive(:close)
        allow(mock_client).to receive(:read).and_return(test_data)
        allow(mock_client).to receive(:close)
        allow(File).to receive(:exist?).and_return(false)
        allow(File).to receive(:unlink)
      end

      it 'should create unix server with specified path' do
        expect(UNIXServer).to receive(:new).with(temp_socket_path)
        monitor.on_trigger(options)
      end

      it 'should accept client connections' do
        expect(mock_server).to receive(:accept).and_return(mock_client)
        monitor.on_trigger(options)
      end

      it 'should read data from client' do
        expect(mock_client).to receive(:read).and_return(test_data)
        monitor.on_trigger(options)
      end

      it 'should set data output attribute' do
        monitor.on_trigger(options)
        expect(monitor.data).to eq(test_data)
      end

      it 'should close client connection' do
        expect(mock_client).to receive(:close)
        monitor.on_trigger(options)
      end

      it 'should close server socket' do
        expect(mock_server).to receive(:close)
        monitor.on_trigger(options)
      end

      it 'should clean up socket file after completion' do
        allow(File).to receive(:exist?).with(temp_socket_path).and_return(true)
        expect(File).to receive(:unlink).with(temp_socket_path)
        monitor.on_trigger(options)
      end

      it 'should clean up socket file even if error occurs' do
        allow(mock_client).to receive(:read).and_raise(StandardError, 'test error')
        allow(File).to receive(:exist?).with(temp_socket_path).and_return(true)
        expect(File).to receive(:unlink).with(temp_socket_path)

        expect { monitor.on_trigger(options) }.to raise_error(StandardError, 'test error')
      end
    end
  end
end
