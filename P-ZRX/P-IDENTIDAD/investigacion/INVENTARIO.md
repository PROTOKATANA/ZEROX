# INVENTARIO — todo lo que usa la identidad de billete

Una fila por **regla, vector de prueba o fragmento de código**. Columnas: qué propiedad de la identidad
necesita, si la **conserva / refuerza / pierde** con **B** (IDV-01, sin `chunk`, con `piece_offset`) y con
**C** (candidata, `H(dominio, slot, PlotBatchId, sector, piece_offset)`), y qué habría que **reescribir**.

Etiquetas: `VF` verificado en fuente · `EN` enumerado/medido con este instrumento · `DE` derivado ·
`ND` no determinado. Las rutas son desde la raíz `/home/katana/zeo/ZEROX`.

**Regla de lectura, y es la conclusión del inventario:** *dentro de una misma historia* A, B y C
particionan igual (porque un reto fija un bucket y cada pieza aporta un chunk — E2/E3 de `INFORME.md` §2),
así que **toda** fila marcada «igual dentro de una historia» ya está resuelta y no exige trabajo de
migración; las únicas filas que cambian son las que cruzan **ramas con retos distintos**.

---

## A · Reglas de SPEC

| # | Regla | Ruta | Propiedad que necesita de la identidad | Con B | Con C | Qué reescribir |
|---|---|---|---|---|---|---|
| A1 | **`C-GD-07` / R-FIN-11 — la tupla** | `SPEC.md:2315-2321` | definición: qué soluciones son «el mismo derecho» | **cambia** el campo `chunk` por `dominio` + `piece_offset` | igual que B, más `PlotBatchId` | la tupla y su justificación; el resto de `C-GD-07` no cambia |
| A2 | **`C-GD-07` U2 (invalidez)** | `SPEC.md:2317-2318` | unicidad en `padres(B)` y en el pasado estricto | **igual dentro de una historia** (`EN`: 27/27 casos); más agresiva entre ramas | como B | nada en la regla; **sí** en `C-GD-10` (A11) |
| A3 | **`C-GD-07` U3″ dinámica** | `SPEC.md:2319-2321` | unicidad entre azules del mergeset, en orden `C-GD-05` | **igual dentro de una historia** (`EN`) | como B | nada |
| A4 | **P1 · unicidad pagable** | `SPEC.md:1891-1896` | una sola copia pagable por clave | **igual dentro de una historia**; agrupa más entre ramas | como B | nada |
| A5 | **`C-ORD-02` · desempate entre copias** | `SPEC.md:1984-1987` | `rank` total + «azul primero» | **igual** (misma `rank`, misma regla) | como B | nada |
| A6 | **`C-ORD-03` · orden de aplicación** | `SPEC.md:1989-1993` | no confundir selección con aplicación | **igual** | como B | nada |
| A7 | **Contexto persistente de billetes consumidos** | `SPEC.md:1898-1908` | clave estable para el conjunto consumido | **cambia el contenido** del conjunto, no la regla; la reconstrucción en reorg no cambia | como B | documentar que la clave cambia (los conjuntos persistidos de una red migrada no son comparables) |
| A8 | **Reorg libera el billete** (`fixture_reorg_libera_billete`) | `SPEC.md:1900-1908`; `veritas/consenso/comprobacion-decisiva-v1/src/validacion.jl:246-273`; test en `test/runtests.jl:194-231` | clave de billete + reconstrucción desde génesis | **conserva**: la regla es de contabilidad, no de definición | conserva | nada. **Vector de prueba**: el fixture declara `ticket::UInt64`; **caduca por semántica** si se quiere que pruebe la nueva tupla (habría que derivarlo) |
| A9 | **`fixture_desempate_color`** | `comprobacion-decisiva-v1/src/validacion.jl:189-212` | color/`rank` entre copias del mismo billete | **conserva** (P1 no cambia) | conserva | nada |
| A10 | **R-FIN-8′ (cobro)** | `SPEC.md` §7.2 (1931-1961) | qué cobra y qué no | **igual dentro de una historia**; `rojo_U3` puede aparecer entre ramas | como B | nada |
| A11 | **`C-GD-10` · qué puntas descarta el productor** | `SPEC.md:2335-2356` | evitar que el productor emita un bloque inválido por su elección de padres | **se refuerza la necesidad**: hay que añadir el descarte de puntas que violarían U2 | como B | **SÍ** — hallazgo nuevo de este trabajo (`INFORME.md` Resultado 7). Hoy la lista no incluye U2 ni `C-GD-05` |
| A12 | **`C-GD-11` · bounded merge depth** | `SPEC.md:2401-2409` | validez de la fusión, no pago | **igual** | igual | nada (sigue `<<PENDIENTE>>` por otras razones) |
| A13 | **`C-FLU-12` · entropía de la inyección** | `SPEC.md:1673-1686` | **dos copias del mismo billete ⇒ misma entropía** | **PIERDE**: `chunk` deja de estar en la identidad ⇒ dos copias pueden dar entropías distintas (`EN`: `flujo-divergente-misma-pieza`, B y C violan; A no) | pierde igual | **SÍ** — el *«Invariante de no-equivocación del inyector»* de `SPEC.md:1682-1686` debe reescribirse o imponerse por otra vía |
| A14 | **Coste escrito de D-F1 en §7.1.4** | `SPEC.md:1688-1698` | dos billetes distintos con el mismo `chunk` ⇒ misma entropía | **no cambia de tamaño** (sigue siendo colisión de 32 B); B **añade** el caso inverso (misma identidad, dos entropías) | igual | aclarar que el coste de A no se hereda ni se agrava, y que B/C añaden otro |
| A15 | **`C-FLU-13(3)` · validez absoluta** | `SPEC.md:1701-1704` | todo el pasado válido | **se vuelve operativa**: con B/C un bloque inválido arrastra a su descendencia (`EN`: 4 660 / 31 015 bloques) | igual | nada en la regla; el coste va a A11 |
| A16 | **R-FIN-13′ · retarget y emisión cuentan el conjunto pagable** | `SPEC.md:1885-1887` | mismo conjunto que P1 | **igual dentro de una historia** (`EN`: 27/27) | igual | nada |
| A17 | **`C-REORG-01/02` · undo data** | `SPEC.md:2454-2462` | reconstruir el UTXO | **no usa la identidad de billete** (es UTXO: `crates/zx-storage/src/utxo.rs:30-41,198-220,245-262`) | igual | nada |
| A18 | **`C-HDR-01` §6.1 · cabecera** | `SPEC.md:831-851` | `piece_offset [154,156)` y `chunk [252,284)` existen | **no requiere campo nuevo**: B usa un campo que ya viaja | **C sí**: `PlotBatchId` no existe | nada para B; para C, formato nuevo **y** compromiso en la prefirma |
| A19 | **`C-HDR-04` · sello Ed25519** | `SPEC.md:974-988` | la firma liga la solución al bloque | **igual** | igual | nada |
| A20 | **§14 · activación de cambios de consenso** | `SPEC.md:2728-2798` | cambio con activación, no silencioso | **aplica**: un replay bajo B puede invalidar bloques válidos bajo A | aplica | la vía de activación, si se adopta |

