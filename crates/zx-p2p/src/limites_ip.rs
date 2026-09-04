//! Límites y baneo **por dirección IP** (SPEC §16.3, C-NET-05, C-NET-20).
//!
//! # Por qué `connection_limits` de libp2p no basta
//!
//! Lo comprobé en el crate: sus únicos ajustes son `with_max_pending_incoming`,
//! `with_max_established_incoming/outgoing`, `with_max_established` y
//! `with_max_established_per_peer`. **Ninguno mira la IP de origen.** Todos son globales o por
//! `PeerId`.
//!
//! Y ese es el problema, porque **un `PeerId` es gratis**: `Keypair::generate_ed25519()` es
//! instantáneo, sin PoW, sin registro, sin coste. Así que `MAX_CONEXIONES_POR_PEER = 1` no defiende
//! de nada — basta con generar una identidad nueva por conexión.
//!
//! Dos ataques que eso deja abiertos, ambos desde **una sola máquina**:
//!
//! | Ataque | Cómo | Efecto |
//! |---|---|---|
//! | *Slowloris* | Abrir conexiones y no terminar nunca el handshake | El contador global de pendientes se llena y el nodo **rechaza a todo el mundo**, honesto o no |
//! | Relleno de cupo | 72 `PeerId` distintos desde la misma IP | Se ocupa el cupo entrante entero y el nodo queda sordo a peers nuevos |
//!
//! Es lo que hacen Bitcoin Core y Zebra, y por eso hay que escribirlo: libp2p no lo trae.
//!
//! # Por qué por /24 y /64, y no por IP exacta
//!
//! Contar por IP exacta es trivial de evadir: cualquier VPS barato viene con varias, y un /64 de
//! IPv6 son 18 trillones de direcciones asignadas **a un solo cliente**. Contar por prefijo hace que
//! el coste de evadir sea el de alquilar redes distintas, no el de pedir una IP más.
//!
//! IPv4 se agrupa por **/24** y IPv6 por **/64**, que es la unidad que los proveedores asignan.

use std::collections::HashMap;
use std::net::{IpAddr, Ipv4Addr, Ipv6Addr};
use std::task::{Context, Poll};

use libp2p::core::transport::PortUse;
use libp2p::swarm::{
    ConnectionDenied, ConnectionId, FromSwarm, NetworkBehaviour, THandler, THandlerInEvent,
    THandlerOutEvent, ToSwarm, dummy,
};
use libp2p::{Multiaddr, PeerId};

/// Conexiones simultáneas desde un mismo prefijo de red.
///
/// Deliberadamente bajo: un operador honesto no necesita varias conexiones al mismo nodo desde la
/// misma subred, y un atacante sí.
pub const MAX_POR_PREFIJO: u32 = 3;

/// Conexiones **a medio negociar** desde un mismo prefijo. La defensa contra *slowloris*.
pub const MAX_PENDIENTES_POR_PREFIJO: u32 = 2;

/// Cuánto puntúa una violación de consenso.
pub const PUNTOS_VIOLACION_CONSENSO: u32 = 100;

/// A partir de cuántos puntos se banea un prefijo.
///
/// 100 significa **un solo golpe**: una violación de consenso positivamente identificada no admite
/// segunda oportunidad. Es el valor de Zebra, y la razón es que fabricar una violación de consenso
/// cuesta trabajo real — no ocurre por accidente.
pub const UMBRAL_BANEO: u32 = 100;

// Una conexión pendiente le cuesta menos al atacante que una establecida —no ha completado el
// handshake— así que su cupo MUST ser más estrecho, no más ancho. Aserción de compilación y no
// test: es una relación entre constantes, y una aserción de compilación no se puede saltar.
const _: () = assert!(
    MAX_PENDIENTES_POR_PREFIJO < MAX_POR_PREFIJO && MAX_PENDIENTES_POR_PREFIJO > 0,
    "el cupo de pendientes debe ser más estrecho que el de establecidas, y no cero"
);

/// Cuántos prefijos baneados se recuerdan.
///
/// Acotado, y con desalojo del más antiguo. Sin la cota, el propio registro de baneos sería el
/// vector: un atacante con muchas redes haría crecer la tabla sin límite.
pub const MAX_BANEADOS: usize = 20_000;

