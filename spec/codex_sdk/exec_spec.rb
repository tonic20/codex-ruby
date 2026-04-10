# frozen_string_literal: true

require "spec_helper"

RSpec.describe CodexSDK::Exec do
  let(:options) { CodexSDK::Options.new(codex_path: "/usr/bin/codex") }
  let(:thread_options) { CodexSDK::ThreadOptions.new }

  def mock_popen3(stdout_lines:, stderr: "", exit_code: 0)
    stdin = instance_double(IO, write: nil, close: nil, closed?: true)
    stdout = StringIO.new(stdout_lines.join("\n") + "\n")
    stderr_io = StringIO.new(stderr)
    status = instance_double(Process::Status, success?: exit_code == 0, exitstatus: exit_code, termsig: nil)
    wait_thread = double("wait_thread", value: status, alive?: false, pid: 12345)

    allow(Open3).to receive(:popen3).and_return([stdin, stdout, stderr_io, wait_thread])

    { stdin: stdin, stdout: stdout, stderr: stderr_io, wait_thread: wait_thread }
  end

  describe "#run" do
    it "spawns codex exec and yields parsed events" do
      jsonl = [
        '{"type":"thread.started","thread_id":"t1"}',
        '{"type":"turn.started"}',
        '{"type":"item.completed","item":{"type":"agent_message","id":"i0","text":"Hi"}}',
        '{"type":"turn.completed","usage":{"input_tokens":10,"cached_input_tokens":0,"output_tokens":5}}'
      ]

      mocks = mock_popen3(stdout_lines: jsonl)

      exec = described_class.new(options, thread_options: thread_options)
      events = []

      exec.run("hello") { |event| events << event }

      expect(events.size).to eq(4)
      expect(events[0]).to be_a(CodexSDK::Events::ThreadStarted)
      expect(events[0].thread_id).to eq("t1")
      expect(events[1]).to be_a(CodexSDK::Events::TurnStarted)
      expect(events[2]).to be_a(CodexSDK::Events::ItemCompleted)
      expect(events[2].item.text).to eq("Hi")
      expect(events[3]).to be_a(CodexSDK::Events::TurnCompleted)
      expect(events[3].usage.input_tokens).to eq(10)

      expect(mocks[:stdin]).to have_received(:write).with("hello")
      expect(mocks[:stdin]).to have_received(:close)
    end

    it "raises ExecError on non-zero exit" do
      mock_popen3(stdout_lines: [], stderr: "Something went wrong", exit_code: 1)

      exec = described_class.new(options, thread_options: thread_options)

      expect {
        exec.run("hello") { |_| }
      }.to raise_error(CodexSDK::ExecError, /exited with code 1/)
    end

    it "raises ParseError for invalid JSON" do
      mock_popen3(stdout_lines: ["not json"])

      exec = described_class.new(options, thread_options: thread_options)

      expect {
        exec.run("hello") { |_| }
      }.to raise_error(CodexSDK::ParseError, /Failed to parse/)
    end

    it "skips empty lines" do
      jsonl = [
        '{"type":"thread.started","thread_id":"t1"}',
        "",
        '{"type":"turn.completed","usage":{}}'
      ]
      mock_popen3(stdout_lines: jsonl)

      exec = described_class.new(options, thread_options: thread_options)
      events = []
      exec.run("hello") { |event| events << event }

      expect(events.size).to eq(2)
    end

    it "passes the dangerous bypass flag when requested" do
      mock_popen3(stdout_lines: ['{"type":"turn.completed","usage":{}}'])

      described_class.new(
        options,
        thread_options: CodexSDK::ThreadOptions.new(dangerously_bypass_approvals_and_sandbox: true)
      ).run("hello") { |_| }

      expect(Open3).to have_received(:popen3).with(
        anything,
        "/usr/bin/codex",
        "exec",
        "--experimental-json",
        "--dangerously-bypass-approvals-and-sandbox"
      )
    end
  end

  describe "#interrupt" do
    it "sends SIGTERM to the subprocess" do
      status = instance_double(Process::Status, success?: true, exitstatus: 0, termsig: nil)
      wait_thread = double("wait_thread", value: status, alive?: true, pid: 12345)

      stdin = instance_double(IO, write: nil, close: nil, closed?: true)
      stdout = StringIO.new("")
      stderr_io = StringIO.new("")

      allow(Open3).to receive(:popen3).and_return([stdin, stdout, stderr_io, wait_thread])
      allow(Process).to receive(:kill)
      allow(wait_thread).to receive(:alive?).and_return(true, false)

      exec = described_class.new(options, thread_options: thread_options)

      # Start in a background thread so we can interrupt
      runner = ::Thread.new { exec.run("hello") { |_| } }
      sleep(0.05)

      exec.interrupt

      expect(Process).to have_received(:kill).with("TERM", 12345)
      runner.join(1)
    end
  end
end
