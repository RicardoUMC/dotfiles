# Per-Island Bar Reveal
Status: Iterating (uncommitted); preserve existing `always`, `edge-reveal`, and `disabled` behavior. Pointer/compositor and physical hot-plug verification remain pending by user decision.
Scope: Add a no-reservation visibility mode that reveals only the hovered bar island and keeps only the owning island visible with its overlay.

## Specs

### S1 — No-reservation individual island reveal
> Vale, me gustaría agregar una nueva opción las que tenemos. Mira, lo que tengo pensado es que, si bien ahorita la opción que tenemos permite pasar el cursor al menos el que tengo activado en este momento, es pasar el cursor para que se abra la barra, Ese siento que está bien. Pero también quisiera una opción en la que no desplace el contenido de la pantalla. Porque, de hecho, lo puedes revisar tú si creas una captura una grabación en donde veas que cuando pasa el cursor por encima, abre toda la barra, y que además desliza el contenido vuelve más pequeño el contenido de la aplicación que se estaba mostrando. Como como si aumentara el espacio reservado. Creo que es eso, ¿no? Yo, que quiero es algo diferente. Es una nueva opción, porque no es que me desagrade esta 1º opción, pero que permita poner por encima cada una de las islas de manera individual. Por ejemplo, a lo que me refiero es que si pongo el cursor por encima de donde estaría la isla de servicios, solo la isla de servicios sea la que salga, pero sin tener un espacio reservado como para que afecte los tamaños de las aplicaciones o de las ventanas que están presentes. Si lo paso en el área en donde estaría la isla de el dashboard, quiero que solo aparezca la islita del dashboard. Y que las otras 2 islas no aparezcan. O sea, que solamente aparezca la isla a la cual, entre comillas, se le está haciendo foco.

### S2 — Overlay ownership visibility
> Sólo isla dueña + overlay

### S3 — Island trigger footprint
> Banda fina en el borde

### S4 — Short configurable island hide delay
> Lo único que siento es que no es tan inmediato, el cambio para que se escondan, se vuelvan a esconder las islas. Siento que se tardan demasiado, no sé si haya por ahí algún delay que tengas. Pero, o sea, por ejemplo, pongo el cursor encima de la isla, está perfecto, funciona también, pero lo quito y pasa como un 2º para que se vuelva a esconder. Yo no quiero que tenga mucho delay. De hecho, si es algo que ahorita configuraste manualmente, estaría bien que a lo mejor lo pongas como un valor configurable. Ya ves, que todo esto es con la intención de tener un Shell lo más configurable posible, pudiera ser que lo podamos agregar, pudiera ser correcto, Esto a lo mejor no agregarlo a todas las animaciones, bueno, esa es otra cosa más bien. Las animaciones ahorita veo que no las tiene. Y me parece correcto porque es una 1º implementación.

### S5 — Position-aware organic reveal motion
> La otra cosa que te iba a comentar al respecto era justamente eso, que me gustaría agregar animaciones. Algo que no solo sea que salgan las islas, sino que, por ejemplo, en la isla central, no sé si se pueda hacer, porque tampoco sé qué tan complicado sea, El hecho de que caiga para abajo, pero que se sienta o se vea algo así así como una especie de líquido, aprovechando la forma de los notch. O sea, que se sienta algo orgánico, sin verse una animación entre comillas, genérica, no sé si me estoy dando a entender. Eso para el ejemplo de la isla central. Para las islas laterales, pensaba que el hecho de que estén ocupando finalmente un lateral y una parte superior? Para la barra que ahorita tenemos activa, que es la superior, A lo a lo mejor hacer que ese crecimiento o esa animación salga desde la esquina, o sea, que en algo así como que sea como que en diagonal? De acuerdo a la esquina en la que se encuentre. Espero que también me esté dando a entender. Todo esto considera que también se debe de replicar para cada una de las distintas posiciones en las que se pueden configurar la barra, porque no sé si eso también lo hayas considerado ahorita con la implementación. ¿Esas pruebas ahorita no las he realizado? Pero se me acaban de ocurrir, entonces yo creo que eso también es algo que hay que empezar a validar.

## Tasks

