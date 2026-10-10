# 009 — Category colors from a curated palette

- **Status:** Accepted
- **Date:** 2026-10-09

## Context

[ADR 008](008-categories-and-month-keys.md) gave every category a stored `colorToken`, one of `Chart1`…`Chart7`, so that a category would keep the same color in the donut and in its list icon.

Building the models showed that this does not work with those tokens:

- In `tokens.json` and [DESIGN.md](../design/DESIGN.md), `Chart1`…`Chart7` are a tonal ramp meant to be assigned by rank (largest category first). They run from dark to light gold and then dark to light gray: seven shades, not seven distinguishable colors. Two categories with neighboring tokens look almost the same.
- No mockup colors a category icon. Icon chips are `SurfaceSecondary` with the icon in `TextPrimary`.

The author wants users to choose a color for each category, and the donut to show it.

## Decision

**Each category stores a base color picked from a curated palette of thirteen colors. The analytics donut draws each slice with a subtle gradient of its category's base color.**

- **Palette:** twelve hues in order around the color wheel — `gold`, `amber`, `terracotta`, `wine`, `rose`, `plum`, `indigo`, `blue`, `sky`, `teal`, `green`, `olive` — plus the neutral `graphite`. Each is a `Category…` color in `GuldrColors` with light and dark variants (values in DESIGN.md and `tokens.json`). All share one restrained chroma so they read as one family next to the gold identity; lightness alternates between neighboring hues to keep them apart, and each dark variant is the same hue slightly lighter. Every variant has at least 3.3:1 contrast against `Surface`, above the 3:1 WCAG minimum for graphics.
- **Model:** `Category.colorKey: String` stores the case name, exposed as `CategoryColor`. An unknown key, written by a newer version, falls back to `graphite`.
- **Defaults:** the seeded categories get fixed colors. The eight expense defaults use the eight palette colors that are furthest apart from each other (every combination was checked, in both modes and under simulated color blindness): `gold`, `terracotta`, `wine`, `plum`, `indigo`, `sky`, `green`, `graphite`.
- **Picker:** creating or editing a category in Settings shows the thirteen colors as a grid, in palette order. No free color picker.
- **Gradient:** each donut slice goes from its base color to the base color mixed 12% with `Surface`. The effect is a soft sheen, not a change of color. Because the mix uses the card's own background, it works in light and dark mode without a second color per category.
- **Where colors appear:** only in the donut and its legend. Icon chips stay neutral, as in the mockups.
- **Telling slices apart:** thirteen colors cannot all be distinct from each other, especially for color-blind users (the closest pairs are gold/amber/terracotta and teal/graphite), and categories may share a color. The donut therefore never relies on color alone: slices are separated by a 2 pt gap, the legend always names every slice, and large slices carry a direct label.

This supersedes the **Appearance** bullet of ADR 008. Everything else in ADR 008 stands: kinds, the default set, stable `systemKey`s, archiving and month keys.

## Alternatives considered

- **`Chart1`…`Chart7` stored per category (ADR 008 as written)** — the tokens are shades of two hues, so categories are hard to tell apart, and the donut loses the ordered ramp it was designed for.
- **No stored color; color by chart rank** — matches the original mockup and needs no field, but the user cannot recognize a category by its color, and the same category changes color from month to month.
- **Free `ColorPicker`** — unlimited choice, but no contrast guarantee (a pale yellow disappears on white), a dark variant has to be guessed, and it breaks the rule that colors come from `GuldrColors`.

## Consequences

- Users recognize categories by color across months, and the donut keeps a consistent, on-brand look in both modes.
- The design system gains thirteen color tokens. `Chart1`…`Chart7` lose their purpose and are removed in Phase 21 if no other chart uses them.
- Adding a color later means a new asset and a new enum case; old app versions show `graphite` for it.
- The gradient rule lives in one place (the donut component) and is documented in DESIGN.md.
