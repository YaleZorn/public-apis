# Third-party attributions (Kongfu `game/`)

本目录仅收录**合法开源**组件声明。禁止引入泄露 / 破解 / 盗版商业源码或资产。

## Combat core (M1)

| Project | License | Upstream | Usage in Kongfu |
| --- | --- | --- | --- |
| [ape1121/Godot-4-Tower-Defense-Template](https://github.com/ape1121/Godot-4-Tower-Defense-Template) | **MIT** © 2024 Alp | GitHub | Wave escalation / spawnable-enemy pool ideas adapted into `scripts/td/wave_director.gd`. Turret → Kongfu roster unit cards (portraits in `assets/textures/portraits/`). **No** template dino/turret sprites redistributed. |

Full MIT text: [`third_party/ape1121-godot-4-tower-defense-template/LICENSE`](./third_party/ape1121-godot-4-tower-defense-template/LICENSE)

## Explore auto-combat ideas (M3)

| Project | License | Upstream | Usage in Kongfu |
| --- | --- | --- | --- |
| [yuuki4180/GodotAutoCombatKit](https://github.com/yuuki4180/GodotAutoCombatKit) | **MIT** | GitHub | **Ideas only** (竖屏自动索敌普攻 + 轻触主动). Kongfu explore combat in `scripts/explore/explore_run.gd` is first-party; **no** AutoCombatKit source or assets vendored. |

## Lite inventory (M3)

| Project | License | Upstream | Usage in Kongfu |
| --- | --- | --- | --- |
| [expressobits/inventory-system](https://github.com/expressobits/inventory-system) | **MIT** | GitHub | **API / bag+craft shape inspiration** for first-party `scripts/explore/run_bag.gd` + `materials.json` recipes. Plugin **not** vendored; craft UI is thin settle hooks. |
| [seloc0des/godot-inventory-lite](https://github.com/seloc0des/godot-inventory-lite) | **MIT** | GitHub | Mentioned as lighter alternative; not vendored. |

## Engine

| Project | License | Notes |
| --- | --- | --- |
| [Godot Engine](https://godotengine.org/) 4.3 | MIT | Runtime; not vendored in this tree |

## Shell / content (first-party)

Title, lobby, art (ink-mist), ContentDB, SaveManager, knowledge pipeline, Idle hub, explore 搜打撤 — Kongfu project original under the repository license. Offline, **no IAP**.

## Future mode grafts (not in M3 binary)

- scottpetrovic/godot-4-idleclicker (MIT) — idle upgrade reference (Idle already first-party in M2)
- DarkRewar/SurvivorsStarterKit or GDScript survivors clones (MIT) — arena ramp (M4+)
- Ascendancy / room-chain refs — tower climb layer table (M5)

When those land, append LICENSE copies under `third_party/` and update this file.
