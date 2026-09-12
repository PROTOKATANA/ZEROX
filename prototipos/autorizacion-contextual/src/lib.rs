//! Composición experimental transparente; NO certifica cabecera PoST, DAG ni disponibilidad.
//! Las huellas son claves locales de evidencia, no nuevos hashes de consenso.
#![forbid(unsafe_code)]

pub mod almacen;
pub mod compromiso;
pub mod dominio;

use zx_consensus::activacion::{Red, comprobar_branch_id};
use zx_consensus::bloque::{Bloque, BloqueValidado, ContextoBloque, validar_cuerpo};
use zx_consensus::error::ConsensusError;
use zx_consensus::peso::{MAX_TX_WEIGHT, ZONA_LIBRE};
use zx_consensus::testigo::{ContextoGasto, satisface};
use zx_consensus::validacion::{
    ConjuntoUtxo, EntradaUtxo, comprobar_sin_doble_gasto_en_bloque, peso_tx,
};
use zx_core::digest::BlockHash;
use zx_core::preimage::block::{BlockHeader, merkle_root};
use zx_core::preimage::tx::{HashType, sighash, txid};
use zx_core::tx::{Lock, OutPoint, Tx};

/// Entrada owned. No es un tipo validado: sus campos pueden ser adversariales.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct CuerpoCandidato {
    pub cabecera: BlockHeader,
    pub txs: Vec<Tx>,
    pub testigos: Vec<Vec<Vec<u8>>>,
    /// Perfil de esta API: sólo ALL. No inventa un byte nuevo en el testigo wire.
    pub hash_type: HashType,
    /// Incluso Some(vacío) exige un verificador Orchard que este perfil no tiene.
    pub orchard: Option<Vec<u8>>,
}

impl CuerpoCandidato {
    pub fn block_hash(&self) -> BlockHash {
        self.cabecera.block_hash()
    }

