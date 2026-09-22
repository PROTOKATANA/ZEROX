# gdr-d1-d8.jl — D1 (¿el supuesto DAG era una cadena?) y D8 (fixture U2/U3″ insuficiente).
#
# Requiere el oráculo GDR-v0.2 y el instrumento CRP-v0.1. Se ejecuta con el proyecto de la copia:
#   ./julia-local.sh --project=copia gdr-d1-d8.jl
# NO modifica nada de CRP-v0.1 ni de GDR.
include(joinpath(@__DIR__, "copia", "src", "CosteRamaPrivada.jl"))
using .CosteRamaPrivada
using Printf
using StableRNGs
using Random

GDR = incluir_ghostdag()
const P = P_DEFECTO

"Resumen estructural de un estado GDR: puntas, azules, rojos por tipo y tamaño del mergeset."
function estructura(GDR, est)
    tips = GDR.tips(est)
    v = GDR.virtual_sp(est, GDR.P_DEFECTO)
    bs = GDR.blueset(est, v)
    n_red_01 = 0; n_red_02 = 0; ms_max = 0; ms_con_red = 0
    for i in 1:est.n
        g = est.gd[i]
        n_red_01 += count(x -> get(g.tipos, x, 0x00) == 0x01, g.ms_reds)
        n_red_02 += count(x -> get(g.tipos, x, 0x00) == 0x02, g.ms_reds)
        ms = length(g.ms_blues) + length(g.ms_reds)
        ms_max = max(ms_max, ms)
        length(g.ms_reds) > 0 && (ms_con_red += 1)
    end
    return (n_bloques = est.n - 1, n_puntas = length(tips), n_azules_blueset = length(bs),
            rojo_k = n_red_01, rojo_U3 = n_red_02, ms_max = ms_max,
            bloques_con_rojo = ms_con_red, bw_punta = est.gd[v].bw, v = v)
end

# ---------------------------------------------------------------------------
println("##### D1 · ¿el supuesto DAG era una cadena? #####")
println()
println("(a) `construir_rama_gdr` TAL CUAL (copia/src/rapido.jl:195-260): actualiza las puntas tras")
println("    CADA bloque, incluso dentro del mismo slot.")
@printf("%6s %8s %10s %10s %10s %9s %9s %8s\n", "s", "sr/sr0", "n_total", "n_azules",
        "n_puntas", "rojo_k", "rojo_U3", "ms_max")
for (s, sr, sem) in ((0.1, P.sr0, 0x6D1), (0.3, P.sr0, 0x6D2), (0.3, P.sr0 << 2, 0x6D3),
                     (0.5, P.sr0, 0x6D4))
    rng = StableRNG(UInt64(sem))
    t = construir_rama_gdr(GDR, P; s = s, n_slots = 200, sr_fijo = sr, rng = rng)
    e = estructura(GDR, t.est)
    @printf("%6.2f %8.2f %10d %10d %10d %9d %9d %8d\n", s,
            Float64(sr) / Float64(P.sr0), e.n_bloques, e.n_azules_blueset,
            e.n_puntas, e.rojo_k, e.rojo_U3, e.ms_max)
end
println()
println("    Identidad observada: n_azules = n_total + 1 en TODAS las filas (el +1 es el génesis,")
println("    que `blueset` incluye, GDR src/modelo.jl:249). Y n_puntas = 1 siempre: no hay anticonos.")
println()

println("(b) CONTROL: la misma construcción con VISTA LOCAL — los k bloques de un slot se autorían")
println("    contra la vista del INICIO del slot, antes de propagar los del propio slot (la")
println("    corrección que pide D1). Se mide también el máximo de puntas alcanzado.")
@printf("%6s %10s %10s %10s %9s %9s %8s %10s %11s\n", "s", "n_total", "n_azules", "n_puntas",
        "rojo_k", "rojo_U3", "ms_max", "azules/nt", "max_puntas")
for s in (0.3, 1.0, 3.0)
    rng = StableRNG(UInt64(0x6E0) + UInt64(round(Int, 100s)))
    est = GDR.EstadoRapido(params_gdr(GDR, P), "G"; sr_g = P.sr0)
    puntas = Int[1]
    max_puntas = 1
    for t in 1:200
        k = min(poisson_knuth(rng, tasa_esperada(s, P.sr0, P)), 50)
        vista = copy(puntas)                       # vista al INICIO del slot
        nuevos = Int[]
        usados = Set{Int}()
        for _ in 1:k
            sp = vista[1]
            mejor = GDR.bw_de(est, sp)
            for x in vista[2:end]
                bx = GDR.bw_de(est, x)
                (bx > mejor || (bx == mejor && x < sp)) && (sp = x; mejor = bx)
            end
            extras = [x for x in vista if x != sp]
            npad = min(length(extras), Int(P.max_padres) - 1)
            if npad > 0
                shuffle!(rng, extras)
                extras = extras[1:npad]
            end
            padres = vcat(sp, extras)
            ok = GDR.anadir!(est, params_gdr(GDR, P), string("B_", t, "_", length(nuevos) + 1),
                             padres, UInt64(t), UInt64(rand(rng, 0:(2^20))), P.sr0, UInt64(0))
            ok || continue
            push!(nuevos, est.n)
            union!(usados, padres)
        end
        puntas = vcat([x for x in puntas if !(x in usados)], nuevos)
        max_puntas = max(max_puntas, length(puntas))
    end
    e = estructura(GDR, est)
    @printf("%6.2f %10d %10d %10d %9d %9d %8d %10.4f %11d\n", s, e.n_bloques, e.n_azules_blueset,
            e.n_puntas, e.rojo_k, e.rojo_U3, e.ms_max,
            e.n_azules_blueset / max(e.n_bloques, 1), max_puntas)
