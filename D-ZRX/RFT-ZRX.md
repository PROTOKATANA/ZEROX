# RFT-ZRX — refutaciones vigentes para el ZEROX híbrido

**Abierto:** 2026-09-26. **Mantiene:** Claude (director técnico, `AUTO-ZRX.md`). **Decide:** Katana.

**Qué entra aquí.** Solo resultados comprobados que **siguen aplicando** al diseño híbrido
(PoW de arranque → PoAS + PoT + DAG con garantía y posible registro de sectores), con su alcance
exacto y la evidencia que los reabriría. Cuando el híbrido **retira** la premisa de una refutación
antigua, esa refutación no está aquí: queda como histórica y **condicional** en
`R-ZRX/MAPA-RESCATE.md` y su pregunta nueva en `D-ZRX/IPA-ZRX.md` (`AUTO-ZRX.md` §2).

**Procedencia.** RFT-01…RFT-13: todas las fuentes están en el archivo `/home/katana/zeo/.trash/zerox/`
(= commit `9681061`, salvo los 95 archivos que solo existen en `.trash`). Rutas relativas a esa
raíz; hash sha256 completo del archivo citado. **Desde RFT-14:** las fuentes están en **este**
repositorio (rama `main`; hasta el 2026-09-28, `rediseno/v1-spec-first`), con el commit que las registró. Cada cita literal se comprobó en la fuente el
2026-09-26. **Los números de línea del SPEC antiguo se desplazaron por ediciones concurrentes:
citar por ID de regla.**

**Cómo usarlo.** Antes de proponer un mecanismo, comprobar que no choca con ninguna fila. Si
choca, o se demuestra que el mecanismo retira **exactamente** la premisa explotada (y se escribe),
o no se encarga.

---

## RFT-01 · La rama privada no deja evidencia; ningún depósito la castiga

**Enunciado.** Construir una rama privada, leer disco, calcular soluciones y no publicar no produce
ningún objeto verificable. Ninguna condición de validez evaluable sobre `past(B)` obliga a publicar:
en su rama, el atacante es la autoridad. El stake **no crea evidencia**, solo castiga la que existe;
con probabilidad de evidencia cero, ninguna cuantía disuade.

**Alcance.** Demostrado en sus dos direcciones centrales y declarado **no exhaustivo** sobre toda
condición imaginable (R-6). Lo que en PoS sí deja rastro de la rama privada son **votos públicos
con participación obligatoria**, un mecanismo distinto del depósito.

**Aplicación al híbrido.** **Sigue aplicando.** `D-ZRX/SPEC.md` §0 y §7 lo reconocen: el castigo
propuesto se limita a doble firma publicada. La fase PoW **no** cambia esto después del corte.

**Fuentes.** `P-ZRX/P-SECRETO/investigacion/INFORME.md` (sha256 `1524c43e3552a927f3c2c9b9276e446f22fd85a45dc1e3bec4d27d037fb06c94`), F1;
`P-ZRX/T-ZRX/LIBRO-DE-RESTRICCIONES.md` R-1, R-6 (`1592ecb88c2d6a525ad52f195430c05a8fe951979ecbc6b383f8633ce971f8de`);
`P-ZRX/T-ZRX/ESTADO-DOBLE-FARMEO.md` §1, §3 (`a667b25a724822d6dade9392b4fcdc6513c2a982bd4a7587ea8db82221696687`);
`P-ZRX/P-STAKE/MAPA.md` §0 (`0261f56c55ad81dbd2f10997d5f2b8933374f78222cdabc6bba1077e6fb0d9ae`).

**Qué NO dice.** Que el doble farmeo rompa el consenso: multiplica el ataque de mayoría,
`α* = (1 − β_d − 2β_x)/2` (`P-PRESTAMO` F1), y `C-FIN-01` lo acota a `d < F_slots`.

**Lo reabriría.** Un mecanismo que haga observable la rama privada sin votos obligatorios, con
prueba de que no cae en R-6; o una decisión de Katana que admita votos de finalidad por stake
(hoy excluidos por `D-ZRX/SPEC.md` §0).

**Actualización 2026-09-26.** La decisión llegó: Katana adopta en principio la capa de finalidad por
votos (`P-ZRX/P-FINALIDAD-VOTOS/DECISIONES.md` FV-D02). **La refutación sigue en pie:** hasta que un
certificado sella, la rama privada no deja evidencia y ningún depósito la castiga. Lo que cambia es la
**duración** del riesgo (de `F_slots` a la franja sin sellar) y que reescribir lo ya sellado exija firmar
dos certificados (evidencia castigable). No está implementada ni tiene contrato ratificado (IPA X-04).

---

## RFT-02 · La doble firma del «mismo billete» no alcanza al atacante con varias soluciones por slot

**Enunciado.** Con la identidad `C-GD-07` `(public_key, sector_index, history_size, chunk, slot)`,
la fracción `κ` del doble farmeo publicado que deja evidencia vale **1,000** si `m ≤ 0,05`,
**0,455** si `m = 1` y **0,000** si `m = 4` (flujo común), y **0,000** con flujo divergente;
`m` = soluciones ganadoras esperadas del atacante por slot.

**Alcance.** Enumeración exacta sobre el formato de 32 piezas × 4 chunks del modelo; `m` alto es
propio de un atacante con mucho espacio.

