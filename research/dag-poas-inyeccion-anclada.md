# Inyección anclada a slot y profundidad temporal — un DAG que encaja en PoAS

**Fecha:** 2026-09-07 · **PROPUESTA SIN AUDITAR** del agente principal, a petición de Katana
(«piensa y analiza hasta que encuentres un algoritmo que resuelva esto»). Reabre la parte de
**P-038** que la auditoría cerró. Debe pasar por D9 y D8 antes de tocar el SPEC. No hay
precedente desplegado; sí hay precedente de cada pieza por separado (citas abajo).

## 0 · Corrección previa

`dag-poas-auditoria.md` §0 dice que reconciliar «inyector estable» con «rezago acotado» sería un
Proof-of-Time nuevo, sin precedente. D8 lo dijo con finalidad de Kaspa (12 h) como profundidad.
**Esa profundidad no es la que hace falta.** La que hace falta es la de *acuerdo* sobre la cadena
seleccionada, que en GHOSTDAG es la misma exponencial que en Nakamoto: minutos, no horas. Y
Autonomys ya paga hoy un rezago de contenido de K = 100 bloques = 10 min (PR #1986,
`lookback_in_blocks == K`). El algoritmo de abajo no paga más lookahead al VDF rápido que Autonomys.

## 1 · Qué exige de verdad la inyección (de `dag-nativo-poas-propuesta.md` §2)

