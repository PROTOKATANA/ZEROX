//! Servicio PoT **local** de la red dev: flujo único, slot a slot, con ventana acotada
//! (D-P09, D-P10; `C-FLU-06`, `C-POT-01`, `C-POT-02`, `C-POT-04`, `C-POT-05`).
//!
//! # Qué es
//!
//! [`ServicioPot`] conserva el estado PoT de **una** historia dev y avanza un slot por llamada:
//!
//! - arranca de la semilla S1 del terminal `T` (`semilla(f_0, 0) = blake3(block_hash(T) ‖ ∅)[0..16)`,
//!   D-P09) como salida del slot 0;
//! - avanza con `N_dev` constante y **un solo flujo, sin inyecciones** (`D = 0`, D-P10), calculando
//!   `zx_pot::prove(semilla_siguiente(salida_anterior, None), N_dev)`;
//! - guarda la salida y el portador de una **ventana acotada y configurable** de slots, con error
//!   explícito fuera de ella;
//! - implementa [`InstantaneaPot`] para que la puerta conjunta verifique **cabeceras ajenas** con
//!   las salidas ya calculadas.
//!
//! Es **lógica pura, sin hilos propios**: no arranca ningún hilo ni temporizador; el nodo (W06) es
//! quien lo avanzará desde su bucle.
//!
//! # El pasado validado no se inventa
//!
//! `InstantaneaPot::pasado()` necesita `(hash, slot, flujo)` de los bloques padre, que **no** se
//! deducen del estado PoT. Por eso el servicio expone [`ServicioPot::registrar_validado`]: el
//! llamante declara los bloques que ya validó y el servicio solo conserva los que caen en la
//! ventana. La validez la aporta el llamante, **no** este objeto; el terminal entra como ancla
//! (slot 0) en la construcción.
//!
//! # Qué NO acredita
//!
//! No admite bloques, no verifica sellos ni PoAS, no elige padres ni rango, no archiva historia y
//! no elige `N_dev` ni `SR_dev` (los fija la red dev; D-P10/D-P11). Su semilla es el marcador S1
//! (A-07 abierto): no es una derivación de seguridad.
//!
//! # Memoria
//!
//! La ventana retiene a lo sumo `ventana` slots de salidas (16 B) y portadores (128 B), más el
//! ancla del terminal (constante extra). Los registros de pasado se podan con el mismo límite. El
//! coste por avance es un `prove` de `N_dev` iteraciones.

use std::collections::BTreeMap;
use std::num::NonZeroU32;

use zx_core::BlockHash;
use zx_core::preimage::flow::flujo_genesis;
use zx_core::wire_dag::{MAX_BUNDLES_POT, POT_OUTPUT_BYTES, PotCheckpoints};
use zx_pot::tipos::PotSeed;

use crate::pot::{
    ErrorContextoPot, checkpoints_a_wire, proyectar_iteraciones, semilla_genesis, semilla_siguiente,
};
use crate::pot_rango::{
    BloqueDelPasado, FLUJO_BYTES, InstantaneaPot, InyeccionesPot, MotivoPotPendiente,
};

