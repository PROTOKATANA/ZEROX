# salida.jl — escritura de tablas reproducibles y del RESUMEN.md con procedencia (ORDEN §3.6)

_ent(x) = x === missing ? "" : string(x)
_real(x) = x === missing ? "" : @sprintf("%.6f", Float64(x))

function escribir_metricas(res::Resultado, ruta::AbstractString)
    open(ruta, "w") do io
        println(io, join(("metrica", "ambito", "n", "ausentes", "p50", "p95", "max", "unidad"), '\t'))
        for f in res.filas_enteras
            println(io, join((f.metrica, f.ambito, string(f.n), string(f.ausentes),
                              _ent(f.p50), _ent(f.p95), _ent(f.max), f.unidad), '\t'))
        end
        for f in res.filas_reales
            println(io, join((f.metrica, f.ambito, string(f.n), string(f.ausentes),
                              _real(f.p50), _real(f.p95), _real(f.max), f.unidad), '\t'))
        end
    end
    return ruta
end

function escribir_latencias(res::Resultado, ruta::AbstractString)
    open(ruta, "w") do io
        println(io, join(("nodo_a", "nodo_b", "producidos", "admitidos", "no_admitidos",
                          "negativos", "n", "p50", "p95", "max"), '\t'))
        for f in res.latencias
            println(io, join((f.nodo_a, f.nodo_b, string(f.producidos), string(f.admitidos),
                              string(f.no_admitidos), string(f.negativos), string(f.n),
                              _ent(f.p50), _ent(f.p95), _ent(f.max)), '\t'))
        end
    end
    return ruta
end

function escribir_tramos(res::Resultado, ruta::AbstractString)
    open(ruta, "w") do io
        println(io, join(("tramo_desde", "tramo_hasta", "n", "p50", "p95", "max", "unidad"), '\t'))
        for f in res.tramos
            println(io, join((string(f.desde), string(f.hasta), string(f.n),
                              _ent(f.p50), _ent(f.p95), _ent(f.max), "ns"), '\t'))
        end
    end
    return ruta
end

function escribir_rechazos(res::Resultado, ruta::AbstractString)
    open(ruta, "w") do io
        println(io, join(("etapa", "motivo", "n", "p50_t_hasta_rechazo", "p95_t_hasta_rechazo",
                          "max_t_hasta_rechazo"), '\t'))
        for f in res.rechazos
            println(io, join((f.etapa, replace(f.motivo, '\t' => ' '), string(f.n),
                              _ent(f.p50), _ent(f.p95), _ent(f.max)), '\t'))
        end
    end
    return ruta
end

function escribir_convergencia(res::Resultado, ruta::AbstractString)
    open(ruta, "w") do io
        println(io, join(("inicio_pared_ns", "duracion_hasta_coincidencia_ns", "truncada"), '\t'))
        for f in res.convergencia
            println(io, join((string(f.inicio_pared_ns), string(f.duracion_ns),
                              f.truncada ? "1" : "0"), '\t'))
        end
    end
    return ruta
end

# Lista de métricas sin ninguna muestra (no medidas), con el motivo inferido
function _no_medidas(res::Resultado)
    filas = String[]
    for f in res.filas_enteras
        f.n == 0 && push!(filas, "- `$(f.metrica)` ($(f.ambito)): sin muestras.")
    end
    for f in res.filas_reales
        f.n == 0 && push!(filas, "- `$(f.metrica)` ($(f.ambito)): sin muestras.")
    end
    return filas
end

