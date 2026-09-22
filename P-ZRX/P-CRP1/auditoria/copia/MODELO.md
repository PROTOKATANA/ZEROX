# MODELO — CRP-v0.1

## 1 · Contabilidad de trabajo (el corazón del resultado)

Unidades normalizadas: espacio total = 1; `λ0 = 1` bloque/slot a espacio completo y rango de
referencia `sr0`. Para una rama con fracción de espacio `s` y rango `sr`:

```
tasa de validación   λ(s, sr) = s · λ0 · sr/sr0
peso por bloque      w(sr)   = ⌊2^128/(sr+1)⌋          (C-GD-01, exacto en enteros)
trabajo por slot     E       = λ(s,sr) · w(sr)/w(sr0) ≈ s · λ0
```

La tasa crece ∝ `sr` (cada chunk gana si `solution_distance ≤ sr/2`; con distancia uniforme en
`{0,…,M−1}`, la probabilidad es ≈ `sr/(2M)`) y el peso decrece ∝ `1/sr`. **El producto es
`sr`-independiente**: ésa es la razón por la que el `SR` endógeno no mueve el umbral medio.
`referencia.jl` lo comprueba de forma exacta (Rational/BigInt); `rapido.jl` y GDR-v0.2 lo miden.

El vector de **decoupling** (dos rangos distintos) sí amplifica:

```
E[trabajo/slot] = s · (sr_val/sr0) · w(sr_peso)/w(sr0) ≈ s · (sr_val/sr_peso)
```

En el SPEC ambos son el **mismo campo** (`rango_solucion`: validez en §7.1, peso en C-GD-01), así
que `sr_val = sr_peso` y la amplificación es 1. Se mide la tabla de amplificación para dejarlo
explícito.

## 2 · Adversario

Controla `α` del espacio. Puede retener, elegir padres y elegir el `sr` de su rama (dentro de lo que
permita el controlador), abrir varias ramas y presentar la de mayor `blue_work`. No rompe blake3,
Ed25519 ni la secuencialidad del PoT. No se le concede más CPU/PoT que el reloj (salvo el escenario
multistream, declarado).

## 3 · Regímenes (no se mezclan, §3.3)

- **Corto (reorg / doble gasto):** la honesta lleva una ventaja inicial `d` en unidades de trabajo;
  el adversario compite contra el reloj. Se mide `P(alcance)` y `α_mínimo(d, ε)`.
- **Largo (IBD / long-range):** el adversario dispone de tiempo arbitrario y sólo necesita superar
  el `blue_work` admitido en el momento de presentar. Se compara el trabajo acumulado de dos
  historias que parten del génesis a lo largo de la misma ventana de calendario.

## 4 · Familia de controladores de `SR` (R-FIN-13′ NO está especificado)

`Controlador(ancla, γ, ventana, sr_min, sr_max)` con:
- `CTRL_FIJO`: `sr = sr0`, no reacciona;
- `CTRL_REACTIVO`: `sr ← sr·(objetivo/observado)^γ` sobre la ventana (sube `sr` si produce de menos);
- `CTRL_INVERSO`: el mismo lazo con signo contrario (control de la **dirección**).

Ninguna es «el» controlador: son una familia. El resultado que no depende de la familia es la
invariancia de la media; la **varianza** sí depende del controlador y se mide aparte.

## 5 · Referencias comparadas

| Protocolo | Trabajo por recurso | Reutilización de la unidad | Granularidad |
|---|---|---|---|
| PoW lineal (Bitcoin) | `∝` hashrate | no (el hash se gasta) | fija (1/bloque) |
| GHOSTDAG/PoW (Kaspa) | `∝` hashrate | no | alta (muchos bloques/s) |
| PoST-DAG (ZEROX) | `∝` espacio | **sí** (misma solución, ramas disjuntas) | **elegible** por `sr` |

La granularidad `g` = bloques por unidad de trabajo. Mayor `g` ⇒ misma media, menos varianza por
unidad de trabajo. El doble uso cambia el **coste**, no el umbral.

## 6 · Supuestos de red

Δ de propagación: se usa el orden de `veritas/finalidad/delta-medido-v1/` (para cabeceras, Δ_50
sub-segundo y Δ_100 hasta ~2,2 s en redes ER grandes). La fracción roja del DAG depende de
`λ·Δ/k`; se declara y se barre como escenario. Si Δ se relaja (mayor), sube la fracción roja de
**ambas** ramas y baja el trabajo efectivo por recurso; el umbral medio no cambia, la seguridad
absoluta y la cola corta sí.

## 7 · Límites declarados

- `solution_distance` uniforme e independiente entre chunks y slots (supuesto del modelo).
- Identidad de billete suficiente para U2/U3″ (se toma del SPEC y se comprueba contra GDR, no se
  re-deriva de blake3/Ed25519).
- `sr0`, `λ0` son de **normalización**, no constantes de protocolo.
- La unicidad «un billete = un bloque contado» se comprueba sólo en la forma contextual (§3.4).
