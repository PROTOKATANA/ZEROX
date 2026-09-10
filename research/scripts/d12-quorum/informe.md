# D12 · Finalidad por quórum de soluciones como gadget sobre el DAG, frente a la capa estilo Filecoin

**Agente:** D12 · **Fecha:** 2026-09-10 · **Encargo:** `research/scripts/d12-quorum/ENCARGO.md`
**Método:** `research/scripts/METODO-AGENTES.md` (sin presupuesto de tiempo; LAGUNA nunca por falta de tiempo).

**Fuentes primarias leídas enteras antes de medir:**

| Fuente | Ruta | Qué se usa |
|---|---|---|
| Keller y Böhme, *HotPoW* | `research/fuentes/hotpow.txt` (1 942 líneas) | §3 teoría de quórums, §4 protocolo, §5 evaluación, Apéndices A/B/C |
| Sankagiri et al., *CAP Theorem Allows User-Dependent Adaptivity and Finality* | `research/fuentes/cap-adaptividad-finalidad.txt` | marco de dos reglas de confirmación |
| Lewis-Pye y Roughgarden, *Resource Pools and the CAP Theorem* | `research/fuentes/lewispye-roughgarden-cap.pdf` **descargado hoy** de `arxiv.org/pdf/2006.10698`, extraído con `pypdf` a `.txt` | Teorema 4.1 y sus hipótesis |
| Propuesta rival | `research/dag-poas-capa-finalidad.md` (R-FIN-15..22) | la comparación |
| Diseño vivo | `research/dag-poas-ancla-de-orden.md` §2 (R-FIN-1..14), `research/dag-poas-catalogo-problemas-ataques.md` | la composición |
| Kaspa | `/home/katana/zeo/fuentes/rusty-kaspa @ c338d495` | reglas de selección y finalidad |
| Autonomys | `/home/katana/zeo/fuentes/subspace @ f8842d0` | tamaño real de una solución |

---

## A · Control positivo y auditoría del cálculo de partida

**Script:** `d12_a_control.py` · **Salida:** `salida_a.txt`

### A.1 · Los números del paper, reproducidos con tres instrumentos independientes

Tres vías para la misma cantidad: (1) la forma cerrada del Lema 1 en precisión arbitraria por la
gamma incompleta regularizada —la forma que el propio paper usa en la demostración del Teorema 1,
`hotpow.txt:1660-1668`, `f(k) = P(2k,k) = γ(2k,k)/(2k−1)!`—, (2) `scipy.stats.poisson.sf`, y
(3) un **Monte Carlo del proceso de Poisson de la Definición 1** (`hotpow.txt:279-283`), que no usa
ninguna fórmula cerrada: genera tiempos entre ATV exponenciales y cuenta.

| Control | Publicado | Reproducido | Etiqueta |
|---|---:|---:|---|
| POA de Bitcoin, `k = 1`, `λ = 0,1`, `t = 10 min` (`hotpow.txt:392-397`) | 0,2642 | **0,2642** | VERIFICADO |
| Tabla A.1, `k = 2` (`hotpow.txt:1839`) | 0,1429 | **0,14288** | VERIFICADO |
| Tabla A.1, `k = 16` | 0,0003 | **2,762e-04** | VERIFICADO |
| Tabla A.1, `k = 64` | 1,2e-12 | **1,2724e-12** | VERIFICADO |
| Tabla A.1, `k = 256` | 4e-45 | **3,959e-45** | VERIFICADO |
| Corolario 2: independencia de `λ` (`hotpow.txt:379-386`) | — | dispersión relativa **≤ 3,5e-15** sobre `λ ∈ {0,01 … 1 000}` para `k = 1, 16, 64` | VERIFICADO |
| Ec. (14), tasa asintótica `ln(e/4)` | −0,38629 | −0,51215 (`k=16`) → −0,38745 (`k=4 096`), converge por arriba | VERIFICADO |

El Monte Carlo (12 semillas: 11, 22, …, 333; 400 000 realizaciones cada una) coincide con la forma
cerrada en las siete configuraciones probadas, dentro del IC del 95 %:

| `k` | `λ` | MC media | IC 95 % | cerrada |
|---:|---:|---:|---|---:|
| 1 | 0,10 | 0,264341 | [0,264000, 0,264682] | 0,264241 |
| 2 | 1,00 | 0,142797 | [0,142542, 0,143052] | 0,142877 |
| 8 | 1,00 | 0,008253 | [0,008157, 0,008350] | 0,008231 |
| 16 | 1,00 | 0,000280 | [0,000267, 0,000293] | 0,000276 |

