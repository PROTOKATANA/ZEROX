# PROGRESO.md — ORDEN-W05b1

Crates **nuevos** `crates/zx-poas` (verificador PoAS, historia génesis dev de D-P12, protocolo dev y
reto de auditoría) y `crates/zx-farmer` (parcela persistente, auditoría por slot y conversión de
candidatos a soluciones verificadas). Sustituye la historia de fixture por la historia derivada del
génesis dev y demuestra de extremo a extremo que un sector ploteado produce ≥3 soluciones que el
verificador real acepta. Zona única: `/home/katana/zeo/ZEROX/deepseek/W05b1/`.

## Entrada congelada — comprobación de INICIO (2026-09-26T02:13)

`sha256sum -c P-ZRX/P-DAG/ENTRADA-W05b1.sha256` desde la raíz; coinciden las 4 huellas
(`logs/entrada-inicio.log`):

```
P-ZRX/P-DAG/ORDEN-W05b1.md: OK
P-ZRX/P-DAG/DECISIONES-W05.md: OK
P-ZRX/P-FORMATO/FORMATO-v0.md: OK
V-ZRX/LINEO.md: OK
exit=0
```

`LINEO.md` se leyó íntegro antes de escribir código. Como LINEO es Julia/C++/CUDA y esta orden es
Rust de consenso, sus reglas aplicables se traducen así: sin Python, determinismo explícito
(semilla fija del relleno, compromiso congelado), nada de `unsafe`, y presupuesto declarado (3 h,
8 hilos, 32 GiB, 40 GiB). No se creó ninguna auditoría Julia: no aplica a un port Rust.

## Falta de definición detectada e informada (antes de fijar el código)

**Ninguna impide cumplir la orden.** Se declaran las interpretaciones aplicadas, sin lógica nueva:

1. **Reto de auditoría (`reto_desde_salida`).** §3.2 pide `farmer.rs`/`productor_poas.rs` «sin
   cambio de lógica», y el código antiguo deriva el reto con `zx_consensus::reto_desde_salida(salida,
   slot)`, que en `9681061` vive en `zx-consensus::pot`. §5 prohíbe portar PoT y dice que «los retos
   de auditoría son valores de prueba de 32 B fijados en los tests (la derivación desde PoT es de
   W05b2)». El `zx-consensus` de W04 **no tiene** `pot.rs`, y la frontera §6 V8 impide que
   `zx-farmer` dependa de `zx-consensus`. **Interpretación:** se porta la función **pura** de 12
   líneas (`blake3(blake3(salida) ‖ LE64(slot))`, sin AES, sin flujo, sin `N(s)`, sin cabecera) a
   `zx-poas::reto`, se conserva la firma antigua `auditar_candidatos(salida, slot, rango)` y se
   añade la primitiva `auditar_con_reto(reto: [u8;32], rango)` para que el reto de 32 B pueda
   fijarse explícitamente. Los tests usan `salida` (16 B) y `slot` de prueba fijos, de los que sale
   el reto; ver «Lo que esta orden NO demuestra» en `INFORME.md`.
2. **`protocolo_dev.rs` dentro de `zx-poas`.** §3.1 asigna el `FarmerProtocolInfo` dev a `zx-poas`,
   lo que obliga a `zx-poas` a depender de `subspace-farmer-components`. Se sigue la letra de la
   orden (el módulo devuelve `FarmerProtocolInfo`) y se declara la dependencia.
3. **Relleno con `rand`/`rand_chacha`.** D-P12 pide `ChaCha8Rng::from_seed(block_hash(génesis))` y
   `fill`. La orden fija `rand_chacha =0.9.0` (del lock antiguo) y advierte de **no** seguir la
   versión que Autonomys usa para su relleno (allí `rand 0.8.5` + `rand_chacha 0.3.1`). Se añade
   `rand =0.9.5` (también del lock antiguo) para usar `Rng::fill` literalmente; es una definición
   propia (D-P12), distinta de la de Autonomys.
4. **Clon de Autonomys en `ws/`.** §4 permite enlace o copia. Se usa un **enlace simbólico**
   `ws/PDF -> /home/katana/zeo/ZEROX/PDF` (81 MiB del clon, no migrado, ignorado por git), excluido
   de `cambios.patch` y de `MIGRACION.sha256`.

## Secuencia de trabajo

1. **02:13 · Lectura y montaje.** Lectura íntegra de `ORDEN-W05b1.md`, `V-ZRX/LINEO.md`,
   `DECISIONES-W05.md` (D-P12/D-P13), `FORMATO-v0.md` §3 y `CONTRATO-v0.md` (D-T05); comprobación de
   la entrada; extracción del código antiguo de `9681061` a `ref/`; `ws.orig/` = W01+W02+W04+W05a y
   `ws/` = copia de trabajo; copia de `.cargo-home` de L01 (697 MiB).
2. **02:14–02:16 · Resolución del árbol.** `Cargo.toml` raíz con `exclude` y dependencias por ruta
   al clon (como `9681061`); `Cargo.lock` resuelto en `--offline` con la caché de L01: 220 paquetes
   frente a 132 de la base y 496 de `9681061`; **toda adición externa existe con su misma versión**
   (`logs/lock-subconjunto.txt`).
3. **02:16–02:19 · Crates.** `zx-poas` (`verificador.rs` portado sin cambio de lógica; `historia.rs`
   con la receta D-P12; `protocolo_dev.rs`; `reto.rs`; `lib.rs`) y `zx-farmer` (`farmer.rs` y
   `productor_poas.rs` portados, apuntando a `HistoriaGenesis`; `lib.rs`). La raíz gana los dos
   miembros y el `ci/frontera-crates.sh` sus dos fronteras.
4. **02:18–02:19 · Compromiso.** Primera corrida de `historia_genesis`: el cotejo falla con el
   valor observado, que se congela en `COMPROMISO_HISTORIA_GENESIS_DEV`
   (`8126fdbe…29f24af9`). El módulo `verificador.rs` compila sin cambios.
5. **02:19–02:29 · Tests y V1–V8.** Portados 15 (`tests/poas.rs`) y 12 (`tests/farmer_disco.rs`);
   retirado `convierte_pot_dev_y_solucion_disco` (PoT, W05b2); nuevos 17 (`historia_genesis.rs`,
   `extremo_a_extremo.rs` y unitarios). `fmt` y `clippy -D warnings` limpios; `cargo test
   --workspace --all-features --locked` = **415 pasan, 0 fallan, 1 ignorado**, 0 nombres previos
   ausentes y 44 nuevos; V5/V6/V7 en verde; `ci/dependencias-exactas.sh` (15) y
   `ci/frontera-crates.sh` (`zx-poas → {zx-core, zx-consensus}`, `zx-farmer → {zx-core, zx-poas}`)
   OK.
6. **02:29 · Entregables.** `cambios.patch` (20 ficheros), `MIGRACION.sha256` (103 huellas,
   `sha256sum -c` OK), `INFORME.md`, `PROGRESO.md`, `HORAS.log`, `logs/`.

## Resultado

- V1 `fmt` OK; V2 `clippy -D warnings` 0 avisos; V3 415/0/1 (44 nombres nuevos, 372 previos
  intactos); V4 15+12 portados/adaptados y 1 retirado declarado; V5 3/3 soluciones verificadas; V6
  10 negativos con su error; V7 compromiso determinista y congelado; V8 OK.
- `zx-poas` y `zx-farmer` son las dos únicas adiciones al `Cargo.lock` (junto con el árbol Autonomys,
  todo con versiones del lock de `9681061`); ninguna versión existente cambia.
- Veredicto: **SUPERADO**.
