//! **Relé compacto degradado** (C-NET-06, C-NET-08, C-NET-09, R-NET-01, R-NET-02).
//!
//! # Qué reemplaza esto
//!
//! El anuncio compacto manda la cabecera DAG, un nonce de transporte, la coinbase **completa** y
//! un identificador corto de seis bytes por cada transacción restante. El receptor intenta
//! reconstruir el bloque desde su mempool; lo que no consigue, lo pide **una vez**. Si aun así no
//! completa, el siguiente estado es **pedir el bloque completo**, no una segunda ronda compacta
//! sin límite. La máquina de estados ([`MaquinaRele`]) hace que esa segunda ronda sea
//! **inconstruible**, no una convención documentada.
//!
//! # Coste acotado por el receptor (H-02)
//!
//! [`reconstruir`] calcula el `txid` de cada candidato **una sola vez** y construye un
//! `HashMap<IdCorto, …>` que distingue «una coincidencia» de «más de una» contando, sin guardar
//! duplicados. Es `O(m)` hashes, no `O(n·m)`.
//!
//! # Lo que NO es
//!
//! No es un camino de consenso distinto: los bytes reconstruidos se validan con las mismas reglas.
//! La justificación PoT no viaja en el anuncio: llega por el canal PoT prioritario o con el bloque
//! completo. Si falta evidencia, el candidato queda [`EstadoRele::PendienteDeEvidencia`]: no se
//! adopta ni se marca inválido por ausencia.
//!
//! # Colisiones, timeouts y fallback no puntúan
//!
//! C-NET-08: una colisión de identificador corto se resuelve pidiendo la transacción entera y el
//! peer **no** se penaliza. C-NET-05: lento o mudo tampoco puntúa. Todo eso queda codificado en
//! [`FalloReconstruccion::puntua_al_peer`], que devuelve `false` para todas las causas previstas.

use std::collections::HashMap;

use thiserror::Error;

use zx_core::digest::{BlockHash, Digest, TxId};
use zx_core::encoding::{compact_size, int};
use zx_core::error::EncodingError;
use zx_core::preimage::block::merkle_root;
use zx_core::preimage::dag::{dag_header_a_bytes, dag_header_desde_bytes};
use zx_core::wire::{MAX_ELEMENTOS_DECLARADOS, tx_a_bytes, tx_desde_bytes};
use zx_core::wire_dag::IntegracionPotPendiente;
use zx_core::{DagBlockHeader, Tx, body_commitment, txid};

use crate::id_corto::{ClavesIdCorto, IdCorto, TAMANO_ID_CORTO};
use crate::presupuesto::{PRESUPUESTO_BYTES, Presupuesto};

/// Número máximo de transacciones de un anuncio compacto, acotado **antes** de reservar.
pub const MAX_TX_ANUNCIO: u64 = MAX_ELEMENTOS_DECLARADOS;

/// Presupuesto de bytes del relé: el mismo techo agregado de C-NET-21.
pub const PRESUPUESTO_BYTES_RELE: usize = PRESUPUESTO_BYTES;

/// Una transacción con sus testigos, tal y como viaja.
pub type TxConTestigos = (Tx, Vec<Vec<u8>>);

/// Un cuerpo completo: transacciones y, por transacción, sus testigos.
pub type CuerpoConTestigos = (Vec<Tx>, Vec<Vec<Vec<u8>>>);

/// Fallo de formato, de presupuesto o de correspondencia del relé compacto.
#[derive(Debug, Error, PartialEq, Eq, Clone)]
pub enum ReleError {
    /// Un anuncio declara más transacciones de las que el lector acepta.
    #[error("relé compacto: {declarados} transacciones anunciadas, máximo {maximo}")]
    DemasiadasTransacciones {
        /// Declaradas.
        declarados: u64,
        /// Cota del lector.
        maximo: u64,
    },

    /// La petición de faltantes no está en orden estrictamente creciente.
    #[error("petición de faltantes: los índices MUST ser estrictamente crecientes y únicos")]
    IndicesNoCanonicos,

    /// Un índice de la petición queda fuera del número de transacciones anunciado.
    #[error("petición de faltantes: índice {indice} fuera de {total} transacciones anunciadas")]
    IndiceFueraDeRango {
        /// Índice pedido.
        indice: u32,
        /// Total anunciado.
        total: usize,
    },

    /// La respuesta no trae una transacción cuyo identificador corto coincide con el anunciado.
    #[error("respuesta de faltantes: el short ID del índice {indice} no coincide con el anunciado")]
    RespuestaNoCorresponde {
        /// Índice comprobado.
        indice: u32,
    },

    /// La respuesta es de otro bloque que el candidato en curso.
    #[error("respuesta de faltantes: bloque {encontrado}, se esperaba {esperado}")]
    BloqueNoCoincide {
        /// Bloque de la respuesta.
        encontrado: BlockHash,
        /// Bloque del candidato en curso.
        esperado: BlockHash,
    },

    /// El número de transacciones de la respuesta no es el de la petición.
    #[error("respuesta de faltantes: {recibidas} transacciones para {pedidas} índices")]
    RecuentoRespuestaIncorrecto {
        /// Índices pedidos.
        pedidas: usize,
        /// Transacciones recibidas.
        recibidas: usize,
    },

    /// No queda presupuesto de memoria en vuelo (C-NET-21).
    #[error("C-NET-21: no queda presupuesto para parsear el mensaje del relé")]
    Presupuesto,

