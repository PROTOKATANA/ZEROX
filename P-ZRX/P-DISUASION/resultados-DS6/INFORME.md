# INFORME — DS-6 · Reparto del espacio entre claves en redes reales de espacio

**Corrección A aplicada (ver sección al final).** El §0–§7 originales de abajo contienen un error de
convención del exponente (usaban `dist_alpha` = exponente de la **cola**; la fórmula de DS-3 exige el
exponente de la **densidad** = cola + 1) y no traían el cálculo empírico directo de `B(ε)` que pide
`CORRECCION-DS6-A.md`. Ambos se corrigen en la sección **«Corrección A»** al final de este documento,
que es la que debe citarse. Se deja el resto sin borrar para que quede el rastro del error.

**Ejecutor:** Sonnet (web + Julia CPU, sin Python, sin git, sin subagentes). **Fecha:** 2026-09-26.
**Encargo:** `P-ZRX/P-DISUASION/ORDEN-DS6-REPARTO-CLAVES.md`. **Marco:** `P-ZRX/P-DISUASION/MARCO.md`.
**Motivo (DS-3 §4.7):** el parámetro que decide si el castigo M3+M5 muerde en A1 (doble farmeo) es
`dist_alpha`, el exponente de la Pareto de tamaños de clave (H3), **hipótesis sin medir** en
`escenarios.tsv` (`2,05; 2,2; 2,5; 3,0`).

## 0 · Veredicto de la pregunta falsable

> «¿En al menos una red pública de prueba de espacio, los datos disponibles permiten estimar la cola
> de la distribución de espacio por clave/granjero con un intervalo que caiga dentro o fuera del
> rango 2,05–3,0 usado por DS-3?»

**Sí, se pudo estimar, y el intervalo cae FUERA del rango, muy por debajo, con un margen grande
(no un empate estadístico):**

| Ajuste | `dist_alpha` estimado | IC 95 % (bootstrap, 5.000 réplicas) | ¿dentro de [2,05; 3,0]? |
|---|---:|---|---|
| Todo el rango observado (2.453 granjeros, un solo pool) | **0,1113** | `[0,1102; 0,1124]` | **NO**, 18× por debajo |
| Solo la cola que mejor ajusta una Pareto (906 granjeros ≥ 90,8 TiB, Clauset–Shalizi–Newman) | **0,8560** | `[0,8096; 0,9069]` | **NO**, ≈2,4× por debajo |

Con la fórmula de `B(ε)` de P-CLAVE/DS-3 (§2 abajo), un exponente tan por debajo de 2 hace que
`B(ε)` sea **esencialmente cero** (`10⁻¹¹` a `10⁻⁷`, frente al umbral relevante `0,20–0,60`). La
sensibilidad ya calculada por DS-3 (cambio relativo `0,637` entre `α=2,05` y `α=3,0`) describe una
región mucho más plana que la que separa la hipótesis de la única red real medida.

## 1 · Fuentes (con fecha y etiqueta)

