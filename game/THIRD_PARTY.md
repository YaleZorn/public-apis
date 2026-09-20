# Third-party attributions (Kongfu `game/`)

本目录仅收录**合法开源**组件声明。禁止引入泄露 / 破解 / 盗版商业源码或资产。

## Combat core (M1)

| Project | License | Upstream | Usage in Kongfu |
| --- | --- | --- | --- |
| [ape1121/Godot-4-Tower-Defense-Template](https://github.com/ape1121/Godot-4-Tower-Defense-Template) | **MIT** © 2024 Alp | GitHub | Wave escalation / spawnable-enemy pool ideas adapted into `scripts/td/wave_director.gd`. Turret → Kongfu roster unit cards (portraits in `assets/textures/portraits/`). **No** template dino/turret sprites redistributed. |

Full MIT text: [`third_party/ape1121-godot-4-tower-defense-template/LICENSE`](./third_party/ape1121-godot-4-tower-defense-template/LICENSE)

## Engine

| Project | License | Notes |
| --- | --- | --- |
| [Godot Engine](https://godotengine.org/) 4.3 | MIT | Runtime; not vendored in this tree |

## Shell / content (first-party)

Title, lobby, art (ink-mist), ContentDB, SaveManager, knowledge pipeline, explore stubs — Kongfu project original under the repository license. Offline, **no IAP**.

## Future mode grafts (not in M1 binary)

Documented for planning only; not required to run M1:

- yuuki4180/GodotAutoCombatKit (MIT) — explore/arena auto-combat (M4+)
- scottpetrovic/godot-4-idleclicker (MIT) — idle upgrade reference (M3)
- expressobits/inventory-system (MIT) — inventory/craft (explore)

When those land, append LICENSE copies under `third_party/` and update this file.
