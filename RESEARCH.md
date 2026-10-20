# Research Notes

Continuum is an engineering composition, not a reproduction of every paper below. This page records the research that informed its defaults and the limits of that evidence.

## Context management

### Context Language Models (CLM)

- **Paper:** *Context Language Models*
- **Authors:** Rulin Shao, Shannon Zejiang Shen, Junjie Oscar Yin, Yuetai Li, Minheng Wang, Hamish Ivison, Radha Poovendran, Nathan Lambert, Teng Xiao, Mike Lewis, Wen-tau Yih, Luke Zettlemoyer, Pang Wei Koh
- **Date:** 2026-09-29
- **arXiv:** <https://arxiv.org/abs/2609.37725>
- **Status:** preprint
- **Informed:** the core of Continuum’s context layer, `pi-clm`.

The paper treats context as a file the model can edit, rather than an append-only transcript. Reported results include:

- BrowseComp-Plus: 11.4% higher accuracy with 21.5% fewer prefix-reuse FLOPs than the strongest baseline.
- TerminalBench 2.1: matches the strongest baseline with 29.5% fewer FLOPs.
- EdgeBench 12-hour runs: 5% higher score with 59% fewer FLOPs.
- 24-hour multi-repository agent swarm: 65% greater downstream speedup at the same compute.
- Natural-language steering and evolved context-management skills improved held-out accuracy by up to 35.9 points.

Continuum uses that idea through `pi-clm`. The generic template uses a 256K budget and 32K reserve; DeepSeek-specific starting points are documented in [docs/CLM-DEEPSEEK.md](./CLM-DEEPSEEK.md), including a 272K/64K high-effort profile and a 384K/128K max-effort profile.

### The Missing Knowledge Layer

- **Paper:** *The Missing Knowledge Layer in Cognitive Architectures for AI Agents*
- **Author:** Michaël Roynard
- **Date:** 2026-04-13 (v2 2026-06-12)
- **arXiv:** <https://arxiv.org/abs/2604.11364>
- **Status:** position paper
- **Informed:** the separation between CLM working context, durable task state (`TASK.md`, `PLAN.md`, `VERDICT.json`), and the raw archived session. It argues that facts, experiences, and active inference need different persistence semantics, which is why Continuum does not collapse them into one memory store.

The paper argues that Knowledge, Memory, Wisdom, and Intelligence need different persistence semantics: indefinite supersession for facts, Ebbinghaus decay for experiences, evidence-gated revision, and ephemeral inference. It cites Mastra’s Observational Memory result (94.87% on LongMemEval) but also cites a community audit reporting problems with LoCoMo and LongMemEval, so Continuum treats that number as provisional rather than as proof.

### Contextual Agentic Memory is a Memo, Not True Memory

- **Authors:** Binyan Xu, Xilin Dai, Kehuan Zhang
- **Date:** 2026-04-30
- **arXiv:** <https://arxiv.org/abs/2604.27707>
- **Status:** position paper
- **Informed:** the decision to keep the raw Pi session and durable task state, rather than treating a vector store or summary as “memory.”

The paper argues that retrieval-based memory generalizes by similarity to stored cases and faces a composition ceiling; it also highlights persistent memory poisoning. Continuum therefore keeps append-only session history and day archives, and does not claim that RAG or a summary is true memory.

### MAGE: Memory as Execution State Management

- **Paper:** *Beyond Semantic Organization: Memory as Execution State Management for Long-Horizon Agents*
- **Authors:** Yaoqi Chen, Haibin Lai, Yuru Feng, Chuyu Han, Qianxi Zhang, Baotong Lu, Menghao Li, Xinjiang Wang, et al.
- **Date:** 2026-06-04
- **arXiv:** <https://arxiv.org/abs/2606.06090>
- **Status:** EMNLP 2026 Main
- **Informed:** the use of `TASK.md`, `PLAN.md`, `VERDICT.json`, and the active task path as durable execution state, not just semantic memory.

Reported result: +7.8–20.4 percentage points task success and 55.1% lower token consumption on MemoryArena versus baselines.

Continuum does not implement MAGE’s full tree machinery; it adopts the design principle that a long-horizon agent should reconstruct state from a structured active path.

## Agent topology and delegation

### BOAD: Hierarchical Software Engineering Agents

- **Paper:** *BOAD: Discovering Hierarchical Software Engineering Agents via Bandit Optimization*
- **Authors:** Iris Xu, Guangtao Zeng, Zexue He, Charles Jin, Aldo Pareja, Dan Gutfreund, Chuang Gan, Zhang-Wei Hong
- **Date:** 2025-12-29
- **arXiv:** <https://arxiv.org/abs/2512.23631>
- **Status:** ICLR 2026
- **Informed:** the small specialist tree: a lead plus scout, implementer, and verifier; not a wide agent swarm.

