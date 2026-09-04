//! Target compacto, comparación de PoW y trabajo acumulado (SPEC §7.1, §7.2, §11).
//!
//! # La trampa de endianness
//!
//! `C-POW-01` compara el hash de bloque con el target interpretándolo como entero **big-endian**.
//!
//! Zebra hace lo contrario —`U256::from_little_endian`— y no está mal: Bitcoin y Zcash muestran y
//! almacenan sus hashes con los bytes invertidos por convención histórica, y Zebra respeta esa
//! convención. **ZEROX no la tiene.** Portar ese archivo tal cual compilaría, pasaría cualquier test
//! autoconsistente, y produciría una cadena distinta a la del resto de la red.
//!
//! Por eso hay un test que fija la convención con un vector asimétrico, y no un comentario pidiendo
//! cuidado.

use primitive_types::U256;

use crate::digest::BlockHash;
use crate::error::EncodingError;

/// Target máximo — la **dificultad mínima** que el protocolo admite (P-004).
///
/// `2^224 − 1`. Equivale a `2^32` ≈ 4,29·10⁹ hashes por bloque, es decir ~35,8 MH/s sostenidos para
/// mantener los 120 s.
pub fn pow_limit() -> U256 {
    (U256::one() << 224usize) - U256::one()
}

/// Target mínimo — la **dificultad máxima** (P-004).
///
/// `2^64`. Acota el error de truncamiento del retarget manteniendo al menos 64 bits significativos.
pub fn min_target() -> U256 {
    U256::one() << 64usize
}

/// `bits` del génesis y de los primeros `N` bloques (C-DIFF-02).
///
/// `0x1d00ffff`, que decodifica a `2^224 − 2^208` — **el mayor target representable** bajo
/// [`pow_limit`].
///
/// # Por qué no es `2^224 − 1` exactamente
///
/// El formato compacto solo representa valores de la forma `mantisa × 256^k` con la mantisa de 3
/// bytes. `2^224 − 1` son 28 bytes de `0xFF` seguidos: **no es representable**. Si el SPEC exigiera
/// literalmente `TARGET_INICIAL = POW_LIMIT`, el bloque génesis no podría llevar un `bits` que
/// decodificara a ese valor.
///
/// `POW_LIMIT` sigue siendo la **cota** —ningún target puede superarla— y `TARGET_INICIAL` es el
/// mayor valor representable por debajo. La diferencia es de 1,5·10⁻⁵ en dificultad: irrelevante.
/// Es la misma situación que en Bitcoin, cuyo `powLimit` es justamente `0x1d00ffff`.
pub const TARGET_INICIAL_BITS: u32 = 0x1d00_ffff;

/// Target del génesis, ya decodificado (C-DIFF-02).
///
/// La elección es asimétrica —pasarse de difícil impide lanzar, pasarse de fácil se autocorrige en
/// minutos porque con `N = 90` la ventana se llena enseguida— y este es el extremo seguro.
/// 🔶 Revisable **solo hasta crear el génesis**.
pub fn target_inicial() -> U256 {
    U256::from(0x0000_ffff_u32) << (8usize * (0x1d - 3))
}

/// Target compacto de 32 bits (C-POW-03).
///
/// Codifica un entero de 256 bits como `mantisa (3 bytes) × 256^(exponente − 3)`, con el exponente
/// en el byte más significativo.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct CompactBits(u32);

impl CompactBits {
    /// El `u32` tal cual aparece en la cabecera.
    #[must_use]
    pub const fn to_u32(self) -> u32 {
        self.0
    }

    /// Envuelve un `u32` sin validar. La validación ocurre en [`Self::decodificar`].
    #[must_use]
    pub const fn from_u32(v: u32) -> Self {
        Self(v)
    }

