//! **Identificadores cortos de transacción para el relé compacto** (C-NET-07, BIP 152).
//!
//! Un bloque compacto no manda las transacciones: manda seis bytes por cada una, y el receptor las
//! busca en su mempool. Seis bytes bastan porque el emisor y el receptor comparten casi todo el
//! mempool; lo que no cuadre se pide entero.
//!
//! ⚠️ **Esto es solo la derivación del identificador.** La reconstrucción del bloque, la
//! recuperación de colisiones y el anuncio compacto en sí no están implementados: son el resto de
//! BIP 152, y siguen declarados como pendientes en `ci/reglas-sin-codigo.txt`. Se cita aquí solo
//! la regla que este archivo cumple.
//!
//! # Por qué el nonce no es decorativo
//!
//! Las claves de SipHash salen del hash de la cabecera **con un nonce que elige el emisor**. Cita
//! del BIP: *«by using the block hash as a key to SipHash, an attacker cannot predict what keys
//! will be used […] so that even block creators cannot control where collisions occur»*.
//!
//! Sin él, un minero podría fabricar transacciones que colisionen con las del mempool ajeno y
//! degradar la propagación de la red entera. Con él, las claves cambian por anuncio y nadie puede
//! apuntar a nada.
//!
//! # La trampa de BIP 152 que aquí no existe
//!
//! BIP 152 usa **SHA256 simple**, no doble, a diferencia del blockhash de Bitcoin. Quien lo
//! implemente "como el blockhash" produce identificadores incompatibles, y el síntoma es que los
//! bloques **nunca reconstruyen**, sin un solo error de protocolo — un fallo silencioso que se
//! confunde con un problema de red.
//!
//! ZEROX no hereda la trampa porque su hash de cabecera ya es **una sola pasada** de SHA3-256. Aun
//! así hay un test que lo fija, porque "no puede pasar aquí" es exactamente lo que alguien pensará
//! justo antes de cambiar la función de hash de cabecera.
//!
//! # SipHash no se reimplementa
//!
//! Se adopta `siphasher`. BIP 152 **no define** SipHash-2-4 —remite a Aumasson & Bernstein—, así
//! que es una primitiva externa con vectores oficiales y le corresponde el mismo trato que a
//! `sha3` o `ed25519-zebra`. Que no sea consensus-critical (un identificador mal derivado provoca
//! una re-petición, no un fork) no cambia la regla.

use std::hash::Hasher as _;

use siphasher::sip::SipHasher24;
use zx_core::digest::TxId;
use zx_core::preimage::block::{BlockHeader, TAMANO_CABECERA};
use zx_core::sha3_256_publico;
use zx_core::wire::cabecera_a_bytes;

/// Cuántos bytes mide un identificador corto.
///
/// Seis, como en BIP 152. Con `n` transacciones en el bloque y `m` en el mempool del receptor, la
/// probabilidad de al menos una colisión va como `n·m / 2⁴⁸`; para un bloque de 3000 y un mempool
/// de 30 000 son unas 3 · 10⁻⁴. Cuando ocurre se resuelve pidiendo la transacción entera, que es
/// la parte de BIP 152 que todavía no existe.
pub const TAMANO_ID_CORTO: usize = 6;

/// Un identificador corto: los 6 bytes bajos del SipHash.
pub type IdCorto = [u8; TAMANO_ID_CORTO];

/// Las dos claves de SipHash de un anuncio compacto, derivadas de la cabecera y el nonce.
///
/// Se calculan **una vez por bloque** y se reutilizan para todas sus transacciones: derivarlas por
/// transacción costaría un SHA3-256 por cada una, que es justo el trabajo que el relé compacto
/// existe para ahorrar.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct ClavesIdCorto {
    k0: u64,
    k1: u64,
}

impl ClavesIdCorto {
    /// Unas claves concretas, para vectores de respuesta conocida.
    ///
    /// La derivación normal es [`Self::derivar`]. Esto existe para poder comprobar nuestra
    /// llamada a SipHash contra los vectores oficiales de Aumasson & Bernstein, que vienen con sus
    /// claves dadas — sin ese contraste, usar `SipHasher13` en lugar de `SipHasher24`, o invertir
    /// el orden de las claves, produciría identificadores consistentes entre nosotros y distintos
    /// de los del resto del mundo. El síntoma sería que los bloques no reconstruyen nunca.
    #[must_use]
    pub const fn desde_claves(k0: u64, k1: u64) -> Self {
        Self { k0, k1 }
    }

