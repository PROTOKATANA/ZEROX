//! GHOSTDAG y `rank` (SPEC §11 `C-GD-01`…`C-GD-09` y §7.2 `C-ORD-01`…`C-ORD-03`).
//!
//! # Qué implementa
//!
//! Dado un DAG de bloques `(id, padres, slot, solution_distance, rango de espacio SR,
//! identidad de billete)`, este módulo calcula, como **función exclusiva de `past(B)`**
//! (`C-GD-09`): el padre seleccionado `sp(B)` (`C-GD-03`), el mergeset (`C-GD-04`), su orden
//! (`C-GD-05`), el coloreo azul/`rojo_k`/`rojo_U3` (`C-GD-06`, `C-GD-07`), `blue_score` y
//! `blue_work` (`C-GD-08`), y `rank` con el orden de aplicación de `C-ORD-03`.
//!
//! # Aritmética (LINEO §9)
//!
//! **Ni un solo flotante.** `w(B) = ⌊2^128/(SR+1)⌋` (`C-GD-01`) es división entera exacta en
//! `U256`; todo `blue_work` va en `u256` (`C-GD-02`) con suma **comprobada**: un desbordamiento
//! devuelve [`ConsensusError::BlueWorkDesbordado`], nunca envuelve. No se hereda `Uint192`.
//!
//! # Representación elegida (LINEO §8.2) y su coste
//!
//! - **IDs densos.** Los `BlockHash` de 32 B viven una sola vez en `ids` + un `HashMap` de
//!   índice; todo el camino caliente compara `u32` densos (LINEO §4: «IDs densos `Int32/Int64`»)
//!   en vez de arrays de 32 B en mapas.
//! - **Adyacencia contigua.** `padres: Vec<Vec<u32>>` por bloque. El universo de un mergeset son
//!   los padres de `B` y sus ancestros dentro del anticono, ≤ 15 padres y mergeset ≤ 180
//!   (R-FIN-12), así que el coste por bloque está acotado por esos topes, no por `n`.
//! - **Conjuntos de bits densos.** El pasado estricto (`anc`) y el blue set de la referencia se
//!   guardan en `ConjuntoBits` (`Vec<u64>`), no en `HashSet` (LINEO §4). La operación dominante
//!   es la consulta de anticono `x ∈ anticone(cand)`, que se resuelve con dos consultas de bit
//!   `O(1)`; iterar el blue set cuesta `O(n/64 + azules)`.
//! - **Referencia + kernel.** Hay dos implementaciones: [`Algoritmo::Referencia`] recalcula la
//!   definición directa del k-cluster sobre el blue set completo (`O(|blue set|²)` por mergeset),
//!   y [`Algoritmo::Kernel`] implementa el algoritmo incremental (walk por la cadena del `sp` con
//!   el mapa de tamaños de anticono azul), `O(|mergeset|·|cadena|·(k+1))`. El test diferencial los
//!   compara; LINEO §2/§10 exigen medir el caso real, no el juguete (ver `RENDIMIENTO.md`).
//!
//! El almacén es **en memoria** y de estudio. Su persistencia y su cableado a `zx-node`/`zx-storage`
//! son el encargo 04; aquí no se toca `fork_choice.rs`, que sigue siendo la selección lineal vigente.

use std::cmp::Ordering;
use std::collections::{HashMap, HashSet, VecDeque};

use primitive_types::U256;
use zx_core::digest::{BlockHash, Digest};
use zx_core::preimage::dag::{MAX_PADRES, PadresDag};

use crate::bloque_dag::ContextoDag;
use crate::error::ConsensusError;

/// `k` por defecto de R-FIN-12 (elegido, `SPEC.md:1609`).
pub const K_POR_DEFECTO: u32 = 30;
/// Máximo de padres por bloque (R-FIN-12, `C-GD-04`).
pub const MAX_PADRES_POR_DEFECTO: u8 = 15;
/// Tope de mergeset: `|mergeset(B)| + 1 ≤ 180` (R-FIN-12, `C-GD-04`).
pub const MERGESET_LIMITE_POR_DEFECTO: u32 = 180;
/// `S_max = 150` slots (C-GD-04).
pub const S_MAX_POR_DEFECTO: u64 = 150;

/// Índice denso de un bloque dentro del [`AlmacenGhostdag`].
pub type Idx = u32;

/// Modo de selección del padre `sp(B)` (`C-GD-03`).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ModoSp {
    /// Regla C: mayor `blue_work`; empate → **menor** `sd`; empate → **menor** id. Dirección
    /// **mixta** decidida por Katana (opción C), deliberadamente distinta de Kaspa.
    Zerox,
    /// Modo histórico `:kaspa` (mayor `(bw, id)`); se conserva para los vectores oficiales.
    Kaspa,
}

/// Modo de orden del mergeset (colorear y aplicar, `C-GD-05`).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ModoMerge {
    /// Regla C: `(blue_work, solution_distance, id)` ascendente.
    Terna,
    /// Modo histórico `:kaspa`: `(blue_work, id)` ascendente, sin `sd`.
    Kaspa,
}

/// Qué implementación del coloreo ejecuta el almacén.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Algoritmo {
    /// Definición directa del k-cluster sobre el blue set completo (clara, cuadrática).
    Referencia,
    /// Algoritmo incremental con el walk por la cadena del `sp` (el del nodo).
    Kernel,
}

/// Parámetros de GHOSTDAG (`C-GD-04`, R-FIN-12). Los valores por defecto son la regla C.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Parametros {
    /// k del k-cluster.
    pub k: u32,
    /// Máximo de padres.
    pub max_padres: u8,
    /// Tope de `|mergeset| + 1`.
    pub mergeset_limite: u32,
    /// `S_max` en slots.
    pub s_max: u64,
    /// U2 activa (invalidez por billete repetido).
    pub u2: bool,
    /// U3″ dinámica activa.
    pub u3_dinamica: bool,
    /// Modo de `sp(B)`.
    pub sp: ModoSp,
    /// Modo de orden del mergeset.
    pub merge: ModoMerge,
}

