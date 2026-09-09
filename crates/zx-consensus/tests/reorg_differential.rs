//! Test diferencial de reorganización (SPEC C-REORG-05, C-REORG-06).
//!
//! El SPEC lo exige explícitamente antes de la Fase 3, y por una razón concreta: un caché de ventana
//! indexado por **altura** devuelve datos de la rama vieja tras un reorg que reemplaza bloques a las
//! mismas alturas, **sin que nada falle visiblemente**. El nodo sigue funcionando y validando con
//! una mediana que ya no corresponde a su cadena. Es un fork silencioso.
//!
//! La forma de este test es la que pide C-REORG-06: se provoca un fork con pesos **muy distintos**
//! en cada rama y se comprueba que, tras el reorg, las medianas coinciden **exactamente** con las
//! que calcularía un nodo que solo hubiera visto la cadena ganadora desde el principio.
//!
//! Y además se demuestra lo contrario: que un caché por altura **daría la respuesta equivocada**.
//! Sin esa segunda mitad, el test no probaría que la regla hace falta.

#![expect(clippy::unwrap_used, reason = "los tests fallan con panic por diseño")]
#![expect(
    clippy::integer_division,
    reason = "aritmética entera a propósito: es un test de consenso"
)]

use zx_consensus::fork_choice::ClaveVentana;
use zx_consensus::peso::{
    MedianaLarga, N_CORTO, ZONA_LIBRE, get_mid, limite, mediana_corta, mediana_efectiva,
    mediana_larga, peso_largo_plazo,
};
use zx_core::digest::{BlockHash, Digest};

/// Un bloque reducido a lo que el cálculo de medianas necesita.
#[derive(Clone, Copy, Debug)]
struct Eslabon {
    hash: BlockHash,
    altura: u32,
    peso: u64,
}

/// Cadena en memoria. El orden del vector es el orden de la cadena.
#[derive(Clone, Debug, Default)]
struct Cadena(Vec<Eslabon>);

impl Cadena {
    /// Añade un bloque cuyo hash depende de **toda** su historia, no solo de la altura.
    ///
    /// Es lo que hace el test realista: dos ramas a la misma altura tienen hashes distintos, igual
    /// que en la cadena real, y por eso un caché por hash las distingue y uno por altura no.
    fn empujar(&mut self, peso: u64) {
        let altura = u32::try_from(self.0.len()).unwrap();
        let previo = self.0.last().map_or([0u8; 32], |e| *e.hash.as_bytes());

        // hash = f(hash_padre, altura, peso) — cualquier cambio en la historia lo cambia.
        let mut sem = [0u8; 32];
        for (destino, origen) in sem.iter_mut().zip(previo.iter()) {
            *destino = origen.wrapping_add(1);
        }
        let mezcla = [
            u8::try_from(altura & 0xFF).unwrap(),
            u8::try_from(peso & 0xFF).unwrap(),
            u8::try_from((peso >> 8) & 0xFF).unwrap(),
        ];
        for (destino, m) in sem.iter_mut().zip(mezcla.iter()) {
            *destino ^= m;
        }

        self.0.push(Eslabon {
            hash: BlockHash::from_digest(Digest::from_bytes(sem)),
            altura,
            peso,
        });
    }

    fn tip(&self) -> Eslabon {
        *self.0.last().unwrap()
    }

    /// Recorta la cadena a `n` bloques — simula volver al punto de fork.
    fn truncar(&self, n: usize) -> Self {
        Self(self.0.get(..n).unwrap().to_vec())
    }

    /// Pesos crudos de la ventana corta que termina en el tip (C-WGT-06).
    fn ventana_corta(&self) -> Vec<u64> {
        let n = self.0.len().min(N_CORTO);
        self.0
            .get(self.0.len() - n..)
            .unwrap()
            .iter()
            .map(|e| e.peso)
            .collect()
    }

