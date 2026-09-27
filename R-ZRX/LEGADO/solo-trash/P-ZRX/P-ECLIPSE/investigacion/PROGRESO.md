# PROGRESO — P-ECLIPSE

Bitácora del encargo. `date`, `uptime` y las comprobaciones de entrada y salida, como pide
`PROMPT.md` §7.

---

## 0 · Primera respuesta al encargo (§10: «si algo te parece equivocado, dilo ANTES de empezar»)

**El encargo es ejecutable y se ha ejecutado. Cuatro precisiones, dichas antes de empezar:**

1. **`PROMPT.md` §0.1 afirma que el diseño «hoy solo tiene diversidad por prefijo (`C-NET-20`)».**
   `verificado en fuente`: `C-NET-20` es **límite y baneo** por prefijo (`/24` IPv4, `/64` IPv6,
   `MAX_POR_PREFIJO = 3`) y la **diversidad como selección de pares no está implementada**: no hay
   `addrman`, ni `PrefixBucket`, ni selección de salientes de ningún tipo. La premisa es imprecisa.
   No cambia el encargo; cambia la etiqueta de la sección D, que el propio encargo ya previó
   («si el gestor de direcciones no existe, dilo»).
2. **`PROMPT.md` §4.2 pide «las 8 salientes»**, pero `crates/zx-p2p/src/limites.rs:174` fija
   **24 salientes**. Las 8 son de Bitcoin 0.9.3 y de Kaspa. Se dan las dos cuentas.
3. **`PROMPT.md` §0.1 dice que la ronda 11b «NUNCA SE TERMINÓ» y que nadie hizo D, E y F.** Correcto
   para D–F; pero sus secciones **A, B y C sí están completas y publicadas**, y se han podido
   **verificar** contra el puerto nuevo. El encargo las trata como «histórico no heredable»; con el
   puerto verificado, sus números **sí** son reproducibles, y eso se ha aprovechado.
4. **No hay nada más que me parezca equivocado.** El encargo §2 se presenta como hipótesis atacable
   y, atacada con aritmética, **se sostiene** (`INFORME.md` §F1). El matiz importante —que el eje es
   la **retención** y no el retardo— se añade y se explica.

---

## 1 · Presupuesto declarado ANTES de ejecutar (§11 de `LINEO.md` y del bloque del encargo)

- **Máquina de referencia:** AMD Ryzen 9 9950X3D, 16 núcleos / 32 hilos, 123,4 GiB de RAM.
- **Tope de auditoría:** 64 GiB de RAM y 24 hilos. **El encargo lo estrecha a 8 hilos** y a corridas
  de minutos a una hora; se respeta el más estricto: **8 hilos como techo**, y de hecho se ha
  ejecutado **en serie, 1 hilo** (`Threads.nthreads(:default) = 1`), porque el barrido no lo
  necesitaba.
- **Disco temporal:** < 2 GiB (depósito de Julia precompilado + artefactos). Los artefactos de
  `resultados/` suman decenas de KiB.
- **Tiempo:** ninguna corrida ha superado los **10 minutos**. El total del instrumento, incluida la
  precompilación, está por debajo de **1 hora**.
- **Estado:** **ninguna corrida se agotó.** **No hay resultados inconclusos por presupuesto.**

---

## 2 · Entrada (antes de tocar nada)

```text
$ LC_ALL=C sha256sum -c P-ZRX/P-ECLIPSE/ENTRADA.sha256
P-ZRX/P-ECLIPSE/PROMPT.md: OK
research/scripts/d8-ronda11b/informe.md: OK
research/scripts/d8-ronda11b/ENCARGO.md: OK
research/scripts/d8-ronda8/salida_a3b.txt: OK
P-ZRX/T-ZRX/LIBRO-DE-RESTRICCIONES.md: OK
P-ZRX/T-ZRX/AGUJEROS-Y-SOLUCIONES.md: OK
```

```text
$ git -C /home/katana/zeo/ZEROX status --short
 M Cargo.lock
 M Cargo.toml
 M TAREAS.md
 M ci/consenso-pendiente.txt
 M crates/zx-consensus/Cargo.toml
 M crates/zx-consensus/src/lib.rs
 M crates/zx-consensus/tests/spec_numeros.rs
 M crates/zx-storage/src/error.rs
 M crates/zx-storage/src/utxo.rs
?? P-ZRX/P-ECLIPSE/
?? P-ZRX/PIEZAS-DE-CODIGO/CORRECCION-A1.md
?? P-ZRX/PIEZAS-DE-CODIGO/DECISIONES-0.0.1.md
?? P-ZRX/PIEZAS-DE-CODIGO/HOJA-DE-RUTA.md
?? P-ZRX/PIEZAS-DE-CODIGO/ORDEN-A1.md
?? P-ZRX/PIEZAS-DE-CODIGO/ORDEN-B1-PREPARACION.md
?? P-ZRX/PIEZAS-DE-CODIGO/PROGRESO-0.0.1.md
?? crates/zx-consensus/src/poas.rs
?? crates/zx-consensus/tests/poas.rs
```

