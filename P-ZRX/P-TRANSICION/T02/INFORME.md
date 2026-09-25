# INFORME — T02: modelo adversarial de la selección a través del corte

**ID:** T02 (con `CORRECCION-T02-A`). **Fecha de ejecución:** 2026-09-26. **Ejecutor:** DeepSeek.
**Alcance:** modelo analítico + Monte Carlo de E1–E4 bajo `ORDEN-T02.md` y `CORRECCION-T02-A.md`.
**Datos crudos:** `resultados/` (`E1..E4.csv`, `E1_tabla_nakamoto.csv`, `E3_validacion_mc.csv`,
`resumen.csv`). **Método:** `METODO.md`. **Modelo:** `MODELO.md`. **Supuestos clave:**
`HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`.

## 1. Veredicto sobre la pregunta falsable

> «Con `FC-3`, ningún adversario con fracción de espacio PoST `a < 1/2` consigue que un nodo en
> línea abandone la historia honesta tras el corte, cualquiera que sea su fracción de hash
> `h < 1`, dentro de la abstracción de §3.»

**Se refuta, dentro del modelo.** Contraejemplo reproducible (`seed 0x5a5a`, 10⁵ réplicas):

| `h` | `a` | `k` | `r` | `p` | `F_slots` | éxito nodo **nuevo** (IC 99,9 %) | éxito nodo **en línea** (IC 99,9 %) |
|---:|---:|---:|---:|---:|---:|---:|---:|
| **0,9** | **0,40** | 6 | 0,1 | 0,9 | 1000 | **0,99982** [0,99962; 0,99992] | **0,99982** [0,99962; 0,99992] |
| 0,6 | 0,40 | 6 | 0,1 | 0,9 | 1000 | 0,76989 [0,76548; 0,77424] | 0,76989 [0,76548; 0,77424] |
| 0,5 | 0,40 | 6 | 0,1 | 0,9 | 1000 | 0,51986 [0,51466; 0,52506] | 0,51986 [0,51466; 0,52506] |
| 0,4 | 0,40 | 6 | 0,1 | 0,9 | 1000 | 0,26420 [0,25964; 0,26881] | 0,26420 [0,25964; 0,26881] |

Umbral fijado antes de ejecutar: `P_éxito > 10⁻³` con IC que no contenga `10⁻³`. En la rejilla
corrida, **32 de 35 puntos** de E2 con `a < 1/2` superan el umbral (ver `resultados/E2.csv`).
El nodo **en línea** cambia igual que el nuevo en estos puntos porque `d = 0` (la punta honesta no
tiene ningún bloque PoST) y `0 < F_slots`.

**Mecanismo.** El adversario mina en privado desde el bloque a altura `H*−k`. Con `h` alta llega a
su terminal **antes** que el honesto (`t_A ≤ t_H`, casi seguro para `h=0,9`). En `t_A` el honesto
todavía no ha empezado su fase PoST, luego `W_A = W_H = 0`; el empate favorece al adversario y su
rama tiene tanto trabajo como el terminal honesto y **más avance** (ya está en `H*`). Como no hay
bloque PoST honesto, `d = 0`, de modo que `C-FIN-01` no protege. No hace falta espacio: `a = 0,4`.

Esto es exactamente el ataque que la corrección quería aislar con «terminal alternativo privado +
espacio»: el recurso que decide no es `a` sino `h`, y `FC-3` no lo detiene cuando el terminal
adversario existe primero.

## 2. E1 · control de Nakamoto

La fórmula de la corrección reproduce la **tabla publicada** del artículo §11 con error máximo
**4,83·10⁻⁸** (`< 10⁻⁶`). Nota: para `q = 0,3` el artículo tabula `z = 0, 5, 10, …, 50` (no
`1…4` ni `6…9`); se comprobaron esos 22 puntos. El simulador cae dentro del IC 99,9 % en
**24/24** puntos de la rejilla (`resultados/E1.csv`). `h ≥ 1/2` da `P = 1` (captura segura), como
fija el artículo.

## 3. E2 · terminal alternativo privado + espacio

Sensibilidad desde la base `(h; a; k; r; p; F_slots) = (0,25; 0,4; 6; 0,1; 0,9; 1000)`.
`ge =` métrica principal `≥`; `gt =` estricta `>`.

**Barrido en `h`** (`a=0,4; k=6; r=0,1; p=0,9; F_slots=1000`):

| `h` | `ge` nuevo | `ge` en línea | `gt` nuevo |
|---:|---:|---:|---:|
| 0,10 | 0,00039 | 0,00039 | 0,00035 |
| 0,25 | 0,03906 | 0,03906 | 0,03556 |
| 0,40 | 0,26420 | 0,26420 | 0,24817 |
| 0,50 | 0,51986 | 0,51986 | 0,50270 |
| 0,60 | 0,77188 | 0,77188 | 0,75877 |
| 0,90 | 0,99982 | 0,99982 | 0,99980 |

