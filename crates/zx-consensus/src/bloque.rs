//! Validez de bloque (SPEC §6.4).
//!
//! Es donde converge todo lo demás: PoW, dificultad, timestamps, peso, emisión y validez de cada
//! transacción. Un bloque válido es el que sobrevive a las nueve comprobaciones de aquí.
//!
//! # Lo que este módulo NO hace
//!
//! No calcula el target esperado ni las medianas: eso exige recorrer ventanas de hasta 262 800
//! bloques y es responsabilidad del llamante, que tiene el estado. Se le pasan ya calculados en
//! [`ContextoBloque`].
//!
//! ⚠️ Y con una obligación: **esas ventanas MUST leerse sobre la cadena candidata** (C-REORG-06), no
//! sobre la activa. A la misma altura, las dos ramas tienen bloques distintos. Si el llamante cachea
//! el resultado, la clave **MUST** ser el hash del tip (C-REORG-05, [`crate::fork_choice::ClaveVentana`]).

use primitive_types::U256;
use zx_core::preimage::block::BlockHeader;
use zx_core::preimage::tx::txid;
use zx_core::target::{CompactBits, cumple_pow};
use zx_core::tx::Tx;

use crate::activacion::{Red, comprobar_branch_id};
use crate::emision::{recompensa_base, subsidio};
use crate::error::ConsensusError;
use crate::peso::{PesoValidado, limite};
use crate::timestamps::{comprobar_ftl, comprobar_monotonia};
use crate::validacion::{ConjuntoUtxo, comprobar_sin_doble_gasto_en_bloque, peso_tx, validar_tx};

/// Todo lo que la validación necesita saber del estado de la cadena.
///
/// Va explícito y no oculto tras un handle para que se vea de un vistazo **qué mira el consenso**.
/// Cualquier campo que se añada aquí entra en el consenso y tiene que pasar por el SPEC.
#[derive(Clone, Copy, Debug)]
pub struct ContextoBloque {
    /// Red, para la tabla de ramas y el prefijo mágico.
    pub red: Red,
    /// Target que exige el retarget a esta altura (C-BLK-05, C-DIFF-09).
    pub target_esperado: U256,
    /// Mediana efectiva `M(H)` (C-WGT-08), leída sobre la cadena candidata.
    pub mediana_efectiva: u64,
    /// Suma de subsidios efectivos de los bloques `0 .. H−1` (C-EMIT-01).
    pub emitido: u128,
    /// Timestamp del padre, para C-TS-01.
    pub ts_padre: i64,
    /// Reloj **local** del nodo, para C-TS-03. Nunca hora de red (C-TS-04).
    pub reloj_local: i64,
}

/// Un bloque tal y como llega, con sus testigos por transacción y por entrada.
pub struct Bloque<'a> {
    /// Cabecera.
    pub cabecera: BlockHeader,
    /// Transacciones, la primera de las cuales es la coinbase (C-BLK-07).
    pub txs: &'a [Tx],
    /// `testigos[i][j]` es el testigo de la entrada `j` de la transacción `i`. La coinbase no tiene
    /// entradas, así que su vector está vacío.
    pub testigos: &'a [Vec<Vec<u8>>],
}

/// Lo que se aprende al validar un bloque.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct BloqueValidado {
    /// Peso total (C-WGT-01).
    pub peso: u64,
    /// Suma de fees de las transacciones no coinbase.
    pub fees: u128,
    /// Subsidio efectivo tras la penalización (C-EMIT-06).
    pub subsidio: u128,
}

/// ¿Es esta transacción una coinbase? Lo es exactamente si no tiene entradas (C-EMIT-03).
#[must_use]
pub fn es_coinbase(tx: &Tx) -> bool {
    tx.inputs.is_empty()
}

