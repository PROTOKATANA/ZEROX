# CRP-v0.2 · Contrato

**Categoría Veritas:** `seguridad` (dominante); `consenso` y `rendimiento` (secundarias).
**Entrada congelada:** `ENTRADA.md` = `deepseek/ENCARGO-07v2-coste-rama-privada.md`,
SHA-256 `a8912ba5d8d48ae71685b3ea471d7166df74bebc4f17bd609c4182c1e8795c45`.
**Sustituye la evidencia protocolaria de CRP-v0.1, que queda como baseline idealizado.**

## 1 · Pregunta

Para una fracción adversaria de espacio `α`, ¿cuál es
`P_win(α,T,d,E,O) = P[W_priv(T) − W_pub(T) > d | E, O]`, en función del horizonte `T`, la red, el
controlador y el número `S` de flujos PoT que el adversario pueda costear? ¿Qué parte es protocolo
vigente y qué parte solo escenario candidato?

`W_pub`, `W_priv` son incrementos de `blue_work` **posteriores al ancestro común**.
`d` es el déficit inicial en unidades de trabajo. `E` es el escenario; `O` el observador.

## 2 · Objetos que NO se mezclan (encargo §1)

| Objeto | Definición |
|---|---|
| `P_win` | probabilidad de superar estrictamente por encima del déficit `d` |
| `α_prob(p₀,T,d,E,O)` | ínfimo de `α` con `P_win ≥ p₀` |
| `g_E(α)` | `lim_{T→∞} E[W_priv−W_pub]/T`, si existe |
| `α_drift(E)` | fronteras de signo de `g_E`; no "mínimo de ataque" |
| `P_eventual` | probabilidad de que exista algún `T` con `W_priv−W_pub > d` |
| `P(empate)` | visita a `D=0`; objeto distinto de superación estricta |

Una traza `Pendiente` puede cuantificar sensibilidad pero **no cuenta como ataque válido** ni entra
en `P_win`.

## 3 · Criterios de éxito (encargo §5)

Se acepta una **frontera condicionada de escenario** solo si se cumplen simultáneamente los diez
criterios del encargo §5. El **umbral protocolario global** exige, además, ausencia de reglas
pendientes que cambien validez/trabajo y una demostración de exhaustividad o cota superior sobre
todas las estrategias válidas. Con el SPEC actual eso no ocurre: flujo, PoT conjunto, controlador y
partes de C-GD-11/finalidad siguen pendientes.

## 4 · Lo que este instrumento NO acredita

- No ejecuta criptografía PoT AES: lo que comprueba es **compatibilidad estructural de flujo**.
- No integra el controlador del SPEC: su corrida es `Pendiente`; el primer dato ausente es la
  **ventana** (TAREAS §2.3).
- RCE/ARM se usa como **perfil candidato**; no se promociona a consenso.
- No mide `S_adversario`; `S` es un **escenario**. Cualquier afirmación económica concreta exigiría
  un perfil de hardware compatible, que aquí falta.
- No reimplementa GHOSTDAG: reutiliza GDR-v0.2 (`veritas/consenso/ghostdag-rank-v1/`).
- No certifica eventos de probabilidad `1e-12` con Monte Carlo ingenuo.
- No hereda el veredicto de CRP-v0.1.

## 5 · Criterio de parada

El trabajo se detiene con `inconcluso` si falta una regla autorizada, una integración o el
presupuesto. Un timeout no es evidencia de seguridad.