| # | Fuente | Qué mide | Fecha de la consulta | Etiqueta |
|---|---|---|---|---|
| 1 | `https://spacefarmers.io/farmers` (247 páginas, `?page=1..247`) | Lista completa y pública de **granjeros de UN pool de Chia** (`SpaceFarmers.io`), ordenada por `points` (proxy exacto y sin redondear del espacio contribuido), con su `TiB` derivado y `share %` | 2026-09-26, ~07:25–07:30 UTC (descarga propia) | **primaria comprobada** (descargada, guardada con `sha256`, verificable) |
| 2 | `https://spacefarmers.io/` (portada) | Netspace total del pool: `576,07 PiB` (=589.895,7 TiB) | 2026-09-26 | **primaria comprobada** |
| 3 | `https://spacefarmers.io/api-docs` | Confirma que el único endpoint de farmer requiere `launcher_id` ya conocido (no hay listado por API; se usó la tabla HTML paginada de `/farmers`) | 2026-09-26 | primaria (documentación) |
| 4 | Chia docs, *reference-farming-hardware*: "100 TiB ⇒ ~10.000 puntos/día", "cada plot k32 ⇒ ~10 puntos/día" | Calibración `points↔TiB` (no se usó directamente: se trabajó con `points`, la magnitud sin redondear) | citado en el sitio del pool | secundaria |
| 5 | `arxiv.org/html/2604.13044v1` (*Green by Design? Investigating the Energy and Carbon Footprint of Chia Network*) | Estratificación de granjeros en 3 cohortes (servidor/escritorio/portátil, 15/60/25 % con 65/30/5 % del netspace) | 2026 (versión html leída hoy) | **hipótesis declarada por sus propios autores**, NO datos medidos (cita solo la documentación de hardware recomendado; los autores admiten "limited data on node types", sensibilidad por eso) — se descarta como fuente de `dist_alpha` |
| 6 | `dashboard.chia.net` (coeficiente de Nakamoto) | Página no cargó (error de Grafana en el momento de la consulta); no se obtuvo el dato | 2026-09-26 | intento fallido, declarado |
| 7 | Autonomys: Messari *State of Autonomys Network Q1 2025*, Medium "300PB Pledged…", docs.autonomys.xyz, forum, GitHub `astral` | Espacio total prometido (`300 PB` nov-2024 → `522 PB` Q1-2025) y número de direcciones activas (`109.700`); **ningún listado público por operador/granjero individual** encontrado en el presupuesto de esta orden | 2026-09-26 | secundaria (agregados de red); **falta el dato por clave/granjero** |

**Qué NO se encontró:** un listado público de espacio por cuenta/operador en Autonomys (Astral
explorer redirige, requeriría indexar la cadena vía GraphQL/Subquery, fuera del presupuesto de 2 h
y de la prohibición de credenciales/infraestructura adicional). **Se declara explícitamente: no hay
segunda red con datos por clave en este encargo.** La respuesta se apoya en **una sola red real**
(Chia, un pool), tal como permite la pregunta falsable ("al menos una").

## 2 · Qué mide la fuente 1 y sus sesgos (obligatorio por la orden)

- **Unidad de medida real:** un **granjero del pool** (`launcher_id`, el *plot NFT* singleton de
  Chia) — la unidad de contabilidad que el pool usa para pagar. Es el análogo más cercano a una
  **«clave»** de ZEROX/P-CLAVE: agrega todo el espacio que ese identificador declara, sin importar
  cuántas parcelas físicas k32 lo componen.
- **NO es**: (a) todo el netspace de Chia (`~3–4 EiB` netspace efectivo estimado en 2026, ver
  XCH.today citado en LowEndBox — este pool son `576 PiB` ≈ 0,015–0,02 de la red, **secundaria**,
  no verificada aquí con una fuente primaria de netspace total); (b) todas las claves de un
  granjero (un mismo operador puede tener varios `launcher_id`, fragmentando su espacio real —
  sesgo hacia MÁS unidades pequeñas de las que un solo operador "económico" representa); (c) los
  granjeros que minan solo (*solo farming*) o en otros pools — **los mayores tenedores de espacio en
  Chia tienden a NO usar pools públicos** (evitan la comisión y la confianza en el operador), así que
  este pool probablemente **subrepresenta la cola derecha real** (podría faltar aún más
  concentración arriba) y por tanto, si acaso, **sesga `dist_alpha` hacia arriba** (menos pesada de
  lo real) — el sesgo conocido apunta en la MISMA dirección que reforzaría la conclusión de este
  informe, no en la contraria.
- **Granularidad de piso:** el plot k32 mínimo son ~101,4 GiB; con un netspace total de red del
  orden de EiB, una sola parcela es una fracción `~10⁻⁸` a `10⁻⁹` del total — del mismo orden que el
  `f_min = 10⁻⁸` que ya usa el MODELO de DS-3/P-CLAVE. Esto es una coincidencia útil de escala, no
  una validación: el `f_min` de H3 y el piso físico de Chia son compatibles en orden de magnitud.
