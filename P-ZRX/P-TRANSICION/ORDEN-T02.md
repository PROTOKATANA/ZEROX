# ORDEN-T02 — Modelo adversarial de la selección a través del corte

## 1. Identidad y contexto

- **ID:** T02. **Estado:** redactada 2026-09-26. **Director:** Claude (rol de `AUTO-ZRX.md`).
  **Ejecutor:** DeepSeek (modelo analítico + Monte Carlo acotado; no requiere el plus de Sonnet).
- **Proyecto:** `/home/katana/zeo/ZEROX`.
- **Zona de ejecución (única escribible):** `/home/katana/zeo/ZEROX/P-ZRX/P-TRANSICION/T02/`.
- **Objetivo único:** medir, bajo **el mismo** adversario, red y horizonte, cuánto cuesta y con qué
  probabilidad triunfa una reescritura alrededor del corte PoW → PoST con cada regla de selección
  del contrato (`FC-1`, `FC-2`, `FC-3`), y cuánto puede retrasar el corte una mayoría de hash que
  censura depósitos.
- **Pregunta falsable:** «Con `FC-3`, ningún adversario con fracción de espacio PoST `a < 1/2`
  consigue que un nodo en línea abandone la historia honesta tras el corte, cualquiera que sea su
  fracción de hash `h < 1`, dentro de la abstracción de §3.» Se refuta con una combinación
  `(h, a, k, F_slots)` con `a < 1/2` y probabilidad de éxito no despreciable (umbral en §7),
  reproducible por semilla y por la fórmula cerrada.
- **Desbloquea:** `D-ZRX/IPA-ZRX.md` A-05 y A-08 (datos para confirmar o revertir D-T03 y D-T04).

## 2. Autoridad y entradas

Lee **íntegros** antes de escribir código: este archivo; `/home/katana/zeo/ZEROX/V-ZRX/LINEO.md`
(**vinculante**); `/home/katana/zeo/ZEROX/P-ZRX/P-TRANSICION/CONTRATO-v0.md` (§0 D-T03/D-T04,
TRN-04, TRN-09, §8). Contexto: `D-ZRX/RFT-ZRX.md` (RFT-01, RFT-07) y
`P-ZRX/P-TRANSICION/NOTA-A07-SEMILLA.md`. Fuente primaria de la fórmula de alcance:
Nakamoto, *Bitcoin: A Peer-to-Peer Electronic Cash System*, §11, https://bitcoin.org/bitcoin.pdf.

No leas ni uses código de `P-ZRX/P-TRANSICION/T01/` (lo escribe otra sesión en paralelo; este
instrumento debe ser independiente).

Entrada congelada: `/home/katana/zeo/ZEROX/P-ZRX/P-TRANSICION/ENTRADA-T02.sha256`; compruébala
con `cd /home/katana/zeo/ZEROX && LC_ALL=C sha256sum -c P-ZRX/P-TRANSICION/ENTRADA-T02.sha256`
**al empezar y al terminar** y copia ambas salidas en `PROGRESO.md`.

## 3. Decisiones ya tomadas por el director (no las cambies)

1. **Tiempo.** Unidad de tiempo = `T_pow` (intervalo medio de bloque PoW). Los bloques PoW llegan
   como procesos de Poisson independientes: honestos a tasa `1−h`, adversario a tasa `h`. **Sin
   retarget** dentro de la ventana de ataque (supuesto explícito: la ventana es corta frente a la
   ventana de ajuste). Cada bloque PoW vale 1 unidad de trabajo.
2. **Corte.** La altura del terminal honesto es `H*`; el terminal es el primer bloque de su rama a
   esa altura (TRN-04; `Φ` se supone verdadera en ambas ramas salvo en el escenario E4). `W_min` no
   liga cuando el adversario bifurca desde un bloque honesto reciente (reutiliza el trabajo del
   prefijo); por eso, **en este modelo, FC-2 coincide con FC-3** salvo en E5. Decláralo.
