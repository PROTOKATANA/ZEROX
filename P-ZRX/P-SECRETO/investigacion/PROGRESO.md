# PROGRESO — P-SECRETO · ¿Puede exigirse algo que no se pueda cumplir en secreto?

**Bitácora de trabajo. Sesión: 2026-09-23. Valida: Claude. Decide: Katana.**

## §1 · Comprobación de ENTRADA

Ejecutado desde la raíz `/home/katana/zeo/ZEROX`, antes de tocar nada:

```
$ LC_ALL=C sha256sum -c P-ZRX/P-SECRETO/ENTRADA.sha256
P-ZRX/P-SECRETO/PROMPT.md: OK

$ git -C /home/katana/zeo/ZEROX status --short
 M Cargo.lock
 M Cargo.toml
 M MIGRACION.md
 M P-ZRX/PROPUESTAS-VIABLES.md
 M README.md
 M SPEC.md
 M TAREAS.md
 M ci/consenso-pendiente.txt
 M ci/frontera-crates.sh
 M ci/reglas-sin-cablear.txt
 M ci/reglas-sin-codigo.txt
 M crates/zx-consensus/Cargo.toml
 M crates/zx-consensus/src/bloque_dag.rs
 M crates/zx-consensus/src/error.rs
 M crates/zx-consensus/src/ghostdag.rs
 M crates/zx-consensus/src/lib.rs
 M crates/zx-consensus/tests/ghostdag_bench.rs
 M crates/zx-consensus/tests/ghostdag_oraculo.rs
 M crates/zx-consensus/tests/ghostdag_prop.rs
 M crates/zx-consensus/tests/ghostdag_rust.rs
?? ENCARGO-03c-POT-CONTEXTUAL.md
?? P-ZRX/P-ANCESTRIA/
?? P-ZRX/P-COBERTURA/
?? P-ZRX/P-LATENCIA/
?? P-ZRX/P-PUENTE-ESPACIO-TASA/
?? P-ZRX/P-RIVAL/
?? P-ZRX/P-SECRETO/
?? P-ZRX/P-SELLO/
?? P-ZRX/P-TASA/
?? P-ZRX/T-ZRX/ESTADO-DOBLE-FARMEO.md
?? crates/zx-consensus/src/pot.rs
?? crates/zx-consensus/tests/pot_derivaciones.rs
?? crates/zx-consensus/tests/pot_slot.rs
?? crates/zx-pot/

$ date
mié 23 sep 2026 21:00:47 CEST

$ uptime
 21:00:47  up 15 days 17:30,  2 users,  carga promedio: 1,31, 1,14, 1,08
```

- `PROMPT.md: OK` — entrada íntegra.
- Los `M`/`??` de `crates/`, `ci/`, `SPEC.md`, `TAREAS.md`, `Cargo.*`, `README.md`,
  `MIGRACION.md` **no son míos**: son del encargo de cableado en paralelo (aviso del PROMPT §7).
  Los `??` de otros `P-ZRX/*/` son de los encargos anteriores de la serie del doble farmeo.
- **No toco nada fuera de `P-ZRX/P-SECRETO/investigacion/`.**

## §2 · Objeciones al encargo antes de ejecutar (PROMPT §10)

Ninguna que invalide el encargo. Tres matices que declaro y que desarrollo con números en el
INFORME, no como protesta sino como alcance:

1. La premisa («ataquemos κ = 0») no tiene privilegio y el encargo lo dice él mismo. La refuto o
   la confirmo con números; en este caso la confirmo como teorema (F1) y la entierro por la
   viveza (F4).
2. El §4.2 dice «la probabilidad de que los k sorteados sean todos suyos es ≈ α^k (declara el
   modelo de muestreo…)». Ese número es correcto para el atacante **si los firmantes honestos se
   niegan a firmar lo ajeno**; si firman cualquier bloque válido que ven (el diseño «obediente»),
   la captura no es la métrica que manda: la manda el silencio de los firmantes honestos. Ambas
   métricas se publican y se separan.
3. La candidata tiene **dos encarnaciones** con destinos distintos y hay que separarlas desde la
   primera línea: la de una fase (las firmas van dentro del bloque: muere por latencia) y la de
   dos fases / activación de peso (las firmas llegan después: sobrevive la latencia, muere por la
   red, y además cae del lado equivocado de la línea roja de §4.5). El PROMPT describe la de una
   fase; la de dos fases es el único arreglo de latencia posible y hay que tratarla para no
   descartar con trampa.

## §3 · Presupuesto declarado antes de ejecutar (PROMPT §«ADAPTACIÓN»)

