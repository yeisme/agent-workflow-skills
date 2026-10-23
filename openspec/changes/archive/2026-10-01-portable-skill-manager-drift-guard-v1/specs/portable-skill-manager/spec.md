## ADDED Requirements

### Requirement: 内容基线保护
manager SHALL 在所有修改入口校验上次受管内容基线；MUST NOT 覆盖双runtime任一用户修改或以新source替代旧基线。

#### Scenario: 已托管内容漂移
- **WHEN** 文件、路径或执行权限与基线不一致
- **THEN** 变更返回runtime_drift，profile/source/runtime均不改变

### Requirement: 旧状态显式迁移
manager SHALL 提供state migrate且仅以原source.local核对旧状态，MUST NOT 自动认领未知内容或同步旧安全合同的manager。

#### Scenario: 旧源缺失
- **WHEN** 原source不存在或与双runtime不同
- **THEN** 迁移失败，保留原状态

### Requirement: 事务恢复
manager SHALL 对变更使用锁、事务备份及可验证的恢复流程；残留事务 MUST 阻止后续写入，显式恢复不得覆盖事务外编辑。

#### Scenario: 不可捕获中断
- **WHEN** 发布留下未完成事务
- **THEN** 下次修改返回recovery_required，state recover只恢复记录目标且校验旧新摘要
