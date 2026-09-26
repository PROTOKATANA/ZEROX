//! Arnés **diferencial** contra el oráculo Julia T01 (`ORDEN-W03` §3.10, V4).
//!
//! Lee `testdata/transicion-v0/vectores-transicion-v0.txt`, deriva claves Ed25519 deterministas por
//! clave abstracta (`semilla = SHA3-256("zx-t01-clave" ‖ k u64 LE)` con `ed25519-zebra`), construye
//! transacciones **reales** v1/v2/v3 firmadas por el `firmante` abstracto, mantiene la
//! correspondencia id abstracto de salida → `OutPoint` real, ejecuta el motor en el orden de entrega
//! del fichero y compara `RES`, `SEL` y el estado canónico traducido de vuelta a claves abstractas.
//!
//! Requisito de V4: **0 discrepancias** en todos los casos.

#![expect(clippy::expect_used, reason = "el test falla con panic por diseño")]
#![expect(
    clippy::indexing_slicing,
    reason = "índices sobre vectores construidos en el propio test"
)]

use std::collections::{BTreeMap, VecDeque};
use std::fmt::Write as _;
use std::fs;

use ed25519_zebra::{SigningKey, VerificationKey};
use primitive_types::U256;
use zx_consensus::transicion::{
    BloqueTransicion, ErrorTransicion, Estado, Fase, HechosCabecera, Origen, ParametrosTransicion,
    Punto, aplicar_con_undo, deshacer, seleccionar,
};
use zx_core::preimage::tx::txid as calcular_txid;
use zx_core::{
    Amount, BlockHash, BodyCommitment, CBID_RED_DEV, ClavePublica, DagBlockHeader, Digest,
    ErrorFormaTx, ExtensionTx, HashType, Lock, MerkleRoot, OutPoint, PadresDag, SigHash,
    SolucionPoas, SpentOutput, TipoGarantia, Tx, TxId, TxIn, TxOut,
};

/// Ruta al fichero de vectores dentro del workspace (`ws/testdata/...`).
const RUTA_VECTORES: &str = concat!(
    env!("CARGO_MANIFEST_DIR"),
    "/../../testdata/transicion-v0/vectores-transicion-v0.txt"
);

// ─────────────────────────────────────────────────────────────────────────────
// Claves y salidas abstractas
// ─────────────────────────────────────────────────────────────────────────────

/// Deriva el par determinista de la clave abstracta `k`.
fn firmante_de(k: u64) -> SigningKey {
    let mut mensaje = b"zx-t01-clave".to_vec();
    mensaje.extend_from_slice(&k.to_le_bytes());
    let digest = zx_core::sha3_256_publico(&mensaje);
    SigningKey::from(*digest.as_bytes())
}

/// Clave pública determinista de la clave abstracta `k`.
fn clave_de(k: u64) -> ClavePublica {
    let sk = firmante_de(k);
    let vk = VerificationKey::from(&sk);
    ClavePublica::desde_bytes(vk.into())
}

/// Hash de bloque sintético: el id abstracto en big-endian, para que el orden de bytes coincida con
/// el orden entero que usa el oráculo en los desempates.
fn hash_de(id: u64) -> BlockHash {
    let mut bytes = [0u8; 32];
    bytes[24..].copy_from_slice(&id.to_be_bytes());
    BlockHash::from_digest(Digest::from_bytes(bytes))
}

/// Clave de firma **única por salida abstracta**: dos coinbases idénticas en bloques distintos
/// tendrían el mismo `txid` real y colisionarían en el UTXO, algo que el oráculo no modela porque
/// asigna un id de salida distinto a cada una. La clave se deriva de `(id, dueño)` en un dominio
/// propio, así que cada salida real es distinta sin cambiar ninguna regla.
fn sk_salida(id: u64, dueno: u64) -> SigningKey {
    let mut mensaje = b"zx-t01-salida".to_vec();
    mensaje.extend_from_slice(&id.to_le_bytes());
    mensaje.extend_from_slice(&dueno.to_le_bytes());
    let digest = zx_core::sha3_256_publico(&mensaje);
    SigningKey::from(*digest.as_bytes())
}

fn clave_salida(id: u64, dueno: u64) -> ClavePublica {
    let sk = sk_salida(id, dueno);
    let vk = VerificationKey::from(&sk);
    ClavePublica::desde_bytes(vk.into())
}

/// `OutPoint` sintético para una entrada abstracta sin salida registrada: el motor no lo encontrará
/// y devolverá `ErrDobleGasto`, como el oráculo.
fn outpoint_inexistente(id: u64) -> OutPoint {
    let mut mensaje = b"zx-t01-inexistente".to_vec();
    mensaje.extend_from_slice(&id.to_le_bytes());
    let digest = zx_core::sha3_256_publico(&mensaje);
    OutPoint {
        prev_txid: TxId::from_digest(digest),
        prev_index: 0,
    }
}

