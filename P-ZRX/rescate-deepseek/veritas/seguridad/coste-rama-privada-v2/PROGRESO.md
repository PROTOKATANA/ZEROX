# CRP-v0.2 · Progreso

## 2026-09-18

1. **Huella verificada.** `sha256sum -c` OK. Copia byte a byte a `ENTRADA.md`; coincide con el
   original. Sidecar conservado como `ENCARGO.sha256`.
2. **Lectura de fuentes.** `AGENTS.md`, `README.md`, `MIGRACION.md`, `research/README.md`,
   `LINEO.md`; SPEC §6.1–§7.3/§11; TAREAS §2.1–2.4/§2.7–2.8/§3.1/§4.1; ancla-de-orden;
   RCE/ARM; Rust DAG y listas `ci/`.
3. **`MATRIZ-AUTORIDAD.md`.** Estado normativo por regla; se separa texto vigente de instrumentos
   y de Rust aislado vs ruta activa (`fork_choice` lineal sigue activo).
4. **Modelo.** Baseline ±1, DP acotada con masa cruda, RCE rev2, R-FIN-5 estructural, GDR wrapper
   y simulador por vistas locales.
5. **Regresiones de D1–D10 corregidas:**
   - D1: simulación por eventos con vistas locales; fixtures deterministas de rojo/cero.
   - D2: unidad única, `z=g·d`, soporte adaptativo, masa cruda y cotas `[P_L,P_U]`.
   - D3: DPs separadas de empate y superación; regresión `1/2⁻`.
   - D4/D5: `SR` derivado por RCE en el perfil candidato; controlador del SPEC `Pendiente`.
   - D7: descriptor con `PotOrigin`/`N`; prefijo en `slot(X)`; no `true` sin autenticar.
   - D8: color contextual `(fusionador, bloque)`; U2/U3 en GDR.
   - D9: `S` escenario; I/O solo lectura, cache caliente; `S_adversario` Pendiente.
   - D10: se abandona "ataque gratis"; se declara "cero espacio adicional bajo supuestos".
6. **Suite:** 128/128 en verde (`resultados/TESTS.txt`). Benchmarks y artefactos de `run.jl`.
7. **Corrección de signo detectada por los tests.** `g_E` se reorientó a
   `E[W_priv − W_pub]/T` (positivo ⇒ ventaja adversaria), como pide el encargo §1.
8. **Blancos honestos:** revisión de la asociación DAG→cohorte RCE; medición de `S_adversario`;
   C-GD-11 y finalidad. Todo ello queda como límite declarado, no rellenado.
9. **Revisiones en contexto independiente** (`REVISION-MATEMATICA.md`, `REVISION-RUST.md`,
   `REVISION-JULIA.md`). Encontraron defectos reales (cotas, cifras, estado normativo,
   R-FIN-5 no invocado, `Δ=0`). Correcciones en `REVISION-RESPUESTA.md`; suite 131/131.
10. **Hallazgo central del escenario candidato:** con R-FIN-5 estructural (máximo de ramas), la
    frontera medida da `P_win=0.000` (IC sup 0.057) para `S≤4, α≤0.3`; el contrafactual aditivo
    alcanza `0.766` a `S=4, α=0.2`. Es decir, el peligro `S·α` existe **solo** si los flujos se
    suman. R-FIN-5 no está adoptada: resultado `Válida estructural / Pendiente cripto`.
