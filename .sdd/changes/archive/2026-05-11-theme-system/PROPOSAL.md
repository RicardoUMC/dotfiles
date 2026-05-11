# Proposal: Theme System

## Intent

To eliminate hardcoded magic numbers (border radius, opacity, spacing, font sizes, animation durations, bar height) across the Quickshell Qt6/QML rice. Centralizing these into a mutable token system enables hot-reloading and dynamic theming without coupling components to arbitrary pixel values.

## Scope

### In Scope
- Creating a mutable `Theme.qml` singleton to manage design tokens.
- Defining a JSON-based configuration (`config.json`) with hot-reload via `FileView`.
- Token catalog for radius, spacing, opacity, font sizes, bar height, and animation durations.
- ~70 token substitutions across 12 files.
- Phased migration strategy to guarantee zero visual regression.

### Out of Scope
- A graphical Settings GUI (deferred to a separate change).
- Color theming (the existing `Colors.qml` readonly palette singleton remains as-is).

## Capabilities

### New Capabilities
- `theme-system`: Centralized mutable token management with hot-reload via `config.json`.

### Modified Capabilities
- `quickshell-components`: Replaces hardcoded structural values with `Theme.qml` tokens.

## Approach

A hybrid architecture where `Colors.qml` provides a robust, readonly color palette, while a new `Theme.qml` singleton serves as a mutable store for structural and behavioral tokens. `Theme.qml` will read from an optional `config.json` via a `FileView` to support immediate hot-reloading. The migration will be done sequentially: establish `Theme.qml` with identical defaults (zero visual change), migrate files from least to most risky, and tackle the critical bar height token (37px) last.

## Token Catalog

- **Radius**: Window borders, component rounding, pill shapes.
- **Spacing**: Margins, paddings, gaps between widgets.
- **Opacity**: Background transparency, hover states.
- **Font Sizes**: Text scaling for labels, clocks, and indicators.
- **Bar Height**: Currently 37px (critical coupling across 3 files).
- **Animation**: Standardized durations and easing transitions.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `Theme.qml` | New | Mutable singleton for token state |
| `config.json` | New | Hot-reload configuration file |
| UI Components (12 files) | Modified | Replace hardcoded values with `Theme` tokens |

## Migration Strategy

1. **Setup**: Create `Theme.qml` initialized with current hardcoded defaults (zero visual change).
2. **Safe Migration**: Substitute radius, spacing, and opacity tokens in isolated components.
3. **Typography & Motion**: Substitute font sizes and animation durations.
4. **Critical Path**: Migrate the 37px bar height token referenced across 3 heavily coupled files.
5. **Dynamic State**: Wire up `config.json` and `FileView` to `Theme.qml` for hot-reload.

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Visual regressions | Medium | Migrate file-by-file using exact default values; visual QA per step |
| Layout breaks (bar height) | High | Handle token last after simpler tokens are proven |
| Hot-reload performance | Low | Keep `config.json` flat/minimal |

## Rollback Plan

Revert the specific commit for the failing file migration to restore the hardcoded values. `Theme.qml` can remain in the codebase harmlessly until all components are successfully migrated.

## Dependencies

- Quickshell `FileView` for file-system hot-reloading.

## Success Criteria

- [ ] All 12 identified files have hardcoded values replaced with `Theme.*` properties.
- [ ] Changing a value in `config.json` instantly updates the running UI without restarting.
- [ ] No visual changes are observable compared to the pre-migration state.