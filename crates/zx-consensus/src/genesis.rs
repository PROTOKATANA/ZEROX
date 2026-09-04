//! Bloque génesis (SPEC §15).
//!
//! # Definición constructiva, no bytes hardcodeados
//!
//! El génesis se construye con una función determinista de parámetros explícitos, y su hash se
//! compara contra una constante. Es el patrón de Bitcoin y Zcash, y se eligió sobre el de Monero
//! —transacción coinbase en hexadecimal crudo— por dos razones: es **auditable**, porque se ve de
//! qué parámetros sale, y **falla duro y visible** si alguien toca un parámetro sin recalcular el
//! hash, en lugar de arrancar en silencio sobre un génesis no intencionado.
//!
//! # 🔴 Los parámetros de mainnet están BLOQUEADOS — P-017
//!
//! El mensaje, el timestamp y el nonce se fijan **el día del lanzamiento**, porque C-GEN-05 exige
//! que el mensaje referencie un evento público verificable de esa fecha. Lo que hay aquí es la
//! **maquinaria**, ya probada, con parámetros de marcador de posición explícitos.

use zx_core::amount::Amount;
use zx_core::digest::{BlockHash, Digest, TxId};
use zx_core::firma::ClavePublica;
use zx_core::preimage::block::{BlockHeader, merkle_root};
use zx_core::preimage::tx::txid;
use zx_core::target::{CompactBits, TARGET_INICIAL_BITS};
use zx_core::tx::{Lock, Tx, TxOut};

use crate::activacion::{Red, rama_activa};
use crate::error::ConsensusError;
use crate::validacion::VERSION_TX;

/// Parámetros de los que se construye un génesis (C-GEN-01).
///
/// Que sean explícitos es el punto: cualquiera puede reconstruir el bloque y comprobar el hash.
#[derive(Clone, Copy, Debug)]
pub struct ParametrosGenesis {
    /// Red a la que pertenece.
    pub red: Red,
    /// Mensaje simbólico de la coinbase (C-GEN-05).
    ///
    /// **No tiene función de consenso** — ningún nodo inspecciona su contenido. Su valor es una
    /// comprobación humana, manual y única: que referencie un evento público de la fecha permite a
    /// cualquiera concluir que el bloque no pudo minarse antes.
    ///
    /// Para ZEROX pesa más que en la mayoría de cadenas, porque el proyecto declara "sin premine".
    /// El precedente es Bytecoin, del que Monero nació como fork limpio tras concluirse que ~80 %
    /// del suministro existía antes del lanzamiento anunciado, con timestamps fabricados.
    pub mensaje: &'static [u8],
    /// Segundos Unix del lanzamiento.
    pub timestamp: u64,
    /// Nonce. No hay PoW que resolver (C-GEN-02), así que su única función es separar redes.
    pub nonce: u64,
}

/// 🔴 **P-017.** Parámetros de mainnet — marcador de posición hasta el día del lanzamiento.
pub const GENESIS_MAINNET: ParametrosGenesis = ParametrosGenesis {
    red: Red::Mainnet,
    mensaje: b"PENDIENTE P-017: titular verificable de la fecha de lanzamiento",
    timestamp: 0,
    nonce: 0,
};

/// 🔴 **P-017.** Parámetros de testnet.
///
/// **MUST** producir un hash distinto al de mainnet (C-GEN-04). Aquí lo garantizan el mensaje y el
/// nonce; el prefijo mágico de C-NET-01 hace el resto del aislamiento.
pub const GENESIS_TESTNET: ParametrosGenesis = ParametrosGenesis {
    red: Red::Testnet,
    mensaje: b"PENDIENTE P-017: testnet de ZEROX",
    timestamp: 0,
    nonce: 1,
};

