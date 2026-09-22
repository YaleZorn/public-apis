# Kongfu Roguelike — v0.9.3 TD 汁水追平 + 爬塔专属 BGM

竖屏、离线武侠健身题材。叠在 v0.9.2 手感续抠之上：

- **TD 汁水**：布阵爆发、主路/侧翼预警、攻击弹道斩击、命中冲击、刷怪入场 — 向 `AutoCombatRing` 可读性靠齐
- **爬塔专属 BGM**：不再共用探索曲；上升感攀登主题（音量仍走设置）
- **HUD**：TD 底栏改为竖向肖像卡，与大厅/探索/演武一致
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

见 `data/CONTENT_PACKS.md` — `content_pack_demo_mountain` 本地挂载演示。

## 冒烟

```bash
godot --headless --path . --script res://tests/smoke_test.gd
godot --headless --path . --script res://tests/boot_scenes.gd
godot --headless --path . --script res://tests/gameplay_smoke.gd
```