**Aplicación al híbrido.** **Sigue aplicando** a `C-EVP-01/02`: esa evidencia atrapa accidentes y
atacantes pequeños, no a uno grande que usa billetes distintos en cada rama. `D-ZRX/SPEC.md` §7 ya
lo declara («dos soluciones/billetes distintos … No bajo C-GD-07 actual»).

**Fuente.** `P-ZRX/P-EQUIVOCACION/investigacion/INFORME.md` (`c4720eab15926796ffd5053424287f23f5bfc55a015b53cdeca22c1d16ab23e5`), tabla §1.2.

**Lo reabriría.** Redefinir la falta (p. ej. dos cabeceras de la misma clave en un slot) **junto
con** una regla de una propuesta por clave y slot y la medida de su coste honesto y del efecto de
dividir claves (`D-ZRX/SPEC.md` §7, «Ampliaciones de E»). Nótese RFT-05: dividir claves anula
reglas por identidad.

---

## RFT-03 · Un compromiso sobre el valor de un objeto no fecha nada (incondicional)

**Enunciado.** Todo predicado sobre el **valor** de un objeto es invariante en el tiempo. Ningún
compromiso —raíz Merkle, KZG, acumulador, `SectorId`, fecha de alta— acredita que los bytes
existieran antes de un instante.

**Alcance.** Demostrado; no depende de hardware, ventana ni supuesto de dureza.

**Aplicación al híbrido.** **Sigue aplicando** a las variantes R1/R2 de
`P-ZRX/P-REGISTRO-SECTORES/` (identidad y fecha; raíz exacta sin prueba de cómputo): contabilidad
e identidad de lote, **no** preexistencia. Tampoco la PoRep la da: una PoRep ligada a aleatoriedad
posterior prueba cómputo **después** de esa aleatoriedad (cota inferior de tiempo), no existencia
anterior.

**Fuente.** `P-ZRX/P-COBERTURA/investigacion/INFORME.md` §3, Corolario 4 (`63935b0d4ad395e2e85277ec7e76664b14685f450f95eeabc39732889d9f4719`).

**Qué NO dice.** Que no se pueda comprometer la cobertura del objeto (sí es construible, §7.3 del
mismo informe), ni que una cota **inferior** de tiempo sea imposible.

**Lo reabriría.** Nada que se apoye solo en el valor del objeto. Una propiedad temporal exige algo
que varíe con el tiempo y esté ligado al cómputo honesto (mismo informe, Cor. 4).

---

## RFT-04 · Sobre el formato PoAS actual, auditar no distingue «guardado» de «regenerado»

**Enunciado.** Si el objeto es función determinista y pública de datos públicos y su cómputo es
paralelizable por unidad, ningún esquema con verificación sucinta distingue almacenado de
regenerado dentro del plazo (simulación exacta). Las aperturas por muestreo no demuestran
almacenamiento.

**Alcance.** **Condicionado** a que la regeneración quepa en la ventana del reto; verificado en la
fuente de Autonomys `f8842d0` (`generate_parallel` en `plotting.rs`, según el informe).

**Aplicación al híbrido.** **Sigue aplicando** a auditorías posteriores (encargo 02 de
`P-REGISTRO-SECTORES`) mientras el formato sea el de PoAS actual. Una auditoría sobre ese formato
solo **encarece**, y hay que dar el coste absoluto.

**Fuentes.** `P-ZRX/P-COBERTURA/investigacion/INFORME.md` §3, Cor. 1;
`P-ZRX/P-PERMANENCIA/investigacion/INFORME.md` (`aa023e3acb2ee4aed1a75e8d67ce381187d3e33e1b79209d984d34693e5595f8`);
`LIBRO-DE-RESTRICCIONES.md` R-3.

**Lo reabriría.** Cambiar el objeto ploteado: romper el determinismo público (semilla secreta) o la
paralelizabilidad (sellado secuencial tipo PoRep) — encargos 04/05 de `P-REGISTRO-SECTORES`. La
latencia o «materializar N a la vez» no son vías: son desigualdades sobre hardware.

**Actualización 2026-09-26 (coste absoluto, P-DISUASION).** Regenerar en vez de almacenar cuesta
117,238 núcleos por TiB en continuo, ≈ 7,1 GTX 1070 y ≈ 677 W por TiB (medida GPU de DS-4 con la tabla
**v2** de Autonomys; ZEROX usa la v1, 0,92 frente a 0,90 s por registro en CPU). Es un encarecimiento
**exigible**, pero la auditoría solo **detecta** la regeneración si abre más de 181 092 posiciones por TiB
en el plazo del reto (un SSD lo sirve, un disco duro doméstico no). Fuente: `P-ZRX/P-DISUASION/REVISION-DS3.md`
(`54add85`), `REVISION-DS4.md` (`4147520`). Una GTX 1070 es cota inferior de una GPU actual.

---

## RFT-05 · Toda regla por identidad se evade partiendo el espacio; un coste fijo no basta

