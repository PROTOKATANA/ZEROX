# Informe: Redundancia del Timelord en ZEROX

**Fecha:** 2026-09-07 · Agente de Diseño, Problema 4 (B7)
**Fuentes:** Documentación de Chia Network (docs.chia.net), código de Subspace/Autonomys (`subspace @ f8842d0`), FIP-0086 (Filecoin F3), eth2book.info (RANDAO), drand.love.

---

## 1 · Estado del arte en redundancia de VDF/Timelord

### 1.1 · Chia Network — competición natural

Chia opera **múltiples timelords simultáneos** que compiten en una carrera secuencial. Dado que la VDF de Chia (Wesolowski sobre grupos de clase) es **determinista**, todos los timelords producen **el mismo output** para el mismo input (Proof of Space + iteraciones). Solo el más rápido logra terminar primero y su output se propaga por la red; los demás abandonan la carrera actual y saltan al siguiente "dash".

- **Redundancia:** implícita. Si el timelord más rápido cae, el segundo más rápido gana la carrera y la red no se detiene.
- **Operación:** Chia Network Inc. corre varios timelords (incluyendo ASIC) en ubicaciones estratégicas globales, más backups.
- **Coordinación:** **ninguna**. No hay consenso, comité ni timeout entre timelords. Es competición pura.
- **Seguridad:** un atacante con un timelord más rápido puede orphannear o censurar, pero **no puede parar la red** a menos que sea el único timelord existente.
- **Bluebox timelords:** secundarios que compactan pruebas históricas; no afectan la liveness.

### 1.2 · Autonomys/Subspace — timekeeper único con verificación abierta

Autonomys implementa un **timekeeper único por nodo** (`is_timekeeper: bool` en `sc-proof-of-time/src/source.rs:80`). Este timekeeper produce una cadena secuencial de PoT (AES repetido, `subspace_proof_of_time::prove`). Los outputs se gossipan por el topic `/subspace/subspace-proof-of-time/1` y **cualquier nodo puede verificarlos** (`PotVerifier::verify_checkpoints`, `verifier.rs:228`).

- **Redundancia hoy:** limitada. Solo el nodo configurado como timekeeper produce. Si no hay timekeeper en la red, no hay nuevos slots PoT y la cadena se detiene.
- **Recuperación:** el código contiene un TODO explícito (`source.rs:291`): *"Follow both verified and unverified checkpoints to start secondary timekeeper ASAP in case verification succeeds"*. Esto indica que los desarrolladores reconocen la necesidad de un arranque rápido de timekeepers secundarios, pero **no está implementado**.
- **Reorg:** la cadena de PoT se reescribe si la cadena de bloques reorganiza (`PotStateUpdateOutcome::Reorg`).
- **Barrera de entrada:** cualquiera puede activar `is_timekeeper = true`. No hay permiso, staking ni registro.

### 1.3 · drand — umbral criptográfico, no VDF secuencial

drand genera beacons de aleatoriedad pública usando **threshold cryptography** (BLS signatures). Un comité de nodos (League of Entropy) firma colectivamente; se necesita un quorum (`> 2/3`) para producir una firma válida.

- **Redundancia:** hasta `f < n/3` nodos pueden caer o ser bizantinos sin afectar la liveness.
- **Relación con ZEROX:** demuestra que un servicio crítico puede tener redundancia sin punto único de fallo, pero **usando un mecanismo distinto** (threshold signatures vs. VDF secuencial). drand no impone un delay temporal verificable; reemplaza el "tiempo" por "acuerdo criptográfico".
- **Conclusión:** no es aplicable directamente como reemplazo del PoT de Autonomys, que sí necesita el delay secuencial.

### 1.4 · Filecoin F3 — BFT sobre heaviest-chain, sin VDF

Filecoin no usa VDF. Su consenso base (Expected Consensus, EC) es heaviest-chain con tipsets. F3 (FIP-0086) añade una capa de BFT (GossiPBFT) que finaliza tipsets en decenas de segundos.

