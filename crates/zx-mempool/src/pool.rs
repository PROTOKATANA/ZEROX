//! El mempool: admisión, desalojo y selección para minar (SPEC §5.5, C-REORG-04).
//!
//! # Nada de aquí es consenso
//!
//! Un nodo puede tener el mempool que quiera. Lo que este módulo decide es **qué retransmite y qué
//! ofrece a su minero**, no qué es válido. Un bloque que incluya una transacción que este mempool
//! rechazó sigue siendo perfectamente válido (C-TX-15).
//!
//! Esa separación tiene una consecuencia práctica: el desalojo por presión de memoria y la
//! selección para minar pueden cambiarse sin hard fork, y **deben** poder hacerlo, porque son
//! precisamente las políticas que hay que ajustar con datos reales de la red.

// Aritmética entera deliberada: la selección para minar debe ser reproducible entre nodos, y un
// `f64` haría que dos máquinas ordenasen distinto ante empates cercanos.
#![expect(
    clippy::integer_division,
    reason = "la comisión por peso debe ser reproducible bit a bit entre nodos"
)]

use std::collections::HashMap;

use zx_consensus::emision::recompensa_base;
use zx_consensus::peso::{MAX_TX_WEIGHT, MedianaLarga};
use zx_core::digest::TxId;
use zx_core::tx::Tx;

use crate::error::MempoolError;
use crate::tarifa::se_admite;

/// Una transacción esperando en el mempool.
#[derive(Clone, Debug)]
pub struct Entrada {
    /// La transacción.
    pub tx: Tx,
    /// Sus testigos, uno por entrada.
    pub testigos: Vec<Vec<u8>>,
    /// Peso según C-WGT-02.
    pub peso: u64,
    /// Comisión que paga, en brek.
    pub fee: u128,
    /// Altura a la que entró — para desalojar por antigüedad.
    pub altura_entrada: u32,
}

impl Entrada {
    /// Comisión por unidad de peso, en brek. Es el criterio de ordenación para minar y desalojar.
    ///
    /// Se calcula con multiplicación previa para no perder precisión con transacciones grandes de
    /// comisión pequeña: dividir primero las aplastaría todas a cero y las haría indistinguibles.
    #[must_use]
    pub fn fee_por_peso_escalado(&self) -> u128 {
        const ESCALA: u128 = 1_000_000;
        if self.peso == 0 {
            return 0;
        }
        self.fee.saturating_mul(ESCALA) / u128::from(self.peso)
    }
}

/// Estado de la cadena que el mempool necesita para decidir.
#[derive(Clone, Copy, Debug)]
pub struct ContextoMempool {
    /// Altura del tip.
    pub altura: u32,
    /// Mediana de largo plazo vigente — la que ancla la tarifa (§5.5).
    pub mlt: MedianaLarga,
    /// Suministro emitido, para calcular la recompensa base.
    pub emitido: u128,
}

/// Mempool con un tope de peso total.
#[derive(Debug)]
pub struct Mempool {
    entradas: HashMap<TxId, Entrada>,
    peso_total: u64,
    peso_maximo: u64,
}

impl Mempool {
    /// Crea un mempool con el tope de peso dado.
    ///
    /// El tope es **política local**, no consenso: cada nodo elige cuánta memoria dedica.
    #[must_use]
    pub fn nuevo(peso_maximo: u64) -> Self {
        Self {
            entradas: HashMap::new(),
            peso_total: 0,
            peso_maximo,
        }
    }

    /// Transacciones en espera.
    #[must_use]
    pub fn len(&self) -> usize {
        self.entradas.len()
    }

    /// ¿Está vacío?
    #[must_use]
    pub fn is_empty(&self) -> bool {
        self.entradas.is_empty()
    }

    /// Peso total acumulado.
    #[must_use]
    pub const fn peso_total(&self) -> u64 {
        self.peso_total
    }

    /// ¿Contiene esta transacción?
    #[must_use]
    pub fn contiene(&self, id: &TxId) -> bool {
        self.entradas.contains_key(id)
    }

