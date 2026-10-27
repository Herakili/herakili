# Herakili: Hekili for Classic Era

Herakili is a Classic Era (1.15.x, interface 11509) port of Hekili, based on the upstream `wrath` branch, released
under the GNU GPL v3 (`LICENSE`; credits, changes and library licences in `NOTICE.md`).  Era, Hardcore and Anniversary
realms are covered; Season of Discovery (runes) is not.

The shipped addon is the `Herakili` folder built by `tools/build.sh` (Era TOC `Herakili_Vanilla.toc`, saved variables
`HerakiliDB`, commands `/herakili` and `/hera`).  The source keeps Hekili's internal Lua identifier `Hekili` and the
untouched Wrath files, which the build leaves out.

## Status: beta (`era-beta-3`)

Every priority is auto-selected by talent tree.  Healing specs aren't covered (Hekili's engine does damage and
tanking); healer-specced characters get the class's damage priority.

| Class   | Priorities | Notes |
|---------|------------|-------|
| Warrior | Fury, Arms, Protection | Tank Mode: Defensive Stance = tank priority (dual-wield Fury/Prot meta); raid Sunder opener |
| Paladin | Retribution, Protection | Seal choice, Judgement debuff upkeep, Consecration by targets/mana |
| Hunter  | Marksmanship, Beast Mastery, Survival | Auto Shot model, Aimed Shot modes, melee fallback, pet care |
| Rogue   | Combat, Assassination, Subtlety | Energy ticks, Slice and Dice pooling, stealth openers, dagger detection |
| Priest  | Shadow | Mind Flay clipping rules, Shadow Weaving, wand fallback, racials |
| Shaman  | Elemental, Enhancement | Totems and weapon imbues from the client APIs |
| Mage    | Frost, Fire, Arcane | Scorch stacks, AoE by pack position, mana gems / Evocation / wand |
| Warlock | Affliction, Demonology, Destruction | Curse per group type, Life Tap/Dark Pact, demon handling |
| Druid   | Feral (Cat + Bear by form), Balance | Energy ticks, optional powershifting, Maul on next swing |

Porting notes for further work are in `PORTING.md`.

## What changed in the engine

- `Herakili_Vanilla.toc` (`X-Flavor: Era`) loads `Era\Classes.lua` and the Era class modules; `Hekili.IsEra()` was added and
  `Hekili.IsClassic()` now covers Wrath and Era, so every "classic vs. retail" branch applies to Era too.
- 1.15.8+ client changes: options panel via the Settings API; display dragging via `GetPhysicalScreenSize`;
  `GetPlayerAuraBySpellID` rebuilt from `C_UnitAuras`; spec group via `C_SpecializationInfo`; tolerant combat-rating
  lookups; talent points per tree via `C_SpecializationInfo.GetSpecializationInfo` (Era/Classes.lua).
- Events the client doesn't have are never registered (`ns.IsEventValid`, e.g. `LEARNED_SPELL_IN_TAB`).
- Items the client can't resolve (e.g. the shared Wrath potion list) are skipped instead of erroring in
  `Item:ContinueOnItemLoad`, which used to abort `Classes.lua` and cascade into hundreds of "nil" errors.  Note that
  `C_Item.DoesItemExistByID` can be true for such IDs on the live client; the check that matters is
  `GetItemInfoInstant`, and every item load is wrapped so it can never stop the file from loading.
- The GCD is tracked through the class module's `gcd` spell (Era has no spell 61304).
- LibDualSpec is optional (it only loads on Era realms with dual spec); LibRangeCheck-3.0 (v38, Era-aware) replaces 2.0.
- Combat log flags come from `Enum.CombatLogObject` (the `COMBATLOG_OBJECT_*` globals are deprecation fallbacks on Era).
- On a fresh profile the class module's default priority is used, and talent-based selection works without opening the
  options first.
- Upstream bugs fixed along the way: caption `SetJustifyV` with LEFT/RIGHT (the modern client rejects it),
  `QueueRebuildUI` out of scope in `Hekili:SetOption`, `HandleSpellData` unable to unregister itself (duplicate handlers),
  `SaveDebugSnapshot( nil )` indexing a nil display (broke snapshots), Charge's `not combat` test (always false), and two
  debug-path calls to removed APIs.

