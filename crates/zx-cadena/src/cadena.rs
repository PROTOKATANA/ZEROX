//! Gestor del estado del DAG en memoria (`ORDEN-W06a`, `D-N02`).
//!
//! Implementa `ED-1…ED-6` y `RD-1…RD-10` del contrato `P-ZRX/P-DAG/CONTRATO-ESTADO-DAG-v0.md`
//! sobre el motor de W03 (`aplicar` para PoW, `aplicar_fusion` para PoST) y `zx-dag` (GHOSTDAG):
//!
//! - **ED-1** la fase PoW se aplica en modo estricto sobre su padre;
//! - **ED-2** `Estado(past(B))` parte del estado del padre seleccionado y aplica, en orden
//!   `C-GD-05`, el mergeset de `B` sin `rojo_U3`, en modo fusión con punto `slot(B)`;
//! - **ED-3** el virtual `V` tiene por padres las puntas válidas, `slot(V) = máx slot(puntas)`, y la
//!   cadena seleccionada es la de `sp` desde `V`;
//! - **RD-4/RD-1** un bloque de cadena se aplica en su propio slot; uno fusionado de lado, en el
//!   slot del fusionador; el importe de la coinbase usa `subsidio_post(slot(X))`;
//! - **RD-5** `slot(B) − slot(X) > F_slots` invalida el bloque (`ErrMergeDepth`);
//! - **RD-9/RD-10** la garantía del productor se comprueba en `Estado(past(B))` promovido en
//!   `slot(B)`, una sola vez, en la admisión.
//!
//! La verificación de cabeceras no es de esta orden: `pow_valido`/`prueba_valida` llegan decididos.

use std::cmp::Ordering;
use std::collections::{BTreeMap, BTreeSet};

use zx_consensus::transicion::{
    Estado, ParametrosTransicion, Punto, TxDescartada, Undo, aplicar, aplicar_fusion, deshacer,
    es_terminal_condiciones,
};
use zx_core::{Amount, BlockHash, ClavePublica, Tx};
use zx_dag::ghostdag::{
    Algoritmo, AlmacenGhostdag, BloqueGhostdag, Color, IdentidadGhostdag, Idx, ModoMerge, ModoSp,
    Parametros as ParametrosGhostdag, Rank,
};
use zx_dag::{ErrorDag, RangoSolucionValidado, hash_de_id_textual};

use crate::bloque::{BloqueCadena, BloquePost};
use crate::error::MotivoBloque;

/// Máximo de padres de un bloque real en el oráculo T04 (`RD-8`).
const MAX_PADRES_ORACULO: u8 = 3;
/// Tope de mergeset del oráculo (`C-GD-04`).
const MERGESET_LIMITE_ORACULO: u32 = 180;

/// Una transacción descartada al aplicar la historia seleccionada, con el bloque del que procede.
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct Descarte {
    /// Bloque que contenía la transacción.
    pub bloque: BlockHash,
    /// Índice **0-based** de la transacción dentro del bloque.
    pub indice: usize,
    /// Motivo del descarte.
    pub motivo: zx_consensus::transicion::ErrorTransicion,
}

/// Resultado de aplicar la historia o una rama: estado, orden y descartes, más los undos.
type HistoriaAplicada = (Estado, Vec<BlockHash>, Vec<Descarte>, Vec<Undo>);

/// Datos de GHOSTDAG de un bloque, guardados para reconstruir el almacén del virtual.
#[derive(Clone, Debug)]
struct DatosDag {
    padres: Vec<BlockHash>,
    slot: u64,
    distancia: u64,
    sr: u64,
    identidad: u64,
}

/// Almacén virtual `V` (una copia del DAG con la punta virtual añadida).
struct Virtual {
    dag: AlmacenGhostdag,
    idx: Idx,
    slot: u64,
}

/// Gestor del estado del DAG en memoria.
pub struct Cadena {
    params: ParametrosTransicion,
    k: u32,
    cbid: u32,
    por_hash: BTreeMap<BlockHash, BloqueCadena>,
    validos: BTreeMap<BlockHash, bool>,
    motivos: BTreeMap<BlockHash, MotivoBloque>,
    past: BTreeMap<BlockHash, Estado>,
    post: BTreeMap<BlockHash, Estado>,
    descartes: BTreeMap<BlockHash, Vec<TxDescartada>>,
    terminal: Option<BlockHash>,
    estado_t: Estado,
    dag: Option<AlmacenGhostdag>,
    dag_idx: BTreeMap<BlockHash, Idx>,
    dag_orden: Vec<BlockHash>,
    dag_datos: BTreeMap<BlockHash, DatosDag>,
}

