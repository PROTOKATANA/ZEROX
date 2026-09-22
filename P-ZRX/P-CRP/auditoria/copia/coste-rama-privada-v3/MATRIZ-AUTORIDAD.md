# CRP-v0.3 · Matriz de autoridad (revisa y sustituye la de v0.2)

Estados usados: `SPEC vigente`, `candidata`, `oráculo abstracto`, `implementada sin cablear`,
`integrada`, `pendiente`, `excluida`.
Validez de traza (trivaluada): `Válida`, `Inválida`, `Pendiente`. Una decisión ausente **nunca**
se resuelve localmente para obtener `Válida`.

## A · Selección y orden (GHOSTDAG)

| Regla | Fuente | Estado normativo | Integración | Depende de pendiente | Conclusión permitida |
|---|---|---|---|---|---|
| C-GD-01 peso `⌊2^128/(SR+1)⌋` | `SPEC.md` §11 | SPEC vigente | `ghostdag.rs` (sin cablear), GDR-v0.2 | — | identidad aritmética |
| C-GD-02 dominio `u256` | `SPEC.md` §11 | SPEC vigente | `BW256` en GDR / `checked_add` Rust | — | cota de no desbordamiento |
| C-GD-03 padre seleccionado | `SPEC.md` §11 | SPEC vigente | `ghostdag.rs`, GDR-v0.2 | C-GD-10 | desempate determinista |
| C-GD-04 mergeset y límites R-FIN-12 | `SPEC.md` §11 | SPEC vigente | `ghostdag.rs`, GDR-v0.2 | — | validez estructural |
| C-GD-05 orden del mergeset | `SPEC.md` §11 | SPEC vigente | `ghostdag.rs`, GDR-v0.2 | — | orden total |
| C-GD-06 k-cluster | `SPEC.md` §11 | SPEC vigente | `ghostdag.rs`, GDR-v0.2 | — | color azul/rojo_k |
| C-GD-07 U2/U3″ | `SPEC.md` §11 / R-FIN-11 | SPEC vigente | `ghostdag.rs`, GDR-v0.2 | — | validez / color |
| C-GD-08 acumuladores | `SPEC.md` §11 | SPEC vigente | `ghostdag.rs`, GDR-v0.2 | — | `blue_work` |
| C-GD-09 color contextual | `SPEC.md` §11 | SPEC vigente | `ghostdag.rs`, GDR-v0.2 | — | color no global |
| C-GD-10 padres barajados | `SPEC.md` §11 | SPEC vigente | `ci/reglas-sin-codigo.txt` | — | política de producción, no verificación |
| C-GD-11 bounded merge depth | `SPEC.md` §11 | SPEC vigente, **5 pendientes** | sin código | métrica, valor, bootstrap, borde, finalidad | validez de fusión condicionada |
| C-ORD-01 `rank` | `SPEC.md` §7.2 | SPEC vigente | `ghostdag.rs`, GDR-v0.2 | — | orden total |
| C-ORD-02 P1 selección de copia | `SPEC.md` §7.2 | SPEC vigente | `ghostdag.rs` (`seleccionar_copia`) | — | agrupa por billete |
| C-ORD-03 orden de aplicación | `SPEC.md` §7.2 | SPEC vigente | `ghostdag.rs`, GDR-v0.2 | — | orden de estado |
| C-ORD-04 conflictos | `SPEC.md` §11 | SPEC vigente | `ci/reglas-sin-codigo.txt` | UTXO/undo | descarte silencioso |
| `ghostdag.rs` | `crates/zx-consensus` | implementada sin cablear | no lo usa `zx-node` | — | instrumento Rust aislado |
| `fork_choice.rs` | `crates/zx-consensus` | ruta activa (PoW lineal) | `cadena.rs` | migración DAG | NO representa el DAG destino |
| GDR-v0.2 | `veritas/consenso/ghostdag-rank-v1/` | oráculo abstracto | este instrumento lo reutiliza | — | referencia GHOSTDAG |

## B · Prueba, flujo y rango

