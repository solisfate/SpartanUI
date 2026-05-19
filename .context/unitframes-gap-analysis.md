# SpartanUI UnitFrames Feature Gap Analysis

## Context

Deep comparison of SpartanUI, DandersFrames (v4.3.0), and ElvUI unitframe systems to identify every missing option, element, and default. Previous audits kept missing things - this time we did an exhaustive code-level read of all three addons. The trigger: SpartanUI was missing party frame sorting (now added as `mode` option, but other sorting gaps remain).

**Note:** This is a reference document for planning future work, not a single implementation plan.

### Validation Status

All gaps validated by 3 independent code review agents on 2026-04-13. Corrections applied below.

### Items flagged for initial implementation pass:

- Power bar: auto-hide, only-show-for-healer, not-in-combat hide
- Castbar: display cast target name

### Post-Validation Corrections Applied:

- **Frame strata/level**: SpartanUI ALREADY HAS THIS (Health.lua, Power.lua, Castbar.lua all call SetFrameStrata/SetFrameLevel). Removed from gaps.
- **Frame Glow System**: SpartanUI's TargetIndicator already covers target/focus/mouseover glow. Downgraded - only missing state-specific color per glow type.
- **Hover/Selection Highlight**: Already covered by TargetIndicator (ShowTarget, ShowMouseover modes). Removed from gaps.
- **Enrage tracking in dispel**: SpartanUI already tracks Enrage (DispelTypeEnum Enrage=9). Removed from gaps.
- **Targeted Spell Indicator**: Blizzard hotfixed UnitIsUnit API on 2026-04-07 - group-frame targeted spells permanently blocked. Personal display still works but group use case is dead. Downgraded from CRITICAL.
- **Missing Buff Indicator**: Trivially simple in DandersFrames (6 hardcoded spell IDs with UnitHasBuff check). Gap is real but very small scope.
- **Health Threshold Fade**: Frame-level only in DandersFrames too (not per-element). Corrected description.
- **Per-element OOR alpha**: Even more extensive than claimed (21+ sub-elements in DandersFrames). Understated.
- **Aura Designer**: Genuinely massive (~13K lines, 8 indicator types). Gap was understated.
- **Click-through auras**: AuraBars already have EnableMouse(false). Gap only affects Buffs/Debuffs icon elements.

---

## Current State Summary

| Metric                        | SpartanUI                                                                                                                               | DandersFrames                                                 | ElvUI                                                                                                         |
| ----------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| Unit types                    | 15 (player, target, pet, pettarget, targettarget, ttt, focus, focustarget, party, raid, boss, bosstarget, arena + partypet/partytarget) | 2 modes (party/raid) + pet + 2 pinned sets + 2 highlight sets | 16 (player, target, tt, ttt, focus, ft, pet, pettarget, boss, arena, party, raid1/2/3, tank, assist, raidpet) |
| Configurable options (approx) | ~300                                                                                                                                    | ~650+                                                         | ~500+                                                                                                         |
| Elements per frame            | 37                                                                                                                                      | ~25 (but each far deeper)                                     | 28+                                                                                                           |
| Framework                     | oUF + Ace3                                                                                                                              | Custom secure headers                                         | oUF + Ace3                                                                                                    |

---

## GAP ANALYSIS BY CATEGORY

### 1. GROUP FRAME SORTING & ORDERING

**SpartanUI HAS (verified in code):**

- `mode` select: ASSIGNEDROLE, GROUP, NAME (party.lua:165, raid.lua:212)
- `groupingOrder` computed from mode (TANK,HEALER,DAMAGER,NONE or 1-8)
- `maxColumns`, `unitsPerColumn`, `columnSpacing`, `xOffset`, `yOffset`
- `showRaid`, `showParty`, `showPlayer`, `showSolo`

**SpartanUI HARDCODES (verified):**

- `sortMethod` = `'index'` (party.lua:69, raid.lua:89) - user cannot change
- `columnAnchorPoint` = `'TOPLEFT'` for party (line 77), `'LEFT'` for raid (line 98) - user cannot change
- `point` = `'TOP'` for raid (line 83) - user cannot change
- No `sortDir` (ASC/DESC)

| Missing Feature                                        | Who Has It                                             | Severity     | Notes                                                               |
| ------------------------------------------------------ | ------------------------------------------------------ | ------------ | ------------------------------------------------------------------- |
| `sortMethod` user option (INDEX/NAME/GROUP)            | ElvUI                                                  | **HIGH**     | Currently hardcoded to 'index' even though `mode` changes `groupBy` |
| `sortDir` (ASC/DESC)                                   | ElvUI                                                  | **HIGH**     | No way to reverse sort order                                        |
| `columnAnchorPoint` user option                        | Both                                                   | **HIGH**     | Controls growth direction of columns - hardcoded                    |
| `point` user option (growth direction)                 | Both                                                   | **CRITICAL** | Controls whether frames stack DOWN, RIGHT, LEFT, UP                 |
| Combined growth directions (UP_RIGHT, DOWN_LEFT, etc.) | ElvUI (12+ combos)                                     | **HIGH**     | ElvUI has the most flexible growth system                           |
| Class-based sorting                                    | DandersFrames (`sortByClass` + reorderable class list) | **MEDIUM**   | Sort by class with custom class order                               |
| Separate melee/ranged DPS in role sort                 | DandersFrames (`sortSeparateMeleeRanged`)              | **MEDIUM**   | Unique to DandersFrames                                             |
| Reorderable role priority                              | DandersFrames (`sortRoleOrder` drag-and-drop)          | **MEDIUM**   | DandersFrames lets you reorder TANK/HEALER/MELEE/RANGED             |
| Self-position control                                  | DandersFrames (`sortSelfPosition: SORTED/FIRST/LAST`)  | **MEDIUM**   | Force yourself to top/bottom of group                               |
| `invertGroupingOrder`                                  | ElvUI                                                  | **MEDIUM**   | Reverse entire grouping order                                       |
| `raidWideSorting`                                      | ElvUI                                                  | **MEDIUM**   | Sort all units as one flat list instead of per-group                |
| `startFromCenter`                                      | ElvUI                                                  | **LOW**      | Grow frames outward from center                                     |
| Per-group visibility toggles (1-8)                     | DandersFrames (`raidGroupVisible`)                     | **MEDIUM**   | Hide specific raid groups                                           |
| Reorderable group display order                        | DandersFrames (`raidGroupDisplayOrder`)                | **LOW**      | Custom group numbering                                              |
| Multiple raid tiers                                    | ElvUI (raid1/2/3 with independent configs)             | **HIGH**     | Different layouts for 10-man vs 25-man vs 40-man                    |
| Visibility macro string                                | ElvUI (`visibility` macro condition)                   | **HIGH**     | `[@raid6,exists] show;hide` style conditions                        |
| Group labels                                           | DandersFrames (font, size, color, format)              | **MEDIUM**   | "Group 1", "Group 2" labels above raid groups                       |
| Flat vs grouped layout toggle                          | DandersFrames (`raidUseGroups`)                        | **MEDIUM**   | Completely flat layout alternative                                  |