Reported result: 53.1% on SWE-bench Verified and 20.0% on SWE-bench-Live with a 36B model; top-2 discovered specialists beat top-3/4/5 teams.

### Inside the Scaffold

- **Paper:** *Inside the Scaffold: A Source-Code Taxonomy of Coding Agent Architectures*
- **Author:** Benjamin Rombaut
- **Date:** 2026-04-03 (v2 2026-04-10)
- **arXiv:** <https://arxiv.org/abs/2604.03515>
- **Status:** preprint
- **Informed:** the decision to keep Pi’s loop as the trunk and treat tree search as a specialist primitive rather than the default.

The taxonomy covers 13 open-source coding-agent scaffolds. It identifies five composable loop primitives — ReAct, generate-test-repair, plan-execute, multi-attempt retry, and tree search — and finds that 11 of 13 compose multiple primitives. Control strategies range from fixed pipelines to MCTS, but the common substrate is a loop with tools and context management. Continuum’s lead/scout/implementer/verifier roles are a small specialist tree layered on that loop, not a replacement for it.

### Decomposition Buys Integrity, Not Yield

- **Paper:** *Decomposition Buys Integrity, Not Yield*
- **Authors:** Rong He
- **Date:** 2026-09-15
- **arXiv:** <https://arxiv.org/abs/2609.17464>
- **Status:** preprint
- **Informed:** the default continuous session plus day snapshots, and the warning against deep agent trees as a discovery strategy.

The paper models a tree of agents and finds that depth reduces root-context exposure but not discovery yield; flat is optimal for yield, and only a small fraction of production sessions are worth delegating.

### When Sub-Agents Work in Parallel

- **Paper:** *When Sub-Agents Work in Parallel: The Promises and Pitfalls of Dynamic Concurrency in Long-Horizon Coding Tasks*
- **Authors:** Han Li, HanHaoNing Li, Ziqian Jiang, Yiling Lou
- **Date:** 2026-10-07
- **arXiv:** <https://arxiv.org/abs/2610.10263>
- **Status:** preprint
- **Informed:** no automatic “spawn everything” default; delegation is for complementary long-horizon work, not routine tasks.

Reported result: across 354 tasks and 2,124 executions, task-success effect ranged from −11.9 to +2.3 percentage points, while token use was 1.41–3.31× sequential. Long-horizon benchmarks gained up to 14.3 points; SWE-bench Verified showed no gain.

### AdaptOrch

- **Paper:** *AdaptOrch: Task-Adaptive Multi-Agent Orchestration in the Era of LLM Performance Convergence*
- **Authors:** Geunbin Yu
- **Date:** 2026-02-18
- **arXiv:** <https://arxiv.org/abs/2602.16873>
- **Status:** preprint
- **Informed:** the idea of choosing topology per task, rather than committing to a fixed deep tree.

Reported result: 12–23% relative improvement over static single-topology baselines across SWE-bench, GPQA, and HotpotQA. On SWE-bench, the router preferred hybrid topology 62% of the time, parallel 24%, and hierarchical only 14%.

### MS-Eval: Sub-Agent Delegation and Orchestration

- **Paper:** *MS-Eval: Benchmarking Sub-Agent Delegation and Orchestration in MCP-Intensive Working Scenarios*
- **Authors:** Bowen Ding, Qixin Wang, Lexing Ruan, Weiyi Lu, Qiwei Ge, Ruishan Fang, Tao Lin
- **Date:** 2026-10-16
- **arXiv:** <https://arxiv.org/abs/2610.22869>
- **Status:** preprint
- **Informed:** narrow specialist roles and the warning that unnecessary delegation is overhead.

The paper finds specialization is the best practical practice, but redundant delegation turns the extra cost into pure overhead.

### Deep Agentic Search

- **Paper:** *Deep Agentic Search for Repository-Level Code Question Answering: An Empirical Study*
- **Authors:** Amirkia Rafiei Oskooei, Bora Ilci, Alperen Kayim, Mehmet Egemen Uzun, Berat Can, Kaan Emre Kara, Ozan Orhan, Mehmet S. Aktas
- **Date:** 2026-08-02
- **arXiv:** <https://arxiv.org/abs/2608.01507>
- **Status:** preprint, under review
- **Informed:** the rule “do not use a scout subagent for indexed repository Q&A.”

