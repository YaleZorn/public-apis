# Kongfu Roguelike — v0.11.0 · Feel like a game

竖屏、离线武侠健身。相对 v0.10.1 本版专注 **前 5 分钟像游戏**：

- **引导 / 下一步**：标题「踏上栈道」→ 大厅固定展示一条「下一步」任务卡 → 首局塔防分步提示
- **大厅枢纽**：少按钮；探索 / 爬塔 / 演武按波次进度软锁；推荐出战英雄；去掉密排花名册与版本/包名噪音
- **TD 手感**：放置震颤 + 落脚环；击杀/波清横幅奖励；第一章与三波解锁文案
- **产品观感**：墨雾青玉面板层次，非工程师工具盘
- 仍标 **内容分级：17+**；离线无 IAP；合法 OSS only

设计依据（Project store）：
- `docs/gameplay-design.md`
- `docs/project-context.md`
- `docs/character-presentation.md`

包协议说明：[`data/CONTENT_PACKS.md`](./data/CONTENT_PACKS.md)  
第三方声明：[`THIRD_PARTY.md`](./THIRD_PARTY.md)（合法 OSS only）。

## 要求

- [Godot 4.3+](https://godotengine.org/)
- 竖屏 720×1280（项目已配置）

## 本地运行

```bash
cd game
godot4 --path .
# 无 GPU / CI：
godot --path . --rendering-driver opengl3
```

## Android APK（侧载）

见同版本交付说明；debug APK 可直接 `adb install`。开启「允许未知来源」后安装。

## 冒烟

```bash
cd game
godot --headless --path . --script res://tests/smoke_test.gd
godot --headless --path . --script res://tests/boot_scenes.gd
godot --headless --path . --script res://tests/gameplay_smoke.gd
```
