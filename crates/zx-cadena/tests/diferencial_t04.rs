//! Arnés **diferencial** contra el oráculo T04-D (`ORDEN-W06a-B`, V4 y V5).
//!
//! Lee `testdata/estado-dag-v0.3/vectores-estado-dag-v0.3.txt`, deriva claves Ed25519 deterministas
//! por clave abstracta (`semilla = SHA3-256("zx-t01-clave" ‖ k u64 LE)`, igual que W03), construye
//! transacciones **reales** v1/v2/v3 firmadas por el `firmante` abstracto, traduce cada bloque a
//! [`BloqueCadena`] con `padres`, `sr`, `sd`, `ident` y `k` y ejecuta [`Cadena`] en el orden de
//! entrega del fichero.
//!
//! T04-D / F-18: la salida implícita de una `Liberacion` tiene el id abstracto
//! `ID_LIB(clave, nonce, importe) = 2⁶² + clave·2⁴⁰ + nonce·2²⁰ + importe`; el arnés lo decodifica y
//! lo traduce al `(txid, 0)` real. No hay contador de ids implícitos, ni entradas inventadas, ni
//! punto fijo: los vectores v0.3 ya no tienen la colisión de ids del generador v0.2.
//!
//! Compara, por caso: `RES` de cada bloque, `DESC` (transacción descartada y motivo), `SEL`, `UTXO`,
//! `GAR` y `EST`. V4 exige **0 discrepancias** en los 914 casos; V5 exige que la tabla de cobertura
//! de los 900 casos aleatorios sea idéntica a la sección `vectores-v0.3` de `cobertura-v0.3.txt`.
//!
//! Las correspondencias de error son las de `ORDEN-W03` §4 (W03/W02b), sin añadir ninguna.

#![expect(clippy::expect_used, reason = "el test falla con panic por diseño")]
#![expect(
    clippy::indexing_slicing,
    reason = "índices sobre vectores construidos en el propio test"
)]

use std::collections::{BTreeMap, BTreeSet};
use std::fmt::Write as _;
use std::fs;

use ed25519_zebra::{SigningKey, VerificationKey};
use primitive_types::U256;
use zx_cadena::{BloqueCadena, BloquePost, Cadena, Descarte};
use zx_consensus::transicion::{
    BloqueTransicion, Estado, Fase, HechosCabecera, ParametrosTransicion,
};
use zx_consensus::transicion::{ErrorTransicion, Origen, Punto};
use zx_core::preimage::tx::txid as calcular_txid;
use zx_core::{
    Amount, BlockHash, CBID_RED_DEV, ClavePublica, ExtensionTx, HashType, Lock, OutPoint,
    SpentOutput, TipoGarantia, Tx, TxId, TxIn, TxOut,
};
use zx_dag::IdentidadGhostdag;

/// Vectores v0.3 dentro del workspace (`ws/testdata/...`).
const RUTA_VECTORES: &str = concat!(
    env!("CARGO_MANIFEST_DIR"),
    "/../../testdata/estado-dag-v0.3/vectores-estado-dag-v0.3.txt"
);
/// Tabla de cobertura esperada de T04-D.
const RUTA_COBERTURA: &str = concat!(
    env!("CARGO_MANIFEST_DIR"),
    "/../../testdata/estado-dag-v0.3/cobertura-v0.3.txt"
);
/// Máximo de padres del generador de T04, declarado (`ORDEN-W06a-C` decisión 1): sus vectores no
/// admiten más de 3 y la identidad viaja como `u64` de fixture (`IdentidadGhostdag::de_fixture`).
/// Es el **único** consumidor de ese dominio: la ruta de producción usa la tupla real.
const MAX_PADRES_ARNES: u8 = 3;

// ─────────────────────────────────────────────────────────────────────────────
// Claves y salidas abstractas
// ─────────────────────────────────────────────────────────────────────────────

fn firmante_de(k: u64) -> SigningKey {
    let mut mensaje = b"zx-t01-clave".to_vec();
    mensaje.extend_from_slice(&k.to_le_bytes());
    let digest = zx_core::sha3_256_publico(&mensaje);
    SigningKey::from(*digest.as_bytes())
}

fn clave_de(k: u64) -> ClavePublica {
    let sk = firmante_de(k);
    let vk = VerificationKey::from(&sk);
    ClavePublica::desde_bytes(vk.into())
}