    /// C-NET-07 · `h = SHA3-256(cabecera(92 B) ‖ nonce(8 B LE))`, y de ahí las dos claves.
    #[must_use]
    pub fn derivar(cabecera: &BlockHeader, nonce: u64) -> Self {
        let mut entrada = [0u8; TAMANO_CABECERA + 8];
        // La cabecera son los MISMOS bytes que viajan y que se hashean (C-WIRE-01), no una
        // segunda serialización escrita para esto. Si hubiera dos, podrían divergir.
        let (cab, resto) = entrada.split_at_mut(TAMANO_CABECERA);
        cab.copy_from_slice(&cabecera_a_bytes(cabecera));
        resto.copy_from_slice(&nonce.to_le_bytes());

        let h = sha3_256_publico(&entrada);
        let b = h.as_bytes();
        // `expect` no: los índices son constantes y el digest mide 32 bytes, pero el workspace
        // prohíbe el pánico en producción y un `unwrap_or` aquí no oculta nada — si el digest
        // cambiara de tamaño, el test de vectores lo cazaría antes.
        let leer = |desde: usize| -> u64 {
            let mut ocho = [0u8; 8];
            if let Some(t) = b.get(desde..desde + 8) {
                ocho.copy_from_slice(t);
            }
            u64::from_le_bytes(ocho)
        };
        Self {
            k0: leer(0),
            k1: leer(8),
        }
    }

    /// El identificador corto de una transacción bajo estas claves.
    #[must_use]
    pub fn id(&self, txid: &TxId) -> IdCorto {
        let mut h = SipHasher24::new_with_keys(self.k0, self.k1);
        h.write(txid.digest().as_bytes());
        let completo = h.finish().to_le_bytes();
        let mut id = [0u8; TAMANO_ID_CORTO];
        // Los 6 bytes BAJOS. En little-endian son los seis primeros del array.
        if let Some(t) = completo.get(..TAMANO_ID_CORTO) {
            id.copy_from_slice(t);
        }
        id
    }
}

#[cfg(test)]
#[expect(
    clippy::indexing_slicing,
    reason = "los índices son constantes sobre un digest de 32 bytes"
)]
mod tests {
    use super::{ClavesIdCorto, TAMANO_ID_CORTO};
    use std::hash::Hasher as _;
    use zx_core::digest::{BlockHash, Digest, MerkleRoot, TxId};
    use zx_core::preimage::block::{BlockHeader, TAMANO_CABECERA};

    fn cabecera(nonce: u64) -> BlockHeader {
        BlockHeader {
            // Literal a propósito, y es el único sitio del proyecto donde se acepta: `zx-p2p` no
            // puede depender de `zx-consensus` —lo vigila un job de CI— así que no hay `rama_activa`
            // que llamar. Da igual: el identificador corto se deriva de los BYTES de la cabecera,
            // sin interpretarlos, así que aquí cualquier valor sirve mientras sea estable.
            consensus_branch_id: 0xc478_80ea,
            prev_hash: BlockHash::from_digest(Digest::from_bytes([1; 32])),
            merkle_root: MerkleRoot::from_digest(Digest::from_bytes([2; 32])),
            timestamp: 1_788_480_120,
            bits: 0x1d00_ffff,
            nonce,
            height: 1,
        }
    }

    fn tx(n: u8) -> TxId {
        TxId::from_digest(Digest::from_bytes([n; 32]))
    }

    /// **Vectores oficiales de SipHash-2-4** — `veorq/SipHash`, `vectors.h`, la implementación de
    /// referencia de Aumasson & Bernstein.
    ///
    /// Clave `00 01 02 … 0f`, entradas de longitud creciente empezando por la vacía. Esto no prueba
    /// SipHash —de eso responde el crate— sino **nuestra llamada**: que sea 2-4 y no 1-3, que las
    /// dos mitades de la clave vayan en el orden correcto, y que la salida se lea en
    /// little-endian. Equivocarse en cualquiera de las tres produce identificadores consistentes
    /// entre nosotros e incompatibles con todo lo demás, y el síntoma sería que los bloques no
    /// reconstruyen nunca — sin un solo error de protocolo.
    #[test]
    fn nuestra_llamada_a_siphash_da_los_vectores_oficiales() {
        use siphasher::sip::SipHasher24;

        let k0 = u64::from_le_bytes([0, 1, 2, 3, 4, 5, 6, 7]);
        let k1 = u64::from_le_bytes([8, 9, 10, 11, 12, 13, 14, 15]);

        let esperados: [(usize, [u8; 8]); 3] = [
            (0, [0x31, 0x0e, 0x0e, 0xdd, 0x47, 0xdb, 0x6f, 0x72]),
            (1, [0xfd, 0x67, 0xdc, 0x93, 0xc5, 0x39, 0xf8, 0x74]),
            (2, [0x5a, 0x4f, 0xa9, 0xd9, 0x09, 0x80, 0x6c, 0x0d]),
        ];
        for (largo, esperado) in esperados {
            let entrada: Vec<u8> = (0..largo).map(|i| i as u8).collect();
            let mut h = SipHasher24::new_with_keys(k0, k1);
            h.write(&entrada);
            assert_eq!(
                h.finish().to_le_bytes(),
                esperado,
                "vector oficial de longitud {largo}"
            );
        }
    }

