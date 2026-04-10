# frozen_string_literal: true

module CodexSDK
  module Items
    # Parse a JSON hash into a typed item.
    def self.parse(data)
      case data["type"]
      when "agent_message"   then AgentMessage.from_json(data)
      when "reasoning"       then Reasoning.from_json(data)
      when "command_execution" then CommandExecution.from_json(data)
      when "file_change"     then FileChange.from_json(data)
      when "mcp_tool_call"   then McpToolCall.from_json(data)
      when "web_search"      then WebSearch.from_json(data)
      when "todo_list"       then TodoList.from_json(data)
      when "error"           then Error.from_json(data)
      else Unknown.new(id: data["id"], type: data["type"], data: data)
      end
    end

    AgentMessage = Data.define(:id, :text) do
      def self.from_json(data)
        new(id: data["id"], text: data["text"].to_s)
      end
    end

    Reasoning = Data.define(:id, :text) do
      def self.from_json(data)
        new(id: data["id"], text: data["text"].to_s)
      end
    end

    CommandExecution = Data.define(:id, :command, :aggregated_output, :exit_code, :status) do
      def self.from_json(data)
        new(
          id: data["id"],
          command: data["command"].to_s,
          aggregated_output: data["aggregated_output"].to_s,
          exit_code: data["exit_code"],
          status: data["status"].to_s
        )
      end
    end

    FileChange = Data.define(:id, :changes, :status) do
      def self.from_json(data)
        changes = (data["changes"] || []).map do |c|
          { path: c["path"], kind: c["kind"] }
        end
        new(id: data["id"], changes: changes, status: data["status"].to_s)
      end
    end

    McpToolCall = Data.define(:id, :server, :tool, :arguments, :result, :error, :status) do
      def self.from_json(data)
        new(
          id: data["id"],
          server: data["server"].to_s,
          tool: data["tool"].to_s,
          arguments: data["arguments"],
          result: data["result"],
          error: data["error"],
          status: data["status"].to_s
        )
      end
    end

    WebSearch = Data.define(:id, :query) do
      def self.from_json(data)
        new(id: data["id"], query: data["query"].to_s)
      end
    end

    TodoList = Data.define(:id, :items) do
      def self.from_json(data)
        items = (data["items"] || []).map do |item|
          { text: item["text"], completed: item["completed"] }
        end
        new(id: data["id"], items: items)
      end
    end

    Error = Data.define(:id, :message) do
      def self.from_json(data)
        new(id: data["id"], message: data["message"].to_s)
      end
    end

    Unknown = Data.define(:id, :type, :data)
  end
end
