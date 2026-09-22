# Decisiones pendientes — lo que cambia para Katana según salga el número

Este documento **no decide**. Ordena las tres defensas que ZEROX tiene sobre la mesa contra el
atacante que conoce retos por adelantado —**revelación retardada** R-FIN-14(h), **compromiso previo
de parcela con edad** (A1+C1) y **sellado secuencial**— según lo que dice la medición de
P-INTENTO, y separa lo que la cifra cierra de lo que deja abierto.

Recordatorio de alcance: lo medido es una **cota SUPERIOR** del coste del atacante, y **no hay
precios**. Todo lo de abajo es hardware condicionado a `w`.

---

## 1 · La cifra que decide

**[Medido]** Un intento dirigido cuesta:

| | |
|---|---:|
| Generar la tabla de una pieza, 1 núcleo | **809 ms** |
| Probar esa tabla contra un reto adicional | 0,49 µs (o 1,4 ns en lote) |
| Camino ganador, sin regenerar la tabla | 23,0 ms |
| CPU de 24 hilos, forma ganadora (anidada, 8 concurrentes) | **25,03 tablas/s** |

**[Derivado]** `N_eq(una CPU de 24 hilos, w) = 25,03 · w` piezas de espacio honesto equivalente
(`τ = 1 s`, `Piece::SIZE = 1.048.672 B`). A `w = 10⁴` son 0,239 TiB; a `w = 10⁵`, 2,39 TiB; a
`w = 10⁶`, 23,9 TiB.

**[Derivado]** Los dos umbrales que importan **coinciden** cuando `λ = 1`:

```text
w_equilibrio     = N_h / (r·τ)        UNA máquina emula la red entera
w_min_latencia   = N_h / (r·τ·λ)      el atacante cubre al menos una solución por slot
```

Es decir: **el ataque se vuelve competitivo en hardware exactamente cuando también se vuelve
viable en latencia.** No hay una ventana en la que sea «caro pero rápido».

| Red honesta `N_h` | `w` para que **1** CPU de 24 hilos emule la red | CPUs para emular 1 disco de 20 TB con `w = 10⁴` |
|---|---:|---:|
| 10⁶ piezas (≈ 1 TiB) | 4,0·10⁴ | 76 |
| 10⁸ piezas (≈ 100 TiB) | 4,0·10⁶ | 76 |
| 10⁹ piezas (≈ 1 PiB) | 4,0·10⁷ | 76 |

**La cifra no depende de `N_h` para la comparación con disco** —el disco es disco— y **sí** para el
umbral de igualdad con la red.

---

## 2 · Qué defensa deja de ser urgente y cuál pasa a serlo

La respuesta **depende enteramente de `w`**, y `w` es lo que `P-ZRX/P-REVELACION/` tiene que dar.
Hay dos regímenes y el corte es nítido.

### Régimen A — `w ≲ 10³` (ventana de adelanto corta)

- **El ataque dirigido no es viable en latencia.** `w_min = N_h/(r·τ·λ)` exige `w` de millones para
  una red de 10⁹ piezas. Con `w` de miles, el sembrador **no cubre ni una solución por slot**.
- **Lo que esto significa:** el hueco que P-SEMBRADOR demostró (la unidad de aceptación es una
  pieza, no un sector) **sigue existiendo**, pero su explotación económica queda fuera de alcance
  por una razón **temporal**, no por una razón de coste.
- **Consecuencia para las defensas:** **A1+C1 y el sellado secuencial dejan de ser urgentes como
  cierre del ataque dirigido**. Siguen cerrando otras cosas (ploteo parcial, catálogo precomputado),
  pero el atacante que se describe en P-SEMBRADOR no llega.
- **La revelación retardada R-FIN-14(h) pasa a primer plano**, porque es la que **acota `w`**. Si
  R-FIN-14(h) mantiene `w` en la decena o el centenar, cierra el ataque sin tocar la parcela.

### Régimen B — `w ≳ 10⁶` (ventana de adelanto larga)

- **Una CPU de 24 hilos emula de 2,39 TiB (`w = 10⁵`) a 23,9 TiB (`w = 10⁶`)** de disco honesto.
  Un solo servidor con varias de estas CPUs iguala el disco de un granjero mediano.
- **La urgencia se invierte:** **A1+C1 pasa a ser la defensa que cierra**, y el sellado secuencial
  la que elimina sin auditorías frecuentes. La revelación retardada **mitiga** pero no cierra para
  todo `ρ` (veredicto de P-SEMBRADOR, Fase 2, fila D).
- **Lo que compra el atacante con `w` grande es tiempo de CPU sustituible por disco a razón de
  ~0,239 TiB por CPU y por cada 10⁴ retos de adelanto.** Es una tasa de cambio **medida**.