**Enunciado.** (R-4) Cualquier exclusividad «una identidad X bajo un solo Y» se derrota repartiendo
el espacio entre identidades mientras crear una cueste lo mismo por byte. (R-5) Un coste **fijo**
por identidad solo domina por debajo de un tamaño de granja. (R-9) Para una cuota `φ` con
`φ(0)=0`, «partir cuesta» si y solo si `φ(f)/f` es estrictamente decreciente, es decir, regresiva.

**Aplicación al híbrido.** **Sigue aplicando** a cualquier propuesta que use `requisito(B)` por
clave (`C-BON-04`) como **defensa del umbral o de la exclusividad**. `D-ZRX/SPEC.md` no lo usa así
(el depósito solo habilita y responde), y debe seguir sin hacerlo.

**Fuentes.** `research/dag-poas-balizas-auditoria.md:30-38,66-78` (`c5a8fc476988bf7c9b5827e292b4e96459943bba54d4b25f616c33e92aac788e`);
`P-ZRX/P-TASA/investigacion/INFORME.md` §2.3, §4.1 (`ca59f678d5d93be0dccaff29b46539d9b0046cef457f0cbc729aff984a6582fe`).

**Lo reabriría.** Un coste no proporcional al espacio que además crezca con el beneficio lineal de
evadir, sin ser regresivo — R-9 lo descarta para cuotas; habría que salir de esa familia.

---

## RFT-06 · El sellado ligado a la rama no existe para un objeto determinista y público

**Enunciado.** Un «religado» que quepa en el presupuesto del honesto materializa ~6–19 MiB y deja
compartir ≥ 99,998 % del espacio entre ramas; el que haría falta cuesta 5,7·10⁴–1,7·10⁵ veces ese
presupuesto. El ticket de Filecoin se toma de un bloque finalizado y **no** separa forks.

**Aplicación al híbrido.** **Sigue aplicando:** ningún precompromiso, PoRep o auditoría del
registro de sectores cierra el doble farmeo entre ramas (coincide con `ENCARGO-05` de
`P-REGISTRO-SECTORES`). Las cifras dependen de `τ = 1 s` y del modelo de esa fecha; la dicotomía,
no.

**Fuente.** `P-ZRX/P-SELLO/investigacion/INFORME.md` F3 (`2c35b3a57055d7a00571cebc8d24f0ab0e4764b687f63d67e83bc53912cfc69c`);
`ESTADO-DOBLE-FARMEO.md` H-8.

**Lo reabriría.** Una primitiva fuera de la clase determinista-pública que ligue el objeto a la
rama sin ser neutral entre las ramas del propio granjero (no encontrada; la vía del secreto sí es
neutral).

---

## RFT-07 · La cuota de peso no está acotada por la fracción de bytes

**Enunciado.** `α_blue_work ≤ α_bytes` es **falso**: con `f = 0,3` y eficiencia azul asimétrica la
cuota del adversario es `6/13 = 0,4615` (amplificación 1,54×). La revisión 1 del instrumento circuló
con la cota contraria; prevalece la revisión 2.

**Aplicación al híbrido.** **Sigue aplicando** a todo razonamiento de umbral en la fase PoST.

**Fuente.** `P-ZRX/P-PUENTE-ESPACIO-TASA/veritas/seguridad/espacio-tasa-v1/INFORME-CORRECCION.md` C1
(`8c38d2483a890d49e37822b2d513b9d353e8709da4b00de5289a0dc2dd16065c`).

---

## RFT-08 · Anclar el reto al padre seleccionado da grinding (26,8941 %)

**Enunciado.** Si el reto depende del padre, cada punta es una lotería y el umbral cae a
`1/(1+e)`; no hay profundidad intermedia útil porque `L_slots ≥ F_slots`.

**Alcance.** No se hereda automáticamente si cada reintento cuesta (p. ej. un bloque PoW); aplica
cuando el reto puede re-muestrearse gratis.

**Aplicación al híbrido.** **Sigue aplicando** a la fase PoST. Para la semilla del corte
(TRN-08 de `P-ZRX/P-TRANSICION/CONTRATO-v0.md`) el re-muestreo **no** es gratis: cada terminal
alternativo cuesta un bloque PoW válido. Eso **no** la vuelve segura: queda como problema abierto
IPA A-07.

**Fuentes.** `research/dag-poas-ancla-de-finalidad.md:313-319` (`c7ea047b02fa8b31cdc189a4112a0ec4e4164e51379a6c721656ac6f8e695619`);
`P-ZRX/P-ANCESTRIA/investigacion/INFORME.md` F2, F5 (`47dc6c5d73174ba87d4727d7bc886489f9392a7ac6c4bc9e82ca5dec10653109`).

---

## RFT-09 · El tiempo no es rival; una pata PoW concurrente aditiva no reduce el doble farmeo

**Enunciado.** (R-8) Un VDF por rama se paraleliza entre ramas: dos núcleos, dos ramas; el segundo
VDF no defiende del doble farmeo (sí sirve para la ventana de adelanto, otro problema). (P-RIVAL)
En composición aditiva o de umbral, `V = β_d/2 + β_x` no baja con el peso `θ` de una pata PoW; en
la multiplicativa hay dilución, pero su moneda es la tasa de hash, que se compra.

**Aplicación al híbrido.** **Sigue aplicando** como advertencia: **mantener PoW después del corte
no es una defensa** del doble farmeo salvo composición multiplicativa con mayoría honesta de hash,
que un adversario con dinero compra. El híbrido actual no mantiene PoW tras el corte (TRN-05).

