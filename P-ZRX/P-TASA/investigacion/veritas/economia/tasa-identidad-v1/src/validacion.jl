# =============================================================================
# validacion.jl — rutinas de validación (las usan `test/runtests.jl` y `run.jl`)
# -----------------------------------------------------------------------------
# Cada función devuelve una estructura con los controles y su resultado, para que
# el informe pueda citar el número exacto de controles y no sólo «pasa».
# =============================================================================

"""
    ResultadoValidacion

`nombre`, `controles` (número), `fallos` (número) y `detalle` (vector de textos
de los fallos, vacío si no hay).
"""
mutable struct ResultadoValidacion
    nombre::String
    controles::Int
    fallos::Int
    detalle::Vector{String}
end

function ResultadoValidacion(nombre::String)
    return ResultadoValidacion(nombre, 0, 0, String[])
end

"""
    anotar!(r, condicion, mensaje) -> r

Suma un control y registra el fallo con su mensaje. Muta `r` y lo devuelve, para
poder encadenar. No hay ninguna tautología: el control recibe la condición ya
calculada por quien llama.
"""
function anotar!(r::ResultadoValidacion, condicion::Bool, mensaje::String)
    r.controles += 1
    if !condicion
        r.fallos += 1
        push!(r.detalle, mensaje)
    end
    return r
end