- **Medición en vivo:** la descarga secuencial de 247 páginas tardó ~5 minutos; la tabla se
  reordena en vivo. Se detectaron **13 duplicados de `launcher_id`** entre páginas contiguas
  (0,53 % de las filas) por granjeros pequeños que cambiaron de rango durante la descarga; se
  eliminaron por deduplicación (se conserva la primera aparición). Efecto sobre `dist_alpha`:
  despreciable (13 de 2.453, y del lado de menor magnitud).
- **Se excluyeron 4 filas con `points=0`** (sin actividad registrada; `log(0)` no está definido
  para la verosimilitud de Pareto).

## 3 · Método (Julia, `deepseek/DS6/src/analisis.jl`)

1. **Ajuste MLE cerrado de Pareto Tipo I** (no la parametrización de Clauset-Shalizi-Newman, que
   difiere en un `+1`; se verificó la convención exacta leyendo
   `P-ZRX/P-DISUASION/DS3/src/modelo.jl` líneas 45-153: `pdf(f) = dist_alpha·f_min^dist_alpha /
   f^(dist_alpha+1)`, la misma que `Distributions.Pareto` de Julia/Wikipedia). Con `x_min` conocido:
   `dist_alpha_hat = n / Σ ln(x_i/x_min)` (fórmula clásica, cerrada, exacta).
2. **Dos ajustes, declarados por separado:**
   - **Global**: `x_min` = mínimo observado (1 punto), cubre **todo** el rango — es la lectura
     literal de H3 (una sola Pareto para toda la población). Bondad de ajuste **mala**
     (`KS=0,397`, muy por encima del valor crítico `≈1,36/√2453=0,027`): **una sola ley de potencia
     NO describe bien el rango completo** (probable efecto de piso por granularidad de plot/pool).
   - **Cola óptima** (Clauset-Shalizi-Newman 2009, adaptado): se barre `x_min` sobre los valores
     únicos observados, se exige cola ≥50 puntos, se minimiza el estadístico KS entre la CDF
     empírica y la Pareto ajustada. Resultado: `x_min=18.339` puntos (≈90,8 TiB), `n_cola=906`
     (37 % de la muestra), `KS=0,039 < 0,045` crítico: **no se rechaza** que la cola de los
     granjeros grandes siga una Pareto con este exponente.
3. **Intervalo:** bootstrap no paramétrico (remuestreo con reemplazo de la cola, 5.000 réplicas,
   semilla fija `0x5a5a`, la misma que usa DS-3 para comparabilidad; `Random.Xoshiro`, Julia 1.13.0
   determinista en esta versión). IC percentil 2,5–97,5 %.
4. **Traducción a `B(ε)`:** se implementaron **las dos fórmulas ya existentes en el propio código de
   DS-3/P-CLAVE**, citando línea exacta:
   - La que usa DS-3 por defecto (`masa_prob`, rama `F_max=∞`, `DS3/src/modelo.jl:139-148`):
     `B(ε) = 1 − (f_min/x)^(dist_alpha−2)`, **exige `dist_alpha>2`**.
   - La general truncada (`F_max=1`, la misma función, rama no-infinita, y la definición de H3 en
     `MODELO.md` §3: "Pareto truncada [10⁻⁸,1]"): `B(ε) = (x^b − f_min^b)/(F_max^b − f_min^b)`,
     `b=2−dist_alpha`, válida para cualquier `dist_alpha≠2`.
   - **Autocomprobación obligatoria antes de usar datos reales:** con `dist_alpha=2,2` (el valor
     base de `escenarios.tsv`), `ε=0,01`, `T_v=3.600`, `λ=1`, `f_min=10⁻⁸`, la fórmula no truncada
     da `B(ε)=0,675466`, **idéntico** al publicado en `DS3/resultados/comprobaciones.csv` (caso
     §4.4). La implementación de este informe está verificada contra la de DS-3 antes de aplicarla
     a los datos de Chia.
5. **Presupuesto declarado (LINEO §7):** 1 hilo, <1 GiB RAM, unos MiB de disco; tiempo real de
   ejecución `0,49 s` para `n=2.453`, rejilla de `x_min` de hasta 2.453 candidatos y 10.000
   réplicas de bootstrap (2×5.000) — no se necesitó paralelismo ni GPU; medido con `time`, no
   supuesto.