/// Valida **solo la cabecera** (C-HDR-02b, C-BLK-04, C-BLK-05, C-BLK-06).
///
/// Separada de [`validar_cuerpo`] porque el sync **headers-first** valida cabeceras antes de
/// descargar los cuerpos: es la fase que permite descartar una cadena entera sin gastar banda en
/// megabytes de transacciones.
///
/// También es la barrera anti-DoS: un par hostil no debe poder obligarnos a verificar miles de
/// firmas antes de que descubramos que su cabecera no cumple el PoW.
///
/// # Errores
/// La variante de [`ConsensusError`] de la primera regla incumplida. Ojo con
/// [`ConsensusError::es_permanente`]: el rechazo por timestamp futuro **MUST NOT** cachearse.
pub fn validar_cabecera(
    cabecera: &BlockHeader,
    ctx: &ContextoBloque,
) -> Result<(), ConsensusError> {
    let altura = cabecera.height;

    // ── Cabecera. Barato, y descarta la mayoría de la basura. ────────────────

    // C-HDR-02b · rama de consenso correcta. Protección contra wipe-out.
    comprobar_branch_id(ctx.red, altura, cabecera.consensus_branch_id)?;

    // C-BLK-05 · `bits` MUST ser exactamente el del retarget, no "uno equivalente".
    let bits_esperados = CompactBits::codificar(ctx.target_esperado);
    if cabecera.bits != bits_esperados.to_u32() {
        return Err(ConsensusError::BitsIncorrectos {
            esperado: bits_esperados.to_u32(),
            encontrado: cabecera.bits,
        });
    }
    // Y MUST ser canónico y estar en rango (C-POW-04, C-POW-05).
    let target = CompactBits::from_u32(cabecera.bits)
        .decodificar()
        .map_err(|_| ConsensusError::BitsIncorrectos {
            esperado: bits_esperados.to_u32(),
            encontrado: cabecera.bits,
        })?;

    // C-BLK-06 · timestamps. El de futuro NO es permanente: ver `es_permanente()`.
    //
    // La cabecera lleva el timestamp en `u64` (§6.1, para no heredar el problema del año 2106) y la
    // aritmética de dificultad va en `i64` (C-DIFF-03, necesita signo para la reconstrucción
    // monótona). La conversión es **comprobada**, no un `as`: C-ENC-03 prohíbe el desbordamiento
    // silencioso, y un `as` convertiría un timestamp absurdo en uno negativo sin decir nada.
    let ts =
        i64::try_from(cabecera.timestamp).map_err(|_| ConsensusError::TimestampFueraDeRango {
            ts: cabecera.timestamp,
        })?;
    comprobar_monotonia(altura, ts, ctx.ts_padre)?;
    comprobar_ftl(ts, ctx.reloj_local)?;

    // C-BLK-04 · PoW. Después de `bits`, porque validar el PoW contra un target que no es el que
    // toca no demostraría nada.
    if !cumple_pow(&cabecera.block_hash(), target) {
        return Err(ConsensusError::PowInsuficiente);
    }

    Ok(())
}

