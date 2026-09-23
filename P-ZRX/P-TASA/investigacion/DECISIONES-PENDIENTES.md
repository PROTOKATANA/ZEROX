# DECISIONES-PENDIENTES — P-TASA · tasa-identidad-v1

**En una línea, como pide el encargo §7: la vía (11) —tasa fija por identidad— no merece existir como
defensa del umbral, en ninguna de sus tres variantes, y por eso este documento no inventa decisiones
de diseño: sólo queda la decisión de encuadre y una nota de registro.** Todo lo que sigue son
bifurcaciones **reales** para Katana; ninguna la toma este encargo. Las cifras están derivadas en
`INFORME.md` y son reproducibles con `veritas/economia/tasa-identidad-v1/correr-todo.sh`.

**El hecho que ordena todo:** una tasa que encarece **crear** identidades no encarece **reusar** una,
y el doble farmeo reusa una. Su único efecto es hacer costosa la **partición** que evade una regla de
exclusividad, y esa regla necesita que la infracción **se pruebe** (`κ·q > 0`). Por tanto la tasa
hereda la dependencia de `κ` que el encargo le atribuía evitada: con `κq = 0`, la fracción de espacio
disuadida es **exactamente 0 para todo `τ`** (`demostrado`).

---

## D1 · ¿Se rechaza la vía (11) como defensa del umbral?

| Opción | Qué cuesta | Qué cierra |
|---|---|---|
| **1A · Rechazarla como defensa y retirarla del tablero** | Nada. Conserva `P-ZRX/PROPUESTAS-VIABLES.md` honesto | Nada, y hay que decirlo: **el hueco que la motivaba sigue abierto** (la salida «coste no proporcional al espacio» que nombra el teorema queda sin ocupar) |
| **1B · Mantenerla en F0 «por si acaso»** | Un encargo que ya está hecho y no va a cambiar de signo sin cambiar `H1` (la distribución de tamaños) | Nada nuevo. Sólo se justifica si aparece una medición de la distribución real **y** una fuente de `κq > 0` que `P-CLAVE` no encontró |
| **1C · Adoptarla igualmente como mitigación parcial** | Barrera de entrada **regresiva** (carga `f*/f`: más del 100 % del ingreso de toda granja menor que la marginal) y dependencia de la economía de castigo ya refutada | Un encarecimiento de la partición **sólo si `κq > 0`**. **No es un cierre** y no se puede presentar como tal |

**Etiqueta: `propuesto`.** La recomendación de este trabajo es **1A**. **Lo que decide Katana**, y lo
único que este trabajo no puede decidir por él, es si el proyecto quiere conservar la tasa **por otras
razones** (D3).

---

## D2 · Si se conserva una tasa por identidad: ¿en qué se paga?

| Opción | Qué cuesta | Qué cierra |
|---|---|---|
| **2A · En moneda** | **Arranque circular**: en el génesis no hay moneda. O se asigna moneda en el génesis —**contradice `C-EMIT-02`**—, o se paga con el primer ingreso (lo que **convierte (c) en (b)**, dependiente de `κ`), o es barrera de entrada | Nada por sí sola. Y **`C-EMIT-02` es una regla vigente**, no una preferencia |
| **2B · En cómputo** | Reintroduce **minería PoW**, que `MIGRACION.md:84-90` registra como retirada; `W` fijo es **ASIC-able** y comprable a escala | Cumple la letra del teorema y **evita el arranque**. Bajo el modelo de amenaza de Katana («un ente con mucha capacidad atacará») es la unidad **más favorable al atacante** |
| **2C · Ambas, a elección** | Suma los dos costes | Nada: el atacante elige la más barata de las dos |

**Etiqueta: `derivado`.** Si Katana adopta 2A o 2B, **la decisión es de unidad, no de seguridad**: la
regresividad y la dicotomía de `INFORME.md` §4 **no dependen de la unidad**, sólo de que el coste sea
fijo por identidad.

---

## D3 · ¿Se usa la tasa como **tarifa** para otra función (no como defensa)?

