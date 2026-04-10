# frozen_string_literal: true

module CodexSDK
  module Events
    # Parse a JSON hash into a typed event.
    def self.parse(data)
      case data["type"]
      when "thread.started"  then ThreadStarted.new(thread_id: data["thread_id"])
      when "turn.started"    then TurnStarted.new
      when "turn.completed"  then TurnCompleted.from_json(data)
      when "turn.failed"     then TurnFailed.new(error_message: data.dig("error", "message").to_s)
      when "item.started"    then ItemStarted.new(item: Items.parse(data["item"]))
      when "item.updated"    then ItemUpdated.new(item: Items.parse(data["item"]))
      when "item.completed"  then ItemCompleted.new(item: Items.parse(data["item"]))
      when "error"           then Error.new(message: data["message"].to_s)
      else Unknown.new(type: data["type"], data: data)
      end
    end

    ThreadStarted = Data.define(:thread_id)

    TurnStarted = Data.define do
      def initialize; super(); end
    end

    TurnCompleted = Data.define(:usage) do
      def self.from_json(data)
        usage_data = data["usage"]
        return new(usage: nil) unless usage_data.is_a?(Hash) && usage_data.any?

        usage = ::CodexSDK::Usage.new(
          input_tokens: usage_data["input_tokens"].to_i,
          cached_input_tokens: usage_data["cached_input_tokens"].to_i,
          output_tokens: usage_data["output_tokens"].to_i
        )
        new(usage: usage)
      end
    end

    TurnFailed = Data.define(:error_message)

    ItemStarted = Data.define(:item)
    ItemUpdated = Data.define(:item)
    ItemCompleted = Data.define(:item)

    Error = Data.define(:message)

    Unknown = Data.define(:type, :data)
  end
end
