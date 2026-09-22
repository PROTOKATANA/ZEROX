# PLAN-SPEC — P-CIERRE fase 1 · §1.2

**2026-09-20. Esto es un PLAN. No se ha editado `SPEC.md`, `TAREAS.md` ni `ci/`.** La fase 2 solo
empieza con una adenda que apruebe este documento. Es **integración, no investigación**: ninguna
regla se inventa ni se mejora. Todo lo que entra sale de dos propuestas ya validadas y con todas
sus decisiones tomadas: `veritas/consenso/pot-primitiva-v1/PROPUESTA-SPEC.md` (C-POT-01…08) y
`veritas/consenso/regla-flujo-v1/PROPUESTA-SPEC.md` (C-FLU-01…18, 20…23 y C-FIN-01). Las rutas de
origen que se citan abajo son **las migradas**; el contenido es idéntico al de `P-POT/propuesta/`
y `P-FLUJO/propuesta/`, que quedan intactos.

## 0 · Cómo leer este plan

**Una fila por edición.** El §1 es el **índice exhaustivo**: `E-NN`, archivo y línea, ID de regla,
qué clase de edición es, de dónde sale, y si lleva dudas. Cada `E-NN` tiene después su **bloque de
detalle** con el **texto actual literal** y el **texto propuesto literal**, porque hay textos de
veinte líneas que en una celda de tabla no se pueden leer ni revisar.

**Números de línea:** los del `SPEC.md` y `TAREAS.md` de hoy, antes de tocar nada. Cada edición los
desplaza; el orden de aplicación de la fase 2 será **de abajo arriba** dentro de cada archivo, para
que los números de las ediciones posteriores no se muevan mientras se aplican.

**Criterios de fondo que gobiernan todo el plan** (`P-CIERRE/ENCARGO.md` §1.2.1):

1. Al SPEC va el **enunciado normativo** y una **nota corta de motivo**. Las demostraciones y las
   cifras de simulación **se quedan en `veritas/` y se citan**.
2. **Ninguna cifra medida entra como constante.** `F_slots`, `L_suelo_slots`, `I_slots`, `D`,
   `N(s)`, `ρ_max`, `PRESUP_PAR` y `PRESUP_NODO` van como **símbolos** o `<<PENDIENTE>>`.
3. **No se reescribe el fondo de ninguna regla.** Lo que al condensar parece defecto o ambigüedad
   se **anota** en §8 y **no se resuelve**: decide Katana.

**Convenciones de forma que ya impone el repositorio y que el plan respeta:**

- Un ID nuevo **MUST** empezar línea como `**C-XXX-NN** ·` para que `ci/citas-spec.sh` lo cuente
  (`grep -oP '^\*\*\K[A-Z]+-[A-Z]+-[0-9]+[a-z]?' SPEC.md`, `ci/citas-spec.sh:54`).
- IDs **nuevos y estables**, sin reutilizar retirados (`TAREAS.md` §4.2, `TAREAS.md:653-654`).
- Mientras no exista código, cada ID va a `ci/reglas-sin-codigo.txt` (`TAREAS.md:655-656`).

---

## 1 · Índice exhaustivo de ediciones

### 1.1 · `SPEC.md` — reglas nuevas (32 ediciones: E-01 es la reescritura de §7.1; las otras 31 son reglas)

| # | Archivo:línea | ID | Clase | De dónde sale | Dudas |
|---|---|---|---|---|---|
| E-01 | `SPEC.md:1278-1285` | §7.1 | reescritura de sección: desaparece su «Pendiente» y pasa a ser la portada de §7.1.1–§7.1.7 | encargo §1.2.2 | — |
| E-02 | `SPEC.md:+§7.1.1` | **C-POT-01** | nueva | `pot-primitiva-v1/PROPUESTA-SPEC.md:28-60` | — |
| E-03 | `SPEC.md:+§7.1.1` | **C-POT-02** | nueva | `:62-86` | — |
| E-04 | `SPEC.md:+§7.1.1` | **C-POT-03** | nueva | `:88-107` | — |
| E-05 | `SPEC.md:+§7.1.1` | **C-POT-04** | nueva | `:109-125` | — |
| E-06 | `SPEC.md:+§7.1.1` | **C-POT-05** | nueva | `:127-163` | **D-1** (corrección obligatoria de `PROCEDENCIA.md`) |
| E-07 | `SPEC.md:+§7.1.2` | **C-POT-06** | nueva | `:169-219` | — |
| E-08 | `SPEC.md:+§7.1.2` | **C-POT-07** | nueva | `:225-275` | — |
| E-09 | `SPEC.md:+§7.1.2` | **C-POT-08** | nueva | `:281-310` | — |
| E-10 | `SPEC.md:+§7.1.3` | **C-FLU-01** | nueva | `regla-flujo-v1/PROPUESTA-SPEC.md:443-528` | **D-2** |
| E-11 | `SPEC.md:+§7.1.3` | **C-FLU-02** | nueva | `:547-609` | **D-3** |
| E-12 | `SPEC.md:+§7.1.3` | **C-FLU-03** | nueva | `:611-631` | — |
| E-13 | `SPEC.md:+§7.1.3` | **C-FLU-04** | nueva | `:633-729` | — |
| E-14 | `SPEC.md:+§7.1.3` | **C-FLU-05** | nueva | `:733-753` | — |
| E-15 | `SPEC.md:+§7.1.3` | **C-FLU-06** | nueva | `:755-801` | **D-4** |
| E-16 | `SPEC.md:+§7.1.3` | **C-FLU-07** | nueva | `:805-824` | — |
| E-17 | `SPEC.md:+§7.1.3` | **C-FLU-08** | nueva | `:826-854` | — |
| E-18 | `SPEC.md:+§7.1.3` | **C-FLU-09** | nueva | `:856-882` | — |
| E-19 | `SPEC.md:+§7.1.4` | **C-FLU-10** | nueva | `:886-941` | **D-5** |
| E-20 | `SPEC.md:+§7.1.4` | **C-FLU-11** | nueva | `:943-965` | **D-6** |
| E-21 | `SPEC.md:+§7.1.4` | **C-FLU-12** | nueva (con su invariante como cláusula, **no** como ID aparte) | `:969-1032` | **D-7** |
| E-22 | `SPEC.md:+§7.1.5` | **C-FLU-13** | nueva | `:1036-1064` | — |
| E-23 | `SPEC.md:+§7.1.5` | **C-FLU-14** | nueva | `:1066-1122` | — |
| E-24 | `SPEC.md:+§7.1.6` | **C-FLU-15** | nueva | `:1211-1282` | — |
| E-25 | `SPEC.md:+§7.1.7` | **C-FLU-16** | nueva | `:1600-1630` | — |
| E-26 | `SPEC.md:+§14.3` | **C-FLU-17** | nueva, **NO es regla de consenso** | `:1554-1596` | **D-8** (dónde vive) + **D-9** (contradice C-FLU-22) |
| E-27 | `SPEC.md:+§7.1.6` | **C-FLU-18** | nueva | `:1513-1552` | — |
| E-28 | `SPEC.md:+§7.1.5` | **C-FLU-20** | nueva | `:1124-1166` | — |
| E-29 | `SPEC.md:+§7.1.5` | **C-FLU-21** | nueva | `:1168-1207` | — |
| E-30 | `SPEC.md:+§7.1.6` | **C-FLU-22** | nueva | `:1284-1449` | — |
| E-31 | `SPEC.md:+§12`, tras `C-REORG-07` | **C-FIN-01** | nueva, familia `C-FIN` nueva | `:1777-1828` | **D-10** |
| E-32 | `SPEC.md:+§16.6`, tras `C-NET-32` | **C-NET-33** | nueva — **es `C-FLU-23` renumerada** | `:1451-1511` | **D-11** (el ID) |

> **`C-FLU-19` no existe y no se reutiliza.** Fue el nombre de la regla de finalidad hasta la
> revisión 5 de la propuesta; `D-F7 = B` la sacó de la familia y la llamó `C-FIN-01`
> (`regla-flujo-v1/PROPUESTA-SPEC.md:101-103`). El hueco es deliberado.

### 1.2 · `SPEC.md` — reglas y secciones existentes que cambian (14 ediciones)

| # | Archivo:línea | ID | Qué cambia | De dónde sale | Dudas |
|---|---|---|---|---|---|
| E-33 | `SPEC.md:28-37` | §0.2 | la tabla de áreas gana `C-POT`, `C-FLU` y `C-FIN` | encargo §Reglas 4 | **D-12** |
| E-34 | `SPEC.md:560-584` | **C-HASH-06** | dos etiquetas de dominio nuevas; la lista «cerrada» se amplía | D-F2 = A; `regla-flujo-v1/…:918-931` | — |
| E-35 | `SPEC.md:879-881` | **C-HDR-05** | la cota de slot pasa **a todos los padres** | D-F6 = A; `:547-560` | **D-13** (ci/) |
| E-36 | `SPEC.md:883-899` | **C-HDR-06** | su `flow(B, slot(B))` queda definido: remite a C-FLU-10/11 | `:951-963` | **D-14** (`flow` vs `flujo`) |
| E-37 | `SPEC.md:907-928` | **C-HDR-07** | el `pot_output` único es la **salida futura**; el último checkpoint la ancla | D-2 = A; `pot-primitiva-v1/…:127-163` | **D-1** |
| E-38 | `SPEC.md:1687-1689` | **C-GD-04** | su repetición de la cota de slot se alinea con C-HDR-05 nueva | `regla-flujo-v1/…:598-601` | — |
| E-39 | `SPEC.md:1721-1734` | **C-GD-10** | dos filtros nuevos de la cola de candidatos (C-FLU-02, C-FLU-20) y la **enumeración cerrada** del verificador se amplía | `:571-588`, `:1145-1150` | — |
| E-40 | `SPEC.md:1891-1903` | **C-REORG-07** | sigue **transitoria**; solo gana una remisión a C-FIN-01 | encargo §1.2.2; `:1810-1828` | — |
| E-41 | `SPEC.md:2976-2980` | **C-NET-31** | la caché se indexa por la **clave contextual** de C-POT-07, no por slot a secas | `pot-primitiva-v1/…:225-257` | — |
| E-42 | `SPEC.md:2997-3009` | **C-NET-32** | la salvaguarda 1 se acota a «misma clave»; la 3 gana la **cota global por nodo** y el modo de fallo `Pendiente` | D-F10 = B; `pot-primitiva-v1/…:250-253`, `regla-flujo-v1/…:1451-1511` | — |
| E-43 | `SPEC.md:1436-1438` | §7.3 | `L` deja de ser parámetro libre: pasa a **definición** | tercera tanda de Katana; `:468-478` | — |
| E-44 | `SPEC.md:1449-1466` | §7.3 | el contrato de unidades gana `L_slots := máx(…)`, `F_slots`, `L_suelo_slots` y las remisiones | `:443-455` | — |
| E-45 | `SPEC.md:3029` | §17 | la fila «Prueba de espacio/tiempo» deja de decir «Decisión de diseño pendiente» | encargo §1.2.2 | — |
| E-46 | `SPEC.md:3034` | §17 | la fila «Finalidad» remite a C-FIN-01 y nombra lo que NO se reconcilia | D-F3 acotada | — |

### 1.3 · `TAREAS.md` (8 ediciones)

| # | Archivo:línea | Qué cambia | De dónde sale | Dudas |
|---|---|---|---|---|
| E-47 | `TAREAS.md:124-178` | §2.1 pasa a «cerrado en el SPEC, falta cablear», **corrigiendo su titular** | encargo §1.2.3 | — |
| E-48 | `TAREAS.md:186-188` | §2.3 anota el **residuo de paridad del `SR`** | `puerta-cobertura-v1/PROCEDENCIA.md` §3 | — |
| E-49 | `TAREAS.md:297-298` | §2.7: C-NET-31 y C-NET-32 **corregidas** | E-41, E-42 | — |
| E-50 | `TAREAS.md:414` | §3.3: `L` ya no es libre; `L_suelo_slots` símbolo | E-43 | — |
| E-51 | `TAREAS.md:+§2.9` | **ocho puntos que hoy no están en ninguna lista** | encargo §1.2.3 | — |
| E-52 | `TAREAS.md:+726` | «Cerrado recientemente» gana la entrada de §2.1 | forma de la lista | — |
| E-53 | `TAREAS.md:648-660` | §4.2 registra las tres familias nuevas y el hueco `C-FLU-19` | encargo §Reglas 4 | — |
| E-56 | `TAREAS.md:679-681` | Nivel 5 gana el defecto de `run.jl` de ANCLA-v0.2 (escribe en el CWD) | **`ADENDA-1.md` §1** | — |

### 1.4 · `ci/` (2 ediciones)

| # | Archivo | Qué cambia | Dudas |
|---|---|---|---|
| E-54 | `ci/reglas-sin-codigo.txt` | **+31 IDs**: C-POT-01…08, C-FLU-01…18, C-FLU-20…22, C-FIN-01, C-NET-33 | — |
| E-55 | `ci/reglas-sin-cablear.txt` | **C-HDR-05 y C-HDR-07 cambian de semántica**: su código queda por detrás del SPEC. Se declara con el precedente de C-NET-07, **sin tocar `crates/`** | **D-13** |

**Total: 56 ediciones.** (55 del plan original + E-56, pedida por `P-CIERRE/ADENDA-1.md` §1.)

---

## 2 · Dónde viven las reglas nuevas, y cómo se condensan

### 2.1 · La estructura propuesta

`§7 · Prueba de espacio y tiempo` es el sitio: es donde el SPEC ya tiene el hueco («fijar el
formato y validación conjunta, retardo de autoría, puntos de control, **inyección de entropía y
dependencias por flujo**», `SPEC.md:1284-1285`) y es lo que §2.1 de `TAREAS.md` persigue.

```
§7.1 · Prueba y desafío                          ← E-01, portada; pierde su «Pendiente»
  §7.1.1 · El PoT como primitiva                 ← C-POT-01…05
  §7.1.2 · El contrato del verificador           ← C-POT-06, C-POT-07, C-POT-08
  §7.1.3 · El flujo: unidades, ancla y época     ← C-FLU-01…09
  §7.1.4 · El identificador de flujo             ← C-FLU-10, 11, 12
  §7.1.5 · Validez y pasado consistente          ← C-FLU-13, 14, 20, 21
  §7.1.6 · Partición de flujo                    ← C-FLU-15, 22, 18
  §7.1.7 · El calendario de N(s)                 ← C-FLU-16
§12 · Reorganizaciones, tras C-REORG-07          ← C-FIN-01   (familia C-FIN nueva)
§14.3 · Comportamiento del nodo                  ← C-FLU-17   (NO es regla de consenso; D-8)
§16.6 · PoT en la red, tras C-NET-32             ← C-NET-33   (era C-FLU-23; D-11)
```

**Por qué C-FIN-01 no va en §7.** Porque no es una regla de flujo: es una regla de **finalidad**
que el flujo usa, y Katana lo decidió así en **D-F7 = B**
(`veritas/consenso/regla-flujo-v1/DECISIONES-PENDIENTES.md:438-452`). §12 es donde vive la única
regla de profundidad de reorganización que hoy tiene el SPEC, `C-REORG-07`, y ponerlas juntas es lo
que hace visible que una **sustituye** a la otra en el DAG y que **hoy conviven sin reconciliar**.

**Por qué C-NET-33 no va en §7 ni se llama C-FLU-23.** La propia propuesta lo señala y **no abre
decisión**, porque el criterio ya está decidido: «`C-FLU-23` es una **enmienda a C-NET-32.3**, no
una regla de flujo. Por el mismo criterio que Katana fijó en **D-F7**, el traslado debería
numerarla en `C-NET`» (`regla-flujo-v1/PROPUESTA-SPEC.md:1504-1511`). El siguiente libre es
**C-NET-33** (el máximo hoy es `C-NET-32`; `C-NET-10` está retirada con tombstone y no se
reutiliza).

### 2.2 · Qué se queda fuera del SPEC al condensar

Cada regla de las propuestas trae enunciado, demostración, medición y discusión. **Al SPEC va solo
el enunciado normativo y una nota corta de motivo.** Lo demás se cita. En concreto:

| Qué | Dónde se queda | Cómo se cita en el SPEC |
|---|---|---|
| Las demostraciones (buena fundamentación del ancla, unicidad, Lemas 1 y 2, (c′), A1, el cierre del DoS…) | `veritas/consenso/regla-flujo-v1/PROPUESTA-SPEC.md` | por regla, con `§` y líneas |
| Las cifras de `L_mín` (119 / 1 198 / 1 682 / 177 slots) y la cola de `W_obs` | `veritas/consenso/ancla-inyeccion-v2/` | como **referencia de calibración**, nunca como valor |
| `arcsin(√(τ/F))/π` → 0,27 % / 0,75 % / 1,5 % | `veritas/consenso/puerta-cobertura-v1/` | en la nota de riesgo residual de C-FLU-22 |
| 92 ms/slot, 1,561 s de producción, `F_slots × 92 ms ≈ 11 min` | `veritas/rendimiento/coste-salto-v1/` y `SPEC.md:2987-2991`, ya citados | se conservan las citas que el SPEC ya tiene |
| Los 45 vectores de cita y los V1–V5 | `veritas/consenso/pot-primitiva-v1/vectores/` | una remisión en C-POT-02 |
| Todo `DECISIONES-PENDIENTES.md` | las dos carpetas migradas | remisión en §17 |

**Ninguna cifra medida entra como constante.** Van como símbolo: `F_slots`, `L_suelo_slots`,
`L_slots`, `I_slots`, `S_max_slots`, `D`, `N(s)`, `ρ_max`, `PRESUP_PAR`, `PRESUP_NODO`,
`ETIQUETA_FLUJO`, `ETIQUETA_GENESIS`, `entropía_externa`, y la ventana de persistencia de C-FLU-17.

---

## 3 · Detalle de las ediciones — reglas nuevas

### E-01 · `SPEC.md:1278-1285` · §7.1 pierde su «Pendiente»

**Texto actual (literal):**

```markdown
### 7.1 · Prueba y desafío

R-FIN-14 describe el reto por slot derivado de la salida PoT secuencial del flujo. No basta
comprobar un hash de cabecera: hay que verificar solución de espacio, testigos KZG, identidad de
billete, reto, distancia de solución, sello y justificación PoT.

**Pendiente:** fijar el formato y validación conjunta, retardo de autoría, puntos de control,
inyección de entropía y dependencias por flujo. No se introduce una prueba de sustitución.
```

**Texto propuesto (literal):**

```markdown
### 7.1 · Prueba y desafío

No basta comprobar un hash de cabecera: hay que verificar solución de espacio, testigos KZG,
identidad de billete, reto, distancia de solución, sello y justificación PoT.

Las subsecciones §7.1.1 a §7.1.7 fijan la parte **PoT y flujo** de esa verificación: el PoT como
primitiva (`C-POT-01`…`C-POT-05`), el contrato del verificador (`C-POT-06`…`C-POT-08`), y el
**flujo** — unidades, ancla, época, identificador, entropía, validez y partición
(`C-FLU-01`…`C-FLU-18`, `C-FLU-20`…`C-FLU-22`). La regla de finalidad de la que cuelgan es
`C-FIN-01` (§12); el presupuesto de verificación de flujo ajeno es `C-NET-33` (§16.6); la señal de
flujo minoritario, que **no es regla de consenso**, es `C-FLU-17` (§14.3).

> **Procedencia.** `C-POT-01`…`C-POT-08` salen de
> `veritas/consenso/pot-primitiva-v1/PROPUESTA-SPEC.md`, validada el 2026-09-20; las reglas de
> flujo, de `veritas/consenso/regla-flujo-v1/PROPUESTA-SPEC.md`, validada el mismo día. **Las
> demostraciones y las cifras de simulación se quedan allí y no se repiten aquí.** Los
> instrumentos que las sostienen son `veritas/consenso/ancla-inyeccion-v2/` (ANCLA-v0.2) y
> `veritas/consenso/puerta-cobertura-v1/` (PCO-v0.1), con el alcance declarado en sus
> `PROCEDENCIA.md`. **Ninguno de sus números entra aquí como constante.**

**Sigue pendiente**, y no lo cierran estas subsecciones: la **validación conjunta** de solución de
espacio, testigos KZG, distancia de solución y sello contra el reto derivado (el paso 5 de
`C-POT-08`), el **retardo de autoría** `D` como valor, y los puntos de control. No se introduce una
prueba de sustitución.
```

