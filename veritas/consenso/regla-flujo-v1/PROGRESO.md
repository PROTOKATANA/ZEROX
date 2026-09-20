# PROGRESO — P-FLUJO

> **Nota de migración (Claude, 2026-09-20, `P-CIERRE`).** Bitácora del ejecutor, migrada desde
> `P-FLUJO/propuesta/` al validar y trasladar el trabajo a `veritas/consenso/regla-flujo-v1/`. **Las rutas
> `P-FLUJO/propuesta/` que aparecen más abajo son históricas** y no se han reescrito: son el
> testimonio de dónde se escribió. El estado vigente está en `PROCEDENCIA.md` y en `LEEME.md`.
> El original queda intacto en su sitio.

Bitácora del encargo `P-FLUJO/ENCARGO.md`. Zona de escritura: `P-FLUJO/propuesta/` y nada más.

## Comprobación de entrada (obligatoria, §8.2 del encargo)

`date`:

```
sáb 19 sep 2026 08:15:19 CEST
```

`LC_ALL=C sha256sum -c P-FLUJO/ENTRADA.sha256` desde `/home/katana/zeo/ZEROX`:

```
P-FLUJO/ENCARGO.md: OK
P-FLUJO/PROMPT.md: OK
```

`git -C /home/katana/zeo/ZEROX status --short`:

```
 M SPEC.md
 M TAREAS.md
 M ci/reglas-sin-cablear.txt
 M ci/reglas-sin-codigo.txt
?? P-2.1/
?? P-FLUJO/
?? P-POT/
?? P-PUERTA/
?? problemas/
?? veritas/consenso/poda-post-v1/
?? veritas/consenso/prueba-recursiva-v1/
?? veritas/seguridad/
```

## Lecturas hechas antes de redactar (§3 del encargo)

Todas abiertas; ninguna cita de este trabajo procede de memoria.

1. `/home/katana/zeo/ZEROX/P-2.1/SINTESIS.md` — entero (80 líneas).
2. `/home/katana/zeo/ZEROX/P-POT/propuesta/PROPUESTA-SPEC.md` — entero (359 líneas).
   `/home/katana/zeo/ZEROX/P-POT/propuesta/DECISIONES-PENDIENTES.md` — l. 1-60 (estilo).
   `/home/katana/zeo/ZEROX/veritas/consenso/ghostdag-rank-v1/PROPUESTA-SPEC.md` — l. 1-70 (forma).
3. `/home/katana/zeo/ZEROX/research/dag-poas-ancla-de-orden.md` — l. 1-60, 150-320, 370-400, 425-450.
4. `/home/katana/zeo/ZEROX/research/dag-poas-inyeccion-auditoria.md` — l. 70-125, 210-225, 470-485.
5. `/home/katana/zeo/ZEROX/research/scripts/d9-ronda11c/informe.md` — l. 30-70.
6. `/home/katana/zeo/ZEROX/SPEC.md` — l. 556-590, 820-940, 1270-1300, 1427-1475, 1655-1700,
   1885-1910, 1987-2014, 2044-2060, 2181-2215, 2971-3012.
7. `/home/katana/zeo/ZEROX/TAREAS.md` — l. 124-185, 648-660.
8. `/home/katana/zeo/ZEROX/research/README.md` — l. 1-15 (estatuto de evidencia histórica).
9. `/home/katana/zeo/ZEROX/crates/zx-core/src/wire_dag.rs` — l. 350-370 (el trait de contexto).
   `/home/katana/zeo/ZEROX/crates/zx-node/src/cadena.rs` — l. 313-330 (semántica de reorg profunda).

Comprobado además que la familia `C-FLU-NN` **no existe** en el repositorio
(`grep -rn "C-FLU" --include=*.md --include=*.rs --include=*.txt .` solo encuentra el propio
encargo y su PROMPT). Los IDs `C-FLU-01…C-FLU-16` son nuevos (`TAREAS.md:653-654`).

## Lo que se hizo, en orden

1. Lectura completa de §3 antes de escribir una sola línea de propuesta.
2. **Ataque a la afirmación central del §2 antes de redactar nada más.** Resultado: (a) refutada
   con contraejemplo, (c) demostrada y con margen de un slot, (b) sobrevive pero por DF-2.
   El enunciado corregido está en §0 de `PROPUESTA-SPEC.md` y se comunicó a Katana antes de
   redactar, como exige el cierre del encargo.
3. Redacción de `PROPUESTA-SPEC.md` (16 reglas `C-FLU-NN`) y `DECISIONES-PENDIENTES.md` (6).
4. Comprobación de salida.

## Nada de cómputo

No se ejecutó Julia ni ningún otro instrumento: el encargo es de redacción y demostración corta,
y ninguna de las demostraciones de §10 pide comprobación numérica. Cero Python, por §8.3.

## Comprobación de salida

`date`:

```
sáb 19 sep 2026 08:35:04 CEST
```

`LC_ALL=C sha256sum -c P-FLUJO/ENTRADA.sha256` desde `/home/katana/zeo/ZEROX`:

```
P-FLUJO/ENCARGO.md: OK
P-FLUJO/PROMPT.md: OK
```