    /// Intenta admitir una transacción.
    ///
    /// La validez de consenso **ya debe estar comprobada** por el llamante: aquí solo se aplica
    /// política. Se rechaza si ya está, si excede `MAX_TX_WEIGHT`, o si la comisión no llega al
    /// mínimo dinámico (§5.5).
    ///
    /// Si el mempool está lleno, desaloja lo más barato **solo si la entrante paga más**. Sin esa
    /// condición, un atacante podría vaciar el mempool a base de transacciones baratas.
    ///
    /// # Errores
    /// La variante de [`MempoolError`] que corresponda.
    pub fn admitir(
        &mut self,
        id: TxId,
        entrada: Entrada,
        ctx: ContextoMempool,
    ) -> Result<(), MempoolError> {
        if self.entradas.contains_key(&id) {
            return Err(MempoolError::YaPresente);
        }
        if entrada.peso > MAX_TX_WEIGHT {
            return Err(MempoolError::ExcedeMaxTxWeight { peso: entrada.peso });
        }

        let base = recompensa_base(ctx.emitido);
        if !se_admite(entrada.fee, entrada.peso, base, ctx.mlt) {
            return Err(MempoolError::TarifaInsuficiente);
        }

        // Hacer sitio si hace falta.
        while self.peso_total.saturating_add(entrada.peso) > self.peso_maximo {
            let Some((id_barata, tarifa_barata)) = self.mas_barata() else {
                // No queda nada que desalojar y aun así no cabe.
                return Err(MempoolError::NoCabe { peso: entrada.peso });
            };
            if tarifa_barata >= entrada.fee_por_peso_escalado() {
                // Lo que hay paga igual o más: la entrante no merece el sitio.
                return Err(MempoolError::NoCabe { peso: entrada.peso });
            }
            self.retirar(&id_barata);
        }

        self.peso_total = self.peso_total.saturating_add(entrada.peso);
        self.entradas.insert(id, entrada);
        Ok(())
    }

    /// Retira una transacción, devolviéndola si estaba.
    pub fn retirar(&mut self, id: &TxId) -> Option<Entrada> {
        let e = self.entradas.remove(id)?;
        self.peso_total = self.peso_total.saturating_sub(e.peso);
        Some(e)
    }

    /// La transacción con menor comisión por peso, para desalojar.
    ///
    /// El desempate es por **txid**, no por orden de inserción: así dos nodos con el mismo mempool
    /// desalojan lo mismo. No es consenso, pero un comportamiento reproducible es más fácil de
    /// depurar que uno que depende del orden de llegada.
    fn mas_barata(&self) -> Option<(TxId, u128)> {
        self.entradas
            .iter()
            .map(|(id, e)| (*id, e.fee_por_peso_escalado()))
            .min_by(|a, b| a.1.cmp(&b.1).then_with(|| a.0.cmp(&b.0)))
    }

    /// Selecciona transacciones para un bloque, sin exceder `limite_peso`.
    ///
    /// Ordena por comisión por peso descendente, con el **txid** como desempate para que la
    /// selección sea reproducible. Es un voraz simple: no resuelve la mochila óptima, y no falta —
    /// con transacciones pequeñas frente al límite del bloque, la diferencia es despreciable.
    ///
    /// ⚠️ **No comprueba dependencias entre transacciones del mempool.** Si una gasta la salida de
    /// otra que también está en espera, el llamante **MUST** ordenarlas o descartar la dependiente:
    /// C-BLK-09 y C-TX-13 se validan al construir el bloque, no aquí.
    #[must_use]
    pub fn seleccionar(&self, limite_peso: u64) -> Vec<(TxId, &Entrada)> {
        let mut candidatas: Vec<_> = self.entradas.iter().map(|(id, e)| (*id, e)).collect();
        candidatas.sort_by(|a, b| {
            b.1.fee_por_peso_escalado()
                .cmp(&a.1.fee_por_peso_escalado())
                .then_with(|| a.0.cmp(&b.0))
        });

        let mut elegidas = Vec::new();
        let mut peso = 0u64;
        for (id, e) in candidatas {
            let siguiente = peso.saturating_add(e.peso);
            if siguiente <= limite_peso {
                peso = siguiente;
                elegidas.push((id, e));
            }
        }
        elegidas
    }

