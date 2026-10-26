# Porting a class to Classic Era

How `Era/Warrior.lua` was built, written down so every class follows the same path.  Read `ERA.md` first.

## Files a class port owns

| File | What |
|------|------|
| `Era/<Class>.lua` | The class module (talents, auras, abilities, state hooks, settings, packs, pack selectors). |
| `Era/APLs/<Class><Spec>.simc` | One SimC-style priority per spec; the pack name is the part after the class name. |
| `tools/scenarios/<CLASS>.lua` | Test builds and combat scenarios for the harness (format: see `tools/scenarios/WARRIOR.lua`). |

Shared files (`Classes.lua`, `State.lua`, `Events.lua`, `UI.lua`, `Era/Classes.lua`, `tools/*`) are shared by all ports.
Change them only when a class genuinely needs an engine fix, keep the change minimal and generic, re-read the file
right before editing (other ports edit in parallel), and list every such change in your report.

## Start from

- `Wrath/<Class>.lua` for structure and engine conventions (resources, auras with `copy`, abilities, hooks, settings,
  `RegisterPack`, `RegisterPackSelector`).  Everything Wrath-only goes: glyphs, Wrath ranks/talents/spells, Wrath gear.
- `Era/Warrior.lua` for Era conventions (rank tables, `known_id`, pseudo-auras, settings, pack selectors, options).

## IDs: always from the Era client tables, never from memory

- `python3 tools/era_talents.py <classID>` prints the class's exact Era talent table as `RegisterTalents` lines
  (classIDs: Warrior 1, Paladin 2, Hunter 3, Rogue 4, Priest 5, Shaman 7, Mage 8, Warlock 9, Druid 11).  Use it verbatim.
- `python3 tools/spell_lookup.py "Frostbolt" "Fireball"` lists every Era spell with that name: ID, rank, learn level,
  skill line.  The spellbook spells are the ones on a class skill line with a level.
- Abilities: `id` = the **highest Era rank**, `copy = { all lower ranks }`.  The engine resolves the rank you know by
  name, so the ID must exist on Era or the ability has no name.
- Auras: list every rank's aura ID in `copy` (for most spells the aura ID equals the spell ID per rank).
- Rank-dependent numbers (duration, damage, rage/mana gain): key a table by spell ID and read
  `class.abilities[ key ].id` (see `known_id` in `Era/Warrior.lua`).  There is no `action.X.rank`.
- Talent-only abilities: set `talent = "<key>"` on the ability.
- Verify: `luajit tools/dump_spec.lua Era/<Class>.lua <CLASS> > /tmp/ids.txt && python3 tools/check_ids.py /tmp/ids.txt <classID>`
  must report 0 problems (it checks existence, names, complete rank chains, talents).

## Era mechanics and engine traps learned on Warrior

- `combat` is the combat **start time** (0 out of combat), not a boolean: write `combat == 0`, never `not combat`.
  In APLs use `time` (seconds in combat; 0 out of combat).
- There is no global cooldown spell 61304 on Era: `spec:RegisterOptions{ gcd = <spellID> }` must name a spell that
  every character of the class knows from level 1, is on the GCD, and has no cooldown of its own (Warrior: Battle
  Shout 6673).  The engine tracks the GCD through it.
- Shared (all-class) auras/abilities in `Classes.lua` may carry Wrath IDs as their primary `id`; a class module's own
  aura/ability with the same key wins, so redefine with Era IDs when a priority relies on one.
- Don't register events that Era lacks (the engine already skips them through `ns.IsEventValid`).
- Items: only Era items (check `tools/.era-api/db2/ItemSparse.csv`).  Wrath potions/trinkets don't exist.
- No glyphs, no spell haste rating, no `Enum`-based combat log flags beyond `Enum.CombatLogObject`.
- Combat log hooks: `spec:RegisterCombatLogEvent( function( _, subtype, _, sourceGUID, _, _, _, destGUID, _, _, _, ... ) end )`;
  for `SWING_MISSED` the miss type is the first `...` value, for `SPELL_*` suffixes it's after spellID, name, school.
