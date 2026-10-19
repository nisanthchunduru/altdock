# Testing Altdock

## Automated checks

```sh
./scripts/test.sh
./scripts/build-app.sh
codesign --verify --strict --verbose=2 dist/Altdock.app
plutil -lint Resources/Info.plist
dist/Altdock.app/Contents/MacOS/Altdock --list-current-space
dist/Altdock.app/Contents/MacOS/Altdock --list-spaces
dist/Altdock.app/Contents/MacOS/Altdock --public-windows --list-spaces
```

The core suites cover current-display filtering, off-screen exclusion in the public fallback, all-Spaces indexing (including shared and unvisited Spaces), window eligibility, deduplication, stable ordering, empty/unknown Spaces, negative display coordinates, and dock geometry. Native model tests use a fake tracker and clock to verify synchronous cached switches, absence of artificial empty publications, unknown-Space interaction blocking, rapid switches, and fallback settling. Dynamic loader tests cover missing frameworks and symbols.

These are deterministic unit tests, not proof of macOS Space reporting or permission-dependent app activation. Reservation tests cover tiled/floating/foreign-display geometry, negative coordinates, stable clearance, feedback suppression, retry limits, guarded restoration, partial-write rollback, and default-enabled preferences. System Dock tests use fake preference stores and isolated recovery directories; they cover normal exit, crash/relaunch, duplicate instances, missing keys, corrupt records, stale helpers, and restoration failures without changing the real Dock.

The checklist below must also be performed on a real Mac. It is a test plan, not a record that every scenario has passed. Starting the app now changes the system Dock's position/auto-hide and may resize eligible windows after Accessibility is granted; quitting should restore them as described in README.

## Signing checks

- [ ] `security find-identity -v -p codesigning` lists one valid `Altdock` identity in the login Keychain. Confirm the private key is exportable and user trust is code-signing-only.
- [ ] Sign two temporary app copies with different contents: CDHashes differ but `codesign -d -r-` reports the same app-identifier + certificate-leaf requirement. Both pass strict verification. Never use these test copies to modify TCC or the native Dock.
- [ ] A missing/ambiguous default identity makes `build-app.sh` fail before compilation instead of silently signing ad hoc.
- [ ] Switching once from ad-hoc to certificate signing may require Accessibility reapproval. Subsequent builds with the same identity/path should retain it.

## Manual acceptance checklist

### Current Space

- [ ] Run `--list-spaces`: the backend is SkyLight and apps from inactive Spaces are already listed, without visiting those Spaces.
- [ ] Open different apps on two Spaces. Switch Spaces: cached icons replace the previous list without flashing the empty-state message or resizing to its width.
- [ ] Create a new Space and switch to it immediately: an unknown destination does not temporarily claim to be empty. A confirmed empty destination does show the empty state.
- [ ] Open two windows from one app: there is one icon. Changing window stacking order does not reorder existing icons.
- [ ] Move the last window for an app to another Space: its icon disappears.
- [ ] Minimize the last window and hide its app: verify the icon disappears if WindowServer orders the window out. Space membership alone no longer keeps an ordered-out window's app in the dock. Quitting removes the icon.
- [ ] Cover a window with another app: its Space membership remains valid.
- [ ] Visit an empty Space: the empty-state message appears, not stale icons.
- [ ] Switch Spaces rapidly and during launch/termination: old-Space icons do not persist.
- [ ] Use Mission Control and Stage Manager; check membership again after leaving their transition states.

### Ordered-in window eligibility

- [ ] With two Chrome instances whose real browser windows are on other Desktops, confirm their retained ordered-out helper windows no longer generate Chrome icons on an otherwise Chrome-free Desktop.
- [ ] Run `--list-spaces` without visiting other Desktops: their ordered-in browser windows must still be cached. Switching there should reveal the correct icons without a new on-screen-only discovery delay.
- [ ] Create a small but ordered-in normal window: it must still qualify. No minimum-height workaround should suppress legitimate small windows.
- [ ] Hide/restore or close/reopen a window: membership updates with ordering state. Genuine ordered-out minimized/hidden windows are currently omitted, pending explicit AX support.

### Persistent Space-bound panels

