//! Contexto SINTÉTICO: raíz KZG construida aquí, no historia ZEROX/Archiver acreditada.
//! Usa pruebas PoS y verificador PoAS reales; no certifica PoT, firma o cabecera.

#![feature(generic_const_exprs)]
#![allow(incomplete_features)]

use ab_proof_of_space::chiapos::{Tables, TablesCache};
use std::num::NonZeroU64;
use subspace_core_primitives::hashes::blake3_254_hash_to_scalar;
use subspace_core_primitives::pieces::{PieceOffset, Record};
use subspace_core_primitives::pos::PosProof;
use subspace_core_primitives::pot::PotOutput;
use subspace_core_primitives::sectors::SectorId;
use subspace_core_primitives::segments::{ArchivedHistorySegment, HistorySize};
use subspace_core_primitives::solutions::{ChunkWitness, Solution};
use subspace_core_primitives::{PublicKey, ScalarBytes};
use subspace_kzg::{Kzg, Scalar};
use subspace_proof_of_space::chia::ChiaTable;
use subspace_verification::{Error, PieceCheckParams, VerifySolutionParams, verify_solution};

fn history(size: u64) -> HistorySize {
    HistorySize::from(NonZeroU64::new(size).expect("constante positiva de fixture"))
}

fn bucket(sector: &SectorId, pot: PotOutput, slot: u64) -> u32 {
    let global = pot.derive_global_randomness().derive_global_challenge(slot);
    u16::from(
        sector
            .derive_sector_slot_challenge(&global)
            .s_bucket_audit_index(),
    )
    .into()
}

fn prefix(s_bucket: u32) -> u32 {
    // Misma costura endian que ChiaTable::is_proof_valid, K=20 del commit fijado.
    u32::from_be_bytes(s_bucket.to_le_bytes()) >> (32 - u32::from(PosProof::K))
}