- T1 [S1] Extend the normalized visibility contract with the new per-island mode while preserving existing modes and fallback behavior. Route: `Theme.qml`, config schema, and configurable-bar documentation. Commit: pending.
- T2 [S1] Implement independent per-island hover zones, opacity/state transitions, and zero reservation/input displacement across all four bar positions. Route: `Bar.qml` and section geometry. Commit: pending.
- T3 [S2] Keep only the owning island visible while its Bar-owned overlay is open; preserve global overlay routing and disabled-screen reconciliation. Route: `Bar.qml` and `shell.qml`. Commit: pending.
- T4 [S1,S2] Verify multi-monitor, policy compatibility, four-edge geometry, overlay lifecycle, lint, reload, and available runtime behavior. Commit: pending.
- T5 [S4] Add a separate configurable short hide delay for `island-reveal` without changing `edge-reveal` timing. Commit: pending.
- T6 [S5] Design and implement a bounded position-aware reveal animation using existing Motion intents; keep physics-heavy liquid deformation future work until a concrete visual proof exists. Commit: pending.

## Log

### L1 — Original request
Vale, me gustaría agregar una nueva opción las que tenemos. Mira, lo que tengo pensado es que, si bien ahorita la opción que tenemos permite pasar el cursor al menos el que tengo activado en este momento, es pasar el cursor para que se abra la barra, Ese siento que está bien. Pero también quisiera una opción en la que no desplace el contenido de la pantalla. Porque, de hecho, lo puedes revisar tú si creas una captura una grabación en donde veas que cuando pasa el cursor por encima, abre toda la barra, y que además desliza el contenido vuelve más pequeño el contenido de la aplicación que se estaba mostrando. Como como si aumentara el espacio reservado. Creo que es eso, ¿no? Yo, que quiero es algo diferente. Es una nueva opción, porque no es que me desagrade esta 1º opción, pero que permita poner por encima cada una de las islas de manera individual. Por ejemplo, a lo que me refiero es que si pongo el cursor por encima de donde estaría la isla de servicios, solo la isla de servicios sea la que salga, pero sin tener un espacio reservado como para que afecte los tamaños de las aplicaciones o de las ventanas que están presentes. Si lo paso en el área en donde estaría la isla de el dashboard, quiero que solo aparezca la islita del dashboard. Y que las otras 2 islas no aparezcan. O sea, que solamente aparezca la isla a la cual, entre comillas, se le está haciendo foco.

### L2 — Product decision
Sólo isla dueña + overlay

### L3 — Trigger decision
Banda fina en el borde

### L4 — Implementation and verification evidence
- `Theme.qml` accepts `island-reveal` in global defaults and exact-name monitor overrides; invalid values retain the existing `always` fallback behavior.
- `Bar.qml` keeps `exclusiveZone` at zero for this mode, derives one thin trigger model per island from seam-safe external intervals, reveals one island at a time, gates hidden input and blur, and keeps only the owning island visible with an open center/services overlay.
- Qt 6 lint, JSON parsing, diff checks, and a clean hard reload passed. The runtime matrix passed zero reservations and trigger geometry for `top`, `bottom`, `left`, and `right`; compatibility checks passed for `always`, `edge-reveal`, `disabled`, invalid fallback, and island-mode overlay open/close without reservation.
- `Theme.islandRevealHideDelay` is configurable at `bar.islandRevealHideDelay` with default `140` ms and clamp `40..2000`; temporary valid (`90`) and clamped (`10`) reloads completed without errors.
- The first animation pass uses the non-interactive `BarSection` mask for scale/origin growth, `BarTab` opacity for content fade, `Motion.RevealSpatial`, `bar.islandRevealAxisStagger` (default `24`, clamp `0..200`), and settled-only island native blur; interactive endpoint descendants remain untransformed so their MouseAreas retain native hit coordinates.
- Pointer simulation remains unavailable because this Hyprland build rejected the attempted `movecursor` dispatch forms; therefore the actual visual handoff, click-through feel, and owner-only island persistence were not observed with a real cursor. Physical hot-plug was not exercised. Native assessment was not run for this untracked candidate; the prior controller requires explicit intended-untracked declaration.

### L5 — Closure decision
Acepto la iteración con verificación pendiente: cerrar documentando que falta la comprobación manual de puntero y hot-plug.

