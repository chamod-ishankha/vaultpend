# Project Specification: VaultSpend

**Version:** 1.4.13  
**Status:** In progress  
**Last updated:** 2026-04-04  
**Target platforms:** Android, iOS  

---

## 1. Executive Summary

**VaultSpend** is a privacy-centric, cross-platform financial management app for daily expenses and recurring subscriptions. Built with **Flutter**, it aims for fast entry on mobile with **offline-first** local storage, a guest/local-only mode, and optional **encrypted cloud sync** when the user signs in.

---

## 2. Core Functional Requirements

### 2.1 Expense tracking

- **Fast entry:** UI optimized so a typical manual expense can be logged in under ~5 seconds (amount, category, optional note).
- **Categorization:** Manual tagging; optional defaults or suggestions per category (e.g. Development, Food, Utilities).
- **Multi-currency:** Support **LKR**, **USD**, and **EUR** with stored amounts per transaction and conversion using **cached daily rates** when offline, refreshed when online (see §3.4).
- **Offline first:** Create, edit, list, and search expenses without network access; sync when available (Phase 2+).

### 2.2 Subscription management (“Anti-Drain”)

- **Active tracking:** Dashboard for recurring SaaS and lifestyle subscriptions (cost, cycle, next billing).
- **Renewal notifications:** Local and/or push reminders **24 h and 48 h** before billing (exact channel per platform in §3.5).
- **Trial monitoring:** “Trial” state for subscriptions that need explicit confirmation before treating them as paid.
- **Burn rate:** Derived metrics: fixed cost per day / week / month from active subscriptions (and optionally recurring expense rules later).

### 2.3 Data and synchronization

- **Cross-platform parity:** Same logical data model on Android and iOS with a fixed conflict strategy: **last-write-wins using Firestore `updated_at` server timestamps**, plus deterministic tie-break by document id when timestamps are equal.
- **Export:** Monthly and annual reports as **PDF** and **CSV**.
- **Secure backup:** Encrypted backups for account recovery (aligned with §7).
- **Guest mode:** The app must be usable without an account using only local storage; sync features remain disabled until the user signs in.

### 2.4 Out of scope for v1 (non-goals)

- Banking / card aggregation (Plaid-style live feeds).
- Multi-user shared budgets or family plans.
- Investment portfolio tracking beyond labeling expenses.

---

## 3. Technical Stack

| Component | Technology | Rationale |
| :--- | :--- | :--- |
| **Frontend** | Flutter | Single codebase for Android and iOS. |
| **State management** | Riverpod | Testable providers and scalable dependency graph. |
| **Local database** | **isar_community** (Isar v3 fork) | Maintained fork compatible with current Dart/Flutter; run `dart run build_runner build` after model changes. |
| **Cloud backend** | Firebase (Firestore + Firebase SDKs) | Managed backend for auth, sync storage, and platform integration. |
| **Cloud database** | Cloud Firestore | User-scoped collections (`users/{uid}/...`) for categories, expenses, and subscriptions. |
| **Authentication** | Firebase Auth | Email/password auth for signed-in sync; local guest mode remains unauthenticated. |

### 3.1 Exchange rates

- Use a **public FX API** (e.g. frankfurter.app, exchangerate.host, or ECB-based feeds) with **daily** refresh when online; persist last-good rates for offline display and rough conversion—not for regulated financial reporting.

### 3.2 Push and local notifications

- **Mobile:** Firebase Cloud Messaging (FCM) or equivalent for push; local notifications for reminders when push is unavailable.

### 3.3 PDF / CSV

- **CSV:** Generated client-side or via Firebase-backed export flow—choose one implementation path per export feature to avoid duplication.
- **PDF:** Flutter/pdf or Firebase-backed render path—decide in Phase 3 based on layout complexity.

---

## 4. System Architecture and Data Model

### 4.1 High-level architecture

- **Client:** Flutter app with Isar (local) + Riverpod.
- **Cloud services:** Firebase Auth + Cloud Firestore.
- **Sync:** Authenticated client syncs Firestore documents with server timestamps; client remains local-first with reconciliation on refresh using LWW resolution (`updated_at` precedence).

### 4.2 Key entities (conceptual)

| Entity | Main fields (illustrative) |
| :--- | :--- |
| **User** | `id` (Firebase UID), `email`, `preferred_currency`, `created_at`, `updated_at` |
| **Transaction** | `id`, `user_id`, `amount`, `currency`, `category_remote_id`, `occurred_at`, `note`, `is_recurring` |
| **Subscription** | `id`, `user_id`, `name`, `amount`, `currency`, `cycle`, `next_billing_date`, `is_trial`, `trial_ends_at` (nullable) |
| **Category** | `id`, `user_id`, `name`, `icon_key`, `color` |

Indexes and full sync payload shapes belong in the API/database design doc.

---

## 5. UI/UX Design Principles

1. **Adaptive layouts**
   - **Mobile:** Bottom navigation, large touch targets, minimal steps for add-expense flow.
   - **Tablet:** Expanded spacing and wider list/form layouts where useful.
2. **Visual feedback:** Charts (e.g. spending by category, trend over time) using Flutter charting or `CustomPainter` where custom visuals are needed.
3. **Dark mode first:** Default to a high-contrast dark theme; light theme as secondary.
4. **Brand consistency:** Use the VaultSpend logo asset in key identity surfaces (login, splash transition, sidebar header) instead of repeating plain text branding.

**Accessibility:** Respect platform font scaling; sufficient contrast; semantic labels for screen readers on primary flows (add expense, list, subscriptions).