    /// Retira las transacciones que un bloque acaba de confirmar.
    pub fn confirmar_bloque(&mut self, confirmadas: &[TxId]) {
        for id in confirmadas {
            self.retirar(id);
        }
    }

    /// **C-REORG-04.** Reinserta las transacciones de bloques desconectados.
    ///
    /// Devuelve las que **no** pudieron readmitirse. El llamante **MUST** descartarlas, no
    /// conservarlas: una que ya no es válida —doble gasto por la cadena nueva, coinbase que dejó de
    /// estar maduro— no debe quedarse esperando a que "vuelva a valer".
    ///
    /// Las que vengan de una coinbase **MUST NOT** llegar aquí: una coinbase desconectada no puede
    /// reinsertarse en ningún caso, porque pertenecía a un bloque que ya no existe.
    pub fn reinsertar_tras_reorg(
        &mut self,
        devueltas: Vec<(TxId, Entrada)>,
        ctx: ContextoMempool,
    ) -> Vec<TxId> {
        let mut descartadas = Vec::new();
        for (id, e) in devueltas {
            if self.admitir(id, e, ctx).is_err() {
                descartadas.push(id);
            }
        }
        descartadas
    }
}

#[cfg(test)]
#[expect(clippy::unwrap_used, reason = "los tests fallan con panic por diseño")]
mod tests {
    use super::{ContextoMempool, Entrada, Mempool};
    use crate::error::MempoolError;
    use crate::tarifa::tarifa_minima;
    use zx_consensus::emision::recompensa_base;
    use zx_consensus::peso::{MAX_TX_WEIGHT, MedianaLarga, ZONA_LIBRE};
    use zx_core::amount::Amount;
    use zx_core::digest::{Digest, TxId};
    use zx_core::firma::ClavePublica;
    use zx_core::tx::{Lock, Tx, TxOut};

    fn ctx() -> ContextoMempool {
        ContextoMempool {
            altura: 100,
            mlt: MedianaLarga::nueva(ZONA_LIBRE),
            emitido: 0,
        }
    }

    fn id(n: u8) -> TxId {
        TxId::from_digest(Digest::from_bytes([n; 32]))
    }

    fn tx_vacia() -> Tx {
        Tx {
            version: 1,
            inputs: vec![],
            outputs: vec![TxOut {
                value: Amount::CERO,
                lock: Lock::PubKey {
                    pubkey: ClavePublica::desde_bytes([0; 32]),
                },
            }],
            lock_time: 0,
            expiry_height: 0,
        }
    }

    /// Tarifa mínima para ese peso en el contexto por defecto, más un margen.
    fn fee_suficiente(peso: u64) -> u128 {
        tarifa_minima(peso, recompensa_base(0), MedianaLarga::nueva(ZONA_LIBRE)) * 2
    }

    fn entrada(peso: u64, fee: u128) -> Entrada {
        Entrada {
            tx: tx_vacia(),
            testigos: vec![],
            peso,
            fee,
            altura_entrada: 100,
        }
    }

    #[test]
    fn se_admite_una_transaccion_que_paga_lo_suficiente() {
        let mut m = Mempool::nuevo(1_000_000);
        let peso = 350;
        m.admitir(id(1), entrada(peso, fee_suficiente(peso)), ctx())
            .unwrap();
        assert_eq!(m.len(), 1);
        assert_eq!(m.peso_total(), peso);
        assert!(m.contiene(&id(1)));
    }

