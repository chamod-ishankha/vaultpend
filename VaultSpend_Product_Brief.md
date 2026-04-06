# VaultSpend Product Brief (Current State)

## 1) Product Overview
VaultSpend is a **mobile-first personal finance app** (Flutter, Android/iOS) focused on:
- Fast expense and subscription tracking
- Local-first reliability (works offline)
- Optional Cloud sync when signed in
- Reminder intelligence for renewals and recurring expenses
- Practical insights and exports (CSV/PDF)

Current app version: **1.5.22+14**

## 2) Product Positioning and Core Value
VaultSpend is designed for users who want:
- A private, dependable daily finance tracker
- No lock-in to internet connectivity
- Clear visibility into recurring spending and subscription renewals
- Actionable reports with quick sharing/export

The app supports:
- **Guest mode** (local-only)
- **Signed-in mode** (Firebase Auth + Firestore sync)

---

## 3) Technical Foundation (High-Level)
- **Frontend:** Flutter + Riverpod
- **Local DB:** Isar (source of truth for local-first behavior)
- **Cloud:** Firebase Auth + Cloud Firestore
- **Notifications:** flutter_local_notifications
- **Exports:** CSV + PDF + Share sheet
- **OCR:** Image picker + ML Kit text recognition for receipt scan assistance

Data domains:
- Categories
- Expenses
- Subscriptions
- Activity logs
- Sync incidents
- Reminder diagnostics metadata

---

## 4) Current Product Logic

### 4.1 App startup and session flow
- App initializes Firebase and Isar in `main.dart`.
- Root app (`VaultSpendApp`) resolves auth state + guest mode.
- A branded splash is shown first.
- If user is authenticated or in guest mode → open Shell (main app).
- Otherwise → Login screen.

### 4.2 Local-first and Cloud sync
- Core repositories are user-scoped via Riverpod providers.
- If signed in: repositories enable cloud sync to Firestore.
- If guest: local storage remains active, cloud sync disabled.
- Shell screen supports manual “Sync now” and auto sync behavior when network reconnects.
- Sync status banner communicates online/offline/syncing state.

### 4.3 Reminder engine
- Global reminder service initializes after app starts.
- Reminder sync runs:
  - On startup
  - Periodically (2-minute ticker)
  - On lifecycle resume
  - On reminder toggle changes
- Supports master toggle + per-type toggles:
  - Subscription reminders
  - Recurring expense reminders
- Diagnostics screen compares **expected vs pending** reminders and bucket breakdowns.

### 4.4 Currency and FX behavior
- Preferred currency exists per user/profile.
- Key screens can show converted amounts using FX snapshot (fallback-safe).
- Insights supports both:
  - Preferred-currency normalized analytics
  - Currency-wise native breakdown mode

### 4.5 Activity and operational logging
- User actions (add/update/delete, trial actions, etc.) are logged in activity log.
- Sync failures are captured in sync incidents with pagination and trend summaries.

---

## 5) Information Architecture & Navigation

## Main Shell Tabs
1. **Expenses**
2. **Subscriptions**
3. **Insights**

## Drawer / Side actions
- Categories
- Settings
- Sync status / Sync now (signed-in)
- Sign out (signed-in) or sign-in CTA (guest)

## Settings hub
- Profile
- Reminder controls
- Reminder diagnostics
- Sync incidents
- Activity log

---

## 6) Screen-by-Screen Brief

### 6.1 Auth & entry
- **AuthLoadingScreen**: branded loading state while restoring session.
- **LoginScreen**:
  - Email/password login
  - Create account navigation
  - Continue as guest (local only)
  - Cloud availability message and error cards
- **RegisterScreen**:
  - Email/password/confirm validation
  - Preferred currency selection (LKR/USD/EUR)

### 6.2 Home/Shell
- Tabbed navigation (NavigationBar on mobile, NavigationRail on wider layouts)
- Top status banner for Cloud/guest/offline state
- Sync controls and account-related shortcuts

### 6.3 Expenses
- **ExpenseListScreen**:
  - List + pull-to-refresh
  - Empty state with guidance
  - Inline edit/delete via menu
  - CSV/PDF export menu
  - FX reference strip and preferred-currency rendering
- **AddExpenseScreen**:
  - Amount, currency, category, date/time, recurring toggle, note
  - Receipt scan action with OCR amount suggestion flow
  - Save updates logs and reminder resync

### 6.4 Subscriptions
- **SubscriptionListScreen**:
  - Sorted list with trial-first handling
  - Trial summary card (ending soon / expired / missing end date)
  - Mark trial as paid flow
  - CSV/PDF export menu
- **AddSubscriptionScreen**:
  - Name, amount, currency, billing cycle, next billing date/time
  - Trial toggle and trial end date

