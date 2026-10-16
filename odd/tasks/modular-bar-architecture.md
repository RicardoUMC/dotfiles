# Modular Configurable Bar Architecture
Feature scope: recover the known-good bottom behavior, then separate placement, geometry, content policy, ordering, motion, and monitor topology.
Implementation starts bottom-first; left/right remain unchanged until the shared contracts are stable.

## Specs
- S1: "Lo que quiero hacer es 1º, que la barra justamente se pueda estar poniendo en cualquier costado de de la pared con las especificaciones que ya habíamos dicho"
- S2: "que haya modularidad con las con los elementos"
- S3: "posiblemente ya no ponga lo que es el nombre de la aplicación que está abierta"
- S4: "solo poner el ícono que en el que está activo"
- S5: "que esto podría ser incluso una configuración que pudiera decidir el usuario"
- S6: "no quiero algo tal cual cuadrado"
- S7: "que sus barras se muevan"
- S8: "No quiero que empieces directo con el desarrollo, con la implementación, porque me gustaría que 1º investigaras el estado del arte"
- S9: "cuando 2 monitores estén pegados en esos laterales que tengan los comportamientos que ya habíamos definido"
- S10: "que al mismo tiempo sean coherentes con la imagen engión en la geometría"

## Tasks
- T1 (S1, S9, S10): Recover and freeze bottom against the last acceptable baseline; route: bottom mask/blur parity; commit: 5b1d1a0
- T2 (S1, S2, S10): Define one canonical logical geometry contract consumed by visible mask, native blur, input, and reservation; route: scalar IslandGeometry section contract; commit: 63cb2de
- T3 (S2, S4, S5): Separate edge placement from slot order and content presentation; route: configurable content policy; commit: pending
- T4 (S5, S6, S7): Add the configurable divider and Calm motion policy without coupling them to placement; route: theme/config policy; commit: pending
- T5 (S1, S9, S10): Verify all four edges, per-monitor overrides, shared seams, content modes, and motion defaults; route: functional/runtime checks; commit: pending
- T6 (S1, S2, S9, S10): Correct the lateral visible/blur/input frames and rotated cap mapping without changing accepted top/bottom behavior; route: mask-local geometry and physical-edge transforms; commit: 7a20bfc
- T7 (S1, S2, S9, S10): Keep vertical dashboard expansion overlay-shaped, align the right-side catcher, and verify layer behavior separately from reservation; route: collapsed reservation plus output-local catcher geometry; commit: 7a20bfc
- T8 (S1, S2, S9, S10): Analyze the latest user recording and distinguish persistent lateral geometry from open-state animation/content defects; route: extracted frame evidence and source mapping; commit: pending
- T9 (S1, S2, S9, S10): Correct the recording-confirmed geometry and open-state defects without regressing the accepted top/bottom contract; route: bounded QML correction and runtime verification; commit: 341c071, 8d1cecf, a5c5156

## Log
### L1 — User request (verbatim)
"No, estoy viendo que al parecer deshiciste los cambios que habíamos conseguido para la barra inferior cuando esté en botón, Para el top, al parecer, no hay problema, se ve tal cual lo habíamos dejado originalmente. Pero para el bottom quedó raro. No, ya no quedó como lo habíamos solucionado antes. Y no me gusta, porque de hecho hay cosas raras por ejemplo, te voy a compartir una imagen, para que puedas ver más o menos a lo que me refiero. ¿Cuándo está la barra en la parte inferior? Que se supone ya había quedado bien, o al menos aceptable. ¿Piensa en este desarrollo? De las barras lateral izquierda lateral derecha o o superior o inferior? Como algo modular, trata de verlo modular completamente configurable. Lo que quiero hacer es 1º, que la barra justamente se pueda estar poniendo en cualquier costado de de la pared con las especificaciones que ya habíamos dicho, las definiciones por ejemplo, cuando 2 monitores estén pegados en esos laterales que tengan los comportamientos que ya habíamos definido, pero que al mismo tiempo sean coherentes con la imagen engión en la geometría, a eso es a lo que me refiero. Porque ahorita ya se rompió lo de la parte inferior, y quiero ver si se puede hacer algo para que a lo mejor no todo esté atado porque me imagino que ahorita se rompió, porque las cosas estaban muy atadas. Entonces quiero ver la mejor arquitectura para poder lograrlo, tanto que se puedan invertir, por ejemplo, los órdenes que te decía entre workspace o los servicios, para cualquier tipo de barra, ya sea superior, inferior y izquierda o derecha.