**De dónde sale:** encargo §1.2.2 («§7.1 (desaparece su «Pendiente»)»). La frase «R-FIN-14
describe…» se retira porque R-FIN-14 es **evidencia histórica** (`research/README.md:7-10`) y lo
que describía ya está escrito como regla.

**Dudas:** ninguna. La parte de §7.1 que **sí** sigue pendiente se conserva explícita, para no
convertir «cerrado el flujo» en «cerrada §7.1».

### E-02 … E-06 · `SPEC.md` · §7.1.1 nueva · `C-POT-01` … `C-POT-05`

**Texto actual:** no existe. §7.1.1 es sección nueva, insertada tras E-01.

**Texto propuesto (literal):**

````markdown
#### 7.1.1 · El PoT como primitiva

Un **flujo** `f` es un identificador opaco de 32 bytes (`C-FLU-10`). `semilla(f, 0)` la aporta el
contexto (`C-FLU-06`). `N(s)` es el trabajo secuencial del slot `s` (§7.3) y `D` el retardo de
autoría; los dos van como **símbolos**.

**C-POT-01** · **Encadenado de semilla slot a slot.**

```text
semilla(f, s) = salida(f, s−1)                                  (caso general)
semilla(f, s) = blake3(entropía(f, s) ‖ salida(f, s−1))[0..16)  (si el contexto declara inyección en s)
```

La entropía y el slot de activación son **ENTRADAS que aporta el contexto**, nunca el candidato
(`C-FLU-12`, `C-FLU-07`). **MUST** haber **a lo sumo una inyección por slot**; si el contexto
declarara más de una, el estado es `Pendiente` por error de contexto (`C-POT-06`), **nunca** una
decisión local. El bloque génesis no lleva justificación (`pot_bundle_count = 0`, C-HDR-07); la
salida de su slot se evalúa desde `semilla(f_0, 0)` y su reto se deriva como el de cualquier slot.

> El orden de la concatenación —**la entropía primero**, truncado a 16 bytes— y el aplicarla
> exactamente en el slot de inyección son los de Autonomys, verificados en fuente en
> `veritas/consenso/pot-primitiva-v1/PROPUESTA-SPEC.md:38-44`. `blake3` se conserva byte a byte
> por decisión de Katana del 2026-09-19 (**D-1 = A**): es lo que mantiene vivos los 32 vectores
> diferenciales de `prototipos/pot-estable` como validación externa.

**C-POT-02** · **Salida, checkpoints y verificación de un slot.**

```text
salida(f, s) = AES128_chain^{N(s)}(semilla(f, s))
```

evaluada en **8 tramos uniformes**: un `PotCheckpoints` de `8 × 16 = 128 B`, siendo la salida el
**último** de los ocho. La clave AES del tramo es `blake3(semilla)[0..16)`. `N(s)` **MUST** ser
múltiplo de 16; en otro caso la primitiva rechaza (`C-POT-04`).

La verificación de un slot **MUST** ser una función **determinista** de la terna
`(semilla, N, PotCheckpoints)`: misma terna, mismo resultado, en cualquier nodo y en cualquier
orden de llegada. Es la propiedad en la que se apoya `C-POT-07`.

> Vectores de forma V1–V5 en `veritas/consenso/pot-primitiva-v1/vectores/`, reproducidos 4/4. **No
> sustituyen** los 32 vectores diferenciales de `prototipos/pot-estable`, que son la validación
> externa del AES.

**C-POT-03** · **Aleatoriedad y reto por slot, sin atajos.**

```text
aleatoriedad(f, s) = blake3(salida(f, s))
reto(f, s)         = blake3(aleatoriedad(f, s) ‖ LE64(s))
```

Ningún reto de un slot **MUST** derivarse de una función que permita **saltarse slots**. En
particular **MUST NOT** existir `reto(f, s) = H(flujo(f) ‖ s)` ni ninguna PRF de `s` a partir de un
valor fijo de época: el reto de `s` solo es derivable **después** de evaluar la cadena secuencial
hasta `s`.

> Es lo único que impide evaluar de antemano la época entera de un candidato a ancla. Sin esta
> prohibición, el adelanto de `L_slots` con que se conoce la entropía (C-FLU-07) dejaría de costar
> tiempo secuencial.

**C-POT-04** · **Dominio de `N(s)` y proyección `u64 → NonZeroU32`.**

El contexto expresa `N(s)` en `u64`. El **verificador MUST** proyectarlo con comprobaciones y
**MUST NOT** hacer panic ni envolver en silencio. Si `N(s) == 0`, `N(s) > u32::MAX` o
`N(s) % 16 ≠ 0`, el estado es **`Pendiente` con diagnóstico de contexto, nunca `Inválido`**: el
fallo está en el pasado validado del nodo o en su implementación, no en el candidato.

`N(s)` es función del pasado validado y lo aporta el contexto; el candidato **MUST NOT** poder
declararlo. Su valor inicial, sus límites y **quién autoriza** un cambio siguen
`<<PENDIENTE: §7.3>>`; su calendario lo fija `C-FLU-16`.

**C-POT-05** · **Qué es el `pot_output` de la cabecera y qué cubre la justificación.**

```text
pot_output(B) = salida(f, slot(B) + D)      la salida «future», anclada en la cabecera
```

**Decidido por Katana el 2026-09-19 (D-2 = A):** de las dos salidas que Autonomys lleva en su
pre-digest, el campo único de 16 B de ZEROX (`[88,104)`, C-HDR-01) es la **futura**.

La justificación de `B` lleva `d = slot(B) − slot(sp(B))` portadores (C-HDR-07). El portador `i`
cubre el slot `slot(sp(B)) + D + i`, y el **último checkpoint del último portador MUST ser igual a
`pot_output(B)`**. Con esto `pot_bundle_count == slot(B) − slot(sp(B))` es exactamente el número
de slots del rango `(slot(sp(B)) + D, slot(B) + D]`. La semilla del primer slot del rango la deriva
el **contexto** del pasado validado —con D-2 = A es la salida del slot `slot(sp(B)) + D`, ya
anclada en un bloque anterior—, **nunca el candidato** (`C-POT-06`).

> **El coste de la opción A, dicho en voz alta y con su corrección.** El reto del slot `s`
> (`C-POT-03`) usa la salida del slot `s`, que **no** está anclada en la cabecera de `B`. En el
> camino normal la aporta la caché por slot (`C-NET-31`). En el camino **bajo demanda**
> (`C-NET-32`) hay que obtenerla del pasado validado: **como los padres se validan antes que el
> hijo, la salida del slot `s` sale siempre de ese pasado** —de la propia justificación de `B` si
> `d > D`, o de la de un ancestro—. La redacción de la propuesta decía que «la justificación de
> `B` no basta»; **es demasiado pesimista y queda corregida aquí**, según
> `veritas/consenso/pot-primitiva-v1/PROCEDENCIA.md`.
````

**De dónde sale:** `veritas/consenso/pot-primitiva-v1/PROPUESTA-SPEC.md:26-163`. La corrección de
C-POT-05 viene de `veritas/consenso/pot-primitiva-v1/PROCEDENCIA.md`, que la marca «**Corrección
pendiente al pasar al SPEC**».

**Qué se queda fuera:** las 45 citas verificadas en fuente de Autonomys, la tabla de las tres
opciones de D-2 con su coste, la nota de Katana al decidir, y la derivación candidata de
`semilla(f, 0)` de Autonomys. Todo en la carpeta migrada.

**Dudas — D-1:** la corrección de `PROCEDENCIA.md` **cambia una afirmación de la propuesta
validada**, no solo la condensa. La escribo como manda el testimonio del validador y la señalo
aquí para que Katana la vea en el diff y no en una nota al pie.

### E-07 … E-09 · `SPEC.md` · §7.1.2 nueva · `C-POT-06`, `C-POT-07`, `C-POT-08`

**Texto actual:** no existe.

**Texto propuesto (literal):**

````markdown
#### 7.1.2 · El contrato del verificador de PoT

**C-POT-06** · **Entradas, salida de tres estados y prohibición de circularidad.**

**Del candidato** —lo único que viaja en el wire— la cabecera DAG (con `slot` y `pot_output`) y la
justificación `PotCheckpoints` (C-HDR-07). **Del contexto**, derivado exclusivamente del pasado DAG
validado: el identificador de flujo `f`, la semilla del primer slot del rango, las inyecciones y
`N(s)` de cada slot del rango, el retardo `D`, y la caché del propio nodo (`C-POT-07`).

La salida **MUST** tener **tres** estados, no dos:

```text
PotValido        — cadena completa verificada y anclada
PotInvalido(r)   — defecto del candidato, verificable y final
PotPendiente(r)  — sin prueba de invalidez, pero tampoco de validez
```

`Inválido` **MUST** reservarse a: descuadre o desborde de portadores (C-HDR-05/C-HDR-07);
verificación AES fallida para alguna terna con la semilla y el `N(s)` del contexto; último
checkpoint ≠ `pot_output` (C-POT-05); discrepancia con la caché **bajo la misma clave**
(`C-POT-07`). `Pendiente` cubre: `N(s)` fuera del dominio de `C-POT-04`; slot por delante del reloj
PoT del nodo (C-NET-32.2); **presupuesto agotado** (`C-NET-33`); y fallo interno del contexto.
**Nada `Pendiente` pasa a `Válido` por defecto:** la única transición es una verificación posterior
**exitosa** con las mismas entradas de contexto.

**Prohibición de circularidad.** El verificador **MUST NOT** aceptar del propio candidato lo que
debe venir del pasado validado: el flujo, la semilla del rango, las inyecciones y `N(s)` **MUST**
aportarlos el contexto. El candidato solo aporta los checkpoints —evidencia reemplazable— y el
`pot_output` anclado —redundancia comprobada, **nunca fuente de verdad**—. Ninguna implementación
**MUST** ofrecer una vía que acepte el valor declarado por el candidato como si fuese el esperado:
**la circularidad MUST ser imposible, no desaconsejada**. Es el mismo principio de C-HDR-06.

El identificador de flujo es **opaco** para este verificador: se usa para indexar el contexto y la
caché, y **MUST NOT** interpretarse, derivarse de él ni validarse (`C-FLU-11`).

**C-POT-07** · **La caché se indexa por contexto, no por slot; y validez ≠ política de recursos.**

```text
clave_caché = (f, s, semilla(f, s), N(s))     los cuatro del CONTEXTO, no del candidato
valor       = salida(f, s)
```

La caché **MUST** indexarse por la clave contextual completa. Una entrada cacheada pertenece a un
contexto: **discrepar con una entrada de OTRA clave no prueba nada** —son cadenas de PoT distintas,
ambas legítimas—. Con la **misma** clave el PoT es determinista (`C-POT-02`), así que discrepancia
⟹ `Inválido`, y se decide comparando 128 B, **sin gastar AES**.

Agotar un presupuesto de CPU (`C-NET-33`) produce **`Pendiente`, nunca `Inválido`**: un nodo sin
recursos **MUST NOT** declarar falsa una prueba que no ha verificado. Lo mismo para la retención
por reloj (C-NET-32.2).

> **Por qué la clave y no el slot.** Con más de un flujo candidato, `salida(f₁,s) ≠ salida(f₂,s)`, y
> una caché por slot a secas haría depender la **validez** de qué llegó primero — contra el
> principio de que la validez es función del pasado del bloque y de nada más. **Con un único flujo
> la corrección es inocua**, y está demostrado en
> `veritas/consenso/pot-primitiva-v1/PROPUESTA-SPEC.md:259-275`: la clave pasa a ser función de `s`
> y el comportamiento observable es idéntico al del texto anterior.

**C-POT-08** · **Orden de validación: estructural y barato antes que AES; cada paso con su estado.**

| Paso | Comprobación | Estado si falla |
|---|---|---|
| 1 | **Estructural, sin AES.** Decode acotado (C-WIRE-04/05); `slot(B) ≥ slot(p)` para **todo** padre (C-HDR-05); `pot_bundle_count == slot(B) − slot(sp(B)) ≤ 150` sin underflow (C-HDR-07) | `Inválido` |
| 1b | **Flujo (`C-FLU-14`), sin AES.** Derivar `flujo(B, ·)` del pasado validado y comprobarlo contra el de cada `X ∈ past(B)` | `Inválido` si discrepa; `Pendiente` si falta pasado |
| 2 | Cabecera y sello (C-HDR-03/C-HDR-04) | `Inválido` |
| 3 | **Caché por clave** (`C-POT-07`): comparar la salida anclada con la entrada de la clave del contexto | `Inválido` / `Pendiente` |
| 4 | **AES secuencial del rango**: por portador, verificar; encadenar semilla; último checkpoint == `pot_output` | `Inválido` si falla; `Pendiente` si se agota el presupuesto |
| 5 | Solo con `Válido`: derivar `reto` del slot (`C-POT-03`) y verificar la solución PoAS contra él | según §7.1 |

El paso 3 es lo que garantiza que **el camino normal no paga AES por bloque**: el coste por salto
queda acotado por construcción, que es el criterio de C-NET-06. El paso 4 es el respaldo bajo
demanda (C-NET-32), con el presupuesto de `C-NET-33`. Un `Pendiente` en el paso 4 **MUST NOT**
invalidar el bloque: el nodo retiene y completa cuando pueda.

> **El paso 1b va donde va, y no más tarde, por dos razones.** La clave de caché del paso 3
> **empieza por `f`**: sin el flujo resuelto no hay clave que consultar. Y `C-POT-06` exige que el
> flujo lo aporte el contexto: `C-FLU-10` y `C-FLU-11` son quien cumple esa exigencia.
````

**De dónde sale:** `veritas/consenso/pot-primitiva-v1/PROPUESTA-SPEC.md:167-310`, con el paso **1b**
insertado por `veritas/consenso/regla-flujo-v1/PROPUESTA-SPEC.md:1089-1101`. Los cinco pasos
originales **no se tocan**, que es lo que la propuesta de flujo declara explícitamente.

**Qué se queda fuera:** el diagnóstico completo de la ronda 10a (por qué «continuidad por defecto»
rompía R-FIN-5), la demostración de inocuidad con un flujo único, los costes de 92/101/190 ms y
8,3 s —ya están en `SPEC.md:2987-2991` y no se duplican—, y el antecedente C-TIMELORD-01.

**Dudas:** ninguna propia. C-POT-08 cita `C-NET-33`, que es E-32: **las dos ediciones tienen que
entrar juntas o ninguna.**

### E-10 … E-18 · `SPEC.md` · §7.1.3 nueva · `C-FLU-01` … `C-FLU-09`

**Texto actual:** no existe.

**Texto propuesto (literal):**

````markdown
#### 7.1.3 · El flujo: unidades, el ancla y la vista de época

**C-FLU-01** · **Todo lo del flujo se mide en índices de slot de PoT, y `L` va atada a `F`.**

```text
T_j      = j · I_slots                  umbral de época j (índice de slot), j ≥ 1
I_j      = ancla de la época j          (C-FLU-04)
t_j      = slot(I_j) + L_slots          instante de activación (índice de slot)
profundidad(t, P) = t − slot(P)         en slots, con P el último ancestro común

L_slots := máx( F_slots , L_suelo_slots , S_max_slots + 1 )
```

`L_slots` es una **definición**, no un parámetro libre: **MUST** derivarse y **MUST NOT**
declararse aparte. `F_slots := ⌈F / τ_nom⌉`. `F_slots`, `L_suelo_slots` e `I_slots` son
**símbolos**; esta regla no les da valor.

Una comparación de consenso **MUST NOT** depender de `τ_nom` en tiempo de ejecución ni de ningún
reloj físico. **La profundidad de una reorganización MUST medirse como
`slot(punta) − slot(último ancestro común)`, en índices de slot; MUST NOT medirse en bloques**: a
`λ = 1 bloque/s` y `τ_nom = 1 s/slot` coinciden nominalmente, pero C-GD-04 admite saltos de hasta
`S_max_slots` en la cadena, así que las dos cuentas se separan y **solo el slot es infalsificable**.

> **Los tres términos del máximo, y por qué hacen falta los tres.** El primero es la atadura que
> Katana decidió (perfil **1a**): si `F` baja en producción, `L` baja con ella, como identidad y no
> como nota de operación. El segundo es el **suelo**, y existe porque el primero no basta: `L`
> responde a una magnitud distinta —la cola de desacuerdo honesto frente a `Δ`—, que no baja cuando
> baja `F`. El tercero hace que `C-FLU-08` se cumpla por construcción para cualquier `F`.
>
> **`L_suelo_slots` MUST fijarse** a partir de (a) la cola medida de desacuerdo de cadena
> seleccionada a una `ε` elegida explícitamente y (b) **una cota de `Δ` medida en red real**.
> Mientras no exista (b), cualquier valor es provisional y **MUST** decirlo. La referencia de orden
> de magnitud —y **solo** eso— está en `veritas/consenso/ancla-inyeccion-v2/`, con `Δ` **simulada**
> (DMS-v0.1), no medida. `<<PENDIENTE: el valor de L_suelo_slots>>`.
>
> ⚠️ §7.3 advierte que `F` «no se iguala por defecto a `L`». Esa frase y `C-FLU-01` **no dicen lo
> mismo**: aquella prohíbe copiar `L` desde `F`; ésta **deriva `L` de `F` con un suelo**. Se parecen
> mucho y significan cosas distintas.

**C-FLU-02** · **Cierre de ancestros por slot.** Para todo bloque `B` y **todo** padre `p` de `B`:
`slot(p) ≤ slot(B)`, desigualdad **no estricta** (el empate está permitido, como en C-HDR-05).

> **Por qué es materia de validez y no política.** La vista de época de `C-FLU-03` es un corte por
> `slot`. Para que ese corte sea un sub-DAG bien formado tiene que ser **cerrado por ancestros**, y
> eso exige que ningún padre tenga un `slot` mayor que su hijo. Sin esta regla un bloque dentro del
> corte puede tener un padre fuera, el sub-DAG queda incompleto y GHOSTDAG **no está definido**
> sobre él. Por eso C-FLU-02 entra también en la enumeración cerrada de C-GD-10 y en C-HDR-05.
>
> **Decidido por Katana el 2026-09-20 (D-F6 = A).** Su coste para el productor honesto está
> **`estimado ≈ 0`, no medido**: `TAREAS.md` §2.9.

**C-FLU-03** · **Vista de época.** `V_j(B) := ( past(B) ∪ {B} ) ∩ { X : slot(X) < T_j + L_slots }`.

El corte **MUST** ser `T_j + L_slots` y **MUST NOT** ser `t_j`: `t_j` depende del ancla que se está
definiendo, y `T_j + L_slots` es función de `j` y de las constantes y de nada más.

> Consecuencia, dicha en voz alta: un bloque con `slot ∈ [T_j + L_slots, t_j)` **no participa** en
> elegir el ancla. Es deliberado.

**C-FLU-04** · **El ancla.** `I_j(B)` es el **primer** bloque de `Chn(V_j(B))` con `slot ≥ T_j`,
donde `Chn(V_j(B))` es la cadena seleccionada del bloque virtual sobre `V_j(B)`, calculada con
C-GD-01…C-GD-07 **restringidas a `V_j(B)`**.

> **`Chn(V_j(B))` NO es la cadena seleccionada del nodo.** Es lo que hace la definición bien
> fundada —la recursión termina, porque el flujo de todo `X ∈ V_j(B)` depende solo de épocas
> `j' < j`— y es también lo que deja la puerta abierta antes de `t_j`: `V_j(B)` **crece sin
> reorganización** en cuanto un bloque nuevo fusiona un bloque retenido del corte, y fusionar no es
> reorganizar. Desde `t_j` la deriva se detiene (`C-FLU-14`, `C-FLU-21`) y el productor la evita
> (`C-FLU-20`). **Antes de `t_j` no hay regla: hay carrera.**
>
> La existencia, la unicidad y la buena fundamentación están **demostradas** en
> `veritas/consenso/regla-flujo-v1/PROPUESTA-SPEC.md:633-729`, con la condición suficiente escrita
> y el caso en que falla nombrado. Ese caso lo cierra `C-FLU-05`.

