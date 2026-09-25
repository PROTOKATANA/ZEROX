# METODO — S01

**Objetivo.** Ejecutar `ENCARGO-01-FORMATO-ALTA.md` con la plantilla de `AUTO-ZRX.md` §6 en una zona
aislada (`deepseek/S01/`): fijar R1/R2, plotear un sector PoAS real, verificar una solución con el
verificador del clon, abrirla contra R2, rechazar los negativos del modelo de amenaza y medir.

## 1. Entradas leídas íntegras antes de escribir código

- `P-ZRX/P-REGISTRO-SECTORES/ORDEN-S01.md`, `ENCARGO.md`, `ANALISIS.md`,
  `ENCARGO-01-FORMATO-ALTA.md`.
- `V-ZRX/LINEO.md` (íntegro, antes de cualquier cálculo).
- `D-ZRX/RFT-ZRX.md` (RFT-03, RFT-04, RFT-06 y resto, para no chocar con una refutación vigente).
- `P-ZRX/P-REGISTRO-SECTORES/investigacion/fuentes-filecoin/INFORME.md` y `REVISION.md`.
- Histórico (solo lectura, en `/home/katana/zeo/.trash/zerox/`): `P-COBERTURA/investigacion/INFORME.md`
  §§2–3 y 7; `P-SEMBRADOR/investigacion/INFORME.md` fase 1.
- Código de referencia (solo lectura, commit `9681061`): `crates/zx-node/src/farmer.rs`,
  `crates/zx-node/tests/farmer_disco.rs`, `crates/zx-consensus/src/poas.rs`.

## 2. Revisión de fuente del clon de Autonomys (`f8842d0`, copia local)

Se clonó `PDF/autonomys-subspace` a `deepseek/S01/autonomys-subspace` (`git clone --no-hardlinks`
+ `checkout --detach f8842d0…`), sin tocar el original. Se verificaron en el clon, línea a línea:

- `subspace-verification/src/lib.rs:228-350`: derivación de `SectorId`, reto global, `s_bucket`,
  PoS, máscara `chunk XOR proof.hash()` (`:248-249`), distancia y KZG.
- `subspace-farmer-components/src/sector.rs:436-470,521-552`: orden físico de `iter_record_chunk_to_plot`
  y `iter_s_bucket_records`.
- `sector.rs:582-608`: regla de chunks usados (codificados + no codificados al final).
- `sector.rs:362-364` y `pieces.rs:559-570`: tamaño del mapa, `NUM_CHUNKS`, `NUM_S_BUCKETS`.
- `plotting.rs:384-417,616-667`: encoding por registro en paralelo y `generate_parallel`.
- `plotting.rs:519-614`: layout del archivo de sector (mapa ‖ chunks ‖ metadatos ‖ checksum).

No se copió ni se reimplementó PoS, KZG ni erasure coding: se enlazó la API pública por `path`.

## 3. Construcción y verificación

1. **Prototipo Rust** (`prototipo/`, crate independiente). `H_d` reimplementada en 3 líneas porque
   `zx_core::hash` es `pub(crate)`. Se leen las regiones del archivo, se construyen las hojas en
   orden físico, el Merkle con relleno `vacío` y R2; `apertura` extrae `(chunk_location, camino)` y
   los digests; `verificar_apertura` recompone R2 y coteja identidad, codificación, camino y
   cardinalidad.
2. **Solución real.** Se plotea con `plot_sector` + `CpuRecordsEncoder::<ChiaTable>` (ruta paralela)
   sobre la historia archivada determinista del fixture dev. La búsqueda audita por slot con
   `audit_sector_sync` y convierte candidatos con `SolutionCandidates::into_solutions`; la solución
   se verifica con `subspace_verification::verify_solution::<ChiaTable,_>` **antes** de abrir.
3. **Oráculo independiente Julia** (`oraculo-r2/`): reimplementa SHA3-256 con `SHA`, la
   decodificación del mapa (bitfields Lsb0), la regla de chunks usados, el orden de hojas y el
   Merkle; recalcula `raiz_chunks` y R2 desde el volcado. Coincidencia byte a byte requerida.
4. **Registro abstracto** en memoria: alta, duplicado y caducidad por slot, etiquetado como
   abstracto (no es formato de cadena).

## 4. Modelo de amenaza ejercitado

Prover que intenta usar una solución de otra clave/índice/`history_size`; cambiar la versión o el
`CBID`; presentar una hoja con otro `piece_offset`/`s_bucket`, un camino de otra posición/hoja o la
raíz de otro sector; declarar `codificado = 0`; digests ajenos; alta duplicada o caducada. Todos se
ejecutan y se exige el error concreto. **No modelado** (declarado en el informe): corrección del
ploteo (solo R3), preexistencia, permanencia y doble uso entre ramas (RFT-06).

## 5. Medición (LINEO §6–§7; no es benchmark de producción)

- **Modelo de coste:** el compromiso R2 recorre los `n = p·2^15` chunks y construye un Merkle de
  `2m·32 B` (`m = next_pow2(n)`); la verificación recorre `log2(m)` hashes SHA3-256 más la
  recomposición de R2.
- **Referencia y kernel:** para el formato, la referencia es el propio plotter/verificador real del
  clon; para R2, el oráculo Julia independiente (dos implementaciones que deben coincidir byte a
  byte).
- **Protocolo:** compilar en `--release`; calentar la verificación (100 iteraciones) antes de medir
  1000 verificaciones de apertura y tomar la mediana; `t_plot` y `t_R2` medidos por separado y
  repetidos 3 veces por tamaño (medianas en `resultados/REPETICIONES.tsv`); registrar hardware,
  carga (`uptime`), versiones, commit del clon y hashes de los lockfiles en `ENTORNO.txt`.
- **Presupuesto:** 3 h de reloj, 8 hilos, 32 GiB de RAM, 60 GiB de disco (el de la orden). No se
  agotó; no hubo timeout. Los hilos se limitaron con `RAYON_NUM_THREADS=8`.
- **Reproducibilidad:** `Cargo.lock` propio (174 paquetes), toolchain pineada, `Manifest.toml` de
  Julia, versión de Julia en `julia-version.toml`, semilla del fixture declarada.

## 6. Que no se hace

- No se usa **Python** en ningún punto.
- No se declara ningún `Ok` ficticio: cada fallo devuelve su variante de error.
- No se usa `@fastmath`/`-ffast-math`; no hay cálculo `Float64` que decida un veredicto.
- No se toca `D-ZRX/SPEC.md` ni el consenso; no se escribe fuera de `deepseek/S01/`; no hay commit
  ni push.
- No se presenta el coste del prototipo como benchmark de red: la ruta R2 de S01 es serial y no
  optimizada, y así se declara.
