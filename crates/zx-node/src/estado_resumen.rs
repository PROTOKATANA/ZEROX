//! Resumen de estado (decisión 8 de `ORDEN-W06d1`; «Relanzamiento» punto 5).
//!
//! `blake3` de una codificación canónica **propia de `zx-node`** del estado de la punta
//! seleccionada: UTXO, garantía (con nonce) y emisión. Ni `zx-cadena` ni `zx-consensus` ofrecen esta
//! codificación (buscado explícitamente antes de escribirla; ninguna pieza migrada la impedía, así
//! que no hace falta ningún arreglo a otro crate). Objetivo: comparar el estado de dos aperturas del
//! mismo nodo (o, en el futuro, de dos nodos) sin volcar el estado entero.
//!
//! # Formato canónico
//!
//! Big-endian para todo entero de ancho fijo. Las colecciones de `Estado` que son `BTreeMap`
//! (`utxo`, `garantias`) ya iteran en orden de clave: no hace falta ordenar nada aparte. Los
//! `Vec<Pendiente>`/`Vec<EnRetirada>` de cada [`Garantia`] se codifican en su orden de aparición: es
//! el orden en que el motor de transición los fue añadiendo, determinista para una misma historia.
//!
//! ```text
//! resumen(Estado) = blake3(
//!     b"zx-node/resumen-estado/v1"
//!     ‖ CompactLenU64(|utxo|) ‖ Σ_{(op,e) en utxo, orden BTreeMap} entrada_utxo(op, e)
//!     ‖ CompactLenU64(|garantias|) ‖ Σ_{(pk,g) en garantias, orden BTreeMap} garantia(pk, g)
//!     ‖ i128_be(emitido)
//! )
//! ```
//!
//! con `entrada_utxo(op, e) = txid(32) ‖ index_be(4) ‖ valor_be(8) ‖ lock(...) ‖ origen(1) ‖ punto(9)`
//! y `garantia(pk, g) = pk(32) ‖ activo_be(8) ‖ nonce_siguiente_be(8) ‖ pendientes(...) ‖
//! en_retirada(...) ‖ congelado_be(8) ‖ creditos(...)`. `lock` codifica su discriminante (`0` = P2K,
//! `1` = MultiSig) seguido de sus campos; `origen` es el discriminante de tres valores; `punto` es un
//! byte de discriminante (`0` = Altura, `1` = Slot) seguido de 8 bytes big-endian.
//!
//! No es un formato de wire ni entra en ningún hash de consenso: es un instrumento de diagnóstico
//! del nodo (`ESCENARIOS-0.0.1.md` §1, «resumen del estado canónico»).

use zx_consensus::transicion::{
    EnRetirada, EntradaUtxo, Estado, Garantia, Origen, Pendiente, Punto,
};
use zx_core::{ClavePublica, Lock, OutPoint};

/// Dominio del resumen de estado (no es una etiqueta de consenso).
const DOMINIO: &[u8] = b"zx-node/resumen-estado/v1";

fn codificar_len(buf: &mut Vec<u8>, n: usize) {
    #[expect(
        clippy::unwrap_used,
        reason = "un estado real nunca tiene más de u64::MAX entradas"
    )]
    let n64 = u64::try_from(n).unwrap();
    buf.extend_from_slice(&n64.to_be_bytes());
}

fn codificar_punto(buf: &mut Vec<u8>, p: Punto) {
    match p {
        Punto::Altura(h) => {
            buf.push(0);
            buf.extend_from_slice(&u64::from(h).to_be_bytes());
        }
        Punto::Slot(s) => {
            buf.push(1);
            buf.extend_from_slice(&s.to_be_bytes());
        }
    }
}

fn codificar_lock(buf: &mut Vec<u8>, lock: &Lock) {
    match lock {
        Lock::PubKey { pubkey } => {
            buf.push(0);
            buf.extend_from_slice(pubkey.bytes());
        }
        Lock::MultiSig { k, pubkeys } => {
            buf.push(1);
            buf.push(*k);
            codificar_len(buf, pubkeys.len());
            for pk in pubkeys {
                buf.extend_from_slice(pk.bytes());
            }
        }
        Lock::Htlc {
            hash,
            receiver,
            sender,
            timeout,
        } => {
            buf.push(2);
            buf.extend_from_slice(hash);
            buf.extend_from_slice(receiver.bytes());
            buf.extend_from_slice(sender.bytes());
            buf.extend_from_slice(&u64::from(*timeout).to_be_bytes());
        }
    }
}

