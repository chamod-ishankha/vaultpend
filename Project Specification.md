# Project Specification: VaultSpend

**Version:** 1.4.1  
**Status:** Draft  
**Last updated:** 2026-04-03  
**Target platforms:** Android, iOS, Web  

---

## 1. Executive Summary

**VaultSpend** is a privacy-centric, cross-platform financial management app for daily expenses and recurring subscriptions. Built with **Flutter**, it aims for fast entry on mobile and clear analytics on the web, with **offline-first** local storage, a guest/local-only mode, and optional **encrypted cloud sync** when the user signs in.

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

- **Cross-platform parity:** Same logical data model on mobile and web; conflict resolution defined with the sync API (last-write-wins with audit fields or server timestamps—finalize in backend design).
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
| **Frontend** | Flutter | Single codebase for mobile and web. |
| **State management** | Riverpod | Testable providers and scalable dependency graph. |
| **Local database** | **isar_community** (Isar v3 fork) | Maintained fork compatible with current Dart/Flutter; run `dart run build_runner build` after model changes. |
| **Cloud backend** | Firebase (Firestore + Firebase SDKs) | Managed backend for auth, sync storage, and platform integration. |
| **Cloud database** | Cloud Firestore | User-scoped collections (`users/{uid}/...`) for categories, expenses, and subscriptions. |
| **Authentication** | Firebase Auth | Email/password auth for signed-in sync; local guest mode remains unauthenticated. |

### 3.1 Exchange rates

- Use a **public FX API** (e.g. frankfurter.app, exchangerate.host, or ECB-based feeds) with **daily** refresh when online; persist last-good rates for offline display and rough conversion—not for regulated financial reporting.

### 3.2 Push and local notifications

- **Mobile:** Firebase Cloud Messaging (FCM) or equivalent for push; local notifications for reminders when push is unavailable.
- **Web:** Browser notification API where permitted; may be limited vs mobile—document UX fallback (e.g. in-app banner on next open).

### 3.3 PDF / CSV

- **CSV:** Generated client-side or via Firebase-backed export flow—choose one implementation path per export feature to avoid duplication.
- **PDF:** Flutter/pdf or Firebase-backed render path—decide in Phase 3 based on layout complexity.

---

## 4. System Architecture and Data Model

### 4.1 High-level architecture

- **Client:** Flutter app with Isar (local) + Riverpod.
- **Cloud services:** Firebase Auth + Cloud Firestore.
- **Sync:** Authenticated client syncs Firestore documents with server timestamps; client remains local-first with reconciliation on refresh.

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
   - **Web / desktop:** Navigation rail or sidebar, wider tables and filters, keyboard-friendly entry where possible.
2. **Visual feedback:** Charts (e.g. spending by category, trend over time) using Flutter charting or `CustomPainter` where custom visuals are needed.
3. **Dark mode first:** Default to a high-contrast dark theme; light theme as secondary.

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
| **Phase 2** | **In progress:** Firebase Auth + Firestore sync wiring, with guest/local-only mode preserved when signed out. |

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

### Phase 3: Web and analytics

- Flutter web build and deployment pipeline.
- Analytics views (e.g. pie charts, trend lines).
- PDF and CSV export (per §3.3).

### Phase 4: Intelligence and automation

- On-device receipt OCR (e.g. ML Kit or similar) for amount/category hints.
- Automated recurring rules and server-side reconciliation where applicable.

---

## 9. Open Decisions (to close during implementation)

| Topic | Options | Note |
| :--- | :--- | :--- |
| Sync conflict strategy | LWW vs merge-by-field | Must be fixed before multi-device rollout. |
| Web push | FCM web vs in-app only | Depends on hosting and browser support. |
| PDF generation | Client vs server | Depends on template complexity. |

---

## 10. Glossary

- **Burn rate (subscriptions):** Recurring subscription cost normalized to day/week/month.
- **Offline first:** Full CRUD locally; network enhances sync and rates, not basic usage.
- **Trial mode:** Subscription tracked as trial until user confirms or `trial_ends_at` passes.
