# Configurable Bar Visibility — Session 3
Status: Implemented (source commit `c4c7eb6`; documentation commit pending; pointer simulation and physical hot-plug remain unverified)
Scope: Apply `always`, `edge-reveal`, and `disabled` per monitor with external-edge-only reveal and overlay-safe lifecycle.

## Specs

### S1 — Visibility policies
> Implementar el comportamiento efectivo de:
>
> - `visibility: "always"`
> - `visibility: "edge-reveal"`
> - `visibility: "disabled"`

> ### `always`
>
> - La barra permanece visible.
> - Reserva su espacio normal mediante `exclusiveZone`.
> - Funciona igual que el comportamiento actual.

> ### `disabled`
>
> - No debe crearse una instancia visible de la barra para ese monitor.
> - No debe reservar espacio.
> - No debe crear una hot-zone invisible.
> - Los demás monitores deben continuar funcionando normalmente.
> - Los overlays independientes, como launcher o wallpaper, no deben romperse por la ausencia de esa barra.

> ### `edge-reveal`
>
> - La barra permanece oculta o reducida a una zona mínima de revelado.
> - Al alcanzar el borde elegible del monitor, la barra aparece con una animación.
> - Al abandonar la barra, debe ocultarse después de un retraso razonable.
> - Mientras está visible, debe mantener sus interacciones normales.
> - El estado de revelado debe ser independiente por monitor.
> - Revelar la barra de un monitor no debe revelar la de ningún otro.

### S2 — External edge eligibility
> La hot-zone sólo puede existir en un borde externo del layout de outputs.
>
> No crear hot-zones en seams compartidos entre monitores adyacentes.
>
> Para determinar si un borde es externo:
>
> - usar la geometría real de `ShellScreen`;
> - considerar `x`, `y`, `width` y `height`;
> - no usar índices;
> - no asumir orden;
> - no asumir que los monitores tienen la misma altura;
> - no asumir que están alineados;
> - no asumir solamente dos monitores.

> Si la posición elegida coincide con un borde compartido:
>
> - el seam debe quedar libre para cruzar el cursor;
> - no debe activar la barra de forma accidental;
> - el monitor debe conservar otro mecanismo explícito de acceso, como shortcut o IPC.

### S3 — Reservation, layer, and geometry
> Cuando la barra esté oculta:
>
> - no debe conservar la reserva normal de espacio;
> - debe conservar únicamente la superficie mínima necesaria para detectar el revelado;
> - la hot-zone debe permanecer en `WlrLayer.Top`;
> - no mover notificaciones ni OSD a otra capa;
> - no usar una superficie sin `screen` explícito;
> - no dejar que el compositor seleccione arbitrariamente el output.

> Cuando la barra esté visible:
>
> - restaurar el `exclusiveZone` normal;
> - conservar las dimensiones y offsets propios de `top`, `bottom`, `left` y `right`;
> - no alterar la geometría de las máscaras existentes.

### S4 — Overlay interaction
> El edge reveal no debe abrir overlays por hover. El hover sólo puede revelar la barra; abrir paneles sigue requiriendo interacción explícita.

> La barra debe permanecer visible mientras un panel interactivo que dependa de ella esté abierto, si ocultarla haría perder el foco, el input o el contexto visual.

### S5 — Visual and motion boundary
> Preservar:
>
> - islas actuales;
> - curvas;
> - wraps;
> - notch corners;
> - input mask;
> - blur;
> - estados hover/pressed;
> - power pill;
> - orientación vertical ya implementada.

> El movimiento de entrada y salida debe usar el sistema `Motion` o los tokens de animación existentes. No introducir duraciones o easing aislados sin justificarlo.

### S6 — Explicit non-goals
> No implementar en esta sesión:
>
> - barra continua;
> - dashboard desacoplado;
> - colores dinámicos;
> - paletas derivadas del wallpaper;
> - nuevas posiciones;
> - cambios de estilo de las islas;
> - cambios al overlay manager que no sean estrictamente necesarios para mantener consistencia de visibilidad.

### S7 — Documentation boundary
> Actualizar únicamente lo necesario en:
>
> - `specs/configurable-bar.md`
> - `specs/multi-monitor.md`
> - `specs/bar.md`
> - `specs/overlay-manager.md`
> - `DESIGN.md`
> - `AGENTS.md`

