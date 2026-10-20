# Optional examples

These are **not loaded by default**. They are starting points for project-specific capabilities you can add when a project needs them.

## Researcher

Copy `agents/researcher.md` into `.pi/agents/` when you want a project-specific web/paper researcher. It expects `pi-web-access` in the child:

```bash
pi install npm:pi-web-access
```

The `pi-subagents` built-in `researcher` is also available; this file is for customization.

## Diagrammer

Copy `agents/diagrammer.md` into `.pi/agents/` when you want a diagram specialist. It writes Mermaid/Graphviz source and renders with local tools when available.

## Skills

Copy `skills/research-protocol` or `skills/diagramming` into `.pi/skills/` and select them in the relevant agent's `skills:` frontmatter.

The base template intentionally does not preload these. Use `toolsmith` or copy them per project when needed.