Some APIs Hekili uses (`UnitBuff`, `IsPlayerSpell`, `GetTalentTabInfo`, `GetItemInfo`, ...) exist on Era only through
Blizzard's deprecation fallbacks, which are on by default (`loadDeprecationFallbacks` CVar).

## Tools

All tools run from the repository root.  First: `tools/fetch-libs.sh` (libraries) and `tools/fetch-era-api.sh`
(Era API dumps, UI-source global names, client DB2 tables from wago.tools, then `tools/era_data.py`).

| Command | Purpose |
|---------|---------|
| `LIBS=<dir> tools/test.sh` | Run everything below; `quick` skips the leveling runs, `HARNESS_SAVEDVARS=<Hekili.lua>` adds a run from a saved profile. |
| `luajit tools/harness.lua Herakili_Vanilla.toc WARRIOR 17/34/0` | Runs the addon against a model of the Era client built from its own data: only APIs that exist resolve, spells/items/strings/CVars/constants/events come from the client tables, unknown items and events error like the client. Plays login, spec detection, priority restore/selection, compiles every entry, walks the options tree, then combat scenarios through the real engine. `HARNESS_LEVEL`, `HARNESS_DEBUG=<scenario>` (Hekili's decision log), `HARNESS_TARGETDEBUG`, `HARNESS_DUMP`. |
| `tools/build.sh [AddOns dir]` | Assemble `dist/Herakili` and `dist/Herakili-<version>.zip`; optionally copy it into a WoW `Interface/AddOns` folder. |
| `LIBS=<dir> lua5.1 tools/packtool.lua embed Era/Warrior.lua Era/APLs/WarriorFury.simc Fury 1` | Encode an APL into the built-in pack in a class module (versioned by date and time, so profiles update). `decode` / `encode` / `decodestr` too. |
| `python3 tools/check_apl.py Era/Warrior.lua Era/APLs/*.simc` | Every action, aura, talent and setting an APL references exists. |
| `luajit tools/dump_spec.lua Era/Warrior.lua WARRIOR > ids.txt; python3 tools/check_ids.py ids.txt 1` | Every spell, rank, aura and talent ID exists on Era, names match, rank chains are complete. |
| `python3 tools/check_globals.py` | Globals the addon reads that the Era client doesn't provide (with source lines). |
| `python3 tools/check_events.py` | Registered events the Era client doesn't have. |
| `python3 tools/check_shared.py <HARNESS_DUMP file>` | Shared (all-class) abilities/auras/items that don't exist on Era. |
| `python3 tools/make_logo.py [preview.png]` | Draw the Herakili crest (`Textures/HERAKILI.tga`, `tools/logo.png`) from geometry. |
| `python3 tools/era_talents.py <classID>` / `tools/spell_lookup.py "<name>"` | Era talent table as RegisterTalents lines / every Era spell with a name, its rank, level and skill line. |

## Warrior notes

- Spell, rank, talent and aura IDs come from / are verified against the Era client tables (build 1.15.9.70003).
- Rage: white hits use the 1.x formula (7.5 × damage / c); a queued Heroic Strike or Cleave replaces the main-hand swing's rage.
- Overpower is tracked from your target's dodges (5 s window); stance swaps keep rage up to Tactical Mastery's limit.
- Enemy counting for Cleave / Whirlwind: enemy nameplates within 8 yards (enable them with V; they are off by default on
  Era), plus damage-based detection from your abilities' hits (white swings don't count).
- Racials: Blood Fury and Berserking are used with the cooldowns when your race has them.
- Tank threat follows the Era threat values measured on the Classic server (magey/classic-warrior "Threat Mechanics";
  Defensive Stance × Defiance = 1.495): Revenge is the best threat per rage, Bloodthirst the best per global cooldown,
  Heroic Strike (rank 9: damage + 173) is the single-target rage dump and never starves a ready Bloodthirst, Cleave
  (+100 per target) and Battle Shout (threat split across all enemies) are the multi-target dumps, and Sunder Armor
  is filler once at 5 stacks.  Bloodthirst vs. Revenge order is still to be checked against top Era logs.
- Settings (Herakili options → Warrior): Heroic Strike / Cleave rage thresholds, Execute-phase queueing, Hamstring weaving
  for Windfury, Sunder / Demoralizing Shout upkeep, Rend while leveling, Bloodthirst/Mortal Strike over Execute above an
  attack-power threshold, and the Fury Overpower stance dance.
