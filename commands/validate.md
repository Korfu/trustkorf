---
name: validate
description: Manually trigger trustKORF quality validation - runs the full deployment gate with evidence-based confidence scoring
---

# /validate - Manual Quality Validation

Run the full trustKORF deployment gate on demand.

## What This Does

This command triggers the same comprehensive quality validation that runs automatically before commits and PRs. Use it when you want to check the confidence score at any point during development.

## Process

1. Invoke the `trustkorf:stack-profiling` skill if the stack profile is not yet cached
2. Invoke the `trustkorf:deployment-gate` skill with the full evidence collection suite
3. The deployment gate will:
   - Run all available checks (tests, types, lint, build, e2e)
   - Compute the confidence score
   - Create tests if coverage is insufficient
   - Loop with fixes if below threshold
   - Report the final result

## When to Use

- You want to check if the current state of the code would pass the deployment gate
- You've fixed issues flagged by continuous validation and want to verify
- You want a full quality report before deciding to commit
- The automatic deployment gate was skipped and you want to run it manually
