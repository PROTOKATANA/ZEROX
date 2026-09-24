//! Vista **estructural** de la clausura ancestral de los padres de un candidato.
//!
//! # Qué es y qué no es
//!
//! [`VistaPasadoEstructural`] recorre transitivamente **todos** los padres de un candidato —el
//! seleccionado y los adicionales de [`PadresDag`]— leyendo registros de una fuente inyectada,
//! deduplica por `block_hash` y devuelve un conjunto inmutable y determinista. Es la materia
//! prima estructural que `C-POT-06` exige para el `past(B)` y sobre la que `C-FLU-14` comprobará
//! la consistencia de flujo. La cota de slot sobre **todos** los padres es `C-HDR-05`; el
//! mergeset `C-GD-04` se apoya en este mismo pasado, pero **no** se calcula aquí.
//!
//! **No acredita validez.** No verifica la solución PoAS, no ejecuta el orden de `C-POT-08`, no
//! comprueba `C-FLU-14`, no colorea GHOSTDAG y no admite el candidato. Sus registros llevan solo
//! `hash`, `PadresDag` y `slot`: no existe una marca `validado`, ni una función pública
//! `insertar_validado` ni `admitir`. Estar en la vista **no** significa bloque válido ni admitido.
//!
//! # La fuente y su contrato de integración futura
//!
//! Los datos los aporta una [`FuenteRegistrosDag`] inyectada. Su contrato de producción es
//! estricto: **MUST** leer exclusivamente un índice separado de bloques PoST **plenamente
//! admitidos** —los que ya superaron el orden completo de `C-POT-08` y la validez de
//! `C-FLU-14`—. Ese índice es hoy un **destino vacío en la ruta activa**: solo los tests lo llenan
//! con bytes no verificados, así que este adaptador todavía no lee evidencia de producción.
//! **MUST NOT** leer la cola reemplazable `AlmacenCandidatosDag`, ni entradas
//! sintéticas de `AlmacenGhostdag::anadir_sintetico`, ni campos del propio candidato. Una
//! implementación de test cumple la firma pero **no acredita** procedencia: sirve para probar esta
//! vista, no para admitir un bloque.
//!
//! # Orden, determinismo y recursos
//!
//! El recorrido es iterativo —sin recursión de pila no acotada—, usa aritmética comprobada y
//! enumera a los padres en orden ascendente de `BlockHash`; el resultado se devuelve ordenado
//! igual. Ese es un orden de **datos**, no el orden de mergeset ni un orden de consenso. La
//! construcción recibe un [`PresupuestoVista`] **explícito** elegido por el llamante como límite
//! de recursos local —no como valor de consenso—. Agotarlo devuelve
//! [`ErrorVistaCausal::PresupuestoAgotado`], distinto de la ausencia de un registro, y **nunca**
//! una vista truncada.
//!
//! # El candidato no puede estar en su propio pasado
//!
//! [`VistaPasadoEstructural::desde_padres`] recibe el `hash_candidato`. **Antes de leer o insertar**
//! cualquier hash comprueba si coincide con el candidato y, si es así, devuelve
//! [`ErrorVistaCausal::CandidatoEnSuPasado`] —incoherencia estructural, no agotamiento—. Esa
//! comprobación **precede** al presupuesto: hallar el propio hash nunca se oculta como
//! [`ErrorVistaCausal::PresupuestoAgotado`]. Un candidato que se declara padre a sí mismo, o cuyo
//! pasado declarado vuelve a él, no produce vista parcial ni vista alguna.
//!
//! # Coherencia, inmutabilidad y recursos
//!
//! La vista es inmutable **después** de construirla, pero `desde_padres` **no** puede garantizar
//! una lectura coherente si la fuente cambia durante el recorrido: para producción
//! [`FuenteRegistrosDag`] debe ser una **instantánea estable** con registros inmutables por `hash`.
//! Un `&self` con mutabilidad interior **no basta**. Esta preparación no instala todavía una fuente
//! de producción ni promete coherencia concurrente. El [`PresupuestoVista`] es una **cota parcial
//! de recursos** —cuántas lecturas y cuánta memoria— y no un valor de consenso: el futuro llamante
//! debe fijar un límite local y ejecutar la construcción **fuera del bucle de red**.
//!
//! # Lo que este módulo deliberadamente no hace
//!
//! No implementa `InstantaneaPot` ni `ContextoDag` sobre esta vista: sus respuestas exigen flujo,
//! inyecciones, salidas PoT auditadas y GHOSTDAG procedente de admisión real, que todavía no
//! existen. Tampoco se conecta al nodo ni promociona candidatos.

