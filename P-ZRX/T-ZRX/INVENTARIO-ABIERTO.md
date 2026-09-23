# Inventario de lo abierto en ZEROX — 2026-09-23

**Recopilado y verificado por Claude** contra el repositorio, no contra los documentos: varios
conteos de `TAREAS.md` ya no coinciden con la realidad (§H).

**Cómo leerlo.** Ordenado por **tipo**, porque cada tipo se resuelve de forma distinta: un agujero de
seguridad necesita diseño, uno de código necesita un encargo de implementación, una deuda de
evidencia necesita medición, un parámetro necesita una decisión tuya. **Al final (§I) está el grafo
de bloqueos**, que es lo que dice por dónde empezar.

---

## A · Agujeros de seguridad — **15**

Los catalogados en `P-ZRX/T-ZRX/AGUJEROS-Y-SOLUCIONES.md`, más uno descubierto hoy.

| # | Agujero | Estado |
|---|---|---|
| **A1** | Multistream de PoT | **Cerrado por regla** (`C-FLU-13/14`), sin código |
| **A2** | Varianza del rango elegible | `C-RET-01…11` **propuestas**, no en el SPEC |
| **B1** | Ventana de adelanto (`ρ > 1`) | Abierto. `ρ_max` sin cota medida |
| **B2** | Sembrador | **Abierto y sin vía viva**: la maduración es imposible de acreditar |
| **B3** | *Steering* del ancla | Acotado por calibración, no cerrado |
| **C1** | Alquiler corto / capacidad relámpago | Abierto, sin mercado medido |
| **C2** | Cobrar y borrar | Abierto, sin medir |
| **C3** | Mismo billete en ramas distintas (**doble farmeo**) | **Abierto. Nueve vías cerradas** — ver `ESTADO-DOBLE-FARMEO.md` |
| **D1** | Mayoría comprando el recurso | Inherente a toda red abierta |
| **D2** | Red y eclipse | **Abierto.** Modelado en la ronda 11b, **sin integrar ni validar** |
| **D3** | Partición de flujo sin cura | Se previene con `L` frente a `Δ`; `Δ` no medida |
| **D4** | Arranque sucinto tras poda | Abierto. Niveles descartados; prueba recursiva no examinada |
| **D5** | El reloj principal | Un núcleo entero por línea de PoT; no llega a `τ = 1 s` en la máquina de referencia |
| **D6** | SIGSEGV en `ab-proof-of-space` (ruta no paralela) | Causa raíz **no determinada** |
| **NUEVO** | **Sesgo de tasa eligiendo la clave** | El adversario elige `public_key` ⟹ `sector_id` ⟹ **qué s-bucket se le audita**; puede caer en buckets densos pagando reploteo. `verify_solution` deriva el `sector_id` de la propia solución **y no lo contrasta con nada**. **Sin medir** |

---

## B · Código — el hueco mayor, y con diferencia

| Inventario | Cuenta |
|---|---:|
| Reglas **sin una línea de código** (`ci/reglas-sin-codigo.txt`) | **53** |
| Reglas **con código pero sin cablear** (`ci/reglas-sin-cablear.txt`) | **35** |
| Puntos de consenso **que nadie ejecuta** (`ci/consenso-pendiente.txt`) | **12** |
| Tests **ignorados a propósito** | **7** |
| `TODO` en `crates/*/src` | **4** |

**Desglose de las 53 sin código:** `C-FLU` 18 · `C-NET` 7 · `C-CHK` 7 · `C-EXP` 6 · `C-UPG` 3 ·
`C-SLOT` 3 · `C-SPEC` 2 · `C-GD` 2 · y 5 sueltas.
**Desglose de las 35 sin cablear:** `C-GD` 9 · `C-POT` 8 · `C-NET` 6 · `C-HDR` 4 · `C-ORD` 3 ·
`C-FLU` 3.

