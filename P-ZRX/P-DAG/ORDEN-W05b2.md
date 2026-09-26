# ORDEN-W05b2 — Crate `zx-post`: PoT, puerta conjunta y bloque de transición real

## 1. Identidad y contexto

- **ID:** W05b2. **Estado:** redactada 2026-09-26. **Director:** Claude. **Ejecutor:** DeepSeek.
- **Zona (única escribible):** `/home/katana/zeo/ZEROX/deepseek/W05b2/`.
- **Objetivo único:** portar la verificación PoT y la puerta conjunta de cabecera PoST de `9681061`
  a un crate nuevo `zx-post` (D-P14, abajo), anclar el contexto PoT en el terminal PoW
  (D-P09…D-P11), cablear la verificación de la justificación PoT del wire DAG (en el código antiguo
  `wire_dag.rs:375-380` devolvía siempre `IntegracionPotPendiente`), y producir y verificar de
  extremo a extremo el **primer bloque PoST real** hijo de un terminal dev.
- **Pregunta falsable:** «Un productor honesto con un sector ploteado sobre la historia génesis dev
  construye, tras un terminal PoW dev, una cabecera de transición cuyo PoT (semilla S1 de D-P09),
  solución PoAS y sello verifican en la puerta conjunta (`Comprobada`), y la puerta rechaza cada
  cabecera alterada de §6 con su motivo, sin inventar contexto.» Se refuta con un rechazo de la
  honesta o una aceptación de una alterada.
- **Desbloquea:** W06a/W06d (nodo).

## 2. Autoridad y entradas

Lee íntegros: este archivo; `V-ZRX/LINEO.md`; `P-ZRX/P-DAG/DECISIONES-W05.md`;
`P-ZRX/P-DAG/REVISION-W05a.md`, `REVISION-W05b1.md`; `P-ZRX/P-RED-DEV/PERFIL-DEV-v0.md` §4;
`P-ZRX/P-TRANSICION/CONTRATO-v0.md` (TRN-06…TRN-08, «Ratificaciones v0.1»). Base: el workspace de
la raíz (`zx-core`, `zx-pot`, `zx-consensus` de W04 —**otra orden, W03, lo modifica en paralelo: no
dependas de cambios nuevos en él**—, `zx-dag`, `zx-poas`, `zx-farmer`). Código antiguo (solo
lectura, `git show 9681061:`): `crates/zx-consensus/src/{pot.rs, pot_rango.rs, cabecera_conjunta.rs}`
y sus tests (`tests/{pot_slot.rs, pot_rango.rs, pot_derivaciones.rs, cabecera_conjunta.rs, flow.rs}`
y los módulos de test internos); `crates/zx-core/src/wire_dag.rs` (justificación);
`crates/zx-node/src/{bootstrap_dag_dev.rs, contexto_genesis_dag_dev.rs, perfil_primer_hijo_dag_dev.rs,
puerta_primer_hijo_dag_dev.rs}` y `crates/zx-node/tests/{perfil_primer_hijo_dag_dev.rs,
puerta_primer_hijo_dag_dev.rs, farmer_disco.rs}` como **plantilla** del contexto del primer hijo.
Medida antigua de referencia (otra fecha y carga): `research/dag-poas-ancla-de-orden.md` de `9681061`
(«`prove` = 1,561 s/slot … 200 032 000 iteraciones … Ryzen 9 9950X3D»).
Entrada congelada: `P-ZRX/P-DAG/ENTRADA-W05b2.sha256`, al empezar y como último paso.

## 3. Decisiones ya tomadas por el director

1. **D-P14 · Crate `zx-post`** (depende de `zx-core`, `zx-pot`, `zx-dag`, `zx-poas`; **no** de
   `zx-consensus` salvo que el génesis dev lo exija para los tests, en cuyo caso solo como
   `dev-dependency`). Contenido: `pot.rs` (funciones puras antiguas **excepto**
   `reto_desde_salida`, que ya vive en `zx_poas::reto` y se reutiliza), `pot_rango.rs`,
   `cabecera_conjunta.rs`, `contexto_transicion.rs`, `justificacion.rs`, `productor.rs`.
2. **`pot_rango.rs`** sin la rama de génesis (`pot_rango.rs:555-572` antiguo): una cabecera sin padres
   ya la rechaza `zx-dag` (D-P08); aquí devuelve `PotInvalido(SinPadres)` sin tocar AES. El resto
   (fases previa y AES, caché, `C-FLU-14` sobre el pasado) **sin cambio de lógica**.
3. **`cabecera_conjunta.rs`**: mismo orden `C-POT-08` (padres → PoT previa → sello → PoT AES → rango →
   PoAS) y misma clasificación `Comprobada / Invalida / Pendiente`; padres con
   `zx_dag::comprobar_padres_contextual`; PoAS con `zx_poas::verificar_solucion_poas`. Añade la
   salida `HechosPost { hash, padre_seleccionado, slot, productor, peso, prueba_valida: true,
   requisito_declarado: 0 }` (el `peso` = `w(SR)` de `zx-dag`) para el motor de estado.
4. **`contexto_transicion.rs` (D-P09…D-P11):** `f₀ = H_flujo(ETIQUETA_GENESIS ‖ block_hash(T))`,
   `semilla(f₀, 0) = blake3(block_hash(T) ‖ ∅)[0..16)` (entropía externa vacía en dev), salida
   confiada del slot 0 = esa semilla; un solo flujo sin inyecciones; `D = 0`; `N(s) = N_dev`
   constante recibida por parámetro; `SR` esperado = `SR_dev` constante recibida por parámetro;
   `es_terminal(h) ⟺ h = block_hash(T)`; el pasado validado lo suministra el llamante (en los
   tests, `T` y los bloques PoST que el propio test valide). Etiquetado **dev** y marcador S1
   (A-07 abierto).
