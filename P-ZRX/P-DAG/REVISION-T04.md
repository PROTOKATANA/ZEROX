# Revisión del director — T04 (2026-09-26)

**Veredicto: SUPERADO.** DeepSeek, 02:27–02:48. Oráculo Julia del estado DAG en
`P-ZRX/P-DAG/T04/`.

- GDR-v0.2 revalidado exacto antes de construir encima (28 DAGs / 2 290 bloques y fixtures kaspa,
  0 discrepancias).
- 8 casos dirigidos con resultado construido a mano; 3 000 historias aleatorias (25 380 bloques
  PoST, 1 977 descartes, 1 374 `rojo_U3`, 673 650 órdenes de llegada): 0 fallos en IE-1…IE-6;
  `Pkg.test()` 361/361.
- 908 vectores exportados (`resultados/vectores-estado-dag-v0.txt`, sha256 `29096f74…4af84`),
  releídos sin discrepancias.
- **Diez ambigüedades** documentadas antes del código; ratificadas como RD-1…RD-10 en
  `CONTRATO-ESTADO-DAG-v0.md`. **RD-4 corrige un error del director**: el contrato aplicaba `sp(B)`
  en `slot(B)` y eso contradecía su propio IE-5.
- Dependencia de T01 por `include` de solo lectura (declarada).

**Límites:** abstracción sin criptografía ni red; `max_parents = 3` en el oráculo.
