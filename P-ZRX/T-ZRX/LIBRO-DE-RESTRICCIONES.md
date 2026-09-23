# Libro de restricciones — qué tiene que pasar cualquier pieza nueva de ZEROX

**Abierto:** 2026-09-23 · **Mantiene:** Claude · **Decide:** Katana.

Este documento **no narra** la investigación: la convierte en **criterio de diseño**. Cada restricción
es un resultado ya establecido, con su prueba, **su alcance exacto** y **qué descarta**.

**Para qué sirve.** Antes de gastar un encargo en una idea, pásala por las doce. Si choca con una,
está refutada antes de nacer y sabes por qué. Si las pasa todas, **merece encargo** — y entonces el
encargo se escribe sabiendo qué NO hace falta volver a comprobar.

**Cómo leerlo.** «Qué NO dice» es tan importante como el enunciado: casi todos los errores de esta
serie vinieron de aplicar un resultado fuera de su alcance.

---

## Las restricciones

### R-1 · Un recurso no rival produce doble farmeo, y cerrarlo exige cambiar de familia

**Enunciado.** Si el recurso que da derecho a producir **no se consume al usarlo**, el mismo recurso
produce peso en ramas distintas a la vez. Cerrarlo exige **consumo físico** (PoW y parientes) o
**registro de identidades + castigo con participación obligatoria** (PoS y parientes).

**Estado:** `derivado`, del catálogo completo de familias. **Prueba:** `ESTADO-DOBLE-FARMEO.md` §1
y el teorema de exclusividad (R-4).

**Qué descarta:** cualquier defensa que espere cerrar el doble farmeo **sin tocar la naturaleza del
recurso**. Las nueve intentadas caen aquí.

**Qué NO dice:** que el doble farmeo rompa el consenso. Es un **multiplicador** del ataque de mayoría
—`α* = (1 − β_d − 2β_x)/2`— y está **acotado por `C-FIN-01`**: solo sirve dentro de `d < F_slots`.

---

### R-2 · Un compromiso al VALOR no puede fechar nada · **incondicional**

**Enunciado.** Todo predicado sobre el **valor** de un objeto es invariante en el tiempo: vale lo
mismo computado hoy que hace un mes. Por tanto **ningún compromiso** —Merkle, KZG, acumulador— puede
acreditar **preexistencia**.

**Estado:** `demostrado`, y **no depende de hardware, ventana ni hipótesis de dureza**.
**Prueba:** `P-ZRX/P-COBERTURA/investigacion/INFORME.md` §3, Corolario 4.

**Qué descarta:** el registro de parcelas con maduración; toda «prueba de antigüedad» por compromiso;
y cualquier variante que ate recompensas a que unos bytes «existían antes».

**Qué NO dice:** que no se pueda comprometer la **cobertura** del objeto. Eso **sí es construible**
(íd. §7.3) — pero es identidad de lote, **no cambia el coste del sembrador**.

---

### R-3 · Determinista + público + paralelizable ⟹ indistinguible de regenerado

**Enunciado.** Si el objeto es función **determinista y pública** de datos públicos y su cómputo es
**paralelizable por unidad**, ningún esquema con verificación sucinta distingue «almacenado» de
«regenerado dentro del plazo». Es **simulación exacta**: los transcriptos son idénticos.

**Estado:** `demostrado`, **condicionado** a que el trabajo quepa en la ventana.
**Prueba:** `P-ZRX/P-COBERTURA/investigacion/INFORME.md` §3, Corolario 1. Verificado en fuente:
`plotting.rs:626-627` (`generate_parallel`) y `:659-665`.

**Qué descarta:** pruebas de posesión o de almacenamiento sobre el formato actual; auditorías por
muestreo (el tramposo regenera lo que se le pide).

**Vías de escape, y las dos cambian el objeto ploteado:** romper el **determinismo** (semilla secreta)
o la **paralelizabilidad** (sellado secuencial). La latencia y «materializar N a la vez» **no son
vías**: son desigualdades cuantitativas sobre hardware.

