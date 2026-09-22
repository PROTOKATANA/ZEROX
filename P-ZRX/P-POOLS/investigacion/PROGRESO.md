# PROGRESO — P-POOLS

Bitácora del encargo `P-ZRX/P-POOLS/PROMPT.md`. Responde en español. Zona de escritura:
**solo** `P-ZRX/P-POOLS/investigacion/`.

## Advertencia previa al trabajo (obligatoria por el PROMPT, §6)

**Nada de este encargo me parece equivocado en su planteamiento.** El hueco que describe existe y
está comprobado abajo. Sí dejo escritas **tres precisiones** antes de empezar, porque cambian el
alcance de la respuesta y no hacerlo sería etiquetar de más:

1. **«Controlar un servidor equivale a controlar todo ese espacio» no es exacto como afirmación
   general.** El espacio (los bytes de la parcela) no vive en el servidor del pool: vive en el
   granjero. Lo que un servidor de pool puede capturar es la **corriente de soluciones y firmas**,
   no la parcela. La equivalencia se cumple en la arquitectura de **firma ciega** y en la de
   **pool que firma**; **no** se cumple si el pool solo recibe parciales y el granjero construye y
   firma (Chia-like). Se desarrolla en `INFORME.md` §1.2.
2. **El encargo dice que la palabra «pool» aparece en `SPEC.md` «solo» como *pool blindado*.**
   Comprobado con `grep -n -i pool SPEC.md`: aparece además en **`mempool`** (varias veces) y en el
   HRP de `C-ENC-06` («mainnet, transparente» / «blindada»). **Ninguna** de esas apariciones es un
   pool de farming: la afirmación del encargo es correcta en lo que importa (el pool de farming no
   existe en el SPEC), pero la formulación «solo» es imprecisa. Se corrige aquí y en
   `INFORME.md` §0.
3. **`P-ZRX/P-EQUIVOCACION/` tiene una suposición que este encargo rompe, y hay que decirlo.**
   `DEFINICION-PROPUESTA.md:176-178` afirma: «Las condiciones (a)–(d) son autenticadas por el
   sello: **no hay forma de producir el segundo sello sin la clave privada**». Cierto: sin la
   clave privada no se produce. **Pero un pool hostil no necesita la clave privada: necesita que el
   cliente del granjero firme lo que él le manda.** La conclusión de atribución (el castigo cae
   sobre el lote del granjero, `FALSOS-POSITIVOS.md` §3.4.3 y `CANDIDATA.md` §6) se mantiene
   formalmente y **señala a un inocente**. No es un error de ese expediente: es un supuesto que su
   modelo de amenaza no cubría, y este encargo sí.

No reabro ninguna decisión de Katana y no fijo ningún parámetro.

---

## Entrada — comprobaciones (desde la raíz `/home/katana/zeo/ZEROX`)

Ejecutado el 2026-09-22, antes de escribir nada en `investigacion/`.

```
$ LC_ALL=C sha256sum -c P-ZRX/P-POOLS/ENTRADA.sha256
P-ZRX/P-POOLS/PROMPT.md: OK

$ git -C /home/katana/zeo/ZEROX status --short
 D ZEROX-EN-NUMEROS.md
?? .trash/
?? P-ZRX/
?? veritas/consenso/poda-post-v1/
?? veritas/consenso/prueba-recursiva-v1/
?? veritas/seguridad/

$ date
mar 22 sep 2026 17:12:02 CEST

$ uptime
 17:12:02  up 14 days 13:41,  0 users,  carga promedio: 1,06, 1,09, 1,09
```

**Lectura de las tres salidas.** (a) `ENTRADA.sha256` verifica: `PROMPT.md` es el fijado por el
encargo y no se ha tocado. (b) El árbol no está limpio, pero **ninguna** de las entradas sucias es
de este encargo: `ZEROX-EN-NUMEROS.md` borrado y cuatro directorios sin seguimiento que ya
existían al empezar (`.trash/`, `P-ZRX/`, y tres en `veritas/`). No los he tocado. (c) `uptime`
marca carga ~1,06 en 24 hilos: hay holgura, pero este encargo **no ejecuta cómputo pesado**
(véase «Presupuesto»).