    /// Fallo de codificación del mensaje subyacente.
    #[error(transparent)]
    Codificacion(#[from] EncodingError),
}

/// Acota un contador declarado **antes** de que nadie reserve memoria por él (C-WIRE-04).
///
/// # Errores
/// [`ReleError::DemasiadasTransacciones`].
pub fn reserva_acotada(declarados: u64) -> Result<usize, ReleError> {
    if declarados > MAX_TX_ANUNCIO {
        return Err(ReleError::DemasiadasTransacciones {
            declarados,
            maximo: MAX_TX_ANUNCIO,
        });
    }
    usize::try_from(declarados).map_err(|_| ReleError::DemasiadasTransacciones {
        declarados,
        maximo: MAX_TX_ANUNCIO,
    })
}

/// Anuncio compacto: cabecera DAG, nonce, coinbase completa e identificadores del resto.
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct AnuncioCompacto {
    /// Cabecera DAG anunciada.
    pub cabecera: DagBlockHeader,
    /// Nonce de transporte de C-NET-07 (clave de los identificadores cortos).
    pub nonce_transporte: u64,
    /// Coinbase prefilled, completa y con sus testigos.
    pub coinbase: Tx,
    /// Testigos de la coinbase, en el mismo orden que sus entradas.
    pub testigos_coinbase: Vec<Vec<u8>>,
    /// Un identificador corto por cada transacción restante, en orden.
    pub ids_restantes: Vec<IdCorto>,
}

impl AnuncioCompacto {
    /// Construye un anuncio acotando el número de transacciones.
    ///
    /// # Errores
    /// [`ReleError::DemasiadasTransacciones`].
    pub fn nuevo(
        cabecera: DagBlockHeader,
        nonce_transporte: u64,
        coinbase: Tx,
        testigos_coinbase: Vec<Vec<u8>>,
        ids_restantes: Vec<IdCorto>,
    ) -> Result<Self, ReleError> {
        let total = ids_restantes.len() as u64 + 1;
        if total > MAX_TX_ANUNCIO {
            return Err(ReleError::DemasiadasTransacciones {
                declarados: total,
                maximo: MAX_TX_ANUNCIO,
            });
        }
        Ok(Self {
            cabecera,
            nonce_transporte,
            coinbase,
            testigos_coinbase,
            ids_restantes,
        })
    }

    /// Número total de transacciones anunciadas, coinbase incluida.
    #[must_use]
    pub fn total_txs(&self) -> usize {
        self.ids_restantes.len() + 1
    }

    /// Las claves de SipHash derivadas de la cabecera y el nonce.
    #[must_use]
    pub fn claves(&self) -> ClavesIdCorto {
        ClavesIdCorto::derivar_dag(&self.cabecera, self.nonce_transporte)
    }

    /// El identificador anunciado en el índice `i` (0 es la coinbase).
    #[must_use]
    pub fn id_en(&self, i: usize) -> Option<IdCorto> {
        self.ids_restantes.get(i.checked_sub(1)?).copied()
    }

    /// `cabecera_dag ‖ nonce(8 LE) ‖ CompactSize(n_restantes) ‖ ids ‖ coinbase con testigos`.
    #[must_use]
    pub fn a_bytes(&self) -> Vec<u8> {
        let mut v = dag_header_a_bytes(&self.cabecera);
        int::escribir_u64(&mut v, self.nonce_transporte);
        compact_size::escribir(&mut v, self.ids_restantes.len() as u64);
        for id in &self.ids_restantes {
            v.extend_from_slice(id);
        }
        tx_a_bytes(&mut v, &self.coinbase, &self.testigos_coinbase);
        v
    }

    /// Lee un anuncio, acotando el contador antes de reservar y aduciendo el presupuesto.
    ///
    /// # Errores
    /// [`ReleError`] de formato o de presupuesto; el error de codificación subyacente.
    pub fn desde_bytes<'a>(
        bytes: &'a [u8],
        presupuesto: &Presupuesto,
    ) -> Result<(Self, &'a [u8]), ReleError> {
        let _reserva = presupuesto
            .reservar(bytes.len())
            .ok_or(ReleError::Presupuesto)?;
        let (cabecera, r) = dag_header_desde_bytes(bytes)?;
        let (nonce_transporte, r) = int::leer_u64(r)?;
        let (n, r) = compact_size::leer(r)?;
        let n = reserva_acotada(n)?;
        let (ids_bytes, r) =
            r.split_at_checked(n * TAMANO_ID_CORTO)
                .ok_or(EncodingError::Truncado {
                    esperados: n * TAMANO_ID_CORTO,
                    disponibles: r.len(),
                })?;
        let mut ids_restantes = Vec::with_capacity(n);
        for trozo in ids_bytes.chunks_exact(TAMANO_ID_CORTO) {
            let mut id = [0u8; TAMANO_ID_CORTO];
            id.copy_from_slice(trozo);
            ids_restantes.push(id);
        }
        let ((coinbase, testigos_coinbase), resto) = tx_desde_bytes(r)?;
        Ok((
            Self {
                cabecera,
                nonce_transporte,
                coinbase,
                testigos_coinbase,
                ids_restantes,
            },
            resto,
        ))
    }
}

/// Una transacción candidata del mempool, con sus testigos.
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct CandidatoMempool {
    /// Transacción.
    pub tx: Tx,
    /// Testigos de la transacción.
    pub testigos: Vec<Vec<u8>>,
}

/// Estado de reconstrucción de un anuncio.
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct Reconstruccion {
    anuncio: AnuncioCompacto,
    txs: Vec<Option<Tx>>,
    testigos: Vec<Option<Vec<Vec<u8>>>>,
    faltantes: Vec<u32>,
    ambiguos: Vec<u32>,
}

impl Reconstruccion {
    /// Una reconstrucción con la coinbase ya colocada.
    #[must_use]
    pub fn para(anuncio: &AnuncioCompacto) -> Self {
        let total = anuncio.total_txs();
        let mut rec = Self {
            anuncio: anuncio.clone(),
            txs: vec![None; total],
            testigos: vec![None; total],
            faltantes: Vec::new(),
            ambiguos: Vec::new(),
        };
        rec.rellenar(
            0,
            anuncio.coinbase.clone(),
            anuncio.testigos_coinbase.clone(),
        );
        rec
    }

    /// ¿Están todas las posiciones rellenas?
    #[must_use]
    pub fn esta_completa(&self) -> bool {
        self.txs.iter().all(Option::is_some)
    }

    /// Índices que no se pudieron rellenar (ausencia o ambigüedad).
    #[must_use]
    pub fn faltantes(&self) -> &[u32] {
        &self.faltantes
    }

    /// Índices con más de una coincidencia en el mempool.
    #[must_use]
    pub fn ambiguos(&self) -> &[u32] {
        &self.ambiguos
    }