---

### 2. HEALTH BAR

**SpartanUI HAS:**

- height, reverseFill, smoothAnimation, texture
- colorReaction, colorSmooth, colorClass, colorTapping, colorDisconnected
- bg (enabled, color, useClassColor)
- customColors (useCustom, barColor, healPredictionColor, absorbColor, healAbsorbColor)
- cutaway (enabled, duration, color)
- Heal prediction textures (healPrediction, absorb, healAbsorb, overflow)
- 2 text elements with tag system
- Missing-health color: achieved via FrameBackground element (set frame BG color, missing health shows through)

| Missing Feature                                   | Who Has It    | Severity   | Notes                                                                              |
| ------------------------------------------------- | ------------- | ---------- | ---------------------------------------------------------------------------------- |
| Bar orientation (HORIZONTAL/VERTICAL)             | Both          | **HIGH**   | Vertical health bars are a staple UF feature                                       |
| Gradient health coloring (3-tier with thresholds) | Both          | **HIGH**   | DandersFrames: High/Medium/Low with weights; ElvUI: healthBreak with thresholds    |
| Transparent health mode                           | ElvUI         | **MEDIUM** | Reverse-transparency visual effect                                                 |
| Invert health fill direction                      | ElvUI         | **MEDIUM** | Fill from right-to-left or top-to-bottom                                           |
| Custom health backdrop color                      | ElvUI         | **LOW**    | Separate backdrop color from bar color                                             |
| Dead state backdrop                               | ElvUI         | **MEDIUM** | Different background when unit is dead                                             |
| Class-colored backdrop                            | ElvUI         | **LOW**    | Backdrop uses class color                                                          |
| Heal prediction source split (mine/others/all)    | Both          | **HIGH**   | DandersFrames: MINE/OTHERS/ALL with separate colors; ElvUI: personal/others colors |
| Absorb bar display modes                          | DandersFrames | **HIGH**   | OVERLAY, ATTACHED_OVERFLOW, ATTACHED_CLAMP - 3 modes for how absorbs display       |
| Heal prediction overflow control                  | Both          | **MEDIUM** | User-configurable max overflow amount                                              |
| Missing health background with gradient colors    | DandersFrames | **HIGH**   | Separate gradient colors for the missing-health portion (beyond simple BG color)   |
| Per-power-type color customization                | ElvUI         | **HIGH**   | 11 individually configurable power type colors                                     |

---

### 3. POWER BAR

**SpartanUI HAS:**

- height, reverseFill, smoothAnimation, texture
- colorPower (automatic), customColors
- PowerPrediction (player only, Retail)
- 2 text elements

| Missing Feature                      | Who Has It | Severity   | Notes                                                                               |
| ------------------------------------ | ---------- | ---------- | ----------------------------------------------------------------------------------- |
| **Auto-hide power bar**              | ElvUI      | **HIGH**   | Hide when empty/not applicable. **FLAGGED FOR INITIAL IMPLEMENTATION.**             |
| **Only show for healer role**        | ElvUI      | **HIGH**   | Show power only on healer frames in groups. **FLAGGED FOR INITIAL IMPLEMENTATION.** |
| **Not-in-combat hide**               | ElvUI      | **MEDIUM** | Hide power bar outside combat. **FLAGGED FOR INITIAL IMPLEMENTATION.**              |
| Detach from frame                    | ElvUI      | **MEDIUM** | Float power bar independently                                                       |
| Power cutaway (separate from health) | ElvUI      | **MEDIUM** | SpartanUI only has health cutaway                                                   |

---

### 4. AURA SYSTEM (BUFFS/DEBUFFS)

**SpartanUI HAS:**

- number, size, rows, spacing, growthx/y, initialAnchor
- sortMode (priority/time/name - Retail limited to priority)
- Retail filter modes (8 presets + custom), Classic rules system
- showMounts, disableInPvP, customFilter
- smartPosition, whitelist/blacklist (Classic)
- maxDuration filter on AuraBars (Classic only, 900s default)

