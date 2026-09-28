# Síntesis — qué protege al ZEROX híbrido, frente a qué, y cómo se combinan los mecanismos

**Fecha:** 2026-09-26 22:25. **Firma:** Claude (director). **Junta:** P-DISUASION (DS-1…DS-6, con su
`SINTESIS.md`), P-SLASHING (SL-1…SL-4a), P-FINALIDAD-VOTOS (FV-1, dos ejecuciones) y P-AUSENCIA-VOTO (AV-1),
más el estado del nodo (P-NODO). **No es regla:** lo normativo de 0.0.1 está en `D-ZRX/SPEC-0.0.1.md`; lo
refutado, en `D-ZRX/RFT-ZRX.md`; lo abierto, en `D-ZRX/IPA-ZRX.md`.

## 1. Efecto combinado por ataque

«Exigible» = el atacante lo paga haga lo que haga; «condicionado» = solo si deja evidencia o se le detecta.

| Ataque | Mecanismos que actúan | Efecto combinado | ¿En 0.0.1? |
|---|---|---|---|
| **Doble farmeo en rama privada** (atacante grande con espacio propio) | Garantía, castigo con evidencia, registro de sectores, `C-FIN-01`; **finalidad por votos** | Ninguno lo encarece de forma exigible (RFT-01, RFT-14, RFT-15). `C-FIN-01` acota la profundidad a `F_slots`. La capa de votos acota el **tiempo** a la franja sin sellar y hace que reescribir lo sellado exija dos certificados firmados (castigables) | `C-FIN-01` sí; votos **no** (sin contrato ni código) |
| **Doble farmeo con reclutamiento** (atacante que necesita espacio ajeno) | Castigo con evidencia + retención (DS-L03, RAT-3) | Encarece de forma condicionada: con el reparto real de un pool, el espacio en claves sin saldo es ≈ 1,8·10⁻⁴ y el reclutado tiene saldo que perder (DS-6, SL-2, SL-2b) | Motor y cadena sí (SL-4a); nodo **no** (SL-4b). *2026-09-28: sí en el nodo, medido con procesos reales (W07b E-8)* |
| **Equivocación publicada** (doble firma de la misma oportunidad) | `EvidenceTx` v4, confiscación, 2/8 al incluidor | Castigo exigible una vez publicada; autodenuncia nunca rentable (pierde ≥ 6/8·C, RFT-22) | Igual que la fila anterior |
| **Espacio ajeno** (pool que firma a ciegas) | Coinbase atada a `sol.public_key` (O4) | Quita el premio del robo, sin detección (RFT-11 sigue: no quita la capacidad) | **Sí** (puerta conjunta) |
| **Sembrador** (regenerar en vez de almacenar) | Registro + auditorías + colateral | ≈ 7,1 GTX 1070 y ≈ 677 W por TiB en continuo (exigible); detección solo con > 181 092 aperturas por TiB (RFT-04) | **No** (`SEC-0`) |
| **Sybil** (partir el espacio en claves) | Garantía mínima por identidad | Exigible pero regresiva (RFT-23) | Sí, `q = 10` ZZK por clave en dev (*corregido el 2026-09-28: decía `q = 20`, que es el `q_g` de SL-2 en unidades del modelo*) |
| **Largo alcance / *bootstrapping*** | PoT de un solo flujo, `C-FIN-01`, sellado lento (si se adopta) | El PoT cierra el *bootstrapping* de Baig–Pietrzak; el *replotting* queda abierto sin registro + BFT (RFT-16) | PoT y `C-FIN-01` sí |
| **Pausar la finalidad** | Falta «elegido sin voto», `m_aus` proporcional (FV-D06) | Pausar cuesta y el coste crece con el tamaño del atacante; el umbral no sube: 20 % con `b = 2` y censura (RFT-17) | **No** |
| **Sellar una mentira** | Umbral 2/3 del peso, `EvidenceVoto` | Exige el 50 % con `b = 2` y censura; irreversible para quien lo adoptó (RFT-18); deja firmas castigables | **No** |
| **Ventana previa al primer bloque PoST** | Ninguno PoST | Carrera PoW de Nakamoto (RFT-13) | Sí, como límite declarado |

## 2. Conflictos entre mecanismos

1. **Garantía por identidad (anti-Sybil) frente al granjero pequeño:** regresiva (RFT-23) y excluye a quien
   aporta espacio sin tokens (IPA C-07). La salida candidata —garantía por unidad de espacio (C-02)— exige
   medir el espacio, es decir, el registro de sectores.
2. **Prima `b` de los votos:** trilema entre viveza, pausa y sello (RFT-17). `b = 2` (FV-D05) paga con un
   umbral de pausa del 20 %.
3. **`m_aus` proporcional frente al honesto con apagones:** los fallos propios se pagan por decisión de
   Katana (FV-D03, FV-D04); el plazo de gracia neutraliza la censura salvo control total de la red.
4. **Castigo correlacionado frente a honestos:** descartado (RFT-15); la multa por ausencia tampoco se
   correlaciona.
5. **Firmante seguro:** lo necesitan a la vez la producción (SL-4b) y el voto (FV-1, D4); se vota más que se
   produce, así que el firmante del voto soporta más carga.