    /// La transacción rellena en el índice, si la hay.
    #[must_use]
    pub fn tx_en(&self, i: usize) -> Option<&Tx> {
        self.txs.get(i).and_then(Option::as_ref)
    }

    /// Las transacciones y testigos, en orden. `None` si falta alguna.
    #[must_use]
    pub fn completas(&self) -> Option<CuerpoConTestigos> {
        let mut txs = Vec::with_capacity(self.txs.len());
        let mut testigos = Vec::with_capacity(self.txs.len());
        for (t, w) in self.txs.iter().zip(&self.testigos) {
            txs.push(t.clone()?);
            testigos.push(w.clone()?);
        }
        Some((txs, testigos))
    }

    /// El anuncio que se está reconstruyendo.
    #[must_use]
    pub fn anuncio(&self) -> &AnuncioCompacto {
        &self.anuncio
    }

    fn rellenar(&mut self, i: usize, tx: Tx, testigos: Vec<Vec<u8>>) {
        if let (Some(ts), Some(ws)) = (self.txs.get_mut(i), self.testigos.get_mut(i)) {
            *ts = Some(tx);
            *ws = Some(testigos);
        }
    }
}

/// Reconstruye el bloque desde el mempool calculando **un** `txid` por candidato (H-02).
///
/// Es una primitiva genérica sobre la función `calcular_txid` para que un test pueda contar las
/// invocaciones. El camino de producción es [`reconstruir`].
fn reconstruir_con<F: Fn(&Tx) -> TxId>(
    anuncio: &AnuncioCompacto,
    mempool: &[CandidatoMempool],
    calcular_txid: F,
) -> Reconstruccion {
    let claves = anuncio.claves();
    // Índice construido UNA vez: id → (conteo, primer candidato). No guarda duplicados.
    let mut indice: HashMap<IdCorto, (u16, &CandidatoMempool)> =
        HashMap::with_capacity(mempool.len());
    for cand in mempool {
        let txid = calcular_txid(&cand.tx);
        let id = claves.id(&txid);
        match indice.get_mut(&id) {
            Some((n, _)) => *n = n.saturating_add(1),
            None => {
                indice.insert(id, (1, cand));
            }
        }
    }

    let mut rec = Reconstruccion::para(anuncio);
    for i in 1..anuncio.total_txs() {
        let Some(id_anunciado) = anuncio.id_en(i) else {
            continue;
        };
        match indice.get(&id_anunciado) {
            // Exactamente una coincidencia: rellena.
            Some((1, cand)) => rec.rellenar(i, cand.tx.clone(), cand.testigos.clone()),
            // Ninguna: faltante.
            None => rec.faltantes.push(i as u32),
            // Más de una: ambiguo **y** faltante (C-NET-08, sin penalizar).
            Some(_) => {
                rec.ambiguos.push(i as u32);
                rec.faltantes.push(i as u32);
            }
        }
    }
    rec
}

/// Reconstruye el bloque desde el mempool. `O(m)` hashes de transacción.
#[must_use]
pub fn reconstruir(anuncio: &AnuncioCompacto, mempool: &[CandidatoMempool]) -> Reconstruccion {
    let cbid = anuncio.cabecera.consensus_branch_id;
    reconstruir_con(anuncio, mempool, |tx| txid(tx, cbid))
}

/// Una única petición de faltantes, correlacionada por `block_hash` (H-03).
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct PeticionFaltantes {
    bloque: BlockHash,
    indices: Vec<u32>,
}

impl PeticionFaltantes {
    /// Construye la petición validando orden, unicidad y rango.
    ///
    /// # Errores
    /// [`ReleError::IndicesNoCanonicos`] o [`ReleError::IndiceFueraDeRango`].
    pub fn nueva(bloque: BlockHash, indices: &[u32], total: usize) -> Result<Self, ReleError> {
        let mut anterior: Option<u32> = None;
        for &i in indices {
            if let Some(a) = anterior
                && i <= a
            {
                return Err(ReleError::IndicesNoCanonicos);
            }
            if i as usize >= total {
                return Err(ReleError::IndiceFueraDeRango { indice: i, total });
            }
            anterior = Some(i);
        }
        Ok(Self {
            bloque,
            indices: indices.to_vec(),
        })
    }

    /// El bloque al que se refiere la petición.
    #[must_use]
    pub const fn bloque(&self) -> BlockHash {
        self.bloque
    }

    /// Los índices pedidos.
    #[must_use]
    pub fn indices(&self) -> &[u32] {
        &self.indices
    }

    /// `block_hash(32) ‖ CompactSize(n) ‖ n × u32 LE`.
    #[must_use]
    pub fn a_bytes(&self) -> Vec<u8> {
        let mut v = Vec::new();
        v.extend_from_slice(self.bloque.as_bytes());
        compact_size::escribir(&mut v, self.indices.len() as u64);
        for i in &self.indices {
            int::escribir_u32(&mut v, *i);
        }
        v
    }

    /// Lee una petición y valida orden, rango y presupuesto.
    ///
    /// # Errores
    /// El error de codificación o de validación que corresponda.
    pub fn desde_bytes<'a>(
        bytes: &'a [u8],
        total: usize,
        presupuesto: &Presupuesto,
    ) -> Result<(Self, &'a [u8]), ReleError> {
        let _reserva = presupuesto
            .reservar(bytes.len())
            .ok_or(ReleError::Presupuesto)?;
        let (bloque, r) = int::leer_32(bytes)?;
        let (n, r) = compact_size::leer(r)?;
        let n = reserva_acotada(n)?;
        let mut indices = Vec::with_capacity(n);
        let mut r = r;
        for _ in 0..n {
            let (i, resto) = int::leer_u32(r)?;
            indices.push(i);
            r = resto;
        }
        let p = Self::nueva(
            BlockHash::from_digest(Digest::from_bytes(bloque)),
            &indices,
            total,
        )?;
        Ok((p, r))
    }
}

/// Respuesta con las transacciones completas solicitadas, en el mismo orden que la petición.
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct RespuestaFaltantes {
    /// Bloque al que corresponde la respuesta.
    pub bloque: BlockHash,
    /// Pares `(transacción, testigos)`, en el orden de la petición.
    pub transacciones: Vec<TxConTestigos>,
}