La inyección existe para dos cosas: (a) c-correlación, que el atacante no pueda ramificar su árbol
privado eligiendo entre muchas entropías (BDK+19, φ_c); (b) VDF débil, que nadie pueda precomputar
el flujo de PoT sin cota, lo que permitiría ploteo dirigido a desafíos conocidos. Ninguna de las dos
exige que el inyector sea «el bloque a la altura 50j» ni que el momento sea «slot de la punta + 15».
Exigen: **una entropía no moldeable, acordada por todos antes de aplicarse, aplicada en un slot
acordado, con un lookahead total acotado en minutos.** El slot de la punta lo eligió Autonomys por
comodidad (nazar-pc, foro 1615 #3: «(m+1)c is already known», y evitar un caso borde), no por
seguridad; la alternativa «slot de la fuente + constante» se discutió y se descartó por eso.

## 2 · El algoritmo

Parámetros (en **slots**, es decir en tiempo, no en bloques):

```
INTERVALO_INYECCION  = I   (p. ej. 300 slots = 5 min; c-correlación, cf. Autonomys 50 bloques × 6 s)
PROFUNDIDAD_INYECCION = L  (p. ej. 600–900 slots = 10–15 min; profundidad de ACUERDO, no de finalidad)
```

Estructura: GHOSTDAG (u otro DAG con cadena seleccionada determinista) sobre PoAS, un solo flujo
de PoT.

```
Época j:      empieza en el slot E_j = j · I.                     (fijado por el reloj, no por bloques)
Inyector I_j: el bloque de la CADENA SELECCIONADA de past(B) con el menor slot ≥ E_j.
Entropía_j:   blake3(chunk(I_j) ‖ pot_output(I_j))                (como Autonomys: no el hash del bloque)
Aplicación:   t_j = slot(I_j) + L                                  (NO slot(punta) + 15)
Semilla:      en el slot t_j, seed ← blake3(entropía_j ‖ S(t_j))   (S = salida del PoT en ese slot)
```

Reglas:

- **R-INJ-1 (determinismo).** I_j, entropía_j y t_j son funciones de past(B). Ningún nodo consulta
  su punta ni su cadena activa para validar el PoT de B (hoy ya es así en Autonomys: `block_import.rs:460-477`).
- **R-INJ-2 (no fusión entre flujos).** B es inválido si algún X ∈ past(B) tiene una solución
  inválida bajo el flujo que past(B) determina en slot(X). Consecuencia: dos sub-DAGs que discrepan
  en I_j para alguna época **no se pueden fusionar**; compiten por peso como dos ramas. Es la
  semántica de la cadena lineal, extendida.
- **R-INJ-3 (unicidad de billete).** Identidad `(public_key, sector_index, history_size, chunk, slot)`.
  De varias copias, la primera en el orden de GHOSTDAG es azul y las demás rojas (la forma U3′ que
  D8 dio; **no** «rojas ambas», que D9 refutó).
- **R-INJ-4 (peso, reajuste, emisión).** Solo sobre azules. Peso = Σ ⌊2^128/(SR+1)⌋. El reajuste
  mide slots de la cadena seleccionada o una ventana de azules (retarget de DAG, no LWMA-1; D9 A6).
- **R-INJ-5 (anticono anclado a slot).** Un candidato con `slot < slot(fusionador) − X` es rojo.
  Determinista y más fuerte que el anclaje temporal de PoW (D8, «A5 invierte la dirección»).

## 3 · Por qué resuelve cada uno de los dos fallos de la auditoría

**Split honesto sin atacante (D8 Ataque 1).** El inyector se lee a profundidad L en la cadena
seleccionada. Dos nodos honestos discrepan en I_j solo si discrepan en la cadena seleccionada a
profundidad L, que es el suceso de reorg profunda: exponencialmente improbable en L bajo GHOSTDAG
(Teorema 4 con k calibrado; D9 midió con el modelo de carrera P ≈ 10⁻²⁴ a 600 s con α = 0,25, y la
cota del propio paper, más floja, cae también en ese orden). Cuando ocurra, es una reorg: el lado
minoritario pierde sus bloques desde t_j y se resincroniza, igual que hoy en Autonomys tras un
PoT reorg (foro 2175: «never happens during normal operation»).

**Multi-flujo del atacante (D9 A3, D8 Ataque 2).** Con R-INJ-2 los bloques de un flujo distinto no
se pueden referenciar: cada flujo privado del atacante es un sub-DAG aparte con peso α, sin
sumarse a nada. Para que honestos adopten su flujo, tiene que ganar la cadena seleccionada a
profundidad L, que es el ataque de Nakamoto de siempre. La construcción de D9 («m flujos → m·α·λ»)
necesitaba merge irrestricto; R-INJ-2 lo prohíbe de forma determinista.

**Lookahead del VDF rápido.** Un atacante v× conoce entropía_j desde que I_j es público
(≈ slot(I_j) + D) y puede calcular S hasta t_j + I adelantándose (L + I)(1 − 1/v). Con L + I = 15
min y v = 2: ~7,5 min. Autonomys hoy: K + intervalo = 10 + 5 = 15 min de rezago total, el mismo
número. **No se paga más que Autonomys.** (Y ZEROX lineal a T = 120 s está peor: 3,3 h, P-039.)

**Grinding del inyector (φ_c).** El inyector se elige por *slot* (el primero de la cadena
seleccionada con slot ≥ E_j), no por conteo de bloques, para que el atacante no pueda moverlo
insertando bloques azules en la ventana. Su única palanca es retener su propio bloque cuando sería
I_j, la misma que en la cadena lineal (greenpaper §2.1: «withholding a winning block»). Bajo el
modelo de BDK, más bloques por época de desafío bajan φ_c; a q pequeño una época de 5 min tiene
cientos de bloques → φ menor que el φ₅₀ = 1,2815 de la lineal. **Con la reserva de D9: el teorema
está sobre conteo, no sobre peso.**

## 4 · Qué se modifica: el DAG o el PoST

Los dos, y poco:

| Pieza | Cambio | Precedente de la pieza |
|---|---|---|
| PoT: fuente del inyector | posición ordinal → primer bloque de cadena seleccionada con slot ≥ E_j | Chia: «primer bloque del slot» por `deficit` |
| PoT: momento de inyección | slot(punta)+15 → slot(inyector)+L | Autonomys foro 1615, *Design choice 1* (t_mc + T), descartada por comodidad |
| PoT: entropía | igual: blake3(chunk ‖ pot_output) | Autonomys |
| PoT: VDF | **sin cambios** | — |
| DAG: fusión | prohibida entre flujos (R-INJ-2) | cadena lineal (semántica), Autonomys `past(B)` |
| DAG: coloreado | U3′ | GHOSTDAG + D8 |
| DAG: peso/DAA/emisión | solo azules, peso por espacio | Kaspa `blue_work` (generalizado) |

La naturaleza paralela del DAG **no** es el problema. Entre inyecciones el flujo es común a todo el
DAG y los bloques paralelos son inocuos. Lo único que tiene que ser lineal es la elección del
inyector, y GHOSTDAG ya tiene una cadena seleccionada determinista para eso.

## 5 · Lo que sigue abierto (de D8, no resuelto por esto)

- **Poda**: rusty-kaspa poda por niveles de ceros del hash. Análogo natural: nivel por
  `solution_distance ≤ SR/2^ℓ` (prob. 2^{−(ℓ−1)}, no moldeable). Investigación, no adopción.
- **Cliente ligero (§26)**: `blue_work` en cabecera es afirmación; hace falta prueba de peso
  (MMR de cabeceras, Chia `header_mmr_root`). Diseño nuevo.
- **Coinbase por bloque a q pequeño**: la dirección de recompensa vuelve a la cabecera o el
  fusionador paga (deshace C-HDR-08). Emisión solo sobre azules.
- **C-REORG-07** en tiempo, no en bloques, y sin `exit`.
- **Retarget de DAG** (ventana de azules), convergencia sin derivar.
- **Coste de auditoría de red**: `C-NET-03/04` con soluciones a 1,32 ms cada una a q = 1.
- **Dmax real** sin medir; k sin calibrar.

## 6 · Lo que D9 y D8 tienen que atacar antes de que esto sea una regla

D9: (1) que P(discrepancia en I_j) a profundidad L es la cota de reorg de GHOSTDAG y no algo peor
por la ventana de slots; (2) φ bajo elección de inyector por slot y peso por espacio; (3) que
R-INJ-2 no reintroduce n-split ni particiones por equivocación del inyector; (4) el lookahead exacto
del VDF rápido con L, I y D; (5) qué L e I salen de las constantes de ZEROX. D8: (1) equivocar el
inyector (dos bloques del atacante como candidatos a I_j hacia dos mitades de la red, dentro de D);
(2) retener el inyector honesto y publicarlo tarde; (3) forzar reorgs de profundidad ≈ L a bajo
coste; (4) DoS con sub-DAGs de flujos falsos (coste de verificar antes de rechazar por R-INJ-2);
(5) todo lo de §5.