| Regla | Fuente | Estado normativo | Integración | Depende de pendiente | Conclusión permitida |
|---|---|---|---|---|---|
| C-HDR-05 slot no estricto | `SPEC.md` §6.1 | SPEC vigente | GDR-v0.2 lo aplica | — | restricción estructural |
| C-HDR-06 rango contextual | `SPEC.md` §6.1 | SPEC vigente, interfaz implementada sin cablear (`bloque_dag.rs`) | no lo usa `zx-node` | ventana/arranque/redondeos (TAREAS §2.3) | controlador **Pendiente** |
| C-HDR-07 justificación PoT | `SPEC.md` §6.1 | SPEC vigente | `wire_dag` devuelve `IntegracionPotPendiente` | verificador PoT AES | bloque no declarable válido |
| R-FIN-1a slot no estricto | SPEC §6.1 (C-HDR-05) / ancla-de-orden | SPEC vigente | GDR-v0.2 lo valida | — | restricción estructural |
| R-FIN-2/3 identidad de flujo | ancla-de-orden | candidata | `DescriptorFlujo` (estructural) | `Pot`/`PotOrigin` autorizados | compatibilidad estructural |
| R-FIN-4 validez absoluta | ancla-de-orden | candidata | no | flujo + PoT real | conservar `Pendiente` |
| R-FIN-5 pasado consistente de flujo | ancla-de-orden | candidata | `rfin5.jl` (estructural) | `PotOrigin`/`N(s)` autenticados | rechazo estructural, no "PoT verificado" |
| R-FIN-11 U2/U3″ | SPEC §11 (C-GD-07) / ancla-de-orden | SPEC vigente | `ghostdag.rs`, GDR-v0.2 | — | unicidad de billete |
| R-FIN-13′ retarget paga = cuenta | SPEC §7.2 / ancla-de-orden | SPEC vigente (acoplamiento); detalle de ventana candidato | no | ventana | no reutilizar tasas antiguas |
| R-FIN-14 reto por slot | ancla-de-orden | candidata | no | PoT AES, `N(s)`, `ρ_max` | reto secuencial |
| R-FIN-7 finalidad en tiempo | ancla-de-orden | candidata | sin código | `F` provisional, `Δ` sin medir | no garantía de pago |
| C-NET-31/32 PoT por slot cacheado | `SPEC.md` §16 (C-NET-31/32) | SPEC vigente, valores pendientes | `ci/reglas-sin-codigo.txt` | presupuesto CPU, caché por flujo | tensión caché global vs `(flujo,slot)` Pendiente |
| Dominio/autorización (DAV) | `veritas/consenso/dominio-autorizacion-v1/` | oráculo abstracto | no | — | permite hablar de `PotOrigin` como contrato |
| Contrato de billete CBE | `veritas/consenso/contrato-billete-v1/` | oráculo abstracto | no | — | identidad de billete supuesta |
| DAV/DA0/DCM | `veritas/consenso/identidad-disponibilidad-v1/` | oráculo abstracto | no | — | disponibilidad no implementada |
| DMS (Δ) | `veritas/finalidad/delta-medido-v1/` | oráculo abstracto | no | — | Δ sintética, no de red ZEROX |

## C · Retarget y finalidad

| Regla | Fuente | Estado normativo | Integración | Depende de pendiente | Conclusión permitida |
|---|---|---|---|---|---|
| Controlador del SPEC | SPEC §7.2/§6.1 | pendiente | no | ventana, arranque, redondeos, fusiones fuera de ventana | corrida adversaria **Pendiente** |
| RCE-v0.1 rev2 (+Z0) | `retarget-causal-endogeno-v1/` | oráculo abstracto (candidato) | `controlador_rce.jl` | asociación DAG→cohorte es oráculo | SR derivado en el perfil candidato |
| ARM-v0.1 | `admision-retarget-multivista-v1/` | oráculo abstracto (candidato) | vectores en tests | contexto de cierre desde DAG | no consenso |
| `F = 2 h` | MIGRACION §Parámetros | provisional | — | medición de Δ en red DAG | no cierra finalidad |
| Poda/IBD sucinto | `veritas/consenso/poda-post-v1/` | excluida (niveles) / abierta (recursiva) | no | — | sync sucinto **no disponible** |

## D · Conclusión de autoridad

- El **texto vigente** que este instrumento puede usar como autoridad es §6.1–§7.3 y §11 del SPEC,
  con C-GD-01…09, C-ORD-01…03 y C-HDR-06/07.
- El **flujo PoT conjunto (R-FIN-5)**, el **controlador del SPEC** y partes de **C-GD-11/finalidad**
  permanecen pendientes: todo veredicto global queda **inconcluso**, y las trazas que dependan de
  ellos quedan `Pendiente`.
- RCE/ARM, DAV, DCM y el contrato de billete son **instrumentos/oráculos**, no consenso activado.