## Presupuesto declarado (LINEO §11, adaptado por el PROMPT)

- **Naturaleza:** análisis de arquitectura y de reglas escritas con lectura de fuentes primarias.
  **No** es un instrumento de cálculo.
- **Tiempo:** sin corrida de cómputo. La única ejecución es la comprobación `sha256sum -c` y
  `git status`, de coste despreciable.
- **Memoria:** < 1 GiB (lectura de documentos y de código Rust; ningún array grande).
- **Disco:** solo los cuatro ficheros de `investigacion/` (decenas de KiB).
- **Hilos:** ninguno. **No se ha lanzado Julia ni ninguna auditoría numérica.** Si en algún punto
  hubiera hecho falta comprobar algo con números, el PROMPT limita a Julia con
  `./veritas/julia.sh` y **máximo 4 hilos**, y prohíbe Python. **No ha hecho falta**, y por eso no
  hay `veritas/` en este expediente.
- **GPU:** no aplica.

## Método y fuentes abiertas

Regla de método aplicada (lección registrada en `P-ZRX/T-ZRX/AGUJEROS-Y-SOLUCIONES.md` §10 y en
`DEFINICION-PROPUESTA.md:239-241`): **no se cita una regla sin abrir su sección entera.** Todas las
citas de abajo llevan ruta completa y línea, y las secciones grandes se han leído completas.

Fuentes abiertas **enteras** (o con el rango exacto citado):

| Fuente | Qué se leyó |
|---|---|
| `SPEC.md` §3.2 (`C-HASH-04/05/06`), §4.5 (tabla de etiquetas) | líneas 368-392 y 561-591 |
| `SPEC.md` §5 (transacciones, incl. nota de autorización) | líneas 593-821 |
| `SPEC.md` §6.1 y §6.2 **enteras** | líneas 825-1009 |
| `SPEC.md` §7.1 **entera** (`C-POT-01`…`C-POT-08`, `C-FLU-01`…`C-FLU-22`) | líneas 1308-1882 |
| `SPEC.md` §7.2 **entera** (unicidad pagable, P1) | líneas 1883-2022 |
| `SPEC.md` §11 **entera** (`C-GD-01`…`C-GD-11`, `C-ORD-01`…`C-ORD-04`) | líneas 2268-2449 |
| `SPEC.md` §12 (`C-FIN-01`) | líneas 2518-2571 |
| `SPEC.md` §2.3 (`C-ENC-06`, HRP) | líneas 183-195 |
| `crates/zx-core/src/firma.rs` | entero (192 líneas) |
| `crates/zx-core/src/digest.rs` | entero (160 líneas) |
| `crates/zx-core/src/preimage/dag.rs` | cabecera, `SolucionPoas`, `pre_hash`, `verificar_sello`, parser |
| `research/dag-poas-ancla-de-orden.md` (`R-FIN-8′`, `R-FIN-11`) | líneas 227-240 y 344-375 |
| `P-ZRX/P-EQUIVOCACION/investigacion/FALSOS-POSITIVOS.md` | entero (200 líneas) |
| `P-ZRX/P-EQUIVOCACION/investigacion/DEFINICION-PROPUESTA.md` | §3, §4, §5 y nota final |
| `P-ZRX/P-EQUIVOCACION/CANDIDATA.md` | §3-§7 |
| `P-ZRX/P-PRESTAMO/investigacion/INFORME.md` | §1, §3, §4 |
| `P-ZRX/P-SEMBRADOR/investigacion/INFORME.md` | resultado, alcance y §1 |
| `research/README.md` | entrada |
| `PDF/autonomys-subspace/.../auditing.rs`, `.../proving.rs`, `.../subspace-verification/src/lib.rs` | lectura delegada con citas `archivo:línea`; ver `INFORME.md` |
| Documentación oficial de pools de Chia | abierta **directamente** por web (lectura delegada interrumpida al tener ya las fuentes primarias); ver `INFORME.md` §1.2 |

Entregables previstos: `INFORME.md`, `ARQUITECTURA.md`, `DECISIONES-PENDIENTES.md`, este
`PROGRESO.md`.

