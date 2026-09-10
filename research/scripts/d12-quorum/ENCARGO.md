# Ronda 12 — Finalidad por quórum de soluciones como gadget sobre el DAG, frente a la capa estilo Filecoin

**Lee primero:** `research/scripts/METODO-AGENTES.md` (obligatorio; sin presupuesto de tiempo, resultado
completo, LAGUNA nunca por falta de tiempo).

**Fuentes primarias, ya en local:**
- `research/fuentes/hotpow.txt` — Keller y Böhme, *HotPoW: Finality from Proof-of-Work Quorums*. **La teoría
  a portar.** §3 (proceso de trabajo, ATV, k-quorum, probabilidad de ambigüedad, Teorema 1), §4 (protocolo:
  votos, quórums, elección de líder, regla de preferencia, commit de tres fases de HotStuff), §5 (evaluación:
  latencia, churn, ataques de consistencia y censura; el resultado de que un atacante al 1/3 se lleva el 42 %
  de los bloques con retención de votos).
- `research/fuentes/cap-adaptividad-finalidad.txt` — Sankagiri, Wang, Kannan, Viswanath, *Blockchain CAP
  Theorem Allows User-Dependent Adaptivity and Finality*. **El marco correcto**: cadena más larga con
  checkpoints y **dos reglas de confirmación**, y el usuario elige. Es la forma de convivir con el teorema.
- El teorema de imposibilidad: Lewis-Pye y Roughgarden, *Resource Pools and the CAP Theorem*
  (`https://arxiv.org/pdf/2006.10698`, descárgalo a `research/fuentes/lewispye-roughgarden-cap.pdf` y extrae
  el texto con `pypdf`; `pdftotext` no está instalado). **Ningún protocolo es a la vez adaptativo y con
  finalidad** en el escenario sin tamaño conocido y parcialmente síncrono. Lee el enunciado exacto y sus
  hipótesis: es la cota de lo que se puede pedir.
- `research/dag-poas-capa-finalidad.md` — **la alternativa contra la que compites**, R-FIN-15..22, estilo
  Filecoin F3, sin auditar. Scripts en `research/scripts/finalidad-espacio/`.
- El diseño vivo: `research/dag-poas-ancla-de-orden.md` §2 (R-FIN-1..14; **NO editar**), y
  `research/dag-poas-catalogo-problemas-ataques.md`.
- Instrumentos: `research/scripts/rendimiento/verif_quorum_soluciones.py` (mi cálculo de partida, a auditar),
  `research/scripts/d9-ronda9a/r9a_a3_frontera.py` (`prev`/`union10`), `research/scripts/verif_frontera_vs_F.py`.
- Código: Kaspa `/home/katana/zeo/fuentes/rusty-kaspa @ c338d495`; Autonomys `/home/katana/zeo/fuentes/subspace @ f8842d0`.

**Constantes vigentes:** `λ = 1 bloque/s`, `τ = 1 s`, `k_GHOSTDAG = 30`, `S_max = 150 s`, `N_CORTO = 1 000`,
`N_LARGO = 21 600`, `ZONA_LIBRE = 100 000 B`, umbral operativo 33 %, frontera 44,6 % con `F = 2 h`,
`Δ` **sin medir** (4 s supuesto; a 16 s la frontera baja a 38,3 %). Riesgo de reversión hoy a `α = 0,33`:
1,5e-6 a los 10 min, 7,1e-36 a los 30 min.

**Idea a evaluar.** Cada solución de espacio da **un voto**; `k` votos por el mismo bloque de la cadena
seleccionada forman un certificado de finalidad. Dos certificados en conflicto exigen `2k` soluciones, luego
la probabilidad cae exponencialmente en `k` (mi cálculo: 1,3e-12 con `k = 64`, quórum en ~64 s, certificado
agregado < 60 B). **Sin tabla de poder, sin suponer quién está encendido, sin dinero en juego.**

---

## Puntos

**A · Control positivo, antes de nada.** Reproduce dos cosas del paper con su propio instrumento: la POA de
Bitcoin (`k = 1`, `λ = 0,1`) debe dar 0,2642, y el Corolario 2 (POA en el tiempo esperado de quórum es
independiente de `λ`). Después audita `verif_quorum_soluciones.py`: ¿es correcta mi lectura de que
`POA(k) = P[Poisson(k) ≥ 2k]`, y es correcta la extrapolación a nuestro `λ`? Declara mis errores si los hay.