- Pseudo-auras (no `id`) are fine for things the engine predicts itself (queued Heroic Strike, Overpower window).
- On Era a class module's definitions take precedence over the shared ones in `Classes.lua` (the module is loaded
  first; see `Hekili:SpecializationChanged`).  Shared Wrath-ID racials/potions can be overridden with Era IDs.
- Reserved names: a state expression called `soul_shards` won't compile (it's treated as the retail resource), and an
  action list called `mana` silently never runs.  Use other names (`shard_count`, `regen`).
- `solo` / `group` / `raid` come from `GetNumGroupMembers()` (which counts the player); `solo` is true at 0 or 1.
- Costs: read live costs with `GetSpellPowerCost` (pattern in `Era/Paladin.lua`); fallback tables must come from
  `tools/.era-api/db2/SpellPower.csv`, never from memory (percent costs are of base mana).
- Wands: `Shoot` (5019) comes from the Wands skill, not a class line; check `HasWandEquipped()`, and never recommend
  Shoot while it is already active (pressing it again stops the wand).
- Things Hekili can't see (being behind the target, ranged pack size beyond nameplate range) belong in settings.
- Ranks learned later must not be assumed: the priority must work at every level (abilities you don't know are simply
  skipped; make sure a low-level character still gets a sensible priority).

## Priorities (APLs)

- Research the Era rotation from reputable sources (Classic Era sims, Wowhead Classic, Warcraft Tavern, class Discords'
  public guides).  No Season of Discovery runes.
- One list per stance/form where it matters, `run_action_list` by stance/form like `Era/APLs/WarriorFury.simc`.
- Leveling-aware: rely on `talent.X.enabled`, unknown abilities being skipped, and simple fallbacks.
- Expose real choices as settings (`spec:RegisterSetting`), not hard-coded numbers.
- AoE via `active_enemies` (nameplates within the spec's `nameplateRange`, plus damage-based detection).
- Validate: `python3 tools/check_apl.py Era/<Class>.lua Era/APLs/<Class>*.simc` → 0 problems.
- Embed each pack: `LIBS=<dir with LibDeflate/ and Ace3/> lua5.1 tools/packtool.lua embed Era/<Class>.lua Era/APLs/<Class><Spec>.simc <Spec> <classID> "hekili-era" "<description>"`.
- Pack selectors: one per spec by talent tree (`tab1 > max( tab2, tab3 )` etc.), and `RegisterOptions{ package = <default> }`.

## Test

- Scenario file `tools/scenarios/<CLASS>.lua`: `builds` (talent rank spell IDs per points string; use the highest rank
  spell of each talent you take), `defaultBuild`, `reset( H )` (power type, mana, forms, gear) and `scenarios( H )`.
  World model fields (`H.W`): `powerType` (0 mana, 1 rage, 3 energy), `mana/manaMax/rage/energy/combo`, `forms`
  (shapeshift bar spell IDs) and `stance` (active index), `formID`, `pet` (`H.Pet( name, family )`), `casting`
  (`{ spellID, start, finish, channel }`), `equip` (slot → Era item ID), `autoRepeat`, `buffs`/`debuffs`
  (`H.Aura( spellID, remaining, stacks, duration )`), `target` (`H.Target( health, boss )`, `.distance`, `.casting`),
  `H.Plates( n )`, `groupSize`, `inCombat`, `gcdStart`, `cooldowns[ id ] = { start, duration }`; `H.Cast( spellID )`
  reports a real cast; `H.CLEU( subtype, src, dst, ... )` fires a combat log event.
- Run: `luajit tools/harness.lua Hekili_Vanilla.toc <CLASS> <build>` (and `HARNESS_LEVEL=20 ... 0/0/0` for leveling).
  `HARNESS_DEBUG="<part of a scenario name>"` prints Hekili's own decision log for that scenario.
- Then `LIBS=... tools/test.sh quick <CLASS>` must end with `ALL CHECKS PASSED`.
- Scenarios should cover: single target, AoE (3+ enemies), execute/finisher thresholds, resource-starved, out of combat
  opener, cooldown usage, each stance/form, and anything with a setting.  Check that what's recommended is what an
  experienced Era player would press; if not, fix the priority, not the scenario.
