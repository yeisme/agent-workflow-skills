---
name: yeisme-skill-routing-governance
description: Use when selecting, combining, adding, removing, discovering, reviewing, or routing complex skills for a Yeisme or external project, especially when managing project profiles, syncing .agents/.claude runtimes, deciding active versus on-demand status, or guiding an agent to use the smallest compatible workflow and domain constraints.
---

# Yeisme Skill Routing Governance

Keep semantic routing in the agent and deterministic state changes in the portable Skill manager.

## Boundaries

- In the Yeisme monorepo, treat `.skills/yeisme/` as the project-owned source and `.skills/imported/` as the reviewed third-party source.
- In an external project, use the public `yeisme-agent-my-skills` checkout as source and let the manager write the server-local binding to `.skills/source.local`.
- Treat `.skills/profiles/root.txt` as the portable external-project declaration. Yeisme monorepo subprojects continue to use `.skills/profiles/targets/<owner>.txt` through the host adapter.
- Treat `.agents/skills/` and `.claude/skills/` as generated runtime copies. Never edit them as source.
- Do not recreate marketplace, route scoring, sets, telemetry, MCP, HTTP, or background services.
- Do not encode natural-language task understanding in shell. The agent reads descriptions and chooses.
- Do not install, activate, or promote every search match. Discovery is evidence, not approval.

## Routing Workflow

1. Read the nearest `AGENTS.md` and identify the code or document owner.
2. Classify the requested work as a primary workflow, a domain constraint, an independent audit, or ordinary work that needs no extra Skill.
3. Prefer a named or clearly triggered active skill.
4. If no active skill fits, search the source layer:

```bash
scripts/skills.sh search "<task terms>"
scripts/skills.sh resolve <skill-name>
```

5. Read every plausible candidate's complete `SKILL.md`, but do not load unrelated references or bulk-load the source inventory.
6. Select the smallest compatible combination: one primary workflow, at most one compatible domain constraint, and independent audit skills on separate read-only review work.
7. Reject combinations that assign two owners to the same state, attach two primary workflows, mix implementation and independent audit in one role, or let a domain Skill choose models, permissions, agents, or side effects.
8. Keep a Skill on demand unless it is required at session start, protects a high-frequency owner invariant, or repeated discovery misses justify promotion.
9. If promotion or demotion is justified, preview the profile change, apply it through the manager, then perform the narrowest sync and validation.

🔴 CHECKPOINT · 🛑 STOP：do not `profile add`/`remove` or sync until the current user authorized that assignment. Discovery is evidence, not approval. Abort sync when another writer is active or a runtime-only change cannot be explained.

Read [references/agent-routing-contract.md](references/agent-routing-contract.md) when three or more candidates match, ownership is ambiguous, or a workflow/domain/audit combination needs compatibility review.

## External Project Bootstrap

For the shortest AI drama setup, install the Router directly from its cloud repository:

```bash
npx --yes skills add https://github.com/yeisme/ai-drama-skills \
  --skill ai-drama-router \
  --yes
```

Use the aggregate checkout only when a project needs long-term source binding, profile management, dual runtimes, and validation.

From a public source checkout:

```bash
git clone --recurse-submodules https://github.com/yeisme/yeisme-agent-my-skills.git
cd yeisme-agent-my-skills
scripts/skills.sh --project /path/to/project init
```

`init` creates the portable root profile, records the local source checkout, activates this management Skill, synchronizes both runtime homes, and validates the result. Optional context or workflow Skills remain explicit profile choices. The source binding is local to each server; rerun `configure-source` after moving the checkout:

```bash
scripts/skills.sh --project /path/to/project configure-source
```

## Profile Management

For an external project managed from the public checkout:

```bash
scripts/skills.sh --project /path/to/project profile show
scripts/skills.sh --project /path/to/project --dry-run profile add <skill-name>
scripts/skills.sh --project /path/to/project profile add <skill-name>
scripts/skills.sh --project /path/to/project profile remove <skill-name>
scripts/skills.sh --project /path/to/project sync
scripts/skills.sh --project /path/to/project validate
```