use std::collections::BTreeMap;

use zx_core::{BlockHash, PadresDag};
use zx_storage::{AlmacenAdmitidosDag, StorageError};

/// Registro estructural mínimo de un bloque: `hash`, padres y `slot`.
///
/// No lleva cuerpo, sello, rango, `pot_output` ni ninguna marca de validez. Es lo justo para
/// recorrer la clausura ancestral.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct RegistroEstructural {
    hash: BlockHash,
    padres: PadresDag,
    slot: u64,
}

impl RegistroEstructural {
    /// Construye un registro estructural.
    ///
    /// **No** acredita que el bloque sea válido, verificado ni admitido.
    #[must_use]
    pub const fn nuevo(hash: BlockHash, padres: PadresDag, slot: u64) -> Self {
        Self { hash, padres, slot }
    }

    /// El `block_hash` del registro.
    #[must_use]
    pub const fn hash(&self) -> BlockHash {
        self.hash
    }

    /// Los padres declarados.
    #[must_use]
    pub const fn padres(&self) -> PadresDag {
        self.padres
    }

    /// El índice de PoT (`slot`). Se conserva como dato; **no** se usa para indexar ni deduplicar.
    #[must_use]
    pub const fn slot(&self) -> u64 {
        self.slot
    }
}

/// Fuente inyectada de registros estructurales, indexada por `block_hash`.
///
/// El contrato de producción está en la cabecera del módulo: en el futuro **solo** un índice
/// separado de bloques PoST plenamente admitidos. `Ok(None)` significa que la clave no está en la
/// fuente —contexto incompleto—, **nunca** invalidez del candidato. Un `Ok(Some(r))` con
/// `r.hash() != *hash` es incoherencia de la fuente y la vista lo rechaza sin construir nada.
///
/// Para producción debe ser una **instantánea estable**: registros inmutables por `hash` durante
/// todo el recorrido, de modo que dos lecturas de la misma clave no puedan divergir. Un `&self`
/// con mutabilidad interior **no basta**. Esta preparación no instala esa fuente ni promete
/// coherencia concurrente; el contrato solo la exige.
pub trait FuenteRegistrosDag {
    /// Error propio de la fuente (E/S, índice corrupto…). La vista lo propaga sin interpretarlo.
    type Error;

    /// Lee el registro estructural de `hash`.
    ///
    /// # Errores
    /// El error propio de la fuente. Devolver `None` no es un error de la fuente: es contexto
    /// incompleto.
    fn leer(&self, hash: &BlockHash) -> Result<Option<RegistroEstructural>, Self::Error>;
}

/// Adaptador de [`FuenteRegistrosDag`] sobre el índice de bloques DAG plenamente admitidos.
///
/// Lee **exclusivamente** [`AlmacenAdmitidosDag::bloque_admitido`]. No consulta la cola
/// reemplazable de candidatos, ni entradas sintéticas, ni campos del candidato bajo análisis.
///
/// # Qué acredita y qué no
///
/// El adaptador no añade confianza: confía en que el índice contiene bloques ya admitidos por la
/// ruta completa, que todavía no existe. Construye el [`RegistroEstructural`] con el `block_hash`
/// canónico, los `PadresDag` y el `slot` de la cabecera; **no** deriva `InstantaneaPot` ni presenta
/// `pot_output` o `sol.chunk` como salidas verificadas. Hoy el índice está **vacío en la ruta
/// activa**, de modo que en producción el adaptador devuelve `Ok(None)` para toda clave; solo los
/// tests lo pueblan con fakes o fixtures que **no** acreditan admisión.
///
/// Un `Ok(None)` del índice se traduce en `Ok(None)` de la fuente: contexto incompleto, **nunca**
/// invalidez del candidato. Un error del índice —corrupción incluida— se propaga como
/// [`ErrorVistaCausal::Fuente`] sin convertirse en ausencia.
///
/// # Coherencia de instantánea
///
/// Lleva `&self` y **no** promete por sí mismo una instantánea estable: si el índice cambiara
/// durante el recorrido, dos lecturas de la misma clave podrían divergir. Para producción la
/// fuente **MUST** ser inmutable durante todo el recorrido. Hoy, al estar el índice **vacío en la
/// ruta activa**, no hay nada que pueda cambiar durante el recorrido, pero eso **no** es una
/// garantía del almacenamiento ni del adaptador: la publicación del futuro escritor tendrá que
/// serializarse con el recorrido o exponer una vista congelada, y esa garantía no se implementa en
/// este incremento.
pub struct FuenteIndiceAdmitidos<'a, A> {
    indice: &'a A,
}

