# 2026-07-12：WP-025B 生命周期与 CI

## 为什么做这一轮

手机游戏会频繁因来电、锁屏、切应用进入后台。如果角色继续自动走，玩家回来只会看到莫名失败；如果退出前没落盘，设置和进度也可能丢失。另一个长期风险是本机能跑，但新提交没有在干净 Linux 环境重现。

## 实现

- `GameSession.set_paused` 提供明确的幂等暂停入口，奖励/结算界面不会被误改成玩法暂停。
- 主场景收到应用暂停或窗口失焦时自动暂停，并同时保存设置和进度。
- Android 系统返回请求优先暂停游戏，不让一次误触直接退出正在进行的局。
- 场景退出时再次 `save_all`；两个文件分别尝试保存，不因第一个失败而跳过第二个。
- 新增 GitHub Actions：PR/推送在 Ubuntu 24.04 下载锁定 Godot 4.7 和 Node 22，运行全量测试；非 PR 在测试后缓存官方导出模板、生成 Linux x86_64 artifact。
- CI 和本地构建同样检查 Godot 的失败日志词，不能只信退出码。

## 验证

- Godot 断言增至 209 项，覆盖玩法阶段暂停/恢复、奖励阶段拒绝暂停和双文件保存。
- 主场景经过编辑器完整扫描，无通知常量或生命周期脚本编译错误。
- CI 工作流已做静态审阅；只有提交推送后才能取得 GitHub 执行证据，因此当前不能写成“CI 已通过”。

## 首次远端执行

- 推送 `d57802a` 后，Actions 运行 `29178277837` 在 `rules-and-godot-tests` 失败。
- Godot 4.7 Linux 编辑器下载成功；失败发生在运行测试脚本前：`scripts/test_all.sh: Permission denied`，退出码 126。
- 根因是 Windows 工作区提交时 shell 脚本保留为 `100644`。修复同时提交 Git 可执行位，并在 CI 中显式 `chmod +x scripts/*.sh`，避免未来工具再次丢失模式位。
- 修复提交 `06a9fb1` 触发运行 `29178388977`：`rules-and-godot-tests` 与 `linux-release` 均成功，Linux artifact 上传完成。这是首次真实 Ubuntu 24.04 远端绿灯。
- 该运行证明 Linux 环境能测试和导出，但尚未启动发布二进制；下一轮给正式包增加自退出 smoke 模式并纳入 CI。
- Windows 首次 smoke 使用 GUI 入口 `RogueMaze.exe`，PowerShell 无法可靠接收其标准输出，门禁正确失败。改用 Godot 同次导出的 `RogueMaze.console.exe` 包装器后，收到 `RogueMaze smoke: main scene ready` 且退出码为 0；游戏内容仍来自同一嵌入 PCK。
- 修复后本地 `build_releases.ps1 -Desktop` 完整通过：15 项 Node、214 项 Godot、Windows/Linux release 导出、Windows 正式包主场景 smoke 全部成功。

## 下一步

推送恢复后观察首次 Actions，修复真实 Linux 环境差异；与此同时等待 Android SDK 许可确认和 iOS 发布机信息。
