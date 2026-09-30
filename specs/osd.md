# OSD

**Status:** Implemented
**Files:** `quickshell/.config/quickshell/osd/OsdWindow.qml`, Hyprland bindings in `hyprland/.config/hypr/hyprland.conf`, `hyprland/.config/hypr/scripts/brightness`

## Description
Transient volume and brightness overlay. A single small pill that appears near the bottom of the screen when a volume or panel-brightness key is pressed, shows the value, and disappears on its own. It is not an `overlayManager` overlay.

## Behavior

### Trigger source
- Driven entirely by Hyprland keybindings, not by shell-side signal observers:

| Bind | Command |
|------|---------|
| `XF86AudioRaiseVolume` | `wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+ && quickshell ipc call osd showVolume` |
| `XF86AudioLowerVolume` | `wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- && quickshell ipc call osd showVolume` |
| `XF86AudioMute` | `wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle && quickshell ipc call osd showVolume` |
| `XF86MonBrightnessUp` | `~/.config/hypr/scripts/brightness up` |
| `XF86MonBrightnessDown` | `~/.config/hypr/scripts/brightness down` |

- The shell never changes volume itself: Hyprland mutates the sink first, then asks the OSD to re-read and display it
- The brightness binds do **not** call `brightnessctl`: `/sys/class/backlight` is empty on this host, so the old `brightnessctl` binds never touched a panel. Panel brightness goes over DDC/CI through `ddcutil` (`hyprland/.config/hypr/scripts/brightness`), which resolves the focused connector to a ddcutil display index with a self-healing per-connector cache under `$XDG_STATE_HOME/hyprland-brightness`, reads VCP `0x10` for current + max, clamps the ±5 step, writes the absolute value, and **only then** reports the applied percentage with `quickshell ipc call osd showBrightness <pct>`. The OSD reports what was applied instead of probing a second device that could disagree with the panel that changed
- The brightness binds are `bindl` (no `e`): one press costs ~650 ms of DDC/CI (`getvcp` ~297 ms + `setvcp` ~354 ms) even with the map cached, so hold-to-repeat would queue dozens of execs. The volume binds keep `bindel` because `wpctl` is fast enough for repeat to be useful
- IPC surface is `IpcHandler { target: "osd" }` with exactly two functions: `showVolume()` (sets `mode = "volume"`, starts `volumeReader`, calls `show()`) and `showBrightness(pct: int)` (sets `mode = "brightness"`, stores `brightPct = pct`, calls `show()`)

### Surface
- `PanelWindow` with `WlrLayershell.layer: WlrLayer.Overlay`, `exclusionMode: ExclusionMode.Ignore`, `WlrLayershell.keyboardFocus: WlrKeyboardFocus.None`
- Anchored `bottom` + `left` + `right`, `implicitHeight: 80`, `margins { bottom: 60; left: 0; right: 0 }`, `color: "transparent"`
- The pill body itself is a centered `Item` (`anchors.centerIn: parent`) with `implicitWidth: 220` / `implicitHeight: 52`, radius `Theme.radiusPill`, fill `Colors.base01` at `0.92` alpha, and a 1 px `Colors.muted` border at `Theme.opacityBorder`
- `visible: false` by default; one instance, created in `shell.qml` as `OsdWindow {}`
- Screen targeting is explicit: `property ShellScreen targetScreen: null` with `screen: root.targetScreen`, resolved by `resolveTargetScreen()`, which matches `Hyprland.focusedMonitor.name` against `ShellScreen.name` over `Quickshell.screens`. `show()` calls it only under `if (!visible)` — a pill already on screen keeps that screen rather than being unmapped and rebuilt under the user (`ProxyWindowBase::setScreen()` on a mapped surface rebuilds it). Unresolvable focus keeps the previous pin. Observed live: the pill appeared at the bottom of `DP-2` while `DP-2` held focus, then on `DP-1` after focus moved
- The surface takes no keyboard focus and ignores exclusivity, so the OSD never steals focus and never reserves screen space
- The OSD is not registered with `overlayManager`: it can appear on top of any active overlay and does not close one, and `overlayManager.closeAll()` (workspace change) does not hide it

### Value display
- `property string mode` — `"volume"` (default) or `"brightness"` — selects what the one pill renders. Everything below derives from it: `readonly property bool isBrightness`, `percent`, `dimmed`, `labelText`, and `icon`
- Volume: `Process { command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"] }`, stdout parsed by `SplitParser`
- Regex: `/Volume:\s*([\d.]+)(\s+\[MUTED\])?/`; on match, `volPct = Math.round(parseFloat(m[1]) * 100)` and `muted = !!m[2]`, then the process is stopped (`running = false`)
- Non-matching lines are ignored, so the displayed value only changes when the sink reports a volume
- Brightness: no reader. `brightPct` is the number the `scripts/brightness` helper just wrote to the panel, passed as the `showBrightness(pct: int)` argument
- `volPct`, `muted` and `brightPct` are plain properties, retained between shows: the pill always renders the last-known value immediately; volume is then corrected when the new read lands
- Track fill is `parent.width * (percent / 100)` inside a 140x4 pill track at `Colors.muted` `0.3` alpha
- Label text (`labelText`) is `brightPct + "%"` in brightness mode; in volume mode it is `"MUTED"` when muted, otherwise `volPct + "%"`
- `dimmed` is `muted` in volume mode and `brightPct === 0` in brightness mode (where the screen is black)
- Icon glyph is selected by state from `Colors.monoFont` via the escaped code points written in `OsdWindow.qml`: brightness mode → `"\uf186"` at `0`, `"\uf185"` otherwise; volume mode → muted `"\uf6a9"`, `volPct === 0` → `"\udb80\udf76"`, `volPct < 50` → `"\udb80\udf77"`, otherwise → `"\udb80\udf78"`. The three `\udb80\udfxx` pairs are surrogate-encoded Nerd Font volume glyphs (speaker-off / low / high)
- Color treatment: a dimmed state uses `Colors.muted` for icon, fill, and label with the fill at `0.35` opacity; an active state uses `Colors.blue` (base0D) with a `Colors.textDim` label

### Timeout
- Single `Timer { interval: 2500; repeat: false; onTriggered: root.visible = false }`, shared by both modes
- `show()` sets `visible = true` and calls `dismissTimer.restart()`, so each key press re-arms the same 2500 ms window rather than stacking timers, whichever mode changed
- The timeout is a literal `2500`, not a `Theme` animation token — **divergence** from the configurable-token rule used elsewhere
- There is no close button, no click handler, and no `Escape` handler: the pill can only leave by timer

### Divergences
- Brightness is no longer a divergence: both modes exist in code, and `SPECS.md` records that volume and brightness both produce the pill. What this file does not re-verify is the rendered brightness pill itself (glyph and fill readability at `0 %` on a real panel) — the `showBrightness` IPC path and its derived rendering are verified in code
- The 4 px rail-band divergence recorded here earlier is resolved: the hit test uses `bar.reservedBarContentHeight` — see `specs/launcher.md`

### Token usage
- `Theme.radiusPill` (body and track radius), `Theme.opacityBorder`, `Theme.spacingLg` / `Theme.spacingMd` (inner padding and row spacing), `Theme.fontSizeIcon`, `Theme.fontSizeLabel`
- `Colors.monoFont` for the icon, `Colors.uiFont` for the percent label
- Colors: `Colors.base01`, `Colors.muted`, `Colors.blue`, `Colors.textDim`
- Hardcoded, non-token values: surface height `80`, bottom margin `60`, pill `220x52`, track `140x4`, timeout `2500`
