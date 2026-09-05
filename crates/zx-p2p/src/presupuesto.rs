//! Presupuesto **agregado** de memoria en vuelo (SPEC §16.3, C-NET-21).
//!
//! # Lo que el `.take(MAX)` por petición no cubre
//!
//! Cada lectura del códec está acotada: nadie puede hacer que una sola respuesta reserve más de
//! `MAX_RESPUESTA_BYTES`. Eso está bien y no basta, porque **el límite por petición no acota el
//! producto**:
//!
//! ```text
//! MAX_RESPUESTA_BYTES (25,6 MB) × MAX_STREAMS_SYNC (8) × MAX_PEERS_ENTRANTES (72) = 14,7 GB
//! ```
//!
//! Bajar `MAX_STREAMS_SYNC` de 100 a 8 quitó un orden de magnitud y dejó el problema. Casi quince
//! gigabytes reservables por peticiones que un atacante emite gratis siguen siendo un OOM.
//!
//! ⚠️ **Ese 14,7 empezó siendo 7,2 en estos comentarios, y estaba mal.** El arreglo de C-NET-13
//! dobló `MAX_GOSSIP_BYTES` —pasó de derivarse de `ZONA_LIBRE` a derivarse de `LIMITE_BLOQUE_GENESIS`,
//! que es el doble— y los comentarios que narraban la aritmética se quedaron con el número viejo.
//! Tercera vez que este proyecto escribe a mano un número que es función de una constante. Por eso
//! ahora hay un test que **deriva** las cifras en vez de repetirlas.
//!
//! # Por qué un contador global y no más límites por peer
//!
//! Porque el recurso que se agota es **global**. Repartirlo por peer significa elegir entre dos
//! males: o el reparto es generoso y la suma sigue sin acotar, o es estrecho y un nodo con muchos
//! peers honestos se estrangula a sí mismo.
//!
//! Un presupuesto compartido no tiene ese problema: **el techo es el techo**, y quien llega tarde
//! espera o se le dice que no. Es como funciona cualquier reserva de recursos que de verdad acote.
//!
//! # La reserva se libera sola
//!
//! [`Reserva`] devuelve lo suyo al soltarse — incluido si quien la tenía entra en pánico o el
//! futuro se cancela a mitad. Un contador que hubiera que decrementar a mano tendría una fuga por
//! cada camino de error que alguien olvidara, y **una fuga en un contador de presupuesto es un DoS
//! diferido**: el nodo deja de aceptar peticiones sin que nada esté pasando.

use std::sync::Arc;
use std::sync::atomic::{AtomicUsize, Ordering};

/// Techo de bytes reservados a la vez por peticiones de red en vuelo.
///
/// **256 MiB.** No sale de una medición sino de un razonamiento de orden de magnitud: es holgado
/// para un nodo sirviendo a decenas de peers a la vez —cada respuesta llena de cabeceras son
/// ~184 KB, así que caben más de mil simultáneas— y sigue siendo un techo que un servidor modesto
/// puede permitirse sin morir.
///
/// 🔶 Revisable con medición real cuando exista la testnet pública (P-019).
pub const PRESUPUESTO_BYTES: usize = 256 * 1024 * 1024;

/// Contador compartido de bytes en vuelo.
#[derive(Clone, Debug)]
pub struct Presupuesto {
    en_vuelo: Arc<AtomicUsize>,
    techo: usize,
}

impl Default for Presupuesto {
    fn default() -> Self {
        Self::nuevo(PRESUPUESTO_BYTES)
    }
}

impl Presupuesto {
    /// Uno con el techo dado.
    #[must_use]
    pub fn nuevo(techo: usize) -> Self {
        Self {
            en_vuelo: Arc::new(AtomicUsize::new(0)),
            techo,
        }
    }

