//! Selección de cadena y mecánica de reorganización (SPEC §11, §12).
//!
//! # No es "la cadena más larga"
//!
//! Es la de **mayor trabajo acumulado** (C-FORK-03). La distinción no es pedante: "más larga" es
//! falseable minando muchos bloques de dificultad ínfima.
//!
//! Y el trabajo acumulado es condición **necesaria, no suficiente**. Bitcoin lo implementa así en
//! `FindMostWorkChain()`: toma el máximo, camina hacia atrás verificando que ningún ancestro esté
//! marcado inválido, y si lo está lo purga del conjunto de candidatos y repite.
//!
//! # El desempate diverge de Bitcoin a propósito
//!
//! Bitcoin desempata por orden de llegada local (`nSequenceId`), lo que es **no determinista entre
//! nodos**: dos nodos que reciben los mismos bloques en distinto orden sostienen tips distintos.
//! Para ZEROX eso significaría que **el nodo de Cortex y el del vendedor podrían discrepar sobre si
//! un pago existe**.
//!
//! `C-FORK-04` desempata por el **menor hash de tip**, big-endian. Zebra hace lo mismo en producción
//! en la mainnet de Zcash, documentando que se aparta de la spec de Zcash a propósito.

use primitive_types::U256;
use zx_core::digest::BlockHash;
use zx_core::target::{TrabajoAcumulado, hash_como_entero, trabajo_bloque};

use crate::error::ConsensusError;

/// Profundidad máxima de reorganización (C-REORG-07).
///
/// `COINBASE_MATURITY − 1`. Un reorg más profundo **MUST NOT** aplicarse: el nodo se detiene y
/// alerta.
///
/// Lo que compra, dicho para un vendedor: *pasadas 100 confirmaciones el cobro es final por
/// protocolo, no solo probablemente*. Es finalidad al estilo Zcash en vez de la probabilística de
/// Bitcoin, y cierra el vector "el minero cobra, gasta el coinbase, y un reorg profundo se lo
/// quita".
///
/// **La contrapartida es deliberada**: una partición de red honesta de más de 3,3 h con hashrate a
/// ambos lados para el nodo y exige intervención humana. Es *fail-stop*, no *fail-safe*: para
/// infraestructura de pagos, pararse y avisar es mejor que servir el estado de una minoría sin
/// saberlo.
pub const MAX_REORG_LENGTH: u32 = crate::emision::COINBASE_MATURITY - 1;

/// Lo mínimo que el fork choice necesita saber de un tip.
///
/// `trabajo` es derivado y cacheable, pero **MUST** poder recalcularse desde los `bits` almacenados
/// (C-FORK-02). Nunca es fuente de verdad.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct Tip {
    /// Hash de la cabecera del tip.
    pub hash: BlockHash,
    /// Altura del tip.
    pub altura: u32,
    /// Trabajo acumulado desde el génesis hasta este bloque, inclusive.
    pub trabajo: TrabajoAcumulado,
}

/// Resultado de comparar dos tips.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Preferencia {
    /// Gana el primero.
    Primero,
    /// Gana el segundo.
    Segundo,
}

/// Compara dos tips según C-FORK-03 y C-FORK-04.
///
/// Primero el trabajo acumulado; en empate **exacto**, el menor `block_hash` interpretado como
/// entero big-endian (la misma convención de C-POW-01).
///
/// Es **total y determinista**: dos nodos con los mismos dos tips eligen siempre lo mismo, sin
/// depender del orden de llegada ni de ningún reloj.
///
/// Dos tips con el mismo hash son el mismo bloque; se devuelve [`Preferencia::Primero`] por
/// convención, y el llamante no debería estar comparándolos.
#[must_use]
pub fn preferir(a: &Tip, b: &Tip) -> Preferencia {
    match a.trabajo.cmp(&b.trabajo) {
        core::cmp::Ordering::Greater => Preferencia::Primero,
        core::cmp::Ordering::Less => Preferencia::Segundo,
        // C-FORK-04 · desempate determinista por menor hash.
        core::cmp::Ordering::Equal => {
            if hash_como_entero(&b.hash) < hash_como_entero(&a.hash) {
                Preferencia::Segundo
            } else {
                Preferencia::Primero
            }
        }
    }
}

