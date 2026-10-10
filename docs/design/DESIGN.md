# Guldr Design System

> *Your gold, in order.* Warm Scandinavian minimalism: a quiet neutral base, one matte-gold accent, Apple system typography. It must feel 100% iPhone and still unmistakably Guldr.

This folder is the single source of truth for Guldr's visual design. The approved mockups live in `mockups/`; every value below was taken from them. **Do not invent new colors, sizes or radii.** If something is missing, ask before adding it and then record it here.

## Folder map

| Path | What it is |
|---|---|
| `DESIGN.md` | This file: rules, tokens, component specs |
| `tokens.json` | Machine-readable tokens (colors light/dark, type, radii, spacing, sizes) |
| `Guldr/Resources/GuldrColors.xcassets` | Ready-to-use color sets with light and dark appearances (21 colors) |
| `mockups/*.dc.html` | Approved screen designs (HTML source). Read them for exact values; each shows light and dark side by side |
| `icon/` | App icon glyph as filled SVG (for Icon Composer) plus full-icon previews |
| `wordmark/` | The `guldr` wordmark as outlined vector SVG (dark, light, gold) |
| `fonts/Manrope-SemiBold.ttf` | Wordmark font only (SIL OFL, license in `fonts/OFL.txt`) |

Mockup to feature mapping: `Dashboard` = home, `Transactions` = transaction list, `Budget` = budget, `Charts` = analytics, `AddTransaction` = add sheet, `Lock` = Face ID lock screen, `Widgets` = small and medium widgets, `Main` = brand sheet.

## Principles

1. **Native first.** Use system components (`NavigationStack` large titles, `TabView`, `Picker(.segmented)`, `.sheet`, `List`/`Form` where they fit). The mockups approximate iOS 26 Liquid Glass; the real tab bar, sheets and controls must be the native ones, not hand-drawn copies.
2. **One accent.** Gold is the brand, never a data meaning. Income is `Positive`, not gold.
3. **Two golds.** `Gold` is for text and icons (passes 4.5:1 in both modes). `GoldFill` is for fills only. Never put `GoldFill` text on a light background (2.05:1, fails).
4. **Light and dark are equals.** Every screen must work in both. Never force a color scheme.
5. **Numbers are the product.** All amounts use `.monospacedDigit()`. Large amounts use the serif display face.
6. **Accessibility.** Support Dynamic Type (use `@ScaledMetric` for custom sizes), VoiceOver labels on icon-only buttons, 44 pt minimum touch targets.

## Color

Use the asset catalog names from SwiftUI (`Color("GoldFill")` or the generated symbols, e.g. `Color(.goldFill)`). Hex values for reference:

| Token | Light | Dark | Use |
|---|---|---|---|
| `AppBackground` | `#F7F4EE` | `#111111` | Screen background |
| `Surface` | `#FFFFFF` | `#1B1A18` | Cards, circular buttons |
| `SurfaceSecondary` | `#EFEAE0` | `#242220` | Icon chips, search field, segmented track |
| `TextPrimary` | `#141312` | `#F2EEE6` | Primary text, amounts |
| `TextSecondary` | `#6B665E` | `#9C968C` | Metadata, captions, inactive tabs |
| `Hairline` | `#E3DDD1` | `#2C2A27` | 1 pt card borders and separators |
| `Track` | `#EFEAE0` | `#2C2A27` | Progress bar and ring tracks |
| `Gold` | `#8A6A2E` | `#C8A96A` | Text and icons: active tab, links, highlighted % |
| `GoldFill` | `#C8A96A` | `#C8A96A` | Fills: add button, progress, rings, motif lines |
| `OnGold` | `#111111` | `#111111` | Content on `GoldFill` |
| `GoldSoft` | `#F3EAD7` | `#2E271A` | Selected category chip background |
| `Positive` | `#2F7D5B` | `#5FB38A` | Income amounts and arrows |
| `Negative` | `#B4443C` | `#E07A6E` | Over-budget values, alerts |
| `NegativeSoft` | `#F6E4E0` | `#2B1C1A` | Over-budget alert background |
| `Chart1`–`Chart7` | see `tokens.json` | | Legacy rank ramp; not used for categories (ADR 009), removed in Phase 21 if unused |

### Category palette

Each category has a base color chosen from this palette (ADR 009). Asset names are `Category` + the key (`CategoryTeal`); the model stores the key (`teal`). Twelve hues in color-wheel order plus a neutral, all with the same restrained chroma; every value has at least 3.3:1 contrast against `Surface`.

| Key | Light | Dark | Default categories |
|---|---|---|---|
| `gold` | `#A9872A` | `#BB9A46` | Housing, Salary |
| `amber` | `#B26417` | `#C87E41` | |
| `terracotta` | `#A64832` | `#C2644F` | Food |
| `wine` | `#873046` | `#AB5064` | Entertainment |
| `rose` | `#BA678D` | `#CD80A2` | |
| `plum` | `#794880` | `#97649F` | Shopping |
| `indigo` | `#6F6DB9` | `#8383CD` | Education |
| `blue` | `#295D94` | `#497DB7` | |
| `sky` | `#3A95B9` | `#58AACD` | Transport |
| `teal` | `#017976` | `#349794` | Freelance |
| `green` | `#4A925C` | `#66A774` | Health |
| `olive` | `#65690F` | `#82863A` | Other income |
| `graphite` | `#6F6B65` | `#8F8C85` | Other (also the fallback for unknown keys) |

