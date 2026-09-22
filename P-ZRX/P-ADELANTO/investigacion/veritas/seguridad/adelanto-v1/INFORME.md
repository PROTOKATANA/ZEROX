# ADL-v1.0 — Informe del instrumento

`A(ρ, L, I, W_dec, D, S_max)` con `pot_output = salida(f, slot + D)` (D-2 = A), bajo las reglas
vigentes. **Categoría dominante `seguridad`**; secundarias `consenso` (las reglas que la restringen) y
`rendimiento` (el precio de (h) en núcleos por nodo). Motivo de la categoría, declarado como exige
LINEO §1.

**Alcance.** Este proyecto mide el **evaluador matemático** y su oráculo de eventos. **No** implementa
el PoT, **no** implementa el VDF de la revelación retardada y **no** mide `ρ` real ni el coste de un
intento dirigido del sembrador. Sus salidas certifican el modelo introducido, no una regla de consenso
elegida.

**Conclusión, en una línea:** `A = L + I − W_dec − D` en el régimen estacionario, **independiente de
`ρ`**; `D` resta; `(h)` baja la ventana de `L+I` a `≈I` al coste de `1 + L/I` núcleos por nodo, y bajo
`C-FLU-01` ese coste tiene suelo `1 + F_slots/I`. La justificación completa está en
`../../INFORME.md`; las premisas que la sostienen, en `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`.

---

## 1 · Modelo

### 1.1 Fronteras de slots firmables

Firmar el slot `s` en el instante `t` exige (i) `PoT ≥ s + D` —el campo es `salida(f, s+D)`,
`C-POT-05`— y (ii) flujo determinado hasta `s+D` —horizonte `Γ(t)`—. De ahí

```text
Γ(t) = t + I_slots + L_slots − W_dec                 cota de conocimiento (ronda 7 y 9c)
h(t) = mín( t , Γ(t) − D )                            frontera honesta
a(t) = mín( ρ·t , Γ(t) − D )                          frontera del atacante
A(t) = a(t) − h(t)
```

y con `ρ > 1` en el dominio viable `D ≤ L − W_dec`:

| Régimen | `A` | `D` |
|---|---|---|
| `Γ − D < t` | `0` | — |
| `t ≤ Γ − D < ρt` | **`L + I − W_dec − D`** | resta |
| `Γ − D ≥ ρt` | `(ρ−1)·t` | se cancela |

### 1.2 El núcleo histórico, reproducido como oráculo de regresión

```text
A_core(ρ,L,I,W_dec) = máx(0, (L − 1 − W_dec) + I·(1 − 1/ρ))   ρ > 1 ;  0   ρ ≤ 1
```

Transcrito literalmente desde `P-ZRX/P-SEMBRADOR/investigacion/veritas/seguridad/sembrador-v1/src/modelo.jl:90-103`
y reproducido bit a bit (test §1). **No se hereda como resultado**: se conserva como vector de
regresión permanente.

### 1.3 Revelación retardada

```text
A_con_h(ρ) = máx(0, (I + W_dec − 1) − (L + I)/ρ)
ρ*         = (L + I)/(I + W_dec − 1)          [donde se anula]
ρ*_cont    = (L + I)/(I + W_dec)              [invierte (h.6) exactamente]
coste_rel  = 1 + L/I                          [multiplicador de verificación]
núcleos    = c_v · (1 + L/I),  c_v = 0,0961 s/slot  [medido, verify]
líneas     = ⌈L/I⌉ + 1
```

### 1.4 Contrafactuales (diagnóstico, nunca resultado)

| Nombre | Qué modela | Estado |
|---|---|---|
| `A_add` | reto derivado de `pot_output` ⇒ `D` **suma** | **prohibido** por `C-POT-03` y `R-FIN-14(e)` |
| `A_sub` | `D` grava solo al atacante, frontera honesta sin desplazar | **inconsistente** con `C-POT-05` |
| `A_D` | histórico con `D` restado | generalización en la moneda de `A_core` |

---

## 2 · Representación y elección de estructura de datos

