# METODO — GDR-v0.2

Todos los comandos se ejecutan desde la raíz del repositorio (`/home/katana/zeo/ZEROX`), usando
siempre `veritas/julia.sh` y `--project=veritas/consenso/ghostdag-rank-v1`.

## Convivencia de CPU (histórico)

Durante la ejecución en `deepseek/`, las corridas de más de 30 s o de más de 1 hilo usaron un
candado con PID (`deepseek/OCUPADO-CPU` / `deepseek/MIDIENDO`) para no contaminar el banco de
`veritas/rendimiento/coste-salto-v1`, que medía a la vez. Fuera de esa convivencia no hace falta:
basta con no medir el escalado mientras otra carga use la máquina.

## Reproducir la suite de tests

```bash
veritas/julia.sh --check-bounds=yes \
  --project=veritas/consenso/ghostdag-rank-v1 \
  veritas/consenso/ghostdag-rank-v1/test/runtests.jl
```

## CLI (`run.jl`)

```bash
# entorno (git HEAD, fecha, VERSION, hilos, CPU/RAM, BLAS, Pkg.status())
veritas/julia.sh --project=veritas/consenso/ghostdag-rank-v1 \
  veritas/consenso/ghostdag-rank-v1/run.jl --entorno

# los 6 vectores de Kaspa (SP_KASPA/MERGE_KASPA explícitos)
veritas/julia.sh --project=veritas/consenso/ghostdag-rank-v1 \
  veritas/consenso/ghostdag-rank-v1/run.jl --kaspa

# equivalencia oráculo/kernel bajo la regla C (P_DEFECTO), N DAGs aleatorios
veritas/julia.sh --project=veritas/consenso/ghostdag-rank-v1 \
  veritas/consenso/ghostdag-rank-v1/run.jl --equivalencia 600 --seed 0xACAC10

# 3.2(d): equivalencia con claves independientes, 4 modos × 6 k, ventana 1..30, ≥300 c/u
veritas/julia.sh --project=veritas/consenso/ghostdag-rank-v1 \
  veritas/consenso/ghostdag-rank-v1/run.jl --equivalencia-c --seed 0xC0DEC1

# determinismo bajo la regla C: <familias> DAGs, <ordenes> entregas c/u (familia 1: ventana=6)
veritas/julia.sh --project=veritas/consenso/ghostdag-rank-v1 \
  veritas/consenso/ghostdag-rank-v1/run.jl --determinismo 3 1000 --seed 0x6D60

# coste por bloque, bits de blue_work y cota corregida (3.5)
veritas/julia.sh --project=veritas/consenso/ghostdag-rank-v1 \
  veritas/consenso/ghostdag-rank-v1/run.jl --resumen --seed 0xB0E1
```

## Benchmarks, perfil y escalado (1 hilo salvo escalado)

```bash
veritas/julia.sh --project=veritas/consenso/ghostdag-rank-v1 \
  veritas/consenso/ghostdag-rank-v1/bench/benchmarks.jl

veritas/julia.sh --project=veritas/consenso/ghostdag-rank-v1 \
  veritas/consenso/ghostdag-rank-v1/bench/perfil.jl

# escalado: repetir con --threads=N,0 para N ∈ {1,2,4,8,16,24} (24 solo sin MIDIENDO vivo)
JULIA_NUM_THREADS=<n> OPENBLAS_NUM_THREADS=1 veritas/julia.sh \
  --project=veritas/consenso/ghostdag-rank-v1 --threads=<n>,0 \
  veritas/consenso/ghostdag-rank-v1/bench/escalado.jl
```

## @code_warntype (3.6b) y memoria (3.6a)

```bash
veritas/julia.sh --project=veritas/consenso/ghostdag-rank-v1 \
  veritas/consenso/ghostdag-rank-v1/bench/warntype.jl > veritas/consenso/ghostdag-rank-v1/resultados/WARNTYPE.txt

veritas/julia.sh --project=veritas/consenso/ghostdag-rank-v1 \
  veritas/consenso/ghostdag-rank-v1/bench/memoria.jl --seed 0xB0E1 > veritas/consenso/ghostdag-rank-v1/resultados/MEMORIA.txt
```
La corrección 1 ejecutó ambas mediciones desde `tmp/` y borró los scripts, así que sus salidas no
eran reproducibles. Al migrar se escribieron `bench/warntype.jl` (añade
`revisar_con_bloque_cadena`, que faltaba) y `bench/memoria.jl`, y los dos resultados se
regeneraron con ellos.

## Entorno de la corrida publicada

`julia 1.13.0`, `znver5`, 32 hilos lógicos / 123,4 GB RAM en la máquina; tests/Kaspa/derivaciones a
1 hilo; escalado sujeto a convivencia con `deepseek/MIDIENDO`. `Manifest.toml` **sin cambios** en
esta corrección (§0: no se añadieron dependencias): `BenchmarkTools 1.8.0`, `JSON3 1.14.3`
(`[deprecated]`, no sustituido — fuera de alcance de Corrección 1), `StableRNGs 1.0.4`.

## Fixtures de Kaspa