**Fuentes.** `P-ZRX/P-RIVAL/investigacion/INFORME.md` F1–F4 (`8488417a18764c8d2d9f320d5a095eaf29be93239511a29974de550ca5287117`);
`LIBRO-DE-RESTRICCIONES.md` R-8.

---

## RFT-10 · La identidad de billete por pieza no aporta nada

**Enunciado.** `chunk` no es un grado de libertad independiente: un reto fija un s-bucket y cada
pieza aporta como mucho un chunk. Las tres identidades evaluadas particionan igual; beneficio
≈ 0,6 % y rompe `C-FLU-12`.

**Aplicación al híbrido.** **Sigue aplicando** a `C-EVP-01`: no proponer una identidad de
oportunidad por pieza como forma de ampliar la evidencia.

**Fuentes.** `P-ZRX/P-IDENTIDAD/investigacion/INFORME.md` §4 (`9aab46c48accba44c1eaf3b9603875a85198ec116441937b43990944bda93758`);
`P-ZRX/T-ZRX/MEJORA-IDENTIDAD-DE-BILLETE.md` (`a3c42887627aea895c32c57a26a771f0c2caf66755c7004364955d5b2a7145dd`).

**Lo reabriría.** Un formato de parcela distinto (el resultado depende del formato de Autonomys
`f8842d0`).

---

## RFT-11 · Una firma no prueba que el firmante vio nada

**Enunciado.** El verificador comprueba que alguien firmó, nunca por qué. «Firmar solo lo visto»
es conducta, no regla de consenso; la firma a ciegas es indistinguible. Es el mismo fallo que el de
los pools (el operador compone `pre_hash` y el cliente firma sin ver). Además, recoger `k` firmas
por slot mata la viveza (`P(cabe) = 0,219` con `k = 4`, `Δ = 0,26 s` simulada).

**Aplicación al híbrido.** **Sigue aplicando:** ninguna defensa de la garantía o de los sectores
puede depender de atestiguación de terceros ni de que un pool «no haga firmar a ciegas».

**Fuentes.** `P-ZRX/P-SECRETO/investigacion/INFORME.md` §1.2; `P-ZRX/P-POOLS/investigacion/INFORME.md`
(`bfac1d85b35e55c7795630168af48e129d98833c81bd8ad51f348bb2a2596afc`); `LIBRO-DE-RESTRICCIONES.md` R-10.

---

## RFT-12 · Con el segundo VDF, la ventana de adelanto no se anula

**Enunciado.** La tesis «`sup A = 0` con `ρ_max ≤ ρ*`» y «la edad colapsa» son **falsas**: sin
segundo VDF el adelanto ≈ `L` para todo `ρ > 1`; con él, `(L + I)(1 − 1/ρ)`. El modelo de
`P-ADELANTO` quedó refutado; su aritmética vale.

**Alcance.** Cifras del modelo (`L = 7200`, `I = 851`) sin revalidar; `SDV-v1.1` posterior deja la
mejora protocolaria **inconclusa**. `ρ_max` depende de hardware (`ESTADO-RELOJ.md`: `ε·K`, K = 16
medido en un Ryzen 9950X3D).

**Aplicación al híbrido.** **Sigue aplicando** a la fase PoST y al corte: un adversario con PoT
más rápido conoce antes los retos, incluidos los primeros tras `s_0`.

**Fuentes.** `P-ZRX/P-REVELACION/investigacion/INFORME.md` (`2abfab32dd1593e489b8fb889338ba7f5ecd5cf51196867b1b62ddfad5951480`);
`P-ZRX/P-SEGUNDO-VDF/segundo-vdf-v1/INFORME.md` (`70bcd72335708dbef153db56e011d4c7711810afd22e7aba886ad1f942d9fe46`);
`P-ZRX/T-ZRX/ESTADO-RELOJ.md` (`88f436498971ba84ff3a17a1ff908e438021766c13d776cc2f95a0369a1cda4a`).

**Nota del director (2026-09-27; derivación sin instrumento, a verificar en 0.0.2 paso 1).** De la propia fórmula:
el segundo VDF recorta el adelanto frente a `L` solo mientras `(L + I)(1 − 1/ρ) < L`, es decir, `ρ < 1 + L/I`. Con
`L = 7200` e `I = 851` el umbral es `ρ ≈ 9,46`, muy por encima de la ventaja realista con AES. Ejemplos: con
`ρ = 1,5` el adelanto baja de 7 200 a ≈ 2 684 (−63 %); con `ρ = 2`, a ≈ 4 026 (−44 %). Por encima del umbral no
mejora nada. Depende de `L` e `I`, que están sin revalidar.


---

## RFT-13 · Ninguna regla de selección protege con PoST los últimos bloques PoW antes del primer bloque PoST

**Enunciado.** Mientras ningún sufijo tiene peso PoST, la selección a través del corte (FC-3)
decide por trabajo PoW: reescribir los últimos `k` bloques antes del corte es la carrera de Nakamoto
(depende de `h` y `k`, no del espacio). Con `h ≥ 1/2` el adversario controla el terminal.