impl Default for Parametros {
    fn default() -> Self {
        Self {
            k: K_POR_DEFECTO,
            max_padres: MAX_PADRES_POR_DEFECTO,
            mergeset_limite: MERGESET_LIMITE_POR_DEFECTO,
            s_max: S_MAX_POR_DEFECTO,
            u2: true,
            u3_dinamica: true,
            sp: ModoSp::Zerox,
            merge: ModoMerge::Terna,
        }
    }
}

/// Color de un candidato del mergeset en el bloque de cadena que lo fusiona (`C-GD-09`:
/// contextual).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Color {
    /// Azul: pasa las dos condiciones del k-cluster.
    Azul,
    /// Excluido por el tope de anticono azul del k-cluster (`C-GD-06`).
    RojoK,
    /// Excluido por unicidad de billete, sin evaluar el k-cluster (`C-GD-07`, U3″).
    RojoU3,
}

/// Bloque de entrada al almacén GHOSTDAG.
#[derive(Clone, Debug)]
pub struct BloqueGhostdag {
    /// Id de 32 bytes.
    pub id: BlockHash,
    /// Padres declarados (el orden es irrelevante: el `sp` se recalcula).
    pub padres: Vec<BlockHash>,
    /// Índice PoT declarado.
    pub slot: u64,
    /// `solution_distance` de la prueba PoAS/PoT.
    pub solution_distance: u64,
    /// Rango de espacio `SR`; determina el peso `⌊2^128/(SR+1)⌋`.
    pub rango_espacio: u64,
    /// Identidad de billete comprimida; `0` = sin billete.
    pub identidad: u64,
}

/// `rank(B) = (blue_work, solution_distance, id)` (`C-ORD-01`), ascendente.
///
/// El orden derivado de los campos, en este orden, ES el de `C-ORD-01`: `U256` y `u64` son
/// órdenes totales y `BlockHash` compara 32 bytes lexicográficamente. Termina en el id, así que
/// bajo el supuesto de no colisión es **total**: `C-ORD-02` no necesita tercer desempate.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub struct Rank {
    /// `blue_work` acumulado.
    pub blue_work: U256,
    /// `solution_distance`.
    pub solution_distance: u64,
    /// Id de 32 bytes.
    pub id: BlockHash,
}

/// Conjunto de bits sobre índices densos (`LINEO §4`).
#[derive(Clone, Debug, PartialEq, Eq, Default)]
struct ConjuntoBits {
    palabras: Vec<u64>,
}

impl ConjuntoBits {
    fn nuevos() -> Self {
        Self {
            palabras: Vec::new(),
        }
    }

    fn contiene(&self, i: Idx) -> bool {
        let pos = i as usize;
        let (w, b) = (pos >> 6, pos & 63);
        self.palabras.get(w).is_some_and(|p| p & (1u64 << b) != 0)
    }

    fn insertar(&mut self, i: Idx) {
        let pos = i as usize;
        let (w, b) = (pos >> 6, pos & 63);
        if self.palabras.len() <= w {
            self.palabras.resize(w + 1, 0);
        }
        if let Some(p) = self.palabras.get_mut(w) {
            *p |= 1u64 << b;
        }
    }

    fn unir(&mut self, otra: &Self) {
        if self.palabras.len() < otra.palabras.len() {
            self.palabras.resize(otra.palabras.len(), 0);
        }
        for (a, b) in self.palabras.iter_mut().zip(otra.palabras.iter()) {
            *a |= *b;
        }
    }

    fn iter(&self) -> impl Iterator<Item = Idx> + '_ {
        self.palabras.iter().enumerate().flat_map(|(w, p)| {
            let p = *p;
            (0..64u32).filter_map(move |b| (p & (1u64 << b) != 0).then_some((w as u32) * 64 + b))
        })
    }
}

/// Valor centinela de «sin entrada» en las tablas densas de tamaños de anticono.
const SIN_ENTRADA: u32 = u32::MAX;

/// Estado interno específico del algoritmo, necesario para el bloque siguiente.
///
/// `tam` y `bas` se indexan por **índice denso de bloque**. Los índices son densos, así que la
/// consulta es un acceso a vector `O(1)` sin hashing (LINEO §4: universo denso ⇒ `Vector`, no
/// `HashMap`). Se midió que la alternativa con `HashMap` (SipHash) multiplicaba por ~3,5 el
/// coste del kernel en el mergeset máximo, y la lista de pares con búsqueda lineal no acotaba
/// bien; ver `RENDIMIENTO.md`.
#[derive(Clone, Debug, PartialEq, Eq)]
enum EstadoInterno {
    /// Blue set completo de `past(B) ∪ {B}` y `tam[b] = |anticone(b) ∩ blue set|`.
    Referencia {
        blueset: ConjuntoBits,
        tam: Vec<u32>,
    },
    /// `blues_anticone_sizes` del algoritmo incremental, por índice de bloque.
    Kernel { bas: Vec<u32> },
}

/// Resultado de revisar un candidato contra un tramo de la cadena del `sp`.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum Revision {
    /// Azul en este tramo (no hay que seguir subiendo).
    Azul,
    /// Rojo: el k-cluster se rompe.
    Rojo,
    /// Aún no decide; hay que seguir por la cadena del `sp`.
    Pendiente,
}

