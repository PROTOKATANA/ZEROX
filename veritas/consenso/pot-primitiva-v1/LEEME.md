# pot-primitiva-v1 — el PoT como primitiva y el contrato del verificador

**Esto NO es un instrumento de cálculo: es una PROPUESTA de texto normativo.** No tiene
`Project.toml`, `run.jl` ni `resultados/`, y por eso no sigue la estructura de `veritas/LINEO.md`
§1: no hay nada que ejecutar salvo los vectores de prueba de `vectores/`. Vive en `veritas/` porque
es la evidencia sobre la que se edita el SPEC, y `PROCEDENCIA.md` es su testimonio de validación.

| Archivo | Qué es |
|---|---|
| `PROPUESTA-SPEC.md` | Las ocho reglas `C-POT-01…08`, con sus etiquetas de afirmación |
| `DECISIONES-PENDIENTES.md` | D-1 y D-2, con sus opciones, su coste y la decisión de Katana |
| `PROCEDENCIA.md` | Testimonio del validador. **No se edita.** Incluye la corrección obligatoria a C-POT-05 al pasar al SPEC |
| `PROGRESO.md` | Bitácora del ejecutor (DeepSeek). Rutas históricas; véase su nota de migración |
| `ENTRADA/` | Copia congelada del encargo y el prompt que lo gobernaron, con `ENTRADA.sha256` |
| `vectores/` | Crate Rust mínimo que genera los vectores V1–V5 (`LEEME.md` propio) |
| `HUELLAS.sha256` | Huellas de todo lo anterior, con rutas desde la raíz del repositorio |

## Procedencia y migración

Redactada por **DeepSeek** en `P-POT/propuesta/` según `P-POT/ENCARGO.md`, validada por Claude el
2026-09-20 y migrada aquí el mismo día por `P-CIERRE/ENCARGO.md` §1.1. El original en `P-POT/`
queda intacto. **Único cambio de código en la migración:** la dependencia por ruta de
`vectores/Cargo.toml` pasa de `../../../prototipos/pot-estable` a
`../../../../prototipos/pot-estable`, porque el destino está un nivel más hondo.

## Comprobaciones

```bash
# desde la raíz del repositorio
LC_ALL=C sha256sum -c veritas/consenso/pot-primitiva-v1/HUELLAS.sha256
LC_ALL=C sha256sum -c veritas/consenso/pot-primitiva-v1/ENTRADA/ENTRADA.sha256

CARGO_TARGET_DIR=/tmp/ppot-target cargo test --release --offline -j 2 \
  --manifest-path veritas/consenso/pot-primitiva-v1/vectores/Cargo.toml
```

## Lo que esta propuesta NO cierra

Está enumerado al final de `PROPUESTA-SPEC.md`. Lo más importante: el inyector, la activación de
la entropía, la derivación del flujo y la selección entre flujos son de `regla-flujo-v1`; los
valores de `I`, `L`, `F`, `ρ_max`, `D` y `N(s)` van como símbolos; y la verificación conjunta
PoAS/PoT de §7.1 sigue pendiente de redacción.