impl<'a, A> FuenteIndiceAdmitidos<'a, A> {
    /// Envuelve una referencia al índice de admitidos.
    ///
    /// No acredita que el índice contenga bloques válidos: solo expone su lectura.
    #[must_use]
    pub const fn nueva(indice: &'a A) -> Self {
        Self { indice }
    }
}

impl<A: AlmacenAdmitidosDag> FuenteRegistrosDag for FuenteIndiceAdmitidos<'_, A> {
    type Error = StorageError;

    fn leer(&self, hash: &BlockHash) -> Result<Option<RegistroEstructural>, StorageError> {
        let Some(bloque) = self.indice.bloque_admitido(hash)? else {
            // Ausencia de contexto, no invalidez del candidato.
            return Ok(None);
        };
        Ok(Some(RegistroEstructural::nuevo(
            bloque.cabecera.block_hash(),
            bloque.cabecera.padres,
            bloque.cabecera.slot,
        )))
    }
}

/// Presupuesto **local** de registros a materializar.
///
/// Es una decisión de recursos del llamante —cuántas lecturas y cuánta memoria admite— y **no** un
/// valor de consenso. La vista no lo usa para declarar nada sobre el candidato: agotarlo es un
/// error de quien preguntó, no una invalidez. Es una **cota parcial**: el futuro llamante debe
/// fijar un límite local y ejecutar la construcción fuera del bucle de red.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct PresupuestoVista {
    max_registros: u64,
}

impl PresupuestoVista {
    /// Crea un presupuesto de `max_registros` registros.
    #[must_use]
    pub const fn nuevo(max_registros: u64) -> Self {
        Self { max_registros }
    }

    /// El máximo de registros que se materializarán.
    #[must_use]
    pub const fn max_registros(self) -> u64 {
        self.max_registros
    }
}

/// Error tipado de la construcción de la vista estructural.
///
/// Distingue **contexto incompleto** (falta un registro; no es invalidez) de **incoherencia de la
/// fuente** (un ciclo o un registro devuelto bajo otra clave) y de **presupuesto agotado** (límite
/// local de recursos). Una vista parcial nunca se devuelve.
#[derive(Clone, PartialEq, Eq, Debug)]
pub enum ErrorVistaCausal<E> {
    /// Falta el registro `faltante`, referenciado por `referido_por`.
    ///
    /// Es contexto incompleto, **nunca** invalidez del candidato.
    ContextoIncompleto {
        /// Hash que la fuente no ofrece.
        faltante: BlockHash,
        /// Bloque cuyos padres lo referencian; `None` si es un padre directo del candidato.
        referido_por: Option<BlockHash>,
    },
    /// La fuente devolvió un registro bajo otra clave.
    RegistroIncoherente {
        /// La clave que se pidió.
        pedido: BlockHash,
        /// El hash que traía el registro devuelto.
        devuelto: BlockHash,
    },
    /// El `hash_candidato` aparece en su propio pasado declarado: incoherencia estructural.
    ///
    /// El candidato se declara padre a sí mismo, o un ancestro suyo lo referencia de vuelta. No es
    /// agotamiento ni ausencia: la vista se rechaza sin construir nada.
    CandidatoEnSuPasado {
        /// El `block_hash` del candidato, hallado también como ancestro.
        hash: BlockHash,
    },
    /// El grafo de padres contiene un ciclo.
    CicloDetectado {
        /// Un bloque que alcanza su propio pasado.
        bloque: BlockHash,
    },
    /// Se agotó el presupuesto local de registros. No se devuelve vista truncada.
    PresupuestoAgotado {
        /// El presupuesto que fijó el llamante.
        presupuesto: u64,
    },
    /// La fuente falló.
    Fuente(E),
}