**Progreso real:** existe `crates/zx-pot/` con el AES y las 8 reglas `C-POT` han pasado de «sin
código» a «sin cablear». Pero `wire_dag::verificar_justificacion_pot` **sigue devolviendo
`IntegracionPotPendiente`**: hay verificador, no hay conexión.

**Los bloques concretos:**

1. **§2.8 · Cablear el DAG a la ruta activa.** `zx-node`/`zx-storage` siguen con la cabecera lineal
   de 92 B; GHOSTDAG no sustituye a `fork_choice.rs`; el relé compacto «1+» no existe.
   *Indicador:* `el_codigo_alcanza_la_base_poas_de_556`, **ignorado a propósito**.
2. **§2.6 · Estado UTXO con datos de deshacer.** `TODO(sincronizador)` en
   `crates/zx-node/src/cadena.rs:725`. **Bloquea `validar_bloque` y la poda local.**
3. **§2.1 · Las 31 reglas de flujo.** Existen piezas aisladas (primitiva AES, adaptador de un slot,
   derivaciones puras, núcleo de rango) pero **ninguna en la ruta activa**. Falta el **derivador de
   procedencia contextual** —flujo, vista de época, ancla, salida base—: el núcleo asume una
   instantánea de `past(B)` validado **que nadie produce**.
4. **§2.7 · Las nueve reglas de transporte:** ninguna tiene una línea. Y `C-NET-07` es **código de la
   versión anterior de la regla** (deriva sobre `txid`, la regla dice `wtxid`).
5. **Cuatro pruebas de integración de red desactivadas**: convergencia de tres nodos, recuperación de
   nodo caído, sincronización simultánea, y el par que se queda atrás sin anuncio.

**Dos huecos de API que pueden forkear la red:**
- `ghostdag::Parametros` expone `ModoSp::Kaspa` como campo público: un llamante puede construir un
  nodo que forkea.
- `AlmacenGhostdag::anadir_sintetico` **no valida** y es API pública.

**Y un hueco invisible al CI, que es el peor de esta sección:** el guardián **no puede listar**
`ghostdag::admitir` porque su heurístico lo da por alcanzado (colisión de nombre con
`zx-mempool::pool::admitir`). Lo mismo con `proyectar_iteraciones`, `checkpoints_a_primitiva`,
`verificar_slot_aes`, `aleatoriedad_de_salida` y `semilla_siguiente`. **Son seis huecos reales que
ningún inventario ve.**

---

## C · Deuda de evidencia — afirmado sin medir

**La deuda principal (§2.9-8):** la **convergencia del orden no está probada** para este diseño. Las
proposiciones de GHOSTDAG valen sobre GHOSTDAG **puro**; con las tres reglas añadidas encima, «que el
orden total siga convergiendo **no está comprobado**». De ahí cuelgan `C-FLU-04` y toda §7.1.3.

**Sin medir (§2.9 a):** la vía A2 · el equilibrio adaptativo (ataca a P2, donde descansa el perfil
1a) · el coste de `C-FLU-02` para el honesto —`estimado ≈ 0`, y su comprobación era **«condición para
pasar al SPEC»** que **sigue sin cumplirse**— · la tercera rendija del presupuesto · el colateral
honesto de `C-FLU-20` · y **`Δ`, que es simulada, no medida en red**.

**Por demostrar (§2.9 b):** el sembrador (A1+C1) · **la convergencia del orden** · la existencia del
ancla en el caso patológico · la disponibilidad del ancla tras la poda.

**Evidencia sin validar (§2.9 e):** CRP-v0.2 y v0.3 **auditadas, no validadas como instrumentos ni
migradas**.

**§2.2 · La identidad del billete está supuesta, no demostrada.** Toda §7.2 —dedup, unicidad pagable,
peso— se apoya en que el billete identifique la oportunidad, y en los instrumentos **eso es una
declaración del fixture**. Es el límite H7.