`git -C /home/katana/zeo/ZEROX status --short`:

```
 M SPEC.md
 M TAREAS.md
 M ci/reglas-sin-cablear.txt
 M ci/reglas-sin-codigo.txt
?? P-2.1/
?? P-FLUJO/
?? P-POT/
?? P-PUERTA/
?? problemas/
?? veritas/consenso/poda-post-v1/
?? veritas/consenso/prueba-recursiva-v1/
?? veritas/seguridad/
```

**Idéntico a la entrada.** `P-FLUJO/` ya salía como `?? P-FLUJO/` al empezar (el directorio no
está en git), así que los tres archivos nuevos de `P-FLUJO/propuesta/` no cambian la salida. Nada
fuera de la zona se ha tocado: ni `SPEC.md`, ni `TAREAS.md`, ni `ci/`, ni `crates/`, ni `research/`,
ni `P-2.1/`, ni `P-POT/`, ni `P-PUERTA/`. Los cuatro `M` y los ocho `??` son los mismos de las
08:15:19.

## Entregables

```
P-FLUJO/propuesta/PROPUESTA-SPEC.md         71 462 B   16 reglas C-FLU-01…16
P-FLUJO/propuesta/DECISIONES-PENDIENTES.md 18 035 B   6 decisiones D-F1…D-F6
P-FLUJO/propuesta/PROGRESO.md              este archivo
```

## Lo que hay que leer primero, si solo se lee una cosa

**§0 de `PROPUESTA-SPEC.md`.** La afirmación central del encargo §2 está **refutada en su parte
(a)**: una partición de flujo **sí** puede nacer sin que nadie viole la finalidad, y eso es
exactamente lo que `P-2.1` midió al calibrar `L`. La parte (c) queda **demostrada** y con un slot de
margen, lo que cierra el borde `L = F` sin pedir margen extra. La parte (b) sobrevive, pero por DF-2,
no por el argumento de finalidad. El perfil 1a no cambia; **cambia el motivo por el que es seguro**,
y cualquier texto que se traslade al SPEC citando (a) estaría citando un argumento que no se
sostiene.

**Y después, D-F3 de `DECISIONES-PENDIENTES.md`:** la elección entre R-FIN-7 y `C-REORG-07` decide
si la ventana de adopción es vacía o mide ≈1,33 h. Es la decisión de mayor consecuencia de todo el
encargo y el SPEC dice explícitamente que las dos reglas no están reconciliadas.

---

# Revisión 2 — ADENDA 1 (2026-09-20)

## Adenda registrada (§3 de `ADENDA-1.md`)

`/home/katana/zeo/ZEROX/P-FLUJO/ADENDA-1.md`, leída entera antes de tocar nada. **Prevalece sobre el
`ENCARGO.md` en lo que dice** (`ADENDA-1.md:4`). Huella comprobada.

## Comprobación de entrada

`date`:

```
dom 20 sep 2026 13:17:38 CEST
```

`LC_ALL=C sha256sum -c P-FLUJO/ENTRADA.sha256` y `… P-FLUJO/ADENDAS.sha256` desde
`/home/katana/zeo/ZEROX`:

```
P-FLUJO/ENCARGO.md: OK
P-FLUJO/PROMPT.md: OK
P-FLUJO/ADENDA-1.md: OK
```

`git -C /home/katana/zeo/ZEROX status --short`:

```
 M SPEC.md
 M TAREAS.md
 M ci/reglas-sin-cablear.txt
 M ci/reglas-sin-codigo.txt
?? P-2.1/
?? P-FLUJO/
?? P-POT/
?? P-PUERTA/
?? P-SEMBRADOR/
?? problemas/
?? veritas/consenso/poda-post-v1/
?? veritas/consenso/prueba-recursiva-v1/
?? veritas/seguridad/
```

**Diferencia con la entrada del 2026-09-19:** aparece `?? P-SEMBRADOR/`, que no existía. **No es
obra mía**: es la investigación del sembrador que la adenda cita (`ADENDA-1.md:44-47`). No he
escrito nada en ella; solo he leído `P-SEMBRADOR/investigacion/INFORME.md`.

## Lecturas nuevas de esta revisión (todas abiertas antes de citarlas)

1. `/home/katana/zeo/ZEROX/P-FLUJO/ADENDA-1.md` — entera.
2. `/home/katana/zeo/ZEROX/research/dag-poas-balizas-auditoria.md` — l. 60-80. **La cita de la
   revisión 1 era a un archivo inexistente** (`research/balizas-auditoria.md`); corregida, y el
   teorema resulta decir más de lo que la abreviatura sugería (§8 de la propuesta).
3. `/home/katana/zeo/ZEROX/PDF/autonomys-subspace/crates/subspace-core-primitives/src/pot.rs`
   — l. 168-200: `PotSeed::from_genesis`. Y
   `…/subspace-core-primitives/src/hashes.rs` — l. 141-157: `blake3_hash_list` es el hash de la
   concatenación, así que la transcripción de C-FLU-06 es fiel. **Deja de ser cita de segunda mano.**
