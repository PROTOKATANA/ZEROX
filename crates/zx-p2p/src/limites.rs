//! Límites explícitos de la capa de red (SPEC §16.3, C-NET-11).
//!
//! # Por qué existe este módulo
//!
//! **La capa de transporte de libp2p no es segura por defecto para una cadena**, y lo peor es que
//! ninguno de sus defectos falla al compilar. Cuatro defaults, verificados contra
//! `rust-libp2p@v0.56.0`:
//!
//! | Límite | Default | Qué provoca en ZEROX |
//! |---|---|---|
//! | `gossipsub::max_transmit_size` | **65 536 B** | Un bloque completo no se propaga |
//! | `gossipsub::validate_messages` | **`false`** | El mensaje se reenvía **antes** de validarlo |
//! | `ConnectionLimits` | todo `None` | Sin límite de conexiones |
//! | Tamaño en `request_response::Codec` | **no existe** | El trait no impone ninguno |
//!
//! Reunirlos aquí, con nombre y con la razón al lado, es lo que impide que alguien "simplifique"
//! uno de ellos más adelante sin saber qué está quitando.
//!
//! # Los límites nuevos de la red dev
//!
//! La orden fija tres: tamaño máximo de [`crate::mensaje::BloqueRed`], hashes por petición (256) y
//! cabeceras por respuesta (2 000). El primero se declara **con valor dev** porque `zx-core` todavía
//! no ha portado `peso.rs`: cuando exista el límite de peso, este valor se derivará de él.

use zx_core::preimage::block::TAMANO_CABECERA;
use zx_core::preimage::dag::TAMANO_CABECERA_MAX;
use zx_core::wire_dag::MAX_JUSTIFICACION_POT_CODIFICADA;

/// Cuerpo máximo de un bloque en la red dev, en bytes.
///
/// **Valor dev declarado.** La orden pide «el límite de peso que ya use `zx-core`, o, si no existe,
/// 2 MiB dev». `peso.rs` no está portado (lo dirá W03+), así que se toma 2 MiB. No es una medición
/// ni una regla de consenso: es una cota de transporte provisional y revisable.
pub const MAX_CUERPO_DEV_BYTES: u64 = 2 * 1024 * 1024;

/// Tamaño máximo de un [`crate::mensaje::BloqueRed`], en bytes.
///
/// Desglose: cabecera PoST máxima ([`TAMANO_CABECERA_MAX`] = 1 037 B, la más grande de las dos
/// familias) **más** la justificación PoT codificada al máximo
/// ([`MAX_JUSTIFICACION_POT_CODIFICADA`] = 19 201 B; `ORDEN-W06d3` decisión 1: `BloqueRed::Post`
/// ahora la lleva, igual que `zx_core::wire_dag::BloqueDag`) **más** el cuerpo máximo dev. Un bloque
/// PoW no tiene justificación y por tanto siempre mide menos que este máximo. No incluye el byte de
/// familia ni el `CompactSize` del contador de transacciones: eso lo añade el códec al comprobar el
/// buffer recibido.
pub const MAX_BLOQUE_RED_BYTES: u64 =
    TAMANO_CABECERA_MAX as u64 + MAX_JUSTIFICACION_POT_CODIFICADA as u64 + MAX_CUERPO_DEV_BYTES;

/// Cuántas veces el límite de bloque dev admite el transporte.
///
/// El transporte **MUST** dejar pasar cualquier bloque que quepa con holgura para la cabecera, los
/// sobres del protocolo y cambios futuros del límite de cuerpo.
pub const FACTOR_MARGEN: u64 = 8;

/// Techo absoluto que ningún `LIMITE(H)` legítimo puede alcanzar: **1 TiB**.
pub const LIMITE_BLOQUE_ABSURDO: u64 = 1 << 40;

/// Techo de gossip derivado del límite de bloque, o `None` si el límite es absurdo.
///
/// # Por qué devuelve `Option` y no satura
///
/// Saturar a `usize::MAX` significaría "sin límite", que es exactamente el fallo que C-NET-11 existe
/// para impedir. Un valor corrupto no debe traducirse en desactivar la defensa; debe traducirse en
/// no arrancar.
#[must_use]
pub const fn limite_gossip(limite_bloque: u64) -> Option<usize> {
    if limite_bloque == 0 || limite_bloque > LIMITE_BLOQUE_ABSURDO {
        return None;
    }
    let bytes = limite_bloque * FACTOR_MARGEN;
    if bytes > usize::MAX as u64 {
        // Solo alcanzable en un objetivo de 32 bits.
        None
    } else {
        Some(bytes as usize)
    }
}

