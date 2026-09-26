# REVISIÓN W07c — analizador de los registros del nodo (Julia)

**Revisor:** Claude (director). **Fecha:** 2026-09-26 (≈ 23:14). **Ejecutor:** DeepSeek, 22:57–23:10.
Evidencia: `deepseek/W07c/` (`HUELLAS.sha256` 63/63 en verde, comprobado); instrumento migrado a
`P-ZRX/P-MEDICION/analisis-registro-v1/` (sin el depósito de Julia ni los 211 MB del sintético de 10⁶ eventos,
regenerable con `bench/`), con `HUELLAS.sha256` propias. **Veredicto: SUPERADO.**

## Comprobado por el director

- `ENTRADA-W07c.sha256` 7/7 al principio y al final (el ejecutor la reverificó; los registros de W06d4 intactos).
- V1 70/70 exactos (8 conjuntos a mano, incluidos truncado final frente a truncado en medio, latencia negativa,
  v0 sin versión), V2 36/36 (nearest-rank), V3 402/402 (con semilla fija, contra un oráculo O(E²)), V5: el
  análisis de W06d4 tarda 15,7 ms; 10⁶ eventos, 3,73 s y 826 MiB de pico.
- **Comprobación independiente (`grep`/`comm` sobre los registros crudos):** los pares producción → admisión
  por pareja de nodos coinciden **exactamente** con `latencias.tsv` (181, 306, 186, 218, 144, 188; total 1 223).
- Las 13 «faltas de definición» (`FALTAS-DE-DEFINICION.md`) se informaron antes de escribir código y todas
  adoptan la lectura determinista mínima: **se ratifican las 13**. La nº 11 corrige mi orden: en esta máquina
  `JULIA_DEPOT_PATH=<zona>/.julia-depot:` no alcanza `/home/katana/.julia`; se usa la ruta explícita.

## Errores del director que esta entrega destapa

1. La orden llamó «ejecución V4 de W06d4» a `run/{A,B,C}`, que son las ejecuciones de **V6/V7** (con un nodo
   caído por `ErrMergeDepth`). Los resultados del analizador sobre esos registros son correctos para lo que
   son; no describen V4.
2. «Estado final distinto» no es divergencia cuando los nodos se paran en momentos distintos (en V4 de W06d4,
   C siguió seis minutos más que A y B). El estado **virtual** depende además de las puntas laterales que cada
   nodo conoce (`REVISION-W06d4.md`). **Consecuencia para W07b:** comparar el estado exige un **reposo**: los
   nodos dejan de producir en el mismo slot, siguen validando y propagando, y solo entonces se compara. Se
   añade a W07a un parámetro de medición `--dejar-de-producir-en-slot` (no es consenso).

## Límites

Instrumento de análisis de registros, no de consenso. El modelo que usó el ejecutor no se verificó por API
(declarado). Métricas de v0: 8 no medibles (lo dice su informe).
