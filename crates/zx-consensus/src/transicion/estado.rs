//! Estado, invariantes y mutación con undo por delta.
//!
//! El motor funcional clona el estado de entrada y lo muta a través de [`Aplicador`], que registra
//! en un [`Undo`] el valor previo de cada clave tocada. `deshacer` restituye exactamente el estado
//! previo (§3.5, `I-2`).

use primitive_types::U256;
use zx_core::{Amount, ClavePublica, OutPoint};

use crate::transicion::tipos::{
    EntradaUtxo, Escalares, Estado, Fase, Garantia, Marca, Origen, ParametrosTransicion, Pendiente,
    Punto, Undo,
};

impl Estado {
    /// Estado inicial (fase génesis, todo vacío).
    #[must_use]
    pub fn inicial() -> Self {
        Self {
            utxo: std::collections::BTreeMap::new(),
            garantias: std::collections::BTreeMap::new(),
            emitido: 0,
            quemado: 0,
            fase: Fase::Genesis,
            terminal: None,
            altura: 0,
            trabajo: U256::zero(),
            slot: 0,
            s0: 0,
            peso_sufijo: 0,
            altura_terminal: None,
            subsidio_acum: 0,
            prox_salida: 0,
        }
    }

    /// Suma de garantía activa total (`Σ activo`).
    #[must_use]
    pub fn garantia_activa_total(&self) -> i128 {
        self.garantias
            .values()
            .map(|g| i128::from(g.activo.brek()))
            .sum()
    }

    /// Garantía activa de una clave (cero si no existe).
    #[must_use]
    pub fn activo_de(&self, clave: &ClavePublica) -> Amount {
        self.garantias.get(clave).map_or(Amount::CERO, |g| g.activo)
    }
}

/// Predicado de activación `Φ` (`TRN-04`, `SEC-0`): `Σ activo ≥ S_min` y `#claves ≥ K_min`.
#[must_use]
pub fn phi(estado: &Estado, params: &ParametrosTransicion) -> bool {
    let mut total: i128 = 0;
    let mut claves: u32 = 0;
    for g in estado.garantias.values() {
        total += i128::from(g.activo.brek());
        if g.activo >= params.q {
            claves += 1;
        }
    }
    total >= i128::from(params.s_min.brek()) && claves >= params.k_min
}

/// Madurez de una salida `coinbase_pow` en un punto dado (`TRN-02`, `TRN-02b`).
#[must_use]
pub fn gastable_en(
    entrada: &EntradaUtxo,
    fase: Fase,
    altura_terminal: Option<u32>,
    s0: u64,
    params: &ParametrosTransicion,
    punto: Punto,
) -> bool {
    if entrada.origen != Origen::CoinbasePow {
        return true;
    }
    let Punto::Altura(creada) = entrada.creada else {
        return true;
    };
    let Some(madura) = creada.checked_add(params.m_cb) else {
        return false;
    };
    match fase {
        Fase::PoW => punto.como_altura().is_some_and(|h| h >= madura),
        Fase::PoST => {
            if altura_terminal.is_some_and(|at| madura <= at) {
                return true;
            }
            match (punto.como_slot(), s0.checked_add(params.m_res_slots)) {
                (Some(s), Some(tope)) => s >= tope,
                _ => false,
            }
        }
        Fase::Genesis => false,
    }
}

/// Suma de valor del UTXO.
#[must_use]
pub fn suma_utxo(estado: &Estado) -> i128 {
    estado
        .utxo
        .values()
        .map(|e| i128::from(e.valor.brek()))
        .sum()
}

/// Suma de valor inmovilizado en garantías (activo, congelado, pendientes, créditos y retiradas).
#[must_use]
pub fn suma_garantias(estado: &Estado) -> i128 {
    let mut total: i128 = 0;
    for g in estado.garantias.values() {
        total += i128::from(g.activo.brek()) + i128::from(g.congelado.brek());
        for p in &g.pendientes {
            total += i128::from(p.importe.brek());
        }
        for p in &g.creditos {
            total += i128::from(p.importe.brek());
        }
        for r in &g.en_retirada {
            total += i128::from(r.importe.brek());
        }
    }
    total
}

/// `I-1`: `Σ UTXO + Σ garantías == Emitido − Quemado`.
#[must_use]
pub fn invariante_i1(estado: &Estado) -> bool {
    suma_utxo(estado) + suma_garantias(estado) == estado.emitido - estado.quemado
}

