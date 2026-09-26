# REVISIÓN DS-5 — castigo correlacionado (M4)

**Revisor:** Claude (director). **Fecha:** 2026-09-26. **Ejecutor:** subagente Sonnet (≈ 10 min).
Evidencia: `resultados-DS5/`. **Veredicto: ACEPTADA.** Pregunta falsable **refutada**.

## Comprobado por el director

- M4 ya está especificado en `D-ZRX/SPEC.md` §5 (`C-SLA-01`…`C-SLA-04`; `perdida(P,e) = min(V(P,e),
  techo_exacto(f_e × V(P,e)))`, línea 259), con `b`, `c` pendientes; IPA C-05 lo declara no implementable.
- La cota central es algebraica: ninguna forma de M4 confisca más que el saldo `V`. Con la grieta de DS-3
  (279 claves reclutadas con saldo ≤ 0,01), el máximo confiscable es 2,79 u.e. frente a 510 570 u.e. de
  soborno evitado (`resultados-comprobacion.txt`).
- Cita de Ethereum verificada en el HTML descargado (`sha256 901ab55a…`): «As it happened, no correlated
  slashings occurred that incurred a penalty greater than zero under this mechanism». **Matiz:** la frase
  está en el párrafo sobre la subida gradual del multiplicador en el despliegue inicial; extenderla al
  incidente de 2025 es **derivación** de DS-5, no afirmación de la fuente. La fuente sí dice que, por el
  redondeo entero, «when there are few slashings there is no extra correlated slashing penalty at all».

## Lo que concluye

- **M4 no encarece el doble farmeo ni la equivocación del atacante grande** (N en A1 y A2): no elimina la
  premisa de RFT-01 (sigue necesitando evidencia publicada) ni la grieta de DS-3 (no puede quitar saldo que
  no existe). Solo alcanza a quien deja evidencia y tiene saldo: un subconjunto de lo que M3 ya cubría.
- **Aporta celdas W** (empeora): castigo a honestos con un fallo común (con la forma de SPEC y `b = 0,1`, un
  fallo compartido del 5 % de 10 000 claves satura el castigo salvo `c < 0,0018`); un vector nuevo de
  *griefing*; y, en la forma de SPEC (que escala con el número de claves), incentivo a concentrar
  identidades, en contra de M1 y de C-07. La forma tipo Ethereum (por fracción de saldo) es menos mala en
  esas celdas, pero tampoco cierra A1 ni A2.