**Alcance.** Modelo T02 sin latencia ni retarget, `k = 0` para GHOSTDAG; `h = 0,25`, `k = 6`:
éxito ≈ 0,039 con cualquier `a < 1/2`.

**Aplicación al híbrido.** **Aplica:** no se puede afirmar que el corte «hereda» seguridad PoST
para los bloques inmediatamente anteriores. Lo que se juega en esa ventana (depósitos, pagos,
emisión de los últimos bloques) tiene seguridad PoW.

**Fuente.** `P-ZRX/P-TRANSICION/T02/INFORME.md` §§1, 3; revisión `P-ZRX/P-TRANSICION/REVISION-T02.md`.

**Lo reabriría.** Una regla que dé peso PoST honesto antes del corte o que cierre lo que está en juego
antes de la ventana (IPA A-05b), demostrada con latencia real.

---

## RFT-14 · Ningún mecanismo de PoStake ni de Filecoin encarece de forma exigible el doble farmeo del atacante con espacio propio suficiente

**Enunciado.** La garantía sin castigo no encarece el doble farmeo: el mismo colateral vale en todas las
ramas. El castigo con evidencia más retención (M3 + M5) solo muerde si hay evidencia y saldo: con el
reparto de claves supuesto por DS-3 (cola larga de claves diminutas), el atacante recluta en claves sin
saldo el espacio que cruza la deriva y el sobrecoste es **Δ = 0** para toda probabilidad de éxito ≤ 0,5.
Registro, auditorías, colateral de sectores y sellado encarecen **otros** ataques (sembrador, Sybil, largo
alcance), no el doble farmeo simultáneo. Ningún sistema de espacio puro revisado (Chia, SpaceMint,
Autonomys) lo encarece de forma exigible; el castigo de SpaceMint exige que se publiquen los dos bloques.

**Alcance.** Atacante grande que no necesita espacio ajeno. **Excepción medida:** con el reparto real de
un pool de Chia (2 470 granjeros), la fracción del espacio en claves sin saldo suficiente es
1,78·10⁻⁴ [1,49·10⁻⁴; 2,08·10⁻⁴] (`ε = 0,01`, `T_v = 3 600`), muy por debajo del umbral que haría gratis el
reclutamiento: el atacante que **recluta** sí paga el castigo. Es una barrera condicionada a que haya
evidencia, no un cierre. Las cifras en unidades de token son escenarios hipotéticos y el modelo de DS-2
mezclaba saldo por clave y pérdida por reclutado (SL-2, F5): la escala absoluta es dudosa; la conclusión
es estructural.

**Aplicación al híbrido.** **Aplica.** No presentar la garantía, el castigo ni el registro de sectores como
solución del doble farmeo. La capa de finalidad por votos (FV-D02) lo **mitiga en el tiempo**; tampoco lo
encarece antes del sello.

**Fuente.** `P-ZRX/P-DISUASION/SINTESIS.md` (`a9b42a7`), `REVISION-DS1.md` (`96caf72`), `REVISION-DS3.md`
(`54add85`), `REVISION-DS6.md` (`8e1e93d`); `P-ZRX/P-SLASHING/REVISION-SL2.md` (F5).

**Lo reabriría.** Un mecanismo cuyo coste el atacante pague en todas las ramas sin depender de que
publique evidencia, con prueba de que no cae en RFT-01 ni en R-6.

---

## RFT-15 · El castigo correlacionado (`C-SLA`) no disuade al atacante grande y castiga a honestos

**Enunciado.** Ninguna forma de castigo correlacionado confisca más que el saldo `V` que existe. Con la
grieta de DS-3 (279 claves reclutadas con saldo ≤ 0,01), el máximo confiscable es 2,79 u.e. frente a
510 570 u.e. de soborno evitado. Solo alcanza a quien deja evidencia y tiene saldo, un subconjunto de lo
que ya cubre el castigo simple. Además **empeora**: con la forma de `D-ZRX/SPEC.md` §5 y `b = 0,1`, un fallo
compartido del 5 % de 10 000 claves satura el castigo salvo `c < 0,0018`; abre *griefing* y, al escalar con
el número de claves, incentiva concentrar identidades.

**Alcance.** Las dos formas examinadas (la de `SPEC.md` y la tipo Ethereum, por fracción de saldo); la
segunda es menos mala para honestos, pero tampoco cierra el doble farmeo ni la equivocación. Las cifras
en u.e. tienen la reserva de escala de SL-2 (F5).

**Aplicación al híbrido.** **Aplica.** `C-SLA-01…04` de `D-ZRX/SPEC.md` (propuesta de Katana, no
ratificada) no se implementa: pérdida no correlacionada con fracción fija `f` (`P-ZRX/P-SLASHING/DECISIONES.md`
DS-L02). Tampoco se correlaciona la multa por ausencia de voto (AV-1).

**Fuente.** `P-ZRX/P-DISUASION/REVISION-DS5.md` (`07dc551`).

**Lo reabriría.** Una forma de correlación que alcance al atacante sin evidencia o sin saldo, con tasa de
castigo a honestos medida y acotada.

---

## RFT-16 · Una cadena más larga basada en prueba de espacio no es segura sin supuestos adicionales