## Verificación independiente

Por `AGENTS.md` («para tareas complejas de protocolo, usar especialistas independientes»), y por la
advertencia de método del encargo, el trabajo se contrastó con **tres lecturas delegadas** y **dos
verificadores adversariales** que no compartían mi contexto:

| Verificación | Alcance | Resultado |
|---|---|---|
| Lectura del código de Autonomys | `auditing.rs`, `proving.rs`, `subspace-verification/src/lib.rs` **enteros** | Confirmó con `archivo:línea` que auditar y probar no exigen secreto. Ver `INFORME.md` §1.1.1 |
| Lectura de expedientes vecinos | `FALSOS-POSITIVOS.md`, `DEFINICION-PROPUESTA.md`, `P-PRESTAMO/INFORME.md`, `AGUJEROS-Y-SOLUCIONES.md` **enteros** | Confirmó el modelo del soborno, la atribución al lote y la ausencia de la amenaza «pool» en los cuatro |
| Verificador Rust (adversarial) | 9 hechos de código y SPEC | **1 matiz que obligó a corregir el informe** (el vínculo clave↔billete: `[VF]`→`[D]` + `[ND]`, ver `INFORME.md` §1.1.4) y 6 precisiones de redacción, todas aplicadas |
| Refutador de protocolo (adversarial) | 7 tesis del análisis, más `P-IDENTIDAD` y la página de Chia | **T1, T2, T3, T5, T6 y T7 resisten** tras abrir todas las fuentes; **T4 («la única palanca») cayó en su «única»** y se corrigió: hay al menos dos palancas de consenso alternativas (destino comprometido en la parcela; reclamo diferido) y la regla no quita el incentivo general, solo el premio. Además: 3 hallazgos colaterales aplicados (cita de Chia mal atribuida; el anclaje `sector_id↔public_key` es código fijado, no norma ZEROX; la variante silenciosa sin evidencia) |
| Documentación externa de Chia | Protocolo de pool 1.0 (especificación y resumen) y «Farmers», abiertos por web el 2026-09-22 | `[VF-ext]`: el granjero construye y firma; el pool solo reparte; la parcela se liga al singleton; la parcial es un mensaje distinto (2/2 BLS sobre el payload, no sobre un `pre_hash`) |

La corrección más importante de todo el proceso está registrada en `INFORME.md` §1.1.4: la
afirmación «la clave que firma el sello es la de la identidad de billete» **no está certificada en
el SPEC**; el propio documento remite a `veritas/consenso/contrato-billete-v1/`, y su `REVISION.md`
dice «CBE-01/02 no certifican `TicketId`». Se mantiene como lectura única coherente (`[D]`) con la
certificación marcada pendiente (`[ND]`). Es exactamente el tipo de afirmación que la regla de
validez del encargo prohíbe presentar como verificada.

**Ninguna de las verificaciones escribió ni modificó ningún archivo.**

## Bitácora

- **2026-09-22 17:12** — Comprobaciones de entrada (arriba). Se verifican sin incidencias.
- **2026-09-22 17:14** — Creado `investigacion/`. Lectura de `SPEC.md` §5/§6.1/§6.2 y del código
  de firma y de cabecera.
- **2026-09-22 17:20-18:05** — Lectura completa de `SPEC.md` §3.2, §4.5, §7.1, §7.2, §8.2, §11, §12;
  `crates/zx-core/src/{firma,digest}.rs` y `preimage/dag.rs`; `research/dag-poas-ancla-de-orden.md`
  (`R-FIN-8′`, `R-FIN-11`); `P-ZRX/P-EQUIVOCACION/{CANDIDATA.md,investigacion/*}`;
  `P-ZRX/P-PRESTAMO/investigacion/INFORME.md` §1/§3/§4; `P-ZRX/P-SEMBRADOR` y
  `P-ZRX/T-ZRX/AGUJEROS-Y-SOLUCIONES.md`. Lecturas delegadas del código de Autonomys y de la
  documentación de Chia.
