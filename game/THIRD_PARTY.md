# Third-party attributions (Kongfu `game/`)

本目录仅收录**合法开源**组件声明。禁止引入泄露 / 破解 / 盗版商业源码或资产。

## Combat core (M1)

| Project | License | Upstream | Usage in Kongfu |
| --- | --- | --- | --- |
| [ape1121/Godot-4-Tower-Defense-Template](https://github.com/ape1121/Godot-4-Tower-Defense-Template) | **MIT** © 2024 Alp | GitHub | Wave escalation / spawnable-enemy pool ideas adapted into `scripts/td/wave_director.gd`. Turret → Kongfu roster unit cards (portraits in `assets/textures/portraits/`). **No** template dino/turret sprites redistributed. |

Full MIT text: [`third_party/ape1121-godot-4-tower-defense-template/LICENSE`](./third_party/ape1121-godot-4-tower-defense-template/LICENSE)

## Explore auto-combat ideas (M3+)

| Project | License | Upstream | Usage in Kongfu |
| --- | --- | --- | --- |
| [yuuki4180/GodotAutoCombatKit](https://github.com/yuuki4180/GodotAutoCombatKit) | **MIT** | GitHub | **Ideas only** (竖屏自动索敌普攻 + 轻触主动). Shared first-party ring: `scripts/combat/auto_combat_ring.gd` (explore / arena / tower). **No** AutoCombatKit source or assets vendored. |

## Lite inventory (M3)

| Project | License | Upstream | Usage in Kongfu |
| --- | --- | --- | --- |
| [expressobits/inventory-system](https://github.com/expressobits/inventory-system) | **MIT** | GitHub | **API / bag+craft shape inspiration** for first-party `scripts/explore/run_bag.gd` + `materials.json` recipes. Plugin **not** vendored; craft UI is thin settle hooks. |
| [seloc0des/godot-inventory-lite](https://github.com/seloc0des/godot-inventory-lite) | **MIT** | GitHub | Mentioned as lighter alternative; not vendored. |

## Arena ramp ideas (M4)

| Project | License | Upstream | Usage in Kongfu |
| --- | --- | --- | --- |
| [DarkRewar/SurvivorsStarterKit](https://github.com/DarkRewar/SurvivorsStarterKit) | **MIT** | GitHub | **Ideas only** (survival timer / escalate spawn pressure). Kongfu arena is first-party GDScript on the shared auto-combat ring; **no** C# survivors kit vendored. |
| GDScript survivors clones (e.g. migalvalm / bektaskemal — MIT) | **MIT** | GitHub | Optional escalate/timer reference; not vendored. |

## Tower layer UX (M5)

| Project | License | Upstream | Usage in Kongfu |
| --- | --- | --- | --- |
| [MadAvidCoder/Ascendancy](https://github.com/MadAvidCoder/Ascendancy) | **MIT** | GitHub | **Layer-progress UX inspiration only**. Floor table + exclusive drop pool are first-party (`tower.json` / `gear_tower_blade`). No platformer combat fork. |

## Engine

| Project | License | Notes |
| --- | --- | --- |
| [Godot Engine](https://godotengine.org/) 4.3 | MIT | Runtime; not vendored in this tree |

## Shell / content (first-party)

Title, lobby, art (ink-mist), ContentDB multi-pack loader, SaveManager, knowledge pipeline (journal / morning quiz / spaced review), Idle hub, explore 搜打撤, arena 演武场, tower 爬塔 — Kongfu project original under the repository license. Offline, **no IAP**.

**content_pack seam:** scan `res://data/content_pack_*`, merge owned packs (`manifest.owned` or save `owned_content_packs`). Demo pack: `content_pack_demo_mountain` (units + knowledge + gear). How-to: [`data/CONTENT_PACKS.md`](./data/CONTENT_PACKS.md).

## Future grafts

- Optional vendor expressobits full inventory
- Additional thematic packs (still local-owned, no store billing in v0)

When vendoring LICENSE files: append under `third_party/` and update this file.
