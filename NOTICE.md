# Herakili

Herakili is a rotation and priority helper for World of Warcraft: Classic Era.

## Based on Hekili

Herakili is a modified version of **Hekili** by Hekili and contributors (https://github.com/Hekili/hekili), which is
licensed under the GNU General Public License version 3.  Herakili is distributed under the same licence: see
`LICENSE`.  Herakili is not made, endorsed or supported by Hekili's authors; please don't report Herakili problems to
them.

### Changes from Hekili (GPL v3, section 5a)

Starting from Hekili's `wrath` branch (commit 2ef2a444), modified from October 2026:

- Added a Classic Era (1.15.x) flavor: `Herakili_Vanilla.toc`, the `Era/` class modules and their priorities for all
  nine classes, and Era-specific engine fixes (client API changes in 1.15.8+, events, items, spec detection, GCD
  tracking, definition precedence).
- Renamed the addon to Herakili (folder, title, saved variables `HerakiliDB`, slash commands `/herakili` and `/hera`,
  options and minimap names).  The internal Lua identifier `Hekili` is unchanged.
- Removed the legacy import format (it relied on LibCompress) and the bundled libraries listed below as not included.
- Added offline development tools (`tools/`), not part of the installed addon.

## Bundled libraries

Each library keeps its own licence and copyright notices.

| Library | Licence |
|---------|---------|
| Ace3 (AceAddon, AceBucket, AceComm, AceConfig, AceConsole, AceDB, AceDBOptions, AceEvent, AceGUI, AceHook, AceLocale, AceSerializer, AceTab, AceTimer) and CallbackHandler-1.0 | BSD-style; see `Libs/Ace3-LICENSE.txt` |
| ChatThrottleLib (in AceComm-3.0) | Public domain |
| AceGUI-3.0-SharedMediaWidgets | Customized BSD (per its project page) |
| LibChatAnims | Ace3-style BSD (per its project page) |
| LibCustomGlow-1.0 | See `Libs/LibCustomGlow-1.0/LICENSE` |
| LibDeflate | zlib; see `Libs/LibDeflate/LICENSE.txt` |
| LibDualSpec-1.0 | BSD-style; notice in `Libs/LibDualSpec-1.0/LibDualSpec-1.0.lua` |
| LibRangeCheck-3.0 | MIT; see `Libs/LibRangeCheck-3.0/LICENSE` |
| LibSharedMedia-3.0 | LGPL v2.1 (stated in the library) |
| LibSpellRange-1.0 | GPL v3 (per its project page) |
| LibStub | Public domain |
| LibTranslit-1.0 | LGPL v3; see `Libs/LibTranslit-1.0/COPYING.LESSER` |
| SpellFlashCore (with BigLibTimer) | Public domain (per its project page) |

Not included, though Hekili bundles them: **LibCompress** (GPL v2 only), **AceGUI-3.0_SFX-Widgets** (its licence
doesn't allow redistribution outside addon packs), **LibDataBroker-1.1** ("All Rights Reserved") and **LibDBIcon-1.0**
(needs LibDataBroker).  Herakili's minimap button appears when another addon provides LibDataBroker and LibDBIcon,
which most popular addons do; `/herakili` always opens the options.
