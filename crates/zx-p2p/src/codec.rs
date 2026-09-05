//! Códec del protocolo de sincronización (SPEC §16.1, C-NET-11, C-WIRE-04).
//!
//! # El trait `Codec` no impone ningún límite de tamaño
//!
//! Es el hallazgo más importante de la investigación de libp2p, y no es obvio leyendo el trait:
//! `read_request`/`read_response` reciben un `AsyncRead` y **nada** acota cuánto leen. El
//! `.take(N)` es responsabilidad de cada implementación. La de referencia del propio crate
//! (`request-response/src/cbor.rs`) lo hace explícitamente; una escrita "de forma natural" con
//! `read_to_end` deja que un peer reserve la memoria que quiera **antes** de que el parser pueda
//! rechazar nada.
//!
//! # Y `.take(N)` por sí solo NO basta
//!
//! Este es el matiz que casi se cuela. `AsyncReadExt::take(N)` acota la lectura a `N` bytes, así
//! que la memoria queda contenida — bien. Pero si el emisor manda **más** de `N`, no produce un
//! error de "demasiado grande": **trunca en silencio**, y lo que falla después es el parseo, con
//! un error de datos corruptos que no dice nada del tamaño.
//!
//! Eso importa por C-NET-05: un truncamiento silencioso se clasificaría como `Ilegible` —"este
//! peer habla otro dialecto"— cuando en realidad es `Excedido` —"este peer mandó algo que no
//! debía"—. Son motivos distintos con políticas distintas.
//!
//! Así que aquí se lee hasta `N` y **se comprueba si se llegó al tope**: si se llegó, es que había
//! más, y se rechaza como exceso antes de intentar parsear nada.

use std::io;

use async_trait::async_trait;
use futures::{AsyncRead, AsyncReadExt, AsyncWrite, AsyncWriteExt};
use libp2p::StreamProtocol;
use libp2p::request_response;

use crate::limites;
use crate::mensaje::{BloqueRed, Estado, Peticion, Respuesta};
use crate::presupuesto::Presupuesto;
use zx_core::digest::{BlockHash, Digest};
use zx_core::encoding::{compact_size, int};
use zx_core::error::EncodingError;
use zx_core::wire;

/// Máximo de hashes en un locator.
///
/// Un locator es logarítmico por construcción —denso cerca de la punta, espaciado hacia atrás—, así
/// que 64 entradas cubren una cadena de `2^40` bloques de sobra. Cualquier cosa mayor es un peer
/// que no está construyendo un locator, sino gastándonos tiempo.
pub const MAX_LOCATOR: usize = 64;

/// El códec de ZEROX para `request-response`.
///
/// Lleva el [`Presupuesto`] porque **es aquí donde se reserva la memoria**. Ponerlo más arriba
/// significaría contabilizar después de haber leído, que es contabilizar tarde.
#[derive(Clone, Default, Debug)]
pub struct ZxCodec {
    presupuesto: Presupuesto,
}

impl ZxCodec {
    /// Uno que comparte presupuesto con los demás.
    ///
    /// **Comparten el contador a propósito**: el recurso que se agota es global, así que repartirlo
    /// por conexión no acotaría la suma. Ver [`crate::presupuesto`].
    #[must_use]
    pub fn con_presupuesto(presupuesto: Presupuesto) -> Self {
        Self { presupuesto }
    }

    /// El presupuesto que usa.
    #[must_use]
    pub const fn presupuesto(&self) -> &Presupuesto {
        &self.presupuesto
    }
}

#[async_trait]
impl request_response::Codec for ZxCodec {
    type Protocol = StreamProtocol;
    type Request = Peticion;
    type Response = Respuesta;

    async fn read_request<T>(&mut self, _: &StreamProtocol, io: &mut T) -> io::Result<Peticion>
    where
        T: AsyncRead + Unpin + Send,
    {
        let bytes = leer_acotado(io, limites::MAX_PETICION_BYTES, &self.presupuesto).await?;
        peticion_desde_bytes(&bytes).map_err(a_io)
    }

    async fn read_response<T>(&mut self, _: &StreamProtocol, io: &mut T) -> io::Result<Respuesta>
    where
        T: AsyncRead + Unpin + Send,
    {
        let bytes = leer_acotado(io, limites::MAX_RESPUESTA_BYTES, &self.presupuesto).await?;
        respuesta_desde_bytes(&bytes).map_err(a_io)
    }