/// Coinbase del génesis: **valor cero** (C-GEN-03, C-EMIT-02).
///
/// Sus salidas **MUST NOT** insertarse en el UTXO set. No es que gastarlas esté prohibido por una
/// regla: es que nunca existen. Bitcoin hace lo mismo con un caso especial en `ConnectBlock`.
///
/// El mensaje viaja en el `lock` de una salida de valor cero. Es inconectable por C-GEN-03, así que
/// no crea un UTXO no gastable — simplemente no llega al conjunto.
#[must_use]
pub fn coinbase_genesis(mensaje: &[u8]) -> Tx {
    // El mensaje se compacta a 32 bytes con XOR por posición. No es criptográfico ni pretende
    // serlo: el mensaje íntegro vive en los parámetros, que son públicos y reproducibles.
    //
    // Los 32 bytes ocupan el hueco de una clave pública, y casi con certeza NO son una clave válida
    // — que es justo lo que se quiere: la salida es inconectable por C-GEN-03 y además nadie tiene
    // la privada. Con P2K (P-020) esto es más honesto que antes: ya no finge ser el hash de una
    // clave que existe en alguna parte.
    let mut marca = [0u8; 32];
    for (i, b) in mensaje.iter().enumerate() {
        if let Some(d) = marca.get_mut(i % 32) {
            *d ^= *b;
        }
    }
    Tx {
        version: VERSION_TX,
        inputs: vec![],
        outputs: vec![TxOut {
            value: Amount::CERO,
            lock: Lock::PubKey {
                pubkey: ClavePublica::desde_bytes(marca),
            },
        }],
        lock_time: 0,
        // C-EMIT-04: la coinbase declara su altura. El génesis está en la 0.
        expiry_height: 0,
    }
}

/// Construye el bloque génesis a partir de sus parámetros (C-GEN-01).
///
/// # Errores
/// [`ConsensusError::SinRamaActiva`] si la tabla de ramas de la red está mal formada.
pub fn construir(p: ParametrosGenesis) -> Result<(BlockHeader, Tx), ConsensusError> {
    let cb = coinbase_genesis(p.mensaje);
    let branch_id = rama_activa(p.red, 0)?;
    let raiz = merkle_root(&[txid(&cb, branch_id)]);

    Ok((
        BlockHeader {
            consensus_branch_id: branch_id,
            // El génesis no tiene padre. Cero es el único valor con significado aquí.
            prev_hash: BlockHash::from_digest(Digest::from_bytes([0u8; 32])),
            merkle_root: raiz,
            timestamp: p.timestamp,
            bits: TARGET_INICIAL_BITS,
            nonce: p.nonce,
            height: 0,
        },
        cb,
    ))
}

/// Comprueba que un génesis construido cumple todas las invariantes de §15.
///
/// Es lo que C-GEN-01 pide que aborte el arranque: se llama al inicializar el nodo, antes de tocar
/// nada más.
///
/// **No comprueba el PoW**: C-GEN-02 lo exime explícitamente. Es una exención estructural, igual
/// que la de Bitcoin en `AcceptBlockHeader`, y no depende de que el génesis satisfaga o no su
/// propio target.
///
/// # Errores
/// [`ConsensusError::GenesisInvalido`] con el motivo concreto.
pub fn comprobar(cabecera: &BlockHeader, coinbase: &Tx) -> Result<(), ConsensusError> {
    let malo = |motivo| ConsensusError::GenesisInvalido { motivo };

    if cabecera.height != 0 {
        return Err(malo("C-HDR-02: el génesis MUST estar en la altura 0"));
    }
    if *cabecera.prev_hash.as_bytes() != [0u8; 32] {
        return Err(malo("el génesis no tiene padre: prev_hash MUST ser cero"));
    }
    if !coinbase.inputs.is_empty() {
        return Err(malo("C-BLK-07: la coinbase no tiene entradas"));
    }
    if coinbase.expiry_height != 0 {
        return Err(malo(
            "C-EMIT-04: la coinbase del génesis declara la altura 0",
        ));
    }
    // C-GEN-03 · valor cero. Sin premine, sin dev tax, sin founder reward.
    let total: i64 = coinbase.outputs.iter().map(|s| s.value.brek()).sum();
    if total != 0 {
        return Err(malo(
            "C-GEN-03/C-EMIT-02: la coinbase del génesis MUST valer cero",
        ));
    }
    // La raíz de Merkle compromete esa coinbase y no otra.
    if merkle_root(&[txid(coinbase, cabecera.consensus_branch_id)]) != cabecera.merkle_root {
        return Err(malo(
            "C-BLK-01: la raíz de Merkle no compromete esta coinbase",
        ));
    }
    // `bits` MUST ser canónico y estar en rango, aunque el PoW no se compruebe.
    CompactBits::from_u32(cabecera.bits)
        .decodificar()
        .map_err(|_| malo("C-POW-04: los bits del génesis no son canónicos"))?;
    Ok(())
}