impl RespuestaFaltantes {
    /// Aplica la respuesta a una reconstrucción en curso.
    ///
    /// Comprueba, en este orden: que el bloque coincide con el de la petición y el anuncio; el
    /// recuento; y que cada transacción tenga el identificador corto anunciado en su índice.
    ///
    /// # Errores
    /// [`ReleError::BloqueNoCoincide`], [`ReleError::RecuentoRespuestaIncorrecto`] o
    /// [`ReleError::RespuestaNoCorresponde`].
    pub fn aplicar(
        &self,
        peticion: &PeticionFaltantes,
        rec: &mut Reconstruccion,
    ) -> Result<(), ReleError> {
        let esperado = rec.anuncio().cabecera.block_hash();
        if peticion.bloque != esperado {
            return Err(ReleError::BloqueNoCoincide {
                encontrado: peticion.bloque,
                esperado,
            });
        }
        if self.bloque != peticion.bloque {
            return Err(ReleError::BloqueNoCoincide {
                encontrado: self.bloque,
                esperado,
            });
        }
        if self.transacciones.len() != peticion.indices.len() {
            return Err(ReleError::RecuentoRespuestaIncorrecto {
                pedidas: peticion.indices.len(),
                recibidas: self.transacciones.len(),
            });
        }
        let claves = rec.anuncio().claves();
        for (k, (tx, testigos)) in self.transacciones.iter().enumerate() {
            let Some(&i) = peticion.indices.get(k) else {
                continue;
            };
            let Some(id_anunciado) = rec.anuncio().id_en(i as usize) else {
                return Err(ReleError::IndiceFueraDeRango {
                    indice: i,
                    total: rec.anuncio().total_txs(),
                });
            };
            let txid = txid(tx, rec.anuncio().cabecera.consensus_branch_id);
            if claves.id(&txid) != id_anunciado {
                return Err(ReleError::RespuestaNoCorresponde { indice: i });
            }
            rec.rellenar(i as usize, tx.clone(), testigos.clone());
            rec.faltantes.retain(|&f| f != i);
            rec.ambiguos.retain(|&a| a != i);
        }
        Ok(())
    }

    /// `block_hash(32) ‖ CompactSize(n) ‖ n × (tx con testigos)`.
    #[must_use]
    pub fn a_bytes(&self) -> Vec<u8> {
        let mut v = Vec::new();
        v.extend_from_slice(self.bloque.as_bytes());
        compact_size::escribir(&mut v, self.transacciones.len() as u64);
        for (tx, testigos) in &self.transacciones {
            tx_a_bytes(&mut v, tx, testigos);
        }
        v
    }

    /// Lee una respuesta, acotando el contador antes de reservar y aduciendo el presupuesto.
    ///
    /// # Errores
    /// [`ReleError`] de formato o de presupuesto; el error de codificación subyacente.
    pub fn desde_bytes<'a>(
        bytes: &'a [u8],
        presupuesto: &Presupuesto,
    ) -> Result<(Self, &'a [u8]), ReleError> {
        let _reserva = presupuesto
            .reservar(bytes.len())
            .ok_or(ReleError::Presupuesto)?;
        let (bloque, r) = int::leer_32(bytes)?;
        let (n, mut r) = compact_size::leer(r)?;
        let n = reserva_acotada(n)?;
        let mut transacciones = Vec::with_capacity(n);
        for _ in 0..n {
            let ((tx, t), resto) = tx_desde_bytes(r)?;
            transacciones.push((tx, t));
            r = resto;
        }
        Ok((
            Self {
                bloque: BlockHash::from_digest(Digest::from_bytes(bloque)),
                transacciones,
            },
            r,
        ))
    }
}

/// Por qué no se pudo completar el bloque por el camino compacto.
///
/// Todas las causas previstas **no puntúan** al peer y llevan al mismo fallback **terminal**: pedir
/// el bloque completo. No hay una segunda ronda compacta ilimitada.
#[derive(Debug, Error, PartialEq, Eq, Clone)]
pub enum FalloReconstruccion {
    /// El anuncio no se pudo empezar a reconstruir: sin mempool.
    #[error("relé compacto: sin mempool disponible")]
    SinMempool,
    /// Uno o más identificadores cortos colisionaron (C-NET-08).
    #[error("relé compacto: colisión de identificador corto, se pide la transacción entera")]
    Colision,
    /// La reconstrucción quedó incompleta tras la única ronda de petición.
    #[error("relé compacto: reconstrucción incompleta")]
    ReconstruccionIncompleta,
    /// La respuesta no corresponde a la petición.
    #[error("relé compacto: la respuesta no corresponde")]
    RespuestaNoCorresponde,
    /// Venció el timeout de la capa llamante.
    #[error("relé compacto: timeout")]
    Timeout,
    /// La raíz de Merkle recalculada no coincide (C-NET-09).
    #[error("C-NET-09: la raíz de Merkle del bloque reconstruido no coincide")]
    CompromisoMerkleFallido,
    /// El compromiso completo del cuerpo no coincide.
    #[error("relé compacto: el compromiso del cuerpo no coincide")]
    CompromisoCuerpoFallido,
}

impl FalloReconstruccion {
    /// ¿Estas causas puntúan hacia el baneo del peer? **Ninguna de las previstas.**
    #[must_use]
    pub const fn puntua_al_peer(&self) -> bool {
        false
    }

    /// El fallback es **terminal**: siempre el bloque completo.
    #[must_use]
    pub const fn siguiente_estado(&self) -> EstadoRele {
        EstadoRele::PeticionBloqueCompleto
    }
}

/// Estado del candidato en el relé (FSM de la §2.3 del encargo).
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum EstadoRele {
    /// Anuncio recibido, aún sin reconstruir.
    Anunciado,
    /// Se pidieron las transacciones faltantes; **solo una vez**.
    EsperandoFaltantes,
    /// Bloque reconstruido y compromisos comprobados.
    Reconstruido,
    /// Reconstruido, pero la justificación PoT todavía no está verificada. Ni se adopta ni se marca
    /// inválido por ausencia.
    PendienteDeEvidencia,
    /// Fallback **terminal**: se pide el bloque completo.
    PeticionBloqueCompleto,
}

