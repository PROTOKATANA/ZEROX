# INFORME RI-3c — revisión independiente de la lógica del nodo (`zx-node`, `zx-post::servicio_pot`)

**Revisor:** subagente Sonnet (RI-3c). **Fecha:** 2026-09-27, 00:40–00:56 (≈16 min de análisis + reproducción;
presupuesto 2 h, no agotado). **Commit revisado:** `de26376` (W06d5 ya migrada). **Entrada:**
`sha256sum -c P-ZRX/P-REVISION-CODIGO/ENTRADA-RI-3.sha256` desde la raíz → `La suma coincide` para
`ORDEN-RI-3.md` y `ORDEN-RI-1.md` (las dos únicas entradas listadas en ese fichero).

**Alcance cubierto:** `crates/zx-node/src/{nodo.rs, regimen.rs, pow.rs, rechazo.rs}`,
`crates/zx-node/src/bin/zx-adversario.rs`, `crates/zx-post/src/servicio_pot.rs`. Excluido, tal como pide
`ORDEN-RI-3.md`: lo ya declarado en `P-ZRX/P-NODO/REVISION-W06d5.md` (falta de sincronización PoST por
lotes, dial sin reintento, motivo oculto en `P2pError::Transporte`, falta de tests de las decisiones 1 y
2) y lo ya reportado en `REVISION-RI-3a.md`/`REVISION-RI-3b.md`.

## Tabla de hallazgos (por gravedad)

| # | Gravedad | Archivo:línea | Resumen | Estado |
|---|---|---|---|---|
| H1 | **Crítica** | `crates/zx-node/src/nodo.rs:493-506` (PoW) y `:746-758` (PoST) | Un bloque (propio **o de red**) que pasa la verificación de cabecera pero es rechazado por `zx-cadena::admitir` (motivo `Legitimo` **o** `Interno`) queda **persistido en el almacén** antes de saberse rechazado, sin deshacerse. `Nodo::reiniciar` repite esa entrada fantasma sin distinguirla y su rechazo, sin manejo especial, tira todo el arranque: el nodo no puede volver a arrancar nunca. | **CONFIRMADO** (reproducido) |
| H2 | Media/Plausible | `crates/zx-node/src/rechazo.rs:113-118` (`clasificar_cabecera_pendiente`) frente a `crates/zx-post/src/cabecera_conjunta.rs:153-159` (`MotivoCabeceraPendiente::PruebaPotIncoherente`, `RangoSinAtadura`) | Dos variantes de `MotivoCabeceraPendiente` están documentadas en su propio módulo como «por construcción no debería ocurrir» (violación de invariante de la librería de verificación, no falta de contexto local), pero `rechazo.rs` las clasifica, junto con el resto, como `Pendiente` sin distinción: nunca fatal, nunca penaliza, se reintentan indefinidamente (hasta el tope de la cola). Si alguna vez disparan, el nodo las trata como un hueco local benigno en vez de una señal de alarma. | PLAUSIBLE (no reproducido: forzar esas dos ramas exige un caso que la propia librería declara inalcanzable) |

No se encontraron hallazgos adicionales de gravedad alta o crítica en la puerta de garantía antes de
producir (decisión 1 de W06d5), en el filtro de padres extra (decisión 2), ni en la clasificación general
Legítimo/Interno de `rechazo.rs` fuera de lo anotado en H2 (ver «Revisado sin hallazgos» más abajo).

---

## H1 (crítica, CONFIRMADO): un bloque rechazado por `zx-cadena` queda persistido para siempre y bloquea todo reinicio futuro

### Regla contra la que se revisa

`ORDEN-W06d1` decisión 4 (tubería de admisión única) y decisión 7 (D-N03′: reiniciar repite el registro
del almacén sin re-verificar cabeceras); `ORDEN-RI-3.md` §«Qué buscar» (RI-3c): «ventanas en que un fallo
deja el almacén y `zx-cadena` desalineados».

### El defecto

En `admitir_pow_interno` (`nodo.rs:389-541`) y en `admitir_post_interno` (`nodo.rs:613-772`), el orden de
operaciones es:

1. Verificar la cabecera (`verificar_cabecera_pow` / `verificar_cabecera_conjunta`).
2. Si `!ya_admitido && verificar`: **persistir en `self.almacen`** (`nodo.rs:493-496` para PoW,
   `:746-749` para PoST).
3. Si `!ya_admitido`: **admitir en `self.cadena`** (`nodo.rs:500-506` para PoW, `:752-758` para PoST). Si
   `cadena.admitir` devuelve `Err(MotivoBloque)`, la función propaga ese error con `?`/`.map_err(...)?`.

El comentario que justifica este orden (`nodo.rs:487-492` y `:735-745`) solo razona sobre la
**seguridad frente a un `SIGKILL` entre los dos pasos** («si el proceso muere entre las dos, el reinicio
repite desde el almacén… al revés perdería el bloque sin dejar rastro»): asume implícitamente que, una
vez pasada la verificación de cabecera, `cadena.admitir` **siempre tendrá éxito**. Pero
`cadena.admitir` puede rechazar el bloque por motivos que **no** dependen de la cabecera —el motor de
transición (`ErrGarantia`, `ErrMergeDepth`, `ErrMergeset`, `ErrU2`, cualquier `ErrTransicion` incluido
`ErrEmision`/`ErrSaldo`, etc.)— y esos son exactamente los motivos que `rechazo.rs` clasifica como
`Legitimo` (normales, esperables: W06d5 decisión 3 documenta que `ErrGarantia` y `ErrMergeDepth` se
**evidenciaron en vivo**, V5-1 y V6(b) de `REVISION-W06d4.md`) o `Interno`.

En ese momento el bloque ya está escrito en `self.almacen` (paso 2), y **no hay ningún paso que lo
retire** si el paso 3 falla. El almacén queda con una entrada que `zx-cadena` nunca admitió: almacén y
`zx-cadena` divergen (el propio riesgo que `ORDEN-RI-3.md` pide comprobar).

Esta ruta (`admitir_pow_interno`/`admitir_post_interno` con `verificar = true`) es la que usan **tanto**
un bloque propio (`fase_pow`, `fase_regimen`) **como** un bloque llegado por red
(`intentar_admitir_pow_de_red:1078`, `intentar_admitir_post_de_red:1216`) — la «tubería única» de la
decisión 4. Un bloque de un par honesto que pierde una carrera de garantía/mergeset por un evento
concurrente en la rama de este nodo (exactamente el caso que `rechazo.rs` llama `Legitimo` y documenta
como normal) basta para persistir la entrada fantasma.

`Nodo::reiniciar` (`nodo.rs:310-350`) repite **todo** el registro del almacén con `verificar = false`
(`repetir_uno:352-382`, `admitir_pow_interno`/`admitir_post_interno` sin volver a verificar la cabecera,
D-N03′) y llama a `cadena.admitir` otra vez sobre la entrada fantasma. Como el estado que se reconstruye
hasta ese punto es determinista, `cadena.admitir` vuelve a fallar con el **mismo** motivo, y el bucle de
`reiniciar` (`nodo.rs:331-335`, `self.repetir_uno(*hash, valor, indice)?;`) no distingue esa clasificación:
el error se propaga sin más hasta `Nodo::arrancar`, que devuelve `Err`. **El proceso no puede volver a
arrancar nunca**, aunque el bloque nunca fue válido y no había nada que preservar.

Contraste revelador: `arranque_limpio` (`nodo.rs:269-306`, el camino del génesis) hace las cosas en el
orden **contrario y seguro** — admite en `cadena` primero (`:277-293`) y solo si eso tiene éxito persiste
en el almacén (`:294-295`) — lo que confirma que el orden invertido en la tubería principal es un
descuido, no una decisión deliberada aplicada de forma consistente.

### Impacto

