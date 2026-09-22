# CRP-v0.2 · Informe

**Categoría:** `seguridad` (dominante); `consenso` y `rendimiento` (secundarias).
**Versión del modelo:** `CRP-v0.2`. **Entrada:** `ENTRADA.md`
(`a8912ba5…5c45`). **Sustituye la evidencia protocolaria de CRP-v0.1** (baseline idealizado útil;
veredicto protocolario inconcluso).

---

## 0 · Resumen ejecutivo

| Afirmación | Autoridad | Estado | Condición | Evidencia |
|---|---|---|---|---|
| `blue_work(B)=Σ_{x∈blues(B)}w(x)` | `SPEC.md` §11 (C-GD-08) | SPEC vigente | ya en `ghostdag.rs`/GDR | `ghostdag.rs`, GDR-v0.2 |
| Carrera ±1: `P(empate)=(q/p)^d`, `P(superar)=(q/p)^(d+1)` | encargo D3 / ruina clásica | demostrado | `q<p`; un evento por paso | `referencia.jl`, tests |
| DP acotada conserva masa y publica `[P_L,P_U]` | encargo D2 | demostrado | error ≤ `1e-12` por encima de la cota | `resultados/CORTO.txt` |
| `d` en trabajo ≡ `d·g` en retícula | encargo D2 | demostrado | pasos ±1 | tests |
| Controlador del SPEC | SPEC §6.1/§7.2 | **Pendiente** | falta ventana/arranque/redondeos | `RCE.txt` |
| RCE rev2 (+Z0) deriva `SR` en perfil candidato | contrato RCE | instrumento | asociación DAG→cohorte es oráculo | tests, `RCE.txt` |
| R-FIN-5 rechaza prefijo incompatible en `slot(X)` | ancla-de-orden | candidata | descriptor autenticado; si no, Pendiente | tests, `RFIN5.txt` |
| Toy `S`: `α_drift=1/(S+1)` | encargo §4 | demostrado | iid, suma íntegra, sin red | `CONTROL.txt` |
| `S=24, α=0.04` es **igualdad**, no victoria | encargo D7 | demostrado | toy aditivo | tests |
| DAG con vistas locales produce rojos reales | encargo D1 | medido | concurrencia `k=2` | `DAG.txt` |
| Eficiencias `η_h`/`η_a` | encargo D6 | pendiente | sin red asimétrica medida | — |
| `S_adversario` | encargo D9 | pendiente | falta perfil de hardware | `IO.txt` |
| Coste económico | encargo D10 | pendiente | sin modelo económico completo | — |

**Conclusión:** hay **frontera medida para los escenarios ensayados**, pero el umbral protocolario
global es **inconcluso** porque flujo PoT conjunto, controlador del SPEC, PoT AES,
C-GD-11 y finalidad siguen pendientes. No se hereda el veredicto de CRP-v0.1.

---

## 1 · α_drift: identidad del baseline vs escenario con autoridad

`g_E(α) = lim_T E[W_priv(T) − W_pub(T)]/T`. En el baseline simétrico (un evento por paso, misma
tasa y mismo peso por bloque), la frontera de deriva es

```
g_E(α) = α − (1−α) = 2α − 1,   α_drift = 1/2 (exacto).
```

(`g_E` es `E[W_priv − W_pub]/T`: positivo ⇒ ventaja adversaria, según el encargo §1.)

Esto es una **identidad aritmética del baseline**: no depende del protocolo. Bajo un escenario DAG
con estado de autoridad explícito, la frontera solo se recupera si `η_h = η_a` y las tasas medias
existen; si los rojos honestos y adversarios difieren, `g_E` es una **raíz implícita**

```
α_drift : α·c_a^∞(α)·η_a^∞(α) = (1−α)·c_h^∞(α)·η_h^∞(α),
```

no una constante. En v2 medimos rojos reales por concurrencia (`DAG.txt`, `k=2`): la fracción de
réplicas con ≥1 rojo es 1.0, IC95 (0.912, 1.000). **No** medimos `η_h ≠ η_a` en red asimétrica; por
tanto la parte "verificada bajo DAG con autoridad" es solo la estructura de color, no el umbral.

