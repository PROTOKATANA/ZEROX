# FALSOS-POSITIVOS — conductas honestas que producen la misma evidencia

**Qué se cataloga.** Conductas **sin mala fe** que producen exactamente
`mismo TicketId y slot + dos pre_hash distintos + dos sellos válidos + ambas cabeceras válidas en su
contexto`, que es la infracción estrecha de `P-ZRX/P-EQUIVOCACION/CANDIDATA.md` §5.

**Etiquetas:** `verificado en fuente` (la regla que lo permite está abierta y citada) · `derivado`
(de las reglas escritas, con el razonamiento) · `estimado` (frecuencia como **función**, sin número
inventado) · `propuesto` (la defensa). Ninguna frecuencia se da como cifra: el encargo §3 pide
«como función, no como número inventado», y la tasa real depende de parámetros que **no están
fijados** (`SPEC.md` §7.3).

**Notación de frecuencia.** `α` = fracción de espacio del agricultor; `λ` = tasa de bloques de la red
(≈ 1 por slot en el perfil A″, `SPEC.md` C-SLOT-01); `n` = número de nodos/*harvesters* sobre la
misma parcela; `r` = tasa de reinicios por nodo y unidad de tiempo; `ρ_reorg` = tasa de
reorganizaciones; `S_max := S_max_slots`. La probabilidad de que el agricultor gane un slot dado es
`≈ α`; la de que **dos** de sus nodos produzcan en el mismo slot y el mismo billete, `≈ α` si ambos
están vivos (encuentran **el mismo** ganador porque el reto es el mismo, `P3`).

---

## 1 · Catálogo exhaustivo

### FP1 · Dos nodos o *harvesters* redundantes sobre la misma parcela, con vistas distintas de las puntas

- **¿Posible con las reglas escritas?** **Sí**, y es el caso dominante. `C-GD-10` dice que el
  productor toma hasta `max_block_parents = 15` puntas recorriendo una **cola de candidatos
  barajada** y que «el resto del conjunto **MAY** variar entre nodos y entre bloques: es la única
  regla de esta sección que **no** es determinista, y no lo es a propósito». Dos nodos con la misma
  parcela, el mismo billete ganador y puntas ligeramente distintas producen **dos `pre_hash`**.
  `verificado en fuente` (`SPEC.md` C-GD-10) + `derivado`.
- **Frecuencia (función).** Con `n` nodos sobre la misma parcela y ambos vivos:
  `P(evidencia por slot ganado) → 1` cuando `n ≥ 2`, porque el ganador es **el mismo** en los dos
  (mismo reto, misma parcela) y lo único que difiere son los padres. La tasa de slots afectados es
  `≈ α·λ` por unidad de tiempo (los slots que el agricultor gana), **no** una rareza de cola.
  `estimado`.
- **¿Qué la evita?** Sólo el firmante seguro del §3. Ninguna regla de consenso la evita, porque
  —`C-GD-10` *dixit*— la elección de padres **no es determinista a propósito**: el barajado es lo que
  impide perder 14–21 bloques honestos por slot en una red cargada.
- **Nota importante.** El barajado **no se puede quitar** para arreglar esto: quitar el barajado
  cambia un falso positivo por una pérdida sistemática de bloques honestos (`SPEC.md` C-GD-10, nota
  «Sin el barajado se pierden bloques honestos para siempre, y está medido»).

### FP2 · Reinicio con pérdida de estado que vuelve a firmar el mismo slot

- **¿Posible?** **Sí.** Tras reiniciar, el nodo reconstruye su punta (distinta de la que tenía),
  vuelve a encontrar el mismo ganador para el mismo slot y firma otra vez.
- **Frecuencia (función).** `≈ r · α · λ` por nodo y unidad de tiempo, más alta si el reinicio cae
  dentro de la ventana en que el nodo aún puede producir para ese slot (`S_max` slots, `C-GD-04`).
  `estimado`.
- **¿Qué la evita?** El firmante seguro, **si** el registro sobrevive al reinicio (§3.3).

### FP3 · Cambio de rama o adopción del flujo rival (`C-FLU-22`) seguido de producción para un slot todavía dentro de `S_max`

- **¿Posible?** **Sí.** `C-FLU-22` permite **adoptar** la rama rival dentro de la ventana, y
  `C-FLU-18` obliga al nodo sin cadena previa a aplicar la selección ordinaria. Tras adoptar, la
  punta cambia y el nodo puede producir para un slot **pasado** mientras
  `slot(B) − slot(sp(B)) ≤ S_max` (`C-GD-04`) y `pot_bundle_count == slot(B) − slot(sp(B)) ≤ 150`
  (`C-HDR-07`). Si ese slot ya lo firmó en la rama abandonada, hay dos `pre_hash` con el mismo
  `TicketId`. `verificado en fuente` + `derivado`.
- **Frecuencia (función).** `≈ ρ_reorg · (slots de solape dentro de S_max) · α`. `estimado`.
- **¿Qué la evita?** El firmante seguro; y una regla de producción que **prohíba** reusar el billete
  en la rama nueva. Sin esa regla, §7.2 **invita** a reusarlo (ver FP7).

### FP4 · Reempaquetado del mismo bloque con otro cuerpo

- **¿Cambia el `pre_hash`?** **Sí.** En la base lineal la prefirma es `header_encoding[0, 492)` e
  incluye `merkle_root` `[36, 68)`; en el formato DAG incluye `body_commitment` y los padres
  (`SPEC.md` C-HDR-01, C-HDR-03). Cambiar el cuerpo, el orden de las transacciones, la coinbase o los
  padres cambia la prefirma y por tanto el `pre_hash`. `verificado en fuente`.
- **¿Es una conducta honesta?** **La retransmisión pura no** lo es: reenviar un bloque recibido no
  vuelve a firmar y no produce un segundo `pre_hash`. **Sí** lo es volver a **producir** el mismo slot
  con otro cuerpo (por ejemplo, reconstruir el candidato tras un fallo local o porque llegó un bloque
  nuevo y la punta cambió). `derivado`.
- **Frecuencia (función).** Ligada a la tasa de reconstrucción del candidato dentro de la ventana de
  producción del slot; `≈` (reconstrucciones por slot ganado) `· α · λ`. `estimado`.
- **¿Qué la evita?** El firmante seguro (§3): decisión **antes** de firmar, no antes de publicar.

### FP5 · Reconstrucción del candidato del mismo slot al cambiar la punta

Es un caso particular de FP4 y merece línea propia porque es **el más probable de todos** con
`λ ≈ 1 bloque/slot`: el nodo arma su candidato, aún no lo ha publicado, llega un bloque nuevo, la
punta virtual cambia (`C-GD-03`) y el nodo reconstruye con otro padre. Dos firmas del mismo
`(TicketId, slot)` con padres distintos. **No interviene ninguna falta**: es el funcionamiento
normal de un DAG a un bloque por segundo. `derivado`. Frecuencia `≈ P(el nodo gana el slot) · P(la
punta cambia entre armado y firma)`, ambas del orden de `α` y de la fracción de `Δ` sobre el tiempo
de armado. `estimado`.

### FP6 · Clave compartida: *pool* custodial, clave robada o copiada

- **¿Posible?** **Sí.** La identidad incluye `public_key`; dos operadores con la misma clave y acceso
  a la parcela producen la misma evidencia. `derivado`.
- **Frecuencia (función).** `≈` (operadores con la misma clave y la misma parcela, sin registro
  compartido) `× α · λ`. `estimado`. **No medible con lo que hay**: no existe un censo de claves
  compartidas.
- **¿Qué la evita?** Nada criptográfico. El firmante seguro sólo ayuda si el registro es **común** a
  los dos operadores.
- **Consecuencia de seguridad, que es lo importante:** con `CANDIDATA.md` §6 el castigo cae sobre
  **el lote y las recompensas retenidas**, no sobre una persona. Un tercero que obtenga la clave
  (o un *pool* negligente) puede por tanto **provocar la confiscación** del lote ajeno firmando dos
  veces. Es una vía de **griefing** que el diseño candidato no trata.

### FP7 · El billete de la historia abandonada «vuelve a estar disponible» (`SPEC.md` §7.2)

- **¿Posible?** **Sí, y es una contradicción de reglas, no una rareza.** `SPEC.md` §7.2 dice:
  «En reorg, el conjunto se reconstruye para la nueva cadena: un billete consumido en una historia
  abandonada **vuelve a estar disponible** en la rama que prevalece», y lo respalda con el vector
  `fixture_reorg_libera_billete`: «el mismo billete gana en dos ramas competidoras y, tras el reorg,
  lo consume el bloque de la rama prevalente». Ese vector **es** la infracción estrecha. `verificado
  en fuente` (`SPEC.md` §7.2).
- **Consecuencia.** Con la infracción adoptada, el firmante seguro debe **negarse** a reusar el
  billete, y entonces el granjero honesto **pierde esa recompensa** tras cada reorg. La regla de
  §7.2 y la infracción no pueden convivir sin decidir cuál manda. Va a
  `DEFINICION-PROPUESTA.md` §5.
- **Frecuencia (función).** `≈ ρ_reorg · α` por unidad de tiempo: es **el precio honesto del
  mecanismo** y hay que declararlo, no esconderlo. `derivado`.

### FP8 · Dos redes con la misma clave y el mismo sector

- **¿Posible?** **Sí con la identidad de `C-GD-07`/R-FIN-11**, que **no incluye un dominio de red**:
  `(public_key, sector_index, history_size, chunk, slot)`. Un mismo billete en mainnet y en testnet
  colisionaría. IDV-01 y `CANDIDATA.md` sí llevan dominio. `verificado en fuente` (comparación de las
  tres definiciones).
- **Frecuencia (función).** `≈` (operadores que corren la misma parcela en dos redes) `× α · λ`.
  `estimado`.
- **¿Qué la evita?** Incluir el dominio económico de red/era en la identidad (IDV-01,
  `CANDIDATA.md`).

### FP9 · Época saltada y ancla heredada (`C-FLU-05`, `C-FLU-21`)

- **¿Posible?** **No produce la evidencia.** `C-FLU-05` hace que una época sin ancla se salte y
  `C-FLU-21` que la inyección activada se **herede**. Son reglas de flujo, no de billete: cambian el
  reto, no la identidad. Se listan para dejarlo escrito y **descartarlas**: no son fuente de falso
  positivo. `derivado`.

---

## 2 · Tabla de decisión

| Caso | ¿Posible? | ¿Lo evita alguna regla vigente? | ¿Lo evita el firmante seguro? |
|---|---|---|---|
| FP1 *harvesters* redundantes | sí | **no** (el barajado es deliberado) | **sí**, si comparten registro |
| FP2 reinicio | sí | no | **sí**, si el registro sobrevive |
| FP3 producción en slot pasado tras `C-FLU-22` | sí | no | **sí**, con coste: pierde el slot (FP7) |
| FP4 reempaquetado con otro cuerpo | sí | no | **sí** |
| FP5 punta cambiada antes de firmar | sí | no | **sí** |
| FP6 clave compartida / robada | sí | no | sólo si el registro es común |
| FP7 reuso del billete liberado por reorg | sí | §7.2 lo **invita** | **sí**, pero con pérdida honesta |
| FP8 dos redes | sí (con `C-GD-07`) | no | sí |
| FP9 época saltada / herencia | no | — | — |

---

## 3 · Firmante seguro — especificación como requisito de producción

> Esto es una **propuesta** de requisito de producción, no una regla de consenso y no texto de SPEC.

### 3.1 · Regla

```text
Antes de emitir el sello de un bloque B:
  1. Calcular su identidad de oportunidad TicketId(B) (la identidad recomendada, DEFINICION-PROPUESTA §3).
  2. Consultar el registro persistente por la clave (TicketId(B), slot(B)).
  3. Si NO hay entrada: escribir  (TicketId, slot) -> pre_hash(B)  de forma ATÓMICA y DURADERA
     (fsync del fichero o commit de la transacción) y sólo entonces firmar.
  4. Si hay entrada con el MISMO pre_hash: firmar (es el mismo bloque; puede reemitirse).
  5. Si hay entrada con OTRO pre_hash: NO firmar. Descartar el candidato.
```

El punto 3 es el único que importa y el único que se hace mal por defecto: **persistir antes de
firmar**, no después de publicar.

### 3.2 · Qué hace si pierde el registro

**Abstenerse durante `S_max_slots`** es suficiente y es el plazo exacto: un bloque para un slot `s`
sólo puede aparecer si `slot(B) − slot(sp(B)) ≤ S_max` (`C-GD-04`) y
`pot_bundle_count == slot(B) − slot(sp(B)) ≤ 150` (`C-HDR-07`), de modo que pasado `S_max` ningún
bloque nuevo puede reclamar un slot anterior. Abstenerse más tiempo no compra nada; abstenerse menos
deja una ventana. `derivado`.

### 3.3 · Por qué el registro tiene que sobrevivir al reinicio, y qué significa «sobrevivir»

Debe ser **durable** (fsync/commit) y **anterior** a la firma; si se escribe después, un corte de
energía entre firma y escritura reproduce FP2. Un registro en memoria o un `write` sin `fsync` no
cumple.

### 3.4 · Lo que el firmante seguro NO cubre — hay que decirlo

1. **Dos máquinas que no comparten el registro.** Es FP1 y FP6. La única forma de cubrirlo es un
   registro **compartido** (servicio común, o una función determinista de `(TicketId, slot, punta)`),
   y ninguna de las dos está especificada hoy.
2. **Un atacante decidido.** El registro es **local**: quien quiera doble-firmar borra el registro (o
   usa un binario que no lo consulte) y firma dos veces. **El firmante seguro es un filtro de
   accidentes honestos, no un mecanismo de seguridad.** No hay que presentarlo como prevención.
3. **Una clave robada o compartida** (FP6): el castigo cae sobre el lote, no sobre quien firmó.
4. **La pérdida honesta de §7.2** (FP7): el firmante seguro **causa** la pérdida del slot tras un
   reorg. Es el precio, y es una decisión de diseño, no un fallo de implementación.
5. **La identidad mal elegida.** Si el firmante se indexa por `pre_hash` o por `block_hash` en vez de
   por la identidad de oportunidad, no protege nada: los dos `pre_hash` son distintos por
   construcción.
