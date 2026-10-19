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

## Manual acceptance checklist

### Current Space

- [ ] Run `--list-spaces`: the backend is SkyLight and apps from inactive Spaces are already listed, without visiting those Spaces.
- [ ] Open different apps on two Spaces. Switch Spaces: cached icons replace the previous list without flashing the empty-state message or resizing to its width.
- [ ] Create a new Space and switch to it immediately: an unknown destination does not temporarily claim to be empty. A confirmed empty destination does show the empty state.
- [ ] Open two windows from one app: there is one icon. Changing window stacking order does not reorder existing icons.
- [ ] Move the last window for an app to another Space: its icon disappears.
- [ ] Minimize the last window and hide its app: verify membership against `--list-spaces`. If WindowServer retains that window’s membership, its icon stays. Quitting removes the icon.
- [ ] Cover a window with another app: its Space membership remains valid.
- [ ] Visit an empty Space: the empty-state message appears, not stale icons.
- [ ] Switch Spaces rapidly and during launch/termination: old-Space icons do not persist.
- [ ] Use Mission Control and Stage Manager; check membership again after leaving their transition states.

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
- [ ] Grant permission: maximize a normal window. Its bottom edge clears Altdock while its top, left, and width remain unchanged. Repeat more than twice, including animated zooms; later user maximizations must still be adjusted.
- [ ] Test a window without the optional `AXFullScreen` attribute and a size-resizable window with read-only position. Neither should be rejected solely for that missing capability.
- [ ] Cause one delayed/failed AX resize: verify bounded retry rather than permanent suppression. Inspect the diagnostic for the reason.
- [ ] Test left/right halves and bottom quarters, including macOS's tile margins. Ordinary floating windows and top-only tiles are untouched.
- [ ] Test dialogs, full-screen windows, minimized windows, and fixed/minimum-size apps. Unsupported writes must not repeatedly shrink or oscillate windows.
- [ ] Switch between Spaces with many/few apps: reserved height remains stable despite icon shrinking or an empty Space.
- [ ] Move/resize a managed window manually: Altdock does not restore a stale original frame over that placement.
- [ ] Run a competing tiling manager: after a bounded retry Altdock yields instead of continually fighting its layout.
- [ ] Disable Reserve Space, hide Altdock, or enable auto-hide: only unchanged Altdock-adjusted windows are restored. Auto-hide edge reveals do not resize windows.
- [ ] Change icon size/display and disconnect a monitor. Verify correct coordinates and guarded restoration.
- [ ] Revoke Accessibility while running: stop adjusting windows without crashes; restore permission and verify recovery.

### System Dock borrowing and restoration

- [ ] Record the original Dock position and auto-hide setting. Launch Altdock: position becomes right and auto-hide becomes enabled. No size, magnification, pinned-icon, or delay preference changes.
- [ ] Start with right/auto-hide already enabled: no unnecessary Dock restart or rewrite.
- [ ] Quit normally: both original values return, and `~/Library/Application Support/Altdock/system-dock.json` is removed after successful restoration. No guardian remains.
- [ ] Force-quit only the main Altdock process: the helper restores both settings. The helper has `--restore-dock-after-exit` in its arguments; killing it as well prevents immediate recovery.
- [ ] For a controlled recovery test, terminate both processes, then relaunch and quit Altdock: restore the original pre-session settings, not the temporary right/auto-hide values.
- [ ] Launch a second instance: it must not overwrite the existing original-settings record or change preferences on exit.
- [ ] Confirm diagnostics (`--list-spaces`, `--list-current-space`) neither modify system Dock preferences nor request Accessibility.
- [ ] Do not expect arbitrary application-window frames to be restored after force quit; only the two system Dock settings have durable crash recovery.

### Presentation and settings

- [ ] Change icon size; enable and disable automatic hiding; hide and show Altdock from its status menu.
- [ ] With auto-hide enabled, reveal at the bottom edge, move to an icon, and open a context menu. The dock stays available during interaction and hides after leaving.
- [ ] Check both light/dark appearance and Reduce Motion/Reduce Transparency. Hover enlarges icons without clipping them; names appear on hover.
- [ ] Open enough apps to overflow the display. Every icon remains reachable by horizontal scrolling.
- [ ] Use VoiceOver to identify the dock, app names, and active status.
- [ ] Restart Altdock: icon size, display selection, and auto-hide persist.
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
