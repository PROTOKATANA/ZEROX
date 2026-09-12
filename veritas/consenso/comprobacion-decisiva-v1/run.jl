using ComprobacionDecisiva

function main(args::Vector{String})
    seed = parse_seed(args)
    resultado = ejecutar_convergencia(seed)
    println("model=comprobacion-decisiva-v1 seed=$seed rng=none acceptance=exact_economic_convergence")
    println("node_convergence=$(resultado.convergido) independent_progress_ana=$(resultado.progreso_ana) " *
            "independent_progress_bruno=$(resultado.progreso_bruno) " *
            "pending_then_reproduced=$(resultado.pendiente_reproducido)")
    println("payments=$(resultado.pagos) consumptions=$(resultado.consumos) " *
            "total_paid=$(resultado.total_paid) total_consumed=$(resultado.total_consumed) " *
            "retarget_equal=$(resultado.retarget_igual)")
    println("blue_weight_dedup=$(resultado.peso_dedup) naive_weight=$(resultado.peso_naive) " *
            "naive_detected=$(resultado.naive_detected)")
    println("double_spend_invalid_unpublished=$(resultado.doble_gasto) " *
            "same_window_double_spend=$(resultado.doble_gasto_ventana)")
    println("local_clock_detected=$(resultado.reloj_detectado) " *
            "heldzero_convergencia=$(resultado.heldzero_convergencia)")
    println("range_validation=Pending network=Pending cortex_finality=Pending")
    all([resultado.convergido, resultado.progreso_ana, resultado.progreso_bruno,
         resultado.pendiente_reproducido, resultado.retarget_igual,
         resultado.naive_detected, resultado.doble_gasto,
         resultado.doble_gasto_ventana, resultado.reloj_detectado,
         resultado.heldzero_convergencia]) ||
        error("comprobación decisiva: veredicto no demostrado")
end

main(ARGS)