/// Valida el **cuerpo** del bloque, dando la cabecera por ya validada (§6.4).
///
/// # Errores
/// La variante de [`ConsensusError`] de la primera regla incumplida.
pub fn validar_cuerpo<U: ConjuntoUtxo>(
    b: &Bloque<'_>,
    ctx: &ContextoBloque,
    utxos: &U,
) -> Result<BloqueValidado, ConsensusError> {
    let altura = b.cabecera.height;

    // ── Estructura. Barato. ──────────────────────────────────────────────────

    // C-BLK-07 · la primera es coinbase y ninguna otra lo es.
    let (coinbase, resto) = b
        .txs
        .split_first()
        .ok_or(ConsensusError::BloqueSinCoinbase)?;
    if !es_coinbase(coinbase) {
        return Err(ConsensusError::BloqueSinCoinbase);
    }
    if resto.iter().any(es_coinbase) {
        return Err(ConsensusError::CoinbaseFueraDeSitio);
    }
    if b.testigos.len() != b.txs.len() {
        return Err(ConsensusError::TestigoMalFormado {
            motivo: "MUST haber un vector de testigos por transacción",
        });
    }

    // C-EMIT-04 · unicidad del txid de coinbase. Sin esto, dos coinbases de alturas distintas con
    // las mismas salidas tendrían **el mismo txid**: el testigo no entra en el txid.
    if coinbase.expiry_height != altura {
        return Err(ConsensusError::CoinbaseSinAltura {
            altura,
            expiry_height: coinbase.expiry_height,
        });
    }

    // C-BLK-01..03 · la raíz de Merkle compromete estas transacciones y no otras.
    let cbid = b.cabecera.consensus_branch_id;
    let txids: Vec<_> = b.txs.iter().map(|t| txid(t, cbid)).collect();
    if zx_core::preimage::block::merkle_root(&txids) != b.cabecera.merkle_root {
        return Err(ConsensusError::MerkleRootIncorrecta);
    }

    // C-BLK-09 · ninguna transacción del bloque gasta lo que gastó otra.
    comprobar_sin_doble_gasto_en_bloque(b.txs)?;

    // ── Transacciones. Lo caro va al final. ──────────────────────────────────

    let testigos_coinbase = b.testigos.first().map_or(&[][..], Vec::as_slice);
    let mut peso_total = peso_tx(coinbase, testigos_coinbase);
    let mut fees: u128 = 0;

    for (i, tx) in resto.iter().enumerate() {
        let ws = b
            .testigos
            .get(i + 1)
            .ok_or(ConsensusError::TestigoMalFormado {
                motivo: "faltan testigos",
            })?;
        // C-BLK-08 · cada transacción, válida por sí misma.
        let v = validar_tx(tx, ws, utxos, altura)?;
        fees = fees
            .checked_add(u128::try_from(v.fee.brek()).unwrap_or(u128::MAX))
            .ok_or(ConsensusError::DesbordamientoAritmetico)?;
        peso_total = peso_total
            .checked_add(v.peso)
            .ok_or(ConsensusError::DesbordamientoAritmetico)?;
    }

    // C-BLK-10 / C-WGT-09 · el límite duro. Y el tipo que lo demuestra (C-WGT-10).
    let peso_validado = PesoValidado::comprobar(peso_total, limite(ctx.mediana_efectiva))?;

    // C-EMIT-01, C-EMIT-06, C-EMIT-07 · subsidio con el suelo de la cola aplicado ANTES de penalizar.
    let base = recompensa_base(ctx.emitido);
    let subsidio_efectivo = subsidio(base, peso_validado, ctx.mediana_efectiva)?;

    // C-EMIT-03 · la coinbase no puede cobrar más de lo que le toca.
    let salidas_coinbase = coinbase
        .outputs
        .iter()
        .try_fold(0u128, |acc, s| {
            u128::try_from(s.value.brek())
                .ok()
                .and_then(|v| acc.checked_add(v))
        })
        .ok_or(ConsensusError::DesbordamientoAritmetico)?;
    let maximo = subsidio_efectivo
        .checked_add(fees)
        .ok_or(ConsensusError::DesbordamientoAritmetico)?;
    if salidas_coinbase > maximo {
        return Err(ConsensusError::CoinbaseCobraDeMas {
            cobrado: salidas_coinbase,
            maximo,
        });
    }

    Ok(BloqueValidado {
        peso: peso_total,
        fees,
        subsidio: subsidio_efectivo,
    })
}

/// Valida un bloque completo: cabecera y cuerpo (§6.4).
///
/// El orden va **de lo barato a lo caro** y no es solo rendimiento: es anti-DoS.
///
/// # Errores
/// La variante de [`ConsensusError`] de la primera regla incumplida.
pub fn validar_bloque<U: ConjuntoUtxo>(
    b: &Bloque<'_>,
    ctx: &ContextoBloque,
    utxos: &U,
) -> Result<BloqueValidado, ConsensusError> {
    validar_cabecera(&b.cabecera, ctx)?;
    validar_cuerpo(b, ctx, utxos)
}

#[cfg(test)]
#[expect(clippy::unwrap_used, reason = "los tests fallan con panic por diseño")]
mod tests {
    use super::{Bloque, ContextoBloque, es_coinbase, validar_cabecera, validar_cuerpo};
    use crate::activacion::{RAMA_V1_MAINNET, Red};
    use crate::emision::recompensa_base;
    use crate::error::ConsensusError;
    use crate::peso::ZONA_LIBRE;
    use crate::validacion::{ConjuntoUtxo, EntradaUtxo, VERSION_TX};
    use zx_core::amount::Amount;
    use zx_core::digest::{BlockHash, Digest, MerkleRoot, TxId};
    use zx_core::preimage::block::{BlockHeader, merkle_root};
    use zx_core::preimage::tx::txid;
    use zx_core::target::{CompactBits, min_target, pow_limit};
    use zx_core::tx::{Lock, OutPoint, Tx, TxIn, TxOut};

