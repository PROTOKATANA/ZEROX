# P-DISUASION — Marco común: qué resuelven y cuánto encarecen PoStake y Filecoin en ZEROX

**Fecha:** 2026-09-26. **Director:** Claude. **Origen:** Katana, 2026-09-26: determinar qué problemas
resuelven los mecanismos de PoStake y de Filecoin en ZEROX y si mejoran la seguridad frente a un
atacante X. **Criterio de Katana:** un mecanismo que **no cierra** un hueco pero **encarece** el
ataque (en dinero, energía u otro coste) o actúa como barrera de disuasión **es una mejora real**
frente al protocolo antiguo (`.trash/zerox`, `9681061`), que no tiene PoStake ni barreras de
disuasión. Este marco lo rigen todos los encargos `DS-*`; nada de él es regla ni parámetro.

## 1. Qué se compara

- **Línea base B0:** ZEROX antiguo, PoST puro (PoAS + PoT + DAG) **sin** stake ni registro de
  sectores, tal como está en `9681061` y lo analizaron los encargos de `.trash/zerox/P-ZRX/`.
- **B1:** el híbrido actual de 0.0.1 (garantía por clave con requisito `q`, coinbase PoST acreditada a
  garantía con madurez, retiro con retardo; **sin** evidencia ni castigo; `SEC-0`).
- **Candidatos:** cada mecanismo del §3, solo y en las combinaciones que el encargo justifique.

## 2. Atacante X y catálogo de ataques

X tiene recursos grandes y los usará (modelo de amenaza de Katana: «no compensa» no es seguridad;
distinguir **imposible** de **caro** y dar el **coste absoluto**). Parámetros de X: fracción de
espacio `α`, capital `K`, hash `h` en la fase PoW, GPU, red, tiempo.

| ID | Ataque | Evidencia previa (leer antes) |
|---|---|---|
| A1 | Doble farmeo: producir con el mismo espacio en ramas privadas o competidoras; reorganización para doble gasto | `.trash/zerox/P-ZRX/T-ZRX/ESTADO-DOBLE-FARMEO.md`; `D-ZRX/RFT-ZRX.md` RFT-01, RFT-09 |
| A2 | Equivocación publicada (dos bloques del mismo slot y clave) | RFT-02; `.trash/zerox/P-ZRX/P-EQUIVOCACION/` |
| A3 | Sembrador: regenerar la parcela bajo demanda en vez de almacenarla | RFT-04; `P-SEMBRADOR`, `P-INTENTO`; `P-ZRX/P-REGISTRO-SECTORES/investigacion/02-auditorias/` |
| A4 | Sybil / partición de identidades para evadir reglas por clave | RFT-05, RFT-10; `P-TASA`, `P-IDENTIDAD`, `P-CLAVE` |
| A5 | Producir con espacio ajeno (pools sin clave, externalización) | `P-POOLS`; memoria «pools pueden producir con espacio ajeno» |
| A6 | *Grinding* de retos o de la semilla | RFT-08; `P-ZRX/P-TRANSICION/NOTA-A07-SEMILLA.md` |
| A7 | Largo alcance: reescribir historia con claves antiguas o ya retiradas | IPA C-03, C-08; `C-FIN-01` |
| A8 | Captura de la transición: prefijo PoW, ventana previa al primer bloque PoST, censura de depósitos | RFT-13; IPA A-05, A-05b, A-08, A-10; `P-ZRX/P-POW/REVISION-A10-M1.md` |
| A9 | Retención y censura de bloques en el DAG (*selfish*), exclusión de honestos | IPA B, X-01 |
| A10 | Alta tardía, capacidad duplicada, precomputación | `P-COBERTURA` (ningún compromiso fecha nada, Cor. 4) |
| A11 | Eclipse | `.trash/zerox/P-ZRX/P-ECLIPSE/`, `R-ZRX/LEGADO/eclipse/` |
| A12 | Efecto secundario: denuncias falsas, castigo a honestos, *griefing* | IPA C-05 |