4. `/home/katana/zeo/ZEROX/SPEC.md` — l. 1721-1733 (**C-GD-10**, para la consecuencia (i) de D-F6).
5. `/home/katana/zeo/ZEROX/crates/zx-core/src/wire_dag.rs` — l. 280-301, y
   `/home/katana/zeo/ZEROX/crates/zx-consensus/src/bloque_dag.rs` — l. 138-170 (qué toca D-F6 en el
   código; el trait `ContextoDag` **no tiene accesor de `slot`**).
6. `/home/katana/zeo/ZEROX/P-SEMBRADOR/investigacion/INFORME.md` — l. 1-40. **Solo esa parte**: las
   líneas 9, 11, 13 y 27 son las que cito. **No he leído el informe entero**, y así queda declarado
   en «Lo que esta propuesta NO resuelve», punto 11.

## Qué cambió, en orden

1. Cabecera de `PROPUESTA-SPEC.md`: bloque «Revisión 2 — ADENDA 1 incorporada».
2. §0: refutación **aceptada por el validador**; §0.4 y C-FLU-15 dicen **sin suavizar** que una
   partición no tiene cura en el protocolo — **prevención, no recuperación**.
3. **Decididas, sin condicionalidad:** suelo de `L` (C-FLU-01), D-F1 = A (C-FLU-12), D-F6 = A
   (C-FLU-02, con (i) C-GD-10, (ii) coste `estimado` a confirmar con ANCLA-v0.2, (iii) tabla de lo
   que toca).
4. **Provisionales marcadas en el texto de cada regla:** D-F2 → A (C-FLU-06, C-FLU-10), D-F3 → C
   (§0.2, §10.3), D-F4 → A (§10.2), D-F5 → no legislar + **C-FLU-17 nueva**.
5. Dos declaraciones nuevas en «Lo que NO resuelve»: el coste de 1a frente al sembrador (punto 5) y
   la aritmética del adelanto sin rehacer tras D-2 = A (punto 9).
6. Dos citas arregladas; el punto 11 pasa de «dos citas de segunda mano» a «resueltas», con la única
   excepción declarada del informe del sembrador leído en parte.
7. `DECISIONES-PENDIENTES.md` reestructurada: **Parte I decididas**, **Parte II provisionales**,
   **Parte III abierto que no es decisión**. Cada provisional dice **qué habría que reescribir** si
   Katana elige la otra opción.

## Nada de cómputo, otra vez

Sin Julia y sin Python. La única medición que esta revisión pide —el coste de C-FLU-02 con
ANCLA-v0.2— **no se ha ejecutado**: queda declarada como condición para pasar al SPEC, no hecha.

## Comprobación de salida

`date`:

```
dom 20 sep 2026 13:25:30 CEST
```

`LC_ALL=C sha256sum -c` de las dos huellas:

```
P-FLUJO/ENCARGO.md: OK
P-FLUJO/PROMPT.md: OK
P-FLUJO/ADENDA-1.md: OK
P-FLUJO/ADENDA-2.md: OK
```

`git -C /home/katana/zeo/ZEROX status --short`: **idéntico a la entrada de esta revisión** (los
cuatro `M` y los nueve `??`). Solo se han modificado los tres archivos de
`P-FLUJO/propuesta/`. Nada fuera de la zona.

> **En esta comprobación apareció `P-FLUJO/ADENDA-2.md`** (mtime 13:21, es decir **durante** la
> revisión 2), ya incluida en `P-FLUJO/ADENDAS.sha256`. No estaba cuando empecé. La revisión 2 quedó
> escrita tal como está; lo que la ADENDA 2 cambia va en la **revisión 3**, abajo.

---

# Revisión 3 — ADENDA 2 (2026-09-20)

## Adenda registrada

`/home/katana/zeo/ZEROX/P-FLUJO/ADENDA-2.md`, leída entera. **Prevalece sobre el §2 de la ADENDA 1**
(`ADENDA-2.md:4-5`): lo que allí era provisional pasa a decidido y la marca se retira.

**Cómo apareció, porque importa para la trazabilidad:** `ADENDA-2.md` tiene mtime **13:21**, es
decir que se escribió **mientras yo redactaba la revisión 2** (empezada a las 13:17). No estaba en
`P-FLUJO/` cuando hice la comprobación de entrada de esa revisión, y la detecté en la comprobación
de **salida**, al ver que `ADENDAS.sha256` tenía dos líneas en vez de una. La revisión 2 quedó
escrita tal cual; esta revisión 3 aplica la ADENDA 2 encima.

## Comprobación de entrada

`date`:

```
dom 20 sep 2026 13:32:11 CEST
```

`LC_ALL=C sha256sum -c P-FLUJO/ENTRADA.sha256` y `… P-FLUJO/ADENDAS.sha256`:

```
P-FLUJO/ENCARGO.md: OK
P-FLUJO/PROMPT.md: OK
P-FLUJO/ADENDA-1.md: OK
P-FLUJO/ADENDA-2.md: OK
```

`git -C /home/katana/zeo/ZEROX status --short`:

```
 M SPEC.md
 M TAREAS.md
 M ci/reglas-sin-cablear.txt
 M ci/reglas-sin-codigo.txt
?? P-2.1/
?? P-FLUJO/
?? P-POT/
?? P-PUERTA/
?? P-SEMBRADOR/
?? problemas/
?? veritas/consenso/poda-post-v1/
?? veritas/consenso/prueba-recursiva-v1/
?? veritas/seguridad/
```

## Lecturas nuevas de esta revisión

1. `/home/katana/zeo/ZEROX/P-FLUJO/ADENDA-2.md` — entera.
2. No hizo falta ninguna fuente nueva: las citas que la ADENDA 2 pide ya estaban abiertas en la
   revisión 2 (`SPEC.md:1891-1899`, `:2050-2054`, `:560-584`, `:1987-2014`, `:2000-2002`,
   `crates/zx-node/src/cadena.rs:318-320`, `research/dag-poas-balizas-auditoria.md`) o en la
   revisión 1 (`SPEC.md:1894`, `P-POT/propuesta/PROPUESTA-SPEC.md:98-103`,
   `research/dag-poas-ancla-de-orden.md:261-264, 272-275`). **Ninguna cita nueva sin abrir.**

## Qué cambió

1. **Se retiró la marca PROVISIONAL de todas las reglas.** Comprobado: no queda ninguna
   (`grep -n "PROVISIONAL" PROPUESTA-SPEC.md` solo devuelve el texto que explica que ya no las hay).
2. **D-F2 = A:** `H_flujo = H_d = SHA3-256(etiqueta ‖ m)` con dos etiquetas nuevas propuestas
   (`ZZKFlowId_______`, `ZZKFlowGenesis__`) y la declaración de que **hay que ampliar C-HASH-06**.
   Añadida la línea que pide la adenda sobre por qué aquí no aplica el argumento del oráculo, y el
   aviso de que `semilla(f_0,0)` **sigue en blake3 a propósito**.
3. **D-F3 = C, acotada:** **C-FIN-01** nueva, en el §10.4 nuevo. Solo el enunciado. La
   reconciliación (código que se detiene, `COINBASE_MATURITY`, techo de archivado) queda declarada
   como pendiente, y `C-REORG-07` **no se toca**.
4. **D-F4 = A:** las **dos** desigualdades escritas explícitas —(α) reorg prohibida con
   `d ≥ F_slots`, (β) inyección en vigor con `s ≥ t_j`, borde inclusivo—. La demostración del borde
   se conserva intacta.
5. **D-F5 mejorada:** **C-FLU-18** nueva (el nodo sin cadena previa aplica selección ordinaria; la
   finalidad solo obliga a quien tiene cadena), con su alcance —minoría aislada, secuencialidad del
   PoT, C-CHK citados y no ampliados— y con lo que **no** acota. C-FLU-17 se mantiene.
6. **«Lo que NO resuelve»** pasa de 13 a 15 puntos: entra el granjero que produce en flujo no
   seleccionado (declarado, no legislado) y la reconciliación de la finalidad que queda fuera por
   alcance.
7. **`DECISIONES-PENDIENTES.md`:** todo decidido salvo **D-F7**, bifurcación **nueva** que abro y no
   resuelvo (en qué familia de IDs vive una regla de finalidad, que no es de flujo).

**Reglas nuevas en total desde la primera entrega:** C-FLU-17 (rev. 2), **C-FLU-18** y **C-FIN-01**
(rev. 3). De 16 a 19.

## Nada de cómputo

Sin Julia y sin Python, otra vez. La medición que C-FLU-02 exige (ANCLA-v0.2) **sigue sin
ejecutarse**: es condición declarada para pasar al SPEC, no trabajo hecho.

## Comprobación de salida

`date`:

```
dom 20 sep 2026 13:32:24 CEST
```

`LC_ALL=C sha256sum -c` de las dos huellas:

```
P-FLUJO/ENCARGO.md: OK
P-FLUJO/PROMPT.md: OK
P-FLUJO/ADENDA-1.md: OK
P-FLUJO/ADENDA-2.md: OK
```

`git -C /home/katana/zeo/ZEROX status --short`:

```
 M SPEC.md
 M TAREAS.md
 M ci/reglas-sin-cablear.txt
 M ci/reglas-sin-codigo.txt
?? P-2.1/
?? P-FLUJO/
?? P-POT/
?? P-PUERTA/
?? P-SEMBRADOR/
?? problemas/
?? veritas/consenso/poda-post-v1/
?? veritas/consenso/prueba-recursiva-v1/
?? veritas/seguridad/
```

**Idéntico a la entrada de esta revisión.** Solo se han modificado los tres archivos de
`P-FLUJO/propuesta/`. Nada fuera de la zona: ni `SPEC.md`, ni `TAREAS.md`, ni `ci/`, ni `crates/`,
ni `research/`, ni `P-2.1/`, ni `P-POT/`, ni `P-PUERTA/`, ni `P-SEMBRADOR/`.

## Entregables al cierre de la revisión 3

| Archivo | Contenido |
|---|---|
| `P-FLUJO/propuesta/PROPUESTA-SPEC.md` | **19 reglas** `C-FLU-01…19` |
| `P-FLUJO/propuesta/DECISIONES-PENDIENTES.md` | D-F1…D-F6 **decididas**, **D-F7 abierta** |
| `P-FLUJO/propuesta/PROGRESO.md` | este archivo, con las tres revisiones |

