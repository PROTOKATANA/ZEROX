//! Bucle de consenso: el único dueño de `zx-cadena` y `zx-storage` (decisión 3).
//!
//! Arranque limpio o reinicio (D-N03′), tubería de admisión única (decisión 4), fases PoW y PoST en
//! régimen (decisión 5, 6), resumen de estado (decisión 8) y registro estructurado (decisión 9).

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::sync::mpsc;
use std::thread;
use std::time::Instant;

use primitive_types::U256;
use subspace_core_primitives::PublicKey;
use subspace_verification::PieceCheckParams;
use zx_cadena::{BloqueCadena, BloquePost, Cadena};
use zx_consensus::genesis::{GENESIS_DEV, HASH_GENESIS_DEV, construir as construir_genesis};
use zx_consensus::transicion::{BloqueTransicion, HechosCabecera, Origen, ParametrosTransicion};
use zx_consensus::verificador::{ContextoPow, validar_cabecera_pow};
use zx_consensus::{PARAMETROS_POW_DEV, Sha3Dev};
use zx_core::digest::Digest;
use zx_core::preimage::block::BlockHeader;
use zx_core::wire::cuerpo_desde_bytes;
use zx_core::wire_dag::{BloqueDag, MAX_BUNDLES_POT, bloque_dag_desde_bytes};
use zx_core::{BlockHash, PadresDag, Red, Tx, trabajo_bloque};
use zx_dag::ErrorDag;
use zx_dag::bloque_dag::{CandidatoSinRango, ContextoRangoDag};
use zx_farmer::farmer::{ParcelaDisco, plotear_sector_en_disco};
use zx_p2p::entrante::VeredictoFinal;
use zx_p2p::mensaje::{BloqueRed, Estado, Fase as FaseRed, PuntaPow};
use zx_poas::HistoriaGenesis;
use zx_post::cabecera_conjunta::{EstadoCabeceraConjunta, verificar_cabecera_conjunta};
use zx_post::pot_rango::{CachePotVerificada, PresupuestoPot};
use zx_post::productor::{
    FuenteSoluciones, ParametrosProductor, ProductoFirmado, SolucionCandidata,
    producir_con_firmante,
};
use zx_post::servicio_pot::ServicioPot;
use zx_storage::disco::AlmacenEnDisco;
use zx_storage::{Almacen, BloqueAdmitido, ErrorRepeticion, Familia};

use crate::claves::ClaveDev;
use crate::compendio::compendio_de_almacen;
use crate::error::{ErrorNodo, ResultadoNodo};
use crate::estado_resumen::resumen_estado;
use crate::identidad::identidad_de_cabecera_post;
use crate::padres::padres_de_regimen;
use crate::parada;
use crate::perfil;
use crate::pow;
use crate::red::huerfanos::DepositoHuerfanos;
use crate::red::vista::VistaRed;
use crate::red::{self, ManijaRed, ReceptorTrabajoRed, TrabajoRed};
use crate::regimen::{ClaveConParcela, MsgBucle, MsgProductor, hilo_productor_regimen};
use crate::registro::Registro;
use zx_post::firmante::{Firmante, Registro as RegistroFirmante};

/// `SR_dev`/`ContextoRangoDag` constante del perfil dev (D-P11: sin controlador).
struct RangoDev(u64);

impl ContextoRangoDag for RangoDev {
    fn rango_esperado(&self, _candidato: &CandidatoSinRango<'_>) -> Result<u64, ErrorDag> {
        Ok(self.0)
    }
}

/// Presupuesto sin tope: el nodo dev no impone `C-NET-33` en un proceso propio y sin red.
struct PresupuestoIlimitado;

impl PresupuestoPot for PresupuestoIlimitado {
    fn consumir_slot(&mut self, _slot: u64) -> bool {
        true
    }
}

/// Configuración del nodo (decisión 10, CLI).
pub struct Config {
    /// Directorio de datos (almacén + parcelas).
    pub dir_datos: PathBuf,
    /// Ruta del registro estructurado.
    pub ruta_registro: PathBuf,
    /// Red configurada (decisión 2: debe ser `Red::Dev`).
    pub red: Red,
    /// Semilla de derivación de claves.
    pub semilla: u64,
    /// Índices de claves a derivar.
    pub indices_claves: Vec<u32>,
    /// `N_dev`.
    pub n_dev: u64,
    /// `SR_dev`.
    pub sr_dev: u64,
    /// Parada tras N slots de régimen (`None` = sin límite).
    pub parada_tras_slots: Option<u64>,
    /// `ORDEN-W06d6` decisión 6: desde este slot el nodo deja de **producir**, pero sigue
    /// validando, propagando y sincronizando. `None` = nunca deja de producir por esta vía.
    pub dejar_de_producir_en_slot: Option<u64>,
}

/// Estado completo del nodo, dueño único de `zx-cadena` y `zx-storage`.
pub struct Nodo {
    params: ParametrosTransicion,
    cadena: Cadena,
    almacen: AlmacenEnDisco,
    /// Registro estructurado compartido (`ORDEN-W07a`): el hilo de consenso y la tarea de red
    /// escriben en él (el `Mutex` interno serializa cada línea).
    registro: Arc<Registro>,
    /// `ORDEN-SL4b2` decisión 2: registro durable del firmante seguro (`C-EVP-06`, FIR-01…FIR-15),
    /// único por nodo (compartido entre todas sus claves: la identidad RAT-1 ya incluye
    /// `public_key`). `None` hasta que `arranque_limpio`/`reiniciar` lo abre; `fase_regimen` es lo
    /// único que lo usa y corre siempre después de que uno de los dos se haya ejecutado.
    registro_firmante: Option<Arc<RegistroFirmante>>,
    /// `ORDEN-SL4b2` decisiones 3/4: detector de doble firma y lista de `EvidenceTx` pendientes de
    /// incluir. En memoria, no persiste entre reinicios (declarado en `DEFINICIONES-FALTANTES.md`).
    detector: crate::evidencia::DetectorDobleFirma,
    claves: Vec<ClaveDev>,
    cbid: u32,
    /// Cadena de cabeceras `[0..=altura]` de la punta PoW **seleccionada** (mayor trabajo
    /// acumulado, `ORDEN-W06d3` decisión 3): la reconstruye [`Nodo::actualizar_seleccion_pow`] cada
    /// vez que cambia. No es "todo lo que se ha visto": para eso está [`Self::headers_pow`].
    historial_pow: Vec<BlockHeader>,
    /// Todas las cabeceras PoW conocidas y válidas, indexadas por hash, de cualquier rama
    /// (`ORDEN-W06d3` decisión 3): permite reconstruir el historial de **cualquier** punta con
    /// `Nodo::historial_hasta`, no solo el de la rama seleccionada hoy.
    headers_pow: BTreeMap<BlockHash, BlockHeader>,
    /// Un `ServicioPot` de verificación **por terminal candidato** (`ORDEN-W06d7` decisión 5: ya no
    /// hay uno solo, porque puede haber varios terminales con DAG a la vez). Se crea en cuanto
    /// `zx-cadena` reconoce el candidato ([`Nodo::asegurar_servicios_verificacion`]), antes incluso
    /// de que tenga DAG propio (el bloque de transición de ese terminal necesita el servicio para
    /// verificarse, y todavía no hay DAG en ese punto).
    servicios_verificacion: BTreeMap<BlockHash, ServicioPot>,
    historia: Arc<HistoriaGenesis>,
    ultima_punta_registrada: Option<BlockHash>,
    dir_datos: PathBuf,
    n_dev: u64,
    sr_dev_actual: u64,
    parada_tras_slots: Option<u64>,
    /// `ORDEN-W06d6` decisión 6.
    dejar_de_producir_en_slot: Option<u64>,
    /// Trabajo PoW acumulado de la cadena admitida (para el saludo de red, decisión 4).
    trabajo_acumulado: U256,
    /// Hash del génesis (cacheado: `ORDEN-W06d2` lo necesita en cada saludo).
    hash_genesis: BlockHash,
    /// Red configurada (`ORDEN-W06d2` lo necesita en cada saludo).
    red_configurada: Red,
    /// Instantánea de solo lectura que sirve el saludo y la sincronización (`ORDEN-W06d2`).
    /// Existe siempre, con o sin red: así no hay dos caminos de construcción de `Nodo`.
    vista_red: Arc<VistaRed>,
    /// Depósito acotado de bloques huérfanos (decisión 3).
    huerfanos: DepositoHuerfanos,
    /// El handle hacia la red, si [`Self::conectar_red`] se llamó. `None` reproduce exactamente el
    /// comportamiento de `ORDEN-W06d1`: un nodo sin red.
    red: Option<ManijaRed>,
    /// Cola de trabajo que el manejador de red encola y este hilo drena (decisión 1).
    trabajo_red: Option<ReceptorTrabajoRed>,
    /// Bloques PoST **de red** descartados como [`crate::rechazo::ClasificacionRechazo::Pendiente`]
    /// (aviso del director, `ORDEN-W06d5`, tras el hallazgo de V5): no son inválidos, solo faltó
    /// contexto local (`Pot(PasadoIncompleto)` mientras este nodo sincroniza fuera de orden). Nunca
    /// se cachean como inválidos ni penalizan al remitente; se reintentan en
    /// [`Self::reintentar_post_pendientes`] cada vez que el propio pasado avanza. Acotada
    /// (`TOPE_POST_PENDIENTES`): el más viejo se descarta sin más si se supera el tope — el riesgo
    /// que se evita es RI-2a (un hueco local guardado para siempre como si fuera un defecto del
    /// candidato), no un cachá sin límite. `ORDEN-W07a`: cada entrada lleva el `Instant` de llegada
    /// del bloque, para que el `bloque_red_admitido` del reintento conserve `t_total_ns`.
    post_pendientes: std::collections::VecDeque<(BloqueDag, Instant)>,
    /// `ORDEN-W07a`: modo del arranque (`true` = limpio, `false` = reinicio), para el evento
    /// `arranque`, que se emite al empezar `ejecutar` (cuando ya se conoce, si la hay, la red).
    modo_limpio: bool,
    /// `ORDEN-W07a`: `PeerId` de libp2p del nodo, si hay red (para `arranque`).
    peer_id: Option<String>,
    /// `ORDEN-W07a`: dirección donde escucha el nodo, si hay red (para `arranque`).
    red_escuchar: Option<String>,
    /// `ORDEN-W07a`: desglose de la última admisión (etapas envueltas con `Instant`), para el
    /// `bloque_red_admitido`/`bloque_red_rechazado`.
    medicion: Medicion,
    /// `ORDEN-W07a`: cadena seleccionada en el último `cambio_punta`, para calcular
    /// `profundidad_reorg` sin tocar `zx-cadena`. `ultima_cadena_indice` es su índice por hash
    /// (evita reconstruirlo en cada cambio de punta).
    ultima_cadena_seleccionada: Vec<BlockHash>,
    /// Índice `hash -> posición` de [`Self::ultima_cadena_seleccionada`].
    ultima_cadena_indice: BTreeMap<BlockHash, usize>,
    /// `ORDEN-W06d10-B`, **solo en tests**: fallo **local** inyectado (persistencia/servicio) para
    /// poder demostrar que el borde de red lo trata como `Ignorar` y lo registra, sin depender de
    /// romper de verdad el disco. Nunca existe en el binario de producción.
    #[cfg(test)]
    fallo_local_simulado: Option<String>,
    /// `ORDEN-W06d10-B`, **solo en tests**: reloj local inyectado, para poder demostrar que X1
    /// (timestamp futuro, C-TS-03) se difiere sin cachearse y se admite cuando el reloj avanza, sin
    /// depender del reloj real de la máquina. Nunca existe en el binario de producción.
    #[cfg(test)]
    reloj_local_simulado: Option<i64>,
}

/// Desglose de tiempos y etapa de la última llamada a `admitir_pow_interno`/`admitir_post_interno`
/// (`ORDEN-W07a` decisión 1: solo `Instant` alrededor de llamadas que ya existen).
#[derive(Clone, Copy, Default)]
struct Medicion {
    /// Tiempo de la verificación de cabecera (PoW o cabecera conjunta).
    cabecera_ns: u64,
    /// Tiempo de `Cadena::admitir` (GHOSTDAG y estado).
    admision_ns: u64,
    /// Tiempo de `Almacen::admitir` (persistencia).
    persistencia_ns: u64,
    /// Última etapa **iniciada**; punto de fallo para `bloque_red_rechazado`.
    etapa: &'static str,
}

/// Tope de [`Nodo::post_pendientes`]: acotar la cola, no la corrección (D-oS local, no de consenso).
const TOPE_POST_PENDIENTES: usize = 64;

/// `ORDEN-SL4b2` decisión 1: puerta RAT-3, factorizada de [`Nodo::arrancar`] para poder probarla
/// con un perfil que la incumple sin tener que construir un nodo entero (disco, génesis, parcelas).
fn comprobar_puerta_rat3(
    r_slots: u64,
    evidencia: &zx_consensus::transicion::ParametrosEvidencia,
) -> ResultadoNodo<()> {
    if perfil::puerta_rat3(r_slots, evidencia) {
        Ok(())
    } else {
        Err(ErrorNodo::PuertaRat3Incumplida {
            r_slots,
            plazo_mas_margen: evidencia.plazo_slots + evidencia.m_margen_slots,
        })
    }
}

fn ruta_parcela(dir_datos: &Path, indice: u32) -> PathBuf {
    dir_datos.join(format!("parcela-{indice}.plot"))
}

/// Índice de sector determinista por índice de clave (D2: distinto de cero para ejercitar offset).
fn indice_sector_de(indice_clave: u32) -> u16 {
    u16::try_from(indice_clave % 1000).unwrap_or(0) + 1
}

const PIEZAS_POR_SECTOR: u16 = zx_poas::protocolo_dev::PIEZAS_POR_SECTOR_DEV;

/// Abre o crea la parcela de una clave (D2).
fn abrir_o_crear_parcela(
    dir_datos: &Path,
    clave: &ClaveDev,
    historia: &HistoriaGenesis,
) -> ResultadoNodo<ParcelaDisco> {
    let ruta = ruta_parcela(dir_datos, clave.indice);
    let public_key = PublicKey::from(*clave.pk.bytes());
    if !ruta.exists() {
        plotear_sector_en_disco(
            &ruta,
            &public_key,
            indice_sector_de(clave.indice),
            PIEZAS_POR_SECTOR,
            historia.historial(),
            historia.protocolo(),
            historia.kzg(),
            historia.erasure_coding(),
        )
        .map_err(ErrorNodo::Farmer)?;
    }
    ParcelaDisco::abrir(&ruta, &public_key).map_err(ErrorNodo::Farmer)
}

impl Nodo {
    /// Arranca el nodo: comprueba la red **antes** de abrir disco o parcelas (decisión 2), abre (o
    /// crea) el almacén y repite su registro sobre una `Cadena` nueva si no está vacío (D-N03′).
    ///
    /// # Errores
    /// [`ErrorNodo::RedNoEsDev`] si `cfg.red != Red::Dev`; el resto de variantes según la fase.
    pub fn arrancar(cfg: &Config) -> ResultadoNodo<Self> {
        if cfg.red != Red::Dev {
            return Err(ErrorNodo::RedNoEsDev {
                encontrada: cfg.red,
            });
        }
        std::fs::create_dir_all(&cfg.dir_datos)?;
        let registro = Arc::new(Registro::abrir(&cfg.ruta_registro)?);

        let params = perfil::parametros_transicion_dev()?;
        let cbid = zx_core::CBID_RED_DEV;
        // `ORDEN-SL4b2` decisión 1: puerta RAT-3, comprobada **antes** de tocar disco (mismo
        // espíritu que la comprobación de `Red::Dev` de arriba, decisión 2 de `ORDEN-W06d1`). Un
        // perfil que la incumple no arranca, con el mensaje exacto en el error.
        let evidencia = perfil::parametros_evidencia_dev();
        comprobar_puerta_rat3(params.r_slots, &evidencia)?;
        let (cabecera_genesis, tx_genesis) = construir_genesis(GENESIS_DEV)?;
        let hash_genesis_esperado = BlockHash::from_digest(Digest::from_bytes(HASH_GENESIS_DEV));
        if cabecera_genesis.block_hash() != hash_genesis_esperado {
            return Err(ErrorNodo::GenesisDiscrepante {
                encontrado: cabecera_genesis.block_hash(),
                esperado: hash_genesis_esperado,
            });
        }

        let ruta_almacen = cfg.dir_datos.join("storage");
        let almacen =
            AlmacenEnDisco::abrir(&ruta_almacen, Red::Dev, cabecera_genesis.block_hash())?;
        let claves = ClaveDev::derivar_varias(cfg.semilla, &cfg.indices_claves);
        let historia = Arc::new(HistoriaGenesis::construir()?);

        let estado_inicial = Estado {
            hash_genesis: hash_genesis_esperado,
            red: cfg.red,
            fase: FaseRed::Pow,
            punta_pow: PuntaPow {
                hash: hash_genesis_esperado,
                altura: 0,
                trabajo_acumulado: [0; 32],
            },
            terminal: None,
            puntas_post: Vec::new(),
            blue_work_virtual: [0; 32],
            longitud_registro: 0,
        };

        let mut nodo = Self {
            params,
            // `ORDEN-SL4b2` decisión 1: `nueva_con_evidencia`, con el perfil de evidencia dev
            // (`f = 1/1`, `Plazo_slots = 300`, `M_margen_slots = 60`, `cbid`, activa) ya validado
            // por la puerta RAT-3 de arriba.
            cadena: Cadena::nueva_con_evidencia(
                perfil::parametros_transicion_dev()?,
                perfil::ghostdag_k(),
                cbid,
                perfil::ghostdag_max_padres(),
                evidencia,
            ),
            almacen,
            registro,
            registro_firmante: None,
            detector: crate::evidencia::DetectorDobleFirma::nuevo(perfil::MAX_IDENTIDADES_DETECTOR),
            claves,
            cbid,
            historial_pow: Vec::new(),
            headers_pow: BTreeMap::new(),
            servicios_verificacion: BTreeMap::new(),
            historia,
            ultima_punta_registrada: None,
            dir_datos: cfg.dir_datos.clone(),
            n_dev: cfg.n_dev,
            sr_dev_actual: cfg.sr_dev,
            parada_tras_slots: cfg.parada_tras_slots,
            dejar_de_producir_en_slot: cfg.dejar_de_producir_en_slot,
            trabajo_acumulado: U256::zero(),
            hash_genesis: hash_genesis_esperado,
            red_configurada: cfg.red,
            vista_red: Arc::new(VistaRed::nueva(estado_inicial)),
            huerfanos: red::nuevo_deposito_huerfanos(),
            red: None,
            trabajo_red: None,
            post_pendientes: std::collections::VecDeque::new(),
            modo_limpio: false,
            peer_id: None,
            red_escuchar: None,
            medicion: Medicion::default(),
            ultima_cadena_seleccionada: Vec::new(),
            ultima_cadena_indice: BTreeMap::new(),
            #[cfg(test)]
            fallo_local_simulado: None,
            #[cfg(test)]
            reloj_local_simulado: None,
        };

        let longitud = nodo.almacen.longitud_registro()?;
        nodo.modo_limpio = longitud == 0;
        if longitud == 0 {
            nodo.arranque_limpio(cabecera_genesis, tx_genesis)?;
        } else {
            nodo.reiniciar(longitud)?;
        }
        Ok(nodo)
    }

    fn arranque_limpio(
        &mut self,
        cabecera_genesis: BlockHeader,
        tx_genesis: Tx,
    ) -> ResultadoNodo<()> {
        let testigos_genesis: Vec<Vec<Vec<u8>>> = vec![Vec::new()];
        // `ORDEN-W06d6` decisión 1: instantánea para el registro de admisión de la vista de red,
        // construida antes de que `tx_genesis` se consuma más abajo.
        let para_vista_genesis = BloqueRed::Pow {
            cabecera: cabecera_genesis,
            txs: vec![tx_genesis.clone()],
            testigos: testigos_genesis.clone(),
        };
        self.cadena
            .admitir(BloqueCadena::Pow(BloqueTransicion::nuevo(
                HechosCabecera::Genesis {
                    hash: cabecera_genesis.block_hash(),
                },
                vec![(
                    tx_genesis.clone(),
                    testigos_genesis.first().cloned().unwrap_or_default(),
                )],
            )))
            .map_err(|m| ErrorNodo::BloquePropioRechazado {
                hash: cabecera_genesis.block_hash(),
                motivo: m.nombre().to_string(),
                // Interno: el génesis dev es una constante fija (W04); un rechazo aquí es siempre
                // un bug de construcción, nunca una carrera (no hay nada concurrente todavía).
                clasificacion: crate::rechazo::ClasificacionRechazo::Interno,
            })?;
        let admitido = BloqueAdmitido::pow(&cabecera_genesis, &[tx_genesis], &testigos_genesis);
        self.almacen.admitir(&admitido, true)?;
        self.headers_pow
            .insert(cabecera_genesis.block_hash(), cabecera_genesis);
        self.historial_pow.push(cabecera_genesis);
        // `ORDEN-W06d3`, hallazgo en vivo (`PROGRESO.md`): en un arranque limpio (a diferencia de
        // un reinicio, que sí pasa por `admitir_pow_interno`) nada más registraba el génesis en
        // `VistaRed::cabeceras_pow`; el primer bloque real quedaba como "hueco de altura" para
        // siempre y el localizador de sincronización nunca llegaba a funcionar. `Self::historial_pow`
        // es la fuente de verdad; `fijar_cabeceras_pow` la copia entera a la vista.
        self.vista_red.fijar_cabeceras_pow(&self.historial_pow);
        // `ORDEN-W06d6` decisión 1: el registro de admisión de la vista tiene que empezar en el
        // génesis, igual que el registro real de `zx-storage` (`registrar_pow` no se llama aquí,
        // así que sin esto el cuerpo y la entrada de registro del génesis nunca existirían en la
        // vista de red).
        self.vista_red.registrar_genesis_pow(para_vista_genesis);
        // `ORDEN-SL4b2` decisión 2 (FIR-12): arranque limpio ⇒ `Registro::nueva`, sin historia y
        // sin abstención — el directorio de datos lo creó este mismo proceso, así que no hay nada
        // que perder.
        self.abrir_registro_firmante_limpio()?;
        Ok(())
    }

    /// Ruta del registro durable del firmante seguro (decisión 2): un fichero por nodo, compartido
    /// entre todas sus claves (la identidad RAT-1 ya incluye `public_key`, FIR-02).
    fn ruta_registro_firmante(&self) -> PathBuf {
        self.dir_datos.join("firmante.registro")
    }

    /// `ORDEN-SL4b2` decisión 2, FIR-12: alta atómica sin historia. Solo válido en un arranque
    /// **limpio** (directorio de datos creado por este proceso): una identidad que ya existía y
    /// perdió su registro usa [`Self::abrir_registro_firmante_tras_reinicio`], nunca esta ruta.
    fn abrir_registro_firmante_limpio(&mut self) -> ResultadoNodo<()> {
        let ruta = self.ruta_registro_firmante();
        let registro = RegistroFirmante::nueva(ruta).map_err(|e| {
            ErrorNodo::Otro(format!(
                "firmante: no se pudo crear el registro nuevo (arranque limpio): {e}"
            ))
        })?;
        self.registro_firmante = Some(Arc::new(registro));
        Ok(())
    }

    /// `ORDEN-SL4b2` decisión 2: en todo reinicio, `Registro::abrir(ruta, slot_actual, 150)` con
    /// `slot_actual = máx(slot más alto de los bloques del almacén, slot PoT reconstruido)`. Se
    /// llama al final de [`Self::reiniciar`], cuando `self.cadena` y
    /// `self.servicios_verificacion` ya reflejan toda la historia repetida.
    fn abrir_registro_firmante_tras_reinicio(&mut self) -> ResultadoNodo<()> {
        let slot_bloques = self
            .cadena
            .bloques_post()
            .iter()
            .map(|b| b.slot)
            .max()
            .unwrap_or(0);
        let slot_pot = self
            .cadena
            .terminal()
            .and_then(|t| self.servicios_verificacion.get(&t))
            .map(ServicioPot::slot_actual)
            .unwrap_or(0);
        let slot_actual = slot_bloques.max(slot_pot);
        let ruta = self.ruta_registro_firmante();
        let registro =
            RegistroFirmante::abrir(ruta, slot_actual, perfil::S_MAX_SLOTS).map_err(|e| {
                ErrorNodo::Otro(format!(
                    "firmante: no se pudo abrir el registro tras el reinicio (slot_actual \
                     {slot_actual}): {e}"
                ))
            })?;
        self.registro_firmante = Some(Arc::new(registro));
        Ok(())
    }

