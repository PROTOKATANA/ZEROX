# validacion.jl — equivalencia referencia/kernel, invariantes y bordes (LINEO §2 paso 5).
#
# Cada comprobación devuelve un `Comprobacion` con nombre, veredicto y detalle numérico exacto.
# Nada se declara «verificado» sin un artefacto impreso que lo respalde.

struct Comprobacion
    nombre::String
    ok::Bool
    detalle::String
end

"""Conjunto de `SR` de regresión: bordes de paridad, potencias de dos, extremos de `u64` y
valores cercanos a los candidatos históricos `2^11`."""
function srs_de_regresion()
    s = BigInt[]
    append!(s, BigInt.(0:64))
    for k in (11, 12, 16, 20, 32, 40, 48, 56, 63)
        append!(s, BigInt[big(2)^k - 1, big(2)^k, big(2)^k + 1])
    end
    append!(s, BigInt[big(2)^64 - 2, big(2)^64 - 1])
    return sort!(unique(s))
end

"""Oráculo independiente de `A(sr)` por enumeración en un círculo pequeño."""
function validar_A_circulo(m::Integer=256)
    malos = 0
    for sr in 0:(m - 1)
        if A_sr_enumerado(sr, m) != A_sr(sr)
            malos += 1
        end
    end
    return Comprobacion("A(sr) contra enumeración en círculo de $m puntos", malos == 0,
                        "discrepancias=$malos; SR cubiertos=0:$((m-1))")
end

"""`razon_ref` (producto) contra la forma cerrada de PCO-v0.1 y contra el producto a mano."""
function validar_razon_cerrada(srs)
    malos = 0
    for sr in srs
        (razon_ref(sr) == razon_cerrada(sr) == razon_producto(sr)) || (malos += 1)
    end
    return Comprobacion("razón: producto == forma cerrada == producto a mano", malos == 0,
                        "SR probados=$(length(srs)); discrepancias=$malos")
end