/// Dato GHOSTDAG almacenado de un bloque (`C-GD-09`: invariante frente al orden de llegada).
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct DatosGhostdag {
    /// Padre seleccionado; `None` solo para el génesis.
    pub sp: Option<Idx>,
    /// Mergeset completo en el orden de coloreado (sin `sp`), `C-GD-05`.
    pub orden_mergeset: Vec<Idx>,
    /// `blues(B) = [sp] ++ azules del mergeset`, en orden de coloreado.
    pub blues: Vec<Idx>,
    /// `rojo_k` y `rojo_U3` en orden de coloreado.
    pub rojos: Vec<Idx>,
    /// Color de cada bloque rojo del mergeset (los azules están en `blues`).
    pub colores: Vec<(Idx, Color)>,
    /// Identidades azules acumuladas, ordenadas (comparación determinista).
    pub blue_idents: Vec<u64>,
    /// `blue_score(B)` (conteo, `C-GD-08`).
    pub blue_score: u64,
    /// `blue_work(B)` (peso acumulado en `u256`, `C-GD-02`).
    pub blue_work: U256,
    estado: EstadoInterno,
}

/// `w(B) = ⌊2^128/(SR+1)⌋` (`C-GD-01`), división entera exacta.
///
/// `SR` es `u64`, así que el divisor es `≥ 1`. `SR = 0` da `2^128`; `SR = 2^64−1` da el mínimo
/// `2^64 > 0`.
#[must_use]
pub fn peso(rango_espacio: u64) -> U256 {
    (U256::one() << 128usize) / (U256::from(rango_espacio) + U256::one())
}

/// Suma comprobada de `blue_work` (`C-GD-02`, C-ENC-03).
///
/// # Errores
/// [`ConsensusError::BlueWorkDesbordado`] si el resultado no cabe en `u256`.
pub fn sumar_blue_work(a: U256, b: U256) -> Result<U256, ConsensusError> {
    a.checked_add(b).ok_or(ConsensusError::BlueWorkDesbordado)
}

fn hash_desde_id(id: &[u8; 32]) -> BlockHash {
    BlockHash::from_digest(Digest::from_bytes(*id))
}

/// Convierte un id textual ASCII en un `BlockHash` rellenando con ceros a la derecha, igual que
/// `hash_de_id` de GDR-v0.2. Es lo que usa el test del oráculo para casar ids.
#[must_use]
pub fn hash_de_id_textual(s: &str) -> BlockHash {
    let b = s.as_bytes();
    let mut id = [0u8; 32];
    let n = b.len().min(32);
    if let (Some(dst), Some(src)) = (id.get_mut(..n), b.get(..n)) {
        dst.copy_from_slice(src);
    }
    hash_desde_id(&id)
}

/// Almacén GHOSTDAG en memoria.
///
/// Construido con [`AlmacenGhostdag::nuevo`] y alimentado con [`AlmacenGhostdag::anadir`].
pub struct AlmacenGhostdag {
    params: Parametros,
    algoritmo: Algoritmo,
    genesis: BlockHash,
    indice: HashMap<BlockHash, Idx>,
    ids: Vec<BlockHash>,
    padres: Vec<Vec<Idx>>,
    slots: Vec<u64>,
    sds: Vec<u64>,
    srs: Vec<u64>,
    idents: Vec<u64>,
    anc: Vec<ConjuntoBits>,
    gd: Vec<DatosGhostdag>,
}

impl AlmacenGhostdag {
    /// Crea el almacén con un génesis.
    #[must_use]
    pub fn nuevo(
        params: Parametros,
        algoritmo: Algoritmo,
        id_genesis: BlockHash,
        slot_genesis: u64,
        sr_genesis: u64,
        ident_genesis: u64,
    ) -> Self {
        let mut anc = ConjuntoBits::nuevos();
        let genesis_idx: Idx = 0;
        anc.insertar(genesis_idx);
        let mut blueset = ConjuntoBits::nuevos();
        blueset.insertar(genesis_idx);
        let estado = match algoritmo {
            Algoritmo::Referencia => {
                let tam = vec![0u32; genesis_idx as usize + 1];
                EstadoInterno::Referencia { blueset, tam }
            }
            Algoritmo::Kernel => {
                let mut bas = vec![SIN_ENTRADA; genesis_idx as usize + 1];
                fijar_tabla(&mut bas, genesis_idx, 0);
                EstadoInterno::Kernel { bas }
            }
        };
        let blue_idents = if ident_genesis == 0 {
            Vec::new()
        } else {
            vec![ident_genesis]
        };
        let gd = DatosGhostdag {
            sp: None,
            orden_mergeset: Vec::new(),
            blues: vec![genesis_idx],
            rojos: Vec::new(),
            colores: Vec::new(),
            blue_idents,
            blue_score: 0,
            blue_work: U256::zero(),
            estado,
        };
        let mut indice = HashMap::new();
        indice.insert(id_genesis, genesis_idx);
        Self {
            params,
            algoritmo,
            genesis: id_genesis,
            indice,
            ids: vec![id_genesis],
            padres: vec![Vec::new()],
            slots: vec![slot_genesis],
            sds: vec![0],
            srs: vec![sr_genesis],
            idents: vec![ident_genesis],
            anc: vec![anc],
            gd: vec![gd],
        }
    }

    /// Parámetros activos.
    #[must_use]
    pub const fn parametros(&self) -> &Parametros {
        &self.params
    }

    /// Algoritmo activo.
    #[must_use]
    pub const fn algoritmo(&self) -> Algoritmo {
        self.algoritmo
    }

    /// Número de bloques (incluido el génesis).
    #[must_use]
    pub fn len(&self) -> usize {
        self.ids.len()
    }

    /// ¿Está vacío? Nunca: siempre hay génesis.
    #[must_use]
    pub fn is_empty(&self) -> bool {
        false
    }

