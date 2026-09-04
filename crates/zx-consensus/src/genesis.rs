//! Bloque génesis (SPEC §15).
//!
//! # Definición constructiva, no bytes hardcodeados
//!
//! El génesis se construye con una función determinista de parámetros explícitos, y su hash se
//! compara contra una constante. Es el patrón de Bitcoin y Zcash, y se eligió sobre el de Monero
//! —transacción coinbase en hexadecimal crudo— por dos razones: es **auditable**, porque se ve de
//! qué parámetros sale, y **falla duro y visible** si alguien toca un parámetro sin recalcular el
//! hash, en lugar de arrancar en silencio sobre un génesis no intencionado.
//!
//! # 🔴 Los parámetros de mainnet están BLOQUEADOS — P-017
//!
//! El mensaje, el timestamp y el nonce se fijan **el día del lanzamiento**, porque C-GEN-05 exige
//! que el mensaje referencie un evento público verificable de esa fecha. Lo que hay aquí es la
//! **maquinaria**, ya probada, con parámetros de marcador de posición explícitos.

use zx_core::amount::Amount;
use zx_core::digest::{BlockHash, Digest, TxId};
use zx_core::firma::ClavePublica;
use zx_core::preimage::block::{BlockHeader, merkle_root};
use zx_core::preimage::tx::txid;
use zx_core::target::{CompactBits, TARGET_INICIAL_BITS_MAINNET, TARGET_INICIAL_BITS_TESTNET};
use zx_core::tx::{Lock, Tx, TxOut};

use crate::activacion::{Red, rama_activa};
use crate::error::ConsensusError;
use crate::validacion::VERSION_TX;

/// Parámetros de los que se construye un génesis (C-GEN-01).
///
/// Que sean explícitos es el punto: cualquiera puede reconstruir el bloque y comprobar el hash.
#[derive(Clone, Copy, Debug)]
pub struct ParametrosGenesis {
    /// Red a la que pertenece.
    pub red: Red,
    /// Mensaje simbólico de la coinbase (C-GEN-05).
    ///
    /// **No tiene función de consenso** — ningún nodo inspecciona su contenido. Su valor es una
    /// comprobación humana, manual y única: que referencie un evento público de la fecha permite a
    /// cualquiera concluir que el bloque no pudo minarse antes.
    ///
    /// Para ZEROX pesa más que en la mayoría de cadenas, porque el proyecto declara "sin premine".
    /// El precedente es Bytecoin, del que Monero nació como fork limpio tras concluirse que ~80 %
    /// del suministro existía antes del lanzamiento anunciado, con timestamps fabricados.
    pub mensaje: &'static [u8],
    /// Segundos Unix del lanzamiento.
    pub timestamp: u64,
    /// Nonce. No hay PoW que resolver (C-GEN-02), así que su única función es separar redes.
    pub nonce: u64,
}

/// 🔴 **P-017.** Parámetros de mainnet — marcador de posición hasta el día del lanzamiento.
///
/// **Están diseñados para NO pasar [`comprobar`].** El `timestamp: 0` incumple C-GEN-06 a
/// propósito, así que un nodo que intente arrancar en mainnet con estos parámetros **aborta con un
/// mensaje que nombra a P-017** en vez de levantar una cadena sobre un génesis no intencionado.
///
/// Es deliberado y hay un test que lo fija: `el_genesis_de_mainnet_todavia_no_arranca`.
pub const GENESIS_MAINNET: ParametrosGenesis = ParametrosGenesis {
    red: Red::Mainnet,
    mensaje: b"PENDIENTE P-017: titular verificable de la fecha de lanzamiento",
    timestamp: 0,
    nonce: 0,
};

