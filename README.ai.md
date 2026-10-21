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

- **Click** an icon to activate the app or restore its selected minimized local window. If its eligible local window is already focused and not minimized, Altdock leaves that window focused instead of raising a sibling. Hover to see its full name immediately in a Dock-style label above a bottom dock or toward the desktop from a side dock. The label has fully rounded corners and uses a 13-point regular macOS system font. It measures the text using that font and expands horizontally on one line. Only a name wider than the available screen is ellipsized. It does not resize the dock or intercept clicks. Icons keep the captured native size rather than using Altdock-specific magnification.
- **Minimized windows** appear as separate window-shaped tiles after the app icons, with titles and app badges. The separator is centered in the gap between the app icon's visible artwork and the first window card, including on side docks. Click a tile (or right-click → Restore) to restore that exact window; its minimized siblings stay minimized. Hover to read its full title. Tiles use a lightweight representation, not live screenshots, and need no Screen Recording permission. Accessibility minimize/restore events trigger a prompt, coalesced refresh rather than waiting for the next periodic scan; this works independently of space reservation. They keep a stable order per Desktop and disappear when restored or closed; app-icon drag ordering does not rearrange them.
- **Drag an icon** left/right in a bottom dock, or up/down in a side dock, then release inside the panel to rearrange it. Neighboring icons preview the new order. Release outside the panel to cancel; a drag does not activate the app. Each Desktop retains its own order across discovery refreshes and Space switches during the current Altdock session, even if apps or the Space temporarily disappear from discovery. Remembered ordering never makes an absent app visible. Orders are not yet persisted across Altdock restarts. For an overflowing dock, scroll to expose the icons you want to rearrange; dragging does not auto-scroll.
- **Right-click** for Open, **New Window**, **Move Focused Window**, **Move**, Hide, or Quit. Both move menus list the other ordinary Desktops on the selected display in Mission Control order. Quit uses the app’s normal termination flow, not force-quit.
- Icons are vertically centered in bottom docks and horizontally centered in side docks. The running indicator is drawn separately, centered in the gap between the icon's image bounds and the dock's screen-facing border, so it cannot shift the icon. A wider indicator marks the frontmost app.
- The **menu-bar icon** controls dock visibility, automatic hiding, space reservation, display selection, and launch at login, and reports the captured native edge and icon size.
- With **Automatically Hide** enabled, move the pointer to the corresponding bottom, left, or right screen edge to reveal Altdock.
- Icons retain the native base size. Horizontal or vertical scrolling handles overflow instead of shrinking them.
- On the visible Space-bound dock, app additions/removals use a 240 ms ease-in/out scale-and-fade transition anchored toward the screen edge. Neighboring icons and the panel resize together. The first app reveals the panel; removing the last app hides it immediately. There is no empty placeholder or loading spinner. This is a Dock-like approximation, not Apple's private animation implementation.
- Reduce Motion disables membership movement. Initial layouts, background/hidden panels, display/style changes, and the shared-panel compatibility renderer update immediately. Switching Spaces does not replay membership animations.
- Appearance follows the system, with support for Reduce Motion, Reduce Transparency, and VoiceOver labels.

Rearranging icons does not move application windows between Desktops, pin an app, or modify the native Dock. It is unavailable in the shared-panel compatibility mode because that panel has no fixed source Desktop. Reduce Motion disables the neighboring-icon animation while preserving dragging.

## Create a new window

Right-click an app icon → **New Window**. Altdock invokes an enabled, explicit New Window menu command in that running app, then checks for a new ordered window and brings it forward. It never blindly sends ⌘N or launches another app instance. Single-window apps, disabled commands, unreadable menus, and apps without a recognized command get a clear explanation rather than a forced duplicate instance. Command lookup happens only when requested, not during background discovery.

Accessibility is required. The initial command matcher recognizes English New Window/New Finder Window and default-profile variants, including a default ⌘N action inside a New Window submenu. Other labels/localizations and apps offering only New Document or New Tab are not guessed. If no distinct ordered window ID appears—for example, the app reuses its existing window or takes too long—Altdock reports that creation could not be confirmed and does not retry the command. Verification is based on WindowServer identity, not document contents or a guarantee about every app's tab behavior. Window placement follows the app's behavior.

