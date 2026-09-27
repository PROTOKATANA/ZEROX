# INFORME — ORDEN-W06d10-B

**Ejecutor:** DeepSeek (`deepseek-flash`, esfuerzo `high`). **Zona:** `deepseek/W06d10-B/`.
**Base:** raíz en el commit `5a07027` (incluye W06d10 migrada), verificada con
`sha256sum -c P-ZRX/P-NODO/ENTRADA-W06d10-B.sha256`: **53/53** verde **antes** de editar y **después**
de terminar. **Inicio (orden):** 2026-09-27T23:45+02:00. **Fin:** ver `HORAS.log`.
**Nota de entorno:** `V-ZRX/LINEO.md` leído íntegro antes de escribir código. La orden rige código
Rust; se aplican sus reglas de veracidad, reproducibilidad, presupuesto (8 hilos, 1 h 30 min) y
prohibición de Python.

---

## 1. Resumen

W06d10 hizo que un bloque difundido **demostrablemente inválido** penalizara al par en gossip igual
que en sincronización. La revisión V1 de esa orden encontró que **tres** familias de
`VeredictoFinal::Rechazar` dependen de la **vista local** y por tanto castigaban a pares honestos:
**X1** `ErrorPow::TimestampDemasiadoFuturo` (C-TS-03, reloj local; el propio tipo lo declara **no
permanente**), **X2** `MotivoBloque::ErrLimiteTerminales` (tope **local** de terminales con DAG) y
**X3** fallos **locales** de persistencia/servicio/detector. W06d10-B las pasa a `Ignorar` en las dos
rutas:

1. **Clasificación nueva** `ClasificacionRechazo::VistaLocal` (`rechazo.rs`): `es_legitimo() ==
   false` (fatalidad de un bloque propio **sin cambios**, decisión 2), `es_pendiente() == false`,
   `penaliza_en_red() == false`.
2. **X1**: `clasificar_error_pow` usa `ErrorPow::es_permanente()` (contrato del propio tipo), no una
   lista propia; `TimestampDemasiadoFuturo → VistaLocal`.
3. **X2**: `ErrLimiteTerminales → VistaLocal`; el motivo cacheado X2 y el camino «padre conocido e
   inválido» con motivo X2 también devuelven `Ignorar` (decisión 4, ver §4).
4. **X3**: los errores **locales** que llegan al borde de red (`Otro`/`Almacen`/`Io`) → `Ignorar` +
   evento de diagnóstico `bloque_red_vista_local` con su motivo. Los defectos del candidato que hoy
   eran `ErrorNodo::Otro` (`bits`, `target`, `trabajo`, `peso`) se envuelven como
   `BloquePropioRechazado{Interno}` para que **sigan penalizando** (V2).
5. **Sin cambios de validez**: el bloque sigue sin admitirse mientras no cumpla; `zx-cadena`,
   `zx-consensus` y `zx-p2p` **no** se tocan; `Cargo.lock` sin cambios.

## 2. V0 — base

- `sha256sum -c P-ZRX/P-NODO/ENTRADA-W06d10-B.sha256` en la raíz: **53/53** (antes y después).
- `ws.orig/` es copia de la base y **no se modificó**: `diff -rq` contra la raíz idéntico en
  `Cargo.toml`, `Cargo.lock`, `rust-toolchain.toml`, `ci/`, `crates/`, `testdata/`.
- Suite completa en V4: **891 pasados / 0 fallos / 6 ignorados** (la base de W06d10 daba 883/0/6;
  +8 son los tests nuevos de esta orden).

## 3. Falta de definición informada antes de editar (`PROGRESO.md` §0.1)

**«X2 sin cachear» no es alcanzable dentro del contrato.** X2 nace **dentro** de `Cadena::admitir`
(`zx-cadena/src/cadena.rs:367`, `dag_de_terminal_mut`): `admitir` cachea **todo** rechazo en
`validos`/`motivos` (`cadena.rs:403-406`) y lo devuelve en la siguiente llamada (`cadena.rs:369-378`).
`Cadena` no expone forma de olvidar esa entrada y `zx-cadena` está **vedado**, así que el nodo no
puede evitar que el bloque quede en `motivos`. Se implementó todo lo que sí cabe en la zona:

- **X2 y su reaparición devuelven `Ignorar`** (nunca `Rechazar`), no penalizan y no se reconvierten
  por el motivo cacheado.
