# ORDEN-W06d2 — Red del nodo: validación diferida, huérfanos, sincronización y herramienta adversarial

## 1. Identidad y contexto

- **ID:** W06d2. **Fecha:** 2026-09-26. **Director:** Claude. **Ejecutor:** subagente **Sonnet** (red
  asíncrona e integración), revisor independiente después. Se congela y lanza cuando W06d1 esté migrada.
- **Zona (única escribible):** `/home/katana/zeo/ZEROX/deepseek/W06d2/`.
- **Objetivo único:** que varios `zx-node` se conecten por `zx-p2p`, difundan y validen bloques
  **antes** de retransmitirlos sin bloquear la red, resuelvan padres ausentes, sincronicen desde el
  génesis (fase PoW por localizador, DAG por padres) y penalicen lo demostrablemente inválido; y una
  herramienta adversarial separada que hable el protocolo real.
- **Pregunta falsable:** «Dos nodos conectados por la red real cruzan el corte y convergen a la misma
  punta y al mismo resumen de estado; un tercero que llega tarde sincroniza desde el génesis al mismo
  estado; cada entrada inválida de la herramienta adversarial se rechaza con su motivo sin cambiar el
  estado; y ningún bloque se retransmite antes de validarse por completo.»

## 2. Entradas

Lee íntegros: este archivo; `V-ZRX/LINEO.md` (rige todo el código: `AUTO-ZRX.md` §52);
`P-ZRX/P-NODO/PLAN-W06.md` (D-N01, D-N04, D-N05, D-N07); `P-ZRX/P-MEDICION/ESCENARIOS-0.0.1.md`
(§1 y E-5…E-8); las revisiones de W06c y W06d1; y el código migrado. Base: la raíz. Entrada
congelada: `P-ZRX/P-NODO/ENTRADA-W06d2.sha256`.

## 3. Decisiones del director

1. **Validación diferida en `zx-p2p`** (el único cambio a ese crate, con la frontera
   `zx-p2p → {zx-core}` intacta): hoy `servicio.rs` llama a `bloque_difundido` y en el mismo turno
   informa `report_message_validation_result`; con ~66 ms de PoT por bloque PoST eso para la red
   (`entrante.rs` exige métodos rápidos). Se añade un veredicto **diferido** (p. ej. `Veredicto::Diferir`
   con un identificador opaco) y un comando de `ManejoRed` para informar después `Aceptar`/`Ignorar`/
   `Rechazar`; gossipsub retiene el mensaje hasta entonces. Un veredicto que no llega a tiempo se trata
   como `Ignorar` (sin penalizar). Tests en `zx-p2p`.
2. **Nada se retransmite sin validación completa** (cabecera, PoT, PoAS, sello, padres, estado). Los
   bloques propios se difunden **después** de persistirse.
3. **Huérfanos:** un bloque con padres desconocidos no penaliza; va a un depósito **acotado** (número
   total y por par, con desalojo determinista declarado) y dispara `Peticion::Bloques` de los padres
   ausentes (como mucho `MAX_HASHES_POR_PETICION`), recursivamente hasta enlazar o agotar un límite
   declarado.
4. **Sincronización:** saludo `Estado`; fase PoW por `CabecerasPow` con localizador y luego cuerpos;
   tras el corte, recorrido hacia atrás desde las puntas del par por `Bloques`. Todo con límites
   explícitos (`zx-p2p::limites`) y sin confiar en el par: cada bloque pasa la tubería única de W06d1.
5. **Penalización:** `Rechazar` solo para lo demostrablemente inválido (formato, sello, PoT, PoAS,
   estado); `Ignorar` para lo no juzgable (huérfano, duplicado, sin presupuesto). Registro de cada
   penalización (`ESCENARIOS` §1).
6. **Herramienta adversarial** (binario aparte, p. ej. `zx-node/src/bin/zx-adversario.rs` o un crate de
   pruebas; nunca un modo del nodo): se conecta como un par más y envía lo de E-7 (PoW con nonce malo,
   PoST con PoAS, PoT o sello malos, coinbase mayor que el subsidio, ráfaga de huérfanos, operación de
   garantía repetida, mensaje sobredimensionado) y E-8 (dos bloques de la misma clave en el mismo slot,
   que **se registran** porque `C-EVP` está inactivo).
7. Pruebas en proceso con transporte TCP en `127.0.0.1` (o `MemoryTransport` si el TCP no es
   determinista en el entorno; decláralo), `N_dev` pequeño.

## 4. Verificación

| Paso | Qué | Criterio |
|---|---|---|
| V1–V2 | `fmt --check`, `clippy -D warnings --locked` | limpio |
| V3 | `cargo test --workspace --all-features --locked` | todo lo previo con su nombre + lo nuevo |
| V4 | Dos nodos desde el génesis cruzan el corte y producen ≥ 30 bloques PoST entre ambos | misma punta y mismo resumen de estado al terminar; 0 bloques honestos rechazados |
| V5 | Tercer nodo que llega tras ≥ 100 bloques | sincroniza al mismo resumen de estado |
| V6 | Partición y reunión (desconexión de un par durante ≥ 10 slots, ambos producen) | tras reunir, misma punta y estado; profundidad de reorganización registrada |
| V7 | Herramienta adversarial, cada entrada de E-7 | rechazada con su motivo, estado sin cambios, par penalizado; ráfaga de huérfanos con memoria acotada (medida) |
| V8 | E-8 (equivocación) | registrado; ningún nodo cae |
| V9 | Traza de difusión: ningún `Aceptar` antes de terminar la validación completa | comprobado sobre el registro estructurado |
| V10 | `dependencias-exactas.sh`, `frontera-crates.sh` (`zx-p2p → {zx-core}` intacta); lock sin cambios de versión | OK |

**Prohibido Python.** Presupuesto: **4 h, 8 hilos, 16 GiB**.

## 5. Entregables y límites

Patrón de las órdenes W (`ws.orig/`, `ws/` con el enlace `ws/PDF`, `cambios.patch`,
`MIGRACION.sha256`, `logs/`, `INFORME.md`, `PROGRESO.md`, `HORAS.log` con `date -Is` real). Cargo desde
`ws/` con `GIT_CEILING_DIRECTORIES`, `CARGO_HOME` y `CARGO_TARGET_DIR` en la zona. **Un solo ejecutor:
prohibido lanzar subagentes o forks.** Nada fuera de la zona; sin git; sin secretos; ningún `Ok`
ficticio. Arreglos mínimos a otros crates, uno a uno y documentados.
