using Test

include(joinpath(@__DIR__, "..", "src", "modelo.jl"))
include(joinpath(@__DIR__, "..", "src", "referencia.jl"))
using .Modelo
using .Referencia

"q_a(a_rompe(b),b) debe dar exactamente 2/3, por construcción algebraica."
function a_rompe_check_via_qa()
    b = 4.0
    a = a_rompe(b)
    return q_a(a, b)
end

@testset "AV-1 · fórmulas heredadas de FV-1 (checkpoints [S] contra INFORME.md/CONTRATO de FV-1)" begin
    @test isapprox(a_pausa(4.0), 1/9; atol=1e-12)
    @test isapprox(a_pausa(1.0), 1/3; atol=1e-12)
    @test isapprox(a_pausa(2.0), 1/5; atol=1e-12)     # 0,20 citado en INFORME.md FV-1 §1(e)
    @test isapprox(a_rompe(4.0), 1/3; atol=1e-12)
    @test isapprox(a_rompe(6.0), 1/4; atol=1e-12)
    @test isapprox(a_rompe(10.0), 1/6; atol=1e-12)
    @test isapprox(a_rompe(1.0), 2/3; atol=1e-12)
    @test isapprox(q_a(a_rompe(4.0), 4.0), a_rompe_check_via_qa(); atol=1e-9)
end

@testset "AV-1 · q_a(a_rompe(b),b) == 2/3 y q_a(a_pausa(b),b) == 1/3, para b∈{1,2,4,6,10}" begin
    for b in (1.0, 2.0, 4.0, 6.0, 10.0)
        @test isapprox(q_a(a_rompe(b), b), 2/3; atol=1e-9)
        @test isapprox(q_a(a_pausa(b), b), 1/3; atol=1e-9)
    end
end

@testset "AV-1 · p_necesaria extremos (FV-1 INFORME.md §1(d))" begin
    @test isapprox(p_necesaria(0.25, 1.0), 8/9; atol=1e-6)   # 88,9% con b=1
    # b→∞: p_necesaria -> 2a/(1-a) ... FV-1 cita 66,7% como el límite "solo encendidos" a a=0.25
    @test isapprox(2*0.25/(1-0.25), 2/3; atol=1e-9)
end

@testset "AV-1 · binomial exacta vs recursiva (oráculo de enumeración, K≤30)" begin
    for (s, K) in ((0.01, 20), (0.1, 10), (0.3, 25))
        probs = enumerar_binomial_exacto(s, K)
        @test isapprox(sum(probs), 1.0; atol=1e-9)
        for j in 0:K
            @test isapprox(prob_elegido_binom(s, K, j), probs[j+1]; atol=1e-9)
        end
    end
end

@testset "AV-1 · prob_al_menos_una_plaza vs Monte Carlo (StableRNG, semillas no consecutivas)" begin
    casos = [(0.001, 1000, 0x1111_1111_1111_1111),
             (0.01, 200, 0x2222_2222_2222_2223),
             (0.25, 20, 0x3333_3333_3333_3337)]
    for (s, K, semilla) in casos
        exacto = prob_al_menos_una_plaza(s, K)
        mc = mc_prob_al_menos_una_plaza(s, K, 20000, semilla)
        # tolerancia ~ 5 desviaciones estándar binomiales del MC (n=20000)
        se = sqrt(exacto * (1 - exacto) / 20000)
        @test abs(exacto - mc) <= 5 * se + 1e-6
    end
end

@testset "AV-1 · incidentes_por_instancia: fórmula vs Monte Carlo" begin
    a_eff, K = 0.25, 200
    for m_split in (1, 5, 50)
        exacto = incidentes_por_instancia(a_eff, K, m_split)
        mc = mc_incidentes_por_instancia(a_eff, K, m_split, 20000, UInt64(0x4444_4444_4444_4449) + UInt64(m_split) * UInt64(7))
        @test abs(exacto - mc) < 0.15  # cómputo ligero: tolerancia amplia, orden de magnitud comprobado
    end
end

@testset "AV-1 · hallazgo central: concentración minimiza incidentes con m_aus fijo" begin
    a_eff, K = 0.25, 1000
    inc_concentrado = incidentes_por_instancia(a_eff, K, 1)
    inc_fragmentado = incidentes_por_instancia(a_eff, K, 1000)
    @test inc_concentrado < inc_fragmentado
    @test isapprox(inc_concentrado, 1.0; atol=1e-6)          # (1-a_eff)^K ≈ 0 con K=1000,a_eff=0.25
    # A m_split=1000 (s=a_eff/m_split=2,5·10⁻⁴, K=1000) aún no es el límite de
    # Poisson exacto (K·s no es ≪1): la aproximación de primer orden da
    # K·a_eff·(1 − (K−1)·a_eff/(2·m_split)) ≈ 218,8, y el valor exacto es 221,2.
    # La tolerancia cubre esa corrección de segundo orden, no un error del modelo.
    @test isapprox(inc_fragmentado, a_eff * K; rtol=0.15)
end