Como ya sabes, yo no soy un experto para diseño de interfaces, y en general desarrollo de interfaces UXUI, por eso también te pido ayuda. Sé lo que quiero lograr, eso es lo que en lo que te puedo ayudar para definirte mejor las cosas. Pero honestamente yo no sé lo que a lo mejor la industria suela hacer con este tipo de cosas. Yo quiero recuerda, que debe ser algo muy configurable, entonces lo que yo siento que pudiera ayudar para lograr todo eso y que no todo esté atado con todo, porque pareciera que ahorita todo está atado con todo, que haya modularidad con las con los elementos por ejemplo. No sé si eso ayuda, pero si es que ayuda en algo, que a lo mejor se se utilice, porque ahorita están las cosas mal. Como que retrocedimos con lo que ya habíamos hecho, quiero corregirlo y ahí no sé si incluso se pueda hacer desde una misma cosa. Pensando bien las cosas, cómo se van a relacionar, cómo va a ser la arquitectura, si eso puede ayudar en algo, genial.

Por ejemplo, cosa que estuve notando ahorita que estaba probando la parte de la barra izquierda, que en realidad ahorita la desactivé, ahorita estoy viendo la barra inferior, pero cuando estaba probando la barra en la parte izquierda, noté un par de cosas que a lo mejor voy a estar cambiando en general para todas las barras, y es que posiblemente ya no ponga lo que es el nombre de la aplicación que está abierta. Porque se empieza a ensanchar la barra y es algo que no quiero. Si acaso que vaya poniendo los nombres de las aplicaciones pero de manera vertical, y no me refiero a que yo lo lea tal cual de izquierda a derecha, ¿no? O sea, es prácticamente como si esté de abajo a arriba, como si giraras el texto 90 grados. Eso aplica incluso también para el reloj, porque el reloj también tiene el mismo problema. Si no, lo más sencillo es simplemente decir el el escritorio en donde nos encontramos, y a lo mejor no importa cuántas aplicaciones tengamos abiertas en ese escritorio, a lo mejor no poner todas, a lo mejor solo poner el ícono que en el que está activo. O los íconos de las aplicaciones que están activas. De hecho, esto podría ser incluso una configuración que pudiera decidir el usuario, que tengan esas 2 opciones. Esto implicaría, a lo mejor, repensar la parte de los escritorios, a lo mejor que no sean tal cual que tengan los números, o que sí, que eso también se pueda configurar, o algo así como bullets, que tengan animación al pasar de escritorio en otro y lo que suelen utilizar los demás shells.

Luego, para la parte de servicios, aquí yo estoy hablando en general, no solo de la barra cuando está en el lado izquierdo, A lo mejor, no sé si simplificar, no no simplificar, sino que mejorar la división que ahorita tienes con un rectángulo. Entiendo que es una división entre el botón de apagado con los otros servicios de notificación, sonido, Bluetooth y WiFi. Pero no me termina de gustar. Quiero algo un poquito más acorde al la estética que estamos utilizando, no quiero algo tal cual cuadrado, no sé si incluso quiera un divisor, quiero algo que se sienta moderno, que no se sienta tosco, que no se sienta puesto ahí solo para dividir, porque ahorita se siente así. Si tienes tú alguna sugerencia, alguna propuesta, la acepto, la podemos ir probando para tratar de lograrlo.

Ahorita lo que no quiero es seguir con estos errores, porque eran cosas al menos para la barra inferior, eran cosas que ya teníamos resueltas. Entonces ahorita yo creo que preferiría regresar al punto en donde funcionaba, antes de aplicar las cosas para ¿La barra izquierda? Para que tomes en cuenta ya todo lo que te dije y ver si hay que modificar cosas."