/// Límite de bloque del arranque dev: [`MAX_BLOQUE_RED_BYTES`].
pub const LIMITE_BLOQUE_DEV: u64 = MAX_BLOQUE_RED_BYTES;

/// Tamaño máximo de un mensaje de gossipsub en el arranque dev.
pub const MAX_GOSSIP_BYTES: usize = match limite_gossip(LIMITE_BLOQUE_DEV) {
    Some(v) => v,
    // Inalcanzable: `MAX_BLOQUE_RED_BYTES` es ~2 MiB. Si fallara al compilar, es que alguien ha
    // tocado el límite del cuerpo hasta un valor imposible.
    None => panic!("MAX_BLOQUE_RED_BYTES debe dar un techo de gossip válido"),
};

/// A partir de qué fracción del margen el nodo **se niega a seguir**.
pub const MARGEN_MINIMO: u64 = 2;

/// ¿Puede este nodo seguir sirviendo con el límite de transporte que tiene?
///
/// El límite de gossipsub se fija al construir el behaviour y no cambia en caliente; un nodo que se
/// para diciendo "mi límite de transporte se ha quedado corto" es mejor que uno que deja de ver la
/// mitad de los mensajes sin decirlo.
#[must_use]
pub const fn margen_suficiente(limite_bloque: u64, limite_transporte: usize) -> bool {
    let necesario = limite_bloque.saturating_mul(MARGEN_MINIMO);
    necesario <= limite_transporte as u64
}

/// Tamaño máximo de una **petición** de sincronización, en bytes.
///
/// Una petición es un locator o una lista de hashes: unos pocos KiB como mucho. Que sea pequeño es
/// la primera línea de defensa — no hay razón legítima para una petición grande.
pub const MAX_PETICION_BYTES: u64 = 64 * 1024;

/// Bloques por respuesta de `Bloques`.
pub const MAX_BLOQUES_POR_RESPUESTA: usize = 16;

/// Tamaño máximo de una **respuesta** de sincronización, en bytes.
///
/// Una respuesta carga hasta [`MAX_BLOQUES_POR_RESPUESTA`] bloques completos. Sin cota, un peer
/// puede hacer que reservemos memoria arbitraria **antes** de que el parser rechace nada.
pub const MAX_RESPUESTA_BYTES: u64 =
    MAX_BLOQUES_POR_RESPUESTA as u64 * MAX_BLOQUE_RED_BYTES + 64 * 1024;

/// Cabeceras PoW por respuesta de `CabecerasPow`.
///
/// A 92 bytes por cabecera son ~184 KB por respuesta llena. Bitcoin usa 2000.
pub const MAX_CABECERAS_POR_RESPUESTA: usize = 2_000;

/// Hashes por petición de `Bloques`.
///
/// La orden lo fija en 256. Con 32 B por hash son 8 KiB de cuerpo: la petición sigue siendo diminuta
/// y el receptor sabe de antemano cuánto va a servir.
pub const MAX_HASHES_POR_PETICION: usize = 256;

/// Peers salientes: los que **elegimos** nosotros.
pub const MAX_PEERS_SALIENTES: u32 = 24;

/// Peers entrantes: los que nos eligen a nosotros.
pub const MAX_PEERS_ENTRANTES: u32 = 72;

/// Conexiones establecidas simultáneas, en total.
pub const MAX_CONEXIONES: u32 = MAX_PEERS_SALIENTES + MAX_PEERS_ENTRANTES;

/// Conexiones establecidas con un **mismo** peer.
pub const MAX_CONEXIONES_POR_PEER: u32 = 1;

/// Conexiones entrantes a medio negociar (defensa contra *slowloris*).
pub const MAX_CONEXIONES_PENDIENTES: u32 = 32;