- **X1 sí queda sin cachear de verdad**: falla en `validar_cabecera_pow`, antes de que nada se
  inserte (`nodo.rs`), así que al reenviarlo con el reloj al día **se vuelve a juzgar y se admite**
  (V1). X3 tampoco se cachea.
- **Residual declarado**: tras cambiar la vista local, `cadena.admitir` seguiría devolviendo el
  motivo X2 cacheado; para el «sin cachear» completo de X2 haría falta autorizar en `zx-cadena` o
  bien un `Cadena::olvidar(hash)` o bien que `admitir` no cachee `ErrLimiteTerminales`. Propuesta
  registrada en `PROGRESO.md` §0.1; no ejecutada por estar fuera de los archivos permitidos.

## 4. V1 — caminos a `Rechazar` y hallazgo de la decisión 4

Tabla completa en `PROGRESO.md` §0.2. Resumen: **V** (demostrable) siguen penalizando; **X1/X2/X3**
pasan a `Ignorar`.

**Hallazgo propio (decisión 4), tratado igual:** el camino **«padre conocido e inválido»**
(`nodo.rs`, ramas PoW y PoST) dependía de la vista local cuando el motivo cacheado del padre es X2:
un hijo válido se rechazaba y penalizaba porque **este** nodo había ignorado al padre por el tope
local de terminales. Ahora, si el motivo del padre no penaliza, el hijo se **`Ignorar`** (sin
desconexión ni puntuación), con traza `bloque_red_vista_local`. No estaba en la tabla de W06d10.

También se revisó `ErrorPow` (solo `TimestampDemasiadoFuturo` es no permanente, según el propio
`es_permanente()`) y `MotivoCabeceraInvalida`/`MotivoPotInvalido` (sin variantes dependientes del
reloj o del conjunto local de terminales; `MotivoCabeceraPendiente` ya era `Ignorar`). No se
encontró otra familia X.

## 5. Cambios (solo archivos permitidos)

| Archivo | Cambio |
|---|---|
| `crates/zx-node/src/rechazo.rs` | Variante `VistaLocal` (`es_vista_local`/`penaliza_en_red`); `ErrLimiteTerminales → VistaLocal`; `clasificar_error_pow` con `ErrorPow::es_permanente`; tests X1/X2. |
| `crates/zx-node/src/nodo.rs` | X1 en `validar_cabecera_pow`; motivo cacheado X1/X2/X3 y padre-inválido-X2 → `Ignorar` en gossip y sync; P3c/P3d/Po6 (`bits`/`target`/`trabajo`/`peso`) → `BloquePropioRechazado{Interno}`; `error_atribuible_al_candidato`; evento `bloque_red_vista_local`; costuras de test `fallo_local_simulado` y `reloj_local_simulado` (`#[cfg(test)]`); tests V1/V2. |
| `crates/zx-node/tests/w06d10b_x2_limite_terminales.rs` | Test nuevo (X2): el noveno terminal produce `ErrLimiteTerminales` real y el nodo lo clasifica `VistaLocal`. |

`crates/zx-node/src/error.rs`, `red/sync.rs` y `red/manejador.rs` **no** necesitaron cambios (el
veredicto `Ignorar` basta para que `zx-p2p` y la ruta de sincronización no penalicen). `Cargo.lock`
sin cambios.

## 6. V1/V2 — tests

- `rechazo.rs` (unit): `x1_ftl_es_vista_local_y_no_penaliza`,
  `x1_fallo_permanente_sigue_penalizando`, `x2_limite_terminales_es_vista_local_y_no_penaliza`, más
  los existentes.
- `nodo::pruebas_w06d10b` (unit):
  - **X1**, ambas rutas: timestamp futuro → `Ignorar`, sin caché (`motivo`/`headers_pow`), sin
    `par_penalizado`; con el reloj (inyectado) al día, **el mismo bloque** se admite.
  - **X3**, ambas rutas: fallo local inyectado → `Ignorar`, evento `bloque_red_vista_local` con el
    motivo, sin `par_penalizado`; sin el fallo el mismo bloque se admite (no quedó cacheado).
  - **V2** (regresión): coinbase que paga de más (`ErrEmision`) → `Rechazar` en gossip y en
    sincronización, también con el motivo ya cacheado.
  - Mapeo `error_atribuible_al_candidato`: `Interno`/`Legitimo` sí; `VistaLocal`/`Pendiente`/
    `ImposibleSinPenalizar`/`Otro` no.
