//! Límites explícitos de la capa de red (SPEC §16.3, C-NET-11).
//!
//! # Por qué existe este módulo
//!
//! **La capa de transporte de libp2p no es segura por defecto para una cadena**, y lo peor es que
//! ninguno de sus defectos falla al compilar. Cuatro defaults, verificados contra
//! `rust-libp2p@v0.56.0` (ver `research/libp2p-arquitectura.md` §0 y §3):
//!
//! | Límite | Default | Qué provoca en ZEROX |
//! |---|---|---|
//! | `gossipsub::max_transmit_size` | **65 536 B** | Un bloque típico mide 100-200 KB: **ninguno se propaga** |
//! | `gossipsub::validate_messages` | **`false`** | El mensaje se reenvía **antes** de validarlo |
//! | `ConnectionLimits` | todo `None` | Sin límite de conexiones |
//! | Tamaño en `request_response::Codec` | **no existe** | El trait no impone ninguno |
//!
//! Reunirlos aquí, con nombre y con la razón al lado, es lo que impide que alguien "simplifique"
//! uno de ellos más adelante sin saber qué está quitando.

/// Margen sobre el tamaño de consenso, para cabecera, sobres y crecimiento de la mediana.
///
/// El tamaño de bloque de ZEROX es **dinámico** (§6.5): la zona libre es un suelo, no un techo, y
/// la mediana larga puede crecer con los años. Un límite de transporte ajustado al tamaño de hoy
/// se convierte en una partición de red silenciosa el día que los bloques crezcan — los nodos
/// nuevos aceptarían bloques que los viejos rechazan por tamaño de mensaje.
pub const FACTOR_MARGEN: u64 = 8;

/// Zona libre de consenso, en unidades de peso (§6.5).
///
/// **Se declara aquí y no se importa de `zx-consensus` a propósito**: este crate no depende de
/// consenso —ver el diagrama en `lib.rs`—, así que la copia se mantiene sincronizada por un test
/// (`el_limite_de_gossip_se_deriva_de_la_zona_libre_de_consenso`) que sí lo importa como
/// dev-dependency. Si alguien cambia `ZONA_LIBRE` en consenso, ese test falla.
const ZONA_LIBRE_CONSENSO: u64 = 100_000;

/// Tamaño máximo de un mensaje de gossipsub, en bytes.
///
/// **MUST** fijarse explícitamente: el default de 64 KiB es menor que un bloque típico.
pub const MAX_GOSSIP_BYTES: usize = (ZONA_LIBRE_CONSENSO * FACTOR_MARGEN) as usize;

/// Tamaño máximo de una **petición** de sincronización, en bytes.
///
/// Una petición es un locator: unos pocos cientos de hashes de 32 bytes como mucho. Que sea
/// pequeño es la primera línea de defensa — no hay razón legítima para una petición grande.
pub const MAX_PETICION_BYTES: u64 = 64 * 1024;

/// Tamaño máximo de una **respuesta** de sincronización, en bytes.
///
/// Una respuesta puede traer un lote de bloques, así que es el límite grande del crate. Aun así
/// está acotado: sin él, un peer puede hacer que reservemos memoria arbitraria **antes** de que el
/// parser tenga oportunidad de rechazar nada.
pub const MAX_RESPUESTA_BYTES: u64 = MAX_GOSSIP_BYTES as u64 * 16;

/// Cabeceras por respuesta de `Headers`.
///
/// A 112 bytes por cabecera son ~224 KB por respuesta llena. Bitcoin usa 2000 y zcashd 160 —este
/// último por el tamaño de las soluciones Equihash, que ZEROX no tiene.
pub const MAX_CABECERAS_POR_RESPUESTA: usize = 2_000;

/// Bloques por respuesta de `Blocks`.
pub const MAX_BLOQUES_POR_RESPUESTA: usize = 16;

/// Peers salientes: los que **elegimos** nosotros.
pub const MAX_PEERS_SALIENTES: u32 = 24;

/// Peers entrantes: los que nos eligen a nosotros.
///
/// Mayor que el de salientes **a propósito**, y es un compromiso incómodo que conviene tener
/// escrito: aceptar más entrantes hace la red más útil para los demás, pero significa que la
/// mayoría de nuestros peers pueden ser peers que no elegimos. Zebra documenta exactamente el mismo
/// trade-off con un multiplicador de 5 (`zebra-network/src/constants.rs:64-81`).
pub const MAX_PEERS_ENTRANTES: u32 = 72;

/// Conexiones establecidas simultáneas, en total.
pub const MAX_CONEXIONES: u32 = MAX_PEERS_SALIENTES + MAX_PEERS_ENTRANTES;

/// Conexiones establecidas con un **mismo** peer.
///
/// Una basta. Permitir varias multiplica por N lo que un solo peer puede consumir.
pub const MAX_CONEXIONES_POR_PEER: u32 = 1;

/// Conexiones entrantes a medio negociar.
///
/// Es la defensa contra *slowloris*: abrir conexiones y no terminar nunca el handshake.
pub const MAX_CONEXIONES_PENDIENTES: u32 = 32;

/// Peers en modo de **alto ancho de banda** para el relé compacto (C-NET-10).
///
/// Literal de BIP 152: *"Nodes MUST NOT send such sendcmpct messages to more than three peers, as
/// it encourages wasting outbound bandwidth across the network."*
pub const MAX_PEERS_ALTO_ANCHO_BANDA: usize = 3;

