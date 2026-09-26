# PROGRESO — ORDEN-W06a-C

Ejecutor: DeepSeek Harness, modelo `deepseek-flash`, esfuerzo `high`. Bitácora de decisiones y faltas
de definición, registradas **antes** de editar, con la lectura más conservadora.

## Lectura previa

`ORDEN-W06a-C.md` completa, `V-ZRX/LINEO.md` completa, `REVISION-W06d1.md` y `REVISION-W06a-B.md`,
`PERFIL-DEV-v0.md` §4, y el código migrado que toca la orden: `zx-cadena`
(`src/{bloque.rs,cadena.rs,error.rs,lib.rs}`, `tests/{propiedades.rs,contexto_dag.rs,diferencial_t04.rs}`),
`zx-node` (`src/{nodo.rs,padres.rs,perfil.rs,identidad.rs,lib.rs}`), `zx-dag`
(`src/{ghostdag.rs,identidad.rs}`) y `zx-core/src/preimage/dag.rs` (`PadresDag`, `MAX_PADRES = 15`).

## Falta de definición detectada e informada ANTES de editar

1. **Colisión de 8 bytes no construible.** La orden pide «dos bloques cuyas identidades truncadas a
   8 bytes coincidirían pero las reales difieren (U2)». El truncamiento que hacía `zx-node` era de
   los 8 primeros bytes de `huella()` (SHA3-256). Encontrar una colisión real de ese prefijo exige
   ~2³² hashes (birthday) y no cabe en un test. **Lectura adoptada:** se fija la propiedad de tipo
   que el `u64` rompía por construcción con dos `IdentidadTicket` que comparten los **mismos 8
   primeros bytes de su codificación canónica** (`bytes_canonicos()[..8]`, la clave pública) y
   difieren en el `slot`: cualquier proyección a 8 bytes los confundiría, la tupla real no; U2 los
   separa y rechaza el repetido. Queda declarado en el comentario del test.
2. **Alcance de la copia.** La orden pide copiar «solo lo necesario para compilar y probar, no los
   documentos». **Lectura (precedente W06a-B):** `Cargo.toml`, `Cargo.lock`, `rust-toolchain.toml`,
   `crates/`, `ci/`, `testdata/`, `.github/` y el enlace `ws/PDF`; ni `P-ZRX/`, ni `V-ZRX/`, ni
   `deepseek/`, ni `.git/`, ni `AUTO-ZRX.md`. `PDF` excluido de `cambios.patch` y `MIGRACION.sha256`.
3. **V0 no fue verde a la primera.** `logs/V0.log` (primera corrida conjunta W06d1+W06a-B) falló en
   `zx-node/tests/reinicio.rs` V5: «ronda régimen 4: no se vieron 4 bloques producidos en 30 s».
   El reintento aislado del mismo test pasó (428,69 s) y la suite completa `V0b` volvió a dar
   **694 pasan / 0 fallan / 2 ignorados**, idéntico a W06d1. En W06d1 ya había pasado lo mismo
   (`logs/V3-despues.log` falló y `logs/V3-despues2.log` pasó con 422,97 s): es un *flake* de
   temporización del test en `debug`, no una rotura de la combinación. Se conserva `logs/V0.log`
   (la primera corrida, la que manda la orden) **y** `logs/V0b.log` (la verde). Se **paró** para
   verificar; se siguió solo con la base verde confirmada. Decisión del director, si procede:
   aislar ese test o subir su presupuesto de 30 s.
4. **`mergeset_limite` no es parte de la orden.** `PERFIL-DEV-v0.md` §4 declara 15 padres, pero no
   fija tope de mergeset; `zx-cadena` mantiene el del oráculo (180) en `inicializar_dag` y el perfil
   de `zx-node` declara `u32::MAX` en `parametros_ghostdag_dev` (no consumido por `Cadena`). La orden
   solo pide parametrizar `max_padres`; **no se toca** el mergeset para no ampliar el alcance.
5. **`de_fixture` en los tests de `zx-dag`.** La orden dice que `de_fixture` queda «solo para el
   arnés diferencial». Se interpreta referido a `BloqueCadena::Post` y a la ruta de producción: los
   tests de `zx-dag` (`ghostdag_oraculo`, `ghostdag_rust`, `ghostdag_prop`) siguen usando
   `IdentidadGhostdag::de_fixture` sobre `BloqueGhostdag` porque son oráculos sintéticos, no la
   puerta de producción; no se tocan (fuera del alcance de la orden).

