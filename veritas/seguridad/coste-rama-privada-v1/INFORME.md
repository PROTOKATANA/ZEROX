# INFORME — CRP-v0.1 · ¿Cuánto cuesta una rama privada con más `blue_work`?

**Categoría:** `seguridad` (dominante); `consenso` (secundaria). **Pregunta** (`ENCARGO-07` §2):
sea `α` la fracción de espacio del adversario, ¿cuál es el `α` mínimo para construir en privado una
rama con más `blue_work` que la honesta, y cómo se compara con el `α>1/2` de PoW?

---

## 1 · La curva `α_mínimo` (primero) — **demostrado + medido**

### 1.1 Media / umbral

> **Resultado.** Bajo el criterio de éxito del `CONTRATO.md` (superar estrictamente el `blue_work`
> observable) y con el adversario **reteniendo** su rama, `α_mínimo = 1/2` **exacto**, para PoW
> lineal, GHOSTDAG sobre PoW y PoST-DAG, en los dos regímenes (§3.3). Etiqueta: **demostrado**.

La demostración es de contabilidad, no de criptografía (`MODELO.md` §1). Para una rama con fracción
de espacio `s`, el trabajo por slot es `E = λ(s,sr)·w(sr)/w(sr0) ≈ s·λ0`, **independiente de `sr`**:
la tasa de validación es `∝ sr` y el peso `∝ 1/sr`. Con retención, la honesta acumula `(1−α)` y el
adversario `α`; comparar da `α>1/2`, sin depender del horizonte. Comprobado de forma **exacta**
(`referencia.jl`) y contra el **oráculo GDR-v0.2** (`rapido.jl`):

| comprobación | resultado | artefacto |
|---|---|---|
| `(sr/sr0)·(w(sr)/w(sr0)) ≈ 1`, exacto | error_rel máx = **1,33e-14** | `run-teoria.txt` |
| Trabajo exacto `s=3/10`, `sr` ∈ {sr0/8…8·sr0} | `max/min = 1,000000000000007` | `run-teoria.txt` |
| Work/slot con GDR, `s`∈{0.1,0.3,0.5}, `sr`∈{sr0,4sr0} | ≈ `s` (tabla) | `run-gdr.txt` |

**Publicar está dominado.** Si el adversario publica sus bloques en la honesta, ésta acumula el
espacio completo (`h=1`) y la privada `α`: sólo ganaría con `α>1` (`α* = 1/sirv`). Por tanto el
umbral operativo es `1/2`, y el «doble uso» **no lo baja** (§4).

### 1.2 Régimen CORTO: la curva `α_mínimo(d, ε)`

El umbral `1/2` es el límite de horizonte infinito. Con una ventaja honesta inicial de `d` unidades
de trabajo y confianza `ε`, el adversario puede alcanzar con `α<1/2`. Para pasos ±1 (PoW lineal,
exacto):

| `d` | 3 | 6 | 12 | 24 | 50 | →∞ |
|---|---|---|---|---|---|---|
| `α_mínimo` (`ε=0,10`) | 0,317 | 0,405 | 0,452 | 0,476 | 0,489 | **0,500** |

`α_mínimo(d,ε) = 1/(1+ε^{−1/d}) → 1/2⁺`. Etiqueta: **demostrado** para pasos ±1; **medido** para el
proceso Poisson-step (DP, `run-corto.txt`).

**La contribución del DAG (Kaspa/ZEROX) es de varianza, no de umbral.** Con la misma media, más
granularidad `g` (más bloques por unidad de trabajo) reduce la cola del adversario. DP, `α=0,4`,
`d=6`:

| `g` | 1 | 4 | 16 | 64 | 256 |
|---|---|---|---|---|---|
| `P(alcance)` | 8,0e-2 | 6,6e-2 | 4,2e-2 | 1,3e-2 | 3,2e-26 |

Esto **separa el DAG del PoST**: el DAG baja la varianza (bien); el PoST abre un eje nuevo (§3).

### 1.3 Régimen LARGO (IBD / long-range)

El adversario dispone de tiempo arbitrario y sólo necesita superar el `blue_work` admitido al
presentar. Como el trabajo por slot es `∝` espacio y **el espacio se reutiliza en el tiempo pero no
se acumula más rápido** (la honesta también lo reutiliza durante toda la ventana), la comparación es
la misma: `α>1/2`. **No hay descuento long-range** en PoST frente a PoW bajo los supuestos del
`MODELO.md` (flujo PoT global único, un reto por slot, sin ventaja de VDF). Etiqueta: **demostrado
condicionado a los supuestos**; el supuesto del flujo es justo lo que el ATAQUE 2 ataca (§5).

---

## 2 · Comparación con PoW y Kaspa, mismo escenario y criterio

