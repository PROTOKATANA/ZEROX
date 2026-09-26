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
//! `Cargo.toml` de este crate no menciona `zx-consensus` — lo comprueba `ci/frontera-crates.sh`.
//!
//! # Los veredictos son cuatro, no tres (`ORDEN-W06d2`)
//!
//! Un bloque cuyo padre todavía no conocemos **no es un bloque inválido**: es un bloque que llegó
//! antes de tiempo. Distinguirlo importa: en gossipsub es literalmente la diferencia entre
//! `MessageAcceptance::Ignore` y `::Reject` — solo el segundo aplica la penalización. Castigar a
//! quien nos adelanta un bloque penaliza a peers honestos con otro *timing*.
//!
//! # Por qué existe [`Veredicto::Diferir`]
//!
//! Un bloque PoST real tarda del orden de decenas de milisegundos en verificarse (PoT + PoAS). Si
//! [`ManejadorEntrante::bloque_difundido`] se queda ahí dentro, el bucle de `zx-p2p` — que también
//! pollea el `Swarm` — deja de hacerlo mientras tanto, y la red entera se para. `Diferir` deja que
//! el manejador conteste **de inmediato** "todavía no lo sé" y siga la validación de verdad en su
//! propio hilo; cuando termine, informa el veredicto final con
//! [`crate::servicio::ManejoRed::informar_validacion`] (o su variante bloqueante para un hilo que no
//! es `tokio`), usando el mismo [`IdDiferido`] que recibió aquí. `zx-p2p` retiene el mensaje de
//! gossipsub entre tanto (`report_message_validation_result` no se llama hasta entonces) y, si el
//! informe no llega dentro de un plazo declarado, lo trata como `Ignorar` — nunca como `Rechazar`:
//! un manejador lento o caído no es un peer culpable.

use zx_core::digest::BlockHash;
use zx_core::preimage::block::BlockHeader;

use crate::mensaje::{BloqueRed, Estado};

/// Identificador opaco de una validación diferida.
///
/// Lo asigna `zx-p2p` **antes** de llamar a [`ManejadorEntrante::bloque_difundido`] y no significa
/// nada fuera del crate: el manejador solo lo guarda y lo devuelve tal cual con
/// [`crate::servicio::ManejoRed::informar_validacion`]. El campo es `pub(crate)` para que los tests
/// de este crate puedan construirlo directamente; fuera de aquí es opaco (no hay forma pública de
/// leer su valor). `Default` existe **solo** para que un manejador de otro crate pueda escribir un
/// test unitario de su propio `bloque_difundido` sin depender de un `Swarm` real; el valor que
/// produce no tiene ningún significado de protocolo y nunca coincide con uno de producción salvo
/// por casualidad de conteo.
#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug, Default)]
pub struct IdDiferido(pub(crate) u64);

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
    /// **Todavía no se sabe.** La validación de verdad sigue en otro hilo; el resultado llegará
    /// después por [`crate::servicio::ManejoRed::informar_validacion`] con el mismo [`IdDiferido`]
    /// que trajo la llamada a [`ManejadorEntrante::bloque_difundido`]. `zx-p2p` retiene el mensaje.
    Diferir,
}

/// El veredicto final de una validación que se difirió. No incluye `Diferir`: una validación
/// diferida no puede volver a diferirse indefinidamente sin que alguien acabe decidiendo.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum VeredictoFinal {
    /// Válido. Se retransmite a la malla.
    Aceptar,
    /// No juzgable (p. ej. quedó huérfano, o llegó duplicado mientras se validaba). No penaliza.
    Ignorar,
    /// Inválido de forma demostrable. Penaliza a quien lo propagó.
    Rechazar,
}

/// Lo que `zx-p2p` necesita del resto del nodo.
///
/// Implementarlo es trabajo de `zx-node`. Cada método debe ser **rápido y no bloqueante**: se
/// llaman desde el bucle de eventos, y mientras uno corre el `Swarm` no se pollea — o sea, la red
/// entera está parada. Lo que tarde debe delegarse a otra tarea y devolver [`Veredicto::Diferir`].
pub trait ManejadorEntrante: Send + Sync + 'static {
    /// Nuestro estado, para responder a un saludo.
    fn estado(&self) -> Estado;

    /// Un bloque llegó por difusión. **Se valida antes de retransmitir.**
    ///
    /// `id` es el identificador opaco a devolver más tarde si el veredicto es
    /// [`Veredicto::Diferir`]. El default de este trait no existe: cada implementación decide. El
    /// veredicto es del manejador, no del códec.
    fn bloque_difundido(&self, id: IdDiferido, bloque: &BloqueRed) -> Veredicto;

    /// Una transacción llegó por difusión.
    ///
    /// En 0.0.1 **no hay tema de transacciones**: las txs viajan dentro de los bloques. El método se
    /// conserva como parte de la interfaz portada para cuando exista ese canal.
    fn tx_difundida(&self, tx_serializada: &[u8]) -> Veredicto;

    /// Un peer pide cabeceras PoW desde el primer hash de su locator que reconozcamos.
    ///
    /// Devolver un vector vacío es una respuesta legítima: significa "no reconozco nada de tu
    /// locator", y quien lo recibe debe entenderlo como que no compartimos historia.
    fn cabeceras_desde(&self, locator: &[BlockHash], hasta: Option<BlockHash>) -> Vec<BlockHeader>;

    /// Un peer pide cuerpos de bloque (PoW o PoST). Los que no tengamos simplemente no van en la
    /// respuesta.
    fn bloques_por_hash(&self, hashes: &[BlockHash]) -> Vec<BloqueRed>;
}