**C-FLU-05** · **Época sin ancla: se salta, y saltarla es definitivo.**

```text
Si Chn(V_j(B)) no cruza T_j, la época j NO produce inyección para B: el flujo de B
sigue siendo el de la última inyección realizada.
Un bloque B con slot(B) ≥ T_j + L_slots para el que I_j(B) no exista es INVÁLIDO.
```

Una época saltada **MUST NOT** recuperarse después. **No hay inyección retroactiva.**

> Sin la segunda frase la regla no es monótona: un descendiente con vista mayor tendría un flujo
> distinto del de `B` en slots donde `B` ya está fijado, `C-FLU-14` lo invalidaría, y la cadena se
> atascaría. Declarar inválido al bloque convierte un bloqueo global en un rechazo local. Un bloque
> honesto cuya cadena seleccionada coincide con la de su vista **nunca** cae aquí.

**C-FLU-06** · **El flujo del génesis y el origen de `semilla(f, 0)`.**

```text
f_0             := H_flujo( ETIQUETA_GENESIS ‖ block_hash(génesis) )        32 B
semilla(f_0, 0) := blake3( block_hash(génesis) ‖ entropía_externa )[0..16)  16 B
```

y `flujo(B, s) = f_0` para todo `s < t_1`. Las épocas se indexan desde `j = 1`: **no hay época 0 y
el génesis no es ancla de nada**. `entropía_externa` es **parámetro de lanzamiento** (§15.2), no
algo que derive el nodo: **MUST** ser pública, verificable e **imposible de elegir después** de
conocer el génesis. `<<PENDIENTE: el valor de entropía_externa por red>>`.

> **Las dos líneas usan hashes distintos a propósito, y el lector no debe «uniformarlas».**
> `semilla(f_0, 0)` conserva `blake3` porque alimenta la primitiva PoT, que D-1 = A dejó entera en
> `blake3`, y porque ahí sí hay oráculo: es la derivación de Autonomys. `f_0` usa `H_flujo`
> (`C-FLU-10`), que es `H_d` con etiqueta propia, porque el identificador de flujo **no tiene
> contraparte en Autonomys**: no hay oráculo que perder y gana la separación de dominio.

**C-FLU-07** · **Activación retardada.** `t_j := slot(I_j) + L_slots`. Para todo slot `s`,
`flujo(B, s)` lo fija la **última** inyección `j` con `t_j ≤ s`; si no hay ninguna, `f_0`. El borde
es **inclusivo**: en `s = t_j` la entropía **ya** está mezclada.

> **Una sola lotería, y está demostrado.** Para todo `s ∈ [slot(I_j), t_j)`, `flujo(B, s)` **no
> depende de `I_j`**: lo fija la inyección `j−1` o anterior. Dos nodos que discrepen del ancla
> producen y verifican **exactamente el mismo** `reto(f, s)` en todo ese intervalo. El intervalo es
> donde la red tiene `L_slots` para converger **sin que la discrepancia tenga consecuencias**; lo
> que ocurre en `t_j` es que la discrepancia, si sobrevive, se vuelve **irreversible**.

**C-FLU-08** · **`S_max_slots < L_slots` — condición de corrección.** Con ella el ancla cae dentro
de su propia vista de época, y en `t_j` está enterrada bajo al menos un bloque de cadena. Sin ella
**la definición del ancla no está bien puesta**. `C-FLU-01` la hace automática.

> **No es la condición que cierra el ataque del bloque retenido**, y decirlo al revés sería
> repetir el patrón de etiqueta ancha sobre resultado estrecho. Lo que cierra ese ataque después de
> `t_j` es `C-FIN-01` junto con `C-FLU-14` y `C-FLU-21`.

**C-FLU-09** · **`S_max_slots < I_slots`.** Entonces `t_j < t_{j+1}` **estrictamente**, los `t_j`
son distintos dos a dos y están ordenados como las épocas. Corolario: **a lo sumo una inyección por
slot**, que es lo que `C-POT-01` exige del contexto.

> §7.3 ya la conserva «como condición suficiente del perfil propuesto, no como necesidad universal
> demostrada», y esta regla **no la eleva** a necesidad: demuestra que es suficiente para lo que se
> usa. Con épocas saltadas (`C-FLU-05`) el número de inyecciones realizadas puede ser menor que el
> de umbrales cruzados.
````

**De dónde sale:** `veritas/consenso/regla-flujo-v1/PROPUESTA-SPEC.md:443-882`.

**Qué se queda fuera:** las demostraciones de existencia, unicidad y buena fundamentación de
C-FLU-04; la prueba de la lotería única de C-FLU-07; las dos demostraciones de C-FLU-08 y la de
C-FLU-09; la corrección de atribución sobre la `X` de la auditoría; las cifras de `L_mín`; la tabla
(iii) de C-FLU-02 sobre qué toca en `crates/`; y la verificación de primera mano del `pot.rs` de
Autonomys. Todo en la carpeta migrada.

**Dudas:**

- **D-2 (C-FLU-01):** la propuesta escribe `L_slots ≥ máx(...)` en su §1 y `L_slots := máx(...)`
  en la decisión de la tercera tanda, que es **más estricta**. Escribo `:=`, que es lo decidido
  (`P-2.1/SINTESIS.md:102-104`). Lo señalo porque los dos signos conviven en el documento de
  origen.
- **D-3 (C-FLU-02):** la propuesta declara que confirmar su coste con ANCLA-v0.2 es **«condición
  para pasar al SPEC», no trabajo opcional**
  (`veritas/consenso/regla-flujo-v1/PROPUESTA-SPEC.md:2001-2003`). **Esa medición no existe.** El
  plan traslada la regla igualmente porque Katana decidió D-F6 = A sabiendo esto, y la anota en
  `TAREAS.md` §2.9 — pero **es una condición declarada y no cumplida**, y Katana debe verla.
- **D-4 (C-FLU-06):** `ETIQUETA_GENESIS := "ZZKFlowGenesis__"` y `ETIQUETA_FLUJO := "ZZKFlowId_______"`
  son **propuestas de nombre** del agente, no decisiones. El traslado puede cambiarlos sin tocar
  ninguna demostración. Van en E-34.

### E-19 … E-21 · `SPEC.md` · §7.1.4 nueva · `C-FLU-10`, `C-FLU-11`, `C-FLU-12`

**Texto actual:** no existe.

**Texto propuesto (literal):**

````markdown
#### 7.1.4 · El identificador de flujo y la entropía de la inyección

**C-FLU-10** · **Derivación del identificador de flujo.**

```text
flujo(B, s) := f_0                                                      si no hay inyección con t_j ≤ s
flujo(B, s) := H_flujo( flujo(B, t_j − 1) ‖ entropía_j(B) ‖ LE64(t_j) ) con j la última inyección con t_j ≤ s

H_flujo(m)  := H_d( ETIQUETA_FLUJO ‖ m ) = SHA3-256( ETIQUETA_FLUJO ‖ m )
```

El resultado son **32 bytes**. El primer argumento es `flujo(B, t_j − 1)` —«el valor vigente justo
antes de esta inyección»— y **MUST NOT** escribirse como `flujo(B, t_{j−1})`: con épocas saltadas
(`C-FLU-05`) `t_{j−1}` puede no existir. `t_j` entra como `LE64(t_j)`, codificación fija: una
concatenación de enteros sin longitud fija es ambigua por construcción.

> **Es acumulativo y es función exclusiva de `past(B)`, las dos cosas demostradas** en
> `veritas/consenso/regla-flujo-v1/PROPUESTA-SPEC.md:932-941`. Lo primero convierte la comparación
> de flujos en una comparación de 32 bytes. Lo segundo es lo que satisface la exigencia de C-HDR-06
> de que nada dependa del orden de llegada, del reloj local ni de la punta local.
>
> **Decidido por Katana el 2026-09-20 (D-F2 = A):** `H_d` con etiqueta nueva, no `blake3`. Las dos
> etiquetas nuevas se añaden a C-HASH-06 (§4.5).

**C-FLU-11** · **El flujo NUNCA se declara.** Ningún campo de la cabecera ni del cuerpo **MUST**
contener el identificador de flujo, ni ningún valor del que se derive. El flujo de un bloque lo
calcula el verificador a partir de `past(B)`, y **MUST NOT** existir vía alguna que acepte un valor
del candidato como si fuese el esperado: **la circularidad MUST ser imposible, no desaconsejada**.

`C-FLU-10` **es** la definición de `flow(B, slot(B))` que C-HDR-06 usa sin definir:
`flow(B, slot(B)) := flujo(B, slot(B))`. Como el flujo es función exclusiva de `past(B)`, la
exigencia de C-HDR-06 de que el rango esperado sea función **exclusiva** de ese pasado queda
satisfecha por composición, **sin añadir ninguna dependencia nueva**.

**C-FLU-12** · **Entropía de la inyección.**

```text
entropía_j(B) := blake3( chunk(I_j(B)) ‖ pot_output(I_j(B)) )
```

y se entrega a `C-POT-01` como la entrada `entropía(f, t_j)`. Los dos ingredientes son campos de
**cabecera** de `I_j(B)`: `sol.chunk` en `[252,284)` y `pot_output` en `[88,104)` (C-HDR-01).

**Invariante de no-equivocación del inyector.** **Dos copias del mismo billete MUST producir la
misma entropía y el mismo `t_j`.** Cualquier cambio futuro que meta en la entropía un campo
**moldeable por el constructor del bloque** —el hash del bloque, el `timestamp`, el conjunto de
padres, la raíz de Merkle— **reabre el grinding de la entropía por contenido del bloque**, hoy
cerrado, y **MUST NOT** hacerse sin rehacer ese análisis.

> **Decidido por Katana el 2026-09-20 (D-F1 = A).** El motivo que más pesa no es criptográfico:
> es **no atar §2.1 a la identidad del billete (§7.2), que además puede cambiar** si algún día se
> adopta un registro de parcelas contra el sembrador.
>
> **El coste de A queda escrito:** dos billetes distintos con el mismo `chunk` en el mismo slot y
> flujo dan la misma entropía. La entropía no distingue **quién** ancló, solo **qué chunk** ganó.
> No se ha encontrado un ataque por esa vía, **y no encontrarlo no es cerrarlo**.
>
> **Aviso para quien valide:** con `pot_output` = salida **futura** (D-2 = A), la entropía se deriva
> de `salida(f, slot(I_j) + D)`. El invariante se conserva —ambas son función de `(f, slot)` y de
> nada más—, pero **la aritmética del adelanto no se ha rehecho con `+D`**: `TAREAS.md` §2.9.
````

**De dónde sale:** `veritas/consenso/regla-flujo-v1/PROPUESTA-SPEC.md:886-1032`.

**Qué se queda fuera:** la demostración de la acumulatividad y de la dependencia exclusiva de
`past(B)`; la demostración del invariante bajo D-F1 = A; la comparación con D-1 y por qué el
argumento que ganó D-1 no aplica aquí; y las citas a `P-SEMBRADOR/investigacion/INFORME.md`.

**Dudas:**

- **D-5 (C-FLU-10):** el SPEC hereda hoy el nombre `flow` en C-HDR-06 (`SPEC.md:887`) y el código
  usa `flujo` (`crates/zx-core/src/wire_dag.rs:356-357`). El plan **fija `flujo`** y hace que
  C-HDR-06 lo use (E-36). Es un cambio de nombre en una regla existente; si Katana prefiere
  conservar `flow` en el SPEC, hay que invertir E-36 y este párrafo.
- **D-6 (C-FLU-11):** la regla dice «ningún campo… **MUST** contener» donde el sentido es
  **MUST NOT**. Es literal de la propuesta (`:945-946`). **Lo escribo en el SPEC como `MUST NOT`,
  que es lo que la regla significa**, y lo declaro aquí en vez de arreglarlo en silencio. El mismo
  giro aparece en C-HDR-06 vigente (`SPEC.md:896`, «Ninguna implementación **MUST** ofrecer…»), así
  que es un defecto de redacción **ya presente en el SPEC** y no una invención de la propuesta.
- **D-7 (C-FLU-12):** la propuesta numera el invariante como **`C-FLU-12.1`**. En el SPEC **no
  puede** ser un ID de línea: `ci/citas-spec.sh:54` extrae con
  `^\*\*\K[A-Z]+-[A-Z]+-[0-9]+[a-z]?`, y `**C-FLU-12.1**` se leería como `C-FLU-12` duplicado. Va
  como **cláusula dentro de C-FLU-12**, con su texto íntegro. Si Katana quiere que sea regla
  propia, el ID libre sería `C-FLU-24`.

### E-22, E-23, E-28, E-29 · `SPEC.md` · §7.1.5 nueva · `C-FLU-13`, `C-FLU-14`, `C-FLU-20`, `C-FLU-21`

**Texto actual:** no existe.

**Texto propuesto (literal):**

````markdown
#### 7.1.5 · Validez absoluta y pasado consistente de flujo

**C-FLU-13** · **Validez absoluta.** `B` es **válido** si y solo si: (1) su solución PoAS verifica
bajo `reto(flujo(B, slot(B)), slot(B))`; (2) su justificación de PoT cubre el rango exigido por
C-HDR-07 **bajo ese mismo flujo**; (3) todos los bloques de `past(B)` son válidos; (4) cumple
`C-FLU-14`.

La validez de `B` **MUST NOT** depender de la cadena seleccionada del observador, de su punta, de
su reloj ni del orden de llegada. Es función de `past(B)` y de nada más.

> **Esta es la bifurcación de §2.1 y su precio se paga aquí, explícito.** Si la validez del PoT
> fuese **relativa a la cadena seleccionada**, se abriría el **multistream** —`α_mínimo = 1/(S+1)`,
> hasta 0,040 con `S ≈ 24`, medido en `veritas/seguridad/coste-rama-privada-v1/`—. Siendo
> **absoluta**, el multistream queda cerrado (un flujo fabricado por el atacante no es el flujo de
> ningún bloque honesto y sus bloques no se pueden referenciar, `C-FLU-14`) y lo que se abre es la
> **partición de flujo** (§7.1.6). **Lo que la contiene no es una regla: es `L_slots` frente a `Δ`**,
> con la probabilidad medida en simulación en `veritas/consenso/ancla-inyeccion-v2/` y la `Δ`
> **simulada, no medida en red**.

**C-FLU-14** · **Pasado consistente de flujo.**

```text
Para todo X ∈ past(B):   flujo(X, slot(X)) == flujo(B, slot(X))
```

Un bloque **MUST NOT** referenciar un bloque de otro flujo. La comprobación es **estructural** y va
**antes** de tocar ningún PoT (paso 1b de `C-POT-08`). Si el nodo no tiene todo `past(B)` el estado
es **`Pendiente` por contexto incompleto, nunca `Inválido`**.

> **No necesita AES, y está demostrado:** los ingredientes de `flujo(·)` son una constante, dos
> campos de cabecera por ancla, los `slot(I_j)` y el orden GHOSTDAG restringido a `V_j`. **Ninguno
> exige evaluar la cadena AES.** Lo que **sí** cuesta es recomputar cadena y flujo del sub-DAG
> ajeno, que es superficie de DoS: por eso el paso 1b va bajo el presupuesto de `C-NET-33`.

**C-FLU-20** · **Qué hace el productor con un bloque tardío que cambiaría un ancla ya activada.**
Al construir un bloque `B`, el productor **MUST** descartar de su cola de candidatos (C-GD-10) toda
punta cuya inclusión cambiaría `entropía_j` o `t_j` de **alguna época `j` ya activada en el pasado
de `B`** —es decir, con `t_j ≤ slot(X)` para algún `X ∈ past(B)`—. Un productor **MUST NOT** emitir
un bloque inválido por una elección de padres que él mismo controla.

Es **política de producción**, no verificación: un verificador no rechaza por el conjunto de
padres, rechaza por `C-FLU-14`, que es validez objetiva.

> **Consecuencia, y hay que decirla así: ese bloque queda INFUSIONABLE PARA SIEMPRE en ese flujo.**
> Como el pasado solo crece, ningún descendiente futuro podrá fusionarlo si hacerlo cambiaría `I_j`.
> **No hay caducidad ni ventana de rescate.** Normalmente paga el atacante, que es quien retiene;
> **el colateral honesto no está medido** (`TAREAS.md` §2.9).
>
> ⚠️ **Esta política MUST NOT extenderse al intervalo anterior a `t_j`.** Antes de `t_j` fusionar es
> legal, así que la política no se apoyaría en ninguna invalidez: sería un «lo primero que vi
> manda» y **haría el flujo dependiente del orden de llegada de los mensajes**, que es exactamente
> el defecto que la ronda 10a tuvo que retirar. **Solo actúa después de la activación.**

**C-FLU-21** · **La inyección ya activada se hereda, no se recalcula.** Si `past(B)` contiene algún
bloque `X` con `t_j ≤ slot(X)`, la inyección `j` de `B` —su `entropía_j` y su `t_j`— **MUST** ser la
de `X` y **MUST NOT** recalcularse a partir de `V_j(B)`. `I_j` solo se calcula con `C-FLU-04`
cuando ningún bloque del pasado la tiene activada.

> **No cambia qué bloques son válidos: la vuelve constructiva.** El verificador deja de recalcular
> `Chn(V_j(B))` por bloque y la hereda; el ancla se calcula **una vez por época y se transporta**.
> Se escribe aunque sea redundante porque, sin ella, dos implementaciones pueden calcular lo mismo
> por caminos distintos y discrepar en un borde que nadie ha enumerado.
>
> **Decidido por Katana el 2026-09-20 (D-F8 = C): la vista NO se congela.** Congelarla reabriría
> **E1** —el ancla dependiendo de la cadena, la cadena de la validez, la validez del ancla— en una
> franja de anchura `≤ S_max_slots`, y compraba muy poco: adelantar la congelación 150 slots
> nominales sobre una carrera que dura `L_slots ≥ F_slots`. **Esto no arregla nada de la carrera
> anterior a `t_j`.**
````

**De dónde sale:** `veritas/consenso/regla-flujo-v1/PROPUESTA-SPEC.md:1036-1207`.

**Qué se queda fuera:** la demostración de que C-FLU-14 no necesita AES; la demostración de que el
bloque tardío es infusionable; la demostración de equivalencia de C-FLU-21 con C-FLU-14; y el
análisis completo de por qué congelar reabre E1.

**Dudas:** ninguna propia.

### E-24, E-27, E-30 · `SPEC.md` · §7.1.6 nueva · `C-FLU-15`, `C-FLU-22`, `C-FLU-18`

**Texto actual:** no existe.

**Texto propuesto (literal):**

````markdown
#### 7.1.6 · Partición de flujo: estatuto, adopción y nodo sin cadena

> **Leer esto antes que las tres reglas.** **Ningún texto derivado de esta sección debe decir «las
> particiones de flujo se curan», ni tampoco «no tienen cura». Las dos son falsas: depende de cómo
> nació la partición.** `C-FLU-22` cura el nacimiento **espontáneo** —por latencia—, que es el
> improbable. **No cura** el nacimiento realista, un corte de red más largo que `L_slots`, donde la
> ventana es **vacía desde el propio `t_j`** y la partición es **permanente**. El diseño es, sobre
> todo, **prevención** —`L_slots` frente a `Δ`, con el suelo de `C-FLU-01`—; la recuperación es un
> añadido real pero acotado, **no una garantía de reconciliación**.

**C-FLU-15** · **Una partición de flujo tiene el estatuto de un fallo de finalidad.** Una partición
de flujo **se trata como** una violación de finalidad: es un fallo del modelo de seguridad, no un
estado que el protocolo gestione.

> **«Se trata como», no «es».** Escribirlo como equivalencia causal sería **falso**: existe una
> partición de flujo que nace **sin** violar ninguna regla de finalidad
> (`veritas/consenso/regla-flujo-v1/PROPUESTA-SPEC.md:248-294`, refutación demostrada). Lo que sí
> es cierto y está demostrado: **si la partición nace, la finalidad es lo que impide curarla** fuera
> de la ventana de `C-FLU-22`.
>
> **Producir en un flujo no seleccionado no se puede prohibir criptográficamente**, y el motivo es
> más fuerte que una laguna: «cualquier mecanismo de exclusividad entre relojes en PoAS
> permisionless es derrotable por partición de identidad, porque el coste de producir espacio es
> lineal en bytes e independiente de cuántas identidades lo reclamen, y las identidades son gratis
> por diseño» (`research/dag-poas-balizas-auditoria.md:68-75`). Lo que el diseño **sí** hace es
> dejarlo **sin valor económico**, y no hace falta regla nueva: `C-FLU-14` impide referenciar esos
> bloques desde el flujo ganador, luego su coinbase nunca entra en la historia seleccionada.

