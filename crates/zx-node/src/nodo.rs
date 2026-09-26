//! Bucle de consenso: el único dueño de `zx-cadena` y `zx-storage` (decisión 3).
//!
//! Arranque limpio o reinicio (D-N03′), tubería de admisión única (decisión 4), fases PoW y PoST en
//! régimen (decisión 5, 6), resumen de estado (decisión 8) y registro estructurado (decisión 9).

use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::sync::mpsc;
use std::thread;

use subspace_core_primitives::PublicKey;
use subspace_verification::PieceCheckParams;
use zx_cadena::{BloqueCadena, BloquePost, Cadena};
use zx_consensus::genesis::{GENESIS_DEV, HASH_GENESIS_DEV, construir as construir_genesis};
use zx_consensus::transicion::{BloqueTransicion, HechosCabecera, ParametrosTransicion};
use zx_consensus::verificador::{ContextoPow, validar_cabecera_pow};
use zx_consensus::{PARAMETROS_POW_DEV, Sha3Dev};
use zx_core::digest::Digest;
use zx_core::preimage::block::BlockHeader;
use zx_core::wire::cuerpo_desde_bytes;
use zx_core::wire_dag::{BloqueDag, bloque_dag_desde_bytes};
use zx_core::{BlockHash, PadresDag, Red, Tx, trabajo_bloque, txid};
use zx_dag::ErrorDag;
use zx_dag::bloque_dag::{CandidatoSinRango, ContextoRangoDag};
use zx_farmer::farmer::{ParcelaDisco, plotear_sector_en_disco};
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
use crate::pow::{self, CoinbasePropia};
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
    historial_pow: Vec<BlockHeader>,
    coinbases: Vec<CoinbasePropia>,
    servicio_verificacion: Option<ServicioPot>,
    historia: Arc<HistoriaGenesis>,
    ultima_punta_registrada: Option<BlockHash>,
    dir_datos: PathBuf,
    n_dev: u64,
    sr_dev_actual: u64,
    parada_tras_slots: Option<u64>,
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
            coinbases: Vec::new(),
            servicio_verificacion: None,
            historia,
            ultima_punta_registrada: None,
            dir_datos: cfg.dir_datos.clone(),
            n_dev: cfg.n_dev,
            sr_dev_actual: cfg.sr_dev,
            parada_tras_slots: cfg.parada_tras_slots,
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
            })?;
        let admitido = BloqueAdmitido::pow(&cabecera_genesis, &[tx_genesis], &testigos_genesis);
        self.almacen.admitir(&admitido, true)?;
        self.historial_pow.push(cabecera_genesis);
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

        if verificar && !es_genesis {
            #[expect(
                clippy::indexing_slicing,
                reason = "historial_pow siempre tiene al menos el génesis en índice 0"
            )]
            let padre = &self.historial_pow[self.historial_pow.len() - 1];
            let target_esperado = pow::target_de_altura(&self.historial_pow, cabecera.height)
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
                }
            })?;
        }

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
        // Rastro de coinbases/depósitos propios (decisión 5), antes de que `txs` se consuma: marca
        // depositadas las que este bloque gasta y registra la coinbase nueva si paga a una clave
        // propia. Funciona igual en producción que en repetición (mismos `txs`).
        for tx in &txs {
            for input in &tx.inputs {
                if input.outpoint.prev_index == 0 {
                    for c in &mut self.coinbases {
                        if c.txid == input.outpoint.prev_txid {
                            c.depositada = true;
                        }
                    }
                }
            }
        }
        if !es_genesis
            && let Some(coinbase) = txs.first()
            && let Some(salida) = coinbase.outputs.first()
            && let zx_core::Lock::PubKey { pubkey } = salida.lock
            && let Some(indice_clave) = self.claves.iter().position(|c| c.pk == pubkey)
        {
            self.coinbases.push(CoinbasePropia {
                indice_clave,
                altura: cabecera.height,
                txid: txid(coinbase, self.cbid),
                valor: salida.value,
                depositada: false,
            });
        }

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
                }
            })?;
        }

        self.historial_pow.push(cabecera);
        // El `ServicioPot` de verificación se necesita en cuanto el terminal existe, tanto en
        // producción en vivo (lo crea `fase_regimen` antes de producir) como en la **repetición**
        // (D-N03′): si el registro trae ya bloques PoST, `admitir_post_interno` los procesa aquí
        // mismo, dentro de `Nodo::arrancar`, antes de que `fase_regimen` llegue a ejecutarse. Sin
        // esto, reabrir un nodo que ya había cruzado el corte fallaba siempre en la primera entrada
        // PoST del registro (bug real encontrado por `tests/reinicio.rs`, ver `PROGRESO.md`).
        if self.servicio_verificacion.is_none()
            && let Some(terminal) = self.cadena.terminal()
        {
            let servicio = ServicioPot::nuevo(terminal, self.n_dev, 4096)
                .map_err(|e| ErrorNodo::Otro(format!("ServicioPot de verificación: {e}")))?;
            self.servicio_verificacion = Some(servicio);
        }
        self.registrar_cambio_de_punta()?;
        Ok(())
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
                    });
                }
                EstadoCabeceraConjunta::Pendiente(m) => {
                    return Err(ErrorNodo::BloquePropioRechazado {
                        hash,
                        motivo: format!("pendiente: {m:?}"),
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
        if !ya_admitido {
            self.cadena.admitir(BloqueCadena::Post(post)).map_err(|m| {
                ErrorNodo::BloquePropioRechazado {
                    hash,
                    motivo: m.nombre().to_string(),
                }
            })?;
        }

        if !ya_admitido && verificar {
            let admitido = BloqueAdmitido::post(&bloque);
            self.almacen.admitir(&admitido, true)?;
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
        if slot <= servicio.slot_actual() {
            let ya = servicio
                .salida_de(slot)
                .map_err(|e| ErrorNodo::Otro(e.to_string()))?;
            if ya != salida {
                return Err(ErrorNodo::Otro(format!(
                    "D-P10 violado: dos bloques del slot {slot} traen salidas PoT distintas"
                )));
            }
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

    /// Registra en el resumen de estado un cambio de punta seleccionada (decisión 8 y 9).
    fn registrar_cambio_de_punta(&mut self) -> Result<(), ErrorNodo> {
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
        for c in &self.coinbases {
            if c.depositada {
                continue;
            }
            let Some(madura_en) = c.altura.checked_add(self.params.m_cb) else {
                continue;
            };
            if altura_bloque < madura_en {
                continue;
            }
            let Some(clave) = self.claves.get(c.indice_clave) else {
                continue;
            };
            let nonce = estado
                .garantias
                .get(&clave.pk)
                .map_or(0, |g| g.nonce_siguiente);
            let (tx, testigos) = pow::construir_deposito(c, clave, nonce, self.cbid)
                .map_err(|e| ErrorNodo::Otro(format!("construir depósito: {e}")))?;
            depositos.push((tx, testigos));
        }
        Ok(depositos)
    }

    /// Fase PoW: mina hasta fijar el terminal, con un depósito por clave madura en cada altura que
    /// lo permita (decisión 5). Devuelve cuando `Cadena` fija el terminal.
    ///
    /// # Errores
    /// [`ErrorNodo::BloquePropioRechazado`] si el motor rechaza un bloque propio (decisión 4, fatal).
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
            let evento = self
                .registro
                .evento("bloque_minado")
                .u64("altura", u64::from(cabecera_minada.height))
                .str("hash", &cabecera_minada.block_hash().to_string());
            self.registro.escribir(evento, false)?;

            self.admitir_pow_interno(
                cabecera_minada,
                txs,
                testigos,
                self.almacen.longitud_registro()?,
                true,
            )?;

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
    /// [`ErrorNodo::BloquePropioRechazado`] si el motor rechaza un bloque propio (decisión 4, fatal).
    fn fase_regimen(&mut self) -> ResultadoNodo<()> {
        let terminal = self
            .cadena
            .terminal()
            .ok_or_else(|| ErrorNodo::Otro("fase_regimen sin terminal".to_string()))?;
        if self.servicio_verificacion.is_none() {
            let servicio = ServicioPot::nuevo(terminal, self.n_dev, 4096)
                .map_err(|e| ErrorNodo::Otro(format!("ServicioPot de verificación: {e}")))?;
            self.servicio_verificacion = Some(servicio);
        }

        // El primer bloque de régimen (transición) usa `producir` (W05b2), decisión 6.
        if self.cadena.tips_validas().is_empty() {
            self.producir_bloque_transicion(terminal)?;
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

        for msg in rx_en_bucle {
            match msg {
                MsgProductor::PeticionPadres => {
                    let padres = padres_de_regimen(&self.cadena)
                        .map_err(|e| ErrorNodo::Otro(format!("padres de régimen: {e}")))?;
                    if tx_a_productor.send(MsgBucle::Padres(padres)).is_err() {
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
                        Err(e) => {
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
        self.admitir_post_interno(bloque, self.almacen.longitud_registro()?, true)
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

    use super::{BlockHeader, Config, Nodo, Red, txid};

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
