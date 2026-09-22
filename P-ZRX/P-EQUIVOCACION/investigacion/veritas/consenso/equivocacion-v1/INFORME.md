# EQUIV-v0.1 — ¿alcanza la infracción estrecha a todo el doble farmeo que importa?

Instrumento de la auditoría **P-EQUIVOCACION**. Categoría dominante: **consenso**; secundarias:
economía (κ, castigo) y criptografía (identidad de billete y sello).

- **Informe de la auditoría completa:** [`../../../../INFORME.md`](../../../../INFORME.md)
- **Proposiciones, con demostración o contraejemplo:** [`../../../../PROPOSICIONES.md`](../../../../PROPOSICIONES.md)
- **Falsos positivos y firmante seguro:** [`../../../../FALSOS-POSITIVOS.md`](../../../../FALSOS-POSITIVOS.md)
- **Infracción, identidad y evidencia mínima (propuesta):** [`../../../../DEFINICION-PROPUESTA.md`](../../../../DEFINICION-PROPUESTA.md)
- **Supuestos que codifica el código:** [`../../../../HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`](../../../../HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md)

## Qué hace este proyecto

Enumerador exhaustivo, en Julia y con aritmética entera exacta, de:

1. el ancla de época `C-FLU-04` sobre la vista truncada `C-FLU-03`,
2. el flujo `C-FLU-10` con la entropía de `C-FLU-12`,
3. GHOSTDAG restringido a la vista: `C-GD-01`, `C-GD-03`…`C-GD-08`,
4. las tres identidades de billete del §1 del encargo,
5. `κ` = fracción del doble farmeo que deja evidencia, por régimen (flujo común / divergente) y por
   identidad.

**No fija ningún parámetro de consenso.** `I`, `F`, `L`, `S_max`, `k` y la media de ganadoras `m` son
entradas.

## Cómo se ejecuta

```bash
/home/katana/zeo/ZEROX/veritas/julia.sh --project=. test/runtests.jl
/home/katana/zeo/ZEROX/veritas/julia.sh --project=. --threads=4 run.jl --modo todo
/home/katana/zeo/ZEROX/veritas/julia.sh --project=. --threads=4 bench/benchmarks.jl
for t in 1 2 4; do /home/katana/zeo/ZEROX/veritas/julia.sh --project=. --threads=$t bench/escalado.jl; done
```

Presupuesto declarado: **≤ 4 hilos**, ≤ 4 GiB de RAM, ≤ 200 MiB de disco. Si se agota, checkpoint en
`resultados/` y estado **inconcluso** (no se agotó).

## Resultados

Todo en `resultados/`: `contraste.txt` (oráculo ↔ kernel), `kappa-flujo.csv` (rejilla de la
hipótesis), `kappa-identidad.csv` (κ por identidad y régimen), `benchmark.txt`, `ENTORNO.txt`. Los
artefactos **no son fuente de verdad**: lo que se cita en los informes está regenerado por los
comandos de arriba con `julia = 1.13.0` (`julia-version.toml`) y el `Manifest.toml` de la plantilla
de `veritas/plantilla/`.
