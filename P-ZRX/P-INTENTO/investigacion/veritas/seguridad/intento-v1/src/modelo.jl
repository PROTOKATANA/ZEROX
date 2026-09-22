"""
Tipos y parámetros del modelo de coste del intento dirigido.

**Qué es y qué no es.** Este instrumento convierte medidas de hardware en una métrica *sin
precios*: cuánto espacio honesto emula una máquina, y cuántas máquinas hacen falta para una
fracción `alpha` de una red de `N_h` piezas. No decide si el ataque «es rentable»: no hay precios
y no se inventan.

**Hipótesis estructurales, todas verificadas en fuente y no supuestas:**

- La tabla depende solo de la semilla; el reto solo elige el *s-bucket*
  (`crates/subspace-proof-of-space/src/chia_v2.rs:28-36,64-68`).
- `s_bucket` = dos primeros bytes LE de `SectorId XOR global_challenge`
  (`crates/subspace-core-primitives/src/sectors.rs:32-39,117-123`).
- El verificador decide con `bidirectional_distance(global_challenge, audit_chunk) <= R_s/2`
  (`crates/subspace-verification/src/lib.rs:118-159`), donde `audit_chunk` ya es el chunk CRUDO.
  Por eso un acierto no necesita el testigo: solo el mapa de presencia y el chunk crudo.
- La unidad de aceptación es una pieza, no un sector
  (`crates/subspace-verification/src/lib.rs:228-270`).

**Unidades.** `tau_s` son segundos por slot y NO se mezcla con número de slots. `r` son tablas por
segundo. `N_eq` sale en piezas; para pasarlo a bytes hay que multiplicar por `Piece::SIZE`, que se
pasa explícitamente.
"""

"""
Medidas crudas del banco Rust, en unidades del SI. Ninguna cifra se teclea: se leen del fichero
`mediciones/modelo-entrada.tsv` que genera `banco-rust`.
"""
struct Medidas{T<:Real}
    # M1
    t_tabla_1_hilo_s::T
    t_tabla_1_hilo_semilla_fresca_s::T
    t_tabla_paralela_s::T
    t_tabla_paralela_hilos::Int
    r_agregado_por_hilos::Vector{T}
    hilos_barridos::Vector{Int}
    r_agregado_paralelo::Vector{T}
    r_agregado_anidado::Vector{T}
    # M2
    t_reto_por_bucket_s::T
    t_reto_lote_total_s::T
    t_derivar_bucket_s::T
    t_distancia_s::T
    # M3
    t_ganador_tabla_s::T
    t_ganador_resto_s::T
    # Estructura
    o::T
    bucket_max::Int
    ram_por_tabla_bytes::Int
    sizeof_proofs_bytes::Int
    # Origen
    fuente::String
end

"""
Escenario medido: la máquina, el protocolo y la red. `w` NO se fija aquí: es símbolo del barrido.
"""
struct Escenario{T<:Real}
    r::T
    t_reto_s::T
    o::T
    rango_solucion::T
    tau_s::T
    N_h::T
    alpha::T
    pi_DAG::T
    t_ganador_s::T
    bytes_por_pieza::Int
end

"""Fila del barrido. Todo lo que no se mide va marcado como derivado en el informe."""
struct Resultado{T<:Real}
    w::T
    p::T
    r_efectiva::T
    n_eq::T
    bytes_eq::T
    maquinas::T
    fraccion_una_maquina::T
    coste_por_solucion_s::T
    latencia_holgada::Bool
    w_min_latencia::T
    w_equilibrio::T
end

"""Valida el escenario y devuelve sus campos con tipo concreto."""
function Escenario(;
    r::T,
    t_reto_s::T,
    o::T,
    rango_solucion::T,
    tau_s::T,
    N_h::T,
    alpha::T,
    pi_DAG::T,
    t_ganador_s::T,
    bytes_por_pieza::Integer,
) where {T<:Real}
    r > zero(T) || throw(ArgumentError("r debe ser positivo"))
    t_reto_s >= zero(T) || throw(ArgumentError("t_reto_s no puede ser negativo"))
    zero(T) < o <= one(T) || throw(ArgumentError("o debe estar en (0,1]"))
    zero(T) <= rango_solucion <= typemax(UInt64) ||
        throw(ArgumentError("rango_solucion fuera de rango u64"))
    tau_s > zero(T) || throw(ArgumentError("tau_s debe ser positivo"))
    N_h >= zero(T) || throw(ArgumentError("N_h no puede ser negativo"))
    zero(T) < alpha < one(T) || throw(ArgumentError("alpha debe estar en (0,1)"))
    zero(T) < pi_DAG <= one(T) || throw(ArgumentError("pi_DAG debe estar en (0,1]"))
    t_ganador_s >= zero(T) || throw(ArgumentError("t_ganador_s no puede ser negativo"))
    bytes_por_pieza > 0 || throw(ArgumentError("bytes_por_pieza debe ser positivo"))
    return Escenario{T}(
        r,
        t_reto_s,
        o,
        rango_solucion,
        tau_s,
        N_h,
        alpha,
        pi_DAG,
        t_ganador_s,
        Int(bytes_por_pieza),
    )
end

