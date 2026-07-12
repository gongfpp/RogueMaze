# 构建身份文件

`build_info.json` 会在导出前生成并装进游戏包。它不会提交到 Git，构建结束后也会自动删除，避免一次构建把工作树弄脏。

只有排查工具问题时才手动运行 `node scripts/generate_build_info.mjs --platform windows`。正常情况下，请使用 Windows、Linux、Android、iOS 各自的构建入口，它们会填写正确的平台和配置。
