# CRP-v0.2 · Respuesta a las revisiones en contexto independiente

Los tres dictámenes (`REVISION-MATEMATICA.md`, `REVISION-RUST.md`, `REVISION-JULIA.md`) se
escribieron sobre el estado anterior a esta respuesta. Aquí se registra qué se corrigió y qué
queda como límite declarado. Ninguna corrección se hace para "poner en verde": se reproduce el
defecto y se comprueba el arreglo.

| Hallazgo | Revisor | Corrección | Verificación |
|---|---|---|---|
| F1/M3 `P_eventual` mal (`0.0343`) | matemática, Julia | corregido a `0.0585277`; `P_eventual ≥ P_finita` | `INFORME.md` §2 |
| F2/M4 cifras I/O no coincidentes | matemática, Julia | se publica rango y se cita `resultados/IO.txt` | `resultados/IO.txt` |
| F3 soporte inferior fijo alejado de −1 | matemática | `prob_superar_dp` fija `lo=−1` (`lo_inicial`) | test `z0 grande: frontera z≤−1 alcanzable` |
| M1 `Δ=0` pierde entregas | Julia | `_procesar_entregas!` usa `≤` y consume; rechazos GDR se omiten | suite 131/131 |
| M2 signo de `g_E` en el informe | Julia | corregido a `α−(1−α)` | `INFORME.md` §1 |
| M5 `--replicas` sin uso | Julia | alimenta la frontera medida y la calibración | `DAG.txt` |
| M6/Rust4 «R-FIN-5 aplicado antes de colorear» pero no invocado | Julia, Rust | `dag_sim.jl` aplica R-FIN-5 estructural (`_flujo_en`) antes de GDR | `src/dag_sim.jl` |
| Rust1 C-HDR-06 «sin código» | Rust | reclasificado «interfaz implementada sin cablear» | `MATRIZ-AUTORIDAD.md` |
| Rust2/3 R-FIN-1a/R-FIN-11 «candidata» | Rust | reclasificados SPEC vigente (C-HDR-05 / C-GD-07) | `MATRIZ-AUTORIDAD.md` |
| Rust5 validez cuatrivaluada | Rust | eliminado `CONTRAFACTUAL`; validez es trivaluada | `src/modelo.jl` |
| Rust5 métrica de rojos mezclada | Rust | `tasa_rojos_calibrada` usa rojos/bloques totales | `src/validacion.jl` |

## Límites que se conservan (no se corrigen, se declaran)

- **F4/F5/F6/F7/F8 (baja):** el test de «invariancia de retícula» verifica corrección del DP a
  varios `z0`, no invariancia física; la cobertura de mutación es parcial; el intervalo de
  `α_prob` es estrecho por bisceción; `q≥p` no cortocircuita; algunos tests toy son tautológicos
  (declarados en `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`).
- **P1/P2 (Julia):** el simulador asigna MB por réplica y `_procesar_entregas!` es `O(T·E)`; se
  tipó el RNG (`Simulador{R}`) pero no se optimizó el resto. No afecta al veredicto; es coste.
- Revisión de la **asociación DAG→cohorte RCE** y **`S_adversario`** siguen pendientes.
- Las revisiones no certifican la matemática con aritmética de bolas; el margen no se certifica.

Los dictámenes originales **no se reescriben**: conservan los defectos encontrados, que quedan como
evidencia de procedencia.