## 2 · `α_drift`, `α_prob` y `P_eventual` por separado

| Objeto | Valor/definición | Estado |
|---|---|---|
| `α_drift` baseline | `1/2` exacto | demostrado |
| `α_drift` toy `S` | `1/(S+1)` para `S∈{1,2,4,8,16,24}` | demostrado (`CONTROL.txt`) |
| `α_prob(0.05, T=200, d=6, baseline)` | intervalo `(0.394663, 0.394663)` | derivado (DP) |
| `P_eventual` baseline `d=6, α=0.4` | `(q/p)^7 = 0.0585277`; DP finito T=200 = `0.0583926` | derivado |
| Empate `d=6, α=0.4, T=200` | `0.0876` (distinto de superar) | derivado |

No se usa `P=1/2` por defecto. `α_prob` es un intervalo; `P_eventual` no se confunde con la
probabilidad a horizonte finito.

## 3 · Frontera implícita con eficiencias contextuales

`η_x(T) = E[blue_work_x post-fork]/E[trabajo bruto elegible_x post-fork]`. Con retención total,
una rama por lado y límites existentes:

```
α·c_a^∞·η_a^∞ = (1−α)·c_h^∞·η_h^∞.
```

La forma cerrada `c_hη_h/(c_hη_h+c_aη_a)` solo vale si `c_x^∞η_x^∞` no cambia con `α`. En v2 no se
dispone de `c_x^∞` ni `η_x^∞` medidos en red ZEROX; lo único medido es la existencia de rojos y su
recuento bajo concurrencia. **Queda pendiente.**

## 4 · R-FIN-5: ¿puede incorporar bloques con prefijos ya divergentes?

**No en el escenario candidato.** La comprobación estructural compara el prefijo en `slot(X)`;
si `flujo(X,slot(X)) ≠ flujo(B,slot(X))`, el bloque `X` no puede incorporarse. Una divergencia
**posterior** no invalida el pasado común (test: compatible en slot 7, incompatible en slot 20).
En el **SPEC actual** el flujo conjunto no está cerrado (TAREAS §2.1): la decisión sigue
**Pendiente**, no `Válida`.

## 5 · Máximo de `S` ramas fijas: aporte y coste

Con `S` ramas incompatibles el adversario presenta **la mejor**; no suma. Por eso se usan cotas de
unión `max_i P(E_i) ≤ P(∪E_i) ≤ min(1, Σ_i P(E_i))`. El aporte frente a `S=1` es de varianza
(el máximo de varias ramas), no de suma de trabajo. Coste: `S` presupuestos de CPU/PoT/I/O
privados. **No** se demuestra optimalidad ni árboles adaptativos. `S_adversario` es pendiente.

Frontera medida (`resultados/DAG.txt`, 64 réplicas/celda, `T=400`, `Δ=4`, honesto total `1−α`,
rama `α`, `k=30`, GDR con R-FIN-5 estructural):

| `S` | regla | `α=0.2, d=0` | `α=0.3, d=0` |
|---|---|---|---|
| 1 | máximo (R-FIN-5) | 0.000 (IC 0.000–0.057) | 0.000 (0.000–0.057) |
| 4 | máximo (R-FIN-5) | 0.000 (0.000–0.057) | 0.000 (0.000–0.057) |
| 4 | suma (contrafactual) | 0.766 (0.649–0.853) | 1.000 (0.943–1.000) |

El peligro `S·α` aparece **solo** en el contrafactual aditivo; con R-FIN-5 no hay suma de ramas
incompatibles. Como R-FIN-5 no está adoptada, la traza del escenario candidato es
`Válida estructural / Pendiente cripto`, no un ataque al protocolo vigente.

## 6 · Toy `1/(S+1)` y su distancia al DAG completo

