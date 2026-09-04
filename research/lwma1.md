# LWMA-1 — reglas de consenso para el retarget · agente zx-d2-consenso, 2026-09-04

> Fuente: `zawy12/difficulty-algorithms` @ `8d83967968ae22b2cd4ca5d9da08bfdb663c60cd` (código + issues
> extraídos vía API) + 6 implementaciones reales inspeccionadas. Material en `/tmp/.../scratchpad/`
> (`issues/`, `impls/`, `difficulty-algorithms/`).

## ⚠️ HALLAZGO BLOQUEANTE

**No existe "la" fórmula de LWMA-1.** Zawy publicó DOS en el mismo issue #3, con resultados numéricos distintos:

| | LWMA-1 CN (cuerpo de #3) | LWMA-1 target (#3 comment-442129791) |
|---|---|---|
| Espacio | dificultad `uint64` | **target** `arith_uint256` |
| Media | aritmética de dificultades | media de targets (= media armónica de D) |
| Semilla | `previous = timestamps[0] − T` (anómala) | `previous = block(h−N).time` |
| Suelo de `t` | `if (L < N*N*T/20) L = N*N*T/20` | **ausente** |
| Factor 99/100 | sí | **ausente** |
| Overflow guard | `avg_D > 2000000*N*N*T` — **INCORRECTO** (ver §overflow) | N/A (256 bits) |

**ZEROX usa `nBits`/target de 256 bits + Nakamoto por trabajo acumulado → la variante correcta es la de TARGET.**
Es también la de Tari (Rust, producción, N=90, FTL=540, block time efectivo 120 s — coincidencia exacta con ZEROX).
**NUNCA la variante `uint64` CN.**

## Constantes (T = 120 s)

```
T          = 120                          // DECISIONES.md §2
N          = 90                           // PROPUESTO — requiere firma humana (P-003)
k          = N*(N+1)*T / 2   = 491_400    // normalización, precomputar (no evaluar la expresión)
NK         = N * k           = 44_226_000
ST_CAP     = 6*T             = 720
T_FLOOR    = N*(N+1)*T / 20  = 49_140     // = k/10, suelo de la suma ponderada
FTL        = N*T / 20        = 540
MTP_W      = 11
POW_LIMIT      = <256-bit, PENDIENTE — P-004>
MIN_TARGET     = <256-bit, >= 2^64, PENDIENTE — P-004>
TARGET_INICIAL = <256-bit del génesis, PENDIENTE — P-004>
```
Todos los enteros derivados son exactos (sin resto) con estos valores.

## Reglas de retarget (van al SPEC verbatim)

**C-DIFF-01 · Pureza y dominio.** El retarget es `siguiente_target(H, cab[H−N−1..H−1]) -> Target`.
Únicas entradas: altura `H`, los `N+1` timestamps `ts(H−N−1..H−1)`, los `N` targets `decode(nBits(H−N..H−1))`.
Prohibido leer reloj local, hora de red, mempool, config, o cabeceras fuera de esa ventana.

**C-DIFF-02 · Arranque.** Si `1 <= H <= N` → `siguiente_target(H) = TARGET_INICIAL`. Primer retarget calculado: `H = N+1 = 91`. `nBits` del génesis = `compact(TARGET_INICIAL)`. **No** usar `POW_LIMIT` como arranque. **No** encoger `N` dinámicamente — la ventana es siempre exactamente `N`.

**C-DIFF-03 · Reconstrucción monótona de solvetimes (clamp).** Todo en `i64`:
```
p := ts(H − N − 1)
para j = 1..N:
    h := H − N − 1 + j
    c := si ts(h) > p entonces ts(h) sino p + 1     // NUNCA "if st<1 then st=1"
    st[j] := min(ST_CAP, c − p)                      // ST_CAP = 720
    p := c
```
Invariante: `1 <= st[j] <= 720`. Sin negativos ni ceros **por construcción**. El clamp `min(6T,·)` se aplica DESPUÉS de la reconstrucción y SOBRE LA DIFERENCIA, nunca sobre el timestamp.

**C-DIFF-04 · Suma linealmente ponderada.** `t := Σ_{j=1..N} j * st[j]`  (i64, rango [4_095, 2_948_400]).

**C-DIFF-05 · Suelo de `t`.** ⚠ DIVERGENCIA ENTRE FUENTES. **Propuesto: incluirlo** (P-003).
```
si t < T_FLOOR entonces t := T_FLOOR      // T_FLOOR = 49_140
```
Sin él: un atacante con timestamps a `padre+1` lleva `t` a 4_095 → dificultad **×120 en un bloque** → freeze al retirarse. Con él, el techo es **×10**. El CN lo tiene; el zawy-BTC lo perdió respecto al BTG original.

**C-DIFF-06 · Suma de targets (exacta).** `S := Σ_{j=1..N} decode(nBits(H − N − 1 + j))`  en **U512, SIN divisiones intermedias** (divergencia deliberada de Flux/zawy-BTC que hacen `target/N/k` por término = N truncamientos).

**C-DIFF-07 · Target siguiente.** `next := (S * t) / NK`  (U512, división entera hacia cero).
Equivale a `media(targets) · LWMA(st) / T`.

**C-DIFF-08 · Acotado.** `si next > POW_LIMIT → POW_LIMIT`; `si next < MIN_TARGET → MIN_TARGET`.

**C-DIFF-09 · Ida y vuelta por `nBits` (crítico).** `nBits(H)` válido ⟺ `nBits(H) == compact(next)`. El valor que consume C-DIFF-06 es SIEMPRE `decode(nBits(h))`, nunca el `next` de alta precisión. **Prohibido** persistir/realimentar el target sin cuantizar → split entre nodos full y headers-first.

**C-DIFF-10 · Nada más.** Prohibido: jump rule de LWMA-2/4, tempering de LWMA-4, clamp por bloque tipo Flux/Digishield, timespan limits, redondeo a dígitos significativos, `if (ST<1) ST=1`, sort de timestamps, lag, cut, MTP como bloque más reciente de la ventana.

## Reglas de timestamp

**C-TS-01 · Monotonía** (endurecimiento LWMA-3/4). `ts(H) >= ts(H−1) + 1`. Rechazo **permanente**. Implica la MTP-11 clásica y hace inalcanzable la rama `p+1` de C-DIFF-03 (que se mantiene como defensa en profundidad y para evaluar cadenas candidatas).

**C-TS-02 · MTP-11 solo para timelocks.** `MTP(H) = mediana(ts(H−1..H−11))`. Reloj para HTLC/timelocks (BIP-113). **NO** entra en el retarget.

**C-TS-03 · Future Time Limit.** `ts(H) <= reloj_local + 540`. Rechazo **NO permanente** (diferir/reintentar; nunca cachear como inválido ni banear al par). Si se cachea como inválido permanente → split garantizado con partición temporal.

**C-TS-04 · Prohibida la hora de red.** Ninguna regla de consenso usa mediana de pares, NTP ni `GetAdjustedTime()`. Solo reloj local. Motivo: con FTL=540 << 4200, la regla "revert to node time" de Bitcoin/Zcash abriría un Sybil del 33% (zcash#4021). Sin peer time, la vulnerabilidad no existe.

**C-TS-05 · Regla del minero (no consenso).** `ts = max(reloj_local, ts(padre)+1)`; no publicar hasta `ts <= reloj_local + 540`.

## Sobre "LWMA-1 + hardening 3/4, sin jump rule de 2" (DECISIONES.md §2)

**Es correcto, no requiere cambio.** Matices con evidencia:
- **La jump rule de LWMA-2 NO tuvo un exploit documentado.** Se retiró por evidencia empírica: *"I could not show they were better than LWMA-1"* (#3); empeoraba el 30% de monedas que necesitaban mejora (#50, caso Wownero #24); sesgaba métricas (#24).
- El ÚNICO exploit real de la familia motivó **LWMA-3**: `if (ST<0) ST=0` → timestamps retrasados se vuelven solvetimes largos artificiales → hunde la dificultad (una moneda: 4800 bloques en 5h). Ese fix **YA ES parte de LWMA-1** → es C-DIFF-03.
- El "endurecimiento de timestamps" = C-TS-01 (monotonía, sustituye MTP-11) + C-DIFF-03 (manejo out-of-sequence). Es lo que zawy llama LWMA-3 absorbido en LWMA-1.

## Overflow — BUG CONFIRMADO en el código `uint64` publicado

El guard `avg_D > 2000000*N*N*T` es mucho mayor que el umbral seguro real `(2^64−1)/(N(N+1)T·99)`, dejando banda desprotegida: **10.3× para N=90/T=120** → overflow desde dificultad ≈1.9e11 ≈ **1.6 GH/s de SHA3** (trivial con unas GPU). Wownero lo parcheó en producción (altura 307800) y hardcodeó 6 dificultades. **→ La variante `uint64` está prohibida. La de target en U512 es inmune.**

Cotas en U512 (N=90, T=120): `S·t ≈ 2^252` (cabe en U256 solo si `POW_LIMIT <= 2^228`; **mandar U512** hace la cota independiente de POW_LIMIT). Error de truncamiento < 2^-64 con `MIN_TARGET >= 2^64`. La cuantización de `nBits` NO se acumula en LWMA (es una media, no una multiplicación recursiva) — ventaja concreta sobre relative-ASERT/EMA.

Cotas de respuesta por bloque (con C-DIFF-05): `next/media ∈ [1/10, 6]` → dificultad sube hasta ×10, baja hasta ÷6. Sin el suelo, techo ×120.

## No-determinismo (para D8/D6)

1. **Cero `f32`/`f64` en consenso** (Masari/Oxen usan `double`+`boost::round`). Test de CI que grepee `zx-consensus`.
2. **Rust `--release` hace wrapping**, debug panic → dos nodos, dos resultados. Todo con `checked_*` en U512/i64, error de validación, nunca wrapping.
3. Realimentación de precisión → C-DIFF-09.
4. Truncamiento: `st[j] >= 1` (C-DIFF-03) garantiza que ningún operando i64 sea negativo.
5. Orden de la suma `S`: asociativa, pero fijar el orden del bucle en el SPEC para reproducibilidad de vectores.
6. **Ancho del timestamp `u32` vs `u64`** — no decidido (año 2106). Recomendado `u64`. → P-004.
7. `t < T_FLOOR`: `T_FLOOR` como constante precomputada (49_140), no expresión.
8. FTL contra reloj local: no es no-determinismo SI se implementa como rechazo temporal (C-TS-03).
9. Reorgs: el retarget se evalúa sobre la cadena **candidata**, no `chainActive`.

## Implementaciones inspeccionadas (todas mutuamente incompatibles en consenso)

| Repo @ commit | Ruta | Espacio | N | T | Desviaciones |
|---|---|---|---|---|---|
| RunOnFlux/fluxd @ 69db01f | src/pow.cpp:175 | target U256 | 60 | 120 | clamp ±150/67%; sin suelo; división por término; **peer time** |
| tari-project/tari @ 89ea795 | lwma_diff.rs:104 | dificultad u128 | **90** | ~120 | media aritmética; sin suelo; sin 99/100; reloj local |
| wownero @ 2c544de | difficulty.cpp:379 | u64/u128 | 144 | 300 | LWMA-1 CN literal (incl. `timestamps[0]-T`); 6 dif. hardcoded por overflow |
| masari, oxen | difficulty.cpp | **double** | 60 | 120 | media armónica en float + `boost::round` |

## Decisiones que NO están en DECISIONES.md → PREGUNTAS-PARA-KATANA.md

- **P-003**: N (ventana) — propuesto 90; y suelo C-DIFF-05 incluir/excluir — propuesto incluir. Ambos son números de consenso.
- **P-004**: `POW_LIMIT`, `MIN_TARGET`, `TARGET_INICIAL` (256-bit) + ancho del timestamp (`u32`/`u64`).
- **P-005**: factor de corrección 0.9975 (sesgo del clamp 6T → T_efectivo ≈ 120.30 s). Opción (A) no corregir y documentar, (B) corregir con `(S·t·10000)/(NK·9975)`. Requiere derivación de D9.
- **P-006**: **medida de trabajo acumulado con dificultad variable.** Zawy (#58, #82) sostiene que `Σ 2^256/(target+1)` no es correcta cuando la dificultad cambia mucho, y falta un ajuste `N/(N−1)`. **Afecta al fork choice de ZEROX.** No investigado — merece un encargo propio a zx-d2-consenso.
- Nota: zawy 2025 (#76) recomienda WTEMA/ASERT sobre LWMA para proyectos nuevos. DECISIONES.md ya tiene ASERT como fallback. La justificación de LWMA sigue válida (resiste el forwarded-stamp del 38% que sí afecta a ASERT, #50), pero constar que va contra el consejo más reciente del autor.

## Lagunas
- No hay vectores oficiales de LWMA. Propuesta: golden vectors con reimplementación Python (bigint) cruzada contra Rust (D6).
- `test_DAs.cpp` (54 KB, repo de zawy) es su banco de simulación — no compilado; posible oráculo para D6/D9.
- La semilla `timestamps[0]−T` del CN: sin justificación de zawy en ningún issue. Sesgo +0.0244% dif. Se DESCARTA (se usa `ts(H−N−1)`), pero consta como divergencia consciente.