/// Un prefijo de red: /24 en IPv4, /64 en IPv6.
#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
pub enum Prefijo {
    /// Los tres primeros octetos de una IPv4.
    V4([u8; 3]),
    /// Los ocho primeros bytes de una IPv6.
    V6([u8; 8]),
}

impl Prefijo {
    /// El prefijo de una IP.
    #[must_use]
    pub fn de_ip(ip: IpAddr) -> Self {
        match ip {
            IpAddr::V4(v4) => Self::de_v4(v4),
            IpAddr::V6(v6) => Self::de_v6(v6),
        }
    }

    fn de_v4(v4: Ipv4Addr) -> Self {
        let o = v4.octets();
        Self::V4([o[0], o[1], o[2]])
    }

    fn de_v6(v6: Ipv6Addr) -> Self {
        let o = v6.octets();
        let mut p = [0u8; 8];
        p.copy_from_slice(o.get(..8).unwrap_or(&[0u8; 8]));
        Self::V6(p)
    }

    /// El prefijo de una `Multiaddr`, o `None` si no lleva IP.
    ///
    /// Una dirección sin IP —memoria, por ejemplo— **no se limita**: el transporte en memoria solo
    /// existe en tests, y limitarlo ahí rompería el arnés sin defender nada.
    #[must_use]
    pub fn de_multiaddr(addr: &Multiaddr) -> Option<Self> {
        use libp2p::multiaddr::Protocol;
        addr.iter().find_map(|p| match p {
            Protocol::Ip4(v4) => Some(Self::de_v4(v4)),
            Protocol::Ip6(v6) => Some(Self::de_v6(v6)),
            _ => None,
        })
    }
}

/// Behaviour que limita y banea por prefijo de red.
#[derive(Debug, Default)]
pub struct LimitesPorIp {
    establecidas: HashMap<Prefijo, u32>,
    pendientes: HashMap<Prefijo, u32>,
    /// Qué prefijo tiene cada conexión, para poder descontar al cerrarse.
    de_conexion: HashMap<ConnectionId, Prefijo>,
    /// Qué prefijos usa cada peer, para poder puntuarlo cuando se le condena.
    ///
    /// Un peer puede estar conectado desde varios: se puntúan **todos**, porque la identidad que
    /// violó consenso es la misma detrás de cada uno.
    de_peer: HashMap<PeerId, Vec<Prefijo>>,
    puntos: HashMap<Prefijo, u32>,
    /// Prefijos baneados, en orden de llegada para desalojar el más antiguo.
    baneados: Vec<Prefijo>,
}

/// Por qué se denegó una conexión.
#[derive(Debug, thiserror::Error)]
pub enum Denegada {
    /// El prefijo está baneado.
    #[error("prefijo baneado por violación de consenso")]
    Baneado,
    /// Demasiadas conexiones establecidas desde ese prefijo.
    #[error("demasiadas conexiones desde el mismo prefijo de red ({actual}/{max})")]
    DemasiadasEstablecidas {
        /// Cuántas hay.
        actual: u32,
        /// Cuántas se admiten.
        max: u32,
    },
    /// Demasiadas conexiones a medio negociar desde ese prefijo.
    #[error("demasiadas conexiones pendientes desde el mismo prefijo ({actual}/{max})")]
    DemasiadasPendientes {
        /// Cuántas hay.
        actual: u32,
        /// Cuántas se admiten.
        max: u32,
    },
}

impl LimitesPorIp {
    /// Uno vacío.
    #[must_use]
    pub fn nuevo() -> Self {
        Self::default()
    }

    /// ¿Está baneado este prefijo?
    #[must_use]
    pub fn esta_baneado(&self, p: Prefijo) -> bool {
        self.baneados.contains(&p)
    }

    /// Puntos acumulados por un prefijo.
    #[must_use]
    pub fn puntos_de(&self, p: Prefijo) -> u32 {
        self.puntos.get(&p).copied().unwrap_or(0)
    }

    /// Cuántos prefijos hay baneados.
    #[must_use]
    pub fn baneados(&self) -> usize {
        self.baneados.len()
    }

