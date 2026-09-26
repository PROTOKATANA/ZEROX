# REVISIÓN SL-3b — correcciones del oráculo de evidencia

**Revisor:** Claude (director). **Fecha:** 2026-09-26. **Ejecutor:** DeepSeek, 19:15–19:28. **Veredicto:
SUPERADO.** Los vectores de referencia para SL-4 son `vectores-transicion-v0.4.txt` (T01, 2 795 casos) y
`vectores-estado-dag-v0.5.txt` (T04, 1 878 casos), con su cobertura.

- **RAT-2′:** recompensa `suelo(C·2/8) = C ÷ 4`; test para todo `C` de 0 a 1 000: el infractor pierde
  `≥ 6/8·C` (exacto en enteros).
- **Cobertura de T04:** «contra clave sin saldo» 80 (≥ 30); «deshecha» redefinida como aplicada en la
  historia seleccionada y retirada por una reorganización: 115 (≥ 30); definiciones escritas.
- **T01:** barrido dedicado de 5 060 historias con evidencia además de las 737 280 del principal; 0 fallos.
- `Pkg.test()` T01 2 178/2 178, T04 422/422; relectura de los vectores nuevos con 0 discrepancias.
- Los vectores anteriores (T01 v0.3, T04 v0.4) siguen intactos pero **ya no se releen** bajo RAT-2′ (difieren
  en lo quemado y la recompensa): es el efecto buscado; quedan como históricos.
