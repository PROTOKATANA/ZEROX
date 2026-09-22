# Solución candidata al problema de la reutilización del espacio entre ramas

**Fecha:** 2026-09-21 · **Autor del texto:** Codex · **Transcrito por:** Claude, a petición de Katana,
sin cambiar el contenido. **Estado:** candidata. **No es SPEC, no fija parámetros y no está validada.**
Contexto y mapa general de agujeros: `P-ZRX/T-ZRX/AGUJEROS-Y-SOLUCIONES.md`.

---

La solución más viable para ZEROX es:

> Registro previo de parcelas por lote + maduración + recompensas propias retenidas y condicionadas a
> permanencia + castigo únicamente por doble firma objetivamente demostrable.

No usaría PoW. Tampoco intentaría prohibir criptográficamente toda reutilización del espacio: con la
parcela actual no es posible sin rediseñarla por completo.

## Diseño concreto recomendado

### 1. Registrar la parcela completa

Cada lote obtiene un `PlotBatchId` que compromete:

```text
dominio de red
clave del granjero
raíz de los bytes codificados
cardinalidad/capacidad
versión de parcela
época de registro
```

No basta registrar `SectorId`, `history_size` o una lista de identificadores.

### 2. Periodo de maduración

El lote no produce peso inmediatamente. Debe esperar `M` slots y superar retos impredecibles durante ese
periodo.

Esto impide registrar capacidad después de conocer el reto y encarece el alquiler instantáneo.

### 3. Vincular cada solución al lote activo

Cada bloque demuestra que su pieza pertenece al `PlotBatchId` registrado. La identidad económica del
billete debe ser independiente de padres, coinbase y sello:

```text
TicketId =
  H(dominio, slot, PlotBatchId, sector_index, piece_offset)
```

La definición definitiva entre flujos sigue necesitando análisis.

### 4. Retener recompensas propias

Parte de cada recompensa queda bloqueada y vinculada al `PlotBatchId`. Se libera gradualmente si la
parcela responde a auditorías futuras.

No se exige comprar monedas, por lo que no es staking. La garantía procede exclusivamente de recompensas
ya ganadas.

### 5. Infracción estrecha

Solo se castiga una evidencia inequívoca:

```text
mismo TicketId y slot
+ dos pre_hash diferentes
+ dos firmas válidas
+ ambas cabeceras válidas en su contexto
```

No se castiga simplemente «estar en dos ramas», porque eso podría alcanzar reorgs, particiones o bloques
DAG honestos.

### 6. Castigo prospectivo

Cuando la evidencia entra en la historia seleccionada:

- se pierden las recompensas aún retenidas;
- el lote queda inhabilitado;
- debe replotearse y volver a madurar;
- no se revierten pagos ya finalizados.

### 7. Auditorías de permanencia

Aunque no haya doble firma, borrar la parcela o dejar de responder impide liberar las recompensas
retenidas. Esto cubre permanencia y alquiler corto, no solo equivocación.

## Por qué es la opción más viable

Ataca simultáneamente los problemas más reales:

- registro posterior al reto;
- sembrador;
- alquiler de horas;
- producir, cobrar y borrar;
- duplicación exacta del mismo billete;
- claves desechables sin historial económico.

Y conserva las restricciones principales:

- PoSpace-Time + DAG;
- sin staking comprado;
- sin comité;
- sin ASIC/energía PoW continua;
- entrada posible para pequeños granjeros mediante registros agrupados.

## Lo que no debe prometer

Este mecanismo no impide físicamente que una parcela madura sea leída para dos ramas. Tampoco cubre
perfectamente:

- trabajar ramas diferentes en slots alternos;
- retos distintos de flujos distintos;
- parcelas propias preparadas con antelación;
- una rama privada nunca revelada;
- censura temporal de la prueba;
- un doble gasto cuyo beneficio supere lo confiscable.

Por eso el consenso base debe seguir siendo seguro suponiendo que el doble farming es barato. El registro
y las recompensas retenidas son una capa adicional para elevar el coste del soborno, no el fundamento del
umbral de seguridad.

## Decisión

Mi recomendación inequívoca es:

> Adoptar como candidata B+H —registro completo con edad más activación/permanencia mediante recompensas
> retenidas— y añadir la doble firma estrecha como complemento.

No adoptaría:

- PoW híbrido;
- expulsión basada solo en una clave;
- caducidad más corta como solución;
- penalizar cualquier producción en ramas diferentes;
- una supuesta «exclusividad física» de la parcela actual.

