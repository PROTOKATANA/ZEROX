//! El **firmante seguro**: la política de «persistir antes de firmar».
//!
//! Implementa la regla de `P-ZRX/P-FIRMANTE/ESPECIFICACION.md` §3.1, literal:
//!
//! ```text
//! Antes de emitir el sello de un bloque B:
//!   1. Calcular su identidad de oportunidad TicketId(B).
//!   2. Consultar el registro persistente por la clave (TicketId(B), slot(B)).
//!   3. Si NO hay entrada: escribir (TicketId, slot) -> pre_hash(B) de forma ATÓMICA y DURADERA
//!      (fsync del fichero o commit de la transacción) y sólo entonces firmar.
//!   4. Si hay entrada con el MISMO pre_hash: firmar (es el mismo bloque; puede reemitirse).
//!   5. Si hay entrada con OTRO pre_hash: NO firmar. Descartar el candidato.
//! ```
//!
//! # Lo que este tipo es y lo que no es
//!
//! Es un **filtro de accidentes honestos**: dos nodos redundantes, un reinicio, un candidato
//! reconstruido porque la punta cambió. **No** es un mecanismo de seguridad: quien quiera
//! doble-firmar borra el registro o usa otro binario. `ESPECIFICACION.md` §3.4.2 y encargo §8.
//!
//! # Por qué el orden de las operaciones es el contrato
//!
//! El error por defecto —y el que este prototipo existe para no cometer— es apuntar el bloque
//! **después** de publicarlo. Aquí [`Firmante::firmar`] no tiene ninguna ruta que firme antes de
//! que [`Registro::resolver`] devuelva `Ok`: el sello se construye después, y si la persistencia
//! falla, la función devuelve `Err` sin sello. El test `durabilidad_*` lo comprueba matando el
//! proceso justo en medio.

use ed25519_zebra::SigningKey;
use zx_core::preimage::dag::DagBlockHeader;

use crate::identidad::{IdentidadOportunidad, IdentidadTicket, S_MAX_SLOTS_NOMINAL};
use crate::registro::{Registro, RegistroError, Resolucion};

/// Qué hizo el firmante con un candidato.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Resultado {
    /// No había entrada: se persistió y **después** se selló. Es el camino normal.
    Sellado,
    /// Ya había entrada con el mismo `pre_hash`: es el mismo bloque y se ha vuelto a sellar.
    /// Es el **caso 4**: un nodo que se reinicia y republica no queda roto.
    Reemitido,
    /// El candidato se descartó y **no** se selló. Es el **caso 5**. El candidato no llegó a
    /// firmarse, así que no puede producir la evidencia de equivocación.
    AbstenidoPorConflicto {
        /// El `pre_hash` que ya estaba en el registro, con la misma identidad y el mismo slot.
        pre_hash_registrado: zx_core::PreHash,
    },
}

/// Fallos del firmante. Todos significan que **no se emitió sello**.
#[derive(Debug, thiserror::Error)]
pub enum FirmanteError {
    /// El registro falló (E/S, bloqueo, corrupción o abstención). Si dudas, no firmes: es la
    /// decisión segura y es la que toma este tipo.
    #[error("firmante: {0}")]
    Registro(#[from] RegistroError),

    /// La identidad del candidato no se pudo calcular. Hoy no hay ningún caso en que esto ocurra
    /// (la codificación canónica no puede fallar con estos tipos); existe para que el día que la
    /// identidad sí pueda rechazar un candidato, el firmante no firme «por defecto».
    #[error("firmante: identidad no calculable: {motivo}")]
    Identidad {
        /// Motivo.
        motivo: &'static str,
    },
}

/// El firmante: un registro compartido y la ventana `S_max_slots` vigente.
///
/// Lleva el registro por referencia, así que **varios hilos** pueden llamar a
/// [`Firmante::firmar`] a la vez: la exclusión la impone el `Mutex` del registro. Dos **procesos**
/// sobre el mismo fichero quedan excluidos por `flock` (ver [`Registro::abrir`]).
#[derive(Debug)]
pub struct Firmante<'a> {
    registro: &'a Registro,
    s_max_slots: u64,
}

impl<'a> Firmante<'a> {
    /// Construye el firmante con la ventana vigente.
    ///
    /// `s_max_slots` **no** es una constante de este prototipo: es un parámetro de perfil
    /// (`SPEC.md` §11 lo usa como valor de trabajo). [`S_MAX_SLOTS_NOMINAL`] es el valor por
    /// defecto de aquí con su procedencia anotada.
    #[must_use]
    pub const fn nuevo(registro: &'a Registro, s_max_slots: u64) -> Self {
        Self {
            registro,
            s_max_slots,
        }
    }

    /// El firmante con el `S_max_slots` nominal (150 slots).
    #[must_use]
    pub const fn con_s_max_nominal(registro: &'a Registro) -> Self {
        Self::nuevo(registro, S_MAX_SLOTS_NOMINAL)
    }

    /// `S_max_slots` vigente en esta instancia.
    #[must_use]
    pub const fn s_max_slots(&self) -> u64 {
        self.s_max_slots
    }

