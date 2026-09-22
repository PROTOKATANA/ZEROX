# HIPÓTESIS QUE CODIFICAN LA CONCLUSIÓN — ANCLA-v0.2

Supuestos que, fijados por definición, volverían tautológico un resultado. Se listan con su
efecto y dónde se manifiestan. Obligatorios del encargo: (a), (b), (c).

1. **(a) «Cada honesto sigue un solo flujo». [OBLIGATORIO del encargo]** En 4.A la red honesta
   comparte un único flujo (los cortes se miden dentro de una época sin divergencia); el modelo
   no contempla que un honesto produzca a la vez en dos flujos. Si un honesto cubriera ambos
   flujos (4.0 dice que es racional), la dinámica de 4.B cambiaría. **Efecto:** 4.A no mide la
   auto-sostenibilidad de una partición *ya nacida*; 4.0 la analiza aparte. Cualquier conclusión
   de 4.A vale solo bajo flujo único.
2. **(b) «Prop. 7 vale dentro de cada flujo». [OBLIGATORIO]** La convergencia del orden de
   GHOSTDAG está demostrada sobre GHOSTDAG puro; el diseño añade U3″/R-FIN-5/R-FIN-8′ (laguna nº
   1 de `ancla-de-orden.md` §5, «deuda principal»). Al medir el ancla sobre el DAG de un solo
   flujo asumo que el orden converge dentro de él. **Efecto:** condiciona 4.A y 4.B (estabilidad
   del ancla y precio de la partición). Si Prop. 7 cae bajo las reglas añadidas, cae todo.
3. **(c) «La Δ es simulada, no medida en red». [OBLIGATORIO]** DMS-v0.1 usa latencias
   lognormales supuestas (mediana 80 ms, p99 500 ms) y los escalones Δ ∈ {4,10,16} son constantes
   de estrés sin correlación espacial. **Efecto:** todos los `L_mín` y `G(d)` son MS sobre ese
   modelo de retardo, no MR.
4. **«La tasa de bloque es λ=1/s con SR congelado».** En 4.A no hay dinámica de retarget; el
   retarget por flujo solo entra en 4.B.4/4.D como condición. Si el retarget en operación real
   infla la tasa (ronda 3 §7: λ_real = k/(k−2D)), las colas se mueven.
5. **«El ancla definitiva existe y es única».** Con `S_max < L` el punto fijo de §2.1 es único en
   todo lo simulado (se informa si aparece un contraejemplo); la existencia asume que la cadena
   cruza `T_j` en el horizonte (los casos sin cruce se cuentan como `G_vacío`, no se descartan).
6. **«N_obs = 12 observadores y W_obs como máximo sobre ellos».** W_obs crece con el número de
   observadores por ser un máximo; el valor publicado es el de 12 (histórico) + una celda de
   sensibilidad con 24. **Efecto:** los `L_mín` son cotas inferiores para redes con más
   observadores que discrepen de verdad.
7. **«El adversario conoce todo lo publicado al instante y los honestos no mienten sobre el
   orden»** (adversario del paper). No modela eclipse de un observador honesto concreto (fuera
   del alcance declarado en ENCARGO §7).
8. **«La entropía del flujo es función del billete, no del bloque»** (inyeccion-auditoria:24,477):
   dos bloques del mismo billete dan el mismo flujo. Por eso en 4.A el flujo no se simula
   explícitamente: el ancla es estructural y todos los bloques honestos están en el mismo flujo.
9. **«El control con fusión de 4.B reproduce el modelo del repo»** (honestos que siguen al más
   pesado con retardo Δ): la comparación entre brazos vale solo bajo ese modelo de adopción.

## ADENDA-2 — hipótesis retirada de la 4.0 (reconocida)

**«Con retarget por flujo la deriva del peso es 0 y la absorción no ocurre jamás»** fue una
hipótesis que codificaba la conclusión (constantes literales en `deriva_absorcion`) y además la
equivocada para ZEROX: la selección es por `blue_work` con `w = ⌊2^128/(SR+1)⌋`, el SR se
cancela y el peso crece ∝ al espacio que cubre el flujo. La 4.0 queda RETIRADA y sustituida por
PCO-v0.1 (`P-PUERTA/`). Se registra aquí para que no reaparezca.