- **Redundancia:** F3 es un comité de storage providers ponderados por QAP. Si F3 se detiene, EC sigue funcionando (availability sobre consistency).
- **Relación con ZEROX:** F3 resuelve finalidad rápida, no aleatoriedad impredecible. No aplica al problema del timelord.

### 1.5 · Ethereum Beacon Chain — RANDAO acumulativo, sin VDF desplegado

Ethereum no usa VDF en producción. Su aleatoriedad (RANDAO) es un acumulador de BLS signatures de los proponentes de bloques.

- **Redundancia:** no hay un único productor de aleatoriedad. Cada proponente aporta un bit. Si un proponente falta, el acumulador simplemente no se actualiza en ese slot.
- **Vulnerabilidad:** un proponente puede sesgar un bit (withholding). Esto es un problema de impredecibilidad, no de liveness.
- **VDF propuesto:** se ha discutido añadir un VDF tras el RANDAO para eliminar el sesgo, pero "no hay plan activo de implementarlo" (eth2book). El VDF propuesto sería un **único servicio**, similar al timelord, con la misma pregunta de redundancia.

---

## 2 · Evaluación de mitigaciones

| Opción | ¿Impredecibilidad? | ¿Unicidad de flujo? | Coste operativo | Complejidad | Veredicto |
|---|---|---|---|---|---|
| **A. Comité de timelords** | Sí. La VDF es determinista; mismos inputs → mismo output. | Sí. El flujo es función de la cadena seleccionada (R-FIN-3), no del productor. | Medio. `n` CPUs rápidas. | Baja. Sin coordinación. | **Viable** |
| **B. Principal + fallback por timeout** | Sí. | Sí. | Medio. | Media. El timeout es sensible a relojes y a retrasos inducidos. | Viable pero innecesario; A lo hace sin timeout. |
| **C. VDF verificable por cualquiera (productor designado)** | Sí, pero sin mecanismo de sucesión. | Sí. | Bajo. | Baja. | **Parcial.** Autonomys ya está aquí; falta el arranque automático del secundario. |
| **D. PoW de emergencia** | Sí, pero introduce mecanismo ajeno. | Sí. | Alto (infraestructura PoW). | Alta. Cambio de modelo de consenso transitorio. | **Descartado.** Vector de ataque: forzar caída del PoT para minar PoW. |
| **E. Múltiples cadenas VDF independientes** | **No.** El atacante elige el inyector entre varios. | **No.** Divergencia de flujo en el mismo slot. | Alto. | Muy alta. | **Descartado.** Rompe R-FIN-2 y R-FIN-3. |
| **F. Competición natural (Chia-style) + redundancia operativa** | Sí. | Sí. | Medio. | **Mínima.** | **Recomendada.** |
| **G. Checkpoints + arranque secundario inmediato** | Sí. | Sí. | Medio. | Baja. | **Recomendada como complemento de F.** |

### Notas por opción

**Opción A vs. F:** En la práctica son la misma opción. La diferencia es semántica: A suena a "comité coordinado", mientras que F es "competición sin coordinación". Dado que la VDF de Autonomys es determinista, no hay nada que coordinar. No se reintroduce ningún problema de acuerdo porque **no hay elección que hacer entre outputs honestos**.

**Opción B:** El timeout es peligroso. Si el atacante retrasa (no tumba) al principal justo hasta antes del timeout, forzaría la activación del fallback. Como ambos producen el mismo output, esto no es un ataque de consenso, pero introduce oscilación y complejidad innecesaria. En una VDF determinista, si hay un secundario computando, su output llega automáticamente sin necesidad de timeout.

**Opción D:** El PoW de emergencia es un mecanismo completamente ajeno al diseño actual. Un atacante que puede DDoS el timelord puede intentar forzar la caída para beneficiarse del PoW. Además, el DAG de ZEROX no tiene dificultad de PoW; la dificultad es sobre el espacio. No encaja.

**Opción E:** Múltiples cadenas de VDF significan múltiples inyectores posibles para la misma época. Esto reabre exactamente el ataque de grinding que R-FIN-2 cierra: el atacante podría elegir la cadena de VDF que le dé mejor `entropía_j`.

