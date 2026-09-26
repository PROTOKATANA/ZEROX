# ORDEN-RI-2 — Revisión independiente del código de W05b3–W06d1 (estado DAG, almacén, productor, nodo)

- **ID:** RI-2 (dos revisores en paralelo: **RI-2a** y **RI-2b**). **Fecha:** 2026-09-26. **Director:**
  Claude. **Ejecutor:** subagentes Claude Sonnet.
- **Motivo:** IPA E-11: «W06 en adelante con revisor independiente en cada orden de código». El código
  migrado desde RI-1 (W05b3, W06a, W06a-B, W06a-C, W06b, W06d1) no ha tenido revisor independiente.
- **Zona escribible:** `/home/katana/zeo/ZEROX/deepseek/RI-2a/` o `/home/katana/zeo/ZEROX/deepseek/RI-2b/`
  (la tuya). **Nada** fuera de ella: ni `crates/`, ni `P-ZRX/`, ni git.

## Alcance

| Revisor | Código (en la raíz, commit `4042821` o posterior) | Contratos |
|---|---|---|
| **RI-2a** | `crates/zx-cadena/` (estado del DAG, reorganización y undo, virtual, GHOSTDAG en la cadena, `max_padres`, identidad) y `crates/zx-consensus/src/transicion/fusion.rs` (correcciones RI-1a) | `P-ZRX/P-DAG/CONTRATO-ESTADO-DAG-v0.md` (ED, IE, RD), `P-ZRX/P-TRANSICION/CONTRATO-v0.md`, `P-ZRX/P-FORMATO/FORMATO-v0.md` |
| **RI-2b** | `crates/zx-storage/` (atomicidad, integridad, repetición), `crates/zx-post/src/{productor_regimen.rs, servicio_pot.rs}` y `crates/zx-node/` (tubería de admisión, hilos, reinicio, reconstrucción del PoT, registro, CLI, negativa fuera de `Red::Dev`) | `P-ZRX/P-NODO/PLAN-W06.md` (D-N03′), `P-ZRX/P-NODO/ORDEN-W06b.md`, `ORDEN-W06d1.md` (con «Relanzamiento»), `P-ZRX/P-DAG/DECISIONES-W05.md`, `P-ZRX/P-RED-DEV/PERFIL-DEV-v0.md` |

**Excluido (ya conocido):** coste de admisión GHOSTDAG no acotado (IPA B-12); reinicio sin instantáneas
(E-10); testigos PoW no comprometidos en la cabecera (REVISION-W06b); prueba de reinicio intermitente
(REVISION-W06a-C, en corrección en W06d2); la red (W06d2, en curso); mecanismos «no activos en 0.0.1».

## Qué buscar

Lo mismo que RI-1 (`ORDEN-RI-1.md` §«Qué buscar»), más: estado que diverge entre nodos según el orden de
llegada; undo inexacto tras reorganización profunda; ventanas en las que un fallo deja el almacén y
`zx-cadena` desalineados; reconstrucción del PoT tras reinicio que acepte salidas no verificadas; doble
firma posible tras reiniciar; cualquier atajo de desarrollo (fixture, oráculo) que haya quedado en la ruta
de producción; y tests que no prueban lo que dicen.

## Método, evidencia y entregable

Como RI-1: cada hallazgo con archivo y línea, regla, escenario concreto, gravedad y **CONFIRMADO** (solo
si lo reprodujiste en una copia en tu zona, con `CARGO_TARGET_DIR` y `CARGO_HOME` en la zona, `--locked`,
como mucho 4 hilos, comando y salida literal) o **PLAUSIBLE**. **No lances subagentes ni forks.** Prohibido
Python; sin credenciales. Presupuesto: 2 h. Entregable `deepseek/RI-2a/INFORME.md` (o `RI-2b`): tabla por
gravedad, detalle, y lista de lo leído entero y lo muestreado. Si no hay nada grave, dilo; no rellenes.
