# Kongfu Roguelike — M2 Idle 名人花名册（v0.5.0）

竖屏、离线武侠健身题材。**M2：Idle 历史/武侠名人花名册** — 挂机银两/修为/材料草稿 + 训练槽喂 TD 被动；叠在 M1 无限波 TD 之上。

设计依据（Project store）：
- `docs/gameplay-design.md`
- `docs/project-context.md`
- `docs/base-game-candidates.md`

第三方声明：见 [`THIRD_PARTY.md`](./THIRD_PARTY.md)（合法 OSS only）。

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

### Idle 怎么玩

1. 大厅点 **名人花名册 · Idle**（主 meta 枢纽）
2. 查看 **待领取** 银两 / 修为 / 材料草稿 → **领取挂机收益**（离线上限见 `data/content_pack_core/idle.json`，默认 8 时）
3. 点选具名名人（鲁智深 / 李寻欢 / 黄蓉 / 孙思邈 / 赵云 / 张三丰 / 花木兰 / 林冲）
4. **指派所选** 入训练槽（耗银两）；周期完成后熟练度↑，并有机会掉落未解锁碎片
5. 回大厅 → **新局 · 塔防**：已解锁名人可放置；`effective_mastery` 抬 TD 攻击

爬塔 / 演武 / 探索深度仍为 stubs（探索壳可进）。

## M2 已交付

- 8 具名名人（`units.json` + `historical_tag` + `idle` 速率），非匿名 blob
- Idle 枢纽场景：领取 / 花名册进度 / 训练槽 / 详情
- 离线累计 + cap + claim；存档 v2 迁移
- 训练熟练接入 TD `effective_mastery`；碎片解锁权重
- 大厅 Idle 入口高亮为 meta 枢纽
- 离线无 IAP；冒烟含 Idle

## 冒烟

```bash
cd game
godot --headless --path . --script res://tests/smoke_test.gd
godot --headless --path . --script res://tests/boot_scenes.gd
godot --headless --path . --script res://tests/gameplay_smoke.gd
```

## 截图

Project store `media/m2-idle/`。