/// ✅ Parámetros de **testnet** — reales, no marcador de posición.
///
/// P-017 bloquea los de **mainnet**, no estos: C-GEN-05 pide un mensaje verificable de la fecha de
/// lanzamiento, y testnet no se lanza, se enciende. Lo que testnet necesita es existir, para que
/// `zx-p2p` y `zx-node` tengan una cadena real contra la que sincronizar.
///
/// **MUST** producir un hash distinto al de mainnet (C-GEN-04). Lo garantizan a la vez el mensaje,
/// el nonce, el `bits` y el `CONSENSUS_BRANCH_ID`; el prefijo mágico de C-NET-01 hace el resto del
/// aislamiento a nivel de transporte.
///
/// El timestamp es **2026-09-04 00:00:00 UTC**. No es decorativo — ver C-GEN-06.
pub const GENESIS_TESTNET: ParametrosGenesis = ParametrosGenesis {
    red: Red::Testnet,
    mensaje: b"ZEROX testnet 2026-09-04 - sin valor, se reinicia sin aviso",
    timestamp: 1_788_480_000,
    nonce: 1,
};

/// Hash del génesis de **testnet**, la aserción que C-GEN-01 pide hardcodear.
///
/// No es decorativo: si alguien toca un parámetro de [`GENESIS_TESTNET`] sin recalcular esto, el
/// test `el_hash_del_genesis_de_testnet_esta_congelado` falla y el nodo **no arranca sobre una
/// cadena que no era la que creía**. Es la diferencia entre un error ruidoso y una partición
/// silenciosa de red.
///
/// Mainnet **no tiene** su constante todavía, y no debe tenerla: sus parámetros están bloqueados
/// por P-017 y congelar el hash de un marcador de posición sería congelar el error.
pub const HASH_GENESIS_TESTNET: [u8; 32] = [
    0xfe, 0x56, 0x84, 0x5a, 0x01, 0xba, 0xfa, 0x5a, 0x51, 0xae, 0x43, 0xdd, 0x43, 0xd1, 0x65, 0x84,
    0x96, 0x6f, 0x65, 0xa2, 0xac, 0xb4, 0x1b, 0xc6, 0xfa, 0xc2, 0x81, 0x81, 0x40, 0x62, 0xb6, 0xf1,
];

/// Suelo de plausibilidad del timestamp del génesis: **2026-01-01 00:00:00 UTC** (C-GEN-06).
///
/// ZEROX no existía antes de 2026, así que ningún génesis legítimo puede declarar una fecha
/// anterior. Su función real es que un **marcador de posición no pueda lanzarse por descuido**.
pub const TIMESTAMP_MINIMO_GENESIS: u64 = 1_767_225_600;

/// Coinbase del génesis: **valor cero** (C-GEN-03, C-EMIT-02).
///
/// Sus salidas **MUST NOT** insertarse en el UTXO set. No es que gastarlas esté prohibido por una
/// regla: es que nunca existen. Bitcoin hace lo mismo con un caso especial en `ConnectBlock`.
///
/// El mensaje viaja en el `lock` de una salida de valor cero. Es inconectable por C-GEN-03, así que
/// no crea un UTXO no gastable — simplemente no llega al conjunto.
#[must_use]
pub fn coinbase_genesis(mensaje: &[u8]) -> Tx {
    // El mensaje se compacta a 32 bytes con XOR por posición. No es criptográfico ni pretende
    // serlo: el mensaje íntegro vive en los parámetros, que son públicos y reproducibles.
    //
    // Los 32 bytes ocupan el hueco de una clave pública, y casi con certeza NO son una clave válida
    // — que es justo lo que se quiere: la salida es inconectable por C-GEN-03 y además nadie tiene
    // la privada. Con P2K (P-020) esto es más honesto que antes: ya no finge ser el hash de una
    // clave que existe en alguna parte.
    let mut marca = [0u8; 32];
    for (i, b) in mensaje.iter().enumerate() {
        if let Some(d) = marca.get_mut(i % 32) {
            *d ^= *b;
        }
    }
    Tx {
        version: VERSION_TX,
        inputs: vec![],
        outputs: vec![TxOut {
            value: Amount::CERO,
            lock: Lock::PubKey {
                pubkey: ClavePublica::desde_bytes(marca),
            },
        }],
        lock_time: 0,
        // C-EMIT-04: la coinbase declara su altura. El génesis está en la 0.
        expiry_height: 0,
    }
}