## 4 · Resultado numérico y traducción a DS-3

Con la fórmula truncada (la única definida en el régimen que sugieren los datos reales):

| Ajuste | `dist_alpha` (IC95) | `B(ε=0,01; T_v=3.600)` | `B(ε=0,01; T_v=100.000)` |
|---|---|---:|---:|
| Global | 0,1113 [0,110; 0,112] | `3,2·10⁻¹¹` | `3,2·10⁻¹⁶` |
| Cola óptima | 0,8560 [0,810; 0,907] | `4,4·10⁻⁷` | `4,4·10⁻¹²` |
| *(referencia, H3 de DS-3)* `2,2` | — | `0,6755` | — |

Frente al criterio de grieta de DS-3 (§4.4: `B(ε) > 1−2·α_atacante`, con `α_atacante∈{0,20; 0,25;
0,33; 0,40}` ⇒ umbral entre `0,20` y `0,60`): con **cualquiera** de los dos ajustes reales, en punto
y en todo el intervalo de confianza, `B(ε)` queda entre 6 y 11 órdenes de magnitud **por debajo**
del umbral. La curva completa (`resultados/traduccion-grieta.csv`) muestra el cruce donde `B(ε)`
empezaría a importar (`≳0,2`) recién en `dist_alpha≈1,9–1,95` — **todavía por debajo** del extremo
inferior que DS-3 barrió (`2,05`), y muy lejos de los `0,11–0,86` observados aquí. La conclusión no
depende de afinar la cifra: hace falta un cambio de **más de un orden de magnitud** en `dist_alpha`
para que `B(ε)` deje de ser, a efectos prácticos, cero.

**Nota estructural sobre el propio código de DS-3:** su fórmula por defecto (`F_max=∞`) **no está
definida** para `dist_alpha≤2` — devuelve `NaN` (columna `no_truncada_DS3`, `grieta=NC` en el CSV).
DS-3 nunca probó un régimen ni remotamente cercano al que sugiere la única red real medida. La
fórmula truncada que sí cubre este régimen ya existe en el mismo archivo (`P-CLAVE`, rama general de
`masa_prob`), solo no es la que `masa_espacio_bajo_b` llama por defecto.

## 5 · Qué implica para el castigo de DS-3 (M3+M5, ataque A1)

DS-3 (`REVISION-DS3.md`, `INFORME.md` §4.1) concluyó que el castigo con evidencia (M3+M5) **no
muerde nunca** contra el doble farmeo: el atacante cruza la deriva reclutando el espacio que
necesita (`β_d≤0,585`) enteramente entre claves de saldo confiscable cero, porque `B(ε)=0,675 >
0,585` bajo H3 (`dist_alpha=2,2`, sin medir). Ese resultado **depende por completo** de que la
distribución real sea tan poco concentrada como `dist_alpha≈2–3` (muchas claves pequeñas que juntas
representan más de la mitad del espacio total).

**La única red real que se pudo medir contradice esa hipótesis, y por un margen grande:** en
`SpaceFarmers.io`, ni la distribución completa (`dist_alpha≈0,11`) ni, más relevante todavía, la
cola que sí se ajusta razonablemente bien a una ley de potencia (`dist_alpha≈0,86`, granjeros
≥90 TiB) se acercan al rango `2,05–3,0`. Con cualquiera de los dos, `B(ε)≈0`: **casi todo el espacio
de la red real está concentrado en manos de pocos tenedores grandes, y prácticamente nada de espacio
vive en claves con saldo por debajo del umbral de confiscación.** Si ZEROX se pareciera a esta red
real (una hipótesis en sí misma, ver reservas), **la grieta de P-CLAVE se cierra**: el atacante ya
NO podría reclutar el `β_d` que necesita a coste cero, porque no hay suficiente espacio acumulado en
claves "baratas" para llegar a `β_d≈0,28–0,58`. El castigo M3+M5 **volvería a morder**.

