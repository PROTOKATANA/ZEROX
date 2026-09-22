"""
`RevelacionV1` — REV-v1.0, instrumento de `P-ZRX/P-REVELACION`.

Modelo **por eventos** de la frontera de PoT del atacante frente a la del timekeeper honesto,
con las barreras de inyección de `R-FIN-2`/`R-FIN-14` y con la opción de revelación retardada
`R-FIN-14(h)`. Todos los parámetros (`L, I, W_dec, D, S_max, Lrev, ρ, α`) son **entradas**: no
hay ninguna constante de consenso escrita a mano (encargo §9).

Fuentes de reglas, leídas antes de codificar:

- `C-FLU-01` (`SPEC.md:1507-1543`): `T_j = j·I`, `t_j = slot(I_j) + L_slots`,
  `L_slots := máx(F_slots, L_suelo_slots, S_max_slots+1)`.
- `C-FLU-04` (`SPEC.md:1564-1577`): el ancla `I_j` es un bloque con `slot ≥ T_j`; aquí
  `slot(I_j) = T_j + off_j` con `off_j ∈ [0, S_max)`.
- `C-FLU-07` (`SPEC.md:1612-1620`): la inyección se aplica en `t_j`, borde inclusivo.
- `C-FLU-09` (`SPEC.md:1630-1632`): `S_max_slots < I_slots` ⇒ `t_j < t_{j+1}` estrictamente.
- `C-POT-03` (`SPEC.md:1376-1390`): el reto del slot `s` usa `salida(f, s)`; ningún atajo.
- `C-POT-05` (`SPEC.md:1403-1417`): `pot_output(B) = salida(f, slot(B) + D)`; la justificación
  cubre `(slot(sp)+D, slot(B)+D]`, luego quien produce un bloque del slot `s` ha alcanzado
  `s + D`.
- `C-FLU-12` (`SPEC.md:1673-1677`): `entropía_j = blake3(chunk(I_j) ‖ pot_output(I_j))`, que es
  la regla que `(h)` sustituiría.
- `R-FIN-14(a)-(h)` (`research/dag-poas-ancla-de-orden.md:258-296`).

Núcleo del modelo (idéntico en la referencia y en el kernel rápido; lo único que cambia es cómo
se acumula):

```text
s_j = T_j + off_j ,  t_j = s_j + L
τ_j = máx( τ_{j-1} + (t_j − t_{j-1})/ρ , e_j + 1/ρ )      [atacante; cruce de barrera = 1/ρ]
σ_j = máx( σ_{j-1} + (t_j − 1 − H_{j-1}) , e_j^h ) + 1    [honesto, a tasa 1]
```

con `e_j` la disponibilidad de `entropía_j` y `e_j^h` la del honesto. Las variantes de `e_j` y
las banderas que las seleccionan están en `Config`.
"""
module RevelacionV1

using Random
using StableRNGs
using Printf
using Statistics

export Config, MetricasReplica, Buffers, ResultadoBarrido
export construir_trayectorias!, simular_replica!, barrer!, reiniciar!
export rejilla_rho, sortear_offsets!, fila_media, fila_cuantil
export hist_agregado, cuantil_hist, fraccion_excedencia
export comparar_con_oraculo, invariantes, puntualidad_estricta, _pos_traj
export oraculo_por_slot, oraculo_eventos_exacto
export a_core_semv1, ventaja_barrera_10a, rho_estrella_continua, rho_estrella_10a
export n_rachas, tasa_rachas, lineas_timekeeper, nucleos_nodo, nucleos_cadena
export I_estrella, I_minima, coste_verificacion, instantes_por_hora

include("modelo.jl")
include("referencia.jl")
include("rapido.jl")
include("validacion.jl")

end # module
