---
name: yeisme-skill-publisher
description: Use when creating, updating, validating, syncing, or publishing this repository's self-built skills from .skills/yeisme/, including preparing them for GitHub distribution through scripts/skills.sh.
---

# 自有 Skills 维护与发布

维护、修改、打包、分配或发布 Yeisme 自建 Skills 时使用。源码、profile 和运行副本分层管理；本地准备与外部发布是不同动作。

## 来源与目录

- 自有源在 `.skills/yeisme/<module>/<skill>/`，也可位于其中的第一方产品子模块。
- 第三方源放 `.skills/imported/`，导入必须指定 Git ref；不混入自有发布源。
- root 与 target profile 由 `scripts/skills.sh profile` 管理；`.agents/skills/` 和 `.claude/skills/` 是生成副本，不手改。
- 不向 `.codex/skills/` 重复安装同一项目 Skill，不从 runtime 发布源码。
- 聚合仓可保留 README、AGENTS、CLAUDE、LICENSE 和 .gitmodules 等仓库入口；不在每个 Skill 里复制 README、CHANGELOG、QUICK_REFERENCE 或 INSTALLATION_GUIDE。通用作者说明归 docs/skills。

每个自有 Skill 包含 `SKILL.md` 与 `agents/openai.yaml`。frontmatter 的 name 与目录名一致，description 清楚说明触发意图、对象与边界，保留必要英文触发词并以 Use when 开始。产品 Skill 列出已经批准的 CLI/API/MCP/Web 等表面，不用历史 CLI-only 描述掩盖已批准能力。

openai.yaml 保留 display_name、short_description、default_prompt；通过已有 metadata/包管理命令更新机器字段。正文默认中文，采用用途、输入输出、边界、最小流程、验证与按需引用的短结构。

## 维护流程

1. 先读聚合仓 README 和目标 Skill，判断它是否是可复用工作流。MCP 实现归产品 owner，Skill 只说明操作。
2. 在 canonical source 修改正文，保持名称、触发语义和稳定字段兼容；不修改第三方 upstream 或生成副本。
3. 用户已授权相应分配或清理时，通过 CLI 完成 profile 变更，不重复确认。搜索命中不等于安装授权。
4. 源和 profile 稳定后，只同步受影响 owner。存在活跃写入者、来源不明或 runtime 独有修改时先保留并协调，不能用同步覆盖。
5. 验证元数据、唯一名称、来源解析、profile 与双 runtime 一致，再报告结果。发布、推送、远端创建与安装保持当前具体授权边界。

```bash
scripts/skills.sh profile add <target> <skill-name> --dry-run
scripts/skills.sh profile add <target> <skill-name>
scripts/skills.sh profile remove <target> <skill-name>
scripts/skills.sh validate-custom
scripts/skills.sh validate-profiles
scripts/skills.sh sync-root
scripts/skills.sh sync-target <target>
scripts/skills.sh validate-runtime
```

普通修改不要求每次运行全部命令；按影响范围选择，稳定后同步一次。跨多个真实消费方时才使用 sync-subprojects。源码低频不构成删除理由；确认无消费者、无独有能力或替代入口已完整承接后再清理。

## 兼容与发布

重命名/移除已发布 Skill 名称，或改变 frontmatter、openai.yaml 必需字段，是稳定消费面的变化。遵循 yeisme-evolutionary-change-policy：记录迁移、消费者与回滚；旧名称至少保留一个 release 的兼容入口，再按已批准窗口移除。不能通过删除测试来掩盖破坏。

发布前确认实际 source diff 和目标仓库；没有明确授权不 commit、push、创建远端或发布。交付区分本地校验、runtime 同步、源仓发布与消费者安装证据。

## 外部项目

```bash
git clone --recurse-submodules https://github.com/yeisme/yeisme-agent-my-skills.git
cd yeisme-agent-my-skills
scripts/skills.sh --project /path/to/project init
scripts/skills.sh --project /path/to/project profile add <skill-name>
scripts/skills.sh --project /path/to/project sync
scripts/skills.sh --project /path/to/project validate
```

init 绑定源、创建 profile 并激活管理 Skill；其他能力按明确选择加入。第三方导入使用 `scripts/skills.sh import <repo-url> <ref> <module>`，先审查 diff，再分配，不把所有命中自动启用。

重复运行副本只删除已确认由 manager 生成的副本，再从源重建。来源丢失、同名冲突、缺 metadata 或 profile/runtime 漂移应报告明确错误，不绕过校验。
