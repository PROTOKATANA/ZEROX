# PROCEDENCIA — `eclipse-red-v1`

De dónde sale cada pieza que este instrumento usa. `LINEO.md` §5.3 y el encargo §10 exigen poder
reconstruir el resultado y su coste.

## 1 · Código reutilizado de otro instrumento (no copiado)

| Pieza | Origen | Cómo se usa | Qué NO se toca |
|---|---|---|---|
| GHOSTDAG, coloreo, orden, `rank`, peso `⌊2^128/(SR+1)⌋`, oráculo `BigInt` | `veritas/consenso/ghostdag-rank-v1/` (GDR-v0.2, `src/GhostdagRank.jl`) | `include` del módulo, desde `src/GDR.jl` | **No se copia, no se edita, no se mueve.** Se declara la ruta absoluta y se comprueba que existe |

**Por qué `include` y no `Pkg.develop`:** su `src/` **no importa ningún paquete externo**
(verificado leyendo su fuente; `JSON3`, `StableRNGs` y `BenchmarkTools` los usan sólo su `run.jl` y
su `test/`). Luego `include` no arrastra el entorno del otro proyecto ni obliga a modificar ningún
`Manifest.toml` ajeno.

## 2 · Modelo portado de instrumentos históricos en Python (selección, no reejecución)

| Pieza del puerto | Origen | Nota |
|---|---|---|
| Calendario de eventos y `_padres` | `research/scripts/d9-ronda8c/r8c_sim.py` | portado literalmente, incluidas sus rarezas |
| `MundoEclipse.corre_ecl` (control D8 A3b) | `research/scripts/d8-ronda8/d8_a3_smax.py` | es el instrumento del control positivo |
| `MundoVictima.corre_victima` (tres variantes) | `research/scripts/d8-ronda11b/r11b_lib.py` | idem |
| Semántica de GHOSTDAG del histórico | `research/scripts/d9-ronda8c/r8c_gd.py` | **no se porta**: lo aporta GDR-v0.2; sólo se usa como referencia de lectura |
| `n_min_poisson` y `e1_B` | `research/scripts/d8-ronda11b/r11b_lib.py` | portados y **reproducidos** contra sus tablas |

**Los ficheros `.py` no se han ejecutado.** Se han **leído** como evidencia y su modelo se ha
**portado**, que es lo que `veritas/LINEO.md` autoriza: *«Los instrumentos Python históricos
conservados sólo se inspeccionan como evidencia y para portar los modelos pertinentes a Julia»*.

## 3 · Artefactos publicados usados como oráculo

| Artefacto | Qué se reproduce |
|---|---|
| `research/scripts/d8-ronda8/salida_a3b.txt` | la fila de control: `0,8218 / 0,6513 / 0,5920 / 0,5460`, `n_C = 522` |
| `research/scripts/d8-ronda11b/salida_a.txt` (vía las tablas de `informe.md` §A.2–A.3) | 6 filas de las variantes, con sus `n` |
| `research/scripts/d8-ronda11b/informe.md` §B.1, §C.1, §C.5 | `B`, `n_min` y `α` |

## 4 · Datos externos citados, con su etiqueta

| Dato | Fuente | Etiqueta |
|---|---|---|
| `Δ` p99 0,26–0,45 s / 0,26–0,60 s | `veritas/finalidad/delta-medido-v1/` (DMS-v0.1) | **`medido` en simulación**, no en red |
| 92 ms por slot de PoT (AVX-512/VAES); 1,33–9,86 ms por salto | `veritas/rendimiento/coste-salto-v1/` | `medido` en hardware |
| 8 salientes, `tried` 4096, `new` 16384, `/16`, 1000 direcciones por `ADDR`, 163K/284K | `research/fuentes/heilman2015-eclipse.txt` (abierto) | `verificado en fuente` |
| 595 / 620 / 5540 / 8600 IPs para ~50 % | PR #9037 de Bitcoin Core (cuerpo, abierto por el autor de este informe) | **`modelo`** del propio autor, no medición |
| «72 % … 95 % stale» en `tried` | PR #8282 (cuerpo, abierto) | `medición` del autor |
| `PrefixBucket`, `outbound_target = 8`, `MAX_ADDRESSES = 4096`, peso `64^(4−y)/n` | `/home/katana/zeo/fuentes/rusty-kaspa/` | `verificado en fuente` |
| `MAX_PEERS_SALIENTES = 24`, `/24` y `/64` sólo para límites, salientes no contabilizadas por prefijo | `crates/zx-p2p/` | `verificado en fuente` |
| Reglas `C-POT-*`, `C-FLU-*`, `C-GD-01`, `C-FIN-01`, `C-NET-25…33` | `SPEC.md` (citadas **por ID**, nunca por línea) | `verificado en fuente` |

## 5 · Entorno de ejecución, y una circunstancia que se declara

- Julia **1.13.0** (`julia-version.toml`), `Manifest.toml` versionado.
- **Depósito de Julia:** `$HOME/.julia` es de **sólo lectura** para el agente que produjo esto
  (`Pkg` aborta con *«The primary depot is not writable»*). Se usa
  `JULIA_DEPOT_PATH=P-ZRX/P-ECLIPSE/.julia-depot:$HOME/.julia`: el primero escribible, el segundo
  de sólo lectura para paquetes y registro. **Es una circunstancia del entorno, no una decisión del
  instrumento**: con cualquier depósito escribible funciona igual.
- **Ejecución en serie, 1 hilo.** El encargo permite hasta 8; no se necesitaron y `LINEO.md` §7
  trata el tope como techo, no como objetivo.
- Máquina: AMD Ryzen 9 9950X3D (znver5), 123,4 GiB de RAM.

## 6 · Lo que este instrumento NO hereda, y por qué

- **No hereda el peso por conteo como si fuera el vigente.** El histórico pesaba por conteo; hoy
  manda `C-GD-01`. Se miden **los dos** y se declara cuál es cuál.
- **No hereda las constantes de 11b como si fueran las de hoy.** `Δ = 4 s` es nominal y simulado;
  el régimen de hoy se barre aparte.
- **No hereda la conclusión de 11b.** Sus números se reproducen para **validar el puerto**, no para
  reutilizarlos: `INFORME.md` §F2 dice que la fila de control **se mueve hasta +7,3 puntos** al
  cambiar de régimen.
