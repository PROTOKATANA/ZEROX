# P-CRP · RECOMENDACIÓN DE MIGRACIÓN

**No he migrado nada.** El encargo §5 lo prohíbe expresamente. Esto es una recomendación para Katana.

Punto de partida comprobado: los dos instrumentos **reejecutan** (tests y artefactos numéricos
byte a byte, `INFORME.md` §2.1), GDR-v0.2 **no ha cambiado** desde el 2026-09-18
(`PROGRESO.md` §2) y sus `HUELLAS.sha256` internas verifican. Lo que sigue es qué merece migrarse,
con qué correcciones previas y con qué etiqueta.

---

## 1 · Veredicto por instrumento

| Instrumento | ¿Migrar? | Etiqueta propuesta | Condición |
|---|---|---|---|
| **CRP-v0.2** | **No** (salvo como anexo) | `evidencia histórica de la etapa v0.2` | Superado por v0.3 en todo lo que decide: flujo por bloque, tres eventos, `S` conjunto, decisión del observador. Su R-FIN-5 en el DAG es un **proxy de rama** (`_flujo_en`), no un prefijo de flujo (`DEFECTOS.md` C11), y publica intervalos de Wilson de **40** réplicas como si fueran de 64 (`DEFECTOS.md` B1). Conservarlo en `P-ZRX/rescate-deepseek/`, que ya lo tiene, con la nota «no migrado: superado por v0.3». |
| **CRP-v0.3** | **Sí, con correcciones previas y veredicto rebajado** | `veritas/seguridad/coste-rama-privada-v3/` — categoría `seguridad`; estado: **instrumento**; conclusión literal propuesta: *«Umbral protocolario inconcluso; el baseline idealizado no sustituye las reglas pendientes. Frontera medida **solo** para el contrafactual aditivo, que no es una regla vigente.»* | Ver §2. |

**Por qué v0.3 y no v0.2:** v0.3 es el único que (a) lleva `DescriptorFlujo` por bloque y aplica la
comprobación sobre **todo** `past(B)` antes de colorear, (b) separa `P_terminal`/`P_first_passage`/
`P_eventual` y calcula `α_prob` con cobertura simultánea, (c) genera los `S` flujos desde
oportunidades compartidas con controles de correlación, (d) modela presentación, fusión y decisión
del observador, y (e) registra `rgdr` (truncamiento por `s_max`) en vez de ocultarlo. v0.2 no tiene
nada de eso.

---

## 2 · Correcciones previas obligatorias (antes de mover un solo fichero)

Cada una está detallada en `DEFECTOS.md`.

### Bloqueantes (cambian lo que el instrumento puede afirmar)

1. **Re-derivar las semillas de réplica** (`A1`) y **reejecutar todos los barridos**. Mientras las
   réplicas sean `StableRNG(SEMILLA + r)`, los IC de Wilson publicados no son IC. Usar un RNG
   contracorriente con la derivación correcta (`set_counter!(r, (0, id))`, ver `A2`) y publicar la
   configuración. **Sin esto no se migra.**
2. **Cerrar el puente `espacio → tasa` o declarar su ausencia en la portada** (`C1`). Hoy todas las
   `α` son probabilidades de oportunidad por slot; el encargo preguntaba por fracción de espacio.
   La fila H1 de `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md` afirma una derivación PoAS que **no
   existe**. Hay que borrar esa afirmación y añadir el límite.
3. **Reetiquetar R-FIN-5**: con `C-FLU-13/14` redactadas el 2026-09-20, «candidata» ya no es
   correcto; y a la vez hay que decir que `flujo(B, ·)` se **declara** en el fixture en vez de
   derivarse de `past(B)`, luego el instrumento reproduce la **forma** de `C-FLU-14` y **no** puede
   acreditar la regla (`C3`/D-d, `BASELINE.md` escenario 3).
4. **No presentar «frontera medida» sin el matiz**: las celdas con R-FIN-5 son `0/n` en todos los
   barridos; lo único con señal positiva es el contrafactual aditivo. La frase de cierre de v0.3
   («Frontera medida para los escenarios ensayados») es engañosa tal cual.

### Necesarias (documentación y honestidad del entregable)

5. **`HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md` propio de v0.3** — hoy es el de v0.2 byte a byte
   (`B2`). Debe listar sus tautologías: `η_a ≡ 1`, semillas consecutivas, `autenticado` de fixture,
   `α` como tasa, rojos por unión de contextos, y la identidad del toy `1/(S+1)`.