    /// D-N03′: repite el registro de admisión sobre una `Cadena` fresca, sin re-verificar cabeceras,
    /// y reconstruye el `ServicioPot` de verificación desde las cabeceras almacenadas (decisión 7).
    fn reiniciar(&mut self, longitud: u64) -> ResultadoNodo<()> {
        let inicio = Instant::now();

        // `Almacen::repetir` toma un `FnMut` que aquí no puede pedir prestado `self` entero (ya
        // presta `self.almacen`): se recogen primero los pares crudos (el almacén ya comprobó su
        // integridad al abrir) y se procesan después, uno a uno, con acceso normal a `self`.
        let mut crudos: Vec<(BlockHash, Vec<u8>)> = Vec::new();
        let resultado: Result<(), ErrorRepeticion<std::convert::Infallible>> =
            self.almacen.repetir(&mut |hash, valor| {
                crudos.push((hash, valor.to_vec()));
                Ok(())
            });
        resultado.map_err(|e| match e {
            ErrorRepeticion::Almacen(se) => ErrorNodo::Almacen(se),
            ErrorRepeticion::Destino(ne) => match ne {},
        })?;

        let mut indice = 0u64;
        for (hash, valor) in &crudos {
            self.repetir_uno(*hash, valor, indice)?;
            indice = indice.saturating_add(1);
        }

        if indice != longitud {
            return Err(ErrorNodo::Otro(format!(
                "la repetición procesó {indice} entradas, se esperaban {longitud}"
            )));
        }
        // `ORDEN-SL4b2` decisión 2: se abre **después** de repetir, cuando `self.cadena` y
        // `self.servicios_verificacion` ya reflejan toda la historia (necesarios para calcular
        // `slot_actual`).
        self.abrir_registro_firmante_tras_reinicio()?;
        // `ORDEN-W07d` decisión 1: el resumen del estado virtual **después** de repetir todo el
        // almacén, más la punta, el conteo de bloques y el compendio de todos los admitidos. El
        // resumen usa la misma función que `cambio_punta`; el compendio, el registro persistido
        // completo (PoW y PoST).
        let (punta, resumen, n_bloques_dag, compendio) = self.campos_estado_final()?;
        self.registro.escribir(
            self.registro
                .evento("reinicio_completo")
                .u64("bloques_repetidos", indice)
                .u64("duracion_ns", inicio.elapsed().as_nanos() as u64)
                .str("punta", &punta)
                .str("resumen_estado", &resumen)
                .u64("n_bloques_dag", n_bloques_dag)
                .str("compendio_bloques", &compendio),
            true,
        )?;
        Ok(())
    }

    /// Campos del estado final para `reinicio_completo` y `parada` (`ORDEN-W07d` decisiones 1 y 2):
    /// `(punta, resumen_estado, n_bloques_dag, compendio_bloques)`.
    ///
    /// `punta` es `mejor_punta().or(terminal())`, la misma expresión que `cambio_punta`; si no hay
    /// ninguna (fase PoW pura) queda vacía (falta de definición 3). `n_bloques_dag` es
    /// `Cadena::bloques_admitidos()`, la definición que ya usa el esquema v1. El compendio sale del
    /// almacén persistido, que incluye el génesis (falta de definición 1).
    fn campos_estado_final(&self) -> ResultadoNodo<(String, String, u64, String)> {
        let punta = self.cadena.mejor_punta().or(self.cadena.terminal());
        let estado = self
            .cadena
            .estado_virtual()
            .map_err(|m| ErrorNodo::Otro(format!("estado virtual: {m}")))?;
        let resumen = resumen_estado(&estado);
        let n_bloques_dag = self.cadena.bloques_admitidos();
        let compendio = compendio_de_almacen(&self.almacen).map_err(ErrorNodo::Almacen)?;
        Ok((
            punta.map(|h| h.to_string()).unwrap_or_default(),
            resumen,
            n_bloques_dag,
            compendio,
        ))
    }

    /// Escribe el evento crítico `parada` (`ORDEN-W07d` decisión 2) con el estado final calculado
    /// en ese momento.
    fn escribir_parada(&self, motivo: &str) -> ResultadoNodo<()> {
        let (punta, resumen, n_bloques_dag, compendio) = self.campos_estado_final()?;
        self.registro.escribir(
            self.registro
                .evento("parada")
                .str("motivo", motivo)
                .str("punta", &punta)
                .str("resumen_estado", &resumen)
                .u64("n_bloques_dag", n_bloques_dag)
                .str("compendio_bloques", &compendio),
            true,
        )?;
        Ok(())
    }

    fn repetir_uno(&mut self, hash: BlockHash, valor: &[u8], indice: u64) -> Result<(), ErrorNodo> {
        let bloque =
            BloqueAdmitido::desde_almacen(valor).map_err(|e| ErrorNodo::RepeticionFallida {
                indice,
                hash,
                motivo: e.to_string(),
            })?;
        match bloque.familia() {
            Familia::Pow => {
                let (cuerpo, _) = cuerpo_desde_bytes(bloque.canonicos()).map_err(|e| {
                    ErrorNodo::RepeticionFallida {
                        indice,
                        hash,
                        motivo: e.to_string(),
                    }
                })?;
                let (cabecera, txs, testigos) = cuerpo;
                self.admitir_pow_interno(cabecera, txs, testigos, indice, false)
            }
            Familia::Post => {
                let (bloque_dag, _) = bloque_dag_desde_bytes(bloque.canonicos()).map_err(|e| {
                    ErrorNodo::RepeticionFallida {
                        indice,
                        hash,
                        motivo: e.to_string(),
                    }
                })?;
                self.admitir_post_interno(bloque_dag, indice, false)
            }
        }
    }

    /// Reloj local en segundos desde la época Unix (`C-TS-04`: nunca una hora de red). En tests
    /// puede inyectarse con [`Self::reloj_local_simulado`] para probar X1 sin depender del reloj
    /// real de la máquina.
    fn reloj_local(&self) -> i64 {
        #[cfg(test)]
        if let Some(t) = self.reloj_local_simulado {
            return t;
        }
        i64::try_from(
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .map(|d| d.as_secs())
                .unwrap_or(0),
        )
        .unwrap_or(i64::MAX)
    }

    /// Admite un bloque PoW: verificación W04 (si `verificar`), motor de transición, persistencia.
    ///
    /// `verificar = false` en la repetición (D-N03′): la cabecera ya se comprobó cuando se admitió
    /// la primera vez. El motor de transición (con sus firmas) se ejecuta **siempre**, verificado o
    /// no: es lo que detecta un testigo PoW corrupto (`REVISION-W06b.md`, límite declarado).
    fn admitir_pow_interno(
        &mut self,
        cabecera: BlockHeader,
        txs: Vec<Tx>,
        testigos: Vec<Vec<Vec<u8>>>,
        _indice_registro: u64,
        verificar: bool,
    ) -> Result<(), ErrorNodo> {
        let hash = cabecera.block_hash();
        let es_genesis = cabecera.height == 0;
        // `ORDEN-W06d10-B` (solo tests): fallo local inyectado, como el que produciría un error de
        // persistencia/servicio. Se consume una vez; en producción este bloque no existe.
        #[cfg(test)]
        if let Some(motivo) = self.fallo_local_simulado.take() {
            return Err(ErrorNodo::Otro(motivo));
        }
        // `ORDEN-W07a` decisión 1: solo se envuelven con `Instant` llamadas que ya existen. La
        // etapa se fija para poder etiquetar un rechazo (`bloque_red_rechazado`).
        self.medicion = Medicion {
            etapa: "cabecera",
            ..Medicion::default()
        };
        // Instantánea para la vista de red (decisión 4): se toma **antes** de que `txs`/`testigos`
        // se consuman más abajo (`into_iter().zip`). Solo se usa si el bloque resulta nuevo
        // (`!ya_admitido`, comprobado antes de publicarla); el coste de clonar es aceptable en la
        // red dev (bloques con pocas transacciones) y se revisa si el perfil (W07) lo desmiente.
        let para_vista = BloqueRed::Pow {
            cabecera,
            txs: txs.clone(),
            testigos: testigos.clone(),
        };

        if verificar && !es_genesis {
            let inicio_cabecera = Instant::now();
            // `ORDEN-W06d3` decisión 3: el contexto de validación (target, altura, timestamp) se
            // calcula contra el **padre declarado** de este bloque (`cabecera.prev_hash`), nunca
            // contra `historial_pow.last()`: eso es precisamente lo que hacía imposible admitir una
            // bifurcación PoW real con un contexto correcto (`REVISION-W06d2.md`, límite conocido).
            let historial_padre = self.historial_hasta(cabecera.prev_hash);
            let padre =
                *historial_padre
                    .last()
                    .ok_or_else(|| ErrorNodo::BloquePropioRechazado {
                        hash,
                        motivo: format!("padre {} desconocido (sin cabecera)", cabecera.prev_hash),
                        // Interno: el padre de un bloque que este mismo nodo acaba de minar sobre
                        // su propio `historial_pow` no puede ser desconocido salvo un bug real.
                        clasificacion: crate::rechazo::ClasificacionRechazo::Interno,
                    })?;
            let target_esperado = pow::target_de_altura(&historial_padre, cabecera.height)
                .map_err(|e| ErrorNodo::BloquePropioRechazado {
                    hash,
                    motivo: format!("target de altura: {e}"),
                    // Interno: depende del historial del padre declarado (que este nodo ya tiene),
                    // no de ninguna vista local; cualquier nodo con ese padre calcularía lo mismo.
                    clasificacion: crate::rechazo::ClasificacionRechazo::Interno,
                })?;
            let ctx = ContextoPow {
                red: Red::Dev,
                parametros: PARAMETROS_POW_DEV,
                altura_padre: padre.height,
                hash_padre: padre.block_hash(),
                target_esperado,
                ts_padre: i64::try_from(padre.timestamp).unwrap_or(i64::MAX),
                reloj_local: self.reloj_local(),
            };
            validar_cabecera_pow(&cabecera, &ctx, &Sha3Dev).map_err(|e| {
                ErrorNodo::BloquePropioRechazado {
                    hash,
                    motivo: format!("validar_cabecera_pow: {e}"),
                    // `ORDEN-W06d10-B` X1: el propio tipo declara con `es_permanente()` qué fallo
                    // es diferible (C-TS-03, reloj local → `VistaLocal`) y cuál es un defecto
                    // permanente del candidato (`Interno`). Para un bloque propio la fatalidad no
                    // cambia (`VistaLocal::es_legitimo() == false`).
                    clasificacion: crate::rechazo::clasificar_error_pow(&e),
                }
            })?;
            self.medicion.cabecera_ns = inicio_cabecera.elapsed().as_nanos() as u64;
        }
        // Se registra la cabecera (válida, o el génesis) para poder reconstruir el historial de
        // cualquier rama que la tenga como ancestro, sea o no la punta seleccionada hoy.
        self.headers_pow.insert(hash, cabecera);

        let hechos = if es_genesis {
            HechosCabecera::Genesis { hash }
        } else {
            let target =
                pow_target_de(&cabecera).map_err(|e| ErrorNodo::BloquePropioRechazado {
                    hash,
                    motivo: e.to_string(),
                    // Interno: `bits` no canónico del candidato, demostrable por cualquier nodo.
                    clasificacion: crate::rechazo::ClasificacionRechazo::Interno,
                })?;
            let trabajo =
                trabajo_bloque(target).ok_or_else(|| ErrorNodo::BloquePropioRechazado {
                    hash,
                    motivo: format!("trabajo del bloque {hash} desborda"),
                    // Interno: aritmética del propio bloque.
                    clasificacion: crate::rechazo::ClasificacionRechazo::Interno,
                })?;
            HechosCabecera::PoW {
                hash,
                padre: cabecera.prev_hash,
                altura: cabecera.height,
                trabajo,
                pow_valido: true,
            }
        };
        // `ORDEN-W06d4` decisión 1/2: hasta aquí, el rastro de coinbases/depósitos propios era un
        // indicador local (`CoinbasePropia.depositada`) que marcaba "ya gastada" en cuanto **algún**
        // bloque admitido (propio o ajeno, en cualquier rama) gastaba el `OutPoint`, sin comprobar si
        // ese bloque seguía en la rama seleccionada. Confirmado con evidencia
        // (`pruebas_deposito_sensible_a_la_rama`, más abajo): tras una reorganización que descarta el
        // bloque del depósito pero conserva la coinbase (todavía viva en la rama nueva), el
        // indicador quedaba en `true` para siempre y el nodo nunca volvía a depositarla, así que las
        // `K_min` claves con garantía activa que exige `Φ` nunca llegaban a reunirse con varios
        // procesos minando a la vez (`REVISION-W06d3.md`). `preparar_depositos` ya no mantiene ese
        // indicador: decide qué depositar leyendo directamente `estado.utxo`/`estado.garantias` de
        // la punta PoW **seleccionada** en el momento de construir el bloque, que es sensible a la
        // rama por construcción (una salida gastada en una rama descartada sigue viva en `utxo` de
        // cualquier otra rama que no la gastó).

        let ya_admitido = self.cadena.es_valido(&hash) || self.cadena.motivo(&hash).is_some();
        if !ya_admitido {
            // `ORDEN-W06d6`, paso previo (RI-3c H1, `REVISION-RI-3c.md`): orden **admitir en
            // `zx-cadena` → persistir → difundir** (la difusión la hace quien llama, ya solo tras
            // que esta función devuelva `Ok`). Antes se persistía primero: si `cadena.admitir`
            // rechazaba el bloque con un motivo `Legitimo`/`Interno` normal (`ErrGarantia`,
            // `ErrMergeDepth`... la propia `ORDEN-W06d5` decisión 3 los declara esperables), la
            // entrada quedaba en el almacén **sin que nada la deshiciera**: un bloque rechazado
            // repetía su rechazo en cada reinicio (D-N03′ repite todo el registro) y el nodo no
            // volvía a arrancar nunca (RI-3c, reproducido con un `ErrEmision`). Con el orden nuevo,
            // un rechazo de `cadena.admitir` sale de esta función (el `?` de abajo) **antes** de
            // tocar disco: no hay nada que deshacer. Si el proceso muere justo entre admitir
            // (memoria) y persistir (disco), el bloque simplemente no salió del nodo — nunca se
            // difundió (eso ocurre después, en el llamante) y el reinicio no lo repite porque no
            // está en el almacén; no es la doble firma que RI-2b temía (esa era sobre difundir
            // antes de persistir, no sobre admitir antes de persistir).
            let admitido = BloqueAdmitido::pow(&cabecera, &txs, &testigos);
            let txs_con_testigos: Vec<(Tx, Vec<Vec<u8>>)> = txs.into_iter().zip(testigos).collect();
            let bt = BloqueTransicion::nuevo(hechos, txs_con_testigos);
            self.medicion.etapa = "admision";
            let inicio_admision = Instant::now();
            self.cadena.admitir(BloqueCadena::Pow(bt)).map_err(|m| {
                ErrorNodo::BloquePropioRechazado {
                    hash,
                    motivo: m.nombre().to_string(),
                    clasificacion: crate::rechazo::clasificar_motivo_bloque(&m),
                }
            })?;
            self.medicion.admision_ns = inicio_admision.elapsed().as_nanos() as u64;
            // Solo en la ruta en vivo (`verificar`): en la repetición el bloque ya está en el
            // almacén (viene de ahí) y volver a escribirlo sería una vuelta redundante a disco.
            if verificar {
                self.medicion.etapa = "persistencia";
                let inicio_persistencia = Instant::now();
                self.almacen.admitir(&admitido, true)?;
                self.medicion.persistencia_ns = inicio_persistencia.elapsed().as_nanos() as u64;
            }
            self.vista_red.registrar_pow(cabecera.height, para_vista);
            // Un hijo que esperaba justo este padre puede reintentarse ya (decisión 3).
            self.resolver_huerfanos_de(hash);
        }

        // `ORDEN-W06d3` decisión 3: `historial_pow`/`trabajo_acumulado` ya no se extienden a
        // ciegas con cada bloque admitido (eso asumía una única cadena lineal); se recalculan desde
        // la punta PoW **seleccionada** por `zx-cadena` (mayor trabajo acumulado), lo mismo si este
        // bloque la extiende como si es un bloque de una rama lateral que no la cambia.
        self.actualizar_seleccion_pow()?;
        // `ORDEN-W06d7` decisión 5: un `ServicioPot` de verificación **por terminal candidato**, no
        // solo el seleccionado — puede haber varios terminales con DAG a la vez (decisión 1), y cada
        // uno necesita su propio flujo PoT para verificar los bloques PoST que declaran ese terminal
        // en su pasado, tanto en producción en vivo (lo crea también `fase_regimen`) como en la
        // **repetición** (D-N03′): si el registro trae ya bloques PoST, `admitir_post_interno` los
        // procesa aquí mismo, dentro de `Nodo::arrancar`, antes de que `fase_regimen` llegue a
        // ejecutarse. Sin esto, reabrir un nodo que ya había cruzado el corte fallaba siempre en la
        // primera entrada PoST del registro (bug real encontrado por `tests/reinicio.rs`,
        // `PROGRESO.md` de `W06d3`).
        self.asegurar_servicios_verificacion()?;
        self.registrar_cambio_de_punta()?;
        Ok(())
    }

    /// Crea el `ServicioPot` de verificación de todo terminal candidato que todavía no lo tenga
    /// (`ORDEN-W06d7` decisión 5). Idempotente: un candidato ya conocido no se reconstruye ni
    /// pierde el pasado PoT que ya llevaba (a diferencia del diseño de un único terminal, donde
    /// "reconstruir" significaba tirar el servicio anterior — aquí cada terminal tiene el suyo para
    /// siempre, así que no hace falta).
    /// `ORDEN-SL4b2` decisiones 3/4: observa `cabecera` en el detector de doble firma y traduce su
    /// resultado a eventos del esquema v1 (`evidencia_detectada`, `limite_alcanzado`). No falla
    /// nunca por el resultado del detector en sí (una identidad nueva, una retransmisión o una
    /// tercera cabecera del mismo incidente no son errores); solo puede fallar al escribir el
    /// registro estructurado.
    fn observar_para_detector(
        &mut self,
        cabecera: zx_core::preimage::dag::DagBlockHeader,
    ) -> Result<(), ErrorNodo> {
        let slot_actual = cabecera.slot;
        let (observacion, limite) = self.detector.observar(cabecera);
        if let Some(limite) = limite {
            let evento = self
                .registro
                .evento("limite_alcanzado")
                .str("par", "local")
                .str("limite", "MAX_IDENTIDADES_DETECTOR")
                .str(
                    "detalle",
                    &format!(
                        "desalojada la identidad del slot {} (tope {})",
                        limite.slot_desalojado,
                        perfil::MAX_IDENTIDADES_DETECTOR
                    ),
                );
            self.registro.escribir(evento, false)?;
        }
        if let crate::evidencia::Observacion::Incidente(pendiente) = observacion {
            let zx_core::ExtensionTx::Evidencia { h1, h2 } = &pendiente.tx.extension else {
                return Err(ErrorNodo::Otro(
                    "detector: pendiente sin ExtensionTx::Evidencia".to_string(),
                ));
            };
            let clave = h1.sol.public_key;
            let propia = self.claves.iter().any(|c| c.pk == clave);
            let evento = self
                .registro
                .evento("evidencia_detectada")
                .str(
                    "incident_id",
                    &zx_core::digest::Digest::from_bytes(pendiente.incident_id).to_string(),
                )
                .str(
                    "clave",
                    &zx_core::digest::Digest::from_bytes(*clave.bytes()).to_string(),
                )
                .u64("slot_falta", pendiente.slot_falta)
                .str("hash_1", &h1.block_hash().to_string())
                .str("hash_2", &h2.block_hash().to_string())
                .bool("propia", propia);
            self.registro.escribir(evento, true)?;
        }
        // Poda (decisión 3/EV-11): mismo criterio que el registro del firmante, en cada admisión.
        let evp = perfil::parametros_evidencia_dev();
        self.detector.podar_vistas(slot_actual, evp.plazo_slots);
        self.detector.podar_pendientes(slot_actual, evp.plazo_slots);
        Ok(())
    }

    fn asegurar_servicios_verificacion(&mut self) -> Result<(), ErrorNodo> {
        for terminal in self.cadena.terminal_candidatos() {
            if let std::collections::btree_map::Entry::Vacant(e) =
                self.servicios_verificacion.entry(terminal)
            {
                let servicio = ServicioPot::nuevo(terminal, self.n_dev, 4096).map_err(|err| {
                    ErrorNodo::Otro(format!("ServicioPot de verificación: {err}"))
                })?;
                e.insert(servicio);
            }
        }
        Ok(())
    }

    /// `ORDEN-SL4b2` decisión 0 (paso previo): si `self.cadena.terminal()` (el seleccionado por
    /// FC-3, `ORDEN-W06d7`) ya no es `*terminal` (el que el hilo productor sigue produciendo),
    /// manda al hilo el `ServicioPot` de verificación del nuevo terminal —ya avanzado con toda su
    /// historia admitida, `asegurar_servicios_verificacion` lo garantiza— y actualiza `*terminal`.
    ///
    /// El hilo adopta ese `ServicioPot` como propio (`regimen::MsgBucle::CambiarTerminal`) y elige
    /// sus próximos padres sobre el DAG del terminal nuevo automáticamente: `padres_de_regimen` lee
    /// `self.cadena.contexto_dag()`/`tips_validas()` del terminal **seleccionado**, sin que este
    /// método tenga que tocar nada de la elección de padres.
    ///
    /// Devuelve `true` si se sincronizó un cambio (el llamante no debe contestar con datos del
    /// terminal anterior a la petición del hilo que disparó esta llamada, si la había).
    ///
    /// # Errores
    /// El de [`Self::asegurar_servicios_verificacion`].
    fn sincronizar_terminal_productor(
        &mut self,
        terminal: &mut BlockHash,
        tx_a_productor: &mpsc::Sender<MsgBucle>,
    ) -> Result<bool, ErrorNodo> {
        let Some(actual) = self.cadena.terminal() else {
            return Ok(false);
        };
        if actual == *terminal {
            return Ok(false);
        }
        self.asegurar_servicios_verificacion()?;
        let Some(servicio) = self.servicios_verificacion.get(&actual).cloned() else {
            // No debería ocurrir tras `asegurar_servicios_verificacion`, pero no es motivo para
            // matar el proceso: se reintentará en la próxima vuelta del bucle.
            return Ok(false);
        };
        tracing::info!(
            terminal_anterior = ?*terminal,
            terminal_nuevo = ?actual,
            "fase_regimen: el terminal seleccionado cambió; se sincroniza el hilo productor sin \
             reiniciar el proceso (decisión 0 de ORDEN-SL4b2)"
        );
        *terminal = actual;
        // Si el hilo ya cerró su extremo del canal (apagado en curso), no hay nada que avisar.
        let _ = tx_a_productor.send(MsgBucle::CambiarTerminal(servicio));
        Ok(true)
    }

    /// Terminal único al que resuelven `padres` (réplica, de solo lectura, de
    /// `Cadena::terminal_de_bloque_post`; `ORDEN-W06d7` decisión 5): el nodo necesita saberlo
    /// **antes** de llamar a `Cadena::admitir`, para elegir el `ServicioPot`/contexto de
    /// verificación correctos. `None` si algún padre es desconocido o los padres resuelven a más de
    /// un terminal (en ese caso `Cadena::admitir` lo rechazará con su propio motivo:
    /// `ErrSinPadre`/`ErrTerminalAmbiguo`; aquí basta con no elegir un servicio equivocado).
    fn terminal_de_padres(&self, padres: &[BlockHash]) -> Option<BlockHash> {
        let candidatos = self.cadena.terminal_candidatos();
        let mut terminal_ref: Option<BlockHash> = None;
        for x in padres {
            let t = if candidatos.contains(x) {
                Some(*x)
            } else {
                self.cadena.terminal_de(x)
            };
            let t = t?;
            match terminal_ref {
                None => terminal_ref = Some(t),
                Some(prev) if prev != t => return None,
                Some(_) => {}
            }
        }
        terminal_ref
    }

    /// Reconstruye, si hace falta, `historial_pow` (y `trabajo_acumulado`) desde la punta PoW que
    /// `Cadena::mejor_punta_pow` selecciona ahora (`ORDEN-W06d3` decisión 3). Registra la
    /// profundidad de la reorganización cuando la punta cambia de rama, no solo de altura.
    fn actualizar_seleccion_pow(&mut self) -> Result<(), ErrorNodo> {
        let Some(nueva_punta) = self.cadena.mejor_punta_pow() else {
            return Ok(());
        };
        let punta_anterior = self.historial_pow.last().map(BlockHeader::block_hash);
        if punta_anterior == Some(nueva_punta) {
            return Ok(());
        }
        let historial_anterior = std::mem::take(&mut self.historial_pow);
        let nuevo_historial = self.historial_hasta(nueva_punta);
        let comunes = historial_anterior
            .iter()
            .zip(nuevo_historial.iter())
            .take_while(|(a, b)| a.block_hash() == b.block_hash())
            .count();
        let profundidad = historial_anterior.len().saturating_sub(comunes);
        // `ORDEN-W06d4` decisión 2: ya no hay una lista local de `CoinbasePropia` que podar tras una
        // reorganización (`ORDEN-W06d3` la podaba por `bloque`, pero eso no bastaba: ver el
        // comentario en `admitir_pow_interno`). `preparar_depositos` lee `estado.utxo` de la punta
        // ya seleccionada en cada llamada, así que no hay ningún indicador que desincronizar aquí.
        self.historial_pow = nuevo_historial;
        // `ORDEN-W06d3`, hallazgo en vivo (`PROGRESO.md`): `VistaRed::registrar_pow` es
        // *append-only por altura* y nunca sustituye una altura ya ocupada, aunque la rama
        // seleccionada cambie. Se fija aquí la secuencia completa (siempre desde el génesis) para
        // que el localizador y `cabeceras_desde` que sirven a los pares reflejen exactamente la
        // rama que este nodo tiene por buena, tanto en una extensión simple como en una
        // reorganización.
        self.vista_red.fijar_cabeceras_pow(&self.historial_pow);
        self.trabajo_acumulado = self
            .cadena
            .trabajo_pow(&nueva_punta)
            .unwrap_or_else(U256::zero);
        if profundidad > 0 {
            let evento = self
                .registro
                .evento("reorganizacion_pow")
                .str(
                    "punta_anterior",
                    &punta_anterior.map(|h| h.to_string()).unwrap_or_default(),
                )
                .str("punta_nueva", &nueva_punta.to_string())
                .u64("profundidad", profundidad as u64);
            self.registro.escribir(evento, false)?;
        }
        Ok(())
    }

