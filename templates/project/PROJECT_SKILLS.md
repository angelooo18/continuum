# Project Skills and Extensions

Continuum keeps the base template small. Add capabilities per project, on demand, instead of baking every tool into the lead.

## When to create a skill

Create a project skill when the need is **instructions or procedure**, not a new executable tool. Examples:

- research protocol for this project,
- paper-reading checklist,
- diagram conventions,
- domain-specific review checklist,
- release or migration procedure.

Put it in:

```text
.pi/skills/<name>/SKILL.md
```

Use frontmatter:

```markdown
---
name: <lowercase-hyphen-name>
description: What it does and when to use it.
---
```

Then assign it only to the agent that needs it:

```yaml
skills: <name>
```

## When to create an extension

Create a project extension only when the need is **executable behavior**: a new tool, a hook, a provider, or a guard. Examples:

- a diagram renderer,
- a project-specific API client,
- a deterministic verifier,
- a policy gate.

Put it in:

```text
.pi/extensions/<name>.ts
```

Load it only in the agent that needs it. Do not load every extension into the lead.

## Rules

1. The lead gets orchestration, CLM, and verification gates — not every project tool.
2. Prefer a skill over an extension unless you need executable behavior.
3. Prefer a disposable specialist over adding a tool to the lead.
4. Every new extension must have:
   - a narrow purpose,
   - explicit tool permissions,
   - a failure mode that is safe,
   - a short test or smoke command,
   - a note on which agent loads it.
5. Never put secrets in a skill or extension. Use environment variables or Pi auth.
6. Review any project skill or extension before granting project trust.

## Capability acceptance

A skill or extension is not adopted just because it exists. Before it becomes part of the project:

1. Define the smallest representative task it should improve.
2. Run that task with the current baseline. Record pass/fail, token cost, and wall-clock time.
3. Run the same task with the new capability.
4. Keep it only if it improves a metric that matters, or materially reduces risk.
5. Record the result in `PLAN.md` or the project notes, and assign the capability only to the specialist that needs it.

If it adds complexity without a measured benefit, remove or disable it. Do not build a separate plugin library; the project's `.pi/skills/` and `.pi/extensions/` are the library. Do not add a capability to the lead unless it is an orchestration or verification gate.

## Suggested workflow

Ask the lead:

```text
Use toolsmith to create a project skill for <task>.
```

or:

```text
Use toolsmith to create a project extension that <behavior>.
```

The toolsmith creates the files, validates them, and returns the paths. The lead then assigns the skill/extension to the right specialist.