/// Fallo del servicio PoT local.
#[derive(Debug, thiserror::Error)]
pub enum ErrorServicioPot {
    /// La ventana configurada mide cero slots.
    #[error("ventana de {configurada} slots: debe ser >= 1")]
    VentanaInvalida {
        /// Valor configurado.
        configurada: u64,
    },
    /// `N_dev` fuera del dominio de la primitiva PoT.
    #[error("N_dev inválido: {0}")]
    NDevInvalido(#[from] ErrorContextoPot),
    /// El slot pedido no está retenido en la ventana.
    #[error("el slot {slot} no está en la ventana retenida [{desde}, {hasta}]")]
    FueraDeVentana {
        /// Slot pedido.
        slot: u64,
        /// Primer slot retenido.
        desde: u64,
        /// Último slot calculado.
        hasta: u64,
    },
    /// No hay portador retenido para un slot que cae dentro de la ventana (nunca el ancla 0).
    #[error("no hay portador retenido para el slot {slot}")]
    PortadorAusente {
        /// Slot sin portador.
        slot: u64,
    },
    /// Se pidió un slot por delante del último calculado.
    #[error("el servicio está en el slot {slot_actual}; se pidió el {slot}")]
    SlotFuturo {
        /// Slot pedido.
        slot: u64,
        /// Último slot calculado.
        slot_actual: u64,
    },
    /// Se pidió retroceder el servicio.
    #[error("el servicio ya avanzó hasta el slot {actual}; se pidió {pedido}")]
    ObjetivoAnterior {
        /// Slot pedido.
        pedido: u64,
        /// Último slot calculado.
        actual: u64,
    },
    /// Aritmética de slots desbordada.
    #[error("aritmética de slots desbordada")]
    AritmeticaDeSlotsDesbordada,
    /// El rango `(sp_slot, b_slot]` es vacío o invertido.
    #[error("rango de slots inválido: sp={sp_slot}, B={b_slot}")]
    RangoInvalido {
        /// Slot del padre seleccionado.
        sp_slot: u64,
        /// Slot del bloque.
        b_slot: u64,
    },
    /// El rango supera la cota de portadores del formato.
    #[error("el rango {d} excede MAX_BUNDLES_POT={max}")]
    RangoExcedeMaximo {
        /// Diferencia pedida.
        d: u64,
        /// Cota del formato.
        max: u64,
    },
    /// Se registró dos veces el mismo `block_hash`.
    #[error("bloque ya registrado en el pasado del servicio: {hash}")]
    BloqueDuplicado {
        /// Hash repetido.
        hash: BlockHash,
    },
    /// La primitiva PoT rechazó el slot.
    #[error("la primitiva PoT rechazó el slot {slot}: {error}")]
    Pot {
        /// Slot que falló.
        slot: u64,
        /// Error de la primitiva.
        #[source]
        error: zx_pot::PotError,
    },
}

/// Servicio PoT local de una historia dev, con ventana acotada de slots.
///
/// Se construye con [`ServicioPot::nuevo`] (terminal, `N_dev` y ventana) y se avanza con
/// [`ServicioPot::avanzar`] o [`ServicioPot::avanzar_hasta`]. Es inmutable salvo por esas dos
/// operaciones y [`ServicioPot::registrar_validado`].
#[derive(Debug, Clone)]
pub struct ServicioPot {
    terminal: BlockHash,
    f0: [u8; FLUJO_BYTES],
    s1: [u8; POT_OUTPUT_BYTES],
    n_dev: u64,
    iteraciones: NonZeroU32,
    ventana: u64,
    slot_actual: u64,
    salidas: BTreeMap<u64, [u8; POT_OUTPUT_BYTES]>,
    portadores: BTreeMap<u64, PotCheckpoints>,
    pasado: Vec<BloqueDelPasado>,
}

impl ServicioPot {
    /// Arranca el servicio en el terminal `T` (slot 0 = S1) con `N_dev` y una ventana de slots.
    ///
    /// Deriva `f_0` y S1 **solo** de `block_hash(T)` (entropía externa vacía, D-P09) y exige
    /// `N_dev` en el dominio de la primitiva. La ventana debe ser `>= 1`.
    ///
    /// # Errores
    /// [`ErrorServicioPot::NDevInvalido`] si `N_dev` no es válido;
    /// [`ErrorServicioPot::VentanaInvalida`] si `ventana == 0`.
    pub fn nuevo(terminal: BlockHash, n_dev: u64, ventana: u64) -> Result<Self, ErrorServicioPot> {
        let iteraciones = proyectar_iteraciones(n_dev)?;
        if ventana == 0 {
            return Err(ErrorServicioPot::VentanaInvalida { configurada: 0 });
        }
        let f0 = flujo_genesis(&terminal);
        let s1 = semilla_genesis(&terminal, &[]);
        let pasado = vec![BloqueDelPasado {
            hash: terminal,
            slot: 0,
            flujo: f0,
        }];
        Ok(Self {
            terminal,
            f0,
            s1,
            n_dev,
            iteraciones,
            ventana,
            slot_actual: 0,
            salidas: BTreeMap::new(),
            portadores: BTreeMap::new(),
            pasado,
        })
    }

