//! Bucle de consenso: el único dueño de `zx-cadena` y `zx-storage` (decisión 3).
//!
//! Arranque limpio o reinicio (D-N03′), tubería de admisión única (decisión 4), fases PoW y PoST en
//! régimen (decisión 5, 6), resumen de estado (decisión 8) y registro estructurado (decisión 9).

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::sync::mpsc;
use std::thread;

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
use zx_core::wire_dag::{BloqueDag, bloque_dag_desde_bytes};
use zx_core::{BlockHash, PadresDag, Red, Tx, trabajo_bloque};
use zx_dag::ErrorDag;
use zx_dag::bloque_dag::{CandidatoSinRango, ContextoRangoDag};
use zx_farmer::farmer::{ParcelaDisco, plotear_sector_en_disco};
use zx_p2p::entrante::VeredictoFinal;
use zx_p2p::mensaje::{BloqueRed, Estado, Fase as FaseRed, PuntaPow};
use zx_poas::HistoriaGenesis;
use zx_post::cabecera_conjunta::{EstadoCabeceraConjunta, verificar_cabecera_conjunta};
use zx_post::pot_rango::{CachePotVerificada, PresupuestoPot};
use zx_post::productor::{FuenteSoluciones, ParametrosProductor, SolucionCandidata, producir};
use zx_post::servicio_pot::ServicioPot;
use zx_storage::disco::AlmacenEnDisco;
use zx_storage::{Almacen, BloqueAdmitido, ErrorRepeticion, Familia};

use crate::claves::ClaveDev;
use crate::error::{ErrorNodo, ResultadoNodo};
use crate::estado_resumen::resumen_estado;
use crate::identidad::identidad_de_cabecera_post;
use crate::padres::padres_de_regimen;
use crate::perfil;
use crate::pow;
use crate::red::huerfanos::DepositoHuerfanos;
use crate::red::vista::VistaRed;
use crate::red::{self, ManijaRed, TrabajoRed};
use crate::regimen::{ClaveConParcela, MsgBucle, MsgProductor, hilo_productor_regimen};
use crate::registro::Registro;

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
}

/// Estado completo del nodo, dueño único de `zx-cadena` y `zx-storage`.
pub struct Nodo {
    params: ParametrosTransicion,
    cadena: Cadena,
    almacen: AlmacenEnDisco,
    registro: Registro,
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
    /// El terminal sobre el que se construyó `servicio_verificacion`, para saber si hay que
    /// reconstruirlo tras un cambio de terminal tentativo (FC-3, antes de que exista ningún bloque
    /// PoST; `ORDEN-W06d3` decisión 3).
    terminal_servicio: Option<BlockHash>,
    servicio_verificacion: Option<ServicioPot>,
    historia: Arc<HistoriaGenesis>,
    ultima_punta_registrada: Option<BlockHash>,
    dir_datos: PathBuf,
    n_dev: u64,
    sr_dev_actual: u64,
    parada_tras_slots: Option<u64>,
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
    trabajo_red: Option<tokio::sync::mpsc::UnboundedReceiver<TrabajoRed>>,
    /// Bloques PoST **de red** descartados como [`crate::rechazo::ClasificacionRechazo::Pendiente`]
    /// (aviso del director, `ORDEN-W06d5`, tras el hallazgo de V5): no son inválidos, solo faltó
    /// contexto local (`Pot(PasadoIncompleto)` mientras este nodo sincroniza fuera de orden). Nunca
    /// se cachean como inválidos ni penalizan al remitente; se reintentan en
    /// [`Self::reintentar_post_pendientes`] cada vez que el propio pasado avanza. Acotada
    /// (`TOPE_POST_PENDIENTES`): el más viejo se descarta sin más si se supera el tope — el riesgo
    /// que se evita es RI-2a (un hueco local guardado para siempre como si fuera un defecto del
    /// candidato), no un cachá sin límite.
    post_pendientes: std::collections::VecDeque<BloqueDag>,
}