    /// Los prefijos desde los que está conectado un peer.
    #[must_use]
    pub fn prefijos_de(&self, peer: PeerId) -> Vec<Prefijo> {
        self.de_peer.get(&peer).cloned().unwrap_or_default()
    }

    /// Suma puntos a un prefijo y lo banea si cruza el umbral.
    ///
    /// Devuelve `true` si acaba de banearse.
    ///
    /// **Solo debe llamarse con violaciones de consenso positivamente identificadas** (C-NET-05).
    /// Un peer lento, uno que habla otra versión o uno que va por detrás **no** puntúan: la razón
    /// es la de Zebra —*quien te entrega un bloque no es quien eligió su altura*— y penalizar al
    /// mensajero deja que un tercero haga que baneemos a peers honestos.
    pub fn puntuar(&mut self, p: Prefijo, puntos: u32) -> bool {
        let total = self.puntos.entry(p).or_insert(0);
        *total = total.saturating_add(puntos);

        if *total >= UMBRAL_BANEO && !self.baneados.contains(&p) {
            // Desalojo FIFO: sin la cota, el propio registro de baneos sería el vector.
            if self.baneados.len() >= MAX_BANEADOS {
                let viejo = self.baneados.remove(0);
                self.puntos.remove(&viejo);
            }
            self.baneados.push(p);
            return true;
        }
        false
    }

    fn comprobar(&self, p: Prefijo, pendiente: bool) -> Result<(), Denegada> {
        if self.baneados.contains(&p) {
            return Err(Denegada::Baneado);
        }
        if pendiente {
            let n = self.pendientes.get(&p).copied().unwrap_or(0);
            if n >= MAX_PENDIENTES_POR_PREFIJO {
                return Err(Denegada::DemasiadasPendientes {
                    actual: n,
                    max: MAX_PENDIENTES_POR_PREFIJO,
                });
            }
        } else {
            let n = self.establecidas.get(&p).copied().unwrap_or(0);
            if n >= MAX_POR_PREFIJO {
                return Err(Denegada::DemasiadasEstablecidas {
                    actual: n,
                    max: MAX_POR_PREFIJO,
                });
            }
        }
        Ok(())
    }
}

impl NetworkBehaviour for LimitesPorIp {
    type ConnectionHandler = dummy::ConnectionHandler;
    type ToSwarm = std::convert::Infallible;

    fn handle_pending_inbound_connection(
        &mut self,
        id: ConnectionId,
        _local: &Multiaddr,
        remoto: &Multiaddr,
    ) -> Result<(), ConnectionDenied> {
        // Sin IP no se limita: el transporte en memoria solo existe en tests.
        let Some(p) = Prefijo::de_multiaddr(remoto) else {
            return Ok(());
        };
        self.comprobar(p, true).map_err(ConnectionDenied::new)?;

        *self.pendientes.entry(p).or_insert(0) += 1;
        self.de_conexion.insert(id, p);
        Ok(())
    }

    fn handle_established_inbound_connection(
        &mut self,
        id: ConnectionId,
        peer: PeerId,
        _local: &Multiaddr,
        remoto: &Multiaddr,
    ) -> Result<THandler<Self>, ConnectionDenied> {
        let Some(p) = Prefijo::de_multiaddr(remoto) else {
            return Ok(dummy::ConnectionHandler);
        };
        // Deja de estar pendiente pase lo que pase: si se deniega ahora, la pendiente ya no lo es.
        if let Some(n) = self.pendientes.get_mut(&p) {
            *n = n.saturating_sub(1);
        }
        self.comprobar(p, false).map_err(ConnectionDenied::new)?;

        *self.establecidas.entry(p).or_insert(0) += 1;
        self.de_conexion.insert(id, p);
        let prefijos = self.de_peer.entry(peer).or_default();
        if !prefijos.contains(&p) {
            prefijos.push(p);
        }
        Ok(dummy::ConnectionHandler)
    }

    fn handle_established_outbound_connection(
        &mut self,
        _id: ConnectionId,
        _peer: PeerId,
        _addr: &Multiaddr,
        _rol: libp2p::core::Endpoint,
        _puerto: PortUse,
    ) -> Result<THandler<Self>, ConnectionDenied> {
        // Las salientes las elegimos nosotros: no hay nada que limitar por IP ajena.
        Ok(dummy::ConnectionHandler)
    }