    /// Reconstruye, desde [`Self::headers_pow`], la cadena de cabeceras `[0..=altura(tip)]` que
    /// termina en `tip`, caminando `prev_hash` hacia atrás hasta el génesis. Vacío si `tip` no se
    /// conoce todavía (huérfano o hash ajeno): el llamante lo trata como "sin padre disponible".
    fn historial_hasta(&self, tip: BlockHash) -> Vec<BlockHeader> {
        let mut inverso = Vec::new();
        let mut actual = tip;
        loop {
            let Some(h) = self.headers_pow.get(&actual) else {
                return Vec::new();
            };
            inverso.push(*h);
            if h.height == 0 {
                break;
            }
            actual = h.prev_hash;
        }
        inverso.reverse();
        inverso
    }

    /// Admite un bloque PoST: tubería única (decisión 4) o repetición (`verificar = false`).
    fn admitir_post_interno(
        &mut self,
        bloque: BloqueDag,
        _indice_registro: u64,
        verificar: bool,
    ) -> Result<(), ErrorNodo> {
        let hash = bloque.cabecera.block_hash();
        // `ORDEN-W06d10-B` (solo tests): fallo local inyectado (ver `admitir_pow_interno`).
        #[cfg(test)]
        if let Some(motivo) = self.fallo_local_simulado.take() {
            return Err(ErrorNodo::Otro(motivo));
        }
        // `ORDEN-W07a`: misma medición por etapas que `admitir_pow_interno`.
        self.medicion = Medicion {
            etapa: "cabecera",
            ..Medicion::default()
        };
        // `ORDEN-W06d7` decisión 1/5: los padres deciden a qué terminal pertenece este bloque —
        // necesario **ya** para elegir el `ServicioPot`/contexto de verificación, antes incluso de
        // llamar a `Cadena::admitir` (que hace la misma resolución internamente, pero después). Se
        // calcula **siempre** (también en la repetición, `verificar = false`): el servicio de ese
        // terminal necesita actualizarse igual al final de la función.
        let padres_declarados = padres_dag_a_vec(&bloque.cabecera.padres);
        let Some(terminal) = self.terminal_de_padres(&padres_declarados) else {
            // Terminal desconocido o ambiguo aquí: no es prueba de invalidez (podría ser un padre
            // que este nodo todavía no admitió, o una ambigüedad real que `Cadena::admitir`
            // rechazará más abajo con su propio motivo, `ErrTerminalAmbiguo`/`ErrSinPadre`); tratarlo
            // como rechazo fatal de un bloque **propio** sería incorrecto para un bloque de **red**
            // que sincroniza fuera de orden (mismo espíritu que `MotivoCabeceraPendiente`,
            // `crate::rechazo`).
            return Err(ErrorNodo::BloquePropioRechazado {
                hash,
                motivo: "terminal_no_resoluble".to_string(),
                clasificacion: crate::rechazo::ClasificacionRechazo::Pendiente,
            });
        };

        if verificar {
            let inicio_cabecera = Instant::now();
            self.asegurar_servicios_verificacion()?;
            let servicio = self.servicios_verificacion.get(&terminal).ok_or_else(|| {
                ErrorNodo::Otro(format!(
                    "verificación PoST sin ServicioPot para el terminal {terminal}"
                ))
            })?;
            let params_pieza: PieceCheckParams = self.historia.params_pieza();
            let mut cache = CachePotVerificada::nueva();
            let mut presupuesto = PresupuestoIlimitado;
            let rango = RangoDev(self.cadena_sr_dev());

            // El primer bloque tras el corte de **cada** terminal (su bloque de transición,
            // decisión 6) se verifica **antes** de que `zx-cadena` tenga ningún bloque PoST propio
            // de ese terminal: `Cadena::contexto_dag_de(terminal)` es `None` hasta la primera
            // admisión (`ORDEN-W06d7` decisión 1: el DAG de un terminal nace con su primer bloque
            // PoST). Para ese único bloque, cuyo único padre posible es `terminal`, no hay
            // ambigüedad de `sp` que temer y se usa `ContextoTransicion` (el mismo contexto dev que
            // `zx-post` define para exactamente este caso). Para todo lo demás, el GHOSTDAG real
            // **de ese terminal** (no necesariamente el seleccionado: varios terminales pueden tener
            // DAG a la vez).
            let estado = match self.cadena.contexto_dag_de(terminal) {
                Some(dag) => verificar_cabecera_conjunta(
                    &bloque,
                    servicio,
                    dag,
                    &rango,
                    u64::MAX,
                    &mut cache,
                    &mut presupuesto,
                    Some(&params_pieza),
                    self.historia.kzg(),
                ),
                None => {
                    let ctx = zx_post::contexto_transicion::ContextoTransicion::nuevo(
                        terminal,
                        self.n_dev,
                        self.sr_dev_actual,
                        Vec::new(),
                    )
                    .map_err(|e| {
                        ErrorNodo::Otro(format!("ContextoTransicion del bloque de transición: {e}"))
                    })?;
                    verificar_cabecera_conjunta(
                        &bloque,
                        servicio,
                        &ctx,
                        &rango,
                        u64::MAX,
                        &mut cache,
                        &mut presupuesto,
                        Some(&params_pieza),
                        self.historia.kzg(),
                    )
                }
            };
            match estado {
                EstadoCabeceraConjunta::Comprobada(_) => {}
                EstadoCabeceraConjunta::Invalida(m) => {
                    return Err(ErrorNodo::BloquePropioRechazado {
                        hash,
                        motivo: format!("{m:?}"),
                        clasificacion: crate::rechazo::clasificar_cabecera_invalida(&m),
                    });
                }
                EstadoCabeceraConjunta::Pendiente(m) => {
                    return Err(ErrorNodo::BloquePropioRechazado {
                        hash,
                        motivo: format!("pendiente: {m:?}"),
                        clasificacion: crate::rechazo::clasificar_cabecera_pendiente(&m),
                    });
                }
            }
            self.medicion.cabecera_ns = inicio_cabecera.elapsed().as_nanos() as u64;
        }

        // `ORDEN-SL4b2` decisión 3: se indexa aquí, **con independencia** de que la admisión que
        // sigue (GHOSTDAG/estado) acabe aceptando o rechazando este bloque (EV-08: la evidencia no
        // exige reconstruir la rama perdedora ni demostrar validez PoAS/PoT/padres en contexto).
        // Corre en la ruta en vivo (`verificar = true`, la puerta ya pasó arriba) y en la
        // repetición al reiniciar (`verificar = false`: todo lo que hay en el almacén ya pasó la
        // puerta en una ejecución anterior), para que el detector reconstruya el mismo estado tras
        // un reinicio. No se llama nunca para una cabecera cuya puerta conjunta falló (decisión 3,
        // último párrafo): ese caso ya salió por el `?`/`return Err` de arriba.
        self.observar_para_detector(bloque.cabecera)?;

        let distancia = zx_poas::verificar_solucion_poas(
            &bloque.cabecera.sol,
            bloque.cabecera.slot,
            bloque.cabecera.pot_output,
            bloque.cabecera.rango_solucion,
            &self.historia.params_pieza(),
            self.historia.kzg(),
        )
        .map_err(|e| ErrorNodo::RepeticionFallida {
            indice: _indice_registro,
            hash,
            motivo: format!("distancia PoAS: {e}"),
        })?;
        // Identidad real de `C-GD-07` (`ORDEN-W06a-C` decisión 2): la tupla literal derivada de la
        // misma cabecera que aporta `block_hash`, `slot` y `SR`. Ya **no** se trunca a un `u64`.
        let identidad = identidad_de_cabecera_post(&bloque.cabecera);
        let padres = padres_declarados;
        let txs: Vec<(Tx, Vec<Vec<u8>>)> = bloque
            .txs()
            .iter()
            .cloned()
            .zip(bloque.testigos().iter().cloned())
            .collect();

        let post = BloquePost {
            hash,
            padres,
            slot: bloque.cabecera.slot,
            productor: bloque.cabecera.sol.public_key,
            peso: peso_u128(&bloque).map_err(|e| ErrorNodo::BloquePropioRechazado {
                hash,
                motivo: e.to_string(),
                // Interno: el peso w(SR) de la solución declarada es del candidato.
                clasificacion: crate::rechazo::ClasificacionRechazo::Interno,
            })?,
            prueba_valida: true,
            requisito_declarado: 0,
            sr: bloque.cabecera.rango_solucion,
            distancia,
            identidad,
            txs,
        };

        let ya_admitido = self.cadena.es_valido(&hash) || self.cadena.motivo(&hash).is_some();
        // `ORDEN-W06d6`, paso previo (RI-3c H1, `REVISION-RI-3c.md`): orden **admitir en
        // `zx-cadena` → persistir → difundir**, igual que `admitir_pow_interno` y por el mismo
        // motivo (ver su comentario). Esto **sustituye** el orden de RI-2b (persistir antes de
        // admitir): RI-2b acertaba en el objetivo —evitar la doble firma de «Relanzamiento» punto
        // 4— y se equivocaba en la forma. Lo que de verdad la evita es que la **difusión** ocurra
        // solo después de persistir (eso no cambia: sigue siendo el llamante, tras que esta función
        // devuelva `Ok`), no que la persistencia sea el primer paso. Con persistir primero, un
        // rechazo legítimo de `cadena.admitir` (`ErrGarantia`, `ErrMergeDepth`... la propia
        // `ORDEN-W06d5` decisión 3 los declara esperables) dejaba una entrada fantasma en el
        // almacén que D-N03′ repite en cada reinicio sin deshacerla — el nodo no volvía a arrancar
        // (RI-3c, confirmado). Con el orden nuevo, un rechazo sale por el `?` de abajo antes de
        // tocar disco. Si el proceso muere entre admitir (memoria) y persistir (disco), el slot
        // sigue sin observarse fuera del nodo (nunca se difundió) y el reinicio no repite nada (no
        // está en el almacén): no hay bloque fantasma que reproduzca el rechazo, y no hay doble
        // firma observable porque no hubo difusión.
        if !ya_admitido {
            self.medicion.etapa = "admision";
            let inicio_admision = Instant::now();
            self.cadena.admitir(BloqueCadena::Post(post)).map_err(|m| {
                ErrorNodo::BloquePropioRechazado {
                    hash,
                    motivo: m.nombre().to_string(),
                    clasificacion: crate::rechazo::clasificar_motivo_bloque(&m),
                }
            })?;
            self.medicion.admision_ns = inicio_admision.elapsed().as_nanos() as u64;
            // `ORDEN-SL4b2` diagnóstico (no forma parte del esquema mínimo v1): igual que el que
            // escribe el productor tras incluir su propia `EvidenceTx` (`nodo.rs`, manejo de
            // `MsgProductor::Post`), pero aquí para **cualquier** bloque admitido por esta única
            // tubería (propio, de red o repetido): así los tres nodos —no solo el que incluyó la
            // evidencia— dejan en su registro `activo`/`congelado` de la clave castigada tras cada
            // aplicación, que es lo que V4 necesita leer "del estado de los tres nodos".
            //
            // `estado_post(&hash)` (el estado **tras este bloque concreto**), no
            // `estado_terminal()`: ese último es `Estado(T)` del terminal PoW-PoST (el corte), no
            // la punta PoST corriente — leerlo aquí habría dado siempre el estado de antes del
            // corte, sin ninguna garantía ni incidente (hallazgo real de la primera ejecución de
            // V4 con procesos reales, `PROGRESO.md`).
            for (incident_id, clave) in bloque.txs().iter().filter_map(|t| match &t.extension {
                zx_core::ExtensionTx::Evidencia { h1, .. } => Some((
                    *zx_core::incident_id_evidencia(
                        h1.consensus_branch_id,
                        h1.sol.public_key.bytes(),
                        h1.sol.sector_index,
                        h1.sol.history_size,
                        &h1.sol.chunk,
                        h1.slot,
                    )
                    .as_bytes(),
                    h1.sol.public_key,
                )),
                _ => None,
            }) {
                let g = self
                    .cadena
                    .estado_post(&hash)
                    .and_then(|estado| estado.garantias.get(&clave));
                let evento = self
                    .registro
                    .evento("garantia_clave_tras_evidencia")
                    .str(
                        "incident_id",
                        &zx_core::digest::Digest::from_bytes(incident_id).to_string(),
                    )
                    .str(
                        "clave",
                        &zx_core::digest::Digest::from_bytes(*clave.bytes()).to_string(),
                    )
                    .i64("activo", g.map_or(0, |g| g.activo.brek()))
                    .i64("congelado", g.map_or(0, |g| g.congelado.brek()));
                self.registro.escribir(evento, false)?;
            }
            // Solo en la ruta en vivo (`verificar`): en la repetición el bloque ya está en el
            // almacén (viene de ahí).
            if verificar {
                let admitido = BloqueAdmitido::post(&bloque);
                self.medicion.etapa = "persistencia";
                let inicio_persistencia = Instant::now();
                self.almacen.admitir(&admitido, true)?;
                self.medicion.persistencia_ns = inicio_persistencia.elapsed().as_nanos() as u64;
            }
            let para_vista = BloqueRed::Post {
                cabecera: bloque.cabecera,
                justificacion: bloque.justificacion.clone(),
                txs: bloque.txs().to_vec(),
                testigos: bloque.testigos().to_vec(),
            };
            self.vista_red.registrar_post(hash, para_vista);
            self.resolver_huerfanos_de(hash);
        }

        // El terminal de `hash` ya se conoce: la admisión de arriba (o, en la repetición, una
        // anterior) lo fijó en `zx-cadena` (`ORDEN-W06d7` decisión 1); `terminal` (resuelto arriba
        // desde los padres declarados) es el mismo valor y sirve de respaldo defensivo.
        let terminal_del_bloque = self.cadena.terminal_de(&hash).unwrap_or(terminal);
        self.actualizar_servicio_verificacion(terminal_del_bloque, &bloque)?;
        self.registrar_cambio_de_punta()?;
        Ok(())
    }

    fn cadena_sr_dev(&self) -> u64 {
        // El `SR_dev` no vive en `Cadena`; el nodo lo trae de la CLI y lo guarda aquí mismo.
        self.sr_dev_actual
    }

    /// Mantiene al día el `ServicioPot` de verificación **de `terminal`** (decisión 7 de
    /// `ORDEN-W06a`; por terminal desde `ORDEN-W06d7` decisión 5): inserta la salida y el portador
    /// **de este bloque**, sin recalcular el PoT. El flujo es único y global dentro de cada terminal
    /// (D-P10), así que si el slot ya estaba cubierto por otra rama/hermano **del mismo terminal**,
    /// solo se comprueba que coincide (defensa; nunca debería discrepar: lo impediría antes
    /// `ContextoTransicion`/H2 en la ruta de producción, pero este servicio de verificación no pasa
    /// por ahí).
    fn actualizar_servicio_verificacion(
        &mut self,
        terminal: BlockHash,
        bloque: &BloqueDag,
    ) -> Result<(), ErrorNodo> {
        let Some(servicio) = self.servicios_verificacion.get_mut(&terminal) else {
            return Err(ErrorNodo::Otro(
                "ServicioPot de verificación ausente tras el terminal".to_string(),
            ));
        };
        let slot = bloque.cabecera.slot;
        let salida = bloque.cabecera.pot_output;
        let bundles = bloque.justificacion.bundles();
        let Some(portador) = bundles.last().copied() else {
            return Err(ErrorNodo::Otro(format!(
                "bloque PoST {} sin portadores en su justificación",
                bloque.cabecera.block_hash()
            )));
        };
        // `ORDEN-W06d9` (causa de origen del `fallo_productor` de W07b): la justificación de un
        // bloque PoST trae, **ya verificados**, los portadores de `(slot(sp), slot]`; su longitud es
        // `slot - slot(sp)` y su i-ésimo portador pertenece al slot `slot - n + 1 + i`. Antes solo se
        // registraba el último (el del propio bloque), así que un bloque que saltaba slots dejaba los
        // intermedios como huecos permanentes —`insertar_calculado` no los rellena y `avanzar` solo
        // avanza hacia delante—, que más tarde `portadores_para` denunciaba como `PortadorAusente` y
        // el hilo productor convertía en `fallo_productor`. Registrar el rango entero, con datos ya
        // verificados, los elimina en el origen.
        if let Ok(n) = u64::try_from(bundles.len())
            && n >= 1
            && n <= slot
            && n <= MAX_BUNDLES_POT as u64
        {
            servicio
                .registrar_portadores(slot - n, slot, bundles)
                .map_err(|e| ErrorNodo::Otro(e.to_string()))?;
        }
        // `ORDEN-W06d4` decisión 3: antes, un slot `<= slot_actual()` se reconciliaba solo con
        // `salida_de`, que exige que el slot **ya tenga** una salida calculada. Si el hueco lo dejó
        // un salto de OTRA rama (`insertar_calculado` los permite a propósito, D-P10), `salida_de`
        // fallaba con `FueraDeVentana` aunque este bloque, ya admitido y verificado, traiga su
        // `pot_output` real — y el bloque se rechazaba sin entrar nunca en `pasado()`: la causa
        // confirmada de `Pot(PasadoIncompleto)` en un hijo que lo declarara padre más tarde
        // (`REVISION-W06d3.md`, hallazgo no resuelto). `declarar_salida_pasada` reconcilia el hueco
        // con el dato ya verificado y sigue detectando una discrepancia real (D-P10) como error.
        if slot <= servicio.slot_actual() {
            servicio
                .declarar_salida_pasada(slot, salida, portador)
                .map_err(|e| ErrorNodo::Otro(e.to_string()))?;
        } else {
            servicio
                .insertar_calculado(slot, salida, portador)
                .map_err(|e| ErrorNodo::Otro(e.to_string()))?;
        }
        let hash = bloque.cabecera.block_hash();
        if servicio.slot_de(&hash).is_none() {
            servicio
                .registrar_validado(hash, slot)
                .map_err(|e| ErrorNodo::Otro(e.to_string()))?;
        }
        Ok(())
    }

    /// Registra en el resumen de estado un cambio de punta seleccionada (decisión 8 y 9), y
    /// republica el saludo de red (`ORDEN-W06d2` decisión 4) tanto si cambió la punta como si no:
    /// la altura PoW/las puntas PoST pueden cambiar sin que la punta *seleccionada* cambie (p. ej.
    /// un huérfano lateral que se resuelve).
    fn registrar_cambio_de_punta(&mut self) -> Result<(), ErrorNodo> {
        self.vista_red
            .actualizar_estado(self.construir_estado_red());

        let punta_actual = self.cadena.mejor_punta().or(self.cadena.terminal());
        if punta_actual == self.ultima_punta_registrada {
            return Ok(());
        }
        self.ultima_punta_registrada = punta_actual;
        let estado = self
            .cadena
            .estado_virtual()
            .map_err(|m| ErrorNodo::Otro(format!("estado virtual: {m}")))?;
        let resumen = resumen_estado(&estado);
        // `ORDEN-W07a` decisión 4: profundidad de reorganización = bloques de la cadena
        // seleccionada anterior que no están en la nueva (0 si solo la extiende).
        let profundidad_reorg = punta_actual
            .map(|p| self.actualizar_cadena_seleccionada(p))
            .unwrap_or(0);

        let mut evento = self
            .registro
            .evento("cambio_punta")
            .str(
                "punta",
                &punta_actual.map(|h| h.to_string()).unwrap_or_default(),
            )
            .str("resumen_estado", &resumen)
            .u64("profundidad_reorg", profundidad_reorg);
        // `blue_score` solo existe para bloques del DAG (PoST); en fase PoW se omite (§0).
        if let Some(blue_score) = punta_actual.and_then(|h| self.cadena.blue_score(&h)) {
            evento = evento.u64("blue_score", blue_score);
        }
        self.registro.escribir(evento, false)?;
        Ok(())
    }

    /// Actualiza la cadena seleccionada a la que termina en `punta` y devuelve `profundidad_reorg`
    /// (bloques de la anterior que no están en la nueva). Usa solo lo que `zx-cadena` ya expone
    /// (`padre_seleccionado`) y recorre únicamente el tramo nuevo: una extensión es un solo paso.
    fn actualizar_cadena_seleccionada(&mut self, punta: BlockHash) -> u64 {
        // Fase PoW pura (sin DAG): la cadena seleccionada es `historial_pow`, lineal.
        if self.cadena.mejor_punta().is_none() {
            let nueva: Vec<BlockHash> = self
                .historial_pow
                .iter()
                .map(BlockHeader::block_hash)
                .collect();
            let comunes = self
                .ultima_cadena_seleccionada
                .iter()
                .zip(nueva.iter())
                .take_while(|(a, b)| a == b)
                .count();
            let profundidad = self
                .ultima_cadena_seleccionada
                .len()
                .saturating_sub(comunes) as u64;
            self.reemplazar_cadena_seleccionada(&nueva);
            return profundidad;
        }

        // Fase PoST: sube por `sp` desde la punta nueva hasta el primer bloque ya presente.
        let mut sufijo_nuevo = Vec::new();
        let mut actual = Some(punta);
        let mut comun = None;
        while let Some(h) = actual {
            if let Some(&i) = self.ultima_cadena_indice.get(&h) {
                comun = Some(i);
                break;
            }
            sufijo_nuevo.push(h);
            actual = self.cadena.padre_seleccionado(&h);
        }
        let profundidad = match comun {
            Some(i) => self.ultima_cadena_seleccionada.len().saturating_sub(1 + i) as u64,
            None => self.ultima_cadena_seleccionada.len() as u64,
        };
        let descartados: Vec<BlockHash> = match comun {
            Some(i) => self.ultima_cadena_seleccionada.split_off(i + 1),
            None => std::mem::take(&mut self.ultima_cadena_seleccionada),
        };
        for h in descartados {
            self.ultima_cadena_indice.remove(&h);
        }
        sufijo_nuevo.reverse();
        for h in sufijo_nuevo {
            self.ultima_cadena_indice
                .insert(h, self.ultima_cadena_seleccionada.len());
            self.ultima_cadena_seleccionada.push(h);
        }
        profundidad
    }

    /// Reemplaza la cadena seleccionada entera (fase PoW, historia lineal).
    fn reemplazar_cadena_seleccionada(&mut self, nueva: &[BlockHash]) {
        self.ultima_cadena_seleccionada.clear();
        self.ultima_cadena_indice.clear();
        for (i, h) in nueva.iter().enumerate() {
            self.ultima_cadena_seleccionada.push(*h);
            self.ultima_cadena_indice.insert(*h, i);
        }
    }