> **Nota de honestidad sobre el MC.** Las filas `(k=1, λ=0,1)` y `(k=1, λ=1,0)` salen **idénticas**, y
> las `(k=16, λ=0,1)`/`(k=16, λ=1,0)` también. No es un fallo del instrumento: el suceso
> `T_{2k} ≤ k/λ` es invariante de escala en `λ`, y con la misma semilla los uniformes subyacentes son
> los mismos. Es, de hecho, **la demostración muestral del Corolario 2**. Criterio α: el resultado sí
> cambia —y mucho— al cambiar `k` (0,264 → 1,27e-12 entre `k=1` y `k=64`), que es el parámetro que se
> estudia.

**Lo que NO se ha podido replicar:** la validación empírica sobre datos históricos de Bitcoin
(`ĥp = 0,2606` sobre 2017-2018, `hotpow.txt:397-401`) exige la serie de sellos de tiempo de Bitcoin,
que no está en local. **LAGUNA menor**; haría falta descargar los encabezados de Bitcoin. No afecta a
ninguna conclusión: es una validación del paper contra la realidad, no del instrumento.

### A.2 · Auditoría de `research/scripts/rendimiento/verif_quorum_soluciones.py`

| # | Afirmación del script | Veredicto |
|---|---|---|
| 1 | `POA(k) = P[Poisson(k) ≥ 2k]` | **CORRECTA.** Es literalmente el Corolario 2 (`hotpow.txt:379-386`): Lema 1 da `P[Poisson(λt) ≥ 2k]`, Corolario 1 da `t̄ = k/λ`, luego `λt̄ = k` |
| 2 | «independiente de λ» | **CORRECTA**, VERIFICADO en A.1c |
| 3 | Rutina propia `poisson_sf` | **CORRECTA.** Peor error relativo **6,4e-14** frente a mpmath/scipy en `k ∈ [16, 256]`. La condición de corte y el tope `k > λ·40 + 2000` no muerden en ese rango |
| 4 | «cae ~`e^{−0,386k}`» | **CORRECTA.** `ln(e/4) = −0,38629`, exactamente la tasa de la Ec. (14). Para `k` finito el decaimiento real es más rápido (−0,428 a `k=64`) |
| 5 | «un `k`-quórum tarda ~`k` segundos» a `λ = 1/s` | **CORRECTA en aritmética, ENGAÑOSA en composición.** `t̄ = k/λ`. Pero en HotPoW la tasa de **votos** es `k·λ_bloque` (`hotpow.txt:200-208`: *«HotPoW asks for k easier puzzles each expected to take 10/k minutes»*), de modo que el quórum tarda **un intervalo de bloque**. Si el voto es nuestro bloque, `λ_voto = λ_bloque = 1/s`, el quórum tarda `k` s **y consume `k` bloques**. Ver punto B |
| 6 | `bls = 48 + (k+7)//8` — certificado agregado « < 60 B » | **ERROR.** Ver abajo |

**El error 6, con el número del propio paper.** Un mapa de bits solo comprime si existe un **registro
ordenado de firmantes** contra el que indexar. En F3 lo hay: la tabla de poder. HotPoW **no tiene
registro** —esa es su ventaja anunciada— y por eso sus votos son autoportantes: la clave pública del
votante viaja **dentro** del voto. El paper lo tarifa en la Tabla A.1 (`hotpow.txt:1835-1843`):

| `k` | cabecera del paper | modelo `32 + 40k` |
|---:|---:|---:|
| 1 | 72 B | 72 B |
| 2 | 112 B | 112 B |
| 16 | 672 B | 672 B |
| 64 | 2,6 kB | 2 592 B |
| 256 | 10 kB | 10 272 B |

El modelo `32 + 40k` reproduce la tabla exactamente: 32 B de referencia común más **40 B por voto**
(32 B de clave pública + 8 B de solución). No hay 60 B agregados; **hay 40 B por voto que no se
pueden agregar sin reintroducir el registro** que la propuesta presume no necesitar. Y 8 B es el
tamaño de una solución de PoW; el de una solución de **espacio** de Autonomys es otro (punto F).

**Errores propios que declaro ya:** el `bls = 48 + (k+7)//8` del cálculo de partida es mío y es
inaplicable sin registro. El resto del script de partida es aritméticamente correcto.

**Etiqueta del punto A: VERIFICADO** (control positivo reproducido con tres instrumentos; un error
del cálculo de partida localizado y cuantificado).
