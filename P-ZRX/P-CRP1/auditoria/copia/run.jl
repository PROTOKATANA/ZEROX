#!/usr/bin/env julia
# CRP-v0.1 — CLI reproducible. Ver METODO.md y CONTRATO.md.
using Pkg
using Printf
using Dates
using StableRNGs

const DIR = @__DIR__
const RES = joinpath(DIR, "resultados")

include(joinpath(DIR, "src", "CosteRamaPrivada.jl"))
using .CosteRamaPrivada

"Raíz del repositorio (sube buscando SPEC.md)."
function raiz_repo()
    a = abspath(DIR)
    for _ in 1:8
        isfile(joinpath(a, "SPEC.md")) && return a
        p = dirname(a); p == a && break; a = p
    end
    return dirname(dirname(dirname(dirname(DIR))))
end

function entorno(comando::String, semilla)
    io = IOBuffer()
    raiz = raiz_repo()
    git = try
        strip(read(`git -C $raiz rev-parse HEAD`, String))
    catch
        "no disponible"
    end
    println(io, "== ENTORNO CRP-v0.1 ==")
    println(io, "git_HEAD: ", git)
    println(io, "fecha: ", Dates.now())
    println(io, "julia: ", VERSION)
    println(io, "cpu: ", Sys.CPU_NAME)
    println(io, "hilos_julia: ", Threads.nthreads(:default), " / ",
            Threads.nthreads(:interactive))
    println(io, "comando: ", comando)
    println(io, "semilla: ", semilla)
    print(io, "pkg: ")
    try
        Pkg.status(io=io)
    catch
        println(io, "no disponible")
    end
    return String(take!(io))
end

const P = P_DEFECTO
const SEMILLA = UInt64(0xC057E07)

# ---------------------------------------------------------------------------
function modo_fuentes()
    raiz = raiz_repo()
    fs = [
        "SPEC.md", "TAREAS.md", "veritas/LINEO.md", "AGENTS.md",
        "research/dag-poas-auditoria.md", "research/dag-poas-ancla-de-orden.md",
        "veritas/consenso/poda-post-v1/INFORME.md",
        "veritas/consenso/poda-post-v1/MODELO.md",
        "veritas/consenso/poda-post-v1/PROCEDENCIA.md",
        "veritas/consenso/ghostdag-rank-v1/src/GhostdagRank.jl",
        "veritas/consenso/ghostdag-rank-v1/src/referencia.jl",
        "veritas/consenso/ghostdag-rank-v1/src/modelo.jl",
        "deepseek/veritas/consenso/prueba-recursiva-v1/INFORME.md",
        "veritas/finalidad/delta-medido-v1/INFORME.md",
    ]
    io = IOBuffer()
    println(io, "== fuentes citadas (existencia comprobada desde la raíz) ==")
    println(io, "raíz: ", raiz)
    faltan = 0
    for f in fs
        p = joinpath(raiz, f)
        if isfile(p)
            println(io, "  OK    ", f, "  (", filesize(p), " B)")
        else
            println(io, "  FALTA ", f); faltan += 1
        end
    end
    println(io, "faltan: ", faltan)
    return String(take!(io))
end

# ---------------------------------------------------------------------------
function modo_teoria()
    io = IOBuffer()
    println(io, "== §2 · La curva α_mínimo: contabilidad exacta ==")
    println(io, "Unidades: espacio total = 1; λ0 = 1 bloque/slot a espacio completo y sr0.")
    println(io, "Trabajo por slot de una rama con fracción s: E = s·λ0 = s, INDEPENDIENTE de sr.")
    println(io, "  (tasa de validación ∝ sr; peso w = ⌊2^128/(sr+1)⌋ ∝ 1/sr)")
    println(io)
    println(io, "Invariancia exacta (sr/sr0)·(w(sr)/w(sr0)) ≈ 1, error de suelos:")
    for c in cota_invariancia(P.sr0)
        @printf(io, "  sr/sr0 = %10.6f   razón = %.15f   error_rel = %.3e\n",
                Float64(c.sr) / Float64(P.sr0), Float64(c.razon), Float64(c.error_rel))
    end
    ci = chequear_invariancia_trabajo(P.sr0)
    @printf(io, "  trabajo exacto para s=3/10: min=%.12f max=%.12f  max/min=%.15f\n",
            Float64(ci.filas[1][2]), Float64(ci.filas[end][2]), Float64(ci.razon_max_min))
    println(io)
    println(io, "Umbral medio (trabajo privado = trabajo honesto):")
    for pub in (false, true)
        u = umbral_medio(0.4; publica=pub)
        @printf(io, "  publica=%-5s  honesto=%.3f adversario=%.3f  razón=%.3f  α*=%.3f\n",
                pub, u.honesto, u.adversario, u.razon, α_estrella_medio(; publica=pub))
    end
    println(io, "  α* = 1/(1+sirv). Con retención (sirv=1) α*=0.5; con publicación (sirv=1) la")
    println(io, "  honesta acumula 1 y el adversario α: sólo gana con α>1, luego publicar está")
    println(io, "  dominado por retener. El umbral operativo es α*=0.5 en los dos protocolos")
    println(io, "  comparables bajo el MISMO criterio (superar blue_work).")
    println(io)
    println(io, "Multiplicidad m (D6): la tasa sube ×m en AMBAS ramas; la razón no cambia.")
    println(io, "  trabajo_honesto = m·(1−α), trabajo_adv = m·α ⇒ α*=0.5, independiente de m.")
    println(io)
    println(io, "Multistream S (ATAQUE 2, condicional al diseño del PoT): cuota Sα/(1−α+Sα).")
    println(io, "  α_min(S) con cuota=1/2: α = 1/(S+1).")
    for S in (1, 2, 4, 8, 16, 24, 64)
        @printf(io, "    S=%3d  α_eff(α=0.45)=%.4f   α_min=%.4f\n", S,
                cuota_multistream(0.45, S), 1 / (S + 1))
    end
    return String(take!(io))
