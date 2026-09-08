# Auditoría D9-e — Ronda 8e: el peso real `blue_work = Σ w(SR)` contra los resultados de D9-d

**Propuesta:** `dag-poas-ancla-de-orden.md` §2, ancla `blue_score` · **Pregunta:** la laguna mayor de
D9-d — su simulador pesaba 1 por bloque; el diseño y Kaspa pesan `Σ calc_work(bits)`
(`protocol.rs:155-161`, `difficulty.rs:211-217`), y ese peso elige la cadena · **Fecha:** 2026-09-08,
madrugada, modo autónomo · **Agente:** D9-e en **Opus 5**, fresco · **Informe íntegro, 15 scripts y
salidas (commit `ac35045`, solo su directorio):** `research/scripts/d9-ronda8e/`.

> **VEREDICTO: el peso real no mueve ninguna conclusión de D9-d** — `m` ±4 %, sesgo idéntico, `δ` en
> peso ≈ `δ` en conteo, y el Lema A2 **se transfiere** al ancla con dos eslabones nuevos demostrados.
> Y no es porque la rama no corra: bajo ataque el peso invierte 136 decisiones de `find_selected_parent`
> y 185 órdenes de mergeset, **y el ancla no se entera**. Lo que sí está roto es otra cosa:
> **`m` no tiene cota superior conocida** — sube cada vez que un agente amplía la familia de
> estrategias (D9-c 5,0 → D9-d 3,03 → D9-e **5,77**). Mientras no haya cota por argumento, ningún
> `c` ni `F` derivado de `m` está dimensionado.

---

## 0 · Verificación independiente del agente principal

| Comprobación | Resultado |
|---|---|
| Commit `ac35045` | **Solo su directorio** (37 ficheros, 0 fuera) |
| `AUDITA_SCRIPTS.py` (15 scripts) | 5 marcas, **las cinco leídas por mí**: cuatro `x == x` son el modismo de descarte de NaN; el `[T2]` (`n = 0.5`, `r8e_lib.py:164`) es el camino «épocas intermedias vacías», que corre **0 veces** en 72 corridas (`r8e_z_auditoria.py`, ejecutado por mí) |
| **Criterio de cobertura de rama** (nuevo) | **Pasa:** control negativo `W=None` → `sp≠ = 0/0/0` (`r8e_a0_control.py`); contador vivo, `sp≠ = 353` (`r8e_a0c_contador.py`) — ejecutados por mí |
| **A4**, `r8e_a4_lemaA2.py`, ejecutado por mí | **Reproduce:** 141 967/141 967 parejas con `blue_work` monótono; cambios de ancla con cadena ya distinta en `p ≤ idx`: 60/60, 27/27, 16/16 |
| **A4b**, `r8e_a4b_contraejemplo.py`, ejecutado por mí | **Reproduce:** con peso real, `blue_score` **no** monótono bajo ancestría (2 parejas rotas); `blue_work` sí (0); con peso 1 el contraejemplo desaparece |
| Cita `difficulty.rs:166-198` | **Real:** `calculate_difficulty_bits(window, ghostdag_data)` recalcula `bits` por bloque sobre una ventana deslizante |
| Reproducción de D9-d con peso 1 | **Cifra a cifra en las 15 celdas** (2,33/3,03/3,17/3,25), 12 semillas, misma familia importada |

---

## 1 · A1 · `m` con peso real — NO cambia (desvío −2,8 % a +4,0 %)

Con `sp≠` hasta 156 (la rama corre), el menú del ancla `blue_score` con `Σ w(SR)` difiere del de peso 1
en **±4 %** sobre 30 celdas. **A1b — ¿puede mover el peso?** La palanca existe (retroceder para heredar el
`SR` de otra ventana compra 20× de peso por 110 de `blue_score`) **y es ruinosa**: hunde su cuota de
cadena del 49,4 % al 1,5 %. En el punto de diseño la ganancia es **exactamente 1,0000**.

**Nota honesta de D9-e sobre el punto de diseño:** con `W_RETARGET = 3 083` y horizonte de 260 s hay
**0 retargets**, así que ahí el peso real **no se distingue del peso 1 por construcción**; las medidas
con la rama viva usan `W = 20/80` (ventana forzada). Está declarado en `salida_a0.txt`.

## 2 · A2 · El sesgo no empeora por el peso — empeora por la familia de estrategias

49,3 % bloques / 59,3 % umbrales / **59,3 % peso**, idéntico en las 5 configuraciones; `w_atac/w_hon ≤ 1`.
**Pero el 80,6 % «eligiendo padres» de D9-d sube a 90,9 %** solo por ampliar `retro` de 4 a 64: el
atacante pone un bloque suyo en el cruce del umbral en **9 de cada 10** a `α = 0,25`, **19 de cada 20** a
0,40. **No es el peso: es que D9-d no buscó bastante.** Y `p_cap` sigue sin cota superior.

## 3 · A3 · Lema 9 en peso — PLAUSIBLE que sí; y el retarget cuesta margen

Peor desvío del `δ` en peso frente al de conteo: **−0,0113** (el peso da un `δ` más benigno).
**Efecto nuevo:** con retarget activo (`W = 80`) `δ_ef` sube **+41 %** (0,1222 → 0,1719); el margen
sobre la cota 0,2105 baja del 39 % al **18 %**. En el punto de diseño no ocurre; la sensibilidad existe y
no estaba escrita.