impl<E: core::fmt::Display> core::fmt::Display for ErrorVistaCausal<E> {
    fn fmt(&self, f: &mut core::fmt::Formatter<'_>) -> core::fmt::Result {
        match self {
            Self::ContextoIncompleto {
                faltante,
                referido_por,
            } => {
                write!(f, "contexto incompleto: falta {faltante}")?;
                if let Some(referente) = referido_por {
                    write!(f, " referenciado por {referente}")?;
                }
                Ok(())
            }
            Self::RegistroIncoherente { pedido, devuelto } => {
                write!(
                    f,
                    "registro incoherente: se pidió {pedido} y llegó {devuelto}"
                )
            }
            Self::CandidatoEnSuPasado { hash } => {
                write!(
                    f,
                    "el candidato {hash} aparece en su propio pasado declarado"
                )
            }
            Self::CicloDetectado { bloque } => {
                write!(f, "ciclo de padres detectado en {bloque}")
            }
            Self::PresupuestoAgotado { presupuesto } => {
                write!(f, "presupuesto agotado: {presupuesto} registros")
            }
            Self::Fuente(error) => write!(f, "error de la fuente: {error}"),
        }
    }
}

/// Estado de un hash en el recorrido iterativo, para detectar ciclos sin recursión.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
enum Estado {
    /// Está en la pila actual: si se vuelve a él, hay ciclo.
    EnCurso,
    /// Ya se expandió por completo.
    Cerrado,
}

/// Tarea de la pila iterativa: entrar en un hash o cerrarlo al terminar sus padres.
#[derive(Clone, Copy, Debug)]
enum Tarea {
    Entrar {
        hash: BlockHash,
        referido_por: Option<BlockHash>,
    },
    Salir {
        hash: BlockHash,
    },
}

/// Vista estructural inmutable del pasado de los padres de un candidato.
///
/// Contiene exactamente la unión de los padres y sus pasados, sin el candidato, deduplicada por
/// `block_hash` y ordenada de forma ascendente por `BlockHash`. El orden es de **datos** —para que
/// dos recorridos den el mismo vector—, no el orden de mergeset ni un orden de consenso.
///
/// Es inmutable **después** de construirla. `desde_padres` no garantiza una lectura coherente si la
/// fuente cambia durante el recorrido: para producción la fuente debe ser una instantánea estable
/// con registros inmutables por `hash`.
#[derive(Clone, PartialEq, Eq, Debug)]
pub struct VistaPasadoEstructural {
    ancestros: Vec<RegistroEstructural>,
}

