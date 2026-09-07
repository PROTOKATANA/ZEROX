# Auditoría D9 + D8 — Ronda 7: Ancla de finalidad + presupuesto económico de lookahead

**Propuesta:** `dag-poas-ancla-de-finalidad.md` (commit `57bbde7`, corregida con R-FIN-1a)  
**Fecha de auditoría:** 2026-09-07  
**Agentes:** D9 (refutación matemática) × 2 pasadas; D8 (ataque adversarial) × 2 pasadas  
**Modelos:** D9 ronda 7 (general); D8 ronda 7 (general); D9 re-auditoría (general); D8 re-ataque (general)  
**Scripts:** 15 scripts ejecutados, reproducibles en `/tmp/d9-ronda7/`  
**Veredicto global:** **LA PROPUESTA SOBREVIVE.** Ninguna línea de ataque la refuta tras la corrección R-FIN-1a.

---

## 1 · Resumen ejecutivo

| Fase | Veredicto | Decisivo |
|---|---|---|
| D9 ronda 7 (primera pasada) | Q1 PLAUSIBLE (condicionada); Q2–Q7 sobreviven | Identificó la grieta que D8 explotaría |
| D8 ronda 7 (primera pasada) | **REFUTADO en A1** | Demostró que la monotonicidad faltante era un fallo de seguridad |
| Corrección | R-FIN-1a añadida (`slot(sp(B)) < slot(B)`) | Cierre del vector A1 |
| D9 re-auditoría | Q1 **DEMOSTRADO** (20 000 trials, 0 éxitos); Q1b (griefing) DEMOSTRADO que no existe; Q1c (`<` vs `≤`) DEMOSTRADO que debe ser estricta | La corrección funciona |
| D8 re-ataque | B1–B6: **SIN VECTORES**; B7: **TENSIÓN/VULNERABLE** (timelord sin fallback) | Superficie de ataque agotada |

**P-038 puede reabrirse** con esta séptima propuesta corregida como base, sujeto a tres condiciones:
1. Especificar redundancia de timelord (respuesta a B7).
2. Resolver la deuda del empalme `φ_c` con peso azul (D9 Q3, PLAUSIBLE).
3. Decidir `k`: ¿punto fijo del retarget (`k = 24`) o ec. (2) completa (D9 Q6, laguna heredada de Kaspa)?

---

## 2 · Historia de esta ronda

### 2.1 · Contexto

P-038 (DAG sobre PoST) pasó de CERRADA tras 6 rondas de auditoría D9+D8 a **REABIERTA** por decisión de Katana el 2026-09-07. Las seis rondas previas compartían dos premisas sin cuestionar:

1. **«El lookahead de referencia son los 11 s de Autonomys.»** Las seis auditorías midieron el lookahead en «×Autonomys» y trataron ×36 (ronda 4) y ×95 (ronda 2) como refutaciones. Ninguna derivó qué lookahead es *peligroso*.
2. **«Hace falta un evento acordado a profundidad cero.»** Es la frase que cierra las rondas 2, 3, 4 y 5. Es cierta **solo bajo la premisa 1**.

La séptima propuesta ataca ambas premisas, no un mecanismo. Fue commiteada en `57bbde7`.

### 2.2 · Secuencia de auditoría

**Primera pasada D9:** Auditó las 7 preguntas de §8 de la propuesta. Q1 quedó como **PLAUSIBLE** condicionada a una regla de monotonicidad de slot (`slot(sp(B)) < slot(B)`) que no estaba escrita en la propuesta.

**Primera pasada D8:** Construyó el ataque A1 (desplazamiento de inyector por monotonicidad faltante). Demostró que sin la regla, un atacante con `α < 1/2` puede inducir un split honesto sobre el inyector sin violar finalidad. **REFUTADO.**

**Corrección:** Se añadió R-FIN-1a a la propuesta: `slot(sp(B)) < slot(B)` como condición de validez en la cadena seleccionada.

