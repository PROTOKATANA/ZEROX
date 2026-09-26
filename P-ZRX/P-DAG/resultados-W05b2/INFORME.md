# INFORME.md — ORDEN-W05b2 (crate `zx-post`)

**Ejecutor:** DeepSeek (`deepseek-flash`, esfuerzo `high`). **Zona:** `deepseek/W05b2/`.
**Veredicto: SUPERADO.** La pregunta falsable se sostiene: un productor honesto con un sector
ploteado sobre la historia génesis dev construye, tras un terminal PoW dev, una cabecera de
transición cuyo PoT (S1), solución PoAS y sello verifican en la puerta conjunta (`Comprobada`), y la
puerta rechaza cada cabecera alterada de §5 con su motivo, sin inventar contexto. Con **3
claves/semillas distintas**.

## 1. Qué se entregó

Crate nuevo `crates/zx-post` (D-P14), 120 ficheros migrados, `cambios.patch` (20 ficheros),
`MIGRACION.sha256` (verificado con `sha256sum -c`), `logs/`, `PROGRESO.md`, `HORAS.log`.

### API de `zx-post`

- `pot`: `ErrorContextoPot`, `proyectar_iteraciones`, `checkpoints_a_primitiva`,
  `checkpoints_a_wire`, `verificar_slot_aes`, `semilla_siguiente`, `semilla_genesis`; reexporta de
  `zx_poas::reto` `reto_desde_salida`/`aleatoriedad_de_salida` (no se duplican).
- `pot_rango`: `EstadoPot` (`PotValido`/`PotInvalido`/`PotPendiente`), `verificar_rango_pot_fase_previa`
  + `TokenRangoPot`, `verificar_rango_pot_fase_aes`, `verificar_rango_pot`, `CachePotVerificada`,
  `InstantaneaPot`, `PresupuestoPot`, `PruebaPotValidada`. D-P08: una cabecera sin padres es
  `PotInvalido(SinPadres)` sin tocar AES (§3.2).
- `cabecera_conjunta`: `EstadoCabeceraConjunta`, `HechosPost { hash, padre_seleccionado, slot,
  productor, peso, prueba_valida, requisito_declarado }`, `verificar_cabecera_conjunta`. Orden
  `C-POT-08`: padres (`zx_dag::comprobar_padres_contextual`) → PoT previa → sello → PoT AES →
  rango (`zx_dag::RangoSolucionValidado`) → PoAS (`zx_poas::verificar_solucion_poas`). El `peso` es
  `zx_dag::peso(SR)`.
- `contexto_transicion`: `ContextoTransicion` (implementa los tres rasgos), `RegistroValidado`,
  `ETIQUETA_PERFIL_DEV`, `MARCADOR_SEMILLA_S1`. `f_0 = H_flujo(ETIQUETA_GENESIS ‖ block_hash(T))`,
  `S1 = blake3(block_hash(T) ‖ ∅)[0..16)`, sin inyecciones, `D = 0`, `N(s) = N_dev`, `SR = SR_dev`,
  `es_terminal(h) ⟺ h = T`.
- `justificacion`: `leer_justificacion` (formato de `wire_dag.rs`, cota 150), `verificar_justificacion_pot`,
  `MotivoJustificacion`. **Sustituye** el `IntegracionPotPendiente` perpetuo.
- `productor`: `producir`, `ParametrosProductor`, `FuenteSoluciones`, `SolucionCandidata`,
  `clave_publica_de`. Calcula el PoT slot a slot desde S1, audita por la fuente inyectada, ensambla
  la cabecera (`padres=[T]`, `height=0`, `slot`, `pot_output`, justificación, `SR_dev`, solución,
  coinbase v3 a la clave) y firma.

## 2. Verificación (§6)

