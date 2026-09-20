# Kongfu Roguelike — M1 TD 嫁接（v0.4.0）

竖屏、离线武侠健身题材。**M1：守卫剑阁式无限波塔防** — ape1121 MIT 战斗核思路嫁入现有 `game/` 壳（标题/大厅/美术/ContentDB/存档/知识保留）。

设计依据（Project store）：
- `docs/gameplay-design.md`
- `docs/project-context.md`
- `docs/base-game-candidates.md`

第三方声明：见 [`THIRD_PARTY.md`](./THIRD_PARTY.md)（合法 OSS only）。

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

大厅 → **新局 · 塔防** → 底栏选角色卡放置 → **下一波**。波间可「存档并回大厅」。

## M1 已交付

- 无限（或极高上限）波次 escalate（`scripts/td/wave_director.gd`，源自 ape1121 spawner 曲线）
- 玩家点按 **下一波**；波间布阵 / 回收 / 存档
- 敌军默认 **上→下**；第 3/6/8/10… 波含 **侧翼伏击** 路
- 阵容角色卡放置/回收（肖像映射 turret → Kongfu units）
- 大厅入口 + Idle/爬塔/演武场灰显 stubs
- 离线无 IAP；冒烟测试通过

## 冒烟

```bash
cd game
godot --headless --path . --script res://tests/smoke_test.gd
godot --headless --path . --script res://tests/boot_scenes.gd
godot --headless --path . --script res://tests/gameplay_smoke.gd
```

## 截图

Project store `media/m1-td/`。
