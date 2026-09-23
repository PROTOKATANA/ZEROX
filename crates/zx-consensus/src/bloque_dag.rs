//! Compromisos del cuerpo DAG y rango contextual (SPEC §6, §7.2, §11).
//!
//! # Dos controles que no se sustituyen
//!
//! Este módulo comprueba el **compromiso estructural**: recalcula `merkle_root` y
//! `body_commitment` y los compara con la cabecera. Eso **no** verifica firmas, Halo2 ni UTXO, y
//! tampoco demuestra que el bloque sea válido. La verificación criptográfica de los testigos vive
//! en [`crate::testigo::satisface`], y la validación del cuerpo en `zx-node`.
//!
//! **No** se conecta a `validar_bloque`: la cadena transitoria sigue siendo lineal y no integra el
//! DAG. Exponerlo suelto es deliberado; fingir que ya está integrado, no.

use zx_core::digest::{AuthDigest, BlockHash, TxId};
use zx_core::preimage::block::merkle_root;
use zx_core::{DagBlockHeader, PadresDag, Tx, auth_digest, body_commitment_de_pares, txid};

use crate::error::ConsensusError;

// ─────────────────────────────────────────────────────────────────────────────
// H-06 · Rango contextual sin circularidad
// ─────────────────────────────────────────────────────────────────────────────

/// Vista **opaca** de un candidato que no expone `rango_solucion` (H-06).
///
/// La documentación de [`ContextoRangoDag`] prohíbe depender del campo recibido. Eso deja de ser
/// una regla en prosa y pasa a ser un tipo: no hay accesor, ni `Deref`, ni `as_header()`, y el
/// `Debug` está escrito a mano para omitirlo. Una implementación que quiera devolver el campo no
/// puede nombrarlo.
#[derive(Clone, Copy)]
pub struct CandidatoSinRango<'a> {
    cabecera: &'a DagBlockHeader,
}

impl<'a> CandidatoSinRango<'a> {
    /// Los padres declarados.
    #[must_use]
    pub fn padres(&self) -> &'a PadresDag {
        &self.cabecera.padres
    }

    /// El índice de PoT.
    #[must_use]
    pub fn slot(&self) -> u64 {
        self.cabecera.slot
    }

    /// La altura declarada, como `u64`.
    #[must_use]
    pub fn height(&self) -> u64 {
        u64::from(self.cabecera.height)
    }

    /// El timestamp declarado.
    #[must_use]
    pub fn timestamp(&self) -> u64 {
        self.cabecera.timestamp
    }

    /// La salida PoT de 16 bytes.
    #[must_use]
    pub fn pot_output(&self) -> &'a [u8; 16] {
        &self.cabecera.pot_output
    }
}

impl core::fmt::Debug for CandidatoSinRango<'_> {
    fn fmt(&self, f: &mut core::fmt::Formatter<'_>) -> core::fmt::Result {
        // A mano y **sin** `rango_solucion`: un `{:?}` no debe ser una puerta trasera.
        f.debug_struct("CandidatoSinRango")
            .field("padres", &self.cabecera.padres)
            .field("slot", &self.cabecera.slot)
            .field("height", &self.cabecera.height)
            .field("timestamp", &self.cabecera.timestamp)
            .field("pot_output", &self.cabecera.pot_output)
            .finish()
    }
}

