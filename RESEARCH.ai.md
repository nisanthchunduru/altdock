# Altdock engineering research

## Product decisions

- Show apps belonging to the selected display's current Space; retain a macOS Dock-like interface.
- Cache all-Spaces window membership rather than emptying the dock during Space transitions.
- Reserve room for Altdock **by default**, using Accessibility-based avoidance for maximized/tiled windows. Permission must still be granted through macOS; it cannot be silently enabled.
- Capture the system Dock's original edge, base icon size and thickness before parking it. Altdock uses that edge and size, with per-Space length. Keep the native Dock on the same original edge as Altdock. Enable auto-hide; temporarily reduce native icons to 1 point, set a 1,000-second auto-show delay, and select Scale minimization. Restore all five original settings on exit. Never modify native magnification, Dock items, minimize-to-application, or launch-animation preferences.
- Screen-space avoidance is not a WindowServer-wide reservation. Do not promise that every app or manually placed window will comply.

## Source review

These are implementation findings from inspected source and callers, not runtime testing of the third-party apps. Commit links are pinned because implementations and documentation change. No source code was copied into Altdock.

### Docky — conservative reservation

Commit: `44bf925639e079c5edf8284fd8edc2c157349ee5` (GPLv3).

- [WindowReservationService.swift](https://github.com/josejuanqm/docky/blob/44bf925639e079c5edf8284fd8edc2c157349ee5/Docky/Services/WindowReservationService.swift): reacts to the window registry's AX updates when resize mode and Accessibility are enabled. Requires overlap and at least two edges aligned with the screen's visible frame. Shrinks maximized/half/quarter-tiled windows while leaving ordinary floating windows alone. Uses a 250 ms per-window cooldown.
- [WindowRegistry.swift](https://github.com/josejuanqm/docky/blob/44bf925639e079c5edf8284fd8edc2c157349ee5/Docky/Services/WindowRegistry.swift): AX observers and position/size writes; attempts to refresh stale window handles.
- [SystemDockVisibilityService.swift](https://github.com/josejuanqm/docky/blob/44bf925639e079c5edf8284fd8edc2c157349ee5/Docky/Services/SystemDockVisibilityService.swift): snapshots Dock preferences and has a watchdog restoration mechanism. Altdock should touch only explicitly approved settings (now position, auto-hide, icon size, auto-show delay, minimize effect), not this project's larger set of animation settings.

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
7. Normal exit/disable can safely restore unchanged frames. Force-quit recovery of arbitrary app windows is not guaranteed; the system Dock's five borrowed preferences have a separate durable restoration mechanism.

## System Dock lifecycle

Save the exact prior presence/value of `com.apple.dock` keys `orientation`, `autohide`, `tilesize`, `autohide-delay`, and `mineffect` before changing anything. Missing keys must be restored by deletion, not replaced by guessed defaults. Update keys individually; never replace the whole preference domain. Synchronize and restart the current user's system Dock only when values change.

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
- `Sources/Altdock/SystemDock/`: five-key preference access plus durable session/guardian handling. The guardian is the same executable in a headless `--restore-dock-after-exit` mode, started before preferences are changed. Its waiting file lock is released by the OS if the owner dies. No accessibility permission is needed to restore these preferences.
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
- A subsequent measured 11-point overlap was an authorization failure, not another geometry bug: Firefox ended at Quartz y=1602 while Altdock began at y=1591; the existing target was y=1587. After the user quit Altdock, removed/re-added the exact app in Accessibility, and reopened it, the unchanged binary reported live access and Firefox's frame became y=30, height=1557, leaving the intended four-point gap. Check the running app's actual grant before changing padding or rebuilding again; a rebuild can invalidate the just-refreshed ad-hoc grant.
- A stale grant may need the user to remove/re-add the exact built app in Privacy & Security → Accessibility. Stable code signing is the proper long-term solution for repeated local rebuilds. Do not bypass TCC, loosen signature requirements, reset privacy grants, or silently modify the keychain as a workaround.
- [Rectangle issue 1615](https://github.com/rxhanson/Rectangle/issues/1615) documents inaccessible Firefox window metadata and stale grants; the maintainer recommends checking permission/app state rather than assuming a blanket Firefox-version incompatibility. [Mozilla bug 1865755](https://bugzilla.mozilla.org/show_bug.cgi?id=1865755) also documents AX resize behavior when accessibility is active. Altdock does not toggle Firefox's accessibility preferences or `AXEnhancedUserInterface`.

## Persistent panels per Space

The user chose to prototype a dock that belongs to each workspace rather than a stationary shared window that changes shape. The previous controller replaced its SwiftUI root value and recalculated/recentered the panel on every model change, including focus and transition flags. Caching window membership fixed data latency, not those presentation jumps.

Implementation:

- `SpaceWindowTracker.allSelections` scopes the cached all-Spaces index to the selected display's managed Spaces. `DockModel.spaceApplications` publishes stable per-Space app lists and `activeSpaceID` separately; there is still only one scanner/timer.
- `DockPanelController` retains surfaces keyed by Space ID. Each `NativeDockSurface` has one `DockPresentation` and one `NSHostingView`, created once. Focus changes do not recalculate frames or replace root views; unchanged layouts do not call `setFrame`. Hosting sizing options are disabled so intrinsic-size updates cannot resize the native window behind the controller's back.
- Per-Space panels use `[.managed, .fullScreenAuxiliary, .ignoresCycle]`, not `.canJoinAllSpaces` or `.stationary`. In always-visible mode all verified panels remain ordered in their own Spaces; WindowServer decides which is on-screen. Auto-hide acts on the active panel and hides inactive panels.
- `SpacePanelPlacement` dynamically resolves `SLSMoveWindowsToManagedSpace(int connection, CFArray windows, uint64_t spaceID) -> void`. It accepts an `NSPanel`, checks that it belongs to `NSApp.windows`, orders it at zero opacity, moves only that own window ID, and requires `SLSCopySpacesForWindows` to return exactly the destination ID. An unverified panel is closed invisibly; no security settings, other apps' Space assignments, or active desktop are changed.
- Missing private APIs/data or a rejected placement uses the shared-panel fallback. Placement failures are remembered until the Space/display is recreated or the app restarts, avoiding repeated invisible moves. `--shared-panel` allows an A/B comparison with the same signed binary. `--panel-status` reads the running app's panel IDs, Space IDs, geometry, app PIDs, and ordering state from `~/Library/Application Support/Altdock/panel-status.json`.
- Space removal closes only that panel. Display changes/hotplug recreate the applicable set. Quit closes all panels. Activation from an outgoing panel must still match the live active Space ID, preventing delayed clicks from switching to an unrelated workspace.

A native probe on macOS 26.7.1 successfully moved an invisible, nonactivating panel owned by the probing process to an existing inactive Space. Membership read back correctly immediately, remained correct after frame changes, order-out/order-front, and restoring opacity, and the active Space did not change. No Accessibility grant or security-setting change was used for the probe. The running prototype was also checked independently against WindowServer: three distinct dock window IDs had the expected single-Space memberships, with exactly the active Space's panel on-screen and the others off-screen at full opacity. This validates own-window placement, not arbitrary other-app movement or full-screen animation on every OS version.

References: [yabai declaration](https://github.com/koekeishiya/yabai/blob/master/src/misc/extern.h), [yabai move implementation](https://github.com/koekeishiya/yabai/blob/master/src/space_manager.c), and [Hammerspoon issue 3636](https://github.com/Hammerspoon/hammerspoon/issues/3636) (own versus other-app window behavior differs). Do not adopt compatibility-ID workarounds, scripting additions, SIP changes, or global Space mutations merely because another window manager uses them.

Lifecycle tests use fake surfaces (no real windows/private writes): preloading inactive/empty Spaces, persistent identities across switching, no switch-time relayout/reattachment, inactive content updates, creation/deletion, display changes, placement failure, compatibility mode, global hide/show, and cleanup. Native Space swipes, cancelled swipes, Mission Control, multiple displays, and full-screen auxiliary rendering still need hands-on acceptance.

## Physical bottom versus the system Dock's old work area

A placement bug was traced to the original coexistence rule in `DockGeometry.frame`: `max(screenFrame.minY + 8, visibleFrame.minY + 8)`. On the inspected Mac, the full screen began at AppKit y=0 but `NSScreen.visibleFrame` still began at y=90 even with the system Dock's preferences set to right/auto-hide. That deterministically placed every panel at y=98. This was a geometry assumption left over from displaying Altdock above a visible system Dock, not a failure to assign panels to Spaces.

The corrected rule anchors panels at `screenFrame.minY + DockGeometry.bottomMargin` (8 points). Width and horizontal centering still respect the reported visible frame. `DockGeometry.panelHeight`, `bottomMargin`, and `reservationClearance` are shared with `ReservationGeometry`, whose Quartz-coordinate bottom limit is now `display.maxY - panelHeight(preferredIconSize) - bottomMargin - reservationClearance`. Do not subtract `visible.maxY` first: that double-counts the old Dock strip.

Eligibility accepts bottom-aligned windows ending at either the reported work-area bottom or the physical display bottom, since apps can use either after the Dock is hidden. The implementation only shortens overlapping windows; it does not expand windows that already clear Altdock. Regression tests cover stale insets, negative monitor coordinates, horizontal insets, every configured icon size, both alignment conventions, and both per-Space/shared panels.

A native probe using the actual geometry and own-window placement code confirmed that WindowServer honored y=8 for icon sizes 24/40/52/64 while `visibleFrame.minY` was still 90. The rebuilt running app's three panels were independently checked through `CGWindowListCopyWindowInfo` and all had an 8-point physical bottom margin. No `constrainFrameRect` override, global work-area mutation, desktop switch, or security-setting change was needed.

## Stable local signing identity

User-approved identity name: **Altdock**, stored only in the login Keychain, with an exportable RSA-3072 private key. Certificate subject/issuer CN=Altdock, random serial, SHA-256/RSA signature, ten-year validity, critical CA:FALSE, digitalSignature, and codeSigning EKU. No personal name, email, organization, or address was included; no private-key/.p12 backup files were created.

Certificate SHA-1: `C11E34AF0F57148CE73A8B5171AC439D35931641`; SHA-256: `48B3C40D11ABA0971543BBA2D172CF335AA0C52FC4A670711240D532B0C173F2`. User trust contains only the code-signing policy (OID `1.2.840.113635.100.1.16`), with no admin-domain trust entry. Import granted automatic key use to `/usr/bin/codesign`, not all apps. Exportability was checked through Security.framework attributes.

`scripts/create-signing-identity.swift --create` reuses an existing identity rather than rotating it. Generation uses OpenSSL with private material passed through in-memory pipes into Security.framework import. Only a non-secret OpenSSL configuration is written temporarily. Native macOS approval may be needed for Keychain/trust changes; never handle user passwords in chat. Trust approval initially waited for user interaction, then completed; no alternative trust domain/security bypass was used.

`build-app.sh` now resolves the unique valid Altdock identity in the login Keychain to its fingerprint and fails closed if missing/ambiguous. `CODE_SIGN_IDENTITY`/`CODE_SIGN_KEYCHAIN` allow explicit overrides; ad-hoc signing requires explicit `CODE_SIGN_IDENTITY=-`. No custom/loosened designated requirement is supplied.

Two temporary app copies with different Info.plist contents were signed and strictly verified. Their CDHashes differed, while both default requirements were `identifier "dev.altdock.Altdock" and certificate leaf = H"c11e34af0f57148ce73a8b5171ac439d35931641"`. This establishes stable code identity, not automatic migration of an old TCC grant; moving from ad-hoc signing or to a new Mac still needs user approval. This is local development signing, not Developer ID/notarization.

## Native size and edge matching

The native Dock was restored briefly by quitting the existing Altdock binary, then measured through read-only CoreDock queries. With magnification disabled and no explicit native `tilesize` preference, its normalized tile size was `0.42857143`, mapping to 64 points on the 16–128 range, and its bottom footprint was 90 points. The old Altdock used 64 + 29 = 93 points of panel height plus an 8-point margin: 101 total, eleven more than the native footprint. Its 14-point top padding existed to accommodate always-on custom hover magnification.

The new `DockStyle` carries original edge, base icon size and edge footprint. Native metrics are captured **before** parking; the recovery record also preserves them across crashes, preventing the temporary parked edge from becoming Altdock's next original. Older records without appearance remain readable. Normal quit removes the record and the next launch captures the current native settings afresh.

For the measured native style, Altdock uses an 82-point panel plus the 8-point edge margin, with 64-point icons and 18 points of cross-axis space. Icons are now centered with nine points on each side; the indicator is independently positioned toward the screen edge rather than participating in the icon's stack layout. It no longer enlarges icons on hover or shrinks them for overflow; it scrolls along its horizontal/vertical axis. The panel length follows each Space's apps rather than copying empty space from the native Dock's full icon list. Magnification animation and every private visual detail are not cloned.

`NativeDockAppearance` reads CoreDock tile size/orientation/rectangle and falls back to `tilesize` or 64-point icons. Hidden/magnified/unavailable native rectangles use a calibrated footprint of icon size + 26. References: [CoreDock getter declarations](https://gist.github.com/w0lfschild/90db263867f469738c01e9e2d937f874) and [Apple's documented 16–128 tilesize range](https://github.com/apple/device-management/blob/release/mdm/profiles/com.apple.dock.yaml).

Layout, indicators, auto-hide zones, and reservation use the captured bottom/left/right edge. Left reservation changes x/width while retaining the right edge; right changes width; bottom changes height. Frame verification/rollback supports both axes and preflights writable position when a shift is needed. Altdock retains the original native size while the system Dock is temporarily reduced to 1 point; magnification preferences remain untouched. Cross-edge and crash-recovery behavior is covered by deterministic tests; real side-dock/macOS variations still need acceptance testing.

## Icon centering

`DockIconLayout` gives every icon a cell spanning the panel thickness, with its image rectangle centered in that cell. The indicator's center is the midpoint between the icon's screen-facing boundary and the panel boundary; its thickness is subtracted symmetrically. For a 64-point icon in an 82-point panel, the nine-point gap contains a four-point indicator with 2.5-point clearance on both sides. This rule applies to bottom, left, and right panels and to active/inactive indicators. `DockIconContent` positions the image and running indicator independently in a fixed-size ZStack. Scroll content applies padding only along the scrolling axis. The old asymmetric padding and icon-plus-indicator stack centered the combined group, not the icon itself.

Pure tests cover all edges, native icon sizes 16–128, active/inactive indicators, and varied footprints. Pixel-based SwiftUI ImageRenderer tests use a synthetic solid sRGB icon for bottom/left/right at 1x and 2x scales. An initial fixture used DeviceRGB, which color-managed red into orange on this machine and broke red-pixel detection; explicitly using sRGB for both generation and read-back fixed the test, not the layout. No user screenshot is necessary for these deterministic checks. Artwork inside an app-supplied icon may itself have asymmetric transparent padding; the icon's image box, not its visual center of mass, is centered.

## Ordered-out auxiliary windows and phantom Chrome icons

Native investigation found two separate Chrome processes with retained ~400×84 windows on the affected Desktop. They had normal layer, alpha=1, plausible bounds and valid Space membership, but `SLSWindowIsOrderedIn` reported false. Their actual browser windows reported ordered-in on other Spaces. The panel assignments were correct; the phantom icons arose because the all-Spaces scan only checked geometry/layer/alpha/membership. Two PIDs account for the two icons, not duplicate copies of one PID.

`SkyLightSpaces` now resolves `SLSWindowIsOrderedIn(int connection, uint32 windowID, uint8_t *out) -> CGError`, returning nil on failure. `SpaceWindowTracker` skips confirmed ordered-out candidates before fetching their membership. A missing API or failed ordering read uses the existing on-screen fallback rather than guessing. Ordered-in windows on inactive Spaces remain eligible (`isOnScreen=false` does not imply ordered-out). There is no hard-coded Chrome filter, minimum-height workaround, or bundle-ID deduplication.

This deliberately excludes all ordered-out windows for now; genuine hidden/minimized windows may also be omitted. Explicit AX recognition of those window types is a separate enhancement, not part of this fix. Tests inject Space/order queries and snapshots into the real tracker to cover phantom helpers, inactive ordered windows, small legitimate ordered windows, order changes, shared/all-desktop membership, query failures, and unavailable private APIs. Desktop labels must be mapped by the order of `SLSCopyManagedDisplaySpaces`'s Spaces array, not sorted numeric IDs.

## App membership animation

`DockMembershipAnimation` gates a shared 240 ms ease-in/out animation on real app-ID changes in a previously laid-out, ordered, active-Space-bound panel. Reduced Motion, loading/unknown Space transitions, initial population, background panels, shared compatibility panels, and display/style changes bypass it. Compare against the previous **target layout**, not the window's intermediate animated frame, to avoid restarting/cancelling animation on repeated snapshot/focus updates.

`NativeDockSurface` changes its persistent presentation in a SwiftUI transaction. `DockFrameAnimator` owns a single cancellable 60 Hz timer and `DockFrameTransition` target state, using 240 ms smooth ease-in/out interpolation and direct `setFrame` calls. `DockView` uses identity-based scale+opacity transitions anchored at bottom/leading/trailing for the corresponding physical dock edge. Surviving views reflow naturally; the first/last app swaps the empty placeholder with an opacity transition. This approximates familiar Dock insertion/removal, without using undocumented Apple animation timings or adding a launch-bounce behavior. Final icon geometry and reservation thickness stay unchanged.

Policy regressions cover all edges, first/last app, unchanged focus snapshots, overflow, rapid consecutive membership changes, hidden/background/shared panels, loading, display/style changes, and Reduce Motion. Existing pixel tests still validate final centered icon geometry. A native probe opened/closed only its own temporary test window while sampling Altdock's WindowServer bounds at roughly 60 Hz. Insertion produced intermediate widths between 550 and 626 points, and removal returned through intermediate widths to 550, confirming that the actual panel animates rather than snapping. Actual perceived smoothness, interrupted swipes, and rapid open/quit sequences still require the manual checklist.

## Clipped last icon after a Space switch

A screenshot of the active Desktop 2 reproduced Writer cut off on the right. WindowServer and panel diagnostics agreed on a 264-point frame even though the presentation contained four apps requiring 322 points. An earlier off-screen screenshot had shown the correct width, so inactive snapshots alone missed this failure.

The animator implementation compared only the last requested layout and had no idle reconciliation of the actual native frame. An old deferred frame animation could race with a newer immediate layout, and the stale size was then never repaired. The replacement uses one explicit timer/target state, retargets from the current native frame, stops at the newest target, and settles on hide/close or leaving the active Space. No old completion closure can write an obsolete width. Visibility/focus checks reconcile a settled frame without interfering with an active animation. Native-panel and pure-state regressions cover the observed 264→322 mismatch, superseded shrink, repeated targets, retargeting, side layouts, and cancellation.

## Hover app-name labels

`DockHoverAnchor` supplies a pass-through AppKit tracking view behind each SwiftUI button. Each native dock surface owns a `DockTooltipController` and a nonactivating, mouse-ignoring child panel, so the label is not clipped by the dock's rounded shape/ScrollView and never changes reservation or dock geometry. Labels sit above bottom docks or inward from side docks, centered on the hovered visible icon cell and clamped to the display work area. Tracking is restricted to visible scrolled bounds. Labels hide on mouse exit, click, menu tracking, Space change, membership/layout change, and hide/close; the short position-monitor timer runs only while a label is active.

The initial tooltip used capped width and intrinsic sizing that did not explicitly match the displayed font. An intermediate wrapping label split Firefox Developer Edition unnecessarily. Per user instruction, `DockTooltipContent` now measures the name with the actual displayed NSFont, adds text-cell padding/rounding, grows horizontally without an arbitrary width cap, and explicitly disables wrapping. Only names wider than the available screen are ellipsized; the label remains one line. The label uses a continuous corner radius of half its height and a 13-point regular system font. `NSFont.toolTipsFont(ofSize: 0)` was tried but resolved to 11 points; the user confirmed it was smaller than the Dock label. Do not equate the platform tooltip font with Dock typography. The 13-point choice corrects that undersizing; exact private Dock font metrics remain unverified. Tests cover font selection, rounded corners, short→long→short transitions, Unicode, long names, and drawing bounds as well as positioning on all edges. No screenshot or image-capable model is required for these geometry checks.

## Empty/loading Spaces: reserve room without showing a panel

The user requested removal of the empty state. `DockView` no longer renders placeholder text or a spinner. `DockPanelController` orders only surfaces with their own cached apps, and `NativeDockSurface.show` independently rejects empty content. A known empty Space may retain a minimal hidden panel for Space attachment, but neither automatic reveal nor an unknown initial state displays it. First/last app transitions reveal/hide the panel without an empty-placeholder animation. Other membership transitions remain animated.

`SpaceWindowTracker` retains its last successful all-Spaces index on transient failures; first-launch failure can still use the on-screen fallback. Active Space identity is queried separately from discovery so `DockModel` can select the destination's cached apps even when a fresh selection is unavailable. Unknown/empty destinations never borrow outgoing icons. Successful empty snapshots clear old icons, successful topology changes prune removed Spaces, and changing display bounds invalidates the display-scoped presentation cache. The tracker reports when a retained cache is being used.

Reservation is independent of automatic empty-panel visibility (`isEnabled` remains true). During discovery/loading, current on-screen windows can feed reservation separately without forcing a dock panel to appear. Existing explicit user Hide Altdock/auto-hide/Reserve Space preferences and Accessibility requirements remain in force. This remains best-effort AX adjustment, not OS-wide screen reservation.

Regression tests cover unknown startup, populated/empty destination caches, refresh failures, first/last apps, auto-hide reveal, background membership, native show rejection, and reservation preference independence. Cache is session-memory state, not disk persistence across app restarts.

## Suppressing Altdock in native full-screen Spaces

The user requested no dock or reservation on a full-screen app's Desktop. `SkyLightSpaces.fullScreenSpaceIDs(on:)` reads the selected display's managed Space `type` (4 = full screen, 0 = ordinary Desktop); `SpaceWindowTracker` exposes this independently of window discovery. `DockModel` refreshes the classification on polling and Space changes, retaining it on transient failures and clearing it when display bounds change.

Full-screen IDs are excluded from panel creation; an existing panel newly classified full-screen is closed. Shared fallback and auto-hide reveal also respect the active full-screen gate. Reservation does not create requests for such Spaces and pauses its observers while preserving normal-Desktop adjustment records, avoiding unnecessary undo/redo on unrelated windows. It resumes when returning. Existing AX checks still exclude individual full-screen windows from writes.

Do not infer full screen from a single app, window dimensions, or the name Zoom: a maximized window on an ordinary Desktop should keep Altdock. This targets native full-screen Spaces (including Split View); presentation modes that remain ordinary Desktop windows are not automatically classified as native full screen. Without private Space metadata, do not guess from geometry. Tests cover cached apps, newly created full-screen Spaces before window discovery, topology read failures, shared mode, auto-hide reveal, return to normal Desktops, and preservation of normal maximized-window behavior.

A native probe opened only its own NSWindow in full-screen mode. The running Altdock reported `Dock hidden in full-screen Space`, zero panels assigned to the new full-screen Space, `Reservation paused in full-screen Space`, and WindowServer reported zero on-screen Altdock windows. Closing the test window returned to ordinary-Desktop behavior with reservation active again. No other app's window was toggled or resized by the probe.

## Move the selected app's current-Desktop windows

`DesktopWindowMover` implements an explicit user action from the icon context menu. Destinations come from ordinary (`type == 0`) managed Spaces on the selected display, in their reported order; numeric Space IDs are not desktop ordinals. Per-Space surfaces capture their source ID and pass it with the destination and selected app process. Shared fallback panels do not offer moves.

Before submitting, the service checks the live active/source/destination topology, takes a fresh window snapshot, filters the selected PID/display and existing eligibility criteria, and requires ordered-in status plus exclusive membership in the source Space. Windows on other Spaces, shared/all-Desktop windows, ordered-out windows, and other processes are excluded. Cancellation/source changes before submission cause no writes. After one request, up to 15 short asynchronous polls verify destination membership. Partial/failure counts are surfaced without retries or rollback; model caches refresh afterward. Pinning remains reverted.

On macOS 26.7.1, a two-process native probe found `SLSMoveWindowsToManagedSpace` did not move the other process's test window, while `SLSBridgedMoveWindowsToManagedSpaceOperation` with `initWithWindows:spaceID:` and `performWithWMBridgeDelegate` did. `DesktopMoveBridge` dynamically checks this class/selectors; it is separate from own-panel placement. Relevant interface reference: [DockDoor PrivateApis.swift](https://github.com/ejbills/DockDoor/blob/77e4771d38cf69dc24f2f76c74a73e61fab54571/DockDoor/Utilities/PrivateApis.swift#L179-L215). The bridge follows the discovered interface, not copied application logic. No scripting addition or security change is installed.

A second native probe using the actual new service moved a separate test process's window, verified its target membership, and confirmed the active Desktop remained unchanged. Tests use synthetic window data and a fake bridge to cover scope, source/destination changes, unknown membership, no-window/unsupported cases, bounded verification, and partial success. The real probe opened/closed only its own disposable window, not user app windows.

## Drag-to-reorder icons per Desktop

`DockIconOrder` provides pure move/clamp and nearest-slot calculations. `DockIconDragState` keeps an original order and a local preview, with dragged-item displacement relative to the preview slot so the icon follows the pointer. `DockView` uses a six-point-threshold simultaneous DragGesture in the panel coordinate space, horizontal at the bottom and vertical at either side. Neighbors animate their preview positions unless Reduce Motion is enabled. Tooltip tracking is suppressed during dragging, and post-drag click suppression prevents mouse release from activating an app.

Only a changed order released inside the panel is committed. Outside drops, gesture cancellation, membership changes, loading, and view disappearance clear the preview. The per-Space surface captures its source ID; `DockModel.reorderApplication` revalidates the active source Desktop and existing app membership, updates `iconOrders` and that Space's cached list, and leaves other Spaces untouched. Subsequent discovery retains the chosen ordering. No windows are moved, no pinning is added, and no native Dock preferences change. Order is per-session, not disk-persistent; overflow can be scrolled before rearranging, with no drag auto-scroll in this version. Shared fallback panels disable reordering.

Tests cover move directions, index bounds, invalid input, midpoint thresholds, canceled/outside/stale drops, click suppression, per-Desktop isolation and refresh stability. A native AppKit-event probe using the actual DockView and synthetic app icons verified bottom/left/right drags: [101,102,103] became [102,103,101], exactly one commit, zero app activations. The first probe produced no gestures because its hosting view had not been explicitly laid out; setting its frame and laying out the native view fixed the harness. No user windows were moved or reordered by the probe.

## Reorder retention across transient Space snapshots

The first reorder implementation reused the visible PID list as its ordering memory. `orderedProcessIDs` correctly filters absent apps, but writing that filtered result back into `iconOrders` erased temporarily absent ranks; pruning the dictionary against the current selection also erased an omitted Space. Three regressions reproduced the reset to alphabetical order after an empty inactive snapshot, an omitted Space, and a missing/reappearing app.

Ordering memory is now independent of visibility: `DockIconOrder.remembering` retains known ranks and appends newly seen PIDs. `replacingVisibleOrder` updates visible ranks on a user drop while preserving temporarily absent entries. The per-Space ranking dictionary survives incomplete topology snapshots for the session; only the actual discovered/cached app list decides which icons display. Empty Spaces remain hidden, absent apps do not become phantom icons, and deleted panels still close. PID-based ordering remains session-only and is not persisted across Altdock restarts.

## Preserve focused windows on icon clicks

`ApplicationActivator` now reads the clicked app's `AXFocusedWindow` before enumerating fallback windows. It checks that this window belongs to the target PID and matches an eligible current-Space/display window. If the app is active and not hidden, activation is a no-op: no unhide, AXMain, AXRaise, or application.activate call. A background/hidden app's remembered focused local window is preferred when bringing it forward. Missing/nonlocal focus falls back to the first accessible local candidate; absent Accessibility uses normal macOS activation without prompting.

Native AX reads/writes live in `NativeApplicationActivation` behind an injectable `ApplicationActivationAccess` protocol. Tests verify the actual activation orchestration and absence of side effects, not merely a window-ID sort: focused sibling listed second, repeated clicks, background/hidden activation, other-Space/display focus, read failure, missing permission, no eligible windows, wrong PID, and unmatched AX windows. Permission-dependent app-specific behavior still needs native acceptance.

## Return a window to its pre-full-screen Desktop

A native AppKit lifecycle probe on macOS 26.7.1 confirmed the same window ID survives ordinary → native full-screen → ordinary → minimized transitions. `SLSCopySpacesForWindows` changes its exclusive membership from the ordinary Desktop to a type-4 Space and back. The window can already be ordered out at `windowDidExitFullScreen`, and stays present in `CGWindowListCopyWindowInfo(.optionAll)` after minimization. Dock-icon eligibility is therefore the wrong input for return tracking.

`FullScreenReturnController` consumes the tracker's raw successful private snapshots before ordered-in filtering. It records PID/window-ID-specific origins only for initially eligible ordered-in windows, but continues tracking those identities while ordered out. Space metadata from all connected displays must be complete and consistent with `allSpaceIDs`; unknown/missing reads do not invent a location. Type-4 membership arms the return, including overlapping source/full-screen transition memberships. Two ordinary-membership observations at least 0.5 seconds apart settle an exit; a change restarts that wait. Existing origin IDs survive Desktop renumbering. A deleted origin resolves to the first ordinary Desktop on its original display, or the primary display after disconnection. Split View can keep its full-screen Space while one window leaves.

Before moving, the controller re-captures window ownership and checks fresh topology/membership. It submits only the specific returning window through the existing bridged mover; no activation, unminimize, resize, or active-Space calls. Later snapshots verify the destination with a two-second deadline; failure is logged and no move is re-submitted for that exit. Normal moves before a new full-screen cycle update the origin. All-Desktop membership clears exclusive origins; terminated processes clear records; absent ordinary records have a 60-second grace period, while missing full-screen identities retain their origin for the session. No disk persistence or app-name/geometry-only origin guesses. A recreated/newly full-screen window or a completely missed full-screen cycle cannot be reliably restored.

Regression tests cover original/deleted/reordered Desktops, minimized windows, sibling isolation, normal/manual moves, repeated full-screen cycles, Split View, settling/reentry, uncertain reads, ownership changes, disappearing/recreated windows, bounded failure/verification, display removal, and raw-snapshot wiring without phantom dock icons. A native two-process probe using the actual controller/tracker and bridged operation injected a misplaced exit for a disposable window: its original membership was restored, it remained minimized, and the active Desktop stayed unchanged. At the normal 0.75-second polling interval, another run saw macOS itself correct the injected placement before observation; no Altdock correction was needed. These probes did not move user windows. Zoom-specific automation and real Desktop deletion/multi-monitor transitions remain manual acceptance checks.

## Accepted native-Dock suppression

The user accepted a thin remaining Mission Control strip. Altdock now combines its existing parking/auto-hide behavior with `tilesize=1` and `autohide-delay=1000`. A native test on macOS 26.7.1 showed these settings shrink the native Dock substantially but do not completely hide it in Mission Control. Sidebar 2.2.8 static binary inspection also found this size/delay pair; No-bouncing is not adopted. Scale minimization was subsequently accepted separately, as described below.

`SystemDockSettings.suppression` distinguishes an old record that never captured these preferences (`nil`) from a new record that captured both as absent (a present object with nil fields). On upgrade, a saved old position/auto-hide pair is preserved while current size/delay values are captured before any write. Applying an old record does not delete uncaptured keys. Appearance is captured before shrinking and retained through crash recovery. Reads reject invalid numeric values; writes retain existing forced-preference preflight, read-back verification and idempotence.

Tests cover four-key restore, exact absence, non-default/fractional originals, old-record migration/restoration, crash/relaunch, unchanged settings, invalid reads and unrelated preferences. Native signed-app quit/relaunch verification confirmed all four values/presence restored exactly, original 64-point Altdock artwork retained, and one-point/1,000-second suppression reapplied only while running.

## Minimized-window inclusion and Scale minimization

`SpaceWindowTracker` checks ordered-in status first, groups only ordered-out eligible candidates by PID, then asks `MinimizedWindowReader` once per process per refresh. The reader uses AXWindows, exact `_AXUIElementGetWindow` IDs, PID ownership, AXWindow role, and a true AXMinimized Boolean. No size/title guesses or permission prompts. AX calls have 100ms messaging timeouts. Unreadable results retain only previously confirmed minimized candidates; confirmed non-minimized/missing windows clear state. Membership and display geometry filtering remain unchanged. The existing Move to action still excludes ordered-out windows. A running signed-app check also retained a minimized disposable fixture in its correct Desktop panel; with the new startup preference applied, its Scale animation completed in approximately 0.28s. A real quit/relaunch cycle restored the original five preference values/presence (including Genie) and reapplied Scale without shrinking Altdock's 64-point icons.

Activation's focused-window no-op additionally requires confirmed non-minimized state, so a remembered focused minimized window is restored rather than ignored. A signed, two-process native probe using the actual tracker/reader/activator confirmed an ordered-out minimized fixture remained locally discoverable and could be restored on the same Desktop. No user windows were minimized by the probe.

Native animation testing on macOS26.7.1 measured approximately 0.57s for Genie, 0.55s for the unsupported `mineffect=none` value, and 0.26s for Scale. The user accepted Scale plus keeping Apple's tiny hidden Dock on Altdock's edge. `SystemDockSettings.minimization` captures the original effect separately, distinguishing uncaptured legacy records from captured absence. Legacy two-/four-key backups are upgraded before mutation; normal/crash restoration preserves the original effect or deletes a previously absent key. No global animation/Reduce Motion override is used, and Scale is not described as disabling animation.

## Separate minimized-window tiles

Discovery annotates eligible windows with minimized state and an optional Accessibility title. `DockModel` keeps ordered minimized-window lists per Space separately from app PID ordering. `DockMinimizedWindow` identities combine PID and window ID; the panel's length counts both app icons and minimized-window slots. Presentation observes minimized membership independently, so minimizing a second window changes the dock even if its app was already present. Membership transitions also animate these changes.

`DockMinimizedWindowIcon` renders a window-shaped title card with an app badge and native cell geometry. These are not live screenshots; no Screen Recording permission is requested. A separator starts the section; hover labels expose full titles, and button/context-menu Restore targets the individual window. Minimized tiles are not part of app drag ordering.

Restore re-reads discovery, requires a successful private snapshot and matching current Space/PID/window identity, then freshly verifies the selected AX window is still minimized before clearing AXMinimized, raising it and activating its app. It does not substitute the app's remembered focused sibling. Closed, already-restored, other-Desktop or unreadable targets no-op.

Native signed-app UI verification used an app with two distinct minimized windows. Pressing its Budget tile through Accessibility restored Budget, left Notes minimized, removed only Budget's tile, and shrank the actual panel. A screenshot verified the two title cards/app badges and separator. The disposable fixture required automatic window tabbing disabled and settled minimization before inspection; the AX driver needed enough action timeout for real restore processing. Tests cover per-window identity, stale actions, per-Space caching/order, label changes, sizing and all-edge rendering. No user app windows were restored/minimized by the test.

## Balanced minimized-section separator

The separator was aligned to the first minimized button's leading/top edge, ignoring the six-point inter-cell gap and the window card's inset inside its native icon cell. `DockMinimizedWindowLayout` now computes both the preview bounds and a one-point separator midway between the preceding app artwork's trailing edge and the preview's leading edge. `DockIconArtwork` measures visible alpha bounds in a small 128px raster, ignoring faint shadows; its last-image cache holds only a weak image reference. This is local app-icon processing, not a window screenshot, and adds no polling. Line thickness is included, so the two edge-to-edge gaps are equal. The SwiftUI stack and geometry share `DockIconLayout.spacing`; tile positions and total dock length do not change. Tests cover bottom/left/right edges and six icon sizes, unchanged preview size/centering, and asymmetric transparent app-icon padding checked against actual SwiftUI-rendered pixels.

## Prompt minimized-tile appearance

`MinimizedApplicationObserver` registers AXWindowMiniaturized/AXWindowDeminiaturized on each regular app's application element. Native registration and event delivery were verified on macOS26.7.1. `MinimizedWindowEvents` owns these observers independently of reservation, removes them for terminated apps or missing permission, and rejects stale per-PID callbacks. No automatic permission prompt. A failed/partial subscription is cleaned up; retries back off from 0.25s through 0.5/1/2/4s to 5s, driven by existing refreshes. An initial flat 5s retry proved too slow for newly launched apps whose AX server was not ready yet.

DockModel coalesces minimize/restore events for 10ms on the main queue, then performs the existing fresh discovery. An already-triggered refresh consumes the pending work; stop cancels it. The 750ms discovery interval and 240ms membership animation remain unchanged. Unsupported event sources still rely on that fallback; event timing is controlled by macOS, so this is not a prediction of a user's minimize action.

Native before/after measurements observed the start of the actual panel-width animation after each fixture AX miniaturize event. Before: about116ms and688ms for two windows. After the startup-retry fix: about90ms and82ms. These are short live timing samples, not a guaranteed latency bound. Only disposable fixture windows were minimized. Tests cover prompt/coalesced refresh, cancellation, permission changes, observer reuse, PID removal/reuse, partial-failure backoff, and cleanup.

## Focused-only Desktop moves

`DesktopWindowMoveScope.focused` resolves the selected app's AXFocusedWindow to an exact WindowServer ID, then filters only that ID through the existing PID/display/ordered/exclusive-source eligibility. It rechecks focused ID, ownership/geometry, ordering, membership, active source and destination immediately before the single bridged move. No nil-focus/sibling fallback. Existing all-window behavior remains as Move; both scopes retain the existing move-task busy gating and cancellation.

Native two-process testing moved a disposable app's focused window while two siblings stayed on the source and the active Desktop did not change. Unit tests cover focused sibling selection, wrong PID/display/Space/shared/minimized candidates, and focus/source changes before submission. No user windows were moved in these probes.

## Verification priorities

Test geometry in Quartz's top-left coordinate system, including negative monitor coordinates and system Dock/menu-bar insets; known/unknown Spaces; loop suppression; manual overrides; restoration guards; fixed-size/minimum-size apps; missing permissions; default-enabled migration; and preference backup/apply/restore failures. Native acceptance must cover Mission Control, full screen, multi-monitor arrangements, app/tiling-manager conflicts, normal quit, force quit, and restart. Unit tests are not proof of behavior in every third-party app.
