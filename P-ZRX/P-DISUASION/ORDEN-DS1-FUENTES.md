# ORDEN-DS1 — Fuentes primarias: mecanismos de disuasión en sistemas de espacio y de stake

## 1. Identidad y contexto

- **ID:** DS-1. **Fecha:** 2026-09-26. **Director:** Claude. **Ejecutor:** subagente Sonnet
  (investigación con web; sin código). **Marco obligatorio:** `P-ZRX/P-DISUASION/MARCO.md`.
- **Zona (única escribible):** `/home/katana/zeo/ZEROX/deepseek/DS1/`.
- **Objetivo único:** reunir, con fuente primaria y fecha, **qué conducta castiga o encarece** cada
  mecanismo de disuasión en los sistemas de referencia, **bajo qué condición se aplica** (qué
  evidencia, quién la aporta, cuándo se incluye) y **con qué magnitudes**, para que DS-2 lo traslade a
  ZEROX sin importar cifras por analogía.
- **Pregunta falsable:** «Existe al menos un mecanismo documentado en un sistema de prueba de espacio
  que encarezca el doble farmeo o la producción en ramas privadas de forma **exigible** (sin depender
  de que el atacante publique evidencia).» Se confirma con la fuente o se refuta con la búsqueda
  documentada.

## 2. Qué investigar (cada punto con URL, fecha de consulta y cita literal de lo esencial)

1. **Filecoin:** depósito de precompromiso, *initial pledge*, tasas de fallo y de terminación,
   *consensus faults* (qué conductas, qué evidencia, qué castigo), plazos de WindowPoSt, coste del
   sellado (tiempo, hardware y energía de un sector de 32 GiB y 64 GiB, con fuente), magnitudes
   históricas del colateral por TiB con fecha, y ataques que la propia especificación declara **no**
   cubiertos (generación, externalización, Sybil).
2. **Chia:** ausencia de stake; cómo trata el farmeo en varias ramas y por qué lo considera
   aceptable o no; filtro de parcelas; parcelas comprimidas y coste de **regenerar o descomprimir**
   en GPU (Bladebit, Gigahorse u otros) con cifras y fecha; *time lords*.
3. **Spacemint** (Park et al.): transacciones de castigo por doble farmeo, supuestos que exige.
4. **Autonomys / Subspace:** qué stake existe (operadores de dominios) y qué **no** tiene el farmer;
   coste documentado del ploteo en CPU y GPU.
5. **Ethereum PoS:** conductas castigadas, evidencia y denunciante, castigo correlacionado, fuga por
   inactividad, casos reales (número de castigos, el mayor evento correlacionado) y cómo se cuantifica
   el coste de un ataque.
6. **Literatura:** análisis de *nothing-at-stake* y de «simulación sin coste» en PoSpace/PoST, ataques
   de largo alcance y sus defensas, metodologías de «coste de un ataque del 51 %» (p. ej. alquiler de
   hash) y cualquier propuesta de disuasión **por coste** que no dependa de detectar (inmovilización,
   sellado lento, VDF, *time-lock*).

## 3. Entregable

`deepseek/DS1/INFORME.md` en español: (a) tabla por sistema y mecanismo: **conducta objetivo →
condición de aplicación (exigible o condicionada) → magnitud con fecha → fallos o incidentes
documentados**; (b) respuesta a la pregunta falsable; (c) «lo que busqué y no encontré», con las
búsquedas hechas; (d) lista de fuentes. Etiqueta cada afirmación: **fuente primaria comprobada**
(leíste la página), **fuente secundaria**, **derivación** o **hipótesis**. Ninguna cifra sin fuente.

## 4. Límites

Solo lectura fuera de tu zona (el repositorio y `.trash/zerox` se pueden leer). **No lances
subagentes ni forks.** Sin git; sin Python; sin credenciales. Presupuesto: 2 h.
