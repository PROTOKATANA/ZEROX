# PROGRESO — P-SELLO (sellado asimétrico ligado a la rama)

**Encargo:** `P-ZRX/P-SELLO/PROMPT.md`. **Zona de escritura:** solo `P-ZRX/P-SELLO/investigacion/`.
**Categoría del instrumento:** `criptografia` (dominante: la propiedad de rivalidad entre ramas es una
propiedad del objeto y de la prueba); secundarias `consenso` y `tema de coste`. Ruta:
`investigacion/veritas/criptografia/sellado-rama-v1/`.

**Presupuesto declarado ANTES de ejecutar (LINEO §11 y §8 del encargo):** máximo **4 hilos**,
**8 GiB de RAM**, **2 GiB de disco** (incluye la caché de un depósito Julia propio; los artefactos de
cálculo son < 10 MiB), **2 h de pared**. Si se agota: checkpoint y **inconcluso**. No se confunde
timeout con falsedad. No se ejecuta `ab-proof-of-space` ni se plotta. Nada de Python.

---

## 0 · Comprobaciones de entrada (encargo §5)

```
$ cd /home/katana/zeo/ZEROX
$ LC_ALL=C sha256sum -c P-ZRX/P-SELLO/ENTRADA.sha256
P-ZRX/P-SELLO/PROMPT.md: OK
$ git -C /home/katana/zeo/ZEROX status --short
 M Cargo.lock
 M Cargo.toml
 M MIGRACION.md
 M P-ZRX/PROPUESTAS-VIABLES.md
 M README.md
 M SPEC.md
 M TAREAS.md
 M ci/consenso-pendiente.txt
 M ci/frontera-crates.sh
 M ci/reglas-sin-cablear.txt
 M ci/reglas-sin-codigo.txt
 M crates/zx-consensus/Cargo.toml
 M crates/zx-consensus/src/bloque_dag.rs
 M crates/zx-consensus/src/error.rs
 M crates/zx-consensus/src/ghostdag.rs
 M crates/zx-consensus/src/lib.rs
 M crates/zx-consensus/tests/ghostdag_bench.rs
 M crates/zx-consensus/tests/ghostdag_oraculo.rs
 M crates/zx-consensus/tests/ghostdag_prop.rs
 M crates/zx-consensus/tests/ghostdag_rust.rs
?? P-ZRX/P-ANCESTRIA/
?? P-ZRX/P-COBERTURA/
?? P-ZRX/P-LATENCIA/
?? P-ZRX/P-PUENTE-ESPACIO-TASA/
?? P-ZRX/P-RIVAL/
?? P-ZRX/P-SELLO/
?? P-ZRX/P-TASA/
?? crates/zx-consensus/src/pot.rs
?? crates/zx-consensus/tests/pot_derivaciones.rs
?? crates/zx-consensus/tests/pot_slot.rs
?? crates/zx-pot/
$ date
mié 23 sep 2026 19:18:13 CEST
$ uptime
 19:18:13  up 15 days 15:47,  0 users,  carga promedio: 1,29, 1,38, 1,98
```

**Lectura de las marcas `M`/`??`:** pertenecen a **otro encargo** que trabaja en `crates/`, `ci/`,
`SPEC.md`, `TAREAS.md` (lo avisa el encargo §5). No se tocó ninguna. Todo lo escrito en este encargo
está bajo `P-ZRX/P-SELLO/investigacion/`, que figura como `?? P-ZRX/P-SELLO/` y es íntegramente mío.

---

## 1 · Objeciones al encargo, declaradas ANTES de ejecutar

**[O1 · El encargo pregunta si la propiedad es coherente, y la respuesta es que no lo es — bajo una
premisa que el propio encargo fija.]** El §2.1 pide formalizar `Sellar(datos, rama)` y
`Religar(objeto, rama')` con `T_bajo` barato, y a la vez exige que «tener `objeto` para `A` no permita
producir peso pleno en `B`». Si `Religar` es determinista y público, el corolario de simulación de
`P-ZRX/P-COBERTURA/investigacion/INFORME.md` §3 (Teorema y Corolario 4) se aplica al par
`(objeto, rama')` **sin cambiar una palabra**: lo que se regenera es un objeto que es función
determinista y pública de `(objeto almacenado, rama')`, y el transcripto es idéntico. No es que la
construcción sea difícil: la conjunción «`T_bajo` ≤ ventana **y** obligatorio almacenar» es
**contradictoria** para esa clase. Lo desarrollo en F1 y F3.

