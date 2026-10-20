# Credits

Continuum is a composition layer. It does not vendor the upstream packages below; it installs or loads them as separate Pi packages.

## Pi

- Project: <https://github.com/earendil-works/pi>
- Site: <https://pi.dev>
- Role: the agent harness, session format, extension API, and package system Continuum runs on.

## pi-clm

- Project: <https://github.com/lolipopshock/pi-clm>
- Paper: **Context Language Models** — <https://arxiv.org/abs/2609.37725>
- Authors: Rulin Shao, Shannon Zejiang Shen, Junjie Oscar Yin, Yuetai Li, Minheng Wang, Hamish Ivison, Radha Poovendran, Nathan Lambert, Teng Xiao, Mike Lewis, Wen-tau Yih, Luke Zettlemoyer, Pang Wei Koh
- Role: model-managed live context, context mirror, compaction, and recall.
- Continuum usage: the project template installs `npm:@lolipopshock/pi-clm@1.0.0` and provides a `CLM_STEERING.md` brief.

## pi-subagents

- Project: <https://github.com/nicobailon/pi-subagents>
- Role: foreground/background subagents, agent definitions, steering, supervisor messaging, workflows, and child-session artifacts.
- Continuum usage: the project template installs `npm:pi-subagents@0.79.1` and ships core agents for scout, implementer, verifier, and toolsmith.

## pi-web-access (optional)

- Project: <https://github.com/nicobailon/pi-web-access>
- Role: web search, fetch, source checking, and research tools for optional researcher agents.
- Continuum usage: not installed by default; add it per project when using the optional researcher example.

## tmux (optional)

- Project: <https://github.com/tmux/tmux>
- Role: instant attach/resume and single-writer project sessions.
- Continuum usage: optional. Without tmux, `continuum open` runs Pi directly.

## Research

See [RESEARCH.md](./RESEARCH.md) for the full research notes and citations.

## Research references

Continuum’s subagent policy is informed by:

- **BOAD: Discovering Hierarchical Software Engineering Agents via Bandit Optimization** — <https://arxiv.org/abs/2512.23631>
- **Decomposition Buys Integrity, Not Yield** — <https://arxiv.org/abs/2609.17464>
- **When Sub-Agents Work in Parallel** — <https://arxiv.org/abs/2610.10263>
- **MS-Eval** — <https://arxiv.org/abs/2610.22869>

These are references, not bundled code.
