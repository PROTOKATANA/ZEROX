# Piezas de código que faltan hasta una 1.0 beta — 2026-09-23

**Verificado leyendo el código**, no los documentos. `TAREAS.md` está desactualizado en varios puntos
(§H de `INVENTARIO-ABIERTO.md`).

## El estado real, en tres frases

1. **La ruta activa de ZEROX es hoy una cadena LINEAL con PoW.** `sync.rs:309` verifica
   `comprobar_pow`; `cadena.rs` maneja `BlockHeader` de 92 B con `bits`/`target`; el fork choice es
   el lineal. Es herencia de la base de código de la que partió el proyecto.
2. **Todo el DAG + PoST está escrito AL LADO y no lo ejecuta nadie.** `zx-consensus` tiene 8 494
   líneas —GHOSTDAG, cabecera DAG, PoT, rango, peso— y `ghostdag.rs` **no se referencia fuera de su
   propio crate**.
3. **No existe verificador de la prueba de espacio.** `SolucionPoas` (`preimage/dag.rs:134`) es un
   struct de datos que viaja en la cabecera; **ninguna función lo valida**. Sin KZG, sin
   proof-of-space, sin auditoría de disco.

> **Consecuencia, dicha sin rodeos: hoy ZEROX no es PoST en ningún sentido operativo.** Tiene el
> formato, los tipos y la maquinaria de consenso alrededor de una prueba que nadie comprueba.

---

## Las piezas, por capas de dependencia

### Capa 0 · Sin esto no hay consenso PoST

| # | Pieza | Depende | Tamaño | Bloquea |
|---|---|---|---|---|
| **1** | **Verificador PoAS** — KZG sobre `record_commitment`/`record_witness`, verificación de prueba de espacio, `solution_distance`. Realista: integrar `subspace-verification` | — | **Grande** | **Todo lo demás** |
| **2** | **Conectar `zx-pot` a `wire_dag`** — el AES ya está; falta el contrato contextual (`C-POT-06/07/08`) y la caché por clave. Hoy devuelve `IntegracionPotPendiente` | 1 (parcial) | Media | Validez de cabecera |
| **3** | **Derivador de contexto de flujo** — calcular `flujo`, vista de época, ancla e inyección desde `past(B)`. El núcleo de rango asume una instantánea que nadie produce | 2 | **Grande** | Las 21 reglas `C-FLU` |

### Capa 1 · Estado

| # | Pieza | Depende | Tamaño | Bloquea |
|---|---|---|---|---|
| **4** | **Cablear el UTXO a la cadena** — `adoptar`/`extender` deben aplicar el bloque, guardar `UndoData` y revertir en reorg. **La pieza existe y está probada** (`utxo.rs`, 644 líneas, con test de que aplicar+deshacer es la identidad); falta el uso | — | Media | `validar_bloque`, poda, y la pieza 7 |
| **5** | **Persistir UTXO y undo en disco** | 4 | Media | Reinicio sin resincronizar |

### Capa 2 · El DAG en la ruta activa (§2.8)

| # | Pieza | Depende | Tamaño | Bloquea |
|---|---|---|---|---|
| **6** | **`zx-node`/`zx-storage` adoptan `DagBlockHeader`** en vez del lineal de 92 B. *Indicador:* el test `el_codigo_alcanza_la_base_poas_de_556` deja de estar ignorado | 1 | **Grande** | Todo el DAG |
| **7** | **GHOSTDAG sustituye a `fork_choice`** — `Cadena` deja de ser una **lista** y pasa a ser un **árbol de puntas**; alimentar `ContextoDag` desde el almacén | 6, 4 | **Grande** | Orden, peso, reorg |
| **8** | **Retarget / controlador de rango** en la ruta (`C-HDR-06`, y las `C-RET` si se trasladan) | 7 | Media | Validez de cabecera |

### Capa 3 · Producción de bloques — **nada de esto existe**

| # | Pieza | Depende | Tamaño | Bloquea |
|---|---|---|---|---|
| **9** | **Plotter / auditor de disco** — plotear parcelas y auditarlas por slot. Realista: integrar el de Autonomys | 1 | **Grande** | Producir |
| **10** | **Productor de bloques** — selección de padres (`C-GD-10`), ensamblado desde mempool, coinbase, `pre_hash`, sello, publicación. **No hay ni esqueleto** | 7, 9 | **Grande** | Red funcional |
| **11** | **Firmante seguro** (persistir antes de firmar). Prototipo validado en `P-ZRX/P-FIRMANTE/`, fuera de `crates/` | 10 | Pequeña | — |

