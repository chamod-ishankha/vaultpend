# VaultSpend — UI/UX Reference Document

> **Purpose:** Full description of the current VaultSpend mobile app (v1.5.22) for use as a reference when creating a new UI/UX design.
> **Platform:** Android + iOS (mobile-first, with responsive support for wider screens)
> **Framework:** Flutter 3, Material 3 (Material You)

---

## 1. Project Overview

VaultSpend is a **personal finance app** focused on:
- Fast expense and subscription tracking
- Reliable **local-first** behavior (works fully offline)
- Optional **Cloud sync** via Firebase when signed in
- Smart reminders for upcoming bills and recurring expenses
- Clear, actionable financial insights and reports

### Key User Modes
| Mode | Description |
|------|-------------|
| **Guest Mode** | Local-only. No account needed. Data stays on device. |
| **Signed-In Mode** | Full features + Cloud sync across devices. |

---

## 2. Design System & Visual Identity

### 2.1 Color Palette (Material 3 — Dark Mode Default)

The app uses **Material 3 color system** seeded from a **teal/cyan primary color**.

| Token | Dark Mode Value | Light Mode Value | Usage |
|-------|-----------------|------------------|-------|
| Scaffold Background | `#0B0B0F` (near black) | `#F1F5F9` | Main screen background |
| Surface | `#121218` (dark grey-purple) | `#F8FAFC` | Cards, drawers |
| Primary Seed (dark) | `#0D9488` (teal) | `#0F766E` (darker teal) | Primary buttons, highlights |
| Splash/Icon Background | `#0B0B0F` | – | Splash screen, app icon |

> **The app launches in dark mode by default** (`ThemeMode.dark`). Light mode is defined but not the default.

### 2.2 Typography
- **No custom fonts** — uses Flutter/Material 3's default system font (Roboto on Android, SF Pro on iOS)
- Follows Material 3 text role hierarchy: `displayLarge` → `titleMedium` → `bodySmall`
- Section headers use `titleSmall` with `fontWeight: w700`
- Amount values use `titleMedium`

### 2.3 Shape & Elevation
- Cards use default Material 3 card shape (slightly rounded corners ~12dp)
- Inputs use `OutlineInputBorder()` (fully bordered, rectangle with rounded corners)
- FABs (Floating Action Buttons) use default Material 3 FAB shape
- Dialogs use `AlertDialog()` with Material 3 styling

### 2.4 Icons
- Exclusively uses **Material Icons** (outlined variants preferred for inactive states, filled for active/selected)
- Categories support an optional icon from a **bundled icon catalog** (JSON-based)

### 2.5 Branding Assets
- `assets/branding/logo.png` — Full logo shown on auth screens (height 150px)
- `assets/branding/app_icon.png` — Square icon used in splash, navigation rail header
- `assets/branding/splash.png` — Full-screen splash image (shown for 3 seconds on launch)

---

## 3. App Navigation Structure

### 3.1 Main Navigation (Bottom nav on mobile, Rail on desktop)

```
Shell Screen
├── [Tab 0] Expenses        (icon: receipt_long_outlined / receipt_long)
├── [Tab 1] Subscriptions   (icon: subscriptions_outlined / subscriptions)
└── [Tab 2] Insights        (icon: insights_outlined / insights)
```

### 3.2 Side Drawer (Mobile-only)
Accessed via hamburger menu icon (top-left of each main screen):
```
Drawer
├── [Header] Logo image (DrawerHeader, background: surfaceContainerHighest)
├── [Tile] User email / "Guest mode" + subtitle (Signed in / Local-only)
├── [Tile] Account sync (if signed in — cloud_sync_outlined icon)
├── [Tile] Categories → ManageCategoriesScreen
├── [Tile] Settings → SettingsScreen
├── [Divider]
├── [Tile] Sync status tile (categories/expenses/subscriptions counts + last sync)
├── [Tile] Sync now (sync icon)
├── [Tile] Sign out (logout icon)      ← if signed in
└── [Tile] Sign in or create account   ← if guest mode
```

### 3.3 Status Banner (Persistent, top of shell content)
A colored horizontal bar sits **below the safe area, above the tab content** on every shell screen.

