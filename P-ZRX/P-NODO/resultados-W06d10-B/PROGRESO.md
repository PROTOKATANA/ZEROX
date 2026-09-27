# PROGRESO — ORDEN-W06d10-B

**Ejecutor:** DeepSeek (`deepseek-flash`, esfuerzo `high`). **Zona:** `deepseek/W06d10-B/`.
**Base:** raíz en el commit `5a07027` (incluye W06d10 migrada), verificada con
`sha256sum -c P-ZRX/P-NODO/ENTRADA-W06d10-B.sha256` en la raíz **antes** de editar.
**Inicio (orden):** 2026-09-27T23:45+02:00. **Inicio de trabajo:** ver `HORAS.log`.
**Nota de entorno:** se ha leído `V-ZRX/LINEO.md` íntegro antes de escribir código (la orden rige
código Rust; la política de veracidad, reproducibilidad, presupuesto, prohibición de Python y de
`Ok` ficticio se aplica igual).

---

## 0. INFORMES PREVIOS A EDITAR (obligación de la orden)

### 0.1 Falta de definición: «X2 sin cachear» no es alcanzable sin editar `zx-cadena` (vedado)

La decisión 1 pide que X1, X2 y X3 pasen a `Ignorar` **sin cachear el bloque como inválido**, «para
que pueda volver a juzgarse cuando la vista cambie». Tres de los cuatro efectos (sin desconexión,
sin puntuación, sin `par_penalizado`) se consiguen enteramente en `zx-node`. El cuarto —no dejar el
bloque marcado como inválido— **no** para X2:

- X2 (`MotivoBloque::ErrLimiteTerminales`) nace **dentro** de `Cadena::admitir`
  (`zx-cadena/src/cadena.rs:367`), en `dag_de_terminal_mut` (`cadena.rs:793-823`).
- `Cadena::admitir` **cachea todo rechazo**: `self.validos.insert(hash, false)` y
  `self.motivos.insert(hash, motivo)` (`cadena.rs:403-406`); y cualquier llamada posterior vuelve a
  devolver el motivo cacheado sin reevaluar (`cadena.rs:369-378`).
- `Cadena` no expone ninguna forma de olvidar/desalojar esa entrada (`zx-cadena/src/cadena.rs`,
  API pública en `lib.rs`: `Cadena` no tiene `olvidar`/`remove`/`clear`). Con `zx-cadena` **vedado**
  por el contrato, el nodo no puede quitar el bloque de `motivos` una vez que `cadena.admitir` lo
  puso.

Lo que **sí** queda garantizado dentro de la zona permitida (y es lo que prueban V1/V2): un bloque
X2 (y su reaparición) devuelve `Ignorar`, nunca `Rechazar`, no penaliza, no se desconecta y **no se
vuelve a marcar como `Rechazar`** por la vía del motivo cacheado. Lo que **no** puede garantizarse:
que, tras cambiar la vista local (p. ej. desalojar un terminal más pesado), `cadena.admitir` vuelva
a juzgarlo; seguirá devolviendo el motivo cacheado.

- **X1 sí queda sin cachear de verdad**: `validar_cabecera_pow` falla **antes** de que
  `admitir_pow_interno` inserte nada (`nodo.rs:652-666`); el bloque no entra ni en `headers_pow` ni
  en `cadena`, así que al reenviarlo con el reloj local avanzado se vuelve a juzgar de cero y se
  admite (V1).
- **X3 tampoco se cachea** en general: sus fallos ocurren antes de `cadena.admitir` (servicio,
  detector) o después de admitir (persistencia/servicio posterior); no son motivos de `cadena`.

> **Propuesta mínima si el director quiere el §0.1 completo:** autorizar una de estas dos en
> `zx-cadena`: (a) un `Cadena::olvidar(hash)` que borre `validos`/`motivos`/`por_hash`; o (b) que
> `admitir` **no** cachee `MotivoBloque::ErrLimiteTerminales` (su invalidación depende del conjunto
> local de terminales, no del candidato). Cualquiera de las dos cabe en pocas líneas; hoy no es
> posible desde los archivos permitidos.

### 0.2 V1 — Todos los caminos de un bloque de red a `VeredictoFinal::Rechazar` (tabla de partida)

Base `5a07027`, tabla de `REVISION-W06d10.md` §1 y `W06d10/PROGRESO.md` §0.2 revisada línea a línea.
**V** = la invalidez la juzga igual cualquier nodo con los padres del bloque (demostrable);
**X** = depende de la vista local (pasa a `Ignorar`); **Cache** = ¿`cadena.admitir` guarda el
motivo? (solo importa para X).

