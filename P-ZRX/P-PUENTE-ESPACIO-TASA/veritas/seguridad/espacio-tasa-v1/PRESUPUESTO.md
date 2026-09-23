# PRESUPUESTO — espacio-tasa-v1

Declarado **antes** de ejecutar cualquier medición, conforme a `veritas/LINEO.md` §7 y al encargo §6.

## Máquina de referencia

| Recurso | Valor |
|---|---|
| CPU | AMD Ryzen 9 9950X3D, 16 núcleos físicos / 32 hilos lógicos, 1 nodo NUMA |
| RAM | 123 GiB visibles |
| `Sys.CPU_NAME` | `znver5` |
| Julia | 1.13.0 (`veritas/julia.sh`) |
| Rust | `rustc 1.97.0-nightly (20de910db 2026-05-02)` |
| Upstream fijado | `/home/katana/zeo/fuentes/subspace` @ `f8842d019cdf0f7163421b9644db5a9ff82b2a73` (misma copia de lectura en `PDF/autonomys-subspace/`) |

## Techos declarados para **este** instrumento

Los topes de LINEO son **techo, no objetivo**. Se declaran techos más bajos porque el problema lo permite.

| Recurso | Techo LINEO | Techo declarado aquí | Motivo |
|---|---:|---:|---|
| Hilos de cómputo | 24 | **16** | La generación de tablas PoS ya escala por su cuenta; 16 hilos bastan para el colector Rust y dejan margen al sistema. La capa Julia es serial o paralela por réplica con reducción determinista. |
| RAM | 64 GiB | **8 GiB** | Un sector sintético de 1.000 piezas ocupa ~1,05 GiB de chunks; Julia trabaja con contadores enteros y tablas de ocupación de 64 KiB por pieza. |
| Disco temporal | — | **6 GiB** | `target/` de Cargo, depósito Julia aislado y datos del colector. Todo bajo el instrumento; se puede borrar. |
| Tiempo de pared | — | **3 h** | Con parada por presupuesto: si se agota, se conserva el checkpoint y se reporta **inconcluso**. |

Ninguna corrida individual supera **30 min** de pared.

## Zona de escritura

Solo `P-ZRX/P-PUENTE-ESPACIO-TASA/veritas/seguridad/espacio-tasa-v1/`, que es el único punto del
árbol con permiso de escritura en esta sesión (el resto de `/home/katana/zeo/ZEROX` está montado
**de solo lectura**: `findmnt` lo confirma). El clon upstream se usa **solo como dependencia por
ruta** y no se copia ni se modifica.

## Política ante agotamiento

Si el presupuesto se agota: checkpoint en `resultados/`, estado **inconcluso** y causa concreta en
`INFORME.md`. Un timeout **no** es evidencia de falsedad (`LINEO.md` §10).