## Lo que hay que leer primero, si solo se lee una cosa

**§0 de `PROPUESTA-SPEC.md`**, que no ha cambiado de fondo en tres revisiones: la afirmación central
del encargo está refutada en su parte (a), el validador lo aceptó, y el perfil 1a se sostiene por
(P1) ancla final antes de usarse, (P2) la partición rara vez nace —medido en simulación— y (P3) si
nace es permanente. **Lo que la ADENDA 1 añadió es que Katana lo reconfirma sabiéndolo:** prevención,
no recuperación.

**Y lo que queda sobre la mesa es una sola cosa: D-F7**, en qué familia de IDs entra C-FIN-01, que es
una regla de finalidad y no de flujo. Recomiendo familia propia (`C-FIN-NN`); el ID de hoy es cómodo
y probablemente equivocado, y renombrarlo después gasta un ID estable.

---

# Revisión 4 — objeción del validador a la Prop. A (2026-09-20)

## Comprobación de entrada

`date`: `dom 20 sep 2026 13:34:11 CEST` (comprobado al empezar la verificación de la objeción).
Huellas: `ENCARGO.md: OK`, `PROMPT.md: OK`, `ADENDA-1.md: OK`, `ADENDA-2.md: OK`.
`git status --short`: los cuatro `M` y los nueve `??` de siempre.

## Lecturas nuevas

1. Mi propio §0.2, §0.4, C-FLU-03 y C-FLU-04, releídos enteros antes de responder.
2. `/home/katana/zeo/ZEROX/TAREAS.md` l. 129-141 — CRP-v0.1, `α_mínimo = 1/2` para la rama privada.
3. `/home/katana/zeo/ZEROX/research/dag-poas-ancla-de-orden-auditoria-9a.md` l. 18-21, 50-52 — la
   regla (h.3) que hacía el flujo dependiente del orden de llegada y su sustitución por (h.3′).
4. `/home/katana/zeo/ZEROX/veritas/consenso/ghostdag-rank-v1/PROPUESTA-SPEC.md` l. 68-70 —
   `blue_work` es intrínseco al bloque, no depende del observador. **Es la línea que decide la
   objeción.**

## Veredicto: la objeción es CORRECTA, y alcanza más lejos

**Mi error.** El Lema 1 habla de `Chn(V_j)`, la cadena del virtual sobre la vista truncada de
C-FLU-04. Lo apliqué a **las cadenas seleccionadas de los nodos**. Son objetos distintos: `V_j(B)`
crece cuando `B` **fusiona** un bloque retenido, y fusionar no es reorganizar. Bajo la R-FIN-1
literal los dos objetos coinciden — pero esa definición es justo la que E1 refuta por circular y la
que C-FLU-04 repara **cambiando de objeto**. Reparé la circularidad y no propagué el cambio.

**Lo que el validador no dijo y yo encontré al verificar:** el mismo error rompe la **conclusión (c)
de §0.2**. Dos flujos comparten todo el DAG con `slot < t_j`, así que cruzar cuesta `≈ t − t_j`, no
`t − T_j`: **la ventana de adopción mide ≈ `F_slots`, no cero.** Es lo que
`P-2.1/SINTESIS.md:30-31` ya decía —y que yo cité en §0.4 mientras afirmaba lo contrario en §0.2—.
**El análisis de PCO-v0.1 que `SINTESIS.md:74-76` declaró «superado» por mi razonamiento no estaba
superado.**

## Qué cambió

1. **§0.2:** (c) **retirada**. Corrección en cabecera de sección, con el error nombrado. Nuevo
   **(c′)** demostrado: dos bloques con anclas distintas no comparten ningún ancestro de
   `slot ≥ t_j`, luego la profundidad de cruzar es `> t − t_j` y la ventana es `[t_j, t_j+F_slots)`.
2. **§0.4:** Prop. A **retirada**, partida en **A1** (demostrado; mecanismo **C-FLU-14**, no
   finalidad) y **A2** (**probabilístico y NO medido**; carrera de `blue_work` de longitud `L`).
   Retirada la frase «cierra **sin estadística** el vector 2». Sub-hallazgo: **el k-cluster no
   protege `Chn(V_j)`**, porque `blue_work` es intrínseco y el color no entra en la elección del
   virtual — lo que corrige de paso lo que yo suponía en C-FLU-08.
3. **(P1)(P2)(P3) reescritos** como (P1′), (P2a), **(P2b) nuevo y no medido**, (P3′) más débil.
4. **§0.5:** (b) queda condicionada a D-F9.
5. **§10.2:** el borde `L = F` **re-acotado** al mecanismo de nacimiento por latencia.
6. **C-FLU-04:** aviso explícito de que `Chn(V_j)` no es la cadena del nodo, con las dos
   consecuencias.
7. **Reglas nuevas: C-FLU-20** (regla del productor; y que el bloque tardío queda **infusionable
   para siempre**, con el aviso de no extender la política antes de `t_j` para no repetir (h.3)) y
   **C-FLU-21** (la inyección activada se hereda, no se recalcula).