Category colors appear only in the analytics donut and its legend; icon chips stay neutral. The color picker in Settings shows these thirteen swatches, never a free color picker. Not every pair is distinct (gold/amber/terracotta and teal/graphite are close), so charts never rely on color alone.

Expenses are shown in `TextPrimary` with a leading minus (−$42.80); only income uses `Positive` (+$5,000.00). `Negative` is reserved for "over budget".

Amounts show cents in rows, forms and the balance. Large summary figures (budget ring center, chart totals, donut center, widgets) show whole units, rounded half away from zero ($1,759.50 → $1,760), as in the mockups; `MoneyFormatter`'s `.wholeUnits` precision does this.

Cards: every card has a 1 pt `Hairline` border in both modes. Elevated cards (radius 28 and 24: balance, budget ring, charts) also cast a shadow in light mode only: `0 1 2 rgba(20,19,18,.04)` + `0 10 30 rgba(20,19,18,.06)`, drawn in `TextPrimary` at those opacities. Compact cards (radius 22: income and expense summaries) have no shadow.

## Typography

| Role | Font | Size (pt) | Weight | Notes |
|---|---|---|---|---|
| Balance | New York (`.serif`) | 46 (cents 26 in `TextSecondary`) | Regular | tabular digits |
| Add-sheet amount | New York | 58 | Regular | gold caret |
| Ring / widget amount | New York | 30 / 28 / 26 | Regular | |
| Large title | SF Pro | 34 | Bold | native large title |
| Section title | SF Pro | 20 | Bold | "Recent" |
| Summary value | SF Pro | 19 | Semibold | tabular |
| Row title / amount | SF Pro | 16 | Semibold | amount tabular |
| Card title | SF Pro | 15 | Semibold | |
| Meta / caption | SF Pro | 13 | Regular | `TextSecondary` |
| Overline | SF Pro | 12 | Semibold | uppercase, +0.1 em tracking |
| Tab label | SF Pro | 10 | Semibold | native tab bar |
| Wordmark | Manrope SemiBold | 26 (header) · 40 (lock) | 600 | lowercase, −0.04 em (header), −0.045 em (large) |

Prefer semantic text styles with `design: .serif` / default and `@ScaledMetric` so sizes follow Dynamic Type. The wordmark can be the SVG in `wordmark/` or `Text("guldr").font(.custom("Manrope-SemiBold", size: 26)).tracking(-1.04)`; Manrope is used **only** for the wordmark.

## Brand motif: ledger lines

1 pt horizontal lines in `GoldFill`, as wide as their container. Never as a full-screen texture.

| Variant | Where | Lines | Gap | Widths | Opacity |
|---|---|---|---|---|---|
| Leading | Under the balance | 3, left-aligned | 5 pt | 100 / 78 / 56 % | 1.0 / 0.5 / 0.25 |
| Centered | Above the Face ID button | 3, centered | 5 pt | 100 / 70 / 40 % | 0.6 / 0.35 / 0.18 |
| Compact | Small widget, under the balance | 2, left-aligned | 3 pt | 100 / 70 % | 1.0 / 0.45 |

On the Dashboard the lines draw in once per launch (DESIGN.md › Motion); everywhere else they are static.

## Shape and spacing

- Radii (pt): balance and ring cards 28 · generic card 24 · compact card 22 · alert 18 · field group 16 · category chip and keypad key 14 · icon chip 12–13 · segmented 12 (thumb 9) · progress bar 3 · buttons are capsules.
- Screen padding 20 pt horizontal; vertical stack spacing 16 pt (home) / 10–12 pt (lists); card padding 22 pt (18 compact); row vertical padding 8 pt, row gap 12 pt.
- Icon chip 42×42 (40 in lists, 38 in budget) with a 20 pt stroke icon (1.6 pt line). Use SF Symbols in code; the mockup icons are stand-ins for their closest SF Symbol.

## Motion

Implemented in `Guldr/Core/DesignSystem/Motion.swift`; every animation and haptic in the app goes through it.

### Principles

1. **Motion explains a change of state.** Something was saved, a value updated, a limit was crossed. It is never decoration and never loops.
2. **Native springs only.** SwiftUI's `.smooth`, `.snappy` and `.spring` curves; no custom easing or keyframe choreography.
3. **Short and calm,** like the voice. Nothing longer than 0.6 s; nothing that bounces more than a hint.
4. **The system's transitions stay the system's.** Sheets, navigation pushes, tab switches and the keyboard are never replaced or restyled.

### Tokens