impl EstadoRele {
    /// ¿Es terminal?
    #[must_use]
    pub const fn es_terminal(self) -> bool {
        matches!(self, Self::PeticionBloqueCompleto)
    }
}

/// Máquina de estados del relé.
///
/// Hace **inconstruible** la segunda ronda compacta: ninguna transición devuelve a
/// [`EstadoRele::EsperandoFaltantes`], y `reconstruir`/`aplicar_respuesta` fuera de su estado
/// llevan a [`EstadoRele::PeticionBloqueCompleto`].
#[derive(Clone, Debug)]
pub struct MaquinaRele {
    anuncio: AnuncioCompacto,
    reconstruccion: Reconstruccion,
    estado: EstadoRele,
}

impl MaquinaRele {
    /// Arranca en [`EstadoRele::Anunciado`].
    #[must_use]
    pub fn nueva(anuncio: AnuncioCompacto) -> Self {
        let reconstruccion = Reconstruccion::para(&anuncio);
        Self {
            anuncio,
            reconstruccion,
            estado: EstadoRele::Anunciado,
        }
    }

    /// Estado actual.
    #[must_use]
    pub const fn estado(&self) -> EstadoRele {
        self.estado
    }

    /// El anuncio.
    #[must_use]
    pub fn anuncio(&self) -> &AnuncioCompacto {
        &self.anuncio
    }

    /// La reconstrucción en curso.
    #[must_use]
    pub fn reconstruccion(&self) -> &Reconstruccion {
        &self.reconstruccion
    }

    /// Transición `Anunciado ─ reconstruir`.
    ///
    /// Si no se está en `Anunciado`, **no** se reintenta: se va al fallback terminal.
    pub fn reconstruir(&mut self, mempool: &[CandidatoMempool]) -> EstadoRele {
        if self.estado != EstadoRele::Anunciado {
            self.estado = EstadoRele::PeticionBloqueCompleto;
            return self.estado;
        }
        self.reconstruccion = reconstruir(&self.anuncio, mempool);
        self.estado = self.evaluar();
        self.estado
    }

    /// Transición `EsperandoFaltantes ─ aplicar`.
    ///
    /// Nunca vuelve a `EsperandoFaltantes`: o `Reconstruido`, o terminal.
    pub fn aplicar_respuesta(
        &mut self,
        peticion: &PeticionFaltantes,
        respuesta: &RespuestaFaltantes,
    ) -> EstadoRele {
        if self.estado != EstadoRele::EsperandoFaltantes {
            self.estado = EstadoRele::PeticionBloqueCompleto;
            return self.estado;
        }
        match respuesta.aplicar(peticion, &mut self.reconstruccion) {
            Ok(()) if self.reconstruccion.esta_completa() && self.compromisos_ok() => {
                self.estado = EstadoRele::Reconstruido;
            }
            // Respuesta ajena, recuento distinto o compromisos que fallan: terminal.
            _ => self.estado = EstadoRele::PeticionBloqueCompleto,
        }
        self.estado
    }

    /// Transición `Reconstruido ─ sin justificación PoT verificada`.
    ///
    /// Deja el candidato en [`EstadoRele::PendienteDeEvidencia`] y devuelve el estado explícito de
    /// integración pendiente de `wire_dag`. No hay `Ok(())` fabricado.
    ///
    /// # Errores
    /// [`IntegracionPotPendiente`] mientras el verificador PoT no esté integrado.
    pub fn esperar_evidencia(&mut self) -> Result<EstadoRele, IntegracionPotPendiente> {
        if self.estado != EstadoRele::Reconstruido {
            return Ok(self.estado);
        }
        self.estado = EstadoRele::PendienteDeEvidencia;
        Err(IntegracionPotPendiente(
            "el bloque reconstruyó, pero la justificación PoT no está verificada",
        ))
    }

    /// Evalúa una reconstrucción recién hecha.
    fn evaluar(&mut self) -> EstadoRele {
        if self.reconstruccion.esta_completa() {
            if self.compromisos_ok() {
                EstadoRele::Reconstruido
            } else {
                EstadoRele::PeticionBloqueCompleto
            }
        } else {
            // Faltantes o ambiguos: primera y única ronda compacta.
            EstadoRele::EsperandoFaltantes
        }
    }

    fn compromisos_ok(&self) -> bool {
        comprobar_completitud_y_compromisos(&self.anuncio, &self.reconstruccion).is_ok()
    }
}

/// Comprueba que la reconstrucción está completa y que los dos compromisos cuadran.
///
/// # Errores
/// [`FalloReconstruccion`] con la primera causa que falle.
pub fn comprobar_completitud_y_compromisos(
    anuncio: &AnuncioCompacto,
    rec: &Reconstruccion,
) -> Result<(), FalloReconstruccion> {
    if !rec.esta_completa() {
        return Err(FalloReconstruccion::ReconstruccionIncompleta);
    }
    let Some((txs, testigos)) = rec.completas() else {
        return Err(FalloReconstruccion::ReconstruccionIncompleta);
    };
    // C-NET-09: la raíz recalculada debe coincidir con la comprometida en la cabecera.
    let txids: Vec<TxId> = txs
        .iter()
        .map(|t| txid(t, anuncio.cabecera.consensus_branch_id))
        .collect();
    if merkle_root(&txids) != anuncio.cabecera.merkle_root {
        return Err(FalloReconstruccion::CompromisoMerkleFallido);
    }
    match body_commitment(&txs, &testigos, anuncio.cabecera.consensus_branch_id) {
        Ok(b) if b == anuncio.cabecera.body_commitment => Ok(()),
        _ => Err(FalloReconstruccion::CompromisoCuerpoFallido),
    }
}