**Enunciado.** Baig y Pietrzak (FC 2025, arXiv:2505.14891), resumen: «we prove that without additional
assumptions no such protocol exists» (cadena más larga basada en PoSpace, segura bajo disponibilidad
dinámica), con una cota de la longitud del fork válida para cualquier regla de selección. El artículo
reconoce dos salidas: un VDF (Chia) contra el *bootstrapping* y registro + BFT (Filecoin) contra el
*replotting*.

**Alcance.** Resultado publicado, leído por el director en arxiv.org el 2026-09-26. La cota transcrita en
el modelo de DS-3 (4 253) no coincide con la del resumen (`φ²ρ/ε = 1 600`): mismo orden de magnitud;
**no** se usa como cifra de ZEROX.

**Aplicación al híbrido.** **Aplica a medias.** El PoT de un solo flujo saca a ZEROX del *bootstrapping*;
el *replotting* sigue abierto mientras no haya registro de sectores y una capa tipo BFT. La finalidad por
votos sobre sectores registrados (FV-D01, FV-D02) es la candidata para esa mitad y depende del registro,
que no existe.

**Fuente.** `P-ZRX/P-DISUASION/REVISION-DS1.md` (`96caf72`), `REVISION-DS3.md` (F7).

**Lo reabriría.** Una demostración de que el híbrido cumple el supuesto adicional del artículo para el
*replotting* (registro + finalidad por votos implementados y medidos).

---

## RFT-17 · Con prima `b > 1` en el sorteo de votos y censura de las pruebas de disponibilidad, pausar la finalidad exige menos de un tercio

**Enunciado.** Si el atacante (siempre encendido, siempre con prima) censura todas las pruebas de
disponibilidad de los honestos, su fracción de plazas es `a·b/(a·b + 1 − a)`. Pausa (≥ 1/3 de las plazas)
con `a ≥ 1/(2b+1)` y sella a solas (≥ 2/3) con `a ≥ 2/(b+2)`. Con `b = 2` (FV-D05): pausa con el **20 %**,
sella a solas con el **50 %**. Es la esperanza, no varianza del sorteo. La prima es un trilema: `b` mueve a
la vez la viveza, la seguridad de pausa y la de sellar a solas, y ningún valor gana en las tres.

**Alcance.** Atacante con control de red suficiente para censurar las pruebas de disponibilidad.
Aritmética rehecha por el director. Sin censura, el umbral de pausa vuelve a 1/3.

**Aplicación al híbrido.** **Aplica** a la capa adoptada con `b = 2`. Pausar devuelve a la situación sin
capa (`C-FIN-01`); desde AV-1 pausar ya **cuesta** (falta «elegido sin voto», `m_aus` proporcional, FV-D06),
pero el umbral no sube.

**Fuente.** `P-ZRX/P-FINALIDAD-VOTOS/REVISION-FV1.md` (`bfc40b9`), `resultados-FV1/`.

**Lo reabriría.** Pruebas de disponibilidad no censurables por quien controla la red, o `b = 1` (que exige
el 66,7 % de participación honesta para sellar).

---

## RFT-18 · Un certificado de finalidad falso ya adoptado no se revierte con trabajo honesto

**Enunciado.** Con la capa pausada o sin activar ningún nodo queda peor que con `C-FIN-01`; pero un nodo
que **adoptó** un certificado falso no lo abandona por más trabajo honesto posterior («mentira
permanente»): ahí sí queda peor. Sellar a solas exige `a ≥ 2/(b+2)` con censura (50 % con `b = 2`).

**Alcance.** Condición (c) de la orden FV-1, refutada **en parte**. Firmar dos certificados contradictorios
deja evidencia castigable (`EvidenceVoto`), así que el ataque cuesta garantía, pero el daño a quien adoptó
es irreversible.

**Aplicación al híbrido.** **Aplica.** Es el coste explícito aceptado por Katana al adoptar la capa y la
razón para no bajar el umbral de sellar a solas (`b = 2`, no 4).

**Fuente.** `P-ZRX/P-FINALIDAD-VOTOS/REVISION-FV1.md` (`bfc40b9`); `resultados-FV1/INFORME.md` (FV-18).

**Lo reabriría.** Una regla de recuperación que saque de un certificado falso sin hacer reversibles los
certificados honestos, demostrada bajo partición.

---

## RFT-19 · Una tabla de poder que cada nodo recalcula desde su propio pasado rompe la finalidad bajo partición

**Enunciado.** Si la tabla de poder de la instancia `n` es «función de `past(A_n)` y de nada más», una
partición pura, sin ninguna doble firma, basta para que cada mitad certifique una historia distinta: cada
una recalcula la tabla con las claves que ve y reúne 2/3 de **su** tabla con menos de un tercio del peso
real. Es peor que `C-FIN-01` sola.

**Alcance.** Refuta la lectura literal de la propuesta antigua (R-FIN-15). Se cierra con **FV-01b**: la
tabla de `n` es la que comprometió el certificado de `n − 1` (como FIP-0086 de Filecoin F3). **Residuo:** la
ventana de arranque antes del primer certificado.

**Aplicación al híbrido.** **Aplica como restricción:** toda variante de la capa encadena la tabla por
certificado.

**Fuente.** `P-ZRX/P-FINALIDAD-VOTOS/resultados-FV1-v1/INFORME.md` §1.1 (`3bfcf1a`).

