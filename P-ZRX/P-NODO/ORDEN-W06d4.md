# ORDEN-W06d4 — Que tres nodos reales crucen el corte: depósitos sensibles a la rama y PoT del pasado

**LINEO (`V-ZRX/LINEO.md`) rige este código.** `AUTO-ZRX.md` §52: «LINEO rige todo el código del
proyecto: producción, consenso, red, almacenamiento…». Aplica sus reglas pertinentes (corrección, referencia
independiente, casos límite, perfiles antes de optimizar, control de recursos, reproducibilidad, trazas). El
reparto Julia/C++ es solo para cálculo de auditoría. Tres ejecutores anteriores lo leyeron mal.

## 1. Identidad y contexto

- **ID:** W06d4. **Fecha:** 2026-09-26. **Director:** Claude. **Ejecutor:** subagente **Sonnet**, único.
- **Zona (única escribible):** `/home/katana/zeo/ZEROX/deepseek/W06d4/`.
- **Motivo (`REVISION-W06d3.md`):** con tres procesos reales el terminal **nunca** se fija (altura ≈ 290 sin
  rechazos), y un bloque propio falla la verificación con `Pot(PasadoIncompleto)`. Sin eso no se cumple el
  criterio de cierre de W06 (`PLAN-W06.md` §3).
- **Pregunta falsable:** «Tres procesos `zx-node` en `127.0.0.1`, desde el génesis, fijan el mismo terminal,
  producen y verifican por red bloques PoST ajenos y convergen; un cuarto sincroniza tarde; tras una partición
  y reunión vuelven a converger; y `zx-adversario` ve rechazadas sus entradas PoST inválidas.»

## 2. Decisiones del director

1. **Primero la causa, con evidencia:** instrumenta y reproduce el caso de tres nodos hasta localizar por qué
   Φ no se cumple. **Hipótesis del director a comprobar o refutar:** el indicador local `depositada = true`
   (`crates/zx-node/src/nodo.rs`, límite declarado en `resultados-W06d3/PROGRESO.md` ≈ línea 73) no depende de
   la rama; tras una reorganización que descarta el bloque del depósito, el nodo no vuelve a depositar.
2. **Si se confirma:** el nodo decide qué depositar **a partir del estado de la punta seleccionada** de
   `zx-cadena` (garantía y `nonce_siguiente` de sus claves, salidas propias maduras que siguen vivas), sin
   indicadores locales que puedan desincronizarse de la rama. Test determinista: una reorganización forzada
   descarta el bloque del depósito y el nodo vuelve a depositar.
3. `Pot(PasadoIncompleto)` en un bloque propio: causa y corrección, con test que lo reproduzca antes del
   arreglo.
4. Después, las pruebas de extremo a extremo de `ORDEN-W06d3` §4 que quedaron sin cerrar: V4 (tres procesos,
   ≥ 60 PoST, PoST ajenos verificados por red), V5 (cuarto nodo tardío), V6 (partición y reunión en fase PoW y
   en fase PoST) y V7 (`zx-adversario` con entradas PoST contra un objetivo que haya cruzado el corte). Logs de
   cada ejecución conservados.

## 3. Verificación

`fmt --check`, `clippy -D warnings --locked`, `cargo test --workspace --all-features --locked` (todo lo previo
con su nombre + lo nuevo), `dependencias-exactas.sh`, `frontera-crates.sh`, lock sin cambios de versión; y las
pruebas de extremo a extremo del §2.4 con procesos reales. **Prohibido Python.** Presupuesto: **4 h, 8 hilos,
16 GiB**; si se agota, entrega lo hecho, lo que falta y la hipótesis vigente.

## 4. Entregables y límites

Patrón de las órdenes W; en `ws.orig/` y `ws/` solo lo necesario para compilar y probar. **Un solo ejecutor:
prohibido lanzar subagentes o forks.** Espera a que terminen tus pruebas antes de informar; genera
`cambios.patch` y `MIGRACION.sha256` como **último** paso. Nada fuera de la zona; sin git; sin secretos; ningún
`Ok` ficticio. Entrada congelada: `P-ZRX/P-NODO/ENTRADA-W06d4.sha256`.
