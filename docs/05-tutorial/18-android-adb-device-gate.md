# 第 18 章：手机开了 USB 调试，为什么电脑还是看不到

读完这一章，你能把 Android 真机部署拆成几个独立环节，运行项目的诊断/部署脚本，并用准确证据报告卡在哪一层。

## 五个常被混在一起的环节

1. **USB 物理连接**：线缆能传数据，不是只能充电。
2. **Windows 设备与驱动**：设备管理器能识别手机、MTP 或 Android ADB Interface。
3. **ADB 程序**：电脑上有 `adb.exe`，来自 Android Platform Tools。
4. **手机授权**：`adb devices` 显示 `device`，不是 `unauthorized` 或 `offline`；首次连接要在手机上确认 RSA 指纹。
5. **应用工具链**：有 Platform 35、Build Tools 35.0.1 等，能够先生成 APK，再安装。

手机里打开“USB 调试”只完成了手机侧的一部分。电脑没有 ADB 时，连 `adb devices` 这句话都无法执行。

## 先看门禁，不猜

```powershell
.\scripts\check_platforms.ps1
```

关注 Android 的这些行：SDK root、Platform Tools、Build Tools、Platform 35、ADB executable、Authorized device。`Export preset YES` 只说明项目配置存在，不代表 APK 已经生成。

常见设备状态：

- `device`：已授权，可以继续。
- `unauthorized`：解锁手机，确认 RSA 弹窗；不要盲目重装 Godot。
- `offline`：重插数据线、切换 USB 模式或重启 ADB 后再查。
- 没有设备行：先看线缆、USB 模式和 Windows 驱动。

## SDK 许可为什么要本人确认

仓库锁定了安装版本，也能自动校验下载文件，但 Google SDK 仍有许可协议。代理或脚本不能替个人/公司声称有权接受。

有权成员阅读协议后，显式运行：

```powershell
.\scripts\setup_android_sdk.ps1 -AcceptAndroidSdkLicense
```

这会安装到仓库 `.tools/android-sdk`，不污染系统 SDK，也不会提交 Git。

## 构建、安装和启动

```powershell
.\scripts\build_releases.ps1 -Android
.\scripts\deploy_android_device.ps1 -CaptureScreenshot
```

部署脚本会：

1. 找到 ADB 并选择唯一已授权设备。
2. 确认手机是 arm64。
3. 用 `adb install -r` 保留应用数据并覆盖调试包。
4. 从 launcher 启动 RogueMaze。
5. 等 3 秒确认进程存在，读取该进程日志。
6. 发现 `FATAL EXCEPTION`、GDScript 解析错误等就失败。
7. 输出设备报告和可选截图，游戏留在手机上供你继续触摸试玩。

多台设备时传序列号：

```powershell
.\scripts\deploy_android_device.ps1 -Serial ABC123 -CaptureScreenshot
```

序列号用于选择设备。公开日志前仍应检查它是否属于团队不希望外传的设备信息。

## “进程启动”仍不等于真机验收

自动 smoke 只能证明安装、入口和前几秒日志。人工还要做：

- 触摸/拖拽四张牌、旋转、奖励选择。
- 刘海/圆角/系统导航区没有遮挡。
- 返回键和切后台会暂停并保存。
- 声音开关、减少动态效果、结算与重开正常。
- 至少运行 20 分钟，记录温度、帧率感受、闪退和内存异常。

报告应写“Pixel 设备 API 35，APK 安装/启动 smoke 通过，人工 20 分钟通过”，而不是“Android 应该没问题”。