> Documentar claramente:
>
> - qué parte de `edge-reveal` quedó implementada;
> - cómo se detectan bordes externos;
> - qué ocurre en seams compartidos;
> - cómo se comporta `disabled`;
> - qué limitaciones siguen pendientes.

### S8 — Verification matrix
> Verificar como mínimo:
>
> 1. Un monitor con `always`.
> 2. Un monitor con `edge-reveal`.
> 3. Un monitor con `disabled`.
> 4. Dos monitores adyacentes horizontalmente.
> 5. Dos monitores con alturas diferentes.
> 6. Barra en `top`.
> 7. Barra en `bottom`.
> 8. Barra en `left`.
> 9. Barra en `right`.
> 10. Edge reveal en un borde externo.
> 11. Confirmar que el seam compartido no revela la barra.
> 12. Revelar una barra mientras la otra permanece oculta.
> 13. Salir de la barra y confirmar el retraso de ocultamiento.
> 14. Abrir el dashboard embebido desde una barra revelada.
> 15. Abrir y cerrar el control center.
> 16. Escape y click externo.
> 17. Monitor desconectado mientras una barra está revelada.
> 18. Configuración inválida y fallback seguro.
> 19. Hot-reload sin dejar una barra huérfana.
> 20. Qt 6 `qmllint` sobre los QML modificados.
> 21. Reload real de Quickshell sin errores.

## Tasks

- T1 [S1,S3] Implement per-monitor always/edge-reveal runtime state, hidden reservation, reveal strip, and Motion-gated transitions without changing existing geometry. Route: `Bar.qml` + configuration tokens. Commit: `c4c7eb6`.
- T2 [S2] Derive external-edge reveal eligibility from all connected `ShellScreen` rectangles and keep shared seams click-through. Route: `shell.qml` screen geometry helper + Bar inputs. Commit: `c4c7eb6`.
- T3 [S4] Keep Bar-owned interactive context revealed and reconcile reveal state across overlay open/close, hot-plug, and disabled filtering without touching standalone launcher/wallpaper ownership. Commit: `c4c7eb6`.
- T4 [S5,S6] Preserve masks, blur, input union, layer, screen pinning, and all existing four-edge geometry; add only required reveal gating. Commit: `c4c7eb6`.
- T5 [S7] Synchronize the six requested documents with the implemented boundary and remaining limitations. Commit: documentation commit pending.
- T6 [S8] Run structural, Qt 6 lint, reload, and available live matrix checks; record exact pass/fail/pending evidence. Commit: documentation commit pending.

## Log

