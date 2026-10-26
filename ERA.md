# Hekili for Classic Era

This branch adds a Classic Era (1.15.x, interface 11509) flavor of Hekili, based on the upstream `wrath` branch.
Era, Hardcore and Anniversary realms are covered; Season of Discovery (runes) is not.

## Status

| Class   | Module            | Priorities                           |
|---------|-------------------|--------------------------------------|
| Warrior | `Era/Warrior.lua` | Fury, Arms (auto-selected by talents) |

Other classes still need an `Era/<Class>.lua` module and APLs; the Wrath modules in `Wrath/` are the starting point.

## What changed in the engine

- `Hekili_Vanilla.toc` (`X-Flavor: Era`) loads `Era\Classes.lua` and the Era class modules; `Hekili.IsEra()` was added and
  `Hekili.IsClassic()` now covers Wrath and Era, so every "classic vs. retail" branch applies to Era too.
- Fixes for APIs that are gone or moved on the 1.15.8+ client: the options panel uses the Settings API, display dragging uses
  `GetPhysicalScreenSize`, `GetPlayerAuraBySpellID` is rebuilt from `C_UnitAuras`, the active spec group comes from
  `C_SpecializationInfo`, combat-rating lookups tolerate missing `CR_*` constants, and talent points per tree are read from
  `C_SpecializationInfo.GetSpecializationInfo` (Era/Classes.lua).
- LibDualSpec is optional: it only loads on Era realms with dual spec (Season of Discovery, Anniversary).
- LibRangeCheck-2.0 was replaced by LibRangeCheck-3.0 (same API, maintained, Era-aware).
- On a fresh install the talent-based priority selection works without opening the options first.

Some APIs Hekili uses (`UnitBuff`, `IsPlayerSpell`, `GetTalentTabInfo`, ...) exist on Era only through Blizzard's
deprecation fallbacks, which are on by default (`loadDeprecationFallbacks` CVar).

## Tools

All tools run from the repository root.

| Command | Purpose |
|---------|---------|
| `tools/fetch-libs.sh` | Copy the third-party libraries (normally pulled in by the packager via `.pkgmeta`) from an official Hekili release zip into `Libs/`. |
| `tools/build.sh [AddOns dir]` | Assemble `dist/Hekili`; optionally copy it into a WoW `Interface/AddOns` folder. |
| `LIBS=<dir> lua5.1 tools/packtool.lua embed Era/Warrior.lua Era/APLs/WarriorFury.simc Fury 1` | Encode an APL into the built-in pack string in a class module. `LIBS` must contain `LibDeflate/` and `Ace3/` checkouts. `decode` / `encode` / `decodestr` are also available. |
| `python3 tools/check_apl.py Era/Warrior.lua Era/APLs/*.simc` | Check that every action, aura, talent and setting an APL references exists in the module. |
| `tools/fetch-era-api.sh` then `luajit tools/harness.lua Hekili_Vanilla.toc WARRIOR 17/34/0` | Offline load test against the real Era API list: loads the addon, runs login, spec detection, pack restore and selection, and compiles every priority entry. |

## Warrior notes

- Spell, rank, talent and aura IDs were checked against Wowhead's Classic database.
- Rage: white hits use the 1.x formula (7.5 × damage / c); a queued Heroic Strike or Cleave replaces the main-hand swing's rage.
- Overpower is tracked from your target's dodges (5 s window); stance swaps keep rage up to Tactical Mastery's limit.
- Enemy counting for Cleave / Whirlwind uses nameplates within 8 yards plus damage-based detection as a fallback.
- Settings (Hekili options → Warrior): Heroic Strike / Cleave rage thresholds, Execute-phase queueing, Hamstring weaving
  for Windfury, Sunder / Demoralizing Shout upkeep, Rend while leveling, Bloodthirst/Mortal Strike over Execute above an
  attack-power threshold, and the Fury Overpower stance dance.
