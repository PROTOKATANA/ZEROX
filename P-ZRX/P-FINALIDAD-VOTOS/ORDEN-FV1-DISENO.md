# ORDEN-FV1 — Capa de finalidad por votos bajo R1–R5: diseño, contrato v0 y análisis adversarial

## 1. Identidad y contexto

- **ID:** FV-1. **Fecha:** 2026-09-26. **Director:** Claude. **Ejecutor:** subagente Sonnet (diseño y
  análisis; sin código de producto; comprobaciones numéricas en Julia, **nunca** Python).
- **Zona (la única en la que puede escribir):** `/home/katana/zeo/ZEROX/deepseek/FV1/`.
- **Objetivo único:** diseñar una capa de finalidad por votos, superpuesta a PoAS + PoT + DAG, que cumpla
  R1–R5 de `P-ZRX/P-FINALIDAD-VOTOS/PROGRAMA.md`. Hay que decir qué gana y qué no frente a `C-FIN-01`
  sola, y entregar un contrato ratificable v0 sin fijar parámetros de producción.
- **Pregunta falsable:** «Existe una capa de finalidad por votos que cumple R1–R5 a la vez y en la que:
  - (a) ningún atacante cuyo peso, sumado al de los honestos apagados, sea menor que un tercio del peso
    total puede pausar ni romper el sello;
  - (b) romper el sello deja siempre firmas contradictorias de al menos un tercio del peso total,
    castigables con una garantía que crece con el peso;
  - (c) con la capa pausada, rota o sin activar, ningún nodo queda peor que con `C-FIN-01` sola;
  - (d) en marcha normal, el tiempo hasta el sello es menor que `F_slots` como función de `Δ` y del número
    de votantes.»

  Se refuta con un contraejemplo concreto a (a), (b), (c) o (d), o demostrando que dos de R1–R5 son
  incompatibles.

## 2. Entradas (leer íntegras)

**Árbol actual:**
- `P-ZRX/P-FINALIDAD-VOTOS/PROGRAMA.md` y `P-ZRX/P-FINALIDAD-VOTOS/CONTEXTO.md` (la conversación con
  Katana). Lo marcado en el contexto como «lectura del director» es hipótesis que tienes que confirmar o
  refutar, no un resultado;
- `D-ZRX/SPEC.md` (§0; §5 `C-BON`, `C-EVP`, `C-SLA`; §7; `C-BOT`) y `D-ZRX/SPEC-0.0.1.md`;
- `D-ZRX/RFT-ZRX.md` (RFT-01, 02, 06, 09, 12) y `D-ZRX/IPA-ZRX.md` (B-04, B-05, D-05, E-06);
- `P-ZRX/P-TRANSICION/CONTRATO-v0.md` (`C-FIN-01`, `F_slots`) y `P-ZRX/P-DAG/CONTRATO-ESTADO-DAG-v0.md`;
- `P-ZRX/P-DISUASION/SINTESIS.md`, `REVISION-DS2.md`, `REVISION-DS5.md`, `REVISION-DS6.md` y
  `resultados-DS2/INFORME.md` §2;
- `P-ZRX/P-SLASHING/PROGRAMA.md`, `DECISIONES.md`, `REVISION-SL1.md`, `REVISION-SL2.md` y
  `resultados-SL1/CONTRATO-EVIDENCIA-v0.md`;
- `P-ZRX/P-REGISTRO-SECTORES/ANALISIS.md` y `ENCARGO.md`;
- `R-ZRX/LEGADO/stake/MAPA.md` y `R-ZRX/LEGADO/eclipse/INFORME.md`.

**De `/home/katana/zeo/.trash/zerox/` (solo lectura; también en `git show 9681061:<ruta>`):**
- `research/dag-poas-capa-finalidad.md`: la propuesta del 2026-09-09 (reglas R-FIN-15…22). Es **hipótesis
  sin auditar**: el punto de partida, no una verdad. Sus cifras se recalculan, no se citan.
- `research/scripts/finalidad-espacio/verif_*.py`: léelos para entender el cálculo; **no los ejecutes**.
- `research/scripts/d14-sin-comite/informe.md`: la ronda que definió «comité».
- `P-ZRX/T-ZRX/LIBRO-DE-RESTRICCIONES.md`, `ESTADO-DOBLE-FARMEO.md` y `AGUJEROS-Y-SOLUCIONES.md`.
- `P-ZRX/P-SECRETO/investigacion/INFORME.md` y `P-ZRX/P-POOLS/investigacion/` (la firma a ciegas).
- `P-ZRX/P-FLUJO/propuesta/PROPUESTA-SPEC.md` (partición de flujo) y
  `P-ZRX/P-ECLIPSE/investigacion/INFORME.md`.
