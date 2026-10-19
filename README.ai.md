# Altdock

Productivity-focused MacOS Dock alternative for the AI era.

Altdock is a native macOS menu-bar app with translucent dock panels. It shows **apps with windows assigned to the active Space on the selected display**—not every running app. By default it preloads one persistent panel per Space, so the outgoing dock does not have to change its icons and size into the incoming dock.

## Build and run

Requires macOS 13+ and a Swift 6+ toolchain (Xcode or Command Line Tools). No third-party dependencies.

```sh
./scripts/build-app.sh
open dist/Altdock.app
```

The script creates a release `.app` bundle signed with the **Altdock** identity in your login Keychain. If that identity is missing or ambiguous, the build fails rather than silently falling back to ad-hoc signing. **Quit Altdock before rebuilding or replacing its bundle.** For everyday use, copy `dist/Altdock.app` to `/Applications` and launch that copy. Enable **Launch at Login** only after placing it in its permanent location.

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

- **Click** an icon to activate the app. Hover to see its name; icons keep the captured native size rather than using Altdock-specific magnification.
- **Right-click** for Open, Hide, or Quit. Quit uses the app’s normal termination flow, not force-quit.
- Icons are vertically centered in bottom docks and horizontally centered in side docks. The running indicator is drawn separately, centered in the gap between the icon's image bounds and the dock's screen-facing border, so it cannot shift the icon. A wider indicator marks the frontmost app.
- The **menu-bar icon** controls dock visibility, automatic hiding, space reservation, display selection, and launch at login, and reports the captured native edge and icon size.
- With **Automatically Hide** enabled, move the pointer to the corresponding bottom, left, or right screen edge to reveal Altdock.
- Icons retain the native base size. Horizontal or vertical scrolling handles overflow instead of shrinking them.
- Appearance follows the system, with support for Reduce Motion, Reduce Transparency, and VoiceOver labels.

## Matching the native Dock

Before parking the system Dock, Altdock captures its original **bottom/left/right edge**, **base icon size**, and **edge footprint**. That snapshot drives every Space's panel. The bar's length still fits that Space's apps; it does not keep empty space merely to match the native Dock's full app list.

Altdock no longer uses its own Small/Medium/Large presets. Change the native Dock's size while Altdock is quit, then launch Altdock to capture it. The old Altdock `iconSize` preference is ignored. A crash/relaunch reuses the saved original appearance rather than copying the temporarily parked Dock's edge.

A native 64-point icon and 90-point edge footprint produce an 82-point visible panel plus an 8-point screen-edge margin. The former implementation used a 93-point panel plus the margin, unnecessarily consuming 11 extra points. Fixed-size hover feedback replaces the previous icon enlargement so it needs no additional permanent headroom.

Native metrics use read-only CoreDock queries and the `tilesize` preference. When native geometry is unavailable (for example, an already auto-hidden or magnified Dock), thickness falls back to the calibrated icon-size-plus-26-point footprint. This mirrors the base size and footprint, not every private macOS rendering detail or magnification animation.

## Persistent panels per Space — prototype

- Each known Space on the selected display gets a separate `NSPanel`, SwiftUI hosting view, and presentation state, including inactive/empty Spaces. One shared model still does window discovery; this is not a separate scan/timer per Space.
- Panels use managed, Space-bound collection behavior rather than `canJoinAllSpaces`/`stationary`. macOS controls their visibility as desktops move. In always-visible mode, inactive panels remain **ordered in their own Spaces**, not moved onto or shown over the active desktop.
- `SLSMoveWindowsToManagedSpace` is dynamically loaded to attach **only Altdock-owned panels**. Creation occurs at zero opacity; membership must read back as exactly the destination Space before a panel can be shown. Altdock does not move other applications' windows between Spaces or programmatically switch desktops.
- Panels sit **8 points inside the original bottom, left, or right display edge**, not inside the system Dock's stale work-area inset. The non-docked axis is centered in the visible work area.
- Switching Spaces updates focus/visibility, not panel membership, root hosting views, or frame sizes. Membership changes within a Space can still change that Space's dock size. Display changes rebuild the relevant panels, deleted Spaces close theirs, and quit closes all panels.
- Auto-hide remains available; only the active panel responds to the reveal edge. Inactive panels are hidden in auto-hide mode. Hide Altdock hides every panel.
- If all-Spaces data or placement is unavailable, a shared panel is used as a compatibility fallback. A failed placement is closed invisibly and is not repeatedly retried; recreating the Space/display or relaunching retries it. The menu reports the active presentation mode. Full-screen Spaces and multi-display arrangements still require hands-on testing; membership verification alone does not prove native animation/visibility in every macOS configuration.

To inspect the running app's panel IDs, assigned Spaces, frames, app PIDs, and ordering state:

```sh
dist/Altdock.app/Contents/MacOS/Altdock --panel-status
```

This reads `~/Library/Application Support/Altdock/panel-status.json` and does not start another dock or change preferences. For comparison, quit Altdock and relaunch the same binary in the old shared-panel mode:

```sh
open dist/Altdock.app --args --shared-panel
```

