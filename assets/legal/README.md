# 发行声明文件

- `GODOT_LICENSE.txt`：Godot Engine MIT 许可证正文。
- `GODOT_COPYRIGHT.txt`：直接取自 Godot 官方源码标签 `4.7-stable`，包含引擎及其第三方组件的完整版权与许可证清单。
- `CREDITS.txt`：本项目当前署名和资产来源摘要。

`GODOT_COPYRIGHT.txt` SHA-256：`CB1980C88089573BCACD7221D777C689BB8BBD778799F24C27FCA0FE5F774D6D`

四个平台导出预设用 `include_filter="assets/legal/*.txt"` 强制携带这些文件。更新 Godot 版本时必须从对应稳定标签重新取得版权清单、更新哈希并重新导出验证。
