pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property bool bluetoothEnabled: false
    property bool discovering: false
    property var connectedDevices: []
    property var availableDevices: []
    property var pairedDevices: []
    property string errorMessage: ""
    property string actionKind: "" // pair | connect | disconnect | forget
    property string actionAddress: ""
    property string actionStatus: "idle" // idle | running | success | error
    property string actionError: ""
    property bool refreshQueued: false
    property bool actionOutputReceived: false
    property bool actionAwaitingRefresh: false
    property bool actionRefreshQueued: false
    property bool actionOutcomeOk: false
    property string actionOutcomeError: ""

    readonly property string refreshScript: String.raw`
import json
import re
import subprocess

ADDRESS_RE = re.compile(r"^Device\s+([0-9A-Fa-f:]{17})\s+(.+)$")

def run(args, timeout=8):
    try:
        return subprocess.run(args, text=True, capture_output=True, timeout=timeout)
    except Exception as exc:
        return None

def parse_devices(output):
    devices = {}
    for line in output.splitlines():
        match = ADDRESS_RE.match(line.strip())
        if match:
            devices[match.group(1).upper()] = match.group(2).strip()
    return devices

def parse_bool(value):
    return value.strip().lower() in ("yes", "true", "1")

def info_for(address, fallback_name=""):
    item = {
        "address": address,
        "name": fallback_name,
        "connected": False,
        "paired": False,
        "trusted": False,
        "battery": None,
        "icon": "",
    }
    proc = run(["bluetoothctl", "info", address])
    if not proc or proc.returncode != 0:
        return item
    for raw in proc.stdout.splitlines():
        line = raw.strip()
        if line.startswith("Name:"):
            item["name"] = line.split(":", 1)[1].strip()
        elif line.startswith("Alias:") and not item["name"]:
            item["name"] = line.split(":", 1)[1].strip()
        elif line.startswith("Icon:"):
            item["icon"] = line.split(":", 1)[1].strip()
        elif line.startswith("Paired:"):
            item["paired"] = parse_bool(line.split(":", 1)[1])
        elif line.startswith("Trusted:"):
            item["trusted"] = parse_bool(line.split(":", 1)[1])
        elif line.startswith("Connected:"):
            item["connected"] = parse_bool(line.split(":", 1)[1])
        elif "Battery Percentage:" in line:
            match = re.search(r"\((\d+)\)", line)
            if match:
                item["battery"] = int(match.group(1))
    return item

result = {
    "bluetoothEnabled": False,
    "discovering": False,
    "connectedDevices": [],
    "availableDevices": [],
    "pairedDevices": [],
    "errorMessage": "",
}

show = run(["bluetoothctl", "show"])
if show is None or show.returncode != 0:
    result["errorMessage"] = "bluetoothctl show failed"
    print(json.dumps(result))
    raise SystemExit(0)

for raw in show.stdout.splitlines():
    line = raw.strip()
    if line.startswith("Powered:"):
        result["bluetoothEnabled"] = parse_bool(line.split(":", 1)[1])
    elif line.startswith("Discovering:"):
        result["discovering"] = parse_bool(line.split(":", 1)[1])

all_devices = {}
for command in (["bluetoothctl", "devices"], ["bluetoothctl", "devices", "Paired"], ["bluetoothctl", "devices", "Connected"]):
    proc = run(command)
    if proc and proc.returncode == 0:
        all_devices.update(parse_devices(proc.stdout))

items = [info_for(address, name) for address, name in sorted(all_devices.items(), key=lambda pair: pair[1].lower())]
result["connectedDevices"] = [item for item in items if item["connected"]]
result["pairedDevices"] = [item for item in items if item["paired"]]
result["availableDevices"] = items
print(json.dumps(result))
`

    readonly property string scanScript: String.raw`
import json
import subprocess

SCAN_SECONDS = 8
try:
    proc = subprocess.run(["bluetoothctl", "--timeout", str(SCAN_SECONDS), "scan", "on"], text=True, capture_output=True, timeout=SCAN_SECONDS + 5)
    print(json.dumps({"ok": proc.returncode == 0, "errorMessage": proc.stderr.strip() or proc.stdout.strip()}))
except Exception as exc:
    print(json.dumps({"ok": False, "errorMessage": str(exc)}))
`

    readonly property string actionScript: String.raw`
import json
import subprocess
import sys

action = sys.argv[1] if len(sys.argv) > 1 else ""
address = sys.argv[2] if len(sys.argv) > 2 else ""
commands = {
    "power-on": ["bluetoothctl", "power", "on"],
    "power-off": ["bluetoothctl", "power", "off"],
    "connect": ["bluetoothctl", "connect", address] if address else None,
    "disconnect": ["bluetoothctl", "disconnect", address] if address else None,
    "pair": ["bluetoothctl", "pair", address] if address else None,
    "forget": ["bluetoothctl", "remove", address] if address else None,
}
command = commands.get(action)
if not command:
    print(json.dumps({"ok": False, "errorMessage": "invalid bluetooth action"}))
    raise SystemExit(0)
try:
    proc = subprocess.run(command, text=True, capture_output=True, timeout=30)
    print(json.dumps({"ok": proc.returncode == 0, "errorMessage": proc.stderr.strip() or proc.stdout.strip()}))
except Exception as exc:
    print(json.dumps({"ok": False, "errorMessage": str(exc)}))
`

    function applyState(payload) {
        bluetoothEnabled = !!payload.bluetoothEnabled
        // Keep the optimistic scan flag while our own bounded scan is in flight;
        // the adapter may not report Discovering yet, and the periodic refresh
        // must not clear the pill's "Scanning…" state mid-scan.
        if (!scanProcess.running)
            discovering = !!payload.discovering
        connectedDevices = payload.connectedDevices || []
        pairedDevices = payload.pairedDevices || []
        availableDevices = payload.availableDevices || []
        errorMessage = payload.errorMessage || ""
    }

    function refresh() {
        if (refreshProcess.running) {
            refreshQueued = true
            return
        }
        refreshProcess.command = ["python3", "-c", refreshScript]
        refreshProcess.running = true
    }

    function actionSnapshotConfirmed() {
        if (!actionOutcomeOk || !actionAddress)
            return actionOutcomeOk
        const all = (connectedDevices || []).concat(availableDevices || [])
        let device = null
        for (const item of all) {
            if (item && String(item.address || "").toUpperCase() === actionAddress) {
                device = item
                break
            }
        }
        if (actionKind === "pair")
            return !!device && (!!device.paired || !!device.trusted)
        if (actionKind === "connect")
            return !!device && !!device.connected
        if (actionKind === "disconnect")
            return !device || !device.connected
        if (actionKind === "forget")
            return !device
        return true
    }

    function finishActionRefresh() {
        actionAwaitingRefresh = false
        if (actionOutcomeOk && !actionSnapshotConfirmed()) {
            actionOutcomeOk = false
            actionOutcomeError = "Bluetooth state did not refresh"
        }
        actionStatus = actionOutcomeOk ? "success" : "error"
        actionError = actionOutcomeOk ? "" : (actionOutcomeError || "Bluetooth action failed")
        if (!actionOutcomeOk)
            errorMessage = actionError
    }

    function scan() {
        if (scanProcess.running)
            return
        discovering = true
        scanProcess.command = ["python3", "-c", scanScript]
        scanProcess.running = true
    }

    function setBluetoothEnabled(enabled) {
        runAction(enabled ? "power-on" : "power-off")
    }

    function connectDevice(address) {
        return address ? runAction("connect", address) : false
    }

    function disconnectDevice(address) {
        return address ? runAction("disconnect", address) : false
    }

    function pairDevice(address) {
        return address ? runAction("pair", address) : false
    }

    function forgetDevice(address) {
        return address ? runAction("forget", address) : false
    }

    function runAction(action, address) {
        if (actionProcess.running || actionStatus === "running")
            return false
        actionKind = action
        actionAddress = String(address || "").toUpperCase()
        actionStatus = "running"
        actionError = ""
        errorMessage = ""
        actionOutputReceived = false
        actionAwaitingRefresh = false
        actionOutcomeOk = false
        actionOutcomeError = ""
        actionProcess.command = ["python3", "-c", actionScript, action, address || ""]
        actionProcess.running = true
        return true
    }

    function finishActionProcess() {
        if (!actionOutputReceived) {
            actionOutcomeOk = false
            actionOutcomeError = "Bluetooth action returned no result"
        }
        actionAwaitingRefresh = true
        actionRefreshQueued = refreshProcess.running
        refresh()
    }

    Process {
        id: refreshProcess
        property bool outputReceived: false
        stdout: SplitParser {
            onRead: data => {
                refreshProcess.outputReceived = true
                try {
                    const payload = JSON.parse(data.trim())
                    root.applyState(payload)
                    if (root.actionAwaitingRefresh && payload.errorMessage) {
                        root.actionOutcomeOk = false
                        root.actionOutcomeError = payload.errorMessage
                    }
                } catch (error) {
                    root.errorMessage = String(error)
                    if (root.actionAwaitingRefresh) {
                        root.actionOutcomeOk = false
                        root.actionOutcomeError = String(error)
                    }
                }
            }
        }
        onStarted: outputReceived = false
        onExited: {
            if (!outputReceived && root.actionAwaitingRefresh) {
                root.actionOutcomeOk = false
                root.actionOutcomeError = "Bluetooth refresh returned no result"
            }
            if (root.actionAwaitingRefresh && root.actionRefreshQueued)
                root.actionRefreshQueued = false
            else if (root.actionAwaitingRefresh)
                root.finishActionRefresh()
            if (root.refreshQueued) {
                root.refreshQueued = false
                root.refresh()
            }
        }
    }

    Process {
        id: scanProcess
        property bool outputReceived: false
        stdout: SplitParser {
            onRead: data => {
                scanProcess.outputReceived = true
                try {
                    const payload = JSON.parse(data.trim())
                    root.errorMessage = payload.ok ? "" : (payload.errorMessage || "Bluetooth scan failed")
                } catch (error) {
                    root.errorMessage = String(error)
                }
            }
        }
        onStarted: outputReceived = false
        onExited: {
            if (!outputReceived)
                root.errorMessage = "Bluetooth scan returned no result"
            root.discovering = false
            root.refresh()
        }
    }

    Process {
        id: actionProcess
        property bool outputReceived: false
        stdout: SplitParser {
            onRead: data => {
                actionProcess.outputReceived = true
                root.actionOutputReceived = true
                try {
                    const payload = JSON.parse(data.trim())
                    root.actionOutcomeOk = payload.ok === true
                    root.actionOutcomeError = root.actionOutcomeOk ? "" : (payload.errorMessage || "Bluetooth action failed")
                } catch (error) {
                    root.actionOutcomeOk = false
                    root.actionOutcomeError = String(error)
                }
            }
        }
        onStarted: outputReceived = false
        onExited: root.finishActionProcess()
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
