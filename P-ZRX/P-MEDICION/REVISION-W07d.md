# REVISIÓN W07d — registro del estado final

**Revisor:** Claude (director). **Fecha:** 2026-09-27 (≈ 17:47). **Ejecutor:** DeepSeek, 16:46–17:44. Evidencia:
`resultados-W07d/`. **Veredicto: SUPERADO. Migrada** (7 archivos de `crates/zx-node/`; base sin cambios desde
`20214cb`; 7/7 huellas). **Solo registro:** ni reglas ni tubería.

- `reinicio_completo` y `parada` (críticos) llevan `punta`, `resumen_estado` del estado virtual **final** (tras toda
  la repetición, o en el momento de parar), `n_bloques_dag` y `compendio_bloques` (SHA3-256 de los hashes de todos
  los bloques persistidos, ordenados): comparar nodos deja de depender de cuándo se escribió el último `cambio_punta`.
- Parada ordenada con `SIGTERM`/`SIGINT` (manejador mínimo con `signal(2)`, solo un indicador atómico; `unsafe`
  confinado en `parada.rs` y revisado por el director); `bloque_transicion_producido`.
- `fmt`, `clippy -D warnings`, **868/0/6**, T01/T04 en verde, guardianes. Límites declarados: el determinismo del
  compendio se probó sobre las funciones, no con dos procesos; `parada` por señal probada en fase PoW (en PoST, en
  proceso). Primera compilación con 8 hilos unos minutos (declarado).
- **Uso:** las mediciones de W07b se hicieron con `26312ff`; el veredicto de «mismo estado» de cada repetición se
  obtiene con **este** binario, reabriendo cada nodo aislado sobre sus `datos` guardados (`reinicio_completo`).