| Protocolo | `α*` medio | Granularidad | Doble uso | `α_min(d=6, ε=0,1)` |
|---|---:|---|---|---:|
| PoW lineal (Bitcoin) | **0,500** | 1 | no | 0,405 |
| GHOSTDAG sobre PoW (Kaspa) | **0,500** | alta (~10–100) | no | 0,405 (cola menor) |
| PoST-DAG (ZEROX) | **0,500** | **elegible por `sr`** | **sí (económico)** | 0,405 (cola ajustable) |

**Lectura.** ZEROX **no está peor** que PoW ni que Kaspa en el **umbral**: la media es `1/2` en los
tres. El DAG aporta menor varianza (mejor cola corta, como ya medía la investigación). La diferencia
de ZEROX es (a) el **coste** (§4) y (b) un eje de **varianza elegible** por el adversario (§3) que
Kaspa no tiene. Etiqueta: **demostrado** (media y estructura) + **medido** (cola).

---

## 3 · `SR` endógeno: dirección y magnitud — **demostrado + medido**

La intuición del §3.2 del encargo («`SR` menor ⇒ peso mayor») es cierta **por bloque**, pero la
validez es `∝ SR`: el producto es constante. **La dirección del controlador no cambia la media.**

- `CTRL_FIJO` y `CTRL_REACTIVO` (estable) dan `trabajo/slot ≈ s`; `CTRL_INVERSO` lleva `sr` al
  mínimo, deja de producir y su trabajo tiende a 0, no a más (`run-controladores.txt`).
- El vector de **media** exige **desacoplar** `sr_val` de `sr_peso`; en el SPEC son el **mismo**
  campo. Tabla de amplificación `sr_val/sr_peso`: 1 (acoplado), 4×, 16× (desacoplado).

**El riesgo real es de varianza.** Fijando `sr` bajo (bloques escasos y pesados), con el **mismo**
trabajo medio `α·T`, sube la probabilidad de superar a la honesta. MC, `α=0,45`, `T=400` slots:

| `K = sr0/sr` | 1 | 4 | 16 | 64 |
|---|---:|---:|---:|---:|
| `P(adv > hon)` | 0,022 | 0,097 | 0,244 | 0,308 |
| `E[trabajo_adv]` | 179,9 | 179,7 | 180,9 | 178,0 |

Mismo medio; la cola se compra con varianza. Etiqueta: **medido** (modelo), **condicionado** a que
el controlador permita ese `sr`. De ahí la propiedad MUST P2/P3 de `PROPUESTA.md`.

---

## 4 · Umbral frente a coste económico (§3.1) — **estimado**

Son dos consecuencias distintas y se cuantifican por separado:

- **Umbral:** no baja. `α*=1/2`; publicar da `α*=1` y está dominado.
- **Coste:** en PoW, atacar exige **desviar** recurso y renunciar a la recompensa honesta de `α`
  durante la ventana de ataque: `coste_op ≈ α·R·T_a`. En PoST el mismo espacio produce en la rama
  privada y el adversario puede seguir cobrando en la honesta hasta el punto de bifurcación; el
  **coste marginal de recurso del ataque es 0** y el coste de oportunidad se reduce al tramo de
  retención posterior a la bifurcación, `T_retención ≈ Δ·conf` para una reorg corta.
  `coste_op(PoST)/coste_op(PoW) → T_retención/T_a → 0` (reorg corta), `= 1` (long-range).

**Con `α>1/2` el ataque es «gratis» en recursos.** Eso es *nothing-at-stake*: encarece la
**honestidad** (opcionalidad) y **no** rompe el umbral. «Gratis» significa: sin espacio adicional,
sin renunciar a la recompensa honesta más allá de la ventana de retención. Etiqueta: **estimado**
(fórmula declarada, sin datos de red).

---

## 5 · Multiplicidad `m` y multistream `S` — **recalculado + condicional**

- **Multiplicidad de billetes `m` (D6):** la tasa sube `×m` en **ambas** ramas; la razón no cambia.
  `α*=1/2` independiente de `m`. Recalculado para esta pregunta (no heredado del encargo 05).
- **Multistream de PoT (ATAQUE 2, `research/dag-poas-auditoria.md`):** si el adversario puede abrir
  `S` flujos de PoT independientes, la cuota efectiva es `Sα/(1−α+Sα)`:

  | `S` | 2 | 4 | 8 | 16 | 24 |
  |---|---:|---:|---:|---:|---:|
  | `α_min` | 0,333 | 0,200 | 0,111 | 0,059 | 0,040 |

  Es el **único** vector medido que baja el umbral. Etiqueta: **no demostrado / condicional** al
  diseño del flujo PoT (si hay un único flujo global anclado a finalidad, desaparece; el precio es
  el adelanto de VDF de ATAQUE 1). **No se hereda** como veredicto: se da como escenario.

---

## 6 · U2/U3″ entre ramas disjuntas (§3.4) — **medido contra el oráculo**

| comprobación | resultado |
|---|---|
| Mismo billete dos veces dentro de una rama | válidas, pero **1 azul y 1 `rojo_U3`** |
| U2 (mismo billete en el pasado de un padre) | **rechazado** (`:u2`) |
| Mismo billete en **dos ramas disjuntas** | ambas válidas y **azules en su propia rama** |
| Un fusionador que ve ambas | una azul y la otra `rojo_U3` |