/// Hash de bloque sintético con el **mismo** mapeo que GDR-v0.2/T04: el terminal es `"T"` y cada
/// bloque es `"B<id>"`, en ASCII rellenado a 32 bytes por la derecha (`hash_de_id` de `modelo.jl`).
/// El orden de bytes de esos hashes es el que decide los empates de GHOSTDAG (`C-GD-03`/`C-GD-05`).
fn hash_abstracto(id: u64, terminal_id: Option<u64>) -> BlockHash {
    if Some(id) == terminal_id {
        zx_dag::hash_de_id_textual("T")
    } else {
        zx_dag::hash_de_id_textual(&format!("B{id}"))
    }
}

fn outpoint_inexistente(id: u64) -> OutPoint {
    let mut mensaje = b"zx-t01-inexistente".to_vec();
    mensaje.extend_from_slice(&id.to_le_bytes());
    let digest = zx_core::sha3_256_publico(&mensaje);
    OutPoint {
        prev_txid: TxId::from_digest(digest),
        prev_index: 0,
    }
}

/// Base del rango reservado a las salidas de liberación (T01-E / F-18).
const ID_LIB_BASE: u64 = 1 << 62;
/// Máscara de 20 bits: `clave`, `nonce` e `importe` viven en `[0, 2²⁰)`.
const MASCARA_20: u64 = (1 << 20) - 1;

/// Deshace `ID_LIB(clave, nonce, importe) = 2⁶² + clave·2⁴⁰ + nonce·2²⁰ + importe`.
///
/// Devuelve `None` para un id explícito (`< 2⁶²`) o fuera del rango de 60 bits de la codificación.
fn decodificar_id_lib(id: u64) -> Option<(u64, u64, u64)> {
    let resto = id.checked_sub(ID_LIB_BASE)?;
    if (resto >> 60) != 0 {
        return None;
    }
    let importe = resto & MASCARA_20;
    let nonce = (resto >> 20) & MASCARA_20;
    let clave = (resto >> 40) & MASCARA_20;
    Some((clave, nonce, importe))
}

#[derive(Clone, Copy)]
struct SalidaRef {
    op: OutPoint,
    valor: Amount,
    dueno: u64,
}

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
}

// ─────────────────────────────────────────────────────────────────────────────
// Parser del fichero de vectores
// ─────────────────────────────────────────────────────────────────────────────

fn campos(linea: &str) -> BTreeMap<String, String> {
    let mut mapa = BTreeMap::new();
    for token in linea.split_whitespace().skip(1) {
        if let Some((k, v)) = token.split_once('=') {
            mapa.insert(k.to_string(), v.to_string());
        }
    }
    mapa
}

fn desnudar(texto: &str) -> &str {
    texto
        .strip_prefix('[')
        .and_then(|s| s.strip_suffix(']'))
        .unwrap_or("")
}

fn parse_lista_u64(texto: &str) -> Vec<u64> {
    let dentro = desnudar(texto);
    if dentro.is_empty() {
        return Vec::new();
    }
    dentro
        .split(',')
        .map(|x| x.parse().expect("entero"))
        .collect()
}

fn parse_salidas(texto: &str) -> Vec<(u64, u64, u64)> {
    let dentro = desnudar(texto);
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

#[derive(Clone, Debug)]
struct TxCrudo {
    tipo: String,
    firmante: u64,
    clave: u64,
    importe: u64,
    ent: Vec<u64>,
    sal: Vec<(u64, u64, u64)>,
    nonce: u64,
}

#[derive(Clone, Debug)]
struct BloqueCrudo {
    id: u64,
    fam: String,
    padres: Vec<u64>,
    altura: u32,
    trabajo: u64,
    pow_ok: bool,
    slot: u64,
    prod: u64,
    peso: u64,
    sr: u64,
    sd: u64,
    ident: u64,
    reqdecl: u64,
    txs: Vec<TxCrudo>,
}

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
    k: u32,
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
            k: 0,
        }
    }
}

