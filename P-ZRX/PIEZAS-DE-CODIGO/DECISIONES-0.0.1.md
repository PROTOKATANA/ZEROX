# Decisiones de ZEROX 0.0.1

No hay valores de consenso nuevos decididos. Los parámetros `<<PENDIENTE>>` del SPEC no se fijan aquí. Se registrarán con el formato de `PROMPT.md` §4 las decisiones que bloqueen una pieza y, en régimen desatendido, cualquier elección provisional, su fundamento, aislamiento y reversión.

La discrepancia aritmética de 17 frente a 18 piezas no es una decisión de protocolo: se conservan las 18 casillas enumeradas. La frase introductoria desactualizada de `SPEC.md` §6.1 tampoco modifica C-HDR-01; requiere corrección editorial posterior fuera de la zona de trabajo.

## DECISIÓN NECESARIA · CI-A1

**Pieza bloqueada:** A1, cierre de §8.1 y guardián `ci/alcance-consenso.sh`.

**Descripción:** A1 añade `zx-consensus::poas::verificar_solucion_poas` como función pública deliberadamente no cableada hasta C1/B3. El guardián exige declararla en `ci/consenso-pendiente.txt`. Además, el enlace por ruta a los crates del clon fijado requirió modificar `Cargo.toml` de la raíz y regenerar `Cargo.lock`; esos dos archivos **ya fueron modificados por DeepSeek** y la orden A1 los declaró, pero `PROMPT.md` §8 solo permite escribir en `crates/` y `P-ZRX/PIEZAS-DE-CODIGO/`. Fue un error del líder autorizar esos archivos en su orden sin resolver antes el límite del encargo. Los tres archivos quedan fuera de la zona original.

**Opción A · Excepción mínima para dependencias e inventario de CI**

- Ventajas: conserva el enlace necesario a la API auditada, deja explícita la integración pendiente y permite pasar el guardián y cerrar A1 con trazabilidad.
- Desventajas: conserva dos archivos ya modificados fuera de la zona original y añade un tercero; exige inspección individual de sus diffs.
- Descripción: permitir solo `Cargo.toml`, `Cargo.lock` y `ci/consenso-pendiente.txt`. Los dos primeros registran exclusivamente las exclusiones de workspace y dependencias de A1; en el tercero, añadir la función con motivo y fase C1/B3. No alterar scripts, otras listas ni reglas.

**Opción B · Mantener la zona estricta**

- Ventajas: recupera literalmente el límite de archivos original.
- Desventajas: exige retirar los cambios de manifiesto y lock escritos por DeepSeek, A1 deja de compilar con dependencias por ruta y queda sin cerrar; el guardián sigue rojo mientras la función sea pública y huérfana.
- Descripción: revisar y revertir solo los cambios de DeepSeek en esos dos archivos, sin `git reset` ni borrar trabajo ajeno; mantener el resto como trabajo pendiente o rediseñar el enlace a Autonomys antes de marcar casilla.

**Recomendación:** A. El enlace por ruta requiere que Cargo resuelva el clon con su propio workspace; conservar los dos archivos hace reproducible la compilación. El inventario fue diseñado para registrar funciones de consenso aún no alcanzadas, exactamente esta situación. Los cambios son localizados y reversibles: las exclusiones y dependencias se retiran si se abandona el adaptador, y la entrada de CI se elimina cuando C1/B3 cablee la llamada. No fijan valores de consenso.

**Resolución del usuario (2026-09-24, «AFIRMATIVO»):** autorizada la opción A **solo para** `Cargo.toml`, `Cargo.lock` y `ci/consenso-pendiente.txt`. Se conservaron los dos primeros y se añadió a la lista la entrada `zx-consensus::poas::verificar_solucion_poas` con motivo y fase C1/B3. `ci/alcance-consenso.sh` y `ci/citas-spec.sh` pasan. No se autorizó editar otros archivos fuera de la zona original; `TAREAS.md` y `P-ZRX/P-ECLIPSE/` son trabajo concurrente ajeno y quedan intactos.
