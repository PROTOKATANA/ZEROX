# PROGRESO.md — ORDEN-W06c

Red de la red dev: `crates/zx-p2p` portado con los mensajes del híbrido. Zona única:
`/home/katana/zeo/ZEROX/deepseek/W06c/`.

## Entrada congelada — comprobación (INICIO y FINAL, último paso)

`sha256sum -c P-ZRX/P-NODO/ENTRADA-W06c.sha256` (desde `/home/katana/zeo/ZEROX`) coincide en los
cuatro ficheros; captura en `logs/ENTRADA-w06c.log`:

```
P-ZRX/P-NODO/ORDEN-W06c.md: La suma coincide
P-ZRX/P-NODO/PLAN-W06.md: La suma coincide
P-ZRX/P-FORMATO/FORMATO-v0.md: La suma coincide
V-ZRX/LINEO.md: La suma coincide
exit=0
```

## Falta de definición detectada antes de editar (y resolución)

La orden pide informar antes de improvisar. Se detectaron y resolvieron estas imprecisiones; todas
quedan declaradas en el `INFORME.md` §5:

1. **Tipo del campo `red` del saludo.** La orden lo nombra sin tipo. Se fija `Red` de `zx-core`,
   codificado como **un byte cerrado** (`Mainnet=0`, `Testnet=1`, `Dev=2`); un byte fuera del
   conjunto se rechaza (`ErrorCodec::RedDesconocida`), no se interpreta por defecto.
2. **`punta_pow` como tupla.** Se materializa en la struct `PuntaPow { hash, altura,
   trabajo_acumulado }`, equivalente 1:1 a la terna descrita.
3. **Tema de transacciones.** La decisión 3 enumera **dos** temas de gossip y no menciona `txs`.
   Se implementan exactamente dos (bloques PoW y PoST completos). `tx_difundida` se conserva en el
   trait (decisión 2, «sin cambio de lógica») pero en 0.0.1 no hay tema que lo alimente.
4. **Límite de peso del cuerpo.** `zx-core` **no** ha portado `peso.rs`, así que se aplica la
   alternativa que la propia orden autoriza: **2 MiB dev** declarados en
   `limites::MAX_CUERPO_DEV_BYTES` (cabecera PoST máxima + 2 MiB = `MAX_BLOQUE_RED_BYTES`).
5. **`CabecerasPow::parada`.** Se mantiene el `Option<BlockHash>` del `hasta` portado: la orden
   solo lo renombra.
6. **`ModoCodec::SoloEstado` del perfil dev.** La orden exige petición/respuesta de bloques en la
   red dev (V5), que el modo «solo saludo» de `9681061` prohibía. Se retira ese modo y el perfil dev
   usa el códec completo; la restricción era transitoria de la red lineal.
7. **La desconexión por génesis ajeno.** La comparación es decisión del nodo (decisión 5 prohíbe
   que `zx-p2p` valide); el test V5 recorre el camino completo y corta vía
   `ManejoRed::desconectar`, y comprueba el `PeerDesconectado` en el otro extremo.

## Secuencia de trabajo

1. **02:31–02:34 · Lectura y montaje.** Lectura íntegra de la orden, `LINEO.md`, `PLAN-W06.md` y
   `FORMATO-v0.md`; lectura del código antiguo (`ref/old/`, extraído con `git show 9681061:`) y de
   la API pública de `zx-core` (`red`, `wire`, `wire_dag`, `error`, `encoding`, `tx`,
   `preimage::{block,dag}`). Copia de la base a `ws.orig/` y `ws/`; enlace `PDF` al clon real y
   `CARGO_HOME` local (el `~/.cargo` es de solo lectura en el sandbox).
2. **02:34–02:39 · Implementación.** Crate nuevo `crates/zx-p2p`: `mensaje.rs` (dos familias, saludo
   nuevo, `CabecerasPow`), `codec.rs` (familia declarada + `ErrorCodec`), `config.rs` (perfil
   `/zx-dev/1` y dos temas), `limites.rs` (bloque 2 MiB, 256 hashes, 2000 cabeceras), `behaviour.rs`,
   `servicio.rs`, `entrante.rs`; portados literales `error.rs`, `limites_ip.rs`, `presupuesto.rs`;
   `tests/dos_nodos.rs` sobre `MemoryTransport`.
3. **02:39–02:40 · Lock.** Resolución de dependencias con las versiones del `Cargo.lock` de
   `9681061`; 18 paquetes bajados con `cargo update --precise`; `logs/lock-subconjunto.txt` con
   **400/400** versiones idénticas.
4. **02:41–02:42 · V1/V2 y tests de zx-p2p.** fmt y clippy `-D warnings` limpios; **77 + 10** tests
   pasan.
5. **02:42–02:47 · V3–V7.** `cargo test --workspace --all-features --locked` (**502 pasan, 0
   fallan, 1 ignorado**); `fmt --check`; `clippy --workspace -D warnings`;
   `dependencias-exactas.sh` (20 exactas) y `frontera-crates.sh` (incluye `zx-p2p → {zx-core}`).
6. **02:47–02:48 · Entregables.** `cambios.patch`, `MIGRACION.sha256`, `ref/`, `logs/`,
   `INFORME.md`, este `PROGRESO.md` y comprobación final de la entrada.

## Resultado

- V1 `fmt` OK; V2 `clippy -D warnings` OK; V3 **502/0**; V4 lista de tests portados/adaptados/
  retirados en `logs/V4-tests-portados.txt`; V5 los 10 de integración en
  `logs/V5-integracion.txt`; V6 el mapa caso→error en `logs/V6-codec.txt`; V7 OK.
- `Cargo.lock` actualizado con las dependencias de `zx-p2p`, versiones exactas de `9681061`.
- Veredicto: **SUPERADO** (la pregunta falsable no queda refutada).
