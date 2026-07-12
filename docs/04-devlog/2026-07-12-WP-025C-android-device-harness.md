# 2026-07-12：WP-025C Android 真机部署门禁（进行中）

## 新的外部条件

用户说明已有 Android 手机通过 USB 连接并开启 USB 调试，可授权直接安装 APK 和试玩。这解除了“没有真机”的条件，但不自动证明 Windows 驱动、ADB、SDK 或 RSA 授权已经就绪，也不代表代理可以代替用户接受 Android SDK 许可。

## 本轮实际检查

- 当前终端的 PATH 没有 `adb`，`ANDROID_HOME`/`ANDROID_SDK_ROOT` 为空。
- 仓库 `.tools/android-sdk`、Android Studio 默认 SDK 路径和几个常见自定义目录均不存在。
- Windows PnP/CIM 的已连接设备中没有 Android、ADB 或 WPD 手机条目；只出现了无关的 USB 麦克风。
- 平台状态从原来的 5/12 细分为 5/14：新增 `ADB executable`、`Authorized device` 两项，当前均为 NO。

这意味着“手机上打开 USB 调试”与“本终端能部署 APK”之间仍缺工具和/或驱动链路，不能伪造真机通过。

## 已完成的工程准备

- 新增 `deploy_android_device.ps1`：按 PATH、环境变量、仓库 SDK、Android Studio 默认目录定位 ADB。
- 只接受恰好一台已授权设备；多设备要求显式 `-Serial`，unauthorized 给出解锁/RSA 提示。
- 安装前检查 arm64 ABI 和 APK 非空；使用 `adb install -r`，通过 launcher intent 启动。
- 启动 3 秒后验证进程仍存在，按 PID 读取日志并拒绝 Android/Godot 致命错误。
- 输出不含个人数据的设备报告；可选截图，应用保持运行供人工触屏试玩。
- 平台检查脚本同步报告 ADB 和授权设备，不再只看 SDK 文件夹。

## 当前验证

脚本在缺少 ADB 的真实环境中按预期快速失败，并明确给出两条合法路径：设置已有 SDK，或由有权主体阅读许可后运行安装脚本。尚未生成 APK、安装、启动或采集真机截图。

## 下一门禁

1. 用户明确确认 Android SDK 许可后，安装仓库锁定的 Platform Tools、Build Tools 35.0.1、Platform 35、NDK r28b。
2. Windows 能在 PnP 和 `adb devices -l` 中看到手机，手机端接受 RSA 指纹。
3. 构建 APK，运行 `deploy_android_device.ps1 -CaptureScreenshot`。
4. 人工完成放路、旋转、奖励、暂停/切后台、结算和重开；记录 Build、设备 API、截图、日志与 20 分钟结果。

WP-025 与 WP-025C 保持 ACTIVE。
