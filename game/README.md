# Kongfu Roguelike — M4 演武场 + M5 爬塔（v0.8.0）

竖屏、离线武侠健身题材。叠在 M3 搜打撤之上：

- **M4 演武场**：生存 ramp · 自动普攻+主动技 · 随时下场结算修为/熟练度
- **M5 爬塔**：纵向层表 · 清层进阶 · 层间存档 · 后期专属装备（与探索池分离）

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

### 演武场怎么玩

1. 大厅选英雄肖像 → **演武场 · 生存练功**
2. 敌人持续刷出并随时间变强；自动普攻，点主动技
3. 右上墨雾肖像 + 存活/击杀 HUD
4. 随时 **下场结算**（或力竭）→ 熟练度 / 修为 / 少量银两入库
5. 软存档约每 5s；大厅可续关演武

### 爬塔怎么玩

1. 大厅选英雄 → **爬塔 · 纵向进度**
2. 清当前层敌人 → 层奖（材料/碎片/武学草稿）
3. **下一层** 或 **存档并回大厅**（层间可中断）
4. 第 5 层起可掉 **剑阁残锋**（`pool: tower_exclusive`，不进探索掉落）

### 探索 / TD / Idle

仍按原路径：大厅新局塔防、探索搜打撤、名人花名册 Idle。

## 冒烟

```bash
cd game
godot --headless --path . --script res://tests/smoke_test.gd
godot --headless --path . --script res://tests/boot_scenes.gd
godot --headless --path . --script res://tests/gameplay_smoke.gd
```

## 截图

- Project store `media/m4-arena/`
- Project store `media/m5-tower/`
