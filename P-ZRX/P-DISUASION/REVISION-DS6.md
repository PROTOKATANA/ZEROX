# REVISIÓN DS-6 (+ Corrección A) — reparto del espacio entre claves en una red real

**Revisor:** Claude (director). **Fecha:** 2026-09-26. **Ejecutor:** subagente Sonnet. Evidencia:
`resultados-DS6/` (informe con la sección «Corrección A», código, resultados, CSV crudo de 2 470 granjeros
de SpaceFarmers.io con huellas). **Veredicto: ACEPTADA tras la Corrección A.**

## Comprobado por el director

- Datos: 247 páginas de `/farmers` de un pool público de Chia descargadas por el ejecutor, con `sha256`
  (la única «discrepancia» del `sha256sum -c` es la del propio fichero de sumas, que se lista a sí mismo).
- **Error de la primera entrega, detectado por el director:** el ajuste da el exponente de la **cola**
  (`n / Σ ln(x/xmin)`), y la fórmula de DS-3 (`masa_prob`, media finita solo si `α > 2`) espera el de la
  **densidad** (= cola + 1). Sin corregir, `B(ε)` salía 4,4·10⁻⁷; corregido, **0,0947 [0,059; 0,151]**. El
  ejecutor lo rederivó y lo confirmó.
- **Cálculo empírico directo** (sin ajustar ninguna ley): fracción del espacio en granjeros con
  `f < ε/(λ·T_v)`. Con `ε = 0,01`, `T_v = 3.600`: **1,78·10⁻⁴ [1,49·10⁻⁴; 2,08·10⁻⁴]** con el pool como
  denominador; entre 3,95·10⁻⁴ y 1,42·10⁻³ con el espacio de la red; máximo de toda la rejilla, 0,0144.

## Lo que concluye

Frente al umbral de DS-3 (`B(ε) > 1 − 2·α_atacante`), la grieta **se cierra** para `α_atacante` =
0,20 / 0,25 / 0,33 / 0,40, con el ajuste corregido (margen mínimo −0,105) y con el cálculo empírico
(margen ≥ −0,186 en toda la rejilla). **Si el espacio de ZEROX se reparte como en este pool, un atacante
con el 20–40 % del espacio no puede reclutar gratis, en claves sin saldo, el espacio que le falta para
ganar la rama privada: tendría que sobornar claves con saldo, y el castigo con evidencia más retención
(M3 + M5) le cobra.**

## Alcance exacto (lo que no cambia)

- Solo afecta al atacante que **necesita reclutar** espacio ajeno. El atacante con espacio propio
  suficiente no recluta, y con muchas soluciones por slot no deja evidencia (`κ → 0`, P-EQUIVOCACION):
  para él el castigo sigue sin morder.
- Sigue condicionado a que los reclutados dejen evidencia que llegue a la cadena (`κ > 0`, RFT-01).
- Es **una** red y **un** pool (576 PiB, frente a 3–4 EiB de Chia), por analogía estructural: ZEROX no
  existe todavía como red y su reparto real será otro. Los granjeros en solitario, en general grandes, no
  aparecen: el sesgo va hacia más concentración, es decir, a favor de la conclusión.
- La hipótesis H3 de DS-3 (`α_dens ∈ [2,05; 3,0]`) queda **sin respaldo**: con estos datos es la que tendría
  que justificarse.
