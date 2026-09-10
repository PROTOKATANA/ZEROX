# D9 · Auditoría adversarial de la ronda d13 — F0a, F0b, F1, F2

**Agente:** D9 · Matemáticas y validación formal · **Fecha:** 2026-09-10
**Mandato:** intentar **refutar** cada número y cada cita de los cuatro informes de
`research/scripts/d13-finalidad/`. No validar: romper. Si no se rompe tras intentarlo en serio,
queda respaldado.
**Alcance:** `f0a-clave-plot.md`, `f0b-anti-equivocacion.md`, `f1-p040-latencia.md`,
`f2-alternativas-latencia.md`, y el instrumento del principal `verifica_d13.py`.
**Restricciones respetadas:** no se modificó ningún fichero de los auditados ni `verifica_d13.py`;
no se ejecutó `git`; los scripts auxiliares de esta auditoría viven en `/tmp/opencode/d9/`.

---

## 0 · Instrumentos y fuentes usadas

| Instrumento | Qué es | Resultado |
|---|---|---|
| `verifica_d13.py` (del principal) | 40 comprobaciones numéricas | **Se ejecutó entero: todos sus PASS son correctos.** Una pega: su fórmula de riesgo anual `1-(1-p)**N` es inestable por cancelación para `p < ~1e-16`; no comprueba la fila de 1e-12, así que no produce ningún PASS falso, pero no debe extenderse a esa zona sin `expm1/log1p` |
| `verifica_d9.py` (mío, mpmath+scipy) | recálculo independiente de POA, binomial, certificado, gossip, ploteo | en `/tmp/opencode/d9/` |
| `prev()` de `r9a_a3_frontera.py:37-49` | re-ejecutado sin modificar | reproduce la tabla de F1 §2.5 **dígito a dígito** |
| Scripts de `finalidad-espacio/` | re-ejecutados enteros | `verif_sorteo.py`, `verif_sesgo_sorteo.py`, `verif_quorum.py`, `verif_certificado.py` |
| Fuentes primarias | `hotpow.txt` (1943 líneas), `fip-0086.md` (1147), `dagknight.txt`, `phantom-ghostdag.txt`, `cap-adaptividad-finalidad.txt`, `lewispye-roughgarden-cap.txt`, `bdk19.txt`, `subspace @ f8842d0`, `chia-blockchain v2.7.4`, `coste-ploteo-medido.md` | leídas en las líneas citadas |
| Web | `arxiv.org/abs/1906.08936` + `ar5iv` (texto completo), `docs.avax.network`, `ethereum.org` | accesibles y citadas |

**Nota sobre mi propio método.** Mi primera pasada del riesgo anual dio `α = 27,3732 %` para
1e-12/año y **estaba mal por mi culpa**: usé `1-(1-p)**N`, que con `p≈5e-19` redondea `1-p` a `1.0`
y devuelve 0 o un salto artificial. Recalculado con `expm1(N·log1p(-p))` y con `mpmath` regularizado,
el valor correcto es **27,049 %**, que es el del informe. Lo dejo escrito: el error fue mío y el
informe tenía razón.

---

## 1 · Tabla maestra de cifras

