# Ronda 13 — Irreversibilidad: quórum de soluciones, capa P-040 y alternativas

**Lee primero:** `research/scripts/METODO-AGENTES.md` (obligatorio; sin presupuesto de tiempo, resultado
completo, LAGUNA nunca por falta de tiempo).

**Prioridad declarada por Katana (2026-09-10), y ordena todo el encargo:**

1. **El mecanismo de irreversibilidad. Hay que bajar los tiempos de irreversibilidad lo más posible.**
   Es el criterio que decide.
2. **El cliente ligero es secundario.** Si no se puede tener cliente ligero verificado, se usan
   **servidores privados** como solución (modelo `zx-lightwalletd`). No se paga seguridad de
   irreversibilidad por ganar cliente ligero.

**Punto de partida (d12 y catálogo, ya medidos):**

| Hecho | Número | Fuente |
|---|---|---|
| Quórum: equivocación gratis en PoAS | POA `1,27e-12` → `0,52` con cualquier `k` | `d12-quorum/informe.md` §F.7; `subspace-verification/src/lib.rs:228-272` |
| Quórum: dominado | 1 702 s vs 871 s a `α=0,33`, objetivo 1e-12 | d12 §D.6 |
| Quórum: frontera | 44,69 % → 32,98 %; sin frontera a 143 s | d12 §G.2 |
| Quórum: cliente ligero | 4,04 GB/año + 842 h de núcleo/año | d12 §G.3 |
| P-040 (F3-style): irreversibilidad | ~30 s en caso normal; se para el 41 % de instancias a `α=0,33` | `dag-poas-capa-finalidad.md`; catálogo #58 |
| P-040: cliente ligero | 6,6 MB/año (R-FIN-22, sin auditar) | `capa-finalidad` §E |
| Suelo estructural de confirmación | 100–134 s, ninguna `F` lo baja | catálogo #31 |
| Rendimiento | 1 280 tx/s objetivo; 285 libres; 28 571 techo | hoja «ZEROX en números», 10-sep |

**Fuentes primarias en local:** `research/fuentes/hotpow.txt`, `cap-adaptividad-finalidad.txt`,
`lewispye-roughgarden-cap.txt`, `dagknight.txt`, `phantom-ghostdag.txt`, `bdk19.txt`.
Código: Autonomys `/home/katana/zeo/fuentes/subspace` @ `f8842d0`; Kaspa
`/home/katana/zeo/fuentes/rusty-kaspa` @ `c338d495`; Chia `/home/katana/zeo/ZEROX/PDF/chia-blockchain`
(v2.7.4). Diseño vivo: `research/dag-poas-ancla-de-orden.md` §2 (R-FIN-1..14; **NO editar**).

---

## F0 · Puerta del quórum — ¿anti-equivocación sin dinero en juego?

Única pregunta viva del quórum: ¿existe una regla que restaure la Definición 1 de HotPoW
(`hotpow.txt:279-283`: cada ATV vota una vez por un valor) **sin dinero en juego**?

Variantes a evaluar, cada una con su coste:

1. **Castigo de espacio**: probada la doble firma, se revoca la elegibilidad del plot/clave por `E`
   épocas. Pregunta de código que la decide: **¿se puede rotar la clave del plot sin volver a
   plotear?** (Chia v2.7.4 y Autonomys `f8842d0`).
2. **Quema de recompensa + lista negra de clave**: ¿esquivable rotando clave? ¿penalización
   proporcional al daño?
3. **Voto = bloque** (variante 1 de d12): re-verificar con el DAG; d12 §B.2 la refutó como
   profundidad con otro nombre.
4. **Atar el reto al valor votado**: cuantificar el coste (replotear por valor). Si es imposible,
   decirlo con el número.
5. **Voto con puzzle fresco** (PoW/VDF por voto): reintroduce un segundo recurso; coste y encaje.
6. **Submuestreo tipo Avalanche**: la equivocación no rompe su argumento igual que HotPoW; ¿es una
   vía real de irreversibilidad baja sin dinero?

**Kill criterion:** si ninguna variante restaura `2k` sin dinero en juego, se declara teorema con
prueba, se documenta y **se cierra la vía quórum de P-043**.

Control positivo obligatorio: reproducir `0,2642` (POA Bitcoin) y `0,5166` (equivocación, `k=64`)
con el instrumento de `research/scripts/rendimiento/verif_quorum_soluciones.py`.

---

## F1 · Auditoría de P-040 para irreversibilidad (prioridad 1)

Preguntas, en orden:

1. **Tiempo real de irreversibilidad** en caso normal: cadencia de instancias, `LOOKBACK = 10`,
   tiempo hasta certificado. ¿Son ~30 s? ¿Cuál es el mínimo alcanzable y qué lo fija?
2. **Bajo ataque:** ¿se para el 41 % de las instancias a `α=0,33`? ¿Cuál es el fallback (R-FIN-7) y
   el tiempo de recuperación? Seguridad vs viveza: la irreversibilidad no puede retroceder.
3. **`p` del granjero doméstico:** ¿<88,9 % rompe la seguridad o solo la viveza? Con prioridad 1,
   una capa que se para bajo ataque tiene que decirlo con número.
4. **`Δ` sin medir:** temporizadores del comité y qué pasa si `Δ` sale alto.
5. **Sesgo de sorteo** (`capa-finalidad` §4.D) y **BLS** (`blst` vs Rust puro; `kzg.verify =
   1,0773 ms` ya medido).
6. Verificar la afirmación «no funciona en el umbral del 33 %».

Instrumentos: `research/scripts/finalidad-espacio/`, `d12-quorum/`, banco KZG.

---

## F2 · Alternativas para irreversibilidad baja (prioridad 1)

Lista con descripción, tiempo de irreversibilidad, supuestos, si exige dinero en juego, coste por
nodo y fuente primaria:

- Baseline: profundidad de confirmación (R-FIN-7, 2 h; suelo 100–134 s).
- Avalanche Snowball/Snowman (fuente primaria a traer): sub-segundo, sin slashing; ¿peso por
  espacio?, ¿composición con GHOSTDAG?
- DAGKNIGHT (local): finalidad por profundidad de DAG, sin comité.
- Comité BFT (Tendermint, HotStuff-2, Casper FFG, GRANDPA): los únicos que bajan a segundos, pero
  exigen dinero en juego; coste de introducirlo.
- Capas híbridas: finalidad lenta por profundidad + certificado advisory.
- Cliente ligero (prioridad 2): #28a (2-4 GB/año con confianza parcial), #28b (muestreo del DAG),
  weak subjectivity; y servidores privados como plan B declarado.

---

## F3 · Balance doble y veredicto

Una tabla con **seguridad** (frontera, dominación, equivocación, viveza) y **rendimiento**
(**tiempo de irreversibilidad normal y bajo ataque** —la columna que decide—, bytes/año y CPU por
nodo, profundidad de poda, cliente ligero como secundario). Recomendación con etiqueta y condición
que la cambiaría. `## Veredicto` y `## Errores propios`.

## F4 · Decisión y SPEC

Reglas nuevas o cierre de P-043/P-040; actualización de `PREGUNTAS-PARA-KATANA.md`,
`DECISIONES.md` y `PROGRESO.md`; el diff del SPEC se presenta a Katana antes de aplicarlo.

**Lo que NO entra:** implementación de código de consenso · P-039 · P-036 · P-035 vs P-041 · editar
la propuesta viva `dag-poas-ancla-de-orden.md`.