/// `bits` de arranque de cada red (C-DIFF-02, P-004c).
///
/// **Las dos redes llevan valores distintos a propósito.** Mainnet arranca 32 veces más difícil que
/// el mínimo representable, que es la estimación de hashrate con la que el primer bloque dura `T`
/// = 120 s — **lo mismo que cualquier bloque después**, sin arranque artificialmente lento. Testnet
/// se queda en el mínimo, porque una red local de tres nodos tiene que producir bloques deprisa o
/// los tests de integración no sirven.
///
/// El aislamiento entre redes **no** depende de esto: lo garantizan el génesis distinto (C-GEN-04)
/// y el prefijo mágico (C-NET-01). Aquí solo se decide la dificultad de arranque.
#[must_use]
pub const fn target_inicial_bits(red: Red) -> u32 {
    match red {
        Red::Mainnet => TARGET_INICIAL_BITS_MAINNET,
        Red::Testnet => TARGET_INICIAL_BITS_TESTNET,
    }
}

/// Construye el bloque génesis a partir de sus parámetros (C-GEN-01).
///
/// # Errores
/// [`ConsensusError::SinRamaActiva`] si la tabla de ramas de la red está mal formada.
pub fn construir(p: ParametrosGenesis) -> Result<(BlockHeader, Tx), ConsensusError> {
    let cb = coinbase_genesis(p.mensaje);
    let branch_id = rama_activa(p.red, 0)?;
    let raiz = merkle_root(&[txid(&cb, branch_id)]);

    Ok((
        BlockHeader {
            consensus_branch_id: branch_id,
            // El génesis no tiene padre. Cero es el único valor con significado aquí.
            prev_hash: BlockHash::from_digest(Digest::from_bytes([0u8; 32])),
            merkle_root: raiz,
            timestamp: p.timestamp,
            bits: target_inicial_bits(p.red),
            nonce: p.nonce,
            height: 0,
        },
        cb,
    ))
}

/// Comprueba que un génesis construido cumple todas las invariantes de §15.
///
/// Es lo que C-GEN-01 pide que aborte el arranque: se llama al inicializar el nodo, antes de tocar
/// nada más.
///
/// **No comprueba el PoW**: C-GEN-02 lo exime explícitamente. Es una exención estructural, igual
/// que la de Bitcoin en `AcceptBlockHeader`, y no depende de que el génesis satisfaga o no su
/// propio target.
///
/// # Errores
/// [`ConsensusError::GenesisInvalido`] con el motivo concreto.
pub fn comprobar(cabecera: &BlockHeader, coinbase: &Tx) -> Result<(), ConsensusError> {
    let malo = |motivo| ConsensusError::GenesisInvalido { motivo };

    if cabecera.height != 0 {
        return Err(malo("C-HDR-02: el génesis MUST estar en la altura 0"));
    }
    if *cabecera.prev_hash.as_bytes() != [0u8; 32] {
        return Err(malo("el génesis no tiene padre: prev_hash MUST ser cero"));
    }
    if !coinbase.inputs.is_empty() {
        return Err(malo("C-BLK-07: la coinbase no tiene entradas"));
    }
    if coinbase.expiry_height != 0 {
        return Err(malo(
            "C-EMIT-04: la coinbase del génesis declara la altura 0",
        ));
    }
    // C-GEN-03 · valor cero. Sin premine, sin dev tax, sin founder reward.
    let total: i64 = coinbase.outputs.iter().map(|s| s.value.brek()).sum();
    if total != 0 {
        return Err(malo(
            "C-GEN-03/C-EMIT-02: la coinbase del génesis MUST valer cero",
        ));
    }
    // La raíz de Merkle compromete esa coinbase y no otra.
    if merkle_root(&[txid(coinbase, cabecera.consensus_branch_id)]) != cabecera.merkle_root {
        return Err(malo(
            "C-BLK-01: la raíz de Merkle no compromete esta coinbase",
        ));
    }
    // `bits` MUST ser canónico y estar en rango, aunque el PoW no se compruebe.
    CompactBits::from_u32(cabecera.bits)
        .decodificar()
        .map_err(|_| malo("C-POW-04: los bits del génesis no son canónicos"))?;
    // C-GEN-06 · el timestamp MUST ser plausible. Ver la constante para el porqué.
    if cabecera.timestamp < TIMESTAMP_MINIMO_GENESIS {
        return Err(malo(
            "C-GEN-06: el timestamp del génesis es anterior a 2026 — ¿parámetros de marcador de \
             posición sin rellenar? Ver P-017",
        ));
    }
    Ok(())
}

