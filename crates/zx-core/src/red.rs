//! Identidad de red.
//!
//! # Por qué vive en `zx-core` y no en `zx-consensus`
//!
//! Llegó a haber **dos** `Red` distintos en el workspace —uno en `zx-core::address`, otro en
//! `zx-consensus::activacion`— y eso es exactamente el error que hay que evitar: dos tipos con el
//! mismo nombre y el mismo significado que el compilador no puede relacionar. Nada impedía pasar el
//! de un módulo donde se esperaba el otro salvo que las firmas no cuadraran, y el día que
//! cuadraran por casualidad el fallo sería silencioso.
//!
//! Vive aquí porque es una etiqueta, no una regla: no decide nada de consenso. Y ponerla en el
//! crate base es lo que permite que `zx-p2p` la use **sin depender de `zx-consensus`** — ver el
//! diagrama de dependencias en `zx-p2p`.

/// Prefijo mágico de mainnet (C-NET-01). Primeros 4 bytes de `SHA3-256("ZEROX/mainnet/magic")`.
pub const MAGIC_MAINNET: [u8; 4] = [0x9e, 0x0f, 0x10, 0x44];

/// Prefijo mágico de testnet (C-NET-01). Primeros 4 bytes de `SHA3-256("ZEROX/testnet/magic")`.
pub const MAGIC_TESTNET: [u8; 4] = [0xbb, 0x79, 0x64, 0x3f];

/// La cadena a la que pertenece algo.
///
/// Aparece en direcciones (el HRP entra en el checksum, así que una dirección de testnet **no
/// puede** leerse como de mainnet), en la tabla de ramas de consenso, en el génesis y en los
/// parámetros de red.
#[derive(Clone, Copy, PartialEq, Eq, Debug, Hash)]
pub enum Red {
    /// Cadena principal.
    Mainnet,
    /// Cadena de pruebas.
    Testnet,
}

impl Red {
    /// Nombre corto, para logs y para componer identificadores.
    #[must_use]
    pub const fn nombre(self) -> &'static str {
        match self {
            Self::Mainnet => "mainnet",
            Self::Testnet => "testnet",
        }
    }

    /// Prefijo mágico de esta red (C-NET-01).
    ///
    /// **Este prefijo, y no el hash del génesis, es lo que impide que un nodo hable con un peer de
    /// otra red.** El génesis distinto (C-GEN-04) evita que las cadenas se confundan; el prefijo
    /// evita que los nodos siquiera se saluden.
    #[must_use]
    pub const fn magic(self) -> [u8; 4] {
        match self {
            Self::Mainnet => MAGIC_MAINNET,
            Self::Testnet => MAGIC_TESTNET,
        }
    }
}

#[cfg(test)]
#[expect(clippy::unwrap_used, reason = "los tests fallan con panic por diseño")]
mod tests {
    use super::{MAGIC_MAINNET, MAGIC_TESTNET, Red};
    use crate::sha3_256_publico;

    #[test]
    fn las_dos_redes_tienen_nombres_distintos() {
        assert_ne!(Red::Mainnet.nombre(), Red::Testnet.nombre());
        assert_eq!(Red::Mainnet.nombre(), "mainnet");
    }

    /// **C-NET-01.** Los prefijos son **derivados, no inventados**, y esto lo demuestra.
    ///
    /// El SPEC afirma que salen de `SHA3-256("ZEROX/<red>/magic")`. Una afirmación así o se
    /// comprueba o sobra: sin este test nadie sabría si los bytes del SPEC son los que da la
    /// fórmula o los que alguien tecleó una vez.
    #[test]
    fn los_prefijos_magicos_se_derivan_de_su_formula() {
        for red in [Red::Mainnet, Red::Testnet] {
            let etiqueta = format!("ZEROX/{}/magic", red.nombre());
            let h = sha3_256_publico(etiqueta.as_bytes());
            let cuatro: [u8; 4] = h.as_bytes().get(..4).unwrap().try_into().unwrap();
            assert_eq!(
                cuatro,
                red.magic(),
                "primeros 4 bytes de SHA3-256({etiqueta:?})"
            );
        }
    }

    /// Bitcoin documenta que sus prefijos *"not valid as UTF-8"*. Comprobado, no citado.
    #[test]
    fn los_prefijos_magicos_no_son_utf8_valido() {
        for magic in [MAGIC_MAINNET, MAGIC_TESTNET] {
            assert!(core::str::from_utf8(&magic).is_err(), "{magic:02x?}");
        }
    }

    #[test]
    fn cada_red_tiene_su_propio_prefijo() {
        assert_ne!(Red::Mainnet.magic(), Red::Testnet.magic());
    }
}