### L2 — T1 evidence
- Restored the accepted bottom `Scale` transform in `NotchIslandMask.qml` from `bfd4662`.
- Qt6 `qmllint`, hard reload, `Configuration Loaded`, RGB strip comparison, and visual review passed.
- Commit: `5b1d1a0 fix(bar): restore bottom mask orientation`.

### L3 — T2 evidence
- Extended `IslandGeometry.qml` with pure scalar section helpers for corner extents, edge frame offsets, proxy placement, mask dimensions, wraps, source dimensions, and reservation.
- `BarSection` is the scalar contract provider; `NotchIslandMask` and `IslandBlurRegion` consume the same derived values without a dynamic metrics object.
- Qt6 `qmllint`, stale-reference check, hard reload, and latest log block passed with `Configuration Loaded` and no `ERROR` or `WARN`.
- Captured and visually reviewed `/tmp/quickshell-t13-top.png`, `/tmp/quickshell-t13-bottom.png`, `/tmp/quickshell-t13-left.png`, and `/tmp/quickshell-t13-right.png`.
- The capture wrapper exited 1 only because its `cmp` assertion ran before the `EXIT` trap; the trap restored `config.json`, which is back at `position: bottom`.
- Commit: `63cb2de refactor(bar): share scalar island geometry`.

### L4 — T3 implementation and verification
- Added normalized endpoint order and content policies through `Theme.effectiveBarConfig(screenName)`, preserving exact-name per-monitor overrides and safe enum fallbacks.
- Extracted the services/power endpoint into `bar/ServiceEndpoint.qml`; both endpoint slots now use shared Loader components, while the center/dashboard remains fixed.
- Added workspace presentation modes (`numbers`, `bullets`, `active-only`), app modes (`hidden`, `active-icon`, `all-icons`, `vertical-labels`), and clock modes (`auto`, `horizontal`, `vertical`, `hidden`). Side bars default to the active application icon and upright content.
- Added `ClockChip` orientation policy and compact side media presentation; registered the new QML module in `bar/qmldir`.
- Fixed power hit-testing after Loader extraction by mapping through scene coordinates instead of passing the non-`QQuickItem` `PanelWindow` to `mapToItem()`.
- Qt6 `qmllint` completed with exit 0; the hard reload completed with `Configuration Loaded` and no runtime `ERROR` or `WARN` after the coordinate fix.
- Captured and visually reviewed `/tmp/quickshell-t14-default-bottom.png`, `/tmp/quickshell-t14-inverted-bottom.png`, `/tmp/quickshell-t14-left-active-icon.png`, `/tmp/quickshell-t14-per-monitor.png`, and `/tmp/quickshell-t14-invalid-fallback.png`.
- The corrected five-scenario capture matrix restored `quickshell/.config/quickshell/config.json` byte-for-byte; its local modification remains intentionally uncommitted.
- Work-unit commit: `270ec20 feat(bar): add configurable endpoint content policies`.

### L5 — T4 integrated divider implementation and verification
- Added `bar/ServiceDivider.qml` as a passive divider primitive with `arc`, `hairline`, and `none` modes. The default arc bends toward the monitor interior and follows top/bottom/left/right orientation without owning input or routing.
- Routed normalized `bar.divider` and the resolved physical position from `Bar.qml` through `ServiceEndpoint.qml`; registered the component in `bar/qmldir`.
- Updated `specs/configurable-bar.md`, `specs/bar.md`, and `DESIGN.md` so the endpoint contract and divider modes are discoverable and no longer describe order or the divider as future work.
- Qt6 `qmllint` completed with exit 0; hard reload completed with `Configuration Loaded` and no runtime `ERROR` or `WARN`.
- Captured and visually reviewed `/tmp/quickshell-t16-arc-top.png`, `/tmp/quickshell-t16-arc-bottom.png`, `/tmp/quickshell-t16-arc-left.png`, `/tmp/quickshell-t16-arc-right.png`, `/tmp/quickshell-t16-hairline-bottom.png`, and `/tmp/quickshell-t16-none-bottom.png`, plus endpoint crops.
- The six-scenario capture matrix restored `quickshell/.config/quickshell/config.json` byte-for-byte; its local debug modification remains intentionally uncommitted.
- Work-unit commit: `71ea05a feat(bar): add integrated service divider`.