    /// `block_hash` del terminal `T`.
    #[must_use]
    pub const fn terminal(&self) -> BlockHash {
        self.terminal
    }

    /// `f_0 = H_flujo(ETIQUETA_GENESIS ‖ block_hash(T))` (D-P09).
    #[must_use]
    pub const fn f0(&self) -> [u8; FLUJO_BYTES] {
        self.f0
    }

    /// S1: `blake3(block_hash(T) ‖ ∅)[0..16)`, la salida confiada del slot 0 (D-P09).
    #[must_use]
    pub const fn s1(&self) -> [u8; POT_OUTPUT_BYTES] {
        self.s1
    }

    /// `N_dev` del perfil dev (D-P10).
    #[must_use]
    pub const fn n_dev(&self) -> u64 {
        self.n_dev
    }

    /// Ventana de slots retenida.
    #[must_use]
    pub const fn ventana(&self) -> u64 {
        self.ventana
    }

    /// Último slot calculado (0 si solo está S1).
    #[must_use]
    pub const fn slot_actual(&self) -> u64 {
        self.slot_actual
    }

    /// Primer slot retenido en la ventana.
    #[must_use]
    pub fn primer_slot_retenido(&self) -> u64 {
        self.slot_actual
            .saturating_sub(self.ventana.saturating_sub(1))
    }

    /// `salida(f, slot)` ya calculada. El slot 0 es S1 (ancla del terminal).
    ///
    /// # Errores
    /// [`ErrorServicioPot::FueraDeVentana`] si el slot no está retenido.
    pub fn salida_de(&self, slot: u64) -> Result<[u8; POT_OUTPUT_BYTES], ErrorServicioPot> {
        if slot == 0 {
            return Ok(self.s1);
        }
        self.salidas
            .get(&slot)
            .copied()
            .ok_or(ErrorServicioPot::FueraDeVentana {
                slot,
                desde: self.primer_slot_retenido(),
                hasta: self.slot_actual,
            })
    }

    /// Portador PoT de 128 B del slot, si está retenido. El slot 0 no tiene portador (es S1).
    ///
    /// # Errores
    /// [`ErrorServicioPot::PortadorAusente`] si el slot no tiene portador retenido.
    pub fn portador_de(&self, slot: u64) -> Result<&PotCheckpoints, ErrorServicioPot> {
        self.portadores
            .get(&slot)
            .ok_or(ErrorServicioPot::PortadorAusente { slot })
    }

    /// Avanza **un** slot: calcula la salida y el portador siguientes con `N_dev`.
    ///
    /// # Errores
    /// [`ErrorServicioPot::AritmeticaDeSlotsDesbordada`] si `slot_actual + 1` no cabe;
    /// [`ErrorServicioPot::Pot`] si la primitiva rechaza la terna (no debería con `N_dev` válido).
    pub fn avanzar(&mut self) -> Result<u64, ErrorServicioPot> {
        let slot = self
            .slot_actual
            .checked_add(1)
            .ok_or(ErrorServicioPot::AritmeticaDeSlotsDesbordada)?;
        let anterior = self.salida_de(self.slot_actual)?;
        // Un solo flujo y sin inyecciones: D-P10. La semilla del slot es la salida anterior.
        let semilla = semilla_siguiente(anterior, None);
        let carrier = zx_pot::prove(PotSeed::from(semilla), self.iteraciones)
            .map_err(|error| ErrorServicioPot::Pot { slot, error })?;
        self.salidas.insert(slot, *carrier.output());
        self.portadores.insert(slot, checkpoints_a_wire(&carrier));
        self.slot_actual = slot;
        self.podar();
        Ok(slot)
    }

