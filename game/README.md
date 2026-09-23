# Kongfu Roguelike — v0.10.1 · 17+ 特效续抠

竖屏、离线武侠健身题材。叠在 v0.10.0 之上做 **状态特效续抠**：

- **光环**：墨意 wash / 笔触 wisp + 上飘墨瓣（少几何同心圆）
- **技能激发**：更长可读峰值 + 长斩痕拖尾 / 残影
- **爆衣**：`*_reveal_mid.png` → `*_reveal.png` 多帧过渡；软边（去厚描边贴纸感）
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

## Android APK（侧载）

见同版本交付说明；debug APK 可直接 `adb install`。开启「允许未知来源」后安装。

## 冒烟

```bash
cd game
godot --headless --path . --script res://tests/smoke_test.gd
godot --headless --path . --script res://tests/boot_scenes.gd
godot --headless --path . --script res://tests/gameplay_smoke.gd
```
