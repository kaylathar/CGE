require 'spec_helper'

describe 'DAF::FileUpdateMonitor' do
  context 'when new monitor is created' do
    it 'should validate that the path exists' do
      options = { 'frequency' => 2, 'path' => '/tmp/fake' }
      expect { FileUpdateMonitor.new(options) }.to raise_error
    end

    it 'should validate that the frequency is > 1' do
      options = { 'frequency' => 0, 'path' => '/' }
      expect { FileUpdateMonitor.new(options) }.to raise_error
    end

    it 'should have a required option named path' do
      expect(FileUpdateMonitor.required_options).to include('path')
    end

    it 'should have a required option named frequency' do
      expect(FileUpdateMonitor.required_options).to include('frequency')
    end
  end

  context 'when block_until_triggered is called' do
    let(:monitor) do
      options = { 'frequency' => 2, 'path' => '/' }
      FileUpdateMonitor.new(options)
    end

    let!(:file) do
      dup = class_double('File').as_stubbed_const(
        transfer_nested_constants: true)
      @time = 0
      allow(dup).to receive(:mtime) do
        @time += 1
      end
      allow(dup).to receive(:exist?).and_return(true)
      allow(dup).to receive(:open).and_return(ifile)
      dup
    end

    let(:ifile) do
      dup = double('File')
      allow(dup).to receive(:read).and_return('contents')
      allow(dup).to receive(:close)
      dup
    end

    it 'should sleep the set frequency' do
      expect(monitor).to receive(:sleep).with(2)
      monitor.block_until_triggered
    end

    it 'should record current time' do
      expect(file).to receive(:mtime).twice
      monitor.block_until_triggered
    end

    it 'should skip loop unless file modify time changes' do
      expect(monitor).to receive(:sleep).with(2).exactly(3).times
      @mtime = 0
      allow(file).to receive(:mtime) do
        @mtime += 1
        if @mtime < 4
          0
        else
          1
        end
      end
      monitor.block_until_triggered
    end

    context 'when file is modified' do
      it 'should record the time as output' do
        monitor.block_until_triggered
        expect(monitor.time).to eq(2)
      end

      it 'should record the contents of the file as output' do
        monitor.block_until_triggered
        expect(monitor.contents).to eq('contents')
      end
    end
  end
end
