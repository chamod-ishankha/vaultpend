# VaultSpend 5-Point Feature Update Plan (Cost-Free Edition)

Since this is a personal test app and you want to **avoid all paid services and credit card requirements (Blaze Plan)**, I have heavily revised the plan to utilize 100% free, built-in strategies. 

## User Review Required

> [!TIP]
> **Avatar Firebase Persistence (Free)**
> *Firebase Storage actually has a free tier (5GB), but requires more setup.* Instead of using that, I strongly recommend we revert to my original plan: **Base64 String Persistence**. 
> We will heavily compress the chosen avatar down to a tiny 100x100 image, convert it into a simple text string (Base64), and save it directly into the existing Firestore free database alongside your `preferred_currency`. It's 100% free, requires zero setup on your end, and easily fits within limits! 

> [!WARNING]
> **The Problem with Server-Side Search on Free Tier**
> You cannot install the Algolia extension without upgrading your Firebase to the explicit "Pay-as-you-go" (Blaze) plan requiring a credit card.
> Because of this, I strongly recommend we use **Local Filtering Search** instead of Server-Side. Since this is a personal test app, your dataset is small. Fetching the records to your phone and using standard `.contains()` logic gives you **true, flawless full-text search** for absolutely free, without wrestling with Firebase limitations. Are you okay with me building Local Search?

---

## Proposed Changes

### 1. Profile State Orchestration (Zero-Cost Avatars)

#### [MODIFY] `lib/features/auth/auth_session.dart`
- Extend `AuthUser` data model to accept `photoBase64` payload.

#### [MODIFY] `lib/features/auth/auth_providers.dart`
- Intercept and sync `photo_base64` natively within the existing user settings firestore read.
- Add `updateProfileBase64(String encoded)` action to mutate the active session and persist into the Firestore database `users/{uid}/settings/profile` doc.

### 2. Global Avatar Resolution & Interactions

#### [MODIFY] `lib/features/home/shell_screen.dart`
- Provide `photoBase64` downstream to child navbar widgets.
- Route `onAvatarTap` to navigate to `ProfileUpdateScreen`.
- Replace `AnimatedSwitcher` with `PageView` using standard kinetic scrolling physics.
- Sync `onPageChanged` back into `_index` state to trigger bottom/desktop rail updates.

#### [MODIFY] `lib/features/home/widgets/shell_sidebar_drawer.dart`
- Swap the placeholder `Icon` for `MemoryImage(base64Decode(photoBase64))` when available.

#### [MODIFY] `lib/features/settings/profile_update_screen.dart`
- Import `image_picker`. 
- Bind an `InkWell` to the avatar graphic triggering `pickImage()`.
- **CRITICAL**: Enforce `maxWidth: 150, maxHeight: 150, imageQuality: 50` on the picker to guarantee the resulting Base64 string is only ~5-10KB (Firestore limit is 1,000KB).

### 3. Expandable Local Full-Text Search

#### [MODIFY] `lib/features/expenses/expense_list_screen.dart` & `lib/features/subscriptions/subscription_list_screen.dart` & `lib/features/categories/manage_categories_screen.dart`
- Inject an expandable inline Search `TextField` integrated tightly into the ObsidianAppBar `actions`.
- Convert the native list `builder` to intercept a locally managed `_searchQuery` string state.
- Apply `.where((item) => item.title.toLowerCase().contains(_searchQuery))` to achieve true full-text search without database extension requests.

### 4. Insights Dashboard Upgrades

#### [MODIFY] `lib/features/insights/insights_screen.dart`
- Inject `<FxReferenceStrip>` module at the top of the `ResponsiveBody` content tree exactly identically to the expense and subscription screens to align parity.

---

## Verification Plan
### Manual Verification
- You will test the new PageView by dragging across the body of the application to navigate pages fluidly.
- Select an avatar photo. The app will compress it, convert it to string text, and save it to Firestore completely for free. Validate it loads on reboot.
- Type into the new Search bars. Validate that words inside the *middle* of titles match flawlessly because of the Local Filtering methodology.
