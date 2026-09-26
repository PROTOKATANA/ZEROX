# INFORME.md — ORDEN-W06a-C

**`zx-cadena` sin atajos del oráculo en la ruta de producción.** Sesión: DeepSeek Harness, modelo
`deepseek-flash`, esfuerzo `high`. Fecha: 2026-09-26, 09:51–12:00 +02:00. Zona única:
`/home/katana/zeo/ZEROX/deepseek/W06aC/`. Sin Python, sin dependencias Rust nuevas, sin `unsafe`, sin
commit ni push, nada escrito fuera de la zona. Base: workspace de la raíz copiado a `ws.orig/` y `ws/`
(`Cargo.toml`, `Cargo.lock`, `rust-toolchain.toml`, `crates/`, `ci/`, `testdata/`, `.github/` y el
enlace `PDF`), sin los documentos.

**Pregunta falsable:** «Con el máximo de padres como parámetro (15 en la red dev, 3 en el
diferencial) y la identidad real de `C-GD-07`, el diferencial contra T04 v0.3 sigue en 0
discrepancias con su cobertura, y `zx-node` produce y verifica bloques con más de 3 padres e
identidades reales.»
**Veredicto: NO REFUTADA — SUPERADO**, con **un hallazgo de temporización** (§4) y **una limitación
declarada** en el test de colisión a 8 bytes (§5).

## 1. Veredicto por paso

| Paso | Comando (desde `ws/`, entorno §6) | Veredicto |
|---|---|---|
| V0 | `cargo test --workspace --all-features --locked` sin cambios | **FALLA** (`logs/V0.log`): `reinicio.rs` V5, ronda régimen 4 (30 s). Ver §4 |
| V0b | misma suite, repetida | **OK** (exit 0; **694 pasan, 0 fallan, 2 ignorados**; `logs/V0b.log`) |
| V1 | `cargo fmt --all -- --check` | **OK** (exit 0; `logs/V1-fmt.log`) |
| V2 | `cargo clippy --workspace --all-targets --all-features --locked -- -D warnings` | **OK** (exit 0; `logs/V2-clippy.log`) |
| V3 | `cargo test --workspace --all-features --locked` | **OK** (exit 0; **698 pasan, 0 fallan, 2 ignorados**; los 694 previos con su nombre + 4 nuevos; `logs/V3-test.log`) |
| V4 | `diferencial_t04` (v0.3, 914 casos) | **OK** (0 discrepancias; cobertura idéntica; `logs/V4-diferencial-t04.log`) |
| V6 | `ci/dependencias-exactas.sh`, `ci/frontera-crates.sh`; lock | **OK** (23 dependencias exactas; 9 fronteras; `Cargo.lock` byte a byte idéntico; `logs/V6-guardianes.log`, `logs/lock-subconjunto.txt`) |
| Entrada | `sha256sum -c P-ZRX/P-NODO/ENTRADA-W06a-C.sha256` al inicio y al final | **OK** en ambos (5/5; `logs/entrada-inicio.log`, `logs/entrada-final.log`) |

## 2. Qué se hizo

1. **`max_padres` como parámetro de construcción.** `Cadena::nueva(params, k, cbid, max_padres)`
   (`u8`, sin valor por defecto oculto) guarda el tope y lo pasa a `ParametrosGhostdag` en
   `inicializar_dag`. Desaparece la constante `MAX_PADRES_ORACULO = 3`. El nodo usa
   `perfil::ghostdag_max_padres()` (15, `PERFIL-DEV-v0.md` §4); el arnés de T04 declara
   `MAX_PADRES_ARNES = 3` (el límite de su generador).
2. **Identidad real de `C-GD-07`.** `BloquePost::identidad` pasa de `u64` a `IdentidadGhostdag`;
   `DatosDag::identidad` y `bloque_ghostdag` propagan el tipo. `zx-node` deriva
   `IdentidadGhostdag::Billete(identidad_de_cabecera(cabecera))` (módulo `zx-node/src/identidad.rs`,
   puerta única, **sin truncar**) y `diferencial_t04` pasa `IdentidadGhostdag::de_fixture(b.ident)`.
   El nodo ya no proyecta la huella a 8 bytes.
3. **Tests.** `zx-cadena/tests/padres_e_identidad.rs`: bloque de 15 padres admitido y de 16
   rechazado con `max_padres = 15`; con 3, el cuarto padre se rechaza; dos billetes distintos que
   una proyección de 8 bytes confundiría no colapsan en U2 y el repetido da `ErrU2`.
   `zx-node/tests/padres_maximos.rs`: con 16 puntas válidas, `padres_de_regimen` selecciona
   exactamente 15. `propiedades.rs` y `contexto_dag.rs` pasan a identidades reales y `max_padres`
   explícito. El test previo `zx_node::identidad::tests::es_determinista_y_nunca_cero` se conserva
   (adaptado a la identidad real), de modo que no desaparece ningún nombre previo.

## 3. Pregunta falsable, punto por punto

- **Diferencial T04 v0.3, 0 discrepancias:** 914/914 (900 aleatorios + 14 dirigidos), con la
  cobertura idéntica a `cobertura-v0.3.txt`.
- **15 padres en la red dev:** `max_padres = 15` admite el bloque de 15 y rechaza el de 16;
  `padres_de_regimen` del nodo selecciona 15 de 16 puntas.