/// Recalcula el trabajo acumulado de una cadena desde sus targets (C-FORK-02).
///
/// Existe para poder comprobar que el valor cacheado es correcto: el trabajo **MUST** poder
/// reconstruirse íntegramente desde los `bits` almacenados, así que un caché corrupto es detectable.
///
/// # Errores
/// [`ConsensusError::DesbordamientoAritmetico`] si algún target es inválido o la suma desborda.
pub fn trabajo_acumulado(targets: &[U256]) -> Result<TrabajoAcumulado, ConsensusError> {
    let mut acc = TrabajoAcumulado::cero();
    for t in targets {
        let w = trabajo_bloque(*t).ok_or(ConsensusError::DesbordamientoAritmetico)?;
        acc = acc
            .sumar(w)
            .ok_or(ConsensusError::DesbordamientoAritmetico)?;
    }
    Ok(acc)
}

/// Profundidad de la reorganización que supondría pasar de `activo` a `candidato`.
///
/// Es cuántos bloques hay que **desconectar**: `altura(activo) − altura(ancestro_comun)`.
#[must_use]
pub const fn profundidad_reorg(altura_activo: u32, altura_ancestro_comun: u32) -> u32 {
    altura_activo.saturating_sub(altura_ancestro_comun)
}

/// Comprueba C-REORG-07 antes de aplicar una reorganización.
///
/// # Errores
/// [`ConsensusError::ReorgDemasiadoProfunda`] si excede [`MAX_REORG_LENGTH`]. Quien reciba este
/// error **MUST** detener el nodo y alertar al operador de forma explícita — **MUST NOT** limitarse
/// a rechazar el bloque y seguir, porque entonces el nodo se queda en una minoría de red sin
/// saberlo.
pub fn comprobar_profundidad_reorg(profundidad: u32) -> Result<(), ConsensusError> {
    if profundidad > MAX_REORG_LENGTH {
        return Err(ConsensusError::ReorgDemasiadoProfunda {
            profundidad,
            maximo: MAX_REORG_LENGTH,
        });
    }
    Ok(())
}

/// Clave de un caché de ventana (C-REORG-05).
///
/// **La clave es el hash del tip, nunca la altura.** Un caché indexado por altura devuelve datos de
/// la rama vieja tras un reorg que reemplaza bloques a las mismas alturas, **sin que nada falle
/// visiblemente**: fork silencioso, que es el peor tipo porque el nodo sigue funcionando y aceptando
/// bloques bajo una regla de peso o dificultad que ya no corresponde a la cadena real.
///
/// La altura se guarda solo para diagnóstico; **no** participa en la igualdad.
#[derive(Clone, Copy, Debug)]
pub struct ClaveVentana {
    hash_tip: BlockHash,
    altura: u32,
}

impl ClaveVentana {
    /// Crea la clave a partir del tip que originó el valor cacheado.
    #[must_use]
    pub const fn nueva(hash_tip: BlockHash, altura: u32) -> Self {
        Self { hash_tip, altura }
    }

    /// Altura del tip. **Solo diagnóstico** — no interviene en la comparación.
    #[must_use]
    pub const fn altura(&self) -> u32 {
        self.altura
    }

    /// ¿Sigue siendo válido este valor cacheado para el tip dado?
    ///
    /// Compara **el hash**. Si no coincide, el llamante **MUST** recomputar desde cero sobre la
    /// cadena candidata (C-REORG-06), nunca reutilizar.
    #[must_use]
    pub fn vale_para(&self, tip_actual: &BlockHash) -> bool {
        self.hash_tip == *tip_actual
    }
}

impl PartialEq for ClaveVentana {
    /// **Solo el hash.** Dos claves con la misma altura y distinto hash son distintas — esa es toda
    /// la regla C-REORG-05.
    fn eq(&self, otra: &Self) -> bool {
        self.hash_tip == otra.hash_tip
    }
}

impl Eq for ClaveVentana {}

