# DS-3 · Falta de definición detectada antes de escribir código

**Fecha:** 2026-09-26. **Ejecutor:** DeepSeek (`deepseek-flash`). **Entrada congelada:**
`P-ZRX/P-DISUASION/ENTRADA-DS3.sha256` (verificada). **Orden:** `ORDEN-DS3-MODELO.md`.

La orden manda: «Si detectas una falta de definición, infórmala antes de editar.» Esto es lo
detectado al leer íntegros `MARCO.md`, `ORDEN-DS3-MODELO.md` (con su Ratificación),
`REVISION-DS2.md`, `resultados-DS2/MODELO.md` y `V-ZRX/LINEO.md`, más los instrumentos fuente
citados por el MODELO (`.trash/zerox/P-ZRX/P-{PRESTAMO,CLAVE,COBERTURA,INTENTO,EQUIVOCACION}`).

Ninguna de estas faltas **bloquea** la ejecución: todas se resuelven con una decisión declarada
(abajo, «Resolución DS-3»), y ninguna inventa un dato; cuando no hay fórmula ratificada, la celda se
publica como **no cuantificada** en vez de rellenarse con un número supuesto.

## F1 · La pregunta falsable por celda no existe en DS-2

- **Qué falta.** `ORDEN-DS3` §1 dice que la pregunta falsable de DS-3 es «la que DS-2 formule para
  cada celda E (“el mecanismo multiplica el coste mínimo de X por al menos …”)». DS-2 **no formula
  ninguna pregunta de ese tipo por celda**: su matriz (`resultados-DS2/INFORME.md` §3) da
  veredictos cualitativos `Ee`/`Ec` y cantidades sueltas, y su §7 da cifras de orden de magnitud,
  pero en ningún sitio hay un «multiplica por al menos X» por celda E.
- **Resolución DS-3.** DS-3 construye la pregunta falsable de cada celda cuantificable y la marca
  como **construida por DS-3**, no como formulada por DS-2. Se publica en `INFORME.md` §2 junto al
  valor calculado y su refutación o no.

## F2 · «Coste mínimo absoluto para una probabilidad de éxito dada» no está definido

- **Qué falta.** El MODELO ratificado define probabilidad en función de parámetros (DP de primera
  pasada §2.2; `P(B=0)` §2.3; frontera de cobertura §2.8) y costes fijos (§2.7, §2.9), pero **no
  define una función coste↔probabilidad** invertible para A4, A5, A7, A8, A9, A10. Para A4 el
  requisito `q`/`S_min` es «símbolo, forma pendiente» (`MODELO` §3, `CONTRATO-v0` §1); para A5/O4 y
  A7/F3 no hay fórmula de coste en el MODELO; M4 y O3 figuran «no evaluado» en DS-2.
- **Resolución DS-3.** Se adopta una **probabilidad de éxito objetivo** en rejilla declarada
  (`P* ∈ {10⁻⁶, 10⁻³, 0,5, 0,99}`, hipótesis) y se invierte el modelo **solo donde el MODELO lo
  permite**: A1/A2 por bisección en `β_d` sobre la DP; A3 por la frontera de cobertura `k=B`.
  Donde no hay función invertible, se publica el coste que el MODELO sí da (fijo por TiB, por
  identidad, energía PoW) y la celda se marca **no cuantificada por falta de definición** con la
  pieza exacta que falta.

## F3 · Convención de redondeo del déficit `d` del paseo

- **Qué falta.** `MODELO` §2.2 da `d = (μ_p − μ_a)·F` (real), pero la DP exige `d` entero y la
  ratificación no fija el redondeo. Los valores publicados de `P-PRESTAMO` (p. ej. `d=346` para
  `(1−2·0,33)·1.019 = 346,46`) son compatibles con `floor` y con `round`.
- **Resolución DS-3.** Se usa `round(Int, d)` y se declara; el caso de comprobación §4.2
  (`P=9,75·10⁻¹⁰⁸`) fija la convención (con `floor` también da 346; se documenta que ambos coinciden
  en ese punto y se prueba además el borde `d` exactamente entero).

## F4 · Derivación de semillas no consecutivas

- **Qué falta.** La orden pide «semillas fijas con `StableRNGs` no consecutivas» sin fijar la
  función de derivación.
- **Resolución DS-3.** Se adopta la mezcla SplitMix64 ya validada en `P-CLAVE`
  (`hash64(semilla_maestra ⊻ etiqueta, id)`, `src/rapido.jl`), se declara, y un test comprueba que
  las semillas de réplicas contiguas difieren y que el resultado es idéntico en serie y en paralelo.

## F5 · Forma funcional del coste de partición de identidades (A4)

- **Qué falta.** `MODELO` §3 lista `q`, `S_min` como símbolos con tres escenarios, y DS-2 remite a
  `P-TASA` (fuera de la entrada congelada) para el teorema de no proporcionalidad. No hay en el
  MODELO una `C(identidades)` explícita.
