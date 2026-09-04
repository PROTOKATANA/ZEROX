# Bundle Orchard — layout byte a byte · agente zx-d1-cripto-zk (Sonnet), 2026-09-04

> Verificado contra código real: `zcash/orchard@be4f659` (v0.15.5), `zcash/librustzcash@5e770a9`,
> `protocol.tex` (fuente LaTeX), ZIP-224/225/244, y **empíricamente contra 200 tx reales de
> mainnet Zcash vía API de Blockchair** (100 v5 → 9165 B exactos, 100 v6 → 9166 B exactos).
> Para la Fase 6 (pool blindado) — no bloquea la Fase 0, pero contiene 2 hallazgos de seguridad
> que sí importan ya (versión mínima del crate a pinear).

## 1 · La Action — 820 bytes, orden exacto

⚠️ **`cv` va PRIMERO, no el nullifier** (contradice el orden intuitivo/el del struct en memoria del crate — el serializador escribe `cv_net` primero).

| off | bytes | campo | contenido |
|---|---|---|---|
| 0 | 32 | `cv` | commitment Pedersen al valor neto. **Puede ser el punto cero.** |
| 32 | 32 | `nullifier` | de la nota gastada |
| 64 | 32 | `rk` | validating key aleatorizada. **NO puede ser identidad** (regla nueva, ver §9) |
| 96 | 32 | `cmx` | commitment de la nota creada |
| 128 | 32 | `ephemeralKey` | clave pública Pallas efímera. **NO puede ser identidad ni encoding inválido** |
| 160 | 580 | `encCiphertext` | AEAD: 564 B plaintext + 16 B tag |
| 740 | 80 | `outCiphertext` | 64 B plaintext + 16 B tag |
| **820** | | | **TOTAL** |

`encCiphertext` (564 B plaintext = `leadByte(1)‖d(11)‖v(8)‖rseed(32)‖memo(512)`):
```
[0..52)    parte "compacta" (para light clients / CompactBlock)
[52..564)  memo cifrado
[564..580) tag Poly1305
```
El corte en 52 no es arbitrario: `1+11+8+32`. Cae en frontera de campo a propósito — permite trial-decryption sin descargar memos.

## 2 · Por qué se fusiona spend+output — qué oculta EXACTAMENTE (no sobrevender)

| Oculta | NO oculta |
|---|---|
| El nº de spends reales vs outputs reales (arity hiding) | El **nº de acciones** `n` — va en claro en `nActionsOrchard` |
| Si una acción gasta/crea una nota real o dummy | Que la tx **toca** el pool Orchard |
| El valor de cada nota | El **`valueBalance`** total (en claro) |
| El destinatario | El **anchor** y los **nullifiers** (visibles, no vinculables a su commitment) |

Mecánica: una acción dummy tiene nullifier/cmx **reales**, de una nota real de valor 0 — indistinguible porque es igual de real, solo con valor cero. El circuito NO comprueba el Merkle path si `v_old = 0` (permite el spend dummy sin que exista tal nota).

**Padding — NO es consenso, es política de wallet.** El builder rellena a mínimo **2 acciones** por defecto (`DEFAULT_MIN_ACTIONS = 2`). El nº de acciones es `max(max(spends, outputs), 2)`, **no** `spends+outputs` (spend real y output real comparten acción — ahí está el ahorro vs Sapling). Coinbase **nunca** se rellena.
**Riesgo si ZEROX no rellena o permite n=1**: se pierde la propiedad de arity-hiding, y es irreversible retroactivamente. No es consensus-critical pero sí privacy-critical.

## 3 · El bundle completo

`n=0` → el bundle son 1 byte (`CompactSize(0)`).

| # | campo | notas |
|---|---|---|
| 1 | `nActionsOrchard` (CompactSize) | MUST `< 2^16` |
| 2 | `vActionsOrchard` (820·n) | |
| 3 | `flagsOrchard` (1 B) | §4 |
| 4 | `valueBalanceOrchard` (i64 LE) | |
| 5 | `anchorOrchard` (32 B) | §5 |
| 6 | `sizeProofsOrchard` (CompactSize) | **valor obligatorio: `2720 + 2272·n`** |
| 7 | `proofsOrchard` | prueba Halo2 **agregada**, una sola para todas las acciones |
| 8 | `vSpendAuthSigsOrchard` (64·n) | **SIN prefijo de longitud** (implícita de n) |
| 9 | `bindingSigOrchard` (64 B) | §6 |

**3 trampas de orden:**
1. `spendAuthSig` NO va dentro de la Action — va DESPUÉS de la prueba, en array separado, correspondencia posicional.
2. `proofsOrchard` lleva CompactSize propio; `vSpendAuthSigsOrchard` NO.
3. `nActionsOrchard` va antes de todo, incluidos los flags.

## 3b · ⚠️ CVE real: GHSA-2x4w-pxqw-58v9 — longitud de prueba no validada

