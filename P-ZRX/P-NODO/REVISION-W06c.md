# Revisión del director — W06c (2026-09-26)

**Veredicto: SUPERADO y migrado a la raíz** (02:50). DeepSeek, 02:31–02:48.

`zx-p2p` portado (transporte libp2p, límites explícitos, presupuesto, servicio, codec) con los
mensajes del híbrido: `BloqueRed::{Pow, Post}` con familia **explícita** en el wire (F-04, comprobado
en `mensaje.rs`), saludo `Estado` nuevo, `CabecerasPow` por localizador, protocolo `/zx-dev/1`, gossip
en `/zx-dev/bloques/{pow,post}/1`. Relé compacto no portado (declarado). Límites dev: bloque 2 MiB,
256 hashes por petición, 2 000 cabeceras por respuesta. 502 tests; integración `MemoryTransport`
10/10; fronteras de todos los crates OK (`zx-p2p → {zx-core}`); 400/400 paquetes con la versión del
lock antiguo. Base idéntica a la raíz; `MIGRACION.sha256` verificado en la raíz.

**Pendiente para W06d:** la desconexión por génesis ajeno la decide el nodo; el gossip debe
responder `Accept/Ignore/Reject` tras validar (el mensaje queda pendiente con cota); no hay tema de
transacciones (0.0.1 no lo necesita: las transacciones de prueba se incluyen por el productor).
