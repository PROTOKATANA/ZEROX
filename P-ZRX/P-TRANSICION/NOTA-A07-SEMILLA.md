# Nota A-07 — sesgo del minero del terminal sobre la semilla PoT del corte

**Estado:** **derivación** del director, **sin instrumento**; alimenta `D-ZRX/IPA-ZRX.md` A-07 y
la interfaz `derivar_semilla` de `CONTRATO-v0.md` §8. **Fecha:** 2026-09-26. **Firma:** Claude.
Nada de esta nota es regla ni parámetro; la comprobación corresponde a una orden futura (T03).

## 1. El problema

TRN-08 hace que la semilla del flujo PoT tras el corte dependa de la historia hasta el terminal
`T`. Quien mina `T` conoce la semilla antes que nadie y puede **publicar o callar** su bloque:
callar le permite seguir buscando otro terminal hermano con una semilla distinta. El archivo ya
advertía, sin validar, que «una pata de PoW pequeña la domina un Estado y entonces controla la
entropía del ancla» (`archivo/P-ZRX/T-ZRX/AGUJEROS-Y-SOLUCIONES.md`, §«PoW en lugar del VDF»).
`RFT-08` no se hereda sin más: aquí cada reintento cuesta un bloque PoW válido.

## 2. Modelo mínimo (supuestos explícitos)

- Adversario con fracción `h` del hash PoW; honestos `1 − h`; tiempo medio entre bloques `T_pow`.
- El terminal es el primer bloque de su rama que cumple TRN-04 a cierta altura `H*`.
- El adversario valora una semilla por su ventaja en los primeros slots (retos que favorecen sus
  parcelas o un ploteo parcial preparado). Evaluar una semilla exige conocer los retos, que salen
  del flujo PoT.
- `τ` = duración nominal de un slot; `ρ` = cociente entre la velocidad PoT del adversario y la
  nominal (`ρ ≥ 1`; `ρ_max` depende del hardware, `RFT-12`, `R-ZRX/LEGADO/reloj/ESTADO-RELOJ.md`).

## 3. Candidatos y lo que cada uno deja

**S1 · `semilla = H(T)`, retos desde el slot 1.** El adversario que encuentra un candidato lo
evalúa casi en el acto. Mientras calla, compite con los honestos por el siguiente hermano: el
número esperado de candidatos propios antes del primero honesto es `h/(1−h)` **[derivación,
carrera de Poisson]** (0,5 con `h = 1/3`; 1 con `h = 1/2`; sin cota cuando `h → 1`). Sesgo pequeño
para `h` pequeño, **total** para un adversario con mayoría de hash. Coste por candidato
descartado: la recompensa de ese bloque.

**S2 · Semilla desde un ancla anterior `A = T − K`.** Traslada la molienda al minero de `A` y da a
**todos** `K` bloques de antelación sobre los retos. Con retos conocidos horas antes, el ataque del
sembrador (ploteo parcial dirigido a retos conocidos, `archivo/P-ZRX/P-SEMBRADOR/`, `P-INTENTO`)
gana tiempo de preparación. **Empeora** un ataque conocido para mejorar otro; no se recomienda sin
medirlo.

**S3 · Semilla retardada: `semilla = PoT^D(H(T))`, retos solo tras `D` slots de flujo.** Para
evaluar un candidato, el adversario necesita `D·τ/ρ` de tiempo secuencial. Si

    D · τ / ρ_max  ≫  T_pow / (1 − h)                                  (A07-1)

los honestos habrán publicado un terminal mucho antes de que el adversario sepa si el suyo le
conviene: callar para evaluar le cuesta el candidato sin información útil. Es el uso de un VDF como
baliza de aleatoriedad no manipulable que motiva la literatura de VDF (Boneh, Bonneau, Bünz,
Fisch, *Verifiable Delay Functions*, CRYPTO 2018, que cita «public randomness beacons» entre sus
aplicaciones **[fuente]**); la desigualdad concreta es **[derivación]**.

**Lo que S3 no cierra [derivación]:**
- Un adversario que **publica tarde** un terminal propio ya evaluado compite por FC-3 con peso
  PoST: solo gana si además tiene más peso PoST desde el corte, es decir, si ya domina la fase
  PoST. `C-FIN-01` lo acota para los nodos en línea.
- `ρ_max` no está acotado frente a un adversario con hardware especializado: (A07-1) depende de
  una cifra de hardware (`RFT-12`). Elegir `D` grande retrasa el primer bloque PoST `D` slots.
- La mayoría de hash sigue controlando qué rama PoW llega al terminal; S3 solo quita la
  **información** para elegir entre candidatos, no el control del prefijo.

**S4 · Entropía externa fijada antes del lanzamiento** (`C-FLU-06` antiguo). Evita la molienda
del terminal, pero la entropía es conocida por todos desde el principio ⇒ mismo problema que S2
con antelación máxima, salvo que se combine con S3.

## 4. Hipótesis de trabajo para la orden T03 (no decisión)

Candidato a evaluar primero: **S3** (con `D` como símbolo), comparado con S1 y S2 bajo el mismo
adversario `(h, ρ, espacio)`. Métricas: ventaja del adversario en peso PoST durante los primeros
`N` slots; probabilidad de reversión del terminal; coste en recompensas descartadas; retraso del
primer bloque PoST. Contraejemplo que la refutaría: una estrategia de retención con evaluación
parcial (p. ej. prefijo del flujo PoT) que obtenga ventaja sin violar (A07-1).

## 5. Qué hace falta para la orden

- Oráculo T01 superado (contabilidad y selección de la transición).
- Valor de `ρ_max` por clase de hardware (IPA B-02) — sin él, (A07-1) se evalúa como curva.
- Modelo de ventaja de un conjunto de retos conocidos para un plotter real (IPA B-09, D-02).
