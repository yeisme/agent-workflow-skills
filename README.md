# Agent Workflow Skills

面向 Codex、Claude Code、Gemini CLI、Copilot CLI、Cursor、Windsurf、OpenCode、Crush 等 Agent 宿主的开源工作流与 Skills 治理集合。

本仓库只保留通用 Agent runtime、Skills 分层、仓库路由、发布治理和 local-first policy。Ordo 调度与 Scaena 生产 Skills 已拆到各自 owner 仓库，避免通用 Agent 工作流与具体产品运行逻辑混在一起。

## 能力分组

- Agent runtime：`codex-agent-runtime`、`claude-code-agent-runtime`、`gemini-cli-agent-runtime`、`copilot-cli-agent-runtime`、`cursor-agent-runtime`、`windsurf-agent-runtime`、`opencode-agent-runtime`、`crush-agent-runtime`
- Skills 治理：`yeisme-claude-skills-layout`、`yeisme-skill-routing-governance`、`yeisme-skill-publisher`
- 仓库与状态策略：`yeisme-repo-routing`、`local-first-backup-sync-policy`

## 使用与验证

```bash
git clone https://github.com/yeisme/agent-workflow-skills.git
cd agent-workflow-skills
python3 scripts/validate_skills.py
```

这些 Skills 可以描述宿主 adapter 所需 capability，但不应假设宿主一定存在 `scripts/skills.sh`、固定目录或特定产品。Yeisme 专属命令作为示例与 adapter 说明保留在明确标注的 Skill 中。

## License

[MIT](LICENSE)