Sin cambios desde GDR-v0.1: `fixtures/kaspa/dag{0..5}.json`, origen y hashes en
`fixtures/kaspa/ORIGENES.sha256` (commit rusty-kaspa `c338d495bec29e4dc8b5149f99e8db6fa916ed4a`).

## sha256 de las fuentes leídas para esta corrección (2026-09-14) — registro histórico

Esta lista fija lo que leyó la corrección 1. La huella vigente es `HUELLAS.sha256`, generada al
migrar desde la raíz del repositorio y con rutas finales (`TAREAS.md` volvió a cambiar en el
commit 9c2360d).

`TAREAS.md` cambió desde GDR-v0.1 (Katana añadió el bloque de la regla C en §1.3); el resto de
fuentes primarias no ha cambiado. Se recalculan también las del propio instrumento, todas
modificadas en esta corrección salvo `rapido.jl` (comparadores sin cambios respecto a v0.1).

```
ddbe5182b007e21645519afe149762bfd806640fd1f790608419c84777c6195b  TAREAS.md
1683af53e6c118213ea5ddfa85872a9e3470e72e20eea51ca308296aa4deb92f  SPEC.md
55e5c8158c9e495c9ba47f97bb834dd23d0b3fff44e46def98ea3d7f952b1a6a  research/dag-poas-ancla-de-orden.md
0343b83290489fde1b3ba961eb8fdd1f7ccb1bdf1ea1ee7062db993fc48936e1  veritas/LINEO.md
573662d8da56cdaf9995c102b50b52286b087dd62cbe2f3533ca47f08a99ef16  veritas/consenso/disponibilidad-causal-multivista-v1/CONTRATO.md
f24eac2c0ed6b7cd72eb47f8d14cea25c7e29e159cf5b47580e324b9316f01f9  research/scripts/d9-ronda8c/r8c_gd.py
e90369190cfdde4cc8208f0e1a67f35d83f5aec02c41147d4f0c6339abdd217b  research/scripts/d9-ronda8c/r8c_test_gd.py
044b12f1941733ce45c5f3a5376e198ef2b4796f5b6f5bda3c4b670a18055e33  fuentes/rusty-kaspa/consensus/src/processes/ghostdag/protocol.rs
8b6716afbaddd2becd1910e8d80108747daaa97970669cb50c22ff0fca0dc47f  fuentes/rusty-kaspa/consensus/src/processes/ghostdag/ordering.rs
8a86df5cf864a17c963be9cd1cf08961c040ea28e4684b238506ec0a51671122  fuentes/rusty-kaspa/consensus/src/processes/ghostdag/mergeset.rs
c24b8a276edd0defcf6c22f46a7bae289bb59c9639eee6dde4fe46657484b5d3  fuentes/rusty-kaspa/crypto/hashes/src/lib.rs
0e681d096236e4beb76c4dd51f739233d057a0330cdc2c7b88ba270ce364e166  fuentes/rusty-kaspa/testing/integration/src/consensus_integration_tests.rs
9643647e6b1762e28da614a00d686cffe4c08d58ece8dbb5dbc88aea85033f1f  veritas/consenso/ghostdag-rank-v1/src/GhostdagRank.jl
7769415b749f51133be454f525b12b2eb9f4549081f952e93e17dfa12d3a71b3  veritas/consenso/ghostdag-rank-v1/src/modelo.jl
dd9f200b419f7601ca49b8ccba1f18d3bb670012b4a4e52bae5e7091550c4579  veritas/consenso/ghostdag-rank-v1/src/rapido.jl
51e3961553bca60b0c3d3dda5d1d1e17a82bb4c8945cbfa417c9845117c7080c  veritas/consenso/ghostdag-rank-v1/src/referencia.jl
05dd24d8dd35e349b0f2fb8827b2b564bcce23125c4c888e88901e3e756a879d  veritas/consenso/ghostdag-rank-v1/src/validacion.jl
c2af15c1feeb074475f984f91e09e20869c1f7e93578e84462a47b8d3c9e8b91  veritas/consenso/ghostdag-rank-v1/test/runtests.jl
6a609a07475a7344dbeca117013b4482d77d6a9cfe2fd3802d40aad2cc1b5555  veritas/consenso/ghostdag-rank-v1/DERIVACIONES.md
39fbc8bd7a80534b5a89a660296c1629025319df0bfd0f7bc66820781b7b0032  veritas/consenso/ghostdag-rank-v1/run.jl
```

`HUELLAS.sha256` se generó al migrar; comprobar con `sha256sum -c` desde la raíz del repositorio.

## Registro de convivencia de esta corrección

Al empezar: `deepseek/MIDIENDO` y `deepseek/OCUPADO-CPU` ausentes; `git status --short` mostraba
`M TAREAS.md` (cambio de Katana, no de esta sesión — ver `BITACORA.md`). Durante la
corrección, `deepseek/MIDIENDO` apareció vivo (sesión hermana, "perfil-A"); el benchmark de
escalado por hilos se pospuso hasta que se liberase, en vez de competir por CPU con la medición
ajena. Registro completo, con hora real de cada paso, en `resultados/REGISTRO.log`.