### L6 — T4 Calm motion implementation and verification
- Resolved `bar.motion` per monitor and wired `reduced` to disable only the new bar-local transitions; `calm` remains the default shared-intent policy and `expressive` currently aliases those intents.
- Replaced literal center expansion and MPRIS width animations with `Motion.Spatial`; active workspace fills use `Motion.EffectsColor`; service-chip fills and `StateLayer` opacity honor the same motion switch.
- Qt6 `qmllint` completed with exit 0; hard reload completed with `Configuration Loaded` and no runtime `ERROR` or `WARN`.
- Captured and visually reviewed `/tmp/quickshell-t17-calm-bottom.png`, `/tmp/quickshell-t17-reduced-bottom.png`, `/tmp/quickshell-t17-calm-left.png`, and `/tmp/quickshell-t17-reduced-left.png`.
- The four-scenario motion matrix restored `quickshell/.config/quickshell/config.json` byte-for-byte; its local debug modification remains intentionally uncommitted.
- Work-unit commit: `911810a feat(bar): wire configurable motion policy`.

### L7 — User correction/evidence (verbatim)
"Key evidence: right wrapped mask doubles targetProxy.x (IslandGeometry.qml:46-55, NotchIslandMask.qml:27+141), shifting fill +wrapDepth relative to content; left rotation maps canonical L cap to physical bottom but section frame still uses -L/proxyY=L (latent when L≠R). Definite dashboard issues: CenterPanel.qml:59 forces fullscreen catcher hole x=0 even for right; BarSection.qml:41 reserves current target width and Bar.qml:65-69 includes center, so expansion reserves 260px and reflows tiles rather than overlaying. Both surfaces explicitly Top; screenshots do not prove actual below-normal-window stacking."

### L8 — T6/T7 implementation and verification
- Corrected edge-specific physical extents for the rotated left source, localized the right vertical mask body/caps so `targetProxy.x` is applied once, and aligned the right native-blur regions with the same frame.
- Made vertical exclusion use collapsed widths, including the expanded center (`260` visual width reserves `37`) and endpoint width (`46`, not `sideTabHeight=220`); aligned the right fullscreen catcher hole to `popup.width - centerWidth`.
- Qt6 `qmllint` passed on the touched QML set with only the documented `PanelWindow` warning; `git diff --check` passed.
- Independent static verification passed all seven invariants, including 2,688 top/bottom scalar comparisons, asymmetric extents, endpoint reservation, output-local catcher, and intentional `config.json` state.
- Hard reloads reached `Configuration Loaded` without runtime `ERROR` or `WARN`; settled `DP-1` capture `/tmp/quickshell-t20-dp1-settled.png` was inspected. Pointer behavior and actual compositor stacking remain unverified because this Hyprland build rejected the available `hyprctl dispatch` syntax and no pointer injector is installed.
- Work-unit commit: `7a20bfc fix(bar): align lateral masks and dashboard geometry`.

### L9 — Documentation sync
- Updated `specs/bar.md`, `specs/configurable-bar.md`, and `DESIGN.md` to describe the corrected right mirrored frame, collapsed vertical reservation, and the explicit boundary between static reservation/catcher checks and unverified live pointer/compositor behavior.
- Work-unit commit: `7b77eb5 docs(bar): document corrected lateral contracts`.

### L10 — User correction (verbatim)
"Vale, ahora sí se encima, pero ahora hay más problemas (además del de la geometría que no se han resuelto). Te dejé un video en recordings de quickshell"

### L11 — Recording evidence (verbatim)
"Inspected all requested frames/files. Key confirmed persistent issue: vertical centerTab is 260×520 but inner body retains horizontal preferredHeight=260−16=244 and only fillWidth, leaving large empty top/bottom and a ~132px media column. Key8 is intermediate closing size, not settled width; keys9/11/12 settled. Left x=0 and center y remain correct. Also left endpoint flags all true suppress both wraps; sectionId-specific cap handedness diverges from IslandBlurRegion's fixed cap cutouts. Found extra structural RCC clipping risk/thumbnail support: Bar vertical surface width272 while RCC x≈102,width360, so service panels/backdrop get clipped to narrow bar surface."

