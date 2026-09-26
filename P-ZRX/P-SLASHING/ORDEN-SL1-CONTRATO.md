# ORDEN-SL1 — Contrato de evidencia y castigo v0 y especificación del firmante seguro

## 1. Identidad y contexto

- **ID:** SL-1. **Fecha:** 2026-09-26. **Director:** Claude. **Ejecutor:** subagente Sonnet (diseño y
  análisis; sin código de producto; aritmética de comprobación en Julia si hace falta, nunca Python).
- **Zona (única escribible):** `/home/katana/zeo/ZEROX/deepseek/SL1/`.
- **Objetivo único:** convertir las reglas **propuestas** `C-EVP-01…06` y `C-SLA-01…04` de `D-ZRX/SPEC.md`
  §5 en un **contrato ratificable** para el híbrido actual (`CONTRATO-EVIDENCIA-v0.md`), con cada regla
  precisa, verificable y probada por un caso, y en una **especificación del firmante seguro**, sin decidir
  parámetros numéricos (los calibra SL-2).
- **Pregunta falsable:** «Existe un conjunto de reglas de evidencia y castigo que (a) castiga toda doble
  firma demostrable una sola vez por incidente, (b) no castiga nunca a un productor que usa el firmante
  seguro, ni siquiera tras reiniciar o reorganizar, y (c) no deja a un infractor retirar su garantía antes
  de que la evidencia pueda llegar.» Se refuta con un contraejemplo concreto a (a), (b) o (c).

## 2. Entradas (leer íntegras)

`P-ZRX/P-SLASHING/PROGRAMA.md`; `D-ZRX/SPEC.md` §5 (`C-EVP-*`, `C-SLA-*`) y §7; `D-ZRX/IPA-ZRX.md` (C-01…C-09);
`P-ZRX/P-DISUASION/SINTESIS.md` y las revisiones DS-2, DS-3, DS-5 y DS-6; `P-ZRX/P-TRANSICION/CONTRATO-v0.md`;
`P-ZRX/P-DAG/CONTRATO-ESTADO-DAG-v0.md`; `P-ZRX/P-FORMATO/FORMATO-v0.md` (con v0.1; la versión 4 reservada);
`D-ZRX/SPEC-0.0.1.md`; de `.trash/zerox/P-ZRX/` (solo lectura): `P-EQUIVOCACION/investigacion/` (en
especial `FALSOS-POSITIVOS.md` y `DEFINICION-PROPUESTA.md`), `P-FIRMANTE/` (especificación y prototipo),
`P-PRESTAMO` y `P-CLAVE` (informes); del código antiguo, con `git show 9681061:<ruta>`:
`crates/zx-consensus/src/firmante/{mod,alta,identidad,registro}.rs`.

## 3. Decisiones del director (no se reabren)

1. **Única falta castigable en v0:** la doble firma de `C-EVP-02` (dos cabeceras con la misma identidad de
   oportunidad de `C-EVP-01`, contenidos distintos, sellos válidos). Nada de ausencias.
2. **Sin castigo correlacionado:** `C-SLA-03` se sustituye por una pérdida **no correlacionada** (fracción
   fija de la garantía expuesta, parámetro para SL-2). Justificación: DS-5.
3. La evidencia es una transacción **v4** comprometida en `txid`, Merkle o `body_commitment` y peso (como
   exige `C-EVP-03`), sin entradas ni salidas monetarias.
4. Congelación y confiscación son consecuencias **distintas**; suspender la elegibilidad no es confiscar.

## 4. Lo que tiene que contener el contrato

1. **Formato de `EvidenceTx` (v4):** campos, orden canónico de las dos cabeceras, tamaño máximo, dominio del
   identificador de incidente, qué entra en el `txid`; cómo rechaza la forma lo mal formado.
2. **Verificación:** qué comprueba el motor (identidad común, contenidos distintos, sellos ZIP-215, rama),
   con qué coste de CPU acotado, y qué **no** necesita (reconstruir la rama perdedora, garantía histórica).
3. **Incidente único y deduplicación**, también en el DAG (`C-ORD-03`, modo fusión: la segunda evidencia del
   mismo incidente queda inerte sin invalidar su bloque; aplicación única aunque haya reorganizaciones).
4. **Plazo y disponibilidad:** ventana de admisión frente a `F_slots`, `R_slots` y la finalidad `C-FIN-01`;
   qué pasa si la evidencia llega tarde; la desigualdad `R_slots > plazo + margen` escrita con sus símbolos.
5. **Consecuencias:** congelación inmediata de la garantía del infractor (qué partes: activo, pendiente,
   en retirada, créditos de coinbase no maduros), confiscación de una fracción `f` (símbolo), **destino de
   los fondos** (quemar, recompensar a quien incluye, mezcla) con el análisis de incentivos de cada opción
   (inclusión, censura de evidencia, denuncia repetida, autodenuncia para recuperar algo); qué pasa con una
   clave sin saldo (A12, «la grieta»).
6. **Retiro:** cómo interactúa con retiros y liberaciones en curso (una retirada no escapa al castigo si la
   falta es anterior).
7. **Reorganización y undo:** la evidencia y sus efectos se deshacen exactamente con su bloque.
8. **Firmante seguro (`C-EVP-06`):** qué persiste antes de firmar (identidad de oportunidad y hash de lo
   firmado), cuándo se niega a firmar, recuperación tras caída a mitad de escritura, copias de seguridad y
   el caso de la misma clave en dos máquinas (riesgo que el firmante **no** puede evitar y hay que declarar);
   qué se toma del código antiguo y qué cambia.
9. **Falsos positivos:** catálogo de causas honestas de doble firma (cosechadoras redundantes, reinicio con
   pérdida de estado, reempaquetado, restauración de copia, dos máquinas) y cuáles elimina el firmante y
   cuáles no; esto es la entrada de SL-2.
10. **Lista de casos** que el oráculo de SL-3 tendrá que reproducir (positivos, negativos y adversariales:
    evidencia duplicada, evidencia de otra rama, evidencia tardía, evidencia contra clave sin saldo, cabeceras
    iguales, firmas inválidas, identidades distintas, reorganización que saca la evidencia).
11. **Parámetros abiertos** que calibra SL-2, cada uno con su símbolo y su restricción.

## 5. Entregable y límites

`deepseek/SL1/CONTRATO-EVIDENCIA-v0.md` (reglas numeradas `EV-*` y `FIR-*`, cada una con su justificación y
su caso) y `deepseek/SL1/INFORME.md` (respuesta a la pregunta falsable, decisiones que el director tiene que
tomar, con opciones, coste de cada una y recomendación). Solo lectura fuera de la zona. **No lances subagentes
ni forks.** Sin git; sin Python; sin credenciales. Distingue hecho, derivación e hipótesis. Presupuesto: 3 h.