impl Cadena {
    /// Crea una cadena vacía con los parámetros de transición, el `k` de GHOSTDAG y el `CBID`.
    #[must_use]
    pub fn nueva(params: ParametrosTransicion, k: u32, cbid: u32) -> Self {
        Self {
            params,
            k,
            cbid,
            por_hash: BTreeMap::new(),
            validos: BTreeMap::new(),
            motivos: BTreeMap::new(),
            past: BTreeMap::new(),
            post: BTreeMap::new(),
            descartes: BTreeMap::new(),
            terminal: None,
            estado_t: Estado::inicial(),
            dag: None,
            dag_idx: BTreeMap::new(),
            dag_orden: Vec::new(),
            dag_datos: BTreeMap::new(),
        }
    }

    /// ¿Está admitido y es válido el bloque `hash`?
    #[must_use]
    pub fn es_valido(&self, hash: &BlockHash) -> bool {
        self.validos.get(hash).copied().unwrap_or(false)
    }

    /// Motivo por el que `hash` no se admitió, si se procesó y falló.
    #[must_use]
    pub fn motivo(&self, hash: &BlockHash) -> Option<&MotivoBloque> {
        self.motivos.get(hash)
    }

    /// `Estado(past(B))`, si `B` se admitió con éxito.
    #[must_use]
    pub fn estado_past(&self, hash: &BlockHash) -> Option<&Estado> {
        self.past.get(hash)
    }

    /// `Estado(past(B) ∪ {B})`, si `B` se admitió con éxito.
    #[must_use]
    pub fn estado_post(&self, hash: &BlockHash) -> Option<&Estado> {
        self.post.get(hash)
    }

    /// Descartes registrados al aplicar `B` sobre `Estado(past(B))`.
    #[must_use]
    pub fn descartes(&self, hash: &BlockHash) -> Option<&[TxDescartada]> {
        self.descartes.get(hash).map(Vec::as_slice)
    }

    /// Hash del terminal PoW descubierto, si existe.
    #[must_use]
    pub fn terminal(&self) -> Option<BlockHash> {
        self.terminal
    }

    /// `Estado(T)`, el estado tras aplicar el terminal.
    #[must_use]
    pub fn estado_terminal(&self) -> &Estado {
        &self.estado_t
    }

    /// Acceso al bloque por su hash, si se conoce.
    #[must_use]
    pub fn bloque(&self, hash: &BlockHash) -> Option<&BloqueCadena> {
        self.por_hash.get(hash)
    }

    /// Bloques PoST conocidos (válidos e inválidos), en orden de hash.
    #[must_use]
    pub fn bloques_post(&self) -> Vec<&BloquePost> {
        self.por_hash
            .values()
            .filter_map(|b| match b {
                BloqueCadena::Post(p) => Some(p),
                BloqueCadena::Pow(_) => None,
            })
            .collect()
    }

    /// Admite un bloque (PoW o PoST). Devuelve `Ok` si es válido.
    ///
    /// Un bloque ya procesado devuelve el resultado almacenado, sin reprocesarlo.
    ///
    /// # Errores
    /// El [`MotivoBloque`] que haya invalidado el bloque.
    pub fn admitir(&mut self, bloque: BloqueCadena) -> Result<(), MotivoBloque> {
        let hash = bloque.hash();
        if let Some(v) = self.validos.get(&hash) {
            return if *v {
                Ok(())
            } else {
                Err(self
                    .motivos
                    .get(&hash)
                    .cloned()
                    .unwrap_or(MotivoBloque::ErrSinPadre))
            };
        }
        self.por_hash.insert(hash, bloque.clone());
        let resultado = match &bloque {
            BloqueCadena::Pow(_) => self.admitir_pow(&bloque),
            BloqueCadena::Post(_) => self.admitir_post(&bloque),
        };
        match &resultado {
            Ok(()) => {
                self.validos.insert(hash, true);
            }
            Err(motivo) => {
                self.validos.insert(hash, false);
                self.motivos.insert(hash, motivo.clone());
            }
        }
        resultado
    }