Reported result: semantic search answered 65.2% correctly versus 46.2% for deep agentic search, at less than half the cost. 41.8% of subagent failures were at the planner-to-subagent handoff.

## Verification

### LLM-as-a-Verifier

- **Paper:** *LLM-as-a-Verifier: A General-Purpose Verification Framework*
- **Authors:** Jacky Kwok, Shulu Li, Pranav Atreya, Yuejiang Liu, Yixing Jiang, Chelsea Finn, Marco Pavone, Ion Stoica, et al.
- **Date:** 2026-07-06
- **arXiv:** <https://arxiv.org/abs/2607.05391>
- **Repo:** <https://github.com/llm-as-a-verifier/llm-as-a-verifier>
- **Status:** preprint
- **Informed:** DeepSeek for the verifier role, explicit acceptance criteria, and evidence-backed `VERDICT.json`.

Reported results:

- Terminal-Bench 4.0 best-of-3: 66.2% vs 63.1% Pass@1.
- Terminal-Bench 4.0 best-of-5: 69.2% vs 64.8%.
- Terminal-Bench 2.1 self-verification best-of-3: 86.5% vs 79.4%.
- Best-of-5: 88.0% vs 78.7%.

Continuum uses the principle, not the full logprob/tournament implementation. Deterministic tests remain the primary gate.

## Decision routing

### REFLEX with Jev

- **Paper:** *REFLEX with Jev for Efficient Selective Control in LLM Agents*
- **Authors:** Tiantong Wu and 1 other author
- **Date:** 2026-09-22
- **arXiv:** <https://arxiv.org/abs/2609.26532>
- **Status:** preprint
- **Informed:** why Continuum does not use a learned router by default; the verifier gate stays explicit and deterministic.

REFLEX uses Jev as a fast typed decision layer and calls a strong LLM when confidence is low or generation is required. On a frozen 100-task benchmark it reports 95% success with 72.7% fewer strong-model calls, with reductions across three fallback families. The paper also reports limited advantage over a cheap generative cascade on external BFCL and τ-style evaluations. Continuum therefore treats typed routing as an optional experiment, not a default component.

### Good Judgment, Bad Advice

- **Paper:** *Good Judgment, Bad Advice: Decision-Model Controllers Raise Agent Cost Without Improving Success*
- **Author:** Naman Vats
- **Date:** 2026-10-17
- **arXiv:** <https://arxiv.org/abs/2610.24649>
- **Status:** preprint
- **Informed:** the decision not to add a Jev-style controller to the lead loop.

In a pre-specified Terminal-Bench 2.1 study (21 tasks, 315 trials), a Jev controller raised cost per attempt by 19% at an identical 73.0% pass rate. It was cheaper than a small-LLM controller but 22% more expensive than a placebo, and it was poorly calibrated: its mean probability that a run was complete was 0.50 when 87% of those runs passed. The result is a warning that a typed decision layer is not automatically cheaper or better.

## Harness engineering

### AI Harness Engineering

- **Paper:** *AI Harness Engineering: A Runtime Substrate for Foundation-Model Software Agents*
- **Authors:** Hailin Zhong, Shengxin Zhu
- **Date:** 2026-05-13
- **arXiv:** <https://arxiv.org/abs/2605.13357>
- **Status:** preprint / position
- **Informed:** the ledger, task state, verification evidence, failure attribution, and auditable episode packaging.

### Code as Agent Harness

- **Paper:** *Code as Agent Harness*
- **Authors:** Xuying Ning, Katherine Tieu, Dongqi Fu, Tianxin Wei, Zihao Li, Yuanchen Bei, Jiaru Zou, Mengting Ai, et al.
- **Date:** 2026-05-18
- **arXiv:** <https://arxiv.org/abs/2605.18747>
- **Status:** survey preprint
- **Informed:** treating code, project layout, and executable checks as the substrate of the agent system.

### Meta-Harness

- **Paper:** *Meta-Harness: End-to-End Optimization of Model Harnesses*
- **Authors:** Yoonho Lee and 5 other authors
- **Date:** 2026-03-30
- **arXiv:** <https://arxiv.org/abs/2603.28052>
- **Status:** preprint
- **Informed:** the `toolsmith` workflow and the requirement to evaluate a capability before keeping it.

Meta-Harness searches over harness code with an agentic proposer that can inspect source, scores, and execution traces. Reported results: 7.7 points better with 4× fewer context tokens on online text classification; 4.7 points average gain on 200 IMO-level problems across five held-out models; and discovered harnesses that surpass the best hand-engineered baselines on TerminalBench-2. The lesson for Continuum is capability-level search with trace access, not a fixed mega-harness.

### PluginRSI

