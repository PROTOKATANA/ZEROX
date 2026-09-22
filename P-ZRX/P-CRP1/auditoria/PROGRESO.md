# PROGRESO — P-CRP1 · bitácora

**Encargo:** `P-ZRX/P-CRP1/PROMPT.md` — «¿Son reales los diez defectos atribuidos a CRP-v0.1, y
cuánto mueven sus cifras?»

**Presupuesto declarado (LINEO §7 y bloque obligatorio §8, adaptado por el encargo):**
máximo **4 hilos** (hay otros encargos en la máquina; tope conjunto 24), ≤ **8 GiB de RAM**,
≤ **1 GiB de disco temporal**. Si se agota: checkpoint y estado **inconcluso**. Julia en CPU con
`veritas/julia.sh`; **nada de Python**.

---

## 0 · Comprobaciones de ENTRADA (desde la raíz, antes de tocar nada)

```text
$ LC_ALL=C sha256sum -c P-ZRX/P-CRP1/ENTRADA.sha256
... 37 líneas ...
[exit 0]  →  37/37 OK

$ git -C /home/katana/zeo/ZEROX status --short
 D ZEROX-EN-NUMEROS.md
?? .trash/
?? P-ZRX/
?? veritas/consenso/poda-post-v1/
?? veritas/consenso/prueba-recursiva-v1/
?? veritas/seguridad/

$ date
lun 21 sep 2026 16:41:42 CEST
```

`uptime` antes de la primera corrida: `carga promedio: 0,00, 0,05, 0,08` sobre 32 hilos lógicos.

---

## 1 · Zona de trabajo y desviaciones

- Escritura **exclusiva** en `P-ZRX/P-CRP1/auditoria/`. Nada fuera de ahí fue creado, editado ni
  movido. `PROMPT.md` y `ENTRADA.sha256` de `P-ZRX/P-CRP1/` sólo se leyeron.
- Copia congelada: `cp -a veritas/seguridad/coste-rama-privada-v1 auditoria/copia`.
- **No hizo falta corregir la ruta de GDR.** El encargo lo preveía; la comprobación dice que no:

  ```text
  $ diff -rq veritas/seguridad/coste-rama-privada-v1 \
             P-ZRX/P-CRP1/auditoria/copia
  (sin salida)
  ```

  `ruta_gdr()` (`copia/src/rapido.jl:158-171`) sube por los directorios padre hasta 12 niveles y
  encuentra `veritas/consenso/ghostdag-rank-v1/src/GhostdagRank.jl` en la raíz del repositorio.
  **El `diff` es vacío: la única modificación permitida no fue necesaria.** No hay ningún cambio
  que registrar en este apartado.

- **Desviación de entorno (no de código).** Bajo el sandbox de escritura de esta sesión,
  `$HOME/.julia` es de **solo lectura** (`EROFS` al crear `~/.julia/logs/manifest_usage.toml.pid`),
  así que `veritas/julia.sh` falla al instanciar. Solución aplicada, sin tocar ni el instrumento ni
  GDR: un envoltorio local, `auditoria/julia-local.sh`, que fija

  ```bash
  export JULIA_DEPOT_PATH="<auditoria>/.julia_depot:$HOME/.julia"
  export JULIA_NUM_THREADS=4
  export OPENBLAS_NUM_THREADS=1
  ```

  `JULIA_DEPOT_PATH` admite una **pila** de depots: el primero es escribible (dentro de la zona de
  trabajo) y el segundo aporta los paquetes ya instalados en solo lectura. Versión de Julia:
  **1.13.0** en todos los artefactos, idéntica a la del instrumento original.

---

## 2 · Qué se ejecutó y dónde quedó

