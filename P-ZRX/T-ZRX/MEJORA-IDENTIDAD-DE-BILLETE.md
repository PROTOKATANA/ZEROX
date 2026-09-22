# Mejora candidata: cambiar la identidad de billete

> ⚠️ **REBAJADA el 2026-09-21 — lee primero el §7 al final: su premisa es falsa dentro de una historia.**

**Fecha:** 2026-09-21 · **Origen:** `P-ZRX/P-PRESTAMO/investigacion/` (entregado y validado por Claude:
aritmética rehecha aparte, sin reejecutar su instrumento) · **Estado:** **candidata por comprobar**, no
implementable todavía. Lo comprueba `P-ZRX/P-IDENTIDAD/` (escrito, **sin lanzar**).

> **Qué la hace distinta de todo lo demás de este directorio:** no es un mecanismo nuevo. Es **un cambio
> de definición** que, si se sostiene, **haría innecesario el mecanismo de castigo entero**.

---

## 1 · El problema que resuelve

Una misma parcela puede farmear **a la vez** la rama pública y la rama privada de un atacante. Es
invisible y casi gratis, y de ahí sale el riesgo del **espacio prestado**: si se generaliza, el umbral de
seguridad se erosiona sin que nadie tenga que comprar un disco.

## 2 · Las dos salidas

| | **Hoy: identidad vigente** (`C-GD-07`, con `chunk`) | **Alternativa: identidad por pieza** (IDV-01 / candidata, con `piece_offset`) |
|---|---|---|
| Qué es farmear dos ramas | **dos oportunidades distintas**: el granjero **duplica** y eso **suma peso neto** al atacante | **la misma oportunidad dos veces**: es la infracción **por definición** |
| Qué puede hacer el granjero | duplicar | **solo repartir** su espacio entre ramas |
| Efecto en el umbral | baja a `(1 − β_d − 2β_x)/2`; **solo un castigo creíble lo sostiene** | repartir no da peso extra a nadie: **el umbral se sostiene sin depender del castigo** |
| Tipo de defensa | **económica** (disuadir con dinero) | **estructural** (por construcción) |
| Qué arrastra | evidencia publicable, censura de la prueba, sobornos, castigo accidental a honestos, vesting, firmante seguro | una **migración de regla** y sus efectos secundarios (§4) |

`β_d` = espacio honesto que trabaja en **ambas** ramas; `β_x` = alquilado en exclusiva. Cada unidad de
alquiler exclusivo baja el umbral **el doble** que una de doble farmeo (quita de la pública **y** suma a
la privada; el doble granjero solo suma).

## 3 · Por qué importa tanto

Una defensa económica siempre tiene grietas, y `P-ZRX/P-PRESTAMO/` las cuantificó: **no existe ninguna
combinación de retención y plazo** que valga frente a quien **publica solo la rama ganadora** (no deja
par de bloques: ninguna identidad lo alcanza), frente a **censura total de la prueba**, o frente a un
atacante cuyo beneficio no tenga cota. Una defensa estructural no depende de que el castigo se aplique.

Además, `P-ZRX/P-EQUIVOCACION/` midió que la identidad vigente, **por llevar `chunk`**, deja escapar dos
soluciones distintas de la misma pieza (su cobertura cae de 1,000 a 0,000 en ese escenario), mientras las
dos alternativas dan 1,000.

**Y el propio SPEC ya dejó la puerta abierta.** Al decidir D-F1 (`SPEC.md` §7.1.4, bloque «Decidido por
Katana el 2026-09-20») se escribió que el motivo que más pesaba era *«no atar §7.1 a la identidad del
billete (§7.2), que además **puede cambiar** si algún día se adopta un registro de parcelas contra el
sembrador»*. Allí mismo consta su coste: dos billetes distintos con el mismo `chunk`, en el mismo slot y
flujo, dan la misma entropía.

## 4 · Lo que NO está comprobado — por eso es candidata

1. **Qué se rompe.** De la identidad de billete cuelgan U2, U3″ dinámica, la unicidad pagable (P1) y su
   desempate, el conjunto de billetes consumidos y su reconstrucción en reorg, R-FIN-8′/13′ y el código
   de `crates/`. **Nadie ha hecho el inventario.**
2. **Cuántos bloques honestos se perderían.** Una identidad **más gruesa invalida más bloques**: un
   granjero honesto con dos soluciones en la misma pieza podría ver invalidado el segundo. Es el riesgo
   serio del cambio y no está medido.
3. **El alcance exacto del cierre.** «No aporta peso neto» vale dentro de **una historia**; entre **ramas
   disjuntas** las dos copias son válidas y azules cada una en la suya
   (`veritas/seguridad/coste-rama-privada-v1/INFORME.md` §6, medido contra GDR-v0.2). Si lo que cierra es
   «no suma al fusionar» pero no «no suma mientras las ramas están separadas», la conclusión necesita esa
   condición escrita.
