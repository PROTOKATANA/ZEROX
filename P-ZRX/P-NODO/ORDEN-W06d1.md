# ORDEN-W06d1 — `zx-node` sin red: un proceso cruza el corte, produce en régimen y reinicia

## 1. Identidad y contexto

- **ID:** W06d1. **Fecha:** 2026-09-26. **Director:** Claude. **Ejecutor:** subagente **Sonnet**
  (integración de seis crates con hilos, tiempo real y disco: el «plus» de D-P06), con revisor
  independiente después. Se congela y lanza cuando W05b3, W06a y W06b estén migradas.
- **Zona (única escribible):** `/home/katana/zeo/ZEROX/deepseek/W06d1/`.
- **Objetivo único:** crate `zx-node` (biblioteca + binario `zx-node`) que, **en un solo proceso y sin
  red**, arranca de la red dev, mina PoW, deposita garantía con sus propias claves, cruza el corte,
  produce bloques PoST en régimen con su hilo PoT y su granjero, persiste, y al reiniciar reconstruye
  el mismo estado. La red es W06d2.
- **Pregunta falsable:** «Un proceso `zx-node` con 3 claves dev, desde el génesis, alcanza el terminal,
  produce ≥ 30 bloques PoST que su propia tubería de admisión verifica íntegros (cabecera, PoT, PoAS,
  sello, estado), y tras `SIGKILL` en un punto arbitrario reabre con el **mismo resumen de estado** que
  tenía el último bloque persistido y sigue produciendo.»

## 2. Entradas

Lee íntegros: este archivo; `V-ZRX/LINEO.md`; `P-ZRX/P-NODO/PLAN-W06.md` (D-N01…D-N08, D-N03′);
`P-ZRX/P-RED-DEV/PERFIL-DEV-v0.md`; `P-ZRX/P-MEDICION/ESCENARIOS-0.0.1.md` §1; las revisiones de
W05b2, W05b3, W06a, W06b y W06c; y el código migrado de `crates/`. Del árbol antiguo, como referencia
de estructura (con `git show 9681061:<ruta>`, sin restaurar): `crates/zx-node/src/{main.rs, nodo.rs,
farmer.rs, productor_poas.rs}` y `crates/zx-node/tests/tres_nodos.rs`. Base: la raíz. Entrada
congelada: `P-ZRX/P-NODO/ENTRADA-W06d1.sha256`.

## 3. Decisiones del director

1. **Dependencias:** `zx-node` puede ver todos los crates del workspace; ninguno puede verlo a él
   (regla nueva en `frontera-crates.sh`). Dependencias externas **solo** las del lock de `9681061` a su
   versión exacta (`tokio =1.53.1`, `clap =4.6.6`, `tracing =0.1.44`, `tracing-subscriber =0.3.23`,
   `serde =1.0.229` si hace falta), sin tocar versiones existentes del lock.
2. **Negarse a arrancar** si la red configurada no es `Red::Dev` (`PERFIL-DEV-v0.md` §5), antes de abrir
   disco o sockets; test incluido.
3. **Hilos:** un bucle de consenso **único** dueño de `zx-cadena` y `zx-storage` (determinismo, D-N07);
   un hilo PoT que avanza `ServicioPot` slot a slot con `N_dev` y **es** el reloj de slots; el granjero
   audita en su hilo al recibir cada slot; el minero PoW en su hilo sobre la plantilla que le da el
   bucle de consenso, y se detiene en el corte. Canales acotados; ningún `unwrap` en el camino de datos.
4. **Tubería de admisión única** para todo bloque, también los propios: verificación completa de
   cabecera (PoW: verificador W04; PoST: `verificar_cabecera_conjunta` con `ContextoDag` sobre
   `zx-cadena` e `InstantaneaPot` sobre `ServicioPot`) → `zx-cadena` → `zx-storage` (una escritura
   atómica) → registro. Un bloque propio rechazado es un **error del nodo**: se registra y el proceso
   termina con código ≠ 0 en los tests.
5. **Fase PoW:** plantilla sobre la punta PoW seleccionada; coinbase F-16 a una clave propia; cuando
   una salida propia madura (`M_cb`), el bucle construye un depósito v2 (nonce del estado, F-15) para
   cada clave propia hasta que cada una tenga garantía `≥ q` y lo incluye en su plantilla. Sin relevo
   de transacciones (0.0.1).
6. **Corte y PoST:** al fijar `zx-cadena` el terminal `T`, el hilo PoT arranca de S1 = semilla de `T`
   (D-P09). En cada slot, para cada clave propia con garantía suficiente en el estado de las puntas,
   el granjero audita; con solución `< SR_dev`, el bucle elige padres (puntas, seleccionado primero por
   GHOSTDAG, ≤ 15) y llama a `producir_en_regimen` (W05b3); el primer bloque tras `T` usa `producir`
   (W05b2).
7. **Reinicio:** abrir `zx-storage`, repetir las admisiones sobre `zx-cadena` sin re-verificar
   cabeceras (D-N03′) y reconstruir `ServicioPot` **desde las salidas PoT de las cabeceras
   almacenadas** (ya verificadas), no recalculando el flujo desde `T` (costaría el tiempo real
   transcurrido). Documenta exactamente qué estado del PoT se reconstruye y cómo se reanuda.
8. **Resumen de estado:** `blake3` de la codificación canónica del estado de la punta seleccionada
   (UTXO, garantía con nonce, emisión), expuesto en el registro en cada cambio de punta; si `zx-cadena`
   ya lo ofrece, úsalo.
