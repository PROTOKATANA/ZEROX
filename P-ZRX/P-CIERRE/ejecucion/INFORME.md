# INFORME — P-CIERRE fase 2

**2026-09-20.** Aplicado el plan aprobado por `P-CIERRE/ADENDA-1.md`, con sus dos correcciones del
§3 y la entrada de Nivel 5 que pide su §1. **Sin `git commit`, `push`, `stash`, cambio de rama ni
borrados:** el árbol queda modificado para que Katana revise el diff.

---

## 1 · Qué se aplicó

**56 ediciones**: las 55 del plan más **E-56**, pedida por la adenda. Todas aplicadas, ninguna
omitida, en el orden del §10 del plan (`SPEC.md` de abajo arriba → `ci/` → `TAREAS.md`).

| Archivo | Ediciones | Diff de la fase 2 |
|---|---|---|
| `SPEC.md` | E-01…E-46 (46) | **+655 / −39** |
| `ci/reglas-sin-codigo.txt` | E-54 | **+172 / −0** |
| `ci/reglas-sin-cablear.txt` | E-55 | 2 comentarios reescritos, **0 IDs movidos** |
| `TAREAS.md` | E-47…E-53, E-56 (8) | **+188 / −12** |

### `git diff --stat` (incluye los cambios que ya traía el árbol antes del encargo)

```
 SPEC.md                   | 1192 +++++++++++++++++++++++++++++++++++++++++++--
 TAREAS.md                 |  419 ++++++++++++++--
 ci/reglas-sin-cablear.txt |   41 +-
 ci/reglas-sin-codigo.txt  |  178 +++++++
 4 files changed, 1732 insertions(+), 98 deletions(-)
```

> **Ese `--stat` no es el de la fase 2.** `SPEC.md`, `TAREAS.md` y los dos `.txt` ya estaban
> modificados respecto a `HEAD` cuando empezó el encargo. Las cifras de la tabla de arriba son el
> diff **contra el árbol tal como estaba al empezar la fase 2**, que es lo que P-CIERRE ha escrito.

### `git status --short`

```
 M SPEC.md
 M TAREAS.md
 M ci/reglas-sin-cablear.txt
 M ci/reglas-sin-codigo.txt
?? P-2.1/                              ?? veritas/consenso/ancla-inyeccion-v2/
?? P-CIERRE/                           ?? veritas/consenso/poda-post-v1/
?? P-FLUJO/                            ?? veritas/consenso/pot-primitiva-v1/
?? P-POT/                              ?? veritas/consenso/prueba-recursiva-v1/
?? P-PUERTA/                           ?? veritas/consenso/puerta-cobertura-v1/
?? P-SEMBRADOR/                        ?? veritas/consenso/regla-flujo-v1/
?? P-ZRX/                              ?? veritas/seguridad/
?? problemas/
```

Las cuatro líneas nuevas respecto al inicio del encargo son los cuatro destinos migrados. **Ningún
resto en la raíz.**

---

## 2 · Recuento de `ci/citas-spec.sh`, antes y después

```
ANTES     Citas del SPEC: 191 reglas, todas implementadas o declaradas.
          De ellas, 22 con código que todavía no ejecuta nadie. OK

DESPUÉS   Citas del SPEC: 222 reglas, todas implementadas o declaradas.
          De ellas, 22 con código que todavía no ejecuta nadie. OK
```

**+31 reglas.** Por familia:

| Familia | Nuevas | IDs |
|---|---:|---|
| `C-POT` | 8 | `C-POT-01`…`C-POT-08` |
| `C-FLU` | 21 | `C-FLU-01`…`C-FLU-18`, `C-FLU-20`…`C-FLU-22` |
| `C-FIN` | 1 | `C-FIN-01` |
| `C-NET` | 1 | `C-NET-33` (es `C-FLU-23` renumerada, D-F7) |

`ci/reglas-sin-codigo.txt`: **35 → 66 IDs**. `ci/reglas-sin-cablear.txt`: **22 → 22**, sin mover
ningún ID; lo que cambió son los comentarios de `C-HDR-05` y `C-HDR-07`.

**Comprobado en el SPEC:** las 31 están definidas **exactamente una vez** cada una, con su
`**C-XXX-NN**` al principio de línea, y **no hay ninguna referencia a una regla `C-POT`/`C-FLU`/
`C-FIN` que no exista**. `C-FLU-19` no existe y no se referencia.

---

## 3 · Comprobaciones

### Los cuatro guardianes, en verde

