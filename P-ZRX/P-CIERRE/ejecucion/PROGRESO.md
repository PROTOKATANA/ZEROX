# PROGRESO — P-CIERRE

Bitácora obligatoria del encargo (`P-CIERRE/ENCARGO.md` §Reglas 6): huellas de la entrada,
`git status --short` y `date` al empezar y al terminar cada fase.

---

## FASE 1 — inicio

```
$ date
dom 20 sep 2026 20:11:05 CEST

$ LC_ALL=C sha256sum -c P-CIERRE/ENTRADA.sha256
P-CIERRE/ENCARGO.md: OK
P-CIERRE/PROMPT.md: OK
P-CIERRE/procedencia/PROCEDENCIA-ancla-inyeccion-v2.md: OK
P-CIERRE/procedencia/PROCEDENCIA-pot-primitiva-v1.md: OK
P-CIERRE/procedencia/PROCEDENCIA-puerta-cobertura-v1.md: OK
P-CIERRE/procedencia/PROCEDENCIA-regla-flujo-v1.md: OK

$ git status --short
 M SPEC.md
 M TAREAS.md
 M ci/reglas-sin-cablear.txt
 M ci/reglas-sin-codigo.txt
?? P-2.1/
?? P-CIERRE/
?? P-FLUJO/
?? P-POT/
?? P-PUERTA/
?? P-SEMBRADOR/
?? P-ZRX/
?? problemas/
?? veritas/consenso/poda-post-v1/
?? veritas/consenso/prueba-recursiva-v1/
?? veritas/seguridad/
```

**Entrada íntegra: 6/6 OK.** El árbol de partida ya traía `SPEC.md`, `TAREAS.md` y los dos `.txt`
de `ci/` modificados respecto a `HEAD`; la fase 1 **no los toca**, así que ese estado debe ser
idéntico al terminar.

### Lecturas del §0 completadas antes de tocar nada

`AGENTS.md` · `MIGRACION.md` · `SPEC.md` §0 y las secciones que el plan edita (§4.5, §6.1, §7.1,
§7.3, §11, §12, §16.6, §17) · `P-2.1/SINTESIS.md` entero · `P-POT/propuesta/PROPUESTA-SPEC.md` y
`DECISIONES-PENDIENTES.md` · `P-FLUJO/propuesta/PROPUESTA-SPEC.md` (2 039 líneas) y
`DECISIONES-PENDIENTES.md` · las cuatro `P-CIERRE/procedencia/PROCEDENCIA-*.md` ·
`veritas/consenso/ghostdag-rank-v1/PROPUESTA-SPEC.md` y `HUELLAS.sha256` (precedente de forma) ·
`veritas/seguridad/coste-rama-privada-v1/PROCEDENCIA.md` · `TAREAS.md` §2.1, §2.3, §2.7, §3, §4.2 ·
los cuatro `ci/*.sh` y los dos `.txt`.

### Tres avisos dados antes de empezar

1. **`C-FLU-19` no existe:** se renombró a `C-FIN-01` en la revisión 5 de la propuesta
   (`P-FLUJO/propuesta/PROPUESTA-SPEC.md:101-103`). El hueco en la numeración `C-FLU` es
   deliberado y no se reutiliza.
2. **`C-FLU-12.1` no puede ser un ID de línea en el SPEC.** `ci/citas-spec.sh` extrae los IDs con
   `grep -oP '^\*\*\K[A-Z]+-[A-Z]+-[0-9]+[a-z]?'`: escribir `**C-FLU-12.1**` al principio de una
   línea produciría `C-FLU-12` duplicado. Va como cláusula dentro de C-FLU-12.
3. **Defecto interno de la propuesta, no resuelto aquí:** `C-FLU-17` conserva la frase «DF-2 sigue
   intacta: el nodo **MUST NOT** cambiar de flujo por este indicador»
   (`P-FLUJO/propuesta/PROPUESTA-SPEC.md:1556-1559`), que `C-FLU-22` (D-F9 = C) contradice.
   Anotado en `PLAN-SPEC.md` como duda; decide Katana.

