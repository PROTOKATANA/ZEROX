//! Estrategias del adversario de S02a y producción de aperturas de R2.
//!
//! Modelo (ORDEN-S02a §3.2):
//!
//! - **E-disco**: conserva el sector completo; abre leyendo el chunk almacenado y recomponiendo el
//!   camino desde el árbol Merkle (caché del honesto).
//! - **E-árbol(L)**: conserva solo los `2^(profundidad−L)` nodos del nivel `L`; para abrir
//!   regenera las `2^L` hojas del bloque alineado de la posición y recompone el camino.
//! - **E-nada**: no conserva nada del sector; regenera todas las hojas y el árbol completo
//!   (equivale a `E-árbol(profundidad)`).
//!
//! La pieza de cada registro se obtiene de la historia **local** una sola vez por registro (fuera
//! del camino cronometrado): la orden la supone gratuita y local.

use std::num::NonZeroU64;

use subspace_core_primitives::pieces::{PieceOffset, Record, RecordCommitment, RecordWitness};
use subspace_core_primitives::pos::PosProof;
use subspace_core_primitives::segments::HistorySize;
use subspace_core_primitives::solutions::{ChunkWitness, Solution};
use subspace_core_primitives::ScalarBytes;
use subspace_kzg::Scalar;

use crate::merkle::{Merkle, nodo, vacio};
use crate::r2::{Apertura, hoja};
use crate::regeneracion::TablaRegistro;
use crate::sector::{Entorno, ErrorSector, NUM_S_BUCKETS, ParametrosPlot, Sector};

/// Posición física de una hoja: `(s_bucket, piece_offset, codificado)`.
pub type Posicion = (u16, u16, u8);

/// Estrategia del adversario que se mide.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Estrategia {
    /// Conserva el sector completo (línea base honesta).
    Disco,
    /// Conserva los nodos del nivel `L` del árbol (nivel 0 = hojas).
    Arbol(usize),
    /// No conserva nada del sector (raíz y metadatos públicos).
    Nada,
}

impl Estrategia {
    /// Etiqueta legible para los TSV.
    #[must_use]
    pub fn etiqueta(&self) -> String {
        match self {
            Estrategia::Disco => "E-disco".to_string(),
            Estrategia::Arbol(l) => format!("E-arbol(L={l})"),
            Estrategia::Nada => "E-nada".to_string(),
        }
    }

    /// Nivel `L` efectivo, o `None` para E-disco.
    #[must_use]
    pub fn nivel(&self, profundidad: usize) -> Option<usize> {
        match self {
            Estrategia::Disco => None,
            Estrategia::Arbol(l) => Some(*l),
            Estrategia::Nada => Some(profundidad),
        }
    }
}

/// Almacenamiento conservado por la estrategia, en bytes.
///
/// - E-disco: bytes del fichero de sector (`mapa + chunks + meta + checksum`).
/// - E-árbol(L): `2^(profundidad−L) · 32` bytes (nodos del nivel L).
/// - E-nada: 32 B (la raíz) más metadatos públicos.
#[must_use]
pub fn almacenamiento_bytes(
    estrategia: Estrategia,
    sector_bytes: usize,
    m: usize,
) -> u64 {
    match estrategia {
        Estrategia::Disco => sector_bytes as u64,
        Estrategia::Arbol(l) => ((m >> l) as u64) * 32,
        Estrategia::Nada => 32,
    }
}

/// Lista de posiciones físicas en el orden de las hojas de R2.
///
/// # Errores
///
/// Falla si el mapa de contenidos no decodifica.
pub fn posiciones_fisicas(sector: &Sector) -> Result<Vec<Posicion>, ErrorSector> {
    let mut posiciones = Vec::with_capacity(sector.campos.n as usize);
    for bucket in 0u32..NUM_S_BUCKETS {
        let s_bucket = subspace_core_primitives::sectors::SBucket::from(bucket as u16);
        for (piece_offset, codificado) in sector
            .mapa
            .iter_s_bucket_records(s_bucket)
            .map_err(|e| ErrorSector::Coherencia(format!("iter_s_bucket_records: {e}")))?
        {
            posiciones.push((
                bucket as u16,
                u16::from(piece_offset),
                u8::from(codificado),
            ));
        }
    }
    Ok(posiciones)
}