---

### R-4 · Toda exclusividad por identidad se evade partiendo el espacio

**Enunciado.** Cualquier regla «una identidad-X bajo un solo Y» —sea X la clave, el sector o
cualquier unidad— es derrotable **repartiendo el espacio** entre identidades, mientras crear una
identidad cueste lo mismo por byte. Por linealidad del ploteo más gratuidad de identidad.

**Estado:** `demostrado` (D9). **Prueba:** `research/dag-poas-balizas-auditoria.md:30-38,66-78`.

**Qué descarta:** exclusividad por clave o por sector, cuotas por identidad, detección estadística
por identidad, y cualquier variante que trate la identidad como recurso escaso.

**Qué NO dice:** que no exista salida. Dice que la salida exige un coste **no proporcional al
espacio** — y entonces aplica R-5.

---

### R-5 · «Coste no proporcional al espacio» es NECESARIO y **no suficiente**

**Enunciado.** El beneficio de evadir es **lineal** en el espacio; un coste **fijo** solo domina por
debajo de un tamaño. **Siempre existe una granja lo bastante grande para absorberlo**:
`τ_min = f*·(λIP T_h − c_b)`, proporcional al tamaño de la granja marginal.

**Estado:** `derivado`, con instrumento. **Prueba:** `P-ZRX/P-TASA/investigacion/INFORME.md` §2.3.

**Qué descarta:** tasas o depósitos fijos por identidad como defensa del umbral. **Corrige la lectura
de R-4:** la salida que aquel teorema nombraba **no basta**.

---

### R-6 · Ninguna condición de validez sobre `past(B)` obliga a publicar

**Enunciado.** En su rama privada **el atacante es la autoridad**: toda condición que el consenso
evalúe sobre `past(B)` se la fabrica dentro de su rama. Incluida la atestiguación por terceros.

**Estado:** `demostrado` en sus dos direcciones centrales; **declarado explícitamente como no
exhaustivo** sobre todas las condiciones imaginables. **Prueba:**
`P-ZRX/P-SECRETO/investigacion/INFORME.md` F1.

**Qué descarta:** cerrar `κ = 0` por la vía de la validez; compromiso previo de intención; exigir
historial reciente; exigir referencia a datos públicos —**ver lo público no obliga a publicar**—.

---

### R-7 · Anclar el reto al padre ⟹ grinding, y el umbral cae al 26,8941 %

**Enunciado.** Si el reto depende del padre seleccionado, cada punta es una lotería y el umbral cae a
`1/(1+e) = 26,8941 %`. No hay profundidad intermedia útil: `umbral(d)` crece hacia 1/2 sin
alcanzarlo, y el eje real (`I_slots`, `L_slots`) **no se puede mover** porque `L_slots ≥ F_slots`.

**Estado:** `derivado` del modelo BDK+19. **Prueba:** `research/dag-poas-ancla-de-finalidad.md:313-319`
y `P-ZRX/P-ANCESTRIA/investigacion/INFORME.md` F2, F5.

**Qué NO dice, y es importante:** **no se hereda automáticamente** a un recurso donde cada reintento
cueste (una pata de PoW). La condición exacta para que sí aplique: **que el reto pueda re-muestrearse
gratis**. Pero en ese caso aplica R-8.

---

### R-8 · El tiempo no es rival

**Enunciado.** Un VDF por rama **se paraleliza entre ramas**: dos núcleos, dos líneas, dos ramas. El
tiempo secuencial **no cuenta** como coste rival entre historias.

**Estado:** `derivado`. **Prueba:** `P-ZRX/P-RIVAL/investigacion/INFORME.md` F1 y H5;
`P-ZRX/P-SELLO/investigacion/PROGRESO.md` O5.

