//! **Que el `bits` que llega sea el que el retarget exige** (C-BLK-05, C-DIFF-09).
//!
//! # El hueco que esto cierra
//!
//! `zx-consensus` implementa LWMA-1 entero y probado (`siguiente_target`), y `validar_cabecera`
//! comprueba C-BLK-05 contra el target esperado. Pero **el nodo no llamaba a ninguno de los dos**:
//! el camino de sincronización pasaba por `sync::validar_cadena_de_cabeceras`, cuyo docstring dice
//! explícitamente que no comprueba la dificultad esperada.
//!
//! El resultado era que un peer podía servir cabeceras con **cualquier `bits` canónico** —uno más
//! barato del que LWMA exige a esa altura— y el nodo las adoptaba. La defensa que quedaba era el
//! umbral de trabajo de C-NET-04, que solo atrapa los casos groseros: `bits` un poco más fácil de
//! lo que toca produce una cadena que **este nodo acepta y el resto de la red rechaza**, que es
//! una divergencia de consenso en el peor sitio posible.
//!
//! No hay regla nueva aquí. C-BLK-05 y C-DIFF-09 ya estaban en el SPEC; lo que faltaba era el
//! cable.
//!
//! # Por qué la ventana se arma sobre la rama CANDIDATA, no sobre la nuestra
//!
//! El retarget de la cabecera `H` mira los `N+1` ancestros `H−N−1 .. H−1` (C-DIFF-01). Cuando lo
//! que llega es una bifurcación, parte de esos ancestros son del peer y parte nuestros:
//!
//! ```text
//!   nuestra cadena   ─────●────────●────────●   (punta)
//!                         │ ancla
//!   lo que propone        └────○────○────○───○  (candidata)
//! ```
//!
//! Todo lo que está **en el ancla o por debajo** es compartido —por definición de ancla— así que
//! se lee de nuestra cadena. Todo lo que está por encima viene del lote.
//!
//! Coger la ventana de nuestra punta sería el mismo error que ya se cazó una vez en
//! `validar_cadena_de_cabeceras`, que sumaba el trabajo del tip en vez del ancla: juzgar una rama
//! con datos de otra.
//!
//! # Lo que este módulo NO valida
//!
//! Solo `bits`. Los timestamps (C-BLK-06, C-TS-01/03) y el cuerpo son de la validación completa de
//! bloque. Aquí se hace lo que se puede hacer con cabeceras sueltas, en la fase headers-first, que
//! es exactamente donde interesa descartar una cadena antes de gastar banda en sus cuerpos.

use primitive_types::U256;
use zx_consensus::dificultad::{N, VentanaRetarget, siguiente_target};
use zx_core::preimage::block::BlockHeader;
use zx_core::target::CompactBits;

use crate::cadena::Cadena;
use crate::sync::RechazoCabeceras;

/// Comprueba el `bits` de cada cabecera del lote contra lo que el retarget exige.
///
/// `cabeceras` deben venir ya validadas estructuralmente: encadenadas entre sí, con `bits`
/// canónico y colgando de `ancla_altura` (eso lo hace `sync::validar_estructura`).
///
/// # Errores
/// - [`RechazoCabeceras::DificultadIncorrecta`] en la primera cabecera cuyo `bits` no sea el que
///   toca. **Mala fe**: el retarget es una función pura, no hay forma inocente de discrepar.
/// - [`RechazoCabeceras::VentanaIncompleta`] si nos faltan ancestros para calcularlo. **No** es
///   mala fe: es una limitación nuestra.
/// - [`RechazoCabeceras::BitsNoCanonico`] si algún `bits` de la ventana no decodifica.
pub fn comprobar_dificultad(
    cadena: &Cadena,
    cabeceras: &[BlockHeader],
    ancla_altura: u32,
) -> Result<(), RechazoCabeceras> {
    let inicial = target_inicial(cadena)?;
    let n_u32 = u32::try_from(N).map_err(|_| RechazoCabeceras::VentanaIncompleta)?;

    for cab in cabeceras {
        let h = cab.height;

        // C-DIFF-02 · arranque. Para `1 ≤ H ≤ N` no hay ventana que mirar: rige TARGET_INICIAL.
        let esperado = if h == 0 || h <= n_u32 {
            inicial
        } else {
            let v = ventana(cadena, cabeceras, ancla_altura, h)?;
            siguiente_target(VentanaRetarget {
                timestamps: &v.0,
                targets: &v.1,
            })
            .map_err(|_| RechazoCabeceras::VentanaIncompleta)?
        };

        // C-DIFF-09 · la comparación es por `bits`, ida y vuelta, no por target. Dos `bits`
        // distintos pueden decodificar al mismo target solo si uno no es canónico, y la
        // canonicidad ya se comprobó — pero comparar el entero es más barato y más estricto.
        if cab.bits != CompactBits::codificar(esperado).to_u32() {
            return Err(RechazoCabeceras::DificultadIncorrecta);
        }
    }
    Ok(())
}

