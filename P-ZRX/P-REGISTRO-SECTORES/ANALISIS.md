# Registro de sectores para ZEROX — análisis de decisión

**Estado:** investigación; no es especificación ni autorización de activación.
**Fecha:** 2026-09-25.

## 1. Qué aporta el precedente de Filecoin

Filecoin no concede poder de almacenamiento por publicar un identificador. Su
secuencia documentada es precomprometer un `SealedCID` y depósito, aportar más
tarde una PoRep ligada a aleatoriedad posterior dentro de una ventana y, tras
el alta, responder a retos recurrentes de WindowPoSt. El sector que deja de
probarse pierde poder y puede afectar al colateral. Son mecanismos y supuestos
distintos de los de ZEROX; no se copian sus plazos ni su prueba criptográfica.

Fuentes primarias: [alta de almacenamiento](https://spec.filecoin.io/systems/filecoin_mining/sector/adding_storage/),
[PoRep](https://spec.filecoin.io/algorithms/pos/porep/),
[WindowPoSt](https://spec.filecoin.io/algorithms/pos/post/),
[fallos de sector](https://spec.filecoin.io/systems/filecoin_mining/sector/sector-faults/)
y [colateral](https://spec.filecoin.io/systems/filecoin_mining/miner_collaterals/).
La propia especificación de Filecoin marca partes de estas secciones con
«Theory Audit: wip»; se usa como diseño de referencia, no como prueba para ZEROX.

## 2. Línea base específica de ZEROX

La copia histórica del código y el análisis de `P-COBERTURA` muestran que:

- `SectorId` deriva de clave pública, índice e historia; no contiene fecha de
  cómputo de la parcela ni es contrastado con un registro de altas.
- La solución PoAS acredita una pieza y testigos del historial público. No
  incluye una apertura frente a un compromiso del sector completo ni acredita
  la forma física almacenada de ese sector.
- Los bytes de la parcela son deterministas y públicamente regenerables bajo
  el formato examinado. Una raíz de sus bytes puede fijar *qué* objeto se
  declara, pero no demuestra *cuándo* se calcularon o si siguen en disco.
- La propuesta POS2T registra garantía por clave, no sectores. El peso
  `blue_work` sigue derivando de PoAS, y el castigo propuesto se limita a
  firmas contradictorias observables.

Fuentes locales: `P-ZRX/P-COBERTURA/investigacion/INFORME.md` §§2–3 y 7;
`P-ZRX/P-SEMBRADOR/investigacion/INFORME.md`; `D-ZRX/SPEC.md` §§0, 3–5.
Los dos primeros están en `/home/katana/zeo/.trash/zerox/` o en `HEAD` histórico.
Sus cifras dependen de hardware y modelos de 2026-09-22 y no son parámetros.
El árbol actual contiene documentación nueva y conserva el código antiguo
principalmente en el historial: todo prototipo debe indicar exactamente qué
revisión estudia, sin dar por integrada la ruta activa PoAS + PoT + DAG.

## 3. Tres afirmaciones que hay que separar

| Afirmación | Resultado actual | Prueba que falta |
|---|---|---|
| «El sector quedó identificado antes de un reto» | Un alta con orden y edad podría hacerlo | Regla de orden DAG, reto impredecible y consulta contextual del registro |
| «El sector completo existía en esa fecha» | Un `SectorId` o raíz no lo demuestra | Prueba de cómputo completo vinculada a aleatoriedad posterior o un nuevo formato; especificar su alcance temporal |
| «El sector permaneció disponible» | Una solución ganadora no lo demuestra | Auditorías futuras, plazo, coste adversarial de regeneración y tasa de fallos honestos |

**Inferencia:** un registro exacto puede impedir sustituir silenciosamente un
sector comprometido por otro y mejorar la contabilidad. Sin una prueba de alta
de alcance suficiente, eso no equivale a capacidad física acreditada. Incluso
con auditorías por muestras, «capacidad» significa capacidad lógica bajo un
modelo de regeneración y duplicación explícito, no bytes únicos de hardware.

## 4. Hipótesis de mejora y ataques que la refutan

1. **Adaptación a retos futuros.** Un alta anterior al reto puede obligar a
   decidir antes, pero el productor puede registrar muchos candidatos y elegir
   claves; una raíz calculable sin conservar los bytes no fecha su existencia.
   La prueba debe medir edad efectiva frente a adelanto PoT, sesgo de claves,
   coste de altas masivas y pérdida de capacidad honesta por espera.
2. **Garantía proporcional a capacidad.** Un contador de sectores activos
   permite definir una obligación por sector, pero debe acreditarse que cada
   sector aporta capacidad útil y que la misma capacidad no respalda muchas
   identidades con coste trivial. La garantía puede cubrir una falta demostrada
   sin otorgar turnos ni multiplicar `blue_work`.
3. **Permanencia tras cobrar.** Auditorías futuras pueden detectar ausencia y
   elevar el coste de borrar; no distinguen por sí solas borrado malicioso de
   fallo de disco, partición o censura de la respuesta. La primera consecuencia
   a evaluar es suspensión de elegibilidad o recompensa futura; confiscar
   garantía por ausencia exige un modelo de falsos positivos aceptable.
4. **Rama privada.** El registro y las auditorías no impiden reutilizar el
   mismo sector en historias competidoras ni revelan una rama oculta. No
   reivindicar cierre del doble farmeo por esta vía.

## 5. Decisiones y puertas

| Puerta | Evidencia mínima | Si falla |
|---|---|---|
| G1 · Compromiso | La solución real abre el mismo objeto registrado; especificación de bytes, versión, cardinalidad y caducidad; costes de alta y verificación | No proponer registro en consenso como defensa de cobertura |
| G2 · Tiempo y permanencia | Coste adversarial frente a ventana de reto y plazo, adelanto PoT, aperturas y regeneración; sensibilidad CPU/GPU y falsas ausencias | Clasificar solo como contabilidad o encarecimiento condicional |
| G3 · DAG y economía | Transiciones deterministas con reorg/undo, conservación monetaria, presupuesto de nodo, accesibilidad para nuevos productores y no canibalización PoAS/PoT | No proponer ratificación ni parámetros |
| G4 · Nuevo formato | Solo si G1/G2 muestran una brecha relevante: amenaza, ganancia verificable y coste de reploteo/migración | Mantener el formato y declarar el límite |
| G5 · Sistema completo | Compatibilidad de PoRep con los bytes usados por PoAS, orden PoW→precompromiso→aleatoriedad→prueba→auditoría, ataques residuales y consecuencias de faltas | No trasladar la secuencia de Filecoin como regla de ZEROX |

Las puertas no requieren que un mecanismo vuelva imposible todo ataque; sí
exigen decir exactamente qué ataque impide, encarece, detecta o deja intacto.
La decisión final puede ser descartar, mantener como mejora opcional de
contabilidad, seguir investigando o redactar una propuesta normativa para
revisión. Ninguna de esas decisiones se infiere de un benchmark aislado.