/// Peticiones de sincronización simultáneas que se aceptan de **un mismo peer**.
///
/// El default de `request_response::Config` son **100**. Con respuestas de hasta
/// [`MAX_RESPUESTA_BYTES`], eso serían decenas de gigabytes por peer. Bajarlo a 8 es la mitad de la
/// mitigación; la otra mitad es el presupuesto agregado de [`crate::presupuesto`].
pub const MAX_STREAMS_SYNC: usize = 8;

/// Plazo, en segundos, para que llegue el veredicto de una validación diferida
/// (`ORDEN-W06d2` decisión 1) antes de tratarla como [`crate::entrante::Veredicto::Ignorar`].
///
/// Un bloque PoST real verifica en decenas de milisegundos (PoT + PoAS); 5 s es generoso incluso
/// bajo carga y sigue acotando cuánto tiempo puede quedar un mensaje de gossipsub retenido sin
/// reenviarse ni descartarse.
pub const PLAZO_VALIDACION_DIFERIDA_S: u64 = 5;

/// Cuántas validaciones diferidas puede tener pendientes `zx-p2p` a la vez.
///
/// Acota la memoria de la tabla de pendientes (`ORDEN-W06d2`, disciplina de recursos de `LINEO`):
/// un manejador que difiere sin nunca informar no debe crecer sin límite entre barridos del plazo.
/// Al llegar al tope, la entrada más antigua se expira como `Ignorar` para dejar sitio.
pub const MAX_DIFERIDOS_PENDIENTES: usize = 4_096;

// ── Coherencia de los límites ────────────────────────────────────────────────
// Aserciones de compilación y no tests: una relación entre constantes no se puede saltar con
// `--skip`, y un cambio que rompa la coherencia MUST impedir compilar.

// El techo de gossip cubre el bloque máximo completo.
const _: () = assert!(
    MAX_GOSSIP_BYTES as u64 >= MAX_BLOQUE_RED_BYTES,
    "C-NET-11: el techo de gossip debe admitir un bloque completo"
);

// El techo de gossip supera el default de libp2p, o no estaríamos arreglando nada.
const _: () = assert!(
    MAX_GOSSIP_BYTES > 65_536,
    "C-NET-11: el default de libp2p es 65536 y es demasiado pequeño"
);

// El margen del arranque dev MUST ser suficiente, o el nodo no arrancaría nunca.
const _: () = assert!(margen_suficiente(LIMITE_BLOQUE_DEV, MAX_GOSSIP_BYTES));

// Una respuesta de sincronización carga varios bloques: MUST ser mayor que un mensaje suelto.
const _: () = assert!(MAX_RESPUESTA_BYTES > MAX_GOSSIP_BYTES as u64);

// Una petición es un locator, no un lote: MUST ser mucho menor que una respuesta.
const _: () = assert!(MAX_PETICION_BYTES * 100 < MAX_RESPUESTA_BYTES);

// Un lote lleno de cabeceras PoW cabe en una respuesta.
const _: () = assert!(
    (MAX_CABECERAS_POR_RESPUESTA * TAMANO_CABECERA) as u64 <= MAX_RESPUESTA_BYTES,
    "un lote de cabeceras al máximo MUST caber en una respuesta"
);

// Un lote lleno de hashes cabe en una petición (32 B por hash + discriminante + CompactSize).
const _: () = assert!(
    1 + 9 + (MAX_HASHES_POR_PETICION * 32) as u64 <= MAX_PETICION_BYTES,
    "una petición con el máximo de hashes MUST caber en MAX_PETICION_BYTES"
);

// Coherencia de los límites de conexión.
const _: () = assert!(MAX_CONEXIONES == MAX_PEERS_SALIENTES + MAX_PEERS_ENTRANTES);
const _: () = assert!(
    MAX_PEERS_ENTRANTES > MAX_PEERS_SALIENTES,
    "trade-off asumido: aceptamos más peers de los que elegimos"
);
const _: () = assert!(MAX_PEERS_SALIENTES > 0 && MAX_CONEXIONES_POR_PEER == 1);

