# INFORME.md — ORDEN-W06c

**Red de la red dev: `crates/zx-p2p` portado con los mensajes del híbrido.**
Sesión: DeepSeek Harness, modelo `deepseek-flash`, esfuerzo `high`.
Fecha: 2026-09-26, 02:31–02:48 +02:00. Zona única: `/home/katana/zeo/ZEROX/deepseek/W06c/`.
Sin Python; nada escrito fuera de la zona; sin commit ni push; sin secretos.
Base: workspace de la raíz (commit `e0b5155`, W05b1), copiado a `ws.orig/` y `ws/`; código antiguo
de `zx-p2p` extraído de `9681061` a `ref/old/` (solo lectura).

**Pregunta falsable:** «Dos pares con `MemoryTransport` se saludan, intercambian bloques PoW y PoST
completos por anuncio y por petición, y rechazan en el códec toda codificación no canónica o que
exceda los límites, sin que `zx-p2p` dependa de nada salvo `zx-core`.»
**Veredicto: NO REFUTADA — SUPERADO.** Los 10 tests de integración y los 77 de librería pasan; el
cierre de dependencias de `zx-p2p` (400 paquetes) usa exactamente las versiones de `9681061`; la
frontera `zx-p2p → {zx-core}` está comprobada por la CI.

## 1. Veredicto por paso

| Paso | Comando (desde `ws/`, entorno §6) | Veredicto |
|---|---|---|
| V1 | `cargo fmt --all -- --check` | **OK** (exit 0; `logs/V1-fmt.log`) |
| V2 | `cargo clippy --workspace --all-targets --all-features --locked -- -D warnings` | **OK** (exit 0, 0 avisos; `logs/V2-clippy.log`) |
| V3 | `cargo test --workspace --all-features --locked` | **OK** (exit 0; **502** pasan, 0 fallan, 1 ignorado; `logs/V3-test.log`) |
| V4 | tests antiguos portados/adaptados/retirados, con motivo | **OK** (lista completa; `logs/V4-tests-portados.txt`) |
| V5 | integración con `MemoryTransport` | **OK** (10/10; `logs/V5-integracion.txt`, `logs/test-zx-p2p.log`) |
| V6 | códec: ida y vuelta y rechazos, cada uno con su error | **OK** (mapa caso→error; `logs/V6-codec.txt`) |
| V7 | `ci/dependencias-exactas.sh` y `ci/frontera-crates.sh` | **OK** (20 dependencias exactas; 5 fronteras, incluida `zx-p2p → {zx-core}`; `logs/V7-deps.log`, `logs/V7-frontera.log`) |
| Entrada | `sha256sum -c P-ZRX/P-NODO/ENTRADA-W06c.sha256` | **OK** en inicio y final (4/4; `logs/ENTRADA-w06c.log`) |
| Lock | cotejo del cierre de `zx-p2p` contra el lock de `9681061` | **OK** (400/400 versiones idénticas; `logs/lock-subconjunto.txt`) |

Desglose de V3: `zx-p2p` = **77** (lib) + **10** (`dos_nodos`) + 0 doc-tests. El resto son los
tests previos del workspace (zx-core, zx-pot, zx-consensus, zx-dag, zx-poas, zx-farmer), todos con
su nombre. El único ignorado es pre-existente (no de `zx-p2p`).

## 2. Mensajes nuevos y discriminantes

`crates/zx-p2p/src/mensaje.rs`. Versión de protocolo nueva: **`/zx-dev/1`**.

| Tipo | Variante | Discriminante |
|---|---|---|
| `FamiliaBloque` | `Pow` / `Post` | `0x00` / `0x01` |
| `Fase` | `Pow` / `Post` | `0x00` / `0x01` |
| `red` | `Mainnet` / `Testnet` / `Dev` | `0x00` / `0x01` / `0x02` |
| `Peticion` | `Estado` / `CabecerasPow` / `Bloques` | `0x00` / `0x01` / `0x02` |
| `Respuesta` | `Estado` / `CabecerasPow` / `Bloques` / `NoDisponible` | `0x00` / `0x01` / `0x02` / `0x03` |

- `BloqueRed = enum { Pow { cabecera: BlockHeader, txs, testigos }, Post { cabecera:
  DagBlockHeader, txs, testigos } }`. El wire lleva **byte de familia explícito**; el códec lo
  **exige** contra la familia declarada por el llamante (F-04) y nunca adivina por longitud. La
  ruta de respuesta usa `bloque_desde_bytes_autotag` (la familia viene del byte del wire, no de la
  longitud).
- `Estado = { hash_genesis, red, fase, punta_pow: PuntaPow { hash, altura, trabajo_acumulado
  [u8;32] BE }, terminal: Option<BlockHash>, punta_post: Vec<BlockHash> (≤ 16), blue_work_virtual
  [u8;32] BE }`.
