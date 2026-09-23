# Kongfu Roguelike — v0.10.0 · 17+ 特效品质重建

竖屏、离线武侠健身题材。叠在 v0.9.9 状态特效之上做 **品质重建**：

- **爆衣**：作者向 `*_reveal.png` 换装立绘（非 procedural 暖色撕裂）
- **光环**：软层叠环 + 雾盘 + 环绕墨瓣（`assets/textures/vfx/`）
- **技能激发**：闪光核 + 斩痕拖尾 + 能量瓣，竖屏可读
- 标题/设置仍标 **内容分级：17+**；离线无 IAP；合法 OSS only

设计依据（Project store）：
- `docs/gameplay-design.md`
- `docs/project-context.md`
- `docs/character-presentation.md`
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
