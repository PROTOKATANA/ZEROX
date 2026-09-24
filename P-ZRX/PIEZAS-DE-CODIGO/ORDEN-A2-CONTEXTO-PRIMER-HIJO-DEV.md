# ORDEN A2 · contexto PoT y rango del primer hijo DAG dev

**Ejecutor:** DeepSeek Harness, `deepseek-v4.1-flash`, esfuerzo `high`. **Pieza:** incremento A2/A3/C3; ninguna casilla se cierra por esta entrega. Lee `DECISIONES-0.0.1.md` PERFIL-PRIMER-HIJO-DEV, `SPEC.md` C-POT-01/02/04/05/06/08, C-FLU-06/14, C-HDR-05/06/07, los módulos citados abajo y esta orden antes de editar.

## Alcance y archivos exactos

- Crear `crates/zx-node/src/perfil_primer_hijo_dag_dev.rs` con el perfil **exclusivo de `zx-dag-dev`** y el contexto inmutable del primer hijo `{G}`.
- Añadir solo `pub mod perfil_primer_hijo_dag_dev;` a `crates/zx-node/src/lib.rs`.
- Crear `crates/zx-node/tests/perfil_primer_hijo_dag_dev.rs` con las pruebas descritas.
- `crates/zx-consensus/src/error.rs`: añadir **solo** una variante contextual genérica `ContextoRangoNoDisponible { motivo: &'static str }` (o nombre equivalente) a `ConsensusError`. `ContextoRangoDag` devuelve ese diagnóstico cuando una vista no aplica; `cabecera_conjunta` ya clasifica como `Pendiente` todo error de rango distinto de `RangoIncorrecto`. No reutilizar `PadreNoValidado`, `SaltoMayorSmax` ni `BloqueDesconocido` para encubrir una falta de contexto de rango.

No cambiar `bootstrap_dag_dev.rs`, `contexto_genesis_dag_dev.rs`, `Cargo.toml`, `Cargo.lock`, el binario, otros archivos de `zx-consensus`, `zx-core`, CI, SPEC, PDF ni archivos concurrentes. `zx-pot` ya figura como dev-dependency de `zx-node`; los tests pueden usarlo. No hacer commit ni push. Si una API obliga a ampliar archivos, **detente, explica cuál y por qué**.

## Perfil elegido, solo desarrollo

En el módulo nuevo declara constantes privadas `N_PRIMER_HIJO_DEV: u64 = 200_032_000`, `SR_PRIMER_HIJO_DEV: u64 = u64::MAX` y `MAX_SLOT_PRIMER_HIJO_DEV: u64 = 150`. `N` es múltiplo de 16 y coincide con la carga de la medición previa de `research/dag-poas-ancla-de-orden.md` (1,561 s `prove` en esta máquina en 2026-09-08), **no** con una cadencia garantizada hoy. `SR` tiene cobertura observada únicamente en el test local de una parcela de dos piezas con `N=16`; su tasa bajo `N_PRIMER_HIJO_DEV` y tres nodos **no está medida**. El límite 150 es el máximo de portadores de C-HDR-07, no un intervalo de consenso nuevo. El perfil **solo** declara ausencia de inyecciones dentro de esta ventana de primer hijo, y devuelve contexto ausente fuera de ella. No definir calendario de épocas ni controlador de lanzamiento. `D=0` sale del getter ya existente del bootstrap, no se duplica como constante contradictoria.

## API requerida

Implementa un tipo público de nombre inequívoco, por ejemplo `ContextoPrimerHijoPotDagDev`, con campos privados. Constructor público equivalente a

```rust
pub fn desde_bootstrap_y_cabecera(
    bootstrap: &EstadoBootstrapDagDev,
    cabecera: &DagBlockHeader,
) -> Result<ContextoPrimerHijoPotDagDev, ErrorPerfilPrimerHijoDev>
```

El constructor deriva `hash_candidato` de **esa cabecera**, llama `instantanea_primer_hijo(bootstrap, &cabecera.padres, cabecera.block_hash())`, exige `1 <= slot <= 150` y `bootstrap.retardo_pot_dev() == 0`, y guarda la identidad completa del candidato, su slot y la vista estructural inmutable. Un fallo de topología de la vista se conserva como error tipado, no se convierte en «cabecera inválida». No leer `pot_output`, `rango_solucion`, `timestamp`, `height` ni sello de la cabecera para definir `N`, `SR`, flujo, ancla o inyecciones. Conserva `BloqueDelPasado {hash:G, slot:0, flujo:f0}` como único elemento, derivado del bootstrap/vista; no aceptes una lista de pasado, `f0`, ancla, `N` o `SR` proporcionados por el candidato o el llamante. Expón getters de solo lectura para el hash/slot del candidato y `dag()` para pasar la vista estructural existente a A3. No escribas un método que declare `admitido`, `valido` o similar.

