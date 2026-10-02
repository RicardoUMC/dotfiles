# Right-island visual geometry and configurability

Status: approved for implementation as a focused visual work unit.

## Goal
Improve the right control-center's visual proportions and user configurability without changing the single-surface input authority, sibling routing, N-monitor behavior, or Tokyo City palette.

## Evidence
- Recording: `/tmp/quickshell-recordings/screen_20261002_005554.mp4`.
- The panel body is currently hardcoded to width 420 and max height 600.
- Panel edge offsets contain `-1` visual fudges.
- Panel title uses `fontSizeBody` while card hero typography uses `fontSizeBodyLg`.
- Power is a 160px bordered mini-card inside a 420px body, unlike the full-width borderless specialty cards.
- Section switches reset the full body reveal even while the RCC remains open.

## Scope
1. Add only high-leverage `rightPanel.*` structural tokens to `Theme.qml` and `config.json`: width, maxHeight, topMargin, rightMargin, padding, cardGap, cardFillOpacity (or equivalent shared card surface opacity), radius/border opacity only if needed by existing geometry.
2. Replace RCC hardcoded panel geometry with those tokens; preserve output-local anchoring and geometry-driven backdrop mask.
3. Use `Theme.fontSizeBodyLg` for the panel title.
4. Make Power composition consistent with sibling cards: use the panel width rather than an orphan 160px fragment, remove its unique border grammar, and retain destructive tint/state semantics through existing tokens.
5. Keep fresh-open reveal animation, but do not collapse and regrow the full panel on an already-open sibling switch. Preserve content-driven max-height behavior and clamp against the owning screen's local `root.height`.
6. Keep all service/back-end behavior, input routing, Escape/focus, and N-monitor logic unchanged.

## Configurability rules
- Structural values belong in `Theme.qml` and `config.json`.
- Colors/fonts remain in `Colors.qml` or existing font tokens.
- Do not add per-row/per-label/per-card micro-tokens; reuse spacing/radius/opacity tokens where possible.
- Preserve all pre-existing dirty changes in `Theme.qml`, `config.json`, and unrelated files.

## Verification
- Qt6 qmllint on every touched QML file.
- `git diff --check`.
- Soft and hard reload with terminal `Configuration Loaded` and no post-reload `ERROR`.
- Qt6 lint/JSON/diff verification passed; only documented Theme style warnings remain.
- Full compositor screenshot captured after reload at 4480x1440; Power opened through IPC and visually inspected as a full-width card inside the panel. Closed-state screenshot preserved both outputs and the bar composition.
- Pointer behavior remains pending live confirmation: closed-state pass-through, sibling switching, Escape, and N-monitor anchoring.

Compact Power verification:
- Qt6 lint, JSON parse, and `git diff --check` passed; only the same pre-existing Theme style warnings remain.
- Soft and hard reload both ended with `Configuration Loaded` and no post-reload errors.
- Open Power capture at 4480x1440 confirms the panel narrows to the former compact scale while remaining right-anchored; non-Power panel geometry is unchanged.

## Follow-up: compact Power mode
- Keep the general RCC at `rightPanel.width`, but make the Power section use a configurable compact card width matching its former scale.
- Derive the RCC width in Power mode from `rightPanel.powerWidth + 2 * rightPanel.padding`, preserving the right edge and existing input/focus ownership.
- Verify that non-Power sections retain their existing width and that the compact panel does not introduce output-specific offsets.

## Follow-up: collapsed Audio entry flow
- Opening Audio from the right-island chip must show the summary card first; routing and the attached device panel open only after a second interaction with the Audio card.
- Preserve the existing Audio volume controls, service actions, Escape/focus ownership, and sibling routing.

Audio flow verification:
- Qt6 lint passed for `RightControlCenter.qml`; `AudioControlCard.qml` retains only pre-existing `[unqualified]` warnings in its repeater delegate.
- `git diff --check` passed.
- Soft and hard reload both ended with `Configuration Loaded` and no post-reload errors.
- The interactive visual click path remains pending direct pointer confirmation; the state transition is now explicit in `RightControlCenter.qml` and the Audio card's second-step controls remain intact.

## Follow-up: Audio hierarchy and compact input control
- Compact Audio should show one summary hero plus two distinct controls: output volume and microphone gain.
- Expanded Audio should hide the compact summary controls and show only the detailed device/routing panel, avoiding duplicate output/input controls and duplicate routing rows.
- Preserve output/input selection, mute actions, attached-panel Back behavior, Escape/focus ownership, and sibling routing.

Audio hierarchy verification:
- `AudioControlCard.qml` passes Qt6 lint with no diagnostics; `AudioControlPanel.qml` retains only its existing `[unqualified]` warnings.
- `git diff --check` passed.
- Soft and hard reload both ended with `Configuration Loaded` and no post-reload errors.
- Compact output and microphone sliders share one visual/interaction component; expanded Audio renders only the detailed panel. Direct pointer confirmation remains pending.

## Follow-up: compact mute hit targets
- Make compact output/microphone mute controls own explicit click targets inside `CompactLevelControl`, while preserving the existing visual pill grammar and AudioService actions.
- Verify both compact mute paths after reload.

Mute hit-target verification:
- `AudioControlCard.qml` passes Qt6 lint with no diagnostics.
- `git diff --check` passed.
- Soft and hard reload both ended with `Configuration Loaded` and no post-reload errors.
- Compact mute buttons now own explicit `MouseArea`s; direct pointer confirmation remains pending.

## Follow-up: direct audio mute dispatch
- Remove the remaining compact mute signal hop; each compact level control dispatches directly to the appropriate AudioService output/input mute method.
- Preserve the existing visual button and explicit hit target.

Direct mute dispatch verification:
- `AudioControlCard.qml` passes Qt6 lint with no diagnostics.
- `git diff --check` passed.
- Soft and hard reload both ended with `Configuration Loaded` and no post-reload errors.
- Backend `wpctl set-mute` was validated for both default sink and source without changing either current state; live pointer confirmation remains pending.

## Follow-up: RCC content input priority
- Make the interactive RCC content layer explicitly higher than the panel-body click catcher so compact mute controls and detailed Audio controls receive pointer events.
- Preserve outside-click dismissal through the backdrop and do not change the global mask ownership.

RCC input-priority verification:
- Qt6 lint passed for `RightControlCenter.qml` and `AudioControlCard.qml`.
- `git diff --check` passed.
- Soft and hard reload both ended with `Configuration Loaded` and no post-reload errors.
- The interactive `Flickable` now has explicit z-priority over the panel-body catcher; direct pointer confirmation remains pending.

## Delivery
- Work-unit commits: `5df5c5f` (`feat(quickshell): make right panel geometry configurable`), `df64eb5` (`feat(quickshell): compact right-panel power mode`), `a80d9a9` (`fix(quickshell): open audio control center collapsed`), `bafc01b` (`feat(quickshell): simplify compact audio controls`), `356fec9` (`fix(quickshell): restore compact audio mute clicks`), and `277ee7b` (`fix(quickshell): dispatch compact audio mute directly`) on `main`.
- No push unless separately requested.