Si se exigiera como requisito absoluto que el mismo recurso no pueda beneficiar dos ramas, entonces la
respuesta sería PoW material o una nueva PoRep ligada a la ancestría. Pero eso sería otro diseño de
consenso. Para el ZEROX decidido, B+H es la solución implementable con mejor relación entre seguridad
añadida, compatibilidad y coste.

---
---

# Anexo · Correcciones y condiciones de Claude

**Esto NO forma parte del texto de Codex.** Lo añade Claude el 2026-09-21 a petición de Katana. Claude
adoptaría el diseño de arriba **como candidata, tal cual**, con las cuatro condiciones de §A.2 antes de
tratarlo como diseño. Etiquetas como en `P-ZRX/T-ZRX/AGUJEROS-Y-SOLUCIONES.md` §0.

## A.1 · La corrección previa: qué rompe de verdad el doble farmeo

**Claude afirmó que, con doble farmeo, «el atacante no necesita discos propios». Es FALSO**, y lo corrigió
Codex. Con el espacio total normalizado a 1, `α` = espacio propio del atacante (retirado de la rama
pública) y `β` = espacio honesto que trabaja en **ambas** ramas:

```text
rama pública ≈ 1 − α          rama privada ≈ α + β
la privada crece más deprisa  ⟺  β > 1 − 2α
```

Con `α = 0` haría falta `β > 1`: **imposible**; duplicando trabajo ajeno, como mucho se empata. Si los
reclutados **abandonan** la pública (alquiler exclusivo), reaparece el umbral normal: atacante más
alquilados deben superar el 50 %.

**[LECTURA DE CLAUDE]** La misma fórmula, leída como umbral: **`α* = (1 − β)/2`**.

| `β` (espacio honesto que farmea doble) | 0 | 1/3 | 1/2 |
|---|---:|---:|---:|
| umbral `α*` | **0,50** | 0,33 | 0,25 |

El `α* = 1/2` de CRP-v0.1 (`veritas/seguridad/coste-rama-privada-v1/`) es el caso `β = 0`. **No está
demostrado que el umbral baje; lo que la fórmula dice es que baja en proporción a `β`, y `β` es lo
desconocido**: cuántos granjeros racionales farmearían doble si es gratis y sin riesgo. Seguir una segunda
rama le cuesta al granjero verificar su PoT, **0,092–0,190 núcleos**; producirlo cuesta **1,56 núcleos** y
lo pone el atacante (`veritas/consenso/puerta-cobertura-v1/INFORME.md`). Los «24 flujos por SSD» son solo
una cota de IOPS, no el coste completo.

Otras tres frases de Claude que se retiran, también por la crítica de Codex:

- **«Le cuesta la parcela»** era exagerado: se pierden **elegibilidad, recompensa retenida y tiempo de
  replot y maduración**; los discos y los bytes siguen ahí. Y caben fragmentación entre claves o lotes,
  parcelas maduras de reserva, censura de la prueba si el atacante gana, y un doble gasto que valga más
  que todo lo retenido.
- **«Los reintentos gratis ya están descontados en la finalidad»** sobraba: `CONTINUIDAD.md:179` dice que
  los riesgos históricos son de una carrera nominal, **no del pago DAG integrado**.
- **«PoW es la única familia»**: la propiedad necesaria es **trabajo fresco, no reutilizable y ligado a la
  ancestría**; PoW es solo la única familia **madura** que la tiene.

## A.2 · Las cuatro condiciones

### C1 · La frase clave de Codex es un requisito, no un hecho

*«El consenso base debe seguir siendo seguro suponiendo que el doble farming es barato.»* Es el encuadre
correcto, **y nadie lo ha comprobado**: por `α* = (1 − β)/2`, si el doble farmeo es barato `β` puede ser
grande. **Primer encargo: modelar el juego `α + β`** — doble publicación frente a alquiler exclusivo,
varianza corta (el agujero A2 de `AGUJEROS-Y-SOLUCIONES.md`), retención selectiva y soborno condicionado
al éxito. Ese modelo es también el que dice **cuánta recompensa retener y durante cuánto tiempo**: como
mínimo, el vesting debe durar más que la ventana en que la evidencia puede aparecer (del orden de `F` más
margen), o el granjero ya habrá cobrado cuando llegue la prueba. Criterio de éxito de Codex, que se
conserva: *pérdida esperada del granjero reclutado > soborno necesario*, **incluyendo** censura,
fragmentación y fallos honestos.

### C2 · Las auditorías por muestreo de piezas probablemente NO demuestran almacenamiento

