# Cómo resuelven Bitcoin Core, Zcash (zcashd/Zebra) y Monero el problema de "PoW real en tests de dos nodos"

> Investigación de fuente primaria para ZEROX. Todo está anclado a un commit/tag concreto, clonado
> y leído directamente (no de memoria, no del README). Fecha de la investigación: 2026-09-05.
>
> Repos y commits usados:
> - `bitcoin/bitcoin` @ `v29.4` = `3fc0865963a38b871e9f7d94e6151c4953563516`
> - `zcash/zcash` (zcashd) @ `v6.20.0` = `6966f30a8541b0e5998837dce14250ca9e15b16a`
> - `ZcashFoundation/zebra` @ `v6.3.0` = `f5c5277fe41eba9c74f37098738f93f35dd70d60`
> - `monero-project/monero` @ `v0.18.5.1` = `4f92268d7c16741cfb41e5bbe2aa46cc260a9ea5`
>
> Contexto del problema en ZEROX: `pow_limit()` en `crates/zx-core/src/target.rs:26` es `2^224-1`
> (35,8 MH/s sostenidos para 120 s), y el propio `TARGET_INICIAL_BITS_TESTNET` (`0x1d00ffff`,
> `target.rs:83`) ya está pegado a ese límite — el test
> `el_trabajo_es_2_elevado_256_entre_target_mas_uno` en `target.rs` demuestra que da **≈2³²
> hashes/bloque**. El harness de dos nodos (`crates/zx-node/tests/sincronizacion.rs:1-18`) lo
> reconoce explícitamente en su propio doc-comment: valida con `validar_estructura` pero **no**
> con `comprobar_pow`, porque minar de verdad a ese target es inviable en CI.

---

## 1 · Bitcoin Core — la red `regtest`

### 1.1 `powLimit` por red — literal

`src/kernel/chainparams.cpp` @ `v29.4`:

```
AFIRMACIÓN: powLimit de regtest es 0x7fff...ff (≈2^255), ~2^31 veces más fácil que mainnet
            (0x00000000ffff...ff, ≈2^224); en la práctica ~1-2 hashes esperados por bloque.
REPO:       bitcoin/bitcoin @ v29.4 (3fc0865963a38b871e9f7d94e6151c4953563516)
ARCHIVO:    src/kernel/chainparams.cpp:101 (Main), :230 (Testnet3), :329 (Testnet4),
            :474 (Signet), :542 (Regtest)
CÓDIGO:     // CMainParams
            consensus.powLimit = uint256{"00000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffff"};
            // CRegTestParams
            consensus.powLimit = uint256{"7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"};
TESTS:      src/test/pow_tests.cpp (no cubre regtest directamente; ver §4 para el bug de overflow
            de regtest encontrado en producción, issue #5712)
CONFIANZA:  alta
```

### 1.2 `fPowNoRetargeting` y `fPowAllowMinDifficultyBlocks`

```
AFIRMACIÓN: fPowNoRetargeting congela nBits al del bloque anterior en cada recálculo de dificultad
            (retarget = no-op); fPowAllowMinDifficultyBlocks permite minar directamente al powLimit
            si el bloque llega con >20 min de retraso, y relaja además la validación de
            transiciones de dificultad permitidas. Están activados así: mainnet ambos en false;
            testnet3/testnet4/signet fPowAllowMinDifficultyBlocks=true, fPowNoRetargeting=false;
            regtest los dos en true.
REPO:       bitcoin/bitcoin @ v29.4
ARCHIVO:    src/kernel/chainparams.cpp:104-106 (Main), :233,235 (Testnet3), :545,547 (Regtest)
            src/pow.cpp:14-53, 87-91 (dónde se consultan)
CÓDIGO:     // pow.cpp — GetNextWorkRequired
            if (params.fPowAllowMinDifficultyBlocks) {
                if (pblock->GetBlockTime() > pindexLast->GetBlockTime() + params.nPowTargetSpacing*2)
                    return nProofOfWorkLimit;
                ...
            }
            // pow.cpp — CalculateNextWorkRequired
            if (params.fPowNoRetargeting)
                return pindexLast->nBits;
            // pow.cpp — PermittedDifficultyTransition
            if (params.fPowAllowMinDifficultyBlocks) return true;
TESTS:      src/test/pow_tests.cpp (retarget general, sobre CMainParams)
CONFIANZA:  alta
```