    /// Intenta reservar `bytes`. Devuelve `None` si no caben.
    ///
    /// Usa `fetch_update`, no un `load` seguido de un `store`: entre esos dos, otro hilo puede
    /// reservar y el techo se supera. Con la operación atómica de comparar-e-intercambiar, dos
    /// reservas concurrentes **no pueden** pasar las dos.
    #[must_use]
    pub fn reservar(&self, bytes: usize) -> Option<Reserva> {
        let techo = self.techo;
        self.en_vuelo
            .fetch_update(Ordering::AcqRel, Ordering::Acquire, |actual| {
                let nuevo = actual.checked_add(bytes)?;
                (nuevo <= techo).then_some(nuevo)
            })
            .ok()?;

        Some(Reserva {
            contador: Arc::clone(&self.en_vuelo),
            bytes,
        })
    }

    /// Bytes reservados ahora mismo.
    #[must_use]
    pub fn en_vuelo(&self) -> usize {
        self.en_vuelo.load(Ordering::Acquire)
    }

    /// Cuánto queda libre.
    #[must_use]
    pub fn disponible(&self) -> usize {
        self.techo.saturating_sub(self.en_vuelo())
    }
}

/// Bytes reservados. **Se devuelven al soltarse.**
///
/// No hay forma de olvidarse de liberar: no existe un método para hacerlo, así que el único camino
/// es el `Drop`. Un contador que hubiera que decrementar a mano tendría una fuga por cada `return`
/// temprano que alguien no viera.
#[derive(Debug)]
pub struct Reserva {
    contador: Arc<AtomicUsize>,
    bytes: usize,
}

impl Reserva {
    /// Cuántos bytes tiene reservados.
    #[must_use]
    pub const fn bytes(&self) -> usize {
        self.bytes
    }
}

impl Drop for Reserva {
    fn drop(&mut self) {
        // `fetch_sub` sobre lo que esta reserva puso: no puede bajar de cero porque solo se
        // devuelve lo que se reservó, y la reserva se creó sumando exactamente esto.
        self.contador.fetch_sub(self.bytes, Ordering::AcqRel);
    }
}

#[cfg(test)]
#[expect(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::integer_division,
    reason = "los tests fallan con panic por diseño; la división entera es deliberada"
)]
mod tests {
    use super::{PRESUPUESTO_BYTES, Presupuesto};

    #[test]
    fn una_reserva_ocupa_y_al_soltarse_libera() {
        let p = Presupuesto::nuevo(1_000);
        assert_eq!(p.en_vuelo(), 0);

        {
            let r = p.reservar(400).unwrap();
            assert_eq!(r.bytes(), 400);
            assert_eq!(p.en_vuelo(), 400);
            assert_eq!(p.disponible(), 600);
        }
        assert_eq!(p.en_vuelo(), 0, "al soltarse se devuelve");
    }

    /// **El techo es el techo.** Es la propiedad entera de este módulo.
    #[test]
    fn no_se_puede_pasar_del_techo() {
        let p = Presupuesto::nuevo(1_000);
        let _a = p.reservar(600).unwrap();
        let _b = p.reservar(400).unwrap();
        assert_eq!(p.en_vuelo(), 1_000);

        assert!(p.reservar(1).is_none(), "ni un byte más");
        assert!(p.reservar(usize::MAX).is_none());
    }

    /// El borde exacto entra; uno más, no.
    #[test]
    fn el_borde_exacto_del_techo() {
        let p = Presupuesto::nuevo(1_000);
        assert!(p.reservar(1_000).is_some(), "el techo justo entra");

        let p = Presupuesto::nuevo(1_000);
        assert!(p.reservar(1_001).is_none(), "uno más, no");
    }

    /// **Una reserva liberada deja sitio para otra.** Sin esto, el presupuesto se agotaría solo.
    #[test]
    fn liberar_deja_sitio() {
        let p = Presupuesto::nuevo(1_000);
        let a = p.reservar(1_000).unwrap();
        assert!(p.reservar(1).is_none());

        drop(a);
        assert!(p.reservar(1_000).is_some(), "el sitio vuelve");
    }