impl VistaPasadoEstructural {
    /// Construye la vista recorriendo transitivamente **todos** los padres de `padres`.
    ///
    /// Se parte del padre seleccionado y de cada adicional; se sigue el pasado de cada uno hasta
    /// agotarlo, deduplicando por `block_hash`. El candidato `hash_candidato` no se incluye y
    /// **nunca** puede aparecer: antes de leer o insertar cualquier hash se comprueba si coincide
    /// con él y, si es así, se devuelve [`ErrorVistaCausal::CandidatoEnSuPasado`], sin vista
    /// parcial. Esa comprobación **precede** al presupuesto, de modo que hallar el propio hash no
    /// se disfraza de agotamiento. Un diamante comparte ancestro una sola vez.
    ///
    /// La fuente se consulta por clave y el hash devuelto **debe** coincidir con ella. Un registro
    /// ausente es contexto incompleto; un ciclo, incoherencia de la fuente. El presupuesto se
    /// comprueba antes de cada lectura y, al agotarse, devuelve
    /// [`ErrorVistaCausal::PresupuestoAgotado`] sin vista parcial.
    ///
    /// No se usa la punta local, la cadena seleccionada, el orden de llegada, `height`, GHOSTDAG
    /// ni la cola de candidatos.
    ///
    /// # Errores
    /// [`ErrorVistaCausal::ContextoIncompleto`], [`ErrorVistaCausal::RegistroIncoherente`],
    /// [`ErrorVistaCausal::CandidatoEnSuPasado`], [`ErrorVistaCausal::CicloDetectado`],
    /// [`ErrorVistaCausal::PresupuestoAgotado`] o [`ErrorVistaCausal::Fuente`].
    pub fn desde_padres<F>(
        fuente: &F,
        padres: &PadresDag,
        hash_candidato: BlockHash,
        presupuesto: PresupuestoVista,
    ) -> Result<Self, ErrorVistaCausal<F::Error>>
    where
        F: FuenteRegistrosDag,
    {
        let mut estado: BTreeMap<BlockHash, Estado> = BTreeMap::new();
        let mut registros: BTreeMap<BlockHash, RegistroEstructural> = BTreeMap::new();
        let mut materializados: u64 = 0;

        let mut raices: Vec<BlockHash> = Vec::with_capacity(usize::from(padres.count()));
        if !padres.es_genesis() {
            raices.push(padres.seleccionado());
            raices.extend_from_slice(padres.extras());
            raices.sort_unstable();
        }

        let mut pila: Vec<Tarea> = Vec::new();
        for raiz in raices {
            if estado.get(&raiz) == Some(&Estado::Cerrado) {
                continue;
            }
            pila.push(Tarea::Entrar {
                hash: raiz,
                referido_por: None,
            });
            while let Some(tarea) = pila.pop() {
                match tarea {
                    Tarea::Entrar { hash, referido_por } => {
                        match estado.get(&hash) {
                            Some(Estado::Cerrado) => continue,
                            Some(Estado::EnCurso) => {
                                return Err(ErrorVistaCausal::CicloDetectado { bloque: hash });
                            }
                            None => {}
                        }
                        // El candidato no puede estar en su propio pasado, y esta comprobación
                        // precede al presupuesto: hallar el propio hash no se oculta como
                        // agotamiento ni se devuelve como vista parcial.
                        if hash == hash_candidato {
                            return Err(ErrorVistaCausal::CandidatoEnSuPasado { hash });
                        }
                        if materializados >= presupuesto.max_registros() {
                            return Err(ErrorVistaCausal::PresupuestoAgotado {
                                presupuesto: presupuesto.max_registros(),
                            });
                        }
                        let registro = match fuente.leer(&hash) {
                            Ok(Some(registro)) => registro,
                            Ok(None) => {
                                return Err(ErrorVistaCausal::ContextoIncompleto {
                                    faltante: hash,
                                    referido_por,
                                });
                            }
                            Err(error) => return Err(ErrorVistaCausal::Fuente(error)),
                        };
                        if registro.hash() != hash {
                            return Err(ErrorVistaCausal::RegistroIncoherente {
                                pedido: hash,
                                devuelto: registro.hash(),
                            });
                        }
                        materializados = materializados.checked_add(1).ok_or(
                            ErrorVistaCausal::PresupuestoAgotado {
                                presupuesto: presupuesto.max_registros(),
                            },
                        )?;
                        estado.insert(hash, Estado::EnCurso);
                        registros.insert(hash, registro);

                        let mut ascendientes: Vec<BlockHash> =
                            Vec::with_capacity(usize::from(registro.padres().count()));
                        if !registro.padres().es_genesis() {
                            ascendientes.push(registro.padres().seleccionado());
                            ascendientes.extend_from_slice(registro.padres().extras());
                            ascendientes.sort_unstable();
                        }
                        // La pila es LIFO: se apilan en orden descendente para procesarlos
                        // ascendentes y que el recorrido sea determinista.
                        pila.push(Tarea::Salir { hash });
                        for ascendiente in ascendientes.into_iter().rev() {
                            pila.push(Tarea::Entrar {
                                hash: ascendiente,
                                referido_por: Some(hash),
                            });
                        }
                    }
                    Tarea::Salir { hash } => {
                        estado.insert(hash, Estado::Cerrado);
                    }
                }
            }
        }

        Ok(Self {
            ancestros: registros.into_values().collect(),
        })
    }

    /// Los registros, en orden ascendente de `BlockHash` (orden de datos, no de consenso).
    #[must_use]
    pub fn ancestros(&self) -> &[RegistroEstructural] {
        &self.ancestros
    }

    /// ¿Está `hash` en la clausura ancestral?
    #[must_use]
    pub fn contiene(&self, hash: &BlockHash) -> bool {
        self.ancestros
            .binary_search_by(|registro| registro.hash().cmp(hash))
            .is_ok()
    }

    /// El registro de `hash`, si está en la clausura.
    #[must_use]
    pub fn get(&self, hash: &BlockHash) -> Option<&RegistroEstructural> {
        self.ancestros
            .binary_search_by(|registro| registro.hash().cmp(hash))
            .ok()
            .and_then(|indice| self.ancestros.get(indice))
    }

    /// Cuántos ancestros contiene la clausura.
    #[must_use]
    pub fn len(&self) -> usize {
        self.ancestros.len()
    }