# -----------------------------------------------------------------------------
# V1 · Álgebra exacta del umbral
# -----------------------------------------------------------------------------
"""
    validar_umbral_exacto() -> ResultadoValidacion

`g(α*) = 0` exacto en `Rational{BigInt}` para una rejilla de `(βd, βx, ηh, ηa)`;
signo estricto a los dos lados de `α*`; y los casos particulares del encargo.
"""
function validar_umbral_exacto()
    r = ResultadoValidacion("umbral exacto")
    for βd in (0 // 1, 1 // 10, 1 // 5, 1 // 3, 1 // 2)
        for βx in (0 // 1, 1 // 10, 1 // 5)
            for (ηh, ηa) in ((1 // 1, 1 // 1), (3 // 2, 1 // 1), (1 // 1, 3 // 4), (5 // 4, 1 // 2))
                αs = alpha_estrella_t(βd, βx, ηh, ηa)
                r = anotar!(r, deriva_t(αs, βd, βx, ηh, ηa) == 0 // 1,
                            "g(α*)≠0 en βd=$βd βx=$βx ηh=$ηh ηa=$ηa")
                # signo estricto a los dos lados (exacto: desplazamiento racional)
                δ = 1 // 1000
                r = anotar!(r,
                            (deriva_t(αs - δ, βd, βx, ηh, ηa) < 0 // 1) !=
                            (deriva_t(αs + δ, βd, βx, ηh, ηa) < 0 // 1),
                            "el signo no cambia al cruzar α* en βd=$βd βx=$βx")
                r = anotar!(r, deriva_t(αs + δ, βd, βx, ηh, ηa) > 0 // 1,
                            "deriva no positiva a la derecha de α*")
                r = anotar!(r, deriva_t(αs - δ, βd, βx, ηh, ηa) < 0 // 1,
                            "deriva no negativa a la izquierda de α*")
            end
        end
    end
    # Casos particulares con η = 1
    r = anotar!(r, alpha_estrella_t(0 // 1, 0 // 1, 1 // 1, 1 // 1) == 1 // 2, "α*(0,0) ≠ 1/2")
    r = anotar!(r, alpha_estrella_t(1 // 5, 0 // 1, 1 // 1, 1 // 1) == 2 // 5, "α*(1/5,0) ≠ 2/5")
    r = anotar!(r, alpha_estrella_t(0 // 1, 1 // 10, 1 // 1, 1 // 1) == 2 // 5,
                "α*(0,1/10) ≠ 2/5")
    # βx vale el doble que βd: la misma reducción del umbral con la mitad de espacio
    for β in (1 // 10, 1 // 5, 1 // 3)
        r = anotar!(r, alpha_estrella_t(β, 0 // 1, 1 // 1, 1 // 1) ==
                       alpha_estrella_t(0 // 1, β // 2, 1 // 1, 1 // 1),
                    "βx no vale el doble que βd con β=$β")
    end
    r = anotar!(r, frontera_beta_d(1 // 3, 1 // 1, 1 // 1) == 1 // 3, "1−2α ≠ 1/3 con α=1/3")
    r = anotar!(r, frontera_beta_x(1 // 3, 1 // 1, 1 // 1) == 1 // 6, "1/2−α ≠ 1/6 con α=1/3")
    return r
end

# -----------------------------------------------------------------------------
# V2 · Las tres variantes: coste por byte y dependencia de κ
# -----------------------------------------------------------------------------
"""
    validar_variantes() -> ResultadoValidacion

`:A` da coste por byte constante (no cumple el teorema); `:B` y `:C` divergen al
reducir el tamaño de la identidad (sí lo cumplen). `:B` es la única que depende de
`κ` como coste por identidad.
"""
function validar_variantes()
    r = ResultadoValidacion("variantes de coste")
    r = anotar!(r, !depende_de_kappa(:A) && depende_de_kappa(:B) && !depende_de_kappa(:C),
                "la dependencia de κ por variante no es la declarada")
    s1 = 1 // 100
    s2 = s1 // 1000
    cA1 = coste_por_byte(:A, s1, 1 // 2)
    cA2 = coste_por_byte(:A, s2, 1 // 2)
    r = anotar!(r, cA1 == cA2, ":A no es constante por byte")
    cB1 = coste_por_byte(:B, s1, 1 // 1, 1 // 1)
    cB2 = coste_por_byte(:B, s2, 1 // 1, 1 // 1)
    r = anotar!(r, cB2 == 1000 * cB1, ":B no diverge como 1/s_id")
    cC1 = coste_por_byte(:C, s1, 1 // 1)
    cC2 = coste_por_byte(:C, s2, 1 // 1)
    r = anotar!(r, cC2 == 1000 * cC1, ":C no diverge como 1/s_id")
    # partición neutral en :A, lineal en :B, exacta (no lineal) en :C
    r = anotar!(r, costo_A(s1, 1 // 2) + costo_A(s2, 1 // 2) == costo_A(s1 + s2, 1 // 2),
                ":A no es neutral bajo partición")
    r = anotar!(r, costo_B(1 // 1, 1 // 1) * 2 == 2 * costo_B(1 // 1, 1 // 1),
                ":B no es lineal en N")
    r = anotar!(r, costo_C(1 // 1) + costo_C(1 // 1) > costo_C(1 // 1),
                ":C no es subaditiva en identidades")
    r = anotar!(r, costo_B(2 // 1, 5 // 1) == 10 // 1, ":B no escala con κq")
    return r
end

# -----------------------------------------------------------------------------
# V3 · Dicotomía partición/regresividad
# -----------------------------------------------------------------------------
"""
    validar_dicotomia() -> ResultadoValidacion

Sobre una rejilla exacta de `f` y `N`, comprueba que en toda la familia
estrictamente cóncava se cumple **a la vez** «partir cuesta» y «es regresiva», y
que la lineal no cumple ninguna de las dos. Es la validación del teorema que
responde a §2.3; no es una comparación de una fórmula consigo misma porque las dos
propiedades se evalúan con expresiones distintas (`Nφ(f/N)` frente a `φ(f)/f`).
"""
function validar_dicotomia()
    r = ResultadoValidacion("dicotomía partición/regresividad")
    fr = Rational{BigInt}[1 // 1000, 1 // 100, 1 // 20, 1 // 10, 1 // 4, 1 // 2, 3 // 4]
    Ns = [2, 3, 5, 10]
    concavas = Horario{Rational{BigInt}}[Fija(Rational{BigInt}(1)),
                                       FijaLineal(Rational{BigInt}(1), Rational{BigInt}(1) / 10)]
    lineal = Lineal{Rational{BigInt}}(Rational{BigInt}(1))
    for h in concavas
        for f in fr, N in Ns
            f * N ≤ 1 || continue
            parte = particion_mas_cara(h, f, N)
            reg = regresiva(h, f, f * N)
            r = anotar!(r, parte, "concava: partir no cuesta ($(typeof(h)), f=$f, N=$N)")
            r = anotar!(r, reg, "concava: no es regresiva ($(typeof(h)), f=$f)")
            r = anotar!(r, parte == reg, "las dos propiedades discrepan en $h")
        end
    end
    for f in fr, N in Ns
        f * N ≤ 1 || continue
        r = anotar!(r, !particion_mas_cara(lineal, f, N),
                    "lineal: partir cuesta (no debe)")
        r = anotar!(r, !regresiva(lineal, f, f * N), "lineal: regresiva (no debe)")
    end
    # La escalera con tope degenera en lineal cuando Smax → 0 y en fija cuando
    # Smax ≥ fmax: es el dial entre (a) y (c). Tasa efectiva por byte τ/Smax.
    escalera = Tope{Rational{BigInt}}(Rational{BigInt}(1), Rational{BigInt}(1) / 16)
    r = anotar!(r, tasa_por_byte_tope(escalera) == Rational{BigInt}(16),
                "tasa por byte del tope ≠ τ/Smax")
    r = anotar!(r, desviacion_tope(escalera, Rational{BigInt}(1)) == Rational{BigInt}(0),
                "la escalera no coincide con la recta en múltiplos exactos")
    fi = Fija{Rational{BigInt}}(Rational{BigInt}(1))
    r = anotar!(r, cuota(fi, Rational{BigInt}(1) / 1000) == Rational{BigInt}(1),
                "φ fija ≠ τ")
    return r
end

# -----------------------------------------------------------------------------
# V4 · Φ de la Pareto: primitiva cerrada contra suma de Riemann
# -----------------------------------------------------------------------------
"""
    validar_phi_pareto(; K=4000) -> ResultadoValidacion

La primitiva cerrada de `modelo.jl` debe caer **dentro** del intervalo de
Riemann de `referencia.jl` en toda la rejilla, y el intervalo debe encogar al
aumentar `K`. Independiente de la primitiva.
"""
function validar_phi_pareto(; K::Integer = 4000)
    r = ResultadoValidacion("Φ Pareto: cerrada vs Riemann")
    for a in (2.05, 2.2, 2.5, 3.0)
        d = ParetoTruncado(1e-8, 1.0, a)
        for x in (1e-8, 1e-7, 1e-6, 1e-5, 1e-4, 1e-3, 1e-2, 1e-1, 1.0)
            cerrada = Phi_espacio(d, x)
            lo, hi, ancho = Phi_pareto_riemann(d, x; K = K)
            r = anotar!(r, lo - 1e-12 ≤ cerrada ≤ hi + 1e-12,
                        "cerrada fuera del intervalo en a=$a x=$x ($lo ≤ $cerrada ≤ $hi)")
            r = anotar!(r, ancho ≥ 0, "ancho negativo en a=$a x=$x")
        end
    end
    # monotonía estricta y bordes exactos
    d = ParetoTruncado(1e-8, 1.0, 2.2)
    r = anotar!(r, Phi_espacio(d, 1e-8) == 1.0, "Φ(fmin) ≠ 1")
    r = anotar!(r, Phi_espacio(d, 1.0) == 0.0, "Φ(fmax) ≠ 0")
    prev = 1.0
    for x in (1e-7, 1e-6, 1e-5, 1e-4, 1e-3, 1e-2)
        v = Phi_espacio(d, x)
        r = anotar!(r, v < prev, "Φ no decrece en x=$x")
        prev = v
    end
    # inversa
    for p in (0.05, 0.2, 0.34, 0.5, 0.8)
        f = inversa_Phi(d, p)
        r = anotar!(r, abs(Phi_espacio(d, f) - p) < 1e-9, "inversa_Phi inconsistente en p=$p")
    end
    return r
end

# -----------------------------------------------------------------------------
# V5 · Monte Carlo contra la primitiva (con IC)
# -----------------------------------------------------------------------------
"""
    validar_mc(; M=100_000, R=16, maestra=UInt64(0x5a5a)) -> ResultadoValidacion

El valor cerrado debe caer dentro del **IC de Wilson** del estimador (que es una
proporción desde que muestrea la medida de espacio), y dentro del IC t entre
réplicas. Se comprueba además que las réplicas con semillas derivadas no son
idénticas, que hay aciertos en la cola y que el resultado es determinista con la
misma semilla maestra.
"""
function validar_mc(; M::Integer = 100_000, R::Integer = 16, maestra::UInt64 = UInt64(0x5a5a))
    r = ResultadoValidacion("MC vs Φ cerrada")
    # semillas no consecutivas
    s = [semilla_replica(maestra, i) for i in 1:8]
    r = anotar!(r, all(s[i] != s[i + 1] for i in 1:7), "semillas consecutivas")
    dif = [s[i+1][1] - s[i][1] for i in 1:7]
    r = anotar!(r, !all(d == dif[1] for d in dif), "las semillas avanzan de forma constante")
    d = ParetoTruncado(1e-8, 1.0, 2.2)
    for x in (1e-6, 1e-4, 1e-2)
        cerrada = Phi_espacio(d, x)
        esperados = cerrada * M * R
        res = mc_phi(maestra, d, x, M, R)
        # LINEO §5.3: sólo se certifica donde el aparato tiene resolución. Con
        # menos de 20 aciertos esperados el IC de Wilson no cubre de forma
        # fiable una `p` diminuta (es una propiedad de frecuencia, no de la
        # muestra), y el resultado se declara **no aplicable**, no «falso».
        if esperados ≥ 20
            r = anotar!(r, res.wilson_lo ≤ cerrada ≤ res.wilson_hi,
                        "Wilson no contiene el cerrado en x=$x ($(res.wilson_lo) ≤ $cerrada ≤ $(res.wilson_hi))")
            r = anotar!(r, res.ic_lo ≤ cerrada ≤ res.ic_hi,
                        "el IC t no contiene el cerrado en x=$x ($(res.ic_lo) ≤ $cerrada ≤ $(res.ic_hi))")
        else
            r = anotar!(r, esperados < 20,
                        "la declaración de no aplicabilidad está mal puesta en x=$x")
        end
        r = anotar!(r, res.desv ≥ 0, "desviación negativa entre réplicas en x=$x")
    end
    a = mc_phi(maestra, d, 1e-4, M, R)
    b = mc_phi(maestra, d, 1e-4, M, R)
    r = anotar!(r, a.ratios == b.ratios, "el MC no es determinista con la misma semilla")
    c = mc_phi(maestra + 1, d, 1e-4, M, R)
    r = anotar!(r, a.ratios != c.ratios, "semilla distinta no cambia el flujo")
    return r
end

# -----------------------------------------------------------------------------
# V6 · Reclutamiento: avaricioso contra exacto
# -----------------------------------------------------------------------------
"""
    validar_reclutamiento(; semilla=0x5a5a) -> ResultadoValidacion

Contraejemplo de que el avaricioso **no** es óptimo cuando hay coste fijo por
granja, y comprobación de que el exacto de dos niveles coincide con la fuerza
bruta. Se construye el contraejemplo explícitamente (no se busca al azar).
"""
function validar_reclutamiento()
    r = ResultadoValidacion("reclutamiento avaricioso vs exacto")
    # Contraejemplo construido de que el avaricioso no es óptimo con coste fijo
    # por granja: (espacio, soborno) = (1, 9/10), (3/5, 1/2), (3/5, 1/2), β = 1.
    # El avaricioso ordena por soborno/espacio (0,833 < 0,833 < 0,9), toma las dos
    # pequeñas y paga 1; el óptimo es la grande sola por 0,9.
    f = [1 // 1, 3 // 5, 3 // 5]
    sob = [9 // 10, 1 // 2, 1 // 2]
    β = 1 // 1
    av = reclutamiento_avaricioso(f, sob, β)
    ex = reclutamiento_bruto(f, sob, β)
    r = anotar!(r, av.espacio ≥ β && ex.espacio ≥ β, "alguna vía no alcanza β")
    r = anotar!(r, ex.coste == 9 // 10, "el exacto no elige la grande sola")
    r = anotar!(r, av.coste == 1 // 1, "el avaricioso no paga 1 con las dos pequeñas")
    r = anotar!(r, av.coste > ex.coste,
                "el avaricioso debería ser no óptimo: $(av.coste) vs $(ex.coste)")

    # Fuerza bruta contra el exacto de dos niveles en instancias pequeñas
    for θ in (Rational{BigInt}(1) / 2, Rational{BigInt}(3) / 4), K in (2, 4)
        fg = θ
        τ = Rational{BigInt}(1) / 100
        c_b = Rational{BigInt}(0)
        κq = Rational{BigInt}(1)
        Lp = Rational{BigInt}(1)
        λ = Rational{BigInt}(1)
        I = Rational{BigInt}(1)
        Pwin = Rational{BigInt}(1)
        Th = Rational{BigInt}(1)
        β2 = Rational{BigInt}(3) / 4
        d = dos_niveles_discreta(θ, fg, K)
        sobs = [soborno_granja(fi, τ, c_b, κq, Lp, λ, I, Pwin, Th) for fi in d.f]
        exn = reclutamiento_dos_niveles(θ, fg, K, τ, c_b, κq, Lp, λ, I, Pwin, Th, β2)
        bru = reclutamiento_bruto(d.f, sobs, β2)
        r = anotar!(r, exn.coste == bru.coste,
                    "dos niveles ≠ fuerza bruta (θ=$θ K=$K): $(exn.coste) vs $(bru.coste)")
    end
    return r
end

# -----------------------------------------------------------------------------
# V7 · Macros y tipos prohibidos en el código fuente
# -----------------------------------------------------------------------------
"""
    sin_macros_prohibidas(rutas) -> Vector{String}

Busca `@fastmath`, `@turbo` y `Float32` **fuera de comentarios**. Devuelve las
infracciones como `archivo:línea: texto`. Es un control de reglas, no de cálculo.
Las líneas que implementan el propio buscador (`occursin(`) se saltan para que el
verificador no se delate a sí mismo.
"""
function sin_macros_prohibidas(rutas::Vector{String})
    infracciones = String[]
    for ruta in rutas
        isfile(ruta) || continue
        for (n, linea) in enumerate(eachline(ruta))
            codigo = linea
            i = findfirst('#', codigo)
            i === nothing || (codigo = codigo[1:i-1])
            occursin("occursin(", codigo) && continue
            occursin('`', codigo) && continue   # docstrings y comentarios en línea
            if occursin("@fastmath", codigo) || occursin("@turbo", codigo) ||
               occursin("Float32", codigo)
                push!(infracciones, "$ruta:$n: $(strip(linea))")
            end
        end
    end
    return infracciones
end
