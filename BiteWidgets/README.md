# BiteWidgets — manual setup required

This folder contains the WidgetKit extension's Swift source. Xcode 16 does
**not** auto-create extension targets via synchronized folders — adding the
extension is a one-time manual step in Xcode:

## 1. Add the extension target

1. In Xcode: `File → New → Target…`
2. Pick **Widget Extension**, name it `BiteWidgets`, parent app `Bite`.
3. Uncheck "Include Live Activity" (not needed for V2).
4. After creation, delete the default boilerplate files Xcode dropped in;
   they'll be replaced by the files in this folder.

## 2. Wire the source files

1. Right-click the new `BiteWidgets` group → `Add Files to "Bite"…`
2. Select all `.swift` files under this `BiteWidgets/` folder.
3. Confirm `Target Membership` includes only the `BiteWidgets` target.

## 3. Add the App Group entitlement

1. Select the `BiteWidgets` target → **Signing & Capabilities**.
2. `+ Capability → App Groups`.
3. Add `group.com.bite.health` (must match the main app's entitlement).

## 4. Add the shared snapshot file

`BiteWidgets/Shared/BiteWidgetSnapshot.swift` is a **symlink** to the
main-app file in `Bite/Services/WidgetSnapshotService.swift`. Xcode
projects can't symlink files inside the project, so instead **add the
main-app file as a reference** to the BiteWidgets target's Compile
Sources phase:

1. In `Bite/Services/WidgetSnapshotService.swift`, file inspector →
   **Target Membership** → also check `BiteWidgets`.

(The `BiteWidgetSnapshot` struct gracefully handles the missing
App-Group container in dev — widgets render the empty snapshot.)

## 5. Verify

`xcodebuild -target BiteWidgets -sdk iphonesimulator build` should succeed
once the iOS 26.4 simulator runtime is installed.
