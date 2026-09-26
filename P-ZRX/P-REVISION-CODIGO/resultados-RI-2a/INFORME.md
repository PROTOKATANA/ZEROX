# RI-2a — Revisión independiente: `crates/zx-cadena/` y `fusion.rs`

**Revisor:** RI-2a (subagente Claude Sonnet). **Fecha:** 2026-09-26. **Commit revisado:**
`c715c4b18167c4ad3de6ffcf3008570fc3797ee9` (posterior al mínimo exigido `4042821`).
**Zona de trabajo:** `/home/katana/zeo/ZEROX/deepseek/RI-2a/ws` (copia de `Cargo.toml`, `Cargo.lock`,
`rust-toolchain.toml`, `crates/`, `testdata/`, enlace `PDF`), `CARGO_HOME`/`CARGO_TARGET_DIR` en la
zona, `--locked`, `-j 4`, `RUST_TEST_THREADS=4`.

## Tabla de hallazgos

| # | Gravedad | Estado | Archivo:línea | Descripción (una línea) |
|---|---|---|---|---|
| 1 | **Alta** | **CONFIRMADO** | `crates/zx-cadena/src/cadena.rs:207-235` (`Cadena::admitir`) | Un bloque sometido antes de que su padre exista queda cacheado como `ErrSinPadre` **para siempre**: si el padre llega después y es válido, `admitir` no lo reevalúa (devuelve el error cacheado por hash), sin ningún mecanismo de invalidación o reintento dentro de `zx-cadena`. |
| 2 | Baja | PLAUSIBLE | `crates/zx-cadena/src/cadena.rs:987-999` (`mapear_error_dag`) | El `_ => MotivoBloque::ErrSinPadre` final puede enmascarar errores internos genuinos de `zx-dag` (p. ej. `GhostdagIncoherente`, corrupción de estado) bajo la etiqueta de "padre ausente", dificultando distinguir un rechazo legítimo de un bug interno. |
| 3 | Baja (nota, no defecto activo) | — | `crates/zx-cadena/src/cadena.rs:952-972` (`activo_promovido`) vs. `crates/zx-consensus/src/transicion/estado.rs:276-333` (`Aplicador::promover`) | Duplicación de la lógica de madurez de garantía (misma condición `madura_en_slot ≤ slot`) en dos sitios independientes; hoy son equivalentes (verificado), pero un cambio futuro en uno sin el otro rompería silenciosamente `RD-9`. |

No se encontraron discrepancias de conservación (I-1), de undo (I-2/IE-4), de determinismo por
orden de llegada en el *coloreado* GHOSTDAG (IE-3), ni divergencias contra el oráculo T04-D: el
arnés `diferencial_t04.rs` (914 casos, incluidos ~300 con `ErrMergeDepth`, es decir `RD-5` **sí**
está bien cubierto por vectores, al contrario de lo que sugería a primera vista que las
propiedades de `proptest` usan `f_slots: None`) pasa con 0 discrepancias en mi copia.

## Detalle

### 1. `Cadena::admitir` cachea huérfanos como inválidos permanentes (ALTA, CONFIRMADO)

`admitir` (cadena.rs:207) mira primero `self.validos.get(&hash)`: si el hash ya se procesó, **nunca
reprocesa**, devuelve el resultado guardado. Esto es correcto para bloques ya *válidos* o
*definitivamente* inválidos (forma incorrecta, garantía insuficiente, etc.), pero el mismo caché se
usa también para `ErrSinPadre` cuando el padre simplemente **todavía no ha llegado**. El contrato
(`R-15`, `CONTRATO-ESTADO-DAG-v0.md` y el propio docstring de `admitir_post`/`chequear_forma`)
delega la retención de huérfanos al **nodo** («un nodo en línea lo retiene como huérfano hasta que
llega el padre»), pero `zx-cadena` no ofrece ninguna defensa en profundidad si el llamante (fuera de
mi alcance: `zx-node`, revisado por RI-2b) llega a invocar `admitir` sobre un bloque antes de que su
padre esté disponible: ese hash queda marcado inválido para siempre en esta instancia de `Cadena`,
aunque el padre llegue después y sea válido.