**B · La composición con el DAG, que el paper NO hace.** HotPoW **sustituye** el consenso; nosotros lo
queremos **encima** de GHOSTDAG con el ancla por índice de PoT. Hay que responder, con citas al código de
Kaspa y a R-FIN-1..14:
1. ¿Sobre qué se vota? Candidatos: un bloque de la **cadena seleccionada**, el ancla `I_j`, o un punto de
   `blue_work`. Cada uno tiene un problema distinto: la cadena seleccionada cambia con el coloreado; el ancla
   ya es objeto de *steering* (rondas 3-10).
2. ¿De dónde sale el voto? La solución de un bloque **ya existe** y ya está firmada (`C-HDR-03/04`). ¿Vale el
   propio bloque como voto, o hace falta un mensaje aparte? Si vale el bloque, ¿en qué se diferencia esto de
   la profundidad de confirmación que ya tenemos —que es exactamente la pregunta que decide si el gadget
   añade algo o es un cambio de nombre?
3. ¿Qué pasa con la regla de selección? R-FIN-7 dice que no se reorganiza por debajo de `F` y que una punta
   que lo exija se **ignora**. Un certificado tiene que **adelantar** la finalidad y no poder retrasarla ni
   invalidar nada (es R-FIN-18 en la otra propuesta): escribe la regla y demuéstralo.
4. ¿Y con R-FIN-5, un flujo por PoT? Un certificado cruza flujos; un bloque no puede referenciar otro flujo,
   pero un certificado no es un bloque.

**C · El umbral, con nuestro `Δ`.** El paper afirma `α < 1/2` y mide que a `α = 1/3` un atacante que retiene
votos se lleva el 42 % de los bloques. Nuestra frontera de flujo único ya es 44,6 % y cae a 38,3 % con
`Δ = 16 s`. Preguntas: (1) ¿qué le hace el retardo de red a la unicidad del quórum —dos honestos con vistas
distintas pueden votar valores distintos sin ser atacantes?; (2) ¿cuál es el umbral **compuesto** del sistema
DAG + gadget, que no es el mínimo de los dos ni el del paper?; (3) reproduce su ataque de censura por
retención de votos en nuestro régimen (`λ = 1/s`, `Δ ∈ {4, 8, 16} s`) y di qué fracción de certificados
controla un atacante al 33 %.

**D · La parada bajo ataque, que es el teorema.** Lewis-Pye y Roughgarden dicen que se parará; la pregunta no
es si, sino **cuándo y cómo se recupera**. Mide, para `α ∈ {0,10; 0,25; 0,33; 0,40}` y `k ∈ {32, 64, 128}`:
fracción de instancias que no cierran quórum, tiempo hasta que vuelve a cerrarse, y si la cadena sigue
avanzando entretanto (debe: la finalidad lenta de R-FIN-7 es el suelo). Compara con lo medido de la capa
estilo Filecoin (§4.A de `dag-poas-capa-finalidad.md`: se para el 41 % de las instancias a `α = 0,33`).

**E · Cara a cara con la capa estilo Filecoin.** Tabla con las dos, en las mismas condiciones:
finalidad conseguida; umbral; qué se para y cuándo; estado por nodo; bytes por año; CPU por nodo;
criptografía que obliga a adoptar; supuestos sobre quién está encendido; superficie de ataque nueva;
y **qué hay que demostrar antes de escribirla**. Recomendación con etiqueta, y la condición que la cambiaría.

**F · El coste real del certificado.** Mi cifra de «< 60 B agregado» supone agregación. Sin ella son `k`
firmas. Calcula: bytes por certificado y por año a las cadencias razonables; CPU de verificación por nodo;
si obliga a BLS12-381 como la otra propuesta (y entonces la ventaja criptográfica desaparece) o si hay una
salida —por ejemplo que las `k` firmas ya estén en los `k` bloques y el certificado solo las referencie.
**Este punto puede decidir la comparación entero.**

**G · Lo que el gadget NO arregla.** Enumera qué problemas del catálogo siguen igual con el gadget puesto, y
si abre alguno nuevo. En particular: ¿toca la frontera de flujo único? ¿Toca el cliente ligero —la otra
propuesta lo resucitaba a 6,6 MB/año, y eso resultó ser su mayor ganancia?

**H · Veredicto.** ¿Merece la pena? ¿Cuál de las dos, o ninguna? Si la respuesta es «ninguna», dilo: el
riesgo de reversión hoy ya es 7,1e-36 a los 30 minutos con `α = 0,33`, y puede que la finalidad rápida sea
un lujo que no compensa una pieza de consenso nueva.
