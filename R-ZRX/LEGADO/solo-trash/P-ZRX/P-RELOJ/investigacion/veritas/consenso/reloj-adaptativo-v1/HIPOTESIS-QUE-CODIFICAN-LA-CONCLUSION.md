# HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md

El encargo lo exige (`PROMPT.md` §6) y su motivo es el error característico de esta serie: **el
alcance estrecho con etiqueta ancha**. Aquí van todas las hipótesis que el instrumento **da por
ciertas sin demostrarlas**, ordenadas por cuánto pesan en la conclusión. Cada una dice qué se
rompería si fuera falsa.

---

## H1 · La latencia de un bloque del PoT es la suma de diez latencias de ronda

**Qué se da por cierto.** `lat_bloque = lat(AESENC)·9 + lat(AESENCLAST)`, y las dos latencias son la
misma. Es decir: la cadena de dependencias del bloque pasa por los registros de destino de las diez
instrucciones, sin puertos adicionales ni reordenación que la acorte.

**Por qué se cree.** Medido: `lat AESENC` = 4,001 ciclos y `lat bloque PoT` = 42,0 ciclos ≈ 10 × 4 +
2 de `PXOR` y lazo. `verificado en fuente` en `aes/x86_64.rs:22-33`.

**Si fuera falsa.** El suelo de `ρ` por fabricante cambiaría de magnitud, y F3 cambiaría de
respuesta. La medición de ciclos con PMU la sostiene directamente, así que el riesgo es bajo.

---

## H2 · El factor de paralelismo de la verificación es `K`, y `K ≤ 16`

**Qué se da por cierto.** Que verificar `N` bloques con `K` carriles tarda `N·t_bloque/K`, y que `K`
no pasa de 16 en hardware real. Es lo que convierte `(ADM′)` en `S ≤ ε·K`.

**Por qué se cree.** Medido: el factor por tramos sale 8,02× con 8 tramos; y el barrido de carriles
satura (2,63 ciclos/bloque a 16 carriles frente a 0,263 ciclos/instrucción, cerca del techo de 4
VAES-512 por ciclo de la unidad).

**Si fuera falsa.** Si `K` fuera ilimitado, `S ≤ ε·K` no acotaría nada y el adaptador sí tendría un
grado de libertad. **Es la hipótesis que más peso tiene en el veredicto de F7**, y por eso se midió
en vez de citarse. Un verificador con hardware especializado (no una CPU) podría pasar de 16; eso
está **no determinado** y se declara.

---

## H3 · El coste de verificación que importa es el del camino de respaldo

**Qué se da por cierto.** Que el camino normal (`C-POT-08` paso 3, caché por clave contextual) es
`O(1)` y que el que paga `O(N)` es el respaldo del paso 4, bajo el presupuesto de `C-NET-33`. Por
tanto el presupuesto `ε` se aplica al respaldo.

**Por qué se cree.** `verificado en fuente` en `SPEC.md` §7.1.2: «el paso 3 es lo que garantiza que
el camino normal no paga AES por bloque».

**Si fuera falsa** —si en la práctica el camino normal también recomputara— el impuesto de
verificación sería **continuo** y no solo de puesta al día, y el presupuesto `ε` sería mucho más
caro que lo que dice M1. No está medido con un nodo real: **no determinado**.

---

## H4 · `N` es el mismo para todos los nodos y se aplica en `t_j`

**Qué se da por cierto.** Que `N(s)` es función del pasado validado y común (`C-POT-04`), y que su
cambio ocurre en la inyección de entropía (`C-FLU-16`). Es lo que hace que el controlador tenga
**retardo** y no sea un lazo instantáneo.

**Por qué se cree.** `verificado en fuente` en `SPEC.md` §7.1.1 y §7.1.7.

**Si fuera falsa** —si `N` pudiera variar por nodo— el problema cambiaría de naturaleza: habría
varias cadenas de PoT y `C-FLU-13` (validez absoluta) se rompería.

---