#[cfg(test)]
#[expect(clippy::unwrap_used, reason = "los tests fallan con panic por diseño")]
#[expect(
    clippy::indexing_slicing,
    reason = "índices constantes sobre vectores construidos en el propio test"
)]
mod tests {
    use super::{
        AnuncioCompacto, CandidatoMempool, EstadoRele, FalloReconstruccion, MaquinaRele,
        PRESUPUESTO_BYTES_RELE, PeticionFaltantes, Reconstruccion, ReleError, RespuestaFaltantes,
        comprobar_completitud_y_compromisos, reconstruir, reconstruir_con, reserva_acotada,
    };
    use crate::id_corto::{ClavesIdCorto, TAMANO_ID_CORTO};
    use crate::presupuesto::Presupuesto;
    use std::cell::Cell;
    use zx_core::digest::{BlockHash, Digest, TxId};
    use zx_core::firma::ClavePublica;
    use zx_core::preimage::block::merkle_root;
    use zx_core::preimage::dag::{DagBlockHeader, PadresDag, SolucionPoas};
    use zx_core::tx::{Lock, OutPoint, Tx, TxIn, TxOut};
    use zx_core::{Amount, body_commitment, txid};

    const CBID: u32 = 0xc478_80ea;

    fn tx(n: u8, salida: i64) -> Tx {
        Tx {
            version: 1,
            inputs: vec![TxIn {
                outpoint: OutPoint {
                    prev_txid: TxId::from_digest(Digest::from_bytes([n; 32])),
                    prev_index: 0,
                },
                sequence: 0,
            }],
            outputs: vec![TxOut {
                value: Amount::nuevo(salida).unwrap(),
                lock: Lock::PubKey {
                    pubkey: ClavePublica::desde_bytes([n; 32]),
                },
            }],
            lock_time: 0,
            expiry_height: 0,
        }
    }

    /// Construye un bloque de 4 transacciones y su anuncio coherente.
    fn fixture() -> (AnuncioCompacto, Vec<CandidatoMempool>) {
        let txs = vec![tx(1, 5_000), tx(2, 1_000), tx(3, 1_000), tx(4, 1_000)];
        let testigos: Vec<Vec<Vec<u8>>> = (1..=4u8).map(|n| vec![vec![n; 64]]).collect();
        let txids: Vec<TxId> = txs.iter().map(|t| txid(t, CBID)).collect();
        let nonce = 0x1122_3344_5566_7788u64;

        let cabecera = DagBlockHeader {
            consensus_branch_id: CBID,
            merkle_root: merkle_root(&txids),
            timestamp: 1_788_480_000,
            height: 1,
            slot: 1,
            pot_output: [0; 16],
            rango_solucion: 1,
            sol: SolucionPoas::default(),
            body_commitment: body_commitment(&txs, &testigos, CBID).unwrap(),
            padres: PadresDag::nuevo(BlockHash::from_digest(Digest::from_bytes([9; 32])), &[])
                .unwrap(),
            sello: [0; 64],
        };

        let claves = ClavesIdCorto::derivar_dag(&cabecera, nonce);
        let ids_restantes: Vec<[u8; TAMANO_ID_CORTO]> =
            txids[1..].iter().map(|t| claves.id(t)).collect();
        let anuncio = AnuncioCompacto::nuevo(
            cabecera,
            nonce,
            txs[0].clone(),
            testigos[0].clone(),
            ids_restantes,
        )
        .unwrap();

        let mempool = vec![
            CandidatoMempool {
                tx: txs[1].clone(),
                testigos: testigos[1].clone(),
            },
            CandidatoMempool {
                tx: txs[2].clone(),
                testigos: testigos[2].clone(),
            },
        ];
        (anuncio, mempool)
    }

    // ── H-02 · coste O(m) y reserva real ─────────────────────────────────────

    /// El `txid` se calcula exactamente una vez por candidato, no una vez por (tx anunciada,
    /// candidato).
    #[test]
    fn el_txid_se_calcula_una_vez_por_candidato() {
        let (anuncio, mempool) = fixture();
        let llamadas = Cell::new(0usize);
        let rec = reconstruir_con(&anuncio, &mempool, |t| {
            llamadas.set(llamadas.get() + 1);
            txid(t, CBID)
        });
        assert_eq!(rec.faltantes(), &[3u32]);
        assert_eq!(
            llamadas.get(),
            mempool.len(),
            "una vez por candidato, no mempool*anuncio"
        );
        assert_ne!(llamadas.get(), mempool.len() * anuncio.total_txs());
    }

    /// El contador declarado se acota **en el códec**, no en una función suelta.
    #[test]
    fn el_codec_acota_el_contador_antes_de_reservar() {
        use zx_core::encoding::compact_size;
        let (anuncio, _) = fixture();
        let mut bytes = anuncio.cabecera.a_bytes();
        bytes.extend_from_slice(&0u64.to_le_bytes()); // nonce
        compact_size::escribir(&mut bytes, u64::MAX); // n_restantes mentiroso
        // …y nada más.
        assert!(matches!(
            AnuncioCompacto::desde_bytes(&bytes, &Presupuesto::default()),
            Err(ReleError::DemasiadasTransacciones { .. })
        ));

        // Lo mismo en la respuesta.
        let mut rb = vec![0u8; 32];
        compact_size::escribir(&mut rb, u64::MAX);
        assert!(matches!(
            RespuestaFaltantes::desde_bytes(&rb, &Presupuesto::default()),
            Err(ReleError::DemasiadasTransacciones { .. })
        ));
    }

    /// El presupuesto del códec puede agotarse y provocar rechazo.
    #[test]
    fn el_codec_respeta_el_presupuesto() {
        let (anuncio, _) = fixture();
        let bytes = anuncio.a_bytes();
        let p = Presupuesto::nuevo(4);
        assert_eq!(
            AnuncioCompacto::desde_bytes(&bytes, &p),
            Err(ReleError::Presupuesto)
        );
        assert_eq!(p.en_vuelo(), 0, "la reserva se devuelve al fallar");
    }

    #[test]
    fn la_reserva_se_acota_antes_de_leer() {
        assert_eq!(reserva_acotada(4).unwrap(), 4);
        assert!(matches!(
            reserva_acotada(u64::MAX),
            Err(ReleError::DemasiadasTransacciones { .. })
        ));
    }

    // ── Códecs de anuncio y respuesta ────────────────────────────────────────