**Nivel 5:** H2 (convergencia con **un** par de órdenes, sin barrido) · H4 (los «dos nodos» comparten
`EconModel` y el oráculo `context_truth`: convergen en parte **por construcción**) · H5 (**no se
comprueba `Σsalidas ≤ Σentradas`**: el fixture consume 5500 y paga 3000) · H6 (`catch ArgumentError →
Invalid` enmascara roturas de invariante como veredicto de consenso) · cuatro instrumentos firman un
`SPEC.md` que ya no existe · `DMS-v0.1`: el test del estimador **no cubre la ruta en línea** de
`run.jl` · `ANCLA-v0.2` escribe en el CWD (riesgo de **comparar una copia consigo misma**) ·
`puerta-cobertura-v1/HUELLAS.sha256`: 4 de 82 rutas no resuelven.

**Y el resultado que desactiva cifras previas:** `α_blue_work ≤ α_bytes` es **FALSO**. Ninguna cifra
de umbral expresada en «fracción de disco» significa lo que parece.

---

## D · Parámetros sin cerrar — **13 marcadores en el SPEC**

`<<PENDIENTE: P-00N>>` · `§7.3` (×2) · **`L_suelo_slots`** (×2, no fijable sin `Δ` real) ·
`entropía_externa` por red · ventana de persistencia y margen de `blue_work` · tamaño de cola y
política de desalojo · presupuesto de reenvío y política de recorte · presupuesto de CPU por par e
intervalo · **`PRESUP_PAR` y `PRESUP_NODO`** · y dos sin descripción.

**Del Nivel 3:** `Δ` solo simulada (falta **v2a** y **v2b**) · `F = 2 h` **provisional**, con
obligación declarada de bajarla · `I_slots` sin cerrar · **`ρ_max` sin cota medida** · **P-038
abierta** · génesis (parámetros y hashes por red, bootstrap explícito).

**Además:** falta **redactar la regla `C-NET` de tres partes** de Q1 (cola prioritaria, presupuesto
de reenvío, anuncio-y-petición). Sin ella, los nodos por debajo de la referencia **se saturan en vez
de recortar**.

**Y `PRESUP_NODO` se calibra en pinza con una mordaza sin derivar:** por abajo debe bastar para
verificar una rama rival completa (~11 min de CPU); **la cota superior no está derivada**.

---

## E · Decisiones esperándote — **45 declaradas, más las del SPEC**

| Origen | Nº |
|---|---:|
| `P-ZRX/P-CLAVE/investigacion/DECISIONES-PENDIENTES.md` | 9 |
| `P-ZRX/P-POOLS/investigacion/DECISIONES-PENDIENTES.md` | 8 |
| `P-ZRX/P-COBERTURA/investigacion/DECISIONES-PENDIENTES.md` | 7 |
| `P-ZRX/P-RANGO/propuesta/DECISIONES-PENDIENTES.md` | 7 |
| `P-ZRX/P-ANCESTRIA/investigacion/DECISIONES-PENDIENTES.md` | 6 |
| `P-ZRX/P-SECRETO/investigacion/DECISIONES-PENDIENTES.md` | 5 |
| `P-ZRX/P-TASA/investigacion/DECISIONES-PENDIENTES.md` | 3 |

**Más, de `TAREAS.md`:** los **cinco pendientes de `C-GD-11`** (métrica, valor, bootstrap, borde de
igualdad, relación con finalidad y poda) · **§4.1** recompensa del bloque honesto tardío (¿pérdida
definitiva o reinclusión?) · §2.5 significado de altura, orden y madurez en DAG · relajar o no
`C-NET-06` · el destino del **encargo 06** (prueba recursiva, decidido pero sin lanzar) · qué hacer
con los cuatro instrumentos que firman un SPEC inexistente.

---

## F · Defectos pendientes en instrumentos ya validados

Ninguno invalida su resultado; todos rompen trazabilidad o inducen a error.

