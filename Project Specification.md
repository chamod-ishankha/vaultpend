# VaultSpend Project Specification

Version: 1.5.0
Date: 2026-04-04
Status: In Progress
Platform Scope: Android + iOS (mobile-only)

## 1. Product Goal
VaultSpend is a personal finance app focused on:
- Fast expense/subscription tracking
- Reliable local-first behavior
- Optional Cloud sync when signed in
- Clear reminders and actionable insights

## 2. Architecture Baseline
- Frontend: Flutter + Riverpod
- Local persistence: Isar
- Cloud: Firebase Auth + Cloud Firestore
- Export: CSV + PDF via share sheet
- Notifications: flutter_local_notifications with diagnostic tooling

## 3. Phase Progress Matrix

### Phase 1: Foundation & Data Model
Completion: 100%
- Done: app scaffolding, domain models, local persistence, repository patterns
- Done: category/expense/subscription CRUD flows

### Phase 2: Auth, Sync, and Reliability
Completion: 97%
- Done: Firebase Auth (email/password)
- Done: Firestore sync paths under users/{uid}
- Done: owner-scoped rules and schema-aware validation
- Done: guest mode support with local-only behavior
- Done: sync status indicators and conflict-safe update behavior
- Remaining:
  - Add per-entity conflict trend charts in diagnostics (optional)

### Phase 3: Reporting, Exports, and Insights
Completion: 92%
- Done: Expenses CSV/PDF exports
- Done: Subscriptions CSV/PDF exports
- Done: Insights CSV/PDF exports
- Done: Insights dashboard with:
  - range selector (7D/30D/90D/All)
  - trend line chart
  - category distribution
  - expense/subscription currency splits
  - largest subscriptions
  - recent activity
  - month-over-month comparison with directional indicators
  - upcoming billing forecasting and trial/billing status cues
- Remaining:
  - Add saved/preset insight report views (for reusable reporting slices)
  - Add richer "time remaining" labels consistently where pending triggers are shown

### Phase 4: Reminder Intelligence & Trial Operations
Completion: 92%
- Done: global + per-type reminder toggles
- Done: managed reminder scheduling and diagnostics screen
- Done: human-readable pending reminder parsing (subscription + recurring)
- Done: trial monitoring visibility across subscriptions and insights
- Done: explicit "mark trial as paid" flow with confirmation
- Done: activity log entries for critical user actions
- Remaining:
  - Add optional notification reliability counters in diagnostics (advanced breakdown)

### Phase 5: UX Polish & Operational Readiness
Completion: 100%
- Done: branding asset integration (logo/icon/splash)
- Done: Cloud wording consistency in major user-facing auth UX
- Done: activity log screen with clear history and reset
- Done: consistency pass on auth/list empty states (spacing, density, alignment)
- Done: reminder scheduling scenario test coverage (bucket selection + monthly rollover)
- Done: release checklist section with device-level reminder and sync validation steps

## 4. Overall Completion
Estimated overall completion: 97%

Computation basis:
- Weighted average across phases with higher weight on Phases 2-4 (core product behavior)
- Includes implemented code, not only planned/spec statements

## 5. Current Confirmed Capabilities
- Mobile app runs with Firebase initialized and Isar local store
- Guest mode and signed-in mode both functional on mobile
- Expense/subscription CRUD and sync flows active
- Reminder diagnostics available from shell navigation
- Activity log available from shell navigation
- Export menus available on Expenses, Subscriptions, and Insights

## 6. Remaining Backlog (Priority Ordered)
1. Optional diagnostics enhancements (trend visualization + advanced counters)

## 7. Immediate Next Development Item
Implement backlog item #1 now:
- Add optional diagnostics enhancements (trend visualization + advanced counters)

## 8. Release Checklist (Device-Level)
- Build and smoke-test Android and iOS release candidates on physical devices.
- Verify offline-first behavior:
  - Enable airplane mode.
  - Create/update/delete one expense and one subscription.
  - Confirm data persists after app restart.
- Verify reminder scheduling end-to-end:
  - Enable global reminders and both reminder types.
  - Create one subscription due within 24 hours and one recurring expense due within 24 hours.
  - Open Reminder Diagnostics and confirm pending reminder entries are present.
  - Confirm expected vs pending counters match.
- Verify reminder cancellation paths:
  - Disable subscription reminders and confirm subscription pending reminders are removed.
  - Disable recurring reminders and confirm recurring pending reminders are removed.
  - Re-enable toggles and confirm reminders are re-scheduled.
- Verify trial lifecycle:
  - Mark a trial subscription as paid and confirm activity log entry.
  - Confirm trial indicators are removed from Insights and subscription badges.
- Verify Cloud sync behavior (signed-in mode):
  - Sign in on Device A and Device B with the same account.
  - Create/update/delete records on Device A and confirm propagation to Device B.
  - Temporarily disable network on one device, make changes, re-enable network, and verify eventual sync.
- Verify export flows:
  - Export CSV and PDF from Expenses, Subscriptions, and Insights.
  - Confirm files open correctly from share targets.
- Verify diagnostics and operational visibility:
  - Confirm Recent sync incidents section loads and shows failures when sync is intentionally interrupted.
  - Confirm Activity Log includes key user operations and can be cleared.