### L1 — Original request
Quiero iniciar la Sesión 3 del sistema de barra configurable: implementar las políticas de visibilidad y el edge reveal por monitor.

   ## Objetivo

   Implementar el comportamiento efectivo de:

   - `visibility: "always"`
   - `visibility: "edge-reveal"`
   - `visibility: "disabled"`

   La base de configuración global y por monitor ya existe en `Theme.qml`, incluyendo el snapshot/resolver normalizado definido en la Sesión 1.

   La posición `top`, `bottom`, `left` y `right` ya está implementada desde la Sesión 2. Debes trabajar sobre esa implementación sin reescribir su geometría.

   ## Archivos y documentación a revisar

   Antes de escribir:

   - `quickshell/.config/quickshell/bar/Bar.qml`
   - `quickshell/.config/quickshell/shell.qml`
   - `quickshell/.config/quickshell/theme/Theme.qml`
   - `quickshell/.config/quickshell/config.json`
   - `quickshell/.config/quickshell/bar/CenterPanel.qml`
   - `quickshell/.config/quickshell/bar/RightControlCenter.qml`
   - `specs/configurable-bar.md`
   - `specs/multi-monitor.md`
   - `specs/overlay-manager.md`
   - `specs/bar.md`
   - `DESIGN.md`
   - `AGENTS.md`

   ## Comportamiento requerido

   ### `always`

   - La barra permanece visible.
   - Reserva su espacio normal mediante `exclusiveZone`.
   - Funciona igual que el comportamiento actual.

   ### `disabled`

   - No debe crearse una instancia visible de la barra para ese monitor.
   - No debe reservar espacio.
   - No debe crear una hot-zone invisible.
   - Los demás monitores deben continuar funcionando normalmente.
   - Los overlays independientes, como launcher o wallpaper, no deben romperse por la ausencia de esa barra.

   ### `edge-reveal`

   - La barra permanece oculta o reducida a una zona mínima de revelado.
   - Al alcanzar el borde elegible del monitor, la barra aparece con una animación.
   - Al abandonar la barra, debe ocultarse después de un retraso razonable.
   - Mientras está visible, debe mantener sus interacciones normales.
   - El estado de revelado debe ser independiente por monitor.
   - Revelar la barra de un monitor no debe revelar la de ningún otro.

   ## Regla de bordes externos

   La hot-zone sólo puede existir en un borde externo del layout de outputs.

   No crear hot-zones en seams compartidos entre monitores adyacentes.

   Para determinar si un borde es externo:

   - usar la geometría real de `ShellScreen`;
   - considerar `x`, `y`, `width` y `height`;
   - no usar índices;
   - no asumir orden;
   - no asumir que los monitores tienen la misma altura;
   - no asumir que están alineados;
   - no asumir solamente dos monitores.

   Si la posición elegida coincide con un borde compartido:

   - el seam debe quedar libre para cruzar el cursor;
   - no debe activar la barra de forma accidental;
   - el monitor debe conservar otro mecanismo explícito de acceso, como shortcut o IPC.

   ## Reserva y layer-shell

   Cuando la barra esté oculta:

   - no debe conservar la reserva normal de espacio;
   - debe conservar únicamente la superficie mínima necesaria para detectar el revelado;
   - la hot-zone debe permanecer en `WlrLayer.Top`;
   - no mover notificaciones ni OSD a otra capa;
   - no usar una superficie sin `screen` explícito;
   - no dejar que el compositor seleccione arbitrariamente el output.

   Cuando la barra esté visible:

   - restaurar el `exclusiveZone` normal;
   - conservar las dimensiones y offsets propios de `top`, `bottom`, `left` y `right`;
   - no alterar la geometría de las máscaras existentes.

   ## Interacción con overlays

   Verificar especialmente:

   - `CenterPanel`;
   - `RightControlCenter`;
   - `PowerMenu`;
   - `MprisPopup`;
   - `MetricsDropdown`;
   - launcher;
   - wallpaper selector.

   El edge reveal no debe abrir overlays por hover. El hover sólo puede revelar la barra; abrir paneles sigue requiriendo interacción explícita.

   La barra debe permanecer visible mientras un panel interactivo que dependa de ella esté abierto, si ocultarla haría perder el foco, el input o el contexto visual.

   ## Reglas visuales

   Preservar:

   - islas actuales;
   - curvas;
   - wraps;
   - notch corners;
   - input mask;
   - blur;
   - estados hover/pressed;
   - power pill;
   - orientación vertical ya implementada.

   El movimiento de entrada y salida debe usar el sistema `Motion` o los tokens de animación existentes. No introducir duraciones o easing aislados sin justificarlo.

   ## Fuera de alcance

   No implementar en esta sesión:

   - barra continua;
   - dashboard desacoplado;
   - colores dinámicos;
   - paletas derivadas del wallpaper;
   - nuevas posiciones;
   - cambios de estilo de las islas;
   - cambios al overlay manager que no sean estrictamente necesarios para mantener consistencia de visibilidad.

   ## Documentación

   Actualizar únicamente lo necesario en:

   - `specs/configurable-bar.md`
   - `specs/multi-monitor.md`
   - `specs/bar.md`
   - `specs/overlay-manager.md`
   - `DESIGN.md`
   - `AGENTS.md`

   Documentar claramente:

   - qué parte de `edge-reveal` quedó implementada;
   - cómo se detectan bordes externos;
   - qué ocurre en seams compartidos;
   - cómo se comporta `disabled`;
   - qué limitaciones siguen pendientes.

   ## Casos de verificación

   Verificar como mínimo:

   1. Un monitor con `always`.
   2. Un monitor con `edge-reveal`.
   3. Un monitor con `disabled`.
   4. Dos monitores adyacentes horizontalmente.
   5. Dos monitores con alturas diferentes.
   6. Barra en `top`.
   7. Barra en `bottom`.
   8. Barra en `left`.
   9. Barra en `right`.
   10. Edge reveal en un borde externo.
   11. Confirmar que el seam compartido no revela la barra.
   12. Revelar una barra mientras la otra permanece oculta.
   13. Salir de la barra y confirmar el retraso de ocultamiento.
   14. Abrir el dashboard embebido desde una barra revelada.
   15. Abrir y cerrar el control center.
   16. Escape y click externo.
   17. Monitor desconectado mientras una barra está revelada.
   18. Configuración inválida y fallback seguro.
   19. Hot-reload sin dejar una barra huérfana.
   20. Qt 6 `qmllint` sobre los QML modificados.
   21. Reload real de Quickshell sin errores.

   ## Documentación

   Actualizar únicamente lo necesario en:

   - `specs/configurable-bar.md`
   - `specs/multi-monitor.md`
   - `specs/bar.md`
   - `specs/overlay-manager.md`
   - `DESIGN.md`
   - `AGENTS.md`

   ## Proceso ODD

   - Explorar primero y reconciliar el task document antes del primer write.
   - Registrar la sesión en `odd/tasks/`.
   - Revisar el estado del worktree y no sobrescribir cambios ajenos.
   - Implementar por unidades pequeñas.
   - Usar verificaciones funcionales y Qt 6 lint.
   - Aplicar la regla de configurabilidad de `AGENTS.md`.
   - No implementar funcionalidades de sesiones posteriores.
   - No hacer push.
   - Al finalizar, reportar archivos modificados, checks exitosos, checks fallidos o pendientes y cualquier limitación.