/// Hash del génesis de una red, tal y como se hardcodearía para la aserción de C-GEN-01.
///
/// # Errores
/// La de [`construir`].
pub fn hash(p: ParametrosGenesis) -> Result<BlockHash, ConsensusError> {
    Ok(construir(p)?.0.block_hash())
}

/// El txid de la coinbase del génesis, que **MUST NOT** entrar en el UTXO set (C-GEN-03).
///
/// Se expone para que la capa de estado pueda comprobar explícitamente que no está, en vez de
/// confiar en que nadie la insertó.
///
/// # Errores
/// La de [`construir`].
pub fn txid_coinbase(p: ParametrosGenesis) -> Result<TxId, ConsensusError> {
    let (cab, cb) = construir(p)?;
    Ok(txid(&cb, cab.consensus_branch_id))
}

#[cfg(test)]
#[expect(
    clippy::unwrap_used,
    clippy::panic,
    reason = "los tests fallan con panic por diseño"
)]
mod tests {
    use super::{
        GENESIS_MAINNET, GENESIS_TESTNET, coinbase_genesis, comprobar, construir, hash,
        txid_coinbase,
    };
    use crate::activacion::Red;
    use crate::error::ConsensusError;
    use zx_core::amount::Amount;
    use zx_core::digest::{BlockHash, Digest};
    use zx_core::target::TARGET_INICIAL_BITS;

    #[test]
    fn el_genesis_construido_es_valido() {
        for p in [GENESIS_MAINNET, GENESIS_TESTNET] {
            let (cab, cb) = construir(p).unwrap();
            comprobar(&cab, &cb).unwrap_or_else(|e| panic!("{:?}: {e}", p.red));
        }
    }

    #[test]
    fn el_genesis_esta_en_la_altura_cero_y_no_tiene_padre() {
        let (cab, _) = construir(GENESIS_MAINNET).unwrap();
        assert_eq!(cab.height, 0);
        assert_eq!(cab.prev_hash.as_bytes(), &[0u8; 32]);
        assert_eq!(cab.bits, TARGET_INICIAL_BITS, "C-DIFF-02");
    }

    /// **C-GEN-03 / C-EMIT-02.** Sin premine, sin dev tax, sin founder reward.
    #[test]
    fn la_coinbase_del_genesis_vale_cero() {
        let (_, cb) = construir(GENESIS_MAINNET).unwrap();
        let total: i64 = cb.outputs.iter().map(|s| s.value.brek()).sum();
        assert_eq!(total, 0, "el génesis MUST NOT crear valor");
        assert!(cb.inputs.is_empty(), "es coinbase");
    }

    /// Y se rechaza si alguien intenta colar valor.
    #[test]
    fn se_rechaza_un_genesis_con_premine() {
        let (cab, mut cb) = construir(GENESIS_MAINNET).unwrap();
        if let Some(s) = cb.outputs.first_mut() {
            s.value = Amount::nuevo(1).unwrap();
        }
        let e = comprobar(&cab, &cb).unwrap_err();
        assert!(matches!(e, ConsensusError::GenesisInvalido { .. }), "{e:?}");
        assert!(
            format!("{e}").contains("cero"),
            "el error debe nombrar la regla"
        );
    }

    /// **C-GEN-04.** Mainnet y testnet MUST producir hashes distintos.
    ///
    /// Sin esto, un bloque de una red podría ser el bloque 0 válido de la otra.
    #[test]
    fn mainnet_y_testnet_tienen_genesis_distintos() {
        let m = hash(GENESIS_MAINNET).unwrap();
        let t = hash(GENESIS_TESTNET).unwrap();
        assert_ne!(m, t, "C-GEN-04: los génesis de las dos redes MUST diferir");
        assert_ne!(
            txid_coinbase(GENESIS_MAINNET).unwrap(),
            txid_coinbase(GENESIS_TESTNET).unwrap(),
            "y sus coinbases también"
        );
    }