| State | Background Color | Icon | Title | Action Button |
|-------|-----------------|------|-------|---------------|
| Signed in + online | `primaryContainer` | `cloud_done_outlined` | "Account sync active" | "Sync now" |
| Signed in + syncing | `primaryContainer` | `sync` | "Syncing account data" | none |
| Signed in + offline | `primaryContainer` | `cloud_done_outlined` | "Offline local mode" | none |
| Guest mode | `secondaryContainer` | `person_outline` | "Guest mode" | none |
| Not signed in | `surfaceContainerHighest` | `lock_outline` | "Not signed in" | none |

---

## 4. Screen-by-Screen Description

---

### Screen 1: Splash Screen

**File:** `app.dart` → `_VaultSpendSplashScreen`

**Layout:**
- Full-screen scaffold, no AppBar
- `SizedBox.expand` containing a full-cover `Image` widget
- Image: `assets/branding/splash.png` with `BoxFit.cover`
- Displayed for **3 seconds** then replaced by Login or Shell

**Design Notes:**
- Background is effectively `#0B0B0F` (very dark near-black)
- No navigation controls, completely immersive

---

### Screen 2: Login Screen

**File:** `features/auth/login_screen.dart`

**Layout:** Centered scrollable column, max width 460px (responsive constraint)

```
[Padding: 24px all sides]
  ↕ 24px spacer
  [Logo image: 150px tall, centered]
  ↕ 8px
  [Subtitle text: "Sign in to sync your data with Cloud."]
    → bodyMedium, color: onSurfaceVariant, centered
  ↕ 32px
  [Error banner] (conditional, errorContainer background, rounded 8px)
  [Status message banner] (conditional, secondaryContainer background, rounded 8px)
  [TextField: Email] — OutlineInputBorder, emailAddress keyboard
  ↕ 16px
  [TextField: Password] — obscured, visibility toggle icon suffix
  ↕ 24px
  [FilledButton: "Sign in"] — full width, 14px vertical padding
  ↕ 16px
  [TextButton: "Create account"] → navigates to RegisterScreen
  [TextButton.icon: "Continue as guest (local only)"] — person_outline icon
  ↕ 24px
  [Footnote text: offline/sync explanation] — bodySmall, color: outline, centered
```

**States:**
- Loading state: `FilledButton` shows `CircularProgressIndicator` (20×20, strokeWidth 2) instead of label
- All interactive elements disabled during submission (`busy = true`)

---

### Screen 3: Register Screen

**File:** `features/auth/register_screen.dart`

**Layout:** Centered scrollable column, max width 460px

```
[Padding: 24px all sides]
  ↕ 24px
  [Logo image: 150px tall, centered]
  ↕ 8px
  [Subtitle: "Create your account to enable Cloud sync."] — bodyMedium, centered
  ↕ 32px
  [Error banner] (conditional)
  [TextField: Email] — emailAddress keyboard
  ↕ 16px
  [TextField: Password (min 8 characters)] — obscured, toggle icon
  ↕ 16px
  [TextField: Confirm password] — obscured, toggle icon
  ↕ 16px
  [DropdownButtonFormField: Preferred currency] — options: LKR, USD, EUR
    OutlineInputBorder, label "Preferred currency"
  ↕ 24px
  [FilledButton: "Create account"] — full width, 14px padding
  ↕ 16px
  [TextButton: "Back to sign in"] → pops back
  ↕ 24px
  [Footnote: account creation note] — bodySmall, color: outline, centered
```

---

### Screen 4: Shell Screen (Main App Container)

**File:** `features/home/shell_screen.dart`

**Mobile Layout:**
```
[Status Banner (full-width, color varies by auth state)]
  → Icon + title text + subtitle + optional "Sync now" TextButton

[Animated content area — switches between 3 tabs]
  Tab 0: ExpenseListScreen
  Tab 1: SubscriptionListScreen
  Tab 2: InsightsScreen

[NavigationBar (bottom)]
  • Expenses    (receipt_long icon)
  • Subscriptions  (subscriptions icon)
  • Insights    (insights icon)
  → Selected indicator: primaryContainer color
```