**Lo reabriría.** Nada que recalcule la tabla localmente; solo una tabla derivable igual por todos sin
certificado previo, demostrada bajo partición.

---

## RFT-20 · Una multa fija por no votar no crece con el tamaño del atacante

**Enunciado.** La falta «elegido sin voto» es por clave e instancia. Con `m_aus` **fijo** y el peso en una
sola clave, pausar cuesta **36 000 u.e./h para cualquier `a` entre 0,10 y 0,40**; repartir el peso en más
claves multiplica los incidentes (de 1 a 95 por instancia al pasar de 1 a 1 000 claves con `a = 0,1`), lo
que castiga la fragmentación y premia concentrar.

**Alcance.** Cálculo de AV-1 en Julia (`calc/resultados/C2-costo-pausa-hora.csv`,
`C6-concentracion-vs-fragmentacion.csv`), leído por el director. Unidades hipotéticas.

**Aplicación al híbrido.** **Aplica:** Katana decidió `m_aus` proporcional a la garantía con un mínimo
(FV-D06); proporcional, el coste crece con `a` (1,8·10⁷ → 7,2·10⁷ u.e./h).

**Fuente.** `P-ZRX/P-AUSENCIA-VOTO/REVISION-AV1.md` (`98ceea8`).

**Lo reabriría.** Una falta por unidad de peso que no dependa del número de claves.

---

## RFT-21 · Una sola VRF por ventana revela el calendario de votos

**Enunciado.** Si una única salida VRF por ventana decide todas las instancias en que sale elegido un
granjero, en cuanto vota una vez revela el calendario completo del resto de la ventana: el atacante puede
censurarlo de forma selectiva. Hace falta una VRF **independiente por instancia**, comprometida por
Merkle al abrir la ventana y revelada al cerrarla. SSLE se descarta: resuelve el problema contrario (que
solo el elegido pueda probarlo).

**Alcance.** Diseño de AV-1 (`CONTRATO-AUSENCIA-v0.md`), sin implementación.

**Aplicación al híbrido.** **Aplica** al contrato de la falta de ausencia y a FV-2.

**Fuente.** `P-ZRX/P-AUSENCIA-VOTO/resultados-AV1/CONTRATO-AUSENCIA-v0.md`, `INFORME.md`; revisión
`REVISION-AV1.md` (`98ceea8`).

**Lo reabriría.** Una construcción de una VRF por ventana que no filtre el calendario, con prueba.

---

## RFT-22 · Redondear hacia arriba la recompensa del incluidor deja al infractor perder menos de 6/8

**Enunciado.** Con recompensa `techo(C·2/8)`, el infractor que se autodenuncia puede perder menos de
`6/8·C` (con `C = 11`: pierde 8 < 8,25). La regla vigente es **RAT-2′**: `suelo(C·2/8)`.

**Alcance.** Aritmética entera exacta; detectado por el ejecutor de SL-3 (AMBIGUEDAD-SL3-9). Error del
director en RAT-2.

**Aplicación al híbrido.** **Aplica:** oráculos T01 v0.4 / T04 v0.5 y Rust (SL-4a) usan el suelo.

**Fuente.** `P-ZRX/P-SLASHING/REVISION-SL3.md` (`50c9a13`), `CONTRATO-EVIDENCIA-v0.md` («Ratificación v0»).

**Lo reabriría.** Nada: es aritmética.

---

## RFT-23 · Una garantía fija por identidad expulsa al granjero diminuto

**Enunciado.** Con garantía **por identidad**, el granjero honesto con fracción de red `f_h ≲ 10⁻⁵` paga
más de garantía que lo que ingresa: el mecanismo es regresivo.

**Alcance.** Calibración de SL-2 con los escenarios hipotéticos de DS-2/DS-3; coincide con la
regresividad que ya señalaban DS-2 y DS-3 (A4 Sybil).

**Aplicación al híbrido.** **Aplica** al perfil dev (`q = 10` ZZK por clave; el `q_g = 20` de SL-2 está en unidades del
modelo, no es comparable; corrección del 2026-09-28): aceptable para la red dev, no
para producción. Recomendación: garantía **por unidad de espacio** (IPA C-02, C-07).

**Fuente.** `P-ZRX/P-SLASHING/REVISION-SL2.md` (`a9b42a7`).

**Lo reabriría.** Precios y parámetros de producción que saquen del rango al granjero pequeño real, o un
requisito proporcional al espacio.

---

## RFT-24 · Un nodo en el mismo puerto y con los mismos pares no está aislado: esa «partición» no prueba nada

**Enunciado.** Relanzar un nodo **en el mismo puerto** sin marcar a nadie **no** lo aísla: los demás, que lo tienen en su
`--red-marcar`, vuelven a conectarse y le entregan sus bloques. En W06d7 V5 rep2 la punta del nodo «aislado» era idéntica a
la del otro lado. La V6(b) de W06d7 (partición con el mismo terminal) se dio por demostrada así y era
falso. Una partición solo cuenta con el nodo aislado en un **puerto nuevo sin pares** y con **0 contactos cruzados**
(`par_conectado`, `bloque_recibido`) en los registros de los dos lados durante toda la ventana.

