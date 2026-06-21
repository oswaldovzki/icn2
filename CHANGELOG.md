# CHANGELOG

## v1.7.1

### WA-1 Refactor race modifiers and max pools

- Update and normalize ICN2.RACE_MODIFIERS values and comments, adjusting hunger/thirst/fatigue modifiers for many races for better balance.
- Introduce a consolidated ICN2.RACE_MAX_VALUES table (moved earlier) with per-race point pools and added neutral/other races (Pandaren, Dracthyr, EarthenDwarf, Haranir).
- Remove the old duplicate RACE_MAX_VALUES block at the end and clean up explanatory comments.
- TOC update to 1.7.1.

## v1.8.0

### WA-1 Switch needs to fixed-point values; add localization

- Convert hunger/thirst/fatigue recovery and bonuses from percentage-based to fixed-point values so all races gain the same absolute points.
- Update food/drink trickle, feast behavior, manual Eat/Drink/Rest defaults, and fatigue recovery logic/comments to use points/sec semantics.
- Improve item detection for food/drink (use container item IDs and class/subclass filtering + tooltip API) and adjust completion bonus math/printouts accordingly.
- Add ICN2_Localization.lua (English + ptBR), laying the ground for future languages support.
- Also fix race name typo (Harronir) and simplify race lookup in GetMaxValue.
- TOC update to 1.8.0.

## v1.8.1

### Track Well Fed eligibility to prevent reapply

- Add a wellFedEligible saved flag and eating-linked eligibility logic to prevent the Well Fed hunger-pause from reapplying across UI reloads/portals.
- ICN2_Data.lua: introduce defaults.wellFedEligible. ICN2_FoodDrink.lua: document the rework, persist wellFedEligible in ICN2DB, set it true when eating starts, and consume it when the Well Fed pause is applied (checked alongside auraInstanceID).
- Also minor comment and formatting tweaks.
- TOC update to 1.8.1.

## v2.0.0

### Refactor rate engine, food/drink, debug UI

- Large cleanup and behavior changes across core modules: bump TOC version to 2.0.0, add a data migration to reset decayRates for the new logic, and adjust default presets/values. Add an "instance" situation mode (apply neutral modifiers & short-circuit aura scanning/display) and improve situation label handling in Core. Tweak race/class modifiers and RACE_MAX_VALUES for better balance.
- Food/Drink: simplify tier math and adjust tier values, improve aura/item detection (nil guards, tooltip API, container/class/subclass checks), prevent aura scanning in instances/combat, implement wellFedEligible handling and robust Well Fed pause consumption. Emotes: prevent emotes in combat, respect min intervals and chance checks, minor cleanup.
- Debug/UI: enlarge and polish debug window (sizes, font), improve serializer/pretty-printing, streamline snapshot pipeline and refresh/select controls, update debug version tag. Misc: various formatting/comment tweaks and VSCode Lua diagnostics/globals added, and CHANGELOG reorganized with new v1.8.x entries.
- TOC update to 2.0.0.

## v2.1.0

### Localization

- Localized UI and chat messages; added combat guard to prevent aura scanning in unsafe contexts.
- Extended localization coverage and replaced remaining hardcoded strings across all modules.
- Revamped localization system: standardized color codes, improved fallback behavior, and expanded string coverage.

### Aura Scanning

- Added persistent aura cache with delta-based updates, reducing redundant scans and improving tick performance.

## v2.2.0

### Accessibility

- Added preliminary support for future accessibility options, including colorblindness.

## v2.2.1

### TOC

- Updated TOC version to support 12.0.7.

## v2.3.0

### Food Quality

- Food/Drink now restores more points the higher its quality
- Common (white) restores 30 points
- Uncommon (green) restores 40 points
- Rare (blue and higher) restores 60 points

### UI Updates

- Refactored UI rendering code to improve maintainability and support future updates.
- Updated state icons for clarity.
- Adjusted recovery and decay state indicator thresholds.
- Moved all images to a dedicated "assets" folder.
- Fixed issues with the Blocky theme.
- Tuned default values for Fast and Realistic settings.
- Increased Instanced decay by 10%.
- Increased Hunger recovery from Cannibalize to 60 points.

## Known Issues

- Certain Drink (I believe legacy items) items do not apply the "Drink" aura and therefore fail to restore "Thirst".
- This behavior has been reported to Blizzard; it is unclear whether it is intended.
- Workaround: Manually replenish the "Thirst" state via the ICN2 settings menu.
