# Altdock

Productivity-focused MacOS Dock alternative for the AI era.

Altdock is a native macOS menu-bar app with a floating, translucent dock. It shows **apps with windows assigned to the active Space on the selected display**—not every running app. Window membership is cached across all Spaces so switching does not clear and reload the dock.

## Build and run

Requires macOS 13+ and a Swift 6+ toolchain (Xcode or Command Line Tools). No third-party dependencies.

```sh
./scripts/build-app.sh
open dist/Altdock.app
```

The script creates a release `.app` bundle with an icon and an ad-hoc signature. For everyday use, copy `dist/Altdock.app` to `/Applications` and launch that copy. Enable **Launch at Login** from Altdock’s menu only after putting it in its permanent location.

For development:

```sh
swift run Altdock
./scripts/test.sh
swift run Altdock --list-current-space
swift run Altdock --list-spaces
swift run Altdock --public-windows --list-spaces
```

`--list-current-space` prints the detected process IDs and app names without opening the dock. `--list-spaces` reports the discovery backend, scan time, active Space, and cached apps across all Spaces. `--public-windows` forces on-screen-only discovery for troubleshooting; it can also be passed when launching the app. The menu reports the current backend.

The test script uses Swift Testing and handles the Testing macro-plugin location in newer Command Line Tools. Test-host requirements depend on your toolchain; recent Testing frameworks require macOS 14+.

## Using Altdock

- **Click** an icon to activate the app. Hover to magnify it and see its name.
- **Right-click** for Open, Hide, or Quit. Quit uses the app’s normal termination flow, not force-quit.
- The dot beneath each icon indicates a running app; the wider indicator marks the frontmost app.
- The **menu-bar icon** controls dock visibility, automatic hiding, icon size, display selection, and launch at login.
- With **Automatically Hide** enabled, move the pointer to the bottom edge beneath the dock to reveal it.
- Icons shrink to accommodate more apps; horizontal scrolling handles overflow.
- Appearance follows the system, with support for Reduce Motion, Reduce Transparency, and VoiceOver labels.

Altdock does **not** hide, replace, restart, or modify Apple’s Dock. It sits above the system Dock when that Dock reserves screen space. For a cleaner setup, manually enable **System Settings → Desktop & Dock → Automatically hide and show the Dock**. Both docks can respond to the same bottom edge; moving the system Dock to the left or right avoids that conflict.

## Space semantics and permissions

Altdock dynamically loads **private SkyLight APIs**: `SLSCopySpacesForWindows` maps windows to Spaces; `SLSCopyManagedDisplaySpaces` enumerates Spaces; `SLSCopyBestManagedDisplayForRect` and `SLSManagedDisplayGetCurrentSpace` identify the selected display’s active Space. `CGWindowListCopyWindowInfo(.optionAll)` supplies window metadata, including windows on inactive Spaces. No screenshots, window titles, or network access are used.

- Private APIs are undocumented and may break with macOS updates. Missing symbols or failed snapshot queries fall back to public on-screen discovery. Dynamic loading avoids a hard launch-time dependency, but cannot guarantee compatibility with a changed private ABI. This build is intended for direct distribution, not Mac App Store submission.
- Only normal-layer, nontransparent windows belonging to regular applications qualify. Windows with no reported Space membership are excluded. Finder appears only when it has a qualifying window, not merely because its desktop is visible.
- Hidden and minimized windows can qualify when WindowServer still returns their geometry and Space membership. Apps without qualifying windows remain omitted. The public fallback omits hidden and minimized windows because it only knows what is on-screen.
- “Current Space” is scoped to the **selected display** using both Space membership and window geometry. A window spanning displays can qualify on either if assigned to that display’s active Space. Windows assigned to several Spaces appear in each corresponding list.
- A 0.75-second timer and app lifecycle notifications reconcile the all-Spaces cache. A Space-change notification selects cached membership immediately, then schedules reconciliation. Existing icons are not cleared first, and their ordering is retained per Space. A newly created/unknown Space keeps the previous icons non-interactive until a snapshot is available; a known empty Space displays the empty state immediately. Caches can briefly lag window moves or closes until reconciliation.
- Public fallback transitions preserve the previous, non-interactive dock during a 0.4-second grace period, with short retries, rather than showing a misleading empty state. Full scans currently run on the main thread; large window counts may increase refresh cost.
- **Screen Recording is not requested.** Filtering uses process IDs, window geometry, and Space IDs—not protected window titles or images.
- **Accessibility is optional.** “Enable Precise Window Switching…” opens the permission settings. When granted, Altdock uses `_AXUIElementGetWindow` when available to match an accessible window by ID, unminimizes it, and raises it before activating the app. Geometry matching is a fallback if that symbol is unavailable. Without a usable accessible window, macOS chooses which window to activate and may switch Spaces; restoration of a particular minimized window is not guaranteed without Accessibility. Hidden apps are unhidden on activation. Clicks re-query membership to avoid acting on stale icons.
- The panel is configured to accompany full-screen Spaces, but macOS can suppress auxiliary panels in some full-screen apps. Full-screen, Stage Manager, and multi-monitor behavior should be verified on your setup.

## Project layout

```text
Sources/Altdock/       Native app, window discovery, activation, dock UI, and menu
Sources/AltdockCore/   Pure window filtering, stable ordering, and layout rules
Tests/                Swift Testing suites for filtering, ordering, and layout
Resources/Info.plist  Menu-bar app bundle metadata
scripts/              Build, icon generation, and test commands
```

See [PRODUCT.md](PRODUCT.md) for the product requirements and [TESTING.md](TESTING.md) for the manual acceptance checklist.

## Signing and distribution

The default ad-hoc signature is for local development; the bundle is not notarized. You can select a signing identity with `CODE_SIGN_IDENTITY="Developer ID Application: …" ./scripts/build-app.sh`, but public distribution still needs an appropriate signing/notarization workflow. Rebuilding an ad-hoc signed app can require re-granting Accessibility access. No login item is registered until explicitly enabled from the menu.

## API references

- [CGWindowListCopyWindowInfo](https://developer.apple.com/documentation/coregraphics/cgwindowlistcopywindowinfo(_:_:))
- [On-screen window lists](https://developer.apple.com/documentation/coregraphics/cgwindowlistoption/optiononscreenonly)
- [Active Space notifications](https://developer.apple.com/documentation/appkit/nsworkspace/activespacedidchangenotification)
- [Window collection behavior](https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct)
- [yabai’s private API declarations](https://github.com/koekeishiya/yabai/blob/master/src/misc/extern.h)
- [yabai’s window-to-Space queries](https://github.com/koekeishiya/yabai/blob/master/src/window.c)
