# bench/perfil.jl — perfil de CPU y asignaciones del caso real (n=10000).
#
# Ejecutar con: julia --project=. bench/perfil.jl  (salida a stdout; redirigir a
# resultados/PERFIL.txt). Calienta el kernel antes de perfilar para separar el JIT.

using Profile
using StableRNGs
using DeltaMedido

function perfil_representativo()
    p = ParametrosRed(10000, :regular, 8, 0.08, 0.5, 1.0e7, 683.0, 0.0, 1.0, 30.0)
    rng = StableRNG(UInt64(0x5A5A))
    red = construir_red(rng, p)
    t_creacion = calendario_poisson(rng, 1.0, 30.0)
    creador = rand(rng, 1:10000, length(t_creacion))
    m = MotorRapido(10000; capacidad = 64 + (10000 * 8 + 1) * 16)

    # calentamiento (compilación fuera del perfil)
    correr!(m, red, t_creacion, creador)

    Profile.clear()
    @profile correr!(m, red, t_creacion, creador)
    println("profile=representative_n10000_d8")
    Profile.print(format = :flat, sortedby = :count, mincount = 20)
    bytes = @allocated correr!(m, red, t_creacion, creador)
    println("allocated_bytes=$(bytes)")
    println("n=$(red.g.n) edges=$(length(red.g.vecinos)÷2) bloques=$(length(t_creacion))")
end

perfil_representativo()
