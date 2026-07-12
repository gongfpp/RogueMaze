# 2026-07-12：WP-025C Android 真机部署门禁（进行中）

## 新的外部条件

用户说明已有 Android 手机通过 USB 连接并开启 USB 调试，可授权直接安装 APK 和试玩。这解除了“没有真机”的条件，但不自动证明 Windows 驱动、ADB、SDK 或 RSA 授权已经就绪，也不代表代理可以代替用户接受 Android SDK 许可。

## 本轮实际检查

- 当前终端的 PATH 没有 `adb`，`ANDROID_HOME`/`ANDROID_SDK_ROOT` 为空。
- 仓库 `.tools/android-sdk`、Android Studio 默认 SDK 路径和几个常见自定义目录均不存在。
- 第一轮按 Android/ADB/WPD 名称过滤没有发现手机；随后枚举全部 USB VID，找到状态为 OK 的 `Redmi Note 8 Pro`（Google USB VID `18D1`）。这说明驱动链存在，首次过滤只是漏检。
- Android Studio/Unity 完整 SDK 不存在，但已安装 SideQuest 带有 ADB 34.0.5。项目改为可发现这个合法现有工具，不重复下载。
- `adb devices -l` 显示手机为 `device`，不是 unauthorized：产品 `begonia`，RSA 已授权。
- 真机为 Xiaomi Redmi Note 8 Pro、`arm64-v8a`、API 29；符合当前最低 API 24 和 arm64 APK 预设。包名查询确认 RogueMaze 尚未安装。
- 平台状态从原来的 5/12 细分为 7/14：新增的 `ADB executable`、`Authorized device` 已为 YES；SDK root、Build Tools、Platform 35、NDK 仍为 NO。

这意味着 USB/驱动/ADB/RSA/ABI 门禁已经通过；当前唯一 Android 工具链缺口是用于生成 APK 的完整 SDK，仍不能伪造安装通过。

## 已完成的工程准备

- 新增 `deploy_android_device.ps1`：按 PATH、环境变量、仓库 SDK、Android Studio 默认目录定位 ADB。
- 只接受恰好一台已授权设备；多设备要求显式 `-Serial`，unauthorized 给出解锁/RSA 提示。
- 安装前检查 arm64 ABI 和 APK 非空；使用 `adb install -r`，通过 launcher intent 启动。
- 启动 3 秒后验证进程仍存在，按 PID 读取日志并拒绝 Android/Godot 致命错误。
- 输出不含个人数据的设备报告；可选截图，应用保持运行供人工触屏试玩。
- 平台检查脚本同步报告 ADB 和授权设备，不再只看 SDK 文件夹。

## 当前验证

脚本先在缺少 ADB 的搜索范围中按预期快速失败；加入 SideQuest 路径后，平台检查能看到 ADB 34.0.5 和唯一已授权真机。`-SkipInstall` 已真实跑到设备属性和 launcher 阶段，并因包尚未安装而准确报告 `No activities found`，没有把 ADB 的正常 stderr 提示误判成 PowerShell 异常。尚未生成 APK、安装、启动或采集真机截图。

## 下一门禁

1. 用户明确确认 Android SDK 许可后，安装仓库锁定的 Platform Tools、Build Tools 35.0.1、Platform 35、NDK r28b。
2. 已完成：Windows 与 `adb devices -l` 能看到手机，RSA 已授权，arm64/API 29 已确认。
3. 构建 APK，运行 `deploy_android_device.ps1 -CaptureScreenshot`。
4. 人工完成放路、旋转、奖励、暂停/切后台、结算和重开；记录 Build、设备 API、截图、日志与 20 分钟结果。

WP-025 与 WP-025C 保持 ACTIVE。