**Corrección a `dag-poas-empalme-peso.md` — Lema E1 (DEMOSTRADO):** sean `A`, `B` candidatos a padre
seleccionado, `S = blues(A)∖blues(B)`, `T = blues(B)∖blues(A)`; entonces `bw(A) − bw(B) = w(S) − w(T)` y
`bs(A) − bs(B) = |S| − |T|`. `S ∪ T` son bloques **contemporáneos** cerca de las puntas y el retarget es
función del pasado **compartido**, luego les da el mismo `SR`: **la deriva del retarget es un factor
común a las dos ramas y se cancela en `find_selected_parent`.** Confirmado sin hueco: `empates_bs ==
empates_bw` en las 24 filas. La nota del empalme acotaba `ε_común`, que **no decide**; lo que decide es
`ε_diferencial`, que vale **1,0020**. **La restricción `W ≥ 3 083, γ ≤ 0,25` se queda — por otra razón
y con más margen.** Y la LAGUNA 1 de esa nota es real en su literalidad: bajo ataque el sesgo del
retarget es sistemático y rompe su cota de `ε_común` por 2,8× (5,3× en el punto de diseño) — pero es la
magnitud que no importa.

## 4 · A4 · El Lema A2 SÍ se transfiere al ancla `blue_score` — DEMOSTRADO, con dos eslabones

- **Lema A4:** `blue_score` es **estrictamente creciente por la cadena seleccionada**; luego «el ancla
  (primer bloque con `blue_score ≥ c·j`) cambia ⇒ la cadena ya difiere en alguna posición
  `p ≤ idx(ancla)`», y ahí aplica el Lema A2 de D9-c (la pareja `(bloque, sustituto)` se invierte ⇒
  `∃C` de la Def. 2 ⇒ Prop. 7, sin cota de la unión). Comprobado **579/579** cambios de ancla.
- **Lema A4b:** `blue_work` es **monótono bajo ancestría con peso real** — porque la magnitud que se
  acumula es la misma que elige al padre. **141 967/141 967** parejas, 0 excepciones.

**Colateral, REFUTADO un supuesto implícito:** `blue_score` **no** es monótono bajo ancestría con peso
real (contraejemplo ejecutable: `Q` con `mergeset_blues = [B1]`, `mergeset_reds = [A0..A3]`, y
`blue_score(Q) < blue_score(A3)` con `A3 ∈ past(Q)`). No afecta al ancla (el Lema A4 solo pide
monotonía **por la cadena**), **pero sí a R-FIN-10 (`altura := idx`) y a la monotonía que R-FIN-7
exige**, que se apoyan en una altura monótona bajo ancestría. **`blue_work` sí lo es: usar `blue_work`
como altura.**

## 5 · Lo que D9-e cambia en el texto (aplicado)

1. **R-FIN-13: `slot` = índice de PoT, no sello de tiempo de la cabecera.** D9-e midió la lectura
   pesimista (sello); con el índice de PoT —objetivo, infalsificable— la palanca de A1b desaparece y el
   retarget deja de ser falsificable por *timewarp*. Era una ambigüedad de la regla.
2. **R-FIN-10: `altura := blue_work` de la cadena seleccionada**, no `idx`/`blue_score` (Lema A4b).
3. **`dag-poas-empalme-peso.md`: añadido el Lema E1** y separados `ε_común` / `ε_diferencial`.
4. **Lemas A4 y A4b en el texto de R-FIN-1.**
5. **`I`, `c`, `F` de D9-d A5 etiquetadas «contra la familia de D9-d», que no es un modelo de amenaza.**
   Con `m = 5,77` (la cota inferior actual, `retro ≤ 64`, Blom): `I ≈ 12 250 s (3,4 h)`, `c ≈ 9 300`
   azules, **`F ≈ 15,5 h`**. Y **subirá** en cuanto alguien amplíe la familia.

## 6 · Errores declarados por D9-e — dos de método

**El grave:** su primer modelo de retarget **no podía refutar nada** — con ventana por épocas, dos puntas
contemporáneas comparten peso por construcción, así que `sp≠ = 0` era un teorema de su implementación.
Lo vio leyendo `difficulty.rs:166-198` (Kaspa recalcula `bits` por bloque) y rehizo todo con ventana
deslizante. **El simétrico:** estuvo a punto de firmar un `+11,8 %` que no existe — con 3 semillas; con 6
más, coincidencia exacta. **Es la tercera vez esta noche que el criterio α pasa y el resultado es
falso por otra vía** (D9-d: rama que no corre; D9-e: modelo que no puede refutar; y semillas
insuficientes). Los tres van al método.

## 7 · Estado y consecuencia

| | |
|---|---|
| ¿Cambia el peso real las conclusiones sobre el ancla? | **No** (verificado) |
| ¿Se transfiere la Prop. 7 al ancla `blue_score`? | **Sí** — Lemas A4 + A4b (demostrados, comprobados 141 967/141 967) |
| ¿Está dimensionado el diseño? | **No.** `m` no tiene cota superior conocida: 5,0 → 3,03 → 5,77. `I`, `c`, `F` dependen de `m` |
| Lo que sí está | `k=30`, `q=1`, `S_max=150`, `W_RETARGET`, U3″ dinámica (Lema 9 sobrevive), R-FIN-7 reescrita, `shuffle`, dos umbrales, `slot` = índice de PoT, `altura := blue_work` |
| `Δ` | **Sigue sin medir.** Todo `δ` depende de él |

**La pregunta que decide ahora no es de simulación: es si `m` admite una cota superior por
argumento** (número de bloques que el atacante puede poner en el anticono del cruce en una ventana
`Δ`, acotado por sus billetes en esa ventana), o si hace falta un ancla donde `m` esté acotado **por
construcción** (leer el inyector de una **ventana de tiempo fija**, no de un cruce de umbral). Sin una
de las dos, el DAG tiene todas sus reglas y ninguna de sus constantes.