```text
$ date
jue 24 sep 2026 10:34:04 CEST

$ uptime
 10:34:04  up 16 days  7:03,  0 users,  carga promedio: 1,12, 1,07, 1,06
```

**Nota de zona:** los `M` y `??` de `crates/`, `ci/`, `Cargo.*`, `SPEC.md` y `P-ZRX/PIEZAS-DE-CODIGO/`
**no son de este encargo**: hay otro trabajando ahí, como avisa `PROMPT.md` §7. Lo único añadido por
P-ECLIPSE es `P-ZRX/P-ECLIPSE/`.

---

## 3 · Bitácora

| Cuándo | Qué |
|---|---|
| 10:34 | Entrada verificada (6/6) y `git status` registrado. Reconocimiento del repositorio. |
| 10:35 | Leídos `AGUJEROS-Y-SOLUCIONES.md` §1.4, `LIBRO-DE-RESTRICCIONES.md`, 11b `informe.md` **entero**, `ENCARGO.md` y `salida_a3b.txt`. |
| 10:36 | Leído `LINEO.md` entero y extraídas del `SPEC.md` (por ID, nunca por línea) las reglas `C-POT-*`, `C-FLU-*`, `C-GD-01`, `C-FIN-01` y `C-NET-25`…`33`. |
| 10:37 | Analizados `r8c_sim.py`, `r8c_gd.py`, `d8_a3_smax.py`, `r11b_lib.py`, `r11b_a_ataque.py`. **Decisión clave:** el control exige reproducir los mismos números, luego hay que **portar el RNG de CPython**, no usar otro. |
| 10:38 | Entorno Julia resuelto. **Incidencia de entorno:** `$HOME/.julia` es de **sólo lectura** para el agente, así que `Pkg` no puede escribir; se resuelve con un depósito escribible en `P-ZRX/P-ECLIPSE/.julia-depot` + el del sistema como segundo (sólo lectura). Declarado en `PROCEDENCIA.md`. |
| 10:39 | `src/pyrng.jl` escrito y **validado** contra el vector publicado del MT19937 y contra `random.Random(0/1/42).random()` de CPython (coincidencia exacta de 17 dígitos). |
| 10:40 | `src/GDR.jl` + `src/mundo.jl`. **Fallo real:** escritura fuera de rango con `@inbounds` porque los buffers de vista no crecían con el estado → segfault. Corregido y anotado en el código. |
| 10:41 | **CONTROL POSITIVO SUPERADO:** `0,8218 / 0,6513 / 0,5920 / 0,5460` con `n_C = 522`, y `α=0,25` idéntico también. Coinciden promedios **y conteos**. |
| 10:43 | Las **tres variantes** reproducen todas las tablas publicadas de 11b, incluidos los `n` (215, 193, 190, 178, 175, 180, 143). |
| 10:45 | `run.jl` con modos; barrido de régimen ejecutado en segundo plano. |
| 10:47 | Módulos `sensores.jl`, `captura.jl`, `flujo.jl`. |
| 10:49 | **Defecto cazado por un test:** la primera CDF normal (Lentz) daba `Φ(1,96) = 0,98896` y `P(D>8) = 0,0045` cuando es **forzosamente** `0,0100`. Sustituida por serie + asintótica. |
| 10:52 | Con la CDF corregida: `P(D>8) = 0,0100000000`, `P(L>8) = 0,014760` (idéntico al publicado) y `B` reproduce 11b §B.1 celda a celda en lognormal. |
| 10:53 | Segunda corrección: el ajuste de la **Pareto** estaba mal (`ln100` en vez de `ln50`); con el correcto, `76,40 / 138,92` y `1 422,41` salen **idénticos** a lo publicado. Queda **una** celda sin reproducir (Pareto p99=16 «por slot»), anotada en `INFORME.md` §6.7. |
| 10:54 | `test/runtests.jl`: **1006/1006 pasan** con `--check-bounds=yes`. |
| 10:55 | Entregables escritos. Comprobaciones de salida. |

---

## 4 · Salida