4. **Cuánto vale.** Su beneficio se mide en umbral de seguridad, y **el umbral no tiene base**: ningún
   instrumento del repositorio conecta el espacio con la tasa de bloques (el defecto D4, abierto —
   `P-ZRX/P-CRP/auditoria/DEFECTOS.md` C1).
5. **Si la alternativa está lista.** IDV-01 está marcada **«condicionada»**
   (`veritas/consenso/identidad-disponibilidad-v1/CONTRATO-VALIDACION.md`), y la de la candidata exige un
   `PlotBatchId` que **no existe**.

## 5 · Lo que el cambio NO cierra

Publicar solo la rama ganadora · la carrera del ancla (`P-ZRX/P-EQUIVOCACION/` P4/P5) · el alquiler
exclusivo (`β_x`) · una mayoría real de espacio. Sigue sin ser exclusividad física del disco.

## 6 · Estado y siguiente paso

**Lanzar `P-ZRX/P-IDENTIDAD/`** (escrito, 4 hilos, no depende de nada). Contestará §4.1, §4.2 y §4.3, y
qué haría falta para migrar. **Dirá si se puede y a qué coste; no si conviene**: eso es decisión de
Katana, y el §4.4 seguirá abierto hasta que exista el puente espacio→tasa.

**Si sale que se puede**, el prototipo de `P-ZRX/P-PROTOTIPO/` deja de ser el paquete de castigo entero
y pasa a ser mucho más pequeño. Ése es el ahorro.

---

## 7 · ⚠️ REBAJADA el 2026-09-21 por `P-ZRX/P-IDENTIDAD/` — leer antes que todo lo anterior

**La premisa de §2 es falsa dentro de una historia.** `P-ZRX/P-IDENTIDAD/` midió que **las tres
identidades particionan IGUAL**, y la razón es un hecho del código fijado que ningún informe anterior
había usado: **`chunk` no es un grado de libertad independiente**. Un reto fija **un solo s-bucket** por
sector (`PDF/autonomys-subspace/crates/subspace-core-primitives/src/sectors.rs:33-39`) y cada pieza
aporta **a lo sumo un chunk** en ese bucket
(`PDF/autonomys-subspace/crates/subspace-farmer-components/src/sector.rs:582-608`). **Verificado por
Claude abriendo las dos fuentes.** Luego «dos soluciones de la misma pieza con `chunk` distinto en el
mismo slot» es **estructuralmente imposible** dentro de una historia, y con ello se cae la afirmación de
`P-ZRX/P-EQUIVOCACION/` de que la identidad vigente «deja escapar» esos casos.

**Qué queda del beneficio.** Solo el tratamiento de copias en **ramas disjuntas con flujos divergentes**,
y allí B/C agrupan **únicamente cuando gana la misma pieza**: `P(forzado)` medido 1,00 / 0,10 / 0,013 /
0,006 para `pieces_in_sector` = 1 / 4 / 16 / 1000. Con el valor de mainnet (1000), **≈0,6 %**.

**Qué cuesta, y no es poco.**

1. **Rompe el invariante de no-equivocación de `C-FLU-12`** (`SPEC.md` §7.1.4: «dos copias del mismo
   billete MUST producir la misma entropía y el mismo `t_j`»). Bajo la identidad vigente ese invariante
   es un **teorema** —`chunk` está en la identidad—; bajo B/C dos copias pueden llevar `chunk` distinto y
   **la entropía difiere**. Medido. Obligaría a reescribir el invariante o a declarar el caso como coste
   aceptado; el propio SPEC advierte de que tocar la entropía **reabre el grinding por contenido**.
2. **Invalidación en cascada.** `C-GD-10` hace que el productor descarte las puntas que violarían
   `C-GD-11`, pero **no** las que harían inválido su bloque por U2. Con una identidad más gruesa la
   invalidez arrastra, por validez absoluta, a todo bloque que la tenga en su pasado: **64,8 % de bloques
   no válidos con equivocación total, frente a 0,40 % con la identidad vigente**.

**Consecuencia para el tablero.** La propuesta **no sube de fase**: `P-ZRX/PROPUESTAS-VIABLES.md` la
marca **F1 (tope)** y retira la dependencia «(1) puede dejar a (7) en segundo plano». **El mecanismo de
castigo vuelve a ser la vía principal.**

**Lo que sí se salva, y es valioso:** el hallazgo de `C-GD-10` es un **defecto real del diseño actual**,
independiente de esta propuesta, y conviene mirarlo aunque no se adopte. Está en los huecos del tablero.

**Procedencia del error.** Claude presentó esta mejora como «la mejor del día» apoyándose en dos informes
que compartían una premisa que ninguno había comprobado en el código. El encargo que la comprobó es el
que la tumbó, que es exactamente para lo que se escribió.