| Missing Feature                                                         | Who Has It    | Severity   | Notes                                                                                                                                                                                               |
| ----------------------------------------------------------------------- | ------------- | ---------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Click-through auras (Buffs/Debuffs icons)                               | Both          | **HIGH**   | Essential for healer click-casting. AuraBars already have `EnableMouse(false)`, but Buffs/Debuffs icon elements do NOT.                                                                             |
| Click-through in combat only                                            | DandersFrames | **MEDIUM** | Only click-through during combat                                                                                                                                                                    |
| Duration text customization (font, scale, outline, anchor, colorByTime) | DandersFrames | **HIGH**   | Full control over duration text appearance                                                                                                                                                          |
| Hide duration above threshold                                           | DandersFrames | **MEDIUM** | Don't show duration text for long buffs                                                                                                                                                             |
| Stack text customization (font, minimum, outline, scale, anchor)        | DandersFrames | **MEDIUM** | Full control over stack count text                                                                                                                                                                  |
| Aura border customization (thickness, inset)                            | DandersFrames | **MEDIUM** | Control border appearance                                                                                                                                                                           |
| Per-debuff-type border colors                                           | DandersFrames | **MEDIUM** | Magic=blue, Curse=purple, Disease=brown, Poison=green, Bleed=red                                                                                                                                    |
| Expiring aura effects (pulsate, tint, border glow)                      | DandersFrames | **HIGH**   | Visual emphasis when auras are about to expire                                                                                                                                                      |
| Expiring threshold mode (PERCENT vs SECONDS)                            | DandersFrames | **MEDIUM** | Choose how expiring is calculated                                                                                                                                                                   |
| Deduplicate defensives                                                  | DandersFrames | **MEDIUM** | WoW 12.0+ - avoid showing same defensive twice                                                                                                                                                      |
| Desaturate auras (non-player)                                           | ElvUI         | **LOW**    | Gray out auras not cast by you                                                                                                                                                                      |
| Min/max duration filter (Classic buffs/debuffs)                         | ElvUI         | **MEDIUM** | Filter out very short or very long auras. Note: Retail uses Blizzard filter API so this is Classic-only. SpartanUI already has maxDuration on AuraBars (Classic) but not on Buffs/Debuffs elements. |
| Sort direction (ASC/DESC)                                               | ElvUI         | **MEDIUM** | SpartanUI has sortMode but no direction control                                                                                                                                                     |
| Multiple sort methods (TIME, DURATION, NAME, INDEX, PLAYER)             | ElvUI         | **MEDIUM** | More granular sort control                                                                                                                                                                          |
| Auto-size aura icons from frame width                                   | ElvUI         | **MEDIUM** | ElvUI calculates icon size as `(frameWidth - spacing) / (perrow * numrows)` when `sizeOverride=0`. SpartanUI requires explicit size.                                                                |
| Keep size ratio toggle                                                  | ElvUI         | **LOW**    | When auto-sizing, force square icons vs allow custom height                                                                                                                                         |
| Tooltip anchor customization                                            | ElvUI         | **LOW**    | Control where aura tooltips appear                                                                                                                                                                  |
| Hide cooldown swipe                                                     | DandersFrames | **LOW**    | Remove the spinning cooldown overlay                                                                                                                                                                |
| Boss debuff overlay mode                                                | DandersFrames | **MEDIUM** | Large overlay display for critical mechanics                                                                                                                                                        |

---

### 5. CASTBAR

**SpartanUI HAS:**

- height, width, texture, bg color, customColors
- interruptable, FlashOnInterruptible, InterruptSpeed
- Shield icon (size, attachToTimer, position)
- Spell Icon (enabled, size, position)
- latency display (SafeZone)
- 2 text elements
- interruptibleColor

| Missing Feature                      | Who Has It | Severity   | Notes                                                                                             |
| ------------------------------------ | ---------- | ---------- | ------------------------------------------------------------------------------------------------- |
| Tick marks for channeled spells      | ElvUI      | **HIGH**   | Shows individual ticks on channeled spells - important for casters                                |
| **Display cast target name**         | ElvUI      | **HIGH**   | Shows who the enemy is casting at - critical for healers. **FLAGGED FOR INITIAL IMPLEMENTATION.** |
| Cast time format (REMAINING/ELAPSED) | ElvUI      | **MEDIUM** | Choose countdown vs countup display                                                               |
| Spark/progress indicator             | ElvUI      | **MEDIUM** | Bright line at current cast position                                                              |
| Reverse fill direction               | ElvUI      | **LOW**    | Fill bar right-to-left                                                                            |
| Overlay on frame                     | ElvUI      | **MEDIUM** | Display castbar overlaid on health bar                                                            |
| Time to hold after complete          | ElvUI      | **LOW**    | Keep castbar visible briefly after cast finishes                                                  |
| Use class/reaction color             | ElvUI      | **MEDIUM** | Color castbar by class or reaction                                                                |
| Custom text/time fonts               | ElvUI      | **LOW**    | Separate fonts for spell name vs timer                                                            |

---

### 6. FADER / VISIBILITY / RANGE SYSTEM

**SpartanUI HAS:**

- Range element: insideAlpha, outsideAlpha (whole-frame only)
- Group visibility toggles (showRaid, showParty, showPlayer, showSolo)

| Missing Feature                             | Who Has It    | Severity     | Notes                                                                                     |
| ------------------------------------------- | ------------- | ------------ | ----------------------------------------------------------------------------------------- |
| **State-based fader system**                | ElvUI         | **CRITICAL** | 10+ triggers: combat, hover, health, casting, playertarget, power, vehicle, dynamicflight |
| Fader min/max alpha with smooth transitions | ElvUI         | **HIGH**     | Configurable alpha range with smooth animation                                            |
| Per-instance-difficulty visibility          | ElvUI         | **HIGH**     | Different visibility in M+, heroic raid, etc. (9 difficulty types)                        |
| Per-element OOR alpha control               | DandersFrames | **CRITICAL** | Fade individual elements independently when OOR (14+ elements)                            |
| Per-element dead state alpha                | DandersFrames | **HIGH**     | Fade individual elements when unit is dead                                                |
| Health threshold fade                       | DandersFrames | **MEDIUM**   | Fade frame when health is above threshold (full health = faded)                           |
| Cancel fade on dispel                       | DandersFrames | **LOW**      | Briefly show full alpha when dispelling                                                   |
| Range check spell ID customization          | DandersFrames | **MEDIUM**   | Choose which spell determines range (auto-detect or manual)                               |
| Range update interval                       | DandersFrames | **LOW**      | How often to check range                                                                  |

