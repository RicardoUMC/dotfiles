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
- Implementation is ready for its work-unit commit; the commit identity will be recorded in the next log update.