    /// Hash del génesis.
    #[must_use]
    pub const fn genesis(&self) -> BlockHash {
        self.genesis
    }

    /// Datos GHOSTDAG del bloque `i`, si existe.
    #[must_use]
    pub fn datos(&self, i: Idx) -> Option<&DatosGhostdag> {
        self.gd.get(i as usize)
    }

    /// Id externo del bloque `i`.
    #[must_use]
    pub fn id(&self, i: Idx) -> Option<BlockHash> {
        self.ids.get(i as usize).copied()
    }

    /// Padres del bloque `i`.
    #[must_use]
    pub fn padres_de(&self, i: Idx) -> Option<&[Idx]> {
        self.padres.get(i as usize).map(Vec::as_slice)
    }

    /// `rank(B)` (`C-ORD-01`).
    #[must_use]
    pub fn rank(&self, i: Idx) -> Option<Rank> {
        let pos = i as usize;
        Some(Rank {
            blue_work: self.gd.get(pos)?.blue_work,
            solution_distance: *self.sds.get(pos)?,
            id: *self.ids.get(pos)?,
        })
    }

    /// Color contextual de `cand` visto desde el bloque que lo fusiona `bloque`
    /// (`C-GD-09`). Devuelve `None` si `cand` no es del mergeset de `bloque`.
    #[must_use]
    pub fn color_en(&self, bloque: Idx, cand: Idx) -> Option<Color> {
        let gd = self.gd.get(bloque as usize)?;
        if gd.blues.contains(&cand) {
            return Some(Color::Azul);
        }
        gd.colores
            .iter()
            .find_map(|(c, color)| (*c == cand).then_some(*color))
    }

    /// `C-ORD-02` · ganadora entre copias del mismo billete.
    ///
    /// Entre las candidatas —azules y `rojo_k`; las `rojo_U3` quedan excluidas— gana la **azul**;
    /// en igualdad de color, la de **menor `rank`**. Sin tercer desempate: `rank` ya termina en el
    /// id (`C-ORD-01`).
    #[must_use]
    pub fn seleccionar_copia(&self, candidatas: &[(Idx, Color)]) -> Option<Idx> {
        candidatas
            .iter()
            .filter(|(_, c)| *c != Color::RojoU3)
            .min_by(|(ia, ca), (ib, cb)| {
                let color_a = u8::from(*ca == Color::RojoK);
                let color_b = u8::from(*cb == Color::RojoK);
                color_a
                    .cmp(&color_b)
                    .then_with(|| self.rank(*ia).cmp(&self.rank(*ib)))
            })
            .map(|(i, _)| *i)
    }

    /// Cadena seleccionada desde `tip` hasta el génesis (`C-ORD-03`).
    #[must_use]
    pub fn cadena_seleccionada(&self, tip: Idx) -> Vec<Idx> {
        let mut cadena = Vec::new();
        let mut cur = Some(tip);
        while let Some(c) = cur {
            cadena.push(c);
            cur = self.gd.get(c as usize).and_then(|g| g.sp);
        }
        cadena.reverse();
        cadena
    }

    /// Puntas del DAG visible (bloques sin hijos), ordenadas.
    #[must_use]
    pub fn puntas(&self) -> Vec<Idx> {
        let mut con_hijo = ConjuntoBits::nuevos();
        for ps in &self.padres {
            for p in ps {
                con_hijo.insertar(*p);
            }
        }
        (0..self.ids.len() as Idx)
            .filter(|i| !con_hijo.contiene(*i))
            .collect()
    }

    /// Punta virtual: el `sp` de C-GD-03 sobre las puntas (`C-GD-03`).
    #[must_use]
    pub fn punta_virtual(&self) -> Option<Idx> {
        let puntas = self.puntas();
        seleccionar_sp_generico(&puntas, |a, b| self.comparar_sp(a, b))
    }

    /// Orden de aplicación de `C-ORD-03` (R-FIN-8′(4)): por cada bloque `C` de la cadena
    /// seleccionada, `[sp(C)] ++ mergeset(C)` reordenado por `C-GD-05`, azules y `rojo_k`
    /// entrelazados, **saltando los `rojo_U3`**. La selección de `C-ORD-02` no altera este orden.
    #[must_use]
    pub fn orden_aplicacion(&self, tip: Idx) -> Vec<Idx> {
        let cadena = self.cadena_seleccionada(tip);
        let mut orden = Vec::new();
        if let Some(primero) = cadena.first() {
            orden.push(*primero);
        }
        for c in cadena.iter().skip(1) {
            let Some(gd) = self.gd.get(*c as usize) else {
                continue;
            };
            let mut ms: Vec<Idx> = gd
                .blues
                .iter()
                .copied()
                .filter(|x| Some(*x) != gd.sp)
                .collect();
            ms.extend(gd.rojos.iter().copied());
            ms.retain(|x| self.color_en(*c, *x) != Some(Color::RojoU3));
            ms.sort_by(|a, b| self.comparar_merge(*a, *b));
            orden.extend(ms);
            orden.push(*c);
        }
        orden
    }

