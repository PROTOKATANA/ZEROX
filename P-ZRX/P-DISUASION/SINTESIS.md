# P-DISUASION — Síntesis: qué resuelven y cuánto encarecen PoStake y Filecoin en ZEROX

**Fecha:** 2026-09-26. **Firma:** Claude (director). **Para:** Katana. **Base:** DS-1 (fuentes), DS-2
(matriz), DS-3 (modelo cuantitativo), DS-4 (medida GPU), con sus revisiones en esta carpeta. **Criterio
aplicado (Katana):** un mecanismo que no cierra un hueco pero encarece el ataque de forma **exigible**
—el atacante lo paga haga lo que haga— es una mejora real frente al protocolo antiguo sin stake.

## 1. Respuesta corta

| Mecanismo | Qué problema encarece | Cuánto (absoluto) | ¿Exigible? | ¿Mejora real? |
|---|---|---|---|---|
| **Coinbase atada a la clave de la solución** (O4, tipo Chia) | Producir con espacio ajeno (pools que firman a ciegas) | Quita todo el premio del robo; coste de implantación bajo | **Sí**, sin depender de detección | **Sí** — la más limpia |
| **Registro + auditorías + colateral de sectores** (Filecoin F1 + F2 + F4) | Sembrador: regenerar en vez de almacenar | 117 núcleos o **≈ 7 GPU GTX 1070 por TiB en continuo, ≈ 677 W por TiB** frente a ≈ 5 W de almacenar (≈ 135×) | **Sí** el coste; la **detección** solo si la auditoría abre > 181 092 posiciones por TiB (un SSD lo sirve, un disco duro doméstico no) | **Sí**, con esa condición de diseño |
| **Garantía mínima por identidad** (M1) | Sybil: partir el espacio en muchas claves | `q` por identidad: capital inmovilizado y adquirido | **Sí** | **Sí, acotada**: regresiva (pesa más a la granja pequeña) y excluye a quien aporta espacio sin tokens |
| **Sellado lento** (Filecoin F3, PoRep) | Reescribir la historia (largo alcance) | Horas por sector (Filecoin); obliga a resellar todo el periodo | **Sí**, si se adopta (cambia el objeto ploteado) | **Sí** contra largo alcance; **no** contra el doble farmeo |
| **PoT de un solo flujo** (ya en ZEROX) | Fabricar historia falsa de golpe (*bootstrapping* de Baig-Pietrzak) | Obliga a recorrer el tiempo real | **Sí** | **Sí**: saca a ZEROX de la mitad de la imposibilidad de Baig-Pietrzak |
| **Finalidad `C-FIN-01`** (ya en ZEROX) | Reorganizaciones profundas | Acota la profundidad, no el umbral | **Sí**, estructural | **Sí**, acota daño |
| **Castigo por evidencia + retención** (M3 + M5) | Doble farmeo y equivocación | Con el reparto supuesto por DS-3, **Δ = 0** (el atacante recluta gratis en claves sin saldo). **Con el reparto real de un pool de Chia (DS-6), esa grieta se cierra**: el atacante del 20–40 % que necesita espacio ajeno tiene que sobornar claves con saldo, y el castigo le cobra | **Condicionado**: a que los reclutados dejen evidencia; no alcanza al atacante con espacio propio suficiente | **Sí, contra el atacante que recluta**, si el espacio está concentrado; **no** contra el grande autosuficiente |
| **Garantía sin castigo** (M1, M2 contra el doble farmeo) | — | El mismo colateral vale en todas las ramas | — | **No** contra el doble farmeo |
| **Castigo correlacionado** (M4, ya en `SPEC.md` C-SLA) | Doble farmeo y equivocación | **Nulo** frente al atacante grande: no puede confiscar más saldo del que hay (máximo 2,79 u.e. frente a 510 570 de soborno evitado, DS-5) | No | **No**; además **empeora**: castiga a honestos con fallos comunes y abre *griefing* |

## 2. Lo que queda firme

1. **El doble farmeo no lo encarece ningún mecanismo de PoStake ni de Filecoin de forma exigible**
   frente a un atacante grande con espacio propio suficiente: lo confirman las fuentes (DS-1), la matriz
   (DS-2), el modelo (DS-3) y el castigo correlacionado (DS-5). **Pero el castigo con evidencia sí encarece
   al atacante que necesita reclutar espacio ajeno** si el espacio está concentrado, como en un pool real
   de Chia (DS-6: la fracción de espacio en claves sin saldo es ≈ 2·10⁻⁴, muy por debajo del umbral 0,2–0,6
   que haría gratis el reclutamiento). Es una barrera condicionada (exige evidencia), no un cierre.
2. **Sí hay mejoras reales y exigibles** en otros frentes: espacio ajeno (O4), sembrador (sectores y
   auditorías), Sybil (garantía) y largo alcance (sellado lento, PoT, finalidad).
3. **Baig y Pietrzak (FC 2025, comprobado):** un PoSpace de cadena más larga no puede ser seguro sin
   supuestos adicionales. ZEROX tiene uno de los dos que el artículo reconoce (el VDF/PoT, como Chia),
   que cierra el *bootstrapping*; no tiene el otro (registro + BFT, como Filecoin), que cerraría el
   *replotting*.

## 3. Errores y reservas

- **Error del director:** ratifiqué DS-2 sin rehacer una cuenta; la región de retención es
  `ρ_ret·T_v > 370`, no «≳ 4.000» (la incoherencia venía ya de P-PRESTAMO y la detectó DS-3).
- La medida GPU es de la tabla **v2** de Autonomys; ZEROX usa la **v1**. En CPU cuestan casi lo mismo
  (0,92 frente a 0,90 s por registro), pero no es la medida exacta del objeto de ZEROX.
- Todas las cifras en tokens son **escenarios hipotéticos** (no hay precios ni parámetros de producción), y el modelo de DS-2 mezclaba saldo por clave y pérdida por reclutado (SL-2, F5): las cifras absolutas en u.e. son de escala dudosa; las conclusiones no cambian.
- Una GTX 1070 es **cota inferior** de una GPU actual: el sembrador con hardware actual es más barato en
  un factor no medido.

## 4. Siguiente

- **DS-5 (hecho):** el castigo correlacionado tampoco encarece el doble farmeo y empeora el riesgo para
  honestos (`REVISION-DS5.md`). Con esto, ningún mecanismo de PoStake examinado lo encarece de forma exigible.
- **DS-6 (hecho, con corrección del director):** en un pool real de Chia el espacio está muy concentrado;
  la grieta del reclutamiento gratuito se cierra (`REVISION-DS6.md`). Autonomys no publica datos por clave.
- Decisiones de diseño que salen de aquí, para Katana: adoptar O4 como regla candidata; si se activan
  auditorías, diseñarlas para `k > B` con el presupuesto de E/S doméstico; valorar la tabla v2.