**C-FLU-22** · **Adopción del flujo rival dentro de la ventana, con presupuesto.**

```text
Adoptar = seleccionar. Una rama de otro flujo es VÁLIDA en términos absolutos (C-FLU-13):
NO se puede FUSIONAR (C-FLU-14) pero SÍ se puede SELECCIONAR.

d(t) := slot(punta seleccionada actual) − slot(P),  con P el ÚLTIMO ANCESTRO COMÚN
        de la cadena actual y la rama candidata.
```

Un nodo **MUST** elegir entre ramas válidas por la selección ordinaria de GHOSTDAG (mayor
`blue_work`; desempates de C-GD-03), **sin excepción por flujo**, limitada por `C-FIN-01`: solo
mientras `d < F_slots`.

Orden y coste, que **MUST** respetarse:

1. La comprobación estructural del flujo va **siempre primero** (paso 1b de `C-POT-08`). **Sin AES.**
2. El PoT del flujo rival se verifica **solo si hace falta para adoptar**: solo si la rama rival va
   **por delante** en `blue_work` y `d < F_slots`. Si no, **no se verifica nada**: la punta se
   ignora (`C-FIN-01`).
3. Todo ello **bajo los dos presupuestos de `C-NET-33`**. Agotarlos da **`Pendiente`, nunca
   `Inválido`**.
4. **Sin validez comprobada no se adopta.** `Pendiente` **MUST NOT** contar como válido ni como
   inválido: el nodo se queda donde está y reintenta.

> **La congelación es simultánea.** El instante de cierre es `slot(P) + F_slots`, **función
> exclusiva de `P`**: no depende de cuándo cada nodo se enteró de la rama rival, ni de su reloj, ni
> del orden de llegada. Todos los nodos **con cadena** cruzan el umbral en el mismo índice de slot.
>
> **La anchura de la ventana depende de cómo nació la partición**, y esto es lo que hay que leer:
>
> | Nacimiento | `slot(P)` | Ventana |
> |---|---|---|
> | **Espontáneo** (latencia) | `t_j − 1` | **máxima**, `F_slots − 1` |
> | Corte de red que empezó en `s₀` | `s₀` | `[t_j, s₀ + F_slots)` |
> | **Corte de red más largo que `L`** | `≤ t_j − L_slots` | **VACÍA** |
>
> **Riesgo residual, con su alcance declarado.** Aun con congelación simultánea quedan dos rendijas
> medidas en `veritas/consenso/puerta-cobertura-v1/` (PCO-v0.1): el **desfase de vista** en el
> instante de congelación, que va como `√(τ/F)` —**condicionado a que la partición haya nacido y a
> reparto simétrico**—, y **el nodo que sincroniza después**, que toma el líder del momento. El
> segundo **no lo cierra esta regla**: lo gobiernan `C-FLU-18` y `C-FLU-17`. `C-NET-33` añade una
> **tercera, no medida** y parcialmente bajo control del atacante.
>
> **R-FIN-5 cambia de motivo, y la frase exacta importa.** Deja de ser cierto a la letra que «un
> nodo honesto **jamás** verifica el PoT de un flujo ajeno». Lo cierto es: **nunca lo verifica para
> FUSIONAR** —C-FLU-14 es estructural y no toca AES—; **solo lo verifica para ADOPTAR**, dentro de
> esta ventana y bajo presupuesto. La virtud que se conserva es la que importaba: **el camino
> normal nunca paga AES ajeno**.
>
> **Forzar ese gasto no es barato, y está demostrado** en
> `veritas/consenso/regla-flujo-v1/PROPUESTA-SPEC.md:1373-1425`: exige ganar una carrera de
> `blue_work` de longitud `L_slots`. La demostración **usa `L_slots ≥ F_slots`**, así que es un
> argumento a favor del perfil 1a, independiente de los demás. **La cola de esa carrera no está
> medida** (`TAREAS.md` §2.9).

**C-FLU-18** · **El nodo sin cadena previa aplica la selección ordinaria.** Un nodo sin cadena
previa selecciona la rama de **mayor `blue_work`** por las reglas C-GD vigentes, **sin excepción por
flujo**. `C-FIN-01` obliga **únicamente** a quien ya tiene una cadena seleccionada que reorganizar;
**no impone nada a quien no tiene ninguna**.

> **No es un mecanismo nuevo: es cerrar un hueco de redacción**, y sin escribirlo dos clientes
> pueden implementarlo distinto, que es la clase de fork latente que el Nivel 1 de `TAREAS.md`
> persigue.
>
> **Qué lo acota, y qué no.** En el arranque, C-CHK-01…C-CHK-07 fijan la rama canónica —pero son
> **uno solo** en la vida de la cadena y **caducan** en `ALTURA_CADUCIDAD`—. A largo alcance, lo
> acota la secuencialidad del PoT (`C-POT-03`). **Lo que NO acota:** después de `ALTURA_CADUCIDAD`
> y con una partición viva, un nodo nuevo va al flujo más pesado **del momento**, que puede ser el
> minoritario. **C-FLU-18 hace la conducta determinista y única; no la hace acertada.**
````

**De dónde sale:** `veritas/consenso/regla-flujo-v1/PROPUESTA-SPEC.md:1211-1282, 1284-1449,
1513-1552`.

**Qué se queda fuera:** la demostración de la anchura de la ventana y de la simultaneidad; la
demostración completa del cierre del DoS con sus tres avisos; los porcentajes concretos del desfase
de vista (0,27 % / 0,75 % / 1,5 %), que se quedan en PCO-v0.1 y se citan sin repetirse; la
refutación de §0.3; y el análisis de C-CHK.

**Dudas:** ninguna propia. El orden de presentación —15, 22, 18— es deliberado: la declaración de
estatuto primero, la única cura después, y el caso que ninguna de las dos alcanza al final.

### E-25 · `SPEC.md` · §7.1.7 nueva · `C-FLU-16`

**Texto actual:** no existe.

**Texto propuesto (literal):**

````markdown
#### 7.1.7 · El calendario de `N(s)`

**C-FLU-16** · **`N(s)` cambia exactamente en `t_j`.** Cualquier cambio de `N(s)` **MUST**
aplicarse en el mismo slot `t_j` en que se aplica la entropía de la inyección `j`, y **en ningún
otro**. Entre dos activaciones, `N(s)` es constante.

> **Por qué es regla y no coincidencia.** `N(s)` entra en la clave de caché de `C-POT-07`. Si
> pudiera cambiar en un slot distinto de `t_j`, habría **dos** puntos de discontinuidad por época
> en vez de uno, y la clave tendría que rastrear un calendario propio. Con esta regla el calendario
> de `N` es **el mismo objeto** que el de las inyecciones, que `C-FLU-09` deja bien ordenado y con
> a lo sumo un cambio por slot.
>
> **Quién autoriza un cambio de `N(s)`, su valor inicial, sus límites y su anuncio siguen
> `<<PENDIENTE>>`** (§7.3). El `ensure_root` del actualizador de Autonomys **no se adopta** como
> autoridad de ZEROX. Esta regla fija **cuándo** se aplica, no **quién** lo decide.
````

**De dónde sale:** `veritas/consenso/regla-flujo-v1/PROPUESTA-SPEC.md:1600-1630`.

**Dudas:** ninguna.

### E-26 · `SPEC.md:+§14.3` · `C-FLU-17` — **NO es regla de consenso**

**Texto actual:** no existe. Se inserta en §14.3 «Comportamiento del nodo», tras `C-UPG-08`
(`SPEC.md:2156-2158`).

**Texto propuesto (literal):**

````markdown
**C-FLU-17 · El nodo detecta que ha quedado fuera del flujo mayoritario y lo señala.**

> **Esto NO es una regla de consenso.** No cambia la validez de ningún bloque. Existe para que un
> nodo no siga funcionando **en silencio** dentro de un flujo minoritario.

Un nodo **MUST** señalar el estado «flujo posiblemente minoritario» cuando, **de forma sostenida**,
exista una punta `P` conocida con `flujo(P, slot(P)) ≠ flujo(mi punta, slot(mi punta))`,
`blue_work(P) > blue_work(mi punta seleccionada)`, y que `C-FIN-01` le obligue a ignorar.

La señal **MUST** exigir persistencia durante una ventana y **MUST NOT** dispararse con una sola
observación: una punta rival más pesada puede ser transitoria o fabricada.
`<<PENDIENTE: la ventana de persistencia y el margen de `blue_work`>>` — es calibración, y ninguna
implementación puede fijarla por su cuenta (§0.3).

El trabajo de calcular `blue_work` de una punta ajena **MUST** caer dentro del presupuesto de
`C-NET-33`, y agotarlo **MUST** dejar la señal como «no determinada», **nunca** como «estoy en el
mayoritario».

Qué hace el nodo con la señal: **nada automático**. La expone —registro, métrica, estado
consultable— y **MAY** dejar de producir bloques si el operador lo ha configurado así.

> **Es computable con lo que el nodo ya calcula y sin AES:** el flujo de `P` sale del paso 1b de
> `C-POT-08`, y `blue_work` es lo que GHOSTDAG ya produce. **La señal existe precisamente porque el
> protocolo no puede hacer nada más**: cambiar de flujo fuera de la ventana de `C-FLU-22` es lo que
> `C-FIN-01` prohíbe.
````

**De dónde sale:** `veritas/consenso/regla-flujo-v1/PROPUESTA-SPEC.md:1554-1596`.

**Dudas:**

- **D-8 — dónde vive.** La propuesta dice «con las reglas de comportamiento de nodo (§14.3 / §16),
  **no** en §7 ni §11. Si se traslada a una sección de consenso, deja de ser lo que es»
  (`:1593-1594`). §14.3 es la única sección del SPEC llamada «Comportamiento del nodo», y es donde
  la propongo. **Pero §14.3 cuelga de «§14 · Activación de cambios de consenso» y hoy solo tiene
  reglas `C-UPG` sobre hard forks: el encaje temático es malo.** La alternativa es una §16.7 nueva.
  **Recomiendo §14.3** —crear una sección para una sola regla no operativa es peor—, pero decide
  Katana.
- **D-9 — la regla se contradice con `C-FLU-22`, y no lo resuelvo.** El texto de origen dice:
  «**no es una regla de adopción** (DF-2 sigue intacta: el nodo **MUST NOT** cambiar de flujo por
  este indicador)» y, más abajo, «Cambiar de flujo por su cuenta … sería **imposible** bajo 1a: la
  reorganización necesaria está prohibida desde `t_j`» (`:1556-1559, 1589-1592`). **Las dos frases
  son de la revisión 2 y quedaron superadas por `C-FLU-22` (D-F9 = C), que sí permite adoptar
  dentro de la ventana.** En el texto propuesto arriba **he retirado las dos frases** y he escrito
  la versión compatible («cambiar de flujo fuera de la ventana de `C-FLU-22` es lo que `C-FIN-01`
  prohíbe»). **Es un cambio de fondo respecto a la letra de la propuesta y por eso está aquí y no
  en una nota:** si Katana prefiere otra redacción, este párrafo es el que hay que cambiar.

### E-31 · `SPEC.md:+§12`, tras `C-REORG-07` (línea 1903) · `C-FIN-01` — familia `C-FIN` nueva

**Texto actual:** no existe.

**Texto propuesto (literal):**

````markdown
**C-FIN-01 · Finalidad en índices de slot, sin `exit`.**

```text
Sea d = slot(punta actual) − slot(último ancestro común con la punta candidata),
en índices de slot de PoT (C-FLU-01).

Un nodo MUST NOT sustituir su cadena seleccionada por una candidata con d ≥ F_slots.
Una punta que lo exigiera se IGNORA.
El nodo MUST seguir operando: MUST NOT detenerse, MUST NOT abortar y MUST NOT exigir
intervención del operador por este motivo.
```

`F_slots` es un **SÍMBOLO**. Esta regla no le da valor: `<<PENDIENTE: §7.3>>`.

`C-FIN-01` obliga **únicamente** a quien ya tiene una cadena seleccionada que reorganizar
(`C-FLU-18`). La adopción dentro de la ventana que esta desigualdad deja abierta es `C-FLU-22`.

> **De dónde sale cada pieza.** El enunciado es el de R-FIN-7 (evidencia histórica,
> `research/dag-poas-ancla-de-orden.md:301-303`), con tres precisiones que R-FIN-7 no tenía: la
> magnitud es el **índice de slot** y no «segundos de slot»; **la desigualdad es explícita** —
> profundidad **exactamente** `F_slots` cae **dentro** de lo prohibido, que es la lectura
> conservadora (Katana, D-F4 = A) —; y el «nunca apaga el proceso» pasa de nota a **MUST NOT**
> enumerado, porque es precisamente lo que la diferencia del comportamiento vigente del código.
>
> **Por qué en slots y no en bloques.** `C-REORG-07` cuenta **bloques**; toda la regla de flujo
> cuenta **slots**. Convertir una en otra exige `λ`, que es una magnitud **estimada por el
> retarget**, no una constante de consenso. **Una regla de finalidad medida en bloques no se puede
> comparar con una profundidad medida en slots sin meter `λ` en el consenso.**
>
> **Relación con `C-REORG-07`: se declara, no se resuelve.** `C-REORG-07` sigue siendo
> **transitoria** y esta regla **no la toca**. Por alcance decidido (D-F3 = C, acotada al
> enunciado) **NO entran aquí**: la reconciliación con el código que hoy **se detiene**, la
> relación con `COINBASE_MATURITY` —de la que `MAX_REORG_LENGTH = 11 999` deriva— y el techo de
> archivado. Los tres están nombrados en `TAREAS.md` §2.9.
>
> ⚠️ **Dos reglas de profundidad conviven en este documento y dicen cosas distintas.** La que rige
> el diseño destino es **ésta**; `C-REORG-07` es **transitoria** y describe lo que el código hace
> hoy, no lo que el protocolo manda. **La reconciliación sigue pendiente** y está pedida en §13 y
> nombrada en `TAREAS.md` §2.9.
````

**De dónde sale:** `veritas/consenso/regla-flujo-v1/PROPUESTA-SPEC.md:1777-1828`; la decisión de
familia, **D-F7 = B** (`veritas/consenso/regla-flujo-v1/DECISIONES-PENDIENTES.md:438-452`).

**Qué se queda fuera:** la tabla comparativa R-FIN-7 / C-REORG-07, el cálculo de por qué la
elección cambiaba la conclusión (c) y el registro de opciones de D-F3.

**Dudas — D-10:** el SPEC dice hoy, en `C-REORG-07`, que «**No se publican ambas reglas como
simultáneamente activas**» (`SPEC.md:1903`). Con E-31 y E-40 el SPEC **publica las dos**: una
transitoria y declarada como tal, y una destino. **La frase deja de ser cierta a la letra.** E-40
la reescribe para que diga lo que va a ser verdad; lo señalo porque es exactamente el tipo de
contradicción que §13 manda evitar y quiero que Katana vea la redacción concreta.

### E-32 · `SPEC.md:+§16.6`, tras `C-NET-32` (línea 3009) · `C-NET-33` — era `C-FLU-23`

**Texto actual:** no existe.

**Texto propuesto (literal):**

````markdown
**C-NET-33 · Presupuesto de verificación de flujo ajeno: dos cotas, y qué pasa al agotarlas.**

El trabajo que un nodo dedica a ramas de **otro flujo** —la comprobación estructural del paso 1b de
`C-POT-08` y la verificación de PoT de `C-FLU-22`— **MUST** estar acotado por **dos** presupuestos
a la vez:

```text
PRESUP_PAR    por par y por intervalo     (es el de C-NET-32.3)
PRESUP_NODO   por NODO y por intervalo    (nuevo)
```

Agotar **cualquiera** de los dos produce **`Pendiente`, NUNCA `Inválido`**. Con `Pendiente` el nodo:

- **MUST** conservar su cadena seleccionada actual — no adopta;
- **MUST NOT** tratar la rama como inválida;
- **MUST NOT** dejar de reenviarla por este motivo;
- **MUST** reintentar cuando vuelva a tener presupuesto, mientras la ventana de `C-FLU-22` siga
  abierta.

`<<PENDIENTE: los valores de PRESUP_PAR y PRESUP_NODO>>`. Ninguna implementación puede fijarlos por
su cuenta (§0.3).

> **Por qué hacía falta la segunda cota.** C-NET-32.3 acota «por par y por intervalo», y **las
> identidades son gratis por diseño** (`research/dag-poas-balizas-auditoria.md:68-75`): un atacante
> con `N` conexiones obtiene `N` presupuestos, así que el techo de trabajo por nodo **lo fija él**.
> Con `PRESUP_NODO` el techo **deja de depender de `N`**, que es el criterio declarado de C-NET-06.
> Esto **no** abarata ni encarece el **disparo** del AES ajeno —que sigue exigiendo ganar la
> carrera de `C-FLU-22`—; lo que acota es el **techo**.
>
> **Por qué el modo de fallo se escribe entero.** Bajo `C-FLU-22`, «no adoptar» **ya no es neutro**:
> quedarse sin presupuesto durante la ventana significa quedarse en el flujo en el que se está, y
> cuando la ventana se cierra, **quedarse ahí para siempre**. De ahí las cuatro obligaciones, y en
> particular **seguir reenviando**: un nodo sin presupuesto no debe convertirse además en
> amplificador de la partición cortando la propagación a sus pares.
>
> ⚠️ **Esto abre una rendija más, y no está medida.** Dos nodos **con el mismo DAG** pueden acabar
> en flujos distintos porque uno pudo pagar la verificación dentro de la ventana y el otro no. Es
> la **tercera** rendija, además de las dos de PCO-v0.1, y **a diferencia de aquellas está
> parcialmente bajo control del atacante**, que puede gastar presupuesto ajeno con tráfico barato
> del paso 1b. La **validez** no se mueve —sigue siendo función de `past(B)`—; lo que se mueve es la
> **selección**, que bajo `C-FLU-22` decide el flujo. `TAREAS.md` §2.9.
>
> **La calibración es una pinza, no un número suelto.** Por abajo, integrado sobre la ventana,
> `PRESUP_NODO` **MUST** bastar para verificar **una** rama rival completa —en el peor caso
> `F_slots` slots, del orden de `F_slots × 92 ms` con los costes de §16.6—; con menos, la adopción
> **nunca** se completa y **D-F9 quedaría derogada de hecho sin que nadie la revocara**. Por
> arriba, demasiado grande devuelve el DoS que la segunda cota existe para acotar. **La cota
> superior no está derivada.** `TAREAS.md` §2.9.
````

**De dónde sale:** `veritas/consenso/regla-flujo-v1/PROPUESTA-SPEC.md:1451-1511` (allí numerada
`C-FLU-23`), con **D-F10 = B** decidida por Katana el 2026-09-20.

**Dudas — D-11:** el ID. La propia propuesta señala, **sin abrir decisión**, que el traslado
debería numerarla en `C-NET` «por el mismo criterio que Katana fijó en D-F7» (`:1504-1511`).
Propongo **`C-NET-33`**, el siguiente libre (`C-NET-10` está retirada con tombstone y no se
reutiliza). La alternativa que la propuesta menciona —«un tercer punto de C-NET-32»— **no la
recomiendo**: el modo de fallo ocupa cuatro obligaciones y una pinza de calibración, y enterrarlo
dentro de otra regla lo haría invisible a `ci/citas-spec.sh`, que cuenta por ID.

---

## 4 · Detalle de las ediciones — reglas y secciones existentes que cambian

### E-33 · `SPEC.md:28-37` · §0.2, tabla de áreas

**Texto actual (literal):**

