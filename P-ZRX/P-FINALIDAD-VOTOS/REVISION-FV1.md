# REVISIÓN FV-1 (segunda ejecución) — capa de finalidad por votos con la decisión de Katana

**Revisor:** Claude (director). **Fecha:** 2026-09-26. **Ejecutor:** subagente Sonnet (≈ 29 min).
Evidencia: `resultados-FV1/` (contrato FV-01…FV-24 y FV-EVP-01…06, informe, `calc/` en Julia).
**Veredicto: ACEPTADA.** La pregunta falsable queda **refutada en (a)** y **parcialmente en (c)**; (e) es un
trilema, no una elección sin coste.

## Comprobado por el director

- Huellas de la zona y `ENTRADA-FV1.sha256` en verde.
- **Aritmética rehecha por el director** (con el atacante siempre encendido, y por tanto siempre con prima):
  si censura todas las pruebas de disponibilidad de los honestos, su fracción de plazas es `a·b/(a·b+1−a)`.
  Pausa (≥ 1/3 de plazas) con `a ≥ 1/(2b+1)`; sella él solo (≥ 2/3) con `a ≥ 2/(b+2)`. Participación honesta
  mínima para sellar sin atacante: 66,7 % / 50 % / 33,3 % para `b` = 1 / 2 / 4; con un atacante del 25 % que
  se abstiene: 88,9 % / 83,3 % / 77,8 %. Coinciden con el informe.

## Lo que concluye

1. **(a) refutada:** con prima `b > 1` y control de red suficiente para censurar las pruebas de
   disponibilidad, el umbral de pausa cae por debajo de 1/3 (11,1 % con `b = 4`). No es varianza del
   sorteo: es la esperanza. Pausar sigue sin castigo y devuelve a la situación de hoy.
2. **(c) parcial:** con la capa pausada o sin activar, ningún nodo queda peor que con `C-FIN-01`; pero un
   certificado falso **ya adoptado** no se revierte con más trabajo honesto («mentira permanente»):
   ahí sí se queda peor.
3. **(e) trilema:** `b` mueve a la vez viveza (menos participación necesaria), seguridad de pausa y
   seguridad de sellar a solas; ningún `b` gana en las tres.
4. Hallazgos nuevos: el firmante seguro debe extenderse al voto (se vota mucho más que se produce); el
   cliente ligero reabre el largo alcance de PoS y choca con «sin ancla externa» (fuera de alcance).

## Decisiones para Katana

D1 valor de `b` (el ejecutor recomienda 4); D2 suelo `E` (mejora la ruptura, no la pausa); D3 firmas BLS
agregadas o Ed25519; D4 firmante seguro para el voto (el director lo adopta: sí); D5 subclave de voto
(línea futura); D6 cliente ligero (el director lo adopta: fuera de alcance).
