# ORDEN-W06c — Red de la red dev: `zx-p2p` portado con mensajes del híbrido

## 1. Identidad y contexto

- **ID:** W06c. **Estado:** redactada 2026-09-26; se lanza tras migrar W05b1. **Director:** Claude.
  **Ejecutor:** DeepSeek.
- **Zona (única escribible):** `/home/katana/zeo/ZEROX/deepseek/W06c/`.
- **Objetivo único:** portar `crates/zx-p2p` de `9681061` (transporte libp2p, límites C-NET,
  codec, servicio) al workspace, con los mensajes rediseñados para las dos familias de bloque, sin
  depender de consenso (D-N01).
- **Pregunta falsable:** «Dos pares con `MemoryTransport` se saludan, intercambian bloques PoW y
  PoST completos por anuncio y por petición, y rechazan en el codec toda codificación no canónica o
  que exceda los límites, sin que `zx-p2p` dependa de nada salvo `zx-core`.» Se refuta con un
  mensaje válido que no llega, uno inválido que se acepta o una dependencia prohibida.
- **Desbloquea:** W06d (nodo).

## 2. Autoridad y entradas

Lee íntegros: este archivo; `V-ZRX/LINEO.md`; `P-ZRX/P-NODO/PLAN-W06.md`;
`P-ZRX/P-FORMATO/FORMATO-v0.md`. Código antiguo (solo lectura, `git show 9681061:`):
`crates/zx-p2p/**` (src y tests), su `Cargo.toml`, las entradas de `libp2p`, `tokio`,
`futures`, `siphasher`, `futures_ringbuf` y afines del `Cargo.toml` raíz y del `Cargo.lock`
antiguos, y `ci/frontera-crates.sh`. Base: el workspace de la raíz.
Entrada congelada: `P-ZRX/P-NODO/ENTRADA-W06c.sha256`, al empezar y como último paso.

## 3. Decisiones ya tomadas por el director

1. **Frontera:** `zx-p2p` depende solo de `zx-core` y de sus crates externos (libp2p, tokio…); la CI
   `frontera-crates.sh` lo comprueba (`zx-p2p → {zx-core}`).
2. **Se porta sin cambio de lógica:** transporte, `behaviour`, `limites`, `limites_ip`,
   `presupuesto`, `entrante` (el trait `ManejadorEntrante` que implementará el nodo), `servicio`,
   `config`, `error`, con sus tests. Todo límite sigue siendo explícito (C-NET-11).
3. **Mensajes nuevos** (sustituyen a los lineales de `mensaje.rs`; discriminantes nuevos, versión de
   protocolo nueva `/zx-dev/1`):
   - `BloqueRed` = `enum { Pow { cabecera: BlockHeader, txs, testigos }, Post { cabecera:
     DagBlockHeader, txs, testigos } }`, con codec que **exige** la familia declarada (F-04: nada se
     adivina por la longitud).
   - `Estado` (saludo) = `{ hash_genesis, red, fase: PoW | PoST, punta_pow: (hash, altura,
     trabajo_acumulado 32 B BE), terminal: Option<hash>, puntas_post: Vec<hash> (≤ 16),
     blue_work_virtual: 32 B BE }`. Génesis o red distintos ⇒ desconexión (como antes).
   - `Peticion` = `Estado | CabecerasPow { locator, parada } | Bloques { hashes (≤ límite) }`;
     `Respuesta` = `Estado | CabecerasPow(Vec<BlockHeader>) | Bloques(Vec<BloqueRed>) |
     NoDisponible`.
   - Anuncios por gossip en dos temas, `/zx-dev/bloques/pow/1` y `/zx-dev/bloques/post/1`, con el
     bloque completo. **El relé compacto no se porta** en 0.0.1 (se declara; su código antiguo queda
     en el archivo).