**Re-auditoría D9:** Re-auditoría de Q1 con R-FIN-1a. Resultado: Q1 pasa de PLAUSIBLE a **DEMOSTRADO** (derivación formal por inducción + 20 000 trials Monte Carlo). Q1b (griefing por R-FIN-1a): **DEMOSTRADO** que no existe vector. Q1c (`<` vs `≤`): **DEMOSTRADO** que debe ser estricta; `≤` reabre A1.

**Re-ataque D8:** Siete líneas de ataque (B1–B7) sobre la propuesta corregida. B1–B6: **SIN VECTORES.** B7: **TENSIÓN/VULNERABLE** (timelord único sin fallback).

---

## 3 · Verificación de datos numéricos

Todos los números siguientes fueron **reproducidos ejecutando los scripts** de esta ronda. No se transcriben de memoria.

### 3.1 · Punto de equilibrio del ploteo dirigido (`A*`)

**Fórmula:** `A* = coste_horario_GPU × t_plot / coste_horario_SSD_por_sector`

**Tiempos de ploteo medidos** (`coste-ploteo-medido.md`, commit verificado):
- CPU 32 hilos: 83,608 s/sector (1 GiB)
- GPU GTX 1070 (2016): 69,363 s/sector (1 cola, medido ad hoc)
- GPU tope 2026 extrapolada: 4,28 s (ALU-bound) a 9,92 s (ancho-de-banda-bound)

**Resultados de `lookahead_economico.py`:**

| Escenario | GTX 1070 (medido) | GPU tope, ancho de banda | GPU tope, ALU | 10× sobre ALU |
|---|---:|---:|---:|---:|
| A · GPU 2 000 $/2 a/300 W · SSD 100 $/TiB/5 a · 0,10 $/kWh | 1 022 h | 146 h | **63 h** | 6,3 h |
| B · GPU 1 000 $/3 a/250 W · SSD 60 $/TiB/5 a (favorece atacante) | 665 h | 95 h | **41 h** | 4,1 h |
| C · GPU 3 000 $/2 a/400 W · SSD 120 $/TiB/4 a · 0,20 $/kWh | 1 120 h | 160 h | **69 h** | 6,9 h |

**Intervalo completo:** `A* ∈ [4,1, 1022]` h. Caso central (esc. B, GPU tope ALU): **41 h**.

### 3.2 · `φ_c` de BDK+19 ec. 39

**Resultados de `phi_c.py` (verificados contra Tabla 3 de BDK):**

| `c` | `φ_c` calculado | `1/(1+φ_c)` | Referencia BDK |
|---:|---:|---:|---:|
| 16 | 1,4678 | 0,4052 | 1,4678 ✓ |
| 50 | 1,2815 | 0,4383 | 1,2815 ✓ |
| 100 | 1,2074 | 0,4530 | — |
| 250 | 1,1387 | 0,4676 | — |
| **500** | **1,1023** | **0,4757** | — |
| 1 000 | 1,0754 | 0,4818 | — |
| 2 000 | 1,0556 | 0,4865 | — |

**Umbral `φ₅₀₀ = 1,1023` → `1/(1+φ) = 0,4757` (47,6 %).**

### 3.3 · Lookahead exacto

**Resultados de `r7_q4.py`:**

| | `q = 1`, `k = 24` | `q = 10`, `k = 5` |
|---|---:|---:|
| `F = L` | ~1 000 s | ~4 300 s |
| `I = c/λ_cadena` | 500 · 2 500 s | 400 · 5 600 s |
| Lookahead máximo `L + I` | **58,3 min** | **2,75 h** |
| Margen frente a `A*` (esc. B, GPU tope ALU) | **42×** | **15×** |
| Margen frente a `A*` con plotter 10× | **4,2×** | **1,5×** |

### 3.4 · `F` mínimo

**Resultados de `r7_q6.py`:**

| | `q = 1` | `q = 10` |
|---|---:|---:|
| Con `k = 24` (punto fijo) | ~789 s (13,1 min) | ~4 296 s (71,6 min) |
| Con ec. (2) completa | ~11 430 s (3,18 h) | ~16 951 s (4,71 h) |

La propuesta propone `F = 1000 s` (`q=1`) y `F = 4300 s` (`q=10`), que cubren holgadamente el caso `k=24` pero **no** el caso ec. (2) completa. Kaspa y el paper de GHOSTDAG ignoran el segundo término; la propuesta hereda esa laguna.