5. **Justificación PoT del wire (`justificacion.rs`):** decodifica y verifica los portadores de la
   cabecera DAG con el formato de `wire_dag.rs` (cota `MAX_BUNDLES_POT = 150` del formato) usando
   `pot_rango`; sustituye el `IntegracionPotPendiente` perpetuo. Si el formato antiguo no permite
   verificar sin una decisión nueva, **para** e informa.
6. **Productor (`productor.rs`):** dado `T`, una parcela (`zx-farmer`), una clave Ed25519 dev y los
   parámetros: calcula el PoT slot a slot desde S1 (`zx-pot::prove` con `N_dev`), audita la parcela
   con `zx_poas::reto(salida, slot)` hasta hallar una solución, construye la cabecera (`padres = [T]`,
   `height = 0` (F-03), `slot`, `pot_output`, justificación, rango, campos de la solución, compromiso
   del cuerpo de una coinbase v3 a su clave), la firma y la devuelve con su cuerpo.
7. **`N_dev` de prueba** en los tests: pequeño (p. ej. 2 048 iteraciones, múltiplo de 16) para que el
   test sea rápido; **no** es el valor de la red.

Si algo no se puede cumplir tal cual, **para** e infórmalo antes de improvisar.

## 4. Contrato de ejecución

Patrón W02/W04 (`ws.orig/`, `ws/` con enlace `ws/PDF` al clon de la raíz excluido de la migración,
`cambios.patch`, `MIGRACION.sha256`, `logs/`, `INFORME.md`, `PROGRESO.md`, `HORAS.log`); caché de
cargo copiable de `deepseek/W05b1/.cargo-home`. `CARGO_BUILD_JOBS=8`, `RUST_TEST_THREADS=8`. Sin
cambiar versiones del `Cargo.lock`.

## 5. Modelo de amenaza

Productor hostil: `pot_output` falso; justificación con portadores de otro flujo o de otro slot;
sello de otra clave o sobre otra prefirma; solución de otra clave, sector o historia; `SR` distinto
del esperado; padres extra; `slot = 0`; `slot` por delante del PoT verificable (debe quedar
`Pendiente`, no inválido, como en el diseño antiguo). Ningún pánico.

## 6. Verificación

| Paso | Qué | Criterio |
|---|---|---|
| V1–V2 | `fmt --check`, `clippy -D warnings --locked` | limpio |
| V3 | `cargo test --workspace --all-features --locked` | todo lo previo pasa con su nombre + lo nuevo |
| V4 | Tests antiguos de PoT y puerta portados, adaptados (génesis → terminal) o retirados, con motivo | lista completa; ningún test de la lógica AES/flujo retirado |
| V5 | Extremo a extremo: génesis dev → cadena PoW dev minada con `minero_dev` hasta una altura dada → `T` → historia génesis → parcela → productor → cabecera de transición → puerta conjunta = `Comprobada` → `HechosPost` coherentes | pasa, con 3 claves/semillas distintas |
| V6 | Negativos de §5, cada uno con su resultado (`Invalida(motivo)` o `Pendiente(motivo)`) | todos |
| V7 | Pruebas espía heredadas: sello inválido no consume AES; padres inválidos no verifican sello; PoT pendiente no invoca PoAS | pasan |
| V8 | `dependencias-exactas.sh`, `frontera-crates.sh` (añade `zx-post → {zx-core, zx-pot, zx-dag, zx-poas}`) | OK |

**Medición informativa** (LINEO §7; máquina con carga ajena: registra `uptime`): iteraciones AES por
segundo de `prove` y `verify` de `zx-pot` en perfil `release`, 1 hilo, mediana de ≥ 10 corridas, y el
`N` que daría ≈ 1 s por slot en esta máquina. Es un dato para el perfil dev, no un parámetro.
**Prohibido Python.** Presupuesto: **3 h, 8 hilos, 16 GiB, 40 GiB de disco**.

## 7. Entregables y límites

`ws/`, `cambios.patch`, `MIGRACION.sha256`, `logs/`, `INFORME.md` (veredicto; API de `zx-post`;
tests portados/adaptados/retirados; medida de `N`; «Lo que esta orden NO demuestra»: estado,
garantía, admisión en nodo, red, sesgo de semilla, seguridad de los parámetros dev), `PROGRESO.md`,
`HORAS.log`. Resumen final ≤ 40 líneas. DeepSeek `deepseek-flash`, esfuerzo `high`; LINEO antes del
código; nada fuera de la zona; sin commit ni push; sin secretos; ningún `Ok` ficticio.

## Lanzamiento

    mkdir -p /home/katana/zeo/ZEROX/deepseek/W05b2 && cd /home/katana/zeo/ZEROX/deepseek/W05b2 && \
    ( set -a; . /home/katana/torio/deepseek-harness/.env >/dev/null 2>&1; set +a; \
      node /home/katana/torio/deepseek-harness/apps/cli/lib/bin.js --profile headless \
      "Orden W05b2. Lee íntegro /home/katana/zeo/ZEROX/P-ZRX/P-DAG/ORDEN-W05b2.md y cúmplelo. Antes de escribir código, lee íntegro /home/katana/zeo/ZEROX/V-ZRX/LINEO.md. Si detectas una falta de definición, infórmala antes de editar." \
      > ../W05b2-dsh.stdout 2> ../W05b2-dsh.stderr )