    /// El génesis es **determinista**: los mismos parámetros dan siempre el mismo hash. Es lo que
    /// permite la aserción de C-GEN-01.
    #[test]
    fn el_genesis_es_determinista() {
        let a = hash(GENESIS_MAINNET).unwrap();
        for _ in 0..5 {
            assert_eq!(hash(GENESIS_MAINNET).unwrap(), a);
        }
    }

    /// Cambiar **cualquier** parámetro cambia el hash. Es lo que hace útil la aserción: tocar algo
    /// sin recalcular el hash rompe el arranque en vez de pasar desapercibido.
    #[test]
    fn cada_parametro_cambia_el_hash_del_genesis() {
        let base = hash(GENESIS_MAINNET).unwrap();

        let mut p = GENESIS_MAINNET;
        p.mensaje = b"otro mensaje completamente distinto";
        assert_ne!(hash(p).unwrap(), base, "mensaje");

        let mut p = GENESIS_MAINNET;
        p.timestamp = 1;
        assert_ne!(hash(p).unwrap(), base, "timestamp");

        let mut p = GENESIS_MAINNET;
        p.nonce = 1;
        assert_ne!(hash(p).unwrap(), base, "nonce");
    }

    /// C-BLK-01: la raíz de Merkle compromete esa coinbase y no otra.
    #[test]
    fn una_coinbase_cambiada_invalida_el_genesis() {
        let (cab, _) = construir(GENESIS_MAINNET).unwrap();
        let otra = coinbase_genesis(b"una coinbase que no es la del genesis");
        assert!(matches!(
            comprobar(&cab, &otra),
            Err(ConsensusError::GenesisInvalido { .. })
        ));
    }

    #[test]
    fn se_rechaza_un_genesis_con_padre() {
        let (mut cab, cb) = construir(GENESIS_MAINNET).unwrap();
        cab.prev_hash = BlockHash::from_digest(Digest::from_bytes([1u8; 32]));
        assert!(comprobar(&cab, &cb).is_err());
    }

    #[test]
    fn se_rechaza_un_genesis_fuera_de_la_altura_cero() {
        let (mut cab, cb) = construir(GENESIS_MAINNET).unwrap();
        cab.height = 1;
        assert!(comprobar(&cab, &cb).is_err());
    }

    /// **C-GEN-02: el génesis NO pasa por la comprobación de PoW.**
    ///
    /// Su nonce es 0 y no resuelve nada, y aun así `comprobar` lo acepta. La exención es
    /// estructural —igual que en Bitcoin—, no depende de que el génesis satisfaga su propio target.
    #[test]
    fn el_genesis_no_necesita_resolver_el_pow() {
        let (cab, cb) = construir(GENESIS_MAINNET).unwrap();
        assert_eq!(cab.nonce, 0, "sin minar");

        let target = zx_core::target::CompactBits::from_u32(cab.bits)
            .decodificar()
            .unwrap();
        let cumple = zx_core::target::cumple_pow(&cab.block_hash(), target);
        // No se afirma que NO lo cumpla —podría cumplirlo por azar con probabilidad 2⁻³²—, sino que
        // `comprobar` no lo mira.
        let _ = cumple;
        assert!(comprobar(&cab, &cb).is_ok(), "C-GEN-02: exento del PoW");
    }

    /// Las dos redes usan la rama de consenso activa a la altura 0.
    #[test]
    fn el_genesis_declara_la_rama_activa() {
        for (p, red) in [
            (GENESIS_MAINNET, Red::Mainnet),
            (GENESIS_TESTNET, Red::Testnet),
        ] {
            let (cab, _) = construir(p).unwrap();
            assert_eq!(
                cab.consensus_branch_id,
                crate::activacion::rama_activa(red, 0).unwrap()
            );
        }
    }
}