/// Cifras crudas de una apertura producida.
pub struct AperturaProducida {
    /// Apertura lista para verificar contra R2.
    pub apertura: Apertura,
    /// Chunk almacenado de la posición pedida.
    pub chunk_almacenado: [u8; 32],
    /// Prueba de espacio de la posición pedida (`None` para E-disco, que no la regenera aquí).
    pub proof: Option<PosProof>,
    /// Chunk fuente (sin enmascarar) de la posición pedida.
    pub chunk_fuente: Option<[u8; 32]>,
    /// Número de tablas PoS distintas regeneradas.
    pub tablas: usize,
    /// Número de hojas regeneradas.
    pub hojas: usize,
}

/// Recompone el camino Merkle de la hoja `i` a partir de las hojas regeneradas del bloque de
/// tamaño `2^l` y de los nodos conservados del nivel `l`.
///
/// Los `l` primeros hermanos salen del bloque regenerado; los `profundidad−l` restantes se
/// obtienen recomponiendo los niveles superiores desde el nivel `l` conservado (coste
/// `2^(profundidad−l)−1` hashes, que forma parte de la latencia de la estrategia).
#[must_use]
pub fn camino_arbol(
    arbol: &Merkle,
    i: usize,
    l: usize,
    hojas_bloque: &[[u8; 32]],
) -> Vec<[u8; 32]> {
    let profundidad = arbol.profundidad();
    let start = (i >> l) << l;
    let mut camino = Vec::with_capacity(profundidad);

    let mut nivel = hojas_bloque.to_vec();
    let mut idx = i - start;
    for _ in 0..l {
        camino.push(nivel[idx ^ 1]);
        nivel = nivel.chunks_exact(2).map(|p| nodo(&p[0], &p[1])).collect();
        idx /= 2;
    }

    let mut sup = arbol.nivel(l).to_vec();
    let mut idx_sup = i >> l;
    for _ in l..profundidad {
        camino.push(sup[idx_sup ^ 1]);
        sup = sup.chunks_exact(2).map(|p| nodo(&p[0], &p[1])).collect();
        idx_sup /= 2;
    }
    camino
}