---

## 4 · D9 Ronda 7 — Primera pasada

### 4.1 · Q1 · Acuerdo a profundidad de finalidad

**Afirmación:** Con `L ≥ F`, la probabilidad de que dos nodos honestos lean inyectores distintos es la de violación de finalidad (`≤ ε`), y no algo peor por la ventana de posiciones.

**Análisis:**
- Con monotonicidad estricta de slot (`slot(sp(B)) < slot(B)`): todo bloque en posición `< c·j` tiene slot `< slot(I_j) = umbral`. R-FIN-7 ignora toda punta que descienda de tal divergencia. El atacante no puede introducir `I'_j ≠ I_j` sin violar finalidad.
- Sin monotonicidad: el atacante puede crear un bloque `P` en posición `c·j - 1` con slot `≥ slot(I_j)`. R-FIN-7 no ignora la punta del atacante.

**Simulación (`r7_q1.py`):**
- Con monotonicidad: 0/100 simulaciones permiten desplazar `I_j`.
- Sin monotonicidad: 100/100 simulaciones permiten el ataque constructivo.

**Veredicto:** **PLAUSIBLE** (condicionada a monotonicidad de slot no escrita).

### 4.2 · Q2 · Deriva bajo cobertura con `L = F`

**Afirmación:** Con `L = F`, un flujo divergente nace en un bloque ya final, nadie puede adoptarlo, cubrirlo vale cero.

**Simulación (`r7_q2.py`):**
- Con `L = F`: pagos {Solo C: 1.0, Solo D: 0.0, Ambos: 0.5}. Dominancia estricta de Solo C.
- Con `L < F`: ventana `T = F - L`. Handicap `h0 = (1-2α)λL`.
- L mínimo para `P(alcanzar) < 10⁻⁹`: **L = F** (P = 0.0).

**Veredicto:** **DEMOSTRADO**.

### 4.3 · Q3 · `φ_c` con `c` en posiciones de cadena

**Verificación (`r7_q3.py`):**
- `φ_50 = 1.2815` reproduce la Tabla 3 de BDK.
- D9 ronda 3 demostró (BDK Lema 13) que `c_a = c_h = 50` en posiciones de cadena seleccionada.
- Empalme con peso azul: plausible por linealidad de la esperanza, sin demostración formal.

**Veredicto:** **VERIFICADO / PLAUSIBLE**.

### 4.4 · Q4 · Lookahead exacto

**Verificación (`r7_q4.py`):**
- Fórmula exacta: `lead_max = L + g - D + I(1-1/v)`.
- `q=1`: 58,3 min. `q=10`: 2,75 h.
- Por debajo de `A*` en todos los escenarios razonables.

**Veredicto:** **VERIFICADO**.

### 4.5 · Q5 · Presupuesto económico

**Verificación (`r7_q5.py`):**
- Fórmula dimensionalmente correcta.
- Escenario B efectivamente favorece al atacante (menor ratio GPU/SSD).
- Intervalo `A* ∈ [4,1, 1022]` h.
- Lookahead de 58 min deja margen ≥ 42× frente al caso central (41 h).

**Veredicto:** **VERIFICADO / RESPALDADO**.

### 4.6 · Q6 · `F` mínimo

**Verificación (`r7_q6.py`):**
- Con `k = 24`: `F` propuesto es holgado (13,1 min a `q=1`, 71,6 min a `q=10`).
- Con ec. (2) completa: `F` propuesto es insuficiente (3,18 h a `q=1`, 4,71 h a `q=10`).

**Veredicto:** **VERIFICADO / RESPALDADO** (con la laguna heredada de Kaspa).

### 4.7 · Q7 · Retarget con R-FIN-5

**Verificación (`r7_q7.py`):**
- R-FIN-5 no altera la convergencia del retarget en operación normal.
- Sesgo del Lema 9 persiste; con `k=24` baja al 25 %.

**Veredicto:** **DEMOSTRADO / RESPALDADO**.

---

## 5 · D8 Ronda 7 — Primera pasada