---

## 3 · Recomendación de diseño

### 3.1 · Estrategia: Opción F + G

**Redundancia operativa al estilo Chia, con checkpoints verificables para recuperación inmediata.**

La VDF de Autonomys (AES secuencial, `subspace_proof_of_time`) es determinista: para un `seed` y `slot_iterations` dados, existe un único `output` válido. Esto elimina el problema de acuerdo: múltiples timelords no generan conflictos, generan **el mismo flujo**.

Por tanto, la mitigación no requiere un protocolo nuevo. Requiere:

1. **Permiso implícito:** cualquier nodo puede ser timelord. No hay identidad, staking ni registro.
2. **Redundancia operativa:** se fomenta que múltiples operadores (incluido el operador principal de ZEROX con backups geodistribuidos) ejecuten timelords simultáneamente.
3. **Gossip anónimo:** los outputs se publican en el topic de PoT. Los nodos aceptan el primero válido que reciban (todos son idénticos).
4. **Checkpoints públicos:** cada output de PoT incluye checkpoints intermedios (`PotCheckpoints`). Un nodo que solo verifica puede, tras validar los checkpoints del último slot, arrancar como productor del siguiente slot sin recomputar toda la historia.

### 3.2 · Justificación respecto a las propiedades del DAG

- **Impredecibilidad del inyector:** La impredecibilidad viene del *delay* de la VDF, no de quién la computa. Si un atacante controla un timelord, no puede acelerar el cálculo. Si controla todos los timelords, sigue sin poder acelerarlo. Múltiples productores no debilitan la impredecibilidad.
- **Unicidad del flujo de PoT:** El flujo `flujo(B, s)` (R-FIN-3) es determinista una vez fijada la cadena seleccionada. Dos timelords que sigan la misma cadena seleccionada producen exactamente el mismo `pot_output(I_j)`. Dos timelords en particiones distintas producen flujos distintos, pero R-FIN-5 ya impide que un bloque referencie un flujo ajeno.
- **Coste operativo:** bajo. Una CPU rápida por instancia. No se comparan con el coste de un ASIC de Chia.
- **Complejidad de implementación:** mínima. El código de Autonomys ya soporta `is_timekeeper` en cualquier nodo. El cambio es operacional y de configuración de red, no de consenso.

### 3.3 · Cambios propuestos al SPEC

Añadir una sección **C-TIMELORD** con las siguientes reglas:

- **C-TIMELORD-01:** Cualquier nodo de la red puede producir un PoT válido. Los nodos aceptan cualquier PoT que verifique criptográficamente sobre el flujo derivado de su cadena seleccionada.
- **C-TIMELORD-02:** No existe identidad, permiso ni staking asociado al rol de timelord. La validez del PoT es puramente criptográfica.
- **C-TIMELORD-03:** Se recomienda redundancia operativa: múltiples instancias de timelord en ubicaciones geográficas y proveedores de red independientes.
- **C-TIMELORD-04:** El protocolo de gossip de PoT incluye checkpoints intermedios para permitir que un nodo verificador se convierta en productor sin recomputar la cadena de PoT desde el génesis.

**Nota sobre P-038:** Esta recomendación satisface la condición 1 para reabrir P-038: "Especificar redundancia de timelord (respuesta a B7)". No requiere modificar ninguna regla R-FIN existente, porque las reglas de consenso del DAG ya tratan el flujo como anónimo y determinista.

### 3.4 · Análisis de ataque residual

**Ataque:** Un adversario DDoS **todos** los timelords honestos simultáneamente.
- **Impacto:** la cadena se detiene (stall) hasta que un nuevo timelord arranque.
- **Mitigación:** con checkpoints (C-TIMELORD-04), cualquier nodo que haya estado verificando puede activarse como timelord en segundos, no en horas. El atacante tendría que mantener el DDoS contra **toda** la red indefinidamente.
- **Comparación:** Este es el mismo modelo de riesgo que Chia acepta: la red se detiene si no queda ningún timelord, pero la barrera para levantar uno es baja.

