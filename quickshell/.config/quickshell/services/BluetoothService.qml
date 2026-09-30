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
        if (refreshProcess.running)
            return
        refreshProcess.command = ["python3", "-c", refreshScript]
        refreshProcess.running = true
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
        if (address)
            runAction("connect", address)
    }

    function disconnectDevice(address) {
        if (address)
            runAction("disconnect", address)
    }

    function pairDevice(address) {
        if (address)
            runAction("pair", address)
    }

    function forgetDevice(address) {
        if (address)
            runAction("forget", address)
    }

    function runAction(action, address) {
        if (actionProcess.running)
            return
        actionProcess.command = ["python3", "-c", actionScript, action, address || ""]
        actionProcess.running = true
    }

    Process {
        id: refreshProcess
        stdout: SplitParser {
            onRead: data => {
                try {
                    root.applyState(JSON.parse(data.trim()))
                } catch (error) {
                    root.errorMessage = String(error)
                }
                refreshProcess.running = false
            }
        }
    }

    Process {
        id: scanProcess
        stdout: SplitParser {
            onRead: data => {
                try {
                    const payload = JSON.parse(data.trim())
                    root.errorMessage = payload.ok ? "" : (payload.errorMessage || "Bluetooth scan failed")
                } catch (error) {
                    root.errorMessage = String(error)
                }
                root.discovering = false
                scanProcess.running = false
                root.refresh()
            }
        }
    }

    Process {
        id: actionProcess
        stdout: SplitParser {
            onRead: data => {
                try {
                    const payload = JSON.parse(data.trim())
                    root.errorMessage = payload.ok ? "" : (payload.errorMessage || "Bluetooth action failed")
                } catch (error) {
                    root.errorMessage = String(error)
                }
                actionProcess.running = false
                root.refresh()
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
