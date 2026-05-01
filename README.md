# Bite

Personal health agent — iOS app + Cloudflare Worker backend. Monorepo.

## Repository layout

```
Bite/                         (this repo)
├── Bite/                     ← iOS app source (SwiftUI)
├── BiteTests/                ← iOS unit tests
├── BiteUITests/              ← iOS UI tests
├── BiteWidgets/              ← Home Screen widgets
├── Bite.xcodeproj/           ← Xcode project
├── Info.plist                ← iOS Info.plist
│
├── worker/                   ← Cloudflare Worker backend (TypeScript, drizzle, wrangler)
│
├── design-source/            ← Source PNG/PDF files used as input for asset generation
│                               (raw exports from Procreate/Figma — committed for reproducibility)
│
├── docs/                     ← Internal documentation
│   └── superpowers/
│       └── specs/            ← Design specs for major changes
│
├── README.md                 ← (this file)
├── SETUP.md                  ← Developer onboarding instructions
└── .gitignore
```

### Why iOS source lives at the repo root

Xcode projects use file paths relative to `.xcodeproj`. Moving the iOS code into `apps/ios/`
would require updating every reference inside `Bite.xcodeproj/project.pbxproj` and risks
breaking schemes, build settings, and IDE state. Pragmatic decision: iOS at root, other
apps as siblings (`worker/`, future `web/`). When the repo grows enough to justify the
refactor, we'll restructure into `apps/*`.

## Apps

### iOS app (`Bite/`, `BiteWidgets/`)

SwiftUI app targeting iOS 18+. Uses SwiftData for local persistence, HealthKit for
biometrics, and talks to the Cloudflare Worker for AI/coach features.

Open `Bite.xcodeproj` in Xcode. See [`SETUP.md`](./SETUP.md) for environment setup.

### Worker (`worker/`)

Cloudflare Worker (TypeScript) providing:

- Auth (JWT)
- AI/coach proxy
- Drizzle ORM over D1 / Postgres

```bash
cd worker
npm install
npx wrangler dev
```

Tests: `npm run test` (Vitest).

## Documentation

- [`docs/superpowers/specs/`](./docs/superpowers/specs) — design specs for major changes
- [`SETUP.md`](./SETUP.md) — developer environment setup

## Conventions

- **Branches:** feature work in `feature/*`, bugfixes in `fix/*`, design overhauls in `design/*`.
- **Specs first:** any change touching multiple components or design language ships with a
  spec doc in `docs/superpowers/specs/` before implementation.
- **English UI copy:** all user-facing strings are English. Italian raw values exist in
  some `Codable` enums for back-compat — use `.displayName` accessors in views, never
  `.rawValue`.
- **Asset format:** mascot/illustrations as PNG (transparent, ≥1024px); flat icons as
  PDF vectorial ("Single Scale + Preserve Vector Data").

## License

Private. All rights reserved.