---

## FASE 1 — cierre

```
$ date
dom 20 sep 2026 23:34:07 CEST

$ LC_ALL=C sha256sum -c P-CIERRE/ENTRADA.sha256
P-CIERRE/ENCARGO.md: OK
P-CIERRE/PROMPT.md: OK
P-CIERRE/procedencia/PROCEDENCIA-ancla-inyeccion-v2.md: OK
P-CIERRE/procedencia/PROCEDENCIA-pot-primitiva-v1.md: OK
P-CIERRE/procedencia/PROCEDENCIA-puerta-cobertura-v1.md: OK
P-CIERRE/procedencia/PROCEDENCIA-regla-flujo-v1.md: OK

$ git status --short
 M SPEC.md
 M TAREAS.md
 M ci/reglas-sin-cablear.txt
 M ci/reglas-sin-codigo.txt
?? P-2.1/
?? P-CIERRE/
?? P-FLUJO/
?? P-POT/
?? P-PUERTA/
?? P-SEMBRADOR/
?? P-ZRX/
?? problemas/
?? veritas/consenso/ancla-inyeccion-v2/
?? veritas/consenso/poda-post-v1/
?? veritas/consenso/pot-primitiva-v1/
?? veritas/consenso/prueba-recursiva-v1/
?? veritas/consenso/puerta-cobertura-v1/
?? veritas/consenso/regla-flujo-v1/
?? veritas/seguridad/
```

**Entrada íntegra: 6/6 OK.** `SPEC.md`, `TAREAS.md` y los dos `.txt` de `ci/` siguen exactamente
igual que al empezar la fase (` M` por cambios previos a este encargo, ninguno mío). Las cuatro
líneas nuevas de `git status` son los cuatro destinos migrados; **no hay ningún `?? resultados/`**.

### Entregables de la fase 1

| Archivo | Qué es |
|---|---|
| `P-CIERRE/ejecucion/MIGRACION.md` | Las cuatro migraciones, los dos cambios de ruta, las cuatro pruebas y el control de identidad |
| `P-CIERRE/ejecucion/PLAN-SPEC.md` | **55 ediciones**, una por fila, con texto actual y propuesto literales, procedencia y dudas |
| `P-CIERRE/ejecucion/control-hon-4/` | La salida real de la reejecución de `hon-4`, con sus huellas |
| `P-CIERRE/ejecucion/PROGRESO.md` | Este archivo |

### Lo que la fase 1 dejó verificado

```
ANCLA-v0.2  suite --check-bounds=yes, 1 hilo        2 763 / 2 763   exit 0
PCO-v0.1    suite --check-bounds=yes, 1 hilo          239 /   239   exit 0
ppot-vectores  cargo test --release --offline            4 /     4   exit 0
control hon-4  w.csv / g.csv / resumen.csv          idénticos byte a byte al original
HUELLAS.sha256 de los cuatro destinos               92+63+14+11 = 180 / 180 OK
ENTRADA.sha256 de los cuatro destinos                 4+1+2+5 =  12 /  12 OK
ci/citas-spec.sh (línea base, sin tocar nada)       191 reglas, 22 sin cablear, exit 0
ci/alcance-consenso.sh                              verde, exit 0
ci/dependencias-exactas.sh                          28 dependencias exactas, exit 0
ci/frontera-crates.sh                               verde, exit 0
```

> **Nota para la fase 2:** los cuatro guardianes se invocan como `bash ci/<guardián>.sh` desde la
> raíz. Invocarlos como `./ci/<guardián>.sh` da «Permiso denegado» en este entorno para
> `dependencias-exactas.sh` y `frontera-crates.sh` — es el envoltorio de ejecución, no los
> scripts, que tienen su bit `x`. Los cuatro salen **en verde** con el árbol tal como queda al
> cerrar la fase 1, así que cualquier rojo en la fase 2 será culpa de la fase 2.
>
> **El crate nuevo `veritas/consenso/pot-primitiva-v1/vectores/` NO entra en el workspace** —lleva
> su propio `[workspace]`— y `ci/frontera-crates.sh`, que corre `cargo metadata` sobre la raíz, lo
> confirma: sigue verde. `cargo test --workspace` no lo toca.