    /// Decodifica a target, exigiendo forma **canónica** y rango (C-POW-04, C-POW-05).
    ///
    /// Rechaza, en este orden:
    /// - bit de signo puesto,
    /// - exponente cero,
    /// - mantisa cero,
    /// - mantisa no normalizada (cabía con un exponente menor),
    /// - desbordamiento de 256 bits,
    /// - target fuera de `[MIN_TARGET, POW_LIMIT]`.
    ///
    /// La canonicidad no es estética: sin ella, un mismo target admite varias codificaciones y un
    /// minero puede probar cada una contra el filtro de dificultad. Es el mismo razonamiento que
    /// C-ENC-05 para `CompactSize`.
    ///
    /// # Errores
    /// [`EncodingError::BitsNoCanonico`] o [`EncodingError::TargetFueraDeRango`].
    pub fn decodificar(self) -> Result<U256, EncodingError> {
        let v = self.0;
        let exponente = (v >> 24) as u8;
        let mantisa = v & 0x007f_ffff;
        let signo = v & 0x0080_0000 != 0;

        let malo = |motivo| EncodingError::BitsNoCanonico { bits: v, motivo };

        if signo {
            return Err(malo("el bit de signo MUST estar a cero"));
        }
        if exponente == 0 {
            return Err(malo("exponente cero"));
        }
        if mantisa == 0 {
            return Err(malo("mantisa cero"));
        }
        // El exponente cuenta bytes: mantisa × 256^(exp−3).
        if exponente < 3 {
            return Err(malo("exponente < 3 no es representable de forma canónica"));
        }
        let desplazamiento = 8usize * (exponente as usize - 3);
        // 24 bits de mantisa + desplazamiento MUST caber en 256.
        if desplazamiento + 24 > 256 {
            return Err(malo("mantisa × 256^(exp−3) desborda 256 bits"));
        }
        let target = U256::from(mantisa) << desplazamiento;

        // C-POW-04 · canonicidad, definida como punto fijo: `bits` MUST ser exactamente lo que
        // produce el codificador para ese target.
        //
        // Se define así, y no enumerando reglas estructurales, porque enumerar se equivoca. El
        // intento obvio —"el byte alto de la mantisa MUST ser distinto de cero"— rechaza
        // `0x1d00ffff`, que es canónico: ese byte cero **es** el resultado del desplazamiento que
        // evita invadir el bit de signo. Es el propio `powLimit` de Bitcoin.
        //
        // Recodificar y comparar no puede desincronizarse del codificador, porque es el codificador.
        if Self::codificar(target).0 != v {
            return Err(malo("no es la codificación canónica de su propio target"));
        }

        if target > pow_limit() {
            return Err(EncodingError::TargetFueraDeRango {
                motivo: "target > POW_LIMIT",
            });
        }
        if target < min_target() {
            return Err(EncodingError::TargetFueraDeRango {
                motivo: "target < MIN_TARGET",
            });
        }
        Ok(target)
    }

    /// Codifica un target en su forma compacta **canónica** (C-POW-04).
    ///
    /// Es la inversa de [`Self::decodificar`] para todo target en `[MIN_TARGET, POW_LIMIT]` —
    /// demostrado exhaustivamente por D9 sobre los 167 116 800 pares (exponente, mantisa) válidos
    /// del rango: cero fallos de identidad, cero colisiones.
    ///
    /// ⚠️ **No lo es fuera de ese rango.** Para todo `target < 2¹⁶` produce un `bits` con exponente
    /// `< 3` que `decodificar` rechaza: su propia salida no vuelve a decodificar a nada. Hoy es
    /// inalcanzable —`MIN_TARGET = 2⁶⁴` está `2⁴⁸` por encima— pero **la propiedad vale sobre el
    /// subrango, no sobre los 256 bits**, y dejaría de valer si `MIN_TARGET` bajara de `2¹⁶`.
    #[must_use]
    pub fn codificar(target: U256) -> Self {
        if target.is_zero() {
            return Self(0);
        }
        // Bytes significativos: cuántos hacen falta para representarlo.
        let bits_significativos = 256 - target.leading_zeros() as usize;
        let mut exponente = bits_significativos.div_ceil(8);
        let mut mantisa = if exponente <= 3 {
            (target << (8 * (3 - exponente))).low_u32() & 0x00ff_ffff
        } else {
            (target >> (8 * (exponente - 3))).low_u32() & 0x00ff_ffff
        };
        // Si el bit alto de la mantisa invadiría el bit de signo, se corre un byte.
        if mantisa & 0x0080_0000 != 0 {
            mantisa >>= 8;
            exponente += 1;
        }
        Self((u32::try_from(exponente).unwrap_or(0xFF) << 24) | mantisa)
    }
}

/// Interpreta un hash de bloque como entero **big-endian** (C-POW-01).
///
/// Ver la nota de endianness del módulo: no es intercambiable con little-endian.
#[must_use]
pub fn hash_como_entero(h: &BlockHash) -> U256 {
    U256::from_big_endian(h.as_bytes())
}

/// C-POW-01: un bloque satisface el PoW si `block_hash < target`.
#[must_use]
pub fn cumple_pow(h: &BlockHash, target: U256) -> bool {
    hash_como_entero(h) < target
}