---

## 4 · Pseudocódigo

### 4.1 · Nodo con múltiples timelords (vista del nodo honesto)

```rust
// En el nodo honesto: no importa de qué timelord llega el PoT.
// El gossip acepta cualquier proof válida sobre el next_slot_input esperado.

fn handle_pot_gossip(proof: GossipProof) {
    let expected = self.state.next_slot_input();
    
    if proof.slot != expected.slot 
       || proof.seed != expected.seed
       || proof.slot_iterations != expected.slot_iterations {
        return; // mismatch, posible reorg en curso
    }
    
    if self.pot_verifier.verify_checkpoints(proof.seed, proof.slot_iterations, &proof.checkpoints) {
        // Válida. Extiende el estado local.
        self.state.try_extend(expected, proof.slot, proof.checkpoints.output(), None);
        
        // Notifica a productores de bloques (slot_worker).
        self.slot_sender.send(PotSlotInfo { slot: proof.slot, checkpoints: proof.checkpoints });
        
        // Re-gossip a peers.
        self.gossip_engine.broadcast(proof.encode());
    } else {
        self.punish_peer(sender, INVALID_PROOF);
    }
}
```

### 4.2 · Timelord (productor de PoT)

```rust
fn run_timekeeper(state: Arc<PotState>, verifier: PotVerifier, sender: mpsc::Sender<Proof>) {
    let mut next_input = state.next_slot_input();
    
    loop {
        // La VDF es puramente secuencial y determinista.
        let checkpoints = prove(next_input.seed, next_input.slot_iterations);
        
        // Inyecta en el caché local del verificador para que handle_pot_gossip
        // no tenga que reprobar este slot si llega de otro peer.
        verifier.inject_verified_checkpoints(next_input.seed, next_input.slot_iterations, checkpoints);
        
        let proof = TimekeeperProof {
            slot: next_input.slot,
            seed: next_input.seed,
            slot_iterations: next_input.slot_iterations,
            checkpoints,
        };
        
        sender.try_send(proof);
        
        // Avanza al siguiente slot.
        next_input = state.try_extend(next_input, proof.slot, checkpoints.output(), None)
                         .unwrap_or_else(|e| e);
    }
}
```

### 4.3 · Arranque de timelord secundario desde checkpoints

```rust
fn bootstrap_timekeeper_from_checkpoints(
    latest_verified_slot: Slot,
    checkpoints: &[PotCheckpoints],
    parameters: &PotParameters,
) -> PotNextSlotInput {
    // El nodo ha estado verificando. Tiene los checkpoints de cada slot.
    // No necesita recomputar; solo avanza el estado interno.
    let mut input = derive_genesis_input(parameters);
    
    for (i, cp) in checkpoints.iter().enumerate() {
        let slot = Slot::from(i as u64 + 1);
        // Verificación rápida (paralela) de los checkpoints.
        assert!(verify(input.seed, input.slot_iterations, cp));
        input = PotNextSlotInput::derive(input.slot_iterations, slot, cp.output(), &parameters.next_change());
    }
    
    input // Ahora es el next_slot_input vigente; el timekeeper puede empezar a prove aquí.
}
```

---

## 5 · Conclusión

El problema del timelord único (B7) es **operativo, no de consenso**. La solución más simple y segura es explotar la **determinismo de la VDF de Autonomys**: múltiples timelords producen el mismo flujo, por lo que no hay conflicto que resolver. La red gana redundancia corriendo varios timelords independientes, igual que Chia. El protocolo no necesita comités, timeouts, ni PoW de emergencia. Solo necesita:

1. Permitir explícitamente que cualquier nodo sea timelord (sin permiso).
2. Publicar checkpoints para arranque instantáneo de timelords secundarios.
3. Recomendar redundancia operativa geodistribuida.

Esto cierra B7 sin tocar las reglas R-FIN del DAG y sin reintroducir ningún problema de acuerdo.