- [ ] Run `--panel-status`: one distinct native window ID for each Space on the selected display, with no shared fallback in the normal working case. `ordered: true` on an inactive panel means it remains ordered in that Space, not that it is visible on the current desktop.
- [ ] Swipe/keyboard-switch between Spaces with different icon counts. Each dock should travel with its workspace rather than one stationary dock changing width. Repeat and cancel an interactive swipe midway.
- [ ] For original native Dock edges bottom/left/right, compare its base icon size and footprint to Altdock after launch. Every panel sits 8 points inside that original edge. Use native Dock size changes while Altdock is quit; there are no Altdock size presets. Repeat with a negatively positioned monitor and `--shared-panel`.
- [ ] Compare `--panel-status` before/after a switch: window IDs, ownership, and per-Space frames remain stable; only the active Space changes unless app membership changed.
- [ ] Open/close an app window on a Space, then leave and return: its existing panel updates correctly. Empty Spaces have their own stable empty-state panels.
- [ ] Create/delete/reorder Spaces in Mission Control: panels are added/closed without ghosts, duplicate bars, or unintended desktop switching.
- [ ] Select another display, unplug/reconnect it, and change scaling: old panels close and the new display gets the correct set. Test both separate-Spaces and shared-Spaces display configurations.
- [ ] Test full-screen Spaces and Split View. A successful membership assignment is not proof that macOS displays the auxiliary panel there.
- [ ] With auto-hide on, only the active panel responds to the reveal edge. Hide/show from the menu applies globally. Quit leaves no Altdock panels on any Space.
- [ ] For A/B comparison, quit and run `open dist/Altdock.app --args --shared-panel`; relaunch without the argument to restore the prototype. This uses the same signed binary and needs no re-signing.
- [ ] Verify stale clicks from an outgoing panel do not activate an app after changing Spaces.

### Application switching

- [ ] Click each icon: its app activates; the frontmost indicator updates.
- [ ] Give one app windows in multiple Spaces. Enable Accessibility, then click it from each Space: check that the local window is raised, including identical window geometries and minimized windows.
- [ ] Deny Accessibility: filtering still works; switching falls back to standard macOS activation without repeatedly prompting.
- [ ] Open the context menu: Open, Hide, and Quit behave normally. Quit an app with unsaved work and confirm its save prompt is respected.
- [ ] Close a window immediately before clicking its stale icon: Altdock does not launch another instance or restore unrelated windows.

### Fallback and private-API compatibility

- [ ] Quit Altdock and launch `open dist/Altdock.app --args --public-windows`: the menu reports on-screen fallback, transitions preserve the dock while settling, and hidden/minimized-only apps are omitted.
- [ ] Relaunch without that argument: the menu returns to SkyLight when available.
- [ ] Validate the all-Spaces backend after macOS upgrades. Missing symbols or failed reads should fall back, not prevent launch. A changed private ABI still requires compatibility testing.

### Default reservation and Accessibility

- [ ] Launch with no saved `reserveSpace` preference: the menu is checked without user opt-in. Startup never prompts for Accessibility. Missing access leaves the dock usable and shows a clear permission-needed item. An explicit permission request must not prompt if the live grant is already present.
- [ ] Run `--reservation-status`: verify the report comes from the running app's PID/path, not the diagnostic CLI. If a checked Settings entry is stale after rebuilding, the app reports missing permission instead of pretending it can resize windows.
- [ ] Grant permission and maximize a normal window. Bottom docks preserve top/left/width, right docks preserve left/top/height, and left docks preserve right/top/height while leaving the gap. Repeat more than twice, including animated zooms.
- [ ] Test a window without the optional `AXFullScreen` attribute and a size-resizable window with read-only position. Neither should be rejected solely for that missing capability.
- [ ] Cause one delayed/failed AX resize: verify bounded retry rather than permanent suppression. Inspect the diagnostic for the reason.
- [ ] Verify reservation leaves space only for Altdock, not Altdock plus the old system Dock strip. Test maximized windows aligned with either the old reported work-area bottom or the full display bottom; do not expand windows that already clear the dock.
- [ ] Test left/right halves and quarters touching the captured edge, including native tile margins. Ordinary floating windows and tiles away from that edge are untouched.
- [ ] Test dialogs, full-screen windows, minimized windows, and fixed/minimum-size apps. Unsupported writes must not repeatedly shrink or oscillate windows.
- [ ] Switch between Spaces with many/few apps: reserved height remains stable despite icon shrinking or an empty Space.
- [ ] Move/resize a managed window manually: Altdock does not restore a stale original frame over that placement.
- [ ] Run a competing tiling manager: after a bounded retry Altdock yields instead of continually fighting its layout.
- [ ] Disable Reserve Space, hide Altdock, or enable auto-hide: only unchanged Altdock-adjusted windows are restored. Auto-hide edge reveals do not resize windows.
- [ ] Change the native icon size while Altdock is quit, relaunch, switch displays, and disconnect a monitor. Verify sizing, edge coordinates, and guarded restoration.
- [ ] Revoke Accessibility while running: stop adjusting windows without crashes; restore permission and verify recovery.