**Desktop Layout (wide screens):**
```
[NavigationRail (left side)]
  [Header: App icon 72×72px]
  • Expenses
  • Subscriptions
  • Insights
  [Trailing: icon buttons for Categories, Settings, Sync, Sign out/in]

[Content area (expanded, right side)]
  [Status Banner]
  [Selected tab content]
```

**Drawer (mobile only, slides from left):**
- Background: themed surface
- Header: logo image on `surfaceContainerHighest` background
- User info tile + conditional sync/auth tiles
- See Section 3.2 for full structure

---

### Screen 5: Expense List Screen

**File:** `features/expenses/expense_list_screen.dart`

**AppBar:**
```
← [Menu icon (hamburger, if mobile)]    "Expenses"    [Download icon (export menu)]
```
Export popup menu: "Export as CSV" (table_chart icon) | "Export as PDF" (picture_as_pdf icon)

**Body layout:**
```
[FX Reference Strip] — thin horizontal bar showing live exchange rates
[Scrollable list OR empty state]
```

**List Item (ListTile per expense):**
```
[Title]: Amount with currency
  → If converted: preferred currency total
  → If not converted: original currency + amount
  → Style: titleMedium
[Subtitle]: Category name · Date (MMM d, yyyy h:mm a) · "Recurring" (if applicable)
[Trailing]:
  • Notes icon (notes icon, color: outline) — if expense has a note
  • PopupMenuButton → "Edit" | "Delete"
```

**Empty State:**
```
[Centered column, positioned 25% down screen]
  [receipt_long_outlined icon, size 40, color: outline]
  ↕ 12px
  [Text: "No expenses yet.\nTap + to add one.\nPull down to refresh."]
    bodyLarge, color: onSurfaceVariant, centered
```

**FAB:** `FloatingActionButton` with `add` icon → opens AddExpenseScreen

**Pull to refresh:** RefreshIndicator on list + FX rates

**Delete confirmation:** `AlertDialog` with "Delete expense?" title, "This cannot be undone." body, Cancel (TextButton) + Delete (FilledButton)

---

### Screen 6: Add / Edit Expense Screen

**File:** `features/expenses/add_expense_screen.dart`

**AppBar:**
```
← back    "Add expense" / "Edit expense"    [document_scanner_outlined icon]
```
Scanner icon → opens OCR receipt scanner bottom sheet

**Body (scrollable form, maxWidth 760px):**
```
[TextField: Amount]
  → numberWithOptions(decimal: true), digits + period/comma allowed
  → OutlineInputBorder, label "Amount"
  → Autofocused on new expense
↕ 16px
[DropdownButtonFormField: Currency]
  → Options: LKR, USD, EUR
  → Defaults to user's preferred currency on new expense
↕ 16px
[DropdownButtonFormField: Category]
  → Lists all user categories by name
  → Defaults to first category if available
↕ 16px
[ListTile: Date & Time]
  → Tappable, shows formatted date "MMM d, yyyy h:mm a"
  → Opens: date picker → then time picker
  → Styled with rounded border (outline color, radius 8)
↕ 8px
[SwitchListTile: "Recurring"]
  → Toggle for marking recurring expenses
↕ 0
[TextField: Note (optional)]
  → maxLines: 2, OutlineInputBorder
↕ 24px
[FilledButton: "Save"]
  → Full width, 12px vertical padding
  → Shows CircularProgressIndicator while saving
```

**Receipt OCR Bottom Sheet** (triggered by scanner icon):
```
[ModalBottomSheet with drag handle]
  [ListTile: "Use camera"] — camera_alt_outlined icon
  [ListTile: "Choose from gallery"] — photo_library_outlined icon
```
After scan, shows **Amount Confirmation Bottom Sheet**:
```
[ModalBottomSheet: "Confirm detected amount"]
  [Title: "Confirm detected amount"] — titleMedium, w700
  [Subtitle: "Choose the best match from receipt scan results."]
  [Radio-style ListTiles for each candidate amount (up to 3)]
    → Icon: radio_button_checked / radio_button_unchecked
    → Title: amount (2 decimal places)
    → Subtitle: source line from receipt (max 2 lines, ellipsis)
  [Row: TextButton "Skip" | FilledButton "Use amount"]
```

