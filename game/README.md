# Kongfu Roguelike — 可玩第一章 · 画面加深（v0.3.2）

竖屏、离线武侠健身题材。**第一章「栈道夜雨」** — 塔防主线 + 探索支线 + 真健身知识环，墨雾青玉夜色视觉身份；竖屏可对外截图试玩。

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

## 画面（v0.3.2）

- 统一主题：墨夜青绿 + 灯笼金；霞鹜文楷字体
- **分角色立绘卡**（大厅阵容 / TD 底栏 / 场上单位）
- TD：栈道全幅、门楼据点避开 HUD、命中闪白 + 血条
- 探索：房间转场、技能爆发环、敌方血条与击杀烟
- 程序化循环 BGM（氛围 / 战斗）+ 设置「音乐」音量
- 知识本：玉框墨笺排版

## 冒烟

```bash
cd game
godot --headless --path . --script res://tests/smoke_test.gd
godot --headless --path . --script res://tests/boot_scenes.gd
godot --headless --path . --script res://tests/gameplay_smoke.gd
```

## 截图

Project store `media/art-deepen/`。
