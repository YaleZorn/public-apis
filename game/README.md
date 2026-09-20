# Kongfu Roguelike — M3 探索搜打撤（v0.6.0）

竖屏、离线武侠健身题材。**M3：荒山搜打撤** — 饥荒气质节点图 + 搜材料 / 打遭遇 / 撤据点结算；材料进共享 meta 与薄打造；叠在 M2 Idle 名人 + M1 无限波 TD 之上。

设计依据（Project store）：
- `docs/gameplay-design.md`
- `docs/project-context.md`
- `docs/base-game-candidates.md`

第三方声明：见 [`THIRD_PARTY.md`](./THIRD_PARTY.md)（合法 OSS only · AutoCombatKit / expressobits 思路归因）。

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

### 搜打撤怎么玩

1. 大厅选探索英雄（花名册肖像）→ **新局 · 探索搜打撤**
2. **山门据点**：看出路 / 入库背包 / 薄打造（麻布护腕、武学草稿等）
3. **搜**：药草坡、弃械小径、玉屑密龛 → 材料进本趟背包
4. **打**：自动普攻 + 点主动技；清场掉材料/碎片
5. **撤**：非战斗可「回据点」；据点「撤离回大厅」全额入库；战斗中撤离保留约半袋；力竭保留约四成
6. 节点边界 / 非战斗「存档并回大厅」可中断续关

爬塔 / 演武仍为大厅 stubs。

## M3 已交付

- 节点图 `rooms.json`（settle / gather / combat / event / supply / loot）
- 本趟背包 `run_bag.gd` + 共享 `materials_inv` + `materials.json` 配方
- 自动战 + 主动技；夜压（访节点过多后敌攻↑）
- 撤离结算比例；存档 v3（材料库存迁移）
- 大厅探索为真实模式文案；墨雾肖像保留
- 离线无 IAP；冒烟含 explore gather/combat/withdraw

## 冒烟

```bash
cd game
godot --headless --path . --script res://tests/smoke_test.gd
godot --headless --path . --script res://tests/boot_scenes.gd
godot --headless --path . --script res://tests/gameplay_smoke.gd
```

## 截图

Project store `media/m3-explore/`。