| Token | SwiftUI | Use |
|---|---|---|
| `standard` | `.smooth(duration: 0.35)` | Layout and value changes: a row appears, a total updates, a filter applies |
| `snappy` | `.snappy(duration: 0.25)` | Direct manipulation: category chips, keypad keys, segmented controls, toggles |
| `emphasized` | `.spring(duration: 0.45, bounce: 0.15)` | Success moments only: a transaction saved, a budget created |
| `reveal` | `.smooth(duration: 0.6)` | First appearance of fills: progress bars, rings, the ledger lines drawing in |
| `stagger` | 0.04 s per item, 0.25 s total at most | Entrance of list rows and chart marks; items past the cap appear together |

### Patterns

| Element | Behavior | Token |
|---|---|---|
| Amounts (balance, totals, ring center) | `.contentTransition(.numericText(value:))`: digits roll to the new value | `standard` |
| Progress bars, mini rings, budget ring | Fill from 0 on first appearance; later changes animate from the current value | `reveal`, then `standard` |
| Ledger lines | Draw in left to right, once per launch on the Dashboard; static elsewhere | `reveal` + `stagger` |
| Charts | Marks grow on first appearance and morph on period change | `standard` + `stagger` |
| Category chip | Selection fill and border | `snappy` |
| Save | The saved row appears in place; the checkmark bounces (`.symbolEffect(.bounce)`) | `emphasized` |
| Over-budget alert | Slides in with the list; its warning symbol pulses once (`.symbolEffect(.pulse)`) | `standard` |
| Sheets, navigation, tabs | Native transitions, untouched | — |

### Haptics

Through `.sensoryFeedback`, tied to the state change, never to a timer.

| Event | Feedback |
|---|---|
| Category chip or segmented control changes | `.selection` |
| Keypad key | `.impact(weight: .light)` |
| Transaction or budget saved | `.success` |
| A save pushes a budget over its limit | `.warning` |
| Face ID unlock fails | `.error` |

### Reduce Motion

When `accessibilityReduceMotion` is on:

| Element | Behavior |
|---|---|
| Fills (bars, rings, ledger lines) | Appear at their final value, no fill animation |
| Layout and list changes | Opacity cross-fade (`.easeInOut(duration: 0.2)`) instead of movement |
| Stagger | Off: everything appears together |
| Chart marks | Appear at their final value |
| Symbol effects | Off (the pulse and the bounce) |
| Numeric text transitions | Kept: they do not move content around the screen |
| Haptics | Kept |

## Components

- **BalanceCard**: `Surface`, radius 28, border `Hairline`, padding 22. Label, serif balance, ledger lines, 2-column income/expense with arrow icons (`Positive`/`Negative`), divider, savings rate (13 pt label, % in `Gold`, 6 pt bar `GoldFill` on `Track`).
- **BudgetSummaryRow**: 44 pt mini ring (stroke 5, `GoldFill` on `Track`, round caps), title 15 semibold, meta 13, chevron.
- **TransactionRow**: icon chip + title/meta + trailing amount. Income amount `Positive` with "+", expense `TextPrimary` with "−".
- **BudgetRing**: 168 pt, stroke 12, starts at 12 o'clock, center shows remaining in serif 30 + "available".
- **CategoryBudgetRow**: icon chip 38, name 15 semibold, "spent of limit" 13 (spent semibold), 5 pt bar; over budget turns bar and spent value `Negative`.
- **OverBudgetAlert**: `NegativeSoft` background, radius 18, warning icon in `Negative`, text `TextPrimary`.
- **AddButton**: 64 pt circle, `GoldFill`, plus icon `OnGold`. In the app, place it next to the native tab bar per iOS 26 conventions.
- **CategoryChip** (add sheet): 62 pt tall, radius 14; selected = `GoldSoft` fill + 1.5 pt `GoldFill` border + `Gold` content.
- **Charts** (Swift Charts): income bars `GoldFill`, expense bars `TextSecondary`-toned (`#6B665E` light / `#6E6962` dark); category donut sorts categories by amount; each slice is a subtle gradient from its category's base color to that color mixed 12% with `Surface`; slices are separated by a 2 pt gap, the legend names every slice, and large slices carry a direct label.
- **Primary button**: capsule, 54 pt tall, `GoldFill` with `OnGold` 17 pt semibold text.

## App icon

Glyph: a "G" that is also a clipped coin. Built on a 1024 grid: ring center (512, 512), outer radius 292, inner 208, opening at the top right, bar from x 548 to 804 at y 470–554. Files in `icon/`:

- `guldr-glyph-gold.svg` (`#C8A96A`) — default and dark appearance glyph
- `guldr-glyph-gold-deep.svg` (`#8A6A2E`) — glyph for a light-background variant
- `guldr-glyph-white.svg` — for mono/tinted appearances
- `preview-*.svg` / `preview-default-1024.png` — full icons as designed (reference only; Icon Composer adds the mask and glass)

Backgrounds: default `#111111`, light variant `#FFFFFF`, tinted variant `#2A2826` with `#D9D4CB` glyph.

## Voice

Short, second person, calm. "Your month, made clear." · "Your finances, just for you." Subtle gold references ("Your reserve") without overdoing it. No hype, no investing jargon. Spanish copy keeps the same tone in the String Catalog.
