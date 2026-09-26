# REVISIÓN DS-1 — fuentes primarias de mecanismos de disuasión

**Revisor:** Claude (director). **Fecha:** 2026-09-26. **Ejecutor:** subagente Sonnet (≈ 9 min, 58
llamadas). Evidencia: `resultados-DS1/INFORME.md`. **Veredicto: ACEPTADA con huecos declarados.**

## Comprobado por el director

- **Baig y Pietrzak**, «On the (in)security of Proofs-of-Space based Longest-Chain Blockchains», FC 2025,
  arXiv:2505.14891: el resumen dice literalmente «we prove that without additional assumptions no such
  protocol exists» (cadena más larga basada en PoSpace, segura bajo disponibilidad dinámica), con una
  cota de la longitud del fork para el doble gasto válida **para cualquier regla de selección**.
  Leído por el director en arxiv.org el 2026-09-26.
- El informe etiqueta cada afirmación ([P]/[S]/[D]/[H]) y declara como secundario todo lo que no pudo
  leer (SpaceMint, varios PDF). No hay cifras sin fuente.

## Lo que aporta

1. **Pregunta falsable refutada:** ningún sistema de espacio puro revisado (Chia, SpaceMint, Autonomys)
   encarece el doble farmeo en ramas privadas de forma **exigible**; el castigo de SpaceMint es
   **condicionado** (exige que se publiquen los dos bloques). Coincide con RFT-01 y con el cierre de las
   ocho vías de `ESTADO-DOBLE-FARMEO`.
2. **Mecanismos exigibles encontrados:** el *consensus pledge* de Filecoin (capital inmovilizado para
   tener poder, M1), la tasa de terminación, el sellado lento ligado a aleatoriedad de la cadena
   (encarece **reescribir la historia**, A7, no el doble farmeo simultáneo, A1) y la fuga por
   inactividad de Ethereum.
3. Metodología de coste de ataque (crypto51: alquiler de hash por hora, con sus sesgos declarados).

## Huecos y cómo los cubre DS-2

- **Matiz decisivo para ZEROX:** el resultado de Baig y Pietrzak es para PoSpace **sin supuestos
  adicionales**. ZEROX añade PoT (VDF de un solo flujo) y finalidad `C-FIN-01`. DS-2 debe leer el
  artículo **completo** y decir qué supuestos adicionales escapan a la cota y si PoT o la finalidad de
  ZEROX son de esa clase.
- PDF ilegibles para la herramienta web (SpaceMint, el artículo completo de Baig y Pietrzak, el de
  electricidad de Filecoin): **se pueden descargar con `curl` a la zona y leer con el lector de PDF
  local**. DS-2 lo hará para los tres.
- Sin cifras de energía o tiempo de sellado Filecoin por sector, ni de descompresión GPU en Chia, ni de
  ploteo en Autonomys: DS-4 mide lo propio (regeneración PoAS en GPU).
