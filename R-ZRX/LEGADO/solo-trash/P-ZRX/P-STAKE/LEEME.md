# P-STAKE — castigo y finalidad con lo ganado en juego

**Dos encargos en este directorio. Se ejecutan en orden, uno detrás de otro.**

| Orden | Encargo | Pregunta | Escribe en | Sello de entrada |
|---:|---|---|---|---|
| **1** | [`PROMPT-1.md`](PROMPT-1.md) | Las cuatro condiciones del castigo (E, A, R, C) para la **doble firma de bloques**, con las recompensas retenidas como colateral | `investigacion-1/` | `ENTRADA-1.sha256` |
| **2** | [`PROMPT-2.md`](PROMPT-2.md) | **Finalidad por votos**, con lo ganado en juego: que ninguna conducta oculta afecte a lo finalizado sin dejar evidencia | `investigacion-2/` | `ENTRADA-2.sha256` |

**`PROMPT-2` depende de `PROMPT-1`:** lee `investigacion-1/` y reutiliza su diseño de E, A, R y C
para castigar votos contradictorios. Su primer paso comprueba que `investigacion-1/INFORME.md`
existe; **si no, se detiene**.

**Recomendación de Claude:** validar `PROMPT-1` **antes** de lanzar `PROMPT-2`. Si no se hace,
`PROMPT-2` trabaja sobre resultados sin validar, y está avisado de que debe tratarlos como entrada y
no como verdad.

**Base común, de solo lectura para los dos:** [`MAPA.md`](MAPA.md) — el mapa previo de mecanismos PoS
verificados en fuente primaria (Filecoin, Ethereum, Casper, Decred) cruzados con los agujeros de
ZEROX.

**Origen:** petición de Katana del 2026-09-24. Estado de las decisiones en `MAPA.md` §3: Katana se ha
retractado de la prohibición de staking **para recompensas ganadas**; **la de comités sigue
vigente**, y `PROMPT-2` la evalúa sin revocarla.
