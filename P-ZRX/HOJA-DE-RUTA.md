# Hoja de ruta de versiones de ZEROX (decisión de Katana, 2026-09-27)

| Versión | Contenido | Plan |
|---|---|---|
| **0.0.1** | Ruta vertical medible: PoW de arranque SHA3 dev, corte, PoAS + PoT, DAG, garantía, evidencia y castigo por doble firma, red, sincronización, reinicio; mediciones reales (W07b) | `P-ZRX/PLAN-0.0.1.md`, `D-ZRX/SPEC-0.0.1.md`, `D-ZRX/INFORME-0.0.1.md` |
| **0.0.2** | En este orden (Katana, 2026-09-27): **(1)** medición del **doble farmeo** en la red dev + **FV-2 y FV-3** (modelo y oráculo de la finalidad por votos, sin código de nodo) + **medir `ρ_max`** (AES del PoT en las CPU y GPU disponibles) y, con ese dato, **decidir el segundo VDF** (RFT-12) y **derivar `N` y decidir entre `N` fijo y `N` dinámico con techo**, escribiendo la ley de adaptación que falta (`R-ZRX/LEGADO/reloj/ESTADO-RELOJ.md`; IPA B-02; `P-ZRX/P-N-DINAMICO/ENCARGO-ND1.md`) + **eclipse: rehacer P-ECLIPSE con las reglas nuevas y medir el coste de capturar un nodo en la red dev** (IPA B-07): investigación que decide la viabilidad; **(2)** **relevo de transacciones** (IPA A-14) **y prevención del eclipse** en la misma capa de red (gestor de direcciones con diversidad por prefijo, conexiones ancla, renovación de pares; IPA B-07); **(3)** **PoStake pendiente** (garantía por unidad de espacio, retención y disuasión comprobada —SL-2c, C-12—, liquidez del productor —C-13—); **(4)** **coste de admisión GHOSTDAG** acotado (IPA B-12); **(5)** **mecanismos de Filecoin** (IPA D-01…D-05: registro de sectores, PoRep, auditorías, ciclo de vida) | `P-ZRX/PLAN-0.0.2.md` |
| **0.0.3** | **Finalidad por votos en el nodo** (FV-4, Rust) con el peso definitivo de sectores registrados (FV-D01); FV-2 y FV-3 se hacen en 0.0.2. **Recuperación del eclipse con los votos** (IPA B-07; propuesta del director sin evaluar: los sellos firmados por la mayoría del peso como señal verificable para que un nodo eclipsado salga incluso pasado `F`; riesgo que estudiar: firmas viejas de claves ya retiradas, ataque de largo alcance) | `P-ZRX/P-FINALIDAD-VOTOS/` |
| **0.0.4** | **Minero PoW SHA3-256 para CPU (Rust) y GPU AMD (HIP)**, corrigiendo y reutilizando `caliza` y `silicio` | sección «Minero PoW» de `P-ZRX/PLAN-0.0.2.md` (se moverá a `PLAN-0.0.4.md`) |

Katana, al fijar el orden: «0.0.2: Filecoin, 0.0.3: Finalidad, 0.0.4: Minero»; el relevo de transacciones entra en 0.0.2
(respuesta del mismo día). Que lo pendiente de PoStake vaya en 0.0.2 es lectura del director (depende de los sectores);
se revierte si Katana lo sitúa en otra versión.

**Eclipse (Katana, 2026-09-27, opción recomendada por el director):** «esto también es algo que se debe investigar y
solucionar»; se divide: investigación en el paso 1 de 0.0.2, prevención en 0.0.2 junto al relevo de transacciones y
recuperación con los votos en 0.0.3.

**Sugerencias del director pendientes de ubicar** (no decididas por Katana): reinicio con instantáneas de estado (IPA
E-10), propuesto para 0.0.3; semilla del corte no sesgable (IPA A-07; en W07b E-9 quien retuvo su terminal y lo publicó
tarde ganó la reunión), propuesta para 0.0.4 junto al minero.
