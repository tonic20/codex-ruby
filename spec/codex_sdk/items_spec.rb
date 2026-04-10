# frozen_string_literal: true

require "spec_helper"

RSpec.describe CodexSDK::Items do
  describe ".parse" do
    it "parses agent_message" do
      item = described_class.parse("type" => "agent_message", "id" => "item_0", "text" => "Hello!")
      expect(item).to be_a(CodexSDK::Items::AgentMessage)
      expect(item.id).to eq("item_0")
      expect(item.text).to eq("Hello!")
    end

    it "parses reasoning" do
      item = described_class.parse("type" => "reasoning", "id" => "item_1", "text" => "Let me think...")
      expect(item).to be_a(CodexSDK::Items::Reasoning)
      expect(item.text).to eq("Let me think...")
    end

    it "parses command_execution" do
      data = {
        "type" => "command_execution", "id" => "item_2",
        "command" => "ls -la", "aggregated_output" => "file1\nfile2",
        "exit_code" => 0, "status" => "completed"
      }
      item = described_class.parse(data)
      expect(item).to be_a(CodexSDK::Items::CommandExecution)
      expect(item.command).to eq("ls -la")
      expect(item.exit_code).to eq(0)
      expect(item.status).to eq("completed")
    end

    it "parses file_change" do
      data = {
        "type" => "file_change", "id" => "item_3",
        "changes" => [{ "path" => "src/main.rb", "kind" => "update" }],
        "status" => "completed"
      }
      item = described_class.parse(data)
      expect(item).to be_a(CodexSDK::Items::FileChange)
      expect(item.changes).to eq([{ path: "src/main.rb", kind: "update" }])
    end

    it "parses mcp_tool_call" do
      data = {
        "type" => "mcp_tool_call", "id" => "item_4",
        "server" => "tradebot", "tool" => "get_candles",
        "arguments" => { "pair" => "BTC/USD" },
        "result" => { "content" => [{ "type" => "text", "text" => "data..." }] },
        "error" => nil, "status" => "completed"
      }
      item = described_class.parse(data)
      expect(item).to be_a(CodexSDK::Items::McpToolCall)
      expect(item.server).to eq("tradebot")
      expect(item.tool).to eq("get_candles")
      expect(item.status).to eq("completed")
    end

    it "parses web_search" do
      item = described_class.parse("type" => "web_search", "id" => "item_5", "query" => "bitcoin price")
      expect(item).to be_a(CodexSDK::Items::WebSearch)
      expect(item.query).to eq("bitcoin price")
    end

    it "parses todo_list" do
      data = {
        "type" => "todo_list", "id" => "item_6",
        "items" => [
          { "text" => "Step 1", "completed" => true },
          { "text" => "Step 2", "completed" => false }
        ]
      }
      item = described_class.parse(data)
      expect(item).to be_a(CodexSDK::Items::TodoList)
      expect(item.items.size).to eq(2)
      expect(item.items.first[:completed]).to be true
    end

    it "parses error" do
      item = described_class.parse("type" => "error", "id" => "item_7", "message" => "something failed")
      expect(item).to be_a(CodexSDK::Items::Error)
      expect(item.message).to eq("something failed")
    end

    it "returns Unknown for unrecognized types" do
      item = described_class.parse("type" => "future_type", "id" => "item_8")
      expect(item).to be_a(CodexSDK::Items::Unknown)
      expect(item.type).to eq("future_type")
    end
  end
end
