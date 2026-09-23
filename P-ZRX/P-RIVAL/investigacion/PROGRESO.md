# PROGRESO — P-RIVAL / TR-v0.1

Bitácora con `date`, `uptime`, presupuesto y las comprobaciones de entrada y salida exigidas por
`PROMPT.md` §5. Todo lo escrito vive bajo `P-ZRX/P-RIVAL/investigacion/`.

---

## 0 · Objeción previa al encargo (antes de ejecutar)

Declarada antes de empezar, como pide `PROMPT.md` §8, y confirmada después:

1. **«Rival» no se define por «el coste crece con las ramas»** (un VDF por rama también lo hace). Se
   define por **P4**: el recurso se paga de nuevo por ancestría
   (`P-ZRX/P-ANCESTRIA/investigacion/INFORME.md`
   F1). El VDF por rama es un peaje absorbible; el PoW es proporcional al peso producido.
2. **La premisa «la pata cierra el doble farmeo» no se sostiene.** El trabajo de la segunda copia
   también pesa a favor de la rama privada, así que la ventaja de umbral **no baja nunca**; con
   compuerta, sube. El resultado es un «no» y se enuncia en la primera línea del informe.
3. **El 26,8941 % no aplica a una pata de PoW** (coincido con el encargo), pero por una razón
   precisa: es una cota de grinding con **re-muestreo gratis**, y un PoW paga cada reintento con
   hashes del mismo presupuesto rival. La condición bajo la que **sí** aplicaría queda escrita.

No se recomienda adoptar ni retirar PoW.

---

## 1 · Entrada (comprobaciones de `PROMPT.md` §5)

```bash
cd /home/katana/zeo/ZEROX
LC_ALL=C sha256sum -c P-ZRX/P-RIVAL/ENTRADA.sha256
git -C /home/katana/zeo/ZEROX status --short
date
```

**`sha256sum`:** `P-ZRX/P-RIVAL/PROMPT.md: OK` (exit 0).

**`date`:** `mié 23 sep 2026 19:15:31 CEST`.
**`uptime`:** `19:15:31  up 15 days 15:44,  0 users,  carga promedio: 1,48, 1,35, 2,09`.

**`git status --short` (entrada):** ficheros **ya marcados por otro encargo**, registrados y **no
tocados**:

```text
 M Cargo.lock                              M crates/zx-consensus/src/bloque_dag.rs
 M Cargo.toml                              M crates/zx-consensus/src/error.rs
 M MIGRACION.md                            M crates/zx-consensus/src/ghostdag.rs
 M P-ZRX/PROPUESTAS-VIABLES.md             M crates/zx-consensus/src/lib.rs
 M README.md                               M crates/zx-consensus/tests/ghostdag_bench.rs
 M SPEC.md                                 M crates/zx-consensus/tests/ghostdag_oraculo.rs
 M TAREAS.md                               M crates/zx-consensus/tests/ghostdag_prop.rs
 M ci/consenso-pendiente.txt               M crates/zx-consensus/tests/ghostdag_rust.rs
 M ci/frontera-crates.sh                   ?? P-ZRX/P-ANCESTRIA/  ?? P-ZRX/P-COBERTURA/
 M ci/reglas-sin-cablear.txt               ?? P-ZRX/P-LATENCIA/  ?? P-ZRX/P-PUENTE-ESPACIO-TASA/
 M ci/reglas-sin-codigo.txt                ?? P-ZRX/P-RIVAL/     ?? P-ZRX/P-SELLO/
 M crates/zx-consensus/Cargo.toml          ?? P-ZRX/P-TASA/      ?? crates/zx-consensus/src/pot.rs
                                           ?? crates/zx-consensus/tests/pot_derivaciones.rs
                                           ?? crates/zx-consensus/tests/pot_slot.rs
                                           ?? crates/zx-pot/
```

**Presupuesto declarado antes de ejecutar:** **4 hilos**, 4 GiB de RAM, 256 MiB de artefactos en
disco (el depósito de precompilación de Julia, 194 MiB, se declara aparte y es caché regenerable),
minutos por tarea, techo de 2 h de pared. **No se agotó.**

---

## 2 · Lecturas (enteras, no citas de una línea)

`AGENTS.md`, `README.md`, `MIGRACION.md` (entero), `research/README.md`, `veritas/LINEO.md` (entero),
`research/dag-poas-ancla-de-finalidad.md` (entero), `research/dag-poas-balizas-auditoria.md` (entero),
`research/coste-ploteo-medido.md` (entero), `research/pot-aes-asic-chacha.md` (entero),
`P-ZRX/P-PRESTAMO/investigacion/INFORME.md` (entero), `P-ZRX/P-TASA/investigacion/INFORME.md`
(entero), `P-ZRX/P-ANCESTRIA/investigacion/INFORME.md` (entero), `SPEC.md` §11 (C-GD-01…C-GD-11) y
§7.2 (C-ORD-01…C-ORD-04) y C-HDR-06, `P-ZRX/P-RANGO/propuesta/PROPUESTA-SPEC.md:70-109,418-447`
(tasa de peso ≈ piezas). No se abrió ningún precedente externo.

