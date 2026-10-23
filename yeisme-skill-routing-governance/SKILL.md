---
name: yeisme-skill-routing-governance
description: Use when selecting, combining, adding, removing, discovering, reviewing, or routing complex skills for a Yeisme or external project, especially when managing project profiles, syncing .agents/.claude runtimes, deciding active versus on-demand status, or guiding an agent to use the smallest compatible workflow and domain constraints.
---

# Skills 路由与分层治理

Agent 负责理解任务，Skill manager 负责确定性状态变更。默认只加载一个主工作流和至多一个兼容领域约束；独立审计保持只读，不与实现者混用。

## 来源与边界

- Yeisme 自有源是 `.skills/yeisme/`，第三方源是 `.skills/imported/`；外部项目使用固定来源的 `yeisme-agent-my-skills` checkout。
- `.skills/profiles/root.txt` 声明根级默认集，Yeisme 子项目用 `.skills/profiles/targets/<owner>.txt`；外部机器绑定由 manager 写入 `.skills/source.local`。
- `.agents/skills/` 与 `.claude/skills/` 是生成副本，不手工编辑。未知来源、重复名称、缺失 owner、profile/runtime 漂移或双副本差异必须验证失败。
- 不重建 marketplace、路由评分、telemetry、MCP/HTTP 服务或后台任务；不在 shell 中实现自然语言路由。

## 选择与发现

先读最近的 AGENTS.md，确定 owner，再判断任务需要主工作流、领域约束、独立审计，还是普通工具即可。优先用户点名或明确触发的 Skill；缺少入口时搜索：

```bash
scripts/skills.sh search "<task terms>"
scripts/skills.sh resolve <skill-name>
```

读取匹配候选的完整 SKILL.md，引用文件按需展开，不批量加载所有源。三个以上候选、归属不清或组合有冲突时读 [Agent 路由合同](references/agent-routing-contract.md)。Skill 不得选择模型、派发 Agent、扩大权限或接管第二份领域状态。

低频评审、发布、安全审计和专项操作保持按需。只有启动必需、高频 owner 不变量、反复发现失败或最近 AGENTS.md 明确要求，才提升为默认加载。搜索命中不是安装批准。

## 分配与同步

profile 变更和同步需要当前任务授权；用户已明确要求相应清理、分配或同步时直接完成，不重复确认。同一路径有活跃写入者或 runtime 独有修改无法解释时先协调并保留内容。

Yeisme 宿主命令：

```bash
scripts/skills.sh profile show root
scripts/skills.sh profile show agent/scaena
scripts/skills.sh profile add agent/scaena <skill-name> --dry-run
scripts/skills.sh profile add agent/scaena <skill-name>
scripts/skills.sh profile remove agent/scaena <skill-name> --dry-run
scripts/skills.sh profile remove agent/scaena <skill-name>
scripts/skills.sh profile validate
```

源与 profile 稳定后再同步一次。根级变更用 `sync-root`，单项目用 `sync-target`，确实跨多个消费方才用 `sync-subprojects`。同步前检查当前源、profile 与 runtime 差异，不覆盖无法归因的独有修改。

```bash
scripts/skills.sh validate-custom
scripts/skills.sh validate-profiles
scripts/skills.sh sync-root
scripts/skills.sh sync-target <target>
scripts/skills.sh validate-runtime
scripts/skills.sh validate-subprojects-runtime
```

同步冲突必须在源/profile 解决后重生成，不能手改 runtime。manager 保留非托管目录，遇到同名冲突应失败而非覆盖。

## 外部项目

只需要做剧路由时可以直接安装该产品 Router；需要长期绑定、profile 与双 runtime 管理时再使用聚合仓库。

```bash
npx --yes skills add https://github.com/yeisme/ai-drama-skills --skill ai-drama-router --yes

git clone --recurse-submodules https://github.com/yeisme/yeisme-agent-my-skills.git
cd yeisme-agent-my-skills
scripts/skills.sh --project /path/to/project init
scripts/skills.sh --project /path/to/project profile show
scripts/skills.sh --project /path/to/project --dry-run profile add <skill-name>
scripts/skills.sh --project /path/to/project profile add <skill-name>
scripts/skills.sh --project /path/to/project profile remove <skill-name>
scripts/skills.sh --project /path/to/project profile validate
scripts/skills.sh --project /path/to/project sync
scripts/skills.sh --project /path/to/project validate
```

`init` 创建 profile、记录本机来源、激活管理 Skill 并同步验证；已有项目不能用init重绑source。其他工作流仍按明确选择加入。checkout移动后显式指定新--source执行configure-source。

### Portable manager 0.3.0安全合同

所有修改自动核对`.skills/runtime-baseline.v1.tsv`和双runtime；用户新增/编辑/删除文件、修改执行权限都会阻止sync与profile remove，不提供force。合法source更新通过旧基线识别，不把新source当旧内容基准。未知同名目录冲突拒绝，其他未托管目录保留。受管路径禁止symlink、特殊文件和TAB/换行，中文空格支持。`--dry-run`不修改项目文件。

旧项目须使用新manager执行`--project <project> state migrate`，不传--source；原source.local、manifest/profile和双runtime必须精确匹配。缺源、原source已变或runtime有独有内容则停止，不能手写baseline认领。迁移后再configure-source/sync/validate。目标source必须包含安全合同v1的manager；工具回滚不代表manager也能降级。

变更持有单writer锁。可捕获失败尝试恢复旧状态；掉电/强制中断不保证多目录原子性。看到recovery_required时，先确认writer已停止，使用`state recover --transaction <reported-id>`；只处理项目内固定目标且拒绝覆盖事务外编辑。不删除锁或事务来强行继续，也不执行事务数据中的命令。baseline保护误覆盖，不是对同一用户恶意篡改的密码学防御。

第三方导入必须指定 Git ref：

```bash
scripts/skills.sh import <repo-url> <ref> <module>
```

导入后先审查 diff，再按已有授权分配；不把第三方内容写入自有源，不自动安装所有命中。

## 失败处理

| 触发 | 先做什么 | 仍失败时 |
| --- | --- | --- |
| Skill 名称能搜到但没有可解析 source | 运行 `scripts/skills.sh resolve <skill-name>` | 标记 unavailable，不写 profile、不手建 runtime 目录 |
| profile 引用了已删除或重复 Skill | 运行 `scripts/skills.sh profile validate` | 修正 profile 真源后再同步，不能把 runtime 当补丁层 |
| runtime 有未解释的独有文件 | 先保存 diff 并确认是否有活跃 writer | 停止 sync/remove，不用 force 覆盖 |
| 同名 Skill 来自多个 source | 比较 source、owner 和当前 profile | 选择一个 canonical source，其余保持 on-demand 或明确 import |
| sync 报 `recovery_required` | 确认 writer 已停止，按事务号运行 `state recover` | 不删除锁、不执行事务数据中的命令、不重复启动第二个 writer |
| requested skill 需要凭据、付费或外部写入 | 先加载对应 owner 的动作合同和授权门 | 只完成本地 dry-run/read-only，不能用 Skill 路由代替授权 |

## 交付

说明选中的主工作流、可选约束及按需状态，列出实际 profile 变化和验证命令。冲突、缺失能力、未完成同步必须如实报告。两个主工作流冲突时保留最小兼容组合；runtime 与源不一致时修正真源，不复制补丁到生成目录。
