# Changelog

## 0.2.3 (2026-09-23)

- Preserve provider failures when macOS reports a transient permission error for an exiting process group; verify that the group is gone before ignoring cleanup errors.

## 0.2.2 (2026-09-23)

- Clear the exposed PID after an already-exited CLI has been reaped, preventing stale process diagnostics.

## 0.2.1 (2026-09-23)

- Expose the active CLI PID through `AgentThread#pid` for worker recovery diagnostics.

## 0.2.0 (2026-09-23)

- Forward ordered `local_image` inputs through the public thread API; reject unsupported input types and invalid local paths instead of silently discarding them.
- Add `ignore_user_config`, `ignore_rules`, and `ephemeral` thread options; use the documented `--json` CLI flag.
- Honor explicit environment replacement without inheriting parent secrets.
- Terminate and reap CLI process groups on cancellation or consumer errors, with concurrent interruption serialized.
- Raise on streams that end without a completed turn instead of returning partial answers as success.

## 0.1.5 (2026-06-17)

- Include structured Codex CLI error events in non-zero exit errors, so
  API failures such as unsupported model names are visible to callers

## 0.1.4 (2026-06-16)

- Pass `web_search: true` to current Codex CLI versions as the global
  `--search` flag instead of the rejected `web_search=true` config override

## 0.1.3 (2026-06-16)

- Add `AGENTS.md` with contributor and release rules for AI agents
- Disable the `Gemspec/RequireMFA` RuboCop cop to match the intentionally MFA-free release setup

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
