# REVISIÓN SL-4a — evidencia y castigo en formato, motor y cadena (Rust)

**Revisor:** Claude (director). **Fecha:** 2026-09-26. **Ejecutor:** DeepSeek, 19:30–20:58. Evidencia:
`resultados-SL4a/`. **Veredicto: SUPERADO. Migrada** por parche (22 rutas, base idéntica, `git apply --check`
limpio, 22 huellas verificadas; `crates/zx-node/` sin tocar; lock idéntico).

## Comprobado por el director

- `ENTRADA-SL4a.sha256` 9/9. Informe: suite 729/0/2 (721 antes; 8 añadidos, 0 perdidos);
  `diferencial_t01` (T01 v0.4, 2 795 casos) y `diferencial_t04` (T04 v0.5, 1 878 casos) con **0
  discrepancias** y cobertura **idéntica** a la de los oráculos; traducción real de cada evidencia a dos
  cabeceras con sellos Ed25519 reales, sin emulación.

## Lo que queda implementado

`EvidenceTx` v4 (`ExtensionTx::Evidencia`, forma, `txid` con dominio propio, identificador de incidente);
en el motor, incidentes, congelación, confiscación, recompensa `suelo(C·2/8)` y quema (RAT-2′), la ventana de
liberación y la puerta de RAT-3 (`ErrPuertaRAT3`), evidencia fuera de plazo, poda y undo exacto; en
`zx-cadena`, la evidencia en fusión como descarte que no invalida el bloque, aplicación única y reaparición
tras reorganización.

## Declarado y aceptado

- **FD-1:** el identificador de incidente del contrato (`H_d`, SHA3-256) y el del oráculo (SHA-256)
  difieren; el arnés compara la **identidad** del incidente (opaca), no los bytes del hash. Ningún contador
  depende del hash.
- **FD-8:** los parámetros de evidencia viven en `ParametrosEvidencia` (y `Cadena::nueva_con_evidencia`) para
  no tocar `zx-node`; la integración en el nodo y en el perfil dev es de **SL-4b**, que además tiene que
  llevar el firmante seguro al voto cuando exista la capa (FV-1, D4).
- La combinación con W06d4 (en curso, toca `zx-node` y `zx-post`) no se ha probado junta: la primera suite
  conjunta será la de la migración de W06d4.

## Corrección de la migración (22:15)

**Error del director:** la migración por parche no trajo los dos directorios de vectores que usan los
diferenciales de SL-4a (`testdata/transicion-v0.4/` y `testdata/estado-dag-v0.5/`): el parche de 22 rutas
solo contenía código. La raíz quedó con `diferencial_t01` y `diferencial_t04` sin sus datos. Lo detectó
W06d5 en su paso 0. Copiados desde `deepseek/SL4a/ws/testdata/`; los vectores son idénticos byte a byte a
las salidas de los oráculos (`T01/resultados/vectores-transicion-v0.4.txt`,
`T04/resultados/vectores-estado-dag-v0.5.txt`). Lección: al migrar por parche, comparar también
`testdata/` de la zona con la raíz.