**Esto no cierra la pregunta, la invierte y la deja abierta con más urgencia:** antes de DS-6, H3 era
una hipótesis sin ningún dato; ahora hay un dato real, de una red de espacio de producción, y apunta
en la dirección **opuesta** a la que DS-3 usó como escenario central. Con una sola red medida y con
las reservas del §6, esto **no reemplaza** la necesidad de medir ZEROX quando exista; pero sí cambia
la carga de la prueba: el escenario que DS-3 trató como el default (`dist_alpha∈[2,05;3,0]`) queda
ahora como el que necesita justificarse, no al revés.

## 6 · Reservas

1. **Una sola red, un solo pool.** No hay una segunda red con datos por clave (Autonomys no los
   publica en un listado accesible dentro de este presupuesto). La pregunta pedía "al menos una":
   se cumple, pero con `n=1` a nivel de red no se puede promediar ni descartar que Chia sea un caso
   atípico.
2. **Pool ≠ red completa.** Sesgo declarado en §2: probablemente subrepresenta la cola derecha real
   (los más grandes no usan pools públicos), lo que si acaso **subestima** `dist_alpha` observado
   aún más de lo medido — refuerza, no debilita, la conclusión de que el rango 2,05–3,0 es
   demasiado alto.
3. **Analogía, no medición de ZEROX.** `dist_alpha` es una propiedad adimensional (invariante de
   escala) de la forma de la distribución, así que no depende de que Chia y ZEROX midan el espacio
   en las mismas unidades — pero sigue siendo una **hipótesis de analogía estructural** (mismo tipo
   de recurso, PoSpace, con economías de escala e incentivos de hardware similares) hacia una red
   que **no existe todavía en producción**. No es una medición directa de ZEROX ni puede serlo hoy.
4. **El ajuste global es un mal ajuste de Pareto** (`KS=0,397`): la población completa de granjeros
   pequeños probablemente no sigue una sola ley de potencia (más bien algo con un "piso" cerca del
   tamaño mínimo de parcela/pool). El ajuste de **cola** (`dist_alpha≈0,856`, buen ajuste, `KS=0,039`
   dentro del crítico) es la cifra estadísticamente más defendible; el ajuste global se publica
   igual, íntegro, porque es la lectura literal de "una sola Pareto para toda la población" que pide
   H3, y porque ambos ajustes —el bueno y el malo— dan la misma conclusión cualitativa.
5. **Un mismo operador, varias claves.** Este informe no puede distinguir si un `launcher_id`
   pequeño es un operador genuinamente pequeño o un fragmento de uno grande (relevante para el
   propio modelo de amenaza de Sybil/A4, no solo para H3): si hay fragmentación deliberada, la cola
   de "claves pequeñas" observada en la práctica podría ser aún más numerosa (más `count`) sin que
   eso cambie el resultado de `dist_alpha` en `space`, que es lo que pesa en `B(ε)`.

## 7 · Reproducción

```bash
export PATH=/home/katana/torio/.juliaup/bin:$PATH
export JULIA_DEPOT_PATH="/home/katana/zeo/ZEROX/deepseek/DS6/.julia-depot"
cd /home/katana/zeo/ZEROX/deepseek/DS6
env -u LD_LIBRARY_PATH julia src/analisis.jl
```

**Rutas de entrega:**
- Este informe: `deepseek/DS6/INFORME.md`.
- Datos crudos con checksum: `deepseek/DS6/crudo/farmers-pages/*.html` (247 páginas),
  `deepseek/DS6/crudo/farmers-raw.csv` (extracción), `deepseek/DS6/crudo/SHA256SUMS.txt`
  (263 archivos), `deepseek/DS6/crudo/page_home.html` (netspace del pool), páginas de contexto
  (`sf-apidocs.html`, `autonomys_consensus.html`, etc.).
- Código y resultados: `deepseek/DS6/src/analisis.jl`,
  `deepseek/DS6/resultados/{resumen-ajuste.csv, traduccion-grieta.csv, muestra-limpia.csv, RUN.log,
  SHA256SUMS-resultados.txt}`.