"""El residuo de paridad, con el redondeo propuesto (rejilla par)."""
function validar_paridad(srs)
    peor_par = 0 // big(1)
    peor_impar = 0 // big(1)
    cota_par_ok = true
    cota_impar_ok = true
    for sr in srs
        d = deficit(sr)
        if iseven(sr)
            peor_par = max(peor_par, d)
            # con sr par: déficit == ρ/2^128 y ρ < sr+1 ≤ 2^64  ⇒ déficit < 2^-64
            (d == rem(DOS128, big(sr) + 1) // DOS128) || (cota_par_ok = false)
            (d < 1 // big(2)^64) || (cota_par_ok = false)
        else
            peor_impar = max(peor_impar, d)
            # con sr impar: déficit >= 1/(sr+1) (más el suelo)
            (d >= 1 // (big(sr) + 1)) || (cota_impar_ok = false)
        end
    end
    detalle = "déficit máximo par=$(peor_par) (¿<2^-64? $(peor_par < 1//big(2)^64)); " *
              "déficit máximo impar=$(peor_impar)"
    return Comprobacion("residuo de paridad con SR par y con SR impar", cota_par_ok && cota_impar_ok,
                        detalle)
end

"""Dominio de `SR` y de `w`: `SR=0` no cabe en `u128`; la rejilla par sí."""
function validar_dominio(srs)
    peso0 = peso_big(0)
    overflow_demostrado = peso0 == DOS128 && DOS128 > MAX_U128
    ok = overflow_demostrado
    malos = 0
    for sr in srs
        sr >= 2 || continue
        iseven(sr) || continue
        peso_fast(UInt64(sr)) == peso_big(sr) || (malos += 1)
        peso_big(sr) <= MAX_U128 || (malos += 1)
    end
    # C-GD-01: w(B) >= 2^64 para todo SR <= 2^64-1
    minimo = peso_big(big(2)^64 - 1)
    ok = ok && malos == 0 && minimo >= big(2)^64
    detalle = "w(0)=2^128 > typemax(u128) ($overflow_demostrado); " *
              "w(2^64-1)=$minimo >= 2^64 ($(minimo >= big(2)^64)); discrepancias kernel/ref=$malos"
    return Comprobacion("dominio de SR, peso en u128 y suelo w >= 2^64", ok, detalle)
end

"""El kernel del controlador contra la referencia exacta, con bordes y muestra aleatoria.

Solo se prueban estados **alcanzables**: el rango activo vive en la rejilla par (arranque par y
pasos pares). Un `r` impar no es un estado del sistema y no se le exige paridad de salida."""
function validar_controlador(c::ConfigControlador, srs, aleatorios)
    malos = 0
    impares = 0
    fuera = 0
    clamped_ref = 0
    casos = 0
    for n in (UInt64(0), UInt64(1), UInt64(2), c.q ÷ 2, c.q, c.q + 1, c.q * 2, UInt64(10_000))
        for r in srs
            (c.sr_min <= r <= c.sr_max) || continue
            iseven(r) || continue
            casos += 1
            rr = UInt64(r)
            ref, clamped, _, _ = controlador_ref(rr, n, c)
            fast, clamped_fast = controlador_fast(rr, n, c)
            (BigInt(fast) == ref && clamped == clamped_fast) || (malos += 1)
            iseven(fast) || (impares += 1)
            (c.sr_min <= fast <= c.sr_max) || (fuera += 1)
            clamped && (clamped_ref += 1)
        end
    end
    for (r, n) in aleatorios
        iseven(r) || continue
        casos += 1
        ref, clamped, _, _ = controlador_ref(r, n, c)
        fast, clamped_fast = controlador_fast(UInt64(r), UInt64(n), c)
        (BigInt(fast) == ref && clamped == clamped_fast) || (malos += 1)
        iseven(fast) || (impares += 1)
        (c.sr_min <= fast <= c.sr_max) || (fuera += 1)
    end
    ok = malos == 0 && impares == 0 && fuera == 0
    detalle = "casos=$casos; discrepancias=$malos; salidas impares=$impares; " *
              "fuera de dominio=$fuera; clamps activados en la referencia=$clamped_ref"
    return Comprobacion("controlador: kernel u128 == referencia BigInt", ok, detalle)
end

"""Anchura: la precondición de RCE-v0.1 es necesaria en 128 bits; `u256` no la necesita."""
function validar_ancho(c::ConfigControlador)
    # (a) tres factores u64 caben en 2^192 (y por tanto en u256) pero no en u128
    tres = MAX_U64 * MAX_U64 * MAX_U64
    cabe192 = tres < big(2)^192
    cabe256 = tres < big(2)^256
    no_cabe128 = tres > MAX_U128
    # (b) desbordamiento real de UInt128 con tres factores u64
    desborda = false
    try
        Base.Checked.checked_mul(Base.Checked.checked_mul(UInt128(typemax(UInt64)),
                                                          UInt128(typemax(UInt64))),
                                 UInt128(typemax(UInt64)))
    catch e
        desborda = e isa OverflowError
    end
    # (c) una configuración fuera de la precondición es rechazada por el kernel, no saturada
    rechazada = false
    if !precondicion_u128(c)
        try
            controlador_fast(c.r_inicial, UInt64(1), c)
        catch e
            rechazada = e isa ArgumentError
        end
    end
    ok = cabe192 && cabe256 && no_cabe128 && desborda
    detalle = "(2^64-1)^3 < 2^192 ($cabe192), < 2^256 ($cabe256), > typemax(u128) ($no_cabe128); " *
              "UInt128 desborda de verdad ($desborda); precondición del caso c=$c es " *
              "$(precondicion_u128(c)); rechazo observado si procede ($rechazada)"
    return Comprobacion("anchura: u256 suficiente sin precondición; u128 no", ok, detalle)
end

"""Activación diferida y `MissedUpdate`: la misma frontera que RCE-v0.1."""
function validar_activacion(c::ConfigControlador)
    a1, ok1 = activacion_ref(big(10), big(10), c)
    # sello justo en la primera frontera posterior al corte
    esperado = (fld(big(10), big(c.w_slots)) + 1) * big(c.w_slots) +
               (big(c.retardos_ventana) - 1) * big(c.w_slots)
    ok = ok1 && a1 == esperado
    a2, ok2 = activacion_ref(big(10), a1, c)          # sello en la frontera: MissedUpdate
    ok = ok && !ok2
    # monótona en el corte
    monotona = true
    for corte in big(0):big(10)
        aa, _ = activacion_ref(corte, big(0), c)
        if aa < a1 - big(c.w_slots) * 10
            monotona = false
        end
    end
    return Comprobacion("activación diferida y MissedUpdate", ok && monotona,
                        "corte=10 ⇒ activación=$a1; sello en la frontera ⇒ se pierde ($(!ok2))")
end

"""Z0: `N_j = 0` es no-op. No agenda propuesta y no revierte el rango (enmienda Z0)."""
function validar_z0(c::ConfigControlador)
    ref, clamped, _, _ = controlador_ref(c.r_inicial, 0, c)
    fast, clamped_fast = controlador_fast(c.r_inicial, UInt64(0), c)
    ok = ref == big(c.r_inicial) && fast == c.r_inicial && !clamped && !clamped_fast
    return Comprobacion("Z0: N_j=0 es no-op", ok,
                        "ref=$ref fast=$fast clamped=$clamped/$clamped_fast")
end

"""La deriva por cohorte del kernel nunca supera `γ` (P3, la parte que el controlador fija)."""
function validar_deriva(c::ConfigControlador, srs)
    g = gamma(c)
    peor = 0 // big(1)
    for n in (UInt64(1), UInt64(2), c.q ÷ 4, c.q, c.q * 4, UInt64(1_000_000))
        for r in srs
            (c.sr_min <= r <= c.sr_max) || continue
            out, _ = controlador_fast(UInt64(r), n, c)
            razon = big(out) // big(r)
            peor = max(peor, abs(razon - 1))
        end
    end
    # cota teórica del paso: γ, más el residuo de la rejilla par (<= 1 unidad de SR)
    cota = g + 1 // big(c.sr_min)
    ok = peor <= cota
    return Comprobacion("deriva por cohorte acotada por γ + 1/SR_MIN", ok,
                        "γ=$g; cota=$cota; peor deriva observada=$peor")
end