    /// Procesa un conjunto de bloques con un orden de llegada arbitrario, reintentando los que
    /// tienen padres aún no procesados (espejo de `resolver!`/`padres_listos` del oráculo T04).
    ///
    /// `llegada` es una permutación de índices de `bloques`. Un bloque cuyo padre no está en el
    /// conjunto se procesa y falla con `ErrSinPadre`; uno cuyo padre está pero aún no se procesó se
    /// reintenta.
    ///
    /// # Errores
    /// `ErrSinPadre` si no se puede progresar (ciclo o padre ausente no rechazable).
    pub fn resolver(
        &mut self,
        bloques: &[BloqueCadena],
        llegada: &[usize],
    ) -> Result<(), MotivoBloque> {
        for b in bloques {
            self.por_hash.entry(b.hash()).or_insert_with(|| b.clone());
        }
        let mut pendientes: Vec<usize> = llegada.to_vec();
        while !pendientes.is_empty() {
            let mut quedan = Vec::new();
            let mut progreso = false;
            for j in &pendientes {
                let Some(b) = bloques.get(*j) else {
                    continue;
                };
                if self.validos.contains_key(&b.hash()) {
                    continue;
                }
                if self.padres_listos(b) {
                    let _ = self.admitir(b.clone());
                    progreso = true;
                } else {
                    quedan.push(*j);
                }
            }
            pendientes = quedan;
            if !progreso {
                return Err(MotivoBloque::ErrSinPadre);
            }
        }
        Ok(())
    }

    /// ¿Están listos los padres de `b` (desconocido ⇒ se puede rechazar ya)?
    fn padres_listos(&self, b: &BloqueCadena) -> bool {
        if !self.por_hash.contains_key(&b.hash()) {
            return true;
        }
        for p in b.padres() {
            if Some(p) == self.terminal {
                continue;
            }
            if !self.por_hash.contains_key(&p) {
                return true;
            }
            if !self.validos.contains_key(&p) {
                return false;
            }
        }
        true
    }

    /// Admite un bloque PoW en modo estricto (`ED-1`).
    fn admitir_pow(&mut self, bloque: &BloqueCadena) -> Result<(), MotivoBloque> {
        let (hash, padre) = match bloque {
            BloqueCadena::Pow(b) => (b.hash(), b.padre()),
            BloqueCadena::Post(_) => return Err(MotivoBloque::ErrSinPadre),
        };
        let estado_padre = match padre {
            None => Estado::inicial(),
            Some(p) => self
                .post
                .get(&p)
                .cloned()
                .ok_or(MotivoBloque::ErrSinPadre)?,
        };
        let nuevo = aplicar(
            &estado_padre,
            &bloque.como_transicion(),
            &self.params,
            self.cbid,
        )?;
        if self.terminal.is_none()
            && let Some(altura) = bloque.como_transicion().hechos.altura()
            && es_terminal_condiciones(&nuevo, &self.params, altura)
        {
            self.terminal = Some(hash);
            self.estado_t = nuevo.clone();
        }
        self.past.insert(hash, estado_padre);
        self.post.insert(hash, nuevo);
        Ok(())
    }

    /// Admite un bloque PoST: forma, GHOSTDAG, `Estado(past(B))`, garantía y `post(B)`.
    fn admitir_post(&mut self, bloque: &BloqueCadena) -> Result<(), MotivoBloque> {
        let BloqueCadena::Post(p) = bloque else {
            return Err(MotivoBloque::ErrSinPadre);
        };
        self.chequear_forma(p)?;
        let terminal = self.terminal.ok_or(MotivoBloque::ErrSinPadre)?;
        self.inicializar_dag(terminal);
        let idx = self.anadir_al_dag(p)?;
        let base = self.estado_past_de_idx(idx, p)?;
        self.comprobar_garantia(&base, p)?;
        let (mut nuevo, _undo, desc) = aplicar_fusion(
            &base,
            &bloque.como_transicion(),
            Punto::Slot(p.slot),
            &self.params,
            self.cbid,
        )?;
        nuevo.peso_sufijo =
            nuevo
                .peso_sufijo
                .checked_add(p.peso)
                .ok_or(MotivoBloque::ErrTransicion(
                    zx_consensus::transicion::ErrorTransicion::ErrDesbordamiento,
                ))?;
        self.past.insert(p.hash, base);
        self.post.insert(p.hash, nuevo);
        self.descartes.insert(p.hash, desc);
        Ok(())
    }

