# Requirements

Altdock is a macOS Dock at alternative that displays only apps and minimized windows in the current MacOS Desktop/Space

**Functional requirements** describe UI/UX and features. **Non-functional requirements** describe performance, reliability, privacy, compatibility, and delivery.

## EARS notation

Requirements use the [Easy Approach to Requirements Syntax](https://alistairmavin.com/ears/):

| Pattern | Form used here |
| --- | --- |
| Ubiquitous | Altdock shall ... |
| Event-driven | When ..., Altdock shall ... |
| State-driven | While ..., Altdock shall ... |
| Unwanted behavior | If ..., then Altdock shall ... |
| Optional feature | Where ... is included, Altdock shall ... |
| Combined | While ..., when ..., Altdock shall ... |

Each requirement has an ID and uses **shall** to say what Altdock must do.

## Terms

- **Desktop:** an ordinary macOS Space, excluding native full-screen and Split View Spaces.
- **Local:** assigned to the active Desktop on the selected display, with window bounds intersecting that display.
- **Eligible window:** a nondegenerate, nontransparent, normal-layer window of a regular application other than Altdock, with verified Space membership, that is either ordered in or confirmed minimized through Accessibility. A window need not currently be on-screen to be ordered in on another Desktop.
- **Movable window:** an eligible, ordered-in window assigned exclusively to the source Desktop and intersecting the selected display. Minimized/hidden ordered-out windows, shared/all-Desktop windows, and native full-screen Spaces are excluded from menu-driven moves.
- **Focused window:** the selected application's Accessibility-reported focused window, not an arbitrary sibling or another application's window.
- **Origin Desktop:** the last exclusive ordinary Desktop observed for a window before that same process/window identity entered native full screen.
- **Original Dock settings:** the saved values and presence/absence of native Dock preferences before Altdock changes them. A retained crash-recovery record takes precedence over the temporary settings currently in effect.
- **Points:** macOS logical display points, not physical pixels.

A cached window list can briefly fall behind macOS. A failed query does not mean that a window has closed or a Desktop has been deleted.

## Functional requirements

### Controls and display selection

References: [DockPreferences.swift](Sources/Altdock/DockPreferences.swift), [StatusMenuController.swift](Sources/Altdock/StatusMenuController.swift).

- **AD-PLAT-003** — Altdock shall expose menu-bar controls for dock visibility, automatic hiding, space reservation, display selection, and launch at login.
- **AD-PLAT-004** — When the user selects a display, Altdock shall show its dock on that display.
- **AD-PLAT-005** — If the selected display is unavailable and another display is available, then Altdock shall use the primary display rather than leave its dock inaccessible off-screen.
- **AD-PLAT-006** — When the user changes launch-at-login behavior, Altdock shall request the corresponding macOS login-item registration or removal.
- **AD-PLAT-007** — If macOS requires approval for a login item, then Altdock shall direct the user to the relevant system settings.
- **AD-PLAT-008** — While no display is available, Altdock shall keep its dock panels hidden.

### Desktop membership and discovery

References: [SpaceWindowTracker.swift](Sources/Altdock/SpaceWindowTracker.swift), [SpaceApplications.swift](Sources/AltdockCore/SpaceApplications.swift), [current-Desktop checks](TESTING.ai.md#current-space).

- **AD-DISC-001** — While verified Space information is available, Altdock shall display application icons only for applications with eligible local windows.
- **AD-DISC-002** — Altdock shall display at most one application icon per process on each Desktop, independently of that process's window count.
- **AD-DISC-003** — When a successful discovery reports that an application has no eligible windows on a Desktop, Altdock shall remove its application icon from that Desktop.
- **AD-DISC-004** — Altdock shall exclude ordered-out auxiliary windows unless Accessibility confirms that the corresponding window is genuinely minimized.
- **AD-DISC-005** — Altdock shall exclude merely hidden, non-minimized, ordered-out windows from fresh eligible-window results.
- **AD-DISC-006** — While a window is assigned to multiple Desktops, Altdock shall represent its application on each Desktop where it otherwise qualifies.
- **AD-DISC-007** — Altdock shall maintain discovery data for inactive Desktops without requiring the user to visit them first.
- **AD-DISC-010** — While public fallback is active, Altdock shall identify that reduced capability in its status information.

### Dock panels and visibility

References: [DockPanelController.swift](Sources/Altdock/DockPanelController.swift), [DockSurface.swift](Sources/Altdock/DockSurface.swift).

- **AD-PANEL-001** — While per-Space rendering is available, Altdock shall maintain one persistent panel for each known ordinary Desktop on the selected display.
- **AD-PANEL-002** — When the user switches Desktops, Altdock shall present the destination Desktop's cached content without substituting the outgoing Desktop's icons.
- **AD-PANEL-004** — While a Desktop is confirmed empty or has no known destination-specific content, Altdock shall keep its panel hidden without an empty-state message, spinner, or visible blank dock.
- **AD-PANEL-005** — When a Desktop is removed, Altdock shall dispose of that Desktop's panel.
- **AD-PANEL-007** — When the user hides Altdock, Altdock shall hide all of its dock panels.
- **AD-PANEL-008** — When Altdock quits normally, Altdock shall close all of its dock panels.
- **AD-PANEL-009** — While automatic hiding is enabled, Altdock shall allow only the active Desktop's panel to respond to the selected display's reveal edge.

### Appearance, animation, and accessibility

References: [DockStyle.swift](Sources/AltdockCore/DockStyle.swift), [DockGeometry.swift](Sources/AltdockCore/DockGeometry.swift), [DockMembershipAnimation.swift](Sources/Altdock/DockMembershipAnimation.swift).

- **AD-UI-001** — Altdock shall use the native Dock's original edge, base icon size, and footprint captured before native-Dock suppression.
- **AD-UI-002** — Altdock shall place its panels eight points inside the physical bottom, left, or right display edge, rather than add a stale native-Dock work-area inset.
- **AD-UI-003** — Altdock shall size panel length according to its application icons and minimized-window tiles, subject to available display space.
- **AD-UI-004** — If dock content exceeds the available length, then Altdock shall provide scrolling without shrinking the captured base icon size.
- **AD-UI-005** — Altdock shall center application icons across the dock's thickness independently of their running indicators.
- **AD-UI-006** — Altdock shall distinguish the frontmost application's running indicator from other running applications' indicators.
- **AD-UI-007** — While a populated Space-bound panel is visible on its Desktop and Reduce Motion is off, when its membership changes, Altdock shall animate insertion/removal and the corresponding panel-size change.
- **AD-UI-008** — While Reduce Motion is enabled, Altdock shall suppress membership movement animations.
- **AD-UI-009** — When presenting an inactive, previously hidden, newly initialized, or compatibility-mode panel, Altdock shall avoid replaying membership animations from another Desktop.
- **AD-UI-010** — Altdock shall follow the system appearance and support Reduce Transparency and meaningful VoiceOver names, states, and actions.

### Hover labels

References: [DockTooltipController.swift](Sources/Altdock/DockTooltipController.swift).

- **AD-HOVER-002** — Altdock shall place hover labels above a bottom dock or toward the desktop from a side dock without resizing the dock or intercepting clicks.
- **AD-HOVER-003** — Altdock shall render hover labels in a single-line, rounded label using a 13-point regular system font, expanding to fit the name within the available screen width.
- **AD-HOVER-004** — If a label exceeds the available screen width, then Altdock shall ellipsize it rather than wrap it onto multiple lines.
- **AD-HOVER-005** — When hover ends, a menu starts tracking, the Space changes, or the anchor becomes unavailable, Altdock shall dismiss the corresponding hover label.

### Application activation

References: [ApplicationActivator.swift](Sources/Altdock/ApplicationActivator.swift).

- **AD-ACT-001** — When the user activates an application icon, Altdock shall recheck local window membership before selecting an activation target.
- **AD-ACT-002** — While the selected app is active and its focused window is eligible locally and confirmed not minimized, when its icon is clicked, Altdock shall preserve that window's focus instead of raising a sibling.
- **AD-ACT-003** — If the selected app's focused window is not local, then Altdock shall select an eligible local window rather than treat the app's active state alone as sufficient.
- **AD-ACT-004** — If precise Accessibility-based activation is unavailable, then Altdock shall retain best-effort application activation without automatically requesting permission.
- **AD-ACT-005** — If an action comes from a stale outgoing-Desktop panel, then Altdock shall reject it rather than activate an unrelated Desktop's window.

### Minimized windows

References: [MinimizedWindowReader.swift](Sources/Altdock/MinimizedWindowReader.swift), [DockMinimizedWindow.swift](Sources/Altdock/DockMinimizedWindow.swift), [minimized-window checks](TESTING.ai.md#separate-minimized-window-tiles).

- **AD-MIN-001** — When Accessibility confirms an eligible window is minimized, Altdock shall retain its application's icon on the corresponding Desktop.
- **AD-MIN-002** — Altdock shall display each eligible minimized window as a separate tile after the application-icon section.
- **AD-MIN-003** — Altdock shall identify minimized-window tiles with a window title or fallback identity and an application badge, without requiring live screenshots.
- **AD-MIN-004** — Altdock shall center the minimized-section separator between the preceding application icon's visible artwork and the first minimized window card.
- **AD-MIN-005** — When the user clicks a minimized-window tile or selects its Restore action, Altdock shall restore only that selected window after verifying its current identity, Desktop, and minimized state.
- **AD-MIN-006** — If a restore target is closed, already restored, nonlocal, or cannot be verified, then Altdock shall avoid substituting another window.
- **AD-MIN-007** — When discovery confirms a minimized window was restored or closed, Altdock shall remove only its corresponding minimized-window tile.
- **AD-MIN-008** — Altdock shall preserve the order of remaining minimized-window tiles across ordinary discovery refreshes.
- **AD-MIN-010** — While space reservation is disabled, Altdock shall continue observing supported minimize/restore notifications independently of reservation.

### Per-Desktop icon ordering

References: [DockIconDragState.swift](Sources/Altdock/DockIconDragState.swift), [DockIconOrder.swift](Sources/AltdockCore/DockIconOrder.swift).

- **AD-ORDER-001** — While per-Space rendering is active, when the user drags an application icon, Altdock shall preview its proposed order within that Desktop's application section.
- **AD-ORDER-002** — When a changed drag order is released inside the panel with valid source membership, Altdock shall commit the new order only for that Desktop.
- **AD-ORDER-003** — If a drag is canceled, released outside the panel, or invalidated by membership changes, then Altdock shall discard the drag preview.
- **AD-ORDER-004** — When a drag completes, Altdock shall prevent its mouse release from activating the application.
- **AD-ORDER-005** — When discovery temporarily omits applications or Desktops, Altdock shall retain their remembered ordering independently of visible membership for the current session.
- **AD-ORDER-006** — Altdock shall leave actual application-window Desktop assignments unchanged when icons are reordered.
- **AD-ORDER-007** — While shared-panel compatibility mode is active, Altdock shall disable per-Desktop icon reordering.

### New Window

References: [NewWindowCommand.swift](Sources/Altdock/NewWindowCommand.swift), [ApplicationWindowCreator.swift](Sources/Altdock/ApplicationWindowCreator.swift).

- **AD-NEW-001** — Altdock shall expose a New Window action in application-icon context menus.
- **AD-NEW-002** — When New Window is requested for a supported application, Altdock shall invoke that application's enabled, explicit normal-window creation command.
- **AD-NEW-003** — If the application has no recognized enabled command, including a single-window or unsupported application, then Altdock shall explain the limitation without launching another application instance.
- **AD-NEW-004** — Altdock shall avoid substituting an arbitrary New, New Tab, New Document, private/incognito, or other unrelated command for New Window.
- **AD-NEW-005** — When a New Window command has been submitted, Altdock shall check for a distinct ordered normal-layer window belonging to the same process before reporting verified creation.
- **AD-NEW-007** — When a new window is confirmed, Altdock shall attempt to bring that window forward without forcibly overriding the application's chosen Desktop placement.

### Moving windows between Desktops

References: [DesktopWindowMover.swift](Sources/Altdock/DesktopWindowMover.swift), [window-moving checks](TESTING.ai.md#moving-windows-between-desktops).

- **AD-MOVE-001** — Altdock shall expose separate application-icon actions named Move and Move Focused Window.
- **AD-MOVE-002** — Altdock shall list destination ordinary Desktops on the selected display in Mission Control order, excluding the source Desktop and full-screen Spaces.
- **AD-MOVE-003** — When the user selects Move, Altdock shall request movement only of the selected process's movable source-Desktop windows.
- **AD-MOVE-004** — When the user selects Move Focused Window, Altdock shall request movement only of that application's verified focused movable window.
- **AD-MOVE-005** — If the focused window is unavailable or not movable locally, then Altdock shall reject the focused-window move without selecting a sibling or moving the entire app.
- **AD-MOVE-006** — If the focused target, ownership, source Desktop, or destination changes before a focused-window move is submitted, then Altdock shall reject the stale request.
- **AD-MOVE-007** — Altdock shall avoid requesting a switch of the active Desktop as part of a menu-driven window move.
- **AD-MOVE-008** — When a move request is submitted, Altdock shall verify destination membership rather than equate submission with success.
- **AD-MOVE-010** — While the required backend or fixed source Desktop is unavailable, Altdock shall disable the move actions.
- **AD-MOVE-013** — If the source or destination Desktop is no longer valid before either move action is submitted, then Altdock shall reject the request.

### Full-screen windows

References: [FullScreenReturnController.swift](Sources/Altdock/FullScreenReturnController.swift), [full-screen return checks](TESTING.ai.md#returning-from-native-full-screen).

- **AD-FULL-001** — While the selected display is in a verified native full-screen or Split View Space, Altdock shall suppress its dock panels and hover labels on that display.
- **AD-FULL-002** — While an ordinary window is maximized on an ordinary Desktop, Altdock shall continue providing normal dock and reservation behavior.
- **AD-FULL-003** — When a window with a known origin Desktop enters native full screen, Altdock shall retain that origin for the same process/window identity during the session.
- **AD-FULL-004** — When that window leaves full screen and ordinary-Desktop membership has settled, Altdock shall return it to its surviving origin Desktop if necessary.
- **AD-FULL-005** — If the origin Desktop has been deleted, then Altdock shall use Desktop 1 in Mission Control order on the original display as the return destination.
- **AD-FULL-006** — If the original display has been disconnected, then Altdock shall use Desktop 1 on the primary display as the fallback return destination.
- **AD-FULL-007** — When automatically returning a window, Altdock shall leave its siblings, minimized/hidden state, and active-Desktop selection unchanged by the requested operation.
- **AD-FULL-008** — If a window has no reliable observed origin or its identity has been replaced, then Altdock shall avoid guessing an origin from another window.
- **AD-FULL-009** — Altdock shall leave ordinary resizing and deliberate Desktop moves outside a full-screen-return episode alone.

### Space reservation

References: [reservation implementation](Sources/Altdock/Reservation), [reservation checks](TESTING.ai.md#default-reservation-and-accessibility).

- **AD-RES-001** — If no reservation preference has been saved, then Altdock shall enable the Reserve Space preference without automatically prompting for Accessibility.
- **AD-RES-002** — While reservation is enabled, Accessibility is granted, Altdock is shown without auto-hide, and the active Space is an ordinary Desktop, Altdock shall keep eligible maximized/edge-tiled windows clear of its reserved strip.
- **AD-RES-003** — Altdock shall derive reserved clearance from the captured native Dock footprint plus four points, independently of the current icon count.
- **AD-RES-004** — Altdock shall avoid adding the old native-Dock work-area inset a second time when reserving space.
- **AD-RES-005** — Altdock shall leave ordinary floating, dialog, minimized, full-screen, non-resizable, and unverifiable windows outside automatic reservation adjustments.
- **AD-RES-006** — When reservation requires a resize, Altdock shall preserve the unaffected edges of the window for the selected bottom/left/right dock edge.
- **AD-RES-008** — While auto-hide, explicit Altdock hiding, or native full-screen suppression makes reservation inactive, Altdock shall suspend reservation writes.
- **AD-RES-009** — When reservation is released by disabling it, hiding Altdock, enabling auto-hide, changing its display/layout, or normal quit, Altdock shall attempt to restore only windows still matching its last applied adjustment.
- **AD-RES-010** — While a dock panel is hidden solely because its Desktop is empty or unresolved, Altdock shall retain reservation eligibility independently of panel visibility.

### Native Dock settings

References: [native Dock settings and recovery](Sources/Altdock/SystemDock).

Altdock manages these five settings in `com.apple.dock`: `orientation`, `autohide`, `tilesize`, `autohide-delay`, and `mineffect`.

- **AD-NATIVE-001** — When Altdock starts without a retained recovery record, Altdock shall save the original presence/value of all five approved preferences before changing them.
- **AD-NATIVE-002** — When Altdock starts, Altdock shall capture or recover its original native-Dock appearance before applying suppression.
- **AD-NATIVE-003** — When starting a native-Dock session, Altdock shall configure Apple's Dock on Altdock's original edge with auto-hide enabled, one-point icons, a 1,000-second auto-show delay, and the Scale minimize effect.
- **AD-NATIVE-004** — Altdock shall leave native Dock items, magnification, minimize-to-application, launch animation, and unrelated preferences unchanged.
- **AD-NATIVE-005** — When Altdock quits normally, Altdock shall restore all five saved preference values, deleting keys that were originally absent.

A thin native Dock strip may remain visible in Mission Control. Scale is still an animation; complete hiding and animation-free minimization are not required.

### Diagnostics

References: [diagnostic commands](README.ai.md#diagnosing-reservation-and-permission-problems).

- **AD-DIAG-001** — When the user requests panel or reservation status, Altdock shall report the running application's state rather than treat the diagnostic caller's Accessibility grant as the application's grant.
- **AD-DIAG-003** — When discovery diagnostics are run without launching the dock, Altdock shall leave native Dock preferences unchanged and avoid permission prompts.

## Non-functional requirements

### Platform and compatibility

References: [Package.swift](Package.swift), [SpaceWindowTracker.swift](Sources/Altdock/SpaceWindowTracker.swift), [reservation implementation](Sources/Altdock/Reservation).

- **AD-PLAT-001** — Altdock shall provide a native macOS application targeting macOS 13 or later.
- **AD-PLAT-002** — Altdock shall use Swift with native AppKit/SwiftUI interfaces and no third-party application dependencies.
- **AD-DISC-009** — If private Space discovery is unavailable, then Altdock shall provide a public on-screen-only fallback without guessing inactive-Desktop membership.
- **AD-PANEL-006** — If per-Space panel placement cannot be verified, then Altdock shall use a shared-panel fallback instead of displaying a panel on an unverified Desktop.
- **AD-RES-011** — Altdock shall implement reservation through guarded window adjustments rather than claim a change to macOS's global usable-screen rectangle.

### Performance and resource usage

References: [DockModel.swift](Sources/Altdock/DockModel.swift), [MinimizedWindowEvents.swift](Sources/Altdock/MinimizedWindowEvents.swift), [SystemDockPreferences.swift](Sources/Altdock/SystemDock/SystemDockPreferences.swift).

These requirements reduce unnecessary processing and keep interactions responsive. We haven't agreed on numerical limits for CPU usage, memory usage, battery consumption, or response time. Measurements in [RESEARCH.ai.md](RESEARCH.ai.md) are test results, not guarantees.

- **AD-PANEL-003** — When the user switches between already-known Desktops, Altdock shall preserve their existing panel identities and Desktop assignments.
- **AD-HOVER-001** — When the pointer enters an eligible icon, Altdock shall show its label without an intentional hover delay.
- **AD-MIN-009** — When a supported Accessibility minimize/restore notification arrives, Altdock shall schedule a coalesced discovery refresh without waiting for the next periodic scan.
- **AD-MOVE-011** — While a create/move action is pending, Altdock shall prevent duplicate create/move submissions.
- **AD-NATIVE-011** — Altdock shall avoid restarting the native Dock when the requested preference values are already applied.

### Reliability and recovery

References: [SpaceWindowTracker.swift](Sources/Altdock/SpaceWindowTracker.swift), [ApplicationWindowCreator.swift](Sources/Altdock/ApplicationWindowCreator.swift), [DesktopWindowMover.swift](Sources/Altdock/DesktopWindowMover.swift), [SystemDockSession.swift](Sources/Altdock/SystemDock/SystemDockSession.swift).

- **AD-DISC-008** — If discovery temporarily fails, then Altdock shall retain the last successful Desktop-specific cache rather than treat the failure as a confirmed empty Desktop.
- **AD-MIN-011** — If minimized-window state temporarily cannot be read, then Altdock shall retain prior confirmation only for still-present candidates with the same process and window identities.
- **AD-NEW-006** — If creation cannot be confirmed within the bounded verification period, then Altdock shall report the outcome as unconfirmed without automatically repeating the command.
- **AD-MOVE-009** — If a move fails or only partially succeeds, then Altdock shall report the outcome without blind retries or rollback of other windows.
- **AD-MOVE-012** — When Altdock stops, Altdock shall cancel pending create/move verification and follow-up work.
- **AD-RES-007** — If an adjustment cannot be verified, then Altdock shall use bounded retry/backoff and avoid overwriting intervening user or window-manager changes.
- **AD-NATIVE-006** — If the main Altdock process exits unexpectedly while its recovery helper remains available, then Altdock's recovery helper shall attempt restoration of the saved native Dock settings.
- **AD-NATIVE-007** — If a recovery record survives an interrupted session, then Altdock shall preserve its original settings rather than replace them with the temporary suppressed settings.
- **AD-NATIVE-008** — If restoration fails, then Altdock shall retain the recovery record for a later attempt.
- **AD-NATIVE-009** — If a recovery record is corrupt or another instance owns the session, then Altdock shall refuse to overwrite the saved originals or begin conflicting preference changes.
- **AD-NATIVE-010** — When upgrading a recovery record that did not capture a newly managed preference, Altdock shall capture that preference before first modifying it while preserving the older saved values.

### Privacy and security

References: [AccessibilityPermission.swift](Sources/Altdock/AccessibilityPermission.swift), [permissions and privacy](README.ai.md#space-semantics-and-permissions).

- **AD-SAFE-001** — When Altdock starts, Altdock shall check Accessibility status without automatically requesting permission.
- **AD-SAFE-002** — When the user explicitly requests Accessibility access, Altdock shall recheck the live grant before prompting.
- **AD-SAFE-003** — If Accessibility is already granted, then Altdock shall avoid displaying another permission prompt.
- **AD-SAFE-004** — Altdock shall avoid resetting TCC, weakening SIP, installing scripting additions, or modifying system-wide security policy to obtain window-management access.
- **AD-SAFE-005** — Altdock shall operate its dock and minimized-window tiles without requesting Screen Recording permission or capturing window screenshots.
- **AD-SAFE-006** — Altdock shall avoid recording ordinary keystroke contents or making network requests as part of normal dock operation.
- **AD-DIAG-002** — Altdock shall omit window titles and contents from its persisted panel/reservation diagnostics.

### Builds and code signing

References: [build scripts](scripts), [signing and distribution](README.ai.md#signing-and-distribution).

- **AD-BUILD-001** — The Altdock build process shall use a stable signing identity so ordinary rebuilds preserve the application's designated signing requirement.
- **AD-BUILD-002** — If the configured normal-build signing identity is missing or ambiguous, then the Altdock build process shall fail rather than silently switch to ad-hoc signing.
- **AD-BUILD-003** — The Altdock signing setup shall avoid writing unrequested private-key backup files or granting TLS/system-wide trust to the local signing certificate.

## Current limits

The current version has these limits:

- Closed apps cannot be pinned to Altdock.
- Icon order and remembered full-screen return Desktops last only until Altdock quits.
- Minimized-window tiles show titles and app badges, not live previews. They cannot be rearranged by dragging.
- Dragging does not auto-scroll. Scroll to the icons you want before rearranging them.
- New Window recognizes a small set of English menu commands. Other languages and app-specific commands need additional support. Some apps expose tabs as windows, so a new WindowServer ID does not always mean a separate window.
- Public on-screen fallback cannot reliably identify inactive-Desktop minimized windows or native full-screen Spaces.
- After a force quit, app windows may keep the sizes Altdock gave them. Restoring Apple's Dock settings is handled separately.
- The current plan does not include removing all polling, replacing Apple's Dock process, reproducing its menu arrow exactly, or distributing Altdock through the App Store.

## Verification and maintenance

Use [TESTING.ai.md](TESTING.ai.md) for manual checks and [Tests](Tests) for automated tests. Test window management, full-screen transitions, and multiple displays on real Macs too; passing unit tests doesn't guarantee that every app or macOS version works.

Keep the same requirement IDs when improving the wording. Update requirements when product decisions change. Record timing settings and performance measurements in [RESEARCH.ai.md](RESEARCH.ai.md); add performance targets here only once they've been agreed on.