end

# ---------------------------------------------------------------------------
function modo_corto()
    io = IOBuffer()
    println(io, "== §3.3 · Régimen CORTO: alcanzar desde una ventaja inicial d ==")
    println(io, "Probabilidad de que el adversario alcance (lleve el déficit a ≤0):")
    println(io, "  exacta ±1: (α/(1−α))^d ; difusión: exp(−2(1−2α)d·g); DP Poisson-step.")
    @printf(io, "%5s %6s %14s %14s %14s\n", "d", "α", "exacta±1", "difusion(g=1)", "DP Poisson")
    for f in validar_curva_corta()
        @printf(io, "%5d %6.2f %14.6e %14.6e %14.6e\n", f.d, f.α,
                Float64(f.exacta), f.difusion, f.dp)
    end
    println(io)
    println(io, "Granularidad g (bloques por unidad de trabajo): DP Poisson, α=0.4, d=6.")
    for g in (1, 4, 16, 64, 256)
        p = prob_alcance_dp(0.4, float(g), 600; d=6)
        @printf(io, "  g=%4d  p=%.3e\n", g, p)
    end
    println(io, "  g mayor = más bloques más pequeños = menos varianza = menos cola para el")
    println(io, "  adversario, con la MISMA media. Ésa es la contribución del DAG (Kaspa/ZEROX)")
    println(io, "  frente a la cadena lineal; no mueve el umbral α*=0.5, mueve la varianza.")
    println(io)
    println(io, "α_mínimo(d, ε=0.10) para pasos ±1: invertir (α/(1−α))^d = ε.")
    for d in (3, 6, 12, 24, 50)
        αmin = 1.0 / (1.0 + (0.10)^(-1.0 / d))
        @printf(io, "  d=%3d  α_min=%.4f\n", d, αmin)
    end
    println(io, "  → α_min → 0.5 por arriba al crecer d; para d→∞ es 0.5 exacto.")
    println(io)
    println(io, "VARIANZA ELEGIDA POR EL ADVERSARIO (PoST): fijar sr=sr0/K da el mismo trabajo")
    println(io, "medio αT con más varianza. ¿Baja α_min a horizonte finito? MC (α=0.45):")
    @printf(io, "%6s %14s %14s %14s\n", "K", "P(adv>hon)", "E[trabajo_adv]", "α·T")
    for f in efecto_varianza_sr(P; α=0.45, n_slots=400, factores=(1, 4, 16, 64), n_rep=4000)
        @printf(io, "%6d %14.4f %14.2f %14.2f\n", f[1], f[2], f[3], f[4])
    end
    println(io, "  Mismo medio; P(superar) sube con K: el adversario puede comprar cola con")
    println(io, "  varianza. Lo acota R-FIN-13′ (propiedad MUST en PROPUESTA.md), no el umbral.")
    return String(take!(io))
end

