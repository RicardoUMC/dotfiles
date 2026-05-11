# Workspaces

**Status:** Implemented
**File:** `quickshell/.config/quickshell/bar/Workspaces.qml`

## Description
Workspace indicator showing workspace number/icon and active app names.

## Behavior

### Display format
- Each workspace shows: `[number/icon] · [app1] | [app2]`
- Special workspace (`special:magic`) shows icon `󰓪`
- Active workspace: text is bright + bold
- Inactive workspace: text is muted

### App name resolution
1. Look up app class in `DesktopEntries.applications` by ID (case-insensitive)
2. If found, use the desktop entry `name`
3. Fallback: strip reverse-DNS prefix (last segment) or suffixes `-browser`, `-desktop`
4. Capitalize first letter

### Reactivity
- Updates on: `workspace`, `workspacev2`, `moveworkspace`, `movewindow`, `activewindow`, `fullscreen` Hyprland events

### Separator
- `•` between workspace number and app list (only visible when workspace has open windows)
- `|` between multiple apps (only visible for index > 0)
