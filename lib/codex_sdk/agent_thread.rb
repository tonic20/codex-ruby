# frozen_string_literal: true

require "fileutils"

module CodexSDK
  class AgentThread
    attr_reader :id

    def initialize(options, thread_options:, resume_id: nil)
      @options = options
      @thread_options = thread_options
      @id = resume_id
      @exec = nil
    end

    # Blocking run: sends prompt, collects all events, returns a Turn.
    def run(input, turn_options: TurnOptions.new)
      items = []
      final_response = ""
      usage = nil

      run_streamed(input, turn_options: turn_options) do |event|
        case event
        when Events::ItemCompleted
          items << event.item
          final_response = event.item.text if event.item.is_a?(Items::AgentMessage)
        when Events::TurnCompleted
          usage = event.usage
        when Events::TurnFailed
          raise Error, event.error_message
        when Events::Error
          items << Items::Error.new(id: nil, message: event.message)
        end
      end

      Turn.new(items: items, final_response: final_response, usage: usage)
    end

    # Streaming run: yields each event to the block as it arrives.
    def run_streamed(input, turn_options: TurnOptions.new, &block)
      prompt = normalize_input(input)

      output_schema_path = nil
      if turn_options.output_schema
        output_schema_path = write_output_schema(turn_options.output_schema)
      end

      @exec = Exec.new(
        @options,
        thread_options: @thread_options
      )

      @exec.run(
        prompt,
        resume_thread_id: @id,
        output_schema_path: output_schema_path
      ) do |event|
        # Capture thread ID from first event
        @id = event.thread_id if event.is_a?(Events::ThreadStarted)

        block.call(event)
      end
    ensure
      cleanup_output_schema(output_schema_path)
    end

    # Interrupt the running subprocess.
    def interrupt
      @exec&.interrupt
    end

    private

    def normalize_input(input)
      case input
      when String
        input
      when Array
        input.filter_map { |entry|
          entry[:text] if entry[:type] == "text"
        }.join("\n\n")
      else
        input.to_s
      end
    end

    def write_output_schema(schema)
      dir = Dir.mktmpdir("codex-output-schema")
      path = File.join(dir, "schema.json")
      File.write(path, JSON.generate(schema))
      path
    end

    def cleanup_output_schema(path)
      return unless path
      dir = File.dirname(path)
      FileUtils.rm_rf(dir)
    rescue StandardError
      # best effort
    end
  end
end
