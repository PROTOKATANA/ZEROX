//! Contrato candidato de vinculación, comparado como vector exacto.
//! NO añade un hash/campo a la cabecera ni autentica al productor.

use crate::{AutorizacionPerfil, ContextoIdentificado, CuerpoCandidato, Rechazo, autorizar_cuerpo};
use zx_core::digest::{AuthDigest, TxId};
use zx_core::preimage::block::merkle_root;
use zx_core::preimage::tx::{auth_digest, txid};

/// Conserva orden, multiplicidad y coinbase. No es una prueba de firmas válidas.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct CompromisoCuerpoDeclarado {
    pares: Vec<(TxId, AuthDigest)>,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ErrorCompromiso {
    OrchardNoSoportado,
    ListasDesalineadas,
    MerkleIncoherente,
}

impl CompromisoCuerpoDeclarado {
    /// `Ok` construye la proyección: no valida firmas, coinbase ni el perfil ALL.
    pub fn del_cuerpo(cuerpo: &CuerpoCandidato) -> Result<Self, ErrorCompromiso> {
        if cuerpo.orchard.is_some() {
            return Err(ErrorCompromiso::OrchardNoSoportado);
        }
        if cuerpo.txs.len() != cuerpo.testigos.len() {
            return Err(ErrorCompromiso::ListasDesalineadas);
        }
        let pares: Vec<_> = cuerpo
            .txs
            .iter()
            .zip(&cuerpo.testigos)
            .map(|(tx, testigos)| {
                (
                    txid(tx, cuerpo.cabecera.consensus_branch_id),
                    auth_digest(testigos),
                )
            })
            .collect();
        let ids: Vec<_> = pares.iter().map(|(id, _)| *id).collect();
        if merkle_root(&ids) != cuerpo.cabecera.merkle_root {
            return Err(ErrorCompromiso::MerkleIncoherente);
        }
        Ok(Self { pares })
    }

    /// La longitud es la del vector real, no un contador propuesto por el peer.
    #[must_use]
    pub fn cantidad(&self) -> usize {
        self.pares.len()
    }

    #[must_use]
    pub fn pares(&self) -> &[(TxId, AuthDigest)] {
        &self.pares
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ErrorVinculacion {
    Proyeccion(ErrorCompromiso),
    EntregaDistinta,
    Autorizacion(Rechazo),
}

/// Vincula la entrega al compromiso esperado y después ejecuta el compositor real.
/// El llamante debe autenticar la procedencia del compromiso esperado y del snapshot.
/// Aquí se suministran como entradas; no se simula una cabecera DAG firmada.
pub fn autorizar_con_compromiso(
    candidato: &CuerpoCandidato,
    contexto: &ContextoIdentificado,
    esperado: &CompromisoCuerpoDeclarado,
) -> Result<AutorizacionPerfil, ErrorVinculacion> {
    let recibido =
        CompromisoCuerpoDeclarado::del_cuerpo(candidato).map_err(ErrorVinculacion::Proyeccion)?;
    if &recibido != esperado {
        return Err(ErrorVinculacion::EntregaDistinta);
    }
    autorizar_cuerpo(candidato, contexto).map_err(ErrorVinculacion::Autorizacion)
}