### System Dock borrowing and restoration

- [ ] Record original native Dock position, auto-hide, and icon size. With an original bottom/left Dock, Altdock uses that edge and parks the native Dock on the right. With an original right Dock, Altdock stays right and parks the native Dock at the bottom. Auto-hide is enabled; no native size/magnification/icon/delay preferences change.
- [ ] Recover a crashed session whose native Dock is already parked: no unnecessary rewrite/restart, no recapture of the parked edge as Altdock's new original.
- [ ] Quit normally: both original values return, and `~/Library/Application Support/Altdock/system-dock.json` is removed after successful restoration. No guardian remains.
- [ ] Force-quit only the main Altdock process: the helper restores both settings. The helper has `--restore-dock-after-exit` in its arguments; killing it as well prevents immediate recovery.
- [ ] For a controlled recovery test, terminate both processes, then relaunch and quit Altdock: restore the original pre-session settings, not the temporary right/auto-hide values.
- [ ] Launch a second instance: it must not overwrite the existing original-settings record or change preferences on exit.
- [ ] Confirm diagnostics (`--list-spaces`, `--list-current-space`) neither modify system Dock preferences nor request Accessibility.
- [ ] Do not expect arbitrary application-window frames to be restored after force quit; only the two system Dock settings have durable crash recovery.

### Presentation and settings

- [ ] Check icon centering at bottom/left/right: the image box has equal cross-axis margins, independent of the running indicator and active-app state. With native 64-point icons and an 82-point panel, both margins are nine points. Test at 1x and Retina scaling; app artwork with asymmetric transparent padding can appear optically offset even when its image box is centered.

- [ ] Enable/disable auto-hide and hide/show Altdock. Verify horizontal layout at the bottom and vertical layout at the sides.
- [ ] Reveal from the captured bottom/left/right edge, move to an icon, and open a context menu. The dock stays available during interaction and hides after leaving.
- [ ] Check light/dark appearance and Reduce Transparency. Hover shows names/feedback without changing icon dimensions or requiring extra permanent headroom.
- [ ] Open enough apps to overflow the display. Every icon remains reachable by horizontal scrolling.
- [ ] Use VoiceOver to identify the dock, app names, and active status.
- [ ] Restart Altdock: display/auto-hide preferences persist, while native appearance is captured afresh after a normal quit. A crash recovery reuses its original appearance snapshot.
- [ ] Confirm only the two intended system Dock preferences change while Altdock runs and both are restored on quit.

### Displays, full screen, and lifecycle

- [ ] Select each connected display. Membership and panel position follow that display, including monitors above or left of the main display.
- [ ] Disconnect the selected display: the dock falls back to the primary display. Reconnect it: it returns to the saved display when the ID is unchanged.
- [ ] Enter and leave full-screen apps and Split View; evaluate whether macOS allows the auxiliary panel there.
- [ ] Change display scaling and the system Dock’s size/location/auto-hide settings: Altdock remains on screen.
- [ ] Sleep and wake the Mac: membership refreshes without duplicate panels or timers.
- [ ] Move the app to `/Applications`, enable Launch at Login, and log out/in. Disable it and verify it no longer launches.
- [ ] Open the bundled app twice: only one dock/status item remains.
- [ ] Quit Altdock: its panel and status item disappear, with other apps unaffected.
