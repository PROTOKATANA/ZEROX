# Definiciones faltantes — SL-4b2

Ninguna de las siguientes paró la ejecución (no eran bloqueantes): se registran aquí, antes de que
el informe las dé por hechas, porque cada una implicó una elección de diseño no literal en la orden.

## 1. Decisión 2 — «quítalas de la API pública de zx-post o márcalas `#[cfg(test)]`»

El contrato de implementación (§4) permite editar `crates/zx-post/src/{lib.rs, productor.rs,
productor_regimen.rs}` «solo para retirar del alcance del nodo las funciones sin firmante», y por
otro lado solo permite tocar tests **nuevos** (no los ya existentes). Los dos tests de integración
`crates/zx-post/tests/regimen.rs` y `crates/zx-post/tests/firmante_productores.rs` (fuera de mi zona
editable, no son "tests nuevos") siguen llamando a `producir_en_regimen`/`producir` (las funciones
sin firmante) como parte de su verificación de que ambas rutas de sellado producen el mismo bloque
byte a byte. Marcarlas `#[cfg(test)]` o `pub(crate)` habría roto la compilación de esos dos archivos,
que no puedo tocar.

**Elección:** no cambié la visibilidad de `producir_en_regimen`/`producir` en `zx-post` (siguen
`pub`). En su lugar, verifiqué por `grep` que ningún archivo de `crates/zx-node/**` las nombra ya en
ningún sitio (`regimen.rs` usa exclusivamente `producir_en_regimen_con_firmante`): el nodo es
inalcanzable desde ellas en la práctica, aunque a nivel de tipos zx-post las siga exportando. Si el
director quiere el cierre también a nivel de API pública, hace falta una orden que además reescriba
o mueva esos dos archivos de test (fuera de mi zona) a `#[cfg(test)] mod` dentro del crate.

## 2. Cómo leer la confiscación "del estado de los tres nodos" (V4) sin tocar `zx-p2p`/`zx-cadena`

La orden exige, en V4, verificar `f=1: C=V`, `suelo(C·2/8)` a la coinbase del incluidor y el resto
quemado, "leído del estado de... los tres nodos". Ni el protocolo de red (`zx-p2p`, vedado) expone
una consulta de garantía por clave, ni `resumen_estado` (existente, de `ORDEN-W06d1`) es más que un
`blake3` opaco del estado completo (no se puede leer un valor concreto de él sin romper el
"solo lectura" de `zx-cadena`, vedado, para exponer un método de volcado).

**Elección:** añadí un evento de **diagnóstico** nuevo (no forma parte del esquema mínimo v1 —
`ESQUEMA-REGISTRO-v1.md` §1 bis ya declara que el nodo puede añadir diagnósticos que el analizador
ignora sin error) `garantia_clave_tras_evidencia` (`incident_id`, `clave`, `activo`, `congelado`),
escrito por `admitir_post_interno` (la tubería única de admisión, cubre producción propia, red y
repetición) inmediatamente después de aplicar cualquier bloque que lleve una `EvidenceTx`. Lee
`self.cadena.estado_terminal().garantias`, una lectura que `Cadena` ya expone públicamente
(`estado_terminal()`); no añade ninguna API nueva a `zx-cadena` ni al protocolo de red.

## 3. Filtro de "ventana abierta en el slot del bloque" (decisión 4) necesitó el slot en el mensaje

`MsgProductor::PeticionPadres` (protocolo interno hilo↔bucle, mío desde `ORDEN-W06d1`) no llevaba el
`slot` objetivo: el bucle no podía saber para qué slot se estaban pidiendo los padres, y sin eso no
puede filtrar qué evidencias pendientes tienen la ventana abierta "en el slot del bloque" (decisión
4, literal). Cambié `PeticionPadres` a `PeticionPadres(u64)`. Es un cambio de protocolo interno, no
de wire ni de consenso; no toca ningún archivo fuera de mi zona.

## 4. Detector de doble firma no persiste entre reinicios

Decisión 3 no dice si el detector debe sobrevivir a un reinicio del proceso. El registro durable del
**firmante** (decisión 2) sí lo exige explícitamente (`Registro::abrir` con `slot_actual`); el
detector de doble firma no tiene un requisito equivalente en la orden. Lo dejé **en memoria**
(`crates/zx-node/src/evidencia.rs`, campo `detector` de `Nodo`, reconstruido vacío en cada
`Nodo::arrancar`), pero la llamada a `observar()` desde `admitir_post_interno` corre también en la
ruta de **repetición** (`verificar = false`): como los bloques con `EvidenceTx` ya aplicada siguen en
el almacén y se repiten igual que cualquier otro, y como el propio doble-billete (dos cabeceras PoST
normales, ambas admitidas por el DAG) también se repite, el detector **sí** reconstruye su índice de
identidades vistas a partir de la historia repetida. Lo que **no** sobrevive es una vista que nunca
llegó a producir una segunda cabecera antes del reinicio: si la segunda cabecera llega **después**
de un reinicio, el detector la compara contra lo que acaba de reconstruir de la repetición, así que
sigue funcionando; el caso no cubierto es exactamente el mismo límite que ya tiene el registro del
firmante frente a un reinicio sin repetición completa, y no es nuevo de esta orden.
