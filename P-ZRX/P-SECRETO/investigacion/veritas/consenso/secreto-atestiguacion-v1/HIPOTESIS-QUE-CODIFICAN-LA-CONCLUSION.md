# HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md — secreto-atestiguacion-v1

Cada hipótesis declara qué cifra del INFORME la necesita. Etiquetas: `demostrado`,
`verificado en fuente`, `medido`, `derivado`, `estimado`, `propuesto`, `no verificado`.

## H1 · El sorteo es por slot y determinista — `derivado de SPEC`
Las k plazas del bloque de slot `s` se sortean de la salida del PoT de ese slot
(`salida(f, s)`, C-POT-02), con `f` el flujo del bloque (función de `past(B)`,
C-FLU-10/13). El sorteo es una función determinista de `past(B)`: ninguna cifra de
este instrumento depende de la vista del nodo (§4.5 del PROMPT se respeta por
construcción). *Necesita:* todos los resultados de captura y viveza (F3, F4).

## H2 · Muestreo con reemplazo como cota alcanzable del atacante — `demostrado`
El teorema de identidad (`research/dag-poas-balizas-auditoria.md` §2, `verificado en
fuente`) permite partir el espacio en claves gratis: la captura sin reemplazo tiende
a α^k desde abajo. El instrumento publica ambas (con reemplazo exacto; sin reemplazo
exacto con M = 1000) y la cota es la de reemplazo. *Necesita:* F3-captura.

## H3 · Independencia reto/sorteo (S4) — `propuesto`
`reto(f,s) = blake3(aleatoriedad(f,s) ‖ s)` (C-POT-03) y el sorteo son funciones de
hash distintas de la misma salida del PoT; se tratan como independientes. Sin esta
hipótesis la captura de cadena NO factoriza en α^d·α^(kd). *Necesita:* F3-cadena.
*Dirección:* si no fueran independientes, el peor caso es el atacante jugando con la
correlación; la conclusión cualitativa (captura de cadena astronómicamente pequeña)
no depende de ella porque ambos factores van en el exponente.

## H4 · Disponibilidad y silencio como entradas — `no verificado`
`p_disponible` (fracción de honestos encendidos y respondiendo) y `p_sil` (prob. de
que un firmante honesto guarde silencio sobre lo firmado) son ENTRADAS, no se fijan.
Son las mismas magnitudes que mataron la capa de comité descartada
(`research/dag-poas-capa-finalidad.md` §4.C: «la p real de un granjero doméstico…
sin ella la viveza es una conjetura»). *Necesita:* F4-viveza, F4-soborno.

## H5 · El firmante honesto puede elegir V1 (firmar a ciegas) — `derivado`
Nada verificable distingue una firma sobre un hash presentado (V1) de una firma de un
bloque visto (V2). La infalsificabilidad de la atestiguación es política del firmante,
no propiedad de la condición de validez. *Necesita:* la respuesta a F1 entera.

## H6 · Latencia por enlace lognormal de DMS-v0.1 — `medido`
Lognormal por enlace no dirigido, mediana 80 ms / p99 500 ms
(`veritas/finalidad/delta-medido-v1/INFORME.md:44`); Δ_99 p99 = 0,26–0,60 s (§11.2-11.3);
τ = 1 s nominal. *Necesita:* F4-latencia.
**H6a** · Tramo productor↔firmante de h saltos de overlay — `derivado, no medido`
DMS-v0.1 propaga hop-by-hop con ~5,6 saltos extremo a extremo (C-NET-26); la distancia
media a un nodo aleatorio es h ≈ 2–3. El instrumento publica h ∈ {1, 2, 3}; h = 1 es
la cota optimista (conexión directa). *Necesita:* F4-latencia (es la hipótesis que
decide cuantitativamente F4).
**H6b** · Tramos de ida y vuelta independientes — `propuesto`
T_col = Σ de 2h enlaces iid. El modelo anterior («el doble de un enlace») es más
optimista y se retiró durante la verificación.

## H7 · La ponderación por espacio exige tabla de poder derivada — `verificado en fuente`
PoST no registra a nadie; el sorteo ponderado exige la maquinaria R-FIN-15
(`research/dag-poas-capa-finalidad.md` §3: tabla derivada de bloques pagados, W_VIVO).
Esa tabla es manipulable por el atacante (el problema D8 de aquella propuesta,
`research/dag-poas-capa-finalidad.md` §4.D, sin cerrar). El modelo supone ponderación
fiel por espacio real. *Necesita:* la lectura de F3 y la comparación con la capa
descartada (F5).

## H8 · El sorteo no es grindable mientras el flujo sea honesto — `derivado`
Con partición de flujo (C-FLU-22, d < F_slots) el atacante puede re-elegir ancla →
flujo → sorteo: el steering de la capa de comité (m anclas → m sorteos; m medida 2,955,
cota 151). Multiplica la captura por ~m, no cambia la conclusión (exponentes −3435…).

## H9 · Las identidades de billete no cambian este análisis — `verificado en fuente`
Ninguna cifra de este instrumento depende de la identidad de billete (C-GD-07 vs
IDV-01): la atestiguación es sobre bloques, no sobre oportunidades.

## Controles anti-tautología (PROMPT §6)
Rutas independientes por cifra: enumeración exhaustiva de sorteos (N^k secuencias
ponderadas) para captura/viveza/partición; enumeración de reto×sorteos por slot para
la cadena; enumeración multinomial (3 resultados por plaza) para la fuga; bolas de Arb
(128 bits) para la lognormal; convolución de Simpson (F_1 exacta) ↔ Monte Carlo
Philox4x con semillas no consecutivas (splitmix64) e IC de Wilson 99 % para la
latencia multihop; superficie α* contra la identidad de P-PRESTAMO con g(α*) = 0
exacto y signo estricto a los dos lados. Rutas NO independientes (declaradas):
«F(mediana) = 0,5» y «F(p99) = 0,99» son identidades de la parametrización (plomería,
no evidencia); la identidad (α^k)^d = α^(kd) se sustituyó por anclas de constantes
independientes (log10 = −(k+1)·d·log10(3)).
