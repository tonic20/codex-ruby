# frozen_string_literal: true

require "spec_helper"

RSpec.describe CodexSDK::AgentThread do
  let(:options) { CodexSDK::Options.new(codex_path: "/usr/bin/codex") }
  let(:thread_options) { CodexSDK::ThreadOptions.new(model: "gpt-5") }

  def stub_exec_run(events)
    allow_any_instance_of(CodexSDK::Exec).to receive(:run) do |_exec, _prompt, **_kwargs, &block|
      events.each { |event| block.call(event) }
    end
  end

  describe "#run" do
    it "collects events and returns a Turn" do
      context_snapshot = CodexSDK::ContextSnapshot.new(
        model_context_window: 258_400,
        last_token_usage: CodexSDK::TokenUsage.new(total_tokens: 12_345),
        total_token_usage: CodexSDK::TokenUsage.new(total_tokens: 67_890)
      )
      events = [
        CodexSDK::Events::ThreadStarted.new(thread_id: "t1"),
        CodexSDK::Events::TurnStarted.new,
        CodexSDK::Events::ItemCompleted.new(item: CodexSDK::Items::AgentMessage.new(id: "i0", text: "Hello!")),
        CodexSDK::Events::TurnCompleted.new(usage: CodexSDK::Usage.new(input_tokens: 50, output_tokens: 10))
      ]
      exec = instance_double(CodexSDK::Exec, context_snapshot: context_snapshot)
      allow(CodexSDK::Exec).to receive(:new).and_return(exec)
      allow(exec).to receive(:run) do |_prompt, **_kwargs, &block|
        events.each { |event| block.call(event) }
      end

      thread = described_class.new(options, thread_options: thread_options)
      turn = thread.run("test prompt")

      expect(turn.items.size).to eq(1)
      expect(turn.final_response).to eq("Hello!")
      expect(turn.usage.input_tokens).to eq(50)
      expect(turn.usage.output_tokens).to eq(10)
      expect(turn.context_snapshot).to eq(context_snapshot)
      expect(thread.context_snapshot).to eq(context_snapshot)
      expect(thread.id).to eq("t1")
    end

    it "raises on TurnFailed" do
      events = [
        CodexSDK::Events::ThreadStarted.new(thread_id: "t1"),
        CodexSDK::Events::TurnStarted.new,
        CodexSDK::Events::TurnFailed.new(error_message: "rate limited")
      ]
      stub_exec_run(events)

      thread = described_class.new(options, thread_options: thread_options)
      expect { thread.run("test") }.to raise_error(CodexSDK::Error, "rate limited")
    end

    it "captures Events::Error as an error item" do
      events = [
        CodexSDK::Events::ThreadStarted.new(thread_id: "t1"),
        CodexSDK::Events::TurnStarted.new,
        CodexSDK::Events::Error.new(message: "stream error"),
        CodexSDK::Events::TurnCompleted.new(usage: CodexSDK::Usage.new)
      ]
      stub_exec_run(events)

      thread = described_class.new(options, thread_options: thread_options)
      turn = thread.run("test")

      expect(turn.items.size).to eq(1)
      expect(turn.items.first).to be_a(CodexSDK::Items::Error)
      expect(turn.items.first.message).to eq("stream error")
    end
  end

  describe "namespace safety" do
    it "does not define CodexSDK::Thread" do
      expect(CodexSDK.const_defined?(:Thread, false)).to be(false)
    end
  end

  describe "#run_streamed" do
    it "yields events as they arrive" do
      events = [
        CodexSDK::Events::ThreadStarted.new(thread_id: "t1"),
        CodexSDK::Events::ItemCompleted.new(item: CodexSDK::Items::Reasoning.new(id: "i0", text: "thinking...")),
        CodexSDK::Events::ItemCompleted.new(item: CodexSDK::Items::AgentMessage.new(id: "i1", text: "Result")),
        CodexSDK::Events::TurnCompleted.new(usage: CodexSDK::Usage.new(output_tokens: 20))
      ]
      stub_exec_run(events)

      thread = described_class.new(options, thread_options: thread_options)
      received = []
      thread.run_streamed("test") { |event| received << event }

      expect(received.size).to eq(4)
      expect(received[0]).to be_a(CodexSDK::Events::ThreadStarted)
      expect(received[1].item).to be_a(CodexSDK::Items::Reasoning)
    end

    it "captures thread_id from ThreadStarted event" do
      events = [CodexSDK::Events::ThreadStarted.new(thread_id: "thread_xyz")]
      stub_exec_run(events)

      thread = described_class.new(options, thread_options: thread_options)
      expect(thread.id).to be_nil

      thread.run_streamed("test") { |_event| nil }
      expect(thread.id).to eq("thread_xyz")
    end

    it "stores the final context snapshot after the stream ends" do
      context_snapshot = CodexSDK::ContextSnapshot.new(
        model_context_window: 258_400,
        last_token_usage: CodexSDK::TokenUsage.new(total_tokens: 20_145),
        total_token_usage: CodexSDK::TokenUsage.new(total_tokens: 28_198)
      )
      exec = instance_double(CodexSDK::Exec, context_snapshot: context_snapshot)
      allow(CodexSDK::Exec).to receive(:new).and_return(exec)
      allow(exec).to receive(:run) do |_prompt, **_kwargs, &block|
        block.call(CodexSDK::Events::ThreadStarted.new(thread_id: "thread_xyz"))
      end

      thread = described_class.new(options, thread_options: thread_options)
      thread.run_streamed("test") { |_event| nil }

      expect(thread.context_snapshot).to eq(context_snapshot)
    end
  end

  describe "#interrupt" do
    it "delegates to exec" do
      exec = instance_double(CodexSDK::Exec, interrupt: nil, context_snapshot: nil)
      allow(CodexSDK::Exec).to receive(:new).and_return(exec)
      allow(exec).to receive(:run)

      thread = described_class.new(options, thread_options: thread_options)
      thread.run_streamed("test") { |_event| nil }
      thread.interrupt

      expect(exec).to have_received(:interrupt)
    end
  end
end
