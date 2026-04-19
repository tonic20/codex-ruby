# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "time"
require "tmpdir"

RSpec.describe CodexSDK::RolloutContextSnapshotReader do
  let(:sessions_root) { Dir.mktmpdir("codex-sessions") }

  after do
    FileUtils.rm_rf(sessions_root)
  end

  def write_rollout(relative_path, events, mtime:)
    path = File.join(sessions_root, relative_path)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, "#{events.map { |event| JSON.generate(event) }.join("\n")}\n")
    File.utime(mtime, mtime, path)
    path
  end

  it "returns the latest token_count snapshot from recent rollout files" do
    started_at = Time.utc(2026, 4, 19, 10, 0, 0)

    write_rollout(
      "2026/04/19/rollout-old.jsonl",
      [
        {
          "type" => "event_msg",
          "payload" => {
            "type" => "token_count",
            "info" => {
              "model_context_window" => 258_400,
              "last_token_usage" => { "total_tokens" => 8_498 },
              "total_token_usage" => { "total_tokens" => 24_766 }
            }
          }
        }
      ],
      mtime: started_at - 60
    )

    write_rollout(
      "2026/04/19/rollout-new.jsonl",
      [
        { "type" => "event_msg", "payload" => { "type" => "token_count", "info" => nil } },
        {
          "type" => "event_msg",
          "payload" => {
            "type" => "token_count",
            "info" => {
              "model_context_window" => 1_050_000,
              "last_token_usage" => {
                "input_tokens" => 18_000,
                "cached_input_tokens" => 2_000,
                "output_tokens" => 120,
                "reasoning_output_tokens" => 30,
                "total_tokens" => 20_150
              },
              "total_token_usage" => {
                "input_tokens" => 42_000,
                "cached_input_tokens" => 12_000,
                "output_tokens" => 360,
                "reasoning_output_tokens" => 60,
                "total_tokens" => 54_420
              }
            }
          }
        }
      ],
      mtime: started_at + 5
    )

    snapshot = described_class.new(sessions_root: sessions_root, started_at: started_at).read

    expect(snapshot.model_context_window).to eq(1_050_000)
    expect(snapshot.context_tokens).to eq(20_150)
    expect(snapshot.last_token_usage.total_tokens).to eq(20_150)
    expect(snapshot.last_token_usage.reasoning_output_tokens).to eq(30)
    expect(snapshot.total_token_usage.total_tokens).to eq(54_420)
  end

  it "reads updated existing rollout files when resuming a thread" do
    started_at = Time.utc(2026, 4, 19, 10, 0, 0)
    path = write_rollout(
      "2026/04/19/rollout-resume.jsonl",
      [
        {
          "type" => "event_msg",
          "payload" => {
            "type" => "token_count",
            "info" => {
              "model_context_window" => 258_400,
              "last_token_usage" => { "total_tokens" => 8_057 },
              "total_token_usage" => { "total_tokens" => 8_057 }
            }
          }
        }
      ],
      mtime: started_at - 60
    )

    File.write(
      path,
      "#{
        [
          {
            "type" => "event_msg",
            "payload" => {
              "type" => "token_count",
              "info" => {
                "model_context_window" => 258_400,
                "last_token_usage" => { "total_tokens" => 20_145 },
                "total_token_usage" => { "total_tokens" => 28_198 }
              }
            }
          }
        ].map { |event| JSON.generate(event) }.join("\n")
      }\n"
    )
    File.utime(started_at + 5, started_at + 5, path)

    snapshot = described_class.new(sessions_root: sessions_root, started_at: started_at).read

    expect(snapshot.context_tokens).to eq(20_145)
    expect(snapshot.total_token_usage.total_tokens).to eq(28_198)
  end

  it "returns nil when no token_count snapshot is available" do
    started_at = Time.utc(2026, 4, 19, 10, 0, 0)
    write_rollout(
      "2026/04/19/rollout-empty.jsonl",
      [{ "type" => "event_msg", "payload" => { "type" => "token_count", "info" => nil } }],
      mtime: started_at + 5
    )

    snapshot = described_class.new(sessions_root: sessions_root, started_at: started_at).read

    expect(snapshot).to be_nil
  end
end
