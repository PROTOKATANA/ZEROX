# El reloj y `N`: estado al 2026-09-24 — LEER ANTES DE TOCAR `pot_slot_iterations`

**Sesión:** 2026-09-24. **Mide y valida:** Claude. **Decide:** Katana. **Ejecutó:** `P-ZRX/P-RELOJ/`.

Este documento existe para que nadie repita la cadena de razonamiento de esta sesión ni redescubra
sus callejones. **No sustituye a `P-ZRX/P-RELOJ/investigacion/INFORME.md`**: recoge lo medido, lo
decidido, lo corregido y lo que falta, con la ruta de cada cosa.

> **El resultado en una frase:** el reloj no estaba roto, **estaba sin decidir** — `N` no está fijado
> en ninguna parte del SPEC—; y lo que parecía un problema de seguridad son **dos problemas
> distintos**, de los que solo uno lo es.

---

## 1 · La corrección de encuadre, que es lo primero

El punto de partida era la ficha **D5** («el reloj principal»): `prove = 1,561 s/slot` en la máquina
de referencia frente a `τ = 1 s`. Se leyó como «la máquina no llega». Es cierto, y **no es un
problema de seguridad**. Se parte en dos:

| | Qué es | ¿Seguridad? |
|---|---|---|
| **Quién puede operar un timelord** | Lo fija `N` | **No.** Es participación y viveza |
| **Cuánto se adelanta el más rápido (`ρ`)** | Lo fija el hardware | **Sí.** Y está abierto desde el 2026-09-08 |

**`N` no toca `ρ`.** Bajar `N` acelera a todos por igual: **el cociente entre hardware es invariante
en `N`**. Y `τ = N · t_iter(el más rápido)`, así que **subir `τ` y subir `N` son el mismo
movimiento**, no dos palancas.

> **Esto sustituye la lectura de la ficha D5** de `P-ZRX/T-ZRX/AGUJEROS-Y-SOLUCIONES.md` §1.4. Esa
> ficha sigue siendo correcta en su dato (`prove = 1,561 s/slot`, confirmado aquí por segunda vía),
> pero lo cataloga como un agujero único cuando son dos cosas distintas. **No se edita** porque está
> sellada en `P-ZRX/P-ECLIPSE/ENTRADA.sha256`; se corrige aquí.

---

## 2 · Lo medido, que antes era una sola cifra y ahora son cinco

Todo en el Ryzen 9 9950X3D (Zen 5), la máquina de referencia.

| Magnitud | Valor | Clase | Fuente |
|---|---:|---|---|
| Cadena AES-128 encadenada | **7,7716 ns/bloque** | `medido` | `P-ZRX/P-RELOJ/medicion-previa/` (Claude) |
| La misma, reproducida | **7,7789 / 7,7636 ns** | `medido` | `P-RELOJ/investigacion/mediciones/latencia-aes/` |
| Latencia de `AESENC` | **4,001 ciclos** | `medido` con PMU | ídem, `aesinst.c` |
| Latencia de `VAESENC` ymm y zmm | **4,001 ciclos** | `medido` | **ensanchar el vector NO baja la latencia** |
| Bloque de 10 rondas | **42,01 ciclos** | `medido` | 10 × 4,001 + 2 de `pxor` y lazo |
| Frecuencia efectiva | **5,428 GHz** | `medido` | |
| Paralelismo de verificación `K` | **16** | `medido` | 42,01 ÷ 2,627 = 15,99 |

**La reproducción es independiente:** Criterion sobre el crate de Autonomys frente a un bucle en C
con intrínsecos, y **el mismo sumidero `c3af66b6e126af3c`** — es la misma computación bit a bit.
Concuerdan al **0,4 %**. La cifra de `1,561 s/slot` queda **confirmada**.

### 2.1 · La brecha con el 14900KS, y qué parte de ella está medida

| | Esta máquina | 14900KS |
|---|---:|---:|
| ns/bloque | **7,739 `[medido]`** | 4,841 `[citado]` |
| ciclos/bloque | **42,01 `[medido]`** | 30 `[derivado]` |
| ciclos/ronda | **4,001 `[medido]`** | 3 `[citado]` |
| frecuencia | **5,428 GHz `[medido]`** | 6,196 GHz `[derivado]` |

**Descomposición correcta:** `42,01/30 = 1,400` (ciclos por bloque) × `6,196/5,428 = 1,141`
(frecuencia) = **1,598**, que coincide con el cociente de ns medido (**1,599**).