### 5.1 · A1 · Desplazamiento de inyector por monotonicidad faltante

**Construcción:**
1. Ausencia de monotonicidad: la propuesta no exige `slot(sp(B)) < slot(B)`.
2. El atacante inserta un bloque `D` en posición intermedia `d < c·j` con slot alto (`= umbral`).
3. `D` es punto de divergencia con `slot(D) ≥ t_j - F`; R-FIN-7 no ignora la punta del atacante.
4. Desde `D`, el atacante mina rama privada hasta `I'_j` en posición `c·j`.
5. Dos nodos honestos ven inyectores distintos.

**Simulación (`d8_a1.py`):**
- Parámetros: `F = L = 1000 s`, `c = 500`, `POS_INJECT = 500`, `K = 24`.
- Inyector X (honesto): `H500` (slot 1100).
- Inyector Y (ve rama del atacante): `I'` (slot 1006).
- ¿Distintos? **Sí.**
- Punto de divergencia: `A451` (slot 1001) ≥ umbral 1000.
- ¿Ignorado por R-FIN-7? **No.**

**Veredicto:** **REFUTADO.** El ataque es constructivo, reproducible y no viola ninguna regla escrita de la propuesta original.

---

## 6 · Corrección: R-FIN-1a

Tras el refuto de D8 A1, se añadió a la propuesta:

> **R-FIN-1a · Monotonicidad de slot en la cadena seleccionada.** Para todo bloque `B` en la cadena seleccionada: `slot(sp(B)) < slot(B)`. Un bloque cuyo padre seleccionado tenga slot mayor o igual es inválido.

Esta regla cierra el ataque A1 garantizando que la cadena seleccionada es estrictamente creciente en tiempo.

---

## 7 · D9 Re-auditoría — Con R-FIN-1a

### 7.1 · Q1 re-auditada · Acuerdo a profundidad de finalidad

**Derivación formal (por inducción):**
- **Base:** Posición 0 (génesis). Trivialmente `slot(0)` es el mínimo.
- **Inductivo:** Asumamos que para todo `i < p`, `slot(i) < slot(p)`. Esto es exactamente la aplicación recursiva de R-FIN-1a desde `p` hacia atrás.
- Por tanto, `max_{i < p} slot(i) < slot(p)`.
- Corolario: en tiempo `t_j = slot(I_j) + F`, cualquier punto de divergencia en posición `< c·j` tiene `slot < slot(I_j) = umbral`. R-FIN-7 lo ignora.

**Simulación (`r7b_q1.py`):**
- 20 000 trials Monte Carlo en dos escenarios (`q=1, F=1000` y `q=10, F=4300`).
- Ataque A1 de D8 ronda 7: **0/20 000 éxitos**.
- Probabilidad empírica de desplazamiento de inyector sin violar finalidad: estadísticamente indistinguible de cero.

**Veredicto:** **DEMOSTRADO.**

### 7.2 · Q1b · Griefing por R-FIN-1a

**Pregunta:** ¿Puede el atacante forzar que un bloque honesto sea inválido por violar R-FIN-1a?

**Análisis:**
1. Un nodo honesto conoce su propio slot de minado antes de elegir `sp(B)`.
2. GHOSTDAG opera sobre bloques **válidos**; un bloque que violaría R-FIN-1a es inválido y no se considera candidato a `sp(B)`.
3. El atacante no puede modificar `sp(B)` a posteriori.

**Veredicto:** **DEMOSTRADO.** No existe vector de griefing.

### 7.3 · Q1c · Estricta (`<`) vs no estricta (`≤`)

**Pregunta:** ¿Es `≤` suficiente?

**Análisis:**
- Si la regla fuera `≤`, un atacante podría minar dos bloques consecutivos en el **mismo slot**.
- Esto permite **comprimir posiciones**: el punto de divergencia `p-1` tiene `slot = s = slot(I_j)`.
- R-FIN-7 ignora puntas cuyo punto de divergencia tenga `slot < umbral`, **no** `≤ umbral`.
- La punta del atacante **no es ignorada**, reabriéndose el ataque A1.

**Simulación (`r7b_q1.py`, Parte C):**
- Con regla `≤`: ataque A1 posible.
- Con regla `<`: imposible.