---

### Screen 7: Subscription List Screen

**File:** `features/subscriptions/subscription_list_screen.dart`

**AppBar:**
```
← [Menu icon]    "Subscriptions"    [Download icon (export)]
```

**Body:**
```
[FX Reference Strip]
[Trial Summary Card] (shown only when trial subscriptions exist)
[Sorted list of subscriptions]
```

**Trial Summary Card** (Card widget, `secondaryContainer` background):
```
[Padding: 16px]
  [Title: "Trial monitoring"] — titleMedium, onSecondaryContainer
  ↕ 8px
  [Text: "N trial subscription(s) tracked"] — bodyMedium
  ↕ 4px
  [Text: "N ending soon · N expired · N without end date"] — bodySmall
```

**Subscription List Item (ListTile):**
```
[Leading]: Icon
  → isTrial: hourglass_bottom icon
  → regular: subscriptions_outlined icon
[Title]: Subscription name
[Subtitle]: 
  "{currency} {amount} · {cycle} · Next: {MMM d, yyyy h:mm a} · {trial status label}"
  → Trial status: "Trial active", "N days left", "Trial expired", etc.
[Trailing]: PopupMenuButton
  → "Edit"
  → "Mark as paid" (shown only for trials)
  → "Delete"
```

**Sorting:** Trials first (sorted by trial end date), then by next billing date

**"Mark as paid" Confirmation Dialog:**
```
[AlertDialog]
  Title: "Convert trial to paid?"
  Body: "This will mark {name} as a paid subscription and clear trial fields."
  Actions: TextButton "Cancel" | FilledButton "Confirm"
```

**FAB:** `FloatingActionButton` with `add` icon → opens AddSubscriptionScreen

---

### Screen 8: Add / Edit Subscription Screen

**File:** `features/subscriptions/add_subscription_screen.dart`

**AppBar:**
```
← back    "Add subscription" / "Edit subscription"
```

**Body (scrollable form, maxWidth 760px):**
```
[TextField: Name]
  → textCapitalization: words, OutlineInputBorder
  → Autofocused on new subscription
↕ 16px
[TextField: Amount per cycle]
  → numberWithOptions(decimal: true)
↕ 16px
[DropdownButtonFormField: Currency] — LKR, USD, EUR
↕ 16px
[DropdownButtonFormField: Billing cycle]
  → Options: monthly, annual, custom
↕ 16px
[ListTile: Next billing date & time]
  → Rounded border, tappable → date+time picker
↕ 8px
[SwitchListTile: "Trial"]
  → Toggles trial mode
[If trial enabled:]
  [ListTile: "Trial ends at"]
    → "Not set" or formatted date+time
    → Rounded border, tappable → date+time picker
  ↕ 8px
↕ 16px
[FilledButton: "Save"] — full width, 12px padding
```

---

### Screen 9: Insights Screen

**File:** `features/insights/insights_screen.dart`

**AppBar:**
```
← [Menu icon]    "Insights"    [Download icon (export)]
```

**Body (scrollable dashboard):**

```
[Report View Selector] — horizontal chip/segment bar
  Options: Overview | Spending Focus | Subscription Focus | Billing Watch | Currency Breakdown
  → Persisted user preference

[Range Selector] — horizontal chip bar
  Options: 7D | 30D | 90D | All
  → Changes expense date filter

[Key Metrics Strip] — horizontal scrollable row of metric chips
  • Expenses count
  • Categories count
  • Subscriptions count
  • Trials count
  • Expired Trials count
  • MoM Increasing currencies count

[Trend Chart Card]
  → Custom-drawn line chart
  → Shows daily spend trend for selected range & dominant currency
  → X-axis: date labels, Y-axis: amount
  → Peak value marker
  → Canvas-drawn (CustomPainter), colored from _insightPalette

[Month-over-Month Card]
  → Table comparing current vs previous month spend by currency
  → Directional indicator icons (up/down/flat)
  → Delta values shown

[Detail Cards — visible based on active report view:]

  [Spending sections — Overview, Spending Focus, Currency Breakdown]
    • Expense summary card (count + totals by currency)
    • Expense Currency Split card (bar/text breakdown per currency)
    • Category Distribution card (visual spend distribution)
    • Recurring Expenses card
    • Top Categories (up to 5) card

  [Subscription sections — Overview, Subscription Focus, Billing Watch, Currency Breakdown]
    • Subscriptions summary card (active count + monthly burn per currency)
    • Subscription Currency Split card
    • Subscription Cycle Mix card (monthly/annual/etc distribution)
    • Largest Subscriptions card (top subscriptions sorted by amount)

  [Billing Watch section — Overview, Subscription Focus, Billing Watch]
    → Upcoming Billing Card
       [Billing window selector: 7D | 30D | 60D]
       [List of subscriptions due in window]
         Each: amount, date, trial badge if applicable
       [Totals by currency for window]
       Tapping a subscription → opens Edit Subscription screen

  [Activity section — all except Billing Watch]
    → Recent Activity Card
       Recent expenses (sorted by date, newest first)
       Recent subscriptions (sorted by billing date)
```

