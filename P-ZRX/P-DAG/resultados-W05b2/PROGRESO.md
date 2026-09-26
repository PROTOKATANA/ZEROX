# PROGRESO.md — ORDEN-W05b2

Crate nuevo **`crates/zx-post`** (PoT puro, `pot_rango`, puerta conjunta `cabecera_conjunta`,
contexto de transición D-P09…D-P11, justificación PoT del wire y productor del primer bloque PoST
real hijo de un terminal dev). Zona única: `/home/katana/zeo/ZEROX/deepseek/W05b2/`.

## Entrada congelada — comprobación de INICIO (2026-09-26T02:33)

`sha256sum -c P-ZRX/P-DAG/ENTRADA-W05b2.sha256` desde la raíz; coinciden las 6 huellas
(`logs/entrada-inicio.log`):

```
P-ZRX/P-DAG/ORDEN-W05b2.md: OK
P-ZRX/P-DAG/DECISIONES-W05.md: OK
P-ZRX/P-DAG/REVISION-W05a.md: OK
P-ZRX/P-DAG/REVISION-W05b1.md: OK
P-ZRX/P-RED-DEV/PERFIL-DEV-v0.md: OK
V-ZRX/LINEO.md: OK
exit=0
```

`LINEO.md` se leyó íntegro antes de escribir código. Es un documento de cálculo Julia (CPU) y
C++/CUDA (GPU); esta orden es un port Rust de consenso, así que se traducen sus reglas aplicables:
**sin Python**, determinismo explícito, presupuesto declarado (3 h, 8 hilos, 16 GiB, 40 GiB) y
medición reproducible del párrafo «Medición informativa» (§6) en perfil `release`, 1 hilo, mediana
de ≥ 10 corridas. No se crea ninguna auditoría Julia: no aplica a un port Rust.

## Faltas de definición detectadas e informadas (antes de fijar el código)

**Ninguna impide cumplir la orden.** Se declaran las interpretaciones aplicadas, sin lógica nueva
inventada:

1. **§3.1/§6-V8 frente a §3.6: `productor.rs` y `zx-farmer`.** §3.1 y §V8 fijan la frontera
   `zx-post → {zx-core, zx-pot, zx-dag, zx-poas}` (lista blanca), mientras §3.6 pide al productor
   recibir «una parcela (`zx-farmer`)». Para respetar la frontera **explícita** sin romper §3.6,
   `productor.rs` abstrae la parcela en un rasgo `FuenteSoluciones` (recibe `(salida, slot, rango)`
   y devuelve soluciones ya verificadas por el camino real de `zx-farmer`). El puente concreto a
   `zx_farmer::ParcelaDisco` vive en los tests de `zx-post` como **dev-dependency** (el script
   `frontera-crates.sh` solo mira dependencias que no son `dev`), y en W06 lo aportará el nodo, que
   ya depende de ambos crates. `zx-consensus` entra también como **dev-dependency** (la excepción de
   §3.1) para minar la cadena PoW de la prueba V5.
2. **§3.5: `justificacion.rs` y el contexto del wire.** `zx_core::wire_dag::verificar_justificacion_pot`
   recibe un `ContextoVerificacionPot` con `flujo`, `semilla`, `retardo` e `iteraciones`, pero **no**
   aporta `pasado` (C-FLU-14) ni `salida_validada` (ancla de C-POT-05), de modo que esa interfaz
   antigua no puede alimentar `pot_rango`. La propia orden sanciona la solución al nombrar
   `pot_rango` y `contexto_transicion.rs`: `zx-post::justificacion` implementa la verificación real
   sobre `InstantaneaPot` (la interfaz que `pot_rango` exige), decodifica los portadores del formato
   de `wire_dag.rs` con la cota `MAX_BUNDLES_POT = 150` y **sustituye** el `IntegracionPotPendiente`
   perpetuo en la nueva ruta. El stub de `zx-core` queda como interfaz superada y **no se toca**:
   `zx-core` no puede depender de `zx-pot` (frontera), y retirarlo arrastraría su test y su rasgo sin
   beneficio. Se documenta en el módulo.
3. **§3.1: `reto_desde_salida` y `aleatoriedad_de_salida`.** La revisión W05b1 ordena usar
   `zx_poas::reto::reto_desde_salida` sin duplicarla. `aleatoriedad_de_salida` es su primitiva y
   vive en el mismo módulo; `pot.rs` la **reutiliza** por reexport en vez de recopiarla. Solo se
   portan a `pot.rs` las funciones de AES/semilla (`proyectar_iteraciones`, conversiones,
   `verificar_slot_aes`, `semilla_siguiente`, `semilla_genesis`).
