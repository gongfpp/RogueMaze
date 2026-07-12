# 工具链与四平台构建

这份文档只写团队现在真正需要的工具和命令。版本升级必须单独验证，不能看到新版本就直接换。

## 已锁定版本

- 游戏引擎：Godot 4.7 stable，标准版，不使用 .NET 版。
- 游戏脚本：GDScript。
- 渲染：Compatibility，优先覆盖低端移动设备和普通桌面显卡。
- 规则原型：Node.js 20+，只用于开发验证，不进入游戏包。
- Android Java：OpenJDK 17。

选择 4.7 stable 是因为它是 2026-06-18 发布的正式稳定版。4.7.1 当前仍是 RC，4.8 是开发版，都不进入生产基线。

## Windows 本机准备

Godot 是便携程序，不需要安装到系统：

1. 下载 `Godot_v4.7-stable_win64.exe.zip` 和标准导出模板。
2. 编辑器解压到 `.tools/godot`。
3. 在编辑器同目录放一个 `_sc_` 空文件，启用自包含模式。
4. 将模板解压到 `.tools/godot/editor_data/export_templates/4.7.stable`。

`.tools` 已被 Git 忽略。不要提交 1 GB 以上的编辑器和模板。

运行 Godot 测试：

```powershell
.\scripts\run_godot.ps1 --headless --path . --script tests\godot\test_runner.gd
```

运行 Node 和 Godot 全部测试：

```powershell
.\scripts\test_all.ps1
```

脚本把开发期用户目录放到 `.tools/user-data`。这只为避免 CI、沙箱和公共电脑污染用户目录，不改变正式游戏的存档位置。

## Linux 本机准备

1. 下载 Godot 4.7 stable 标准版，或让 `godot` 命令指向该版本。
2. 安装 Node.js 20+。
3. 给脚本执行权限：`chmod +x scripts/*.sh`。
4. 运行 `./scripts/test_all.sh`。

也可以设置 `GODOT_BIN=/path/to/godot` 指定编辑器。脚本会把 XDG 开发缓存放进 `.tools`。

## 当前四平台结论

| 平台 | 当前能做到什么 | 还缺什么 |
| --- | --- | --- |
| Windows x86_64 | 本机全量测试、release 导出和控制台包装器成品 smoke 均通过 | Beta 前补更多分辨率与 20 分钟人工回归 |
| Linux x86_64 | Windows 本机与 Ubuntu 24.04 CI 可导出；正式二进制 smoke 和 artifact 上传已通过 | Beta 前补真实桌面交互与 20 分钟人工回归 |
| Android | arm64 APK 预设、Godot 模板、JDK 17、检查/构建脚本已就绪 | 有权主体接受 Android SDK 许可后安装锁定 SDK；生成 APK 并上真机 |
| iOS | arm64 Xcode 工程预设、临时 Team ID 注入脚本已就绪 | 必须有 macOS、Xcode、Team ID、签名和 iPhone/iPad |

Android 当前官方要求包括 Platform Tools 35.0.0+、Build Tools 35.0.1、Platform 35、CMake 3.10.2 和 NDK r28b。获得许可确认后安装到 `.tools/android-sdk`，不写入系统目录。

查看当前平台缺项：

```powershell
.\scripts\check_platforms.ps1
```

有权接受 Android SDK 许可的人阅读官方协议后，可运行：

```powershell
.\scripts\setup_android_sdk.ps1 -AcceptAndroidSdkLicense
.\scripts\build_releases.ps1 -Android
```

macOS 发布机设置 10 位 Apple Team ID 后运行：

```bash
export GODOT_IOS_TEAM_ID=ABCDE12XYZ
./scripts/build_ios.sh
```

Android 发布版 AAB 需要 Gradle 构建和团队 release keystore；当前自动化只生成本地调试 APK，绝不把 keystore 或密码提交到仓库。

## 为什么暂时不用 C#

GDScript 足以承载当前 2D 规则，编辑和导出链更短。Godot 4 的 C# 移动端支持仍会增加 SDK 与兼容性变量。只有实测性能或团队技能证明值得时才重新评估。

## 版本升级规则

- 补丁稳定版发布后，先在分支运行全测试和四平台导出，再更新锁定版本。
- RC、beta、dev 不进入 `main`。
- 升级后更新 ADR、本文、开发日志和构建脚本。
