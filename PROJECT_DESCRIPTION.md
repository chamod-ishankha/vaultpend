# VaultSpend — Project Description & Asset Creation Prompts

---

## 📄 Full Project Description

### VaultSpend — Personal Finance Tracker for Android & iOS

**VaultSpend** is a mobile-first personal finance app built with Flutter that helps individuals track expenses and subscriptions with speed and clarity. It works offline by default and optionally syncs to the cloud when signed in — giving users full control of their financial data without requiring an internet connection.

The app is designed for people who want a lightweight, no-fuss way to stay on top of their recurring costs, understand their spending patterns, and never miss a subscription renewal or trial expiration.

---

### Core Capabilities

- **Expense Tracking** — Log one-time and recurring expenses with category, amount, currency, and date. Filter and sort by date range or category. Export to CSV or PDF.
- **Subscription Management** — Track all active subscriptions with billing frequency, next billing date, and trial status. Get reminders before renewals. Mark trials as converted or cancelled.
- **Category Customization** — Create personal expense and subscription categories with custom icons (30+ options) and color labels.
- **Analytics & Insights** — View spending trends over 7, 30, 90 days, or all-time. See category breakdowns, month-over-month comparisons, largest subscriptions, and upcoming trial expirations.
- **Smart Reminders** — Scheduled local notifications for upcoming subscription renewals and recurring expenses, with full diagnostic tools to verify what's scheduled.
- **Multi-Currency Support** — Log expenses in any currency with automatic FX conversion to a preferred base currency.
- **Cloud Sync** — Sign in with email to sync all data across devices via Firebase. Guest mode available for local-only use.
- **Export** — Share expenses, subscriptions, and insights as CSV or PDF via the native share sheet.
- **Activity Log** — Full audit trail of user actions (creates, edits, deletes, sync events) with timestamps.

---

### Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter (Dart) |
| State Management | Riverpod |
| Local Database | Isar (embedded, offline-first) |
| Cloud Backend | Firebase Auth + Cloud Firestore |
| Notifications | flutter_local_notifications |
| Exports | CSV + PDF generation |
| OCR | Google ML Kit (receipt scanning) |
| Platforms | Android + iOS |

---

### Design

VaultSpend uses Google's **Material 3** design system with a dark-mode-first interface. The primary brand color is **teal (#0D9488)** — conveying trust, clarity, and focus. The UI is clean and minimal, with a 5-tab bottom navigation shell, bottom-sheet pickers, swipe-to-delete list actions, and clear empty states.

---

### Target Audience

Individuals who want a private, fast, offline-capable finance tracker — especially those managing multiple subscriptions, multi-currency spending, or who want more transparency without the complexity of full budgeting apps.

---

### Status

Production-ready. Version 1.5.22. Available for Android and iOS.

---

---

## 🎨 Asset Creation Prompts

Use the prompts below with AI image generators (Midjourney, DALL·E, Adobe Firefly, Stable Diffusion, etc.) or pass them to a designer.

---

### 1. App Icon