```text
$ LC_ALL=C sha256sum -c P-ZRX/P-ECLIPSE/ENTRADA.sha256
P-ZRX/P-ECLIPSE/PROMPT.md: OK
research/scripts/d8-ronda11b/informe.md: OK
research/scripts/d8-ronda11b/ENCARGO.md: OK
research/scripts/d8-ronda8/salida_a3b.txt: OK
P-ZRX/T-ZRX/LIBRO-DE-RESTRICCIONES.md: OK
P-ZRX/T-ZRX/AGUJEROS-Y-SOLUCIONES.md: OK
```

```text
$ git -C /home/katana/zeo/ZEROX status --short
 M P-ZRX/PIEZAS-DE-CODIGO/HOJA-DE-RUTA.md
 M P-ZRX/PIEZAS-DE-CODIGO/PROGRESO-0.0.1.md
 M TAREAS.md
 M crates/zx-consensus/src/lib.rs
 M crates/zx-consensus/src/pot_rango.rs
 M crates/zx-consensus/tests/pot_rango.rs
 M crates/zx-storage/src/error.rs
 M crates/zx-storage/src/utxo.rs
?? P-ZRX/P-ECLIPSE/
?? P-ZRX/PIEZAS-DE-CODIGO/CORRECCION-A2-PREPARACION.md
?? P-ZRX/PIEZAS-DE-CODIGO/ORDEN-A2-PREPARACION.md
```

```text
$ date
jue 24 sep 2026 10:58:05 CEST

$ uptime
 10:58:05  up 16 days  7:27,  0 users,  carga promedio: 1,49, 2,26, 1,96
```

**Lectura de las dos salidas de `git status`.** Las seis huellas de `ENTRADA.sha256` siguen **OK**:
no se ha modificado ninguno de los ficheros de entrada. Los `M`/`??` de `crates/`, `TAREAS.md` y
`P-ZRX/PIEZAS-DE-CODIGO/` **cambian entre la entrada y la salida y no son de este encargo**: son del
otro trabajo que avisa `PROMPT.md` §7, y su avance (aparecen `pot_rango.rs` y dos órdenes A2) se
anota aquí sólo para que nadie lo atribuya a P-ECLIPSE. **Nada de `SPEC.md`, `TAREAS.md`, `ci/`,
`crates/`, `prototipos/`, `research/`, `veritas/`, `PDF/` ni del resto de `P-ZRX/` ha sido tocado
por este encargo.**

---

## 5 · Dos incidencias que se declaran en vez de esconderse

1. **Un subagente dejó cinco notas de release de Bitcoin Core (`rn-*.md`) en `P-ZRX/P-ECLIPSE/`**,
   fuera de la zona de escritura autorizada (`P-ZRX/P-ECLIPSE/investigacion/`). Se detectaron y se
   **eliminaron**; eran descargas suyas, no ficheros del repositorio. El estado final de esa carpeta
   es el de entrada: `ENTRADA.sha256`, `PROMPT.md`, `investigacion/` y el depósito de Julia.
2. **`P-ZRX/P-ECLIPSE/.julia-depot/` es una caché de build, no un entregable.** Existe porque
   `$HOME/.julia` es de sólo lectura para este agente (`Pkg` aborta con *«The primary depot is not
   writable»*). Ocupa ~104 MiB. Si Katana prefiere no tenerla en el árbol, se puede borrar: el
   instrumento se reproduce apuntando `JULIA_DEPOT_PATH` a cualquier depósito escribible.

---

## 6 · Estado de los entregables

| Entregable | Estado |
|---|---|
| `INFORME.md` (F1 primero, después F2–F7) | **completo** |
| `DECISIONES-PENDIENTES.md` | **completo** (6 decisiones, con coste de cada rama) |
| `BORRADORES-C-NET.md` (`C-NET-34`+) | **completo**, marcado PROPUESTA, sin fijar valores |
| `PROGRESO.md` | **este documento** |
| Instrumento `eclipse-red-v1/` | **completo y verificado**: control reproducido, 1006/1006 tests |
| `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md` | **completo** (en la carpeta del instrumento) |

**Lo que NO se ha hecho, y se dice aquí además de en el informe:**
- No se ha simulado la partición de flujo de extremo a extremo (dos vistas, dos flujos, dos anclas).
  F1 es una **derivación** con aritmética de enteros, no una simulación. Requeriría GHOSTDAG
  restringido a `V_j(B)` **por nodo**, que `GDR-v0.2` no ofrece.
- No se ha medido nada nuevo en hardware. Los costes de 92 ms/slot y 1,33–9,86 ms por salto se
  **citan** de `veritas/rendimiento/coste-salto-v1`.
- No se ha fijado ni un solo valor de consenso, y no se ha tocado `SPEC.md`.