| Paso | Resultado |
|---|---|
| V1 `fmt --check` | exit 0 |
| V2 `clippy -D warnings --locked` | exit 0, 0 avisos (`--workspace --all-targets`, incluido el ejemplo de medición; `logs/V2-clippy-alltargets.log`) |
| V3 `cargo test --workspace --all-features --locked` | **519 pasan, 0 fallan, 1 ignorado** (`logs/V3-test-final.log`); 415 nombres previos presentes, 0 ausentes; ~104 nuevos |
| V4 tests portados/adaptados/retirados | 81 portados/adaptados, **0 retirados**; ningún test AES/flujo retirado (`logs/V4-tests.txt`) |
| V5 extremo a extremo (3 semillas) | 3/3 `Comprobada` + `HechosPost` coherentes (`logs/V4-V7-detalle.log`) |
| V6 negativos de §5 | 9 `Invalida(motivo)` + 1 `Pendiente(RelojFuturo)` |
| V7 pruebas espía heredadas | sello inválido no gasta AES; padres inválidos no llegan al sello; PoT pendiente no invoca PoAS; el núcleo produce prueba con el contexto dev |
| V8 `dependencias-exactas.sh`, `frontera-crates.sh` | 15 exactas; 5/5 fronteras OK, añadida `zx-post → {zx-core,zx-pot,zx-dag,zx-poas}` |

**V5 (3 semillas).** Génesis dev → 3 bloques PoW minados con `minero_dev` → `T`; historia génesis
(D-P12) → sector ploteado con la clave de verificación Ed25519 (así sello y PoS comparten clave) →
`productor` con `N_dev = 2 048`, `SR_dev = u64::MAX` → `Comprobada` en el slot 1/2/1 con 1/2/1
portadores. `HechosPost`: `padre_seleccionado = T`, `slot` = cabecera, `productor` = clave, `peso =
2^64`, `prueba_valida = true`, `requisito_declarado = 0`. Cuerpo: una coinbase v3 pagada a la clave;
compromisos recalculados OK.

**V6.** `pot_output` falso → `Invalida(Pot(PotOutputNoCoincide))`; portador de otro flujo →
`Invalida(Pot(AesFallido{slot:1}))`; sello de otra clave → `Invalida(Sello)`; sello sobre otra
prefirma → `Invalida(Sello)`; solución de otra clave/sector → `Invalida(Poas)`; `SR` distinto →
`Invalida(Rango(RangoIncorrecto))`; padres extra → `Invalida(Padres(TerminalConPadresExtra))`;
`slot = 0` (ataque con justificación vacía y `pot_output = S1`, y también reetiquetado) →
`Invalida(TransicionSinProgresoDeSlot { slot: 0, s0: 0 })`; `slot` por delante del reloj →
`Pendiente(Pot(RelojFuturo))`. Ningún pánico.

**V7.** Los negativos de §5 se comprueban además con las espías heredadas portadas (presupuesto
intacto ante padres/sello/reloj). El stub `zx_core::wire_dag::verificar_justificacion_pot` se deja
como interfaz superada (no puede depender de `zx-pot` por frontera); la ruta real es
`zx-post::justificacion`.

## 3. Medida de `N` (§6, informativa)

`cargo run --release -p zx-pot --example medir_pot`, 1 hilo (`taskset -c 3`), 11 corridas,
`N = 20 000 000` (múltiplo de 16). Máquina AMD Ryzen 9 9950X3D, 32 hilos lógicos, `uptime` carga
media 3,21 (carga ajena):

| Primitiva | Mediana | Iteraciones/s | `N` para ≈ 1 s/slot |
|---|---:|---:|---:|
| `prove` | 144,016 ms | 1,389 × 10⁸ | ≈ **138 873 760** |
| `verify` | 9,086 ms | 2,201 × 10⁹ | ≈ 2 201 286 288 |

El valor de referencia antiguo (200 032 000 → 1,561 s) implicaba ≈ 1,28 × 10⁸ iter/s; el medido es
consistente. **Es un dato para el perfil dev, no un parámetro** (el valor de red se calibra en W07,
D-P10). `logs/V9-medicion.log`.

## 4. Faltas de definición informadas antes de escribir código

1. **§3.1/§V8 vs §3.6 (`zx-farmer`).** La frontera explícita excluye `zx-farmer`; `productor.rs`
   abstrae la parcela en `FuenteSoluciones` y el puente real a `ParcelaDisco` vive en los tests
   como **dev-dependency** (W06 lo aportará en el nodo). `zx-consensus` también es dev-dependency
   (excepción §3.1 para el génesis/`minero_dev`).
2. **§3.5 (`justificacion`).** `ContextoVerificacionPot` no aporta `pasado` ni `salida_validada`;
   la verificación real se hace sobre `InstantaneaPot` (lo que `pot_rango` exige), según la propia
   orden. El stub de `zx-core` no se toca.
