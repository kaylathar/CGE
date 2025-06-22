require 'spec_helper'

describe CGE::CronMonitor do
  let(:options) { { 'time' => '2024-12-25 10:00:00' } }
  let(:monitor) { CGE::CronMonitor.new('cron_monitor', {}) }

  context 'when on_trigger is called' do
    it 'should require a time option' do
      expect(CGE::CronMonitor.required_options).to include('time')
    end

    it 'should validate that time is parseable' do
      invalid_options = { 'time' => 'not a time' }
      expect { monitor.execute(invalid_options, nil) }.to raise_error
    end

    it 'should accept valid time formats' do
      valid_times = [
        '2024-12-25 10:00:00',
        '2024/12/25 10:00:00',
        'Dec 25, 2024 10:00 AM'
      ]

      valid_times.each do |time_str|
        options = { 'time' => time_str }
        expect { monitor.execute(options, nil) }.not_to raise_error
      end
    end

    it 'should parse the target time correctly' do
      monitor.execute(options, nil)
      expect(monitor.instance_variable_get(:@target_time)).to be_a(Time)
    end

    context 'when target time is in the future' do
      let(:future_time) { Time.now + 1 }
      let(:future_options) { { 'time' => future_time.to_s } }
      let(:future_monitor) { CGE::CronMonitor.new('future_monitor', {}) }

      it 'should sleep until target time' do
        expect(future_monitor).to receive(:sleep).with(kind_of(Numeric))
        future_monitor.execute(future_options, nil)
      end

      it 'should set fired_at when triggered' do
        allow(future_monitor).to receive(:sleep)
        future_monitor.execute(future_options, nil)
        expect(future_monitor.fired_at).to be_a(Time)
      end

    end

    context 'when target time is in the past' do
      let(:past_time) { Time.now - 1 }
      let(:past_options) { { 'time' => past_time.to_s } }
      let(:past_monitor) { CGE::CronMonitor.new('past_monitor', {}) }

      it 'should not sleep' do
        expect(past_monitor).not_to receive(:sleep)
        past_monitor.execute(past_options, nil)
      end

      it 'should return immediately' do
        start_time = Time.now
        past_monitor.execute(past_options, nil)
        end_time = Time.now
        expect(end_time - start_time).to be < 0.1
      end
    end
  end
end