---

## 3 · Modelo y decisiones

- **Composición principal: aditiva** `W_b = (1−θ)σ_b + θρ_b`; es la única en la que `θ` es
  literalmente la fracción de peso del trabajo rival. Multiplicativa y de umbral se analizan como
  variantes. Justificación en `INFORME.md` §2.1.
- **Control `θ = 0`:** `α* = (1−β_d−2β_x)/2`, exacto, contra bisección independiente.
- **Hallazgo central (F3):** `V = α*(0,0) − α*(β_d,β_x) = β_d/2 + β_x`, **independiente de `θ` y
  `ρ`**. Con compuerta, `V` **sube**. La pata nunca reduce la ventaja.
- **F4:** `β_x` **abandona** la pública y su trabajo se reasigna → coste rival neto cero y efecto
  doble; para todo `θ > 0`, `c > 0`, `β_x` domina a `β_d`. Encarecer `β_d` empuja a `β_x`.
- **F6:** el cierre exige `θ > (1+β_d+2β_x)/(2−ρ+β_d+2β_x) ≥ 1/2`; con `ρ ≥ 1` no existe `θ`. **No
  hay `θ` útil.**

---

## 4 · Defectos propios detectados y corregidos

1. **Bucle roto** en el primitivo de compuerta (`control_umbral`) referenciaba una función
   inexistente. Eliminado; sustituido por dos propiedades enunciadas (hash de sobra / atacante
   escaso). Vector de regresión en `test/runtests.jl`.
2. **Borde `σ_priv = 0`** en la composición multiplicativa (`α = 0`): la bisección lanzaba error.
   Ahora los factores nulos deciden el signo sin ambigüedad.
3. **Bisección aditiva con `g(0) ≥ 0`**: lanzaba error cuando el atacante ya gana sin espacio propio.
   Ahora devuelve `0` (el valor correcto).
4. **`β_x` no es `2×β_d` con compuerta.** El primer test lo suponía; es falso si `β_d` **compra** el
   trabajo de su segunda copia. Se distingue **trabajo comprado** de **trabajo reasignado**: con
   reasignación (el caso de `β_x`) sí es el doble. De esa corrección nació el hallazgo de F4.
5. **`ventaja_beta_x` estaba fijada a `1`** mientras `marginal_beta_x` daba `2(1−θ)+2θc`, es decir
   `1 + θc/(1−θ)`: la función de ventaja no coincidía con su derivada y el test no las ataba.
   Corregida a `1 + θc/(1−θ) = 2×β_d` y el test ata ahora las dos en toda la rejilla. Detectada
   releyendo el informe completo, no por un test (que es exactamente el riesgo que el encargo avisa).
6. **`code_warntype` sin `InteractiveUtils`** en `bench/benchmarks.jl`: fallo de importación,
   corregido con `using InteractiveUtils`.
7. **La afirmación universal «`V` nunca baja con `θ`» era FALSA**, y la contradicción interna
   `§3.1`/`§4.2` sobre el factor de compuerta de `β_x`. **Las dos las encontró la verificación
   independiente, no mis tests** (ver §4bis). Corregidas: forma cerrada multiplicativa
   `V = [β_d+β_x(1+k)]/(1+k)`, artefacto `F3b-multiplicativa.tsv`, test del contraejemplo, `Modelo A`
   declarado para la aditiva y reescritura de F6.

Los siete tienen su comprobación en `test/runtests.jl` o su corrección verificada en `BENCH.txt`.

---

## 4bis · Verificación independiente (dos especialistas)

Se lanzaron dos verificadores independientes sobre el informe y el instrumento (matemáticas y citas).
**Encontraron dos errores reales míos que los tests no detectaban:**

1. **Matemáticas.** `A3` («la ventaja de umbral no depende de `θ`») es **falsa como enunciado
   universal**: sólo vale en la composición **aditiva**. Contraejemplo en la **multiplicativa** con
   `ρ_priv/ρ_pub = 1/2`, `β_d = β_x = 1/10`: `V = 0,1500 → 0,1481 → 0,1442 → 0,1333 → 0,1111 →
   0,1002`. El instrumento sólo probaba `ρ_priv = ρ_pub`, donde `V` es constante, y por eso pasaba.
   **Corregido**: F6 pasa de «no existe `θ` útil» a **«depende de la composición»**; se añadió la
   forma cerrada, el artefacto `F3b` y el test de regresión. También señaló que `g_aditivo_desde_tasas`
   es la **misma identidad** que `g_aditivo` (no una ruta independiente) y que la diferencia finita
   sobre una función afín es una guarda, no una prueba: §7.1 del informe se reetiquetó.
