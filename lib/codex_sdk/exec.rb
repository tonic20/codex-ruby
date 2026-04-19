# frozen_string_literal: true

require "open3"
require "json"

module CodexSDK
  # Internal: manages the codex CLI subprocess.
  # Spawns `codex exec --experimental-json`, writes prompt to stdin,
  # reads JSONL events from stdout.
  class Exec
    SHUTDOWN_TIMEOUT = 10 # seconds to wait after SIGTERM before SIGKILL

    attr_reader :pid, :context_snapshot

    def initialize(options, thread_options: ThreadOptions.new)
      @options = options
      @thread_options = thread_options
      @stdin = nil
      @stdout = nil
      @stderr = nil
      @wait_thread = nil
      @mutex = Mutex.new
    end

    # Spawns the subprocess, writes the prompt, reads JSONL events.
    # Yields each parsed event hash to the block.
    def run(prompt, resume_thread_id: nil, images: [], output_schema_path: nil, &block)
      args = build_args(resume_thread_id: resume_thread_id, images: images, output_schema_path: output_schema_path)
      env = build_env
      sessions_root = codex_sessions_root(env)
      started_at = Time.now
      @context_snapshot = nil

      @stdin, @stdout, @stderr, @wait_thread = Open3.popen3(env, *args)

      # Write prompt and close stdin (one-shot, matching TypeScript SDK)
      @stdin.write(prompt.to_s)
      @stdin.close

      # Read stderr in background thread
      stderr_reader = ::Thread.new do
        @stderr.read
      rescue StandardError
        ""
      end

      # Read JSONL from stdout line by line
      @stdout.each_line do |line|
        line = line.strip
        next if line.empty?

        begin
          data = JSON.parse(line)
        rescue JSON::ParserError => e
          raise ParseError.new("Failed to parse event: #{e.message}", line: line)
        end

        event = Events.parse(data)
        block.call(event)
      end

      stderr_buf = stderr_reader.value.to_s
      status = @wait_thread.value

      unless status.success?
        code = status.exitstatus || status.termsig
        truncated = stderr_buf.length > 500 ? "#{stderr_buf[0, 497]}..." : stderr_buf
        raise ExecError.new(
          "Codex exited with code #{code}: #{truncated}",
          exit_code: code,
          stderr: stderr_buf
        )
      end

      @context_snapshot = read_context_snapshot(
        sessions_root: sessions_root,
        started_at: started_at
      )
    ensure
      cleanup
    end

    # Sends SIGTERM to the subprocess, waits, then SIGKILL if needed.
    def interrupt
      @mutex.synchronize do
        return unless @wait_thread&.alive?

        begin
          Process.kill("TERM", @wait_thread.pid)
        rescue Errno::ESRCH
          return
        end

        # Wait for graceful shutdown
        unless wait_for_exit(SHUTDOWN_TIMEOUT)
          begin
            Process.kill("KILL", @wait_thread.pid)
          rescue Errno::ESRCH
            # already gone
          end
        end
      end
    end

    private

    def build_args(resume_thread_id: nil, images: [], output_schema_path: nil)
      codex_path = @options.codex_path || find_codex_path
      args = [codex_path, "exec", "--experimental-json"]

      # Global config overrides
      args.concat(ConfigSerializer.to_flags(@options.config)) if @options.config.any?

      # Base URL
      if @options.base_url
        args.concat(["--config", "openai_base_url=#{ConfigSerializer.to_toml_value(@options.base_url)}"])
      end

      # Thread options -> CLI flags
      to = @thread_options
      args.concat(["--model", to.model]) if to.model
      args.concat(["--sandbox", to.sandbox_mode]) if to.sandbox_mode
      args.concat(["--cd", to.working_directory]) if to.working_directory
      args << "--dangerously-bypass-approvals-and-sandbox" if to.dangerously_bypass_approvals_and_sandbox
      args << "--skip-git-repo-check" if to.skip_git_repo_check

      to.additional_directories.each { |dir| args.concat(["--add-dir", dir]) }

      if to.reasoning_effort
        args.concat(["--config", "model_reasoning_effort=#{ConfigSerializer.to_toml_value(to.reasoning_effort)}"])
      end

      unless to.network_access.nil?
        args.concat(["--config", "sandbox_workspace_write.network_access=#{to.network_access}"])
      end

      args.concat(["--config", "web_search=#{ConfigSerializer.to_toml_value(to.web_search)}"]) if to.web_search

      if to.approval_policy
        args.concat(["--config", "approval_policy=#{ConfigSerializer.to_toml_value(to.approval_policy)}"])
      end

      # Output schema
      args.concat(["--output-schema", output_schema_path]) if output_schema_path

      # Resume
      args.concat(["resume", resume_thread_id]) if resume_thread_id

      # Images (always last)
      images.each { |path| args.concat(["--image", path]) }

      args
    end

    def build_env
      base_env = @options.env || ENV.to_h
      env = base_env.dup
      env["CODEX_API_KEY"] = @options.api_key if @options.api_key
      env["CODEX_INTERNAL_ORIGINATOR_OVERRIDE"] ||= "codex_sdk_rb"
      env
    end

    def find_codex_path
      path = `which codex 2>/dev/null`.strip
      raise Error, "codex binary not found in PATH" if path.empty?

      path
    end

    def codex_sessions_root(env)
      return File.join(env["CODEX_HOME"], "sessions") if env["CODEX_HOME"] && !env["CODEX_HOME"].empty?

      return unless env["HOME"] && !env["HOME"].empty?

      File.join(env["HOME"], ".codex", "sessions")
    end

    def read_context_snapshot(sessions_root:, started_at:)
      return unless sessions_root

      RolloutContextSnapshotReader.new(
        sessions_root: sessions_root,
        started_at: started_at
      ).read
    rescue StandardError
      nil
    end

    def wait_for_exit(timeout)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
      loop do
        return true unless @wait_thread&.alive?

        remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
        return false if remaining <= 0

        sleep([0.1, remaining].min)
      end
    end

    def cleanup
      @stdin&.close unless @stdin&.closed?
      @stdout&.close unless @stdout&.closed?
      @stderr&.close unless @stderr&.closed?
    end
  end
end