    #[test]
    fn se_rechaza_una_transaccion_que_no_paga() {
        let mut m = Mempool::nuevo(1_000_000);
        let e = m.admitir(id(1), entrada(350, 1), ctx()).unwrap_err();
        assert!(matches!(e, MempoolError::TarifaInsuficiente));
        assert!(m.is_empty(), "no debe quedar rastro de un rechazo");
    }

    /// Y el mensaje deja claro que rechazar aquí **no es invalidar** (C-TX-15).
    #[test]
    fn el_rechazo_por_tarifa_no_dice_invalida() {
        let e = MempoolError::TarifaInsuficiente;
        let texto = format!("{e}");
        assert!(
            texto.contains("NO invalida"),
            "el error MUST desambiguar: {texto}"
        );
    }

    #[test]
    fn no_se_admite_dos_veces_la_misma() {
        let mut m = Mempool::nuevo(1_000_000);
        let peso = 350;
        m.admitir(id(1), entrada(peso, fee_suficiente(peso)), ctx())
            .unwrap();
        let e = m
            .admitir(id(1), entrada(peso, fee_suficiente(peso)), ctx())
            .unwrap_err();
        assert!(matches!(e, MempoolError::YaPresente));
        assert_eq!(m.len(), 1);
    }

    #[test]
    fn se_rechaza_por_encima_de_max_tx_weight() {
        let mut m = Mempool::nuevo(u64::MAX);
        let peso = MAX_TX_WEIGHT + 1;
        let e = m
            .admitir(id(1), entrada(peso, fee_suficiente(peso)), ctx())
            .unwrap_err();
        assert!(matches!(e, MempoolError::ExcedeMaxTxWeight { .. }));
    }

    /// **El desalojo solo ocurre si la entrante paga más.**
    ///
    /// Sin esa condición, un atacante vaciaría el mempool a base de transacciones baratas: cada una
    /// echaría a otra sin aportar nada.
    #[test]
    fn una_transaccion_barata_no_desaloja_a_una_cara() {
        let peso = 1_000;
        let mut m = Mempool::nuevo(peso); // cabe exactamente una

        let cara = entrada(peso, fee_suficiente(peso) * 10);
        m.admitir(id(1), cara, ctx()).unwrap();

        let barata = entrada(peso, fee_suficiente(peso));
        let e = m.admitir(id(2), barata, ctx()).unwrap_err();
        assert!(matches!(e, MempoolError::NoCabe { .. }), "{e:?}");
        assert!(m.contiene(&id(1)), "la cara sigue dentro");
        assert!(!m.contiene(&id(2)));
    }

    /// Y al revés: una que paga más **sí** desaloja.
    #[test]
    fn una_transaccion_cara_desaloja_a_una_barata() {
        let peso = 1_000;
        let mut m = Mempool::nuevo(peso);

        m.admitir(id(1), entrada(peso, fee_suficiente(peso)), ctx())
            .unwrap();
        m.admitir(id(2), entrada(peso, fee_suficiente(peso) * 10), ctx())
            .unwrap();

        assert!(!m.contiene(&id(1)), "la barata salió");
        assert!(m.contiene(&id(2)), "la cara entró");
        assert_eq!(m.len(), 1);
        assert_eq!(m.peso_total(), peso, "el peso se recalcula al desalojar");
    }

    /// La selección prioriza comisión por peso, no comisión absoluta.
    ///
    /// Una transacción enorme que paga mucho en total puede rentar menos por byte que una pequeña
    /// que paga poco — y el bloque tiene límite de peso, no de número de transacciones.
    #[test]
    fn se_selecciona_por_comision_por_peso_no_absoluta() {
        let mut m = Mempool::nuevo(1_000_000);

        // Gorda: paga mucho en total, poco por peso.
        m.admitir(id(1), entrada(10_000, fee_suficiente(10_000) * 2), ctx())
            .unwrap();
        // Fina: paga poco en total, mucho por peso.
        m.admitir(id(2), entrada(500, fee_suficiente(500) * 20), ctx())
            .unwrap();

        let sel = m.seleccionar(1_000_000);
        assert_eq!(sel.len(), 2);
        assert_eq!(
            sel.first().unwrap().0,
            id(2),
            "la de mayor comisión por peso va primera"
        );
    }