| # | Afirmación (origen) | Valor del informe | Valor recalculado | Etiqueta |
|---:|---|---|---|---|
| 1 | POA Def. 4, Bitcoin `k=1` (f0b §1.4; `hotpow.txt:403-405`) | 0,2642 | 0,26424112 | **VERIFICADO COMPUTACIONALMENTE** (mpmath+scipy) |
| 2 | POA Def. 4, `k=16/64/256` (f0b §1.4) | 2,762e-4 / 1,272367e-12 / 3,959e-45 | 2,761998e-4 / 1,2723673e-12 / 3,9590424e-45 | **VERIFICADO COMPUTACIONALMENTE** |
| 3 | POA con equivocación libre, `k=16/64/256` (f0b §1.4) | 0,5333 / 0,516624 / 0,5083 | 0,5332551 / 0,5166240 / 0,5083115 | **VERIFICADO COMPUTACIONALMENTE** |
| 4 | POA(64, 128 s)=P[Pois(128)≥128] (f0b §1.4; d12 §B.5) | 0,511754 | 0,51175445 | **VERIFICADO COMPUTACIONALMENTE** |
| 5 | Tabla A.1 del paper (0,0003 / 1,2e-12 / 4e-45) | reproducida | 2,762e-4 / 1,2724e-12 / 3,959e-45 | **VERIFICADO** |
| 6 | Umbral de viveza `p ≥ (2/3)/(1−α)` (f1 §4.2) | 66,7 / 88,9 / 95,2 / 99,5 % | 66,667 / 88,889 / 95,238 / 99,503 % | **DEMOSTRADO** (álgebra) + verificado |
| 7 | P[Bin(4000, α) ≥ 1334], α=0,33 (f1 §3.2) | 0,324 | 0,3243905 | **VERIFICADO COMPUTACIONALMENTE** |
| 8 | Paradas/año a α=0,33 (f1 §3.2) | 340 999 | 340 999,33 (0,3243905·1 051 200) | **VERIFICADO COMPUTACIONALMENTE** |
| 9 | α máx. para riesgo anual < 1e-6 (f1 §3.4) | 28,2 % | 28,2431 % | **VERIFICADO COMPUTACIONALMENTE** |
| 10 | α máx. para riesgo anual < 1e-12 (f1 §3.4) | 27,0 % | 27,0490 % | **VERIFICADO COMPUTACIONALMENTE** |
| 11 | α máx. para riesgo anual < 1e-2 (f1 §3.4) | 29,2 % | 29,2455 % | **VERIFICADO COMPUTACIONALMENTE** |
| 12 | «m=3 casi idéntico a m=1» (f1 §3.4) | — | m=3: 28,1371 % vs 28,2431 % (Δ=0,106 pp) | **VERIFICADO** |
| 13 | Umbral espacio-tiempo `u_h/(2u_a+u_h)`, `u_h=0,80` (f1 §4.4) | 28,6 % | 28,5714 % (0,8/2,8) | **DEMOSTRADO** (álgebra) + verificado |
| 14 | Ed25519 `K=4000`: 4000·66+128 (f1 §6.2) | 264 128 B | 128+4000·(64+2) = 264 128 B | **VERIFICADO** |
| 15 | Ed25519 `K=4000` a 30 s (f1 §6.2) | 277,65 GB/año | 277,6514 GB/año | **VERIFICADO** |
| 16 | BLS `K=4000`: 724 B / 0,76 GB/año (f1 §6.2) | 724 B / 0,76 | 128+96+500 = 724 B / 0,7611 GB/año | **VERIFICADO** |
| 17 | «66 B por firma» (f1 §6.2) | 66 B | 64 B firma Ed25519 + 2 B índice de tabla (`verif_certificado.py:10,14-17`); **la clave pública (32 B) no va en el certificado** | **VERIFICADO** (composición); 128 B de cabecera = **PLAUSIBLE, supuesto** |
| 18 | La fila «Ed25519 K=4000 = 237 728 B / 249,90 GB» de la propuesta es de K=3600 (f1 §6.2) | 237 728 B | `verif_certificado.py:27` solo imprime K∈{100,400,1000,3600}; 128+3600·66 = 237 728 | **REFUTADO el etiquetado de la propuesta; la corrección de F1 es correcta** |
| 19 | Gossip ~3,5 TB/año/nodo a K=4000/30 s (f1 §6.4) | ~3,5 TB | 484 B×K×N = **2,04 TB** (1 voto/miembro); 6,11–8,14 TB (3–4 votos); 2,94–3,37 TB con 200 B×3,5–4 | **PLAUSIBLE, no demostrado**; el 3,5 no está inflado, pero depende de un tamaño de mensaje no medido |
| 20 | Ploteo 64 GiB: 89,2 min CPU / 74,0 min GTX 1070 (f0a §6.1) | 89,2 / 74,0 | 83,608·64/60 = 89,182 / 69,363·64/60 = 73,987 | **VERIFICADO** (medido en `coste-ploteo-medido.md:20-24,189-196`) |
| 21 | 256 sectores: 5,9 h / 4,9 h / 18–42 min (f0a §6.1) | 5,9 / 4,9 / 18–42 | 5,95 / 4,93 / 18,3–42,3 min | **VERIFICADO** |
| 22 | Cuota 64 GiB = 1,9 % de red 10 TiB con α=0,33 (f0a §6.1) | 1,9 % | 64/(0,33·10·1024) = 1,8939 % | **VERIFICADO** |
| 23 | Cuota 64 GiB = 0,019 % de 1 PiB (f0a §6.1) | 0,019 % | 0,01850 % | **VERIFICADO** |
| 24 | Estado del nullifier: 14,7 MB / 64,6 GB-año (f0b §2.1) | 14,7 MB / 64,6 GB | 64·7200·32 = 14,7 MB; 64·31,536e6·32 = 64,57 GB | **VERIFICADO** |
| 25 | Tráfico HotPoW 0,98 TB/año a k=64 (f0b §2.5) | 0,98 TB | 484·64·31,536e6 = 0,977 TB/año | **VERIFICADO** |
| 26 | Parada de P-040: 32,4 / 69,2 / 100 % según m (f1 §3.2, §9) | 32,4 / 69,2 / 100 | 0,3244 (m=1) / **0,6861 (m=2,955 exacto)**; 0,6916 (ceil=3); **0,6693 con m=2,822** / 1,0000 | **VERIFICADO con corrección**: el 69,2 % es `ceil(m)=3`; con el m del diseño vivo (`ancla-de-orden.md:156`: 2,822) es 66,9 % |
| 27 | Origen de m=2,955 (f1 §3.2) | D8 A4.2 | `capa-finalidad.md:210`; el diseño vivo dice **2,822** (`ancla-de-orden.md:156`) | **RESPALDADO POR FUENTE**, con discrepancia de fuente |
| 28 | Origen de m=151 (f1 §3.2) | `m ≤ 1+λ·S_max` | `1 + 1·150 = 151`, `S_max=150 s` (`ancla-de-orden.md:156,167-170,188`) | **DEMOSTRADO** |
| 29 | F1 §2.5 `prev()` (30/134/300/600/1800 s) | tabla completa | reproducida exacta: 6,255e-2 / 6,376e-21 / 1,305e-68 / 3,768e-316 (α=0,10), etc. | **VERIFICADO COMPUTACIONALMENTE** |
| 30 | F1 §4.3 tabla exacta con sortición | 12,9 % a α=0,25/p=0,90; 5,9e-1 a α=0,30/p=0,95; 9,1e-1 a α=0,33/p=0,98 | 12,92 % / 5,855e-1 / 9,093e-1 | **VERIFICADO COMPUTACIONALMENTE** (8 celdas) |
| 31 | K_eff Zipf(1) | 29,6 / 35,8 / 39,6 / 46,7 | 29,61 / 35,76 / 39,63 / 46,72 | **VERIFICADO COMPUTACIONALMENTE** |
| 32 | «3-7 s» como mínimo con Δ≈1 s (f1 §2.3, §9.1) | suelo del protocolo | T_cons = 3–6 s con Δ=1 s (3–4 pasos) es correcto **como ínfimo del consenso**; la latencia end-to-end a cadencia `c` es `T_cons + [0, c]`, con media `c/2 + T_cons` | **REFUTADO como «suelo del protocolo»** (ver §3.2) |
| 33 | F3 real: espera 30–60 s (f1 §2.1) | 30–60 s | la espera es **0–30 s** (el `+2` es relativo al último finalizado, no al bloque); latencia 18–54 s a Δ=6 s | **COTA CORREGIDA** (F1 §2.3 ya da el rango bueno) |
| 34 | Ethereum finalidad ~12,8 min (f2 §3.4) | 12,8 min | 2 épocas × 32 slots × 12 s = 768 s; `ethereum.org` lo confirma | **VERIFICADO** (web) |
| 35 | Avalanche 1,35 s / 3.400 tps (f2 §3.2) | 1,35 s / 3.400 | abstract de arXiv:1906.08936: «3400 tps, 1.35 sec» | **VERIFICADO** (paper) |
| 36 | Avalanche 2.000 AVAX de stake (f2 §3.2) | 2.000 AVAX | `docs.avax.network/docs/primary-network`: «staking at least 2,000 AVAX» | **VERIFICADO** (web) |
| 37 | Avalanche: stake total `$1.689 M`, 46,6 % (f2 §3.2) | $1.689 M | web hoy: **$1.680,7 M** (1,68 B), 46,6 % | **COTA CORREGIDA** (unidades/fecha; el 46,6 % es correcto) |
| 38 | DAGKNIGHT 1,2–12 s (f2 §3.3) | 1,2–12 s | `dagknight.txt:182-197`: D=0,1/1/2 s → 1,2/6/12 s, λ=3,75, α=0,2, ε=0,05 | **VERIFICADO** |
| 39 | GHOSTDAG 70,4 % ≤10 s, 99,9 % ≤10 min, máx 746 s (f2 §3.7) | 70,4 % | `phantom-ghostdag.txt:884-893` | **VERIFICADO** |
| 40 | SPECTRE 21 s (f2 §3.9) | 21 s | `phantom-ghostdag.txt:830-837` | **VERIFICADO** |
| 41 | Autonomys `confirmation_depth_k=100` → ~600 s (f2 §3.8) | 100 bloques, ~600 s | `subspace-runtime-primitives/src/lib.rs:221`; 100×6 s = 600 s | **VERIFICADO** |
| 42 | Suelo 3k/((1−α)λ) = 100–134 s (f2 §3.1) | 100–134 s | 90/0,9=100; 90/0,67=134 | **VERIFICADO** |
| 43 | «0,56·3k ⇒ suelo real ~60–75 s» (f2 §5.2) | 60–75 s | 0,56·90 = **50,4 s**; 0,56·(100–134) = 56–75 s | **COTA IMPRECISA heredada** de `informe-52:560` |

---

## 2 · Matemáticas — recálculo y comparación

### 2.1 POA: la definición y la identidad

La afirmación del encargo («Def. 1 = P[Poisson(k) ≥ 2k]») mezcla dos cosas y conviene precisarla:

- **Definición 1** (`hotpow.txt:281-284`) es la *definición del proceso*: cada evento asigna un ATV
  que vota **una vez por un valor**. No es una fórmula de probabilidad.
- **Definición 4** (`hotpow.txt:305-312`) es la POA: `poa_{P,k}(t) := Pr[P(t) ≥ 2k]`.
- **Corolario 2** (`hotpow.txt:379-386`): en `t̄ = k/λ`, `P(t̄) ~ Poisson(k)` y
  `poa(t̄) = 1 − e^{−k} Σ_{i=0}^{2k−1} k^i/i!`.

Recalculado con `mpmath` (60 dígitos) y con `scipy.stats.poisson` de forma independiente:

| `k` | P[Pois(k) ≥ 2k] (Def. 4) | P[Pois(k) ≥ k] (equivocación) |
|---:|---:|---:|
| 1 | 0,26424112 | 0,63212056 |
| 16 | 2,761998e-4 | 0,53325511 |
| 32 | 4,1444609e-7 | 0,52351169 |
| 64 | 1,2723673e-12 | 0,51662399 |
| 128 | 1,6610742e-23 | 0,51175445 |
| 256 | 3,9590424e-45 | 0,50831148 |

