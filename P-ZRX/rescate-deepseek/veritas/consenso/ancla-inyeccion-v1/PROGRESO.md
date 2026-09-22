# PROGRESO — ANCLA-v0.1 (bitácora, fechas reales)

## 2026-09-18

**Estado `git` al empezar** (`git -C /home/katana/zeo/ZEROX status --short`):

```
 M SPEC.md
 M TAREAS.md
 M ci/reglas-sin-cablear.txt
 M ci/reglas-sin-codigo.txt
?? P-2.1/
?? problemas/
?? veritas/consenso/poda-post-v1/
?? veritas/consenso/prueba-recursiva-v1/
?? veritas/seguridad/
```

**Estado `git` al terminar:** idéntico (no se tocó nada fuera de `deepseek/P-2.1/`). Ver la
comprobación al final de esta bitácora.

### Trabajo

1. **Lectura obligatoria**: `veritas/LINEO.md` completo; `research/dag-poas-auditoria.md`
   (ATAQUE 1/2); `research/dag-poas-ancla-de-orden.md` (R-FIN-5 y R-FIN-14 (a)–(h));
   `research/pot-aes-asic-chacha.md` §3; `veritas/seguridad/coste-rama-privada-v1/` (INFORME §5,
   PROCEDENCIA); `TAREAS.md` §2.1 y §3.3; `veritas/consenso/ghostdag-rank-v1/` (GDR-v0.2) y
   `veritas/finalidad/delta-medido-v1/` (DMS-v0.1).
2. **Verificación del §2 del encargo (día uno)**: la corrección del modelo es correcta y coincide
   con R-FIN-14. Se confirma con la ronda 9c §E (`n_eval = ρ·W_dec`, 0 para `ρ ≤ 1`) y la
   calibración `I ≥ ρ_max·W_dec` (f). No hay motivo para detener el encargo.
3. **Zona y contrato**: `CONTRATO.md`, `MODELO.md`, `Project.toml` recortado (StableRNGs + stdlib),
   `run.jl`, `src/`, `test/`, `bench/`, `resultados/`.
4. **Implementación**: simulador de red honesta (DMS-v0.1) + DAG con 15 puntas + GDR-v0.2 sin
   modificar; medición transitoria con estados incrementales.
5. **Validación de la red**: `Δ_99` medio 0,234 s / p99 0,364 s (rango medido 0,26–0,60 s). ✓
6. **Defecto 1 encontrado y corregido** (comparación de cadenas en espacios de índices distintos).
   `MODELO.md` §6. Los resultados publicados son posteriores.
7. **Defecto 2 corregido**: dimensionado de `maxB` con cola de Poisson.
8. **Corridas**:
   - `resultados/prueba2.*`: 200 réplicas, `λ=1` (calibración del estimador).
   - `resultados/curva-grande.*`: **10 000 réplicas**, `λ=1`, `T=600`, 24 hilos, 1 514 s de pared.
   - `resultados/curva-lambda3.*`: 800 réplicas, `λ=3`, `T=300` (contraste de carga).
   - `resultados/ENTORNO.txt`.

### Presupuesto usado

- RAM pico observada: por debajo de ~8 GiB (tope 64 GiB). ✓
- Hilos: 24 (tope 24). ✓
- Disco: `resultados/` < 100 MiB. ✓
- Ninguna corrida quedó **inconclusa**.

### Lo no hecho / abierto

- `D_min(10⁻⁹)` es **estimado**, no medido (harían falta ~10⁹ unidades independientes).
- No se simula partición, eclipse ni adversario; no se re-deriva R-FIN-14.
- No se ejecutó JET.jl ni `LoopVectorization` (no justificado: el cuello es la construcción de
  estados de GDR por observador, no un kernel regular).

### Comprobación final

`git status --short` al terminar la sesión: idéntico al de arriba; sólo se añadió contenido bajo
`deepseek/P-2.1/`. Verificado con dos llamadas en fechas distintas de la misma sesión.

- Tests con `--check-bounds=yes`: **131/131** en verde (`resultados/TESTS.txt`).
- `HUELLAS.sha256` (rutas desde la raíz del repo): **verificado, `sha256sum -c` exit 0**, 45 rutas
  (instrumento + fuentes de GDR-v0.2 + fuentes citadas de `research/`).
- Benchmark y escalado: `resultados/BENCH.txt`, `resultados/ESCALADO.txt`.