end
println()
println("    Con vista local aparecen PUNTAS MÚLTIPLES (max_puntas > 1) y mergesets > 1: la cadena")
println("    era un artefacto de `construir_rama_gdr`, no una propiedad del escenario. (Para rojo_k")
println("    harían falta mergesets mayores que k = 30, que este control no busca.)")
println()

println("(c) ¿Algún test o resultado publicado ejercita anticonos o `rojo_k`?")
println("    * `rojo_k` (0x01) NO existe como identificador en GDR-v0.2: es la etiqueta documental")
println("      del valor 0x01 de `tipos` (GDR src/rapido.jl:11). No hay accesor `es_rojo_k`; los")
println("      tests lo ejercitan sólo de forma indirecta (GDR test/runtests.jl:239-240,281,317-318).")
println("    * CRP-v0.1 NUNCA cuenta 0x01: su fixture mide sólo `rojo_U3`")
println("      (copia/src/rapido.jl:348,350; copia/test/runtests.jl:87; resultados/run-gdr.txt:38,41).")
println("    * `copia/test/runtests.jl:78-91` sólo comprueba invariancia de trabajo y el fixture U2/U3″.")
println()

# ---------------------------------------------------------------------------
println("##### D8 · ¿era suficiente el fixture U2/U3″? #####")
println()
println("(a) La comprobación «azul en su propia rama» (copia/src/rapido.jl:368-369):")
params = GDR.Params(k = 30, max_parents = 15, mergeset_limit = 180, s_max = 150,
                    u2 = true, u3_mode = GDR.U3_DYNAMIC,
                    sp_mode = GDR.SP_ZEROX, merge_mode = GDR.MERGE_SPEC)
est3 = GDR.EstadoRapido(params, "G")
okX = GDR.anadir!(est3, params, "X", Int[1], UInt64(1), UInt64(1), UInt64(1) << 40, UInt64(11))
okY = GDR.anadir!(est3, params, "Y", Int[1], UInt64(1), UInt64(1), UInt64(1) << 40, UInt64(11))
println("    es_ancestro_rapido(est3, 2, 2) = ", GDR.es_ancestro_rapido(est3, 2, 2),
        "   (a == b => true por el `||`, GDR src/rapido.jl:43)")
println("    es_ancestro_rapido(est3, 3, 3) = ", GDR.es_ancestro_rapido(est3, 3, 3))
println("    Luego `azulX = es_ancestro_rapido(est3,2,2) && okX` se reduce a `okX`.")
println("    El color NO es una propiedad global del bloque: hay que registrar")
println("    `(punta/contexto, bloque) -> color` e inspeccionar blueset y blue_work REALES.")
println()
println("(b) Los cuatro casos que D8 exige y su cobertura en CRP-v0.1:")
casos = [
    ("dos copias del mismo billete en una rama compatible", "SI (est, bloques A1/A2 + fusionador C)"),
    ("dos ramas disjuntas con el mismo billete y flujo compatible", "SI (est3, X e Y)"),
    ("dos ramas con prefijos PoT realmente divergentes", "NO"),
    ("intento de fusion de cada caso", "PARCIAL (solo intra-rama y ramas disjuntas)"),
    ("orden explicito: flujo, validez, U2, color U3''", "NO (no hay ninguna etapa de flujo PoT)"),
]
for (c, s) in casos
    @printf("    %-58s %s\n", c, s)
end
println()
println("(c) Efecto de la tautología en el resultado publicado `run-gdr.txt:39`:")
println("    «ambas azules en su rama=true» es exactamente `okX && okY` (que los bloques se")
println("    añadieron), NO una medición de color. La conclusión de U3″ («bloquea el doble uso")
println("    dentro de una rama y no entre ramas disjuntas») sigue siendo correcta para los casos")
println("    intra-rama y de fusión, que sí se miden; la columna «ambas azules en su rama» no")
println("    aporta evidencia.")
