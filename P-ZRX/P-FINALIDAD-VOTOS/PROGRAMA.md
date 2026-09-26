# P-FINALIDAD-VOTOS — Programa: capa de finalidad por votos bajo R1–R5

**Fecha:** 2026-09-26. **Director:** Claude. **Origen:** conversación con Katana del 2026-09-26. El doble
farmeo no se evita dentro de la familia; Katana pide un encargo para estudiar una capa de finalidad por
votos que **lo arrincone**, sujeta a cinco reglas suyas.

## Mandato de Katana: R1–R5 (literal)

- **R1. Entrada abierta:** participa cualquiera con el recurso, sin permiso ni elección.
- **R2. Sin elección:** el peso es el recurso verificado en la cadena; nunca votos de terceros ni métricas
  externas.
- **R3. Nadie indispensable:** producir bloques nunca depende de los votantes; si faltan, solo se pausa la
  finalidad.
- **R4. Sin decidir contenido:** los votos solo sellan lo ya producido.
- **R5. Toda falta deja firma:** votar dos cosas contradictorias es prueba y castigo.

Motivo, en palabras de Katana: *«lo que no me gusta de los comités es que centralizan el poder/decisión y
yo quiero que zerox sobreviva sin una entidad o sujeto de respaldo, zerox tiene que sobrevivir por sí solo
con sus mineros, cultivadores, etc… nadie es indispensable, si alguien sale o desaparece el zerox sigue
adelante»*.

**Estado de la regla.** Para este programa, R1–R5 sustituyen a «no hay comités de decisión» (`AGENTS.md`,
hoy borrado; `D-ZRX/SPEC.md` §0 aún la invoca; IPA E-06). `SPEC.md` §0 **no** se edita hasta que FV-1
entregue y Katana ratifique.

## Decisiones de Katana (2026-09-26, provisionales hasta FV-1)

- **Peso:** sectores registrados con garantía, para que R5 tenga algo que castigar.
- **En el sorteo están todos los registrados**, no solo los que demostraron estar encendidos.
- **Sorteo secreto en cada ronda, como en Algorand (AGR1):** nadie sabe quién vota hasta que ya ha votado.
  Solo votan los que salen elegidos.
- **Probabilidad = espacio registrado × prima `b`** para quien demostró disponibilidad hace poco. La prueba es
  de sí o no y verificable en la cadena, no una puntuación. Ganar un bloque cuenta como prueba, pero no es la
  única ni da peso extra.
- **Advertencia del director:** el atacante siempre cobra la prima. `b` es un dial entre seguridad (`b = 1`)
  y viveza (`b → ∞`); con `b` finito, la fracción de plazas del atacante tiene techo aunque censure las
  pruebas de los honestos. FV-1 entrega las curvas en `(b, E)` (`ORDEN-FV1-DISENO.md`, decisión 6).

## Por qué

El razonamiento completo de la conversación está en `CONTEXTO.md`: por qué el doble farmeo no tiene cierre
conocido y sí mitigación, cómo se llegó de «no hay comités» a R1–R5, qué haría la capa y qué no, sus umbrales,
las correcciones del director y el problema del quórum con granjeros domésticos.

- **El doble farmeo no es evitable dentro de la familia** (`D-ZRX/RFT-ZRX.md` RFT-01, RFT-02, RFT-06,
  RFT-09). Ningún mecanismo de PoStake ni de Filecoin lo encarece de forma exigible frente al atacante
  grande (`P-ZRX/P-DISUASION/SINTESIS.md`). `C-FIN-01` acota el daño a `d < F_slots`, pero `F` no puede
  bajar: tiene signo opuesto en el doble farmeo y en el eclipse.
- **Baig y Pietrzak no dicen que un BFT cierre el doble farmeo.** Dicen que Filecoin escapa a *su*
  imposibilidad (*replotting*) con BFT; el doble farmeo de ZEROX es otro vector
  (`P-ZRX/P-DISUASION/resultados-DS2/INFORME.md` §2.5).
- **Hipótesis del director, a comprobar por FV-1 (no son resultados):** la capa **no** cierra el doble
  farmeo; lo arrincona en la franja aún no sellada. Revertir lo sellado exige que al menos un tercio del
  peso total firme dos cosas contradictorias, lo que deja evidencia. Un nodo eclipsado no acepta un sello
  falso sin 2/3 de las firmas. La finalidad rápida deja de competir con el eclipse. El precio: un tercio
  del peso, **contando a los honestos apagados**, pausa la finalidad; un tercio más control de la red
  rompe el sello, con firma; y hacen falta 2/3 del peso **total** en línea para sellar.
- **Precedentes.** Filecoin F3 (FIP-0086) sobre su consenso de base; Casper FFG sobre PoW. En ZEROX,
  `research/dag-poas-capa-finalidad.md` (2026-09-09, **hipótesis sin auditar**, en `.trash/zerox/` y en
  `9681061`): la misma capa con el peso derivado de los bloques cobrados. Quedó bloqueada por la regla de
  comités y porque «PoAS no registra a nadie».

## Límites

- **No toca 0.0.1.** Es una capa superpuesta: no cambia quién produce, quién cobra, GHOSTDAG ni
  `blue_work`. `C-FIN-01` permanece como red de seguridad.
- **Modelo de amenaza de Katana:** asumir un atacante con recursos de Estado. Para cada ataque hay que dar
  su coste absoluto y distinguir lo imposible de lo caro; «no compensa» no es argumento.
- **Castigo coherente con P-SLASHING:** sin castigo correlacionado (DS-5) y sin castigo por ausencia;
  evidencia de la misma familia que `EvidenceTx` (`P-ZRX/P-SLASHING/resultados-SL1/CONTRATO-EVIDENCIA-v0.md`).

## Encargos

| ID | Qué | Ejecutor | Depende de |
|---|---|---|---|
| FV-1 | Diseño, contrato v0 y análisis adversarial de la capa bajo R1–R5; comparación de las tres fuentes de peso; comprobaciones numéricas | Sonnet | — |
| FV-2 | Modelo cuantitativo: quórum con participación real, sesgo de la tabla de pesos, duración de ronda frente a `Δ` | DeepSeek (Julia) | FV-1 ratificado |
| FV-3 | Oráculo Julia y vectores | DeepSeek | FV-2 |
| FV-4 | Implementación Rust; diferencial contra FV-3 | Sonnet | FV-3; `Δ` medida en la red dev |

FV-2, FV-3 y FV-4 se redactan cuando FV-1 esté ratificado: su alcance depende de la prueba de
disponibilidad, de `b` y del suelo `E` que salgan de FV-1.

## Programas de la misma solución

- **`P-ZRX/P-AUSENCIA-VOTO/`**: qué pasa cuando alguien sale elegido y no vota. Hay que hacer el sorteo
  verificable después, y la consecuencia es la pérdida de la prima y una confiscación pequeña (decisión FV-D03).
  Su primer encargo es AV-1.
