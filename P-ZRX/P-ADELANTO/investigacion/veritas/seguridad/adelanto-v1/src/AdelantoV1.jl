"""
    AdelantoV1

Instrumento `ADL-v1.0` de `P-ZRX/P-ADELANTO`: el adelanto adversarial
`A(ρ, L, I, W_dec, D, S_max)` con `pot_output = salida(f, slot + D)` (D-2 = A), bajo las
reglas vigentes (`C-FLU-01`, `C-POT-03`, `C-POT-05`, `C-FLU-07`, `R-FIN-14`).

Categoría dominante: `seguridad` (secundarias: `consenso` y `rendimiento`). Motivo de la
categoría: la pregunta del encargo es cuánta ventana de retos futuros conoce un atacante,
que es una pregunta de seguridad; el coste por nodo es rendimiento y las reglas que la
restringen son de consenso.

Entrada del módulo: `modelo.jl`, `referencia.jl`, `rapido.jl`, `validacion.jl`.
Convención de ejes: **slots**; `τ_nom` nunca entra en una comparación.
"""
module AdelantoV1

using Dates

include("modelo.jl")
include("referencia.jl")
include("rapido.jl")
include("validacion.jl")

export ParametrosAdelanto, ResultadoAdelanto
export L_derivada, adelanto_nucleo, desafios_nucleo
export adelanto_D, adelanto_frontera, adelanto_frontera_inf, rho_transitorio
export adelanto_con_h, adelanto_con_h_D
export adelanto_add, adelanto_sub
export rho_estrella, rho_estrella_continua, I_estrella, I_minima_f, lineas_timekeeper, coste_relativo
export nucleos_nodo, vivo, horizonte_flujo
export sup_A_sin_h, sup_A_con_h, cota_sellado
export evaluar_fila, barrer!, barrer_hilos!, barrer_soa!, rejilla
export referencia_bigfloat, referencia_exacta, simular_fronteras, rejilla_offsets
export regresion_semv1, kernel_vs_bigfloat, frontera_vs_sim, invariantes, exactitud_umbrales
export a_core_semv1, desafios_semv1, TABLA_SEMV1
export COSTE_VERIFY_SLOT_S, ASIMETRIA_PROVE_VERIFY

end # module
