# frozen_string_literal: true

module CodexSDK
  class Client
    def initialize(codex_path: nil, base_url: nil, api_key: nil, config: {}, env: nil)
      @options = Options.new(
        codex_path: codex_path,
        base_url: base_url,
        api_key: api_key,
        config: config,
        env: env
      )
    end

    # Start a new thread with the given options.
    def start_thread(**kwargs)
      thread_options = ThreadOptions.new(**kwargs)
      AgentThread.new(@options, thread_options: thread_options)
    end

    # Resume an existing thread by ID.
    def resume_thread(thread_id, **kwargs)
      thread_options = ThreadOptions.new(**kwargs)
      AgentThread.new(@options, thread_options: thread_options, resume_id: thread_id)
    end
  end
end
