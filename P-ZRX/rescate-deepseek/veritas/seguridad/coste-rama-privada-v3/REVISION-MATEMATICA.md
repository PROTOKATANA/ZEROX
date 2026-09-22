# REVISION-MATEMATICA.md — CRP-v0.3

**Tipo:** revisión independiente de matemáticas/probabilidad, **contexto nuevo**, hecha a
petición del usuario. **No es firma de tercero ni certificación**: es un dictamen técnico de
una sola pasada adversarial, sin autoridad normativa.

**Entrada revisada:** `veritas/seguridad/coste-rama-privada-v3/` (`src/`, `test/`,
`resultados/`, `INFORME.md`, `MATRIZ-VALIDEZ.md`) derivada de v0.2. **No se modificó** código
fuente, `SPEC`, `TAREAS` ni el encargo.

---

## 1 · Alcance

Se revisa el foco pedido por el usuario:

1. Separación `P_terminal(T)` / `P_first_passage(≤T)` / `P_eventual` (`src/eventos.jl`,
   `src/dp.jl`), correctitud de las DPs, cotas y orden.
2. `α_prob` con cobertura simultánea (`cp_intervalo` + `alpha_prob_simultaneo`).
3. Derivación y consistencia de `P_eventual = (q/p)^(z0+1)`.
4. Punto 7: déficit en unidades de `blue_work` y semilla independiente de `d`.
5. Defendibilidad estadística del SWEEP-DAG y de las conclusiones del `INFORME.md` sobre el
   aditivo cruzando `1/(S+1)` y R-FIN-5 (máximo), con 24 réplicas.

Fuera de alcance: validez de reglas del SPEC, topología de GDR-v0.2 (se usa como oráculo),
benchmarks económicos/`S_adversario`.

## 2 · Método

- Suite pedida: `env -u LD_LIBRARY_PATH julia --check-bounds=yes --project=. test/runtests.jl`
  → **76/76 pass, 4.3 s** (Julia 1.13.0, `znver5`, `hilos=1/1`, `semilla=23130`, 24 réplicas).
- Comprobaciones propias en `/tmp/opencode/rev/*.jl` (no se tocó el instrumento):
  - Referencias exactas: `P_terminal(T)=P(Binomial(T,p) ≤ ⌊(T−d−1)/2⌋)` en `BigFloat` y
    `P_first_passage` racional vía `prob_superar_finita`.
  - Barrido de 4000 puntos aleatorios (`z0∈[0,60]`, `T∈[1,400]`, `α∈[0,0.499)`) y casos extremos
    (`z0≤100`, `T≤1000`, `α→0.5`) contra las cotas de la DP.
  - Reejecución de las celdas del SWEEP-DAG con la **rejilla α exacta** (no redondeada) y
    recuento del contrafactual aditivo con y sin duplicación del prefijo común.
  - Reproducción manual del bucle de `simular_v3!` para exponer el prefijo compartido.
  - Pruebas directas de `compatible_rfin5` y de `alpha_prob_simultaneo` con n grande y datos
    no monótonos.

## 3 · Hallazgos

### H1 · Contrafactual aditivo: el prefijo común se cuenta S veces — **severidad ALTA (de medición)**

`run.jl:61` fija `d = d_bloques * W` (`W = ⌊2^128/(SR+1)⌋`, correcto) y `run.jl:64` usa una
semilla independiente de `d` (correcto). Pero `dag_sim.jl:323` y `dag_sim.jl:335` miden
`W_pub = bw(punta_pub) − bw(génesis)` y `W_priv[s] = bw(tip_s) − bw(génesis)` con
`fork_ref = 1` (génesis), **no** el ancestro común real. Como cada rama se enraíza en la misma
punta pública congelada (`raices[s]`, `dag_sim.jl:286`), cada `W_priv[s]` contiene el mismo
prefijo `bw(raíz)`. Por tanto:

```text
Σ_s W_priv[s] − W_pub = (S−1)·bw(prefijo) + Σ_s rama_s − público_postfork
```

El encargo (D7.4 / §1.5) exige **"prefijo común contado una vez"**. `celda_dag`
(`run.jl:66-69`) usa esa suma cruda como `esum`, de modo que a cada éxito de `suma_terminal` se
le regala `(S−1)·bw(prefijo)` (a `t_fork=1`, 0 ó 2 bloques por réplica, multiplicados por hasta
S=24). Recuento con prefijo contado una vez (mismo RNG, misma rejilla α exacta):