Esto es exactamente la clase de fallo que pide `ORDEN-RI-2` («estado que diverge entre nodos según
el orden de llegada»): si dos nodos honestos reciben los mismos bloques en órdenes distintos, y en
alguno de ellos el bloque hijo llega a `zx-cadena` una fracción de segundo antes que su padre (una
condición de carrera de red, no necesariamente un bug de `zx-node`), ese nodo queda permanentemente
en un estado de DAG distinto al de sus pares para ese hash, sin recuperación salvo reiniciar la
`Cadena` desde cero. El *helper* `resolver()` (cadena.rs:246, usado solo en tests) sí resuelve
huérfanos correctamente reintentando hasta el punto fijo, lo que demuestra que la propia zona sabe
cómo hacerlo bien; pero `resolver()` no forma parte de la API que usa producción (grep confirmado:
solo lo llama `tests/propiedades.rs`), así que esa protección no está disponible fuera de tests.

**Reproducción (en mi copia, `deepseek/RI-2a/ws`):**

Añadí este test a `crates/zx-cadena/tests/padres_e_identidad.rs`:

```rust
#[test]
fn ri2a_huerfano_cacheado_no_se_reintenta_al_llegar_el_padre() {
    let mut cadena = cadena_con_terminal(15);
    let terminal = hash(1);
    let p = post(50, vec![terminal], 1, productor(50), ticket(50, 1));
    let p_hash = p.hash();
    let b = post(60, vec![p_hash], 2, productor(60), ticket(60, 2)); // hijo de p, sometido antes

    let r1 = cadena.admitir(b.clone());
    assert_eq!(r1, Err(MotivoBloque::ErrSinPadre)); // p aún no existe: correcto

    let rp = cadena.admitir(p);
    assert!(rp.is_ok()); // p llega y es válido

    let r2 = cadena.admitir(b); // mismo hash que antes
    assert!(r2.is_ok(), "BUG confirmado: ... {r2:?}");
}
```

Comando y salida literal:

```
$ cd /home/katana/zeo/ZEROX/deepseek/RI-2a/ws && \
  CARGO_HOME=/home/katana/zeo/ZEROX/deepseek/RI-2a/.cargo-home \
  CARGO_TARGET_DIR=/home/katana/zeo/ZEROX/deepseek/RI-2a/target \
  RUST_TEST_THREADS=4 cargo test --locked -j 4 -p zx-cadena --test padres_e_identidad

running 4 tests
thread 'ri2a_huerfano_cacheado_no_se_reintenta_al_llegar_el_padre' panicked at
crates/zx-cadena/tests/padres_e_identidad.rs:276:5:
BUG confirmado: B quedó permanentemente ErrSinPadre aunque P ya es válido: Err(ErrSinPadre)
test ri2a_huerfano_cacheado_no_se_reintenta_al_llegar_el_padre ... FAILED
test identidades_reales_distintas_no_colapsan_en_ocho_bytes ... ok
test con_max_padres_tres_el_cuarto_padre_se_rechaza ... ok
test quince_padres_se_admiten_y_dieciseis_se_rechazan ... ok
test result: FAILED. 3 passed; 1 failed; 0 ignored; 0 measured; 0 filtered out
```

**Alcance de la responsabilidad:** el defecto está en el contrato/API de `zx-cadena` (falta de
defensa en profundidad), no necesariamente en `zx-node` — no revisé `zx-node` (fuera de mi alcance,
RI-2b). Recomiendo coordinar con RI-2b: si `zx-node` **garantiza** con pruebas que nunca llama a
`Cadena::admitir` antes de que el padre esté admitido (buffer de huérfanos verificado), el riesgo
queda mitigado en la práctica; si no hay esa prueba cruzada, este hallazgo es explotable por una
simple condición de carrera de red, no requiere un adversario.

### 2. `mapear_error_dag`: catch-all que puede enmascarar corrupción interna (BAJA, PLAUSIBLE)