- `Peticion::CabecerasPow { locator: Vec<BlockHash> (≤ 64), parada: Option<BlockHash> }`.
- `Peticion::Bloques { hashes }` (≤ 256) y `Respuesta::Bloques(Vec<BloqueRed>)`.
- Gossip: **dos** temas con el bloque completo, `/zx-dev/bloques/pow/1` y
  `/zx-dev/bloques/post/1` (`topic_bloques_pow`/`topic_bloques_post`, perfil dev). El tema decide
  la familia declarada; un bloque de otra familia se rechaza.
- `Estado` serializado: `1 + 32 + 1 + 1 + (32+4+32) + (1+32) + (CompactSize + ≤16·32) + 32` ≤ 681 B.
- El **relé compacto no se porta** en 0.0.1: se retiran `rele_compacto.rs`, `id_corto.rs`,
  `FaltantesCompactas`, `anuncio_compacto` y `transacciones_compactas`. El código antiguo queda en
  `ref/old/`.

## 3. Límites nuevos y su motivo

`crates/zx-p2p/src/limites.rs`. Todo límite es explícito (C-NET-11); las relaciones entre
constantes son aserciones de compilación.

| Constante | Valor | Motivo |
|---|---:|---|
| `MAX_CUERPO_DEV_BYTES` | 2 MiB | La orden pide «el límite de peso de `zx-core` o, si no existe, 2 MiB dev». `peso.rs` no está portado: **2 MiB dev declarados**. |
| `MAX_BLOQUE_RED_BYTES` | 1 037 + 2 MiB = 2 098 189 B | Cabecera PoST máxima (`TAMANO_CABECERA_MAX = 1 037`, la mayor de las dos familias) + cuerpo dev. |
| `MAX_HASHES_POR_PETICION` | 256 | Fijado por la orden. 8 KiB de cuerpo: la petición sigue siendo diminuta. |
| `MAX_CABECERAS_POR_RESPUESTA` | 2 000 | Fijado por la orden (≈184 KB de cabeceras a 92 B). |
| `MAX_BLOQUES_POR_RESPUESTA` | 16 | Portado; la respuesta cabe en `MAX_RESPUESTA_BYTES`. |
| `MAX_PETICION_BYTES` | 64 KiB | Portado: un locator, no un lote. |
| `MAX_RESPUESTA_BYTES` | 16·`MAX_BLOQUE_RED_BYTES` + 64 KiB | Portado, recalculado con el bloque nuevo. |
| `MAX_GOSSIP_BYTES` | `limite_gossip(LIMITE_BLOQUE_DEV)` = 8·2 MiB | El default de libp2p (65 536 B) no admite un bloque; el techo se deriva del límite (C-NET-13). |
| Conexiones | 24 salientes / 72 entrantes / 1 por peer / 32 pendientes | Portados (C-NET-11). |
| `MAX_STREAMS_SYNC` | 8 | Portado: el default son 100 streams concurrentes por peer. |

## 4. Tests portados, adaptados y retirados

Detalle completo en `logs/V4-tests-portados.txt`. Resumen:

- **Portados literales:** `error.rs` (3), `limites_ip.rs` (7), `presupuesto.rs` (7).
- **Adaptados a los mensajes nuevos:** `mensaje.rs`, `codec.rs`, `config.rs`, `behaviour.rs`,
  `servicio.rs`, `entrante.rs` y `tests/dos_nodos.rs`. Mismos invariantes; cambian los tipos, los
  temas y la versión de protocolo.
- **Retirados, con motivo:** todo el relé compacto (`rele_compacto.rs` ~25 tests, `id_corto.rs` 9
  tests, `examples/medir_reconstruccion.rs`, `FaltantesCompactas`, `MAX_PEERS_ALTO_ANCHO_BANDA`) y
  el modo `SoloEstado` del perfil dev (6 tests) porque la orden exige sincronización completa en
  dev. También se retiran los dos tests de `limites` que dependían de `zx-consensus` como
  *dev-dependency* (W03 modifica ese crate en paralelo; la orden prohíbe depender de él).
- **Nuevos:** ida y vuelta de bloques por familia, familia cambiada/desconocida, bloque por encima
  del máximo, demasiadas puntas PoST, contador no mínimo, anuncio de bloque PoW/PoST por gossip,
  petición de bloques por hash y desconexión por génesis ajeno.

## 5. Definición imperfecta detectada antes de actuar (y resolución)

1. **Tipo del campo `red`**: se fija `Red` de `zx-core` con byte cerrado `Mainnet=0/Testnet=1/
   Dev=2`; un byte fuera del conjunto se rechaza. (§2)
2. **`punta_pow` como tupla**: se materializa en `PuntaPow` con los mismos tres campos.
3. **Temas de gossip**: la orden enumera dos (bloques PoW y PoST) y no menciona `txs`; se
   implementan exactamente esos dos. `tx_difundida` se conserva en el trait pero en 0.0.1 no tiene
   canal, y así se declara.
