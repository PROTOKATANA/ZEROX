# REVISIÓN W06d1 — `zx-node` sin red

**Revisor:** Claude (director). **Fecha:** 2026-09-26. **Ejecutor:** subagente Sonnet (relanzamiento
tras el incidente del *fork*; ejecutor único, 05:48–08:14, cierre de entregables a las 09:50).
Evidencia: `resultados-W06d1/`. **Veredicto: SUPERADO con reservas. Migrada.**

## Comprobado por el director

- `ENTRADA-W06d1.sha256` en verde. El agente se detuvo a las 08:14 esperando su propia suite en segundo
  plano y no volvió a informar; su suite terminó a las 08:41 (`logs/V3-despues2.log`): **694 pasan,
  0 fallan, 2 ignorados** (680 antes; 0 perdidos, 14 añadidos). El director detectó que
  `tests/reinicio.rs` (08:10) era posterior a `cambios.patch` y a `MIGRACION.sha256` (08:07); el
  ejecutor los regeneró sin tocar código (`sha256sum -c` en verde).
- **Migración por parche**, no por copia: `ws/` contenía toda la raíz (documentos incluidos) y copiarla
  habría pisado documentos posteriores. Base comprobada en las rutas que toca el parche; `git apply
  --check` limpio; las **24** huellas de los archivos del parche coinciden con `MIGRACION.sha256`.
- CI: paso de clonado fijado de Autonomys (`f8842d0…`, IPA E-03) y regla de frontera de `zx-node`.
  **No ejecutado en remoto** (sin push).

## Lo que demuestra (V1–V9)

Un proceso con 3 claves dev arranca del génesis, mina PoW, deposita garantía, fija el terminal (altura 30)
y produce bloques PoST en régimen que su propia tubería verifica íntegros (78 bloques, 0 rechazados, V4);
reabre tras **10 `SIGKILL`** (4 en fase PoW, 1 al cruzar el corte, 5 en régimen) sin corrupción y sigue
produciendo (V5); se **niega a arrancar** si un testigo PoW está corrupto en disco (V5b, el límite de
W06b); rechaza redes no dev antes de tocar el disco (V6) y un bloque propio alterado (V7). V8 **parcial**:
60 slots con `N_dev` real en 99,5 s (1,66 s por slot), `SR_dev` sin calibrar.

## Reservas (no bloquean la red dev; se corrigen en W06a-C)

1. **Máximo de padres 3**, no 15: `zx-cadena` fija `MAX_PADRES_ORACULO = 3` (límite del generador de
   T04) en la ruta de producción.
2. **Identidad GHOSTDAG no inyectiva:** `zx-cadena` recibe un `u64` (`IdentidadGhostdag::de_fixture`) y
   el nodo trunca la tupla `C-GD-07` a 8 bytes. Colisión despreciable en la red dev, no certificada.
3. El primer bloque tras el terminal se verifica con `ContextoTransicion` (atajo dev); un solo padre
   posible, sin elección de padre seleccionado que temer.
4. **Combinación sin probar:** la raíz tiene ahora W06d1 y W06a-B (arneses sin emulación); ninguna suite
   las ha ejecutado juntas. La primera será la de W06a-C.
5. V8: el slot real dura 1,66 s y no ~1 s: hay que medirlo en W07 con la máquina en reposo.
