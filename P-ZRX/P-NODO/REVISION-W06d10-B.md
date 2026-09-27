# REVISIÓN W06d10-B — lo que depende de la vista local no penaliza al par

**Revisor:** Claude (director). **Fecha:** 2026-09-28 (≈ 00:56). **Ejecutor:** DeepSeek, 23:45–00:55 (dentro de
1 h 30 min). Evidencia: `resultados-W06d10-B/`; ejecuciones reales en `deepseek/W06d10-B/run/`. **Veredicto: SUPERADO.
Migrada** por parche (`nodo.rs`, `rechazo.rs` y un test nuevo; base intacta: `ENTRADA-W06d10-B.sha256` verde en la raíz,
`ws.orig/crates` idéntico a la raíz; `MIGRACION.sha256` verde; archivos de la raíz idénticos a la zona).

- **Clasificación nueva `VistaLocal`** (`rechazo.rs`): no es legítima ni penaliza. `ErrLimiteTerminales` → `VistaLocal`;
  los errores PoW se clasifican con el contrato del propio tipo (`ErrorPow::es_permanente()`): el FTL (C-TS-03) es
  `VistaLocal`, lo permanente sigue siendo `Interno` y penaliza.
- **`nodo.rs`:** X1, X2 y X3 → `Ignorar` en gossip y sincronización, con el evento de diagnóstico
  `bloque_red_vista_local`; también el motivo cacheado no penalizable y el **padre conocido con motivo de vista local**
  (hallazgo del ejecutor por la decisión 4). Los defectos del candidato que antes salían como `ErrorNodo::Otro` (`bits`,
  `target`, `trabajo`, `peso`) se envuelven como `Interno` para seguir penalizando. `error_atribuible_al_candidato` es
  conservador: ante la duda, `Ignorar` (un falso negativo es menos dañino que vetar a un honesto).
- **Costuras de test** (`fallo_local_simulado`, `reloj_local_simulado`) bajo `#[cfg(test)]`: no existen en el binario de
  producción (comprobado en el diff).

| Paso | Comprobado por el director |
|---|---|
| V1/V2 | Tests por familia en las dos rutas y regresión de lo demostrable: verdes (informe) |
| V3 | E-7 semilla 101: 4 rechazos, 4 `par_penalizado`, 0 desconexiones de B y C, convergencia W07d; red de tres nodos al slot 150: 0 `par_penalizado`, 0 `fallo_productor` |
| V4 | `logs/v4-test.log`: **891/0/6** en 85 binarios; fmt, clippy, guardianes y T01/T04 verdes (informe) |

**Límite aceptado (falta de definición bien informada antes de editar):** X2 queda cacheado como inválido en
`zx-cadena` (`Cadena::admitir` guarda todo rechazo y no hay API para olvidarlo; `zx-cadena` estaba vedado). Nunca
penaliza ni vuelve a ser `Rechazar`, pero **no se reevalúa** si la vista local cambia. Solo importa con más de 8
terminales compitiendo en el corte. Pasa a IPA como límite de 0.0.1 (arreglo en 0.0.2: `Cadena::olvidar` o no cachear
`ErrLimiteTerminales`).