### L2 — Exploration evidence
- Existing code filters `disabled` in `shell.qml` before `Variants`; `edge-reveal` is still instantiated and behaves like `always`.
- Existing geometry is screen-sized and four-edge aware; `exclusiveZone` is derived from collapsed section reservation and must be gated rather than recomputed.
- `RightControlCenter` is in the Bar input tree, while `CenterPanel` is a separate screen-pinned Top catcher; hidden input must account for geometry rather than visibility because `Region { item: }` is visibility-blind.
- The only unstaged worktree change before Session 3 is the user's `config.json` preference changing `bar.defaults.position` from `bottom` to `top`; it must remain untouched and excluded from delivery work.

### L3 — Implementation evidence
- `Bar.qml` keeps the existing four-edge geometry, gates `exclusiveZone` and the normal input union while hidden, animates child visual opacity with `Motion.Effects`, and keeps Bar-owned interactive surfaces revealed.
- `shell.qml` derives local edge intervals from all connected screen rectangles, subtracts positive-length opposing-edge overlaps, creates screen-pinned `Top` hot-zone surfaces, and exposes `bar reveal <ShellScreen.name>` for seam-only fallback access.
- `Theme.qml` adds configurable `bar.revealStripThickness` (`1..32`, default `4`) and `bar.revealHideDelay` (`100..10000` ms, default `700`).
- Qt 6 lint, JSON parsing, diff checks, and a clean hard reload passed. Temporary runtime checks confirmed zero hidden reservations, DP-1 left split external strips, DP-2 right seam exclusion, exact-screen IPC reveal, disabled filtering, and invalid visibility fallback. Pointer simulation was unavailable because this Hyprland build rejected the attempted `movecursor` dispatch forms; physical hot-plug was not exercised.

### L4 — Final verification evidence
- Final Qt 6 `qmllint` returned exit 0; remaining output is known `[unqualified]` style warnings and the existing singleton declaration warning, with no new semantic errors.
- Final policy matrix passed for `top`, `bottom`, `left`, and `right`: hidden `edge-reveal` reservations were zero on both outputs; `always` restored 42 px reservations; `disabled` created no reservations; invalid visibility fell back to `always`.
- Final overlay matrix passed: hidden edge-reveal, exact-screen reveal, right control-center open with the owning Bar reserved, and close after the configured delay.
- Final hard reload ended with `Configuration Loaded` and no `ERROR` after the last reload; the restored config diff contains only the pre-existing `bar.defaults.position` change from `bottom` to `top`.
- Native assessment was unavailable because the candidate includes this untracked feature document and the review controller requires an explicit intended-untracked declaration; the returned plan required only writer self-verification and no independent verifier.