**Qué descarta:** VDF por bloque o por rama como mecanismo de rivalidad; **PoET** (es un VDF con
hardware de confianza: hereda esto y **añade** confianza en el fabricante); y el segundo VDF como
defensa del doble farmeo — sigue valiendo para la **ventana de adelanto**, que es otro problema.

---

### R-9 · «Partir cuesta» ⟺ «es regresiva»

**Enunciado.** Para una cuota `φ(f)` con `φ(0) = 0`: `N·φ(f/N) > φ(f)` para todo `N ≥ 2` **si y solo
si** `φ(f)/f` es estrictamente decreciente. La única familia neutral bajo partición es la **lineal**
`φ(f) = σ·f` — que por serlo **no impide la evasión**.

**Estado:** `demostrado` (identidad algebraica; incontrovertible, no profunda).
**Prueba:** `P-ZRX/P-TASA/investigacion/INFORME.md` §4.1.

**Qué descarta:** cualquier esquema que quiera encarecer la partición **sin ser regresivo**. Un tope
de espacio por identidad convierte la cuota en lineal a saltos: es la variante proporcional
disfrazada.

---

### R-10 · Una firma no prueba que el firmante vio nada

**Enunciado.** El verificador comprueba **que** alguien firmó, **nunca por qué**. «Firmar solo lo
visto» es **conducta del firmante, no regla de consenso**: no verificable desde `past(B)`,
sobornable, y una firma a ciegas es indistinguible de una informada.

**Estado:** `derivado`. **Prueba:** `P-ZRX/P-SECRETO/investigacion/INFORME.md` §1.2 (V1/V2).

**Qué descarta:** la atestiguación como ruptura del secreto; cualquier defensa que dependa de que un
tercero «solo firme lo que ha visto».

**Patrón transversal:** es **el mismo fallo** que `P-ZRX/P-POOLS/` encontró en los pools — el
operador compone el `pre_hash` y el cliente firma sin ver. **Mismo agujero, dos sitios.**

---

### R-11 · La cuota de peso NO está acotada por la fracción de bytes

**Enunciado.** `α_blue_work ≤ α_bytes` es **FALSO**. Con `f = 0,3` y eficiencia azul asimétrica, la
cuota del adversario es **6/13 = 0,4615** — amplificación **1,54×**.

**Estado:** `demostrado` bajo su hipótesis de eficiencia; **la revisión 1 del instrumento circuló con
la cota contraria**, favorable a la seguridad. **Prueba:**
`P-ZRX/P-PUENTE-ESPACIO-TASA/veritas/seguridad/espacio-tasa-v1/INFORME-CORRECCION.md` C1.

**Qué descarta:** razonar sobre umbrales en «fracción de disco» sin el puente. Y obliga a releer con
cuidado cualquier cifra previa expresada así.

---

### R-12 · La ocupación de s-buckets no es constante

**Enunciado.** Es **bimodal**: 9,0668 % de buckets vacíos y varianza **163,17×** la del modelo
«ocupación 1/2», porque `create_proofs` corta al llegar a `NUM_CHUNKS` y deja los buckets altos
vacíos **por construcción**. Una parcela de un sector **no tiene ninguna oportunidad en uno de cada
once slots**.

**Estado:** `medido` sobre el formato real, mecanismo `verificado en fuente`
(`chiapos.rs:251-252,56,260`). **Prueba:** `P-ZRX/P-PUENTE-ESPACIO-TASA/veritas/seguridad/espacio-tasa-v1/INFORME.md` §3.

**Qué descarta:** cualquier instrumento o regla que asuma ocupación constante `1/2` **en la cola**.
La media sí es exacta (`piezas/2`); la distribución, no.

**Vector abierto que se deriva:** el adversario elige `public_key` ⟹ elige `sector_id` ⟹ **sesga qué
bucket se le audita**, y puede caer en buckets densos pagando reploteo. **Sin medir.**

---

## Líneas rojas de proyecto (no son teoremas: son decisiones)

