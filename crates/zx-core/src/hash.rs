//! SHA3-256 con separación de dominio (SPEC §3).
//!
//! # Por qué casi nada de aquí es público
//!
//! La confusión más cara que se puede cometer en esta base de código es **hashear la serialización
//! de wire (Cap'n Proto) en lugar de la preimagen canónica de §4**. Las dos son secuencias de bytes
//! del mismo objeto; producen digests distintos; y el resultado sería un split de cadena silencioso.
//!
//! La defensa no es una convención ni un comentario: es la **ausencia de una firma invocable**.
//! [`h_d`] es `pub(crate)`, así que ningún crate de fuera puede llamarlo — ni queriendo. Y dentro de
//! `zx-core`, la única forma de alimentarlo es [`crate::preimage`], que se construye campo a campo
//! desde tipos de dominio y no acepta un buffer ya serializado.
//!
//! `zx-core` tampoco depende de `capnp`. No puede ni nombrar un tipo de wire.
//!
//! # Por qué un prefijo basta
//!
//! BLAKE2b tiene un campo de personalización en su *parameter block*; SHA3-256 no. Así que el
//! dominio va como **prefijo explícito de longitud fija** (C-HASH-04):
//!
//! ```text
//! H_d(tag, m) := SHA3-256( tag ‖ m )
//! ```
//!
//! Con **todas** las etiquetas midiendo exactamente 16 bytes, ninguna puede ser prefijo propio de
//! otra, así que la construcción es inyectiva sea cual sea la longitud de `m`. La longitud fija es
//! lo que hace el argumento, no la elección de caracteres.
//!
//! Y SHA-3 **no es vulnerable a extensión de longitud** —a diferencia de SHA-2—, así que el prefijo
//! simple es seguro sin necesidad de una construcción tipo HMAC. FIPS 202 §A.1 lo declara, y la
//! razón estructural es la esponja: la salida se exprime solo del *rate*, y los 512 bits de
//! *capacity* nunca se revelan.

// Todo este módulo lo consume `crate::preimage` (SPEC §4), que llega en la siguiente tanda. Hasta
// entonces solo lo tocan los tests. El `allow` es temporal y debe **retirarse** cuando `preimage`
// exista: si para entonces algo sigue sin usarse, es que sobra.
#![allow(
    dead_code,
    reason = "lo consumirá crate::preimage (§4), aún sin escribir"
)]

use sha3::{Digest as _, Sha3_256};

use crate::digest::Digest;

/// Etiqueta de dominio: exactamente 16 bytes (C-HASH-04).
///
/// No hay constructor que acepte una longitud arbitraria. Las etiquetas se declaran con literales
/// `*b"..."` de tipo `[u8; 16]`, de modo que **una etiqueta de longitud incorrecta no compila**.
/// La regla del SPEC la impone el compilador, no una comprobación en tiempo de ejecución.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub(crate) struct DomainTag([u8; 16]);

impl DomainTag {
    /// Etiqueta fija, íntegramente ASCII.
    pub(crate) const fn fija(bytes: [u8; 16]) -> Self {
        Self(bytes)
    }

    /// Etiqueta raíz del txid y del sighash: 12 bytes ASCII + `CONSENSUS_BRANCH_ID` en `u32` LE.
    ///
    /// Es la única etiqueta que no es ASCII puro. Lleva el identificador de rama para que una firma
    /// válida en una rama de consenso sea inválida en cualquier otra — la protección de repetición
    /// de C-UPG-04, copiada de ZIP-244.
    ///
    /// El argumento de inyectividad sigue en pie, y se verificó byte a byte: las otras once
    /// etiquetas **divergen de `ZZKTxIdHash_` dentro de los primeros 12 bytes**, antes de que
    /// empiece la región del branch ID. Ninguno de los 2³² valores posibles puede provocar una
    /// colisión.
    ///
    /// ⚠️ Invariante que hay que vigilar al añadir etiquetas nuevas (C-HASH-05): **ninguna etiqueta
    /// futura puede empezar por los 12 bytes literales `ZZKTxIdHash_`**. Si alguna lo hiciera,
    /// existiría un branch ID que colisionaría con ella.
    pub(crate) const fn raiz(consensus_branch_id: u32) -> Self {
        let p = *b"ZZKTxIdHash_";
        let c = consensus_branch_id.to_le_bytes();
        Self([
            p[0], p[1], p[2], p[3], p[4], p[5], p[6], p[7], p[8], p[9], p[10], p[11], c[0], c[1],
            c[2], c[3],
        ])
    }