4. **§3.4/§3.6 sin tipo de error nuevo.** El `ContextoRangoDag` de `zx-dag` solo admite `ErrorDag`.
   El antiguo `ContextoRangoNoDisponible` no existe y D-P11 fija «`SR` esperado = `SR_dev`
   constante recibida por parámetro», así que `rango_esperado` devuelve `Ok(sr_dev)` y **no** hace
   falta añadir variantes a `zx-dag`.
5. **§3.3: `HechosPost`.** Se implementan **exactamente** los campos listados
   (`hash, padre_seleccionado, slot, productor, peso, prueba_valida, requisito_declarado`); la
   `salida_auditada` y la distancia de solución quedan internas de la puerta (no eran campos
   pedidos). El `peso` es `zx_dag::peso(sr)` (`w(SR)` de C-GD-01/C-GD-08).

## Presupuesto declarado

3 h de pared, 8 hilos (`CARGO_BUILD_JOBS=8`, `RUST_TEST_THREADS=8`), 16 GiB de RAM, 40 GiB de disco.
Si se agota, checkpoint e **inconcluso**; nunca convertir un timeout en un resultado negativo.

## Secuencia de trabajo

1. **02:33 · Lectura y montaje.** Lectura íntegra de la orden, `LINEO.md`, `DECISIONES-W05.md`
   (D-P07…D-P14), `REVISION-W05a/W05b1`, `PERFIL-DEV-v0.md` §4, `CONTRATO-v0.md` (TRN-06…TRN-08 y
   ratificaciones), `FORMATO-v0.md` (F-03, F-05, F-09, F-10). Entrada 6/6 OK; código antiguo de
   `9681061` extraído a `ref/`; `ws.orig/` = raíz congelada de W05b1; `ws/` = copia de trabajo;
   `cargo-home` copiado de W05b1 (697 MiB).
2. **02:34 · Faltas de definición informadas** (arriba), antes de escribir código.
3. **02:35–02:40 · Crate `zx-post`.** `pot.rs` (AES/semilla; reto reexportado de `zx_poas::reto`),
   `pot_rango.rs` (portado verbatim salvo la rama de génesis → `PotInvalido(SinPadres)`, D-P08),
   `cabecera_conjunta.rs` (`HechosPost`, errores `zx_dag::ErrorDag`, PoAS de `zx-poas`),
   `contexto_transicion.rs` (D-P09…D-P11), `justificacion.rs` (sustituye `IntegracionPotPendiente`),
   `productor.rs` (PoT slot a slot desde S1, coinbase v3, sello). Raíz: member `zx-post` y frontera
   §V8. `Cargo.lock` gana solo `zx-post` (ningún par externo cambia); primer `cargo check` OK.
4. **02:41–02:43 · Tests portados.** `pot_slot` (7), `pot_derivaciones` (9), `flow` (6),
   `pot_rango` (33 + 6 internos), `cabecera_conjunta` (11 + 9 internos); adaptado el test de génesis
   a D-P08 y `ComprobacionCabecera` → `HechosPost`; **0 retirados** (`logs/V4-tests.txt`).
5. **02:43–02:52 · Tests nuevos.** `contexto_transicion::tests` (6), `tests/justificacion.rs` (3) y
   `tests/extremo_a_extremo.rs` (12): V5 con 3 claves/semillas, V6 con 9 negativos + 1 pendiente, V7
   con el núcleo PoT sobre el contexto dev.

## Resultado

- V1 `fmt` OK; V2 `clippy --workspace --all-features --locked -D warnings` 0 avisos; V3
  `cargo test --workspace --all-features --locked` = **519 pasan, 0 fallan, 1 ignorado**, 415
  nombres previos presentes y 0 ausentes, ~104 nuevos (`logs/V1-V3.log`).
- V4 81 portados/adaptados, 0 retirados. V5 3/3 `Comprobada` con `HechosPost` coherentes. V6 9
  `Invalida` + 1 `Pendiente`, sin pánicos. V7 espías heredadas en verde. V8 dependencias-exactas
  (15) y frontera (5/5, añadida `zx-post`) OK.
- Medición §6 (`release`, 1 hilo, 11 corridas): `prove` 1,389 × 10⁸ iter/s → `N(1 s)` ≈ 138 873 760;
  `verify` 2,201 × 10⁹ iter/s → `N(1 s)` ≈ 2 201 286 288 (`logs/V9-medicion.log`).
- Entregables: `cambios.patch` (20 ficheros), `MIGRACION.sha256` (120 huellas, `sha256sum -c` OK),
  `logs/`, `INFORME.md`, `HORAS.log`. Veredicto: **SUPERADO** (≈ 34 min, presupuesto no agotado).
