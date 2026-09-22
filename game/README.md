# Kongfu Roguelike — v0.9.4 音效·形效·锁

竖屏、离线武侠健身题材。叠在 v0.9.3 TD/爬塔汁水之上：

- **更厚主题 BGM**：各模式动机更清晰（含知识本专属床），对位应答层；SFX 分层打击（布阵木感、命中噪声+叮）
- **形效战斗 VFX**：TD/战斗环用 Polygon2D 菱形/刃瓣 + Line2D 环，替代 ColorRect 方块火花
- **锁标**：花名册锁定卡用真「锁」字 + 青玉印环（非几何挂锁 blob）
- **HUD**：银两/据点/波次/气血/演武统计统一「·」分隔；技能冷却同格式
- 五模式仍可玩；离线无 IAP；合法 OSS only

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

见 [`data/CONTENT_PACKS.md`](./data/CONTENT_PACKS.md)。`demo_mountain` 默认本地已挂。

### 冒烟

```bash
godot --headless --path . --script res://tests/smoke_test.gd
godot --headless --path . --script res://tests/boot_scenes.gd
godot --headless --path . --script res://tests/gameplay_smoke.gd
```
