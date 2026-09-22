//! Dispositivo de durabilidad: puntos de aborto en un **proceso hijo**.
//!
//! Un test que diga «mate el proceso entre la escritura y la firma» y no mate nada no prueba la
//! durabilidad. Matarlo de verdad sin instrumentar la biblioteca exige un proceso que llame al API
//! pública y se suicide en un punto conocido. Ese proceso es el mismo binario de test re-ejecutado
//! con `FIRMANTE_PUNTO_DE_ABORTO` puesta.
//!
//! [`std::process::abort`] no ejecuta destructores, no vacía búferes de biblioteca y no sincroniza
//! nada. Si la entrada sobrevive al `SIGABRT` (señal 6), es porque el `fsync` del punto 3 de la
//! regla ya había ocurrido **antes**.
//!
//! # El riesgo de un dispositivo de aborto, y cómo se acota
//!
//! Una variable de entorno heredada por accidente mataría un nodo real. Por eso el dispositivo
//! **solo** se dispara desde `firmante_seguro::aborto`, que en producción no llama nadie: el flujo
//! normal ([`crate::firmante::Firmante::firmar`]) no lo consulta. La variable no puede hacer que un
//! nodo real aborte por el mero hecho de estar puesta.

/// Variable de entorno que arma el dispositivo.
pub const VAR: &str = "FIRMANTE_PUNTO_DE_ABORTO";

/// Punto del camino en el que suicidarse.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Punto {
    /// Persistir la entrada (con `fsync`) y abortar **sin** firmar. En producción este punto cae
    /// entre el `return` de [`crate::registro::Registro::resolver`] y la escritura del sello.
    TrasPersistir,
    /// Abortar antes de escribir nada. Es el **control negativo**: la entrada que el otro punto
    /// deja escrita no puede venir de aquí.
    SinPersistir,
}

/// El punto pedido por el entorno, si lo hay.
#[must_use]
pub fn punto() -> Option<Punto> {
    match std::env::var(VAR).ok()?.as_str() {
        "tras-persistir" => Some(Punto::TrasPersistir),
        "sin-persistir" => Some(Punto::SinPersistir),
        _ => None,
    }
}

/// Aborta el proceso sin ejecutar destructores.
pub fn abortar() -> ! {
    std::process::abort()
}

/// Dispara el punto pedido, si lo hay.
///
/// Con [`Punto::TrasPersistir`] persiste `(identidad, pre_hash)` por el camino real —escritura más
/// `fsync` de [`crate::registro::Registro::resolver`]— y aborta. Con [`Punto::SinPersistir`] aborta
/// sin tocar el registro. Sin punto armado no hace nada y devuelve `false`.
pub fn aborto_si_procede(
    registro: &crate::registro::Registro,
    identidad: &impl crate::identidad::IdentidadOportunidad,
    pre_hash: zx_core::PreHash,
) -> bool {
    match punto() {
        Some(Punto::TrasPersistir) => {
            // Camino real: `resolver` escribe y sincroniza. No se inspecciona el resultado a
            // propósito: el punto de aborto está después del `fsync`, salga lo que salga.
            let _ = registro.resolver(identidad, pre_hash);
            abortar()
        }
        Some(Punto::SinPersistir) => abortar(),
        None => false,
    }
}
