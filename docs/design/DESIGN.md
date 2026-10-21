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
| `Field` | `#FFFFFF` | `#242220` | Unselected category chips and the add sheet's field group |
| `FieldAccent` | `#EFEAE0` | `#35322E` | Date chip and separators inside the add sheet's field group (`SurfaceSecondary` would vanish on `Field` in dark) |
| `SheetBackground` | `#F7F4EE` | `#1B1A18` | Add sheet background (lifted from the dimmed screen in dark) |
| `KeypadKey` | `#FFFFFF` | `#2A2826` | Add sheet keypad keys (a step lighter than category chips in dark) |
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
| `ChartExpense` | `#6B665E` | `#6E6962` | Expense bars in the income vs. expenses chart (added by the author on 2026-10-20) |

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

- Radii (pt): balance and ring cards 28 · generic card 24 · compact card 22 · alert 18 · field group 16 · category chip and keypad key 14 · icon chip 12–13 · segmented 12 (thumb 9) · date chip 8 · progress bar 3 · buttons are capsules.
- Screen padding 20 pt horizontal; vertical stack spacing 16 pt (home) / 10–12 pt (lists); card padding 22 pt (18 compact; the budget summary row 16 × 18); row vertical padding 8 pt, row gap 12 pt.
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

- **BalanceCard**: `Surface`, radius 28, border `Hairline`, padding 22. Label, serif balance, ledger lines, 2-column income/expense with arrow icons (`Positive`/`Negative`), divider, savings rate (13 pt label, % in `Gold`, 6 pt bar `GoldFill` on `Track`). The balance is the all-time net; income, expenses and the savings rate cover the current month. A month without income shows the rate as "—" in `TextSecondary` with an empty bar; a month that spent more than it earned shows 0% (decided by the author on 2026-10-16). The card shows from the first launch, at zero.
- **BudgetSummaryRow**: 44 pt mini ring (stroke 5, `GoldFill` on `Track`, round caps; `Negative` when the month's total is over), title 15 semibold, meta 13, chevron. At accessibility text sizes the ring and chevron sit above the text.
- **TransactionRow**: icon chip + title/meta + trailing amount. Income amount `Positive` with "+", expense `TextPrimary` with "−". At accessibility text sizes the amount moves under the meta and the text wraps instead of truncating.
- **BudgetRing**: 168 pt, stroke 12, starts at 12 o'clock, center shows remaining in serif 30 + "available".
- **CategoryBudgetRow**: icon chip 38, name 15 semibold, "spent of limit" 13 (spent semibold), 5 pt bar; over budget turns bar and spent value `Negative`.
- **OverBudgetAlert**: `NegativeSoft` background, radius 18, warning icon in `Negative`, text `TextPrimary`.
- **AddButton**: in the mockups, a 64 pt `GoldFill` circle with an `OnGold` plus. In the app it is the native separated tab next to the tab bar (a `Tab` with the `.prominent` role on iOS 27, `.search` on iOS 26, the roles each version draws apart from the bar): Liquid Glass with a `Gold` plus, sized and minimized by the system. Selecting it opens the add sheet without switching tabs. Decided by the author on 2026-10-10 (native first over a hand-drawn copy).
- **CategoryChip** (add sheet): 62 pt tall, radius 14; selected = `GoldSoft` fill + 1.5 pt `GoldFill` border + `Gold` content.
- **Add sheet**: `SheetBackground`, native sheet and toolbar (Cancel, title, Save in `Gold`), sections 12 pt apart. Native segmented Expense/Income; 58 pt serif amount in a 72 pt row with a 2 × 48 pt `GoldFill` caret that blinks like the system cursor (0.5 s on, 0.5 s off, solid again after each key, hidden while the description is being typed; it keeps blinking with Reduce Motion, as the system cursor does); field group (`Field`, radius 16) of 46 pt rows with 14 pt padding, `FieldAccent` separator, and a date chip (`FieldAccent`, radius 8, 15 pt) that opens a graphical date picker; 4-column category grid with 8 pt gaps; keypad of 3 × 4 keys, 50 pt tall (never below 44), radius 14, `KeypadKey`, 24 pt regular digits, 8 pt gaps, pinned to the bottom while the rest scrolls. At accessibility text sizes the field rows stack label over value and the category grid uses two columns.
- **Dashboard**: no large title; the first row of the scrolling content is the wordmark (26 pt) over the current month (13 pt, `TextSecondary`), and Settings is a native toolbar button (`slider.horizontal.3`) (decided by the author on 2026-10-16). Below, 16 pt apart: the BalanceCard (income and expenses stack at accessibility sizes), the month's BudgetSummaryRow in a compact card (16 × 18 padding; hidden without budgets; tapping it opens Budget), and "Recent" (`sectionTitle`) with "See all" in `Gold` (under the title at accessibility sizes) over the five newest `TransactionRow`s ("Food · Today"), which open the edit sheet. Without transactions, "Your month starts here" with Add replaces Recent. The ledger lines draw in and the recent rows rise in (`stagger`) once per launch.
- **Budget**: native large title with Edit as a native toolbar button in `Gold`; the first row of the content is the month (15 semibold, centered) between previous and next chevrons in `TextSecondary` (44 pt targets). Back has no limit; next stops at next month and fades to 40 % (decided by the author on 2026-10-20). Below, 10 pt apart: the overview card (`.hero`, the BudgetRing beside "Spent" and "Total limit" in the summary style and "71% used · 2 days left" in `Gold`, `Negative` once the month's total is over; a past month shows only the percentage; the figures go under the ring at accessibility sizes), one OverBudgetAlert per category over its limit, then a CategoryBudgetRow per budgeted category, highest usage first, straight on the background. A month without budgets shows the empty state: "Copy last month's budgets" as the primary action (copies and saves at once) with "Set budgets" as a secondary `Gold` text button when last month has budgets, otherwise only "Set budgets".
- **Edit budgets sheet**: native `Form` titled "Budgets" with the month as subtitle; Cancel and Save in `Gold`. "Copy last month's budgets" on top when last month has any, then one row per expense category (symbol in `TextSecondary`, name, and a trailing amount field with the system decimal keyboard, placeholder "No limit"; an invalid amount turns `Negative`), a swipe to remove, and a Total row. An empty field means no budget (decided by the author on 2026-10-20).
- **Transactions list**: native plain `List` on `AppBackground` with no separators; rows are compact `TransactionRow`s (40 pt chip) inset 20 pt. Day sections pin their header (13 pt, `TextSecondary`: the day semibold, the net medium with tabular digits, "+" when positive) on an `AppBackground` strip; the net counts only the active currency. Native search under the large title, revealed by pulling the list down (decided by the author on 2026-10-15: always showing it collapsed the large title on iOS 27); native segmented All/Income/Expenses pinned under it once there is a transaction. Category filter: a native toolbar `Menu` of toggles with "Clear filter", its button `Gold` while a filter is set. Tap a row to edit; trailing swipe (full swipe allowed) in `Negative` asks for a native confirmation first. Empty states: "No transactions yet" with Add, the system search empty state, and "No matching transactions" for filters. At accessibility text sizes the header stacks the net under the day.
- **Analytics**: native large title; the first row is the native segmented period picker (1M · 3M · 6M · 1Y; 6M the first time, then the last one chosen, decided by the author on 2026-10-20). Below, 16 pt apart: the period's Income, Expenses and Saved (12 pt captions over 16 pt semibold values in whole units; Saved in `Gold`, or with a minus sign in `Negative` when the period spent more than it earned; stacked at accessibility sizes), the "Income vs. expenses" card (`.standard`, 18 pt padding, legend beside the title or under it when it doesn't fit; month bars, weekly for 1M and one-letter months for 1Y; the current bucket's label semibold in `TextPrimary`) and the category donut card (136 pt donut beside the legend, under it at accessibility sizes). Touching or dragging over the bars selects one: the others dim to 40 % and a callout on `SurfaceSecondary` shows its period, income and expenses. Every figure covers the period ending with the current month, the donut included. An empty period says "Nothing in this period" and, below 1Y, offers "Show the last year"; a new user sees "Nothing to chart yet" with Add.
- **Settings**: native `Form` pushed from Home's toolbar, inline title. Currency (opens the welcome screen's searchable currency list; footer "Totals, budgets and charts use this currency. Transactions keep the currency they were saved in."), Categories, About, then "Delete all data" in the destructive role. Rows for Face ID, notifications, widget privacy and export appear only with their phases, so Settings never shows a control that does nothing (decided by the author on 2026-10-20). "Delete all data" asks twice: a confirmation dialog that says what goes, then an alert that it can't be undone ("Delete everything").
- **Categories**: native inset list. A native segmented Expenses/Income control first, then the kind's categories (compact `IconChip`, name) in the add sheet's order: tap to edit, touch and hold to drag, swipe left to archive (`TextSecondary` tint; not offered for a kind's last active category). An "Archived" section follows when there are any, restored with a swipe in `Gold`. + in the toolbar, in `Gold`, creates a category of the selected kind (decided by the author on 2026-10-20).
- **Category sheet**: native `Form`, "New category" or "Edit category"; Cancel and Save in `Gold`. Name (a name another category of the kind has turns the footer `Negative`), a grid of 48 curated SF Symbols in 44 pt cells with the CategoryChip's selection style, and the 13 palette swatches (30 pt in 44 pt targets, the selected one ringed in its own color, VoiceOver reads the color's name). "Delete category" appears only for a custom category no transaction uses, after a confirmation; footers say why defaults and categories in use can't be deleted.
- **About**: native `Form`. The wordmark over the version ("1.0.0 (1)"), "Contact support" (Mail, prefilled with the app and iOS versions), and Acknowledgements: Manrope under the SIL Open Font License 1.1, with its full text. The privacy policy row joins once the page is published (step 29.7; decided by the author on 2026-10-21).
- **Charts** (Swift Charts): income bars `GoldFill`, expense bars `ChartExpense` (`#6B665E` light / `#6E6962` dark); category donut sorts categories by amount; each slice is a subtle gradient from its category's base color to that color mixed 12% with `Surface`; slices are separated by a 2 pt gap and the legend names every slice with its share. The 18 pt ring is too thin for labels on the slices, so touching a slice or its legend row selects it instead: the center shows its name, amount and share and the other slices dim (decided by the author on 2026-10-20).
- **Primary button**: capsule, 54 pt tall, `GoldFill` with `OnGold` 17 pt semibold text.

## App icon

Glyph: a "G" that is also a clipped coin. Built on a 1024 grid: ring center (512, 512), outer radius 292, inner 208, opening at the top right, bar from x 548 to 804 at y 470–554. Files in `icon/`:

- `guldr-glyph-gold.svg` (`#C8A96A`) — default and dark appearance glyph
- `guldr-glyph-gold-deep.svg` (`#8A6A2E`) — glyph for a light-background variant
- `guldr-glyph-white.svg` — for mono/tinted appearances
- `preview-*.svg` / `preview-default-1024.png` — full icons as designed (reference only; Icon Composer adds the mask and glass)

Backgrounds: default `#111111`, light variant `#FFFFFF`, tinted variant `#2A2826` with `#D9D4CB` glyph.

### Launch screen

`AppBackground` with the glyph centered at 80 pt: `#8A6A2E` in light, `#C8A96A` in dark (decided by the author on 2026-10-20). The app opens from its icon onto the same glyph instead of a blank system screen. Static, as iOS requires: no text, no animation, no splash delay. The `LaunchGlyph` image set crops the glyph's 1024 grid to its ring (`viewBox` 220 220 584 584) at 80 × 80 pt, since the launch screen draws an image at its natural size. Set in the target's Info › Launch Screen (Background color `AppBackground`, Image name `LaunchGlyph`).

## Voice

Short, second person, calm. "Your month, made clear." · "Your finances, just for you." Subtle gold references ("Your reserve") without overdoing it. No hype, no investing jargon. Spanish copy keeps the same tone in the String Catalog.