| S | α=1/(S+1) | `esum` actual | corregido (prefijo 1 vez) |
|---|---|---|---|
| 2 | 0.33333 | 14/24 | **13/24** |
| 4 | 0.20000 | 17/24 | **13/24** |
| 8 | 0.11111 | 18/24 | **15/24** |
| 16 | 0.05882 | 22/24 | **15/24** |
| 24 | 0.04000 | 24/24 | **17/24** |

(`b−0.05` da 0/24 en ambos recuentos; S=1 no tiene efecto; celdas saturadas a 24/24 no cambian.)
El `INFORME.md:72-74` y `MATRIZ-VALIDEZ.md:28` citan 17/24 y 22/24 como "medido", y 22/24 y
24/24 son precisamente los que colapsan a 15/24 y 17/24. La conclusión **cualitativa** ("el
aditivo cruza dentro del último tramo de 0.05 antes de `1/(S+1)`") sobrevive, pero **las cifras
publicadas no son las del contrafactual especificado**. La columna `max_terminal` (máximo) sí
cancela el prefijo y está bien: `max_s(prefix+rama_s) − (prefix+público)`.

*Recomendación:* medir contra `bw(raíz)` (o restar el prefijo una vez de la suma), no contra
génesis; y declarar el cambio en `PROGRESO.md`.

### H2 · `alpha_prob_simultaneo`: cota mal construida en la rama "sin celdas por encima" — **severidad MEDIA**

`eventos.jl:84-87`:

```julia
if !hay_arriba
    return (tipo=:solo_cota_superior, a=Inf,
            b=(a_low == -Inf ? maximum(alphas) : a_low + (maximum(alphas) - a_low)), ...)
end
```

`b` colapsa a `maximum(alphas)` en ambos casos. Si ninguna celda supera `p0`, la lectura
correcta (bajo monotonía) es `α_prob > a_low`: la única cota disponible es **inferior**, no
superior. Comprobado:

- `alpha_prob_simultaneo(0.05:0.05:0.45, zeros(9), 100000, 0.05)` devuelve
  `(tipo=:solo_cota_superior, a=Inf, b=0.45)` aun cuando las 9 celdas están confiadamente por
  debajo de `p0` (CP 0/1e5 ≪ 0.05), es decir, `α_prob > 0.45`. El par `(a=Inf, b=0.45)` es
  internamente incoherente y puede leerse como una cota superior falsa.
- `metadata`: `eventos.jl:6-7,63` documentan "0/n se publica como cota unilateral"; la rama
  no devuelve la cota CP de la celda 0/n sino el borde de la rejilla.

La parte estándar sí es correcta: `cp_intervalo` reproduce Clopper–Pearson exacto (0/24 →
`(0, 0.1425)` con γ=0.05; 24/24 → `(0.8575, 1)`), y Bonferroni `γ/m` da cobertura simultánea
≥ 1−γ. La rama `:cruce` es válida **bajo monotonía** (verificado con `n=1e5`: devuelve
`(0.25, 0.30)` con la frontera dentro). Lo que falla es la rama sin celdas por encima.

### H3 · Misaplicación: `α_prob` simultáneo mezcla escenarios S distintos — **severidad MEDIA (metodológica)**

`run.jl:96` llama `alpha_prob_simultaneo(alphaS, exmax, REPS, 0.05)` con `alphaS`/`exmax`
acumulados de **todos** los S (`run.jl:89-91`). En `SWEEP-DAG.txt:51` el resultado trae
`celdas = 22`: `0.45` aparece 6 veces (una por S) y hay α de escenarios incompatibles.
`α_prob(α,T,d,E,O)` está definida **por escenario** `E` (que incluye `S`); no existe una única
frontera que combine S=1…24. El `tipo=:indefinida` es seguro, pero la etiqueta
"alpha_prob (evento terminal, regla R-FIN-5=max)" y el `m=22` (con duplicados) no son
interpretables. Debe calcularse un `alpha_prob_simultaneo` por S (o publicarse como familia).

### H4 · "R-FIN-5 (máximo) da ~0 para α<1/2" está sobre-enunciado — **severidad MEDIA**

En `SWEEP-DAG.txt:47`, S=24 α=0.45 (que es <1/2) da `max_terminal = 6/24 = 25 %`
(S=16 y S=8: 6/24 y 5/24). Lo sostenible es "el máximo no cambia la frontera de deriva
(promedio), pero su probabilidad finita cerca de α=0.45 no es despreciable". El
`INFORME.md:22,74` lo resume como "~0 para α<1/2", que la propia tabla contradice.
Además, con 24 réplicas un `0/24` **no** acota P≈0: CP simultáneo (m=22) da cota superior
≈0.246; a lo sumo acota P≲0.25.

### H5 · Potencia insuficiente para llamar "frontera medida" al cruce aditivo — **severidad MEDIA**

Con 24 réplicas y rejilla α de ancho 0.05:
- `INFORME.md:21` y `MATRIZ-VALIDEZ.md:28` etiquetan el cruce como `medido`. Lo medido es, a lo
  sumo, un **intervalo de rejilla** (p. ej. S=4: entre 0.15 y 0.20). No hay IC del punto de
  cruce ni estimación interpolada con error.
- Las celdas `0/24` que sostienen el lado bajo tienen cota superior simultánea ≈0.25, luego son
  compatibles con efectos no pequeños.
- `INFORME.md:79` atribuye el `:indefinida` a "ruido y no monotonicidad"; en realidad el código
  (`eventos.jl:88-90`) lo emite porque `a_low == -Inf`, es decir, **ninguna** celda quedó
  confiadamente por debajo de `p0` tras Bonferroni. La causa declarada es imprecisa.

Etiqueta defendible: "acotado en la rejilla (ancho 0.05, n=24); frontera no estimada".

### H6 · Invariante de R-FIN-5 violada con `flujo_id` compartido — **severidad BAJA/MEDIA (latente)**

`flujo.jl:39-40` hace cortocircuito `flujo_B.flujo_id == flujo_X.flujo_id && flujo_B.autenticado
⇒ VALIDA`, **sin comprobar `X.autenticado`**. Comprobado:

```text
compatible_rfin5(auth(id=3), no-auth(id=3), 7) = VALIDA
```

Contradice la invariante declarada en `flujo.jl:3-4` ("un descriptor no autenticado produce
PENDIENTE, nunca `true`"). No es alcanzable hoy (`construir_flujo` siempre autentica y usa ids
distintos), pero es un agujero en un predicado de seguridad si alguna regla futura reutiliza
ids. No afecta a los tests ni a las trazas actuales.

### H7 · `η_a = 1.0` es tautológico — **severidad BAJA (de presentación)**

`dag_sim.jl:226` (`_eta_rama`) colorea el trabajo adversario en la **punta de su propia rama**,
donde sus bloques son azules por construcción. Por eso `η_a = 1.0` y `rojos_a = 0` no son una
medición de eficiencia bajo la vista pública, sino una identidad del contexto elegido. El
`INFORME.md:23` lo marca "inconcluso" para la curva con rojos (correcto), pero conviene decir
explícitamente que `η_a` es 1 por construcción, no "medido".

### H8 · El test del punto 7 no prueba lo que enuncia — **severidad BAJA**

`test/runtests.jl:44-55` comprueba que un paseo de juguete con el mismo `StableRNG` y distinto
`D₀` conserva los incrementos: es una identidad aritmética del RNG, no del simulador. La
propiedad real (semilla independiente de `d`) se cumple por inspección (`run.jl:64`; `d` sólo
entra en el umbral `run.jl:61,67-69`), pero no tiene test de integración.

## 4 · Lo que sí verifiqué (sin hallazgos)

- **Orden de los tres eventos.** `P_terminal ≤ P_first_passage ≤ P_eventual` se cumple en 4000
  puntos aleatorios y en los casos extremos: 0 violaciones de
  `p_terminal > p_paso` y 0 contradicciones `p_terminal_lower > p_paso_upper`. La prueba
  analítica (terminal ⊆ primera pasada ⊆ eventual) es correcta.
- **DP de primera pasada.** `dp_adaptativa` con `exito=z≤−1`, `lo_inicial=−1`, expansión sólo
  hacia arriba: comparada contra `prob_superar_finita` racional en todo el barrido; el valor
  exacto cae siempre en `[p_exito_lower, p_exito_upper]`. `p_paso` y `p_eventual` coinciden en
  el límite (p. ej. z0=4, α=0.2, T≥100 → 9.765625e-4 = 1/1024).
- **Soporte de P_terminal.** `dp_terminal` expande ambos lados duplicando ancho hasta
  `fuga ≤ 1e-14` o `max_ancho`; la cota `[pterm, pterm+fuga]` acota el valor exacto. Caso con
  fuga no trivial (z0=150, T=600, α=0.45): `pterm=2.675e-18`, `fuga=1.240e-16`, exacto
  `2.675e-18` dentro de la cota. El mecanismo es válido; el valor puntual puede ser una cota
  inferior estricta (se publica la cota aparte, correcto).
- **Derivación de `P_eventual`.** Para `z0=g·d` y `q<p`, la ruina del jugador da
  `(q/p)^(z0+1)`; coincide con `prob_superar_eventual(d,·,·)=(q/p)^(d+1)` y con el valor
  `(0.25)^5=1/1024` (z0=4, α=0.2) y `(1/9)^5=1/59049` (α=0.1). Para `q≥p` devuelve 1.
  La `α_prob` por evento (terminal 0.4431 > paso 0.3546 > eventual 0.3545) es coherente con
  ese orden, pues a menor probabilidad para el mismo α, mayor α umbral.
- **Punto 7.** `d = d_bloques·W` con `W = peso_big(SR=1) = ⌊2^128/2⌋ = 2^127`, idéntico al peso
  real de cada bloque (`GDR peso_big`); `W_pub`/`W_priv` son `BigInt` exactos. Semilla
  independiente de `d` (ver H8).
- **Reproducibilidad del barrido.** Reejecutadas las 22 celdas `d_bloques=0` del SWEEP-DAG con
  el código actual y la rejilla α **exacta** (`1/(S+1)`, etc.): coinciden 22/22 con
  `SWEEP-DAG.txt`. Las aparentes diferencias usando α redondeado a 2 decimales desaparecen al
  usar el valor exacto; no hay falta de reproducibilidad.
- **U2/U3, R-FIN-5 estructural, flujo→validez→U2→color, único productor sin rojos, Δ=0**:
  los tests y fixtures reproducen lo declarado.

## 5 · Lo no verificado

- No re-derivé GHOSTDAG/GDR-v0.2; lo traté como oráculo de color y `blue_work`.
- No ejecuté `run.jl` completo (para no sobrescribir `resultados/`); reproduje celdas sueltas con
  los mismos parámetros. La corrección H1 la hice con una réplica manual que **reproduce
  exactamente** `esum` del código actual.
- No audité `BENCH.txt`/`IO.txt` ni la parte económica (`S_adversario`, `η·c`), fuera del foco.
- No verifiqué la correspondencia entre las reglas del instrumento y el SPEC vigente.
- `alpha_prob_determinista` se probó para `d=4`; no barrí todos los `(d,p0,T)`.

## 6 · Veredicto

**Instrumento internamente coherente y con la matemática de probabilidad correcta en el núcleo
que le da nombre:** la separación de los tres eventos, sus DPs, las cotas por fuga y la forma
cerrada eventual resisten comparación con referencias exactas. La suite pasa 76/76 y las celdas
del barrido son reproducibles.

**Pero hay un defecto material (H1) que invalida las cifras concretas que el `INFORME.md`
presenta como "medidas" del contrafactual aditivo:** el prefijo común se cuenta S veces, contra
la instrucción explícita del encargo; los recuentos bajan de 17/24→13/24 (S=4), 22/24→15/24
(S=16) y 24/24→17/24 (S=24). La conclusión cualitativa de que el aditivo cruza cerca de
`1/(S+1)` sobrevive, pero **no con las cifras ni la etiqueta "medido" actuales**. El bloque
`α_prob` simultáneo tiene además una rama con cota mal construida (H2) y se aplica mezclando
escenarios S (H3). Las afirmaciones "R-FIN-5 máximo ~0 para α<1/2" (H4) y "frontera medida" con
24 réplicas (H5) no son defendibles tal como están escritas; con `n=24` y rejilla de 0.05 lo
máximo honesto es una cota de rejilla con IC amplios.

**Estado sugerido del veredicto del informe:** no cambia la frase final (umbral protocolario
inconcluso), pero las filas "Aditivo cruza en `1/(S+1)`" y "R-FIN-5 (máximo) no suma ramas"
deberían rebajarse a *"contrafactual medido con procedimiento corregido por revisión / acotado
en rejilla, n=24"* y corregirse `INFORME.md §6`, `MATRIZ-VALIDEZ.md` y las cifras de
`SWEEP-DAG.txt` afectadas. Las DPs de eventos y la semilla/unidades del punto 7 quedan
**aprobadas** dentro de lo verificado.
