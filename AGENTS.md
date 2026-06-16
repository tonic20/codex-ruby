# AGENTS.md

Rules for AI agents working on the `codex-ruby` gem (a pure-Ruby SDK for the Codex CLI).

## Project layout

- `lib/codex_sdk.rb` — entry point: defines the `CodexSDK` module, error classes, and `require`s every component.
- `lib/codex_sdk/version.rb` — single source of truth for the gem version.
- `lib/codex_sdk/client.rb` — the public `Client` (`start_thread`, `resume_thread`).
- `lib/codex_sdk/agent_thread.rb` — thread object with blocking (`run`) and streaming (`run_streamed`) execution.
- `lib/codex_sdk/exec.rb` — subprocess lifecycle management for the Codex CLI.
- `lib/codex_sdk/events.rb` / `items.rb` — typed JSONL event and item classes.
- `lib/codex_sdk/options.rb` / `config_serializer.rb` — thread options and TOML/CLI flag serialization.
- `lib/codex_sdk/rollout_context_snapshot_reader.rb` — parses Codex rollout logs for `token_count` data.
- `spec/` — RSpec tests, mirroring `lib/codex_sdk/` one file per component.
- `codex-ruby.gemspec` — gem metadata (note: the gem name is `codex-ruby`, the module is `CodexSDK`).
- `CHANGELOG.md` — human-edited changelog.

## Golden rules

1. **Bump the version at the end of every feature or bugfix.** Edit `lib/codex_sdk/version.rb` and add a matching entry to `CHANGELOG.md` before the work is considered done. This is easy to forget — treat it as part of the definition of done for any change that ships behavior.
2. **Never ship without running the spec suite and the linter.** Both `bundle exec rspec` and `bundle exec rubocop` must be green — CI runs both.
3. **Keep everything under the `CodexSDK` namespace.** No top-level constants. Clients, threads, events, items, and errors all live under `CodexSDK::`.
4. **Don't break downstream apps.** This SDK is consumed by other Ruby projects — the public API (`Client`, `AgentThread`, `Events::*`, `Items::*`) must stay backwards-compatible within a minor series.

## Versioning

- Follow SemVer.
  - Patch (`0.1.2 → 0.1.3`): bugfixes, internal refactors, lint/tooling and doc-only changes with no user-visible behavior shift.
  - Minor (`0.1.2 → 0.2.0`): new features, new options, new public APIs (pre-1.0 may also include breaking changes here, but call them out loudly).
  - Major (`0.1.2 → 1.0.0`+): breaking changes in stable releases.
- Every version bump must have a corresponding `## x.y.z (YYYY-MM-DD)` section in `CHANGELOG.md`, matching the existing format, describing the change from a user's perspective.
- After a release commit lands on `main`, tag it `vX.Y.Z` (matches the pattern set by `v0.1.1`, `v0.1.2`, ...) and push the tag: `git tag -a vX.Y.Z -m "vX.Y.Z" && git push origin vX.Y.Z`. Cut a matching GitHub release.

## Feature workflow

1. Understand the request; look for skills/brainstorming if it is non-trivial.
2. Write or update specs first when the change is testable — mirror the existing `spec/codex_sdk/*_spec.rb` layout.
3. Implement the change using existing patterns — mirror the style of neighboring files.
4. Run `bundle exec rspec` and `bundle exec rubocop`.
5. **Bump the version in `lib/codex_sdk/version.rb`.**
6. **Add a changelog entry in `CHANGELOG.md`** dated today, describing the change from a user's perspective.
7. Commit with a short imperative subject line (see recent `git log` for tone; Conventional Commit prefixes like `fix:`, `feat:`, `chore:` are in use).

## Ruby conventions

- Ruby `>= 3.2` (CI tests 3.2, 3.3, 3.4). Avoid syntax or APIs that require newer.
- Every Ruby file starts with `# frozen_string_literal: true`.
- Keep the SDK dependency-free at runtime — it shells out to the Codex CLI and parses JSONL with the stdlib. Do not add runtime dependencies without strong justification.
- Subprocess handling lives in `exec.rb`; keep process lifecycle (spawn, stream, graceful shutdown, interrupt) there rather than scattering it.
- Redact secrets (API keys) in any `inspect`/logging output — see existing redaction patterns.
- Follow the repo's RuboCop config (`.rubocop.yml`). Let RuboCop autocorrect formatting rather than hand-fighting it.

## Testing

- RSpec only; no Rails. Tests run against the real `lib/` code with the Codex CLI subprocess mocked/stubbed where needed.
- Add a focused spec for every new event type, item type, option, or parsing path.
- Both `rspec` and `rubocop` run in GitHub Actions on every push and PR — keep both green.

## Dependencies

- Add a new runtime dependency only when it is genuinely needed, and add it to `codex-ruby.gemspec` with a pessimistic version constraint (`~>`).
- Keep the gem slim — it is meant to be an unobtrusive client library.

## Things NOT to do

- Do not edit `Gemfile.lock` by hand; run `bundle install` instead.
- Do not hand-edit `.gem` files in the repo root or `pkg/`.
- Do not leave `binding.pry`, `byebug`, or `puts`-based debugging in committed code.
- Do not rename public APIs (`Client`, `AgentThread`, `Events::*`, `Items::*`) without a corresponding major/minor bump and a migration note.
- Do not re-enable `rubygems_mfa_required` in the gemspec — it was intentionally removed so releases can be pushed without MFA.

## Before declaring done

- [ ] Specs pass: `bundle exec rspec`
- [ ] Lint passes: `bundle exec rubocop`
- [ ] `lib/codex_sdk/version.rb` bumped
- [ ] `CHANGELOG.md` updated with today's date and a user-facing summary
- [ ] No stray debug output, commented-out code, or TODOs introduced
- [ ] When a release is cut, the matching `vX.Y.Z` git tag exists and has been pushed, and a GitHub release created