/// Contexto **obligatorio** para comprobar el rango de solución en un DAG (C-HDR-06 reescrita).
///
/// El rango esperado es `controlador(past(B), flow(B, slot(B)))`: función exclusiva del pasado DAG
/// validado y del flujo. **No** puede depender del orden de llegada, la punta local, el reloj, el
/// `timestamp`, el `height` declarado ni del propio `rango_solucion` que trae el candidato.
///
/// El método recibe [`CandidatoSinRango`], no la cabecera. Eso **solo** bloquea el acceso directo a
/// `rango_solucion` a través de esa vista; **no** demuestra que un contexto no conserve la cabecera
/// (o el valor por otra vía) y lo devuelva como «esperado». La garantía real es que el controlador
/// derive el esperado del pasado validado y del flujo, y eso sigue pendiente.
///
/// # Intento de circularidad que NO compila
///
/// ```compile_fail
/// use zx_consensus::bloque_dag::{CandidatoSinRango, ContextoRangoDag};
/// use zx_consensus::ConsensusError;
///
/// struct Circular;
/// impl ContextoRangoDag for Circular {
///     fn rango_esperado(&self, c: &CandidatoSinRango<'_>) -> Result<u64, ConsensusError> {
///         // Acceso DIRECTO por la vista: no existe. Otra vía (una copia de la cabecera) sí.
///         Ok(c.rango_solucion())
///     }
/// }
/// ```
///
/// El algoritmo del controlador (ventana, bootstrap, redondeos y fusiones fuera de ventana) sigue
/// en `TAREAS.md` §2.3 y **no** se inventa aquí.
pub trait ContextoRangoDag {
    /// Rango esperado para el candidato, derivado del pasado validado y del flujo.
    ///
    /// # Errores
    /// El error contextual que impida calcularlo (pasado incompleto, flujo desconocido, …).
    fn rango_esperado(&self, candidato: &CandidatoSinRango<'_>) -> Result<u64, ConsensusError>;
}

/// `SR` y la cabecera para la que se validó, en la frontera C-HDR-06 → C-GD-01/C-GD-08.
///
/// # Qué mejora y qué no
///
/// C-GD-01 pondera `w(B) = ⌊2^128/(SR(B)+1)⌋` y C-GD-08 lo acumula en `blue_work`. Este tipo
/// guarda el valor y, cuando sale de [`Self::validar`], **el `block_hash` de la cabecera que lo
/// superó**. La inserción comprueba esa atadura: un rango validado para `A` no se puede colocar en
/// un bloque con el id de `B` (ver [`ConsensusError::RangoDeOtroBloque`]).
///
/// La puerta que valida el `SR` es
/// [`AlmacenGhostdag::admitir`](crate::ghostdag::AlmacenGhostdag::admitir): recibe la cabecera,
/// deriva su id, pide el rango esperado al contexto, valida e inserta. No acepta ni el `SR` ni el
/// id del llamante. Es una validación **parcial** —solo el `SR`, no la prueba PoST ni el resto del
/// bloque— y ninguna ruta de `zx-node` la ejecuta todavía.
///
/// # Límites, dichos sin adorno
///
/// - [`Self::para_oraculos`] construye un rango **sin validar** (sin cabecera asociada) y sigue
///   siendo API pública para los oráculos. Un llamante que la use con
///   [`AlmacenGhostdag::anadir_sintetico`](crate::ghostdag::AlmacenGhostdag::anadir_sintetico)
///   **se salta C-HDR-06**. Es la parte que este encargo **no** cierra: separar de verdad esa
///   entrada exige que los oráculos construyan cabeceras y pasen por `admitir`, y que exista el
///   contexto real.
/// - Aun pasando por [`Self::validar`], la garantía vale lo que valga el [`ContextoRangoDag`]. La
///   vista opaca impide que el contexto lea el `rango_solucion` declarado, pero **no** prueba que
///   lo derive del pasado validado y del flujo: es una precondición pendiente (`TAREAS.md` §2.3).
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct RangoSolucionValidado {
    /// Cabecera para la que se validó; `None` en el constructor sintético.
    bloque: Option<BlockHash>,
    rango: u64,
}

impl RangoSolucionValidado {
    /// El `SR`.
    #[must_use]
    pub const fn valor(self) -> u64 {
        self.rango
    }

    /// El bloque para el que se validó, si salió de [`Self::validar`].
    #[must_use]
    pub const fn bloque(self) -> Option<BlockHash> {
        self.bloque
    }

    /// Comprueba C-HDR-06 y ata el resultado a la cabecera.
    ///
    /// El valor esperado sale **exclusivamente** del contexto; el candidato entra como
    /// [`CandidatoSinRango`], que no expone `rango_solucion`. Eso impide la circularidad por
    /// lectura, **no** demuestra que el contexto esté bien fundado.
    ///
    /// # Errores
    /// [`ConsensusError::RangoIncorrecto`] si el declarado no coincide con el esperado; o el error
    /// que devuelva el contexto al calcularlo.
    pub fn validar<C: ContextoRangoDag>(
        candidato: &DagBlockHeader,
        ctx: &C,
    ) -> Result<Self, ConsensusError> {
        let vista = CandidatoSinRango {
            cabecera: candidato,
        };
        let esperado = ctx.rango_esperado(&vista)?;
        if candidato.rango_solucion != esperado {
            return Err(ConsensusError::RangoIncorrecto {
                esperado,
                encontrado: candidato.rango_solucion,
            });
        }
        Ok(Self {
            bloque: Some(candidato.block_hash()),
            rango: candidato.rango_solucion,
        })
    }

