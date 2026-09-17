//! El trait que rompe el ciclo red↔consenso.
//!
//! # El problema
//!
//! La red necesita **validar** lo que recibe, y validar es consenso. El sincronizador necesita
//! **pedir** bloques, y pedir es red. Se necesitan en las dos direcciones, y un ciclo de
//! dependencias entre crates no compila.
//!
//! # La solución, y por qué esta y no otra
//!
//! `zx-p2p` **define** este trait y **no lo implementa**. Lo implementa `zx-node`, que es el único
//! crate que ve la red y el consenso a la vez. Así el ciclo se rompe donde debe romperse, y el
//! `Cargo.toml` de este crate no menciona `zx-consensus` — un job de CI lo comprueba.
//!
//! Es el reparto de `zebra-network` (cuya única dependencia interna es `zebra-chain`, tipos puros)
//! frente a `zebrad`, y de `lighthouse_network` frente a `beacon_node/network`.
//!
//! # Los veredictos son tres, no dos
//!
//! Y esa es la parte que importa. Un bloque cuyo padre todavía no conocemos **no es un bloque
//! inválido**: es un bloque que llegó antes de tiempo. Distinguirlo es C-NET-12, y en gossipsub es
//! literalmente la diferencia entre `MessageAcceptance::Ignore` y `::Reject` — solo el segundo
//! aplica la penalización P₄. Castigar a quien nos adelanta un bloque penaliza a peers honestos con
//! otro *timing*.

use zx_core::digest::BlockHash;
use zx_core::preimage::block::BlockHeader;
use zx_core::tx::Tx;

use crate::mensaje::{BloqueRed, Estado};

/// Qué hacer con algo que llegó por difusión.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Veredicto {
    /// Válido. Se retransmite a la malla.
    Aceptar,
    /// **No se puede juzgar todavía** — típicamente, un bloque cuyo padre no conocemos, o algo que
    /// ya teníamos. Se descarta **sin penalizar**.
    Ignorar,
    /// Inválido de forma demostrable. Se descarta **y** se penaliza al que lo propagó.
    Rechazar,
}

/// Lo que `zx-p2p` necesita del resto del nodo.
///
/// Implementarlo es trabajo de `zx-node`. Cada método debe ser **rápido y no bloqueante**: se
/// llaman desde el bucle de eventos, y mientras uno corre el `Swarm` no se pollea — o sea, la red
/// entera está parada. Lo que tarde debe delegarse a otra tarea.
pub trait ManejadorEntrante: Send + Sync + 'static {
    /// Nuestro estado, para responder a un saludo.
    fn estado(&self) -> Estado;

    /// Un bloque llegó por difusión. **Se valida antes de retransmitir** (C-NET-12).
    fn bloque_difundido(&self, bloque: &BloqueRed) -> Veredicto;

    /// Una transacción llegó por difusión.
    fn tx_difundida(&self, tx_serializada: &[u8]) -> Veredicto;

    /// Un peer pide cabeceras desde el primer hash de su locator que reconozcamos.
    ///
    /// Devolver un vector vacío es una respuesta legítima: significa "no reconozco nada de tu
    /// locator", y quien lo recibe debe entenderlo como que no compartimos historia.
    fn cabeceras_desde(&self, locator: &[BlockHash], hasta: Option<BlockHash>) -> Vec<BlockHeader>;

    /// Un peer pide cuerpos de bloque. Los que no tengamos simplemente no van en la respuesta.
    fn bloques_por_hash(&self, hashes: &[BlockHash]) -> Vec<BloqueRed>;

    /// **Relé compacto.** Las transacciones completas de un bloque anunciado, en el orden de los
    /// índices pedidos.
    ///
    /// Implementación por defecto **vacía**: `zx-node` todavía no sirve el relé, y devolver vacío
    /// equivale a `NoDisponible`, que no puntúa (C-NET-05). Cablear esto de verdad es trabajo del
    /// nodo, no de este crate.
    fn transacciones_compactas(
        &self,
        _bloque: &BlockHash,
        _indices: &[u32],
    ) -> Vec<(Tx, Vec<Vec<u8>>)> {
        Vec::new()
    }
}
