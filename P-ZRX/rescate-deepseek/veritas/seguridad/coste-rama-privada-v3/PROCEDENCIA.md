# CRP-v0.3 · Procedencia

## 1 · Entrada congelada

| Archivo | SHA-256 |
|---|---|
| `deepseek/ENCARGO-07v2-coste-rama-privada.md` | `a8912ba5d8d48ae71685b3ea471d7166df74bebc4f17bd609c4182c1e8795c45` |
| `deepseek/ENCARGO-07v2-coste-rama-privada.sha256` | `bd3ed51a9c0478aade54e1b3ada5a529644ce155ffa29a1fd76f27c91b27fa32` |
| `ENTRADA.md` (copia) | coincide con el original |
| `ENCARGO.sha256` (copia) | coincide |

`sha256sum -c` desde la raíz: **OK**. La entrada no cambió durante la ejecución.

## 2 · Relación con CRP-v0.2

CRP-v0.2 **no se cierra**. CRP-v0.3 es un instrumento separado en
`deepseek/veritas/seguridad/coste-rama-privada-v3/` que incorpora las correcciones
pedidas por el usuario (12 puntos). No se edita el directorio v2.

## 3 · Fuentes

Las mismas de v0.2: `AGENTS.md`, `README.md`, `MIGRACION.md`, `research/README.md`,
`veritas/LINEO.md`, `SPEC.md` §6.1–§7.3/§11, `TAREAS.md` §2, `research/dag-poas-ancla-de-orden.md`,
`veritas/consenso/ghostdag-rank-v1/` (GDR-v0.2), `retarget-causal-endogeno-v1/`,
`admision-retarget-multivista-v1/`, y el código Rust aislado vs ruta activa.

## 4 · Trazabilidad

Cada resultado en `resultados/` registra Julia 1.13.0, CPU, hilos y semilla (`ENTORNO.txt`).
Semilla por defecto `0x5a5a`; el `d` no modifica la semilla. Los benchmarks de I/O son de
solo lectura y page cache caliente (`resultados/IO.txt`).
