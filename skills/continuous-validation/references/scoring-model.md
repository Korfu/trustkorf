# trustKORF Confidence Scoring Model

## Overview

Evidence-based confidence scoring collects measurable evidence from multiple quality categories, scores each 0-100, applies weights, and produces a composite score. The score must meet a threshold to pass.

## Two Modes

### Continuous Mode (Lightweight)

Used during implementation for early issue detection.

| Category | Weight | Scoring |
|---|---|---|
| Tests passing | 0.50 | `(passed_tests / total_tests) × 100` |
| Type checks clean | 0.30 | Zero errors = 100, any errors = 0 |
| Test coverage of changes | 0.20 | `(covered_functions / changed_functions) × 100` |

**Threshold: 75** | Soft gate (flags, doesn't block)

### Full Mode (Comprehensive)

Used by the deployment gate before commit/PR.

| Category | Weight | Scoring |
|---|---|---|
| Tests passing | 0.25 | `(passed_tests / total_tests) × 100` |
| Type checks clean | 0.20 | Zero errors = 100, any errors = 0 |
| Lint clean | 0.10 | Zero errors = 100 (warnings are OK) |
| Build succeeds | 0.20 | Exit code 0 = 100, non-zero = 0 |
| Test coverage of changes | 0.15 | `(covered_functions / changed_functions) × 100` |
| E2E passing | 0.10 | `(passed_e2e / total_e2e) × 100` |

**Threshold: 90** | Hard gate (blocks deployment)

## Score Computation

```
composite_score = Σ(weight_i × score_i) for all available categories
```

### Handling Missing Categories

When a category is unavailable (e.g., no type checker, no e2e framework, no linter configured):

1. Remove the unavailable category
2. Sum the remaining weights
3. Redistribute proportionally: `adjusted_weight_i = weight_i / sum_of_remaining_weights`

**Example:** No e2e configured in full mode:
- E2E weight (0.10) is removed
- Remaining weights sum: 0.90
- Tests adjusted: 0.25 / 0.90 = 0.278
- Type checks adjusted: 0.20 / 0.90 = 0.222
- Lint adjusted: 0.10 / 0.90 = 0.111
- Build adjusted: 0.20 / 0.90 = 0.222
- Coverage adjusted: 0.15 / 0.90 = 0.167

### Compiled Languages: Build Covers Type Safety

For compiled languages (C#, Go, Rust, Java), the build IS the type check. When `typeCheckCommand` is `"none"` and a `buildCommand` exists, the type check weight is redistributed normally — a passing build already proves type safety. Don't flag the missing type checker as a gap.

### Handling No Tests

If no test command is configured or no tests exist:
- Tests passing score = 0
- Test coverage score = 0
- This will heavily penalize the composite score
- The test-writer agent should be dispatched to create tests

## Category Scoring Details

### Tests Passing

**Input:** Test command output (exit code + stdout/stderr)
**Parse:** Extract passed/failed/total counts from test runner output
**Score:** `(passed / total) × 100`
**Zero tests:** Score = 0 (not 100 — having no tests is not "all tests pass")

### Type Checks Clean

**Input:** Type checker output (exit code + stderr)
**Parse:** Count error lines
**Score:** Binary — 0 errors = 100, any errors = 0
**No type checker:** Category skipped, weight redistributed

### Lint Clean

**Input:** Linter output (exit code + stdout)
**Parse:** Count errors (ignore warnings)
**Score:** Binary — 0 errors = 100, any errors = 0
**No linter:** Category skipped, weight redistributed

### Build Succeeds

**Input:** Build command output (exit code)
**Score:** Binary — exit 0 = 100, non-zero = 0
**No build command:** Category skipped, weight redistributed

### Test Coverage of Changes

**Input:** List of changed files + list of test files
**Method:**
1. Identify changed/new functions in changed files
2. Check if corresponding test files exist (using naming conventions: `foo.ts` → `foo.test.ts`, `foo.spec.ts`, `test_foo.py`, `FooTest.cs`, etc.)
3. Check if test files contain tests that reference the changed functions
**Score:** `(functions_with_tests / total_changed_functions) × 100`

### E2E Passing

**Input:** E2E runner output (exit code + stdout)
**Parse:** Extract passed/failed/total from runner output
**Score:** `(passed / total) × 100`
**No e2e configured:** Category skipped, weight redistributed

## Report Formats

### Passing (One-line)

```
trustKORF [Continuous|Deployment Gate]: SCORE/100
  Category1: SCORE (×WEIGHT)  Category2: SCORE (×WEIGHT)  ...
```

### Failing (Detailed)

```
╔══════════════════════════════════════╗
║  trustKORF [Mode]: [PASSED|BLOCKED]  ║
║  Confidence Score: SCORE/100         ║
║  Threshold: THRESHOLD                ║
╠══════════════════════════════════════╣
║  Tests passing:     SCORE  (×WEIGHT) ║
║  Type checks:       SCORE  (×WEIGHT) ║
║  Lint clean:        SCORE  (×WEIGHT) ║
║  Build succeeds:    SCORE  (×WEIGHT) ║
║  Test coverage:     SCORE  (×WEIGHT) ║
║  E2E passing:       SCORE  (×WEIGHT) ║
╠══════════════════════════════════════╣
║  ISSUES:                             ║
║  • Issue description 1               ║
║  • Issue description 2               ║
╚══════════════════════════════════════╝
```
