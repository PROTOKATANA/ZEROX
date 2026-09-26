# REVISIÓN DS-4 — coste medido de regenerar parcelas en GPU (sembrador, A3)

**Revisor:** Claude (director). **Fecha:** 2026-09-26. **Ejecutor:** subagente Sonnet (≈ 47 min de
trabajo efectivo). Evidencia: `resultados-DS4/` (informe, resultados, registros, fuentes del banco).
**Veredicto: ACEPTADA, con una reserva de alcance.** Pregunta falsable **confirmada**: en GPU, regenerar
un registro cuesta el 6,0 % del tiempo por núcleo de CPU.

## Comprobado por el director

- Validación: 1 000 registros, `SHA256_CPU = SHA256_GPU = d9be7a16…2927`, 0 discrepancias de bytes y de
  mapa de chunks (`INFORME.md` líneas 75–78). Sin procesos vivos al terminar; GPU en reposo (0 %, 6,9 W).
- Medidas (mediana de 5 repeticiones ≥ 30 s): CPU 1 hilo 1,085 registros/s (0,921 s/registro, coherente
  con los 0,9006 s de S02a); CPU 8 hilos 3,964/s; **GTX 1070 18,37 registros/s (0,0545 s)**, 95,5 W
  activos ⇒ **5,24 J/registro**; 1 TiB (2²⁰ registros) ≈ **16,0 h y 1,52 kWh** en GPU (derivación de
  ráfagas de 150 s, no una corrida de 16 h). Energía de CPU **no medida** (sin acceso a RAPL ni MSR).

## Reserva de alcance (hallazgo del ejecutor, verificado por el director)

ZEROX planta y verifica con `subspace_proof_of_space::chia::ChiaTable` (v1: `crates/zx-poas/src/verificador.rs:68`,
`crates/zx-farmer/src/productor_poas.rs:55`), y S02a midió esa tabla. El *shader* del clon implementa
`chia_v2::ChiaV2Table` (`ab_proof_of_space::chiapos`); con v1 la comparación CPU↔GPU daba 1 000/1 000
discrepancias. **La cifra GPU es de v2**: un indicador de la misma familia con coste CPU casi idéntico
(0,921 frente a 0,9006 s/registro), **no** la medida del objeto que ZEROX regenera. Si ZEROX adoptara v2
(la tabla actual de Autonomys), la medida aplicaría directamente; queda anotado para IPA D-04.

## Derivación del director para la disuasión (etiquetada)

P-COBERTURA (`.trash/zerox/P-ZRX/P-COBERTURA/investigacion/INFORME.md` §5.4) fija que farmear regenerando
exige 117,238 núcleos por TiB en continuo y **supuso** «GPU/TiB (17×) = 6,896, hipótesis, NO medida». Con
DS-4: 117,238 / 0,9006 ≈ **130 registros/s por TiB** ⇒ 130,2 / 18,37 ≈ **7,1 GTX 1070 por TiB**, ≈ **677 W por
TiB en continuo** (≈ 16 kWh por TiB y día), frente a ≈ 5 W por TiB de almacenar (hipótesis de P-COBERTURA):
**≈ 135× la potencia de almacenar**, más 7 GPU de inversión por TiB. La hipótesis de 17× queda **medida**
(16,9×) con la reserva v1/v2. Una GPU actual abarata esa cifra en un factor sin medir. El tramposo que
**solo responde auditorías** (sin farmear) sigue pagando mucho menos (P-COBERTURA E2: 809 s·núcleo por
auditoría ⇒ ≈ 49 s de GTX 1070 por auditoría, derivación): las auditorías disuaden al que farmea
regenerando, no al que solo finge el almacenamiento en la auditoría.