**Alcance.** Método de medición con procesos reales; comprobado en W07b E-6 (3/3 con `contactos_* = 0`).

**Aplicación al híbrido.** **Aplica** a toda prueba de partición, eclipse o reunión (0.0.2: investigación del eclipse).

**Fuente.** `P-ZRX/P-NODO/REVISION-W06d7.md` (corrección del director), `P-ZRX/P-MEDICION/REVISION-W07b.md`,
`resultados-W07b/run/R3-E6-3d21b1f-rep*/EJECUCION.txt`.

**Lo reabriría.** Nada: es método.

---

## RFT-25 · El último `cambio_punta` del registro no decide si dos nodos tienen el mismo estado

**Enunciado.** Comparar el `resumen_estado` del último `cambio_punta` (con o sin reinicio aislado) da falsos
«DIVERGEN». El resumen solo se escribe al cambiar de punta, y un bloque lateral admitido después altera el estado sin
dejar un resumen nuevo. En W07b R1 rep2, C salió «DIVERGEN» con la misma punta que A y B. El campo
`estado_final_igual` del analizador (último evento del registro crudo) dio `false` en R1 ×3 y el estado real era el
mismo. **Método decisivo (W07d):** reposo, parada ordenada o `reinicio_completo` sobre una **copia** de los datos, y
comparación de `resumen_estado` **y** `compendio_bloques` calculados sobre el estado final.

**Alcance.** Método; tres iteraciones refutadas con evidencia real antes de W07d.

**Aplicación al híbrido.** **Aplica** a toda medición multinodo.

**Fuente.** `P-ZRX/P-MEDICION/resultados-W07b/INFORME.md` §5.2, `P-ZRX/P-MEDICION/REVISION-W07d.md`.

**Lo reabriría.** Nada: es método.

---

## RFT-26 · Sin relevo de transacciones, el reparto de claves decide quién cruza el corte (`K_min` es por lado)

**Enunciado.** Con `K_min = 3` y sin relevo de transacciones, cada nodo solo incluye sus propios depósitos:
- con **tres claves en un nodo**, ese nodo cruza solo y los demás no pueden obtener garantía nunca;
- con una **partición anterior al corte** y claves 1 + 1 + 1, **ningún** lado llega a `K_min`. En W07b, un nodo aislado
  minó 206 bloques PoW sin cruzar.

**Alcance.** Perfil dev de 0.0.1; comprobado con procesos reales (W07b §5.1 y §5.3).

**Aplicación al híbrido.** **Aplica** hasta que exista el relevo de transacciones (IPA A-14, 0.0.2 paso 2). En
producción es también un vector: un solo operador con varias claves puede cumplir `K_min` y dejar fuera a los demás.

**Fuente.** `P-ZRX/P-MEDICION/resultados-W07b/INFORME.md` §5.1 y §5.3; ejecución
`deepseek/W07b/run/R3-E6b-3d21b1f-rep1-kmin-imposible/`.

**Lo reabriría.** El relevo de transacciones, o una regla de corte que no dependa de que cada lado reúna `K_min`.

---

## RFT-27 · Penalizar todo `Rechazar` castiga a pares honestos: lo que depende de la vista local no prueba invalidez

**Enunciado.** Tratar como violación de consenso todo bloque rechazado veta a honestos. Hay rechazos que dependen de
la **vista local** del nodo y no del bloque:
- el timestamp PoW por encima del FTL (reloj local);
- el tope local de terminales con DAG;
- los fallos locales de disco o servicio;
- un padre rechazado por cualquiera de esos motivos.

Desde W07a penalizaban en la ruta de sincronización y, con W06d10, lo harían también en gossip. Solo penaliza lo
**demostrablemente inválido para cualquier nodo que tenga los padres**; ante la duda, `Ignorar`.

**Alcance.** Código del nodo en `c107163` (W06d10-B); tabla de caminos en `resultados-W06d10/PROGRESO.md` §0.2.

**Aplicación al híbrido.** **Aplica** a toda regla de puntuación de pares (0.0.2: gestor de direcciones y prevención
del eclipse).

**Fuente.** `P-ZRX/P-NODO/REVISION-W06d10.md`, `P-ZRX/P-NODO/REVISION-W06d10-B.md`.

**Lo reabriría.** Nada: un par honesto no puede evitar lo que depende de la vista de otro nodo.

---


## Registro de altas

| Fecha | Filas | Motivo |
|---|---|---|
| 2026-09-26 | RFT-01 … RFT-12 | Alta inicial tras releer el archivo antiguo para el rediseño híbrido |
| 2026-09-26 01:40 | RFT-13 | T02-A (ventana previa al primer bloque PoST) |
| 2026-09-26 22:25 | RFT-14 … RFT-23; actualización de RFT-01 y RFT-04 | P-DISUASION (DS-1…DS-6), P-SLASHING (SL-2, SL-3), P-FINALIDAD-VOTOS (FV-1, dos ejecuciones) y P-AUSENCIA-VOTO (AV-1) |
| 2026-09-28 02:14 | RFT-24 … RFT-27; nota en RFT-12 (umbral del segundo VDF); corrección de `q` en RFT-23 | W06d7 y W07b (método de partición y de mismo estado; `K_min` por lado), W06d10 y W06d10-B (penalización por vista local) |