- **P-ANCESTRIA:** «cuatro rutas independientes» son tres · 3 tests tautológicos · `modelo.jl:180`
  rotula `d = D_INF` como «el diseño de hoy», que su propio informe niega · la fila B3 (poda) **sin
  artefacto** · citas por línea desfasadas.
- **P-TASA:** encuadre del titular · precisión ficticia · `typemax` publicado como dato.
- **P-RIVAL:** el titular vale **solo para la composición aditiva** · test de la identidad central
  tautológico · conteos descuadrados (1.112 vs 1121; 5 vs 7) · **`H1` cita `IDV-01` como vía viva sin
  decir que `P-IDENTIDAD` la refutó**.
- **P-SELLO:** cita `F2-materializacion.tsv`, **que no existe**.
- **P-SECRETO:** declara 80 controles, hay 63 `@test` y **ningún artefacto** que lo respalde ·
  comentario erróneo en `referencia.jl:167`.
- **P-PUENTE:** «≈59 738» donde el real es **59.741** · desviación a Rust **no argumentada** en
  `METODO.md` ni `CONTRATO.md`.

**Patrón:** tres de seis entregas declaran conteos de test que no cuadran con sus artefactos.
Conviene exigir el artefacto de salida en los próximos encargos.

---

## G · Riesgos operativos

- **38 ficheros modificados sin commitear.** El último commit es `98abede`, con mensaje `+-+-+-+-+`.
  Mucho trabajo vivo sin punto de retorno.
- **Dos encargos escritos y sin lanzar:** `P-ANCLA-TEMPRANA` (reabre el área del ancla, cerrada el
  19/20) y `P-LATENCIA` (**desfasado**: su premisa era buscar recursos alternativos, y P-RIVAL
  respondió esa pregunta por otra vía).
- **Trabajo concurrente:** el encargo de cableado edita `crates/`, `ci/`, `SPEC.md` y `TAREAS.md` a la
  vez que los encargos de `P-ZRX/`. **Las citas por número de línea al SPEC se desplazan: citar por
  ID.**

---

## H · Lo que `TAREAS.md` dice mal

1. «Las **veintiuna** reglas afectadas» en `reglas-sin-cablear.txt` → hoy son **35**.
2. «Sube de 21 a 22» → histórico.
3. «Ninguna de las 31 tiene una línea» **contradice** a su propia §2.1, que ya reconoce piezas de PoT.
4. «`ci/citas-spec.sh` da 181 reglas» frente a «pasa de 181 a **188**» en otra sección.
5. Nunca da el total de `reglas-sin-codigo.txt` (**53**).
6. **No recoge nada de la sesión del 2026-09-22/23**: ni las nueve vías cerradas del doble farmeo, ni
   los hallazgos del puente, ni el vector nuevo. Para eso está `ESTADO-DOBLE-FARMEO.md`.

---

## I · El grafo de bloqueos — por dónde empezar

```text
CABLEAR EL NODO (§2.8 + §2.6)
   ├─> desbloquea: validar_bloque, poda local, las 35 reglas sin cablear
   ├─> desbloquea: medir Δ real en red
   │        ├─> permite fijar L_suelo_slots  (D-3.3)
   │        ├─> permite bajar F              (única palanca contra el doble farmeo)
   │        └─> permite el v2a y el v2b      (red bajo ataque)
   └─> desbloquea: cuantificar la caída del umbral
            (las cinco dependencias del puente son código inexistente)
```

**Casi todo cuelga del cableado.** Las excepciones —lo que se puede avanzar sin él— son:

1. **El frente de la oferta de `β`** (pools, alquiler, custodios): arquitectura y economía, no
   criptografía. Es el único frente con expectativa razonable contra el doble farmeo.
2. **Las 45 decisiones** que ya tienen su coste calculado y solo esperan veredicto.
3. **Los defectos de §F**, que son correcciones baratas.
4. **La deuda de evidencia demostrable sin red** (§2.9 b): sobre todo **la convergencia del orden**,
   que es «la deuda principal» y no necesita nodo para atacarse.
