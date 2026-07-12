# Android 真机试玩检查表

## 自动部署前

- [ ] 手机电量足够，使用可传数据的 USB 线。
- [ ] USB 调试开启，USB 模式不是“仅充电”。
- [ ] Windows 设备管理器能看到手机或 Android ADB Interface。
- [ ] 手机已解锁并确认本电脑 RSA 指纹。
- [ ] `check_platforms.ps1` 的 ADB 与 Authorized device 为 YES。
- [ ] 测试者同意记录匿名操作观察；截图不包含通知、联系人等个人信息。

## 自动 smoke

```powershell
.\scripts\build_releases.ps1 -Android
.\scripts\deploy_android_device.ps1 -CaptureScreenshot
```

- [ ] APK 安装成功。
- [ ] 应用进程启动后保持运行。
- [ ] PID 日志没有 Android/Godot 致命错误。
- [ ] 报告记录设备型号、API、ABI、包路径和 UTC 时间。
- [ ] 截图中的 Build 显示 ANDROID 与 DEBUG。

## 人工触屏与生命周期

- [ ] 点击和拖拽都能放路，四张手牌可触达。
- [ ] 旋转、暂停、SFX、FX LOW 按钮不被刘海/圆角/导航区遮挡。
- [ ] 奖励三选一能点击；胜负页数据和 Build 可读。
- [ ] Android 返回键进入暂停，不直接丢失本局。
- [ ] 切到其他 App 再回来，本局暂停且设置/进度仍在。
- [ ] 锁屏/解锁后没有偷偷推进角色。
- [ ] 竖屏旋转策略符合预期，没有拉伸或触控偏移。
- [ ] 连续运行 20 分钟无闪退、明显发热失控或持续卡顿。

## 结果

- Build：
- 设备编号（不用真实姓名）：
- Android API / ABI：
- 自动报告路径：
- 截图路径：
- 20 分钟结果：通过 / 失败
- 阻断问题与最小复现：