> ⚠️ **Los 4,841 ns del 14900KS NO están medidos por nadie del proyecto.** Salen de dividir 1 s
> entre 206 557 520, y ese «1 s» es un **comentario de código**:
> `PDF/autonomys-subspace/crates/subspace-node/src/chain_spec.rs:129`, *«About 1s on 6.2 GHz Raptor
> Lake CPU (14900KS)»*, **con un `TODO: Adjust once we bench PoT on faster hardware` en la línea de
> encima**. Es la cifra peor respaldada de toda la cadena, y media conclusión descansa en ella.

### 2.2 · La latencia de 4 ciclos y el suelo por fabricante

`AESENC` tarda **4 ciclos** en Zen y **3** en los P-core de Intel. Respaldo: uops.info y Agner Fog
para Zen 1-4, la hoja oficial de AMD (58455), y la medición con PMU de esta sesión.

**`P-RELOJ` cazó además un artefacto ajeno:** la fila resumen de uops.info **para Zen 5 imprime 3**,
contradicha por **sus propios datos crudos** (APERF ≈ 4,05), por `AESDEC` y `AESENCLAST` de la misma
página, y por la documentación de AMD. **Tres fuentes contra una fila.**

**Consecuencia:** quien compre Intel en vez de AMD obtiene **~1,33× de ventaja de reloj al por
menor**. No se compensa con un AMD mejor: haría falta **8,26 GHz** contra un Intel de 6,2.

> **Defecto pendiente en `P-RELOJ` §6, anotado y sin corregir:** su informe concluye que ese tercio
> «no es arquitectural, es de reloj», apoyándose en que **los ciclos no suben con la carga**. El
> argumento está **invertido** —una propiedad arquitectural es precisamente la que no cambia con la
> carga— y su propia tabla lo desmiente. Y su «Producto 1,52×» mezcla ciclos **por ronda** con
> frecuencia **por bloque**; el valor correcto es **1,598**, que es su propia fila de ns.

---

## 3 · Lo que las reglas ya dicen, y lo que dejan abierto

| Regla | Qué fija | Estado |
|---|---|---|
| **`C-POT-04`** | Dominio de `N`: `≠ 0`, `≤ u32::MAX`, **`N % 16 == 0`** | **Su valor inicial, sus límites y QUIÉN AUTORIZA un cambio: `<<PENDIENTE: §7.3>>`** |
| **`C-FLU-16`** | El calendario de un cambio de `N`: entra en la inyección de entropía | cerrada |
| **`C-SLOT-01`** | «La tasa de producción y la duración del slot son **magnitudes distintas**» | cerrada — `λ` **no** queda atada a `τ` |
| **`C-TS-01`** | La relación timestamp–slot | **«debe quedar fijada»** — pendiente |
| **`C-TS-03`** | El FTL | **«queda pendiente»** — **bloqueo duro** |
| **`C-TS-04`** | Prohíbe la hora de red como entrada de consenso | cerrada |
| **`C-TS-05`** | **«No se publica una fórmula de producción antes de fijar esa relación»** | cerrada, y **bloquea** escribir el adaptador |
| **`C-UPG-01`** | Solo hard forks por altura; sin señalización ni votación | cerrada |
| **`C-UPG-08`** | Lista de parámetros ajustables por hard fork | **`N` NO está en la lista** |
| **`C-CHK-01/03`** | El checkpoint se emite una vez, su clave **se destruye**, caduca | cerradas |

**El `% 16` sale de `NUM_CHECKPOINTS (8) × 2`** del extrínseco de Autonomys
(`pallet-subspace/src/lib.rs:640-644`).

### 3.1 · Por qué ZEROX no puede hacer lo que hace Autonomys

Autonomys mueve `N` con `set_pot_slot_iterations`, que exige **`ensure_root`** —una llave de
gobernanza— y es además un **trinquete**: `PotSlotIterationsMustIncrease`, **`N` solo puede subir**.
Y su `N` es un parámetro **de génesis por red**: mainnet **206 557 520**, devnet **150 000 000**,
dev local **100 000 000**.

**ZEROX no tiene esa llave, y es a propósito.** Por `C-UPG-01`, `C-UPG-08` y `C-CHK-01/03`, con `N`
estático **el único camino es un hard fork por altura**, con meses de latencia. Ése es el argumento
más fuerte a favor de un `N` dinámico: **para ZEROX no es una optimización, es la única vía de
ajuste que el diseño admite.**

---

## 4 · La frontera, que es el resultado central

```text
ρ_max = ε · K            ε_min = ρ / K
```