```markdown
| Prefijo | Área |
|---|---|
| `C-ENC` | Codificación y serialización canónica |
| `C-HASH` | Funciones hash y separación de dominio |
| `C-HDR` | Cabecera de bloque |
| `C-TX` | Formato y validez de transacción |
| `C-SIG` | Firmas |
| `C-TS` | Timestamps |
| `C-EMIT` | Emisión y coinbase |
| `C-BLK` | Validez de bloque |
```

**Texto propuesto (literal):** las mismas ocho filas, y al final tres nuevas:

```markdown
| `C-POT` | Proof-of-Time como primitiva y contrato del verificador |
| `C-FLU` | El flujo del PoT: ancla, época, identificador y partición |
| `C-FIN` | Finalidad: profundidad máxima de reorganización |
```

**De dónde sale:** encargo §Reglas 4 («IDs nuevos y estables»); `TAREAS.md` §4.2 obliga a registrar
las familias nuevas.

**Dudas — D-12:** **esta tabla ya está incompleta hoy.** Existen y no figuran: `C-GD`, `C-ORD`,
`C-NET`, `C-STORE`, `C-REORG`, `C-CHK`, `C-WIRE`, `C-SPEC`, `C-UPG`, `C-WGT`, `C-EXP`, `C-GEN`,
`C-SLOT` y `R-NET`. **Añadir tres y dejar catorce fuera es incoherente.** Dos salidas: (a) añadir
solo las tres, dejando la incoherencia como estaba; (b) completar la tabla entera. **Recomiendo
(b)** —es mecánico, no toca ninguna regla y cierra un desajuste real—, **pero está fuera del
alcance del encargo** y por eso no lo hago sin que Katana lo diga. **Por defecto aplicaré (a).**

### E-34 · `SPEC.md:560-584` · `C-HASH-06`, tabla de etiquetas de dominio

**Texto actual (literal), las dos líneas del enunciado y la última fila de la tabla:**

```markdown
**C-HASH-06** · Estas son **todas** las etiquetas de dominio de ZEROX v1.0. Cada una mide
exactamente 16 bytes.
```

```markdown
| `ZZKBlkBodyHash__` | §6.1 compromiso completo del cuerpo, efectos y autorización |
```

**Texto propuesto (literal):** el enunciado no cambia, y la tabla gana dos filas al final:

```markdown
| `ZZKFlowId_______` | §7.1.4 identificador de flujo del PoT (`C-FLU-10`) |
| `ZZKFlowGenesis__` | §7.1.3 flujo del génesis (`C-FLU-06`) |
```

**De dónde sale:** **D-F2 = A**, decidida por Katana el 2026-09-20
(`veritas/consenso/regla-flujo-v1/PROPUESTA-SPEC.md:918-931`). Las dos son ASCII puro de 16 bytes,
como todas menos la del txid.

**Nota que hay que dejar escrita:** la lista se declaraba **cerrada** («Estas son **todas** las
etiquetas de ZEROX v1.0»). **Sigue cerrada; lo que cambia es su contenido**, y cambia por una
decisión de Katana, no por conveniencia de una implementación. Los **nombres** son propuesta del
agente y **se pueden cambiar sin tocar ninguna demostración** (D-4).

### E-35 · `SPEC.md:879-881` · `C-HDR-05` — **cambia de semántica**

**Texto actual (literal):**

```markdown
**C-HDR-05** · En el diseño DAG A″, la relación de slot con el padre seleccionado es **no estricta**:
`slot(sp(B)) ≤ slot(B)` (R-FIN-1a). La igualdad no autoriza ciclos; la validación de ancestros,
flujo y justificación secuencial del PoT se integra conjuntamente. El génesis tiene `slot = 0`.
```

**Texto propuesto (literal):**

```markdown
**C-HDR-05** · En el diseño DAG A″, la cota de slot es **no estricta** y alcanza a **TODOS los
padres**, no solo al seleccionado: para todo bloque `B` y **todo** padre `p` de `B`,
`slot(p) ≤ slot(B)`. En particular `slot(sp(B)) ≤ slot(B)` (R-FIN-1a). La igualdad no autoriza
ciclos. El génesis tiene `slot = 0`.

Es la misma cota que `C-FLU-02`, y es materia de **validez**: sin ella el corte por slot de
`C-FLU-03` no es cerrado por ancestros y GHOSTDAG no está definido sobre él. Por eso `C-FLU-02`
entra también en la enumeración de `C-GD-10`.

> **Decidido por Katana el 2026-09-20 (D-F6 = A).** Hasta entonces el SPEC solo exigía la cota del
> padre seleccionado y **no determinaba** el slot de los demás padres. **El coste para el productor
> honesto está `estimado ≈ 0` y NO medido:** `TAREAS.md` §2.9.
>
> ⚠️ **El código va por detrás de esta regla.** `comprobar_diferencia_slots_del_bloque` recibe
> **solo** `slot_sp`, y `ContextoDag` no expone forma de pedir el `slot` de un padre arbitrario. No
> es solo código sin cablear: es **código de la versión anterior de la regla**, declarado en
> `ci/reglas-sin-cablear.txt`.
```

**De dónde sale:** `veritas/consenso/regla-flujo-v1/PROPUESTA-SPEC.md:547-609`, con la tabla (iii)
que enumera exactamente qué hay que tocar en `crates/` — que **no se toca** (encargo §Reglas 2).

**Dudas — D-13:** cómo se declara en `ci/`. Va en E-55.

### E-36 · `SPEC.md:883-899` · `C-HDR-06` — su `flow` queda definido

**Texto actual (literal), el bloque y el párrafo que importan:**

````markdown
```text
rango_esperado(B) = controlador(past(B), flow(B, slot(B)))
B.rango_solucion == rango_esperado(B)
```

El rango esperado **MUST** aportarlo el contexto del pasado DAG validado y del flujo; debe ser
función **exclusiva** de ese pasado.
````

**Texto propuesto (literal):**

````markdown
```text
rango_esperado(B) = controlador(past(B), flujo(B, slot(B)))
B.rango_solucion == rango_esperado(B)
```

`flujo(B, s)` es el identificador de flujo de `C-FLU-10`, que **MUST** derivarse del pasado y
**MUST NOT** declararse (`C-FLU-11`). Como `C-FLU-10` es función exclusiva de `past(B)`, la
exigencia de esta regla queda satisfecha **por composición, sin añadir ninguna dependencia nueva**.

El rango esperado **MUST** aportarlo el contexto del pasado DAG validado y del flujo; debe ser
función **exclusiva** de ese pasado.
````

**De dónde sale:** `veritas/consenso/regla-flujo-v1/PROPUESTA-SPEC.md:951-963`.

**Dudas — D-14:** hoy conviven `flow` (C-HDR-06) y `flujo` (`crates/zx-core/src/wire_dag.rs:356-357`,
`fn flujo(&self, slot: u64) -> [u8; 32]`). La propuesta pide «sustituir `flow` por `flujo` o fijar
uno de los dos nombres» (`:962-963`). **Fijo `flujo`**, porque es el que ya usa el código y el
resto del SPEC está en español. Es un cambio de nombre en una regla existente y por eso se declara.

### E-37 · `SPEC.md:907-928` · `C-HDR-07` — el `pot_output` es la salida futura

**Texto actual (literal), la frase que se amplía:**

```markdown
`0 ≤ pot_bundle_count ≤ 150` y la cota se comprueba **antes** de reservar. `d = 0` tiene lista
vacía canónica; el génesis usa cero portadores. Para un bloque no génesis, la validación
contextual **MUST** exigir `pot_bundle_count == slot(B) − slot(sp(B))` y rechazar underflow o
diferencia mayor de 150.
```

**Texto propuesto (literal):** el párrafo anterior se conserva íntegro y gana, a continuación:

```markdown
**Qué ancla la justificación, decidido por Katana el 2026-09-19 (D-2 = A).** El `pot_output` de la
cabecera es la salida **futura**, `salida(f, slot(B) + D)` (`C-POT-05`). Los `d` portadores cubren
el rango `(slot(sp(B)) + D, slot(B) + D]`, y el **último checkpoint del último portador MUST ser
igual a `pot_output(B)`**. La semilla del primer slot del rango la aporta el **contexto** desde el
pasado validado, **nunca el candidato** (`C-POT-06`). El orden interno de la verificación es el de
`C-POT-08`.
```

**De dónde sale:** `veritas/consenso/pot-primitiva-v1/PROPUESTA-SPEC.md:127-163`, D-2 = A.

**Dudas — D-1:** la misma corrección de `PROCEDENCIA.md` de E-06 (ver allí). Además, **C-HDR-07
también cambia de semántica sin que su código se mueva**, y por el mismo motivo que C-HDR-05: hoy
`verificar_justificacion_pot` devuelve `IntegracionPotPendiente` y nadie exige el anclaje. Va en
E-55.

### E-38 · `SPEC.md:1687-1689` · `C-GD-04`

**Texto actual (literal):**

```markdown
`k = 30`. Siguen vigentes `slot(sp(B)) ≤ slot(B)` (C-HDR-05) y `slot(B) − slot(sp(B)) ≤ S_max`.
```

**Texto propuesto (literal):**

```markdown
`k = 30`. Siguen vigentes la cota de slot de **todos** los padres, `slot(p) ≤ slot(B)` (C-HDR-05,
`C-FLU-02`), y `slot(B) − slot(sp(B)) ≤ S_max`.
```

**De dónde sale:** `veritas/consenso/regla-flujo-v1/PROPUESTA-SPEC.md:598-601`, que señala que
C-GD-04 «repite exactamente esa cota … también solo sobre `sp`».

**Dudas:** ninguna. Es alinear una repetición con su original.

### E-39 · `SPEC.md:1727-1734` · `C-GD-10`

**Texto actual (literal):**

```markdown
Además, el productor **MUST** descartar de la cola de candidatos toda punta cuya inclusión
produciría un bloque que viola **C-GD-11**. Un productor no puede emitir un bloque inválido por una
elección de padres que él mismo controla.

Esto es **política de producción**, no verificación: un verificador **MUST NOT** rechazar un bloque
por el conjunto de padres que eligió su autor mientras cumpla C-GD-04, C-GD-11 y C-HDR-05. C-GD-03
dice cómo se **elige el padre seleccionado entre unos padres dados**; esta dice **de dónde salen
esos padres**.
```

**Texto propuesto (literal):**

```markdown
Además, el productor **MUST** descartar de la cola de candidatos:

1. toda punta cuya inclusión produciría un bloque que viola **C-GD-11**;
2. toda punta con `slot` mayor que el del bloque que produce (**C-FLU-02**);
3. toda punta cuya inclusión cambiaría `entropía_j` o `t_j` de alguna época ya activada en el
   pasado del bloque (**C-FLU-20**).

Un productor no puede emitir un bloque inválido por una elección de padres que él mismo controla.
**El punto 3 MUST NOT extenderse al intervalo anterior a `t_j`**: allí fusionar es legal y la
política se convertiría en un «lo primero que vi manda» que haría el flujo dependiente del orden de
llegada (`C-FLU-20`).

Esto es **política de producción**, no verificación: un verificador **MUST NOT** rechazar un bloque
por el conjunto de padres que eligió su autor mientras cumpla C-GD-04, C-GD-11, C-HDR-05,
`C-FLU-02` y `C-FLU-14`. C-GD-03 dice cómo se **elige el padre seleccionado entre unos padres
dados**; esta dice **de dónde salen esos padres**.
```

**De dónde sale:** `veritas/consenso/regla-flujo-v1/PROPUESTA-SPEC.md:571-588` y `:1145-1150`.

**Nota que no se puede perder:** la enumeración final de C-GD-10 es **cerrada**, y por eso
`C-FLU-02` y `C-FLU-14` **tienen que** entrar en ella. Dejarlas fuera convertiría `C-FLU-02` en
política de producción en vez de validez, y entonces el corte por slot volvería a no ser cerrado
por ancestros — que es justo lo que `C-FLU-03` necesita.

**Dudas:** ninguna.

### E-40 · `SPEC.md:1897-1903` · `C-REORG-07` — sigue transitoria, solo gana una remisión

**Texto actual (literal):**

```markdown
Este valor se conserva para identificar el estado transitorio del código; no fija la finalidad
del consenso DAG. R-FIN-7 propone no reorganizar por debajo de `F` segundos del reloj de slot
e ignorar la punta incompatible, sin detener el proceso. Su integración está pendiente.

Una restricción de reorg protege el estado local, pero no demuestra por sí sola acuerdo entre
dos nodos aislados. Convertir 11 999 bloques a unas 3,33 h a tasa nominal no da un plazo
determinista. No se publican ambas reglas como simultáneamente activas.
```

**Texto propuesto (literal):**

```markdown
Este valor se conserva para identificar el estado transitorio del código; **no fija la finalidad
del consenso DAG**. La regla de finalidad del diseño DAG es **`C-FIN-01`**, escrita más abajo en
índices de slot y sin `exit`. **`C-REORG-07` sigue siendo transitoria y no se reconcilia aquí**:
la reconciliación con el código que hoy se detiene, con `COINBASE_MATURITY` —de la que
`MAX_REORG_LENGTH` deriva— y con el techo de archivado queda declarada pendiente (§13,
`TAREAS.md` §2.9).

Una restricción de reorg protege el estado local, pero no demuestra por sí sola acuerdo entre
dos nodos aislados. Convertir 11 999 bloques a unas 3,33 h a tasa nominal no da un plazo
determinista, y **convertir bloques en slots exigiría meter `λ` —una magnitud estimada por el
retarget— dentro del consenso** (`C-FIN-01`). **Mientras las dos convivan, la que rige el destino
es `C-FIN-01`; `C-REORG-07` describe lo que el código hace hoy, no lo que el protocolo manda.**
```

**De dónde sale:** encargo §1.2.2 («sigue transitoria; solo gana una remisión a `C-FIN-01`; no se
reconcilia») y `veritas/consenso/regla-flujo-v1/PROPUESTA-SPEC.md:1810-1828`.

**Dudas — D-10:** la frase «**No se publican ambas reglas como simultáneamente activas**» se
sustituye por la última del párrafo. **Es la edición más delicada del plan**: quitarla sin más
sería borrar una salvaguarda; conservarla literal sería publicar una falsedad, porque después de
E-31 el SPEC contiene las dos. La redacción propuesta dice cuál rige y cuál describe. **Si Katana
prefiere conservar la frase original, entonces C-FIN-01 no puede entrar hasta que C-REORG-07 se
retire — y eso es la reconciliación, que D-F3 dejó fuera de alcance.**

### E-41 · `SPEC.md:2976-2980` · `C-NET-31`

**Texto actual (literal):**

```markdown
**C-NET-31 · El PoT viaja en su propio tema y se verifica una vez por slot.** Las salidas de PoT
**MUST** propagarse por un tema de gossip propio, `/zerox/pot/1`, independiente de bloques y
transacciones. Cada nodo **MUST** verificar cada slot **una sola vez** y **MUST** cachear el
resultado; toda validación de bloque que cite ese slot **MUST** resolverse contra esa caché
(C-NET-06). Cada slot se verifica **entero**, lo que lo hace compatible con C-CHK-05.
```

**Texto propuesto (literal):**

```markdown
**C-NET-31 · El PoT viaja en su propio tema y se verifica una vez por clave de contexto.** Las
salidas de PoT **MUST** propagarse por un tema de gossip propio, `/zerox/pot/1`, independiente de
bloques y transacciones. Cada nodo **MUST** verificar cada slot **una sola vez por clave** y
**MUST** cachear el resultado; toda validación de bloque que cite ese slot **MUST** resolverse
contra esa caché (C-NET-06). Cada slot se verifica **entero**, lo que lo hace compatible con
C-CHK-05.

**La clave de la caché es la contextual de `C-POT-07`** —`(f, s, semilla(f, s), N(s))`, los cuatro
del contexto—, **no el slot a secas**. Con un único flujo candidato la clave es función de `s` y el
comportamiento es idéntico al de indexar por slot; con dos o más flujos, indexar por slot haría
depender la **validez** de qué llegó primero a la caché del nodo, que es lo que `C-POT-07` corrige.
```

**De dónde sale:** `veritas/consenso/pot-primitiva-v1/PROPUESTA-SPEC.md:225-275`.

**Dudas:** ninguna.

### E-42 · `SPEC.md:2997-3009` · `C-NET-32`

**Texto actual (literal):**

```markdown
1. **Comparar primero con la caché.** Si la salida no coincide con la ya verificada para ese slot, el
   bloque es **inválido** y se rechaza **sin gastar CPU** en la cadena AES.
2. **Retener, no verificar, lo que va por delante del reloj.** Los slots posteriores al reloj PoT del
   nodo **MUST** retenerse, no verificarse (`research/dag-poas-ancla-de-orden.md:342`).
3. **Presupuesto de CPU acotado**, por par y por intervalo, en el espíritu de C-NET-04.

`<<PENDIENTE: el valor del presupuesto de CPU por par e intervalo>>` — se calibra con el v2b (Q5),
que incluye agotar este presupuesto como vector de ataque. Ninguna implementación puede fijarlo por
su cuenta (§0.3).
```

**Texto propuesto (literal):**

```markdown
1. **Comparar primero con la caché, bajo la MISMA clave.** Si la salida no coincide con la ya
   verificada **para la misma clave contextual** (`C-POT-07`), el bloque es **inválido** y se
   rechaza **sin gastar CPU** en la cadena AES. **Discrepar con una entrada de OTRA clave no prueba
   nada** y **MUST NOT** invalidar: son cadenas de PoT distintas, ambas legítimas.
2. **Retener, no verificar, lo que va por delante del reloj.** Los slots posteriores al reloj PoT del
   nodo **MUST** retenerse, no verificarse (`research/dag-poas-ancla-de-orden.md:342`). El estado es
   `Pendiente`.
3. **Presupuesto de CPU acotado**, por par y por intervalo, en el espíritu de C-NET-04. **Para el
   trabajo sobre ramas de otro flujo hay además una cota global por nodo, y el modo de fallo está
   escrito: `C-NET-33`.** Agotar un presupuesto da **`Pendiente`, NUNCA `Inválido`** (`C-POT-07`).

`<<PENDIENTE: el valor del presupuesto de CPU por par e intervalo>>` — se calibra con el v2b (Q5),
que incluye agotar este presupuesto como vector de ataque. Ninguna implementación puede fijarlo por
su cuenta (§0.3).
```

**De dónde sale:** `veritas/consenso/pot-primitiva-v1/PROPUESTA-SPEC.md:225-275` (salvaguarda 1) y
**D-F10 = B** (salvaguarda 3).

**Dudas:** ninguna. El `<<PENDIENTE>>` de C-NET-32.3 se conserva **tal cual**; `C-NET-33` añade el
suyo para `PRESUP_NODO` y no toca éste.

### E-43 · `SPEC.md:1436-1438` · §7.3, el párrafo de `F` y `L`

**Texto actual (literal):**

```markdown
`F = 2 h` sigue provisional; no es la espera de Cortex ni se iguala por defecto a L. `L = 1 h`
es candidato condicionado, no adopción inequívoca. `I`, `L`, `ρ_max`, la configuración final
de `F` y la calibración frente a `Δ` siguen abiertos.
```

**Texto propuesto (literal):**

```markdown
`F = 2 h` sigue provisional, con obligación declarada de bajarla en producción; no es la espera de
Cortex. **`L` ha dejado de ser un parámetro libre:** desde el 2026-09-20 es una **definición**,
`L_slots := máx(F_slots, L_suelo_slots, S_max_slots + 1)` (`C-FLU-01`), con el perfil **1a**
decidido por Katana. El candidato `L = 1 h` queda **superado**: no se elige `L`, se deriva.

**Cuidado con la frase heredada «no se iguala por defecto a `L`»:** prohibía copiar `L` desde `F`
sin más, y `C-FLU-01` hace lo contrario en el sentido contrario —**deriva `L` de `F` con un
suelo**—. Las dos frases se parecen mucho y significan cosas distintas.

`I_slots`, `ρ_max`, `L_suelo_slots`, la configuración final de `F` y la calibración frente a `Δ`
siguen abiertos. **`L_suelo_slots` no se puede fijar hoy**: su criterio exige una cota de `Δ`
**medida en red real**, que no existe (`TAREAS.md` §3.1).
```

**De dónde sale:** tercera tanda de decisiones de Katana (`P-2.1/SINTESIS.md:102-104`) y
`veritas/consenso/regla-flujo-v1/PROPUESTA-SPEC.md:468-506`.