    struct SinUtxos;
    impl ConjuntoUtxo for SinUtxos {
        fn buscar(&self, _: &OutPoint) -> Option<EntradaUtxo> {
            None
        }
    }

    /// # Por qué los tests del cuerpo no pasan por el PoW
    ///
    /// Incluso al target más fácil que el protocolo admite —`POW_LIMIT`— hace falta del orden de
    /// **2³² hashes** para encontrar un nonce válido. Es el diseño funcionando: ese target equivale
    /// a ~35,8 MH/s sostenidos.
    ///
    /// Minar eso en un test unitario no es viable, y bajar `POW_LIMIT` "solo para los tests" sería
    /// peor: una constante de consenso con un valor distinto en test que en producción es
    /// exactamente la clase de cosa que acaba filtrándose.
    ///
    /// Así que las reglas del cuerpo se prueban con [`validar_cuerpo`], y las de la cabecera con
    /// [`validar_cabecera`] sobre casos que fallan **antes** de llegar al PoW. Que el PoW se
    /// comprueba de verdad lo cubre un test propio —es trivial construir un bloque que **no** lo
    /// cumpla— y la corrección de la comparación en sí está en `zx-core::target`.
    fn ctx() -> ContextoBloque {
        ContextoBloque {
            red: Red::Mainnet,
            target_esperado: CompactBits::codificar(pow_limit()).decodificar().unwrap(),
            mediana_efectiva: ZONA_LIBRE,
            emitido: 0,
            ts_padre: 1_000,
            reloj_local: 1_000_000,
        }
    }

    fn coinbase(altura: u32, brek: i64) -> Tx {
        Tx {
            version: VERSION_TX,
            inputs: vec![],
            outputs: vec![TxOut {
                value: Amount::nuevo(brek).unwrap(),
                lock: Lock::PubKey {
                    pubkey_hash: [0xAA; 32],
                },
            }],
            lock_time: 0,
            expiry_height: altura, // C-EMIT-04
        }
    }

    /// Cabecera coherente con esas transacciones. **Sin minar**: no cumple el PoW.
    fn cabecera(altura: u32, txs: &[Tx]) -> BlockHeader {
        let cbid = RAMA_V1_MAINNET.id;
        let txids: Vec<_> = txs.iter().map(|t| txid(t, cbid)).collect();
        BlockHeader {
            consensus_branch_id: cbid,
            prev_hash: BlockHash::from_digest(Digest::from_bytes([0x01; 32])),
            merkle_root: merkle_root(&txids),
            timestamp: 2_000,
            bits: CompactBits::codificar(pow_limit()).to_u32(),
            nonce: 0,
            height: altura,
        }
    }