    /// Construye el saludo de red actual (`ORDEN-W06d2` decisión 4) a partir del estado propio.
    ///
    /// `blue_work_virtual` queda en cero: 0.0.1 no elige *fork choice* PoST por red (el bloqueo de
    /// `PROGRESO.md` sobre `JustificacionPot` impide verificar un PoST ajeno), así que ningún par
    /// decide todavía nada a partir de este campo. Se deja el tipo correcto para no romper el wire
    /// el día que se resuelva.
    fn construir_estado_red(&self) -> Estado {
        #[expect(
            clippy::indexing_slicing,
            reason = "historial_pow siempre tiene al menos el génesis"
        )]
        let ultimo = self.historial_pow[self.historial_pow.len() - 1];
        let trabajo_be = self.trabajo_acumulado.to_big_endian();
        let mut puntas_post = self.cadena.tips_validas();
        puntas_post.truncate(zx_p2p::mensaje::MAX_PUNTAS_POST);
        Estado {
            hash_genesis: self.hash_genesis,
            red: self.red_configurada,
            fase: if self.cadena.terminal().is_some() {
                FaseRed::Post
            } else {
                FaseRed::Pow
            },
            punta_pow: PuntaPow {
                hash: ultimo.block_hash(),
                altura: ultimo.height,
                trabajo_acumulado: trabajo_be,
            },
            terminal: self.cadena.terminal(),
            puntas_post,
            blue_work_virtual: [0; 32],
            // `ORDEN-W06d6` decisión 1: longitud real del registro de admisión de la vista, no un
            // relleno — es lo que el par sincronizando compara contra su propio cursor.
            longitud_registro: self.vista_red.longitud_registro(),
        }
    }

    /// Difunde un bloque **propio** ya admitido, si hay red (decisión 2: solo **después** de
    /// persistirse, que ya ocurrió dentro de `admitir_pow_interno`/`admitir_post_interno` antes de
    /// que esta función pueda llamarse con su hash). Se relee de [`VistaRed`] en vez de repetir la
    /// construcción del `BloqueRed`: es el mismo valor exacto que ya se guardó allí al admitir.
    fn difundir_si_hay_red(&self, hash: BlockHash) {
        let Some(red) = self.red.as_ref() else {
            return;
        };
        let Some(bloque) = self.vista_red.bloques_por_hash(&[hash]).into_iter().next() else {
            tracing::error!(%hash, "bloque propio recién admitido sin instantánea en VistaRed");
            return;
        };
        if let Err(e) = red.difundir_bloque(&bloque) {
            tracing::warn!(%hash, %e, "no se pudo difundir un bloque propio");
        }
    }

    /// Reintenta contra la tubería de admisión cualquier huérfano que estuviera esperando a
    /// `padre`, ahora que `padre` se acaba de admitir (decisión 3). Recursivo por construcción: si
    /// un huérfano se admite, `admitir_*_interno` vuelve a llamar a esto con su propio hash.
    ///
    /// Sin par de origen (`None`): no se sabe quién mandó el huérfano originalmente (el depósito no
    /// guarda esa procedencia, límite documentado en `PROGRESO.md`), así que si a su vez le falta
    /// otro padre, ese nuevo padre se deposita **sin** disparar una petición dirigida; queda para el
    /// siguiente ciclo de `sync` basado en el saludo.
    fn resolver_huerfanos_de(&mut self, padre: BlockHash) {
        for (hijo, bloque) in self.huerfanos.tomar_para_padre(&padre) {
            let _ = self.intentar_admitir_bloque_red(&bloque, None, Instant::now());
            // Sin `IdDiferido` que informar (no llegó por gossipsub en este turno): el único rastro
            // es el registro. La retransmisión de un huérfano que ahora prospera queda pendiente
            // (límite conocido, ver `PROGRESO.md`): difundirlo exigiría reconstruir un `IdDiferido`
            // que no existe para un bloque que nunca pasó por `report_message_validation_result`.
            let evento = self
                .registro
                .evento("huerfano_resuelto")
                .str("hash", &hijo.to_string());
            let _ = self.registro.escribir(evento, false);
        }
    }

    /// Drena, sin bloquear, el trabajo que el manejador de red encoló (decisión 1). Se llama desde
    /// los bucles de `fase_pow`/`fase_regimen`: el hilo de consenso es el único que muta
    /// `zx-cadena`/`zx-storage` (D-N07), así que la admisión de red ocurre aquí, intercalada con la
    /// propia producción, nunca en el hilo asíncrono de `zx-p2p`.
    fn procesar_trabajo_red_pendiente(&mut self) {
        // Se saca el receptor de `self` temporalmente: `intentar_admitir_bloque_red` necesita
        // `&mut self` completo (muta `cadena`, `almacen`, `huerfanos`...) y el propio receptor vive
        // dentro de `self.trabajo_red`, así que no se puede tomar prestado a la vez.
        let Some(mut receptor) = self.trabajo_red.take() else {
            return;
        };
        loop {
            let trabajo = match receptor.try_recv() {
                Ok(t) => t,
                Err(tokio::sync::mpsc::error::TryRecvError::Empty) => break,
                Err(tokio::sync::mpsc::error::TryRecvError::Disconnected) => return,
            };
            match trabajo {
                TrabajoRed::BloqueDifundido {
                    id,
                    bloque,
                    llegada,
                } => {
                    // Gossipsub no dice quién lo propagó a este nivel (`ManejadorEntrante` no lo
                    // expone); si resulta huérfano, no hay a quién pedirle el padre directamente.
                    self.registrar_bloque_recibido(&bloque, None);
                    let veredicto = self.intentar_admitir_bloque_red(&bloque, None, llegada);
                    if let Some(red) = self.red.as_ref() {
                        red.informar_validacion(id, veredicto);
                    }
                }
                TrabajoRed::BloqueDeSincronizacion {
                    de,
                    bloque,
                    llegada,
                } => {
                    self.registrar_bloque_recibido(&bloque, Some(de));
                    let veredicto = self.intentar_admitir_bloque_red(&bloque, Some(de), llegada);
                    // Un bloque de sincronización demostrablemente inválido sí penaliza: no pasó
                    // por gossipsub (no hay `report_message_validation_result` que llame a esto),
                    // así que la única forma de aplicar C-NET-05/C-EVP es desconectar aquí.
                    if veredicto == VeredictoFinal::Rechazar
                        && let Some(red) = self.red.as_ref()
                    {
                        // `ORDEN-W07a`: única penalización que el nodo decide y puede trazar (la de
                        // gossipsub la aplica `zx-p2p` sin exponer el propagador a `zx-node`).
                        let evento = self
                            .registro
                            .evento("par_penalizado")
                            .str("par", &de.to_string())
                            .str("motivo", "bloque de sincronización rechazado")
                            .str("accion", "expulsion");
                        let _ = self.registro.escribir(evento, false);
                        red.desconectar(de, zx_p2p::error::MotivoDesconexion::ViolacionDeConsenso);
                    }
                }
            }
        }
        self.trabajo_red = Some(receptor);
    }

    /// `ORDEN-W07a` §1: `bloque_recibido`, la primera traza de un bloque llegado por red, **antes**
    /// de verificar nada. `par` se omite en gossip (el propagador no es computable en `zx-node`);
    /// se escribe para bloques de sincronización.
    fn registrar_bloque_recibido(&self, bloque: &BloqueRed, origen: Option<libp2p::PeerId>) {
        let mut evento = self
            .registro
            .evento("bloque_recibido")
            .str("hash", &red::hash_de(bloque).to_string())
            .str("familia", familia_de(bloque))
            .u64("bytes", bytes_de(bloque));
        if let Some(par) = origen {
            evento = evento.str("par", &par.to_string());
        }
        let _ = self.registro.escribir(evento, false);
    }

    /// Decide y aplica el veredicto de un bloque llegado por red (gossip o sincronización), sin
    /// propagar nunca un error fatal: a diferencia de un bloque **propio** (decisión 4 general de
    /// `ORDEN-W06d1`), un bloque ajeno inválido es un evento normal de la red, no un bug del nodo.
    ///
    /// `origen`: el par que lo mandó, si se conoce (sincronización) — se usa **solo** para pedirle
    /// directamente un padre que falte; nunca para decidir el veredicto del propio bloque.
    fn intentar_admitir_bloque_red(
        &mut self,
        bloque: &BloqueRed,
        origen: Option<libp2p::PeerId>,
        llegada: Instant,
    ) -> VeredictoFinal {
        match bloque {
            BloqueRed::Pow {
                cabecera,
                txs,
                testigos,
            } => self.intentar_admitir_pow_de_red(
                *cabecera,
                txs.clone(),
                testigos.clone(),
                origen,
                llegada,
            ),
            BloqueRed::Post {
                cabecera,
                justificacion,
                txs,
                testigos,
            } => self.intentar_admitir_post_de_red(
                *cabecera,
                justificacion.clone(),
                txs.clone(),
                testigos.clone(),
                origen,
                llegada,
            ),
        }
    }

    fn intentar_admitir_pow_de_red(
        &mut self,
        cabecera: BlockHeader,
        txs: Vec<Tx>,
        testigos: Vec<Vec<Vec<u8>>>,
        origen: Option<libp2p::PeerId>,
        llegada: Instant,
    ) -> VeredictoFinal {
        let hash = cabecera.block_hash();
        if self.cadena.es_valido(&hash) {
            return VeredictoFinal::Ignorar; // ya lo teníamos: nada que hacer, no penaliza.
        }
        if let Some(motivo) = self.cadena.motivo(&hash) {
            // `ORDEN-W06d10-B`: un motivo cacheado que depende de la vista local (X2,
            // `ErrLimiteTerminales`) no se convierte en `Rechazar`. Se ignora sin penalizar y se
            // traza; un motivo demostrable del candidato sigue penalizando igual.
            if !crate::rechazo::clasificar_motivo_bloque(motivo).penaliza_en_red() {
                self.trazar_bloque_vista_local(
                    &hash,
                    "pow",
                    &format!("motivo cacheado no penalizable: {motivo}"),
                    llegada,
                );
                return VeredictoFinal::Ignorar;
            }
            return VeredictoFinal::Rechazar; // ya sabíamos que es inválido.
        }
        if cabecera.height == 0 {
            // Un génesis declarado por red nunca sustituye al nuestro (ya comprobado contra
            // `HASH_GENESIS_DEV` al arrancar): no es demostrablemente inválido en sí mismo (podría
            // ser el génesis real, coincidiendo), así que no penaliza.
            return VeredictoFinal::Ignorar;
        }

        let padre = cabecera.prev_hash;
        let padre_conocido = self.cadena.es_valido(&padre) || self.cadena.motivo(&padre).is_some();
        if !padre_conocido {
            let bloque = BloqueRed::Pow {
                cabecera,
                txs,
                testigos,
            };
            let hijo = red::hash_de(&bloque);
            for d in self.huerfanos.insertar(padre, hijo, bloque) {
                let evento = self
                    .registro
                    .evento("huerfano_desalojado")
                    .str("hash", &d.hijo.to_string())
                    .str("motivo", "desalojado por cupo del depósito de huérfanos");
                let _ = self.registro.escribir(evento, false);
            }
            let mut evento = self
                .registro
                .evento("bloque_red_huerfano")
                .str("hash", &hash.to_string())
                .str("familia", "pow")
                .lista_str("padres_ausentes", &[padre.to_string()]);
            if let Some(par) = origen {
                evento = evento.str("par", &par.to_string());
            }
            let _ = self.registro.escribir(evento, false);
            if let (Some(red), Some(peer)) = (self.red.as_ref(), origen) {
                red.pedir(
                    peer,
                    zx_p2p::mensaje::Peticion::Bloques {
                        hashes: vec![padre],
                    },
                );
            }
            return VeredictoFinal::Ignorar;
        }
        if !self.cadena.es_valido(&padre) {
            // `ORDEN-W06d10-B` decisión 4: si el motivo cacheado del padre depende de **nuestra**
            // vista local (X2), el hijo no es demostrablemente inválido — hereda una invalidación
            // que otro nodo con otra rama lateral no haría. Se ignora sin penalizar.
            if self
                .cadena
                .motivo(&padre)
                .is_some_and(|m| !crate::rechazo::clasificar_motivo_bloque(m).penaliza_en_red())
            {
                self.trazar_bloque_vista_local(
                    &hash,
                    "pow",
                    "padre conocido con motivo de vista local",
                    llegada,
                );
                return VeredictoFinal::Ignorar;
            }
            // El padre es conocido y definitivamente inválido: este bloque no puede ser válido.
            let mut evento = self
                .registro
                .evento("bloque_red_rechazado")
                .str("hash", &hash.to_string())
                .str("familia", "pow")
                .str("etapa", "admision")
                .str("motivo", "padre conocido e inválido")
                .u64("t_hasta_rechazo_ns", llegada.elapsed().as_nanos() as u64);
            if let Some(par) = origen {
                evento = evento.str("par", &par.to_string());
            }
            let _ = self.registro.escribir(evento, false);
            return VeredictoFinal::Rechazar;
        }
        // `ORDEN-W06d3` decisión 3: ya no se exige que el padre sea `historial_pow.last()`.
        // `admitir_pow_interno` calcula el contexto de validación (target, altura, timestamp) a
        // partir del padre **declarado** (`Self::historial_hasta`), así que un bloque que extiende
        // un padre admitido y válido que no es la punta actual es una bifurcación PoW real y se
        // admite con su propio contexto correcto, nunca con el de otra rama. Si tras admitirlo
        // resulta ser la rama más pesada, `Self::actualizar_seleccion_pow` conmuta la punta
        // seleccionada (con la profundidad de la reorganización registrada).
        let indice = self.almacen.longitud_registro().unwrap_or(0);
        // `ORDEN-W07a`: `bytes` (tamaño de la serialización de red) y `altura` se capturan antes de
        // que `cabecera`/`txs`/`testigos` se muevan a la tubería de admisión.
        let altura = cabecera.height;
        let bytes = zx_p2p::codec::bloque_a_bytes(&BloqueRed::Pow {
            cabecera,
            txs: txs.clone(),
            testigos: testigos.clone(),
        })
        .len() as u64;
        match self.admitir_pow_interno(cabecera, txs, testigos, indice, true) {
            Ok(()) => {
                // V9: este evento **solo** se escribe después de que `admitir_pow_interno` terminó
                // la tubería completa (cabecera, PoW, motor de transición, persistencia): nunca
                // antes. Es la traza que V9 exige comprobar.
                let mut evento = self
                    .registro
                    .evento("bloque_red_admitido")
                    .str("hash", &hash.to_string())
                    .str("familia", "pow")
                    .u64("altura", u64::from(altura))
                    .u64("bytes", bytes)
                    .u64("t_cabecera_ns", self.medicion.cabecera_ns)
                    .u64("t_admision_ns", self.medicion.admision_ns)
                    .u64("t_persistencia_ns", self.medicion.persistencia_ns)
                    .u64("t_total_ns", llegada.elapsed().as_nanos() as u64)
                    .u64("n_bloques_dag", self.cadena.bloques_admitidos());
                if let Some(par) = origen {
                    evento = evento.str("par", &par.to_string());
                }
                let _ = self.registro.escribir(evento, false);
                VeredictoFinal::Aceptar
            }
            Err(e) => {
                // `ORDEN-W06d10-B`: solo un defecto **atribuible al candidato** penaliza. Un fallo
                // local (X3: persistencia/servicio) o una clasificación de vista local (X1) se
                // ignoran sin penalizar y se trazan con su motivo.
                if !error_atribuible_al_candidato(&e) {
                    self.trazar_bloque_vista_local(&hash, "pow", &e.to_string(), llegada);
                    return VeredictoFinal::Ignorar;
                }
                let mut evento = self
                    .registro
                    .evento("bloque_red_rechazado")
                    .str("hash", &hash.to_string())
                    .str("familia", "pow")
                    .str("etapa", self.medicion.etapa)
                    .str("motivo", &e.to_string())
                    .u64("t_hasta_rechazo_ns", llegada.elapsed().as_nanos() as u64);
                if let Some(par) = origen {
                    evento = evento.str("par", &par.to_string());
                }
                let _ = self.registro.escribir(evento, false);
                VeredictoFinal::Rechazar
            }
        }
    }

    /// `ORDEN-W06d10-B` §1 bis: traza de diagnóstico de un bloque de red **ignorado** porque su
    /// aparente invalidez depende de la vista local (X1/X2/X3) o porque el fallo es local. No es un
    /// rechazo (no penaliza, no desconecta) pero queda visible con su motivo. `&self` para poder
    /// llamarse mientras un motivo de `self.cadena` sigue prestado.
    fn trazar_bloque_vista_local(
        &self,
        hash: &BlockHash,
        familia: &str,
        motivo: &str,
        llegada: Instant,
    ) {
        let evento = self
            .registro
            .evento("bloque_red_vista_local")
            .str("hash", &hash.to_string())
            .str("familia", familia)
            .str("etapa", self.medicion.etapa)
            .str("motivo", motivo)
            .str("veredicto", "Ignorar")
            .u64("t_hasta_ignorar_ns", llegada.elapsed().as_nanos() as u64);
        let _ = self.registro.escribir(evento, false);
    }

    /// Decide y aplica el veredicto de un bloque PoST llegado por red (`ORDEN-W06d3` decisión 2).
    ///
    /// Con `BloqueRed::Post` llevando ya `JustificacionPot` (decisión 1), la tubería única
    /// (`Self::admitir_post_interno`, `verificar = true`) puede verificar de verdad la cabecera
    /// conjunta (PoT, PoAS, sello) y los padres de un bloque ajeno. Antes de eso: si no hay terminal
    /// todavía, el bloque no es juzgable (`Ignorar`, la falta es de fase, no del par); si algún padre
    /// declarado (salvo el terminal, que siempre vale como padre del bloque de transición) no se
    /// conoce, se deposita como huérfano y se pide, igual que en la ruta PoW.
    fn intentar_admitir_post_de_red(
        &mut self,
        cabecera: zx_core::preimage::dag::DagBlockHeader,
        justificacion: zx_core::wire_dag::JustificacionPot,
        txs: Vec<Tx>,
        testigos: Vec<Vec<Vec<u8>>>,
        origen: Option<libp2p::PeerId>,
        llegada: Instant,
    ) -> VeredictoFinal {
        let hash = cabecera.block_hash();
        if self.cadena.es_valido(&hash) {
            return VeredictoFinal::Ignorar; // ya lo teníamos: nada que hacer, no penaliza.
        }
        if let Some(motivo) = self.cadena.motivo(&hash) {
            // `ORDEN-W06d10-B`: X2 (`ErrLimiteTerminales`) cacheado no se reconvierte en `Rechazar`;
            // se ignora sin penalizar. Un motivo demostrable del candidato sigue igual.
            if !crate::rechazo::clasificar_motivo_bloque(motivo).penaliza_en_red() {
                self.trazar_bloque_vista_local(
                    &hash,
                    "post",
                    &format!("motivo cacheado no penalizable: {motivo}"),
                    llegada,
                );
                return VeredictoFinal::Ignorar;
            }
            return VeredictoFinal::Rechazar; // ya sabíamos que es inválido.
        }
        // `ORDEN-W06d7`: ya no hace falta un único terminal seleccionado para juzgar un bloque PoST
        // de red — puede declarar como padre **cualquier** terminal candidato conocido (el suyo, no
        // necesariamente el que este nodo tiene seleccionado hoy). Sin ningún candidato todavía
        // (fase PoW pura), no hay `ServicioPot` ni GHOSTDAG con los que verificar nada: no es
        // demostrablemente inválido (podríamos cruzar el corte nosotros mismos en breve),
        // `Ignorar`, no `Rechazar`.
        if self.cadena.terminal_candidatos().is_empty() {
            let evento = self
                .registro
                .evento("bloque_post_de_red_sin_terminal")
                .str("hash", &hash.to_string());
            let _ = self.registro.escribir(evento, false);
            return VeredictoFinal::Ignorar;
        }
        let candidatos = self.cadena.terminal_candidatos();

        let bloque_red = BloqueRed::Post {
            cabecera,
            justificacion: justificacion.clone(),
            txs: txs.clone(),
            testigos: testigos.clone(),
        };
        for padre in red::padres_declarados(&bloque_red) {
            if candidatos.contains(&padre) {
                continue; // cualquier terminal candidato conocido es un padre válido y conocido.
            }
            let padre_conocido =
                self.cadena.es_valido(&padre) || self.cadena.motivo(&padre).is_some();
            if !padre_conocido {
                // `ORDEN-W06d6` decisión 1: mientras este nodo va muy por detrás de algún par
                // conocido (`VistaRed::sincronizando`), un huérfano PoST llegado por **gossip**
                // (`origen.is_none()`: no sabemos de quién pedir el padre directamente) no se
                // deposita — la sincronización por registro lo traerá en su momento, en orden
                // causal, sin que este nodo tenga que resolver huérfanos de uno en uno mientras la
                // red sigue produciendo (la causa raíz de V5/V6(b), `REVISION-W06d5.md`). Un
                // huérfano de **sincronización** (`origen.is_some()`, llegó como respuesta a una
                // petición nuestra) sigue depositándose igual: es la resolución por padres para los
                // huecos pequeños que la propia decisión 1 conserva.
                if origen.is_none() && self.vista_red.sincronizando() {
                    let evento = self
                        .registro
                        .evento("bloque_post_gossip_descartado_sincronizando")
                        .str("hash", &hash.to_string())
                        .str("padre_ausente", &padre.to_string());
                    let _ = self.registro.escribir(evento, false);
                    return VeredictoFinal::Ignorar;
                }
                for d in self.huerfanos.insertar(padre, hash, bloque_red) {
                    let evento = self
                        .registro
                        .evento("huerfano_desalojado")
                        .str("hash", &d.hijo.to_string())
                        .str("motivo", "desalojado por cupo del depósito de huérfanos");
                    let _ = self.registro.escribir(evento, false);
                }
                let mut evento = self
                    .registro
                    .evento("bloque_red_huerfano")
                    .str("hash", &hash.to_string())
                    .str("familia", "post")
                    .lista_str("padres_ausentes", &[padre.to_string()]);
                if let Some(par) = origen {
                    evento = evento.str("par", &par.to_string());
                }
                let _ = self.registro.escribir(evento, false);
                if let (Some(red), Some(peer)) = (self.red.as_ref(), origen) {
                    red.pedir(
                        peer,
                        zx_p2p::mensaje::Peticion::Bloques {
                            hashes: vec![padre],
                        },
                    );
                }
                return VeredictoFinal::Ignorar;
            }
            if !self.cadena.es_valido(&padre) {
                // `ORDEN-W06d10-B` decisión 4: si el motivo cacheado del padre depende de nuestra
                // vista local (X2), el hijo no es demostrablemente inválido. `Ignorar` sin penalizar.
                if self
                    .cadena
                    .motivo(&padre)
                    .is_some_and(|m| !crate::rechazo::clasificar_motivo_bloque(m).penaliza_en_red())
                {
                    self.trazar_bloque_vista_local(
                        &hash,
                        "post",
                        "padre conocido con motivo de vista local",
                        llegada,
                    );
                    return VeredictoFinal::Ignorar;
                }
                let mut evento = self
                    .registro
                    .evento("bloque_red_rechazado")
                    .str("hash", &hash.to_string())
                    .str("familia", "post")
                    .str("etapa", "admision")
                    .str("motivo", "padre conocido e inválido")
                    .u64("t_hasta_rechazo_ns", llegada.elapsed().as_nanos() as u64);
                if let Some(par) = origen {
                    evento = evento.str("par", &par.to_string());
                }
                let _ = self.registro.escribir(evento, false);
                return VeredictoFinal::Rechazar;
            }
        }

        let bloque_dag = match BloqueDag::nuevo(cabecera, justificacion, txs, testigos) {
            Ok(b) => b,
            Err(e) => {
                let mut evento = self
                    .registro
                    .evento("bloque_red_rechazado")
                    .str("hash", &hash.to_string())
                    .str("familia", "post")
                    .str("etapa", "decodificacion")
                    .str("motivo", &format!("forma: {e}"))
                    .u64("t_hasta_rechazo_ns", llegada.elapsed().as_nanos() as u64);
                if let Some(par) = origen {
                    evento = evento.str("par", &par.to_string());
                }
                let _ = self.registro.escribir(evento, false);
                return VeredictoFinal::Rechazar;
            }
        };
        let indice = self.almacen.longitud_registro().unwrap_or(0);
        // `ORDEN-W07a`: tamaño de red y nº de padres del bloque, antes de admitirlo.
        let n_padres = red::padres_declarados(&bloque_red).len() as u64;
        let bytes = zx_p2p::codec::bloque_a_bytes(&bloque_red).len() as u64;
        // Aviso del director (`ORDEN-W06d5`, tras el hallazgo de V5): la simplificación que
        // trataba `Invalida` y `Pendiente` como el mismo `Rechazar` (declarada en `W06d4`) es un
        // bug real, no solo una simplificación — el mismo riesgo que RI-2a. `Pot(PasadoIncompleto)`
        // es un hueco **local** del `ServicioPot` de verificación (un nodo que sincroniza fuera de
        // orden), no un defecto demostrado del candidato: cachearlo como inválido lo perdería para
        // siempre, y `Rechazar` penaliza (incluso desconecta, `TrabajoRed::BloqueDeSincronizacion`
        // más abajo) a un par honesto por nuestro propio retraso. Ahora se usa la clasificación
        // tipada (`crate::rechazo`, decisión 3): `Pendiente` ⇒ `Ignorar` + se reencola para
        // reintentar cuando el pasado avance (`Self::reintentar_post_pendientes`); el resto, igual
        // que antes.
        let bloque_para_reintento = bloque_dag.clone();
        match self.admitir_post_interno(bloque_dag, indice, true) {
            Ok(()) => {
                // V9: este evento **solo** se escribe después de que `admitir_post_interno` terminó
                // la tubería completa (cabecera conjunta, PoAS, motor de transición, persistencia):
                // nunca antes.
                let mut evento = self
                    .registro
                    .evento("bloque_red_admitido")
                    .str("hash", &hash.to_string())
                    .str("familia", "post")
                    .u64("slot", bloque_para_reintento.cabecera.slot)
                    .u64("n_padres", n_padres)
                    .u64("bytes", bytes)
                    .u64("t_cabecera_ns", self.medicion.cabecera_ns)
                    .u64("t_admision_ns", self.medicion.admision_ns)
                    .u64("t_persistencia_ns", self.medicion.persistencia_ns)
                    .u64("t_total_ns", llegada.elapsed().as_nanos() as u64)
                    .u64("n_bloques_dag", self.cadena.bloques_admitidos());
                if let Some((azules, rojos)) = self.cadena.mergeset_de(&hash) {
                    evento = evento
                        .u64("azules_mergeset", azules)
                        .u64("rojos_mergeset", rojos);
                }
                let txs_descartadas = self.cadena.descartes(&hash).map_or(0, |d| d.len() as u64);
                evento = evento.u64("txs_descartadas", txs_descartadas);
                if let Some(par) = origen {
                    evento = evento.str("par", &par.to_string());
                }
                let _ = self.registro.escribir(evento, false);
                self.reintentar_post_pendientes();
                VeredictoFinal::Aceptar
            }
            Err(ErrorNodo::BloquePropioRechazado {
                motivo,
                clasificacion,
                ..
            }) if clasificacion.es_pendiente() => {
                // `ORDEN-W07a` §1 bis: evento de diagnóstico restaurado (el bloque no es rechazo
                // demostrable ni huérfano de un padre concreto; se reintenta más tarde).
                let evento = self
                    .registro
                    .evento("bloque_red_pendiente")
                    .str("hash", &hash.to_string())
                    .str("familia", "post")
                    .str("motivo", &motivo)
                    .str("veredicto", "Ignorar (reintento encolado)");
                let _ = self.registro.escribir(evento, false);
                self.encolar_post_pendiente(bloque_para_reintento, llegada);
                VeredictoFinal::Ignorar
            }
            // `ORDEN-W06d10-B` X2: `ErrLimiteTerminales` (tope local de terminales) llega aquí ya
            // clasificado como `VistaLocal`. No se penaliza, no se desconecta y queda visible con su
            // motivo en el evento de diagnóstico `bloque_red_vista_local`.
            Err(ErrorNodo::BloquePropioRechazado {
                motivo,
                clasificacion,
                ..
            }) if clasificacion.es_vista_local() => {
                self.trazar_bloque_vista_local(&hash, "post", &motivo, llegada);
                VeredictoFinal::Ignorar
            }
            // `ORDEN-W06d6`, RI-3c H2: `PruebaPotIncoherente`/`RangoSinAtadura` no se reintentan
            // (a diferencia de `Pendiente`, el hueco no se va a llenar solo) pero tampoco penalizan
            // al remitente (a diferencia del resto de rechazos): no hay certeza de que el defecto
            // sea suyo y no nuestro. `VeredictoFinal::Ignorar` es exactamente "se descarta sin
            // penalizar".
            Err(ErrorNodo::BloquePropioRechazado {
                motivo,
                clasificacion,
                ..
            }) if !clasificacion.penaliza_en_red() => {
                // `ORDEN-W07a` §1 bis: se conserva el evento de diagnóstico original.
                let evento = self
                    .registro
                    .evento("bloque_red_ignorado_sin_penalizar")
                    .str("hash", &hash.to_string())
                    .str("familia", "post")
                    .str("motivo", &motivo);
                let _ = self.registro.escribir(evento, false);
                // Y el bloque queda descartado, con su traza de rechazo del §1 (etapa `cabecera`).
                let mut evento = self
                    .registro
                    .evento("bloque_red_rechazado")
                    .str("hash", &hash.to_string())
                    .str("familia", "post")
                    .str("etapa", self.medicion.etapa)
                    .str("motivo", &motivo)
                    .u64("t_hasta_rechazo_ns", llegada.elapsed().as_nanos() as u64);
                if let Some(par) = origen {
                    evento = evento.str("par", &par.to_string());
                }
                let _ = self.registro.escribir(evento, false);
                VeredictoFinal::Ignorar
            }
            Err(e) => {
                // `ORDEN-W06d10-B`: un fallo local (X3) se ignora sin penalizar y se traza; solo un
                // defecto atribuible al candidato (p. ej. PoAS inválido, `RepeticionFallida`) sigue
                // siendo `Rechazar`.
                if !error_atribuible_al_candidato(&e) {
                    self.trazar_bloque_vista_local(&hash, "post", &e.to_string(), llegada);
                    return VeredictoFinal::Ignorar;
                }
                let mut evento = self
                    .registro
                    .evento("bloque_red_rechazado")
                    .str("hash", &hash.to_string())
                    .str("familia", "post")
                    .str("etapa", self.medicion.etapa)
                    .str("motivo", &e.to_string())
                    .u64("t_hasta_rechazo_ns", llegada.elapsed().as_nanos() as u64);
                if let Some(par) = origen {
                    evento = evento.str("par", &par.to_string());
                }
                let _ = self.registro.escribir(evento, false);
                VeredictoFinal::Rechazar
            }
        }
    }

    /// Encola un bloque PoST de red que quedó `Pendiente` (decisión 3 extendida): acotado, el más
    /// viejo se descarta si se supera [`TOPE_POST_PENDIENTES`] — es una cola de mejor esfuerzo, no
    /// una promesa de reintento infinito.
    fn encolar_post_pendiente(&mut self, bloque: BloqueDag, llegada: Instant) {
        if self.post_pendientes.len() >= TOPE_POST_PENDIENTES {
            self.post_pendientes.pop_front();
        }
        self.post_pendientes.push_back((bloque, llegada));
    }

    /// Reintenta los bloques PoST pendientes (decisión 3 extendida, aviso del director tras V5): el
    /// `ServicioPot` de verificación pudo completar el hueco que los frenaba desde la última
    /// admisión. Sin bloqueo del resto del bucle: como mucho una pasada por bloque en cola, cada
    /// vez que se llama. Los que sigan `Pendiente` vuelven a la cola; los que ahora sean
    /// demostrablemente inválidos (o una violación interna) se descartan **sin** penalizar — el
    /// remitente original ya no está atado a este intento.
    fn reintentar_post_pendientes(&mut self) {
        if self.post_pendientes.is_empty() {
            return;
        }
        let pendientes: Vec<(BloqueDag, Instant)> = self.post_pendientes.drain(..).collect();
        for (bloque, llegada) in pendientes {
            let hash = bloque.cabecera.block_hash();
            let indice = self.almacen.longitud_registro().unwrap_or(0);
            let n_padres = {
                let p = &bloque.cabecera.padres;
                if p.es_genesis() {
                    0
                } else {
                    (1 + p.extras().len()) as u64
                }
            };
            let bytes = zx_p2p::codec::bloque_a_bytes(&BloqueRed::Post {
                cabecera: bloque.cabecera,
                justificacion: bloque.justificacion.clone(),
                txs: bloque.txs().to_vec(),
                testigos: bloque.testigos().to_vec(),
            })
            .len() as u64;
            match self.admitir_post_interno(bloque.clone(), indice, true) {
                Ok(()) => {
                    let mut evento = self
                        .registro
                        .evento("bloque_red_admitido")
                        .str("hash", &hash.to_string())
                        .str("familia", "post")
                        .u64("slot", bloque.cabecera.slot)
                        .u64("n_padres", n_padres)
                        .u64("bytes", bytes)
                        .u64("t_cabecera_ns", self.medicion.cabecera_ns)
                        .u64("t_admision_ns", self.medicion.admision_ns)
                        .u64("t_persistencia_ns", self.medicion.persistencia_ns)
                        .u64("t_total_ns", llegada.elapsed().as_nanos() as u64)
                        .u64("n_bloques_dag", self.cadena.bloques_admitidos());
                    if let Some((azules, rojos)) = self.cadena.mergeset_de(&hash) {
                        evento = evento
                            .u64("azules_mergeset", azules)
                            .u64("rojos_mergeset", rojos);
                    }
                    let txs_descartadas =
                        self.cadena.descartes(&hash).map_or(0, |d| d.len() as u64);
                    evento = evento.u64("txs_descartadas", txs_descartadas);
                    let _ = self.registro.escribir(evento, false);
                }
                Err(ErrorNodo::BloquePropioRechazado { clasificacion, .. })
                    if clasificacion.es_pendiente() =>
                {
                    self.encolar_post_pendiente(bloque, llegada);
                }
                Err(e) => {
                    let evento = self
                        .registro
                        .evento("bloque_red_rechazado")
                        .str("hash", &hash.to_string())
                        .str("familia", "post")
                        .str("etapa", self.medicion.etapa)
                        .str("motivo", &format!("reintento: {e}"))
                        .u64("t_hasta_rechazo_ns", llegada.elapsed().as_nanos() as u64);
                    let _ = self.registro.escribir(evento, false);
                }
            }
        }
    }

    /// Construye los depósitos F-15 pendientes (coinbases maduras propias sin depositar) para la
    /// altura `altura_bloque` (decisión 5).
    fn preparar_depositos(&self, altura_bloque: u32) -> ResultadoNodo<Vec<(Tx, Vec<Vec<u8>>)>> {
        // `estado_terminal()` solo es el estado de la punta **antes del corte**: es
        // `Estado::inicial()` hasta que `zx-cadena` fija el terminal (comprobado, no una
        // suposición: el primer intento de este test dio `ErrNonce` porque todo depósito de la
        // fase PoW pedía `nonce = 0`, el de `Estado::inicial()`, aunque ya hubiera uno aplicado).
        // El estado correcto para construir la plantilla de la siguiente altura es el de la
        // **última cabecera PoW admitida**, con `estado_post`.
        #[expect(
            clippy::indexing_slicing,
            reason = "historial_pow siempre tiene al menos el génesis"
        )]
        let ultimo_hash = self.historial_pow[self.historial_pow.len() - 1].block_hash();
        let estado = self
            .cadena
            .estado_post(&ultimo_hash)
            .ok_or_else(|| ErrorNodo::Otro("estado del último bloque PoW ausente".to_string()))?;
        let mut depositos = Vec::new();
        // Hallazgo en vivo (`PROGRESO.md`, primera corrida real de V4, no es un bug de esta orden
        // pero impide demostrarla): el `nonce` de una operación de garantía es un contador **por
        // clave**, no por coinbase. Si la misma clave acumula más de una coinbase madura sin
        // depositar todavía (le basta con que el nodo pase un rato sin que su primer depósito
        // tenga éxito — p. ej. mientras está aislado de la red, ver el diagnóstico de la decisión
        // 4), el bucle de abajo construía **todos** los depósitos de esa clave con el mismo
        // `nonce` leído una sola vez del estado: el segundo, en el mismo bloque, siempre
        // discrepaba con el `nonce_siguiente` que el primero ya había incrementado (`ErrNonce`,
        // modo estricto ⇒ bloque entero inválido ⇒ bloque propio rechazado ⇒ fatal). Se lleva un
        // nonce local por clave, sembrado con el real del estado la primera vez que esa clave
        // aparece en este bloque y luego incrementado en memoria por cada depósito adicional de la
        // misma clave — exactamente lo que el motor de transición espera ver, sin tocar el estado
        // (que no cambia hasta que el bloque se aplique de verdad).
        let mut siguiente_nonce: std::collections::BTreeMap<zx_core::ClavePublica, u64> =
            std::collections::BTreeMap::new();
        // `ORDEN-W06d4` decisión 2: qué depositar se decide leyendo **directamente**
        // `estado.utxo`/`estado.garantias` de la punta PoW ya seleccionada, no un indicador local
        // (`CoinbasePropia.depositada`, `ORDEN-W06d3`) que podía desincronizarse de la rama. Una
        // coinbase propia sigue siendo candidata a depósito exactamente mientras su salida está sin
        // gastar **en el estado de esta rama** (`estado.utxo` la vuelve a mostrar por sí solo si el
        // bloque que la gastó queda descartado por una reorganización, sin ninguna poda aparte); y
        // deja de serlo en el instante en que un bloque de esta rama la gasta de verdad (sale de
        // `estado.utxo`). Iterar `estado.utxo` (`BTreeMap`, orden determinista por `OutPoint`) evita
        // además tener que reconstruir qué coinbases siguen vivas tras cada reorganización.
        for (outpoint, entrada) in &estado.utxo {
            if outpoint.prev_index != 0 || entrada.origen != Origen::CoinbasePow {
                continue;
            }
            let zx_core::Lock::PubKey { pubkey } = entrada.lock else {
                continue;
            };
            let Some(clave) = self.claves.iter().find(|c| c.pk == pubkey) else {
                continue;
            };
            let Some(altura_creacion) = entrada.creada.como_altura() else {
                continue;
            };
            let Some(madura_en) = altura_creacion.checked_add(self.params.m_cb) else {
                continue;
            };
            if altura_bloque < madura_en {
                continue;
            }
            let nonce = *siguiente_nonce.entry(clave.pk).or_insert_with(|| {
                estado
                    .garantias
                    .get(&clave.pk)
                    .map_or(0, |g| g.nonce_siguiente)
            });
            siguiente_nonce.insert(clave.pk, nonce.saturating_add(1));
            let (tx, testigos) =
                pow::construir_deposito(outpoint.prev_txid, entrada.valor, clave, nonce, self.cbid)
                    .map_err(|e| ErrorNodo::Otro(format!("construir depósito: {e}")))?;
            depositos.push((tx, testigos));
        }
        Ok(depositos)
    }

    /// Fase PoW: mina hasta fijar el terminal, con un depósito por clave madura en cada altura que
    /// lo permita (decisión 5). Devuelve cuando `Cadena` fija el terminal.
    ///
    /// # Errores
    /// [`ErrorNodo::BloquePropioRechazado`] con `clasificacion` interna (`ORDEN-W06d5` decisión 3, `crate::rechazo`); un rechazo legítimo se descarta y no llega a devolverse.
    fn fase_pow(&mut self) -> ResultadoNodo<()> {
        if self.cadena.terminal().is_some() {
            return Ok(());
        }
        let (tx_trabajo, rx_trabajo) = mpsc::channel::<pow::TrabajoMinero>();
        let (tx_minado, rx_minado) = mpsc::channel::<BlockHeader>();
        let hilo = thread::spawn(move || pow::hilo_minero(rx_trabajo, tx_minado));

        loop {
            // `ORDEN-W07d` decisión 2: parada ordenada por señal. Se cierra el canal del minero (el
            // hilo termina tras su búsqueda en curso) y se sale para que `ejecutar` escriba `parada`.
            if parada::hay_solicitud() {
                drop(tx_trabajo);
                drop(hilo);
                return Ok(());
            }
            #[expect(
                clippy::indexing_slicing,
                reason = "historial_pow siempre tiene al menos el génesis"
            )]
            let ultimo = self.historial_pow[self.historial_pow.len() - 1];
            let altura = ultimo
                .height
                .checked_add(1)
                .ok_or_else(|| ErrorNodo::Otro("altura PoW desbordada".to_string()))?;
            let ahora = std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .map(|d| d.as_secs())
                .unwrap_or(0);
            let timestamp = ahora.max(ultimo.timestamp.saturating_add(1));
            // C-TS-01 exige `ts > ts_padre` (permanente); con la dificultad inicial dev y el
            // binario en release, minar un bloque tarda mucho menos de 1 s, así que el reloj de
            // pared se queda atrás del `timestamp` mínimo exigible. Sin esta espera, el propio
            // bloque violaría C-TS-03 (`ts > reloj_local + FTL`) al admitirse: un rechazo fatal
            // (decisión 4) por una condición que el nodo mismo puede evitar, no un fallo del motor.
            if timestamp > ahora {
                std::thread::sleep(std::time::Duration::from_secs(timestamp - ahora));
            }
            let depositos = self.preparar_depositos(altura)?;
            #[expect(
                clippy::indexing_slicing,
                reason = "claves nunca está vacía: la CLI exige al menos un índice"
            )]
            let clave_de_este_bloque = self.claves[(altura as usize) % self.claves.len()].pk;
            let (plantilla, _txid_cb, _valor_cb) = pow::construir_plantilla(
                &self.historial_pow,
                ultimo.block_hash(),
                altura,
                timestamp,
                self.cbid,
                clave_de_este_bloque,
                depositos,
            )?;
            let txs = plantilla.txs.clone();
            let testigos = plantilla.testigos.clone();
            let trabajo = pow::TrabajoMinero::from(&plantilla);
            if tx_trabajo.send(trabajo).is_err() {
                return Err(ErrorNodo::Otro(
                    "el hilo minero terminó inesperadamente".to_string(),
                ));
            }
            // `ORDEN-W07d` decisión 2: `recv_timeout` en vez de `recv` para atender la señal
            // mientras el minero busca trabajo; un timeout no es una desconexión, solo se vuelve a
            // esperar. No cambia ninguna decisión del nodo.
            let cabecera_minada = loop {
                match rx_minado.recv_timeout(std::time::Duration::from_millis(50)) {
                    Ok(cabecera) => break cabecera,
                    Err(mpsc::RecvTimeoutError::Timeout) => {
                        if parada::hay_solicitud() {
                            drop(tx_trabajo);
                            drop(hilo);
                            return Ok(());
                        }
                    }
                    Err(mpsc::RecvTimeoutError::Disconnected) => {
                        return Err(ErrorNodo::Otro("el hilo minero cerró el canal".to_string()));
                    }
                }
            };
            // Se drena el trabajo de red **entre** intentos de minado, nunca durante uno: si se
            // interleara mientras `rx_minado` está bloqueado, un bloque de red podría admitirse a
            // la misma altura que estamos minando, y cuando nuestro propio hilo termine,
            // `admitir_pow_interno` lo admitiría como una bifurcación real de PoW —cosa que ni
            // `zx-cadena::admitir_pow` ni el `historial_pow` lineal de este nodo saben resolver
            // (límite conocido, `PROGRESO.md`: sin reorg de PoW en W06d2). En vez de eso, se
            // comprueba justo aquí si la red ya avanzó la punta mientras minábamos y, si es así, se
            // descarta el bloque propio (obsoleto) y se reintenta sobre la punta nueva.
            self.procesar_trabajo_red_pendiente();
            // `ORDEN-W06d3`, hallazgo en vivo (`PROGRESO.md`): el terminal puede fijarlo un bloque
            // de **red** admitido aquí mismo (dentro de `procesar_trabajo_red_pendiente`), no solo
            // uno propio. La comprobación de `self.cadena.terminal()` de más abajo, al final del
            // cuerpo del bucle, solo se alcanza si el bloque propio de esta vuelta se admite; si es
            // obsoleto (`continue`, justo abajo) el bucle vuelve a la cabecera **sin** pasar por
            // ella. Sin este cheque aquí, una vuelta puede minar sobre un padre cuyo propio estado
            // ya tiene `terminal = Some` (fijado por el bloque de red que el `procesar_trabajo_red_
            // pendiente` de arriba acaba de admitir) y `zx-cadena` la rechaza con
            // `ErrPowTrasCorte` — un bloque propio rechazado, fatal por la decisión 4 general de
            // `ORDEN-W06d1`. El bloque recién minado en esta vuelta queda descartado (ya es tarde
            // para él de todas formas: el corte ya ocurrió).
            if self.cadena.terminal().is_some() {
                drop(tx_trabajo);
                let _ = hilo.join();
                return Ok(());
            }
            let punta_sigue_siendo_la_esperada = self
                .historial_pow
                .last()
                .is_some_and(|u| u.block_hash() == cabecera_minada.prev_hash);
            if !punta_sigue_siendo_la_esperada {
                tracing::info!(
                    altura = cabecera_minada.height,
                    "bloque propio obsoleto: la red ya avanzó la punta mientras se minaba"
                );
                continue;
            }
            let n_txs = txs.len() as u64;
            let bytes = zx_p2p::codec::bloque_a_bytes(&BloqueRed::Pow {
                cabecera: cabecera_minada,
                txs: txs.clone(),
                testigos: testigos.clone(),
            })
            .len() as u64;
            let evento = self
                .registro
                .evento("bloque_minado")
                .str("hash", &cabecera_minada.block_hash().to_string())
                .u64("altura", u64::from(cabecera_minada.height))
                .u64("bytes", bytes)
                .u64("n_txs", n_txs);
            self.registro.escribir(evento, false)?;

            // `ORDEN-W06d5` decisión 3: mismo criterio que `fase_regimen` — un rechazo legítimo
            // (p. ej. `ErrPowTrasCorte`, el corte lo fijó un bloque de red justo entre que este
            // nodo empezó a minar y a admitir; ver `crate::rechazo`) se registra y se descarta;
            // solo una violación de invariante interna sigue siendo fatal.
            let indice_registro = self.almacen.longitud_registro()?;
            match self.admitir_pow_interno(cabecera_minada, txs, testigos, indice_registro, true) {
                Ok(()) => {}
                Err(ErrorNodo::BloquePropioRechazado {
                    hash,
                    motivo,
                    clasificacion,
                }) if clasificacion.es_legitimo() => {
                    let evento = self
                        .registro
                        .evento("bloque_propio_rechazado_legitimo")
                        .str("hash", &hash.to_string())
                        .str("motivo", &motivo);
                    self.registro.escribir(evento, false)?;
                    continue;
                }
                Err(e) => return Err(e),
            }
            self.difundir_si_hay_red(cabecera_minada.block_hash());

            if self.cadena.terminal().is_some() {
                drop(tx_trabajo);
                let _ = hilo.join();
                return Ok(());
            }
        }
    }

    /// `ORDEN-W06d8` decisión 3: parada ordenada por fallo del hilo productor. Escribe el evento
    /// **crítico** `fallo_productor` con el motivo y devuelve error, de modo que `ejecutar`/`main`
    /// salen con código ≠ 0: nunca queda un nodo que valida pero ha dejado de producir sin decirlo.
    fn fallo_productor(&self, motivo: &str) -> ResultadoNodo<()> {
        escribir_fallo_productor(&self.registro, motivo)
    }

    /// Fase PoST en régimen: arranca `ServicioPot` de verificación, las parcelas locales y el hilo
    /// productor, y atiende sus peticiones hasta que se agote (`--parada-tras-slots`) o falle.
    ///
    /// # Errores
    /// [`ErrorNodo::BloquePropioRechazado`] con `clasificacion` interna (`ORDEN-W06d5` decisión 3, `crate::rechazo`); un rechazo legítimo se descarta y no llega a devolverse.
    fn fase_regimen(&mut self) -> ResultadoNodo<()> {
        // `ORDEN-SL4b2` decisión 0 (paso previo): `terminal` es el que este bucle sigue
        // **produciendo** ahora mismo; puede quedar por detrás de `self.cadena.terminal()` (FC-3
        // puede reseleccionar mientras se produce, `ORDEN-W06d7`). Mutable: lo actualiza
        // `sincronizar_terminal_productor` en cuanto detecta la discrepancia.
        let mut terminal = self
            .cadena
            .terminal()
            .ok_or_else(|| ErrorNodo::Otro("fase_regimen sin terminal".to_string()))?;
        // `ORDEN-W06d7` decisión 5: un `ServicioPot` por terminal candidato, no uno solo; se
        // asegura (crea si falta) el de `terminal` y el de cualquier otro candidato ya conocido.
        // Entre que `fase_pow` vio el terminal seleccionado por última vez y aquí, una rama más
        // pesada llegada por red pudo haber cambiado la selección (FC-3): `terminal` sigue siendo
        // válido como terminal candidato (tiene su propio servicio para siempre, no se "pierde" al
        // dejar de ser el seleccionado), aunque ya no sea `self.cadena.terminal()`.
        self.asegurar_servicios_verificacion()?;

        // El primer bloque de régimen (transición) se produce con el firmante seguro
        // (`producir_con_firmante`, `ORDEN-SL4b3` decisión 1), ya no con la ruta que sellaba sin
        // registrar. El resto del comentario conserva el motivo de la espera.
        //
        // `ORDEN-W06d5` decisión 1, extensión encontrada **en vivo** al repetir V5 con esta misma
        // orden ya aplicada (evidencia en `PROGRESO.md`): un nodo que llega tarde también puede
        // llegar aquí con `tips_validas()` vacío (los bloques PoST que le llegaron por red antes de
        // fijar su propio terminal se ignoran como `bloque_post_de_red_sin_terminal`, sin
        // reintentarse) y con la clave que firma la transición (`self.claves[0]`, decisión 6 de
        // `producir_bloque_transicion`) **sin garantía propia** (nunca minó ni depositó: exactamente
        // el perfil de una clave nueva de V5). Producir de todos modos repite el mismo `ErrGarantia`
        // fatal que la decisión 1 ya evita en régimen — el hilo productor nunca llega a arrancar
        // porque el proceso muere antes, en esta única producción previa al bucle de mensajes. Igual
        // que en régimen: no se intenta sin garantía; en vez de eso, se espera (procesando red) a
        // que **otro** nodo produzca y sincronice la transición, lo que llena `tips_validas()` por
        // la vía normal de `intentar_admitir_post_de_red`.
        if self.cadena.tips_validas().is_empty() {
            let hay_garantia_propia = self
                .claves
                .first()
                .is_some_and(|c| self.cadena.estado_terminal().activo_de(&c.pk) >= self.params.q);
            if hay_garantia_propia {
                self.producir_bloque_transicion(terminal)?;
            } else {
                tracing::info!(
                    "sin garantía propia en el terminal: no se intenta producir el bloque de \
                     transición; se espera a sincronizarlo de otro nodo"
                );
            }
            // `ORDEN-SL4b3` decisión 1: si `producir_bloque_transicion` se abstuvo (conflicto o
            // pérdida de registro), no produjo nada y `tips_validas()` sigue vacío. Reintentar el
            // mismo candidato determinista solo repetiría la abstención (misma identidad y slot), así
            // que la recuperación es la sincronización con la red, no un bucle de producción; el
            // hilo productor de régimen retomará la producción en los slots siguientes en cuanto la
            // transición esté en la cadena.
            while self.cadena.tips_validas().is_empty() {
                // `ORDEN-W07d` decisión 2: la parada por señal también se atiende aquí, antes de
                // arrancar el hilo productor.
                if parada::hay_solicitud() {
                    return Ok(());
                }
                self.procesar_trabajo_red_pendiente();
                std::thread::sleep(std::time::Duration::from_millis(50));
            }
        }

        let mut claves_con_parcela = Vec::new();
        for clave in self.claves.clone() {
            let parcela = abrir_o_crear_parcela(&self.dir_datos, &clave, &self.historia)?;
            claves_con_parcela.push(ClaveConParcela { clave, parcela });
        }

        // Clon del `ServicioPot` de verificación (ya trae el terminal y todo bloque PoST admitido:
        // el de transición recién producido, o toda la historia de régimen si esto es un reinicio a
        // mitad de régimen). El hilo avanza y produce sobre su propio clon; el del bucle solo se usa
        // para verificar (ver el doc de `hilo_productor_regimen`).
        let servicio_hilo = self
            .servicios_verificacion
            .get(&terminal)
            .cloned()
            .ok_or_else(|| {
                ErrorNodo::Otro("fase_regimen sin ServicioPot de verificación".to_string())
            })?;

        let (tx_a_bucle, rx_en_bucle) = mpsc::channel::<MsgProductor>();
        let (tx_a_productor, rx_en_productor) = mpsc::channel::<MsgBucle>();
        let cbid = self.cbid;
        let n_dev = self.n_dev;
        let sr_dev = self.sr_dev_actual;
        // `ORDEN-W06d6` decisión 6: el hilo productor para de producir en el primero de los dos
        // límites que esté fijado (`--parada-tras-slots` sigue parando el nodo entero; el nuevo
        // `--dejar-de-producir-en-slot` solo para de producir, ver más abajo tras el bucle).
        let parada = self.limite_productor();
        let importe_coinbase = perfil::subsidio_post(0);
        let historia_hilo: Arc<HistoriaGenesis> = Arc::clone(&self.historia);
        // `ORDEN-SL4b2` decisión 2: el firmante seguro (único por nodo) viaja al hilo por `Arc`,
        // igual que `self.registro` (registro estructurado); `fase_regimen` corre siempre después
        // de `arranque_limpio`/`reiniciar`, que ya lo abrieron.
        let registro_firmante_hilo: Arc<RegistroFirmante> = Arc::clone(
            self.registro_firmante
                .as_ref()
                .ok_or_else(|| ErrorNodo::Otro("fase_regimen sin registro de firmante".into()))?,
        );
        // `ORDEN-W06d8` decisión 1: el hilo escribe desde su lado el evento de diagnóstico
        // `productor_respuesta_descartada` cuando descarta una respuesta atrasada; comparte el mismo
        // registro que el bucle (que ya es `Arc` y serializa con un `Mutex`).
        let registro_hilo: Arc<Registro> = Arc::clone(&self.registro);
        let hilo = thread::spawn(move || {
            hilo_productor_regimen(
                servicio_hilo,
                n_dev,
                sr_dev,
                cbid,
                importe_coinbase,
                claves_con_parcela,
                &historia_hilo,
                parada,
                &rx_en_productor,
                &tx_a_bucle,
                &registro_firmante_hilo,
                &registro_hilo,
            );
        });

        // `recv_timeout`, no `for msg in rx_en_bucle`: entre dos mensajes del productor (que puede
        // tardar hasta un slot entero) hace falta seguir drenando `procesar_trabajo_red_pendiente`
        // (decisión 1/3/4 de `ORDEN-W06d2`), o un bloque de red llegaría y esperaría sin motivo
        // hasta el siguiente mensaje del hilo productor.
        loop {
            // `ORDEN-W07d` decisión 2: parada ordenada por señal. Se le pide al productor que pare
            // (responde a `Parar` en su `esperar`) y se sale del bucle; el `join` de abajo lo
            // espera.
            if parada::hay_solicitud() {
                let _ = tx_a_productor.send(MsgBucle::Parar);
                break;
            }
            let msg = match rx_en_bucle.recv_timeout(std::time::Duration::from_millis(50)) {
                Ok(m) => m,
                Err(mpsc::RecvTimeoutError::Timeout) => {
                    self.procesar_trabajo_red_pendiente();
                    // Decisión 0: entre dos mensajes del hilo (hasta un slot entero) es exactamente
                    // cuando una reunión con producción en marcha puede haber reseleccionado el
                    // terminal (E-6b): hay que sincronizar aquí, no solo tras recibir un mensaje.
                    self.sincronizar_terminal_productor(&mut terminal, &tx_a_productor)?;
                    continue;
                }
                Err(mpsc::RecvTimeoutError::Disconnected) => break,
            };
            self.procesar_trabajo_red_pendiente();
            // Decisión 0: si el terminal seleccionado cambió, se sincroniza el hilo **antes** de
            // decidir qué hacer con `msg` — si `msg` es `PeticionPadres`, esa petición era del
            // terminal anterior y no se contesta (el hilo la abandona al ver `CambiarTerminal`,
            // `regimen::Recepcion::Interrumpido`); si es `Post`, el bloque se admite igual (sigue
            // siendo válido en su propio terminal) y el cambio ya viajó como mensaje aparte.
            let terminal_cambio =
                self.sincronizar_terminal_productor(&mut terminal, &tx_a_productor)?;
            match msg {
                MsgProductor::PeticionPadres { .. } if terminal_cambio => {
                    // Petición del terminal anterior: se descarta sin contestar (ver arriba).
                }
                MsgProductor::PeticionPadres {
                    id,
                    slot: slot_objetivo,
                } => {
                    let padres = padres_de_regimen(&self.cadena)
                        .map_err(|e| ErrorNodo::Otro(format!("padres de régimen: {e}")))?;
                    // `(hash, slot)` de cada padre (seleccionado y extras): el hilo productor
                    // necesita esto para registrar en su propio `ServicioPot` cualquier padre que
                    // no haya producido él mismo (`ORDEN-W06d3`, ver el docstring de
                    // `MsgBucle::Padres`). Todo padre de régimen es un `BloqueCadena::Post` (el
                    // único `Pow` posible, el terminal, no aparece en `tips_validas`).
                    let mut info_padres = Vec::with_capacity(1 + padres.extras().len());
                    for h in std::iter::once(padres.seleccionado())
                        .chain(padres.extras().iter().copied())
                    {
                        if let Some(BloqueCadena::Post(p)) = self.cadena.bloque(&h) {
                            info_padres.push((h, p.slot));
                        }
                    }
                    // `ORDEN-W06d5` decisión 1 (RD-9): claves (de entre las que gestiona este
                    // nodo) con garantía activa `>= q` en `Estado(padre_seleccionado)`. Solo el
                    // bucle tiene `Cadena`/`self.params.q`; se calcula aquí, una vez por slot (los
                    // hermanos del mismo slot comparten padres), y se manda al hilo productor para
                    // que nunca intente `producir_en_regimen` con una clave que no lo alcance
                    // (causa de `ErrGarantia` fatal en V5 de `REVISION-W06d4.md`).
                    let estado_base = self.cadena.estado_post(&padres.seleccionado());
                    let con_garantia: std::collections::BTreeSet<zx_core::ClavePublica> =
                        estado_base
                            .map(|estado| {
                                self.claves
                                    .iter()
                                    .filter(|c| estado.activo_de(&c.pk) >= self.params.q)
                                    .map(|c| c.pk)
                                    .collect()
                            })
                            .unwrap_or_default();
                    // `ORDEN-SL4b2` decisión 4: hasta `MAX_EVIDENCIAS_POR_BLOQUE` pendientes cuyo
                    // incidente no esté ya procesado en `estado_base` (el estado sobre el que
                    // construye este bloque) y cuya ventana siga abierta en `slot_objetivo`
                    // (`slot_falta ≤ slot_objetivo < slot_falta + Plazo_slots`). El filtro vive en
                    // `evidencia::elegibles` para poder probarlo por unidad (`ORDEN-SL4b3` V2).
                    let evp = perfil::parametros_evidencia_dev();
                    let evidencias = crate::evidencia::elegibles(
                        &self.detector,
                        estado_base,
                        slot_objetivo,
                        evp.plazo_slots,
                        perfil::MAX_EVIDENCIAS_POR_BLOQUE,
                    );
                    if tx_a_productor
                        .send(MsgBucle::Padres {
                            id,
                            padres,
                            info_padres,
                            con_garantia,
                            evidencias,
                        })
                        .is_err()
                    {
                        break;
                    }
                }
                MsgProductor::Post {
                    id,
                    bloque,
                    instante_salida,
                } => {
                    let hash = bloque.cabecera.block_hash();
                    let slot = bloque.cabecera.slot;
                    let n_padres = {
                        let p = &bloque.cabecera.padres;
                        if p.es_genesis() {
                            0
                        } else {
                            (1 + p.extras().len()) as u64
                        }
                    };
                    let n_txs = bloque.txs().len() as u64;
                    let bytes = zx_p2p::codec::bloque_a_bytes(&BloqueRed::Post {
                        cabecera: bloque.cabecera,
                        justificacion: bloque.justificacion.clone(),
                        txs: bloque.txs().to_vec(),
                        testigos: bloque.testigos().to_vec(),
                    })
                    .len() as u64;
                    let retraso_slot_ns = instante_salida.elapsed().as_nanos() as u64;
                    // `ORDEN-SL4b2` decisión 4 (`evidencia_incluida`): los `incident_id` de las
                    // `EvidenceTx` que este bloque lleva, calculados **antes** de mover `bloque` a
                    // `admitir_post_interno`.
                    let incidentes_incluidos: Vec<([u8; 32], zx_core::ClavePublica)> = bloque
                        .txs()
                        .iter()
                        .filter_map(|t| match &t.extension {
                            zx_core::ExtensionTx::Evidencia { h1, .. } => Some((
                                *zx_core::incident_id_evidencia(
                                    h1.consensus_branch_id,
                                    h1.sol.public_key.bytes(),
                                    h1.sol.sector_index,
                                    h1.sol.history_size,
                                    &h1.sol.chunk,
                                    h1.slot,
                                )
                                .as_bytes(),
                                h1.sol.public_key,
                            )),
                            _ => None,
                        })
                        .collect();
                    match self.admitir_post_interno(
                        *bloque,
                        self.almacen.longitud_registro()?,
                        true,
                    ) {
                        Ok(()) => {
                            for (incident_id, _clave) in &incidentes_incluidos {
                                let evento = self
                                    .registro
                                    .evento("evidencia_incluida")
                                    .str(
                                        "incident_id",
                                        &zx_core::digest::Digest::from_bytes(*incident_id)
                                            .to_string(),
                                    )
                                    .str("bloque", &hash.to_string());
                                self.registro.escribir(evento, false)?;
                                // `garantia_clave_tras_evidencia` (diagnóstico con `activo`/
                                // `congelado` para V4) ya lo escribe, para **cualquier** vía de
                                // admisión, `admitir_post_interno` (única tubería, ver el
                                // comentario allí); no se repite aquí.
                            }
                            let mut evento = self
                                .registro
                                .evento("bloque_producido")
                                .str("hash", &hash.to_string())
                                .u64("slot", slot)
                                .u64("n_padres", n_padres)
                                .u64("n_txs", n_txs)
                                .u64("bytes", bytes)
                                .u64("retraso_slot_ns", retraso_slot_ns);
                            if let Some((azules, rojos)) = self.cadena.mergeset_de(&hash) {
                                evento = evento
                                    .u64("azules_mergeset", azules)
                                    .u64("rojos_mergeset", rojos);
                            }
                            self.registro.escribir(evento, false)?;
                            self.difundir_si_hay_red(hash);
                            // El pasado del `ServicioPot` de verificación acaba de avanzar: algún
                            // bloque de red que quedó `Pendiente` (decisión 3 extendida) puede haber
                            // dejado de estarlo.
                            self.reintentar_post_pendientes();
                            let continuar = self.limite_productor().is_none_or(|limite| {
                                self.servicios_verificacion
                                    .get(&terminal)
                                    .is_some_and(|s| s.slot_actual() < limite)
                            });
                            let respuesta = if continuar {
                                MsgBucle::Continuar { id }
                            } else {
                                MsgBucle::Parar
                            };
                            if tx_a_productor.send(respuesta).is_err() {
                                break;
                            }
                            if !continuar {
                                break;
                            }
                        }
                        // `ORDEN-W06d5` decisión 3: un rechazo **legítimo** (RD-9/RD-5/carrera de
                        // padres, ver `crate::rechazo`) se registra y se descarta; el nodo sigue en
                        // régimen, igual que ya hace con una candidata descartada por
                        // `SlotNoProgreso`. Solo una violación de invariante interna sigue siendo
                        // fatal (decisión 4 de `ORDEN-W06d1`, sin cambios).
                        Err(e) => {
                            if let ErrorNodo::BloquePropioRechazado {
                                hash,
                                motivo,
                                clasificacion,
                            } = &e
                                && clasificacion.es_legitimo()
                            {
                                let evento = self
                                    .registro
                                    .evento("bloque_propio_rechazado_legitimo")
                                    .str("hash", &hash.to_string())
                                    .str("motivo", motivo);
                                self.registro.escribir(evento, false)?;
                                if tx_a_productor.send(MsgBucle::Continuar { id }).is_err() {
                                    break;
                                }
                                continue;
                            }
                            let _ = tx_a_productor.send(MsgBucle::Parar);
                            return Err(e);
                        }
                    }
                }
                // `ORDEN-SL4b2` decisión 2: el firmante seguro se abstuvo (conflicto de identidad
                // o pérdida de registro). Evento crítico del esquema v1; el nodo sigue produciendo
                // (contesta `Continuar`): esta es la única oportunidad perdida, no un fallo.
                MsgProductor::Abstenido { id, slot, motivo } => {
                    let evento = self
                        .registro
                        .evento("firmante_abstenido")
                        .u64("slot", slot)
                        .str("motivo", motivo_abstencion_texto(motivo));
                    self.registro.escribir(evento, true)?;
                    if tx_a_productor.send(MsgBucle::Continuar { id }).is_err() {
                        break;
                    }
                }
                // `ORDEN-W06d8` decisión 3: el hilo productor detectó una violación de invariante
                // (o un fallo interno irrecuperable) y pide parar. No es una entrada ajena ni un
                // `panic` del nodo: es una parada ordenada. Evento crítico `fallo_productor` +
                // error fatal (salida ≠ 0), nunca un nodo que valida y deja de producir en silencio.
                MsgProductor::Fallo { motivo } => {
                    return self.fallo_productor(&motivo);
                }
            }
        }
        drop(tx_a_productor);
        // Decisión 4: un fallo interno del nodo termina el proceso con código ≠ 0, nunca en
        // silencio. `hilo_productor_regimen` no valida entrada ajena (sin red): un panic ahí es una
        // incoherencia interna, no un evento de red que se pueda ignorar (el bug real que motivó
        // esto, `PROGRESO.md`, era exactamente un hilo que moría sin decir por qué).
        if let Err(panico) = hilo.join() {
            let motivo = panico
                .downcast_ref::<&str>()
                .map(|s| (*s).to_string())
                .or_else(|| panico.downcast_ref::<String>().cloned())
                .unwrap_or_else(|| "panic sin mensaje representable".to_string());
            return self.fallo_productor(&format!("el hilo productor terminó con panic: {motivo}"));
        }
        // `ORDEN-W07d` decisión 2: si la parada la pidió una señal, no se entra en el reposo
        // indefinido de `--dejar-de-producir-en-slot`; `ejecutar` escribe `parada` y sale con 0.
        if parada::hay_solicitud() {
            return Ok(());
        }
        // `ORDEN-W06d6` decisión 6: si lo que paró de producir fue **solo**
        // `--dejar-de-producir-en-slot` (no `--parada-tras-slots`), el nodo entero **no** termina
        // aquí: sigue vivo, validando, propagando y sincronizando, para poder compararse en reposo
        // contra otros nodos (`P-ZRX/P-MEDICION/REVISION-W07c.md`). Solo `--parada-tras-slots`
        // (con o sin el otro) termina el proceso, como siempre.
        if self.parada_tras_slots.is_none() && self.dejar_de_producir_en_slot.is_some() {
            let evento = self.registro.evento("dejar_de_producir").str(
                "motivo",
                "--dejar-de-producir-en-slot alcanzado: sigue en reposo activo",
            );
            self.registro.escribir(evento, false)?;
            loop {
                if parada::hay_solicitud() {
                    return Ok(());
                }
                self.procesar_trabajo_red_pendiente();
                std::thread::sleep(std::time::Duration::from_millis(50));
            }
        }
        Ok(())
    }

    /// El límite de slot en el que el hilo productor debe dejar de producir (`ORDEN-W06d6`
    /// decisión 6): el más restrictivo de `--parada-tras-slots` y `--dejar-de-producir-en-slot`,
    /// si hay alguno.
    fn limite_productor(&self) -> Option<u64> {
        match (self.parada_tras_slots, self.dejar_de_producir_en_slot) {
            (Some(a), Some(b)) => Some(a.min(b)),
            (Some(a), None) => Some(a),
            (None, Some(b)) => Some(b),
            (None, None) => None,
        }
    }

    /// `ORDEN-SL4b3` decisión 1: el bloque de transición se produce con [`producir_con_firmante`] y
    /// el **mismo** firmante seguro del nodo que usa el régimen (registro único por nodo,
    /// `C-EVP-06`, FIR-01…FIR-15); ya no hay ninguna ruta que lo selle sin registrar la oportunidad.
    /// Si el firmante se abstiene, no se produce: se escribe `firmante_abstenido` (esquema v1) y se
    /// devuelve `Ok`, dejando que `fase_regimen` espere a sincronizar la transición de otro nodo (el
    /// hilo productor de régimen retomará la producción en cuanto haya puntas).
    fn producir_bloque_transicion(&mut self, terminal: BlockHash) -> ResultadoNodo<()> {
        #[expect(clippy::indexing_slicing, reason = "la CLI exige al menos una clave")]
        let clave = self.claves[0].clone();
        let parcela = abrir_o_crear_parcela(&self.dir_datos, &clave, &self.historia)?;
        let fuente = FuenteTransicion {
            parcela: &parcela,
            historia: &self.historia,
        };
        let parametros = ParametrosProductor {
            n_dev: self.n_dev,
            sr_dev: self.sr_dev_actual,
            max_slots: 150,
            consensus_branch_id: self.cbid,
            timestamp: std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .map(|d| d.as_secs())
                .unwrap_or(0),
            importe_coinbase: perfil::subsidio_post(0),
        };
        // `Arc` clonado para no dejar vivo un préstamo inmutable de `self` mientras más abajo se
        // llama a `admitir_post_interno(&mut self, ...)`.
        let registro_firmante = Arc::clone(self.registro_firmante.as_ref().ok_or_else(|| {
            ErrorNodo::Otro("producir_bloque_transicion sin registro de firmante".to_string())
        })?);
        let producto = {
            let mut firmante = Firmante::nuevo(&registro_firmante);
            producir_con_firmante(terminal, &fuente, &clave.sk, &parametros, &mut firmante)
                .map_err(|e| {
                    ErrorNodo::Otro(format!("producir_con_firmante (bloque de transición): {e}"))
                })?
        };
        let bloque = match producto {
            ProductoFirmado::Bloque(bloque, _) => bloque,
            ProductoFirmado::Abstenido { slot, motivo } => {
                // Decisión 1: el bloque no se produce; evento crítico del esquema v1 con el slot
                // real de la oportunidad y el motivo. El llamante espera a otro nodo.
                let evento = self
                    .registro
                    .evento("firmante_abstenido")
                    .u64("slot", slot)
                    .str("motivo", motivo_abstencion_texto(motivo));
                self.registro.escribir(evento, true)?;
                return Ok(());
            }
        };
        let hash = bloque.cabecera.block_hash();
        let slot = bloque.cabecera.slot;
        self.admitir_post_interno(bloque, self.almacen.longitud_registro()?, true)?;
        // `ORDEN-W07a`: el bloque de transición es un PoST propio admitido y persistido, pero **no**
        // se registra como `bloque_producido`: la base (W06d1…W06d6) no lo hacía y el §1 no fija su
        // `retraso_slot_ns` (no hay hilo productor). Emitirlo antes de que `fase_regimen` abra y
        // plotee las parcelas cambiaba el instante del primer `bloque_producido` y rompía la
        // verificación de reinicio tras `SIGKILL` (`reinicio.rs`): se conserva el comportamiento.
        //
        // `ORDEN-W07d` decisión 3: sí se registra como **diagnóstico** con un tipo propio,
        // `bloque_transicion_producido`, para que el bloque de transición no quede sin rastro sin
        // alterar lo que prueba `reinicio.rs` (que cuenta `bloque_producido`).
        self.registro.escribir(
            self.registro
                .evento("bloque_transicion_producido")
                .str("hash", &hash.to_string())
                .u64("slot", slot),
            false,
        )?;
        self.difundir_si_hay_red(hash);
        Ok(())
    }

    /// La instantánea compartida de red (para construir el manejador antes de llamar a
    /// [`Self::conectar_red`], y para que las pruebas la inspeccionen).
    #[must_use]
    pub fn vista_red(&self) -> Arc<VistaRed> {
        Arc::clone(&self.vista_red)
    }

    /// `ORDEN-W07a`: manija compartida del registro estructurado, para que la red escriba en él los
    /// eventos no críticos de par y de límite.
    #[must_use]
    pub fn registro(&self) -> Arc<Registro> {
        Arc::clone(&self.registro)
    }

    /// Conecta el nodo a la red (`ORDEN-W06d2`): a partir de aquí, `ejecutar` también procesa el
    /// trabajo de red (bloques difundidos o de sincronización) intercalado con su propia
    /// producción (D-N07: un único hilo de consenso). Sin llamar a esto, el nodo se comporta
    /// exactamente como en `ORDEN-W06d1` (sin red).
    pub fn conectar_red(&mut self, manija: ManijaRed, receptor: ReceptorTrabajoRed) {
        self.red = Some(manija);
        self.trabajo_red = Some(receptor);
    }

    /// `ORDEN-W07a`: fija el `peer_id` y la dirección de escucha para el `arranque`. Se llama tras
    /// arrancar la red (si la hay) y antes de [`Self::ejecutar`].
    pub fn fijar_arranque_red(&mut self, peer_id: String, red_escuchar: Option<String>) {
        self.peer_id = Some(peer_id);
        self.red_escuchar = red_escuchar;
    }

    /// Ejecuta el nodo de punta a punta: fase PoW hasta el corte, luego régimen.
    ///
    /// # Errores
    /// Cualquier fallo fatal de admisión propia (decisión 4).
    pub fn ejecutar(&mut self) -> ResultadoNodo<()> {
        // `ORDEN-W07a` §1: `arranque`, al terminar el arranque (ya con la red conectada, si la hay).
        let claves: Vec<String> = self.claves.iter().map(|c| c.indice.to_string()).collect();
        let mut evento = self
            .registro
            .evento("arranque")
            .u64("version_esquema", 1)
            .u64("n_dev", self.n_dev)
            .u64("sr_dev", self.sr_dev_actual)
            .str("claves", &claves.join(","))
            .str(
                "modo",
                if self.modo_limpio {
                    "limpio"
                } else {
                    "reinicio"
                },
            );
        if let Some(peer_id) = self.peer_id.as_deref() {
            evento = evento.str("peer_id", peer_id);
        }
        if let Some(red) = self.red_escuchar.as_deref() {
            evento = evento.str("red_escuchar", red);
        }
        self.registro.escribir(evento, true)?;

        self.fase_pow()?;
        // `ORDEN-W07d` decisión 2: una señal durante la fase PoW detiene el proceso **sin** entrar
        // en régimen (todavía no hay terminal y `fase_regimen` fallaría con «fase_regimen sin
        // terminal»). El flag ya está puesto, así que el motivo es de señal.
        if let Some(motivo) = parada::motivo_solicitado() {
            self.escribir_parada(motivo)?;
            return Ok(());
        }
        self.fase_regimen()?;
        // `ORDEN-W07a` §1 y `ORDEN-W07d` decisión 2: `parada`, salida ordenada (crítico). Si la
        // pidió una señal, ese es el motivo; si no, el final normal de la fase.
        let motivo = if let Some(motivo) = parada::motivo_solicitado() {
            motivo
        } else if self.parada_tras_slots.is_some() {
            "parada_tras_slots"
        } else {
            "fin"
        };
        self.escribir_parada(motivo)?;
        Ok(())
    }

    /// Acceso de solo lectura a `zx-cadena` (para pruebas e inspección; no es API de consenso).
    #[must_use]
    pub fn cadena(&self) -> &Cadena {
        &self.cadena
    }

    /// Altura PoW alcanzada (para pruebas: mide el progreso de la fase PoW sin exponer
    /// `historial_pow` entero).
    #[must_use]
    pub fn altura_pow(&self) -> u32 {
        self.historial_pow.last().map_or(0, |h| h.height)
    }

    /// El resumen de estado (decisión 8) de la punta seleccionada actual, o del terminal si aún no
    /// hay puntas PoST.
    #[must_use]
    pub fn resumen_estado_actual(&self) -> Option<String> {
        let estado = self.cadena.estado_virtual().ok()?;
        Some(resumen_estado(&estado))
    }
}