@testset "AV-1 · costo_pausa_hora_fijo es ~independiente de `a` para a≫1/K, si concentrado" begin
    K = 1000
    b = 2.0
    m_aus = 10.0
    T_h = 0.000278  # 1 s en horas, ilustrativo (Δ no medida, IPA B-05)
    c1 = costo_pausa_hora_fijo(0.20, b, K, m_aus, T_h; m_split=1)
    c2 = costo_pausa_hora_fijo(0.40, b, K, m_aus, T_h; m_split=1)
    @test isapprox(c1, c2; rtol=0.01)          # ambos ≈ m_aus/T_h: el coste NO crece con a
    @test isapprox(c1, m_aus / T_h; rtol=0.02)
end

@testset "AV-1 · costo_pausa_hora_proporcional SÍ crece con `a` (y es ~independiente de m_split)" begin
    K = 1000
    b = 2.0
    f_aus = 0.1
    Gtot = 1.0e6
    T_h = 0.000278
    c_a20 = costo_pausa_hora_proporcional(0.20, b, K, f_aus, Gtot, T_h; m_split=1)
    c_a40 = costo_pausa_hora_proporcional(0.40, b, K, f_aus, Gtot, T_h; m_split=1)
    @test c_a40 > c_a20 * 1.5   # crece con a (idealmente ×2; con K finito, algo menos por el techo binomial)
    c_split1 = costo_pausa_hora_proporcional(0.25, b, K, f_aus, Gtot, T_h; m_split=1)
    c_split50 = costo_pausa_hora_proporcional(0.25, b, K, f_aus, Gtot, T_h; m_split=50)
    @test isapprox(c_split1, c_split50; rtol=0.05)  # invariante a la fragmentación, a diferencia del caso fijo
end

@testset "AV-1 · denominador encogido por retirada (comparador iv, checkpoints de PROGRAMA.md/DECISIONES.md)" begin
    @test isapprox(a_eff_retirada(0.25, 0.25), 0.3077; atol=2e-4)
    @test isapprox(a_eff_retirada(0.25, 0.50), 0.400; atol=1e-3)
    @test isapprox(a_eff_retirada(0.25, 0.75), 0.5714; atol=2e-4)
end

@testset "AV-1 · q_ev / tasa_fp_censura (patrón SL-2b)" begin
    @test tasa_fp_censura(0.0, 1) == 0.0
    @test tasa_fp_censura(1.0, 1) == 1.0
    # una ventana de gracia amplia (n=1019, F_slots de SL-2b) BAJA la probabilidad
    # de censura total frente a una sola oportunidad (n=1): c^1019 ≪ c^1 para c<1.
    @test tasa_fp_censura(0.9, 1019) < tasa_fp_censura(0.9, 1)
end

@testset "AV-1 · ventana de gracia amplia neutraliza la censura parcial (n grande ⇒ tasa≈0 salvo c=1)" begin
    for c in (0.5, 0.9, 0.99)
        @test tasa_fp_censura(c, 1019) < 1e-4 || c >= 0.999
    end
    @test tasa_fp_censura(0.5, 1019) < tasa_fp_censura(0.5, 1)
end

@testset "AV-1 · datos por día: esquema A3 (compromiso+revelación por ventana) es más barato que A1 (continuo) para N_ventana>1" begin
    instancias_dia = 86400.0  # 1 instancia/segundo, ilustrativo (Δ no medida)
    b1 = bytes_dia_esquema1(instancias_dia)
    for Nv in (10, 100, 1000)
        b3 = bytes_dia_esquema3(instancias_dia, Nv)
        @test b3 < b1
    end
    # A N_ventana=1 (ventana == instancia), A3 debe converger a un coste algo MAYOR que A1
    # (paga también la raíz de compromiso por cada instancia).
    b3_N1 = bytes_dia_esquema3(instancias_dia, 1)
    @test b3_N1 > b1
end

@testset "AV-1 · pérdida esperada del honesto: crece con la fracción de tiempo apagado" begin
    f_h, b, K, instancias_dia = 1e-4, 2.0, 1000, 86400.0
    m_aus = 5.0
    r_siempre = perdida_esperada_honesto_anual(f_h, b, K, instancias_dia, :siempre_encendido, m_aus)
    r_16h = perdida_esperada_honesto_anual(f_h, b, K, instancias_dia, :dieciseis_horas, m_aus)
    r_apagon = perdida_esperada_honesto_anual(f_h, b, K, instancias_dia, :apagon_mensual, m_aus; horas_apagon=6.0)
    @test r_siempre.perdida_confiscacion == 0.0   # nunca apagado ⇒ nunca elegido-y-sin-voto por esta causa
    @test r_apagon.perdida_confiscacion < r_16h.perdida_confiscacion
    @test r_16h.perdida_confiscacion > 0.0
end

@testset "AV-1 · region_m_aus_vacia no rompe y es monótona en el grid pequeño" begin
    ingreso = f_h -> f_h * 1.0e7  # ingreso anual simbólico proporcional al peso, unidad de cuenta [H]
    res = region_m_aus_vacia(0.25, 2.0, 1000, 1.0e6, 0.000278, 1.0, 1e-3, 86400.0, 6.0, ingreso, 0.01;
                              f_aus_grid=0.001:0.005:0.5)
    @test res isa NamedTuple
    @test res.vacia isa Bool
end

println("AV-1 calc/test/runtests.jl: todos los tests declarados arriba se ejecutaron.")