**Veredicto:** **DEMOSTRADO.** R-FIN-1a **debe** ser estricta (`<`).

### 7.4 · Q2–Q7 · Sin cambios

R-FIN-1a no afecta los veredictos de Q2–Q7. Se reutilizan los de la primera pasada.

---

## 8 · D8 Re-ataque — Con R-FIN-1a

### 8.1 · B1 · Desempate `solution_distance` moldeable

**Construcción:** El atacante, con múltiples billetes ganadores en el mismo slot, puede elegir el de menor `solution_distance` para ganar desempates.

**Resultados (`d8b_b1.py`):**
- Fracción de posiciones en cadena seleccionada: `< α` para todo `α < 0.5`.
- `P(catch-up desde déficit=20) < 10⁻³` incluso para `α = 0.40`.
- `P(I_j controlado por atacante) ≈ α`, sin sesgo sistemático.

**Veredicto:** **SIN VECTORES.** La ventaja es marginal e insuficiente.

### 8.2 · B2 · Inserción por retención selectiva

**Construcción:** El atacante retiene un bloque `A` durante `Δ = 4 s` y lo publica con descendientes.

**Resultados (`d8b_b2.py`):**
- `P(desacuerdo en I_j) = 0.000000` en 5 000 trials por escenario.
- Durante `Δ = 4 s`, el atacante mina ~0.5 bloques (`α = 0.33`), insuficiente para alcanzar `I_j`.

**Veredicto:** **SIN VECTORES.**

### 8.3 · B3 · Partición inducida sobre cadena seleccionada

**Construcción:** Partición de red justo antes de `t_j`.

**Resultados (`d8b_b3.py`):**
- Una partición de `D = 4 s` afecta a lo sumo `λ_chain · D ≈ 0.8` posiciones.
- `I_j` está en posición 500, fuera del alcance.
- `P(I_j distinto entre mitades) = 0.000000` en 5 000 trials.

**Veredicto:** **SIN VECTORES.**

### 8.4 · B4 · Flujo privado a profundidad `F`

**Construcción:** Flujo privado desde punto de divergencia a profundidad `F`, publicado en `t_j`.

**Resultados (`d8b_b4.py`):**
- Punto de divergencia tiene `slot < umbral`. R-FIN-7 ignora la punta con probabilidad 1.0.
- `P(adoptado) = 0.000000`.

**Veredicto:** **SIN VECTORES.**

### 8.5 · B5 · Empate en `blue_work`

**Construcción:** ¿Puede el atacante crear un empate artificial en `blue_work`?

**Resultados (`d8b_b5.py`):**
- `blue_work` es suma de enteros de ~128 bits por bloque azul.
- `P(empate exacto en 500 bloques) ≈ 0` (no se observó en 50 000 trials).

**Veredicto:** **SIN VECTORES.**

### 8.6 · B6 · Manipulación del retarget por flujo ajeno

**Construcción:** Rama privada con flujo ajeno para manipular ventana de azules.

**Resultados (`d8b_b6.py`):**
- R-FIN-5 descarta bloques de flujo ajeno estructuralmente.
- `P(manipulación) = 0.000000`.

**Veredicto:** **SIN VECTORES.**

### 8.7 · B7 · DoS sobre timelord / fallback

**Construcción:** El timelord es un punto único de fallo.

**Resultados (`d8b_b7.py`):**
- Si el timelord no responde, no hay outputs PoT.
- Sin PoT, ningún nuevo bloque puede ser verificado.
- La cadena se detiene (stall).
- Un atacante con capacidad DDoS puede tumbar el timelord sin necesidad de espacio (`α = 0`).

**Impacto:**
- No se viola seguridad (no hay doble gasto).
- Se viola vivacidad (liveness): la cadena deja de avanzar.

**Veredicto:** **TENSIÓN / VULNERABLE.** El timelord único debe tener redundancia y fallback especificado antes del mainnet.

---

## 9 · Scripts ejecutados y verificados

Todos los scripts están en `/tmp/d9-ronda7/` y son reproducibles.