    /// Compromete TODO el candidato, incluso testigos sobrantes de entradas mal formadas.
    pub fn body_key(&self) -> [u8; 32] {
        let mut bytes = b"ZEROX/experimental/AUT-v1/cuerpo\0".to_vec();
        zx_core::wire::cuerpo_a_bytes(&mut bytes, &self.cabecera, &self.txs, &self.testigos);
        // El encoder nativo omite listas sobrantes: esta cola las compromete igualmente.
        longitud(&mut bytes, self.testigos.len());
        for tx in &self.testigos {
            longitud(&mut bytes, tx.len());
            for witness in tx {
                longitud(&mut bytes, witness.len());
                bytes.extend_from_slice(witness);
            }
        }
        bytes.push(self.hash_type.byte());
        match &self.orchard {
            None => bytes.push(0),
            Some(bundle) => {
                bytes.push(1);
                longitud(&mut bytes, bundle.len());
                bytes.extend_from_slice(bundle);
            }
        }
        *zx_core::sha3_256_publico(&bytes).as_bytes()
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct DatosContexto {
    /// Identidad de dominio suministrada por la capa de contexto, no por el peer del cuerpo.
    pub dominio: [u8; 32],
    pub ancla_causal: [u8; 32],
    pub red: Red,
    /// Altura declarada por el proveedor de contexto; NO se deriva del índice de llegada.
    pub altura: u32,
    pub mediana_efectiva: u64,
    pub emitido: u128,
    pub completo: bool,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum EstadoSalida {
    Disponible(EntradaUtxo),
    Gastado,
    /// Ausencia acreditada por el proveedor, no inferida de un lookup fallido.
    Inexistente,
    Desconocido,
}

/// Snapshot inmutable, identificado por sus datos. Su procedencia DAG NO está certificada.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ContextoIdentificado {
    datos: DatosContexto,
    salidas: Vec<(OutPoint, EstadoSalida)>,
    key: [u8; 32],
}

impl ContextoIdentificado {
    pub fn desde_snapshot_declarado(
        datos: DatosContexto,
        mut salidas: Vec<(OutPoint, EstadoSalida)>,
    ) -> Result<Self, Rechazo> {
        if datos.mediana_efectiva < ZONA_LIBRE || datos.mediana_efectiva.checked_mul(2).is_none() {
            return Err(Rechazo::ContextoInvalido(
                "mediana fuera del perfil comprobable",
            ));
        }
        salidas.sort_by_key(|(o, _)| (o.prev_txid, o.prev_index));
        if salidas.windows(2).any(|w| w[0].0 == w[1].0) {
            return Err(Rechazo::ContextoInvalido("outpoint duplicado en snapshot"));
        }
        let mut bytes = b"ZEROX/experimental/AUT-v1/contexto\0".to_vec();
        bytes.extend_from_slice(&datos.dominio);
        bytes.extend_from_slice(&datos.ancla_causal);
        bytes.push(match datos.red {
            Red::Mainnet => 0,
            Red::Testnet => 1,
        });
        bytes.extend_from_slice(&datos.altura.to_le_bytes());
        bytes.extend_from_slice(&datos.mediana_efectiva.to_le_bytes());
        bytes.extend_from_slice(&datos.emitido.to_le_bytes());
        bytes.push(u8::from(datos.completo));
        longitud(&mut bytes, salidas.len());
        for (outpoint, estado) in &salidas {
            bytes.extend_from_slice(outpoint.prev_txid.as_bytes());
            bytes.extend_from_slice(&outpoint.prev_index.to_le_bytes());
            match estado {
                EstadoSalida::Disponible(entrada) => {
                    comprobar_lock(&entrada.salida.lock)?;
                    if entrada.altura_creacion > datos.altura {
                        return Err(Rechazo::ContextoInvalido(
                            "UTXO creado después de altura contextual",
                        ));
                    }
                    bytes.push(0);
                    bytes.extend_from_slice(&entrada.salida.value.brek().to_le_bytes());
                    zx_core::wire::lock_a_bytes(&mut bytes, &entrada.salida.lock);
                    bytes.extend_from_slice(&entrada.altura_creacion.to_le_bytes());
                    bytes.push(u8::from(entrada.es_coinbase));
                }
                EstadoSalida::Gastado => bytes.push(1),
                EstadoSalida::Inexistente => bytes.push(2),
                EstadoSalida::Desconocido => bytes.push(3),
            }
        }
        let key = *zx_core::sha3_256_publico(&bytes).as_bytes();
        Ok(Self {
            datos,
            salidas,
            key,
        })
    }
    pub fn context_key(&self) -> [u8; 32] {
        self.key
    }
    pub fn datos(&self) -> &DatosContexto {
        &self.datos
    }
    pub fn salidas(&self) -> &[(OutPoint, EstadoSalida)] {
        &self.salidas
    }
    fn estado(&self, outpoint: &OutPoint) -> Option<&EstadoSalida> {
        self.salidas
            .binary_search_by_key(&(outpoint.prev_txid, outpoint.prev_index), |(o, _)| {
                (o.prev_txid, o.prev_index)
            })
            .ok()
            .and_then(|i| self.salidas.get(i))
            .map(|(_, estado)| estado)
    }
}

impl ConjuntoUtxo for ContextoIdentificado {
    fn buscar(&self, outpoint: &OutPoint) -> Option<EntradaUtxo> {
        match self.estado(outpoint) {
            Some(EstadoSalida::Disponible(entrada)) => Some(entrada.clone()),
            _ => None,
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Rechazo {
    ContextoInvalido(&'static str),
    ContextoIncompleto,
    Dependencias(Vec<OutPoint>),
    /// La salida ya está gastada en el snapshot. NO acredita autorización de esta tx:
    /// el snapshot no conserva el lock histórico para verificar esa firma.
    GastadoEnSnapshot(Vec<OutPoint>),
    /// Invalidez de ESTA entrega/contexto; no invalidación global de su cabecera.
    Invalido(ConsensusError),
    Codificacion(zx_core::error::EncodingError),
    NoSoportado(&'static str),
}

/// Evidencia no construible desde clientes Rust seguros, salvo pasando autorizar_cuerpo.
/// Es condicional al snapshot declarado, no prueba portable de consenso o de posesión de datos.
///
/// ```compile_fail
/// use autorizacion_contextual::{AutorizacionPerfil, CuerpoCandidato};
/// use zx_consensus::bloque::BloqueValidado;
/// fn fabricar(cuerpo: CuerpoCandidato, resultado: BloqueValidado) -> AutorizacionPerfil {
///     AutorizacionPerfil { cuerpo, body_key: [0; 32], context_key: [0; 32], resultado }
/// }
/// ```
///
/// ```compile_fail
/// use autorizacion_contextual::AutorizacionPerfil;
/// use zx_core::preimage::tx::HashType;
/// fn mutar(token: &AutorizacionPerfil) {
///     token.cuerpo().hash_type = HashType::None;
/// }
/// ```
#[derive(Clone, Debug)]
pub struct AutorizacionPerfil {
    cuerpo: CuerpoCandidato,
    body_key: [u8; 32],
    context_key: [u8; 32],
    resultado: BloqueValidado,
}

impl AutorizacionPerfil {
    pub fn body_key(&self) -> [u8; 32] {
        self.body_key
    }
    pub fn context_key(&self) -> [u8; 32] {
        self.context_key
    }
    pub fn block_hash(&self) -> BlockHash {
        self.cuerpo.block_hash()
    }
    pub fn cuerpo(&self) -> &CuerpoCandidato {
        &self.cuerpo
    }
    pub fn resultado(&self) -> BloqueValidado {
        self.resultado
    }
}

fn longitud(bytes: &mut Vec<u8>, n: usize) {
    // Plataformas Rust soportadas tienen usize <= u64; son claves locales, no wire nuevo.
    zx_core::encoding::compact_size::escribir(bytes, n as u64);
}

fn comprobar_lock(lock: &Lock) -> Result<(), Rechazo> {
    if let Lock::MultiSig { k, pubkeys } = lock {
        Lock::multisig(*k, pubkeys.clone()).map_err(Rechazo::Codificacion)?;
    }
    Ok(())
}

/// Perfil ALL transparente, con contexto materializado y locks nativos completos.
/// No hace fallback por entrada, ni acepta Orchard si falta su verificador.
pub fn autorizar_cuerpo(
    b: &CuerpoCandidato,
    ctx: &ContextoIdentificado,
) -> Result<AutorizacionPerfil, Rechazo> {
    if b.orchard.is_some() {
        return Err(Rechazo::NoSoportado("Orchard sin verificador"));
    }
    if b.hash_type != HashType::All {
        return Err(Rechazo::NoSoportado("sólo perfil explícito SIGHASH_ALL"));
    }
    if b.cabecera.height != ctx.datos.altura {
        return Err(Rechazo::ContextoInvalido(
            "altura de cabecera distinta del contexto",
        ));
    }
    comprobar_branch_id(
        ctx.datos.red,
        ctx.datos.altura,
        b.cabecera.consensus_branch_id,
    )
    .map_err(Rechazo::Invalido)?;
    let coinbase = b
        .txs
        .first()
        .ok_or(Rechazo::Invalido(ConsensusError::BloqueSinCoinbase))?;
    if !coinbase.inputs.is_empty() {
        return Err(Rechazo::Invalido(ConsensusError::BloqueSinCoinbase));
    }
    if b.txs.iter().skip(1).any(|tx| tx.inputs.is_empty()) {
        return Err(Rechazo::Invalido(ConsensusError::CoinbaseFueraDeSitio));
    }
    if b.testigos.len() != b.txs.len() {
        return Err(Rechazo::Invalido(ConsensusError::TestigoMalFormado {
            motivo: "una lista por transacción",
        }));
    }
    for (tx, ws) in b.txs.iter().zip(&b.testigos) {
        if tx.version != 1 {
            return Err(Rechazo::Invalido(ConsensusError::VersionDeTxNoAdmitida {
                version: tx.version,
            }));
        }
        if tx.lock_time != 0 {
            return Err(Rechazo::NoSoportado(
                "lock_time distinto de cero: semántica pendiente",
            ));
        }
        if tx.outputs.is_empty() {
            return Err(Rechazo::NoSoportado(
                "perfil requiere salidas, incluida coinbase",
            ));
        }
        if ws.len() != tx.inputs.len() {
            return Err(Rechazo::Invalido(ConsensusError::TestigoMalFormado {
                motivo: "un testigo por entrada; ninguno para coinbase",
            }));
        }
        for salida in &tx.outputs {
            comprobar_lock(&salida.lock)?;
        }
        let peso = peso_tx(tx, ws);
        if peso > MAX_TX_WEIGHT {
            return Err(Rechazo::Invalido(ConsensusError::TxExcedeMaximo {
                peso,
                maximo: MAX_TX_WEIGHT,
            }));
        }
    }
    if coinbase.expiry_height != ctx.datos.altura {
        return Err(Rechazo::Invalido(ConsensusError::CoinbaseSinAltura {
            altura: ctx.datos.altura,
            expiry_height: coinbase.expiry_height,
        }));
    }
    let ids: Vec<_> = b
        .txs
        .iter()
        .map(|tx| txid(tx, b.cabecera.consensus_branch_id))
        .collect();
    if merkle_root(&ids) != b.cabecera.merkle_root {
        return Err(Rechazo::Invalido(ConsensusError::MerkleRootIncorrecta));
    }
    comprobar_sin_doble_gasto_en_bloque(&b.txs).map_err(Rechazo::Invalido)?;
    // Ninguna dependencia intra-cuerpo se simula como UTXO previo, ni por orden de llegada.
    if b.txs
        .iter()
        .flat_map(|tx| &tx.inputs)
        .any(|entrada| ids.contains(&entrada.outpoint.prev_txid))
    {
        return Err(Rechazo::NoSoportado(
            "gasto de transacción del mismo cuerpo",
        ));
    }
    if !ctx.datos.completo {
        return Err(Rechazo::ContextoIncompleto);
    }
    let mut faltantes = Vec::new();
    let mut gastadas = Vec::new();
    let mut inexistente = false;
    for entrada in b.txs.iter().flat_map(|tx| &tx.inputs) {
        match ctx.estado(&entrada.outpoint) {
            Some(EstadoSalida::Disponible(_)) => (),
            Some(EstadoSalida::Gastado) => gastadas.push(entrada.outpoint),
            Some(EstadoSalida::Inexistente) => inexistente = true,
            Some(EstadoSalida::Desconocido) | None => faltantes.push(entrada.outpoint),
        }
    }
    // Nunca convertir un lookup omitido en prueba de inexistencia, aunque completo=true.
    if !faltantes.is_empty() {
        return Err(Rechazo::Dependencias(faltantes));
    }
    if inexistente {
        return Err(Rechazo::Invalido(
            ConsensusError::EntradaInexistenteOGastada,
        ));
    }
    if !gastadas.is_empty() {
        return Err(Rechazo::GastadoEnSnapshot(gastadas));
    }
    let resultado = validar_cuerpo(
        &Bloque {
            cabecera: b.cabecera,
            txs: &b.txs,
            testigos: &b.testigos,
        },
        &ContextoBloque {
            red: ctx.datos.red,
            mediana_efectiva: ctx.datos.mediana_efectiva,
            emitido: ctx.datos.emitido,
            // Campos de cabecera antigua que validar_cuerpo NO consulta. No verifican PoW/PoT.
            target_esperado: Default::default(),
            ts_padre: 0,
            reloj_local: 0,
        },
        ctx,
    )
    .map_err(Rechazo::Invalido)?;
    for (tx, ws) in b.txs.iter().zip(&b.testigos).skip(1) {
        let salidas: Vec<_> = tx
            .inputs
            .iter()
            .map(|entrada| {
                ctx.buscar(&entrada.outpoint)
                    .map(|utxo| utxo.salida)
                    .ok_or(Rechazo::Dependencias(vec![entrada.outpoint]))
            })
            .collect::<Result<_, _>>()?;
        for (i, (salida, witness)) in salidas.iter().zip(ws).enumerate() {
            let digest = sighash(
                tx,
                &salidas,
                HashType::All,
                i,
                b.cabecera.consensus_branch_id,
            )
            .map_err(Rechazo::Codificacion)?;
            satisface(
                &salida.lock,
                witness,
                &digest,
                ContextoGasto {
                    altura: ctx.datos.altura,
                },
            )
            .map_err(Rechazo::Invalido)?;
        }
    }
    Ok(AutorizacionPerfil {
        cuerpo: b.clone(),
        body_key: b.body_key(),
        context_key: ctx.key,
        resultado,
    })
}