/// `I-1b`: `Emitido ≤ Σ subsidios`.
#[must_use]
pub fn invariante_i1b(estado: &Estado) -> bool {
    estado.emitido <= estado.subsidio_acum
}

/// Restituye el estado previo a partir del undo por delta (`I-2`, `R-14`).
#[must_use]
pub fn deshacer(estado: &Estado, undo: &Undo) -> Estado {
    let mut restaurado = estado.clone();
    restaurado.emitido = undo.escalares.emitido;
    restaurado.quemado = undo.escalares.quemado;
    restaurado.fase = undo.escalares.fase;
    restaurado.terminal = undo.escalares.terminal;
    restaurado.altura = undo.escalares.altura;
    restaurado.trabajo = undo.escalares.trabajo;
    restaurado.slot = undo.escalares.slot;
    restaurado.s0 = undo.escalares.s0;
    restaurado.peso_sufijo = undo.escalares.peso_sufijo;
    restaurado.altura_terminal = undo.escalares.altura_terminal;
    restaurado.subsidio_acum = undo.escalares.subsidio_acum;
    restaurado.prox_salida = undo.escalares.prox_salida;
    for (op, previa) in &undo.utxo {
        match previa {
            Some(e) => {
                restaurado.utxo.insert(*op, e.clone());
            }
            None => {
                restaurado.utxo.remove(op);
            }
        }
    }
    for (clave, previa) in &undo.garantias {
        match previa {
            Some(g) => {
                restaurado.garantias.insert(*clave, g.clone());
            }
            None => {
                restaurado.garantias.remove(clave);
            }
        }
    }
    restaurado
}

/// Estado en construcción con su undo por delta.
pub(crate) struct Aplicador {
    /// Estado en curso.
    pub estado: Estado,
    /// Undo acumulado.
    pub undo: Undo,
}

impl Aplicador {
    /// Arranca desde `estado` y registra sus escalares previos.
    #[must_use]
    pub fn nuevo(estado: Estado) -> Self {
        let undo = Undo {
            escalares: Escalares::from(&estado),
            utxo: Vec::new(),
            garantias: Vec::new(),
            utxo_vistos: std::collections::BTreeSet::new(),
            garantia_vistos: std::collections::BTreeSet::new(),
        };
        Self { estado, undo }
    }

    /// Marca la posición actual del undo.
    #[must_use]
    pub fn marcar(&self) -> Marca {
        Marca {
            utxo: self.undo.utxo.len(),
            garantias: self.undo.garantias.len(),
        }
    }

    /// Revierte las mutaciones registradas después de `marca` (usado al descartar en fusión).
    pub fn revertir_a(&mut self, marca: Marca) {
        while self.undo.garantias.len() > marca.garantias {
            if let Some((clave, previa)) = self.undo.garantias.pop() {
                self.undo.garantia_vistos.remove(&clave);
                match previa {
                    Some(g) => {
                        self.estado.garantias.insert(clave, g);
                    }
                    None => {
                        self.estado.garantias.remove(&clave);
                    }
                }
            }
        }
        while self.undo.utxo.len() > marca.utxo {
            if let Some((op, previa)) = self.undo.utxo.pop() {
                self.undo.utxo_vistos.remove(&op);
                match previa {
                    Some(e) => {
                        self.estado.utxo.insert(op, e);
                    }
                    None => {
                        self.estado.utxo.remove(&op);
                    }
                }
            }
        }
    }

    fn tocar_utxo(&mut self, op: OutPoint) {
        if self.undo.utxo_vistos.insert(op) {
            let previa = self.estado.utxo.get(&op).cloned();
            self.undo.utxo.push((op, previa));
        }
    }

    fn tocar_garantia(&mut self, clave: ClavePublica) {
        if self.undo.garantia_vistos.insert(clave) {
            let previa = self.estado.garantias.get(&clave).cloned();
            self.undo.garantias.push((clave, previa));
        }
    }

    /// Inserta una salida, registrando el valor previo (incluida su ausencia).
    pub fn insertar_utxo(&mut self, op: OutPoint, entrada: EntradaUtxo) {
        self.tocar_utxo(op);
        self.estado.utxo.insert(op, entrada);
    }

    /// Retira una salida, registrando el valor previo.
    pub fn borrar_utxo(&mut self, op: OutPoint) {
        self.tocar_utxo(op);
        self.estado.utxo.remove(&op);
    }