Es la única forma en que la vía tiene contenido positivo, y hay dos usos que el repositorio ya
necesita y que **no** son defensa del umbral:

- **Financiar el registro de lotes de `P-ZRX/P-COBERTURA/`** (D6 de su `DECISIONES-PENDIENTES.md`: «¿quién
  paga el alta de quien entra sin monedas?»; estado trivial, `0,21 MB/TiB`, el problema es la tarifa).
  Una tasa de identidad **no resuelve** ese problema: quien entra sin monedas sigue sin poder pagarla
  (es el mismo arranque circular de D2). **Se registra para que nadie lo confunda con una solución.**
- **Tarifar spam de identidades** en capas no-consenso (p. ej. registro de pools o de servicios).
  Ahí no hay modelo de adversario de umbral y la regresividad es una decisión de producto, no de
  seguridad.

**Etiqueta: `propuesto` si se adopta; `no determinado` en su valor.** Este encargo **no** estudia
ninguno de los dos usos y **no fija `τ`**.

---

## Lo que NO es una bifurcación

- **Elegir la forma de la cuota `φ`.** No hay nada que elegir: `INFORME.md` §4 demuestra que «partir
  cuesta» y «ser regresiva» son **la misma condición**. Cualquier horario que haga costosa la
  partición es regresivo; el único no regresivo es proporcional al espacio, es decir la variante (a),
  que la propia `AGENTS.md` prohíbe y que además es **neutral bajo partición** (no impide la evasión).
- **Añadir un tope de espacio por identidad.** No rescata la vía: convierte la cuota en
  `τ·⌈f/S_max⌉ ≈ (τ/S_max)·f`, es decir en (a) disfrazada, y **rompe** la propiedad de partición en los
  saltos (`INFORME.md` §4.3).
- **Subir `τ`.** Mueve la carga de la granja pequeña a la pequeña, no a la grande: `τ_min ∝ f*`.
- **Confiar en que «no compensa económicamente».** El modelo de amenaza del encargo lo prohíbe
  expresamente, y este informe da **coste absoluto** además del relativo.
- **Presentar `κ = 0` como cerrado.** No lo cierra nada de lo que hay aquí. Ni la tasa.

---

## Lo que este encargo entrega a otras líneas de trabajo

1. **Un criterio de descarte reutilizable.** Antes de escribir una propuesta de «coste por identidad»
   en PoAS, comprobar dos cosas: (i) ¿la evasión que encarece necesita **crear** una identidad, o sólo
   reusar la que ya tiene? (ii) ¿el beneficio de la evasión es lineal en el espacio? Si la respuesta es
   «reusar» y «sí», **la tasa no puede funcionar para todo tamaño** (`INFORME.md` §2.3), y si además
   se le pide que impida partir, **es regresiva por identidad matemática** (§4.1).
2. **La equivalencia exacta `partir cuesta ⟺ regresiva`**, que es un enunciado general sobre
   horarios de cuota y no depende de ZEROX. Sirve para cualquier propuesta futura de tarifa por
   identidad o por lote.
3. **La corrección de encuadre de F1**: la independencia de `κ` de la variante (c) es una propiedad
   **del recibo**, no de la defensa. Quien vuelva a proponer (c) por esa razón debe leer `INFORME.md`
   §2.1 antes.

---

## Estado que este encargo deja en el tablero

`P-ZRX/PROPUESTAS-VIABLES.md` fila **11** («Tasa fija por identidad») pasa, por este informe, de
`F0` a **`F1 (tope)`**: comprobada en su alcance, con lo que cierra y lo que no. **No la sube a F2 ni
la retira del fichero**: eso lo decide Katana. Si la lectura es «no merece existir», el movimiento
correcto es llevarla a `P-ZRX/T-ZRX/AGUJEROS-Y-SOLUCIONES.md` §1 con la razón, para que nadie la
reabra sin leer por qué cayó —igual que se hizo con (1), (6) y (7).

> Este encargo **no edita** `P-ZRX/PROPUESTAS-VIABLES.md` (es de solo lectura para él, PROMPT §5).
> Este párrafo es la propuesta de movimiento, no el movimiento.