    /// Añade un bloque. Devuelve su índice o el motivo de rechazo.
    ///
    /// # Errores
    /// [`ConsensusError`] con el motivo (`C-GD-04`, `C-GD-07/U2`, `C-HDR-05`, desbordamiento).
    pub fn anadir(&mut self, bloque: BloqueGhostdag) -> Result<Idx, ConsensusError> {
        let mut padres: Vec<Idx> = Vec::with_capacity(bloque.padres.len());
        for p in &bloque.padres {
            let idx = *self
                .indice
                .get(p)
                .ok_or(ConsensusError::BloqueDesconocido { hash: *p })?;
            padre_push_unico(&mut padres, idx);
        }
        // C-GD-04 / R-FIN-12: tope de padres.
        let tope_padres = usize::from(self.params.max_padres).min(MAX_PADRES);
        if padres.len() > tope_padres {
            return Err(ConsensusError::DemasiadosPadresDag {
                declarados: padres.len() as u64,
                maximo: tope_padres as u64,
            });
        }

        // C-GD-07 / U2: la identidad no puede estar en un padre ni en su pasado estricto.
        if self.params.u2 && bloque.identidad != 0 {
            for p in &padres {
                if self.pasado_contiene_ident(*p, bloque.identidad) {
                    return Err(ConsensusError::BilleteDuplicadoU2 {
                        identidad: bloque.identidad,
                    });
                }
            }
        }

        // Pasado estricto: {p} ∪ anc[p] sobre todos los padres.
        let mut anc = ConjuntoBits::nuevos();
        for p in &padres {
            anc.insertar(*p);
            if let Some(a) = self.anc.get(*p as usize) {
                anc.unir(a);
            }
        }

        let sp = seleccionar_sp_generico(&padres, |a, b| self.comparar_sp(a, b)).ok_or(
            ConsensusError::DemasiadosPadresDag {
                declarados: 0,
                maximo: MAX_PADRES as u64,
            },
        )?;

        let slot_sp = *self
            .slots
            .get(sp as usize)
            .ok_or(ConsensusError::GhostdagIncoherente {
                motivo: "el sp del bloque no tiene slot almacenado",
            })?;
        if slot_sp > bloque.slot {
            return Err(ConsensusError::SlotNoMonotono {
                slot: bloque.slot,
                slot_sp,
            });
        }
        if bloque.slot - slot_sp > self.params.s_max {
            return Err(ConsensusError::SaltoMayorSmax {
                salto: bloque.slot - slot_sp,
            });
        }

        let ms = self.mergeset(sp, &padres);
        if ms.len() as u64 + 1 > u64::from(self.params.mergeset_limite) {
            return Err(ConsensusError::MergesetExcedeLimite {
                tamano: ms.len() as u64 + 1,
                maximo: u64::from(self.params.mergeset_limite),
            });
        }

        let nuevo = self.ids.len() as Idx;
        let dato = match self.algoritmo {
            Algoritmo::Referencia => self.colorear_referencia(sp, &ms, bloque.identidad, nuevo)?,
            Algoritmo::Kernel => self.colorear_kernel(sp, &ms, bloque.identidad, nuevo)?,
        };

        self.indice.insert(bloque.id, nuevo);
        self.ids.push(bloque.id);
        self.padres.push(padres);
        self.slots.push(bloque.slot);
        self.sds.push(bloque.solution_distance);
        self.srs.push(bloque.rango_espacio);
        self.idents.push(bloque.identidad);
        self.anc.push(anc);
        self.gd.push(dato);
        Ok(nuevo)
    }

    fn pasado_contiene_ident(&self, raiz: Idx, identidad: u64) -> bool {
        // El pasado estricto de `raiz` es `anc[raiz]`; se incluye `raiz` mismo para el caso de
        // identidad en el propio padre.
        if self.idents.get(raiz as usize).copied() == Some(identidad) {
            return true;
        }
        self.anc.get(raiz as usize).is_some_and(|a| {
            a.iter()
                .any(|x| self.idents.get(x as usize).copied() == Some(identidad))
        })
    }

    // ── Comparadores ────────────────────────────────────────────────────────

    /// Comparador del kernel para el orden del mergeset (`C-GD-05`).
    fn comparar_merge(&self, a: Idx, b: Idx) -> Ordering {
        match self.params.merge {
            ModoMerge::Terna => {
                let da = self.datos(a);
                let db = self.datos(b);
                let (wa, wb) = (da.map(|d| d.blue_work), db.map(|d| d.blue_work));
                match wa.cmp(&wb) {
                    Ordering::Equal => {}
                    no_igual => return no_igual,
                }
                match self.sds.get(a as usize).cmp(&self.sds.get(b as usize)) {
                    Ordering::Equal => {}
                    no_igual => return no_igual,
                }
                self.ids.get(a as usize).cmp(&self.ids.get(b as usize))
            }
            ModoMerge::Kaspa => {
                let wa = self.datos(a).map(|d| d.blue_work);
                let wb = self.datos(b).map(|d| d.blue_work);
                match wa.cmp(&wb) {
                    Ordering::Equal => {}
                    no_igual => return no_igual,
                }
                self.ids.get(a as usize).cmp(&self.ids.get(b as usize))
            }
        }
    }

    /// Comparador del kernel para la selección del `sp` (`C-GD-03`, regla C).
    fn comparar_sp(&self, a: Idx, b: Idx) -> Ordering {
        match self.params.sp {
            ModoSp::Zerox => {
                // Mayor blue_work; empate → menor sd; empate → menor id. Dirección MIXTA.
                let wa = self.datos(a).map(|d| d.blue_work);
                let wb = self.datos(b).map(|d| d.blue_work);
                match wb.cmp(&wa) {
                    Ordering::Equal => {}
                    no_igual => return no_igual,
                }
                match self.sds.get(a as usize).cmp(&self.sds.get(b as usize)) {
                    Ordering::Equal => {}
                    no_igual => return no_igual,
                }
                self.ids.get(a as usize).cmp(&self.ids.get(b as usize))
            }
            ModoSp::Kaspa => {
                let wa = self.datos(a).map(|d| d.blue_work);
                let wb = self.datos(b).map(|d| d.blue_work);
                match wb.cmp(&wa) {
                    Ordering::Equal => {}
                    no_igual => return no_igual,
                }
                self.ids.get(b as usize).cmp(&self.ids.get(a as usize))
            }
        }
    }

