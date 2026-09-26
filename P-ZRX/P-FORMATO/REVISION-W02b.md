# REVISIÓN W02b — FORMATO v0.1 (F-15…F-18) en formato, motor, productor y oráculo de formato

**Revisor:** Claude (director). **Fecha:** 2026-09-26. **Ejecutor:** DeepSeek, 03:35–04:09.
Evidencia: `resultados-W02b/` (informe, progreso, registros, parche, huellas); oráculo migrado a
`P-ZRX/P-FORMATO/oraculo-formato-v0.1/`.

**Veredicto: SUPERADO. Migrada** a la raíz (base comprobada idéntica; `MIGRACION.sha256`, 155
archivos, verificado en la raíz; lock idéntico; 0 borrados).

## Comprobado por el director

- `ENTRADA-W02b.sha256` 47/47 al terminar (también lo registra el ejecutor al empezar y al terminar).
- Informe: 630 tests pasan, 0 fallan, 1 ignorado (el previo); 0 perdidos, 10 añadidos; diferencial
  v0.1 con **0 discrepancias** en 2 055 casos base (1 947 con PoST) y en **3 939 negativos**
  (2 024 `ErrNonce`); oráculo de formato v0.1 `Pkg.test()` 85/85 con los v1 no-coinbase idénticos a v0.
- Cambio de forma leído (`crates/zx-core/src/forma.rs`): la exención de `expiry_height ≠ 0` es solo
  para `version == 1` sin entradas (candidata a coinbase PoW); el resto sigue con `ErrCampoInactivo`.

## Decisiones del ejecutor que el director ratifica (FD-1…FD-7 en `PROGRESO.md`)

- **FD-1** (exención F-16 en la forma, igualdad en el motor): correcta; la forma no conoce la altura.
- **FD-4** (F-17 compara con el slot del bloque que **contiene** la v3, no con el punto de aplicación
  en fusión): correcta; la madurez del crédito sigue el punto de aplicación (RD-1).
- **FD-6** (el oráculo de formato no modela F-16): correcta.
- **FD-7** (negativos de T01): se añade la correspondencia `ErrForma(DepositoSinEntradas) ↔
  ErrAutorizacion` (75 casos, todos `ent=[]` con firmante ajeno) y el espejo del contador
  `prox_salida` ↔ `(txid, 0)` para la salida de la liberación. **Alcance de la primera:** solo modo
  estricto, donde ambas invalidan el bloque. En el DAG manda `CONTRATO-ESTADO-DAG-v0.md` §3: la forma
  (F-03…F-10) invalida el **bloque**, mientras que el oráculo abstracto la vería como descarte. T04 no
  genera depósitos sin entradas, así que W06a no la ejercita; queda escrito para que nadie la extienda
  al modo fusión.

## Error del director que destapa W02b

W03 nunca consumió los vectores **negativos** de T01 (3 939 casos) y `REVISION-W03` no lo señaló. Al
correrlos aparecieron 93 discrepancias de arnés (no de motor). Es el tercer caso de la noche de
aceptar una verificación sin comprobar **qué entradas recorre** (T04 sin retiros, fusión sin `slot`,
W03 sin negativos).