### Dos cosas que hay que leer antes de aprobar el plan

1. **Me equivoqué en el control de identidad y lo corregí antes de darlo por bueno.** Mi primera
   comparación fue inválida: comparé dos copias del mismo archivo. `run.jl` escribe en `resultados/`
   **relativo al directorio de trabajo**, así que la reejecución escribió en la **raíz del
   repositorio**, no en la carpeta del instrumento. Lo vi en `git status`. La comparación buena
   —contra la salida que la reejecución produjo de verdad— **da idéntico byte a byte**, y está en
   `MIGRACION.md` §3.4. Es un **defecto del instrumento original**, documentado en su `METODO.md`
   y **no corregido**: el único cambio de código autorizado era el `include` de GDR.
2. **El plan lleva 14 dudas anotadas y NO resueltas** (`PLAN-SPEC.md` §8), más tres «malas
   noticias» que no son dudas sino estado del proyecto (§8.1). Las tres que más pesan:
   - **D-9:** `C-FLU-17` se contradice con `C-FLU-22`; retiro dos frases suyas. **Es un cambio de
     fondo respecto a la letra de la propuesta.**
   - **D-10:** `C-REORG-07` dice hoy «no se publican ambas reglas como simultáneamente activas», y
     con `C-FIN-01` el SPEC publicará las dos. Reescribo esa frase.
   - **D-3:** la propuesta declara que medir el coste de `C-FLU-02` es **«condición para pasar al
     SPEC»**, y esa medición **no existe**. La regla se traslada igual porque D-F6 = A se decidió
     sabiéndolo.

---

## PARADA (encargo §1.3)

**La fase 1 termina aquí y NO se ha tocado `SPEC.md`, `TAREAS.md` ni `ci/`.** La fase 2 empieza
solo con una adenda que apruebe la migración y el plan.

---

## FASE 2 — inicio

**Autorizada por `P-CIERRE/ADENDA-1.md`** (Katana confirma D-3, D-9 y D-10; el resto de las 14 dudas,
conforme). Huella de la adenda al leerla:

```
$ LC_ALL=C sha256sum P-CIERRE/ADENDA-1.md
d909175e1cc9207ab0bd25498e7654618022dcb2c46c3f61e1dc1460d1998fc3  P-CIERRE/ADENDA-1.md

$ date
dom 20 sep 2026 23:45:32 CEST

$ LC_ALL=C sha256sum -c P-CIERRE/ENTRADA.sha256
P-CIERRE/ENCARGO.md: OK
P-CIERRE/PROMPT.md: OK
P-CIERRE/procedencia/PROCEDENCIA-ancla-inyeccion-v2.md: OK
P-CIERRE/procedencia/PROCEDENCIA-pot-primitiva-v1.md: OK
P-CIERRE/procedencia/PROCEDENCIA-puerta-cobertura-v1.md: OK
P-CIERRE/procedencia/PROCEDENCIA-regla-flujo-v1.md: OK

$ git status --short
 M SPEC.md
 M TAREAS.md
 M ci/reglas-sin-cablear.txt
 M ci/reglas-sin-codigo.txt
?? P-2.1/
?? P-CIERRE/
?? P-FLUJO/
?? P-POT/
?? P-PUERTA/
?? P-SEMBRADOR/
?? P-ZRX/
?? problemas/
?? veritas/consenso/ancla-inyeccion-v2/
?? veritas/consenso/poda-post-v1/
?? veritas/consenso/pot-primitiva-v1/
?? veritas/consenso/prueba-recursiva-v1/
?? veritas/consenso/puerta-cobertura-v1/
?? veritas/consenso/regla-flujo-v1/
?? veritas/seguridad/
```

