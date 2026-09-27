//! Gestor del estado del DAG en memoria (`ORDEN-W06a`, `D-N02`; rediseño `ORDEN-W06d7`).
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
//! # `ORDEN-W06d7`: un DAG por terminal candidato (FC-3 de verdad)
//!
//! `W06d6` descubrió que esta implementación **congelaba** el terminal al admitir el primer bloque
//! PoST (`recalcular_terminal` solo corría mientras `dag.is_none()`) y solo mantenía **un** DAG. Eso
//! no es `TRN-09` (FC-3): dos nodos que cruzan el corte con terminales distintos no convergían nunca
//! (I-3 roto). El rediseño (decisiones del director en `ORDEN-W06d7.md` §3):
//!
//! 1. **Un [`DagTerminal`] por candidato** (`self.dags`): cada terminal que cumple el corte
//!    (`TRN-04`, [`es_primero_en_rama`](Cadena::es_primero_en_rama)) y tiene al menos un bloque PoST
//!    válido cuelga de su propio `AlmacenGhostdag` con raíz en ese terminal. Un bloque PoST
//!    pertenece al DAG del terminal de su pasado ([`Cadena::terminal_de_bloque_post`]); padres de
//!    terminales distintos son inválidos (`ErrTerminalAmbiguo`, `I-4`).
//! 2. **Selección FC-3 entre terminales** ([`Cadena::mejor_terminal_candidato`]): sin ningún DAG
//!    (sufijo PoST), gana el mayor trabajo PoW acumulado; en cuanto alguno tiene sufijo, solo esos
//!    compiten por mayor `blue_work` de su virtual, desempate por `comparar_terminal` (menor hash,
//!    reutilizado de `zx_consensus::transicion`, ya no reimplementado) y, si aún empata, por la
//!    regla `C-GD` (`solution_distance`, `id`).
//! 3. **`C-FIN-01` entre terminales** ([`Cadena::recalcular_seleccion`]): un nodo en línea no
//!    sustituye su terminal seleccionado por otro si el sufijo actual ya abarca `≥ F_slots` desde el
//!    corte (`s_0 = 0`, `CONTRATO-v0.md` §1); se mide con el `slot` máximo de las puntas válidas del
//!    terminal actual.
//! 4. **Tope** [`MAX_TERMINALES_CON_DAG`] = 8 ([`Cadena::dag_de_terminal_mut`]): un noveno candidato
//!    con sufijo PoST se ignora si su trabajo PoW no supera al peor de los ocho (se marca
//!    [`Cadena::limite_terminales_alcanzado`]); si lo supera, desaloja al peor.
//! 5. **API** (`terminal()`, `contexto_dag()`, `estado_virtual()`, `cadena_virtual()`,
//!    `mejor_punta()`…) devuelve lo del terminal **seleccionado**; hay accesos «_de» explícitos por
//!    terminal para quien (el nodo) necesite verificar contra un terminal que no es el seleccionado.
//!
//! Coste declarado (`V-ZRX/LINEO.md`, disciplina general): cada [`Cadena::dag_virtual_de`]
//! reconstruye el `AlmacenGhostdag` del virtual de ese terminal desde cero (patrón ya existente en
//! esta implementación antes de esta orden); con hasta 8 terminales y los tamaños de esta orden
//! (cientos de bloques), el coste adicional de recorrer varios terminales en cada selección es
//! aceptable sin banco de pruebas dedicado; si el número de terminales o de bloques creciera muy por
//! encima de esto, sería el primer punto a perfilar.
//!
//! La verificación de cabeceras no es de esta orden: `pow_valido`/`prueba_valida` llegan decididos.

use std::cmp::Ordering;
use std::collections::{BTreeMap, BTreeSet};

use primitive_types::U256;
use zx_consensus::transicion::{
    Estado, ParametrosEvidencia, ParametrosTransicion, Punto, TxDescartada, Undo, aplicar,
    aplicar_fusion, comparar_terminal, deshacer, es_terminal_condiciones,
};
use zx_core::{Amount, BlockHash, ClavePublica, ExtensionTx, Tx, validar_forma_tx_v4};
use zx_dag::ghostdag::{
    Algoritmo, AlmacenGhostdag, BloqueGhostdag, Color, IdentidadGhostdag, Idx, ModoMerge, ModoSp,
    Parametros as ParametrosGhostdag, Rank,
};
use zx_dag::{ErrorDag, RangoSolucionValidado, hash_de_id_textual};

use crate::bloque::{BloqueCadena, BloquePost};
use crate::error::MotivoBloque;

/// Tope de mergeset del oráculo (`C-GD-04`).
const MERGESET_LIMITE_ORACULO: u32 = 180;

/// Tope de terminales candidatos con DAG propio (`ORDEN-W06d7` decisión 4).
pub const MAX_TERMINALES_CON_DAG: usize = 8;

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
    identidad: IdentidadGhostdag,
}

/// El DAG GHOSTDAG propio de **un** terminal candidato (`ORDEN-W06d7` decisión 1).
///
/// Vive desde que se admite el primer bloque PoST que cuelga de ese terminal
/// ([`Cadena::dag_de_terminal_mut`]); antes de eso el terminal es solo una entrada de
/// [`Cadena::terminal_candidatos`], sin `DagTerminal`.
struct DagTerminal {
    dag: AlmacenGhostdag,
    dag_idx: BTreeMap<BlockHash, Idx>,
    dag_orden: Vec<BlockHash>,
    dag_datos: BTreeMap<BlockHash, DatosDag>,
}