- **`ρ`** = dispersión de hardware admitida (el más lento ÷ el más rápido)
- **`ε`** = fracción del slot que aceptas gastar verificando el PoT
- **`K`** = paralelismo de verificación de la máquina lenta. **Medido: 16** con AVX-512/VAES; **~8**
  con solo AES-NI

| `ε` | `ρ` admitido | Abanico real |
|---:|---:|---|
| 5 % | 0,80× | **vacío** |
| **10 %** | **1,60×** | 14900KS ↔ esta máquina. Gama alta, nada más |
| **19 %** | **3,04×** | prácticamente **cualquier CPU con AES-NI** |

**El objetivo de Katana —cualquier CPU de gama media-alta corre un timelord— es alcanzable a
`ε ≈ 19 %`, no a 10 %.** Ése es el precio, y es un número decidible.

> **Ojo con el doble castigo:** la máquina más lenta suele ser también la de menor `K`. Una CPU con
> solo AES-NI es peor por los dos lados a la vez.

### 4.1 · El otro techo: el tipo

`C-POT-04` da `N ≤ u32::MAX`, luego el mayor del dominio es **4 294 967 280**. Con el hardware
medido son **3,32 s de producción por slot**, y un ASIC de ~20× **satura el tipo**. Es una frontera
real, no un detalle: el adaptador **no puede subir indefinidamente aunque el presupuesto lo
permitiera**.

---

## 5 · El resultado que corrige el encuadre entero

**`N` dinámico NO cuesta más verificación que `N` estático.** Comprobado por aritmética
(ASIC 2,5×, verificador de 11 ns/bloque con `K = 8`):

| | Slot | Verificar | **CPU por segundo de reloj de pared** |
|---|---:|---:|---:|
| **`N` estático** (la cadena se acelera) | 0,400 s | 0,284 s | **0,710** |
| **`N` dinámico** (el slot se mantiene) | 1,000 s | 0,710 s | **0,710** |

Con estático lo pagas porque **los slots llegan más deprisa**; con dinámico porque **cada slot es
mayor**. El coste es `ρ/K` por segundo real en los dos casos: **`N` se cancela**.

> **`ρ` no se elimina: se coloca.** La diferencia de velocidad entre hardware es un hecho físico.
> Lo único que se elige es **dónde cae**: en el calendario (estático), o en más trabajo por slot
> (dinámico).

**Etiqueta honesta:** esta aritmética es **de Claude, de esta sesión**, no de ningún informe.
`P-RELOJ` no la hizo. Es división simple y se comprueba en un minuto, pero **contradice lo que el
propio encargo `P-RELOJ` daba por objeción decisiva (su §2 (C))**, y conviene saberlo.

---

## 6 · Las cinco opciones para `N`

Escenario: aparece un ASIC en el **techo del rango estimado** (2,5× sobre un 14900KS). Verificador
débil: esta misma máquina forzando AES-NI, **190 ms medidos**.

| | Opción | Verificar hoy | Con ASIC 2,5× | Calendario | Hard forks | Evidencia |
|---|---|---:|---:|---|---|---|
| **1** | Estático, fijado una vez | 19 % | 47,5 % | se comprime **2,5×** | uno; otro por ajuste | base actual |
| **2** | Estático + ajustable (`C-UPG-08`) | 19 % | 47,5 % | corregido a mano, meses tarde | **uno por ajuste** | trivial |
| **3** | **Dinámico con timestamps + techo** | 19 % | 47,5 % | **intacto** | **uno, y ninguno más** | **evaluado (P-RELOJ)** |
| **4** | Dinámico + cadena externa | 19 % | 47,5 % | intacto | **dos**, + viveza ajena | evaluado (P-RELOJ §2.1) |
| **5** | Grupos de clase (vía Chia) | ~ms | ~ms | intacto | uno + reescribir el reloj | evaluado, **cifra en contra** |

**Cerrada con número, no es opción:** SNARK sobre la cadena AES. Probar GHOSTDAG —mucho más
barato— sale a **288 s/bloque** (`veritas/consenso/prueba-recursiva-v1/` §2).

**Lo que la tabla enseña:** las columnas de verificación de 1, 2, 3 y 4 son **idénticas**. Entre
ellas **el coste no decide**; solo deciden el calendario y los hard forks.

### 6.1 · Por qué la 5 sigue siendo «No»

