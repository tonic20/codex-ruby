# frozen_string_literal: true

require "spec_helper"

RSpec.describe CodexSDK::Client do
  describe "#start_thread" do
    it "returns a Thread with the given options" do
      client = described_class.new(api_key: "test-key")
      thread = client.start_thread(model: "gpt-5", sandbox_mode: "read-only")

      expect(thread).to be_a(CodexSDK::AgentThread)
      expect(thread.id).to be_nil
    end
  end

  describe "#resume_thread" do
    it "returns a Thread with the given ID" do
      client = described_class.new(api_key: "test-key")
      thread = client.resume_thread("thread_abc", model: "gpt-5")

      expect(thread).to be_a(CodexSDK::AgentThread)
      expect(thread.id).to eq("thread_abc")
    end
  end
end
