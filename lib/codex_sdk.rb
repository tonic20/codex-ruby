# frozen_string_literal: true

require_relative "codex_sdk/version"

module CodexSDK
  class Error < StandardError; end

  class ExecError < Error
    attr_reader :exit_code, :stderr

    def initialize(message, exit_code: nil, stderr: nil)
      @exit_code = exit_code
      @stderr = stderr
      super(message)
    end
  end

  class ParseError < Error
    attr_reader :line

    def initialize(message, line: nil)
      @line = line
      super(message)
    end
  end
end

require_relative "codex_sdk/options"
require_relative "codex_sdk/config_serializer"
require_relative "codex_sdk/items"
require_relative "codex_sdk/events"
require_relative "codex_sdk/exec"
require_relative "codex_sdk/agent_thread"
require_relative "codex_sdk/client"