```
$ bash ci/citas-spec.sh            Citas del SPEC: 222 reglas, todas implementadas o declaradas.
                                   De ellas, 22 con código que todavía no ejecuta nadie. OK
$ bash ci/alcance-consenso.sh      Alcance: 2 crates vigilados, todo punto de entrada se usa o
                                   está declarado. OK
$ bash ci/dependencias-exactas.sh  OK — 28 dependencias con versión exacta
$ bash ci/frontera-crates.sh       "OK — frontera de red, consenso y mempool"
```

### `cargo test --workspace`, sin regresiones

```
$ cargo test --offline --locked -j 2 --workspace --no-fail-fast --quiet
exit=0
TOTAL: 581 pasan / 0 fallan / 6 ignorados
```

**Exactamente la línea base del encargo (581 / 0 / 6).** No se ha tocado `crates/`, y no se ha
movido.

### Los cuatro destinos migrados

```
ancla-inyeccion-v2     92/92 OK
puerta-cobertura-v1    62/63 OK   ← 1 fallo, DELIBERADO (abajo)
pot-primitiva-v1       14/14 OK
regla-flujo-v1         11/11 OK
```

---

## 4 · Las huellas que fallan a propósito

El encargo lo prevé: «Las `HUELLAS.sha256` de instrumentos antiguos que firman `SPEC.md` o
`TAREAS.md` **fallarán a propósito**: se documenta, no se "arregla"».

**Comprobado cuál rompe P-CIERRE y cuál ya estaba rota**, comparando el hash firmado contra el
`SPEC.md`/`TAREAS.md` del inicio de la fase 2
(`SPEC.md` = `673d8679…c6bc58`, `TAREAS.md` = `42785721…6ed163`):

**Rota por esta fase 2 — una sola:**

| Instrumento | Qué línea |
|---|---|
| `veritas/consenso/puerta-cobertura-v1/HUELLAS.sha256` | `SPEC.md` |

Es la **única**, y está **avisada dentro del propio archivo** desde la fase 1: «ATENCION: la linea
de SPEC.md de abajo FALLARA en cuanto P-CIERRE edite el SPEC, y eso es correcto». Sus 62 líneas
restantes siguen en verde, incluidas las 41 propias.

**Ya fallaban antes de esta fase, y no las toco** (firman un `SPEC.md`/`TAREAS.md` anterior):
`disponibilidad-causal-multivista-v1`, `dominio-autorizacion-v1`, `ghostdag-rank-v1`,
`identidad-disponibilidad-v1`, `poda-post-v1`, `prueba-recursiva-v1`,
`retarget-causal-endogeno-v1`, `ventana-retarget-causal-v1`, `delta-medido-v1`, `coste-salto-v1`
y `coste-rama-privada-v1`. Varias fallan además por ficheros de `crates/` que tampoco he tocado.
`TAREAS.md` §5 ya registraba cuatro de ellas desde el 2026-09-14; **el resto no estaba registrado**,
y ahora la lista corta se queda corta: son **once**, no cuatro.

`ancla-inyeccion-v2`, `pot-primitiva-v1` y `regla-flujo-v1` **no firman `SPEC.md`**, así que siguen
en verde completo.

---

## 5 · Todo lo que quedó distinto del plan

### 5.1 · Un error de cuenta mío, detectado al aplicar y corregido

**El plan decía «32 reglas nuevas». Son 31.** `E-01` es la **reescritura de §7.1**, no una regla, y
al sumar las ediciones `E-01…E-32` conté una de más. El recuento correcto es
`8 (C-POT) + 21 (C-FLU) + 1 (C-FIN) + 1 (C-NET-33) = 31`.

Lo detecté al comprobar que `ci/reglas-sin-codigo.txt` pasaba de 35 a **66**, no a 67. Corregido en
los seis sitios donde el número aparecía:

| Dónde | Antes | Ahora |
|---|---|---|
| `SPEC.md` §17, fila «Prueba de espacio/tiempo» | «las 32 reglas nuevas» | «las 31 reglas nuevas» |
| `TAREAS.md` §2.1 (dos veces) | «32 reglas» | «31 reglas» |
| `TAREAS.md` «Cerrado recientemente» (dos veces) | «32 reglas nuevas», «las 32» | «31», «las 31» |
| `P-CIERRE/ejecucion/PLAN-SPEC.md` | 13 apariciones, incluidos los totales | corregidas |

Y con él, **los totales del plan**: `ci/citas-spec.sh` da **222**, no 223; `reglas-sin-codigo.txt`
queda en **66**, no 67. Las cifras de este informe son las medidas, no las previstas.

### 5.2 · Las dos correcciones que pedía la adenda, aplicadas

