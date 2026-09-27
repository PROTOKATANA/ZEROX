# REVISIÓN W06d7 — FC-3 en el nodo: varios terminales con sufijo PoST, selección por peso PoST

**Revisor:** Claude (director). **Fecha:** 2026-09-27 (≈ 06:54). **Ejecutor:** subagente Sonnet, único,
04:57–06:53. Evidencia: `resultados-W06d7/`; ejecuciones reales en `deepseek/W06d7/run/`. **Veredicto:
SUPERADO, con un límite que se corrige en SL-4b2. Migrada** por parche (7 rutas; base sin cambios desde
`39519aa`; 7/7 huellas; crates idénticos a la zona; `Cargo.*` sin cambios).

## Qué queda

`zx-cadena` guarda un `DagTerminal` (GHOSTDAG completo) por terminal candidato con sufijo PoST (tope 8,
`ErrLimiteTerminales`); un bloque con padres de dos terminales es inválido (`ErrTerminalAmbiguo`, I-4); el
terminal seleccionado se recalcula por FC-3 (mayor `blue_work` de la virtual; sin sufijos, mayor trabajo PoW) con
el desempate `comparar_terminal` del motor (ahora público, mismo comportamiento) y `C-FIN-01` (no se cambia si el
sufijo seleccionado abarca `≥ F_slots` slots, leído en `recalcular_seleccion`). El nodo tiene un servicio PoT de
verificación **por terminal**.

## Resultado

| Paso | Resultado |
|---|---|
| V1 | I-3 por propiedades: 2 y 3 terminales, sufijos distintos y **empate exacto**, 200 órdenes cada uno: mismo terminal, punta y estado |
| V2 | PoST más pesado gana con menos PoW; mezcla de terminales inválida; `C-FIN-01` bloquea y permite; noveno terminal ignorado; reinicio conserva la selección |
| V3 | T01 v0.5 y T04 v0.6, 0 discrepancias |
| V4 (E-6b real) | **Superado en 2 repeticiones**, ganador distinto en cada una (el calculado antes de reunir) |
| V5 (V6(b) real, mismo terminal) | **Superado en 2 repeticiones** (aislamiento ≥ 27 slots) |
| V6 | Regresión: tres nodos y nodo tardío (escala reducida: 62 bloques) |
| V7 | `fmt`, `clippy -D warnings`, **829/0/5**, guardianes |

El test de empate encontró un fallo real del código nuevo (selección recalculada antes de marcar el bloque
válido: I-3 roto con empates), corregido. La primera «repetición 2» de V4 reutilizó puertos de la 1 y quedó
contaminada; el ejecutor lo detectó (hash idéntico imposible) y la repitió limpia.

## Límites

1. **El productor no cambia de terminal en caliente** dentro del bucle de régimen (la decisión 5 lo pedía): en
   V4/V5 la reunión ocurre tras parar la producción. Sin corregir, un nodo seguiría produciendo en la rama
   perdedora tras una reunión con producción en marcha (no es un fallo de seguridad: sus bloques no desplazan
   la selección de los demás mientras su rama pese menos). **Se corrige en SL-4b2, paso 0** (toca el mismo bucle).
2. Sin oráculo multiterminal independiente (T04-E, IPA); coste del tope de 8 terminales sin perfilar.