/// Hash congelado de una red, o `None` si esa red todavía no lo tiene (C-GEN-07).
///
/// Mainnet devuelve `None` **a propósito** mientras P-017 siga abierto: congelar el hash de un
/// marcador de posición sería congelar el error.
#[must_use]
pub const fn hash_congelado(red: Red) -> Option<[u8; 32]> {
    match red {
        Red::Testnet => Some(HASH_GENESIS_TESTNET),
        Red::Mainnet => None,
    }
}

/// **La comprobación de arranque completa (C-GEN-01, C-GEN-07).** Es lo que un nodo llama antes de
/// tocar nada más, y lo que aborta el arranque si algo no cuadra.
///
/// Hace tres cosas, en este orden:
/// 1. construye el génesis a partir de sus parámetros,
/// 2. comprueba todas las invariantes de §15 con [`comprobar`],
/// 3. **compara su hash contra la constante congelada** del binario.
///
/// # Por qué el paso 3 no puede vivir solo en un test
///
/// Lo hacía, y una auditoría de trazabilidad lo cazó: C-GEN-07 dice *"el arranque MUST
/// compararlo"*, y una comparación que solo ocurre en `cargo test` **no es el arranque**. Un
/// binario compilado con parámetros tocados habría levantado una cadena distinta sin decir nada,
/// y el síntoma —nodos que no se sincronizan entre sí— aparecería lejísimos de la causa.
///
/// # Errores
/// [`ConsensusError::GenesisInvalido`] con el motivo concreto, o el error de [`construir`].
pub fn comprobar_al_arrancar(p: ParametrosGenesis) -> Result<BlockHash, ConsensusError> {
    let (cabecera, coinbase) = construir(p)?;
    comprobar(&cabecera, &coinbase)?;

    let obtenido = cabecera.block_hash();
    match hash_congelado(p.red) {
        Some(esperado) if obtenido.as_bytes() == &esperado => Ok(obtenido),
        Some(_) => Err(ConsensusError::GenesisInvalido {
            motivo: "C-GEN-07: el génesis construido NO coincide con el hash congelado del \
                     binario — o alguien tocó los parámetros, o este binario no es de esta red",
        }),
        // Una red sin hash congelado no puede arrancar. Hoy es mainnet, por P-017.
        None => Err(ConsensusError::GenesisInvalido {
            motivo: "C-GEN-07: esta red no tiene hash de génesis congelado todavía — ver P-017",
        }),
    }
}

/// Hash del génesis de una red, tal y como se hardcodearía para la aserción de C-GEN-01.
///
/// # Errores
/// La de [`construir`].
pub fn hash(p: ParametrosGenesis) -> Result<BlockHash, ConsensusError> {
    Ok(construir(p)?.0.block_hash())
}

/// El txid de la coinbase del génesis, que **MUST NOT** entrar en el UTXO set (C-GEN-03).
///
/// Se expone para que la capa de estado pueda comprobar explícitamente que no está, en vez de
/// confiar en que nadie la insertó.
///
/// # Errores
/// La de [`construir`].
pub fn txid_coinbase(p: ParametrosGenesis) -> Result<TxId, ConsensusError> {
    let (cab, cb) = construir(p)?;
    Ok(txid(&cb, cab.consensus_branch_id))
}