**Barrido en `a`** (`h=0,25; k=6; r=0,1; p=0,9`; `F_slots=1000` salvo `a≥1/2` con `F_slots=100`):

| `a` | `ge` nuevo | `ge` en línea |
|---:|---:|---:|
| 0,10 | 0,03591 | 0,03591 |
| 0,25 | 0,03665 | 0,03665 |
| 0,40 | 0,03839 | 0,03839 |
| 0,45 | 0,04253 | 0,04253 |
| 0,50 | 0,11504 | **0,05198** |
| 0,55 | 0,63302 | **0,07076** |

Con `a ≥ 1/2` y `F_slots = 100` aparece el único efecto relevante de `C-FIN-01`: el nodo en línea
deja de cambiar cuando la carrera PoST se alarga por encima de 100 slots.

**Otros barridos:** `k = 1,3,6,12` → `ge` = 0,312; 0,119; 0,040; 0,0055. `r = 1/60, 1/10, 1` →
0,0347; 0,0378; 0,0378. `p = 0,5, 0,9` → 0,0458; 0,0386. `F_slots = 100, 1000, 10⁴, ∞` →
0,0381; 0,0378; 0,0380; 0,0390 (el horizonte no muerde en este punto). El **oráculo exacto sin
horizonte** para `a<1/2` (`e2_prob_sin_horizonte`) coincide con el MC dentro del IC.

## 4. E3 · rama PoW con más trabajo por bloque

Coste del adversario `k(1+δ) ∈ [1,01; 13,2]` unidades de trabajo. Se recorrió el **producto
cartesiano completo** (6912 puntos) con fórmulas exactas.

- **`FC-1`** (nodo nuevo): el adversario gana **siempre** (probabilidad 1): publica su terminal con
  más trabajo y no necesita peso PoST. El nodo en línea cambia si `d < F_slots`; la **partición**
  `P(en línea NO cambia y nuevo SÍ) = P(d ≥ F_slots)` vale desde 0 (p. ej. `F_slots = ∞`) hasta 1
  (muchos slots por delante de `F_slots`).
- **`FC-3`**: gana solo mientras `W_H = 0`. Máximo global **0,8647** (`h=0,9; a=0,55; k=1;
  δ=0,01; r=1; p=0,5; F_slots=100`); máximo con `a < 1/2` **0,8394** (`h=0,9; a=0,45; k=1;
  δ=0,01; r=1; p=0,5`). Con slots largos (`r=1`) y `k` pequeño, el adversario publica antes de que
  exista el primer bloque PoST honesto. **1948 puntos** con `a<1/2` tienen `FC-3 > 10⁻³`.
- **Dónde `FC-3` es peor que `FC-1`** para el adversario: prácticamente en toda la rejilla. Para el
  nodo **nuevo**, `FC-1` da 1 y `FC-3 ≤ 1`, luego `FC-3` nunca es mejor para el adversario. Para el
  nodo **en línea**, `FC-1` da `1 − P(d ≥ F_slots)`; `FC-3 > FC-1` en **80 de 6912** puntos (los de
  `F_slots` pequeño y `r` grande, donde `C-FIN-01` bloquea a `FC-1` pero `FC-3` aún encuentra
  `W_H = 0`). En los **6832** restantes `FC-3` es peor para el adversario que `FC-1` en línea.

## 5. E4 · censura de depósitos

Retraso del corte (media y p99 en `T_pow`) y emisión capturada. Sin adversario el corte tendría
media `1 + M_dep`. Horizonte `10⁴·T_pow`.

| `h` | `M_dep` | censurado | `t` medio | exceso sobre `1+M_dep` | `t` p99 | fracción adv. |
|---:|---:|---:|---:|---:|---:|---:|
| 0,10 | 1 | 0,0000 | 2,23 | 0,23 | 7,46 | 0,005 |
| 0,25 | 6 | 0,0000 | 9,62 | 2,62 | 22,26 | 0,032 |
| 0,40 | 12 | 0,0000 | 25,12 | 12,12 | 64,30 | 0,122 |
| 0,50 | 12 | 0,0000 | 41,02 | 28,02 | 135,64 | 0,302 |
| 0,60 | 12 | 0,0000 | 107,96 | 94,96 | 439,46 | 0,589 |
| 0,90 | 1 | 0,0000 | 62,91 | 60,91 | 283,28 | 0,611 |
| 0,90 | 3 | 0,0001 | 1097,65 | 1093,65 | 5049,88 | 0,924 |
| 0,90 | 6 | **0,8102** | 4849,15 | 4842,15 | 9888,48 | 0,976 |
| 0,90 | 12 | **0,9998** | 5245,79 | 5232,79 | 9760,94 | 0,951 |