- **Paper:** *PluginRSI: Recursive Improvement of Agent Harnesses with Reusable Plugins*
- **Authors:** Yaorui Shi, Yuchun Miao, Yuxin Chen, Jiayuan Zhang, Yueqing Sun, Xierui Song, Xiang Wang, An Zhang
- **Date:** 2026-09-25
- **arXiv:** <https://arxiv.org/abs/2609.32423>
- **Status:** preprint
- **Informed:** project-local skills/extensions as reusable capabilities, and the need for a small acceptance test before adoption.

PluginRSI represents a harness as atomized plugins, improves them independently, accumulates them in a library, and recombines them. Reported results: 6–10 percentage points over Meta-Harness on SWE-bench Verified, and a 69% held-out resolve rate after two evolution steps with library reuse versus 65% without. This supports `toolsmith` and `PROJECT_SKILLS.md`, but only with evaluation; a plugin library without task-level checks is just accumulation.

### Grow the Harness, Not the Context

- **Paper:** *Grow the Harness, Not the Context: From Strategy-Free Scaffolds to Reusable Specialist Agents*
- **Authors:** Laizhen Li, Jiarui Li, Juanjuan Zhao, Kejiang Ye, Ye Li, Cheng-zhong Xu, Xitong Gao
- **Date:** 2026-09-22
- **arXiv:** <https://arxiv.org/abs/2609.26760>
- **Status:** preprint
- **Informed:** the `toolsmith` idea and project-local reusable capabilities.

### Harness-Delta Attribution

- **Paper:** *Harness-Delta Attribution: Dissecting Gains From Harness Evolution*
- **Authors:** Wenxuan Ding, Qin Lu, Changlong Yu, Sha Li, Shuowei Jin, Xin Liu, Zhenyu Shi, Greg Durrett
- **Date:** 2026-10-15
- **arXiv:** <https://arxiv.org/abs/2610.22466>
- **Status:** preprint
- **Informed:** the warning that harness gains can be overfitting or extra test-time compute, not general improvement.

The paper attributes an average of 54% of measured gains to overfitting and 14% to test-time scaling; gains often fail to transfer to held-out tasks.

## How Continuum applies this

| Continuum choice | Research basis | Implementation |
|---|---|---|
| Pi loop as the trunk | Inside the Scaffold; Decomposition Buys Integrity, Not Yield | Pi core loop; `AGENTS.md` required flow |
| Lead-only CLM | CLM; The Missing Knowledge Layer | `.pi/settings.json`, `CLM_STEERING.md`, `AGENTS.md` |
| Small specialist tree | BOAD; MS-Eval; When Sub-Agents Work in Parallel | `.pi/agents/`, delegation rules |
| Depth 2 and no auto-spawn | Decomposition; When Sub-Agents Work in Parallel | `AGENTS.md` |
| Independent verifier gate | LLM-as-a-Verifier | `verifier.md`, `VERDICT.json` |
| Project-local capabilities | Meta-Harness; PluginRSI; Grow the Harness, Not the Context | `toolsmith.md`, `PROJECT_SKILLS.md` |
| No Jev controller | REFLEX with Jev; Good Judgment, Bad Advice | `AGENTS.md`, `README.md` non-goals |
| No observational memory in the lead | The Missing Knowledge Layer; CLM | `AGENTS.md`, `README.md` non-goals |
| UTC-traceable archives | AI Harness Engineering | `extensions/continuum.ts`, `bin/continuum` |

## Deliberate non-goals

- No runtime topology router or auto-spawner in the base template. The lead decides delegation from `PLAN.md`; AdaptOrch is design inspiration, not a runtime dependency.
- No recursive specialist spawning. The default depth is 2, and a specialist needs lead approval to delegate further.
- No Jev-style decision controller. Deterministic checks and the read-only verifier are the stop/verify gate.
- No observational memory or second compaction manager in the lead. CLM is the only context manager.
- No parallel implementers without isolated worktrees. The default is one writer.
- No separate plugin library. Project-local `.pi/skills/` and `.pi/extensions/` are the library.

## Evidence caveats

- Several papers above are preprints. Continuum’s defaults are engineering choices informed by them, not proofs that Continuum itself replicates their results.
- The Meta-Harness, PluginRSI, REFLEX, and Jev-controller results are preprints; none evaluates Continuum or Pi directly. Treat them as design evidence, not product claims.
- The model and harness landscape changes quickly. Re-run `make test` and your own held-out tasks before relying on a new default.
- No paper guarantees “100% best results.” Continuum’s verification gate makes failure visible and recoverable; it does not eliminate model error.
