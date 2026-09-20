# CONTRATO — ANCLA-v0.2 · P-2.1 v3

**ID:** ANCLA-v0.2 (estilo de ID del repo). **Categoría propuesta:** `consenso` (dominante);
`seguridad` y `finalidad` secundarias. **Zona:** `P-2.1/veritas/consenso/ancla-inyeccion-v2/`.
**Estado:** instrumento de estudio; ninguna regla de consenso se decide aquí.

## Qué calcula

1. **4.0 (PUERTA, analítico-exacto, sin red):** condición de cobertura racional de un segundo
   flujo como función del coste marginal; curva `S_max_racional(capacidad)`; deriva y tiempo de
   absorción de la diferencia de peso entre dos flujos con fracción `c` de cobertura dual
   (barrido `c ∈ [0,1]`); recálculo del contraste histórico de la ronda 3 bajo R-FIN-4/5.
2. **4.A:** `G(d) = P(W_obs > d)` en rejilla de 1 slot, red honesta (Δ nominal DMS-v0.1 y
   escalones Δ ∈ {4,10,16} s) y bajo adversario (V1 con clausura de publicación, V2 cadena
   privada barriendo P, V3 = V2+A3 declarada no-óptima, A3 entrega selectiva a un solo
   observador); `W_steer` (menú de anclas, control positivo contra ronda 9c); `L_mín(ε,α,Δ)`
   para ε ∈ {1e-3, 1e-6, 1e-9} (1e-3 medido; 1e-6/1e-9 extrapolado con etiqueta `estimado`).
3. **4.B:** partición de red de duración `P_dur` cruzando la activación, barriendo `P_dur` y el
   reparto de espacio; contabilidad del daño (bloques de otro flujo = pérdida entera; rojo_k =
   cobra coinbase); control con fusión (reproduce 17,3-24,4 s / huérfanos 1,81-2,33 %); regla de
   selección entre flujos como variante con precio (verificaciones ajenas imponibles, 96,1 ms/slot
   y 1,561 s/slot); cancelación de SR bajo retarget por flujo (R-FIN-13′); control negativo
   `P(split) ≤ G(L)`.
4. **4.C:** proceso de ramificación con selección: tasa de la mejor rama privada y
   `α*(S,m,I,L)`; barrido S ∈ {1,2,4,8,16,24}, I ∈ [300, 5000] slots, α ∈ [0,25; 0,49],
   m hasta 151; resolución por argumento de las dos hipótesis en disputa (cota de unión vs
   BDK ec. 39; v_gain vs g_steer).
5. **4.D:** mapa analítico (ρ, L, I, F) con W_obs/W_steer medidas: R-FIN-14(f)/(h) corregida,
   `S_max < I` y `S_max < L`, lookahead, `W_RETARGET ≥ 3083`, pinza W/κ corregida (1 198/2 488 s),
   las dos semánticas de F (2 h provisional vs C-REORG-07 3,33 h fail-stop + techo de archivado),
   L vs F (dos ramas con coste).

## Qué NO acredita (ENCARGO §7, completo, + instrumentales)

- **Prop. 7 bajo U3″ + R-FIN-5 + R-FIN-8′** — «deuda principal»; este encargo la supone *dentro de
  cada flujo* (va a `HIPOTESIS-…md`). No demuestra convergencia del orden en el DAG completo con
  dos flujos.
- `c_a = c_h` en unidades de índice (±1,2 puntos sobre cualquier umbral de 4.C), el empalme
  `φ_c ⊗ δ`, y `3k` como ventaja real.
- **Δ real de red**: DMS-v0.1 es simulada con latencias supuestas (lognormal, mediana 80 ms,
  p99 500 ms), no una medición. Los escalones Δ ∈ {4,10,16} son constantes de estrés.
- `ρ_max` real (1,5-2,5× es estimación).
- Retarget dinámico: en 4.A las tasas son fijas (λ=1/s, reparto por α); el retarget solo entra en
  4.B.4 y 4.D como condición. La unidad es la época/réplica con SR congelado.
- Fuera de alcance (catalogados en ENCARGO §7): soborno del ancla, sembrador, ρ>1 como adversario
  simulado, parásita + copias de billete, retención del propio PoT, régimen >15 puntas.
- Ninguna cifra es parámetro de producción.

## Presupuesto declarado ANTES de ejecutar

| Recurso | Tope declarado | Observación |
|---|---|---|
| Hilos | ≤ 24 de cómputo (8 lógicos quedan al sistema) | escalado medido 1…24; se conserva el ganador |
| RAM | ≤ 8 GiB (techo del repo: 64 GiB) | pico estimado: 24 hilos × ~2 réplicas × ~150 MB |
| Disco | ≤ 2 GiB en la zona | checkpoints + resultados CSV |
| Tiempo | **~5 h de pared** en total, en lotes con checkpoint | 4.A ≈ 2,5 h; 4.B ≈ 1 h; 4.C ≈ 30 min; 4.0/4.D minutos |

Si se agota cualquiera: checkpoint, estado **inconcluso**, semilla/parámetros/configuración y
entrada mínima reproducible de cada fallo (LINEO §7). Un timeout no es evidencia de falsedad.

## Reglas del contrato

- Ancla SIEMPRE sobre `past ∩ {slot < t_j}` con punto fijo (ENCARGO §3.1); vista de observador
  cerrada bajo ancestros; V1 con clausura de publicación; GDR-v0.2 sin modificar (por include);
  nada de Python; unidad estadística = época/réplica; 0/n nunca frontera (3/n al 95 %,
  Clopper–Pearson); censurados/vacíos informados aparte; extrapolación etiquetada `estimado` y
  contrastada contra `r = (√((1−α)λ) − √(αλ))²` = 0,0572 a α=1/3; criterio de aceptación
  (el resultado cambia con α) reimplementado en Julia y declarado; desempate declarado
  (C-ORD-01: `(bw, sd, id)` ascendente para mergeset/rank, SP_ZEROX para el padre seleccionado);
  todo por `run.jl` con semilla y entorno fijados; `./veritas/julia.sh` siempre.