**Clasificación: VERIFICADO COMPUTACIONALMENTE.** Los tres instrumentos (mpmath, scipy,
`verif_quorum_soluciones.py`) coinciden. La Tabla A.1 (`hotpow.txt:1835-1842`) queda reproducida.

**Matiz de interpretación, no de número.** «Equivocación = P[Pois(k) ≥ k]» **no es la probabilidad
de un ataque**: es la POA recalculada con el umbral bajado de `2k` a `k`. La probabilidad de que la
ambigüedad sea *posible* en `T_{P,k}` (tiempo del k-ésimo ATV) es 1, no 0,5166, y el propio f0b lo
dice en su §1.3 (última fila de la tabla). El 0,5166 es una **métrica comparada en el mismo
instante**, no una cota de despliegue. El informe lo advierte; queda bien.

### 2.2 Umbrales de viveza

`(1−α)·p ≥ 2/3` es **condición necesaria** (en esperanza) para que el quórum de ⅔ del total sea
alcanzable; el informe la presenta como «media-campo» y la tabla exacta de §4.3 como la que decide.
El álgebra es trivial y el recálculo coincide en todos los puntos (66,667 / 74,074 / 83,333 / 88,889 /
92,593 / 95,238 / 99,503 %). **DEMOSTRADO** como condición necesaria; la suficiencia la da la tabla
exacta, que también reproduje (8 celdas, coincidencia a 2-3 dígitos).

### 2.3 Riesgo anual BFT: el 27,0 % es correcto

- `P[Bin(4000, α) ≥ 1334]`: umbral exacto porque `A ≥ 1334 ⟺ A/K > 1/3` (con `A=1333` los honestos
  tienen exactamente `ceil(2K/3)=2667` y hay quórum). A α=0,33: **0,3243905**.
- Paradas/año = `p·N = 0,3243905 × 1 051 200 = 340 999,33` → el «340 999» es correcto.
- Riesgo anual = `1−(1−p)^N`. Para los objetivos 1e-12 / 1e-6 / 1e-2, resolviendo con
  `expm1(N·log1p(−p))` y bisección mpmath: **27,049 % / 28,243 % / 29,246 %**. La tabla de F1
  (27,0 / 28,2 / 29,2) es correcta.
- Con `m=3` (best-of-3 anclas) los valores apenas cambian (28,137 % para 1e-6; 26,965 % para 1e-12):
  «casi idéntico porque la cola es vertical» es correcto.
- Con `m=151` para 1e-6: 27,777 % — ya no es «casi idéntico», pero la tabla de F1 es explícitamente
  `m=1` (y dice `m=3`), no `m=151`.

**Autocorrección del auditor.** Mi primera pasada dio 27,3732 % y era un artefacto de
`1-(1-p)**N` (con `p≈5e-19`, `1-p` se redondea a `1.0` en doble precisión). El informe tenía razón.
Este mismo defecto está latente en `verifica_d13.py`; no afecta a sus PASS porque no comprueba esa
fila, pero conviene anotarlo para futuros instrumentos.

**Una pega de modelo, no de número:** la anualización `1−(1−p)^N` supone independencia entre las
1 051 200 instancias. Condicionado a un `α` fijo y con entropía nueva por instancia, las `A_i` son
i.i.d. `Bin(K, α)`, así que la anualización es válida *para α fijo*. Si `α` crece dentro del año, el
número no se sostiene. El informe no lo declara; debería.

### 2.4 Umbral espacio-tiempo

Derivación: peso del atacante `s_a·u_a`, peso honesto `(1−s_a)·u_h`; el atacante bloquea si su peso
≥ ⅓ del total ⟹ `s_a ≥ u_h/(2u_a+u_h)`. Con `u_h=0,8`, `u_a=1`: **28,5714 %**. La tabla completa
(33,33 / 32,20 / 31,03 / 28,57 / 25,93) es correcta. **DEMOSTRADO** sobre el texto de R-FIN-15/17.

### 2.5 Certificado: composición real del 66 B

`verif_certificado.py`:
- línea 10: `ED_SIG, ED_PK = 64, 32` — firma Ed25519 de 64 B y clave de 32 B;
- líneas 14-17: `cert_bytes(K, "ed25519", idx_bytes=2) = CERT_META + K*(ED_SIG + idx_bytes)`;
- línea 12: `CERT_META = 128` — «cabecera del certificado: instancia, tipset, cid tabla, etc.»;
- línea 20: `bls = CERT_META + BLS_SIG_AGG(96) + ceil(K/8)`.

Por tanto **66 B = 64 B de firma + 2 B de índice en la tabla de poder**. La clave pública **no viaja
en el certificado**: el verificador resuelve el índice contra la tabla comprometida por R-FIN-21.
El 128 B de cabecera **es un supuesto del script, no una medida**. Correcto para Ed25519 `K=4000`
(264 128 B, 277,65 GB/año) y BLS (724 B, 0,76 GB/año).

La corrección de F1 sobre la propuesta es correcta y verificada: `237 728 B / 249,90 GB` es la salida
de `K=3600` (`verif_certificado.py:27`), no de `K=4000`. La propuesta (`capa-finalidad.md:170`)
la etiqueta mal.

### 2.6 Gossip: ¿3,5 TB es correcto o inflado?

El informe dice: «`K` miembros × 3-4 mensajes × ~200 B por instancia. A `K=4000` y 30 s:
~0,11 MB/s ≈ 3,5 TB/año por nodo». Recálculo con los dos tamaños relevantes:

| Modelo | TB/año/nodo |
|---|---:|
| Certificado BLS solo (724 B × 1 051 200) | **0,00076** |
| Voto de 484 B (d12 §F.1) × K=4000 × 1/instancia | **2,04** |
| Voto de 484 B × K × 3 fases | **6,11** |
| Voto de 484 B × K × 4 fases | **8,14** |
| Mensaje de 200 B × K × 3,5 (modelo del informe) | **2,94** |
| Mensaje de 200 B × K × 4 | **3,36** |

**Veredicto:** el 3,5 TB no es «inflado»; es la parte alta del propio modelo de 200 B del informe, y
si el mensaje real es un voto de 484 B con 3-4 fases el número sube a 6-8 TB. El orden de magnitud
(TB/año, no GB/año) es lo que sostiene la conclusión —el certificado no es el cuello de botella— y
eso es robusto. Pero **es PLAUSIBLE, no medido**: el tamaño real de un `GossiPBFTMessage` no está en
el FIP y puede ser mayor (las QUALITY llevan la cadena propuesta, hasta 99 tipsets,
`fip-0086.md:654`; las evidencias llevan agregados BLS y RLE de firmantes). A favor del informe: el
FIP permite inferir mensajes de las justificaciones (`:619`), lo que puede reducirlo. Lo correcto es
decir «≥ 2 TB/año y probablemente 3-8 TB/año, sin medir».

### 2.7 Ploteo y castigo de espacio

- 83,608 s/GiB (CPU 32 hilos) y 69,363 s/GiB (GTX 1070): **VERIFICADO** contra
  `coste-ploteo-medido.md:20-24,189-196`. 64 GiB → 89,18 / 73,99 min. 256 GiB → 5,95 / 4,93 h.
- Extrapolación GPU tope: 4,28 s (ALU) / 9,92 s (BW) por GiB (`:229-232`) → 4,57 / 10,58 min para
  64 GiB y 18,3 / 42,3 min para 256 GiB. Correcto.
- Cuota: 64 GiB sobre `0,33×10 TiB` = 1,8939 %; sobre `0,33×1 PiB` = 0,0185 %. Correcto.

---

## 3 · Lógica

### 3.1 F0b: ¿es completa la dicotomía A-D?

