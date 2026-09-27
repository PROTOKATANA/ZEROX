#= captura.jl — Sección D: cuántas IP en cuántos prefijos para capturar las ω salientes.

QUÉ MODELO ES ESTE, Y SOBRE QUÉ SISTEMA
=======================================
El encargo (§4.2) pide: «Cuántas IP, en cuántos prefijos /16 (o el agrupamiento que use el gestor
de direcciones real), necesita el atacante para capturar las 8 salientes de una víctima con
probabilidad 50 % y 90 %», con el control de Heilman et al. y aplicado al esquema de Kaspa, y
«declara explícitamente qué parte de la cuenta de Heilman sobrevive al cambio de pila y cuál no.
Si el gestor de direcciones de ZEROX no existe todavía, dilo: entonces la cuenta es sobre un
diseño **propuesto**, no sobre el vigente, y eso cambia la etiqueta de todo el punto.»

**EL GESTOR DE DIRECCIONES DE ZEROX NO EXISTE.** Verificado en el código:
  · `crates/zx-p2p/src/limites.rs:174` `MAX_PEERS_SALIENTES: u32 = 24` (no 8).
  · `limites.rs:182` `MAX_PEERS_ENTRANTES: u32 = 72`; `:185` `MAX_CONEXIONES = 96`; `:190`
    por peer = 1; `:195` pendientes = 32.
  · `limites_ip.rs:75-104`: `Prefijo::V4(/24)` y `V6(/64)`, usados **sólo** para límites y baneo
    (`MAX_POR_PREFIJO = 3`, `limites_ip.rs:46`).
  · `limites_ip.rs:288-298`: `handle_established_outbound_connection` **no registra nada**; las
    salientes no se contabilizan por prefijo.
  · No hay `addrman`, ni tablas `tried`/`new`, ni `PrefixBucket`, ni ASN, ni `feeler`, ni
    `test-before-evict`, ni `anchor`, ni `block-relay-only`, ni bootstrap de Kademlia, ni
    suscripción a gossipsub, ni bucle que mantenga N salientes (grep exhaustivo: 0 coincidencias).
  Por tanto **todo resultado de este módulo sobre ZEROX es sobre un DISEÑO PROPUESTO**, no sobre
  el vigente. La etiqueta de cada fila lo dice.

ARITMÉTICA
==========
La captura de salientes es una cola: la probabilidad se calcula con el producto
hipergeométrico **exacto** en `Rational{BigInt}`, no en `Float64` (encargo §6).
=#

module Captura

using Printf

"""
`P(las ω salientes son del atacante)` con `N = G·t` direcciones repartidas en `G` grupos de `t`
direcciones, de las que el atacante controla `s` grupos (`A = s·t` direcciones), y selección
**uniforme sin reemplazo**. Producto hipergeométrico exacto.
"""
function p_captura(s::Integer, t::Integer, G::Integer, omega::Integer)
    (s < 0 || s > G) && return Rational{BigInt}(0)
    A = BigInt(s) * t
    N = BigInt(G) * t
    omega > N && return Rational{BigInt}(0)
    p = Rational{BigInt}(1)
    for i in 0:(omega - 1)
        (A - i) <= 0 && return Rational{BigInt}(0)
        p *= Rational{BigInt}(A - i, N - i)
    end
    return p
end

"""Menor número de grupos `s` que alcanza la probabilidad objetivo. Exacto: compara racionales."""
function s_minimo(t::Integer, G::Integer, omega::Integer, objetivo::Rational{BigInt})
    s = 1
    while s <= G
        p_captura(s, t, G, omega) >= objetivo && return s
        s += 1
    end
    return G
end

"""
Fracción de grupos necesaria para alcanzar `p` con selección uniforme: `p^(1/ω)`.
Es el resultado del modelo de «selección aleatoria» (la contramedida 2 de Heilman).
"""
function fraccion_grupos(p::Real, omega::Integer)
    return p^(1.0 / omega)
end