    async fn write_request<T>(
        &mut self,
        _: &StreamProtocol,
        io: &mut T,
        req: Peticion,
    ) -> io::Result<()>
    where
        T: AsyncWrite + Unpin + Send,
    {
        let bytes = peticion_a_bytes(&req);
        // Un emisor que se pasa de su propio límite es un bug nuestro, no de nadie más. Fallar aquí
        // es mejor que mandar algo que el otro extremo va a tirar.
        if bytes.len() as u64 > limites::MAX_PETICION_BYTES {
            return Err(io::Error::new(
                io::ErrorKind::InvalidInput,
                "la petición supera MAX_PETICION_BYTES",
            ));
        }
        io.write_all(&bytes).await?;
        io.close().await
    }

    async fn write_response<T>(
        &mut self,
        _: &StreamProtocol,
        io: &mut T,
        res: Respuesta,
    ) -> io::Result<()>
    where
        T: AsyncWrite + Unpin + Send,
    {
        let bytes = respuesta_a_bytes(&res);
        if bytes.len() as u64 > limites::MAX_RESPUESTA_BYTES {
            return Err(io::Error::new(
                io::ErrorKind::InvalidInput,
                "la respuesta supera MAX_RESPUESTA_BYTES",
            ));
        }
        io.write_all(&bytes).await?;
        io.close().await
    }
}

/// Lee hasta `max` bytes y **distingue truncamiento de tamaño legítimo**.
///
/// Se pide `max + 1`: si llegan `max + 1`, es que había más de lo permitido y se rechaza como
/// exceso. Con `take(max)` a secas, el mismo caso llegaría al parser como datos corruptos, y el
/// peer se clasificaría como `Ilegible` en vez de `Excedido` (C-NET-05).
async fn leer_acotado<T>(io: &mut T, max: u64, p: &Presupuesto) -> io::Result<Vec<u8>>
where
    T: AsyncRead + Unpin + Send,
{
    // C-NET-21 · **reservar ANTES de leer.** Reservar después de haber leído contabilizaría memoria
    // que ya está ocupada: el techo no acotaría nada, solo llevaría la cuenta del desastre.
    let cupo = usize::try_from(max.saturating_add(1)).unwrap_or(usize::MAX);
    let _reserva = p.reservar(cupo).ok_or_else(|| {
        io::Error::new(
            io::ErrorKind::OutOfMemory,
            "C-NET-21: no queda presupuesto de memoria en vuelo",
        )
    })?;

    let mut buf = Vec::new();
    io.take(max.saturating_add(1)).read_to_end(&mut buf).await?;

    if buf.len() as u64 > max {
        return Err(io::Error::new(
            io::ErrorKind::InvalidData,
            "C-NET-11: el mensaje supera el límite de tamaño",
        ));
    }
    Ok(buf)
    // `_reserva` se suelta aquí y devuelve el cupo — también por los `?` de arriba.
}

fn a_io(e: EncodingError) -> io::Error {
    io::Error::new(io::ErrorKind::InvalidData, e.to_string())
}