Es la única que hace barata la verificación de verdad, y la única con una cifra **medida en
contra**: el ASIC de grupos de clase de Chia dio **3,1-3,8× demostrado en silicio**, frente a
nuestro **1,5-2,5× estimado sin paper**. Chia mete la ventaja de VDF **dentro** de su umbral
(*«< 42,7 % (\* vdf advantage)»*). Cambiar una cifra medida-mala por una estimada-buena va en
dirección contraria al modelo de amenaza — y **empeora** el objetivo de Katana, porque la latencia
de los grupos de clase no la acelera ninguna CPU de consumo.

### 6.2 · Recomendación de Claude, y su estado

**La 3.** Al mismo precio que la 1 conserva el calendario, y pide **un** hard fork en vez de uno por
ajuste. Además evita un efecto que la 1 no evita: como el retarget de rango es **endógeno** (mide en
índices de slot), si los slots se acortan la cadena produce **más bloques por segundo real** — con
un ASIC 2,5×, los ~49 TB/año sin poda pasarían a **~123 TB/año** `[derivado]`.

**Lo que la 3 NO da, y conviene no ilusionarse:**
- **No toca `ρ` frente a un atacante que oculta su velocidad**: calcula en privado y publica al ritmo
  honesto; el adaptador nunca lo ve.
- **No da inclusividad de hardware**: eso es `ρ_max = ε·K` y no depende de `N`.
- **No abarata la verificación**: cuesta lo mismo que estático.

### 6.3 · La cadena externa, como complemento

`AGENTS.md` prohíbe *staking* y *comités de decisión* y **no dice nada de anclas externas** — el
catálogo que la daba por cerrada está marcado `[NO VERIFICADO]` en el propio repositorio.

Arregla la **calidad del reloj**; **no** arregla el coste de verificación ni `ρ`. Cuesta: viveza
ajena, los timestamps manipulables de esa otra cadena, y un **sub-consenso** sobre cuál y a qué
profundidad que es **otro hard fork**.

**Cómo dejarla barata sin decidirla hoy** `[propuesta de Claude, sin evaluar]`: redactar la regla con
la **fuente de tiempo como entrada nombrada** —«`N` se ajusta según la ley `L` sobre la fuente
`S`»— en vez de empotrar los timestamps en la ley. Y si algún día se añade, **como cota sobre la
medida, no como fuente primaria**, para no heredar su viveza. **Se decide con el FTL en la mano**,
no antes.

---

## 7 · Qué decidió Katana en esta sesión

1. **Fijar `ρ_max` primero y derivar `N` de ahí** — elegido explícitamente entre cuatro opciones, por
   ser el orden lógico: `N` es consecuencia de `ρ_max`, no su causa.
2. **Objetivo declarado: un timelord debe poder correr en cualquier CPU de gama media-alta, Intel o
   AMD**, y si es posible también un ASIC. **Explícitamente: no favorecer a Intel.**
3. **`P-RELOJ` como encargo separado**, no dentro del de `ρ_max`.

**Inclinación anotada, NO decisión:** Katana se inclina por la **opción 3**. No puede constar como
decisión porque la propuesta está en **F1**, y el tablero exige F3 —redactada y con parámetros no
inventados— para entrar al SPEC.

---

## 8 · Por qué NO puede pasar al SPEC todavía

| Fase | ¿Está? |
|---|---|
| **F1** · comprobada en su alcance, informe validado | ✅ |
| **F2** · prototipada fuera del SPEC, coste medido | ⚠️ **a medias**: el coste sí (`K = 16`); **la ley de adaptación NO existe** |
| **F3** · redactada y decidida → entra al SPEC | ❌ |

**No hay borrador de regla.** El encargo lo pedía *solo si F7 salía afirmativo*; salió negativo, y el
ejecutor hizo lo correcto: no lo escribió.

**Y el propio SPEC lo bloquea:** `C-TS-05` dice «**no se publica una fórmula de producción antes de
fijar esa relación**», y la relación timestamp–slot es justo lo que `C-TS-01` deja pendiente.

**Lo que falta, en orden:**

1. **Decisión de Katana de adoptarlo.** `P-RELOJ` **evaluó, no recomendó**; su F7 fue negativo para
   el objetivo pleno.
2. **Cerrar §7.4** — la relación timestamp↔slot y el **FTL**. **Es el bloqueo duro.**
3. **Dos números:** `ε` y quién es la máquina más débil admitida.
4. **Redactar la ley de adaptación**: ventana, ganancia, sobre qué ancestros, y **cómo cuantiza** —
   `N % 16 == 0` hace que el ajuste no sea continuo.
5. **Decidir «quién autoriza»**, que es literalmente el `<<PENDIENTE>>` de `C-POT-04`.

