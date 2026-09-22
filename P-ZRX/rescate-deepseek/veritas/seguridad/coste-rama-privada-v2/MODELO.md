# CRP-v0.2 · Modelo

Versión del modelo: `CRP-v0.2`. Fecha: 2026-09-18.

## 1 · Unidades

| Magnitud | Unidad | Definición |
|---|---|---|
| `w(B)` | unidades de `blue_work` | `⌊2^128/(SR(B)+1)⌋`, entero exacto (C-GD-01) |
| `blue_work(B)` | unidades de `blue_work` | acumulador C-GD-08 sobre azules |
| `D` | unidades de trabajo | `d + W_pub − W_priv` |
| `z` | retícula entera | `z = g·D`; un bloque pesa `1/g` |
| `slot` | índice entero de PoT | no es el sello de cabecera (R-FIN-13) |
| `T` | slots/eventos | horizonte del escenario |
| `Δ` | slots | latencia de propagación honesta |
| `d` | unidades de trabajo | déficit inicial (`d ≥ 0`) |

**Única conversión:** `d` se declara en unidades de trabajo y pasa a la retícula **una sola vez**
(`z0 = g·d`). No se mezclan `d` entero de bloques con `d` de trabajo (regresión de D2).

## 2 · Actores y vistas (encargo §3.1)

- `n_honestos` nodos, cada uno con una **vista local** (`BitSet` de bloques conocidos).
- Producción contra la vista disponible en el instante de autoría, **antes** de recibir bloques en
  tránsito (D1).
- Propagación con latencia entera `Δ`; entrega al inicio del slot correspondiente.
- Un actor adversario con `S` ramas privadas (`S` es escenario, no capacidad).
- Consumidores separados conceptualmente: **veterano**, **nuevo desde génesis** y **sync sucinto**
  (hoy no disponible). El instrumento mide `W_pub` sobre la punta pública y `W_priv` por rama;
  no afirma qué consumidor adopta qué.

## 3 · Reglas aplicadas

Se aplican, vía GDR-v0.2, C-GD-01…09 y C-ORD-01…03 (texto del SPEC §11). Complementos:

- **C-GD-10** (padres): aproximación de cola barajada que incluye la punta de mayor `blue_work`.
  Declarado como aproximación, no como nodo.
- **C-GD-11**: no implementado; sus cinco pendientes quedan fuera. Su ausencia no se rellena.
- **R-FIN-5** (candidata): comprobación **estructural** de prefijo de flujo en `slot(X)`, antes de
  colorear. No ejecuta PoT AES.

## 4 · Flujo PoT (escenario candidato)

Descriptor `PotOrigin = (dominio, origen de índices, semilla, N_inicial)` autenticado más eventos
`(slot_activación, entropía, N_efectivo)`. La compatibilidad compara el **prefijo en `slot(X)`**;
una divergencia futura no invalida el pasado común. Si el descriptor no está autenticado, toda
decisión es `Pendiente`, nunca `true` (encargo §3.3).

## 5 · Adversario (encargo §3.4)

Estrategias ensayadas:

1. retención de `S` ramas y liberación al presentar (máximo de ramas, R-FIN-5);
2. contrafactual aditivo (suma de `S` flujos), **no regla adoptada**;
3. ramas con latencia interna nula;
4. `S` fijo (no árbol adaptativo; declarado como límite).

No se ensaya optimalidad ni árboles adaptativos. Cada estrategia declara qué cota aporta.

## 6 · Escenarios y parámetros

`α`, `S ∈ {1,2,4,8,16,24}` (escenarios), `d`, `T`, `g`, `Δ`, `p₀`, `observador`.
`S=24` **no** es capacidad acreditada; es el valor del toy aditivo donde `24·0.04 = 1−0.04` es
**igualdad**, no victoria. `S_adversario` queda `Pendiente` (bench/io_lectura.jl).

## 7 · Contabilidad de la conclusión (encargo §6)

Cada cifra del informe declara: valor/unidad, definición, versión, fuente, adversario, escenario,
criterio de aceptación y estado (`elegido`, `medido`, `derivado`, `demostrado`, `pendiente`).
