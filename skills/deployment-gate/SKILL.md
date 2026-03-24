---
name: deployment-gate
description: Use before committing code, creating a pull request, claiming work is complete, or finishing a development branch - runs comprehensive quality validation with evidence-based confidence scoring and blocks deployment if the confidence threshold is not met
---

# Deployment Gate

## Overview

Nothing ships without evidence it works. The deployment gate is the final checkpoint between code and production — a hard gate that blocks until confidence is earned.

**Core principle:** No deployment without proof. Confidence is earned, not assumed.

<HARD-GATE>
Do NOT skip, shortcut, or weaken the deployment gate. If the score is below 90, the change does NOT proceed. No exceptions. No "it's just a small change." No "tests are slow." Run the checks, read the evidence, respect the threshold.
</HARD-GATE>

## When This Runs

- Before any `git commit`
- Before creating a pull request
- Before claiming work is complete
- Before finishing a development branch
- Triggered automatically by the Stop hook when uncommitted changes exist
- Manually via `/validate` command

## The Process

```
┌──────────────────────────────┐
│  About to commit/PR/finish   │
└───────────────┬──────────────┘
                ▼
┌──────────────────────────────┐
│  Load stack profile           │
└───────────────┬──────────────┘
                ▼
┌──────────────────────────────┐
│  Identify ALL changed files   │
│  since branch divergence      │
└───────────────┬──────────────┘
                ▼
┌──────────────────────────────┐
│  Dispatch evidence-collector  │
│  agent (mode: full)           │
└───────────────┬──────────────┘
                ▼
        Coverage < 80%?
         ╱          ╲
       YES           NO
        │             │
        ▼             │
┌─────────────────┐   │
│ Dispatch         │   │
│ test-writer      │   │
│ agent            │   │
│ Re-collect       │   │
│ evidence         │   │
└────────┬────────┘   │
         └─────┬──────┘
               ▼
┌──────────────────────────────┐
│  Compute confidence score     │
│  (full mode, threshold: 90)   │
└───────────────┬──────────────┘
               ▼
          Score ≥ 90?
          ╱         ╲
        YES          NO
         │            │
         ▼            ▼
┌──────────────┐ ┌─────────────────────┐
│ APPROVE      │ │ Dispatch fix-advisor │
│ Show report  │ │ Apply fixes          │
│ Proceed      │ │ Re-validate          │
└──────────────┘ │ (max 3 total loops)  │
                 └──────────┬──────────┘
                            ▼
                   Still < 90 after 3?
                       ╱       ╲
                     YES        NO
                      │          │
                      ▼          ▼
              ┌─────────────┐  ┌──────────┐
              │ BLOCK        │  │ APPROVE  │
              │ Full report  │  │ Proceed  │
              │ Escalate to  │  └──────────┘
              │ developer    │
              └─────────────┘
```

## Step-by-Step

### Step 1: Load Stack Profile

Read `.trustkorf/profile.json`. If missing, invoke `trustkorf:stack-profiling` first.

### Step 2: Identify Changed Files

Determine all files changed in the current work:

```bash
# If on a feature branch
git diff main...HEAD --name-only 2>/dev/null || git diff HEAD~5 --name-only

# Also include uncommitted changes
git diff --name-only
git diff --cached --name-only
```

Combine all lists, deduplicate.

### Step 3: Dispatch Evidence Collector (Full Mode)

Dispatch the `evidence-collector` agent with:
- **mode:** `full`
- **stack profile:** the detected profile
- **changed files:** the comprehensive list from Step 2

In full mode, the evidence-collector runs ALL available checks:
- Test command
- Type check command
- Lint command
- Build command
- E2E command (if configured)
- Test coverage assessment

### Step 4: Assess Test Coverage

If the evidence shows test coverage of changed functions < 80%:

1. Dispatch the `test-writer` agent with:
   - List of uncovered changed functions/files
   - Stack profile (for test framework conventions)
   - Existing test file examples (for pattern matching)
