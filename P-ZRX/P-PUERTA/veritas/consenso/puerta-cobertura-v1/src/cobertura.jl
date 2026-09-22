# Punto 3 del encargo: cuanta cobertura hay en equilibrio.
#
# Ningun precio esta escrito aqui. Los costes fisicos son **entradas medidas** del repositorio,
# con su cita; los precios entran como dos numeros **adimensionales** que el llamante barre.

"""
    CostesMedidos

Las magnitudes fisicas del problema, todas medidas antes de este instrumento y citadas con su
archivo y linea. **Son entradas, no resultados**: cambiarlas cambia todas las curvas de §3, y
`test/runtests.jl` lo comprueba barriendolas.

- `lecturas_ref` / `cap_ref_TiB`: `4 161` lecturas aleatorias por slot **por flujo** con `4 TiB`
  a `σ = 1 s` (`research/dag-nativo-poas-propuesta.md:1360`, tambien `:162-163`).
- `us_por_sector`: `42,92 µs` de CPU por sector y desafio, granjero honesto, un hilo
  (`research/coste-ploteo-medido.md:82-91`).
- `dur_slot_s`: duracion del slot. **No se fija**: es parametro.
- `verif_pot_s`: verificar el PoT de **un** flujo, segundos de nucleo por slot. Medido
  `96,1 ms/slot` (`research/dag-poas-ancla-de-orden.md:342`); por ISA, `92 ms` con AVX-512/VAES,
  `101 ms` con AVX2/VAES, `190 ms` con AES-NI/SSE4.1 (`SPEC.md:2988`).
- `prod_pot_s`: **producir** el PoT de un flujo, segundos de nucleo por slot: `prove = 1,561 s/slot`
  medido en un 9950X3D (`research/dag-poas-ancla-de-orden.md:342`).
"""
struct CostesMedidos
    lecturas_ref::Float64
    cap_ref_TiB::Float64
    us_por_sector::Float64
    dur_slot_s::Float64
    verif_pot_s::Float64
    prod_pot_s::Float64
end

"""
    costes_repositorio(; dur_slot_s=1.0, verif_pot_s=0.0961) -> CostesMedidos

Las cifras medidas tal como estan en el repositorio, con el slot y la ISA como los dos unicos
grados de libertad. No es «la» configuracion de ZEROX: es el punto de partida del barrido.
"""
costes_repositorio(; dur_slot_s::Float64=1.0, verif_pot_s::Float64=0.0961) =
    CostesMedidos(4161.0, 4.0, 42.92, dur_slot_s, verif_pot_s, 1.561)

"""
    lecturas_por_TiB(m) -> Float64

Lecturas aleatorias por slot, por TiB y **por flujo**. Se deriva de la medicion de referencia,
no se escribe: `lecturas_ref / cap_ref_TiB`.
"""
lecturas_por_TiB(m::CostesMedidos) = m.lecturas_ref / m.cap_ref_TiB

"""
    nucleos_auditoria_por_TiB(m) -> Float64

Nucleos continuos que cuesta auditar un TiB contra **un** flujo:
`lecturas_por_TiB · us_por_sector / dur_slot`. Una lectura es un sector, y cada sector cuesta un
pase de auditoria.
"""
nucleos_auditoria_por_TiB(m::CostesMedidos) =
    lecturas_por_TiB(m) * m.us_por_sector * 1e-6 / m.dur_slot_s

"""
    nucleos_verif_pot(m) -> Float64

Nucleos continuos que cuesta **verificar** el PoT de un flujo. No depende del tamano de la granja:
es el termino **fijo por flujo abierto**, y es el que decide si la cobertura total es racional.
"""
nucleos_verif_pot(m::CostesMedidos) = m.verif_pot_s / m.dur_slot_s

"""
    nucleos_prod_pot(m) -> Float64

Nucleos continuos que cuesta **producir** el PoT de un flujo. Alguien tiene que pagarlo o el flujo
no existe: sin cadena de PoT no hay reto y no hay bloques.
"""
nucleos_prod_pot(m::CostesMedidos) = m.prod_pot_s / m.dur_slot_s

