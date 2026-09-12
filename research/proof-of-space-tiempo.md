# Proof of Space and Time — investigación con fuente primaria

**2026-09-05.** Cinco agentes en paralelo, uno por fuente, más verificación directa del hilo
principal sobre los PDF locales y la web oficial de Chia.

---

## 1 · El 61,5 % describe un diseño que Chia NUNCA implementó

Es el hallazgo que reordena todo lo demás, y está verificado en la web oficial de Chia:

> *"the Green Paper's previous version that discusses a precursor consensus **which was never
> implemented** is available here for viewing"* — docs.chia.net

El archivo se publica allí como **`Precursor-ChiaGreenPaper.pdf`**, fechado el 9 de julio de
2019. La copia local de ese precursor se retiró en la limpieza del 10 de septiembre de 2026.
La versión consultada como vigente en esta investigación fue el
[greenpaper del 12 de junio de 2026](scripts/d14-sin-comite/fuentes/chia-greenpaper-20260612.pdf).

| | Atacante | Honesto |
|---|---|---|
| Precursor 2019, sin contramedida | 26,9 % | 73,1 % |
| Precursor 2019, con `κ=3` | 38,5 % | **61,5 %** |

Y `κ` ni siquiera era protocolo: *"the value of κ is not part of the specification of Chia. Rather,
it is a **social convention** by the honest farmers"* (Remark 1).

## 2 · La condición real no es un porcentaje

Del greenpaper vigente, ecuación (2):

```
Chia is provably secure if:   space_h · vdf_h  >  space_a · vdf_a · 1.47
```

**Espacio POR velocidad de VDF.** El espacio honesto necesario depende del timelord del atacante:

| VDF del atacante | Espacio honesto necesario |
|---|---|
| igual | 59,5 % |
| 2× | **74,6 %** |
| 3× | **81,5 %** |
| 10× | 93,6 % |

Bitcoin: >50 %, y **no depende de ningún reloj**.

El 1,47 sale del *double dipping* y **es ajustable**: *"there's nothing special about the constant
1.47, it can be lowered to 1+ε for any ε>0 by increasing the number of blocks that depend on the
same challenge (in Chia this is set to at least 16)"*.

## 3 · La VDF no es opcional: hay teorema de imposibilidad

*"a secure (under dynamic availability) longest-chain protocol based on proofs of space **alone does
not exist**"* — greenpaper 2026, citando Baig y Pietrzak (FC 2025, arXiv 2505.14891).

**Esta cita cualitativa es correcta.** Verificada contra el paper el 2026-09-05.

### ⚠️ Pero el greenpaper cita MAL la parte cuantitativa — no copiarla de ahí

El greenpaper vigente (12 jun 2026, §6.2.3) reformula el teorema como un fork de longitud
`R·ε/f²`. **El paper dice otra cosa**, y en la dirección contraria en las dos variables:

| | Longitud del fork que el adversario logra | Cota inferior |
|---|---|---|
| **Paper (arXiv:2505.14891v1)** | **`ϕ²·ρ/ε`** | `ϕ·ρ/ε` |
| Greenpaper §6.2.3 | `R·ε/f²` | — |

con `ϕ` = razón de espacio honesto a adversario, `ρ` = **tiempo de replot medido en bloques**,
`ε` = factor de disponibilidad dinámica.

Contraejemplo con los parámetros de la propia figura 1 del paper (`ε=0,01`, `ϕ=2`, `ρ=4`):
el paper da **1 600 pasos**; la fórmula del greenpaper da **0,01 pasos**, o sea un fork de una
centésima de bloque. Sin sentido.

**Verificado dos veces**, de forma independiente: por D9 leyendo el PDF del paper, y por el hilo
principal contra el resumen en arXiv.

**Por qué nos importa aunque llevemos PoT** (y el teorema sea para PoSpace *sin* VDF): la variable
`ρ` es el **tiempo de replot en bloques**, y es justo la magnitud que `P-034(a)` tiene que fijar.
El sentido de la cota importa: replot **más rápido** (`ρ` pequeño) exige forks **más cortos**, o
sea ataques más baratos. Medido en `research/coste-ploteo-medido.md`: replotear 1 TiB son 300
bloques con 32 núcleos y ~44 con GPU, frente a `MAX_REORG_LENGTH = 99`.

## 4 · El timelord es el problema, no la solución

Documentación oficial: *"only the **fastest** timelord on the network will broadcast proofs at any
given time"*. Los demás son respaldo.