## Move windows between Desktops

Right-click an app icon → **Move Focused Window** to move only that app's AX-focused window. It must be eligible on the current Desktop/display; focus elsewhere or unavailable focus never falls back to a sibling. Altdock rechecks the selected window, source Desktop and destination before submitting the move.

Choose **Move** to move the app's eligible current-Desktop windows together. Altdock re-reads window ownership and Space membership, moves only the selected process's eligible windows assigned exclusively to the source Desktop, then verifies their new membership and refreshes the panels. It does not request a desktop switch or launch another app instance.

The move action does not include windows on other Desktops, windows assigned to multiple/all Desktops, ordered-out/minimized/hidden windows, or windows on other displays. Minimized windows can still keep their app's icon visible; showing an icon does not make those windows eligible for this move action. Full-screen Spaces are neither sources nor destinations. The menu is disabled in the shared-panel fallback or when the private move backend is unavailable. If the active Desktop or destination changed since the menu was opened, the operation is rejected.

macOS's private bridged window-management operation is used because the older direct move function did not move another app's window in testing on this Mac. No SIP changes, scripting additions, global Space changes, or permission bypasses are used. Submission is not considered success until every selected window reads back on the destination. Partial failures report the moved count; Altdock does not repeatedly retry or blindly roll back windows. App-specific behavior and macOS updates can still affect moving windows.

## Return windows from full screen

Altdock remembers each observed window's ordinary Desktop before it enters a native macOS full-screen Space, including app-initiated full screen. When it exits, Altdock returns that window to the same Desktop if needed. If that Desktop was deleted, it uses **Desktop 1** in Mission Control order on the original display; if the display was disconnected, it uses Desktop 1 on the primary display.

This tracks individual window IDs and process IDs, not the whole app. A returning minimized/hidden window stays minimized/hidden; siblings remain untouched. Altdock does not activate the window or request a Desktop switch. It waits for ordinary-Space membership to settle, checks ownership and destination again, submits at most one move per exit, and verifies the result. Failures are logged rather than retried indefinitely.

Ordinary resizing/maximizing/minimizing, manual Desktop moves outside a full-screen return, and windows assigned to all Desktops are not redirected. Return history is session-only: Altdock must see a window on an ordinary Desktop before it enters full screen. Already-full-screen windows at startup, recreated window IDs, and full-screen cycles missed entirely between scans have no reliable origin and are left alone. The feature requires private Space metadata and is inactive in `--public-windows` mode. It does not add minimized windows back to the dock's icon list or prompt for permissions.

## Matching the native Dock

Before parking the system Dock, Altdock captures its original **bottom/left/right edge**, **base icon size**, and **edge footprint**. That snapshot drives every Space's panel. The bar's length still fits that Space's apps; it does not keep empty space merely to match the native Dock's full app list.

Altdock no longer uses its own Small/Medium/Large presets. Change the native Dock's size while Altdock is quit, then launch Altdock to capture it. The old Altdock `iconSize` preference is ignored. A crash/relaunch reuses the saved original appearance rather than copying the temporarily parked Dock's edge.

A native 64-point icon and 90-point edge footprint produce an 82-point visible panel plus an 8-point screen-edge margin. The former implementation used a 93-point panel plus the margin, unnecessarily consuming 11 extra points. Fixed-size hover feedback replaces the previous icon enlargement so it needs no additional permanent headroom.

Native metrics use read-only CoreDock queries and the `tilesize` preference. When native geometry is unavailable (for example, an already auto-hidden or magnified Dock), thickness falls back to the calibrated icon-size-plus-26-point footprint. This mirrors the base size and footprint, not every private macOS rendering detail or magnification animation.

## Persistent panels per Space — prototype

