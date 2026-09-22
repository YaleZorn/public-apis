# Kongfu Roguelike — v0.9.5 小人·立绘

竖屏、离线武侠健身题材。叠在 v0.9.4 音效形效之上：

- **局内小人立绘**：TD / 探索 / 演武 / 爬塔用地上 figure 精灵（非卡框肖像）
- **可动**：呼吸缩放 + 飘带 bob + 攻击 lean；大厅花名册仍用肖像收集卡
- **吸睛造型**：更新黄蓉/木兰/李寻欢等肖像与全身 figure，墨雾武侠 + 略有风情不过火
- 五模式仍可玩；离线无 IAP；合法 OSS only；保留 v0.9.4 音效形效

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