---

## 6. Non-Functional Requirements

- **Performance:** Cold start and main list screens should feel responsive on mid-range devices (targets to be measured in QA).
- **Privacy:** No third-party analytics or ad SDKs unless explicitly added later with user consent and documentation.
- **Security:** See §7; biometrics as app lock only—does not replace server authentication for sync.

---

## 7. Security Considerations

- **Encryption in transit:** TLS for all API calls; certificate pinning considered for production mobile builds.
- **Encryption at rest:** Sensitive fields and backup blobs encrypted before cloud storage; key derivation and rotation documented in backend spec.
- **Biometric lock:** Local authentication (Face ID / fingerprint / device PIN) to open the app on mobile.
- **Privacy:** Minimal data collection; no sale of user data; clear privacy policy before account creation.

---

## 8. Development Roadmap

**Execution order:** Phases are done **one at a time**. Do not start the next phase until the current phase’s exit criteria are met.

| Phase | Backend status |
| :--- | :--- |
| **Phase 1** | **Done (client).** Local Isar MVP; optional polish complete. |
| **Phase 2** | **In progress:** Firebase Auth + Firestore sync operational, guest/local-only mode preserved, and UX polish ongoing. |

**Firestore layout (Phase 2+):**

- **Root:** `users/{uid}` for each authenticated user.
- **Collections:** `categories`, `expenses`, `subscriptions` under each user document.

### Phase 1: Foundation (local MVP) — **complete**

- [x] Create Flutter app under `app/` (`flutter create`, package name `vaultspend`).
- [x] Project structure: `lib/core`, `lib/data`, `lib/features` (feature-oriented).
- [x] Local DB: **isar_community** + codegen; models `Category`, `Expense`, `Subscription`; repositories.
- [x] Expense list + add expense; subscription list + add subscription; bottom navigation shell.
- [x] Optional polish: pull-to-refresh, edit/delete, FX display-only (Frankfurter + local cache; not accounting advice).

**Exit criteria:** User can add expenses and subscriptions offline with no server.

### Phase 2: Firebase sync — **current**

- **Auth:** Firebase email/password sign-in and sign-up.
- **Data:** Firestore-backed sync for categories, expenses, and subscriptions.
- **Flutter:** guest/local-only mode, sign-in/out flow, and local-first repositories with cloud sync when signed in.

#### Phase 2 implementation snapshot (2026-04-03)

- [x] Firebase bootstrap + email/password authentication flow integrated in Flutter.
- [x] Firestore user-scoped collections (`users/{uid}/categories|expenses|subscriptions`) wired into repository sync paths.
- [x] Guest/local-only mode preserved when signed out.
- [x] User-facing auth copy standardized to **Cloud sync** wording.
- [x] Branding pipeline updated and applied (launcher icon, logo, splash assets + key in-app logo placements).
- [x] Shell banner now surfaces live Cloud sync context, including latest known Cloud update timestamp.
- [x] Conflict policy documented as LWW via Firestore `updated_at` server timestamps (deterministic tie-break on id).
- [x] Expense screen CSV export action implemented (share-ready file generation from local data).
- [x] Subscription screen CSV export action implemented (share-ready file generation from local data).
- [x] PDF export services implemented for Expenses and Subscriptions with formatted tables, summaries, and burn-rate estimates.
- [x] Unified export menus (CSV and PDF) wired into both Expense and Subscription screens.
- [x] Web target and all web-specific runtime/configuration paths removed; project scope is now Android/iOS-only.
- [x] Isar generated schemas regenerated for native consistency after platform cleanup.
- [ ] Continue Phase 3 features (analytics dashboards and additional reporting).

### Phase 3: Analytics and reporting

- Mobile analytics and reporting enhancements.
- Analytics views (e.g. pie charts, trend lines).
- [x] Insights screen now includes range filters, top key metrics strip, spend trend line chart with shaded area, month-over-month spend comparison with directional indicators, currency split, category distribution with donut visualization, largest subscriptions, recent activity, subscription currency split, subscription burn summaries, subscription cycle mix, recurring expense snapshots, and configurable upcoming billing forecast (7/30/60-day windows) with nearest scheduled billings preview and tap-through to edit subscriptions.
- [x] Insights CSV and PDF exports implemented with summary tables covering expenses, subscriptions, categories, recurring expense totals, upcoming billings, and recent activity.
- [x] Upcoming billing analytics now surface overdue and due-soon counts plus trial lifecycle status labels (trial ends in X days / trial expired X days ago / due today) for clearer subscription risk monitoring.
- [x] Mock trend mode removed; Insights trend now always reflects live filtered data with currency-scoped plotting.
- [x] Renewal timing buckets added in Insights upcoming billing summary for due-in-24h and due-in-48h monitoring.
- [x] Local subscription renewal reminders implemented and auto-synced (24h and 48h before billing) via scheduled mobile notifications.

### Phase 4: Intelligence and automation

- On-device receipt OCR (e.g. ML Kit or similar) for amount/category hints.
- Automated recurring rules and server-side reconciliation where applicable.

---

## 9. Open Decisions (to close during implementation)

| Topic | Options | Note |
| :--- | :--- | :--- |
| PDF generation | Client vs server | Depends on template complexity. |

---

## 10. Glossary

- **Burn rate (subscriptions):** Recurring subscription cost normalized to day/week/month.
- **Offline first:** Full CRUD locally; network enhances sync and rates, not basic usage.
- **Trial mode:** Subscription tracked as trial until user confirms or `trial_ends_at` passes.