**Chart color palette:** 6 vibrant colors rotating
- `#00A6FB` (cyan-blue)
- `#FF006E` (hot pink)
- `#FB5607` (orange)
- `#8338EC` (purple)
- `#3A86FF` (blue)
- `#06D6A0` (mint green)

**Export:** CSV and PDF available via popup menu in AppBar

---

### Screen 10: Manage Categories Screen

**File:** `features/categories/manage_categories_screen.dart`

**AppBar:**
```
← back    "Categories"
```

**Body (scrollable list, responsive width):**

```
[ListView of categories, separated by Dividers]
  Per category:
    [Leading]: CircleAvatar (radius 14)
      → Background: resolved category color (or surfaceContainerHighest if none)
      → Child: resolved category icon (size 16, auto-contrasting foreground)
    [Title]: Category name
    [Subtitle]: metadata tags joined with " • "
      → "Starter category" (for default seeded categories: Food, Utilities, Development)
      → Description text (if set)
      → "icon: {label}" (if icon set)
      → "color: {label}" (if color set)
      → bodySmall, color: onSurfaceVariant
    [Trailing]: PopupMenuButton → "Edit" | "Delete"
```

**Empty state:** Centered text "No categories yet."

**Delete confirmation dialog:**
```
Title: "Delete category?"
Body: 'Expenses using "{name}" will show as uncategorized.'
Actions: Cancel (TextButton) | Delete (FilledButton)
```

**FAB:** `add` icon → opens EditCategoryScreen (create mode)

---

### Screen 11: Edit / New Category Screen

**File:** `features/categories/edit_category_screen.dart`

**AppBar:**
```
← back    "New category" / "Edit category"
```

**Body (scrollable form, maxWidth 680px):**
```
[Error banner] (conditional, errorContainer background)
↕ 0
[TextField: Name]
  → textCapitalization: words, OutlineInputBorder
  → Autofocused, triggers save on submit
↕ 16px
[TextField: Description (optional)]
  → minLines: 2, maxLines: 3
  → textCapitalization: sentences
↕ 16px
[Icon & Color Preview Container]
  → surfaceContainerLow background, outlineVariant border, radius 12
  → Label: "Icon (optional)" — labelLarge, w700

  [Row: preview + label]
    CircleAvatar (radius 18) with current icon on current color background
    Text showing icon selection state

  [Nested Color Container]
    → surfaceContainerLow background, outlineVariant border
    → Label: "Color (optional)" — labelLarge, w700
    [Row: color preview CircleAvatar + label text]
    [Row: FilledButton.tonal "Choose color" (palette_outlined) | TextButton "Clear"]

  [Row: FilledButton.tonal "Choose icon" (grid_view_outlined) | TextButton "Clear"]

↕ 24px
[FilledButton: "Add category" / "Save"]
  → full width, 12px vertical padding
```

**Icon Picker Bottom Sheet** (`showDragHandle: true`, scrollable):
```
[Title: "Choose an icon"] — titleMedium, w700
[TextField: Search icons] — search prefix icon, filters by key or label
[TextButton.icon: "No icon" (block_outlined)]
[Scrollable list of icon options]
  Each: CircleAvatar (surfaceContainerHighest bg) + icon | title (label) | subtitle (key)
  Selected: checkmark icon (check_circle) on trailing
```