- Informes de `P-ZRX/P-CLAVE/` y `P-ZRX/P-PRESTAMO/`.

**Fuentes externas (lectura primaria; si el visor no lee un PDF, descárgalo con `curl` a la zona y léelo
en local):**
- FIP-0086 (F3, GossiPBFT);
- Buterin y Griffith, *Casper the Friendly Finality Gadget*, arXiv:1710.09437;
- Neu, Tas y Tse, *Ebb-and-Flow Protocols* (IEEE S&P 2021);
- eth2book, «Inactivity leak»;
- arXiv:2404.16363 (fuga de inactividad y finalización contradictoria bajo partición).

## 3. Mandato y decisiones del director (no se reabren)

1. **R1–R5 son requisitos, no orientaciones.** Cada uno se comprueba como propiedad, con demostración o
   contraejemplo. Si dos son incompatibles, se demuestra y se dice qué se pierde con cada renuncia. No se
   reinterpreta una regla para que encaje.
2. **Capa superpuesta.** No cambia quién produce, quién cobra, GHOSTDAG ni `blue_work`. Se mantiene
   `SPEC.md` §0: la garantía no da turnos ni peso de producción.
3. **`C-FIN-01` se queda como red de seguridad.** La regla que hace convivir las dos finalidades es un
   entregable. Su invariante es la condición (c) de la pregunta falsable.
4. **Pausa, no fuga.** Sin quórum, la finalidad se pausa (R3). La fuga de inactividad solo se evalúa como
   comparador, con su precio documentado (finalización contradictoria bajo partición).
5. **Castigo.** La única falta nueva es el doble voto; su definición exacta es un entregable. No se castiga
   ninguna ausencia y no hay castigo correlacionado (DS-5). La evidencia se diseña en la familia de
   `EvidenceTx`, coherente con el contrato de SL-1 y con `P-SLASHING/DECISIONES.md`.
6. **La fuente del peso no está decidida.** Se comparan tres fuentes y se recomienda una:
   - **(A) Derivado de los bloques cobrados en una ventana** (R-FIN-15 antigua). No necesita registro;
     tiene ruido, puede dejar con peso cero al granjero pequeño y es sesgable reteniendo bloques.
   - **(B) Sectores registrados con auditorías y garantía** (`P-REGISTRO-SECTORES`; F3 pondera por QAP).
   - **(C) Garantía `C-BON` (stake).** Es el comparador; cambia el sentido de §0.

   Para cada una hay que decir si cumple R1, R2 y R5 (¿hay garantía proporcional al peso que castigar?),
   cuánto le cuesta al honesto y qué puede hacer el atacante.
7. **Modelo de amenaza de Katana.** El atacante tiene recursos de Estado. Para cada ataque hay que dar el
   coste absoluto (TiB, garantía en símbolos, hardware) y decir si queda **imposible** o solo **caro**.
   «No compensa» no es un argumento.
8. **El doble farmeo no se cierra: es premisa** (RFT-01). Hay que cuantificar cuánto lo arrincona la capa:
   la ventana pasa de `F_slots` al tiempo hasta el sello, como función de `Δ` (sin medir, B-05) y del
   número de votantes.

## 4. Lo que tiene que contener

### A. Contrato v0 (reglas `FV-*`, cada una con su justificación y un caso)

1. **Fuente del peso y tabla de pesos:** función solo del pasado validado; retardo (*lookback*);
   compromiso de la tabla siguiente dentro del certificado.
2. **Quién vota:** todos los que tienen peso, o un sorteo ponderado. Admisión sin elección (R2); plazas por
   clave; si se usa prueba de vida (`W_VIVO` antigua), comprobar que no viola R1.
3. **Protocolo de acuerdo:** GossiPBFT como candidato; fases y temporizadores en función de `Δ`. Solo
   puede sellar prefijos de la cadena seleccionada y nada sobre su contenido (R4).
4. **Certificado:** contenido, esquema de firma (BLS agregada o Ed25519, con tamaños), coste de
   verificación y cadena de certificados desde génesis.
5. **Convivencia con `C-FIN-01`:**
   - regla de selección con certificado y qué manda si las dos finalidades discrepan;
   - demostración o contraejemplo de (c);
   - la «mentira permanente» (§6.1 de la propuesta antigua): qué recuperación existe si 2/3 certifican
     algo falso y si eso deja a ZEROX peor que hoy.
