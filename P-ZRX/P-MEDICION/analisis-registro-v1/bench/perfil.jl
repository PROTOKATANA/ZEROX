# perfil.jl — perfil del análisis del sintético de 10⁶ eventos (LINEO §5.1, §6)
using Profile
include(joinpath(@__DIR__, "..", "src", "analisis_registro_v1.jl"))
using .AnalisisRegistroV1
const AR = AnalisisRegistroV1

dest = joinpath(dirname(@__DIR__), "resultados", "sintetico-1e6")
nodos = ["A", "B", "C"]
res = AR.analizar(dest, nodos)            # calienta JIT
println("eventos: ", sum(r.lineas for r in res.procedencia.nodos_info))
Profile.clear()
Profile.@profile AR.analizar(dest, nodos)
io = IOBuffer()
Profile.print(io; format = :flat, sortedby = :count, mincount = 50, C = false)
print(String(take!(io)))
println("Total snapshots: ", length(Profile.fetch()), " (perfil con 1 hilo para no mezclar hilos ociosos)")
