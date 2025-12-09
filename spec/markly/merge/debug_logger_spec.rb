# frozen_string_literal: true

RSpec.describe Markly::Merge::DebugLogger do
  describe "module configuration" do
    it "has env_var_name set" do
      expect(described_class.env_var_name).to eq("MARKLY_MERGE_DEBUG")
    end

    it "has log_prefix set" do
      expect(described_class.log_prefix).to eq("[markly-merge]")
    end
  end

  describe "inheritance" do
    it "extends Ast::Merge::DebugLogger" do
      expect(described_class.singleton_class.ancestors).to include(Ast::Merge::DebugLogger)
    end
  end

  describe ".debug" do
    context "when debug disabled" do
      before do
        allow(ENV).to receive(:[]).with("MARKLY_MERGE_DEBUG").and_return(nil)
      end

      it "does not output" do
        expect { described_class.debug("test") }.not_to output.to_stderr
      end
    end

    context "when debug enabled" do
      before do
        allow(ENV).to receive(:[]).with("MARKLY_MERGE_DEBUG").and_return("1")
      end

      it "outputs debug message" do
        expect { described_class.debug("test message") }.to output(/test message/).to_stderr
      end

      it "includes prefix" do
        expect { described_class.debug("test") }.to output(/\[markly-merge\]/).to_stderr
      end
    end
  end

  describe ".time" do
    it "returns block result" do
      result = described_class.time("operation") { 42 }
      expect(result).to eq(42)
    end

    it "executes block" do
      executed = false
      described_class.time("operation") { executed = true }
      expect(executed).to be true
    end

    context "when debug enabled" do
      before do
        allow(ENV).to receive(:[]).with("MARKLY_MERGE_DEBUG").and_return("1")
      end

      it "outputs timing info" do
        expect { described_class.time("test_op") { sleep(0.001) } }.to output(/test_op/).to_stderr
      end
    end
  end
end