---

### 7. DISPEL / DEBUFF HIGHLIGHTING

**WARNING:** Any dispel changes MUST be their own separate commit. The dispel system was extensively debugged for WoW 12.0 secret values and is fragile. Do not bundle with other work.

**SpartanUI HAS:**

- Full dispel system with border, typeIcon, debuffIcon
- onlyShowDispellable toggle
- Per-type colors
- Secret-value safe with canaccessvalue()

| Missing Feature                    | Who Has It        | Severity   | Notes                                                                                                  |
| ---------------------------------- | ----------------- | ---------- | ------------------------------------------------------------------------------------------------------ |
| Gradient overlay mode              | DandersFrames     | **HIGH**   | Gradient wash over frame (TOP/BOTTOM/LEFT/RIGHT) with intensity control                                |
| Border style options (OUTER/INNER) | DandersFrames     | **LOW**    | Control border placement                                                                               |
| Animation effects                  | DandersFrames     | **LOW**    | Animated dispel overlay                                                                                |
| Per-type enable/disable toggles    | DandersFrames     | **MEDIUM** | Toggle individual debuff types (show Poison but hide Curse)                                            |
| ~~Enrage tracking~~                | ~~DandersFrames~~ | ~~MEDIUM~~ | **ALREADY EXISTS** - SpartanUI Dispel.lua has `Enrage = 9` in DispelTypeEnum with color curve support. |
| debuffHighlighting fill mode       | ElvUI             | **MEDIUM** | FILL mode with blend mode control                                                                      |

---

### 8. THREAT INDICATOR

**SpartanUI HAS:**

- Styles: glow, aggro, icon_TL/TR/BL/BR
- 4 threat level colors, iconSize

| Missing Feature                                 | Who Has It    | Severity   | Notes                                    |
| ----------------------------------------------- | ------------- | ---------- | ---------------------------------------- |
| BORDERS / HEALTHBORDER / INFOPANELBORDER styles | ElvUI         | **MEDIUM** | More border-based threat display options |
| Aggro-only-tanking toggle                       | DandersFrames | **LOW**    | Only show threat when actually tanking   |
| Border thickness/inset control                  | DandersFrames | **LOW**    | Fine-tune threat border appearance       |
| 8 icon position options                         | ElvUI         | **LOW**    | All 4 corners + 4 edges                  |

---

### 9. COLOR SYSTEM

**SpartanUI HAS:**

- Health: reaction, smooth, class, tapping, disconnected + custom bar/prediction colors
- Power: automatic power type coloring + custom
- Castbar: custom bar + interruptible colors
- Threat: 4 level colors
- FrameBackground: per-side border colors + class colors
- Name: textColor with useCustomColor

| Missing Feature                                  | Who Has It | Severity   | Notes                                                                       |
| ------------------------------------------------ | ---------- | ---------- | --------------------------------------------------------------------------- |
| Per-power-type color customization (11 types)    | ElvUI      | **HIGH**   | Mana, Rage, Energy, Focus, Runic Power, etc. each individually configurable |
| Reaction colors (8 levels individually)          | ElvUI      | **HIGH**   | Customize Hated through Exalted colors individually                         |
| Selection colors (9 states)                      | ElvUI      | **LOW**    | Different colors for different selection states                             |
| Color override per unit (FORCE_ON/OFF/ALWAYS)    | ElvUI      | **MEDIUM** | Force class coloring on specific units                                      |
| Transparent/invert mode per bar type             | ElvUI      | **MEDIUM** | Transparency and inversion toggles per bar                                  |
| 3-tier gradient health (configurable thresholds) | Both       | **HIGH**   | Full threshold-based color system                                           |

---

### 10. FRAME-LEVEL OPTIONS

**SpartanUI HAS:**

- width per frame (user-configurable)
- height calculated from element heights
- Frame position via MoveIt system (includes snapping)
- Preset system for theme switching

| Missing Feature                | Who Has It    | Severity   | Notes                                                                                                                     |
| ------------------------------ | ------------- | ---------- | ------------------------------------------------------------------------------------------------------------------------- |
| ~~Frame strata/level control~~ | ~~ElvUI~~     | ~~HIGH~~   | **ALREADY EXISTS** in SpartanUI - Health.lua, Power.lua, Castbar.lua all support DB.FrameStrata/DB.FrameLevel             |
| Info panel element             | ElvUI         | **MEDIUM** | Dedicated text/icon panel area                                                                                            |
| Unlimited custom text elements | ElvUI         | **HIGH**   | User-defined text tags anywhere on frame (SpartanUI has tags in Health/Power/Name but not arbitrary custom text elements) |
| Frame padding                  | DandersFrames | **LOW**    | Internal frame padding                                                                                                    |

---

### 11. FEATURES COMPLETELY ABSENT FROM SPARTANUI

These are entire feature categories that competitors have:

| Missing Feature                              | Who Has It        | Severity   | Description                                                                                                                                                                                                                                                                                              |
| -------------------------------------------- | ----------------- | ---------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Targeted Spell Indicator**                 | DandersFrames     | **MEDIUM** | Shows enemy casts targeting group members. **BUT: Blizzard hotfixed UnitIsUnit API (2026-04-07) - group-frame version permanently blocked.** Only personal display still works. DandersFrames force-disabled this feature. Implementing would only give personal-target display.                         |
| **Targeted Spell List (stacked bars)**       | DandersFrames     | **MEDIUM** | Party-mode stacked cast bar display. Designed as replacement for blocked Targeted Spell system but still in development in DandersFrames.                                                                                                                                                                |
| **Pinned Frames** (2 custom sets)            | DandersFrames     | **HIGH**   | Manually pin specific players to custom frame groups with auto-add by role                                                                                                                                                                                                                               |
| **Aura Designer** (custom aura system)       | DandersFrames     | **HIGH**   | Full custom aura definition system per-spec with layout groups, sound alerts                                                                                                                                                                                                                             |
| **External Defensive Indicator**             | DandersFrames     | **MEDIUM** | Separate element for externals cast on you (Guardian Spirit, Pain Supp, etc.)                                                                                                                                                                                                                            |
| **Defensive Bar** (multi-icon)               | DandersFrames     | **MEDIUM** | Shows multiple active defensives as a bar (separate from single icon)                                                                                                                                                                                                                                    |
| **Tank/Assist Priority Frames**              | ElvUI             | **MEDIUM** | Dedicated frames for tank/assist roles in raid                                                                                                                                                                                                                                                           |
| **PvP Trinket Indicator**                    | ElvUI             | **MEDIUM** | Arena trinket cooldown tracking                                                                                                                                                                                                                                                                          |
| **Frame Glow: per-state colors**             | ElvUI             | **MEDIUM** | SpartanUI's TargetIndicator already handles target/focus/mouseover glow - but lacks separate color customization per glow state (target=yellow, focus=orange, mouseover=white are defaults but not independently configurable per-state in full). ElvUI allows class color + custom color per glow type. |
| ~~**Hover Highlight**~~                      | ~~DandersFrames~~ | ~~MEDIUM~~ | **ALREADY EXISTS** - SpartanUI TargetIndicator has ShowMouseover mode with texture/border display.                                                                                                                                                                                                       |
| ~~**Selection Highlight**~~                  | ~~DandersFrames~~ | ~~MEDIUM~~ | **ALREADY EXISTS** - SpartanUI TargetIndicator has ShowTarget mode with texture/border display.                                                                                                                                                                                                          |
| **AFK/Status Icons**                         | DandersFrames     | **MEDIUM** | SpartanUI has StatusText with `[afkdnd]` tag (text) and separate LeaderIndicator/PhaseIndicator (icons). DandersFrames adds: AFK timer countdown, hideInCombat per-icon toggles, LFG eye on phased icon, vehicle icon with text. Gap is incremental, not wholesale.                                      |
| **Resource Bar** (per-class filter for raid) | DandersFrames     | **MEDIUM** | Show mana/energy bars on raid frames with per-class enable                                                                                                                                                                                                                                               |
| **Dead state per-element alpha**             | DandersFrames     | **HIGH**   | Independent alpha for each element when unit is dead                                                                                                                                                                                                                                                     |
| **Missing Health Background with gradient**  | DandersFrames     | **HIGH**   | Gradient colors for missing-health portion (SpartanUI has simple BG color via FrameBackground, but no gradient)                                                                                                                                                                                          |
| **Personal Targeted Spell** (off-frame)      | DandersFrames     | **MEDIUM** | Nameplate-style display for spells targeting you, separate from on-frame                                                                                                                                                                                                                                 |
| **6 separate tooltip configs**               | DandersFrames     | **MEDIUM** | Buff/Debuff/Aura/Defensive/Keybind/Frame tooltips each independently configured                                                                                                                                                                                                                          |

---

## COMPLETE GAP RANKING (All Gaps by Severity)

### CRITICAL

1. **Growth direction control** - `columnAnchorPoint` and `point` are hardcoded in party.lua and raid.lua. Users cannot arrange group frames horizontally or in compound directions. Both competitors offer this.
2. **State-based fader system** - ElvUI has 10+ triggers (combat, hover, health, casting, etc.). SpartanUI has zero fader support beyond basic range alpha.
3. **Per-element OOR/dead alpha** - DandersFrames lets you 21+ sub-elements fade independently when out of range or dead. SpartanUI fades the whole frame uniformly.

### HIGH

