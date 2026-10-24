# App Store screenshots

The screenshot plan for Guldr 1.0 (v1 plan, 34.6). Decisions by the author, 2026-10-23:

- **Captioned:** a short headline above each capture.
- **Mixed appearance:** mostly light, with dark for Analytics, the widgets and the share card. The store shows one set per language whatever the viewer's mode, so the set itself shows that Guldr has both.
- **Localized data:** three sets with data that reads naturally in each storefront.
- **Eight screens.**

## Requirements

- **Size:** 6.9-inch iPhone, portrait, **1320 × 2868** px, PNG without transparency. App Store Connect scales this set down for the smaller iPhones, so no other size is needed.
- **Count:** eight per localization, of the ten allowed. The first three show in search results, so they carry the main promise: the month at a glance, quick logging and where the money goes. The order is the author's: the plan's six screens, then the streak and the share card.
- **Content:** real app screens with demo data only. No device frames are needed, and nothing refers to other platforms or to prices.

## Sets

| Localization in App Store Connect | Simulator language and region | Data (`-demoData`) |
|---|---|---|
| English (U.S.) | English, United States | English titles, USD |
| Spanish (Mexico) | Spanish, Mexico | Mexican Spanish titles, MXN at ten times the amounts (rent $8,500) |
| Spanish (Spain) | Spanish, Spain | Spain's Spanish titles (alquiler, nómina), EUR |

`-demoData` picks the titles and the currency from the device's locale (`PreviewData.Flavor`). The language is set for the whole simulator, not only the app, so the widgets and the share sheet follow it too.

## Shots

Captions are New York, like the app's brand moments, and use the same Spanish text in both Spanish sets. Each stays within two lines.

| # | Screen | Mode | State | Caption (English) | Caption (Spanish) |
|---|---|---|---|---|---|
| 1 | Home | Light | Top of Home: balance, the month, budget, recent rows | Your month at a glance | Tu mes de un vistazo |
| 2 | Add sheet | Light | An amount typed (12.50 / 125.00 / 12,50) with Food selected | Log it in seconds | Anótalo en segundos |
| 3 | Analytics | Dark | 6 months, cash flow and the category donut | See where it goes | Mira a dónde se va |
| 4 | Budget | Light | The ring and the categories, one over its limit | Budgets that keep you honest | Presupuestos que te avisan |
| 5 | Transactions | Light | The list grouped by day, top of the list | Every transaction, by day | Cada movimiento, por día |
| 6 | Home Screen | Dark | The small and medium widgets with Guldr's data | Private, right on your Home Screen | Privado, en tu pantalla de inicio |
| 7 | Streak sheet | Light | The 16-day streak, the calendar and the freeze | Make it a habit | Hazlo un hábito |
| 8 | Share card | Dark | An earned achievement's card, Story format | Share wins, never amounts | Comparte logros, nunca montos |

## Composition

`scripts/compose-store-screenshot.swift` turns each raw capture into the final image. Its colors are read from `docs/design/tokens.json`, so nothing is hard-coded:

- **Canvas:** 1320 × 2868, filled with `AppBackground` in the shot's mode.
- **Caption:**
  - New York regular, 96 px, in `TextPrimary`;
  - centered in the top 560 px, with 96 px side margins.
- **Capture:**
  - scaled to 1007 × 2188 and centered, 560 px from the top and 120 px from the bottom;
  - corners use `phoneCard` (28 pt) at 3×, which is 84 px;
  - a 3 px `Hairline` border.

```sh
scripts/compose-store-screenshot.swift raw/02-home.png out/02-home.png light "Your month at a glance"
```

The images aren't committed; they're regenerated from the demo data whenever the screens change. They go to `build/app-store-screenshots/<localization>/`, which is ignored by git.

## Capture

The **iPhone 17 Pro Max** simulator, with the Debug build installed from Xcode. For each set:

1. **Language and region:** set them for the whole simulator, then reboot it.
   ```sh
   xcrun simctl spawn <device> defaults write -g AppleLanguages -array es-MX
   xcrun simctl spawn <device> defaults write -g AppleLocale es_MX
   xcrun simctl shutdown <device> && xcrun simctl boot <device>
   ```
2. **Status bar:** `xcrun simctl status_bar <device> override --time 9:41 --batteryState discharging --batteryLevel 100 --wifiBars 3 --cellularBars 4 --operatorName ""`
3. **Empty store:** Settings › Delete all data if a previous set is there. Deleting the app isn't enough, since the App Group container survives it on the simulator.
4. **Demo data:** `xcrun simctl launch --terminate-running-process <device> com.argudev.guldr -demoData`
5. **Each shot:**
   - `xcrun simctl ui <device> appearance light|dark`;
   - navigate to the screen;
   - `xcrun simctl io <device> screenshot raw/NN-name.png`.
6. **Compose** the eight images with the script.

The data ends on the day of the capture, so the screens show the current month.
