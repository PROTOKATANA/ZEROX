# ORDEN-RI-1 — Revisión independiente del código de consenso (W02–W05b2)

- **ID:** RI-1 (dos revisores en paralelo: **RI-1a** y **RI-1b**). **Fecha:** 2026-09-26.
  **Director:** Claude. **Ejecutor:** subagentes Claude Sonnet.
- **Motivo:** `P-ZRX/PLAN-0.0.1.md` §4 promete un revisor independiente además del director para el
  código de W03–W06. No se hizo en W02–W05b2 (error del director). Esta orden lo repara sobre el
  código ya migrado a la raíz (commit `3cc64b4` o posterior).
- **Zona escribible:** `/home/katana/zeo/ZEROX/deepseek/RI-1a/` o `/home/katana/zeo/ZEROX/deepseek/RI-1b/`
  (la tuya). **Nada** fuera de ella: ni `crates/`, ni `P-ZRX/`, ni git.

## Alcance

| Revisor | Código (en la raíz) | Contratos contra los que se revisa |
|---|---|---|
| **RI-1a** | `crates/zx-consensus/src/transicion/` (motor de transición, modo estricto y fusión, undo); `crates/zx-core/src/{tx.rs, forma.rs, encoding/, preimage/, digest.rs, amount.rs}` (formatos y `txid`) | `P-ZRX/P-TRANSICION/CONTRATO-v0.md` (v0.1), `P-ZRX/P-FORMATO/FORMATO-v0.md`, `P-ZRX/P-DAG/CONTRATO-ESTADO-DAG-v0.md` |
| **RI-1b** | `crates/zx-consensus/src/{verificador.rs, dificultad.rs, timestamps.rs, fork_choice.rs, activacion.rs, algoritmo.rs, genesis.rs, parametros.rs}` (PoW dev); `crates/zx-dag/` (GHOSTDAG, admisión); `crates/zx-post/` (puerta conjunta de la cabecera PoST, PoT, contexto de transición) | `P-ZRX/P-DAG/DECISIONES-W05.md`, `P-ZRX/P-RED-DEV/PERFIL-DEV-v0.md`, `P-ZRX/P-TRANSICION/CONTRATO-v0.md`, las revisiones `P-ZRX/P-POW/REVISION-W04.md` y `P-ZRX/P-DAG/REVISION-W05*.md` |

**Excluido (ya conocido, no lo reportes):** repetición de operaciones de garantía y unicidad de `txid`
de la coinbase (IPA C-10; corrección FORMATO v0.1 F-15…F-18 en curso en W02b); todo lo marcado
«no activo en 0.0.1» en `P-ZRX/PLAN-0.0.1.md` §2; la elección del algoritmo PoW (A-12).

## Qué buscar

Defectos que un adversario con recursos pueda explotar o que rompan el consenso entre nodos honestos:
aceptación de lo inválido o rechazo de lo válido; no determinismo (orden de `HashMap`, relojes, hilos,
flotantes); desbordamientos y truncamientos; undo inexacto; divergencia entre el código y el contrato
citado (con la regla exacta); verificación que se salta en algún camino; consumo no acotado
(padres, tamaños, bucles) antes de validar; parámetros dev que puedan activarse fuera de `Red::Dev`;
tests que no prueban lo que dicen (aserción débil, `Ok` ficticio, `#[ignore]` sin motivo).

## Método y evidencia

- Cada hallazgo con: archivo y línea, regla del contrato (si aplica), escenario concreto (entrada →
  resultado erróneo), gravedad (**crítica / alta / media / baja**) y etiqueta **CONFIRMADO** o
  **PLAUSIBLE**. **CONFIRMADO** solo si lo reprodujiste: copia la raíz a tu zona
  (`tar --exclude=./PDF --exclude=./deepseek --exclude=./target`, con el enlace `PDF` a
  `/home/katana/zeo/ZEROX/PDF` si hace falta), escribe el test mínimo **en la copia**, ejecútalo con
  `CARGO_TARGET_DIR` y `CARGO_HOME` en tu zona, `--locked`, como mucho **4 hilos** (`-j 4`,
  `RUST_TEST_THREADS=4`), y pega el comando y la salida literal. Hay caché de dependencias copiable en
  `/home/katana/zeo/ZEROX/deepseek/W05b2R/` (busca `.cargo-home`); si no hay red, trabaja sin ella.
- Distingue **hecho** (leído o ejecutado), **derivación** e **hipótesis**. No inventes números.
- **Prohibido Python.** No leas ni muestres credenciales (`.env`, `~/.dsh`, tokens).
- Presupuesto: 2 h de reloj.

## Entregable

`deepseek/RI-1a/INFORME.md` (o `RI-1b`): tabla de hallazgos ordenada por gravedad, luego el detalle de
cada uno, luego «revisado sin hallazgos» con la lista de archivos leídos enteros y los que solo se
muestrearon. En español. Si no encuentras nada grave, dilo así; no rellenes.