**Dudas:** ninguna. La lección de la nota está tomada literalmente de la propuesta, que pide que el
traslado la escriba «porque las dos frases se parecen mucho y significan cosas opuestas».

### E-44 · `SPEC.md:1449-1466` · §7.3, contrato de unidades

**Texto actual (literal), las dos viñetas que cambian:**

```markdown
- `slot(B)`, `I_slots`, `L_slots`, `S_max_slots` y `D_aut_slots` son índices o cantidades enteras
  de slots PoT. Con τ nominal de 1 s/slot, la referencia S_max se representa por 150 slots;
  limita `slot(B)−slot(sp(B))`, no el tiempo de retención ni Δ de red.
- `T_j=j·I_slots` es el umbral del inyector; `t_j=slot(I_j)+L_slots` es el índice de inyección.
  R-FIN-9 remite a ese inyector, no al contador obsoleto `c·j`. Origen/bootstrap, existencia del
  ancla, desempates y disponibilidad después de poda aún deben cerrarse. I separa umbrales,
  no necesariamente los instantes realizados de inyección.
```

**Texto propuesto (literal):**

```markdown
- `slot(B)`, `I_slots`, `L_slots`, `S_max_slots`, `F_slots`, `L_suelo_slots` y `D_aut_slots` son
  índices o cantidades enteras de slots PoT. Con τ nominal de 1 s/slot, la referencia S_max se
  representa por 150 slots; limita `slot(B)−slot(sp(B))`, no el tiempo de retención ni Δ de red.
  `F_slots := ⌈F / τ_nom⌉`, y **una comparación de consenso MUST NOT depender de `τ_nom` en tiempo
  de ejecución** (`C-FLU-01`). **La profundidad de una reorganización se mide en slots**,
  `slot(punta) − slot(último ancestro común)`, **nunca en bloques** (`C-FIN-01`).
- `L_slots := máx(F_slots, L_suelo_slots, S_max_slots + 1)` es **definición, no parámetro**
  (`C-FLU-01`). `L_suelo_slots` es parámetro de consenso y va como **símbolo**:
  `<<PENDIENTE: el valor de L_suelo_slots; su criterio exige una cota de Δ medida en red real>>`.
- `T_j=j·I_slots` es el umbral del inyector; `t_j=slot(I_j)+L_slots` es el índice de inyección
  (`C-FLU-01`, `C-FLU-07`). **El origen, la existencia y la unicidad del ancla quedan cerrados**
  en `C-FLU-04`, `C-FLU-05` y `C-FLU-06`; **la disponibilidad después de poda NO**, y sigue
  abierta. `I` separa umbrales, no necesariamente los instantes realizados de inyección
  (`C-FLU-05`: una época puede saltarse, y saltarla es definitivo).
```

**De dónde sale:** `veritas/consenso/regla-flujo-v1/PROPUESTA-SPEC.md:443-528` y `:633-729`.

**Dudas:** ninguna. La viñeta de `N(s)` no se toca aquí: su calendario lo fija `C-FLU-16` y su
autoridad sigue pendiente, que es lo que la viñeta ya dice.

### E-45 · `SPEC.md:3029` · §17, fila «Prueba de espacio/tiempo»

**Texto actual (literal), la parte que cambia — el final de la fila:**

```markdown
Es el ATAQUE 2 de `research/dag-poas-auditoria.md` (2026-09-06, gravedad crítica), que ya declaraba depender de «una regla que la propuesta no escribe» y advertía que **las dos opciones obvias fallan**: validez del PoT relativa a la cadena seleccionada abre el multistream; validez absoluta abre el split. Decisión de diseño pendiente. |
```

**Texto propuesto (literal):**

```markdown
Es el ATAQUE 2 de `research/dag-poas-auditoria.md` (2026-09-06, gravedad crítica), que ya declaraba depender de «una regla que la propuesta no escribe» y advertía que **las dos opciones obvias fallan**: validez del PoT relativa a la cadena seleccionada abre el multistream; validez absoluta abre el split. **DECIDIDO por Katana (2026-09-19/20) y REDACTADO en §7.1: validez ABSOLUTA (`C-FLU-13`), perfil 1a (`L_slots := máx(F_slots, L_suelo_slots, S_max_slots+1)`, `C-FLU-01`).** El multistream queda cerrado porque un flujo fabricado no es el de ningún bloque honesto y sus bloques no se pueden referenciar (`C-FLU-14`). **El split NO se cierra con una regla: se previene con `L` frente a `Δ`**, y si nace se cura solo en el caso espontáneo (`C-FLU-22`), nunca en un corte de red más largo que `L`. **Lo que queda: el código** —ninguna de las 31 reglas nuevas tiene una línea— y las mediciones que faltan (`TAREAS.md` §2.9). |
```

**De dónde sale:** encargo §1.2.2.

**Dudas:** ninguna.

### E-46 · `SPEC.md:3034` · §17, fila «Finalidad»

**Texto actual (literal):**

```markdown
| Finalidad | Integración R-FIN-7, elección conjunta de I/F/L/ρ_max, particiones y recuperación. |
```

**Texto propuesto (literal):**

```markdown
| Finalidad | **R-FIN-7 queda redactada como `C-FIN-01` (§12), en índices de slot y sin `exit`.** Lo que sigue abierto: la **reconciliación** con `C-REORG-07`, con el código que hoy se detiene, con `COINBASE_MATURITY` y con el techo de archivado (fuera de alcance por decisión, D-F3); la elección conjunta de `I`/`F`/`L_suelo`/`ρ_max`; y la **recuperación**, que `C-FLU-22` solo cubre para el nacimiento espontáneo de una partición de flujo. |
```

**De dónde sale:** D-F3 = C acotada al enunciado; `veritas/consenso/regla-flujo-v1/PROPUESTA-SPEC.md:1810-1828`.

**Dudas:** ninguna. El encargo no lo pedía explícitamente, pero dejar la fila diciendo «Integración
R-FIN-7» después de haberla integrado sería describir un pasado que ya pasó — el defecto que
`ci/reglas-sin-codigo.txt` existe para evitar en su eje.

---

## 5 · Detalle de las ediciones — `TAREAS.md`

### E-47 · `TAREAS.md:124-178` · §2.1 pasa a «cerrado en el SPEC, falta cablear»

**Texto actual (literal), el titular y las dos frases que el encargo manda corregir:**

```markdown
### 2.1 · Verificación conjunta PoAS/PoT (§7.1) — 🔴 AQUÍ ESTÁ EL PROBLEMA DE SEGURIDAD
```

```markdown
- **El único vector que baja el umbral es el multistream de PoT.** Cuota efectiva
  `S·α/(1−α+S·α)` ⟹ `α_mínimo = 1/(S+1)`:
```

```markdown
⚠️ **Y la misma auditoría avisa de que las dos salidas obvias fallan:** si la validez del PoT es
**relativa a la cadena seleccionada**, se abre el multistream; si es **absoluta**, se abre el split
de cadena (ATAQUE 1). **Es una decisión de diseño de Katana, no una regla que se pueda redactar sin
más.**
```

**Texto propuesto (literal):** el titular cambia y se inserta un bloque nuevo **inmediatamente
después del titular**, antes de todo lo que ya hay:

```markdown
### 2.1 · Dependencias por flujo del PoT (§7.1) — CERRADO EN EL SPEC (2026-09-20), FALTA CABLEAR

> **CORRECCIÓN DEL TITULAR, y hay que leerla antes que el resto de la sección.** Este apartado se
> tituló «🔴 AQUÍ ESTÁ EL PROBLEMA DE SEGURIDAD» porque `1/(S+1)` —el **4 %** con `S ≈ 24`— se leyó
> como el umbral del diseño. **No lo es.** `1/(S+1)` es la **regla aditiva** —`S` flujos
> independientes suman cuota— y **no aplica con pasado consistente de flujo**: bajo `C-FLU-14` un
> bloque no puede referenciar un bloque de otro flujo, así que los flujos del atacante no se
> agregan a una sola cadena. **El propio instrumento ya lo etiquetaba así**: CRP-v0.1 declaró su
> resultado «condicionado al diseño del flujo, no demostrado»
> (`veritas/seguridad/coste-rama-privada-v1/`). El umbral que CRP-v0.1 midió con **un solo flujo**
> es `α_mínimo = 1/2`, el mismo que PoW — **pero esa cifra no está cerrada: CRP-v0.2 declara
> «sustituye la evidencia protocolaria de CRP-v0.1» (baseline idealizado útil; veredicto
> protocolario INCONCLUSO), y ni v0.2 ni v0.3 están validadas ni migradas** (§2.9 (e)). **Lo que
> este cierre corrige es el titular del 4 %, y no lo sustituye por otro titular ancho.**
>
> **Lo que el multistream sí obligaba a decidir era la bifurcación**, y Katana la decidió: validez
> **absoluta** (`C-FLU-13`) con perfil **1a**. Su precio no es el 4 %: es la **partición de flujo**,
> que no se cierra con una regla y se previene con `L_slots` frente a `Δ`.

**Estado: CERRADO EN EL SPEC, 2026-09-20.** Redactadas **31 reglas** en §7.1.1–§7.1.7, §12, §14.3
y §16.6: `C-POT-01`…`C-POT-08`, `C-FLU-01`…`C-FLU-18`, `C-FLU-20`…`C-FLU-22`, `C-FIN-01` y
`C-NET-33` — **31 en total**. Familias nuevas: `C-POT`, `C-FLU`, `C-FIN`. `C-FLU-19` **no existe** y no se reutiliza.
Reglas existentes modificadas: `C-HASH-06`, `C-HDR-05`, `C-HDR-06`, `C-HDR-07`, `C-GD-04`,
`C-GD-10`, `C-REORG-07`, `C-NET-31`, `C-NET-32`.

Procedencia: `veritas/consenso/pot-primitiva-v1/` y `veritas/consenso/regla-flujo-v1/` (propuestas
validadas), sobre `veritas/consenso/ancla-inyeccion-v2/` y `veritas/consenso/puerta-cobertura-v1/`
(instrumentos validados). El hilo completo de decisiones, en `P-2.1/SINTESIS.md`.

**Lo que queda, y es mucho:**

- **El código: ninguna de las 31 reglas tiene una línea.** Las 31 están en
  `ci/reglas-sin-codigo.txt`.
- **Dos reglas existentes cambiaron de semántica y su código quedó por detrás del SPEC:**
  `C-HDR-05` (la cota de slot alcanza ahora a todos los padres; el código solo mira `sp`) y
  `C-HDR-07` (el `pot_output` es la salida futura y el último checkpoint la ancla; el verificador
  devuelve `IntegracionPotPendiente`). Declaradas en `ci/reglas-sin-cablear.txt`, con el precedente
  de C-NET-07.
- **El verificador PoT sigue sin existir**, y ahora tiene contrato que cumplir (`C-POT-06`).
- **Las mediciones que faltan: §2.9.**
```

Y las dos frases marcadas arriba se **corrigen en su sitio**:

```markdown
- **El único vector medido que baja el umbral es el multistream de PoT** — **y `C-FLU-14` lo
  cierra**, porque los flujos del atacante no se pueden agregar a una sola cadena. La tabla se
  conserva como registro de qué se midió y bajo qué hipótesis, **no como el umbral del diseño**:
```

```markdown
⚠️ **La auditoría avisaba de que las dos salidas obvias fallan:** si la validez del PoT es
**relativa a la cadena seleccionada**, se abre el multistream; si es **absoluta**, se abre el split
de cadena (ATAQUE 1). **DECIDIDO por Katana el 2026-09-19/20: validez absoluta, perfil 1a.** El
split no se cierra con una regla: se **previene** con `L_slots` frente a `Δ` y, si nace, se cura
**solo** en el caso espontáneo (`C-FLU-22`). Ver §2.9.
```

**De dónde sale:** encargo §1.2.3; `P-2.1/SINTESIS.md:17-21`; `TAREAS.md:129-134`.

**Dudas:** ninguna. **El resto de §2.1 —la tabla de `α_mínimo`, la procedencia del ATAQUE 2, lo que
Claude acotó al validar, la parte de red de Q4— se conserva íntegro**: es el registro de cómo se
llegó aquí y borrarlo sería perder la procedencia.

### E-48 · `TAREAS.md:186-188` · §2.3 anota el residuo de paridad del `SR`

**Texto actual (literal):**

```markdown
### 2.3 · Rango: lo que R-FIN-13′ no cierra
Arranque por red, ventana, límites y redondeos, fusiones fuera de ventana y validación de ramas
candidatas con pesos reales. Conservado a propósito en el «Pendiente» de §7.2.
```

**Texto propuesto (literal):**

```markdown
### 2.3 · Rango: lo que R-FIN-13′ no cierra
Arranque por red, ventana, límites y redondeos, fusiones fuera de ventana y validación de ramas
candidatas con pesos reales. Conservado a propósito en el «Pendiente» de §7.2.

**Residuo de paridad del `SR`, anotado el 2026-09-20.** PCO-v0.1 demostró en `Rational{BigInt}` que
el `SR` **se cancela en todo instante** —el peso de un flujo crece con el espacio que lo cubre—,
con una excepción: **con `SR` impar queda un déficit de `1/(SR+1)`**. Es elegible y es pequeño
—≤ 4,9·10⁻⁴ con `SR_MIN = 2^11`, despreciable con rangos realistas—, pero **existe**, y el
controlador de rango puede evitarlo o no según cómo redondee. Fuente y alcance:
`veritas/consenso/puerta-cobertura-v1/PROCEDENCIA.md` §3.
```

**De dónde sale:** encargo §1.2.3; `veritas/consenso/puerta-cobertura-v1/PROCEDENCIA.md` §3, que lo
declara «pendiente de anotar en `TAREAS.md` §2.3».

**Dudas:** ninguna.

### E-49 · `TAREAS.md:297-298` · §2.7, las filas de C-NET-31 y C-NET-32

**Texto actual (literal):**

```markdown
| **C-NET-31** | tema `/zerox/pot/1`, una verificación por slot, cacheada | Q4 |
| **C-NET-32** | verificación bajo demanda con tres salvaguardas (presupuesto PENDIENTE) | Q4 |
```

**Texto propuesto (literal):**

```markdown
| **C-NET-31** | tema `/zerox/pot/1`, una verificación por **clave de contexto**, cacheada — **corregida el 2026-09-20**: la clave es `(f, s, semilla, N)` de `C-POT-07`, no el slot a secas | Q4 + `C-POT-07` |
| **C-NET-32** | verificación bajo demanda con tres salvaguardas — **corregida el 2026-09-20**: la salvaguarda 1 solo invalida **bajo la misma clave**, y la 3 remite a `C-NET-33` (cota global por nodo, D-F10) | Q4 + D-F10 |
| **C-NET-33** | **nueva**: los dos presupuestos de verificación de flujo ajeno y su modo de fallo `Pendiente` (`PRESUP_PAR`, `PRESUP_NODO`, ambos PENDIENTE) | D-F10 = B |
```

Y la frase de cabecera de §2.7 pasa de «las ocho» a «las nueve»:

```markdown
**Estado: CERRADO EN EL SPEC.** … Lo que queda es **código: ninguna de las nueve tiene una
línea**, y las nueve están en `ci/reglas-sin-codigo.txt`.
```

**De dónde sale:** E-41, E-42, E-32.

**Dudas:** ninguna.

### E-50 · `TAREAS.md:414` · §3, fila 3.3

**Texto actual (literal):**

```markdown
| 3.3 | `I`, `L`, `ρ_max` | Sin cerrar; `ρ_max` entre 3× sin segundo VDF y revelación retardada |
```

**Texto propuesto (literal):**

```markdown
| 3.3 | `I_slots`, `L_suelo_slots`, `ρ_max` | **`L` ya NO es un parámetro libre:** desde el 2026-09-20 es una definición, `L_slots := máx(F_slots, L_suelo_slots, S_max_slots+1)` (`C-FLU-01`, perfil 1a). Lo que queda abierto es **`L_suelo_slots`**, que va como símbolo y **no se puede fijar hoy**: su criterio exige una cota de `Δ` **medida en red real** (§3.1), no simulada. `I_slots` sin cerrar; `ρ_max` entre 3× sin segundo VDF y revelación retardada, **y su aritmética está sin rehacer tras D-2** (§2.9) |
```

**De dónde sale:** encargo §1.2.3; E-43.

**Dudas:** ninguna.

### E-51 · `TAREAS.md:+§2.9` · lo que hoy NO está en ninguna lista

**Texto actual:** no existe. §2.9 es apartado nuevo, tras §2.8.

**Texto propuesto (literal):**

