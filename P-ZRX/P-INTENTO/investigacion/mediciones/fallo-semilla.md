# Fallo reproducible: SIGSEGV en `ab-proof-of-space` para ciertas semillas

**Fecha:** 2026-09-21 · **Clon:** `/home/katana/zeo/fuentes/subspace` @ `f8842d0` ·
toolchain `nightly-2026-05-03` · **Máquina:** AMD Ryzen 9 9950X3D, 32 hilos lógicos.

Este documento NO responde a ninguna pregunta del encargo P-INTENTO. Existe porque el barrido de
M1 tropezó con él y porque un fallo reproducible se documenta con su entrada mínima, no se
esconde por el camino.

---

## Hecho observado

**[Medido]** `ab_proof_of_space::chiapos::Tables::<20>::create_proofs` — función **pública**, la
misma que usa `ChiaV2TableGenerator::generate` en
`crates/subspace-proof-of-space/src/chia_v2.rs:28-36` — termina el proceso con **SIGSEGV**
(código de salida 139) para ciertas semillas de 32 bytes.

### Entrada mínima reproducible

Semilla de 32 bytes, en hexadecimal:

```
fc5317b05613ed8f1296ebca4c01b008e56a6dcc1d8c9619a4ddd741b285bcbc
```

Una sola llamada, un solo hilo, sin concurrencia:

```bash
cd P-ZRX/P-INTENTO/investigacion
CARGO_TARGET_DIR="$PWD/target" \
  ./target/release/estres 1 1 separadas fija 0   # con SEMILLA_HEX=<la de arriba>
```

Resultado observado, 3 de 3 ejecuciones:

```
Violación de segmento (`core' generado)      # rc = 139
```

La misma prueba con `SEMILLA_HEX=0000…0000` (32 bytes cero) sale con `rc = 0`. La comparación entre rutas de código está dos secciones más abajo.

**[Verificado por aislamiento]** La semilla se pasa como **bytes crudos** a través de
`SEMILLA_HEX`, sin pasar por el ayudante `seed_i` del banco. El fallo ocurre igual, así que la
causa no está en el banco: está en la biblioteca fijada.

**[Medido]** La semilla `fc5317b0…bcbc` es `seed_i(127)` del banco, es decir
`blake3("INTENTO1" ‖ 127_u64_le)`.

### No es concurrencia y no es acumulativo

| Prueba | Resultado |
|---|---|
| 1 hilo, 1 tabla, semilla `fc5317b0…` | **SIGSEGV (139)**, 3/3 |
| 1 hilo, 1 tabla, semilla `0000…` | rc = 0 |
| 1 hilo, 200 tablas, semilla `0000…` repetida | rc = 0 |
| 1 hilo, 200 tablas, semillas 0…15 en ciclo | rc = 0 |
| 1 hilo, semillas 0,1,2,… en orden | aborta al llegar al índice 127 |
| 1 hilo, semillas 100 000, 100 001, … | ver `fallo-semilla-muestra2.txt` |
| 1 hilo, 1 tabla, índices 120,124,125,126,128,129,130,200,255,256,1000 | rc = 0 |

Con 1 solo hilo se reproduce, así que **no es una carrera de datos ni un problema de concurrencia**.
Y como `SEMILLA_HEX=0000…` aguanta 200 tablas seguidas, tampoco es acumulativo: es la **semilla**.

En una corrida con semillas distintas y consecutivas, el proceso abortó además con
`corrupted size vs. prev_size while consolidating` (glibc), es decir **corrupción de heap**, no solo
el `SIGSEGV` aislado. Ambos síntomas apuntan a una escritura fuera de rango dentro de la
construcción de tablas, que según la semilla cae en memoria asignada (corrompe el heap) o en una
página no mapeada (SIGSEGV).

---

## Qué camino de código falla, y cuál no

**[Medido]** Se ejercitaron las tres funciones públicas que construyen tablas con la misma semilla
mala y con la semilla cero:

| Función pública | Uso | Semilla `fc5317b0…bcbc` | Semilla `0000…0000` |
|---|---|---|---|
| `Tables::<20>::create_proofs` | camino **no paralelo**; `ChiaV2TableGenerator::generate` | **SIGSEGV (139)** | rc = 0 |
| `Tables::<20>::create_proofs_parallel` | `ChiaV2TableGenerator::generate_parallel` | **rc = 0** | rc = 0 |
| `Tables::<20>::create` | las siete tablas completas, no paralelo | **SIGSEGV (139)** | rc = 0 |

Es decir: **el fallo está en la construcción de tablas NO paralela**, tanto en la variante que
devuelve las siete tablas (`create`) como en la que devuelve las pruebas (`create_proofs`). La ruta
paralela, que usa la variante `PrunedTable::OtherBuckets`
(`shared/ab-proof-of-space/src/chiapos/table.rs:887-905`), **no falla con esta semilla**.

## Alcance e impacto

- **[Verificado en fuente]** El **plotter honesto** llama a `generate_parallel`
  (`crates/subspace-farmer-components/src/plotting.rs:620-629` →
  `crates/subspace-proof-of-space/src/chia_v2.rs:39-45` → `create_proofs_parallel`), es decir la
  ruta que **no** falla. Por tanto este hallazgo **no** implica que un granjero se caiga al plotear.
- **[Verificado en fuente]** La ruta que sí falla (`generate` → `create_proofs`) es la que usan el
  banco `pos` del propio clon (`crates/subspace-proof-of-space/benches/pos.rs`,
  `table/single/*`) y la que mide M1 de este encargo: el atacante que genera tablas sueltas.
- **[Estimado, no medido]** La tasa de semillas que disparan el fallo es del orden de **1 entre 10²
  y 10³**: se probaron individualmente unas 135 semillas distintas (índices 0–130, 200, 255, 256,
  1000) con 1 sola mala (la del índice 127), y en una corrida sobre índices grandes apareció al
  menos otra. **No se ha medido la tasa**, y con dos avistamientos no se puede acotar.
- **[No determinado]** La causa raíz. No hay `gdb` en la máquina, `core_pattern` envía los cores a
  `systemd-coredump` (requiere root para leerlos) y no se dispone de `sudo`. Localizarla exigiría
  compilar con `-Zsanitizer=address`, que quedó fuera del presupuesto de este encargo.

## Qué NO cambia

- Las cifras de M1, M2, M3 y M4 se miden **tabla a tabla**, con semillas fijas verificadas seguras.
  El fallo no altera ninguna de esas medidas.
- Lo único que cambia es el **barrido agregado**: cicla sobre un conjunto de semillas verificado
  (`POOL_SEGURO = 32` en `banco-rust/src/bin/escalado.rs`) en vez de recorrer semillas nuevas.

## Reproducción

```bash
cd P-ZRX/P-INTENTO/investigacion/banco-rust
CARGO_TARGET_DIR=../target cargo build --release --bin estres
cd ..
SEMILLA_HEX=fc5317b05613ed8f1296ebca4c01b008e56a6dcc1d8c9619a4ddd741b285bcbc \
  ./target/release/estres 1 1 separadas fija 0 ; echo "rc=$?"
```

## Qué habría que hacer, si Katana quiere cerrarlo

1. Compilar `ab-proof-of-space` con `-Zsanitizer=address` y correr la entrada mínima: da la línea
   exacta de la escritura fuera de rango.
2. Comprobar si el fallo existe también en el `rev` más reciente del repositorio de Autonomys
   (aquí solo se ha probado el `f8842d0` fijado).
3. Si se confirma, decidir si ZEROX hereda `ab-proof-of-space` como dependencia o exige el arreglo
   antes de adoptarlo. **No se ha tocado el clon**: no se ha modificado ni una línea.