#[test]
fn verificador_real_con_contexto_sintetico_y_mutaciones_dirigidas() -> Result<(), String> {
    // Clave Ed25519 ordinaria de semilla pública [0x42;32], fijada y comprobada en
    // crates/zx-core/tests/ed25519_no_unicidad.rs. Este test NO verifica sellos.
    let public_key = PublicKey::from([
        0x21, 0x52, 0xf8, 0xd1, 0x9b, 0x79, 0x1d, 0x24, 0x45, 0x32, 0x42, 0xe1, 0x5f, 0x2e, 0xab,
        0x6c, 0xb7, 0xcf, 0xfa, 0x7b, 0x6a, 0x5e, 0xd3, 0x00, 0x97, 0x96, 0x0e, 0x06, 0x98, 0x81,
        0xdb, 0x12,
    ]);
    let history_size = history(3);
    let sector_index = 7;
    let sector = SectorId::new(public_key.hash(), sector_index, history_size);
    let pot = PotOutput::from([0x35; 16]);
    let kzg = Kzg::new();

    // Record repetido: no se presupone que chunks de piezas diferentes sean distintos.
    let value = Scalar::from([0x17; ScalarBytes::SAFE_BYTES]);
    // El record tiene NUM_CHUNKS coeficientes/evaluaciones fuente; su extensión
    // se verifica en NUM_S_BUCKETS. Una constante conserva el mismo valor allí.
    let record_polynomial = kzg.poly(&vec![value; Record::NUM_CHUNKS])?;
    let record_commitment = kzg.commit(&record_polynomial)?;
    let commitment_bytes: [u8; 48] = (&record_commitment).into();
    let record_hash = Scalar::try_from(blake3_254_hash_to_scalar(&commitment_bytes))?;
    let segment_polynomial = kzg.poly(&vec![record_hash; ArchivedHistorySegment::NUM_PIECES])?;
    let segment_commitment = kzg.commit(&segment_polynomial)?;
    let params = VerifySolutionParams {
        proof_of_time: pot,
        // Sólo perfil permisivo de fixture; NO rango ni probabilidad de producción.
        solution_range: u64::MAX,
        piece_check_params: Some(PieceCheckParams {
            max_pieces_in_sector: 2,
            segment_commitment: segment_commitment.into(),
            recent_segments: history(5),
            recent_history_fraction: (history(1), history(10)),
            min_sector_lifetime: history(4),
            current_history_size: history_size,
            sector_expiration_check_segment_commitment: None,
        }),
    };
    let cache = TablesCache::default();
    let table0 = Tables::<20>::create(
        sector.derive_evaluation_seed(PieceOffset::from(0)).into(),
        &cache,
    );
    let table1 = Tables::<20>::create(
        sector.derive_evaluation_seed(PieceOffset::from(1)).into(),
        &cache,
    );

    // Búsqueda determinista acotada. Exigimos dos PoS distintas para offset0 y una
    // para offset1 bajo MISMO slot/bucket; no aceptar silencio si no se encuentran.
    let mut selected = None;
    for slot in 1..=4096 {
        let audit_bucket = bucket(&sector, pot, slot);
        let proofs0: Vec<_> = table0
            .find_proof_raw(prefix(audit_bucket))
            .take(2)
            .collect();
        if let ([first, second], Some(other)) = (
            proofs0.as_slice(),
            table1.find_proof_raw(prefix(audit_bucket)).next(),
        ) && first != second
        {
            selected = Some((slot, audit_bucket, *first, *second, other));
            break;
        }
    }
    let (slot, audit_bucket, proof0a, proof0b, proof1) =
        selected.ok_or("sin fixture en los 4096 slots; inconcluso")?;
    assert_eq!(
        (slot, audit_bucket),
        (4, 22412),
        "fixture fijada; no regenerar silenciosamente"
    );
    let piece_params = params
        .piece_check_params
        .as_ref()
        .ok_or("falta contexto de pieza")?;
    let make_solution = |offset: u16, proof: [u8; 160]| -> Result<Solution<()>, String> {
        let piece_offset = PieceOffset::from(offset);
        let position = sector
            .derive_piece_index(
                piece_offset,
                history_size,
                piece_params.max_pieces_in_sector,
                piece_params.recent_segments,
                piece_params.recent_history_fraction,
            )
            .position();
        Ok(Solution {
            public_key,
            reward_address: (),
            sector_index,
            history_size,
            piece_offset,
            record_commitment: record_commitment.into(),
            record_witness: kzg
                .create_witness(
                    &segment_polynomial,
                    ArchivedHistorySegment::NUM_PIECES,
                    position,
                )?
                .into(),
            chunk: value.into(),
            chunk_witness: kzg
                .create_witness(&record_polynomial, Record::NUM_S_BUCKETS, audit_bucket)?
                .into(),
            proof_of_space: PosProof::from(proof),
        })
    };
    let first = make_solution(0, proof0a)?;
    let alternate = make_solution(0, proof0b)?;
    let other_piece = make_solution(1, proof1)?;
    let check = |solution: &Solution<()>, context: &VerifySolutionParams, s: u64| {
        verify_solution::<ChiaTable, _>(solution, s, context, &kzg)
    };
    let distance = check(&first, &params, slot).map_err(|error| error.to_string())?;
    let alternate_distance = check(&alternate, &params, slot).map_err(|error| error.to_string())?;
    let other_distance = check(&other_piece, &params, slot).map_err(|error| error.to_string())?;
    assert_ne!(first.proof_of_space, alternate.proof_of_space);
    let mut only_proof_changed = first.clone();
    only_proof_changed.proof_of_space = alternate.proof_of_space;
    assert_eq!(only_proof_changed, alternate, "sólo cambia proof_of_space");
    assert_eq!(
        (distance, alternate_distance, other_distance),
        (
            4352823087875908110,
            8322768934019865430,
            3650123740992092631
        ),
        "distancias de la fixture fijada"
    );
    assert_eq!(first.chunk, other_piece.chunk);
    assert_ne!(first.piece_offset, other_piece.piece_offset);

    // Igualdad exacta de la clave de investigación ZEROX; no identidad ya activada.
    let current_key = |solution: &Solution<()>| {
        (
            solution.public_key,
            solution.sector_index,
            solution.history_size,
            solution.chunk,
            slot,
        )
    };
    assert_eq!(current_key(&first), current_key(&other_piece));
    assert_eq!(current_key(&first), current_key(&alternate));
    assert_ne!(
        (current_key(&first), first.piece_offset),
        (current_key(&other_piece), other_piece.piece_offset)
    );
    assert_eq!(
        (current_key(&first), first.piece_offset),
        (current_key(&alternate), alternate.piece_offset)
    );

    // Misma solución salvo PoS: ambas son válidas bajo MAX, pero un mismo rango
    // puede aceptar una y rechazar la otra. No mide beneficio antes de un deadline.
    let mut discriminating = params.clone();
    discriminating.solution_range = distance
        .min(alternate_distance)
        .checked_mul(2)
        .ok_or("overflow en rango discriminante")?;
    assert!(distance < alternate_distance);
    assert_eq!(check(&first, &discriminating, slot), Ok(distance));
    assert!(matches!(
        check(&alternate, &discriminating, slot),
        Err(Error::OutsideSolutionRange { .. })
    ));

    let mut changed = first.clone();
    changed.proof_of_space = PosProof::default();
    assert_eq!(
        check(&changed, &params, slot),
        Err(Error::InvalidProofOfSpace)
    );
    changed = first.clone();
    changed.chunk = Scalar::from([0x18; ScalarBytes::SAFE_BYTES]).into();
    assert_eq!(
        check(&changed, &params, slot),
        Err(Error::InvalidChunkWitness)
    );
    changed = first.clone();
    changed.chunk_witness = ChunkWitness::default();
    assert_eq!(
        check(&changed, &params, slot),
        Err(Error::InvalidChunkWitness)
    );
    changed = first.clone();
    changed.record_witness = Default::default();
    assert_eq!(check(&changed, &params, slot), Err(Error::InvalidPiece));
    changed = first.clone();
    changed.piece_offset = PieceOffset::from(1);
    assert_eq!(
        check(&changed, &params, slot),
        Err(Error::InvalidProofOfSpace)
    );

    let mut context = params.clone();
    assert!(
        distance > 0,
        "fixture de borde de rango necesita distancia positiva"
    );
    context.solution_range = distance
        .checked_mul(2)
        .ok_or("overflow construyendo borde")?
        - 1;
    assert!(matches!(
        check(&first, &context, slot),
        Err(Error::OutsideSolutionRange { .. })
    ));
    context.solution_range += 1;
    assert_eq!(check(&first, &context, slot), Ok(distance));
    context = params.clone();
    context.proof_of_time = PotOutput::from([0x36; 16]);
    assert_ne!(bucket(&sector, context.proof_of_time, slot), audit_bucket);
    assert_eq!(
        check(&first, &context, slot),
        Err(Error::InvalidProofOfSpace)
    );
    let other_slot = (slot + 1..slot + 4097)
        .find(|&s| bucket(&sector, pot, s) != audit_bucket)
        .ok_or("sin slot de control")?;
    assert_eq!(
        check(&first, &params, other_slot),
        Err(Error::InvalidProofOfSpace)
    );

    context = params.clone();
    context
        .piece_check_params
        .as_mut()
        .ok_or("falta contexto")?
        .max_pieces_in_sector = 1;
    assert!(matches!(
        check(&other_piece, &context, slot),
        Err(Error::InvalidPieceOffset { .. })
    ));
    context = params.clone();
    context
        .piece_check_params
        .as_mut()
        .ok_or("falta contexto")?
        .current_history_size = history(1);
    assert!(matches!(
        check(&first, &context, slot),
        Err(Error::FutureHistorySize { .. })
    ));
    context = params.clone();
    context
        .piece_check_params
        .as_mut()
        .ok_or("falta contexto")?
        .segment_commitment = record_commitment.into();
    assert_eq!(check(&first, &context, slot), Err(Error::InvalidPiece));
    context = params.clone();
    let piece = context
        .piece_check_params
        .as_mut()
        .ok_or("falta contexto")?;
    piece.current_history_size = history(1000);
    piece.sector_expiration_check_segment_commitment = Some(piece.segment_commitment);
    assert!(matches!(
        check(&first, &context, slot),
        Err(Error::SectorExpired { .. })
    ));

    eprintln!(
        "VALIDADO: slot={slot}, bucket={audit_bucket}, offsets=0/1, distancias={distance}/{alternate_distance}/{other_distance}; Some(PieceCheckParams), contexto sintético, sin PoT/cabecera validados"
    );
    eprintln!(
        "PoS offset0 primera={:?}\nPoS offset0 segunda={:?}\nPoS offset1={:?}",
        first.proof_of_space, alternate.proof_of_space, other_piece.proof_of_space
    );
    eprintln!(
        "RANGO_DISCRIMINANTE={}; primera=Ok; segunda=OutsideSolutionRange; sólo cambia PoS",
        discriminating.solution_range
    );
    if std::env::var_os("POAS_GUARDAR_FIXTURE").is_some() {
        // Artefacto de reproducción del harness; Debug NO es serialización de consenso.
        let fixture = format!(
            "AUTONOMYS_COMMIT=f8842d019cdf0f7163421b9644db5a9ff82b2a73\nCONTEXTO=SINTETICO_NO_HISTORIA_ZEROX_NI_ARCHIVER_ACREDITADA\nK=20\nSEED_ED25519=42_repetido_32_bytes\nRECORD_SCALAR=17_repetido_31_bytes\nSLOT={slot}\nBUCKET={audit_bucket}\nPARAMETROS={params:#?}\nSOLUCION_PRIMERA={first:#?}\nSOLUCION_ALTERNATIVA={alternate:#?}\nSOLUCION_OTRA_PIEZA={other_piece:#?}\nDISTANCIAS={distance}/{alternate_distance}/{other_distance}\nRANGO_DISCRIMINANTE={}\n",
            discriminating.solution_range,
        );
        let output =
            std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("resultados/fixture.txt");
        std::fs::write(&output, fixture).map_err(|error| error.to_string())?;
        eprintln!("FIXTURE_COMPLETA={}", output.display());
    }
    Ok(())
}