2. **Citas.** Revisó cita por cita contra las fuentes. Encontró que `§4.2` fijaba
   `V_βx = 1+θc/(1−θ)` mientras `§3.1` daba `∂V/∂β_x = 1`, contradicción interna cierta: la
   `§3.1` omitía el factor de compuerta en el término de `β_x`. **Corregido** con el `Modelo A`
   declarado. Además corrigió diez matices de cita (ver abajo).

**Matices de cita corregidos en el informe:** `e_hash` barre **4** órdenes, no 5; la cita de balizas
incluye la condicional (`:72-74`); la definición de `c` se atribuye a `P-ANCESTRIA` F2.1, no a
`ancla-de-finalidad:313-319`; `razón(SR)` con paridad (`SR/(SR+1)` si impar); `coste-ploteo:92` no
dice «1 hilo»; las «10 instrucciones» del PoT están en `:15-17`; `C1` se acota a v0.2/v0.3; `P-TASA`
§2.2 no afirma que «las propuestas anteriores cayeron»; `τ_min ∝ f*` es `P-TASA` §2.3 (y §4.2 la
carga); rutas con `...` escritas completas.

**Lo que la verificación NO encontró:** ningún error en `α*`, en el control `θ=0`, en `θ_imp`, en el
dominio de la compuerta ni en la aritmética de `F5`. Las dos corridas independientes dieron
**1.121/1.121**, coherentes con `TEST.log`.

---

## 5 · Corridas

```bash
cd P-ZRX/P-RIVAL/investigacion/veritas/consenso/trabajo-rival-v1
export JULIA_DEPOT_PATH="$PWD/.julia-depot:/home/katana/.julia"

# 1) Perfil de referencia: 1.121 controles, 0 fallos, 1 hilo, --check-bounds=yes
JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 \
  /home/katana/zeo/ZEROX/veritas/julia.sh --project=. --check-bounds=yes test/runtests.jl

# 2) Control θ=0 y artefactos F1…F6
JULIA_NUM_THREADS=4 OPENBLAS_NUM_THREADS=1 \
  /home/katana/zeo/ZEROX/veritas/julia.sh --project=. run.jl --control --seed 0x524956414c

# 3) Benchmarks (uptime anotado dentro del propio BENCH.txt)
JULIA_NUM_THREADS=4 OPENBLAS_NUM_THREADS=1 \
  /home/katana/zeo/ZEROX/veritas/julia.sh --project=. bench/benchmarks.jl
```

| corrida | resultado | artefacto |
|---|---|---|
| tests exactos | **1.121 / 1.121** en verde | `resultados/TEST.log` |
| control `θ=0` | reproduce `(1−β_d−2β_x)/2` exacto | salida de `run.jl --control` |
| artefactos | F1…F6 escritos | `resultados/*.tsv`, `CORRIDA.log` |
| benchmarks | tabla LINEO §6 | `resultados/BENCH.txt` |

`uptime` antes del bloque de benchmarks: `19:27:49  up 15 days 15:57,  carga 5,67` ⇒ **medido con
carga ajena** (la carga superó los 4 hilos declarados). Hardware: AMD Ryzen 9 9950X3D (`znver5`),
32 hilos lógicos, 123 GiB, Julia 1.13.0.

---

## 6 · Salida (comprobaciones de `PROMPT.md` §5)

```bash
cd /home/katana/zeo/ZEROX
LC_ALL=C sha256sum -c P-ZRX/P-RIVAL/ENTRADA.sha256   # P-ZRX/P-RIVAL/PROMPT.md: OK
git -C /home/katana/zeo/ZEROX status --short         # 30 entradas ajenas, sin cambios; sólo ?? P-ZRX/P-RIVAL/
date                                                 # mié 23 sep 2026 19:36:51 CEST
uptime                                               # 19:36:51  up 15 days 16:06,  carga 1,63
```

**`git status --short` (salida): idéntico al de entrada** en todo lo ajeno; la única diferencia es el
contenido nuevo bajo `?? P-ZRX/P-RIVAL/`, que es de este encargo. **No se editó, movió ni borró nada**
de `SPEC.md`, `TAREAS.md`, `ci/`, `crates/`, `prototipos/`, `research/`, `veritas/`, `PDF/` ni del
resto de `P-ZRX/`. `PROMPT.md` y `ENTRADA.sha256` intactos (checksum OK).

**Escrito por este encargo (sólo bajo `P-ZRX/P-RIVAL/investigacion/`):** `INFORME.md`,
`DECISIONES-PENDIENTES.md`, `PROGRESO.md`, y el instrumento
`veritas/consenso/trabajo-rival-v1/` (`Project.toml`, `Manifest.toml`, `src/*`, `test/runtests.jl`,
`bench/benchmarks.jl`, `run.jl`, `INFORME.md`, `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`,
`resultados/*`, `.julia-depot/` como caché regenerable).
