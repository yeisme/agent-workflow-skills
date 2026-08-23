## Why

`yeisme-skill-routing-governance` 已定义 Agent 如何选择和晋升 Skills，但其确定性命令假设宿主仓库自带 `scripts/skills.sh`。外部项目需要一个随管理 Skill 一起发布的通用引擎，才能真正复用 profile、双 runtime 和复杂路由治理。

## What Changes

- 在 `yeisme-skill-routing-governance/scripts/skills.sh` 增加可移植管理引擎。
- 支持外部项目初始化、source 绑定、Skill 搜索/解析、profile 生命周期、安全同步和验证。
- 扩展管理 Skill，明确 Agent 语义路由流程、最小组合规则、按需加载和 profile 晋升门槛。
- 增加标准库测试，覆盖外部项目完整闭环和安全边界。

## Capabilities

### New Capabilities

- `portable-skill-manager`: 可随管理 Skill 分发的跨项目确定性 Skill 管理引擎。

### Modified Capabilities

无。

## Impact

- `yeisme-skill-routing-governance/SKILL.md`
- `yeisme-skill-routing-governance/agents/openai.yaml`
- `yeisme-skill-routing-governance/scripts/skills.sh`
- `scripts/test_skill_manager.py`
- `scripts/validate_skills.py`

命令作为 `0.x` additive surface 新增；不改变已发布 Skill 名称与 metadata schema。