| # | Sitio (base) | Motivo | V/X | Cache |
|---|---|---|---|---|
| G1/G2 | `zx-p2p/src/servicio.rs:865-866` | bytes residuales / deserialización | V | — |
| P1/Po1 | `nodo.rs:1621-1623`, `1763-1765` | `cadena.motivo(hash)` ya cacheado | V (salvo X2, abajo) | — |
| P2/Po2 | `nodo.rs:1668-1683`, `1841-1855` | padre conocido e inválido | **V tainted** | — |
| P3a | `nodo.rs:652-661` | `branch_id`/`prev_hash`/`altura`/`bits`/PoW/monotonía | V | no |
| P3a' | `nodo.rs:652-661` | `ErrorPow::TimestampDemasiadoFuturo` (C-TS-03) | **X1** | **no** |
| P3b | `nodo.rs:717-723` | `ErrSlot`/`ErrEmision`/…/`ErrTransicion`/`ErrSinPadre` | V | sí |
| P3b' | idem | `MotivoBloque::ErrLimiteTerminales` | **X2** | **sí** |
| P3c | `nodo.rs:635-636`, `671` | `target_de_altura` / `bits` de la cabecera | V | no |
| P3d | `nodo.rs:672-673` | desbordamiento de trabajo | V | no |
| P3e | `nodo.rs:730-731`, `752` | persistencia / `asegurar_servicios_verificacion` | **X3** | no |
| Po3 | `nodo.rs:1858-1875` | forma del candidato (`BloqueDag::nuevo`) | V | no |
| Po4 | `nodo.rs:1927-1940` | `Pendiente` (contexto PoT) | Ignorar | no |
| Po5 | `nodo.rs:1950-1973` | `ImposibleSinPenalizar` | Ignorar | no |
| Po6 | `nodo.rs:1974-1988` | `Legitimo`/`Interno` (sello/PoT/PoAS/peso) | V | sí |
| Po6' | idem | `ErrLimiteTerminales` | **X2** | **sí** |
| Po6'' | idem | `ErrorNodo::Otro`/`Almacen`/`Io` locales (detector/persistencia/servicio) | **X3** | no |

**Decisión 4 — hallazgo propio, tratado igual (Ignorar):** el camino **P2/Po2 «padre conocido e
inválido»** (`nodo.rs:1668-1683` y `1841-1855`) también depende de la vista local cuando el motivo
cacheado del padre es X2: un hijo perfectamente válido se rechazaba (y se penalizaba) porque
**este** nodo había ignorado a su padre por el tope **local** de terminales. Se trata como la
familia X: si el motivo cacheado del padre no penaliza, el hijo se `Ignorar` (sin desconexión ni
puntuación). Igual ocurre con la rama P1/Po1 de motivo cacheado X2. Ninguno de los dos estaba en la
tabla de W06d10.

**Otras comprobaciones de alcance (V):** `ErrorPow` tiene un contrato explícito (`es_permanente()`,
`zx-consensus/src/error.rs:167-168`) que marca como **no** permanente solo
`TimestampDemasiadoFuturo`; el nodo lo usará en vez de hardcodear la variante. `MotivoCabeceraInvalida`
y `MotivoPotInvalido` no tienen variantes dependientes del reloj ni del conjunto local de terminales
(el `CacheDiscrepante` de PoT compara salida+portador del **mismo** billete, un defecto del
candidato); `MotivoCabeceraPendiente` ya es `Ignorar`. No se encontró otra familia X.

---

## 1. Plan de implementación

| Familia | Cambio |
|---|---|
| X1 | `clasificar_error_pow` (`rechazo.rs`): si `!e.es_permanente()` → `VistaLocal`; si no, `Interno`. `nodo.rs:659` la usa. |
| X2 | `clasificar_motivo_bloque`: `ErrLimiteTerminales → VistaLocal`. Motivo cacheado X2 y padre-inválido-X2 → `Ignorar`. |
| X3 | Errores locales (`Otro`/`Almacen`/`Io`) que llegan al borde de red → `Ignorar` + evento `bloque_red_vista_local`. Los defectos del candidato que hoy son `Otro` (P3c/P3d/Po6: `bits`, `target`, `trabajo`, `peso`) se envuelven como `BloquePropioRechazado{Interno}` para seguir penalizando (V2). |
| Clasificación | Nueva variante `ClasificacionRechazo::VistaLocal`: `es_legitimo()==false` (fatalidad propia sin cambios), `es_pendiente()==false`, `penaliza_en_red()==false`. |
| Diagnóstico | `bloque_red_vista_local` (§1 bis): `hash`, `familia`, `motivo`, `etapa`, `veredicto`; X3 visible con su motivo. |
| P2/Po2 | Si el motivo cacheado del padre es `VistaLocal`, `Ignorar` sin penalizar. |

## 2. Estado

- [x] V0: `sha256sum -c` 53/53 (raíz, antes y después); `ws.orig/` idéntico a la base.
- [x] §0.1/§0.2 antes de editar.
- [x] Código + tests V1/V2 (3 unit `rechazo` + 4 unit `nodo::pruebas_w06d10b` + 1 integración X2).
- [x] V3: E-7 semilla 101 **SUPERADO** (4 `par_penalizado`); R150 **SUPERADO** (0 `par_penalizado`).
- [x] V4: fmt verde; clippy `-D warnings` verde; suite **891/0/6**; 3 guardianes verdes; T01/T04 verdes.
- [x] `cambios.patch` + `MIGRACION.sha256` (3 archivos).

