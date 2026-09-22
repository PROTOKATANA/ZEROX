# CRP-v0.3 · Informe

**Categoría:** `seguridad` (dominante); `consenso` y `rendimiento` (secundarias).
**Versión:** `CRP-v0.3`, derivada de `CRP-v0.2` (que **no** se cierra). Entrada
`ENTRADA.md` (`a8912ba5…5c45`).

---

## 0 · Resumen ejecutivo

| Afirmación | Autoridad | Estado | Condición | Evidencia |
|---|---|---|---|---|
| `P_terminal ≤ P_first_passage ≤ P_eventual` | encargo v0.3 §1 | demostrado | pasos ±1 | tests, `EVENTOS.txt` |
| `α_prob` distinto por evento | encargo v0.3 §1 | derivado | d=4, T=100 | `EVENTOS.txt` (terminal 0.443; paso/eventual 0.355) |
| `α_prob` con cobertura simultánea; 0/n no es frontera | encargo v0.3 §9 | demostrado | Bonferroni `γ/m` | tests, `SWEEP-DAG.txt` |
| R-FIN-5 sobre todo `past(B)` | ancla-de-orden (candidata) | Válida estructural | descriptor autenticado | tests, `U2U3.txt` |
| Fusión público+rama divergente | R-FIN-5 | rechazada | prefijo en `slot(X)` | `SWEEP-DAG.txt` |
| `S` flujos conjuntos (perfecta/iid/derivada) | encargo v0.3 §4 | medido | oportunidades compartidas | `CORRELACION.txt` |
| Único productor sin rojos | encargo v0.3 §6 | medido | Δ∈{0,1,5} | tests |
| `Δ=0` real y drenaje terminal | encargo v0.3 §5 | medido | red simulada | tests |
| Aditivo sube cerca de `1/(S+1)` | encargo v0.3 §8 | medido | S≤24, T=200, 24 reps | `SWEEP-DAG.txt` |
| R-FIN-5 (máximo) ≪ aditivo | encargo v0.3 §4 | medido | no “~0” universal | `SWEEP-DAG.txt` |
| `η_h≈0.99`, `η_a=1.0`, rojos=0 | encargo v0.3 §10 | **curva con rojos inconclusa** | k=30 | `ETA.txt` |
| U2 misma rama; U3″ entre ramas | SPEC §11 | medido | GDR-v0.2 | tests, `U2U3.txt` |
| Controlador del SPEC | SPEC §6.1/§7.2 | **Pendiente** | falta ventana | `RCE` (v0.2) |
| `S_adversario` | encargo D9 | **Pendiente** | falta hardware | v0.2 `IO.txt` |

**Conclusión:** frontera **medida** para los escenarios ensayados; el **umbral protocolario
global sigue inconcluso** por reglas pendientes. CRP-v0.2 no se cierra; v0.3 lo corrige y
lo deja separado.

---

## 1 · Tres eventos (punto 1)

`P_terminal(T)` (cierre exacto), `P_first_passage(≤T)` y `P_eventual` son objetos distintos.
Ejemplo (`z0=4, α=0.2, p=0.8`): `P_terminal(400)=1.35e-42`, `P_first_passage(400)=9.77e-4`,
`P_eventual=9.77e-4`. `α_prob` por evento con `p0=0.05`, `d=4`, `T=100`:
terminal `0.4431`, paso `0.3546`, eventual `0.3545`. No se mezclan.

## 2 · Flujo y R-FIN-5 (punto 2)

Cada bloque lleva `PotOrigin`/`N(s)`/eventos. R-FIN-5 compara el prefijo en `slot(X)` de
**todo** `past(B)`. Con `t_fork=5`: compatible en slot 5, incompatible en slot 15. La fusión
de público y rama divergente se registra `:rechazada_rfin5`; se rechaza **antes** de U2/U3 y
de colorear. Sin descriptor autenticado ⇒ `Pendiente`. **Aviso:** `autenticado` es un campo
declarado del fixture, **no** verificación criptográfica; por eso el resultado es
"compatibilidad estructural", nunca "PoT verificado". El horizonte de justificación se
comprueba por separado (`horizonte_justificacion_ok`).

