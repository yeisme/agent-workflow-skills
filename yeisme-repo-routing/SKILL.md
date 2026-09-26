---
name: yeisme-repo-routing
description: Use when deciding whether a proposed capability fits a Yeisme project, whether it needs split ownership, and where product surfaces, clients, services, files, workflows, skills, MCP code, CLI entrypoints, agent assets, gateway assets, or documentation should live.
---

# Yeisme Repo Routing

Use this skill when a capability is first proposed, when the user wants to merge multiple experiences into one product, or when the correct owner and repository location are unclear.

## Capability Admission Gate

Run this gate before PRD, OpenSpec, CEO review, or implementation:

1. Capture every capability the user explicitly requires in a required-capability ledger. Do not reinterpret a required capability as optional merely because delivery will be staged.
2. Classify the proposal immediately:
   - `fit`: the proposed project owns the capability's canonical state, rules, permissions, evidence, and lifecycle.
   - `split-owner`: one project owns the domain capability while another approved client or control plane composes its visual interaction, navigation, and safe actions through typed contracts.
   - `reject-now`: the capability should not be built as proposed because it violates a hard product, safety, legal, permission, or repository boundary. State this immediately, with the reason and the nearest viable alternative.
3. If the proposed project is the wrong owner, say so now. Name the correct owner, consumer, contract boundary, and how the requested user experience remains available.
4. Treat “merge into one project”, “one workspace”, and “one console” as experience composition by default. They do not authorize feature deletion, canonical-state migration, or copied domain state machines.
5. Carry the admission decision and required-capability ledger into later PRD, CEO, architecture, engineering, design, and OpenSpec work. Do not wait until the spec is complete to raise a known ownership mismatch.

Full continuity rules are in `docs/workflows/product-capability-admission-and-scope-governance.md`.

## Routing Table

| Content | Location |
| --- | --- |
| Self-built publishable skills | `.skills/yeisme/` |
| Third-party skills from skills.sh, gstack, clawhub, or similar sources | `.skills/imported/` |
| Local project agent skill installs | `.agents/skills/` |
| Local Codex skill installs | `.codex/skills/` |
| CLI-first product owners, domain runtimes, operator and automation entrypoints, including the MCP surface of a capability that also has a CLI | `cli/<name>/` |
| MCP-only owners with no first-party CLI or domain owner: MCP platform runtime, third-party-API-only servers, stateless adapters over another owner's published contract | `mcp/<name>/` |
| Agent products, orchestration runtimes, product-agent integrations, agent-specific assets | `agent/` |
| Approved independent Web, desktop, mobile, or cross-platform product clients | `client/` |
| Long-running product backends, workers, bridges, and service APIs | `backend-server/` |
| API gateway deployment, sidecars, runtime orchestration | `apigateway/` |
| Human-facing repository-level docs, cross-project indexes, governance, migration notes | `docs/` |
| Subproject-owned product, design, operator, runtime, protocol, and implementation docs | `<subproject>/docs/` |
| Root OpenSpec design plans, governance, handoff, and migration records | `openspec/changes/<design-id>/` or `openspec/changes/archive/YYYY-MM-DD-<design-id>/` |
| Subproject OpenSpec implementation tasks, execution evidence, and closeout decisions | `<subproject>/openspec/changes/<change-id>/` or `<subproject>/openspec/changes/archive/YYYY-MM-DD-<change-id>/` |
| Automation shared by the repository | `scripts/` |

## One Capability, One Owner

Surfaces are not owners. Decide the owner project first, then place the surfaces inside it. Splitting one capability into several repositories (`cli/x` + `mcp/x` + `backend-server/x`) is the failure mode this policy blocks: it triples submodules, profiles, OpenSpec changes, docs, and release work for a single capability.

| Situation | Owner project | Inside that owner |
| --- | --- | --- |
| Capability needs a CLI and an MCP surface | `cli/<name>/` | CLI entrypoint plus the MCP surface (`cmd/<name>-mcp`, `internal/mcp`, or equivalent) over one shared application service |
| Capability needs a CLI and a long-running service, worker, or daemon | `cli/<name>/` | The service lives in the same project; no `backend-server/<name>/` copy |
| Capability needs a real client product surface | `cli/<name>/` or `agent/<name>/` for the domain, plus `client/<name>/` for the client | Client consumes the owner's CLI/API/event/resource contracts |
| MCP with no first-party CLI or domain owner | `mcp/<name>/` | MCP tools plus the API adapter they front |
| Shared local infrastructure with several consumers and its own lifecycle | `backend-server/<name>/` | Its own multi-consumer contract, not a product feature |

Existing multi-repository splits stay functional but frozen: do not add domain logic, commands, state, or contracts to the non-owner copy, and do not copy the pattern for new work. Consolidating an existing split needs its own OpenSpec migration and a user decision — never a silent merge. Currently known split: DriveBridge across `mcp/drivebridge`, `backend-server/drivebridge`, `client/drivebridge-client`.

## Decision Flow

