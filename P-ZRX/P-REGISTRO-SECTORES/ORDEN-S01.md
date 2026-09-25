# ORDEN-S01 — Encargo 01 de sectores: compromiso y alta de un sector PoAS real (G1)

## 1. Identidad y contexto

- **ID:** S01. **Estado:** redactada 2026-09-26. **Director:** Claude. **Ejecutor:** DeepSeek.
  Implementa `P-ZRX/P-REGISTRO-SECTORES/ENCARGO-01-FORMATO-ALTA.md` en la plantilla de
  `AUTO-ZRX.md` §6 (IPA D-01, E-09). **Es investigación aislada**: nada entra en el workspace ni en
  el consenso.
- **Zona (única escribible):** `/home/katana/zeo/ZEROX/deepseek/S01/`.
- **Pregunta falsable (del encargo 01):** «¿Puede una solución PoAS real demostrar pertenencia al
  **mismo sector completo** que se comprometió antes de ser elegible, con coste admisible de alta y
  verificación?» Se refuta si la apertura de una solución real no se puede verificar contra el
  compromiso R2 de §3, o si su coste no es acotado y medible. **No** se confunde con preexistencia ni
  permanencia (RFT-03, RFT-04).

## 2. Autoridad y entradas

Lee íntegros: este archivo; `V-ZRX/LINEO.md`; `ENCARGO.md`, `ANALISIS.md` y
`ENCARGO-01-FORMATO-ALTA.md` de `P-ZRX/P-REGISTRO-SECTORES/`; `D-ZRX/RFT-ZRX.md` (RFT-03, RFT-04,
RFT-06); `P-ZRX/P-REGISTRO-SECTORES/investigacion/fuentes-filecoin/INFORME.md` y su `REVISION.md`.
Histórico (solo lectura): `P-ZRX/P-COBERTURA/investigacion/INFORME.md` §§2–3, 7 y
`P-ZRX/P-SEMBRADOR/investigacion/INFORME.md` en `/home/katana/zeo/.trash/zerox/`.

Código de referencia (solo lectura): `git -C /home/katana/zeo/ZEROX show 9681061:crates/zx-node/src/farmer.rs`
y `…:crates/zx-node/tests/farmer_disco.rs` (plotter y auditor reales, reproducidos en L01: 13/13) y
`…:crates/zx-consensus/src/poas.rs` (verificador real). Autonomys `f8842d019cdf…` en
`/home/katana/zeo/.trash/zerox/PDF/autonomys-subspace/` (clónalo a tu zona como en L01; no uses el
original). Hechos que el director ya comprobó en esa fuente:
`subspace-verification/src/lib.rs:248-249` (el verificador calcula `masked_chunk = chunk XOR
proof_of_space.hash()`, que es el chunk **almacenado**) y
`subspace-farmer-components/src/sector.rs:436-470` (`iter_record_chunk_to_plot`: orden físico por
s-bucket ascendente y, dentro de cada uno, el de `iter_s_bucket_records`; `chunk_location` es la
posición global).

Entrada congelada: `P-ZRX/P-REGISTRO-SECTORES/ENTRADA-S01.sha256`, al empezar y como último paso.

## 3. Decisiones ya tomadas por el director (no las cambies)

**R0** · sin registro (línea base). **R1** · alta de identidad y fecha:
`(public_key, sector_index, history_size, slot_alta)`; solo contabilidad.

**R2** · compromiso exacto del sector completo, calculado **después** de plotear:

    hoja(i)   = H_d("ZZKSectorHoja___", s_bucket u16 LE ‖ piece_offset u16 LE ‖ codificado u8 ‖ chunk_almacenado 32 B)
    nodo      = H_d("ZZKSectorNodo___", izquierdo 32 B ‖ derecho 32 B)
    vacío     = H_d("ZZKSectorVacio__", "")        (relleno hasta potencia de dos)
    raiz_chunks = raíz Merkle binaria sobre hoja(0 … n−1) en orden de `chunk_location`
    R2 = H_d("ZZKSectorRaiz___", 0x01 ‖ CBID u32 LE ‖ public_key 32 ‖ sector_index u16 LE ‖
             history_size u64 LE ‖ pieces_in_sector u16 LE ‖
             H_d("ZZKSectorMapa___", bytes del SectorContentsMap) ‖
             H_d("ZZKSectorMeta___", bytes de la región de metadatos de registros) ‖
             raiz_chunks ‖ n u32 LE)

`H_d(tag, m) = SHA3-256(tag ‖ m)` con la etiqueta de 16 B, como en `zx-core` (reutiliza
`zx_core::hash` si lo necesitas, leyéndolo del workspace de la raíz como dependencia por ruta de
**solo lectura**, o reimplementa `H_d` en 3 líneas; di cuál). `codificado` = 1 si el chunk se guardó
codificado con la prueba de espacio, 0 si no. `CBID` = el de la red dev si ya existe en
`zx-core` (`CBID_RED_DEV`), si no un valor fijo de prueba declarado.

**Apertura** de una solución ganadora frente a R2: `(chunk_location, camino Merkle)`. El verificador
recalcula `chunk_almacenado = chunk XOR proof_of_space.hash()`, `hoja` con el `s_bucket` auditado y
el `piece_offset` de la solución y `codificado = 1`, comprueba el camino hasta `raiz_chunks` y
recompone `R2` con los campos públicos y los dos digests que la apertura también transporta.

