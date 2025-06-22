require 'spec_helper'

describe DAF::CronMonitor do
  let(:options) { { 'time' => '2024-12-25 10:00:00' } }
  let(:monitor) { DAF::CronMonitor.new }

  context 'when on_trigger is called' do
    it 'should require a time option' do
      expect(DAF::CronMonitor.required_options).to include('time')
    end

    it 'should validate that time is parseable' do
      invalid_options = { 'time' => 'not a time' }
      expect { monitor.on_trigger(invalid_options) }.to raise_error
    end

    it 'should accept valid time formats' do
      valid_times = [
        '2024-12-25 10:00:00',
        '2024/12/25 10:00:00',
        'Dec 25, 2024 10:00 AM'
      ]

      valid_times.each do |time_str|
        options = { 'time' => time_str }
        expect { monitor.on_trigger(options) }.not_to raise_error
      end
    end

    it 'should parse the target time correctly' do
      monitor.on_trigger(options)
      expect(monitor.instance_variable_get(:@target_time)).to be_a(Time)
    end

    context 'when target time is in the future' do
      let(:future_time) { Time.now + 1 }
      let(:future_options) { { 'time' => future_time.to_s } }
      let(:future_monitor) { DAF::CronMonitor.new }

      it 'should sleep until target time' do
        expect(future_monitor).to receive(:sleep).with(kind_of(Numeric))
        future_monitor.on_trigger(future_options)
      end

      it 'should set fired_at when triggered' do
        allow(future_monitor).to receive(:sleep)
        future_monitor.on_trigger(future_options)
        expect(future_monitor.fired_at).to be_a(Time)
      end

    end

    context 'when target time is in the past' do
      let(:past_time) { Time.now - 1 }
      let(:past_options) { { 'time' => past_time.to_s } }
      let(:past_monitor) { DAF::CronMonitor.new }

      it 'should not sleep' do
        expect(past_monitor).not_to receive(:sleep)
        past_monitor.on_trigger(past_options)
      end

      it 'should return immediately' do
        start_time = Time.now
        past_monitor.on_trigger(past_options)
        end_time = Time.now
        expect(end_time - start_time).to be < 0.1
      end
    end
  end
end
