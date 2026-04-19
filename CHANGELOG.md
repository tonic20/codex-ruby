# Changelog

## 0.1.2 (2026-04-19)

- Expose rollout-derived `context_snapshot` data on `Exec`, `AgentThread`, and blocking `Turn` results
- Add `TokenUsage` and `ContextSnapshot` types plus rollout log parsing for Codex `token_count` events
- Add RuboCop to the repository with a dedicated CI lint job and baseline configuration

## 0.1.1 (2026-04-11)

- Patch release

## 0.1.0 (2026-04-10)

- Initial release
- Client with `start_thread` and `resume_thread`
- Blocking and streaming execution modes
- JSONL event parsing (thread, turn, item, error events)
- Item types: agent message, reasoning, command execution, file change, MCP tool call, web search, todo list
- Config serialization to TOML CLI flags
- Subprocess lifecycle management with graceful shutdown
- API key redaction in inspect output
