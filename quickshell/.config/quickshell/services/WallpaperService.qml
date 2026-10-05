pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"

Item {
    id: root

    readonly property string wallpaperDirectory: "~/Pictures/Wallpapers"
    readonly property string currentPathFile: Quickshell.statePath("wallpaper/path.txt")
    property var wallpapers: []
    property string currentPath: ""
    property string errorMessage: ""
    property bool daemonStarted: false
    property bool restoredAtStartup: false
    property bool previewActive: false
    property string previewOriginalPath: ""
    property string previewPath: ""

    readonly property var imageExtensions: [".jpg", ".jpeg", ".png", ".webp", ".avif", ".bmp", ".gif"]
    readonly property var transitionTypes: ["none", "simple", "fade", "left", "right", "top", "bottom", "wipe", "wave", "grow", "center", "any", "outer", "random"]

    function validTransition(value) {
        return transitionTypes.indexOf(value) >= 0 ? value : "fade"
    }

    function refresh() {
        if (scanProcess.running)
            return
        errorMessage = ""
        scanProcess.running = true
    }

    function startPreview() {
        if (previewActive)
            return
        previewOriginalPath = currentPath
        previewPath = currentPath
        previewActive = true
    }

    function previewWallpaper(path) {
        if (!previewActive)
            startPreview()
        if (!path || path === previewPath)
            return
        if (!wallpapers.some(item => item.path === path)) {
            errorMessage = "Wallpaper is not in the catalog"
            return
        }
        previewPath = path
        applyWallpaper(path)
    }

    function commitPreview(path) {
        if (!path || !wallpapers.some(item => item.path === path)) {
            errorMessage = "Wallpaper is not in the catalog"
            return
        }
        previewActive = false
        previewOriginalPath = ""
        previewPath = ""
        currentPath = path
        writeCurrentPath(path)
        if (applyTimer.pendingPath !== path)
            applyWallpaper(path)
    }

    function cancelPreview() {
        if (!previewActive)
            return
        const original = previewOriginalPath
        previewActive = false
        previewOriginalPath = ""
        previewPath = ""
        if (original)
            applyWallpaper(original, Theme.wallpaperTransitionDuration, true)
    }

    function applyWallpaper(path, durationOverride, immediate) {
        if (!path || path.length === 0) {
            errorMessage = "No wallpaper selected"
            return
        }
        if (!daemonStarted) {
            Quickshell.execDetached(["awww-daemon"])
            daemonStarted = true
        }
        applyTimer.pendingPath = path
        applyTimer.pendingTransitionDuration = durationOverride !== undefined && Number(durationOverride) > 0
            ? Number(durationOverride)
            : Theme.wallpaperTransitionDuration
        if (immediate) {
            applyTimer.stop()
            executePendingWallpaper()
        } else {
            applyTimer.restart()
        }
    }

    function setWallpaper(path) {
        cancelPreview()
        for (let i = 0; i < wallpapers.length; i++) {
            if (wallpapers[i].path !== path)
                continue
            currentPath = path
            writeCurrentPath(path)
            applyWallpaper(path)
            return
        }
        errorMessage = "Wallpaper is not in the catalog"
    }

    function setRandom() {
        if (wallpapers.length === 0) {
            errorMessage = "No wallpapers found"
            return
        }
        const next = wallpapers[Math.floor(Math.random() * wallpapers.length)]
        setWallpaper(next.path)
    }

    function writeCurrentPath(path) {
        // FileView persists setText() when blockWrites is enabled; no separate
        // adapter write is needed and skipping it keeps the save atomic.
        currentPathFileView.setText(path + "\n")
    }

    function restoreCurrentWallpaper() {
        if (restoredAtStartup || currentPath === "" || wallpapers.length === 0)
            return
        if (!wallpapers.some(item => item.path === currentPath))
            return
        restoredAtStartup = true
        applyWallpaper(currentPath)
    }

    function relativeName(path) {
        const marker = "/Pictures/Wallpapers/"
        const markerIndex = path.indexOf(marker)
        return markerIndex >= 0 ? path.slice(markerIndex + marker.length) : path
    }

    function rebuildCatalog(text) {
        const entries = []
        const lines = text.split("\n")
        for (let i = 0; i < lines.length; i++) {
            const path = lines[i].trim()
            if (!path || path.endsWith("/"))
                continue
            const lower = path.toLowerCase()
            let supported = false
            for (let j = 0; j < imageExtensions.length; j++) {
                if (lower.endsWith(imageExtensions[j])) {
                    supported = true
                    break
                }
            }
            if (!supported)
                continue
            const relativePath = relativeName(path)
            const slash = relativePath.lastIndexOf("/")
            entries.push({
                path: path,
                relativePath: relativePath,
                name: slash >= 0 ? relativePath.slice(slash + 1) : relativePath
            })
        }
        entries.sort((a, b) => a.relativePath.localeCompare(b.relativePath))
        wallpapers = entries
        if (currentPath !== "" && !entries.some(item => item.path === currentPath))
            currentPath = ""
        restoreCurrentWallpaper()
    }

    Process {
        id: scanProcess
        command: ["sh", "-c", "find \"$HOME/Pictures/Wallpapers\" -type f -print 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: root.rebuildCatalog(text)
        }
    }

    FileView {
        id: currentPathFileView
        path: root.currentPathFile
        preload: true
        blockWrites: true
        atomicWrites: true
        printErrors: false
        watchChanges: true
        onLoaded: {
            const path = text().trim()
            if (path.length > 0) {
                root.currentPath = path
                root.restoreCurrentWallpaper()
            }
        }
        onLoadFailed: root.currentPath = ""
    }

    function executePendingWallpaper() {
        const enabled = Theme.animationEnabled("wallpaper.apply")
        const transition = enabled ? root.validTransition(Theme.wallpaperTransition) : "none"
        const command = ["awww", "img", "--transition-type", transition]
        if (transition !== "none") {
            command.push("--transition-step", String(Theme.wallpaperTransitionStep))
            if (transition !== "simple")
                command.push("--transition-duration", String(applyTimer.pendingTransitionDuration))
            command.push("--transition-fps", String(Theme.wallpaperTransitionFps))
        }
        command.push(applyTimer.pendingPath)
        Quickshell.execDetached(command)
    }

    Timer {
        id: applyTimer
        property string pendingPath: ""
        property real pendingTransitionDuration: 0
        interval: Theme.wallpaperPreviewDelay
        repeat: false
        onTriggered: root.executePendingWallpaper()
    }

    Component.onCompleted: refresh()
}