    fn on_swarm_event(&mut self, evento: FromSwarm) {
        match evento {
            FromSwarm::ConnectionClosed(c) => {
                if let Some(p) = self.de_conexion.remove(&c.connection_id) {
                    if let Some(n) = self.establecidas.get_mut(&p) {
                        *n = n.saturating_sub(1);
                    }
                    // El mapa de peer→prefijos se limpia al cerrar la última conexión suya, o
                    // crecería sin límite con cada peer que pase por aquí.
                    if let Some(v) = self.de_peer.get_mut(&c.peer_id) {
                        v.retain(|q| *q != p);
                        if v.is_empty() {
                            self.de_peer.remove(&c.peer_id);
                        }
                    }
                }
            }
            // Una conexión entrante que falla antes de establecerse deja de estar pendiente. Sin
            // esto, un atacante que abre y abandona conexiones agota el cupo de pendientes **para
            // siempre**: es el slowloris, convertido en permanente por una fuga de contador.
            FromSwarm::ListenFailure(f) => {
                if let Some(p) = self.de_conexion.remove(&f.connection_id)
                    && let Some(n) = self.pendientes.get_mut(&p)
                {
                    *n = n.saturating_sub(1);
                }
            }
            _ => {}
        }
    }

    fn on_connection_handler_event(
        &mut self,
        _peer: PeerId,
        _id: ConnectionId,
        evento: THandlerOutEvent<Self>,
    ) {
        // `dummy::ConnectionHandler` no emite eventos: su tipo es `Infallible`.
        match evento {}
    }

    fn poll(
        &mut self,
        _cx: &mut Context<'_>,
    ) -> Poll<ToSwarm<Self::ToSwarm, THandlerInEvent<Self>>> {
        Poll::Pending
    }
}

#[cfg(test)]
#[expect(
    clippy::unwrap_used,
    clippy::integer_division,
    reason = "los tests fallan con panic por diseño; la división entera genera prefijos distintos"
)]
mod tests {
    use super::{
        Denegada, LimitesPorIp, MAX_BANEADOS, PUNTOS_VIOLACION_CONSENSO, Prefijo, UMBRAL_BANEO,
    };
    use libp2p::Multiaddr;
    use std::net::{IpAddr, Ipv4Addr, Ipv6Addr};

    fn v4(a: u8, b: u8, c: u8, d: u8) -> Prefijo {
        Prefijo::de_ip(IpAddr::V4(Ipv4Addr::new(a, b, c, d)))
    }

    /// **La propiedad que hace útil todo esto: agrupar por prefijo, no por IP.**
    ///
    /// Contar por IP exacta es trivial de evadir — cualquier VPS trae varias, y un /64 de IPv6 son
    /// 18 trillones de direcciones asignadas a **un solo cliente**. Agrupar hace que evadir cueste
    /// alquilar redes distintas, no pedir una IP más.
    #[test]
    fn las_ips_del_mismo_prefijo_cuentan_como_una() {
        assert_eq!(v4(1, 2, 3, 4), v4(1, 2, 3, 200), "mismo /24");
        assert_ne!(v4(1, 2, 3, 4), v4(1, 2, 4, 4), "distinto /24");

        // IPv6: el /64 es la unidad que asignan los proveedores.
        let a = Prefijo::de_ip(IpAddr::V6(
            "2001:db8:1:2:3:4:5:6".parse::<Ipv6Addr>().unwrap(),
        ));
        let b = Prefijo::de_ip(IpAddr::V6(
            "2001:db8:1:2:ffff:ffff:ffff:ffff"
                .parse::<Ipv6Addr>()
                .unwrap(),
        ));
        let c = Prefijo::de_ip(IpAddr::V6("2001:db8:1:3::1".parse::<Ipv6Addr>().unwrap()));
        assert_eq!(
            a, b,
            "mismo /64: 18 trillones de direcciones son un cliente"
        );
        assert_ne!(a, c, "distinto /64");
    }

