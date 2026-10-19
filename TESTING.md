# Testing Altdock

## Automated checks

```sh
./scripts/test.sh
./scripts/build-app.sh
codesign --verify --strict --verbose=2 dist/Altdock.app
plutil -lint Resources/Info.plist
dist/Altdock.app/Contents/MacOS/Altdock --list-current-space
```

The core suites cover current-display filtering, off-screen exclusion, window-layer and transparency filtering, self/agent exclusion, deduplication, stable ordering, empty Spaces, negative display coordinates, icon sizing, overflow, and avoiding the system Dock.

These are deterministic unit tests, not proof of macOS Space reporting or permission-dependent app activation. The checklist below must also be performed on a real Mac. It is a test plan, not a record that every scenario has passed.

## Manual acceptance checklist

### Current Space

- [ ] Open different apps on two Spaces. Switch Spaces: only apps with qualifying windows on the dock’s display appear after the transition settles.
- [ ] Open two windows from one app: there is one icon. Changing window stacking order does not reorder existing icons.
- [ ] Move the last window for an app to another Space: its icon disappears.
- [ ] Minimize the last window, hide the app, and quit the app in separate checks: each removes the icon. Restoring a qualifying window brings it back.
- [ ] Cover a window with another app: check macOS still reports the covered window as on-screen.
- [ ] Visit an empty Space: the empty-state message appears, not stale icons.
- [ ] Switch Spaces rapidly and during launch/termination: old-Space icons do not persist.
- [ ] Use Mission Control and Stage Manager; check membership again after leaving their transition states.

### Application switching

- [ ] Click each icon: its app activates; the frontmost indicator updates.
- [ ] Give one app windows in multiple Spaces. Enable Accessibility, then click it from each Space: check whether the local window is raised. Repeat with identical window geometries to evaluate the documented ambiguity.
- [ ] Deny Accessibility: filtering still works; switching falls back to standard macOS activation without repeatedly prompting.
- [ ] Open the context menu: Open, Hide, and Quit behave normally. Quit an app with unsaved work and confirm its save prompt is respected.
- [ ] Close a window immediately before clicking its stale icon: Altdock does not launch another instance or restore unrelated windows.

### Presentation and settings

- [ ] Change icon size; enable and disable automatic hiding; hide and show Altdock from its status menu.
- [ ] With auto-hide enabled, reveal at the bottom edge, move to an icon, and open a context menu. The dock stays available during interaction and hides after leaving.
- [ ] Check both light/dark appearance and Reduce Motion/Reduce Transparency. Hover enlarges icons without clipping them; names appear on hover.
- [ ] Open enough apps to overflow the display. Every icon remains reachable by horizontal scrolling.
- [ ] Use VoiceOver to identify the dock, app names, and active status.
- [ ] Restart Altdock: icon size, display selection, and auto-hide persist.
- [ ] Confirm Apple’s Dock preferences are unchanged.

### Displays, full screen, and lifecycle

- [ ] Select each connected display. Membership and panel position follow that display, including monitors above or left of the main display.
- [ ] Disconnect the selected display: the dock falls back to the primary display. Reconnect it: it returns to the saved display when the ID is unchanged.
- [ ] Enter and leave full-screen apps and Split View; evaluate whether macOS allows the auxiliary panel there.
- [ ] Change display scaling and the system Dock’s size/location/auto-hide settings: Altdock remains on screen.
- [ ] Sleep and wake the Mac: membership refreshes without duplicate panels or timers.
- [ ] Move the app to `/Applications`, enable Launch at Login, and log out/in. Disable it and verify it no longer launches.
- [ ] Open the bundled app twice: only one dock/status item remains.
- [ ] Quit Altdock: its panel and status item disappear, with other apps unaffected.