---

# Corrección A (2026-09-26) — convención del exponente y `B(ε)` empírico directo

**Motivo:** `CORRECCION-DS6-A.md` (director). Dos fallos en la entrega anterior de este mismo
informe: (1) confundí el exponente de la **cola** (lo que ajusta `mle_pareto`/`ks_pareto` de
`analisis.jl`, que fitea `CCDF=(xmin/x)^α`) con el exponente de la **densidad** que exige
`masa_prob` de `DS3/src/modelo.jl` (`p(f)∝f^{-α}`, `b=2-α`, «`α≤2`: `E[f]` diverge» — eso solo es
cierto si `α` es el exponente de la densidad, no el de la cola); (2) no calculé `B(ε)` directamente
sobre los datos, solo a través de una ley ajustada.

## A.1 · La convención correcta (verificada por rederivación, no solo por confianza en el director)

Rederivé `M(x)=E[min(f,x)]/E[f]` desde cero para una densidad general `p(f)=c·f^{-g}` (sin asumir
qué es `g`): integrando, `E[f]` converge solo si `g>2`, y `M(x) = 1-(f_min/x)^{g-2}` — **exactamente**
la fórmula de `masa_prob` con `dist.alpha=g`. Y la CCDF que resulta de esa misma densidad es
`P(F>f)=(f_min/f)^{g-1}`, es decir: **el exponente de la cola que ajustan `mle_pareto`/`ks_pareto`
de `analisis.jl` es `g-1`, no `g`.** Por tanto:

```
dist_alpha (convención de masa_prob, DENSIDAD) = alpha_cola_hat (mi MLE de analisis.jl) + 1
```

El director tiene razón y mi entrega anterior no. La autocomprobación contra el checkpoint de DS-3
(`B(eps=0.01,Tv=3600,dist_alpha=2.2)=0.675466`) seguía pasando en ambas versiones porque es una
prueba de que **la fórmula está bien transcrita**, no de que la conversión cola↔densidad sea
correcta; no la detectaba.

## A.2 · `B(ε)` con la convención corregida

| Ajuste | `alpha_cola_hat` (IC95, sin cambios) | `alpha_dens_hat = alpha_cola+1` (IC95) | `B(ε=0,01; Tv=3.600)` corregido |
|---|---|---|---:|
| Global (todo el rango, mal ajuste KS=0,397) | 0,1113 [0,110; 0,112] | **1,111** [1,110; 1,112] | `1,15·10⁻⁵` [`1,13·10⁻⁵`; `1,16·10⁻⁵`] |
| Cola óptima (906 granjeros ≥90,8 TiB, buen ajuste KS=0,039) | 0,8560 [0,810; 0,907] | **1,856** [1,810; 1,907] | **`0,0947`** [`0,0593`; `0,1511`] |

La cifra de la cola óptima reproduce la del director (`≈0,095 [0,060;0,151]`) con una diferencia de
redondeo de milésimas. Tabla completa (los dos `T_v`, los tres `ε`, ambas fórmulas) en
`resultados/correccionA-Beps-corregido.csv`.

**Sigue habiendo una discrepancia estructural, ahora más nítida:** `alpha_dens_hat≈1,86` (cola) o
`≈1,11` (global) están **por debajo de 2** en el sentido estricto que exige la fórmula NO truncada
de DS-3 (`E[f]` divergente); solo la versión truncada (`F_max=1`, ya presente en el mismo código de
P-CLAVE) da un número. Esto no cambia con la corrección de convención: sigue siendo cierto que **el
exponente real medido cae fuera, o en el borde, del régimen que la fórmula por defecto de DS-3
cubre** (H3 barre `dist_alpha∈[2,05;3,0]`, todo `>2`; el dato real da `[1,11;1,86]`, todo `≤2`).

## A.3 · `B(ε)` EMPÍRICO directo (sin ajustar ninguna ley)

