# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

trustKORF is a Claude Code plugin that provides automated quality assurance. It embeds into the development flow via hooks and skills, detects the project's tech stack, runs quality checks (tests, types, lint, build, e2e), computes a weighted confidence score, and blocks deployment when confidence is below threshold.

**Core principle:** End of chat = ready to deploy. Confidence is earned through evidence, not assumed.

## Architecture

The plugin has three layers that work together:

### Hooks (automatic triggers)
- `hooks/scripts/detect-stack.sh` — runs on **SessionStart**, outputs JSON with detected language, framework, test/lint/build/e2e commands, test config file, and package manager. Uses file-based signal detection (package.json, tsconfig.json, *.csproj, go.mod, etc.)
- `hooks/scripts/should-gate.sh` — runs on **Stop**, checks for uncommitted code file changes (filtered by extension: .ts, .js, .py, .cs, .go, .rs, etc.). Emits an `allow` decision with a reminder to run the deployment gate. Does NOT block to avoid infinite hook loops.

### Skills (Claude-executed workflows)
- `skills/stack-profiling/` — enriches the raw detection with scope analysis: reads test runner configs, finds test files outside configured scope, adjusts commands, detects duplicates (e.g. lint already includes tsc)
- `skills/continuous-validation/` — lightweight mid-work checks (tests + types only). Soft gate at 75/100. Max 2 fix loops.
- `skills/deployment-gate/` — comprehensive pre-commit gate (tests + types + lint + build + e2e + coverage). Hard gate at 90/100. Max 3 fix loops. Creates tests if coverage < 80%.

### Agents (dispatched by skills)
- `agents/evidence-collector.md` (haiku) — mechanical: runs commands, captures output, reports structured evidence. Two modes: `continuous` (tests + types) and `full` (all checks).
- `agents/test-writer.md` (sonnet) — studies existing test conventions, writes targeted tests for uncovered changed functions, verifies they pass.
- `agents/fix-advisor.md` (sonnet) — analyzes failure evidence, diagnoses root causes, produces specific fix instructions with file/line/code. Tries different approaches on subsequent attempts.

## Scoring Model

Defined in `skills/continuous-validation/references/scoring-model.md`. Key rules:
- Missing categories have weight redistributed proportionally
- Compiled languages (C#, Go, Rust, Java): build covers type safety, so missing typeCheckCommand is not a gap
- Zero changed functions → coverage = 100 (nothing to cover)
- Zero tests → coverage = 0 AND tests = 0 (no tests is never "all pass")

## Key Files

- `hooks/hooks.json` — declares which hooks fire and their timeouts (Stop: 10s, SessionStart: 15s)
- `skills/stack-profiling/references/known-stacks.md` — signal file matrix, framework detection, test runner config files, CI detection, package managers
- `tests/test-scenarios.yaml` — regression test definitions with expected outcomes (true positives, false positive checks, hook robustness, stack detection)
- `.claude-plugin/plugin.json` — plugin manifest (name, version, description)
- `.claude-plugin/marketplace.json` — local marketplace definition

## Testing the Plugin

No automated test runner — tests are manual. Use `tests/test-scenarios.yaml` as the spec:

```bash
# Test stack detection on any project
CLAUDE_PROJECT_DIR=/path/to/project bash hooks/scripts/detect-stack.sh

# Test stop hook (needs git repo with code changes)
CLAUDE_PROJECT_DIR=/path/to/project bash hooks/scripts/should-gate.sh

# Validate JSON output
CLAUDE_PROJECT_DIR=/path/to/project bash hooks/scripts/detect-stack.sh | jq .
```

## When Modifying This Plugin

- `detect-stack.sh` must always output valid JSON, even on errors or unknown directories
- `should-gate.sh` must never use `"decision": "block"` — this causes infinite Stop-hook loops
- The CODE_EXT filter in `should-gate.sh` must match across all three change types (staged, unstaged, untracked)
- After changes, test against: a TS project, a C# project, a parent/workspace directory, and a non-git directory