- **Disponibilidad, remoto:** cualquier par (incluso honesto, por una simple carrera `Legitimo`; con más
  razón un adversario que fabrique un bloque cuya cabecera es real pero cuya transición se rechaza) puede
  hacer que un nodo objetivo persista una entrada fantasma con un solo mensaje aceptado por gossipsub o
  sincronización. La próxima vez que ese nodo se reinicie (mantenimiento, caída, actualización), el
  reinicio **falla de forma determinista y permanente** hasta que un operador repare el almacén a mano.
  Es una vía de denegación de servicio persistente de bajísimo coste para el atacante (un mensaje, sin
  necesidad de que el nodo llegue nunca a *aceptar* el bloque inválido).
- **Operación normal:** incluso sin adversario, W06d5 decisión 3 documenta `ErrGarantia`/`ErrMergeDepth`
  como sucesos **esperados** en producción con varios nodos concurrentes; cualquiera de ellos, si ocurre
  justo cuando se está persistiendo el bloque, deja el almacén con una entrada que impedirá el próximo
  reinicio.

### Reproducción (CONFIRMADO)

Copia de la raíz en `deepseek/RI-3c/ws/` (`tar --exclude=./PDF --exclude=./deepseek --exclude=./target`,
enlace `PDF`), `CARGO_HOME`/`CARGO_TARGET_DIR` en la zona, `--locked`, `-j 4`. Test añadido **solo en la
copia** (no se tocó `crates/` de la raíz), como módulo `#[cfg(test)]` al final de
`crates/zx-node/src/nodo.rs` (mismo patrón que los tests `pruebas_v7`/`pruebas_deposito_sensible_a_la_rama`
ya existentes en el archivo, que usan acceso directo a los métodos privados del `Nodo`):

Construye una cabecera PoW **real** (minada de verdad con `zx_consensus::minar` sobre el target dev,
sin trampas) que extiende el génesis, con una coinbase cuyo importe (51) supera el subsidio dev
(50 ZZK) — el motor de transición la rechaza con `ErrEmision`
(`crates/zx-consensus/src/transicion/aplicar.rs:857-859`, `coinbase_pagada > tope`), clasificado como
`Interno` por `rechazo.rs` (el mismo defecto de orden alcanza igual a un motivo `Legitimo`: el código no
distingue). Llama a `nodo.admitir_pow_interno(cabecera_minada, ..., verificar = true)` (la misma ruta que
usan la red y la producción propia), comprueba que el almacén quedó con la entrada persistida pese al
rechazo, y luego reinicia el nodo desde el mismo directorio.

Comando y salida literal:

```
$ cd /home/katana/zeo/ZEROX/deepseek/RI-3c/ws
$ export CARGO_HOME=/home/katana/zeo/ZEROX/deepseek/RI-3c/.cargo-home
$ export CARGO_TARGET_DIR=/home/katana/zeo/ZEROX/deepseek/RI-3c/target
$ export GIT_CEILING_DIRECTORIES=/home/katana/zeo/ZEROX/deepseek/RI-3c
$ nice -n 19 cargo test -p zx-node --lib --locked -j 4 \
    nodo::pruebas_ri3c_persistencia_antes_de_admitir -- --test-threads=4 --nocapture

   Compiling zx-node v0.0.0 (/home/katana/zeo/ZEROX/deepseek/RI-3c/ws/crates/zx-node)
    Finished `test` profile [unoptimized + debuginfo] target(s) in 1.05s
     Running unittests src/lib.rs (.../zx_node-1e3c2c4b380181e5)

running 1 test
RI-3c: Nodo::arrancar (reinicio) devolvió Err: bloque propio 000025d85b57140ef89996b577b34171728bf6867a68f4991f0d05504f9856e2 rechazado en la admisión: ErrEmision
test nodo::pruebas_ri3c_persistencia_antes_de_admitir::bloque_pow_propio_rechazado_por_cadena_queda_persistido_y_bloquea_el_reinicio ... ok

test result: ok. 1 passed; 0 failed; 0 ignored; 0 measured; 25 filtered out; finished in 38.17s
```