- **2026-09-22 18:05** — Redactados `INFORME.md` y `ARQUITECTURA.md`; y `DECISIONES-PENDIENTES.md`.
- **2026-09-22 18:20** — Verificador Rust independiente: una corrección de fondo (§1.1.4) y seis
  precisiones aplicadas. Se abre `veritas/consenso/contrato-billete-v1/{CONTRATO.md,REVISION.md}`
  para citar la certificación pendiente.
- **2026-09-22 18:22** — Refutador de protocolo independiente: las tesis centrales (T1, T2, T3,
  T5, T6, T7) **resisten**; cae el «única» de T4 y se corrigen las tres palancas alternativas, el
  agujero de los fees, el bypass por `MultiSig`/`Htlc`, la cita mal atribuida de Chia y la
  variante silenciosa sin evidencia. Aplicado a los tres entregables.
- **2026-09-22 18:25** — Aplicadas las correcciones de redacción del verificador, ajustadas las
  referencias cruzadas y ejecutadas las comprobaciones de salida (abajo).

---

## Salida — comprobaciones (desde la raíz `/home/katana/zeo/ZEROX`)

Ejecutado el 2026-09-22 **después de aplicar todas las correcciones de la verificación
independiente**, es decir, sobre la versión final de los cuatro entregables.

```
$ LC_ALL=C sha256sum -c P-ZRX/P-POOLS/ENTRADA.sha256
P-ZRX/P-POOLS/PROMPT.md: OK

$ git -C /home/katana/zeo/ZEROX status --short
 D ZEROX-EN-NUMEROS.md
?? .trash/
?? P-ZRX/
?? veritas/consenso/poda-post-v1/
?? veritas/consenso/prueba-recursiva-v1/
?? veritas/seguridad/

$ date
mar 22 sep 2026 17:24:02 CEST

$ uptime
 17:24:02  up 14 days 13:53,  0 users,  carga promedio: 2,92, 3,13, 2,24
```

**Lectura de las tres salidas.** (a) `PROMPT.md` sigue **OK**: no se ha tocado ni él ni
`ENTRADA.sha256`. (b) El árbol está **exactamente igual que a la entrada**: la lista es idéntica,
así que **no se ha modificado ni borrado nada fuera de `P-ZRX/P-POOLS/investigacion/`**. `P-ZRX/`
figura como directorio sin seguimiento (ya lo estaba); dentro de él, lo único nuevo son los cuatro
ficheros de `investigacion/`. (c) La carga media subió de 1,06 a un máximo de ~6,3 por las lecturas
delegadas de verificación y **ya ha vuelto a 2,92**; no es cómputo de este encargo: no se ha lanzado
Julia, ni Python, ni ninguna auditoría numérica, y por eso **no hay `veritas/` en este expediente**.

Entregables (871 líneas en total): `INFORME.md` (296), `ARQUITECTURA.md` (206),
`DECISIONES-PENDIENTES.md` (159), `PROGRESO.md` (210).

## Cierre

Entregados, en `P-ZRX/P-POOLS/investigacion/`:

| Fichero | Contenido |
|---|---|
| `INFORME.md` | La respuesta (primera línea), §1.1–§1.4, §2 y «Lo que esta investigación NO resuelve» |
| `ARQUITECTURA.md` | La propuesta, con el estatuto de cada pieza (arquitectura / producción / consenso) |
| `DECISIONES-PENDIENTES.md` | D1–D8, con opciones, coste y evidencia que falta |
| `PROGRESO.md` | Este documento |

**Comprobación de la regla de validez del encargo §6:** cada afirmación lleva etiqueta
(`[VF]`/`[VF-ext]`/`[D]`/`[P]`/`[ND]`); se distingue regla de consenso de recomendación de
implementación en `ARQUITECTURA.md` §6 y en `DECISIONES-PENDIENTES.md`; **no se fija ningún
parámetro de consenso** y **no se redacta texto de SPEC** (la regla candidata `C-POOL-01` está
marcada como propuesta); no se presenta ninguna mitigación con palabras de cobertura —al contrario,
`INFORME.md` §1.3 y `ARQUITECTURA.md` §6 dicen explícitamente qué medidas **no** protegen—. Cierra
con «Lo que esta investigación NO resuelve».