El dilema: para volver de `k` a `2k` ATVs, o (A) `π` depende de `x`, o (B) el protocolo impide
reutilizar `π` (registro), o (C) reutilizar `π` se castiga sobre un activo escaso, o (D) el voto es
un objeto escaso atado al valor (el bloque). La frase final —«si `x` no entra en la validez de `π` y
no hay registro ni castigo, las dos utilizaciones son indistinguibles»— es **tautológicamente
cierta**: es la definición de «sin registro ni castigo». No es un teorema profundo; es una
descomposición por casos. El propio informe etiqueta el teorema general como **PLAUSIBLE** y solo el
dilema como DEMOSTRADO, lo cual es honesto.

**¿Falta una variante?** Busqué una quinta fuera de A-D y no la encontré bajo las premisas:
- «Atar el valor a la prueba» (`x = f(π)`) en vez de la prueba al valor: colapsa en (A) por simetría
  o en grinding (el adversario elige entre sus soluciones/bloques).
- Firma de un solo uso derivada del plot (revela la clave al firmar dos veces): sigue siendo
  detección ex-post = (C); sin estado, un verificador no puede saber que existe una segunda firma.
- Reto con recurso fresco no escaso (hash, VDF ligero): no ata nada; si es escaso, es (A)/(e).
- Reputación o tabla: (B).

**La grieta real, y el informe la declara:** la premisa «sin dinero en juego» es más estrecha que la
pregunta. La variante (e) —un puzzle fresco por voto— **restaura `2k` sin dinero** en la letra. El
informe lo dice en el «matiz de honestidad sobre el kill criterion». Eso significa que el enunciado
«no existe ninguna regla que restaure `2k` sin dinero en juego» es **falso tal cual**, y el informe
lo corrige a «no existe sin pagar uno de cuatro precios». La dicotomía A-D es completa *dado* ese
marco; el titular del encargo, no. **Clasificación: DEMOSTRADO el dilema estructural bajo premisas;
PLAUSIBLE el teorema general; el titular literal, REFUTADO por (e).**

### 3.2 La equivalencia «voto = bloque ⇒ profundidad de confirmación»

Bien argumentada y la doy por buena: si el voto es el bloque, un `k`-quórum son `k` bloques y el
predicado «`k` bloques descienden de `B`» **es** «`B` tiene `k` confirmaciones». No hay información
nueva. El argumento de los 194 s (`k/(αλ) = 64/0,33 = 193,9 s`) es aritmética verificada
(`salida_b.txt:53-57`). La única sutileza: la equivalencia es *de predicado*, y de ahí que no
aporte; el informe no pretende que el atacante gane con 194 s, sino que la unicidad no la da el
quórum. Correcto. **DEMOSTRADO.**

### 3.3 El «3-7 s» de F1: ínfimo real, suelo mal etiquetado

Lo que el FIP dice, línea a línea:

| Hecho | Cita | Consecuencia |
|---|---|---|
| Épocas de 30 s | `fip-0086.md:39` | la cadencia de F3 es 30 s |
| **Una instancia por época** | `:704` | no se pueden lanzar instancias extra dentro de una época |
| Arranque: `CurrentEpoch() ≥ finalizedTipsets[i-1].Head().epoch + 2` | `:183` | la instancia `i` finaliza la cadena hasta la época anterior a su arranque |
| «sub-epoch finalization … only limited by the network speed» | `:938` | el FIP **sí** admite finalizar dentro de la época |
| «three communication steps (within tens of seconds)» | `:255` | el caso bueno son 3 pasos |
| `Δ=6 s` inicial; timeout `2Δ`; fases se cierran antes si hay quórum | `:713, :442, :715` | `T_cons ≈ 3-4 entregas` |

Modelo correcto de la latencia de un bloque creado en la época `E`, con la regla `+2`:

- La instancia que puede incluirlo arranca en `E+1` (el `+2` es relativo al **último finalizado**,
  no al bloque). Arranca al inicio de la época `E+1`.
- `t_final = (E+1)·30 + T_cons − t_B`, con `t_B ∈ [E·30, (E+1)·30)`.
- Por tanto la espera es **`[0, 30] s`**, no `[30, 60] s`: **la tabla de F1 §2.1 («F3 real:
  30-60 s») está mal por una época**; la de §2.3 («0-30 s, media 15») es la correcta.

Entonces:
- **¿Puede finalizar por debajo de 30 s sin cambiar la cadencia?** Sí, en el mejor caso: el FIP lo
  dice (`:938`) y el cálculo lo confirma. Pero solo para bloques que caen justo antes del arranque
  de una instancia.
- **¿El 3-7 s es un suelo real o un error?** Es un **ínfimo real del consenso** (`3-4` entregas ×
  `Δ`), no de la irreversibilidad end-to-end. A cadencia `c` y con llegada aleatoria del bloque, la
  latencia es `c/2 + T_cons` de media y `c + T_cons` en el peor caso. Con `c=30 s` y `Δ=1 s`:
  media ≈ 18-21 s; con `Δ=6 s` (el valor inicial del FIP): media ≈ 33-39 s. **El 3-7 s no es el
  suelo del sistema; es el suelo del viaje de ida y vuelta del BFT.** El informe lo entrevé
  («el protocolo podría bajar a 3-7 s si el gossip bajara con él»), pero lo titula «suelo del
  protocolo» en §2.3 y §9.1, y su fila «Mínimo con Δ≈1 s: 0-1 s de espera» solo es cierta si la
  cadencia es ~1 s. **REFUTADO como suelo de irreversibilidad; VERIFICADO como `T_cons` del
  consenso.** Corrección propuesta: publicar `c/2 + T_cons` (media) y `c + T_cons` (cota), y decir
  que el ínfimo `T_cons` exige que el bloque caiga en el borde de época.

Impacto: si Katana decide con el 3-7 s como «suelo», decide con un número que no se entrega de
forma sistemática. La decisión no cambia de dirección (bajar la cadencia sigue siendo la palanca),
pero el número publicable es la media, no el ínfimo.

### 3.4 El modelo de parada 32,4 / 69,2 / 100 %

- **Evento:** `E1 = {A ≥ ceil(K/3)}`, con `A ~ Bin(K, α)`. El atacante bloquea el quórum de ⅔.
  `K=4000`, `α=0,33`: `P(E1)=0,3243905`. **VERIFICADO.**
- **Best-of-m:** `P = 1−(1−p)^m`. El script `verif_sesgo_sorteo.py:31` usa `ceil(m)`; por eso
  `m=2,955 → 0,6916` (el 69,2 % del informe). Con el valor exacto: **0,6861**; con el `m=2,822` del
  diseño vivo (`ancla-de-orden.md:156`): **0,6693**. La tabla de F1 §3.2 etiqueta `m=2,955` con el
  valor de `ceil(m)=3`; §6.1 sí dice «la tabla usa `ceil(m)`, conservador». Es una **cota
  corregida**, en dirección conservadora (el informe se queda del lado pesimista).
- **Orígenes:** `m=2,955` en `capa-finalidad.md:210` (D8 A4.2 con retención); `m=2,822` en
  `ancla-de-orden.md:156` (misma ronda, cifra actualizada). **Discrepancia de fuente sin resolver**
  que D9 señala: no se puede citar 2,955 como «el m del diseño» si el diseño vivo publica 2,822.
- `m=151`: `1 + λ·S_max = 1 + 1·150 = 151`, `S_max=150 s` (`ancla-de-orden.md:156,167-170,188`).
  **DEMOSTRADO.**
