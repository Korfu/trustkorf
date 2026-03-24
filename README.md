# trustKORF

Automated quality assurance for Claude Code. Install it and forget about it — trustKORF embeds itself into the development flow and ensures code changes are deployment-ready.

## What It Does

trustKORF provides evidence-based confidence scoring for your code changes. It detects your tech stack, runs the appropriate quality checks, computes a weighted confidence score, and blocks deployment if the score is too low.

**The goal:** End of chat = ready to deploy.

## How It Works

### Automatic Flow (No Manual Invocation Needed)

1. **Stack Detection** — On session start, trustKORF detects your tech stack (language, framework, test runner, linter, type checker, build tool, e2e framework)

2. **Continuous Validation** — After each implementation chunk, trustKORF runs lightweight checks (tests + type checks) and computes an interim confidence score. If issues are found, it loops with fix instructions.

3. **Deployment Gate** — Before any commit or PR, a comprehensive gate runs ALL checks (tests, types, lint, build, e2e), creates tests if coverage is insufficient, and blocks if the confidence score is below 90/100.

### Confidence Scoring

Evidence from multiple categories is weighted and combined into a composite score:

| Category | Continuous Weight | Deployment Weight |
|---|---|---|
| Tests passing | 0.50 | 0.25 |
| Type checks clean | 0.30 | 0.20 |
| Lint clean | — | 0.10 |
| Build succeeds | — | 0.20 |
| Test coverage | 0.20 | 0.15 |
| E2E passing | — | 0.10 |

- **Continuous threshold:** 75 (soft gate — flags issues)
- **Deployment threshold:** 90 (hard gate — blocks deployment)

### Escalation

When checks fail:
1. A fix-advisor agent analyzes the failures and produces fix instructions
2. Fixes are applied and checks re-run
3. After max attempts (2 for continuous, 3 for deployment), issues are escalated to the developer

## Supported Stacks

trustKORF auto-detects these stacks:

- **JavaScript/TypeScript** — jest, vitest, mocha, eslint, tsc, npm/yarn/pnpm/bun
- **Python** — pytest, mypy, pyright, ruff, flake8
- **Go** — go test, go vet, golangci-lint
- **Rust** — cargo test, cargo clippy, cargo build
- **C#/.NET** — dotnet test, dotnet format, dotnet build
- **Java** — Maven (mvn test), Gradle (gradlew test)
- **Ruby** — rspec, minitest, rubocop, sorbet
- **PHP** — phpunit, phpstan, php-cs-fixer
- **Elixir** — mix test, credo, dialyxir

Frameworks: Next.js, Angular, SvelteKit, Django, Rails, ASP.NET Core, and more.

E2E: Playwright, Cypress.

## Installation

Add trustKORF as a local plugin in Claude Code:

```bash
# From the trustkorf directory
claude plugins add ./path/to/trustkorf
```

Or add it to your `.claude/settings.json`:

```json
{
  "plugins": ["./path/to/trustkorf"]
}
```

## Manual Validation

Use the `/validate` command at any time to trigger a full quality check:

```
/validate
```

## Configuration

### .gitignore

Add `.trustkorf/` to your project's `.gitignore` — this directory caches stack profiles and validation evidence:

```
# trustKORF cache
.trustkorf/
```

## Plugin Structure

```
trustkorf/
├── .claude-plugin/plugin.json      # Plugin manifest
├── skills/
│   ├── stack-profiling/             # Tech stack detection
│   ├── continuous-validation/       # Lightweight ongoing checks
│   └── deployment-gate/             # Comprehensive final gate
├── agents/
│   ├── evidence-collector.md        # Runs checks, collects evidence
│   ├── test-writer.md               # Creates missing tests
│   └── fix-advisor.md               # Diagnoses and prescribes fixes
├── commands/
│   └── validate.md                  # /validate manual trigger
└── hooks/
    ├── hooks.json                   # Stop + SessionStart hooks
    └── scripts/
        ├── detect-stack.sh          # Stack detection script
        └── should-gate.sh           # Stop hook gate trigger
```
