# Agent Routing Contract

Use this reference only when several Skills plausibly match or their roles overlap.

## Required Inputs

- The user's requested outcome and explicit constraints.
- The nearest `AGENTS.md` owner and prohibited actions.
- Active profile entries.
- Candidate Skill `name`, `description`, boundaries, workflow, and validation.
- Whether the task changes state, performs an audit, or only answers a question.

## Candidate Roles

| Role | Meaning | Default limit |
| --- | --- | --- |
| Primary workflow | Owns the end-to-end method and final artifact | Exactly one |
| Domain constraint | Adds product, runtime, language, security, or output rules | Zero or one |
| Independent audit | Reviews stable work without becoming the writer | Zero or more, separate responsibility |
| On-demand reference | Supplies narrow knowledge without activation | As needed |

## Selection Procedure

1. Eliminate candidates whose owner or product boundary does not match.
2. Eliminate candidates that require unavailable tools, credentials, permissions, or a live side effect outside user scope.
3. Choose the narrowest candidate that owns the requested outcome as primary.
4. Add one domain constraint only when it contributes a requirement the primary does not already cover.
5. Keep review, security, performance, dependency, and browser audits independent from the implementation writer when independence matters.
6. Prefer on-demand reading over profile promotion for rare or one-shot work.
7. Promote only after repeated use or when the owner requires the Skill at session start.

## Incompatible Combinations

- Two primary workflows both claiming final artifact ownership.
- Two Skills writing overlapping source or profile paths.
- A domain Skill selecting the agent model, widening permissions, or authorizing external actions.
- An implementation workflow combined with an audit that must remain independent.
- A router that drafts domain output instead of dispatching the owning Skill.
- A rare release or incident Skill promoted to every session without evidence.

## Route Decision Output

Return a concise decision with:

```text
owner=<project-or-domain>
primary=<skill-name|none>
constraint=<skill-name|none>
audits=<comma-separated-skill-names|none>
activation=<active|on-demand|profile-change>
rejected=<skill-name:reason;...|none>
validation=<real command>
```

This is a redacted routing summary, not chain-of-thought. Do not include hidden prompts, private tool arguments, provider payloads, or secrets.