    /// Avanza hasta `slot` (inclusive). Si ya se pasó, es error explícito.
    ///
    /// # Errores
    /// [`ErrorServicioPot::ObjetivoAnterior`] si `slot < slot_actual`; las de [`Self::avanzar`].
    pub fn avanzar_hasta(&mut self, slot: u64) -> Result<u64, ErrorServicioPot> {
        if slot < self.slot_actual {
            return Err(ErrorServicioPot::ObjetivoAnterior {
                pedido: slot,
                actual: self.slot_actual,
            });
        }
        while self.slot_actual < slot {
            self.avanzar()?;
        }
        Ok(self.slot_actual)
    }

    /// Inserta la salida y el portador de `slot` **ya calculados por el llamante**, sin volver a
    /// correr `zx_pot::prove` (`ORDEN-W06d1`, decisión 7: reconstruir el servicio al reiniciar
    /// «desde las salidas PoT de las cabeceras almacenadas… no recalculando el flujo desde T»,
    /// porque recalcularlo costaría el tiempo real transcurrido).
    ///
    /// A diferencia de [`Self::avanzar`], **no** exige `slot == slot_actual() + 1`: solo que
    /// `slot > slot_actual()`. El flujo es único y global (D-P10): dos bloques de ramas o slots
    /// distintos comparten exactamente la misma `salida(f, slot)`, así que un llamante que reconstruye
    /// varias ramas (o repite el registro de admisión) solo necesita **avanzar**, nunca rellenar un
    /// hueco por el que ya pasó otra rama; los huecos intermedios sin bloque tampoco hace falta
    /// llenarlos, porque nunca son `sp` de nadie (`sp` es siempre el slot de un bloque admitido). No
    /// verifica que `salida`/`portador` sean los que `prove` habría producido: es responsabilidad del
    /// llamante que vengan de una cabecera **ya admitida** (su `pot_output`) y de su justificación,
    /// no de una fuente no verificada.
    ///
    /// # Errores
    /// [`ErrorServicioPot::ObjetivoAnterior`] si `slot <= slot_actual()`.
    pub fn insertar_calculado(
        &mut self,
        slot: u64,
        salida: [u8; POT_OUTPUT_BYTES],
        portador: PotCheckpoints,
    ) -> Result<(), ErrorServicioPot> {
        if slot <= self.slot_actual {
            return Err(ErrorServicioPot::ObjetivoAnterior {
                pedido: slot,
                actual: self.slot_actual,
            });
        }
        self.salidas.insert(slot, salida);
        self.portadores.insert(slot, portador);
        self.slot_actual = slot;
        self.podar();
        Ok(())
    }

    /// Registra un bloque **ya validado por el llamante** `(hash, slot)` en el pasado del servicio.
    ///
    /// No aporta ninguna prueba: es la declaración explícita que `InstantaneaPot::pasado()` no puede
    /// deducir del estado PoT. El terminal ya está registrado y no se puede repetir.
    ///
    /// # Errores
    /// [`ErrorServicioPot::SlotFuturo`] si el slot va por delante del servicio;
    /// [`ErrorServicioPot::BloqueDuplicado`] si el hash ya está registrado.
    pub fn registrar_validado(
        &mut self,
        hash: BlockHash,
        slot: u64,
    ) -> Result<(), ErrorServicioPot> {
        if slot > self.slot_actual {
            return Err(ErrorServicioPot::SlotFuturo {
                slot,
                slot_actual: self.slot_actual,
            });
        }
        if hash == self.terminal || self.pasado.iter().any(|b| b.hash == hash) {
            return Err(ErrorServicioPot::BloqueDuplicado { hash });
        }
        self.pasado.push(BloqueDelPasado {
            hash,
            slot,
            flujo: self.f0,
        });
        self.podar();
        Ok(())
    }

    /// `slot` declarado de un bloque registrado, si sigue en la ventana.
    #[must_use]
    pub fn slot_de(&self, hash: &BlockHash) -> Option<u64> {
        self.pasado
            .iter()
            .find_map(|b| (b.hash == *hash).then_some(b.slot))
    }

