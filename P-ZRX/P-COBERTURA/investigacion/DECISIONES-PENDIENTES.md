# DECISIONES-PENDIENTES — P-COBERTURA

Bifurcaciones reales para Katana, con el coste de cada rama. **Ninguna la toma este
encargo.** Las cifras están derivadas en `INFORME.md` y son reproducibles con
`veritas/criptografia/cobertura-parcela-v1/correr-modelo.sh`.

**El hecho que ordena todas las decisiones:** para el formato fijado, **no puede existir** una
prueba sucinta que acredite que los bytes caros **existían** antes del reto (F2,
`[demostrado]`). Lo que sí se puede construir es la **cobertura del objeto caro** (§7.3 del
INFORME). Las decisiones de abajo son, por tanto, «qué se hace con el hueco de preexistencia»,
no «qué prueba se busca».

---

## D1 · ¿Se cambia el objeto ploteado?

| Opción | Qué cuesta | Qué cierra | Quién la paga |
|---|---|---|---|
| **1A · No cambiar** | Nada en el formato | Nada por principio. El sembrador sigue disponible y sólo se le puede poner precio | — |
| **1B · Semilla secreta** (vía iv) | El plot deja de regenerarse desde `(public_key, sector_index, history_size)`; hay que custodiar un secreto durante toda la vida del plot; se pierde la restauración desde el historial; hay que rediseñar la interacción con la expiración pseudoaleatoria | **Rompe la simulación**: el objeto deja de ser público. Es la única vía que puede volver el ataque **imposible** | Los granjeros (custodia, reploteo) y el formato |
| **1C · Sellado secuencial** (vía ii) | Alta lenta (horas por lote), prueba sucinta nueva, verificación que no escala por sector, incompatibilidad con el ploteo actual | Impone un suelo de latencia si la ruta adversarial supera `w`; **no prueba persistencia** después (Filecoin sigue necesitando PoSt) | La red entera: reploteo y `proof_of_space` nuevo |

**Etiqueta: `propuesto`.** **Coste no determinado en bytes ni en CPU**: no existe el diseño.
Un prototipo fuera del SPEC es el paso previo.

## D2 · Si NO se cambia el formato: ¿se adopta el registro con edad y auditorías?

| Opción | Qué cuesta | Qué cierra |
|---|---|---|
| **2A · Registro completo + edad + auditorías** | Estado de cadena trivial (**0,21 MB/TiB**, `0,21 MB/TiB` reproducido en `F5-registro.tsv`); capacidad inactiva `M/T_vida` (**hasta 4,78 %** en el escenario agresivo); **y auditorías con `k > B`** | **Nada del sembrador.** Pasa de coste 0 a **117,2 núcleos/TiB continuos** (~1.524× la energía de almacenar). Vuelve el ataque **caro y observable**, no imposible |
| **2B · Sólo registrar, sin auditorías** | Casi nada | Sólo la identidad del lote. **No cambia el coste del sembrador** |
| **2C · No registrar** | — | Nada |

**El número que decide 2A:** con `w = 7.175` y **una** máquina adversaria,
`B = 181.092` unidades. **Una auditoría con `k ≤ 181.092` no detecta nada.** Es decir: aceptar
2A obliga a fijar `k > 181.092` **por TiB de lote**, que a `D_a = 60 s` son **3.018 lecturas/s
por TiB** — un SSD lo sirve, un HDD doméstico no. **Para lotes de 100 TiB el mismo `k` es
`0,17 %` del lote: los lotes grandes son auditables y los de 1 TiB no.**

## D3 · ¿Se acorta `w`?

Es la **única palanca que mueve la frontera sin tocar la parcela**. Con `w = 0` el almacenamiento
forzado pasaría de `82,7 %` a `1 − R·D_a/N ≈ 0,14 %`, y `B` caería de `181.092` a `1.526`
(`w = 1`).

| Opción | Efecto sobre `B` | Coste |
|---|---|---|
| **3A · Segundo VDF de revelación** (`w = 4.830,6`, `ρ=2,5`) | `B`: 181.092 → **122.411** (`−32 %`) | El coste de la línea VDF; **no baja `w` tanto como parece** (la variante `Lrev = L − S_max` da `4.865,6`, que **sube**) |
| **3B · Eliminar el adelanto** (`w = 0`) | `B` → `R·D_a` | **Destruye la propiedad que el PoT da**: el reto deja de ser público con antelación. Es cambiar el mecanismo de revelación, no la parcela |

**Etiqueta: `derivado`.** `w` es una banda; el instrumento no lo fija.

## D4 · ¿Se acepta el agujero y se declara?

| Opción | Qué cuesta | Qué se gana |
|---|---|---|
| **4A · Declarar el sembrador mitigado/tarifado** | Nada | Honestidad: no se espera una prueba que no va a llegar. **El consenso base ya debe ser seguro suponiendo que el doble farming es barato** (`SOLUCION-CANDIDATA-REUTILIZACION.md:120-121`) |
| **4B · Seguir buscando la prueba** | Tiempo y encargos | Nada demostrable: F2 dice **no puede existir**, no «no se ha encontrado» |

## D5 · ¿Cuál es el tamaño mínimo de lote que merece la pena registrar?

`B` **no crece con `N`**: el número absoluto de aperturas necesarias lo fija el adversario. Por
tanto `k/N` cae con `N`.

| Lote | `k` necesario | `k/N` | ¿Auditable por un doméstico? |
|---:|---:|---:|---|
| 0,1 TiB | > 181.092 | 173 % | **No**: haría falta abrir más posiciones que piezas hay |
| **1 TiB** | > 181.092 | **17,3 %** | SSD sí, HDD no |
| 10 TiB | > 181.092 | 1,73 % | Sí |
| 100 TiB | > 181.092 | 0,17 % | Sí |

**Etiqueta: `derivado`.** Implica que un registro por parcela pequeña **no aporta nada
auditable**: la unidad de registro útil es el lote grande.

## D6 · ¿Quién paga el alta de quien entra sin monedas?

Abierto desde `P-ZRX/P-PERMANENCIA/CANDIDATA.md` C4. El estado es trivial (0,21 MB/TiB), así
que el problema **no es el estado**: es la tarifa de la transacción. La salida natural —alta
pagada con prueba de espacio— **no se ha estudiado aquí**.

## D7 · ¿Qué se hace con los 200 B/alta y el formato de la entrada?

**Hipótesis, no decidido.** Los siete campos de `CANDIDATA.md` §1 (dominio, clave, raíz,
cardinalidad, versión, época) más firma caben en ~200 B, y el estado resultante es trivial.
Alternativa declarada en `P-PERMANENCIA/DECISIONES-PENDIENTES.md` D6: acumulador/conjunto
activo, o dejar `SectorId` como está y aceptar el re-registro.

---

## Lo que NO es una bifurcación

- **Añadir un compromiso del objeto caro.** No es una decisión de seguridad: es construible
  (§7.3) y **no cambia nada del ataque de regeneración**. Decidirlo es decidir si se quiere la
  identidad del lote, no si se cierra el sembrador.
- **Muestrear posiciones.** `k` no mueve la frontera; sólo compra probabilidad por debajo de
  ella. No es una palanca de diseño de seguridad.
- **Subir `M`.** Sube la capacidad inactiva del honesto (`M/T_vida`) sin tocar el techo del
  atacante, que es `B`.
- **Confiar en que «no compensa».** El modelo de amenaza lo prohíbe expresamente.