# ---------------------------------------------------------------------------
function modo_gdr(GDR)
    io = IOBuffer()
    println(io, "== §4.1 · DAG real con GDR-v0.2 (se reutiliza; no se reimplementa) ==")
    println(io, "Trabajo por slot normalizado a w(sr0); debe ≈ s con independencia de sr.")
    @printf(io, "%6s %14s %10s %10s %16s %16s\n", "s", "sr/sr0", "n_total", "n_azules",
            "trabajo_norm", "trabajo/slot")
    for f in experimento_gdr_invariancia(GDR, P; n_slots=200)
        @printf(io, "%6.2f %14.2f %10d %10d %16.2f %16.4f\n", f.s,
                Float64(f.sr) / Float64(P.sr0), f.n_total, f.n_azules,
                f.trabajo_norm, f.trabajo_por_slot)
    end
    println(io)
    println(io, "Controladores (familia; R-FIN-13′ NO está especificado):")
    @printf(io, "%16s %10s %16s %16s %16s\n", "ancla", "s", "trabajo/slot", "min", "max")
    for f in experimento_gdr_controlador(GDR, P; s=0.3, n_slots=300, n_rep=8)
        @printf(io, "%16s %10.2f %16.4f %16.4f %16.4f\n", string(f.ancla), f.s,
                f.trabajo_por_slot, f.min, f.max)
    end
    println(io, "  CTRL_FIJO y CTRL_REACTIVO dan trabajo/slot ≈ s. El controlador cambia la")
    println(io, "  varianza, no la media. CTRL_INVERSO lleva sr a 0 y no produce bloques.")
    println(io)
    println(io, "== §3.4 · U2/U3″ contextual, contra el oráculo ==")
    r = experimento_u2u3(GDR)
    println(io, "  dentro de una rama: copias válidas=", r[:dentro_copias_validas],
            "  azules ident7=", r[:dentro_azules_ident7],
            "  rojo_U3=", r[:dentro_rojoU3])
    println(io, "  U2 rechaza el mismo billete en el pasado: ", r[:u2_rechaza],
            " (", r[:u2_motivo], ")")
    println(io, "  entre ramas disjuntas: válidas=", r[:entre_validas],
            "  ambas azules en su rama=", r[:entre_ambas_azules_en_su_rama])
    println(io, "  un fusionador ve una azul y la otra rojo_U3: ",
            r[:entre_fusion_una_azul_otra_u3])
    println(io, "  → U3″ SÍ bloquea el doble uso dentro de una rama y NO entre ramas disjuntas.")
    return String(take!(io))
end

# ---------------------------------------------------------------------------
function modo_controladores()
    io = IOBuffer()
    println(io, "== §3.2 · Dirección y magnitud del SR endógeno ==")
    println(io, "El vector exige DESACOPLAR el sr que valida del sr que pondera:")
    println(io, "  E[trabajo/slot] = s·(sr_val/sr0)·w(sr_peso)/w(sr0) ≈ s·(sr_val/sr_peso).")
    println(io, "En el SPEC ambos son el MISMO campo (C-GD-01 + §7.1): no hay vector de media.")
    @printf(io, "%14s %14s %14s %14s\n", "sr_val/sr0", "sr_peso/sr0", "amplificación",
            "trabajo/slot(α=0.3)")
    for (rv, rp) in ((1.0, 1.0), (1.0, 4.0), (1.0, 16.0), (4.0, 1.0), (16.0, 1.0))
        amp = rv / rp
        @printf(io, "%14.2f %14.2f %14.3f %14.4f\n", rv, rp, amp, 0.3 * amp)
    end
    println(io, "  Acoplado (sr_val=sr_peso) la amplificación es 1. Separarlos multiplica el")
    println(io, "  trabajo por sr_val/sr_peso sin pagar espacio. PROPIEDAD MUST en PROPUESTA.md.")
    println(io)
    println(io, "Medición Monte Carlo del trabajo/slot con la familia de controladores (s=0.3):")
    for ancla in (CTRL_FIJO, CTRL_REACTIVO, CTRL_INVERSO)
        ctrl = Controlador(P; ancla=ancla, gamma=0.5, ventana=50)
        tot = 0.0
        for r in 1:2000
            rr = simular_rama_rapido(StableRNG(1000 + r), 0.3, P; n_slots=300, ctrl=ctrl)
            tot += rr.trabajo
        end
        @printf(io, "  %-14s trabajo/slot = %.4f (esperado 0.3)\n", string(ancla), tot / 2000 / 300)
    end
    println(io, "  Con ganancia 0.5 y ventana 50 (controlador estable), CTRL_FIJO y CTRL_REACTIVO")
    println(io, "  dan ≈ s: la DIRECCIÓN de un controlador que mantiene la producción no cambia")
    println(io, "  el trabajo medio. CTRL_INVERSO baja sr hasta el mínimo, deja de producir")
    println(io, "  bloques y su trabajo tiende a 0: no es un vector de ganancia. El vector de")
    println(io, "  varianza (sr bajo fijo, no por controlador) se mide en --corto.")
    return String(take!(io))
end