- **`AGENTS.md`:** no hay staking ni comités de decisión.
- **`AGENTS.md`:** una regla pendiente **no se implementa inventando un número**.
- **Decidido 2026-09-19/20:** validez del PoT **absoluta** (`C-FLU-13`). Una condición que dependa de
  **la vista del nodo** en vez de `past(B)` reintroduce la validez relativa y **abre el multistream**.
- **Ancla externa:** «ayuda al operador, **nunca regla de consenso**».

---

## Lo que NO está cerrado — para que esto no se lea como «todo es imposible»

1. **El frente de la oferta de `β`.** El doble farmeo exige que alguien **preste** espacio; con
   `β = 0` el umbral es `1/2` intacto. Es arquitectura y economía, no criptografía, y **el único
   cierre real de toda la serie salió de ahí** (`P-ZRX/P-POOLS/`). Sin estudiar: alquiler directo,
   farming gestionado, custodios.
2. **Bajar `F`.** `C-FIN-01` ya acota el daño a `d < F_slots`. Es la única palanca del consenso que
   reduce el ataque, y depende de `Δ` **medida en red real**.
3. **La cobertura del objeto caro** sí es construible (R-2, alcance).
4. **La composición multiplicativa** con un recurso rival donde la **mayoría honesta sea
   estructural** (no comprable): `P-ZRX/P-RIVAL/investigacion/INFORME.md` §3.4 deja esa rendija
   abierta, y su propio fichero de hipótesis marca cuál es la que decide. **Ver el Apéndice al final
   de este documento: la vía de la rivalidad está APARCADA, no refutada — nueve de doce recursos
   nunca se examinaron.**
5. **La magnitud del daño.** Sigue **sin poder medirse** hasta que el nodo esté cableado
   (`P-ZRX/P-PUENTE-ESPACIO-TASA/veritas/seguridad/espacio-tasa-v1/INFORME.md` §9, cinco dependencias de código inexistente). **No decidas un
   rediseño «porque el agujero es grande o pequeño»: hoy no se sabe.**

---

## Cómo usar este documento

1. Escribe la pieza que propones y **qué objetivo cumple**.
2. Pásala por R-1…R-12. Anota cuál choca y por qué.
3. Si choca con alguna, **está refutada**: anótala en el tablero con la restricción que la mata, para
   que nadie la reproponga.
4. Si las pasa todas, **merece encargo** — y el encargo se escribe declarando qué restricciones ya
   pasó, para que el ejecutor no las rehaga.
5. Si una restricción te parece mal, **atácala**: son resultados, no dogmas, y tres de ellas
   corrigieron creencias previas del propio repositorio.

---

## Apéndice · La vía de la rivalidad: **aparcada, no refutada**

> ⚠️ **Todo este apéndice es conjetura de Claude, de conversación, SIN VALIDAR por ningún encargo.**
> Está aquí para que no se pierda y para que **nadie lo trate como resultado**. Si algún día se
> encarga, se encarga con la premisa atacable, como se hizo con `P-ZRX/P-TASA/`.

**Por qué está aquí.** El 2026-09-23 se recorrió el catálogo de recursos buscando uno que fuera
**rival entre ramas**. Se propuso encargarlo; Katana redirigió a `κ = 0` (`P-ZRX/P-SECRETO/`), que era
la decisión correcta entonces. **Consecuencia: la vía de la rivalidad quedó examinada solo en dos
filas de doce.**

### El criterio propuesto (conjetura)

Para que un recurso sea rival entre ramas harían falta **dos** cosas:

1. **Indexación por rama** — consumirlo para la rama `A` tiene que ser una **acción distinta** de
   consumirlo para `B`. Si el consumo es el mismo acto, sirve a las dos.
2. **No duplicable comprando hardware** — si con el doble de máquinas tienes el doble del recurso, el
   atacante paga y listo.

**Y el nudo, que es la parte más conjetural:** (1) exige que algo de la rama entre en el consumo del
recurso, y en cuanto eso pasa, **o el atacante lo muele** —el 26,8941 % de R-7— **o el coste se
duplica con hardware** —R-8—. Las dos condiciones tirarían en direcciones opuestas.

