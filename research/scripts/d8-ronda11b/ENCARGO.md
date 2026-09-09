# Ronda 11b (D8) — Sensores de eclipse y reglas de red: cuánto tarda en detectarse, con qué falsas alarmas

**Lee primero:** `research/scripts/METODO-AGENTES.md` (obligatorio; sin presupuesto de tiempo, resultado completo). Luego:
`research/dag-poas-mitigaciones-cuatro-riesgos.md` §2 (E1, E2, E3 y la tabla de Bitcoin Core) ·
`research/dag-poas-ancla-de-orden-auditoria-7.md` (A3, eclipse instrumentado: 77 % inválidos) · `SPEC.md` C-NET-05, C-NET-14,
C-NET-19, C-NET-20 · `/home/katana/zeo/NODOS/ZEROX/DECISIONES.md` §19 (atadura sello-slot `|timestamp − (T0 + slot·σ)| ≤ B`) ·
Kaspa `/home/katana/zeo/fuentes/rusty-kaspa/components/addressmanager/src/lib.rs:418-460` (pesos por `PrefixBucket`) y
`kaspad/src/args.rs:115-116` (8 salientes, 128 entrantes) · Autonomys `/home/katana/zeo/fuentes/subspace/crates/sc-proof-of-time/src/source/gossip.rs:30,576-600`
(PoT «viejo» y «demasiado futuro», 10 slots) · Heilman et al. 2015 (`https://eprint.iacr.org/2015/263.pdf`; descárgalo a
`research/fuentes/heilman2015-eclipse.pdf` y extrae el texto) · devwiki de Bitcoin Core «Addrman and eclipse attacks».

**Contexto.** Bajo PoST el atacante que eclipsa a un nodo **no puede falsificar el PoT**: solo retenerlo, retrasarlo, o dejarlo
pasar y filtrar los bloques honestos. Eso permite dos sensores que Bitcoin no tiene: (E1) el PoT recibido va por detrás del
reloj de pared más de `B`; (E2) llegan `α·λ` bloques por slot en vez de `λ = 1`. El diseño hoy solo tiene diversidad por
prefijo (C-NET-20). Constantes: `λ = 1 bloque/s`, `τ = 1 s`, `S_max = 150 s`, `k = 30`, `Δ ≈ 4 s` nominal.

## Puntos

**A · El ataque, cuantificado en nuestro diseño.** Modelo de eclipse: el atacante controla las 8 salientes y las entrantes
de la víctima. Tres variantes: (i) retiene el PoT (la víctima se queda sin slots); (ii) deja pasar el PoT y filtra todos los
bloques honestos; (iii) deja pasar el PoT y los bloques honestos con retraso `E` (la variante de D8 A3). Para cada una: qué ve
la víctima, qué bloques suyos son válidos (R-FIN-1a/`S_max`), y qué puede hacerle el atacante (doble gasto contra la víctima
como comerciante; robar sus bloques).

**B · Sensor E1 (reloj).** Con la atadura sello-slot y un reloj de pared con deriva `±ε`: ¿qué `B` da falsas alarmas
`< 1/año` con la distribución real de retrasos honestos (usa `Δ` con cola: modela `Δ ~` lognormal con p99 ∈ {8, 16} s, hipótesis
declarada) y qué tiempo de detección da para (i)? ¿Qué pasa si el timekeeper cae de verdad? (E1 no distingue eclipse de
caída: escribe la regla que sirve para las dos).

**C · Sensor E2 (tasa).** Bloques por ventana `W ∈ {30, 60, 120, 300} s` con `λ = 1` (Poisson; y con la varianza real del DAG si
`r9a_lib.py` la da). Umbral `n_min(W)` con falsas alarmas `< 1/año`; tiempo de detección para (ii) con `α ∈ {0; 0,10; 0,33}`;
y para (iii) con `E ∈ {20, 60, 200} s`. 12 semillas donde haya simulación.

**D · Eclipse clásico contra el gestor de direcciones de Kaspa.** Con 8 salientes elegidas por `PrefixBucket` y la tabla de
direcciones, ¿cuántas IP en cuántos prefijos necesita el atacante para capturar las 8 con probabilidad 50 % / 90 %? Reproduce
la cuenta de Heilman para Bitcoin (tabla `tried`, 8 salientes) como control, y aplícala al esquema de Kaspa. Después, el
efecto de cada contramedida de Bitcoin Core (feeler, test-before-evict, anchors, block-relay-only, límite de ADDR) sobre esa
probabilidad, con fuente; donde no haya número, hipótesis declarada.

**E · Texto de reglas.** Borrador de reglas C-NET nuevas (numeración provisional C-NET-23…): las contramedidas de Bitcoin Core
adaptadas, E1 y E2 como comportamiento obligatorio del nodo (MUST NOT autor, MUST alertar, MUST renovar pares), y qué hace un
comerciante (no confirmar bajo alarma). Sin tocar consenso.

**F · Entrega.** Tabla: variante de ataque → tiempo hasta detección (mediana y p99) → falsas alarmas/año → coste para el
atacante. Y lo que hay que medir en red real antes de fijar `B` y `n_min`.