## Decisiones del ejecutor (lectura más conservadora)

1. **`Cadena::nueva(params, k, cbid, max_padres)`**: `max_padres` es `u8`, sin valor por defecto.
   Se guarda en `Cadena` y se pasa a `ParametrosGhostdag` en `inicializar_dag`. El nodo pasa
   `perfil::ghostdag_max_padres()` (15); el arnés de T04 declara `MAX_PADRES_ARNES = 3`.
2. **`BloquePost.identidad: IdentidadGhostdag`** (antes `u64`). `DatosDag.identidad` y
   `bloque_ghostdag` propagan el tipo real. `zx-node` deriva
   `IdentidadGhostdag::Billete(identidad_de_cabecera(&bloque.cabecera))` y **se elimina**
   `zx-node/src/identidad.rs` (el truncamiento a `huella()[..8]`); `lib.rs` deja de declarar el
   módulo. El arnés `diferencial_t04` pasa `IdentidadGhostdag::de_fixture(b.ident)`.
3. **Tests nuevos:** `zx-cadena/tests/padres_e_identidad.rs` (15 padres admitidos / 16 rechazados;
   con `max_padres = 3`, el cuarto se rechaza; dos billetes distintos con el mismo prefijo de 8
   bytes no colapsan y el repetido da `ErrU2`) y `zx-node/tests/padres_maximos.rs` (con 16 puntas
   válidas, `padres_de_regimen` selecciona exactamente 15). `propiedades.rs` y `contexto_dag.rs`
   pasan a identidades reales; `propiedades.rs` usa `max_padres = 15` (su generador produce ≤ 3).
4. **`MAX_PADRES_CADENA` del nodo** pasa a `crate::perfil::MAX_PADRES as usize` (15), con
   `ghostdag_max_padres()` en `perfil.rs` para el `k`/padres del perfil.
5. **Se conserva el test previo `zx_node::identidad::tests::es_determinista_y_nunca_cero`.** La
   primera edición borró `zx-node/src/identidad.rs` (era el truncamiento), pero eso eliminaba un
   test previo y la orden exige que V3 mantenga «todo lo previo con su nombre». El módulo se
   conserva como **puerta única** que devuelve ya `IdentidadGhostdag::Billete(identidad_de_cabecera)`
   (el test comprueba que nunca es `SinBillete`/`Sintetica`); `nodo.rs` lo usa y `lib.rs` recupera
   `pub mod identidad;`.

## Secuencia de trabajo

1. **Montaje.** Verificación de `ENTRADA-W06a-C.sha256` (5/5 OK), copia del workspace a `ws.orig/` y
   `ws/`, `env.sh`, `CARGO_HOME`/`target` dentro de la zona (reutilizados de W06d1).
2. **V0.** `cargo test --workspace --all-features --locked` sin cambios: fallo por *flake* de V5
   (ronda régimen 4); reintento aislado verde; `V0b` verde **694/0/2**. Ver falta de definición 3.
3. **Edición** de `zx-cadena` (parámetro y tipo), `zx-node` (identidad real, tope 15) y tests.
4. **Verificación** V1–V6 y entregables.

## Resultados

- **V1** `cargo fmt --all -- --check`: exit 0 (`logs/V1-fmt.log`).
- **V2** `cargo clippy --workspace --all-targets --all-features --locked -- -D warnings`: exit 0
  (`logs/V2-clippy.log`).
- **V4** `diferencial_t04` v0.3: 914 casos, **0 discrepancias**; cobertura idéntica a
  `cobertura-v0.3.txt` (`logs/V4-diferencial-t04.log`).
- **V3** `cargo test --workspace --all-features --locked`: ver `logs/V3-test.log` (previos 694 + los
  4 nuevos: 3 de `padres_e_identidad` + 1 de `padres_maximos`).
- **V6** `ci/dependencias-exactas.sh`, `ci/frontera-crates.sh`; `Cargo.lock` **byte a byte idéntico**
  (`logs/V6-guardianes.log`, `logs/lock-subconjunto.txt`).
- **Entregables:** `cambios.patch` (11 rutas: 9 modificadas + 2 nuevas),
  `MIGRACION.sha256` sobre `ws/` final, `logs/`, `INFORME.md`, `PROGRESO.md`, `HORAS.log`.

**Veredicto: ver `INFORME.md`.** No se escribe nada fuera de
`/home/katana/zeo/ZEROX/deepseek/W06aC/`; sin commit ni push; sin Python; sin dependencias nuevas.
