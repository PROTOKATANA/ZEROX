# ORDEN-DS2 — Matriz ataque × mecanismo para ZEROX, con costes absolutos y veredictos

## 1. Identidad y contexto

- **ID:** DS-2. **Fecha:** 2026-09-26. **Director:** Claude. **Ejecutor:** subagente Sonnet
  (análisis; sin código salvo aritmética de comprobación en Julia si hace falta). Se lanza cuando
  DS-1 esté revisada. **Marco obligatorio:** `P-ZRX/P-DISUASION/MARCO.md` (catálogos §2–§3,
  dimensiones §4, veredictos §5).
- **Zona (única escribible):** `/home/katana/zeo/ZEROX/deepseek/DS2/`.
- **Objetivo único:** para cada par (ataque A1…A12, mecanismo M1…M6, F1…F5, O1…O5), decidir el
  veredicto I / E-exigible / E-condicionado / N / W **frente a B0 y frente a B1**, con la fórmula del
  coste incremental de X en cada dimensión del §4 y su coste para el honesto; y especificar el modelo
  cuantitativo que calculará DS-3.
- **Pregunta falsable:** «Al menos un mecanismo de PoStake o de Filecoin encarece de forma
  **exigible** uno de los ataques A1, A3, A4 o A5 frente a B0.» Se confirma o se refuta celda a celda.

## 2. Entradas (leer antes de escribir una sola celda)

- El marco; el informe de DS-1 y su revisión.
- Evidencia previa de ZEROX (solo lectura): `.trash/zerox/P-ZRX/T-ZRX/ESTADO-DOBLE-FARMEO.md` (las ocho
  vías cerradas), `.trash/zerox/P-ZRX/T-ZRX/AGUJEROS-Y-SOLUCIONES.md`, `R-ZRX/LEGADO/stake/MAPA.md`
  (P-STAKE: «disuasión = P(descubierto) × valor en juego»), los informes de `.trash/zerox/P-ZRX/`
  `P-CLAVE`, `P-PRESTAMO`, `P-EQUIVOCACION`, `P-POOLS`, `P-SEMBRADOR`, `P-INTENTO`, `P-COBERTURA`,
  `P-SELLO`, `P-TASA`, `P-RIVAL`, `P-IDENTIDAD` (carpeta `investigacion/` de cada uno);
  `D-ZRX/RFT-ZRX.md` (RFT-01…RFT-13) y `D-ZRX/IPA-ZRX.md` (familias A, C, D, X).
- Estado del híbrido: `P-ZRX/P-TRANSICION/CONTRATO-v0.md`, `P-ZRX/P-DAG/CONTRATO-ESTADO-DAG-v0.md`,
  `D-ZRX/SPEC-0.0.1.md`; sectores: `P-ZRX/P-REGISTRO-SECTORES/` (análisis, encargos 01–05, informes S01
  y S02a); medidas: `P-ZRX/P-POW/REVISION-A10-M1.md`.

**Regla del mandato:** antes de proponer que un mecanismo encarece un ataque que una refutación
anterior dio por cerrado, **responde por escrito si el mecanismo elimina exactamente la premisa
explotada**; si no la elimina, la celda hereda la refutación con su alcance.

## 3. Lo que tiene que contener

1. **Matriz** completa (ataque × mecanismo, frente a B0 y frente a B1) con veredicto y una línea de
   motivo por celda; las celdas E con la fórmula del Δ de coste de X por dimensión y el coste del
   honesto.
2. **Análisis detallado** de A1 (doble farmeo), A3 (sembrador), A4 (Sybil), A5 (espacio ajeno), A7
   (largo alcance) y A8 (transición): qué parte del coste es exigible, cuál depende de detección, y si
   X puede **trasladarlo** (p. ej. obtener los tokens minando el prefijo PoW: acoplamiento A8 ↔ M1,
   con las cifras de A10-M1).
3. **Efectos adversos** (A12 y exclusión de honestos, IPA C-07) de cada mecanismo que salga E.
4. **Especificación del modelo para DS-3:** variables, fórmulas cerradas, parámetros con rango de
   escenario **declarado como hipótesis** (precio del token, `q`, `S_min`, tipo de interés, precio por
   TB, precio de la energía, cifras medidas de A10-M1 y de S02a), y los casos de comprobación que el
   Monte Carlo debe reproducir.
5. **Respuesta a la pregunta de Katana** en una tabla corta: mecanismo → problema que resuelve o
   encarece → cuánto (orden de magnitud absoluto) → exigible o condicionado → recomendación de
   evaluación siguiente.

## 4. Límites

Solo lectura fuera de tu zona. **No lances subagentes ni forks.** Sin git; sin Python; sin
credenciales. Distingue **hecho**, **derivación** e **hipótesis**; ninguna cifra sin procedencia.
Presupuesto: 3 h. Entregable: `deepseek/DS2/INFORME.md` (y `MODELO.md` con el §3.4).

## 5. Complemento tras la revisión de DS-1 (obligatorio)

1. Lee `P-ZRX/P-DISUASION/REVISION-DS1.md` y `P-ZRX/P-DISUASION/resultados-DS1/INFORME.md`.
2. **Descarga con `curl` a tu zona y lee con el lector de PDF** (no con la herramienta web, que no los
   renderiza): el artículo completo de Baig y Pietrzak (`https://arxiv.org/pdf/2505.14891`), SpaceMint
   (Park et al., FC 2018) y, si lo encuentras, el de consumo eléctrico de Filecoin que DS-1 no pudo leer.
3. **Pregunta nueva, antes de la matriz:** según Baig y Pietrzak, ¿qué «supuestos adicionales» escapan a
   su imposibilidad? ¿El PoT de un solo flujo de ZEROX (D-P10) o su finalidad `C-FIN-01` son de esa
   clase? Responde con citas del artículo y di qué cambia para A1 y A7.
4. Las celdas de SpaceMint que dependan de la lectura directa pasan de [S] a [P] solo si leíste el PDF.