#[cfg(test)]
#[expect(clippy::unwrap_used, reason = "los tests fallan con panic por diseño")]
mod tests {
    use super::{
        ClaveVentana, MAX_REORG_LENGTH, Preferencia, Tip, comprobar_profundidad_reorg, preferir,
        profundidad_reorg, trabajo_acumulado,
    };
    use crate::emision::COINBASE_MATURITY;
    use crate::error::ConsensusError;
    use primitive_types::U256;
    use zx_core::digest::{BlockHash, Digest};
    use zx_core::target::{TrabajoAcumulado, target_inicial, trabajo_bloque};

    fn hash(primer_byte: u8) -> BlockHash {
        let mut b = [0u8; 32];
        if let Some(p) = b.first_mut() {
            *p = primer_byte;
        }
        BlockHash::from_digest(Digest::from_bytes(b))
    }

    fn tip(primer_byte: u8, altura: u32, trabajo: u64) -> Tip {
        Tip {
            hash: hash(primer_byte),
            altura,
            trabajo: TrabajoAcumulado::cero().sumar(U256::from(trabajo)).unwrap(),
        }
    }

    /// C-FORK-03: gana el trabajo, no la longitud.
    #[test]
    fn gana_el_trabajo_acumulado_no_la_altura() {
        let corta_pero_pesada = tip(1, 10, 1_000_000);
        let larga_pero_ligera = tip(2, 10_000, 999_999);
        assert_eq!(
            preferir(&corta_pero_pesada, &larga_pero_ligera),
            Preferencia::Primero,
            "10 bloques pesados ganan a 10 000 ligeros"
        );
    }

    /// C-FORK-04: el desempate es **determinista** y por el menor hash.
    #[test]
    fn el_desempate_es_por_el_menor_hash() {
        let a = tip(0x10, 5, 500);
        let b = tip(0x02, 5, 500);
        assert_eq!(preferir(&a, &b), Preferencia::Segundo, "0x02… < 0x10…");
        assert_eq!(
            preferir(&b, &a),
            Preferencia::Primero,
            "y al revés, lo mismo"
        );
    }

    /// **La propiedad que motiva C-FORK-04.** El resultado no depende del orden de los argumentos.
    ///
    /// Con la regla de Bitcoin —orden de llegada— esto sería falso por construcción, y dos nodos
    /// podrían sostener tips distintos. Aquí el nodo de Cortex y el del vendedor **no pueden**
    /// discrepar sobre si un pago existe.
    #[test]
    fn el_desempate_es_independiente_del_orden_de_llegada() {
        for i in 1u8..40 {
            for j in 1u8..40 {
                if i == j {
                    continue;
                }
                let a = tip(i, 7, 1234);
                let b = tip(j, 7, 1234);
                let directo = preferir(&a, &b);
                let inverso = preferir(&b, &a);
                let coherente = matches!(
                    (directo, inverso),
                    (Preferencia::Primero, Preferencia::Segundo)
                        | (Preferencia::Segundo, Preferencia::Primero)
                );
                assert!(
                    coherente,
                    "orden inconsistente para hashes {i:#04x} y {j:#04x}"
                );
            }
        }
    }

    /// C-FORK-02: el trabajo acumulado se reconstruye desde los targets. Un caché no es la verdad.
    #[test]
    fn el_trabajo_acumulado_se_puede_recalcular() {
        let targets = vec![target_inicial(); 5];
        let acc = trabajo_acumulado(&targets).unwrap();
        let uno = trabajo_bloque(target_inicial()).unwrap();
        assert_eq!(acc.valor(), uno * U256::from(5_u32));

        // Y sumar de uno en uno da lo mismo que la función de conveniencia.
        let mut manual = TrabajoAcumulado::cero();
        for t in &targets {
            manual = manual.sumar(trabajo_bloque(*t).unwrap()).unwrap();
        }
        assert_eq!(manual, acc);
    }

    #[test]
    fn la_cadena_vacia_tiene_trabajo_cero() {
        assert_eq!(trabajo_acumulado(&[]).unwrap(), TrabajoAcumulado::cero());
    }

    // ── C-REORG-07 ───────────────────────────────────────────────────────────