/// El `TARGET_INICIAL` de la red de esta cadena (C-DIFF-02).
fn target_inicial(cadena: &Cadena) -> Result<U256, RechazoCabeceras> {
    CompactBits::from_u32(zx_consensus::genesis::target_inicial_bits(cadena.red()))
        .decodificar()
        .map_err(|_| RechazoCabeceras::BitsNoCanonico)
}

/// Los `N+1` timestamps y los `N` targets de la ventana de `h`, tomados de la rama candidata.
fn ventana(
    cadena: &Cadena,
    lote: &[BlockHeader],
    ancla_altura: u32,
    h: u32,
) -> Result<(Vec<i64>, Vec<U256>), RechazoCabeceras> {
    let n_u32 = u32::try_from(N).map_err(|_| RechazoCabeceras::VentanaIncompleta)?;
    let desde = h
        .checked_sub(n_u32)
        .and_then(|x| x.checked_sub(1))
        .ok_or(RechazoCabeceras::VentanaIncompleta)?;

    let mut timestamps = Vec::with_capacity(N + 1);
    let mut targets = Vec::with_capacity(N);

    for altura in desde..h {
        // Por encima del ancla manda el lote; en el ancla y por debajo, nuestra cadena. Ese corte
        // es lo que hace que la ventana sea de la rama candidata y no de la nuestra.
        let cab = if altura > ancla_altura {
            buscar_en_lote(lote, altura)
        } else {
            cadena.cabecera_en(altura)
        }
        .ok_or(RechazoCabeceras::VentanaIncompleta)?;

        timestamps
            .push(i64::try_from(cab.timestamp).map_err(|_| RechazoCabeceras::VentanaIncompleta)?);
        // El último timestamp de la ventana es `ts(h−1)`, y su target NO entra: son `N+1`
        // timestamps y `N` targets (C-DIFF-01, C-DIFF-06).
        if altura < h - 1 {
            targets.push(
                CompactBits::from_u32(cab.bits)
                    .decodificar()
                    .map_err(|_| RechazoCabeceras::BitsNoCanonico)?,
            );
        }
    }

    if timestamps.len() != N + 1 || targets.len() != N {
        return Err(RechazoCabeceras::VentanaIncompleta);
    }
    Ok((timestamps, targets))
}

/// La cabecera del lote a una altura dada.
///
/// Búsqueda directa por índice: el lote llega encadenado y con alturas consecutivas —lo garantiza
/// `validar_estructura`—, así que la posición se calcula, no se busca. Recorrerlo sería `O(n²)`
/// sobre datos que un peer elige.
fn buscar_en_lote(lote: &[BlockHeader], altura: u32) -> Option<BlockHeader> {
    let primera = lote.first()?.height;
    let idx = usize::try_from(altura.checked_sub(primera)?).ok()?;
    let cab = lote.get(idx)?;
    // Cinturón: si las alturas no fueran consecutivas, el índice apuntaría a otra cabecera y la
    // ventana se calcularía con datos equivocados en silencio.
    (cab.height == altura).then_some(*cab)
}

#[cfg(test)]
#[expect(
    clippy::unwrap_used,
    clippy::expect_used,
    reason = "los tests fallan con panic por diseño"
)]
mod tests {
    use super::{comprobar_dificultad, target_inicial};
    use crate::cadena::Cadena;
    use crate::sync::RechazoCabeceras;
    use zx_consensus::dificultad::{N, T, VentanaRetarget, siguiente_target};
    use zx_core::digest::{Digest, MerkleRoot};
    use zx_core::preimage::block::BlockHeader;
    use zx_core::red::Red;
    use zx_core::target::CompactBits;

    const TS0: u64 = 1_788_480_000;

    /// Una cabecera con el `bits` que se le diga, encadenada a `prev`.
    fn cab(altura: u32, prev: zx_core::digest::BlockHash, bits: u32) -> BlockHeader {
        BlockHeader {
            consensus_branch_id: 0xc478_80ea,
            prev_hash: prev,
            merkle_root: MerkleRoot::from_digest(Digest::from_bytes([altura as u8; 32])),
            // Solvetimes exactos de T: es el caso en que LWMA no debe mover nada.
            timestamp: TS0 + u64::from(altura) * T.unsigned_abs(),
            bits,
            nonce: u64::from(altura),
            height: altura,
        }
    }