#[derive(Debug)]
struct Caso {
    n: u64,
    nombre: String,
    param: ParamCrudo,
    bloques: Vec<BloqueCrudo>,
    res: BTreeMap<u64, String>,
    desc: Vec<(u64, u64, String)>,
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
        k: c.get("k").expect("k").parse().expect("k"),
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
                    desc: Vec::new(),
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
                    padres: parse_lista_u64(c.get("padres").expect("padres")),
                    altura: c.get("altura").expect("altura").parse().expect("altura"),
                    trabajo: c.get("trabajo").expect("trabajo").parse().expect("trabajo"),
                    pow_ok: c.get("pow_ok").expect("pow_ok") == "1",
                    slot: c.get("slot").expect("slot").parse().expect("slot"),
                    prod: c.get("prod").expect("prod").parse().expect("prod"),
                    peso: c.get("peso").expect("peso").parse().expect("peso"),
                    sr: c.get("sr").expect("sr").parse().expect("sr"),
                    sd: c.get("sd").expect("sd").parse().expect("sd"),
                    ident: c.get("ident").expect("ident").parse().expect("ident"),
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
                        ent: parse_lista_u64(c.get("ent").expect("ent")),
                        sal: parse_salidas(c.get("sal").expect("sal")),
                        nonce: c.get("nonce").map_or(0, |v| v.parse().expect("nonce")),
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
            "DESC" => {
                let c = campos(linea);
                if let Some(caso) = caso.as_mut() {
                    caso.desc.push((
                        c.get("bloque").expect("bloque").parse().expect("bloque"),
                        c.get("tx").expect("tx").parse().expect("tx"),
                        c.get("motivo").expect("motivo").clone(),
                    ));
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

struct Constructor {
    cbid: u32,
    claves: Claves,
    /// Salidas explícitas (`id < 2⁶²`): coinbases, transferencias y cambios.
    salidas: BTreeMap<u64, SalidaRef>,
    /// Salidas de liberaciones, indexadas por el `(clave, nonce, importe)` que decodifica su
    /// `ID_LIB`. Su `OutPoint` real es `(txid, 0)`; no hay contador de ids implícitos.
    liberaciones: BTreeMap<(u64, u64, u64), SalidaRef>,
}

impl Constructor {
    fn nuevo(cbid: u32) -> Self {
        Self {
            cbid,
            claves: Claves::default(),
            salidas: BTreeMap::new(),
            liberaciones: BTreeMap::new(),
        }
    }

    /// Resuelve una entrada abstracta a su salida real: los ids explícitos por su mapa; los ids de
    /// liberación (`≥ 2⁶²`) decodificando `(clave, nonce, importe)` y buscando el `(txid, 0)`
    /// registrado al construirla. Una entrada sin salida creada queda ausente.
    fn salida(&self, id: u64) -> Option<&SalidaRef> {
        if let Some(triple) = decodificar_id_lib(id) {
            self.liberaciones.get(&triple)
        } else {
            self.salidas.get(&id)
        }
    }

    fn txin(&self, id: u64) -> TxIn {
        let op = self
            .salida(id)
            .map_or_else(|| outpoint_inexistente(id), |s| s.op);
        TxIn {
            outpoint: op,
            sequence: 0,
        }
    }

    fn salidas_reales(&mut self, sal: &[(u64, u64, u64)]) -> Vec<TxOut> {
        sal.iter()
            .map(|(_id, valor, dueno)| {
                let pk = self.claves.id(*dueno);
                TxOut {
                    value: Amount::nuevo(*valor as i64).expect("valor"),
                    lock: Lock::PubKey { pubkey: pk },
                }
            })
            .collect()
    }

    fn gastadas(&self, ids: &[u64]) -> Vec<SpentOutput> {
        ids.iter()
            .map(|id| match self.salida(*id) {
                Some(s) => SpentOutput {
                    value: s.valor,
                    lock: Lock::PubKey {
                        pubkey: clave_de(s.dueno),
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

    /// Registra la salida implícita de una `Liberacion` (F-18): su id abstracto es
    /// `ID_LIB(clave, nonce, importe)` y su `OutPoint` real `(txid, 0)`. Se indexa por el triple
    /// que decodifica ese id, sin contador.
    fn registrar_liberacion(
        &mut self,
        tx: &Tx,
        importe: u64,
        clave_abstracta: u64,
        nonce: u64,
    ) -> Result<(), String> {
        let valor = i64::try_from(importe)
            .map_err(|_| "importe de liberación fuera de rango".to_string())?;
        let txid = calcular_txid(tx, self.cbid);
        self.liberaciones.insert(
            (clave_abstracta, nonce, importe),
            SalidaRef {
                op: OutPoint {
                    prev_txid: txid,
                    prev_index: 0,
                },
                valor: Amount::nuevo(valor).expect("importe de liberación"),
                dueno: clave_abstracta,
            },
        );
        Ok(())
    }

    fn firmar_entradas(&self, tx: &Tx, ids: &[u64], firmante: u64) -> Vec<Vec<u8>> {
        let gastadas = self.gastadas(ids);
        let mut testigos = Vec::with_capacity(ids.len());
        for (i, _id) in ids.iter().enumerate() {
            let digest: zx_core::SigHash =
                zx_core::sighash(tx, &gastadas, HashType::All, i, self.cbid).expect("sighash");
            let sk = firmante_de(firmante);
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

    fn construir_tx(
        &mut self,
        tx: &TxCrudo,
        productor: u64,
        altura: u32,
        slot: u64,
    ) -> Result<(Tx, Vec<Vec<u8>>), String> {
        let (real, testigos) = match tx.tipo.as_str() {
            "Coinbase" => {
                let salidas = self.salidas_reales(&tx.sal);
                let real = Tx {
                    version: 1,
                    inputs: Vec::new(),
                    outputs: salidas,
                    lock_time: 0,
                    expiry_height: altura,
                    extension: ExtensionTx::Ninguna,
                };
                (real, Vec::new())
            }
            "Transferencia" => {
                let mut inputs = Vec::with_capacity(tx.ent.len());
                for id in &tx.ent {
                    inputs.push(self.txin(*id));
                }
                // El formato real `OutPoint = (txid, índice)` no distingue dos transferencias
                // abstractas con el mismo contenido (mismos prevouts y mismas salidas en
                // valor/dueño) pero distinto id de salida, y el oráculo sí (sus ids son únicos).
                // Se fija `sequence` (campo que el motor no interpreta) con el id abstracto de la
                // primera salida para que el `txid` real sea inyectivo en el contenido abstracto.
                let secuencia = tx.sal.first().map_or(0, |(id, _, _)| *id);
                let secuencia = u32::try_from(secuencia)
                    .map_err(|_| "id abstracto fuera de u32 para sequence".to_string())?;
                for input in &mut inputs {
                    input.sequence = secuencia;
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
                        nonce: tx.nonce,
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
                        slot,
                    },
                };
                (real, Vec::new())
            }
            otro => return Err(format!("tipo de transacción no soportado: {otro}")),
        };
        self.registrar(&real, &tx.sal)?;
        if tx.tipo == "Liberacion" {
            self.registrar_liberacion(&real, tx.importe, tx.clave, tx.nonce)?;
        }
        Ok((real, testigos))
    }
}

struct Reales {
    bloques: Vec<BloqueCadena>,
    hash_a_id: BTreeMap<BlockHash, u64>,
    hash_a_idx: BTreeMap<BlockHash, usize>,
    claves: Claves,
}

fn construir_reales(caso: &Caso) -> Result<Reales, String> {
    // El terminal es el padre del primer bloque PoST; su id abstracto se mapea a `"T"`.
    let terminal_id = caso
        .bloques
        .iter()
        .find(|b| b.fam == "PoST")
        .and_then(|b| b.padres.first().copied());
    let h = |id: u64| hash_abstracto(id, terminal_id);
    let mut constructor = Constructor::nuevo(CBID_RED_DEV);
    let mut bloques = Vec::with_capacity(caso.bloques.len());
    let mut hash_a_id = BTreeMap::new();
    let mut hash_a_idx = BTreeMap::new();
    for (idx, b) in caso.bloques.iter().enumerate() {
        let productor = b.prod;
        let mut txs = Vec::with_capacity(b.txs.len());
        for tx in &b.txs {
            txs.push(constructor.construir_tx(tx, productor, b.altura, b.slot)?);
        }
        let hash = h(b.id);
        let bloque = match b.fam.as_str() {
            "Genesis" => BloqueCadena::Pow(BloqueTransicion::nuevo(
                HechosCabecera::Genesis { hash },
                txs,
            )),
            "PoW" => {
                let padre = h(*b.padres.first().ok_or("PoW sin padre")?);
                BloqueCadena::Pow(BloqueTransicion::nuevo(
                    HechosCabecera::PoW {
                        hash,
                        padre,
                        altura: b.altura,
                        trabajo: U256::from(b.trabajo),
                        pow_valido: b.pow_ok,
                    },
                    txs,
                ))
            }
            "PoST" => BloqueCadena::Post(BloquePost {
                hash,
                padres: b.padres.iter().map(|p| h(*p)).collect(),
                slot: b.slot,
                productor: constructor.claves.id(productor),
                peso: u128::from(b.peso),
                prueba_valida: b.pow_ok,
                requisito_declarado: b.reqdecl,
                sr: b.sr,
                distancia: b.sd,
                identidad: IdentidadGhostdag::de_fixture(b.ident),
                txs,
            }),
            otra => return Err(format!("familia desconocida: {otra}")),
        };
        hash_a_id.insert(hash, b.id);
        hash_a_idx.insert(hash, idx);
        bloques.push(bloque);
    }
    let claves = constructor.claves;
    Ok(Reales {
        bloques,
        hash_a_id,
        hash_a_idx,
        claves,
    })
}

/// Caso resuelto: bloques reales, cadena admitida, estado de la historia, orden y descartes.
type Resuelto = (Reales, Cadena, Estado, Vec<BlockHash>, Vec<Descarte>);

/// Construye los bloques reales una sola vez y aplica la historia. Con F-18 no hay colisión de ids
/// que exija un punto fijo: la salida de cada liberación se traduce a su `(txid, 0)` real por
/// contenido.
fn construir_y_resolver(caso: &Caso) -> Result<Resuelto, String> {
    let params = parametros(&caso.param);
    let reales = construir_reales(caso)?;
    let mut cadena = Cadena::nueva(params, caso.param.k, CBID_RED_DEV, MAX_PADRES_ARNES);
    for bloque in &reales.bloques {
        let _ = cadena.admitir(bloque.clone());
    }
    let (estado, orden, desc) = cadena
        .aplicar_historia()
        .map_err(|motivo| motivo.nombre().to_string())?;
    Ok((reales, cadena, estado, orden, desc))
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

fn render_gar(claves: &Claves, estado: &Estado) -> Result<Vec<String>, String> {
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
        lineas.push(format!(
            "GAR clave={clave} activo={} pend=[{ps}] ret=[{rs}] cred=[{cs}] congelado={} nonce={}",
            g.activo.brek(),
            g.congelado.brek(),
            g.nonce_siguiente
        ));
    }
    lineas.sort();
    Ok(lineas)
}

// ─────────────────────────────────────────────────────────────────────────────
// Tabla de cobertura (V4b)
// ─────────────────────────────────────────────────────────────────────────────

const TIPOS_COBERTURA: [&str; 4] = ["Transferencia", "Deposito", "Retiro", "Liberacion"];
const TIPOS_GARANTIA: [&str; 3] = ["Deposito", "Retiro", "Liberacion"];
const MOTIVOS_COBERTURA: [&str; 8] = [
    "ErrNonce",
    "ErrDobleGasto",
    "ErrSaldo",
    "ErrRetiroPendiente",
    "ErrAutorizacion",
    "ErrInmaduro",
    "ErrOperacionFase",
    "ErrEmision",
];

#[derive(Default)]
struct Cobertura {
    construidas: BTreeMap<String, u64>,
    aplicadas: BTreeMap<String, u64>,
    descartes: BTreeMap<String, BTreeMap<String, u64>>,
    reorgs: u64,
    casos: u64,
}

fn tipo_cobertura(tx: &Tx) -> Option<&'static str> {
    match &tx.extension {
        ExtensionTx::Garantia {
            tipo: TipoGarantia::Deposito,
            ..
        } => Some("Deposito"),
        ExtensionTx::Garantia {
            tipo: TipoGarantia::Retiro,
            ..
        } => Some("Retiro"),
        ExtensionTx::Garantia {
            tipo: TipoGarantia::Liberacion,
            ..
        } => Some("Liberacion"),
        _ if tx.version == 1 && !tx.inputs.is_empty() => Some("Transferencia"),
        _ => None,
    }
}

fn es_garantia(tx: &Tx) -> bool {
    matches!(tx.extension, ExtensionTx::Garantia { .. })
}

fn operaciones_garantia_aplicadas(cadena: &Cadena) -> BTreeSet<(BlockHash, usize)> {
    let Ok((_estado, orden, desc)) = cadena.aplicar_historia() else {
        return BTreeSet::new();
    };
    let descartadas: BTreeSet<(BlockHash, usize)> =
        desc.iter().map(|d| (d.bloque, d.indice)).collect();
    let mut ops = BTreeSet::new();
    for hash in orden {
        if let Some(bloque) = cadena.bloque(&hash) {
            for (i, (tx, _)) in bloque.txs().iter().enumerate() {
                if es_garantia(tx) && !descartadas.contains(&(hash, i)) {
                    ops.insert((hash, i));
                }
            }
        }
    }
    ops
}

fn reorgs_que_deshacen_garantia(reales: &Reales, params: ParametrosTransicion, k: u32) -> u64 {
    let mut cadena = Cadena::nueva(params, k, CBID_RED_DEV, MAX_PADRES_ARNES);
    let mut prev_tip: Option<BlockHash> = None;
    let mut prev_ops: BTreeSet<(BlockHash, usize)> = BTreeSet::new();
    let mut reorgs = 0u64;
    for bloque in &reales.bloques {
        let _ = cadena.admitir(bloque.clone());
        if !matches!(bloque, BloqueCadena::Post(_)) {
            continue;
        }
        let tip = cadena.mejor_punta();
        if tip == prev_tip {
            continue;
        }
        let ops = operaciones_garantia_aplicadas(&cadena);
        if !prev_ops.is_subset(&ops) {
            reorgs += 1;
        }
        prev_tip = tip;
        prev_ops = ops;
    }
    reorgs
}

fn acumular_caso(
    cobertura: &mut Cobertura,
    reales: &Reales,
    orden: &[BlockHash],
    desc: &[Descarte],
    params: ParametrosTransicion,
    k: u32,
) {
    for bloque in &reales.bloques {
        if let BloqueCadena::Post(p) = bloque {
            for (tx, _) in &p.txs {
                if let Some(t) = tipo_cobertura(tx) {
                    *cobertura.construidas.entry(t.to_string()).or_insert(0) += 1;
                }
            }
        }
    }
    let descartadas: BTreeMap<(BlockHash, usize), &ErrorTransicion> = desc
        .iter()
        .map(|d| ((d.bloque, d.indice), &d.motivo))
        .collect();
    for hash in orden {
        let Some(idx) = reales.hash_a_idx.get(hash).copied() else {
            continue;
        };
        let Some(bloque) = reales.bloques.get(idx) else {
            continue;
        };
        for (i, (tx, _)) in bloque.txs().iter().enumerate() {
            let Some(t) = tipo_cobertura(tx) else {
                continue;
            };
            if let Some(motivo) = descartadas.get(&(*hash, i)) {
                *cobertura
                    .descartes
                    .entry(t.to_string())
                    .or_default()
                    .entry(motivo.nombre_t01().to_string())
                    .or_insert(0) += 1;
            } else {
                *cobertura.aplicadas.entry(t.to_string()).or_insert(0) += 1;
            }
        }
    }
    cobertura.reorgs += reorgs_que_deshacen_garantia(reales, params, k);
    cobertura.casos += 1;
}

fn valor(mapa: &BTreeMap<String, u64>, clave: &str) -> u64 {
    mapa.get(clave).copied().unwrap_or(0)
}

fn generar_lineas(c: &Cobertura) -> Vec<String> {
    let mut out = Vec::new();
    out.push("SECCION vectores-v0.3 (casos aleatorios)".to_string());
    out.push(format!("casos = {}", c.casos));
    for t in TIPOS_COBERTURA {
        let desc_t = c.descartes.get(t);
        let dtot: u64 = desc_t.map(|m| m.values().sum()).unwrap_or(0);
        let motivos = MOTIVOS_COBERTURA
            .iter()
            .map(|m| {
                format!(
                    "{m}={}",
                    desc_t.and_then(|d| d.get(*m)).copied().unwrap_or(0)
                )
            })
            .collect::<Vec<_>>()
            .join(" ");
        let conocidos: u64 = MOTIVOS_COBERTURA
            .iter()
            .map(|m| desc_t.and_then(|d| d.get(*m)).copied().unwrap_or(0))
            .sum();
        let aplicadas = valor(&c.aplicadas, t);
        let construidas = valor(&c.construidas, t);
        let evaluadas = aplicadas + dtot;
        out.push(format!(
            "TIPO {t} construidas={construidas} aplicadas={aplicadas} descartadas={dtot} evaluadas={evaluadas} en_ramas_no_seleccionadas={} {motivos} otros={}",
            construidas - evaluadas,
            dtot - conocidos
        ));
    }
    let cons_gar: u64 = TIPOS_GARANTIA
        .iter()
        .map(|t| valor(&c.construidas, t))
        .sum();
    let eval_gar: u64 = TIPOS_GARANTIA
        .iter()
        .map(|t| {
            valor(&c.aplicadas, t)
                + c.descartes
                    .get(*t)
                    .map(|m| m.values().sum::<u64>())
                    .unwrap_or(0)
        })
        .sum();
    let errnonce: u64 = TIPOS_GARANTIA
        .iter()
        .map(|t| {
            c.descartes
                .get(*t)
                .and_then(|m| m.get("ErrNonce"))
                .copied()
                .unwrap_or(0)
        })
        .sum();
    let doble: u64 = TIPOS_COBERTURA
        .iter()
        .map(|t| {
            c.descartes
                .get(*t)
                .and_then(|m| m.get("ErrDobleGasto"))
                .copied()
                .unwrap_or(0)
        })
        .sum();
    out.push(format!("garantia_construidas = {cons_gar}"));
    out.push(format!("garantia_evaluadas = {eval_gar}"));
    out.push(format!("garantia_errnonce = {errnonce}"));
    out.push(format!(
        "garantia_errnonce_pct_construidas = {:.2}",
        if cons_gar == 0 {
            0.0
        } else {
            100.0 * errnonce as f64 / cons_gar as f64
        }
    ));
    out.push(format!(
        "garantia_errnonce_pct_evaluadas = {:.2}",
        if eval_gar == 0 {
            0.0
        } else {
            100.0 * errnonce as f64 / eval_gar as f64
        }
    ));
    out.push(format!("err_doble_gasto_total = {doble}"));
    out.push(format!(
        "reorganizaciones_que_deshacen_garantia = {}",
        c.reorgs
    ));
    out
}

fn cobertura_esperada() -> Vec<String> {
    let texto = fs::read_to_string(RUTA_COBERTURA).expect("leer cobertura");
    let mut lineas = Vec::new();
    let mut dentro = false;
    for linea in texto.lines() {
        if linea.starts_with("SECCION vectores-v0.3") {
            dentro = true;
            lineas.push(linea.to_string());
            continue;
        }
        if dentro {
            if linea.starts_with("SECCION ") {
                break;
            }
            lineas.push(linea.to_string());
        }
    }
    lineas
}

// ─────────────────────────────────────────────────────────────────────────────
// Ejecución diferencial
// ─────────────────────────────────────────────────────────────────────────────

fn ejecutar_caso(caso: &Caso, discrepancias: &mut Vec<String>, cobertura: &mut Cobertura) {
    let params = parametros(&caso.param);
    let (reales, cadena, estado, orden, desc) = match construir_y_resolver(caso) {
        Ok(x) => x,
        Err(e) => {
            discrepancias.push(format!("CASO {}: construcción: {e}", caso.n));
            return;
        }
    };
    for bloque in &reales.bloques {
        let hash = bloque.hash();
        let id = reales.hash_a_id.get(&hash).copied().unwrap_or(0);
        let esperado = caso.res.get(&id).cloned().unwrap_or_default();
        let obtenido = if cadena.es_valido(&hash) {
            "OK".to_string()
        } else {
            cadena
                .motivo(&hash)
                .map_or_else(|| "ErrSinPadre".to_string(), |m| m.nombre().to_string())
        };
        if obtenido != esperado {
            discrepancias.push(format!(
                "CASO {} ({}) bloque {} RES esperado={esperado} obtenido={obtenido}",
                caso.n, caso.nombre, id
            ));
        }
    }
    // DESC.
    let obtenido_desc: Vec<(u64, u64, String)> = desc
        .iter()
        .map(|d| {
            (
                reales.hash_a_id.get(&d.bloque).copied().unwrap_or(0),
                d.indice as u64 + 1,
                d.motivo.nombre_t01().to_string(),
            )
        })
        .collect();
    if obtenido_desc != caso.desc {
        discrepancias.push(format!(
            "CASO {} ({}) DESC esperado={:?} obtenido={:?}",
            caso.n, caso.nombre, caso.desc, obtenido_desc
        ));
    }
    // SEL.
    let punta = cadena
        .mejor_punta()
        .and_then(|h| reales.hash_a_id.get(&h).copied())
        .map_or(-1, |id| id as i64);
    if punta != caso.sel {
        discrepancias.push(format!(
            "CASO {} ({}) SEL esperado={} obtenido={punta}",
            caso.n, caso.nombre, caso.sel
        ));
    }
    // UTXO.
    let mut esperado_utxo: Vec<ClaveUtxo> = caso.utxo.iter().map(|l| parse_utxo_linea(l)).collect();
    esperado_utxo.sort_unstable();
    match utxo_engine(&estado, &reales.claves) {
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
    match render_gar(&reales.claves, &estado) {
        Ok(obtenido) => {
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
    let terminal = estado
        .terminal
        .and_then(|h| reales.hash_a_id.get(&h).copied())
        .map_or(-1, |id| id as i64);
    let est = format!(
        "EST emitido={} quemado={} fase={} terminal={terminal} altura={} slot={} peso_sufijo={}",
        estado.emitido,
        estado.quemado,
        nombre_fase(estado.fase),
        estado.altura,
        estado.slot,
        estado.peso_sufijo
    );
    if est != caso.est {
        discrepancias.push(format!(
            "CASO {} ({}) EST esperado={} obtenido={est}",
            caso.n, caso.nombre, caso.est
        ));
    }
    if caso.nombre == "aleatorio" {
        acumular_caso(cobertura, &reales, &orden, &desc, params, caso.param.k);
    }
}

fn cargar_casos(ruta: &str) -> Vec<Caso> {
    let casos = parsear_fichero(ruta);
    assert!(!casos.is_empty(), "no se leyeron casos de {ruta}");
    casos
}

fn correr() -> (String, Vec<String>, Vec<String>, Vec<String>) {
    let casos = cargar_casos(RUTA_VECTORES);
    let mut discrepancias: Vec<String> = Vec::new();
    let mut cobertura = Cobertura::default();
    let mut por_nombre: BTreeMap<String, (usize, usize)> = BTreeMap::new();
    for caso in &casos {
        let antes = discrepancias.len();
        ejecutar_caso(caso, &mut discrepancias, &mut cobertura);
        let fallo = discrepancias.len() > antes;
        let entrada = por_nombre.entry(caso.nombre.clone()).or_insert((0, 0));
        entrada.0 += 1;
        if fallo {
            entrada.1 += 1;
        }
    }
    let esperado_cob = cobertura_esperada();
    let obtenido_cob = generar_lineas(&cobertura);
    let mut diferencias_cob = Vec::new();
    if esperado_cob.len() != obtenido_cob.len() {
        diferencias_cob.push(format!(
            "longitud de cobertura esperada={} obtenida={}",
            esperado_cob.len(),
            obtenido_cob.len()
        ));
    }
    for (e, o) in esperado_cob.iter().zip(obtenido_cob.iter()) {
        if e != o {
            diferencias_cob.push(format!("esperado={e} obtenido={o}"));
        }
    }
    let mut informe = String::new();
    let _ = writeln!(informe, "casos leidos      = {}", casos.len());
    let _ = writeln!(informe, "discrepancias     = {}", discrepancias.len());
    let _ = writeln!(informe, "por nombre de caso:");
    for (nombre, (n, fallos)) in &por_nombre {
        let _ = writeln!(informe, "  {nombre}: {n} casos, {fallos} con discrepancia");
    }
    for d in discrepancias.iter().take(40) {
        let _ = writeln!(informe, "  {d}");
    }
    let _ = writeln!(informe, "cobertura (tabla del arnés):");
    for l in &obtenido_cob {
        let _ = writeln!(informe, "  {l}");
    }
    (informe, discrepancias, diferencias_cob, obtenido_cob)
}

/// V4 · diferencial completo contra T04-D (`vectores-estado-dag-v0.3.txt`, 914 casos).
#[test]
fn diferencial_t04() {
    let (informe, discrepancias, diferencias_cob, _cob) = correr();
    println!("{informe}");
    assert!(
        discrepancias.is_empty(),
        "diferencial T04 con {} discrepancias:\n{informe}",
        discrepancias.len()
    );
    assert!(
        diferencias_cob.is_empty(),
        "cobertura V4b con {} diferencias:\n{}",
        diferencias_cob.len(),
        diferencias_cob.join("\n")
    );
}
