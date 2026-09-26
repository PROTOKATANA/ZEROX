//! Árbol Merkle binario de chunks y camino de apertura.
//!
//! Construcción fijada por ORDEN-S01 §3:
//!
//! ```text
//! nodo   = H_d("ZZKSectorNodo___", izquierdo 32 B ‖ derecho 32 B)
//! vacío  = H_d("ZZKSectorVacio__", "")
//! raíz   = raíz Merkle binaria sobre hoja(0 .. n−1), relleno con `vacío` hasta potencia de dos
//! ```
//!
//! El árbol se materializa por niveles para poder extraer un camino sin recalcularlo. La memoria es
//! `2·m·32 B` para `m = next_pow2(n)` hojas; con `pieces_in_sector ≤ 4` (el máximo medido en S01)
//! `m ≤ 131072` y el árbol queda por debajo de 9 MiB, acotado y preasignado.

use crate::h_d::{TAG_NODO, TAG_VACIO, h_d};

/// Nodo interno: `H_d(TAG_NODO, izq ‖ der)`.
#[must_use]
pub fn nodo(izquierdo: &[u8; 32], derecho: &[u8; 32]) -> [u8; 32] {
    let mut msg = [0u8; 64];
    msg[..32].copy_from_slice(izquierdo);
    msg[32..].copy_from_slice(derecho);
    h_d(&TAG_NODO, &msg)
}

/// Relleno de hoja vacía: `H_d(TAG_VACIO, "")`.
#[must_use]
pub fn vacio() -> [u8; 32] {
    h_d(&TAG_VACIO, b"")
}

/// Árbol Merkle por niveles. `niveles[0]` son las hojas (ya rellenadas a potencia de dos);
/// `niveles.last()` contiene la raíz en la posición 0.
#[derive(Debug, Clone)]
pub struct Merkle {
    niveles: Vec<Vec<[u8; 32]>>,
}

impl Merkle {
    /// Construye el árbol sobre `hojas` (al menos una), rellenando hasta potencia de dos.
    ///
    /// # Panics
    ///
    /// Si `hojas` está vacío: un sector sin chunks no es un objeto comprometible y no se admite.
    #[must_use]
    pub fn nuevo(hojas: &[[u8; 32]]) -> Self {
        assert!(
            !hojas.is_empty(),
            "un sector sin hojas no es un objeto comprometible"
        );
        let tamano = hojas.len().next_power_of_two();
        let mut nivel_actual = Vec::with_capacity(tamano);
        nivel_actual.extend_from_slice(hojas);
        nivel_actual.resize(tamano, vacio());

        let mut niveles = vec![nivel_actual];
        while niveles.last().map_or(0, Vec::len) > 1 {
            let anterior = niveles.last().expect("hay un nivel; qed");
            let siguiente: Vec<[u8; 32]> = anterior
                .chunks_exact(2)
                .map(|par| {
                    // `chunks_exact(2)` sobre longitud par garantiza dos elementos.
                    let izq = &par[0];
                    let der = &par[1];
                    nodo(izq, der)
                })
                .collect();
            niveles.push(siguiente);
        }
        Self { niveles }
    }

    /// Hojas rellenadas (nivel 0).
    #[must_use]
    pub fn hojas(&self) -> &[[u8; 32]] {
        &self.niveles[0]
    }

    /// Número de hojas rellenadas (potencia de dos).
    #[must_use]
    pub fn hojas_rellenadas(&self) -> usize {
        self.niveles[0].len()
    }

    /// Nivel `k` del árbol (`k = 0` son las hojas, `k = profundidad` la raíz).
    ///
    /// S02a lo usa para simular la estrategia «guardar solo los nodos del nivel L».
    #[must_use]
    pub fn nivel(&self, k: usize) -> &[[u8; 32]] {
        &self.niveles[k]
    }

    /// Profundidad del árbol (`log2` del número de hojas rellenadas).
    #[must_use]
    pub fn profundidad(&self) -> usize {
        self.niveles.len() - 1
    }

    /// Raíz del árbol.
    #[must_use]
    pub fn raiz(&self) -> [u8; 32] {
        self.niveles
            .last()
            .and_then(|nivel| nivel.first())
            .copied()
            .expect("el árbol siempre tiene raíz; qed")
    }

    /// Camino de apertura para la hoja `indice`: un hermano por nivel, de abajo arriba.
    ///
    /// # Panics
    ///
    /// Si `indice` cae fuera del nivel de hojas.
    #[must_use]
    pub fn camino(&self, indice: usize) -> Vec<[u8; 32]> {
        assert!(
            indice < self.hojas_rellenadas(),
            "índice de hoja fuera del árbol"
        );
        let mut camino = Vec::with_capacity(self.niveles.len().saturating_sub(1));
        let mut i = indice;
        for nivel in &self.niveles[..self.niveles.len() - 1] {
            camino.push(nivel[i ^ 1]);
            i /= 2;
        }
        camino
    }
}

/// Recalcula la raíz desde una hoja y su camino. Devuelve `None` si `camino` no tiene la longitud
/// `log2(next_pow2(n))` que corresponde a `n` hojas, o si `indice >= n`.
#[must_use]
pub fn raiz_desde_camino(
    indice: usize,
    hoja: [u8; 32],
    camino: &[[u8; 32]],
    n: usize,
) -> Option<[u8; 32]> {
    if n == 0 || indice >= n {
        return None;
    }
    let m = n.next_power_of_two();
    let profundidad = m.trailing_zeros() as usize;
    if camino.len() != profundidad {
        return None;
    }
    let mut actual = hoja;
    let mut i = indice;
    for hermano in camino {
        actual = if i & 1 == 0 {
            nodo(&actual, hermano)
        } else {
            nodo(hermano, &actual)
        };
        i >>= 1;
    }
    Some(actual)
}

#[cfg(test)]
mod tests {
    use super::{Merkle, raiz_desde_camino};

    fn hojita(i: u8) -> [u8; 32] {
        let mut h = [0u8; 32];
        h[0] = i;
        h
    }

    #[test]
    fn todo_camino_reconstruye_la_raiz() {
        for n in [1usize, 2, 3, 5, 8] {
            let hojas: Vec<[u8; 32]> = (0..n as u8).map(hojita).collect();
            let arbol = Merkle::nuevo(&hojas);
            for i in 0..n {
                let camino = arbol.camino(i);
                assert_eq!(
                    raiz_desde_camino(i, hojas[i], &camino, n),
                    Some(arbol.raiz()),
                    "n = {n}, hoja {i}"
                );
            }
        }
    }

    #[test]
    fn un_camino_de_otra_posicion_no_reconstruye() {
        let hojas: Vec<[u8; 32]> = (0..4u8).map(hojita).collect();
        let arbol = Merkle::nuevo(&hojas);
        let camino = arbol.camino(0);
        assert_ne!(
            raiz_desde_camino(1, hojas[1], &camino, 4),
            Some(arbol.raiz())
        );
    }
}