    #[test]
    fn el_prefijo_se_extrae_de_una_multiaddr() {
        let m: Multiaddr = "/ip4/192.168.1.5/tcp/9833".parse().unwrap();
        assert_eq!(Prefijo::de_multiaddr(&m), Some(v4(192, 168, 1, 0)));

        let m6: Multiaddr = "/ip6/2001:db8::1/tcp/9833".parse().unwrap();
        assert!(matches!(Prefijo::de_multiaddr(&m6), Some(Prefijo::V6(_))));

        // Memoria: sin IP, **no se limita**. Limitarlo rompería el arnés de tests sin defender nada.
        let mem: Multiaddr = "/memory/12345".parse().unwrap();
        assert_eq!(Prefijo::de_multiaddr(&mem), None);
    }

    /// **Un solo golpe basta para banear.**
    ///
    /// Fabricar una violación de consenso cuesta trabajo real: no ocurre por accidente, así que no
    /// hay segunda oportunidad. Es el valor de Zebra.
    #[test]
    fn una_violacion_de_consenso_banea_de_un_golpe() {
        let mut l = LimitesPorIp::nuevo();
        let p = v4(10, 0, 0, 1);

        assert!(!l.esta_baneado(p));
        assert!(
            l.puntuar(p, PUNTOS_VIOLACION_CONSENSO),
            "banea al primer golpe"
        );
        assert!(l.esta_baneado(p));
        assert_eq!(l.puntos_de(p), UMBRAL_BANEO);

        // Y no se banea dos veces: la segunda no vuelve a devolver `true`.
        assert!(!l.puntuar(p, PUNTOS_VIOLACION_CONSENSO));
        assert_eq!(l.baneados(), 1);
    }

    /// Puntos por debajo del umbral **no** banean, y se acumulan.
    #[test]
    fn los_puntos_se_acumulan_hasta_el_umbral() {
        let mut l = LimitesPorIp::nuevo();
        let p = v4(10, 0, 0, 1);

        assert!(!l.puntuar(p, UMBRAL_BANEO - 1));
        assert!(!l.esta_baneado(p), "uno menos que el umbral no banea");
        assert!(l.puntuar(p, 1), "el que cruza sí");
        assert!(l.esta_baneado(p));
    }

    /// **El registro de baneos está acotado, o sería el vector.**
    ///
    /// Sin la cota, un atacante con muchas redes haría crecer la tabla sin límite — convertiría la
    /// defensa en el ataque.
    #[test]
    fn el_registro_de_baneos_no_crece_sin_limite() {
        let mut l = LimitesPorIp::nuevo();
        // Banear MAX_BANEADOS + 100 prefijos distintos.
        for i in 0..(MAX_BANEADOS + 100) {
            let p = Prefijo::V4([(i / 65_536) as u8, ((i / 256) % 256) as u8, (i % 256) as u8]);
            l.puntuar(p, PUNTOS_VIOLACION_CONSENSO);
        }
        assert_eq!(l.baneados(), MAX_BANEADOS, "la tabla está acotada");

        // Y el desalojo es FIFO: el primero ya no está.
        assert!(
            !l.esta_baneado(Prefijo::V4([0, 0, 0])),
            "el más viejo se desalojó"
        );
        // El último sí.
        let i = MAX_BANEADOS + 99;
        let ultimo = Prefijo::V4([(i / 65_536) as u8, ((i / 256) % 256) as u8, (i % 256) as u8]);
        assert!(l.esta_baneado(ultimo));
    }

    /// Un prefijo baneado se deniega antes que nada, sin mirar cupos.
    #[test]
    fn un_prefijo_baneado_se_deniega_de_inmediato() {
        let mut l = LimitesPorIp::nuevo();
        let p = v4(203, 0, 113, 7);
        l.puntuar(p, PUNTOS_VIOLACION_CONSENSO);

        assert!(matches!(l.comprobar(p, true), Err(Denegada::Baneado)));
        assert!(matches!(l.comprobar(p, false), Err(Denegada::Baneado)));

        // Y uno limpio pasa.
        let limpio = v4(198, 51, 100, 1);
        assert!(l.comprobar(limpio, true).is_ok());
        assert!(l.comprobar(limpio, false).is_ok());
    }
}