- **El «100 %» con `m=151`** es `1−(1−0,3244)^151 ≈ 1 − 1,3e-24`. Correcto.
- **P(mentira) = 0 para K=4000** es un subdesbordamiento de `float64` (la cola real es ~1e-449), y
  el 9,87e-103 de K=1000 es `m·p` (union bound), no un cálculo directo. El informe lo presenta bien.

**Un matiz lógico importante:** `P(E1)=0,324` es la probabilidad de que **falle la condición
`A < K/3`**, no la probabilidad de que se rompa la seguridad. F1 lo dice y declara LAGUNA el ataque
concreto de doble finalidad. Por eso «REFUTADO el “la seguridad no se toca”» debe leerse como
«refutado que la condición de seguridad esté garantizada», no como «demostrado que la seguridad se
rompe». El informe es cuidadoso; el titular es más fuerte que la prueba. **La violación de la
condición: VERIFICADA. El ataque: NO DEMOSTRADO (LAGUNA declarada).**

### 3.5 Otras etiquetas fuertes que revisé

- **F0a «REFUTADO como regla anti-equivocación sin dinero»:** el argumento (identidad gratis,
  ploteo por bytes, ban por clave evadible) es correcto. **DEMOSTRADO sobre el código.**
- **F1 «p no rompe la seguridad»:** correcto; el quórum es sobre el total de la tabla
  (`fip-0086.md:389`). **DEMOSTRADO.**
- **F1 «blst ya en la ruta de consenso»:** condicionado a heredar el KZG de Autonomys; el
  `kzg.verify` está en `verify_solution` (`subspace-verification/src/lib.rs:263`) y `rust-kzg-blst`
  es dependencia del workspace (`Cargo.toml:180`). **VERIFICADO en código; la herencia por ZEROX es
  PLAUSIBLE** (lo dice el propio informe).
- **F1 «R-FIN-20 es un registro de claves»:** el FIP exige que la tabla lleve «their signing key»
  (`:96`) y R-FIN-20 declara la BLS en la coinbase. **DEMOSTRADO sobre los textos.**
- **F2 «Avalanche sin dinero es REFUTADO»:** el paper asume que el control Sybil es un problema
  aparte (`§2 Sybil Attacks`, texto completo verificado) y el despliegue exige 2.000 AVAX (web).
  **RESPALDADO POR FUENTE**, con la precisión de que el protocolo no tiene slashing —el stake es
  puerta de entrada, no castigo—, que F2 también dice.

---

## 4 · Citas — spot-check contra la fuente real

### 4.1 `hotpow.txt` (correcciones de F0b a d12)

| Cita de d12 | Para qué | Líneas reales | Veredicto |
|---|---|---|---|
| `437-441` | definición del voto `(r,p,s)` | **437-441 es la Figura 6** («Application… Work Broadcast network»); la definición está en **492-497** | **d12 mal; F0b acierta** |
| `509-517` | condiciones de quórum | correcto (líneas 509-517: lista, umbral y orden canónico) | F0b acierta |
| `544-555`, línea 18 en `548` | validez de bloque | **548 = `18: h′← Hpow(B.parent, p,s)`** | F0b acierta |
| `392-397` | POA de Bitcoin 0,2642 | **403-405** es el Remark de validación; 392-397 es «Since ambiguity causes failure…» | **d12 mal; F0b acierta** |
| `200-208` | «k easier puzzles… 10/k minutes» | **153-156** | **d12 mal; F0b acierta** |
| `1300-1303` | «axiomatic exclusion of PoW-1/PoW-2» | **1235-1237** | **d12 mal; F0b acierta** |
| `597-601` | Listing 4.6, línea 41 | **601-609**, línea 41 en **608** | **d12 mal; F0b acierta** |
| `279-283` (Def. 1) vs f0b `281-284` | Definición 1 | el encabezado está en **281**; el texto 281-284 | f0b cita mejor que el encargo |
| `301-304`, `305-312`, `374-377`, `517-518`, `726-729`, `1835-1842` | ambigüedad 2k, Def. 4, «isolate the effect of k», Sibyl, incentivos, Tabla A.1 | todas correctas | **VERIFICADO** |

**Las cinco correcciones de d12 que hace F0b son correctas, una por una.**

### 4.2 Código Autonomys (F0a, F0b, F1)

Todas las rutas citadas resuelven bajo `/home/katana/zeo/fuentes/subspace/crates/` (los informes
abrevian el prefijo `crates/`), salvo dos que anoto:

| Cita del informe | Línea real | Veredicto |
|---|---|---|
| `verify_solution` «empieza en 211», firma en `211-216`, cuerpo `228-272` | firma en **211-216**, `SectorId` en 228-232, reto en 234-236, KZG en 263 | **VERIFICADO** |
| `check_reward_signature` `107-117` (f0a §1) / `107-116` (§4.1) | función **107-116** | correcto (el 117 es la línea en blanco) |
| `subspace-core-primitives/src/sectors.rs:56-68` | `SectorId::new` en **56-68**, keyed blake3 | **VERIFICADO**; la ruta real es `crates/subspace-core-primitives/src/sectors.rs` |
| `sectors.rs:126-130` | `derive_evaluation_seed` **126-130** | **VERIFICADO** |
| `identity.rs:23-27, 48-52, 73, 105-109, 117-132, 149-152` | todas exactas | **VERIFICADO** |
| `single_disk_farm.rs:107-125, 1311-1317, 1834-1849, 867-870, 1244` | todas correctas (1311-1317 es `IdentityMismatch`; 1848 es el `PublicKeyMismatch`) | **VERIFICADO** |
| `reward_signing.rs:20-28` | bucle y firma en 20-28 | **VERIFICADO** |
| `pallet-subspace/src/lib.rs:1476-1484, 1591-1597, 1603-1634, 1656-1685, 1748-1762, 1765-1782, 448, 375, 533-538, 623-625, 1049, 878, 1384` | todas exactas; `SegmentCommitment` es el **único `StorageMap`** del pallet (grep de 19 items: los demás son `StorageValue`) | **VERIFICADO** |
| `sc-consensus-subspace/src/verifier.rs:339-348, 366-408, 402` | exactas; 402 = `// TODO: Handle equivocation` | **VERIFICADO** |
| `sp-consensus-subspace/src/lib.rs:180-198, 218-221` | `Vote::V0` y `hash()` = `blake2_256(encode())` | **VERIFICADO** |
| `solutions.rs:254-275`, `257-258` | `Solution` sin campo de valor votado; `reward_address` separado | **VERIFICADO** |
| `pot.rs:278-280`, `core-primitives/src/lib.rs:36, 110-112` | `blake3(PoT)`, `REWARD_SIGNING_CONTEXT`, `blake3(randomness‖slot)` | **VERIFICADO** |
| `plotting.rs:252-256, 400, 144-202`; `auditing.rs:237-271` | `SectorId` al plotear, semilla, `map_winning_chunks` sin tope | **VERIFICADO** |
| `commands/farm.rs:164-165, 293-304` | **ruta real:** `src/bin/subspace-farmer/commands/farm.rs` | líneas correctas, prefijo omitido |
| `cluster/controller.rs:835-860` | **ruta real:** `src/cluster/controller.rs` | correcto |
| polkadot-sdk `client/consensus/slots/src/aux_schema.rs:50-68, 31` | **ruta real en el checkout:** `substrate/client/consensus/slots/src/aux_schema.rs`; rev `962a09e060d0…` (el que fija `Cargo.toml:65`); `MAX_SLOT_CAPACITY = 1000` en **:31**; `check_equivocation` en **53-133** | **VERIFICADO** (con `substrate/` omitido) |
| `Cargo.toml:180`; `shared/subspace-kzg/Cargo.toml:24` | `rust-kzg-blst` en **180**; en el shared está en **25** (sección 24-27) | **VERIFICADO** (off-by-one) |

### 4.3 FIP-0086 (F1)

