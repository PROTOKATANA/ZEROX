# Revisión del director — L01 y L01-C1 (2026-09-26)

**Veredicto: línea base REPRODUCIDA.** El código antiguo `9681061`, con su `Cargo.lock`, la
toolchain `nightly-2026-05-03` y el clon de Autonomys en `f8842d0`, compila con `--locked` y pasa
todas sus pruebas no ignoradas en esta máquina (DeepSeek, sesiones de 01:03 y 01:11).

| Suite | Pasadas | Fallidas | Ignoradas | Verificado por el director |
|---|---:|---:|---:|---|
| `zx-core` | 156 | 0 | 0 | logs crudos |
| `zx-pot` | 5 | 0 | 0 | logs crudos |
| `zx-storage` (sin `rocksdb`) | 36 | 0 | 0 | logs crudos |
| `zx-storage --features rocksdb` | 60 | 0 | 0 | recuento de `test result` (5 binarios) |
| `zx-consensus` | 421 | 0 | 4 | recuento de `test result` (22 binarios); 4 `#[ignore]` reales |
| `zx-node --features farmer --test farmer_disco` | 13 | 0 | 0 | logs crudos |

**Comprobaciones independientes del director:** `diff` del checkout contra su manifiesto vacío;
clon de Autonomys en `f8842d019cdf…` sin cambios; `ENTRADA*.sha256` OK; recuentos de los logs.

**Defectos de la orden (del director), corregidos:** no extraía `SPEC.md` (lo incluye
`tests/spec_numeros.rs`); atribuía a S3 pruebas tras la feature `rocksdb`. **Desviación menor del
ejecutor:** en L01 comprobó `ENTRADA` antes de terminar S5; en C1 lo hizo el último.

**Alcance:** prueba los **contratos antiguos**. No valida ninguna regla ni constante del híbrido;
tiempos con carga ajena no controlada (`uptime` hasta 3,5).

**Evidencia conservada:** `P-ZRX/P-LINEA-BASE/resultados/` (27 archivos, `HUELLAS.sha256`).