El test comprueba explícitamente, en este orden: (1) `admitir_pow_interno(..., verificar=true)` devuelve
`Err`; (2) `!nodo.cadena.es_valido(&hash)` (el bloque nunca quedó admitido); (3)
`nodo.almacen.longitud_registro()` pasó de 1 (génesis) a **2** — el bloque rechazado quedó escrito en
disco; (4) tras `drop(nodo)`, un **segundo** `Nodo::arrancar(&cfg)` sobre el mismo directorio devuelve
`Err` — el reinicio falla, con el mismo `ErrEmision`, tal como predice el análisis. El test pasa (`1
passed`), es decir, **el comportamiento defectuoso descrito se reprodujo tal cual**.

**Alcance de la generalización:** se reprodujo con el camino PoW (`admitir_pow_interno`) y un motivo
`Interno` (`ErrEmision`) porque no exige montar el aparato de parcelas/PoT necesario para un bloque PoST
real. El mismo patrón de código (persistir antes de `cadena.admitir`, sin deshacer) está presente de forma
idéntica en `admitir_post_interno` (`nodo.rs:746-758`) y alcanza igual a los motivos `Legitimo`
(`ErrGarantia`, `ErrMergeDepth`, `ErrMergeset`, `ErrU2`, `ErrPowTrasCorte`) que a los `Interno`: esta parte
es **derivación** de la lectura del código (misma estructura `if !ya_admitido && verificar { persistir } …
if !ya_admitido { cadena.admitir(...)? }`), no una segunda ejecución independiente.

### Corrección sugerida (no aplicada; es responsabilidad de quien escriba la orden de corrección)

Invertir el orden como ya hace `arranque_limpio`: admitir primero en `zx-cadena` (que no tiene efectos en
disco) y persistir en el almacén **solo** si `cadena.admitir` tuvo éxito. Esto reintroduce la ventana de
pérdida de datos que el comentario original quería evitar (proceso muere entre `cadena.admitir` y
`almacen.admitir`), pero esa ventana es mucho más estrecha y, sobre todo, **su fallo es silencioso y
recuperable** (el bloque se puede volver a recibir/producir) frente al fallo actual, que es determinista y
permanente. Alternativas: un `almacen.retirar(hash)` explícito en el camino de error, o persistir en un área
«provisional» separada de la que lee `reiniciar`.

---

## H2 (media, PLAUSIBLE): `Pendiente` no distingue una violación de invariante de la librería de verificación de una falta de contexto local

### Regla

`ORDEN-RI-3.md` (RI-3c): «rechazos clasificados como “legítimos” [o, por extensión, “pendientes”] que en
realidad ocultan una violación de invariante… o al revés».

### El defecto

`rechazo::clasificar_cabecera_pendiente` (`rechazo.rs:113-118`) clasifica **toda** variante de
`MotivoCabeceraPendiente` como `Pendiente`, apoyándose en el docstring de ese tipo («ninguno de estos casos
es una prueba de invalidez: no deben cachearse como rechazo permanente»). Pero dos de sus variantes están
documentadas, en su propio módulo de origen, de otra manera:

- `PruebaPotIncoherente` (`crates/zx-post/src/cabecera_conjunta.rs:154-156`): «La prueba PoT devuelta no
  corresponde a esta cabecera. **Por construcción… no debería ocurrir**; se deja `Pendiente` en vez de
  declarar invalidez.»
- `RangoSinAtadura` (`:157-159`): «El rango validado no quedó atado a esta cabecera. **Por construcción…
  no debería ocurrir**; se deja `Pendiente`.»

Es decir: a diferencia de `Pot(PasadoIncompleto)` o `ContextoPiezaAusente` (que son, de verdad, huecos de
contexto **local** de este nodo, resolubles con más sincronización), estas dos variantes describen —según
la documentación del propio autor de `zx-post`— una situación que la construcción de los tipos
(`PruebaPotValidada`, `RangoSolucionValidado::validar`) debería hacer **imposible**. Si alguna vez se
alcanzan, no es un hueco de contexto: es evidencia de que esa garantía de construcción falló en algún
sitio (un bug real en `zx-post`, fuera del alcance de RI-3c, pero cuya **consecuencia** se decide aquí, en
`rechazo.rs`).