- **Hilos: máximo 4.** Los kernels son tablas cerradas `O(celdas)`: no hay Monte Carlo masivo.
  Si lo hubiera, RNG por réplica con semillas **no consecutivas** (hallazgo de `P-ZRX/P-PUERTA`).
- **RAM: máximo 8 GiB** (el cálculo cabe en KiB-MiB).
- **Disco: máximo 300 MiB** (incluye el depósito Julia local si hace falta crearlo; los
  artefactos son < 1 MiB).
- **Tiempo: corridas de minutos**; techo de pared 2 h para todo el instrumento.
- `uptime` anotado antes de cada bloque de benchmark en `resultados/BENCH.txt`.

## §4 · Bitácora

- 21:00 — entrada verificada; lecturas abiertas: `ESTADO-DOBLE-FARMEO.md` (entero),
  `veritas/LINEO.md` (entero), `P-CLAVE` F6, `P-PRESTAMO` F1, `P-EQUIVOCACION`, `P-RIVAL` F1/H5,
  `P-SELLO` O5, `P-2.1/SINTESIS`, `AGUJEROS-Y-SOLUCIONES` (D4), `research/README.md`,
  `research/dag-poas-capa-finalidad.md` (entero), `research/dag-poas-balizas-auditoria.md`
  (entero), `SPEC.md` §7.1/§7.2/§7.3/§12/§16, `veritas/finalidad/delta-medido-v1/INFORME.md`
  (§11.2–11.4), `P-ZRX/P-PUERTA` (hallazgo RNG, INFORME §5 defecto 4).
- 21:05 — F1 formalizado; el instrumento esbozado (captura exacta, viveza, latencia).
- 21:16 — instrumento v1 escrito y en verde (114 controles); tablas F1/F3/F4 generadas;
  benchmarks con `uptime` (carga 1,67–2,53 ⇒ «medido con carga ajena»).
- 21:18 — **verificación independiente lanzada** (AGENTS.md): especialista de matemáticas +
  especialista de Julia, con el encargo de atacar F1–F6 y auditar el código.
- 21:30 — **hallazgos de la verificación incorporados.** Matemáticas: (E1) el paro en
  partición exige sortear también al productor → 1 − x^(k+1) − (1−x)^(k+1); (E2) la
  captura de cadena exige ganar el reto de cada slot → α^((k+1)d); (E3) la fuga usa la
  esperanza como exponente → función generatriz exacta (α+(1−α)p_sil)^(kd); (E4) la
  latencia hay que contarla en saltos de overlay (h) con tramos independientes, no en un
  enlace; (E5) la «tasa efectiva serializada» estaba mal atribuida → retirada, la métrica
  es P(no cabe); (E6) subdesbordamiento Float64 de la fuga → log10 BigFloat; (E7) el
  control F1 codificaba la conclusión → regímenes V1/V2 explícitos. Julia: test
  tautológico de cadena retirado (anclas de constantes + enumeración por slot), identidades
  de parametrización etiquetadas como plomería, deps sin uso retiradas, semilla de CLI
  ahora consumida por el MC.
- 21:40 — instrumento v2 en verde (80 controles con `--check-bounds=yes`); tablas
  regeneradas; benchmarks finales; INFORME.md, DECISIONES-PENDIENTES.md e
  HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md escritos.

## §5 · Comprobación de SALIDA

```
$ LC_ALL=C sha256sum -c P-ZRX/P-SECRETO/ENTRADA.sha256
P-ZRX/P-SECRETO/PROMPT.md: OK

$ git -C /home/katana/zeo/ZEROX status --short   (filtrado a lo relevante)
 M SPEC.md
 M TAREAS.md
 M ci/...                 ← del encargo de cableado (no míos)
 M crates/...             ← íd.
?? P-ZRX/P-SECRETO/       ← este encargo (íntegro, solo investigacion/)
?? P-ZRX/T-ZRX/ESTADO-DOBLE-FARMEO.md  ← entrada de la sesión del doble farmeo (no mío)

$ date
mié 23 sep 2026 21:44:35 CEST

$ uptime
 21:44:35  up 15 days 18:14,  2 users,  carga promedio: 2,55, 2,34, 1,99
```

- `PROMPT.md` íntegro al terminar; **no se tocó nada fuera de
  `P-ZRX/P-SECRETO/investigacion/`**.
- Presupuesto respetado: 4 hilos como tope (la corrida es serial, O(celdas)), RAM < 100 MiB,
  disco < 5 MiB de artefactos (+ depósito Julia local, caché regenerable), corridas de segundos.
- Estado final del instrumento: 80/80 controles, `run.jl --seed 0x5EC5E70 --tarea f1 --tarea f3
  --tarea f4`, `bench/benchmarks.jl` con `uptime` en `resultados/BENCH.txt`.