Origen histórico de `fPowNoRetargeting`: PR bitcoin/bitcoin#6853 ("Added fPowNoRetargeting field to
Consensus::Params"). Cita del autor (CodeShark) en la descripción de la PR: *"-regtest cannot
currently handle chains longer than one retargeting period. This PR allows arbitrary length chains
to be created on -regtest by trivially preserving the nBits value of the last block."* — es decir,
el campo nació **específicamente** para permitir cadenas de test largas sin recalcular dificultad,
no como mecanismo de seguridad de red.

### 1.3 Selección de red — runtime, no compilación

```
AFIRMACIÓN: la red se elige en runtime por un flag de línea de comandos/config (-regtest, -testnet,
            -signet, -chain=<nombre>), mutuamente excluyentes; sin flag, el default es MAIN. Es el
            MISMO binario para las cuatro redes — no hay separación en tiempo de compilación.
REPO:       bitcoin/bitcoin @ v29.4
ARCHIVO:    src/common/args.cpp:788-818
CÓDIGO:     const bool fRegTest = get_net("-regtest");
            ...
            if ((int)chain_arg.has_value() + (int)fRegTest + (int)fSigNet + (int)fTestNet
                + (int)fTestNet4 > 1) {
                throw std::runtime_error("Invalid combination of -regtest, -signet, -testnet,"
                                          " -testnet4 and -chain. Can use at most one.");
            }
            ...
            if (fRegTest) return ChainType::REGTEST;
            ...
            return ChainType::MAIN;
TESTS:      —
CONFIANZA:  alta
```

No hay ningún `assert` ni comprobación en tiempo de ejecución que impida "usar regtest sin
querer" más allá de: (a) requerir un flag **explícito** (nunca es el default), (b) la mutua
exclusión de flags de red (evita combinaciones ambiguas, no evita elegir regtest a propósito), y
(c) el aislamiento estructural aguas abajo — directorio de datos distinto
(`src/common/args.cpp:301,326-327` vía `BaseParams().DataDir()`), puerto por defecto distinto
(`nDefaultPort = 18444` en regtest vs `8333` en mainnet), y **magic bytes** de red distintos
(`pchMessageStart`) que impiden que un nodo regtest y uno mainnet siquiera completen el handshake
P2P. Es defensa en profundidad por aislamiento, no un candado explícito contra el error humano de
lanzar `-regtest` en producción.

---

## 2 · Zcash

### 2.1 zcashd — mismo patrón que Bitcoin Core, con una vuelta de tuerca: Equihash también se achica

```
AFIRMACIÓN: zcashd define powLimit de regtest como 0x0f0f0f0f...0f (256 bits), con un comentario
            explícito del propio equipo advirtiendo que un valor más laxo desborda un bucle interno
            de GetNextWorkRequired. Además de bajar powLimit, **reduce los propios parámetros de
            Equihash** de (N=200,K=9) —mainnet/testnet— a (N=48,K=5) en regtest: la dificultad de
            regtest no es solo "target más fácil", es un rompecabezas más pequeño y barato de
            resolver por construcción.
REPO:       zcash/zcash @ v6.20.0 (6966f30a8541b0e5998837dce14250ca9e15b16a)
ARCHIVO:    src/chainparams.cpp:99-103 (Main, N=200,K=9), :826-830 (Regtest, N=48,K=5)
CÓDIGO:     // CMainParams
            const size_t N = 200, K = 9;
            ...
            consensus.powLimit = uint256S("0007ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff");
            // CRegTestParams
            const size_t N = 48, K = 5;
            ...
            consensus.powLimit = uint256S("0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f");
            // if this is any larger, the for loop in GetNextWorkRequired can overflow bnTot
            consensus.nPowMaxAdjustDown = 0; // Turn off adjustment down
            consensus.nPowMaxAdjustUp = 0; // Turn off adjustment up
            ...
            consensus.fPowNoRetargeting = true;
TESTS:      src/gtest/test_pow.cpp, src/test/pow_tests.cpp (corren sobre CBaseChainParams::MAIN;
            no ejercitan directamente el powLimit de regtest)
CONFIANZA:  alta
```

