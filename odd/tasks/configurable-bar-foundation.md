# Configurable Bar Foundation

Status: Implemented (uncommitted)

## Goal
Implement the first configuration-only foundation for the future configurable bar. Preserve the current top-anchored Tokyo City island bar while introducing validated global defaults, sparse per-monitor overrides, and one effective-configuration resolver keyed by `ShellScreen.name`.

## Approved configuration shape

One `quickshell/.config/quickshell/config.json` file remains the source. Legacy current keys stay compatible:

- `bar.screens`: existing selector (`"all"` or an array of screen names)
- `bar.style`: existing rendering token (`silhouette` or `plain`)

The future model is stored separately:

```json
{
  "bar": {
    "defaults": {
      "position": "top",
      "visibility": "always",
      "style": "islands",
      "revealPolicy": "external-edges"
    }
  },
  "dashboard": { "attachment": "embedded" },
  "monitors": {
    "DP-1": { "bar": { "position": "bottom" }, "dashboard": { "attachment": "detached" } }
  }
}
```

`monitors` is an exact, case-sensitive map keyed by `ShellScreen.name`. Unknown names remain inert. Overrides are sparse.

## Scope

- Implement parser, validation, built-in fallback, immutable-by-replacement normalized snapshot, and resolver in `Theme.qml`.
- Expose the resolved model to each `Bar` instance without applying position, visibility, continuous style, edge reveal, or detached dashboard rendering.
- Preserve legacy `bar.screens` behavior and current visual defaults.
- Document implemented model and explicitly mark rendering behavior as pending.

## Verification evidence

- [x] Qt 6 lint on modified QML files; only documented baseline warnings remain.
- [x] Structural checks for schema, resolver wiring, and legacy compatibility markers.
- [x] Source inspection confirms malformed JSON leaves the normalized snapshot unchanged because assignment occurs after parse/root validation.
- [x] Source inspection confirms successful reload replaces the snapshot, so removed overrides restore inheritance.

## Verification evidence

- `python -m json.tool quickshell/.config/quickshell/config.json`: pass.
- `/usr/lib/qt6/bin/qmllint -I quickshell/.config/quickshell` on Theme.qml, Bar.qml, and shell.qml: pass with documented Quickshell/unqualified warnings only.
- `git diff --check`: pass.
- Runtime compositor reload and live monitor behavior were not run; future configuration is intentionally inert.

## Disabled visibility unit evidence

- Legacy `bar.screens` resolution and empty-match fallback remain the first stage.
- Normalized `visibility: "disabled"` filtering runs after that stage and allows zero Bar instances.
- Active and pending Bar-owned overlays are reconciled by exact screen name; standalone launcher/wallpaper state is preserved.
- Structural checks and Qt 6 lint passed; live compositor reload, hot-plug, and visual lifecycle checks remain pending.

## Decisions

- Use `monitors` rather than `barMonitors` to model both bar and dashboard monitor overrides without colliding with legacy `bar.style` semantics.
- Keep runtime state (visibility/reveal/overlay state) separate; this task only supplies declarative configuration data.
- Do not change physical Bar geometry or layer-shell behavior.

## Next unit: disabled visibility

Approved follow-up: apply `visibility: "disabled"` by filtering the per-monitor Bar instance and its currently Bar-owned surfaces. Preserve the legacy `bar.screens` fallback before this filter; do not restore bars after an explicit disabled result, including when every monitor is disabled. Reconcile active/pending overlay ownership when a Bar disappears. Detached dashboard and independently owned surfaces remain future work.