**Observación frente a la expectativa de la corrección.** La corrección anticipa que para `h > 1/2`
la fracción censurada sería «cerca de 1». Con la estrategia **literal** (perseguir cada bloque
honesto con depósito, publicar solo cuando la rama privada es estrictamente más larga, y volver a
perseguir el depósito devuelto al mempool) el retraso esperado es **finito** para todo `h<1` del
grid: el adversario puede perder una persecución (el honesto consigue `M_dep` bloques antes de que él
saque dos de ventaja) y, repetida la persecución, el corte acaba ocurriendo. La censura solo domina a
`h = 0,9` y `M_dep ≥ 6` (0,81 y 0,9998). Para `h → 1`, el tiempo esperado de corte escala como
`(1−h)^{−(M_dep+1)}` y la fracción censurada tiende a 1 (verificado: `h=0,99`, `M_dep=6` → censurado
1,0 en el test). Se reporta como propiedad que **no** se cumple en la letra del modelo y se deja la
cota.

## 6. Coste absoluto (bloques PoW)

| Escenario | Coste por éxito | Nota |
|---|---|---|
| E1 | `z` confirmaciones y el trabajo de la rama privada (Poisson) | control |
| E2 | **`k`** bloques privados hasta el terminal | en la rejilla, 1–12 |
| E3 | **`k(1+δ)`** unidades de trabajo | 1,01–13,2 |
| E4 | el trabajo de cada reorganización; la emisión capturada mide el coste social | ver §5 |

No se convierte a dinero: no hay precios de hash (falta IPA A-10).

## 7. Hallazgos colaterales

1. **E1:** el proceso embebido del “primer bloque” da una binomial negativa (0,2 en el control de
   `z=1, q=0,1`), distinta de la fórmula de Nakamoto (0,2045873), que usa el tiempo **medio** `z/p`
   del honesto. El simulador implementa la lectura del artículo; se documenta para que no se
   confunda con un error del oráculo.
2. **E2, `a=1/2`:** sin horizonte la absorción es segura (`P=1`); con `F_slots=∞` (`M=10⁵`) el
   éxito se trunca a **0,756** en el punto base. El horizonte, no la física, decide ese número.
3. **Empates:** reportar `≥` y `>` cambia poco (< 2 %) en los puntos corridos; se dan ambas.
4. **E4:** ver §5 (expectativa de censura de la corrección).

## 8. Lo que este modelo NO demuestra

- **Sin latencia:** la red es instantánea y sin huérfanos; la latencia real favorece al adversario y
  no se mide (límite optimista para el honesto).
- **Sin retarget:** no se modela dificultad variable; **E5** (cadena de baja dificultad) queda solo
  cualitativo y `W_min` no se mide.
- **Sin GHOSTDAG real:** `k = 0`; cada sufijo PoST es una cadena y el peso es la suma de bloques.
- **Sin sesgo de semilla (A-07):** la semilla del corte no se modela.
- **Sin precios de hash (A-10):** el coste se da en bloques/trabajo, no en dinero.
- **Sin doble farmeo:** no se modela ventaja del honesto por él (RFT-01 sigue aplicando).
- **Grid de E2 incompleto:** el producto cartesiano de E2 es inconcluso por presupuesto; se cubrió
  una sensibilidad y las interacciones de la pregunta falsable (35 puntos, ≥10⁵ réplicas).
- **E4 con la estrategia literal:** la cota de censura se reporta como resultado del modelo, no como
  imposibilidad de censurar por mayoría de hash; un modelo con minado continuo del adversario daría
  más censura.

## 9. Comprobación de entrada congelada

`ENTRADA-T02.sha256` y `ENTRADA-T02-A.sha256`: los cuatro ficheros (`ORDEN-T02.md`,
`CORRECCION-T02-A.md`, `CONTRATO-v0.md`, `V-ZRX/LINEO.md`) verifican `OK` al empezar y al terminar
(salidas literales en `PROGRESO.md`).

## 10. Reproducir

    cd /home/katana/zeo/ZEROX/P-ZRX/P-TRANSICION/T02
    export JULIA_DEPOT_PATH=$PWD/.julia-depot:
    export JULIA=/home/katana/.julia/juliaup/julia-1.13.0+0.x64.linux.gnu/bin/julia
    env -u LD_LIBRARY_PATH JULIA_NUM_THREADS=1 $JULIA --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.test()'
    env -u LD_LIBRARY_PATH JULIA_NUM_THREADS=4 OPENBLAS_NUM_THREADS=1 \
      $JULIA --project=. --threads=4,0 run.jl --seed 0x5a5a --replicas 100000 --escenario todos

Semilla `0x5a5a`, Julia 1.13.0, AMD Ryzen 9 9950X3D, 4 hilos; `run.jl` completo en 10,7 s.