`rechazo.rs`, en el alcance de esta revisión, no distingue este caso: lo trata igual que un hueco local
benigno. Consecuencias de la clasificación uniforme:

- **Bloque propio:** `Pendiente` se descarta igual que `Legitimo` (decisión 3 extendida), sin marca
  especial, sin hacerse fatal — si el propio nodo construyó un bloque que dispara esta rama, la señal de
  alarma (algo se rompió en la propia verificación) se pierde en silencio.
- **Bloque de red:** nunca penaliza, se reencola indefinidamente (hasta el tope de 64,
  `TOPE_POST_PENDIENTES`) y se reintenta en cada avance del pasado (`reintentar_post_pendientes`). Si
  existiera una entrada capaz de disparar esta rama de forma reproducible (el propio código dice que «no
  debería ocurrir», no que sea imposible por construcción de tipos ajena al atacante), un adversario
  tendría una vía para mantener bloques en la cola de reintento sin que el nodo los penalice ni los
  descarte nunca de forma permanente.

### Por qué queda en PLAUSIBLE

No se intentó forzar `PruebaPotIncoherente`/`RangoSinAtadura`: exigiría construir manualmente los tipos
internos de `zx-post` (`PruebaPotValidada`, `RangoSolucionValidado`) de forma que discrepen de la cabecera
que dicen validar, y esas rutas están fuera del alcance de archivos de esta orden (`cabecera_conjunta.rs`
no es un archivo asignado a RI-3c). No hay evidencia de que sea alcanzable hoy desde el exterior; el
hallazgo es sobre la **clasificación en rechazo.rs** (sí en alcance), no sobre si el bug de invariante
existe de verdad en `zx-post`.

---

## Revisado sin hallazgos adicionales

- **Puerta de garantía antes de producir** (`regimen.rs:256-270`, `nodo.rs:1561-1578`, RD-9): el hilo
  productor no intenta `producir_en_regimen` para una clave sin `con_garantia`, calculada por el bucle
  sobre `Estado(padre_seleccionado)` una vez por slot; el bloque de transición tampoco se produce sin
  garantía propia (`fase_regimen:1561-1578`). Coherente y sin ventana de carrera detectada dentro de un
  mismo proceso (no hay `procesar_trabajo_red_pendiente()` entre la comprobación y la producción del
  bloque de transición).
- **Filtro de padres extra por slot** (`regimen.rs:329-371`, decisión 2 de W06d5): excluye todo padre
  extra cuyo slot no sea anterior al del bloque; el seleccionado se deja a `producir_en_regimen`
  (`SlotNoProgreso`, descartado con gracia). Correcto según lo revisado.
- **Doble firma tras reinicio:** `ServicioPot::nuevo` arranca siempre en `slot_actual = 0`
  (`servicio_pot.rs:183-195`); `Nodo::reiniciar` reconstruye el servicio de verificación reproduciendo
  **todas** las admisiones PoST persistidas (`actualizar_servicio_verificacion`, llamada sin condicionar a
  `verificar`, `nodo.rs:769`) antes de que `fase_regimen` clone ese servicio para el hilo productor
  (`nodo.rs:1590`). Como el flujo PoT es único y global (D-P10), `slot_actual()` tras la reconstrucción es
  el máximo slot de cualquier bloque PoST ya persistido (propio o ajeno), así que el hilo productor
  siempre avanza (`avanzar()`) a partir de ahí: no se revisita ningún slot ya usado por nadie. No se
  encontró una ventana en la que el mismo par `(clave, slot)` pueda producirse dos veces tras un reinicio
  o una reorganización PoST (las reorganizaciones de GHOSTDAG no tocan el flujo PoT, que es ajeno a la
  rama). Coherente con «Relanzamiento» punto 4 de `ORDEN-W06d1`.