Implementa `zx_consensus::pot_rango::InstantaneaPot` para este tipo:

- `flujo_candidato_en(s)`: `f0` solo en `0..=slot_candidato`; fuera, `MotivoPotPendiente::ContextoAusente`.
- `pasado()`: el slice único de G y su flujo `f0`, **no** el candidato ni la cola no confiable.
- `inyecciones_en(s)`: `Ninguna` solo en `1..=slot_candidato`; fuera, error de contexto. La ausencia procede de la hipótesis **dev limitada a la primera ventana**, no de una derivación general de C-FLU-12.
- `iteraciones(s)`: `N_PRIMER_HIJO_DEV` solo en `1..=slot_candidato`; fuera, error de contexto. No derivar de cabecera ni de `pot_output`.
- `retardo_autoria()`: exactamente el getter `D_dev=0` comprobado en construcción.
- `salida_validada(s)`: **solo** `s=0` devuelve el ancla confiada de G; para cualquier otro slot, `ContextoAusente`. Nunca calcular la salida usando el `pot_output` del candidato.

Implementa `ContextoRangoDag` para el mismo tipo: devolver `SR_PRIMER_HIJO_DEV` solo si `CandidatoSinRango::padres()` es `{G}` y `slot()` coincide con el slot guardado; si no, `ConsensusError::ContextoRangoNoDisponible` con causa concreta. El esperado sale del perfil dev inmutable más `past={G}, f0`; jamás del `rango_solucion` declarado ni de otros campos del candidato. `CandidatoSinRango` no expone hash, así que este método **no** acredita identidad completa: documenta que el futuro llamante debe cotejar `cabecera.block_hash()` con el hash guardado **antes** de usar A3. No simules ese cotejo mediante un `Ok` sobre otra cabecera.

## Pruebas que distingan un puente real de un mock

1. Con `iniciar_bootstrap_dag_dev` y una cabecera `{G}` de slot 1, construir el contexto. Comprobar el pasado exacto G/slot0/f0, el ancla solo en 0, `N=200_032_000` para slot1, D=0, rango esperado `u64::MAX`, sin inyección; consultas de slot0 para N, slot2 para N, slot1 para salida acreditada, y slot151 en constructor deben fallar con diagnóstico. Padres ajenos o extras no dan contexto.
2. Producir **un portador real** desde el ancla G con `zx_pot::prove(PotSeed::from(semilla_siguiente(ancla, None)), NonZeroU32::new(200_032_000))`, convertir con `checkpoints_a_wire`, construir una cabecera `{G}` slot1 cuyo `pot_output` sea el último checkpoint y `JustificacionPot::nueva(vec![wire])`. Verificar el núcleo `verificar_rango_pot` con el contexto construido, reloj PoT=1, `CachePotVerificada::nueva()` y presupuesto explícito de un slot; exigir `PotValido` y la salida auditada indirectamente si la API pública lo permite. **No** pasar por A3 ni afirmar PoAS/sello/cuerpo. Alterar un checkpoint y exigir `PotInvalido(AesFallido)`; alterar solo `pot_output` con contexto reconstruido y exigir `PotInvalido(PotOutputNoCoincide)` (o motivo exacto que produzca el núcleo, documentado).
3. Construir una segunda cabecera de igual `{G}`/slot con `pot_output`, `timestamp`, `height` y `rango_solucion` diferentes; comparar los valores de contexto de `N`, flujo, ancla e inyecciones. Deben ser idénticos porque proceden de G/perfil; los hashes de candidato deben diferir. Si se cambia solo `rango_solucion`, `RangoSolucionValidado::validar` o `comprobar_rango_contextual` debe rechazar el declarado distinto del fijo; nunca convertirlo en esperado.
4. Demostrar el límite de identidad: `ContextoRangoDag` no puede distinguir dos cabeceras con los mismos padres/slot por su vista opaca; el getter del hash sí las distingue. Registrar que el futuro wrapper de admisión debe cotejar la identidad antes de llamar A3. No escribir una prueba que presente el método contextual aislado como admisión.

Los tests pueden tardar ~1,5 s por el portador real. No rebajar `N` en la ruta pública para que pasen. Si el coste es muy superior, reporta la medición observada, sin retocar la constante para alcanzar 1 s.

## Entrega

Ejecuta `cargo test -p zx-node --locked --test perfil_primer_hijo_dag_dev`, `cargo fmt --all -- --check`, `cargo clippy -p zx-node --all-targets --locked -- -D warnings`, `ci/citas-spec.sh`, `ci/alcance-consenso.sh` y `git diff --check`. Informa diff y resultados. La puerta de admisión sigue pendiente; **no marcar A2/A3/C3**. La variante contextual de `ConsensusError` autorizada arriba es el único cambio permitido en `zx-consensus`.
