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
| **Doble farmeo con reclutamiento** (atacante que necesita espacio ajeno) | Castigo con evidencia + retención (DS-L03, RAT-3) | Encarece de forma condicionada: con el reparto real de un pool, el espacio en claves sin saldo es ≈ 1,8·10⁻⁴ y el reclutado tiene saldo que perder (DS-6, SL-2, SL-2b) | Motor y cadena sí (SL-4a); nodo **no** (SL-4b) |
| **Equivocación publicada** (doble firma de la misma oportunidad) | `EvidenceTx` v4, confiscación, 2/8 al incluidor | Castigo exigible una vez publicada; autodenuncia nunca rentable (pierde ≥ 6/8·C, RFT-22) | Igual que la fila anterior |
| **Espacio ajeno** (pool que firma a ciegas) | Coinbase atada a `sol.public_key` (O4) | Quita el premio del robo, sin detección (RFT-11 sigue: no quita la capacidad) | **Sí** (puerta conjunta) |
| **Sembrador** (regenerar en vez de almacenar) | Registro + auditorías + colateral | ≈ 7,1 GTX 1070 y ≈ 677 W por TiB en continuo (exigible); detección solo con > 181 092 aperturas por TiB (RFT-04) | **No** (`SEC-0`) |
| **Sybil** (partir el espacio en claves) | Garantía mínima por identidad | Exigible pero regresiva (RFT-23) | Sí, `q = 20` dev |
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
