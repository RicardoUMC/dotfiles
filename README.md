# dotfiles

Personal dotfiles for Arch Linux + Hyprland, managed with [stow](https://www.gnu.org/software/stow/).

## Packages

| Package | Description |
|---------|-------------|
| `quickshell` | Bar, workspaces, system stats — built with [Quickshell](https://quickshell.outfoxxed.me/) (QML/Qt) |
| `hyprland` | Hyprland compositor config |
| `wezterm` | WezTerm terminal config |

## Dependencies

See `setup.sh` for the full list of dependencies and configuration steps.

## Install

```bash
git clone https://github.com/RicardoUMC/dotfiles ~/dotfiles
cd ~/dotfiles
stow quickshell hyprland wezterm
```

> Stow creates symlinks from `~/dotfiles` into `$HOME`.
> Make sure to remove or back up any existing configs before running stow.

## Theme

Tokyo City Terminal Dark — Base16 palette