### L12 — T8/T22 implementation and static verification
- Made `BarSection` reservation width explicit, stacked the lateral center header through `GridLayout`, made the expanded vertical body fill the physical center frame, and excluded hidden clock-date width from collapsed sizing.
- Qt 6.12 `qmllint` passed on the touched QML set with only known unqualified/import/singleton warnings; `git diff --check` passed. Runtime reload remains intentionally deferred until Quickshell is rebuilt for the installed Qt 6.12.0.
- Work-unit commit: 341c071.

### L13 — T9/T23 vertical RCC surface correction
- Expanded vertical `Bar` PanelWindow surfaces to the owning output width while retaining the narrow edge-pinned section geometry and collapsed `exclusiveZone`, so the in-surface RCC body/backdrop is not clipped by the bar's visual width.
- Qt 6.12 `qmllint` passed on `Bar.qml`, `RightControlCenter.qml`, `BarSection.qml`, and `IslandGeometry.qml`; `git diff --check` passed. Runtime RCC validation remains deferred until Quickshell is rebuilt for the installed Qt 6.12.0.
- Work-unit commit: 8d1cecf.

### L14 — T9/T19/T24 lateral endpoint parity correction
- Restored the canonical complementary endpoint flags so left/right lateral sections retain one cap and one inward wrap each, while top/bottom/right behavior remains unchanged.
- Made the rotated native-blur cap cutouts follow the visible mask's `sectionId`-specific `topLeft/topRight` handedness; static checks passed for both endpoint cases and center fallback.
- Verified that the visible rotated source and native blur consume the same scalar wrap gates for both endpoint sections, with no changes to the shared top/bottom scalar contract.
- Qt 6.12 `qmllint` passed on the touched mask/blur set and `git diff --check` passed. Runtime visual confirmation remains deferred until Quickshell is rebuilt for Qt 6.12.0.
- Work-unit commit: a5c5156 (shared by T19/T24).

### L15 — T9/T25 documentation synchronization
- Updated `specs/bar.md`, `specs/configurable-bar.md`, and `DESIGN.md` to distinguish the visually bounded lateral islands from the full-output vertical owner surface, preserve narrow collapsed `exclusiveZone`, and document shared cap/wrap parity between visible and native-blur paths.
- `git diff --check` and targeted contract-text checks passed. Runtime status remains unchanged: rebuild Quickshell against Qt 6.12.0 before compositor validation.
- Work-unit commit: 6c0e04d.

### L16 — T4/T15 Qt 6.12 runtime and rotated geometry comparison
- Rebuilt and installed Quickshell 0.3.2 (revision 4f508be) against system Qt 6.12.0; clean startup and hard reloads reached `Configuration Loaded` without `ERROR` or `WARN`.
- Settled top/bottom/left/right captures on DP-1 and DP-2 passed with `hyprctl layers`, reservations of 42px for top/bottom and 74px for left/right, empty `hyprctl configerrors`, and byte-for-byte restoration of the intentional `config.json` state.
- Rotated left/right strips by the inverse physical-axis transform and compared connected debug-silhouette masks against top/bottom. Top/bottom profiles matched exactly; left/right profiles matched each other after rotation. The 74px versus 42px thickness is explained by `sideTabWidth` versus `sideTabHeight`, while the shared 16px absolute radius remains consistent; no geometry correction was justified.
- Manual pointer hit-testing, outside-click/Escape, and open RCC interaction remain explicitly unclaimed because the host has keyboard-only `wtype` and no pointer-click dispatcher.

### L17 — User correction (verbatim)
"Sigue sin quedar bien la geometría de left y right"

### L18 — User decision (verbatim)
"Primera y segunda opción"
- Scope: correct both lateral proportion/thickness perception and notch/cap/wrap handedness while preserving upright content, collapsed reservation, monitor ownership, native-blur/input parity, and the accepted top/bottom baseline.

