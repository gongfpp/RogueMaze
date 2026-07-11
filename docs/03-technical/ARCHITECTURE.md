# 技术架构草案

状态：预制作草案。仅定义边界，不代表已创建工程。

## 1. 技术方向

- 引擎：暂定 Godot 4.x 稳定版，具体版本由 `WP-002` 验证并锁定。
- 语言：GDScript，用于快速迭代；性能热点测量后再考虑原生扩展。
- 目标：Android、iOS、Windows、Linux 共用规则和内容层。
- 画面：2D，逻辑网格与视觉表现解耦；移动与桌面使用可替换的输入映射和响应式界面布局。
- 配置：资源文件或可校验的数据对象；卡牌、陷阱、关卡不把数值散落在场景脚本中。
- 随机：所有影响玩法的随机数从单局种子派生，支持复现失败和测试。

选择依据与替代条件见 [ADR-0001](decisions/ADR-0001-engine-and-stack.md)。

## 2. 分层

```text
UI / Input
    ↓ command
Game Session Orchestrator
    ↓
Pure Domain Rules ─── Content Definitions
    ↓ events
Presentation / Audio / Haptics
    ↓
Platform Services (save, lifecycle, analytics opt-in)
```

- **Domain**：网格、端口、路块、牌组、角色状态、胜负与种子随机。尽量不依赖 Godot 节点，便于测试。
- **Application**：管理一局的阶段、命令与事件，协调 Domain。
- **Presentation**：场景节点、动画、相机、音效和反馈，不决定规则。
- **Infrastructure**：存档、移动端生命周期、桌面窗口、文件路径、构建和可选服务。

## 3. 建议工程结构

```text
RogueMaze/
├─ project.godot
├─ game/
│  ├─ domain/
│  ├─ application/
│  ├─ presentation/
│  ├─ content/
│  └─ platform/
├─ assets/
│  ├─ art/
│  ├─ audio/
│  └─ fonts/
├─ tests/
│  ├─ unit/
│  ├─ integration/
│  └─ fixtures/
├─ tools/
└─ docs/
```

只有在 `WP-010` 创建工程时才落地这些目录，避免空架构先于真实需求。

## 4. 核心数据模型草案

- `GridPosition(x, y)`：不可变网格坐标。
- `Direction`：左/右/上/下，提供反方向映射。
- `RoadDefinition`：卡牌静态定义、端口和关键词。
- `PlacedRoad`：定义引用、坐标、旋转、耐久和运行时状态。
- `BoardState`：边界、占用与放置/连接查询。
- `DeckState`：抽牌堆、手牌、弃牌堆、循环策略。
- `RunnerState`：所在路段、进度、生命和状态效果。
- `RunState`：种子、节点、资源、胜负和版本。

UI 只发送 `PlaceRoadCommand`、`RotatePreviewCommand` 等意图；规则层返回成功事件或带原因的拒绝结果。

## 5. 关键技术原则

- 确定性：相同版本、配置、输入和种子应得到相同逻辑结果。
- 数据驱动：新增普通卡牌尽量不改流程代码。
- 可观察：开发构建可查看牌堆、种子、网格端口和状态事件。
- 多平台输入：触摸、鼠标和键盘都转换为相同的游戏命令，不复制规则代码。
- 平台差异隔离：后台/恢复、安全区、窗口缩放和文件路径留在平台层。
- 无隐式全局状态：全局服务保持最少，单局状态可重建和测试。

## 6. 首批测试边界

- 旋转后端口变换。
- 相邻端口双向匹配。
- 越界、重叠和孤立路块拒绝原因。
- 固定顺序与随机洗回在种子下可复现。
- 角色到达端口时选择下一路段或明确失败。

## 7. WP-001 已验证规则

- 坐标从 `(0, 0)` 开始，`x` 向右、`y` 向下。
- 道路接口使用左、上、右、下四个离散方向，旋转以顺时针 90 度为一步。
- 新道路必须至少连接一块已有道路；相邻道路若只有一侧开口，则明确返回 `PORT_MISMATCH`。
- 越界、重叠、接口不匹配和孤立放置分别返回不同失败原因，方便 UI 给玩家准确反馈。
- 路径连通使用图搜索判断，不让画面节点决定胜负。
- 固定循环与弃牌洗回共用一个牌组接口；后者从单局种子派生随机顺序。

当前实现位于 `prototypes/rules`，是 Node.js 可执行规格。`WP-011` 会把同样的规则和测试样例移植到 Godot/GDScript；正式游戏不依赖 Node.js。