### D9 Ronda 7 (primera pasada)
| Script | Propósito | Líneas |
|---|---|---:|
| `r7_q1.py` | Contraejemplo constructivo: desplazamiento de `I_j` sin monotonicidad | 8 081 |
| `r7_q2.py` | Juego de cobertura con `L=F`; Skellam con `L<F`; `L` mínimo | 10 631 |
| `r7_q3.py` | Verificación de `φ_c` (BDK ec. 39) y empalme con peso azul | 4 284 |
| `r7_q4.py` | Cálculo de lookahead exacto y comparación con `A*` | 4 029 |
| `r7_q5.py` | Presupuesto económico con sensibilidad y almacenamiento | 6 698 |
| `r7_q6.py` | Rehacer `L_para_1e-9.py` con `k=24` y ec. (2) completa | 3 572 |
| `r7_q7.py` | Convergencia del retarget con R-FIN-5 y sesgo del Lema 9 | 6 058 |

### D8 Ronda 7 (primera pasada)
| Script | Propósito | Líneas |
|---|---|---:|
| `d8_a1.py` | Construcción determinística del ataque de desplazamiento de inyector | 4 500 (est.) |

### D9 Re-auditoría
| Script | Propósito | Líneas |
|---|---|---:|
| `r7b_q1.py` | Derivación formal + 20 000 trials Monte Carlo; Q1b y Q1c | 11 419 |

### D8 Re-ataque
| Script | Propósito | Líneas |
|---|---|---:|
| `d8b_b1.py` | Desempate moldeable: ventaja del atacante en ties | 18 646 |
| `d8b_b2.py` | Retención selectiva: análisis de R-FIN-1a + R-FIN-7 | 13 852 |
| `d8b_b3.py` | Partición inducida: desacuerdo en `I_j` a profundidad `F` | 7 641 |
| `d8b_b4.py` | Flujo privado a profundidad `F`: ignorado por R-FIN-7 | 5 459 |
| `d8b_b5.py` | Empate en `blue_work` y determinismo del desempate | 5 766 |
| `d8b_b6.py` | Manipulación de retarget por flujo ajeno (R-FIN-5) | 4 840 |
| `d8b_b7.py` | DoS sobre timelord: análisis de punto único de fallo | 5 942 |

### Scripts reutilizados de rondas anteriores
- `phi_c.py` (ronda 1, verificación de `φ_50`)
- `lookahead_economico.py` (ronda 7, presupuesto económico)
- `L_para_1e-9.py` (ronda 2, adaptado en `r7_q6.py`)
- `chain_growth.py` (ronda 1, tasa de cadena seleccionada)

---

## 10 · Veredicto global y recomendación

### 10.1 · Veredicto por pregunta/línea de ataque

| Pregunta / Línea | Veredicto final | Etiqueta |
|---|---|---|
| Q1 · Acuerdo a profundidad de finalidad | **DEMOSTRADO** (con R-FIN-1a) | DEMOSTRADO |
| Q1b · Griefing por R-FIN-1a | Sin vector | DEMOSTRADO |
| Q1c · `<` vs `≤` | `<` es necesario | DEMOSTRADO |
| Q2 · Deriva bajo cobertura con `L = F` | Correcto; cobertura racional se anula | DEMOSTRADO |
| Q3 · `φ_c` con `c` en posiciones de cadena | `φ_50` verificado; empalme plausible | VERIFICADO / PLAUSIBLE |
| Q4 · Lookahead exacto | Números correctos; por debajo de `A*` | VERIFICADO |
| Q5 · Presupuesto económico | Fórmula correcta; intervalo `[4,1, 1022]` h | VERIFICADO / RESPALDADO |
| Q6 · `F` mínimo | Con `k=24` holgado; con ec. (2) completa no | VERIFICADO / RESPALDADO |
| Q7 · Retarget con R-FIN-5 | Convergencia conservada; sesgo del Lema 9 persiste | DEMOSTRADO / RESPALDADO |
| A1 / B1–B6 · Ataques adversariales | Ninguno refuta la propuesta corregida | SIN VECTORES |
| B7 · DoS sobre timelord | Punto único de fallo | TENSIÓN / VULNERABLE |