    /// Constructor **sintético** para oráculos y tests. **NO valida C-HDR-06** y no ata el rango a
    /// ninguna cabecera.
    ///
    /// No es la API de producción: existe para que los vectores de GDR-v0.2, los DAGs generados y
    /// los benchmarks puedan sembrar un `SR` sin un `ContextoRangoDag` (el controlador no existe,
    /// `TAREAS.md` §2.3). Un llamante puede invocarlo; por eso la frontera es **parcial** y se
    /// documenta como tal.
    #[must_use]
    pub const fn para_oraculos(rango_solucion: u64) -> Self {
        Self {
            bloque: None,
            rango: rango_solucion,
        }
    }
}

/// Comprueba `rango_solucion` contra el rango que aporta el contexto (C-HDR-06 reescrita).
///
/// Es la puerta que fabrica [`RangoSolucionValidado`]: construye la vista opaca, se la pasa al
/// contexto y compara el resultado con el campo recibido. Delega en
/// [`RangoSolucionValidado::validar`] para que la comparación viva en un solo sitio.
///
/// # Errores
/// [`ConsensusError::RangoIncorrecto`] si el valor declarado no coincide; o el error que devuelva
/// el contexto al calcularlo.
pub fn comprobar_rango_contextual<C: ContextoRangoDag>(
    candidato: &DagBlockHeader,
    ctx: &C,
) -> Result<(), ConsensusError> {
    RangoSolucionValidado::validar(candidato, ctx).map(|_| ())
}

// ─────────────────────────────────────────────────────────────────────────────
// H-04 · Validación contextual de padres
// ─────────────────────────────────────────────────────────────────────────────

/// Contexto **obligatorio** para comprobar los padres de un bloque DAG (C-HDR-05, C-FLU-02,
/// C-GD-03).
///
/// La anticadena y que `prev_hash` sea el `sp(B)` de GHOSTDAG dependen del DAG validado, que este
/// crate no posee. Igual que con el rango, el llamante aporta la información; aquí **no** se
/// implementa GHOSTDAG.
pub trait ContextoDag {
    /// ¿Está este hash entre los bloques ya validados?
    fn es_bloque_validado(&self, h: &BlockHash) -> bool;

    /// ¿`antepasado` está en el pasado de `descendiente`?
    ///
    /// # Errores
    /// El error contextual que impida responder (p. ej. ancestro desconocido).
    fn esta_en_el_pasado_de(
        &self,
        antepasado: &BlockHash,
        descendiente: &BlockHash,
    ) -> Result<bool, ConsensusError>;

    /// `slot` de un padre, tomado del contexto almacenado (C-HDR-05, C-FLU-02).
    ///
    /// Es la **única** vía admitida para conocer el `slot` de un padre arbitrario: el candidato
    /// declara su propio `slot`, no el de sus padres, así que la cota de C-HDR-05/C-FLU-02 no
    /// puede leerse del bloque que se valida. La ausencia **MUST NOT** sustituirse por cero: sin
    /// el slot contextual la cota no es comprobable y el bloque no puede aceptarse.
    ///
    /// # Errores
    /// [`ConsensusError::PadreNoValidado`] si el hash no pertenece al contexto;
    /// [`ConsensusError::SlotDePadreAusente`] si el padre existe pero su `slot` no está
    /// almacenado.
    fn slot_de_padre(&self, h: &BlockHash) -> Result<u64, ConsensusError>;

    /// El padre que GHOSTDAG elige para estos padres (C-GD-03).
    ///
    /// # Errores
    /// El error contextual que impida calcularlo.
    fn padre_seleccionado(&self, padres: &PadresDag) -> Result<BlockHash, ConsensusError>;

