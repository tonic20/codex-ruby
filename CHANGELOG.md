# Changelog

## 0.1.0 (2026-04-10)

- Initial release
- Client with `start_thread` and `resume_thread`
- Blocking and streaming execution modes
- JSONL event parsing (thread, turn, item, error events)
- Item types: agent message, reasoning, command execution, file change, MCP tool call, web search, todo list
- Config serialization to TOML CLI flags
- Subprocess lifecycle management with graceful shutdown
- API key redaction in inspect output
