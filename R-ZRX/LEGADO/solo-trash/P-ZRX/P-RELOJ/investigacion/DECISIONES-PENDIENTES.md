# DECISIONES-PENDIENTES.md — P-RELOJ

Solo lo que es **decisión real de Katana**, con el coste de cada rama. Si una bifurcación no tiene
consecuencias distintas, no está aquí; no se inventan decisiones.

---

## D1 · ¿Se admite el adaptador como **cosmético**, o se sube el presupuesto de verificación?

**El hecho que obliga a decidir.** La frontera medida es `S ≤ ε·K`, con `K ≤ 16` (`medido`) y `ε`
como **entrada** que ZEROX no tiene quién fije (`C-CHK-01`/`C-CHK-03` destruyen la llave y no hay
gobernanza). Con `ε = 10 %`, la red admite **1,6×** de dispersión de hardware: más o menos, un
9950X3D y un 14900KS. El objetivo de Katana —«cualquier CPU de gama media-alta»— pide bastante más.

| Rama | Qué se gana | Qué se paga |
|---|---|---|
| **A · Aceptar el techo** (`ε` pequeño, `N` casi fijo) | El impuesto de verificación queda acotado; el reloj no respira; el adaptador es **cosmético** y la decisión real es `ρ_max` a secas | **Se incumple el objetivo declarado**: los nodos modestos quedan fuera, o hay que admitirlos con `Pendiente` perpetuo (`C-POT-07`, `C-NET-33`) |
| **B · Subir `ε` para admitir `S = 4`** (gama media-alta frente a tope de gama) | El objetivo se cumple: caben máquinas de 4× de diferencia | **`ε = 25 %`**: una cuarta parte del slot de **cada** nodo gastada en verificar, **en el nodo más lento**. Y es el nodo más lento el que decide el presupuesto, no el más rápido |
| **C · Financiar el hardware de verificación** (que los nodos modestos verifiquen con VAES-512 aunque produzcan con AES-NI) | `K` sube y `S ≤ ε·K` se relaja sin tocar `ε` | Es una **subvención**, no una regla de consenso: no cabe en `AGENTS.md` sin decidir quién paga. Además fija el objetivo en hardware concreto |

**Lo que el instrumento aporta a la decisión:** la curva `S_max(ε, K)` completa en
`resultados/frontera.md`, para que la elección se haga sobre números y no sobre la intuición de que
«el adaptador lo arregla». **No hay recomendación en este documento**: `ε` es de Katana.

---

## D2 · Trinquete **sí** o **no**: es la decisión que cambia la forma del reloj

**El hecho.** Medido en `resultados/adaptador.md`: sin trinquete, conectar/desconectar produce
amplitudes de `N` de hasta el **96 %** y un coste de verificación máximo de **0,77 s**; el trinquete
deja la amplitud en **0** y el coste en 0,19 s. Pero **el trinquete es irreversible**: `N` nunca
baja.

| Rama | Qué se gana | Qué se paga |
|---|---|---|
| **A · Trinquete (como Autonomys)** | Oscilación **cero**. Es lo que `PotSlotIterationsMustIncrease` existe para conseguir | **`N` no baja nunca.** Si el hardware más rápido se va, el reloj de la red queda lento **para siempre**: el caso que Katana pide explícitamente («que `N` baje cuando el más rápido se desconecta») **no se cumple**. Y como el trinquete se acciona por hard fork (`C-UPG-01`), tarda **meses** |
| **B · Sin trinquete, con histéresis y retardo corto** | `N` baja cuando debe bajar | Oscilación de hasta el ~37 % de `N` con `g = 0,05`; hay que elegir ganancia y retardo, y **ninguno de los dos es una regla de ZEROX** |
| **C · Sin memoria de bajada pero con caducidad `k`** | `N` baja, pero solo dentro de una ventana | La ventana `k` es una decisión nueva; con `k` pequeño equivale al trinquete de facto |