    const fn as_bytes(&self) -> &[u8; 16] {
        &self.0
    }
}

/// Hash con dominio: `SHA3-256(tag ‖ m)` (C-HASH-04).
///
/// `pub(crate)` **a propósito y de forma no negociable** — ver el módulo. Ningún crate externo
/// puede alcanzar esta función, así que no existe ningún camino por el que unos bytes de wire
/// acaben hasheados como si fueran la preimagen canónica.
pub(crate) fn h_d(tag: DomainTag, msg: &[u8]) -> Digest {
    let mut hasher = Sha3_256::new();
    hasher.update(tag.as_bytes());
    hasher.update(msg);
    Digest::from_bytes(hasher.finalize().into())
}

/// SHA3-256 desnudo, sin dominio.
///
/// Solo para lo que la propia especificación define sin etiqueta: el hash de clave pública de una
/// dirección (C-ENC-07) y la preimagen de un HTLC (C-TX-09). **No** se usa para nada que entre en
/// un txid, un sighash o un hash de bloque — eso pasa siempre por [`h_d`].
pub(crate) fn sha3_256(msg: &[u8]) -> Digest {
    Digest::from_bytes(Sha3_256::digest(msg).into())
}

// ─────────────────────────────────────────────────────────────────────────────
// Tabla de etiquetas de dominio — SPEC §4.5, C-HASH-06.
//
// Son TODAS las de ZEROX v1.0. Añadir una es un cambio de consenso: exige pasar por C-HASH-05,
// y comprobar además la invariante del prefijo documentada en `DomainTag::raiz`.
//
// Cada literal es de tipo [u8; 16]: si alguien escribe una etiqueta de 15 o 17 bytes, no compila.
// ─────────────────────────────────────────────────────────────────────────────

/// §4.2 · cabecera de la transacción.
pub(crate) const TAG_TXID_HEADER: DomainTag = DomainTag::fija(*b"ZZKTxIdHeader___");
/// §4.2 · entradas, y §4.3 entradas-para-firma.
pub(crate) const TAG_TXID_INPUTS: DomainTag = DomainTag::fija(*b"ZZKTxIdInputs___");
/// §4.2 · outpoints consumidos.
pub(crate) const TAG_TXID_PREVOUT: DomainTag = DomainTag::fija(*b"ZZKTxIdPrevout__");
/// §4.2 · campos `sequence`.
pub(crate) const TAG_TXID_SEQUENCE: DomainTag = DomainTag::fija(*b"ZZKTxIdSequence_");
/// §4.2 · salidas creadas.
pub(crate) const TAG_TXID_OUTPUTS: DomainTag = DomainTag::fija(*b"ZZKTxIdOutputs__");
/// §4.3 · importes de las salidas gastadas.
pub(crate) const TAG_TXSIG_AMOUNTS: DomainTag = DomainTag::fija(*b"ZZKTxSigAmounts_");
/// §4.3 · condiciones de bloqueo de las salidas gastadas.
pub(crate) const TAG_TXSIG_LOCKS: DomainTag = DomainTag::fija(*b"ZZKTxSigLocks___");
/// §4.3 · la entrada concreta que se está firmando.
pub(crate) const TAG_TXSIG_THIS_IN: DomainTag = DomainTag::fija(*b"ZZKTxSigThisIn__");
/// §4.4 · auth digest.
pub(crate) const TAG_TX_AUTH: DomainTag = DomainTag::fija(*b"ZZKTxAuthHash___");
/// §6.3 · nodos internos del árbol de Merkle.
pub(crate) const TAG_BLK_MERKLE: DomainTag = DomainTag::fija(*b"ZZKBlkMerkle____");
/// §6.2 · hash de cabecera. Es la preimagen del PoW.
pub(crate) const TAG_BLK_HEADER: DomainTag = DomainTag::fija(*b"ZZKBlkHeader____");

