pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Wayland
import "../theme"

// Engine, not surface. The server, the sound player, both models, the DND/mute
// state and both persistence layers exist exactly once per session here, and the
// single toast PanelWindow below is a pure view of the live model. Product
// decision: notifications appear on ONE surface, on the currently focused
// screen, the same way the OSD behaves (osd/OsdWindow.qml). The engine/view
// split is deliberate — the root stays a plain non-surface Item so that no
// surface lifecycle can ever tear the data engine down.
Item {
    id: root

    // Retention and presentation are deliberately separate:
    //   historyModel — the store. Every notification lands here on arrival, whether
    //                  or not DND/mute suppressed it; a repeated id updates its row
    //                  in place instead of appending copies. Toast expiry never
    //                  removes an entry — only explicit dismissal or Clear all does.
    //   toastModel   — the transient on-screen surface, with its own lifecycle.
    // Two persistence layers guard the store, and exactly one of them hydrates it:
    //   historyStore (PersistentProperties) — carried between engine generations on
    //                  config reload, in-process only. Non-empty means "a reload
    //                  handed this instance its rows", which wins over disk.
    //   historyFile (FileView) — the same JSON snapshot on disk, which is what makes
    //                  the history survive a process restart or reboot.
    // `recentModel` stays the public name for the store, so the bar chip and control
    // center read retention rather than live toasts.
    property bool soundMuted: false
    property bool doNotDisturb: false
    property alias recentModel: historyModel

    // Eviction bound for the store: oldest rows are dropped first. The same bound
    // applies to what reaches disk, since the snapshot is serialized from the store.
    readonly property int maxHistoryEntries: 50

    // Hydration guard: exactly one restore per instance, whichever layer feeds it.
    property bool historyRestored: false

    // Plain-value history entries: { notifId, summary, body, appName, urgency, timestamp }.
    ListModel { id: historyModel }

    // Live toast entries: { notifId, summary, body, appName, urgency, timeout, notif }.
    // `notif` is a live object and therefore never leaves this model — the history
    // store holds no notification objects, only serializable values.
    ListModel { id: toastModel }

    // Reload handoff. "" is the sentinel for "nothing inherited", which is how a
    // cold start differs from a reload that legitimately carried an empty store.
    PersistentProperties {
        id: historyStore
        reloadableId: "notificationHistory"
        property string entries: ""

        // `loaded` fires once per instance: after taking properties from the
        // previous generation on a reload, and immediately on a cold start.
        onLoaded: root.restoreHistory()
    }

    // Disk snapshot, under the shell's XDG state directory (never the repository).
    // Verified against the installed Quickshell/Qt sources and observed standalone:
    //   atomicWrites -> QSaveFile writes a sibling temp file and renames over the
    //   target, so a crash mid-write leaves the previous snapshot intact;
    //   a missing parent directory chain is created on first write;
    //   blockWrites -> each mutation is committed before returning, so an immediate
    //   shell exit cannot drop the last write (measured cost: ~0.005 ms per write).
    // Reading a non-existent file yields an empty string and a loadFailed(FileNotFound)
    // signal rather than throwing, so printErrors stays off to keep a clean first run.
    readonly property string historyFilePath: Quickshell.statePath("notification-history.json")

    property FileView historyFile: FileView {
        path: root.historyFilePath
        preload: false
        blockLoading: true
        blockWrites: true
        atomicWrites: true
        printErrors: false

        onLoadFailed: code => {
            // A missing snapshot is normal on a fresh install; anything else is real.
            if (code !== FileViewError.FileNotFound)
                console.warn(`quickshell: could not read notification history ${root.historyFilePath}: ${FileViewError.toString(code)}`)
        }
        onSaveFailed: code => console.warn(`quickshell: could not persist notification history ${root.historyFilePath}: ${FileViewError.toString(code)}`)
    }

    // Origin key for retention. Normalised ONCE here and used by every path that
    // resolves a bucket — the arrival collapse, the id match, and the hydrate-time
    // fold — so the three can never disagree.
    //
    // Rule: the trimmed appName is the key. An absent (undefined/null), empty, or
    // whitespace-only appName all trim to "" and therefore share the ONE anonymous
    // bucket. That is deliberate: Ricardo's music player does not identify itself,
    // so its track changes — each carrying a fresh freedesktop id — all belong to
    // the same single row.
    //
    // Do NOT "fix" this into a per-summary or per-body bucket later. Keying on the
    // summary would give every distinct track title its own row, which is exactly
    // the event-volume retention that filled the cap and evicted real notifications.
    function originKey(appName) {
        return String(appName === undefined || appName === null ? "" : appName).trim()
    }

    function parseHistory(raw) {
        const items = []
        let parsed = null
        try {
            parsed = JSON.parse(raw)
        } catch (error) {
            parsed = null
        }
        if (!Array.isArray(parsed))
            return items

        for (let i = 0; i < parsed.length; i++) {
            const item = parsed[i]
            if (item === null || typeof item !== "object")
                continue
            const summary = typeof item.summary === "string" ? item.summary : ""
            const body = typeof item.body === "string" ? item.body : ""
            const appName = typeof item.appName === "string" ? item.appName : ""
            // Legacy or corrupted rows with nothing renderable are dropped.
            if (summary.length === 0 && body.length === 0 && appName.length === 0)
                continue
            items.push({
                notifId: typeof item.id === "number" ? item.id : 0,
                summary: summary,
                body: body,
                appName: appName,
                urgency: typeof item.urgency === "number" ? item.urgency : NotificationUrgency.Normal,
                timestamp: typeof item.timestamp === "number" ? item.timestamp : Date.now()
            })
        }
        // History predates origin collapsing and can legitimately contain several
        // rows for one origin (Ricardo's store holds 31 anonymous media rows right
        // now). Fold them on the way in rather than migrating on disk: the newest
        // row of each origin is kept — with its own id, so toast↔row matching for
        // the latest event still resolves — and the stale duplicates are dropped.
        // restoreHistory re-serialises after this, so the first load writes the
        // collapsed shape and the duplicates never come back. Nothing is cleared
        // and no origin is lost: 31 media rows become 1 media row, 13 blueman rows
        // become 1, and so on.
        const kept = []
        const seen = []
        for (let i = items.length - 1; i >= 0; i--) {
            const key = root.originKey(items[i].appName)
            if (seen.indexOf(key) !== -1)
                continue
            seen.push(key)
            kept.unshift(items[i])
        }
        return kept
    }

    function persistHistory() {
        // Do not write either layer until the store has been hydrated: a
        // notification that lands in the same event loop turn as a reload would
        // otherwise overwrite the rows it has not restored yet.
        if (!root.historyRestored)
            return
        const items = []
        for (let i = 0; i < historyModel.count; i++) {
            const entry = historyModel.get(i)
            items.push({
                id: entry.notifId,
                summary: entry.summary,
                body: entry.body,
                appName: entry.appName,
                urgency: entry.urgency,
                timestamp: entry.timestamp
            })
        }
        const snapshot = JSON.stringify(items)
        // Both layers get the same snapshot, so a reload handoff and the disk copy
        // never disagree about what the store held.
        historyStore.entries = snapshot
        root.historyFile.setText(snapshot)
    }

    function restoreHistory() {
        if (root.historyRestored)
            return
        root.historyRestored = true

        // Precedence, so the two layers can never both populate the model:
        // a non-empty reload handoff wins (it is the in-process truth and always at
        // least as fresh as disk); the disk snapshot is consulted only when nothing
        // was inherited, which is exactly the process-restart case.
        let raw = historyStore.entries
        if (raw.length === 0) {
            try {
                raw = root.historyFile.text()
            } catch (error) {
                raw = ""
            }
        }

        const items = parseHistory(raw)
        // Insert oldest-first at the head so a notification that landed before the
        // store settled keeps its place as the newest entry.
        for (let i = items.length - 1; i >= 0; i--)
            historyModel.insert(0, items[i])

        root.trimHistory()
        // Re-serialize so malformed or legacy rows are normalized for next time and
        // the reload handoff is filled in on a cold start.
        root.persistHistory()
    }

    function trimHistory() {
        while (historyModel.count > root.maxHistoryEntries)
            historyModel.remove(0)
    }

    // Newest-first row index for a notification id, or -1. Kept so a repeated
    // freedesktop id can be addressed at all.
    function historyIndexById(notifId) {
        for (let i = historyModel.count - 1; i >= 0; i--) {
            if (historyModel.get(i).notifId === notifId)
                return i
        }
        return -1
    }

    function recordHistory(notif) {
        const entry = {
            notifId:  notif.id,
            summary:  notif.summary,
            body:     notif.body,
            appName:  notif.appName,
            urgency:  notif.urgency,
            timestamp: Date.now()
        }

        // Id match first, so the in-place update rule for repeated freedesktop ids
        // (progress reports, media metadata) keeps working: it preserves the row
        // identity the toast and the control center address by.
        let index = root.historyIndexById(notif.id)
        if (index === -1) {
            // Origin collapse. Every notification whose id is new replaces the
            // newest row of its own origin instead of appending a second row, so
            // the store holds one row per origin and event volume can no longer
            // evict real history.
            const key = root.originKey(notif.appName)
            for (let i = historyModel.count - 1; i >= 0; i--) {
                if (root.originKey(historyModel.get(i).appName) !== key)
                    continue
                index = i
                break
            }
        }

        if (index !== -1) {
            // Remove-then-append relocates the row to the tail, which is the
            // newest position (the model is read newest-first by the control
            // center). set() would leave it stranded at its old index, showing an
            // old event's position with the newest event's content. persistHistory
            // below serialises the in-memory order, so disk follows it.
            historyModel.remove(index)
        }

        historyModel.append(entry)
        // The cap now bounds distinct origins rather than event volume, so
        // eviction is rare. It stays exactly as a safety bound against a runaway
        // emitter of distinct origins; do not remove it because collapsing eased
        // the pressure.
        root.trimHistory()
        root.persistHistory()
    }

    function removeHistoryById(notifId) {
        for (let i = historyModel.count - 1; i >= 0; i--) {
            if (historyModel.get(i).notifId === notifId) {
                historyModel.remove(i)
                root.persistHistory()
                return
            }
        }
    }

    Process {
        id: soundPlayer
        command: ["paplay", ""]
        running: false
    }

    function playSound(urgency) {
        if (root.soundMuted || root.doNotDisturb) return
        const base = "/usr/share/sounds/freedesktop/stereo/"
        if (urgency === NotificationUrgency.Critical)
            soundPlayer.command = ["paplay", base + "dialog-error.oga"]
        else if (urgency === NotificationUrgency.Low)
            soundPlayer.command = ["paplay", base + "message-new-instant.oga"]
        else
            soundPlayer.command = ["paplay", base + "dialog-information.oga"]
        soundPlayer.running = true
    }

    // Explicit dismissal from the control center: drops the stored entry and
    // closes the live toast carrying the same notification id, if still on screen.
    function dismissAt(index) {
        if (index < 0 || index >= historyModel.count)
            return
        const notifId = historyModel.get(index).notifId
        for (let i = toastModel.count - 1; i >= 0; i--) {
            const toast = toastModel.get(i)
            if (toast.notifId !== notifId)
                continue
            if (toast.notif)
                toast.notif.dismiss()
            toastModel.remove(i)
        }
        historyModel.remove(index)
        root.persistHistory()
    }

    // Toast-side close, addressed by notification id rather than row index.
    // `explicit` means the user resolved it (close button or an action), which
    // also removes it from the store; a timeout only takes the toast off screen
    // and leaves the record behind. There is exactly one toast surface, so one
    // row retires once, but id addressing is kept: the signal can be delivered
    // after the row was already removed by an explicit dismissal or Clear all,
    // and an id that is no longer in the model must close nothing.
    function closeToastById(notifId, explicit) {
        for (let i = toastModel.count - 1; i >= 0; i--) {
            const toast = toastModel.get(i)
            if (toast === null || toast.notifId !== notifId)
                continue
            if (explicit) {
                if (toast.notif)
                    toast.notif.dismiss()
                root.removeHistoryById(notifId)
            }
            toastModel.remove(i)
            return
        }
    }

    function clearAll() {
        for (let i = toastModel.count - 1; i >= 0; i--) {
            const toast = toastModel.get(i)
            if (toast && toast.notif)
                toast.notif.dismiss()
        }
        toastModel.clear()
        historyModel.clear()
        root.persistHistory()
    }

    NotificationServer {
        id: server
        keepOnReload: true

        onNotification: notif => {
            for (let i = 0; i < toastModel.count; i++) {
                if (toastModel.get(i).notifId === notif.id) {
                    toastModel.remove(i)
                    break
                }
            }

            // Retention first: recorded whether or not the toast will be shown.
            root.recordHistory(notif)

            const timeout = notif.expireTimeout > 0 ? notif.expireTimeout : 5000

            toastModel.append({
                notifId:  notif.id,
                summary:  notif.summary,
                body:     notif.body,
                appName:  notif.appName,
                urgency:  notif.urgency,
                timeout:  timeout,
                notif:    notif
            })

            root.playSound(notif.urgency)
        }
    }

    // Exactly one toast surface for the session, pinned to the focused monitor
    // the same way the OSD is (osd/OsdWindow.qml): resolved by matching
    // Hyprland.focusedMonitor.name against ShellScreen.name over
    // Quickshell.screens, never by index, never assuming a monitor count. The
    // earlier per-screen `Variants` duplicated the alert on every output; the
    // product decision is one alert, on the screen the user is looking at.
    //
    // Screen targeting stays explicit — an unpinned layer-shell surface gets a
    // null wl_output and lets the compositor pick. The resolved screen lands in
    // a plain property that `screen` reads and is written imperatively, because
    // ProxyWindowBase::setScreen unmaps and rebuilds a surface whose output
    // changes while it is mapped. Resolution therefore runs only on the
    // hidden-to-visible transition: a toast that is already on screen stays on
    // the screen it appeared on when a new notification arrives, and the surface
    // adopts the newly focused monitor the next time it is shown. No focused
    // monitor, or one with no matching ShellScreen (a hot-plug race), leaves the
    // previous pin untouched.
    //
    // This surface is a pure view. It reads the single shared toastModel and
    // reports closings back to the single engine above: no NotificationServer,
    // sound player, history ListModel, PersistentProperties handoff or FileView
    // snapshot lives here.
    PanelWindow {
        id: toastSurface

        // Explicit show/hide driven by the model rather than a binding, so the
        // hidden-to-visible edge is the single place where the screen pin moves.
        property ShellScreen targetScreen: null
        property bool wantsSurface: toastModel.count > 0 && !root.doNotDisturb

        screen: toastSurface.targetScreen
        visible: false

        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; right: true }
        margins { top: Theme.barHeight + Theme.spacingMd - 1; right: Theme.spacingMd - 1 }

        implicitWidth: 380
        implicitHeight: toastColumn.implicitHeight

        function resolveTargetScreen() {
            const focused = Hyprland.focusedMonitor
            if (!focused)
                return
            const screens = Quickshell.screens
            for (let i = 0; i < screens.length; i++) {
                if (screens[i].name === focused.name) {
                    toastSurface.targetScreen = screens[i]
                    return
                }
            }
            // Focused monitor with no live ShellScreen: keep the current pin.
        }

        function showSurface() {
            // Resolve only while unmapped: re-pointing a live layer surface is the
            // risky transition, and a toast stack already on screen must not be
            // torn down and rebuilt under the user.
            if (!toastSurface.visible)
                toastSurface.resolveTargetScreen()
            toastSurface.visible = true
        }

        // The surface maps and unmaps with the live model instead of staying
        // mapped at zero height: that hidden-to-visible edge is the only moment
        // the screen pin is allowed to move. Delegates still exist while the
        // surface is hidden (DND on), and their wall-clock Timers keep retiring
        // rows, so nothing piles up in the model.
        onWantsSurfaceChanged: {
            if (toastSurface.wantsSurface)
                toastSurface.showSurface()
            else
                toastSurface.visible = false
        }

        ColumnLayout {
            id: toastColumn
            width: parent.width
            spacing: Theme.spacingSm

            Repeater {
                model: toastModel

                delegate: NotificationToast {
                    required property var model

                    Layout.fillWidth: true

                    summary:  model.summary
                    body:     model.body
                    appName:  model.appName
                    urgency:  model.urgency
                    timeout:  model.timeout
                    notif:    model.notif

                    // Addressed by notification id, not by row index: a row can
                    // already be gone by the time this signal is delivered (an
                    // explicit dismissal from the control center, or Clear all),
                    // and closing by index would then retire the wrong toast.
                    onDismissed: root.closeToastById(model.notifId, true)
                    onTimedOut: root.closeToastById(model.notifId, false)
                }
            }
        }
    }
}