1. Decide the owner before the surface. A capability that needs a CLI, an MCP surface, or both gets one owner project: put it in `cli/<name>/` and implement the MCP surface inside that project over the same application contracts. Never create a sibling `mcp/<name>/` for a capability that already has a `cli/<name>/` or `agent/<name>/` owner.
2. Use a standalone `mcp/<name>/` owner only when no first-party CLI or domain owner exists: an MCP platform runtime, a third-party-API-only server, or a stateless adapter over another owner's published contract.
3. If a command entry point exists only to drive an MCP server that has no product owner, keep it under `mcp/<name>/cli/`.
4. If it teaches an agent a reusable workflow owned by this repository, put it in `.skills/yeisme/`.
5. If it is a third-party skill installed from skills.sh, gstack, clawhub, or a similar source, put it in `.skills/imported/`.
6. If it is an approved independent product client consuming stable owner APIs, events, resources, or SDKs, put it in `client/<name>/`; do not put domain business rules there, and create this owner only when a real client product surface exists.
7. If it is shared local infrastructure with its own multi-consumer contract, put it in `backend-server/<name>/`; do not create a copy of a capability that already has a `cli/<name>/` owner.
8. If it belongs to the API gateway runtime, put it in `apigateway/`.
9. If it belongs to a concrete agent product, orchestration runtime, or integration, put it in `agent/`.
10. If it is a repository-level design plan, PRD, architecture decision, governance workflow, cross-project handoff, or migration record, put `proposal.md`, `design.md`, `tasks.md`, and `specs/**/spec.md` together under `openspec/changes/<design-id>/`, then archive to `openspec/changes/archive/YYYY-MM-DD-<design-id>/` after closeout.
11. If it tracks concrete implementation, tests, CLI/API/Web/TUI behavior, execution evidence, or release closeout, put the OpenSpec change under the owning subproject, for example `agent/scaena/openspec/changes/scaena-<slug>/`.
12. If it explains a concrete subproject's product, design, operator experience, runtime, protocol, implementation, QA, or release behavior, put it under that subproject's `docs/`, for example `agent/scaena/docs/`.
13. If it only explains the repository as a whole, cross-project governance, or where subproject docs live, put it in root `docs/`.

## Guardrails

- Do not bury project-wide skills under implementation directories.
- Do not put executable MCP code inside a skill directory.
- Do not use `.agents/skills/` or `.codex/skills/` as the publishing source for custom skills.
- Do not put self-built skills in `.skills/imported/`; that directory is reserved for third-party skill sources.
- Do not put third-party skills in `.skills/yeisme/`.
- Prefer one clear owner directory over duplicating the same workflow in multiple places.
- Do not split one capability across `cli/<name>/`, `mcp/<name>/`, and `backend-server/<name>/` repositories. A surface is not an owner, and every extra repository multiplies submodules, profiles, OpenSpec changes, docs, sync steps, and release work for one capability.
- Do not add new domain logic, commands, state, or contracts to the non-owner copy of an already split capability; route new work to the declared owner instead.
- Keep MCP code on the owner's application contracts: it must not shell out to the owner CLI, read the owner's private persistence, or duplicate provider payloads.
- Do not create `client/<name>/` for a surface that a CLI, a loopback projection, or an existing approved client already serves. A client owner needs its own product shell, target users, release cadence, and success metrics.
- Preserve user-required capabilities across owner routing. Moving a capability behind a typed owner contract is not permission to remove it from the product experience.
- If new evidence later changes an admission decision, state the evidence, affected capabilities, migration or compatibility impact, and required user decision before changing scope.
- Treat CLI/API/event/resource contracts as reusable product interfaces, not as proof that a project must remain CLI-only.
- Route independent UI implementations to an approved `client/<name>` owner; keep durable domain state, provider adapters, evidence, and business rules in the domain subproject.
- Prefer CLI plus skills over MCP when an existing CLI already solves the task with less context and no cross-service reuse requirement.
- Do not track subproject code implementation in root `openspec/`; root changes may link to subproject OpenSpec paths as handoff targets.
- Do not require subproject OpenSpec tasks to update root `docs/<project>/**`; update the owning subproject `docs/**` instead, and keep root docs as indexes or handoff links.
- Do not create execution task packages under `docs/**/checklists`, `work-items/active/`, `plans/active/`, implementation directories, or temporary directories. Those locations may link to OpenSpec changes but do not own task state.
- When creating a new subproject, bootstrap `AGENTS.md`, `CLAUDE.md`, the root-level `.skills/profiles/targets/<subproject>.txt`, local `openspec/`, and local `docs/README.md` before non-trivial implementation. Then run `scripts/skills.sh validate-profiles`, `scripts/skills.sh sync-subprojects`, `scripts/openspec.sh sync-tools`, and `scripts/openspec.sh validate` from the repository root.

## Output Style

When asked where something belongs, answer with:

- admission decision: `fit`, `split-owner`, or `reject-now`
- destination path
- reason
- required-capability impact: retained, staged, moved behind a contract, or explicitly awaiting a user removal decision
- experience composition: where the user sees and controls the capability
- any companion files that should be updated
- commands to validate or sync, if relevant

## If this fails

| Trigger | First fix | Still failing |
| --- | --- | --- |
| "Merge into one console" | Treat as experience composition | Do not delete domain capabilities or move canonical state into a client |
| Wrong owner already in a PRD | State `reject-now` or `split-owner` now | Do not wait for later review to drop a required capability |
| Skill source vs runtime confusion | `.skills/yeisme/` is source; `.agents/skills` is generated | Do not publish from runtime copies |
| Subproject docs in root `docs/<project>/` | Move to `<subproject>/docs/` | Root keeps indexes only |