    /// Comprueba forma y padres sin tocar el DAG (`ORDEN-W06a` §3, T04 `chequear_forma`).
    fn chequear_forma(&self, p: &BloquePost) -> Result<(), MotivoBloque> {
        if p.padres.is_empty() {
            return Err(MotivoBloque::ErrSinPadre);
        }
        let mut vistos = BTreeSet::new();
        for x in &p.padres {
            if !vistos.insert(*x) {
                return Err(MotivoBloque::ErrSinPadre);
            }
        }
        let terminal = self.terminal.ok_or(MotivoBloque::ErrSinPadre)?;
        if p.padres.contains(&terminal) && p.padres.len() != 1 {
            return Err(MotivoBloque::ErrSinPadre);
        }
        for x in &p.padres {
            if *x == terminal {
                continue;
            }
            if !self.por_hash.contains_key(x) || !self.es_valido(x) {
                return Err(MotivoBloque::ErrSinPadre);
            }
        }
        if p.slot < 1 {
            return Err(MotivoBloque::ErrSlot);
        }
        let mut ncb = 0usize;
        let mut icb = 0usize;
        for (i, (tx, _)) in p.txs.iter().enumerate() {
            if es_coinbase(tx) {
                ncb += 1;
                icb = i;
            }
        }
        if ncb > 1 {
            return Err(MotivoBloque::ErrEmision);
        }
        if ncb == 1 {
            if icb != 0 {
                return Err(MotivoBloque::ErrEmision);
            }
            let Some((tx, _)) = p.txs.first() else {
                return Err(MotivoBloque::ErrEmision);
            };
            if tx.version != 3 {
                return Err(MotivoBloque::ErrEmision);
            }
            if importe_de_coinbase_post(tx).is_some_and(|v| v.brek() == 0) {
                return Err(MotivoBloque::ErrSaldo);
            }
        }
        Ok(())
    }

    /// Inicializa el almacén GHOSTDAG con el terminal como raíz (D-P07).
    fn inicializar_dag(&mut self, terminal: BlockHash) {
        if self.dag.is_some() {
            return;
        }
        let params = ParametrosGhostdag {
            k: self.k,
            max_padres: MAX_PADRES_ORACULO,
            mergeset_limite: MERGESET_LIMITE_ORACULO,
            s_max: u64::MAX,
            u2: true,
            u3_dinamica: true,
            sp: ModoSp::Zerox,
            merge: ModoMerge::Terna,
        };
        let dag = AlmacenGhostdag::con_raiz_terminal(
            params,
            Algoritmo::Referencia,
            terminal,
            RangoSolucionValidado::para_oraculos(0),
        );
        self.dag = Some(dag);
        self.dag_idx.insert(terminal, 0);
    }

    /// Añade un bloque PoST al DAG y guarda sus datos para reconstruirlo.
    fn anadir_al_dag(&mut self, p: &BloquePost) -> Result<Idx, MotivoBloque> {
        let Some(dag) = self.dag.as_mut() else {
            return Err(MotivoBloque::ErrSinPadre);
        };
        let idx = dag
            .anadir_sintetico(bloque_ghostdag(
                p.hash,
                &p.padres,
                p.slot,
                p.distancia,
                p.sr,
                p.identidad,
            ))
            .map_err(|e| mapear_error_dag(&e))?;
        self.dag_idx.insert(p.hash, idx);
        self.dag_orden.push(p.hash);
        self.dag_datos.insert(
            p.hash,
            DatosDag {
                padres: p.padres.clone(),
                slot: p.slot,
                distancia: p.distancia,
                sr: p.sr,
                identidad: p.identidad,
            },
        );
        Ok(idx)
    }

    /// `Estado(past(B))` para el bloque `p` ya coloreado en el índice `idx` (`ED-2`, `RD-4`).
    fn estado_past_de_idx(&self, idx: Idx, p: &BloquePost) -> Result<Estado, MotivoBloque> {
        let Some(dag) = self.dag.as_ref() else {
            return Err(MotivoBloque::ErrSinPadre);
        };
        let gd = dag.datos(idx).ok_or(MotivoBloque::ErrSinPadre)?;
        let sp = gd.sp.ok_or(MotivoBloque::ErrSinPadre)?;
        let mut base = if sp == 0 {
            self.estado_t.clone()
        } else {
            let sp_hash = self.hash_de_idx(sp).ok_or(MotivoBloque::ErrSinPadre)?;
            self.post
                .get(&sp_hash)
                .cloned()
                .ok_or(MotivoBloque::ErrSinPadre)?
        };
        for x_idx in &gd.orden_mergeset {
            if dag.color_en(idx, *x_idx) == Some(Color::RojoU3) {
                continue;
            }
            let x_hash = self.hash_de_idx(*x_idx).ok_or(MotivoBloque::ErrSinPadre)?;
            let Some(x) = self.por_hash.get(&x_hash) else {
                return Err(MotivoBloque::ErrSinPadre);
            };
            let Some(x_slot) = x.slot() else {
                return Err(MotivoBloque::ErrSinPadre);
            };
            if let Some(f) = self.params.f_slots
                && p.slot > x_slot
                && p.slot - x_slot > f
            {
                return Err(MotivoBloque::ErrMergeDepth);
            }
            let (nuevo, _undo, _desc) = aplicar_fusion(
                &base,
                &x.como_transicion(),
                Punto::Slot(p.slot),
                &self.params,
                self.cbid,
            )?;
            base = nuevo;
        }
        Ok(base)
    }

