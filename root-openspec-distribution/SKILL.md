---
name: root-openspec-distribution
description: Use when routing root OpenSpec designs to code-owning subprojects or freezing root implementation tasks.
---

# 根 OpenSpec 分发

使用本 Skill 处理根目录 spec 分发、owner handoff、根 change 冻结或“不要再在根维护实现任务”的请求。

## 不变量

- 根 `openspec/` 只保存仓库级架构、治理、迁移和跨项目 handoff。
- 代码、测试、CLI/Web/TUI 行为、运行时证据和 closeout 必须写入目标 owner 的 `<owner>/openspec/` 与 `<owner>/docs/`。
- 现有根 change 不假装完成；标记为 `frozen-at-root`，保留设计和历史上下文，停止追加实现任务。
- 未明确 owner 时停在 `needs-routing`，不得按目录名猜测。
- 本 Skill 不执行 Provider、付费调用、部署、发布、生产数据迁移、真实浏览器验收或其他真实 owner 验收。

## 路由步骤

1. 读取根 change 的 `proposal.md`、`design.md`、`tasks.md`，提取显式 owner handoff。
2. 以最近的 owner `AGENTS.md`、本地 `openspec/config.yaml` 和本地 docs 作为实现边界。
3. 将根 change 写入分发索引，状态固定为 `frozen-at-root`。
4. 需要实现时进入 owner，使用 `openspec new change <owner>-<slug>` 创建本地 change；不要在根追加实现任务。
5. 只运行本地静态文档检查；真实验收缺口保留 `pending`、`blocked` 或 `owner-unavailable`。

## 命令

```bash
python3 scripts/openspec-distribute.py
scripts/skills.sh validate-profiles
scripts/openspec.sh sync-tools
```

`.agents/skills/` 和 `.claude/skills/` 是生成目录，不手工修改。若 profile 或 runtime 不一致，先修复 Skill source/profile，再同步。
