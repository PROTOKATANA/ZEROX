# PROCEDENCIA — ANCLA-v0.2

Instrumento ejecutado por **DeepSeek** en `P-2.1/veritas/consenso/ancla-inyeccion-v2/`, según
`P-2.1/ENCARGO.md` (v3) y sus adendas 1 y 2 (copias congeladas en `ENTRADA/`). **Validado por Claude el
2026-09-19 reejecutando y leyendo código**, y migrado aquí. **Solo cubre la PRIMERA PASADA**: 4.A «de
forma». 4.B, 4.C, 4.D y la cola honda **no se ejecutaron**.

## 1 · Qué reejecutó Claude (copia aislada, 24 hilos)

| Celda | Resultado |
|---|---|
| `hon-4` (red honesta, Δ = 4 s, 2 000 réplicas) | `w.csv` **idéntico byte a byte** |
| `hon-16` (Δ = 16 s, 2 000 réplicas) | `w.csv` **idéntico byte a byte** |
| `a3-a45` (entrega selectiva, α = 0,45) | las 600 réplicas entregadas son **idénticas** a las primeras 600 de una corrida propia de 1 000 |

Cola de `a3-a45` con 1 000 réplicas: `P(W_obs > d)` = 0,712 (d=50) · 0,112 (100) · 0,009 (150) · 0,001
(177-200) · 0/1 000 (≥ 250). Confirma `L_mín(10⁻³) ≈ 177` slots.

**No reejecutado:** la suite completa de tests, las celdas V1/V2/V3 ni los controles 9c/11c.

## 2 · Qué leyó Claude en el código

GDR-v0.2 por `include` y **sin modificar**; `entregar!` cierra la vista bajo ancestros y da la clausura de
publicación (con `assert`); `W_obs` según el encargo (último desacuerdo contra el ancla definitiva y por
pares; «sin ancla» contado aparte); el criterio de cambio con `α` existe. **No leído entero:** `kernel.jl`.

## 3 · Alcance — etiquetas estrechas que viajan con cada cifra

1. **El ancla medida es la de R-FIN-1 literal** (primer cruce sobre la cadena seleccionada del
   observador), **no** la reparada de `C-FLU-04` (cadena del virtual de la vista restringida). Que la cola
   medida gobierne también el nacimiento bajo `C-FLU-04` es **razonamiento, no medición**. La vía A2 de
   `regla-flujo-v1` (rama privada más pesada dentro del corte) **no está medida**.
2. **Δ simulada** (DMS-v0.1, latencias supuestas), no medida en red.
3. **A3 es estática**: todos los bloques del atacante al mismo observador toda la réplica. **El equilibrio
   adaptativo no está medido.**
4. **V1 con tope de 8 candidatos** (cota inferior del poder del atacante) **y ventana `[T, T+45]`**
   heredada del «45 s» histórico.
5. `0/n` son cotas superiores, no fronteras; por debajo de `10⁻³` todo es **extrapolación** de cola
   exponencial (`estimado`).

## 4 · Defectos

Su sección **4.0 (puerta) está RETIRADA** y sustituida por PCO-v0.1 (`../puerta-cobertura-v1/`): resultado
central escrito como constantes literales, modelo de peso equivocado, barrera `K` y reparto sin justificar,
«exacto-dp» inexacto, y curva de flujos por capacidad total (este último heredado de un error del encargo).
Presupuesto por celda V1 declarado ~3 min; real 13-31 min.