Definición aplicada literalmente: para cada `(T_v,ε)`, `x=ε/(λT_v)` (fracción de un denominador de
red); `B(ε) = (Σ tib_i para los granjeros con tib_i < x·denom_tib) / denom_tib`, sobre los 2.453
granjeros limpios de `resultados/muestra-limpia.csv`. Intervalo por *bootstrap* de granjeros (5.000
réplicas, remuestreo con reemplazo, semilla `0x5a5a`). Dos denominadores, declarados por separado:

- **`pool`** (primario, autocontenido): la suma de la propia muestra, `590.182 TiB` = `576,35 PiB`
  — coincide con el `576,07 PiB` que muestra el sitio (0,05 % de diferencia, ambos del
  2026-09-26). No depende de ninguna fuente externa.
- **`red`** (secundario, banda de sensibilidad declarada como incompleta): intenté obtener el
  *netspace* de Chia en vivo con fecha 2026-09-26 (`spacescan.io`, `xchscan.com`,
  `chiaexplorer.com`, `dashboard.chia.net`) y los cuatro devolvieron `403`/`302`/contenido solo-JS
  sin el número — **no hay una cifra en vivo verificada dentro del presupuesto de 45 min de esta
  corrección**, así que se declara y se usa una banda amplia (`1 EiB` a `36,73 EiB`, el pico
  histórico) en vez de inventar un punto. La única cifra con fecha que sí se encontró
  (`crudo/page_home.html` no aplica aquí; ver §1 del informe original) es secundaria y de agosto de
  2026, no de la fecha de descarga: XCH.today/LowEndBox, «efectivo <4 EiB, bruto real probablemente
  <3 EiB».

**Tabla principal (`ε=0,01`, `T_v=3.600`, el caso base de DS-3):**

| Denominador | `denom` | `B_emp(ε)` | IC 95 % bootstrap |
|---|---:|---:|---|
| pool (576 PiB, primario) | 590.182 TiB | `1,78·10⁻⁴` | `[1,49·10⁻⁴; 2,08·10⁻⁴]` |
| red, 1 EiB (piso especulativo) | 1.048.576 TiB | `2,17·10⁻⁴` | `[1,84·10⁻⁴; 2,52·10⁻⁴]` |
| red, 3 EiB (XCH.today, bruto) | 3.145.728 TiB | `3,95·10⁻⁴` | `[3,48·10⁻⁴; 4,47·10⁻⁴]` |
| red, 4 EiB (XCH.today, efectivo) | 4.194.304 TiB | `5,10·10⁻⁴` | `[4,57·10⁻⁴; 5,66·10⁻⁴]` |
| red, 36,73 EiB (pico histórico) | 38.514.196 TiB | `1,42·10⁻³` | `[1,35·10⁻³; 1,49·10⁻³]` |

Rejilla completa (`T_v∈{3.600;100.000}`, `ε∈{0,001;0,01;0,1}`, 6 denominadores) en
`resultados/correccionA-Beps-empirico.csv`. El máximo absoluto de toda la rejilla es `0,0144`
(`ε=0,1`, `T_v=3.600`, denominador `4 EiB`) — **ni en el escenario más favorable a que la grieta
exista `B_emp` se acerca al umbral más bajo (`0,20`)**.

## A.4 · Veredicto de la grieta por `α_atacante`, con margen (`eps=0,01`, `T_v=3.600`)

`margen = B(ε) − (1−2·α_atacante)`; margen negativo = grieta **cerrada** (el castigo M3+M5 muerde).

| `α_atacante` | umbral `1−2α` | `B` ajuste cola corregido (0,0947) | margen | `B` empírico (denom. pool, 1,78·10⁻⁴) | margen | Grieta |
|---:|---:|---:|---:|---:|---:|---|
| 0,20 | 0,60 | 0,0947 | **−0,505** | 0,000178 | **−0,600** | **CERRADA** |
| 0,25 | 0,50 | 0,0947 | **−0,405** | 0,000178 | **−0,500** | **CERRADA** |
| 0,33 | 0,34 | 0,0947 | **−0,245** | 0,000178 | **−0,340** | **CERRADA** |
| 0,40 | 0,20 | 0,0947 | **−0,105** | 0,000178 | **−0,200** | **CERRADA** |