"""
Copia un escenario cambiando algunos campos.

Un `struct` no se puede splatear como un `NamedTuple`, asi que la copia con sobrescritura se hace
aqui, con conversion explicita al tipo de `T` y pasando por el constructor que valida.
"""
function con(
    e::Escenario{T};
    r = e.r,
    t_reto_s = e.t_reto_s,
    o = e.o,
    rango_solucion = e.rango_solucion,
    tau_s = e.tau_s,
    N_h = e.N_h,
    alpha = e.alpha,
    pi_DAG = e.pi_DAG,
    t_ganador_s = e.t_ganador_s,
    bytes_por_pieza = e.bytes_por_pieza,
) where {T}
    return Escenario(;
        r = T(r),
        t_reto_s = T(t_reto_s),
        o = T(o),
        rango_solucion = T(rango_solucion),
        tau_s = T(tau_s),
        N_h = T(N_h),
        alpha = T(alpha),
        pi_DAG = T(pi_DAG),
        t_ganador_s = T(t_ganador_s),
        bytes_por_pieza = Int(bytes_por_pieza),
    )
end

"""
Lee `mediciones/modelo-entrada.tsv`, generado por el banco Rust.

Formato: `clave<TAB>valor<TAB>unidad<TAB>fuente<TAB>estado`. Falla con `KeyError` si falta una
clave obligatoria: el modelo nunca sustituye una medida ausente por un número supuesto.
"""
function lectura_mediciones(ruta::AbstractString)
    crudo = Dict{String,String}()
    fuentes = Set{String}()
    for linea in eachline(ruta)
        isempty(strip(linea)) && continue
        startswith(linea, "clave\t") && continue
        campos = split(linea, '\t')
        length(campos) < 3 && continue
        crudo[String(campos[1])] = String(campos[2])
        push!(fuentes, String(campos[4]))
    end

    funcion = let crudo = crudo
        (clave) -> begin
            haskey(crudo, clave) || error(
                "falta la clave medida `$clave` en el fichero de entrada; " *
                "el modelo no la inventa. Ejecuta el banco Rust antes.",
            )
            parse(Float64, crudo[clave])
        end
    end

    entero = let crudo = crudo
        (clave) -> parse(Int, crudo[clave])
    end

    r_single = [funcion("escalado/single/$(h)hilos") for h in (1, 2, 4, 8, 16, 24)]
    r_paralelo = [funcion("escalado/parallel/$(h)hilos") for h in (1, 2, 4, 8, 16, 24)]
    r_anidado = [funcion("escalado/anidado/$(h)hilos") for h in (1, 2, 4, 8, 16, 24)]

    return Medidas{Float64}(
        funcion("criterion/m1/tabla_1_hilo_semilla_fija"),
        funcion("criterion/m1/tabla_1_hilo_semilla_fresca"),
        funcion("criterion/m1/tabla_paralela_interna"),
        entero("banco/rayon_hilos"),
        r_single,
        [1, 2, 4, 8, 16, 24],
        r_paralelo,
        r_anidado,
        # El banco mide el TOTAL de cruzar la tabla con w = 10^4 retos: se divide entre w.
        # Camino que ofrece la API del clon: un `rank/select` por reto.
        funcion("criterion/m2_w10000/por_bucket") / 10_000.0,
        # Cruce EN LOTE completo para w = 10^4: derivar los buckets por identidad + construir el
        # mapa objetivo + un solo AND de 8 KiB. Es TOTAL, no por reto: el AND no depende de `w`.
        funcion("criterion/m2_w10000/lote_and_64k") +
        funcion("criterion/m2_w10000/derivar_buckets") +
        funcion("criterion/m2_w10000/construir_objetivo"),
        # Derivacion del s-bucket POR IDENTIDAD, por reto (los retos globales no se cobran: los
        # produce el PoT una vez y son compartidos).
        funcion("criterion/m2_w10000/derivar_buckets") / 10_000.0,
        funcion("criterion/m2_aislado/distancia_un_acierto"),
        funcion("criterion/m3/tabla_para_la_semilla_ganadora"),
        # Camino ganador SIN regenerar la tabla (esa ya se cuenta en el intento):
        # leer pieza + erasure extend + Kzg::poly (atajo del atacante) + testigo del chunk.
        funcion("criterion/m3_io/leer_pieza_local_1MiB") +
        funcion("criterion/m3/erasure_extend_pieza_1MiB") +
        funcion("criterion/m3/kzg_poly_pieza_1MiB") +
        funcion("criterion/m3/kzg_chunk_witness"),
        funcion("distribucion/o"),
        entero("distribucion/bucket_max"),
        entero("ram/byte_por_tabla"),
        entero("ram/sizeof_Proofs20"),
        join(sort!(collect(fuentes)), ", "),
    )
end

"""
Escenario por defecto a partir de las medidas: `r` de un núcleo, `t_reto` del camino por bucket
medido a `w = 10^4`. El resto de entradas del protocolo las fija el llamante.
"""
function escenario_desde_medidas(m::Medidas{T}; nucleo::Symbol = :un_hilo) where {T}
    r = if nucleo === :un_hilo
        one(T) / m.t_tabla_1_hilo_semilla_fresca_s
    elseif nucleo === :paralelo
        one(T) / m.t_tabla_paralela_s
    else
        throw(ArgumentError("nucleo debe ser :un_hilo o :paralelo"))
    end
    return Escenario(;
        r = r,
        t_reto_s = m.t_reto_por_bucket_s,
        o = m.o,
        rango_solucion = T(0),
        tau_s = T(1),
        N_h = T(0),
        alpha = T(0.1),
        pi_DAG = T(1),
        t_ganador_s = m.t_ganador_tabla_s + m.t_ganador_resto_s,
        bytes_por_pieza = 1_048_672,
    )
end