| artefacto | comando | resultado |
|---|---|---|
| `salidas/repro-tests.txt` | `julia-local.sh --project=copia --check-bounds=yes copia/test/runtests.jl` | **45/45** ✓ (reproduce `PROCEDENCIA.md:13`) |
| `salidas/gdr-d1-d8.txt` | `julia-local.sh --project=copia gdr-d1-d8.jl` | fichas D1 y D8 con GDR-v0.2 |
| `veritas/seguridad/crp1-defectos-v1/resultados/TESTS.txt` | `julia-local.sh --project=. --check-bounds=yes test/runtests.jl` | **60/60** ✓ |
| `.../resultados/run-resumen.txt` | `julia-loca.sh --project=. run.jl --resumen --out run-resumen.txt` | fichas D2–D7, D9, D10 |
| `.../resultados/BENCH.txt` | `julia-local.sh --project=. bench/benchmarks.jl` | tabla de rendimiento (LINEO §6) |
| `.../resultados/ENTORNO.txt` | — | `uptime` y códigos de salida |

---

## 3 · Comprobaciones de SALIDA (desde la raíz, al terminar)

```text
$ LC_ALL=C sha256sum -c P-ZRX/P-CRP1/ENTRADA.sha256
[exit 0]  →  37/37 OK   (las 34 de CRP-v0.1 + PROMPT.md + los dos encargos)

$ git -C /home/katana/zeo/ZEROX status --short
 D ZEROX-EN-NUMEROS.md
?? .trash/
?? P-ZRX/
?? veritas/consenso/poda-post-v1/
?? veritas/consenso/prueba-recursiva-v1/
?? veritas/seguridad/

$ date
lun 21 sep 2026 17:09:40 CEST
```

`git status` es **idéntico** antes y después: no se añadió ni modificó nada fuera de
`P-ZRX/P-CRP1/auditoria/` (que ya aparecía como parte del árbol no rastreado `?? P-ZRX/`). Las
huellas de entrada siguen verificando 37/37 tras todo el trabajo: **ninguna entrada fue alterada**.

`uptime` al terminar: `carga promedio: 0,51, 1,04, 1,27` — por debajo de los 4 hilos asignados, así
que **ningún tiempo publicado lleva la etiqueta «medido con carga ajena»**.

---

## 4 · Incidencias y fallos reproducibles

1. **`~/.julia` de solo lectura.** Resuelto con el depot híbrido (§1). No es un fallo del
   instrumento. Queda como entrada mínima reproducible: `JULIA_DEPOT_PATH` con pila.
2. **Primera versión de la DP con índice de estados mal puesto para el evento estricto (D3).** Con
   la absorción en déficit `≤ −1`, el estado vivo «déficit 0» no existía en el vector de estados y
   su transición se perdía; el resultado era `P(estricto)/P(empate) = 0,16` en vez de `≈ q/p =
   0,667`. **Detectado por el propio contraste**: la razón debe ser `≈ q/p` por la cota de
   martingala. Corregido reindexando los estados (`k` ↔ déficit `k + despl`, `despl = 0` para
   empate y `−1` para estricto), con regresión en `test/runtests.jl` T7. **Ninguna cifra publicada
   de esta auditoría viene de la versión defectuosa.**
3. **`_logpmf_poisson` recomputaba `log k!` en cada llamada.** La tabla exacta de varianza tardaba
   **159 s**; con log-factoriales acumulados tarda **0,18 s** (×880). No cambia ningún resultado.
4. **`validar_ruina_forma_cerrada` con tolerancia demasiado fina para la enumeración.** El error era
   de truncar el **horizonte** (600 pasos), no el método: la masa no absorbida a los 600 pasos es
   ~1,4e-8 relativa. Se subió a 4000 pasos con frontera `m+300` y aritmética `BigFloat` (con
   `Rational` los denominadores crecían como `5^k` y era inviable). Ahora la coincidencia es
   < 1e-9.
5. **`peso_exacto` vs `valores_aceptados` en el borde `sr = 2^64−1`.** La expectativa inicial del
   test confundía ambos: `valores_aceptados(2^64−1) = 2^64−1` (sr impar) mientras
   `peso_exacto(2^64−1) = 2^64`. Corregido el test; la fórmula no cambia.
6. **`sed -i` mal empleado sobre `gdr-d1-d8.jl`** truncó el fichero a 20 líneas durante la
   edición. Reescrito íntegro y reejecutado; la salida válida es la de `salidas/gdr-d1-d8.txt`. No
   afectó a ninguna entrada ni a ningún recálculo.

---

