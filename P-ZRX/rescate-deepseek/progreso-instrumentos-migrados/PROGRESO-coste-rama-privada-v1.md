# PROGRESO — CRP-v0.1

Bitácora con fecha. Ejecutor: DeepSeek. Encargo: `deepseek/ENCARGO-07-coste-rama-privada.md`.

## 2026-09-18 · antes de ejecutar

**`git -C /home/katana/zeo/ZEROX status --short` (registro de apertura):**

```
 M SPEC.md
 M TAREAS.md
 M ci/reglas-sin-cablear.txt
 M ci/reglas-sin-codigo.txt
?? veritas/consenso/poda-post-v1/
```

`deepseek/` está en `.gitignore` (`.gitignore:18`), por eso las fuentes y artefactos de este
encargo **no** aparecen en `git status --short`; no se escribe nada fuera de `deepseek/`.

**Presupuesto declarado:** 64 GiB RAM, 24 hilos (tope), 4 GiB disco, 6 h de cómputo. Uso real: < 2 GiB
RAM, < 50 MiB disco, < 1 h; pico de hilos 24 (sólo en el barrido de escalado). No se supera el tope.

**Fuentes leídas antes de modelar:** `veritas/LINEO.md` (entero), `deepseek/ENCARGO-07…`,
`veritas/consenso/poda-post-v1/{INFORME,MODELO,PROCEDENCIA,PROPUESTA}.md`,
`deepseek/veritas/consenso/prueba-recursiva-v1/INFORME.md` (§1.2, §1.5.3), `SPEC.md` §7.2/§7.3/§11
(C-HDR-06, C-GD-01/02/03/04/05/06/07/08/09/10/11, C-ORD-01..04), `TAREAS.md` §2.2–2.4,
`research/dag-poas-auditoria.md` (A3, A4, ATAQUE 2), `research/dag-poas-ancla-de-orden.md`
(R-FIN-8′, R-FIN-11, R-FIN-13′, R-FIN-14), `veritas/finalidad/delta-medido-v1/INFORME.md`.

## 2026-09-18 · juicio de las cuatro trampas (antes de ejecutar)

Ninguna está mal planteada. Se refinan (§`INFORME.md`):

1. **Doble uso.** Correcta: no baja el umbral. Precisión: publicar en la honesta da `α*=1`, luego
   retener domina; el umbral operativo es `1/2`. La diferencia es de coste, no de umbral.
2. **`SR` endógeno.** Correcta, pero el resultado es más fuerte de lo que sugiere: con el
   acoplamiento `sr_val = sr_peso` (que el SPEC ya tiene) la **media** es exactamente
   `sr`-independiente y la **dirección del controlador es irrelevante**; el riesgo real es de
   **varianza** (colibrí de bloques pesados), acotable por propiedad MUST.
3. **Long-range.** Correcta y separada. Añadido: no hay descuento long-range salvo multistream de
   PoT.
4. **U2/U3″ contextual.** Correcta; verificada contra el oráculo en los dos sentidos.

## 2026-09-18 · ejecución

- Proyecto aislado en `deepseek/veritas/seguridad/coste-rama-privada-v1/`; `Project.toml` recortado a
  9 dependencias/stdlib (copiado del 06, que ya estaba recortado; `Manifest.toml` de 8 118 B).
- `src/` (modelo, referencia exacta, kernel MC + reúso GDR, validación), `test/`, `bench/`, `run.jl`.
- Correcciones durante el desarrollo, todas con prueba: signo de la difusión; índice del DP de
  alcance; `α_estrella` para el modo publicación; conversión `UInt64` en el controlador; eliminación
  del cálculo de peso del bucle caliente (26 000 → 26 allocs).
- Suite: **45/45** (`resultados/TESTS.txt`).
- Resultados por modo en `resultados/run-*.txt`; benchmark `BENCH.txt`; escalado `ESCALADO.txt`.

## 2026-09-18 · cierre

**Hallazgo principal.** `α_mínimo = 1/2` (media, ambos regímenes) para los tres protocolos bajo el
mismo criterio; el DAG mejora la cola corta (varianza) pero no el umbral; el doble uso no baja el
umbral y sí explica *nothing-at-stake*; el único vector que baja el umbral es el multistream de PoT,
**condicional** al diseño del flujo.

**`git -C /home/katana/zeo/ZEROX status --short` (registro de cierre):**

```
 M SPEC.md
 M TAREAS.md
 M ci/reglas-sin-cablear.txt
 M ci/reglas-sin-codigo.txt
?? veritas/consenso/poda-post-v1/
```

Idéntico al de apertura: nada fuera de `deepseek/`; SPEC.md y TAREAS.md no se tocaron aquí (sus
modificaciones son previas y ajenas a este encargo).

**Estado:** listo para validación reejecutando. Nada se migra ni se commitea desde aquí.
