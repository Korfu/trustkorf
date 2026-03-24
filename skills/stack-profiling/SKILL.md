---
name: stack-profiling
description: Use when starting work in a new project, when the tech stack is unknown, or when continuous-validation or deployment-gate need stack information to determine which checks to run - detects language, framework, test runner, linter, type checker, build tool, and e2e framework
---

# Stack Profiling

## Overview

Before you can validate code, you need to know what you're validating. Stack profiling detects the project's technology stack and produces a structured profile that drives all downstream validation.

**Core principle:** Detect once, validate many times.

## When This Runs

- Automatically at session start (via SessionStart hook running `detect-stack.sh`)
- On first invocation of continuous-validation or deployment-gate if no cached profile exists
- When the developer switches to a different project directory

## The Process

### Step 1: Run Automated Detection

The `detect-stack.sh` hook script performs deterministic detection by checking for signal files. If it ran at session start, the output is already available.

If not available, run it manually:
```bash
bash "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/detect-stack.sh"
```

### Step 2: Validate and Enrich

The script output may be incomplete or misleading. The detected `testCommand` might work but only cover a subset of test files due to runner config restrictions. Validate and correct the full profile:

#### 2a. Check Detected Commands Exist

Run `which <command>` or `command -v <command>` for each detected tool.

#### 2b. Read Package Manifests

For Node.js, check `package.json` scripts for actual test/lint/build commands. For C#, check `.csproj` for test framework references. For Python, check `pyproject.toml` `[tool.pytest]` etc.

#### 2c. Analyze Test Runner Scope

**This is critical.** A test command can succeed while silently ignoring test files. The detected `testConfigFile` field tells you where to look, but even when it's `"none"` there may be implicit restrictions.

**Goal:** Ensure `testCommand` runs ALL test files in the project — unit, integration, and eval. If that's not possible with a single command, split into `testCommand` (unit/integration) and note the constraint.

**Generic process — apply to any runner:**

1. **Determine the runner's file discovery rules:**
   - If `testConfigFile` points to a config file, read it and look for include/exclude/match patterns
   - If `testConfigFile` is `"none"`, check for implicit defaults:

   | Runner | Default include pattern | Where overrides live |
   |---|---|---|
   | vitest | `**/*.{test,spec}.?(c\|m)[jt]s?(x)` | `vitest.config.*`, `vite.config.*` → `test.include` |
   | jest | `**/__tests__/**/*.[jt]s?(x)`, `**/?(*.)+(spec\|test).[jt]s?(x)` | `jest.config.*`, `package.json:jest` → `testMatch`, `testPathPattern`, `roots` |
   | pytest | `test_*.py`, `*_test.py` in `testpaths` or project root | `pyproject.toml:[tool.pytest.ini_options]`, `pytest.ini`, `setup.cfg` → `testpaths` |
   | go test | `*_test.go` in specified packages | `./...` covers all — but check if command uses a narrower package path |
   | dotnet test | Test projects referenced by solution | `.sln` file or explicit `--project` flag |
   | rspec | `spec/**/*_spec.rb` | `.rspec`, `spec/spec_helper.rb` |
   | cargo test | `#[cfg(test)]` modules + `tests/` dir | `Cargo.toml` `[[test]]` sections |
   | vitest (workspace) | Per-workspace config | `vitest.workspace.ts` |

2. **Find all test files that actually exist in the project:**
   ```bash
   # Adapt the pattern to the detected language
   # TypeScript/JavaScript:
   find . -type f \( -name "*.test.ts" -o -name "*.spec.ts" -o -name "*.test.js" -o -name "*.spec.js" \) -not -path "*/node_modules/*" -not -path "*/dist/*"
   # Python:
   find . -type f \( -name "test_*.py" -o -name "*_test.py" \) -not -path "*/.venv/*"
   # Go:
   find . -type f -name "*_test.go" -not -path "*/vendor/*"
   ```

3. **Compare actual test files against the runner's scope.** If test files exist in directories the runner won't reach:
   - **Preferred fix:** Adjust `testCommand` to cover all directories. Use runner-specific flags:
     - vitest: `npx vitest run --dir . --config vitest.config.ts` or create a config that broadens `include`
     - jest: `npx jest --roots='<rootDir>/src' --roots='<rootDir>/eval'`
     - pytest: `pytest src/ tests/ eval/`
     - go: ensure `./...` not a narrower path
     - dotnet: ensure solution includes all test projects
   - **If the runner has no way to broaden scope without a config change,** note the limitation in the profile and set `testCommand` to the best available option

4. **Verify the adjusted command works:**
   ```bash
   <adjusted testCommand> --dry-run  # or equivalent for the runner
   # If no dry-run available, just run it and check it discovers the expected files
   ```

5. **Handle split test suites:** Some projects intentionally separate unit tests from integration/eval tests (different env requirements, external dependencies, speed). When you detect this:
   - Set `testCommand` to run unit tests (fast, no external deps)
   - Note integration/eval commands in profile comments — the evidence-collector can run both

#### 2d. Detect Framework-Specific Patterns

- Playwright/Cypress config files → set `e2eCommand` and `e2eFramework`
- `angular.json` → Angular CLI commands (`ng test`, `ng build`, `ng lint`)
- `next.config.*` → Next.js (`next build`, `next lint`)
- `playwright.config.*` → Playwright e2e
- `cypress.config.*` → Cypress e2e

#### 2e. Check CI Configuration

`.github/workflows/*.yml`, `Makefile`, `Dockerfile` may reveal the actual commands used by the team. CI configs are often the source of truth — if CI runs a different test command than what you detected, prefer the CI version.

### Step 3: Produce Stack Profile

Output a structured profile. This is what continuous-validation and deployment-gate consume:

```
Stack Profile:
  language: <detected language>
  framework: <detected framework or "none">
  testCommand: <command to run ALL tests — adjusted after scope analysis>
  testConfigFile: <path to test runner config, or "none">
  testScopeNotes: <any notes about split suites or scope limitations, or "none">
  typeCheckCommand: <command for type checking, or "none">
  lintCommand: <command for linting, or "none">
  buildCommand: <command to build, or "none">
  e2eCommand: <command for e2e tests, or "none">
  e2eFramework: <playwright|cypress|none>
  packageManager: <npm|yarn|pnpm|pip|cargo|dotnet|maven|none>
```

**Important:** `testCommand` must be the result of the scope analysis from Step 2c, not just the raw detected command. If the raw command misses test files, it must be adjusted here.

### Step 4: Cache the Profile

Write the profile to `.trustkorf/profile.json` in the project root so subsequent validations don't re-detect:

```bash
mkdir -p .trustkorf
# Write profile JSON to .trustkorf/profile.json
# Include all fields: language, framework, testCommand, testConfigFile,
# testScopeNotes, typeCheckCommand, lintCommand, buildCommand,
# e2eCommand, e2eFramework, packageManager
```

Remind the developer to add `.trustkorf/` to their `.gitignore` if it's not already there.

## Handling Unknown or Mixed Stacks

**Monorepo detection:** If the root contains multiple sub-projects (e.g., `frontend/package.json` + `backend/go.mod`), detect each and produce a composite profile. Validation skills should scope checks to the sub-project where changes occurred.

**Unknown stack:** If no signal files are found, set all commands to "none" and report to the developer:
> "Could not auto-detect the tech stack. Please provide the test, lint, build, and type check commands for this project."

**Partial detection:** If some tools are detected but others aren't, fill in what you can and mark the rest as "none". Validation skills will skip categories with "none" and redistribute scoring weights.

## Reference

See `references/known-stacks.md` for the full detection matrix.