    /// Garantía del productor sobre `Estado(past(B))` promovido en `slot(B)` (`RD-9`).
    fn comprobar_garantia(&self, base: &Estado, p: &BloquePost) -> Result<(), MotivoBloque> {
        let activo = activo_promovido(base, &p.productor, p.slot)?;
        if activo < self.params.q {
            return Err(MotivoBloque::ErrGarantia);
        }
        Ok(())
    }

    /// Puntas válidas: bloques PoST válidos sin hijo válido (`tips_validas` del oráculo).
    #[must_use]
    pub fn tips_validas(&self) -> Vec<BlockHash> {
        let mut con_hijo = BTreeSet::new();
        for (hash, bloque) in &self.por_hash {
            if !matches!(bloque, BloqueCadena::Post(_)) || !self.es_valido(hash) {
                continue;
            }
            for padre in bloque.padres() {
                if Some(padre) == self.terminal {
                    continue;
                }
                if self.es_valido(&padre) {
                    con_hijo.insert(padre);
                }
            }
        }
        let mut tips: Vec<BlockHash> = self
            .por_hash
            .iter()
            .filter(|(hash, bloque)| {
                matches!(bloque, BloqueCadena::Post(_))
                    && self.es_valido(hash)
                    && !con_hijo.contains(*hash)
            })
            .map(|(hash, _)| *hash)
            .collect();
        tips.sort_unstable();
        tips
    }

    /// Mejor punta por la regla C: mayor `blue_work`, menor `sd`, menor id (`C-GD-03`).
    #[must_use]
    pub fn mejor_punta(&self) -> Option<BlockHash> {
        let tips = self.tips_validas();
        if tips.is_empty() {
            return None;
        }
        let dag = self.dag.as_ref()?;
        tips.into_iter().min_by(|a, b| {
            let ra = self.dag_idx.get(a).and_then(|i| dag.rank(*i));
            let rb = self.dag_idx.get(b).and_then(|i| dag.rank(*i));
            comparar_rank(ra, rb)
        })
    }

    /// Cadena seleccionada desde la virtual, sin el terminal (`cadena_virtual`).
    #[must_use]
    pub fn cadena_virtual(&self) -> Vec<BlockHash> {
        let Some(virtual_dag) = self.dag_virtual().ok().flatten() else {
            return Vec::new();
        };
        let Some(sp) = virtual_dag.dag.datos(virtual_dag.idx).and_then(|g| g.sp) else {
            return Vec::new();
        };
        virtual_dag
            .dag
            .cadena_seleccionada(sp)
            .into_iter()
            .filter(|i| *i != 0)
            .filter_map(|i| self.hash_de_idx(i))
            .collect()
    }

    /// Bloques `rojo_U3` inertes en la historia seleccionada (`u3_virtual`).
    #[must_use]
    pub fn u3_virtual(&self) -> BTreeSet<BlockHash> {
        let mut inertes = BTreeSet::new();
        let Ok(Some(virtual_dag)) = self.dag_virtual() else {
            return inertes;
        };
        let Some(sp) = virtual_dag.dag.datos(virtual_dag.idx).and_then(|g| g.sp) else {
            return inertes;
        };
        for g in virtual_dag.dag.cadena_seleccionada(sp) {
            if g == 0 {
                continue;
            }
            if let Some(gd) = virtual_dag.dag.datos(g) {
                for x in &gd.orden_mergeset {
                    if virtual_dag.dag.color_en(g, *x) == Some(Color::RojoU3)
                        && let Some(h) = self.hash_de_idx(*x)
                    {
                        inertes.insert(h);
                    }
                }
            }
        }
        if let Some(gd) = virtual_dag.dag.datos(virtual_dag.idx) {
            for x in &gd.orden_mergeset {
                if virtual_dag.dag.color_en(virtual_dag.idx, *x) == Some(Color::RojoU3)
                    && let Some(h) = self.hash_de_idx(*x)
                {
                    inertes.insert(h);
                }
            }
        }
        inertes
    }