9. **Registro estructurado** según `ESCENARIOS-0.0.1.md` §1 (una línea JSON por evento, reloj
   monotónico en ns y de pared), en un fichero indicado por la CLI.
10. **CLI** (`clap`): directorio de datos, red (solo `dev`), semilla e índices de claves, papel
    (`minero`, `productor`, `ambos`), `N_dev`, `SR_dev`, ruta del registro, parada tras `X` slots.
11. **CI (IPA E-03):** añade a `.github/workflows/zerox-ci.yml` un paso que clone Autonomys en
    `PDF/autonomys-subspace` y haga `checkout` de `f8842d019cdf0f7163421b9644db5a9ff82b2a73` (`https://github.com/autonomys/subspace`, tabla de `PDF/README.md`)
    antes del build; sin él la CI remota no compila `zx-poas`, `zx-farmer`, `zx-post` ni `zx-node`.

## 4. Verificación

| Paso | Qué | Criterio |
|---|---|---|
| V1–V2 | `fmt --check`, `clippy -D warnings --locked` (con y sin `--features rocksdb`) | limpio |
| V3 | `cargo test --workspace --all-features --locked` | todo lo previo con su nombre + lo nuevo |
| V4 | Integración (`crates/zx-node/tests/`): proceso con 3 claves, `N_dev` de test y `SR_dev` holgado, desde el génesis hasta ≥ 30 bloques PoST admitidos | terminal fijado; 0 bloques propios rechazados; resumen de estado en el registro |
| V5 | Muerte y reinicio: el test lanza el binario como proceso hijo, lo mata con `SIGKILL` en ≥ 10 puntos (semilla fija, fases PoW y PoST), lo reabre | mismo resumen de estado que el último bloque persistido; sigue produciendo; 0 corrupciones |
| V5b | Reinicio con un **testigo** de una transacción de un bloque PoW alterado en disco (el almacén no lo detecta: `REVISION-W06b.md`) | el nodo se niega a arrancar con error explícito al repetir; nunca un estado distinto |
| V6 | Red distinta de `dev` | se niega a arrancar, código ≠ 0, sin crear ficheros |
| V7 | Bloque propio alterado inyectado en la tubería (test) | rechazado con su motivo; el estado no cambia |
| V8 | Ejecución de 10 min con `N_dev` real (138 873 760) y `SR_dev` elegido para ≈ 1 bloque por slot con 3 claves (medido y declarado) | registro conservado; bloques/slot, tiempos de verificación por etapa, CPU y RSS |
| V9 | `dependencias-exactas.sh`, `frontera-crates.sh`; lock sin cambios de versión existentes | OK |

**Prohibido Python.** Presupuesto: **4 h, 8 hilos, 16 GiB**.

## 5. Entregables y límites

Patrón de las órdenes W (`ws.orig/`, `ws/` con el enlace `ws/PDF`, `cambios.patch`,
`MIGRACION.sha256`, `logs/`, `INFORME.md`, `PROGRESO.md`, `HORAS.log` con `date -Is` real). Cargo desde
`ws/` con `GIT_CEILING_DIRECTORIES` en tu zona y `CARGO_HOME`/`CARGO_TARGET_DIR` en la zona (caché
copiable en `deepseek/W05b2R/.cargo-home`). Nada fuera de la zona; sin git; sin secretos; ningún `Ok`
ficticio. Si una pieza migrada (W05b3, W06a, W06b) impide un paso, **para** e informa con la salida
literal: no la parchees en silencio; los arreglos mínimos a otros crates se documentan uno a uno.

## Relanzamiento (2026-09-26, 05:50) — obligatorio leerlo

El primer intento se detuvo porque **dos escritores** trabajaron en la zona: el ejecutor y un *fork*
que él mismo lanzó y que, al heredar su contexto, se creyó ejecutor (no fue otra sesión: comprobado
por el director en las transcripciones). Evidencia en `deepseek/W06d1-intento1/`. Para el
relanzamiento:

1. **Prohibido lanzar subagentes, forks o agentes en paralelo.** Un solo ejecutor escribe en la zona.
2. **LINEO sí rige este código.** `AUTO-ZRX.md` §52: «LINEO rige todo el código del proyecto:
   producción, consenso, red, almacenamiento…»; se aplican sus reglas **pertinentes** (corrección,
   referencia independiente, casos límite, perfiles antes de optimizar, control de recursos, versiones,
   reproducibilidad, trazas). El reparto Julia/C++ es solo para cálculo de auditoría.
3. **Padre seleccionado real.** `ContextoTransicion` de `zx-post` confía en el padre seleccionado
   declarado (atajo dev). El nodo **no** puede usarlo para bloques ajenos: la puerta debe comprobar el
   padre seleccionado con GHOSTDAG real. Si `zx-cadena` no expone lo necesario (p. ej. el padre
   seleccionado de un conjunto de padres), añade el **accesor mínimo** a `zx-cadena`, con test, y
   documéntalo; no dupliques GHOSTDAG en el nodo.
4. **Sin doble firma accidental** (no hay firmante durable portado; `C-EVP` inactivo): el nodo
   persiste un bloque propio **antes** de darlo por producido y, al reiniciar, no produce con una clave
   en un slot menor o igual que el último bloque propio almacenado de esa clave. Test incluido en V5.
5. **Codificación canónica del estado** para el resumen (decisión 8): no existe en `zx-cadena` ni en
   `zx-consensus`; escríbela en `zx-node` sobre colecciones ordenadas y documenta el formato.
