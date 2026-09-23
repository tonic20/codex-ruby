# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "timeout"

RSpec.describe "Analysis CLI compatibility" do
  around do |example|
    Dir.mktmpdir("codex-sdk-test") do |dir|
      @dir = dir
      @cli = File.join(dir, "fake-codex")
      example.run
    end
  end

  def cli(body)
    File.write(@cli, "#!#{RbConfig.ruby}\nrequire 'json'\n#{body}")
    File.chmod(0o700, @cli)
  end

  def client(env: {})
    CodexSDK::Client.new(codex_path: @cli, env: env)
  end

  it "forwards ordered images and text through the public API with isolation flags" do
    cli(<<~CODE)
      puts JSON.generate(type: 'item.completed', item: {id: 'a', type: 'agent_message', text: JSON.generate(args: ARGV, prompt: STDIN.read)})
      puts JSON.generate(type: 'turn.completed', usage: {})
    CODE
    image = File.join(@dir, "frame.png")
    File.write(image, "image fixture")
    thread = client.start_thread(ignore_user_config: true, ignore_rules: true, ephemeral: true)
    turn = thread.run([{ type: "text", text: "first" }, { type: "local_image", path: image },
                       { type: "text", text: "second" }])
    result = JSON.parse(turn.final_response)
    expect(result["prompt"]).to eq("first\n\nsecond")
    expect(result["args"]).to eq(["exec", "--json", "--ignore-user-config", "--ignore-rules", "--ephemeral", "--image",
                                  image])
  end

  it "rejects unsupported input instead of silently discarding it" do
    expect do
      client.start_thread.run([{ type: "video", path: "/tmp/clip.mp4" }])
    end.to raise_error(ArgumentError, /Unsupported/)
  end

  it "does not inherit credentials with explicit environment replacement" do
    cli(<<~CODE)
      puts JSON.generate(type: 'item.completed', item: {id: 'a', type: 'agent_message', text: ENV.fetch('CODEX_TEST_SECRET', 'absent')})
      puts JSON.generate(type: 'turn.completed', usage: {})
    CODE
    original = ENV.fetch("CODEX_TEST_SECRET", nil)
    ENV["CODEX_TEST_SECRET"] = "must-not-leak"
    expect(client.start_thread.run("test").final_response).to eq("absent")
  ensure
    ENV["CODEX_TEST_SECRET"] = original
  end

  it "rejects a partial answer without completion even on exit zero" do
    cli("puts JSON.generate(type: 'item.completed', item: {id: 'a', type: 'agent_message', text: 'partial'})")
    expect { client.start_thread.run("test") }.to raise_error(CodexSDK::Error, /complet/)
  end

  it "stops and reaps the subprocess when an event consumer raises" do
    cli(<<~CODE)
      STDOUT.sync = true
      puts JSON.generate(type: 'thread.started', thread_id: Process.pid.to_s)
      sleep 60
    CODE
    child = nil
    expect do
      Timeout.timeout(5) do
        client.start_thread.run_streamed("test") do |event|
          child = event.thread_id.to_i
          raise "consumer failed"
        end
      end
    end.to raise_error(RuntimeError, "consumer failed")
    expect { Process.kill(0, child) }.to raise_error(Errno::ESRCH)
  ensure
    Process.kill("KILL", child) if child && process_alive?(child)
  end

  it "interrupts a live process safely from competing callers" do
    cli(<<~CODE)
      STDOUT.sync = true
      puts JSON.generate(type: 'thread.started', thread_id: Process.pid.to_s)
      sleep 60
    CODE
    started = Queue.new
    thread = client.start_thread
    runner = Thread.new do
      thread.run_streamed("test") { |event| started << event.thread_id.to_i }
    rescue CodexSDK::Error => e
      e
    end
    child = Timeout.timeout(5) { started.pop }
    cancellers = 2.times.map { Thread.new { thread.interrupt } }
    cancellers.each(&:join)
    expect(runner.join(5)).to eq(runner)
    expect(runner.value).to be_a(CodexSDK::ExecError)
    expect { Process.kill(0, child) }.to raise_error(Errno::ESRCH)
  ensure
    thread&.interrupt
    runner&.join(5)
  end

  def process_alive?(pid)
    Process.kill(0, pid)
    true
  rescue Errno::ESRCH
    false
  end
end
