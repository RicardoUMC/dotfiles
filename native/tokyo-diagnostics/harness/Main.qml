import QtQuick
import QtQuick.Window
import Tokyo.Diagnostics

Window {
    id: root
    visible: true
    width: 640
    height: 360
    title: "Tokyo.Diagnostics harness"
    color: "#171D23"
    property string lifecycleStatus: nativeProbeLifecycleExercise
        ? "scheduled; waiting for initial active child"
        : "disabled; normal harness mode"
    property string lifecyclePhase: "idle"
    property bool lifecycleComponentReady: false

    function failLifecycle(message) {
        root.lifecycleStatus = "failure; " + message
        console.error("[subsurface-lifecycle] FAILURE: " + message)
        readinessTimer.stop()
        lifecycleUpdateTimer.stop()
        replacementTimeoutTimer.stop()
        lifecycleDisableTimer.stop()
        lifecycleQuitTimer.stop()
        Qt.exit(1)
    }

    function observeActive() {
        if (!nativeProbeLifecycleExercise || !root.lifecycleComponentReady || !probe.active)
            return
        if (root.lifecyclePhase === "waiting-initial") {
            root.lifecyclePhase = "initial-active"
            root.lifecycleStatus = "initial active; child IDs surface=" + probe.surfaceId
                + " subsurface=" + probe.subsurfaceId
            console.info("[subsurface-lifecycle] initial active: wl_surface=" + probe.surfaceId
                + " wl_subsurface=" + probe.subsurfaceId)
            readinessTimer.stop()
            lifecycleUpdateTimer.start()
        } else if (root.lifecyclePhase === "waiting-replacement") {
            root.lifecyclePhase = "replacement-active"
            root.lifecycleStatus = "replacement active; child IDs surface=" + probe.surfaceId
                + " subsurface=" + probe.subsurfaceId
            console.info("[subsurface-lifecycle] replacement active: wl_surface=" + probe.surfaceId
                + " wl_subsurface=" + probe.subsurfaceId)
            replacementTimeoutTimer.stop()
            lifecycleDisableTimer.start()
        }
    }

    DiagnosticBridge {
        id: bridge
    }

    SubsurfaceProbe {
        id: probe
        enabled: nativeProbeOptIn || nativeProbeLifecycleExercise
        placeBelow: nativeProbePlaceBelow
        targetWindow: root
        geometry: Qt.rect(18, 18, 180, 72)
        onStatusChanged: {
            if (nativeProbeLifecycleExercise)
                console.info("[subsurface-lifecycle] probe status: " + status)
        }
        onActiveChanged: root.observeActive()
    }

    Timer {
        id: readinessTimer
        interval: 2000
        repeat: false
        onTriggered: {
            if (!probe.active)
                root.failLifecycle("initial active child not observed within 2000ms")
        }
    }

    Timer {
        id: lifecycleUpdateTimer
        interval: 300
        repeat: false
        onTriggered: {
            root.lifecyclePhase = "waiting-replacement"
            root.lifecycleStatus = "update; geometry replacement requested; waiting for replacement active"
            console.info("[subsurface-lifecycle] update: geometry replacement requested")
            probe.geometry = Qt.rect(24, 22, 160, 64)
            replacementTimeoutTimer.start()
        }
    }

    Timer {
        id: replacementTimeoutTimer
        interval: 2000
        repeat: false
        onTriggered: root.failLifecycle("replacement active child not observed within 2000ms")
    }

    Timer {
        id: lifecycleDisableTimer
        interval: 300
        repeat: false
        onTriggered: {
            root.lifecyclePhase = "final-disable"
            root.lifecycleStatus = "final disable; explicitly tearing down active replacement"
            console.info("[subsurface-lifecycle] final disable: probe.enabled = false; active IDs surface="
                + probe.surfaceId + " subsurface=" + probe.subsurfaceId)
            probe.enabled = false
            lifecycleQuitTimer.start()
        }
    }

    Timer {
        id: lifecycleQuitTimer
        interval: 300
        repeat: false
        onTriggered: {
            root.lifecyclePhase = "complete"
            root.lifecycleStatus = "quit; teardown grace period elapsed; active IDs surface="
                + probe.surfaceId + " subsurface=" + probe.subsurfaceId
            console.info("[subsurface-lifecycle] quit cleanly after teardown grace; active IDs surface="
                + probe.surfaceId + " subsurface=" + probe.subsurfaceId
                + "; last destroyed surface=" + probe.lastDestroyedSurfaceId
                + " subsurface=" + probe.lastDestroyedSubsurfaceId)
            Qt.quit()
        }
    }

    Component.onCompleted: {
        if (!nativeProbeLifecycleExercise)
            return
        root.lifecycleComponentReady = true
        root.lifecyclePhase = "waiting-initial"
        console.info("[subsurface-lifecycle] readiness gate started; waiting for initial active child")
        if (probe.active)
            root.observeActive()
        else
            readinessTimer.start()
    }

    Column {
        anchors.centerIn: parent
        spacing: 10

        Text {
            text: "Tokyo.Diagnostics"
            color: "#70E1E8"
            font.pixelSize: 26
        }
        Text { text: bridge.buildIdentity; color: "#E7EDF2" }
        Text { text: "Status: " + bridge.status; color: "#E7EDF2"; wrapMode: Text.Wrap }
        Text { text: "Passive: " + bridge.passive + "    Surface creation: " + bridge.surfaceCreationSupported; color: "#E7EDF2" }
        Text { text: "Capabilities: " + bridge.capabilityState; color: "#E7EDF2"; wrapMode: Text.Wrap }
        Text { text: bridge.diagnosticSummary(); color: "#AAB7C4"; wrapMode: Text.Wrap }
        Text { text: "Probe opt-in: " + probe.enabled + "  active: " + probe.active + "  backend: " + probe.backend; color: "#E7EDF2" }
        Text { text: "Requested order: " + (probe.placeBelow ? "below-parent" : "above-parent"); color: "#E7EDF2" }
        Text { text: "Lifecycle: " + root.lifecycleStatus; color: "#8BE9FD"; wrapMode: Text.Wrap }
        Text { text: "Ordering: " + probe.ordering + "\n" + probe.status; color: "#FFB86C"; wrapMode: Text.Wrap }
    }
}
