# Sizzle 🍳

A Firebase-powered recipe app built with Flutter for **Lab 6**. Discover recipes,
cook them hands-free, and make them your own.

## Features

- **Auth** — email/password sign-in, registration, forgot-password, and a
  first-launch onboarding flow.
- **Recipes (full CRUD)** — create, read, update, and delete, backed by Cloud
  Firestore, with cover-image upload to Firebase Storage.
- **Discovery** — search, category filters, and sorting (newest / quickest /
  most-saved / top-rated).
- **Cook** — a hands-free Cooking Mode with per-step timers, an ingredient
  checklist, and a serving scaler.
- **Organise** — favorites, custom collections, private per-recipe notes, and a
  synced shopping list.
- **Social touches** — per-user star ratings, recipes attributed to their author,
  and shareable recipes (text or PDF).

## Tech

Flutter · Riverpod · Firebase (Auth, Cloud Firestore, Storage) · Material 3.

## Getting started

```bash
flutter pub get
flutter run
```

Requires a Firebase project (config in `lib/firebase_options.dart`). Firestore
offline persistence is enabled, so the app keeps working from its local cache
when the device is offline.

## Builds

CI (GitHub Actions, see `.github/workflows/build.yml`) builds a release **APK**
and an unsigned **iOS** app on every push to `main`; both are attached to the run
as downloadable artifacts. A signed, installable iOS `.ipa` additionally requires
an Apple Developer account.

## Test accounts

| Chef | Email | Password |
| --- | --- | --- |
| Chef Alex | `try@gmail.com` | `password123` |
| Chef Maya | `maya.sizzle@gmail.com` | `password123` |
| Chef Liam | `liam.sizzle@gmail.com` | `password123` |