function informe()
    println("SECCIÓN D · captura de las ω salientes por prefijo")
    println("Producto hipergeométrico EXACTO en Rational{BigInt}; fracciones en coma flotante")
    println("sólo para presentación.")
    println()

    println("D.1 · Modelo de SELECCIÓN UNIFORME: fracción del espacio de grupos necesaria")
    println("      (el resultado que Heilman et al. atribuyen a la contramedida «selección")
    println("       aleatoria»: 50 % → f = 0,5^(1/8) = 0,9170 ; 90 % → f = 0,9^(1/8) = 0,9869)")
    @printf("%6s | %-22s | %-22s\n", "ω", "grupos para 50 %", "grupos para 90 %")
    for omega in (8, 10, 24)
        @printf("%6d | %-22.6f | %-22.6f\n", omega, fraccion_grupos(0.5, omega),
                fraccion_grupos(0.9, omega))
    end
    println("      Con el espacio /16 completo (65536 grupos), esas fracciones son:")
    for omega in (8, 10, 24)
        @printf("      ω=%2d : 50 %% -> %7.0f /16 ;  90 %% -> %7.0f /16\n", omega,
                fraccion_grupos(0.5, omega) * 65536, fraccion_grupos(0.9, omega) * 65536)
    end
    println()
    println("      LECTURA: la exigencia de prefijos CRECE con ω. Pasar de 8 a 24 salientes")
    println("      (lo que ZEROX tiene en `limites.rs:174`) sube el listón de 91,7 % a 97,2 % de")
    println("      los grupos. Es el único efecto protector de ω, y es un efecto del MODELO")
    println("      uniforme: no hay selección implementada que lo realice.")
    println()

    println("D.2 · Control de Heilman et al. 2015 (verificado abriendo el texto del artículo,")
    println("      research/fuentes/heilman2015-eclipse.txt)")
    println("  · 8 salientes y 117 entrantes (bitcoind 0.9.3): txt:233-236")
    println("  · tried = 64 buckets × 64 = 4096 direcciones (txt:301-302);")
    println("    new = 256 × 64 = 16384 (txt:331-332); cada grupo /16 → hasta 4 buckets de tried")
    println("  · grupo = prefijo /16 IPv4; IPv6 normal /32; Hurricane Electric /36; Tor 4 bits")
    println("    (txt:307-310, 344-348)")
    println("  · ADDR: hasta 1000 direcciones por mensaje; >1000 → peer en lista negra (txt:266-274)")
    println("  · 90 % con f = 72 % de tried, τl = 48 h, τa = 27 min (txt:557-559)")
    println("  · con selección aleatoria, 90 % exige f = 98,7 % (txt:560-561)")
    println("  · peor caso con CM1+2+6 (Core 0.10.1), tried lleno de direcciones frescas:")
    println("    163K direcciones para 50 %, 284K para 90 % (txt:1309-1311)")
    println("  · Table 2, medición de testbed: 32 grupos /24 = 8192 direcciones → 98 %;")
    println("    4600 direcciones (2300 grupos × 2) → 100 % (txt:977, 982, 1033)")
    println("  ATENCIÓN: el artículo NO tiene una tabla 50/90 con IPs y /16. El 50 % del ataque")
    println("  original sólo está en la Figura 2; los «50 %» escritos son BAJO contramedidas.")
    println()

    println("D.3 · Contramedidas: coste medido o modelado, con fuente abierta en esta sesión")
    println("      (PR #9037, cuerpo, https://api.github.com/repos/bitcoin/bitcoin/pulls/9037)")
    @printf("%-34s %12s %10s\n", "configuración del nodo", "IPs ~50 %", "factor")
    base = 595.0
    for (nom, ip) in (("default", 595.0), ("default + test-before-evict", 620.0),
                      ("feeler", 5540.0), ("feeler + test-before-evict", 8600.0))
        @printf("%-34s %12.0f %10.2fx\n", nom, ip, ip / base)
    end
    println("      Etiqueta: MODELO/simulación del propio Heilman (2016), escenario realista.")
    println("      NO es medición de testbed. En el artículo, la frecuencia/probabilidad de las")
    println("      feeler NO aparece (NO ENCONTRADO); el «cada 2 minutos» es de Bitcoin Core")
    println("      (src/net.h:61) y del PR #8282.")
    println("      PR #8282 (cuerpo): direcciones obsoletas en tried «the lowest was 72 percent")
    println("      stale, the highest was 95 percent stale» → tried casi vacío de direcciones")
    println("      vivas, que es por qué el peor caso de 163K/284K no es el operativo.")
    println("      `block-relay-only` NO está en el artículo: es de Core 0.19.0 (PR #15759, 2019).")
    println("      `anchor` (CM5) propone 2 conexiones persistentes; el artículo NO da cuánto sube")
    println("      el coste (NO ENCONTRADO) y Core nunca implementó esa tabla (los «anchors» de")
    println("      Core 0.21.0 son los 2 block-relay-only, PR #17428).")
    println()
    println("      Efecto de sumar salientes, en el modelo uniforme (exacto):")
    for omega in (8, 10, 12, 24)
        @printf("        ω=%2d -> 50 %%: %.4f de los grupos ; 90 %%: %.4f\n", omega,
                fraccion_grupos(0.5, omega), fraccion_grupos(0.9, omega))
    end
    println()

    println("D.4 · Aplicación al esquema de KASPA (verificado en /home/katana/zeo/fuentes/rusty-kaspa)")
    println("  · PrefixBucket: /16 en IPv4 (y en IPv6 mapeada a IPv4); /64 en IPv6 nativa")
    println("    (utils/src/networking.rs:38-68)")
    println("  · outbound_target = 8 (kaspad/src/args.rs:115); inbound_limit = 128 (ib.), y la")
    println("    ayuda larga dice 117 (:624): INCONSISTENCIA del propio repositorio")
    println("  · MAX_ADDRESSES = 4096 (components/addressmanager/src/lib.rs:27)")
    println("  · peso: comentario `64^(x−y)/n`, código `64^(MAX+1−y)/n = 64^(4−y)/n`")
    println("    (lib.rs:421-457): DISCREPANCIA doc/código de un exponente")
    println("  · NO hay tried/new, ni frescura, ni evicción, ni feeler, ni test-before-evict,")
    println("    ni anchor (grep: 0 coincidencias)")
    println("  · La «normalización por prefijo» divide el peso por el número de IP del MISMO")
    println("    PrefixBucket. Consecuencia, y es la lectura que importa: **acumular muchas IP en")
    println("    un mismo /16 se penaliza**, así que el recurso escaso deja de ser «IPs» y pasa a")
    println("    ser «prefijos distintos». El atacante óptimo reparte 1-2 IP por /16 y necesita")
    println("    ~f · (nº de buckets distintos) prefijos, con f = 0,5^(1/8) = 0,9170 para el 50 %.")
    println("    Con `MAX_ADDRESSES = 4096` eso son del orden de 0,9170·4096 ≈ 3757 direcciones en")
    println("    otros tantos /16 — cifra del MODELO, no medida: no existe medición publicada de")
    println("    la resistencia a eclipse de kaspad (NO ENCONTRADO).")
    println()

    println("D.5 · ZEROX: la pila real y el diseño PROPUESTO")
    println("  (a) LO QUE HAY HOY — código verificado, etiqueta `verificado en fuente`:")
    println("      · 24 salientes / 72 entrantes / 96 totales, por peer 1, pendientes 32")
    println("      · agrupamiento /24 (IPv4) y /64 (IPv6) SÓLO para límites y baneo; máximo 3")
    println("        conexiones por prefijo, y las SALIENTES NO SE CONTABILIZAN POR PREFIJO")
    println("      · no hay selección de salientes de ningún tipo: `zx-node` sólo marca la lista")
    println("        de `--peer` al arrancar; no hay bucle que mantenga un objetivo de conexiones")
    println("      → En este estado, el modelo de Heilman NO APLICA: no hay tabla que llenar ni")
    println("        sorteo que sesgar. El «coste de capturar las 8 salientes» no está definido")
    println("        porque no hay 8 ni hay captura: hay una lista manual.")
    println("  (b) LO QUE HABRÍA QUE CONSTRUIR para que la cuenta tenga sentido, y su coste:")
    println("      con ω = 24 y selección uniforme, 50 % exige el 97,16 % de los grupos y 90 % el")
    println("      99,56 %. Sobre el espacio /24 de IPv4 (2^24 = 16 777 216 prefijos) eso es")
    @printf("        50 %% -> %.0f prefijos /24 ; 90 %% -> %.0f prefijos /24\n",
            fraccion_grupos(0.5, 24) * 2^24, fraccion_grupos(0.9, 24) * 2^24)
    println("      Sobre /16 sería 97,16 % y 99,56 % de 65536 → 63 691 y 65 246 prefijos.")
    println("      Esas cifras son del MODELO UNIFORME y valen como COTA SUPERIOR del coste:")
    println("      el atacante no necesita poseer el prefijo, le basta con que la víctima lo elija.")
    println("      La cota INFERIOR real depende de la tabla que se construya y no existe.")
    println()
    println("  (c) El efecto que SÍ es sólido y no depende del diseño: mientras no haya selección")
    println("      diversificada, un atacante que consiga ser marcado ocupa cupo sin sorteo. El")
    println("      límite de 3 por prefijo NO lo frena por la vía saliente (`limites_ip.rs:288-298`),")
    println("      que es un hallazgo de código, no un modelo.")
end

end # module