## H5 · Los timestamps están acotados por `δ` por bloque y por el FTL `φ`

**Qué se da por cierto.** En M2, que un bloque puede retrasarse `δ` respecto del anterior y
adelantarse `φ` respecto del reloj local, y que `W`, `δ` y `φ` son entradas. `C-TS-01` fija la
monotonía **pero su relación con `slot` está pendiente**; `C-TS-03` fija el FTL **pero su valor está
pendiente**.

**Por qué se cree.** Leído en `SPEC.md` §7.4; los valores no están decididos en ZEROX.

**Si fuera falsa.** La región de manipulación cambia de tamaño, no de forma: el signo del efecto
(un sesgo negativo sube `N`) no depende de `δ` ni de `φ`.

---

## H6 · El adaptador es un controlador multiplicativo con ganancia constante

**Qué se da por cierto.** Que la ley `N ← N·(1+g·e)` con `e = τ_obj/τ_obs − 1` es una descripción
razonable de lo que un adaptador haría. **Es una elección de modelado, no una regla de ZEROX**: el
encargo prohíbe fijar la ganancia y no existe ninguna regla que diga que el adaptador deba ser
multiplicativo.

**Por qué se cree.** Es la forma estándar de un lazo de control sobre una magnitud positiva
(equivalente a un controlador proporcional en el logaritmo).

**Si fuera falsa.** La conclusión sobre oscilación cambiaría de números, pero **no** la
estructural: `(ADM′)` no depende de la ley de control, y la amplitud siempre está acotada por el
rango de `N` (se ve en `resultados/adaptador.md`).

---

## H7 · El hardware del productor es el mismo objeto que el del verificador

**Qué se da por cierto.** En M1, que `t_v/t_p = 1/K` para cada nodo, es decir que quien produce
rápido también verifica rápido. Es el supuesto **pesimista**: si un nodo pudiera producir con
hardware rápido y verificar con hardware aún más rápido, `(ADM″)` sería **más** permisiva.

**Si fuera falsa.** La frontera se relajaría; nunca se endurecería. El sesgo del error va en contra
de la conclusión, que es la dirección correcta.

---

## H8 · Las cifras del 14900KS son comparables a las medidas aquí

**Qué se da por cierto al hablar del «tercio de latencia»:** que `4,841 ns/bloque` es una medición
del 14900KS. **No lo es**: sale de dividir 1 s entre 206 557 520, y ese «1 s» es un **comentario de
código** con un `TODO: Adjust once we bench PoT on faster hardware` encima
(`chain_spec.rs:128-130`, `verificado en fuente`).

**Si fuera falsa** —si la máquina real no sostiene 6,196 GHz— la descomposición 1,333× × 1,204×
cambia de reparto, pero **no** la conclusión de F3: la latencia de ronda medida en Zen 5 es 4,001
ciclos, y las tablas publicadas dan 4 en Zen 1–4 y 3 en Golden/Raptor Cove. La comparación de
**frecuencia** es la que queda `[derivado]` y así se publica.

---

## H9 · La red admite el gasto de verificar en el nodo más lento

**Qué se da por cierto.** Que «admitido» significa «puede verificar dentro de `ε·τ`», y que ese
`ε` es una decisión de gobernanza que **no existe** en ZEROX (no hay llave de gobernanza,
`C-CHK-01`/`C-CHK-03`). Es decir: el instrumento calcula la frontera de un presupuesto que **hoy
nadie puede fijar**.

**Si fuera falsa** —si el presupuesto no fuera una decisión sino un hecho de facto— el resultado de
F7 no cambia, pero la decisión pendiente cambia de forma: pasaría de «qué `ε` elegir» a «cómo
constatar el `ε` que la red ya soporta».

---

## Lo que este fichero NO hace

No convierte ninguna de estas hipótesis en una conclusión. Donde el informe afirma algo, cita la
hipótesis de la que depende; donde la hipótesis no está medida, la afirmación va marcada
`no determinado` o `derivado`, y **nunca** `demostrado` ni `medido`.
