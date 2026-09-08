# Auditoría 9a — Ronda 10a: ¿puede la revelación retardada por VDF (R-FIN-14 (h)) ser núcleo?

**Pregunta:** romper la opción (h) de R-FIN-14 (`entropía_j = VDF(chunk(I_j) ‖ salida(I_j), L·iter)`), escribir antes su
regla operativa completa, y decir si puede ser núcleo. · **Fecha:** 2026-09-09, madrugada · **Agente:** D8 en **Opus 5**,
relanzado sin presupuesto de tiempo por orden de Katana, continuando desde su primer intento · **Informe (995 líneas), 7
scripts + 1 microbanco en C, 8 commits solo en su directorio:** `research/scripts/d8-ronda10a/`.

> **VEREDICTO (mío, tras reproducir B.1 y C):** **(h) puede ser núcleo, pero no con el texto que tenía, no por la razón que
> 9c dio, y no a la calibración vigente.** (1) La promesa de 9c §E.5, «steering 0 para cualquier `ρ`», es **FALSA**: el
> atacante no espera a que le revelen `entropía_j`, la calcula él, porque sus dos entradas son públicas; la ronda 7
> (`dag-poas-ancla-de-finalidad.md:319-322`) ya lo tenía bien y 9c la contradijo. Lo que (h) hace es dividir el steering
> por **279** en el rango físico del reloj (`ρ ≤ 2,5`) y anularlo solo hasta `ρ* = (L + I)/(I + W_dec)` = **9,2** con
> `I = 851 s`, `L = 2 h`. (2) **Protección y coste son el mismo número:** `ρ* ≈ 1 + L/I` y el multiplicador de verificación
> por nodo es `1 + L/I` (razón 0,977 en seis filas). Con la calibración vigente se compra tolerancia a 9,2× y se pagan
> **0,81 núcleos por nodo** cuando el techo físico estimado del reloj AES es 1,5-2,5×. Con `ρ_max = 2,5` basta
> `I = 4 725 s`: **0,15 núcleos** y `q + 1 = 3` líneas en el timekeeper, a cambio de lookahead `I + F = 3,3 h`. (3) **Vector
> nuevo, de hardware:** en una partición, el lado que no sostenga `q + 1` líneas de AES no produce bloques válidos desde su
> primer `t_j` aunque conserve todo su espacio; con `q + 1 = 10` y 4 núcleos, la revelación llega 3 h tarde. (4) La regla
> (h.3) «continuidad por defecto» del primer intento **rompía R-FIN-5** (hacía `flujo` depender de cuándo llega un
> mensaje) y queda sustituida por **(h.3′) validez incondicional**: la entropía no se publica, se calcula; quien no tenga
> los checkpoints recomputa a ×16,24. (5) DoS de verificación **refutado** (asimetría 16,2×, 32,4× verificando en orden
> aleatorio; Autonomys ya aplica la misma defensa, `gossip.rs:32,438-441`). (6) (h) **no** cambia la frontera de flujo
> único (`prev()` no contiene `ρ`; control idéntico). (7) La LAGUNA «ráfagas planificadas con adelanto» queda **cerrada**:
> una carrera por segundo durante 10 años cuesta 0,46 puntos; el caso real, < 0,08.

---

## 0 · Verificación independiente del agente principal

