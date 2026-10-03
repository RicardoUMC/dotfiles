// Every Bar instance is created by the Variants delegate below and reads
// coordinator scope (root, overlayManager, notifications, systemStats).
// Declaring the capture explicitly is what qmllint asks for on those accesses,
// and it matches how Quickshell instantiates Variants delegates: with the
// delegate component's own creation context (core/variants.cpp).
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "bar"
import "launcher"
import "notifications"
import "osd"
import "theme"
import "services"

ShellRoot {
    id: root

    // Single reactive owner of the workspace-to-monitor assignment.
    // Hyprland mutates HyprlandWorkspace.monitor when a workspace moves to
    // another output, and that mutation notifies nothing on
    // Hyprland.workspaces, so every per-monitor filter needs one external
    // invalidation signal. Bar instances forward it to their workspace island;
    // no bar instance listens to the compositor for this itself.
    property int workspaceMonitorTick: 0

    // Signals re-emitted outward carry the name of the screen that produced
    // the event; overlay coordination is per-instance but session-global.
    signal rightControlCenterToggleRequested(string screenName)
    signal rightControlCenterSectionRequested(string screenName, string section)
    signal rightControlCenterOpened(string screenName)
    signal rightControlCenterClosed(string screenName)

    onRightControlCenterToggleRequested: screenName => overlayManager.open(screenName, "right-control-center")
    onRightControlCenterSectionRequested: (screenName, section) => overlayManager.openRightControlCenter(screenName, section)
    onRightControlCenterClosed: screenName => overlayManager.close(screenName, "right-control-center")

    IpcHandler {
        target: "launcher"
        // IPC triggers carry no screen identity; empty name resolves through
        // barForScreen()'s documented no-screen-intent path.
        function toggle() { overlayManager.open("", "launcher") }
    }

    IpcHandler {
        target: "powermenu"
        function toggle() { overlayManager.openRightControlCenter("", "power") }
    }

    IpcHandler {
        target: "wallpaper"
        function toggle() { overlayManager.open("", "wallpaper") }
        function set(path: string): void { WallpaperService.setWallpaper(path) }
        function random(): void { WallpaperService.setRandom() }
    }

    IpcHandler {
        target: "notifications"
        function toggleSound() {
            notifications.soundMuted = !notifications.soundMuted
        }
    }

    // Manual config reload. The shell is launched with QS_DISABLE_FILE_WATCHER=1
    // (see hyprland.conf exec-once), so saved QML no longer hot-reloads by
    // itself: the watcher used to fire mid-edit and load partially written
    // multi-file changes. Apply-and-verify is therefore deliberate — call this
    // only once a complete, coherent change is on disk.
    IpcHandler {
        target: "shellreload"
        // Soft reload keeps process state and re-reads the config graph.
        function soft() { Quickshell.reload(false) }
        // Hard reload tears the whole shell down and rebuilds it.
        function hard() { Quickshell.reload(true) }
    }

    // Anti-serial-conflict timer — owned by overlayManager logic but must live
    // in ShellRoot. Exactly one shared timer for the whole session: global
    // overlay exclusivity means there is never more than one pending open.
    Timer {
        id: overlayOpenTimer
        interval: 50
        repeat: false
        onTriggered: overlayManager._doOpen(overlayManager._pendingScreenName, overlayManager._pendingOpen)
    }

    // Resolves which connected screens get a Bar. Selection matches by
    // ShellScreen.name only — never by index or ordering. "all" (default)
    // means every screen; an array of names means only the screens whose
    // name matches, and unmatched names are ignored. If the resolved list
    // comes out empty — a named monitor was unplugged, or a name was
    // typo'd — it FALLS BACK TO ALL SCREENS so the session is never left
    // without a bar. The screens binding re-evaluates on screensChanged,
    // so hot-plug adds and removes bar instances without a reload.
    QtObject {
        id: screenSelector

        readonly property var screens: Quickshell.screens
        readonly property var selection: Theme.barScreens

        readonly property var enabledScreens: {
            const all = []
            const count = screens.length
            for (let i = 0; i < count; i++) all.push(screens[i])
            if (typeof selection !== "object" || selection === null)
                return all
            const named = []
            for (let i = 0; i < selection.length; i++) {
                for (let j = 0; j < count; j++) {
                    if (screens[j].name === selection[i]) {
                        named.push(screens[j])
                        break
                    }
                }
            }
            // Fallback: never leave the session without a bar.
            return named.length > 0 ? named : all
        }
    }

    // Resolve the Bar instance for a screen identity. Every open/close
    // command and every bar-geometry read in this file goes through this
    // helper — never through an arbitrary instance. Returns null when no
    // instance exists for the identity (unknown screen, or the delegate is
    // not built yet); callers must handle null without acting on stale
    // geometry. An empty identity means "no screen intent" (IPC/keybind
    // triggers) and resolves to the first available instance.
    function barForScreen(name) {
        const instances = barVariants.instances
        if (instances === null) return null
        for (let i = 0; i < instances.length; i++) {
            const instance = instances[i]
            if (instance === null) continue
            if (name === "") return instance
            if (instance.screenName === name) return instance
        }
        return null
    }

    // Overlay state is session-GLOBAL: at most one overlay is open across all
    // screens at any time, represented by one activeOverlay plus its owning
    // activeScreenName. An overlay renders on the screen that requested it —
    // through that screen's Bar instance — and opening from another screen
    // first closes the previous owner's overlay on its own screen, then opens
    // the requester's after the single shared 50 ms timer.
    QtObject {
        id: overlayManager

        property string activeOverlay: ""
        property string activeScreenName: ""
        // Logical content path model (odd/tasks/interaction-tree-routing.md).
        // activeOverlay stays the single global root identity; activeSection is
        // the right-control-center child content ("" = aggregate landing). The
        // derived activePath is the one truth source for relationship
        // comparisons: same node toggles closed, a sibling switches locally,
        // a different root closes globally. Child components keep emitting
        // intent upward; no component-to-component calls. Descendant shape is
        // reserved for later, not implemented:
        //   right-control-center/audio/device-panel
        property string activeSection: ""
        readonly property string activePath: {
            if (activeOverlay === "") return ""
            if (activeOverlay === "right-control-center")
                return activeSection === "" ? "right-control-center" : "right-control-center/" + activeSection
            return activeOverlay
        }
        property string _pendingOpen: ""
        property string _pendingScreenName: ""
        property string _pendingRightControlCenterSection: ""

        // Build the full logical path for a right-control-center section.
        // Centralized here so no visual component hardcodes path literals.
        function rightControlCenterPath(section) {
            return section === "" ? "right-control-center" : "right-control-center/" + section
        }

        function open(screenName, name) {
            if (activeOverlay === name && activeScreenName === screenName) { _closeActive(); return }
            _pendingRightControlCenterSection = ""
            _closeActive()
            _pendingScreenName = screenName
            _pendingOpen = name
            overlayOpenTimer.restart()
        }

        function openRightControlCenter(screenName, section) {
            const targetPath = rightControlCenterPath(section)
            if (activeOverlay === "right-control-center" && activeScreenName === screenName) {
                // Same screen, same root. Same path toggles closed through the
                // re-entrancy-guarded _closeActive(); a different child switches
                // sibling content locally without tearing down the global root
                // or restarting the 50 ms timer.
                if (activePath === targetPath) { _closeActive(); return }
                const bar = root.barForScreen(screenName)
                if (bar !== null) {
                    bar.openRightControlCenterSection(section)
                    activeSection = section
                }
                return
            }
            // Different root or different screen: preserve the global
            // close-then-open behavior through the shared timer. A rapid second
            // request replaces the pending path instead of queueing a duplicate.
            _closeActive()
            _pendingRightControlCenterSection = section
            _pendingScreenName = screenName
            _pendingOpen = "right-control-center"
            overlayOpenTimer.restart()
        }

        function close(screenName, name) {
            if (activeOverlay === name && activeScreenName === screenName) { _closeActive() }
        }

        function closeAll() { _closeActive() }

        function _closeActive() {
            // Clear activeOverlay first to prevent re-entrant calls from closed() signals
            const current = activeOverlay
            const ownerScreenName = activeScreenName
            activeOverlay = ""
            activeScreenName = ""
            activeSection = ""
            if (current === "") return
            if (current === "launcher") { launcher.visible = false; return }
            if (current === "wallpaper") { wallpaperSelector.visible = false; return }
            // The owning instance may already be gone (monitor unplugged):
            // its surfaces were destroyed with it, state is cleared above.
            const bar = root.barForScreen(ownerScreenName)
            if (bar === null) return
            if (current === "mpris") bar.closeMpris()
            if (current === "metrics") bar.closeMetrics()
            if (current === "center-panel") bar.closeCenterPanel()
            if (current === "right-control-center") bar.closeRightControlCenter()
        }

        function _doOpen(screenName, name) {
            if (name === "launcher") {
                launcher.toggleOpen()
                activeOverlay = name
                activeScreenName = screenName
                return
            }
            if (name === "wallpaper") {
                wallpaperSelector.toggleOpen()
                activeOverlay = name
                activeScreenName = screenName
                return
            }
            const bar = root.barForScreen(screenName)
            if (bar === null) return  // No instance on that screen — nothing to open.
            if (name === "mpris") bar.openMpris()
            if (name === "metrics") bar.openMetrics()
            if (name === "center-panel") bar.openCenterPanel()
            if (name === "right-control-center") {
                bar.openRightControlCenterSection(_pendingRightControlCenterSection)
                activeSection = _pendingRightControlCenterSection
            }
            _pendingRightControlCenterSection = ""
            activeOverlay = name
            activeScreenName = screenName
        }
    }

    // Single-instance engines and compositor orchestration. Bar instances
    // consume injected state; they must never create their own pollers or
    // drive compositor-wide refreshes.
    SystemStats { id: systemStats }

    // Initial toplevel refresh — Hyprland may not report toplevels immediately
    // on startup. Owned here (once) so per-monitor components stay pure.
    Timer {
        interval: 2000
        running: true
        repeat: false
        onTriggered: Hyprland.refreshToplevels()
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            const n = event.name
            if (n === "openwindow" || n === "closewindow" || n === "movewindow")
                Hyprland.refreshToplevels()
            // Both spellings of the move event reach this socket; either one
            // invalidates the per-monitor workspace filter. A move also changes
            // what each monitor is showing, and no event carries the monitor
            // identity needed to repoint every monitor's activeWorkspace, so the
            // authoritative re-read is owned here too (Quickshell dedupes
            // overlapping requests internally).
            if (n === "moveworkspace" || n === "moveworkspacev2") {
                root.workspaceMonitorTick++
                Hyprland.refreshMonitors()
            }
            // Workspace/window transitions are global focus loss and close the
            // active overlay regardless of which screen emitted them. `activewindow`
            // is deliberately NOT in this list: it fires on the panel's own
            // OnDemand keyboard-focus transition the moment a right-control-center
            // opens, so treating it as a focus-loss event closed the panel it was
            // supposed to keep open. Explicit backdrop click and Escape remain the
            // focus-loss/close paths for interactive panels.
            if (["workspace","workspacev2","moveworkspace","movewindow","fullscreen"].includes(n))
                overlayManager.closeAll()
        }
    }

    // One Bar instance per resolved screen. The instance's own overlay
    // surfaces (power menu, MPRIS popup, metrics dropdown, center-panel
    // catcher, right control center) are nested PanelWindows inside the bar
    // surface, so they render on the bar's screen — which under global
    // exclusivity is the screen that requested the overlay.
    Variants {
        id: barVariants
        model: screenSelector.enabledScreens

        delegate: Bar {
            id: barInstance
            required property ShellScreen modelData

            screen: modelData
            screenName: modelData === null ? "" : modelData.name
            // Hyprland monitor behind this bar's screen, injected so no
            // per-screen component resolves compositor identity itself.
            // Hyprland.monitorFor() is a plain invokable that emits nothing,
            // so the monitor model is read here as a dependency: Quickshell can
            // publish a screen before Hyprland publishes its monitor list
            // (startup) or replace it during a hot-plug, and this binding must
            // re-resolve when that happens instead of sticking at null.
            // modelData itself can still be unassigned while the delegate is
            // being created, which logged a TypeError here once per startup, so
            // both dereferences below are guarded.
            hyprlandMonitor: {
                if (modelData === null) return null
                const knownMonitors = Hyprland.monitors.values
                if (knownMonitors.length === 0) return null
                return Hyprland.monitorFor(modelData)
            }
            notificationsState: notifications
            systemStatsState: systemStats.dataState
            workspaceMonitorTick: root.workspaceMonitorTick

            // Per-instance signal routing: these inline handlers fire only for
            // this bar, so every event carries its own screen identity and the
            // coordinator can command the exact instance that emitted it. Bar
            // instances never talk to each other; all coordination lives here.
            onMprisClosed: overlayManager.close(barInstance.screenName, "mpris")
            onMetricsClosed: overlayManager.close(barInstance.screenName, "metrics")
            onCenterPanelToggleRequested: overlayManager.open(barInstance.screenName, "center-panel")
            onCenterPanelClosed: overlayManager.close(barInstance.screenName, "center-panel")
            onRightControlCenterToggleRequested: root.rightControlCenterToggleRequested(barInstance.screenName)
            onRightControlCenterSectionRequested: section => root.rightControlCenterSectionRequested(barInstance.screenName, section)
            onRightControlCenterOpened: root.rightControlCenterOpened(barInstance.screenName)
            onRightControlCenterClosed: root.rightControlCenterClosed(barInstance.screenName)
        }
    }

    LauncherCentered {
        id: launcher
        onDismissed: overlayManager.close("", "launcher")
        onOutsideClicked: (x, y) => {
            // The launcher now pins itself to the focused screen, so the bar it
            // must defer to is that instance, not an arbitrary one: a null
            // target (focus unresolvable at open time) still routes through
            // barForScreen()'s documented no-screen-intent path.
            const launcherScreen = launcher.targetScreen
            const bar = root.barForScreen(launcherScreen === null ? "" : launcherScreen.name)
            if (bar === null) return
            // Interactive height of that instance, not Theme.barRailHeight: the
            // rail token is 4px, so the old test could never be true over chips
            // that are Theme.barChipHeight tall inside a bar of roughly
            // Theme.barHeight, and every click on the bar just closed the
            // launcher. reservedBarContentHeight is the same value the bar hands
            // the compositor as its exclusive zone.
            const inBar = y < bar.reservedBarContentHeight
            if (!inBar) return
            if (x >= bar.powerBtnGlobalX) {
                overlayManager.openRightControlCenter(bar.screenName, "power")
            } else if (bar.mprisChipActive
                       && x >= bar.mprisChipGlobalX - bar.mprisChipWidth / 2
                       && x <= bar.mprisChipGlobalX + bar.mprisChipWidth / 2) {
                bar.setMprisAnchor()
                overlayManager.open(bar.screenName, "mpris")
            }
        }
    }

    WallpaperSelector {
        id: wallpaperSelector
        onDismissed: overlayManager.close("", "wallpaper")
    }

    Notifications { id: notifications }

    OsdWindow {}
}