Antes de NU6.2, `sizeProofsOrchard` no se validaba como regla de consenso. El verificador Halo2 lee un nº fijo de bytes e **ignora el resto** → cualquiera podía rellenar `proofsOrchard` con basura arbitraria sin invalidar la tx. Como `proofsOrchard` es *authorizing data* (no entra en el txid), **el txid no cambiaba**. Resultado: **coste ilimitado de banda/disco, gratis, sin cambiar la identidad de la tx.**

Fix, ahora regla de consenso: `sizeProofsOrchard` **MUST** = `2720 + 2272·nActionsOrchard`.

**→ ZEROX debe tener esta regla desde el día uno** (no tiene tx históricas que preservar, sin excusa de compatibilidad). Lección general: **todo campo de longitud variable que sea authorizing data necesita una longitud canónica exigida** — aplicar la misma lente al lado transparente (p.ej. `scriptSig`).

## 4 · Flags

1 byte: bit 0 = `enableSpendsOrchard`, bit 1 = `enableOutputsOrchard`, bits 2-7 reservados MUST cero.

⚠️ Matiz que se malinterpreta: el flag NO dice "sin spends", dice "las notas gastadas están garantizadas dummy" — la Action sigue existiendo, con su nullifier y **su spendAuthSig, que se sigue validando**.

Reglas: bits 2-7 cero · en coinbase `enableSpends` MUST ser 0 · si `n>0`, al menos uno de los dos MUST ser 1.

**Los dos motivos de existir:** (1) que la coinbase no pueda gastar del pool blindado (sin el flag es inaplicable, al fusionar spend+output); (2) **palanca de contención de desastre preinstalada** — si aparece una vulnerabilidad en un lado del circuito, poner el flag a 0 apaga ese lado sin hard-fork. → **Recomendado para ZEROX desde v1.1.**

⚠️ Aviso de versión: `orchard` `main` (post-NU6.3) reusa el bit 2 para `enableCrossAddress` de un pool nuevo. **ZEROX especifica Orchard vanilla v5: bits 2-7 reservados a cero, no arrastrar el bit 2.**

## 5 · El anchor

Raíz Merkle Sinsemilla, profundidad 32, 32 B. **Uno por bundle, no por acción** (a diferencia de Sapling v4).

⚠️ **No hay ventana de anchors aceptables — es ilimitada.** Cualquier raíz histórica de cualquier bloque anterior es válida para siempre (verificado en Zebra: multiset de anchors no-finalizados + column family con TODAS las raíces históricas finalizadas).

**Implicaciones directas para `zx-storage`/`zx-consensus`:**
1. El nodo debe persistir **toda** raíz histórica indefinidamente — no es caché, es estado de consenso. Column family nueva.
2. En reorg hay que **retirar** las raíces de bloques desconectados — **tercer eje de estado a revertir**, junto al UTXO set y el nullifier set.
3. La ventana (`min_confirmations`) es política de **wallet**, no de consenso — trade-off robustez-a-reorg vs frescura del anonymity set.
4. Caso borde sin resolver (**para D8**): un bundle shield-only sigue citando un anchor válido — Zebra lo exige incondicionalmente. La raíz del árbol vacío suele calificar, pero no está confirmado en lenguaje SPEC para ZEROX.

## 6 · Binding signature — el turnstile

Firma RedPallas sobre el SIGHASH completo. **La clave no va en la tx — se recalcula**: `bvk = Σcv_netᵢ ⊖ ValueCommit_0(valueBalance)`. Por homomorfía de Pedersen, si `Σv_netᵢ − valueBalance = 0`, `bvk` es commitment a cero y el firmante conoce su discrete log (`bsk = Σrcv_netᵢ`); si no, producir la firma rompería el binding de Pedersen.

**Esto ES el turnstile de `DECISIONES.md` §3.4.** Ata el `valueBalance` público (auditable) al agregado oculto → un bug de inflación queda contenido dentro del pool blindado y es detectable desde fuera.

⚠️ **Para D9**: el argumento de soundness demuestra `v* ≡ 0 (mod r_P)`; concluir `v*=0` sobre los enteros exige el acotamiento por rango, que depende de `n < 2^16` y del rango de `valueBalance` **de Zcash**. **ZEROX tiene tamaño de bloque y MAX_MONEY distintos → el argumento de no-overflow hay que re-derivarlo con los números de ZEROX, no copiarlo.**

## 7 · Integración con ZIP-244 (5 personalizaciones que faltaban en `zip244.md`)

`ZTxIdOrchardHash`, `ZTxIdOrcActCHash`, `ZTxIdOrcActMHash`, `ZTxIdOrcActNHash` (txid), `ZTxAuthOrchaHash` (auth).

- `nActionsOrchard` y `sizeProofsOrchard` **NO se hashean en ninguna parte** — mismo patrón que "los contadores no se hashean" de `zip244.md`. Es justo lo que hacía explotable el CVE de §3b: rellenar la prueba cambia el auth digest/wtxid pero no el txid.
- ⚠️ **`anchorOrchard` está en el TXID digest (T.4f) en v5.** En v6/Ironwood se **mueve** al auth digest. **ZEROX sigue la semántica v5: anchor en el txid.** Confirma y amplía la trampa C2 de `zip244.md`: no es solo la personalización lo que cambia en v6, es la posición del anchor.