/// Puente `FuenteSoluciones → ParcelaDisco` para el bloque de transición (decisión 6, `producir`).
struct FuenteTransicion<'a> {
    parcela: &'a ParcelaDisco,
    historia: &'a HistoriaGenesis,
}

impl FuenteSoluciones for FuenteTransicion<'_> {
    type Error = zx_farmer::ErrorProductorPoas;

    fn soluciones(
        &self,
        salida: [u8; 16],
        slot: u64,
        rango: u64,
    ) -> Result<Vec<SolucionCandidata>, Self::Error> {
        let params = self.historia.params_pieza();
        let resultado = zx_farmer::productor_poas::convertir_candidatos_locales(
            self.parcela,
            salida,
            slot,
            rango,
            &params,
            self.historia.kzg(),
            self.historia.erasure_coding(),
        )?;
        Ok(resultado
            .soluciones()
            .iter()
            .map(|c| SolucionCandidata {
                solucion: *c.solucion(),
                distancia: c.distancia(),
            })
            .collect())
    }
}

fn pow_target_de(cabecera: &BlockHeader) -> Result<primitive_types::U256, ErrorNodo> {
    zx_core::decodificar_con(cabecera.bits, &PARAMETROS_POW_DEV.limites)
        .map_err(|e| ErrorNodo::Otro(format!("bits de la cabecera PoW: {e}")))
}