function escribir_resumen(res::Resultado, ruta::AbstractString; fecha::String = string(Dates.now()))
    p = res.procedencia
    open(ruta, "w") do io
        println(io, "# RESUMEN de la ejecución analizada — W07c")
        println(io)
        println(io, "- **Fecha:** ", fecha)
        println(io, "- **Comando:** `", p.comando, "`")
        println(io, "- **Modelo (según la orden):** ", p.modelo)
        println(io, "- **Directorio de ejecución:** `", p.ejecucion, "`")
        println(io, "- **Julia:** ", p.julia_version,
                    " (hilos default=", p.julia_threads_default,
                    ", interactive=", p.julia_threads_interactive, ")")
        println(io, "- **CPU:** ", p.cpu)
        println(io, "- **`sha256(Manifest.toml)`:** `", p.manifest_sha256, "`")
        println(io, "- **`CLK_TCK`:** ", p.clk_tck, " (origen: ", p.clk_tck_origen, ")")
        println(io, "- **Duplicados de producción (hash producido >1 vez):** ", res.duplicados_produccion)
        println(io)
        println(io, "## Procedencia de los archivos leídos")
        println(io)
        println(io, "| archivo | nodo | version_esquema | líneas | truncadas | sha256 |")
        println(io, "|---|---|---|---:|---:|---|")
        for r in p.nodos_info
            println(io, "| `", r.ruta, "` | ", r.nombre, " | ", r.version, " | ",
                        r.lineas, " | ", r.truncadas, " | `", r.sha256, "` |")
        end
        for r in p.recursos
            println(io, "| `", r.ruta, "` | ", r.nombre, " (recursos) | — | ", length(r.muestras),
                        " muestras | 0 | `", r.sha256, "` |")
        end
        println(io)
        println(io, "## Estado final")
        println(io)
        for (nodo, resumen) in res.estado_final_detalle
            println(io, "- ", nodo, ": `", resumen == "" ? "(sin resumen_estado)" : resumen, "`")
        end
        println(io, "- **Estado final igual:** ",
                res.estado_final_igual === missing ? "no medido" :
                (res.estado_final_igual ? "sí" : "no"))
        println(io)
        println(io, "## Divergencia")
        println(io)
        if res.divergencia_medida && res.divergencia_fraccion !== missing
            println(io, "- **Fracción del intervalo en divergencia:** ",
                    @sprintf("%.6f", res.divergencia_fraccion))
            println(io, "- **Episodios:** ", length(res.convergencia),
                    " (", count(f -> f.truncada, res.convergencia), " sin reconverger antes del fin)")
        else
            println(io, "- **Divergencia no medida:** hacen falta ≥2 nodos con `cambio_punta` y un intervalo no vacío.")
        end
        println(io)
        println(io, "## Métricas sin muestras en esta ejecución")
        println(io)
        nm = _no_medidas(res)
        if isempty(nm)
            println(io, "(ninguna)")
        else
            for l in nm
                println(io, l)
            end
        end
        println(io)
        println(io, "## Notas de definición (ver `FALTAS-DE-DEFINICION.md`)")
        println(io)
        println(io, "- Percentiles nearest-rank en enteros: rango = ceil(p·n/100); sin interpolación ni `Float64`.")
        println(io, "- Latencia: producción más temprana de A y admisión más temprana de B por hash; las negativas entran y se cuentan.")
        println(io, "- Divergencia: barrido O(E log E) sobre `cambio_punta`; episodios no reconvergidos marcados `truncada=1`.")
        println(io, "- Recursos: diferencias entre muestras; `CLK_TCK` de `EJECUCION.txt` o 100 por defecto.")
    end
    return ruta
end

function escribir_salidas(res::Resultado, dir_salida::AbstractString; fecha::String = string(Dates.now()))
    mkpath(dir_salida)
    escribir_metricas(res, joinpath(dir_salida, "metricas.tsv"))
    escribir_latencias(res, joinpath(dir_salida, "latencias.tsv"))
    escribir_tramos(res, joinpath(dir_salida, "admision-vs-profundidad.tsv"))
    escribir_rechazos(res, joinpath(dir_salida, "rechazos.tsv"))
    escribir_convergencia(res, joinpath(dir_salida, "convergencia.tsv"))
    escribir_resumen(res, joinpath(dir_salida, "RESUMEN.md"); fecha = fecha)
    return dir_salida
end