/// Trabajo esperado de un bloque con ese target (C-FORK-01).
///
/// ```text
/// trabajo(t) = ((2^256 − 1 − t) / (t + 1)) + 1
/// ```
///
/// Es `2^256 / (target + 1)` sin necesitar un entero de 257 bits: `!t` en `U256` ya es
/// `2^256 − 1 − t`, y `(2^256 − 1 − t) + (t + 1) = 2^256` exactamente. El mismo truco que usa
/// Bitcoin en `arith_uint256::GetBlockProof`.
///
/// Devuelve `None` si `target + 1` desborda, que solo ocurre con `target = 2^256 − 1` — imposible
/// bajo C-POW-05, pero se trata como valor en vez de dar por hecho que no pasa.
#[must_use]
pub fn trabajo_bloque(target: U256) -> Option<U256> {
    let divisor = target.checked_add(U256::one())?;
    if divisor.is_zero() {
        return None;
    }
    ((!target) / divisor).checked_add(U256::one())
}

/// Trabajo acumulado de una cadena (C-FORK-02).
///
/// Valor **derivado y cacheable**, nunca fuente de verdad: **MUST** poder recalcularse a partir de
/// los `bits` almacenados.
///
/// Se lleva en `U256`, no en `u128`. Zebra usa `u128` y le basta, pero Zcash tiene una vida acotada
/// conocida; ZEROX no tiene `MAX_MONEY` ni fin de emisión, así que 256 bits evitan tener que volver
/// a demostrar dentro de cincuenta años que el ancho seguía bastando.
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Debug, Default)]
pub struct TrabajoAcumulado(U256);

impl TrabajoAcumulado {
    /// Cero.
    #[must_use]
    pub fn cero() -> Self {
        Self(U256::zero())
    }

    /// El valor acumulado.
    #[must_use]
    pub const fn valor(self) -> U256 {
        self.0
    }

    /// Suma el trabajo de un bloque. `None` si desborda (C-ENC-03: nunca en silencio).
    #[must_use]
    pub fn sumar(self, trabajo: U256) -> Option<Self> {
        self.0.checked_add(trabajo).map(Self)
    }
}

#[cfg(test)]
#[expect(
    clippy::unwrap_used,
    clippy::panic,
    reason = "los tests fallan con panic por diseño"
)]
mod tests {
    use super::{
        CompactBits, TARGET_INICIAL_BITS, TrabajoAcumulado, cumple_pow, hash_como_entero,
        min_target, pow_limit, target_inicial, trabajo_bloque,
    };
    use crate::digest::{BlockHash, Digest};
    use primitive_types::U256;

    fn hash(bytes: [u8; 32]) -> BlockHash {
        BlockHash::from_digest(Digest::from_bytes(bytes))
    }

    /// **La trampa de Zebra.** Fija la convención con un vector deliberadamente asimétrico.
    ///
    /// Con big-endian, `0x01` en el primer byte pesa `2^248`. Con little-endian pesaría 1. Si
    /// alguien porta el archivo de Zebra tal cual y deja `from_little_endian`, este test lo caza.
    #[test]
    fn el_hash_se_interpreta_big_endian() {
        let mut b = [0u8; 32];
        *b.first_mut().unwrap() = 0x01;
        let v = hash_como_entero(&hash(b));
        assert_eq!(
            v,
            U256::one() << 248usize,
            "C-POW-01: big-endian, no little-endian"
        );

        let mut b = [0u8; 32];
        *b.last_mut().unwrap() = 0x01;
        assert_eq!(
            hash_como_entero(&hash(b)),
            U256::one(),
            "el último byte es el menos pesado"
        );
    }

    #[test]
    fn el_pow_compara_estrictamente_menor() {
        let t = U256::from(1000u32);
        assert!(cumple_pow(&hash(U256::from(999u32).to_big_endian()), t));
        assert!(
            !cumple_pow(&hash(t.to_big_endian()), t),
            "igual al target NO cumple"
        );
        assert!(!cumple_pow(&hash(U256::from(1001u32).to_big_endian()), t));
    }

    #[test]
    fn ida_y_vuelta_de_bits_canonico() {
        for t in [
            target_inicial(),
            min_target(),
            U256::one() << 200usize,
            U256::one() << 100usize,
        ] {
            let b = CompactBits::codificar(t);
            let d = b
                .decodificar()
                .unwrap_or_else(|e| panic!("no decodifica {t}: {e}"));
            assert_eq!(d, t, "ida y vuelta rota para {t}");
        }
    }

