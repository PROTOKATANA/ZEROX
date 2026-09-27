# Hoja de ruta de versiones de ZEROX (decisión de Katana, 2026-09-27)

| Versión | Contenido | Plan |
|---|---|---|
| **0.0.1** | Ruta vertical medible: PoW de arranque SHA3 dev, corte, PoAS + PoT, DAG, garantía, evidencia y castigo por doble firma, red, sincronización, reinicio; mediciones reales (W07b) | `P-ZRX/PLAN-0.0.1.md`, `D-ZRX/SPEC-0.0.1.md`, `D-ZRX/INFORME-0.0.1.md` |
| **0.0.2** | **Mecanismos de Filecoin** (registro de sectores, PoRep, auditorías, ciclo de vida en el DAG) + **relevo de transacciones** (IPA A-14: abrir la red a nuevos productores tras el corte) + **lo que falta de PoStake** (garantía por unidad de espacio, retención de recompensas y disuasión comprobada —SL-2c, C-12—, liquidez del productor —C-13—) | `P-ZRX/PLAN-0.0.2.md` |
| **0.0.3** | **Finalidad por votos** (FV-2 modelo, FV-3 oráculo, FV-4 Rust) con el peso definitivo de sectores registrados (FV-D01); FV-2 y FV-3 pueden adelantarse sin código de nodo | `P-ZRX/P-FINALIDAD-VOTOS/` |
| **0.0.4** | **Minero PoW SHA3-256 para CPU (Rust) y GPU AMD (HIP)**, corrigiendo y reutilizando `caliza` y `silicio` | sección «Minero PoW» de `P-ZRX/PLAN-0.0.2.md` (se moverá a `PLAN-0.0.4.md`) |

Katana, al fijar el orden: «0.0.2: Filecoin, 0.0.3: Finalidad, 0.0.4: Minero»; el relevo de transacciones entra en 0.0.2
(respuesta del mismo día). Que lo pendiente de PoStake vaya en 0.0.2 es lectura del director (depende de los sectores);
se revierte si Katana lo sitúa en otra versión.