# ---------------------------------------------------------------------------
function modo_referencias()
    io = IOBuffer()
    println(io, "== §4.2 · Tres protocolos bajo el MISMO escenario y criterio ==")
    println(io, "Criterio: la rama alternativa gana si su trabajo acumulado supera el observable.")
    println(io, "Las tres acumulan trabajo ∝ fracción de recurso: media α*=0.5 con retención.")
    @printf(io, "%16s %10s %12s %14s %14s\n", "protocolo", "α* medio", "granularidad",
            "doble uso", "α_min(d=6,ε=.1)")
    @printf(io, "%16s %10.3f %12s %14s %14.4f\n", "PoW lineal", 0.5, "1", "no", 1/(1+0.10^(-1/6)))
    @printf(io, "%16s %10.3f %12s %14s %14.4f\n", "GHOSTDAG/PoW", 0.5, "alta (~10-100)",
            "no", 1/(1+0.10^(-1/6)))
    @printf(io, "%16s %10.3f %12s %14s %14.4f\n", "PoST DAG (ZEROX)", 0.5, "elegible",
            "sí (económico)", 1/(1+0.10^(-1/6)))
    println(io, "  El DAG no cambia el umbral medio; reduce varianza (fila anterior). El doble")
    println(io, "  uso no baja el umbral; cambia el COSTE (siguiente).")
    println(io)
    println(io, "Separación DAG / PoST en la cola corta (α=0.4, d=6, DP):")
    for (nom, g) in (("PoW lineal (g=1)", 1.0), ("GHOSTDAG/PoW (g≈10)", 10.0),
                     ("ZEROX, sr fijo alto (g grande)", 256.0))
        @printf(io, "    %-32s p_alcance=%.3e\n", nom, prob_alcance_dp(0.4, g, 600; d=6))
    end
    println(io, "  El DAG baja la cola por granularidad. Pero PoST deja al adversario ELEGIR")
    println(io, "  sr (varianza, --corto): con sr bajo puede subir su cola por encima de la")
    println(io, "  de Kaspa. Ese eje NO existe en PoW: la dificultad es común, no del atacante.")
    println(io)
    println(io, "== §3.1 · Umbral frente a coste económico (nothing-at-stake) ==")
    println(io, "PoW: atacar exige DESVIAR recurso; se renuncia a la recompensa honesta de α")
    println(io, "     durante la ventana de ataque T_a. Coste_op = α·R·T_a (R = recompensa/s).")
    println(io, "PoST: el mismo espacio produce en la rama privada; el adversario puede seguir")
    println(io, "     cobrando en la honesta hasta el punto de bifurcación. Coste marginal de")
    println(io, "     RECURSO del ataque = 0; el coste de oportunidad se reduce al tramo de")
    println(io, "     retención posterior a la bifurcación, que para una reorg corta es ~Δ·conf.")
    println(io, "     Con α>0.5 el ataque es ‘gratis’ en recursos; CON α≤0.5 no gana el umbral.")
    println(io, "  Cuantificación: coste_op(PoST)/coste_op(PoW) = T_retención/T_a → 0 para")
    println(io, "  reorg corta; = 1 para long-range (hay que retener toda la reconstrucción).")
    println(io, "  Esto encarece la HONESTIDAD (opcionalidad), no rompe el umbral.")
    return String(take!(io))
end

# ---------------------------------------------------------------------------
function modo_resumen(GDR)
    io = IOBuffer()
    for (nom, txt) in (("TEORIA", modo_teoria()), ("CORTO", modo_corto()),
                       ("CONTROLADORES", modo_controladores()),
                       ("REFERENCIAS", modo_referencias()), ("GDR", modo_gdr(GDR)))
        println(io, "##### ", nom, " #####"); println(io, txt); println(io)
    end
    return String(take!(io))
end

function main(args)
    semilla = SEMILLA
    if "--seed" in args
        i = findfirst(==("--seed"), args); semilla = parse(UInt64, args[i + 1])
    end
    modo = isempty(args) ? "--ayuda" : args[1]
    salida = let i = findfirst(==("--out"), args)
        i === nothing ? nothing : args[i + 1]
    end
    cab = entorno(join(args, " "), semilla)
    necesita_gdr = modo in ("--gdr", "--resumen")
    texto = if modo == "--entorno"
        cab
    elseif modo == "--fuentes"
        cab * "\n" * modo_fuentes()
    elseif modo == "--teoria"
        cab * "\n" * modo_teoria()
    elseif modo == "--corto"
        cab * "\n" * modo_corto()
    elseif modo == "--controladores"
        cab * "\n" * modo_controladores()
    elseif modo == "--referencias"
        cab * "\n" * modo_referencias()
    elseif necesita_gdr
        GDR = incluir_ghostdag()
        cuerpo = Base.invokelatest(modo == "--gdr" ? modo_gdr : modo_resumen, GDR)
        cab * "\n" * cuerpo
    else
        cab * "\nmodos: --entorno --fuentes --teoria --corto --controladores " *
              "--referencias --gdr --resumen [--seed S] [--out f]\n"
    end
    print(texto)
    if salida !== nothing
        isdir(RES) || mkpath(RES)
        write(joinpath(RES, salida), texto)
    end
end

main(collect(ARGS))