    /// ¿La clausura está vacía? Cierto para el génesis o una cabecera sin padres.
    #[must_use]
    pub fn is_empty(&self) -> bool {
        self.ancestros.is_empty()
    }
}

#[cfg(test)]
#[expect(clippy::expect_used, reason = "los tests fallan con panic por diseño")]
mod tests {
    use std::collections::BTreeMap;

    use super::{
        ErrorVistaCausal, FuenteIndiceAdmitidos, FuenteRegistrosDag, PresupuestoVista,
        RegistroEstructural, VistaPasadoEstructural,
    };
    use zx_core::digest::{BlockHash, BodyCommitment, Digest, MerkleRoot};
    use zx_core::preimage::dag::{DagBlockHeader, PadresDag, SolucionPoas};
    use zx_core::wire_dag::{BloqueDag, JustificacionPot};
    use zx_storage::{AlmacenAdmitidosDag, AlmacenCandidatosDag, StorageError};

    fn h(marca: u8) -> BlockHash {
        BlockHash::from_digest(Digest::from_bytes([marca; 32]))
    }

    fn cabecera_con(slot: u64, marca: u8, padres: PadresDag) -> DagBlockHeader {
        DagBlockHeader {
            consensus_branch_id: 0xc478_80ea,
            merkle_root: MerkleRoot::from_digest(Digest::from_bytes([marca; 32])),
            timestamp: 1_788_480_000 + slot,
            height: 1,
            slot,
            pot_output: [marca; 16],
            rango_solucion: u64::from(marca),
            sol: SolucionPoas::default(),
            body_commitment: BodyCommitment::from_digest(Digest::from_bytes([marca; 32])),
            padres,
            sello: [marca; 64],
        }
    }

    fn bloque_con(
        slot: u64,
        marca: u8,
        seleccionado: BlockHash,
        extras: &[BlockHash],
    ) -> BloqueDag {
        let padres = PadresDag::nuevo(seleccionado, extras).expect("padres canónicos");
        BloqueDag::nuevo(
            cabecera_con(slot, marca, padres),
            JustificacionPot::vacia(),
            vec![],
            vec![],
        )
        .expect("bloque sin cuerpo")
    }

    fn bloque(slot: u64, marca: u8, seleccionado: u8, extras: &[u8]) -> BloqueDag {
        let extras: Vec<BlockHash> = extras.iter().copied().map(h).collect();
        bloque_con(slot, marca, h(seleccionado), &extras)
    }

    fn bloque_genesis(slot: u64, marca: u8) -> BloqueDag {
        BloqueDag::nuevo(
            cabecera_con(slot, marca, PadresDag::genesis()),
            JustificacionPot::vacia(),
            vec![],
            vec![],
        )
        .expect("bloque génesis sin cuerpo")
    }

    /// Fake de **lectura** del nuevo trait. No acredita admisión: solo rellena la interfaz para
    /// probar el adaptador. Implementa **además** la cola de candidatos para demostrar que el
    /// adaptador no la consulta como respaldo.
    #[derive(Default)]
    struct IndiceFake {
        admitidos: BTreeMap<BlockHash, BloqueDag>,
        candidatos: BTreeMap<BlockHash, BloqueDag>,
        falla: bool,
    }

    impl IndiceFake {
        fn con_admitido(mut self, bloque: BloqueDag) -> Self {
            self.admitidos.insert(bloque.cabecera.block_hash(), bloque);
            self
        }

        fn con_candidato(mut self, bloque: BloqueDag) -> Self {
            self.candidatos.insert(bloque.cabecera.block_hash(), bloque);
            self
        }

        fn que_falla(mut self) -> Self {
            self.falla = true;
            self
        }
    }

    impl AlmacenAdmitidosDag for IndiceFake {
        fn bloque_admitido(&self, hash: &BlockHash) -> Result<Option<BloqueDag>, StorageError> {
            if self.falla {
                return Err(StorageError::Corrupto {
                    que: "un fake que falla a propósito",
                });
            }
            Ok(self.admitidos.get(hash).cloned())
        }
    }

    impl AlmacenCandidatosDag for IndiceFake {
        fn guardar_candidato_dag(&self, _bloque: &BloqueDag) -> Result<(), StorageError> {
            Ok(())
        }

        fn candidato_dag(&self, hash: &BlockHash) -> Result<Option<BloqueDag>, StorageError> {
            Ok(self.candidatos.get(hash).cloned())
        }
    }

