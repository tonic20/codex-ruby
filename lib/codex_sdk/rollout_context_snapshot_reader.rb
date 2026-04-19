# frozen_string_literal: true

require "json"

module CodexSDK
  class RolloutContextSnapshotReader
    def initialize(sessions_root:, started_at:)
      @sessions_root = sessions_root
      @started_at = started_at
    end

    def read
      candidate_rollouts.reverse_each do |path|
        snapshot = read_rollout(path)
        return snapshot if snapshot
      end

      nil
    end

    private

    def candidate_rollouts
      return [] unless Dir.exist?(@sessions_root)

      Dir.glob(File.join(@sessions_root, "**", "rollout-*.jsonl"))
        .select { |path| candidate_rollout?(path) }
        .sort_by { |path| File.mtime(path) }
    end

    def candidate_rollout?(path)
      return true unless @started_at

      File.mtime(path) >= (@started_at - 1)
    end

    def read_rollout(path)
      snapshot = nil

      File.foreach(path) do |line|
        event = JSON.parse(line)
        next unless event["type"] == "event_msg"

        payload = event["payload"]
        next unless payload.is_a?(Hash) && payload["type"] == "token_count"

        info = payload["info"]
        next unless info.is_a?(Hash)

        snapshot = ContextSnapshot.new(
          model_context_window: info["model_context_window"].to_i,
          last_token_usage: parse_usage(info["last_token_usage"]),
          total_token_usage: parse_usage(info["total_token_usage"])
        )
      end

      snapshot
    rescue Errno::ENOENT, JSON::ParserError
      nil
    end

    def parse_usage(data)
      return TokenUsage.new unless data.is_a?(Hash)

      TokenUsage.new(
        input_tokens: data["input_tokens"].to_i,
        cached_input_tokens: data["cached_input_tokens"].to_i,
        output_tokens: data["output_tokens"].to_i,
        reasoning_output_tokens: data["reasoning_output_tokens"].to_i,
        total_tokens: data["total_tokens"].to_i
      )
    end
  end
end