Todas las líneas citadas por F1 §1, §2 y §5 son correctas: `:6` status Final, `:16` «tens of
seconds», `:39` épocas de 30 s, `:54/:704` una instancia por época, `:57/:389` quórum ⅔ del total,
`:58` EC sigue si F3 se para, `:65/:248` adversario < ⅓, `:96/:111/:200-201` lookback 10, `:151/
:316-317/:617` decide una cadena, `:183` arranque `+2`, `:255` tres pasos, `:442/:509/:711-713/:715/
:717` timeouts y cierre anticipado, `:361` BDN/rogue-key, `:700/:924-929` coste O(K) de agregación,
`:918-931` BLS12-381 G2/G1 + BDN, `:938` sub-epoch, `:1125` todos los elegibles, `:1135` decenas de
segundos. **La única lectura que F1 hace mal es la consecuencia de `:704` sobre la latencia: el
«una instancia por época» limita la cadencia, pero el FIP mismo admite sub-epoch (`:938`), y la
espera es 0-30 s, no 30-60 s** (ver §3.3).

### 4.4 Papers de F2

| Cita | Fuente real | Veredicto |
|---|---|---|
| Avalanche 1,35 s / 3.400 tps / despliegue medido | arXiv:1906.08936 abstract | **VERIFICADO** |
| «cualquier mecanismo Sybil; PoS es el más alineado» | paper §2 *Sybil Attacks*, texto completo | **VERIFICADO** |
| «todos comparten N» en Slush §4.1 | paper §4.1 | **VERIFICADO** |
| P3: viveza fuerte `f = O(√n)`; polinómica al superarlo | paper P3 y §4.2 | **VERIFICADO** |
| 2.000 AVAX de stake | docs.avax.network/docs/primary-network | **VERIFICADO** |
| `<1 s` C-Chain / `<100 ms` L1 | portada de docs.avax.network (2026) | **VERIFICADO** |
| Ethereum 12,8 min (2 épocas) | ethereum.org PoS: slots 12 s, épocas 32 slots, finalidad en 2 checkpoints | **VERIFICADO** |
| DAGKNIGHT 1,2-12 s (D=0,1-2, λ=3,75, α=0,2, ε=0,05) | `dagknight.txt:182-197` | **VERIFICADO** |
| Pass-Shi: ningún responsivo tolera ≥1/3 | `dagknight.txt:292-294` | **VERIFICADO** |
| Cota exponencial pesimista; pagos honestos cuadráticos | `dagknight.txt:352-367` | **VERIFICADO** |
| GHOSTDAG 70,4 % ≤10 s; 99,9 % ≤10 min; máx 746 s | `phantom-ghostdag.txt:884-893` | **VERIFICADO** |
| SPECTRE 21 s; GHOSTDAG 45 s de ejemplo | `phantom-ghostdag.txt:824-837` | **VERIFICADO** |
| CAP dual rule, `e + O(Δ)`, CP1 no la cumplen PBFT/HotStuff | `cap-adaptividad-finalidad.txt:100-123, 192-194, 506-545, 1574-1580` | **VERIFICADO** |
| Lewis-Pye: adaptativo = vivo sin tamaño; finalidad = seguro en parcialmente síncrono; Teorema 4.1 | `lewispye:727-741, 754-756, 759, 774-781` | **VERIFICADO** |
| bdk19: depósito slashable; overt penalizable; covert indistinguible de latencia | `bdk19.txt:279-284, 299-305, 1496-1498` | **VERIFICADO** |

### 4.5 Chia (F0a)

| Cita | Línea real | Veredicto |
|---|---|---|
| memo del plot v1: `pool(48)‖farmer(48)‖local_master_sk(32)` y variante `puzzle_hash(32)` | `chia/plotting/util.py:221-262` | **VERIFICADO** |
| `plot_public_key = local_pk + farmer_pk (+ taproot)` | `chia/types/blockchain_format/proof_of_space.py:359-364` | **VERIFICADO** |
| `plot_id = std_hash(pool‖plot_public_key)` | `proof_of_space.py:339-350` | **VERIFICADO** |
| `plot_id` en la verificación y `quality_str` | `proof_of_space.py:177, 215` | **VERIFICADO** |
| farmer comprueba `agg_pk == proof.plot_public_key` | `chia/farmer/farmer_api.py:321-333` (assert en 325) | **VERIFICADO** |
| «We cannot use any plots which have different keys in them» | `chia/harvester/harvester_api.py:153` | **VERIFICADO** |
| `join_pool` / `change_payout_instructions` | `chia/cmds/plotnft_funcs.py:343-413, 461-477` | **VERIFICADO** |
| `(2k+1)·2^(k−1)`, factor ×0,78 | `chia/consensus/pos_quality.py:8, 11-23` | **VERIFICADO** (130,0 GiB ×0,78 = 101,4 GiB) |
| temporal 238,3 GiB / 313 GiB | `CHANGELOG.md:2830, 3569` | **VERIFICADO** |

---

## 5 · Dictamen por informe

### F0a · Clave, identidad de plot y castigo de espacio — **SÓLIDO**

- Las 17 citas de código y Chia que comprobé son exactas; las rutas resuelven (dos con prefijo
  omitido, anotado).
- La cadena lógica —identidad = clave del plot; crear claves es gratis; el ploteo escala con bytes;
  el ban por clave es fragmentable; el castigo es ex-post— **se sostiene**.
- El suelo de «~1 sector» está bien etiquetado como PLAUSIBLE (depende del `solution_range`).
- La LAGUNA del tiempo de ploteo de Chia está bien declarada.
- Única pega: «REFUTADO» en la tabla de hallazgos se refiere a la variante, no a la pregunta F0
  entera; el texto lo aclara.

### F0b · Anti-equivocación sin dinero — **SÓLIDO con matices**

- La aritmética POA está impecable (verificada con tres instrumentos).
- **Las cinco correcciones de citas de d12 son correctas** (hotpow 492-497, 509-517, 548, 403-405,
  153-156, 1235-1237, 601-609/608).
- El dilema A-D es completo **bajo sus premisas**, pero es una descomposición tautológica; el
  titular literal («no existe sin dinero») lo refuta la propia variante (e), que el informe declara
  con honestidad. No es un fallo oculto; es un matiz de etiqueta.
- La equivalencia voto=bloque ⇒ profundidad de confirmación está bien argumentada.

### F1 · Auditoría de P-040 — **SÓLIDO con tres correcciones**

1. **La latencia `0-30 s` de §2.3 es la buena; la `30-60 s` de §2.1 está una época alta.**
2. **El «3-7 s» es el ínfimo del BFT, no el suelo de irreversibilidad**: a cadencia `c` la media es
   `c/2 + T_cons` y la cota `c + T_cons`; publicar el ínfimo induce a error. La pregunta del
   encargo («¿puede finalizar por debajo de 30 s sin cambiar la cadencia?») se responde **sí, en el
   mejor caso** (el FIP lo dice en `:938`), pero no de forma sistemática.
3. **El 69,2 % es `ceil(2,955)=3`; con 2,955 exacto es 68,6 %, y con el m=2,822 del diseño vivo,
   66,9 %.** El error va en dirección conservadora.

Todo lo demás que comprobé —el 41 % como cifra de K=1000, los umbrales, el certificado, el
`prev()`, el espacio-tiempo, la BLS/BDN, el 27,0 % anual— **se sostiene**.

### F2 · Alternativas — **SÓLIDO, con dos heredados sin corregir**

- Las citas de Avalanche, Ethereum, DAGKNIGHT, GHOSTDAG, CAP y Lewis-Pye están todas verificadas.
- **Hereda el 41 % sin corregirlo** (lo presenta como el número de P-040). F2 se declara no
  auditor de P-040 y dice que ese número «no está verificado aquí», pero al ser un informe paralelo
  conviene que la cifra corregida (32,4/69,2/100) sustituya a la vieja en el balance F3.