3. **Fase PoST abstracta.** El tiempo tras el corte se mide en slots de duración `τ` (expresa `τ`
   en unidades de `T_pow`: parámetro `r = τ/T_pow`). Cada slot produce un bloque PoST honesto con
   probabilidad `(1−a)·p` y uno del adversario con probabilidad `a·p` (procesos independientes
   por slot; `p` = probabilidad de que el slot tenga algún ganador). Peso por bloque = 1. Es la
   abstracción `k = 0` de `blue_work`, igual que en T01. El adversario construye su sufijo PoST en
   privado sobre **su** terminal; los honestos, sobre el suyo.
4. **Selección.**
   - `FC-1`: gana la historia con más trabajo PoW en el prefijo; a igualdad, más peso PoST.
   - `FC-3`: si hay algún sufijo PoST, gana el de más peso PoST; si no, más trabajo PoW.
   - `FC-2`: `FC-3` sin `W_min` (solo difiere en E5).
   - **Nodo en línea** (`C-FIN-01`): no cambia de historia si `d ≥ F_slots`, con `d` = slot de su
     punta − slot del ancestro común (0 si el ancestro es PoW). **Nodo que sincroniza desde cero**:
     aplica la regla sin `C-FIN-01`.
5. **Escenarios** (todos obligatorios):
   - **E1 · Reescritura antes del corte.** El adversario bifurca `k` bloques antes de un pago que
     espera `z` confirmaciones (clásico). Mide probabilidad de éxito sin corte en medio (control:
     debe reproducir la tabla de Nakamoto §11 para `z = 0…10`, `q ∈ {0,1; 0,3}`, con error
     `< 10⁻⁶` frente a la fórmula).
   - **E2 · Terminal alternativo privado + espacio.** El adversario bifurca a profundidad `k` del
     terminal honesto, mina en privado hasta su propio terminal a altura `H*`, construye en privado
     un sufijo PoST con fracción `a` y publica **cuando su historia gana** según la regla, o
     abandona tras un horizonte `M` slots. Éxito = un nodo en línea (con `F_slots`) adopta su
     historia; métrica secundaria: éxito frente a un nodo que sincroniza desde cero.
   - **E3 · Rama PoW tardía más pesada tras el corte.** El adversario ignora la fase PoST y solo
     acumula más trabajo PoW en su rama que en el prefijo honesto hasta `H*` (bifurcando a
     profundidad `k`). Con `FC-1` puede ganar; con `FC-3`, no sin peso PoST. Mide ambos.
   - **E4 · Censura de depósitos.** Con `h > 1/2`, el adversario excluye todo depósito de sus
     bloques y reorganiza los bloques honestos que los incluyen, para mantener `Φ` falso.
     Mide el retraso esperado del corte en `T_pow` y la fracción de emisión PoW capturada durante
     el retraso, en función de `h`. Con `h ≤ 1/2`, mide el retraso por reorganizaciones parciales.
   - **E5 · Cadena de baja dificultad** (solo cualitativo): explica por escrito por qué `W_min`
     importa frente a un adversario que fabrica una rama con dificultad rebajada, y por qué este
     modelo (sin retarget) no lo mide. **No inventes un modelo de retarget.**
6. **Rejilla de valores de prueba** (no son parámetros propuestos): `h ∈ {0,1; 0,25; 0,4; 0,5;
   0,6; 0,9}`, `a ∈ {0,1; 0,25; 0,4; 0,45; 0,5; 0,55}`, `k ∈ {1, 3, 6, 12}`, `z ∈ {0, 1, 3, 6}`,
   `r ∈ {1/60, 1/10, 1}`, `p ∈ {0,5; 0,9}`, `F_slots ∈ {100, 1000, 10000, ∞}`, `M = 10·F_slots`
   (con `F_slots = ∞`, `M = 10⁵`).

