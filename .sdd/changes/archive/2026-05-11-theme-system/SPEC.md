# Specification: Theme System

## Purpose

Define the behavior of the mutable `Theme.qml` token system and its integration with `config.json` for hot-reloading structural values across Quickshell components, eliminating hardcoded magic numbers.

## Requirements

### Requirement: Theme.qml Singleton Structure

The system MUST provide `Theme.qml` as a mutable QML singleton that is importable from any component. It MUST declare safe default values directly in property declarations (not deferred to `onCompleted`).

### Requirement: Token Equivalents for Structural Values

All current hardcoded structural values MUST have a named token equivalent in `Theme.qml`. `Colors.qml` MUST remain unchanged.

**Token Catalog & Default Values:**
- **Radius**: `radiusSm` (6), `radiusMd` (10), `radiusLg` (12), `radiusPill` (999)
- **Spacing**: `spacingXs` (4), `spacingSm` (8), `spacingMd` (12), `spacingLg` (16), `spacingXl` (24)
- **Opacity**: `opacitySurface` (0.97), `opacityOverlay` (0.33), `opacityBorder` (0.30), `opacityDim` (0.15)
- **Bar**: `barHeight` (37)
- **Animation**: `animFast` (180), `animNormal` (300), `animSlow` (500)
- **Font Sizes**: `fontSizeCaption` (10), `fontSizeLabel` (11), `fontSizeBody` (13), `fontSizeBodyLg` (14), `fontSizeIcon` (18)

### Requirement: Zero Visual Regression

Components MUST produce identical visual output before and after migration to the theme system. The `barHeight` token MUST be adopted by all 3 current consumers (`Bar.qml`, `Notifications.qml`, `PowerMenu.qml`).

### Requirement: Hot-Reloading Configuration

The system MUST support hot-reloading via `config.json`. When the file changes, tokens MUST update without restarting Quickshell.
The hot-reload mechanism MUST be debounced (~100ms) to avoid reacting to partial file writes.

### Requirement: Robust Configuration Parsing

Parse errors in `config.json` MUST fail silently using try/catch logic, retaining the current token values without crashing the application.

## Scenarios

### Scenario: Absent Configuration File

- **GIVEN** `Theme.qml` exists and `config.json` is absent
- **WHEN** the application starts
- **THEN** safe default token values are used
- **AND** the application does not crash

### Scenario: Partial Configuration Overrides

- **GIVEN** `config.json` exists with partial token overrides
- **WHEN** the configuration is parsed
- **THEN** only the specified tokens change
- **AND** the remaining tokens keep their safe default values

### Scenario: Invalid JSON Configuration

- **GIVEN** `config.json` contains invalid JSON syntax
- **WHEN** the file is parsed by `Theme.qml`
- **THEN** the parsing fails silently
- **AND** all tokens remain at their current values

### Scenario: Live Configuration Update

- **GIVEN** `config.json` is written while Quickshell is running
- **WHEN** the debounced hot-reload mechanism triggers
- **THEN** tokens update within 200ms
- **AND** the UI reflects the new token values

### Scenario: Reactive Component Token Reading

- **GIVEN** a component is bound to a token like `Theme.radiusSm`
- **WHEN** the token value updates via hot-reload
- **THEN** the component immediately receives and applies the new value
