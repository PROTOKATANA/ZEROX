# REVISIÓN W06d10 — penalizar al par que difunde un bloque demostrablemente inválido

**Revisor:** Claude (director). **Fecha:** 2026-09-27 (≈ 23:44). **Ejecutor:** DeepSeek, 21:43–23:43 (dentro de las
3 h). Evidencia: `resultados-W06d10/`; ejecuciones reales en `deepseek/W06d10/run/`. **Veredicto: SUPERADO. Migrada** por
parche (5 archivos y 1 test nuevo; base intacta: `ENTRADA-W06d10.sha256` verde en la raíz, `ws.orig/crates` idéntico a
la raíz; `MIGRACION.sha256` verde; los 6 archivos de la raíz idénticos a la zona).

**Motivo:** W07b E-7: los bloques inválidos difundidos por gossip se rechazaban sin penalizar al par.

- **Gossip = sincronización:** ante `Rechazar`, `zx-p2p` mantiene el `Reject` de gossipsub, desconecta al propagador con
  `ViolacionDeConsenso` y avisa al nodo (`ManejadorEntrante::par_penalizado`, con implementación por defecto) para que
  escriba `par_penalizado`. `Aceptar` e `Ignorar` nunca penalizan.
- **Loopback:** para `127.0.0.0/8` y `::1` se puntúa y veta el `PeerId` (registro acotado a `MAX_BANEADOS`, desalojo
  FIFO), no el prefijo; fuera de loopback, sin cambios. Documentado como excepción de la red local.
- **`zx-adversario`:** identidad nueva por vector de E-7; cierra la conexión de saludo antes de la ráfaga (el cupo
  `MAX_POR_PREFIJO = 3` del /24 compartido bloqueaba las identidades nuevas; hallado en el primer intento de V4).

| Paso | Comprobado por el director |
|---|---|
| V4 (E-7 × 3, semillas 101/202/303) | 4 rechazos y **4 `par_penalizado`** por repetición (`penalizados-a.txt`: 4 `PeerId` distintos del adversario), 0 ajenos, 0 desconexiones de B y C, mismo estado con el método W07d |
| V5 (falsos positivos) | 3 redes al slot 150 y una partición E-6 con aislamiento real: **0 `par_penalizado`** entre honestos |
| V6 | `logs/v6-test.log`: **883/0/6** en 84 binarios; fmt, clippy `-D warnings`, guardianes y T01/T04 verdes (informe) |
| Código | Leído el diff de `servicio.rs`, `limites_ip.rs`, `entrante.rs` y `manejador.rs`: solo `Rechazar` penaliza; la política loopback está confinada en `penalizar_peer` |

**Falta de definición bien resuelta:** `red/sync.rs` (consumidor exhaustivo de `EventoRed`) no estaba permitido; el aviso
va por un método de trait en vez de una variante nueva. Aceptado.

**Hallazgos que quedan abiertos:**

1. **V1: tres familias de `Rechazar` dependen de la vista local** y ya penalizaban en la ruta de sincronización (ahora
   también en gossip): (X1) timestamp PoW demasiado futuro, (X2) `ErrLimiteTerminales`, (X3) errores locales de
   persistencia o servicio. X1 es el grave: un nodo honesto con el reloj adelantado sería vetado. **Decisión del
   director:** las tres pasan a `Ignorar` en las dos rutas → `ORDEN-W06d10-B.md`.
2. **Observación previa a esta orden, sin cambio:** a un par **saliente** (al que marcamos nosotros) no se le conocen
   prefijos en `LimitesPorIp` y solo se le desconecta, sin puntuarlo. Se anota para la prevención del eclipse de 0.0.2
   (gestor de direcciones, IPA B-07).
3. `par_penalizado` se escribe desde el bucle de red (escritura de registro no crítica). Aceptable con la frecuencia
   actual; si el registro llega a bloquear, pasarlo a un canal.