- Each known ordinary Desktop Space on the selected display gets a separate `NSPanel`, SwiftUI hosting view, and cached app list. Native full-screen Spaces do not get dock panels. A panel with no apps remains hidden, including while discovery is pending; no empty message, spinner, or blank dock is shown. Populated Space caches are displayed immediately during transitions. One shared model still does window discovery; this is not a separate scan/timer per Space.
- A transient discovery failure preserves the last successful all-Spaces snapshot. It does not replace other Spaces' caches with the current display's on-screen list. A successful empty result clears that Space and hides its panel. An unknown destination never borrows the previous Space's icons.
- Hiding a panel because its cache is empty does **not** disable space reservation. The captured edge/footprint remains active (subject to Accessibility, explicit Hide Altdock, Reserve Space, and auto-hide settings). While discovery is pending, reservation can inspect current on-screen windows separately without making the panel visible.
- Panels use managed, Space-bound collection behavior rather than `canJoinAllSpaces`/`stationary`. macOS controls their visibility as desktops move. In always-visible mode, inactive panels remain **ordered in their own Spaces**, not moved onto or shown over the active desktop.
- `SLSMoveWindowsToManagedSpace` is dynamically loaded to attach **only Altdock-owned panels**. Creation occurs at zero opacity; membership must read back as exactly the destination Space before a panel can be shown. This automatic panel-placement path never moves other apps' windows or switches Desktops. The right-click move action and full-screen return tracking are separate window-movement paths.
- Panels sit **8 points inside the original bottom, left, or right display edge**, not inside the system Dock's stale work-area inset. The non-docked axis is centered in the visible work area.
- Switching Spaces updates focus/visibility, not panel membership, root hosting views, or frame sizes. Membership changes within a Space can still change that Space's dock size. Display changes rebuild the relevant panels, deleted Spaces close theirs, and quit closes all panels.
- Auto-hide remains available; only the active panel responds to the reveal edge. Inactive panels are hidden in auto-hide mode. Hide Altdock hides every panel.
- If all-Spaces data or placement is unavailable, a shared panel is used as a compatibility fallback. A failed placement is closed invisibly and is not repeatedly retried; recreating the Space/display or relaunching retries it. The menu reports the active presentation mode. Multi-display arrangements still require hands-on testing; membership verification alone does not prove native animation/visibility in every macOS configuration.

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
- Altdock is hidden and reservation pauses in **native macOS full-screen Spaces**, including a full-screen Zoom window or Split View. The selected display's Space type determines this—not the app name, window count, or screen-filling geometry. Ordinary maximized windows on regular Desktops still use Altdock. Other displays/Desktops keep their cached panels and adjusted layouts; returning resumes reservation automatically.
- Reservation also pauses when **Automatically Hide** is on or Altdock is explicitly hidden. It does not resize windows on every edge reveal.
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

On launch, Altdock saves the system Dock's exact **position**, **auto-hide**, **icon size**, **auto-show delay**, and **minimize effect**, along with Altdock's original appearance reference. It enables auto-hide and keeps the native Dock on **the same original edge as Altdock**, so minimized windows travel in the same direction. It selects the faster **Scale** minimize effect; this is not animation-free. Native Dock icons are reduced to **1 point**, with a **1,000-second auto-show delay**. A small native Dock strip can still appear in Mission Control; this is suppression, not complete removal. Altdock keeps the original edge, icon size, and footprint captured before these changes. Dock items, magnification, minimize-to-application, and launch-animation preferences are not changed. Restarting the system Dock to apply changes may cause a brief visual transition.

On quit, all five saved settings are restored, including removing keys that were originally absent. A lightweight helper process also restores them if the main Altdock process crashes or is force-quit. A session lock prevents a second instance from overwriting the original snapshot; a token prevents an old helper from restoring a newer session's settings.

The recovery record lives at `~/Library/Application Support/Altdock/system-dock.json`. If both the app and its helper are killed, or the Mac loses power, the next launch reuses that original record and restores it on exit. Do not delete the record while restoration is pending. A corrupt record causes startup to fail without replacing it. A valid record is removed only after restoration succeeds. No permanent recovery LaunchAgent is installed. Changes to these same five settings made manually while Altdock runs will also be replaced by the saved pre-launch values on exit. Older recovery records capture newly introduced size/delay/minimize-effect values before those overrides are first applied; restoring an old record alone does not change preferences it never captured.

The `--list-current-space` and `--list-spaces` diagnostics do not change Dock preferences or prompt for Accessibility.

## Space semantics and permissions