| Decisión | Elección | Motivo |
|---|---|---|
| Fila de parámetros | `struct` inmutable `isbits` de 10 campos `T` | el kernel consume todos los campos juntos; no hay campo que se recorra solo sobre millones de filas ⇒ **AoS**, no `SoA` de entrada |
| Salida del barrido | `Vector{ResultadoAdelanto{T}}` preasignado | una posición por fila, sin objetos por celda |
| Vista plana | `Matrix{T}` preasignada (`barrer_soa!`) | exportar a TSV sin temporales |
| Orden de la rejilla | `ρ` varía más rápido | recorrido contiguo sobre el eje que el encargo pide densificar |
| Descartado | `StaticArrays`, `StructArrays`, `Dict`, `BitVector`, CSR, `Graphs.jl` | no hay tamaño fijo pequeño, ni dispersión, ni grafo: ~12 funciones escalares por fila |
| Paralelismo | `Threads.@threads` sobre bloques contiguos de 4096 filas | escritura disjunta, sin reducción, sin estado compartido ⇒ resultado independiente de los hilos (LINEO §7) |
| Semántica numérica | `Float64` para el kernel, `BigFloat` 256 bits y `Rational{BigInt}` para los umbrales | ningún veredicto discreto (`vivo`, `manda_F`, `ρ < ρ*`) se decide en `Float64` (LINEO §5.3) |

**Sin `@fastmath`, sin `@simd`, sin `@turbo`, sin `Float32`, sin `@inbounds`** (el kernel no indexa;
`barrer!` sí lo usa y el test cubre dimensiones). Sin `@fastmath` en ninguna ruta.

---

## 3 · Validación

Todos los asserts pasan. `Pkg.test()` **pasa** (`Testing AdelantoV1 tests passed`, 100/100) y también
la ejecución directa `julia --project=. test/runtests.jl`. Detalle en `resultados/VALIDACION.txt`.

| # | Comprobación | Criterio | Resultado |
|---|---|---|---|
| 1 | Regresión `A_D(D=0)` vs transcripción literal de SEM-v1 (88 filas) | igualdad exacta | **`maxdiff = 0,0`** |
| 1b | Los 7 valores publicados por SEM-v1 | error ≤ 0,005 y `w` idéntico | error ≤ **0,0034**, `w` idéntico |
| 2 | Bordes de `ρ`: `A_core(1)=0`, acantilado; `A_frontera` continuo | `A_frontera(1)=0` y `A_frontera(1+10⁻⁹) < 10⁻³` | pasa |
| 3 | `D`: resta, satura en 0, contrafactuales | identidad | pasa |
| 4 | Transitorio y saturación (`ρ ≥ ρ_trans`) | `A_frontera` constante en `ρ` | pasa |
| 5 | `(h)`: `A_con_h(ρ*)=0`, residuo `ρ→∞ = I+W_dec−1` | exacto | pasa |
| 6 | `C-FLU-01` en los tres regímenes | exacto | pasa |
| 7 | `(h.6)`: `I*` invierte `ρ*_cont` | error relativo ≤ `10⁻¹²`; `I*(F=2h,ρ_max=2,5,W_dec=45)=4 725 s` | pasa |
| 8 | Kernel vs `BigFloat` 256 bits (1 134 filas) | error rel. ≤ `64 eps` y enteros exactos | peor **1,27·10⁻¹⁴**, 0 violaciones |
| 9 | `A_frontera` vs **Sim-v1** (8 valores de `ρ`) | ≤ 1 slot | **1,0 slot exacto** (convención discreta) |
| 10 | Invariantes: monotonías, continuidad, `vivo`, `L_derivada` | 0 fallos | pasa |
| 11 | Umbrales discretos `Float64` vs `Rational{BigInt}` (576 filas) | 0 discrepancias | pasa |
| 12 | Barrido con hilos == serial | igualdad de `struct`s | pasa |
| 13 | Cotas de Fase 3 | `sup_A_con_h = 0` con `ρ_max ≤ ρ*` | pasa |

### 3.1 Sim-v1 — el oráculo independiente

`simular_fronteras` **no evalúa ninguna forma cerrada**. Construye la lista de épocas
(`T_j`, `s_j`), deriva `Γ(t)` de ella (`Γ = s_{i*+1} + L − 1`, con `i*` la última época con
`s_i + W_dec ≤ t`) y calcula las fronteras con las dos restricciones. La comparación con la forma
cerrada da **una diferencia constante de exactamente 1 slot**, que es la misma convención discreta que
el `−1` de `A_core`. Se publica la diferencia, no se absorbe con una tolerancia holgada.

---

## 4 · Rendimiento