/// `ORDEN-W06d10-B`: ¿este error de la tubería de admisión de un bloque de **red** es un defecto
/// **demostrable del candidato** (penaliza al remitente) o un fallo/vista **local** (X1/X2/X3, se
/// ignora sin penalizar)?
///
/// - `BloquePropioRechazado` con clasificación que penaliza (`Legitimo`/`Interno`, incluidos los
///   defectos que antes llegaban como `ErrorNodo::Otro`: `bits`, `target`, `trabajo`, `peso`).
/// - `RepeticionFallida`/`TestigoPowCorrupto` en la ruta en vivo: PoAS o testigo del candidato.
/// - Todo lo demás (`Otro` de persistencia/servicio/detector, `Almacen`, `Io`, …) es local.
#[must_use]
fn error_atribuible_al_candidato(e: &ErrorNodo) -> bool {
    match e {
        ErrorNodo::BloquePropioRechazado { clasificacion, .. } => clasificacion.penaliza_en_red(),
        ErrorNodo::RepeticionFallida { .. } | ErrorNodo::TestigoPowCorrupto { .. } => true,
        _ => false,
    }
}

/// `PadresDag` a `Vec<BlockHash>` (seleccionado primero), para `BloquePost::padres`.
fn padres_dag_a_vec(p: &PadresDag) -> Vec<BlockHash> {
    if p.es_genesis() {
        return Vec::new();
    }
    let mut v = vec![p.seleccionado()];
    v.extend_from_slice(p.extras());
    v
}