`P-ZRX/P-INTENTO/` midió que **regenerar una pieza cuesta 0,8 s de un núcleo** (25 tablas por segundo en
una CPU de 16 núcleos) **[MEDIDO, sin revalidar]**. Un granjero podría **borrar la parcela, conservar
solo el árbol de compromisos y regenerar la pieza pedida** cuando le auditen: seguiría liberando lo
retenido sin almacenar nada. Afecta a los pasos 2 y 7 del diseño.

**[LECTURA DE CLAUDE — hipótesis por comprobar]** La prueba de permanencia tendría que exigir lo mismo
que exige farmear: **responder en cada slot sobre la parcela entera**, que es justo lo que no se puede
regenerar a tiempo. Forma posible: **pruebas parciales** —soluciones con un umbral más fácil— cuyo número
por periodo estima estadísticamente el tamaño real del lote, como hacen los pools de Chia para medir el
espacio de sus miembros **[NO VERIFICADO]**. **Si se sostiene, podría sustituir a la prueba criptográfica
de cobertura completa** (la «C1» de `P-ZRX/P-SEMBRADOR/`) que hoy bloquea todo el paquete. Por
comprobar: la estimación estadística y su varianza para lotes pequeños; qué parte de los parciales va a
la cadena (todos no caben: muestreo o agregación); y que un sembrador con ventana de adelanto no pueda
fabricarlos más barato que almacenando (debería exigirle replotear el lote entero una y otra vez: cruzar
con las cifras de P-INTENTO).

### C3 · El castigo accidental a granjeros honestos

Un granjero con **dos nodos o *harvesters* redundantes sobre la misma parcela**, o que **reinicia
perdiendo el estado**, puede firmar el mismo `TicketId` y slot con dos `pre_hash` distintos **sin mala
fe**. Con un bloque por segundo en un DAG puede ser frecuente. Es el *slashing* accidental que ya sufre
PoS, y allí se resuelve con una **protección en el productor**: un registro persistente de lo firmado por
lote y slot, que se niega a firmar dos veces. ZEROX necesitaría el equivalente como requisito de
producción, y decidir si el primer castigo es leve o gradual. Codex no lo trata.

### C4 · Quién paga el alta de quien entra sin monedas

Agrupar registros abarata el alta, pero no responde a la pregunta. Si registrar un lote exige una
transacción con tarifa, **choca con el primer valor del proyecto** («entrar no exige tener monedas»).
Salida natural, sin estudiar: que el alta se pague **con una prueba de espacio**, no con tarifa ni con
PoW, y que el antispam del registro salga de ahí.

## A.3 · Una hipótesis a favor de la infracción estrecha, bajo el perfil 1a

**[LECTURA DE CLAUDE — por comprobar]** Codex advierte de que la infracción estrecha «cubre únicamente
duplicar la misma oportunidad». Bajo el perfil **1a** (`L_slots ≥ F_slots`, `C-FLU-01`) eso puede ser
casi todo lo que importa: dentro de la ventana en que una reorganización es posible (profundidad `< F ≤ L`)
**las anclas de las inyecciones activas son anteriores a la bifurcación**, luego las dos ramas comparten
flujo y **tienen los mismos retos**. La clave económica propuesta en el repositorio (IDV-01,
`veritas/consenso/identidad-disponibilidad-v1/CONTRATO-VALIDACION.md`:
`(dominio, slot, public_key, sector_index, history_size, piece_offset)`) **no contiene ni los padres ni
la rama**. Entonces quien farmea doble **duplica necesariamente la misma oportunidad**, y la infracción
estrecha lo alcanza. Su única salida es usar cada oportunidad ganadora en **una sola** rama, que es
repartir su espacio entre ramas: **exclusividad por oportunidad, impuesta económicamente**, y el umbral
vuelve hacia el 50 %.

Riesgos de la hipótesis: un atacante que **prepare con antelación una divergencia de ancla** (el caso de
partición de flujo, donde los retos ya difieren); que IDV-01 está marcada **«condicionada»**; la censura
de la prueba; y C3.

## A.4 · Orden de trabajo que propone Claude

1. **Modelo del juego `α + β`** (cálculo; barato; dice cuánto castigo hace falta y si el consenso base
   aguanta el doble farmeo barato). Incluye comprobar la hipótesis de §A.3.
2. **Comprobar si una prueba de permanencia por parciales aguanta la regeneración** (C2) y si puede
   sustituir a la prueba de cobertura completa.
3. **Prototipo fuera del SPEC** del paquete entero, con la protección del productor (C3) y el alta sin
   monedas (C4) dentro.

Nombre correcto de lo que se construye, en palabras de Codex: **responsabilidad económica y mitigación
del alquiler**, no exclusividad física del espacio ni garantía nueva de finalidad.