---

## B · Código de `crates/` (Rust)

**Hecho que domina este apartado (`VF`):** **no existe en `crates/` ninguna función que calcule la
identidad de billete.** `grep -rE 'R-FIN-11' crates/ --include=*.rs` → 0 coincidencias. La identidad
llega **ya comprimida** como `u64` desde fuera.

| # | Sitio | Qué hace | Propiedad que necesita | Con B / C | Qué reescribir |
|---|---|---|---|---|---|
| B1 | `crates/zx-core/src/preimage/dag.rs:46-83` | anchos de campo y `TAMANO_PREFIJO_FIJO = 492` | los bytes de la solución entran en la prefirma | **igual** | nada |
| B2 | `crates/zx-core/src/preimage/dag.rs:132-153` | `SolucionPoas` con los 9 campos | la identidad es un subconjunto; el tipo no la deriva | igual | nada |
| B3 | `crates/zx-core/src/preimage/dag.rs:171-183` | orden canónico de serialización | orden determinista | igual | nada |
| B4 | `crates/zx-core/src/preimage/dag.rs:324-350` | `DagBlockHeader`; `slot` vive aquí | `slot` entra en la tupla | igual | nada |
| B5 | `crates/zx-core/src/preimage/dag.rs:396-420` | `pre_hash`/`block_hash`/`verificar_sello` | la identidad **no** entra en el hash | igual | nada |
| B6 | `crates/zx-core/tests/vectores_dag.rs:62-77` | vector congelado con `chunk` y `piece_offset` | serialización | **no caduca** (es de bytes) | nada |
| B7 | `crates/zx-core/tests/oraculo_julia.rs:68-77` | mismo vector para el oráculo Julia | serialización | no caduca | nada |
| B8 | `crates/zx-consensus/src/ghostdag.rs:136-151` | `BloqueGhostdag.identidad: u64` «ya comprimida; 0 = sin billete» | la identidad es un `u64` aportado desde fuera | **hay que definir la compresión nueva** | contrato de quien alimenta; el módulo no cambia |
| B9 | `crates/zx-consensus/src/ghostdag.rs:559-568` | **U2** | unicidad en el pasado | igual | nada |
| B10 | `crates/zx-consensus/src/ghostdag.rs:630-640` | `pasado_contiene_ident` | cierre transitivo | igual | nada |
| B11 | `crates/zx-consensus/src/ghostdag.rs:886-894`, `:966-974` | **U3″ dinámica** (kernel y referencia) | identidad azul heredada o vista antes | igual | nada |
| B12 | `crates/zx-consensus/src/ghostdag.rs:1046-1078` | `acumular`: `blue_idents` | conjunto persistente de identidades azules | igual | nada |
| B13 | `crates/zx-consensus/src/ghostdag.rs:454-472` | **`seleccionar_copia` (P1)** | agrupar copias; azul primero; menor `rank` | igual | nada |
| B14 | `crates/zx-consensus/src/ghostdag.rs:508-535` | `orden_aplicacion` (salta `RojoU3`) | copias U3 inertes | igual | nada |
| B15 | `crates/zx-consensus/src/error.rs:323-328` | `BilleteDuplicadoU2` | identidad reportable | igual | nada |
| B16 | `crates/zx-consensus/tests/ghostdag_rust.rs:718-781` | sección 7 «U2 frente a U3″» | U2 invalida; U3″ colorea | **caduca por semántica** si el fixture construye identidades a mano para la tupla vieja | revisar los `ident` de los fixtures |
| B17 | `crates/zx-consensus/tests/ghostdag_prop.rs:32-56` | `identidad: u64::from(idents[i % n])` | identidad sintética | no caduca | nada |
| B18 | `crates/zx-consensus/tests/ghostdag_oraculo.rs:191-207` | identidad desde el oráculo GDR | — | no caduca | nada |
| B19 | `crates/zx-consensus/tests/disponibilidad_causal_multivista_modelo.rs:49,215-240,263-284,486-488` | DCM-v0.1: `TicketId(u64)`, `consumed`, undo | dedup por identidad + contexto persistente + reorg | **regla igual**; los fixtures declaran `TicketId` a mano | los `TicketId` de los fixtures dejan de corresponder a la tupla |
| B20 | `crates/zx-consensus/tests/contrato_billete_modelo.rs:139-163,176-231,239-272` | CBE-v0.1: `ticket: String`, ledger, undo, `switch_branch` | identidad textual atada a `slot` | regla igual | ídem |
| B21 | `crates/zx-consensus/tests/ventana_retarget_causal_modelo.rs:56,71-80,240-307` | `ticket: u64`, `tickets: BTreeMap` | una inscripción por identidad | regla igual | ídem |
| B22 | `crates/zx-p2p/src/id_corto.rs:116-118` | SipHash sobre la cabecera → **ID de bloque** | **no es la identidad de billete** | no cambia | nada |
| B23 | `crates/zx-p2p/src/rele_compacto.rs:349` | dedup por ID corto de bloque | no es la identidad | no cambia | nada |
| B24 | `crates/zx-storage/src/utxo.rs` | undo de UTXO | no es la identidad de billete | no cambia | nada |
| B25 | `ci/reglas-sin-cablear.txt:68` | «C-GD-07 U2 y U3″ dinámica… sin cablear» | — | — | actualizar la entrada al cambiar la tupla |
| B26 | `ci/reglas-sin-codigo.txt:247-248` | «C-FLU-12 …» sin código | — | — | actualizar si A13 cambia |
| B27 | `ci/consenso-pendiente.txt:31-38` | puntos de entrada de `ghostdag` que nadie ejecuta | — | — | actualizar |
| B28 | `ci/citas-spec.sh:56-58` | extrae solo IDs `**XXX-YYY-NN**` | **`R-FIN-*` no está vigilado por el guardián** | igual | considerar añadir R-FIN-11 al guardián |

