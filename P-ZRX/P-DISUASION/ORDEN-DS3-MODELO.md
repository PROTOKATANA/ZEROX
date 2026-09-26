# ORDEN-DS3 — Calculadora y Monte Carlo del coste mínimo de los ataques (B0, B1 y candidatos)

## 1. Identidad y contexto

- **ID:** DS-3. **Fecha:** 2026-09-26. **Director:** Claude. **Ejecutor:** DeepSeek (Julia). Se
  congela y lanza cuando DS-2 esté revisada; su especificación es `deepseek/DS2/MODELO.md` tal como
  quede ratificada en `P-ZRX/P-DISUASION/REVISION-DS2.md`.
- **Zona (única escribible):** `/home/katana/zeo/ZEROX/P-ZRX/P-DISUASION/DS3/` (proyecto Julia propio).
- **Objetivo único:** calcular, para los ataques y mecanismos que DS-2 marque E, el **coste mínimo
  absoluto** de X para alcanzar una probabilidad de éxito dada, en cada dimensión del marco, en B0, B1
  y con cada candidato; y el cociente frente al coste del honesto.
- **Pregunta falsable:** la que DS-2 formule para cada celda E («el mecanismo multiplica el coste
  mínimo de X por al menos …»), que se refuta con la tabla.

## 2. Método (LINEO)

1. Fórmulas cerradas de DS-2 implementadas **y** un Monte Carlo independiente del mismo modelo; los
   dos deben coincidir dentro del error estadístico declarado en los casos de comprobación de DS-2.
2. Parámetros de escenario leídos de un fichero, cada uno con su etiqueta (medido / fuente /
   hipótesis) y su procedencia; barridos declarados; semillas fijas con `StableRNGs` no consecutivas.
3. Salidas: tablas CSV y un `INFORME.md` con, por ataque, «coste mínimo en B0 → en B1 → con cada
   candidato», el cociente frente al honesto, y qué parámetro domina (sensibilidad).
4. `Pkg.test()` con los casos de comprobación; `run.jl` reproducible con un comando.

**Prohibido Python.** Presupuesto: 2 h, 4 hilos, 8 GiB. DeepSeek `deepseek-flash`, esfuerzo `high`;
LINEO antes del código; nada fuera de la zona; sin commit ni push; sin secretos. Entrada congelada
`P-ZRX/P-DISUASION/ENTRADA-DS3.sha256`.

## Ratificación (tras DS-2)

Especificación: `P-ZRX/P-DISUASION/resultados-DS2/MODELO.md` (copia fiel de `deepseek/DS2/MODELO.md`),
ratificada en `REVISION-DS2.md`. Los siete casos de su §4 son la regresión obligatoria de `Pkg.test()`.
Además de su tabla por ataque, entrega una tabla **por mecanismo** con el Δ de coste absoluto de X y el
coste para el honesto en los escenarios del §3, para responder a Katana qué mecanismo encarece qué y
cuánto.