Si algo de esto admite dos implementaciones incompatibles, **antes de editar** descríbelo en
`PROGRESO.md` como `AMBIGÜEDAD-n` y detente si cambia un resultado; si no lo cambia, aplica la
lectura más favorable al **adversario** y decláralo.

## 4. Contrato de implementación

Estructura (LINEO §1, adaptada):

    T02/
    ├── Project.toml, Manifest.toml, julia-version.toml
    ├── src/modelo.jl        tipos y parámetros
    ├── src/referencia.jl    fórmulas cerradas (Nakamoto §11; carreras de Poisson/Bernoulli exactas
    │                        por recursión o suma finita donde existan) y un simulador evento a
    │                        evento transparente
    ├── src/rapido.jl        (solo si el perfil lo justifica) versión optimizada del simulador
    ├── src/validacion.jl    comparación referencia ↔ simulador ↔ rápido
    ├── test/runtests.jl
    ├── run.jl               CLI: --seed, --replicas, --escenario {E1..E4,todos}, --hilos
    ├── resultados/          CSV crudos por escenario + resumen
    └── INFORME.md, METODO.md, MODELO.md, HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md, PROGRESO.md,
        HORAS.log

Dependencias permitidas: stdlib, `StableRNGs.jl` o `Random123.jl`, `SpecialFunctions.jl`,
`Distributions.jl`, `BenchmarkTools.jl`, `IntervalArithmetic.jl` o `Arblib.jl` para certificar
umbrales si hace falta. Nada más sin justificarlo.

Reglas numéricas (LINEO §5.3): conteos y decisiones en enteros; probabilidades en `Float64` con
intervalo de confianza (Wilson o Clopper-Pearson) para Monte Carlo; toda probabilidad que decida
el veredicto cerca del umbral de §7 se certifica con aritmética rigurosa o se declara inconclusa.

## 5. Modelo de amenaza

Adversario con fracción de hash `h` (propia o alquilada: no distingue) y fracción de espacio PoST
`a`, que coordina ambos recursos, conoce toda la historia honesta, puede retener bloques y publicar
cuando le convenga. Red honesta sin latencia (supuesto optimista para el honesto: decláralo como
límite; la latencia real favorece al adversario). **Coste absoluto**: expresa para cada éxito el
trabajo PoW gastado (en bloques, convertible a dinero cuando IPA A-10 dé precios) y la fracción de
espacio `a` exigida; no conviertas a dinero sin fuente.

## 6. Plan de verificación

- Oráculo: fórmulas cerradas donde existan (E1 exacto por Nakamoto §11; carrera de dos procesos por
  suma de la distribución binomial negativa). El simulador debe reproducirlas dentro de su
  intervalo de confianza al 99,9 % en todos los puntos donde ambas existan.
- Tests: bordes `h → 0`, `h → 1`, `a = 1/2`, `k = 0`, `F_slots = 0` y `∞`; propiedades de
  monotonía (éxito no decreciente en `h`, en `a`, en `k` hacia atrás… comprueba y **reporta** si
  alguna no se cumple, no la fuerces); la tabla de Nakamoto como vector de regresión.
- Réplicas Monte Carlo: ≥ 10⁵ por punto donde no haya fórmula; RNG por réplica y por punto
  (LINEO §7), semilla maestra `0x5a5a` por CLI.
- Comandos exactos:

      cd /home/katana/zeo/ZEROX/P-ZRX/P-TRANSICION/T02
      export JULIA_DEPOT_PATH=/home/katana/zeo/ZEROX/P-ZRX/P-TRANSICION/T02/.julia-depot:
      export JULIA=/home/katana/.julia/juliaup/julia-1.13.0+0.x64.linux.gnu/bin/julia
      date -Is >> HORAS.log
      env -u LD_LIBRARY_PATH JULIA_NUM_THREADS=1 $JULIA --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.test()' > resultados/test.log 2>&1
      env -u LD_LIBRARY_PATH JULIA_NUM_THREADS=4 OPENBLAS_NUM_THREADS=1 $JULIA --project=. --threads=4,0 run.jl --seed 0x5a5a --replicas 100000 --escenario todos > resultados/run.log 2>&1
      date -Is >> HORAS.log

  **Tope de 4 hilos** en esta orden: otra orden compila en paralelo en la misma máquina. Mide el
  escalado 1, 2, 4 y conserva el que gane (LINEO §7), sin superar 4.
