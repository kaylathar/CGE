require_relative '../monitors/FileUpdateMonitor'
require 'yaml'

describe FileUpdateMonitor do
  before :each do
    @monitor = FileUpdateMonitor.new( 
      :path => "/tmp/test1",
      :frequency => 3,
    )
  end

  describe "#options" do
    it "is a Hash object" do
      expect(FileUpdateMonitor.options.class).to eq(Hash)
    end

    it "contains two objects" do
      expect(FileUpdateMonitor.options.size).to eq(2)
    end

    context "path option" do
      it { expect(FileUpdateMonitor.options["path"]).to eq(String) }
    end

    context "frequency option" do
      it { expect(FileUpdateMonitor.options["frequency"]).to eq(Integer) }
    end
  end

end
