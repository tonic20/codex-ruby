# frozen_string_literal: true

require "spec_helper"

RSpec.describe CodexSDK::ConfigSerializer do
  describe ".to_toml_value" do
    it "serializes strings as JSON-quoted" do
      expect(described_class.to_toml_value("hello")).to eq('"hello"')
    end

    it "serializes strings with special characters" do
      expect(described_class.to_toml_value('say "hi"')).to eq('"say \\"hi\\""')
    end

    it "serializes integers" do
      expect(described_class.to_toml_value(42)).to eq("42")
    end

    it "serializes floats" do
      expect(described_class.to_toml_value(3.14)).to eq("3.14")
    end

    it "raises for non-finite numbers" do
      expect { described_class.to_toml_value(Float::INFINITY) }.to raise_error(ArgumentError, /non-finite/)
    end

    it "serializes booleans" do
      expect(described_class.to_toml_value(true)).to eq("true")
      expect(described_class.to_toml_value(false)).to eq("false")
    end

    it "serializes arrays" do
      expect(described_class.to_toml_value([1, "two", true])).to eq('[1, "two", true]')
    end

    it "serializes hashes as inline tables" do
      expect(described_class.to_toml_value({ a: 1, b: "x" })).to eq('{a = 1, b = "x"}')
    end

    it "raises for nil" do
      expect { described_class.to_toml_value(nil) }.to raise_error(ArgumentError, /nil/)
    end
  end

  describe ".flatten" do
    it "flattens nested hashes with dot notation" do
      input = { a: { b: 1, c: { d: 2 } } }
      expect(described_class.flatten(input)).to eq("a.b" => 1, "a.c.d" => 2)
    end

    it "handles flat hashes" do
      input = { model: "gpt-5" }
      expect(described_class.flatten(input)).to eq("model" => "gpt-5")
    end
  end

  describe ".to_flags" do
    it "converts a hash to --config flag pairs" do
      input = { sandbox_workspace_write: { network_access: true } }
      flags = described_class.to_flags(input)
      expect(flags).to eq(["--config", "sandbox_workspace_write.network_access=true"])
    end

    it "handles multiple keys" do
      input = { model_reasoning_effort: "high", web_search: "disabled" }
      flags = described_class.to_flags(input)
      expect(flags).to eq([
                            "--config", 'model_reasoning_effort="high"',
                            "--config", 'web_search="disabled"'
                          ])
    end

    it "returns empty array for empty hash" do
      expect(described_class.to_flags({})).to eq([])
    end
  end

  describe ".format_key" do
    it "uses bare keys for simple names" do
      expect(described_class.format_key(:simple_key)).to eq("simple_key")
    end

    it "quotes keys with special characters" do
      expect(described_class.format_key("key with spaces")).to eq('"key with spaces"')
    end
  end
end
