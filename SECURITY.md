# Security

Continuum runs Pi extensions, project-local agents, and shell commands with your user permissions.

## Project trust

- Review `.pi/settings.json`, `.pi/agents/`, `.pi/skills/`, and `.pi/extensions/` before granting project trust.
- A project can execute code through extensions and can instruct the model to run shell commands.
- Do not open untrusted repositories with `--approve`.

## Secrets

- Never commit API keys, tokens, or `auth.json`.
- Use `/login`, environment variables, or a secret manager.
- `continuum new` merges `.agent/`, session, `auth.json`, and env-file rules
  into an existing `.gitignore` and creates a self-ignoring `.agent/.gitignore`.
  Verify with `git check-ignore .agent/active.json` before the first commit.
- If a key is exposed, revoke it immediately.

## CLM and model-editable context

`pi-clm` lets the model edit its own live context. That is powerful and risky:

- untrusted repository content can attempt prompt injection;
- the model can drop constraints if steered badly;
- keep permission gates and secrets out of context;
- review diffs and verification evidence before accepting work.

## Subagents

- Subagents run with the tools their agent definition allows.
- Core agents declare an empty `extensions:` list; background children do not load
  `pi-clm` or the Continuum ledger extension. The Continuum extension also
  ignores `PI_SUBAGENT_CHILD=1` sessions as a second guard.
- `verifier` is intended to be read-only, but tools such as `bash` can still write. Review the agent definition and use project trust carefully.
- Do not give a child broader tools than its task needs.
- Optional example agents may require ambient extensions; review them before
  copying them into `.pi/agents/`.

## Reporting

Open a private security report through the repository hosting provider rather than a public issue.
