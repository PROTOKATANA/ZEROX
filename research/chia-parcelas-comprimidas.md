# Chia: parcelas comprimidas y el coste real de generar bajo demanda

**Fecha:** 2026-09-05 · **Clon:** `PDF/chia-blockchain/`, checkout `f87270c0` (`2.7.4-rc2-16-gf87270c0`, 2026-09-03).

Este informe existe porque `DECISIONES.md §15` afirmó que ZEROX sería «el modelo de Chia sobre datos
arbitrarios, sin su tamaño de red para amortiguarlo». Había que convertir eso en números.

## 1 · Lo desplegado hoy es PoS v1, no v2

```python
# chia/consensus/default_constants.py:83
HARD_FORK2_HEIGHT=uint32(0xFFFFFFFA),  # TODO: todo_v2_plots finalize fork height
```

**Proof of Space 2.0 está en el código y no corre en ningún nodo de mainnet.** El centinela sigue
sin fijar, pese a que Chia Network anunció públicamente una altura objetivo (~9 562 000, nov. 2026).
Divergencia código↔anuncio: **manda el código**.

⚠️ Lección de método: leer un repositorio no basta si no se comprueba que la rama está **activa**.

## 2 · Dos compresiones distintas, y solo una preocupa

| | Reducción | Qué exige | Sancionada |
|---|---:|---|---|
| Oficial, niveles C0–C9 | **~25,8 %** (k32: 101,4 → 75,2 GiB) | CPU para C1–C5, GPU CUDA para C7/C9 | sí |
| *Grinding* tipo DrPlotter | **~50 %** | **GPU al 99 % de forma continua durante el farming** | tolerada, no sancionada |

El ~50 % que cita `CLAUDE.md` es el segundo. DrPlotter no solo comprime al plotear: su «DrSolver»
**reconstruye con la GPU, en cada intento de prueba, lo que el disco no guarda**. Es el compromiso
tiempo-memoria que el greenpaper supone imposible (§1.6.iii), ocurriendo en producción.

El propio **CHIP-0048** —la propuesta de PoS 2.0— lo da como su motivación:
*"In PoS1, plot ID grinding provides attackers up to 3.5× leverage"*.

**LAGUNA:** no se pudo determinar qué fracción del netspace actual usa parcelas comprimidas.
`xch.farm` publica el gráfico pero es JS y no se pudo leer el valor. **No inventar un porcentaje.**

## 3 · El número que decidió §17

Objetivo de diseño publicado por Chia Network para PoS 2.0, del Q&A oficial:

> *"a 5090 GPU ($3700) will be only able to mimic around 20 TB ($20) of storage via plot grinding"*

Dividiendo — **aritmética nuestra sobre cifra suya**:

| Red honesta | GPUs para imitarla entera | Capital |
|---|---:|---:|
| 10 TiB | **0,55** | **< $3 700** |
| 100 TiB | 5,5 | ~$20 000 |
| 1 PiB | 56 | ~$207 000 |
| Chia hoy (~7 EiB efectivos) | ~403 500 | ~$1 490 M |

**Lo que protege a Chia no es su algoritmo: es que su red pesa exabytes.** El multiplicador de 200×
que venden es **relativo**; en términos absolutos, una red joven de decenas de TiB la iguala un
aficionado con una tarjeta gráfica de escritorio.

Y ese multiplicador es el del diseño **que todavía no corre**. Con PoS1 —lo realmente desplegado—
no existe ni siquiera ese factor: el ~50 % de reducción vía grinding ya es real hoy.

**VEREDICTO:** el coste de construir la tabla **no basta por sí solo** por debajo del orden de
**cientos de TiB a bajo PiB** de netspace honesto — exactamente donde una red joven vive sus
primeros años.

## 4 · Por qué esto NO se transfiere a ZEROX tal cual

⚠️ **El número de Chia mide otro ataque.** Su *plot ID grinding* genera y descarta identificadores
de parcela; el sector de Autonomys **contiene piezas reales que hay que tener descargadas**. No se
conjura.

Medido en `coste-ploteo-medido.md` sobre la implementación que ZEROX sí va a usar:

| Acción, por sector | Coste |
|---|---:|
| Auditarlo honestamente desde disco | **9,32 µs** |
| Regenerarlo para poder auditarlo | **83,6 s** |
| **Razón** | **≈ 9,0 millones ×** |

Es lo contrario del cuadro de Chia. La razón estructural la formalizó D9: lo que el atacante debe
almacenar no son los datos —regenerables— sino las **máscaras** `blake3(proof)`, salida de hash
pura, y producirlas cuesta **1,1004 core-segundos por registro**.

**Corolario permanente, y hay que decirlo en voz alta:** el contenido de la pieza no aporta nada a
la dureza del almacenamiento, con relleno o sin él. **PoAS en ZEROX es Chia sobre datos arbitrarios
de forma permanente.** §15 lo presentó como coste transitorio; no lo es. Toda la literatura de
parcelas comprimidas de Chia aplica sin descuento, y **ésa es la deuda que hay que vigilar**.

## 5 · Fuentes y lagunas

**Verificado en el clon:** `chia/consensus/default_constants.py`, `pos_quality.py`,
`pot_iterations.py`, `chia/types/blockchain_format/proof_of_space.py`, `chia/plotting/create_plots.py`.

**Ya en Rust (`chia_rs`):** `compute_plot_id_v2`, `create_v2_plot`, `validate_proof_v2`,
`solve_proof`, `Prover`. Sigue en C++ solo la ruta v1 legacy (`chiapos >= 2.0.10`).
**No es adoptable para ZEROX de todos modos**: no usamos el formato de parcela de Chia (§14).

**Lagunas declaradas:**
- Segundos/plot k32 v1 en una GPU concreta con bladebit-CUDA: sin benchmark primario.
- Fracción del netspace de Chia que usa compresión: no obtenida.
- Si `HARD_FORK2_HEIGHT` se fijó después del checkout leído.
- El mecanismo de encadenado de 16 fragmentos de PoS2 que da su techo teórico de compresión: citado
  del Q&A oficial, **derivación matemática no verificada**.

⚠️ **Pendiente y relevante:** `PDF/time-memory-tre-off-proof-space.pdf` es el paper que acota
formalmente todo esto y **no se había abierto nunca**. Ver `time-memory-tradeoff.md`.
