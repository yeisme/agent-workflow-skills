---
name: yeisme-repo-routing
description: Use when deciding whether a proposed capability fits a Yeisme project, whether it needs split ownership, and where product surfaces, clients, services, files, workflows, skills, MCP code, CLI entrypoints, agent assets, gateway assets, or documentation should live.
---

# Yeisme 仓库与能力归属

首次提出能力、合并体验或不确定目录归属时使用。先确定领域 owner，再决定 CLI、API、MCP、客户端等表面；保留用户明确要求的全部能力。

## 能力准入

进入 PRD、OpenSpec、评审或实现前，记录必需能力并立即分类：

- `fit`：当前项目拥有该能力的状态、规则、权限、证据与生命周期。
- `split-owner`：领域由一个项目维护，已批准的客户端或控制平面通过 typed contract 组合体验。
- `reject-now`：当前放置方式违反产品、权限、安全或仓库边界；立即说明理由和可行 owner。

分阶段交付不能把必需能力悄悄降级为可选。“一个项目/控制台”默认表示体验组合，不自动允许删除能力、迁移 canonical state 或复制状态机。后续发现归属变化时说明证据、受影响能力与迁移影响。完整规则见项目 `docs/workflows/product-capability-admission-and-scope-governance.md`。

## 路由表

| 内容 | 归属 |
| --- | --- |
| 自建可发布 Skills | `.skills/yeisme/` |
| 经审查的第三方 Skills | `.skills/imported/` |
| profile 生成的运行副本 | `.agents/skills/`、`.claude/skills/` |
| 有 first-party CLI 的产品及其 MCP、服务、worker | `cli/<name>/` 内同一 owner |
| 具体 Agent 产品、编排与产品资产 | `agent/<name>/` |
| 没有领域 owner 的第三方 API MCP 或无状态适配器 | `mcp/<name>/` |
| 企业模型与企业 MCP 网关 | `apigateway/aigora/` |
| 个人内网 MCP 网关 | `mcp/gateway/`，独立正常维护 |
| 有独立多消费者合同的共享基础设施 | `backend-server/<name>/` |
| 已批准的独立客户端产品 | `client/<name>/`；只消费 owner 合同 |
| 仓库级架构、治理、索引、迁移 | 根 `docs/` 和根 `openspec/` |
| 产品、运行时、协议、实现与验收文档 | `<owner>/docs/`、`<owner>/openspec/` |
| 仓库共用的确定性自动化 | `scripts/` |

仅为 MCP 服务提供启动命令、且没有独立 CLI 产品 owner 时，命令留在该 MCP 项目内。普通业务服务不因长期运行就拆成第三份 backend 项目。

## 当前迁移决定

DriveBridge 已按用户决定统一到 `cli/drivebridge`：根模块 CLI/MCP，`server/` HTTP/GORM，`web/` React。用户随后要求清理旧项目，原三个工作区入口已移除；不再生成独立 CI、docs、OpenSpec 或 profile。该例外不自动批准其他产品合仓。

2026-10-03：Aigora 专注企业内网 MCP 网关；`mcp/gateway` 恢复个人网关正常维护，独立拥有个人目录、权限、运行与发布。旧整体收敛/退役方向被替代；双方不共享凭据/运行状态，也不吸收领域资产、对话或 A2A 状态。

## 实现规则

1. 同一能力只建一个 owner；CLI/MCP/HTTP 共用 application contract。MCP 不 shell out 到 CLI，不读 owner 私有存储，不复制 Provider payload。
2. 已有 CLI、只读本地投影或获批客户端能满足需求时，不新增客户端项目。独立客户端需要真实产品表面、用户与维护边界，领域规则、权限、凭据和持久化仍由后端 owner 持有。
3. 根 OpenSpec 只管理跨项目设计、治理和迁移；源码、测试、实现证据和 closeout 归子项目。完成后按 CLI 归档，不把任务状态另写到 docs/checklists、work-items 或临时目录。
4. 产品文档归代码 owner；根只保留索引和交接链接，不要求每次回填根级产品副本。
5. Skills 不承担 MCP 实现，不把生成 runtime 当发布源，不混放自有源与第三方源。
6. 普通本地工作直接按最小可逆范围完成；不因新增内部接口或文件再加审批。生产、发布、付费等动作遵循当前具体授权。
7. 新子项目先建立 AGENTS.md、CLAUDE.md、profile、openspec 与 docs/README.md；profile 和结构化资产通过现有 CLI 生成。仓库/子模块创建遵循根 AGENTS.md。

```bash
scripts/skills.sh validate-profiles
scripts/skills.sh sync-target <target>
scripts/openspec.sh sync-tools
scripts/openspec.sh validate
```

只同步受影响范围；根级批量同步只在共享源确实影响多个消费者时使用。

## 失败处理

| 触发 | 先做什么 | 仍失败时 |
| --- | --- | --- |
| 同一能力出现两个 owner | 标出 canonical state、权限和证据的现有 owner | 停止新增副本，建立 split-owner 合同或迁移提案 |
| 用户要求“合并成一个控制台” | 先拆体验组合与领域归属 | 不删除能力、不把状态机搬进客户端 |
| 文档路径与代码 owner 冲突 | 以最近 owner 的 `AGENTS.md` 和本地 docs 为准 | 根文档只留索引和交接链接 |
| MCP 能力没有 first-party CLI/领域 owner | 评估 `mcp/<name>` 是否是无状态适配器 | 不在 Skill 或共享 backend 偷建第三份领域状态 |
| profile/runtime 与 source 不一致 | 运行 `scripts/skills.sh profile validate` 和对应 runtime 校验 | 不手改 runtime，先修 source/profile 再同步 |
| 无法判断 fit/split-owner/reject-now | 暂停实现，写出 owner、合同和证据缺口 | 保留未知，不用目录名称代替归属判断 |

## 交付

说明 `fit|split-owner|reject-now`、目标路径、理由、每项必需能力的保留或交接方式、实际体验入口、兼容影响和验证命令。owner 不匹配时立即纠正，不等待最后评审再砍能力。