## 3. Supuestos compartidos (si cae uno, caen varias filas)

- **Registro de sectores:** lo exigen la capa de votos (peso = sectores registrados), la garantía por unidad
  de espacio y las auditorías. **No existe** (`SEC-0`). Es el bloqueo común de X-04, C-02 y D-01…D-05.
- **Evidencia publicada y disponible:** todo el castigo es condicionado a ella; la censura parcial se
  neutraliza si cualquier productor honesto de la ventana puede incluirla (SL-2b).
- **Reparto del espacio entre claves:** decide si el castigo muerde al que recluta; medido en un pool de
  Chia (DS-6), **no** en ZEROX.
- **`Δ` y el slot real:** fijan `F_slots`, los plazos de evidencia y la instancia de votos; **sin medir**
  (W07). El slot con `N_dev` real dura 1,66 s, no 1 s.
- **Unidades en tokens:** todas las cifras en u.e. son escenarios hipotéticos, con la reserva de escala F5.

## 4. Qué cambia respecto del ZEROX antiguo (`9681061`)

El antiguo no tenía garantía, ni castigo, ni coinbase atada a la clave, ni capa de finalidad: la disuasión
por coste contra el que recluta, contra la equivocación publicada, contra el espacio ajeno y contra Sybil
era **cero**. El híbrido las tiene (O4 y garantía ya en 0.0.1; castigo en motor y cadena; votos diseñados),
**sin** cerrar el doble farmeo del atacante autosuficiente, que ningún sistema de espacio revisado cierra.

## 5. Orden de trabajo que se deduce

SL-4b (castigo en el nodo) → W07 (medir `Δ`, slot real) → FV-2 con la fuente de peso provisional decidida
→ registro de sectores (desbloquea votos, garantía por espacio y auditorías).

## 6. Actualización del 2026-09-28 (cierre de 0.0.1 en `c107163`)

Junta además W06d6…W06d10-B, W07a…W07d y W07b (`P-ZRX/P-MEDICION/REVISION-W07b.md`), y las decisiones de Katana del
27 y el 28 (`P-ZRX/HOJA-DE-RUTA.md`). Las filas de §1 marcadas «2026-09-28» ya están corregidas en su sitio.

**Ataques que §1 no tenía:**

| Ataque | Mecanismos que actúan | Efecto combinado | ¿En 0.0.1? |
|---|---|---|---|
| **Eclipse o partición mayor que `F`** (se paga en IP, no en espacio) | Descubrimiento por Kademlia; **sin** gestor de direcciones | En el corte, `C-FIN-01` entre terminales deja para siempre en el terminal del atacante a un nodo eclipsado más de 600 slots (≈ 13 min); tras el corte, las particiones del mismo terminal se fusionan (E-6) | Expuesto (IPA B-07, P1; 0.0.2 y 0.0.3) |
| **Retención del terminal** (publicar tarde el bloque que cruza el corte) | FC-3 por `blue_work` | En W07b E-9 rep1 el terminal retenido **ganó** la reunión (reorganización de 30); descriptivo, sin criterio | Expuesto (IPA A-07, sin ubicar) |
| **Inundación de bloques inválidos** | Rechazo con motivo + penalización del par (C-NET-05) | Rechazo sin cambio de estado; el par queda desconectado y puntuado (veto por `PeerId` en loopback); lo que depende de la vista local no penaliza (RFT-27) | **Sí** (W06d10, W06d10-B) |
| **Reloj más rápido** (PoT adelantado) | Un solo flujo PoT, `C-FIN-01` | Adelanto ≈ `L` para `ρ > 1` (RFT-12); el segundo VDF lo recortaría para `ρ < 1 + L/I` | Expuesto (0.0.2 paso 1: `ρ_max`, segundo VDF) |
| **Manipulación de timestamps** | Ninguna en PoST (el timestamp de la cabecera **no se valida**) | Hoy no lo consume ninguna regla; lo haría un `N` dinámico (P-RELOJ: el minoritario **sube** `N`) | Latente (IPA B-13; ENCARGO-ND1) |

**§3 corregido:**
- **`Δ` y el slot real** ya no están «sin medir», pero solo en localhost. El slot mide 1,28 s en W07b (1,66 s en W06d1,
  sin explicar la diferencia). La propagación da p50 ≈ 170 ms y p95 ≈ 0,4 s. `Δ_p99` no está calculado y no hay red WAN.
- **Supuesto nuevo:** el relevo de transacciones. Sin él, `K_min` se cumple por lado y un operador con varias claves
  puede excluir a los demás (RFT-26, IPA A-14).

**§5 sustituido:** el orden de trabajo es ahora la hoja de ruta de Katana (`P-ZRX/HOJA-DE-RUTA.md`):
- **0.0.2:** (1) doble farmeo medido, FV-2/FV-3, `ρ_max`, segundo VDF, `N` dinámico y eclipse; (2) relevo de tx y
  prevención del eclipse; (3) PoStake pendiente; (4) GHOSTDAG; (5) Filecoin.
- **0.0.3:** votos y recuperación del eclipse.
- **0.0.4:** minero.