    /// Portadores de `(sp_slot, b_slot]`, en orden, para construir la justificación PoT.
    ///
    /// # Errores
    /// [`ErrorServicioPot::RangoInvalido`] si `sp_slot >= b_slot`;
    /// [`ErrorServicioPot::RangoExcedeMaximo`] si la diferencia supera `MAX_BUNDLES_POT`;
    /// [`ErrorServicioPot::SlotFuturo`] si `b_slot` va por delante del servicio;
    /// [`ErrorServicioPot::PortadorAusente`] si algún slot del rango salió de la ventana.
    pub fn portadores_para(
        &self,
        sp_slot: u64,
        b_slot: u64,
    ) -> Result<Vec<PotCheckpoints>, ErrorServicioPot> {
        let Some(d) = b_slot.checked_sub(sp_slot) else {
            return Err(ErrorServicioPot::RangoInvalido { sp_slot, b_slot });
        };
        if d == 0 {
            return Err(ErrorServicioPot::RangoInvalido { sp_slot, b_slot });
        }
        if d > MAX_BUNDLES_POT as u64 {
            return Err(ErrorServicioPot::RangoExcedeMaximo {
                d,
                max: MAX_BUNDLES_POT as u64,
            });
        }
        if b_slot > self.slot_actual {
            return Err(ErrorServicioPot::SlotFuturo {
                slot: b_slot,
                slot_actual: self.slot_actual,
            });
        }
        let mut portadores = Vec::with_capacity(d as usize);
        // `sp_slot < b_slot` garantiza que `sp_slot + 1` no desborda.
        for slot in (sp_slot + 1)..=b_slot {
            match self.portadores.get(&slot) {
                Some(p) => portadores.push(*p),
                None => return Err(ErrorServicioPot::PortadorAusente { slot }),
            }
        }
        Ok(portadores)
    }

    /// Poda las salidas, portadores y registros que salen de la ventana. El ancla del terminal
    /// (slot 0) es constante y no ocupa entrada en los mapas.
    fn podar(&mut self) {
        let limite = self.primer_slot_retenido();
        self.salidas.retain(|slot, _| *slot >= limite);
        self.portadores.retain(|slot, _| *slot >= limite);
        self.pasado
            .retain(|bloque| bloque.slot == 0 || bloque.slot >= limite);
    }
}

impl InstantaneaPot for ServicioPot {
    /// `f_0` en todo slot: un solo flujo y sin inyecciones (D-P10).
    fn flujo_candidato_en(&self, _slot: u64) -> Result<[u8; FLUJO_BYTES], MotivoPotPendiente> {
        Ok(self.f0)
    }

    /// El pasado registrado por el llamante, con el terminal en el slot 0.
    fn pasado(&self) -> Result<&[BloqueDelPasado], MotivoPotPendiente> {
        Ok(&self.pasado)
    }

    /// Ninguna inyección en dev (D-P10).
    fn inyecciones_en(&self, _slot: u64) -> Result<InyeccionesPot, MotivoPotPendiente> {
        Ok(InyeccionesPot::Ninguna)
    }

    /// `N(s) = N_dev` constante (D-P10).
    fn iteraciones(&self, _slot: u64) -> Result<u64, MotivoPotPendiente> {
        Ok(self.n_dev)
    }

    /// `D = 0` (D-P10).
    fn retardo_autoria(&self) -> Result<u64, MotivoPotPendiente> {
        Ok(0)
    }

    /// Salida ya calculada por el propio servicio; fuera de ventana es falta de contexto.
    fn salida_validada(&self, slot: u64) -> Result<[u8; POT_OUTPUT_BYTES], MotivoPotPendiente> {
        self.salida_de(slot)
            .map_err(|_| MotivoPotPendiente::ContextoAusente {
                que: "salida del slot fuera de la ventana del ServicioPot",
            })
    }
}

/// Pruebas internas del servicio: la salida de cada slot coincide con calcularla a mano desde S1.
#[cfg(test)]
#[expect(clippy::expect_used, reason = "los tests usan expect por diseño")]
mod pruebas {
    use core::num::NonZeroU32;