```
AFIRMACIÓN: a diferencia de Zebra (ver §2.2), zcashd SIEMPRE ejecuta la comprobación real de PoW
            (CheckEquihashSolution + CheckProofOfWork) para bloques que entran a la cadena, en
            cualquier red, incluida regtest. El único camino que se salta ambas comprobaciones es
            `fCheckPOW=false`, usado para validar *propuestas* de bloque (getblocktemplate/
            TestBlockValidity), igual que el caso `is_proposal()` de Zebra — no es un bypass por
            tipo de red.
REPO:       zcash/zcash @ v6.20.0
ARCHIVO:    src/main.cpp:5679-5685 (CheckBlockHeader), :6306 (llamada con fCheckPOW=false, contexto
            de validación de propuesta, no de aceptación de cadena)
CÓDIGO:     if (fCheckPOW && !CheckEquihashSolution(&block, chainparams.GetConsensus()))
                return state.DoS(100, error("CheckBlockHeader(): Equihash solution invalid"), ...);
            if (fCheckPOW && !CheckProofOfWork(block.GetHash(), block.nBits, chainparams.GetConsensus()))
                return state.DoS(50, error("CheckBlockHeader(): proof of work failed"), ...);
TESTS:      —
CONFIANZA:  media (confirmado el patrón general por lectura de main.cpp; no revisé cada call site
            de CheckBlock/CheckBlockHeader en el archivo completo — está la mayoría, no las 100%)
```

Nota adicional: existe `void UpdateRegtestPow(int64_t nPowMaxAdjustDown, int64_t nPowMaxAdjustUp,
uint256 powLimit, bool noRetargeting)` en `src/chainparams.cpp:1113-1120`, que permite reconfigurar
en caliente los parámetros de PoW de la instancia de `CRegTestParams` ya seleccionada. **No
encontré ningún call site** de esta función en el árbol de fuente C++ revisado (`src/rpc/mining.cpp`,
`src/init.cpp`, `src/gtest/test_pow.cpp`, `src/test/pow_tests.cpp` no la usan) — declarado como
laguna, no como afirmación: puede ser código muerto, o invocado desde un binding externo (Python
`qa/rpc-tests` vía una capa de test C++ que no revisé completa, o desde `zcash-cli`/RPC no
encontrado). No lo reporto como mecanismo activo sin confirmar el call site.

### 2.2 Zebra — el hallazgo central: un flag `disable_pow()` de primera clase en el tipo `Network`

Este es el mecanismo que más se parece a lo que ZEROX necesita, y difiere estructuralmente de
Bitcoin Core/zcashd: Zebra no solo baja el target en regtest, **desactiva la comprobación de PoW
por completo** mediante un método del propio enum `Network`, consultado en los dos únicos puntos
reales de verificación de bloques del nodo (no en un arnés de test aparte).

```
AFIRMACIÓN: Network::disable_pow() es false siempre para Mainnet y para el Testnet público por
            defecto, y solo es true cuando el `Network` se construyó con `Network::new_regtest(..)`.
            Es un campo del propio tipo de red (no un flag de test), consultado por el verificador
            de bloques real.
REPO:       ZcashFoundation/zebra @ v6.3.0 (f5c5277fe41eba9c74f37098738f93f35dd70d60)
ARCHIVO:    zebra-chain/src/parameters/network/testnet.rs:480,519 (campo y default=false),
            :1042-1043 (new_regtest fuerza with_disable_pow(true)), :1153-1154, 1218-1220
            zebra-chain/src/parameters/network.rs (Network::disable_pow, delega en Testnet(params))
CÓDIGO:     // testnet.rs — new_regtest
            let mut parameters = Self::build()
                .with_genesis_hash(REGTEST_GENESIS_HASH)?
                // This value is chosen to match zcashd, see:
                // <https://github.com/zcash/zcash/blob/master/src/chainparams.cpp#L654>
                .with_target_difficulty_limit(U256::from_big_endian(&[0x0f; 32]))?
                .with_disable_pow(true)
                ...
            // network.rs — Network
            pub fn disable_pow(&self) -> bool {
                if let Self::Testnet(params) = self { params.disable_pow() } else { false }
            }
TESTS:      zebra-chain/src/parameters/network/tests/vectors.rs (construcción de new_regtest)
CONFIANZA:  alta
```