    /// El `bits` de arranque de MAINNET, `0x1c07fff8`: 32 veces más difícil que el mínimo.
    ///
    /// Los tests de "un bits más fácil" lo necesitan porque **el `TARGET_INICIAL` de testnet es
    /// `POW_LIMIT`**: ya es el target más grande que el protocolo admite, así que no existe un
    /// `bits` canónico más fácil que él y el ataque no se puede ni expresar. Sobre una base más
    /// dura sí, y es además el caso realista — mainnet arranca ahí.
    const DURO: u32 = 0x1c07_fff8;

    /// Un lote de `n` cabeceras a partir del génesis, todas con el mismo `bits`.
    fn lote_con(c: &Cadena, n: u32, bits: u32) -> Vec<BlockHeader> {
        let mut prev = c.genesis();
        (1..=n)
            .map(|i| {
                let h = cab(i, prev, bits);
                prev = h.block_hash();
                h
            })
            .collect()
    }

    /// Un lote con el `bits` inicial de la red.
    fn lote(c: &Cadena, n: u32) -> Vec<BlockHeader> {
        lote_con(
            c,
            n,
            CompactBits::codificar(target_inicial(c).unwrap()).to_u32(),
        )
    }

    /// La ventana de `h` leída de nuestra cadena, y el target que LWMA exige.
    fn esperado_en(c: &Cadena, h: u32) -> primitive_types::U256 {
        let n = u32::try_from(N).unwrap();
        let mut ts = Vec::new();
        let mut tg = Vec::new();
        for altura in (h - n - 1)..h {
            let cab = c.cabecera_en(altura).unwrap();
            ts.push(i64::try_from(cab.timestamp).unwrap());
            if altura < h - 1 {
                tg.push(CompactBits::from_u32(cab.bits).decodificar().unwrap());
            }
        }
        siguiente_target(VentanaRetarget {
            timestamps: &ts,
            targets: &tg,
        })
        .unwrap()
    }

    /// **C-DIFF-02 · hasta `N` manda `TARGET_INICIAL`, y no hay ventana que mirar.**
    #[test]
    fn hasta_n_rige_el_target_inicial() {
        let c = Cadena::nueva(Red::Testnet).unwrap();
        let l = lote(&c, 5);
        comprobar_dificultad(&c, &l, 0).expect("el bits inicial es el que toca");
    }

    /// **El ataque que este módulo existe para parar: cabeceras baratas.**
    ///
    /// Antes de esto el nodo las adoptaba. La única defensa era el umbral de trabajo de C-NET-04,
    /// que solo atrapa lo grosero: un `bits` un poco más fácil del que toca produce una cadena que
    /// **este nodo acepta y el resto de la red rechaza**, que es divergencia de consenso.
    #[test]
    fn un_bits_mas_facil_del_que_toca_es_mala_fe() {
        let c = Cadena::nueva(Red::Testnet).unwrap();
        let n = u32::try_from(N).unwrap();
        c.extender_sin_validar_solo_para_pruebas(&lote_con(&c, n, DURO));

        let target = esperado_en(&c, n + 1);
        let esperado = CompactBits::codificar(target).to_u32();
        let prev = c.cabecera_en(n).unwrap().block_hash();

        // El doble de target = la mitad de trabajo. Se construye codificando el target, no sumando
        // al exponente: sumar al exponente lo multiplica por 256 y se sale de POW_LIMIT, con lo que
        // el rechazo vendría de otra comprobación y el test aprobaría por el motivo equivocado.
        let facil = CompactBits::codificar(target * 2).to_u32();
        assert_ne!(facil, esperado, "el ataque debe ser un bits distinto");
        assert!(
            CompactBits::from_u32(facil).decodificar().is_ok(),
            "el bits del ataque debe ser canónico y estar en rango"
        );

        let e = comprobar_dificultad(&c, &[cab(n + 1, prev, facil)], n)
            .expect_err("un bits más fácil MUST rechazarse");
        assert_eq!(e, RechazoCabeceras::DificultadIncorrecta);
        assert!(e.es_mala_fe(), "no hay forma inocente de traer otro bits");

        // Y el correcto sí pasa, para que el test no pueda aprobar por el motivo equivocado.
        comprobar_dificultad(&c, &[cab(n + 1, prev, esperado)], n)
            .expect("el bits que LWMA exige debe aceptarse");
    }