fn codificar_outpoint(buf: &mut Vec<u8>, op: &OutPoint) {
    buf.extend_from_slice(op.prev_txid.as_bytes());
    buf.extend_from_slice(&op.prev_index.to_be_bytes());
}

fn codificar_entrada_utxo(buf: &mut Vec<u8>, op: &OutPoint, e: &EntradaUtxo) {
    codificar_outpoint(buf, op);
    buf.extend_from_slice(&e.valor.brek().to_be_bytes());
    codificar_lock(buf, &e.lock);
    let origen: u8 = match e.origen {
        Origen::CoinbasePow => 0,
        Origen::Tx => 1,
        Origen::Liberacion => 2,
    };
    buf.push(origen);
    codificar_punto(buf, e.creada);
}

fn codificar_pendiente(buf: &mut Vec<u8>, p: &Pendiente) {
    buf.extend_from_slice(&p.importe.brek().to_be_bytes());
    match p.madura_en_altura {
        Some(h) => {
            buf.push(1);
            buf.extend_from_slice(&u64::from(h).to_be_bytes());
        }
        None => buf.push(0),
    }
    match p.madura_en_slot {
        Some(s) => {
            buf.push(1);
            buf.extend_from_slice(&s.to_be_bytes());
        }
        None => buf.push(0),
    }
}

fn codificar_en_retirada(buf: &mut Vec<u8>, r: &EnRetirada) {
    buf.extend_from_slice(&r.importe.brek().to_be_bytes());
    buf.extend_from_slice(&r.inicio_slot.to_be_bytes());
}

fn codificar_garantia(buf: &mut Vec<u8>, pk: &ClavePublica, g: &Garantia) {
    buf.extend_from_slice(pk.bytes());
    buf.extend_from_slice(&g.activo.brek().to_be_bytes());
    buf.extend_from_slice(&g.nonce_siguiente.to_be_bytes());
    codificar_len(buf, g.pendientes.len());
    for p in &g.pendientes {
        codificar_pendiente(buf, p);
    }
    codificar_len(buf, g.en_retirada.len());
    for r in &g.en_retirada {
        codificar_en_retirada(buf, r);
    }
    buf.extend_from_slice(&g.congelado.brek().to_be_bytes());
    codificar_len(buf, g.creditos.len());
    for c in &g.creditos {
        codificar_pendiente(buf, c);
    }
}

/// Codificación canónica del estado, tal como la documenta el módulo.
#[must_use]
pub fn codificar_estado(estado: &Estado) -> Vec<u8> {
    let mut buf = Vec::new();
    buf.extend_from_slice(DOMINIO);
    codificar_len(&mut buf, estado.utxo.len());
    for (op, e) in &estado.utxo {
        codificar_entrada_utxo(&mut buf, op, e);
    }
    codificar_len(&mut buf, estado.garantias.len());
    for (pk, g) in &estado.garantias {
        codificar_garantia(&mut buf, pk, g);
    }
    buf.extend_from_slice(&estado.emitido.to_be_bytes());
    buf
}

/// `blake3` del estado, en hexadecimal, para el registro estructurado.
#[must_use]
pub fn resumen_estado(estado: &Estado) -> String {
    let bytes = codificar_estado(estado);
    blake3::hash(&bytes).to_hex().to_string()
}

#[cfg(test)]
mod tests {
    use super::resumen_estado;
    use zx_consensus::transicion::Estado;

    #[test]
    fn es_determinista_y_sensible_a_cambios() {
        let e1 = Estado::inicial();
        let e2 = Estado::inicial();
        assert_eq!(resumen_estado(&e1), resumen_estado(&e2));

        let mut e3 = Estado::inicial();
        e3.emitido = 1;
        assert_ne!(resumen_estado(&e1), resumen_estado(&e3));
    }
}