## 3. Catálogo de mecanismos

- **PoStake:** M1 garantía mínima para producir (`q`, `S_min`) — capital inmovilizado; M2 recompensa
  acreditada a garantía con madurez (D-T08) — recompensa bloqueada y confiscable; M3 castigo por
  equivocación con evidencia (`C-EVP`); M4 castigo correlacionado (`C-SLA`); M5 retardo de retiro
  (`R_slots`) y congelación; M6 requisito proporcional (a capacidad o a oferta, IPA C-02).
- **Filecoin:** F1 registro / precompromiso de sectores con depósito; F2 auditorías periódicas tipo
  WindowPoSt con penalización por fallo; F3 sellado lento (PoRep/SDR) como coste de codificación;
  F4 colateral por sector y tasas de fallo o terminación; F5 ciclo de vida (activación retardada,
  expiración).
- **Otros:** O1 PoW de arranque; O2 PoT/VDF; O3 finalidad `C-FIN-01`; O4 atar la coinbase a quien
  firma (tipo Chia) contra A5; O5 lo que las fuentes aporten (p. ej. penalizaciones de Spacemint).

## 4. Dimensiones de coste (todas en unidades absolutas)

| Dimensión | Qué mide | Unidad |
|---|---|---|
| C-riesgo | Capital que X **pierde** si le descubren | tokens y su valor |
| C-inmov | Coste de oportunidad del capital bloqueado mientras ataca | `r·K·T` |
| C-adq | Adquirir los tokens (impacto de mercado; o minarlos en el prefijo PoW: acoplamiento A8 ↔ M1) | valor |
| C-energía | Energía extra (PoW, sellado, regeneración) | kWh (con las medidas de A10-M1) |
| C-hardware | Discos, GPU, ancho de banda | unidades y valor |
| C-tiempo | Retardos, madurez, ventanas, esperas | slots, horas |
| P-detección | Probabilidad de que la conducta deje evidencia **que llega** a la cadena que siguen los honestos | [0, 1] |

## 5. Veredicto por celda (ataque × mecanismo)

- **I** — imposible bajo supuestos (listarlos).
- **E** — encarece: Δ del coste mínimo de X frente a B0 (absoluto) y frente al coste del honesto
  (cociente). Se marca **exigible** si recae sobre X haga lo que haga (p. ej. inmovilizar garantía
  para producir) o **condicionado** si depende de detección e inclusión de evidencia (p. ej. castigo
  con una rama privada que nunca se publica, RFT-01).
- **N** — neutro. **W** — empeora (superficie nueva, exclusión de honestos, castigo erróneo).

Una celda **E exigible con Δ > 0** es una **mejora real** con el criterio de Katana; el informe dice
además cuánto le cuesta al honesto y si X puede trasladar el coste (p. ej. minar sus tokens en el
prefijo PoW).

## 6. Encargos

| ID | Qué | Ejecutor | Depende de |
|---|---|---|---|
| DS-1 | Fuentes primarias: mecanismos de disuasión en Filecoin, Chia, Spacemint, Autonomys, Ethereum y literatura; magnitudes con fecha | Sonnet (web) | — |
| DS-2 | Matriz ataque × mecanismo para ZEROX con costes y veredictos, sobre la evidencia del repositorio y DS-1 | Sonnet | DS-1 |
| DS-3 | Calculadora y Monte Carlo del coste mínimo de los ataques principales, B0 frente a B1 y candidatos | DeepSeek (Julia) | DS-2 |
| DS-4 | Medida en GPU del coste de regenerar parcelas (hueco «GPU sin medir» de `P-INTENTO`) | Sonnet (GPU) | — |

Solapes declarados: DS-1 aporta fuentes a los encargos 04 y 05 de `P-ZRX/P-REGISTRO-SECTORES/`
(de Katana), que siguen vigentes; DS-2 no sustituye al encargo 03 (semántica DAG del sector).