4. **Límite de cuerpo**: no existe `peso.rs`; se aplica la alternativa autorizada (2 MiB dev).
5. **`parada` de `CabecerasPow`**: se mantiene `Option<BlockHash>` del `hasta` portado.
6. **`SoloEstado` del perfil dev**: se retira porque V5 exige petición/respuesta de bloques en dev.
7. **Desconexión por génesis ajeno**: es decisión del nodo (la orden prohíbe que `zx-p2p` valide);
   el test V5 recorre el corte completo vía `ManejoRed::desconectar`.

## 6. Lo que esta orden NO demuestra

- **Validación de bloques.** `zx-p2p` no valida: solo comprueba la forma de sus mensajes. Que un
  bloque sea válido (PoW, PoAS, PoT, firmas, estado, coinbase) es del nodo y de W03+.
- **Sincronización real.** El locator y las peticiones se transportan, pero no hay motor de IBD,
  resolución de huérfanos, ni elección de cadena: eso es W06d/W06e.
- **Red real entre procesos.** Todo se prueba con `MemoryTransport`; no hay TCP/QUIC, Ni NAT, ni
  latencia, pérdida o reordenamiento reales.
- **Resistencia a eclipse.** Se portan límites por prefijo y baneo (C-NET-20) con sus tests, pero
  no se demuestra que resistan un eclipse dirigido.
- **Reanudación/persistencia de mensajes** y **resistencia a partición**.
- **Que la CI de GitHub funcione en GitHub**: no se ejecutó allí, solo localmente.

## 7. Presupuesto y trazas

**Reproducción local (solo zona):** `ws/PDF` es un enlace al clon real
`PDF/autonomys-subspace` (las dependencias *path* de `zx-poas`/`zx-farmer` lo exigen) y
`CARGO_HOME=W06c/.cargo-home`. Ni el enlace ni `.cargo-home` entran en `cambios.patch` ni en
`MIGRACION.sha256`: en la raíz real el clon `PDF/` ya existe y el `Cargo.toml` conserva su
`exclude` intacto.

Presupuesto: 2 h de reloj, 8 hilos, 16 GiB de RAM, 30 GiB de disco. Consumo real ≈ 17 min de
reloj; `ws` 4,6 GiB (incluye `target` 4,6 GiB), `.cargo-home` 2,6 GiB, `ref/` 360 KiB, `logs/`
2,6 MiB; sin tensión de RAM. Toolchain: `cargo`/`rustc` `nightly-2026-05-03`.
Artefactos: `ws/`, `ws.orig/`, `ref/old/`, `cambios.patch` (8 933 líneas; aplica con
`git apply -p1 --check`), `MIGRACION.sha256` (118 huellas, `sha256sum -c` OK), `logs/`,
`PROGRESO.md`, `HORAS.log`.

## 8. Resumen final (≤ 40 líneas)

1. W06c cumple: `crates/zx-p2p` portado a la red dev con los mensajes del híbrido.
2. Dependencia única: `zx-p2p → {zx-core}`; `ci/frontera-crates.sh` lo comprueba (5/5 fronteras).
3. Mensajes nuevos: `BloqueRed::{Pow,Post}`, `Estado` con red/fase/dos puntas, `CabecerasPow`.
4. Protocolo `/zx-dev/1`; gossip en `/zx-dev/bloques/pow/1` y `/zx-dev/bloques/post/1`.
5. La familia se **declara** en el wire y el códec la **exige**; no se adivina por longitud (F-04).
6. El relé compacto no se porta en 0.0.1; su código queda archivado en `ref/old/`.
7. Límites: bloque 2 MiB dev (+1 037 B de cabecera), 256 hashes/petición, 2 000 cabeceras/respuesta.
8. Presupuesto agregado (C-NET-21) compartido entre códec y gossip; reserva antes de leer.
9. `ErrorCodec` con variante propia para cada rechazo: familia, red, fase, booleano, tamaño.
10. V1 fmt y V2 clippy `-D warnings` limpios; V3 **502 pasan, 0 fallan, 1 ignorado**.
11. `zx-p2p`: 77 tests de librería + 10 de integración, 0 fallan.
12. V5: saludo, anuncio PoW, anuncio PoST, petición por hash, `NoDisponible` y génesis ajeno.
13. V6: ida y vuelta de cada mensaje y rechazo de familia/truncado/sobrante/no mínimo/exceso.
14. Lock: 400/400 paquetes del cierre de `zx-p2p` con la versión exacta de `9681061`.
15. `cargo update --precise` bajó 18 paquetes transitivos a la versión del lock antiguo.
16. `Cargo.lock` y `Cargo.toml` actualizados; ninguna dependencia fuera del lock antiguo.
17. Portados literales `error.rs`, `limites_ip.rs`, `presupuesto.rs`; el resto adaptado.
18. Retirado el modo `SoloEstado` de dev: V5 exige sync completo en la red dev.
19. No se depende de `zx-consensus` ni en dev: W03 lo modifica en paralelo.
20. No demuestra validación, sincronización, red entre procesos ni resistencia a eclipse.
21. Veredicto: **SUPERADO**; la pregunta falsable no queda refutada.