6. **Pausa y reanudación (R3):** qué ocurre sin quórum, cómo se reanuda y qué protege mientras tanto.
7. **Falta y evidencia (R5):**
   - definición del doble voto y formato de la evidencia;
   - ventana de admisión frente al retiro de la garantía (quien retira antes de que llegue la prueba);
   - qué se confisca y si la garantía crece con el peso. Si con una fuente de peso no crece, se declara
     que R5 no muerde con esa fuente.
8. **Activación tras el corte PoW → PoST:** peso total mínimo y garantía madura mínima para encender la
   capa; qué rige antes de activarla.
9. **Parámetros abiertos:** cada uno con su símbolo y su restricción.

Si la cadena de certificados sirve al cliente ligero, dilo en **una línea** con su condición; no lo
desarrolles.

### B. Análisis adversarial

Una tabla por atacante, con columnas: fracción `a` del peso total, fracción `o` de honestos apagados,
control de la red (sí/no), qué puede hacer, coste absoluto, si queda firmado, y si es imposible o caro.

Ataques obligatorios:
1. pausa con `a + o ≥ 1/3`;
2. doble sello con un tercio y control de la red;
3. sesgo de la tabla de pesos, reteniendo o publicando bloques y eligiendo ancla (lo que el §4.D antiguo
   no cubrió);
4. eclipse de un nodo observador;
5. partición y flujos de PoT: un certificado cruza flujos (P-FLUJO);
6. largo alcance con claves que ya retiraron su garantía;
7. **delegación del voto y firma a ciegas:** voto como servicio. Es el patrón de P-POOLS y P-SECRETO, y
   crearía un comité de hecho contra R1 y R2;
8. censura por un tercio;
9. denegación de servicio con certificados inválidos;
10. falsos positivos de R5: la misma clave en dos máquinas y el fallo común del cliente;
11. activación prematura, con poca garantía repartida tras el corte;
12. ventana residual del doble farmeo: el atacante grande en la franja aún no sellada.

Antes de proponer una pieza, contrástala con `LIBRO-DE-RESTRICCIONES.md` (R-1…R-12) y di qué restricción
toca.

### C. Comprobaciones numéricas (Julia, proyecto fijado en `deepseek/FV1/calc/`)

1. **Quórum frente a la participación honesta `p` y a `a`,** con ausencias correlacionadas por tamaño de
   clave (el error que §7 de la propuesta antigua declara).
2. **Sorteo, si se usa,** y su sesgo por elección de ancla y de tabla: recalcular §4.A y §4.D antiguos y
   declarar cualquier discrepancia.
3. **Tamaño y coste anual del certificado.**
4. **Ventana del doble farmeo** (tiempo hasta el sello frente a `F_slots`), paramétrica en `Δ`.

Semillas fijas y **no consecutivas**. Todo generador aleatorio lleva una **tabla de cobertura por tipo de
caso, con mínimos**. Hay que reproducir primero los números antiguos como comprobación cruzada.

### D. Informe

- Respuesta a la pregunta falsable.
- Tabla R1–R5, con uno de tres estados por regla: se cumple, se cumple con condición o falla (con el
  contraejemplo).
- Tabla comparativa de las tres fuentes de peso.
- Qué mejora frente a `C-FIN-01` sola y qué no, con el residuo del doble farmeo explícito.
- Decisiones para Katana, con opciones, coste de cada una y recomendación.
- Qué no está medido (`Δ`, `p` real) y cómo se mediría en la red dev.

## 5. Entregable y límites

Entregables, todos en la zona:
- `deepseek/FV1/CONTRATO-FINALIDAD-VOTOS-v0.md`;
- `deepseek/FV1/INFORME.md`;
- `deepseek/FV1/calc/` (`Project.toml`, `Manifest.toml`, `run.jl`, tests y resultados);
- `deepseek/FV1/HUELLAS.sha256`.

Límites:
- Solo lectura fuera de la zona. **No lances subagentes ni forks.** Sin git, sin Python (leer los `.py`
  antiguos sí; ejecutarlos no) y sin credenciales.
- Etiqueta cada afirmación: [P] fuente primaria leída, [S] secundaria, [D] derivación propia, [H]
  hipótesis. Ninguna cifra de memoria.
- Presupuesto: **4 h de reloj** y cómputo ligero (hasta 4 hilos, minutos). Si se agota, entrega lo hecho
  y lo que falta.