- **`$1.689 M` de stake**: la web da hoy `$1.680,7 M`; el 46,6 % es correcto. Desliz menor.
- «0,56·3k ⇒ 60-75 s» es una cota heredada imprecisa: con 3k=90 s da 50,4 s; el 60-75 sale de
  aplicar 0,56 al suelo 100-134 s. Sin consecuencia, pero el número está mal atribuido.

---

## 6 · Formato D9 por afirmación (las que deciden)

```
AFIRMACIÓN:   «POA Def.4 = P[Pois(k)≥2k]; con equivocación libre el umbral cae a k y vale 0,5166 a k=64»
              (f0b §1.3-1.4; hotpow.txt:301-312; d12 §F.7)
CLASIFICACIÓN: VERIFICADO COMPUTACIONALMENTE
DERIVACIÓN:   mpmath (60 dígitos) y scipy sobre k∈{1,16,32,64,128,256}: 2,761998e-4/1,2723673e-12/
              3,9590424e-45 y 0,5332551/0,5166240/0,5083115. La identidad 1−e^−k Σ k^i/i! reproduce
              la Tabla A.1. El 0,5166 NO es probabilidad de ataque: es la POA con umbral k; el evento
              de ambigüedad en T_{P,k} tiene probabilidad 1 (el informe lo dice).
ENTEROS:      no aplica (probabilidades en punto flotante de 60 dígitos).
ADVERSARIO:   un adversario que intentara leer 0,5166 como «probabilidad de romper el protocolo» se
              equivoca; el informe no lo hace.
IMPACTO:      si el número fuera falso, la decisión de cerrar la vía quórum cambiaría.
CORRECCIÓN:   ninguna al número; sí a la etiqueta del encargo («Def. 1» es Def. 4).
```

```
AFIRMACIÓN:   «Umbral anual de seguridad BFT: α ≤ 28,2 % para 1e-6/año; 27,0 % para 1e-12; 29,2 %
              para 1e-2; 340 999 paradas/año a α=0,33» (f1 §3.2, §3.4)
CLASIFICACIÓN: VERIFICADO COMPUTACIONALMENTE
DERIVACIÓN:   P[Bin(4000,α)≥1334] con scipy y mpmath regularizado (coinciden a 8 dígitos):
              0,3243905 (α=0,33). Anualización estable 1−exp(N·log1p(−p)) con N=1 051 200:
              α(1e-12)=27,049 %, α(1e-6)=28,243 %, α(1e-2)=29,246 %. Paradas/año = 340 999,33.
ENTEROS:      umbral 1334 = ceil(4000/3) es correcto porque A=1333 deja honestos = ceil(2K/3).
ADVERSARIO:   el modelo supone α constante durante el año y A_i i.i.d.; si α crece, la anualización
              se queda corta. El informe no declara ese supuesto.
IMPACTO:      es la condición que decidiría si P-040 vale al 33 %; un error aquí mueve la frontera.
CORRECCIÓN:   añadir el supuesto «α fijo» y la advertencia de estabilidad numérica del instrumento.
```

```
AFIRMACIÓN:   «P-040 no funciona al 33 %: 32,4 % (m=1) / 69,2 % (m=2,955) / 100 % (m=151)»
              (f1 §3.2, §9.1)
CLASIFICACIÓN: VERIFICADO con COTAS CORREGIDAS
DERIVACIÓN:   0,3244; 1−(1−0,3244)^2,955 = 0,6861 (no 0,6916); 1−(1−0,3244)^3 = 0,6916;
              con m=2,822 (diseño vivo) = 0,6693; m=151 → 1. Modelo best-of-m con ceil(m) declarado.
ENTEROS:      ceil(m) en verif_sesgo_sorteo.py:31.
ADVERSARIO:   el adversario elige ancla entre m; el modelo asume independencia entre comités
              (aproximación válida para p pequeño).
IMPACTO:      ninguno en la conclusión; el número exacto es más benigno, no más grave.
CORRECCIÓN:   69,2 % → 68,6 % (m=2,955) o 66,9 % (m=2,822). Resolver la discrepancia 2,955 vs 2,822.
```

```
AFIRMACIÓN:   «El mínimo alcanzable es 3-7 s con Δ≈1 s; el 30 s no es un suelo del protocolo»
              (f1 §2.3, §9.1)
CLASIFICACIÓN: REFUTADO como suelo de irreversibilidad / VERIFICADO como T_cons del BFT
DERIVACIÓN:   FIP :704 (una instancia por época), :39 (30 s), :183 (+2 respecto al último
              finalizado), :938 (sub-epoch). La instancia que finaliza un bloque de la época E
              arranca en E+1; espera ∈ [0, 30] s, latencia T_cons + [0, 30] s. T_cons = 3-4 entregas
              × Δ (3-6 s con Δ=1 s). A cadencia c: media c/2 + T_cons, cota c + T_cons. El ínfimo
              T_cons exige caer justo en el borde de época.
ENTEROS:      no aplica.
ADVERSARIO:   quien planifique comercio con 3-7 s verá medias de 18-39 s según Δ.
IMPACTO:      decisión de latencia publicable (prioridad 1 de Katana).
CORRECCIÓN:   publicar c/2+T_cons y c+T_cons; reservar 3-7 s como ínfimo del consenso.
```

```
AFIRMACIÓN:   «No existe una regla anti-equivocación que restaure 2k sin dinero en juego»
              (f0b, veredicto)
CLASIFICACIÓN: REFUTADO en la letra / DEMOSTRADO el dilema estructural A-D bajo premisas
DERIVACIÓN:   la variante (e) —puzzle fresco por voto— restaura 2k sin dinero; el propio f0b lo
              reconoce y lo llama «bifurcación real». La dicotomía A-D cubre el resto: probé cinco
              variantes fuera de A-D y todas colapsan en A/B/C.
ENTEROS:      no aplica.
ADVERSARIO:   un lector que tome el titular por literal cerraría P-043 sin ver la bifurcación (e).
IMPACTO:      cierre de P-043 como capa sin dinero.
CORRECCIÓN:   el titular correcto es el del propio informe: «sin pagar uno de cuatro precios».
```

```
AFIRMACIÓN:   «Certificado Ed25519 K=4000 = 264 128 B / 277,65 GB/año; BLS = 724 B / 0,76 GB/año;
              66 B = firma + índice» (f1 §6.2)
CLASIFICACIÓN: VERIFICADO en la composición / PLAUSIBLE la cabecera
DERIVACIÓN:   verif_certificado.py:10 (64 B firma, 32 B clave), :14-17 (+2 B índice), :12 (128 B
              cabecera). 128+4000·66 = 264 128; ×1 051 200/1e9 = 277,6514 GB. BLS: 128+96+500 = 724.
ENTEROS:      ceil(K/8)=500 B de bitmap para K=4000.
ADVERSARIO:   la clave pública no viaja; el índice solo resuelve si el verificador tiene la tabla
              (R-FIN-21). Correcto.
IMPACTO:      la comparación Ed25519 vs BLS que obliga a BLS.
CORRECCIÓN:   marcar los 128 B como supuesto, no como medida.
```