8. **Decisiones nuevas: D-F8** (congelar la vista; reabre E1 en una franja de `S_max`) y **D-F9**
   (**DF-2 se decidió sobre la premisa falsa**; recomiendo la opción C, adopción con presupuesto,
   cambiando lo que yo mismo recomendé).
9. **«Lo que NO resuelve»** pasa de 15 a 18 puntos.

**Lo que NO cambió: (a) sigue refutada.** No dependía de este error.

## Nada de cómputo

Sin Julia y sin Python. **La carrera A2 no se ha medido**: queda declarada como hueco nuevo, con
ANCLA-v0.2 propuesto como instrumento.

## Comprobación de salida

`date`:

```
dom 20 sep 2026 14:17:55 CEST
```

`LC_ALL=C sha256sum -c` de las dos huellas:

```
P-FLUJO/ENCARGO.md: OK
P-FLUJO/PROMPT.md: OK
P-FLUJO/ADENDA-1.md: OK
P-FLUJO/ADENDA-2.md: OK
```

`git -C /home/katana/zeo/ZEROX status --short`:

```
 M SPEC.md
 M TAREAS.md
 M ci/reglas-sin-cablear.txt
 M ci/reglas-sin-codigo.txt
?? P-2.1/
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

**Una diferencia con la entrada, y no es mía:** aparece `?? P-ZRX/`, que no existía a las 13:34.
No he escrito nada fuera de `P-FLUJO/propuesta/`; los cuatro `M` y el resto de los `??` son los
mismos. Lo registro porque la regla de trabajo es que el resto quede idéntico, y no lo está: hay un
directorio nuevo de otro encargo.

## Entregables al cierre de la revisión 4

| Archivo | Contenido |
|---|---|
| `P-FLUJO/propuesta/PROPUESTA-SPEC.md` | **21 reglas** `C-FLU-01…21` |
| `P-FLUJO/propuesta/DECISIONES-PENDIENTES.md` | D-F1…D-F6 decididas; **D-F7, D-F8 y D-F9 abiertas** |
| `P-FLUJO/propuesta/PROGRESO.md` | este archivo, con las cuatro revisiones |

## Lo que hay que leer primero, si solo se lee una cosa

**La corrección de §0.2 y §0.4.** Dos resultados míos de las revisiones 1-3 eran **falsos**: la
Prop. A y la conclusión (c). Los dos por el mismo cambio de objeto. **Ni «la ventana de adopción es
vacía» ni «el vector 2 queda cerrado sin estadística» son afirmaciones de este documento.**

**Y después D-F9**, porque **DF-2 se decidió sobre la conclusión falsa**. Recomiendo revisarla, y
recomiendo la opción C —adopción dentro de la ventana, con presupuesto—, que es lo contrario de lo
que yo mismo recomendé el 2026-09-19, por la sencilla razón de que mi motivo entonces era un
teorema que no se sostiene.

---

# Revisión 5 — ADENDA 3 (2026-09-20)

## Adenda registrada

`/home/katana/zeo/ZEROX/P-FLUJO/ADENDA-3.md`, leída entera. La respuesta a la objeción queda
**aceptada entera, incluida la retirada de la conclusión (c)** (`ADENDA-3.md:4-5`).

## Comprobación de entrada

`date`: `dom 20 sep 2026 14:31:59 CEST`.
Huellas: `ENCARGO.md: OK`, `PROMPT.md: OK`, `ADENDA-1.md: OK`, `ADENDA-2.md: OK`, `ADENDA-3.md: OK`.
`git status --short`: los cuatro `M` y **diez** `??`, incluido `?? P-ZRX/`, **que es de Katana y no
se toca** (`ADENDA-3.md:48`).

## Lecturas nuevas

Ninguna fuente nueva. Todo lo que la ADENDA 3 pide citar ya estaba abierto en revisiones anteriores:
`SPEC.md:3005-3009` (presupuesto), `:2530-2531` (coste acotado por construcción), `:2987-2988`
(92 ms/slot), `P-2.1/SINTESIS.md:29-36` (las dos rendijas de PCO-v0.1), `TAREAS.md:129-134`
(CRP-v0.1), `research/dag-poas-balizas-auditoria.md:68-75` (identidades gratis),
`research/dag-poas-inyeccion-auditoria.md:83, 110, 116` y
`research/dag-poas-ancla-de-orden-auditoria-9a.md:18-21, 50-52`.

## Qué cambió

1. **D-F7 = B — renombrado.** `C-FLU-19` → **`C-FIN-01`** en los tres entregables: 16 apariciones en
   `PROPUESTA-SPEC.md`, 7 en `DECISIONES-PENDIENTES.md`, 3 en `PROGRESO.md`. Comprobado que no queda
   ninguna `C-FLU-19`. Familia **`C-FIN`** declarada en el índice de §11 con su régimen de IDs.
2. **D-F8 = C — no se congela la vista.** `C-FLU-03` sin tocar; **C-FLU-21 pasa a regla firme**, con
   el motivo escrito dentro de la regla: congelar reabre **E1** en una franja de `≤ S_max_slots`,
   porque el bloque puerta necesitaría el flujo de bloques con `slot ≥ t_j`.
3. **D-F9 = C — regla de adopción nueva: C-FLU-22**, con los siete puntos de la adenda.
   Lo que salió al redactarla y no estaba previsto:
   - **la anchura de la ventana depende de cómo nació la partición** (demostrado):
     `[t_j, slot(P) + F_slots)`, máxima en el nacimiento espontáneo y **vacía** en un corte de red
     más largo que `L`. Eso une el punto 1 con el punto 6.
   - **el DoS queda DEMOSTRADO**: la vía (b) —omitir el ancla honesta— es **imposible dentro de la
     ventana**, y la prueba **usa `L ≥ F`**. Es un **argumento nuevo a favor del perfil 1a**.
4. **Correcciones en cadena, que la adenda no pedía y hacían falta:** C-FLU-15 y el «reverso» de
   §0.4 decían «una partición no tiene cura en el protocolo» — ya no es exacto; **(b) de §0.5 queda
   retirada a la letra** y sustituida por la versión exacta de C-FLU-22 §4; **(P3′) → (P3″)**.
5. **Repasado que ningún pasaje afirme la ventana vacía.** Las diez apariciones de «vací» que
   quedan son: la corrección que lo dice, el texto retirado marcado como tal, la ventana vacía **del
   corte de red** (que sí lo es), la tabla de §10.3 y dos usos ajenos («lista vacía canónica»).
6. **D-F10 abierta, no resuelta:** el presupuesto de C-NET-32.3 es **por par** y las identidades son
   gratis. **No abarata el disparo** —sigue haciendo falta ganar A2— pero multiplica el techo.
7. **«Lo que NO resuelve»** pasa de 18 a 21 puntos: la vía A2 sin medir con ANCLA-v0.2 como
   instrumento (punto 15), las dos rendijas de PCO-v0.1, el presupuesto por par y el peor caso de
   ≈11 min de CPU.

## Nada de cómputo

Sin Julia y sin Python. **La vía A2 sigue sin medir**; ANCLA-v0.2 queda propuesto como instrumento.

## Comprobación de salida

`date`:

```
dom 20 sep 2026 14:38:55 CEST
```

`LC_ALL=C sha256sum -c` de las dos huellas:

```
P-FLUJO/ENCARGO.md: OK
P-FLUJO/PROMPT.md: OK
P-FLUJO/ADENDA-1.md: OK
P-FLUJO/ADENDA-2.md: OK
P-FLUJO/ADENDA-3.md: OK
```

`git -C /home/katana/zeo/ZEROX status --short`:

```
 M SPEC.md
 M TAREAS.md
 M ci/reglas-sin-cablear.txt
 M ci/reglas-sin-codigo.txt