/// Registro de una salida abstracta: su `OutPoint` real, valor y dueño.
#[derive(Clone, Copy)]
struct SalidaRef {
    op: OutPoint,
    valor: Amount,
    dueno: u64,
}

/// Correspondencia entre claves abstractas y claves reales.
#[derive(Default)]
struct Claves {
    id_a_clave: BTreeMap<u64, ClavePublica>,
    clave_a_id: BTreeMap<[u8; 32], u64>,
}

impl Claves {
    fn id(&mut self, k: u64) -> ClavePublica {
        if let Some(pk) = self.id_a_clave.get(&k) {
            return *pk;
        }
        let pk = clave_de(k);
        self.id_a_clave.insert(k, pk);
        self.clave_a_id.insert(*pk.bytes(), k);
        pk
    }

    fn abstracta(&self, pk: &ClavePublica) -> Option<u64> {
        self.clave_a_id.get(pk.bytes()).copied()
    }

    /// Registra la clave única de una salida abstracta y la traduce de vuelta a su dueño.
    fn registrar_salida(&mut self, id: u64, dueno: u64) -> ClavePublica {
        let pk = clave_salida(id, dueno);
        self.clave_a_id.insert(*pk.bytes(), dueno);
        pk
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Parser del fichero de vectores
// ─────────────────────────────────────────────────────────────────────────────

/// Campos `clave=valor` de una línea (el primer token es el nombre de la línea).
fn campos(linea: &str) -> BTreeMap<String, String> {
    let mut mapa = BTreeMap::new();
    for token in linea.split_whitespace().skip(1) {
        if let Some((k, v)) = token.split_once('=') {
            mapa.insert(k.to_string(), v.to_string());
        }
    }
    mapa
}

fn parse_salidas(texto: &str) -> Vec<(u64, u64, u64)> {
    let dentro = texto
        .strip_prefix('[')
        .and_then(|s| s.strip_suffix(']'))
        .unwrap_or("");
    if dentro.is_empty() {
        return Vec::new();
    }
    dentro
        .split(',')
        .map(|item| {
            let p: Vec<&str> = item.split(':').collect();
            (
                p[0].parse().expect("id de salida"),
                p[1].parse().expect("valor de salida"),
                p[2].parse().expect("dueño de salida"),
            )
        })
        .collect()
}

fn parse_entradas(texto: &str) -> Vec<u64> {
    let dentro = texto
        .strip_prefix('[')
        .and_then(|s| s.strip_suffix(']'))
        .unwrap_or("");
    if dentro.is_empty() {
        return Vec::new();
    }
    dentro
        .split(',')
        .map(|x| x.parse().expect("id de entrada"))
        .collect()
}

/// Una transacción abstracta leída del fichero.
#[derive(Clone, Debug)]
struct TxCrudo {
    tipo: String,
    firmante: u64,
    clave: u64,
    importe: u64,
    ent: Vec<u64>,
    sal: Vec<(u64, u64, u64)>,
}

/// Un bloque abstracto leído del fichero.
#[derive(Clone, Debug)]
struct BloqueCrudo {
    id: u64,
    fam: String,
    padre: u64,
    altura: u32,
    trabajo: u64,
    pow_ok: bool,
    slot: u64,
    prod: u64,
    peso: u64,
    reqdecl: u64,
    txs: Vec<TxCrudo>,
}

/// Parámetros de prueba de un caso.
#[derive(Clone, Debug)]
struct ParamCrudo {
    h_dep: u32,
    m_cb: u32,
    m_dep: u32,
    h_corte_min: u32,
    w_min: u64,
    s_min: u64,
    k_min: u32,
    q: u64,
    m_res_slots: u64,
    m_dep_slots: u64,
    m_rec_slots: u64,
    r_slots: u64,
    f_slots: Option<u64>,
}

impl ParamCrudo {
    fn vacio() -> Self {
        Self {
            h_dep: 0,
            m_cb: 0,
            m_dep: 0,
            h_corte_min: 0,
            w_min: 0,
            s_min: 0,
            k_min: 0,
            q: 0,
            m_res_slots: 0,
            m_dep_slots: 0,
            m_rec_slots: 0,
            r_slots: 0,
            f_slots: None,
        }
    }
}

/// Un caso completo del fichero.
#[derive(Debug)]
struct Caso {
    n: u64,
    nombre: String,
    param: ParamCrudo,
    bloques: Vec<BloqueCrudo>,
    res: BTreeMap<u64, String>,
    sel: i64,
    utxo: Vec<String>,
    gar: Vec<String>,
    est: String,
}

fn parsear_parametros(c: &BTreeMap<String, String>) -> ParamCrudo {
    let f = c.get("F_slots").expect("F_slots");
    ParamCrudo {
        h_dep: c.get("H_dep").expect("H_dep").parse().expect("H_dep"),
        m_cb: c.get("M_cb").expect("M_cb").parse().expect("M_cb"),
        m_dep: c.get("M_dep").expect("M_dep").parse().expect("M_dep"),
        h_corte_min: c
            .get("H_corte_min")
            .expect("H_corte_min")
            .parse()
            .expect("H_corte_min"),
        w_min: c.get("W_min").expect("W_min").parse().expect("W_min"),
        s_min: c.get("S_min").expect("S_min").parse().expect("S_min"),
        k_min: c.get("K_min").expect("K_min").parse().expect("K_min"),
        q: c.get("q").expect("q").parse().expect("q"),
        m_res_slots: c
            .get("M_res_slots")
            .expect("M_res_slots")
            .parse()
            .expect("M_res_slots"),
        m_dep_slots: c
            .get("M_dep_slots")
            .expect("M_dep_slots")
            .parse()
            .expect("M_dep_slots"),
        m_rec_slots: c
            .get("M_rec_slots")
            .expect("M_rec_slots")
            .parse()
            .expect("M_rec_slots"),
        r_slots: c.get("R_slots").expect("R_slots").parse().expect("R_slots"),
        f_slots: if f == "inf" {
            None
        } else {
            Some(f.parse().expect("F_slots"))
        },
    }
}

fn parsear_fichero(ruta: &str) -> Vec<Caso> {
    let contenido = fs::read_to_string(ruta).expect("leer vectores");
    let mut casos = Vec::new();
    let mut caso: Option<Caso> = None;
    let mut bloque: Option<BloqueCrudo> = None;
    for linea in contenido.lines() {
        if linea.starts_with('#') || linea.trim().is_empty() {
            continue;
        }
        let primera = linea.split_whitespace().next().unwrap_or("");
        match primera {
            "CASO" => {
                let c = campos(linea);
                caso = Some(Caso {
                    n: c.get("n").expect("n").parse().expect("n"),
                    nombre: c.get("nombre").expect("nombre").clone(),
                    param: ParamCrudo::vacio(),
                    bloques: Vec::new(),
                    res: BTreeMap::new(),
                    sel: -1,
                    utxo: Vec::new(),
                    gar: Vec::new(),
                    est: String::new(),
                });
            }
            "PARAM" => {
                if let Some(c) = caso.as_mut() {
                    c.param = parsear_parametros(&campos(linea));
                }
            }
            "BLOQUE" => {
                let c = campos(linea);
                bloque = Some(BloqueCrudo {
                    id: c.get("id").expect("id").parse().expect("id"),
                    fam: c.get("fam").expect("fam").clone(),
                    padre: c.get("padre").expect("padre").parse().expect("padre"),
                    altura: c.get("altura").expect("altura").parse().expect("altura"),
                    trabajo: c.get("trabajo").expect("trabajo").parse().expect("trabajo"),
                    pow_ok: c.get("pow_ok").expect("pow_ok") == "1",
                    slot: c.get("slot").expect("slot").parse().expect("slot"),
                    prod: c.get("prod").expect("prod").parse().expect("prod"),
                    peso: c.get("peso").expect("peso").parse().expect("peso"),
                    reqdecl: c.get("reqdecl").expect("reqdecl").parse().expect("reqdecl"),
                    txs: Vec::new(),
                });
            }
            "TX" => {
                let c = campos(linea);
                if let Some(b) = bloque.as_mut() {
                    b.txs.push(TxCrudo {
                        tipo: c.get("tipo").expect("tipo").clone(),
                        firmante: c
                            .get("firmante")
                            .expect("firmante")
                            .parse()
                            .expect("firmante"),
                        clave: c.get("clave").expect("clave").parse().expect("clave"),
                        importe: c.get("importe").expect("importe").parse().expect("importe"),
                        ent: parse_entradas(c.get("ent").expect("ent")),
                        sal: parse_salidas(c.get("sal").expect("sal")),
                    });
                }
            }
            "RES" => {
                let c = campos(linea);
                let res = c.get("res").expect("res").clone();
                if let Some(b) = bloque.take()
                    && let Some(caso) = caso.as_mut()
                {
                    caso.res.insert(b.id, res);
                    caso.bloques.push(b);
                }
            }
            "SEL" => {
                let c = campos(linea);
                if let Some(caso) = caso.as_mut() {
                    caso.sel = c.get("punta").expect("punta").parse().expect("punta");
                }
            }
            "UTXO" => {
                if let Some(caso) = caso.as_mut() {
                    caso.utxo.push(linea.to_string());
                }
            }
            "GAR" => {
                if let Some(caso) = caso.as_mut() {
                    caso.gar.push(linea.to_string());
                }
            }
            "EST" => {
                if let Some(caso) = caso.as_mut() {
                    caso.est = linea.to_string();
                }
            }
            "FIN" => {
                if let Some(c) = caso.take() {
                    casos.push(c);
                }
            }
            _ => {}
        }
    }
    casos
}

// ─────────────────────────────────────────────────────────────────────────────
// Parámetros y construcción de bloques reales
// ─────────────────────────────────────────────────────────────────────────────

fn subsidio_pow(_h: u32) -> Amount {
    Amount::nuevo(10).expect("subsidio pow")
}

fn subsidio_post(_s: u64) -> Amount {
    Amount::nuevo(3).expect("subsidio post")
}

fn parametros(p: &ParamCrudo) -> ParametrosTransicion {
    ParametrosTransicion {
        h_dep: p.h_dep,
        m_cb: p.m_cb,
        m_dep: p.m_dep,
        h_corte_min: p.h_corte_min,
        w_min: U256::from(p.w_min),
        s_min: Amount::nuevo(p.s_min as i64).expect("S_min"),
        q: Amount::nuevo(p.q as i64).expect("q"),
        k_min: p.k_min,
        m_res_slots: p.m_res_slots,
        m_dep_slots: p.m_dep_slots,
        m_rec_slots: p.m_rec_slots,
        r_slots: p.r_slots,
        f_slots: p.f_slots,
        subsidio_pow,
        subsidio_post,
    }
}

/// Constructor de transacciones reales con la correspondencia de salidas abstractas.
struct Constructor {
    cbid: u32,
    claves: Claves,
    salidas: BTreeMap<u64, SalidaRef>,
}

impl Constructor {
    fn nuevo(cbid: u32) -> Self {
        Self {
            cbid,
            claves: Claves::default(),
            salidas: BTreeMap::new(),
        }
    }

    fn txin(&self, id: u64) -> TxIn {
        let op = self
            .salidas
            .get(&id)
            .map_or_else(|| outpoint_inexistente(id), |s| s.op);
        TxIn {
            outpoint: op,
            sequence: 0,
        }
    }

    fn salidas_reales(&mut self, sal: &[(u64, u64, u64)]) -> Vec<TxOut> {
        sal.iter()
            .map(|(id, valor, dueno)| {
                let pk = self.claves.registrar_salida(*id, *dueno);
                TxOut {
                    value: Amount::nuevo(*valor as i64).expect("valor"),
                    lock: Lock::PubKey { pubkey: pk },
                }
            })
            .collect()
    }

    fn gastadas(&self, ids: &[u64]) -> Vec<SpentOutput> {
        ids.iter()
            .map(|id| match self.salidas.get(id) {
                Some(s) => SpentOutput {
                    value: s.valor,
                    lock: Lock::PubKey {
                        pubkey: clave_salida(*id, s.dueno),
                    },
                },
                None => SpentOutput {
                    value: Amount::CERO,
                    lock: Lock::PubKey {
                        pubkey: clave_de(0),
                    },
                },
            })
            .collect()
    }

    fn registrar(&mut self, tx: &Tx, sal: &[(u64, u64, u64)]) -> Result<(), String> {
        let txid = calcular_txid(tx, self.cbid);
        for (j, (id, valor, dueno)) in sal.iter().enumerate() {
            let op = OutPoint {
                prev_txid: txid,
                prev_index: u32::try_from(j).map_err(|_| "índice de salida".to_string())?,
            };
            let valor = Amount::nuevo(*valor as i64).expect("valor");
            self.salidas.insert(
                *id,
                SalidaRef {
                    op,
                    valor,
                    dueno: *dueno,
                },
            );
        }
        Ok(())
    }

    fn firmar_entradas(&self, tx: &Tx, ids: &[u64], firmante: u64) -> Vec<Vec<u8>> {
        let gastadas = self.gastadas(ids);
        let mut testigos = Vec::with_capacity(ids.len());
        for (i, id) in ids.iter().enumerate() {
            let digest: SigHash =
                zx_core::sighash(tx, &gastadas, HashType::All, i, self.cbid).expect("sighash");
            let sk = match self.salidas.get(id) {
                Some(s) if s.dueno == firmante => sk_salida(*id, s.dueno),
                _ => firmante_de(firmante),
            };
            let firma: [u8; 64] = sk.sign(digest.as_bytes()).into();
            testigos.push(firma.to_vec());
        }
        testigos
    }

    fn aceptacion(&self, tx: &Tx, firmante: u64) -> Vec<u8> {
        let mensaje = zx_core::mensaje_aceptacion(tx, self.cbid);
        let sk = firmante_de(firmante);
        let firma: [u8; 64] = sk.sign(&mensaje).into();
        firma.to_vec()
    }

    /// Construye una transacción abstracta como transacción real con sus testigos.
    fn construir_tx(&mut self, tx: &TxCrudo, productor: u64) -> Result<(Tx, Vec<Vec<u8>>), String> {
        let (real, testigos) = match tx.tipo.as_str() {
            "Coinbase" => {
                let salidas = self.salidas_reales(&tx.sal);
                let real = Tx {
                    version: 1,
                    inputs: Vec::new(),
                    outputs: salidas,
                    lock_time: 0,
                    expiry_height: 0,
                    extension: ExtensionTx::Ninguna,
                };
                (real, Vec::new())
            }
            "Transferencia" => {
                let mut inputs = Vec::with_capacity(tx.ent.len());
                for id in &tx.ent {
                    inputs.push(self.txin(*id));
                }
                let salidas = self.salidas_reales(&tx.sal);
                let real = Tx {
                    version: 1,
                    inputs,
                    outputs: salidas,
                    lock_time: 0,
                    expiry_height: 0,
                    extension: ExtensionTx::Ninguna,
                };
                let testigos = self.firmar_entradas(&real, &tx.ent, tx.firmante);
                (real, testigos)
            }
            "Deposito" | "Retiro" | "Liberacion" => {
                let tipo = match tx.tipo.as_str() {
                    "Deposito" => TipoGarantia::Deposito,
                    "Retiro" => TipoGarantia::Retiro,
                    _ => TipoGarantia::Liberacion,
                };
                let mut inputs = Vec::with_capacity(tx.ent.len());
                for id in &tx.ent {
                    inputs.push(self.txin(*id));
                }
                let salidas = self.salidas_reales(&tx.sal);
                let clave = self.claves.id(tx.clave);
                let real = Tx {
                    version: 2,
                    inputs,
                    outputs: salidas,
                    lock_time: 0,
                    expiry_height: 0,
                    extension: ExtensionTx::Garantia {
                        tipo,
                        clave,
                        importe: Amount::nuevo(tx.importe as i64).expect("importe"),
                    },
                };
                let mut testigos = self.firmar_entradas(&real, &tx.ent, tx.firmante);
                testigos.push(self.aceptacion(&real, tx.firmante));
                (real, testigos)
            }
            "CoinbasePost" => {
                let clave = self.claves.id(productor);
                let real = Tx {
                    version: 3,
                    inputs: Vec::new(),
                    outputs: Vec::new(),
                    lock_time: 0,
                    expiry_height: 0,
                    extension: ExtensionTx::CoinbasePost {
                        clave,
                        importe: Amount::nuevo(tx.importe as i64).expect("importe"),
                    },
                };
                (real, Vec::new())
            }
            "Evidencia" => {
                let real = Tx {
                    version: 4,
                    inputs: Vec::new(),
                    outputs: Vec::new(),
                    lock_time: 0,
                    expiry_height: 0,
                    extension: ExtensionTx::Ninguna,
                };
                (real, Vec::new())
            }
            otro => return Err(format!("tipo de transacción no soportado: {otro}")),
        };
        self.registrar(&real, &tx.sal)?;
        Ok((real, testigos))
    }
}

/// Cabecera PoST sintética con `height = 0` (solo se usa para `validar_forma_cabecera_post`).
fn cabecera_post(padre: BlockHash) -> DagBlockHeader {
    DagBlockHeader {
        consensus_branch_id: CBID_RED_DEV,
        merkle_root: MerkleRoot::from_digest(Digest::from_bytes([0u8; 32])),
        timestamp: 0,
        height: 0,
        slot: 0,
        pot_output: [0u8; 16],
        rango_solucion: 0,
        sol: SolucionPoas::default(),
        body_commitment: BodyCommitment::from_digest(Digest::from_bytes([0u8; 32])),
        padres: PadresDag::nuevo(padre, &[]).expect("padres"),
        sello: [0u8; 64],
    }
}

/// Bloques reales de un caso, con la correspondencia hash ↔ id abstracto.
struct Reales {
    bloques: Vec<BloqueTransicion>,
    hash_a_id: BTreeMap<BlockHash, u64>,
    id_a_idx: BTreeMap<u64, usize>,
    claves: Claves,
}

fn construir_caso(caso: &Caso) -> Result<Reales, String> {
    let mut constructor = Constructor::nuevo(CBID_RED_DEV);
    let mut bloques = Vec::with_capacity(caso.bloques.len());
    let mut hash_a_id = BTreeMap::new();
    let mut id_a_idx = BTreeMap::new();
    for (idx, b) in caso.bloques.iter().enumerate() {
        let productor = b.prod;
        let mut txs = Vec::with_capacity(b.txs.len());
        for tx in &b.txs {
            txs.push(constructor.construir_tx(tx, productor)?);
        }
        let hash = hash_de(b.id);
        let hechos = match b.fam.as_str() {
            "Genesis" => HechosCabecera::Genesis { hash },
            "PoW" => HechosCabecera::PoW {
                hash,
                padre: hash_de(b.padre),
                altura: b.altura,
                trabajo: U256::from(b.trabajo),
                pow_valido: b.pow_ok,
            },
            "PoST" => HechosCabecera::PoST {
                hash,
                padre: hash_de(b.padre),
                slot: b.slot,
                productor: constructor.claves.id(productor),
                peso: u128::from(b.peso),
                prueba_valida: b.pow_ok,
                requisito_declarado: b.reqdecl,
            },
            otra => return Err(format!("familia desconocida: {otra}")),
        };
        let bloque = match b.fam.as_str() {
            "PoST" => {
                BloqueTransicion::con_cabecera_post(hechos, txs, cabecera_post(hash_de(b.padre)))
            }
            _ => BloqueTransicion::nuevo(hechos, txs),
        };
        hash_a_id.insert(hash, b.id);
        id_a_idx.insert(b.id, idx);
        bloques.push(bloque);
    }
    let claves = constructor.claves;
    Ok(Reales {
        bloques,
        hash_a_id,
        id_a_idx,
        claves,
    })
}

// ─────────────────────────────────────────────────────────────────────────────
// Render canónico traducido a claves abstractas
// ─────────────────────────────────────────────────────────────────────────────

fn orden_origen(origen: Origen) -> u8 {
    match origen {
        Origen::CoinbasePow => 0,
        Origen::Tx => 1,
        Origen::Liberacion => 2,
    }
}

fn nombre_fase(fase: Fase) -> &'static str {
    match fase {
        Fase::Genesis => "FaseGenesis",
        Fase::PoW => "FasePoW",
        Fase::PoST => "FasePoST",
    }
}

/// Clave `(dueño, valor, origen, altura, slot)` del render de UTXO del oráculo.
type ClaveUtxo = (u64, u64, u8, i64, i64);

fn utxo_engine(estado: &Estado, claves: &Claves) -> Result<Vec<ClaveUtxo>, String> {
    let mut v = Vec::with_capacity(estado.utxo.len());
    for (op, e) in &estado.utxo {
        let dueno = match &e.lock {
            Lock::PubKey { pubkey } => claves
                .abstracta(pubkey)
                .ok_or_else(|| format!("clave desconocida en salida {op:?}"))?,
            otro => return Err(format!("lock inesperado en UTXO: {otro:?}")),
        };
        let (altura, slot) = match e.creada {
            Punto::Altura(h) => (i64::from(h), -1),
            Punto::Slot(s) => (-1, s as i64),
        };
        v.push((
            dueno,
            u64::try_from(e.valor.brek()).unwrap_or(0),
            orden_origen(e.origen),
            altura,
            slot,
        ));
    }
    v.sort_unstable();
    Ok(v)
}

fn parse_utxo_linea(linea: &str) -> ClaveUtxo {
    let c = campos(linea);
    let altura = c.get("altura").expect("altura");
    let slot = c.get("slot").expect("slot");
    let origen = match c.get("origen").expect("origen").as_str() {
        "CoinbasePow" => 0,
        "Tx" => 1,
        _ => 2,
    };
    (
        c.get("dueño").expect("dueño").parse().expect("dueño"),
        c.get("valor").expect("valor").parse().expect("valor"),
        origen,
        if altura == "-" {
            -1
        } else {
            altura.parse().expect("altura")
        },
        if slot == "-" {
            -1
        } else {
            slot.parse().expect("slot")
        },
    )
}

fn render_gar(claves: &Claves, estado: &Estado) -> Result<Vec<(u64, String)>, String> {
    let mut lineas = Vec::new();
    for (pk, g) in &estado.garantias {
        let clave = claves
            .abstracta(pk)
            .ok_or_else(|| format!("clave desconocida en garantía {pk:?}"))?;
        let mut pendientes = g.pendientes.clone();
        pendientes.sort_by_key(|p| (p.importe, p.madura_en_altura, p.madura_en_slot));
        let ps = pendientes
            .iter()
            .map(|p| match p.madura_en_altura {
                Some(h) => format!("{}@h{}", p.importe.brek(), h),
                None => format!("{}@s{}", p.importe.brek(), p.madura_en_slot.unwrap_or(0)),
            })
            .collect::<Vec<_>>()
            .join(",");
        let mut retiradas = g.en_retirada.clone();
        retiradas.sort_by_key(|r| (r.inicio_slot, r.importe));
        let rs = retiradas
            .iter()
            .map(|r| format!("{}@s{}", r.importe.brek(), r.inicio_slot))
            .collect::<Vec<_>>()
            .join(",");
        let mut creditos = g.creditos.clone();
        creditos.sort_by_key(|p| (p.importe, p.madura_en_slot));
        let cs = creditos
            .iter()
            .map(|p| format!("{}@s{}", p.importe.brek(), p.madura_en_slot.unwrap_or(0)))
            .collect::<Vec<_>>()
            .join(",");
        lineas.push((
            clave,
            format!(
                "GAR clave={clave} activo={} pend=[{ps}] ret=[{rs}] cred=[{cs}] congelado={}",
                g.activo.brek(),
                g.congelado.brek()
            ),
        ));
    }
    lineas.sort_by_key(|(k, _)| *k);
    Ok(lineas)
}

// ─────────────────────────────────────────────────────────────────────────────
// Ejecución diferencial
// ─────────────────────────────────────────────────────────────────────────────

/// Nombre aceptado para un error del motor frente al esperado del fichero (§4).
fn coincide(esperado: &str, error: &ErrorTransicion) -> bool {
    if let ErrorTransicion::ErrForma(ErrorFormaTx::VersionInactiva { .. }) = error {
        return esperado == "ErrOperacionFase" || esperado == "ErrFueraDeAlcanceV0";
    }
    error.nombre_t01() == esperado
}

fn ejecutar_caso(caso: &Caso, discrepancias: &mut Vec<String>) {
    let params = parametros(&caso.param);
    let reales = match construir_caso(caso) {
        Ok(r) => r,
        Err(e) => {
            discrepancias.push(format!("CASO {}: construcción: {e}", caso.n));
            return;
        }
    };
    let inicial = Estado::inicial();
    // BFS sobre los padres abstractos (el génesis no lleva padre en los hechos reales).
    let mut memo: BTreeMap<u64, Estado> = BTreeMap::new();
    if let Some(gi) = caso.bloques.iter().position(|b| b.fam == "Genesis")
        && let Ok((e, _)) = aplicar_con_undo(&inicial, &reales.bloques[gi], &params, CBID_RED_DEV)
    {
        memo.insert(caso.bloques[gi].id, e);
    }
    let mut cola: VecDeque<u64> = memo.keys().copied().collect();
    while let Some(pid) = cola.pop_front() {
        let Some(estado_padre) = memo.get(&pid).cloned() else {
            continue;
        };
        for (i, b) in caso.bloques.iter().enumerate() {
            if b.padre != pid || memo.contains_key(&b.id) {
                continue;
            }
            if let Ok((nuevo, undo)) =
                aplicar_con_undo(&estado_padre, &reales.bloques[i], &params, CBID_RED_DEV)
            {
                if deshacer(&nuevo, &undo) != estado_padre {
                    discrepancias.push(format!("CASO {} undo bloque {}", caso.n, b.id));
                }
                memo.insert(b.id, nuevo);
                cola.push_back(b.id);
            }
        }
    }
    // RES por bloque.
    for (i, b) in caso.bloques.iter().enumerate() {
        let esperado = caso.res.get(&b.id).cloned().unwrap_or_default();
        let padre_conocido = reales.id_a_idx.contains_key(&b.padre);
        let fallo = if memo.contains_key(&b.id) {
            esperado != "OK"
        } else if !padre_conocido || !memo.contains_key(&b.padre) {
            esperado != "ErrSinPadre"
        } else {
            let estado_padre = memo.get(&b.padre).cloned().unwrap_or_else(Estado::inicial);
            match aplicar_con_undo(&estado_padre, &reales.bloques[i], &params, CBID_RED_DEV) {
                Ok(_) => esperado != "OK",
                Err(e) => !coincide(&esperado, &e),
            }
        };
        if fallo {
            let obtenido = if memo.contains_key(&b.id) {
                "OK".to_string()
            } else if !padre_conocido || !memo.contains_key(&b.padre) {
                "ErrSinPadre".to_string()
            } else {
                let estado_padre = memo.get(&b.padre).cloned().unwrap_or_else(Estado::inicial);
                match aplicar_con_undo(&estado_padre, &reales.bloques[i], &params, CBID_RED_DEV) {
                    Ok(_) => "OK".to_string(),
                    Err(e) => e.nombre_t01().to_string(),
                }
            };
            discrepancias.push(format!(
                "CASO {} ({}) bloque {} RES esperado={esperado} obtenido={obtenido}",
                caso.n, caso.nombre, b.id
            ));
        }
    }
    // SEL.
    let seleccion = match seleccionar(&reales.bloques, &params, CBID_RED_DEV) {
        Ok(s) => s,
        Err(e) => {
            discrepancias.push(format!("CASO {}: seleccionar: {e:?}", caso.n));
            return;
        }
    };
    let punta_id = seleccion
        .punta
        .and_then(|h| reales.hash_a_id.get(&h).copied())
        .map_or(-1, |id| id as i64);
    if punta_id != caso.sel {
        discrepancias.push(format!(
            "CASO {} ({}) SEL esperado={} obtenido={punta_id}",
            caso.n, caso.nombre, caso.sel
        ));
    }
    // UTXO.
    let mut esperado_utxo: Vec<ClaveUtxo> = caso.utxo.iter().map(|l| parse_utxo_linea(l)).collect();
    esperado_utxo.sort_unstable();
    match utxo_engine(&seleccion.estado, &reales.claves) {
        Ok(obtenido) => {
            if obtenido != esperado_utxo {
                discrepancias.push(format!(
                    "CASO {} ({}) UTXO esperado={:?} obtenido={:?}",
                    caso.n, caso.nombre, esperado_utxo, obtenido
                ));
            }
        }
        Err(e) => discrepancias.push(format!("CASO {} UTXO: {e}", caso.n)),
    }
    // GAR.
    match render_gar(&reales.claves, &seleccion.estado) {
        Ok(obtenido) => {
            let obtenido: Vec<String> = obtenido.into_iter().map(|(_, l)| l).collect();
            if obtenido != caso.gar {
                discrepancias.push(format!(
                    "CASO {} ({}) GAR esperado={:?} obtenido={:?}",
                    caso.n, caso.nombre, caso.gar, obtenido
                ));
            }
        }
        Err(e) => discrepancias.push(format!("CASO {} GAR: {e}", caso.n)),
    }
    // EST.
    let terminal = seleccion
        .estado
        .terminal
        .and_then(|h| reales.hash_a_id.get(&h).copied())
        .map_or(-1, |id| id as i64);
    let est = format!(
        "EST emitido={} quemado={} fase={} terminal={terminal} altura={} slot={} peso_sufijo={}",
        seleccion.estado.emitido,
        seleccion.estado.quemado,
        nombre_fase(seleccion.estado.fase),
        seleccion.estado.altura,
        seleccion.estado.slot,
        seleccion.estado.peso_sufijo
    );
    if est != caso.est {
        discrepancias.push(format!(
            "CASO {} ({}) EST esperado={} obtenido={est}",
            caso.n, caso.nombre, caso.est
        ));
    }
    // X-16: independencia del orden de entrega.
    if caso.nombre == "X-16" && reales.bloques.len() > 1 {
        let mut invertidos = reales.bloques.clone();
        invertidos.reverse();
        if let Ok(inv) = seleccionar(&invertidos, &params, CBID_RED_DEV)
            && (inv.punta != seleccion.punta || inv.estado != seleccion.estado)
        {
            discrepancias.push(format!("CASO {} X-16 orden inverso difiere", caso.n));
        }
    }
}

fn cargar_casos() -> Vec<Caso> {
    let casos = parsear_fichero(RUTA_VECTORES);
    assert!(!casos.is_empty(), "no se leyeron casos de {RUTA_VECTORES}");
    casos
}

/// V4: diferencial completo contra el oráculo T01.
#[test]
fn diferencial_t01() {
    let casos = cargar_casos();
    let mut discrepancias: Vec<String> = Vec::new();
    let mut por_nombre: BTreeMap<String, (usize, usize)> = BTreeMap::new();
    let mut con_post = 0usize;
    for caso in &casos {
        let antes = discrepancias.len();
        ejecutar_caso(caso, &mut discrepancias);
        let fallo = discrepancias.len() > antes;
        let entrada = por_nombre.entry(caso.nombre.clone()).or_insert((0, 0));
        entrada.0 += 1;
        if fallo {
            entrada.1 += 1;
        }
        if caso.est.contains("fase=FasePoST") {
            con_post += 1;
        }
    }
    let mut informe = String::new();
    let _ = writeln!(informe, "casos leidos      = {}", casos.len());
    let _ = writeln!(informe, "con sufijo PoST   = {con_post}");
    let _ = writeln!(informe, "discrepancias     = {}", discrepancias.len());
    let _ = writeln!(informe, "por nombre de caso:");
    for (nombre, (n, fallos)) in &por_nombre {
        let _ = writeln!(informe, "  {nombre}: {n} casos, {fallos} con discrepancia");
    }
    for d in discrepancias.iter().take(40) {
        let _ = writeln!(informe, "  {d}");
    }
    println!("{informe}");
    assert!(
        discrepancias.is_empty(),
        "diferencial T01 con {} discrepancias:\n{informe}",
        discrepancias.len()
    );
}