---

## FASE 2 — cierre

```
$ date
dom 20 sep 2026 23:57:37 CEST

$ LC_ALL=C sha256sum -c P-CIERRE/ENTRADA.sha256
P-CIERRE/ENCARGO.md: OK
P-CIERRE/PROMPT.md: OK
P-CIERRE/procedencia/PROCEDENCIA-ancla-inyeccion-v2.md: OK
P-CIERRE/procedencia/PROCEDENCIA-pot-primitiva-v1.md: OK
P-CIERRE/procedencia/PROCEDENCIA-puerta-cobertura-v1.md: OK
P-CIERRE/procedencia/PROCEDENCIA-regla-flujo-v1.md: OK

$ LC_ALL=C sha256sum P-CIERRE/ADENDA-1.md
d909175e1cc9207ab0bd25498e7654618022dcb2c46c3f61e1dc1460d1998fc3  P-CIERRE/ADENDA-1.md

$ git status --short
 M SPEC.md
 M TAREAS.md
 M ci/reglas-sin-cablear.txt
 M ci/reglas-sin-codigo.txt
?? P-2.1/
?? P-CIERRE/
?? P-FLUJO/
?? P-POT/
?? P-PUERTA/
?? P-SEMBRADOR/
?? P-ZRX/
?? problemas/
?? veritas/consenso/ancla-inyeccion-v2/
?? veritas/consenso/poda-post-v1/
?? veritas/consenso/pot-primitiva-v1/
?? veritas/consenso/prueba-recursiva-v1/
?? veritas/consenso/puerta-cobertura-v1/
?? veritas/consenso/regla-flujo-v1/
?? veritas/seguridad/
```

**Entrada íntegra: 6/6 OK. La adenda no cambió durante la fase.**

### Resultado

```
ci/citas-spec.sh            191 -> 222 reglas          exit 0
ci/alcance-consenso.sh      verde                      exit 0
ci/dependencias-exactas.sh  28 dependencias exactas    exit 0
ci/frontera-crates.sh       verde                      exit 0
cargo test --workspace      581 pasan / 0 fallan / 6 ignorados   = línea base
```

56 ediciones aplicadas (55 del plan + E-56 de la adenda), **ninguna omitida**. Diff de la fase 2:
`SPEC.md` +655/−39, `TAREAS.md` +188/−12, `ci/reglas-sin-codigo.txt` +172, `ci/reglas-sin-cablear.txt`
2 comentarios. **Sin commit.**

### Lo que quedó distinto del plan — está entero en `INFORME.md` §5

1. **Un error de cuenta mío:** el plan decía «32 reglas nuevas»; **son 31** (`E-01` es la
   reescritura de §7.1, no una regla). Lo detecté porque `reglas-sin-codigo.txt` daba 66 y no 67.
   Corregido en `SPEC.md`, `TAREAS.md` (4 sitios) y `PLAN-SPEC.md` (13). Los totales reales son
   **222 reglas** y **66 IDs declarados**, no 223 y 67.
2. Las **dos correcciones de la adenda §3** aplicadas, y **E-56** añadida.
3. Dos menores: la doble negación de `C-FLU-11` resuelta con otra redacción, y la fecha de cabecera
   de `TAREAS.md` puesta al día.

**Nada más apareció que el plan no previera.**

### Huellas que fallan a propósito

**Una sola rota por esta fase:** `veritas/consenso/puerta-cobertura-v1/HUELLAS.sha256`, en su línea
de `SPEC.md` — avisada dentro del propio archivo desde la fase 1. Otras **once** ya fallaban antes
y no se tocan; `TAREAS.md` §5 solo registraba cuatro.

---

## FIN DEL ENCARGO

Las dos fases están hechas. El árbol queda modificado y **sin commitear**, para que Katana revise
el diff y decida.
