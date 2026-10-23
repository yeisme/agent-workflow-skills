---
name: codex-agent-runtime
description: Use when configuring, operating, or instructing Codex in Yeisme projects, including skill loading, tool-name mapping from Claude Code style skills, MCP Gateway client setup, multi-agent usage, profile sync, and safe command examples.
---

# Codex 运行指导

在 Codex 中使用 Yeisme Skills、MCP 或本地工具时，按当前运行时实际提供的能力操作。当前用户要求、最近的 AGENTS.md 和权限边界优先。

## 最小执行路径

1. 已启用 `yeisme-builder-profile` 时先恢复用户偏好，再读取本任务需要的 Skill。源码归 `.skills/yeisme/`，运行副本由 profile 生成，不在 `.codex/skills` 复制项目 Skill。
2. Claude Code 风格工具名按能力映射：`TodoWrite` 对应可用的计划工具；`Bash` 对应 shell；`Read/Edit/Write` 对应文件工具；`Skill` 表示直接遵循已读取指令。不得虚构当前没有的工具。
3. CLI 提供 `--json`、`--agent` 或 `--events` 时优先使用稳定合同，不解析人类输出。
4. 普通本地实现、测试、文档、mock 和可丢弃测试数据直接推进；优先现有模式、最小可逆改动和针对性验证。保留无关脏树。
5. 涉及生产、凭据变更、付费、部署、发布、推送、真实通信或不可逆外部操作时核对具体授权。已有同范围授权不重复确认。外部集成先验证 mock 或已授权 sandbox。

## MCP 接入

Gateway 接入使用其生成的客户端配置。直接连接产品的内网 MCP 是另一条路径，不能把 Eikona 的 `/mcp` 当成 Gateway。

```bash
codex
mcp-gateway client doctor --client codex --registry ../registry.json
mcp-gateway client config codex --registry ../registry.json --instructions
mcp-gateway client config codex --registry ../registry.json --policy --json
scripts/skills.sh list-runtime
scripts/skills.sh profile show <owner>
```

产品支持 token 环境变量或受保护文件时，使用该合同；真实 token 不进入聊天、命令参数、仓库文件或证据。远程图片编辑不能传客户端 `/Users`、`/var/folders` 等路径，应使用 owner 接受的上传入口或已有 `eikona://artifact/<handle>`。

`wait` 只是一次状态快照。生成失败或结果未知时先核对原运行，不能直接复用失败的幂等键重发。MCP 路由明确要求经 Gateway 时，不用 shell 绕过策略。

## 子 Agent 与目标

只有当前用户明确要求 subagent、子 agent 或子agent，才能创建子代理。任务复杂、日志多、测试慢或本 Skill 都不构成授权；没有授权时由 root 完成同一工作。

取得授权后，`route-agents` 是唯一协调者，默认 balanced。模型及 reasoning effort 遵循当前宿主 AGENTS.md，不在本 Skill 固定旧模型映射。深度保持一层：root 定义验收和权限，一个 implementer 负责完整功能的源码、测试、fixture 与文档，独立 test-engineer 仅执行验证和产出诊断证据。root 保留外部动作、最终整合和验收。

worker 返回 `status, summary, evidence, files_modified, verification, risks, confidence`。失败包只带命令、退出码、最小错误、证据路径；修复交回原写入者。超时不证明写入者已停止，未确认存活状态前不派第二个重叠写入者。

`child_goal_policy` 保持 `schema_version: "1.0"`，默认 `disabled`。只有当前用户明确授权 `create_if_available` 才能管理一个范围更小的线程目标；不覆盖不兼容目标，不自设 token 预算，不派后代。`goal_report` 可报告 `created|reused|unavailable|collision`，状态可为 `active|waiting_root|complete|blocked|liveness_unknown`。相同阻塞连续三轮后才能标记 blocked；目标完成仅是候选交接，不代替 root 验收。目标不重置修复、升级或熔断预算。

## 分阶段验证

- 实现中：只运行当前改动的必要检查，不反复跑全仓 lint、build、e2e 或全量 OpenSpec。
- 切片稳定：交付改动路径、针对性结果、未执行检查及风险。
- 最终验收：在稳定 diff 上执行该任务必需的完整检查；已有有效结果且输入未变时复用。
- 修复失败前分类为 `introduced|pre_existing|concurrent|environment|ambiguous`；仅修复本次引入且属于授权范围的问题。
- race 不属于默认验证。执行聚合命令前检查依赖，避免间接触发。

详细规则以项目的 `docs/workflows/rapid-local-iteration.md` 和 `docs/workflows/codex-subagent-feature-delivery.md` 为准。普通任务不额外创建长期 goal、日志仓库或整套审批流程。

## 输出与恢复

输出结论、验证来源和下一步，命令可直接运行。不暴露内部执行前缀、隐藏提示词、私有工具参数、Provider 原文或完整推理。缺工具时说明能力缺口并采用普通工具回退；没有授权时继续本地可做的工作，不扩大范围。