```
AFIRMACIÓN: el verificador de bloques real de producción (no un test double) ramifica en
            network.disable_pow(): si es true (o el bloque es una propuesta de minería), valida
            SOLO que el `bits` declarado no sea más fácil que el powLimit de la red
            (difficulty_threshold_is_valid) y NO comprueba que hash <= threshold ni que la
            solución Equihash sea válida. Si es false, corre las dos comprobaciones reales
            (difficulty_is_valid + equihash_solution_is_valid).
REPO:       ZcashFoundation/zebra @ v6.3.0
ARCHIVO:    zebra-consensus/src/block.rs:246-252
            zebra-consensus/src/checkpoint.rs:600-610
            zebra-consensus/src/block/check.rs:76-140 (difficulty_threshold_is_valid vs
            difficulty_is_valid — la primera NO compara hash contra el threshold, solo valida que
            el threshold declarado esté dentro de powLimit; la segunda añade `if hash >
            &difficulty_threshold { Err(...) }`)
CÓDIGO:     // block.rs
            if request.is_proposal() || network.disable_pow() {
                check::difficulty_threshold_is_valid(&block.header, &network, &height, &hash)?;
            } else {
                check::difficulty_is_valid(&block.header, &network, &height, &hash)?;
                check::equihash_solution_is_valid(&block.header)?;
            }
            // checkpoint.rs
            if self.network.disable_pow() {
                crate::block::check::difficulty_threshold_is_valid(...)?;
            } else {
                crate::block::check::difficulty_is_valid(...)?;
                crate::block::check::equihash_solution_is_valid(...)?;
            }
TESTS:      zebrad/tests/integration/regtest.rs (validate_regtest_genesis_block y otros, corren
            contra un zebrad real levantado en Regtest)
CONFIANZA:  alta
```

Consecuencia directa, confirmada en el propio arnés de pruebas de Zebra (no en el nodo): al minar
para regtest, el código **ni siquiera intenta encontrar un nonce que cumpla el hash < target** —
el `while` que lo haría está guardado por `!net.disable_pow()`, así que en regtest jamás se ejecuta:

```
AFIRMACIÓN: el propio harness de pruebas de Zebra usa disable_pow() para decidir si tiene que
            "picar" el nonce de verdad o si puede enviar el bloque tal cual salió de la plantilla,
            usando la MISMA función de validación (difficulty_is_valid) que usaría con PoW real.
REPO:       ZcashFoundation/zebra @ v6.3.0
ARCHIVO:    zebrad/tests/common/regtest.rs:59-67
CÓDIGO:     while !net.disable_pow()
                && zebra_consensus::difficulty_is_valid(&block.header, &net, &height, &block.hash())
                    .is_err()
            {
                increment_big_endian(Arc::make_mut(&mut block.header).nonce.as_mut());
            }
            client.submit_block(block).await?;
TESTS:      zebrad/tests/integration/regtest.rs:59 (regtest_block_templates_are_valid_block_submissions)
CONFIANZA:  alta
```

### 2.3 La alternativa sin red extra: vectores de bloques reales pre-minados, commiteados

```
AFIRMACIÓN: Zebra mantiene 90 bloques reales de mainnet/testnet (con PoW y Equihash genuinos,
            minados por la red real en su momento), volcados como hexadecimal en archivos .txt
            individuales, y expuestos como &'static [u8] mediante lazy_static. Se usan para
            construir cadenas continuas desde el génesis en tests unitarios y de propiedades sin
            minar nada ni depender de red.
REPO:       ZcashFoundation/zebra @ v6.3.0
ARCHIVO:    zebra-test/src/vectors/ (90 archivos block-main-*.txt y block-test-*.txt)
            zebra-test/src/vectors/block.rs:21-48 (BLOCKS, CONTINUOUS_MAINNET_BLOCKS,
            CONTINUOUS_TESTNET_BLOCKS)
CÓDIGO:     /// Continuous mainnet blocks, indexed by height
            ///
            /// Contains the continuous blockchain from genesis onwards.  Stops at the
            /// first gap in the chain.
            pub static ref CONTINUOUS_MAINNET_BLOCKS: BTreeMap<u32, &'static [u8]> = ...
TESTS:      zebra-consensus/src/checkpoint/tests.rs, zebra-state/src/service/read/tests/vectors.rs,
            zebra-rpc/src/methods/tests/vectors.rs, zebra-chain/src/tests/vectors.rs (todos
            consumen CONTINUOUS_MAINNET_BLOCKS/CONTINUOUS_TESTNET_BLOCKS)
CONFIANZA:  alta (conteo y ubicación verificados con `git ls-tree`; la fuente exacta de cómo se
            regeneran/extraen —¿RPC `getblock` contra un zcashd real, script en zebra-utils?— NO
            la encontré documentada en los archivos revisados: LAGUNA)
```

