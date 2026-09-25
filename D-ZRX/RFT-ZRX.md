# RFT-ZRX — refutaciones vigentes para el ZEROX híbrido

**Abierto:** 2026-09-26. **Mantiene:** Claude (director técnico, `AUTO-ZRX.md`). **Decide:** Katana.

**Qué entra aquí.** Solo resultados comprobados que **siguen aplicando** al diseño híbrido
(PoW de arranque → PoAS + PoT + DAG con garantía y posible registro de sectores), con su alcance
exacto y la evidencia que los reabriría. Cuando el híbrido **retira** la premisa de una refutación
antigua, esa refutación no está aquí: queda como histórica y **condicional** en
`R-ZRX/MAPA-RESCATE.md` y su pregunta nueva en `D-ZRX/IPA-ZRX.md` (`AUTO-ZRX.md` §2).

**Procedencia.** Todas las fuentes están en el archivo `/home/katana/zeo/.trash/zerox/`
(= commit `9681061`, salvo los 95 archivos que solo existen en `.trash`). Rutas relativas a esa
raíz; hash sha256 completo del archivo citado. Cada cita literal se comprobó en la fuente el
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

## Registro de altas

| Fecha | Filas | Motivo |
|---|---|---|
| 2026-09-26 | RFT-01 … RFT-12 | Alta inicial tras releer el archivo antiguo para el rediseño híbrido |
| 2026-09-26 01:40 | RFT-13 | T02-A (ventana previa al primer bloque PoST) |