### L7 — Animation design evidence
- Caelestia reference research found anchored anisotropic growth with separate content effects in `modules/nexus/common/BlobPopup.qml` and radius flattening in `Utilities/Background.qml`. The adopted principle is axis-aware geometry plus separate opacity, not an SDF/plugin or physics-heavy deformation.
- Physical reveal origins are slot-based: top `TL/TR/TC`, bottom `BL/BR/BC`, left `TL/BL/LC`, and right `TR/BR/RC`.

### L6 — Iteration request
Lo único que siento es que no es tan inmediato, el cambio para que se escondan, se vuelvan a esconder las islas. Siento que se tardan demasiado, no sé si haya por ahí algún delay que tengas. Pero, o sea, por ejemplo, pongo el cursor encima de la isla, está perfecto, funciona también, pero lo quito y pasa como un 2º para que se vuelva a esconder. Yo no quiero que tenga mucho delay. De hecho, si es algo que ahorita configuraste manualmente, estaría bien que a lo mejor lo pongas como un valor configurable. Ya ves, que todo esto es con la intención de tener un Shell lo más configurable posible, pudiera ser que lo podamos agregar, pudiera ser correcto, Esto a lo mejor no agregarlo a todas las animaciones, bueno, esa es otra cosa más bien. Las animaciones ahorita veo que no las tiene. Y me parece correcto porque es una 1º implementación. La otra cosa que te iba a comentar al respecto era justamente eso, que me gustaría agregar animaciones. Algo que no solo sea que salgan las islas, sino que, por ejemplo, en la isla central, no sé si se pueda hacer, porque tampoco sé qué tan complicado sea, El hecho de que caiga para abajo, pero que se sienta o se vea algo así así como una especie de líquido, aprovechando la forma de los notch. O sea, que se sienta algo orgánico, sin verse una animación entre comillas, genérica, no sé si me estoy dando a entender. Eso para el ejemplo de la isla central. Para las islas laterales, pensaba que el hecho de que estén ocupando finalmente un lateral y una parte superior? Para la barra que ahorita tenemos activa, que es la superior, A lo a lo mejor hacer que ese crecimiento o esa animación salga desde la esquina, o sea, que en algo así como que sea como que en diagonal? De acuerdo a la esquina en la que se encuentre. Espero que también me esté dando a entender. Todo esto considera que también se debe de replicar para cada una de las distintas posiciones en las que se pueden configurar la barra, porque no sé si eso también lo hayas considerado ahorita con la implementación. ¿Esas pruebas ahorita no las he realizado? Pero se me acaban de ocurrir, entonces yo creo que eso también es algo que hay que empezar a validar.

### L8 — Animation implementation verification
- Replaced the invalid `NumberAnimation.delay` approach with a `SequentialAnimation` containing `PauseAnimation` plus the shared spatial animation; the hard reload now reports `Configuration Loaded` with no runtime errors.
- Qt 6.11 lint passes with only existing project warnings (`unqualified`, singleton discovery, and the repository's existing Motion directive diagnostics); JSON parsing, `git diff --check`, and corrected static policy checks pass.
- Final hard reload leaves both monitors at zero reservation: `DP-1 [0, 0, 0, 0]`, `DP-2 [0, 0, 0, 0]`. Pointer/compositor handoff, click-through feel, and physical hot-plug remain manual verification items.

### L9 — Clickability report and diagnosis
Te dejé un video de los primero dos puntos (y parte del 5), los otros, no puedo hacer clicks a los botones, no me deja
- Diagnosis: conditional `PendingRegion.item` bindings may not refresh reliably during live island handoff. The fix keeps each region attached to a stable untransformed proxy whose geometry becomes zero or follows the visible section.

### L10 — Recording inspection
- Located four recordings under `/tmp/quickshell-recordings/` and inspected their frames. The newest recording (`screen_20261025_231007.mp4`) does show the top bar and the center Media/MPRIS popup opening; its sampled frames do not identify a specific nested button whose click fails or show a failed action result.

### L11 — Final input and overlay evidence
- The user confirmed that the islands are now activatable in all configured positions after the direct `BarTab` hover ownership, hide-timer guards, and untransformed interactive-content fixes.
- Static ownership checks confirm center and right overlays force their owning island visible, close through the global overlay manager, and preserve single-root exclusivity. Qt 6 lint, `git diff --check`, and zero reservations remain clean.
- Visual animation timing, cursor handoff feel, and physical hot-plug remain manual checks; no claim is made for those unavailable observations.