    // ── Grafo ───────────────────────────────────────────────────────────────

    fn es_ancestro(&self, a: Idx, b: Idx) -> bool {
        if a == b {
            return true;
        }
        self.anc.get(b as usize).is_some_and(|anc| anc.contiene(a))
    }

    /// `mergeset(B) = past(B) \\ (past(sp) ∪ {sp})` (`C-GD-04`).
    fn mergeset(&self, sp: Idx, padres: &[Idx]) -> Vec<Idx> {
        let mut ms = ConjuntoBits::nuevos();
        let mut cola: VecDeque<Idx> = VecDeque::new();
        for p in padres {
            if *p == sp || self.es_ancestro(*p, sp) || ms.contiene(*p) {
                continue;
            }
            ms.insertar(*p);
            cola.push_back(*p);
        }
        while let Some(cur) = cola.pop_front() {
            if let Some(ps) = self.padres.get(cur as usize) {
                for p in ps {
                    if self.es_ancestro(*p, sp) || ms.contiene(*p) {
                        continue;
                    }
                    ms.insertar(*p);
                    cola.push_back(*p);
                }
            }
        }
        ms.iter().collect()
    }

    /// Orden de coloreado del mergeset: `C-GD-05`.
    fn ordenar_mergeset(&self, cand: &mut [Idx]) {
        cand.sort_by(|a, b| self.comparar_merge(*a, *b));
    }

    /// `tam_anticono_azul` del kernel: sube por la cadena del `sp` (protocol.rs:230-244).
    fn tam_anticono_azul(
        &self,
        bas_actual: &[u32],
        sp_actual: Idx,
        bloque: Idx,
    ) -> Result<u32, ConsensusError> {
        let v = bas_actual
            .get(bloque as usize)
            .copied()
            .unwrap_or(SIN_ENTRADA);
        if v != SIN_ENTRADA {
            return Ok(v);
        }
        let mut cur = Some(sp_actual);
        while let Some(c) = cur {
            if let Some(EstadoInterno::Kernel { bas }) = self.gd.get(c as usize).map(|g| &g.estado)
            {
                let v = leer_tabla(bas, bloque, SIN_ENTRADA);
                if v != SIN_ENTRADA {
                    return Ok(v);
                }
            }
            cur = self.gd.get(c as usize).and_then(|g| g.sp);
        }
        Err(ConsensusError::GhostdagIncoherente {
            motivo: "tam_anticono_azul no encontró el azul en la cadena del sp",
        })
    }

