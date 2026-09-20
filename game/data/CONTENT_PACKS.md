# content_pack 协议（离线 · 无 IAP）

本地挂载可选内容包。无应用商店计费、无内购墙；`owned` 仅表示本机构是否加载该包数据。

## 目录约定

```
game/data/
  content_pack_core/           # 必装核心包
    manifest.json
    units.json · enemies.json · waves.json · rooms.json
    knowledge.json · gear.json · materials.json · idle.json
    arena.json · tower.json
  content_pack_<id>/           # 可选包（示例：content_pack_demo_mountain）
    manifest.json              # 必填
    <module>.json              # 按 modules 列表提供
```

目录名前缀必须是 `content_pack_`。`ContentDB` 启动时扫描 `res://data/`，按包合并索引。

## manifest.json

```json
{
  "content_pack": "demo_mountain",
  "version": 1,
  "display_name": "演示包 · 山野补遗",
  "blurb": "说明文字",
  "owned": true,
  "demo": true,
  "modules": ["units", "knowledge", "gear"]
}
```

| 字段 | 含义 |
| --- | --- |
| `content_pack` | 稳定 id（与目录后缀一致） |
| `owned` | `true` → 合并进运行时数据；`false` → 仅出现在包列表（可灰显），不合并 |
| `modules` | 本包提供的模块；未列出的文件可省略 |
| `demo` | 可选标记：仓库内假 DLC，证明扩展接缝 |

**核心包 `core` 始终视为已拥有。**

可选：存档 meta `owned_content_packs: ["demo_mountain"]` 也可在 `manifest.owned=false` 时本地解锁（仍无商店）。

## 合并规则

- 同 id 后写覆盖先写（先加载 core，再可选包）。
- 条目建议带 `"content_pack": "<id>"` 便于溯源。
- 知识条目支持 `mode_hooks: [{ "mode", "hook" }]`，并兼容 `td_hook` / `explore_hook` / `tower_hook`。

## 如何新增一包

1. 复制 `content_pack_demo_mountain/` 为 `content_pack_my_theme/`。
2. 改 `manifest.json` 的 `content_pack` / `display_name` / `modules`。
3. 只放需要的 JSON（角色、知识、装备、或关卡表）。
4. 设 `"owned": true` 做本地试玩；发售时可改为默认 `false`，日后再用本地解锁列表打开。
5. 跑冒烟：`godot --headless --path . --script res://tests/smoke_test.gd`

## 仓库内演示包

`content_pack_demo_mountain`：花木兰单位 + 4 张山野知识 + 山野行囊符。大厅 / 知识本可看到「已挂载包」列表。
