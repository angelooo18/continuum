# CLM Steering Brief

You manage your own context through `pi-clm`. Keep the live context small, precise, and useful.

## Keep

- The original task and acceptance checks.
- User constraints and non-goals.
- Decisions and rationale.
- File paths and symbol names that matter.
- Failing tests, exact errors, and test commands.
- Open questions and unresolved risks.
- Evidence needed for verification.

## Offload

- Raw tool output and logs.
- Repeated file dumps.
- Large grep/find results.
- Old exploration that is no longer relevant.
- Superseded attempts, unless the failure mode matters.

## Maintain

- A terse task tracker with status and next action.
- A list of modified files.
- A list of verification commands and their outcomes.

## Editing rules

- Make the smallest possible edit.
- Do not rewrite unchanged blocks.
- Do not add explanatory prose to the context file.
- Preserve tool-call/tool-result pairs.
- Never delete the original task, acceptance checks, or security constraints.
- When compacting, keep evidence needed to prove the final change works.

## When to compact

Compact when the context is mostly stale tool output, not when key decisions exist only in the transcript.

## When to hand off

If the context is no longer trustworthy, or the task has changed substantially, stop and create a handoff brief instead of forcing more edits.