4. **Bar orientation (H/V)** - Vertical health bars. Both competitors support this.
5. **Gradient/3-tier health coloring** - Configurable color thresholds. Both competitors.
6. **Heal prediction source split (mine/others/all)** - Both competitors split by source. SpartanUI has single combined `healingAll` bar.
7. **Absorb bar display modes** - DandersFrames: OVERLAY, ATTACHED_OVERFLOW, ATTACHED_CLAMP.
8. **Click-through auras (Buffs/Debuffs icons)** - Both competitors. AuraBars already have it, Buffs/Debuffs do not.
9. **Aura expiring effects (pulsate, tint, glow)** - DandersFrames. Visual emphasis when auras expire.
10. **Duration/stack text customization** - DandersFrames. Font, scale, anchor, colorByTime.
11. **Castbar tick marks** - ElvUI. Shows ticks on channeled spells.
12. **Castbar target display** - ElvUI. Shows who enemy is casting at. **FLAGGED FOR INITIAL IMPLEMENTATION.**
13. **Multiple raid tiers** - ElvUI. Different configs for 10/25/40-man.
14. **Visibility macro conditions** - ElvUI. Conditional show/hide strings.
15. **`sortMethod` as user setting** - Currently hardcoded to 'index'.
16. **`sortDir` (ASC/DESC)** - No way to reverse sort order.
17. **`columnAnchorPoint` user option** - Hardcoded, controls column growth direction.
18. **Combined growth directions** - ElvUI has 12+ compound growth directions.
19. **Per-power-type colors** - ElvUI. Customize mana/rage/energy/etc. individually.
20. **Unlimited custom text elements** - ElvUI. User-defined text tags anywhere on frame (SpartanUI has tags on Health/Power/Name but not arbitrary custom text placement).
21. **Power bar auto-hide** - ElvUI. Hide when empty/not applicable. **FLAGGED FOR INITIAL IMPLEMENTATION.**
22. **Power bar only-show-for-healer** - ElvUI. Show power only on healer frames. **FLAGGED FOR INITIAL IMPLEMENTATION.**
23. **Reaction colors (8 levels individually)** - ElvUI. Customize per-reaction-level.
24. **Per-element dead state alpha** - DandersFrames. Independent alpha per element when dead (21+ sub-elements).
25. **Missing health background with gradient** - DandersFrames. Gradient colors for missing-health portion (beyond SpartanUI's simple FrameBackground).
26. **Pinned Frames** - DandersFrames. Custom frame groups for specific players using real SecureGroupHeaders.
27. **Aura Designer** - DandersFrames. Full custom aura engine (~13K lines, 8 indicator types, sound alerts). Very substantial.
28. **Fader min/max alpha** - ElvUI. Configurable alpha range with smooth animation.
29. **Per-instance-difficulty visibility** - ElvUI. Different visibility per difficulty type.

### MEDIUM-A (Raid sorting/layout + practical enhancements)

**Raid Sorting & Layout (top priority):**

49. **Class-based sorting** - DandersFrames. Sort by class with custom order.
50. **Separate melee/ranged DPS in role sort** - DandersFrames. Unique feature.
51. **Reorderable role priority** - DandersFrames. Drag-and-drop role order.
52. **Self-position control** - DandersFrames. Force self to FIRST/LAST/SORTED.
53. **`invertGroupingOrder`** - ElvUI. Reverse grouping.
54. **`raidWideSorting`** - ElvUI. Sort all units as one flat list.
55. **Per-group visibility toggles (1-8)** - DandersFrames. Hide specific groups.
56. **Group labels** - DandersFrames. Labels above raid groups.
57. **Flat vs grouped layout** - DandersFrames. Toggle between modes.

**Aura Enhancements:**

32. **Click-through in combat only** - DandersFrames. Aura click-through limited to combat.
33. **Hide duration above threshold** - DandersFrames. Don't show duration for long buffs.
34. **Stack text customization** - DandersFrames. Font/minimum/outline/scale/anchor.
35. **Aura border customization** - DandersFrames. Thickness/inset control.
40. **Sort direction (ASC/DESC) for auras** - ElvUI. SpartanUI has sortMode but no direction.
41. **Multiple sort methods for auras** - ElvUI. TIME, DURATION, NAME, INDEX, PLAYER.
42. **Auto-size aura icons from frame width** - ElvUI. Calculates `(frameWidth - spacing) / (perrow * numrows)` when `sizeOverride=0`.

**Power/Health/Castbar:**

30. **Power bar not-in-combat hide** - ElvUI. **FLAGGED FOR INITIAL IMPLEMENTATION.**
43. **Cast time format (REMAINING/ELAPSED)** - ElvUI. Countdown vs countup.
44. **Spark/progress indicator on castbar** - ElvUI. Bright line at cast position. (Note: oUF provides Spark element, SpartanUI doesn't use it.)
46. **Use class/reaction color on castbar** - ElvUI. Color by class or reaction.
47. **Health threshold fade** - DandersFrames. Fade entire frame when health above threshold (frame-level only, not per-element).

**Other Practical:**

36. **Per-debuff-type border colors** - DandersFrames. Per-type color customization (SpartanUI has CornerIndicators as alternative approach using corner squares for Magic/Curse/Poison/Disease).
37. **Expiring threshold mode** - DandersFrames. PERCENT vs SECONDS calculation.
38. **Deduplicate defensives** - DandersFrames. WoW 12.0+ deduplication.
48. **Range check spell ID customization** - DandersFrames. Choose range-checking spell (auto-detect or manual).
58. **Per-type enable/disable toggles for dispel** - DandersFrames. Show Poison but hide Curse. **SEPARATE COMMIT REQUIRED.**
68. **Frame Glow: per-state colors** - ElvUI. SpartanUI TargetIndicator has target/focus/mouseover glow, but lacks independent color per glow type.

### MEDIUM-B (Remaining enhancements)

31. **Dispel gradient overlay mode** - DandersFrames. Gradient wash with intensity control. **SEPARATE COMMIT REQUIRED.**
39. **Min/max duration filter (Classic buffs/debuffs)** - ElvUI. Already on AuraBars, missing from Buffs/Debuffs elements. Classic-only.
45. **Overlay castbar on frame** - ElvUI. Display castbar overlaid on health bar.
59. **debuffHighlighting fill/blend mode** - ElvUI. FILL mode control.
60. **BORDERS/HEALTHBORDER/INFOPANELBORDER threat styles** - ElvUI. More styles.
61. **Color override per unit** - ElvUI. Force class coloring per unit.
62. **Transparent/invert mode per bar** - ElvUI. Per-bar-type toggles.
63. **Info panel element** - ElvUI. Dedicated text/icon panel.
64. **External Defensive Indicator** - DandersFrames. Separate element for externals (SpartanUI's DefensiveIndicator tracks externals but only shows one at a time).
65. **Defensive Bar (multi-icon grid)** - DandersFrames. Grid layout with growth direction + wrapping, genuinely different from single DefensiveIcon.
66. **Tank/Assist Priority Frames** - ElvUI. Dedicated raid role frames.
67. **PvP Trinket Indicator** - ElvUI. Arena trinket tracking.
69. **AFK/Status Icons enhancements** - DandersFrames. AFK timer, hideInCombat per-icon, LFG eye on phased. SpartanUI has text + separate indicator elements - gap is incremental.
70. **Resource Bar per-class filter** - DandersFrames. Per-class enable for raid.
71. **Targeted Spell Indicator (personal only)** - DandersFrames. Group-frame version API-blocked by Blizzard. Personal display still works.
72. **Targeted Spell List** - DandersFrames. Stacked bar display, still in development.
73. **Missing Buff Indicator** - DandersFrames. Simple spell ID watchlist (6 buffs). Low implementation effort.
74. **Personal Targeted Spell (off-frame)** - DandersFrames. Nameplate-style display.
75. **6 separate tooltip configs** - DandersFrames. Per-element-type tooltip settings.
76. **Transparent health mode** - ElvUI. Reverse-transparency.
77. **Invert health fill direction** - ElvUI. Right-to-left fill.
78. **Dead state backdrop** - ElvUI. Different BG when dead.
79. **Heal prediction overflow control** - Both. User-configurable max overflow.
80. **Detach power bar from frame** - ElvUI. Float independently.
81. **Power cutaway** - ElvUI. Separate from health cutaway.
82. **Boss debuff overlay mode** - DandersFrames. Large overlay for mechanics.

### LOW (Niche features)

87. **`startFromCenter`** - ElvUI. Grow outward from center.
88. **Reorderable group display order** - DandersFrames. Custom group numbering.
89. **Desaturate auras (non-player)** - ElvUI. Gray out non-player auras.
90. **Keep size ratio toggle** - ElvUI. Force square icons during auto-sizing.
91. **Tooltip anchor customization** - ElvUI. Control tooltip position.
92. **Hide cooldown swipe** - DandersFrames. Remove spinning overlay.
93. **Reverse castbar fill** - ElvUI. Right-to-left fill.
94. **Time to hold castbar** - ElvUI. Keep visible after cast.
95. **Custom text/time castbar fonts** - ElvUI. Separate fonts.
96. **Cancel fade on dispel** - DandersFrames. Brief show after dispel.
97. **Range update interval** - DandersFrames. How often to check.
98. **Aggro-only-tanking toggle** - DandersFrames. Only show when tanking.
99. **Border thickness/inset (threat)** - DandersFrames. Fine-tune.
100.  **8 icon position options (threat)** - ElvUI. All corners + edges.
101.  **Selection colors (9 states)** - ElvUI. Per-selection-state colors.
102.  **Custom health backdrop color** - ElvUI. Separate from bar.
103.  **Class-colored backdrop** - ElvUI. Backdrop uses class color.
104.  **Frame padding** - DandersFrames. Internal padding.
105.  **Dispel border style (OUTER/INNER)** - DandersFrames. Placement control.
106.  **Dispel animation effects** - DandersFrames. Animated overlay.

---

## DEFAULT VALUE COMPARISON (Key Elements)

### Health Bar Defaults

| Setting          | SpartanUI                  | DandersFrames        | ElvUI                     |
| ---------------- | -------------------------- | -------------------- | ------------------------- |
| Height           | 40                         | 64 (full frame)      | Varies by unit            |
| Orientation      | HORIZONTAL (only)          | HORIZONTAL (default) | HORIZONTAL (default)      |
| Color mode       | colorClass + colorReaction | CLASS (default)      | health-by-value (default) |
| Smooth animation | false                      | true                 | false                     |
| Heal prediction  | true (combined)            | true (MINE default)  | false (most units)        |
| Cutaway          | false                      | N/A                  | false                     |
| Text format      | `[SUIHealth(dynamic)]`     | CURRENTMAX           | Tag-based                 |

### Power Bar Defaults

| Setting    | SpartanUI           | DandersFrames | ElvUI |
| ---------- | ------------------- | ------------- | ----- |
| Height     | 10                  | 4             | 10    |
| Enabled    | true                | false         | true  |
| Auto-hide  | N/A                 | N/A           | false |
| Prediction | false (player only) | N/A           | false |

### Buffs Defaults

| Setting       | SpartanUI     | DandersFrames      | ElvUI                          |
| ------------- | ------------- | ------------------ | ------------------------------ |
| Count         | 10-32         | 5                  | 8 per row                      |
| Size          | 20-24         | 24                 | 0 (auto-calc from frame width) |
| Rows          | 2-4           | wrap=3             | 1                              |
| Click-through | N/A           | true               | false                          |
| Sort          | priority      | TIME               | TIME_REMAINING DESC            |
| Duration text | none (spiral) | full customization | CENTER                         |

### Debuffs Defaults

| Setting       | SpartanUI       | DandersFrames   | ElvUI          |
| ------------- | --------------- | --------------- | -------------- |
| Count         | 10-16           | 5               | 8 per row      |
| Size          | 20-28           | 18              | 0 (auto-calc)  |
| Type borders  | showType (bool) | per-type colors | by debuff type |
| Click-through | N/A             | true            | false          |

### Group Frame Defaults

| Setting       | SpartanUI                | DandersFrames                   | ElvUI        |
| ------------- | ------------------------ | ------------------------------- | ------------ |
| Party width   | 120                      | 125                             | 230          |
| Raid width    | 95                       | N/A (same frame)                | 80           |
| Sort mode     | ASSIGNEDROLE             | role (TANK>HEALER>MELEE>RANGED) | INDEX        |
| Sort method   | index (hardcoded)        | custom                          | INDEX        |
| Growth        | DOWN (hardcoded)         | HORIZONTAL                      | UP_RIGHT     |
| Party columns | 1                        | 1                               | 1            |
| Raid columns  | 4                        | 8 groups x 5                    | 1            |
| Column anchor | TOPLEFT/LEFT (hardcoded) | configurable                    | configurable |

### Range/OOR Defaults

| Setting         | SpartanUI   | DandersFrames             | ElvUI       |
| --------------- | ----------- | ------------------------- | ----------- |
| In-range alpha  | 1.0         | N/A (per-element)         | 1.0         |
| OOR alpha       | 0.3         | 0.2 (health bar)          | 0.35        |
| Per-element OOR | NO          | YES (14+ elements)        | NO          |
| Range method    | oUF default | spell-based (auto-detect) | oUF default |

---

## ElvUI Auto-Size Aura Icons Explained

When ElvUI's `sizeOverride = 0` (the default), it auto-calculates icon size:

```
size = (UNIT_WIDTH - spacing * (perrow - 1) - borderWidth) / (perrow * numrows) * numrows
```

- `UNIT_WIDTH` = frame width
- `borderWidth` = 2px if not thin borders, 0 otherwise
- When `keepSizeRatio = true` (default): height = width (square icons)
- When `keepSizeRatio = false`: allows custom height independent of width

The aura container width also auto-sizes to match the frame width minus standard spacing.

---

## Files Relevant for Implementation

### Group Sorting/Growth (Priority 1)

- `Modules/UnitFrames/Units/party.lua:68-77` - Hardcoded sortMethod, columnAnchorPoint
- `Modules/UnitFrames/Units/raid.lua:88-98` - Same hardcoded values
- `Modules/UnitFrames/Options.lua:1363-1426` - AddGroupLayout needs new options

### Power Bar (Priority 2 - flagged items)

- `Modules/UnitFrames/Elements/Power.lua` - Auto-hide, healer-only, not-in-combat

### Castbar (Priority 2 - flagged items)

- `Modules/UnitFrames/Elements/Castbar.lua` - Target display, tick marks

### Health Bars (Priority 3)

- `Modules/UnitFrames/Elements/Health.lua` - Orientation, gradient, absorb modes

### Aura System (Priority 4)

- `Modules/UnitFrames/Elements/Buffs.lua` - Click-through, duration text, expiring effects
- `Modules/UnitFrames/Elements/Debuffs.lua` - Same + per-type borders

### Dispel (SEPARATE COMMITS ONLY)

- `Modules/UnitFrames/Elements/Dispel.lua` - Gradient overlay, per-type toggles

### New Elements (Priority 5)

- Would need new element files for: Targeted Spell, Fader system

---

## User-Friendliness Evaluation (7th-Grade Test)

For items where SpartanUI already has the feature but implements it differently, which approach would a 7th grader find easiest to understand and use?

### Missing-Health Background Color (SpartanUI: FrameBackground vs DandersFrames: dedicated gradient)

- **SpartanUI approach**: Set FrameBackground color, missing health "shows through" the bar. Indirect - user must understand that bar transparency reveals the background.
- **DandersFrames approach**: Dedicated "missing health color" option with gradient support (high/low colors).
- **7th-grade verdict**: DandersFrames wins. A kid setting up raid frames would look for "what color is missing health" and find it directly. SpartanUI's approach requires understanding layering. **Recommendation**: Add a dedicated "Missing Health Color" option that internally sets FrameBackground, so users find it where they expect it. Keep FrameBackground for advanced users.

### Per-Debuff-Type Border Colors (SpartanUI: CornerIndicators vs DandersFrames: colored aura borders)

- **SpartanUI approach**: Corner squares (small colored dots in corners) indicate Magic/Curse/Poison/Disease.
- **DandersFrames approach**: The entire aura icon border changes color by debuff type.
- **7th-grade verdict**: Both are intuitive in different ways. Corner indicators are subtle and clean; colored borders are more obvious. Neither is clearly "wrong." **Recommendation**: Keep CornerIndicators as-is, but add optional per-type border colors on the aura icons themselves (item #36) as a separate feature. Let users choose their preferred style.

### AFK/Status Display (SpartanUI: text tag vs DandersFrames: icons + timer)

- **SpartanUI approach**: `[afkdnd]` text tag shows "AFK" or "DND" as text on the frame.
- **DandersFrames approach**: Dedicated icon with countdown timer, per-icon hideInCombat.
- **7th-grade verdict**: Text is immediately readable ("AFK" is clear). But a countdown timer ("AFK 3:42") tells you MORE - how long they've been gone. **Recommendation**: Enhance the existing text tag to optionally include elapsed time. No need for a separate icon element - the text approach is already user-friendly. Add `[afkdnd:timer]` tag variant.

### External Defensives (SpartanUI: DefensiveIndicator vs DandersFrames: separate External element)

- **SpartanUI approach**: Single DefensiveIndicator element tracks both personal and external defensives, shows one icon at a time.
- **DandersFrames approach**: Separate "External Defensive Indicator" element, plus a "Defensive Bar" showing multiple icons in a grid.
- **7th-grade verdict**: For a healer learning to track cooldowns, seeing "Guardian Spirit is on Player X" as a single clear icon is enough. Multi-icon display is power-user territory. **Recommendation**: Current approach is fine for most users. Multi-icon defensive bar (item #65) is a MEDIUM priority enhancement, not a gap in usability.

### Frame Growth Direction (SpartanUI: hardcoded DOWN vs ElvUI: 12+ directions)

- **SpartanUI approach**: Party grows DOWN, raid grows DOWN in columns from LEFT. No user control.
- **ElvUI approach**: 12+ compound growth directions (UP_RIGHT, DOWN_LEFT, etc.) with separate `point` and `columnAnchorPoint`.
- **7th-grade verdict**: A kid arranging their screen would think "I want my party on the left going down" or "I want my raid across the bottom." Not being able to change growth direction is genuinely confusing when frames don't fit where you want them. **Recommendation**: This is the #1 usability gap. Add at minimum a simple "Growth Direction" dropdown with plain options: "Down", "Up", "Right", "Left". Compound directions can come later.

### Click-Through Auras (SpartanUI: not available vs competitors: toggle)

- **SpartanUI approach**: Aura icons intercept clicks. If you click on a buff icon over a raid frame, you interact with the aura, not the unit.
- **Both competitors**: Toggle to make auras click-through so clicks pass to the unit frame underneath.
- **7th-grade verdict**: A healer clicking on raid frames to heal will be confused and frustrated when their click lands on a buff icon instead of the player. This is a "why isn't my heal working?!" moment. **Recommendation**: HIGH priority. Simple toggle, massive UX improvement for healers.

---

For any implemented changes:

1. Test in-game with `/rl` after each change
2. Verify party frames sort correctly with new sort options
3. Verify raid frames with all growth directions
4. Test with secret values (combat + tainted context)
5. Verify preset system saves/restores new settings
6. Test Classic compatibility where applicable
7. Dispel changes: test all debuff types, verify canaccessvalue() guards intact