    use zx_core::BlockHash;
    use zx_core::digest::Digest;
    use zx_pot::tipos::PotSeed;

    use super::{ErrorServicioPot, ServicioPot};
    use crate::pot::semilla_genesis;
    use crate::pot_rango::{InstantaneaPot, InyeccionesPot, MotivoPotPendiente};

    const N: u64 = 32;

    fn hash(n: u8) -> BlockHash {
        BlockHash::from_digest(Digest::from_bytes([n; 32]))
    }

    fn servicio(ventana: u64) -> ServicioPot {
        ServicioPot::nuevo(hash(0x01), N, ventana).expect("servicio dev válido")
    }

    fn iteraciones() -> NonZeroU32 {
        NonZeroU32::new(u32::try_from(N).expect("N cabe en u32")).expect("N > 0")
    }

    #[test]
    fn parametros_invalidos_se_rechazan() {
        assert!(matches!(
            ServicioPot::nuevo(hash(1), 0, 10),
            Err(ErrorServicioPot::NDevInvalido(_))
        ));
        assert!(matches!(
            ServicioPot::nuevo(hash(1), 15, 10),
            Err(ErrorServicioPot::NDevInvalido(_))
        ));
        assert!(matches!(
            ServicioPot::nuevo(hash(1), N, 0),
            Err(ErrorServicioPot::VentanaInvalida { configurada: 0 })
        ));
    }

    #[test]
    fn la_cadena_coincide_con_calcularla_a_mano() {
        let mut s = servicio(8);
        let mut salida = s.s1();
        for slot in 1..=6u64 {
            let carrier = zx_pot::prove(PotSeed::from(salida), iteraciones()).expect("N válido");
            salida = *carrier.output();
            let calculado = s.avanzar().expect("avance");
            assert_eq!(calculado, slot);
            assert_eq!(s.salida_de(slot).expect("salida"), salida);
            assert_eq!(
                s.portador_de(slot).expect("portador"),
                &crate::pot::checkpoints_a_wire(&carrier)
            );
        }
        assert_eq!(s.slot_actual(), 6);
    }

    #[test]
    fn fuera_de_ventana_es_error_explicito() {
        let mut s = servicio(3);
        s.avanzar_hasta(6).expect("avance");
        assert_eq!(s.primer_slot_retenido(), 4);
        assert_eq!(s.salida_de(0).expect("ancla del terminal"), s.s1());
        assert!(matches!(
            s.salida_de(3),
            Err(ErrorServicioPot::FueraDeVentana {
                slot: 3,
                desde: 4,
                hasta: 6
            })
        ));
        assert!(matches!(
            s.portador_de(3),
            Err(ErrorServicioPot::PortadorAusente { slot: 3 })
        ));
    }

    #[test]
    fn portadores_para_cuenta_y_cotas() {
        let mut s = servicio(8);
        s.avanzar_hasta(5).expect("avance");
        assert_eq!(s.portadores_para(1, 5).expect("rango").len(), 4);
        assert!(matches!(
            s.portadores_para(3, 3),
            Err(ErrorServicioPot::RangoInvalido {
                sp_slot: 3,
                b_slot: 3
            })
        ));
        assert!(matches!(
            s.portadores_para(5, 1),
            Err(ErrorServicioPot::RangoInvalido { .. })
        ));
        assert!(matches!(
            s.portadores_para(1, 6),
            Err(ErrorServicioPot::SlotFuturo { slot: 6, .. })
        ));
    }