```
AFIRMACIÓN:   «Gossip del consenso ~3,5 TB/año/nodo a K=4000/30 s» (f1 §6.4)
CLASIFICACIÓN: PLAUSIBLE, NO DEMOSTRADO
DERIVACIÓN:   certificado solo: 0,76 GB/año. Votos de 484 B (d12 F.1): 2,04 TB (1/miembro),
              6,11-8,14 TB (3-4). Mensajes de 200 B × 3,5-4: 2,94-3,37 TB. El 3,5 es la parte alta
              del modelo del informe; no está inflado, pero el tamaño real no está medido y las
              QUALITY llevan la cadena (hasta 99 tipsets, fip-0086.md:654).
ENTEROS:      no aplica.
ADVERSARIO:   un nodo doméstico con ~2-8 TB/año de subida/bajada; decide la cadencia publicable.
IMPACTO:      es el freno real a bajar la cadencia.
CORRECCIÓN:   publicar el rango y medir el tamaño de mensaje de GossiPBFT.
```

---

## REFUTADAS

| # | Qué | Dónde | Impacto |
|---:|---|---|---|
| R1 | «El 3-7 s es el suelo de irreversibilidad del protocolo» | f1 §2.3/§9.1 | **Decisión de latencia (prioridad 1).** A cadencia `c` la media es `c/2+T_cons` y la cota `c+T_cons`; el ínfimo 3-7 s exige Δ≈1 s y caer en el borde de época. La cadena `hotpow.txt`/FIP no lo sostiene como suelo end-to-end |
| R2 | «F3 real: espera 30-60 s» | f1 §2.1 | Una época de más: el `+2` es relativo al último finalizado, no al bloque; la espera es 0-30 s. La latencia F3 a Δ=6 s es 18-54 s, no 48-84 s |
| R3 | «69,2 % de parada con m=2,955» | f1 §3.2 | Con m exacto es 68,6 %; con el m=2,822 del diseño vivo, 66,9 %. El 69,2 % es `ceil(m)=3`. Sin impacto en la conclusión (dirección conservadora) |
| R4 | «El 41 % es el número de P-040» | f2 §1.2/§3.5 (heredado) | Es `K=1000, m=1`; el diseño K=4000 da 32,4/68,6/100. F2 lo presenta sin la corrección de F1 |
| R5 | «$1.689 M de stake en Avalanche» | f2 §3.2 | La web da hoy $1.680,7 M (1,68 B); el 46,6 % es correcto. Desliz de unidades/fecha |
| R6 | «Titular: no existe anti-equivocación sin dinero» | f0b veredicto | La variante (e) lo hace sin dinero; el informe lo admite. El titular correcto es «sin pagar uno de cuatro precios» |
| R7 | Fila «Ed25519 K=4000 = 237 728 B» de la propuesta | capa-finalidad.md:170 | Es la salida de K=3600; el valor correcto es 264 128 B / 277,65 GB. **F1 ya lo corrige bien**; se refuta el dato de la propuesta |

## NO DEMOSTRADAS

1. **Ataque concreto de doble finalidad con `A ≥ ⅓K`.** F1 lo declara LAGUNA. `P(A≥⅓K)=0,324` prueba
   que *la condición de seguridad falla*, no que exista un ataque que produzca dos certificados. No
   se puede cerrar sin portar GossiPBFT.
2. **Teorema general de imposibilidad con equivocación.** F0b lo deja en PLAUSIBLE; la literatura
   local prueba adaptividad-vs-finalidad, no coste-por-equivocación. Correcto no elevarlo.
3. **`m` real.** 2,955 (`capa-finalidad.md:210`) vs 2,822 (`ancla-de-orden.md:156`): discrepancia
   sin resolver; ambos salen de simulaciones D8 que no re-ejecuté.
4. **Tamaño real de los mensajes GossiPBFT y coste del gossip.** Sin medir; el 3,5 TB/año es una
   estimación de orden de magnitud.
5. **`kzg.verify = 1,0773 ms`.** Medición de d12 en Criterion; no la reproduje (requiere compilar
   `subspace-kzg` con nightly). La trato como RESPALDADO POR FUENTE.
6. **`p` del granjero doméstico y `Δ` real.** Siguen sin medir; todo el caso normal de P-040 es
   condicional a ellas.
7. **Independencia de las instancias en la anualización y en la recuperación geométrica.** Es una
   aproximación; la tabla de poder se solapa entre instancias y el atacante no es pasivo.
8. **Tiempo de ploteo de Chia k32.** LAGUNA correctamente declarada por F0a.
9. **Latencia empírica de F3 en mainnet de Filecoin.** F1 la declara LAGUNA; no la traje.
10. **Papers BFT de F2** (Tendermint, HotStuff-2, Casper, GRANDPA): no los abrí; sus números
    (3 pasos, 2 fases, 12,8 min, `t_r+6T`) quedan RESPALDADOS POR FUENTE, no verificados por mí.

## COTAS CORREGIDAS

| Cota | Informe | Correcta |
|---|---|---|
| Latencia F3, espera | 30-60 s (f1 §2.1) | **0-30 s** |
| Latencia P-040 a cadencia 30 s | 25-60 s (f1 §2.3) | 25-60 s es correcto para `T_cons`=10-30 s; con Δ=6 s es 18-54 s y con Δ=1 s 3-36 s. La media a Δ=1 s es ~18-21 s |
| Parada con m medido | 69,2 % | **68,6 %** (m=2,955) / **66,9 %** (m=2,822) |
| Stake Avalanche | $1.689 M | **$1.680,7 M** (46,6 %) |
| «0,56·3k ⇒ 60-75 s» | 60-75 s | **50,4 s** si 3k=90 s; 56-75 s si se aplica a 100-134 s. Cota mal atribuida |
| Gossip K=4000 | ~3,5 TB/año | **2,0-8,1 TB/año** según tamaño/fases (484 B) o 2,9-3,4 TB (200 B) |

## LO QUE NO PUDE VERIFICAR

1. **La medición `kzg.verify`** (1,0773 ms): no re-ejecuté el banco Criterion; exigiría compilar el
   workspace con la toolchain nightly. Queda como RESPALDADO POR FUENTE (d12).
2. **Las simulaciones D8/D9 que producen `m=2,955`/`2,822` y `δ(α)`**: leí los informes, no re-corrí
   los simuladores; la discrepancia entre las dos cifras queda señalada, no resuelta.
3. **Los papers BFT que F2 cita por número** (Tendermint, HotStuff-2, Casper FFG, GRANDPA): no los
   descargué; la web solo me sirvió para Avalanche, Ethereum y los de Kaspa.
4. **La latencia empírica de F3 en mainnet** (`f3.filecoin.io`): F1 la declara LAGUNA; yo tampoco la
   obtuve.
5. **El PR #3072 y el issue #2078 de Autonomys**: solo por la cita de `dag-consenso-poas.md:69` y
   `:66`; no los abrí en GitHub.
6. **El tiempo de ploteo de Chia k32**: sin benchmark primario local (LAGUNA de F0a).
7. **El coste de verificación BLS agregada con BDN a K=4000**: la LAGUNA de F1 sigue abierta; el
   2 ms del script es un supuesto y el FIP dice que el coste dominante es O(K).

---

**Veredicto global de D9.** Los cuatro informes son, en su conjunto, **fiables**: las matemáticas
centrales (POA, umbrales, binomiales, certificado, ploteo) pasan el recálculo independiente, y las
citas primarias de `hotpow.txt`, `fip-0086.md`, `dagknight.txt`, `phantom-ghostdag.txt`,
`cap-adaptividad-finalidad.txt`, `lewispy-roughgarden-cap.txt`, `bdk19.txt` y el código de Autonomys
y Chia resisten el spot-check. Las refutaciones son de **interpretación y de etiqueta** —el 3-7 s,
la espera de F3, el 69,2 %, el 41 % heredado— no de la conclusión de fondo: **P-040 no garantiza
irreversibilidad al 33 %, la vía quórum sin dinero está cerrada salvo el precio (e), y el castigo de
espacio es evadible.** Eso queda en pie.
