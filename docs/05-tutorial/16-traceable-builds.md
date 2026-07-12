# 第 16 章：先问“你玩的到底是哪一个包”

读完这一章，你能从 RogueMaze 暂停页读出一个构建的身份，知道版本号和 Git 提交为什么不是一回事，并能把可复现的信息写进缺陷记录。

## 一个常见的沟通事故

程序员上午和下午都导出了 `0.4.0`。上午包的落石有 bug，下午已经修好。测试者只写“0.4.0 落石坏了”，下一位成员无法判断报告是否仍然有效。

所以本项目的构建身份同时包含：

- `version`：给人理解的大版本，例如 `0.4.0`。
- `commit`：Git 对一份确定源码的编号；界面显示前 7 位，例如 `383e92f`。
- `platform`：Windows、Linux、Android 或 iOS。
- `configuration`：Release 或 Debug。
- `built_at_utc`：构建的协调世界时，避免不同时区互相猜。
- `dirty`：构建时是否有未提交修改。

Git SHA 不是密码。它只是仓库历史中的地址，适合放进测试报告。

## 在游戏里查看

游戏中点 `PAUSE`。署名下方会看到类似：

```text
v0.4.0 · WINDOWS · 383e92f
```

如果末尾有 `*`，例如 `383e92f*`，表示构建时还有未提交源码。它可以用于本机调试，但不要把它命名为发布候选。Android 当前自动化生成调试 APK，因此还会看到 `DEBUG`。

编辑器直接运行时没有正式 manifest，会显示 `EDITOR-WINDOWS · dev*`。这是诚实的开发回退，不是错误。

## 构建过程发生了什么

以 Windows 为例：

1. 全量测试通过。
2. Node 工具读取 `project.godot` 版本和当前 Git SHA，生成 `assets/build/build_info.json`。
3. Godot 导出预设把 JSON 强制装进 PCK。
4. 正式 `.console.exe` 启动，游戏再次校验 JSON，并输出身份标记。
5. 脚本比对版本、平台和 SHA；不一致就失败。
6. 无论成功或失败，源目录中的临时 JSON 都被删除。

生成文件不提交 Git，因为每次提交和平台都不同。应该提交的是生成器、校验器和构建规则。

## 自己验证

```powershell
.\scripts\build_releases.ps1 -Desktop
git status --short
```

成功日志应同时出现：

```text
RogueMaze smoke: build v0.4.0 platform=windows configuration=release commit=...
RogueMaze smoke: legal notices ready
RogueMaze smoke: main scene ready
```

随后 `git status --short` 不应只因为构建多出 `build_info.json`。

单独测试生成规则可运行：

```powershell
npm run test:tooling
```

不要手改生成的 JSON 来“让测试通过”。真正的修复位置是版本配置、Git 状态、生成器或构建脚本。

## 怎样写可复现的缺陷

最低限度记录：

```text
Build: v0.4.0 · WINDOWS · 383e92f
Result: 第 3 节点选择 ARMOR 后，落石仍摧毁道路
Expected: 护甲吸收一次落石并降级
Steps: ...
```

再附上结算页数据和操作步骤。这样即使修复已经进入新提交，团队也能取回原来的源码判断差异。

构建身份解决“是哪份代码”，不解决“为什么出错”；它是调试入口，不是质量本身。