> A modern, minimal app icon for a personal finance app called "VaultSpend". The design features a stylized vault or shield symbol combined with a subtle upward arrow or coin motif. Color palette: deep teal (#0D9488) as the primary color on a near-black background (#121218). Flat vector style, no gradients, no shadows. Clean geometric shapes. Suitable for Android and iOS app stores. 1024×1024px.

---

### 2. Primary Logo (Horizontal)

> A horizontal logotype for "VaultSpend" — a personal finance mobile app. The logo includes a compact icon mark (a vault or shield with a small checkmark or currency symbol) on the left, followed by the wordmark "VaultSpend" in a clean, modern sans-serif font on the right. Primary color: teal (#0D9488). Background: transparent. Style: flat, professional, minimal. Suitable for app UI, website headers, and marketing.

---

### 3. Stacked Logo (Vertical)

> A vertical/stacked logo layout for "VaultSpend". The icon mark sits centered above the wordmark "VaultSpend". Icon: a minimal vault or shield in teal (#0D9488). Wordmark: bold, clean sans-serif. Background: transparent. Style: flat vector. Use case: app store listings, email footers, square format placements.

---

### 4. Icon-Only Logo Mark

> A standalone icon/symbol for the VaultSpend app — a minimal, geometric vault door or secure shield that subtly incorporates a finance or currency element (coin, arrow, or checkmark). Color: teal (#0D9488). Background: transparent. No text. Flat vector, single-color friendly. Use case: favicons, small UI placements, watermarks.

---

### 5. Monochrome Logo (Dark Background)

> The VaultSpend horizontal logo rendered in white/light gray on a transparent background. Single-color version for use on dark backgrounds (e.g., the app's dark UI surface #121218 or dark marketing materials). Flat vector, no gradients.

---

### 6. Monochrome Logo (Light Background)

> The VaultSpend horizontal logo rendered in near-black (#0B0B0F) or dark teal on a transparent background. Single-color version for use on light/white backgrounds. Flat vector, no gradients.

---

### 7. Splash Screen / Launch Image

> A full-screen splash/launch image for the VaultSpend mobile app. Centered: the VaultSpend logo (icon + wordmark) in white. Background: deep near-black (#0B0B0F) with a very subtle dark teal radial glow around the logo. Minimal, clean, premium feel. No illustrations, no decorative elements. Aspect ratio 9:19.5 (mobile portrait). Format: PNG.

---

### 8. App Store / Play Store Feature Graphic

> A marketing feature banner for the VaultSpend finance app. Dimensions: 1024×500px (Google Play feature graphic). Left side: VaultSpend logo in white on a deep teal-to-dark gradient (#0D9488 → #0B0B0F). Right side: a clean phone mockup showing the Insights dashboard screen with charts and spending data. Tagline: "Track Expenses. Manage Subscriptions. Stay in Control." Bold, modern, flat design. No clutter.

---

### 9. App Store Screenshots Background

> A screenshot background template for the VaultSpend iOS App Store listing. Gradient background: deep teal (#0D9488) fading to near-black (#121218). Clean, spacious. Top area reserved for caption text. Bottom area reserved for phone mockup. Aspect ratio: 9:19.5. Simple and premium.

---

### 10. Category Icons Set

> A set of 30 flat, minimal line icons for a personal finance app's expense categories. Icons needed: shopping bag, grocery cart, food/fork-knife, drink/glass, coffee cup, car, taxi, bus, train, bicycle, fuel pump, parking sign, airplane/travel, phone, wifi/internet, home/rent, tools/repair, office/briefcase, gym/dumbbell, sports/ball, health/heart, medical/pill, hospital/cross, electricity/bolt, water/droplet, gas flame, money/dollar, category/tag, bank/vault, wallet. Style: flat vector, single-color, 2px stroke weight, rounded corners. Teal (#0D9488) on transparent background. 64×64px each.

---

### 11. Empty State Illustrations

> A set of 5 minimal, friendly flat illustrations for empty state screens in a dark-themed finance app:
>
> 1. No expenses yet — empty wallet or simple receipt
> 2. No subscriptions — empty calendar or pause icon
> 3. No categories — empty tag/label
> 4. No activity log — empty clock/history
> 5. No insights data — empty chart/graph
>
> Style: flat vector, teal (#0D9488) accent on dark (#1C1C26) card backgrounds. Simple, friendly, not overly illustrated. Suitable for mobile dark mode UI.

---

### 12. Onboarding / Marketing Illustrations

> Three clean flat illustrations for a personal finance app's marketing page or onboarding flow:
>
> 1. **Track** — A person looking at a phone showing expense entries, teal accents
> 2. **Organize** — Categories and icons neatly arranged, structured and tidy
> 3. **Understand** — A person reviewing a chart/graph of spending trends, feeling in control
>
> Style: flat vector, modern, minimal characters with no faces (abstract human shapes). Brand colors: teal (#0D9488), near-black (#0B0B0F), white. Mobile-first composition.

---

### 13. Social Media / Marketing Card

> A square social media post (1080×1080px) promoting the VaultSpend app. Bold headline: "Know Where Your Money Goes." Subtext: "Track expenses, manage subscriptions, get insights. VaultSpend — available on Android & iOS." Background: dark (#0B0B0F) with a teal (#0D9488) geometric accent shape. VaultSpend logo bottom-left. Clean, modern, dark-mode aesthetic.
