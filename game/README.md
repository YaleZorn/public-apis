# Kongfu Roguelike — v0.12.0 · 主环竖切

竖屏、离线武侠健身。相对 v0.11：**重绑核心欲望环**，不再堆模式入口。

- **幻想主线**：地铁江湖梦 · 练班子守栈道（标题 / 大厅可读）
- **核心环**：花名册欲望 → 守栈道 TD → Idle 长成 **或** 搜山补给 → 再守
- **模式不平等**：TD 主场 · Idle 枢纽 · 搜山按需；**爬塔 / 演武移出 v1 路径**
- **前 10 分钟**：标题直入教学波 → 具名立功 → 花名册一眼 → 一条功法笺 → 「再守 / 搜山」
- **大厅**：一条叙事下一步，不是工具盘
- 仍标 **内容分级：17+**；离线无 IAP；合法 OSS only

设计依据（Project store）：
- `docs/gameplay-design.md`
- `docs/project-context.md`
- `docs/why-primitive.md`

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

见 `media/builds/README-sideload.md`；debug APK 可直接 `adb install`。

## 冒烟

```bash
cd game
godot --headless --path . --script res://tests/smoke_test.gd
godot --headless --path . --script res://tests/boot_scenes.gd
godot --headless --path . --script res://tests/gameplay_smoke.gd
```
