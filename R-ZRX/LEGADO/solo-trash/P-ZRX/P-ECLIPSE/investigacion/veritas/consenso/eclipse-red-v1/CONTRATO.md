# CONTRATO — `eclipse-red-v1`

**Qué es.** El instrumento Julia que ejecuta el encargo P-ECLIPSE: puerto del modelo de eclipse de
la ronda 11b, barrido del régimen vigente, sensores E1/E2 con aritmética exacta, captura de
salientes y aritmética de la partición de flujo.

**Categoría** (`LINEO.md` §1): `consenso`, por el tema dominante — las reglas que se analizan son
`C-FLU-*`, `C-FIN-01`, `C-GD-01` y `C-NET-*`. Categorías secundarias citadas: `red`
(`crates/zx-p2p`, sección D), `rendimiento` (los costes de 92 ms/slot y 1,33–9,86 ms/salto) y
`finalidad` (`Δ` de `DMS-v0.1`).

## Qué SÍ hace y qué garantiza

| Salida | Garantía |
|---|---|
| Control positivo de D8 A3b | **Reproduce la fila publicada a 4 decimales Y su conteo de bloques.** `verificado` |
| Las tres variantes de 11b | **Reproducen sus tablas publicadas, incluidos los `n`.** `verificado` |
| Barrido de régimen (F2) | `medido`, 12 semillas, con `Δ` **simulada** declarada |
| Sensores E1/E2 | `verificado` contra 11b §B.1 y §C.1; una celda de Pareto sin reproducir, anotada |
| Captura de salientes | `derivado` con producto hipergeométrico **exacto** (`Rational{BigInt}`) |
| Partición de flujo | `derivado` con aritmética de enteros sobre las reglas vigentes |

## Qué NO hace (alcance exacto, y es tan importante como lo anterior)

- **No simula la partición de flujo de extremo a extremo.** No construye dos vistas con dos flujos
  y dos anclas propias. Eso exigiría GHOSTDAG restringido a `V_j(B)` **por nodo**, que `GDR-v0.2`
  no ofrece. F1 es una **derivación**, y por eso lleva la etiqueta `derivado` y no `medido`.
- **No fija ningún parámetro.** `F_slots`, `L_suelo_slots`, `I_slots`, `B`, `W`, `n_min`,
  `PRESUP_PAR`, `PRESUP_NODO`, `E`, `α` son **entradas o símbolos**. El instrumento da resultados
  **como función** de ellos.
- **No mide nada en red ni en hardware.** Cita `DMS-v0.1` (simulada) y `coste-salto-v1` (medido).
- **No decide.** `DECISIONES-PENDIENTES.md` enumera; Katana decide.
- **No toca consenso, ni `SPEC.md`, ni `veritas/`.** Escribe sólo dentro de su carpeta.

## Entradas y salidas

- **Entradas:** semilla entera, `α`, horizonte, `k`, `mp`, `msl`, `λ`, `Δ`, régimen de peso, `fc`,
  `f_v`, `paso`, `E`, `t_ecl`. Todas por argumento; ninguna global mutable.
- **Salidas:** tablas a `stdout` y artefactos en `resultados/` (`run-*.txt`, `TESTS.txt`).
  **Los resultados se escriben dentro de la carpeta del instrumento**, no en el CWD: el encargo §6
  avisa de que `ANCLA-v0.2` tiene ese defecto y el riesgo es comparar una copia consigo misma.

## Dependencias y entorno

- Julia 1.13.0. Paquetes: `BenchmarkTools`, `StableRNGs` (en `Manifest.toml`), más `Test`, `SHA`,
  `Random`, `Statistics`, `Printf` de la stdlib. **`StableRNGs` se declara pero el Monte Carlo de
  este instrumento no lo usa**: el RNG es la réplica de CPython (obligatoria para el control) y para
  cualquier MC nuevo se usaría derivación no consecutiva de semillas.
- **`GDR-v0.2` se reutiliza por `include`** de `veritas/consenso/ghostdag-rank-v1/src/GhostdagRank.jl`
  (legítimo: su `src/` no importa paquetes externos). **No se copia ni se edita.**
- **El depósito de Julia.** En la máquina donde se produjo esto, `$HOME/.julia` es de **sólo
  lectura** para el agente y `Pkg` aborta con *«The primary depot is not writable»*. Se usa
  `JULIA_DEPOT_PATH=P-ZRX/P-ECLIPSE/.julia-depot:$HOME/.julia`. Es una circunstancia del entorno,
  no una decisión del instrumento.

## Fuera de alcance, explícitamente

- Verificar la primitiva PoT, el retarget, el rango de solución o cualquier regla de estado.
- Producir vectores de consenso. **Ninguna cifra de este instrumento es una constante de consenso.**
