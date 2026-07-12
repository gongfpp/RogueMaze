# 2026-07-12：WP-035 发行声明与成品冒烟

## 目标

导出文件能启动还不等于可以合规分发。RogueMaze 使用 Godot Engine，发布包必须携带对应许可证与第三方版权信息；玩家也应该能在游戏内看到基本署名。

## 完成内容

- 从 Godot 官方源码标签 `4.7-stable` 取得完整 `COPYRIGHT.txt`，SHA-256 为 `CB1980C88089573BCACD7221D777C689BB8BBD778799F24C27FCA0FE5F774D6D`。
- `assets/legal` 同时保存 Godot MIT 正文、完整版权清单和 RogueMaze Credits。
- 四个平台的导出预设使用 `include_filter` 强制打包法律文本，不依赖未引用 `.txt` 的默认导出行为。
- 暂停界面显示 `Built with Godot Engine 4.7 · MIT` 与完整声明随包提示；405×720 截图确认不遮挡恢复按钮和手牌。
- 发布包 `--smoke` 会逐一确认三个法律文件在 `res://` 可见，再输出主场景就绪标记。
- 项目自身采用何种开源许可证仍由仓库所有者决定，本轮没有擅自添加代码 LICENSE。

## 成品 smoke 调试

Windows GUI 入口不会把标准输出可靠返回 PowerShell，因此本地门禁改用同次导出的 `.console.exe` 包装器；它加载的仍是同一个内嵌 PCK。Linux CI 直接运行正式 x86_64 二进制。

Actions 运行 `29178512602` 已证明 Ubuntu 24.04 上测试、导出、正式二进制启动和 artifact 上传全绿。

## 验证

- `build_releases.ps1 -Desktop` 必须同时看到 `legal notices ready` 和 `main scene ready`，否则失败。
- Linux CI 同样执行并检查成品标记。
- 公共发布前仍要由所有者确认项目代码许可证、商标相似性和商店隐私表单，这些不是技术脚本可以代签的决定。