/// Texto del `motivo` del evento `firmante_abstenido` (esquema v1): el mismo para la abstención de
/// la transición (`producir_bloque_transicion`) y la del hilo productor de régimen.
fn motivo_abstencion_texto(motivo: zx_post::productor::MotivoAbstencion) -> &'static str {
    match motivo {
        zx_post::productor::MotivoAbstencion::Conflicto { .. } => "conflicto",
        zx_post::productor::MotivoAbstencion::PerdidaRegistro { .. } => "perdida_registro",
    }
}

/// Familia de un bloque de red, para el registro (`pow`/`post`).
fn familia_de(bloque: &BloqueRed) -> &'static str {
    match bloque {
        BloqueRed::Pow { .. } => "pow",
        BloqueRed::Post { .. } => "post",
    }
}

/// Tamaño en bytes de la serialización de red de un bloque (`ORDEN-W07a`).
fn bytes_de(bloque: &BloqueRed) -> u64 {
    zx_p2p::codec::bloque_a_bytes(bloque).len() as u64
}

/// `w(SR)` (`U256`) a `u128` para `BloquePost::peso` (no debería desbordar con `SR_dev` de la red
/// dev; se trata como fallo fatal si ocurriera, no como truncamiento silencioso).
fn peso_u128(bloque: &BloqueDag) -> Result<u128, ErrorNodo> {
    let peso = zx_dag::peso(bloque.cabecera.rango_solucion);
    u128::try_from(peso).map_err(|_| ErrorNodo::Otro(format!("peso {peso} no cabe en u128")))
}

/// `ORDEN-W06d8` decisión 3: escribe el evento crítico `fallo_productor` y devuelve el error fatal
/// correspondiente. Separado del método para poder probarlo por unidad sin construir un `Nodo`
/// entero. La salida ≠ 0 la garantiza `main` al recibir el `Err` de `ejecutar`.
fn escribir_fallo_productor(registro: &Registro, motivo: &str) -> ResultadoNodo<()> {
    registro.escribir(
        registro.evento("fallo_productor").str("motivo", motivo),
        true,
    )?;
    Err(ErrorNodo::Otro(format!(
        "fallo del hilo productor: {motivo}"
    )))
}

/// `ORDEN-SL4b2` V3: la puerta RAT-3 en el punto exacto que usa `Nodo::arrancar`.
#[cfg(test)]
mod pruebas_puerta_rat3 {
    use super::comprobar_puerta_rat3;
    use zx_consensus::transicion::ParametrosEvidencia;

    /// El perfil dev real (`R_slots = 600`, `Plazo_slots = 300`, `M_margen_slots = 60`) arranca.
    #[test]
    fn el_perfil_dev_real_pasa_la_puerta() {
        let evidencia = crate::perfil::parametros_evidencia_dev();
        assert!(comprobar_puerta_rat3(crate::perfil::R_SLOTS, &evidencia).is_ok());
    }

    /// Un perfil de prueba con `R_slots` demasiado corto para su propia ventana **no** arranca, y
    /// el error trae el mensaje con los números exactos.
    #[test]
    #[expect(clippy::unwrap_used, reason = "el test falla con panic por diseño")]
    fn un_perfil_que_incumple_rat3_no_arranca() {
        let evidencia = ParametrosEvidencia {
            plazo_slots: 300,
            m_margen_slots: 60,
            ..crate::perfil::parametros_evidencia_dev()
        };
        let err = comprobar_puerta_rat3(300, &evidencia).unwrap_err();
        let texto = err.to_string();
        assert!(texto.contains("puerta RAT-3"), "{texto}");
        assert!(texto.contains("300"), "{texto}");
        assert!(texto.contains("360"), "{texto}");
    }

    /// El caso límite exacto (`R_slots == Plazo_slots + M_margen_slots`) también incumple: la
    /// desigualdad es estricta (EV-15).
    #[test]
    fn el_limite_exacto_tambien_incumple() {
        let evidencia = ParametrosEvidencia {
            plazo_slots: 300,
            m_margen_slots: 60,
            ..crate::perfil::parametros_evidencia_dev()
        };
        assert!(comprobar_puerta_rat3(360, &evidencia).is_err());
        assert!(comprobar_puerta_rat3(361, &evidencia).is_ok());
    }
}

/// `ORDEN-W06d8` decisión 3 (V1): el fallo del hilo productor no es silencioso: se escribe el
/// evento crítico `fallo_productor` y se devuelve error (el proceso sale ≠ 0 por `main`).
#[cfg(test)]
#[expect(clippy::unwrap_used, reason = "el test falla con panic por diseño")]
mod pruebas_fallo_productor {
    use crate::registro::Registro;

    use super::escribir_fallo_productor;

    #[test]
    fn fallo_productor_escribe_evento_critico_y_devuelve_error() {
        let dir = tempfile::tempdir().unwrap();
        let registro = Registro::abrir(&dir.path().join("registro.jsonl")).unwrap();
        let err =
            escribir_fallo_productor(&registro, "respuesta con id 7 > esperado 2").unwrap_err();
        assert!(
            err.to_string().contains("fallo del hilo productor"),
            "{err}"
        );
        let texto = std::fs::read_to_string(dir.path().join("registro.jsonl")).unwrap();
        assert!(texto.contains("\"tipo\":\"fallo_productor\""), "{texto}");
        assert!(texto.contains("respuesta con id 7 > esperado 2"), "{texto}");
    }
}

/// `ORDEN-W06d1` V7: un bloque **propio** alterado, inyectado directamente en la tubería de
/// admisión (sin pasar por el minero), se rechaza con su motivo y no cambia el estado.
///
/// Es un test unitario (no de `tests/`) porque `admitir_pow_interno` es privado a propósito: la
/// tubería única (decisión 4) no tiene una puerta trasera pública para inyectar candidatos ya
/// verificados. La alteración es la más básica posible —un `nonce` que no cumple el PoW real, sin
/// minar— y por eso la rechaza ya el primer paso de la tubería (`validar_cabecera_pow`).
#[cfg(test)]
#[expect(clippy::expect_used, reason = "el test falla con panic por diseño")]
mod pruebas_v7 {
    use zx_core::preimage::block::merkle_root;

    use zx_core::txid;

    use super::{BlockHeader, Config, Nodo, Red};

    #[test]
    fn bloque_pow_propio_alterado_se_rechaza_y_no_cambia_el_estado() {
        let dir = tempfile::tempdir().expect("tempdir");
        let cfg = Config {
            dir_datos: dir.path().join("datos"),
            ruta_registro: dir.path().join("registro.jsonl"),
            red: Red::Dev,
            semilla: 7,
            indices_claves: vec![0],
            n_dev: 16,
            sr_dev: u64::MAX,
            parada_tras_slots: Some(0),
            dejar_de_producir_en_slot: None,
        };
        let mut nodo = Nodo::arrancar(&cfg).expect("arranque limpio");
        let estado_antes = nodo.resumen_estado_actual();

        #[expect(
            clippy::indexing_slicing,
            reason = "el arranque deja al menos el génesis"
        )]
        let ultimo = nodo.historial_pow[nodo.historial_pow.len() - 1];
        let clave = nodo.claves.first().expect("al menos una clave").pk;
        let coinbase = crate::pow::construir_coinbase_pow(clave, 1);
        let txid_coinbase = txid(&coinbase, nodo.cbid);
        let cabecera = BlockHeader {
            consensus_branch_id: nodo.cbid,
            prev_hash: ultimo.block_hash(),
            merkle_root: merkle_root(&[txid_coinbase]),
            timestamp: ultimo.timestamp + 10,
            bits: ultimo.bits,
            // `nonce = 0` sin minar: no cumple `hash_pow < target` salvo una casualidad
            // astronómicamente improbable con la dificultad inicial real de la red dev.
            nonce: 0,
            height: 1,
        };
        let hash_alterado = cabecera.block_hash();

        let resultado =
            nodo.admitir_pow_interno(cabecera, vec![coinbase], vec![Vec::new()], 0, true);
        assert!(
            resultado.is_err(),
            "un bloque propio con PoW inválido debe rechazarse"
        );
        assert!(
            !nodo.cadena.es_valido(&hash_alterado),
            "el bloque alterado no debe quedar admitido"
        );
        assert_eq!(
            nodo.resumen_estado_actual(),
            estado_antes,
            "el estado no debe cambiar tras el rechazo"
        );
    }
}

/// `ORDEN-W06d4` decisión 1/2: reproduce y corrige que el indicador local de depósito no sea
/// sensible a la rama (`REVISION-W06d3.md`, hipótesis del director).
///
/// Construye, con la tubería real de admisión (`admitir_pow_interno`, sin red), dos ramas PoW que
/// comparten el bloque `A1` (paga una coinbase a una clave propia): la rama `A` gasta esa coinbase
/// en su segundo bloque (el depósito F-15); la rama `B` (más pesada, sin ese depósito) se acaba
/// seleccionando por FC-3. Tras la reorganización, la coinbase de `A1` nunca se gastó en la rama
/// `B`: `preparar_depositos`, evaluado sobre la punta ya seleccionada, debe volver a proponerla.
#[cfg(test)]
#[expect(
    clippy::expect_used,
    clippy::panic,
    reason = "el test falla con panic por diseño"
)]
mod pruebas_deposito_sensible_a_la_rama {
    use zx_consensus::PARAMETROS_POW_DEV;
    use zx_core::preimage::block::merkle_root;
    use zx_core::txid as calc_txid;

    use super::{BlockHeader, Config, Nodo, Red};
    use crate::claves::ClaveDev;
    use crate::pow;

    fn cabecera(prev: BlockHeader, height: u32, txids: &[zx_core::TxId], cbid: u32) -> BlockHeader {
        BlockHeader {
            consensus_branch_id: cbid,
            prev_hash: prev.block_hash(),
            merkle_root: merkle_root(txids),
            timestamp: prev.timestamp + 1,
            bits: PARAMETROS_POW_DEV.bits_iniciales,
            nonce: 0,
            height,
        }
    }

    #[test]
    fn preparar_depositos_vuelve_a_depositar_tras_perder_el_bloque_del_deposito() {
        let dir = tempfile::tempdir().expect("tempdir");
        let cfg = Config {
            dir_datos: dir.path().join("datos"),
            ruta_registro: dir.path().join("registro.jsonl"),
            red: Red::Dev,
            semilla: 11,
            indices_claves: vec![0],
            n_dev: 16,
            sr_dev: u64::MAX,
            parada_tras_slots: Some(0),
            dejar_de_producir_en_slot: None,
        };
        let mut nodo = Nodo::arrancar(&cfg).expect("arranque limpio");
        let clave_propia = nodo.claves.first().cloned().expect("al menos una clave");
        let clave_ajena = ClaveDev::derivar(cfg.semilla, 999);
        let cbid = nodo.cbid;

        #[expect(
            clippy::indexing_slicing,
            reason = "el arranque deja al menos el génesis"
        )]
        let genesis = nodo.historial_pow[0];

        // A1 (altura 1, común a las dos ramas): coinbase paga a la clave propia.
        let cb_a1 = pow::construir_coinbase_pow(clave_propia.pk, 1);
        #[expect(clippy::indexing_slicing, reason = "una coinbase tiene una salida")]
        let valor_a1 = cb_a1.outputs[0].value;
        let txid_a1 = calc_txid(&cb_a1, cbid);
        let cab_a1 = cabecera(genesis, 1, &[txid_a1], cbid);
        nodo.admitir_pow_interno(cab_a1, vec![cb_a1], vec![Vec::new()], 0, false)
            .expect("A1 se admite");

        // M2..M6 (comunes a las dos ramas): solo hacen madurar la coinbase de A1 (`M_CB = 5`:
        // madura en la altura 6). Ninguno la toca.
        let mut prev = cab_a1;
        for altura in 2..=6u32 {
            let cb = pow::construir_coinbase_pow(clave_ajena.pk, altura);
            let txid_cb = calc_txid(&cb, cbid);
            let cab = cabecera(prev, altura, &[txid_cb], cbid);
            nodo.admitir_pow_interno(cab, vec![cb], vec![Vec::new()], 0, false)
                .unwrap_or_else(|e| panic!("M{altura} se admite: {e}"));
            prev = cab;
        }
        let cab_m6 = prev;

        // A7 (altura 7, rama A): la coinbase de A1 ya está madura; la gasta con el depósito F-15.
        let (tx_deposito, testigos_deposito) =
            pow::construir_deposito(txid_a1, valor_a1, &clave_propia, 0, cbid)
                .expect("depósito firmado");
        let cb_a7 = pow::construir_coinbase_pow(clave_ajena.pk, 7);
        let txid_a7 = calc_txid(&cb_a7, cbid);
        let txid_dep = calc_txid(&tx_deposito, cbid);
        let cab_a7 = cabecera(cab_m6, 7, &[txid_a7, txid_dep], cbid);
        nodo.admitir_pow_interno(
            cab_a7,
            vec![cb_a7, tx_deposito],
            vec![Vec::new(), testigos_deposito],
            0,
            false,
        )
        .expect("A7 (con el depósito) se admite");

        // Antes de la reorganización: la rama seleccionada es A7, donde la coinbase de A1 ya se
        // gastó; no hay nada pendiente que depositar.
        let depositos_antes = nodo
            .preparar_depositos(10)
            .expect("preparar_depositos (antes de la reorganización)");
        assert!(
            depositos_antes.is_empty(),
            "tras depositar en A7 no debería haber depósitos pendientes todavía"
        );

        // Rama B (más pesada, sin el depósito): B7, B8, ambas descendientes de M6 (no de A7), sin
        // gastar la coinbase de A1. Dos bloques (B7, B8) pesan más que el único bloque de la rama A
        // (A7) desde el ancestro común M6, así que FC-3 debe conmutar la selección.
        let mut prev = cab_m6;
        for altura in 7..=8u32 {
            let cb = pow::construir_coinbase_pow(clave_ajena.pk, altura);
            let txid_cb = calc_txid(&cb, cbid);
            let cab = cabecera(prev, altura, &[txid_cb], cbid);
            nodo.admitir_pow_interno(cab, vec![cb], vec![Vec::new()], 0, false)
                .unwrap_or_else(|e| panic!("B{altura} se admite: {e}"));
            prev = cab;
        }
        let punta_b = prev.block_hash();
        assert_eq!(
            nodo.cadena.mejor_punta_pow(),
            Some(punta_b),
            "la rama B, más pesada, debe ser la punta PoW seleccionada (FC-3)"
        );
        assert_eq!(
            nodo.historial_pow.last().map(BlockHeader::block_hash),
            Some(punta_b),
            "historial_pow debe reflejar la reorganización a la rama B"
        );

        // La coinbase de A1 nunca se gastó en la rama B: sigue viva (sin gastar) en su estado.
        let estado_b = nodo
            .cadena
            .estado_post(&punta_b)
            .expect("estado de la punta B");
        assert!(
            estado_b.utxo.contains_key(&zx_core::OutPoint {
                prev_txid: txid_a1,
                prev_index: 0,
            }),
            "la coinbase de A1 debe seguir viva (sin gastar) en el estado de la rama B"
        );

        // La corrección (`ORDEN-W06d4` decisión 2): evaluado sobre la rama B ya seleccionada,
        // `preparar_depositos` debe volver a proponer el depósito de la coinbase de A1 (madura en
        // la altura 1 + M_CB(5) = 6; se evalúa en la altura 8). Con el indicador local
        // `depositada` (bug de `ORDEN-W06d3`, `PROGRESO.md`), esta lista queda vacía: el nodo
        // nunca vuelve a intentar depositar esa coinbase, y con ella nunca reúne `Φ`.
        let depositos_despues = nodo
            .preparar_depositos(8)
            .expect("preparar_depositos (después de la reorganización)");
        assert!(
            depositos_despues
                .iter()
                .any(|(tx, _)| tx.inputs.first().map(|i| i.outpoint.prev_txid) == Some(txid_a1)),
            "tras perder el bloque del depósito por la reorganización, el nodo debe volver a \
             proponer el depósito de la coinbase de A1 (bug de ORDEN-W06d3, corregido en \
             ORDEN-W06d4)"
        );
    }
}

/// `ORDEN-W06d6`, paso previo (RI-3c H1, `REVISION-RI-3c.md`): el orden **admitir → persistir**
/// (sustituye al orden de RI-2b, persistir → admitir) impide la entrada fantasma que bloqueaba el
/// reinicio, y el punto de inyección de fallo entre admitir y persistir no deja rastro observable.
#[cfg(test)]
#[expect(
    clippy::expect_used,
    clippy::indexing_slicing,
    reason = "el test falla con panic por diseño"
)]
mod pruebas_ri3c_orden_admitir_persistir {
    use core::sync::atomic::AtomicBool;

    use zx_consensus::{PARAMETROS_POW_DEV, Sha3Dev, minar};
    use zx_core::preimage::block::{BlockHeader, merkle_root};
    use zx_core::{Amount, decodificar_con, txid};

    use zx_storage::Almacen as _;

    use super::{Config, Nodo, Red};
    use crate::pow;

    fn cfg_de_test(dir: &std::path::Path) -> Config {
        Config {
            dir_datos: dir.join("datos"),
            ruta_registro: dir.join("registro.jsonl"),
            red: Red::Dev,
            semilla: 42,
            indices_claves: vec![0],
            n_dev: 16,
            sr_dev: u64::MAX,
            parada_tras_slots: Some(0),
            dejar_de_producir_en_slot: None,
        }
    }

    /// Mina un PoW real de altura 1 sobre el génesis del nodo, con la coinbase que se le pase (para
    /// poder viciarla y forzar un rechazo del motor de transición sin tocar el PoW en sí).
    fn minar_altura_1(nodo: &Nodo, mut coinbase: zx_core::Tx, importe: i64) -> BlockHeader {
        coinbase.outputs[0].value = Amount::nuevo(importe).expect("importe representable");
        let genesis = nodo.historial_pow[nodo.historial_pow.len() - 1];
        let txid_coinbase = txid(&coinbase, nodo.cbid);
        let target = decodificar_con(
            PARAMETROS_POW_DEV.bits_iniciales,
            &PARAMETROS_POW_DEV.limites,
        )
        .expect("bits_iniciales decodifica");
        let cabecera_base = BlockHeader {
            consensus_branch_id: nodo.cbid,
            prev_hash: genesis.block_hash(),
            merkle_root: merkle_root(&[txid_coinbase]),
            timestamp: genesis.timestamp + 1,
            bits: PARAMETROS_POW_DEV.bits_iniciales,
            nonce: 0,
            height: 1,
        };
        let cancelar = AtomicBool::new(false);
        minar(&cabecera_base, target, &Sha3Dev, u64::MAX, &cancelar)
            .expect("un PoW real se encuentra con la dificultad dev inicial (~2^17 intentos)")
    }

    /// **Regresión de RI-3c H1** (test adaptado de `resultados-RI-3c/ri3c_nodo.diff`, con las
    /// aserciones invertidas a lo correcto tras la corrección — el original, ejecutado tal cual
    /// contra la base sin corregir, se conservó como evidencia "antes" en
    /// `deepseek/W06d6/logs/RI-3c-antes.log`): una coinbase que paga de más se **rechaza** por
    /// `ErrEmision` y, con el orden nuevo, **nunca llega a persistirse** — el registro sigue en 1
    /// (solo el génesis) tras el rechazo, y el nodo **reinicia sin problema**.
    #[test]
    fn bloque_pow_propio_rechazado_no_persiste_y_el_reinicio_funciona() {
        let dir = tempfile::tempdir().expect("tempdir");
        let cfg = cfg_de_test(dir.path());
        let mut nodo = Nodo::arrancar(&cfg).expect("arranque limpio");
        let clave = nodo.claves.first().expect("al menos una clave").pk;

        // Coinbase que paga **más** que `subsidio_pow(1)` (perfil dev: 50 ZZK): el motor de
        // transición la rechaza con `ErrEmision` (`Interno` para `crate::rechazo`).
        let coinbase = pow::construir_coinbase_pow(clave, 1);
        let cabecera_minada = minar_altura_1(&nodo, coinbase.clone(), 51);
        let hash = cabecera_minada.block_hash();
        let mut coinbase_viciada = coinbase;
        coinbase_viciada.outputs[0].value = Amount::nuevo(51).expect("importe representable");

        let resultado = nodo.admitir_pow_interno(
            cabecera_minada,
            vec![coinbase_viciada],
            vec![Vec::new()],
            0,
            true,
        );
        assert!(
            resultado.is_err(),
            "la coinbase con importe incorrecto debe rechazarse"
        );
        assert!(
            !nodo.cadena.es_valido(&hash),
            "el bloque rechazado no debe quedar admitido en zx-cadena"
        );

        // La corrección: admitir se intenta **antes** de persistir, así que un rechazo no deja
        // ninguna entrada fantasma en el almacén.
        let longitud_tras_rechazo = nodo
            .almacen
            .longitud_registro()
            .expect("longitud del almacén");
        assert_eq!(
            longitud_tras_rechazo, 1,
            "el bloque rechazado NO debe persistirse: el registro solo tiene el génesis"
        );

        drop(nodo);

        // El reinicio ya no repite ninguna entrada fantasma: debe funcionar sin más.
        let reinicio = Nodo::arrancar(&cfg);
        if let Err(e) = &reinicio {
            eprintln!("RI-3c (corregido): Nodo::arrancar (reinicio) devolvió Err inesperado: {e}");
        }
        assert!(
            reinicio.is_ok(),
            "el reinicio debe funcionar: el bloque rechazado nunca se persistió, así que no hay \
             nada que repetir ni que vuelva a fallar"
        );
    }