### 2.4 El límite real de esta estrategia, admitido por el propio proyecto: el "hito de sincronía con PoW real" de Zebra NO corre en cada PR

```
AFIRMACIÓN: incluso Zebra —que sí valida PoW real en su CI— no lo hace contra dos nodos locales:
            su prueba de sincronía "grande" se conecta a la red mainnet real por Internet, tarda
            entre 58 segundos y 23 minutos, y está explícitamente excluida del CI por defecto de
            cada PR (marcada #[ignore], en un "perfil E2E" aparte). El único "PoW real, en CI de
            cada PR, entre pares" que sí corre es un sync contra la red real con muy pocos
            checkpoints (sync_one_checkpoint_mainnet), también dependiente de conectividad externa
            y de que existan pares vivos — no es hermético ni determinista.
REPO:       ZcashFoundation/zebra @ v6.3.0
ARCHIVO:    zebrad/tests/e2e/sync.rs:16-22
            zebrad/tests/integration/sync.rs:82-83
CÓDIGO:     /// Test if `zebrad` can sync some larger checkpoints on mainnet.
            ///
            /// This test depends on real mainnet peers and can take 58 seconds to 23 minutes
            /// depending on peer availability. It has a dedicated E2E profile and is excluded
            /// from default PR CI.
            #[test]
            #[ignore]
            fn sync_large_checkpoints_empty() -> Result<()> { ... }
TESTS:      zebrad/tests/e2e/sync.rs, zebrad/tests/integration/sync.rs
CONFIANZA:  alta
```

Esto es directamente relevante para ZEROX: **ni siquiera Zebra** resuelve "dos nodos sincronizan
con PoW real, en cada corrida de CI, de forma local y determinista". Su solución es partir el
problema en dos mitades independientes: (a) Regtest con `disable_pow()` para probar la lógica de
API/RPC/mempool/reorg localmente y rápido, y (b) un test de sincronía con PoW genuino que depende
de la red real, es lento, no determinista, y está deliberadamente fuera del gate por PR.

---

## 3 · Monero

```
AFIRMACIÓN: Monero no tiene un "regtest" con powLimit propio como Bitcoin/Zcash. Tiene dos
            mecanismos ortogonales: (a) un nettype FAKECHAIN, seleccionado por el flag `--regtest`
            (mutuamente excluyente con --testnet/--stagenet, valida con un throw si se combinan) o
            por pasar test_options desde C++; (b) un flag de daemon independiente
            `--fixed-difficulty=N` que, si es distinto de cero, hace que
            get_difficulty_for_next_block() devuelva N (o 1 en el primer bloque) sin ejecutar el
            algoritmo de retarget en absoluto, para CUALQUIER nettype — no está restringido a
            FAKECHAIN por código.
REPO:       monero-project/monero @ v0.18.5.1 (4f92268d7c16741cfb41e5bbe2aa46cc260a9ea5)
ARCHIVO:    src/cryptonote_core/blockchain.cpp:287 (assert de que FAKECHAIN exige test_options),
            :857-860 (get_difficulty_for_next_block), :1225-1227 (segundo call site)
            src/cryptonote_core/cryptonote_core.cpp:353-356 (mapeo de flags a nettype),
            :467-471, :677-678 (fixed_difficulty se pasa siempre a Blockchain::init,
            independientemente del nettype)
CÓDIGO:     // blockchain.cpp
            CHECK_AND_ASSERT_MES(nettype != FAKECHAIN || test_options, false,
                "fake chain network type used without options");
            ...
            difficulty_type Blockchain::get_difficulty_for_next_block()
            {
              if (m_fixed_difficulty)
              {
                return m_db->height() ? m_fixed_difficulty : 1;
              }
              ...
            // cryptonote_core.cpp — get_nettype
            const bool regtest = command_line::get_arg(vm, arg_regtest_on);
            if (testnet + stagenet + regtest > 1)
                throw std::runtime_error("Can't specify more than one of --testnet and --stagenet"
                                          " and --regtest");
            return testnet ? TESTNET : stagenet ? STAGENET : regtest ? FAKECHAIN : MAINNET;
TESTS:      no localizados tests directos de `--fixed-difficulty` en el árbol revisado (LAGUNA)
CONFIANZA:  alta (para el mecanismo), media (para la ausencia de guarda contra usarlo en mainnet:
            confirmé que `fixed_difficulty` se pasa sin condicionar al nettype en el call site de
            cryptonote_core.cpp:678, pero no revisé el 100% del árbol de daemon.cpp buscando una
            comprobación adicional más arriba)
```