6. **`MATRIZ-AUTORIDAD.md`**: `:41` cita `rfin5.jl` (no existe en v0.3) → `flujo.jl` (`B3`); `:13`
   «`BW256` en GDR» → GDR acumula en `BigInt` (`B4`); `:28` «ruta activa (PoW lineal)» no es un
   estado admitido (`B5`); y la fila C-NET-31/32 debe seguir en `§16` (ya corregida).
7. **`MATRIZ-VALIDEZ.md`**: o se admite explícitamente una etiqueta adicional «Válida estructural»
   con su definición, o se sustituye por `Pendiente` con motivo; hoy contradice la declaración de
   validez trivaluada de `MATRIZ-AUTORIDAD.md:5-6` (`B6`).
8. **`INFORME.md`**: `:17` cita `SWEEP-DAG.txt` para la fusión (no contiene fusiones) → citar
   `test/runtests.jl:91-93` (`B7`); `:20` no puede decir «medido» del drenaje terminal (`B8`).
9. **`η`**: o se redefine `_eta_rama` para que el denominador y el numerador no sean idénticos por
   construcción, o se cambia la etiqueta de `η_a` de «medido» a «identidad del modelo» (`C4`).
   Lo mismo con el recuento de rojos: por contexto, no unión (`C5`).
10. **`horizonte_justificacion_ok`**: implementar lo que promete el docstring o declararlo un no-op
    (`C6`).
11. **`dp_adaptativa`**: devolver un marcador cuando se topa con `max_ancho` sin cumplir `tol`, en
    vez de devolver la corrida como si estuviera certificada (`C9`).
12. **Mutation tests reales** o declarar que el criterio §4 del encargo no se cumple (`C8`).

### De forma

13. `gdr_wrapper.jl` debe apuntar a la ruta que resuelve desde `veritas/seguridad/…`, **no** a la de
    `deepseek/` ni a una ruta absoluta de mi máquina. Desde
    `veritas/seguridad/coste-rama-privada-v3/src/` la ruta correcta es
    `joinpath(@__DIR__, "..", "..", "..", "consenso", "ghostdag-rank-v1", "src", "GhostdagRank.jl")`.
14. Reescribir las rutas `deepseek/…` que quedan en `ENTRADA.md`, `CONTRATO.md` y `PROCEDENCIA.md`
    como `P-ZRX/rescate-deepseek/…`, y anotar que `ENTRADA.md` es copia del encargo 07v2.
15. Añadir `PROCEDENCIA.md`/`BITACORA.md` como exige el patrón de `veritas/` (v0.3 trae
    `PROCEDENCIA.md` pero no `BITACORA.md`).

---

## 3 · Qué **no** debe migrarse con la etiqueta de «medido» o «umbral»

- `α_drift = 1/2` como umbral del protocolo: es una identidad del baseline.
- `α = 1/(S+1)` y `0,040 con S = 24`: identidad del toy aditivo, y el multistream está cerrado por
  `C-FLU-13`.
- `η_a = 1,0`: identidad de una rama que es cadena.
- `S = 24` como capacidad: es un escenario de barrido; `S_adversario` sigue `pendiente`.
- «PoT verificado»: no hay PoT AES; es compatibilidad estructural.
- Cualquier IC publicado con las semillas actuales, mientras no se re-deriven.

## 4 · Qué **sí** conviene preservar y migrar aunque el instrumento no se migre

- `src/referencia.jl` + `src/dp.jl` (v0.3): DP exacta y acotada con masa cruda; certificada aquí
  contra el oráculo `Rational{BigInt}` con error ≤ `5,7e-16` en la rejilla publicada. Es la pieza
  más reutilizable de las dos.
- `src/eventos.jl`: separación de los tres objetos y `α_prob` con cobertura simultánea
  (Clopper–Pearson + Bonferroni), con la regla «`0/n` nunca es frontera».
- `src/gdr_wrapper.jl` + los fixtures de color: capa fina y correcta sobre GDR-v0.2, con color
  **contextual** y `blue_work` recomputado desde los conjuntos azules.
- `src/validacion.jl`: `identidad_iid_S` frente a `mc_max_S` es un contraste **independiente** real
  (no tautológico) y merece conservarse.
