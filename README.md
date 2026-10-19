# Altdock

Productivity-focused MacOS Dock alternative for the AI era.

Altdock is a native macOS menu-bar app with a floating, translucent dock. It shows **only apps with on-screen windows in the active Space on the selected display**—not every running app.

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
```

`--list-current-space` prints the detected process IDs and app names without opening the dock. The test script uses Swift Testing and handles the Testing macro-plugin location in newer Command Line Tools. Test-host requirements depend on your toolchain; recent Testing frameworks require macOS 14+.

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

The implementation uses public APIs: `CGWindowListCopyWindowInfo`, `NSWorkspace` notifications, and an `NSPanel` that joins Spaces. It does not use private SkyLight/CGS APIs, take screenshots, inspect window titles, or send data over the network.

- Only normal-layer, nontransparent windows belonging to regular applications qualify. Finder appears only when it has a qualifying window, not merely because its desktop is visible.
- Apps with **only minimized windows**, hidden apps, and apps without windows are omitted. Public window-list APIs do not reliably expose those windows’ Space membership. This is an intentional limitation of this first version, not full parity with Apple’s Dock.
- “Current Space” is scoped to the **selected display**. Apps visible only on another display are omitted. A window spanning displays can qualify on either. Windows assigned to all desktops qualify wherever visible.
- Window-list “on-screen” status is supplied by macOS, not a pixel-visibility test; a window covered by another window can still qualify. Stage Manager and Mission Control may affect the list during transitions.
- Space changes refresh after a short settling delay. App lifecycle events refresh immediately; window open/close/move/minimize changes are detected by a 0.75-second polling timer.
- **Screen Recording is not requested.** Basic filtering uses process IDs and window geometry, not protected window titles or images.
- **Accessibility is optional.** “Enable Precise Window Switching…” opens the permission settings. When granted, Altdock tries to raise a current-display window by matching its geometry before activating its app. Without it—or when an app does not expose a matching accessible window—macOS chooses the window and may switch Spaces. Identically positioned windows across Spaces can also make matching ambiguous.
- The panel is configured to accompany full-screen Spaces, but macOS can suppress auxiliary panels in some full-screen apps. Full-screen and multi-monitor behavior should be verified on your setup.

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
