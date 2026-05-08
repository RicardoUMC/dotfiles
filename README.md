# dotfiles

Personal dotfiles for Arch Linux + Hyprland, managed with [stow](https://www.gnu.org/software/stow/).

## Packages

| Package | Description |
|---------|-------------|
| `quickshell` | Bar, workspaces, system stats — built with [Quickshell](https://quickshell.outfoxxed.me/) (QML/Qt) |
| `hyprland` | Hyprland compositor config |
| `wezterm` | WezTerm terminal config |

## Install

```bash
git clone https://github.com/unseen/dotfiles ~/dotfiles
cd ~/dotfiles
stow quickshell hyprland wezterm
```

## Theme

[Tokyo City Terminal Dark](https://github.com/your-theme) — Base16 palette