    /// `Estado(past(V))` (`ED-3`): merge­set completo de `V` en orden `C-GD-05`, sin `rojo_U3`.
    ///
    /// # Errores
    /// Un fallo de aplicación en modo fusión.
    pub fn estado_virtual(&self) -> Result<Estado, MotivoBloque> {
        let Ok(Some(virtual_dag)) = self.dag_virtual() else {
            return Ok(self.estado_t.clone());
        };
        let Some(sp) = virtual_dag.dag.datos(virtual_dag.idx).and_then(|g| g.sp) else {
            return Ok(self.estado_t.clone());
        };
        let mut estado = if sp == 0 {
            self.estado_t.clone()
        } else {
            let sp_hash = self.hash_de_idx(sp).ok_or(MotivoBloque::ErrSinPadre)?;
            self.post
                .get(&sp_hash)
                .cloned()
                .ok_or(MotivoBloque::ErrSinPadre)?
        };
        for x_idx in self.mergeset_virtual(&virtual_dag) {
            let Some(x) = self.por_hash.get(&x_idx) else {
                return Err(MotivoBloque::ErrSinPadre);
            };
            let (nuevo, _undo, _desc) = aplicar_fusion(
                &estado,
                &x.como_transicion(),
                Punto::Slot(virtual_dag.slot),
                &self.params,
                self.cbid,
            )?;
            estado = nuevo;
        }
        Ok(estado)
    }

    /// Recomputa desde `Estado(T)` la historia seleccionada (`R-FIN-8′(4)`): por cada bloque de
    /// cadena, su merge­set a `slot(C)` y luego `C`; al final el merge­set de `V` a `slot(V)`.
    ///
    /// # Errores
    /// Un fallo de aplicación en modo fusión.
    pub fn aplicar_historia(
        &self,
    ) -> Result<(Estado, Vec<BlockHash>, Vec<Descarte>), MotivoBloque> {
        let (estado, orden, descartes, _undos) = self.aplicar_historia_completa()?;
        Ok((estado, orden, descartes))
    }

    /// Como [`Self::aplicar_historia`], pero devuelve además los `Undo` por delta en orden de
    /// aplicación, para demostrar el undo exacto (`IE-4`).
    ///
    /// # Errores
    /// Un fallo de aplicación en modo fusión.
    pub fn aplicar_historia_completa(&self) -> Result<HistoriaAplicada, MotivoBloque> {
        let Ok(Some(virtual_dag)) = self.dag_virtual() else {
            return Ok((self.estado_t.clone(), Vec::new(), Vec::new(), Vec::new()));
        };
        let Some(sp) = virtual_dag.dag.datos(virtual_dag.idx).and_then(|g| g.sp) else {
            return Ok((self.estado_t.clone(), Vec::new(), Vec::new(), Vec::new()));
        };
        let (mut estado, mut orden, mut descartes, mut undos) =
            self.aplicar_cadena(&virtual_dag.dag, sp, Punto::Slot(0), self.estado_t.clone())?;
        // Merge­set de V a `slot(V)`.
        for x_hash in self.mergeset_virtual(&virtual_dag) {
            let Some(x) = self.por_hash.get(&x_hash) else {
                continue;
            };
            let (nuevo, undo, desc) = aplicar_fusion(
                &estado,
                &x.como_transicion(),
                Punto::Slot(virtual_dag.slot),
                &self.params,
                self.cbid,
            )?;
            estado = nuevo;
            orden.push(x_hash);
            undos.push(undo);
            for d in desc {
                descartes.push(Descarte {
                    bloque: x_hash,
                    indice: d.indice,
                    motivo: d.motivo,
                });
            }
        }
        Ok((estado, orden, descartes, undos))
    }

    /// Orden de aplicación de la historia seleccionada (bloques, sin transacciones).
    ///
    /// # Errores
    /// Un fallo de aplicación en modo fusión.
    pub fn orden_aplicacion(&self) -> Result<Vec<BlockHash>, MotivoBloque> {
        Ok(self.aplicar_historia_completa()?.1)
    }

    /// Aplica la rama que termina en `punta` desde `Estado(T)` y devuelve los `Undo` por delta.
    ///
    /// Es la recomputación que necesita una reorganización (`ED-3`, `C-REORG`): el undo exacto se
    /// demuestra deshaciendo los deltas en orden inverso con [`Self::deshacer_historia`].
    ///
    /// # Errores
    /// Un fallo de aplicación en modo fusión, o una punta desconocida.
    pub fn aplicar_rama(&self, punta: &BlockHash) -> Result<(Estado, Vec<Undo>), MotivoBloque> {
        let Some(dag) = self.dag.as_ref() else {
            return Err(MotivoBloque::ErrSinPadre);
        };
        let Some(idx) = self.dag_idx.get(punta).copied() else {
            return Err(MotivoBloque::ErrSinPadre);
        };
        let (estado, _orden, _desc, undos) =
            self.aplicar_cadena(dag, idx, Punto::Slot(0), self.estado_t.clone())?;
        Ok((estado, undos))
    }

    /// Deshace una historia aplicada con [`Self::aplicar_historia_completa`] o
    /// [`Self::aplicar_rama`], en orden inverso (`I-2`).
    #[must_use]
    pub fn deshacer_historia(&self, estado: &Estado, undos: &[Undo]) -> Estado {
        let mut restaurado = estado.clone();
        for undo in undos.iter().rev() {
            restaurado = deshacer(&restaurado, undo);
        }
        restaurado
    }