"""
    s_max_iops(m, iops_por_TiB) -> Float64

**Cuantos flujos puede auditar un granjero, por IOPS**, como funcion de los **IOPS por TiB del
medio** y no de la capacidad total:

    S = iops_por_TiB · dur_slot / lecturas_por_TiB

La capacidad se cancela porque las lecturas crecen con ella y los discos tambien. Fijar un solo
SSD para cualquier capacidad es el error que `P-2.1/ADENDA-2.md` §5 senala y que produce el
absurdo «0 flujos con 100 TiB».
"""
s_max_iops(m::CostesMedidos, iops_por_TiB::Real) =
    float(iops_por_TiB) * m.dur_slot_s / lecturas_por_TiB(m)

"""
    s_max_nucleos(m, nucleos, cap_TiB) -> Float64

**Cuantos flujos puede sostener un granjero, por CPU**: cada flujo cuesta auditoria (lineal en la
capacidad) mas verificacion de PoT (fija):

    S = nucleos / (nucleos_auditoria_por_TiB·cap_TiB + nucleos_verif_pot)

A diferencia del limite por IOPS, este **si** decrece con la capacidad.
"""
s_max_nucleos(m::CostesMedidos, nucleos::Real, cap_TiB::Real) =
    float(nucleos) / (nucleos_auditoria_por_TiB(m) * float(cap_TiB) + nucleos_verif_pot(m))

"""
    s_max(m, iops_por_TiB, nucleos, cap_TiB) -> Float64

El minimo de los dos limites fisicos. Es un **techo**, no un equilibrio: cuantos flujos se pueden
cubrir, no cuantos conviene cubrir.
"""
s_max(m::CostesMedidos, iops_por_TiB::Real, nucleos::Real, cap_TiB::Real) =
    min(s_max_iops(m, iops_por_TiB), s_max_nucleos(m, nucleos, cap_TiB))

"""
    rho_variable(m, precio_iops, precio_nucleo, recompensa_por_TiB) -> Float64

El coste marginal **variable** de cubrir un flujo mas, por TiB, dividido por la recompensa por TiB
de ese flujo. Adimensional.

    ρ_var = (precio_iops·lecturas_por_TiB + precio_nucleo·nucleos_auditoria_por_TiB) / recompensa_por_TiB

`recompensa_por_TiB` es `Rec/W_j`: lo que el flujo `j` paga por slot dividido por el espacio que lo
cubre. Los tres precios estan en la misma moneda por slot; ninguno se inventa aqui.
"""
rho_variable(m::CostesMedidos, precio_iops::Real, precio_nucleo::Real,
             recompensa_por_TiB::Real) =
    (float(precio_iops) * lecturas_por_TiB(m) +
     float(precio_nucleo) * nucleos_auditoria_por_TiB(m)) / float(recompensa_por_TiB)

"""
    rho_fijo(m, precio_nucleo, recompensa_por_TiB) -> Float64

El coste marginal **fijo** por flujo abierto, expresado en TiB: el tamano de granja cuya
recompensa en ese flujo iguala el coste de verificar su PoT.

    ρ_fij = precio_nucleo·nucleos_verif_pot / recompensa_por_TiB       [TiB]
"""
rho_fijo(m::CostesMedidos, precio_nucleo::Real, recompensa_por_TiB::Real) =
    float(precio_nucleo) * nucleos_verif_pot(m) / float(recompensa_por_TiB)

"""
    rho_produccion(m, precio_nucleo, recompensa_por_TiB) -> Float64

Lo mismo para **producir** el PoT del flujo, en TiB. Es `prove/verify ≈ 16×` mayor que `ρ_fij`.
"""
rho_produccion(m::CostesMedidos, precio_nucleo::Real, recompensa_por_TiB::Real) =
    float(precio_nucleo) * nucleos_prod_pot(m) / float(recompensa_por_TiB)

