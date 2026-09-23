# CONTRATO de lectura — `veritas/seguridad/segundo-vdf-v1` (SDV-v1)

Este documento dice **qué es** este instrumento, **qué mide**, **qué no mide** y **cómo se
reproduce**. El informe es `INFORME.md`; las premisas que codifican la conclusión, en
`HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`. Ningún resultado de aquí adopta un parámetro ni
modifica el SPEC.

## 1 · Pregunta y alcance

¿Reduce una segunda cadena secuencial AES de revelación retardada (`R-FIN-14(h)`) la ventana de
adelanto `V` y el sesgo del ancla, y a qué coste por nodo, bajo el mismo escenario y riesgo?
Alcance: **modelo de una sola frontera de PoT por actor** (atacante y honesto), en índices de slot,
sin red, sin AES medido y sin economía. Categoría dominante: `seguridad`; secundarias `consenso`,
`red` y `rendimiento`.

## 2 · Qué es cada pieza

| Archivo | Contenido |
|---|---|
| `src/modelo.jl` | Parámetros, aritmética de calibración (defecto 1) y coste, y la transición por barreras. |
| `src/referencia.jl` | Oráculo **independiente** en `Rational{BigInt}`: forma cerrada max-plus + integración exacta de `V` y cuantiles. |
| `src/rapido.jl` | Kernel `Float64` por puntos de ruptura, histograma temporal y barrido paralelo sin carreras. |
| `src/escenarios.jl` | Defecto 2 (escenarios consistentes), defecto 3 (semillas) y regímenes de líneas. |
| `src/coste.jl` | Defecto 5 (expresabilidad en `zx-pot`) y coste por recurso. |
| `src/consenso.jl` | Defecto 4: mapa de reglas afectadas y máquina de estados `Válido/Inválido/Pendiente`. |
| `src/validacion.jl` | Controles externos (filas publicadas), equivalencia oráculo↔kernel y controles §3. |
| `run.jl` | CLI reproducible; escribe `resultados/*.txt`. |
| `test/runtests.jl` | 64 tests de regresión. |
| `bench/benchmarks.jl` | Rendimiento, asignaciones y escalado de hilos. |

## 3 · Entradas (todas símbolos; ninguna se adopta)

`L, I, W_dec, D, S_max, Lrev, ρ, α` en slots y adimensionales; `con_h` (segunda cadena),
`espera` (el atacante espera la decisión), `semilla_futura` (C-FLU-12 vs h.1),
`revelacion_paralela` (régimen monolineal vs precomputación en línea dedicada), `cruce`
(con coste o gratis) y `lead_h` (`0` o `D`). Entradas **medidas** que sí se usan como datos:
`verify = 0,096147 s/slot`, `prove = 1,561347 s/slot` (Ryzen 9 9950X3D,
`research/dag-poas-ancla-de-orden.md:342`), y el techo de líneas (25 líneas ⇒ 1,7 % de
degradación; `d8-ronda10a` §B.3.1).

## 4 · Qué está demostrado, medido, derivado y pendiente

- **Demostrado (exacto):** equivalencia oráculo↔kernel en `Rational{BigInt}` (192 casos, `Δτ = 0`);
  frontera de calibración `I ≤ (Lrev − ρ_max·W_dec)/(ρ_max−1)`; cotas superiores de `ρ_max`;
  condición de puntualidad; transiciones de estado.
- **Medido (en este instrumento):** `V`, cuantiles y coste en los escenarios declarados;
  reproducción de las filas publicadas de REV-v1.0/ADL-v1.0 con error ≤ 0,045 slots.
- **Derivado:** cotas y factores (p. ej. líneas `⌈Lrev/I⌉` para ocultar la revelación).
- **Pendiente:** el coste real de producir y verificar la cadena larga con la primitiva auditada
  (la API pública no la expresa: ver `INFORME.md` §6); `ρ_max` por plataforma; `W_dec`, `α` y `Δ`
  en red real; la traducción de `V` a finalidad económica; el presupuesto `PRESUP_NODO`.

## 5 · Reproducción

```bash
cd /home/katana/zeo/ZEROX/veritas/seguridad/segundo-vdf-v1
export JULIA_DEPOT_PATH="/tmp/dsh-julia-depot:$HOME/.julia"   # ~/.julia es de solo lectura
/home/katana/torio/.juliaup/bin/julia --project=. --threads=16,0 test/runtests.jl
/home/katana/torio/.juliaup/bin/julia --project=. --threads=16,0 run.jl --modo todo --replicas 64 --seed 0x5a5a
/home/katana/torio/.juliaup/bin/julia --project=. --threads=16,0 bench/benchmarks.jl
```

Semilla maestra `0x5a5a`, derivación `StableRNG(semilla + id_réplica)`, reducción en orden de id.
Entorno y fecha en `resultados/ENTORNO.txt`.

## 6 · Presupuesto declarado antes de ejecutar

24 hilos (tope), 64 GiB de RAM, 8 GiB de disco temporal. Consumo real: cuerpo de la auditoría
**≈3,3 s** de pared a 16 hilos (más ≈45 s de compilación JIT), **<1 GiB** de RAM, **<1 MiB** de
disco. GPU no se usa (recursión escalar secuencial; `LINEO.md` §5.5).

## 7 · Límites que impiden afirmar una mejora global de seguridad

1. `V` es **ventana de conocimiento de frontera**, no probabilidad de doble gasto ni finalidad.
   Reducir `V` un 28 % no reduce la finalidad un 28 %.
2. No hay red (`Δ`, GHOSTDAG, reorganizaciones), ni economía, ni partición modelada.
3. El adversario se modela como **una frontera**; un segundo reloj paralelo no demuestra
   exclusividad de espacio (control negativo, §3 del encargo).
4. La condición inicial (dos fronteras a nivel en `t = 0`) infla `V_max` a `ρ` grande; el informe
   lo cuantifica y separa el transitorio.
5. La segunda cadena **no** se ha medido en hardware: su coste queda `Pendiente`.
