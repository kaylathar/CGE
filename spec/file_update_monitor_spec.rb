require 'spec_helper'

describe 'CGE::FileUpdateMonitor' do
  context 'when on_trigger is called' do
    it 'should validate that the path exists' do
      allow(File).to receive(:exist?).and_return(false)
      inputs = { 'frequency' => 2, 'path' => '/asdf/' }
      monitor = CGE::FileUpdateMonitor.new('file_update_monitor_id', 'monitor', {}, nil)

      allow(monitor).to receive(:sleep).and_return(true)
      mock_graph = double('CommandGraph')
      expect { monitor.execute(inputs, nil, mock_graph) }.to raise_error(CGE::InputError)
    end

    it 'should validate that the frequency is > 1' do
      allow(File).to receive(:exist?).and_return(true)
      inputs = { 'frequency' => -1, 'path' => '/asdf' }
      monitor = CGE::FileUpdateMonitor.new('file_update_monitor_id2', 'monitor', {}, nil)

      allow(monitor).to receive(:sleep).and_return(true)
      mock_graph = double('CommandGraph')
      expect { monitor.execute(inputs, nil, mock_graph) }.to raise_error(CGE::InputError)
    end

    it 'should have a required input named path' do
      expect(CGE::FileUpdateMonitor.required_inputs).to include('path')
    end

    it 'should have a required input named frequency' do
      expect(CGE::FileUpdateMonitor.required_inputs).to include('frequency')
    end
  end

  context 'when on_trigger is called' do
    before(:each) do
      @inputs = { 'frequency' => 2, 'path' => '/asdfasdfasdf' }
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
      @monitor = CGE::FileUpdateMonitor.new('file_update_monitor_id3', 'monitor', {}, nil)
    end

    it 'should sleep the set frequency' do
      expect(@monitor).to receive(:sleep).with(2)
      mock_graph = double('CommandGraph')
      @monitor.execute(@inputs, nil, mock_graph)
    end

    it 'should record current time' do
      expect(File).to receive(:mtime).twice
      allow(@monitor).to receive(:sleep)
      mock_graph = double('CommandGraph')
      @monitor.execute(@inputs, nil, mock_graph)
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
      mock_graph = double('CommandGraph')
      @monitor.execute(@inputs, nil, mock_graph)
    end

    context 'when file is modified' do
      it 'should record the time as output' do
        allow(@monitor).to receive(:sleep)
        mock_graph = double('CommandGraph')
        @monitor.execute(@inputs, nil, mock_graph)
        expect(@monitor.time).to eq(1)
      end

      it 'should record the contents of the file as output' do
        allow(@monitor).to receive(:sleep)
        mock_graph = double('CommandGraph')
        @monitor.execute(@inputs, nil, mock_graph)
        expect(@monitor.contents).to eq('contents')
      end
    end
  end
end