**[O2 · El «intervalo entre cambios de punta» no es el único régimen, y el encargo lo trata como si
lo fuera.]** El objeto actual (`plot`) se liga a `history_size`, que es un **prefijo archivado**
(`PDF/autonomys-subspace/crates/subspace-core-primitives/src/sectors.rs:54-68`), no a la punta. La
tasa de re-ligadura exigida **depende de a qué se ligue**:
- atado a la **punta seleccionada** → cambia a tasa ≈ `λ` (≈ 1/s), que es el caso del encargo;
- atado a un **ancestro a profundidad `d`** → cambia cada ≈ `d/λ` slots, pero entonces **dos ramas
  que bifurcan dentro de los últimos `d` slots comparten el objeto** y la rivalidad se cae.
El instrumento publica **las dos** y muestra que la única profundidad que da rivalidad es `d ≈ 0`, lo
que devuelve el caso del encargo. No es una objeción al resultado; es un grado de libertad que el
encargo no nombra y que, si no se declara, permite una respuesta ambigua.

**[O3 · `α*` es una identidad de ESPACIO y `T_bajo` es un coste de TIEMPO; el puente no existe.]**
El encargo pide (§2.2) «mételo en la superficie `α*` y dilo con números». `α* = (1−β_d−2β_x)/2` se
demostró en `P-ZRX/P-PRESTAMO/` **en fracciones de espacio**, y el propio repositorio tiene anotado
que **no existe el puente espacio → tasa**: `P-ZRX/PROPUESTAS-VIABLES.md` («(5) Puente espacio → tasa
… **Ninguna cifra de umbral del repositorio significa lo que dice**: todos los instrumentos miden
oportunidades por slot, no fracciones de disco», fase **F0**) y `P-PRESTAMO` §0 (H-PUENTE). Por
tanto F5 se cuantifica **en dos capas separadas**: (a) aritmética exacta del reparto de espacio
—`demostrado`—; (b) la **sustitución** `β_d → β_x` inducida por el encarecimiento, que exige una
razón de costes por unidad como **entrada** y se etiqueta `derivado, condicionado a H-COSTE`. No se
convierte una cifra de núcleos en una fracción de espacio.

**[O4 · La premisa no tiene privilegio.]** El §8 lo pide y lo cumplo: si `T_bajo` suficiente para el
honesto implica `T_bajo` suficiente para el atacante, **ésa es la refutación y va en la primera
línea** de `INFORME.md`, sin construcción de rescate.

**[O5 · Advertencia heredada que confirmo y aplico.]** `P-ZRX/PROPUESTAS-VIABLES.md` (fila 12, nota
del 2026-09-23): «un VDF por rama **no es rival** —dos núcleos, dos ramas—». Un reloj secuencial
independiente por rama se paraleliza entre ramas, así que **no** cuenta como coste secuencial no
paralelizable en el sentido del Corolario 2(ii) de `P-COBERTURA`. El instrumento no lo acredita como
vía.

---

## 2 · Bitácora

| Fecha/hora | Hito |
|---|---|
| 2026-09-23 19:18 | Entrada verificada (`sha256sum -c` OK), `git status`, `date`, `uptime`. Objeciones O1-O5 escritas **antes** de ejecutar. |
| 2026-09-23 19:19 | Lectura íntegra de `veritas/LINEO.md` (627 l.), `P-COBERTURA/INFORME.md` (682 l.), `P-PERMANENCIA/INFORME.md` (503 l.), `P-PRESTAMO/INFORME.md` (587 l.), `delta-medido-v1/INFORME.md` (506 l.), `P-SEMBRADOR/INFORME.md` (241 l.), `P-INTENTO/INFORME.md` (625 l.), `research/README.md`, `time-memory-tradeoff.md`, y las líneas citadas de `plotting.rs`, `sectors.rs`, `subspace-verification/src/lib.rs`. |
| 2026-09-23 19:20 | Instrumento creado en `veritas/criptografia/sellado-rama-v1/`: `modelo.jl`, `referencia.jl`, `rapido.jl`, `validacion.jl`. `Pkg.instantiate` (depósito propio). |
| 2026-09-23 19:22 | Primer barrido F2/F4/F5/cert. Detectado un defecto propio: el LP del atacante con cota de símplex daba «todo β_x» por artefacto de la cota, no por la comparación de daños por coste. **Corregido**: F5 pasa a comparación marginal exacta + gap `s/2`, con tests independientes. |
| 2026-09-23 19:26 | Tests: 74/76 → **76/76 en verde** tras corregir dos aserciones propias mal escritas (una cota inferior de 1,14 cuando `1+0,138 = 1,138`, y el sentido de la desigualdad en el umbral). |
| 2026-09-23 19:28 | Fuentes abiertas: informe del subagente + verificación **propia** de `sealing.md` (fetch), `porep.md`, `post.md`, `fip-0019`, `fip-0017`, `sdr/_index.md`, `spacemint.txt`, `repstorage.txt`, `blmr.txt`, `ue-crypto2020.txt`, `nova.txt`, `multichain-pos.txt`. |
| 2026-09-23 19:30 | `./correr-modelo.sh` completo: tests + 4 barridos + MC + benchmarks + JET. **JET: 0 posibles errores.** Todos los TSV escritos. |
| 2026-09-23 19:31 | Entregables escritos: `INFORME.md`, `DECISIONES-PENDIENTES.md`, `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`. Depósito espurio `investigacion/veritas/.julia-depot` (de un `instantiate` con ruta equivocada) eliminado. |

