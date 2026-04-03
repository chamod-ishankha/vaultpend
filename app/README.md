# VaultSpend (Flutter App)

VaultSpend is an offline-first personal finance app with optional Firebase sync.

## Stack

- Flutter + Riverpod
- Isar (local-first persistence)
- Firebase Auth (email/password)
- Cloud Firestore (`users/{uid}/categories|expenses|subscriptions`)

## Local Development

From the `app/` directory:

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

## Firebase Deploy Checklist

1. Confirm Firebase project alias is correct in `.firebaserc`.
2. Verify Firestore configuration in `firebase.json`:
	- `firestore.rules` points to `firestore.rules`
	- `firestore.indexes` points to `firestore.indexes.json`
3. Ensure generated Flutter config exists at `lib/firebase_options.dart`.
4. Review current rules and indexes before deploy:
	- `firebase firestore:rules:get`
	- `firebase firestore:indexes`
5. Deploy rules and indexes:

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

6. Validate in Firebase Console:
	- Rules are active for the expected project.
	- Index build status is complete (if new indexes were added).
7. Run app smoke checks after deploy:
	- Sign in and verify category sync.
	- Create/edit/delete an expense and confirm no duplicate document is created.
	- Create/edit/delete a subscription and verify updates persist across refresh.

## Notes

- Guest mode remains available when signed out; cloud sync is disabled in that mode.
- Security rules enforce owner-only access and schema/type validation for synced entities.
