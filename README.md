# RogueMaze

一款面向 Android、iOS、Windows 与 Linux 的 2D 拼路 Roguelite 过关游戏。角色会从左向右自动前进，玩家通过打出“道路卡牌”实时铺设上坡、下坡、桥梁和机关路线，帮助角色抵达终点。

## 当前状态

- 阶段：P0 立项与预制作
- 当前版本：Alpha 基线 v0.3
- 已完成：垂直切片、纸片机械音画、版本化存档、数据驱动道路/节点、减少动态效果、Windows/Linux 导出
- 当前连续工作：卡牌升级与移除、Alpha 内容扩展及 `WP-025` 平台构建深化；真人试玩保持开放记录
- 锁定技术栈：Godot 4.7 stable + GDScript + Compatibility 渲染
- 远端仓库：`https://github.com/gongfpp/RogueMaze.git`

## 文档入口

- [项目章程](docs/00-project/PROJECT_CHARTER.md)
- [游戏设计文档 GDD](docs/01-design/GDD.md)
- [MVP 范围](docs/01-design/MVP_SCOPE.md)
- [开发计划与里程碑](docs/02-production/DEVELOPMENT_PLAN.md)
- [产品待办列表](docs/02-production/BACKLOG.md)
- [项目管理与质量流程](docs/02-production/WORKFLOW.md)
- [技术架构草案](docs/03-technical/ARCHITECTURE.md)
- [工具链与四平台构建](docs/03-technical/TOOLCHAIN.md)
- [开发日志](docs/04-devlog/README.md)
- [游戏开发实战教学](docs/05-tutorial/README.md)
- [零基础成员从这里开始](docs/05-tutorial/START_HERE.md)
- [风险登记册](docs/02-production/RISK_REGISTER.md)

## 当前可运行内容

当前仓库同时保留 Node.js 可执行规格和已经移植的 Godot/GDScript 规则。安装本地工具链后运行：

```powershell
npm test
.\scripts\test_all.ps1
```

Node 原型见 [prototypes/rules](prototypes/rules/README.md)，Godot 规则位于 `game/domain`。Node 代码不会进入正式游戏包。

当前操作：点击或拖动手牌到绿色格子；`R`/右键旋转；数字键 `1–4` 选牌；空格暂停。`SFX ON/OFF` 切换操作音效。角色会在 4 秒后自动出发。完成三个节点即赢得远征；节点间选择一张奖励牌，途中需要处理尖刺和定时落石。

## 每轮协作约定

每次开发按计划领取一个可完成、可验证的小工作包；完成后如果时间和上下文允许，可以继续下一个，不人为停在半路：

1. 从计划内选择一个最高优先级条目，确认验收标准。
2. 只实现该工作包，不顺手扩张范围。
3. 执行测试、试玩或文档审查。
4. 更新待办、开发日志、变更记录和相关教学。
5. 每轮至少创建一次 Git commit；较长迭代可按稳定检查点多次提交。
6. 推送到项目远端；只有真实的权限、安全或外部资源问题才暂停。

详见 [WORKFLOW.md](docs/02-production/WORKFLOW.md)。