?? P-2.1/
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

**Idéntico a la entrada de esta revisión.** Solo se han modificado los tres archivos de
`P-FLUJO/propuesta/`. `?? P-ZRX/` es de Katana y no se ha tocado.

## Entregables al cierre de la revisión 5

| Archivo | Contenido |
|---|---|
| `P-FLUJO/propuesta/PROPUESTA-SPEC.md` | **22 reglas: `C-FLU-01…18`, `C-FLU-20…22` y `C-FIN-01`** |
| `P-FLUJO/propuesta/DECISIONES-PENDIENTES.md` | **D-F1…D-F9 decididas; D-F10 abierta** |
| `P-FLUJO/propuesta/PROGRESO.md` | este archivo, con las cinco revisiones |

## Lo que hay que leer primero, si solo se lee una cosa

**C-FLU-22 §1 y §6.** La ventana de adopción existe y su anchura **depende de cómo nació la
partición**: máxima en el nacimiento espontáneo, **vacía** en un corte de red más largo que `L`.
**La regla cura el caso improbable y no cura el grave**, y ningún texto derivado debe decir «las
particiones se curan» ni «no tienen cura».

**Y C-FLU-22 §5**, porque ahí hay un resultado nuevo que nadie pidió: la vía barata de forzar
verificación de PoT ajeno **no existe**, y la demostración de que no existe **usa `L ≥ F`**. Es un
argumento a favor del perfil 1a independiente de todos los de `P-2.1`.

---

# Revisión 6 — D-F10 decidida (2026-09-20)

## Comprobación de entrada

`date`: `dom 20 sep 2026 14:56:30 CEST`.
Huellas: `ENCARGO.md: OK`, `PROMPT.md: OK`, `ADENDA-1.md: OK`, `ADENDA-2.md: OK`, `ADENDA-3.md: OK`.
**No hay ADENDA-4:** la decisión llegó por mensaje, no por adenda, y así queda registrada.

`git status --short`: los cuatro `M` de siempre y **once** `??`. **Dos directorios nuevos que no son
míos** y que no he tocado: `?? P-ZRX/` (ya declarado de Katana en `ADENDA-3.md:48`) y
**`?? P-CIERRE/`**, que aparece por primera vez en esta comprobación.

## Lecturas nuevas

