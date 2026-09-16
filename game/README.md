# Kongfu Roguelike — v0 Vertical Slice

竖屏、离线武侠健身题材原型。主线「守卫剑阁」式塔防 + 支线轻操作探索 + 真健身知识环。

设计依据（Project store）：
- `docs/gameplay-design.md`
- `docs/project-context.md`

## 要求

- [Godot 4.3+](https://godotengine.org/)（推荐 4.3 / 4.4）
- 竖屏 720×1280（项目已配置）

## 本地运行

```bash
cd game
godot4 --path .          # 或 Godot 编辑器 Open Project → game/
# 无编辑器时：
godot --path . --rendering-driver opengl3
```

## v0 包含

| 模块 | 内容 |
| --- | --- |
| TD | 1 图（剑阁栈道）、6 槽、最多同时 4 单位、3 敌种、10 波、放置/回收、波间存档 + 知识卡 |
| 探索 | 8 房链、1 英雄、自动普攻 + 1 主动技、房界存档 |
| Meta | 6 角色卡数据、碎片解锁、探索熟练度、共享大厅 |
| 知识 | 15 条可用建议；波间/事件卡；大厅 3 题晨课 + 复习队列 |
| 其他 | 离线、无 IAP、`content_pack` 数据目录、本地单槽存档 |

## v0 不做

招式对抗/弹反、联机/抽卡 IAP、深度锻造、开放大世界、医疗级处方。

## 内容扩展

新单位/敌人/知识放入 `data/content_pack_core/*.json`（或未来新建 `content_pack_*` 并在 `ContentDB` 挂载）。资源与存档带 `content_pack` 标记，便于日后 DLC。

## 冒烟

```bash
cd game
godot --headless --path . --script res://tests/smoke_test.gd
```