1. **`C-FIN-01` (E-31), la nota ⚠️.** Ya no dice que el SPEC «ordena que no se publiquen ambas como
   simultáneamente activas» —esa frase vivía en `C-REORG-07` y E-40 la sustituye—. Dice lo que es
   verdad después de las dos ediciones: *«Dos reglas de profundidad conviven en este documento y
   dicen cosas distintas. La que rige el diseño destino es ésta; `C-REORG-07` es transitoria y
   describe lo que el código hace hoy, no lo que el protocolo manda. La reconciliación sigue
   pendiente y está pedida en §13 y nombrada en `TAREAS.md` §2.9.»*
2. **`TAREAS.md` §2.1 (E-47), el `α_mínimo = 1/2`.** Ya no se afirma sin reserva. La frase entera
   quedó: *«El umbral que CRP-v0.1 midió con un solo flujo es `α_mínimo = 1/2`, el mismo que PoW —
   **pero esa cifra no está cerrada: CRP-v0.2 declara "sustituye la evidencia protocolaria de
   CRP-v0.1" (baseline idealizado útil; veredicto protocolario INCONCLUSO), y ni v0.2 ni v0.3 están
   validadas ni migradas** (§2.9 (e)). Lo que este cierre corrige es el titular del 4 %, y no lo
   sustituye por otro titular ancho.»*

### 5.3 · `E-56`, la entrada de Nivel 5 que pedía la adenda §1

Añadida a `TAREAS.md` Nivel 5: `ANCLA-v0.2` escribe `resultados/` relativo al **directorio de
trabajo**, no al del instrumento, mientras `METODO.md` manda ejecutar desde la raíz. Con el aviso
de que **el control de identidad sí salió idéntico byte a byte** —no invalida ninguna cifra— y de
que lo que el defecto permite es que **una reproducción descuidada compare la copia consigo misma
sin darse cuenta**, que es exactamente lo que me pasó a mí en la fase 1.

### 5.4 · Dos cosas menores que el plan no detallaba

1. **`C-FLU-11`, la doble negación.** El plan (D-6) decía que escribiría `MUST NOT` donde la
   propuesta ponía «ningún campo … **MUST** contener». Al redactarlo, «Ningún campo … **MUST NOT**
   contener» habría sido una doble negación igual de mala. La forma final es
   **«La cabecera y el cuerpo MUST NOT contener el identificador de flujo en ningún campo»**, que
   dice lo mismo sin el giro.
2. **`TAREAS.md`, la fecha de cabecera.** Decía «actualizado el 2026-09-17»; pasa a «2026-09-20».
   No estaba en el plan; dejarla habría hecho que el documento mintiera sobre sí mismo en su
   primera línea.

### 5.5 · Nada más quedó distinto

Ninguna edición se omitió, ninguna se añadió fuera de las declaradas aquí, y **no apareció nada que
el plan no previera** salvo el error de cuenta de §5.1. Las 14 dudas se resolvieron exactamente
como el plan declaraba por defecto y la adenda aprobó.

---

## 6 · Lo que este cierre NO cierra, dicho aquí para que no se pierda

**`TAREAS.md` §2.9 es la lista, con 17 puntos.** Lo que más pesa:

1. **El código: ninguna de las 31 reglas tiene una línea**, y dos de ellas (`C-FLU-02`, `C-FLU-17`)
   ni siquiera tienen dónde engancharse hoy.
2. **`C-HDR-05` y `C-HDR-07` cambiaron de semántica y su código es de la versión anterior.**
   Declarado en `ci/reglas-sin-cablear.txt` con el precedente de C-NET-07; `crates/` sin tocar.
3. **La condición de traslado de `C-FLU-02` sigue sin cumplirse.** La propuesta la escribió como
   condición, no como deseo: medir su coste para el productor honesto con ANCLA-v0.2. Se trasladó
   igual porque D-F6 = A se decidió sabiéndolo.
4. **`CRP-v0.2` declara superada la evidencia de `CRP-v0.1`, y nadie la ha validado.** Está en
   `deepseek/`, zona que `.gitignore` excluye y que se borra al cerrar cada encargo.
5. **La deuda principal sigue donde estaba y ahora sostiene más peso:** (F1) y (F2) son propiedades
   medidas en simulador y un lema, no consecuencias del teorema de GHOSTDAG, y de ellas cuelga toda
   §7.1.3 del SPEC — incluida la buena fundamentación del ancla.
6. **Ninguna cifra medida entró como constante.** Van como símbolo o `<<PENDIENTE>>`: `F_slots`,
   `L_suelo_slots`, `I_slots`, `D`, `N(s)`, `ρ_max`, `PRESUP_PAR`, `PRESUP_NODO`,
   `entropía_externa` y la ventana de persistencia de `C-FLU-17`.

**Y la frase que ningún texto derivado debe romper:** *no se puede decir «las particiones de flujo
se curan» ni «no tienen cura». Depende de cómo nació la partición.* Está escrita en el propio SPEC,
al principio de §7.1.6.