    /// El registro que gobierna este firmante.
    #[must_use]
    pub const fn registro(&self) -> &'a Registro {
        self.registro
    }

    /// La identidad de oportunidad de un candidato, con la definición **vigente** por defecto.
    ///
    /// Hoy es `C-GD-07`/R-FIN-11 sobre los campos de la solución PoAS de la cabecera. Para usar
    /// otra definición, [`Firmante::firmar_con_identidad`].
    #[must_use]
    pub fn identidad(header: &DagBlockHeader) -> IdentidadTicket {
        IdentidadTicket::vigente(
            header.sol.public_key,
            header.sol.sector_index,
            header.sol.history_size,
            header.sol.chunk,
            header.slot,
        )
    }

    /// Aplica la regla a un candidato y devuelve el resultado, **sin** sellar.
    ///
    /// Es la mitad «decidir» de [`Firmante::firmar`], expuesta aparte para poder probar la regla
    /// sin criptografía y para que un llamante que gestione el sello por su cuenta (p. ej. un HSM)
    /// pueda reutilizar exactamente la misma decisión.
    ///
    /// # Errores
    /// [`FirmanteError::Registro`] si el registro falla; en particular
    /// [`RegistroError::EnAbstinencia`] durante la ventana tras una pérdida.
    pub fn decidir(
        &self,
        identidad: &impl IdentidadOportunidad,
        pre_hash: zx_core::PreHash,
    ) -> Result<Resultado, FirmanteError> {
        match self.registro.resolver(identidad, pre_hash)? {
            Resolucion::Nueva => Ok(Resultado::Sellado),
            Resolucion::Conocida => Ok(Resultado::Reemitido),
            Resolucion::Conflicto {
                pre_hash_registrado,
            } => Ok(Resultado::AbstenidoPorConflicto {
                pre_hash_registrado,
            }),
        }
    }

    /// Aplica la regla y, **solo si procede**, escribe el sello Ed25519 en `header.sello`.
    ///
    /// El sello es `Ed25519(sk, pre_hash(B))` — el mensaje es el `pre_hash`, no la prefirma ni el
    /// `block_hash`: ver `crates/zx-core/src/preimage/dag.rs`, `DagBlockHeader::pre_hash` y
    /// `verificar_sello`.
    ///
    /// `header.sello` se escribe **únicamente** en el camino de éxito, así que un candidato
    /// descartado queda con el sello que tuviera (y quien lo llame debe descartarlo: el `Resultado`
    /// se lo dice).
    ///
    /// # Errores
    /// [`FirmanteError`] si el registro falla. En ese caso `header.sello` **no** se toca.
    pub fn firmar(
        &self,
        header: &mut DagBlockHeader,
        sk: &SigningKey,
    ) -> Result<Resultado, FirmanteError> {
        let identidad = Self::identidad(header);
        self.firmar_con_identidad(header, &identidad, sk)
    }

    /// Igual que [`Firmante::firmar`] pero con la identidad que el llamante elija: el punto de
    /// extensión del encargo §1.
    ///
    /// # Errores
    /// Las mismas que [`Firmante::firmar`]. Si `identidad` no es la del header (por ejemplo, la
    /// variante con dominio de red), la huella que indexa el registro es la de `identidad`: eso es
    /// justo lo que se pide, y la responsabilidad de que la identidad describa al candidato es del
    /// llamante.
    pub fn firmar_con_identidad(
        &self,
        header: &mut DagBlockHeader,
        identidad: &impl IdentidadOportunidad,
        sk: &SigningKey,
    ) -> Result<Resultado, FirmanteError> {
        let pre_hash = header.pre_hash();
        let resultado = self.decidir(identidad, pre_hash)?;
        if matches!(resultado, Resultado::AbstenidoPorConflicto { .. }) {
            return Ok(resultado);
        }
        // Decisión tomada y —si era nueva— ya persistida y sincronizada. Solo ahora se sella.
        header.sello = sk.sign(pre_hash.as_bytes()).into();
        Ok(resultado)
    }
}

#[cfg(test)]
#[expect(clippy::unwrap_used, reason = "los tests fallan con panic por diseño")]
mod tests {
    use super::{Firmante, Resultado};
    use crate::identidad::{IdentidadOportunidad, IdentidadTicket};
    use crate::registro::Registro;
    use ed25519_zebra::{SigningKey, VerificationKey};
    use zx_core::preimage::dag::{DagBlockHeader, PadresDag, SolucionPoas};
    use zx_core::{BlockHash, BodyCommitment, Digest, MerkleRoot, PreHash};

    pub(crate) fn sk() -> SigningKey {
        SigningKey::from([42u8; 32])
    }

    pub(crate) fn cabecera(padre: u8, chunk: u8, slot: u64) -> DagBlockHeader {
        DagBlockHeader {
            consensus_branch_id: 0,
            merkle_root: MerkleRoot::from_digest(Digest::from_bytes([0x22; 32])),
            timestamp: 1_700_000_000,
            height: 10,
            slot,
            pot_output: [0x11; 16],
            rango_solucion: 7,
            sol: SolucionPoas {
                public_key: zx_core::ClavePublica::desde_bytes(VerificationKey::from(&sk()).into()),
                sector_index: 1,
                history_size: 1 << 20,
                chunk: [chunk; 32],
                ..SolucionPoas::default()
            },
            body_commitment: BodyCommitment::from_digest(Digest::from_bytes([0x33; 32])),
            padres: PadresDag::nuevo(
                BlockHash::from_digest(Digest::from_bytes([padre; 32])),
                &[],
            )
            .unwrap(),
            sello: [0u8; 64],
        }
    }

