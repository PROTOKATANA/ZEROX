# HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION

Qué supone **cada pieza de código** del enumerador y **qué conclusión se caería** si el supuesto
fuese falso. Es el documento que permite revisar el trabajo por dentro: si algo de aquí no se acepta,
la conclusión afectada hay que volver a calcularla, no matizarla.

Ruta del instrumento: `veritas/consenso/equivocacion-v1/` (dentro de
`P-ZRX/P-EQUIVOCACION/investigacion/`).

---

## 1 · Supuestos de modelo, con su alcance

| # | Supuesto | Dónde vive | Si fuese falso, se caería |
|---|---|---|---|
| H1 | **El flujo se representa por su preimagen canónica** `[(entropía_j, t_j)]` y se compara estructuralmente, sin hashear (`C-FLU-10`). | `src/modelo.jl` (`inyecciones`, `flujo_slot`), `src/rapido.jl` (`flujos_iguales`) | Nada del orden de las conclusiones: sustituir la lista por `SHA3-256` sólo añade colisiones. Lo que **sí** cambiaría es que dos flujos distintos con la misma lista dejarían de existir — ya se comparan por la lista completa. **No hay dependencia criptográfica.** |
| H2 | **`entropía_j = (chunk(I_j), slot(I_j))`** en vez de `blake3(chunk ‖ pot_output)` (`C-FLU-12`). | `src/modelo.jl` (`entropia_ancla`) | Las igualdades/desigualdades de flujo. Se conserva el invariante de no-equivocación (dos copias del mismo billete dan la misma entropía y el mismo `t_j`), que es lo único que el modelo usa. Si el invariante se rompiera, `P3` dejaría de valer. |
| H3 | **`blue_work = blue_score` (peso 1 por bloque)** en la rejilla; el peso exacto `⌊2^128/(SR+1)⌋` está implementado (`peso_bloque`) y **comprobado en los tests**, pero la rejilla usa `SR` constante. | `src/modelo.jl`, `test/runtests.jl` | `P5` (`n_priv > n_com`). Con `SR` variable, la comparación pasa a `Σ w` y el criterio es **la misma desigualdad con pesos**: cambiaría el conteo, no el enunciado. La rejilla **no** cubre retarget. |
| H4 | **`blue_score`/`blue_work` usan el APORTE (`sp` + candidatos aceptados)** y no el conjunto azul acumulado (`C-GD-08`, «`blues(B)` incluye a `sp(B)`»). | `src/modelo.jl`, `src/rapido.jl`, `src/referencia.jl` | Nada cualitativo: la otra lectura duplica el peso de la herencia en **todos** los bloques por igual, y todas las comparaciones son entre bloques del mismo DAG. Cambiaría `n_com`/`n_priv` como medidas, no como comparación. Se declara porque el texto del SPEC admite las dos lecturas. |
| H5 | **Anticono = bloques INCOMPARABLES** (`!(y ∈ past(x)) ∧ !(x ∈ past(y))`), no sólo una de las dos condiciones. | los tres ficheros de kernel | **Todo el coloreo y por tanto `Chn(V_j)`.** Es el único sitio donde apareció un fallo real durante la construcción: `src/referencia.jl` tenía la condición asimétrica y **discrepaba** del kernel en DAGs aleatorios hasta corregirlo. Queda como regresión (1 200 DAGs, 4 familias). |
| H6 | **Contexto del k-cluster = conjunto azul acumulado**; «todo `y` del anticono es azul» (`anti ⊆ ctx`), y «llega a k con él dentro» = `|anticono(y) ∩ ctx| + 1 ≥ k`. | `src/modelo.jl`, `src/rapido.jl`, `src/referencia.jl` | El color de los candidatos del mergeset y, con `k` pequeño, `blue_work`. **Con `k = 30` y los DAGs pequeños de la rejilla nada es rojo por k-cluster**, así que las conclusiones de κ **no dependen** de esta interpretación; sólo el test de `k = 1`. |
| H7 | **U3″ se comprueba contra el contexto azul acumulado** (lectura que hace a U3″ efectiva dentro de una rama, como mide CRP-v0.1 §6). | `src/modelo.jl`, `src/rapido.jl`, `src/referencia.jl` | El test de U2/U3″ y, si se usara con billetes repetidos, `blue_work`. La rejilla usa billetes únicos por rama, así que **no afecta a κ**. |
| H8 | **El predicado de elegibilidad es sintético:** `mezcla64(chunk, prueba, reto) ≤ rango`, con `rango` como **parámetro** que fija `m`, la media de ganadoras por slot. | `src/espectro.jl` (`mezcla64`, `elegible`, `rango_para_media`) | **Toda la parte de κ por identidad.** El modelo **no** reproduce la distancia circular ni KZG; reproduce la **estructura** del par (identidad, elegibilidad). Lo que κ mide —qué pares de soluciones comparten identidad— depende de la **cardinalidad** (`m`) y de qué campo distingue (pieza vs `chunk`), no del valor concreto del reto. Si se quisiera una cifra de κ en red, este predicado **no basta**: hay que sustituirlo por el verificador PoAS real (`prototipos/poas-identidad/`). |
| H9 | **Candidatas = (pieza, `chunk`, prueba) independientes**, con `chunk` propio de cada pieza. | `src/espectro.jl` (`Universo`) | La tabla de identidades. La primera versión compartía los valores de `chunk` entre piezas y **colapsaba artificialmente** la identidad de `C-GD-07`, invirtiendo el signo de la comparación. Corregido y dejado como regresión. |
| H10 | **Slots de doble farmeo `W` = slots con bloque propio en las DOS ramas** (intersección de los conjuntos de slots propios). | `src/espectro.jl` (`slots_rama`, `kappa`) | `κ_flujo` y `κ`. Es la lectura conservadora: un slot donde sólo una rama tiene bloque **no** se cuenta como doble farmeo. Contar todo `[s₀, mín(punta)]` daría a lo sumo más slots en el numerador y el denominador; no cambia `P3` ni `P5`. |
| H11 | **La ventana de reorganización se comprueba, no se supone:** cada fila de la rejilla exige `slot(punta) − s₀ < F` en las dos puntas (`C-FIN-01`). | `src/rejilla.jl`, `run.jl` | κ. Las 480 configuraciones publicadas están **dentro** de la ventana (columna `ventana = true`). |
| H12 | **El DAG se construye con dos ramas explícitas y una fusión a `P`.** El «patrón de retención» es la forma del DAG. | `src/modelo.jl` (`construir_dos_ramas`), `src/rejilla.jl` | La alcanzabilidad de las configuraciones. Es un **modelo**, no una simulación de red: no dice qué patrones produce un adversario real ni con qué probabilidad. |
| H13 | **`k = 30` en toda la rejilla.** | `run.jl` | Nada: con DAGs de ≤ 50 bloques y `k = 30` no hay rojos por k-cluster, así que `blue_work` es proporcional al número de azules. Coincide con el `k = 30` del perfil A″ (`SPEC.md` §7.3). |

