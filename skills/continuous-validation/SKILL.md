---
name: continuous-validation
description: Use after completing implementation work, after a subagent reports back, or when claiming progress on a task - runs lightweight quality checks and computes an interim confidence score to catch issues early before the final deployment gate
---

# Continuous Validation

## Overview

Don't wait until the end to discover your code is broken. Continuous validation catches issues while the cost of fixing them is low.

**Core principle:** Validate early, validate often, fix fast.

## When This Runs

- After completing a logical implementation chunk
- After a subagent reports back with implementation results
- Before claiming progress on a task
- Claude auto-triggers this based on the description above — no manual invocation needed

## The Process

```
┌─────────────────────────────┐
│  Implementation chunk done   │
└──────────────┬──────────────┘
               ▼
┌─────────────────────────────┐
│  Load stack profile          │
│  (invoke stack-profiling     │
│   if not cached)             │
└──────────────┬──────────────┘
               ▼
┌─────────────────────────────┐
│  Identify changed files      │
│  git diff --name-only        │
└──────────────┬──────────────┘
               ▼
┌─────────────────────────────┐
│  Dispatch evidence-collector │
│  agent (mode: continuous)    │
└──────────────┬──────────────┘
               ▼
┌─────────────────────────────┐
│  Compute confidence score    │
└──────────────┬──────────────┘
               ▼
          Score ≥ 75?
          ╱         ╲
        YES          NO
         │            │
         ▼            ▼
┌──────────────┐ ┌─────────────────────┐
│ Report score │ │ Dispatch fix-advisor │
│ & continue   │ │ Apply fixes          │
└──────────────┘ │ Re-validate          │
                 │ (max 2 loops)        │
                 └──────────┬──────────┘
                            ▼
                      Still < 75?
                       ╱       ╲
                     YES        NO
                      │          │
                      ▼          ▼
              ┌──────────┐  ┌──────────┐
              │ FLAG to   │  │ Continue │
              │ developer │  │ work     │
              │ (soft)    │  └──────────┘
              └──────────┘
```

## Step-by-Step

### Step 1: Load Stack Profile

Check if `.trustkorf/profile.json` exists in the project root. If not, invoke the `trustkorf:stack-profiling` skill to detect and cache it.

Read the profile to determine which commands to run.

### Step 2: Identify Changed Files

```bash
git diff --name-only
git diff --cached --name-only
```

Combine both lists. These are the files that need validation.

### Step 3: Dispatch Evidence Collector

Dispatch the `evidence-collector` agent with:
- **mode:** `continuous`
- **stack profile:** the detected profile
- **changed files:** the list from Step 2

In continuous mode, the evidence-collector runs only:
- **Test command** (from stack profile)
- **Type check command** (from stack profile, if not "none")
- **Test coverage assessment** of changed files

### Step 4: Compute Confidence Score

Use the **continuous scoring model**:

| Category | Weight | How to Score |
|---|---|---|
| Tests passing | 0.50 | `(passed / total) × 100`. All pass = 100. |
| Type checks clean | 0.30 | Zero errors = 100. Any errors = 0. |
| Test coverage of changes | 0.20 | `(covered_changed_functions / total_changed_functions) × 100` |

**Composite score** = `Σ(weight × score)`

If a category is unavailable (e.g., no type checker configured), redistribute its weight proportionally among the remaining categories.

**Threshold: 75** (this is a soft gate)

### Step 5: Handle Results

**Score ≥ 75:** Report the score and continue work.

```
trustKORF Continuous Check: 87/100
  Tests: 100 (×0.50)  Type checks: 100 (×0.30)  Coverage: 60 (×0.20)
```

**Score < 75 (first attempt):**
1. Dispatch `fix-advisor` agent with the failure evidence
2. Apply the suggested fixes
3. Re-run evidence collection
4. Recompute score

**Score < 75 (second attempt):**
1. Dispatch `fix-advisor` again with updated context
2. Apply fixes
3. Re-validate one final time

**Score < 75 (after 2 fix loops):**
Flag to the developer — do NOT block:

```
⚠ trustKORF Continuous Check: 58/100 (below threshold of 75)
  Tests: 70 (×0.50)  Type checks: 0 (×0.30)  Coverage: 60 (×0.20)

  Remaining issues after 2 fix attempts:
  • 3 type errors in src/auth/handler.ts
  • 2 failing tests in auth.test.ts

  Continuing work, but these must be resolved before deployment gate.
```

## Key Rules

1. **This is a SOFT gate** — it flags issues but never blocks. The deployment-gate is the hard gate.
2. **Max 2 fix loops** — don't burn tokens endlessly. Flag and move on.
3. **Only run tests + type checks** — save lint, build, and e2e for the deployment gate.
4. **Don't re-validate unchanged code** — scope checks to changed files when possible.
5. **Report concisely** — one-line summary when passing, detailed report when flagging.

## Scoring Reference

See `references/scoring-model.md` for the full scoring model documentation including the deployment-gate weights.
