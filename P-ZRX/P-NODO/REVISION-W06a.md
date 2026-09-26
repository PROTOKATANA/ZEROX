# REVISIÓN W06a — `zx-cadena` y correcciones del modo fusión

**Revisor:** Claude (director). **Fecha:** 2026-09-26. **Ejecutor:** DeepSeek, 04:11–04:59.
Evidencia: `resultados-W06a/` (el `cambios.patch`, 5 MB, queda en `deepseek/W06a/`).

**Veredicto: SUPERADO CON RESERVA. Migrada.** El código (`zx-cadena`, correcciones RI-1a en
`fusion.rs`) entra en la raíz; el diferencial contra T04 queda **provisional** hasta W06a-B.

## Migración

Base del ejecutor = raíz de las 04:11; después entró W05b3 (solo `crates/zx-post`, que W06a no toca).
Se aplicó `cambios.patch` con `git apply --check` limpio y se verificaron **151** huellas de
`MIGRACION.sha256` (todas salvo las 16 de `crates/zx-post`, que en la raíz son las de W05b3). **La
combinación W05b3 + W06a no la ha compilado ni probado nadie todavía**: su primera ejecución completa
será el V3 de W06a-B.

## Comprobado por el director

- `ENTRADA-W06a.sha256` 23/23. Lock: solo `zx-cadena` añadido, sin cambios de versión.
- `fusion.rs`: RI-1a #1 (`slot = punto` en todo bloque fusionado; `peso_sufijo` lo suma `zx-cadena`
  solo por bloques de cadena) y RI-1a #2 (`fusion_pow` eliminado; un bloque PoW en modo fusión ⇒
  `ErrOperacionFase`; génesis ⇒ `ErrGenesis`). También RD-2 (coinbase PoST opcional) y RD-10.
- Informe: 635 pasan, 0 fallan; `diferencial_t01` y negativos siguen en 0; `diferencial_t04`
  913/913 casos sin discrepancias; cobertura del arnés idéntica a `cobertura-v0.2.txt`.

## Reserva: el arnés emula un artefacto del oráculo

El oráculo T01 da a la salida de una liberación el id `prox_salida` (contador que salta al mayor id
explícito + 1); el generador de T04 asigna los ids de las transferencias con otro contador. Entre
ramas, un id de liberación y uno de transferencia pueden coincidir y T01 descarta la transferencia con
`ErrDobleGasto` al crear la salida. Con F-18 (`(txid, 0)`, único por contenido) esa colisión **no
existe** en el formato real. Para igualar al oráculo, `detectar_colisiones` y `forzada` en
`crates/zx-cadena/tests/diferencial_t04.rs` **añaden una entrada inexistente** a esas transferencias:
el motor las descarta por otra causa real y el motivo coincide. Está declarado, pero en esos casos
el diferencial prueba el arnés, no el motor. El ejecutor propone arreglar el contador del generador;
**no basta**: dos ramas pueden asignar el mismo contador a liberaciones distintas. La causa es de
modelado y se corrige en el oráculo (`ORDEN-T01E-T04D`): id de la salida de la liberación como función
inyectiva del contenido de la operación, como F-18.

## Otros límites declarados por el ejecutor (aceptados)

`Estado(past(V))` se reconstruye en `O(N²)` con un almacén temporal (no es la ruta de red; IPA B-12);
`propiedades.rs` solo usa coinbases PoST y `q = 0` (las garantías las cubre el diferencial); la
garantía del productor se calcula desde campos públicos sin `Aplicador::promover`.