    /// `check_blue_candidate_with_chain_block` (protocol.rs:168-225).
    ///
    /// La firma tiene más argumentos que el umbral de clippy porque reproduce 1:1 el contrato
    /// de `protocol.rs`; se documenta la excepción en vez de inventar un contexto artificial.
    #[expect(
        clippy::too_many_arguments,
        reason = "réplica directa de protocol.rs:168-225; cada argumento es una pieza del contrato"
    )]
    fn revisar_con_bloque_cadena(
        &self,
        bas_actual: &[u32],
        sp_actual: Idx,
        blues_actuales: &[Idx],
        cadena: Option<Idx>,
        cand: Idx,
        cand_sizes: &mut Vec<(Idx, u32)>,
        cand_size_inicial: u32,
        k: u32,
    ) -> Result<(Revision, u32), ConsensusError> {
        if cadena.is_some_and(|c| self.es_ancestro(c, cand)) {
            return Ok((Revision::Azul, cand_size_inicial));
        }
        let peer_blues: Vec<Idx> = match cadena {
            None => blues_actuales.to_vec(),
            Some(c) => self
                .gd
                .get(c as usize)
                .map(|g| g.blues.clone())
                .unwrap_or_default(),
        };
        let mut cand_size = cand_size_inicial;
        for peer in peer_blues {
            if self.es_ancestro(peer, cand) {
                continue;
            }
            let pbas = self.tam_anticono_azul(bas_actual, sp_actual, peer)?;
            cand_sizes.push((peer, pbas));
            cand_size += 1;
            if cand_size > k || pbas == k {
                return Ok((Revision::Rojo, cand_size));
            }
        }
        Ok((Revision::Pendiente, cand_size))
    }

    /// `check_blue_candidate` (protocol.rs:247-283). Devuelve `(azul, cand_size, cand_sizes)`.
    fn check_azul(
        &self,
        sp_actual: Idx,
        bas_actual: &[u32],
        blues_actuales: &[Idx],
        cand: Idx,
        k: u32,
    ) -> Result<CheckAzul, ConsensusError> {
        if blues_actuales.len() as u32 == k + 1 {
            return Ok((false, 0, Vec::new()));
        }
        let mut cand_sizes: Vec<(Idx, u32)> = Vec::new();
        let mut cand_size = 0u32;
        let mut cadena: Option<Idx> = None;
        loop {
            let (revision, size) = self.revisar_con_bloque_cadena(
                bas_actual,
                sp_actual,
                blues_actuales,
                cadena,
                cand,
                &mut cand_sizes,
                cand_size,
                k,
            )?;
            cand_size = size;
            match revision {
                Revision::Azul => return Ok((true, cand_size, cand_sizes)),
                Revision::Rojo => return Ok((false, cand_size, cand_sizes)),
                Revision::Pendiente => {
                    // Continuar el walk por la cadena del `sp`.
                    let siguiente = match cadena {
                        None => Some(sp_actual),
                        Some(c) => self.gd.get(c as usize).and_then(|g| g.sp),
                    };
                    cadena = Some(siguiente.ok_or(ConsensusError::GhostdagIncoherente {
                        motivo: "génesis alcanzado sin resolver el candidato",
                    })?);
                }
            }
        }
    }

    fn colorear_kernel(
        &self,
        sp: Idx,
        ms: &[Idx],
        identidad: u64,
        nuevo: Idx,
    ) -> Result<DatosGhostdag, ConsensusError> {
        let mut ordenado = ms.to_vec();
        self.ordenar_mergeset(&mut ordenado);

        let sp_datos = self
            .gd
            .get(sp as usize)
            .ok_or(ConsensusError::GhostdagIncoherente {
                motivo: "índice interno del almacén fuera de rango",
            })?;
        let sp_bi: HashSet<u64> = sp_datos.blue_idents.iter().copied().collect();

        let mut bas: Vec<u32> = vec![SIN_ENTRADA; nuevo as usize + 1];
        fijar_tabla(&mut bas, sp, 0);
        let mut blues: Vec<Idx> = vec![sp];
        let mut rojos: Vec<Idx> = Vec::new();
        let mut colores: Vec<(Idx, Color)> = Vec::new();
        let mut vistos: HashSet<u64> = HashSet::new();

        for cand in &ordenado {
            let cid = self.idents.get(*cand as usize).copied().unwrap_or(0);
            let filtrado = self.params.u3_dinamica
                && cid != 0
                && (sp_bi.contains(&cid) || vistos.contains(&cid));
            if filtrado {
                rojos.push(*cand);
                colores.push((*cand, Color::RojoU3));
                continue;
            }
            let (azul, tam, cand_sizes) =
                self.check_azul(sp, &bas, &blues, *cand, self.params.k)?;
            if azul {
                blues.push(*cand);
                fijar_tabla(&mut bas, *cand, tam);
                for (h, s) in cand_sizes {
                    fijar_tabla(&mut bas, h, s + 1);
                }
                if cid != 0 {
                    vistos.insert(cid);
                }
            } else {
                rojos.push(*cand);
                colores.push((*cand, Color::RojoK));
            }
        }

        let acumulado = self.acumular(sp, identidad, &blues)?;
        Ok(DatosGhostdag {
            sp: Some(sp),
            orden_mergeset: ordenado,
            blues,
            rojos,
            colores,
            blue_idents: acumulado.2,
            blue_score: acumulado.1,
            blue_work: acumulado.0,
            estado: EstadoInterno::Kernel { bas },
        })
    }

    fn colorear_referencia(
        &self,
        sp: Idx,
        ms: &[Idx],
        identidad: u64,
        nuevo: Idx,
    ) -> Result<DatosGhostdag, ConsensusError> {
        // Claves INDEPENDIENTES del kernel (Corrección 1 de GDR-v0.2): la referencia ordena por
        // una tupla (bw, sd, id) calculada aparte, no con `comparar_merge`.
        let mut ordenado = ms.to_vec();
        ordenado.sort_by(|a, b| {
            let ka = self.clave_referencia(*a, self.params.merge);
            let kb = self.clave_referencia(*b, self.params.merge);
            ka.cmp(&kb)
        });

        let sp_datos = self
            .gd
            .get(sp as usize)
            .ok_or(ConsensusError::GhostdagIncoherente {
                motivo: "índice interno del almacén fuera de rango",
            })?;
        let (mut contexto, mut tam): (ConjuntoBits, Vec<u32>) = match &sp_datos.estado {
            EstadoInterno::Referencia { blueset, tam } => (blueset.clone(), tam.clone()),
            EstadoInterno::Kernel { .. } => {
                return Err(ConsensusError::GhostdagIncoherente {
                    motivo: "la referencia encontró un estado de kernel",
                });
            }
        };
        // `tam` cubre hasta el bloque nuevo; los índices intermedios no vistos valen 0.
        tam.resize(nuevo as usize + 1, 0);
        let sp_bi: HashSet<u64> = sp_datos.blue_idents.iter().copied().collect();

        let mut blues: Vec<Idx> = vec![sp];
        let mut rojos: Vec<Idx> = Vec::new();
        let mut colores: Vec<(Idx, Color)> = Vec::new();
        let mut vistos: HashSet<u64> = HashSet::new();

        for cand in &ordenado {
            let cid = self.idents.get(*cand as usize).copied().unwrap_or(0);
            let filtrado = self.params.u3_dinamica
                && cid != 0
                && (sp_bi.contains(&cid) || vistos.contains(&cid));
            if filtrado {
                rojos.push(*cand);
                colores.push((*cand, Color::RojoU3));
                continue;
            }
            // Anticono directo dentro del contexto (la DEFINICIÓN, no el algoritmo incremental).
            let mut anticono: Vec<Idx> = Vec::new();
            for b in contexto.iter() {
                if !self.es_ancestro(b, *cand) && !self.es_ancestro(*cand, b) {
                    anticono.push(b);
                }
            }
            let cabe = anticono.len() as u32 <= self.params.k
                && anticono
                    .iter()
                    .all(|b| leer_tabla(&tam, *b, 0) < self.params.k);
            if cabe {
                for b in &anticono {
                    let actualizado = leer_tabla(&tam, *b, 0).saturating_add(1);
                    fijar_tabla(&mut tam, *b, actualizado);
                }
                fijar_tabla(&mut tam, *cand, anticono.len() as u32);
                contexto.insertar(*cand);
                blues.push(*cand);
                if cid != 0 {
                    vistos.insert(cid);
                }
            } else {
                rojos.push(*cand);
                colores.push((*cand, Color::RojoK));
            }
        }

        let acumulado = self.acumular(sp, identidad, &blues)?;

        // Blue set final de past(B) ∪ {B}: el contexto más B.
        let mut blueset_final = contexto;
        blueset_final.insertar(nuevo);
        fijar_tabla(&mut tam, nuevo, 0);

        let mut blue_idents = acumulado.2;
        blue_idents.sort_unstable();
        Ok(DatosGhostdag {
            sp: Some(sp),
            orden_mergeset: ordenado,
            blues,
            rojos,
            colores,
            blue_idents,
            blue_score: acumulado.1,
            blue_work: acumulado.0,
            estado: EstadoInterno::Referencia {
                blueset: blueset_final,
                tam,
            },
        })
    }

    /// Clave independiente de la referencia para el orden del mergeset.
    fn clave_referencia(&self, i: Idx, modo: ModoMerge) -> (U256, u64, BlockHash) {
        let bw = self
            .gd
            .get(i as usize)
            .map_or(U256::zero(), |g| g.blue_work);
        let sd = self.sds.get(i as usize).copied().unwrap_or(0);
        let id = self
            .ids
            .get(i as usize)
            .copied()
            .unwrap_or_else(|| hash_desde_id(&[0; 32]));
        match modo {
            ModoMerge::Terna => (bw, sd, id),
            ModoMerge::Kaspa => (bw, 0, id),
        }
    }

    /// `blue_score`, `blue_work` y `blue_idents` acumulados (`C-GD-08`).
    fn acumular(
        &self,
        sp: Idx,
        identidad: u64,
        blues: &[Idx],
    ) -> Result<(U256, u64, Vec<u64>), ConsensusError> {
        let sp_datos = self
            .gd
            .get(sp as usize)
            .ok_or(ConsensusError::GhostdagIncoherente {
                motivo: "índice interno del almacén fuera de rango",
            })?;
        let mut bw = sp_datos.blue_work;
        for x in blues {
            let sr = self.srs.get(*x as usize).copied().unwrap_or(0);
            bw = sumar_blue_work(bw, peso(sr))?;
        }
        let score = sp_datos
            .blue_score
            .checked_add(blues.len() as u64)
            .ok_or(ConsensusError::BlueWorkDesbordado)?;
        let mut idents: Vec<u64> = sp_datos.blue_idents.clone();
        for x in blues {
            let cid = self.idents.get(*x as usize).copied().unwrap_or(0);
            if cid != 0 {
                idents.push(cid);
            }
        }
        if identidad != 0 {
            idents.push(identidad);
        }
        Ok((bw, score, idents))
    }
}