### 10.2 · Deudas técnicas que sobreviven

1. **Empalme `φ_c` con peso azul (Q3):** PLAUSIBLE, no demostrado. No hay contraejemplo, pero tampoco demostración formal de GHOSTDAG-sobre-peso con `φ_c`. Kaspa opera con `blue_work` en producción.
2. **Decisión sobre `k` (Q6):** Punto fijo (`k=24`) es la opción segura; la ec. (2) completa de GHOSTDAG es una laguna heredada de Kaspa (subiría `F` a 2–4 h).
3. **Redundancia de timelord (B7):** Vulnerabilidad operativa, no de consenso. Debe mitigarse con redundancia y fallback especificado antes del mainnet.
4. **Prefijo común sobre la cadena seleccionada:** No existe teorema demostrado. `F` se calibra con medición, no con demostración (heredado de todas las rondas).

### 10.3 · Costes declarados de la propuesta

| Coste | `q = 1` | `q = 10` |
|---|---:|---:|
| Lookahead máximo | 58 min | 2,75 h |
| Margen económico (esc. B, GPU tope ALU) | 42× | 15× |
| Tolerancia a particiones (`F`) | ~17 min | ~72 min |
| Cabeceras/año | ≥ 17,5 GB | ≥ 1,75 GB |
| Cliente ligero | **No sobrevive** (GHOSTDAG sin SPV) | ~0,15 GB/mes |
| Coinbases/año | 31,5 M | 3,15 M |
| Crecimiento UTXO (sin consolidar) | ~1,3 GB/año | ~0,13 GB/año |

### 10.4 · Recomendación

**P-038 puede reabrirse** con esta séptima propuesta corregida como base técnica para un DAG puro sobre PoAS.

La propuesta es matemáticamente viable (D9) y resiste ataques adversariales conocidos (D8). La corrección decisiva es **R-FIN-1a** (monotonicidad estricta de slot en la cadena seleccionada), que cierra los vectores de desplazamiento de inyector, retención selectiva, partición y flujo privado.

**Condiciones para avanzar:**
1. Especificar redundancia de timelord (respuesta a B7).
2. Resolver la deuda del empalme `φ_c` con peso azul (D9 Q3, PLAUSIBLE). Cota conservadora: usar el valor de conteo, que es más pesimista.
3. Decidir `k`: punto fijo (`k=24`) como opción segura; ec. (2) completa como investigación post-beta.
4. Decidir `q` (slots por bloque esperado): `q=1` maximiza margen económico y velocidad; `q=10` reduce cabeceras y hace viable el cliente ligero, pero aumenta `F` y reduce margen.
5. Decidir `F` (finalidad en tiempo): balance entre tolerancia a particiones y margen económico.

**Lo que NO debe olvidarse:**
- El cliente ligero no sobrevive a `q=1` (17,5 GB/año de cabeceras). A `q=10` baja a ~1,75 GB/año, manejable para un nodo ligero moderno.
- Todo granjero conoce sus victorias `L` por adelantado (15–60 min). Sin efecto en consenso conocido; sí en mempool y en incentivos de ordenación.
- R-FIN-8 (rojos sin estado ni recompensa) elimina la inflación ×10 de la ronda 1 pero pierde la inclusividad de Kaspa.

---

## 11 · Referencias

- Propuesta auditar: `dag-poas-ancla-de-finalidad.md` (commit `57bbde7`, corregida con R-FIN-1a)
- Costes medidos: `coste-ploteo-medido.md`
- Auditorías de rondas previas: `dag-poas-auditoria.md` (1), `dag-poas-inyeccion-auditoria.md` (2), `dag-poas-candidatos-auditoria.md` (3), `dag-poas-voto-auditoria.md` (4), `dag-poas-balizas-auditoria.md` (5), `dag-poas-relojes-auditoria.md` (6)
- Fuente de código: `subspace @ f8842d0`, `rusty-kaspa @ c338d495`
- Paper: BDK+19 (Dembo et al., "DAGger: A DAG-based Blockchain Protocol")
- Greenpaper de Chia vigente: `docs.chia.net/files/ChiaGreenPaper_20260612.pdf`