**Nota de contraste:** `P-ZRX/P-RIVAL/` formalizó «rival» como **superaditividad (P4) más
proporcionalidad al peso**, que **no es el mismo criterio**. El de arriba sigue sin prueba.

### Estado real de cada recurso

| Recurso | Estado |
|---|---|
| Tiempo / VDF | **REFUTADO** (R-8) |
| Cómputo / PoW | **REFUTADO** para composición aditiva (`P-RIVAL`): no hay `θ` útil |
| Capital | Descartado **por política** (`AGENTS.md`), no refutado técnicamente |
| **IOPS / ancho de banda de disco** | **Sin examinar.** El `S ≈ 24` del multistream era el techo de IOPS de un SSD de 100 k: las lecturas son un flujo rival de verdad. Su talón: indexarlas por rama exige que el reto dependa de la rama, y ahí vuelve R-7 |
| **RAM simultánea** (memory-hard) | **Sin examinar.** Más cara de alquilar que CPU |
| **Ancho de banda de red** | **Sin examinar, y es el candidato con mejor pinta** — ver abajo |
| **Desgaste de SSD** | **Sin examinar.** Cumple las dos condiciones limpiamente (una escritura gastada no se recupera ni se alquila) pero **probarlo exige confiar en el firmware**, y eso es confiar en el fabricante: el mismo talón que mata a los TEE bajo el modelo de amenaza |
| **Espectro radioeléctrico** | **Sin examinar.** Rival localmente; necesita hardware y testigos (DePIN) |
| **Identidad verificada** | **Sin examinar.** No es físico; *proof of personhood* |
| Posición física | Descartado en conversación: presencia global del adversario |
| Calor, energía | Derivados del cómputo |
| Disco (stock) | Es el problema actual (R-1) |

**Nueve de doce sin examinar.**

### El candidato que conecta con la rendija ya anotada

**Ancho de banda de red.** Es rival por física —un byte enviado a una rama no se envía a otra—, no se
acumula y no exige capital previo. Y encaja **justo** en el punto 4 de «Lo que NO está cerrado»: en
composición **multiplicativa** la ventaja del doble farmeo **sí decrece** con `θ` cuando el honesto
tiene mayoría del recurso, y con PoW eso falla porque el hashrate **se compra** — pero **el ancho de
banda agregado de miles de nodos honestos no se compra**: la mayoría honesta sería **estructural**.

**Su talón conocido, y no es pequeño:** medirlo sin confiar en testigos es un problema abierto. Todo
lo que se conoce en esa dirección acaba dependiendo de verificadores que pueden ser del atacante — lo
mismo que hundió a la prueba de latencia.

### Una corrección de redacción, para que no se herede mal

Se escribió: *«la rivalidad encarece el ataque; solo la observabilidad lo impide»*. Es literalmente
cierto **y se lee mal**: puede entenderse como «la rivalidad no sirve», y eso es falso.

**Si el recurso es rival, el atacante que farmea dos ramas paga dos veces**: con el mismo recurso
tiene la mitad de peso en cada una. Eso no cierra el ataque, **pero encarecerlo proporcionalmente es
exactamente lo que mueve el umbral** —es la superficie `α*` de `P-ZRX/P-PRESTAMO/`—. Encarecer no es
cerrar, pero tampoco es nada.

### Qué haría falta para cerrar esto

Un encargo que **(a)** formalice el criterio y decida si el nudo es teorema o se rompe en algún caso,
**(b)** pase los nueve recursos sin examinar por él, y **(c)** evalúe el ancho de banda en composición
multiplicativa contra la hipótesis que decide: si la mayoría honesta agregada es realmente no
comprable. **Si el nudo resulta ser teorema, se cierra la familia entera de una vez** — como hizo
`P-TASA` con las cuotas.