**Lo que está medido y no decidido:** las tres ramas están implementadas en el instrumento
(`trinquete`, `caducidad`, `ganancia`, `retardo` son campos de `Adaptador`) y barridas en
`resultados/adaptador.md`. **Elegir la rama y los valores es de Katana.**

---

## D3 · ¿Se abre el expediente del **ancla externa**, o se cierra citando `AGENTS.md`?

**El hecho.** El encargo corrige que el catálogo la daba por cerrada sin serlo: `AGENTS.md` prohíbe
*staking* y *comités de decisión* y **no dice nada de anclas externas**. El encargo pide evaluarla, y
la evaluación de §2.1 del informe da: **resuelve (A) circularidad y (B) timewarp; NO resuelve (C) el
impuesto de verificación.**

| Rama | Qué se gana | Qué se paga |
|---|---|---|
| **A · Cerrarla por decisión de proyecto** | No se arrastra dependencia de viveza ajena ni un sub-consenso nuevo | Se queda sin una cuarta fuente de tiempo que **sí** existe, y sin responder a (A) por otra vía que el «no se puede» |
| **B · Abrir un encargo de ancla externa** | (A) y (B) cerrados con una referencia fuera de la cadena de PoT | (i) dependencia de la **viveza** de otra cadena; (ii) manipulabilidad de **sus** timestamps (el mismo problema trasladado); (iii) un sub-consenso nuevo dentro de ZEROX («qué cadena y a qué profundidad») que es **otro hard fork**; (iv) **no arregla (C)**, que es lo que el encargo llama decisivo |

**Lo que este instrumento NO hace:** proponerla como regla de consenso (`PROMPT.md` §10). Y **no
revoca `C-TS-04`** ni propone revocarla: si un mecanismo la necesitara, el precio queda escrito y la
calificación es de Katana.

---

## D4 · El presupuesto de verificación `ε` y el techo `K`: ninguna implementación puede fijarlos

**El hecho.** `C-NET-33` deja **pendientes** `PRESUP_PAR` y `PRESUP_NODO`, y `C-POT-07` dice que
agotar un presupuesto da `Pendiente`, **nunca `Inválido`**. Este instrumento **no los fija**: los usa
como entradas y publica la curva.

**Lo que sí queda demostrado y debería entrar en la calibración:** que `K` **no es una decisión de
software**. Es el número de carriles de verificación que el hardware puede llevar a la vez, medido
en **16** para VAES-512 en esta máquina, y **sin medir** para CPUs sin AVX-512. Cualquier valor de
`ε` que se elija está **condicionado** por un `K` que hay que medir en el parque real de hardware,
no suponer.

| Rama | Qué se gana | Qué se paga |
|---|---|---|
| **A · Suponer `K = 8`** (los tramos del PoT) | Es el supuesto conservador y no exige hardware nuevo | Deja `S_max = 0,8` con `ε = 10 %`: **no admite ninguna dispersión**. Es una elección que **niega el objetivo** |
| **B · Medir `K` en el parque real** | La frontera se calibra sobre datos | Exige un censo de hardware que ZEROX, al nacer, no tiene. Es trabajo de campo, no de instrumento |

**Y un número que conviene tener delante al elegir `τ`:** con `τ = 1 s`, `ε = 10 %` y
`N = 206 557 520`, `N_max` con `K = 16` es 2,08·10⁸: **el margen es del 0,8 %**. Cualquier
`τ` menor, o cualquier nodo más lento que esta máquina, deja ese `N` **fuera** del presupuesto.

---

## Lo que NO es una decisión pendiente

- **`N` no se puede fijar aquí.** `C-POT-04` lo deja `<<PENDIENTE: §7.3>>` y `AGENTS.md` prohíbe
  inventarlo. El instrumento da la frontera; el valor es de Katana.
- **No hay `BORRADOR-REGLA.md`.** `PROMPT.md` §9 lo pide solo si F7 sale afirmativo. **F7 sale
  negativo**, así que no se entrega.
- **No se decide si el adaptador «sirve».** Eso ya está respondido: sirve hasta el techo y después es
  cosmético. Lo que queda abierto es **qué hacer con ese hecho**, y son D1 y D2.
