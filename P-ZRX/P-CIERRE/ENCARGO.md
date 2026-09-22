# P-CIERRE — Cerrar `TAREAS.md` §2.1 en el SPEC: migrar la evidencia e integrar las dos propuestas

**Zona de informes: `P-CIERRE/ejecucion/`.** **Diseñado por:** Claude, 2026-09-20. **Decide y commitea:
Katana.** Es trabajo de **integración**, no de investigación: **no se inventa ni se mejora ninguna regla**.
Todo lo que entra al SPEC sale de dos propuestas **ya validadas y con todas sus decisiones tomadas**.

**DOS FASES, con parada obligatoria entre ellas.** La fase 1 **no toca** `SPEC.md`, `TAREAS.md` ni `ci/`.

## 0 · Lecturas

`AGENTS.md`, `MIGRACION.md` y `SPEC.md` §0 (convenciones) · `P-2.1/SINTESIS.md` entero (el hilo completo
de decisiones, incluidas las correcciones) · `P-POT/propuesta/PROPUESTA-SPEC.md` y
`DECISIONES-PENDIENTES.md` · `P-FLUJO/propuesta/PROPUESTA-SPEC.md` y `DECISIONES-PENDIENTES.md` (versión
final, con D-F1…D-F10 decididas) · las cuatro `P-CIERRE/procedencia/PROCEDENCIA-*.md` · como precedente de
forma: `veritas/consenso/ghostdag-rank-v1/` (instrumento + `PROPUESTA-SPEC.md`) y
`veritas/seguridad/coste-rama-privada-v1/PROCEDENCIA.md` · `TAREAS.md` §2.1, §2.3, §2.7, §3 y §4.2 ·
`ci/*.sh` y los dos `.txt`.

## FASE 1 — Migrar y planificar (sin tocar SPEC, TAREAS ni ci)

### 1.1 · Migración — se **COPIA**, no se mueve; los `P-*/` originales quedan intactos

| Origen | Destino |
|---|---|
| `P-2.1/veritas/consenso/ancla-inyeccion-v2/` | `veritas/consenso/ancla-inyeccion-v2/` |
| `P-PUERTA/veritas/consenso/puerta-cobertura-v1/` | `veritas/consenso/puerta-cobertura-v1/` |
| `P-POT/propuesta/` | `veritas/consenso/pot-primitiva-v1/` |
| `P-FLUJO/propuesta/` | `veritas/consenso/regla-flujo-v1/` |

En cada destino: **(a)** una carpeta `ENTRADA/` con la copia congelada del encargo/prompt y las adendas
que lo gobernaron, y sus `*.sha256`; **(b)** el `PROCEDENCIA.md` correspondiente, copiado **literal** desde
`P-CIERRE/procedencia/` —es el testimonio del validador: **no lo edites**—; **(c)** `HUELLAS.sha256`
**regenerado con rutas desde la raíz del repo** en su ubicación nueva; **(d)** las rutas de `METODO.md` y
de los `LEEME` actualizadas al destino.

**Dos rutas relativas se rompen al migrar; arréglalas y demuéstralo:**
- `ancla-inyeccion-v2/src/AnclaInyeccion.jl:10` incluye GDR subiendo cinco niveles; desde el destino son
  dos (`../../ghostdag-rank-v1/src/GhostdagRank.jl`). **Es el único cambio de código permitido en ese
  instrumento.**
- `pot-primitiva-v1/vectores/Cargo.toml` depende de `prototipos/pot-estable` por ruta relativa: ajústala.

**Pruebas de que la migración no cambió nada** (salidas a `P-CIERRE/ejecucion/MIGRACION.md`):
suite de `ancla-inyeccion-v2` con `--check-bounds=yes`; suite de `puerta-cobertura-v1`; `cargo test` de los
vectores; y **control de identidad**: reejecuta desde el destino la celda `hon-4` (2 000 réplicas, ~4 min,
24 hilos) y comprueba que el `sha256` de su `w.csv` es **idéntico** al del original. `resultados/` migrados
no se regeneran salvo ese control. Todo con `./veritas/julia.sh`; **nada de Python**.

**No se migran:** `deepseek/` (incluido el instrumento v1, que midió el ancla equivocada), `P-SEMBRADOR/`
y `P-ZRX/` (investigación en curso, sin validar).

### 1.2 · El plan de edición: `P-CIERRE/ejecucion/PLAN-SPEC.md`

Una tabla **exhaustiva**, una fila por edición: archivo y línea · ID de regla · **texto actual (cita
literal)** · **texto propuesto (literal)** · de dónde sale (propuesta, archivo:línea) · dudas. Tiene que
cubrir, como mínimo:

1. **Reglas nuevas:** `C-POT-01…08`, `C-FLU-01…18` y `C-FLU-20…23`, y `C-FIN-01`. Propón **dónde** viven
   (§7.1 y subsecciones para PoT y flujo; `C-FIN-01` en §12 junto a `C-REORG`) y **cómo se condensan**: en
   el SPEC va el **enunciado normativo** y una nota corta de motivo; **las demostraciones y las cifras de
   simulación se quedan en `veritas/` y se citan**. **Ninguna cifra medida entra como constante**: `F_slots`,
   `L_suelo_slots`, `I_slots`, `D`, `N(s)`, `ρ_max` y los presupuestos van como **símbolos** o `<<PENDIENTE>>`.
