# 受管Skill防覆盖

## Why
现有sync只保护未托管同名目录，已托管用户编辑可能覆盖；需要程序级保护及旧状态迁移。

## What Changes
manager 0.3.0新增确定性内容基线、共用写前预检、显式state migrate/recover；保护双runtime、profile/source/manifest与基线，禁止安全管理器降级。

## Capabilities
### Modified Capabilities
- `portable-skill-manager`: 自动drift保护、迁移与事务恢复。

## Impact
owner仅为治理Skill及其既有Python测试/文档/CI。Bash/coreutils，不引入产品逻辑或Bun/Python运行依赖。保留未知Skill、CLI envelope及既有profile格式，不执行发布/费用/race/子Agent/pi goal。