2. Wait for test-writer to create tests
3. Re-dispatch evidence-collector to get updated evidence

### Step 5: Compute Final Confidence Score

Use the **full scoring model** (see `continuous-validation/references/scoring-model.md`):

| Category | Weight | Score |
|---|---|---|
| Tests passing | 0.25 | `(passed / total) × 100` |
| Type checks clean | 0.20 | 0 errors = 100, else 0 |
| Lint clean | 0.10 | 0 errors = 100 (warnings OK) |
| Build succeeds | 0.20 | exit 0 = 100, else 0 |
| Test coverage | 0.15 | `(covered / changed) × 100` |
| E2E passing | 0.10 | `(passed / total) × 100` |

Unavailable categories have their weight redistributed proportionally.

**Threshold: 90**

### Step 6: Handle Results

#### APPROVE (Score ≥ 90)

Present the confidence report and proceed:

```
╔══════════════════════════════════════╗
║  trustKORF Deployment Gate: PASSED   ║
║  Confidence Score: 94/100            ║
╠══════════════════════════════════════╣
║  Tests passing:      100  (×0.25)    ║
║  Type checks:        100  (×0.20)    ║
║  Lint clean:         100  (×0.10)    ║
║  Build succeeds:     100  (×0.20)    ║
║  Test coverage:       80  (×0.15)    ║
║  E2E passing:         90  (×0.10)    ║
╚══════════════════════════════════════╝
```

#### FIX LOOP (Score < 90, attempts remaining)

1. Dispatch `fix-advisor` agent with:
   - All failed check evidence (stdout, stderr, exit codes)
   - Changed files list
   - Stack profile
2. Apply the recommended fixes
3. Re-dispatch evidence-collector (full mode)
4. Recompute score
5. Track attempt count

**Maximum 3 total attempts** (initial + 2 fix loops).

#### BLOCK (Score < 90 after 3 attempts)

Present the full evidence report and escalate:

```
╔══════════════════════════════════════╗
║  trustKORF Deployment Gate: BLOCKED  ║
║  Confidence Score: 62/100            ║
║  Threshold: 90 | Attempts: 3/3       ║
╠══════════════════════════════════════╣
║  Tests passing:       70  (×0.25)  ⚠ ║
║  Type checks:          0  (×0.20)  ✗ ║
║  Lint clean:         100  (×0.10)  ✓ ║
║  Build succeeds:     100  (×0.20)  ✓ ║
║  Test coverage:       60  (×0.15)  ⚠ ║
║  E2E passing:        N/A  (skip)     ║
╠══════════════════════════════════════╣
║  REMAINING FAILURES:                 ║
║  • 3 type errors in src/auth.ts      ║
║  • 2 tests failing in auth.test.ts   ║
║  • 2 changed functions lack tests    ║
║                                      ║
║  Human intervention required.        ║
║  Fix the above issues and run        ║
║  /validate to re-check.              ║
╚══════════════════════════════════════╝
```

Do NOT proceed with commit or PR. The developer must address the remaining issues.

## Key Rules

1. **This is a HARD gate** — nothing passes below 90. No exceptions.
2. **Max 3 attempts** — initial run + 2 fix loops. Then escalate.
3. **Full check suite** — tests, types, lint, build, e2e. All of them.
4. **Test creation is proactive** — if coverage is low, write tests before scoring.
5. **Evidence in every report** — always show what was checked and what the scores are.
6. **Never claim "ready to deploy" without a passing gate** — if this gate hasn't run, the code isn't ready.

## Integration with Stop Hook

The `should-gate.sh` Stop hook checks for uncommitted changes. If changes exist, it injects a system message instructing Claude to run the deployment gate before stopping. This ensures the gate fires even if Claude "forgets" to invoke it.

The hook is a safety net — the skill description should trigger it naturally in most cases, and the hook catches the rest.