`resultados/BENCH-h1.txt` … `BENCH-h8.txt`, `WARNTYPE.txt`, `JET.txt`, `PERFIL.txt`.

| Variante | Tiempo mediano | Asignaciones | Hilos | Resultado frente al oráculo |
|---|---:|---:|---|---|
| Oráculo `BigFloat` 256 bits | 2,358 µs/fila | 91 | 1 | fuente de verdad numérica |
| Oráculo `Sim-v1` (400 épocas) | 0,307 µs | 3 | 1 | fuente de verdad estructural |
| `evaluar_fila` (kernel, 1 fila) | 4,65 ns | 0 | 1 | `≤ 64 eps` frente a BigFloat |
| `barrer!` serial, 100 000 filas | 0,9127 ms (9,13 ns/fila) | **0 bytes** | 1 | idéntico |
| `barrer_hilos!`, 100 000 filas | 0,1593 ms con 8 hilos | 42 (una vez) | 8 | **idéntico** al serial |

**Escalado** (medido con el mismo script a `JULIA_NUM_THREADS = 1, 2, 4, 8`): speedup 1,00× / 1,88× /
3,43× / **5,76×** y eficiencia 100 % / 93,9 % / 85,7 % / 71,9 %. **Se conserva 8 hilos** para el barrido
grande; para la rejilla real del encargo (decenas de filas) la configuración correcta es **1 hilo**,
porque el barrido completo dura menos de un milisegundo y las tareas solo añaden sobrecarga.

`@allocated barrer!` sobre 100 000 filas = **0 bytes**: el bucle no asigna. `@code_warntype` no muestra
`Any`; **JET `report_call` y `report_opt` sobre `evaluar_fila` y `barrer!`: `No errors detected`**. El
perfil (3 000 repeticiones del barrido, 3·10⁸ filas evaluadas, `PERFIL.txt`) atribuye el trabajo a
`evaluar_fila`, `desafios_nucleo` y la aritmética escalar de `Base`; no aparece ninguna asignación,
ningún `Dict` y ninguna llamada a `log`/`exp`: el coste es el que el modelo dice que es.

---

## 5 · Reproducibilidad

```bash
cd /home/katana/zeo/ZEROX/P-ZRX/P-ADELANTO/investigacion/veritas/seguridad/adelanto-v1
JULIA_DEPOT_PATH="/tmp/dsh-julia-depot:$HOME/.julia" \
JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 \
  /home/katana/torio/.juliaup/bin/julia --project=. --threads=1,0 run.jl --modo todo
# pruebas, por las dos vías
JULIA_DEPOT_PATH="/tmp/dsh-julia-depot:$HOME/.julia" \
  /home/katana/torio/.juliaup/bin/julia --project=. --threads=1,0 test/runtests.jl
JULIA_DEPOT_PATH="/tmp/dsh-julia-depot:$HOME/.julia" \
  /home/katana/torio/.juliaup/bin/julia --project=. --threads=1,0 -e 'using Pkg; Pkg.test()'
```

`Manifest.toml` fija el árbol exacto (reutilizado del proyecto verificado de SEM-v1, con `Dates` y
`Test` añadidos como dependencias directas). `julia-version.toml` fija Julia 1.13.0. **No hay semilla:
el instrumento es determinista.** La única aleatoriedad del diseño (offsets de ancla) se sustituye por
una rejilla fija y explícita.

**Nota de entorno.** En la máquina de este encargo `$HOME/.julia` es de solo lectura, así que la caché
de compilación se redirige con `JULIA_DEPOT_PATH`. El envoltorio `veritas/julia.sh` no lo hace; se
documenta aquí porque afecta a la reproducibilidad del comando, no al resultado.

---

## 6 · Lo que este instrumento NO resuelve

- **No implementa el PoT ni el VDF**: `A_con_h` es la forma cerrada publicada, no una medición.
- **No mide `ρ` real** ni el coste de un intento dirigido del sembrador.
- **No fija ningún parámetro de consenso**: `L_suelo_slots`, `I_slots`, `F`, `D`, `S_max` y `ρ_max`
  entran por CLI como símbolos.
- **No modela** `π_DAG`, propagación, retarget durante el ataque, competencia intra-slot, orfandad ni el
  bootstrap completo.
- **No demuestra** la premisa de disciplina del timekeeper honesto (premisa 6 de
  `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`), que decide si `D` resta o se cancela.