    /// **Punto de inyección de fallo entre admitir y persistir** (decisión 7, paso previo): se
    /// admite un bloque PoW **válido** en `zx-cadena` (memoria) replicando exactamente los pasos
    /// de `admitir_pow_interno` hasta ese punto, y se simula la caída del proceso **sin** llegar a
    /// `almacen.admitir` (el paso siguiente, que esta prueba omite a propósito). Comprueba que:
    /// (a) nada se difunde — estructuralmente imposible, porque `difundir_si_hay_red` solo se
    /// llama *después* de que `admitir_pow_interno` devuelva `Ok`, y aquí nunca se completa esa
    /// llamada; y (b) el nodo reinicia bien — el bloque "caído" no está en el almacén, así que el
    /// reinicio simplemente no lo ve, sin fallar ni dejar rastro.
    #[test]
    fn fallo_entre_admitir_y_persistir_no_deja_rastro_y_el_reinicio_funciona() {
        use zx_cadena::BloqueCadena;
        use zx_consensus::genesis::HASH_GENESIS_DEV;
        use zx_consensus::transicion::{BloqueTransicion, HechosCabecera};
        use zx_core::digest::Digest;
        use zx_core::{BlockHash, trabajo_bloque};

        let dir = tempfile::tempdir().expect("tempdir");
        let cfg = cfg_de_test(dir.path());
        let mut nodo = Nodo::arrancar(&cfg).expect("arranque limpio");
        let clave = nodo.claves.first().expect("al menos una clave").pk;

        let coinbase = pow::construir_coinbase_pow(clave, 1);
        let cabecera_minada = minar_altura_1(&nodo, coinbase.clone(), 50); // subsidio exacto: válido
        let hash = cabecera_minada.block_hash();

        // Replica el paso "admitir en zx-cadena" de `admitir_pow_interno`, **sin** el paso
        // siguiente (`almacen.admitir`) — exactamente el instante en que un `SIGKILL` real
        // interrumpiría entre los dos.
        let target = zx_core::decodificar_con(
            zx_consensus::PARAMETROS_POW_DEV.bits_iniciales,
            &zx_consensus::PARAMETROS_POW_DEV.limites,
        )
        .expect("bits decodifica");
        let trabajo = trabajo_bloque(target).expect("trabajo del bloque");
        let hechos = HechosCabecera::PoW {
            hash,
            padre: cabecera_minada.prev_hash,
            altura: cabecera_minada.height,
            trabajo,
            pow_valido: true,
        };
        let bt = BloqueTransicion::nuevo(hechos, vec![(coinbase, vec![Vec::new()])]);
        nodo.cadena
            .admitir(BloqueCadena::Pow(bt))
            .expect("un bloque válido se admite en memoria");
        assert!(
            nodo.cadena.es_valido(&hash),
            "el bloque queda admitido en memoria (paso 1, ya ocurrió)"
        );

        // "Caída": el proceso termina aquí, sin haber llegado a `almacen.admitir` (paso 2) ni,
        // mucho menos, a la difusión (paso 3, posterior en el llamante real). No hay manejo de red
        // en este nodo de test, así que "no se difunde" es además estructuralmente cierto: no hay
        // ningún `ManijaRed` al que `difundir_si_hay_red` pudiera llamar.
        assert!(
            nodo.red.is_none(),
            "sin red conectada: no hay a quién difundir nada"
        );
        let longitud_antes_de_caer = nodo
            .almacen
            .longitud_registro()
            .expect("longitud del almacén");
        assert_eq!(
            longitud_antes_de_caer, 1,
            "el bloque admitido en memoria todavía NO está en el almacén: la caída simulada \
             ocurre exactamente antes de persistir"
        );
        drop(nodo);

        // El reinicio: el bloque "caído" no está en el almacén, así que sencillamente no existe
        // para el nodo que reinicia — ni error, ni entrada fantasma, ni doble firma observable
        // (nunca se difundió; RI-2b quedaba a salvo por eso, no por el orden de escritura).
        let reinicio = Nodo::arrancar(&cfg).expect("el reinicio debe funcionar sin problema");
        assert_eq!(
            reinicio.historial_pow.len(),
            1,
            "el reinicio solo ve el génesis: el bloque de altura 1 nunca se persistió"
        );
        assert_eq!(
            reinicio.headers_pow.keys().find(|h| **h == hash),
            None,
            "el bloque que 'cayó' entre admitir y persistir no reaparece tras el reinicio"
        );
        // El génesis dev es una constante fija; comprobación de sanidad de que el reinicio partió
        // del mismo génesis, no de uno distinto por accidente.
        assert_eq!(
            reinicio.historial_pow[0].block_hash(),
            BlockHash::from_digest(Digest::from_bytes(HASH_GENESIS_DEV))
        );
    }
}

/// `ORDEN-W06d6` decisión 5: test pendiente de `ORDEN-W06d5` (la cola de `post_pendientes`) — se
/// verificaba solo con ejecuciones reales, sin test unitario del propio tope.
#[cfg(test)]
#[expect(
    clippy::unwrap_used,
    clippy::expect_used,
    reason = "el test falla con panic por diseño"
)]
mod pruebas_cola_post_pendientes {
    use zx_core::digest::{BlockHash, BodyCommitment, Digest, MerkleRoot};
    use zx_core::preimage::dag::{DagBlockHeader, PadresDag, SolucionPoas};
    use zx_core::wire_dag::{BloqueDag, JustificacionPot, PotCheckpoints};

    use super::{Config, Nodo, Red};

    fn cabecera_post(slot: u64) -> DagBlockHeader {
        DagBlockHeader {
            consensus_branch_id: 0xa8b4_66a7,
            merkle_root: MerkleRoot::from_digest(Digest::from_bytes([(slot % 251) as u8; 32])),
            timestamp: 1_000 + slot,
            height: 0,
            slot,
            pot_output: [0; 16],
            rango_solucion: 1,
            sol: SolucionPoas::default(),
            body_commitment: BodyCommitment::from_digest(Digest::from_bytes([0xAA; 32])),
            padres: PadresDag::nuevo(BlockHash::from_digest(Digest::from_bytes([0xEE; 32])), &[])
                .unwrap(),
            sello: [0; 64],
        }
    }

    fn bloque_post_de_prueba(slot: u64) -> BloqueDag {
        let portador = PotCheckpoints::desde_outputs([[0; 16]; 8]);
        let justificacion = JustificacionPot::nueva(vec![portador]).unwrap();
        BloqueDag::nuevo(cabecera_post(slot), justificacion, Vec::new(), Vec::new()).unwrap()
    }

    fn nodo_de_prueba(dir: &std::path::Path) -> Nodo {
        let cfg = Config {
            dir_datos: dir.join("datos"),
            ruta_registro: dir.join("registro.jsonl"),
            red: Red::Dev,
            semilla: 1,
            indices_claves: vec![0],
            n_dev: 16,
            sr_dev: u64::MAX,
            parada_tras_slots: Some(0),
            dejar_de_producir_en_slot: None,
        };
        Nodo::arrancar(&cfg).expect("arranque limpio")
    }

    /// **Regresión de la decisión 3 extendida (`ORDEN-W06d5`).** La cola de `Pendiente` está
    /// acotada a `TOPE_POST_PENDIENTES` (64): superarlo descarta el más viejo (FIFO), nunca crece
    /// sin límite.
    #[test]
    fn la_cola_de_pendientes_esta_acotada_y_descarta_el_mas_viejo() {
        let dir = tempfile::tempdir().expect("tempdir");
        let mut nodo = nodo_de_prueba(dir.path());

        assert!(nodo.post_pendientes.is_empty());

        // Encolar bastantes más que el tope: cada slot es distinto para poder identificar cuál
        // sobrevive.
        let total = super::TOPE_POST_PENDIENTES * 2;
        for slot in 0..total {
            nodo.encolar_post_pendiente(
                bloque_post_de_prueba(slot as u64),
                std::time::Instant::now(),
            );
        }

        assert_eq!(
            nodo.post_pendientes.len(),
            super::TOPE_POST_PENDIENTES,
            "la cola nunca debe superar el tope declarado"
        );
        // FIFO: sobreviven los `TOPE_POST_PENDIENTES` últimos, no los primeros.
        let primero_que_sobrevive = nodo.post_pendientes.front().expect("no vacía");
        assert_eq!(
            primero_que_sobrevive.0.cabecera.slot,
            (total - super::TOPE_POST_PENDIENTES) as u64,
            "el más viejo de los que sobreviven es exactamente el primero no descartado"
        );
        let ultimo = nodo.post_pendientes.back().expect("no vacía");
        assert_eq!(ultimo.0.cabecera.slot, (total - 1) as u64);
    }
}

/// `ORDEN-W07a-R`: cobertura de eventos de diagnóstico que no aparecen en V3. Los tres se emiten en
/// rutas que un nodo sin red puede recorrer con bloques construidos a mano (sin minar); así cada uno
/// queda producido al menos una vez por un test, como pide la tabla de cobertura de la orden.
#[cfg(test)]
#[expect(
    clippy::expect_used,
    clippy::unwrap_used,
    reason = "el test falla con panic por diseño"
)]
mod pruebas_diagnostico_registro {
    use std::time::Instant;

    use zx_core::digest::{BlockHash, BodyCommitment, Digest, MerkleRoot};
    use zx_core::preimage::block::BlockHeader;
    use zx_core::preimage::dag::{DagBlockHeader, PadresDag, SolucionPoas};
    use zx_core::wire_dag::{JustificacionPot, PotCheckpoints};
    use zx_p2p::entrante::VeredictoFinal;
    use zx_p2p::mensaje::BloqueRed;

    use super::{Config, Nodo, Red};

    fn cfg(dir: &std::path::Path) -> Config {
        Config {
            dir_datos: dir.join("datos"),
            ruta_registro: dir.join("registro.jsonl"),
            red: Red::Dev,
            semilla: 1,
            indices_claves: vec![0],
            n_dev: 16,
            sr_dev: u64::MAX,
            parada_tras_slots: Some(0),
            dejar_de_producir_en_slot: None,
        }
    }

    fn h(n: u8) -> BlockHash {
        BlockHash::from_digest(Digest::from_bytes([n; 32]))
    }

    fn bloque_pow_red(nonce: u64, prev: BlockHash) -> BloqueRed {
        BloqueRed::Pow {
            cabecera: BlockHeader {
                consensus_branch_id: 0xa8b4_66a7,
                prev_hash: prev,
                merkle_root: MerkleRoot::from_digest(Digest::from_bytes([0x33; 32])),
                timestamp: 1_000 + nonce,
                bits: 0x1c07_fff8,
                nonce,
                height: 1,
            },
            txs: Vec::new(),
            testigos: Vec::new(),
        }
    }

    fn bloque_post_red(slot: u64, padre: BlockHash) -> BloqueRed {
        let cabecera = DagBlockHeader {
            consensus_branch_id: 0xa8b4_66a7,
            merkle_root: MerkleRoot::from_digest(Digest::from_bytes([0x44; 32])),
            timestamp: 1_000 + slot,
            height: 0,
            slot,
            pot_output: [0; 16],
            rango_solucion: 1,
            sol: SolucionPoas::default(),
            body_commitment: BodyCommitment::from_digest(Digest::from_bytes([0x55; 32])),
            padres: PadresDag::nuevo(padre, &[]).unwrap(),
            sello: [0; 64],
        };
        let portador = PotCheckpoints::desde_outputs([[0; 16]; 8]);
        let justificacion = JustificacionPot::nueva(vec![portador]).unwrap();
        BloqueRed::Post {
            cabecera,
            justificacion,
            txs: Vec::new(),
            testigos: Vec::new(),
        }
    }

    fn registro(dir: &std::path::Path) -> String {
        std::fs::read_to_string(dir.join("registro.jsonl")).expect("leer registro")
    }

    /// Un PoST de red en fase PoW pura (sin candidatos) deja la traza del §1 bis
    /// `bloque_post_de_red_sin_terminal`.
    #[test]
    fn un_post_sin_terminal_candidato_traza_sin_terminal() {
        let dir = tempfile::tempdir().expect("tempdir");
        let mut nodo = Nodo::arrancar(&cfg(dir.path())).expect("arranque limpio");
        let bloque = bloque_post_red(1, h(0xAB));
        let veredicto = nodo.intentar_admitir_bloque_red(&bloque, None, Instant::now());
        assert_eq!(veredicto, VeredictoFinal::Ignorar);
        let texto = registro(dir.path());
        assert!(
            texto.contains("\"tipo\":\"bloque_post_de_red_sin_terminal\""),
            "falta bloque_post_de_red_sin_terminal: {texto}"
        );
    }

    /// El cupo por padre del depósito de huérfanos, al llenarse, traza `huerfano_desalojado`.
    #[test]
    fn el_cupo_por_padre_traza_el_desalojo_de_huerfanos() {
        let dir = tempfile::tempdir().expect("tempdir");
        let mut nodo = Nodo::arrancar(&cfg(dir.path())).expect("arranque limpio");
        // Mismo padre ausente para todos: al pasar de `MAX_HUERFANOS_POR_PADRE` hay desalojo FIFO.
        let padre = h(0xCD);
        for i in 0..=(crate::red::MAX_HUERFANOS_POR_PADRE as u64) {
            let bloque = bloque_pow_red(i, padre);
            let _ = nodo.intentar_admitir_bloque_red(&bloque, None, Instant::now());
        }
        let texto = registro(dir.path());
        assert!(
            texto.contains("\"tipo\":\"huerfano_desalojado\""),
            "falta huerfano_desalojado: {texto}"
        );
    }

    /// Un huérfano que sale del depósito al resolverse su padre traza `huerfano_resuelto`.
    #[test]
    fn un_huerfano_retirado_del_deposito_traza_su_resolucion() {
        let dir = tempfile::tempdir().expect("tempdir");
        let mut nodo = Nodo::arrancar(&cfg(dir.path())).expect("arranque limpio");
        let padre = h(0xEE);
        let bloque = bloque_pow_red(7, padre);
        let _ = nodo.intentar_admitir_bloque_red(&bloque, None, Instant::now());
        // Simula que `padre` acaba de admitirse: el depósito entrega al hijo y este se reintenta.
        nodo.resolver_huerfanos_de(padre);
        let texto = registro(dir.path());
        assert!(
            texto.contains("\"tipo\":\"huerfano_resuelto\""),
            "falta huerfano_resuelto: {texto}"
        );
    }
}

/// `ORDEN-W06d10-B`: X1/X2/X3 no penalizan al par en ninguna de las dos rutas y lo demostrablemente
/// inválido sigue penalizando (V1/V2). Bloque PoW de altura 1 con **PoW real** minado, para que X1
/// (timestamp futuro) falle exactamente en la comprobación FTL y no antes.
#[cfg(test)]
#[expect(
    clippy::expect_used,
    clippy::indexing_slicing,
    reason = "el test falla con panic por diseño"
)]
mod pruebas_w06d10b {
    use core::sync::atomic::AtomicBool;
    use std::time::Instant;

    use zx_consensus::{PARAMETROS_POW_DEV, Sha3Dev, minar};
    use zx_core::digest::Digest;
    use zx_core::preimage::block::{BlockHeader, merkle_root};
    use zx_core::{Amount, BlockHash, Tx, decodificar_con, txid};
    use zx_p2p::entrante::VeredictoFinal;
    use zx_p2p::mensaje::BloqueRed;

    use super::{Config, ErrorNodo, Nodo, Red};
    use crate::pow;
    use crate::rechazo::ClasificacionRechazo;

    fn cfg(dir: &std::path::Path) -> Config {
        Config {
            dir_datos: dir.join("datos"),
            ruta_registro: dir.join("registro.jsonl"),
            red: Red::Dev,
            semilla: 7,
            indices_claves: vec![0],
            n_dev: 16,
            sr_dev: u64::MAX,
            parada_tras_slots: Some(0),
            dejar_de_producir_en_slot: None,
        }
    }

    /// `FTL_dev = N·T/20 = 20·2/20 = 2 s` (`PARAMETROS_POW_DEV`): margen conocido de X1.
    const FTL_DEV_SEG: u64 = 2;

    fn ahora_seg() -> u64 {
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .expect("reloj posterior a 1970")
            .as_secs()
    }

    /// Cabecera PoW de altura 1 sobre el génesis del nodo con la `coinbase` dada y `timestamp`
    /// elegido, con PoW real minado. `bits`/target son los iniciales dev: un bloque válido.
    fn cabecera_altura_1(nodo: &Nodo, coinbase: Tx, timestamp: u64) -> BlockHeader {
        let genesis = nodo.historial_pow[nodo.historial_pow.len() - 1];
        let txid_coinbase = txid(&coinbase, nodo.cbid);
        let target = decodificar_con(
            PARAMETROS_POW_DEV.bits_iniciales,
            &PARAMETROS_POW_DEV.limites,
        )
        .expect("bits_iniciales decodifica");
        let cabecera_base = BlockHeader {
            consensus_branch_id: nodo.cbid,
            prev_hash: genesis.block_hash(),
            merkle_root: merkle_root(&[txid_coinbase]),
            timestamp,
            bits: PARAMETROS_POW_DEV.bits_iniciales,
            nonce: 0,
            height: 1,
        };
        let cancelar = AtomicBool::new(false);
        minar(&cabecera_base, target, &Sha3Dev, u64::MAX, &cancelar)
            .expect("un PoW dev se encuentra en ~2^17 intentos")
    }

    fn coinbase_valida(nodo: &Nodo) -> Tx {
        let clave = nodo.claves.first().expect("al menos una clave").pk;
        pow::construir_coinbase_pow(clave, 1)
    }

    fn bloque_pow_red(cabecera: BlockHeader, coinbase: Tx) -> BloqueRed {
        BloqueRed::Pow {
            cabecera,
            txs: vec![coinbase],
            testigos: vec![Vec::new()],
        }
    }

    fn registro(dir: &std::path::Path) -> String {
        std::fs::read_to_string(dir.join("registro.jsonl")).expect("leer registro")
    }

    /// `ORDEN-W06d10-B` **X1** en las dos rutas: un PoW con `timestamp > reloj + FTL` (FTL dev
    /// `= 20·2/20 = 2 s`) es `Ignorar`, no se cachea ni penaliza, y al reenviarlo con el reloj
    /// local ya al día se admite (C-TS-03: se difiere, no se castiga). El reloj se inyecta
    /// (`reloj_local_simulado`) para no depender del reloj real de la máquina.
    #[test]
    fn x1_timestamp_futuro_se_ignora_y_se_admite_al_avanzar_el_reloj() {
        let dir = tempfile::tempdir().expect("tempdir");
        let mut nodo = Nodo::arrancar(&cfg(dir.path())).expect("arranque limpio");
        let genesis_ts = i64::try_from(nodo.historial_pow[0].timestamp).unwrap_or(0);
        let reloj0 = genesis_ts + 1000;
        nodo.reloj_local_simulado = Some(reloj0);
        // `FTL_dev + 2 s`: por encima del FTL de 2 s (y con margen).
        let ts = u64::try_from(reloj0 + (FTL_DEV_SEG as i64) + 2).expect("timestamp representable");
        let cabecera = cabecera_altura_1(&nodo, coinbase_valida(&nodo), ts);
        let hash = cabecera.block_hash();
        let bloque = bloque_pow_red(cabecera, coinbase_valida(&nodo));

        // Ruta gossip (`origen = None`).
        assert_eq!(
            nodo.intentar_admitir_bloque_red(&bloque, None, Instant::now()),
            VeredictoFinal::Ignorar,
            "C-TS-03: el bloque futuro se difiere, no se rechaza"
        );
        assert!(
            nodo.cadena.motivo(&hash).is_none(),
            "X1 no debe cachearse como inválido en zx-cadena"
        );
        assert!(
            !nodo.headers_pow.contains_key(&hash),
            "X1 no debe cachearse en headers_pow"
        );
        let texto = registro(dir.path());
        assert!(
            texto.contains("\"tipo\":\"bloque_red_vista_local\""),
            "falta la traza de vista local: {texto}"
        );
        assert!(
            !texto.contains("\"tipo\":\"par_penalizado\""),
            "X1 no debe penalizar al par: {texto}"
        );

        // El reloj local avanza (la vista cambia): el mismo bloque vuelve a juzgarse por la ruta de
        // sincronización y pasa.
        nodo.reloj_local_simulado = Some(reloj0 + (FTL_DEV_SEG as i64) + 2);
        assert_eq!(
            nodo.intentar_admitir_bloque_red(
                &bloque,
                Some(libp2p::PeerId::random()),
                Instant::now()
            ),
            VeredictoFinal::Aceptar,
            "con el reloj al día el mismo bloque debe admitirse"
        );
        assert!(nodo.cadena.es_valido(&hash));
        assert!(registro(dir.path()).contains("\"tipo\":\"bloque_red_admitido\""));
    }

    /// `ORDEN-W06d10-B` **X3** en las dos rutas: un fallo **local** (persistencia/servicio
    /// simulado) es `Ignorar`, queda registrado con su motivo y no penaliza; sin el fallo, el mismo
    /// bloque válido se admite (no quedó cacheado).
    #[test]
    fn x3_fallo_local_se_ignora_y_se_registra() {
        let dir = tempfile::tempdir().expect("tempdir");
        let mut nodo = Nodo::arrancar(&cfg(dir.path())).expect("arranque limpio");
        let cabecera = cabecera_altura_1(&nodo, coinbase_valida(&nodo), ahora_seg());
        let hash = cabecera.block_hash();
        let bloque = bloque_pow_red(cabecera, coinbase_valida(&nodo));

        nodo.fallo_local_simulado = Some("persistencia simulada de prueba".to_string());
        assert_eq!(
            nodo.intentar_admitir_bloque_red(
                &bloque,
                Some(libp2p::PeerId::random()),
                Instant::now()
            ),
            VeredictoFinal::Ignorar,
            "un fallo local no es defecto del candidato"
        );
        let texto = registro(dir.path());
        assert!(
            texto.contains("\"tipo\":\"bloque_red_vista_local\""),
            "falta la traza del fallo local: {texto}"
        );
        assert!(
            texto.contains("persistencia simulada de prueba"),
            "el motivo local debe quedar visible: {texto}"
        );
        assert!(!texto.contains("\"tipo\":\"par_penalizado\""), "{texto}");
        assert!(
            !texto.contains("\"tipo\":\"bloque_red_admitido\""),
            "{texto}"
        );
        assert!(nodo.cadena.motivo(&hash).is_none());

        // Sin fallo, el bloque válido se admite: el `Ignorar` no dejó nada cacheado.
        assert_eq!(
            nodo.intentar_admitir_bloque_red(&bloque, None, Instant::now()),
            VeredictoFinal::Aceptar
        );
    }

    /// `ORDEN-W06d10-B` **V2** (regresión): un bloque **demostrablemente** inválido (coinbase que
    /// paga de más, `ErrEmision`) sigue dando `Rechazar` en las dos rutas, también cuando ya está
    /// cacheado el motivo.
    #[test]
    fn v2_defecto_demostrable_sigue_rechazando() {
        let dir = tempfile::tempdir().expect("tempdir");
        let mut nodo = Nodo::arrancar(&cfg(dir.path())).expect("arranque limpio");
        let clave = nodo.claves.first().expect("al menos una clave").pk;
        let mut coinbase = pow::construir_coinbase_pow(clave, 1);
        let doble = coinbase.outputs[0]
            .value
            .brek()
            .checked_mul(2)
            .expect("sin desbordar");
        coinbase.outputs[0].value = Amount::nuevo(doble).expect("importe representable");
        let cabecera = cabecera_altura_1(&nodo, coinbase.clone(), ahora_seg());
        let hash = cabecera.block_hash();
        let bloque = bloque_pow_red(cabecera, coinbase);

        // Primer intento (gossip): defecto demostrable del candidato → Rechazar.
        assert_eq!(
            nodo.intentar_admitir_bloque_red(&bloque, None, Instant::now()),
            VeredictoFinal::Rechazar
        );
        // El motivo queda cacheado; un reenvío por sincronización tampoco se libra.
        assert!(nodo.cadena.motivo(&hash).is_some());
        assert_eq!(
            nodo.intentar_admitir_bloque_red(
                &bloque,
                Some(libp2p::PeerId::random()),
                Instant::now()
            ),
            VeredictoFinal::Rechazar
        );
        assert!(
            registro(dir.path()).contains("\"tipo\":\"bloque_red_rechazado\""),
            "lo demostrablemente inválido debe seguir registrándose como rechazo"
        );
    }

    /// El mapeo de errores del borde de red: solo un defecto atribuible al candidato penaliza; un
    /// fallo local (`Otro`/`Almacen`/…) o una clasificación de vista local, no.
    #[test]
    fn solo_el_defecto_del_candidato_penaliza() {
        let hash = BlockHash::from_digest(Digest::from_bytes([0x42; 32]));
        let con_clasificacion = |clasificacion| ErrorNodo::BloquePropioRechazado {
            hash,
            motivo: "prueba".to_string(),
            clasificacion,
        };
        assert!(super::error_atribuible_al_candidato(&con_clasificacion(
            ClasificacionRechazo::Interno
        )));
        assert!(super::error_atribuible_al_candidato(&con_clasificacion(
            ClasificacionRechazo::Legitimo
        )));
        for local in [
            ClasificacionRechazo::VistaLocal,
            ClasificacionRechazo::Pendiente,
            ClasificacionRechazo::ImposibleSinPenalizar,
        ] {
            assert!(
                !super::error_atribuible_al_candidato(&con_clasificacion(local)),
                "{local:?}"
            );
        }
        assert!(!super::error_atribuible_al_candidato(&ErrorNodo::Otro(
            "persistencia simulada".to_string()
        )));
    }
}