    /// Aplica la cadena seleccionada desde `sp` (sin el merge­set de `V`) y devuelve el estado, el
    /// orden, los descartes y los undos.
    fn aplicar_cadena(
        &self,
        dag: &AlmacenGhostdag,
        sp: Idx,
        _punto_inicial: Punto,
        estado_inicial: Estado,
    ) -> Result<HistoriaAplicada, MotivoBloque> {
        let mut estado = estado_inicial;
        let mut orden = Vec::new();
        let mut descartes = Vec::new();
        let mut undos = Vec::new();
        for g in dag.cadena_seleccionada(sp) {
            if g == 0 {
                continue;
            }
            let c_hash = self.hash_de_idx(g).ok_or(MotivoBloque::ErrSinPadre)?;
            let Some(c) = self.por_hash.get(&c_hash) else {
                return Err(MotivoBloque::ErrSinPadre);
            };
            let c_slot = c.slot().ok_or(MotivoBloque::ErrSinPadre)?;
            let Some(gd) = dag.datos(g) else {
                return Err(MotivoBloque::ErrSinPadre);
            };
            for x_idx in &gd.orden_mergeset {
                if dag.color_en(g, *x_idx) == Some(Color::RojoU3) {
                    continue;
                }
                let x_hash = self.hash_de_idx(*x_idx).ok_or(MotivoBloque::ErrSinPadre)?;
                let Some(x) = self.por_hash.get(&x_hash) else {
                    return Err(MotivoBloque::ErrSinPadre);
                };
                let (nuevo, undo, desc) = aplicar_fusion(
                    &estado,
                    &x.como_transicion(),
                    Punto::Slot(c_slot),
                    &self.params,
                    self.cbid,
                )?;
                estado = nuevo;
                orden.push(x_hash);
                undos.push(undo);
                for d in desc {
                    descartes.push(Descarte {
                        bloque: x_hash,
                        indice: d.indice,
                        motivo: d.motivo,
                    });
                }
            }
            let (mut nuevo, undo, desc) = aplicar_fusion(
                &estado,
                &c.como_transicion(),
                Punto::Slot(c_slot),
                &self.params,
                self.cbid,
            )?;
            let Some(peso) = c.peso() else {
                return Err(MotivoBloque::ErrSinPadre);
            };
            nuevo.peso_sufijo =
                nuevo
                    .peso_sufijo
                    .checked_add(peso)
                    .ok_or(MotivoBloque::ErrTransicion(
                        zx_consensus::transicion::ErrorTransicion::ErrDesbordamiento,
                    ))?;
            estado = nuevo;
            orden.push(c_hash);
            undos.push(undo);
            for d in desc {
                descartes.push(Descarte {
                    bloque: c_hash,
                    indice: d.indice,
                    motivo: d.motivo,
                });
            }
        }
        Ok((estado, orden, descartes, undos))
    }

    /// Hashes del merge­set de `V` a aplicar (sin `rojo_U3`), en orden `C-GD-05`.
    fn mergeset_virtual(&self, virtual_dag: &Virtual) -> Vec<BlockHash> {
        let Some(gd) = virtual_dag.dag.datos(virtual_dag.idx) else {
            return Vec::new();
        };
        gd.orden_mergeset
            .iter()
            .filter(|x| virtual_dag.dag.color_en(virtual_dag.idx, **x) != Some(Color::RojoU3))
            .filter_map(|x| self.hash_de_idx(*x))
            .collect()
    }

