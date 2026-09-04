//! Activación de cambios de consenso (SPEC §14) y parámetros de red (§16).
//!
//! # Solo hard forks, y solo por altura
//!
//! Ni señalización de mineros, ni votación, ni detección de versión de cliente. Es el denominador
//! común de los dos diseños maduros: Zcash lo exige textualmente en ZIP-200, y Monero —pese a tener
//! implementada una votación por supermayoría— usa `threshold = 0` en **las 16 entradas reales** de
//! su tabla: nunca la ha ejercido.
//!
//! BIP-9 y BIP-8 **no aplican**: están definidos para *soft forks*. La señalización de mineros no
//! evita un split en un hard fork, porque un nodo antiguo rechaza los bloques nuevos por definición,
//! se señalice o no.
//!
//! # Por qué el branch ID va en la cabecera
//!
//! ZIP-200 describe el ataque de *wipe-out* —si tras la activación la rama vieja solo produce
//! bloques que también serían válidos bajo las reglas nuevas, un atacante con más trabajo en la
//! vieja puede **barrer la nueva con un reorg perfectamente legítimo**— y nombra la solución
//! genérica: *"modifying the block header to include a commitment to the CONSENSUS_BRANCH_ID"*.
//!
//! **Zcash no la implementó.** A ZEROX le importa más: los hard forks que ya damos por previstos
//! —ajustar `ZONA_LIBRE`, `N_LARGO`, `REF_WEIGHT`— son **cambios de parámetro puros**, que no
//! fuerzan ningún cambio de formato trivialmente inválido bajo las reglas viejas. Son exactamente
//! el caso vulnerable. Al nacer sin cadena viva, ponerlo en la cabecera cuesta cero.

use crate::error::ConsensusError;

/// Red.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Red {
    /// Cadena principal.
    Mainnet,
    /// Cadena de pruebas.
    Testnet,
}

/// Una rama de consenso: su identificador y la altura desde la que rige (C-UPG-02).
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct Rama {
    /// `CONSENSUS_BRANCH_ID`. **MUST** ser no cero y globalmente único.
    pub id: u32,
    /// Altura desde la que se aplican sus reglas.
    pub desde_altura: u32,
}

/// Rama v1.0 de mainnet, activa desde el génesis (C-UPG-02).
///
/// `0xc47880ea` = primeros 4 bytes de `SHA3-256("ZEROX/consensus-branch/v1.0")` leídos como `u32`
/// little-endian. **Derivado, no inventado**: cualquiera puede reproducirlo.
pub const RAMA_V1_MAINNET: Rama = Rama {
    id: 0xc478_80ea,
    desde_altura: 0,
};

/// Tabla de ramas de mainnet, **ordenada por altura ascendente**.
pub const RAMAS_MAINNET: &[Rama] = &[RAMA_V1_MAINNET];

/// Tabla de ramas de testnet.
///
/// Comparte identificador con mainnet en v1.0 porque las dos redes ya están separadas por el
/// génesis (C-GEN-04) y por el prefijo mágico (C-NET-01). Si algún día divergen las reglas, cada red
/// tendrá su propio identificador.
pub const RAMAS_TESTNET: &[Rama] = &[RAMA_V1_MAINNET];

/// Prefijo mágico de mainnet (C-NET-01).
///
/// Primeros 4 bytes de `SHA3-256("ZEROX/mainnet/magic")`. Verificado: no es UTF-8 válido, que es el
/// criterio que Bitcoin documenta para los suyos.
pub const MAGIC_MAINNET: [u8; 4] = [0x9e, 0x0f, 0x10, 0x44];

/// Prefijo mágico de testnet (C-NET-01). De `SHA3-256("ZEROX/testnet/magic")`.
pub const MAGIC_TESTNET: [u8; 4] = [0xbb, 0x79, 0x64, 0x3f];

impl Red {
    /// Tabla de ramas de esta red.
    #[must_use]
    pub const fn ramas(self) -> &'static [Rama] {
        match self {
            Self::Mainnet => RAMAS_MAINNET,
            Self::Testnet => RAMAS_TESTNET,
        }
    }

    /// Prefijo mágico de esta red.
    ///
    /// **Este prefijo, y no el hash del génesis, es lo que impide que un nodo hable con un peer de
    /// otra red.** El génesis distinto evita que las cadenas se confundan; el prefijo evita que los
    /// nodos siquiera se saluden.
    #[must_use]
    pub const fn magic(self) -> [u8; 4] {
        match self {
            Self::Mainnet => MAGIC_MAINNET,
            Self::Testnet => MAGIC_TESTNET,
        }
    }
}