- **Clasificación general de `rechazo.rs`:** los cuatro `MotivoBloque` marcados `Legitimo`
  (`ErrGarantia`, `ErrMergeDepth`, `ErrMergeset`, `ErrU2`, más `ErrTransicion(ErrPowTrasCorte)`) están
  justificados de forma consistente como funciones deterministas del estado compartido del DAG (no del
  orden de llegada de este nodo en particular): cualquier nodo con el mismo `past(B)` los rechazaría
  igual, así que penalizar al remitente de un bloque de red con estos motivos es coherente (a diferencia
  de `Pendiente`, que sí es un hueco puramente local). No se encontró un motivo mal ubicado en el sentido
  contrario (uno que debería ser `Interno`/fatal y está en la lista `Legitimo`, o viceversa), salvo la
  observación de H2.
- **`zx-adversario.rs`:** herramienta separada, no un modo del nodo binario; el orden de escenarios
  (huérfanos y PoST antes que PoW/coinbase, para no perder el mesh de gossipsub tras un baneo) está
  documentado y es coherente con lo observado. El escenario E-8 sigue explícitamente limitado (declarado
  en el propio docstring, no oculto) porque la herramienta no tiene clave privada de un productor real:
  no es un hallazgo nuevo.
- **`servicio_pot.rs`:** la poda de ventana (`podar`, retiene `ventana` slots) es consistente con la
  ventana de 4096 que usa el nodo (`ServicioPot::nuevo(terminal, n_dev, 4096)`); no se detectó una
  ventana insuficiente para los escenarios de la red dev (3 nodos, `F_slots = 600`). `declarar_salida_pasada`
  distingue correctamente un hueco legítimo (D-P10, mismo flujo, distinta rama) de una discrepancia real
  (`SalidaPasadaDiscrepante`).

## Lo leído

**Íntegros:** `crates/zx-node/src/nodo.rs` (2125 líneas), `crates/zx-node/src/regimen.rs`,
`crates/zx-node/src/pow.rs`, `crates/zx-node/src/rechazo.rs`, `crates/zx-node/src/bin/zx-adversario.rs`,
`crates/zx-post/src/servicio_pot.rs`, `crates/zx-node/src/padres.rs`, `crates/zx-cadena/src/error.rs`;
`P-ZRX/P-REVISION-CODIGO/{ORDEN-RI-3.md, ORDEN-RI-1.md, REVISION-RI-3a.md, REVISION-RI-3b.md}`;
`P-ZRX/P-NODO/{PLAN-W06.md, ORDEN-W06d1.md, ORDEN-W06d2.md, ORDEN-W06d3.md, ORDEN-W06d4.md, ORDEN-W06d5.md,
REVISION-W06d5.md}`; `P-ZRX/P-RED-DEV/PERFIL-DEV-v0.md`; `V-ZRX/LINEO.md`.

**Muestreados** (para entender el contexto que citan los archivos en alcance, sin ser objeto directo de la
revisión): `crates/zx-cadena/src/cadena.rs` (líneas ≈380-620: `admitir_pow`, `admitir_post`,
`chequear_forma`, selección de terminal); `crates/zx-consensus/src/transicion/aplicar.rs` (líneas
≈290-940: `aplicar_txs`, `aplicar_pow`, condiciones de corte); `crates/zx-post/src/cabecera_conjunta.rs`
(por `grep` dirigido a `MotivoCabeceraPendiente` y su documentación, líneas 130-330, no leído íntegro:
fuera de los archivos asignados a RI-3c).

## Fin

Hora de fin: 2026-09-27 00:56 (inicio 00:40; presupuesto de 2 h no agotado). Ningún proceso propio queda
vivo (`ps aux` comprobado tras el `cargo test`; los procesos de `deepseek/SL4c/` vistos en la comprobación
pertenecen a otra sesión en curso y no se tocaron). Zona escrita: solo
`/home/katana/zeo/ZEROX/deepseek/RI-3c/` (`ws.orig/`, `ws/` con el cambio de prueba descrito arriba,
`.cargo-home/` copiada de `deepseek/RI-3a/`, `target/`, `HORAS.log`, este `INFORME.md`).
