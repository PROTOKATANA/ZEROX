# Doble farmeo: estado al 2026-09-23 — LEER ANTES DE PROPONER NADA

**Sesión:** 2026-09-22 noche → 2026-09-23. **Valida:** Claude. **Decide:** Katana. **Ejecutan:** los
encargos de `P-ZRX/`.

Este documento existe para que nadie repita el trabajo de ocho encargos. **No sustituye a los
informes**: cada fila remite al suyo. Recoge (1) qué está cerrado y por qué, (2) los hallazgos
**nuevos** que no viven en ningún otro sitio, (3) los defectos que quedaron pendientes de corregir,
y (4) qué decide Katana.

> **El resultado de la sesión, en una frase:** el doble farmeo **no se cierra sin dejar de ser PoST
> puro**, y eso ya no es una intuición: son siete vías refutadas con números más dos resultados
> estructurales que explican por qué. El octavo encargo, que debía decir **cuánto duele**, concluye
> que **no es medible hasta que el nodo esté cableado**.

---

## 1 · Las ocho vías, y dónde está la prueba de cada cierre

| Vía | Por qué cayó | Prueba |
|---|---|---|
| **Identidad de billete por pieza** | `chunk` no es grado de libertad: un reto fija **un** s-bucket y cada pieza aporta a lo sumo un chunk. Las tres identidades particionan igual; beneficio ≈ 0,6 % y rompe `C-FLU-12` | `P-ZRX/P-IDENTIDAD/investigacion/INFORME.md` §4, resultado 7 |
| **Castigo / retención por clave** | El `β_d` que cruza la deriva es **0,34** y el **67,5 %** del espacio está en claves de saldo < 0,01 ⇒ **soborno cero**. Claves nuevas gratis | `P-ZRX/P-CLAVE/investigacion/INFORME.md` F3, F4, F6 |
| **Castigo con la parcela como objeto (7b)** | Cierra la grieta de las claves pobres, pero muere contra `κ = 0` y replotear con GPU cuesta 1,4 h/TiB | Análisis de sesión; ficha en `P-ZRX/PROPUESTAS-VIABLES.md` fila 7b |
| **Registro de parcelas con maduración** | **Imposibilidad demostrada.** Todo predicado sobre el *valor* del objeto es invariante en el tiempo ⇒ **ningún compromiso fecha nada** (Cor. 4, incondicional) | `P-ZRX/P-COBERTURA/investigacion/INFORME.md` §3 |
| **Anclaje del reto a la ancestría** | `d = 0` da **26,8941 %**; no hay profundidad intermedia útil y el eje real (`I_slots`, `L_slots`) no se puede mover porque `L_slots ≥ F_slots` | `P-ZRX/P-ANCESTRIA/investigacion/INFORME.md` F2, F5 |
| **Tasa fija por identidad** | No toca el doble farmeo (cofarmar usa **una** identidad); solo habilita exclusividad, que necesita evidencia ⇒ hereda `κ`. Y «partir cuesta» ⟺ «es regresiva» | `P-ZRX/P-TASA/investigacion/INFORME.md` §2.1, §4.1 |
| **Trabajo rival (pata de PoW)** | `V = β_d/2 + β_x` **invariante en `θ`** en la aditiva; con compuerta **sube**. El cierre exige `θ = 1` con `ρ = 1` | `P-ZRX/P-RIVAL/investigacion/INFORME.md` F2-F4 |
| **Sellado asimétrico ligado a la rama** | Dicotomía temporal sin solución: lo que cabe en el presupuesto del honesto materializa `1,8·10⁻⁵` de la parcela; lo que haría falta cuesta 5,7·10⁴-1,7·10⁵ veces ese presupuesto | `P-ZRX/P-SELLO/investigacion/INFORME.md` F3 |

**Los dos resultados estructurales que explican el conjunto:**

1. **La raíz.** En PoW el hash compromete a los padres **y** es el recurso escaso; en PoST se separan
   (`veritas/consenso/poda-post-v1/INFORME.md:44-56`, refinado en `PROCEDENCIA.md:110-119`).
2. **El teorema de exclusividad.** Toda regla por identidad se evade partiendo el espacio
   (`research/dag-poas-balizas-auditoria.md:30-38,66-78`).

**Y la pared común de toda la familia del castigo:** no hay región frente a `κ = 0` —el atacante
publica solo la rama ganadora— ni frente a censura total (`P-ZRX/P-CLAVE/…` F6).

---

## 2 · Hallazgos NUEVOS de esta sesión (esto no está en ningún otro sitio)

**H-1 · La salida que el teorema nombraba no basta.** «Coste no proporcional al espacio» es
**necesaria y NO suficiente**: el beneficio de evadir es **lineal** en el espacio, así que un coste
**fijo** solo domina por debajo de un tamaño. Cierra la familia entera, no una variante.
`P-ZRX/P-TASA/investigacion/INFORME.md` §2.3 (hallazgo R2).