    /// Construye el almacén del virtual `V` reproduciendo la copia del GDR de T04.
    fn dag_virtual(&self) -> Result<Option<Virtual>, MotivoBloque> {
        let tips = self.tips_validas();
        if tips.is_empty() {
            return Ok(None);
        }
        let Some(terminal) = self.terminal else {
            return Ok(None);
        };
        if tips.len() > usize::from(zx_dag::ghostdag::MAX_PADRES_POR_DEFECTO) {
            // T04 usa `max_parents = typemax` para `V`; `zx-dag` acota a `MAX_PADRES`.
            return Err(MotivoBloque::ErrSinPadre);
        }
        let slot = tips
            .iter()
            .filter_map(|h| self.por_hash.get(h).and_then(BloqueCadena::slot))
            .max()
            .ok_or(MotivoBloque::ErrSinPadre)?;
        let params = ParametrosGhostdag {
            k: self.k,
            max_padres: u8::MAX,
            mergeset_limite: u32::MAX,
            s_max: u64::MAX,
            u2: true,
            u3_dinamica: true,
            sp: ModoSp::Zerox,
            merge: ModoMerge::Terna,
        };
        let mut dag = AlmacenGhostdag::con_raiz_terminal(
            params,
            Algoritmo::Referencia,
            terminal,
            RangoSolucionValidado::para_oraculos(0),
        );
        for hash in &self.dag_orden {
            let Some(datos) = self.dag_datos.get(hash) else {
                return Err(MotivoBloque::ErrSinPadre);
            };
            dag.anadir_sintetico(bloque_ghostdag(
                *hash,
                &datos.padres,
                datos.slot,
                datos.distancia,
                datos.sr,
                datos.identidad,
            ))
            .map_err(|e| mapear_error_dag(&e))?;
        }
        let idx = dag
            .anadir_sintetico(BloqueGhostdag {
                id: hash_de_id_textual("V"),
                padres: tips.clone(),
                slot,
                solution_distance: 0,
                rango_espacio: RangoSolucionValidado::para_oraculos(0),
                identidad: IdentidadGhostdag::SinBillete,
            })
            .map_err(|e| mapear_error_dag(&e))?;
        Ok(Some(Virtual { dag, idx, slot }))
    }

    /// Traduce un índice denso del DAG al `block_hash`.
    fn hash_de_idx(&self, idx: Idx) -> Option<BlockHash> {
        if idx == 0 {
            return self.terminal;
        }
        let pos = (idx as usize).checked_sub(1)?;
        self.dag_orden.get(pos).copied()
    }
}

/// Construye la entrada de `zx-dag` de un bloque PoST.
fn bloque_ghostdag(
    id: BlockHash,
    padres: &[BlockHash],
    slot: u64,
    distancia: u64,
    sr: u64,
    identidad: u64,
) -> BloqueGhostdag {
    BloqueGhostdag {
        id,
        padres: padres.to_vec(),
        slot,
        solution_distance: distancia,
        rango_espacio: RangoSolucionValidado::para_oraculos(sr),
        identidad: IdentidadGhostdag::de_fixture(identidad),
    }
}

/// ¿La transacción es una coinbase (v1 sin entradas, o v3)?
fn es_coinbase(tx: &Tx) -> bool {
    (tx.version == 1 && tx.inputs.is_empty()) || tx.version == 3
}

/// Importe declarado de una coinbase PoST, si la extensión lo es.
fn importe_de_coinbase_post(tx: &Tx) -> Option<Amount> {
    match &tx.extension {
        zx_core::ExtensionTx::CoinbasePost { importe, .. } => Some(*importe),
        _ => None,
    }
}

/// Activo de `clave` tras promover pendientes y créditos madurados en `slot` (`promover!` de T04).
fn activo_promovido(
    estado: &Estado,
    clave: &ClavePublica,
    slot: u64,
) -> Result<Amount, MotivoBloque> {
    let Some(g) = estado.garantias.get(clave) else {
        return Ok(Amount::CERO);
    };
    let mut total = g.activo;
    for p in g.pendientes.iter().chain(g.creditos.iter()) {
        if p.madura_en_slot.is_some_and(|s| s <= slot) {
            total = total
                .suma_comprobada(p.importe)
                .ok_or(MotivoBloque::ErrTransicion(
                    zx_consensus::transicion::ErrorTransicion::ErrDesbordamiento,
                ))?;
        }
    }
    Ok(total)
}

/// Orden de la regla C: mayor `blue_work`, menor `sd`, menor id.
fn comparar_rank(a: Option<Rank>, b: Option<Rank>) -> Ordering {
    match (a, b) {
        (Some(x), Some(y)) => y
            .blue_work
            .cmp(&x.blue_work)
            .then(x.solution_distance.cmp(&y.solution_distance))
            .then(x.id.cmp(&y.id)),
        _ => Ordering::Equal,
    }
}

/// Traduce un rechazo de `zx-dag` al motivo de bloque del oráculo (`mapear_motivo_gdr`).
fn mapear_error_dag(error: &ErrorDag) -> MotivoBloque {
    match error {
        ErrorDag::DemasiadosPadresDag { .. } | ErrorDag::BloqueDesconocido { .. } => {
            MotivoBloque::ErrSinPadre
        }
        ErrorDag::MergesetExcedeLimite { .. } => MotivoBloque::ErrMergeset,
        ErrorDag::BilleteDuplicadoU2 { .. } => MotivoBloque::ErrU2,
        ErrorDag::SaltoMayorSmax { .. } | ErrorDag::SlotDePadrePosterior { .. } => {
            MotivoBloque::ErrSlot
        }
        _ => MotivoBloque::ErrSinPadre,
    }
}