→ U3″ **sí** bloquea el doble uso **dentro** de una rama y **no** entre ramas disjuntas. Una rama
privada disjunta no ve el billete de la pública. Etiqueta: **medido** (GDR-v0.2).

---

## 7 · Las cinco preguntas de LINEO

1. **Complejidad.** Referencia exacta: `O(|srs|)` por tabla; MC: `O(rep·slots)`; DP curva corta:
   `O(nmax·corte·iter)`. GDR: `O(bloques·mergeset)`. Dominante: rep×slots en MC y `nmax` en el DP.
2. **Perfil y asignaciones.** `simular_rama_rapido` (1000 slots): **896 B / 26 allocs** tras eliminar
   el cálculo de `peso_relativo` del bucle (antes 896 kB / 26 000). `barrido_alpha`: 1,1 MB. Sin BLAS.
   Escalado 1→24 hilos del barrido: `0,272 → 0,051 s` (×5,3), resultados **idénticos** entre 1 y 24.
   `@code_warntype` sin `Any` en el kernel (`WARNTYPE.txt`); perfil de la ruta real en `PERFIL.txt`.
3. **Oráculo.** GDR-v0.2 para GHOSTDAG (no se reimplementa); referencia **independiente** por
   Poisson exponencial vs Knuth (equivalencia 3σ) y por contabilidad exacta `Rational{BigInt}`; DP y
   ruina exacta comparados.
4. **Tipos numéricos.** Veredicto discreto en enteros/BigInt; MC en `Float64` con número de
   réplicas, semilla e IC declarados; **sin `@fastmath`**, sin `@simd`/`@turbo`/`Float32`.
5. **Semilla, versión, hardware.** `0xC057E07`; cada artefacto de `resultados/` lleva git, fecha,
   Julia 1.13.0, `znver5`, hilos y `Pkg.status` (`ENTORNO.txt`).

Tabla de rendimiento (formato LINEO §6):

| Variante | Tiempo mediano | Asignaciones | Hilos | Resultado frente a referencia |
|---|---:|---:|---|---|
| Oráculo exacto `Rational{BigInt}` | 7,1 µs / tabla | 444 | 1 | fuente de verdad exacta |
| DP curva corta (`g=16`, `d=6`) | 1,74 ms | 9 | 1 | coincide en orden con la ruina exacta |
| Kernel MC `simular_rama_rapido` (1000 slots) | 10,6 µs | 26 | 1 | ≈ `s` (media), validado |
| `barrido_alpha` (3 α, 200 rep, 300 slots) | 0,61 ms | 1,1 MB | 8 | determinista (idéntico por RNG de réplica) |
| `barrido_alpha` (3 α, 8000 rep, 400 slots) | 51 ms | — | 24 | idéntico 1…24 hilos |

---

## 8 · Supuesto de red y sensibilidad

Δ se toma del orden de `veritas/finalidad/delta-medido-v1/` (Δ_50 sub-segundo; Δ_100 ≤ ~2,2 s en
redes ER grandes). La fracción roja del DAG crece con `λ·Δ/k`; **en ambas ramas**. Si Δ se relaja,
baja el trabajo efectivo por recurso y empeora la cola corta, pero `α*` medio sigue en `1/2`. El
adversario, al controlar la estructura de su rama privada, podría sufrir menos rojos que la honesta
(efecto no medido aquí): **no demostrado**, se deja declarado.

---

## 9 · Límites y lo que se rechaza

**Límites.** El acoplamiento espacio↔solución es supuesto declarado. `sr0`, `λ0` son de
normalización. El multistream es condicional. El efecto «rojos asimétricos» no se mide. R-FIN-13′
**no está especificado**: el resultado del §3 es una **familia** y una **propiedad**, no una
constante.

**Inconcluso por R-FIN-13′.** La curva corta de ZEROX con controlador **real** (no una familia) no
puede cerrarse hasta especificar ventana, arranque, redondeos y «validación de ramas candidatas con
pesos reales» (`TAREAS.md` §2.3). El entregable es `PROPUESTA.md` (P1–P4), que convierte ese
pendiente vago en requisitos escritos.

**Se rechaza explícitamente:** dar por hecho que el doble uso baja el umbral; suponer la dirección
del controlador; mezclar regímenes corto y largo; publicar un `α_mínimo` sin las dos referencias; y
heredar cualquier veredicto de los encargos 05 o 06.

**Veredicto final (uno de los tres del encargo §7).** `α_mínimo ≈ 1/2` en los dos regímenes con
todas las salvedades anteriores: ZEROX está **en la liga de PoW**; el problema de la poda/IBD es de
**ingeniería**, con dos cabos sueltos concretos — la varianza del `SR` (acotable por P1–P3) y el
multistream de PoT (que baja el umbral **si** el flujo no es único). Ninguno de los dos es una
pérdida de umbral intrínseca del PoST DAG.