### L19 — T4/T30 lateral endpoint-Y correction and bounded verification
- Corrected the shared lateral Y frame so both left and right consume the canonical source-right `rightExtent` in `IslandGeometry.sectionOffsetY`, `targetProxyY`, and `maskOffsetY`; right mirrors only the physical X axis. This aligns asymmetric endpoint masks and native blur with the upright target without changing horizontal top/bottom branches.
- Qt 6.12 `qmllint`, JSON validation, `git diff --check`, and static scalar invariants passed. Fresh DP-1 runtime captures for top/bottom/left/right reached `Configuration Loaded` without `ERROR`/`WARN`, preserved reservations of 42/42/74/74, and restored the intentional `config.json` byte-for-byte.
- Rotated DP-1 visual/profile evidence shows preserved top/bottom parity and mirrored left/right geometry; the post-fix center XOR is 74 pixels (0.143%). An independent verifier passed the endpoint-Y correction and found no blocking geometry issue.
- Full N-monitor/seam verification is blocked because the compositor currently reports only DP-1; DP-2 disappeared during the matrix and needs external reconnection. Pointer, outside-click, Escape, RCC interaction, and native-blur pixel accuracy remain explicitly unclaimed.

### L20 — User correction and new visual-evidence criterion (verbatim)
"No ha quedado correctamente todavía. Mira, te cambié de fondo de pantalla que no tenga tantos matices rojos y evitar confusiones. Sigue con la misma técnica que te dije de las capturas por favor. Puedes seguir iterando hasta que notes que ya no haya tanta diferencia entre los de referencia."

### L21 — T4 neutral-wallpaper convergence iteration
- Neutral-wallpaper DP-1 captures isolated a structural lateral thickness mismatch: top/bottom measured 42px while left/right measured 74px. The mismatch came from the vertical center tab using horizontal `Theme.spacingXl` as cross-axis padding.
- Changed `Bar.qml` so `centerTab.paddingH` uses `Theme.spacingSm` when vertical and retains `Theme.spacingXl` for top/bottom. Qt 6.12 `qmllint`, JSON validation, and `git diff --check` passed with only documented warnings.
- Fresh neutral DP-1 top/bottom/left/right reload captures passed with clean `Configuration Loaded`, no `ERROR`/`WARN`, reservations 42/42/60/60, and byte-for-byte config restoration. Rotated profiles then measured 42px for all four orientations; the lateral mirror XOR was 149 pixels (0.503%) and visually sparse around raster/content edges.
- The final geometry decision is bounded to this evidence: no additional QML iteration is justified without a new structural mismatch. DP-2 remains absent from the compositor; pointer/outside-click/Escape/RCC interaction and native-blur pixel accuracy remain unclaimed.

### L22 — T4/#30 final neutral-wallpaper lateral geometry evidence
- Reworked vertical wrap ownership so the rotated canonical source remains authoritative, disabled duplicate external vertical wraps, preserved the accepted 42px lateral frame/reservation, restored the canonical first-wrap handedness, and used the existing configurable `Theme.barCurveRadius` through `BarSection.wrapRadius` for vertical wraps. The second service-endpoint wrap uses the matching `topLeft` Canvas corner after rotation.
- The final clean DP-1 matrix covered top, bottom, left, and right. Every hard reload reached `Configuration Loaded` without `ERROR`/`WARN`; reservations were 42px on all four edges; `config.json` was restored byte-for-byte with hash `f5ce1203345cfcd4466a0df6a434b12d032d7675a825d0ee3b2db2dbeeecb7c1`; `configerrors` was empty.
- Final rotated profiles preserved the 42px center contour and measured endpoint spans of 52/52 top/bottom, 50/51 left, and 50/52 right at the strict silhouette threshold. The final contact sheet shows no gross visual mismatch; the bounded 1–2px services-endpoint residual is Canvas/rasterization-level evidence, not a new structural mismatch.
- Qt 6.12 lint, JSON validation, and `git diff --check` passed. DP-2 remains absent from the compositor; pointer/outside-click/Escape/RCC interaction and native-blur pixel accuracy remain explicitly unclaimed.

### L23 — User correction (verbatim)
"No, todavía no queda. Aunque te acercaste bastante, sigue iterando por favor"

