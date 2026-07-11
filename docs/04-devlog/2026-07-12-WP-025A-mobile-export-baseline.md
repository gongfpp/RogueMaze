# 2026-07-12：WP-025A 移动导出基线

## 这轮完成什么

玩法进入 Alpha 后，四平台不能继续只停留在一句“以后支持”。本轮先把不需要开发者私密身份的工程部分落地，并把真正需要负责人授权或硬件的部分明确留在门禁里。

- 增加 Android arm64 APK 导出预设：最低 API 24、目标 API 35、沉浸式竖屏、不申请网络/震动等未使用权限。
- 增加 iOS arm64 Xcode 工程预设：最低 iOS 15、iPhone/iPad、Compatibility 渲染共用。
- Android 包名和 iOS Bundle ID 暂定为 `com.gongfpp.roguemaze`；首次商店建档前由发行负责人确认所有权和唯一性，之后不得随便修改。
- 新增平台检查脚本，明确列出 SDK、Build Tools、Platform、NDK、Xcode 和 Team ID 哪一项缺失。
- 新增统一桌面/Android 构建脚本和 macOS iOS 构建脚本。iOS Team ID 只在构建时临时注入，脚本退出会恢复空占位，不提交团队身份。
- 新增 Android SDK 安装脚本，但必须由有权限的人显式传入 `-AcceptAndroidSdkLicense`；自动开发过程不会代表个人或公司接受法律协议。
- UI 布局在 Android/iOS 上使用系统安全矩形，避免暂停、卡牌和按钮落进刘海或圆角区域。
- 生成并接入 1024×1024 原创纸片机械应用图标，记录提示词和文件哈希；源 PNG 无损优化后为 1,893,321 字节。

## 已验证

- Godot 能读取四个平台预设；当前只报告 Android SDK 目录缺失，没有预设语法错误。
- Android 调试导出按预期停在缺失 `platform-tools` 与 `build-tools`；同时确认 Godot 可能在导出失败时返回 0，构建脚本已增加日志失败词门禁，避免 CI 假绿。
- 平台检查结果为 5/12：四个预设、JDK 17 已就绪；Android SDK 五项和 iOS 的 macOS/Xcode、Team ID 尚未就绪。
- Windows/Linux 在本轮玩法版本仍能成功导出；新增图标后需要再次跑全量构建记录包体。
- 桌面 405×720 使用完整安全矩形，现有截图布局不变。

## 明确阻塞，不伪造完成

Android SDK 下载页要求接受具有法律约束力的许可，必须由有权主体确认。iOS 官方要求在 macOS + Xcode 上导出，还需要 10 位 Team ID、签名身份和真机。Windows 不能替代这两项证据。

WP-025 保持 ACTIVE。完成条件仍是：Android 真机安装/触屏冒烟、iOS Xcode 构建/真机冒烟、Linux 真实系统启动，以及 Windows 回归记录。