**Nota de discrepancia (`VF`):** `piece_offset` **no** está en la tupla de `C-GD-07` (`SPEC.md:2316`)
pero **sí** en la cabecera y en la prefirma, y la clave de deduplicación de **Autonomys** incluye
**ambos** (`pallet-subspace/src/lib.rs:1591-1597`: `(public_key, sector_index, piece_offset, chunk,
slot)`). `C-GD-07` ya es **más gruesa** que la referencia en `piece_offset`. `TAREAS.md:227-230` lo
declara: «la identidad del billete está supuesta, no demostrada».

---

## C · Instrumentos de `veritas/` que la usan

| # | Instrumento | Qué identidad usa hoy | Con B / C | Qué reescribir |
|---|---|---|---|---|
| C1 | `veritas/consenso/ghostdag-rank-v1/` (GDR-v0.2) | `ident::UInt64` por bloque, `u2`, `u3_mode` | **paramétrico**: acepta cualquier clave; no cambia | nada (solo los `ident` de los fixtures) |
| C2 | `veritas/consenso/comprobacion-decisiva-v1/` | `ticket::UInt64` declarado, sin criptografía; límite H7 (`INFORME.md:133-140`) | regla igual | los fixtures; **documentar** que el vínculo billete↔oportunidad no está probado ahí |
| C3 | `veritas/consenso/contrato-billete-v1/` | `TicketId` opaco; tupla «punto de partida a estudiar», bloqueante en `CONTRATO.md:49-50` | **B acerca la tupla a lo que ya estudia** | nada; sigue siendo `propuesto` |
| C4 | `veritas/consenso/identidad-disponibilidad-v1/` (IDV-01) | la tupla **B**; unicidad de `chunk` «condicionada» (`IDENTIDAD.md:32-33`) y bloqueante de retos (`CONTRATO-VALIDACION.md:34-37`) | **es B** | el bloqueante **no** se levanta con B (`INFORME.md` Resultado 12/§8) |
| C5 | `veritas/consenso/identidad-copias/INFORME.md` | no define identidad; verifica la de Autonomys y refuta claims | **aporta la cita clave**: Autonomys deduplica con `(pk, sector, piece_offset, chunk, slot)` | nada |
| C6 | `P-ZRX/P-EQUIVOCACION/investigacion/veritas/consenso/equivocacion-v1/` | `spec07` / `idv01` / `candidata`; `κ` | **su rejilla «misma-parcela» sobreestima B** (`INFORME.md` §3, Resultado 12) | la rejilla: añadir `P(piezas/sector)` y la columna «forzado» |
| C7 | `P-ZRX/P-PRESTAMO/investigacion/` | tabla §3.3 con A / B | **su columna de B necesita la condición de F4** | la tabla de §3.3 y su D1 |
| C8 | `veritas/seguridad/coste-rama-privada-v1/` | U2/U3″ entre ramas disjuntas (`INFORME.md` §6) | **mide exactamente el hecho que F4 necesita** | nada; citarlo como límite |
| C9 | `P-ZRX/P-IDENTIDAD/investigacion/veritas/consenso/identidad-billete-v1/` | **A, B y C**, sobre GDR-v0.2 | — | este instrumento |

---

## D · Lo que **NO** usa la identidad (verificado para no confundir)

| Sitio | Por qué no |
|---|---|
| `crates/zx-storage/src/utxo.rs` (todo) | `consumidos` es de **outpoints**, no de billetes (`C-REORG-01`) |
| `crates/zx-node/src/cadena.rs:300-395` | adopción/reorg de cabeceras; no toca billetes |
| `crates/zx-p2p/src/id_corto.rs`, `rele_compacto.rs` | deduplican por **ID corto de bloque** |
| `C-HDR-05` / `C-FLU-02` (cota de slot) | validez estructural; no miran la identidad |
| `C-GD-11` | validez de fusión; no cambia quién cobra |
| `crates/zx-core/tests/vectores_dag.rs`, `oraculo_julia.rs` | vectores de **serialización**; la identidad no entra en el hash |