### L24 — T4/#53 wrapRadius correction and runtime evidence
- Corrected the remaining lateral endpoint mismatch by making vertical canonical wrap width use the existing `wrapRadius` token instead of the scaled `cornerSize`; kept horizontal source dimensions unchanged. Updated all four vertical native-blur wrap regions to use the same radius/ellipse dimensions so visible mask and blur remain aligned.
- Recovered the single Quickshell process after the prior IPC no-op incident. The fresh `runtime-neutral-reopened2` four-edge matrix passed reservation probes: top/bottom/left/right all reserved 42px, reloads succeeded, `config.json` restored byte-for-byte, and `configerrors` remained empty.
- Final rotated profiles measured 52/52 endpoint spans top/bottom, 52/51 left, and 52/52 right, with a 42px center contour. The contact sheet was reviewed and the prior gross service-endpoint mismatch is no longer visible; the remaining left 1px is bounded Canvas rasterization.
- Qt 6.12 lint, JSON validation, and `git diff --check` passed after the correction. DP-2 remains absent; pointer/outside-click/Escape/RCC interaction and native-blur pixel accuracy remain explicitly unclaimed.

### L25 — User geometry correction (verbatim)
Vale, para el izquierdo quiero: los wraps sobresalen hacia la derecha, otros 12px

### Isla superior (izquierda con bottom como referencia)

- Pegada al borde superior y = 0
- Workspaces por defecto
- Cuerpo con ancho común de 42 px.
- Tiene única wrap exterior en su extremo superior
- Agrega 16 px de extensión geométrica hacia el lado interno (inferior) para el cap/notch.
- Flags: creo que se deberían de pensar nuevas flags para cuando sean laterales (top/bottomCornerEnabled, leftTop/leftBottomRounded) con false, true, false, true

### Isla central

Creo que la estuviste tocando muchas veces y en realidad dentro de las primeras iteraciones ya había quedado prácticamente jaja. Solo era ajustar mejor las geometrías de los extremos.

### Isla inferior (derecha con bottom como referencia).

- Pegada al borde inferior
- Contiene servicios, divisor y power por defecto
- Flags: similar a la isla superior, pero con true, false, true, false.

### Punto importante

Los anchos se convierten en alturas y alturas en anchos, viniendo de la referencia bottom, debido a que es un cambio de horizontal a vertical.

Veamos si esto te ayuda un poco

### L26 — T4/#54 physical lateral endpoint flags and final verification
- Added physical lateral flags to `BarSection`: `topCornerEnabled`, `bottomCornerEnabled`, `outerTopRounded`, and `outerBottomRounded`. `Bar.qml` assigns `false,true,false,true` to the upper workspace island and `true,false,true,false` to the lower services/power island; horizontal top/bottom flags and the center island remain unchanged.
- Corrected the rotated-source mapping so source-left feeds physical bottom and source-right feeds physical top. This places each lateral wrap at its physical upper/lower endpoint and extends it inward: rightward from the left edge and leftward from the right edge. `IslandBlurRegion` consumes the same mapped flags.
- Final Qt 6.12 lint and `git diff --check` passed with only known warnings. Fresh hard-reload matrices on DP-1 and DP-2 passed top/bottom/left/right reservations of 42px, empty `configerrors`, clean layer ownership, and exact restoration of `config.json` hash `f5ce1203345cfcd4466a0df6a434b12d032d7675a825d0ee3b2db2dbeeecb7c1`.
- Corrected endpoint profiles confirmed left wraps extend inward to `x=42` from the `x=0..39` body at both physical upper/lower endpoints, while right wraps extend inward to `x=47` from the `x=50..89` body. No center redesign was made. Pointer/outside-click/Escape/RCC interaction and native-blur pixel accuracy remain explicitly unclaimed.
- No commit or push was created, per the user's explicit instruction.

### L27 — User correction (verbatim)
Pues las geometrías siguen sin coincidir

### L28 — User authorization (verbatim)
Tuvimos una buena mejora, puedes hacer commit para luego mejorar sobre lo que vamos logrando hasta ahorita

### L29 — T4/#56 checkpoint scope
- Create a checkpoint from the current lateral-geometry improvement: physical top/bottom flags, corrected source mapping, 42px lateral body width, and the corrected source-right `topRight` upper wrap. Preserve the known lower-endpoint mismatch for the next geometry iteration.
- Commit is explicitly authorized by L28; push remains unauthorized.