#[cfg(test)]
#[expect(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    reason = "los tests fallan con panic por diseño"
)]
mod tests {
    use super::target_inicial_bits;
    use super::{
        GENESIS_MAINNET, GENESIS_TESTNET, HASH_GENESIS_TESTNET, ParametrosGenesis,
        TIMESTAMP_MINIMO_GENESIS, coinbase_genesis, comprobar, comprobar_al_arrancar, construir,
        hash, hash_congelado, txid_coinbase,
    };
    use crate::activacion::Red;
    use crate::dificultad::{N, ST_CAP, T};
    use crate::error::ConsensusError;
    use zx_core::amount::Amount;
    use zx_core::digest::{BlockHash, Digest};
    use zx_core::target::{TARGET_INICIAL_BITS_MAINNET, TARGET_INICIAL_BITS_TESTNET};

    #[test]
    fn el_genesis_de_testnet_es_valido() {
        let (cab, cb) = construir(GENESIS_TESTNET).unwrap();
        comprobar(&cab, &cb).unwrap_or_else(|e| panic!("testnet: {e}"));
    }

    /// **C-GEN-06 · P-017.** Mainnet **MUST NOT** arrancar todavía, y esto lo demuestra.
    ///
    /// El marcador de posición lleva `timestamp: 0`, que incumple C-GEN-06. Así, olvidarse de P-017
    /// no produce una mainnet sobre un génesis inventado: produce un nodo que **se niega a
    /// arrancar** citando la pregunta abierta.
    ///
    /// Cuando P-017 se cierre, este test fallará — y esa es exactamente la señal de que hay que
    /// convertirlo en el test de que mainnet **sí** arranca.
    #[test]
    fn el_genesis_de_mainnet_todavia_no_arranca() {
        let (cab, cb) = construir(GENESIS_MAINNET).unwrap();
        let Err(e) = comprobar(&cab, &cb) else {
            panic!("P-017 sigue abierto: el génesis de mainnet NO debe validar todavía");
        };
        let texto = format!("{e}");
        assert!(
            texto.contains("C-GEN-06") && texto.contains("P-017"),
            "el error debe decir qué falta y dónde está anotado: {texto}"
        );
    }

    /// **C-GEN-07.** El arranque de testnet valida y compara el hash. Ruta real, no un test aparte.
    #[test]
    fn el_arranque_de_testnet_valida_y_compara_el_hash() {
        let h = comprobar_al_arrancar(GENESIS_TESTNET).expect("testnet arranca");
        assert_eq!(h.as_bytes(), &HASH_GENESIS_TESTNET);
    }

    /// **C-GEN-07.** Tocar un parámetro sin recalcular el hash **impide arrancar**.
    ///
    /// Este es el test que da valor a la regla. Sin la comparación en el arranque, un binario con
    /// parámetros tocados levantaría una cadena distinta en silencio, y el síntoma —nodos que no
    /// se sincronizan— aparecería lejísimos de la causa.
    #[test]
    fn un_parametro_tocado_impide_arrancar() {
        for tocar in [
            |mut p: ParametrosGenesis| {
                p.timestamp += 1;
                p
            },
            |mut p: ParametrosGenesis| {
                p.nonce += 1;
                p
            },
            |mut p: ParametrosGenesis| {
                p.mensaje = b"otro mensaje cualquiera";
                p
            },
        ] {
            let p = tocar(GENESIS_TESTNET);
            let Err(e) = comprobar_al_arrancar(p) else {
                panic!("un parámetro tocado MUST impedir el arranque");
            };
            assert!(format!("{e}").contains("C-GEN-07"), "{e}");
        }
    }