## 3 · Resultado y entregables

**Veredicto: la vía (13) está muerta.** La dicotomía espacio/presupuesto cierra la clase
determinista-pública, la simulación de `P-COBERTURA` la refuerza, y la búsqueda abierta no encontró
ninguna primitiva fuera de esa clase. Detalle y cifras en `INFORME.md`; la primera línea es la
respuesta a F3.

- `INFORME.md` — F1-F6, fuentes abiertas, verificación, lo que no resuelve.
- `DECISIONES-PENDIENTES.md` — una línea: la vía está muerta, sin decisiones inventadas.
- `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md` — H1-H6 con qué las refutaría.
- `EVIDENCIA-P1-P4-FUENTES-ABIERTAS.md` + `evidencia-fuentes/` — evidencia cruda (8,3 MiB).
- `veritas/criptografia/sellado-rama-v1/` — instrumento (76 tests, 0 asignaciones en los kernels
  calientes, JET limpio) y 5 artefactos TSV.

**Presupuesto consumido:** 4 hilos, < 300 MiB de RAM, **306 MiB de disco** (298 MiB son el depósito
Julia, caché reproducible; los artefactos de cálculo son < 1 MiB), **≈ 1 min de pared**. Muy por
debajo del presupuesto declarado (8 GiB / 2 GiB / 2 h). **No inconcluso.**

## 4 · Comprobaciones de salida (encargo §5)

```
$ cd /home/katana/zeo/ZEROX
$ LC_ALL=C sha256sum -c P-ZRX/P-SELLO/ENTRADA.sha256
P-ZRX/P-SELLO/PROMPT.md: OK
$ git -C /home/katana/zeo/ZEROX status --short
 M Cargo.lock … (las mismas 19 marcas M del otro encargo; ninguna tocada)
?? P-ZRX/P-SELLO/  (mío)  ?? P-ZRX/P-ANCESTRIA/ ?? P-ZRX/P-COBERTURA/ ?? P-ZRX/P-LATENCIA/
?? P-ZRX/P-PUENTE-ESPACIO-TASA/ ?? P-ZRX/P-RIVAL/ ?? P-ZRX/P-TASA/ ?? crates/zx-consensus/src/pot.rs
?? crates/zx-consensus/tests/pot_derivaciones.rs ?? crates/zx-consensus/tests/pot_slot.rs ?? crates/zx-pot/
$ date
mié 23 sep 2026 19:31:41 CEST
$ uptime
 19:31:41  up 15 days 16:01,  0 users,  carga promedio: 1,99, 3,34, 3,14
```

`PROMPT.md` intacto (`OK`). Ninguna marca `M` ni `??` ajena fue tocada; todo lo nuevo está bajo
`P-ZRX/P-SELLO/investigacion/`.

## 5 · Defectos propios detectados y corregidos

1. **LP con cota de símplex (19:22).** El primer modelo de sustitución maximizaba `β_d+2β_x` con
   presupuesto **y** cota de espacio; con `c_x = 1` la cota de espacio dominaba y devolvía «todo β_x»
   para cualquier coste, un artefacto. **Corregido** a la comparación marginal exacta
   (daño por unidad de coste) más el gap `s/2`, que es lo que el encargo pide. Vector de regresión:
   `validar_umbral` (7 razones) y `validar_gap`.
2. **Dos aserciones de test mal escritas (19:26).** `1.14 ≤ 1+0.138` (falso; el valor es 1,138) y el
   sentido de la desigualdad en `dano_por_coste` para `φ=3/5`. Corregidas; ninguna afectaba a un
   artefacto publicado (los tests no habían pasado a verde antes).
3. **Depósito Julia duplicado (19:31).** Un `instantiate` con `$PWD/../../.julia-depot` creó
   `investigacion/veritas/.julia-depot` (141 MiB) antes de corregir la ruta a `../../../`. Eliminado;
   queda solo `investigacion/.julia-depot` (298 MiB).

**No hay tests tautológicos** (encargo §4): cada magnitud se contrasta con una vía de mecánica
distinta (§8.1 del `INFORME.md`).