    /// C-POW-04. Cada uno de estos es una codificación no canónica del mismo target.
    #[test]
    fn se_rechazan_los_bits_no_canonicos() {
        // Bit de signo.
        assert!(
            CompactBits::from_u32(0x1d80_ffff).decodificar().is_err(),
            "signo"
        );
        // Exponente cero.
        assert!(
            CompactBits::from_u32(0x0000_ffff).decodificar().is_err(),
            "exp 0"
        );
        // Mantisa cero.
        assert!(
            CompactBits::from_u32(0x1d00_0000).decodificar().is_err(),
            "mantisa 0"
        );
        // No canónico: 0x1d0000ff representa el mismo target que 0x1b00ff00, con exponente menor.
        assert!(
            CompactBits::from_u32(0x1d00_00ff).decodificar().is_err(),
            "no mínimo"
        );

        // Y el contraejemplo que una regla estructural ingenua rechazaría por error: `0x1d00ffff`
        // tiene el byte alto de la mantisa a cero y **sí** es canónico — es el powLimit de Bitcoin.
        assert!(
            CompactBits::from_u32(0x1d00_ffff).decodificar().is_ok(),
            "0x1d00ffff es canónico: el byte cero sale de evitar el bit de signo"
        );
    }

    /// `TARGET_INICIAL` **MUST** ser representable en forma compacta: el génesis tiene que poder
    /// llevar un `bits` que decodifique a él. `2^224 − 1` no lo es.
    #[test]
    fn el_target_inicial_es_representable_y_cabe_bajo_pow_limit() {
        let bits = CompactBits::from_u32(TARGET_INICIAL_BITS);
        assert_eq!(bits.decodificar().unwrap(), target_inicial());
        assert_eq!(
            CompactBits::codificar(target_inicial()).to_u32(),
            TARGET_INICIAL_BITS
        );
        assert!(
            target_inicial() < pow_limit(),
            "TARGET_INICIAL MUST estar bajo la cota"
        );
        assert!(CompactBits::codificar(pow_limit()).decodificar().unwrap() <= pow_limit());
    }

    #[test]
    fn se_rechaza_el_target_fuera_de_rango() {
        // Por encima de POW_LIMIT = 2^224 − 1.
        let demasiado_facil = CompactBits::codificar(U256::one() << 240usize);
        assert!(demasiado_facil.decodificar().is_err(), "target > POW_LIMIT");

        // Por debajo de MIN_TARGET = 2^64.
        let demasiado_dificil = CompactBits::codificar(U256::one() << 32usize);
        assert!(
            demasiado_dificil.decodificar().is_err(),
            "target < MIN_TARGET"
        );
    }

    /// C-FORK-01 contra los dos extremos, calculados a mano.
    #[test]
    fn el_trabajo_es_2_elevado_256_entre_target_mas_uno() {
        // target = 2^224 − 2^208  ⇒  trabajo ≈ 2^32
        let w = trabajo_bloque(target_inicial()).unwrap();
        assert!(
            w >= (U256::one() << 32usize) && w <= (U256::one() << 33usize),
            "{w}"
        );
        // target = 2^64  ⇒  trabajo ≈ 2^192
        let t = min_target();
        let w = trabajo_bloque(t).unwrap();
        assert!(
            w >= (U256::one() << 191usize) && w <= (U256::one() << 192usize),
            "{w}"
        );
    }

    /// Más difícil (target menor) **MUST** dar más trabajo. Si se invirtiera, el fork choice
    /// premiaría la cadena más débil.
    #[test]
    fn menos_target_es_mas_trabajo() {
        let facil = trabajo_bloque(target_inicial()).unwrap();
        let medio = trabajo_bloque(U256::one() << 200usize).unwrap();
        let dificil = trabajo_bloque(min_target()).unwrap();
        assert!(facil < medio, "{facil} < {medio}");
        assert!(medio < dificil, "{medio} < {dificil}");
    }

    #[test]
    fn el_trabajo_acumulado_no_desborda_en_silencio() {
        let acc = TrabajoAcumulado::cero();
        let w = trabajo_bloque(target_inicial()).unwrap();
        let acc = acc.sumar(w).unwrap().sumar(w).unwrap();
        assert_eq!(acc.valor(), w * 2u32);

        // El borde: sumar sobre el máximo debe devolver None, no envolver.
        let lleno = TrabajoAcumulado::cero().sumar(U256::MAX).unwrap();
        assert!(
            lleno.sumar(U256::one()).is_none(),
            "C-ENC-03: nunca desbordamiento silencioso"
        );
    }

    /// 262 800 bloques al año a dificultad mínima: el acumulado ni se acerca a agotar `U256`.
    /// Es la comprobación de que 256 bits sobran para siempre.
    #[test]
    fn el_acumulado_aguanta_siglos() {
        let por_bloque = trabajo_bloque(min_target()).unwrap(); // el caso más caro
        let bloques_en_mil_anios = U256::from(262_800u32) * U256::from(1000u32);
        let total = por_bloque.checked_mul(bloques_en_mil_anios);
        assert!(
            total.is_some(),
            "mil años a dificultad máxima deben caber en U256"
        );
    }
}