Quit and launch without that argument to return to per-Space panels. `--public-windows` also falls back to a shared panel because it cannot preload membership for inactive Spaces.

## Space reservation — on by default

Grant **Accessibility** through Altdock's menu if its status says access is missing. Startup only checks permission; it never automatically prompts. Explicit requests re-check the live grant and do nothing when permission is already granted. Altdock keeps maximized/edge-tiled windows clear of its captured edge. Bottom and right docks shorten the window; left docks shift its left edge inward while preserving its right edge. Reserve Space is already on, including for existing installations without a saved preference.

- This is Accessibility-based window adjustment, **not** a system-wide change to `NSScreen.visibleFrame`. Floating windows, dialogs, full-screen/minimized windows, non-resizable windows, and windows whose identity or attributes cannot be read safely are left alone.
- Clearance uses the captured native edge footprint plus a four-point gap, independently of the current app count. It does not add the system Dock's old inset twice. Windows aligned with either the reported work area or physical edge can qualify; already-clear windows are not expanded.
- AX events are coalesced for 150 ms, with three-second reconciliation for missed events. Window reads, observer registration, and writes run off the UI thread. App/window attribute access uses a 250 ms messaging timeout. An unsupported optional `AXFullScreen` flag does not disqualify a normal window; a failed read is still retried safely. Writable position is required only if the size change actually displaces the window.
- Resize verification allows up to eight observations, separated by 60 ms, for asynchronous window animations. Transient write failures receive bounded retries rather than permanent suppression after one attempt.
- The engine suppresses its own notifications and yields after repeated competing writes. A later user interaction followed by a new maximize/tile geometry change starts a fresh adjustment rather than exhausting a lifetime retry count. It reads only aggregate mouse/key event counts—not keystrokes or event contents—to distinguish new interaction from its own writes.
- Reservation pauses when **Automatically Hide** is on or Altdock is hidden. It does not resize windows on every edge reveal.
- On normal quit, hiding, disabling reservation, or changing display/clearance, Altdock attempts to restore only windows that still match its last adjustment. It never blindly restores windows the user has since moved. Window-frame restoration after force quit is not guaranteed.

## Diagnosing reservation and permission problems

While Altdock is running:

```sh
dist/Altdock.app/Contents/MacOS/Altdock --reservation-status
```

This reads `~/Library/Application Support/Altdock/reservation-status.json`, written by the **running app**, not the terminal's Accessibility identity. It includes the executable path/PID, last changed report timestamp, AX errors, window IDs/geometry, and adjustment or rejection reasons. It contains no window titles or content. The menu's **Reservation Diagnostics…** item reveals the file. Reports are updated when their contents change; a bounded scan may report only part of the current window list. This diagnostic does not change Dock preferences or request access.

A checked Altdock entry in System Settings can become stale after replacing an ad-hoc signed binary. If the running app reports missing access, remove and re-add the exact `.app` you are running under **Privacy & Security → Accessibility**, then enable it. Altdock polls for the grant without prompting; if macOS still reports it missing after updating the entry, quit and relaunch Altdock. Use a stable code-signing identity for development if you want grants to survive rebuilds reliably. Altdock does not reset TCC, alter security settings, or claim that a stored preference is equivalent to a live OS grant.

If access is granted but a particular app's `AXWindows` query fails, that app may need restarting; do not assume the checked Accessibility setting guarantees that every app exposes usable window information.

## Transitioning to and from the system Dock

On launch, Altdock saves the system Dock's exact **position** and **Automatically hide and show** setting, along with Altdock's appearance reference. It enables auto-hide and parks the system Dock on the **right** when its original edge was bottom/left, or at the **bottom** when its original edge was right. Altdock stays on the original edge. Only settings that need changing are written; no magnification, icon, size, animation, or delay preferences are changed. Restarting the system Dock to apply changes may cause a brief visual transition.

On quit, those two saved settings are restored, including removing keys that were originally absent. A lightweight helper process also restores them if the main Altdock process crashes or is force-quit. A session lock prevents a second instance from overwriting the original snapshot; a token prevents an old helper from restoring a newer session's settings.

The recovery record lives at `~/Library/Application Support/Altdock/system-dock.json`. If both the app and its helper are killed, or the Mac loses power, the next launch reuses that original record and restores it on exit. Do not delete the record while restoration is pending. A corrupt record causes startup to fail without replacing it. A valid record is removed only after restoration succeeds. No permanent recovery LaunchAgent is installed. Changes to these same two settings made manually while Altdock runs will also be replaced by the saved pre-launch values on exit.

The `--list-current-space` and `--list-spaces` diagnostics do not change Dock preferences or prompt for Accessibility.

## Space semantics and permissions

Altdock dynamically loads **private SkyLight APIs**: `SLSCopySpacesForWindows` maps windows to Spaces; `SLSCopyManagedDisplaySpaces` enumerates Spaces; `SLSCopyBestManagedDisplayForRect` and `SLSManagedDisplayGetCurrentSpace` identify the selected display’s active Space. `SLSMoveWindowsToManagedSpace` places Altdock's own panels. `CGWindowListCopyWindowInfo(.optionAll)` supplies window metadata, including windows on inactive Spaces. No screenshots, window titles, or network access are used.