## 3 · Presentación, validación, fusión y decisión (punto 3)

Cada observador emite una `Decision`: el **nuevo** adopta por mayor `blue_work`; el
**veterano** queda `Pendiente` si `F` no está configurada (R-FIN-7); el **eclipsado** no
puede comparar (`Pendiente`). El intento de fusión es explícito y su resultado
(`:posible`/`:rechazada_rfin5`/`:rechazada_u2`) se registra.

## 4 · S flujos conjuntos (punto 4)

Controles: `:perfecta` produce ramas idénticas (recupera `S=1`); `:iid` las hace distintas y
reproduce `1−E[F^S]`; `:derivada` queda entre ambas. Nunca se usan RNG marginales
independientes por comodidad: se derivan de una oportunidad física común.

## 5 · Red (punto 5)

El autor conoce su bloque de inmediato; `Δ=0` se drena en el mismo slot tras producir; al
cerrar `T` se drena todo (convención terminal simétrica). Un único productor no genera
rojos por latencia consigo mismo (0 rojos para `Δ∈{0,1,5}`); con 8 productores y `Δ=0`, sí
hay concurrencia real.

## 6 · Barrido y déficits (puntos 7, 8)

`d` en unidades de `blue_work` (`m·w`); la semilla no cambia al cambiar `d`. Barrido
`S={1,2,4,8,16,24}`, `T∈{80,200,400}`, `Δ∈{1,2,6}`, `k∈{10,30}`, `α` a ambos lados de
`1/(S+1)` y `1/2`. Los incrementos son **post-fork** (prefijo común contado una vez).

La regla aditiva (contrafactual) sube con `α` cerca de `1/(S+1)`: `S=4` 0/24 en `0.15`,
13/24 en `0.20`, 24/24 en `0.25`; `S=16` 0/24 en `0.01`, 16/24 en `0.06`; `S=24` 17/24 en
`0.04`. La regla R-FIN-5 (máximo) es mucho menor y **no** “~0 para todo `α<1/2`”: a `α=0.45,
S=24` da 6/24 terminal. Las celdas con `rgdr>0` (ramas truncadas por `s_max=150`:
`S=16,α=0.01` y `S=24,α=0.04`) quedan **inconclusas**, porque el truncamiento sesga a la baja.

## 7 · Intervalos simultáneos (punto 9)

`alpha_prob_simultaneo` usa Clopper–Pearson con `γ/m`. Celdas `0/24` ⇒
`:solo_cota_superior`; el barrido principal resultó `:indefinida` (ruido y no monotonicidad
en la rejilla gruesa), y así se declara, en lugar de inventar un cruce.

## 8 · η_h y η_a (punto 10)

Medidos por separado: `η_h≈0.99`, `η_a=1.0` con **0 rojos** a `k=30`. Sin muestra de rojos,
la **curva con rojos asimétricos queda inconclusa**; no se supone `η_h=η_a`.

## 9 · U2/U3 (punto 11)

Mismo billete en ramas disjuntas ⇒ una copia `rojo_U3`; mismo billete dentro de una rama ⇒
`U2` invalida; flujo divergente ⇒ R-FIN-5 rechaza antes de colorear. Orden explícito:
flujo → validez → U2 → U3″.

## 10 · Veredicto

Por escenario: baseline `demostrado`; DAG+R-FIN-5 `medido estructural`; aditivo
`contrafactual`; controlador del SPEC y finalidad `Pendiente`; umbral protocolario global
**inconcluso**. No se hereda el veredicto de CRP-v0.1/v0.2.

**Frontera medida para los escenarios ensayados; umbral protocolario inconcluso.**