    /// ¿Ese hash es el génesis de la red?
    ///
    /// **Añadido sobre la firma del encargo:** sin esto no hay forma de distinguir "génesis" de
    /// "bloque no génesis con cero padres", que es precisamente lo que exige el criterio 1.
    fn es_genesis(&self, h: &BlockHash) -> bool;
}

/// Comprueba los padres de un bloque contra el contexto (H-04).
///
/// Cubre, con un error cerrado distinto cada uno:
///
/// 1. `parent_count == 0` ⟺ es el génesis;
/// 2. cada padre —seleccionado y adicionales— está validado;
/// 3. `slot(p) ≤ slot(B)` para **todos** los padres, cota no estricta (C-HDR-05 · C-FLU-02);
/// 4. anticadena: ningún padre está en el pasado de otro;
/// 5. `prev_hash` es el `sp(B)` que devuelve el contexto.
///
/// El `slot` de cada padre lo aporta [`ContextoDag::slot_de_padre`]; nunca se lee del candidato. El
/// génesis, que no tiene padres, conserva su tratamiento propio: pasa por el paso 1 y no llega a
/// la cota.
///
/// # Errores
/// [`ConsensusError::GenesisConCeroPadresNoEsGenesis`], [`ConsensusError::GenesisConPadres`],
/// [`ConsensusError::PadreNoValidado`], [`ConsensusError::SlotDePadreAusente`],
/// [`ConsensusError::SlotDePadrePosterior`], [`ConsensusError::PadresNoAnticadena`] o
/// [`ConsensusError::PadreSeleccionadoIncorrecto`].
pub fn comprobar_padres_contextual<C: ContextoDag>(
    cabecera: &DagBlockHeader,
    ctx: &C,
) -> Result<(), ConsensusError> {
    let hash = cabecera.block_hash();
    let es_genesis = ctx.es_genesis(&hash);
    let count = cabecera.padres.count();

    // 1 · Génesis.
    if count == 0 {
        if !es_genesis {
            return Err(ConsensusError::GenesisConCeroPadresNoEsGenesis);
        }
        // El génesis no tiene padres por construcción; nada más que comprobar.
        return Ok(());
    }
    if es_genesis {
        return Err(ConsensusError::GenesisConPadres);
    }

    // 2 · Padres conocidos.
    let seleccionado = cabecera.padres.seleccionado();
    if !ctx.es_bloque_validado(&seleccionado) {
        return Err(ConsensusError::PadreNoValidado {
            padre: seleccionado,
        });
    }
    for p in cabecera.padres.extras() {
        if !ctx.es_bloque_validado(p) {
            return Err(ConsensusError::PadreNoValidado { padre: *p });
        }
    }

    let todos: Vec<BlockHash> = core::iter::once(seleccionado)
        .chain(cabecera.padres.extras().iter().copied())
        .collect();

    // 3 · Cota de slot para TODOS los padres (C-HDR-05 · C-FLU-02): `slot(p) ≤ slot(B)`, no
    //     estricta. Se hace justo después de comprobar que cada padre pertenece al contexto y
    //     antes de la anticadena: es una comprobación estructural de validez.
    for p in &todos {
        let slot_p = ctx.slot_de_padre(p)?;
        if slot_p > cabecera.slot {
            return Err(ConsensusError::SlotDePadrePosterior {
                padre: *p,
                slot_padre: slot_p,
                slot_b: cabecera.slot,
            });
        }
    }

    // 4 · Anticadena: ningún padre en el pasado de otro.
    for (i, a) in todos.iter().enumerate() {
        for (j, b) in todos.iter().enumerate() {
            if i == j {
                continue;
            }
            if ctx.esta_en_el_pasado_de(a, b)? {
                return Err(ConsensusError::PadresNoAnticadena {
                    antepasado: *a,
                    descendiente: *b,
                });
            }
        }
    }

    // 5 · prev_hash == sp(B) de C-GD-03.
    let esperado = ctx.padre_seleccionado(&cabecera.padres)?;
    if esperado != seleccionado {
        return Err(ConsensusError::PadreSeleccionadoIncorrecto {
            esperado,
            encontrado: seleccionado,
        });
    }

    Ok(())
}

/// Recalcula `merkle_root` y `body_commitment` y los compara con la cabecera DAG.
///
/// Función **pura**: no toca UTXO, firmas, Halo2 ni red. Distingue **cuál** de los dos compromisos
/// falla, porque no significan lo mismo:
///
/// - `merkle_root` cubre los datos de efecto (`txid`);
/// - `body_commitment` cubre efectos **y** autorización (`auth_digest`).
///
/// Igualar el compromiso no es verificar la autorización: los testigos podrían ser fielmente
/// comprometidos y no satisfacer ninguna condición de gasto.
///
/// # Errores
/// [`ConsensusError::CuerpoTestigosDescuadrados`] si los conjuntos no cuadran,
/// [`ConsensusError::MerkleRaizNoCoincide`] o [`ConsensusError::CuerpoCompromisoNoCoincide`].
pub fn comprobar_compromisos_cuerpo_dag(
    header: &DagBlockHeader,
    txs: &[Tx],
    testigos: &[Vec<Vec<u8>>],
) -> Result<(), ConsensusError> {
    if txs.len() != testigos.len() {
        return Err(ConsensusError::CuerpoTestigosDescuadrados {
            txs: txs.len(),
            testigos: testigos.len(),
        });
    }

    // Merkle: solo datos de efecto, en orden de aparición (C-BLK-01..03).
    let txids: Vec<TxId> = txs
        .iter()
        .map(|t| txid(t, header.consensus_branch_id))
        .collect();
    if merkle_root(&txids) != header.merkle_root {
        return Err(ConsensusError::MerkleRaizNoCoincide);
    }

    // Compromiso completo: los pares se recalculan aquí, no se reciben calculados.
    let pares: Vec<(TxId, AuthDigest)> = txs
        .iter()
        .zip(testigos)
        .map(|(t, w)| (txid(t, header.consensus_branch_id), auth_digest(w)))
        .collect();
    if body_commitment_de_pares(&pares) != header.body_commitment {
        return Err(ConsensusError::CuerpoCompromisoNoCoincide);
    }

    Ok(())
}

#[cfg(test)]
#[expect(clippy::unwrap_used, reason = "los tests fallan con panic por diseño")]
#[expect(
    clippy::indexing_slicing,
    reason = "índices constantes sobre vectores construidos en el propio test"
)]
mod tests {
    use super::{
        CandidatoSinRango, ContextoDag, ContextoRangoDag, RangoSolucionValidado,
        comprobar_compromisos_cuerpo_dag, comprobar_padres_contextual, comprobar_rango_contextual,
    };
    use crate::error::ConsensusError;
    use crate::testigo::{ContextoGasto, satisface};
    use zx_core::digest::{BlockHash, BodyCommitment, Digest, MerkleRoot, SigHash};
    use zx_core::firma::ClavePublica;
    use zx_core::preimage::block::merkle_root;
    use zx_core::tx::{Lock, OutPoint, Tx, TxIn, TxOut};
    use zx_core::{Amount, DagBlockHeader, PadresDag, SolucionPoas, body_commitment, txid};

