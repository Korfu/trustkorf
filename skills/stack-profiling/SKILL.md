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

The script output may be incomplete. Validate the detected profile:

1. **Check detected commands exist:** Run `which <command>` or `command -v <command>` for each detected tool
2. **Read package manifests:** For Node.js, check `package.json` scripts for actual test/lint/build commands. For C#, check `.csproj` for test framework references. For Python, check `pyproject.toml` `[tool.pytest]` etc.
3. **Detect framework-specific patterns:**
   - Playwright/Cypress config files → set `e2eCommand` and `e2eFramework`
   - `angular.json` → Angular CLI commands (`ng test`, `ng build`, `ng lint`)
   - `next.config.*` → Next.js (`next build`, `next lint`)
   - `playwright.config.*` → Playwright e2e
   - `cypress.config.*` → Cypress e2e
4. **Check CI configuration:** `.github/workflows/*.yml`, `Makefile`, `Dockerfile` may reveal the actual commands used by the team

### Step 3: Produce Stack Profile

Output a structured profile. This is what continuous-validation and deployment-gate consume:

```
Stack Profile:
  language: <detected language>
  framework: <detected framework or "none">
  testCommand: <command to run tests>
  typeCheckCommand: <command for type checking, or "none">
  lintCommand: <command for linting, or "none">
  buildCommand: <command to build, or "none">
  e2eCommand: <command for e2e tests, or "none">
  e2eFramework: <playwright|cypress|none>
  packageManager: <npm|yarn|pnpm|pip|cargo|dotnet|maven|none>
```

### Step 4: Cache the Profile

Write the profile to `.trustkorf/profile.json` in the project root so subsequent validations don't re-detect:

```bash
mkdir -p .trustkorf
# Write profile JSON to .trustkorf/profile.json
```

Remind the developer to add `.trustkorf/` to their `.gitignore` if it's not already there.

## Handling Unknown or Mixed Stacks

**Monorepo detection:** If the root contains multiple sub-projects (e.g., `frontend/package.json` + `backend/go.mod`), detect each and produce a composite profile. Validation skills should scope checks to the sub-project where changes occurred.

**Unknown stack:** If no signal files are found, set all commands to "none" and report to the developer:
> "Could not auto-detect the tech stack. Please provide the test, lint, build, and type check commands for this project."

**Partial detection:** If some tools are detected but others aren't, fill in what you can and mark the rest as "none". Validation skills will skip categories with "none" and redistribute scoring weights.

## Reference

See `references/known-stacks.md` for the full detection matrix.
