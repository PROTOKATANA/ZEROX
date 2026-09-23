# DECISIONES-PENDIENTES — P-SECRETO

**Regla de este documento:** solo bifurcaciones reales, con el coste de cada rama dicho
en voz alta. La calificación política es de Katana; aquí va la factura técnica.

## D1 · ¿Aceptar la atestiguación por bloque como condición de validez?

Lo que compra (bajo firmantes V2): la rama privada deja de ser privada — el doble farmeo
se vuelve observable (κ → 1) o paga el silencio de (1−α)·k firmantes por bloque. Lo que
cuesta: **la viveza** — la ronda de k firmas no cabe en el slot con la Δ medida
(P(cabe) = 0,22 con k = 4, h = 3, Δ = 0,26 s; 10⁻⁴ con Δ = 0,60); la abstención del
atacante corta la producción a (1−α)^k gratis y sin evidencia; una partición para los dos
lados con probabilidad 0,94 (k = 4, corte 50/50). El modo de fallo es letal (condición de
validez, no capa aditiva).

| Rama | Coste | Consecuencia |
|---|---|---|
| **A. Descartar** (recomendado) | ninguno; se conserva el diseño vigente | κ = 0 sigue abierto por el lado de la validez; la defensa queda en C-FIN-01 y en el frente de la oferta (D4) |
| B. Adoptar con k pequeño (1–2) | abstención de un atacante del 10 % corta el 10–19 % de la producción; k = 1–2 no cabe tampoco con h = 3 (P(cabe) ≤ 0,68/0,47) | la defensa de captura ya la da k = 1; se paga viveza sin ganar nada nuevo |
| C. Adoptar con k grande (≥ 4) | producción honesta ((1−α)·p)^k → 0,43 con p = 0,9 y α = 0,10 (57 % de bloques muertos) y 0,13 con α = 0,33 (87 %); Ed25519 con k ≥ 16 rompe Q2; BLS reabre la bifurcación blst | inseguridad de disponibilidad mayor que la ganancia de seguridad |

## D2 · ¿Adoptar la tabla de poder derivada (maquinaria de la capa de comité)?

El sorteo ponderado por espacio exige contar espacio por clave sin registro: la tabla
R-FIN-15 (`research/dag-poas-capa-finalidad.md` §3) con su W_VIVO, su `p` sin medir y su
ataque de moldeado de tabla (D8, sin cerrar).

| Rama | Coste | Consecuencia |
|---|---|---|
| **A. No adoptar** (recomendado) | ninguno | reabre la maquinaria que quedó descartada, sin comprar nada una vez que D1 es «no» |
| B. Adoptar la tabla sola | W_VIVO, ventana de conteo, poda, y el vector de moldeado sin medir | infraestructura de registro de facto, con los agujeros que la hicieron descartar |

## D3 · ¿Revisar la línea roja del ancla externa?

Como condición de validez el ancla externa es **vacía** (el atacante referencia los
mismos datos externos; ver lo público no obliga a publicar — F2-b del INFORME). Como
regla que decide la canónica es decisión, no validez, y contradice AGENTS.md
(`AGUJEROS-Y-SOLUCIONES.md` D4).

| Rama | Coste | Consecuencia |
|---|---|---|
| **A. Mantener la línea roja** (recomendado) | ninguno | el ancla externa sigue disponible como ayuda al operador, sin tocar κ = 0 |
| B. Revocarla | dependencia de una cadena ajena (parada, reorg, censura); granularidad: anclas cada N minutos no cubren reorganizaciones cortas | cambia la identidad del protocolo por una ganancia que F2-b muestra inexistente |

## D4 · ¿Perseguir el frente de la oferta de β?

Único frente con expectativa razonable según `P-ZRX/T-ZRX/ESTADO-DOBLE-FARMEO.md` H-7
(alquiler directo, farming gestionado, custodios); este encargo lo refuerza: el secreto
no se rompe por el lado de la validez, luego la palanca que queda es que **no haya β que
prestar**.

| Rama | Coste | Consecuencia |
|---|---|---|
| **A. Abrir encargo de oferta** (recomendado) | un encargo de arquitectura/economía, no de criptografía | ataca la única variable que este encargo demuestra intocable por consenso |
| B. No abrirlo | ninguno inmediato | κ = 0 queda sin frente activo; el doble farmeo sigue vivo dentro de la ventana C-FIN-01 |

## D5 · La variante de dos fases (activación de peso por atestiguación)

Descartada por el propio análisis (§4.5: la validez/peso dependería del futuro del
bloque). No se propone como decisión abierta salvo que Katana quiera revisar la línea
roja de validez absoluta, lo que abriría el multistream — fuera del alcance de este
encargo y contra decisiones anteriores.