impl DagTerminal {
    /// Crea el almacén con el terminal como raíz (D-P07).
    fn nueva(terminal: BlockHash, k: u32, max_padres: u8) -> Self {
        let params = ParametrosGhostdag {
            k,
            max_padres,
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
        let mut dag_idx = BTreeMap::new();
        dag_idx.insert(terminal, 0);
        Self {
            dag,
            dag_idx,
            dag_orden: Vec::new(),
            dag_datos: BTreeMap::new(),
        }
    }
}

/// Almacén virtual `V` de **un** terminal (una copia de su DAG con la punta virtual añadida).
struct Virtual {
    dag: AlmacenGhostdag,
    idx: Idx,
    slot: u64,
}

/// Gestor del estado del DAG en memoria.
pub struct Cadena {
    params: ParametrosTransicion,
    /// SL-4a · parámetros de evidencia. `zx-node` los deja inactivos (SL-4b); los arneses usan
    /// [`Cadena::nueva_con_evidencia`].
    evidencia: ParametrosEvidencia,
    k: u32,
    cbid: u32,
    max_padres: u8,
    por_hash: BTreeMap<BlockHash, BloqueCadena>,
    validos: BTreeMap<BlockHash, bool>,
    motivos: BTreeMap<BlockHash, MotivoBloque>,
    past: BTreeMap<BlockHash, Estado>,
    post: BTreeMap<BlockHash, Estado>,
    descartes: BTreeMap<BlockHash, Vec<TxDescartada>>,
    /// Terminal **seleccionado** por FC-3 (`ORDEN-W06d7` decisión 2), con `C-FIN-01` entre
    /// terminales (decisión 3). `None` mientras no hay ningún candidato.
    terminal_seleccionado: Option<BlockHash>,
    /// `Estado(terminal_seleccionado)`, cacheado para que [`Cadena::estado_terminal`] pueda seguir
    /// devolviendo una referencia (compatibilidad de API, decisión 6). Se refresca en
    /// [`Cadena::recalcular_seleccion`].
    estado_t: Estado,
    /// Un DAG por terminal que ya tiene al menos un bloque PoST válido (decisión 1). Acotado a
    /// [`MAX_TERMINALES_CON_DAG`] (decisión 4).
    dags: BTreeMap<BlockHash, DagTerminal>,
    /// Terminal al que pertenece cada bloque PoST ya admitido (para resolver `chequear_forma` y los
    /// accesos «_de» por terminal sin recorrer todo `por_hash`).
    post_terminal: BTreeMap<BlockHash, BlockHash>,
    /// Se marcó al menos una vez el tope de [`MAX_TERMINALES_CON_DAG`] (decisión 4, `limite_alcanzado`).
    limite_alcanzado: bool,
    /// Puntas PoW válidas conocidas: bloques PoW sin ningún hijo PoW válido todavía
    /// (`ORDEN-W06d3` decisión 3). Varias a la vez es exactamente una bifurcación PoW.
    tips_pow: BTreeSet<BlockHash>,
    /// Bloques PoW que, en su propia rama, ya cumplen `es_terminal_condiciones` (altura, trabajo,
    /// `Φ`) y son el **primero** de su rama en cumplirlo (`TRN-04`,
    /// [`Cadena::es_primero_en_rama`]). Candidatos a terminal para siempre (`ORDEN-W06d7`: ya no se
    /// deja de admitir candidatos nuevos al aparecer el primer bloque PoST, que era el hallazgo de
    /// `W06d6`).
    terminal_candidatos: BTreeSet<BlockHash>,
}

impl Cadena {
    /// Crea una cadena vacía con los parámetros de transición, el `k` de GHOSTDAG, el `CBID` y el
    /// **máximo de padres** de un bloque PoST.
    ///
    /// `max_padres` no tiene valor por defecto oculto (`ORDEN-W06a-C` decisión 1): el nodo usa el
    /// del perfil dev (15, `PERFIL-DEV-v0.md` §4) y el arnés diferencial de T04 usa 3, el límite de
    /// su generador. Es el tope que `zx-cadena` impone a cada `AlmacenGhostdag` interno; `zx-dag` lo
    /// acota a [`zx_core::MAX_PADRES`] (15) y a `u8`.
    #[must_use]
    pub fn nueva(params: ParametrosTransicion, k: u32, cbid: u32, max_padres: u8) -> Self {
        Self::nueva_con_evidencia(params, k, cbid, max_padres, ParametrosEvidencia::inactiva())
    }

