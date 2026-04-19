# frozen_string_literal: true

require "spec_helper"

RSpec.describe CodexSDK::Events do
  describe ".parse" do
    it "parses thread.started" do
      event = described_class.parse("type" => "thread.started", "thread_id" => "thread_abc")
      expect(event).to be_a(CodexSDK::Events::ThreadStarted)
      expect(event.thread_id).to eq("thread_abc")
    end

    it "parses turn.started" do
      event = described_class.parse("type" => "turn.started")
      expect(event).to be_a(CodexSDK::Events::TurnStarted)
    end

    it "parses turn.completed with usage" do
      data = {
        "type" => "turn.completed",
        "usage" => { "input_tokens" => 100, "cached_input_tokens" => 20, "output_tokens" => 50 }
      }
      event = described_class.parse(data)
      expect(event).to be_a(CodexSDK::Events::TurnCompleted)
      expect(event.usage.input_tokens).to eq(100)
      expect(event.usage.cached_input_tokens).to eq(20)
      expect(event.usage.output_tokens).to eq(50)
    end

    it "parses turn.completed without usage" do
      event = described_class.parse("type" => "turn.completed")
      expect(event).to be_a(CodexSDK::Events::TurnCompleted)
      expect(event.usage).to be_nil
    end

    it "parses turn.failed" do
      data = { "type" => "turn.failed", "error" => { "message" => "rate limited" } }
      event = described_class.parse(data)
      expect(event).to be_a(CodexSDK::Events::TurnFailed)
      expect(event.error_message).to eq("rate limited")
    end

    it "parses item.started" do
      data = {
        "type" => "item.started",
        "item" => { "type" => "mcp_tool_call", "id" => "item_0", "server" => "test", "tool" => "foo",
                    "status" => "in_progress" }
      }
      event = described_class.parse(data)
      expect(event).to be_a(CodexSDK::Events::ItemStarted)
      expect(event.item).to be_a(CodexSDK::Items::McpToolCall)
      expect(event.item.status).to eq("in_progress")
    end

    it "parses item.updated" do
      data = {
        "type" => "item.updated",
        "item" => { "type" => "command_execution", "id" => "item_1", "command" => "ls",
                    "aggregated_output" => "partial", "status" => "in_progress" }
      }
      event = described_class.parse(data)
      expect(event).to be_a(CodexSDK::Events::ItemUpdated)
      expect(event.item).to be_a(CodexSDK::Items::CommandExecution)
    end

    it "parses item.completed" do
      data = {
        "type" => "item.completed",
        "item" => { "type" => "agent_message", "id" => "item_2", "text" => "Done!" }
      }
      event = described_class.parse(data)
      expect(event).to be_a(CodexSDK::Events::ItemCompleted)
      expect(event.item).to be_a(CodexSDK::Items::AgentMessage)
      expect(event.item.text).to eq("Done!")
    end

    it "parses error" do
      event = described_class.parse("type" => "error", "message" => "fatal error")
      expect(event).to be_a(CodexSDK::Events::Error)
      expect(event.message).to eq("fatal error")
    end

    it "returns Unknown for unrecognized types" do
      event = described_class.parse("type" => "future.event", "data" => {})
      expect(event).to be_a(CodexSDK::Events::Unknown)
      expect(event.type).to eq("future.event")
    end
  end
end