    /// Acceso mutable a la garantía de una clave, creándola si no existe y registrando el undo.
    pub fn garantia_mut(&mut self, clave: ClavePublica) -> &mut Garantia {
        self.tocar_garantia(clave);
        self.estado
            .garantias
            .entry(clave)
            .or_insert_with(Garantia::nueva)
    }

    /// Promueve a `activo` los pendientes y créditos madurados en `punto` (paso (b) de §3.9).
    pub fn promover(
        &mut self,
        punto: Punto,
        es_post: bool,
        params: &ParametrosTransicion,
    ) -> Result<(), crate::transicion::ErrorTransicion> {
        use crate::transicion::ErrorTransicion;
        let claves: Vec<ClavePublica> = self.estado.garantias.keys().copied().collect();
        for clave in claves {
            self.tocar_garantia(clave);
            let Some(g) = self.estado.garantias.get_mut(&clave) else {
                return Err(ErrorTransicion::ErrGenesis);
            };
            let mut quedan: Vec<Pendiente> = Vec::with_capacity(g.pendientes.len());
            for p in g.pendientes.drain(..) {
                let madura = if es_post {
                    matches!(
                        (p.madura_en_slot, punto.como_slot()),
                        (Some(s), Some(ps)) if s <= ps
                    )
                } else {
                    matches!(
                        (p.madura_en_altura, punto.como_altura()),
                        (Some(h), Some(ph)) if h <= ph
                    )
                };
                if madura {
                    g.activo = g
                        .activo
                        .suma_comprobada(p.importe)
                        .ok_or(ErrorTransicion::ErrDesbordamiento)?;
                } else {
                    quedan.push(p);
                }
            }
            g.pendientes = quedan;
            if es_post {
                let mut quedan_creditos: Vec<Pendiente> = Vec::with_capacity(g.creditos.len());
                for p in g.creditos.drain(..) {
                    let madura = matches!(
                        (p.madura_en_slot, punto.como_slot()),
                        (Some(s), Some(ps)) if s <= ps
                    );
                    if madura {
                        g.activo = g
                            .activo
                            .suma_comprobada(p.importe)
                            .ok_or(ErrorTransicion::ErrDesbordamiento)?;
                    } else {
                        quedan_creditos.push(p);
                    }
                }
                g.creditos = quedan_creditos;
            }
            let _ = params;
        }
        Ok(())
    }
}

/// Empuja un pendiente y lo promueve de inmediato si su madurez ya se cumple (`R-4`).
pub(crate) fn acreditar_pendiente(
    g: &mut Garantia,
    pendiente: Pendiente,
    punto: Punto,
    es_post: bool,
) -> Result<(), crate::transicion::ErrorTransicion> {
    use crate::transicion::ErrorTransicion;
    let madura = if es_post {
        matches!(
            (pendiente.madura_en_slot, punto.como_slot()),
            (Some(s), Some(ps)) if s <= ps
        )
    } else {
        matches!(
            (pendiente.madura_en_altura, punto.como_altura()),
            (Some(h), Some(ph)) if h <= ph
        )
    };
    if madura {
        g.activo = g
            .activo
            .suma_comprobada(pendiente.importe)
            .ok_or(ErrorTransicion::ErrDesbordamiento)?;
    } else if es_post {
        g.pendientes.push(Pendiente {
            madura_en_altura: None,
            ..pendiente
        });
    } else {
        g.pendientes.push(pendiente);
    }
    Ok(())
}

/// Acredita un **crédito** de coinbase PoST (D-T08): a `creditos` si aún no madura, a `activo` si ya
/// se cumple su slot de madurez (`R-4`).
pub(crate) fn acreditar_credito(
    g: &mut Garantia,
    pendiente: Pendiente,
    punto: Punto,
) -> Result<(), crate::transicion::ErrorTransicion> {
    use crate::transicion::ErrorTransicion;
    let madura = matches!(
        (pendiente.madura_en_slot, punto.como_slot()),
        (Some(s), Some(ps)) if s <= ps
    );
    if madura {
        g.activo = g
            .activo
            .suma_comprobada(pendiente.importe)
            .ok_or(ErrorTransicion::ErrDesbordamiento)?;
    } else {
        g.creditos.push(pendiente);
    }
    Ok(())
}
