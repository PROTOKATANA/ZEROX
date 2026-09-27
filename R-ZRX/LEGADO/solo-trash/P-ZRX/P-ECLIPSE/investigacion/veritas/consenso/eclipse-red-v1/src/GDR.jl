#= GDR.jl — carga del instrumento reutilizado `GDR-v0.2`.

DECISIÓN DE REUTILIZACIÓN (encargo §3 y §6)
===========================================
El encargo manda: «GHOSTDAG, coloreo, orden y `rank`: `GDR-v0.2`. **Se reutiliza, no se
reimplementa.**»

Este fichero lo carga **por `include` de su módulo**, no copiando código:
`veritas/consenso/ghostdag-rank-v1/src/GhostdagRank.jl`. Es legítimo y sin efectos sobre el
instrumento ajeno porque, verificado leyendo su fuente, **`src/` de GDR-v0.2 no importa ningún
paquete externo**: es autocontenido (sus `Project.toml` deps —`BenchmarkTools`, `JSON3`,
`StableRNGs`— las usan sólo `run.jl` y `test/runtests.jl`). Por eso `include` no arrastra el
entorno del otro proyecto, y **no se edita ni se copia** nada de `veritas/`.

Lo que se reutiliza y lo que NO
-------------------------------
SE REUTILIZA (de GDR-v0.2), sin tocar una línea:
  · `Params`, `P_DEFECTO`, los modos `U3_*`, `SP_*`, `MERGE_*`;
  · `EstadoRapido` (kernel) y `EstadoReferencia` (oráculo `BigInt`);
  · `anadir!` — el núcleo GHOSTDAG: padre seleccionado, mergeset, coloreo k-cluster, U3″, `rank`;
  · `peso`/`peso_big` — el peso exacto `⌊2^128/(SR+1)⌋` de `C-GD-01`;
  · `cadena_seleccionada`, `orden_aplicacion`, `virtual_sp`, `blueset`;
  · `es_menor_rank`, `cmp_orden`, `equivalencia`.

NO SE REUTILIZA, porque GDR-v0.2 **no lo tiene** (declarado en su propio `CONTRATO.md` y
verificado: 0 apariciones de `eclipse`, `poisson`, `retardo`, `delta`, `timestamp` en su `src/`):
  · el calendario de eventos Poisson, el retraso `Δ`, las vistas por nodo, el ataque y los
    sensores. Eso es lo que aporta P-ECLIPSE y vive en `mundo.jl`/`sensores.jl`.

EL PESO POR CONTEO NO SE PUEDE EXPRESAR CON `SR`
------------------------------------------------
El instrumento histórico 11b usaba `blue_work = número de azules` (`r8c_gd.py:258`, «work = 1 por
bloque»), y el encargo pide expresamente medir **cuánto cambia** al pasar al peso por `SR` de
`C-GD-01`. `⌊2^128/(SR+1)⌋` vale 1 sólo si `SR+1 > 2^127`, que no cabe en `UInt64`: el peso por
conteo **no es un caso particular** del peso por `SR` en esta implementación.

Existe, sin embargo, una equivalencia exacta de ORDEN que sí permite reutilizar el mismo motor:
con `SR = 0` **para todos** los bloques, `w = 2^128` constante y por tanto
`blue_work(B) = 2^128 · |blues(B)|`, que es **estrictamente monótono en el conteo de azules**.
`cmp_orden`/`SP_PYTHON` desempatan por `sd` y luego por id, exactamente como `r8c_gd._key`.
Es decir: **el régimen de peso por conteo del instrumento histórico es el régimen `SR = 0` del
motor reutilizado**, y esa identidad es la que hace que el control positivo de D8 A3b sea
reproducible sin reimplementar GHOSTDAG. La identidad se comprueba en `test/runtests.jl`, no se
supone.
=#

module GDR

# Ruta absoluta del instrumento ajeno. Se declara para que la procedencia sea verificable y para
# poder comprobar en los tests que existe y que su hash no ha cambiado (HUELLAS.sha256 del informe).
const RUTA_GDR = "/home/katana/zeo/ZEROX/veritas/consenso/ghostdag-rank-v1"
const RUTA_MODULO = joinpath(RUTA_GDR, "src", "GhostdagRank.jl")

if !isfile(RUTA_MODULO)
    error("No se encuentra GDR-v0.2 en $(RUTA_MODULO). El encargo manda reutilizarlo; " *
          "si no está, el instrumento NO debe sustituirlo por una reimplementación silenciosa.")
end

include(RUTA_MODULO)
using .GhostdagRank

# Reexportaciones explícitas: sólo lo que P-ECLIPSE usa, para que el acoplamiento sea auditable.
export GhostdagRank, RUTA_GDR, RUTA_MODULO

end # module
