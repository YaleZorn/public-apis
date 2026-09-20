# Kongfu Roguelike — M6 知识加深 + content_pack 接缝（v0.9.0）

竖屏、离线武侠健身题材。叠在 M4/M5 五模式基线之上：

- **知识产品化**：32+ 张可用健身卡（饮食/训练/作息）· 知识本筛选 · 晨课 · **间隔复习队列** · 进度喂微小 meta buff
- **content_pack 接缝**：多包扫描合并 · 本地 `owned`（无 IAP）· 仓库内 **演示包 · 山野补遗**（花木兰 / 4 知识 / 行囊符）

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
