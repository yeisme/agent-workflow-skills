---
name: agent-pipeline-development-constraints
description: Use when dispatching, routing, reviewing, accepting, documenting, or merging work across the multi-agent development pipeline (program manager, CEO, architect, OpenSpec author, worktree manager, feature devs, browser QA, deputy architect, reviewers, integration tester, docs syncer, shipper), or when a role is about to write another role's artifacts, approve its own output, widen its dispatched scope, or add an external side effect; enforce the per-role write scope, required input, evidence, stop condition, and gate order.
---

# 多 Agent 开发约束

流水线的头号风险是角色越权，而不是并行度不足。本技能为每个角色固定四件事：可以写什么、必须先读什么、必须交出什么证据、什么时候必须停。

约束真源是 `docs/workflows/agent-pipeline-development-constraints.md`。本技能负责在派发、审查、验收、文档同步和合并时执行它。

## 使用场景

- 编排者要把一批任务派发给多个并行开发者、审查者或验证者。
- 某个角色准备做别的角色的事：实现者想宣布验收通过，审查者想直接提交修复，文档同步者想在行为冒烟前写“已支持”，交付者想合并未审分支。
- 某条 workstream 的失败需要决定返工归属。
- 需要审计一条流水线是否越权、是否缺证据、是否跳过了门禁。

以下情况不要使用本技能：单 owner 本地改动（按 `docs/workflows/rapid-local-iteration.md` 直接执行）；单个任务的阶段与写范围划分（用 `delivery-phase-contract`）；只读探索或纯问答。

## 输入

- 已批准的范围、产品裁决或设计输入。
- owning subproject 的 `AGENTS.md`、分支与 worktree 现状、端口与数据目录约定。
- 目标合同、OpenSpec change、现有 diff、已有验证证据。
- 当前用户是否明确授权子 agent、提交、推送、合并或外部写入。

## 输出

- 一份 workstream 表：任务、角色、owned paths、依赖、验收、门禁顺序。
- 每个角色的派发信封（见下）。
- 每条 workstream 的结论：一致、`introduced`、`pre_existing`、`concurrent`、`environment`、`ambiguous`、`BLOCKED`，以及 rework owner。
- 未决问题与升级到 root 的最小决定请求。

## 工作流

1. **按域分组，不按人分组。** 同一模块/目录附近的任务归入同一 workstream，每条 1-3 个相关任务；同一路径不得分给两个写入者。
2. **过门再派发。** 产品裁决 → 设计 → OpenSpec change → 工作区拓扑 → 并行实现 → 独立审查 → 文档同步 → 合并。每个门要求上一个门的证据，不认上一个门的声明。
3. **写派发信封。** 至少包含 objective、phase、role、owned/shared/forbidden paths、acceptance、focused_verification、integration_dependency、evidence_target、stop_condition、exclusions。缺字段的派发不成立。
4. **保持一个写入者。** 初始最多两个 writer，仅当路径不重叠、验收可独立运行、共享生成物不会被覆盖。出现路径重叠、共享生成物竞争或 writer 存活状态不明时，停止新增写入并切回单 writer。
5. **审查保持只读。** `deputy_architect` 与各 reviewer 只输出带证据的发现和 verdict；修复回到原 writer。
6. **按归类返工。** `introduced` → 同一 writer、`owned_paths` 内修；`pre_existing` → 记录并交对应 owner；`concurrent` → 等稳定点或交该路径 owner；`environment` → 保留证据并重试或恢复环境；`ambiguous` → 先派只读 `debugger`。
7. **文档与合并收口。** 文档只同步已工作、已冒烟的行为；合并按逻辑功能分组，同一功能的多个分支不拆成多次合并。

## 派发信封

```text
objective: <一个可验收的结果>
phase: CONTRACT | FRONTEND | BACKEND | INTEGRATION
owner / role: <角色名>
owned_paths / shared_read_paths / forbidden_paths
acceptance: <可观察验收项>
focused_verification: <真实可运行命令与期望结果>
integration_dependency: <合并后才能运行的检查与负责角色>
evidence_target: <证据目录或报告位置>
stop_condition: <何时结束，何时报告 BLOCKED>
exclusions: <本任务明确不做的事>
model_escalation_evidence: <仅在升级模型或推理等级时需要>
```

## 边界

- 不给角色派发超出其账本的写入权；发现需要新范围时报告为新任务。
- 不允许写入者批准自己的产物，也不用“上下文快满了”“反正能跑”作为跳门理由。
- 不代行提交、推送、合并、发布、部署或凭据访问；这些属于显式授权动作。
- 不把完整测试日志、截图和 trace 回灌编排上下文；落盘后只回传路径、退出码和最小失败摘录。
- 不因为超时启动替代 writer；`timeout` 不释放租约。
- 不把 `pre_existing` 或 `concurrent` 失败算作本 workstream 通过，也不借修它们扩大范围。
- 不在同一功能的分支间制造无法回滚的中间态。
- 本技能不决定模型、配额和 lane 映射；升级必须附失败证据并由 root 持有。

## 验证

- 派发前确认每个叶子任务都有角色、owned paths、依赖、验收和 stop_condition。
- 验收时确认写入者未自审、审查者未改代码、验证者未改 tracked 文件。
- 集成及更高层证据按 `project-integration-test-evidence` 落在 owning subproject 的 `temp/integration-test-runs/<run-id>/`。
- 最小通用检查：

```bash
git status --short
git diff --check
```

- 修改本技能源后运行：

```bash
scripts/skills.sh validate-custom
scripts/skills.sh validate-profiles
scripts/skills.sh sync-root
```

## If this fails

| Trigger | First fix | Still failing |
| --- | --- | --- |
| 两个 writer 要改同一路径 | 合并为一个 writer 或串行化 | 不承认“并行隔离” |
| 审查者已经改了代码 | 回滚到审查前 diff，把修复交回原 writer | 不保留越权提交 |
| writer 超时且存活不明 | 检查工作区与进程，确认状态后再派发 | 不启动重复 writer |
| 失败归属不清 | 派只读 `debugger` 缩小范围 | 不直接派新 writer 重做 |
| 文档领先于行为 | 撤回未验证描述，等冒烟证据 | 不用文档宣告能力 |
| 用户未授权子 agent / 提交 / 合并 | 停止，说明需要哪一项授权 | 不把并行或流水线当作授权 |