/// Salida de `check_azul`: azul, tamaño de anticono del candidato y tamaños por azul.
type CheckAzul = (bool, u32, Vec<(Idx, u32)>);

fn leer_tabla(tabla: &[u32], i: Idx, por_defecto: u32) -> u32 {
    tabla.get(i as usize).copied().unwrap_or(por_defecto)
}

fn fijar_tabla(tabla: &mut [u32], i: Idx, valor: u32) {
    if let Some(slot) = tabla.get_mut(i as usize) {
        *slot = valor;
    }
}

fn padre_push_unico(padres: &mut Vec<Idx>, idx: Idx) {
    if !padres.contains(&idx) {
        padres.push(idx);
    }
    padres.sort_unstable();
}

/// Selecciona el mejor de `candidatos` según `comparador` (que devuelve `Ordering::Less` si el
/// primer argumento es **mejor**).
fn seleccionar_sp_generico<F>(candidatos: &[Idx], mut comparador: F) -> Option<Idx>
where
    F: FnMut(Idx, Idx) -> Ordering,
{
    let mut mejor: Option<Idx> = None;
    for c in candidatos {
        match mejor {
            None => mejor = Some(*c),
            Some(m) => {
                if comparador(*c, m) == Ordering::Less {
                    mejor = Some(*c);
                }
            }
        }
    }
    mejor
}

// ─────────────────────────────────────────────────────────────────────────────
// Implementación real de `ContextoDag` (H-04, H-06), respaldada por el almacén.
// ─────────────────────────────────────────────────────────────────────────────

impl ContextoDag for AlmacenGhostdag {
    fn es_bloque_validado(&self, h: &BlockHash) -> bool {
        self.indice.contains_key(h)
    }

    fn esta_en_el_pasado_de(
        &self,
        antepasado: &BlockHash,
        descendiente: &BlockHash,
    ) -> Result<bool, ConsensusError> {
        let a = *self
            .indice
            .get(antepasado)
            .ok_or(ConsensusError::BloqueDesconocido { hash: *antepasado })?;
        let b = *self
            .indice
            .get(descendiente)
            .ok_or(ConsensusError::BloqueDesconocido {
                hash: *descendiente,
            })?;
        // Pasado ESTRICTO: `a == b` no es ancestro en el sentido de "estar en el pasado de".
        Ok(a != b && self.es_ancestro(a, b))
    }

    fn padre_seleccionado(&self, padres: &PadresDag) -> Result<BlockHash, ConsensusError> {
        // Se ignoran las posiciones declaradas: el `sp` se recalcula con C-GD-03.
        let mut indices: Vec<Idx> = Vec::with_capacity(usize::from(padres.count()));
        if !padres.es_genesis() {
            let s = *self.indice.get(&padres.seleccionado()).ok_or(
                ConsensusError::PadreNoValidado {
                    padre: padres.seleccionado(),
                },
            )?;
            indices.push(s);
        }
        for p in padres.extras() {
            let idx = *self
                .indice
                .get(p)
                .ok_or(ConsensusError::PadreNoValidado { padre: *p })?;
            indices.push(idx);
        }
        let sp = seleccionar_sp_generico(&indices, |a, b| self.comparar_sp(a, b)).ok_or(
            ConsensusError::PadreNoValidado {
                padre: padres.seleccionado(),
            },
        )?;
        self.ids
            .get(sp as usize)
            .copied()
            .ok_or(ConsensusError::PadreNoValidado {
                padre: padres.seleccionado(),
            })
    }

    fn es_genesis(&self, h: &BlockHash) -> bool {
        *h == self.genesis
    }
}