Después sí puede entrar **con sus parámetros marcados `<<PENDIENTE>>`**, que es la convención de la
casa (`C-FLU-17`, `C-NET-33`). **Lo que no puede entrar es el mecanismo sin redactar.**

---

## 9 · Correcciones de Claude en esta sesión — para que nadie herede el error

| Dije | Es falso porque |
|---|---|
| «El reloj se arregla con un número» | Son **dos problemas**: quién opera el timelord (`N`) y `ρ`. Solo el segundo es seguridad |
| «`N` dinámico cobra un impuesto de verificación» | **Cuesta lo mismo que estático** (§5). El impuesto lo causa el hardware rápido |
| «El ancla externa está prohibida» | **`AGENTS.md` no la prohíbe.** Era lectura mía, marcada `[NO VERIFICADO]` en el catálogo |
| «`N_max ≡ ρ_max`» | Falso en forma literal: `ε` no acota `N`, acota la **dispersión**. La relación es `ρ_max = ε·K` |
| «Opción C: puerta de reloj de pared» | **Retirada.** La mencioné y la recomendé **sin estar evaluada**, junto a opciones que sí lo estaban |
| «8 salientes» (en el prompt de `P-ECLIPSE`) | `MAX_PEERS_SALIENTES = 24` en `crates/zx-p2p/src/limites.rs` |

**La puerta de reloj de pared queda como candidata sin evaluar**, no como opción. Si interesa, se
decide con un encargo que responda una sola pregunta: **¿validez o política de relé?** Como validez,
un nodo con el reloj sesgado forkea; como política, un grupo coludido la salta. Nadie lo ha
estudiado.

---

## 10 · Defectos pendientes en `P-RELOJ`, validados por Claude

Ninguno mueve el resultado central; los cuatro rompen trazabilidad o inducen a error.

1. **§6 · «Producto 1,52×» contradice su propia fila de ns (1,599).** Mezcla ciclos por ronda con
   frecuencia por bloque. El correcto es **1,598**.
2. **§6 · el argumento de la carga está invertido.** «Si el tercio fuera arquitectural, los ciclos
   subirían con la carga» — no: una propiedad arquitectural es la que **no** cambia con la carga.
3. **§6 · la conclusión sobrepasa.** «Se compran con frecuencia» exige **8,26 GHz** en AMD contra un
   Intel de 6,2. No es comprable.
4. **§4.3 · la caja de correspondencia contradice su propio §5.** Escribe `ε_min = 1/(ρ·K)`; la buena
   —que el propio informe deriva después— es **`ε_min = ρ/K`**. Factor 9 de diferencia. El texto de
   §4.3 es material superado que quedó sin retirar.

**Lo que sí hizo bien y conviene reconocer:** superó la puerta de reproducción con el mismo
sumidero, argumentó la desviación de LINEO **en `METODO.md` y `CONTRATO.md`** —el defecto que
`P-PUENTE` dejó abierto—, y cazó el artefacto de uops.info.

---

## 11 · Lo que NO hay que volver a hacer

- **No busques un `N` que permita a esta máquina alcanzar a una Intel.** El cociente es **invariante
  en `N`**: bajarlo acelera a los dos por igual.
- **No trates `τ` y `N` como dos palancas.** `τ = N · t_iter(el más rápido)`. Son la misma.
- **No copies el `206 557 520` de Autonomys como si fuera una constante del protocolo.** Es de
  génesis, por red, y lleva un `TODO` de sus propios autores.
- **No compares el 1,5-2,5× nuestro con el 3,1-3,8× de Chia como si tuvieran el mismo respaldo.** El
  suyo es silicio; el nuestro es estimación sin paper, y el estudio de Supranational que lo sostiene
  **nadie lo ha localizado**.
- **No midas el timelord por la máquina de referencia sin decir cuál.** Los 190 ms de la ruta AES-NI
  están medidos **en esta misma CPU forzando la ruta estrecha**, y el repositorio avisa de que
  **no equivalen a una CPU antigua**. Una de gama media de verdad **nadie la ha medido**.

---

## 12 · Si solo vas a hacer una cosa

**Medir `t_iter` en dos o tres CPUs reales.** El programa ya existe y está sellado
(`P-ZRX/P-RELOJ/medicion-previa/aeslat.c`). Es barato, convierte **la cifra peor respaldada de toda
la cadena** en una medición, y **es la entrada de todas las decisiones que quedan**: `ε`, `ρ_max`,
el techo de `N`, y si el adaptador merece la pena.

Todo lo demás está esperando a eso, y al **FTL**.
