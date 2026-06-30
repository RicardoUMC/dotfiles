# Bar Styling

## Purpose

Controls bar background via `bar.style` config: `"silhouette"` (three content-sized island backgrounds at each section, separated by real transparent gaps) or `"plain"` (transparent, no backgrounds).

## Requirements

### R1: Silhouette Mode

When `bar.style` is `"silhouette"`, the system MUST render three content-sized Rectangle backgrounds at leftTab, centerTab, and rightTab bounds. Each island spans full bar height with per-corner radius control. The gaps between islands MUST be real transparent space — no bridging connector or overlap.

Normal state: center island MUST have the same visual height as left and right. Deeper central notch belongs to future expanded state (out of scope).

(Supersedes: earlier single continuous ShapePath fill + 1px stroke approach — replaced by composed Rectangles at content bounds)

#### Scenario: Content-sized island backgrounds

- GIVEN `bar.style` = `"silhouette"`
- WHEN the bar renders
- THEN three Rectangle backgrounds appear at leftTab, centerTab, and rightTab bounds
- AND each island spans full bar height with per-corner radius control

#### Scenario: Real transparent gaps

- GIVEN `bar.style` = `"silhouette"`
- WHEN the bar renders
- THEN gaps between left/center and center/right islands are real transparent space
- AND no continuous fill or bridging connector connects the islands

#### Scenario: Debug silhouette visual

- GIVEN `debug.barSilhouette` is true
- WHEN `bar.style` is `"silhouette"`
- THEN each island displays high-contrast red fill (`rgba(255, 51, 68, 0.65)`) with red border (`#ff3344`)
- AND the fill/border exactly matches the island bounds (not fake container bounds)

### R2: Plain Mode

When `bar.style` is `"plain"`, the system MUST render no background surface.

#### Scenario: Transparent background

- GIVEN `bar.style` = `"plain"`
- WHEN the bar renders
- THEN no fill or stroke is drawn
- AND all content remains visible

### R3: Background and Accent Removal

BarTab MUST NOT render opaque backgrounds (`bgSource`) or borders. CenterTab MUST NOT render the blue accent left-border (`centerAccent`).

#### Scenario: BarTab without own background

- GIVEN any `bar.style` mode
- WHEN a BarTab renders
- THEN no `bgSource` or `border` Rectangle is created
- AND the silhouette is visible behind content (if silhouette mode)

#### Scenario: No center accent

- GIVEN the center BarTab
- WHEN it renders
- THEN no accent border appears on its left edge

### R4: Equal Section Height

All three sections MUST have the same visual height in normal state.

#### Scenario: Height parity

- GIVEN normal state (no overlays active)
- WHEN all sections render
- THEN left, center, and right share identical height

### R5: Future Overlay Compatibility

The design MUST NOT prevent a future expanded center overlay PanelWindow. Expansion SHALL be overlay-based (not a taller bar section).

#### Scenario: Overlay-based expansion

- GIVEN a future expanded center overlay
- WHEN the overlay opens
- THEN the bar silhouette and layout require no changes
- AND the overlay renders as a separate PanelWindow above the bar

### R6: Existing Interactions Preserved

All bar interactions MUST remain functional in both modes: workspaces, center panel, metrics, power menu, MPRIS.

#### Scenario: Interactions work in silhouette mode

- GIVEN `bar.style` = `"silhouette"`
- WHEN the user clicks any bar widget
- THEN all interactions work identically to current behavior

#### Scenario: Interactions work in plain mode

- GIVEN `bar.style` = `"plain"`
- WHEN the user clicks any bar widget
- THEN all interactions work identically to silhouette mode

## Verification

| Checkpoint | Condition | Visual Criterion |
|------------|-----------|------------------|
| CP1 | Default state | Three islands at left/center/right bounds with transparent gaps, breathing visual |
| CP2 | MPRIS active | Center section same height, MPRIS chip visible, no layout shift |
| CP3 | MetricsDropdown open | Overlay above app windows, bar silhouette unchanged |
| CP4 | Config toggle `"plain"` | No bar background, content visible on transparent surface |

## Non-functional Constraints

| Constraint | Value |
|------------|-------|
| Review budget | ≤ 400 lines (forecast ~150–200) |
| QML types | Use existing `Rectangle` — no new types required |
| qmldir changes | Not required |
| Architectural scope | No rewrite; local changes to bar rendering only |
| Commit state | 3 checkpoints committed: ShapePath (5b85301), composed segments (29bb0df), content-sized islands (a1c9fa7) |