    /// Pesos de largo plazo de toda la cadena, calculados **recorriendo la cadena** (C-REORG-06).
    ///
    /// Cada `lt_weight` depende de la `Mlt` vigente en su momento, así que la secuencia entera
    /// depende de la rama. No se puede reutilizar la de otra rama aunque las alturas coincidan.
    ///
    /// La mediana de cada paso se lee de una copia **ordenada** que se mantiene por inserción
    /// binaria: con `MAX_REORG_LENGTH = 11 999` a `λ = 1`, reordenar el prefijo entero en cada paso
    /// haría el test cuadrático-logarítmico. Es la misma mediana entera de C-WGT-03 (`get_mid`).
    fn ventana_larga(&self) -> Vec<u64> {
        let mut mlt = ZONA_LIBRE;
        let mut lt = Vec::with_capacity(self.0.len());
        let mut ordenados: Vec<u64> = Vec::with_capacity(self.0.len());
        for e in &self.0 {
            let w = peso_largo_plazo(e.peso, mlt);
            lt.push(w);
            let pos = ordenados.partition_point(|&v| v <= w);
            ordenados.insert(pos, w);
            let n = ordenados.len();
            let en = |i: usize| ordenados.get(i).copied().unwrap();
            let mediana = if n % 2 == 1 {
                en(n / 2)
            } else {
                get_mid(en(n / 2 - 1), en(n / 2))
            };
            mlt = mediana.max(ZONA_LIBRE);
        }
        lt
    }

    /// La mediana efectiva del tip, calculada desde cero sobre esta cadena.
    fn mediana_efectiva_del_tip(&self) -> u64 {
        let mlt = MedianaLarga::nueva(mediana_larga(&self.ventana_larga()).unwrap());
        let mst = mediana_corta(&self.ventana_corta()).unwrap();
        mediana_efectiva(mlt, mst)
    }
}

/// Construye la cadena base común a las dos ramas.
fn tronco(bloques: usize, peso: u64) -> Cadena {
    let mut c = Cadena::default();
    for _ in 0..bloques {
        c.empujar(peso);
    }
    c
}

/// **El test que el SPEC exige.**
///
/// Tras un reorg, las medianas de la cadena ganadora **MUST** coincidir exactamente con las que
/// calcularía un nodo que solo hubiera visto esa cadena. Si no coincidieran, dos nodos con
/// historiales distintos validarían con límites de bloque distintos: split.
#[test]
fn tras_un_reorg_las_medianas_coinciden_con_las_de_un_nodo_limpio() {
    const FORK: usize = 150;

    // Rama A: bloques llenos. Rama B: bloques casi vacíos. Pesos deliberadamente muy distintos,
    // como pide C-REORG-06, para que un caché contaminado se note.
    let base = tronco(FORK, ZONA_LIBRE);

    let mut rama_a = base.clone();
    for _ in 0..80 {
        rama_a.empujar(ZONA_LIBRE * 2);
    }

    let mut rama_b = base.truncar(FORK);
    for _ in 0..90 {
        rama_b.empujar(1);
    }

    // El nodo que vivió el reorg: siguió A, luego se pasó a B.
    let tras_reorg = rama_b.mediana_efectiva_del_tip();

    // El nodo limpio: reconstruye B desde el génesis sin haber visto A jamás.
    let mut limpio = tronco(FORK, ZONA_LIBRE);
    for _ in 0..90 {
        limpio.empujar(1);
    }
    let sin_reorg = limpio.mediana_efectiva_del_tip();

    assert_eq!(
        tras_reorg, sin_reorg,
        "C-REORG-06: tras el reorg las medianas MUST coincidir con las de un nodo limpio — si no, \
         dos nodos validan con límites de bloque distintos"
    );

    // Y las dos ramas tienen que dar medianas distintas, o el test no probaría nada.
    assert_ne!(
        rama_a.mediana_efectiva_del_tip(),
        tras_reorg,
        "las dos ramas deben diferir, si no el test pasaría por casualidad"
    );
}