**Con las dos vías —la ley corregida y el cálculo empírico directo, en el punto y en todo el
intervalo de confianza, con cualquiera de los seis denominadores de red probados— la grieta
queda cerrada para los cuatro `α_atacante` que usa DS-3.** El margen más pequeño (más cerca de
abrirse) es `−0,105` (ajuste de cola, `α_atacante=0,40`); el empírico nunca se acerca: su máximo en
toda la rejilla (`0,0144`) sigue dejando un margen de al menos `−0,186` contra el umbral más bajo.

**Esto reafirma, con números corregidos, la lectura cualitativa del informe original (aunque los
números en sí eran incorrectos por la convención): con el único dato real disponible, el castigo
M3+M5 volvería a morder frente a A1, en vez de quedar neutralizado por la grieta que asume H3.**

## A.5 · Sesgos (obligatorio, además de los del §6 original)

1. **Pool ≠ red — dirección del sesgo en el cálculo empírico.** `B_emp` con denominador `red` es un
   **mínimo, no una medición completa**: solo suma el espacio de los granjeros de ESTE pool que
   caen bajo el umbral; los granjeros pequeños de otros pools y los que minan en solitario no están
   en la suma. El verdadero `B(ε)` de toda la red **podría ser mayor** que el reportado aquí (más
   claves pequeñas en total), pero para acercarse siquiera al umbral más bajo (`0,20`) haría falta
   que el espacio pequeño **fuera de este pool** sumara más de mil veces lo que suma dentro de él —
   un salto que ninguna fuente consultada sugiere.
2. **Denominador de red sin verificar en vivo.** La banda `1–36,73 EiB` es deliberadamente ancha
   porque no se pudo confirmar un número con fecha 2026-09-26; aun así, el resultado cualitativo
   (grieta cerrada) es el mismo en los seis puntos de la banda, incluido el extremo más favorable a
   abrir la grieta (el denominador más grande, que hace `B_emp` más chico, así que en realidad el
   denominador **más pequeño** —`pool`, `1,78·10⁻⁴`— ya es el caso menos favorable a la grieta
   cerrada entre los probados, y aun así cierra con margen `−0,600` a `−0,200`).
3. **El ajuste de cola sigue siendo el más defendible estadísticamente** (`KS=0,039`, dentro del
   crítico) frente al global (`KS=0,397`, mal ajuste) — se repite la reserva del informe original:
   ninguna Pareto única describe bien TODO el rango.
4. **El empírico y el ajustado no miden lo mismo.** El empírico es **conservador por diseño**: solo
   cuenta el espacio que YA se observó por debajo del umbral en este pool (no extrapola). El ajuste
   de cola (`0,0947`) es mayor porque extrapola la forma de la cola grande hacia tamaños pequeños
   que la propia cola no describe (de hecho la corrección §2 de la orden ya avisa: `B(ε)` depende de
   las claves pequeñas, "justo las que el ajuste de la cola no describe"). Que **ambos, el
   conservador y el extrapolado, den grieta cerrada** es lo que hace la conclusión robusta: no
   depende de cuál de los dos métodos se prefiera.

## A.6 · Reproducción

```bash
export PATH=/home/katana/torio/.juliaup/bin:$PATH
export JULIA_DEPOT_PATH="/home/katana/zeo/ZEROX/deepseek/DS6/.julia-depot"
cd /home/katana/zeo/ZEROX/deepseek/DS6
env -u LD_LIBRARY_PATH julia src/correccion-a.jl
```

**Rutas añadidas:** `deepseek/DS6/src/correccion-a.jl`,
`deepseek/DS6/resultados/{correccionA-Beps-corregido.csv, correccionA-Beps-empirico.csv,
RUN-correccionA.log}`, `deepseek/DS6/SHA256SUMS-correccionA.txt`. Datos crudos reutilizados: los
mismos de `crudo/` (sin descargas nuevas de granjeros; se intentaron y fallaron las de netspace de
red, declarado en A.3, sin archivos nuevos que guardar porque las respuestas fueron `403`/`302`/HTML
sin el dato).