    #[test]
    fn registrar_validado_controla_duplicados_y_futuro() {
        let mut s = servicio(8);
        s.avanzar_hasta(3).expect("avance");
        s.registrar_validado(hash(0x0A), 2).expect("registro");
        assert_eq!(s.slot_de(&hash(0x0A)), Some(2));
        assert_eq!(s.slot_de(&s.terminal()), Some(0));
        assert!(matches!(
            s.registrar_validado(hash(0x0A), 2),
            Err(ErrorServicioPot::BloqueDuplicado { .. })
        ));
        assert!(matches!(
            s.registrar_validado(s.terminal(), 0),
            Err(ErrorServicioPot::BloqueDuplicado { .. })
        ));
        assert!(matches!(
            s.registrar_validado(hash(0x0B), 9),
            Err(ErrorServicioPot::SlotFuturo { slot: 9, .. })
        ));
    }

    #[test]
    fn instantanea_pot_respond() {
        let mut s = servicio(8);
        s.avanzar_hasta(2).expect("avance");
        assert_eq!(s.flujo_candidato_en(99).expect("flujo"), s.f0());
        assert_eq!(
            s.inyecciones_en(1).expect("inyecciones"),
            InyeccionesPot::Ninguna
        );
        assert_eq!(s.iteraciones(1).expect("N"), N);
        assert_eq!(s.retardo_autoria().expect("D"), 0);
        assert_eq!(s.salida_validada(0).expect("S1"), s.s1());
        assert_eq!(
            s.salida_validada(2).expect("slot 2"),
            s.salida_de(2).expect("mapa")
        );
        assert_eq!(
            s.salida_validada(50),
            Err(MotivoPotPendiente::ContextoAusente {
                que: "salida del slot fuera de la ventana del ServicioPot"
            })
        );
        assert_eq!(s.pasado().expect("pasado").len(), 1);
    }

    /// `ORDEN-W06d1`: reconstruir con `insertar_calculado` da el mismo estado que `avanzar`.
    #[test]
    fn insertar_calculado_reproduce_avanzar() {
        let mut avanzado = servicio(8);
        avanzado.avanzar_hasta(4).expect("avance");

        let mut reconstruido = servicio(8);
        for slot in 1..=4u64 {
            let salida = avanzado.salida_de(slot).expect("salida ya calculada");
            let portador = *avanzado.portador_de(slot).expect("portador ya calculado");
            reconstruido
                .insertar_calculado(slot, salida, portador)
                .expect("inserción secuencial válida");
        }
        assert_eq!(reconstruido.slot_actual(), avanzado.slot_actual());
        for slot in 1..=4u64 {
            assert_eq!(
                reconstruido.salida_de(slot).expect("salida"),
                avanzado.salida_de(slot).expect("salida")
            );
        }
    }

    #[test]
    fn insertar_calculado_permite_huecos_pero_no_retroceder() {
        let mut s = servicio(8);
        let carrier = zx_pot::prove(PotSeed::from(s.s1()), iteraciones()).expect("N válido");
        let portador = crate::pot::checkpoints_a_wire(&carrier);
        // `slot = 5` cuando `slot_actual() == 0`: salta el hueco 1..=4 (nunca es `sp` de nadie).
        s.insertar_calculado(5, *carrier.output(), portador)
            .expect("avanzar con hueco es válido: D-P10, flujo único");
        assert_eq!(s.slot_actual(), 5);
        // Retroceder (o repetir el mismo slot) sí es un error.
        assert!(matches!(
            s.insertar_calculado(5, *carrier.output(), portador),
            Err(ErrorServicioPot::ObjetivoAnterior {
                pedido: 5,
                actual: 5
            })
        ));
        assert!(matches!(
            s.insertar_calculado(3, *carrier.output(), portador),
            Err(ErrorServicioPot::ObjetivoAnterior {
                pedido: 3,
                actual: 5
            })
        ));
    }

    #[test]
    fn arranca_de_s1_del_terminal() {
        let t = hash(0x02);
        let s = ServicioPot::nuevo(t, N, 4).expect("servicio");
        assert_eq!(s.terminal(), t);
        assert_eq!(s.s1(), semilla_genesis(&t, &[]));
        assert_eq!(s.f0(), zx_core::preimage::flow::flujo_genesis(&t));
        assert_eq!(s.slot_actual(), 0);
    }
}