3. **§3.1 (reto).** `aleatoriedad_de_salida` se reutiliza de `zx_poas::reto`, no se recopia.
4. **§3.4/§3.6 (rango).** D-P11 fija `SR` esperado constante; `rango_esperado` devuelve `Ok(sr_dev)`
   y no se añaden variantes a `zx-dag`.
5. **§3.3 (`HechosPost`).** Se implementan exactamente los campos listados; la salida auditada y la
   distancia quedan internas.

## 5. Lo que esta orden NO demuestra

- **Estado:** no hay UTXO, emisión, garantía ni `requisito(B)`; `requisito_declarado = 0` es un
  marcador dev (TRN-07 sin controlador).
- **Garantía / admisión en nodo:** `Comprobada` no inserta en GHOSTDAG, no aplica cuerpo/coinbase,
  no persiste ni publica; `past(B)` es el que aporta el test, no un índice de admitidos (W06).
- **Red:** no hay P2P, sincronización, reorganización, reloj de red ni `F_slots`.
- **Sesgo de semilla (A-07):** S1 = `blake3(block_hash(T))` es un marcador; no se analiza sesgo ni
  manipulación del terminal.
- **Seguridad de los parámetros dev:** `N_dev = 2 048` y `SR_dev = u64::MAX` son de test; el valor
  de red (≈ 1,39 × 10⁸ iter/s ⇒ N ≈ 1,39 × 10⁸ para 1 s) es una medición de esta máquina con carga
  ajena, no una calibración de red.
- **Historia de más de un segmento, SEC-A, EvidenceTx, controladores de retarget/rango:** fuera de
  alcance (D-P12, D-P11, IPA).
- **`slot > s_0` (TRN-08 · CONTRATO §1):** la regla no tenía punto de enforcement especificado en
  `pot_rango` (que no conoce el terminal) ni en `zx-dag`; se aplica en la puerta
  (`MotivoCabeceraInvalida::TransicionSinProgresoDeSlot`) tras los padres y antes de tocar AES, y
  cubre el ataque de slot 0 con justificación vacía. Se declara como decisión de la orden (no se
  añade la variante a `zx-dag`).

## 6. Resumen final (≤ 40 líneas)

```
Veredicto: SUPERADO. zx-post (D-P14) con pot, pot_rango, cabecera_conjunta, contexto_transicion,
justificacion y productor. Frontera §V8 respetada (zx-post -> {zx-core,zx-pot,zx-dag,zx-poas};
zx-farmer/zx-consensus solo dev-dependency).
V1 fmt OK. V2 clippy --workspace --all-features --locked, 0 avisos.
V3 519 pasan / 0 fallan / 1 ignorado; 415 nombres previos presentes, 0 ausentes; ~104 nuevos.
V4 81 tests antiguos portados/adaptados, 0 retirados; ningún test AES/flujo retirado.
V5 3/3 semillas: génesis dev + 3 bloques PoW -> T -> historia -> sector -> productor ->
   cabecera de transición -> puerta conjunta Comprobada -> HechosPost coherentes.
V6 9 negativos Invalida (pot_output, portador ajeno, sello x2, solución x2, SR, padres extra,
   slot 0 -> TransicionSinProgresoDeSlot) + 1 Pendiente (reloj futuro). Sin pánicos.
V7 espías heredadas: sello inválido no gasta AES; padres inválidos no llegan al sello;
   PoT pendiente no invoca PoAS; el núcleo sí produce prueba con el contexto dev.
V8 dependencias-exactas 15 OK; frontera 5/5 OK.
Medición §6 (release, 1 hilo, 11 corridas, Ryzen 9 9950X3D, carga 3,21): prove 1,389e8 iter/s ->
   N(1 s) ~ 138 873 760; verify 2,201e9 iter/s -> N(1 s) ~ 2 201 286 288. Dato de perfil dev.
Cargo.lock solo añade zx-post (ningún par externo cambia).
No demuestra: estado/UTXO, garantía, admisión, red, sesgo de semilla, seguridad de parámetros dev,
historia >1 segmento. La regla TRN-08 slot > s_0 se aplica en la puerta (variante propia).
Cambios: cambios.patch (20 ficheros), MIGRACION.sha256 (120 huellas, -c OK), logs/.
Presupuesto 3 h / 8 hilos / 16 GiB / 40 GiB no agotado (~41 min).
```