El **control escalar dedicado** (streams iid, igual tasa, suma íntegra, sin red/rojos/U2/U3/límites)
recupera `α_drift=1/(S+1)` con `g(1/(S+1))=0` para los `S` ensayados. El contrafactual aditivo del
DAG **no** es una regla adoptada y **no** se espera que el DAG completo recupere `1/(S+1)` al
desactivar R-FIN-5: GHOSTDAG no suma ramas incompatibles. En `DAG.txt`, para `S=2`, la suma
adversaria observada supera al máximo de ramas, cuantificando el peligro `S·α`, no el protocolo.

## 7 · Controlador candidato y campo exacto que decide

El perfil RCE rev2 es determinista y **deriva** `SR` del pasado (vector ARM: `N=5` sello 10 ⇒
rango 200 en slot 20; ventana vacía Z0 es no-op y no revierte). El controlador del SPEC queda
`Pendiente`: el **primer dato ausente es la ventana** (arranque, límites, redondeos y fusiones
fuera de ventana, TAREAS §2.3). Sin ventana no se puede construir la traza de `SR` adversarial del
protocolo vigente.

## 8 · Curva con red y rojos asimétricos

Topología: `n_honestos` con vistas locales y latencia `Δ` (simulación por slots, GDR-v0.2). Con
`k=2`, `Δ=4`, `n=8`, 64 réplicas: tasa de bloques rojos `0.6044`, fracción de réplicas con rojo
`1.000`, IC95 (0.943, 1.000). Con `k=30`: 0 rojos, IC95 superior `0.057` (límite unilateral de
Wilson). No hay IC para `η_h`/`η_a` porque no se midió la asimetría de eficiencia; por eso la
frontera con rojos asimétricos queda **Pendiente**. La cota numérica de la diferencia de trabajo
no está certificada con aritmética de bolas; se publica como medición.

## 9 · Qué fue escenario, qué midió el microbenchmark, qué puede afirmarse

- `S_escenario`: `{1,2,4,8,16,24}` elegidos para barrido, etiquetados.
- `S_microbenchmark`: **solo** el componente I/O de lectura sobre 64 MiB en `/tmp`, page cache
  caliente, cola 1. Valores dependientes de la corrida; en `resultados/IO.txt`: `p50≈0.002 ms`,
  `p95≈0.003 ms`, `p99≤0.006 ms`, ~1700–2250 MiB/s. No distingue page cache de almacenamiento.
- `S_adversario`: **pendiente**. No se deriva de `100k IOPS`; falta CPU/PoAS-KZG/PoT-por-slot.

## 10 · Coste adicional

Bajo los supuestos declarados, la conclusión máxima es **"cero espacio plotteado adicional"**,
no "ataque gratis": hay CPU/PoT/IOPS, energía, recompensas renunciadas durante la retención y
capital hundido. **No** se sustituye la duración real por `Δ·conf` sin derivación de unidades.
El modelo económico completo está **pendiente**.

## 11 · Nodo veterano, nodo nuevo desde génesis, sync sucinto

| Consumidor | Estado |
|---|---|
| veterano (con finalidad/reorg) | `Pendiente`: R-FIN-7/`F` provisional y `Δ` sin medir |
| nuevo desde génesis | puede bajar y validar toda la historia; IBD sucinto no existe |
| sync sucinto | **no disponible**; no es un fallo, es coste de arranque (TAREAS §2.4) |

Un eclipse que deja al nodo `Pendiente` no es automáticamente una victoria de selección.

## 12 · ¿Ingeniería, consenso o inconcluso?

Por escenario: el baseline es `demostrado`; el DAG con red es `medido condicionado`; el flujo
R-FIN-5 es `estructural/Pendiente`; el controlador del SPEC es `Pendiente`; el umbral protocolario
global es **inconcluso**. No es una única etiqueta global.

---

## Límites y prohibiciones respetadas

No se editó el encargo, SPEC, TAREAS ni código de producción; no se ejecutó Python; no se hicieron
benchmarks destructivos; no se llamó "medido" a una fórmula evaluada; no se usó `100k IOPS`, 24
flujos, `F`, `I`, `L`, `ρ_max` como hechos; no se heredó el veredicto de CRP-v0.1.

**Frontera medida para los escenarios ensayados; umbral protocolario inconcluso.**