/// Las once etiquetas ASCII fijas, para las comprobaciones de invariante.
pub(crate) const TAGS_FIJAS: [DomainTag; 11] = [
    TAG_TXID_HEADER,
    TAG_TXID_INPUTS,
    TAG_TXID_PREVOUT,
    TAG_TXID_SEQUENCE,
    TAG_TXID_OUTPUTS,
    TAG_TXSIG_AMOUNTS,
    TAG_TXSIG_LOCKS,
    TAG_TXSIG_THIS_IN,
    TAG_TX_AUTH,
    TAG_BLK_MERKLE,
    TAG_BLK_HEADER,
];

#[cfg(test)]
mod tests {
    use super::{DomainTag, TAGS_FIJAS, h_d, sha3_256};

    /// Ancla de cordura: si esto falla, se ha implementado Keccak-256 y no SHA3-256 (H-001).
    #[test]
    fn sha3_256_del_mensaje_vacio() {
        let d = sha3_256(b"");
        assert_eq!(
            format!("{d}"),
            "a7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a",
            "si sale c5d2460186f7233c... es Keccak-256, no SHA3-256 — ver H-001"
        );
    }

    /// C-HASH-04: todas las etiquetas fijas miden 16 bytes y son distintas entre sí.
    ///
    /// La longitud la garantiza el tipo (`[u8; 16]`); esto verifica la unicidad, que el tipo no
    /// puede garantizar.
    #[test]
    fn las_etiquetas_fijas_son_unicas() {
        let mut vistas: Vec<[u8; 16]> = Vec::new();
        for t in TAGS_FIJAS {
            let b = *t.as_bytes();
            assert!(
                !vistas.contains(&b),
                "etiqueta duplicada: {:?}",
                core::str::from_utf8(&b)
            );
            vistas.push(b);
        }
        assert_eq!(vistas.len(), 11);
    }

    /// La invariante que hace segura la etiqueta raíz con branch ID variable.
    ///
    /// Ninguna etiqueta fija comparte los 12 primeros bytes con `ZZKTxIdHash_`. Si alguna los
    /// compartiera, existiría un `CONSENSUS_BRANCH_ID` que colisionaría con ella.
    #[test]
    fn ninguna_etiqueta_fija_empieza_por_el_prefijo_de_la_raiz() {
        let prefijo = b"ZZKTxIdHash_";
        for t in TAGS_FIJAS {
            let b = t.as_bytes();
            let coincide = b[..12] == prefijo[..];
            assert!(
                !coincide,
                "la etiqueta {:?} comparte los 12 primeros bytes con la raíz: un branch ID podría \
                 colisionar con ella",
                core::str::from_utf8(b)
            );
        }
    }

    /// La raíz cambia con el branch ID — es lo que da la protección de repetición (C-UPG-04).
    #[test]
    fn la_raiz_depende_del_branch_id() {
        let a = h_d(DomainTag::raiz(0x0000_0000), b"mismo mensaje");
        let b = h_d(DomainTag::raiz(0xc478_80ea), b"mismo mensaje");
        assert_ne!(a, b, "una firma de una rama sería válida en otra");
    }

    /// Cambiar de dominio cambia el digest, aunque el mensaje sea idéntico.
    #[test]
    fn el_dominio_separa() {
        let msg = b"";
        let a = h_d(super::TAG_TXID_HEADER, msg);
        let b = h_d(super::TAG_TXID_INPUTS, msg);
        assert_ne!(a, b);
    }

    /// C-TX-04: el hash con dominio del vacío no es cero, y difiere por etiqueta.
    ///
    /// ZIP-143/243 usaban `uint256(0)` para los campos ausentes, con lo que "campo ausente" y
    /// "campo cuyo hash dio cero" eran indistinguibles y todos los ausentes colisionaban.
    #[test]
    fn el_hash_del_vacio_no_es_cero() {
        for t in TAGS_FIJAS {
            let d = h_d(t, b"");
            assert_ne!(d.as_bytes(), &[0u8; 32]);
        }
    }
}