- `tests/w06d10b_x2_limite_terminales.rs` (integración): noveno terminal con menos trabajo → el
  motivo real es `ErrLimiteTerminales` y `clasificar_motivo_bloque` lo da `VistaLocal` sin penalizar.
- **Verde**: `cargo test -p zx-node --lib` (todos) y el test de integración nuevo.

## 7. V3 — procesos reales

Guiones de W06d10 copiados y adaptados a esta zona (`scripts/{lib_red.sh,verif.sh,verificar_estado_w07d.sh,r4_e7_rep.sh,r150.sh}`),
`SR_dev = 13043817825332783104`, binarios release propios.

| Prueba | Rep | Semilla | Resultado | Detalle |
|---|---:|---:|---|---|
| E-7 (`r4_e7_rep.sh`, puertos 51000) | 1 | 101 | **SUPERADO** | A: 4 `bloque_red_rechazado`, **4 `par_penalizado`** (4 `PeerId` del adversario), 0 ajenos, 0 desconexiones de B/C, convergencia W07d (`resumen_estado` y `compendio_bloques`). |
| R150 (`r150.sh`, puertos 52000) | 1 | 101 | **SUPERADO** | A/B/C al slot 150, **0 `par_penalizado`** entre honestos, 0 `fallo_productor`, 0 pánicos, convergencia W07d. |

Artefactos en `run/R4-E7-1/` y `run/R150-1/` (`EJECUCION.txt`, `RESULTADO.txt`, registros,
`e7-rechazos.txt`, `penalizados-a.txt`); logs en `logs/v3-e7-seed101.log`,
`logs/v3-r150-seed101.log`.

## 8. V4 — fmt, clippy, suite, guardianes, T01/T04

- `cargo fmt --all -- --check`: **verde**.
- `cargo clippy --workspace --all-targets --all-features --locked -- -D warnings`: **verde**
  (`logs/v4-clippy.log`).
- `cargo test --workspace --all-features --locked`: **85 binarios, 891 pasados, 0 fallos, 6
  ignorados** (`logs/v4-test.log`).
- Guardianes: `ci/dependencias-exactas.sh` (24 exactas), `ci/firmante-obligatorio.sh` y
  `ci/frontera-crates.sh` (fronteras) en **verde**.
- **T01/T04** (`diferencial_t01{, _negativos}`, `diferencial_t04`): **verde** dentro de la suite.
- `Cargo.lock` sin cambios (`sha256sum -c` de la entrada 53/53 tras terminar).

## 9. Límites y hallazgos

- **X2 no cacheado** (residual de §3): el bloque sigue en `cadena.motivos`; se garantiza que no
  penaliza ni se reconvierte en `Rechazar`, no que se reevalúe tras cambiar la vista local. Requiere
  autorización sobre `zx-cadena`.
- **Costuras de test**: `fallo_local_simulado` y `reloj_local_simulado` son `#[cfg(test)]`; el
  binario de producción no las contiene. El reloj real de la máquina no se usa en V1.
- La traza `bloque_red_vista_local` es un evento de diagnóstico del §1 bis (el analizador ignora
  tipos desconocidos); X3 queda visible con su motivo, como pide la decisión 2.
- No se modificó la fatalidad de ningún fallo local para el nodo (decisión 2): `VistaLocal` no es
  `es_legitimo()`, y los `?` de persistencia/servicio siguen propagando el `Err` por las mismas
  rutas.

## 10. Reproducción

```bash
Z=/home/katana/zeo/ZEROX/deepseek/W06d10-B
cd "$Z/ws"
cargo fmt --all -- --check
cargo clippy --workspace --all-targets --all-features --locked -- -D warnings
cargo test --workspace --all-features --locked
bash ci/dependencias-exactas.sh && bash ci/firmante-obligatorio.sh && bash ci/frontera-crates.sh
cargo build --release -p zx-node --all-features --locked
bash "$Z/scripts/r4_e7_rep.sh" 1 51000 101 13043817825332783104
bash "$Z/scripts/r150.sh" 1 52000 101 13043817825332783104
```

Migración: `cambios.patch` (`ws.orig/crates` → `ws/crates`) y `MIGRACION.sha256` (3 archivos
tocados) para el director; `ws.orig/` es la base intacta.
