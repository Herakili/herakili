# Herakili

<img src="https://raw.githubusercontent.com/herakili/herakili/era/tools/logo.png" alt="Herakili crest" width="96" align="right">

A rotation and priority helper for **World of Warcraft: Classic Era**: Era, Hardcore and Anniversary realms
(1.15.x, not Season of Discovery).  It shows the next abilities to press for your class, using a priority picked
automatically from your talents.

Herakili is a port of [Hekili](https://github.com/Hekili/hekili) to Classic Era.  It is **in beta**.

## Classes

| Class   | Priorities | Notes |
|---------|------------|-------|
| Warrior | Fury, Arms, Protection | Tank Mode: Defensive Stance uses the tank priority, built for dual-wield Fury/Prot tanking; raid Sunder Armor opener |
| Paladin | Retribution, Protection | Seal choice, Judgement debuff upkeep, Consecration by targets and mana |
| Hunter  | Marksmanship, Beast Mastery, Survival | Auto Shot timing, Aimed Shot modes, melee fallback, pet care |
| Rogue   | Combat, Assassination, Subtlety | Energy ticks, Slice and Dice, stealth openers, dagger detection |
| Priest  | Shadow | Mind Flay clipping, Shadow Weaving, wand fallback |
| Shaman  | Elemental, Enhancement | Totems and weapon imbues |
| Mage    | Frost, Fire, Arcane | Scorch stacks, AoE by pack position, mana gems, Evocation, wand |
| Warlock | Affliction, Demonology, Destruction | Curse by group type, Life Tap / Dark Pact, demon handling |
| Druid   | Feral (Cat and Bear), Balance | Energy ticks, optional powershifting, Maul queueing |

Healing isn't covered: healer-specced characters get their class's damage priority.

## Install

1. Download the latest zip from [Releases](https://github.com/herakili/herakili/releases).
2. Unzip it into `World of Warcraft\_classic_era_\Interface\AddOns\`, so that you have an `AddOns\Herakili` folder.
3. Start the game and type `/herakili` (or `/hera`) to open the options.  While the options are open, drag the
   displays where you want them.

The minimap button appears when another addon provides LibDataBroker and LibDBIcon (most popular addons do).

## Reporting problems

Open an [issue](https://github.com/herakili/herakili/issues) with your class, level and talents.  If a
recommendation looks wrong, take a **Snapshot** when it happens (options → Snapshots) and attach it.  Please don't
report Herakili problems to Hekili's authors.

## Building from source

The addon is the Era build of this repository: `Herakili_Vanilla.toc` loads the engine and the `Era/` class modules.
`tools/build.sh [AddOns folder]` assembles `dist/Herakili` and a release zip, and can copy it into your AddOns folder.
`ERA.md` covers the changes from Hekili, the offline test harness (`tools/test.sh`) and the checking tools;
`PORTING.md` is the guide for working on class modules.

## Licence and credits

Herakili is licensed under the **GNU General Public License v3** (see `LICENSE`).  It is based on Hekili by Hekili
and contributors; `NOTICE.md` lists the changes and the licences of the bundled libraries.  The Herakili crest is
drawn by `tools/make_logo.py`.
