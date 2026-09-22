# Kongfu Roguelike — v0.9.2 手感续抠（共享战环 + 攻击特效 + 主题 BGM）

竖屏、离线武侠健身题材。叠在 M6 + v0.9.1 手感打磨之上：

- **探索战斗统一**：搜打撤挂上与演武/爬塔相同的 `AutoCombatRing`
- **攻击特效**：冲刺斩击弧、命中冲击环、按技能类型区分的施法表现
- **主题 BGM**：title / lobby / TD / explore / arena 可辨识循环（音量仍走设置）
- **HUD 对齐**：探索补肖像槽；锁定卡用绘制锁标替代「锁」字

设计依据（Project store）：
- `docs/gameplay-design.md`
- `docs/project-context.md`
- `docs/base-game-candidates.md`

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

### 知识本 / 晨课 / 复习

1. 大厅 → **知识本 / 晨课**（有待复习时按钮带 ·复N）
2. 主题筛选：全部 / 训练 / 饮食 / 作息 / 待复习
3. **晨课测验**每日 3 题（优先抽到期/错题）；答对 ≥2 → 当日轻量 buff
4. **间隔复习**：错题立即到期，答对按 1/3/7 天推迟；单独复习会话最多 5 题
5. 局内：TD 波间功法笺、探索事件、爬塔层间笺；学会的 hook 给微小银两/护盾/攻击

### 演示 DLC 包

- 路径：`data/content_pack_demo_mountain/`
- 本地 `owned: true`，无商店计费
- 合并后大厅花名册可见 **花木兰**（碎片解锁）、知识本出现山野主题卡、可装备 **山野行囊符**

新增包步骤见 `data/CONTENT_PACKS.md`。

### 五模式

仍按原路径：TD 无限波、Idle 名人、探索搜打撤、演武场、爬塔。

## 冒烟

```bash
cd game
godot --headless --path . --script res://tests/smoke_test.gd
godot --headless --path . --script res://tests/boot_scenes.gd
godot --headless --path . --script res://tests/gameplay_smoke.gd
```

## 截图

- Project store `media/m6-knowledge-dlc/`