The following commands are Yeisme monorepo host-adapter examples:

```bash
scripts/skills.sh profile show root
scripts/skills.sh profile show agent/ordo
scripts/skills.sh profile add agent/ordo <skill-name> --dry-run
scripts/skills.sh profile add agent/ordo <skill-name>
scripts/skills.sh profile remove agent/ordo <skill-name> --dry-run
scripts/skills.sh profile remove agent/ordo <skill-name>
scripts/skills.sh profile validate
```

Promote a skill only when it is required at session start, protects a high-frequency owner invariant, repeated discovery causes misses, or the nearest `AGENTS.md` declares it active. Demote release-only, audit-only, rare, superseded, or wrong-owner skills.

## Sync And Validation

Skill synchronization is a final-gate operation, not an implementation-loop
command. Assign one root sync owner and wait until all writers affecting
`.skills/yeisme/**`, `.skills/imported/**`, `.skills/profiles/**`,
`.agents/skills/**`, `.claude/skills/**`, or `scripts/skills.sh` have finished.
Freeze those paths before generation.

Before syncing, inspect the current source, profile, and runtime changes:

```bash
git status --short -- .skills/yeisme .skills/imported .skills/profiles .agents/skills .claude/skills scripts/skills.sh
git diff -- .skills/yeisme .skills/imported .skills/profiles scripts/skills.sh
```

Abort synchronization when a runtime-only change cannot be explained by its
source skill and profile, when another writer is active, or when ownership is
ambiguous. Never resolve a sync conflict by hand-editing `.agents/skills/` or
`.claude/skills/`; repair the source/profile state, then regenerate.

For an external project, run `sync` only after route selection and profile edits are stable:

```bash
scripts/skills.sh --project /path/to/project profile validate
scripts/skills.sh --project /path/to/project sync
scripts/skills.sh --project /path/to/project validate
```

The portable manager preserves runtime directories it did not previously manage. It fails instead of overwriting an unmanaged directory whose name conflicts with a profile Skill.

In the Yeisme monorepo host adapter, use the narrowest supported sync command. Run `sync-root` for root-only source
or profile changes. Run `sync-target <target>` for one affected subproject.
Run `sync-subprojects` only when multiple subproject assignments or shared
source skills genuinely require it.

```bash
scripts/skills.sh validate-custom
scripts/skills.sh validate-profiles
scripts/skills.sh sync-root
scripts/skills.sh sync-target <target>
scripts/skills.sh sync-subprojects
scripts/skills.sh validate-runtime
scripts/skills.sh validate-subprojects-runtime
```

Validation must fail on an unknown source, duplicate skill name, missing owner, profile/runtime drift, or different `.agents` and `.claude` contents.

## If this fails

| Trigger | First fix | Still failing |
| --- | --- | --- |
| Two primaries or two owners for one state | Keep one primary + at most one constraint | Do not activate the competing set |
| Search hit is not in the profile | Read the source SKILL.md on demand | Do not install every match |
| Runtime copy disagrees with source | Repair source/profile; regenerate | Do not hand-edit `.agents` / `.claude` |
| External skill requested | `import` from an explicit Git ref, then review the diff | Do not write third-party skills into `.skills/yeisme/` |

## External Skills

Import only from an explicit Git ref:

```bash
scripts/skills.sh import <repo-url> <ref> <module>
```

Review the Git diff before adding the skill to any profile. Do not write external skills into `.skills/yeisme/` and do not treat discovery as installation approval.

## Output

Report:

- selected primary workflow and why it owns the task;
- optional domain constraint and why it is compatible;
- independent audits, if any;
- active or on-demand status for every selected Skill;
- profile changes and the exact sync/validation commands used;
- rejected candidates and the ownership or compatibility reason;
- unresolved conflicts, missing source capabilities, and next action.