| Comprobación | Resultado |
|---|---|
| Commits `34157a2`…`931ffcd` | **Solo su directorio** |
| `AUDITA_SCRIPTS.py` (7 scripts) | 6 marcas `[T3b]`. Leídas por mí `r10a_lib.py:135` (`off`/`paso`: dos arrays distintos inicializados igual) y `r10a_c_coste.py:87` (`nucleo_verif`/`rev`: el mismo coste usado en dos tablas); las otras cuatro son pares control/medida con el mismo texto y estado global distinto, según el agente. Ninguna es una tautología |
| **`r10a_b1_reloj.py` re-ejecutado por mí** (14 semillas × 4 000 épocas, ~25 min) | Salida **IDÉNTICA** a `salida_b1.txt` línea a línea |
| **`r10a_c_coste.py` re-ejecutado por mí** | **IDÉNTICO** a `salida_c.txt` |
| Citas de Chia (`PDF/chia-blockchain` v2.7.4), leídas por mí | `chia/timelord/types.py:6-10` (`INFUSED_CHALLENGE_CHAIN = 3`) ✓ · `timelord.py:351` (itera las tres cadenas) ✓ · `consensus/block_header_validation.py:170` (`deficit < MIN_BLOCKS_PER_CHALLENGE_BLOCK`) y `:204` (`not icc iff icc_challenge hash is None`) ✓ · `default_constants.py:15,38` (16; 600 s) ✓ |
| Cita de Autonomys @ `f8842d0` | `sc-proof-of-time/src/source/gossip.rs:32` (`EXPECTED_POT_VERIFICATION_SPEEDUP = 7`) y `:438-441` («*If we have too many unique proofs to verify it might be cheaper to prove it ourselves*») ✓ |
| B.5 y B.6 (`r10a_b56_frontera.py`, ~45 min) y B.3/B.4 (microbanco en C) | **No re-ejecutados** por mí; B.5 usa `verif_frontera_vs_F.py` como control y reproduce 46,8784 / 36,5432 %; el microbanco se midió con otros dos agentes en la máquina (contaminación declarada por el agente, con control de 1 hilo contra Criterion, razón 0,950) |

---

## 1 · La regla, escrita entera (A) — PLAUSIBLE, y con dos correcciones al primer intento

Seis piezas, texto íntegro en `d8-ronda10a/informe.md` §A.6:

- **(h.1)** `entropía_j = blake3(AES128_chain^{Lrev·N(slot(I_j))}(blake3(chunk(I_j) ‖ salida(f, slot(I_j)))))` con
  **`Lrev = L − S_max`**, aplicada en `t_j = slot(I_j) + L`. Es **función de `past(B)`**: no se publica, se calcula.
- **(h.2)** Los `PotCheckpoints` de esa cadena viajan por gossip bajo tema propio, **nunca en bloque** (900 kB por época
  añadirían un 18,4 % a `Δ = 4 s`). Se verifica **una** revelación por época, la del ancla de la cadena propia, **en orden
  de slot aleatorio**; ante más revelaciones de las que compensa verificar, se recalcula (Autonomys, `gossip.rs:438-441`).
- **(h.3′)** Validez incondicional: la validez de un bloque con `slot(B) ≥ t_j` no depende de que los checkpoints estén
  publicados. **DEMOSTRADO** que elimina la rama que rompía R-FIN-5.
- **(h.4)** Por flujo: dos flujos dan revelaciones distintas del mismo `X`; R-FIN-5 sigue siendo estructural.
- **(h.5)** Iteraciones congeladas en el `N` vigente en `slot(I_j)`, no en `t_j`. DEMOSTRADO por construcción.
- **(h.6)** Calibración: `I ≤ (L − ρ_max·W_dec)/(ρ_max − 1)`. Pagar más `L/I` que `ρ_max` es tirar CPU.

**Por qué `Lrev = L − S_max`:** con `Lrev = L` la disciplina «esperar al ancla» no llega a tiempo por `W_dec/L = 0,62 %`, y
no se compra con hardware porque la carrera es contra la propia cadena principal en el mismo silicio. Cuesta 1,8 % de `ρ*`.

## 2 · Los ataques (B), con número

| Ataque | Resultado | Etiqueta | Número |
|---|---|---|---|
| **B.1 reloj rápido** | La cota `ρ ≥ L/W_dec` (160) es correcta para elegir entre candidatos **ajenos** y ciega para el **propio**: publicar o retener su propio candidato exige solo `ρ* = (L + I)/(I + W_dec)` | VERIFICADO + DEMOSTRADO | 160 → **8,99** (17,8×); residuo por rachas de anclas propias a tasa `α^(n*−1)`, razón sim/cerrado 0,93-1,01; a `ρ = 1,5`, `α = 0,40`: 1,6·10⁻² épocas/año |
| **B.2 DoS de verificación** | No existe como ataque; el coste que queda es el honesto | REFUTADO / VERIFICADO | asimetría 16,24×; 32,4× en orden aleatorio; coste honesto 0,813 núcleos a `I = 851 s`, `L = 2 h` |
| **B.3 vivacidad del timekeeper** | La CPU no es el problema (25 líneas AES simultáneas: 1,7 % de degradación); la barrera de entrada sí: ×`(q+1)` | VERIFICADO (microbanco, contaminado y controlado) | `q + 1 = 10` a la calibración vigente |
| **B.4 partición** | **Vector nuevo de hardware**: un lado sin `q+1` líneas muere con todo su espacio; contradice la letra de R-FIN-7 y no se compensa con espacio | VERIFICADO (aritmética sobre B.3) | 4 núcleos, `q+1 = 10`: revelación 3 h tarde con `F = 2 h`; a `ρ_max = 2,5`, `q+1 = 3` |
| **B.5 carrera** | (h) no toca la frontera | DEMOSTRADO | 46,8784 / 36,5432 % idénticos |
| **B.6 adelanto `(L+I)(1−1/ρ) − W_dec`** | Ráfagas planificadas: la cota de la unión ya se lo regaló | REFUTADO como daño; LAGUNA «retención selectiva con oráculo propio» acotada | −0,46 puntos en el peor caso teórico; < 0,08 real |