    #[test]
    fn el_anuncio_da_la_vuelta() {
        let (anuncio, _) = fixture();
        let bytes = anuncio.a_bytes();
        let (leido, resto) = AnuncioCompacto::desde_bytes(&bytes, &Presupuesto::default()).unwrap();
        assert_eq!(leido, anuncio);
        assert!(resto.is_empty());
    }

    #[test]
    fn la_respuesta_da_la_vuelta() {
        let r = RespuestaFaltantes {
            bloque: BlockHash::from_digest(Digest::from_bytes([7; 32])),
            transacciones: vec![(tx(4, 1_000), vec![vec![4; 64]])],
        };
        let bytes = r.a_bytes();
        let (leido, resto) =
            RespuestaFaltantes::desde_bytes(&bytes, &Presupuesto::default()).unwrap();
        assert_eq!(leido, r);
        assert!(resto.is_empty());
    }

    // ── Reconstrucción ───────────────────────────────────────────────────────

    #[test]
    fn reconstruccion_completa_cuando_esta_todo() {
        let (anuncio, mut mempool) = fixture();
        mempool.push(CandidatoMempool {
            tx: tx(4, 1_000),
            testigos: vec![vec![4; 64]],
        });
        let rec = reconstruir(&anuncio, &mempool);
        assert!(rec.esta_completa());
        assert!(rec.faltantes().is_empty());
        assert!(comprobar_completitud_y_compromisos(&anuncio, &rec).is_ok());
    }

    #[test]
    fn faltante_y_peticion_de_indices() {
        let (anuncio, mempool) = fixture();
        let rec = reconstruir(&anuncio, &mempool);
        assert_eq!(rec.faltantes(), &[3u32], "falta el índice 3");

        let p = PeticionFaltantes::nueva(
            anuncio.cabecera.block_hash(),
            rec.faltantes(),
            anuncio.total_txs(),
        )
        .unwrap();
        let bytes = p.a_bytes();
        let (leida, resto) =
            PeticionFaltantes::desde_bytes(&bytes, anuncio.total_txs(), &Presupuesto::default())
                .unwrap();
        assert_eq!(leida, p);
        assert!(resto.is_empty());

        assert_eq!(
            comprobar_completitud_y_compromisos(&anuncio, &rec),
            Err(FalloReconstruccion::ReconstruccionIncompleta)
        );
    }

    #[test]
    fn indice_repetido_desordenado_o_fuera_de_rango() {
        let b = BlockHash::from_digest(Digest::from_bytes([1; 32]));
        assert_eq!(
            PeticionFaltantes::nueva(b, &[2, 2], 10),
            Err(ReleError::IndicesNoCanonicos)
        );
        assert_eq!(
            PeticionFaltantes::nueva(b, &[3, 2], 10),
            Err(ReleError::IndicesNoCanonicos)
        );
        assert_eq!(
            PeticionFaltantes::nueva(b, &[10], 10),
            Err(ReleError::IndiceFueraDeRango {
                indice: 10,
                total: 10
            })
        );
    }

    #[test]
    fn colision_marca_ambiguo_y_faltante() {
        let (anuncio, mut mempool) = fixture();
        mempool.push(CandidatoMempool {
            tx: tx(3, 1_000),
            testigos: vec![vec![0xEE; 64]],
        });
        let rec = reconstruir(&anuncio, &mempool);
        assert!(
            rec.ambiguos().contains(&2),
            "índice 2 ambiguo: {:?}",
            rec.ambiguos()
        );
        assert!(rec.faltantes().contains(&2));
    }

    #[test]
    fn respuesta_correcta_completa_el_bloque() {
        let (anuncio, mempool) = fixture();
        let mut rec = reconstruir(&anuncio, &mempool);
        let p = PeticionFaltantes::nueva(
            anuncio.cabecera.block_hash(),
            rec.faltantes(),
            anuncio.total_txs(),
        )
        .unwrap();
        let respuesta = RespuestaFaltantes {
            bloque: anuncio.cabecera.block_hash(),
            transacciones: vec![(tx(4, 1_000), vec![vec![4; 64]])],
        };
        respuesta.aplicar(&p, &mut rec).unwrap();
        assert!(rec.esta_completa());
        assert!(comprobar_completitud_y_compromisos(&anuncio, &rec).is_ok());
    }

    #[test]
    fn respuesta_ajena_se_rechaza() {
        let (anuncio, mempool) = fixture();
        let mut rec = reconstruir(&anuncio, &mempool);
        let p = PeticionFaltantes::nueva(
            anuncio.cabecera.block_hash(),
            rec.faltantes(),
            anuncio.total_txs(),
        )
        .unwrap();
        let respuesta = RespuestaFaltantes {
            bloque: anuncio.cabecera.block_hash(),
            transacciones: vec![(tx(9, 1_000), vec![vec![9; 64]])],
        };
        assert!(matches!(
            respuesta.aplicar(&p, &mut rec),
            Err(ReleError::RespuestaNoCorresponde { .. })
        ));
    }

    /// **H-03 §2.2** · Una respuesta de otro bloque no se puede aplicar al candidato en curso.
    #[test]
    fn la_respuesta_se_correlaciona_por_block_hash() {
        let (a1, mempool1) = fixture();
        let mut a2 = a1.clone();
        a2.cabecera.height += 1;
        assert_ne!(a1.cabecera.block_hash(), a2.cabecera.block_hash());

        // Petición del anuncio 1, respuesta con el bloque del anuncio 2.
        let mut rec1 = MaquinaRele::nueva(a1);
        assert_eq!(rec1.reconstruir(&mempool1), EstadoRele::EsperandoFaltantes);
        let p1 = PeticionFaltantes::nueva(
            rec1.anuncio().cabecera.block_hash(),
            rec1.reconstruccion().faltantes(),
            rec1.anuncio().total_txs(),
        )
        .unwrap();
        let respuesta = RespuestaFaltantes {
            bloque: a2.cabecera.block_hash(),
            transacciones: vec![(tx(4, 1_000), vec![vec![4; 64]])],
        };
        assert_eq!(
            rec1.aplicar_respuesta(&p1, &respuesta),
            EstadoRele::PeticionBloqueCompleto
        );
    }