    fn pre_hash_de(c: &DagBlockHeader) -> PreHash {
        c.pre_hash()
    }

    #[test]
    fn caso_5_con_entrada_previa_y_otro_pre_hash_no_firma() {
        let dir = tempfile::tempdir().unwrap();
        let reg = Registro::nueva(dir.path().join("r.log"), 150).unwrap();
        let f = Firmante::con_s_max_nominal(&reg);

        let mut a = cabecera(1, 5, 100);
        assert_eq!(f.firmar(&mut a, &sk()).unwrap(), Resultado::Sellado);
        let sello_a = a.sello;
        assert_ne!(sello_a, [0u8; 64]);

        // Mismo billete y mismo slot, OTRO padre ⇒ otro `pre_hash`.
        let mut b = cabecera(2, 5, 100);
        assert_ne!(pre_hash_de(&a), pre_hash_de(&b));
        let r = f.firmar(&mut b, &sk()).unwrap();
        assert!(matches!(r, Resultado::AbstenidoPorConflicto { .. }));
        assert_eq!(b.sello, [0u8; 64], "el candidato descartado NO puede llevar sello");
    }

    #[test]
    fn caso_4_reemitir_el_mismo_bloque_funciona() {
        let dir = tempfile::tempdir().unwrap();
        let reg = Registro::nueva(dir.path().join("r.log"), 150).unwrap();
        let f = Firmante::con_s_max_nominal(&reg);

        let mut a = cabecera(1, 5, 100);
        assert_eq!(f.firmar(&mut a, &sk()).unwrap(), Resultado::Sellado);
        let sello = a.sello;

        // El nodo se reinicia y reconstruye el MISMO bloque (mismo padre, mismo cuerpo).
        let mut otra_vez = cabecera(1, 5, 100);
        assert_eq!(f.firmar(&mut otra_vez, &sk()).unwrap(), Resultado::Reemitido);
        assert_eq!(otra_vez.sello, sello, "el sello es determinista y válido");
    }

    #[test]
    fn el_sello_verifica_bajo_la_clave_publica() {
        let dir = tempfile::tempdir().unwrap();
        let reg = Registro::nueva(dir.path().join("r.log"), 150).unwrap();
        let f = Firmante::con_s_max_nominal(&reg);
        let mut a = cabecera(1, 5, 100);
        assert_eq!(f.firmar(&mut a, &sk()).unwrap(), Resultado::Sellado);
        a.verificar_sello().unwrap();
    }

    #[test]
    fn el_punto_de_extension_funciona_con_dos_implementaciones() {
        let dir = tempfile::tempdir().unwrap();
        let reg = Registro::nueva(dir.path().join("r.log"), 150).unwrap();
        let f = Firmante::con_s_max_nominal(&reg);

        let mut a = cabecera(1, 5, 100);
        let vigente = Firmante::identidad(&a);
        assert_eq!(f.firmar(&mut a, &sk()).unwrap(), Resultado::Sellado);
        assert_ne!(a.sello, [0u8; 64]);

        // La MISMA oportunidad vista por IDV-01 (con dominio de red).
        let con_red = IdentidadTicket::TicketConRed {
            red: [0xAB; 32],
            public_key: a.sol.public_key,
            sector_index: a.sol.sector_index,
            history_size: a.sol.history_size,
            chunk: a.sol.chunk,
            slot: a.slot,
        };
        assert_ne!(vigente.huella(), con_red.huella());

        // B es OTRO candidato (otra punta): su `pre_hash` no está registrado bajo ninguna de las
        // dos identidades. Bajo IDV-01 sella —espacio de claves distinto— y un segundo candidato
        // contradictorio bajo IDV-01 no.
        let mut b = cabecera(2, 5, 100);
        let mut c = cabecera(3, 5, 100);
        assert_eq!(
            f.firmar_con_identidad(&mut b, &con_red, &sk()).unwrap(),
            Resultado::Sellado
        );
        assert!(matches!(
            f.firmar_con_identidad(&mut c, &con_red, &sk()).unwrap(),
            Resultado::AbstenidoPorConflicto { .. }
        ));
        // Y la implementación vigente sigue recordando lo suyo, sin mezclarse.
        assert!(matches!(
            f.decidir(&vigente, pre_hash_de(&a)).unwrap(),
            Resultado::Reemitido
        ));
        // B está registrado bajo IDV-01, no bajo la vigente: consulta de solo lectura, porque
        // `decidir` escribiría una entrada nueva para esa oportunidad.
        assert!(!f.registro().contiene(&vigente, pre_hash_de(&b)));
        assert!(f.registro().contiene(&con_red, pre_hash_de(&b)));
    }
}
