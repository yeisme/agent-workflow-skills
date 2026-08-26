# portable-skill-manager Specification

## Purpose
TBD - created by archiving change portable-skill-routing-manager-v1. Update Purpose after archive.
## Requirements
### Requirement: 管理引擎随治理 Skill 分发
`yeisme-skill-routing-governance` SHALL 包含可执行的 `scripts/skills.sh`，且其运行不得依赖 Yeisme monorepo 固定目录。

#### Scenario: 管理 Skill 被复制安装
- **WHEN** Skill 目录被复制到外部项目 runtime
- **THEN** 其中的管理脚本仍可通过显式或项目本地 source 配置管理该项目

### Requirement: source 中 Skill 名称唯一
管理器 MUST 根据 `SKILL.md` frontmatter 解析名称，并在 source 中存在重复名称时拒绝 resolve、profile validate 和 sync。

#### Scenario: source 名称唯一
- **WHEN** source 中目标 Skill 只有一个合法目录
- **THEN** `resolve` 返回该目录

#### Scenario: source 名称冲突
- **WHEN** source 中两个目录声明相同 Skill 名称
- **THEN** 命令以非零状态退出并列出冲突路径

### Requirement: profile 是唯一激活声明
管理器 SHALL 通过命令创建和修改 `.skills/profiles/root.txt`，并禁止 profile 引用未知 Skill。

#### Scenario: profile add dry-run
- **WHEN** 用户使用 `--dry-run` 添加已知 Skill
- **THEN** 命令报告计划变更且不修改 profile

### Requirement: 双 runtime 安全同步
管理器 SHALL 生成相同的已管理 Skill 内容到 `.agents/skills` 和 `.claude/skills`，保留未知目录，并通过项目内 staging 在失败时恢复原 runtime。

#### Scenario: 首次同步
- **WHEN** profile 有效且 runtime 尚不存在
- **THEN** 两个 runtime 被创建并包含全部 profile Skills

#### Scenario: 移除已管理 Skill
- **WHEN** Skill 从 profile 移除且存在于上一份 managed manifest
- **THEN** 下一次同步从两个 runtime 移除该 Skill 并更新 manifest

#### Scenario: 保留未知 Skill
- **WHEN** runtime 包含 managed manifest 未列出的 Skill
- **THEN** 下一次同步保留该目录

### Requirement: Agent 使用最小复杂路由组合
管理 Skill MUST 指导 Agent 先识别 owner，再搜索并阅读候选 Skill，默认选择一个 primary workflow 和至多一个兼容 domain constraint，审计职责独立处理。

#### Scenario: 多个候选同时匹配
- **WHEN** 一个任务匹配多个复杂 Skills
- **THEN** Agent 输出选择理由、active/on-demand 状态、owner 和验证命令，而不是批量加载全部候选

### Requirement: 命令结果具有多投影输出
管理器 SHALL 从同一命令结果渲染默认人类摘要、`--agent` key=value 和 `--json` envelope；机器模式失败时仍须输出结构化失败结果并返回非零状态。

#### Scenario: Agent 模式成功
- **WHEN** 用户对成功命令传入 `--agent`
- **THEN** stdout 包含 `spec_version=1.0`、`mode=agent`、规范化 command 和 `status=success`

#### Scenario: JSON 模式失败
- **WHEN** 用户对失败命令传入 `--json`
- **THEN** stdout 仍是有效 JSON envelope，`status=failed` 且包含标准 error 对象