- **Prohibido Python.** No uses el lanzador `juliaup`.

## 7. Medición

Métricas por escenario y punto: probabilidad de éxito (con IC), trabajo PoW gastado por el
adversario (media y percentil 99 en bloques), slots hasta el éxito, y en E4 retraso del corte y
emisión capturada. Umbral de «probabilidad no despreciable» fijado **antes** de ejecutar:
`P_éxito > 10⁻³` con IC al 99,9 % que no incluya `10⁻³`; si el IC contiene el umbral, el punto es
**inconcluso**.

Presupuesto: **2 h de reloj, 4 hilos, 16 GiB de RAM, 2 GiB de disco**. Si se agota, checkpoint e
**inconcluso**.

Límites de extrapolación que el informe debe repetir: sin latencia, sin retarget, sin GHOSTDAG
real (`k = 0`), sin sesgo de semilla (A-07), sin precios de hash (A-10).

## 8. Entregables

En la zona: proyecto de §4, `resultados/` con CSV crudos, `INFORME.md` (veredicto de la pregunta
falsable; tablas por escenario; diferencias FC-1/FC-3; en qué región **FC-3 es peor** que FC-1, si
la hay; coste absoluto en bloques; sección «Lo que este modelo NO demuestra»), `METODO.md`,
`MODELO.md`, `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md` (qué supuesto de §3 decide cada
conclusión), `PROGRESO.md`, `HORAS.log` (solo `date -Is`).

Resumen final (≤ 40 líneas, español): veredicto, puntos que refutan o quedan inconclusos,
comprobación de `ENTRADA-T02.sha256`, archivos, comandos.

## 9. Límites de la sesión

- DeepSeek Harness, modelo de catálogo `deepseek-flash` («DeepSeek-V41-Flash»), esfuerzo `high`.
- Lee íntegro y aplica `V-ZRX/LINEO.md` antes de escribir o ejecutar código. **Ningún código
  Python.**
- No elijas arquitectura, parámetros ni criterios; los valores de la rejilla son de prueba.
- Nada fuera de tu zona; no leas `P-ZRX/P-TRANSICION/T01/`.
- Ningún `Ok` ficticio ni test que se autoconfirme. No hagas commit ni push. No leas ni expongas
  secretos (`.env`, `~/.dsh/`, credenciales).
- Si una prueba falla, repórtala con su salida literal.

## Lanzamiento

    mkdir -p /home/katana/zeo/ZEROX/P-ZRX/P-TRANSICION/T02 && cd /home/katana/zeo/ZEROX/P-ZRX/P-TRANSICION/T02 && \
    ( set -a; . /home/katana/torio/deepseek-harness/.env >/dev/null 2>&1; set +a; \
      node /home/katana/torio/deepseek-harness/apps/cli/lib/bin.js --profile headless \
      "Orden T02. Lee íntegro /home/katana/zeo/ZEROX/P-ZRX/P-TRANSICION/ORDEN-T02.md y cúmplelo. Antes de escribir o ejecutar código, lee íntegros /home/katana/zeo/ZEROX/V-ZRX/LINEO.md y /home/katana/zeo/ZEROX/P-ZRX/P-TRANSICION/CONTRATO-v0.md. Si detectas una falta de definición, infórmala antes de editar." \
      > ../T02-dsh.stdout 2> ../T02-dsh.stderr )
