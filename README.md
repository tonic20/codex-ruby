# codex-ruby

Ruby SDK for the [Codex CLI](https://github.com/openai/codex). Provides subprocess management, JSONL event parsing, and a clean API for building AI-powered applications.

## Prerequisites

[Codex CLI](https://github.com/openai/codex) must be installed and available in your PATH.

```sh
npm install -g @openai/codex
```

Supported platforms: macOS, Linux.

## Installation

Add to your Gemfile:

```ruby
gem "codex-ruby"
```

Requires Ruby 3.2+.

## Usage

```ruby
require "codex_sdk"

client = CodexSDK::Client.new(
  api_key: "your-api-key",      # or set CODEX_API_KEY env var
  base_url: "https://api.openai.com/v1"  # optional
)

# Start a new thread
thread = client.start_thread(
  model: "o4-mini",
  sandbox_mode: "read-only",
  working_directory: "/path/to/project"
)

# Blocking run - returns a Turn with all items
turn = thread.run("Explain this codebase")
puts turn.final_response
puts "Tokens used: #{turn.usage.input_tokens} in, #{turn.usage.output_tokens} out"

# Streaming run - yields events as they arrive
thread.run_streamed("Fix the failing tests") do |event|
  case event
  when CodexSDK::Events::ItemCompleted
    case event.item
    when CodexSDK::Items::AgentMessage
      puts event.item.text
    when CodexSDK::Items::CommandExecution
      puts "Ran: #{event.item.command} (exit #{event.item.exit_code})"
    when CodexSDK::Items::FileChange
      event.item.changes.each { |c| puts "#{c[:kind]}: #{c[:path]}" }
    end
  when CodexSDK::Events::TurnCompleted
    puts "Done! Used #{event.usage.output_tokens} output tokens"
  when CodexSDK::Events::TurnFailed
    puts "Error: #{event.error_message}"
  end
end
```

### Resume a thread

```ruby
thread = client.resume_thread("thread_abc123", model: "o4-mini")
turn = thread.run("Now add tests for the changes")
```

### Interrupt

```ruby
# From another Ruby thread
thread.interrupt
```

### Thread options

```ruby
client.start_thread(
  model: "o4-mini",
  sandbox_mode: "read-only",      # or "read-write"
  working_directory: "/path",
  approval_policy: "unless-allow-listed",
  reasoning_effort: "high",
  network_access: true,
  web_search: true,
  additional_directories: ["/other/path"],
  skip_git_repo_check: false
)
```

### Config overrides

```ruby
client = CodexSDK::Client.new(
  api_key: "key",
  config: {
    mcp_servers: {
      my_server: { url: "http://localhost:3000/mcp" }
    }
  }
)
```

## Event types

| Event | Description |
|-------|-------------|
| `Events::ThreadStarted` | Thread created, provides `thread_id` |
| `Events::TurnStarted` | Turn began processing |
| `Events::TurnCompleted` | Turn finished, provides `usage` |
| `Events::TurnFailed` | Turn failed, provides `error_message` |
| `Events::ItemStarted` | Item processing started |
| `Events::ItemUpdated` | Item updated with partial data |
| `Events::ItemCompleted` | Item finished, provides typed `item` |
| `Events::Error` | Stream-level error, provides `message` |

## Item types

| Item | Fields |
|------|--------|
| `Items::AgentMessage` | `id`, `text` |
| `Items::Reasoning` | `id`, `text` |
| `Items::CommandExecution` | `id`, `command`, `aggregated_output`, `exit_code`, `status` |
| `Items::FileChange` | `id`, `changes` (array of `{path:, kind:}`), `status` |
| `Items::McpToolCall` | `id`, `server`, `tool`, `arguments`, `result`, `error`, `status` |
| `Items::WebSearch` | `id`, `query` |
| `Items::TodoList` | `id`, `items` (array of `{text:, completed:}`) |
| `Items::Error` | `id`, `message` |

## Development

```sh
bundle install
bundle exec rspec
```

## License

MIT