    /// El identificador son los **6 bytes bajos** de ese mismo valor.
    #[test]
    fn el_id_son_los_seis_bytes_bajos() {
        use siphasher::sip::SipHasher24;
        let claves = ClavesIdCorto::desde_claves(0x0706_0504_0302_0100, 0x0f0e_0d0c_0b0a_0908);
        let t = tx(0xab);

        let mut h = SipHasher24::new_with_keys(0x0706_0504_0302_0100, 0x0f0e_0d0c_0b0a_0908);
        h.write(t.digest().as_bytes());
        let completo = h.finish().to_le_bytes();

        assert_eq!(claves.id(&t), completo[..TAMANO_ID_CORTO]);
    }

    /// Determinista: el mismo bloque y la misma transacción dan siempre el mismo identificador.
    #[test]
    fn es_determinista() {
        let c = ClavesIdCorto::derivar(&cabecera(7), 42);
        assert_eq!(c.id(&tx(1)), c.id(&tx(1)));
        assert_eq!(ClavesIdCorto::derivar(&cabecera(7), 42), c);
    }

    /// **El nonce no es decorativo** (C-NET-07).
    ///
    /// Cambiarlo cambia las claves y, con ellas, todos los identificadores. Es lo que impide que
    /// nadie —ni siquiera quien mina el bloque— pueda predecir dónde caerán las colisiones y
    /// fabricar transacciones que degraden la propagación de la red entera.
    #[test]
    fn cambiar_el_nonce_cambia_todos_los_identificadores() {
        let a = ClavesIdCorto::derivar(&cabecera(7), 1);
        let b = ClavesIdCorto::derivar(&cabecera(7), 2);
        assert_ne!(a, b, "otro nonce, otras claves");

        let distintos = (0u8..32).filter(|n| a.id(&tx(*n)) != b.id(&tx(*n))).count();
        assert_eq!(
            distintos, 32,
            "con claves distintas los 32 identificadores deben cambiar; coincidir sería una \
             colisión de 6 bytes, que a esta escala no pasa por azar"
        );
    }

    /// Cambiar la cabecera también cambia las claves, aunque el nonce sea el mismo.
    #[test]
    fn cambiar_la_cabecera_cambia_las_claves() {
        let mut otra = cabecera(7);
        otra.timestamp += 1;
        assert_ne!(
            ClavesIdCorto::derivar(&cabecera(7), 1),
            ClavesIdCorto::derivar(&otra, 1)
        );
    }

    /// **La trampa de BIP 152: una pasada de hash, no dos.**
    ///
    /// BIP 152 usa SHA256 *simple*, a diferencia del blockhash de Bitcoin, que es doble. Quien lo
    /// implemente "como el blockhash" produce identificadores incompatibles y los bloques no
    /// reconstruyen jamás, **sin ningún error de protocolo** — se confunde con un problema de red.
    ///
    /// Aquí no puede pasar porque el hash de cabecera de ZEROX ya es una sola pasada. Este test
    /// lo fija de todos modos, porque "no puede pasar aquí" es exactamente lo que alguien pensará
    /// justo antes de cambiar la función de hash de cabecera.
    #[test]
    fn una_pasada_de_sha3_no_dos() {
        use zx_core::sha3_256_publico;
        use zx_core::wire::cabecera_a_bytes;

        let cab = cabecera(7);
        let nonce = 42u64;
        let mut entrada = Vec::with_capacity(TAMANO_CABECERA + 8);
        entrada.extend_from_slice(&cabecera_a_bytes(&cab));
        entrada.extend_from_slice(&nonce.to_le_bytes());
        assert_eq!(entrada.len(), 100, "92 de cabecera y 8 de nonce");

        let una = sha3_256_publico(&entrada);
        let dos = sha3_256_publico(una.as_bytes());

        let leer = |b: &[u8; 32], d: usize| {
            let mut o = [0u8; 8];
            o.copy_from_slice(&b[d..d + 8]);
            u64::from_le_bytes(o)
        };
        let esperadas =
            ClavesIdCorto::desde_claves(leer(una.as_bytes(), 0), leer(una.as_bytes(), 8));
        let dobles = ClavesIdCorto::desde_claves(leer(dos.as_bytes(), 0), leer(dos.as_bytes(), 8));

        assert_eq!(
            ClavesIdCorto::derivar(&cab, nonce),
            esperadas,
            "las claves salen de UNA pasada sobre cabecera ‖ nonce"
        );
        assert_ne!(esperadas, dobles, "y la doble pasada daría otras distintas");
    }
}