    #[test]
    fn el_limite_de_reorg_es_madurez_menos_uno() {
        assert_eq!(MAX_REORG_LENGTH, COINBASE_MATURITY - 1);
        assert_eq!(MAX_REORG_LENGTH, 99);
    }

    /// El borde exacto: 99 se acepta, 100 detiene el nodo.
    ///
    /// Que sea `COINBASE_MATURITY − 1` garantiza que **un coinbase maduro no puede deshacerse
    /// jamás**: cierra el vector "el minero cobra, gasta, y un reorg profundo se lo quita".
    #[test]
    fn el_borde_de_la_profundidad_maxima() {
        assert!(comprobar_profundidad_reorg(0).is_ok());
        assert!(
            comprobar_profundidad_reorg(MAX_REORG_LENGTH).is_ok(),
            "99 es válido"
        );

        let e = comprobar_profundidad_reorg(MAX_REORG_LENGTH + 1).unwrap_err();
        assert!(
            matches!(
                e,
                ConsensusError::ReorgDemasiadoProfunda {
                    profundidad: 100,
                    maximo: 99
                }
            ),
            "{e:?}"
        );
        // Y el mensaje debe decir qué hacer, no solo qué pasó.
        assert!(
            format!("{e}").contains("DETENER"),
            "el error MUST indicar la acción"
        );
    }

    /// Un coinbase que ya maduró no puede quedar fuera de la cadena por un reorg admisible.
    #[test]
    fn un_coinbase_maduro_no_puede_deshacerse() {
        // Un reorg del máximo admitido desconecta 99 bloques. Un coinbase con 100 confirmaciones
        // quedó 100 bloques atrás, así que sobrevive.
        let profundidad_maxima_admitida = MAX_REORG_LENGTH;
        assert!(
            profundidad_maxima_admitida < COINBASE_MATURITY,
            "MAX_REORG_LENGTH MUST ser menor que COINBASE_MATURITY"
        );
    }

    #[test]
    fn la_profundidad_es_la_distancia_al_ancestro_comun() {
        assert_eq!(profundidad_reorg(1000, 990), 10);
        assert_eq!(profundidad_reorg(1000, 1000), 0, "mismo tip, sin reorg");
        assert_eq!(profundidad_reorg(5, 10), 0, "no puede ser negativa");
    }

    // ── C-REORG-05 ───────────────────────────────────────────────────────────

    /// **La regla que evita el fork silencioso.** Misma altura, distinto hash ⇒ caché inválido.
    ///
    /// Este es exactamente el escenario de un reorg: los bloques se reemplazan **a las mismas
    /// alturas**. Un caché indexado por altura devolvería datos de la rama vieja sin que nada
    /// falle, y el nodo seguiría validando con una mediana que ya no corresponde a su cadena.
    #[test]
    fn el_cache_se_invalida_por_hash_no_por_altura() {
        let rama_vieja = ClaveVentana::nueva(hash(0xAA), 1000);
        let rama_nueva_misma_altura = hash(0xBB);

        assert!(
            rama_vieja.vale_para(&hash(0xAA)),
            "mismo tip: sigue valiendo"
        );
        assert!(
            !rama_vieja.vale_para(&rama_nueva_misma_altura),
            "C-REORG-05: misma altura y distinto hash MUST invalidar"
        );
    }

    /// Y la igualdad del propio tipo ignora la altura, para que nadie pueda "arreglarlo" comparando
    /// alturas por comodidad.
    #[test]
    fn la_igualdad_de_la_clave_solo_mira_el_hash() {
        let a = ClaveVentana::nueva(hash(0x01), 500);
        let b = ClaveVentana::nueva(hash(0x01), 999);
        let c = ClaveVentana::nueva(hash(0x02), 500);

        assert_eq!(a, b, "mismo hash: la misma clave, aunque la altura difiera");
        assert_ne!(
            a, c,
            "distinto hash: claves distintas, aunque la altura coincida"
        );
        assert_eq!(
            a.altura(),
            500,
            "la altura se conserva, pero solo para diagnóstico"
        );
    }
}
