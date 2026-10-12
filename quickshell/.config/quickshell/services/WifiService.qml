pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property bool wifiEnabled: false
    property bool scanning: false
    property string scanStatus: "idle" // idle | scanning | success | error
    property string scanErrorMessage: ""
    property string activeSsid: ""
    property int activeSignal: 0
    property var networks: []
    property string errorMessage: ""
    property bool refreshQueued: false
    property bool scanOutputReceived: false
    property bool scanAwaitingRefresh: false
    property bool scanRefreshQueued: false
    property bool scanOutcomeOk: false
    property string scanOutcomeError: ""
    property bool actionOutputReceived: false

    readonly property string refreshScript: String.raw`
import json
import subprocess

def run(args):
    try:
        return subprocess.run(args, text=True, capture_output=True, timeout=8)
    except Exception as exc:
        return None

def split_terse(line):
    fields, current, escaped = [], "", False
    for char in line.rstrip("\n"):
        if escaped:
            current += char
            escaped = False
        elif char == "\\":
            escaped = True
        elif char == ":":
            fields.append(current)
            current = ""
        else:
            current += char
    fields.append(current)
    return fields

result = {
    "wifiEnabled": False,
    "activeSsid": "",
    "activeSignal": 0,
    "networks": [],
    "errorMessage": "",
}

radio = run(["nmcli", "-t", "-f", "WIFI", "radio"])
if radio is None or radio.returncode != 0:
    result["errorMessage"] = "nmcli radio query failed"
    print(json.dumps(result))
    raise SystemExit(0)

result["wifiEnabled"] = radio.stdout.strip().lower() == "enabled"

known_by_name = {}
connections = run(["nmcli", "-t", "-f", "NAME,UUID,TYPE", "connection", "show"])
if connections and connections.returncode == 0:
    for line in connections.stdout.splitlines():
        parts = split_terse(line)
        if len(parts) >= 3 and parts[2] == "802-11-wireless":
            known_by_name[parts[0]] = parts[1]

wifi = run(["nmcli", "-t", "-f", "SSID,SIGNAL,SECURITY,ACTIVE", "dev", "wifi", "list", "--rescan", "no"])
if wifi is None or wifi.returncode != 0:
    if not result["errorMessage"]:
        result["errorMessage"] = "nmcli wifi list failed"
    print(json.dumps(result))
    raise SystemExit(0)

seen = {}
for line in wifi.stdout.splitlines():
    parts = split_terse(line)
    if len(parts) < 4:
        continue
    ssid, signal_text, security, active_text = parts[:4]
    if not ssid:
        continue
    try:
        signal = int(signal_text)
    except ValueError:
        signal = 0
    active = active_text.strip().lower() in ("yes", "sí", "si", "true", "1")
    existing = seen.get(ssid)
    if existing and existing["signal"] >= signal and not active:
        continue
    item = {
        "ssid": ssid,
        "signal": signal,
        "security": security,
        "active": active,
        "known": ssid in known_by_name,
        "uuid": known_by_name.get(ssid, ""),
    }
    seen[ssid] = item
    if active:
        result["activeSsid"] = ssid
        result["activeSignal"] = signal

result["networks"] = sorted(seen.values(), key=lambda item: (not item["active"], -item["signal"], item["ssid"].lower()))
print(json.dumps(result))
`

    readonly property string scanScript: String.raw`
import json
import subprocess
try:
    proc = subprocess.run(["nmcli", "dev", "wifi", "rescan"], text=True, capture_output=True, timeout=20)
    print(json.dumps({"ok": proc.returncode == 0, "errorMessage": proc.stderr.strip()}))
except Exception as exc:
    print(json.dumps({"ok": False, "errorMessage": str(exc)}))
`

    readonly property string actionScript: String.raw`
import json
import subprocess
import sys

action = sys.argv[1] if len(sys.argv) > 1 else ""
args = sys.argv[2:]
commands = {
    "wifi-on": ["nmcli", "radio", "wifi", "on"],
    "wifi-off": ["nmcli", "radio", "wifi", "off"],
    "connect-known": ["nmcli", "connection", "up", "id", args[0]] if len(args) >= 1 else None,
    "connect-password": ["nmcli", "dev", "wifi", "connect", args[0], "password", args[1]] if len(args) >= 2 else None,
    "forget": ["nmcli", "connection", "delete", "uuid", args[0]] if len(args) >= 1 else None,
}
command = commands.get(action)
if not command:
    print(json.dumps({"ok": False, "errorMessage": "invalid wifi action"}))
    raise SystemExit(0)
try:
    proc = subprocess.run(command, text=True, capture_output=True, timeout=30)
    print(json.dumps({"ok": proc.returncode == 0, "errorMessage": proc.stderr.strip() or proc.stdout.strip()}))
except Exception as exc:
    print(json.dumps({"ok": False, "errorMessage": str(exc)}))
`

    function applyState(payload) {
        wifiEnabled = !!payload.wifiEnabled
        activeSsid = payload.activeSsid || ""
        activeSignal = payload.activeSignal || 0
        networks = payload.networks || []
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

    function scan() {
        if (scanning || scanProcess.running)
            return false
        scanning = true
        scanStatus = "scanning"
        scanErrorMessage = ""
        scanOutputReceived = false
        scanAwaitingRefresh = false
        scanOutcomeOk = false
        scanOutcomeError = ""
        scanProcess.command = ["python3", "-c", scanScript]
        scanProcess.running = true
        return true
    }

    function finishScanProcess() {
        if (!scanOutputReceived) {
            scanOutcomeOk = false
            scanOutcomeError = "Wi-Fi scan returned no result"
        }
        scanAwaitingRefresh = true
        scanRefreshQueued = refreshProcess.running
        refresh()
    }

    function finishScanRefresh() {
        scanning = false
        scanAwaitingRefresh = false
        scanStatus = scanOutcomeOk ? "success" : "error"
        scanErrorMessage = scanOutcomeOk ? "" : (scanOutcomeError || "Wi-Fi scan failed")
    }

    function setWifiEnabled(enabled) {
        runAction(enabled ? "wifi-on" : "wifi-off")
    }

    function connectKnown(uuidOrName) {
        if (!uuidOrName)
            return
        runAction("connect-known", [uuidOrName])
    }

    function connectWithPassword(ssid, password) {
        if (!ssid)
            return
        runAction("connect-password", [ssid, password || ""])
    }

    function forget(uuid) {
        if (!uuid)
            return
        runAction("forget", [uuid])
    }

    function runAction(action, args) {
        if (actionProcess.running)
            return
        const next = ["python3", "-c", actionScript, action]
        for (const arg of (args || []))
            next.push(String(arg))
        actionProcess.command = next
        actionProcess.running = true
        actionProcess.outputReceived = false
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
                    if (root.scanAwaitingRefresh && payload.errorMessage) {
                        root.scanOutcomeOk = false
                        root.scanOutcomeError = payload.errorMessage
                    }
                } catch (error) {
                    root.errorMessage = String(error)
                    if (root.scanAwaitingRefresh) {
                        root.scanOutcomeOk = false
                        root.scanOutcomeError = String(error)
                    }
                }
            }
        }
        onStarted: outputReceived = false
        onExited: {
            if (!outputReceived)
                root.errorMessage = "Wi-Fi refresh returned no result"
            if (root.scanAwaitingRefresh && root.scanRefreshQueued)
                root.scanRefreshQueued = false
            else if (root.scanAwaitingRefresh)
                root.finishScanRefresh()
            if (root.refreshQueued) {
                root.refreshQueued = false
                root.refresh()
            }
        }
    }

    Process {
        id: scanProcess
        stdout: SplitParser {
            onRead: data => {
                root.scanOutputReceived = true
                try {
                    const payload = JSON.parse(data.trim())
                    root.scanOutcomeOk = payload.ok === true
                    root.scanOutcomeError = root.scanOutcomeOk ? "" : (payload.errorMessage || "Wi-Fi scan failed")
                } catch (error) {
                    root.scanOutcomeOk = false
                    root.scanOutcomeError = String(error)
                }
            }
        }
        onExited: root.finishScanProcess()
    }

    Process {
        id: actionProcess
        property bool outputReceived: false
        stdout: SplitParser {
            onRead: data => {
                actionProcess.outputReceived = true
                try {
                    const payload = JSON.parse(data.trim())
                    root.errorMessage = payload.ok ? "" : (payload.errorMessage || "Wi-Fi action failed")
                } catch (error) {
                    root.errorMessage = String(error)
                }
            }
        }
        onExited: {
            if (!outputReceived)
                root.errorMessage = "Wi-Fi action returned no result"
            root.refresh()
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