Altdock dynamically loads **private SkyLight APIs**: `SLSCopySpacesForWindows` maps windows to Spaces; `SLSCopyManagedDisplaySpaces` enumerates Spaces; `SLSCopyBestManagedDisplayForRect` and `SLSManagedDisplayGetCurrentSpace` identify the selected display’s active Space. `SLSMoveWindowsToManagedSpace` places Altdock's own panels. `CGWindowListCopyWindowInfo(.optionAll)` supplies window metadata, including windows on inactive Spaces. No screenshots or network access are used. Minimized-window titles are read locally through Accessibility for tile labels.

- Private APIs are undocumented and may break with macOS updates. Missing symbols or failed snapshot queries fall back to public on-screen discovery. Dynamic loading avoids a hard launch-time dependency, but cannot guarantee compatibility with a changed private ABI. This build is intended for direct distribution, not Mac App Store submission.
- Normal-layer, nontransparent windows belonging to regular applications qualify for all-Spaces discovery if they are **ordered in**, or if Accessibility confirms their exact window ID is **minimized**. `SLSWindowIsOrderedIn` distinguishes windows still ordered on an inactive Space from ordered-out auxiliary windows (such as retained Chrome UI). Valid Space membership alone is not enough. No height heuristic or app-specific filter is used. Finder appears only when it has a qualifying window, not merely because its desktop is visible.
- Ordered-in windows on inactive Spaces remain cached even though they are not currently on-screen. Apps with genuinely minimized windows also stay visible on the windows' assigned Desktop/display, including when discovered already minimized at startup. Each app retains its app icon, and each minimized window also gets a separate restore tile. Ordered-out auxiliaries and merely hidden, non-minimized windows remain excluded. Minimized inclusion requires Accessibility and private Space membership; public on-screen fallback does not guess their Desktop. Transient AX failures preserve previously confirmed minimized IDs only while the same PID/window ID remains a candidate; successful non-minimized reads clear that confirmation. If no all-Spaces cache exists and the ordering API is unavailable or a query fails, discovery falls back to public on-screen windows. An existing all-Spaces cache is retained across transient read failures.
- “Current Space” is scoped to the **selected display** using both Space membership and window geometry. A window spanning displays can qualify on either if assigned to that display’s active Space. Windows assigned to several Spaces appear in each corresponding list.
- A 0.75-second timer and app lifecycle notifications reconcile all-Spaces membership and presentations. Separate per-app Accessibility observers trigger discovery after minimize/restore events, coalescing bursts for 10 ms. Failed registrations retry with increasing delays from 0.25 to 5 seconds on existing refreshes; missing permission or unsupported events retain periodic fallback. No faster global scan timer is added. Existing panel identities are retained across Space switches, with cached icon ordering per Space. Unknown/new Spaces stay hidden unless their own cached apps are available; a confirmed empty Space keeps its panel hidden. Caches can briefly lag window moves or closes until reconciliation.
- Public fallback transitions hide the shared dock during a 0.4-second grace period when no destination-specific cache is available; short retries populate it without showing the outgoing Space's apps. Full scans currently run on the main thread; large window counts may increase refresh cost.
- **Screen Recording is not requested.** Filtering uses process IDs, window geometry, Space IDs, and Accessibility minimized state—not screenshots. Minimized tile labels use Accessibility window titles.
- **Accessibility is required for space reservation and precise window control**, but the basic dock still works without it. “Grant Accessibility Access…” opens the permission settings. When granted, Altdock uses `_AXUIElementGetWindow` when available to match an accessible window by ID, unminimizes it, and raises it before activating the app. Activation can fall back to geometry matching; reservation does not resize geometrically ambiguous windows if exact identity is unavailable. Without a usable accessible window, macOS chooses which window to activate and may switch Spaces; restoration of a particular minimized window is not guaranteed without Accessibility. Hidden apps are unhidden on activation. Clicks re-query membership to avoid acting on stale icons.
- Full-screen detection reads the selected display's managed Space metadata independently of app discovery. Cached full-screen classifications survive transient metadata failures. Without this private metadata (e.g. forced `--public-windows` mode), the app does not guess full-screen state from window dimensions; individual full-screen AX windows are still excluded from reservation writes.

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
