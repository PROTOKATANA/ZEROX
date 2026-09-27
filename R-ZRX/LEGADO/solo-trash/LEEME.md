# R-ZRX/LEGADO/solo-trash — archivos que solo existían en la papelera

**Copiado:** 2026-09-27 (≈ 07:05), por decisión de Katana (PK-02, respuesta del 2026-09-27). **Firma:** Claude.

**Qué es.** Los 90 archivos de `/home/katana/zeo/.trash/zerox/` cuyo **contenido** no está en ningún commit del
repositorio (comprobado con `git hash-object` + `git cat-file -e` contra todos los objetos del repositorio,
excluyendo `target/`, `PDF/`, depósitos de Julia y cachés). El recuento anterior de «95» (IPA E-07) era por
ruta; la diferencia son las fuentes ya copiadas a `R-ZRX/LEGADO/{reloj,eclipse,stake}/` y otras cuyo contenido
ya estaba en git con otra ruta.

**Reparto:** `P-ZRX/P-RELOJ/` (47), `P-ZRX/P-ECLIPSE/` (34), `P-ZRX/P-STAKE/` (5), `P-ZRX/P-VIVEZA/` (2),
`P-ZRX/PROPUESTAS-VIABLES.md` y `TAREAS.md`. Incluye un binario de medición
(`P-ZRX/P-RELOJ/investigacion/mediciones/latencia-aes/aesinst`, 20 KB), conservado como evidencia.

**Procedencia e integridad.** `HUELLAS-ORIGEN.sha256` lleva la huella de cada archivo en la papelera; la copia
las reproduce todas (`sha256sum -c HUELLAS-ORIGEN.sha256` desde esta carpeta). Se revisaron nombres y contenido
en busca de credenciales antes de copiar: ninguna.

**Estado: material histórico, no normativo.** No se promueve a `V-ZRX/` por estar aquí; cualquier cifra o
conclusión de estos archivos se clasifica según `AUTO-ZRX.md` §2 antes de usarse.