/// Tope de [`Nodo::post_pendientes`]: acotar la cola, no la corrección (D-oS local, no de consenso).
const TOPE_POST_PENDIENTES: usize = 64;

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
        let registro = Registro::abrir(&cfg.ruta_registro)?;
        registro.escribir(registro.evento("arranque").str("fase", "inicio"), true)?;

        let params = perfil::parametros_transicion_dev()?;
        let cbid = zx_core::CBID_RED_DEV;
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
        };

        let mut nodo = Self {
            params,
            cadena: Cadena::nueva(
                perfil::parametros_transicion_dev()?,
                perfil::ghostdag_k(),
                cbid,
                perfil::ghostdag_max_padres(),
            ),
            almacen,
            registro,
            claves,
            cbid,
            historial_pow: Vec::new(),
            headers_pow: BTreeMap::new(),
            terminal_servicio: None,
            servicio_verificacion: None,
            historia,
            ultima_punta_registrada: None,
            dir_datos: cfg.dir_datos.clone(),
            n_dev: cfg.n_dev,
            sr_dev_actual: cfg.sr_dev,
            parada_tras_slots: cfg.parada_tras_slots,
            trabajo_acumulado: U256::zero(),
            hash_genesis: hash_genesis_esperado,
            red_configurada: cfg.red,
            vista_red: Arc::new(VistaRed::nueva(estado_inicial)),
            huerfanos: red::nuevo_deposito_huerfanos(),
            red: None,
            trabajo_red: None,
            post_pendientes: std::collections::VecDeque::new(),
        };

        let longitud = nodo.almacen.longitud_registro()?;
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
        self.registro
            .escribir(self.registro.evento("arranque").str("fase", "limpio"), true)?;
        let testigos_genesis: Vec<Vec<Vec<u8>>> = vec![Vec::new()];
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
        Ok(())
    }

    /// D-N03′: repite el registro de admisión sobre una `Cadena` fresca, sin re-verificar cabeceras,
    /// y reconstruye el `ServicioPot` de verificación desde las cabeceras almacenadas (decisión 7).
    fn reiniciar(&mut self, longitud: u64) -> ResultadoNodo<()> {
        let inicio = std::time::Instant::now();
        self.registro.escribir(
            self.registro.evento("arranque").str("fase", "reinicio"),
            true,
        )?;

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
        self.registro.escribir(
            self.registro
                .evento("reinicio_completo")
                .u64("entradas", indice)
                .u64("duracion_ns", inicio.elapsed().as_nanos() as u64),
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
                .map_err(|e| ErrorNodo::Otro(e.to_string()))?;
            let ctx = ContextoPow {
                red: Red::Dev,
                parametros: PARAMETROS_POW_DEV,
                altura_padre: padre.height,
                hash_padre: padre.block_hash(),
                target_esperado,
                ts_padre: i64::try_from(padre.timestamp).unwrap_or(i64::MAX),
                reloj_local: i64::try_from(
                    std::time::SystemTime::now()
                        .duration_since(std::time::UNIX_EPOCH)
                        .map(|d| d.as_secs())
                        .unwrap_or(0),
                )
                .unwrap_or(i64::MAX),
            };
            validar_cabecera_pow(&cabecera, &ctx, &Sha3Dev).map_err(|e| {
                ErrorNodo::BloquePropioRechazado {
                    hash,
                    motivo: format!("validar_cabecera_pow: {e}"),
                    // Interno: el propio minero acaba de encontrar este PoW contra el contexto que
                    // el nodo mismo calculó; una discrepancia aquí es un bug de construcción, no
                    // una carrera con otro proceso.
                    clasificacion: crate::rechazo::ClasificacionRechazo::Interno,
                }
            })?;
        }
        // Se registra la cabecera (válida, o el génesis) para poder reconstruir el historial de
        // cualquier rama que la tenga como ancestro, sea o no la punta seleccionada hoy.
        self.headers_pow.insert(hash, cabecera);

        let hechos = if es_genesis {
            HechosCabecera::Genesis { hash }
        } else {
            let target = pow_target_de(&cabecera)?;
            let trabajo = trabajo_bloque(target)
                .ok_or_else(|| ErrorNodo::Otro(format!("trabajo del bloque {hash} desborda")))?;
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
            // Persistencia (D-N03′) **antes** de admitir en `zx-cadena`: si el proceso muere entre
            // las dos, el reinicio repite desde el almacén y vuelve a llegar aquí con `ya_admitido`
            // falso otra vez (la clave del almacén es el hash, admitir es idempotente); al revés
            // (admitir en memoria y morir antes de persistir) perdería el bloque sin dejar rastro.
            // Solo en la ruta en vivo (`verificar`): en la repetición el bloque ya está en el
            // almacén (viene de ahí) y volver a escribirlo sería una vuelta redundante a disco.
            if verificar {
                let admitido = BloqueAdmitido::pow(&cabecera, &txs, &testigos);
                self.almacen.admitir(&admitido, true)?;
            }

            let txs_con_testigos: Vec<(Tx, Vec<Vec<u8>>)> = txs.into_iter().zip(testigos).collect();
            let bt = BloqueTransicion::nuevo(hechos, txs_con_testigos);
            self.cadena.admitir(BloqueCadena::Pow(bt)).map_err(|m| {
                ErrorNodo::BloquePropioRechazado {
                    hash,
                    motivo: m.nombre().to_string(),
                    clasificacion: crate::rechazo::clasificar_motivo_bloque(&m),
                }
            })?;
            self.vista_red.registrar_pow(cabecera.height, para_vista);
            // Un hijo que esperaba justo este padre puede reintentarse ya (decisión 3).
            self.resolver_huerfanos_de(hash);
        }

        // `ORDEN-W06d3` decisión 3: `historial_pow`/`trabajo_acumulado` ya no se extienden a
        // ciegas con cada bloque admitido (eso asumía una única cadena lineal); se recalculan desde
        // la punta PoW **seleccionada** por `zx-cadena` (mayor trabajo acumulado), lo mismo si este
        // bloque la extiende como si es un bloque de una rama lateral que no la cambia.
        self.actualizar_seleccion_pow()?;
        // El `ServicioPot` de verificación se necesita en cuanto el terminal existe, tanto en
        // producción en vivo (lo crea `fase_regimen` antes de producir) como en la **repetición**
        // (D-N03′): si el registro trae ya bloques PoST, `admitir_post_interno` los procesa aquí
        // mismo, dentro de `Nodo::arrancar`, antes de que `fase_regimen` llegue a ejecutarse. Sin
        // esto, reabrir un nodo que ya había cruzado el corte fallaba siempre en la primera entrada
        // PoST del registro (bug real encontrado por `tests/reinicio.rs`, ver `PROGRESO.md`).
        //
        // Se reconstruye también si el terminal **cambió** desde la última vez (posible mientras
        // `Cadena::contexto_dag()` sigue en `None`, FC-3: una rama más pesada puede desplazar al
        // terminal tentativo antes de que exista ningún bloque PoST, `ORDEN-W06d3` decisión 3): un
        // `ServicioPot` construido sobre el terminal viejo verificaría contra el flujo PoT
        // equivocado.
        if let Some(terminal) = self.cadena.terminal() {
            let necesita_reconstruir =
                self.servicio_verificacion.is_none() || self.terminal_servicio != Some(terminal);
            if necesita_reconstruir && self.cadena.contexto_dag().is_none() {
                let servicio = ServicioPot::nuevo(terminal, self.n_dev, 4096)
                    .map_err(|e| ErrorNodo::Otro(format!("ServicioPot de verificación: {e}")))?;
                self.servicio_verificacion = Some(servicio);
                self.terminal_servicio = Some(terminal);
            }
        }
        self.registrar_cambio_de_punta()?;
        Ok(())
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

        if verificar {
            let servicio = self
                .servicio_verificacion
                .as_ref()
                .ok_or_else(|| ErrorNodo::Otro("verificación PoST sin ServicioPot".to_string()))?;
            let params_pieza: PieceCheckParams = self.historia.params_pieza();
            let mut cache = CachePotVerificada::nueva();
            let mut presupuesto = PresupuestoIlimitado;
            let rango = RangoDev(self.cadena_sr_dev());

            // El primer bloque tras el corte (el de transición, decisión 6) se verifica **antes**
            // de que `zx-cadena` tenga ningún bloque PoST admitido: `Cadena::contexto_dag()` es
            // `None` hasta la primera admisión (`inicializar_dag` vive dentro de `admitir_post`).
            // Para ese único bloque, cuyo único padre posible es el terminal, no hay ambigüedad de
            // `sp` que temer («Relanzamiento» punto 3 es sobre bloques con más de un padre
            // candidato) y se usa `ContextoTransicion` (el mismo contexto dev que `zx-post` define
            // para exactamente este caso). Para todo lo demás, el GHOSTDAG real de `zx-cadena`.
            let estado = match self.cadena.contexto_dag() {
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
                    let terminal = self.cadena.terminal().ok_or_else(|| {
                        ErrorNodo::Otro("verificación PoST sin terminal fijado".to_string())
                    })?;
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
        }

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
        let padres = padres_dag_a_vec(&bloque.cabecera.padres);
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
            peso: peso_u128(&bloque)?,
            prueba_valida: true,
            requisito_declarado: 0,
            sr: bloque.cabecera.rango_solucion,
            distancia,
            identidad,
            txs,
        };

        let ya_admitido = self.cadena.es_valido(&hash) || self.cadena.motivo(&hash).is_some();
        // Aviso del director a mitad de ejecución (RI-2b, `deepseek/RI-2b/INFORME.md` H1): persistir
        // **antes** de admitir en `zx-cadena`, igual que `admitir_pow_interno` y por el mismo motivo
        // (su propio comentario, arriba): si el proceso muere entre las dos, el reinicio repite
        // desde el almacén y vuelve a llegar aquí con `ya_admitido` falso otra vez (idempotente por
        // hash). Al revés —como estaba— un `SIGKILL` entre `cadena.admitir` (memoria) y
        // `almacen.admitir` (disco) perdía el bloque **sin dejar rastro**: al reiniciar,
        // `ServicioPot` se reconstruye solo desde lo persistido (D-N03′), el mismo slot queda
        // libre otra vez y, con un solo flujo PoT determinista (D-P10), la misma clave puede volver
        // a ganarlo y firmar un bloque **distinto** para el mismo slot — la doble firma que
        // «Relanzamiento» punto 4 de `ORDEN-W06d1` prohíbe. Solo en la ruta en vivo (`verificar`):
        // en la repetición el bloque ya está en el almacén (viene de ahí).
        if !ya_admitido && verificar {
            let admitido = BloqueAdmitido::post(&bloque);
            self.almacen.admitir(&admitido, true)?;
        }

        if !ya_admitido {
            self.cadena.admitir(BloqueCadena::Post(post)).map_err(|m| {
                ErrorNodo::BloquePropioRechazado {
                    hash,
                    motivo: m.nombre().to_string(),
                    clasificacion: crate::rechazo::clasificar_motivo_bloque(&m),
                }
            })?;
            let para_vista = BloqueRed::Post {
                cabecera: bloque.cabecera,
                justificacion: bloque.justificacion.clone(),
                txs: bloque.txs().to_vec(),
                testigos: bloque.testigos().to_vec(),
            };
            self.vista_red.registrar_post(hash, para_vista);
            self.resolver_huerfanos_de(hash);
        }

        self.actualizar_servicio_verificacion(&bloque)?;
        self.registrar_cambio_de_punta()?;
        Ok(())
    }

    fn cadena_sr_dev(&self) -> u64 {
        // El `SR_dev` no vive en `Cadena`; el nodo lo trae de la CLI y lo guarda aquí mismo.
        self.sr_dev_actual
    }

    /// Mantiene al día el `ServicioPot` de verificación (decisión 7, ver `PROGRESO.md`): inserta la
    /// salida y el portador **de este bloque**, sin recalcular el PoT. El flujo es único y global
    /// (D-P10), así que si el slot ya estaba cubierto por otra rama/hermano, solo se comprueba que
    /// coincide (defensa; nunca debería discrepar: lo impediría antes `ContextoTransicion`/H2 en la
    /// ruta de producción, pero este servicio de verificación no pasa por ahí).
    fn actualizar_servicio_verificacion(&mut self, bloque: &BloqueDag) -> Result<(), ErrorNodo> {
        let Some(servicio) = self.servicio_verificacion.as_mut() else {
            return Err(ErrorNodo::Otro(
                "ServicioPot de verificación ausente tras el terminal".to_string(),
            ));
        };
        let slot = bloque.cabecera.slot;
        let salida = bloque.cabecera.pot_output;
        let Some(portador) = bloque.justificacion.bundles().last().copied() else {
            return Err(ErrorNodo::Otro(format!(
                "bloque PoST {} sin portadores en su justificación",
                bloque.cabecera.block_hash()
            )));
        };
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
        let evento = self
            .registro
            .evento("cambio_punta")
            .str(
                "punta",
                &punta_actual.map(|h| h.to_string()).unwrap_or_default(),
            )
            .str("resumen_estado", &resumen);
        self.registro.escribir(evento, false)?;
        Ok(())
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
        for (_hijo, bloque) in self.huerfanos.tomar_para_padre(&padre) {
            let veredicto = self.intentar_admitir_bloque_red(&bloque, None);
            // Sin `IdDiferido` que informar (no llegó por gossipsub en este turno): el único rastro
            // es el registro. La retransmisión de un huérfano que ahora prospera queda pendiente
            // (límite conocido, ver `PROGRESO.md`): difundirlo exigiría reconstruir un `IdDiferido`
            // que no existe para un bloque que nunca pasó por `report_message_validation_result`.
            let evento = self
                .registro
                .evento("huerfano_resuelto")
                .str("padre", &padre.to_string())
                .str("veredicto", &format!("{veredicto:?}"));
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
                TrabajoRed::BloqueDifundido { id, bloque } => {
                    // Gossipsub no dice quién lo propagó a este nivel (`ManejadorEntrante` no lo
                    // expone); si resulta huérfano, no hay a quién pedirle el padre directamente.
                    let veredicto = self.intentar_admitir_bloque_red(&bloque, None);
                    if let Some(red) = self.red.as_ref() {
                        red.informar_validacion(id, veredicto);
                    }
                }
                TrabajoRed::BloqueDeSincronizacion { de, bloque } => {
                    let veredicto = self.intentar_admitir_bloque_red(&bloque, Some(de));
                    // Un bloque de sincronización demostrablemente inválido sí penaliza: no pasó
                    // por gossipsub (no hay `report_message_validation_result` que llame a esto),
                    // así que la única forma de aplicar C-NET-05/C-EVP es desconectar aquí.
                    if veredicto == VeredictoFinal::Rechazar
                        && let Some(red) = self.red.as_ref()
                    {
                        red.desconectar(de, zx_p2p::error::MotivoDesconexion::ViolacionDeConsenso);
                    }
                }
            }
        }
        self.trabajo_red = Some(receptor);
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
    ) -> VeredictoFinal {
        match bloque {
            BloqueRed::Pow {
                cabecera,
                txs,
                testigos,
            } => self.intentar_admitir_pow_de_red(*cabecera, txs.clone(), testigos.clone(), origen),
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
            ),
        }
    }

    fn intentar_admitir_pow_de_red(
        &mut self,
        cabecera: BlockHeader,
        txs: Vec<Tx>,
        testigos: Vec<Vec<Vec<u8>>>,
        origen: Option<libp2p::PeerId>,
    ) -> VeredictoFinal {
        let hash = cabecera.block_hash();
        if self.cadena.es_valido(&hash) {
            return VeredictoFinal::Ignorar; // ya lo teníamos: nada que hacer, no penaliza.
        }
        if self.cadena.motivo(&hash).is_some() {
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
                    .str("hijo", &d.hijo.to_string())
                    .str("padre_esperado", &d.padre_esperado.to_string());
                let _ = self.registro.escribir(evento, false);
            }
            let evento = self
                .registro
                .evento("bloque_red_huerfano")
                .str("hash", &hash.to_string())
                .str("padre_ausente", &padre.to_string())
                .str("familia", "pow")
                .str("veredicto", "Ignorar");
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
            // El padre es conocido y definitivamente inválido: este bloque no puede ser válido.
            let evento = self
                .registro
                .evento("bloque_red_rechazado")
                .str("hash", &hash.to_string())
                .str("familia", "pow")
                .str("motivo", "padre conocido e inválido");
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
        match self.admitir_pow_interno(cabecera, txs, testigos, indice, true) {
            Ok(()) => {
                // V9: este evento **solo** se escribe después de que `admitir_pow_interno` terminó
                // la tubería completa (cabecera, PoW, motor de transición, persistencia): nunca
                // antes. Es la traza que V9 exige comprobar.
                let evento = self
                    .registro
                    .evento("bloque_red_admitido")
                    .str("hash", &hash.to_string())
                    .str("familia", "pow")
                    .str("veredicto", "Aceptar");
                let _ = self.registro.escribir(evento, false);
                VeredictoFinal::Aceptar
            }
            Err(e) => {
                let evento = self
                    .registro
                    .evento("bloque_red_rechazado")
                    .str("hash", &hash.to_string())
                    .str("familia", "pow")
                    .str("motivo", &e.to_string());
                let _ = self.registro.escribir(evento, false);
                VeredictoFinal::Rechazar
            }
        }
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
    ) -> VeredictoFinal {
        let hash = cabecera.block_hash();
        if self.cadena.es_valido(&hash) {
            return VeredictoFinal::Ignorar; // ya lo teníamos: nada que hacer, no penaliza.
        }
        if self.cadena.motivo(&hash).is_some() {
            return VeredictoFinal::Rechazar; // ya sabíamos que es inválido.
        }
        let Some(terminal) = self.cadena.terminal() else {
            // Todavía en fase PoW pura: sin terminal no hay `ServicioPot` ni GHOSTDAG con los que
            // verificar nada. No es demostrablemente inválido (podríamos cruzar el corte nosotros
            // mismos en breve): `Ignorar`, no `Rechazar`.
            let evento = self
                .registro
                .evento("bloque_post_de_red_sin_terminal")
                .str("hash", &hash.to_string());
            let _ = self.registro.escribir(evento, false);
            return VeredictoFinal::Ignorar;
        };

        let bloque_red = BloqueRed::Post {
            cabecera,
            justificacion: justificacion.clone(),
            txs: txs.clone(),
            testigos: testigos.clone(),
        };
        for padre in red::padres_declarados(&bloque_red) {
            if padre == terminal {
                continue; // el terminal siempre es un padre válido y conocido, por definición.
            }
            let padre_conocido =
                self.cadena.es_valido(&padre) || self.cadena.motivo(&padre).is_some();
            if !padre_conocido {
                for d in self.huerfanos.insertar(padre, hash, bloque_red) {
                    let evento = self
                        .registro
                        .evento("huerfano_desalojado")
                        .str("hijo", &d.hijo.to_string())
                        .str("padre_esperado", &d.padre_esperado.to_string());
                    let _ = self.registro.escribir(evento, false);
                }
                let evento = self
                    .registro
                    .evento("bloque_red_huerfano")
                    .str("hash", &hash.to_string())
                    .str("padre_ausente", &padre.to_string())
                    .str("familia", "post")
                    .str("veredicto", "Ignorar");
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
                let evento = self
                    .registro
                    .evento("bloque_red_rechazado")
                    .str("hash", &hash.to_string())
                    .str("familia", "post")
                    .str("motivo", "padre conocido e inválido");
                let _ = self.registro.escribir(evento, false);
                return VeredictoFinal::Rechazar;
            }
        }

        let bloque_dag = match BloqueDag::nuevo(cabecera, justificacion, txs, testigos) {
            Ok(b) => b,
            Err(e) => {
                let evento = self
                    .registro
                    .evento("bloque_red_rechazado")
                    .str("hash", &hash.to_string())
                    .str("familia", "post")
                    .str("motivo", &format!("forma: {e}"));
                let _ = self.registro.escribir(evento, false);
                return VeredictoFinal::Rechazar;
            }
        };
        let indice = self.almacen.longitud_registro().unwrap_or(0);
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
                let evento = self
                    .registro
                    .evento("bloque_red_admitido")
                    .str("hash", &hash.to_string())
                    .str("familia", "post")
                    .str("veredicto", "Aceptar");
                let _ = self.registro.escribir(evento, false);
                self.reintentar_post_pendientes();
                VeredictoFinal::Aceptar
            }
            Err(ErrorNodo::BloquePropioRechazado {
                motivo,
                clasificacion,
                ..
            }) if clasificacion.es_pendiente() => {
                let evento = self
                    .registro
                    .evento("bloque_red_pendiente")
                    .str("hash", &hash.to_string())
                    .str("familia", "post")
                    .str("motivo", &motivo)
                    .str("veredicto", "Ignorar (reintento encolado)");
                let _ = self.registro.escribir(evento, false);
                self.encolar_post_pendiente(bloque_para_reintento);
                VeredictoFinal::Ignorar
            }
            Err(e) => {
                let evento = self
                    .registro
                    .evento("bloque_red_rechazado")
                    .str("hash", &hash.to_string())
                    .str("familia", "post")
                    .str("motivo", &e.to_string());
                let _ = self.registro.escribir(evento, false);
                VeredictoFinal::Rechazar
            }
        }
    }

    /// Encola un bloque PoST de red que quedó `Pendiente` (decisión 3 extendida): acotado, el más
    /// viejo se descarta si se supera [`TOPE_POST_PENDIENTES`] — es una cola de mejor esfuerzo, no
    /// una promesa de reintento infinito.
    fn encolar_post_pendiente(&mut self, bloque: BloqueDag) {
        if self.post_pendientes.len() >= TOPE_POST_PENDIENTES {
            self.post_pendientes.pop_front();
        }
        self.post_pendientes.push_back(bloque);
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
        let pendientes: Vec<BloqueDag> = self.post_pendientes.drain(..).collect();
        for bloque in pendientes {
            let hash = bloque.cabecera.block_hash();
            let indice = self.almacen.longitud_registro().unwrap_or(0);
            match self.admitir_post_interno(bloque.clone(), indice, true) {
                Ok(()) => {
                    let evento = self
                        .registro
                        .evento("bloque_red_admitido")
                        .str("hash", &hash.to_string())
                        .str("familia", "post")
                        .str("veredicto", "Aceptar (reintento)");
                    let _ = self.registro.escribir(evento, false);
                }
                Err(ErrorNodo::BloquePropioRechazado { clasificacion, .. })
                    if clasificacion.es_pendiente() =>
                {
                    self.encolar_post_pendiente(bloque);
                }
                Err(e) => {
                    let evento = self
                        .registro
                        .evento("bloque_red_rechazado")
                        .str("hash", &hash.to_string())
                        .str("familia", "post")
                        .str("motivo", &format!("reintento: {e}"));
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
            let Ok(cabecera_minada) = rx_minado.recv() else {
                return Err(ErrorNodo::Otro("el hilo minero cerró el canal".to_string()));
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
            let evento = self
                .registro
                .evento("bloque_minado")
                .u64("altura", u64::from(cabecera_minada.height))
                .str("hash", &cabecera_minada.block_hash().to_string());
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

    /// Fase PoST en régimen: arranca `ServicioPot` de verificación, las parcelas locales y el hilo
    /// productor, y atiende sus peticiones hasta que se agote (`--parada-tras-slots`) o falle.
    ///
    /// # Errores
    /// [`ErrorNodo::BloquePropioRechazado`] con `clasificacion` interna (`ORDEN-W06d5` decisión 3, `crate::rechazo`); un rechazo legítimo se descarta y no llega a devolverse.
    fn fase_regimen(&mut self) -> ResultadoNodo<()> {
        let terminal = self
            .cadena
            .terminal()
            .ok_or_else(|| ErrorNodo::Otro("fase_regimen sin terminal".to_string()))?;
        // Mismo ratchet que `admitir_pow_interno` (`ORDEN-W06d3` decisión 3): entre que `fase_pow`
        // vio el terminal por última vez y aquí, una rama más pesada llegada por red podría haberlo
        // desplazado (FC-3), siempre que todavía no exista ningún bloque PoST (`contexto_dag`
        // `None`). Se reconstruye el `ServicioPot` si el terminal no es el que tenía.
        if self.servicio_verificacion.is_none() || self.terminal_servicio != Some(terminal) {
            let servicio = ServicioPot::nuevo(terminal, self.n_dev, 4096)
                .map_err(|e| ErrorNodo::Otro(format!("ServicioPot de verificación: {e}")))?;
            self.servicio_verificacion = Some(servicio);
            self.terminal_servicio = Some(terminal);
        }

        // El primer bloque de régimen (transición) usa `producir` (W05b2), decisión 6.
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
                while self.cadena.tips_validas().is_empty() {
                    self.procesar_trabajo_red_pendiente();
                    std::thread::sleep(std::time::Duration::from_millis(50));
                }
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
        let servicio_hilo = self.servicio_verificacion.clone().ok_or_else(|| {
            ErrorNodo::Otro("fase_regimen sin ServicioPot de verificación".to_string())
        })?;

        let (tx_a_bucle, rx_en_bucle) = mpsc::channel::<MsgProductor>();
        let (tx_a_productor, rx_en_productor) = mpsc::channel::<MsgBucle>();
        let cbid = self.cbid;
        let n_dev = self.n_dev;
        let sr_dev = self.sr_dev_actual;
        let parada = self.parada_tras_slots;
        let importe_coinbase = perfil::subsidio_post(0);
        let historia_hilo: Arc<HistoriaGenesis> = Arc::clone(&self.historia);
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
            );
        });

        // `recv_timeout`, no `for msg in rx_en_bucle`: entre dos mensajes del productor (que puede
        // tardar hasta un slot entero) hace falta seguir drenando `procesar_trabajo_red_pendiente`
        // (decisión 1/3/4 de `ORDEN-W06d2`), o un bloque de red llegaría y esperaría sin motivo
        // hasta el siguiente mensaje del hilo productor.
        loop {
            let msg = match rx_en_bucle.recv_timeout(std::time::Duration::from_millis(50)) {
                Ok(m) => m,
                Err(mpsc::RecvTimeoutError::Timeout) => {
                    self.procesar_trabajo_red_pendiente();
                    continue;
                }
                Err(mpsc::RecvTimeoutError::Disconnected) => break,
            };
            self.procesar_trabajo_red_pendiente();
            match msg {
                MsgProductor::PeticionPadres => {
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
                    let con_garantia: std::collections::BTreeSet<zx_core::ClavePublica> = self
                        .cadena
                        .estado_post(&padres.seleccionado())
                        .map(|estado| {
                            self.claves
                                .iter()
                                .filter(|c| estado.activo_de(&c.pk) >= self.params.q)
                                .map(|c| c.pk)
                                .collect()
                        })
                        .unwrap_or_default();
                    if tx_a_productor
                        .send(MsgBucle::Padres(padres, info_padres, con_garantia))
                        .is_err()
                    {
                        break;
                    }
                }
                MsgProductor::Post(bloque) => {
                    let hash = bloque.cabecera.block_hash();
                    match self.admitir_post_interno(
                        *bloque,
                        self.almacen.longitud_registro()?,
                        true,
                    ) {
                        Ok(()) => {
                            let evento = self
                                .registro
                                .evento("bloque_producido")
                                .str("hash", &hash.to_string());
                            self.registro.escribir(evento, false)?;
                            self.difundir_si_hay_red(hash);
                            // El pasado del `ServicioPot` de verificación acaba de avanzar: algún
                            // bloque de red que quedó `Pendiente` (decisión 3 extendida) puede haber
                            // dejado de estarlo.
                            self.reintentar_post_pendientes();
                            let continuar = self.parada_tras_slots.is_none_or(|limite| {
                                self.servicio_verificacion
                                    .as_ref()
                                    .is_some_and(|s| s.slot_actual() < limite)
                            });
                            let respuesta = if continuar {
                                MsgBucle::Continuar
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
                                if tx_a_productor.send(MsgBucle::Continuar).is_err() {
                                    break;
                                }
                                continue;
                            }
                            let _ = tx_a_productor.send(MsgBucle::Parar);
                            return Err(e);
                        }
                    }
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
            return Err(ErrorNodo::Otro(format!(
                "el hilo productor terminó con panic: {motivo}"
            )));
        }
        Ok(())
    }

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
        let bloque = producir(terminal, &fuente, &clave.sk, &parametros)
            .map_err(|e| ErrorNodo::Otro(format!("producir (bloque de transición): {e}")))?;
        let hash = bloque.cabecera.block_hash();
        self.admitir_post_interno(bloque, self.almacen.longitud_registro()?, true)?;
        self.difundir_si_hay_red(hash);
        Ok(())
    }

    /// La instantánea compartida de red (para construir el manejador antes de llamar a
    /// [`Self::conectar_red`], y para que las pruebas la inspeccionen).
    #[must_use]
    pub fn vista_red(&self) -> Arc<VistaRed> {
        Arc::clone(&self.vista_red)
    }

    /// Conecta el nodo a la red (`ORDEN-W06d2`): a partir de aquí, `ejecutar` también procesa el
    /// trabajo de red (bloques difundidos o de sincronización) intercalado con su propia
    /// producción (D-N07: un único hilo de consenso). Sin llamar a esto, el nodo se comporta
    /// exactamente como en `ORDEN-W06d1` (sin red).
    pub fn conectar_red(
        &mut self,
        manija: ManijaRed,
        receptor: tokio::sync::mpsc::UnboundedReceiver<TrabajoRed>,
    ) {
        self.red = Some(manija);
        self.trabajo_red = Some(receptor);
    }

    /// Ejecuta el nodo de punta a punta: fase PoW hasta el corte, luego régimen.
    ///
    /// # Errores
    /// Cualquier fallo fatal de admisión propia (decisión 4).
    pub fn ejecutar(&mut self) -> ResultadoNodo<()> {
        self.fase_pow()?;
        self.fase_regimen()
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

/// `PadresDag` a `Vec<BlockHash>` (seleccionado primero), para `BloquePost::padres`.
fn padres_dag_a_vec(p: &PadresDag) -> Vec<BlockHash> {
    if p.es_genesis() {
        return Vec::new();
    }
    let mut v = vec![p.seleccionado()];
    v.extend_from_slice(p.extras());
    v
}

/// `w(SR)` (`U256`) a `u128` para `BloquePost::peso` (no debería desbordar con `SR_dev` de la red
/// dev; se trata como fallo fatal si ocurriera, no como truncamiento silencioso).
fn peso_u128(bloque: &BloqueDag) -> Result<u128, ErrorNodo> {
    let peso = zx_dag::peso(bloque.cabecera.rango_solucion);
    u128::try_from(peso).map_err(|_| ErrorNodo::Otro(format!("peso {peso} no cabe en u128")))
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