---

## 2 · Qué comprueba el oráculo y qué no

El oráculo (`src/referencia.jl`) es **independiente en método**, no en especificación:

| Independencia | Cómo |
|---|---|
| I1 | El pasado se recalcula por DFS en cada consulta; **no** usa la caché `Dag.pasado`. |
| I2 | El orden de proceso se recalcula por DFS postorden; **no** usa el orden de ids. |
| I3 | El coloreo usa `Dict` y anticonos explícitos; **no** usa bitsets. |
| I4 | El ancla se calcula con la **formulación alternativa** de R-FIN-1 («menor `blue_work` entre los bloques de la cadena con `slot ≥ T_j`») en vez de «el primer cruce». |

**Lo que el oráculo NO hace:** no comprueba las firmas, no verifica KZG, no calcula el AES del PoT y
no reproduce la red. No es un oráculo de ZEROX: es un oráculo del **modelo**. La equivalencia
comprobada es «las dos implementaciones del modelo coinciden», no «el modelo es el protocolo».

**Cobertura ejecutada:** 1 200 DAGs aleatorios en 4 familias de parámetros (`n` de 10 a 20, `k` de 1
a 5, `jmax` de 3 a 5) más los vectores de regresión, todos con `test/runtests.jl` (**567/567**). El
fallo de anticono de `H5` se detectó con esta malla: sin ella, `P5` habría salido con un criterio
distinto en cada implementación.

---

## 3 · Qué conclusión cuelga de qué

| Conclusión | Cuelga de | Etiqueta |
|---|---|---|
| `P1` (franja de anchura `S_max`) | Reglas `C-GD-04` + `C-HDR-05` **escritas**; no del modelo | `demostrado` |
| `P2` (ancla anterior a la bifurcación) | `L ≥ F` (perfil 1a) + `C-FLU-07` | `demostrado` |
| `P3` (ancla igual ⟹ flujo igual) | `C-FLU-10/12/07` + `H2` | `demostrado` |
| `P4` (contraejemplo) | `H12` (la forma del DAG es alcanzable como **objeto**, no como suceso de red) + `H5` + `H13` | `enumerado` |
| `P5` (condición `n_priv > n_com`) | `H3` (pesos) + `H6` + `C-GD-03` | `demostrado` + `enumerado` |
| `P6` (la divergencia cubre la cola) | `H1`, `H2`, `H10` | `derivado` + `enumerado` |
| `P7` (las identidades no llevan rama ni reto) | **Las definiciones citadas**, no el modelo | `demostrado` |
| `P8` (κ por identidad) | `H8` + `H9` (el predicado de elegibilidad sintético) — **la parte más frágil** | `enumerado` |
| `P9` (región de κ para el modelo económico) | `P6` + `P8` + `D2`, `D4` (pendientes) | `propuesto` |
| Asimetría de la carrera (`INFORME.md` §3, `D3`) | Lectura de `C-FLU-04`; **no medida** | `derivado` |

**La conclusión que hay que revisar primero si se cae un supuesto:** `P8` depende de `H8` y `H9`. Una
cifra de κ para la red **no** sale de aquí: sale de sustituir el predicado sintético por el
verificador PoAS real y de medir la distribución de `m`.