- **Resolución DS-3.** Se usa el modelo mínimo declarado `coste por identidad = q`,
  `coste por byte = q/f` (que reproduce la no proporcionalidad que DS-2 cita) barrido sobre los tres
  escenarios de `q`; se etiqueta **modelo DS-3**, no reproducción de `P-TASA`.

## F6 · Celdas E sin fórmula alguna en el MODELO

- **Qué falta.** M4 (castigo correlacionado), M3/A7 (claves retiradas), M3/A9 (censura como
  evidencia), O3 (finalidad, solo estructural), O4 (regla de consenso, sin coste en tokens), F3 en
  ZEROX (no implementado), F5 (ciclo de vida), O5/ATX. DS-2 ya las marca «no evaluado» o
  «estructural».
- **Resolución DS-3.** Se listan en `INFORME.md` §2 con estado **no cuantificado por el MODELO** y
  la pieza exacta que faltaría; no se les asigna una cifra inventada.

## F7 · La cota de Baig–Pietrzak del MODELO no cuadra con su propio texto

- **Qué falta.** `MODELO` §2.11 da
  `ℓ = ⌈ρ²φ²(1+ε)((1+ε)−1/φ)/ε⌉ + ⌈ρφ²((1+ε)−1/φ)/ε⌉ + 2⌈log φ / log(1+ε)⌉`
  y afirma que con `φ=2, ε=0,01, ρ=4` da «≈1.233 pasos de bootstrap + ≈140 de replot». La fórmula,
  evaluada literalmente, da **3.297 + 816 + 140 = 4.253** (el 2.º término no es 1.233) y el resumen
  del propio artículo (arXiv:2505.14891) da la cota principal `φ²ρ/ε = 1.600`. Hay, pues, una
  **inconsistencia interna** entre la fórmula transcrita y las cifras que la acompañan.
- **Resolución DS-3.** Se implementa la fórmula **tal como está escrita** (es la que la Ratificación
  manda reproducir) y el test de §4.7 comprueba su aritmética exacta; se publica la discrepancia
  (4.253 frente a 1.233+140 `[sic]` y frente a `φ²ρ/ε=1.600`) como **reserva declarada**, sin
  usarla como cifra de ZEROX. El orden de magnitud (10³) coincide.

## F8 · H-PUENTE y traslado de energía/precios

- **Qué falta, ya declarado por el MODELO.** Todo resultado de ventana (F2 de P-PRESTAMO, A1/A2)
  está condicionado a `H-PUENTE`, que **no existe**; los precios son hipótesis sin fuente; la
  energía Filecoin es hecho en Filecoin e **hipótesis** al trasladarla a ZEROX.
- **Resolución DS-3.** Se propaga la etiqueta `condicionado a H-PUENTE` en cada fila afectada, se
  emiten los precios como parámetro explícito (nunca constante oculta) y las tablas por dimensión
  llevan columna de etiqueta `hecho`/`derivación`/`hipótesis`/`condicionado`.

## F9 · Coste del honesto no definido como escalar único

- **Qué falta.** La orden pide «el cociente frente al coste del honesto», pero no define ese coste
  (¿almacenar? ¿almacenar + auditar? ¿incluye la retención que cobra al honesto accidental?).
- **Resolución DS-3.** Se define, declarado, `coste_honesto` = energía de almacenar la misma
  capacidad durante la misma ventana + una pasada de sellado/regeneración equivalente cuando el
  MODELO la da (P-COBERTURA §5.4) + pérdida esperada anual por castigo accidental
  `ε_h·(ρ_ret·I·T_v + c_r + I·M)` (P-PRESTAMO §6). El cociente se publica con esa definición y su
  desglose.

## F10 · El ejemplo numérico de `MODELO` §2.5 no cuadra con su propia desigualdad

- **Qué falta.** `MODELO` §2.5 escribe la región como `ρ_ret·T_v ≳ 4.000` y a la vez la
  desigualdad `κ·q·(ρ_ret·I·T_v + c_r + I·M) > V/N` con `V/N = 400`, `c_r = 10`, `M = 20`,
  `I = 1`. Con esos números la desigualdad da `ρ_ret·T_v > 370`, no `4.000` (el propio
  P-PRESTAMO §5.1 da la forma cerrada `T_v > 3.700` para `ρ_ret = 0,10`, es decir
  `ρ_ret·T_v > 370`). La cifra `4.000` es, como mínimo, un redondeo de otra convención de
  `V/N` que el MODELO no declara.
- **Resolución DS-3.** Se implementa **la desigualdad** (la que fija la región) y el test de
  §2.5 fija `ρ_ret·T_v > V/N − c_r − I·M`; la cifra `4.000` se publica como **discrepancia
  declarada** y no se usa para decidir.