- **Identidades reales:** `BloquePost::identidad` es la tupla literal; el nodo la deriva de la
  cabecera y no la trunca.
- **`zx-node` produce y verifica** con la integración de W06d1 (V4 de W06d1: ≥ 30 bloques PoST
  admitidos, 0 rechazados) y reinicia sin corrupción (V5), todo re-ejecutado en V3.

## 4. Hallazgo: V0 no fue verde a la primera (flake de temporización)

La **primera corrida conjunta W06d1+W06a-B** que pide `REVISION-W06d1.md` (reserva 4) falló en
`crates/zx-node/tests/reinicio.rs` V5: «ronda régimen 4: no se vieron 4 bloques producidos en 30 s»
(`logs/V0.log`). Evidencia de que es un *flake* del test en `debug`, no una rotura de la
combinación:

- el reintento **aislado** del mismo test pasó (428,69 s; `logs/V0-reintento-v5.log`);
- la suite completa repetida (`V0b`) dio **694/0/2**, idéntica a W06d1 (`logs/V0b.log`);
- en la propia W06d1, `logs/V3-despues.log` ya había fallado en ese test y `logs/V3-despues2.log`
  pasó (422,97 s) con el mismo binario.

Se **paró** al fallar, se verificó la base y se siguió solo con la base verde confirmada. Ambos logs
se conservan. Recomendación para el director: aislar `v5_sigkill…` o subir el presupuesto de 30 s de
la ronda de régimen.

## 5. Lo que esta orden NO demuestra

- **No construye una colisión real de 8 bytes de SHA3-256.** Sería un ataque de cumpleaños de ~2³²
  hashes y no cabe en un test. El test demuestra la propiedad de tipo (la tupla literal no se
  proyecta) con dos billetes que comparten los 8 primeros bytes de su codificación canónica. Ver
  `PROGRESO.md`, falta de definición 1.
- **No toca `mergeset_limite`.** El perfil sólo fija 15 padres; `zx-cadena` conserva el tope del
  oráculo (180) en `inicializar_dag`. Queda declarado (`PROGRESO.md`, falta de definición 4).
- **No re-verifica los oráculos T04**: los consume como especificación.
- **`de_fixture` sigue en los tests sintéticos de `zx-dag`** (`ghostdag_oraculo`, `ghostdag_rust`,
  `ghostdag_prop`), que no son la ruta de producción de `BloquePost` (`PROGRESO.md`, falta de
  definición 5).

## 6. Presupuesto y trazas

Presupuesto declarado: **1 h 30 min de reloj, 8 hilos, 16 GiB de RAM**, disco amplio. Consumo real
≈ 2 h 09 min de reloj (la V0 fallida + V0b + dos V3 completas por el *flake* y por conservar el test
previo). Toolchain `nightly-2026-05-03` (`cargo/rustc 1.97.0-nightly`), 8 jobs,
`RUST_TEST_THREADS=8`, `RUSTFLAGS=`. Artefactos: `ws/`, `ws.orig/`, `cambios.patch` (32 708 bytes,
**11 rutas: 9 modificadas + 2 nuevas**), `MIGRACION.sha256` (210 huellas, `sha256sum -c` OK),
`logs/` (V0, V0b, V0-reintento, V1–V4, V6, entrada, migración, lock), `INFORME.md`, `PROGRESO.md`,
`HORAS.log`. `Cargo.lock`: **sin cambios** (`cmp` igual).

## 7. Resumen final (≤ 40 líneas)

1. V0 sin cambios: falla `reinicio.rs` V5 (ronda régimen 4); V0b: 694/0/2. Flake de temporización
   ya visto en W06d1; base verde verificada antes de editar.
2. V1 `fmt --check` y V2 `clippy -D warnings --all-targets` limpios.
3. V3 final: **698 pasan / 0 fallan / 2 ignorados**; los 694 previos con su nombre + 4 nuevos.
4. V4: `diferencial_t04` 914 casos, **0 discrepancias**; cobertura idéntica.
5. `max_padres` es parámetro de `Cadena::nueva`; fuera `MAX_PADRES_ORACULO = 3`.
6. El nodo pasa `perfil::MAX_PADRES` (15); el arnés T04 declara 3.
7. `BloquePost::identidad` es `IdentidadGhostdag` real; `de_fixture` sólo en T04.
8. `zx-node` deriva la tupla de la cabecera y **no** trunca.
9. Test nuevo: 15 padres admitido, 16 rechazado; con 3, cuarto rechazado.
10. Test nuevo: identidades reales con prefijo de 8 bytes común no colapsan; repetida da `ErrU2`.
11. Test nuevo del nodo: `padres_de_regimen` selecciona 15 de 16 puntas.
12. `propiedades.rs`/`contexto_dag.rs` con identidades reales y `max_padres` explícito.
13. Test previo `es_determinista_y_nunca_cero` conservado (adaptado a la identidad real).
14. V6: 23 dependencias exactas, 9 fronteras OK, lock byte a byte idéntico.
15. Entrada congelada 5/5 al inicio y al final.
16. Límite declarado: la colisión real de 8 bytes de SHA3 no es construible en test.
17. Presupuesto: ≈ 2 h 09 min reales frente a 1 h 30 min previstos (flake + repetición).
18. Veredicto: **SUPERADO**; la pregunta falsable no queda refutada.
