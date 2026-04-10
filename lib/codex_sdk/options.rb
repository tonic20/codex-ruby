# frozen_string_literal: true

module CodexSDK
  # Constructor options for CodexSDK::Client.
  Options = Data.define(
    :codex_path,  # Override path to codex binary
    :base_url,    # OpenAI API base URL
    :api_key,     # API key (set as CODEX_API_KEY env var)
    :config,      # Arbitrary --config key=value overrides (Hash)
    :env          # Full env replacement (no ENV inheritance when set)
  ) do
    def initialize(codex_path: nil, base_url: nil, api_key: nil, config: {}, env: nil)
      super
    end

    def inspect
      redacted_key = api_key ? "[REDACTED]" : "nil"
      "#<#{self.class} codex_path=#{codex_path.inspect} base_url=#{base_url.inspect} " \
        "api_key=#{redacted_key} config=#{config.inspect} env=#{env ? "[SET]" : "nil"}>"
    end
  end

  # Per-thread options controlling model, sandbox, and behavior.
  ThreadOptions = Data.define(
    :model,
    :sandbox_mode,
    :working_directory,
    :approval_policy,
    :dangerously_bypass_approvals_and_sandbox,
    :reasoning_effort,
    :network_access,
    :web_search,
    :additional_directories,
    :skip_git_repo_check
  ) do
    def initialize(
      model: nil,
      sandbox_mode: nil,
      working_directory: nil,
      approval_policy: nil,
      dangerously_bypass_approvals_and_sandbox: false,
      reasoning_effort: nil,
      network_access: nil,
      web_search: nil,
      additional_directories: [],
      skip_git_repo_check: false
    )
      super
    end
  end

  # Per-turn options (output schema, abort).
  TurnOptions = Data.define(:output_schema) do
    def initialize(output_schema: nil)
      super
    end
  end

  # Token usage from a completed turn.
  Usage = Data.define(:input_tokens, :cached_input_tokens, :output_tokens) do
    def initialize(input_tokens: 0, cached_input_tokens: 0, output_tokens: 0)
      super
    end
  end

  # Result of a blocking Thread#run call.
  Turn = Data.define(:items, :final_response, :usage) do
    def initialize(items: [], final_response: "", usage: nil)
      super
    end
  end
end