#[cfg(test)]
#[expect(
    clippy::integer_division,
    reason = "aritmética entera deliberada: modelar el crecimiento con enteros evita floats"
)]
mod tests {
    use super::{
        FACTOR_MARGEN, LIMITE_BLOQUE_ABSURDO, LIMITE_BLOQUE_DEV, MARGEN_MINIMO,
        MAX_BLOQUE_RED_BYTES, MAX_CABECERAS_POR_RESPUESTA, MAX_CUERPO_DEV_BYTES, MAX_GOSSIP_BYTES,
        MAX_HASHES_POR_PETICION, MAX_PETICION_BYTES, MAX_RESPUESTA_BYTES, limite_gossip,
        margen_suficiente,
    };
    use zx_core::preimage::block::TAMANO_CABECERA;
    use zx_core::preimage::dag::TAMANO_CABECERA_MAX;
    use zx_core::wire_dag::MAX_JUSTIFICACION_POT_CODIFICADA;

    /// El límite de `BloqueRed` se **deriva** de la cabecera PoST máxima, la justificación PoT
    /// codificada al máximo y el cuerpo dev declarado (`ORDEN-W06d3` decisión 1).
    #[test]
    fn el_limite_de_bloque_red_se_deriva() {
        assert_eq!(TAMANO_CABECERA_MAX, 1_037, "la cabecera PoST máxima");
        assert_eq!(MAX_JUSTIFICACION_POT_CODIFICADA, 19_201);
        assert_eq!(MAX_CUERPO_DEV_BYTES, 2 * 1024 * 1024);
        assert_eq!(
            MAX_BLOQUE_RED_BYTES,
            1_037 + 19_201 + 2 * 1024 * 1024,
            "cabecera + justificación PoT + cuerpo"
        );
        assert_eq!(LIMITE_BLOQUE_DEV, MAX_BLOQUE_RED_BYTES);
    }

    /// **C-NET-13.** Cuando el margen se agota, el nodo debe **negarse**, no seguir a medias.
    #[test]
    fn sin_margen_suficiente_se_detecta() {
        let techo = MAX_GOSSIP_BYTES;

        let borde = techo as u64 / MARGEN_MINIMO;
        assert!(margen_suficiente(borde, techo), "el borde exacto vale");
        assert!(
            !margen_suficiente(borde + 1, techo),
            "un byte más allá del borde MUST detectarse"
        );

        assert!(!margen_suficiente(u64::MAX, techo));
        assert_eq!(
            limite_gossip(u64::MAX),
            None,
            "absurdo ⇒ sin techo, no techo infinito"
        );
        assert_eq!(limite_gossip(LIMITE_BLOQUE_ABSURDO + 1), None);
        assert_eq!(
            limite_gossip(0),
            None,
            "un límite de cero también es absurdo"
        );
        assert!(limite_gossip(LIMITE_BLOQUE_ABSURDO).is_some());
    }

    /// El techo de gossip cubre el bloque máximo con el margen pactado.
    #[test]
    fn el_limite_de_gossip_admite_bloques_reales() {
        assert_eq!(
            MAX_GOSSIP_BYTES as u64,
            MAX_BLOQUE_RED_BYTES * FACTOR_MARGEN
        );
        assert!(MAX_GOSSIP_BYTES as u64 >= MAX_BLOQUE_RED_BYTES);
    }

    /// Un lote lleno de cabeceras cabe en la respuesta.
    #[test]
    fn un_lote_lleno_de_cabeceras_cabe_en_una_respuesta() {
        let lote = (MAX_CABECERAS_POR_RESPUESTA * TAMANO_CABECERA) as u64;
        assert!(lote <= MAX_RESPUESTA_BYTES);
    }

    /// Un lote lleno de hashes cabe en la petición.
    #[test]
    fn un_lote_lleno_de_hashes_cabe_en_una_peticion() {
        let lote = 1 + 9 + (MAX_HASHES_POR_PETICION * 32) as u64;
        assert!(lote <= MAX_PETICION_BYTES, "{lote} B");
        assert_eq!(MAX_HASHES_POR_PETICION, 256);
    }

    /// Un lote lleno de bloques al máximo cabe en una respuesta.
    #[test]
    fn un_lote_lleno_de_bloques_cabe_en_una_respuesta() {
        let lote = super::MAX_BLOQUES_POR_RESPUESTA as u64 * MAX_BLOQUE_RED_BYTES;
        assert!(lote <= MAX_RESPUESTA_BYTES);
    }
}
