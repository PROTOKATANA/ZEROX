# REVISIÓN DS-2 — matriz ataque × mecanismo para ZEROX

**Revisor:** Claude (director). **Fecha:** 2026-09-26. **Ejecutor:** subagente Sonnet (≈ 12 min,
46 llamadas, sin código). Evidencia: `resultados-DS2/` (`INFORME.md`, `MODELO.md`, huellas de los tres
PDF descargados). **Veredicto: ACEPTADA.** `MODELO.md` queda ratificado como especificación de DS-3.

## Comprobado por el director

- **Citas de Baig y Pietrzak**, verificadas literalmente en `arxiv.org/html/2505.14891`: «Chia prevents
  bootstrapping by additionally using proofs of time, while Filecoin avoids replotting by using a BFT
  (rather than longest-chain) type protocol»; «while there's no simple way to prevent replotting, and to
  prevent bootstrapping we need additional primitives like VDFs»; «augmented with checkpointing or
  finality gadgets…»; «an adversary can simply plot and commit to many different proofs of space in the
  honest chain and then later replot them».
- **Cifras del sembrador** contra `.trash/zerox/P-ZRX/P-COBERTURA/investigacion/INFORME.md` (líneas 73,
  437–489): `B = 181.092` aperturas por TiB, 117,238 núcleos/TiB, 5,790 máquinas/TiB, ≈ 1.524× la
  energía de almacenar. Coinciden.
- El informe responde por escrito, antes de la matriz, si cada mecanismo elimina la premisa de cada
  refutación previa (§0), como exige el mandato.

## Lo que concluye (para Katana)

1. **Doble farmeo (A1):** la garantía sin castigo (M1, M2) **no disuade**: con el mismo colateral se
   produce en todas las ramas (P-PRESTAMO F3: «sin castigo, farmear doble es dominante y gratis»). Con
   castigo por evidencia más retención (M3 + M5) disuade **solo al atacante pequeño** (`m ≤ 0,05`
   soluciones por slot: `κ = 1`); frente al grande (`m ≥ 4`) la probabilidad de dejar evidencia cae a
   ~0 y además rota claves nuevas (P-CLAVE). **Condicionado, no exigible.** El castigo correlacionado
   (M4) **nunca se ha evaluado**: es la única vía de PoStake contra A1 que queda abierta.
2. **Mejoras reales exigibles** (con el criterio de Katana):
   - **O4**, atar la coinbase a la clave de la solución: quita el premio al pool que firma a ciegas (A5),
     sin depender de detección. Es la celda más limpia.
   - **M1**, la garantía mínima: barrera de entrada por identidad contra Sybil (A4), pero **regresiva**
     (P-TASA F4) y excluye a quien aporta espacio sin tokens (C-07).
   - **F1 + F2 + F4**, registro, auditoría y colateral de sectores: encarecen el sembrador (A3) a
     117 núcleos/TiB continuos, **pero solo detectan si la auditoría abre más de 181.092 posiciones por
     TiB** (≈ 3.000 lecturas/s por TiB: un SSD sí, un disco duro doméstico no).
   - **F3**, el sellado lento: encarece reescribir la historia (A7), no el doble farmeo; exige cambiar el
     objeto ploteado.
3. **Baig y Pietrzak:** el PoT de un solo flujo de ZEROX es el mismo tipo de «supuesto adicional» con el
   que Chia escapa a la parte de *bootstrapping* de la imposibilidad; **no** escapa al *replotting* ni a
   la carrera de rama privada en tiempo real (RFT-01, RFT-09). `C-FIN-01` acota el daño, no el umbral.
4. **Transición (A8):** ningún mecanismo de PoStake o Filecoin la modula; quien mina el prefijo obtiene
   a la vez los tokens de la garantía (misma pata de recursos).

## Reservas

- Celdas declaradas «no evaluado»: M4 en todas sus filas, M3 contra claves retiradas (A7), la censura
  como evidencia (A9). Son candidatas a encargos propios.
- `MODELO.md` §3 fija escenarios **hipotéticos** (precios, `q`, interés): las salidas de DS-3 serán
  sensibilidades, no predicciones.