    #[test]
    fn la_seleccion_respeta_el_limite_de_peso() {
        let mut m = Mempool::nuevo(1_000_000);
        for n in 1..=10u8 {
            let peso = 1_000;
            m.admitir(
                id(n),
                entrada(peso, fee_suficiente(peso) * u128::from(n)),
                ctx(),
            )
            .unwrap();
        }
        let sel = m.seleccionar(3_500);
        let total: u64 = sel.iter().map(|(_, e)| e.peso).sum();
        assert!(total <= 3_500, "MUST NOT exceder el límite: {total}");
        assert_eq!(sel.len(), 3, "caben tres de mil");
        // Y son las tres que más pagan.
        assert_eq!(sel.first().unwrap().0, id(10));
    }

    /// La selección es **reproducible**: dos nodos con el mismo mempool eligen lo mismo.
    #[test]
    fn la_seleccion_es_reproducible() {
        let mut m = Mempool::nuevo(1_000_000);
        // Todas con la misma comisión por peso, para forzar el desempate.
        for n in 1..=8u8 {
            let peso = 1_000;
            m.admitir(id(n), entrada(peso, fee_suficiente(peso)), ctx())
                .unwrap();
        }
        let a: Vec<_> = m.seleccionar(4_000).into_iter().map(|(i, _)| i).collect();
        for _ in 0..5 {
            let b: Vec<_> = m.seleccionar(4_000).into_iter().map(|(i, _)| i).collect();
            assert_eq!(a, b, "el desempate por txid hace la selección determinista");
        }
    }

    #[test]
    fn confirmar_un_bloque_retira_sus_transacciones() {
        let mut m = Mempool::nuevo(1_000_000);
        let peso = 500;
        for n in 1..=3u8 {
            m.admitir(id(n), entrada(peso, fee_suficiente(peso)), ctx())
                .unwrap();
        }
        m.confirmar_bloque(&[id(1), id(3)]);
        assert_eq!(m.len(), 1);
        assert!(m.contiene(&id(2)));
        assert_eq!(m.peso_total(), peso, "el peso baja con las retiradas");
    }

    /// **C-REORG-04.** Las que vuelven se readmiten; las que ya no valen se **descartan**.
    #[test]
    fn tras_un_reorg_lo_que_no_se_readmite_se_descarta() {
        let mut m = Mempool::nuevo(1_000_000);
        let peso = 500;

        let devueltas = vec![
            (id(1), entrada(peso, fee_suficiente(peso))), // paga: entra
            (id(2), entrada(peso, 1)),                    // no paga: se descarta
        ];
        let descartadas = m.reinsertar_tras_reorg(devueltas, ctx());

        assert!(m.contiene(&id(1)));
        assert!(!m.contiene(&id(2)));
        assert_eq!(
            descartadas,
            vec![id(2)],
            "MUST devolverse para que el llamante las descarte"
        );
    }

    /// Una transacción de peso cero no rompe la división de la comisión por peso.
    #[test]
    fn una_transaccion_de_peso_cero_no_divide_por_cero() {
        let e = entrada(0, 1_000);
        assert_eq!(
            e.fee_por_peso_escalado(),
            0,
            "peso cero da cero, no un panic"
        );
    }

    /// La comisión por peso multiplica antes de dividir: si no, las transacciones grandes de
    /// comisión pequeña se aplastarían todas a cero y serían indistinguibles al ordenar.
    #[test]
    fn la_comision_por_peso_no_pierde_precision() {
        let grande_barata = entrada(100_000, 150_000);
        let grande_mas_barata = entrada(100_000, 100_000);
        assert!(
            grande_barata.fee_por_peso_escalado() > grande_mas_barata.fee_por_peso_escalado(),
            "dividir primero las habría igualado a 1, haciéndolas indistinguibles"
        );
    }
}