/// Identificador de rama activo a una altura dada (C-UPG-01, C-UPG-02).
///
/// Se elige por **altura de bloque**, nunca por versión de software ni por señalización.
///
/// # Errores
/// [`ConsensusError::SinRamaActiva`] si ninguna rama cubre esa altura — imposible con una tabla
/// bien formada, cuya primera entrada arranca en 0, pero se trata como valor.
pub fn rama_activa(red: Red, altura: u32) -> Result<u32, ConsensusError> {
    red.ramas()
        .iter()
        .rev()
        .find(|r| altura >= r.desde_altura)
        .map(|r| r.id)
        .ok_or(ConsensusError::SinRamaActiva { altura })
}

/// C-HDR-02b · el `consensus_branch_id` de la cabecera **MUST** ser el activo a esa altura.
///
/// Es lo que da la protección contra *wipe-out* (C-UPG-05): un bloque de la rama vieja lleva su
/// identificador viejo y por tanto es inválido a alturas donde rige otro, así que no puede
/// participar en un reorg contra la rama nueva.
///
/// # Errores
/// [`ConsensusError::BranchIdIncorrecto`].
pub fn comprobar_branch_id(red: Red, altura: u32, branch_id: u32) -> Result<(), ConsensusError> {
    let esperado = rama_activa(red, altura)?;
    if branch_id == esperado {
        Ok(())
    } else {
        Err(ConsensusError::BranchIdIncorrecto {
            altura,
            esperado,
            encontrado: branch_id,
        })
    }
}

/// Comprueba que una tabla de ramas está bien formada (C-UPG-02, C-UPG-03).
///
/// Invariantes: arranca en la altura 0, las alturas crecen estrictamente, ningún identificador es
/// cero, y no hay identificadores repetidos.
///
/// Existe para que una tabla mal editada falle en un test y no en producción — es la lección de
/// H-005 aplicada a una constante que se editará a mano en cada hard fork.
///
/// # Errores
/// [`ConsensusError::TablaDeRamasInvalida`] con el motivo.
pub fn comprobar_tabla(ramas: &[Rama]) -> Result<(), ConsensusError> {
    let malo = |motivo| ConsensusError::TablaDeRamasInvalida { motivo };

    let primera = ramas.first().ok_or_else(|| malo("la tabla está vacía"))?;
    if primera.desde_altura != 0 {
        return Err(malo("la primera rama MUST arrancar en la altura 0"));
    }

    let mut vistos: Vec<u32> = Vec::with_capacity(ramas.len());
    let mut altura_previa: Option<u32> = None;

    for r in ramas {
        if r.id == 0 {
            return Err(malo("un CONSENSUS_BRANCH_ID MUST ser distinto de cero"));
        }
        if vistos.contains(&r.id) {
            // Salvo que sea la misma rama repetida, que la comprobación de altura ya descarta.
            return Err(malo("dos ramas comparten CONSENSUS_BRANCH_ID"));
        }
        vistos.push(r.id);

        if let Some(prev) = altura_previa
            && r.desde_altura <= prev
        {
            return Err(malo("las alturas de activación MUST crecer estrictamente"));
        }
        altura_previa = Some(r.desde_altura);
    }
    Ok(())
}

#[cfg(test)]
#[expect(clippy::unwrap_used, reason = "los tests fallan con panic por diseño")]
mod tests {
    use super::{
        MAGIC_MAINNET, MAGIC_TESTNET, RAMA_V1_MAINNET, RAMAS_MAINNET, Rama, Red,
        comprobar_branch_id, comprobar_tabla, rama_activa,
    };
    use crate::error::ConsensusError;
    use zx_core::sha3_256_publico;

    /// **Las constantes derivadas se recalculan aquí, no se confían.**
    ///
    /// Son valores que alguien podría "corregir" a mano en un editor. Si el identificador de rama o
    /// un prefijo mágico dejaran de coincidir con su derivación, el test lo dice.
    #[test]
    fn las_constantes_derivadas_se_reproducen() {
        let cbid = sha3_256_publico(b"ZEROX/consensus-branch/v1.0");
        let cuatro = cbid.as_bytes().get(..4).unwrap();
        let esperado = u32::from_le_bytes(cuatro.try_into().unwrap());
        assert_eq!(
            RAMA_V1_MAINNET.id, esperado,
            "el branch ID MUST ser los primeros 4 B de SHA3-256(\"ZEROX/consensus-branch/v1.0\") en LE"
        );

        let m = sha3_256_publico(b"ZEROX/mainnet/magic");
        assert_eq!(m.as_bytes().get(..4).unwrap(), MAGIC_MAINNET);
        let t = sha3_256_publico(b"ZEROX/testnet/magic");
        assert_eq!(t.as_bytes().get(..4).unwrap(), MAGIC_TESTNET);
    }