/// Produce la apertura de la posición `i` con la estrategia dada.
///
/// Para E-disco lee el chunk almacenado del fichero de sector (no regenera tablas). Para
/// E-árbol(L)/E-nada regenera las hojas del bloque y, con ellas, el camino.
///
/// # Errores
///
/// Falla si la regeneración no produce el chunk esperado o si `i` cae fuera de rango.
pub fn producir_apertura(
    entorno: &Entorno,
    _p: &ParametrosPlot,
    sector: &Sector,
    posiciones: &[Posicion],
    records: &[Box<Record>],
    estrategia: Estrategia,
    i: usize,
) -> Result<AperturaProducida, ErrorSector> {
    let n = sector.campos.n as usize;
    if i >= n {
        return Err(ErrorSector::Coherencia(format!(
            "posición {i} fuera del sector (n = {n})"
        )));
    }
    let (s_bucket, piece_offset, codificado) = posiciones[i];

    if let Estrategia::Disco = estrategia {
        let (mapa_sz, _, _) = sector.tamanos_regiones();
        let ini = mapa_sz + i * 32;
        let chunk: [u8; 32] = sector.bytes[ini..ini + 32]
            .try_into()
            .map_err(|_| ErrorSector::Coherencia("chunk almacenado fuera de rango".into()))?;
        let camino = sector.arbol.camino(i);
        return Ok(AperturaProducida {
            apertura: Apertura {
                chunk_location: i as u32,
                camino,
                codificado,
                raiz_chunks: sector.arbol.raiz(),
                digest_mapa: sector.digest_mapa,
                digest_meta: sector.digest_meta,
                s_bucket,
                piece_offset,
            },
            chunk_almacenado: chunk,
            proof: None,
            chunk_fuente: None,
            tablas: 0,
            hojas: 0,
        });
    }

    let profundidad = sector.arbol.profundidad();
    let l = estrategia
        .nivel(profundidad)
        .ok_or_else(|| ErrorSector::Coherencia("E-árbol sin nivel".into()))?;
    if l > profundidad {
        return Err(ErrorSector::Coherencia(format!(
            "nivel L = {l} > profundidad {profundidad}"
        )));
    }
    let start = (i >> l) << l;
    let bloque = 1usize << l;

    let mut hojas_bloque = vec![vacio(); bloque];
    let real_end = (start + bloque).min(n);

    let mut offsets: Vec<u16> = Vec::new();
    for j in start..real_end {
        let po = posiciones[j].1;
        if !offsets.contains(&po) {
            offsets.push(po);
        }
    }

    let mut tablas = 0usize;
    let mut proof = None;
    let mut chunk_fuente = None;
    let mut chunk_almacenado = [0u8; 32];

    for po in offsets {
        let record = records
            .get(usize::from(po))
            .ok_or_else(|| ErrorSector::Coherencia(format!("sin registro para offset {po}")))?;
        let tabla = TablaRegistro::desde_pieza(entorno, record, &sector.sector_id, po)?;
        tablas += 1;
        for (j, hojas_slot) in hojas_bloque
            .iter_mut()
            .enumerate()
            .take(real_end.saturating_sub(start))
        {
            let j = start + j;
            let (sb, po_j, cod_j) = posiciones[j];
            if po_j != po {
                continue;
            }
            let ch = tabla.chunk_para_hoja(sb, cod_j)?;
            *hojas_slot = hoja(sb, po_j, cod_j, &ch);
            if j == i {
                proof = tabla.proof(sb);
                chunk_fuente = Some(tabla.chunk_fuente(sb));
                chunk_almacenado = ch;
            }
        }
    }

    let camino = camino_arbol(&sector.arbol, i, l, &hojas_bloque);
    Ok(AperturaProducida {
        apertura: Apertura {
            chunk_location: i as u32,
            camino,
            codificado,
            raiz_chunks: sector.arbol.raiz(),
            digest_mapa: sector.digest_mapa,
            digest_meta: sector.digest_meta,
            s_bucket,
            piece_offset,
        },
        chunk_almacenado,
        proof,
        chunk_fuente,
        tablas,
        hojas: real_end - start,
    })
}

/// Construye una `Solution<()>` con la prueba real de la tabla del registro y el chunk fuente, para
/// poder verificar la apertura con el verificador de S01. El resto de testigos (KZG) no intervienen
/// en `verificar_apertura`.
///
/// # Errores
///
/// Falla si el chunk fuente no es un escalar válido o si `history_size` es cero.
pub fn construir_solucion(
    sector: &Sector,
    posiciones: &[Posicion],
    i: usize,
    chunk_fuente: &[u8; 32],
    proof: PosProof,
) -> Result<Solution<()>, ErrorSector> {
    let (_, piece_offset, _) = posiciones[i];
    let escalar = Scalar::try_from(chunk_fuente)
        .map_err(|_| ErrorSector::Regeneracion("chunk fuente no es escalar".into()))?;
    let chunk = ScalarBytes::from(escalar);
    let history_size = HistorySize::new(
        NonZeroU64::new(sector.campos.history_size)
            .ok_or_else(|| ErrorSector::Coherencia("history_size cero".into()))?,
    );
    Ok(Solution {
        public_key: sector.public_key,
        reward_address: (),
        sector_index: sector.campos.sector_index,
        history_size,
        piece_offset: PieceOffset::from(piece_offset),
        record_commitment: RecordCommitment::default(),
        record_witness: RecordWitness::default(),
        chunk,
        chunk_witness: ChunkWitness::default(),
        proof_of_space: proof,
    })
}