**H-2 · Un VDF por rama NO es rival; un PoW sí.** Con dos núcleos se corren dos líneas de VDF y se
farmean dos ramas; la tasa de hash, en cambio, se reparte. **Por tanto el descarte del 26,8941 % de
«trunks» —que era un VDF— no se hereda automáticamente a una pata de PoW.** Condición exacta bajo la
que sí se heredaría: si el reto de la pata pudiera re-muestrearse gratis. `P-RIVAL` F1 y H5.

**H-3 · `α_blue_work ≤ α_bytes` es FALSO.** El repositorio daba por buena una cota que no existe: con
`f = 0,3` y eficiencia azul asimétrica la cuota del adversario es **6/13 = 0,4615**, amplificación
**1,54×**. **La revisión 1 del puente circuló con esa cota**; la revisión 2 la retira.
`P-ZRX/P-PUENTE-ESPACIO-TASA/veritas/seguridad/espacio-tasa-v1/INFORME-CORRECCION.md` C1.

**H-4 · La ocupación de s-buckets no es constante: es bimodal.** **9,0668 %** de buckets vacíos y
varianza **163,17×** la del modelo «ocupación 1/2». **Causa verificada en fuente:** `create_proofs`
recorre buckets en orden creciente y hace `break 'outer` al llegar a `NUM_CHUNKS`
(`PDF/autonomys-subspace/shared/ab-proof-of-space/src/chiapos.rs:251-252,56,260`), así que **5.794 de
los 5.942 vacíos son cola estructural** por encima del bucket **59.741**. Es truncamiento
determinista, no azar. **Consecuencia:** una parcela de un sector no tiene ninguna oportunidad en
**uno de cada once slots**. **Cualquier instrumento que asuma ocupación constante 1/2 está mal
calibrado en la cola.**

**H-5 · Vector nuevo, sin medir: sesgo de tasa eligiendo la clave.** El bucket auditado lo fija
`sector_id XOR global_challenge` y `sector_id` deriva de `public_key`, así que **un adversario que
elige su clave puede sesgar su tasa por encima de la media pagando reploteo**. Y `verify_solution`
**deriva el `sector_id` de la propia solución y no lo contrasta con nada**. No está en el mapa de
agujeros. `P-ZRX/P-PUENTE-ESPACIO-TASA/veritas/seguridad/espacio-tasa-v1/INFORME.md` §3.

**H-6 · La finalidad ya acota el daño, y bajar `F` es la única palanca del consenso que funciona.**
`C-FIN-01` limita la selección a `d < F_slots` (`SPEC.md:1832-1834`): **el doble farmeo solo sirve
dentro de esa ventana**. No lo evita; lo vuelve inútil más allá de `F`. Bajar `F` depende de `Δ`
medida en red real.

**H-7 · El frente que nadie ha atacado: la oferta de `β`, no el mecanismo.** Los ocho encargos
atacan el **mecanismo**. Pero el doble farmeo exige que alguien **preste** espacio: con
`β_d = β_x = 0` el umbral es `1/2` intacto. Las defensas por el lado de la oferta son arquitectura y
economía, no criptografía, y **una ya funcionó** (`P-ZRX/P-POOLS/`: el operador hostil dejaba de
poder firmar por sus granjeros). Quedan sin estudiar el alquiler directo, el farming gestionado y los
custodios. **Es el único frente con expectativa razonable.**

**H-8 · Corrección a una cita que circulaba.** La afirmación de que Filecoin trata «minar varias
ramas con el mismo almacenamiento» como problema abierto **no se sostiene**: el ticket *«has to be
drawn from a finalized block»*, luego es el mismo para todas las ramas a esa altura y **no separa
forks concurrentes**. 29 fuentes archivadas en `P-ZRX/P-SELLO/investigacion/evidencia-fuentes/`. Y no
existe ningún paper de *Updatable Encryption* de Boneh–Liskov–Pass (la atribución correcta es BLMR).

---

## 3 · Descartado en conversación, sin encargo — no lo redescubras

- **Compromiso previo de intención («pre-antelación»).** Para dar detectabilidad tendría que atar a
  la rama **y** publicarse en la cadena pública. Pero forzar a elegir rama convierte `β_d` en `β_x`,
  y `β_x` **baja el umbral el doble** (`P-ZRX/P-PRESTAMO/…` F1, `demostrado`): con `β = 0,2`, `α*`
  pasa de 0,40 a 0,30. Más: diluvio de compromisos y falsos positivos en particiones.
