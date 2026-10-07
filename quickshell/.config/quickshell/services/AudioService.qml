pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var outputs: []
    property var inputs: []
    property string defaultOutputId: ""
    property string defaultInputId: ""
    property int outputVolume: 0
    property int inputVolume: 0
    property bool outputMuted: false
    property bool inputMuted: false
    property string errorMessage: ""
    property string pendingAction: ""
    property string pendingValue: ""

    readonly property string refreshScript: String.raw`
import json
import re
import subprocess

LIST_RE = re.compile(r"^\s*(\d+)\s+([^\t]+?)\s+audio/(sink|source)\s*(\*)?\s*$")
VOLUME_RE = re.compile(r"Volume:\s*([0-9.]+)(?:\s+\[MUTED\])?")

def run(args, timeout=8):
    try:
        return subprocess.run(args, text=True, capture_output=True, timeout=timeout)
    except Exception:
        return None

def volume_for(target):
    proc = run(["wpctl", "get-volume", target])
    if not proc or proc.returncode != 0:
        return {"volume": 0, "muted": False}
    text = proc.stdout.strip()
    match = VOLUME_RE.search(text)
    if not match:
        return {"volume": 0, "muted": "[MUTED]" in text}
    return {"volume": round(float(match.group(1)) * 100), "muted": "[MUTED]" in text}

def inspect_name(identifier, fallback):
    proc = run(["wpctl", "inspect", identifier])
    if not proc or proc.returncode != 0:
        return fallback
    for raw in proc.stdout.splitlines():
        line = raw.strip().lstrip("* ").strip()
        if line.startswith("node.description ="):
            return line.split("=", 1)[1].strip().strip('"') or fallback
    return fallback

def list_devices(kind):
    proc = run(["wpctl", "list", "audio", kind])
    if not proc or proc.returncode != 0:
        return None
    devices = []
    for raw in proc.stdout.splitlines():
        match = LIST_RE.match(raw)
        if not match:
            continue
        identifier, raw_name, device_type, active_marker = match.groups()
        volume = volume_for(identifier)
        devices.append({
            "id": identifier,
            "name": inspect_name(identifier, raw_name.strip()),
            "type": device_type,
            "active": bool(active_marker),
            "volume": volume["volume"],
            "muted": volume["muted"],
        })
    return devices

result = {
    "outputs": [],
    "inputs": [],
    "defaultOutputId": "",
    "defaultInputId": "",
    "outputVolume": 0,
    "inputVolume": 0,
    "outputMuted": False,
    "inputMuted": False,
    "errorMessage": "",
}

outputs = list_devices("sinks")
inputs = list_devices("sources")
if outputs is None or inputs is None:
    result["errorMessage"] = "wpctl audio device query failed"
    print(json.dumps(result))
    raise SystemExit(0)

result["outputs"] = outputs
result["inputs"] = inputs
for item in outputs:
    if item["active"]:
        result["defaultOutputId"] = item["id"]
        result["outputVolume"] = item["volume"]
        result["outputMuted"] = item["muted"]
        break
for item in inputs:
    if item["active"]:
        result["defaultInputId"] = item["id"]
        result["inputVolume"] = item["volume"]
        result["inputMuted"] = item["muted"]
        break

if not result["defaultOutputId"]:
    default_output = volume_for("@DEFAULT_AUDIO_SINK@")
    result["outputVolume"] = default_output["volume"]
    result["outputMuted"] = default_output["muted"]
if not result["defaultInputId"]:
    default_input = volume_for("@DEFAULT_AUDIO_SOURCE@")
    result["inputVolume"] = default_input["volume"]
    result["inputMuted"] = default_input["muted"]

print(json.dumps(result))
`

    readonly property string actionScript: String.raw`
import json
import subprocess
import sys

action = sys.argv[1] if len(sys.argv) > 1 else ""
value = sys.argv[2] if len(sys.argv) > 2 else ""
commands = {
    "default-output": ["wpctl", "set-default", value] if value else None,
    "default-input": ["wpctl", "set-default", value] if value else None,
    "output-volume": ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", f"{max(0, min(100, int(value or 0))) / 100:.2f}"],
    "input-volume": ["wpctl", "set-volume", "@DEFAULT_AUDIO_SOURCE@", f"{max(0, min(100, int(value or 0))) / 100:.2f}"],
    "output-muted": ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "1" if value == "true" else "0"],
    "input-muted": ["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "1" if value == "true" else "0"],
}
command = commands.get(action)
if not command:
    print(json.dumps({"ok": False, "errorMessage": "invalid audio action"}))
    raise SystemExit(0)
try:
    proc = subprocess.run(command, text=True, capture_output=True, timeout=10)
    print(json.dumps({"ok": proc.returncode == 0, "errorMessage": proc.stderr.strip() or proc.stdout.strip()}))
except Exception as exc:
    print(json.dumps({"ok": False, "errorMessage": str(exc)}))
`

    function applyState(payload) {
        console.log("[audio-mute] refresh outputMuted=" + !!payload.outputMuted
                    + " inputMuted=" + !!payload.inputMuted)
        outputs = payload.outputs || []
        inputs = payload.inputs || []
        defaultOutputId = payload.defaultOutputId || ""
        defaultInputId = payload.defaultInputId || ""
        outputVolume = payload.outputVolume || 0
        inputVolume = payload.inputVolume || 0
        outputMuted = !!payload.outputMuted
        inputMuted = !!payload.inputMuted
        errorMessage = payload.errorMessage || ""
    }

    function refresh() {
        if (refreshProcess.running)
            return
        refreshProcess.command = ["python3", "-c", refreshScript]
        refreshProcess.running = true
    }

    function setDefaultOutput(id) {
        if (id)
            runAction("default-output", id)
    }

    function setDefaultInput(id) {
        if (id)
            runAction("default-input", id)
    }

    function setOutputVolume(percent) {
        runAction("output-volume", String(Math.max(0, Math.min(100, Math.round(percent)))))
    }

    function setInputVolume(percent) {
        runAction("input-volume", String(Math.max(0, Math.min(100, Math.round(percent)))))
    }

    function setOutputMuted(muted) {
        console.log("[audio-mute] setOutputMuted requested=" + muted)
        runAction("output-muted", muted ? "true" : "false")
    }

    function setInputMuted(muted) {
        console.log("[audio-mute] setInputMuted requested=" + muted)
        runAction("input-muted", muted ? "true" : "false")
    }

    function runAction(action, value) {
        const normalizedValue = value || ""
        if (actionProcess.running) {
            console.log("[audio-mute] queue action=" + action + " value=" + normalizedValue)
            // Do not drop a mute request that arrives while a slider action is
            // still being applied; execute the latest request after completion.
            pendingAction = action
            pendingValue = normalizedValue
            return
        }
        startAction(action, normalizedValue)
    }

    function startAction(action, value) {
        console.log("[audio-mute] start action=" + action + " value=" + value)
        actionProcess.command = ["python3", "-c", actionScript, action, value]
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
        id: actionProcess
        stdout: SplitParser {
            onRead: data => {
                try {
                    const payload = JSON.parse(data.trim())
                    console.log("[audio-mute] result ok=" + payload.ok
                                + " error=" + (payload.errorMessage || ""))
                    root.errorMessage = payload.ok ? "" : (payload.errorMessage || "Audio action failed")
                } catch (error) {
                    root.errorMessage = String(error)
                }
                actionProcess.running = false
                root.refresh()
                if (root.pendingAction.length > 0) {
                    const nextAction = root.pendingAction
                    const nextValue = root.pendingValue
                    root.pendingAction = ""
                    root.pendingValue = ""
                    root.startAction(nextAction, nextValue)
                }
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
