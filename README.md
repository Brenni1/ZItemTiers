# Zed's Item Tiers (ZItemTiers)

![ZItemTiers](common/poster.png)

Adds a **probability-based item tier system** to Project Zomboid. Any item can spawn with any tier; higher tiers grant stat bonuses.

## Tiers

| Tier     | Default chance | Color  |
|-----------|----------------|--------|
| Common    | 80%            | White  |
| Uncommon  | 16%            | Green  |
| Rare      | 3.2%           | Blue   |
| Epic      | 0.64%          | Purple |
| Legendary | 0.16%          | Gold   |

Probabilities are configurable in `core.lua` (`ZItemTiers.TierProbabilities`).

## Bonuses by Tier

Higher tiers improve items that support the stat (e.g. weapons get damage, clothing gets defense).

- **Weapons:** Damage multiplier, weight reduction (with Java patch)
- **Clothing:** Bite/scratch defense, run speed, vision/hearing impairment reduction
- **Containers:** Capacity, encumbrance reduction, max item encumbrance
- **Drainables (e.g. gas cans, water):** Capacity bonus
- **Literature:** Mood benefits, reading speed
- **Flashlights:** Lower battery consumption
- **Food:** Better hunger reduction (Uncommon+)

Common items have no bonuses. Exact values are in `42.13/media/lua/shared/ZItemTiers/core.lua` under `ZItemTiers.TierBonuses`.

## Crafting

Crafted output tier is derived from **ingredient tiers** (Factorio-style):

- Output is at least the **minimum (highest) tier** among ingredients.
- Mixed tiers use a weighted/probability result.
- Crafting skill can nudge the result (e.g. small chance to go one tier higher at higher skill).

## Requirements & Optional

- **Game version:** 42.x (42.13 media included).
- **CleanUI:** Load after CleanUI (`loadModAfter=CleanUI` in mod.info).
- **ZombieBuddy:** Optional. [ZombieBuddy](https://github.com/zed-0xff/ZombieBuddy) enables Java-based bonuses (e.g. weapon weight); without it, the mod runs Lua-only.
- **Starlit Library:** Optional. If installed, tooltips show detailed bonus breakdowns.

## Integrations

- **Better Clothing Info** – bonus display in clothing UI
- **CleanUI** – load order
- **Context Menu** – tier in context menus
- **Starlit** – detailed tooltip bonuses

## Installation

1. Subscribe (Steam Workshop) or drop the mod folder into `Steam/steamapps/common/Project Zomboid/mods/`.
2. Enable **ZItemTiers** in the main menu Mods screen.
3. (Optional) Install Starlit Library for rich tooltips; build/include the Java JAR for full weapon weight support.

## License

MIT.

## Author

**zed_0xff** – [GitHub](https://github.com/zed-0xff) · [Ko-fi](https://ko-fi.com/zed_0xff)