### Régimen intermedio — `10³ ≲ w ≲ 10⁶`

- Ni holgado ni cerrado. Es donde la decisión es de **grado**: `máquinas(α, N_h, w)` da el número
  exacto (§1) y `α` decide cuánto duele. No se puede despachar con «urgente» o «no urgente».

---

## 3 · Lo que gana, paga y cierra cada opción

| Opción | Qué **gana** con esta medición | Qué **paga** | Qué **cierra** |
|---|---|---|---|
| **R-FIN-14(h) revelación retardada** | Es la **única** que ataca directamente la variable de la que cuelga todo: acorta `w`. Con `N_eq ∝ w`, reducir `w` en `k` reduce el espacio emulado en `k`. A `w = 10³` una CPU de 24 hilos emula 0,024 TiB; a `w = 10⁵`, 2,39 TiB: **dos órdenes de magnitud**. | Varias líneas PoT, CPU permanente de nodo, riesgo de partición (ya evaluado en P-SEMBRADOR, ficha D). | **Acota el ataque** dentro de una región de `ρ`; **no lo elimina** para todo `ρ`. **No toca la parcela.** |
| **A1+C1 compromiso previo + edad** | Si `w` resulta grande, es la defensa que **elimina la adaptación**: el atacante tiene que haber comprometido los bytes antes del reto. | Registro/acumulador en cadena, prueba de pertenencia, espera de alta, poda y acceso de granjeros nuevos. Coste **no determinado** (no se prototipó). | **Elimina condicionalmente** la adaptación posterior al reto, si la edad supera `sup A_actual` y la prueba obliga a todos los bytes. **No cierra la regeneración barata por sí sola.** |
| **Sellado secuencial** | Elimina por ruta crítica, sin auditorías frecuentes. Es la más fuerte si el atacante no puede acelerarlo. | Nueva parcela, nueva criptografía, prueba sucinta, migración mayor. **Riesgo técnico más alto.** | **Elimina condicionalmente**, si la ruta adversarial supera `A_actual` y no hay atajo. **Hoy está propuesto, no demostrado.** |

**Lo que la medición NO cambia:** ninguna de las tres deja de tener sentido por el hecho de que el
intento cueste 809 ms. Lo que cambia es **cuál es la primera palanca**: si `w` se puede acotar, la
palanca es R-FIN-14(h) y las otras dos pueden esperar; si `w` no se puede acotar, la palanca es
A1+C1 y las otras dos son complementos.

---

## 4 · Lo que hay que decidir, en orden

1. **Cerrar `w`** con `P-ZRX/P-REVELACION/` (ventana de adelanto con y sin revelación retardada).
   Sin ese número, la elección entre los dos regímenes del §2 es arbitraria.
2. **Cerrar `π_DAG`.** Multiplica el coste por bloque pagado; no afecta a `N_eq`. Fijarlo a 1
   favorece al atacante.
3. **Fijar `N_h` objetivo de la red joven.** El umbral de igualdad con la red es `N_h/(r·τ·λ)`:
   para 10⁶ piezas el ataque se vuelve viable con `w` de decenas de miles; para 10⁹, con decenas de
   millones.
4. **Solo entonces** decidir si se prototipa A1+C1 (fuera del SPEC, como propone P-SEMBRADOR) o si
   basta con R-FIN-14(h).

---

## 5 · Asuntos independientes que esta investigación abre y no cierra

- **[Medido]** La forma de plotear decide el coste por un factor **2,96×**: 25,03 tablas/s con
  varias llamadas concurrentes a `generate_parallel` sobre una piscina de 24 (la forma que ya usa
  `CpuRecordsEncoder` con varios generadores), frente a 8,47 tablas/s con una sola llamada
  secuencial y 17,52 con tablas independientes a un hilo. Cualquier cifra de coste de ploteo del
  nodo debe declarar **cuál** de las tres usa.
- **[Medido]** `ab-proof-of-space` @ `f8842d0` revienta con **SIGSEGV** para ciertas semillas por el
  camino **no paralelo**. La ruta del plotter honesto (paralela) no falla con la semilla probada,
  pero conviene decidir si ZEROX adopta la dependencia sin un arreglo o exige el fallo cerrado.
  Detalle: `mediciones/fallo-semilla.md`.
- **[Medido]** El objeto compacto que el código usa para responder a un bucket es **10,8× más lento**
  que las siete tablas completas. Si algún componente de ZEROX usa `ChiaV2Table::find_proof` en un
  camino caliente, hay una mejora de datos disponible sin tocar el formato.
- **[Medido]** El camino **no paralelo** cuesta 809 ms por tabla y el paralelo 118 ms con 24 hilos.
  Cualquier estimación de coste de ploteo del nodo debe usar la forma que gane, no la primera que
  aparezca en el código.