    /// El adaptador lee el índice con hash/padres/slot canónicos y **no** cae a la cola.
    #[test]
    fn el_adaptador_lee_el_indice_y_no_la_cola_de_candidatos() {
        let candidato = bloque(30, 0x0A, 0x01, &[]);
        let hash = candidato.cabecera.block_hash();

        // Solo en la cola: la fuente debe decir `None`, no leer el candidato.
        let solo_cola = IndiceFake::default().con_candidato(candidato.clone());
        let fuente = FuenteIndiceAdmitidos::nueva(&solo_cola);
        assert_eq!(
            fuente.leer(&hash).expect("sin error"),
            None,
            "la cola no es una fuente de bloques admitidos"
        );

        // En el índice: se lee con los campos canónicos de la cabecera.
        let admitido = IndiceFake::default().con_admitido(candidato.clone());
        let fuente = FuenteIndiceAdmitidos::nueva(&admitido);
        let registro = fuente.leer(&hash).expect("sin error").expect("está");
        assert_eq!(registro.hash(), hash);
        assert_eq!(registro.hash(), candidato.cabecera.block_hash());
        assert_eq!(registro.padres(), candidato.cabecera.padres);
        assert_eq!(registro.slot(), 30);
    }

    /// El diamante del índice se une y comparte ancestro una sola vez, como el resto de la vista.
    #[test]
    fn el_diamante_del_indice_coincide_con_la_vista_estructural() {
        let c = bloque_genesis(10, 0x0C);
        let c_hash = c.cabecera.block_hash();
        let a = bloque_con(20, 0x0A, c_hash, &[]);
        let b = bloque_con(20, 0x0B, c_hash, &[]);
        let indice = IndiceFake::default()
            .con_admitido(a.clone())
            .con_admitido(b.clone())
            .con_admitido(c.clone());
        let fuente = FuenteIndiceAdmitidos::nueva(&indice);
        let padres = PadresDag::nuevo(a.cabecera.block_hash(), &[b.cabecera.block_hash()])
            .expect("padres canónicos");

        let vista = VistaPasadoEstructural::desde_padres(
            &fuente,
            &padres,
            h(0x50),
            PresupuestoVista::nuevo(8),
        )
        .expect("vista completa");

        let mut esperado = vec![
            a.cabecera.block_hash(),
            b.cabecera.block_hash(),
            c.cabecera.block_hash(),
        ];
        esperado.sort_unstable();
        let obtenido: Vec<BlockHash> = vista
            .ancestros()
            .iter()
            .map(RegistroEstructural::hash)
            .collect();
        assert_eq!(obtenido, esperado);
    }

    /// La ausencia en el índice es contexto incompleto, no invalidez.
    #[test]
    fn la_ausencia_en_el_indice_es_contexto_incompleto() {
        // A está admitido y apunta a B, que no está: falta contexto.
        let a = bloque(20, 0x0A, 0x0B, &[]);
        let indice = IndiceFake::default().con_admitido(a.clone());
        let fuente = FuenteIndiceAdmitidos::nueva(&indice);
        let padres = PadresDag::nuevo(a.cabecera.block_hash(), &[]).expect("padres canónicos");

        let resultado = VistaPasadoEstructural::desde_padres(
            &fuente,
            &padres,
            h(0x50),
            PresupuestoVista::nuevo(8),
        );
        assert_eq!(
            resultado,
            Err(ErrorVistaCausal::ContextoIncompleto {
                faltante: h(0x0B),
                referido_por: Some(a.cabecera.block_hash()),
            })
        );
    }

    /// La corrupción del índice **no** se convierte en ausencia: se propaga como error de fuente.
    #[test]
    fn la_corrupcion_del_indice_llega_como_error_de_fuente() {
        let indice = IndiceFake::default().que_falla();
        let fuente = FuenteIndiceAdmitidos::nueva(&indice);
        assert!(matches!(
            fuente.leer(&h(0x01)),
            Err(StorageError::Corrupto { .. })
        ));

        let padres = PadresDag::nuevo(h(0x0A), &[]).expect("padres canónicos");
        let resultado = VistaPasadoEstructural::desde_padres(
            &fuente,
            &padres,
            h(0x50),
            PresupuestoVista::nuevo(8),
        );
        assert!(matches!(
            resultado,
            Err(ErrorVistaCausal::Fuente(StorageError::Corrupto { .. }))
        ));
    }
}
