# PPP-v0.1 — ¿Existe una poda para ZEROX? Análogo PoST a los niveles de PoW (Julia, CPU)

Fecha: 2026-09-17. Ejecutor: DeepSeek en la zona aislada `deepseek/`; **validado por Claude
reejecutando y migrado el mismo día** (`PROCEDENCIA.md`). Encargo: `ENCARGO-05-poda-post.md`.
Categoría dominante: **consenso**; secundaria: **almacenamiento** (poda y disponibilidad histórica).
Vive en `veritas/consenso/poda-post-v1/`. Estado: **instrumento de estudio**; no decide ninguna
regla de consenso y no adopta `solution_distance ≤ SR/2^L` como regla (es la hipótesis que audita).

## Presupuesto de esta sesión (declarado antes de ejecutar, LINEO §7)

Máquina: `znver5`, 32 hilos lógicos, 123,4 GB RAM. Tope de LINEO: **64 GiB de RAM y 24 hilos de
cómputo**. Esta sesión declara:

- **Tests, fórmulas exactas, tablas, construcciones:** 1 hilo, < 1 GiB de RAM, cada corrida < 5 s.
- **Monte Carlo y escalado:** hasta 24 hilos, < 1 GiB de RAM, < 1 min de pared. No hay
  `deepseek/MIDIENDO` vivo (la zona estaba vacía), así que no hay convivencia que respetar.
- **Disco temporal:** ninguno fuera de `resultados/`; los artefactos suman < 2 MiB.
- Si se agota el presupuesto, checkpoint y estado **inconcluso**. No ha ocurrido.

Todo cálculo obedece a `veritas/LINEO.md`: Julia en CPU, sin Python, aritmética entera y
`Rational{BigInt}` donde el veredicto es discreto, semilla explícita, RNG por réplica, reducción
determinista, oráculo transparente antes que kernel, y validación kernel↔oráculo.

## Qué calcula

Dado el proceso real de solución PoAS (`subspace @ f8842d0`,
`subspace-verification/src/lib.rs:120-158` y `auditing.rs:236-270`) y la definición natural de
nivel `solution_distance ≤ SR/2^L`, el instrumento calcula, **de forma exacta** y por Monte Carlo
cuando corresponde:

1. `P(nivel ≥ L | válida)` como función de `SR`, de `C` (chunks auditados por s-bucket) y de `L`,
   y su comparación con la hipótesis `2^{−(L−1)}` (punto 3 del §3).
2. El efecto del **anclaje de `SR`** sobre la tasa de nivel: bloque, ventana o referencia (puntos
   1–2 del §3).
3. El **coste esperado** (sorteos, slots, espacio-tiempo) de un bloque de nivel `L` y su
   acumulación con retención (puntos 3–4).
4. La **independencia estructural nivel↔padres** por construcción explícita y por barrido, y el
   coste de moler un nivel ligado al hash de cabecera (puntos 5 y 7).
5. La **desigualdad entre historias**: dos DAG con idénticos `(slot, solution_distance, SR)` por
   bloque —por tanto idéntico certificado de niveles— y distinto `blue_work`/`blue_score`,
   reutilizando el oráculo **GDR-v0.2** (punto 7 y ATAQUE 8).
6. El **crecimiento sin poda**: `#cabeceras × mergeset_limit` a la tasa A″ de 1 bloque/s.

## Qué NO calcula (fuera de alcance, declarado)

- **No es un nodo ni un validador.** No deriva PoAS/PoT, no verifica KZG ni firmas, no construye
  el DAG real. El proceso de solución entra modelado (distancia uniforme, mínimo de `C` sorteos).
- **No audita el controlador R-FIN-13′** (ventana, bootstrap, redondeos, fusiones fuera de
  ventana): no está especificado. El efecto del retarget se entrega **como función** del cociente
  `SR_branch/SR_ref`, no con un valor fijo.
- **No mide la tasa real de aciertos** (sorteos por segundo por TiB) ni el coste real de un
  s-bucket: no hay hardware de granja. `C` y `SR` son parámetros.
- **No decide** poda, finalidad, `merge_depth` ni disponibilidad: sólo separa y dictamina los tres
  problemas del §2 del encargo.
- **No propone texto de SPEC.** Lo que sugiere una regla vive en `PROPUESTA.md`, como propuesta.

## Criterios de aceptación

1. La fórmula exacta coincide con la enumeración exhaustiva en modelo escalado (`oraculo_exhaustivo`),
   sin discrepancias.
2. El Monte Carlo es compatible con la exacta dentro de 4σ binomiales en los niveles resolubles.
3. El nivel es independiente de los padres: 0 discrepancias en el barrido de construcción.
4. La suite (85 comprobaciones) pasa con `--check-bounds=yes`.
5. GDR-v0.2 se **reutiliza** como oráculo de `blue_work`; no se reimplementa GHOSTDAG.
6. Cada cifra publicada lleva semilla/comando/versión en `resultados/`.

## Límite declarado

Los veredictos de `INFORME.md` son sobre el **diseño actual** (SPEC 2026-09-17, cabecera plana,
`blue_work` declarado en cabecera). Que un certificado de espacio-tiempo no sea una prueba de poda
verificable **no** dice que ZEROX no pueda operar: dice que la poda de Kaspa no se hereda y que
el problema (2) queda sin resolver con los mecanismos examinados.