2. **Reglas existentes que cambian:** `C-HDR-05` (cota de slot a **todos** los padres, D-F6) · `C-HDR-06`
   (su `flow(B, slot(B))` queda definido: remite a C-FLU-10/11) · `C-HDR-07` (el `pot_output` único es la
   salida futura, D-2; con la **corrección** de `PROCEDENCIA-pot-primitiva-v1.md`) · `C-GD-10` (nuevos
   filtros de la cola de candidatos: C-FLU-02 y C-FLU-20) · `C-HASH-06` (etiqueta nueva del identificador
   de flujo, D-F2) · `C-NET-31` y `C-NET-32` (clave de caché contextual de C-POT-07; **cota global por nodo**
   además de por par, D-F10; agotar **cualquiera** de las dos da `Pendiente`, nunca `Inválido`, y el nodo conserva su cadena, **sigue reenviando** la rama y reintenta mientras la ventana siga abierta. Es el contenido de **`C-FLU-23`, que NO es una regla de flujo sino una enmienda a C-NET-32.3**: por el mismo criterio que Katana fijó en D-F7, **vive en la familia `C-NET`** —propón el ID—, con `PRESUP_NODO` como símbolo) · `C-REORG-07` (sigue **transitoria**;
   solo gana una remisión a `C-FIN-01`; **no se reconcilia**) · §7.1 (desaparece su «Pendiente») · §7.3
   (`L_slots := máx(F_slots, L_suelo_slots, S_max_slots + 1)`) · la fila «Prueba de espacio/tiempo» de la
   tabla de pendientes (~l. 3029).
3. **`TAREAS.md`:** §2.1 pasa a «cerrado en el SPEC, falta cablear», **corrigiendo su titular**: `1/(S+1)`
   («4 %») es la regla **aditiva** y no aplica con pasado consistente de flujo; el instrumento CRP-v0.1 ya lo
   etiquetaba «condicionado al diseño del flujo, no demostrado». §2.7: C-NET-31/32 corregidas. §2.3: anotar
   el residuo de paridad del `SR`. §3.3: `L` ya no es libre; `L_suelo` símbolo. Y **añadir lo que hoy no
   está en la lista**: el sembrador (A5; defensas escritas inservibles, margen sin medir:
   `P-SEMBRADOR/investigacion/`, validación parcial) · Prop. 7 bajo U3″ + R-FIN-5 + R-FIN-8′ («la deuda
   principal») · CRP-v0.2/v0.3 sin validar en `deepseek/` · la vía A2 y el equilibrio adaptativo sin medir ·
   la aritmética del adelanto sin rehacer tras D-2 · la **calibración en pinza** de `PRESUP_NODO` (por abajo `F_slots × ~92 ms ≈ 11 min` de CPU para verificar una rama rival entera, o la adopción de C-FLU-22 queda derogada de hecho; por arriba el DoS; la cota superior no está derivada) · la **tercera rendija** al congelar, no medida y parcialmente bajo control del atacante: dos nodos con el mismo DAG en flujos distintos porque uno pudo pagar la verificación dentro de la ventana y el otro no · la reconciliación de `C-FIN-01` con el código que hoy
   se detiene, con `COINBASE_MATURITY` y con el archivado · el coste de C-FLU-02 para honestos, a confirmar
   con ANCLA-v0.2 · el código del verificador (integrar `prototipos/pot-estable`) y la derivación del flujo
   en el nodo.
4. **`ci/`:** todos los IDs nuevos a `ci/reglas-sin-codigo.txt`. **`C-HDR-05` cambia de semántica y su
   código queda por detrás del SPEC:** di cómo se declara eso con las convenciones de `ci/`
   (`reglas-sin-cablear.txt`, `consenso-pendiente.txt`…) **sin tocar `crates/`**.
5. **Lo que NO entra**, con su motivo.

### 1.3 · PARADA

Escribe `P-CIERRE/ejecucion/PROGRESO.md` y **detente**. El validador revisa la migración y el plan; la
fase 2 empieza solo con una adenda que lo apruebe.

## FASE 2 — Aplicar (solo tras la aprobación)

Aplica **exactamente** el plan aprobado. Después: los cuatro guardianes (`ci/citas-spec.sh`,
`ci/alcance-consenso.sh`, `ci/dependencias-exactas.sh`, `ci/frontera-crates.sh`) en verde y
`cargo test --workspace` sin regresiones (línea base: 581 pasan / 0 fallan / 6 ignorados). Las
`HUELLAS.sha256` de instrumentos antiguos que firman `SPEC.md` o `TAREAS.md` **fallarán a propósito**:
se documenta, no se «arregla». Entrega `P-CIERRE/ejecucion/INFORME.md` con `git diff --stat`, el recuento
de reglas antes/después de `ci/citas-spec.sh`, y la lista de todo lo que quedó distinto del plan.

## Reglas

1. **Sin `git commit`, `push`, `stash`, cambio de rama ni borrados.** El árbol queda modificado para que
   Katana revise el diff y decida.
2. **No edites `crates/`, `prototipos/`, `research/`, `deepseek/` ni los `P-*/` originales.**
3. **No reescribas el fondo de ninguna regla.** Si al condensar ves un defecto o una ambigüedad, **anótalo
   en el plan** y no lo resuelvas: es decisión de Katana.
4. Estilo normativo del SPEC (MUST / MUST NOT), IDs nuevos y estables, sin reutilizar retirados.
5. No cites un archivo o una línea sin abrirlo; rutas completas desde la raíz.
6. Al empezar y al terminar cada fase: `LC_ALL=C sha256sum -c P-CIERRE/ENTRADA.sha256`,
   `git status --short` y `date`, en `PROGRESO.md`.

**Si algo de este encargo te parece equivocado, dilo ANTES de empezar.**