"""
    umbral_probabilidad(x_TiB, ρ_var, ρ_fij) -> Float64

**La condicion de cobertura del encargo**, resuelta en `p`: cubrir un flujo mas es racional para
una granja de `x` TiB si y solo si la probabilidad `p` de que ese flujo acabe siendo el canonico
supera

    p* (x) = ρ_var + ρ_fij / x

El termino `ρ_fij/x` es lo que rompe el argumento historico de que «cubrir es gratis»: no lo es
para una granja pequena, por barato que sea el pase de auditoria.
"""
umbral_probabilidad(x_TiB::Real, ρ_var::Real, ρ_fij::Real) =
    float(ρ_var) + float(ρ_fij) / float(x_TiB)

"""
    tamano_minimo(p, ρ_var, ρ_fij) -> Float64

La granja mas pequena para la que cubrir ese flujo es racional: `ρ_fij/(p − ρ_var)`, o `Inf` si
`p ≤ ρ_var` (entonces no lo es para **ninguna** granja, por grande que sea).
"""
tamano_minimo(p::Real, ρ_var::Real, ρ_fij::Real) =
    float(p) > float(ρ_var) ? float(ρ_fij) / (float(p) - float(ρ_var)) : Inf

"""
    tamano_minimo_productor(p, ρ_var, ρ_fij, ρ_prod) -> Float64

Lo mismo para quien ademas tiene que **producir** el PoT de ese flujo. Si ninguna granja llega a
este tamano, el flujo no tiene quien le calcule la cadena de PoT y **muere por si solo**: es la
palanca mas barata de `PROPUESTA.md`.
"""
tamano_minimo_productor(p::Real, ρ_var::Real, ρ_fij::Real, ρ_prod::Real) =
    float(p) > float(ρ_var) ? (float(ρ_fij) + float(ρ_prod)) / (float(p) - float(ρ_var)) : Inf

"""
    cobertura_equilibrio(tamanos, masa, x_min) -> Float64

`c` en equilibrio: la **fraccion del espacio total** en manos de granjas cuyo tamano supera
`x_min`. Solo esas cubren el segundo flujo, asi que solo esas entran en `c`.

`tamanos` en TiB y `masa` el numero (o peso) de granjas de cada tamano. El resultado es el `c`
que alimenta `flujos_regimen`: **la cobertura no es una eleccion del modelo, es una salida de la
distribucion de tamanos y de los costes.**
"""
function cobertura_equilibrio(tamanos::AbstractVector{<:Real}, masa::AbstractVector{<:Real},
                              x_min::Real)
    length(tamanos) == length(masa) || throw(ArgumentError("tamanos y masa deben medir igual"))
    total = 0.0; cubre = 0.0
    @inbounds for i in eachindex(tamanos)
        e = float(tamanos[i]) * float(masa[i])
        total += e
        float(tamanos[i]) > float(x_min) && (cubre += e)
    end
    return total <= 0 ? 0.0 : cubre / total
end

"""
    pareto_tamanos(x_min_TiB, α, n) -> (tamanos, masa)

Rejilla logaritmica de tamanos de granja con masa de Pareto de exponente `α`
(`P(X > x) ∝ x^{−α}`), para barrer `cobertura_equilibrio`. **Es un supuesto declarado**
(H-TAMANOS en `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`): el reparto real de tamanos de granja
en una red ZEROX no esta medido en ninguna parte de este repositorio.
"""
function pareto_tamanos(x_min_TiB::Real, α::Real, n::Integer; x_max_TiB::Real=100_000.0)
    xs = exp.(range(log(float(x_min_TiB)), log(float(x_max_TiB)); length=n))
    dens = [x^(-(float(α) + 1)) for x in xs]
    return (xs, dens .* [i == 1 ? xs[2] - xs[1] : xs[i] - xs[i-1] for i in 1:n])
end