```rust
fn mapear_error_dag(error: &ErrorDag) -> MotivoBloque {
    match error {
        ErrorDag::DemasiadosPadresDag { .. } | ErrorDag::BloqueDesconocido { .. } => MotivoBloque::ErrSinPadre,
        ErrorDag::MergesetExcedeLimite { .. } => MotivoBloque::ErrMergeset,
        ErrorDag::BilleteDuplicadoU2 { .. } => MotivoBloque::ErrU2,
        ErrorDag::SaltoMayorSmax { .. } | ErrorDag::SlotDePadrePosterior { .. } => MotivoBloque::ErrSlot,
        _ => MotivoBloque::ErrSinPadre,
    }
}
```

No leí el listado completo de variantes de `ErrorDag` en `zx-dag` (fuera de mi alcance estricto),
pero por nombre existe al menos `GhostdagIncoherente` (visto en `ghostdag.rs`, usado para
inconsistencias internas del almacén, no para rechazos de bloques ajenos). Si `anadir_sintetico`
alguna vez devuelve esa variante para un bloque legítimo (por ejemplo, por un bug de índices), el
código actual la reporta igual que "no tiene padre", indistinguible en los tests o en logs de un
rechazo normal. No until encontré un caso concreto que lo dispare (por eso PLAUSIBLE, no
CONFIRMADO): es una observación de robustez/observabilidad, no un bug de consenso demostrado.

### 3. Duplicación de la lógica de madurez de garantía (nota, sin discrepancia activa)

`cadena.rs::activo_promovido` reimplementa, de forma **read-only**, exactamente la condición que
`Aplicador::promover` aplica de forma mutable (`estado.rs:276`): `pendiente.madura_en_slot.is_some_and(|s| s <= slot)`.
Confirmé por lectura que ambas usan el mismo campo y el mismo operador de comparación, y que todos
los `Pendiente` creados por depósitos en fase PoW también fijan `madura_en_slot` (no solo
`madura_en_altura`, ver `aplicar.rs:446-462`), así que hoy no hay divergencia: la garantía
"promovida" que ve `comprobar_garantia` (antes de `aplicar_fusion`) coincide con la que produciría
`ap.promover` dentro de la propia fusión. Lo señalo solo porque es lógica de negocio duplicada en
dos crates sin un punto único de verdad; un cambio futuro en una regla de madurez (`RD-9`/`TRN-07`)
tendría que actualizarse en los dos sitios a la vez.

## Verificaciones que NO dieron hallazgo (con evidencia)

- **RI-1a #1** (`peso_sufijo` no se suma en modo fusión, solo lo suma quien aplica bloques de
  cadena): confirmado por lectura — `fusion.rs` no toca `peso_sufijo`; `cadena.rs::admitir_post` y
  `cadena.rs::aplicar_cadena` son los únicos que lo incrementan, y solo por el peso del bloque que
  se está aplicando sobre su propio `sp`, nunca por bloques del *mergeset*.
- **RI-1a #2** (`aplicar_fusion` rechaza un bloque PoW): confirmado — `fusion.rs:60-63`.
- **RD-2/RD-7/RD-10** (coinbase opcional, orden tx-antes-que-coinbase, garantía no se
  recomprueba al fusionar): confirmado por lectura de `fusion_post` (fusion.rs:153-268).
- **Transición de fase PoW→PoST** (`ap.estado.terminal` propagado correctamente a `Estado(T)`):
  confirmado — `aplicar_pow` (aplicar.rs:766-769) fija `estado.terminal`/`altura_terminal` en el
  mismo `Estado` que `cadena.rs::admitir_pow` guarda como `self.estado_t`, así que `fusion_post`
  encuentra el terminal correcto al procesar el bloque de transición.
- **`RD-5` / `ErrMergeDepth` sin cobertura**: descartado tras revisar
  `testdata/estado-dag-v0.3/vectores-estado-dag-v0.3.txt` — 386 casos con `F_slots` finito y
  decenas de `RES ... res=ErrMergeDepth`; sí está cubierto por el arnés diferencial (aunque no por
  las propiedades de `proptest`, que fijan `f_slots: None`).