    const CBID: u32 = 0xc478_80ea;

    fn h(n: u8) -> BlockHash {
        BlockHash::from_digest(Digest::from_bytes([n; 32]))
    }

    fn tx_con(n: u8, lock: Lock) -> Tx {
        Tx {
            version: 1,
            inputs: vec![TxIn {
                outpoint: OutPoint {
                    prev_txid: zx_core::TxId::from_digest(Digest::from_bytes([n; 32])),
                    prev_index: 0,
                },
                sequence: 0,
            }],
            outputs: vec![TxOut {
                value: Amount::nuevo(i64::from(n) * 1_000).unwrap(),
                lock,
            }],
            lock_time: 0,
            expiry_height: 0,
        }
    }

    fn cabecera_para(txs: &[Tx], testigos: &[Vec<Vec<u8>>]) -> DagBlockHeader {
        cabecera_con(PadresDag::genesis(), txs, testigos)
    }

    fn cabecera_con(padres: PadresDag, txs: &[Tx], testigos: &[Vec<Vec<u8>>]) -> DagBlockHeader {
        let txids: Vec<_> = txs.iter().map(|t| txid(t, CBID)).collect();
        DagBlockHeader {
            consensus_branch_id: CBID,
            merkle_root: merkle_root(&txids),
            timestamp: 1_788_480_000,
            height: 1,
            slot: 1,
            pot_output: [0; 16],
            rango_solucion: 42,
            sol: SolucionPoas::default(),
            body_commitment: body_commitment(txs, testigos, CBID).unwrap(),
            padres,
            sello: [0; 64],
        }
    }

    #[test]
    fn acepta_ambos_compromisos_correctos() {
        let lock = Lock::PubKey {
            pubkey: ClavePublica::desde_bytes([1; 32]),
        };
        let txs = vec![tx_con(1, lock.clone()), tx_con(2, lock)];
        let testigos = vec![vec![vec![0xAA; 64]], vec![vec![0xBB; 65]]];
        let c = cabecera_para(&txs, &testigos);
        assert!(comprobar_compromisos_cuerpo_dag(&c, &txs, &testigos).is_ok());
    }

    #[test]
    fn distingue_cual_de_los_dos_falla() {
        let lock = Lock::PubKey {
            pubkey: ClavePublica::desde_bytes([1; 32]),
        };
        let txs = vec![tx_con(1, lock.clone())];
        let testigos = vec![vec![vec![0xAA; 64]]];
        let c = cabecera_para(&txs, &testigos);

        // Merkle roto: se cambia un dato de efecto sin recomputar el compromiso.
        let mut roto = c;
        roto.merkle_root = MerkleRoot::from_digest(Digest::from_bytes([0xEE; 32]));
        assert_eq!(
            comprobar_compromisos_cuerpo_dag(&roto, &txs, &testigos),
            Err(ConsensusError::MerkleRaizNoCoincide)
        );

        // Cuerpo roto: Merkle correcto, compromiso distinto.
        let mut roto = c;
        roto.body_commitment = BodyCommitment::from_digest(Digest::from_bytes([0xEE; 32]));
        assert_eq!(
            comprobar_compromisos_cuerpo_dag(&roto, &txs, &testigos),
            Err(ConsensusError::CuerpoCompromisoNoCoincide)
        );

        // Testigos de más.
        let descuadre = vec![vec![vec![0xAA; 64]], vec![vec![0xBB; 64]]];
        assert!(matches!(
            comprobar_compromisos_cuerpo_dag(&c, &txs, &descuadre),
            Err(ConsensusError::CuerpoTestigosDescuadrados { .. })
        ));
    }

    /// **Regresión `compromiso != autorizacion`.**
    ///
    /// Un testigo criptográficamente inválido puede coincidir con el `body_commitment` calculado
    /// sobre él. Comprobar el compromiso pasa; `testigo::satisface` lo rechaza. Son dos controles
    /// distintos y esta es la prueba de que no se sustituyen.
    #[test]
    fn un_testigo_invalido_puede_coincidir_con_el_compromiso() {
        let lock = Lock::PubKey {
            pubkey: ClavePublica::desde_bytes([42; 32]),
        };
        let txs = vec![tx_con(7, lock.clone())];
        // Firma basura de 64 bytes: compromete el cuerpo, pero no autoriza nada.
        let testigos = vec![vec![vec![0x00; 64]]];
        let c = cabecera_para(&txs, &testigos);

        assert!(
            comprobar_compromisos_cuerpo_dag(&c, &txs, &testigos).is_ok(),
            "el compromiso es fiel a unos testigos inválidos"
        );

        let sighash = SigHash::from_digest(Digest::from_bytes([0x5a; 32]));
        let veredicto = satisface(
            &lock,
            &testigos[0][0],
            &sighash,
            ContextoGasto { altura: 1 },
        );
        assert!(
            veredicto.is_err(),
            "y la verificación criptográfica los rechaza: {veredicto:?}"
        );
    }