### 6.5 Insights
- **InsightsScreen** dashboard includes:
  - Range selector: 7D / 30D / 90D / All
  - Report view presets:
    - Overview
    - Spending focus
    - Subscription focus
    - Billing watch
    - Currency breakdown
  - Key metrics strip
  - Trend chart
  - Month-over-month comparison
  - Category distribution
  - Currency splits
  - Subscription cycle mix
  - Largest subscriptions
  - Upcoming billing card (window selector)
  - Recent activity summary
  - CSV/PDF export

### 6.6 Categories
- **ManageCategoriesScreen**:
  - Category list with icon + color avatar preview
  - Edit/delete actions
- **EditCategoryScreen**:
  - Name + optional description
  - Database-backed icon picker (searchable)
  - Database-backed color picker

### 6.7 Settings & operational screens
- **SettingsScreen**:
  - Profile entry
  - Reminder master/type toggles
  - Diagnostics links
- **ProfileUpdateScreen**:
  - Display name update
  - Preferred currency update
  - Password change with current password verification
- **ReminderDiagnosticsScreen**:
  - Current toggle states
  - Reliability/coverage counters
  - Expected vs pending analysis
  - Pending reminder sections by type
- **SyncIncidentScreen**:
  - Incident timeline and pagination
  - 7-day summary cards and trend visuals
  - Clear incidents
- **ActivityLogScreen**:
  - Paginated activity timeline
  - Pull-to-refresh + clear log

---

## 7) UX, Design System, and Visual Language

### 7.1 Theme model
- Material 3-based theme
- Both light and dark themes defined
- App is currently forced to **dark mode** (`ThemeMode.dark`)

### 7.2 Core colors in theme
From `app_theme.dart`:
- **Dark scaffold background:** `#0B0B0F`
- **Dark surface:** `#121218`
- **Dark seed color:** `#0D9488`
- **Light scaffold background:** `#F1F5F9`
- **Light surface:** `#F8FAFC`
- **Light seed color:** `#0F766E`

Brand splash/launcher background also uses: `#0B0B0F`

### 7.3 Category color palette (catalog-backed)
Current selectable category color keys:
- `primary_container` (Primary)
- `secondary_container` (Secondary)
- `tertiary_container` (Tertiary)
- `error_container` (Error)
- `surface_container_highest` (Neutral)

### 7.4 Typography / fonts
- No custom font family declared in `pubspec.yaml`
- Uses Flutter/Material default typography (platform default)

### 7.5 Branding assets
- `assets/branding/app_icon.png`
- `assets/branding/logo.png`
- `assets/branding/splash.png`

Visual tone:
- Dark, high-contrast, finance-dashboard style
- Teal-driven accent system
- Card-heavy content blocks with operational status emphasis

### 7.6 Component patterns used broadly
- AppBar + list-centric layouts
- Cards for summaries/diagnostics
- Popup menus for actions (edit/delete/export)
- Modal bottom sheets for pickers/confirm flows
- Snackbars for operation feedback
- RefreshIndicator for manual data refresh

---

## 8) Data + Feature Coverage Summary
Current implemented feature coverage includes:
- Expense CRUD
- Subscription CRUD + trial lifecycle support
- Category CRUD + metadata (description, icon, color)
- Reminder scheduling + diagnostics
- Activity logging
- Sync incident tracking
- Preferred currency and FX-aware display
- Insights dashboard with multiple report views
- CSV/PDF exports for Expenses, Subscriptions, Insights

---

## 9) Current UX Strengths (for rewamp baseline)
- Clear offline-first + sync messaging
- Strong operational transparency (diagnostics/logs/incidents)
- Functional depth in insights and exports
- Consistent form and list interaction model
- Good user control over reminders and trial transitions

## 10) Rewamp Opportunities (high-level)
- Unify visual hierarchy across dense screens (especially diagnostics/insights)
- Modernize spacing, card rhythm, and type scale for readability
- Improve cross-screen component consistency (status chips, section headers, empty states)
- Refine navigation discoverability (drawer/settings depth)
- Introduce stronger brand identity through typography and visual tokens
- Simplify advanced analytics for casual users while keeping power-user depth

---

## 11) Build/Test/Lint commands (documented in repo)
From `app/README.md` (run inside `app/`):
- `flutter pub get`
- `flutter analyze`
- `flutter test`
- `flutter run`

Note: In this current environment, Flutter CLI is not installed, so runtime validation commands could not be executed here.

---

## 12) Brief Conclusion
VaultSpend is a mature local-first finance app with strong reliability, reminders, diagnostics, and reporting capabilities. A rewamp can now focus mainly on **UI/UX modernization, visual consistency, and improved information architecture** without changing the product’s strong functional core.