## 3 · El coste (C) y la identidad que decide

`ρ* = (1 + L/I) · I/(I + W_dec)`; coste de verificación por nodo `= (1 + L/I)` × 0,096 núcleos. Razón 0,977 en las seis
filas. **Cada punto de tolerancia al reloj cuesta un punto de CPU en cada nodo.** Tabla de calibración:

| `ρ_max` | `L` | `I*` | líneas `q + 1` | núcleos/nodo | `I + F` |
|---:|---:|---:|---:|---:|---:|
| 1,5 | 2 h | 14 265 s | 2 | 0,049 | 5,96 h |
| 2,0 | 2 h | 7 110 s | 3 | 0,097 | 3,98 h |
| **2,5** | **2 h** | **4 725 s** | **3** | **0,147** | **3,31 h** |
| 3,0 | 2 h | 3 532 s | 4 | 0,196 | 2,98 h |
| vigente | 2 h | 851 s | 10 | 0,813 | 0,93 h |

Latencia añadida: cero si la revelación va por gossip; 18,4 % de `Δ` si fuera en bloque.

## 4 · Lo que cambia en la propuesta (pendiente de decisión de Katana)

1. **R-FIN-14 (h):** sustituir las dos líneas actuales por las seis piezas (h.1)-(h.6) si se adopta, y en cualquier caso
   **corregir el «lo que compra»**: no es «0 para cualquier `ρ`», es «÷279 hasta `ρ* ≈ 1 + L/I`».
2. **`I` y `L` con (h)** se calibran por (h.6), no por el steering sin (h): es la bifurcación F2 del catálogo.
3. **R-FIN-7:** si se adopta (h), escribir el modo de fallo de partición por hardware (`q + 1` líneas por lado).
4. **`C-NET-03/04`:** el coste de PoT es por slot, y con (h) `1 + L/I` veces.

## 5 · Errores declarados por el agente (11) y lo que cambiaron

Del primer intento: titular sobreafirmado («la cota es FALSA»); A.1 mal leída (el 0,63 % no se compra con CPU, la palanca
es `Lrev < L`); **(h.3) rota y retirada**; expresión muerta en un script; recorte no declarado (400 épocas → 4 000). De este
intento: bug en el simulador cazado por un control que dio `nan` (el atacante esperaba a la red: adversario más débil que el
del paper; corregido, y la cota sin (h) pasó a ser exactamente la de la ronda 7); ±1 en la forma cerrada de las rachas;
origen desplazado en `boot90` (8,0 h → 2,7 h); modelo de B.2.b incompleto; etiqueta de columna; memoización. Contaminación
del microbanco declarada.

## 6 · Lagunas que deja

`ρ_max` real (estudio de Supranational no localizado; 1,5-2,5× es estimación del principal); retención selectiva con oráculo
de victorias propias; efecto de la barrera ×`(q+1)` sobre el número real de timekeepers; `Δ`; `m` con retención inflada
(hereda el aviso de 9c).

## 7 · Efecto sobre las decisiones

- **F2 (`ρ_max` y (h))**: (h) es adoptable con las seis piezas; su calibración es una elección entre CPU en todos los nodos y
  lookahead frente al sembrador. Con 10c (F1, `L` desatada de `F`) la alternativa sin (h) tiene margen 3,6× y `W/κ` dentro
  de BDK; **las dos vías están cuantificadas y la elección es de Katana.**
- Lo que ninguna vía arregla: `ρ_max` es estimación y `Δ` no está medido.