**R3** · prueba de codificación completa ligada a aleatoriedad posterior: **no** se implementa. Se
entrega la razón técnica precisa (RFT-04) de por qué exige cambiar el formato o el circuito, con
referencia a la fuente.

Parámetros de plot: los de desarrollo de `farmer_disco.rs` antiguo (declárelos: son de prueba, no
de ZEROX). Si no son suficientes para obtener una solución ganadora en tiempo, **para** e informa.

## 4. Contrato de ejecución

Crate **independiente** en `deepseek/S01/prototipo/` (no miembro del workspace de la raíz), con
`rust-toolchain.toml` = `nightly-2026-05-03`, dependencias por ruta al clon de Autonomys en tu zona
y versiones fijadas con `=`; `Cargo.lock` propio. `CARGO_HOME`/`CARGO_TARGET_DIR` en tu zona
(puedes copiar la caché `deepseek/L01/.cargo-home`). 8 hilos máximo.

Funciones mínimas: `plotear(parametros) -> Sector`, `compromiso_r1(...)`, `compromiso_r2(&Sector)`,
`apertura(&Sector, &Solucion, s_bucket) -> Apertura`, `verificar_apertura(r2, &Apertura, &Solucion,
s_bucket, campos_publicos) -> Result<(), Error>`, y un registro abstracto en memoria
`RegistroSectores` (alta, duplicado, caducidad por slot) etiquetado como abstracto.

## 5. Modelo de amenaza

Prover que intenta: usar una solución de otro sector, clave, índice o `history_size`; cambiar la
versión; presentar un camino de otra hoja o de otra raíz; registrar dos veces el mismo sector o uno
caducado. Lo que **no** se modela aquí (y el informe debe decirlo): que la raíz corresponda a un
ploteo correcto (lo impediría solo R3), preexistencia, permanencia, doble uso entre ramas (RFT-06).

## 6. Plan de verificación

- La solución ganadora se verifica **con el verificador PoAS real** (`verify_solution::<ChiaTable,_>`
  con los parámetros del test antiguo) antes de abrirla contra R2.
- Positivos: apertura válida de ≥ 3 soluciones ganadoras distintas (slots distintos).
- Negativos (cada uno con su error): `public_key`, `sector_index`, `history_size`, versión y `CBID`
  cambiados; hoja con otro `piece_offset` o `s_bucket`; `codificado = 0`; camino de otra posición;
  raíz de otro sector; alta duplicada; alta caducada.
- Oráculo independiente para la raíz: una implementación **Julia** mínima (`oraculo-r2/`, LINEO) que
  recalcula `raiz_chunks` y `R2` desde un volcado binario del sector que escriba el prototipo; deben
  coincidir byte a byte en al menos dos tamaños de sector.
- Medición (LINEO §7; no es benchmark de producción): para al menos tres `pieces_in_sector`, bytes de
  R1, R2 y de cada apertura; tiempo y RAM de calcular R2 tras plotear; tiempo de verificar una
  apertura (mediana de ≥ 1 000 verificaciones tras calentar); comparación con R0 (sin apertura).
  Registra hardware, carga (`uptime`) y versiones.
- **Prohibido Python.**

Presupuesto: **3 h de reloj, 8 hilos, 32 GiB de RAM, 60 GiB de disco**. Si se agota, **inconcluso**
con el último resultado.

## 7. Criterio de cierre (G1 de `ANALISIS.md`)

**Superada** si las aperturas verifican y todos los negativos se rechazan, con costes medidos;
**fallida** si R2 no puede ligarse a una solución real; **inconclusa** si falta presupuesto. En los
tres casos el informe debe separar lo que R2 demuestra (pertenencia de la pieza al objeto
comprometido) de lo que no (que el objeto sea un ploteo correcto, que existiera antes, que siga en
disco, que no se use en otra rama).

## 8. Entregables

En `deepseek/S01/`: `prototipo/`, `oraculo-r2/`, `resultados/` (crudos), `INFORME.md` (matriz
variante × propiedad demostrada × coste honesto × evidencia; tabla de cobertura R0–R3; razón de R3),
`ESPECIFICACION-BYTES.md` (R1, R2 y apertura byte a byte), `METODO.md`, `PROGRESO.md`, `HORAS.log`.
El director copiará lo validado a `P-ZRX/P-REGISTRO-SECTORES/investigacion/01-formato-alta/`.

## 9. Límites de la sesión

DeepSeek Harness, `deepseek-flash`, esfuerzo `high`; LINEO leído y aplicado antes del código; sin
Python; nada fuera de `deepseek/S01/`; sin commit ni push; sin secretos; ningún `Ok` ficticio.

## Lanzamiento

    mkdir -p /home/katana/zeo/ZEROX/deepseek/S01 && cd /home/katana/zeo/ZEROX/deepseek/S01 && \
    ( set -a; . /home/katana/torio/deepseek-harness/.env >/dev/null 2>&1; set +a; \
      node /home/katana/torio/deepseek-harness/apps/cli/lib/bin.js --profile headless \
      "Orden S01. Lee íntegro /home/katana/zeo/ZEROX/P-ZRX/P-REGISTRO-SECTORES/ORDEN-S01.md y cúmplelo. Antes de escribir código, lee íntegro /home/katana/zeo/ZEROX/V-ZRX/LINEO.md. Si detectas una falta de definición, infórmala antes de editar." \
      > ../S01-dsh.stdout 2> ../S01-dsh.stderr )