    struct CtxFijo(u64);
    impl ContextoRangoDag for CtxFijo {
        fn rango_esperado(
            &self,
            _candidato: &CandidatoSinRango<'_>,
        ) -> Result<u64, ConsensusError> {
            Ok(self.0)
        }
    }

    /// La ruta lineal activa no recibe por accidente la cabecera DAG.
    ///
    /// No existe ninguna conversión `From<DagBlockHeader>`/`Into<BlockHeader>`, así que el
    /// compilador impide pasarlas la una por la otra; el test fija además que son tipos distintos.
    /// `validar_bloque` sigue tomando el `Bloque` lineal y no se ha tocado.
    #[test]
    fn la_ruta_lineal_y_la_dag_son_tipos_distintos() {
        use core::any::TypeId;
        use zx_core::preimage::block::BlockHeader;
        assert_ne!(TypeId::of::<DagBlockHeader>(), TypeId::of::<BlockHeader>());
    }

    #[test]
    fn el_rango_se_exige_exacto_y_nunca_sale_del_campo() {
        let lock = Lock::PubKey {
            pubkey: ClavePublica::desde_bytes([1; 32]),
        };
        let txs = vec![tx_con(1, lock)];
        let testigos = vec![vec![vec![0; 64]]];
        let mut c = cabecera_para(&txs, &testigos);
        c.rango_solucion = 42;

        // El contexto coincide: pasa.
        assert!(comprobar_rango_contextual(&c, &CtxFijo(42)).is_ok());
        // El contexto dice otra cosa: se rechaza aunque el campo sea "el suyo".
        assert_eq!(
            comprobar_rango_contextual(&c, &CtxFijo(43)),
            Err(ConsensusError::RangoIncorrecto {
                esperado: 43,
                encontrado: 42
            })
        );
    }

    /// **C-HDR-06 → C-GD-01/C-GD-08.** El `SR` validado sale del contexto, no del candidato.
    #[test]
    fn el_rango_validado_sale_del_contexto_y_no_del_candidato() {
        let lock = Lock::PubKey {
            pubkey: ClavePublica::desde_bytes([1; 32]),
        };
        let txs = vec![tx_con(1, lock)];
        let testigos = vec![vec![vec![0; 64]]];
        let mut c = cabecera_para(&txs, &testigos);
        c.rango_solucion = 42;

        // El contexto que coincide: valida y conserva exactamente su valor.
        let v = RangoSolucionValidado::validar(&c, &CtxFijo(42)).unwrap();
        assert_eq!(v.valor(), 42);

        // El mismo candidato contra otro contexto no valida: el esperado es el del contexto.
        assert_eq!(
            RangoSolucionValidado::validar(&c, &CtxFijo(7)),
            Err(ConsensusError::RangoIncorrecto {
                esperado: 7,
                encontrado: 42
            })
        );

        // `comprobar_rango_contextual` y `validar` son la misma puerta.
        assert!(comprobar_rango_contextual(&c, &CtxFijo(42)).is_ok());
        assert!(comprobar_rango_contextual(&c, &CtxFijo(7)).is_err());
    }

    /// El constructor sintético es explícito: no valida nada, solo envuelve el valor.
    #[test]
    fn el_constructor_de_oraculos_no_valida_y_lo_declara() {
        assert_eq!(RangoSolucionValidado::para_oraculos(0).valor(), 0);
        assert_eq!(
            RangoSolucionValidado::para_oraculos(u64::MAX).valor(),
            u64::MAX
        );
    }

    /// **H-06** · La vista opaca no filtra `rango_solucion` ni por `Debug`.
    #[test]
    fn la_vista_de_rango_no_imprime_rango_solucion() {
        let lock = Lock::PubKey {
            pubkey: ClavePublica::desde_bytes([1; 32]),
        };
        let txs = vec![tx_con(1, lock)];
        let testigos = vec![vec![vec![0; 64]]];
        let mut c = cabecera_para(&txs, &testigos);
        c.rango_solucion = 0xDEAD_BEEF;

        struct Imprime;
        impl ContextoRangoDag for Imprime {
            fn rango_esperado(
                &self,
                candidato: &CandidatoSinRango<'_>,
            ) -> Result<u64, ConsensusError> {
                let texto = format!("{candidato:?}");
                assert!(
                    !texto.contains("rango_solucion") && !texto.contains("deadbeef"),
                    "el Debug filtra rango_solucion: {texto}"
                );
                let _ = candidato.padres();
                let _ = candidato.slot();
                let _ = candidato.height();
                let _ = candidato.timestamp();
                let _ = candidato.pot_output();
                Ok(0xDEAD_BEEF)
            }
        }
        assert!(comprobar_rango_contextual(&c, &Imprime).is_ok());
    }

    // ── H-04 · Padres contextuales ───────────────────────────────────────────