    /// C-NET-01: el criterio que Bitcoin documenta para sus prefijos.
    ///
    /// Se comprueba sobre los bytes **derivados en ejecución**, no sobre las constantes: con estas
    /// últimas clippy demuestra la invalidez en compilación y considera el test trivial —cosa que
    /// en sí misma es una garantía más fuerte, pero deja de ser una regresión útil si algún día se
    /// cambia la etiqueta de derivación.
    #[test]
    fn los_prefijos_magicos_no_son_utf8_valido() {
        for etiqueta in [&b"ZEROX/mainnet/magic"[..], &b"ZEROX/testnet/magic"[..]] {
            let d = sha3_256_publico(etiqueta);
            let cuatro = d.as_bytes().get(..4).unwrap();
            assert!(
                core::str::from_utf8(cuatro).is_err(),
                "el prefijo derivado de {:?} resultó ser UTF-8 válido — habría que elegir otra \
                 etiqueta, porque el criterio de C-NET-01 es que no aparezca en datos normales",
                core::str::from_utf8(etiqueta)
            );
        }
        assert_ne!(MAGIC_MAINNET, MAGIC_TESTNET, "las redes MUST distinguirse");
    }

    #[test]
    fn el_branch_id_no_es_cero() {
        assert_ne!(RAMA_V1_MAINNET.id, 0, "C-UPG-02: MUST ser no cero");
    }

    #[test]
    fn la_rama_v1_rige_desde_el_genesis() {
        assert_eq!(rama_activa(Red::Mainnet, 0).unwrap(), RAMA_V1_MAINNET.id);
        assert_eq!(
            rama_activa(Red::Mainnet, u32::MAX).unwrap(),
            RAMA_V1_MAINNET.id
        );
    }

    #[test]
    fn la_tabla_real_esta_bien_formada() {
        assert!(comprobar_tabla(RAMAS_MAINNET).is_ok());
        assert!(comprobar_tabla(Red::Testnet.ramas()).is_ok());
    }

    /// La tabla se editará a mano en cada hard fork. Estas son las formas de estropearla.
    #[test]
    fn se_detecta_una_tabla_mal_formada() {
        let casos: [(&str, Vec<Rama>); 5] = [
            ("vacía", vec![]),
            (
                "no arranca en 0",
                vec![Rama {
                    id: 1,
                    desde_altura: 5,
                }],
            ),
            (
                "alturas no crecientes",
                vec![
                    Rama {
                        id: 1,
                        desde_altura: 0,
                    },
                    Rama {
                        id: 2,
                        desde_altura: 0,
                    },
                ],
            ),
            (
                "altura que retrocede",
                vec![
                    Rama {
                        id: 1,
                        desde_altura: 0,
                    },
                    Rama {
                        id: 2,
                        desde_altura: 100,
                    },
                    Rama {
                        id: 3,
                        desde_altura: 50,
                    },
                ],
            ),
            (
                "id cero",
                vec![Rama {
                    id: 0,
                    desde_altura: 0,
                }],
            ),
        ];
        for (que, tabla) in casos {
            assert!(
                matches!(
                    comprobar_tabla(&tabla),
                    Err(ConsensusError::TablaDeRamasInvalida { .. })
                ),
                "debería detectarse: {que}"
            );
        }
    }

    /// **La protección contra wipe-out en funcionamiento.**
    ///
    /// Con dos ramas, un bloque que declare el identificador de la vieja a una altura donde rige la
    /// nueva es **inválido**, así que no puede competir en un reorg contra la rama nueva. Es lo que
    /// ZIP-200 describe y Zcash dejó sin implementar.
    #[test]
    fn un_bloque_de_la_rama_vieja_no_vale_en_la_nueva() {
        const VIEJA: u32 = 0x1111_1111;
        const NUEVA: u32 = 0x2222_2222;
        let tabla = vec![
            Rama {
                id: VIEJA,
                desde_altura: 0,
            },
            Rama {
                id: NUEVA,
                desde_altura: 1000,
            },
        ];
        assert!(comprobar_tabla(&tabla).is_ok());

        let activo_en = |h: u32| {
            tabla
                .iter()
                .rev()
                .find(|r| h >= r.desde_altura)
                .map(|r| r.id)
                .unwrap()
        };
        assert_eq!(activo_en(999), VIEJA, "antes de la activación");
        assert_eq!(activo_en(1000), NUEVA, "justo en la altura de activación");
        assert_ne!(
            activo_en(1000),
            VIEJA,
            "un bloque con el id viejo a 1000 sería inválido"
        );
    }

    #[test]
    fn se_rechaza_una_cabecera_con_el_branch_id_equivocado() {
        assert!(comprobar_branch_id(Red::Mainnet, 10, RAMA_V1_MAINNET.id).is_ok());
        let e = comprobar_branch_id(Red::Mainnet, 10, 0xDEAD_BEEF).unwrap_err();
        assert!(
            matches!(e, ConsensusError::BranchIdIncorrecto { .. }),
            "{e:?}"
        );
    }
}
