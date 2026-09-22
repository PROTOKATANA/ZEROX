# DECISIONES-PENDIENTES — P-IDENTIDAD

Bifurcaciones **reales** para Katana. Ninguna fila es una regla propuesta: el SPEC lo redacta Claude y
lo decide Katana. Cada fila dice qué decide, qué gana con cada opción, qué paga y qué **no** cierra.
Rutas desde `/home/katana/zeo/ZEROX`.

---

## D1 · Qué identidad de billete: A (`C-GD-07`), B (IDV-01) o C (candidata)

**Es la decisión del encargo, y este trabajo cambia su precio.**

| opción | qué gana | qué paga | qué **no** cierra |
|---|---|---|---|
| **A · vigente** `(pk, sector, historia, chunk, slot)` | nada nuevo; **cero migración** | la evidencia de doble farmeo **en el régimen de flujo divergente con piezas distintas**; ya es más gruesa que la clave de Autonomys (omite `piece_offset`) | el escape con retos divergentes (que en la práctica es escapar con **otra pieza**) |
| **B · IDV-01** `(dominio, slot, pk, sector, historia, piece_offset)` | **dentro de una historia, idéntico a A** (medido); entre ramas, agrupa las copias de la misma pieza y deja evidencia cuando el atacante **no puede** elegir otra pieza: `P` = 1,000 / 0,101 / 0,013 / 0,000 / 0,006 para `P` = 1/4/16/32/1000 | (i) rompe el invariante de `C-FLU-12`; (ii) abre invalidación en cascada mientras `C-GD-10` no descarte puntas que violan U2 (hasta 65 % de bloques no válidos con equivocación total, medido); (iii) activación de consenso | publicar solo la rama ganadora; la carrera del ancla; el alquiler exclusivo; el grinding de pruebas alternativas; **el bloqueante de IDV-01** (retos/raíces alternativos del mismo slot) |
| **C · candidata** `H(dominio, slot, PlotBatchId, sector, piece_offset)` | como B en la partición (`EN`: idéntico en el juguete) | **lo mismo que B** más un aparato entero: registro de parcelas, maduración, retención y auditorías (`SOLUCION-CANDIDATA-REUTILIZACION.md`) | `PlotBatchId` **no existe**; el paquete de permanencia no está comprobado (`C2` de su anexo, `no verificado`) |

**Lo que este trabajo aporta a la decisión.** El cambio no es «cerrar por construcción un problema que si
no exige un mecanismo entero», como dice `MEJORA-IDENTIDAD-DE-BILLETE.md` §1: dentro de una historia A ya
comporta igual que B, y fuera de ella B solo muerde en una fracción pequeña (y decreciente con
`pieces_in_sector`) de un régimen que a su vez requiere ganar la carrera del ancla. **El ahorro que
justificaba el encargo es mucho menor que el supuesto, y su precio (invariante de `C-FLU-12` + cascada de
`C-GD-10`) es nuevo.**

**Quién decide:** Katana (consenso). **Bloqueante hoy:** el mismo que IDV-01 declara
(`veritas/consenso/identidad-disponibilidad-v1/CONTRATO-VALIDACION.md:34-37`), y B **no** lo levanta.

---

## D2 · `pieces_in_sector` (`P`) como parámetro de seguridad, no de rendimiento

**Qué falta:** la distribución real de piezas por sector en parcelas reales. El código fija el **tope**
(`MAX_PIECES_IN_SECTOR = 1000`, `subspace-runtime/src/lib.rs:124-125`; 32 en el runtime de test), no la
distribución.

**Por qué importa:** el único beneficio de B frente a A escala como `1/P` (`P(forzado)` de
`INFORME.md` Resultado 12). Una red de parcelas pequeñas (P pequeño) haría B mucho más eficaz; una de
parcelas llenas (P = 1000) lo hace casi inerte.

**Decide:** Katana. **Sin dato de distribución, la cifra de sistema es `no determinada`.**

---

## D3 · ¿Se adopta B sin reescribir el invariante de `C-FLU-12`?

`C-FLU-12` exige que **dos copias del mismo billete** produzcan la misma entropía. Bajo B/C eso deja de
ser un teorema y pasa a ser falso en el caso medido (`flujo-divergente-misma-pieza`). Opciones:

| opción | qué implica |
|---|---|
| **Reescribir el invariante** atándolo a la **oportunidad** (`pk, sector, historia, pieza, slot`) y no al billete | conserva el propósito (no-equivocación del inyector) y reconoce que la entropía de B no distingue `chunk`; hay que rehacer el análisis de grinding que el invariante protegía |
| **Imponerlo** por regla (p. ej. exigir un `chunk` canónico por oportunidad) | es una regla **nueva**, no una consecuencia del cambio; hay que decidir canonicidad y coste de verificación (`IDENTIDAD.md` §4 lo prohíbe explícitamente para `proof_hash`) |
| **Aceptar el caso y declararlo** | el coste es «la misma identidad puede anclar dos entropías»; **no se ha encontrado ataque y no encontrarlo no es cerrarlo** |

**Decide:** Katana. **Bloqueante para adoptar B sin dejar el SPEC incoherente.**

---

## D4 · ¿Se amplía la lista de descarte de `C-GD-10`?

Hallazgo de este trabajo (`INFORME.md` Resultado 7): `C-GD-10` obliga a descartar puntas que violarían
`C-GD-11`, `slot` y `C-FLU-20`, **pero no U2**. Con A el hueco es inocuo; con B/C cualquier bloque que
tome como padres dos copias de la misma pieza se vuelve inválido y arrastra su descendencia (medido:
4 660 y 31 015 bloques en las corridas de `MC-D`).

| opción | qué implica |
|---|---|
| **Añadir U2 a la lista** | cierra el agujero de producción; no cambia la validación (un verificador ya rechaza esos bloques) |
| **Dejarlo** | el productor honesto puede emitir un bloque inválido por su elección de padres — contra la frase del propio §11 |

**Decide:** Katana / redacción de SPEC. **Es requisito de B, no de A.**

---

## D5 · La tasa real de flujos divergentes (`equivoca`)

**Qué falta:** la probabilidad de que un productor tenga dos vistas con retos distintos en el mismo slot.
`P-EQUIVOCACION` P4/P5 da la **condición** (`n_priv > n_com` dentro de `V_j`), no la probabilidad; `L`,
`δ` y `α` no están medidos.

**Por qué importa:** sin ella no hay cifra de sistema para el beneficio de B (Resultado 12) ni para su
coste (Resultado 6). Todo lo que este informe da es una **función**, no una cifra.

**Decide:** Katana (medir o declarar limitación permanente).

---

## D6 · ¿Se obliga al productor a un filtro anti-equivocación (C3 de `CANDIDATA.md`)?

Un granjero con dos nodos o *harvesters* sobre la misma parcela, o que reinicia perdiendo estado, puede
firmar la misma oportunidad dos veces **sin mala fe**. Con A el daño es pequeño (0,00–0,38 % medido);
con B/C es severo (hasta 65 %). La mitigación es un registro persistente por (lote, slot) en el
productor.

**Decide:** Katana. **Es coste de producción de B, no de consenso.**

---

## D7 · ¿Se cambia la tupla de `C-GD-07` para incluir `piece_offset` **sin** quitar `chunk`?

La clave de Autonomys es `(pk, sector, piece_offset, chunk, slot)`: **las dos**. Una cuarta opción,
**A′**, añadiría `piece_offset` a A sin quitar `chunk`. Por E2/E3 tiene el mismo comportamiento que A
**dentro** de una historia y **no** agrupa nada entre ramas (el `chunk` distinto ya separa) — es decir,
**A′ ≈ A** en todo lo medido, y cierra la discrepancia con la referencia.

**Qué falta:** comprobar si A′ aporta algo que A no tenga (no encontrado en este trabajo: `propuesto`
como no-ganancia).

---

## D8 · Qué hacer con los bloques ya producidos bajo A

Si se adopta B/C, la validación cambia y un replay puede invalidar bloques que eran válidos. Es un
cambio de consenso del §14, no una relectura de datos: **decidir la vía de activación** (bloque de
activación, altura, o activación por rama `consensus_branch_id`, que ya existe y `MUST` ser exactamente
la rama activa, `C-HDR-02b`).

**Decide:** Katana.

---

## Lo que este encargo **no** deja pendiente

- Si A y B particionan igual dentro de una historia: **sí, demostrado y enumerado** (no es una opinión).
- Si el cambio pierde bloques honestos en una red honesta: **no, medido 0**.
- Si el cambio cambia el pago dentro de una historia: **no, medido idéntico**.
- Si el cambio rompe el invariante de `C-FLU-12`: **sí, medido** (D3).
- Si `C-GD-10` cubre la producción bajo B: **no** (D4).
- Si B necesita el registro de parcelas: **no**; C **sí**.
