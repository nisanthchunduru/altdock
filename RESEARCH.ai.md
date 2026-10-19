# Altdock engineering research

## Product decisions

- Show apps belonging to the selected display's current Space; retain a macOS Dock-like interface.
- Cache all-Spaces window membership rather than emptying the dock during Space transitions.
- Reserve room for Altdock **by default**, using Accessibility-based avoidance for maximized/tiled windows. Permission must still be granted through macOS; it cannot be silently enabled.
- On launch, save the system Dock's position and auto-hide setting, then move it to the right and enable auto-hide only where necessary. Restore those two settings on exit. Do not modify icons, size, magnification, delays, or other Dock preferences.
- Screen-space avoidance is not a WindowServer-wide reservation. Do not promise that every app or manually placed window will comply.

## Source review

These are implementation findings from inspected source and callers, not runtime testing of the third-party apps. Commit links are pinned because implementations and documentation change. No source code was copied into Altdock.

### Docky — conservative reservation

Commit: `44bf925639e079c5edf8284fd8edc2c157349ee5` (GPLv3).

- [WindowReservationService.swift](https://github.com/josejuanqm/docky/blob/44bf925639e079c5edf8284fd8edc2c157349ee5/Docky/Services/WindowReservationService.swift): reacts to the window registry's AX updates when resize mode and Accessibility are enabled. Requires overlap and at least two edges aligned with the screen's visible frame. Shrinks maximized/half/quarter-tiled windows while leaving ordinary floating windows alone. Uses a 250 ms per-window cooldown.
- [WindowRegistry.swift](https://github.com/josejuanqm/docky/blob/44bf925639e079c5edf8284fd8edc2c157349ee5/Docky/Services/WindowRegistry.swift): AX observers and position/size writes; attempts to refresh stale window handles.
- [SystemDockVisibilityService.swift](https://github.com/josejuanqm/docky/blob/44bf925639e079c5edf8284fd8edc2c157349ee5/Docky/Services/SystemDockVisibilityService.swift): snapshots Dock preferences and has a watchdog restoration mechanism. Altdock should touch only the two settings its user requested, not this project's larger set of hide/delay/animation settings.

### OpenBoringBar — broader bottom guard

Commit: `1d2c3c157786f56230286dda5b1c236948a6d5e0` (MIT).

[ActiveWindowBottomGuardManager.swift](https://github.com/nagisa77/OpenBoringBar/blob/1d2c3c157786f56230286dda5b1c236948a6d5e0/OpenBoringBar/Core/Bar/ActiveWindowBottomGuardManager.swift): app/window observers for create/focus/move/resize, startup adjustment, per-display bar height, minimized/full-screen exclusion. Writes AXSize and restores the top-left anchor through AXPosition. Its one-second global throttle and single trailing request are not a pattern to copy blindly for multi-window adjustment. Its broader overlap policy is more intrusive than the initial Altdock policy.

### Tungsten Edge — conflict handling and verified writes

Commit: `89ab9c1bc2687d12e973ce81a51999d8c56239fc` (GPLv3).

- [WindowLiftAvoidance.swift](https://github.com/moonbai-studio/tungsten-edge/blob/89ab9c1bc2687d12e973ce81a51999d8c56239fc/Core/Support/WindowLiftAvoidance.swift): maximized/bottom-tiled geometry, bounded re-lift/standoff counts, per-window state, and compare-before-rollback. Important lesson: repeatedly enforcing a rectangle against another tiling manager produces visible oscillation.
- [WindowLiftAvoidanceController.swift](https://github.com/moonbai-studio/tungsten-edge/blob/89ab9c1bc2687d12e973ce81a51999d8c56239fc/App/Composition/WindowLiftAvoidanceController.swift): validates stable CG/AX samples, window role, full-screen/minimized state, and writable attributes before adjustment.
- [AXWindowReader.swift](https://github.com/moonbai-studio/tungsten-edge/blob/89ab9c1bc2687d12e973ce81a51999d8c56239fc/Platform/Accessibility/AXWindowReader.swift#L580-L738): checks the current frame before writing, checks settable attributes, verifies the resulting frame, and preserves intervening external changes.

### DeskBar — size adjustment, not global reservation

Commit: `7caaf175e477d767f3bc2302f9edbe2548dd4ac4`.

- [WindowManager.swift](https://github.com/rajeshgoli/deskbar/blob/7caaf175e477d767f3bc2302f9edbe2548dd4ac4/Sources/DeskBar/Services/WindowManager.swift#L410-L434): shortens system-fill-like windows through AXSize, excludes full screen, and scopes to displays with taskbars.
- [ScreenGeometry.swift](https://github.com/rajeshgoli/deskbar/blob/7caaf175e477d767f3bc2302f9edbe2548dd4ac4/Sources/DeskBar/Utilities/ScreenGeometry.swift): classifies full/half-width system-fill-like windows and leaves their origin unchanged.
- [DockManager.swift](https://github.com/rajeshgoli/deskbar/blob/7caaf175e477d767f3bc2302f9edbe2548dd4ac4/Sources/DeskBar/Services/DockManager.swift): backs up preferences, applies changes, restarts Dock, and installs recovery machinery.
- Its older `SPEC.md` says no screen-space reservation, but the implementation does contain AX avoidance. Prefer source over stale specs.

### DockDoor — cooperative snapping reservations

Commit: `77e4771d38cf69dc24f2f76c74a73e61fab54571` (GPLv3).

- [ScreenReservations.swift](https://github.com/ejbills/DockDoor/blob/77e4771d38cf69dc24f2f76c74a73e61fab54571/DockDoor/Utilities/Window%20Management/ScreenReservations.swift): accepts per-edge/display reservations over distributed notifications or AppleScript; computes its own `snappingFrame`, avoiding double-counting the system Dock.
- [WindowInfo.swift](https://github.com/ejbills/DockDoor/blob/77e4771d38cf69dc24f2f76c74a73e61fab54571/DockDoor/Utilities/Window%20Management/WindowInfo.swift#L287-L326): uses that frame for its own positioning and applies AX size/position/size writes. This does not constrain arbitrary placements by other apps.
- Potential future integration: publish `com.ethanbills.DockDoor.reserveScreenEdge` with `edge`, `thickness`, `source`, and `display`. Not required for Altdock's standalone implementation.

InfyniDock's GitHub checkout (`5042fb5`) contained only a README, not implementation source; it is not evidence about the implementation. Docky/Tungsten/DockDoor licenses have reuse obligations; learning the architecture does not mean copying their GPL code into an otherwise unlicensed repository.

## Chosen reservation design

1. Keep a stable exclusion height derived from the user's preferred icon size, panel padding, and bottom gap—not current app count or hover magnification.
2. Only adjust standard, resizable, non-minimized, non-full-screen windows on the selected display/current Space. Start with maximized/bottom-tiled layouts; do not force all manually placed windows out of the way.
3. Observe AX window changes, coalesce events, and retain slow reconciliation for missed events. Keep blocking AX reads/writes off the UI thread and set messaging timeouts.
4. Revalidate identity and geometry before writing; preserve top/left/width. Check results rather than assuming AX success implies the requested size was accepted.
5. Track original and last-applied rectangles per window. Suppress self-generated events; stop on external/manual changes or repeated competing writes. Never blindly restore a stale original frame.
6. Do not resize windows each time an auto-hidden dock reveals. Reservation is suspended while Altdock is hidden or auto-hide is enabled.
7. Normal exit/disable can safely restore unchanged frames. Force-quit recovery of arbitrary app windows is not guaranteed; the system Dock's two preferences have a separate durable restoration mechanism.

## System Dock lifecycle

Save the exact prior presence/value of `com.apple.dock` keys `orientation` and `autohide` before changing anything. Missing keys must be restored by deletion, not replaced by guessed defaults. Update keys individually; never replace the whole preference domain. Synchronize and restart the current user's system Dock only when values change.

Use a persistent original-settings record and a session lock to prevent duplicate instances from overwriting the original snapshot. A lightweight child process can wait for that lock to be released on exit/crash and restore the recorded settings. A session token prevents an old child from restoring a newer session's settings. Normal quit also restores while holding the lock. A retained record allows recovery on next launch if both parent and guardian are killed or the machine loses power. Do not install a permanent LaunchAgent just for this.

## Private API boundary

- Public `NSScreen.visibleFrame` is read-only. [FB9985546](https://openradar.appspot.com/FB9985546) requests third-party edge reservation.
- Reverse-engineered [CGSSetDockRect](https://github.com/alexzielenski/Mousecape/blob/master/Mousecape/mousecloak/CGSInternal/CGSMisc.h) is described as requiring a universal owner. None of the inspected avoidance paths relies on it; it is not the chosen approach.
- Public `.optionAll` window enumeration includes other-Space windows but lacks reliable Space membership. `kCGWindowWorkspace` is unsupported since 10.8.
- Altdock dynamically loads `SLSCopySpacesForWindows`, `SLSCopyManagedDisplaySpaces`, `SLSCopyBestManagedDisplayForRect`, and `SLSManagedDisplayGetCurrentSpace`. [yabai declarations](https://github.com/koekeishiya/yabai/blob/master/src/misc/extern.h) and [usage](https://github.com/koekeishiya/yabai/blob/master/src/window.c) were checked; all-Spaces reads worked on macOS 26.7.1.
- `_AXUIElementGetWindow` supplies exact window identity when available. Reservation should fail safely rather than resize a geometrically ambiguous window if identity cannot be established.
- Private APIs remain OS-version risks. Accessibility permission is not permission to bypass WindowServer privilege checks or macOS security settings.

## Implementation map

- `Sources/AltdockCore/ReservationGeometry.swift`: Quartz-coordinate eligibility and stable bottom clearance.
- `ReservationLedger.swift`: per-window originals, last-applied frames, cooldown/retry bounds, manual-override suppression, and restoration guards.
- `ReservationFrameTransaction.swift`: expected-frame validation, read-back verification, and guarded rollback of partial height changes.
- `Sources/Altdock/Reservation/`: background actor, AX element access, per-app/window observers, and main-thread configuration/event coordination. Individual AX objects need their own messaging timeout: Apple's `AXUIElement.h` explicitly says an application object's timeout does **not** propagate to other objects, even equivalent ones.
- `Sources/Altdock/SystemDock/`: two-key preference access plus durable session/guardian handling. The guardian is the same executable in a headless `--restore-dock-after-exit` mode, started before preferences are changed. Its waiting file lock is released by the OS if the owner dies. No accessibility permission is needed to restore these preferences.
- `DockPreferences.reserveSpace`: missing preference means `true`; an explicit user opt-out remains persistent. Auto-hide and manually hiding Altdock suspend reservation instead of resizing on every reveal.
- `Tests/AltdockCoreTests/Reservation*` and `Tests/AltdockTests/SystemDockSessionTests.swift`: deterministic safety tests, with isolated stores rather than live preference mutations.

A local native probe using the actual session/guardian implementation verified restoration after `SIGKILL` of its owner; the bundled app's normal quit also restored the original Dock settings. This does not establish Accessibility behavior for every app; the manual checklist remains necessary.

## Reservation debugging: permission identity and asynchronous AX behavior

The first implementation had several independently reproducible code-level failure paths:

- Requiring an explicit `false` from optional `AXFullScreen` rejected apps returning `AXError.attributeUnsupported`. Required attributes still need valid reads, but an unsupported optional full-screen flag is now allowed; timeouts are not treated as false.
- Requiring writable AXPosition before a height-only adjustment unnecessarily rejected size-resizable windows. Position capability is now checked only if size adjustment actually changes the anchor.
- Immediate read-back after AXSize could see the old/intermediate animated frame, trigger rollback, and permanently suppress the window. Verification now observes settling with a bounded budget; transient failures have bounded backoff rather than one-failure permanent suppression.
- Two adjustment attempts per window lifetime prevented later legitimate maximizations. Aggregate user-input counters plus a subsequent eligible geometry change now permit a new adjustment cycle; unchanged geometry/unchanged input does not restart a competing-manager loop. No keys or event contents are recorded.

These fixes have deterministic regressions. They are not proof that Firefox specifically returns an unsupported fullscreen attribute.

Native inspection found a normal maximized Firefox desktop window with geometry matching Altdock's eligibility rules. Separately, the built app had a designated requirement of `cdhash H"…"` (ad-hoc signing), which changes across rebuilds. The rebuilt **running app's own** report showed missing Accessibility despite a checked Settings entry. Do not diagnose the app's grant from `swift -e AXIsProcessTrusted()` in a terminal: it has a different responsible identity.

- `AccessibilityPermission` is the centralized, non-prompting checker. Startup never requests access automatically; explicit requests re-check the OS grant and do nothing if already granted. Stored booleans are not used as authorization.
- `ReservationDiagnostics` writes the running process's last changed report to `~/Library/Application Support/Altdock/reservation-status.json`. `--reservation-status` reads it without starting another dock/session or requesting permission. Reports include IDs, geometry, errors, and reasons, not window titles/content.
- A stale grant may need the user to remove/re-add the exact built app in Privacy & Security → Accessibility. Stable code signing is the proper long-term solution for repeated local rebuilds. Do not bypass TCC, loosen signature requirements, reset privacy grants, or silently modify the keychain as a workaround.
- [Rectangle issue 1615](https://github.com/rxhanson/Rectangle/issues/1615) documents inaccessible Firefox window metadata and stale grants; the maintainer recommends checking permission/app state rather than assuming a blanket Firefox-version incompatibility. [Mozilla bug 1865755](https://bugzilla.mozilla.org/show_bug.cgi?id=1865755) also documents AX resize behavior when accessibility is active. Altdock does not toggle Firefox's accessibility preferences or `AXEnhancedUserInterface`.

## Verification priorities

Test geometry in Quartz's top-left coordinate system, including negative monitor coordinates and system Dock/menu-bar insets; known/unknown Spaces; loop suppression; manual overrides; restoration guards; fixed-size/minimum-size apps; missing permissions; default-enabled migration; and preference backup/apply/restore failures. Native acceptance must cover Mission Control, full screen, multi-monitor arrangements, app/tiling-manager conflicts, normal quit, force quit, and restart. Unit tests are not proof of behavior in every third-party app.