```markdown
### 2.9 · La deuda que §2.1 deja al cerrarse — ESCRITA AQUÍ PORQUE NO ESTABA EN NINGUNA LISTA

§2.1 quedó **cerrado en el SPEC** el 2026-09-20. Lo que sigue **no** es el trabajo de cablearlo:
son **huecos de evidencia y de alcance** que el cierre deja vivos y que hasta hoy no figuraban en
ningún inventario del repositorio. Están ordenados por lo que pasa si se ignoran.

**(a) Lo que el diseño supone y nadie ha medido**

1. **La vía A2 no está medida, y es un hueco nuevo.** `P(una rama privada desplaza el ancla dentro
   de `V_j` antes de `t_j`)` es la cola de una carrera de `blue_work` de longitud `L_slots`. El
   **umbral** está medido (`α_mínimo = 1/2`, CRP-v0.1); **la cola a `L = F_slots`, no**. Y lo que
   `P-2.1` midió —`L_mín`— es **otra magnitud**: desacuerdo honesto por latencia. Ni el encargo de
   `P-FLUJO` ni ninguna adenda contemplaban este vector. Instrumento que podría medirlo:
   `veritas/consenso/ancla-inyeccion-v2/`.
2. **El equilibrio adaptativo no está medido**, y es el ataque que va directamente contra (P2), que
   es donde descansa toda la seguridad del perfil 1a: partir a los honestos en dos mitades y
   sostener el empate. Lo medido es **A3 estática** —todos los bloques del atacante al mismo
   observador toda la réplica— con tope de 8 candidatos y ventana `[T, T+45]`.
3. **El coste de `C-FLU-02` para el productor honesto está `estimado ≈ 0`, no medido.** La
   propuesta declara que confirmarlo con ANCLA-v0.2 —fracción de bloques honestos que
   referenciarían un padre de slot mayor, con `Δ` = 0,5 / 4 / 16 s— es **«condición para pasar al
   SPEC», no trabajo opcional**. **La regla se trasladó igualmente, por decisión de Katana
   (D-F6 = A), y esa condición sigue sin cumplirse.** En el régimen candidato `τ ≈ 0,1-0,17 s` los
   empates y cruces de slot se multiplican por 6-10, así que la estimación **no se extrapola sola**.
4. **La tercera rendija del presupuesto no está medida.** Dos nodos con **el mismo DAG** pueden
   acabar en flujos distintos porque uno pudo pagar la verificación dentro de la ventana de
   `C-FLU-22` y el otro no. A diferencia de las dos rendijas de PCO-v0.1, **ésta está parcialmente
   bajo control del atacante**, que puede gastar presupuesto ajeno con tráfico barato del paso 1b.
5. **El colateral honesto de `C-FLU-20` no está medido.** Un bloque tardío que cambiaría un ancla ya
   activada queda **infusionable para siempre**. Lo normal es que sea del atacante; con qué
   frecuencia atrapa bloques honestos, y cuánto empeora con `τ ≈ 0,1-0,17 s`, no se ha medido.
6. **La `Δ` de TODO lo anterior es simulada** (DMS-v0.1), no medida en red. Sigue siendo «la primera
   medición que el diseño necesita» (§3.1).

**(b) Lo que está demostrado que NO funciona, o que falta por demostrar**

7. **El sembrador (A5): las defensas escritas no sirven, y el margen no está medido.**
   `P-SEMBRADOR/investigacion/` (Codex, **validación parcial**: integridad, tests y dos citas clave
   comprobadas; **el informe completo está sin leer**) establece que **ni `history_size` ni
   `altura_ploteo` demuestran antigüedad física** —identifican el prefijo histórico, y un atacante
   puede escoger hoy una referencia antigua que aún sea válida— y que **al atacante le basta una
   pieza, no un sector**. Eliminarlo exigiría **A1+C1**: registrar antes del reto una
   raíz/versionado/cardinalidad de la parcela exacta, **es decir un cambio de consenso**.
   **Falta medir el coste de un intento dirigido** antes de elegir camino. Bajo el perfil **1a** la
   salida histórica —«desatar `L` de `F`»— **queda cerrada**, y el suelo de `C-FLU-01` la cierra
   más: el margen histórico de **1,91×** es **con precios supuestos** y **no está medido**.
8. **La deuda principal: la convergencia del orden no está probada para este diseño.** Prop. 7 y
   Def. 2 de GHOSTDAG están probadas sobre GHOSTDAG **puro**; con las tres reglas añadidas encima,
   «que el orden total siga convergiendo bajo las tres **no está comprobado**. Es la deuda
   principal» (`research/dag-poas-ancla-de-orden.md:436-439`, que las nombra `U3′`, `R-FIN-5` y
   `R-FIN-8`; la forma corregida que usa `P-2.1/SINTESIS.md:64-65` es `U3″` y `R-FIN-8′`). **Toca a §7.1 de lleno:** (F1)
   —`slot` no decreciente por la cadena seleccionada— y (F2) —`blue_work` estrictamente creciente—,
   de las que cuelgan `C-FLU-04` y toda §7.1.3, son **propiedades medidas en simulador y un lema**,
   no consecuencias del teorema.
9. **La existencia del ancla en el caso patológico no está medida.** `C-FLU-04` la demuestra bajo
   una condición suficiente y `C-FLU-05` cierra el caso contrario con un rechazo. **Con qué
   probabilidad `Chn(V_j(B))` diverge de la cadena de `B` por debajo de `T_j` no se sabe:** no hay
   ninguna proposición que ate `blue_work` con `slot`.
10. **La disponibilidad del ancla tras la poda no se resuelve.** `C-FLU-04` necesita `V_j(B)` para
    **todas** las épocas del pasado; qué pasa cuando esos bloques están podados sigue abierto, como
    ya decía R-FIN-1 y repite §7.3.

**(c) Aritmética y calibración sin rehacer**

11. **La aritmética del adelanto está SIN REHACER tras D-2 = A.** El argumento de R-FIN-14(f)/(h)
    —`I ≥ ρ_max·W_dec`, `lead_max`, `ρ* ≈ 1 + L/I`— está escrito sobre la salida **del propio
    slot**; con `pot_output = salida(f, slot+D)` **no se ha rehecho**. **Ninguna cifra de adelanto,
    de `ρ_max` ni de margen frente al sembrador debe darse por válida hasta que se rehaga.**
12. **`PRESUP_NODO` se calibra en PINZA, y una de las dos mordazas no está derivada.** Por abajo:
    integrado sobre la ventana de `C-FLU-22`, **MUST** bastar para verificar **una rama rival
    completa** —peor caso `F_slots` slots, del orden de `F_slots × 92 ms` ≈ **11 min de CPU** con
    los valores nominales—; **con menos, la adopción nunca se completa y D-F9 queda derogada de
    hecho sin que nadie la revoque**. Por arriba: demasiado grande devuelve el DoS. **La cota
    superior NO está derivada.** El valor de `PRESUP_PAR` sigue siendo un `<<PENDIENTE>>` declarado
    que calibra el v2b (Q5).

**(d) Alcance que se decidió dejar fuera, no olvido**

13. **La reconciliación de `C-FIN-01`** con (i) el código que hoy **se detiene**
    —`ReorgDemasiadoProfunda` obliga a «detener el nodo y avisar al operador, no reintentar»—, (ii)
    **`COINBASE_MATURITY`**, de la que `MAX_REORG_LENGTH = COINBASE_MATURITY − 1 = 11 999` deriva, y
    (iii) **el techo de archivado**, que nadie ha estudiado. Quedó fuera **por alcance decidido**
    (D-F3 = C acotada al enunciado), no por falta de decisión. **Es trabajo, no bifurcación.**
    `C-REORG-07` sigue transitoria.
14. **La regla objetiva del recién llegado** —«el flujo canónico es el que lideraba en
    `t_j + F_slots`»— queda como **encargo aparte**, con su resistencia a bloques con slots antiguos
    por estudiar. `C-FLU-18` hace la conducta determinista y única; **no la hace acertada**: tras
    `ALTURA_CADUCIDAD` del checkpoint y con una partición viva, un nodo nuevo va al flujo más pesado
    **del momento**, que puede ser el minoritario.

**(e) Evidencia sin validar que afecta a lo anterior**

15. **CRP-v0.2 y CRP-v0.3 existen en `deepseek/` y NO están validadas ni migradas.** CRP-v0.2
    declara en su propia cabecera que **«sustituye la evidencia protocolaria de CRP-v0.1»**
    (baseline idealizado útil; **veredicto protocolario inconcluso**), y CRP-v0.3 se deriva de
    CRP-v0.2, «que **no** se cierra». **§2.1 y `SPEC.md` §17 citan CRP-v0.1.** Hasta que alguien
    valide v0.2/v0.3 o declare por qué no aplican, **hay una versión posterior de la evidencia
    central de §2.1 sin revisar**, en una zona que `.gitignore` excluye y que se borra al cerrar
    cada encargo.

**(f) El código, que es lo único que cablea todo esto**

16. **El verificador PoT no existe**, y ahora tiene contrato: `C-POT-06` (tres estados, sin
    circularidad), `C-POT-07` (caché por clave contextual) y `C-POT-08` (orden de validación).
    Integrar `prototipos/pot-estable` es el primer paso.
17. **La derivación del flujo en el nodo no existe.** `C-FLU-10` necesita calcular `Chn(V_j)` sobre
    la vista de época; `C-FLU-02` necesita un accesor de `slot` de un padre arbitrario que
    `ContextoDag` **no expone** hoy; `C-FLU-17` necesita puntos de enganche en el nodo que tampoco
    existen. Nada de esto se puede empezar sin §2.8.
```

**De dónde sale:** encargo §1.2.3, que enumera exactamente estos puntos; ampliado con los que la
propia propuesta declara en «Lo que esta propuesta NO resuelve»
(`veritas/consenso/regla-flujo-v1/PROPUESTA-SPEC.md:1876-2039`) y con el hallazgo de `deepseek/`.

**Dudas:** ninguna. El punto **(e)** no estaba en la lista del encargo y lo añado porque lo encontré
al comprobar las rutas: **es evidencia posterior sin validar que contradice el estado declarado de
la evidencia central de §2.1**, y dejarlo fuera de la lista sería dejar fuera la peor noticia.

### E-52 · `TAREAS.md:+726` · «Cerrado recientemente» gana la entrada de §2.1

**Texto actual (literal), la primera entrada de la lista:**

```markdown
## Cerrado recientemente (para no reabrirlo)

- **GHOSTDAG y `rank` redactados en el SPEC (1.2 + 1.3)**, 2026-09-15.
```

**Texto propuesto (literal):** se inserta **antes** de esa entrada:

```markdown
## Cerrado recientemente (para no reabrirlo)

- **Dependencias por flujo del PoT (§2.1) redactadas en el SPEC**, 2026-09-20. **31 reglas
  nuevas** —`C-POT-01`…`08`, `C-FLU-01`…`18`, `C-FLU-20`…`22`, `C-FIN-01`, `C-NET-33`— y nueve
  existentes modificadas. Tres familias nuevas: `C-POT`, `C-FLU`, `C-FIN`. `C-FLU-19` no existe.
  - **La decisión de fondo:** validez del PoT **absoluta** (`C-FLU-13`) con perfil **1a**
    (`L_slots := máx(F_slots, L_suelo_slots, S_max_slots+1)`, `C-FLU-01`). Su precio es la
    **partición de flujo**, que **no se cierra con una regla**: se previene con `L` frente a `Δ` y,
    si nace, `C-FLU-22` solo cura el nacimiento **espontáneo**.
  - **Corrección del titular anterior:** `1/(S+1)` —el «4 %»— es la **regla aditiva** y **no
    aplica con pasado consistente de flujo** (`C-FLU-14`). CRP-v0.1 ya etiquetaba su resultado
    «condicionado al diseño del flujo, no demostrado».
  - Evidencia: `veritas/consenso/pot-primitiva-v1/` y `veritas/consenso/regla-flujo-v1/`
    (propuestas validadas), sobre `veritas/consenso/ancla-inyeccion-v2/` (ANCLA-v0.2) y
    `veritas/consenso/puerta-cobertura-v1/` (PCO-v0.1). Decisiones: D-1, D-2, D-F1…D-F10, todas
    cerradas; hilo completo en `P-2.1/SINTESIS.md`.
  - **Pendiente: el código —ninguna de las 31 tiene una línea— y la deuda de evidencia de §2.9.**
```

**De dónde sale:** la forma de la lista existente.

**Dudas:** ninguna.

### E-56 · `TAREAS.md:679-681` · Nivel 5, deuda de evidencia — pedida por `ADENDA-1.md` §1

**Texto actual (literal), la última entrada de la lista:**

```markdown
- **`DMS-v0.1`:** el test del estimador ponderado por espacio (T1) comprueba las funciones, pero
  `run.jl` aplica la regla en línea, sin llamarlas. Una regresión en esa ruta no la detectaría el
  test (`veritas/finalidad/delta-medido-v1/ENMIENDA-R2.md` §7).
```

**Texto propuesto (literal):** se conserva y se añade a continuación:

```markdown
- **`ANCLA-v0.2` escribe sus resultados en el directorio de trabajo, no en el suyo.** `run.jl` usa
  `joinpath("resultados", ...)` relativo al CWD (`veritas/consenso/ancla-inyeccion-v2/run.jl:49`,
  y lo mismo en `:81, :121, :150, :169`), mientras `METODO.md` manda ejecutar **desde la raíz del
  repositorio**. Seguir el método al pie de la letra crea `resultados/` **en la raíz**, no dentro
  de la carpeta del instrumento — que es donde el propio `METODO.md` dice que están las salidas.
  Detectado el 2026-09-20 al reejecutar la celda `hon-4` como control de identidad de la
  migración; **el control salió idéntico byte a byte**, así que no invalida ninguna cifra. Lo que
  sí hace es que **una reproducción descuidada puede comparar la copia consigo misma y no darse
  cuenta**. Avisado en el `METODO.md` del instrumento; **no corregido**, porque el único cambio de
  código que `P-CIERRE/ENCARGO.md` §1.1 autorizaba era el `include` de GDR.
```

**De dónde sale:** `P-CIERRE/ADENDA-1.md` §1 («Añade a `TAREAS.md` (Nivel 5, deuda de evidencia)
que ANCLA-v0.2 escribe `resultados/` relativo al directorio de trabajo y no al del instrumento»).

**Dudas:** ninguna.

### E-53 · `TAREAS.md:648-660` · §4.2, IDs de regla

**Texto actual (literal), el titular y la primera viñeta:**

```markdown
### 4.2 · IDs de regla para §7.2 — DECIDIDO POR KATANA (2026-09-15)

Las reglas de §7.2 y §11 llevan IDs `C-XXX-NN`. Se aplicó con dos familias nuevas: **C-ORD-NN**
para el orden y el desempate de §7.2, y **C-GD-NN** para GHOSTDAG en §11.
```

**Texto propuesto (literal):**

```markdown
### 4.2 · IDs de regla — DECIDIDO POR KATANA (2026-09-15, ampliado el 2026-09-20)

Las reglas de §7.2 y §11 llevan IDs `C-XXX-NN`. Se aplicó con dos familias nuevas: **C-ORD-NN**
para el orden y el desempate de §7.2, y **C-GD-NN** para GHOSTDAG en §11.

**Tres familias más el 2026-09-20**, con el mismo criterio: **C-POT-NN** (el PoT como primitiva y
el contrato del verificador, §7.1.1–§7.1.2), **C-FLU-NN** (el flujo, §7.1.3–§7.1.7) y **C-FIN-NN**
(finalidad, §12). La separación entre `C-FLU` y `C-FIN` **es una decisión**, no una comodidad:
Katana la tomó en **D-F7 = B** porque la regla de finalidad **no es una regla de flujo**, es una
regla que el flujo usa. Por ese mismo criterio, el presupuesto de verificación de flujo ajeno
**no** es `C-FLU-23` sino **`C-NET-33`**: es una enmienda a C-NET-32.3, de la capa de red.

> ⚠️ **`C-FLU-19` NO EXISTE y su número no se reutiliza.** Fue el nombre de la regla de finalidad
> hasta que D-F7 la sacó de la familia y la renombró `C-FIN-01`. Es el mismo régimen que
> `C-FORK-01`…`04` y que `C-NET-10`.
```

**De dónde sale:** encargo §Reglas 4; D-F7 = B.

**Dudas:** ninguna.

---

## 6 · Detalle de las ediciones — `ci/`

**El guardián que decide esto es `ci/citas-spec.sh`, y falla en los dos sentidos.** Una regla vive
en **exactamente uno** de tres estados:

```
ci/reglas-sin-codigo.txt     la regla no la cita nadie        (no hay código)
ci/reglas-sin-cablear.txt    la cita código que nadie ejecuta (hay código, falta la llamada)
ninguna de las dos           citada y en la ruta activa
```

### E-54 · `ci/reglas-sin-codigo.txt` · **+31 IDs**

**Texto actual:** 35 IDs declarados. Las 32 nuevas no existen todavía.

**Texto propuesto (literal):** se añade al final del archivo (**31 IDs**, no 32: `E-01` es la reescritura de §7.1 y no es una regla):

```
# ── PoT como primitiva y contrato del verificador (SPEC §7.1.1-§7.1.2) ────────────────────────
#
# Redactadas el 2026-09-20 desde veritas/consenso/pot-primitiva-v1/, propuesta validada. Ninguna
# tiene código. El verificador PoT AES no existe: prototipos/pot-estable tiene la primitiva con
# 32 vectores diferenciales, pero no está integrada, y zx-core::wire_dag::verificar_justificacion_pot
# devuelve IntegracionPotPendiente en vez de un booleano provisional (TAREAS §2.1).
#
# C-POT-01  encadenado de semilla slot a slot, con la inyección aplicada exactamente en t_j.
# C-POT-02  salida = AES128_chain^N(semilla) en 8 tramos; la verificación es determinista.
# C-POT-03  aleatoriedad y reto por slot, y la PROHIBICIÓN de cualquier derivación que permita
#           saltarse slots. Es una prohibición: no hay línea que citar, hay ausencia de línea.
# C-POT-04  dominio de N(s) y proyección u64 -> NonZeroU32 sin panic; fuera de dominio = Pendiente.
# C-POT-05  el pot_output de la cabecera es la salida FUTURA (D-2 = A) y el último checkpoint la
#           ancla. Cambia la semántica de C-HDR-07, cuyo código queda por detrás: ver
#           ci/reglas-sin-cablear.txt.
# C-POT-06  contrato del verificador: tres estados y circularidad imposible.
# C-POT-07  caché indexada por clave contextual (f, s, semilla, N); validez != recursos.
# C-POT-08  orden de validación: estructural y caché antes que AES.
C-POT-01
C-POT-02
C-POT-03
C-POT-04
C-POT-05
C-POT-06
C-POT-07
C-POT-08

# ── El flujo del PoT (SPEC §7.1.3-§7.1.7, y C-FLU-17 en §14.3) ────────────────────────────────
#
# Redactadas el 2026-09-20 desde veritas/consenso/regla-flujo-v1/, propuesta validada, sobre los
# instrumentos veritas/consenso/ancla-inyeccion-v2/ y veritas/consenso/puerta-cobertura-v1/.
# Ninguna tiene código, y dos de ellas ni siquiera tienen dónde engancharlo:
#   · C-FLU-02 necesita un accesor del slot de un padre ARBITRARIO; zx-consensus::ContextoDag
#     expone es_bloque_validado, esta_en_el_pasado_de, padre_seleccionado y es_genesis, y NINGUNO
#     da el slot de un padre cualquiera. Sin ese accesor la regla no es comprobable en ese crate.
#   · C-FLU-17 necesita puntos de enganche de estado/métrica en el nodo que no existen.
#
# C-FLU-19 NO EXISTE: fue el nombre de la regla de finalidad hasta D-F7, que la renombró C-FIN-01.
# Su número no se reutiliza (TAREAS §4.2).
#
# C-FLU-01  unidades en slots; L_slots := máx(F_slots, L_suelo_slots, S_max_slots+1). Definición,
#           no parámetro. L_suelo_slots es <<PENDIENTE>>: exige una Δ medida en red real.
# C-FLU-02  cota de slot para TODOS los padres. Es la misma que C-HDR-05 ampliada; su coste para
#           el productor honesto está estimado ~0 y NO medido (TAREAS §2.9).
# C-FLU-03  vista de época V_j(B), con corte en T_j + L_slots (no en t_j, que dependería del ancla).
# C-FLU-04  el ancla: primer cruce de T_j por la cadena seleccionada de la VISTA, no la del nodo.
# C-FLU-05  época sin ancla: se salta, sin recuperación retroactiva; el bloque sin ancla a
#           T_j+L_slots es inválido.
# C-FLU-06  flujo del génesis y semilla(f_0, 0). Usa DOS hashes distintos a propósito: H_flujo para
#           el identificador, blake3 para la semilla. No uniformarlos.
# C-FLU-07  t_j = slot(I_j) + L_slots; hasta t_j rige el flujo anterior. Una sola lotería.
# C-FLU-08  S_max_slots < L_slots: condición de CORRECCIÓN de la definición del ancla.
# C-FLU-09  S_max_slots < I_slots: los t_j distintos dos a dos, <= 1 inyección por slot.
# C-FLU-10  derivación del identificador de flujo con H_flujo = H_d(ETIQUETA_FLUJO || m). Amplía
#           C-HASH-06 con dos etiquetas nuevas (D-F2 = A).
# C-FLU-11  el flujo NUNCA se declara. Prohibición: no hay línea que citar.
# C-FLU-12  entropía de la inyección = blake3(chunk || pot_output) del ancla (D-F1 = A), con el
#           invariante de no-equivocación del inyector como cláusula.
# C-FLU-13  validez ABSOLUTA. Es la bifurcación de §2.1, decidida por Katana.
# C-FLU-14  pasado consistente de flujo: paso 1b del orden de validación, estructural y sin AES.
# C-FLU-15  una partición de flujo tiene el ESTATUTO de un fallo de finalidad ("se trata como", no
#           "es"). Declaración: no hay línea que citar.
# C-FLU-16  N(s) cambia exactamente en t_j y en ningún otro slot.
# C-FLU-17  señal de flujo minoritario. NO es regla de consenso: vive en §14.3 y no cambia la
#           validez de ningún bloque. Necesita enganches en el nodo que no existen.
# C-FLU-18  el nodo sin cadena previa aplica la selección ordinaria de GHOSTDAG. Cierra un hueco de
#           redacción; no añade mecanismo.
# C-FLU-20  el productor descarta las puntas cuya fusión cambiaría un ancla ya activada. Política de
#           producción, como C-GD-10; el bloque tardío queda infusionable para siempre.
# C-FLU-21  la inyección ya activada se hereda, no se recalcula (D-F8 = C: la vista NO se congela).
# C-FLU-22  adopción del flujo rival dentro de la ventana, con presupuesto (D-F9 = C). Sustituye a
#           DF-2, que se había decidido sobre una premisa falsa.
C-FLU-01
C-FLU-02
C-FLU-03
C-FLU-04
C-FLU-05
C-FLU-06
C-FLU-07
C-FLU-08
C-FLU-09
C-FLU-10
C-FLU-11
C-FLU-12
C-FLU-13
C-FLU-14
C-FLU-15
C-FLU-16
C-FLU-17
C-FLU-18
C-FLU-20
C-FLU-21
C-FLU-22

# ── Finalidad (SPEC §12) ──────────────────────────────────────────────────────────────────────
#
# C-FIN-01  finalidad en índices de slot, sin exit: d >= F_slots prohibido, la punta se ignora y el
#           proceso NO se detiene. Familia nueva por decisión de Katana (D-F7 = B): no es una regla
#           de flujo, es una regla que el flujo usa.
#
#           ⚠ EL CÓDIGO DE HOY HACE LO CONTRARIO, y no por estar sin cablear: zx-node::cadena
#           devuelve ReorgDemasiadoProfunda y obliga a "detener el nodo y avisar al operador, no
#           reintentar". Eso implementa C-REORG-07, que sigue siendo TRANSITORIA y sigue vigente
#           en el código. C-FIN-01 no la sustituye todavía: la reconciliación quedó fuera de
#           alcance por decisión (D-F3 = C) y está declarada en TAREAS §2.9.
C-FIN-01

# ── Presupuesto de verificación de flujo ajeno (SPEC §16.6) ───────────────────────────────────
#
# C-NET-33  dos presupuestos (PRESUP_PAR, PRESUP_NODO), los dos <<PENDIENTE>>, y el modo de fallo
#           escrito: agotar cualquiera da Pendiente y NUNCA Inválido, el nodo conserva su cadena,
#           SIGUE REENVIANDO y reintenta. Es la enmienda a C-NET-32.3 que D-F10 = B decidió; se
#           numera en C-NET y no en C-FLU por el mismo criterio de D-F7.
C-NET-33
```