Y del paper de consenso: con un VDF **2× más rápido**, el espacio que necesita un atacante para el
ataque del 51 % **baja de ~46 % a ~30 %**. Cita textual del cálculo: `0.46/0.54 = 2x/(1-x). x=0.30`.

En 2023 **Chia Network Inc. fabricó y desplegó sus propios timelords ASIC**, operados por ellos en
colocations distribuidas: 800 000–1 000 000 iteraciones/s frente a ~260 000 de los no-ASIC. El
diseño no es abierto.

Es decir: **quien controla el reloj más rápido fija el umbral de seguridad de la red**, y hoy en
Chia ese alguien es la propia empresa.

## 5 · Lo que la práctica rompió

El análisis idealiza (§1.6) que las pruebas de espacio **no admiten ningún compromiso
tiempo-memoria**. Falso. Chia Network, abril 2026:

> *"Compressed plots achieved approximately 50% size reduction… Enabling grinding attacks: GPUs
> could rapidly generate and discard plots, **effectively farming without storage**."*

Su respuesta es **Proof of Space 2.0**: formato nuevo, `k` de 32 a 28, plots de ~100 GB a ~1 GB, y
**el primer replot obligatorio de su historia**. Ya está en el código de la v2.7.4
(`PLOT_SIZE_V2 = 28`) pero **sin altura de activación**: `HARD_FORK2_HEIGHT = 0xFFFFFFFA`.

## 6 · Disponibilidad en Rust

### Pruebas de espacio — hay opciones reales

| | Lenguaje | Verificador separable | En Rust |
|---|---|---|---|
| `chiapos` v1 | C++20 | sí, ~1 800 líneas | FFI oficial, 97 vectores de prueba |
| `chia-pos2` | C++20 | sí | FFI oficial, 92 K descargas, **formato sin congelar** |
| **`ab-proof-of-space`** (Autonomys) | **Rust puro** | **sí, `verify_only_raw` sin tocar el plot** | nativo, pero **nightly** y vendorizado |

**Verificar es O(1)**: ~127 invocaciones de hash, sin acceso a disco, no escala con `k`. Eso salva
buena parte de nuestro modelo anti-DoS.

### VDF — aquí no hay opciones

- **`chiavdf`** (FFI oficial a C++ + **GMP**) es la única vía seria. Mantenida, con fuzzing.
- **`chia_rs` NO incluye VDF.** El núcleo Rust de Chia no cubre esta pieza.
- Rust puro: `poanetwork/vdf`, **abandonado desde 2021**, y un fork de una sola persona de mayo de
  2026 con **1 estrella y 0 forks**.
- **No existe ningún vector de interoperabilidad** entre chiavdf y ninguna otra implementación. El
  determinismo bit a bit solo está verificado *dentro* de chiavdf — exactamente la cicatriz de
  H-001, otra vez.

## 7 · Impacto en nuestro código: mucho menor de lo que parecía

| Cubo | Reglas |
|---|---|
| **Sobreviven intactas** | **128** |
| Sobreviven con cambios | 26 |
| **Mueren** | **11** |

- `fork_choice.rs` **no necesita cambiar ni una línea de lógica**: solo el tipo que consume.
- La cabecera pierde `bits` y `nonce` — **12 de 92 bytes**.
- De 11 crates: **3 intactos** (`zx-storage`, `zx-mempool`, casi todo `zx-p2p`), 4 vacíos, 3
  parciales, 1 se reconstruye con otro propósito.
- Se libera una restricción: la preimagen ya no tiene que caber en un bloque de *rate* de SHA3.

## 8 · Lo que sí funciona de Chia, y es separable

El **protocolo de pools**: el granjero firma y elige el bloque, el pool solo agrega pagos. Eso es
resistencia a censura real que un pool de Bitcoin no tiene — y **no depende del mecanismo de
consenso**. Se puede tener en PoW.

## Lagunas declaradas

- ~~El paper de imposibilidad (Baig y Pietrzak 2025) se leyó vía resumen, no el PDF completo.~~
  **Cerrado el 2026-09-05:** D9 leyó el PDF completo y el hilo principal verificó el resumen en
  arXiv. De ahí salió el error de reformulación del greenpaper documentado en §3.
- No hay cifra medida de milisegundos de verificación de PoSpace: el coste es O(1) por construcción,
  pero nadie publica el número.
- No se verificó si el Proof-of-Time de Autonomys tiene la misma dinámica de "solo importa el más
  rápido" que el timelord de Chia. **Es la pregunta que decide si PoAS es una salida real.**
- Contradicción no resuelta entre dos documentos oficiales de Chia sobre el umbral del mecanismo
  desplegado: 42–46 % (2022) frente a 40,5–43 % (2024).