4. **Límites nuevos** con valor dev declarado y comentario de por qué: tamaño máximo de `BloqueRed`
   (cabecera PoST 1 037 B + cuerpo con el límite de peso que ya use `zx-core`, o, si no existe, 2 MiB
   **dev**), máximo de hashes por petición (256), máximo de cabeceras por respuesta (2 000).
5. `zx-p2p` **no** valida bloques: solo la forma de sus mensajes. Entrega bytes decodificados al
   `ManejadorEntrante`, que decide (`Accept/Ignore/Reject` del gossip se comunica **después** de que
   el nodo valide, como describía la nota de E1 antigua: el mensaje queda pendiente con límite de
   memoria y tiempo).

Si algo no se puede cumplir tal cual, **para** e infórmalo antes de improvisar.

## 4. Contrato de ejecución

Patrón W02/W04 (`ws.orig/`, `ws/`, `cambios.patch`, `MIGRACION.sha256`, `logs/`, `INFORME.md`,
`PROGRESO.md`, `HORAS.log`). Versiones de dependencias **exactamente** las del `Cargo.lock` de
`9681061` (demuéstralo en `logs/lock-subconjunto.txt`). `CARGO_BUILD_JOBS=8`, `RUST_TEST_THREADS=8`.

## 5. Modelo de amenaza

Par hostil: mensajes truncados, contadores no mínimos, familias cambiadas, bloques por encima de
los límites, inundación de peticiones, respuestas que no corresponden a la petición, génesis ajeno.
Ningún pánico; límites explícitos.

## 6. Verificación

| Paso | Qué | Criterio |
|---|---|---|
| V1–V2 | `fmt --check`, `clippy -D warnings --locked` | limpio |
| V3 | `cargo test --workspace --all-features --locked` | todo lo previo pasa con su nombre + lo nuevo |
| V4 | Tests antiguos de `zx-p2p` portados, adaptados (mensajes nuevos) o retirados (relé compacto), con motivo | lista completa |
| V5 | Integración en proceso (`MemoryTransport`): saludo, anuncio PoW y PoST recibido por el otro par, petición de bloques por hash, `NoDisponible`, desconexión por génesis ajeno | cada uno pasa |
| V6 | Codec: ida y vuelta de cada mensaje y rechazo de: familia cambiada, truncado, sobrante, contador no mínimo, exceso de límites | cada uno con su error |
| V7 | `dependencias-exactas.sh`, `frontera-crates.sh` | OK |

**Prohibido Python.** Presupuesto: **2 h, 8 hilos, 16 GiB, 30 GiB de disco**.

## 7. Entregables y límites

`ws/`, `cambios.patch`, `MIGRACION.sha256`, `logs/`, `INFORME.md` (veredicto; mensajes y
discriminantes; límites y su motivo; tests portados/retirados; «Lo que esta orden NO demuestra»:
validación, sincronización, red real entre procesos, resistencia a eclipse), `PROGRESO.md`,
`HORAS.log`. Resumen final ≤ 40 líneas. DeepSeek `deepseek-flash`, esfuerzo `high`; LINEO antes del
código; nada fuera de la zona; sin commit ni push; sin secretos; ningún `Ok` ficticio.

## Lanzamiento

    mkdir -p /home/katana/zeo/ZEROX/deepseek/W06c && cd /home/katana/zeo/ZEROX/deepseek/W06c && \
    ( set -a; . /home/katana/torio/deepseek-harness/.env >/dev/null 2>&1; set +a; \
      node /home/katana/torio/deepseek-harness/apps/cli/lib/bin.js --profile headless \
      "Orden W06c. Lee íntegro /home/katana/zeo/ZEROX/P-ZRX/P-NODO/ORDEN-W06c.md y cúmplelo. Antes de escribir código, lee íntegro /home/katana/zeo/ZEROX/V-ZRX/LINEO.md. Si detectas una falta de definición, infórmala antes de editar." \
      > ../W06c-dsh.stdout 2> ../W06c-dsh.stderr )