## 8 · Tamaño — verificado contra mainnet real

Fórmula (tx solo-Orchard, `1≤n≤27`): `tamaño = 2853 + 3156·n` (formato Zcash v5, con cabeceras Sapling vacías) · `2851 + 3156·n` para ZEROX sin sección Sapling.

| n | Zcash v5 | ZEROX |
|---|---|---|
| 2 | **9165** (100/100 verificado en Blockchair) | 9163 |

**Marginal por acción: 3156 B** = 820 wire + 2272 prueba + 64 firma.

⚠️ **Corrección a `DECISIONES.md` §4.3**: dice "tx ~3-10× más grandes" — cierto para tx blindada vs transparente-multi-input, pero para el **pago simple** (≈250 B Ed25519 vs ≈9165 B) el factor real es **~37×**. Corregir, porque es input directo al umbral `X` de visibilidad por monto y al presupuesto de bloque.

## 9 · ⚠️ Suelo de versión del crate — bug de soundness real (falsificación invisible)

**`orchard < 0.14.0` tiene un bug de soundness en `halo2_gadgets` que podía permitir "balance violation" = falsificación de moneda invisible.** Exactamente el riesgo que D1 existe para prevenir. Fix en `halo2_gadgets 0.5.0` / `orchard 0.14.0`.

**ZEROX ya pinea `orchard = "=0.15.5"` — correcto, no requiere cambio.** Razón adicional para 0.15.x sobre 0.14.x: enforcement de proof-size derivado de la versión del bundle (no un parámetro que se pueda pasar mal) + rechazo de `rk` identidad y `epk` inválido incorporados.

**Nunca usar `OrchardCircuitVersion::InsecurePreNu6_2`** — el crate la mantiene solo para verificar tx históricas de Zcash; ZEROX no tiene ninguna.

**Pinear también con `=`** (no caret): `halo2_proofs`, `halo2_gadgets`, `pasta_curves`, `reddsa`, `incrementalmerkletree`. El `Cargo.lock` no basta si algún crate de ZEROX se usa como librería.

### Dos reglas de consenso recientes (abril 2026), no en ZIP-224/225

1. **`rk` MUST NOT ser el punto identidad** — sin esto, un panic remoto durante verificación de prueba tumbaba nodos (crash remoto de todos los nodos).
2. **`ephemeralKey` MUST decodificar a un punto Pallas válido no-identidad** — fue un **split de consenso real**: zcashd lo aceptaba, Zebra lo rechazaba.

`Action::from_parts` del crate ya las impone (`Result`) — si ZEROX construye Actions solo por esa vía, sale gratis. **Pero el parser debe rechazar la tx, no hacer panic.** Nota de asimetría: `cv` SÍ puede ser el punto cero.

## Riesgos, por severidad

1. Circuito pre-NU6.2 → violación de balance = **falsificación de moneda invisible** (mitigado: ya pineamos 0.15.5)
2. `sizeProofsOrchard` no canónico → coste ilimitado de banda/disco sin cambiar txid
3. Orden de campos mal → fork inmediato (falla ruidoso, se detecta en tests)
4. Anchor en digest equivocado (copiar semántica v6) → txid mal en toda la cadena, silencioso
5. No persistir/revertir anchors históricos → fork no determinista dependiente del orden de sync — **el peor de depurar**
6. `rk`/`epk` inválidos no rechazados → panic remoto o consensus split
7. No rellenar a 2 acciones → pérdida irreversible de arity hiding (no es fork, es privacidad)

## Para D8 (18 vectores concretos de ataque)

Reordenar cv↔nullifier · proof +1 byte / +1MB · flags con bit reservado · flags=0 con n>0 · coinbase con enableSpends=1 o valueBalance>0 · rk=0 / epk=0 · epk fuera de rango · cmx/nullifier ≥ q_P · cv=punto cero (debe aceptarse) · CompactSize no mínimo · anchor de bloque reorganizado · anchor de árbol vacío en shield-only · anchor de bloque futuro · nullifier duplicado entre acciones · reordenar spendAuthSigs · n=0 con bytes sobrantes · n=65536.

## Lagunas (para D9 y trabajo futuro)

- Argumento de no-overflow de la binding sig **con los parámetros de ZEROX** (MAX_MONEY, tamaño de bloque, n máximo) — no transferible de Zcash, hay que re-derivarlo.
- Derivación del nullifier (`DeriveNullifier_nk`) y su unicidad — no verificada. Si está mal, permite doble gasto.
- Parámetros de Sinsemilla/ValueCommit (generadores, personalización, MerkleCRH) — se adoptan del crate sin tocar, no reimplementar.
- Comportamiento exacto del builder para el anchor de un bundle shield-only — confirmado que Zebra lo valida incondicionalmente y que existe `Anchor::empty_tree()`, pero no trazado el camino del builder.
- Jerarquía de claves ZIP-32 Orchard, direcciones diversificadas, KDF de note encryption — fuera de esta consulta, necesarias para Fase 6.