**Esto es lo más parecido a un agujero real de los cuatro proyectos**: a diferencia de
Bitcoin Core/zcashd/Zebra, donde la dificultad trivial vive **dentro** de una clase de parámetros de
red separada y solo se activa eligiendo esa red, en Monero `--fixed-difficulty` es un argumento de
daemon genérico, documentado como herramienta de test, que **el código no impide usar en
`--mainnet` (el nettype por defecto)**. La única barrera es la documentación/convención operativa,
no una comprobación en `cryptonote_core.cpp` o `blockchain.cpp`.

---

## 4 · Bugs reales de "PoW trivial mal aislado" (la pregunta clave del §4 del encargo)

```
AFIRMACIÓN: el propio powLimit "demasiado fácil" de regtest causó un bug de desbordamiento de
            enteros real en Bitcoin Core: al multiplicar la dificultad previa (extremadamente alta
            en términos de "trabajo", por ser powLimit muy laxo) por nActualTimespan antes de
            dividir por el timespan objetivo, el primer retarget en regtest desbordaba el entero de
            trabajo acumulado (bnTot/arith_uint256) y disparaba una dificultad absurda. El propio
            reporte aclara que esto NO puede pasar en mainnet/testnet porque sus dificultades
            iniciales son demasiado pequeñas para desbordar.
FUENTE:     bitcoin/bitcoin issue #5712, "Regtest difficulty calculation error"
            https://github.com/bitcoin/bitcoin/issues/5712
CITA:       "The way the arithmetic works in that function is to first multiply the prior
            difficulty by nActualTimespan and then divide by TargetTimespan." — "I don't believe
            this can affect mainnet or testnet, because the initial difficulties are small enough
            that no overflow can occur."
CONFIANZA:  media (contenido de un issue de GitHub, no código fuente propio; no encontré el commit
            de fix exacto en el árbol de v29.4 que reproduzca la línea citada literalmente en el
            issue, aunque el patrón de guarda contra overflow SÍ está presente hoy en
            src/pow.cpp:56-60 con el clamp de nActualTimespan a [timespan/4, timespan*4])
```

```
AFIRMACIÓN: zcashd conoce el mismo riesgo de desbordamiento y lo documenta directamente sobre la
            constante, en vez de depender de que nadie la suba sin pensar.
REPO:       zcash/zcash @ v6.20.0
ARCHIVO:    src/chainparams.cpp:830
CÓDIGO:     consensus.powLimit = uint256S("0f0f0f0f...0f"); // if this is any larger, the for loop
                                                             // in GetNextWorkRequired can overflow bnTot
CONFIANZA:  alta
```

No encontré (dentro del tiempo de esta investigación) un CVE numerado y públicamente catalogado
específicamente por "parámetros de testnet/regtest filtrados a mainnet" en ninguna cadena; lo más
cercano documentado en fuente primaria son estos dos casos de "el powLimit trivial de regtest rompe
la aritmética de retarget", que son bugs de *diseño de test*, no de *fuga de red* — declarado como
laguna respecto a la pregunta tal como se formuló.

---

## 5 · Tabla comparativa de `powLimit` / mecanismos de dificultad de prueba