- **Stake proporcional.** Cierra, pero es PoS y contradice `AGENTS.md`. Lo que lo hace funcionar en
  PoS no es el colateral: es que **el conjunto de validadores es conocido y la participación
  obligatoria**, así que la rama privada deja rastro. Importar eso es dejar de ser PoST.
- **Cambiar el fork choice.** No toca el problema: el doble farmeo es del **recurso**, no del orden.

---

## 4 · Defectos pendientes de corregir en las entregas validadas

Ninguno invalida su resultado; todos rompen trazabilidad o inducen a error a quien los herede.

| Encargo | Qué corregir |
|---|---|
| `P-ANCESTRIA` | «Cuatro rutas independientes» son **tres** (O1 reutiliza el mismo `Lambda`); 3 tests tautológicos; **`modelo.jl:180` rotula `d = D_INF` como «el diseño de hoy»**, que es lo que el propio informe niega; la fila B3 (niveles de poda) **no tiene artefacto detrás**; citas por línea desfasadas ~3 por edición concurrente del SPEC |
| `P-TASA` | Encuadre del titular (parte el alcance incondicional del condicional); siete decimales sobre una entrada de tres cifras; «tres rutas» es generoso; un `typemax` publicado como dato |
| `P-RIVAL` | **El titular vale solo para la composición aditiva** (en la multiplicativa hay dilución si el honesto tiene mayoría de trabajo); test de la identidad central **tautológico**; conteos que no cuadran (**1.112 vs 1121**, **5 vs 7** defectos); **`H1` cita `IDV-01` como vía viva sin mencionar que `P-IDENTIDAD` la refutó** |
| `P-SELLO` | `INFORME.md:140` cita `resultados/F2-materializacion.tsv`, **que no existe**; los datos están en `F2-religadura.tsv` |
| `P-PUENTE-ESPACIO-TASA` | Dice «cero por encima de ≈59 738»; el último bucket ocupado real es **59.741**. Y el uso de **Rust** —justificado, porque enlaza contra el clon fijado y llama a su API pública— **no está argumentado como desviación de LINEO** en el `METODO.md` ni el `CONTRATO.md` de ese instrumento |

---

## 5 · La cifra que falta, y por qué no se puede obtener todavía

`P-PUENTE-ESPACIO-TASA` §9 responde **no** a «¿podemos cuantificar la caída del umbral?», y sus cinco
razones son **todas código que no existe**: la verificación completa no se ejecuta en ninguna ruta, la
admisión PoST+DAG no está implementada, sin `β` no hay tasa de trabajo azul, y sin el controlador de
rango y las reglas de flujo no se sabe si dos retos sobre la misma parcela son siquiera admisibles.

**No es una limitación del instrumento: es que la magnitud no es medible hasta que el nodo esté
cableado.** El instrumento sí mide, con el código real, el tramo **bytes → candidatos por slot**.

**Consecuencia de orden:** el trabajo que desbloquea todo lo demás —la cifra del umbral, `Δ` real
para bajar `F`, y poder medir H-5— es el **cableado**, que avanza en paralelo (`crates/zx-pot/`,
`crates/zx-consensus/src/pot.rs`).

---

## 6 · Lo que espera a Katana

1. **Las tres ramas de `P-COBERTURA`** (`P-ZRX/P-COBERTURA/investigacion/DECISIONES-PENDIENTES.md` D1): cambiar el objeto ploteado
   (semilla secreta o sellado), registro parcial sin prometer preexistencia, o aceptar y tarifar.
2. **D1-D8 de `P-POOLS`**, empezando por atar la coinbase a `sol.public_key`.
3. **Trasladar `C-RET-01…11` de `P-RANGO` al SPEC**, y fijar sus valores.
4. **`ρ_max` y el segundo VDF**, pendientes desde el 2026-09-08.
5. **Qué hacer ahora que la magnitud no es medible:** seguir cableando y medir después, o decidir a
   ciegas. **Recomendación de Claude:** lo primero.

---

## 7 · Si solo vas a leer tres cosas

0. **`P-ZRX/T-ZRX/LIBRO-DE-RESTRICCIONES.md`** si lo que vas a hacer es **proponer una pieza nueva**:
   son las doce restricciones duras con su prueba y su alcance. Filtra la idea ahí antes de gastar un
   encargo.
1. Este documento.
2. `P-ZRX/PROPUESTAS-VIABLES.md` — el tablero, con cada propuesta, su fase y su bitácora.
3. `P-ZRX/T-ZRX/AGUJEROS-Y-SOLUCIONES.md` — el mapa de agujeros, anterior a esta sesión y **todavía
   válido salvo en lo que este documento corrige**.

---

## 8 · Aviso de coherencia: qué documentos NO reflejan esta sesión