    #[test]
    fn recuento_incorrecto_se_rechaza() {
        let (anuncio, mempool) = fixture();
        let mut rec = reconstruir(&anuncio, &mempool);
        let p = PeticionFaltantes::nueva(
            anuncio.cabecera.block_hash(),
            rec.faltantes(),
            anuncio.total_txs(),
        )
        .unwrap();
        let respuesta = RespuestaFaltantes {
            bloque: anuncio.cabecera.block_hash(),
            transacciones: Vec::new(),
        };
        assert_eq!(
            respuesta.aplicar(&p, &mut rec),
            Err(ReleError::RecuentoRespuestaIncorrecto {
                pedidas: 1,
                recibidas: 0
            })
        );
    }

    // ── FSM ──────────────────────────────────────────────────────────────────

    #[test]
    fn la_fsm_recorre_las_aristas_del_diagrama() {
        // Anunciado → reconstruir → completo y OK → Reconstruido.
        let (anuncio, mut mempool) = fixture();
        mempool.push(CandidatoMempool {
            tx: tx(4, 1_000),
            testigos: vec![vec![4; 64]],
        });
        let mut m = MaquinaRele::nueva(anuncio);
        assert_eq!(m.estado(), EstadoRele::Anunciado);
        assert_eq!(m.reconstruir(&mempool), EstadoRele::Reconstruido);

        // Reconstruido → sin PoT verificado → PendienteDeEvidencia.
        assert!(m.esperar_evidencia().is_err());
        assert_eq!(m.estado(), EstadoRele::PendienteDeEvidencia);
    }

    #[test]
    fn la_fsm_pasa_por_esperando_faltantes_y_luego_reconstruido() {
        let (anuncio, mempool) = fixture();
        let mut m = MaquinaRele::nueva(anuncio.clone());
        assert_eq!(m.reconstruir(&mempool), EstadoRele::EsperandoFaltantes);
        let p = PeticionFaltantes::nueva(
            anuncio.cabecera.block_hash(),
            m.reconstruccion().faltantes(),
            anuncio.total_txs(),
        )
        .unwrap();
        let respuesta = RespuestaFaltantes {
            bloque: anuncio.cabecera.block_hash(),
            transacciones: vec![(tx(4, 1_000), vec![vec![4; 64]])],
        };
        assert_eq!(
            m.aplicar_respuesta(&p, &respuesta),
            EstadoRele::Reconstruido
        );
    }

    /// La arista que **no** existe: una segunda ronda compacta.
    #[test]
    fn no_hay_segunda_ronda_compacta() {
        let (anuncio, mempool) = fixture();
        let mut m = MaquinaRele::nueva(anuncio);
        assert_eq!(m.reconstruir(&mempool), EstadoRele::EsperandoFaltantes);
        // Volver a reconstruir desde EsperandoFaltantes NO da otra ronda: terminal.
        assert_eq!(m.reconstruir(&mempool), EstadoRele::PeticionBloqueCompleto);
        assert!(m.estado().es_terminal());

        // Y aplicar sin estar en EsperandoFaltantes tampoco.
        let mut m2 = MaquinaRele::nueva(fixture().0);
        let p = PeticionFaltantes::nueva(m2.anuncio().cabecera.block_hash(), &[1], 4).unwrap();
        let r = RespuestaFaltantes {
            bloque: m2.anuncio().cabecera.block_hash(),
            transacciones: Vec::new(),
        };
        assert_eq!(
            m2.aplicar_respuesta(&p, &r),
            EstadoRele::PeticionBloqueCompleto
        );
    }

    // ── Compromisos y no-puntuación ──────────────────────────────────────────

    #[test]
    fn las_mutaciones_separan_efectos_de_autorizacion() {
        let (anuncio, mut mempool) = fixture();
        mempool.push(CandidatoMempool {
            tx: tx(4, 1_000),
            testigos: vec![vec![4; 64]],
        });
        let rec = reconstruir(&anuncio, &mempool);
        assert!(comprobar_completitud_y_compromisos(&anuncio, &rec).is_ok());

        let (txs, testigos) = rec.completas().unwrap();

        // Mutación de efectos: se cambia el valor de una salida ⇒ Merkle falla.
        let mut txs2 = txs.clone();
        txs2[2] = tx(3, 2_000);
        let rec2 = Reconstruccion {
            anuncio: anuncio.clone(),
            txs: txs2.iter().cloned().map(Some).collect(),
            testigos: testigos.iter().cloned().map(Some).collect(),
            faltantes: Vec::new(),
            ambiguos: Vec::new(),
        };
        assert_eq!(
            comprobar_completitud_y_compromisos(&anuncio, &rec2),
            Err(FalloReconstruccion::CompromisoMerkleFallido)
        );

        // Mutación solo de testigos: Merkle intacto, compromiso distinto.
        let mut testigos2 = testigos.clone();
        testigos2[2] = vec![vec![0xAB; 64]];
        let rec3 = Reconstruccion {
            anuncio: anuncio.clone(),
            txs: txs.into_iter().map(Some).collect(),
            testigos: testigos2.into_iter().map(Some).collect(),
            faltantes: Vec::new(),
            ambiguos: Vec::new(),
        };
        assert_eq!(
            comprobar_completitud_y_compromisos(&anuncio, &rec3),
            Err(FalloReconstruccion::CompromisoCuerpoFallido)
        );
    }

    #[test]
    fn el_fallback_es_terminal_y_no_puntua() {
        for fallo in [
            FalloReconstruccion::SinMempool,
            FalloReconstruccion::Colision,
            FalloReconstruccion::ReconstruccionIncompleta,
            FalloReconstruccion::RespuestaNoCorresponde,
            FalloReconstruccion::Timeout,
            FalloReconstruccion::CompromisoMerkleFallido,
            FalloReconstruccion::CompromisoCuerpoFallido,
        ] {
            assert!(!fallo.puntua_al_peer(), "{fallo:?}");
            assert_eq!(fallo.siguiente_estado(), EstadoRele::PeticionBloqueCompleto);
        }
    }

    /// El presupuesto de C-NET-21 sigue siendo el vigente.
    #[test]
    fn el_presupuesto_sigue_siendo_256_mib() {
        assert_eq!(PRESUPUESTO_BYTES_RELE, 268_435_456);
    }
}