**De dónde sale:** encargo §1.2.4; `TAREAS.md:655-656`.

**Efecto en el guardián:** `ci/reglas-sin-codigo.txt` pasa de **35** a **66** IDs declarados.
`ci/citas-spec.sh` pasará de «191 reglas» a **222**.

**Dudas:** ninguna. **Comprobado que ninguno de los 31 IDs existe hoy** en `SPEC.md`, `TAREAS.md`,
`ci/`, `crates/` ni `research/`, y que `C-NET-33` está libre (el máximo hoy es `C-NET-32`).

### E-55 · `ci/reglas-sin-cablear.txt` · `C-HDR-05` y `C-HDR-07` cambian de semántica

**El problema que hay que resolver, y por qué no vale moverlas de archivo.** `C-HDR-05` y
`C-HDR-07` **están citadas** por `crates/zx-core/src/wire_dag.rs`. Si se pasan a
`ci/reglas-sin-codigo.txt`, `ci/citas-spec.sh` falla con «Estas ya se citan en el código y siguen en
`ci/reglas-sin-codigo.txt`» (`ci/citas-spec.sh:76-87`). **Su estado sigue siendo «hay código, falta
la llamada»: lo que cambia es que ese código implementa la versión ANTERIOR de la regla.**

**El repositorio ya tiene el precedente exacto, y es C-NET-07**
(`ci/reglas-sin-cablear.txt:76-85`): «la regla pasó a derivar sobre `wtxid` … y el código sigue
derivando sobre `txid`. **No es solo código sin cablear: es código de la versión anterior de la
regla.**» Se aplica el mismo patrón, **sin tocar `crates/`**.

**Texto actual (literal), el comentario de C-HDR-05 y el de C-HDR-07:**

```
# C-HDR-05  slot(B) >= slot(sp(B)). Comprobación estructural en crates/zx-core/src/wire_dag.rs
#           (comprobar_diferencia_slots_del_bloque); el slot del padre seleccionado lo aporta el
#           contexto DAG, que todavía no existe.
```

```
# C-HDR-07  la justificación PoT va fuera de la cabecera y es obligatoria. Hay contenedor y
#           códec, pero el verificador AES secuencial devuelve IntegracionPotPendiente: hoy
#           nadie la exige.
```

**Texto propuesto (literal):**

```
# C-HDR-05  ⚠️ CAMBIÓ DE SEMÁNTICA EL 2026-09-20, Y EL CÓDIGO ES DE LA VERSIÓN ANTERIOR. La regla
#           exigía slot(sp(B)) <= slot(B) y no decía nada de los demás padres. Katana decidió
#           D-F6 = A: la cota alcanza ahora a TODOS los padres, slot(p) <= slot(B), porque sin eso
#           el corte por slot de C-FLU-03 no es cerrado por ancestros y GHOSTDAG no está definido
#           sobre él. El código comprueba SOLO el padre seleccionado:
#           comprobar_diferencia_slots_del_bloque recibe únicamente slot_sp
#           (crates/zx-core/src/wire_dag.rs), y zx-consensus::ContextoDag no expone forma de pedir
#           el slot de un padre arbitrario, así que la regla nueva NO es comprobable ahí sin un
#           accesor nuevo. Es el mismo estado que C-NET-07: no solo código sin cablear, sino
#           código de la versión anterior de la regla. Cablear C-HDR-05 significa ahora dos cosas,
#           no una: llamar a la comprobación desde la ruta activa Y ampliarla a todos los padres.
#           Mismo objeto que C-FLU-02, declarada en ci/reglas-sin-codigo.txt.
```

```
# C-HDR-07  ⚠️ CAMBIÓ DE SEMÁNTICA EL 2026-09-20, Y EL CÓDIGO NO LA ALCANZA. La regla ya no solo
#           dice que la justificación es obligatoria: dice QUÉ ancla (D-2 = A, C-POT-05). El
#           pot_output de la cabecera es la salida FUTURA, salida(f, slot(B)+D), los d portadores
#           cubren (slot(sp)+D, slot(B)+D], y el último checkpoint del último portador MUST ser
#           igual a pot_output. Hay contenedor y códec, pero el verificador AES secuencial
#           devuelve IntegracionPotPendiente: hoy nadie la exige y nadie comprueba el anclaje.
#           Cablearla exige el verificador de C-POT-06/07/08, que no existe (TAREAS §2.9).
```

**De dónde sale:** encargo §1.2.4 («di cómo se declara eso con las convenciones de `ci/` … **sin
tocar `crates/`**»); precedente de C-NET-07 en el propio archivo.

**Dudas — D-13:** el encargo nombra `C-HDR-05`. **`C-HDR-07` está en la misma situación** por D-2 =
A y lo incluyo; si Katana prefiere tocar solo lo que el encargo nombra, el segundo bloque se cae.
**Recomiendo incluirlo:** dejar `C-HDR-07` con un comentario que ya no describe su regla es
exactamente el fallo que este archivo existe para impedir.

**Nota sobre `C-HDR-06`:** también cambia (E-36), pero **solo gana una definición de un término que
ya usaba** —`flow` → `flujo`, definido por `C-FLU-10`—. Su código no queda por detrás de nada: la
interfaz de `bloque_dag.rs` sigue prohibiendo la circularidad por tipo, que es lo que la regla
exige. **No se toca su entrada en `ci/reglas-sin-cablear.txt`.**

**Ningún ID entra ni sale de `ci/reglas-sin-cablear.txt`:** sigue con 22. Lo que cambia son dos
comentarios.

---

## 7 · Lo que NO entra, con su motivo

### 7.1 · No entra en el SPEC porque su sitio es `veritas/`

| Qué | Por qué no entra |
|---|---|
| **Todas las demostraciones** (buena fundamentación del ancla, unicidad, existencia condicionada, Lemas 1 y 2, (c′), A1, la lotería única, el entierro del ancla, el cierre del DoS de verificación, la inocuidad de la caché con un flujo) | El SPEC lleva el **enunciado normativo**; las pruebas se quedan en la carpeta migrada y se citan por `§` y línea. Meterlas haría el SPEC ilegible y duplicaría un texto que ya está firmado por `HUELLAS.sha256` |
| **Las cifras de simulación**: `L_mín` = 119 / 1 198 / 1 682 / 177 slots, la extrapolación ≈360 / ≈3 600 / ≈5 000, `arcsin(√(τ/F))/π` = 0,27 % / 0,75 % / 1,5 %, `S_IOPS ≈ 24`, el margen 1,91× | **Ninguna cifra medida entra como constante** (encargo §1.2.1). Y todas cuelgan de una **`Δ` simulada**. Se citan como referencia de calibración en la nota de `C-FLU-01` y en la de riesgo residual de `C-FLU-22` |
| Las 45 citas en fuente de Autonomys de `pot-primitiva-v1` y las 153 de `regla-flujo-v1` | Son el aparato de validación de las propuestas, no texto normativo |
| El registro de opciones de **D-1, D-2 y D-F1…D-F10** | Vive en los dos `DECISIONES-PENDIENTES.md` migrados. El SPEC dice qué se decidió, no qué se descartó |
| La tabla (iii) de `C-FLU-02` sobre qué habría que tocar en `crates/` | Es trabajo de cableado: va a `TAREAS.md` §2.9 y a `ci/`, no al SPEC |

### 7.2 · No entra porque no está decidido, y no me toca decidirlo

| Qué | Estado |
|---|---|
| **Los valores** de `F_slots`, `L_suelo_slots`, `I_slots`, `D`, `N(s)`, `ρ_max`, `PRESUP_PAR`, `PRESUP_NODO`, `entropía_externa`, la ventana de persistencia de `C-FLU-17` | Todos como **símbolo** o `<<PENDIENTE>>`. `L_suelo_slots` **no se puede fijar hoy**: exige una `Δ` medida en red real |
| **La reconciliación de `C-FIN-01`** con `C-REORG-07`, con el código que se detiene, con `COINBASE_MATURITY` y con el techo de archivado | **Fuera por alcance decidido** (D-F3 = C, acotada al enunciado). `C-REORG-07` sigue transitoria y **no se reconcilia** |
| **La regla objetiva del recién llegado** («el flujo canónico es el que lideraba en `t_j + F_slots`») | Encargo aparte; su resistencia a bloques con slots antiguos está por estudiar |
| **El perfil 1b** (`L < F`) | Descartado hoy. Si se adoptara, `C-FLU-15` y toda §7.1.6 habría que reescribirlos enteros |
| **La verificación conjunta PoAS/PoT completa** (§7.1): solución de espacio, testigos KZG, distancia de solución y sello contra el reto | Sigue pendiente y se conserva explícita en §7.1. El paso 5 de `C-POT-08` la supone, no la escribe |
| **C-CHK-05** y su calibración | Se cita como compatible con `C-NET-31`; no se toca |

### 7.3 · No entra porque el encargo lo prohíbe

| Qué | Motivo |
|---|---|
| Cualquier cambio en `crates/`, `prototipos/`, `research/`, `deepseek/` y los `P-*/` originales | Encargo §Reglas 2. **El desfase de `C-HDR-05` y `C-HDR-07` se declara en `ci/`, no se arregla en el código** |
| Migrar `deepseek/` (incluido el instrumento v1 del ancla, que midió el ancla equivocada), `P-SEMBRADOR/` y `P-ZRX/` | Encargo §1.1. `P-SEMBRADOR` **sí** entra en `TAREAS.md` §2.9 como deuda nombrada; `P-ZRX` no, porque es investigación en curso sin validar y sin relación con §2.1 |
| Regenerar los `resultados/` migrados | Encargo §1.1, salvo el control de identidad de `hon-4`, que se hizo |
| Cualquier `git commit`, `push`, `stash`, cambio de rama o borrado | Encargo §Reglas 1 |

### 7.4 · Reglas de la propuesta que NO llegan al SPEC como tales

| Qué | Qué se hace |
|---|---|
| **`C-FLU-23`** | **No existe como `C-FLU`.** Se traslada como **`C-NET-33`** (§16.6), por el criterio de D-F7 que la propia propuesta invoca. D-11 |
| **`C-FLU-12.1`** | **No es un ID.** Su texto entra **íntegro** como cláusula de `C-FLU-12`, porque `ci/citas-spec.sh` no puede distinguir `C-FLU-12.1` de `C-FLU-12`. D-7 |
| **`C-FLU-19`** | **No existe.** Es `C-FIN-01`. El número no se reutiliza |
| Las dos frases de `C-FLU-17` que dicen «DF-2 sigue intacta» y «cambiar de flujo sería imposible bajo 1a» | **Se retiran:** las superó `C-FLU-22` (D-F9 = C). D-9 |
| La frase de `C-REORG-07` «No se publican ambas reglas como simultáneamente activas» | **Se reescribe**, porque después de E-31 dejaría de ser cierta. D-10 |

---

## 8 · Dudas y defectos anotados, NO resueltos

**Rule 3 del encargo: lo que al condensar parece defecto o ambigüedad se anota y no se resuelve.**
Aquí están las catorce, con lo que hago por defecto si Katana no dice otra cosa.

| # | Dónde | Qué pasa | Qué hago por defecto |
|---|---|---|---|
| **D-1** | E-06, E-37 · `C-POT-05`, `C-HDR-07` | `PROCEDENCIA.md` manda **corregir** una afirmación de la propuesta validada: «la justificación de `B` no basta» es demasiado pesimista, porque los padres se validan antes que el hijo | **Escribo la corrección**, como manda el testimonio del validador |
| **D-2** | E-10 · `C-FLU-01` | La propuesta usa `≥` en su §1 y `:=` en la decisión de la tercera tanda | **Escribo `:=`**, que es lo decidido y lo más estricto |
| **D-3** | E-11 · `C-FLU-02` | La propuesta declara que medir su coste con ANCLA-v0.2 es **«condición para pasar al SPEC», no trabajo opcional**. **Esa medición no existe** | **Traslado la regla** (Katana decidió D-F6 = A sabiéndolo) y la anoto en `TAREAS.md` §2.9 |
| **D-4** | E-15, E-34 | `ETIQUETA_FLUJO` y `ETIQUETA_GENESIS` son **nombres propuestos**, no decididos | Uso los propuestos; **cambiarlos no toca ninguna demostración** |
| **D-5** | E-19, E-36 | Conviven `flow` (SPEC) y `flujo` (código) | **Fijo `flujo`** en las dos |
| **D-6** | E-20 · `C-FLU-11` | La propuesta escribe «ningún campo … **MUST** contener» donde el sentido es **MUST NOT**. **El mismo giro está hoy en `C-HDR-06`** (`SPEC.md:896`) | **Escribo `MUST NOT`** y lo declaro aquí en vez de arreglarlo en silencio |
| **D-7** | E-21 · `C-FLU-12.1` | No puede ser un ID de línea: `ci/citas-spec.sh` lo leería como `C-FLU-12` duplicado | **Cláusula dentro de `C-FLU-12`**. Si Katana la quiere como regla, el ID libre es `C-FLU-24` |
| **D-8** | E-26 · `C-FLU-17` | La propuesta dice «§14.3 / §16». §14.3 es la única sección llamada «Comportamiento del nodo», pero **cuelga de «Activación de cambios de consenso» y solo tiene reglas `C-UPG`** | **§14.3.** Crear una §16.7 para una sola regla no operativa es peor |
| **D-9** | E-26 · `C-FLU-17` | **La regla se contradice con `C-FLU-22`:** conserva dos frases de la revisión 2 que `D-F9 = C` superó | **Retiro las dos frases** y escribo la versión compatible. **Es un cambio de fondo y por eso está aquí** |
| **D-10** | E-31, E-40 | `C-REORG-07` dice hoy «**No se publican ambas reglas como simultáneamente activas**», y con `C-FIN-01` el SPEC publica las dos | **Reescribo la frase** diciendo cuál rige y cuál describe. Si Katana la quiere literal, `C-FIN-01` **no puede entrar** hasta reconciliar — y eso lo dejó fuera D-F3 |
| **D-11** | E-32 · `C-NET-33` | El ID. La propuesta lo señala sin abrir decisión | **`C-NET-33`**, el siguiente libre. **No** como tercer punto de C-NET-32: lo haría invisible a `ci/citas-spec.sh` |
| **D-12** | E-33 · §0.2 | **La tabla de áreas ya está incompleta hoy**: faltan catorce familias. Añadir tres y dejar catorce fuera es incoherente | **Añado solo las tres.** Recomiendo completarla, **pero está fuera de alcance** |
| **D-13** | E-55 · `ci/` | El encargo nombra `C-HDR-05`; **`C-HDR-07` está en la misma situación** por D-2 = A | **Incluyo las dos.** Dejar un comentario que ya no describe su regla es el fallo que ese archivo existe para impedir |
| **D-14** | E-36 · `C-HDR-06` | El cambio de nombre `flow` → `flujo` toca una regla existente | Lo hago, y lo declaro |

### 8.1 · Tres cosas que NO son dudas: son malas noticias del estado del proyecto

1. **La condición de traslado de `C-FLU-02` no se ha cumplido.** La propuesta la escribió como
   condición, no como deseo. Se traslada igual porque Katana decidió D-F6 = A sabiéndolo, pero
   **queda una regla de consenso cuyo coste para los honestos nadie ha medido**.
2. **`CRP-v0.2` declara superada la evidencia de `CRP-v0.1`, y nadie la ha validado.** §2.1 y
   `SPEC.md` §17 citan CRP-v0.1. La v0.2 y la v0.3 están en `deepseek/`, que `.gitignore` excluye y
   que **se borra al cerrar cada encargo**. Va a `TAREAS.md` §2.9 (e).
3. **La deuda principal sigue donde estaba, y ahora sostiene más peso.** (F1) y (F2) son
   propiedades **medidas en simulador y un lema**, no consecuencias del teorema de GHOSTDAG, y de
   ellas cuelga toda §7.1.3 —incluida la buena fundamentación del ancla, que es lo que repara E1—.

---

## 9 · Recuentos antes y después

| | Antes | Después |
|---|---:|---:|
| Reglas en `SPEC.md` (`ci/citas-spec.sh`) | **191** | **222** |
| — de ellas, en `ci/reglas-sin-codigo.txt` | 35 | **66** |
| — de ellas, en `ci/reglas-sin-cablear.txt` | 22 | **22** (sin cambios de ID; dos comentarios reescritos) |
| Familias de reglas | 22 | **25** (`+C-POT`, `+C-FLU`, `+C-FIN`) |
| Reglas existentes modificadas | — | **9** (`C-HASH-06`, `C-HDR-05`, `C-HDR-06`, `C-HDR-07`, `C-GD-04`, `C-GD-10`, `C-REORG-07`, `C-NET-31`, `C-NET-32`) |
| Secciones nuevas en `SPEC.md` | — | **7** (§7.1.1 … §7.1.7) |
| Apartados nuevos en `TAREAS.md` | — | **1** (§2.9), más una entrada de Nivel 5 (E-56) |

**Línea base de `cargo test --workspace` que la fase 2 debe conservar: 581 pasan / 0 fallan / 6
ignorados.** Ninguna edición de este plan toca `crates/`, así que **no debería moverse**; si se
mueve, es una regresión y se informa.

**Guardianes que la fase 2 debe dejar en verde:** `ci/citas-spec.sh`, `ci/alcance-consenso.sh`,
`ci/dependencias-exactas.sh`, `ci/frontera-crates.sh`. Los tres últimos no los toca nada de este
plan; `ci/citas-spec.sh` es el que E-54 y E-55 tienen que satisfacer.

**Huellas que van a fallar a propósito, y se documentan en vez de «arreglarse»:** las
`HUELLAS.sha256` de instrumentos antiguos que firman `SPEC.md` o `TAREAS.md`. Está previsto en el
encargo y ya avisado dentro de
`veritas/consenso/puerta-cobertura-v1/HUELLAS.sha256`. `TAREAS.md` §5 ya registra cuatro
instrumentos en esa situación desde el 2026-09-14.

---

## 10 · Orden de aplicación propuesto para la fase 2

1. **`SPEC.md`, de abajo arriba**: E-46, E-45 (§17) → E-42, E-41, E-32 (§16.6) → E-26 (§14.3) →
   E-40, E-31 (§12) → E-39, E-38 (§11) → E-44, E-43 (§7.3) → E-01 y E-02…E-30 (§7.1) → E-37, E-36,
   E-35 (§6.1) → E-34 (§4.5) → E-33 (§0.2).
2. **`ci/`**: E-54, E-55. Después, `ci/citas-spec.sh` **tiene que** dar 222 y salir en verde.
3. **`TAREAS.md`**: E-56, E-53, E-52, E-51, E-50, E-49, E-48, E-47.
4. **Comprobaciones**: los cuatro guardianes, `cargo test --workspace` contra la línea base, y
   `LC_ALL=C sha256sum -c P-CIERRE/ENTRADA.sha256` + `git status --short` + `date` en `PROGRESO.md`.
5. **`INFORME.md`** con `git diff --stat`, el recuento de `ci/citas-spec.sh` antes y después, y
   **todo lo que quedó distinto de este plan**.

**Antes de tocar nada en la fase 2 se vuelve a comprobar `ENTRADA.sha256`**, para detectar si la
adenda cambió el encargo.