| Proyecto  | Red         | powLimit (o equivalente)                              | Retargeting                     | Chequeo de PoW real                                   |
|-----------|-------------|--------------------------------------------------------|----------------------------------|--------------------------------------------------------|
| Bitcoin   | Mainnet     | `0x00000000ffff...ff` (≈2²²⁴)                          | normal                          | siempre (`CheckProofOfWorkImpl`)                       |
| Bitcoin   | Testnet3/4  | `0x00000000ffff...ff` (igual que mainnet)              | normal + regla min-diff 20min   | siempre                                                |
| Bitcoin   | Signet      | `0x00000377ae00...00` (más difícil que mainnet)        | normal                          | siempre + reto de firma adicional                      |
| Bitcoin   | Regtest     | `0x7fff...ff` (≈2²⁵⁵, ~1-2 hashes/bloque)              | **desactivado** (fPowNoRetargeting) | siempre, pero contra target casi trivial            |
| Zcash     | Mainnet     | `0x0007ffff...ff` (≈2²⁴³), Equihash(200,9)             | ventana de 17 bloques, ±32%/±16%| siempre                                                |
| Zcash     | Testnet     | `0x07ffff...ff` (≈2²⁵¹), Equihash(200,9)               | normal                          | siempre                                                |
| Zcash     | Regtest     | `0x0f0f0f...0f`, Equihash(48,5) (puzzle más chico)     | **desactivado**                 | siempre, pero contra target/puzzle casi triviales      |
| Zebra     | Mainnet     | `2²⁴³-1`                                                | normal                          | siempre (`difficulty_is_valid` + `equihash_solution_is_valid`) |
| Zebra     | Testnet     | `2²⁵¹-1` (default)                                      | normal                          | siempre                                                |
| Zebra     | Regtest     | `0x0f0f0f...0f` (igual que zcashd, comentado como tal) | n/a (`disable_pow=true`)        | **NUNCA** — se salta hash<target y Equihash por completo |
| Monero    | Mainnet/Testnet/Stagenet | dificultad real vía LWMA/EMA               | normal                          | siempre                                                |
| Monero    | Regtest (`FAKECHAIN`) + `--fixed-difficulty=N` | dificultad fija = N (o 1)   | **desactivado** (se ignora el algoritmo) | el hash sigue teniendo que cumplir el target fijo, pero N puede ser 1 |

---

## 6 · Recomendación explícita para ZEROX

**Adoptar el patrón de Zebra, no el de Bitcoin/zcashd, y explícitamente no el de Monero.**

Concretamente:

1. Añadir un método `Red::pow_deshabilitado(self) -> bool` (o un campo en una futura variante
   `Red::Regtest`/`Red::Local`) que devuelva `false` para `Mainnet` y `Testnet`, y `true` solo para
   una tercera variante explícita creada por un constructor con nombre distinto
   (`Red::nueva_regtest(..)`, análogo a `Network::new_regtest`). **No** reutilizar `Testnet` con un
   flag oculto de configuración fácil de dejar activado sin querer — Zebra sí modela Regtest como
   "Testnet con parámetros", pero el punto de entrada (`new_regtest`) es sintácticamente imposible
   de alcanzar por accidente desde `Network::Mainnet` o `Network::default()`.
2. Consultar ese método en el **único punto real** donde hoy vive `comprobar_pow` en
   `zx-consensus`/`zx-node` — no en una función de test aparte (`validar_estructura` sin PoW). El
   harness de dos nodos debe llamar exactamente a la función de validación de producción, con
   `pow_deshabilitado()=true` para la red de test, tal como hace `zebra-consensus/src/block.rs:246`
   y `checkpoint.rs:600`. Esto cierra el hueco que hoy describe el propio doc-comment de
   `sincronizacion.rs`.
3. Para el "picado" de nonce en tests que sí quieran ejercitar el camino real de `comprobar_pow`
   (no el bypass), replicar el patrón de `zebrad/tests/common/regtest.rs:59-67`: un único bucle que
   incrementa el nonce y llama a la función de validación real, condicionado por
   `!red.pow_deshabilitado()` — así la MISMA función de test sirve para regtest (bucle no se
   ejecuta) y para una red con PoW real barato (bucle grinding de verdad).
4. Mantener, además del flag, el aislamiento estructural que ya tiene ZEROX y que comparten las
   cuatro cadenas: génesis distinto (ya existe, C-GEN-04) y magic bytes distintos (ya existe,
   C-NET-01, `red.rs:14-18`). Esto es lo que impide que un nodo "de prueba" hable por accidente con
   uno de producción, incluso si algún día se equivocara el flag de PoW.