**Color Picker Bottom Sheet** (`showDragHandle: true`, scrollable):
```
[Title: "Choose a color"] — titleMedium, w700
[TextButton.icon: "No color" (block_outlined)]
[Scrollable list of color options]
  Each: CircleAvatar with color + palette icon | title (label) | subtitle (key)
  Selected: checkmark icon trailing
```

---

### Screen 12: Settings Screen

**File:** `features/settings/settings_screen.dart`

**AppBar:**
```
← back    "Settings"
```

**Body (scrollable, padding `fromLTRB(12, 8, 12, 24)`):**

```
[Section header: "Profile"] — titleSmall, w700

[Card]
  [ListTile]
    Leading: person_outline icon
    Title: email address (or "Guest mode")
    Subtitle: "Preferred currency: {currency}" (or sign-in instruction)
    Trailing: chevron_right
    → Tapping: signed-in → ProfileUpdateScreen | guest → LoginScreen

↕ 14px
[Section header: "Reminder controls"] — titleSmall, w700

[Card]
  [SwitchListTile: "Renewal reminders"]
    → notifications_active_outlined (on) / notifications_off_outlined (off)
    → Subtitle shows current state
  [Divider height 1]
  [SwitchListTile: "Subscription reminders"]
    → subscriptions_outlined icon
    → 24h/48h reminders for subscription renewals
  [Divider height 1]
  [SwitchListTile: "Recurring expense reminders"]
    → repeat_outlined icon
    → 24h/48h reminders for recurring expenses

↕ 14px
[Section header: "Diagnostics and logs"] — titleSmall, w700

[Card]
  [ListTile: "Reminder diagnostics"]
    → bug_report_outlined icon
    → Subtitle: "View pending reminder jobs"
    → → ReminderDiagnosticsScreen
  [Divider height 1]
  [ListTile: "Sync incidents"]
    → sync_problem_outlined icon
    → Subtitle: "Open incident history"
    → → SyncIncidentScreen
  [Divider height 1]
  [ListTile: "Activity log"]
    → history_outlined icon
    → Subtitle: "See your recent actions"
    → → ActivityLogScreen
```

---

### Screen 13: Account Profile Screen

**File:** `features/settings/profile_update_screen.dart`

**AppBar:**
```
← back    "Account Profile"
```

**Body (scrollable, padding `fromLTRB(12, 8, 12, 24)`):**

```
[Section header: "Profile details"] — titleSmall, w700

[Card: Profile summary]
  [Padding: 16px]
  [Row: CircleAvatar (radius 22, primaryContainer bg, person_outline icon)]
    + [Column: displayName (titleMedium, w700) | email (bodySmall)]
  ↕ 16px
  [If signed in:]
    [Label: "Account ID"] — labelLarge, w700
    [Text: user ID string]
    ↕ 10px
    [Label: "Current preferred currency"] — labelLarge, w700
    [Text: currency code]
  [Status banner] — secondaryContainer bg (if success message)
  [Error banner] — errorContainer bg (if error)
  [If NOT signed in:]
    → FilledButton.icon "Sign in to edit profile" (login_outlined icon)

[If signed in:]
  ↕ 14px
  [Section header: "Editable fields"] — titleSmall, w700

  [Card with Form]
    [Padding: 16px]
    [TextFormField: Email address] — disabled/readOnly, OutlineInputBorder
    [Note: "Email updates are disabled..."] — bodySmall
    ↕ 16px
    [TextFormField: Display name] — editable, validates ≥2 chars
    ↕ 16px
    [DropdownButtonFormField: Preferred currency] — LKR, USD, EUR
    [Note: "This currency is used as the base..."] — bodySmall
    ↕ 18px
    [Section: "Change password"] — titleSmall, w700
    [TextFormField: Current password] — obscured, toggle
    ↕ 12px
    [TextFormField: New password] — obscured, toggle
    ↕ 12px
    [TextFormField: Confirm new password] — obscured, toggle
    [Note: "Leave password fields empty..."] — bodySmall
    ↕ 18px
    [Row: FilledButton "Save profile" (full width, 14px padding) | TextButton "Reset"]
```