    fn bloque<'a>(h: &'a BlockHeader, txs: &'a [Tx], testigos: &'a [Vec<Vec<u8>>]) -> Bloque<'a> {
        Bloque {
            cabecera: *h,
            txs,
            testigos,
        }
    }

    // ── Estructura ───────────────────────────────────────────────────────────

    #[test]
    fn es_coinbase_es_no_tener_entradas() {
        assert!(es_coinbase(&coinbase(1, 100)));
        let mut con_entrada = coinbase(1, 100);
        con_entrada.inputs.push(TxIn {
            outpoint: OutPoint {
                prev_txid: TxId::from_digest(Digest::from_bytes([1; 32])),
                prev_index: 0,
            },
            sequence: 0,
        });
        assert!(!es_coinbase(&con_entrada));
    }

    #[test]
    fn un_bloque_solo_con_coinbase_valida() {
        let altura = 7;
        let base = recompensa_base(0);
        let txs = vec![coinbase(altura, i64::try_from(base).unwrap())];
        let h = cabecera(altura, &txs);
        let w = vec![vec![]];

        let v = validar_cuerpo(&bloque(&h, &txs, &w), &ctx(), &SinUtxos).unwrap();
        assert_eq!(v.fees, 0);
        assert_eq!(v.subsidio, base, "sin penalización: el bloque es diminuto");
    }

    /// **C-EMIT-03.** Un brek de más y el bloque es inválido.
    #[test]
    fn la_coinbase_no_puede_cobrar_de_mas() {
        let altura = 7;
        let base = i64::try_from(recompensa_base(0)).unwrap();
        let txs = vec![coinbase(altura, base + 1)];
        let h = cabecera(altura, &txs);
        let w = vec![vec![]];

        let e = validar_cuerpo(&bloque(&h, &txs, &w), &ctx(), &SinUtxos).unwrap_err();
        assert!(
            matches!(e, ConsensusError::CoinbaseCobraDeMas { .. }),
            "{e:?}"
        );
    }

    /// Cobrar **de menos** es legal: el minero puede renunciar a parte de su subsidio.
    #[test]
    fn la_coinbase_puede_cobrar_de_menos() {
        let altura = 7;
        let txs = vec![coinbase(altura, 1)];
        let h = cabecera(altura, &txs);
        let w = vec![vec![]];
        assert!(validar_cuerpo(&bloque(&h, &txs, &w), &ctx(), &SinUtxos).is_ok());
    }

    /// **C-EMIT-04.** Sin la altura en `expiry_height`, dos coinbases de alturas distintas tendrían
    /// el mismo txid.
    #[test]
    fn la_coinbase_debe_declarar_su_altura() {
        let altura = 7;
        let mut cb = coinbase(altura, 100);
        cb.expiry_height = altura + 1;
        let txs = vec![cb];
        let h = cabecera(altura, &txs);
        let w = vec![vec![]];

        let e = validar_cuerpo(&bloque(&h, &txs, &w), &ctx(), &SinUtxos).unwrap_err();
        assert!(
            matches!(e, ConsensusError::CoinbaseSinAltura { .. }),
            "{e:?}"
        );
    }

    /// La propiedad que C-EMIT-04 compra, comprobada directamente: dos coinbases de alturas
    /// distintas con **las mismas salidas** tienen txids distintos.
    #[test]
    fn dos_coinbases_de_alturas_distintas_no_colisionan() {
        let cbid = RAMA_V1_MAINNET.id;
        let a = coinbase(10, 500);
        let b = coinbase(11, 500);
        assert_eq!(a.outputs, b.outputs, "salidas idénticas a propósito");
        assert_ne!(
            txid(&a, cbid),
            txid(&b, cbid),
            "sin la altura en los datos de efecto, estos dos txid coincidirían"
        );
    }

    #[test]
    fn el_bloque_debe_empezar_por_la_coinbase() {
        let altura = 7;
        let txs: Vec<Tx> = vec![];
        let h = cabecera(altura, &txs);
        let w: Vec<Vec<Vec<u8>>> = vec![];
        assert!(matches!(
            validar_cuerpo(&bloque(&h, &txs, &w), &ctx(), &SinUtxos),
            Err(ConsensusError::BloqueSinCoinbase)
        ));
    }

    #[test]
    fn no_puede_haber_dos_coinbases() {
        let altura = 7;
        let txs = vec![coinbase(altura, 100), coinbase(altura, 100)];
        let h = cabecera(altura, &txs);
        let w = vec![vec![], vec![]];
        assert!(matches!(
            validar_cuerpo(&bloque(&h, &txs, &w), &ctx(), &SinUtxos),
            Err(ConsensusError::CoinbaseFueraDeSitio)
        ));
    }

    /// **C-BLK-01.** La raíz de Merkle compromete estas transacciones y no otras.
    #[test]
    fn una_raiz_de_merkle_que_no_cuadra_invalida() {
        let altura = 7;
        let txs = vec![coinbase(altura, 100)];
        let mut h = cabecera(altura, &txs);
        h.merkle_root = MerkleRoot::from_digest(Digest::from_bytes([0xFF; 32]));
        let w = vec![vec![]];
        assert!(matches!(
            validar_cuerpo(&bloque(&h, &txs, &w), &ctx(), &SinUtxos),
            Err(ConsensusError::MerkleRootIncorrecta)
        ));
    }

    /// Y cambiar una transacción sin recalcular la raíz también salta.
    #[test]
    fn cambiar_una_tx_sin_tocar_la_raiz_invalida() {
        let altura = 7;
        let originales = vec![coinbase(altura, 100)];
        let h = cabecera(altura, &originales);
        let alteradas = vec![coinbase(altura, 101)];
        let w = vec![vec![]];
        assert!(matches!(
            validar_cuerpo(&bloque(&h, &alteradas, &w), &ctx(), &SinUtxos),
            Err(ConsensusError::MerkleRootIncorrecta)
        ));
    }

    // ── Cabecera ─────────────────────────────────────────────────────────────

    /// C-BLK-05: `bits` MUST ser el del retarget, no "uno equivalente".
    #[test]
    fn los_bits_deben_ser_los_del_retarget() {
        let altura = 7;
        let txs = vec![coinbase(altura, 100)];
        let mut h = cabecera(altura, &txs);
        h.bits = CompactBits::codificar(pow_limit() / 2).to_u32();
        assert!(matches!(
            validar_cabecera(&h, &ctx()),
            Err(ConsensusError::BitsIncorrectos { .. })
        ));
    }

    /// C-HDR-02b: la protección contra *wipe-out*.
    #[test]
    fn un_branch_id_equivocado_invalida() {
        let altura = 7;
        let txs = vec![coinbase(altura, 100)];
        let mut h = cabecera(altura, &txs);
        h.consensus_branch_id = 0xDEAD_BEEF;
        assert!(matches!(
            validar_cabecera(&h, &ctx()),
            Err(ConsensusError::BranchIdIncorrecto { .. })
        ));
    }

    /// C-TS-01: el timestamp tiene que avanzar. Rechazo **permanente**.
    #[test]
    fn un_timestamp_que_no_avanza_invalida_permanentemente() {
        let altura = 7;
        let txs = vec![coinbase(altura, 100)];
        let h = cabecera(altura, &txs);
        let mut c = ctx();
        c.ts_padre = i64::try_from(h.timestamp).unwrap(); // igual, no mayor

        let e = validar_cabecera(&h, &c).unwrap_err();
        assert!(
            matches!(e, ConsensusError::TimestampNoMonotono { .. }),
            "{e:?}"
        );
        assert!(e.es_permanente(), "C-TS-01 es rechazo permanente");
    }

    /// **C-TS-03: el rechazo por futuro NO es permanente.**
    ///
    /// Es la diferencia que importa. Cachear como inválido un bloque que solo llegó pronto deja al
    /// nodo fuera de la cadena buena para siempre en cuanto su reloj se ponga al día.
    #[test]
    fn un_timestamp_futuro_es_rechazo_diferible() {
        let altura = 7;
        let txs = vec![coinbase(altura, 100)];
        let h = cabecera(altura, &txs);
        let mut c = ctx();
        c.reloj_local = 0;

        let e = validar_cabecera(&h, &c).unwrap_err();
        assert!(
            matches!(e, ConsensusError::TimestampDemasiadoFuturo { .. }),
            "{e:?}"
        );
        assert!(
            !e.es_permanente(),
            "C-TS-03: MUST NOT cachearse como inválido — se difiere y se reintenta"
        );
    }

    /// **C-BLK-04: el PoW se comprueba de verdad.**
    ///
    /// Con todo lo demás correcto, un nonce que no resuelve el target hace fallar la cabecera. Es
    /// la dirección fácil de probar: encontrar uno que **sí** lo resuelva exige ~2³² hashes.
    #[test]
    fn un_pow_insuficiente_invalida() {
        let altura = 7;
        let txs = vec![coinbase(altura, 100)];
        let h = cabecera(altura, &txs);
        // Un nonce cualquiera contra POW_LIMIT falla con probabilidad 1 − 2⁻³².
        let e = validar_cabecera(&h, &ctx()).unwrap_err();
        assert!(matches!(e, ConsensusError::PowInsuficiente), "{e:?}");
    }

    /// Y el PoW se comprueba **después** de `bits`: validar contra un target que no es el que toca
    /// no demostraría nada.
    #[test]
    fn los_bits_se_comprueban_antes_que_el_pow() {
        let altura = 7;
        let txs = vec![coinbase(altura, 100)];
        let mut h = cabecera(altura, &txs);
        h.bits = CompactBits::codificar(min_target()).to_u32();
        // Ambas reglas fallarían; MUST ganar la de `bits`.
        assert!(matches!(
            validar_cabecera(&h, &ctx()),
            Err(ConsensusError::BitsIncorrectos { .. })
        ));
    }
}
