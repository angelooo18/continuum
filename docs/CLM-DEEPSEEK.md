# DeepSeek CLM Profiles

Two tested starting points for **DeepSeek V4.1 Flash** with `pi-clm`.

These are engineering profiles, not claims of a universal optimum. They are based on:

- **Context Language Models** — <https://arxiv.org/abs/2609.37725>
  - 32K for most coding/deep-research evaluations
  - 128K for 12-hour EdgeBench
  - 272K for the multi-repository Software World swarm
- **DeepSeek-V4.1-Flash technical report** / model card — <https://huggingface.co/deepseek-ai/DeepSeek-V4.1-Flash-1017>
  - 1M context, CSA2 + FP4 KV cache, ~890 bytes/token global KV
  - reasoning effort: `low=50`, `high=75`, `max=100`
  - 60–80 effort recovers most accuracy at less than half the max token budget
  - max effort lengthens trajectories by roughly 1.6–1.8× over high for marginal gains

## Profile A — everyday coding / high effort

Use this as the default for normal repo work, multi-file changes, and debugging.

```text
/clm config budget 272k
/clm config reserve 64k
/clm config reminders 50/75/90%
/clm config guard on
/clm config compaction auto
/clm config cap 10000:0.5
/clm config trailer on
/clm config one-tool off
/clm config steering /path/to/project/CLM_STEERING.md

model: deepseek/deepseek-flash
thinking: high
```

Why:

- **272K** matches the CLM paper’s multi-repository budget.
- **64K reserve** leaves about **208K of working context** while giving DeepSeek’s reasoning traces room.
- **high** maps to DeepSeek effort 75, inside the report’s 60–80 cost/quality sweet spot.
- **10K observation cap**, trailer, guard, and steering follow the CLM setup.

## Profile B — hard long-horizon work / max effort

Use this only for very difficult debugging, large migrations, or tasks where the extra reasoning is worth the cost.

```text
/clm config budget 384k
/clm config reserve 128k
/clm config reminders 50/75/90%
/clm config guard on
/clm config compaction auto
/clm config cap 10000:0.5
/clm config trailer on
/clm config one-tool off
/clm config steering /path/to/project/CLM_STEERING.md

model: deepseek/deepseek-flash
thinking: max
```

Why:

- **384K** gives more room for long reasoning and a large repo.
- **128K reserve** accounts for max-effort output growth.
- **max** is reserved for hard tasks because the report shows diminishing returns and 1.6–1.8× longer trajectories.

## Comparison

| Profile | Budget | Reserve | Working context | Thinking |
|---|---:|---:|---:|---|
| Continuum generic default | 256K | 32K | 224K | high |
| DeepSeek everyday | **272K** | **64K** | **208K** | high |
| DeepSeek max | **384K** | **128K** | **256K** | max |

The generic default is deliberately conservative and cross-model. For DeepSeek specifically, Profile A is the better default; Profile B is the escalation path.

## Notes

- `reserve` is generation/guard headroom, not a hard output cap. Too small a reserve can make CLM compact earlier than necessary.
- CLM edits invalidate the prefix cache. A 272K–384K budget is usually a better trade than defaulting to the full 1M window.
- `cap 10000:0.5` is the CLM paper’s observation-cap setting. Raise it to `20000:0.5` only if code-heavy work repeatedly re-reads the same large outputs.
- Keep `one-tool off` for normal Pi use. Turn it on only to reproduce the paper harness’s one-command-per-turn behavior.
- Use `/clm status` to confirm the resolved budget and reserve.