---

### Screen 14: Activity Log Screen

**File:** `features/activity/activity_log_screen.dart`

**AppBar:**
```
← back    "Activity Log"    [delete_outline icon → clear dialog]
```

**Clear dialog:**
```
Title: "Clear activity log?"
Body: "This removes all activity records for this account."
Actions: Cancel | FilledButton "Clear"
```

**Body:**
```
[Loading state]: CircularProgressIndicator centered
[Empty state]: Centered text "No activity recorded yet."
[Populated list]: RefreshIndicator wrapping ListView.separated

  Per entry (Card with ListTile):
    Leading: history icon
    Title: action name (e.g. "Expense added", "Subscription deleted")
    Subtitle: "MMM d, yyyy h:mm a · {details}"

  [Footer]:
    → If loading more: CircularProgressIndicator
    → If no more: "End of activity log" text
    → If has more: TextButton "Load more"
```

**Pagination:** 25 items per page, infinite scroll (loads more when <280px from bottom)

---

### Screen 15: Reminder Diagnostics Screen

**File:** `features/reminders/reminder_diagnostics_screen.dart`

**AppBar:**
```
← back    "Reminder Diagnostics"
```

**Content:** Shows detailed diagnostic information about:
- Pending notification jobs (expected vs actual counts)
- Per-type breakdown (subscription reminders vs recurring expense reminders)
- Human-readable "time remaining" labels for pending triggers

---

### Screen 16: Sync Incident Screen

**File:** `features/reminders/sync_incident_screen.dart`

**AppBar:**
```
← back    "Sync Incidents"
```

**Content:** History of Cloud sync failures/incidents with timestamps and error details.

---

## 5. Common UI Patterns & Components

### 5.1 FX Reference Strip
A thin horizontal strip shown at the top of Expenses and Subscriptions list screens showing live exchange rate indicators (e.g., USD→LKR rate). Horizontal scrollable. Part of `core/widgets/fx_reference_strip.dart`.

### 5.2 Empty States
Consistent empty state pattern:
- Icon: large (40px), `color: outline`
- Message: `bodyLarge`, `color: onSurfaceVariant`, center-aligned
- Support instruction (e.g., "Tap + to add one. Pull down to refresh.")
- Positioned ~25% from top of screen

### 5.3 Loading States
- `CircularProgressIndicator()` centered — for full-screen async loads
- 20×20 `CircularProgressIndicator(strokeWidth: 2)` inside buttons while saving

### 5.4 Error/Status Banners (Inline)
Used in login, register, and category screens:
```
Material widget:
  color: errorContainer (errors) / secondaryContainer (status)
  borderRadius: 8px
  padding: 12px
  Text: themed color (onErrorContainer / onSecondaryContainer)
```

### 5.5 Confirmation Dialogs
Standard pattern used throughout:
```
AlertDialog
  title: "Action name?"
  content: "Explanation text."
  actions:
    TextButton "Cancel" — pops false
    FilledButton "Confirm/Delete/Save" — pops true
```

### 5.6 PopupMenuButton (Context Menus)
Used on list items (expenses, subscriptions, categories):
- Position: trailing end of ListTile
- Items: "Edit" + "Delete" (+ conditional items like "Mark as paid" for trial subs)
- Tapping the ListTile itself also opens the editor

### 5.7 Bottom Sheets
Used for:
- Receipt OCR source selection (camera / gallery)
- Amount confirmation (detected OCR amounts)
- Icon picker (in category edit)
- Color picker (in category edit)

All use `showModalBottomSheet` with `showDragHandle: true`

### 5.8 Section Cards (Settings pattern)
Settings screen and Profile screen use **Cards containing grouped ListTiles**:
```
Card {
  Column {
    ListTile or SwitchListTile
    Divider(height: 1)
    ListTile or SwitchListTile
    ...
  }
}
```

---

## 6. Data Models Summary