    struct CtxDag {
        validados: Vec<BlockHash>,
        genesis: BlockHash,
        pasados: Vec<(BlockHash, BlockHash)>,
        /// `slot` contextual de cada padre: la única fuente admitida por C-HDR-05/C-FLU-02.
        slots: Vec<(BlockHash, u64)>,
        sp_forzado: Option<BlockHash>,
    }

    impl CtxDag {
        fn nuevo(genesis: BlockHash) -> Self {
            Self {
                validados: Vec::new(),
                genesis,
                pasados: Vec::new(),
                slots: Vec::new(),
                sp_forzado: None,
            }
        }
    }

    impl ContextoDag for CtxDag {
        fn es_bloque_validado(&self, h: &BlockHash) -> bool {
            self.validados.contains(h)
        }

        fn esta_en_el_pasado_de(
            &self,
            antepasado: &BlockHash,
            descendiente: &BlockHash,
        ) -> Result<bool, ConsensusError> {
            Ok(self.pasados.contains(&(*antepasado, *descendiente)))
        }

        fn slot_de_padre(&self, h: &BlockHash) -> Result<u64, ConsensusError> {
            // Igual que el almacén real: padre desconocido y slot ausente son errores distintos,
            // y el slot **no** se toma del candidato ni se sustituye por cero.
            if !self.validados.contains(h) {
                return Err(ConsensusError::PadreNoValidado { padre: *h });
            }
            self.slots
                .iter()
                .find_map(|(id, slot)| (id == h).then_some(*slot))
                .ok_or(ConsensusError::SlotDePadreAusente { padre: *h })
        }

        fn padre_seleccionado(&self, padres: &PadresDag) -> Result<BlockHash, ConsensusError> {
            Ok(self.sp_forzado.unwrap_or_else(|| padres.seleccionado()))
        }

        fn es_genesis(&self, h: &BlockHash) -> bool {
            *h == self.genesis
        }
    }

    fn bloque_minimo() -> (Vec<Tx>, Vec<Vec<Vec<u8>>>) {
        let lock = Lock::PubKey {
            pubkey: ClavePublica::desde_bytes([1; 32]),
        };
        (vec![tx_con(1, lock)], vec![vec![vec![0xAA; 64]]])
    }

    #[test]
    fn el_genesis_sin_padres_pasa_y_el_impostor_no() {
        let (txs, testigos) = bloque_minimo();
        let c = cabecera_con(PadresDag::genesis(), &txs, &testigos);
        let mut ctx = CtxDag::nuevo(c.block_hash());
        assert!(comprobar_padres_contextual(&c, &ctx).is_ok());

        // Otro génesis ⇒ este bloque con cero padres no es el génesis ⇒ rechazo.
        ctx.genesis = h(0xEE);
        assert_eq!(
            comprobar_padres_contextual(&c, &ctx),
            Err(ConsensusError::GenesisConCeroPadresNoEsGenesis)
        );
    }

    #[test]
    fn un_padre_no_validado_se_rechaza() {
        let (txs, testigos) = bloque_minimo();
        let padres = PadresDag::nuevo(h(1), &[h(2)]).unwrap();
        let c = cabecera_con(padres, &txs, &testigos);
        let mut ctx = CtxDag::nuevo(h(0));
        // Solo el seleccionado está validado; el adicional no.
        ctx.validados = vec![h(1)];
        assert_eq!(
            comprobar_padres_contextual(&c, &ctx),
            Err(ConsensusError::PadreNoValidado { padre: h(2) })
        );
    }

    #[test]
    fn dos_padres_en_relacion_de_ancestro_se_rechazan() {
        let (txs, testigos) = bloque_minimo();
        let padres = PadresDag::nuevo(h(1), &[h(2)]).unwrap();
        let c = cabecera_con(padres, &txs, &testigos);
        let mut ctx = CtxDag::nuevo(h(0));
        ctx.validados = vec![h(1), h(2)];
        ctx.slots = vec![(h(1), 0), (h(2), 0)];
        // h(1) está en el pasado de h(2): no es anticadena.
        ctx.pasados = vec![(h(1), h(2))];
        assert_eq!(
            comprobar_padres_contextual(&c, &ctx),
            Err(ConsensusError::PadresNoAnticadena {
                antepasado: h(1),
                descendiente: h(2)
            })
        );
    }

    #[test]
    fn un_prev_hash_que_no_es_sp_se_rechaza() {
        let (txs, testigos) = bloque_minimo();
        let padres = PadresDag::nuevo(h(1), &[h(2)]).unwrap();
        let c = cabecera_con(padres, &txs, &testigos);
        let mut ctx = CtxDag::nuevo(h(0));
        ctx.validados = vec![h(1), h(2)];
        ctx.slots = vec![(h(1), 0), (h(2), 0)];
        ctx.sp_forzado = Some(h(2));
        assert_eq!(
            comprobar_padres_contextual(&c, &ctx),
            Err(ConsensusError::PadreSeleccionadoIncorrecto {
                esperado: h(2),
                encontrado: h(1)
            })
        );
    }