    /// Igual que [`Cadena::nueva`], con los parámetros de evidencia explícitos (SL-4a).
    #[must_use]
    pub fn nueva_con_evidencia(
        params: ParametrosTransicion,
        k: u32,
        cbid: u32,
        max_padres: u8,
        evidencia: ParametrosEvidencia,
    ) -> Self {
        Self {
            params,
            evidencia,
            k,
            cbid,
            max_padres,
            por_hash: BTreeMap::new(),
            validos: BTreeMap::new(),
            motivos: BTreeMap::new(),
            past: BTreeMap::new(),
            post: BTreeMap::new(),
            descartes: BTreeMap::new(),
            terminal_seleccionado: None,
            estado_t: Estado::inicial(),
            dags: BTreeMap::new(),
            post_terminal: BTreeMap::new(),
            limite_alcanzado: false,
            tips_pow: BTreeSet::new(),
            terminal_candidatos: BTreeSet::new(),
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

    /// Hash del terminal **seleccionado** por FC-3 (`ORDEN-W06d7` decisión 2), si existe algún
    /// candidato.
    #[must_use]
    pub fn terminal(&self) -> Option<BlockHash> {
        self.terminal_seleccionado
    }

    /// `Estado(T)` del terminal seleccionado (el estado tras aplicar ese bloque PoW).
    #[must_use]
    pub fn estado_terminal(&self) -> &Estado {
        &self.estado_t
    }

    /// Todos los terminales candidatos conocidos (con DAG o sin él), en orden de hash.
    #[must_use]
    pub fn terminal_candidatos(&self) -> Vec<BlockHash> {
        self.terminal_candidatos.iter().copied().collect()
    }

    /// Terminales que ya tienen su propio DAG (al menos un bloque PoST válido), en orden de hash
    /// (`ORDEN-W06d7` decisión 1).
    #[must_use]
    pub fn terminales_con_dag(&self) -> Vec<BlockHash> {
        self.dags.keys().copied().collect()
    }

    /// ¿Se alcanzó alguna vez el tope [`MAX_TERMINALES_CON_DAG`] (decisión 4)?
    #[must_use]
    pub fn limite_terminales_alcanzado(&self) -> bool {
        self.limite_alcanzado
    }

    /// Terminal al que pertenece un bloque PoST ya admitido, si se conoce.
    #[must_use]
    pub fn terminal_de(&self, hash: &BlockHash) -> Option<BlockHash> {
        self.post_terminal.get(hash).copied()
    }

    /// Acceso al bloque por su hash, si se conoce.
    #[must_use]
    pub fn bloque(&self, hash: &BlockHash) -> Option<&BloqueCadena> {
        self.por_hash.get(hash)
    }

    /// El `AlmacenGhostdag` real del terminal **seleccionado**, si ya tiene DAG (`ORDEN-W06d1`,
    /// «Relanzamiento» punto 3; multi-terminal desde `ORDEN-W06d7`).
    ///
    /// `AlmacenGhostdag` ya implementa [`zx_dag::bloque_dag::ContextoDag`] sobre sus propios
    /// bloques admitidos, con `padre_seleccionado` calculado por GHOSTDAG real (`comparar_sp`,
    /// `C-GD-03`), no declarado por el candidato. Este accesor es lo que le faltaba a `Cadena` para
    /// que un llamante externo (el nodo) pueda verificar la cabecera de un candidato **antes** de
    /// admitirlo, sin volver a implementar la selección de padre en otro sitio.
    ///
    /// `None` hasta que se admite el **primer bloque PoST** del terminal seleccionado. Para
    /// verificar contra un terminal que no es el seleccionado (varios DAG a la vez), usa
    /// [`Cadena::contexto_dag_de`].
    #[must_use]
    pub fn contexto_dag(&self) -> Option<&zx_dag::ghostdag::AlmacenGhostdag> {
        self.terminal_seleccionado
            .and_then(|t| self.dags.get(&t))
            .map(|dt| &dt.dag)
    }

    /// El `AlmacenGhostdag` real de un terminal concreto, sea o no el seleccionado (`ORDEN-W06d7`
    /// decisión 5: el nodo necesita un servicio de verificación por terminal con DAG, no solo el
    /// seleccionado).
    #[must_use]
    pub fn contexto_dag_de(
        &self,
        terminal: BlockHash,
    ) -> Option<&zx_dag::ghostdag::AlmacenGhostdag> {
        self.dags.get(&terminal).map(|dt| &dt.dag)
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
    /// # `ErrSinPadre` por una dependencia que **todavía no ha llegado** no se cachea (RI-2a #1)
    ///
    /// Si el padre (o, en PoST, algún terminal candidato) del bloque no está disponible
    /// **todavía**, el rechazo es provisional: el mismo bloque, sometido otra vez después de que su
    /// dependencia llegue, MUST poder admitirse. La comprobación
    /// ([`Self::dependencia_no_disponible`]) se hace **antes** de tocar `admitir_pow`/`admitir_post`
    /// —y por tanto antes de cualquier mutación del DAG interno—, así que reintentar más tarde
    /// vuelve a ejecutar la tubería completa desde cero, nunca a medias.
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
        if self.dependencia_no_disponible(&bloque) {
            self.por_hash.insert(hash, bloque);
            return Err(MotivoBloque::ErrSinPadre);
        }
        self.por_hash.insert(hash, bloque.clone());
        let resultado = match &bloque {
            BloqueCadena::Pow(_) => self.admitir_pow(&bloque),
            BloqueCadena::Post(_) => self.admitir_post(&bloque),
        };
        match &resultado {
            Ok(()) => {
                self.validos.insert(hash, true);
                // `ORDEN-W06d7`: la selección FC-3 entre terminales se recalcula **aquí**, después
                // de marcar `hash` como válido — no dentro de `admitir_pow`/`admitir_post`. Un bloque
                // PoST recién admitido participa en `tips_validas_de`/`dag_virtual_de` (que filtran
                // por `Self::es_valido`) solo a partir de este punto; recalcular la selección antes
                // (como hacía una versión previa de este cambio) veía una vista atrasada de un
                // bloque —el que se acaba de admitir con éxito—, y un empate de `blue_work` que este
                // mismo bloque resolvía se evaluaba con el estado de un paso antes: no violaba
                // ningún invariante de aplicación (`past`/`post` ya estaban completos), pero sí I-3
                // por un paso de más entre "admitido" y "contado para la selección".
                self.recalcular_seleccion();
            }
            Err(motivo) => {
                self.validos.insert(hash, false);
                self.motivos.insert(hash, motivo.clone());
            }
        }
        resultado
    }

    /// ¿Depende `bloque` de algo (un padre PoW, o **cualquier** terminal candidato para un PoST)
    /// que esta `Cadena` todavía no tiene?
    #[must_use]
    fn dependencia_no_disponible(&self, bloque: &BloqueCadena) -> bool {
        match bloque {
            BloqueCadena::Pow(_) => bloque
                .padre_seleccionado()
                .is_some_and(|p| !self.post.contains_key(&p)),
            BloqueCadena::Post(p) => {
                if self.terminal_candidatos.is_empty() {
                    return true;
                }
                p.padres
                    .iter()
                    .any(|x| !self.terminal_candidatos.contains(x) && !self.es_valido(x))
            }
        }
    }

    /// Procesa un conjunto de bloques con un orden de llegada arbitrario, reintentando los que
    /// tienen padres aún no procesados (espejo de `resolver!`/`padres_listos` del oráculo T04).
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
            if self.terminal_candidatos.contains(&p) {
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
    ///
    /// Cada bloque se valida contra el estado de **su padre declarado** (`self.post.get(&p)`), no
    /// contra ninguna noción de "la punta": dos bloques con el mismo padre (una bifurcación PoW) se
    /// admiten los dos, cada uno con su propio `Estado(past)`/`Estado(post)` independiente.
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
            &self.evidencia,
        )?;

        // Una bifurcación PoW real: el padre deja de ser punta (si lo era) y este bloque lo es.
        if let Some(p) = padre {
            self.tips_pow.remove(&p);
        }
        self.tips_pow.insert(hash);

        // `ORDEN-W06d7` decisión 1: ya no se congela el primer terminal (hallazgo de W06d6); se
        // sigue registrando cualquier candidato nuevo, tenga o no otro terminal ya un DAG.
        let es_candidato = bloque
            .como_transicion()
            .hechos
            .altura()
            .is_some_and(|altura| es_terminal_condiciones(&nuevo, &self.params, altura))
            && self.es_primero_en_rama(padre);

        self.past.insert(hash, estado_padre);
        self.post.insert(hash, nuevo);

        if es_candidato {
            self.terminal_candidatos.insert(hash);
            // La recomputación de la selección FC-3 la hace `Cadena::admitir` (el llamante), después
            // de marcar `hash` como válido (`ORDEN-W06d7`, ver su comentario).
        }
        Ok(())
    }

    /// ¿Es `hash` (de padre `padre`) el **primer** bloque de su rama en cumplir
    /// `es_terminal_condiciones` (`TRN-04`: «ningún ancestro suyo cumple las tres condiciones»)?
    fn es_primero_en_rama(&self, padre: Option<BlockHash>) -> bool {
        let mut actual = padre;
        while let Some(p) = actual {
            if self.terminal_candidatos.contains(&p) {
                return false;
            }
            actual = match self.por_hash.get(&p) {
                Some(BloqueCadena::Pow(bt)) => bt.padre(),
                _ => None,
            };
        }
        true
    }

    /// Trabajo PoW acumulado de `hash`, si se conoce (`U256::zero()` si no).
    fn trabajo_de(&self, hash: &BlockHash) -> U256 {
        self.post.get(hash).map(|e| e.trabajo).unwrap_or_default()
    }

    /// Mejor terminal candidato **sin** ningún DAG con sufijo (fase puramente PoW, `TRN-09`
    /// primera cláusula): mayor trabajo acumulado, empate por menor hash.
    fn mejor_terminal_por_trabajo(&self) -> Option<BlockHash> {
        self.terminal_candidatos.iter().copied().min_by(|a, b| {
            self.trabajo_de(b)
                .cmp(&self.trabajo_de(a))
                .then_with(|| a.cmp(b))
        })
    }

    /// `Rank` (`blue_work`, `solution_distance`, `id`) del virtual de un terminal con DAG, si existe.
    fn rank_virtual_de(&self, terminal: BlockHash) -> Option<Rank> {
        let virtual_dag = self.dag_virtual_de(terminal).ok().flatten()?;
        virtual_dag.dag.rank(virtual_dag.idx)
    }

    /// Mejor terminal candidato por FC-3 (`TRN-09`): sin ningún sufijo PoST conocido, por trabajo
    /// PoW; en cuanto alguno tiene sufijo, solo esos compiten por `blue_work` de su virtual,
    /// desempate por [`comparar_terminal`] (reutilizado de `zx_consensus::transicion`, menor hash) y,
    /// si aún empata, por la regla `C-GD` completa (`solution_distance`, `id`) — inalcanzable en la
    /// práctica porque dos terminales son hashes distintos, pero se conserva por completitud
    /// (`ORDEN-W06d7` decisión 2, «después la de C-GD»).
    fn mejor_terminal_candidato(&self) -> Option<BlockHash> {
        if self.dags.is_empty() {
            return self.mejor_terminal_por_trabajo();
        }
        self.dags.keys().copied().min_by(|a, b| {
            let ra = self.rank_virtual_de(*a);
            let rb = self.rank_virtual_de(*b);
            comparar_blue_work(ra, rb)
                .then_with(|| comparar_terminal(Some(*a), Some(*b)).reverse())
                .then_with(|| comparar_rank(ra, rb))
        })
    }

    /// `slot` máximo entre las puntas válidas del DAG de `terminal` (0 si no tiene DAG o no tiene
    /// puntas todavía): es `d` para `C-FIN-01` entre terminales, con `s_0 = 0` (`CONTRATO-v0.md` §1).
    fn slot_max_de(&self, terminal: BlockHash) -> u64 {
        self.tips_validas_de(terminal)
            .iter()
            .filter_map(|h| self.por_hash.get(h).and_then(BloqueCadena::slot))
            .max()
            .unwrap_or(0)
    }

    /// Recalcula el terminal seleccionado tras un cambio (nuevo candidato o nuevo bloque PoST):
    /// FC-3 (`TRN-09`) con `C-FIN-01` entre terminales (`ORDEN-W06d7` decisión 3): un nodo en línea
    /// no sustituye su terminal si el sufijo actual ya abarca `≥ F_slots` desde el corte.
    fn recalcular_seleccion(&mut self) {
        if let Some(nuevo) = self.mejor_terminal_candidato() {
            let acepta = match self.terminal_seleccionado {
                None => true,
                Some(actual) if actual == nuevo => false,
                Some(actual) => match self.dags.get(&actual) {
                    None => true,
                    Some(_) => {
                        let d = self.slot_max_de(actual);
                        match self.params.f_slots {
                            None => true,
                            Some(tope) => d < tope,
                        }
                    }
                },
            };
            if acepta {
                self.terminal_seleccionado = Some(nuevo);
            }
        }
        self.estado_t = self
            .terminal_seleccionado
            .and_then(|t| self.post.get(&t).cloned())
            .unwrap_or_else(Estado::inicial);
    }

    /// Mejor punta PoW conocida por trabajo acumulado (empate: hash menor), sea o no ya terminal
    /// (`ORDEN-W06d3` decisión 3): es lo que sigue la plantilla de minado, para que un bloque propio
    /// siempre extienda la rama más pesada conocida, no una punta cualquiera.
    #[must_use]
    pub fn mejor_punta_pow(&self) -> Option<BlockHash> {
        self.tips_pow.iter().copied().min_by(|a, b| {
            self.trabajo_de(b)
                .cmp(&self.trabajo_de(a))
                .then_with(|| a.cmp(b))
        })
    }

    /// Trabajo PoW acumulado de un bloque admitido, si se conoce (`ORDEN-W06d3` decisión 3): lo que
    /// el nodo publica como `trabajo_acumulado` de su punta seleccionada en el saludo de red.
    #[must_use]
    pub fn trabajo_pow(&self, hash: &BlockHash) -> Option<U256> {
        self.post.get(hash).map(|e| e.trabajo)
    }

    /// Terminal al que resuelve un padre declarado: el propio hash si es un terminal candidato, o
    /// el terminal del bloque PoST ya admitido en ese hash.
    fn terminal_de_padre(&self, x: &BlockHash) -> Option<BlockHash> {
        if self.terminal_candidatos.contains(x) {
            Some(*x)
        } else {
            self.post_terminal.get(x).copied()
        }
    }

    /// Terminal único al que pertenecen **todos** los padres de `p` (`ORDEN-W06d7` decisión 1: un
    /// bloque PoST pertenece al DAG del terminal de su pasado).
    ///
    /// # Errores
    /// `ErrSinPadre` si algún padre es desconocido o inválido; `ErrTerminalAmbiguo` si los padres
    /// resuelven a más de un terminal distinto (`I-4`).
    fn terminal_de_bloque_post(&self, p: &BloquePost) -> Result<BlockHash, MotivoBloque> {
        let mut terminal_ref: Option<BlockHash> = None;
        for x in &p.padres {
            let Some(t) = self.terminal_de_padre(x) else {
                return Err(MotivoBloque::ErrSinPadre);
            };
            match terminal_ref {
                None => terminal_ref = Some(t),
                Some(prev) if prev != t => return Err(MotivoBloque::ErrTerminalAmbiguo),
                Some(_) => {}
            }
        }
        terminal_ref.ok_or(MotivoBloque::ErrSinPadre)
    }

    /// Admite un bloque PoST: forma, terminal de su pasado, GHOSTDAG, `Estado(past(B))`, garantía y
    /// `post(B)` (`ORDEN-W06d7`: opera sobre el [`DagTerminal`] de `p`, no necesariamente el
    /// seleccionado).
    fn admitir_post(&mut self, bloque: &BloqueCadena) -> Result<(), MotivoBloque> {
        let BloqueCadena::Post(p) = bloque else {
            return Err(MotivoBloque::ErrSinPadre);
        };
        let terminal = self.chequear_forma(p)?;
        self.dag_de_terminal_mut(terminal)?;
        let idx = self.anadir_al_dag(terminal, p)?;
        let base = self.estado_past_de_idx(terminal, idx, p)?;
        self.comprobar_garantia(&base, p)?;
        let (mut nuevo, _undo, desc) = aplicar_fusion(
            &base,
            &bloque.como_transicion(),
            Punto::Slot(p.slot),
            &self.params,
            self.cbid,
            &self.evidencia,
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
        self.post_terminal.insert(p.hash, terminal);
        // La recomputación de la selección FC-3 la hace `Cadena::admitir` (el llamante), después de
        // marcar `p.hash` como válido: solo entonces `tips_validas_de`/`dag_virtual_de` (que filtran
        // por `Self::es_valido`) cuentan este bloque para el `blue_work` de su terminal
        // (`ORDEN-W06d7`, ver el comentario en `Cadena::admitir`).
        Ok(())
    }

    /// Comprueba forma y padres sin tocar el DAG (`ORDEN-W06a` §3, T04 `chequear_forma`); resuelve
    /// y devuelve el terminal único de `p` (`ORDEN-W06d7`).
    fn chequear_forma(&self, p: &BloquePost) -> Result<BlockHash, MotivoBloque> {
        if p.padres.is_empty() {
            return Err(MotivoBloque::ErrSinPadre);
        }
        let mut vistos = BTreeSet::new();
        for x in &p.padres {
            if !vistos.insert(*x) {
                return Err(MotivoBloque::ErrSinPadre);
            }
        }
        let terminal = self.terminal_de_bloque_post(p)?;
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
        // SL-4c (§3.2): la forma de la `EvidenceTx` v4 (`EV-04`, `RAT-1`, `EV-01`) es forma de
        // bloque y se comprueba **antes** de la garantía del productor y de la semántica, igual
        // que `chequear_forma_evidencia` del oráculo T04 (`EstadoDAG.jl:292-294`).
        if self.evidencia.evp {
            for (tx, testigos) in &p.txs {
                if tx.version == 4 && matches!(tx.extension, ExtensionTx::Evidencia { .. }) {
                    validar_forma_tx_v4(tx, testigos, self.evidencia.cbid)
                        .map_err(|e| MotivoBloque::ErrTransicion(e.into()))?;
                }
            }
        }
        Ok(terminal)
    }

    /// Consigue (o crea) el [`DagTerminal`] de `terminal`, aplicando el tope
    /// [`MAX_TERMINALES_CON_DAG`] (`ORDEN-W06d7` decisión 4): si ya hay 8 y `terminal` es nuevo, se
    /// desaloja al peor (menor trabajo PoW) si `terminal` lo supera; si no, se ignora
    /// (`ErrLimiteTerminales`) y se marca [`Cadena::limite_terminales_alcanzado`].
    fn dag_de_terminal_mut(
        &mut self,
        terminal: BlockHash,
    ) -> Result<&mut DagTerminal, MotivoBloque> {
        if !self.dags.contains_key(&terminal) {
            if self.dags.len() >= MAX_TERMINALES_CON_DAG {
                let Some(peor) = self.dags.keys().copied().min_by(|a, b| {
                    self.trabajo_de(a)
                        .cmp(&self.trabajo_de(b))
                        .then_with(|| b.cmp(a))
                }) else {
                    // Inalcanzable: `self.dags.len() >= MAX_TERMINALES_CON_DAG > 0` garantiza al
                    // menos una clave. Defensivo, no un pánico: se trata como el mismo rechazo que
                    // el resto de este método ante un estado interno inesperado.
                    return Err(MotivoBloque::ErrLimiteTerminales);
                };
                self.limite_alcanzado = true;
                if self.trabajo_de(&terminal) <= self.trabajo_de(&peor) {
                    return Err(MotivoBloque::ErrLimiteTerminales);
                }
                self.dags.remove(&peor);
            }
            self.dags.insert(
                terminal,
                DagTerminal::nueva(terminal, self.k, self.max_padres),
            );
        }
        self.dags
            .get_mut(&terminal)
            .ok_or(MotivoBloque::ErrSinPadre)
    }

    /// Añade un bloque PoST al DAG de `terminal` y guarda sus datos para reconstruirlo.
    fn anadir_al_dag(&mut self, terminal: BlockHash, p: &BloquePost) -> Result<Idx, MotivoBloque> {
        let Some(dt) = self.dags.get_mut(&terminal) else {
            return Err(MotivoBloque::ErrSinPadre);
        };
        let idx = dt
            .dag
            .anadir_sintetico(bloque_ghostdag(
                p.hash,
                &p.padres,
                p.slot,
                p.distancia,
                p.sr,
                p.identidad,
            ))
            .map_err(|e| mapear_error_dag(&e))?;
        dt.dag_idx.insert(p.hash, idx);
        dt.dag_orden.push(p.hash);
        dt.dag_datos.insert(
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

    /// `Estado(past(B))` para el bloque `p` ya coloreado en el índice `idx` del DAG de `terminal`
    /// (`ED-2`, `RD-4`).
    fn estado_past_de_idx(
        &self,
        terminal: BlockHash,
        idx: Idx,
        p: &BloquePost,
    ) -> Result<Estado, MotivoBloque> {
        let Some(dt) = self.dags.get(&terminal) else {
            return Err(MotivoBloque::ErrSinPadre);
        };
        let gd = dt.dag.datos(idx).ok_or(MotivoBloque::ErrSinPadre)?;
        let sp = gd.sp.ok_or(MotivoBloque::ErrSinPadre)?;
        let mut base = if sp == 0 {
            self.post
                .get(&terminal)
                .cloned()
                .ok_or(MotivoBloque::ErrSinPadre)?
        } else {
            let sp_hash = self
                .hash_de_idx(terminal, sp)
                .ok_or(MotivoBloque::ErrSinPadre)?;
            self.post
                .get(&sp_hash)
                .cloned()
                .ok_or(MotivoBloque::ErrSinPadre)?
        };
        for x_idx in &gd.orden_mergeset {
            if dt.dag.color_en(idx, *x_idx) == Some(Color::RojoU3) {
                continue;
            }
            let x_hash = self
                .hash_de_idx(terminal, *x_idx)
                .ok_or(MotivoBloque::ErrSinPadre)?;
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
                &self.evidencia,
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

    /// Puntas válidas del terminal **seleccionado** (`tips_validas` del oráculo).
    #[must_use]
    pub fn tips_validas(&self) -> Vec<BlockHash> {
        self.terminal_seleccionado
            .map(|t| self.tips_validas_de(t))
            .unwrap_or_default()
    }

    /// Puntas válidas de un terminal concreto: bloques PoST válidos de su DAG sin hijo válido.
    #[must_use]
    pub fn tips_validas_de(&self, terminal: BlockHash) -> Vec<BlockHash> {
        let mut con_hijo = BTreeSet::new();
        for (hash, bloque) in &self.por_hash {
            if !matches!(bloque, BloqueCadena::Post(_)) || !self.es_valido(hash) {
                continue;
            }
            if self.post_terminal.get(hash) != Some(&terminal) {
                continue;
            }
            for padre in bloque.padres() {
                if padre == terminal {
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
                    && self.post_terminal.get(*hash) == Some(&terminal)
                    && !con_hijo.contains(*hash)
            })
            .map(|(hash, _)| *hash)
            .collect();
        tips.sort_unstable();
        tips
    }

    /// Mejor punta del terminal **seleccionado** por la regla C: mayor `blue_work`, menor `sd`,
    /// menor id (`C-GD-03`).
    #[must_use]
    pub fn mejor_punta(&self) -> Option<BlockHash> {
        self.terminal_seleccionado
            .and_then(|t| self.mejor_punta_de(t))
    }

    /// Como [`Cadena::mejor_punta`], para un terminal concreto.
    #[must_use]
    pub fn mejor_punta_de(&self, terminal: BlockHash) -> Option<BlockHash> {
        let tips = self.tips_validas_de(terminal);
        if tips.is_empty() {
            return None;
        }
        let dt = self.dags.get(&terminal)?;
        tips.into_iter().min_by(|a, b| {
            let ra = dt.dag_idx.get(a).and_then(|i| dt.dag.rank(*i));
            let rb = dt.dag_idx.get(b).and_then(|i| dt.dag.rank(*i));
            comparar_rank(ra, rb)
        })
    }

    /// Cadena seleccionada desde la virtual del terminal **seleccionado**, sin el terminal
    /// (`cadena_virtual`).
    #[must_use]
    pub fn cadena_virtual(&self) -> Vec<BlockHash> {
        self.terminal_seleccionado
            .map(|t| self.cadena_virtual_de(t))
            .unwrap_or_default()
    }

    /// Como [`Cadena::cadena_virtual`], para un terminal concreto.
    #[must_use]
    pub fn cadena_virtual_de(&self, terminal: BlockHash) -> Vec<BlockHash> {
        let Some(virtual_dag) = self.dag_virtual_de(terminal).ok().flatten() else {
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
            .filter_map(|i| self.hash_de_idx(terminal, i))
            .collect()
    }

    /// Bloques `rojo_U3` inertes en la historia seleccionada del terminal seleccionado
    /// (`u3_virtual`).
    #[must_use]
    pub fn u3_virtual(&self) -> BTreeSet<BlockHash> {
        self.terminal_seleccionado
            .map(|t| self.u3_virtual_de(t))
            .unwrap_or_default()
    }

    /// Como [`Cadena::u3_virtual`], para un terminal concreto.
    #[must_use]
    pub fn u3_virtual_de(&self, terminal: BlockHash) -> BTreeSet<BlockHash> {
        let mut inertes = BTreeSet::new();
        let Ok(Some(virtual_dag)) = self.dag_virtual_de(terminal) else {
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
                        && let Some(h) = self.hash_de_idx(terminal, *x)
                    {
                        inertes.insert(h);
                    }
                }
            }
        }
        if let Some(gd) = virtual_dag.dag.datos(virtual_dag.idx) {
            for x in &gd.orden_mergeset {
                if virtual_dag.dag.color_en(virtual_dag.idx, *x) == Some(Color::RojoU3)
                    && let Some(h) = self.hash_de_idx(terminal, *x)
                {
                    inertes.insert(h);
                }
            }
        }
        inertes
    }

    /// `Estado(past(V))` (`ED-3`) del terminal **seleccionado**: merge­set completo de `V` en orden
    /// `C-GD-05`, sin `rojo_U3`.
    ///
    /// # Errores
    /// Un fallo de aplicación en modo fusión.
    pub fn estado_virtual(&self) -> Result<Estado, MotivoBloque> {
        match self.terminal_seleccionado {
            Some(t) => self.estado_virtual_de(t),
            None => Ok(self.estado_t.clone()),
        }
    }

    /// Como [`Cadena::estado_virtual`], para un terminal concreto.
    ///
    /// # Errores
    /// Un fallo de aplicación en modo fusión.
    pub fn estado_virtual_de(&self, terminal: BlockHash) -> Result<Estado, MotivoBloque> {
        let estado_terminal = || {
            self.post
                .get(&terminal)
                .cloned()
                .unwrap_or_else(Estado::inicial)
        };
        let Ok(Some(virtual_dag)) = self.dag_virtual_de(terminal) else {
            return Ok(estado_terminal());
        };
        let Some(sp) = virtual_dag.dag.datos(virtual_dag.idx).and_then(|g| g.sp) else {
            return Ok(estado_terminal());
        };
        let mut estado = if sp == 0 {
            estado_terminal()
        } else {
            let sp_hash = self
                .hash_de_idx(terminal, sp)
                .ok_or(MotivoBloque::ErrSinPadre)?;
            self.post
                .get(&sp_hash)
                .cloned()
                .ok_or(MotivoBloque::ErrSinPadre)?
        };
        for x_idx in self.mergeset_virtual(terminal, &virtual_dag) {
            let Some(x) = self.por_hash.get(&x_idx) else {
                return Err(MotivoBloque::ErrSinPadre);
            };
            let (nuevo, _undo, _desc) = aplicar_fusion(
                &estado,
                &x.como_transicion(),
                Punto::Slot(virtual_dag.slot),
                &self.params,
                self.cbid,
                &self.evidencia,
            )?;
            estado = nuevo;
        }
        Ok(estado)
    }

    /// Recomputa desde `Estado(T)` la historia seleccionada del terminal **seleccionado**
    /// (`R-FIN-8′(4)`).
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
        let Some(terminal) = self.terminal_seleccionado else {
            return Ok((self.estado_t.clone(), Vec::new(), Vec::new(), Vec::new()));
        };
        let Ok(Some(virtual_dag)) = self.dag_virtual_de(terminal) else {
            return Ok((self.estado_t.clone(), Vec::new(), Vec::new(), Vec::new()));
        };
        let Some(sp) = virtual_dag.dag.datos(virtual_dag.idx).and_then(|g| g.sp) else {
            return Ok((self.estado_t.clone(), Vec::new(), Vec::new(), Vec::new()));
        };
        let (mut estado, mut orden, mut descartes, mut undos) = self.aplicar_cadena(
            terminal,
            &virtual_dag.dag,
            sp,
            self.post
                .get(&terminal)
                .cloned()
                .unwrap_or_else(Estado::inicial),
        )?;
        // Merge­set de V a `slot(V)`.
        for x_hash in self.mergeset_virtual(terminal, &virtual_dag) {
            let Some(x) = self.por_hash.get(&x_hash) else {
                continue;
            };
            let (nuevo, undo, desc) = aplicar_fusion(
                &estado,
                &x.como_transicion(),
                Punto::Slot(virtual_dag.slot),
                &self.params,
                self.cbid,
                &self.evidencia,
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

    /// Aplica la rama que termina en `punta` desde `Estado(T)` de **su** terminal y devuelve los
    /// `Undo` por delta (`ED-3`, `C-REORG`); resuelve el terminal de `punta` por
    /// [`Cadena::terminal_de`].
    ///
    /// # Errores
    /// Un fallo de aplicación en modo fusión, o una punta desconocida.
    pub fn aplicar_rama(&self, punta: &BlockHash) -> Result<(Estado, Vec<Undo>), MotivoBloque> {
        let terminal = self.terminal_de(punta).ok_or(MotivoBloque::ErrSinPadre)?;
        let Some(dt) = self.dags.get(&terminal) else {
            return Err(MotivoBloque::ErrSinPadre);
        };
        let Some(idx) = dt.dag_idx.get(punta).copied() else {
            return Err(MotivoBloque::ErrSinPadre);
        };
        let estado_inicial = self
            .post
            .get(&terminal)
            .cloned()
            .unwrap_or_else(Estado::inicial);
        let (estado, _orden, _desc, undos) =
            self.aplicar_cadena(terminal, &dt.dag, idx, estado_inicial)?;
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

    /// Aplica la cadena seleccionada de `terminal` desde `sp` (sin el merge­set de `V`) y devuelve
    /// el estado, el orden, los descartes y los undos.
    fn aplicar_cadena(
        &self,
        terminal: BlockHash,
        dag: &AlmacenGhostdag,
        sp: Idx,
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
            let c_hash = self
                .hash_de_idx(terminal, g)
                .ok_or(MotivoBloque::ErrSinPadre)?;
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
                let x_hash = self
                    .hash_de_idx(terminal, *x_idx)
                    .ok_or(MotivoBloque::ErrSinPadre)?;
                let Some(x) = self.por_hash.get(&x_hash) else {
                    return Err(MotivoBloque::ErrSinPadre);
                };
                let (nuevo, undo, desc) = aplicar_fusion(
                    &estado,
                    &x.como_transicion(),
                    Punto::Slot(c_slot),
                    &self.params,
                    self.cbid,
                    &self.evidencia,
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
                &self.evidencia,
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

    /// Hashes del merge­set de `V` a aplicar (sin `rojo_U3`), en orden `C-GD-05`, para `terminal`.
    fn mergeset_virtual(&self, terminal: BlockHash, virtual_dag: &Virtual) -> Vec<BlockHash> {
        let Some(gd) = virtual_dag.dag.datos(virtual_dag.idx) else {
            return Vec::new();
        };
        gd.orden_mergeset
            .iter()
            .filter(|x| virtual_dag.dag.color_en(virtual_dag.idx, **x) != Some(Color::RojoU3))
            .filter_map(|x| self.hash_de_idx(terminal, *x))
            .collect()
    }

    /// Construye el almacén del virtual `V` de `terminal` reproduciendo la copia del GDR de T04.
    fn dag_virtual_de(&self, terminal: BlockHash) -> Result<Option<Virtual>, MotivoBloque> {
        let Some(dt) = self.dags.get(&terminal) else {
            return Ok(None);
        };
        let tips = self.tips_validas_de(terminal);
        if tips.is_empty() {
            return Ok(None);
        }
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
        for hash in &dt.dag_orden {
            let Some(datos) = dt.dag_datos.get(hash) else {
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

    /// Traduce un índice denso del DAG de `terminal` al `block_hash`.
    fn hash_de_idx(&self, terminal: BlockHash, idx: Idx) -> Option<BlockHash> {
        if idx == 0 {
            return Some(terminal);
        }
        let dt = self.dags.get(&terminal)?;
        let pos = (idx as usize).checked_sub(1)?;
        dt.dag_orden.get(pos).copied()
    }
}

/// Construye la entrada de `zx-dag` de un bloque PoST.
///
/// La identidad se recibe ya construida: la ruta real (`IdentidadGhostdag::Billete`, derivada de la
/// cabecera por `zx_dag::identidad_de_cabecera`) no se proyecta a `u64`; el arnés diferencial pasa
/// `de_fixture` explícitamente.
fn bloque_ghostdag(
    id: BlockHash,
    padres: &[BlockHash],
    slot: u64,
    distancia: u64,
    sr: u64,
    identidad: IdentidadGhostdag,
) -> BloqueGhostdag {
    BloqueGhostdag {
        id,
        padres: padres.to_vec(),
        slot,
        solution_distance: distancia,
        rango_espacio: RangoSolucionValidado::para_oraculos(sr),
        identidad,
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

/// Comparador de **solo** `blue_work` entre virtuales de dos terminales (`ORDEN-W06d7` decisión 2,
/// primera cláusula de FC-3 entre terminales); el desempate por hash y por el resto de `C-GD` va
/// aparte (`comparar_terminal`, `comparar_rank`), porque el `id`/`solution_distance` del nodo
/// sintético `V` no distingue terminales (es la misma constante en todos).
fn comparar_blue_work(a: Option<Rank>, b: Option<Rank>) -> Ordering {
    match (a, b) {
        (Some(x), Some(y)) => y.blue_work.cmp(&x.blue_work),
        (Some(_), None) => Ordering::Less,
        (None, Some(_)) => Ordering::Greater,
        (None, None) => Ordering::Equal,
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
