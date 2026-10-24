# App Store metadata

What goes into App Store Connect for Guldr 1.0, in English (U.S.), the primary language, and in Spanish. The same Spanish text goes in both **Spanish (Mexico)** and **Spanish (Spain)** (author's call, 2026-10-23); it uses the app's own words ("monto", "anotar", "Movimientos") and avoids regional ones such as "celular" or "móvil".

Each field shows its limit and the current length. App Store Connect counts characters, not bytes. Text blocks are plain text: the App Store doesn't render Markdown, so lists use "•".

## App record

| Field | Value |
|---|---|
| Name | Guldr |
| Bundle ID | `com.argudev.guldr` |
| SKU | `guldr-ios` |
| Apple ID | `6826453592` |
| App Store URL | https://apps.apple.com/app/id6826453592 |
| Primary language | English (U.S.) |
| Category | Finance, no secondary category |
| Age rating | 4+ |
| Price | Free, no in-app purchases |
| Availability | Every country and region except China mainland; not on Mac or Apple Vision Pro |
| App Privacy | Data Not Collected |

These were set in steps 34.1 to 34.4 of the [v1.0 plan](../plan/v1.0.md).

## URLs

The same in every language.

| Field | URL |
|---|---|
| Support URL (required) | https://mauroargudev.github.io/Guldr/support/ |
| Marketing URL | https://mauroargudev.github.io/Guldr/ |
| Privacy Policy URL | https://mauroargudev.github.io/Guldr/privacy/ |

## Name and subtitle

The name and subtitle are indexed for search together with the keywords, so no word appears twice across them.

Store names are unique per localization, and another app already uses "Guldr" in Spanish (Mexico). Both Spanish localizations therefore use "Guldr: Finanzas personales" (author's call, 2026-10-23). The name under the icon on the Home Screen stays Guldr in every language.

| | English | Spanish |
|---|---|---|
| Name (30) | Guldr (5) | Guldr: Finanzas personales (26) |
| Subtitle (30) | Private budget & expenses (25) | Gastos y presupuesto privados (29) |

## Promotional text (170)

Shown above the description and editable at any time without a new version.

**English** (156)

```text
Log a day's spending in seconds, keep your streak going and see where your money goes. Everything stays on your iPhone: no account, no servers, no tracking.
```

**Spanish** (143)

```text
Anota tus gastos en segundos, mantén tu racha y mira a dónde va tu dinero. Todo se queda en tu iPhone: sin cuenta, sin servidores, sin rastreo.
```

## Keywords (100)

Comma-separated with no spaces after the commas. They leave out the name, the subtitle's words and the category, which are indexed already.

**English** (100)

```text
money,spending,tracker,finance,income,savings,habit,streak,offline,no account,widget,csv,ledger,cash
```

**Spanish** (100)

```text
dinero,billetera,ahorro,ingresos,control,racha,hábito,sin cuenta,offline,widget,csv,cuentas,registro
```

## Description (4000)

**English**

```text
Guldr is a personal finance app that keeps everything on your iPhone. There's no account to create and no server behind it: what you enter never leaves your device unless you share it.

LOG IN SECONDS
• A keypad-first add sheet: amount, category, done.
• Income and expenses with your own categories, a description and a date.
• Every transaction keeps the currency it was saved in.

SEE WHERE YOUR MONEY GOES
• Home shows your balance and this month's income, expenses and savings rate.
• Monthly budgets per category, with alerts at 80% and 100%.
• Analytics compares income and expenses over 1, 3, 6 or 12 months and breaks spending down by category.
• A searchable list of transactions, grouped by day.

MAKE IT A HABIT
• An optional daily reminder, skipped on days you've already logged.
• A logging streak you can still repair the next day, with freezes for the days you miss.
• Bronze, silver and gold achievements for consistency, budgets kept and money saved.
• Share cards for your achievements and your month that never show an amount.

PRIVATE BY DESIGN
• No account, no analytics, no ads, no tracking.
• An optional Face ID lock.
• Hide amounts in widgets. With the lock on, budget alerts leave amounts out too.

AND ALSO
• Small and medium Home Screen widgets.
• CSV export for any spreadsheet.
• English and Spanish, VoiceOver, Dynamic Type and Reduce Motion throughout.

Your gold, in order.
```

**Spanish**

```text
Guldr es una app de finanzas personales que guarda todo en tu iPhone. No hay cuenta que crear ni servidores detrás: lo que anotas nunca sale de tu dispositivo, a menos que tú lo compartas.

ANOTA EN SEGUNDOS
• Agregar empieza por el teclado: monto, categoría y listo.
• Ingresos y gastos con tus propias categorías, una descripción y una fecha.
• Cada movimiento guarda la moneda en la que lo anotaste.

MIRA A DÓNDE VA TU DINERO
• Inicio muestra tu saldo y los ingresos, gastos y tasa de ahorro del mes.
• Presupuestos mensuales por categoría, con alertas al 80 % y al 100 %.
• Análisis compara ingresos y gastos en 1, 3, 6 o 12 meses y desglosa tus gastos por categoría.
• Una lista de movimientos agrupada por día, con búsqueda.

HAZLO UN HÁBITO
• Un recordatorio diario opcional, que no llega los días que ya anotaste.
• Una racha que todavía puedes reparar al día siguiente, con protectores para los días que se te pasan.
• Logros de bronce, plata y oro por constancia, presupuestos cumplidos y dinero ahorrado.
• Tarjetas para compartir tus logros y tu mes, que nunca muestran un monto.

PRIVADA DESDE EL DISEÑO
• Sin cuenta, sin analíticas, sin anuncios, sin rastreo.
• Bloqueo opcional con Face ID.
• Oculta los montos en los widgets. Con el bloqueo activo, las alertas de presupuesto tampoco los muestran.

Y ADEMÁS
• Widgets pequeño y mediano para la pantalla de inicio.
• Exportación CSV para cualquier hoja de cálculo.
• Inglés y español, VoiceOver, texto dinámico y reducción de movimiento en toda la app.

Tu oro, en orden.
```

## What's New (4000)

App Store Connect doesn't show this field for a first version. From 1.0.1 on, each version's text comes from its section in [CHANGELOG.md](../../CHANGELOG.md), shortened to what a user notices.

## Copyright

```text
2026 Mauricio Argumedo
```

## App Review information

- **Sign-in required:** off. Guldr has no account.
- **Contact:** the author's name, phone number and email, filled in App Store Connect only (they aren't kept in the repo).
- **Notes** (4000), in English:

```text
Guldr needs no account or sign-in, and every feature is available right away. All data is stored on the device with SwiftData; the app makes no network requests of its own and contains no third-party SDKs. There are no in-app purchases.

To try it:
1. Tap the + tab to add an expense or income with the keypad. Home updates its balance and the month's totals.
2. Budget tab: set a monthly limit per category. Alerts at 80% and 100% are optional local notifications.
3. Analytics tab: charts appear once there are transactions.
4. The streak on Home opens a calendar and the achievements. Achievements and the monthly recap can be shared as images that never show an amount.
5. Settings (the button at the top right of Home): the optional Face ID lock and the option to hide amounts in widgets are under Security; the optional daily reminder is under Notifications; Export transactions creates a CSV file.

Widgets: add the Guldr widget from the Home Screen in the small or medium size.
```

## Screenshots

The plan is in [screenshots.md](screenshots.md) (step 34.6).