    /// **C-GEN-07 · P-017.** Mainnet no puede arrancar: no tiene hash congelado.
    ///
    /// Son dos candados independientes —C-GEN-06 por el timestamp y C-GEN-07 por el hash ausente—
    /// y eso es deliberado: cerrar P-017 exige tocar los dos, así que no basta con rellenar la
    /// fecha y olvidar congelar el hash.
    #[test]
    fn mainnet_no_arranca_porque_no_tiene_hash_congelado() {
        assert!(
            hash_congelado(Red::Mainnet).is_none(),
            "P-017 sigue abierto"
        );
        assert!(comprobar_al_arrancar(GENESIS_MAINNET).is_err());
    }

    /// **C-GEN-01.** El hash del génesis de testnet está congelado.
    ///
    /// Cambiar cualquier parámetro sin actualizar la constante hace fallar esto. Sin la aserción,
    /// dos nodos con builds distintas levantarían **cadenas distintas creyendo que son la misma**,
    /// y el síntoma aparecería mucho más tarde y muy lejos de la causa.
    #[test]
    fn el_hash_del_genesis_de_testnet_esta_congelado() {
        let h = hash(GENESIS_TESTNET).unwrap();
        assert_eq!(
            h.as_bytes(),
            &HASH_GENESIS_TESTNET,
            "el génesis de testnet cambió — si es a propósito, actualiza HASH_GENESIS_TESTNET; \
             si no, has roto la red de pruebas"
        );
    }

    /// **C-GEN-04.** Las dos redes producen génesis distintos.
    ///
    /// Se comprueba aunque mainnet no valide todavía: `construir` sí funciona, y lo que interesa es
    /// que los hashes difieran, no que el bloque sea lanzable.
    #[test]
    fn mainnet_y_testnet_no_comparten_genesis() {
        assert_ne!(
            hash(GENESIS_MAINNET).unwrap().as_bytes(),
            hash(GENESIS_TESTNET).unwrap().as_bytes(),
            "C-GEN-04: un génesis compartido dejaría a las dos redes confundirse"
        );
    }

    /// **C-GEN-06.** El suelo es un suelo: un segundo antes falla, el suelo justo pasa.
    #[test]
    fn el_borde_exacto_del_suelo_de_timestamp() {
        let mut p = GENESIS_TESTNET;

        p.timestamp = TIMESTAMP_MINIMO_GENESIS - 1;
        let (cab, cb) = construir(p).unwrap();
        assert!(
            comprobar(&cab, &cb).is_err(),
            "un segundo antes MUST fallar"
        );

        p.timestamp = TIMESTAMP_MINIMO_GENESIS;
        let (cab, cb) = construir(p).unwrap();
        assert!(comprobar(&cab, &cb).is_ok(), "el suelo justo MUST valer");
    }

