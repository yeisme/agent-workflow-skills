# Agent Workflow Skills 工作区说明

本仓库维护跨 Agent 宿主的 runtime 指导、Skills source/profile/runtime 分层、发布治理、仓库路由与本地优先策略。

## 边界

- 不维护 Ordo、Scaena、Auctra、Eikona、Pinax 等产品专属运行流程。
- Skill 名称是稳定消费契约；迁移仓库时保持名称不变。
- 每个 Skill 必须包含 `SKILL.md` 与 `agents/openai.yaml`。
- 详细规则放在 `references/`，确定性检查放在 `scripts/`；不在每个 Skill 内重复 README。
- 宿主特定命令必须明确标注为 adapter 示例，不得伪装成通用 Skill 标准。

## 验证

```bash
python3 scripts/validate_skills.py
```
