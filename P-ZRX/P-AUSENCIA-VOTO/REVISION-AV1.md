# REVISIÓN AV-1 — la falta «elegido sin voto»

**Revisor:** Claude (director). **Fecha:** 2026-09-26. **Ejecutor:** subagente Sonnet (≈ 35 min).
Evidencia: `resultados-AV1/` (contrato AV-01…AV-22, informe, `calc/` en Julia). **Veredicto: ACEPTADA.**
Pregunta falsable: se sostiene en (a), (c) y (d); en (b) solo con una regla económica; **se refuta en (e)
con `m_aus` fijo**.

## Comprobado por el director

- Huellas de la zona y `ENTRADA-AV1.sha256` (18/18) en verde.
- `calc/resultados/C2-costo-pausa-hora.csv`: con `m_aus` **fijo** y el peso en una sola clave, el coste por
  hora de pausa es **36 000 u.e./h para cualquier `a`** entre 0,10 y 0,40 (la falta es por clave e instancia:
  una clave grande paga una vez por instancia, gane las plazas que gane); con `m_aus` **proporcional a la
  garantía**, crece en línea con `a` (1,8·10⁷ → 7,2·10⁷ u.e./h). `C6-concentracion-vs-fragmentacion.csv`: con
  `m_aus` fijo, repartir el peso en más claves **multiplica** los incidentes (1 → 95 por instancia de 1 a
  1 000 claves con `a = 0,1`).

## Lo que aporta

1. **Sorteo secreto durante la ronda y verificable después:** compromiso Merkle por ventana con una VRF
   **independiente por instancia** (una sola VRF por ventana revelaría todo el calendario en cuanto se vota
   una vez) y **revelación obligatoria** al cierre, con **suspensión** (no confiscación) de quien no revela:
   callarse nunca sale mejor que revelar. SSLE se descarta (resuelve el problema contrario: solo el elegido
   puede probarlo).
2. **La falta** (`AV-12`): clave elegida en la instancia `n` según su revelación, sin voto admitido ni en el
   plazo ordinario ni en el de gracia. **Defensa ante censura:** plazo de gracia `G_slots ≈ F_slots` para
   incluir el propio voto; la censura total durante toda la ventana exige controlar la red entera.
3. **Falsos positivos por causa:** fallo propio (lo paga el honesto, por decisión de Katana, con pérdida por
   perfil calculada); censura del atacante (neutralizada por el plazo de gracia salvo control total);
   fallo correlacionado (sin castigo correlacionado: cada clave paga lo suyo).
4. **Resultado central:** para que pausar le cueste más al atacante más grande, `m_aus` tiene que ser
   **proporcional a la garantía** (con un mínimo).

## No medido

`T_instancia` real (IPA B-05); el valor económico de producir y votar; PDF completos de Algorand y SSLE
(solo resúmenes).