fn truncado(que: &'static str) -> EncodingError {
    let _ = que;
    EncodingError::Truncado {
        esperados: 1,
        disponibles: 0,
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Petición
// ─────────────────────────────────────────────────────────────────────────────

/// Serializa una petición.
#[must_use]
pub fn peticion_a_bytes(p: &Peticion) -> Vec<u8> {
    let mut b = Vec::new();
    int::escribir_u8(&mut b, p.discriminante());
    match p {
        Peticion::Estado => {}
        Peticion::Cabeceras { locator, hasta } => {
            compact_size::escribir(&mut b, locator.len() as u64);
            for h in locator {
                b.extend_from_slice(h.as_bytes());
            }
            match hasta {
                Some(h) => {
                    int::escribir_u8(&mut b, 1);
                    b.extend_from_slice(h.as_bytes());
                }
                None => int::escribir_u8(&mut b, 0),
            }
        }
        Peticion::Bloques { hashes } => {
            compact_size::escribir(&mut b, hashes.len() as u64);
            for h in hashes {
                b.extend_from_slice(h.as_bytes());
            }
        }
    }
    b
}

/// Deserializa una petición.
///
/// # Errores
/// El error de codificación que corresponda. **Nunca entra en pánico** (C-WIRE-05).
pub fn peticion_desde_bytes(bytes: &[u8]) -> Result<Peticion, EncodingError> {
    let (disc, r) = int::leer_u8(bytes)?;
    let (p, resto) = match disc {
        Peticion::DISC_ESTADO => (Peticion::Estado, r),
        Peticion::DISC_CABECERAS => {
            let (locator, r) = leer_hashes(r, MAX_LOCATOR)?;
            let (tiene, r) = int::leer_u8(r)?;
            let (hasta, r) = match tiene {
                0 => (None, r),
                1 => {
                    let (h, r) = int::leer_32(r)?;
                    (Some(BlockHash::from_digest(Digest::from_bytes(h))), r)
                }
                // C-ENC-09 · un booleano que no es 0 ni 1 es una segunda codificación del mismo
                // valor lógico, y solo se acepta una. Se rechaza en vez de interpretarse como
                // "cualquier cosa distinta de cero es verdadero": si dos nodos difieren en esa
                // interpretación, difieren en qué mensajes existen.
                _ => return Err(truncado("booleano no canónico en `hasta`")),
            };
            (Peticion::Cabeceras { locator, hasta }, r)
        }
        Peticion::DISC_BLOQUES => {
            let (hashes, r) = leer_hashes(r, limites::MAX_BLOQUES_POR_RESPUESTA)?;
            (Peticion::Bloques { hashes }, r)
        }
        otro => {
            return Err(EncodingError::LockDesconocido {
                discriminante: otro,
            });
        }
    };

    // Nada de relleno. Es el mismo razonamiento que C-TX-06c: sin esta comprobación, la basura
    // sobrante viaja gratis y el atacante consigue banda a coste cero.
    if resto.is_empty() {
        Ok(p)
    } else {
        Err(truncado("bytes sobrantes tras la petición"))
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Respuesta
// ─────────────────────────────────────────────────────────────────────────────

/// Serializa una respuesta.
#[must_use]
pub fn respuesta_a_bytes(r: &Respuesta) -> Vec<u8> {
    let mut b = Vec::new();
    int::escribir_u8(&mut b, r.discriminante());
    match r {
        Respuesta::Estado(e) => {
            b.extend_from_slice(e.genesis.as_bytes());
            b.extend_from_slice(e.tip.as_bytes());
            int::escribir_u32(&mut b, e.altura);
            b.extend_from_slice(&e.trabajo);
        }
        Respuesta::Cabeceras(cs) => {
            compact_size::escribir(&mut b, cs.len() as u64);
            for c in cs {
                b.extend_from_slice(&wire::cabecera_a_bytes(c));
            }
        }
        Respuesta::Bloques(bs) => {
            compact_size::escribir(&mut b, bs.len() as u64);
            for bl in bs {
                b.extend_from_slice(&wire::cabecera_a_bytes(&bl.cabecera));
                compact_size::escribir(&mut b, bl.txs.len() as u64);
                for (i, tx) in bl.txs.iter().enumerate() {
                    let vacio = Vec::new();
                    let t = bl.testigos.get(i).unwrap_or(&vacio);
                    wire::tx_a_bytes(&mut b, tx, t);
                }
            }
        }
        Respuesta::NoDisponible => {}
    }
    b
}

/// Deserializa una respuesta.
///
/// # Errores
/// El error de codificación que corresponda. **Nunca entra en pánico** (C-WIRE-05).
pub fn respuesta_desde_bytes(bytes: &[u8]) -> Result<Respuesta, EncodingError> {
    let (disc, r) = int::leer_u8(bytes)?;
    let (resp, resto) = match disc {
        Respuesta::DISC_ESTADO => {
            let (genesis, r) = int::leer_32(r)?;
            let (tip, r) = int::leer_32(r)?;
            let (altura, r) = int::leer_u32(r)?;
            let (trabajo, r) = int::leer_32(r)?;
            (
                Respuesta::Estado(Estado {
                    genesis: BlockHash::from_digest(Digest::from_bytes(genesis)),
                    tip: BlockHash::from_digest(Digest::from_bytes(tip)),
                    altura,
                    trabajo,
                }),
                r,
            )
        }
        Respuesta::DISC_CABECERAS => {
            let (n, mut r) = leer_contador(r, limites::MAX_CABECERAS_POR_RESPUESTA)?;
            let mut cs = Vec::with_capacity(n);
            for _ in 0..n {
                let (c, resto) = wire::cabecera_desde_bytes(r)?;
                cs.push(c);
                r = resto;
            }
            (Respuesta::Cabeceras(cs), r)
        }
        Respuesta::DISC_BLOQUES => {
            let (n, mut r) = leer_contador(r, limites::MAX_BLOQUES_POR_RESPUESTA)?;
            let mut bs = Vec::with_capacity(n);
            for _ in 0..n {
                let (cabecera, resto) = wire::cabecera_desde_bytes(r)?;
                let (n_tx, mut resto) = leer_contador(resto, usize::MAX)?;
                let mut txs = Vec::with_capacity(n_tx.min(4096));
                let mut testigos = Vec::with_capacity(n_tx.min(4096));
                for _ in 0..n_tx {
                    let ((tx, t), r2) = wire::tx_desde_bytes(resto)?;
                    txs.push(tx);
                    testigos.push(t);
                    resto = r2;
                }
                bs.push(BloqueRed {
                    cabecera,
                    txs,
                    testigos,
                });
                r = resto;
            }
            (Respuesta::Bloques(bs), r)
        }
        Respuesta::DISC_NO_DISPONIBLE => (Respuesta::NoDisponible, r),
        otro => {
            return Err(EncodingError::LockDesconocido {
                discriminante: otro,
            });
        }
    };

    if resto.is_empty() {
        Ok(resp)
    } else {
        Err(truncado("bytes sobrantes tras la respuesta"))
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Auxiliares
// ─────────────────────────────────────────────────────────────────────────────

/// Lee un contador y lo acota **antes** de reservar (C-WIRE-04).
fn leer_contador(bytes: &[u8], max: usize) -> Result<(usize, &[u8]), EncodingError> {
    let (n, r) = compact_size::leer(bytes)?;
    let tope = (max as u64).min(wire::MAX_ELEMENTOS_DECLARADOS);
    if n > tope {
        return Err(EncodingError::DemasiadosElementos {
            declarados: n,
            maximo: tope,
        });
    }
    let n = usize::try_from(n).map_err(|_| EncodingError::DemasiadosElementos {
        declarados: n,
        maximo: tope,
    })?;
    Ok((n, r))
}

fn leer_hashes(bytes: &[u8], max: usize) -> Result<(Vec<BlockHash>, &[u8]), EncodingError> {
    let (n, mut r) = leer_contador(bytes, max)?;
    let mut v = Vec::with_capacity(n);
    for _ in 0..n {
        let (h, resto) = int::leer_32(r)?;
        v.push(BlockHash::from_digest(Digest::from_bytes(h)));
        r = resto;
    }
    Ok((v, r))
}

#[cfg(test)]
#[expect(
    clippy::unwrap_used,
    clippy::expect_used,
    reason = "los tests fallan con panic por diseño"
)]
mod tests {
    use super::{
        MAX_LOCATOR, ZxCodec, peticion_a_bytes, peticion_desde_bytes, respuesta_a_bytes,
        respuesta_desde_bytes,
    };
    use crate::limites;
    use crate::mensaje::{BloqueRed, Estado, Peticion, Respuesta};
    use futures::AsyncWriteExt;
    use futures_ringbuf::Endpoint;
    use libp2p::StreamProtocol;
    use libp2p::request_response::Codec;
    use zx_core::amount::Amount;
    use zx_core::digest::{BlockHash, Digest, MerkleRoot, TxId};
    use zx_core::firma::ClavePublica;
    use zx_core::preimage::block::BlockHeader;
    use zx_core::tx::{Lock, OutPoint, Tx, TxIn, TxOut};

    fn h(n: u8) -> BlockHash {
        BlockHash::from_digest(Digest::from_bytes([n; 32]))
    }

    fn proto() -> StreamProtocol {
        StreamProtocol::new("/zerox/sync/1")
    }

    fn cabecera(n: u8) -> BlockHeader {
        BlockHeader {
            consensus_branch_id: 0xc478_80ea,
            prev_hash: h(n),
            merkle_root: MerkleRoot::from_digest(Digest::from_bytes([n ^ 0xff; 32])),
            timestamp: 1_788_480_000 + u64::from(n),
            bits: 0x1c07_fff8,
            nonce: u64::from(n),
            height: u32::from(n),
        }
    }

    fn bloque(n: u8) -> BloqueRed {
        let tx = Tx {
            version: 1,
            inputs: vec![TxIn {
                outpoint: OutPoint {
                    prev_txid: TxId::from_digest(Digest::from_bytes([n; 32])),
                    prev_index: 0,
                },
                sequence: 0,
            }],
            outputs: vec![TxOut {
                value: Amount::nuevo(1_000).unwrap(),
                lock: Lock::PubKey {
                    pubkey: ClavePublica::desde_bytes([n; 32]),
                },
            }],
            lock_time: 0,
            expiry_height: 0,
        };
        BloqueRed {
            cabecera: cabecera(n),
            txs: vec![tx],
            testigos: vec![vec![vec![0x11; 64]]],
        }
    }

    fn todas_las_peticiones() -> Vec<Peticion> {
        vec![
            Peticion::Estado,
            Peticion::Cabeceras {
                locator: vec![],
                hasta: None,
            },
            Peticion::Cabeceras {
                locator: vec![h(1), h(2), h(3)],
                hasta: Some(h(9)),
            },
            Peticion::Bloques {
                hashes: vec![h(4), h(5)],
            },
        ]
    }

    fn todas_las_respuestas() -> Vec<Respuesta> {
        vec![
            Respuesta::Estado(Estado {
                genesis: h(0),
                tip: h(1),
                altura: 12_345,
                trabajo: [0xab; 32],
            }),
            Respuesta::Cabeceras(vec![]),
            Respuesta::Cabeceras((0..5).map(cabecera).collect()),
            Respuesta::Bloques(vec![]),
            Respuesta::Bloques((0..3).map(bloque).collect()),
            Respuesta::NoDisponible,
        ]
    }

    // ── Ida y vuelta, sin Swarm ──────────────────────────────────────────────

    #[test]
    fn todas_las_peticiones_dan_la_vuelta() {
        for p in todas_las_peticiones() {
            let b = peticion_a_bytes(&p);
            assert_eq!(peticion_desde_bytes(&b).unwrap(), p, "{p:?}");
        }
    }

    #[test]
    fn todas_las_respuestas_dan_la_vuelta() {
        for r in todas_las_respuestas() {
            let b = respuesta_a_bytes(&r);
            assert_eq!(respuesta_desde_bytes(&b).unwrap(), r, "{r:?}");
        }
    }

    /// **La ida y vuelta por un stream real**, con el patrón de `request-response/src/cbor.rs`:
    /// un par de extremos en memoria, sin `Swarm`, sin transporte, sin negociación de protocolo.
    #[tokio::test]
    async fn el_codec_da_la_vuelta_por_un_stream() {
        for p in todas_las_peticiones() {
            let (mut a, mut b) = Endpoint::pair(4096, 4096);
            let mut codec = ZxCodec::default();

            codec
                .write_request(&proto(), &mut a, p.clone())
                .await
                .expect("escribe");
            a.close().await.unwrap();

            let leida = codec.read_request(&proto(), &mut b).await.expect("lee");
            assert_eq!(leida, p);
        }

        for r in todas_las_respuestas() {
            let (mut a, mut b) = Endpoint::pair(65_536, 65_536);
            let mut codec = ZxCodec::default();

            codec
                .write_response(&proto(), &mut a, r.clone())
                .await
                .expect("escribe");
            a.close().await.unwrap();

            let leida = codec.read_response(&proto(), &mut b).await.expect("lee");
            assert_eq!(leida, r);
        }
    }

    // ── Límites de tamaño ────────────────────────────────────────────────────

    /// **El matiz que casi se cuela: `.take(N)` trunca en silencio.**
    ///
    /// Se manda una petición **más grande que el límite**. Con `take(max)` a secas, el lector
    /// habría leído `max` bytes, el parseo habría fallado con "datos corruptos", y el peer se
    /// habría clasificado como `Ilegible` —"habla otro dialecto"— en vez de `Excedido` —"mandó algo
    /// que no debía"—. Son motivos distintos con políticas distintas (C-NET-05).
    ///
    /// Aquí se lee `max + 1` y se comprueba el tope, así que el error dice lo que es.
    #[tokio::test]
    async fn una_peticion_demasiado_grande_se_rechaza_por_tamano_y_no_por_parseo() {
        let exceso = (limites::MAX_PETICION_BYTES + 1_000) as usize;
        let (mut a, mut b) = Endpoint::pair(exceso + 4096, exceso + 4096);

        // Bytes crudos, sin pasar por el escritor: simula a un peer que ignora el límite.
        let basura = vec![Peticion::DISC_ESTADO; exceso];
        a.write_all(&basura).await.unwrap();
        a.close().await.unwrap();

        let e = ZxCodec::default()
            .read_request(&proto(), &mut b)
            .await
            .expect_err("MUST rechazarse");
        assert_eq!(e.kind(), std::io::ErrorKind::InvalidData);
        assert!(
            e.to_string().contains("C-NET-11"),
            "el error debe decir que es por tamaño, no por parseo: {e}"
        );
    }

    /// **C-NET-21 · sin presupuesto, no se lee.**
    ///
    /// Es la defensa que el `.take(MAX)` por petición no da: aquel acota **una** lectura, este
    /// acota la **suma**. Sin él, `25,6 MB × 8 streams × 72 peers` son 14,7 GB reservables por
    /// peticiones que un atacante emite gratis.
    #[tokio::test]
    async fn sin_presupuesto_la_lectura_se_rechaza() {
        use crate::presupuesto::Presupuesto;

        // Un presupuesto ridículo: no cabe ni una petición.
        let p = Presupuesto::nuevo(10);
        let mut codec = ZxCodec::con_presupuesto(p.clone());

        let (mut a, mut b) = Endpoint::pair(4096, 4096);
        let bytes = peticion_a_bytes(&Peticion::Estado);
        futures::AsyncWriteExt::write_all(&mut a, &bytes)
            .await
            .unwrap();
        a.close().await.unwrap();

        let e = codec
            .read_request(&proto(), &mut b)
            .await
            .expect_err("MUST rechazarse por presupuesto");
        assert_eq!(e.kind(), std::io::ErrorKind::OutOfMemory);
        assert!(e.to_string().contains("C-NET-21"), "{e}");

        // Y la reserva se devolvió: el rechazo no deja el contador tocado.
        assert_eq!(p.en_vuelo(), 0);
    }

    /// **La reserva se devuelve tras una lectura correcta.**
    ///
    /// Sin esto, el presupuesto se agotaría solo con tráfico legítimo — un DoS diferido que se
    /// dispara sin que esté pasando nada.
    #[tokio::test]
    async fn una_lectura_correcta_devuelve_su_reserva() {
        use crate::presupuesto::Presupuesto;

        let p = Presupuesto::nuevo(crate::presupuesto::PRESUPUESTO_BYTES);
        let mut codec = ZxCodec::con_presupuesto(p.clone());

        for _ in 0..50 {
            let (mut a, mut b) = Endpoint::pair(4096, 4096);
            codec
                .write_request(&proto(), &mut a, Peticion::Estado)
                .await
                .unwrap();
            a.close().await.unwrap();
            codec.read_request(&proto(), &mut b).await.unwrap();
            assert_eq!(p.en_vuelo(), 0, "cada lectura devuelve lo suyo");
        }
    }

    /// **El contador mentiroso, el ataque más barato.**
    ///
    /// El emisor declara millones de hashes en el locator y manda cuatro bytes. Sin la cota, el
    /// lector reserva por lo declarado antes de descubrir que no hay cuerpo. Es el patrón que
    /// lighthouse prueba mintiendo en el prefijo en vez de construir el payload real — así el test
    /// es instantáneo y no estresa el CI.
    #[test]
    fn un_locator_mentiroso_se_rechaza_sin_reservar() {
        use zx_core::encoding::compact_size;
        for declarados in [MAX_LOCATOR as u64 + 1, u32::MAX as u64, u64::MAX] {
            let mut b = vec![Peticion::DISC_CABECERAS];
            compact_size::escribir(&mut b, declarados);
            // …y nada más.
            let e = peticion_desde_bytes(&b).expect_err("MUST rechazarse");
            assert!(
                matches!(e, zx_core::error::EncodingError::DemasiadosElementos { .. }),
                "declarar {declarados} hashes debe fallar por la cota, no por falta de bytes: {e}"
            );
        }
    }

    /// Lo mismo en la respuesta: cabeceras y bloques declarados de más.
    #[test]
    fn una_respuesta_con_contador_mentiroso_se_rechaza() {
        use zx_core::encoding::compact_size;
        for disc in [Respuesta::DISC_CABECERAS, Respuesta::DISC_BLOQUES] {
            let mut b = vec![disc];
            compact_size::escribir(&mut b, u64::MAX);
            assert!(
                matches!(
                    respuesta_desde_bytes(&b),
                    Err(zx_core::error::EncodingError::DemasiadosElementos { .. })
                ),
                "disc {disc:#04x}"
            );
        }
    }

    /// Un lote lleno de cabeceras **sí** cabe: la cota no debe rechazar lo legítimo.
    #[test]
    fn un_lote_lleno_de_cabeceras_pasa_la_cota() {
        let cs: Vec<_> = (0..limites::MAX_CABECERAS_POR_RESPUESTA)
            .map(|i| cabecera((i % 256) as u8))
            .collect();
        let r = Respuesta::Cabeceras(cs);
        let b = respuesta_a_bytes(&r);

        assert!(
            b.len() as u64 <= limites::MAX_RESPUESTA_BYTES,
            "{} B no caben en {} B",
            b.len(),
            limites::MAX_RESPUESTA_BYTES
        );
        assert_eq!(respuesta_desde_bytes(&b).unwrap(), r);
    }

    // ── Robustez ─────────────────────────────────────────────────────────────

    /// **C-WIRE-05.** Ningún byte arbitrario hace entrar en pánico a los lectores.
    #[test]
    fn ningun_byte_arbitrario_hace_entrar_en_panico() {
        // Determinista: un generador congruencial simple, para que un fallo sea reproducible.
        let mut x: u64 = 0x2545_F491_4F6C_DD1D;
        for _ in 0..2_000 {
            let mut buf = Vec::new();
            for _ in 0..(x % 300) {
                x = x.wrapping_mul(6_364_136_223_846_793_005).wrapping_add(1);
                buf.push((x >> 33) as u8);
            }
            let _ = peticion_desde_bytes(&buf);
            let _ = respuesta_desde_bytes(&buf);
            x = x.wrapping_mul(6_364_136_223_846_793_005).wrapping_add(1);
        }
    }

    /// Truncar en cualquier punto se rechaza, nunca se acepta a medias.
    #[test]
    fn un_mensaje_truncado_nunca_se_acepta_a_medias() {
        for p in todas_las_peticiones() {
            let b = peticion_a_bytes(&p);
            for n in 0..b.len() {
                assert!(
                    peticion_desde_bytes(b.get(..n).unwrap()).is_err(),
                    "{p:?} truncada a {n} bytes NO debe aceptarse"
                );
            }
        }
    }

    /// **Nada de relleno.** Un byte de más invalida, por el mismo razonamiento que C-TX-06c: sin
    /// esta comprobación la basura sobrante viaja gratis.
    #[test]
    fn el_relleno_sobrante_se_rechaza() {
        for p in todas_las_peticiones() {
            let mut b = peticion_a_bytes(&p);
            b.push(0x00);
            assert!(peticion_desde_bytes(&b).is_err(), "{p:?} + 1 byte");
        }
        for r in todas_las_respuestas() {
            let mut b = respuesta_a_bytes(&r);
            b.push(0x00);
            assert!(respuesta_desde_bytes(&b).is_err(), "{r:?} + 1 byte");
        }
    }

    /// Un discriminante desconocido se rechaza, nunca se interpreta como otra cosa.
    #[test]
    fn un_discriminante_desconocido_se_rechaza() {
        for disc in [0x04u8, 0x7f, 0x80, 0xff] {
            assert!(
                peticion_desde_bytes(&[disc]).is_err(),
                "petición {disc:#04x}"
            );
            assert!(
                respuesta_desde_bytes(&[disc]).is_err(),
                "respuesta {disc:#04x}"
            );
        }
    }

    /// El booleano de `hasta` **MUST** ser 0 o 1: nada de "cualquier cosa distinta de cero".
    ///
    /// Sin esto habría dos codificaciones del mismo mensaje, y dos codificaciones del mismo mensaje
    /// son maleabilidad — el mismo razonamiento que C-ENC-05 para `CompactSize`.
    #[test]
    fn el_booleano_de_hasta_debe_ser_canonico() {
        use zx_core::encoding::compact_size;
        for valor in [2u8, 3, 0x7f, 0xff] {
            let mut b = vec![Peticion::DISC_CABECERAS];
            compact_size::escribir(&mut b, 0); // locator vacío
            b.push(valor);
            b.extend_from_slice(&[0u8; 32]);
            assert!(
                peticion_desde_bytes(&b).is_err(),
                "un booleano de {valor:#04x} MUST rechazarse"
            );
        }
    }
}
