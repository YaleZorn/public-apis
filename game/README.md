# Kongfu Roguelike — 可玩第一章（v0.2）

竖屏、离线武侠健身题材。**第一章「栈道夜雨」** — 塔防主线 + 探索支线 + 真健身知识环，从 graybox 提升到可对外试玩品质。

设计依据（Project store）：
- `docs/gameplay-design.md`
- `docs/project-context.md`

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

## 本版包含（vs v0.1 graybox）

| 模块 | 内容 |
| --- | --- |
| **产品壳** | 标题页、设置（主音量/音效）、续关/新局、场景淡入淡出 |
| **TD 第一章** | 10 波具名节奏（前哨→终守）、波次提示/横幅、剑阁门/地形、形状语言单位、飘字/震屏/程序化音效、胜败结算屏 |
| **探索** | 9 房链（战/事件/修炼/宝箱/补给）、房间进度条、HP 条、战利品反馈、撤离/战败/通关屏 |
| **Meta** | 阵容碎片进度、3 槽装备（通关/知识解锁）、探索主角切换 |
| **知识** | 15 条；局内卡片不剧透；知识本未解锁隐藏答案；晨课 3 题 + buff |
| **Juice** | 程序化 SFX、飘字伤害、轻震屏、按钮脉冲、场景过渡 |
| **美术** | 统一主题色（武侠绿金）、角色定位形状、敌人标签形状 |

## v0.2 仍属占位

- 无最终美术/配音/音乐轨
- 装备仅 3 件演示词条，无深度锻造
- TD 单章单图；探索单条路线
- 知识科学审核流程待产品签收

## 内容扩展

JSON 驱动：`data/content_pack_core/*.json`。新 pack 目录 + `ContentDB.PACK_ROOT` 挂载即 DLC 接缝。

## 冒烟

```bash
cd game
godot --headless --path . --script res://tests/smoke_test.gd
godot --headless --path . --script res://tests/boot_scenes.gd
godot --headless --path . --script res://tests/gameplay_smoke.gd
```

## 截图

Chapter 截图由 agent 写入 Project store：`media/playable-chapter/`。