// El límite de gossip MUST superar cualquier transacción individual: si una tx que el consenso
// acepta no cupiera en un mensaje, sería invalidez de facto impuesta por el transporte.
// (`MAX_TX_WEIGHT == ZONA_LIBRE` en consenso; el test lo verifica contra el crate real.)
const _: () = assert!(
    MAX_GOSSIP_BYTES as u64 > ZONA_LIBRE_CONSENSO,
    "C-NET-11: el límite de gossip debe superar el peso máximo de una tx, o el transporte \
     censuraría transacciones válidas"
);

// Y MUST superar el default de libp2p, o no estaríamos arreglando nada.
const _: () = assert!(
    MAX_GOSSIP_BYTES > 65_536,
    "C-NET-11: el default de libp2p es 65536 y es demasiado pequeño para un bloque de ZEROX"
);

// Una respuesta de sincronización carga varios bloques: MUST ser mayor que un mensaje suelto.
const _: () = assert!(MAX_RESPUESTA_BYTES > MAX_GOSSIP_BYTES as u64);

// Una petición es un locator, no un lote: MUST ser mucho menor que una respuesta.
const _: () = assert!(MAX_PETICION_BYTES * 100 < MAX_RESPUESTA_BYTES);

// Coherencia de los límites de conexión. Son constantes, así que van aquí y no en un test: una
// aserción de compilación no se puede saltar con `--skip`.
const _: () = assert!(MAX_CONEXIONES == MAX_PEERS_SALIENTES + MAX_PEERS_ENTRANTES);
const _: () = assert!(
    MAX_PEERS_ENTRANTES > MAX_PEERS_SALIENTES,
    "trade-off asumido: aceptamos más peers de los que elegimos"
);
const _: () = assert!(MAX_PEERS_SALIENTES > 0 && MAX_CONEXIONES_POR_PEER == 1);
const _: () = assert!(
    MAX_PEERS_ALTO_ANCHO_BANDA < MAX_PEERS_SALIENTES as usize,
    "C-NET-10: no se puede tener más peers de alto ancho de banda que peers salientes"
);

#[cfg(test)]
mod tests {
    use super::{
        MAX_BLOQUES_POR_RESPUESTA, MAX_CABECERAS_POR_RESPUESTA, MAX_GOSSIP_BYTES,
        MAX_PEERS_ALTO_ANCHO_BANDA, MAX_RESPUESTA_BYTES,
    };
    use zx_consensus::peso::{MAX_TX_WEIGHT, ZONA_LIBRE};
    use zx_core::preimage::block::TAMANO_CABECERA;

    /// **C-NET-11.** El límite de gossip supera un bloque típico con margen de sobra.
    ///
    /// Este test es el que habría cazado el default de 64 KiB. Un bloque en la zona libre mide
    /// 100 KB, así que con el default **no se habría propagado ni uno solo**, sin error visible.
    #[test]
    fn el_limite_de_gossip_admite_bloques_reales() {
        assert_eq!(MAX_GOSSIP_BYTES, 800_000, "8× la zona libre");
    }

    /// **La copia local de `ZONA_LIBRE` sigue coincidiendo con la de consenso.**
    ///
    /// `zx-p2p` **no depende** de `zx-consensus` (solo en dev, para este test): así el código de red
    /// no puede llamar a consenso ni por accidente. El precio es una constante duplicada, y este
    /// test es lo que la mantiene honesta — si alguien cambia `ZONA_LIBRE` en consenso, falla aquí
    /// y no en producción.
    #[test]
    fn el_limite_de_gossip_se_deriva_de_la_zona_libre_de_consenso() {
        assert_eq!(
            super::ZONA_LIBRE_CONSENSO,
            ZONA_LIBRE,
            "la copia local de ZONA_LIBRE se ha desincronizado de zx-consensus"
        );
        assert_eq!(MAX_GOSSIP_BYTES as u64, ZONA_LIBRE * super::FACTOR_MARGEN);
        assert!(
            MAX_GOSSIP_BYTES as u64 > MAX_TX_WEIGHT,
            "una tx que el consenso acepta MUST caber en un mensaje"
        );
    }

    /// Un lote lleno de cabeceras **MUST** caber en el límite de respuesta.
    ///
    /// Sin esta comprobación, los dos límites podrían fijarse por separado y dejar un lote máximo
    /// que nunca se puede entregar: el nodo pediría algo que su propio transporte rechaza.
    #[test]
    fn un_lote_lleno_de_cabeceras_cabe_en_una_respuesta() {
        let lote = (MAX_CABECERAS_POR_RESPUESTA * TAMANO_CABECERA) as u64;
        assert!(
            lote < MAX_RESPUESTA_BYTES,
            "{MAX_CABECERAS_POR_RESPUESTA} cabeceras son {lote} B y el techo es \
             {MAX_RESPUESTA_BYTES} B"
        );
    }

    /// Y un lote lleno de bloques también, contando cada uno en la zona libre.
    #[test]
    fn un_lote_lleno_de_bloques_cabe_en_una_respuesta() {
        let lote = MAX_BLOQUES_POR_RESPUESTA as u64 * ZONA_LIBRE;
        assert!(
            lote <= MAX_RESPUESTA_BYTES,
            "{MAX_BLOQUES_POR_RESPUESTA} bloques de {ZONA_LIBRE} B son {lote} B y el techo es \
             {MAX_RESPUESTA_BYTES} B"
        );
    }

    /// **C-NET-10, BIP 152.** Tres, y el BIP lo dice con MUST NOT.
    ///
    /// La coherencia con los demás límites está en aserciones de compilación, arriba. Aquí solo se
    /// fija el número, que es el que cita el BIP literalmente.
    #[test]
    fn el_modo_de_alto_ancho_de_banda_esta_limitado_a_tres() {
        assert_eq!(
            MAX_PEERS_ALTO_ANCHO_BANDA, 3,
            "BIP 152: MUST NOT send such sendcmpct messages to more than three peers"
        );
    }
}
