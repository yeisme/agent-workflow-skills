# 实施与验收任务

由 scripts/openspec-tasks.py 维护状态。

- [x] 1.1 owner=manager；scope=基线/预检/迁移；deps=none；verify=Python unittest；预期=冲突零写；失败复查=tree digest | evidence: manager0.3.0安全基线与所有变更预检、显式旧source迁移、降级保护通过；包含字节/执行权限/删除/双runtime与未知同名冲突。命令回归9 PASS，temp/integration-test-runs/20261001T184700Z-b3a7f74a/。
- [x] 1.2 owner=manager；scope=事务/恢复/锁；deps=1.1；verify=故障注入测试；预期=恢复不覆盖独有内容；失败复查=journal | evidence: 固定目标事务+锁+写前复查；临时子进程发布故障恢复、中断残留显式recover、事务外用户编辑拒绝覆盖全部通过。预发布非法暂存的恢复边界已修正，失败证据保留；无真实用户进程终止。
- [x] 2.1 owner=manager；scope=证据/文档/CI；deps=1.2；verify=validate_skills/strict；预期=本地合同通过；失败复查=受影响入口 | evidence: owner evidence runner与既有unittest、CI生成脚本已接入；validate_skills16 PASS、strict2 PASS、focused Ruff PASS。Manju最终实际包已跨版本消费安全manager；未推送/发布，未修改无关既有dirty。