- **`TAREAS.md` y `SPEC.md` no se han tocado.** Su §2.10 y su §17 describen el estado **anterior** a
  estos ocho encargos: no recogen ninguna de las ocho refutaciones ni los hallazgos H-1…H-8. Si los
  lees como estado actual, te quedarás corto. El estado vivo es este documento más el tablero.
- **Hay un encargo de cableado corriendo en paralelo** que sí toca `crates/` (`crates/zx-pot/`,
  `crates/zx-consensus/src/pot.rs`, tests de PoT), `ci/` y el propio `SPEC.md`. **Ese trabajo no lo
  ha validado Claude** y no se describe aquí. Al comprobar zonas de escritura, los ficheros marcados
  `M` o `??` en `crates/`, `ci/`, `Cargo.*` y `README.md` son suyos, no de los encargos de `P-ZRX/`.
- **Efecto secundario a tener en cuenta:** varias citas por número de línea a `SPEC.md` hechas
  durante la sesión se desplazaron por esas ediciones concurrentes. **Los IDs de regla son fiables;
  los números de línea, no.** Cita siempre por ID.

---

## 9 · Romper el secreto (`κ = 0`) — INTENTADO Y CERRADO (2026-09-23)

**Decisión de Katana, 2026-09-23:** *«es preferible ganar seguridad antes que garantizar un
secreto»*. De ahí salió **`P-ZRX/P-SECRETO/`**, que se ejecutó y **cerró la vía**:

> **RESULTADO: el obstáculo ES un teorema.** Ninguna condición de validez evaluable sobre `past(B)`
> obliga a un productor a publicar. **La atestiguación por terceros no es contraejemplo**, porque el
> firmante puede firmar **a ciegas** (V1) y **el verificador no puede distinguir una firma V1 de una
> V2**: puede comprobar *que* alguien firmó, nunca *por qué*. «Firmar solo lo visto» (V2) es
> **conducta del firmante, no regla de consenso** — no verificable y sobornable.
>
> **Y muere además por viveza:** `P(la ronda de k firmas cabe en el slot) = 0,219` con `k = 4`,
> `h = 3`, `Δ = 0,26 s`, y `10⁻⁴` con `Δ = 0,60`; la abstención del atacante corta la producción a
> `(1−α)^k` **gratis** (20 % con `α = 0,33`); y con `p = 0,9` de nodos despiertos mueren el **57 %
> de los slots sin atacante alguno**. Recomendaciones del informe: NO a la atestiguación, NO a la
> tabla de poder, NO al ancla externa, **SÍ al frente de la oferta de `β`**.
>
> **Conexión que el informe no hace (Claude):** la firma a ciegas es **el mismo fallo estructural
> que `P-ZRX/P-POOLS/` encontró en los pools** — el operador compone el `pre_hash` y el cliente
> firma sin ver. Mismo agujero, dos sitios. Cualquier defensa futura que dependa de que alguien
> firme «solo lo que ha visto» choca con esto.

**Lo que sigue vivo, y este encargo lo confirma:** el frente de la **oferta de `β`** (H-7). El
secreto no se rompe por el lado de la validez.

**Contexto de por qué se intentó:**

**El razonamiento que lo abre** (de Claude, **sin validar**): las siete defensas de castigo no
cayeron por el recurso, cayeron porque el atacante **opera en secreto**. Un recurso rival que se
consuma en privado sigue sin dejar rastro: **la rivalidad encarece el ataque; solo la observabilidad
lo impide.** Por eso la pregunta deja de ser «¿qué recurso es rival?» y pasa a ser **«¿qué puede
exigirse a un productor que sea imposible de hacer en secreto?»**.

**El obstáculo que el encargo debe decidir primero:** *en su rama privada, el atacante es la
autoridad* — toda condición evaluada sobre `past(B)` se la fabrica él dentro de su rama. Si eso es
teorema, romper el secreto **exige** información que el atacante no pueda producir, y solo hay tres
fuentes: **(a) otros participantes**, **(b) una cadena externa**, **(c) el tiempo físico**. **La (c)
ya está cerrada**: el tiempo no es rival (dos núcleos, dos ramas).

**Las dos líneas rojas que esto roza, y que el encargo NO revoca:** `AGENTS.md` prohíbe los comités
de decisión, y el ancla externa está catalogada como «ayuda al operador, nunca regla de consenso».
Lo que se pide es determinar si la distinción entre **atestiguar** y **decidir** se sostiene
técnicamente, y cuantificar el precio — la calificación la hace Katana.

**Donde puede morir, y hay que mirarlo antes que nada:** la **viveza**. Exigir firmas de terceros
convierte un problema de seguridad en uno de disponibilidad. Con `τ = 1 s` y `Δ = 0,26-0,60 s`,
¿cabe una ronda de recogida de `k` firmas en el slot? Y un atacante que **censure las respuestas**
podría parar la cadena honesta **sin tener espacio**.
