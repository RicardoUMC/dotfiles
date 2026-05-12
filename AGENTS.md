# AGENTS.md — dotfiles (Arch Linux + Hyprland + Quickshell)

## Stack
- **WM**: Hyprland 0.54.3, monitor DP-2 @ 1920x1080, GPU AMD RX 7600
- **Shell UI**: Quickshell (QML/Qt6) — entry point `~/.config/quickshell/shell.qml`
- **SDDM theme**: `tokyo-city` at `/usr/share/sddm/themes/tokyo-city/`
- **Dotfiles manager**: `stow` — each package mirrors `$HOME` structure

## Stow packages
| Directory | Stow target |
|-----------|-------------|
| `quickshell/` | `~/.config/quickshell/` |
| `hyprland/` | `~/.config/hypr/` |
| `sddm/` | `/usr/share/sddm/themes/` |
| `wezterm/` | `~/.config/wezterm/` |

Install: `cd ~/dotfiles && stow quickshell hyprland wezterm`

## Quickshell architecture

```
shell.qml               ← coordinator: owns all overlay state, IPC handlers
bar/Bar.qml             ← PanelWindow top bar, imports bar/* components
bar/PowerMenu.qml       ← fullscreen PanelWindow Overlay (WlrLayer.Overlay)
bar/MprisPopup.qml      ← fullscreen PanelWindow Overlay
launcher/LauncherCentered.qml ← fullscreen PanelWindow Overlay
notifications/Notifications.qml ← PanelWindow Overlay, top-right
theme/Colors.qml        ← pragma Singleton — all color + font tokens
```

**Every QML module needs its type declared in the local `qmldir` file** — missing entries cause `Type X unavailable` errors on load.

## Overlay system rules (enforced in shell.qml)
- Overlays are **mutually exclusive by context group** — opening one must close incompatibles
- Use a **50ms Timer** before opening a new overlay to avoid Wayland serial conflicts
- Overlays open/close **only on explicit user interaction** — never on hover
- `Escape` closes the active overlay; closing a parent closes all its children
- Coordination lives in `shell.qml` — components signal up, never talk to each other directly

## SDDM quirks
- SDDM 0.21: context globals (`userName`, `userPassword`, etc.) are **injected by the QML engine** — never redeclare them as `property var`
- Test theme without logging out: `sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/tokyo-city`

## Typography system
All components use tokens from `Colors.qml` — never hardcode font families:
| Token | Font | Use |
|-------|------|-----|
| `Colors.uiFont` | SF Pro Text | Labels, buttons, body text, metric values |
| `Colors.displayFont` | SF Pro Display | Large titles, headers |
| `Colors.monoFont` | VictorMono Nerd Font | Nerd Font icons, separators |

## Palette — Tokyo City Terminal Dark (Base16)
Key values used in components:
- `base00` `#171D23` — background
- `base01` `#1D252C` — surface/cards
- `base0D` `#539AFC` — accent/blue
- `base0C` `#70E1E8` — cyan (reserved for special workspace highlight)
- `base08` `#D95468` — red/danger

## Hardware paths (used in SystemStats.qml)
- GPU busy: `/sys/class/drm/card1/device/gpu_busy_percent`
- Disk: `nvme0n1`
- Network: `wlp11s0`

## IPC commands
```bash
quickshell ipc call launcher toggle
quickshell ipc call powermenu toggle
quickshell ipc call notifications toggleSound
```

## Commit style
Conventional commits: `feat(scope): message`, `fix(scope): message`, `refactor(scope): message`
Merge directly to `main` — no PRs (personal repo). Never commit without explicit user request.

## Design system
See `DESIGN.md` for the full design reference — philosophy, inspirations, tokens, overlay rules, and planned architecture. Read it before touching any UI component.

## Available skills (OpenCode)
| Command | Skill | Purpose |
|---------|-------|---------|
| `/sync-docs` | `sync-docs` | Sync SPECS.md, DESIGN.md, AGENTS.md, specs/* to reflect current implementation state |

## Do not touch
- `~/.config/opencode/` — managed by `gentle-ai` (AGENTS.md, opencode.json, skills/, commands/)
- Never add `--no-verify`, amend commits, or force push