Ninguna. Todo lo que C-FLU-23 cita estaba ya abierto: `SPEC.md:3005-3009` (el presupuesto por par y
su `<<PENDIENTE>>`), `:2530-2531` (coste acotado por construcción, criterio de C-NET-06),
`:2987-2988` (92 ms/slot), `research/dag-poas-balizas-auditoria.md:68-75` (identidades gratis) y
`P-2.1/SINTESIS.md:31-36` (las dos rendijas de PCO-v0.1).

## Qué cambió

1. **Regla nueva: `C-FLU-23`.** Dos cotas —`PRESUP_PAR` (C-NET-32.3, ya existente) y `PRESUP_NODO`
   (nueva, **símbolo**)—, y las **cuatro obligaciones** del estado `Pendiente`: conservar la cadena
   seleccionada, no declarar inválido, **seguir reenviando** y reintentar mientras la ventana siga
   abierta. Agotar **cualquiera** de las dos da `Pendiente`, nunca `Inválido`.
2. **El modo de fallo, escrito y razonado.** Bajo C-FLU-22 «no adoptar» **ya no es neutro**: quedarse
   sin presupuesto durante la ventana es quedarse en el flujo actual, y al cerrarse la ventana
   (`slot(P) + F_slots`), para siempre. De ahí la obligación de seguir reenviando: un nodo sin
   presupuesto no debe convertirse además en amplificador de la partición.
3. **§7, paso 1b:** su presupuesto pasa de una cota a dos, con remisión a C-FLU-23.
4. **C-FLU-22 §3 y §7:** el punto de presupuesto remite a la regla nueva; el antiguo §7 de la regla
   pasa a §8 (renumerado dentro de C-FLU-22).
5. **Dos hallazgos al redactarla, ninguno pedido en la decisión:**
   - **La calibración es una pinza.** Si `PRESUP_NODO` es demasiado pequeño **deroga D-F9 en la
     práctica**: la adopción nunca se completa y la decisión queda anulada sin que nadie la revoque.
     La cota inferior sale del peor caso (`F_slots × 92 ms` ≈ 11 min de CPU); la superior **no está
     derivada**.
   - **Una tercera rendija**, que se suma a las dos de PCO-v0.1: dos nodos con el mismo DAG pueden
     acabar en flujos distintos porque uno pudo pagar la verificación y el otro no, y **está
     parcialmente bajo control del atacante**. **No medida.**
6. **Nota de numeración, sin abrir decisión.** `C-FLU-23` es una **enmienda a C-NET-32.3**, no una
   regla de flujo. Por el criterio que Katana fijó en **D-F7** (la finalidad salió de `C-FLU` a
   `C-FIN`), el traslado debería numerarla en **`C-NET`**. El criterio ya está decidido, así que lo
   señalo en la regla y en el índice y **no abro D-F11**.
7. **`DECISIONES-PENDIENTES.md`:** D-F10 pasa a decidida con su registro de opciones conservado.
   **D-F1…D-F10 decididas; ninguna abierta.**
8. **«Lo que NO resuelve»:** los puntos 19 y 20 se reescriben — ya no dicen «D-F10 abierta», dicen
   la rendija nueva sin medir y la pinza de calibración.

## Nada de cómputo

Sin Julia y sin Python. Las dos magnitudes que esta revisión nombra —la vía A2 y la rendija del
presupuesto— **siguen sin medir**.

## Comprobación de salida

`date`:

```
dom 20 sep 2026 14:58:38 CEST
```

`LC_ALL=C sha256sum -c` de las dos huellas:

```
P-FLUJO/ENCARGO.md: OK
P-FLUJO/PROMPT.md: OK
P-FLUJO/ADENDA-1.md: OK
P-FLUJO/ADENDA-2.md: OK
P-FLUJO/ADENDA-3.md: OK
```

`git -C /home/katana/zeo/ZEROX status --short`:

```
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

**Idéntico a la entrada de esta revisión.** Solo se han modificado los tres archivos de
`P-FLUJO/propuesta/`. `?? P-ZRX/` y `?? P-CIERRE/` no son míos y no se han tocado.

## Entregables al cierre de la revisión 6

| Archivo | Contenido |
|---|---|
| `P-FLUJO/propuesta/PROPUESTA-SPEC.md` | **23 reglas: `C-FLU-01…18`, `C-FLU-20…23` y `C-FIN-01`** |
| `P-FLUJO/propuesta/DECISIONES-PENDIENTES.md` | **D-F1…D-F10 decididas; ninguna abierta** |
| `P-FLUJO/propuesta/PROGRESO.md` | este archivo, con las seis revisiones |

## Lo que hay que leer primero, si solo se lee una cosa

**La pinza de calibración de C-FLU-23.** Los dos presupuestos van como símbolos, pero **no son
libres en las dos direcciones**: por abajo los ata el peor caso de verificación (≈11 min de CPU) y,
si se quedan por debajo, **la adopción de C-FLU-22 no se completa nunca y D-F9 queda derogada de
hecho**. Un parámetro mal calibrado no degrada el diseño: le apaga una decisión.

**Y la tercera rendija**, que no estaba en ninguna lista: el presupuesto puede dejar a dos nodos con
el mismo DAG en flujos distintos, y esa es la única de las tres que el atacante puede provocar.