| Model | Key Fields | Notes |
|-------|-----------|-------|
| **Expense** | amount, currency, categoryId, occurredAt, isRecurring, note | Supports OCR auto-fill |
| **Subscription** | name, amount, currency, cycle, nextBillingDate, isTrial, trialEndsAt | Cycle: monthly/annual/custom |
| **Category** | name, description, iconKey, color | Database-backed icon + color catalog |

**Currencies supported:** LKR (Sri Lankan Rupee), USD, EUR

---

## 7. Navigation Flow Map

```
App Launch
  └─→ [Splash Screen: 3s]
        ├─→ [Login Screen]  (not authenticated)
        │    ├─→ [Register Screen]
        │    └─→ [Shell Screen] (on success / guest mode)
        └─→ [Shell Screen]  (already authenticated / guest)

Shell Screen (tabs: Expenses | Subscriptions | Insights)
  ├─→ [Add/Edit Expense Screen]     (FAB or list item tap/edit)
  ├─→ [Add/Edit Subscription Screen] (FAB or list item tap/edit)
  └─→ Drawer →
        ├─→ [Manage Categories Screen]
        │    └─→ [Edit/New Category Screen]
        └─→ [Settings Screen]
              ├─→ [Account Profile Screen]
              ├─→ [Reminder Diagnostics Screen]
              ├─→ [Sync Incident Screen]
              └─→ [Activity Log Screen]
```

---

## 8. Key UX Behaviors & Notes

### 8.1 Local-First Architecture
- All operations complete **immediately locally** — no network wait
- Cloud sync runs in background (signed-in mode only)
- Offline banner shown when signed-in but network unavailable
- Pull-to-refresh triggers manual data + FX rate refresh

### 8.2 Reminder System
- Reminders are synced every 2 minutes in background
- Also synced when: user adds/edits/deletes expense or subscription
- Also synced when: app resumes from background
- Three toggles: global on/off, subscription reminders, recurring expense reminders

### 8.3 Currency Handling
- User picks a **preferred currency** during registration (LKR/USD/EUR)
- Lists show amounts converted to preferred currency when FX rates available
- Falls back to original currency if conversion unavailable
- Insights currency breakdown shows **native totals** (not converted) to preserve accuracy

### 8.4 Trial Subscription Lifecycle
1. Mark subscription as "Trial" with optional trial end date
2. Trial counter card shows at top of subscription list
3. "Mark as paid" context menu option → confirmation dialog → converts to paid subscription
4. Activity log records the conversion
5. Insights trial/expired trial counters update

### 8.5 Receipt OCR
- Camera or gallery source selection
- Extracts amounts from receipt image using ML Kit
- Shows up to 3 candidate amounts with source text for user selection
- Auto-populates note field from detected text if note is empty

### 8.6 Category System
- Default starter categories seeded: Food, Utilities, Development
- Custom categories: name + optional description + optional icon (catalog) + optional color (catalog)
- Icons: Material Icons subset, searchable by label or key
- Colors: predefined theme-aware color options (resolved against current theme)
- Deleting a category shows affected expenses as "Uncategorized"

### 8.7 Responsive Behavior
- Breakpoint: desktop width (`isDesktopWidth` function)
- Mobile: bottom NavigationBar + drawer
- Desktop: NavigationRail (left sidebar) + no drawer
- Content: `ResponsiveBody` constrains max width and centers content

---

## 9. Known Design Limitations (Current Version)

These are areas where the current design is functional but minimal, and the new design could significantly improve:

1. **No custom typography** — uses default system fonts only
2. **No data visualization richness** — trend chart is custom-drawn but basic; no animated transitions
3. **Plain list items** — expenses and subscriptions use standard `ListTile` without custom card design
4. **No dark/light mode toggle in-app** — forced dark mode, no user control
5. **No avatar/profile picture** — profile shows generic person_outline icon only
6. **No onboarding flow** — first-time users land directly on login
7. **Limited currency support** — only LKR, USD, EUR available
8. **Settings screen density** — functional but dense, could benefit from more visual hierarchy
9. **No filter/search** — no way to filter or search expenses/subscriptions list
10. **Status banner always visible** — takes persistent space even when not critical info

---

*Document generated April 2026 from VaultSpend v1.5.22 source code.*