### Capa 4 · Red

| # | Pieza | Depende | Tamaño | Bloquea |
|---|---|---|---|---|
| **12** | **Cablear el relé compacto** — `rele_compacto.rs` existe (1 266 líneas) **y no está conectado**; migrar a `/zerox/blocks/2`. **Trampa:** `servicio.rs` despacha por `topico.contains("/blocks/")` | 6 | Media | Δ realista |
| **13** | **IBD sobre DAG** — el sincronizador pide cadenas lineales y comprueba PoW | 7 | **Grande** | Nodo nuevo |
| **14** | **Las 9 reglas `C-NET-25…33`** y la regla de Q1 (prioridad, presupuesto de reenvío, anuncio-y-petición) | 12 | Media | Saturación |

### Capa 5 · Usuario final — **todo por escribir**

| # | Pieza | Depende | Tamaño | Bloquea |
|---|---|---|---|---|
| **15** | **Firma de transacciones y generación de claves** — `firma.rs` **solo verifica** | — | Pequeña | Wallet |
| **16** | **Constructor de transacciones** (selección de entradas, cambio, tarifa) | 15, 4 | Media | Wallet |
| **17** | **`zx-wallet`** — keystore, direcciones, seguimiento de saldo. Hoy 5 líneas | 16 | **Grande** | Uso real |
| **18** | **`zx-rpc`** — JSON-RPC de consulta y envío. Hoy 5 líneas | 17, 4 | Media | Cualquier cliente |
| **19** | **`zx-scanner` / `zx-lightwalletd`** — hoy 7 líneas cada uno | 18, 20 | Grande | Cortex |

### Transversal — no son de beta

| # | Pieza | Tamaño |
|---|---|---|
| **20** | **Capa blindada entera** (Orchard/Halo2): notas, pruebas, verificación en consenso, viewing keys. Las dependencias están en `Cargo.toml` y **ningún crate las usa** | **Muy grande — es un proyecto en sí** |
| **21** | **Poda** — requisito declarado de **mainnet**, no de beta | Grande |

---

## El camino mínimo a una 1.0 beta transparente

```text
1 → 2 → 4 → 6 → 7 → 9 → 10 → 12 → 13 → 15 → 16 → 17 → 18
```

**Sin capa blindada (20) ni poda (21).** Las piezas **3** y **8** hacen falta solo si quieres las
reglas de flujo activas; sin ellas tienes un DAG PoST funcionando pero con `C-FLU` sin ejecutar.

---

## La decisión previa, antes de escribir una línea

La ruta activa es **PoW lineal heredado** y el destino es **PoST + DAG**. Eso obliga a elegir:

- **(a) Refactorizar `Cadena` en marcha** — menos código nuevo, pero cada paso deja el nodo en un
  estado híbrido y los tests existentes protegen el comportamiento **viejo**.
- **(b) Escribir la ruta DAG al lado y conmutar** — más código, pero cada mitad es coherente y la
  conmutación es un punto único y revisable. El repositorio **ya trabaja así** (`zx-consensus` tiene
  el DAG completo al lado del lineal), así que (b) es la continuación natural de lo que ya se hizo.

**Recomendación:** (b). Y el indicador de haber llegado es concreto y ya existe: el test
`el_codigo_alcanza_la_base_poas_de_556` dejando de estar ignorado.

---

## Por dónde empezar, y por qué

**La pieza 1: el verificador PoAS.**

No por tamaño —es de las grandes— sino porque **hoy la prueba de espacio no se comprueba en ninguna
parte**. Todo lo demás del proyecto es maquinaria alrededor de una prueba que nadie valida: se puede
cablear el DAG entero, conectar el UTXO y escribir el productor, y seguirías teniendo una cadena que
acepta cualquier `SolucionPoas`.

Es además la que **desbloquea más**: la 2 (PoT contextual), la 6 (cabecera DAG con sentido), la 9
(auditar disco) y la 10 (producir) dependen de ella.

**Si prefieres una victoria pequeña antes**, la pieza **4** (cablear el UTXO) es la única de la lista
que **no depende de nada** y cuyo código **ya está escrito y probado**: solo hay que usarlo. Pero
hazla sabiendo que si eliges la opción (b) de arriba, se cablea contra la ruta nueva, no contra la
lineal — o será trabajo que hay que repetir.
