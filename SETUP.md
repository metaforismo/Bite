# Bite — environment setup

Three blockers exist between this codebase and a clean `xcodebuild build_sim`.
None are code bugs; all need one-time Xcode UI / wrangler steps.

## 1. Install the iOS 26.4 simulator runtime

Xcode 26.4.1 ships SDK iOS 26.4 but only iOS 26.2 simulator runtime is
installed. `actool` (asset-catalog compiler) refuses the version mismatch.

- Open Xcode → **Settings → Components**.
- Search "iOS 26.4" → **Get**.
- Wait ~10 minutes for the multi-GB download to finish.

Confirm with:

```bash
xcrun simctl list runtimes | grep 26.4
```

You should see something like `iOS 26.4 (26.4 - 23E…) - …`.

## 2. Add the BiteWidgets extension target

The widget Swift sources live in `/BiteWidgets/` but Xcode cannot auto-add
extension targets (synchronized folders only handle source file inclusion in
existing targets, not target creation).

1. Open `Bite.xcodeproj` in Xcode.
2. **File → New → Target…** → choose **Widget Extension** under iOS.
3. Name it exactly `BiteWidgets`. Embed in `Bite`. Uncheck "Include Live Activity".
4. After Xcode creates the target, **delete** the boilerplate Swift files it
   added (the `BiteWidgets/BiteWidgets.swift` template, etc.).
5. Right-click the new `BiteWidgets` group → **Add Files to "Bite"…** → select
   every `.swift` file under `/BiteWidgets/` (Bundle, SnapshotProvider, all 5
   widgets). Confirm **Target Membership** is `BiteWidgets` only.
6. Select `Bite/Services/WidgetSnapshotService.swift` in the navigator. In the
   File Inspector → **Target Membership** → also check `BiteWidgets` (the
   widget extension needs to read the `BiteWidgetSnapshot` struct).
7. Select the `BiteWidgets` target → **Signing & Capabilities** → `+ Capability
   → App Groups` → add `group.com.bite.health` (must match `Bite.entitlements`).
8. Build the widget scheme: **Product → Scheme → BiteWidgets**, then ⌘B.

Verify from CLI:

```bash
xcodebuild -project Bite.xcodeproj -target BiteWidgets -sdk iphonesimulator build CODE_SIGNING_ALLOWED=NO
```

## 3. Set the production API base URL

`Bite/Services/Coach/BiteAPIConfig.swift` reads `BITE_API_BASE_URL` from
`Info.plist`. Default in source is `http://localhost:8787` (local Wrangler dev).

For TestFlight/Release:

- Xcode → select Bite target → **Info** tab.
- Edit the `BITE_API_BASE_URL` row → set to your deployed Worker URL,
  e.g. `https://bite-worker.<your-account>.workers.dev`.
- Or use a per-scheme `.xcconfig` so Debug stays on localhost and
  Release/TestFlight points at production.

## 4. Worker provisioning

Backend resources are listed in `worker/wrangler.toml`. First-time setup:

```bash
cd worker
pnpm install
wrangler login
wrangler d1 create bite_db                           # paste the id into wrangler.toml
wrangler vectorize create bite-memories --dimensions=1536 --metric=cosine
wrangler vectorize create bite-files    --dimensions=1536 --metric=cosine
wrangler r2 bucket create bite-files
wrangler secret put OPENROUTER_API_KEY
wrangler secret put FIREBASE_PROJECT_ID
wrangler secret put FIREBASE_CLIENT_EMAIL
wrangler secret put FIREBASE_PRIVATE_KEY              # paste the multi-line PEM
wrangler secret put FILE_ENCRYPTION_MASTER_KEY        # 32-byte hex
pnpm db:migrate:remote
pnpm deploy
```

For local dev:

```bash
pnpm dev   # starts on :8787 — matches the iOS Info.plist default
```

## 5. Firebase iOS SDK

In Xcode: **File → Add Package Dependencies…** →
`https://github.com/firebase/firebase-ios-sdk`. Check `FirebaseAuth` and
`FirebaseAppCheck`. Drop your `GoogleService-Info.plist` into the `Bite/`
group (keep it out of the widget extension target).

The `#if canImport(FirebaseAuth)` paths in
`Bite/Services/Coach/AuthService.swift` activate automatically.