## 5 · Cronología

| hora (CEST) | hito |
|---|---|
| 16:41 | verificación de entrada 37/37; `git status`; `uptime` |
| 16:42–16:55 | lectura de `AGENTS.md`, `veritas/LINEO.md` (627 líneas), `ENCARGO-07v2` §2, CRP-v0.1 completo y GDR/PCO por delegación independiente |
| 16:55 | copia `cp -a`; `diff` vacío; creación de la zona `auditoria/` |
| 17:00 | reproducción de la suite original: **45/45** |
| 17:00–17:06 | kernels de recálculo, suite propia **60/60**, fichas D1/D8 con GDR |
| 17:06 | `run.jl --resumen` y `bench/benchmarks.jl` |
| 17:09 | verificación de salida 37/37; `date`; `uptime` |

---

## 6 · Cumplimiento de las reglas de validez del encargo §5

| regla | cumplimiento |
|---|---|
| No citar archivo, línea o artículo sin abrirlo | todas las citas de este informe se leyeron; los falsos positivos descartados están listados en `DEPENDIENTES.md` §9 |
| Etiquetar cada afirmación | hecho en `INFORME.md` y `CIFRAS.md` (`demostrado`, `verificado en fuente`, `reproducido`, `recalculado`, `medido`, `derivado`, `estimado`, `no determinado`) |
| No validar por autoridad | `PROCEDENCIA.md` y el encargo 07v2 se comprobaron contra el código y contra recálculos; el resultado es que **los dos están equivocados, y no en lo mismo** |
| Un test que compara una fórmula consigo misma no es un test | es precisamente D7; los recálculos se contrastan con oráculos independientes (enumeración exhaustiva, sistema racional, martingala, MC con semillas no consecutivas) |
| No fijar parámetros de consenso | no se fija `S`, `Δ`, `k`, `α` ni umbral alguno |
| No admitir «en la liga de PoW» ni «seguro al 50 %» | no se usan; `INFORME.md` §4 explica por qué no se sostienen |
| Cerrar con «Lo que esta auditoría NO resuelve» | `INFORME.md` §5 |
| Decir ANTES si algo del encargo parece equivocado | ver §7 |

---

## 7 · Objeciones al encargo, dichas antes de empezar y mantenidas

1. **D5 dice «recalcula sin Monte Carlo (convolución exacta de dos procesos de Poisson compuestos,
   o DP con masa conservada)».** Es correcto y hacedero; conviene precisar que la comparación debe
   hacerse con los pesos **enteros** `w(sr)`, no con `Float64`, porque `w(sr_a)/w(sr0)` es
   exactamente `K` sólo en el límite: los empates `A_a·w(sr_a) = A_h·w(sr0)` tienen probabilidad
   positiva (2,7e-3 con `K = 1`) y con `Float64` se clasificarían mal.
2. **D2 dice «ruina exacta en `Rational{BigInt}`».** La ruina del paseo **compuesto** de Poisson no
   es racional (las pmf llevan `e^{−μ}`). La lectura que he aplicado es la del propio D3 —retícula
   de paso `1/g` con pasos ±1, déficit `z = d·g`—, que **sí** es exacta en `Rational{BigInt}`, y
   además es **cota superior rigurosa** del paseo compuesto por la martingala. El paseo compuesto
   lo doy aparte, por DP de masa conservada, con su intervalo.
3. **La guía del encargo pide para D1 «mira `n_azules` frente a `n_total`, puntas por slot y si
   algún test o resultado ejercita anticonos o `rojo_k`».** Aviso de que `rojo_k` **no existe como
   identificador** en GDR-v0.2: es la etiqueta documental del valor `0x01` de `tipos`. Lo trato
   como el concepto, y lo digo explícitamente en la ficha.
4. **El encargo pide «una fila por cada cifra publicada» en `CIFRAS.md`.** He incluido también las
   que no se pueden recalcular, marcadas `no determinable`, en vez de omitirlas.
5. **`P-ZRX/P-CRP1/auditoria/veritas/seguridad/crp1-defectos-v1/` ya existía vacío.** Lo he
   poblado; no había ningún entregable previo que respetar.