- Private APIs are undocumented and may break with macOS updates. Missing symbols or failed snapshot queries fall back to public on-screen discovery. Dynamic loading avoids a hard launch-time dependency, but cannot guarantee compatibility with a changed private ABI. This build is intended for direct distribution, not Mac App Store submission.
- Only normal-layer, nontransparent windows belonging to regular applications qualify. Windows with no reported Space membership are excluded. Finder appears only when it has a qualifying window, not merely because its desktop is visible.
- Hidden and minimized windows can qualify when WindowServer still returns their geometry and Space membership. Apps without qualifying windows remain omitted. The public fallback omits hidden and minimized windows because it only knows what is on-screen.
- “Current Space” is scoped to the **selected display** using both Space membership and window geometry. A window spanning displays can qualify on either if assigned to that display’s active Space. Windows assigned to several Spaces appear in each corresponding list.
- A 0.75-second timer and app lifecycle notifications reconcile all-Spaces membership and presentations. Existing panel identities are retained across Space switches, with cached icon ordering per Space. Unknown/new Spaces use the existing compatibility path until discovery/placement succeeds; a confirmed empty Space has its own empty-state panel. Caches can briefly lag window moves or closes until reconciliation.
- Public fallback transitions preserve the previous, non-interactive dock during a 0.4-second grace period, with short retries, rather than showing a misleading empty state. Full scans currently run on the main thread; large window counts may increase refresh cost.
- **Screen Recording is not requested.** Filtering uses process IDs, window geometry, and Space IDs—not protected window titles or images.
- **Accessibility is required for space reservation and precise window control**, but the basic dock still works without it. “Grant Accessibility Access…” opens the permission settings. When granted, Altdock uses `_AXUIElementGetWindow` when available to match an accessible window by ID, unminimizes it, and raises it before activating the app. Activation can fall back to geometry matching; reservation does not resize geometrically ambiguous windows if exact identity is unavailable. Without a usable accessible window, macOS chooses which window to activate and may switch Spaces; restoration of a particular minimized window is not guaranteed without Accessibility. Hidden apps are unhidden on activation. Clicks re-query membership to avoid acting on stale icons.
- The panel is configured to accompany full-screen Spaces, but macOS can suppress auxiliary panels in some full-screen apps. Full-screen, Stage Manager, and multi-monitor behavior should be verified on your setup.

## Project layout

```text
Sources/Altdock/       Native app, window discovery, activation, dock UI, and menu
Sources/AltdockCore/   Pure window filtering, stable ordering, and layout rules
Tests/                Swift Testing suites for filtering, ordering, and layout
Resources/Info.plist  Menu-bar app bundle metadata
scripts/              Build, icon generation, and test commands
```

See [REQUIREMENTS.md](REQUIREMENTS.md) for the initial product requirements, [RESEARCH.ai.md](RESEARCH.ai.md) for the source review and engineering decisions, and [TESTING.md](TESTING.md) for the manual acceptance checklist.

## Signing and distribution

The default signer is a self-signed **Altdock** certificate and exportable RSA-3072 private key in the login Keychain. It has ten-year validity, code-signing/digital-signature usage, and user-domain code-signing-only trust—not TLS or system-wide trust. There is no separate private-key or `.p12` backup. To create/reuse it on a Mac:

```sh
swift -suppress-warnings scripts/create-signing-identity.swift --create
```

Approve any native Keychain/trust prompt locally. The helper reuses an existing identity and refuses ambiguous/partial identities instead of silently rotating keys. It keeps newly generated key material in memory and imports it into Keychain; it never writes a private-key backup. You can later export the certificate and private key as an encrypted `.p12` through Keychain Access when moving Macs.

Builds resolve this identity to its certificate fingerprint. The platform-generated designated requirement binds the app identifier to that certificate, so changing the binary does not change the signing identity. Switching from an old ad-hoc build to this certificate may require one final Accessibility approval; a new Mac still needs its own approval.

`CODE_SIGN_IDENTITY` and `CODE_SIGN_KEYCHAIN` can select another identity/keychain. Explicit `CODE_SIGN_IDENTITY=-` permits ad-hoc signing for disposable builds and prints a warning; it is never an automatic fallback. The local certificate is not Apple-issued and the app is not notarized; public distribution requires a separate Developer ID/notarization workflow. Login-item registration remains explicit.

## API references

- [CGWindowListCopyWindowInfo](https://developer.apple.com/documentation/coregraphics/cgwindowlistcopywindowinfo(_:_:))
- [On-screen window lists](https://developer.apple.com/documentation/coregraphics/cgwindowlistoption/optiononscreenonly)
- [Active Space notifications](https://developer.apple.com/documentation/appkit/nsworkspace/activespacedidchangenotification)
- [Window collection behavior](https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct)
- [yabai’s private API declarations](https://github.com/koekeishiya/yabai/blob/master/src/misc/extern.h)
- [yabai’s window-to-Space queries](https://github.com/koekeishiya/yabai/blob/master/src/window.c)