    /// **A partir de `N+1` manda LWMA, calculado sobre la ventana real.**
    ///
    /// Con solvetimes exactos de `T` el retarget no debe mover el target: si lo moviera, el
    /// problema sería de `siguiente_target`, no de aquí. Lo que se comprueba es que este módulo
    /// pide **el valor que la función pura devuelve**, sea cual sea.
    #[test]
    fn en_n_mas_uno_manda_lwma_y_no_el_inicial() {
        let c = Cadena::nueva(Red::Testnet).unwrap();
        let n = u32::try_from(N).unwrap();
        let previas = lote(&c, n);
        c.extender_sin_validar_solo_para_pruebas(&previas);
        assert_eq!(c.altura(), n);

        // La ventana de `N+1`: timestamps de las alturas 0..=N, targets de las 0..N−1.
        let mut ts = Vec::new();
        let mut tg = Vec::new();
        for altura in 0..=n {
            let h = c.cabecera_en(altura).unwrap();
            ts.push(i64::try_from(h.timestamp).unwrap());
            if altura < n {
                tg.push(CompactBits::from_u32(h.bits).decodificar().unwrap());
            }
        }
        let esperado = siguiente_target(VentanaRetarget {
            timestamps: &ts,
            targets: &tg,
        })
        .unwrap();

        let prev = c.cabecera_en(n).unwrap().block_hash();
        let buena = cab(n + 1, prev, CompactBits::codificar(esperado).to_u32());
        comprobar_dificultad(&c, &[buena], n).expect("el bits de LWMA es el que toca");

        // Y el inicial, si difiere, ya no vale a esta altura.
        let inicial = CompactBits::codificar(target_inicial(&c).unwrap()).to_u32();
        if inicial != buena.bits {
            let mala = cab(n + 1, prev, inicial);
            assert_eq!(
                comprobar_dificultad(&c, &[mala], n),
                Err(RechazoCabeceras::DificultadIncorrecta),
                "pasada la altura N, TARGET_INICIAL deja de ser una respuesta válida"
            );
        }
    }

    /// **Sin ancestros no se juzga, y no se castiga.**
    ///
    /// Una cabecera a una altura alta cuya ventana no tenemos no es un ataque: es que nos faltan
    /// datos. Tratarlo como mala fe desconectaría a peers honestos durante la descarga inicial.
    #[test]
    fn sin_ventana_no_es_mala_fe() {
        let c = Cadena::nueva(Red::Testnet).unwrap();
        let bits = CompactBits::codificar(target_inicial(&c).unwrap()).to_u32();
        let suelta = cab(10_000, c.genesis(), bits);

        let e = comprobar_dificultad(&c, &[suelta], 0).expect_err("no se puede calcular");
        assert_eq!(e, RechazoCabeceras::VentanaIncompleta);
        assert!(
            !e.es_mala_fe(),
            "faltarnos ancestros es limitación nuestra, no culpa del peer"
        );
    }

    /// **La ventana de una bifurcación sale de la rama candidata, no de nuestra punta.**
    ///
    /// Es el mismo error que ya se cazó una vez en `validar_cadena_de_cabeceras`, que sumaba el
    /// trabajo del tip en lugar del ancla. Aquí se comprueba que por encima del ancla mandan las
    /// cabeceras del lote: se le da al lote un timestamp muy distinto del que tiene nuestra rama a
    /// esa misma altura, y el target esperado tiene que cambiar en consecuencia.
    #[test]
    fn la_ventana_de_una_bifurcacion_usa_el_lote_no_nuestra_punta() {
        let c = Cadena::nueva(Red::Testnet).unwrap();
        let n = u32::try_from(N).unwrap();
        c.extender_sin_validar_solo_para_pruebas(&lote_con(&c, n, DURO));

        // Bifurcación desde la altura N−1: dos cabeceras nuestras se sustituyen por otras dos con
        // solvetimes mucho más lentos, lo que debe hacer que LWMA afloje el target.
        let ancla_altura = n - 1;
        let ancla = c.cabecera_en(ancla_altura).unwrap();
        let bits = ancla.bits;

        let mut rama = Vec::new();
        let mut prev = ancla.block_hash();
        for i in 0..2u32 {
            let mut h = cab(ancla_altura + 1 + i, prev, bits);
            // Diez veces el tiempo de bloque: la rama es mucho más lenta que la nuestra.
            h.timestamp = ancla.timestamp + u64::from(i + 1) * T.unsigned_abs() * 10;
            prev = h.block_hash();
            rama.push(h);
        }

        // La segunda de la rama está a la altura N+1, así que su ventana ya es de LWMA y toma del
        // lote la cabecera de altura N — la de la rama, no la nuestra.
        let e = comprobar_dificultad(&c, &rama, ancla_altura);
        assert_eq!(
            e,
            Err(RechazoCabeceras::DificultadIncorrecta),
            "con solvetimes diez veces mayores el target esperado cambia, así que reutilizar el \
             `bits` del ancla ya no vale. Si esto pasara, la ventana se estaría armando con \
             nuestras cabeceras en vez de con las del lote."
        );
    }
}