5. **No** copiar el patrón de Monero (`--fixed-difficulty` como argumento de daemon genérico, sin
   atarlo al tipo de red en el código). Si ZEROX alguna vez expone un flag de CLI/config para forzar
   dificultad, debe rechazar explícitamente combinarse con `Red::Mainnet` en el propio código de
   arranque del nodo (`zx-node`), con un `return Err(..)` — no dejarlo como convención documental.
6. Evaluar además la alternativa de Zebra §2.3 (vectores de bloques reales pre-minados) para
   pruebas que necesiten ejercitar el camino de `comprobar_pow` genuino sin minar en cada corrida de
   CI: si en algún momento existe una red ZEROX viva (aunque sea una testnet pública), commitear un
   prefijo continuo de sus primeras N cabeceras reales (con PoW genuino) en `testdata/`, igual que
   `zebra-test/src/vectors/block-main-*.txt`, y usarlas en tests de sincronización de dos nodos en
   vez de (o adicionalmente a) el bypass por red. Hoy esto no es aplicable: ZEROX no tiene todavía
   una red viva de la que extraer cabeceras reales — es una opción para más adelante, no ahora.

### Riesgos de la recomendación

- **El riesgo Zebra ya documentó**: al saltarse `comprobar_pow` con un flag, el harness dos-nodos
  deja de probar la ruta de código que rechaza cabeceras con `bits` fuera de rango o hash sobre el
  target — hay que mantener el chequeo "trivial" (`difficulty_threshold_is_valid`, el equivalente a
  "el `bits` declarado no es más fácil que el `pow_limit` de la red") incluso con el bypass, tal
  como hace Zebra, para no perder cobertura de esa regla de consenso.
- **El riesgo Monero**: si el flag de deshabilitar PoW no queda atado sintácticamente a un
  constructor de red imposible de invocar desde `Mainnet`, hay riesgo de que alguien lo cablee "solo
  para probar algo rápido" contra una config real. Mitigarlo con un tipo que no permita la
  combinación, no con una convención de nombres.
- **El riesgo del propio Zebra sin resolver**: ni siquiera este patrón da "sincronía de dos nodos
  con PoW real, determinista, en cada PR". Si en algún momento ZEROX necesita esa garantía más
  fuerte (no solo estructura + bypass), la única vía observada en los cuatro proyectos es o bien
  minar de verdad contra una red real y aceptar que el test es lento/no determinista (lo que Zebra
  hace y excluye del CI por defecto), o bien vectores de bloques reales pre-minados commiteados
  (§2.3, §6.6) — que ZEROX no puede tener todavía porque no existe una red viva.

---

## LAGUNAS

- No se encontró el call site de `UpdateRegtestPow` (zcashd) dentro de `src/` en `v6.20.0`; puede
  ser código muerto o invocado desde una capa de test que no revisé completa (posible framework
  Python `qa/rpc-tests`, no inspeccionado).
- No se documentó en el código revisado de Zebra **cómo se regeneran** los 90 vectores de
  `zebra-test/src/vectors/block-*.txt` (¿script en `zebra-utils`? ¿RPC manual contra un zcashd
  real?) — solo se confirmó su existencia, cantidad y uso.
- No localicé tests directos que ejerciten `--fixed-difficulty` de Monero, ni una comprobación en
  `daemon.cpp`/`cryptonote_core.cpp` (más allá de lo citado) que lo restrinja a nettypes de prueba;
  no puedo afirmar con certeza que **no exista** tal guarda en otro punto del árbol que no revisé
  (p. ej. validación de argumentos en `src/daemon/`).
- No se encontró un CVE numerado y catalogado públicamente sobre "parámetros de red de prueba
  filtrados a mainnet" en ninguna de las cuatro cadenas investigadas; lo más cercano son los dos
  bugs de overflow de retarget en regtest (Bitcoin issue #5712, comentario preventivo de zcashd),
  que son bugs de *diseño del valor de prueba*, no de *fuga de red*.
- No revisé el 100% de los call sites de `CheckBlock`/`CheckBlockHeader` en `src/main.cpp` de
  zcashd (son >10 en un archivo de miles de líneas); confirmé el patrón general y el único caso de
  `fCheckPOW=false` encontrado (validación de propuesta), pero no puedo garantizar que no exista
  algún otro camino con `fCheckPOW=false` específico de un nettype que no haya visto.