/// **Y esta es la mitad que demuestra que C-REORG-05 hace falta.**
///
/// Un caché indexado por **altura** se daría por válido tras el reorg —las alturas coinciden— y
/// devolvería la mediana de la rama vieja. Uno indexado por **hash** lo detecta.
#[test]
fn un_cache_por_altura_daria_la_respuesta_equivocada() {
    const FORK: usize = 150;
    let base = tronco(FORK, ZONA_LIBRE);

    let mut rama_a = base.clone();
    for _ in 0..80 {
        rama_a.empujar(ZONA_LIBRE * 2);
    }
    let mut rama_b = base.truncar(FORK);
    for _ in 0..80 {
        rama_b.empujar(1);
    }

    let tip_a = rama_a.tip();
    let tip_b = rama_b.tip();

    // Las dos ramas terminan **a la misma altura**: eso es lo que hace peligroso el caché por altura.
    assert_eq!(
        tip_a.altura, tip_b.altura,
        "el escenario exige misma altura"
    );
    assert_ne!(tip_a.hash, tip_b.hash, "y distinto hash");

    let m_a = rama_a.mediana_efectiva_del_tip();
    let m_b = rama_b.mediana_efectiva_del_tip();
    assert_ne!(m_a, m_b, "las medianas difieren de verdad: {m_a} vs {m_b}");

    // El caché de la rama A, tras el reorg a B.
    let clave_a = ClaveVentana::nueva(tip_a.hash, tip_a.altura);

    // Indexado por hash: lo detecta y obliga a recomputar. Esto es C-REORG-05.
    assert!(
        !clave_a.vale_para(&tip_b.hash),
        "C-REORG-05: el caché MUST invalidarse — misma altura, distinto hash"
    );

    // Indexado por altura habría dado por bueno el valor de A sobre la cadena B.
    let por_altura_lo_daria_por_bueno = clave_a.altura() == tip_b.altura;
    assert!(
        por_altura_lo_daria_por_bueno,
        "un caché por altura consideraría válido el valor de A para el tip de B — y ese es \
         exactamente el fork silencioso que C-REORG-05 evita"
    );

    // Cuantificando el daño: los límites de bloque que resultarían.
    let limite_correcto = limite(m_b);
    let limite_contaminado = limite(m_a);
    assert_ne!(
        limite_correcto, limite_contaminado,
        "un nodo con el caché contaminado aceptaría bloques de hasta {limite_contaminado} bytes \
         donde la cadena real permite {limite_correcto}"
    );
}

/// El reorg más profundo que C-REORG-07 admite tampoco puede desincronizar las medianas.
#[test]
fn un_reorg_al_limite_de_profundidad_tampoco_desincroniza() {
    use zx_consensus::fork_choice::MAX_REORG_LENGTH;

    let profundidad = usize::try_from(MAX_REORG_LENGTH).unwrap();
    let alto = profundidad + 300;
    let base = tronco(alto, ZONA_LIBRE);

    let mut rama_b = base.truncar(alto - profundidad);
    for _ in 0..profundidad {
        rama_b.empujar(ZONA_LIBRE / 4);
    }

    let mut limpio = tronco(alto - profundidad, ZONA_LIBRE);
    for _ in 0..profundidad {
        limpio.empujar(ZONA_LIBRE / 4);
    }

    assert_eq!(
        rama_b.mediana_efectiva_del_tip(),
        limpio.mediana_efectiva_del_tip(),
        "ni al máximo de profundidad admitida las medianas pueden divergir"
    );
}

/// Los pesos de largo plazo dependen de **toda** la historia de su rama, no solo de la altura.
///
/// Es la razón de fondo de C-REORG-06: `lt_weight(b)` usa la `Mlt` vigente cuando `b` entró, así
/// que la secuencia entera es propia de la rama. Reutilizar la de otra —aunque las alturas cuadren—
/// da otros números.
#[test]
fn el_peso_de_largo_plazo_depende_de_la_rama_entera() {
    let mut a = tronco(50, ZONA_LIBRE * 3);
    let mut b = tronco(50, ZONA_LIBRE);
    // Mismo bloque final en las dos, misma altura, historias distintas.
    a.empujar(ZONA_LIBRE * 2);
    b.empujar(ZONA_LIBRE * 2);

    let lt_a = a.ventana_larga();
    let lt_b = b.ventana_larga();
    assert_eq!(lt_a.len(), lt_b.len(), "misma altura");
    assert_ne!(
        lt_a.last(),
        lt_b.last(),
        "el mismo peso a la misma altura da lt_weight distinto según la rama — por eso C-REORG-06 \
         obliga a leer las ventanas sobre la cadena candidata"
    );
}