    /// **Una reserva soltada por un pánico también libera.**
    ///
    /// Es la razón de que sea un `Drop` y no un método: un camino de error que alguien olvide
    /// decrementar es una fuga, y una fuga en un contador de presupuesto es un DoS diferido — el
    /// nodo deja de aceptar peticiones sin que esté pasando nada.
    #[test]
    fn un_panico_tambien_libera() {
        let p = Presupuesto::nuevo(1_000);
        let p2 = p.clone();

        let h = std::thread::spawn(move || {
            let _r = p2.reservar(800).unwrap();
            #[expect(clippy::panic, reason = "el pánico es el objeto del test")]
            {
                panic!("soltando la reserva por la vía dolorosa");
            }
        });
        assert!(h.join().is_err(), "el hilo debía entrar en pánico");
        assert_eq!(p.en_vuelo(), 0, "el pánico también devuelve la reserva");
    }

    /// **Dos reservas concurrentes no pueden pasarse las dos del techo.**
    ///
    /// Con un `load` seguido de un `store`, entre ambos otro hilo reserva y el techo se supera. Por
    /// eso se usa `fetch_update`, que es comparar-e-intercambiar.
    #[test]
    fn la_concurrencia_no_puede_superar_el_techo() {
        use std::sync::Arc;
        use std::sync::atomic::{AtomicUsize, Ordering};

        let p = Presupuesto::nuevo(100_000);
        let concedidas = Arc::new(AtomicUsize::new(0));
        let mut hilos = Vec::new();

        // 64 hilos pidiendo 10 000 cada uno contra un techo de 100 000: como mucho 10 pueden
        // tenerlo a la vez.
        for _ in 0..64 {
            let p = p.clone();
            let c = Arc::clone(&concedidas);
            hilos.push(std::thread::spawn(move || {
                let mut mias = Vec::new();
                for _ in 0..20 {
                    if let Some(r) = p.reservar(10_000) {
                        c.fetch_add(1, Ordering::Relaxed);
                        mias.push(r);
                    }
                }
                // Se comprueba **con las reservas todavía vivas**: es cuando el invariante puede
                // romperse.
                assert!(
                    p.en_vuelo() <= 100_000,
                    "el techo se superó: {}",
                    p.en_vuelo()
                );
                mias
            }));
        }

        let mut todas = Vec::new();
        for h in hilos {
            todas.extend(h.join().expect("ningún hilo debe entrar en pánico"));
        }
        assert!(p.en_vuelo() <= 100_000);
        assert_eq!(todas.len() * 10_000, p.en_vuelo(), "la cuenta cuadra");

        drop(todas);
        assert_eq!(p.en_vuelo(), 0, "todo vuelve");
    }

    /// **El presupuesto acota el peor caso, y las cifras se DERIVAN.**
    ///
    /// Este test existe por un fallo concreto: los comentarios de este módulo decían 12,8 MB y
    /// 7,2 GB, y los valores reales son **25,6 MB y 14,7 GB**. El arreglo de C-NET-13 dobló la
    /// constante de la que salen, y la narración se quedó atrás.
    ///
    /// Así que aquí no se escribe ningún número a mano salvo el techo: todo lo demás se calcula
    /// desde las constantes reales, y las cotas comprueban el **orden de magnitud**, que es lo que
    /// de verdad importa y lo que un cambio futuro no debe romper en silencio.
    #[test]
    fn el_presupuesto_por_defecto_acota_el_peor_caso() {
        use crate::limites::{MAX_PEERS_ENTRANTES, MAX_RESPUESTA_BYTES, MAX_STREAMS_SYNC};

        // Lo que se podía reservar SIN presupuesto agregado.
        let sin_presupuesto =
            MAX_RESPUESTA_BYTES * MAX_STREAMS_SYNC as u64 * u64::from(MAX_PEERS_ENTRANTES);
        assert!(
            sin_presupuesto > 7_000_000_000,
            "el peor caso sin presupuesto eran ~7,2 GB: {sin_presupuesto}"
        );

        // Y lo que se puede ahora, sin importar peers ni streams.
        assert!(
            (PRESUPUESTO_BYTES as u64) < sin_presupuesto / 20,
            "el presupuesto debe quitar al menos un orden de magnitud"
        );
        assert_eq!(PRESUPUESTO_BYTES, 268_435_456, "256 MiB");
    }
}
