---
name: verification
description: Evidence-based verification procedure for checking a change against acceptance criteria, tests, regressions, and unresolved risks. Use when reviewing a diff or deciding whether work is done.
---

# Verification

1. Read `TASK.md` and list every acceptance check.
2. Read the diff and the changed files.
3. Run the relevant tests, lint, typecheck, and build commands.
4. Check for:
   - regressions,
   - missing edge cases,
   - unrelated changes,
   - silent failures,
   - missing evidence.
5. For each acceptance check, record:
   - `PASS`, `FAIL`, or `UNVERIFIED`,
   - the exact evidence (command, output, file:line).
6. Write `VERDICT.json` with an overall verdict and residual risks.
7. Never mark a check `PASS` without evidence.
8. A green test suite is necessary but not sufficient; acceptance checks still need evidence.