    #[test]
    fn padres_validados_y_anticadena_pasan() {
        let (txs, testigos) = bloque_minimo();
        let padres = PadresDag::nuevo(h(1), &[h(2), h(3)]).unwrap();
        let c = cabecera_con(padres, &txs, &testigos);
        let mut ctx = CtxDag::nuevo(h(0));
        ctx.validados = vec![h(1), h(2), h(3)];
        ctx.slots = vec![(h(1), 0), (h(2), 0), (h(3), 0)];
        assert!(comprobar_padres_contextual(&c, &ctx).is_ok());
    }

    // ── C-HDR-05 · C-FLU-02 · cota de slot para TODOS los padres ─────────────

    #[test]
    fn el_padre_seleccionado_con_slot_posterior_se_rechaza() {
        let (txs, testigos) = bloque_minimo();
        let padres = PadresDag::nuevo(h(1), &[]).unwrap();
        let mut c = cabecera_con(padres, &txs, &testigos);
        c.slot = 5;
        let mut ctx = CtxDag::nuevo(h(0));
        ctx.validados = vec![h(1)];
        ctx.slots = vec![(h(1), 6)];
        assert_eq!(
            comprobar_padres_contextual(&c, &ctx),
            Err(ConsensusError::SlotDePadrePosterior {
                padre: h(1),
                slot_padre: 6,
                slot_b: 5
            })
        );
    }

    #[test]
    fn el_padre_adicional_con_slot_posterior_se_rechaza_aunque_el_seleccionado_cumpla() {
        let (txs, testigos) = bloque_minimo();
        let padres = PadresDag::nuevo(h(1), &[h(2)]).unwrap();
        let mut c = cabecera_con(padres, &txs, &testigos);
        c.slot = 5;
        let mut ctx = CtxDag::nuevo(h(0));
        ctx.validados = vec![h(1), h(2)];
        // El seleccionado cumple; el adicional no.
        ctx.slots = vec![(h(1), 4), (h(2), 9)];
        assert_eq!(
            comprobar_padres_contextual(&c, &ctx),
            Err(ConsensusError::SlotDePadrePosterior {
                padre: h(2),
                slot_padre: 9,
                slot_b: 5
            })
        );
    }

    #[test]
    fn todos_los_padres_con_el_mismo_slot_que_b_pasan() {
        let (txs, testigos) = bloque_minimo();
        let padres = PadresDag::nuevo(h(1), &[h(2), h(3)]).unwrap();
        let mut c = cabecera_con(padres, &txs, &testigos);
        c.slot = 7;
        let mut ctx = CtxDag::nuevo(h(0));
        ctx.validados = vec![h(1), h(2), h(3)];
        ctx.slots = vec![(h(1), 7), (h(2), 7), (h(3), 7)];
        assert!(comprobar_padres_contextual(&c, &ctx).is_ok());
    }

    #[test]
    fn padres_con_slots_anteriores_pasan() {
        let (txs, testigos) = bloque_minimo();
        let padres = PadresDag::nuevo(h(1), &[h(2)]).unwrap();
        let mut c = cabecera_con(padres, &txs, &testigos);
        c.slot = 10;
        let mut ctx = CtxDag::nuevo(h(0));
        ctx.validados = vec![h(1), h(2)];
        ctx.slots = vec![(h(1), 0), (h(2), 9)];
        assert!(comprobar_padres_contextual(&c, &ctx).is_ok());
    }

    #[test]
    fn un_padre_validado_sin_slot_contextual_es_error_explicito() {
        let (txs, testigos) = bloque_minimo();
        let padres = PadresDag::nuevo(h(1), &[h(2)]).unwrap();
        let mut c = cabecera_con(padres, &txs, &testigos);
        c.slot = 5;
        let mut ctx = CtxDag::nuevo(h(0));
        ctx.validados = vec![h(1), h(2)];
        // El adicional está validado pero el contexto no le da slot: no se acepta por defecto.
        ctx.slots = vec![(h(1), 4)];
        assert_eq!(
            comprobar_padres_contextual(&c, &ctx),
            Err(ConsensusError::SlotDePadreAusente { padre: h(2) })
        );
    }

    #[test]
    fn un_padre_desconocido_no_tiene_slot_y_se_rechaza() {
        // Sin pasar por `comprobar_padres_contextual`: la consulta misma falla explícitamente.
        let ctx = CtxDag::nuevo(h(0));
        assert_eq!(
            ContextoDag::slot_de_padre(&ctx, &h(1)),
            Err(ConsensusError::PadreNoValidado { padre: h(1) })
        );
        let mut ctx = CtxDag::nuevo(h(0));
        ctx.validados = vec![h(1)];
        assert_eq!(
            ContextoDag::slot_de_padre(&ctx, &h(1)),
            Err(ConsensusError::SlotDePadreAusente { padre: h(1) })
        );
    }
}
