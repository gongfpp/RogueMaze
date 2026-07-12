# 2026-07-12：WP-038 可追溯试玩构建

## 为什么做

测试者说“昨天那个包在第三关崩了”，团队仍然不知道是哪个提交、哪个平台、Debug 还是 Release。版本号 `0.4.0` 也不够，因为同一版本开发期间可能有几十个提交。本轮让每个导出包携带自己的构建身份证。

## 实际完成

- `generate_build_info.mjs` 从 `project.godot` 和 Git 生成 schema v1 JSON：版本、完整/短 SHA、平台、Debug/Release、UTC 时间、工作树是否有未提交修改。
- 只接受 Windows、Linux、Android、iOS 和两种构建配置；无效 SHA、平台、配置会直接失败。
- `BuildInfo` 负责读取与再次校验。编辑器没有生成文件时显示 `DEV` 身份，不伪装成发行包。
- 四平台预设强制带入 `assets/build/build_info.json`；Windows/Android 构建脚本、Linux CI、macOS iOS 脚本分别生成正确的平台值。
- 构建结束或失败都会删除临时 JSON；iOS 的 Team ID 占位恢复和身份清理共用退出 trap。
- 暂停页与胜负页显示 `版本 · 平台 · 短 SHA`；dirty 构建加 `*`，Android 调试包另标 `DEBUG`。
- 成品 smoke 拒绝缺失或非法身份。Windows 本地会比对预期 SHA，Linux CI 会和 `GITHUB_SHA` 比对。

## 验证结果

- Node 规则 15/15、构建工具 4/4。
- Godot 232 条断言、耐久 250 轮/37,253 条不变量通过。
- Windows release 成品输出：`v0.4.0 platform=windows configuration=release commit=383e92f`。
- Windows/Linux 打包清单均明确包含 `assets/build/build_info.json`；两平台导出成功。
- 构建结束后源目录不存在生成的 JSON，Git 状态没有构建噪声。
- 405×720 暂停页使用更长的 `EDITOR-WINDOWS` 开发标签检查，三行信息未溢出。

## 边界

- 本轮证明 Windows 成品和 Linux 打包路径；Linux 真实二进制由推送后的 Actions 再验证。
- Android/iOS 生成步骤已接入，但只有完成 WP-025 的 SDK、签名和真机构建后，才能证明移动包中的实际显示。
- dirty 星号不是错误，它提醒测试者这个包不是由纯净提交构建，不适合当正式候选。
