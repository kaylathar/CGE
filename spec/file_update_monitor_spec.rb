require 'spec_helper'

describe 'DAF::FileUpdateMonitor' do
  context 'when on_trigger is called' do
    it 'should validate that the path exists' do
      allow(File).to receive(:exist?).and_return(false)
      options = { 'frequency' => 2, 'path' => '/asdf/' }
      monitor = DAF::FileUpdateMonitor.new('monitor', {})

      allow(monitor).to receive(:sleep).and_return(true)
      expect { monitor.execute(options, nil) }.to raise_error(DAF::OptionError)
    end

    it 'should validate that the frequency is > 1' do
      allow(File).to receive(:exist?).and_return(true)
      options = { 'frequency' => -1, 'path' => '/asdf' }
      monitor = DAF::FileUpdateMonitor.new('monitor', {})

      allow(monitor).to receive(:sleep).and_return(true)
      expect { monitor.execute(options, nil) }.to raise_error(DAF::OptionError)
    end

    it 'should have a required option named path' do
      expect(DAF::FileUpdateMonitor.required_options).to include('path')
    end

    it 'should have a required option named frequency' do
      expect(DAF::FileUpdateMonitor.required_options).to include('frequency')
    end
  end

  context 'when on_trigger is called' do
    before(:each) do
      @options = { 'frequency' => 2, 'path' => '/asdfasdfasdf' }
      @file = double('File')
      @time = 0
      allow(File).to receive(:mtime) do
        current_time = @time
        @time += 1
        current_time
      end
      allow(File).to receive(:exist?).and_return(true)
      allow(File).to receive(:open).and_return(@file)
      allow(@file).to receive(:read).and_return('contents')
      allow(@file).to receive(:close)
      @monitor = DAF::FileUpdateMonitor.new('monitor', {})
    end

    it 'should sleep the set frequency' do
      expect(@monitor).to receive(:sleep).with(2)
      @monitor.execute(@options, nil)
    end

    it 'should record current time' do
      expect(File).to receive(:mtime).twice
      allow(@monitor).to receive(:sleep)
      @monitor.execute(@options, nil)
    end

    it 'should skip loop unless file modify time changes' do
      expect(@monitor).to receive(:sleep).with(2).exactly(3).times
      @mtime = 0
      allow(File).to receive(:mtime) do
        @mtime += 1
        if @mtime < 4
          0
        else
          1
        end
      end
      @monitor.execute(@options, nil)
    end

    context 'when file is modified' do
      it 'should record the time as output' do
        allow(@monitor).to receive(:sleep)
        @monitor.execute(@options, nil)
        expect(@monitor.time).to eq(1)
      end

      it 'should record the contents of the file as output' do
        allow(@monitor).to receive(:sleep)
        @monitor.execute(@options, nil)
        expect(@monitor.contents).to eq('contents')
      end
    end
  end
end
