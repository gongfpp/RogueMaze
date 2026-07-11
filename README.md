# RogueMaze

一款面向 Android、iOS、Windows 与 Linux 的 2D 拼路 Roguelite 过关游戏。角色会从左向右自动前进，玩家通过打出“道路卡牌”实时铺设上坡、下坡、桥梁和机关路线，帮助角色抵达终点。

## 当前状态

- 阶段：P0 立项与预制作
- 当前版本：规则原型 v0.1
- 已完成：项目管理基线、道路连接规则、两种牌组循环和可复现样例
- 下一工作包：`WP-002 工具链与四平台导出验证`
- 暂定技术栈：Godot 4.x + GDScript；在 `WP-002` 锁定具体版本
- 远端仓库：`https://github.com/gongfpp/RogueMaze.git`

## 文档入口

- [项目章程](docs/00-project/PROJECT_CHARTER.md)
- [游戏设计文档 GDD](docs/01-design/GDD.md)
- [MVP 范围](docs/01-design/MVP_SCOPE.md)
- [开发计划与里程碑](docs/02-production/DEVELOPMENT_PLAN.md)
- [产品待办列表](docs/02-production/BACKLOG.md)
- [项目管理与质量流程](docs/02-production/WORKFLOW.md)
- [技术架构草案](docs/03-technical/ARCHITECTURE.md)
- [开发日志](docs/04-devlog/README.md)
- [游戏开发实战教学](docs/05-tutorial/README.md)
- [零基础成员从这里开始](docs/05-tutorial/START_HERE.md)
- [风险登记册](docs/02-production/RISK_REGISTER.md)

## 当前可运行内容

`WP-001` 是不依赖游戏引擎的规则原型。安装 Node.js 20+ 后可运行：

```powershell
npm test
npm run simulate:rules
```

实现和说明见 [prototypes/rules](prototypes/rules/README.md)。这部分用于验证规则，之后会移植到 Godot，不会作为正式游戏运行时依赖。

## 每轮协作约定

每次开发按计划领取一个可完成、可验证的小工作包；完成后如果时间和上下文允许，可以继续下一个，不人为停在半路：

1. 从计划内选择一个最高优先级条目，确认验收标准。
2. 只实现该工作包，不顺手扩张范围。
3. 执行测试、试玩或文档审查。
4. 更新待办、开发日志、变更记录和相关教学。
5. 每轮至少创建一次 Git commit；较长迭代可按稳定检查点多次提交。
6. 推送到项目远端；只有真实的权限、安全或外部资源问题才暂停。

详见 [WORKFLOW.md](docs/02-production/WORKFLOW.md)。
