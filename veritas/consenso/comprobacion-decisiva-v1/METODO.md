# METODO — Comprobación decisiva v1 (etapa A)

> Nota (2026-09-12, promoción): este documento fue el plan de la comprobación. La
> frontera «solo deepseek/» que describe fue la de su fase de producción; esta promoción
> a `veritas/consenso/comprobacion-decisiva-v1/` ya la supera. El resto se conserva tal
> cual fue aprobado.
>
> Nota (2026-09-12, enmienda Z0): la mención de «Aceptación y controles» a «conservar la
> discrepancia legada del helper Rust» como evidencia documentada queda **superada** por la
> enmienda Z0 (ver `retarget-causal-endogeno-v1/CONTRATO.md` revisión 2 y el INFORME de esta
> comprobación): el control de ventana vacía con HeldZero ahora verifica la **convergencia**
> Julia–Rust (`range_at(40)=200`), no la discrepancia.

Fecha de aprobación: 2026-09-12.
Zona de escritura exclusiva: `/home/katana/zeo/ZEROX/deepseek/`.

## Objetivo

Demostrar o refutar, en Julia CPU (sin Python, sin GPU): dos nodos que reciben los
mismos bloques en distinto orden, con cuerpos retenidos y copias presentes, convergen
sobre una historia y obtienen exactamente los mismos pagos, transacciones, consumos y
retarget, mientras los candidatos independientes completos pueden seguir avanzando.

## Estructura

```
deepseek/
├── PLAN.md                      # este plan + decisiones y bifurcaciones resueltas
├── bitacora/                    # registro fechado de cada paso, comandos y resultados
└── comprobacion-decisiva-v1/    # la auditoría, con estructura LINEO
    ├── Project.toml / Manifest.toml / julia-version.toml
    ├── src/{modelo,referencia,rapido,validacion}.jl
    ├── test/runtests.jl
    ├── run.jl                   # semilla obligatoria, determinista
    ├── bench/                   # solo coste del workload, como en ARM-v0.1
    ├── resultados/              # artefactos con entorno, comando y exit_code
    └── INFORME.md               # qué requisito del objetivo queda demostrado/medido/pendiente
```

## Qué modela la auditoría (nuevo respecto a ARM-v0.1)

1. **Capa económica mínima entera** — transacciones con entradas (consumos, tipo UTXO
   abstracto con IDs enteros) y salidas (pagos). Sin criptografía real (se declara);
   prohibido Float64 para dinero (LINEO §9). Doble gasto → Invalid sin publicar.
2. **Peso azul con deduplicación** — el billete identifica la oportunidad (incluyendo
   piece_offset y variantes); las copias agrupan a la misma oportunidad y no multiplican
   el peso. La multiplicación ingenua se implementa como control negativo que debe ser
   detectado.
3. **Dos nodos, no dos vistas** — cada nodo tiene su cola de entregas adversarial: mismo
   conjunto de bloques, distinto orden, un cuerpo retenido por nodo. Convergencia al
   completarse la evidencia.
4. **Progreso de candidatos independientes** — mientras una historia queda Pending por
   cuerpo retenido, el nodo adopta una rama independiente completa; cuando llega el
   cuerpo tardío, la historia retenida se valida y reproduce (no inerte para siempre).

## Reutilización sin editar

Motores DCM-v0.1 (`veritas/consenso/disponibilidad-causal-multivista-v1/`) y RCE-v0.1
(`veritas/consenso/retarget-causal-endogeno-v1/`) por ruta relativa, patrón de
`AdmisionRetargetMultivista.jl:3-8`. Referencia BigInt que reescanea vs kernel UInt128
con cursor, como en ARM-v0.1.

## Aceptación y controles

- Igualdad exacta de proyecciones económicas (pagos/consumos) y de retarget entre ambos
  nodos al converger; progreso independiente observado.
- Controles negativos: reloj local (heredado de ARM), copias multiplicando peso, doble
  gasto, ventana vacía con HeldZero (conservar la discrepancia legada del helper Rust
  como evidencia documentada).
- Timeout = inconcluso.

Presupuesto declarado: 1 hilo, BLAS 1, ≤8 GiB RAM, ≤30 min/suite, 60 s por comando
Julia, semilla-etiqueta 20260912.

## Límites declarados en INFORME (no los cierra)

Derivación GHOSTDAG real, validación PoAS contra el rango del pasado causal,
firmas/criptografía, red libp2p, particiones/eclipse, durabilidad — siguen pendientes;
esta comprobación decide la arquitectura, no es el nodo.

## Frontera estricta de escritura (decidida con el usuario)

- Todo lo que se crea, escribe o modifica va dentro de `deepseek/`. Nada se toca en
  `veritas/`, `crates/` ni ningún otro directorio.
- Solo lecturas fuera de `deepseek/`: los motores DCM-v0.1 y RCE-v0.1 se incluyen por
  ruta relativa sin editar sus archivos; SPEC/MIGRACION/LINEO solo como lectura.
- Único efecto lateral fuera del repo: caché de precompilación de Julia (`~/.julia`).
  Declarado en bitácora.
- Sin commits, sin push; `deepseek/` queda sin versionar salvo petición explícita.

## Etapas

1. Escribir `deepseek/PLAN.md` + abrir bitácora con fecha, HEAD de git y decisiones.
2. Crear el esqueleto de `comprobacion-decisiva-v1/` (patrón ARM, sin sus vectores).
3. Implementar modelo: economía mínima, peso azul dedup, dos nodos con calendarios de
   entrega.
4. Referencia + kernel + validación + controles negativos.
5. `runtests.jl`, `run.jl`, registro de resultados con `veritas/julia.sh`.
6. `INFORME.md` con el veredicto por requisito del objetivo y la bitácora cerrada.

## Bifurcaciones resueltas

- Auditoría nueva en `deepseek/comprobacion-decisiva-v1/`, no bajo `veritas/` (frontera
  de escritura del usuario); sigue la estructura LINEO de `veritas/plantilla/`.
- Motores DCM/RCE reutilizados por inclusión relativa, no copiados ni editados.
- Semilla-etiqueta 20260912; determinismo total (`rng=none`), como en ARM-v0.1.
- Julia CPU, 1 hilo, BLAS 1: prohibido Python y GPU (AGENTS.md).