    /// **Por qué C-GEN-06 existe, medido.**
    ///
    /// El timestamp del génesis **entra en la ventana del primer retarget**: para `H = N+1 = 91`,
    /// C-DIFF-01 usa `ts(H−N−1 .. H−1) = ts(0..90)`, y `ts(0)` es el del génesis.
    ///
    /// Con `ts(0) = 0` el primer solvetime reconstruido satura en `ST_CAP = 720` en vez de valer
    /// `T = 120`, así que `t` sube 600 y el primer target calculado sale **un 0,122 % más fácil** de
    /// lo que debería. Es pequeño, pero es un error silencioso nacido de un marcador de posición —
    /// justo la clase de cosa que conviene volver imposible en vez de documentar.
    #[test]
    fn un_genesis_en_el_ano_cero_sesga_el_primer_retarget() {
        let n = N as i64;
        // n(n+1) siempre es par, así que la división entera aquí es exacta, no truncada.
        #[expect(
            clippy::integer_division,
            reason = "n(n+1) es par: la división es exacta"
        )]
        let k = n * (n + 1) / 2 * T;

        // Cadena sana: todos los solvetimes valen exactamente T.
        let t_sano: i64 = (1..=n).map(|j| j * T).sum();
        assert_eq!(
            t_sano, k,
            "con st = T en todos, t = k y el target no se mueve"
        );

        // Con el génesis en 0, st[1] satura en ST_CAP en vez de valer T.
        let t_sesgado: i64 = ST_CAP + (2..=n).map(|j| j * T).sum::<i64>();
        assert!(t_sesgado > k, "el target se afloja");
        assert_eq!(
            t_sesgado - k,
            ST_CAP - T,
            "exactamente ST_CAP − T, con peso j=1"
        );

        // +0,122 %. Comprobado con enteros: 1,001 < t/k < 1,002.
        assert!(t_sesgado * 1000 > k * 1001 && t_sesgado * 1000 < k * 1002);
    }

    #[test]
    fn el_genesis_esta_en_la_altura_cero_y_no_tiene_padre() {
        let (cab, _) = construir(GENESIS_MAINNET).unwrap();
        assert_eq!(cab.height, 0);
        assert_eq!(cab.prev_hash.as_bytes(), &[0u8; 32]);
    }

    /// **P-004c.** Cada red arranca con SU dificultad, y mainnet es la difícil.
    ///
    /// Sin este test, cambiar una de las dos constantes y olvidar la otra pasaría desapercibido:
    /// los demás tests del génesis no miran `bits`.
    #[test]
    fn cada_red_arranca_con_su_propia_dificultad() {
        for p in [GENESIS_MAINNET, GENESIS_TESTNET] {
            let (cab, _) = construir(p).unwrap();
            assert_eq!(
                cab.bits,
                target_inicial_bits(p.red),
                "C-DIFF-02, {:?}",
                p.red
            );
        }
        assert_eq!(
            target_inicial_bits(Red::Mainnet),
            TARGET_INICIAL_BITS_MAINNET
        );
        assert_eq!(
            target_inicial_bits(Red::Testnet),
            TARGET_INICIAL_BITS_TESTNET
        );
        assert_ne!(
            TARGET_INICIAL_BITS_MAINNET, TARGET_INICIAL_BITS_TESTNET,
            "si se igualan, o testnet va lenta o mainnet se regala"
        );
    }

    /// **C-GEN-03 / C-EMIT-02.** Sin premine, sin dev tax, sin founder reward.
    #[test]
    fn la_coinbase_del_genesis_vale_cero() {
        let (_, cb) = construir(GENESIS_MAINNET).unwrap();
        let total: i64 = cb.outputs.iter().map(|s| s.value.brek()).sum();
        assert_eq!(total, 0, "el génesis MUST NOT crear valor");
        assert!(cb.inputs.is_empty(), "es coinbase");
    }

    /// Y se rechaza si alguien intenta colar valor.
    #[test]
    fn se_rechaza_un_genesis_con_premine() {
        let (cab, mut cb) = construir(GENESIS_MAINNET).unwrap();
        if let Some(s) = cb.outputs.first_mut() {
            s.value = Amount::nuevo(1).unwrap();
        }
        let e = comprobar(&cab, &cb).unwrap_err();
        assert!(matches!(e, ConsensusError::GenesisInvalido { .. }), "{e:?}");
        assert!(
            format!("{e}").contains("cero"),
            "el error debe nombrar la regla"
        );
    }

    /// **C-GEN-04.** Mainnet y testnet MUST producir hashes distintos.
    ///
    /// Sin esto, un bloque de una red podría ser el bloque 0 válido de la otra.
    #[test]
    fn mainnet_y_testnet_tienen_genesis_distintos() {
        let m = hash(GENESIS_MAINNET).unwrap();
        let t = hash(GENESIS_TESTNET).unwrap();
        assert_ne!(m, t, "C-GEN-04: los génesis de las dos redes MUST diferir");
        assert_ne!(
            txid_coinbase(GENESIS_MAINNET).unwrap(),
            txid_coinbase(GENESIS_TESTNET).unwrap(),
            "y sus coinbases también"
        );
    }

    /// El génesis es **determinista**: los mismos parámetros dan siempre el mismo hash. Es lo que
    /// permite la aserción de C-GEN-01.
    #[test]
    fn el_genesis_es_determinista() {
        let a = hash(GENESIS_MAINNET).unwrap();
        for _ in 0..5 {
            assert_eq!(hash(GENESIS_MAINNET).unwrap(), a);
        }
    }

    /// Cambiar **cualquier** parámetro cambia el hash. Es lo que hace útil la aserción: tocar algo
    /// sin recalcular el hash rompe el arranque en vez de pasar desapercibido.
    #[test]
    fn cada_parametro_cambia_el_hash_del_genesis() {
        let base = hash(GENESIS_MAINNET).unwrap();

        let mut p = GENESIS_MAINNET;
        p.mensaje = b"otro mensaje completamente distinto";
        assert_ne!(hash(p).unwrap(), base, "mensaje");

        let mut p = GENESIS_MAINNET;
        p.timestamp = 1;
        assert_ne!(hash(p).unwrap(), base, "timestamp");

        let mut p = GENESIS_MAINNET;
        p.nonce = 1;
        assert_ne!(hash(p).unwrap(), base, "nonce");
    }

    /// C-BLK-01: la raíz de Merkle compromete esa coinbase y no otra.
    #[test]
    fn una_coinbase_cambiada_invalida_el_genesis() {
        let (cab, _) = construir(GENESIS_MAINNET).unwrap();
        let otra = coinbase_genesis(b"una coinbase que no es la del genesis");
        assert!(matches!(
            comprobar(&cab, &otra),
            Err(ConsensusError::GenesisInvalido { .. })
        ));
    }

    #[test]
    fn se_rechaza_un_genesis_con_padre() {
        let (mut cab, cb) = construir(GENESIS_MAINNET).unwrap();
        cab.prev_hash = BlockHash::from_digest(Digest::from_bytes([1u8; 32]));
        assert!(comprobar(&cab, &cb).is_err());
    }

    #[test]
    fn se_rechaza_un_genesis_fuera_de_la_altura_cero() {
        let (mut cab, cb) = construir(GENESIS_MAINNET).unwrap();
        cab.height = 1;
        assert!(comprobar(&cab, &cb).is_err());
    }

    /// **C-GEN-02: el génesis NO pasa por la comprobación de PoW.**
    ///
    /// Su nonce es 0 y no resuelve nada, y aun así `comprobar` lo acepta. La exención es
    /// estructural —igual que en Bitcoin—, no depende de que el génesis satisfaga su propio target.
    #[test]
    fn el_genesis_no_necesita_resolver_el_pow() {
        // Testnet, porque mainnet está bloqueado por C-GEN-06 mientras P-017 siga abierto.
        let (cab, cb) = construir(GENESIS_TESTNET).unwrap();
        assert_eq!(
            cab.nonce, 1,
            "el nonce del génesis separa redes (C-GEN-04), no resuelve un PoW"
        );

        let target = zx_core::target::CompactBits::from_u32(cab.bits)
            .decodificar()
            .unwrap();
        let cumple = zx_core::target::cumple_pow(&cab.block_hash(), target);
        // No se afirma que NO lo cumpla —podría cumplirlo por azar—, sino que `comprobar` no lo mira.
        let _ = cumple;
        assert!(comprobar(&cab, &cb).is_ok(), "C-GEN-02: exento del PoW");
    }

    /// Las dos redes usan la rama de consenso activa a la altura 0.
    #[test]
    fn el_genesis_declara_la_rama_activa() {
        for (p, red) in [
            (GENESIS_MAINNET, Red::Mainnet),
            (GENESIS_TESTNET, Red::Testnet),
        ] {
            let (cab, _) = construir(p).unwrap();
            assert_eq!(
                cab.consensus_branch_id,
                crate::activacion::rama_activa(red, 0).unwrap()
            );
        }
    }
}