- **Determinismo por orden de llegada dentro del coloreado GHOSTDAG** (una vez que los padres de un
  bloque ya están admitidos): el algoritmo colorea cada bloque solo a partir de su propio pasado ya
  fijado; no encontré dependencia de qué bloques *hermanos* no relacionados se hayan añadido antes o
  después. `tests/propiedades.rs::ie3` (proptest, permutación topológica) lo ejercita y pasa.
- Ejecución completa de la suite `zx-cadena` en mi copia (incluida `diferencial_t04` con 914 casos):
  **0 fallos** salvo el test que yo añadí para el hallazgo 1.

```
$ cargo test --locked -j 4 -p zx-cadena   # (con CARGO_HOME/CARGO_TARGET_DIR en la zona)
contexto_dag: 2 passed
diferencial_t04: 1 passed (914 casos internos, 131s)
padres_e_identidad: 3 passed, 1 failed (el mío, hallazgo 1)
propiedades: (incluido en la corrida; sin fallos)
```

## Leído entero

- `crates/zx-cadena/src/cadena.rs` (1000 líneas)
- `crates/zx-cadena/src/bloque.rs`
- `crates/zx-cadena/src/error.rs`
- `crates/zx-cadena/src/lib.rs`
- `crates/zx-consensus/src/transicion/fusion.rs` (268 líneas)
- `P-ZRX/P-DAG/CONTRATO-ESTADO-DAG-v0.md`
- `P-ZRX/P-TRANSICION/CONTRATO-v0.md`
- `P-ZRX/P-FORMATO/FORMATO-v0.md`
- `P-ZRX/P-REVISION-CODIGO/ORDEN-RI-2.md`, `ORDEN-RI-1.md`

## Muestreado (no leído íntegro)

- `crates/zx-cadena/tests/padres_e_identidad.rs` (leído casi entero, usado como base del repro)
- `crates/zx-cadena/tests/propiedades.rs` (cabecera, definición de parámetros, casos IE-1…IE-4)
- `crates/zx-cadena/tests/contexto_dag.rs` (cabecera y objetivo del test)
- `crates/zx-cadena/tests/diferencial_t04.rs` (cabecera, parseo de `PARAM`/`F_slots`, no el arnés
  completo de comparación línea a línea)
- `crates/zx-consensus/src/transicion/estado.rs` (secciones `promover`, `acreditar_pendiente`,
  `acreditar_credito`, `gastable_en`, `Estado::inicial`, `deshacer`)
- `crates/zx-consensus/src/transicion/aplicar.rs` (secciones `aplicar_pow`, `aplicar_post` estricto,
  `TipoGarantia::Deposito/Retiro`, `es_terminal_condiciones`, `phi`; no el fichero completo — no
  reproduje aquí ningún hallazgo porque está fuera de mi alcance salvo por comparación con
  `fusion.rs`)
- `crates/zx-dag/src/ghostdag.rs` (definición de `mergeset`, `colorear_kernel`/`colorear_referencia`,
  `orden_mergeset`; no todo el algoritmo GHOSTDAG, que es de `zx-dag`, fuera de mi alcance)
- `testdata/estado-dag-v0.3/vectores-estado-dag-v0.3.txt` (solo `grep` de `PARAM`/`RES`, no leído
  como texto corrido — 68 000+ líneas)
- `V-ZRX/LINEO.md` (cabecera y la sección de perfil de máquina/hilos; el resto es método de
  auditorías Julia/CUDA, no aplicable a esta revisión de Rust)

## Nota de alcance y tiempo

Sin Python, sin credenciales, sin subagentes. Compilación y tests con `CARGO_HOME`/
`CARGO_TARGET_DIR` en `/home/katana/zeo/ZEROX/deepseek/RI-2a/`, `--locked`, `-j 4`,
`RUST_TEST_THREADS=4`. Todos los procesos de `cargo` lanzados por mí terminaron antes de escribir
este informe (confirmado con `cargo test` en primer plano/segundo plano, ambos con código de salida
observado).
